import { util, url } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { AxiosHttpClient, AxiosTextResponse } from '../readerTranslation/network/AxiosHttpClient'
import { normalizeWebDavBaseUrl } from '../remote/WebDavClient'
import { mergeSyncWorks, parseSyncWorks, SyncWork, syncWorkKey } from './HistorySyncModel'

export interface HistorySyncConfig {
  enabled: boolean
  directoryUrl: string
  username: string
  password: string
}

export interface HistorySyncProvider {
  test(): Promise<void>
  reconcile(local: SyncWork[], active: () => boolean): Promise<SyncWork[]>
}

interface ShardRef {
  bucket: string
  hash: string
}

interface Manifest {
  schemaVersion: number
  shards: ShardRef[]
}

const MAX_SHARD_BYTES = 4 * 1024 * 1024
const MANIFEST_PATH = 'manifest.json'

function utf8(value: string): Uint8Array {
  return new util.TextEncoder().encodeInto(value)
}

function digest(value: string): string {
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: utf8(value) })
  return Array.from(md.digestSync().data).map((byte: number): string => byte.toString(16).padStart(2, '0')).join('')
}

function bucketFor(work: SyncWork): string {
  return digest(syncWorkKey(work)).substring(0, 2)
}

function strongEtag(value: string): boolean {
  return /^"[^"\r\n]+"$/.test(value)
}

export function validatedHistorySyncDirectory(raw: string): string {
  try {
    const parsed = url.URL.parseURL(raw.trim())
    if ((parsed.protocol === 'https:' || parsed.protocol === 'http:') && parsed.hostname.length > 0 &&
      parsed.username.length === 0 && parsed.password.length === 0 &&
      parsed.hash.length === 0 && parsed.search.length === 0) return normalizeWebDavBaseUrl(parsed.toString())
  } catch (_error) {
  }
  throw new Error('url')
}

function parseManifest(body: string): Manifest {
  const manifest = JSON.parse(body) as Manifest
  if (manifest === null || typeof manifest !== 'object' || manifest.schemaVersion !== 1 ||
    !Array.isArray(manifest.shards) || manifest.shards.length > 256) throw new Error('data')
  const buckets = new Set<string>()
  manifest.shards.forEach((ref: ShardRef): void => {
    if (ref === null || typeof ref !== 'object' || typeof ref.bucket !== 'string' ||
      typeof ref.hash !== 'string' || !/^[0-9a-f]{2}$/.test(ref.bucket) ||
      !/^[0-9a-f]{64}$/.test(ref.hash) || buckets.has(ref.bucket)) throw new Error('data')
    buckets.add(ref.bucket)
  })
  return manifest
}

export class WebDavHistorySync implements HistorySyncProvider {
  private readonly root: string
  private readonly authorization: string
  private verified: boolean = false
  private readonly shardCache = new Map<string, SyncWork[]>()

  constructor(config: HistorySyncConfig) {
    this.root = validatedHistorySyncDirectory(config.directoryUrl) + '/koma-history-v1/'
    this.authorization = config.username.length === 0 && config.password.length === 0 ? '' :
      'Basic ' + new util.Base64Helper().encodeToStringSync(utf8(config.username + ':' + config.password))
  }

  async test(): Promise<void> {
    const collection = await this.request('MKCOL', '')
    if (collection.statusCode !== 405) this.requireSuccess(collection)
    // Prove both preconditions against a disposable resource before trusting the
    // server with a real manifest. Existing remote history is untouched.
    const probe = 'probe-' + util.generateRandomUUID() + '.json'
    this.verified = false
    let verified = false
    try {
      this.requireSuccess(await this.request('PUT', probe, '1', 'If-None-Match', '*'))
      const original = await this.request('GET', probe)
      this.requireSuccess(original)
      if (original.body !== '1' || !strongEtag(original.etag)) throw new Error('conditions')
      const duplicate = await this.request('PUT', probe, '2', 'If-None-Match', '*')
      if (duplicate.statusCode !== 412) throw new Error('conditions')
      const stale = await this.request('PUT', probe, '2', 'If-Match', '"koma-stale"')
      if (stale.statusCode !== 412) throw new Error('conditions')
      this.requireSuccess(await this.request('PUT', probe, '2', 'If-Match', original.etag))
      const changed = await this.request('GET', probe)
      this.requireSuccess(changed)
      if (changed.body !== '2' || !strongEtag(changed.etag) || changed.etag === original.etag) throw new Error('conditions')
      verified = true
    } finally {
      const deleted = await this.request('DELETE', probe).catch((): AxiosTextResponse => new AxiosTextResponse())
      this.verified = verified && deleted.statusCode >= 200 && deleted.statusCode < 300
    }
    if (!this.verified) throw new Error('cleanup')
  }

  async reconcile(local: SyncWork[], active: () => boolean): Promise<SyncWork[]> {
    if (!this.verified) await this.test()
    for (let attempt = 0; attempt < 4; attempt += 1) {
      this.requireActive(active)
      const manifestResponse = await this.request('GET', MANIFEST_PATH)
      const exists = manifestResponse.statusCode !== 404
      if (exists) {
        this.requireSuccess(manifestResponse)
        if (!strongEtag(manifestResponse.etag)) throw new Error('conditions')
      }
      const manifest: Manifest = exists ? parseManifest(manifestResponse.body) : { schemaVersion: 1, shards: [] }
      const remote = await this.readShards(manifest)
      const merged = mergeSyncWorks(local, remote)
      const refs = await this.writeShards(manifest, merged, active)
      if (JSON.stringify(refs) === JSON.stringify(manifest.shards)) return merged
      this.requireActive(active)
      const updated: Manifest = { schemaVersion: 1, shards: refs }
      const published = await this.request('PUT', MANIFEST_PATH, JSON.stringify(updated),
        exists ? 'If-Match' : 'If-None-Match', exists ? manifestResponse.etag : '*')
      if (published.statusCode === 409 || published.statusCode === 412) continue
      this.requireSuccess(published)
      return merged
    }
    throw new Error('conflict')
  }

  private async readShards(manifest: Manifest): Promise<SyncWork[]> {
    const nextCache = new Map<string, SyncWork[]>()
    const works: SyncWork[] = []
    for (let start = 0; start < manifest.shards.length; start += 6) {
      const batch = manifest.shards.slice(start, start + 6)
      const loaded = await Promise.all(batch.map((ref: ShardRef): Promise<SyncWork[]> => this.readShard(ref)))
      batch.forEach((ref: ShardRef, index: number): void => {
        nextCache.set(ref.hash, loaded[index])
        loaded[index].forEach((work: SyncWork): void => { works.push(work) })
      })
    }
    this.shardCache.clear()
    nextCache.forEach((rows: SyncWork[], hash: string): void => { this.shardCache.set(hash, rows) })
    return works
  }

  private async readShard(ref: ShardRef): Promise<SyncWork[]> {
    const cached = this.shardCache.get(ref.hash)
    let rows: SyncWork[]
    if (cached !== undefined) {
      rows = cached
    } else {
      const response = await this.request('GET', this.shardPath(ref.hash))
      if (response.statusCode === 404) throw new Error('data')
      this.requireSuccess(response)
      if (digest(response.body) !== ref.hash) throw new Error('data')
      rows = parseSyncWorks(response.body)
    }
    if (rows.length === 0 || rows.some((work: SyncWork): boolean => bucketFor(work) !== ref.bucket)) throw new Error('data')
    return rows
  }

  private async writeShards(old: Manifest, works: SyncWork[], active: () => boolean): Promise<ShardRef[]> {
    const byBucket = new Map<string, SyncWork[]>()
    works.forEach((work: SyncWork): void => {
      const bucket = bucketFor(work)
      const existing = byBucket.get(bucket)
      if (existing === undefined) byBucket.set(bucket, [work])
      else existing.push(work)
    })
    const refs: ShardRef[] = []
    for (const bucket of Array.from(byBucket.keys()).sort()) {
      const rows = byBucket.get(bucket) as SyncWork[]
      const body = JSON.stringify(rows)
      if (utf8(body).byteLength > MAX_SHARD_BYTES) throw new Error('size')
      const hash = digest(body)
      refs.push({ bucket, hash })
      if (old.shards.some((ref: ShardRef): boolean => ref.bucket === bucket && ref.hash === hash)) continue
      this.requireActive(active)
      const response = await this.request('PUT', this.shardPath(hash), body, 'If-None-Match', '*')
      if (response.statusCode !== 412) this.requireSuccess(response)
      // Confirm the complete immutable object before publishing a reference to it.
      const stored = await this.request('GET', this.shardPath(hash))
      this.requireSuccess(stored)
      if (digest(stored.body) !== hash) throw new Error('data')
    }
    return refs
  }

  private shardPath(hash: string): string {
    return 'shard-' + hash + '.json'
  }

  private requireActive(active: () => boolean): void {
    if (!active()) throw new Error('cancelled')
  }

  private requireSuccess(response: AxiosTextResponse): void {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('http-' + response.statusCode.toString())
    }
  }

  private async request(method: string, path: string, body: string = '', condition: string = '',
    token: string = ''): Promise<AxiosTextResponse> {
    const headers: Record<string, string> = { 'Accept': 'application/json', 'Cache-Control': 'no-cache' }
    if (this.authorization.length > 0) headers['Authorization'] = this.authorization
    if (body.length > 0) headers['Content-Type'] = 'application/json; charset=utf-8'
    if (condition.length > 0) headers[condition] = token
    try {
      return await AxiosHttpClient.requestText(this.root + path, method, headers, body, 8000, 15000, MAX_SHARD_BYTES, 0)
    } catch (_error) {
      // Transport errors can carry a request config with the authorization header.
      throw new Error('network')
    }
  }
}
