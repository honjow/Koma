import { taskpool, util, url } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DavResource } from '../remote/WebDavModels'
import { parseWebDavMultiStatus, buildPropfindBody } from '../remote/WebDavClient'
import {
  buildSyncDataset, copySyncManifest, decodeSyncManifest, decodeSyncShard, syncDigest, syncShardPath, syncUtf8, SyncManifest, SyncObject,
  SyncDataset, SyncDatasetRef, SyncShardRef, SYNC_COLLECTION, SYNC_MAX_OBJECT_BYTES, SYNC_MAX_ROUND_BYTES,
} from './DeviceSyncWire'
import { syncBucketKey } from './DeviceSyncData'
import { mergeSyncFacts, SyncFact } from './DeviceSyncFacts'
import { decodeSyncCommit, mergeSyncJournal, syncCommitBody, syncCommitName, SyncJournalCommit, SYNC_COMMIT_NAME } from './DeviceSyncJournal'
import { requestDeviceSyncStream } from './DeviceSyncHttpStream'
import { SyncPackArchiveIndex, SyncPackReader, SyncPackStore,
  SyncPackPendingAttempt } from './DeviceSyncObjectPack'
import { SyncLegacyArchiveReader, SyncLegacyReadSession,
  SyncLegacyArchiveStore, SyncLegacyPendingAttempt } from './DeviceSyncLegacyArchive'
import { legacyArchiveWriters, legacyArchiveSegments, legacyArchiveCandidates } from './DeviceSyncLegacyArchiveAdapter'
import { DeviceSyncMetrics, syncMetricUptime } from './DeviceSyncMetrics'
import { readCompactedSyncPublicationPacks, SyncPackCompactionSession } from './DeviceSyncPackCompaction'
import { readGenericCompactedSyncPacks } from './DeviceSyncGenericPackCompaction'
import { planPublicationPacks, writePublicationPacks, readPublicationPacks, PublicationPackPlan,
  PublicationPackStore } from './DeviceSyncPublicationPack'
import { retainPublicationPackLocations, validatePublicationPackLocation, SyncPublicationPackLocation } from './DeviceSyncPublicationPackCodec'

export interface SyncConnectionDraft {
  directory: string
  username: string
  password: string
}

@Concurrent
function buildMigratedDataset(id: string, objects: SyncObject[], epoch: number, previous?: SyncDatasetRef): SyncDataset {
  const facts: SyncFact[] = []
  for (const object of objects) {
    facts.push(...decodeSyncShard(id, object.ref, object.body, syncBucketKey))
  }
  return buildSyncDataset(id, mergeSyncFacts([], facts), epoch, previous, syncBucketKey, true)
}

export interface SyncRemoteManifest {
  manifest?: SyncManifest
  etag: string
  hash: string
  sharedHash?: string
  sharedHeads?: string[]
  sharedSuperseded?: string[]
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
  root?: string
}

interface SyncHttpResponse {
  status: number
  body: string
  etag: string
}

class SyncWebDavPackStore implements SyncPackStore {
  private readAction: (path: string) => Promise<string | undefined>
  private writeAction: (path: string, body: string) => Promise<void>
  private listAction: (path: string) => Promise<string[]>
  private removeAction: (path: string) => Promise<void>
  private pendingPort?: SyncArchivePendingPort
  constructor(readAction: (path: string) => Promise<string | undefined>,
    writeAction: (path: string, body: string) => Promise<void>,
    listAction: (path: string) => Promise<string[]>,
    removeAction: (path: string) => Promise<void>, pendingPort?: SyncArchivePendingPort) {
    this.readAction = readAction
    this.writeAction = writeAction
    this.listAction = listAction
    this.removeAction = removeAction
    this.pendingPort = pendingPort
  }
  read(path: string): Promise<string | undefined> { return this.readAction(path) }
  write(path: string, body: string): Promise<void> { return this.writeAction(path, body) }
  list(path: string): Promise<string[]> { return this.listAction(path) }
  remove(path: string): Promise<void> { return this.removeAction(path) }
  async loadPending(): Promise<SyncPackPendingAttempt[]> {
    if (this.pendingPort === undefined) return []
    return (await this.pendingPort.loadPending()).map((item: SyncLegacyPendingAttempt): SyncPackPendingAttempt => ({
      path: item.path, startedAt: item.startedAt, checks: item.checks, nextCheckAt: item.nextCheckAt,
      awaitingListing: item.awaitingListing }))
  }
  async recordPending(attempt: SyncPackPendingAttempt): Promise<void> {
    if (this.pendingPort === undefined) throw new Error('sync_pack_pending')
    const value: SyncLegacyPendingAttempt = { path: attempt.path, startedAt: attempt.startedAt, checks: attempt.checks,
      nextCheckAt: attempt.nextCheckAt, awaitingListing: attempt.awaitingListing }
    await this.pendingPort.recordPending(value)
  }
  async forgetPending(path: string): Promise<void> {
    if (this.pendingPort === undefined) throw new Error('sync_pack_pending')
    await this.pendingPort.forgetPending(path)
  }
  async deferPending(path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean): Promise<void> {
    if (this.pendingPort === undefined) throw new Error('sync_pack_pending')
    await this.pendingPort.deferPending(path, startedAt, nextCheckAt, checks, awaitingListing)
  }
}

class SyncPublicationWebDavStore implements PublicationPackStore {
  private begin: (path: string) => Promise<void>
  private putAction: (path: string, body: string) => Promise<void>
  private getAction: (path: string) => Promise<string | undefined>
  private complete: (path: string) => Promise<void>
  constructor(begin: (path: string) => Promise<void>, put: (path: string, body: string) => Promise<void>,
    get: (path: string) => Promise<string | undefined>, complete: (path: string) => Promise<void>) {
    this.begin = begin; this.putAction = put; this.getAction = get; this.complete = complete
  }
  beginUnique(path: string): Promise<void> { return this.begin(path) }
  put(path: string, body: string): Promise<void> { return this.putAction(path, body) }
  get(path: string): Promise<string | undefined> { return this.getAction(path) }
  completeUnique(path: string): Promise<void> { return this.complete(path) }
}

class SyncLegacyWebDavStore implements SyncLegacyArchiveStore {
  readOriginal: (path: string) => Promise<string | undefined>
  listOriginal: (path: string) => Promise<string[]>
  removeOriginal: (path: string) => Promise<void>
  readArchive: (path: string) => Promise<string | undefined>
  listArchive: (path: string) => Promise<string[]>
  ensureArchive: (path: string) => Promise<void>
  writeArchive: (path: string, body: string) => Promise<void>
  removeArchive: (path: string) => Promise<void>
  loadPending: () => Promise<SyncLegacyPendingAttempt[]>
  recordPending: (attempt: SyncLegacyPendingAttempt) => Promise<void>
  forgetPending: (path: string) => Promise<void>
  deferPending: (path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean) => Promise<void>
  constructor(readOriginal: (path: string) => Promise<string | undefined>, listOriginal: (path: string) => Promise<string[]>,
    removeOriginal: (path: string) => Promise<void>, readArchive: (path: string) => Promise<string | undefined>,
    listArchive: (path: string) => Promise<string[]>, ensureArchive: (path: string) => Promise<void>,
    writeArchive: (path: string, body: string) => Promise<void>, removeArchive: (path: string) => Promise<void>,
    loadPending: () => Promise<SyncLegacyPendingAttempt[]>, recordPending: (attempt: SyncLegacyPendingAttempt) => Promise<void>,
    forgetPending: (path: string) => Promise<void>,
    deferPending: (path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean) => Promise<void>) {
    this.readOriginal = readOriginal
    this.listOriginal = listOriginal
    this.removeOriginal = removeOriginal
    this.readArchive = readArchive
    this.listArchive = listArchive
    this.ensureArchive = ensureArchive
    this.writeArchive = writeArchive
    this.removeArchive = removeArchive
    this.loadPending = loadPending
    this.recordPending = recordPending
    this.forgetPending = forgetPending
    this.deferPending = deferPending
  }
}

export interface SyncArchivePendingPort {
  loadPending(): Promise<SyncLegacyPendingAttempt[]>
  recordPending(attempt: SyncLegacyPendingAttempt): Promise<void>
  forgetPending(path: string): Promise<void>
  deferPending(path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean): Promise<void>
  recordSeen(kind: string): Promise<void>
}

export type SyncRequestGuard = () => void

// Percent-escape hex digits are case-insensitive. Preserve the escapes:
// decoding %2F here would change the DAV path's segment boundaries.
function normalizedDavHref(value: string): string {
  return value.replace(/%[0-9a-f]{2}/gi, (escape: string): string => escape.toUpperCase())
}

@Concurrent
function parseSyncListing(xml: string, address: string): DavResource[] {
  // A 207 is not by itself proof of a complete DAV listing. Treat malformed,
  // truncated or failed entries as an error instead of an empty directory.
  if (!/<(?:[A-Za-z0-9_.-]+:)?multistatus\b[^>]*>/i.test(xml) ||
    !/<\/(?:[A-Za-z0-9_.-]+:)?multistatus\s*>(?:\s|<!--(?:(?!--)[\s\S])*-->|<\?(?:(?!\?>)[\s\S])*\?>)*$/i.test(xml)) {
    throw new Error('sync_response_invalid')
  }
  const openings = xml.match(/<(?:[A-Za-z0-9_.-]+:)?response\b[^>]*>/gi) ?? []
  const closings = xml.match(/<\/(?:[A-Za-z0-9_.-]+:)?response\s*>/gi) ?? []
  const blocks = Array.from(xml.matchAll(/<(?:[A-Za-z0-9_.-]+:)?response\b[^>]*>([\s\S]*?)<\/(?:[A-Za-z0-9_.-]+:)?response\s*>/gi))
  const resources = parseWebDavMultiStatus(xml, address)
  if (openings.length === 0 || openings.length !== closings.length || blocks.length !== openings.length ||
    resources.length !== blocks.length) throw new Error('sync_response_invalid')
  let self = false
  for (let i = 0; i < blocks.length; i++) {
    const propstats = Array.from(blocks[i][1].matchAll(/<(?:[A-Za-z0-9_.-]+:)?propstat\b[^>]*>([\s\S]*?)<\/(?:[A-Za-z0-9_.-]+:)?propstat\s*>/gi))
    const resourceType = propstats.find((entry: RegExpMatchArray): boolean =>
      /<(?:[A-Za-z0-9_.-]+:)?status\b[^>]*>\s*HTTP\/\d(?:\.\d)?\s+2\d\d(?:\s|<)/i.test(entry[1]) &&
      /<(?:[A-Za-z0-9_.-]+:)?resourcetype\b/i.test(entry[1]))
    if (resourceType === undefined) throw new Error('sync_response_invalid')
    resources[i].isCollection = /<(?:[A-Za-z0-9_.-]+:)?collection\b/i.test(resourceType[1])
    // Concurrent functions cannot call same-module helpers in ArkTS.
    const href = resources[i].href.replace(/%[0-9a-f]{2}/gi, (escape: string): string => escape.toUpperCase())
    const request = address.replace(/%[0-9a-f]{2}/gi, (escape: string): string => escape.toUpperCase())
    if (href.replace(/\/+$/, '') === request.replace(/\/+$/, '')) {
      if (!resources[i].isCollection) throw new Error('sync_response_invalid')
      self = true
    }
  }
  if (!self) throw new Error('sync_response_invalid')
  return resources
}

async function readSyncListing(xml: string, address: string, guard: SyncRequestGuard): Promise<DavResource[]> {
  // A writer directory can contain many responses even when the latest head is unchanged.
  const resources = await taskpool.execute(parseSyncListing, xml, address) as DavResource[]
  guard()
  return resources
}

@Concurrent
function isSyncObjectValid(ref: SyncShardRef, body: string): boolean {
  return syncDigest(body) === ref.hash && syncUtf8(body).byteLength === ref.bytes
}

async function validSyncObject(ref: SyncShardRef, body: string, guard: SyncRequestGuard): Promise<boolean> {
  const valid = await taskpool.execute(isSyncObjectValid, ref, body) as boolean
  guard()
  return valid
}

const MANIFEST = 'manifest.json'
const OBJECT_NAME = /^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/
const WRITER = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const WRITER_NAME = new RegExp('^' + WRITER + '$')
const WRITER_PUBLICATION = new RegExp('^(' + WRITER + ')/([0-9]{14})/([0-9]{16})-([0-9a-f]{64})(?:-(' + WRITER + '))?\\.json$')
const V4_PREFIX = 'v4/'
const SHARED_OBJECT_NAME = new RegExp('^[a-z0-9-]{1,64}-g-[0-7](?:-[0-9a-f]{1,64})?-[0-9a-f]{64}-' + WRITER + '\\.json$')
const SHARED_OLD_SLOT_NAME = /^[a-z0-9-]{1,64}-g-[0-7](?:-[0-9a-f]{1,64})?-[ab]\.json$/
const SHARED_GC_DELAY_MS = 120000
interface SharedCollectionSweep {
  next: number
  running: boolean
  needsScan: boolean
  unreferenced: Map<string, number>
}
const SHARED_SWEEPS = new Map<string, SharedCollectionSweep>()
const SEGMENT_SIZE = 128
const LEGACY_DISCOVERY_MS = 5 * 60 * 1000
const PACK_READERS: Map<string, SyncPackReader> = new Map<string, SyncPackReader>()
const LEGACY_ARCHIVE_READERS: Map<string, SyncLegacyArchiveReader> = new Map<string, SyncLegacyArchiveReader>()
const LEGACY_ARCHIVE_SEEN: Set<string> = new Set<string>()
// Synchronization needs only href and collection type; comic browsing needs the
// extra DAV properties and continues to use buildPropfindBody().
const SYNC_LISTING_BODY = '<?xml version="1.0" encoding="utf-8"?>' +
  '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>'

interface LegacyDiscovery {
  account: string
  space: string
  checked: number
  manifest: SyncRemoteManifest
  objects: SyncShardRef[]
}

interface V3Discovery {
  account: string
  space: string
  writer: string
  checked: number
  legacyTag: string
  manifest: SyncRemoteManifest
}

const legacyDiscovery: LegacyDiscovery[] = []
const v3Discovery: V3Discovery[] = []

function publicationSegment(sequence: number): string {
  return Math.floor((sequence - 1) / SEGMENT_SIZE).toString().padStart(14, '0')
}

interface SyncWriterPublication {
  writer: string
  manifest: SyncManifest
  transaction?: string
  locations?: SyncObjectLocation[]
  newTargets?: SyncObjectLocation[]
  packLocations?: SyncPublicationPackLocation[]
  newPackTargets?: SyncPublicationPackLocation[]
}

interface SyncObjectLocation {
  epoch: number
  hash: string
  writer: string
  attempt: string
}

interface PlannedPublication {
  signature: string
  transaction: string
  body: string
  path: string
  locations: SyncObjectLocation[]
  prepared: boolean
  targets: Map<string, SyncObjectLocation>
}

interface ExcludedV4Publication {
  writer: string
  sequence: string
  digest: string
}

interface CachedJournalCommit {
  address: string
  commit: SyncJournalCommit
  bytes: number
  body?: string
}

// Only immutable, hash-validated content is cached. Directory listings and
// unlisted witnesses are fetched again to distinguish stale listings from loss.
const journalCache: CachedJournalCommit[] = []
let journalCacheBytes = 0

export function canonicalSyncDirectory(input: string): string {
  try {
    const raw = input.trim()
    const parsed = url.URL.parseURL(raw)
    // LAN WebDAV servers commonly use HTTP. The user-selected scheme is kept;
    // HTTPS requests still use the platform's normal certificate validation.
    if ((parsed.protocol === 'https:' || parsed.protocol === 'http:') && parsed.hostname.length > 0 && parsed.username.length === 0 &&
      parsed.password.length === 0 && !raw.includes('?') && !raw.includes('#') &&
      !/%2f|%5c|%00|\\/i.test(raw) && raw.length <= 1024) {
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

class RetryableSyncRequestError extends Error {}

function syncRequestError(error: Error, method: string, namespace: string): Error {
  const code = (error as BusinessError).code
  if (code === undefined) return error.message === 'sync_network_timeout' ?
    new RetryableSyncRequestError(error.message) : error
  // Record only protocol operation and namespace: neither URLs nor credentials
  // belong in diagnostics. Business errors from the guard remain unchanged.
  console.warn('[KomaSync] method=' + method + ' namespace=' + namespace + ' code=' + code.toString())
  if (code === 2300047) return new Error('sync_directory_redirected')
  if (code === 2300060 || code === 2300051 || code === 2300035) return new Error('sync_tls_failed')
  if (code === 2300006 || code === 2300005) return new Error('sync_host_unresolved')
  if (code === 2300028) return new RetryableSyncRequestError('sync_network_timeout')
  if (code === 2300007 || code === 2300018 || code === 2300052 || code === 2300055 || code === 2300056) {
    return new RetryableSyncRequestError('sync_network_failed')
  }
  if (code === 2300003 || code === 2300001) return new Error('sync_invalid_directory')
  return new Error('sync_network_failed')
}

/** No operation accepts a URL supplied by a manifest. Redirects are disabled by NetworkKit. */
export class DeviceSyncWebDav {
  private readonly directory: string
  private readonly root: string
  private readonly writerRoot: string
  private readonly writerRootV4: string
  private readonly sharedRoot: string
  private readonly writer: string
  private readonly authorization: string
  private readonly witnesses: string[]
  private space: string
  private readonly boundSpace: boolean
  private readonly account: string
  private legacyObjects: SyncShardRef[] = []
  private readonly objectOwners: Map<string, string[]> = new Map<string, string[]>()
  private readonly ownObjects: Set<string> = new Set<string>()
  private readonly v4Writers: Set<string> = new Set<string>()
  private readonly locations: Map<string, SyncObjectLocation[]> = new Map<string, SyncObjectLocation[]>()
  private readonly attemptedLocations: Set<string> = new Set<string>()
  private readonly publicationBodies: Map<string, string> = new Map<string, string>()
  private readonly verifiedRefs: Set<string> = new Set<string>()
  // A listing is evidence of visibility, never of the object's bytes.
  private readonly visibleRefs: Set<string> = new Set<string>()
  private readonly publishedLocations: Set<string> = new Set<string>()
  private legacyCommitsExist?: boolean
  private legacyObjectsExist?: boolean
  private legacyCommitsChecked: number = 0
  private legacyObjectsChecked: number = 0
  private roundMetrics?: DeviceSyncMetrics
  private readonly guardMetrics = new Map<SyncRequestGuard, DeviceSyncMetrics>()
  private archiveSeen: (kind: string) => boolean = (_kind: string): boolean => false
  private recordArchiveSeen: (kind: string, guard: SyncRequestGuard) => Promise<void> =
    async (_kind: string, _guard: SyncRequestGuard): Promise<void> => {}
  private planned?: PlannedPublication
  private plannedPacks?: PublicationPackPlan
  private readonly publicationPacks: SyncPublicationPackLocation[] = []
  private readonly publicationPackRefs = new Map<string, SyncShardRef>()
  private readonly publicationPackDatasets = new Map<string, string>()
  private readonly unavailablePublicationPacks = new Set<string>()
  private compactionReadSession = new SyncPackCompactionSession()
  private readonly genericArchiveRoots = new Map<string, boolean>()
  private recoveringPublication: boolean = false
  private readonly recoveryTargets: Set<string> = new Set<string>()
  private readonly excludedV4: ExcludedV4Publication[] = []
  private readonly legacyWriterObjects: Set<string> = new Set<string>()
  private legacyReadSession: SyncLegacyReadSession = new SyncLegacyReadSession()
  private legacyObjectListing?: Set<string>
  private observedV4Frontier: string[] = []
  private v4Refresh?: Promise<boolean>

  constructor(draft: SyncConnectionDraft, witnesses: string[] = [], space: string = '', writer: string = '') {
    this.directory = canonicalSyncDirectory(draft.directory) + '/'
    this.root = this.directory + SYNC_COLLECTION + '/'
    this.writerRoot = this.directory + 'koma-device-sync-v3/'
    this.writerRootV4 = this.directory + 'koma-device-sync-v4/'
    this.sharedRoot = this.directory + 'koma-device-sync-v5/'
    if (writer !== '' && !WRITER_NAME.test(writer)) throw new Error('sync_invalid_writer')
    this.writer = writer
    this.witnesses = witnesses.slice()
    this.witnesses.filter((name: string): boolean => name.startsWith(V4_PREFIX) &&
      WRITER_PUBLICATION.test(name.substring(V4_PREFIX.length))).forEach((name: string): void => {
      this.v4Writers.add(name.substring(V4_PREFIX.length).split('/')[0])
    })
    const identity = syncDigest(JSON.stringify([canonicalSyncDirectory(draft.directory), draft.username.trim()]))
    this.account = identity
    this.boundSpace = space !== ''
    this.space = space || identity.substring(0, 8) + '-' + identity.substring(8, 12) + '-' + identity.substring(12, 16) +
      '-' + identity.substring(16, 20) + '-' + identity.substring(20, 32)
    if (draft.username.includes(':') || /[\r\n\u0000]/.test(draft.username) ||
      (draft.username.length === 0 && draft.password.length > 0)) throw new Error('sync_invalid_username')
    this.authorization = draft.username.length === 0 ? '' :
      'Basic ' + new util.Base64Helper().encodeToStringSync(syncUtf8(draft.username + ':' + draft.password))
  }

  spaceId(): string { return this.space }

  cacheScope(): string { return this.account + ':' + this.space }

  beginShardReadRound(): void {
    this.legacyReadSession = new SyncLegacyReadSession()
    this.unavailablePublicationPacks.clear()
    this.compactionReadSession = new SyncPackCompactionSession()
    this.genericArchiveRoots.clear()
  }

  setRoundMetrics(metrics?: DeviceSyncMetrics): void { this.roundMetrics = metrics }
  setGuardMetrics(guard: SyncRequestGuard, metrics?: DeviceSyncMetrics): void {
    if (metrics === undefined) this.guardMetrics.delete(guard)
    else this.guardMetrics.set(guard, metrics)
  }
  configureArchiveWitness(seen: (kind: string) => boolean,
    record: (kind: string, guard: SyncRequestGuard) => Promise<void>): void {
    this.archiveSeen = seen
    this.recordArchiveSeen = record
  }

  /** Exclude only a locally persisted, failed sent transaction while replanning. */
  excludeV4Publication(path: string, body: string): void {
    if (!path.startsWith(V4_PREFIX)) throw new Error('sync_invalid_commit')
    const parts = WRITER_PUBLICATION.exec(path.substring(V4_PREFIX.length))
    if (parts === null || parts[1] !== this.writer || parts[4] !== syncDigest(body)) throw new Error('sync_invalid_commit')
    this.decodePublication(path, body)
    if (!this.excludedV4.some((entry: ExcludedV4Publication): boolean => entry.writer === parts[1] &&
      entry.sequence === parts[3] && entry.digest === parts[4])) {
      this.excludedV4.push({ writer: parts[1], sequence: parts[3], digest: parts[4] })
    }
  }

  private isExcludedV4(path: string): boolean {
    const parts = WRITER_PUBLICATION.exec(path)
    return parts !== null && this.excludedV4.some((entry: ExcludedV4Publication): boolean =>
      parts[1] === entry.writer && parts[3] === entry.sequence && parts[4] === entry.digest)
  }

  async readLegacyManifest(guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const response = await this.requestAt('GET', this.directory + 'koma-device-sync-v1/manifest.json', guard)
    if (response.status === 404) return { etag: '', hash: '' }
    requireSuccess(response.status)
    const manifest = decodeSyncManifest(response.body)
    this.legacyObjects = manifest.datasets.concat(manifest.previous).flatMap((ref: SyncDatasetRef): SyncShardRef[] => ref.shards)
    return { manifest, etag: response.etag, hash: syncDigest(response.body) }
  }

  async probe(id: string, guard: SyncRequestGuard): Promise<boolean> {
    if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('sync_invalid_probe')
    await this.ensureCollection(this.directory, guard)
    await this.ensureCollection(this.sharedRoot, guard)
    const address = this.sharedRoot + 'probe-' + id + '.json'
    const first = '{"probe":1}'
    let cleaned = false
    try {
      requireSuccess((await this.requestAt('PUT', address, guard, first)).status)
      const loaded = await this.requestAt('GET', address, guard)
      requireSuccess(loaded.status)
      if (loaded.body !== first) throw new Error('sync_response_invalid')
    } finally {
      try {
        await this.cleanProbe(id, guard, false, 5)
        cleaned = true
      } catch (_error) {}
    }
    guard()
    return cleaned
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
      normalizedDavHref(item.href).replace(/\/+$/, '') === normalizedDavHref(address).replace(/\/+$/, ''))
    if (resource === undefined) throw new Error('sync_not_webdav_directory')
    if (!resource.isCollection) throw new Error('sync_path_not_directory')
  }

  async cleanProbe(id: string, guard: SyncRequestGuard, legacy: boolean = false, collection: number = 2): Promise<void> {
    if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('sync_invalid_probe')
    const path = 'probe-' + id + '.json'
    const address = (legacy ? this.directory + 'koma-device-sync-v1/' : collection === 5 ? this.sharedRoot : this.root) + path
    const result = await this.requestAt('DELETE', address, guard)
    if (result.status !== 404) requireSuccess(result.status)
  }

  private async readJournal(guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const listing = await this.request('PROPFIND', '', guard, buildPropfindBody())
    if (listing.status !== 404) requireSuccess(listing.status)
    if (listing.status !== 404 && listing.status !== 207) throw new Error('sync_collection_listing_failed')
    const listed = new Set<string>()
    if (listing.status === 207) (await readSyncListing(listing.body, this.root, guard)).forEach((item: DavResource): void => {
      if (!item.isCollection && normalizedDavHref(item.href).startsWith(normalizedDavHref(this.root))) {
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

  private async listWriterPath(path: string, guard: SyncRequestGuard, root: string = this.writerRoot): Promise<DavResource[]> {
    const address = root + path
    const response = await this.requestAt('PROPFIND', address, guard, SYNC_LISTING_BODY)
    if (response.status === 404) return []
    requireSuccess(response.status)
    if (response.status !== 207) throw new Error('sync_collection_listing_failed')
    return (await readSyncListing(response.body, address, guard))
      .filter((item: DavResource): boolean => normalizedDavHref(item.href).startsWith(normalizedDavHref(address)) &&
        normalizedDavHref(item.href) !== normalizedDavHref(address))
  }

  private packStore(guard: SyncRequestGuard, pending?: SyncArchivePendingPort,
    protectedBodies: string[] = [], allowArchivedPublished: boolean = false): SyncPackStore {
    const protectedPacks = new Set<string>()
    const protect = (pack: SyncPublicationPackLocation): void => {
      for (const attempt of pack.attempts) protectedPacks.add(pack.writer + '/packs/pack-' + attempt + '-' + pack.hash + '.json')
    }
    if (!allowArchivedPublished) this.publicationPacks.forEach(protect)
    for (const body of protectedBodies) {
      let publication: SyncWriterPublication
      try { publication = JSON.parse(body) as SyncWriterPublication } catch (_error) { throw new Error('sync_invalid_commit') }
      for (const pack of (publication.packLocations ?? []).concat(publication.newPackTargets ?? [])) {
        validatePublicationPackLocation(pack, this.manifestObjects(publication.manifest))
        protect(pack)
      }
    }
    return new SyncWebDavPackStore(
      async (path: string): Promise<string | undefined> => {
        const response = await this.requestAt('GET', this.writerRootV4 + path, guard)
        if (response.status === 404) return undefined
        requireSuccess(response.status)
        return response.body
      },
      async (path: string, body: string): Promise<void> => {
        requireSuccess((await this.requestAt('PUT', this.writerRootV4 + path, guard, body)).status)
      },
      async (path: string): Promise<string[]> => {
        const address = this.writerRootV4 + path
        return (await this.listWriterPath(path, guard, this.writerRootV4)).filter((item: DavResource): boolean =>
          !item.isCollection).map((item: DavResource): string => item.href.substring(address.length))
      },
      async (path: string): Promise<void> => {
        if (protectedPacks.has(path)) throw new Error('sync_pack_in_use')
        const pathParts = path.split('/')
        if (allowArchivedPublished && pathParts.length === 3 && WRITER_NAME.test(pathParts[0]) && pathParts[1] === 'packs') {
          if (pending === undefined) throw new Error('sync_pack_pending')
          await pending.recordSeen('pack:' + pathParts[0])
          guard()
        }
        const response = await this.requestAt('DELETE', this.writerRootV4 + path, guard)
        if (response.status !== 404) requireSuccess(response.status)
      }, pending)
  }

  private publicationPackStore(guard: SyncRequestGuard, begin: (path: string) => Promise<void>,
    complete: (path: string) => Promise<void>): PublicationPackStore {
    return new SyncPublicationWebDavStore(begin,
      async (path: string, body: string): Promise<void> => {
        requireSuccess((await this.requestAt('PUT', this.writerRootV4 + path, guard, body)).status)
      },
      async (path: string): Promise<string | undefined> => {
        const response = await this.requestAt('GET', this.writerRootV4 + path, guard)
        if (response.status === 404) return undefined
        requireSuccess(response.status)
        return response.body
      }, complete)
  }

  async prefetchPublicationObjects(refs: SyncShardRef[], guard: SyncRequestGuard): Promise<Map<string, string>> {
    const result = new Map<string, string>()
    if (this.publicationPacks.length === 0 || refs.length === 0) return result
    const noop = async (_path: string): Promise<void> => {}
    const candidates = this.publicationPacks.filter((pack: SyncPublicationPackLocation): boolean =>
      !this.unavailablePublicationPacks.has(JSON.stringify(pack)))
    const read = await readPublicationPacks(this.publicationPackStore(guard, noop, noop), candidates,
      Array.from(this.publicationPackRefs.values()), refs, guard)
    guard()
    if (read.incomplete) for (const pack of candidates) {
      if (read.missing.some((ref: SyncShardRef): boolean => pack.members.some((member): boolean =>
        member.epoch === ref.epoch && member.hash === ref.hash))) this.unavailablePublicationPacks.add(JSON.stringify(pack))
    }
    for (const item of read.objects) result.set(syncShardPath(item.ref), item.body)
    const missing = refs.filter((ref: SyncShardRef): boolean => !result.has(syncShardPath(ref)))
    const buckets = new Set<string>()
    for (const pack of this.publicationPacks) {
      for (const ref of missing) {
        if (!pack.members.some((member): boolean => ref.epoch === member.epoch && ref.hash === member.hash)) continue
        const dataset = this.publicationPackDatasets.get(syncShardPath(ref))
        if (dataset !== undefined) buckets.add(JSON.stringify([pack.writer, dataset, pack.hash]))
      }
    }
    for (const key of buckets) {
      const parts = JSON.parse(key) as string[]
      const remaining = missing.filter((ref: SyncShardRef): boolean => !result.has(syncShardPath(ref)) &&
        this.publicationPackDatasets.get(syncShardPath(ref)) === parts[1] && this.publicationPacks.some(
          (pack: SyncPublicationPackLocation): boolean => pack.writer === parts[0] && pack.hash === parts[2] &&
            pack.members.some((member): boolean => member.epoch === ref.epoch && member.hash === ref.hash)))
      if (remaining.length === 0) continue
      const archived = await readCompactedSyncPublicationPacks(this.packStore(guard), parts[0], parts[1], parts[2], remaining, guard,
        this.compactionReadSession)
      guard()
      for (const item of archived.objects) result.set(syncShardPath(item.ref), item.body)
    }
    // If a whole archive bucket is temporarily absent, do not fan out into
    // one legacy search per shard. Probe alternate verified packs here and
    // stop at the first unresolved ref; failures remain retryable.
    for (const ref of missing) {
      const path = syncShardPath(ref)
      if (result.has(path) || this.legacyWriterObjects.has(path) || (this.locations.get(path)?.length ?? 0) > 0) continue
      const owners = Array.from(new Set<string>(this.publicationPacks.filter((pack: SyncPublicationPackLocation): boolean =>
        pack.members.some((member): boolean => member.epoch === ref.epoch && member.hash === ref.hash))
        .map((pack: SyncPublicationPackLocation): string => pack.writer)))
      if (owners.length === 0) continue
      let failure: Error | undefined
      for (const owner of owners) {
        try {
          const body = await this.packReader().read(this.packStore(guard), owner, ref.epoch, ref.hash, ref.bytes, guard)
          guard()
          result.set(path, body)
          break
        } catch (error) { guard(); failure = error as Error }
      }
      if (!result.has(path)) throw failure ?? new Error('sync_pack_not_found')
    }
    return result
  }

  async prefetchGenericObjects(dataset: string, refs: SyncShardRef[], guard: SyncRequestGuard): Promise<Map<string, string>> {
    const result = new Map<string, string>()
    const writers = new Set<string>()
    for (const ref of refs) {
      const path = syncShardPath(ref)
      for (const owner of this.objectOwners.get(path) ?? []) writers.add(owner)
      for (const location of this.locations.get(path) ?? []) writers.add(location.writer)
    }
    for (const writer of writers) {
      let exists = this.genericArchiveRoots.get(writer)
      if (exists === undefined) {
        const address = this.writerRootV4 + writer + '/archive-objects/'
        const response = await this.requestAt('PROPFIND', address, guard, SYNC_LISTING_BODY)
        if (response.status === 404) exists = false
        else {
          requireSuccess(response.status)
          if (response.status !== 207) throw new Error('sync_collection_listing_failed')
          await readSyncListing(response.body, address, guard)
          exists = true
        }
        guard()
        this.genericArchiveRoots.set(writer, exists)
      }
      if (!exists) continue
      const wanted = refs.filter((ref: SyncShardRef): boolean => {
        const path = syncShardPath(ref)
        return !result.has(path) && ((this.objectOwners.get(path) ?? []).includes(writer) ||
          (this.locations.get(path) ?? []).some((loc: SyncObjectLocation): boolean => loc.writer === writer))
      })
      if (wanted.length === 0) continue
      const read = await readGenericCompactedSyncPacks(this.packStore(guard), writer, dataset, wanted, guard,
        this.compactionReadSession)
      guard()
      for (const item of read.objects) result.set(syncShardPath(item.ref), item.body)
    }
    return result
  }

  async writePlannedPacks(guard: SyncRequestGuard, begin: (path: string) => Promise<void>,
    complete: (path: string) => Promise<void>): Promise<SyncObject[]> {
    const plan = this.plannedPacks
    if (plan === undefined || plan.packs.length === 0) return plan?.singles ?? []
    await this.ensureWriterRoot(guard)
    await this.ensureCollection(this.writerRootV4 + this.writer + '/packs/', guard)
    await writePublicationPacks(this.publicationPackStore(guard, begin, complete), plan, guard)
    for (const pack of plan.packs) for (const member of pack.location.members) {
      this.verifiedRefs.add('object-' + member.epoch.toString() + '-' + member.hash + '.json')
    }
    return plan.singles
  }

  private legacyArchiveStore(guard: SyncRequestGuard, pending?: SyncArchivePendingPort): SyncLegacyArchiveStore {
    const read = async (root: string, path: string): Promise<string | undefined> => {
      const response = await this.requestAt('GET', root + path, guard)
      if (response.status === 404) return undefined
      requireSuccess(response.status)
      return response.body
    }
    const list = async (root: string, path: string): Promise<string[]> => {
      const address = root + path
      return (await this.listWriterPath(path, guard, root)).map((item: DavResource): string => {
        const name = item.href.substring(address.length).replace(/\/$/, '')
        return name + (item.isCollection ? '/' : '')
      })
    }
    return new SyncLegacyWebDavStore(
      (path: string): Promise<string | undefined> => read(this.writerRoot, path),
      (path: string): Promise<string[]> => list(this.writerRoot, path),
      async (path: string): Promise<void> => {
        const kind = OBJECT_NAME.test(path) ? 'objects' : 'commits'
        // The archive module calls this only after two packs are verified and
        // discoverable; persist the witness before removing the original.
        if (pending === undefined) throw new Error('sync_legacy_archive_pending')
        await pending.recordSeen(kind)
        LEGACY_ARCHIVE_SEEN.add(this.account + ':' + this.space + ':' + kind)
        guard()
        const response = await this.requestAt('DELETE', this.writerRoot + path, guard)
        if (response.status !== 404) requireSuccess(response.status)
      },
      (path: string): Promise<string | undefined> => read(this.writerRootV4, path),
      (path: string): Promise<string[]> => list(this.writerRootV4, path),
      async (path: string): Promise<void> => {
        if (!path.startsWith('legacy-v3/') || path.includes('..')) throw new Error('sync_invalid_path')
        let directory = this.writerRootV4
        for (const part of path.split('/').filter((item: string): boolean => item.length > 0)) {
          directory += part + '/'
          await this.ensureCollection(directory, guard)
        }
      },
      async (path: string, body: string): Promise<void> => {
        requireSuccess((await this.requestAt('PUT', this.writerRootV4 + path, guard, body)).status)
      },
      async (path: string): Promise<void> => {
        const response = await this.requestAt('DELETE', this.writerRootV4 + path, guard)
        if (response.status !== 404) requireSuccess(response.status)
      },
      async (): Promise<SyncLegacyPendingAttempt[]> => pending === undefined ? [] : pending.loadPending(),
      async (attempt: SyncLegacyPendingAttempt): Promise<void> => {
        if (pending === undefined) throw new Error('sync_legacy_archive_pending')
        await pending.recordPending(attempt)
      },
      async (path: string): Promise<void> => {
        if (pending === undefined) throw new Error('sync_legacy_archive_pending')
        await pending.forgetPending(path)
      },
      async (path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean): Promise<void> => {
        if (pending === undefined) throw new Error('sync_legacy_archive_pending')
        await pending.deferPending(path, startedAt, nextCheckAt, checks, awaitingListing)
      })
  }

  private legacyArchiveReader(): SyncLegacyArchiveReader {
    const key = this.account + ':' + this.space
    let reader = LEGACY_ARCHIVE_READERS.get(key)
    if (reader === undefined) {
      if (LEGACY_ARCHIVE_READERS.size >= 4) LEGACY_ARCHIVE_READERS.delete(LEGACY_ARCHIVE_READERS.keys().next().value as string)
      reader = new SyncLegacyArchiveReader()
      LEGACY_ARCHIVE_READERS.set(key, reader)
    }
    return reader
  }

  private async hasLegacyArchive(kind: string, guard: SyncRequestGuard, force: boolean = false): Promise<boolean> {
    const cached = kind === 'commits' ? this.legacyCommitsExist : this.legacyObjectsExist
    const checked = kind === 'commits' ? this.legacyCommitsChecked : this.legacyObjectsChecked
    if (cached === true || (cached === false && !force && Date.now() - checked < 5000)) return cached
    const key = this.account + ':' + this.space + ':' + kind
    const address = this.writerRootV4 + 'legacy-v3/' + kind + '/'
    const response = await this.requestAt('PROPFIND', address, guard, SYNC_LISTING_BODY)
    if (response.status === 404) {
      if (LEGACY_ARCHIVE_SEEN.has(key) || this.archiveSeen(kind)) throw new Error('sync_legacy_archive_unavailable')
      if (kind === 'commits') this.legacyCommitsExist = false
      else this.legacyObjectsExist = false
      if (kind === 'commits') this.legacyCommitsChecked = Date.now()
      else this.legacyObjectsChecked = Date.now()
      return false
    }
    requireSuccess(response.status)
    if (response.status !== 207) throw new Error('sync_collection_listing_failed')
    await readSyncListing(response.body, address, guard)
    if (kind === 'commits') this.legacyCommitsExist = true
    else this.legacyObjectsExist = true
    return true
  }

  private packReader(): SyncPackReader {
    let reader = PACK_READERS.get(this.account)
    if (reader === undefined) {
      if (PACK_READERS.size >= 4) PACK_READERS.delete(PACK_READERS.keys().next().value as string)
      reader = new SyncPackReader()
      PACK_READERS.set(this.account, reader)
    }
    return reader
  }

  private manifestObjects(manifest: SyncManifest): SyncShardRef[] {
    return manifest.datasets.concat(manifest.previous, manifest.alternatives ?? [])
      .flatMap((dataset: SyncDatasetRef): SyncShardRef[] => dataset.shards)
  }

  private recordObjectOwners(writer: string, manifest: SyncManifest): void {
    for (const ref of this.manifestObjects(manifest)) {
      const path = syncShardPath(ref)
      const owners = this.objectOwners.get(path) ?? []
      if (!owners.includes(writer)) this.objectOwners.set(path, owners.concat(writer))
    }
    for (const dataset of manifest.datasets.concat(manifest.previous, manifest.alternatives ?? [])) {
      for (const ref of dataset.shards) this.publicationPackDatasets.set(syncShardPath(ref), dataset.id)
    }
  }

  private objectLocationName(location: SyncObjectLocation): string {
    return 'object-' + location.epoch.toString() + '-' + location.hash + '-' + location.attempt + '.json'
  }

  private recordLocations(manifest: SyncManifest, body: string): void {
    const publication = JSON.parse(body) as SyncWriterPublication
    if (publication.transaction === undefined && publication.locations === undefined) return // early v4
    if (!publication.transaction || !WRITER_NAME.test(publication.transaction) || !Array.isArray(publication.locations)) {
      throw new Error('sync_invalid_commit')
    }
    const refs = new Set<string>(this.manifestObjects(manifest).map((ref: SyncShardRef): string => syncShardPath(ref)))
    const seen = new Set<string>()
    for (const loc of publication.locations) {
      if (!loc || !Number.isSafeInteger(loc.epoch) || loc.epoch < 1 || !/^[0-9a-f]{64}$/.test(loc.hash) ||
        !WRITER_NAME.test(loc.writer) || !WRITER_NAME.test(loc.attempt)) throw new Error('sync_invalid_commit')
      const key = 'object-' + loc.epoch.toString() + '-' + loc.hash + '.json'
      const identity = key + ':' + loc.writer + ':' + loc.attempt
      if (!refs.has(key) || seen.has(identity)) throw new Error('sync_invalid_commit')
      seen.add(identity)
      const values = this.locations.get(key) ?? []
      if (!values.some((item: SyncObjectLocation): boolean => item.writer === loc.writer && item.attempt === loc.attempt)) {
        this.locations.set(key, values.concat(loc))
      }
    }
    if (publication.newTargets !== undefined) {
      if (!Array.isArray(publication.newTargets)) throw new Error('sync_invalid_commit')
      const targets = new Set<string>()
      for (const loc of publication.newTargets) {
        if (!loc || loc.writer !== publication.writer || !WRITER_NAME.test(loc.attempt)) throw new Error('sync_invalid_commit')
        const identity = 'object-' + loc.epoch.toString() + '-' + loc.hash + '.json:' + loc.writer + ':' + loc.attempt
        if (!seen.has(identity) || targets.has(identity)) throw new Error('sync_invalid_commit')
        targets.add(identity)
      }
    }
    const allRefs = this.manifestObjects(manifest)
    if (publication.packLocations !== undefined) {
      if (!Array.isArray(publication.packLocations)) throw new Error('sync_invalid_commit')
      for (const pack of publication.packLocations) {
        validatePublicationPackLocation(pack, allRefs)
        if (!this.publicationPacks.some((value: SyncPublicationPackLocation): boolean =>
          JSON.stringify(value) === JSON.stringify(pack))) this.publicationPacks.push(pack)
      }
      for (const ref of allRefs) this.publicationPackRefs.set(syncShardPath(ref), ref)
    }
    if (publication.newPackTargets !== undefined) {
      if (!Array.isArray(publication.newPackTargets)) throw new Error('sync_invalid_commit')
      for (const pack of publication.newPackTargets) {
        validatePublicationPackLocation(pack, allRefs)
        if (pack.writer !== publication.writer || !(publication.packLocations ?? []).some(
          (value: SyncPublicationPackLocation): boolean => JSON.stringify(value) === JSON.stringify(pack))) {
          throw new Error('sync_invalid_commit')
        }
      }
    }
  }

  private markPublishedLocations(body: string): void {
    const publication = JSON.parse(body) as SyncWriterPublication
    for (const location of publication.locations ?? []) {
      this.publishedLocations.add(location.writer + '/' + this.objectLocationName(location))
    }
  }

  private async readWriterManifest(legacy: SyncRemoteManifest, guard: SyncRequestGuard,
    base: string = this.writerRoot): Promise<SyncRemoteManifest> {
    const isV4 = base === this.writerRootV4
    const marker = isV4 ? V4_PREFIX : ''
    const originalLegacy = legacy.writer === true ? legacy.old : legacy.manifest
    const root = await this.listWriterPath('', guard, base)
    if (!isV4) this.legacyObjectListing = new Set<string>(root.filter((item: DavResource): boolean => !item.isCollection)
      .map((item: DavResource): string => item.href.substring(base.length)).filter((name: string): boolean => OBJECT_NAME.test(name)))
    const names = new Set<string>(root.filter((item: DavResource): boolean => item.isCollection)
      .map((item: DavResource): string => item.href.substring(base.length).replace(/\/$/, ''))
      .filter((name: string): boolean => WRITER_NAME.test(name)))
    const witnesses = this.witnesses.filter((name: string): boolean => isV4 ?
      name.startsWith(V4_PREFIX) && WRITER_PUBLICATION.test(name.substring(V4_PREFIX.length)) : WRITER_PUBLICATION.test(name))
      .map((name: string): string => isV4 ? name.substring(V4_PREFIX.length) : name)
    witnesses.forEach((name: string): void => { names.add(name.split('/')[0]) })
    const hasLegacyArchive = !isV4 && await this.hasLegacyArchive('commits', guard)
    if (hasLegacyArchive) {
      const archived = await legacyArchiveWriters(this.legacyArchiveStore(guard), Array.from(names), witnesses, guard)
      archived.forEach((name: string): void => { names.add(name) })
    }
    if (names.size > 128) throw new Error('sync_replica_limit')
    if (isV4) names.forEach((name: string): void => { this.v4Writers.add(name) })
    const heads: SyncJournalCommit[] = []
    const writerHeads: SyncWriterHead[] = []
    const frontier = legacy.frontier?.slice() ?? []
    if (legacy.manifest !== undefined) heads.push({ format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1, parents: [], manifest: legacy.manifest })
    let own: SyncManifest | undefined = legacy.own
    let ownWritable = legacy.ownWritable ?? true
    let warning = legacy.warning ?? ''
    for (const writer of Array.from(names).sort()) {
      let ownV4Unsafe = false
      const prefix = writer + '/'
      const witness = witnesses.find((name: string): boolean => name.startsWith(prefix))
      const known = isV4 && witness !== undefined && this.isExcludedV4(witness) ? undefined : witness
      const segments = await this.listWriterPath(prefix, guard, base)
      let segmentNames = segments.filter((item: DavResource): boolean => item.isCollection)
        .map((item: DavResource): string => item.href.substring(base.length + prefix.length).replace(/\/$/, ''))
        .filter((segment: string): boolean => /^[0-9]{14}$/.test(segment)).sort().reverse()
      if (hasLegacyArchive) segmentNames = await legacyArchiveSegments(this.legacyArchiveStore(guard), writer, segmentNames, witnesses, guard)
      let listed: string[] = []
      for (const segment of segmentNames) {
        const files = await this.listWriterPath(prefix + segment + '/', guard, base)
        listed = files.filter((item: DavResource): boolean => !item.isCollection)
          .map((item: DavResource): string => item.href.substring(base.length))
          .filter((name: string): boolean => WRITER_PUBLICATION.test(name) && !(isV4 && this.isExcludedV4(name)))
        if (hasLegacyArchive) {
          const physical = listed
          listed = await legacyArchiveCandidates(this.legacyArchiveStore(guard), writer, segment, physical, witnesses, guard)
          if (listed.some((path: string): boolean => !physical.includes(path) && !witnesses.includes(path))) {
            await this.recordArchiveSeen('commits', guard)
            LEGACY_ARCHIVE_SEEN.add(this.account + ':' + this.space + ':commits')
          }
        }
        // MKCOL can complete before the first PUT in a new segment.
        if (listed.length > 0) break
      }
      const candidates = listed.slice()
      if (known !== undefined && !candidates.includes(known)) candidates.push(known)
      candidates.sort().reverse()
      let accepted = false
      for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
        const path = candidates[candidateIndex]
        const current = WRITER_PUBLICATION.exec(path)
        if (candidates.some((name: string): boolean => {
          const other = WRITER_PUBLICATION.exec(name)
          return current !== null && other !== null && other[3] === current[3] && other[4] !== current[4]
        })) {
          warning = 'sync_writer_conflicting_publications'
          if (writer === this.writer) { ownWritable = false; if (isV4) ownV4Unsafe = true }
          continue
        }
        try {
          const read = await this.readWriterHead(marker + path, listed.includes(path), guard)
          if (read === undefined) throw new Error('sync_shard_missing')
          if (writer === this.writer) {
            own = read
            // A healthy current v4 head can advance even when the older v3
            // writer is damaged; its warning remains visible separately.
            if (isV4) ownWritable = !ownV4Unsafe
          }
          heads.push({ format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1, parents: [], manifest: read })
          writerHeads.push({ path: marker + path, manifest: read, segments: segmentNames,
            listed: listed.map((value: string): string => marker + value), root: marker })
          if (isV4) this.recordObjectOwners(writer, read)
          else this.manifestObjects(read).forEach((ref: SyncShardRef): void => {
            this.legacyWriterObjects.add(syncShardPath(ref))
          })
          frontier.push(marker + (known !== undefined && known > path ? known : path))
          accepted = true
          break
        } catch (error) {
          const code = (error as Error).message
          const sameLater = candidates.slice(candidateIndex + 1).some((otherPath: string): boolean => {
            const other = WRITER_PUBLICATION.exec(otherPath)
            return current !== null && other !== null && other[3] === current[3] && other[4] === current[4]
          })
          if (sameLater && (code === 'sync_shard_missing' || code === 'sync_invalid_commit' || code === 'sync_shard_damaged')) continue
          const prior = known === undefined ? null : WRITER_PUBLICATION.exec(known)
          const isKnownCommit = prior !== null && current !== null && prior[3] === current[3] && prior[4] === current[4]
          // An already observed publication missing from both the listing and
          // its direct GET is not evidence that an older writer head is current.
          // Keep the local projection and retry discovery instead of rewinding.
          if (isKnownCommit && code === 'sync_shard_missing') {
            throw new Error('sync_remote_changed')
          }
          if (code !== 'sync_shard_missing' && code !== 'sync_invalid_commit' && code !== 'sync_shard_damaged') throw error as Error
          warning = code
          if (writer === this.writer) { ownWritable = false; if (isV4) ownV4Unsafe = true }
        }
      }
      if (!accepted && known !== undefined) frontier.push(marker + known)
    }
    if (frontier.length === (legacy.frontier?.length ?? 0)) {
      legacy.writer = true
      legacy.old = originalLegacy
      legacy.warning = warning
      legacy.ownWritable = ownWritable
      return legacy
    }
    const manifest = heads.length === 0 ? undefined : mergeSyncJournal(heads, this.space)
    return { manifest, own, old: originalLegacy, writer: true, journal: true, frontier, warning, ownWritable,
      writerHeads: (legacy.writerHeads ?? []).concat(writerHeads),
      hash: manifest === undefined ? '' : syncDigest(JSON.stringify(manifest)),
      legacyHash: legacy.legacyHash, legacyRevision: legacy.legacyRevision, legacySpace: legacy.legacySpace,
      etag: '"writer-' + syncDigest(JSON.stringify([legacy.etag, frontier])) + '"' }
  }

  async readEarlierWriterGroup(head: SyncWriterHead, guard: SyncRequestGuard,
    accept: (manifest: SyncManifest) => Promise<boolean>): Promise<boolean> {
    const marker = head.root ?? ''
    const base = marker === V4_PREFIX ? this.writerRootV4 : this.writerRoot
    const physicalPath = marker.length > 0 ? head.path.substring(marker.length) : head.path
    const parts = physicalPath.split('/')
    const writer = parts[0]
    const currentSegment = parts[1]
    let remaining = SEGMENT_SIZE
    const segments = Array.from(new Set<string>([currentSegment].concat(head.segments)))
      .filter((segment: string): boolean => segment <= currentSegment).sort().reverse()
    for (const segment of segments.slice(0, 4)) {
      const prefix = marker + writer + '/' + segment + '/'
      let listed = head.listed.some((path: string): boolean => path.startsWith(prefix)) ?
        head.listed : (await this.listWriterPath(writer + '/' + segment + '/', guard, base))
          .filter((item: DavResource): boolean => !item.isCollection)
          .map((item: DavResource): string => marker + item.href.substring(base.length))
          .filter((path: string): boolean => WRITER_PUBLICATION.test(path.substring(marker.length)))
      if (marker === '') listed = await legacyArchiveCandidates(this.legacyArchiveStore(guard), writer, segment, listed, [], guard)
      const currentSequence = WRITER_PUBLICATION.exec(physicalPath)?.[3]
      for (const path of listed.filter((item: string): boolean => {
        const sequence = WRITER_PUBLICATION.exec(item.substring(marker.length))?.[3]
        return sequence !== undefined && currentSequence !== undefined && sequence < currentSequence
      }).sort().reverse()) {
        if (remaining-- <= 0) return false
        const current = WRITER_PUBLICATION.exec(path.substring(marker.length))
        if (listed.some((item: string): boolean => {
          const other = WRITER_PUBLICATION.exec(item.substring(marker.length))
          return current !== null && other !== null && other[3] === current[3] && other[4] !== current[4]
        })) continue
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
    // A stale listing may retain a removed v4 witness. Recheck that exact
    // durable witness rather than treating the local cache as proof it exists.
    if (listed && cached !== undefined && !(path.startsWith(V4_PREFIX) && this.witnesses.includes(path))) {
      const manifest = copySyncManifest(cached.commit.manifest, this.space)
      if (path.startsWith(V4_PREFIX)) {
        this.recordObjectOwners(path.substring(V4_PREFIX.length).split('/')[0], manifest)
        if (cached.body !== undefined) {
          this.recordLocations(manifest, cached.body)
          this.markPublishedLocations(cached.body)
        }
      }
      else this.manifestObjects(manifest).forEach((ref: SyncShardRef): void => {
        this.legacyWriterObjects.add(syncShardPath(ref))
      })
      return manifest
    }
    const remote = await this.readCommit(path, guard, listed || this.witnesses.includes(path))
    if (remote?.manifest === undefined) return undefined
    if (!path.startsWith(V4_PREFIX)) this.manifestObjects(remote.manifest).forEach((ref: SyncShardRef): void => {
      this.legacyWriterObjects.add(syncShardPath(ref))
    })
    if (cached === undefined) {
      const bytes = syncUtf8(JSON.stringify(remote.manifest)).byteLength
      journalCache.push({ address: key, commit: { format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1,
        parents: [], manifest: remote.manifest }, bytes, body: this.publicationBodies.get(path) })
      journalCacheBytes += bytes
      while (journalCacheBytes > 8 * SYNC_MAX_OBJECT_BYTES || journalCache.length > 4096) {
        journalCacheBytes -= journalCache.shift()?.bytes ?? 0
      }
    }
    return remote.manifest
  }

  async readSharedHead(guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const address = this.sharedRoot + 'heads/'
    const names = (await this.listWriterPath('', guard, address))
      .filter((item: DavResource): boolean => !item.isCollection)
      .map((item: DavResource): string => normalizedDavHref(item.href).substring(normalizedDavHref(address).length))
      .filter((name: string): boolean => SYNC_COMMIT_NAME.test(name)).sort()
    if (names.length > 0) {
      const commits = new Map<string, SyncJournalCommit>()
      for (let start = 0; start < names.length; start += 4) {
        const batch = names.slice(start, start + 4)
        const rows = await Promise.all(batch.map((name: string): Promise<SyncJournalCommit> =>
          this.readSharedCommit(name, guard)))
        rows.forEach((row: SyncJournalCommit, index: number): void => { commits.set(batch[index], row) })
      }
      const parents = new Set<string>()
      commits.forEach((commit: SyncJournalCommit): void => { commit.parents.forEach((name: string): void => { parents.add(name) }) })
      const heads = names.filter((name: string): boolean => !parents.has(name))
      const rows = heads.map((name: string): SyncJournalCommit => commits.get(name)!)
      if (rows.length === 0) throw new Error('sync_invalid_commit')
      const space = rows[0].manifest.space
      if (rows.some((commit: SyncJournalCommit): boolean => commit.manifest.space !== space)) throw new Error('sync_space_changed')
      const manifest = rows.length === 1 ? rows[0].manifest : mergeSyncJournal(rows, space)
      if (rows.length > 1) {
        const frontier = new Set<string>()
        const hashes = new Set<string>()
        let migrating = false
        rows.forEach((commit: SyncJournalCommit): void => {
          const legacy = commit.manifest.legacyMigration
          if (legacy === undefined) return
          migrating = true
          legacy.frontier.forEach((name: string): void => { frontier.add(name) })
          if (legacy.legacyHash !== undefined) hashes.add(legacy.legacyHash)
        })
        if (migrating) manifest.legacyMigration = { frontier: Array.from(frontier).sort(),
          legacyHash: hashes.size === 1 ? Array.from(hashes)[0] : undefined }
      }
      this.checkSharedManifest(manifest)
      const etag = syncDigest(heads.join('\n'))
      return { manifest, etag, hash: syncDigest(JSON.stringify(manifest)), sharedHash: etag, sharedHeads: heads,
        sharedSuperseded: names.filter((name: string): boolean => parents.has(name)) }
    }
    const response = await this.requestAt('GET', this.sharedRoot + MANIFEST, guard)
    if (response.status === 404) return { etag: '', hash: '', sharedHash: '' }
    requireSuccess(response.status)
    const manifest = decodeSyncManifest(response.body)
    this.checkSharedManifest(manifest)
    const hash = syncDigest(response.body)
    return { manifest, etag: hash, hash, sharedHash: hash }
  }

  private checkSharedManifest(manifest: SyncManifest): void {
    if ((this.boundSpace && manifest.space !== this.space) || manifest.maintenance || manifest.previous.length > 0 ||
      manifest.datasets.concat(manifest.alternatives ?? []).some((dataset: SyncDatasetRef): boolean =>
        dataset.shards.some((ref: SyncShardRef): boolean => ref.slot === undefined))) {
      throw new Error('sync_invalid_manifest')
    }
    this.space = manifest.space
  }

  private async readSharedCommit(name: string, guard: SyncRequestGuard): Promise<SyncJournalCommit> {
    const address = this.sharedRoot + 'heads/' + name
    const key = this.account + '\n' + address
    const cached = journalCache.find((entry: CachedJournalCommit): boolean => entry.address === key)
    if (cached !== undefined) return cached.commit
    const response = await this.requestAt('GET', address, guard)
    if (response.status === 404) throw new Error('sync_remote_changed')
    requireSuccess(response.status)
    const commit = decodeSyncCommit(name, response.body)
    this.checkSharedManifest(commit.manifest)
    const bytes = syncUtf8(response.body).byteLength
    journalCache.push({ address: key, commit, bytes })
    journalCacheBytes += bytes
    while (journalCacheBytes > 8 * SYNC_MAX_OBJECT_BYTES || journalCache.length > 4096) {
      journalCacheBytes -= journalCache.shift()?.bytes ?? 0
    }
    return commit
  }

  async readSyncState(guard: SyncRequestGuard, requiredTag: string = ''): Promise<SyncRemoteManifest> {
    let remote = await this.readSharedHead(guard)
    if (remote.manifest === undefined) {
      remote = await this.readManifest(guard)
      remote.sharedHash = ''
      remote.writer = false
    }
    if (requiredTag !== '' && remote.etag !== requiredTag) throw new Error('sync_preview_changed')
    return remote
  }

  private sharedObjectPath(dataset: string, ref: SyncShardRef): string {
    if (!/^[a-z0-9-]{1,64}$/.test(dataset) || !/^g-[0-7](?:-[0-9a-f]{1,64})?$/.test(ref.bucket) ||
      (ref.slot !== 'a' && ref.slot !== 'b')) throw new Error('sync_invalid_path')
    if (ref.immutable !== undefined && !WRITER_NAME.test(ref.immutable)) throw new Error('sync_invalid_path')
    return this.sharedRoot + dataset + '-' + ref.bucket + '-' +
      (ref.immutable === undefined ? ref.slot : ref.hash + '-' + ref.immutable) + '.json'
  }

  async readSharedObject(dataset: string, ref: SyncShardRef, guard: SyncRequestGuard): Promise<string> {
    const response = await this.requestAt('GET', this.sharedObjectPath(dataset, ref), guard)
    if (response.status === 404) throw new Error('sync_shard_missing')
    requireSuccess(response.status)
    if (!(await validSyncObject(ref, response.body, guard))) {
      // A reader can hold a manifest while another device advances its slots.
      // Refresh the index before applying data from a different revision.
      const current = await this.readSharedHead(guard)
      if (current.manifest?.datasets.concat(current.manifest.alternatives ?? []).some((row: SyncDatasetRef): boolean => row.id === dataset &&
        row.shards.some((active: SyncShardRef): boolean => active.bucket === ref.bucket && active.slot === ref.slot &&
          active.hash === ref.hash))) throw new Error('sync_shard_damaged')
      throw new Error('sync_remote_changed')
    }
    return response.body
  }

  /** Finish migrating remote datasets outside the selected scope without applying them locally. */
  async prepareSharedMigration(manifest: SyncManifest, objects: SyncObject[], guard: SyncRequestGuard): Promise<void> {
    const datasets: SyncDatasetRef[] = []
    const branches = new Map<string, SyncDatasetRef[]>()
    for (const row of manifest.datasets.concat(manifest.alternatives ?? [])) {
      branches.set(row.id, (branches.get(row.id) ?? []).concat(row))
    }
    for (const id of Array.from(branches.keys()).sort()) {
      const rows = branches.get(id) ?? []
      if (rows.length === 1 && rows[0].shards.every((ref: SyncShardRef): boolean => ref.immutable !== undefined)) {
        datasets.push(rows[0])
        continue
      }
      const source: SyncObject[] = []
      for (const row of rows) {
        if (row.schema !== 1) throw new Error('sync_update_required')
        for (let start = 0; start < row.shards.length; start += 4) {
          const batch = row.shards.slice(start, start + 4)
          const bodies = await Promise.all(batch.map((ref: SyncShardRef): Promise<string> => {
            const planned = objects.find((object: SyncObject): boolean => object.dataset === id && object.ref.hash === ref.hash)
            if (planned !== undefined) return Promise.resolve(planned.body)
            return ref.slot === undefined ? this.readObject(ref, guard) : this.readSharedObject(id, ref, guard)
          }))
          for (let i = 0; i < batch.length; i++) source.push({ ref: batch[i], body: bodies[i] })
          guard()
        }
      }
      const shared = rows.find((row: SyncDatasetRef): boolean =>
        row.shards.every((ref: SyncShardRef): boolean => ref.slot !== undefined))
      const built = await taskpool.execute(buildMigratedDataset, id, source, manifest.epoch, shared) as SyncDataset
      guard()
      datasets.push(built.ref)
      for (let i = objects.length - 1; i >= 0; i--) {
        const object = objects[i]
        if (object.dataset === id && !built.ref.shards.some((ref: SyncShardRef): boolean =>
          ref.bucket === object.ref.bucket && ref.slot === object.ref.slot && ref.hash === object.ref.hash &&
          ref.immutable === object.ref.immutable)) objects.splice(i, 1)
      }
      objects.push(...built.objects)
    }
    manifest.datasets = datasets
    manifest.previous = []
    manifest.alternatives = []
  }

  async publishShared(manifest: SyncManifest, objects: SyncObject[], expected: string, guard: SyncRequestGuard,
    beforeSend: () => Promise<void>): Promise<SyncRemoteManifest> {
    if (expected === '') await this.ensureCollection(this.sharedRoot, guard)
    const current = await this.readSharedHead(guard)
    if (current.sharedHash !== expected) throw new Error('sync_remote_changed')
    const headRoot = this.sharedRoot + 'heads/'
    if (current.sharedHeads === undefined) await this.ensureCollection(headRoot, guard)
    const parents = current.sharedHeads ?? []
    const body = syncCommitBody(manifest, parents)
    const name = syncCommitName(body)
    await beforeSend()
    // Both payloads and publications have immutable names. A late writer
    // can create a concurrent head, but it cannot overwrite either payload.
    for (const object of objects) {
      const dataset = object.dataset ?? ''
      const path = this.sharedObjectPath(dataset, object.ref)
      requireSuccess((await this.requestAt('PUT', path, guard, object.body)).status)
      await this.readSharedObject(dataset, object.ref, guard)
    }
    if ((await this.readSharedHead(guard)).sharedHash !== expected) throw new Error('sync_remote_changed')
    requireSuccess((await this.requestAt('PUT', headRoot + name, guard, body)).status)
    const receipt = await this.readSharedCommit(name, guard)
    for (const parent of parents.concat(current.sharedSuperseded ?? [])) {
      // The verified child retains every selected or opaque dataset. An
      // unobserved concurrent commit has a different name and is never removed.
      try { await this.requestAt('DELETE', headRoot + parent, guard) } catch (_error) {}
    }
    this.scheduleSharedCollection(guard, true)
    const tag = syncDigest(name)
    return { manifest: receipt.manifest, hash: syncDigest(JSON.stringify(receipt.manifest)),
      etag: tag, sharedHash: tag, sharedHeads: [name] }
  }

  scheduleSharedCollection(guard: SyncRequestGuard, published: boolean = false): void {
    let sweep = SHARED_SWEEPS.get(this.account)
    if (sweep === undefined) {
      if (SHARED_SWEEPS.size >= 8) SHARED_SWEEPS.delete(SHARED_SWEEPS.keys().next().value as string)
      sweep = { next: 0, running: false, needsScan: true, unreferenced: new Map<string, number>() }
      SHARED_SWEEPS.set(this.account, sweep)
    }
    if (published) sweep.needsScan = true
    const now = syncMetricUptime()
    if (sweep.running || now < sweep.next || (!sweep.needsScan && sweep.unreferenced.size === 0)) return
    const state = sweep
    state.running = true
    state.needsScan = false
    state.next = now + SHARED_GC_DELAY_MS
    void this.collectSharedObjects(state, guard).catch((): void => { state.needsScan = true })
      .finally((): void => { state.running = false })
  }

  private async collectSharedObjects(state: SharedCollectionSweep, guard: SyncRequestGuard): Promise<void> {
    const remote = await this.readSharedHead(guard)
    const manifest = remote.manifest
    if (manifest === undefined || remote.sharedHeads === undefined) return
    const referenced = new Set<string>()
    for (const dataset of manifest.datasets.concat(manifest.alternatives ?? [])) {
      for (const ref of dataset.shards) referenced.add(this.sharedObjectPath(dataset.id, ref))
    }
    const now = syncMetricUptime()
    const seen = new Map<string, number>()
    const obsolete: string[] = []
    for (const item of await this.listWriterPath('', guard, this.sharedRoot)) {
      const name = normalizedDavHref(item.href).substring(normalizedDavHref(this.sharedRoot).length)
      const address = this.sharedRoot + name
      if (item.isCollection || referenced.has(address) ||
        (name !== MANIFEST && !SHARED_OBJECT_NAME.test(name) && !SHARED_OLD_SLOT_NAME.test(name))) continue
      const since = state.unreferenced.get(address) ?? now
      seen.set(address, since)
      // Leave an unreferenced blob readable across in-flight WebDAV calls.
      if (now - since >= SHARED_GC_DELAY_MS) obsolete.push(address)
    }
    state.unreferenced = seen
    if (obsolete.length === 0 || (await this.readSharedHead(guard)).sharedHash !== remote.sharedHash) return
    for (const address of obsolete.slice(0, 64)) {
      const response = await this.requestAt('DELETE', address, guard)
      if (response.status !== 404) requireSuccess(response.status)
      state.unreferenced.delete(address)
    }
  }

  async verifySharedWrite(remote: SyncRemoteManifest, datasets: string[], guard: SyncRequestGuard,
    cached: (id: string, ref: SyncShardRef) => Promise<string | undefined>): Promise<void> {
    for (const dataset of remote.manifest?.datasets ?? []) {
      if (!datasets.includes(dataset.id)) continue
      for (const ref of dataset.shards) {
        try {
          await this.readSharedObject(dataset.id, ref, guard)
        } catch (error) {
          const code = (error as Error).message
          if (code !== 'sync_shard_damaged' && code !== 'sync_shard_missing') throw error as Error
          const body = await cached(dataset.id, ref)
          if (body === undefined || !(await validSyncObject(ref, body, guard))) throw error as Error
          // Restore exactly the content the current manifest commits to.
          // Never replace a slot that belongs to a newer manifest.
          if ((await this.readSharedHead(guard)).hash !== remote.hash) throw new Error('sync_remote_changed')
          requireSuccess((await this.requestAt('PUT', this.sharedObjectPath(dataset.id, ref), guard, body)).status)
          await this.readSharedObject(dataset.id, ref, guard)
        }
      }
    }
    if ((await this.readSharedHead(guard)).hash !== remote.hash) throw new Error('sync_remote_changed')
  }

  /** Only an already committed and readable shared snapshot can retire legacy directories. */
  async retireMigratedLegacy(guard: SyncRequestGuard): Promise<void> {
    const shared = await this.readSharedHead(guard)
    const manifest = shared.manifest
    const migrated = manifest?.legacyMigration
    if (manifest === undefined || migrated === undefined) return
    const legacy = await this.readManifest(guard)
    if (legacy.warning) throw new Error(legacy.warning)
    const added = (legacy.frontier ?? []).some((path: string): boolean => !migrated.frontier.includes(path)) ||
      (legacy.legacyHash !== undefined && legacy.legacyHash !== migrated.legacyHash)
    if (added && legacy.manifest !== undefined) {
      // An older device finished writing during the upgrade. Merge that
      // contribution into the shared index before another cleanup attempt.
      const next = copySyncManifest(manifest)
      next.epoch = Math.max(manifest.epoch, legacy.manifest.epoch)
      next.revision = Math.max(manifest.revision + 1, next.epoch)
      next.alternatives = (next.alternatives ?? []).concat(legacy.manifest.datasets, legacy.manifest.alternatives ?? [])
      const objects: SyncObject[] = []
      await this.prepareSharedMigration(next, objects, guard)
      next.legacyMigration = { frontier: legacy.frontier ?? [], legacyHash: legacy.legacyHash }
      await this.publishShared(next, objects, shared.sharedHash ?? shared.hash, guard, async (): Promise<void> => {})
      return
    }
    for (const dataset of manifest.datasets.concat(manifest.alternatives ?? [])) {
      for (let start = 0; start < dataset.shards.length; start += 4) {
        await Promise.all(dataset.shards.slice(start, start + 4).map((ref: SyncShardRef): Promise<string> =>
          this.readSharedObject(dataset.id, ref, guard)))
      }
    }
    if ((await this.readSharedHead(guard)).hash !== shared.hash) throw new Error('sync_remote_changed')
    // Delete only application-owned protocol collections. A retry can see a
    // subset of the original frontier after a previous partial cleanup.
    for (const root of [this.directory + 'koma-device-sync-v1/', this.root, this.writerRoot, this.writerRootV4]) {
      const response = await this.requestAt('DELETE', root, guard)
      if (response.status !== 404) requireSuccess(response.status)
      if (response.status === 207) throw new Error('sync_collection_cleanup_failed')
    }
    const next = copySyncManifest(manifest)
    next.legacyMigration = undefined
    next.revision++
    await this.publishShared(next, [], shared.sharedHash ?? shared.hash, guard, async (): Promise<void> => {})
  }

  async readManifest(guard: SyncRequestGuard, requiredTag: string = '', discoveryOnly: boolean = false): Promise<SyncRemoteManifest> {
    // Another device can create a legacy archive between two reads on the
    // same provider. Do not let a cached missing directory hide newer heads.
    this.legacyCommitsExist = undefined
    let legacy: SyncRemoteManifest
    const previous = legacyDiscovery.find((entry: LegacyDiscovery): boolean =>
      entry.account === this.account && entry.space === this.space)
    const hasWriterWitness = this.witnesses.some((name: string): boolean => WRITER_PUBLICATION.test(name) ||
      (name.startsWith(V4_PREFIX) && WRITER_PUBLICATION.test(name.substring(V4_PREFIX.length))))
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
    let result = legacy
    if (this.writer !== '') {
      const cached = v3Discovery.find((entry: V3Discovery): boolean =>
        entry.account === this.account && entry.space === this.space && entry.writer === this.writer)
      const v3Witnesses = this.witnesses.filter((name: string): boolean => WRITER_PUBLICATION.test(name))
      const hasV4Witness = this.witnesses.some((name: string): boolean => name.startsWith(V4_PREFIX) &&
        WRITER_PUBLICATION.test(name.substring(V4_PREFIX.length)))
      if (discoveryOnly && requiredTag === '' && hasV4Witness && cached !== undefined &&
        cached.legacyTag === legacy.etag && Date.now() - cached.checked < LEGACY_DISCOVERY_MS &&
        v3Witnesses.every((name: string): boolean => cached.manifest.frontier?.includes(name) === true)) {
        result = JSON.parse(JSON.stringify(cached.manifest)) as SyncRemoteManifest
        for (const head of result.writerHeads ?? []) this.manifestObjects(head.manifest)
          .forEach((ref: SyncShardRef): void => { this.legacyWriterObjects.add(syncShardPath(ref)) })
      } else {
        result = await this.readWriterManifest(legacy, guard)
        if (cached !== undefined) v3Discovery.splice(v3Discovery.indexOf(cached), 1)
        v3Discovery.push({ account: this.account, space: this.space, writer: this.writer,
          checked: Date.now(), legacyTag: legacy.etag,
          manifest: JSON.parse(JSON.stringify(result)) as SyncRemoteManifest })
        if (v3Discovery.length > 8) v3Discovery.shift()
      }
    }
    if (this.writer !== '') result = await this.readWriterManifest(result, guard, this.writerRootV4)
    if (legacy.warning === 'sync_legacy_unavailable' && result.manifest === undefined) throw new Error('sync_space_changed')
    if (requiredTag !== '' && requiredTag !== result.etag) throw new Error('sync_preview_changed')
    this.witnesses.splice(0, this.witnesses.length, ...(result.frontier ?? []))
    this.observedV4Frontier = (result.frontier ?? []).filter((name: string): boolean => name.startsWith(V4_PREFIX)).sort()
    this.v4Refresh = undefined
    return result
  }

  private async v4HeadChanged(guard: SyncRequestGuard): Promise<boolean> {
    if (this.observedV4Frontier.length === 0) return false
    if (this.v4Refresh === undefined) {
      const refresh = (async (): Promise<boolean> => {
        const current = await this.readWriterManifest({ etag: '', hash: '', frontier: [] }, guard, this.writerRootV4)
        const now = (current.frontier ?? []).filter((name: string): boolean => name.startsWith(V4_PREFIX)).sort()
        return JSON.stringify(now) !== JSON.stringify(this.observedV4Frontier)
      })()
      this.v4Refresh = refresh.finally((): void => { this.v4Refresh = undefined })
    }
    return this.v4Refresh
  }

  async readObject(ref: SyncShardRef, guard: SyncRequestGuard): Promise<string> {
    const path = syncShardPath(ref)
    const packed = await this.prefetchPublicationObjects([ref], guard)
    const fromPack = packed.get(path)
    if (fromPack !== undefined && await validSyncObject(ref, fromPack, guard)) {
      this.verifiedRefs.add(path)
      return fromPack
    }
    // A restarted writer may be recovering a sent intent before discovering
    // heads. Its staged objects already live under its own writer directory.
    const known = this.objectOwners.get(path) ?? []
    const owners = Array.from(new Set<string>(known.concat(this.writer !== '' ? [this.writer] : [], Array.from(this.v4Writers))))
    let damaged = false
    const read = async (address: string): Promise<string | undefined> => {
      const object = await this.requestAt('GET', address, guard)
      if (object.status !== 404) {
        requireSuccess(object.status)
        if (await validSyncObject(ref, object.body, guard)) {
          this.verifiedRefs.add(path)
          return object.body
        }
        damaged = true
      }
      return undefined
    }
    const readLegacy = async (): Promise<string | undefined> => {
      if (this.writer !== '') {
        const old = await read(this.writerRoot + path)
        if (old !== undefined) return old
      }
      const old = await read(this.root + path)
      if (old !== undefined) return old
      if (this.legacyObjects.some((value: SyncShardRef): boolean => syncShardPath(value) === path)) {
        return read(this.directory + 'koma-device-sync-v1/' + path)
      }
      return undefined
    }
    // A v4 head can carry an unchanged v3 ref without moving its contents.
    // Head ownership alone does not imply a v4 object location.
    const legacyFirst = this.legacyWriterObjects.has(path) && (this.locations.get(path)?.length ?? 0) === 0
    if (legacyFirst) {
      const legacy = await readLegacy()
      if (legacy !== undefined) return legacy
    }
    for (const location of this.locations.get(path) ?? []) {
      const object = await read(this.writerRootV4 + location.writer + '/objects/' + this.objectLocationName(location))
      if (object !== undefined) return object
    }
    for (const owner of owners) {
      const object = await read(this.writerRootV4 + owner + '/objects/' + path)
      if (object !== undefined) return object
    }
    if (!legacyFirst) {
      const legacy = await readLegacy()
      if (legacy !== undefined) return legacy
    }
    // A fresh provider can be handed a previously cached manifest without its
    // location table (for example, the focused-reader path). Discover exact
    // immutable attempts only when the direct known paths did not work.
    const prefix = path.substring(0, path.length - 5) + '-'
    for (const owner of owners) {
      const directory = owner + '/objects/'
      const entries = await this.listWriterPath(directory, guard, this.writerRootV4)
      for (const entry of entries) {
        const name = entry.href.substring((this.writerRootV4 + directory).length)
        if (entry.isCollection || !name.startsWith(prefix) || !name.endsWith('.json')) continue
        const attempt = name.substring(prefix.length, name.length - 5)
        if (!WRITER_NAME.test(attempt)) continue
        const value = await read(entry.href)
        if (value !== undefined) return value
      }
    }
    let legacyFailure: Error | undefined
    // A v4 head can retain an old v3 ref which no current v3 head mentions.
    // Only an exact, newly staged target is known not to be a v3 archive.
    if (!(this.recoveringPublication && this.recoveryTargets.has(path)) && await this.hasLegacyArchive('objects', guard, true)) {
      try {
        const archived = await this.legacyArchiveReader().read(this.legacyArchiveStore(guard), path, guard, true)
        if (archived !== undefined && await validSyncObject(ref, archived, guard)) {
          await this.recordArchiveSeen('objects', guard)
          LEGACY_ARCHIVE_SEEN.add(this.account + ':' + this.space + ':objects')
          guard()
          this.verifiedRefs.add(path)
          return archived
        }
      } catch (error) { guard(); legacyFailure = error as Error }
    }
    // Existing publications keep their precise locator, but the immutable
    // object may have been moved into its writer's verified pack.
    let packFailure: Error | undefined = this.publicationPacks.some((pack: SyncPublicationPackLocation): boolean =>
      pack.members.some((member): boolean => member.epoch === ref.epoch && member.hash === ref.hash)) ?
      new Error('sync_pack_not_found') : undefined
    const candidates = Array.from(new Set<string>((this.locations.get(path) ?? [])
      .map((location: SyncObjectLocation): string => location.writer).concat(owners)))
    for (const owner of candidates) {
      const directory = this.writerRootV4 + owner + '/packs/'
      try {
        const response = await this.requestAt('PROPFIND', directory, guard, SYNC_LISTING_BODY)
        if (response.status === 404) {
          const pendingTarget = owner === this.writer && this.recoveringPublication && this.recoveryTargets.has(path)
          const possible = !pendingTarget && ((this.locations.get(path) ?? []).some((location: SyncObjectLocation): boolean =>
            location.writer === owner && (this.publishedLocations.has(owner + '/' + this.objectLocationName(location)) ||
              !this.recoveringPublication || !this.recoveryTargets.has(path))) ||
            (this.v4Writers.has(owner) && !this.legacyWriterObjects.has(path) &&
              (!this.recoveringPublication || !this.recoveryTargets.has(path))))
          if (possible && packFailure === undefined) packFailure = new Error('sync_pack_not_found')
          continue
        }
        requireSuccess(response.status)
        if (response.status !== 207) throw new Error('sync_collection_listing_failed')
        await readSyncListing(response.body, directory, guard)
        const found = await this.packReader().read(this.packStore(guard), owner, ref.epoch, ref.hash, ref.bytes, guard)
        this.verifiedRefs.add(path)
        return found
      } catch (error) {
        guard()
        if ((error as Error).message === 'sync_pack_not_found' && owner === this.writer &&
          this.recoveringPublication && this.recoveryTargets.has(path)) continue
        if (packFailure === undefined) packFailure = error as Error
      }
    }
    // A writer may publish a new head while a reader holds its previous one.
    // Share one re-discovery across concurrent shard failures in this round;
    // unchanged heads retain the established damage/fallback behavior.
    if (await this.v4HeadChanged(guard)) throw new Error('sync_remote_changed')
    if (legacyFailure !== undefined) throw legacyFailure as Error
    if (packFailure !== undefined) throw packFailure as Error
    throw new Error(damaged ? 'sync_shard_damaged' : 'sync_shard_missing')
  }

  async prefetchLegacyObjects(refs: SyncShardRef[], guard: SyncRequestGuard): Promise<Map<string, string>> {
    const result = new Map<string, string>()
    const candidates = refs.filter((ref: SyncShardRef): boolean => {
      const path = syncShardPath(ref)
      return this.legacyWriterObjects.has(path) && (this.locations.get(path)?.length ?? 0) === 0
    }).map((ref: SyncShardRef): string => syncShardPath(ref))
    if (candidates.length === 0 || !(await this.hasLegacyArchive('objects', guard))) return result
    const found = await this.legacyArchiveReader().readMany(this.legacyArchiveStore(guard), candidates, guard, this.legacyReadSession)
    guard()
    if (found.incomplete && found.missing.length > 0) throw new Error('sync_legacy_archive_incomplete')
    for (const entry of found.entries) result.set(entry.path, entry.body)
    if (found.entries.length > 0) {
      await this.recordArchiveSeen('objects', guard)
      LEGACY_ARCHIVE_SEEN.add(this.account + ':' + this.space + ':objects')
    }
    return result
  }

  confirmPrefetchedObject(ref: SyncShardRef): void { this.verifiedRefs.add(syncShardPath(ref)) }

  async storeObject(object: SyncObject, guard: SyncRequestGuard): Promise<void> {
    const path = syncShardPath(object.ref)
    if (!(await validSyncObject(object.ref, object.body, guard))) {
      throw new Error('sync_shard_damaged')
    }
    if (this.writer !== '') {
      await this.ensureWriterObjects(guard)
      if (this.recoveringPublication) throw new Error('sync_replan_required')
      const target = this.planned?.targets.get(path)
      const location = target !== undefined ? target :
        { epoch: object.ref.epoch, hash: object.ref.hash, writer: this.writer, attempt: util.generateRandomUUID() } as SyncObjectLocation
      const address = this.writerRootV4 + this.writer + '/objects/' + this.objectLocationName(location)
      if (this.attemptedLocations.has(address)) throw new Error('sync_replan_required')
      this.attemptedLocations.add(address)
      // An interrupted PUT may still reach the server later. Never send a
      // second request to that path, even when the bytes are identical.
      requireSuccess((await this.requestAt('PUT', address, guard, object.body)).status)
      const stored = await this.requestAt('GET', address, guard)
      requireSuccess(stored.status)
      if (stored.body !== object.body) throw new Error('sync_shard_damaged')
      const locations = this.locations.get(path) ?? []
      if (!locations.some((value: SyncObjectLocation): boolean => value.writer === location.writer && value.attempt === location.attempt)) {
        this.locations.set(path, locations.concat(location))
      }
      this.ownObjects.add(path)
      if (target === undefined) this.planned = undefined
      return
    }
    const address = this.root + path
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

  commitName(manifest: SyncManifest, frontier: string[], objects: SyncObject[] = []): string {
    const body = this.commitBody(manifest, frontier, objects)
    return this.writer === '' ? syncCommitName(body) : this.planned!.path
  }

  commitBody(manifest: SyncManifest, frontier: string[], objects: SyncObject[] = []): string {
    if (this.writer === '') return syncCommitBody(manifest, frontier)
    const signature = JSON.stringify([manifest, objects.map((object: SyncObject): string => syncShardPath(object.ref)).sort()])
    if (this.planned?.signature === signature) return this.planned.body
    const transaction = util.generateRandomUUID()
    const singles = this.plannedPacks?.singles ?? objects
    const toWrite = new Set<string>(singles.map((object: SyncObject): string => syncShardPath(object.ref)))
    const refs = new Map<string, SyncShardRef>()
    this.manifestObjects(manifest).forEach((ref: SyncShardRef): void => { refs.set(syncShardPath(ref), ref) })
    const locations: SyncObjectLocation[] = []
    const targets = new Map<string, SyncObjectLocation>()
    refs.forEach((ref: SyncShardRef, path: string): void => {
      const existing = this.locations.get(path) ?? []
      existing.forEach((location: SyncObjectLocation): void => { locations.push(location) })
      if (toWrite.has(path)) {
        const target: SyncObjectLocation = { epoch: ref.epoch, hash: ref.hash, writer: this.writer,
          attempt: util.generateRandomUUID() }
        locations.push(target)
        targets.set(path, target)
      }
    })
    const packLocations = retainPublicationPackLocations(this.publicationPacks, this.manifestObjects(manifest))
    const newPackTargets = (this.plannedPacks?.packs ?? []).map((pack): SyncPublicationPackLocation => pack.location)
    const publication: SyncWriterPublication = { writer: this.writer, manifest, transaction, locations,
      newTargets: Array.from(targets.values()), packLocations: packLocations.concat(newPackTargets), newPackTargets }
    const body = JSON.stringify(publication)
    if (syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES) throw new Error('sync_manifest_too_large')
    const path = V4_PREFIX + this.publicationName(this.writer, manifest.revision, body, util.generateRandomUUID())
    this.planned = { signature, transaction, body, path, locations, prepared: false, targets }
    return body
  }

  async preparePublication(manifest: SyncManifest, objects: SyncObject[], selected: string[], guard: SyncRequestGuard,
    localBody?: (dataset: string, ref: SyncShardRef) => Promise<string | undefined>): Promise<SyncObject[]> {
    if (this.writer === '') return []
    this.planned = undefined
    this.visibleRefs.clear()
    const pending = new Set<string>(objects.map((object: SyncObject): string => syncShardPath(object.ref)))
    const checked = new Set<string>()
    const listings = new Map<string, Set<string>>()
    const checkedPacks = new Map<string, Map<string, string>>()
    const failedPackArchives = new Set<string>()
    const repairs: SyncObject[] = []
    for (const dataset of manifest.datasets.concat(manifest.alternatives ?? [])) {
      if (!selected.includes(dataset.id)) continue
      for (const ref of dataset.shards) {
        const path = syncShardPath(ref)
        if (pending.has(path) || checked.has(path)) continue
        checked.add(path)
        if (this.verifiedRefs.has(path)) continue
        if (this.legacyWriterObjects.has(path) && this.legacyObjectListing?.has(path) === true) {
          this.visibleRefs.add(path)
          continue
        }
        let visible = false
        const matchingPacks = this.publicationPacks.filter((pack: SyncPublicationPackLocation): boolean =>
          pack.members.some((member): boolean => member.epoch === ref.epoch && member.hash === ref.hash))
        if (matchingPacks.length > 0 && !this.legacyWriterObjects.has(path) &&
          (this.locations.get(path)?.length ?? 0) === 0) {
          let found: string | undefined
          for (const pack of matchingPacks) {
            const key = JSON.stringify(pack)
            let bodies = checkedPacks.get(key)
            if (bodies === undefined) {
              const noop = async (_path: string): Promise<void> => {}
              const all = Array.from(this.publicationPackRefs.values())
              const wanted = all.filter((candidate: SyncShardRef): boolean => pack.members.some((member): boolean =>
                member.epoch === candidate.epoch && member.hash === candidate.hash))
              const batch = await readPublicationPacks(this.publicationPackStore(guard, noop, noop), [pack], all, wanted, guard)
              guard()
              if (batch.incomplete) this.unavailablePublicationPacks.add(key)
              bodies = new Map<string, string>()
              for (const item of batch.objects) bodies.set(syncShardPath(item.ref), item.body)
              checkedPacks.set(key, bodies)
            }
            found = bodies.get(path)
            if (found !== undefined) break
          }
          if (found !== undefined) {
            if (!(await validSyncObject(ref, found, guard))) throw new Error('sync_shard_damaged')
            this.verifiedRefs.add(path)
            continue
          }
          let archived: string | undefined
          if (matchingPacks.some((pack: SyncPublicationPackLocation): boolean => !failedPackArchives.has(JSON.stringify(pack)))) {
            try { archived = (await this.prefetchPublicationObjects([ref], guard)).get(path) }
            catch (error) {
              guard()
              const code = (error as Error).message
              if (code !== 'sync_pack_not_found' && code !== 'sync_pack_incomplete') throw error as Error
              matchingPacks.forEach((pack: SyncPublicationPackLocation): void => { failedPackArchives.add(JSON.stringify(pack)) })
            }
          }
          guard()
          if (archived !== undefined) {
            if (!(await validSyncObject(ref, archived, guard))) throw new Error('sync_shard_damaged')
            this.verifiedRefs.add(path)
            continue
          }
          if (localBody === undefined) throw new Error('sync_pack_not_found')
          const body = await localBody(dataset.id, ref)
          guard()
          if (body === undefined || !(await validSyncObject(ref, body, guard))) throw new Error('sync_pack_not_found')
          repairs.push({ ref, body })
          continue
        }
        for (const location of this.locations.get(path) ?? []) {
          let files = listings.get(location.writer)
          if (files === undefined) {
            const dir = location.writer + '/objects/'
            const base = this.writerRootV4 + dir
            const rows = await this.listWriterPath(dir, guard, this.writerRootV4)
            guard()
            files = new Set<string>(rows.filter((row: DavResource): boolean => !row.isCollection)
              .map((row: DavResource): string => row.href.substring(base.length)))
            listings.set(location.writer, files)
          }
          if (files.has(this.objectLocationName(location))) { visible = true; break }
        }
        if (visible) { this.visibleRefs.add(path); continue }
        try { await this.readObject(ref, guard) } catch (error) {
          guard()
          const code = (error as Error).message
          if (localBody === undefined || (code !== 'sync_shard_missing' && code !== 'sync_shard_damaged' &&
            code !== 'sync_pack_not_found' && code !== 'sync_legacy_archive_unavailable')) throw error as Error
          const body = await localBody(dataset.id, ref)
          guard()
          if (body === undefined || !(await validSyncObject(ref, body, guard))) throw error as Error
          repairs.push({ ref, body })
        }
      }
    }
    // Keep independent datasets in separate packs so damaged cover data,
    // for example, cannot make reading progress unreadable as collateral.
    const byDataset = new Map<string, SyncObject[]>()
    const singles: SyncObject[] = []
    for (const object of objects.concat(repairs)) {
      const dataset = manifest.datasets.concat(manifest.alternatives ?? [], manifest.previous).find(
        (entry: SyncDatasetRef): boolean => entry.shards.some((ref: SyncShardRef): boolean =>
          syncShardPath(ref) === syncShardPath(object.ref)))
      if (dataset === undefined) { singles.push(object); continue }
      byDataset.set(dataset.id, (byDataset.get(dataset.id) ?? []).concat(object))
    }
    const combined: PublicationPackPlan = { packs: [], singles }
    for (const batch of byDataset.values()) {
      const plan = await planPublicationPacks(this.writer, batch, guard)
      guard()
      combined.packs.push(...plan.packs)
      combined.singles.push(...plan.singles)
    }
    this.plannedPacks = combined
    guard()
    this.commitBody(manifest, [], objects.concat(repairs))
    this.planned!.prepared = true
    return repairs
  }

  private publicationName(writer: string, sequence: number, body: string, attempt: string = ''): string {
    return writer + '/' + publicationSegment(sequence) + '/' + sequence.toString().padStart(16, '0') +
      '-' + syncDigest(body) + (attempt.length > 0 ? '-' + attempt : '') + '.json'
  }

  private decodePublication(name: string, body: string): SyncManifest {
    const physical = name.startsWith(V4_PREFIX) ? name.substring(V4_PREFIX.length) : name
    const parts = WRITER_PUBLICATION.exec(physical)
    if (parts === null) throw new Error('sync_invalid_commit')
    let publication: SyncWriterPublication
    try { publication = JSON.parse(body) as SyncWriterPublication } catch (_error) { throw new Error('sync_invalid_commit') }
    if (!publication || publication.writer !== parts[1]) throw new Error('sync_invalid_commit')
    const manifest = decodeSyncManifest(JSON.stringify(publication.manifest))
    if (manifest.schema !== 2 || manifest.maintenance ||
      this.publicationName(publication.writer, manifest.revision, body, parts[5] ?? '') !== physical) {
      throw new Error('sync_invalid_commit')
    }
    if (name.startsWith(V4_PREFIX)) this.recordLocations(manifest, body)
    return manifest
  }

  async retryCommit(body: string, guard: SyncRequestGuard, selected: string[], path: string = ''): Promise<SyncRemoteManifest> {
    if (path.startsWith(V4_PREFIX) && WRITER_PUBLICATION.test(path.substring(V4_PREFIX.length))) {
      const manifest = this.decodePublication(path, body)
      if (!path.startsWith(V4_PREFIX + this.writer + '/')) throw new Error('sync_invalid_writer')
      const publication = JSON.parse(body) as SyncWriterPublication
      await this.verifyNewPublicationPacks(publication, selected, guard)
      const retry = V4_PREFIX + this.publicationName(this.writer, manifest.revision, body, util.generateRandomUUID())
      this.planned = { signature: '', transaction: publication.transaction ?? '', body, path: retry,
        locations: publication.locations ?? [], prepared: true, targets: new Map<string, SyncObjectLocation>() }
      this.recoveryTargets.clear()
      for (const target of publication.newTargets ?? []) {
        this.recoveryTargets.add('object-' + target.epoch.toString() + '-' + target.hash + '.json')
      }
      this.recoveringPublication = true
      try {
        await this.writePublication(retry.substring(V4_PREFIX.length), body, manifest, guard, selected)
      } finally {
        this.recoveringPublication = false
        this.recoveryTargets.clear()
      }
      const receipt = await this.readCommit(retry, guard)
      if (receipt === undefined) throw new Error('sync_remote_result_unknown')
      return receipt
    }
    if (WRITER_PUBLICATION.test(path)) {
      const manifest = this.decodePublication(path, body)
      if (!path.startsWith(this.writer + '/')) throw new Error('sync_invalid_writer')
      // An interrupted v3 intent must still be recovered at its original path.
      await this.ensureCollection(this.writerRoot, guard)
      await this.ensureCollection(this.writerRoot + this.writer + '/', guard)
      await this.ensureCollection(this.writerRoot + this.writer + '/' + path.split('/')[1] + '/', guard)
      requireSuccess((await this.requestAt('PUT', this.writerRoot + path, guard, body)).status)
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

  private async verifyNewPublicationPacks(publication: SyncWriterPublication, selected: string[], guard: SyncRequestGuard): Promise<void> {
    const refs = publication.manifest.datasets.concat(publication.manifest.alternatives ?? [])
      .filter((dataset: SyncDatasetRef): boolean => selected.includes(dataset.id))
      .flatMap((dataset: SyncDatasetRef): SyncShardRef[] => dataset.shards)
    for (const pack of publication.newPackTargets ?? []) {
      if (!pack.members.some((member): boolean => refs.some((ref: SyncShardRef): boolean =>
        ref.epoch === member.epoch && ref.hash === member.hash))) continue
      let missing = false
      for (const attempt of pack.attempts) {
        const path = pack.writer + '/packs/pack-' + attempt + '-' + pack.hash + '.json'
        const response = await this.requestAt('GET', this.writerRootV4 + path, guard)
        guard()
        if (response.status === 404) { missing = true; break }
        requireSuccess(response.status)
        const ref: SyncShardRef = { epoch: 1, hash: pack.hash, bytes: pack.bytes, bucket: '' }
        if (!(await validSyncObject(ref, response.body, guard))) { missing = true; break }
      }
      if (missing) {
        for (const dataset of publication.manifest.datasets.concat(publication.manifest.alternatives ?? [])) {
          if (!selected.includes(dataset.id)) continue
          const wanted = dataset.shards.filter((ref: SyncShardRef): boolean => pack.members.some((member): boolean =>
            ref.epoch === member.epoch && ref.hash === member.hash))
          if (wanted.length === 0) continue
          const archive = await readCompactedSyncPublicationPacks(this.packStore(guard), pack.writer,
            dataset.id, pack.hash, wanted, guard, this.compactionReadSession)
          guard()
          for (const ref of archive.missing) {
            try { await this.packReader().read(this.packStore(guard), pack.writer, ref.epoch, ref.hash, ref.bytes, guard) }
            catch (error) {
              guard()
              const code = (error as Error).message
              // A missing listing or local witness cannot distinguish a lost
              // object from an archive that has not become visible yet.
              if (code === 'sync_pack_not_found' || code === 'sync_pack_incomplete') throw new Error('sync_pack_not_found')
              throw error as Error
            }
          }
        }
      }
    }
  }

  async verifyV4Publication(path: string, body: string, selected: string[], guard: SyncRequestGuard): Promise<void> {
    if (!path.startsWith(V4_PREFIX)) throw new Error('sync_invalid_commit')
    const manifest = this.decodePublication(path, body)
    const writer = path.substring(V4_PREFIX.length).split('/')[0]
    this.recordObjectOwners(writer, manifest)
    const publication = JSON.parse(body) as SyncWriterPublication
    await this.verifyNewPublicationPacks(publication, selected, guard)
    this.recoveryTargets.clear()
    for (const target of publication.newTargets ?? []) {
      this.recoveryTargets.add('object-' + target.epoch.toString() + '-' + target.hash + '.json')
    }
    this.recoveringPublication = true
    const checked = new Set<string>()
    try {
      for (const dataset of manifest.datasets.concat(manifest.alternatives ?? [])) {
        if (!selected.includes(dataset.id)) continue
        for (const ref of dataset.shards) {
          const name = syncShardPath(ref)
          if (checked.has(name)) continue
          checked.add(name)
          try {
            await this.readObject(ref, guard)
          } catch (error) {
            const code = (error as Error).message
            if ((code === 'sync_shard_missing' || code === 'sync_shard_damaged') && this.recoveryTargets.has(name)) {
              throw new Error('sync_replan_required')
            }
            throw error as Error
          }
        }
      }
    } finally {
      this.recoveringPublication = false
      this.recoveryTargets.clear()
    }
  }

  async readCommit(name: string, guard: SyncRequestGuard, required: boolean = false): Promise<SyncRemoteManifest | undefined> {
    if (name.startsWith(V4_PREFIX) && WRITER_PUBLICATION.test(name.substring(V4_PREFIX.length))) {
      const response = await this.requestAt('GET', this.writerRootV4 + name.substring(V4_PREFIX.length), guard)
      if (response.status === 404) return undefined
      requireSuccess(response.status)
      const manifest = copySyncManifest(this.decodePublication(name, response.body), this.space)
      this.publicationBodies.set(name, response.body)
      this.markPublishedLocations(response.body)
      const writer = name.substring(V4_PREFIX.length).split('/')[0]
      this.recordObjectOwners(writer, manifest)
      return { manifest, hash: syncDigest(JSON.stringify(manifest)), etag: '"writer-' + syncDigest(name) + '"',
        frontier: [name], journal: true, writer: true }
    }
    if (WRITER_PUBLICATION.test(name)) {
      let body: string | undefined
      const response = await this.requestAt('GET', this.writerRoot + name, guard)
      if (response.status !== 404) { requireSuccess(response.status); body = response.body }
      let physicalValid = false
      if (body !== undefined) {
        try { this.decodePublication(name, body); physicalValid = true } catch (_error) {}
      }
      if (!physicalValid && await this.hasLegacyArchive('commits', guard, true)) {
        body = await this.legacyArchiveReader().read(this.legacyArchiveStore(guard), name, guard, required)
        if (body !== undefined) {
          await this.recordArchiveSeen('commits', guard)
          LEGACY_ARCHIVE_SEEN.add(this.account + ':' + this.space + ':commits')
          guard()
        }
      }
      if (body === undefined) return undefined
      const manifest = copySyncManifest(this.decodePublication(name, body), this.space)
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
  private writerObjectsChecked: boolean = false

  private async ensureWriterRoot(guard: SyncRequestGuard): Promise<void> {
    if (this.writerRootChecked) return
    await this.ensureCollection(this.writerRootV4, guard)
    await this.ensureCollection(this.writerRootV4 + this.writer + '/', guard)
    this.writerRootChecked = true
  }

  private async ensureWriterObjects(guard: SyncRequestGuard): Promise<void> {
    await this.ensureWriterRoot(guard)
    if (this.writerObjectsChecked) return
    await this.ensureCollection(this.writerRootV4 + this.writer + '/objects/', guard)
    this.writerObjectsChecked = true
  }

  private async writePublication(path: string, body: string, manifest: SyncManifest, guard: SyncRequestGuard,
    selected: string[], beforeSend: () => void | Promise<void> = (): void => {}): Promise<void> {
    await this.ensureWriterObjects(guard)
    const segment = path.split('/')[1]
    await this.ensureCollection(this.writerRootV4 + this.writer + '/' + segment + '/', guard)
    // Reused refs retain their existing locations; selected refs must remain
    // readable, while disabled and unknown datasets stay opaque. Cross-writer
    // references mean objects cannot be collected from an owner's head alone.
    const required = new Map<string, boolean>()
    for (const dataset of manifest.datasets.concat(manifest.alternatives ?? [], manifest.previous)) {
      const active = manifest.datasets.includes(dataset) || (manifest.alternatives ?? []).includes(dataset)
      for (const ref of dataset.shards) {
        const name = syncShardPath(ref)
        const mustCopy = active && selected.includes(dataset.id)
        required.set(name, (required.get(name) ?? false) || mustCopy)
      }
    }
    for (const ref of this.manifestObjects(manifest)) {
      const name = syncShardPath(ref)
      // Unselected, unknown and fallback-only datasets stay opaque. In
      // particular their servers may be unavailable while this group works.
      if (!required.get(name)) continue
      if (this.ownObjects.has(name)) continue
      if (this.verifiedRefs.has(name)) continue
      if (!this.recoveringPublication && this.visibleRefs.has(name)) continue
      try {
        await this.readObject(ref, guard)
      } catch (error) {
        const code = (error as Error).message
        if (this.recoveringPublication && (code === 'sync_shard_missing' || code === 'sync_shard_damaged')) {
          throw new Error('sync_replan_required')
        }
        throw error as Error
      }
    }
    // Every new object was already read back by storeObject. Reused refs are
    // content-addressed and immutable; re-downloading the whole dataset here
    // made one page save issue dozens of redundant GETs on slow WebDAV servers.
    await beforeSend()
    requireSuccess((await this.requestAt('PUT', this.writerRootV4 + path, guard, body)).status)
  }

  async publish(manifest: SyncManifest, tag: string, guard: SyncRequestGuard,
    beforeSend: () => void | Promise<void> = (): void => {}, selected: string[] = []): Promise<boolean> {
    if (this.writer !== '') {
      if (this.planned === undefined || !this.planned.prepared ||
        JSON.stringify((JSON.parse(this.planned.body) as SyncWriterPublication).manifest) !== JSON.stringify(manifest)) {
        await this.preparePublication(manifest, [], selected, guard)
      }
      const prior = this.planned
      const same = prior !== undefined && JSON.stringify((JSON.parse(prior.body) as SyncWriterPublication).manifest) ===
        JSON.stringify(manifest)
      const body = same && prior !== undefined ? prior.body : this.commitBody(manifest, [])
      const path = this.planned!.path.substring(V4_PREFIX.length)
      this.decodePublication(V4_PREFIX + path, body)
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
    // Repeating reads is safe; mutating requests may have reached the server
    // even if their response was lost and therefore must never be replayed.
    for (let attempt = 0; ; attempt++) {
      guard()
      const metrics = this.guardMetrics.get(guard) ?? this.roundMetrics
      const started = metrics === undefined ? 0 : syncMetricUptime()
      let status = 0
      try {
        const response = await this.requestOnce(method, address, guard, body, tag, create, depth)
        status = response.status
        return response
      } catch (error) {
        guard()
        if (attempt >= 1 || (method !== 'GET' && method !== 'PROPFIND') ||
          !(error instanceof RetryableSyncRequestError)) throw error as Error
      } finally {
        if (metrics !== undefined) {
          try {
            const namespace = address.startsWith(this.sharedRoot) ? 'v5' : address.startsWith(this.writerRootV4) ? 'v4' : address.startsWith(this.writerRoot) ? 'v3' :
              address.startsWith(this.root) ? 'v2' : address.startsWith(this.directory + 'koma-device-sync-v1/') ? 'v1' : 'directory'
            metrics.record(method, namespace, status, syncMetricUptime() - started, attempt > 0)
          } catch (_error) {}
        }
      }
    }
  }

  private async requestOnce(method: string, address: string, guard: SyncRequestGuard, body: string = '',
    tag: string = '', create: boolean = false, depth: string = '1'): Promise<SyncHttpResponse> {
    guard()
    // Initialization may create the exact user-selected directory, never its ancestors.
    const legacyRoot = this.directory + 'koma-device-sync-v1/'
    const legacyName = address.startsWith(legacyRoot) ? address.substring(legacyRoot.length) : ''
    const legacyAllowed = (method === 'DELETE' && address === legacyRoot) ||
      (method === 'GET' && (legacyName === MANIFEST || OBJECT_NAME.test(legacyName))) ||
      ((method === 'GET' || method === 'DELETE') && /^probe-[0-9a-f-]{36}\.json$/.test(legacyName))
    if (address !== this.directory && !address.startsWith(this.sharedRoot) && !address.startsWith(this.root) && !address.startsWith(this.writerRoot) &&
      !address.startsWith(this.writerRootV4) && !legacyAllowed) {
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
    const namespace = address.startsWith(this.writerRootV4) ? 'v4' : address.startsWith(this.writerRoot) ? 'v3' :
      address.startsWith(this.root) ? 'v2' : address.startsWith(legacyRoot) ? 'v1' : 'directory'
    if (method === 'PROPFIND') {
      try {
        // Listings are not single shards: stream them without imposing the
        // shard-size limit, and decode outside the UI thread.
        const response = await requestDeviceSyncStream(address, {
          customMethod: method, maxRedirects: 0, usingCache: false, header: headers,
          extraData: body.length === 0 ? undefined : body, connectTimeout: 15000, readTimeout: 60000,
        }, guard)
        return { status: response.status, body: response.body, etag: responseTag(response.header) }
      } catch (error) {
        throw syncRequestError(error as Error, method, namespace)
      }
    }
    const request = http.createHttp()
    let response: http.HttpResponse
    try {
      response = await request.request(address, {
        customMethod: method, maxRedirects: 0, usingCache: false, header: headers,
        extraData: body.length === 0 ? undefined : body,
        connectTimeout: 15000, readTimeout: 30000, maxLimit: SYNC_MAX_OBJECT_BYTES,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
      })
    } catch (error) {
      throw syncRequestError(error as Error, method, namespace)
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
