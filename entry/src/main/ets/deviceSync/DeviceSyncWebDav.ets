import { util, url } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DavResource } from '../remote/WebDavModels'
import { parseWebDavMultiStatus, buildPropfindBody } from '../remote/WebDavClient'
import {
  copySyncManifest, decodeSyncManifest, syncDigest, syncShardPath, syncUtf8, SyncManifest, SyncObject,
  SyncDatasetRef, SyncShardRef, SYNC_COLLECTION, SYNC_MAX_OBJECT_BYTES, SYNC_MAX_ROUND_BYTES,
} from './DeviceSyncWire'
import { decodeSyncCommit, mergeSyncJournal, syncCommitBody, syncCommitName, SyncJournalCommit, SYNC_COMMIT_NAME } from './DeviceSyncJournal'

export interface SyncConnectionDraft {
  directory: string
  username: string
  password: string
}

export interface SyncRemoteManifest {
  manifest?: SyncManifest
  etag: string
  hash: string
  frontier?: string[]
  journal?: boolean
  legacyHash?: string
  legacyRevision?: number
  legacySpace?: string
}

interface SyncHttpResponse {
  status: number
  body: string
  etag: string
}

export type SyncRequestGuard = () => void

const MANIFEST = 'manifest.json'
const OBJECT_NAME = /^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/

export function canonicalSyncDirectory(input: string): string {
  try {
    const raw = input.trim()
    const parsed = url.URL.parseURL(raw)
    if (parsed.protocol === 'https:' && parsed.hostname.length > 0 && parsed.username.length === 0 &&
      parsed.password.length === 0 && !raw.includes('?') && !raw.includes('#') &&
      !/%2e|%2f|%5c|%00|\\/i.test(raw) && raw.length <= 1024) {
      return parsed.toString().replace(/\/+$/, '')
    }
  } catch (_error) {
  }
  throw new Error('sync_https_directory_required')
}

function responseTag(header: Object): string {
  const fields = header as Record<string, string>
  const key = Object.keys(fields).find((name: string): boolean => name.toLowerCase() === 'etag')
  return key === undefined || typeof fields[key] !== 'string' ? '' : fields[key].trim()
}

function requireSuccess(status: number): void {
  if (status >= 200 && status < 300) return
  if (status === 401) throw new Error('sync_authentication_failed')
  if (status === 403) throw new Error('sync_permission_denied')
  if (status === 405 || status === 501) throw new Error('sync_webdav_method_unsupported')
  if (status === 423) throw new Error('sync_remote_locked')
  if (status === 429) throw new Error('sync_server_busy')
  if (status === 507) throw new Error('sync_server_storage_full')
  if (status === 413) throw new Error('sync_request_too_large')
  if (status >= 300 && status < 400) throw new Error('sync_directory_redirected')
  if (status === 404) throw new Error('sync_directory_missing')
  throw new Error('sync_server_http_' + status.toString())
}

function conflict(status: number): boolean {
  return status === 409 || status === 412
}

/** No operation accepts a URL supplied by a manifest. Redirects are disabled by NetworkKit. */
export class DeviceSyncWebDav {
  private readonly directory: string
  private readonly root: string
  private readonly authorization: string
  private readonly witnesses: string[]
  private readonly space: string
  private legacyObjects: SyncShardRef[] = []

  constructor(draft: SyncConnectionDraft, witnesses: string[] = [], space: string = '') {
    this.directory = canonicalSyncDirectory(draft.directory) + '/'
    this.root = this.directory + SYNC_COLLECTION + '/'
    this.witnesses = witnesses.slice()
    const identity = syncDigest(JSON.stringify([canonicalSyncDirectory(draft.directory), draft.username.trim()]))
    this.space = space || identity.substring(0, 8) + '-' + identity.substring(8, 12) + '-' + identity.substring(12, 16) +
      '-' + identity.substring(16, 20) + '-' + identity.substring(20, 32)
    if (draft.username.includes(':') || /[\r\n\u0000]/.test(draft.username) ||
      (draft.username.length === 0 && draft.password.length > 0)) throw new Error('sync_invalid_username')
    this.authorization = draft.username.length === 0 ? '' :
      'Basic ' + new util.Base64Helper().encodeToStringSync(syncUtf8(draft.username + ':' + draft.password))
  }

  spaceId(): string { return this.space }

  async readLegacyManifest(guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const response = await this.requestAt('GET', this.directory + 'koma-device-sync-v1/manifest.json', guard)
    if (response.status === 404) return { etag: '', hash: '' }
    requireSuccess(response.status)
    const manifest = decodeSyncManifest(response.body)
    this.legacyObjects = manifest.datasets.concat(manifest.previous).flatMap((ref: SyncDatasetRef): SyncShardRef[] => ref.shards)
    return { manifest, etag: response.etag, hash: syncDigest(response.body) }
  }

  async probe(id: string, guard: SyncRequestGuard): Promise<void> {
    if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('sync_invalid_probe')
    await this.ensureCollection(this.directory, guard)
    await this.ensureCollection(this.root, guard)
    const path = 'probe-' + id + '.json'
    const first = '{"probe":1}'
    const next = '{"probe":2}'
    let primaryError: Error | undefined
    try {
      requireSuccess((await this.request('PUT', path, guard, first, '', true)).status)
      const loaded = await this.request('GET', path, guard)
      requireSuccess(loaded.status)
      if (loaded.body !== first) throw new Error('sync_response_invalid')
      requireSuccess((await this.request('PUT', path, guard, next)).status)
      const updated = await this.request('GET', path, guard)
      requireSuccess(updated.status)
      if (updated.body !== next) throw new Error('sync_response_invalid')
    } catch (error) {
      primaryError = error as Error
      throw primaryError
    } finally {
      try {
        await this.cleanProbe(id, guard)
      } catch (error) {
        if (primaryError === undefined) throw new Error('sync_probe_cleanup_' + (error as Error).message)
      }
    }
  }

  private async ensureCollection(address: string, guard: SyncRequestGuard): Promise<void> {
    const body = '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>'
    let result = await this.requestAt('PROPFIND', address, guard, body, '', false, '0')
    if (result.status === 404) {
      const created = await this.requestAt('MKCOL', address, guard)
      if (created.status === 409) throw new Error('sync_directory_parent_missing')
      if (created.status !== 405) requireSuccess(created.status)
      result = await this.requestAt('PROPFIND', address, guard, body, '', false, '0')
    }
    requireSuccess(result.status)
    if (result.status !== 207) throw new Error('sync_not_webdav_directory')
    const resource = parseWebDavMultiStatus(result.body, address).find((item: DavResource): boolean =>
      item.href.replace(/\/+$/, '') === address.replace(/\/+$/, ''))
    if (resource === undefined) throw new Error('sync_not_webdav_directory')
    if (!resource.isCollection) throw new Error('sync_path_not_directory')
  }

  async cleanProbe(id: string, guard: SyncRequestGuard, legacy: boolean = false): Promise<void> {
    if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('sync_invalid_probe')
    const path = 'probe-' + id + '.json'
    const address = (legacy ? this.directory + 'koma-device-sync-v1/' : this.root) + path
    const result = await this.requestAt('DELETE', address, guard)
    if (result.status !== 404) requireSuccess(result.status)
    const checked = await this.requestAt('GET', address, guard)
    if (checked.status !== 404) {
      requireSuccess(checked.status)
      throw new Error('sync_probe_cleanup_pending')
    }
  }

  async readManifest(guard: SyncRequestGuard, requiredTag: string = ''): Promise<SyncRemoteManifest> {
    const listing = await this.request('PROPFIND', '', guard, buildPropfindBody())
    if (listing.status !== 404) requireSuccess(listing.status)
    if (listing.status !== 404 && listing.status !== 207) throw new Error('sync_collection_listing_failed')
    const names = new Set<string>(this.witnesses)
    if (listing.status === 207) parseWebDavMultiStatus(listing.body, this.root).forEach((item: DavResource): void => {
      if (!item.isCollection && item.href.startsWith(this.root)) {
        const name = item.href.substring(this.root.length)
        if (SYNC_COMMIT_NAME.test(name)) names.add(name)
      }
    })
    const commits = new Map<string, SyncJournalCommit>()
    const parents = new Set<string>()
    let budget = SYNC_MAX_ROUND_BYTES
    // Direct GET witnesses and all parents: a cached/incomplete listing must never erase a seen branch.
    const pending = Array.from(names).sort()
    while (pending.length > 0) {
      const name = pending.shift()!
      if (commits.has(name)) continue
      if (!SYNC_COMMIT_NAME.test(name) || commits.size >= 16384) throw new Error('sync_round_too_large')
      const loaded = await this.request('GET', name, guard)
      if (loaded.status === 404) throw new Error('sync_space_changed')
      requireSuccess(loaded.status)
      budget -= syncUtf8(loaded.body).byteLength
      if (budget < 0) throw new Error('sync_round_too_large')
      const commit = decodeSyncCommit(name, loaded.body)
      commits.set(name, commit)
      commit.parents.forEach((parent: string): void => { parents.add(parent); if (!commits.has(parent)) pending.push(parent) })
    }
    const frontier = Array.from(commits.keys()).filter((name: string): boolean => !parents.has(name)).sort()
    if (commits.size > 0 && frontier.length === 0) throw new Error('sync_invalid_commit')
    let result: SyncRemoteManifest
    if (frontier.length > 0) {
      const manifest = mergeSyncJournal(frontier.map((name: string): SyncJournalCommit => commits.get(name)!), this.space)
      result = { manifest, hash: syncDigest(JSON.stringify(manifest)),
        etag: '"journal-' + syncDigest(frontier.join('\n')) + '"', frontier, journal: true }
      this.legacyObjects = []
    } else {
      const legacy = await this.requestAt('GET', this.directory + 'koma-device-sync-v1/manifest.json', guard)
      if (legacy.status !== 404) requireSuccess(legacy.status)
      if (legacy.status === 404) result = { etag: '', hash: '', frontier: [], journal: true }
      else {
        const old = decodeSyncManifest(legacy.body)
        const manifest = copySyncManifest(old, this.space)
        manifest.schema = 2
        manifest.minWriter = 2
        manifest.maintenance = false
        this.legacyObjects = old.datasets.concat(old.previous).flatMap((ref: SyncDatasetRef): SyncShardRef[] => ref.shards)
        result = { manifest, hash: syncDigest(JSON.stringify(manifest)), etag: '"legacy-' + syncDigest(legacy.body) + '"',
          frontier: [], journal: true, legacyHash: syncDigest(legacy.body), legacyRevision: old.revision, legacySpace: old.space }
      }
    }
    if (requiredTag !== '' && requiredTag !== result.etag) throw new Error('sync_preview_changed')
    this.witnesses.splice(0, this.witnesses.length, ...(result.frontier ?? []))
    return result
  }

  async readObject(ref: SyncShardRef, guard: SyncRequestGuard): Promise<string> {
    const result = await this.request('GET', syncShardPath(ref), guard)
    if (result.status === 404 && this.legacyObjects.some((old: SyncShardRef): boolean => syncShardPath(old) === syncShardPath(ref))) {
      const legacy = await this.requestAt('GET', this.directory + 'koma-device-sync-v1/' + syncShardPath(ref), guard)
      if (legacy.status === 404) throw new Error('sync_shard_missing')
      requireSuccess(legacy.status)
      return legacy.body
    }
    if (result.status === 404) throw new Error('sync_shard_missing')
    requireSuccess(result.status)
    return result.body
  }

  async storeObject(object: SyncObject, guard: SyncRequestGuard): Promise<void> {
    const path = syncShardPath(object.ref)
    if (syncDigest(object.body) !== object.ref.hash || syncUtf8(object.body).byteLength !== object.ref.bytes) {
      throw new Error('sync_shard_damaged')
    }
    const before = await this.request('GET', path, guard)
    if (before.status !== 404) {
      requireSuccess(before.status)
      if (before.body !== object.body) throw new Error('sync_shard_damaged')
      return
    }
    requireSuccess((await this.request('PUT', path, guard, object.body)).status)
    const existing = await this.readObject(object.ref, guard)
    if (existing !== object.body) throw new Error('sync_shard_damaged')
  }

  commitName(manifest: SyncManifest, frontier: string[]): string {
    return syncCommitName(syncCommitBody(manifest, frontier))
  }

  commitBody(manifest: SyncManifest, frontier: string[]): string { return syncCommitBody(manifest, frontier) }

  async retryCommit(body: string, guard: SyncRequestGuard, selected: string[]): Promise<SyncRemoteManifest> {
    const name = syncCommitName(body)
    const commit = decodeSyncCommit(name, body)
    for (const parent of commit.parents) {
      if (await this.readCommit(parent, guard) === undefined) throw new Error('sync_space_changed')
    }
    const checked = new Set<string>()
    let budget = SYNC_MAX_ROUND_BYTES
    for (const dataset of commit.manifest.datasets.concat(commit.manifest.alternatives ?? [])) {
      // Disabled and unknown groups remain opaque on recovery, just as on a normal round.
      if (!selected.includes(dataset.id)) continue
      for (const ref of dataset.shards) {
        const path = syncShardPath(ref)
        if (checked.has(path)) continue
        budget -= ref.bytes
        if (budget < 0) throw new Error('sync_round_too_large')
        const content = await this.readObject(ref, guard)
        if (syncDigest(content) !== ref.hash || syncUtf8(content).byteLength !== ref.bytes) throw new Error('sync_shard_damaged')
        checked.add(path)
      }
    }
    requireSuccess((await this.request('PUT', name, guard, body)).status)
    const receipt = await this.readCommit(name, guard)
    if (receipt === undefined) throw new Error('sync_remote_result_unknown')
    return receipt
  }

  async readCommit(name: string, guard: SyncRequestGuard): Promise<SyncRemoteManifest | undefined> {
    if (!SYNC_COMMIT_NAME.test(name)) throw new Error('sync_invalid_commit')
    const result = await this.request('GET', name, guard)
    if (result.status === 404) return undefined
    requireSuccess(result.status)
    const commit = decodeSyncCommit(name, result.body)
    const manifest = copySyncManifest(commit.manifest, this.space)
    return { manifest, hash: syncDigest(JSON.stringify(manifest)), etag: '"journal-' + syncDigest(name) + '"',
      frontier: [name], journal: true }
  }

  async publish(manifest: SyncManifest, tag: string, guard: SyncRequestGuard,
    beforeSend: () => void = (): void => {}): Promise<boolean> {
    // Migration is a one-time remote-object preservation, never a local apply of disabled groups.
    for (const ref of this.legacyObjects) await this.storeObject({ ref, body: await this.readObject(ref, guard) }, guard)
    const current = await this.readManifest(guard)
    if (current.etag !== tag) return false
    const body = syncCommitBody(manifest, current.frontier ?? [])
    const name = syncCommitName(body)
    guard()
    beforeSend()
    requireSuccess((await this.request('PUT', name, guard, body)).status)
    const receipt = await this.readCommit(name, guard)
    if (receipt === undefined || receipt.hash !== syncDigest(JSON.stringify(manifest))) throw new Error('sync_remote_result_unknown')
    return true
  }

  async sweepable(manifest: SyncManifest, guard: SyncRequestGuard): Promise<string[]> {
    // Journal ancestors and concurrent writers retain references. V1 epoch GC is inapplicable.
    return []
  }

  async removeUnreferenced(path: string, guard: SyncRequestGuard): Promise<void> {
    throw new Error('sync_journal_gc_unavailable')
  }

  private async request(method: string, path: string, guard: SyncRequestGuard, body: string = '',
    tag: string = '', create: boolean = false): Promise<SyncHttpResponse> {
    if (path.length > 0 && path !== MANIFEST && !OBJECT_NAME.test(path) && !SYNC_COMMIT_NAME.test(path) && !/^probe-[0-9a-f-]{36}\.json$/.test(path)) {
      throw new Error('sync_invalid_path')
    }
    return this.requestAt(method, this.root + path, guard, body, tag, create)
  }

  private async requestAt(method: string, address: string, guard: SyncRequestGuard, body: string = '',
    tag: string = '', create: boolean = false, depth: string = '1'): Promise<SyncHttpResponse> {
    guard()
    // Initialization may create the exact user-selected directory, never its ancestors.
    const legacyRoot = this.directory + 'koma-device-sync-v1/'
    const legacyName = address.startsWith(legacyRoot) ? address.substring(legacyRoot.length) : ''
    const legacyAllowed = (method === 'GET' && (legacyName === MANIFEST || OBJECT_NAME.test(legacyName))) ||
      ((method === 'GET' || method === 'DELETE') && /^probe-[0-9a-f-]{36}\.json$/.test(legacyName))
    if (address !== this.directory && !address.startsWith(this.root) && !legacyAllowed) throw new Error('sync_invalid_path')
    const headers: Record<string, string> = {
      'Accept': method === 'PROPFIND' ? 'application/xml' : 'application/json',
      'Cache-Control': 'no-cache, no-store',
    }
    if (this.authorization.length > 0) headers['Authorization'] = this.authorization
    if (method === 'PROPFIND') headers['Depth'] = depth
    if (body.length > 0) headers['Content-Type'] = method === 'PROPFIND' ? 'application/xml' : 'application/json'
    if (tag.length > 0) headers['If-Match'] = tag
    if (create) headers['If-None-Match'] = '*'
    const request = http.createHttp()
    let response: http.HttpResponse
    try {
      response = await request.request(address, {
        customMethod: method, maxRedirects: 0, usingCache: false, header: headers,
        extraData: body.length === 0 ? undefined : body,
        connectTimeout: 5000, readTimeout: 10000, maxLimit: SYNC_MAX_OBJECT_BYTES,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
      })
    } catch (error) {
      const code = (error as BusinessError).code
      if (code === 2300047) throw new Error('sync_directory_redirected')
      if (code === 2300060 || code === 2300051 || code === 2300035) throw new Error('sync_tls_failed')
      if (code === 2300006 || code === 2300005) throw new Error('sync_host_unresolved')
      if (code === 2300028) throw new Error('sync_network_timeout')
      if (code === 2300003 || code === 2300001) throw new Error('sync_https_directory_required')
      throw new Error('sync_network_failed')
    } finally {
      request.destroy()
    }
    guard()
    const data = response.result instanceof ArrayBuffer ? new Uint8Array(response.result) : new Uint8Array(0)
    let text = ''
    try {
      text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(data)
    } catch (_error) {
      if (response.responseCode >= 200 && response.responseCode < 300) throw new Error('sync_response_invalid')
    }
    return { status: response.responseCode, body: text, etag: responseTag(response.header) }
  }
}
