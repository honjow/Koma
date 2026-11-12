import { taskpool, util } from '@kit.ArkTS'
import { isSyncReplica } from './DeviceSyncFacts'
import { SYNC_MAX_OBJECT_BYTES } from './DeviceSyncWire'
import { LegacyBatch, LegacyEntry, LegacyPack, legacyDirectory, checkedLegacyEntry, checkedLegacyPack, makeLegacyBatches } from './DeviceSyncLegacyArchiveCodec'

// Legacy originals live under the shared v3 root. Archives live separately
// under v4/legacy-v3; storing raw bytes keeps unknown groups and old witnesses.
export interface SyncLegacyArchiveStore {
  readOriginal(path: string): Promise<string | undefined>
  listOriginal(path: string): Promise<string[]>
  removeOriginal(path: string): Promise<void>
  readArchive(path: string): Promise<string | undefined>
  listArchive(path: string): Promise<string[]>
  ensureArchive(path: string): Promise<void>
  writeArchive(path: string, body: string): Promise<void>
  removeArchive(path: string): Promise<void>
  // Per endpoint/space, durable before issuing each non-idempotent attempt.
  loadPending(): Promise<SyncLegacyPendingAttempt[]>
  recordPending(attempt: SyncLegacyPendingAttempt): Promise<void>
  forgetPending(path: string): Promise<void>
  deferPending(path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean): Promise<void>
}

export interface SyncLegacyPendingAttempt {
  path: string
  startedAt: number
  nextCheckAt?: number
  checks?: number
  awaitingListing?: boolean
}

export interface SyncLegacyArchiveResult {
  archived: string[]
  skipped: string[]
  remaining: string[]
}

interface LegacyReadResult {
  path: string
  entry?: LegacyEntry
  error?: Error
}

interface LegacyDeleteResult {
  path: string
  error?: Error
}

interface LegacyAvailablePack {
  name: string
  body: string
  pack: LegacyPack
}

/** Reuse one session for one endpoint/space maintenance round only. */
export class SyncLegacyArchiveSession {
  private readonly indexed: Map<string, Map<string, string[]>> = new Map()
  private readonly complete: Set<string> = new Set()
  private count: number = 0
  private readonly overflow: Set<string> = new Set()
  private readonly maxEntries: number

  constructor(maxEntries: number = 8192) { this.maxEntries = maxEntries }

  names(directory: string, wanted: Set<string>): string[] | undefined {
    if (!this.complete.has(directory)) return undefined
    const names = new Set<string>()
    wanted.forEach((path: string): void => { (this.indexed.get(directory)?.get(path) ?? [])
      .forEach((name: string): void => { names.add(name) }) })
    return Array.from(names).sort()
  }

  record(directory: string, name: string, pack: LegacyPack): void {
    const rows = this.indexed.get(directory) ?? new Map<string, string[]>()
    pack.entries.forEach((entry: LegacyEntry): void => {
      const existing = rows.get(entry.path)
      if (existing === undefined) {
        if (this.count >= this.maxEntries) { this.overflow.add(directory); return }
        rows.set(entry.path, [name]); this.count++
      } else if (!existing.includes(name)) rows.set(entry.path, existing.concat(name))
    })
    this.indexed.set(directory, rows)
  }

  markComplete(directory: string): void {
    if (!this.overflow.has(directory)) this.complete.add(directory)
  }
}

const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const COMMIT = new RegExp('^(' + UUID + ')/([0-9]{14})/([0-9]{16})-([0-9a-f]{64})\\.json$')
const PACK = new RegExp('^pack-(' + UUID + ')-([0-9a-f]{64})\\.json$')
const MAX_INPUT_BYTES = 4 * SYNC_MAX_OBJECT_BYTES
const CONCURRENCY = 4
const ATTEMPT_BACKOFF_MS = 5 * 60 * 1000

async function deferLegacyAttempt(store: SyncLegacyArchiveStore, entry: SyncLegacyPendingAttempt,
  awaitingListing: boolean, guard: () => void): Promise<void> {
  const checks = Math.min((entry.checks ?? 0) + 1, 6)
  const delays: number[] = [15000, 60000, 300000, 1800000, 21600000, 86400000]
  await store.deferPending(entry.path, entry.startedAt, Date.now() + delays[checks - 1], checks, awaitingListing)
  guard()
}

@Concurrent
function checkLegacyEntryTask(path: string, body: string): LegacyEntry { return checkedLegacyEntry(path, body) }

@Concurrent
function checkLegacyPackTask(directory: string, name: string, body: string): LegacyPack {
  return checkedLegacyPack(directory, name, body)
}

@Concurrent
function makeLegacyBatchesTask(input: LegacyEntry[]): LegacyBatch[] { return makeLegacyBatches(input) }

// Latest two revisions remain physically present for ordinary discovery;
// all same-revision candidates remain, including conflicting publications.
async function protectedLegacyHeads(store: SyncLegacyArchiveStore, writer: string, guard: () => void): Promise<Set<string>> {
  const segments = (await store.listOriginal(writer + '/')).map((name: string): string => name.replace(/\/$/, ''))
    .filter((name: string): boolean => /^[0-9]{14}$/.test(name)).sort().reverse()
  guard()
  const result = new Set<string>()
  const revisions = new Set<string>()
  for (const segment of segments) {
    const names = (await store.listOriginal(writer + '/' + segment + '/')).slice().sort().reverse()
    guard()
    for (const name of names) {
      const path = writer + '/' + segment + '/' + name
      const match = COMMIT.exec(path)
      if (match === null) continue
      if (!revisions.has(match[3]) && revisions.size >= 2) continue
      revisions.add(match[3])
      result.add(path)
    }
    if (revisions.size >= 2) break
  }
  return result
}

async function reconcileLegacyAttempts(store: SyncLegacyArchiveStore, directory: string,
  guard: () => void): Promise<void> {
  const pending = (await store.loadPending()).filter((entry: SyncLegacyPendingAttempt): boolean =>
    entry.path.startsWith(directory) && PACK.test(entry.path.substring(directory.length)))
  guard()
  const unresolved = new Set<string>(pending.map((entry: SyncLegacyPendingAttempt): string => entry.path))
  let visible: string[] | undefined
  for (const entry of pending) {
    if ((entry.nextCheckAt ?? 0) > Date.now()) {
      if (entry.awaitingListing === true) throw new Error('sync_legacy_archive_unconfirmed')
      continue
    }
    const name = entry.path.substring(directory.length)
    const hash = PACK.exec(name)![2]
    const body = await store.readArchive(entry.path)
    guard()
    if (body === undefined) {
      // The old PUT may still arrive. Do not poll a permanently absent path
      // on every synchronization round.
      await deferLegacyAttempt(store, entry, false, guard)
      continue
    }
    try { await taskpool.execute(checkLegacyPackTask, directory, name, body); guard() }
    catch (_error) { guard() }
    if (visible === undefined) { visible = await store.listArchive(directory); guard() }
    if (!visible.includes(name)) {
      await deferLegacyAttempt(store, entry, true, guard)
      throw new Error('sync_legacy_archive_unconfirmed')
    }
    let verified = 0
    const others = Array.from(new Set<string>(visible)).filter((candidate: string): boolean =>
      candidate !== name && !unresolved.has(directory + candidate) && PACK.exec(candidate)?.[2] === hash)
    for (const candidate of others) {
      const copy = await store.readArchive(directory + candidate)
      guard()
      if (copy === undefined) continue
      try { await taskpool.execute(checkLegacyPackTask, directory, candidate, copy); guard(); verified++ }
      catch (_error) { guard() }
      if (verified >= 2) break
    }
    if (verified >= 2) {
      await store.removeArchive(entry.path)
      guard()
      visible = visible.filter((candidate: string): boolean => candidate !== name)
    }
    // Even a verified read or DELETE cannot prove a timed-out PUT has ended.
    // Retain its exact path so a later reappearance is checked again.
    await deferLegacyAttempt(store, entry, false, guard)
  }
}

/** Revisit timed-out attempts even after every source original has been removed. */
export async function reconcileLegacyArchivePending(store: SyncLegacyArchiveStore,
  guard: () => void = (): void => {}): Promise<void> {
  const pending = await store.loadPending()
  guard()
  const directories = new Set<string>()
  pending.forEach((entry: SyncLegacyPendingAttempt): void => {
    const split = entry.path.lastIndexOf('/')
    const directory = entry.path.substring(0, split + 1)
    if (/^legacy-v3\/(?:objects\/[0-9a-f]|commits\/[0-9a-f-]{36}\/[0-9]{14})\/$/.test(directory) &&
      PACK.test(entry.path.substring(split + 1))) directories.add(directory)
  })
  for (const directory of Array.from(directories)) await reconcileLegacyAttempts(store, directory, guard)
}

async function reserveLegacyAttempt(store: SyncLegacyArchiveStore, directory: string, hash: string,
  guard: () => void): Promise<string> {
  const pending = (await store.loadPending()).filter((entry: SyncLegacyPendingAttempt): boolean =>
    entry.path.startsWith(directory) && PACK.exec(entry.path.substring(directory.length))?.[2] === hash)
  guard()
  const newest = pending.reduce((time: number, entry: SyncLegacyPendingAttempt): number => Math.max(time, entry.startedAt), 0)
  if (pending.length >= 4 && Date.now() - newest < ATTEMPT_BACKOFF_MS) throw new Error('sync_legacy_archive_pending')
  const name = 'pack-' + util.generateRandomUUID() + '-' + hash + '.json'
  await store.recordPending({ path: directory + name, startedAt: Date.now() })
  guard()
  return name
}

// Discover once per bucket, not once per original. Only two independently
// validated physical packs make an original eligible for resumed deletion.
async function coveredLegacyEntries(store: SyncLegacyArchiveStore, directory: string, wanted: Set<string>,
  guard: () => void, session: SyncLegacyArchiveSession): Promise<Set<string>> {
  await reconcileLegacyAttempts(store, directory, guard)
  const indexed = session.names(directory, wanted)
  const names = indexed ?? Array.from(new Set<string>((await store.listArchive(directory))
    .filter((name: string): boolean => PACK.test(name)))).sort()
  guard()
  const unresolved = new Set<string>((await store.loadPending()).map((entry: SyncLegacyPendingAttempt): string => entry.path))
  guard()
  const coverage = new Map<string, number>()
  const byHash = new Map<string, LegacyAvailablePack[]>()
  let incomplete = false
  for (const name of names) {
    if (unresolved.has(directory + name)) continue
    const body = await store.readArchive(directory + name)
    guard()
    if (body === undefined) { incomplete = true; continue }
    try {
      const pack = await taskpool.execute(checkLegacyPackTask, directory, name, body) as LegacyPack
      guard()
      const hash = PACK.exec(name)![2]
      byHash.set(hash, (byHash.get(hash) ?? []).concat({ name, body, pack }))
      session.record(directory, name, pack)
      pack.entries.forEach((entry: LegacyEntry): void => {
        if (wanted.has(entry.path)) coverage.set(entry.path, (coverage.get(entry.path) ?? 0) + 1)
      })
    } catch (_error) { guard(); incomplete = true }
  }
  if (indexed === undefined && !incomplete) session.markComplete(directory)
  // If an interrupted upload left exactly one valid pack, repair that copy
  // directly rather than writing a fresh pair on every retry.
  for (const hash of Array.from(byHash.keys())) {
    const copies = byHash.get(hash) ?? []
    if (copies.length !== 1 || !copies[0].pack.entries.some((entry: LegacyEntry): boolean =>
      wanted.has(entry.path) && (coverage.get(entry.path) ?? 0) < 2)) continue
    await store.ensureArchive(directory)
    guard()
    const name = await reserveLegacyAttempt(store, directory, hash, guard)
    if (name === copies[0].name) throw new Error('sync_legacy_archive_unconfirmed')
    await store.writeArchive(directory + name, copies[0].body)
    guard()
    const read = await store.readArchive(directory + name)
    guard()
    if (read === undefined || read !== copies[0].body) throw new Error('sync_legacy_archive_unconfirmed')
    await taskpool.execute(checkLegacyPackTask, directory, name, read)
    guard()
    const visible = await store.listArchive(directory)
    guard()
    if (!visible.includes(copies[0].name) || !visible.includes(name)) throw new Error('sync_legacy_archive_unconfirmed')
    await store.forgetPending(directory + name)
    guard()
    session.record(directory, name, copies[0].pack)
    copies[0].pack.entries.forEach((entry: LegacyEntry): void => {
      if (wanted.has(entry.path)) coverage.set(entry.path, (coverage.get(entry.path) ?? 0) + 1)
    })
  }
  return new Set<string>(Array.from(coverage.keys()).filter((path: string): boolean => (coverage.get(path) ?? 0) >= 2))
}

async function readLegacyOriginal(store: SyncLegacyArchiveStore, path: string, guard: () => void): Promise<LegacyReadResult> {
  try {
    const body = await store.readOriginal(path)
    guard()
    if (body === undefined) return { path }
    try {
      const entry = await taskpool.execute(checkLegacyEntryTask, path, body) as LegacyEntry
      guard()
      return { path, entry }
    } catch (_error) {
      guard()
      return { path }
    }
  } catch (error) { return { path, error: error as Error } }
}

async function removeLegacyOriginals(store: SyncLegacyArchiveStore, paths: string[], archived: Set<string>,
  guard: () => void): Promise<void> {
  for (let offset = 0; offset < paths.length; offset += CONCURRENCY) {
    guard()
    const pending = paths.slice(offset, offset + CONCURRENCY).map(async (path: string): Promise<LegacyDeleteResult> => {
      try { await store.removeOriginal(path); guard(); return { path } }
      catch (error) { return { path, error: error as Error } }
    })
    // All in-flight requests finish before reporting failure or cancellation.
    const results = await Promise.all(pending)
    const failure = results.find((result: LegacyDeleteResult): boolean => result.error !== undefined)
    results.forEach((result: LegacyDeleteResult): void => { if (result.error === undefined) archived.add(result.path) })
    if (failure?.error !== undefined) throw failure.error
    guard()
  }
}

/** Process at most 128 names / 4 MiB; the caller schedules remaining work in the background. */
export async function archiveLegacyV3(store: SyncLegacyArchiveStore, originals: string[], guard: () => void = (): void => {},
  session: SyncLegacyArchiveSession = new SyncLegacyArchiveSession()): Promise<SyncLegacyArchiveResult> {
  const unique = Array.from(new Set<string>(originals))
  const input: LegacyEntry[] = []
  const remaining: string[] = []
  const skipped: string[] = []
  const protectedByWriter = new Map<string, Set<string>>()
  for (const path of unique.slice(0, 128)) {
    legacyDirectory(path)
    const commit = COMMIT.exec(path)
    if (commit !== null && !protectedByWriter.has(commit[1])) {
      protectedByWriter.set(commit[1], await protectedLegacyHeads(store, commit[1], guard))
    }
  }
  const candidates: string[] = []
  unique.forEach((path: string, i: number): void => {
    legacyDirectory(path)
    if (i >= 128) { remaining.push(path); return }
    const commit = COMMIT.exec(path)
    if (commit !== null && protectedByWriter.get(commit[1])?.has(path)) { skipped.push(path); return }
    candidates.push(path)
  })
  let size = 0
  for (let offset = 0; offset < candidates.length; offset += CONCURRENCY) {
    guard()
    if (size >= MAX_INPUT_BYTES) { remaining.push(...candidates.slice(offset)); break }
    const reads = candidates.slice(offset, offset + CONCURRENCY).map((path: string): Promise<LegacyReadResult> =>
      readLegacyOriginal(store, path, guard))
    const results = await Promise.all(reads)
    const failure = results.find((result: LegacyReadResult): boolean => result.error !== undefined)
    if (failure?.error !== undefined) throw failure.error
    guard()
    results.forEach((result: LegacyReadResult): void => {
      if (result.entry === undefined) { skipped.push(result.path); return }
      if (size + result.entry.bytes > MAX_INPUT_BYTES) { remaining.push(result.path); return }
      size += result.entry.bytes
      input.push(result.entry)
    })
  }
  const archived = new Set<string>()
  const wantedByDirectory = new Map<string, Set<string>>()
  input.forEach((entry: LegacyEntry): void => {
    const directory = legacyDirectory(entry.path)
    const wanted = wantedByDirectory.get(directory) ?? new Set<string>()
    wanted.add(entry.path)
    wantedByDirectory.set(directory, wanted)
  })
  for (const directory of Array.from(wantedByDirectory.keys())) {
    const covered = await coveredLegacyEntries(store, directory, wantedByDirectory.get(directory)!, guard, session)
    await removeLegacyOriginals(store, Array.from(covered), archived, guard)
  }
  const uncovered = input.filter((entry: LegacyEntry): boolean => !archived.has(entry.path))
  const batches = await taskpool.execute(makeLegacyBatchesTask, uncovered) as LegacyBatch[]
  guard()
  for (const batch of batches) {
    await store.ensureArchive(batch.directory)
    guard()
    const names: string[] = []
    for (let copy = 0; copy < 2; copy++) {
      const name = await reserveLegacyAttempt(store, batch.directory, batch.hash, guard)
      if (names.includes(name)) throw new Error('sync_legacy_archive_unconfirmed')
      names.push(name)
      await store.writeArchive(batch.directory + name, batch.body)
      guard()
      const read = await store.readArchive(batch.directory + name)
      guard()
      if (read === undefined || read !== batch.body) throw new Error('sync_legacy_archive_unconfirmed')
      await taskpool.execute(checkLegacyPackTask, batch.directory, name, read)
      guard()
      const visibleCopy = await store.listArchive(batch.directory)
      guard()
      if (!visibleCopy.includes(name)) throw new Error('sync_legacy_archive_unconfirmed')
      await store.forgetPending(batch.directory + name)
      guard()
    }
    const visible = await store.listArchive(batch.directory)
    guard()
    if (!names.every((name: string): boolean => visible.includes(name))) throw new Error('sync_legacy_archive_unconfirmed')
    for (const name of names) {
      await store.forgetPending(batch.directory + name)
      guard()
      session.record(batch.directory, name, { format: 'KOMA_V3_ARCHIVE', version: 1, entries: batch.entries })
    }
    const toRemove: string[] = []
    for (const entry of batch.entries) {
      const commit = COMMIT.exec(entry.path)
      if (commit !== null && protectedByWriter.get(commit[1])?.has(entry.path)) { skipped.push(entry.path); continue }
      toRemove.push(entry.path)
    }
    await removeLegacyOriginals(store, toRemove, archived, guard)
  }
  input.forEach((entry: LegacyEntry): void => {
    if (!archived.has(entry.path) && !skipped.includes(entry.path)) skipped.push(entry.path)
  })
  return { archived: Array.from(archived), skipped, remaining }
}

async function readLegacyBucket(store: SyncLegacyArchiveStore, directory: string,
  guard: () => void, requiredPath: string = ''): Promise<LegacyEntry[]> {
  const names = Array.from(new Set<string>((await store.listArchive(directory))
    .filter((name: string): boolean => PACK.test(name)))).sort()
  guard()
  const groups = new Map<string, string[]>()
  names.forEach((name: string): void => {
    const hash = PACK.exec(name)![2]
    groups.set(hash, (groups.get(hash) ?? []).concat(name))
  })
  const entries = new Map<string, LegacyEntry>()
  let incomplete = false
  for (const alternatives of Array.from(groups.values())) {
    let complete = false
    for (const name of alternatives) {
      const body = await store.readArchive(directory + name)
      guard()
      if (body === undefined) continue
      try {
        const pack = await taskpool.execute(checkLegacyPackTask, directory, name, body) as LegacyPack
        pack.entries.forEach((entry: LegacyEntry): void => { entries.set(entry.path, entry) })
        complete = true
        break
      } catch (_error) { guard() }
    }
    if (!complete) incomplete = true
    if (requiredPath.length > 0 && entries.has(requiredPath)) return Array.from(entries.values())
  }
  if (incomplete && (requiredPath.length === 0 || !entries.has(requiredPath))) throw new Error('sync_legacy_archive_incomplete')
  return Array.from(entries.values())
}

/** Missing is not proof of deletion. A known witness must fail closed and re-list later. */
export async function readArchivedLegacyV3(store: SyncLegacyArchiveStore, originalPath: string,
  guard: () => void = (): void => {}, required: boolean = false): Promise<string | undefined> {
  const directory = legacyDirectory(originalPath)
  const entry = (await readLegacyBucket(store, directory, guard, originalPath)).find((item: LegacyEntry): boolean => item.path === originalPath)
  if (entry === undefined && required) throw new Error('sync_legacy_archive_unavailable')
  return entry?.body
}

/** Include archived names when searching earlier snapshots, not just physical v3 files. */
export async function listArchivedLegacyV3Commits(store: SyncLegacyArchiveStore, writer: string, segment: string,
  guard: () => void = (): void => {}): Promise<string[]> {
  if (!isSyncReplica(writer) || !/^[0-9]{14}$/.test(segment)) throw new Error('sync_legacy_archive_invalid')
  const directory = 'legacy-v3/commits/' + writer + '/' + segment + '/'
  return (await readLegacyBucket(store, directory, guard)).map((entry: LegacyEntry): string => entry.path).sort().reverse()
}

interface CachedLegacyPack {
  pack: LegacyPack
  bytes: number
}

export interface SyncLegacyManyEntry {
  path: string
  body: string
}

export interface SyncLegacyManyResult {
  entries: SyncLegacyManyEntry[]
  // A missing entry is not proof of remote deletion: try the ordinary paths.
  missing: string[]
  incomplete: boolean
}

interface SyncLegacyBucketResult {
  entries: SyncLegacyManyEntry[]
  incomplete: boolean
  error?: Error
}

/** Scoped to one sync round and one endpoint/space. Never persist negative results. */
export class SyncLegacyReadSession {
  readonly completed: Set<string> = new Set()
  readonly index: Map<string, string[]> = new Map()
  readonly loading: Map<string, Promise<SyncLegacyBucketResult>> = new Map()
}

/** One instance per endpoint/space. Only verified packs and positive indexes are cached. */
export class SyncLegacyArchiveReader {
  private readonly index: Map<string, string[]> = new Map()
  private readonly cache: Map<string, CachedLegacyPack> = new Map()
  private readonly loading: Map<string, Map<() => void, Promise<void>>> = new Map()
  private bytes: number = 0
  private readonly maxBytes: number
  private readonly maxEntries: number

  constructor(maxBytes: number = 8 * SYNC_MAX_OBJECT_BYTES, maxEntries: number = 8192) {
    this.maxBytes = maxBytes
    this.maxEntries = maxEntries
  }

  private remember(path: string, packPath: string): void {
    const names = this.index.get(path) ?? []
    this.index.delete(path)
    this.index.set(path, names.includes(packPath) ? names : names.concat(packPath))
    while (this.index.size > this.maxEntries) this.index.delete(this.index.keys().next().value as string)
  }

  private cachePack(path: string, pack: LegacyPack, bytes: number): void {
    const previous = this.cache.get(path)
    if (previous !== undefined) { this.bytes -= previous.bytes; this.cache.delete(path) }
    if (bytes > this.maxBytes) return
    while (this.bytes + bytes > this.maxBytes && this.cache.size > 0) {
      const first = this.cache.keys().next().value as string
      this.bytes -= this.cache.get(first)!.bytes
      this.cache.delete(first)
    }
    this.cache.set(path, { pack, bytes })
    this.bytes += bytes
  }

  private async pack(store: SyncLegacyArchiveStore, directory: string, name: string,
    guard: () => void): Promise<LegacyPack | undefined> {
    const path = directory + name
    guard()
    const cached = this.cache.get(path)
    if (cached !== undefined) {
      this.cache.delete(path)
      this.cache.set(path, cached)
      return cached.pack
    }
    const body = await store.readArchive(path)
    guard()
    if (body === undefined) return undefined
    const pack = await taskpool.execute(checkLegacyPackTask, directory, name, body) as LegacyPack
    guard()
    // JS strings occupy roughly two bytes per code unit; avoid re-encoding an
    // already verified pack on the caller thread merely to size the LRU.
    this.cachePack(path, pack, body.length * 2)
    return pack
  }

  private async scan(store: SyncLegacyArchiveStore, directory: string, guard: () => void): Promise<void> {
    const names = Array.from(new Set<string>((await store.listArchive(directory))
      .filter((name: string): boolean => PACK.test(name)))).sort()
    guard()
    const groups = new Map<string, string[]>()
    names.forEach((name: string): void => {
      const hash = PACK.exec(name)![2]
      groups.set(hash, (groups.get(hash) ?? []).concat(name))
    })
    for (const alternatives of Array.from(groups.values())) {
      let verified: LegacyPack | undefined
      for (const name of alternatives) {
        try {
          verified = await this.pack(store, directory, name, guard)
          if (verified !== undefined) break
        } catch (error) {
          guard()
          if ((error as Error).message !== 'sync_legacy_archive_damaged') throw error as Error
        }
      }
      if (verified !== undefined) {
        verified.entries.forEach((entry: LegacyEntry): void => {
          alternatives.forEach((name: string): void => this.remember(entry.path, directory + name))
        })
      }
    }
  }

  private async discover(store: SyncLegacyArchiveStore, directory: string, guard: () => void): Promise<void> {
    const guards = this.loading.get(directory) ?? new Map<() => void, Promise<void>>()
    this.loading.set(directory, guards)
    let work = guards.get(guard)
    if (work === undefined) {
      work = this.scan(store, directory, guard)
      guards.set(guard, work)
    }
    try { await work } finally {
      if (guards.get(guard) === work) guards.delete(guard)
      if (guards.size === 0) this.loading.delete(directory)
    }
  }

  private async readManyBucket(store: SyncLegacyArchiveStore, directory: string, wanted: Set<string>,
    guard: () => void, session?: SyncLegacyReadSession): Promise<SyncLegacyBucketResult> {
    if (session === undefined || session.completed.has(directory)) {
      return this.readManyBucketInner(store, directory, wanted, guard, session)
    }
    const previous = session.loading.get(directory)
    if (previous !== undefined) {
      const result = await previous
      if (result.error !== undefined) return result
      try { guard() } catch (error) { return { entries: [], incomplete: true, error: error as Error } }
      return this.readManyBucket(store, directory, wanted, guard, session)
    }
    const work = this.readManyBucketInner(store, directory, wanted, guard, session)
    session.loading.set(directory, work)
    try { return await work } finally {
      if (session.loading.get(directory) === work) session.loading.delete(directory)
    }
  }

  private async readManyBucketInner(store: SyncLegacyArchiveStore, directory: string, wanted: Set<string>,
    guard: () => void, session?: SyncLegacyReadSession): Promise<SyncLegacyBucketResult> {
    try {
      if (session?.completed.has(directory)) {
        const found = new Map<string, string>()
        let incomplete = false
        const used = new Map<string, LegacyPack>()
        for (const path of Array.from(wanted)) {
          const names = session.index.get(path) ?? []
          let entry: LegacyEntry | undefined
          for (const name of names) {
            try {
              let pack = used.get(name)
              if (pack === undefined) pack = await this.pack(store, directory, name, guard)
              if (pack === undefined) continue
              used.set(name, pack)
              entry = pack.entries.find((item: LegacyEntry): boolean => item.path === path)
              if (entry !== undefined) break
            } catch (error) {
              guard()
              if ((error as Error).message !== 'sync_legacy_archive_damaged') throw error as Error
            }
          }
          if (entry !== undefined) found.set(path, entry.body)
          else if (names.length > 0) incomplete = true
        }
        if (!incomplete) return { entries: Array.from(found.keys()).map((path: string): SyncLegacyManyEntry =>
          ({ path, body: found.get(path)! })), incomplete: false }
        session.completed.delete(directory)
      }
      const names = Array.from(new Set<string>((await store.listArchive(directory))
        .filter((name: string): boolean => PACK.test(name)))).sort()
      guard()
      const groups = new Map<string, string[]>()
      names.forEach((name: string): void => {
        const hash = PACK.exec(name)![2]
        groups.set(hash, (groups.get(hash) ?? []).concat(name))
      })
      const found = new Map<string, string>()
      let incomplete = false
      for (const alternatives of Array.from(groups.values())) {
        let verified: LegacyPack | undefined
        for (const name of alternatives) {
          try {
            verified = await this.pack(store, directory, name, guard)
            if (verified !== undefined) break
          } catch (error) {
            guard()
            if ((error as Error).message !== 'sync_legacy_archive_damaged') throw error as Error
          }
        }
        if (verified === undefined) { incomplete = true; continue }
        verified.entries.forEach((entry: LegacyEntry): void => {
          if (wanted.has(entry.path)) found.set(entry.path, entry.body)
          if (session !== undefined) session.index.set(entry.path, alternatives)
        })
        if (session === undefined && found.size === wanted.size) break
      }
      guard()
      if (session !== undefined && !incomplete) session.completed.add(directory)
      return { entries: Array.from(found.keys()).map((path: string): SyncLegacyManyEntry =>
        ({ path, body: found.get(path)! })), incomplete }
    } catch (error) { return { entries: [], incomplete: true, error: error as Error } }
  }

  /** One round's positive matches only; callers validate dataset/bucket and try ordinary paths for misses. */
  async readMany(store: SyncLegacyArchiveStore, originals: string[], guard: () => void = (): void => {},
    session?: SyncLegacyReadSession): Promise<SyncLegacyManyResult> {
    guard()
    const unique = Array.from(new Set<string>(originals))
    const buckets = new Map<string, Set<string>>()
    unique.forEach((path: string): void => {
      if (!/^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/.test(path)) throw new Error('sync_legacy_archive_invalid')
      const directory = legacyDirectory(path)
      const wanted = buckets.get(directory) ?? new Set<string>()
      wanted.add(path)
      buckets.set(directory, wanted)
    })
    const directories = Array.from(buckets.keys()).sort()
    const entries: SyncLegacyManyEntry[] = []
    let incomplete = false
    for (let start = 0; start < directories.length; start += CONCURRENCY) {
      const pending = directories.slice(start, start + CONCURRENCY).map((directory: string): Promise<SyncLegacyBucketResult> =>
        this.readManyBucket(store, directory, buckets.get(directory)!, guard, session))
      const results = await Promise.all(pending)
      guard()
      const failure = results.find((result: SyncLegacyBucketResult): boolean => result.error !== undefined)
      if (failure?.error !== undefined) throw failure.error
      results.forEach((result: SyncLegacyBucketResult): void => {
        entries.push(...result.entries)
        incomplete = incomplete || result.incomplete
      })
    }
    const found = new Set<string>(entries.map((entry: SyncLegacyManyEntry): string => entry.path))
    return { entries, missing: unique.filter((path: string): boolean => !found.has(path)), incomplete }
  }

  async read(store: SyncLegacyArchiveStore, originalPath: string, guard: () => void = (): void => {},
    required: boolean = false): Promise<string | undefined> {
    guard()
    const directory = legacyDirectory(originalPath)
    const indexed = async (): Promise<string | undefined> => {
      for (const path of this.index.get(originalPath) ?? []) {
        if (!path.startsWith(directory)) continue
        try {
          const pack = await this.pack(store, directory, path.substring(directory.length), guard)
          const entry = pack?.entries.find((item: LegacyEntry): boolean => item.path === originalPath)
          if (entry !== undefined) return entry.body
        } catch (error) {
          guard()
          if ((error as Error).message !== 'sync_legacy_archive_damaged') throw error as Error
        }
      }
      return undefined
    }
    let found = await indexed()
    if (found !== undefined) { guard(); return found }
    await this.discover(store, directory, guard)
    guard()
    found = await indexed()
    if (found !== undefined) { guard(); return found }
    // The bounded index may have evicted this path while scanning a large
    // bucket. A targeted pass can still return it without caching all entries.
    return readArchivedLegacyV3(store, originalPath, guard, required)
  }
}
