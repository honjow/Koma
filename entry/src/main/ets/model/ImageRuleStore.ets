import { common } from '@kit.AbilityKit'
import { taskpool, util } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { writeAppTextFile } from './AppFileTextPersistence'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { connectImageRuleState } from '../state/ImageRuleState'
import { ImageBannerRule, ImageRuleRecord, ImageRuleSnapshot, ImageRuleConfiguration, ImageRuleSubscription, ImageRuleIndex, ImageRulePack,
  ImageRulePackReference, validateImageRulePack, validateImageRuleConfiguration, imageRuleKey } from './ImageBannerRules'
import { isValidHttpUrl, resolveIndexDocumentUrl, safeResolveIndexRelativeUrl, parseIndexEntriesDocument } from '../sourceRuntime/SourceIndexMetadata'

const LIMIT = 4 * 1024 * 1024

@Concurrent
function readImageRules(path: string): string {
  if (!fs.accessSync(path)) return ''
  if (fs.statSync(path).size > 4 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
  return JSON.stringify(validateImageRuleConfiguration(JSON.parse(fs.readTextSync(path)) as Object))
}
@Concurrent
function commitImageRules(path: string, payload: string): void {
  if (payload.length > 4 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
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
  const pack = validateImageRulePack(JSON.parse(text) as Object)
  if (pack.id !== reference.id || pack.version !== reference.version || !pack.meta?.name?.trim() ||
    pack.rules.some((rule: ImageBannerRule): boolean => !rule.name?.trim() || !rule.description?.trim()))
    throw new Error('invalid_image_rule_details')
  return JSON.stringify(pack)
}
@Concurrent
export function subscriptionDocumentKind(payload: string): string {
  const value = JSON.parse(payload) as Object
  if (!Array.isArray(value) && (value as ImageRuleIndex)?.kind === 'image_rules') return 'image_rules'
  return parseIndexEntriesDocument(value) !== undefined ? 'source' : 'unknown'
}

/** Explicit rule subscriptions only. There is no bundled rule data or source-repository discovery.
 * The common subscription page combines two typed providers; source installation never consumes these records.
 * Old implicit snapshots are not evidence that a user subscribed, so they restore inactive.
 */
export class ImageRuleStore {
  private static instances: Map<string, ImageRuleStore> = new Map()
  private ready: Promise<void>
  private configuration: ImageRuleConfiguration = { schemaVersion: 2, subscriptions: [] }
  private writes: Promise<void> = Promise.resolve()
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
    this.configuration = { schemaVersion: 2, subscriptions: [] }
    try {
      const saved = await taskpool.execute<[string], string>(readImageRules, this.path())
      if (saved) this.configuration = validateImageRuleConfiguration(JSON.parse(saved) as Object)
    } catch (_error) { /* No valid subscription means no active rules, never an implicit fallback. */ }
    this.publishState(false)
  }
  private publishState(userChange: boolean): void {
    const state = connectImageRuleState()
    state.enabledRuleCount = this.configuration.subscriptions.filter((s: ImageRuleSubscription): boolean => s.enabled)
      .reduce((sum: number, s: ImageRuleSubscription): number => sum + s.packs.reduce((count: number, p: ImageRulePack): number =>
        count + p.rules.filter((rule: ImageBannerRule): boolean => !s.disabledRules.includes(imageRuleKey(p.id, rule.id))).length, 0), 0)
    state.dataRevision += 1
    if (userChange) state.userRevision += 1
  }
  async list(): Promise<ImageRuleSubscription[]> { await this.ready; return JSON.parse(JSON.stringify(this.configuration.subscriptions)) as ImageRuleSubscription[] }
  async pinned(): Promise<ImageRuleSnapshot> {
    const subscriptions = await this.list()
    return { schemaVersion: 1, records: subscriptions.filter((s: ImageRuleSubscription): boolean => s.enabled)
      .map((s: ImageRuleSubscription): ImageRuleRecord => ({ origin: s.url, revision: s.revision,
        packs: s.packs.map((pack: ImageRulePack): ImageRulePack => ({ schemaVersion: pack.schemaVersion,
          id: pack.id, version: pack.version, meta: pack.meta,
          rules: pack.rules.filter((rule: ImageBannerRule): boolean => !s.disabledRules.includes(imageRuleKey(pack.id, rule.id))) })) })) }
  }
  async exportSnapshot(): Promise<ImageRuleConfiguration> { await this.ready; return JSON.parse(JSON.stringify(this.configuration)) as ImageRuleConfiguration }
  async reload(): Promise<void> { this.generation += 1; this.ready = this.load(); await this.ready }
  private change(operation: (draft: ImageRuleConfiguration) => void, userChange: boolean = true): Promise<void> {
    const write = this.writes.then(async (): Promise<void> => {
      await this.ready
      const draft = await this.exportSnapshot()
      operation(draft)
      const next = validateImageRuleConfiguration(draft)
      await taskpool.execute<[string, string], void>(commitImageRules, this.path(), JSON.stringify(next))
      this.configuration = next
      this.publishState(userChange)
    })
    this.writes = write.catch((): void => {})
    return write
  }
  async restore(value: Object): Promise<void> {
    this.generation += 1
    const valid = validateImageRuleConfiguration(JSON.parse(JSON.stringify(value)) as Object)
    await this.change((draft: ImageRuleConfiguration): void => { draft.subscriptions = valid.subscriptions })
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
  private async download(url: string, document?: string): Promise<ImageRuleSubscription> {
    const index = JSON.parse(document ?? await this.fetchDocument(url)) as ImageRuleIndex
    if (index.schemaVersion !== 1 || index.kind !== 'image_rules' || !index.meta?.name?.trim() ||
      typeof index.revision !== 'string' || !index.revision || !Array.isArray(index.packs) ||
      index.packs.length === 0 || index.packs.length > 32) throw new Error('invalid_image_rule_index')
    const packs: ImageRulePack[] = []
    const ids: Set<string> = new Set()
    for (const reference of index.packs) {
      if (typeof reference.id !== 'string' || ids.has(reference.id) || !/^[a-f0-9]{64}$/.test(reference.sha256))
        throw new Error('invalid_image_rule_reference')
      ids.add(reference.id)
      const bytes = await this.resource(safeResolveIndexRelativeUrl(url, reference.path, '.json'))
      packs.push(JSON.parse(await taskpool.execute<[ArrayBuffer, string], string>(validateImageRuleResource,
        bytes, JSON.stringify(reference))) as ImageRulePack)
    }
    return { url, name: index.meta.name.trim(), description: index.meta.description,
      website: isValidHttpUrl(index.meta.website ?? '') ? index.meta.website : undefined,
      enabled: true, automaticUpdates: true, disabledRules: [], updatedAt: Date.now(), revision: index.revision, packs }
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
      if (previous !== undefined) {
        downloaded.enabled = previous.enabled; downloaded.automaticUpdates = previous.automaticUpdates
        downloaded.disabledRules = previous.disabledRules
      }
      draft.subscriptions = draft.subscriptions.filter((s: ImageRuleSubscription): boolean => s.url !== previousUrl)
      draft.subscriptions.push(downloaded)
    }))
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
    }))
  }
  async setEnabled(url: string, enabled: boolean, automatic: boolean = false): Promise<void> {
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const subscription = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === url)
      if (!subscription) throw new Error('image_rule_subscription_removed')
      if (automatic) subscription.automaticUpdates = enabled
      else subscription.enabled = enabled
    }, !automatic))
  }
  async setRuleEnabled(url: string, packId: string, ruleId: string, enabled: boolean): Promise<void> {
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const subscription = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === url)
      if (!subscription) throw new Error('image_rule_subscription_removed')
      const key = imageRuleKey(packId, ruleId)
      subscription.disabledRules = subscription.disabledRules.filter((id: string): boolean => id !== key)
      if (!enabled) subscription.disabledRules.push(key)
    }))
  }
  refresh(url: string): Promise<void> {
    const pending = this.inFlight.get(url)
    if (pending) return pending
    const request = this.update(url)
    this.inFlight.set(url, request)
    const retire = (): void => { if (this.inFlight.get(url) === request) this.inFlight.delete(url) }
    void request.then(retire, retire)
    return request
  }
  private async update(url: string): Promise<void> {
    await this.ready
    if (!this.configuration.subscriptions.some((s: ImageRuleSubscription): boolean => s.url === url)) return
    const generation = this.generation, epoch = this.epochs.get(url) ?? 0
    const downloaded = await this.download(url)
    await BackupRestoreActivity.runWrite(() => this.change((draft: ImageRuleConfiguration): void => {
      const saved = draft.subscriptions.find((s: ImageRuleSubscription): boolean => s.url === url)
      if (!saved || generation !== this.generation || epoch !== (this.epochs.get(url) ?? 0)) return
      saved.name = downloaded.name; saved.description = downloaded.description; saved.website = downloaded.website
      saved.revision = downloaded.revision; saved.packs = downloaded.packs; saved.updatedAt = downloaded.updatedAt
    }, false))
  }
  async refreshAutomaticSubscriptions(): Promise<void> {
    const subscriptions = await this.list()
    for (const subscription of subscriptions) if (subscription.enabled && subscription.automaticUpdates &&
      Date.now() - subscription.updatedAt >= 24 * 60 * 60 * 1000) {
      try { await this.refresh(subscription.url) } catch (_error) { console.warn('[ImageRules] automatic_update_failed') }
    }
  }
}
