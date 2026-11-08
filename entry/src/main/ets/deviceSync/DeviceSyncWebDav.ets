import { taskpool, util, url } from '@kit.ArkTS'
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
  writer?: boolean
  own?: SyncManifest
  old?: SyncManifest
  warning?: string
  ownWritable?: boolean
  writerHeads?: SyncWriterHead[]
}

export interface SyncWriterHead {
  path: string
  manifest: SyncManifest
  segments: string[]
  listed: string[]
}

interface SyncHttpResponse {
  status: number
  body: string
  etag: string
}

export type SyncRequestGuard = () => void

@Concurrent
function parseSyncListing(xml: string, address: string): DavResource[] {
  return parseWebDavMultiStatus(xml, address)
}

async function readSyncListing(xml: string, address: string, guard: SyncRequestGuard): Promise<DavResource[]> {
  // A writer directory can contain many responses even when the latest head is unchanged.
  const resources = await taskpool.execute(parseSyncListing, xml, address) as DavResource[]
  guard()
  return resources
}

const MANIFEST = 'manifest.json'
const OBJECT_NAME = /^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/
const WRITER = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const WRITER_NAME = new RegExp('^' + WRITER + '$')
const WRITER_PUBLICATION = new RegExp('^(' + WRITER + ')/([0-9]{14})/([0-9]{16})-([0-9a-f]{64})\\.json$')
const SEGMENT_SIZE = 128
const LEGACY_DISCOVERY_MS = 5 * 60 * 1000

interface LegacyDiscovery {
  account: string
  space: string
  checked: number
  manifest: SyncRemoteManifest
  objects: SyncShardRef[]
}

const legacyDiscovery: LegacyDiscovery[] = []

function publicationSegment(sequence: number): string {
  return Math.floor((sequence - 1) / SEGMENT_SIZE).toString().padStart(14, '0')
}

interface SyncWriterPublication {
  writer: string
  manifest: SyncManifest
}

interface CachedJournalCommit {
  address: string
  commit: SyncJournalCommit
  bytes: number
}

// Only immutable, hash-validated content is cached. Directory listings and
// unlisted witnesses are fetched again to distinguish stale listings from loss.
const journalCache: CachedJournalCommit[] = []
let journalCacheBytes = 0

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
  private readonly writerRoot: string
  private readonly writer: string
  private readonly authorization: string
  private readonly witnesses: string[]
  private readonly space: string
  private readonly account: string
  private legacyObjects: SyncShardRef[] = []

  constructor(draft: SyncConnectionDraft, witnesses: string[] = [], space: string = '', writer: string = '') {
    this.directory = canonicalSyncDirectory(draft.directory) + '/'
    this.root = this.directory + SYNC_COLLECTION + '/'
    this.writerRoot = this.directory + 'koma-device-sync-v3/'
    if (writer !== '' && !WRITER_NAME.test(writer)) throw new Error('sync_invalid_writer')
    this.writer = writer
    this.witnesses = witnesses.slice()
    const identity = syncDigest(JSON.stringify([canonicalSyncDirectory(draft.directory), draft.username.trim()]))
    this.account = identity
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
      requireSuccess((await this.request('PUT', path, guard, first)).status)
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
    const resource = (await readSyncListing(result.body, address, guard)).find((item: DavResource): boolean =>
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

  private async readJournal(guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const listing = await this.request('PROPFIND', '', guard, buildPropfindBody())
    if (listing.status !== 404) requireSuccess(listing.status)
    if (listing.status !== 404 && listing.status !== 207) throw new Error('sync_collection_listing_failed')
    const listed = new Set<string>()
    if (listing.status === 207) (await readSyncListing(listing.body, this.root, guard)).forEach((item: DavResource): void => {
      if (!item.isCollection && item.href.startsWith(this.root)) {
        const name = item.href.substring(this.root.length)
        if (SYNC_COMMIT_NAME.test(name)) listed.add(name)
      }
    })
    const commits = new Map<string, SyncJournalCommit>()
    const parents = new Set<string>()
    let budget = SYNC_MAX_ROUND_BYTES
    // Direct GET witnesses and all parents: a cached/incomplete listing must never erase a seen branch.
    const pending = Array.from(new Set<string>(Array.from(listed).concat(this.witnesses.filter((name: string): boolean =>
      SYNC_COMMIT_NAME.test(name))))).sort()
    while (pending.length > 0) {
      const name = pending.shift()!
      if (commits.has(name)) continue
      if (!SYNC_COMMIT_NAME.test(name) || commits.size >= 16384) throw new Error('sync_round_too_large')
      const address = this.account + ':' + name
      let cached = journalCache.find((entry: CachedJournalCommit): boolean => entry.address === address)
      if (cached === undefined || !listed.has(name)) {
        const loaded = await this.request('GET', name, guard)
        if (loaded.status === 404) throw new Error('sync_space_changed')
        requireSuccess(loaded.status)
        if (cached === undefined) {
          cached = { address, commit: decodeSyncCommit(name, loaded.body), bytes: syncUtf8(loaded.body).byteLength }
          journalCache.push(cached)
          journalCacheBytes += cached.bytes
          while (journalCacheBytes > 8 * SYNC_MAX_OBJECT_BYTES || journalCache.length > 4096) {
            journalCacheBytes -= journalCache.shift()?.bytes ?? 0
          }
        } else if (syncCommitName(loaded.body) !== name) throw new Error('sync_invalid_commit')
      }
      budget -= cached.bytes
      if (budget < 0) throw new Error('sync_round_too_large')
      const commit = cached.commit
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
    return result
  }

  private async listWriterPath(path: string, guard: SyncRequestGuard): Promise<DavResource[]> {
    const address = this.writerRoot + path
    const response = await this.requestAt('PROPFIND', address, guard, buildPropfindBody())
    if (response.status === 404) return []
    requireSuccess(response.status)
    if (response.status !== 207) throw new Error('sync_collection_listing_failed')
    return (await readSyncListing(response.body, address, guard))
      .filter((item: DavResource): boolean => item.href.startsWith(address) && item.href !== address)
  }

  private async readWriterManifest(legacy: SyncRemoteManifest, guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const root = await this.listWriterPath('', guard)
    const names = new Set<string>(root.filter((item: DavResource): boolean => item.isCollection)
      .map((item: DavResource): string => item.href.substring(this.writerRoot.length).replace(/\/$/, ''))
      .filter((name: string): boolean => WRITER_NAME.test(name)))
    const witnesses = this.witnesses.filter((name: string): boolean => WRITER_PUBLICATION.test(name))
    witnesses.forEach((name: string): void => { names.add(name.split('/')[0]) })
    if (names.size > 128) throw new Error('sync_replica_limit')
    const heads: SyncJournalCommit[] = []
    const writerHeads: SyncWriterHead[] = []
    const frontier = legacy.frontier?.slice() ?? []
    if (legacy.manifest !== undefined) heads.push({ format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1, parents: [], manifest: legacy.manifest })
    let own: SyncManifest | undefined
    let ownWritable = true
    let warning = legacy.warning ?? ''
    for (const writer of Array.from(names).sort()) {
      const prefix = writer + '/'
      const known = witnesses.find((name: string): boolean => name.startsWith(prefix))
      const segments = await this.listWriterPath(prefix, guard)
      const segmentNames = segments.filter((item: DavResource): boolean => item.isCollection)
        .map((item: DavResource): string => item.href.substring(this.writerRoot.length + prefix.length).replace(/\/$/, ''))
        .filter((segment: string): boolean => /^[0-9]{14}$/.test(segment)).sort().reverse()
      let listed: string[] = []
      for (const segment of segmentNames) {
        const files = await this.listWriterPath(prefix + segment + '/', guard)
        listed = files.filter((item: DavResource): boolean => !item.isCollection)
          .map((item: DavResource): string => item.href.substring(this.writerRoot.length))
          .filter((name: string): boolean => WRITER_PUBLICATION.test(name))
        // MKCOL can complete before the first PUT in a new segment.
        if (listed.length > 0) break
      }
      const candidates = listed.slice()
      if (known !== undefined && !candidates.includes(known)) candidates.push(known)
      candidates.sort().reverse()
      let accepted = false
      for (const path of candidates) {
        const prefixWithoutHash = path.slice(0, path.lastIndexOf('-'))
        if (candidates.some((name: string): boolean => name !== path && name.startsWith(prefixWithoutHash + '-'))) {
          warning = 'sync_writer_conflicting_publications'
          if (writer === this.writer) ownWritable = false
          continue
        }
        try {
          const read = await this.readWriterHead(path, listed.includes(path), guard)
          if (read === undefined) throw new Error('sync_shard_missing')
          if (writer === this.writer) own = read
          heads.push({ format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1, parents: [], manifest: read })
          writerHeads.push({ path, manifest: read, segments: segmentNames, listed })
          frontier.push(known !== undefined && known > path ? known : path)
          accepted = true
          break
        } catch (error) {
          const code = (error as Error).message
          if (code !== 'sync_shard_missing' && code !== 'sync_invalid_commit' && code !== 'sync_shard_damaged') throw error as Error
          warning = code
          if (writer === this.writer) ownWritable = false
        }
      }
      if (!accepted && known !== undefined) frontier.push(known)
    }
    if (frontier.length === (legacy.frontier?.length ?? 0)) {
      legacy.writer = true
      legacy.old = legacy.manifest
      legacy.warning = warning
      legacy.ownWritable = ownWritable
      return legacy
    }
    const manifest = heads.length === 0 ? undefined : mergeSyncJournal(heads, this.space)
    return { manifest, own, old: legacy.manifest, writer: true, journal: true, frontier, warning, ownWritable, writerHeads,
      hash: manifest === undefined ? '' : syncDigest(JSON.stringify(manifest)),
      legacyHash: legacy.legacyHash, legacyRevision: legacy.legacyRevision, legacySpace: legacy.legacySpace,
      etag: '"writer-' + syncDigest(JSON.stringify([legacy.etag, frontier])) + '"' }
  }

  async readEarlierWriterGroup(head: SyncWriterHead, guard: SyncRequestGuard,
    accept: (manifest: SyncManifest) => Promise<boolean>): Promise<boolean> {
    const parts = head.path.split('/')
    const writer = parts[0]
    const currentSegment = parts[1]
    let remaining = SEGMENT_SIZE
    const segments = Array.from(new Set<string>([currentSegment].concat(head.segments)))
      .filter((segment: string): boolean => segment <= currentSegment).sort().reverse()
    for (const segment of segments.slice(0, 4)) {
      const prefix = writer + '/' + segment + '/'
      const listed = head.listed.some((path: string): boolean => path.startsWith(prefix)) ?
        head.listed : (await this.listWriterPath(prefix, guard)).filter((item: DavResource): boolean => !item.isCollection)
          .map((item: DavResource): string => item.href.substring(this.writerRoot.length))
          .filter((path: string): boolean => WRITER_PUBLICATION.test(path))
      const currentSequence = WRITER_PUBLICATION.exec(head.path)?.[3]
      for (const path of listed.filter((item: string): boolean => {
        const sequence = WRITER_PUBLICATION.exec(item)?.[3]
        return sequence !== undefined && currentSequence !== undefined && sequence < currentSequence
      }).sort().reverse()) {
        if (remaining-- <= 0) return false
        const sequence = path.slice(0, path.lastIndexOf('-') + 1)
        if (listed.some((item: string): boolean => item !== path && item.startsWith(sequence))) continue
        let older: SyncManifest | undefined
        try { older = await this.readWriterHead(path, true, guard) } catch (error) {
          const code = (error as Error).message
          if (code !== 'sync_invalid_commit' && code !== 'sync_shard_damaged' && code !== 'sync_shard_missing') throw error as Error
          continue
        }
        if (older !== undefined && await accept(older)) return true
      }
    }
    return false
  }

  private async readWriterHead(path: string, listed: boolean, guard: SyncRequestGuard): Promise<SyncManifest | undefined> {
    const key = this.account + ':' + path
    const cached = journalCache.find((entry: CachedJournalCommit): boolean => entry.address === key)
    if (listed && cached !== undefined) return copySyncManifest(cached.commit.manifest, this.space)
    const remote = await this.readCommit(path, guard)
    if (remote?.manifest === undefined) return undefined
    if (cached === undefined) {
      const bytes = syncUtf8(JSON.stringify(remote.manifest)).byteLength
      journalCache.push({ address: key, commit: { format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1,
        parents: [], manifest: remote.manifest }, bytes })
      journalCacheBytes += bytes
      while (journalCacheBytes > 8 * SYNC_MAX_OBJECT_BYTES || journalCache.length > 4096) {
        journalCacheBytes -= journalCache.shift()?.bytes ?? 0
      }
    }
    return remote.manifest
  }

  async readManifest(guard: SyncRequestGuard, requiredTag: string = '', discoveryOnly: boolean = false): Promise<SyncRemoteManifest> {
    let legacy: SyncRemoteManifest
    const previous = legacyDiscovery.find((entry: LegacyDiscovery): boolean =>
      entry.account === this.account && entry.space === this.space)
    const hasWriterWitness = this.witnesses.some((name: string): boolean => WRITER_PUBLICATION.test(name))
    try {
      guard()
      if (discoveryOnly && hasWriterWitness && previous !== undefined &&
        Date.now() - previous.checked < LEGACY_DISCOVERY_MS && requiredTag === '') {
        legacy = JSON.parse(JSON.stringify(previous.manifest)) as SyncRemoteManifest
        this.legacyObjects = previous.objects.slice()
      } else {
        legacy = await this.readJournal(guard)
        if (this.writer !== '') {
          if (previous !== undefined) legacyDiscovery.splice(legacyDiscovery.indexOf(previous), 1)
          const snapshot = JSON.parse(JSON.stringify(legacy)) as SyncRemoteManifest
          legacyDiscovery.push({ account: this.account, space: this.space, checked: Date.now(),
            manifest: snapshot, objects: this.legacyObjects.slice() })
          if (legacyDiscovery.length > 8) legacyDiscovery.shift()
        }
      }
    } catch (error) {
      const code = (error as Error).message
      if (this.writer === '' || !hasWriterWitness || (code !== 'sync_space_changed' &&
        code !== 'sync_invalid_commit' && code !== 'sync_invalid_manifest' && code !== 'sync_shard_damaged')) throw error as Error
      // Old damage or missing witnesses are not deletions. Keep the receipt
      // and allow the migrated records to keep moving.
      legacy = { hash: '', etag: '', journal: true, warning: 'sync_legacy_unavailable',
        frontier: this.witnesses.filter((name: string): boolean => SYNC_COMMIT_NAME.test(name)) }
    }
    const result = this.writer === '' ? legacy : await this.readWriterManifest(legacy, guard)
    if (legacy.warning === 'sync_legacy_unavailable' && result.manifest === undefined) throw new Error('sync_space_changed')
    if (requiredTag !== '' && requiredTag !== result.etag) throw new Error('sync_preview_changed')
    this.witnesses.splice(0, this.witnesses.length, ...(result.frontier ?? []))
    return result
  }

  async readObject(ref: SyncShardRef, guard: SyncRequestGuard): Promise<string> {
    const path = syncShardPath(ref)
    if (this.writer !== '') {
      const object = await this.requestAt('GET', this.writerRoot + path, guard)
      if (object.status !== 404) {
        requireSuccess(object.status)
        return object.body
      }
    }
    const result = await this.request('GET', path, guard)
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
    if (this.writer !== '') await this.ensureWriterRoot(guard)
    const address = (this.writer === '' ? this.root : this.writerRoot) + path
    const before = await this.requestAt('GET', address, guard)
    if (before.status !== 404) {
      requireSuccess(before.status)
      if (before.body !== object.body) throw new Error('sync_shard_damaged')
      return
    }
    requireSuccess((await this.requestAt('PUT', address, guard, object.body)).status)
    const existing = await this.requestAt('GET', address, guard)
    requireSuccess(existing.status)
    if (existing.body !== object.body) throw new Error('sync_shard_damaged')
  }

  commitName(manifest: SyncManifest, frontier: string[]): string {
    const body = this.commitBody(manifest, frontier)
    return this.writer === '' ? syncCommitName(body) : this.publicationName(this.writer, manifest.revision, body)
  }

  commitBody(manifest: SyncManifest, frontier: string[]): string {
    if (this.writer === '') return syncCommitBody(manifest, frontier)
    const publication: SyncWriterPublication = { writer: this.writer, manifest }
    const body = JSON.stringify(publication)
    if (syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES) throw new Error('sync_manifest_too_large')
    return body
  }

  private publicationName(writer: string, sequence: number, body: string): string {
    return writer + '/' + publicationSegment(sequence) + '/' + sequence.toString().padStart(16, '0') +
      '-' + syncDigest(body) + '.json'
  }

  private decodePublication(name: string, body: string): SyncManifest {
    const parts = WRITER_PUBLICATION.exec(name)
    if (parts === null) throw new Error('sync_invalid_commit')
    let publication: SyncWriterPublication
    try { publication = JSON.parse(body) as SyncWriterPublication } catch (_error) { throw new Error('sync_invalid_commit') }
    if (!publication || publication.writer !== parts[1]) throw new Error('sync_invalid_commit')
    const manifest = decodeSyncManifest(JSON.stringify(publication.manifest))
    if (manifest.schema !== 2 || manifest.maintenance || this.publicationName(publication.writer, manifest.revision, body) !== name) {
      throw new Error('sync_invalid_commit')
    }
    return manifest
  }

  async retryCommit(body: string, guard: SyncRequestGuard, selected: string[], path: string = ''): Promise<SyncRemoteManifest> {
    if (WRITER_PUBLICATION.test(path)) {
      const manifest = this.decodePublication(path, body)
      if (!path.startsWith(this.writer + '/')) throw new Error('sync_invalid_writer')
      await this.writePublication(path, body, manifest, guard, selected)
      const receipt = await this.readCommit(path, guard)
      if (receipt === undefined) throw new Error('sync_remote_result_unknown')
      return receipt
    }
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
    if (WRITER_PUBLICATION.test(name)) {
      const response = await this.requestAt('GET', this.writerRoot + name, guard)
      if (response.status === 404) return undefined
      requireSuccess(response.status)
      const manifest = copySyncManifest(this.decodePublication(name, response.body), this.space)
      return { manifest, hash: syncDigest(JSON.stringify(manifest)), etag: '"writer-' + syncDigest(name) + '"',
        frontier: [name], journal: true, writer: true }
    }
    if (!SYNC_COMMIT_NAME.test(name)) throw new Error('sync_invalid_commit')
    const result = await this.request('GET', name, guard)
    if (result.status === 404) return undefined
    requireSuccess(result.status)
    const commit = decodeSyncCommit(name, result.body)
    const manifest = copySyncManifest(commit.manifest, this.space)
    return { manifest, hash: syncDigest(JSON.stringify(manifest)), etag: '"journal-' + syncDigest(name) + '"',
      frontier: [name], journal: true }
  }

  private writerRootChecked: boolean = false

  private async ensureWriterRoot(guard: SyncRequestGuard): Promise<void> {
    if (this.writerRootChecked) return
    await this.ensureCollection(this.writerRoot, guard)
    this.writerRootChecked = true
  }

  private async writePublication(path: string, body: string, manifest: SyncManifest, guard: SyncRequestGuard,
    selected: string[], beforeSend: () => void | Promise<void> = (): void => {}): Promise<void> {
    await this.ensureWriterRoot(guard)
    const segment = path.split('/')[1]
    await this.ensureCollection(this.writerRoot + this.writer + '/', guard)
    await this.ensureCollection(this.writerRoot + this.writer + '/' + segment + '/', guard)
    for (const dataset of manifest.datasets) {
      if (!selected.includes(dataset.id)) continue
      for (const ref of dataset.shards) {
        const content = await this.readObject(ref, guard)
        if (syncDigest(content) !== ref.hash || syncUtf8(content).byteLength !== ref.bytes) throw new Error('sync_shard_damaged')
      }
    }
    await beforeSend()
    requireSuccess((await this.requestAt('PUT', this.writerRoot + path, guard, body)).status)
  }

  async publish(manifest: SyncManifest, tag: string, guard: SyncRequestGuard,
    beforeSend: () => void | Promise<void> = (): void => {}, selected: string[] = []): Promise<boolean> {
    if (this.writer !== '') {
      const body = this.commitBody(manifest, [])
      const path = this.publicationName(this.writer, manifest.revision, body)
      this.decodePublication(path, body)
      await this.writePublication(path, body, manifest, guard, selected, beforeSend)
      return true
    }
    // Migration is a one-time remote-object preservation, never a local apply of disabled groups.
    for (const ref of this.legacyObjects) await this.storeObject({ ref, body: await this.readObject(ref, guard) }, guard)
    const current = await this.readManifest(guard)
    if (current.etag !== tag) return false
    const body = syncCommitBody(manifest, current.frontier ?? [])
    const name = syncCommitName(body)
    guard()
    await beforeSend()
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
    if (address !== this.directory && !address.startsWith(this.root) && !address.startsWith(this.writerRoot) && !legacyAllowed) {
      throw new Error('sync_invalid_path')
    }
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
