import { common } from '@kit.AbilityKit'
import { taskpool, util } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { writeAppTextFile } from './AppFileTextPersistence'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { ImageRuleDescriptor, ImageRuleSnapshot, ImageRuleRecord, ImageRuleIndex, ImageRulePack,
  ImageRulePackReference, validateImageRulePack, validateImageRuleSnapshot } from './ImageBannerRules'
import { isValidHttpUrl, safeResolveIndexRelativeUrl } from '../sourceRuntime/SourceIndexMetadata'

const LIMIT = 4 * 1024 * 1024


@Concurrent
function readImageRules(path: string): string {
  if (!fs.accessSync(path)) return ''
  if (fs.statSync(path).size > 4 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
  const text = fs.readTextSync(path)
  validateImageRuleSnapshot(JSON.parse(text) as Object)
  return text
}

@Concurrent
function commitImageRules(path: string, payload: string): void {
  if (payload.length > 4 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
  validateImageRuleSnapshot(JSON.parse(payload) as Object)
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
  if (pack.id !== reference.id || pack.version !== reference.version) throw new Error('image_rule_identity_mismatch')
  return JSON.stringify(pack)
}

/** One local snapshot owner. Readers pin a copy; background publication never resets visible pages.
 * Unsubscribing stops calls to sync; acquired data stays usable like installed sources.
 */
export class ImageRuleStore {
  private static instances: Map<string, ImageRuleStore> = new Map()
  private ready: Promise<void>
  private snapshot: ImageRuleSnapshot = { schemaVersion: 1, records: [] }
  private generation: number = 0
  private writes: Promise<void> = Promise.resolve()
  private inFlight: Map<string, Promise<void>> = new Map()
  private context: common.Context
  private constructor(context: common.Context) { this.context = context; this.ready = this.load() }
  static forContext(context: common.Context): ImageRuleStore {
    let store = ImageRuleStore.instances.get(context.filesDir)
    if (store === undefined) { store = new ImageRuleStore(context); ImageRuleStore.instances.set(context.filesDir, store) }
    return store
  }
  private async load(): Promise<void> {
    // Generic bundled data is an offline compatibility seed, never a source/domain branch.
    const bytes = await this.context.resourceManager.getRawFileContent('image-rules-bootstrap.json')
    const pack = validateImageRulePack(JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as Object)
    this.snapshot = { schemaVersion: 1, records: [{ origin: 'builtin:compatibility', revision: '1', packs: [pack] }] }
    try {
      const saved = await taskpool.execute<[string], string>(readImageRules, `${this.context.filesDir}/image-rules.v1.json`)
      if (saved) this.snapshot = validateImageRuleSnapshot(JSON.parse(saved) as Object)
    } catch (_error) { /* A damaged update never removes the offline compatibility seed. */ }
  }
  async pinned(): Promise<ImageRuleSnapshot> {
    await this.ready
    return JSON.parse(JSON.stringify(this.snapshot)) as ImageRuleSnapshot
  }
  async reload(): Promise<void> { this.generation += 1; this.ready = this.load(); await this.ready }
  async exportSnapshot(): Promise<ImageRuleSnapshot> { return this.pinned() }
  async restore(snapshot: ImageRuleSnapshot): Promise<void> {
    this.generation += 1
    const valid = validateImageRuleSnapshot(JSON.parse(JSON.stringify(snapshot)) as Object)
    await this.ready
    await this.publish(valid)
  }
  private publish(snapshot: ImageRuleSnapshot): Promise<void> {
    const write = this.writes.then(async (): Promise<void> => {
      await taskpool.execute<[string, string], void>(commitImageRules,
        `${this.context.filesDir}/image-rules.v1.json`, JSON.stringify(snapshot))
      this.snapshot = snapshot
    })
    this.writes = write.catch((): void => {})
    return write
  }
  private async resource(url: string): Promise<ArrayBuffer> {
    if (!isValidHttpUrl(url)) throw new Error('invalid_image_rule_url')
    const request = http.createHttp()
    try {
      const response = await request.request(url, { method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false, connectTimeout: 5000, readTimeout: 10000,
        maxLimit: LIMIT })
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) || response.result.byteLength > LIMIT)
        throw new Error('image_rule_fetch_failed')
      return response.result
    } finally { request.destroy() }
  }
  sync(origin: string, descriptor: ImageRuleDescriptor, isCurrent: () => Promise<boolean>): Promise<void> {
    const pending = this.inFlight.get(origin)
    if (pending !== undefined) return pending
    const result = this.synchronize(origin, descriptor, isCurrent)
    this.inFlight.set(origin, result)
    const retire = (): void => { if (this.inFlight.get(origin) === result) this.inFlight.delete(origin) }
    void result.then(retire, retire)
    return result
  }
  private async synchronize(origin: string, descriptor: ImageRuleDescriptor, isCurrent: () => Promise<boolean>): Promise<void> {
    await this.ready
    const generation = this.generation
    const bytes = await this.resource(descriptor.indexUrl)
    const index = JSON.parse(util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(bytes))) as ImageRuleIndex
    if (index.schemaVersion !== 1 || typeof index.revision !== 'string' || !index.revision ||
      !Array.isArray(index.packs) || index.packs.length === 0 || index.packs.length > 32) throw new Error('invalid_image_rule_index')
    if (this.snapshot.records.some((r: ImageRuleRecord): boolean => r.origin === origin && r.revision === index.revision)) return
    const packs: ImageRulePack[] = []
    const ids: Set<string> = new Set()
    for (const reference of index.packs) {
      if (typeof reference.id !== 'string' || ids.has(reference.id) || !/^[a-f0-9]{64}$/.test(reference.sha256))
        throw new Error('invalid_image_rule_reference')
      ids.add(reference.id)
      const url = safeResolveIndexRelativeUrl(descriptor.indexUrl, reference.path, '.json')
      const data = await this.resource(url)
      packs.push(JSON.parse(await taskpool.execute<[ArrayBuffer, string], string>(validateImageRuleResource,
        data, JSON.stringify(reference))) as ImageRulePack)
    }
    await BackupRestoreActivity.runWrite(async (): Promise<void> => {
      // Serialize the merge, not just the final disk write, so independent subscriptions cannot lose each other.
      const write = this.writes.then(async (): Promise<void> => {
        if (generation !== this.generation || !await isCurrent()) return
        const records = this.snapshot.records.filter((r: ImageRuleRecord): boolean => r.origin !== origin &&
          !(r.origin === 'builtin:compatibility' && packs.some((p: ImageRulePack): boolean => p.id === 'edge-banners')))
        records.push({ origin, revision: index.revision, packs })
        const next: ImageRuleSnapshot = { schemaVersion: 1, records }
        await taskpool.execute<[string, string], void>(commitImageRules,
          `${this.context.filesDir}/image-rules.v1.json`, JSON.stringify(next))
        this.snapshot = next
        console.info('[ImageRules] published revision=' + index.revision)
      })
      this.writes = write.catch((): void => {})
      await write
    })
  }
}
