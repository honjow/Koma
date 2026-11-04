import { common } from '@kit.AbilityKit'
import { taskpool, util } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { writeAppTextFile } from './AppFileTextPersistence'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { connectImageRuleState } from '../state/ImageRuleState'
import { ImageProcessingPlugin, validateImageProcessingPlugin, imagePluginDefaults } from './ImageProcessingPlugins'
import { SettingsFieldValues } from './SettingsFormFields'
import { ImagePluginOffer, ImagePluginRow, imagePluginOffers, imagePluginOffersConflict, imagePluginRows } from './ImagePluginManagement'
import { imagePluginNative } from './ImagePluginNative'
import { ImageBannerRule, ImageRuleRecord, ImageRuleSnapshot, ImageRuleConfiguration, ImageRuleSubscription, ImageRuleIndex, ImageRulePack,
  ImageRulePackReference, ImagePluginCollection, validateImageRulePack, validateImageRuleConfiguration, imageRuleKey } from './ImageBannerRules'
import { isValidHttpUrl, resolveIndexDocumentUrl, safeResolveIndexRelativeUrl, parseIndexEntriesDocument } from '../sourceRuntime/SourceIndexMetadata'

const LIMIT = 4 * 1024 * 1024

@Concurrent
function readImageRules(path: string): string {
  if (!fs.accessSync(path)) return ''
  if (fs.statSync(path).size > 16 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
  return JSON.stringify(validateImageRuleConfiguration(JSON.parse(fs.readTextSync(path)) as Object))
}
@Concurrent
function commitImageRules(path: string, payload: string): void {
  if (payload.length > 16 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
  validateImageRuleConfiguration(JSON.parse(payload) as Object)
  writeAppTextFile(path, payload)
}
@Concurrent
function validateImageRuleResource(bytes: ArrayBuffer, referenceJson: string): string {
  const reference = JSON.parse(referenceJson) as ImageRulePackReference
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new Uint8Array(bytes) })
  const actual = Array.from(digest.digestSync().data).map((v: number): string => v.toString(16).padStart(2, '0')).join('')
  if (actual !== reference.sha256) throw new Error('image_rule_digest_mismatch')
  const text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(bytes))
  const raw = JSON.parse(text) as Object
  if ((raw as ImageProcessingPlugin).schemaVersion === 2) {
    const plugin = validateImageProcessingPlugin(raw)
    if (plugin.id !== reference.id || plugin.version !== reference.version) throw new Error('invalid_image_plugin_identity')
    // Executable bytes are accepted only from their separately hashed resource.
    plugin.processor.moduleBase64 = undefined
    return JSON.stringify(plugin)
  }
  const pack = validateImageRulePack(raw)
  if (pack.id !== reference.id || pack.version !== reference.version || !pack.meta?.name?.trim() ||
    pack.rules.some((rule: ImageBannerRule): boolean => !rule.name?.trim() || !rule.description?.trim()))
    throw new Error('invalid_image_rule_details')
  return JSON.stringify(pack)
}
@Concurrent
function validateImageProcessorModule(bytes: ArrayBuffer, expected: string): string {
  if (bytes.byteLength < 8 || bytes.byteLength > 2 * 1024 * 1024) throw new Error('image_processor_size')
  const data = new Uint8Array(bytes)
  if (data[0] !== 0 || data[1] !== 97 || data[2] !== 115 || data[3] !== 109) throw new Error('invalid_image_processor')
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data })
  const actual = Array.from(digest.digestSync().data).map((v: number): string => v.toString(16).padStart(2, '0')).join('')
  if (actual !== expected) throw new Error('image_processor_digest_mismatch')
  const reason = imagePluginNative.inspectImageProcessor(data)
  if (reason) throw new Error('image_processor_' + reason)
  return new util.Base64Helper().encodeToStringSync(data)
}
@Concurrent
export function subscriptionDocumentKind(payload: string): string {
  const value = JSON.parse(payload) as Object
  if (!Array.isArray(value) && ['image_rules', 'image_plugins'].includes((value as ImageRuleIndex)?.kind ?? '')) return 'image_rules'
  return parseIndexEntriesDocument(value) !== undefined ? 'source' : 'unknown'
}

/** Explicit rule subscriptions only. There is no bundled rule data or source-repository discovery.
 * The common subscription page combines two typed providers; source installation never consumes these records.
 * Old implicit snapshots are not evidence that a user subscribed, so they restore inactive.
 * Catalog identity and installed content have independent lifecycles: removing
 * an address keeps installations; no subscription gate or automatic upgrade runs.
 * The current ownership and migration contract is in docs/subscription-image-rules.md.
 */
export class ImageRuleStore {
  private static instances: Map<string, ImageRuleStore> = new Map()
  private ready: Promise<void>
  private configuration: ImageRuleConfiguration = { schemaVersion: 3, subscriptions: [], installations: [] }
  private writes: Promise<void> = Promise.resolve()
  private automaticCheckStarted: boolean = false
  private pendingCheck: Promise<boolean> | undefined = undefined
  private inFlight: Map<string, Promise<void>> = new Map()
  private epochs: Map<string, number> = new Map()
  private generation: number = 0
  private context: common.Context
  private constructor(context: common.Context) { this.context = context; this.ready = this.load() }
  static forContext(context: common.Context): ImageRuleStore {
    let store = ImageRuleStore.instances.get(context.filesDir)
    if (store === undefined) { store = new ImageRuleStore(context); ImageRuleStore.instances.set(context.filesDir, store) }
    return store
  }
  private path(): string { return `${this.context.filesDir}/image-rules.v1.json` }
  private async load(): Promise<void> {
    try {
      const saved = await taskpool.execute<[string], string>(readImageRules, this.path())
      this.configuration = saved ? validateImageRuleConfiguration(JSON.parse(saved) as Object) :
        { schemaVersion: 3, subscriptions: [], installations: [] }
      connectImageRuleState().readFailed = false
    } catch (_error) {
      // Preserve the file and any usable in-memory state. A read error must not
      // turn into an empty configuration which the next edit could overwrite.
      connectImageRuleState().readFailed = true
    }
    this.publishState(false)
  }
  private assertReadable(): void {
    if (connectImageRuleState().readFailed) throw new Error('image_plugin_storage_unavailable')
  }
  private publishState(userChange: boolean): void {
    const state = connectImageRuleState()
    state.enabledRuleCount = this.configuration.installations.reduce((sum: number, source: ImagePluginCollection): number =>
      sum + source.packs.reduce((count: number, pack: ImageRulePack): number => count + pack.rules.filter((rule: ImageBannerRule): boolean =>
        !source.disabledRules.includes(imageRuleKey(pack.id, rule.id))).length, 0) +
      source.plugins.filter((plugin: ImageProcessingPlugin): boolean => !source.disabledRules.includes(imageRuleKey(plugin.id, plugin.id))).length, 0)
    // Use the same candidates as the management list. Legacy packs may expose
    // several rows, but updating the pack is a single installation operation.
    const updates = imagePluginRows(this.configuration.subscriptions, this.configuration.installations)
      .filter((row: ImagePluginRow): boolean => row.group === 'updates')
      .map((row: ImagePluginRow): string => JSON.stringify([row.source.origin, row.id()]))
    state.updateCount = new Set<string>(updates).size
    state.dataRevision += 1
    if (userChange) state.userRevision += 1
  }
  async list(): Promise<ImageRuleSubscription[]> {
    await this.ready; this.assertReadable()
    return JSON.parse(JSON.stringify(this.configuration.subscriptions)) as ImageRuleSubscription[]
  }
  async installed(): Promise<ImagePluginCollection[]> {
    await this.ready; this.assertReadable()
    return JSON.parse(JSON.stringify(this.configuration.installations)) as ImagePluginCollection[]
  }
  async pinned(): Promise<ImageRuleSnapshot> {
    await this.ready
    const installations = JSON.parse(JSON.stringify(this.configuration.installations)) as ImagePluginCollection[]
    return { schemaVersion: 1, records: installations.map((source: ImagePluginCollection): ImageRuleRecord => ({
      origin: source.origin, revision: '',
      plugins: source.plugins.filter((plugin: ImageProcessingPlugin): boolean => !source.disabledRules.includes(imageRuleKey(plugin.id, plugin.id))),
      pluginSettings: source.pluginSettings,
      packs: source.packs.map((pack: ImageRulePack): ImageRulePack => ({ schemaVersion: pack.schemaVersion,
        id: pack.id, version: pack.version, meta: pack.meta,
        rules: pack.rules.filter((rule: ImageBannerRule): boolean => !source.disabledRules.includes(imageRuleKey(pack.id, rule.id))) })) })) }
  }
  async exportSnapshot(): Promise<ImageRuleConfiguration> {
    await this.ready; this.assertReadable()
    return JSON.parse(JSON.stringify(this.configuration)) as ImageRuleConfiguration
  }
  async reload(): Promise<void> { this.generation += 1; this.ready = this.load(); await this.ready }
  private change(operation: (draft: ImageRuleConfiguration) => void, userChange: boolean = true, allowRecovery: boolean = false): Promise<void> {
    const write = this.writes.then(async (): Promise<void> => {
      await this.ready
      if (!allowRecovery) this.assertReadable()
      const draft = JSON.parse(JSON.stringify(this.configuration)) as ImageRuleConfiguration
      operation(draft)
      const next = validateImageRuleConfiguration(draft)
      await taskpool.execute<[string, string], void>(commitImageRules, this.path(), JSON.stringify(next))
      this.configuration = next
      connectImageRuleState().readFailed = false
      this.publishState(userChange)
    })
    this.writes = write.catch((): void => {})
    return write
  }
  async restore(value: Object): Promise<void> {
    this.generation += 1
    const valid = validateImageRuleConfiguration(JSON.parse(JSON.stringify(value)) as Object)
    await this.change((draft: ImageRuleConfiguration): void => { draft.subscriptions = valid.subscriptions; draft.installations = valid.installations }, true, true)
  }
  async fetchDocument(url: string): Promise<string> {
    const bytes = await this.resource(resolveIndexDocumentUrl(url))
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(bytes))
  }
  private async resource(url: string): Promise<ArrayBuffer> {
    if (!isValidHttpUrl(url)) throw new Error('invalid_image_rule_url')
    const request = http.createHttp()
    try {
      const response = await request.request(url, { method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false, connectTimeout: 10000, readTimeout: 15000,
        maxLimit: LIMIT })
      if (response.responseCode !== 200) throw new Error('image_rule_http_' + response.responseCode)
      if (!(response.result instanceof ArrayBuffer) || response.result.byteLength > LIMIT) throw new Error('invalid_image_rule_index')
      return response.result
    } finally { request.destroy() }
  }
  private async download(url: string, document?: string, isCurrent: () => boolean = (): boolean => true): Promise<ImageRuleSubscription> {
    const index = JSON.parse(document ?? await this.fetchDocument(url)) as ImageRuleIndex
    const pluginIndex = index.schemaVersion === 2 && index.kind === 'image_plugins'
    if ((!pluginIndex && (index.schemaVersion !== 1 || index.kind !== 'image_rules')) || !index.meta?.name?.trim() ||
      typeof index.revision !== 'string' || !index.revision || !Array.isArray(index.packs) ||
      index.packs.length === 0 || index.packs.length > 32) throw new Error('invalid_image_rule_index')
    const packs: ImageRulePack[] = []
    const catalog: ImageProcessingPlugin[] = []
    const manifestHashes: Record<string, string> = {}
    const ids: Set<string> = new Set()
    for (const reference of index.packs) {
      if (!isCurrent()) throw new Error('image_plugin_request_cancelled')
      if (typeof reference.id !== 'string' || ids.has(reference.id) || !/^[a-f0-9]{64}$/.test(reference.sha256))
        throw new Error('invalid_image_rule_reference')
      ids.add(reference.id)
      const manifestUrl = safeResolveIndexRelativeUrl(url, reference.path, '.json')
      const bytes = await this.resource(manifestUrl)
      const parsed = JSON.parse(await taskpool.execute<[ArrayBuffer, string], string>(validateImageRuleResource,
        bytes, JSON.stringify(reference))) as Object
      if (pluginIndex) {
        const plugin = validateImageProcessingPlugin(parsed)
        manifestHashes[plugin.id] = reference.sha256
        plugin.processor.path = safeResolveIndexRelativeUrl(manifestUrl, plugin.processor.path, '.wasm')
        catalog.push(plugin)
      } else {
        packs.push(validateImageRulePack(parsed))
      }
    }
    return { url, name: index.meta.name.trim(), description: index.meta.description,
      website: isValidHttpUrl(index.meta.website ?? '') ? index.meta.website : undefined,
      updatedAt: Date.now(), revision: index.revision, packs, catalog, manifestHashes }
  }
  async add(url: string, customName: string, document?: string, previousUrl?: string): Promise<void> {
    const normalized = resolveIndexDocumentUrl(url)
    await this.ready
    const epoch = (this.epochs.get(normalized) ?? 0) + 1
    this.epochs.set(normalized, epoch)
    const generation = this.generation
    const downloaded = await this.download(normalized, document)
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      if (generation !== this.generation || this.epochs.get(normalized) !== epoch) throw new Error('image_rule_request_cancelled')
      if (draft.subscriptions.some((s: ImageRuleSubscription): boolean => s.url === normalized && s.url !== previousUrl))
        throw new Error('image_rule_subscription_exists')
      const previous = previousUrl === undefined ? undefined : draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === previousUrl)
      if (previousUrl !== undefined && previous === undefined) throw new Error('image_rule_subscription_removed')
      downloaded.customName = customName.trim() || undefined
      downloaded.disabled = previous?.disabled
      draft.subscriptions = draft.subscriptions.filter((s: ImageRuleSubscription): boolean => s.url !== previousUrl)
      draft.subscriptions.push(downloaded)
    }, false))
  }
  async rename(url: string, customName: string): Promise<void> {
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const subscription = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === url)
      if (!subscription) throw new Error('image_rule_subscription_removed')
      subscription.customName = customName.trim() || undefined
    }, false))
  }
  async remove(url: string): Promise<void> {
    this.epochs.set(url, (this.epochs.get(url) ?? 0) + 1)
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      draft.subscriptions = draft.subscriptions.filter((s: ImageRuleSubscription): boolean => s.url !== url)
    }, false))
  }
  async setSubscriptionDisabled(url: string, disabled: boolean): Promise<void> {
    await this.ready
    this.epochs.set(url, (this.epochs.get(url) ?? 0) + 1)
    this.inFlight.delete(url)
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const saved = draft.subscriptions.find((item: ImageRuleSubscription): boolean => item.url === url)
      if (saved === undefined) throw new Error('image_rule_subscription_removed')
      saved.disabled = disabled || undefined
      if (disabled) saved.lastError = undefined
    }, false))
    if (!disabled) void this.refresh(url).catch((): void => {})
  }
  private collection(draft: ImageRuleConfiguration, origin: string, name: string): ImagePluginCollection {
    let installed = draft.installations.find((source: ImagePluginCollection): boolean => source.origin === origin)
    if (installed === undefined) {
      installed = { origin, name, plugins: [], packs: [], disabledRules: [], pluginSettings: {} }
      draft.installations.push(installed)
    }
    return installed
  }
  private ensureOrigin(draft: ImageRuleConfiguration, origin: string, id: string): void {
    if (draft.installations.some((source: ImagePluginCollection): boolean => source.origin !== origin &&
      (source.plugins.some((plugin: ImageProcessingPlugin): boolean => plugin.id === id) ||
        source.packs.some((pack: ImageRulePack): boolean => pack.id === id)))) throw new Error('image_plugin_source_conflict')
  }
  async setRuleEnabled(origin: string, packId: string, ruleId: string, enabled: boolean): Promise<void> {
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const source = draft.installations.find((value: ImagePluginCollection): boolean => value.origin === origin)
      if (!source) throw new Error('image_plugin_not_installed')
      if (enabled && draft.installations.some((other: ImagePluginCollection): boolean => other.origin !== origin &&
        (other.plugins.some((plugin: ImageProcessingPlugin): boolean => plugin.id === packId && !other.disabledRules.includes(imageRuleKey(packId, packId))) ||
          other.packs.some((pack: ImageRulePack): boolean => pack.id === packId && pack.rules.some((rule: ImageBannerRule): boolean =>
            !other.disabledRules.includes(imageRuleKey(packId, rule.id))))))) throw new Error('image_plugin_source_conflict')
      const key = imageRuleKey(packId, ruleId)
      source.disabledRules = source.disabledRules.filter((id: string): boolean => id !== key)
      source.conflicts = (source.conflicts ?? []).filter((id: string): boolean => id !== key)
      if (!enabled) source.disabledRules.push(key)
    }))
  }
  /** Catalog changes never install or activate content. Only explicit actions
   * change installed versions, retaining their position and user configuration. */
  async installPlugin(url: string, id: string, version?: number): Promise<void> {
    await this.ready; this.assertReadable()
    const offers = imagePluginOffers(this.configuration.subscriptions, id, url)
    const selected = offers[0]
    if (selected === undefined || (version !== undefined && selected.plugin.version !== version))
      throw new Error('image_plugin_not_in_catalog')
    if (imagePluginOffersConflict(offers)) throw new Error('image_plugin_source_conflict')
    this.ensureOrigin(this.configuration, url, id)
    const requestKey = JSON.stringify([url, id])
    const epoch = this.epochs.get(requestKey) ?? 0, generation = this.generation
    const routes = offers.filter((offer: ImagePluginOffer): boolean => offer === selected ||
      (offer.plugin.version === selected.plugin.version && offer.plugin.processor.sha256 === selected.plugin.processor.sha256 &&
        selected.manifestHash !== undefined && selected.manifestHash === offer.manifestHash))
    let used = selected
    let usedEpoch = 0
    let bytes: ArrayBuffer | undefined
    let failure: Error | undefined
    for (const offer of routes) {
      const address = offer.subscription.url
      const live = this.configuration.subscriptions.find((item: ImageRuleSubscription): boolean => item.url === address)
      if (live === undefined || live.disabled || live.revision !== offer.subscription.revision ||
        generation !== this.generation || epoch !== (this.epochs.get(requestKey) ?? 0)) continue
      usedEpoch = this.epochs.get(address) ?? 0
      try {
        bytes = await this.resource(offer.plugin.processor.path)
        used = offer
        break
      } catch (error) {
        failure = error as Error
        if (failure.message === 'invalid_image_rule_url' || failure.message === 'invalid_image_rule_index') throw failure
      }
    }
    if (bytes === undefined) throw failure ?? new Error('image_plugin_request_cancelled')
    const plugin = JSON.parse(JSON.stringify(used.plugin)) as ImageProcessingPlugin
    plugin.processor.moduleBase64 = await taskpool.execute<[ArrayBuffer, string], string>(validateImageProcessorModule, bytes, plugin.processor.sha256)
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const catalog = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === used.subscription.url)
      const current = catalog?.catalog?.find((p: ImageProcessingPlugin): boolean => p.id === id)
      if (!catalog || catalog.disabled || !current || current.processor.sha256 !== plugin.processor.sha256 || current.version !== plugin.version ||
        catalog.manifestHashes?.[id] !== used.manifestHash ||
        generation !== this.generation || epoch !== (this.epochs.get(requestKey) ?? 0) ||
        usedEpoch !== (this.epochs.get(catalog.url) ?? 0)) throw new Error('image_plugin_request_cancelled')
      catalog.lastDownloadAt = Date.now()
      this.ensureOrigin(draft, url, id)
      const source = this.collection(draft, url, catalog.customName || catalog.name)
      const index = source.plugins.findIndex((p: ImageProcessingPlugin): boolean => p.id === id)
      const legacy = source.packs.find((pack: ImageRulePack): boolean => pack.id === id)
      if (index >= 0) source.plugins[index] = plugin
      else source.plugins.push(plugin)
      source.packs = source.packs.filter((pack: ImageRulePack): boolean => pack.id !== id)
      if (index < 0) {
        const key = imageRuleKey(id, id)
        const legacyEnabled = legacy?.rules.some((rule: ImageBannerRule): boolean => !source.disabledRules.includes(imageRuleKey(id, rule.id))) ?? false
        source.disabledRules = source.disabledRules.filter((value: string): boolean => value !== key)
        if (!legacyEnabled) source.disabledRules.push(key)
      }
    }))
  }
  async installRulePack(url: string, id: string): Promise<void> {
    await this.ready; this.assertReadable()
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const catalog = draft.subscriptions.find((s: ImageRuleSubscription): boolean => !s.disabled && s.url === url)
      const offered = catalog?.packs.find((pack: ImageRulePack): boolean => pack.id === id)
      if (!catalog || !offered) throw new Error('image_plugin_not_in_catalog')
      this.ensureOrigin(draft, url, id)
      const source = this.collection(draft, url, catalog.customName || catalog.name)
      if (source.plugins.some((plugin: ImageProcessingPlugin): boolean => plugin.id === id)) throw new Error('image_plugin_already_installed')
      const index = source.packs.findIndex((pack: ImageRulePack): boolean => pack.id === id)
      const previous = index >= 0 ? source.packs[index] : undefined
      for (const rule of offered.rules) if (!previous?.rules.some((old: ImageBannerRule): boolean => old.id === rule.id) &&
        !source.disabledRules.includes(imageRuleKey(id, rule.id))) source.disabledRules.push(imageRuleKey(id, rule.id))
      if (index >= 0) source.packs[index] = offered
      else source.packs.push(offered)
    }))
  }
  async uninstallPlugin(origin: string, id: string, ruleId?: string): Promise<void> {
    const key = JSON.stringify([origin, id])
    this.epochs.set(key, (this.epochs.get(key) ?? 0) + 1)
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const source = draft.installations.find((s: ImagePluginCollection): boolean => s.origin === origin)
      if (!source) return
      source.plugins = source.plugins.filter((plugin: ImageProcessingPlugin): boolean => plugin.id !== id)
      source.packs = source.packs.map((pack: ImageRulePack): ImageRulePack => pack.id !== id || ruleId === undefined ? pack :
        { schemaVersion: pack.schemaVersion, id: pack.id, version: pack.version, meta: pack.meta,
          rules: pack.rules.filter((rule: ImageBannerRule): boolean => rule.id !== ruleId) })
        .filter((pack: ImageRulePack): boolean => pack.id !== id || (ruleId !== undefined && pack.rules.length > 0))
      const settings: Record<string, SettingsFieldValues> = {}
      for (const key of Object.keys(source.pluginSettings)) if (key !== id) settings[key] = source.pluginSettings[key]
      source.pluginSettings = settings
      draft.installations = draft.installations.filter((value: ImagePluginCollection): boolean => value.plugins.length > 0 || value.packs.length > 0)
    }))
  }
  async setPluginSettings(origin: string, id: string, values: SettingsFieldValues, expectedProcessor?: string): Promise<void> {
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const source = draft.installations.find((s: ImagePluginCollection): boolean => s.origin === origin)
      const plugin = source?.plugins.find((p: ImageProcessingPlugin): boolean => p.id === id)
      if (!source || !plugin) throw new Error('image_plugin_not_installed')
      if (expectedProcessor !== undefined && expectedProcessor !== JSON.stringify([plugin.version, plugin.processor.sha256]))
        throw new Error('image_plugin_settings_stale')
      source.pluginSettings[id] = imagePluginDefaults(plugin, values)
    }))
  }
  revalidateInBackground(): void {
    if (this.automaticCheckStarted) return
    this.automaticCheckStarted = true
    void this.checkUpdates().catch((): void => {})
  }

  // Startup and pull-to-refresh share one catalog check. Fetching metadata
  // never upgrades an installation or changes the active reader configuration.
  checkUpdates(): Promise<boolean> {
    if (this.pendingCheck !== undefined) return this.pendingCheck
    const request = this.checkSubscriptions()
    this.pendingCheck = request
    const retire = (): void => { if (this.pendingCheck === request) this.pendingCheck = undefined }
    void request.then(retire, retire)
    return request
  }

  private async checkSubscriptions(): Promise<boolean> {
    await this.ready
    this.assertReadable()
    const urls = this.configuration.subscriptions.filter((subscription: ImageRuleSubscription): boolean => !subscription.disabled)
      .map((subscription: ImageRuleSubscription): string => subscription.url)
    let complete = true
    for (const url of urls) {
      try { await this.refresh(url) } catch (_error) { complete = false }
    }
    return complete
  }

  refresh(url: string): Promise<void> {
    const pending = this.inFlight.get(url)
    if (pending) return pending
    const epoch = this.epochs.get(url) ?? 0
    const generation = this.generation
    const request = this.update(url).catch(async (error: Error): Promise<void> => {
      if (generation !== this.generation || epoch !== (this.epochs.get(url) ?? 0)) return
      await this.change((draft: ImageRuleConfiguration): void => {
        const saved = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === url)
        if (saved && !saved.disabled && generation === this.generation && epoch === (this.epochs.get(url) ?? 0))
          saved.lastError = 'image_rules_update_failed'
      }, false)
      throw error
    })
    this.inFlight.set(url, request)
    const retire = (): void => { if (this.inFlight.get(url) === request) this.inFlight.delete(url) }
    void request.then(retire, retire)
    return request
  }
  private async update(url: string): Promise<void> {
    await this.ready
    if (!this.configuration.subscriptions.some((s: ImageRuleSubscription): boolean => s.url === url && !s.disabled)) return
    const generation = this.generation, epoch = this.epochs.get(url) ?? 0
    const downloaded = await this.download(url, undefined, (): boolean =>
      generation === this.generation && epoch === (this.epochs.get(url) ?? 0))
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const saved = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === url)
      if (!saved || saved.disabled || generation !== this.generation || epoch !== (this.epochs.get(url) ?? 0)) return
      saved.name = downloaded.name; saved.description = downloaded.description; saved.website = downloaded.website
      saved.revision = downloaded.revision; saved.packs = downloaded.packs; saved.updatedAt = downloaded.updatedAt
      saved.catalog = downloaded.catalog; saved.manifestHashes = downloaded.manifestHashes; saved.lastError = undefined
    }, false))
  }
}
