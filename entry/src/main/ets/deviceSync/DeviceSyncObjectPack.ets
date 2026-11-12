import { taskpool, util } from '@kit.ArkTS'
import { isSyncReplica } from './DeviceSyncFacts'
import { syncDigest, syncUtf8, SYNC_MAX_OBJECT_BYTES } from './DeviceSyncWire'

// Prototype only: enable retirement after the pack reader has shipped. Older
// clients cannot read packed objects; writer-side listing checks cannot prove
// simultaneous visibility on an eventually consistent server.
export interface SyncPackStore {
  read(path: string): Promise<string | undefined>
  write(path: string, body: string): Promise<void>
  list(path: string): Promise<string[]>
  remove(path: string): Promise<void>
  loadPending(): Promise<SyncPackPendingAttempt[]>
  recordPending(attempt: SyncPackPendingAttempt): Promise<void>
  forgetPending(path: string): Promise<void>
  deferPending(path: string, startedAt: number, nextCheckAt: number, checks: number, awaitingListing: boolean): Promise<void>
}

export interface SyncPackPendingAttempt {
  path: string
  startedAt: number
  checks?: number
  nextCheckAt?: number
  awaitingListing?: boolean
}

export interface SyncPackEntry {
  epoch: number
  hash: string
  bytes: number
  body: string
}

interface SyncPack {
  version: number
  writer: string
  entries: SyncPackEntry[]
}

interface SyncPackSource {
  name: string
  epoch: number
  hash: string
  body: string
}

interface SyncPackBatch {
  names: string[]
  body: string
  hash: string
  entries: SyncPackEntry[]
}

export interface SyncPackArchiveResult {
  packs: string[]
  skipped: string[]
  nextIndex: number
  discoveryPending: boolean
}

interface SyncPackBuildResult {
  batches: SyncPackBatch[]
  skipped: string[]
}

interface SyncPackIndexed {
  names: string[]
  entries: SyncPackIndexEntry[]
}

interface SyncPackIndexEntry {
  epoch: number
  hash: string
}

export class SyncPackArchiveIndex {
  initialized: boolean = false
  listed: boolean = false
  nextPack: number = 0
  names: string[] = []
  packs: Map<string, SyncPackIndexed> = new Map<string, SyncPackIndexed>()
}

@Concurrent
function validPackSources(sources: SyncPackSource[]): SyncPackSource[] {
  return sources.filter((source: SyncPackSource): boolean => {
    const bytes = syncUtf8(source.body).byteLength
    return bytes > 0 && bytes <= SYNC_MAX_OBJECT_BYTES && syncDigest(source.body) === source.hash
  })
}

const OBJECT = /^object-([1-9][0-9]*)-([0-9a-f]{64})(?:-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}))?\.json$/
const PACK = /^pack-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-([0-9a-f]{64})\.json$/

async function reconcilePackPending(store: SyncPackStore, writer: string, guard: () => void): Promise<void> {
  const dir = writer + '/packs/'
  const all = await store.loadPending()
  const pending = all.filter((entry: SyncPackPendingAttempt): boolean =>
    entry.path.startsWith(dir) && PACK.test(entry.path.substring(dir.length)))
  guard()
  let visible: string[] | undefined
  for (const entry of pending) {
    if ((entry.nextCheckAt ?? 0) > Date.now()) {
      if (entry.awaitingListing === true) throw new Error('sync_pack_unconfirmed')
      continue
    }
    const name = entry.path.substring(dir.length)
    const hash = PACK.exec(name)![2]
    const body = await store.read(entry.path)
    guard()
    if (body === undefined) {
      const checks = (entry.checks ?? 0) + 1
      const delays = [15000, 60000, 300000, 1800000, 21600000, 86400000]
      await store.deferPending(entry.path, entry.startedAt, Date.now() + delays[Math.min(checks - 1, delays.length - 1)], checks, false)
      guard()
      continue // An old timed-out request can still arrive.
    }
    try { await taskpool.execute(decodePack, writer, name, body); guard() } catch (_error) { guard() }
    if (visible === undefined) { visible = await store.list(dir); guard() }
    if (!visible.includes(name)) {
      const checks = (entry.checks ?? 0) + 1
      const delays = [15000, 60000, 300000, 1800000, 21600000, 86400000]
      await store.deferPending(entry.path, entry.startedAt, Date.now() + delays[Math.min(checks - 1, delays.length - 1)], checks, true)
      guard()
      throw new Error('sync_pack_unconfirmed')
    }
    let copies = 0
    for (const candidate of Array.from(new Set<string>(visible))) {
      if (candidate === name || PACK.exec(candidate)?.[2] !== hash) continue
      if (all.some((item: SyncPackPendingAttempt): boolean => item.path === dir + candidate)) continue
      const other = await store.read(dir + candidate)
      guard()
      if (other === undefined) continue
      try { await taskpool.execute(decodePack, writer, candidate, other); guard(); copies++ } catch (_error) { guard() }
      if (copies >= 2) break
    }
    if (copies >= 2) {
      try {
        await store.remove(entry.path)
        guard()
        visible = visible.filter((candidate: string): boolean => candidate !== name)
      } catch (error) {
        guard()
        // A publication can still name this exact attempt. Keep it and
        // continue reconciling the other pending attempts in this batch.
        if ((error as Error).message !== 'sync_pack_in_use') throw error as Error
      }
    }
    // A timed-out request may arrive again even after DELETE. Keep its marker;
    // only a PUT that actually returned successfully can be forgotten.
    const checks = (entry.checks ?? 0) + 1
    const delays = [15000, 60000, 300000, 1800000, 21600000, 86400000]
    await store.deferPending(entry.path, entry.startedAt, Date.now() + delays[Math.min(checks - 1, delays.length - 1)], checks, false)
    guard()
  }
}

export async function reconcileSyncPackPending(store: SyncPackStore, writer: string, guard: () => void): Promise<void> {
  if (!isSyncReplica(writer)) throw new Error('sync_pack_invalid')
  await reconcilePackPending(store, writer, guard)
}

async function reservePackAttempt(store: SyncPackStore, writer: string, hash: string, guard: () => void,
  proposed: string = ''): Promise<string> {
  const dir = writer + '/packs/'
  const pending = (await store.loadPending()).filter((entry: SyncPackPendingAttempt): boolean =>
    entry.path.startsWith(dir) && PACK.exec(entry.path.substring(dir.length))?.[2] === hash)
  guard()
  const newest = pending.reduce((time: number, entry: SyncPackPendingAttempt): number => Math.max(time, entry.startedAt), 0)
  if (pending.length >= 4 && Date.now() - newest < 5 * 60 * 1000) throw new Error('sync_pack_pending')
  const name = 'pack-' + (proposed.length > 0 ? proposed : util.generateRandomUUID()) + '-' + hash + '.json'
  if (pending.some((entry: SyncPackPendingAttempt): boolean => entry.path === dir + name)) throw new Error('sync_pack_invalid')
  await store.recordPending({ path: dir + name, startedAt: Date.now() })
  guard()
  return name
}

@Concurrent
function decodePack(writer: string, name: string, body: string): SyncPack {
  const match = /^pack-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-([0-9a-f]{64})\.json$/.exec(name)
  if (!isSyncReplica(writer) || match === null || syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES ||
    syncDigest(body) !== match[2]) throw new Error('sync_pack_damaged')
  let pack: SyncPack
  try { pack = JSON.parse(body) as SyncPack } catch (_error) { throw new Error('sync_pack_damaged') }
  if (!pack || pack.version !== 1 || pack.writer !== writer || !Array.isArray(pack.entries) || pack.entries.length === 0) {
    throw new Error('sync_pack_damaged')
  }
  const seen = new Set<string>()
  for (const entry of pack.entries) {
    if (!entry || !Number.isSafeInteger(entry.epoch) || entry.epoch < 1 ||
      !/^[0-9a-f]{64}$/.test(entry.hash) || typeof entry.body !== 'string' ||
      !Number.isSafeInteger(entry.bytes) || entry.bytes < 1 || entry.bytes > SYNC_MAX_OBJECT_BYTES ||
      syncUtf8(entry.body).byteLength !== entry.bytes || syncDigest(entry.body) !== entry.hash) {
      throw new Error('sync_pack_damaged')
    }
    const key = entry.epoch + ':' + entry.hash
    if (seen.has(key)) throw new Error('sync_pack_damaged')
    seen.add(key)
  }
  return pack
}

@Concurrent
function buildPackBatches(writer: string, sources: SyncPackSource[]): SyncPackBuildResult {
  const batches: SyncPackBatch[] = []
  const skipped: string[] = []
  let entries: SyncPackEntry[] = []
  let names: string[] = []
  let keys = new Set<string>()
  let size = syncUtf8(JSON.stringify({ version: 1, writer, entries: [] })).byteLength
  const baseSize = size
  const flush = (): void => {
    if (names.length < 3) {
      skipped.push(...names)
    } else {
      const body = JSON.stringify({ version: 1, writer, entries })
      batches.push({ names, body, hash: syncDigest(body), entries })
    }
    entries = []
    names = []
    keys = new Set<string>()
    size = baseSize
  }
  for (const source of sources) {
    const bytes = syncUtf8(source.body).byteLength
    if (bytes < 1 || bytes > SYNC_MAX_OBJECT_BYTES || syncDigest(source.body) !== source.hash) {
      skipped.push(source.name)
      continue
    }
    const key = source.epoch + ':' + source.hash
    const entry: SyncPackEntry = { epoch: source.epoch, hash: source.hash, bytes, body: source.body }
    const entrySize = keys.has(key) ? 0 : syncUtf8(JSON.stringify(entry)).byteLength + (entries.length > 0 ? 1 : 0)
    if (baseSize + entrySize > SYNC_MAX_OBJECT_BYTES) { skipped.push(source.name); continue }
    if (size + entrySize > SYNC_MAX_OBJECT_BYTES) flush()
    if (!keys.has(key)) {
      size += syncUtf8(JSON.stringify(entry)).byteLength + (entries.length > 0 ? 1 : 0)
      entries.push(entry)
      keys.add(key)
    }
    names.push(source.name)
  }
  flush()
  return { batches, skipped }
}

// Inputs are bare names in this writer's own objects directory, never remote
// paths supplied by a listing. Every attempt gets a fresh caller-generated UUID.
export async function archiveSyncObjects(store: SyncPackStore, writer: string, names: string[],
  attempt: string, guard: () => void = (): void => {}, startIndex: number = 0,
  archiveIndex: SyncPackArchiveIndex = new SyncPackArchiveIndex(), maxItems: number = 128): Promise<SyncPackArchiveResult> {
  guard()
  if (!isSyncReplica(writer) || !isSyncReplica(attempt) || names.length === 0) throw new Error('sync_pack_invalid')
  const objectDir = writer + '/objects/'
  const packDir = writer + '/packs/'
  await reconcilePackPending(store, writer, guard)
  guard()
  const unresolved = new Set<string>((await store.loadPending()).map((entry: SyncPackPendingAttempt): string => entry.path))
  guard()
  if (!archiveIndex.initialized) {
    if (!archiveIndex.listed) {
      archiveIndex.names = Array.from(new Set<string>(await store.list(packDir)))
      guard()
      archiveIndex.listed = true
    }
    const end = Math.min(archiveIndex.names.length, archiveIndex.nextPack + 8)
    for (; archiveIndex.nextPack < end; archiveIndex.nextPack++) {
      const name = archiveIndex.names[archiveIndex.nextPack]
      if (unresolved.has(packDir + name)) continue
      const match = PACK.exec(name)
      if (match === null) continue
      const raw = await store.read(packDir + name)
      guard()
      if (raw === undefined) continue
      let value: SyncPack
      try { value = await taskpool.execute(decodePack, writer, name, raw) as SyncPack }
      catch (_error) { guard(); continue }
      guard()
      const group = archiveIndex.packs.get(match[2])
      if (group === undefined) archiveIndex.packs.set(match[2], { names: [name],
        entries: value.entries.map((entry: SyncPackEntry): SyncPackIndexEntry => ({ epoch: entry.epoch, hash: entry.hash })) })
      else group.names.push(name)
    }
    if (archiveIndex.nextPack < archiveIndex.names.length) {
      return { packs: [], skipped: [], nextIndex: startIndex, discoveryPending: true }
    }
    archiveIndex.initialized = true
  }
  const sources: SyncPackSource[] = []
  const sourceNames = new Set<string>()
  let chars = 0
  const deferred: string[] = []
  let nextIndex = Math.max(0, Math.min(startIndex, names.length))
  let checked = 0
  for (; nextIndex < names.length && checked < Math.max(1, Math.min(maxItems, 128)); nextIndex++) {
    const name = names[nextIndex]
    checked++
    if (chars >= 4 * SYNC_MAX_OBJECT_BYTES) break
    const match = OBJECT.exec(name)
    if (match === null || !Number.isSafeInteger(Number(match[1]))) throw new Error('sync_pack_invalid')
    if (sourceNames.has(name)) continue
    sourceNames.add(name)
    const body = await store.read(objectDir + name)
    guard()
    if (body === undefined) { deferred.push(name); continue }
    // Bound each background job's input. Unprocessed entries are left intact.
    if (body.length > SYNC_MAX_OBJECT_BYTES || chars + body.length > 4 * SYNC_MAX_OBJECT_BYTES) {
      deferred.push(name)
      continue
    }
    chars += body.length
    sources.push({ name, epoch: Number(match[1]), hash: match[2], body })
  }
  const valid = await taskpool.execute(validPackSources, sources) as SyncPackSource[]
  guard()
  const validNames = new Set<string>(valid.map((source: SyncPackSource): string => source.name))
  const invalid = sources.filter((source: SyncPackSource): boolean => !validNames.has(source.name))
    .map((source: SyncPackSource): string => source.name)
  const packed = new Set<string>()
  const packs: string[] = []
  for (const pair of archiveIndex.packs.entries()) {
    const hash = pair[0]
    const indexed = pair[1]
    const covered = valid.filter((source: SyncPackSource): boolean => !packed.has(source.name) &&
      indexed.entries.some((entry: SyncPackIndexEntry): boolean => entry.epoch === source.epoch && entry.hash === source.hash))
    if (covered.length === 0) continue
    const copies: string[] = []
    let content = ''
    for (const name of indexed.names) {
      const raw = await store.read(packDir + name)
      guard()
      if (raw === undefined) continue
      try { await taskpool.execute(decodePack, writer, name, raw) } catch (_error) { guard(); continue }
      guard()
      content = raw
      copies.push(name)
      if (copies.length === 2) break
    }
    if (copies.length === 0) continue
    let reserved = ''
    if (copies.length === 1) {
      const name = await reservePackAttempt(store, writer, hash, guard)
      if (copies.includes(name)) throw new Error('sync_pack_invalid')
      reserved = name
      await store.write(packDir + name, content)
      guard()
      const raw = await store.read(packDir + name)
      guard()
      if (raw !== content) throw new Error('sync_pack_unconfirmed')
      await taskpool.execute(decodePack, writer, name, raw)
      guard()
      copies.push(name)
      indexed.names.push(name)
    }
    const visible = await store.list(packDir)
    guard()
    if (!copies.every((name: string): boolean => visible.includes(name))) throw new Error('sync_pack_unconfirmed')
    if (reserved.length > 0) { await store.forgetPending(packDir + reserved); guard() }
    for (const source of covered) {
      await store.remove(objectDir + source.name)
      guard()
      packed.add(source.name)
    }
    copies.forEach((name: string): void => { packs.push(packDir + name) })
  }
  const built = await taskpool.execute(buildPackBatches, writer,
    valid.filter((source: SyncPackSource): boolean => !packed.has(source.name))) as SyncPackBuildResult
  guard()
  for (let index = 0; index < built.batches.length; index++) {
    const batch = built.batches[index]
    const copies: string[] = []
    for (let copy = 0; copy < 2; copy++) {
      const proposed = index === 0 && copy === 0 ? attempt : ''
      const packName = await reservePackAttempt(store, writer, batch.hash, guard, proposed)
      if (copies.includes(packName)) throw new Error('sync_pack_invalid')
      const path = packDir + packName
      await store.write(path, batch.body)
      guard()
      const direct = await store.read(path)
      guard()
      if (direct === undefined || direct !== batch.body) throw new Error('sync_pack_unconfirmed')
      await taskpool.execute(decodePack, writer, packName, direct)
      guard()
      const confirmation = await store.list(packDir)
      guard()
      if (!confirmation.includes(packName)) throw new Error('sync_pack_unconfirmed')
      await store.forgetPending(path)
      guard()
      copies.push(packName)
    }
    const visible = await store.list(packDir)
    guard()
    if (!copies.every((name: string): boolean => visible.includes(name))) throw new Error('sync_pack_unconfirmed')
    for (const name of batch.names) { await store.remove(objectDir + name); guard() }
    archiveIndex.packs.set(batch.hash, { names: copies,
      entries: batch.entries.map((entry: SyncPackEntry): SyncPackIndexEntry => ({ epoch: entry.epoch, hash: entry.hash })) })
    copies.forEach((name: string): void => { packs.push(packDir + name) })
  }
  return { packs, skipped: built.skipped.concat(deferred, invalid), nextIndex, discoveryPending: false }
}

export async function readSyncPackObject(store: SyncPackStore, writer: string, epoch: number,
  hash: string, bytes: number, guard: () => void = (): void => {}): Promise<string | undefined> {
  guard()
  if (!isSyncReplica(writer) || !Number.isSafeInteger(epoch) || epoch < 1 || !/^[0-9a-f]{64}$/.test(hash) ||
    !Number.isSafeInteger(bytes) || bytes < 1 || bytes > SYNC_MAX_OBJECT_BYTES) throw new Error('sync_pack_invalid')
  const dir = writer + '/packs/'
  let damaged = false
  let incomplete = false
  const names = await store.list(dir)
  guard()
  for (const name of names) {
    if (!PACK.test(name)) continue
    const body = await store.read(dir + name)
    guard()
    if (body === undefined) { incomplete = true; continue }
    let pack: SyncPack
    try {
      pack = await taskpool.execute(decodePack, writer, name, body) as SyncPack
    } catch (_error) {
      guard()
      // A partial or damaged pack must not hide another valid copy.
      damaged = true
      continue
    }
    guard()
    const entry = pack.entries.find((item: SyncPackEntry): boolean => item.epoch === epoch && item.hash === hash)
    if (entry !== undefined && entry.bytes === bytes) return entry.body
  }
  if (incomplete) throw new Error('sync_pack_incomplete')
  if (damaged) throw new Error('sync_pack_damaged')
  // A listing can temporarily omit a newly written pack. Missing is not proof
  // that the object was never archived, so the caller must retry discovery.
  throw new Error('sync_pack_not_found')
}

/** Verified immutable packs are shared between concurrent reads for one endpoint. */
export class SyncPackReader {
  private readonly cache: Map<string, SyncPack> = new Map<string, SyncPack>()
  private readonly sizes: Map<string, number> = new Map<string, number>()
  private readonly loading: Map<string, Map<() => void, Promise<void>>> = new Map<string, Map<() => void, Promise<void>>>()
  private bytes: number = 0

  private cached(writer: string, epoch: number, hash: string, bytes: number): string | undefined {
    for (const pack of this.cache.values()) {
      if (pack.writer !== writer) continue
      const item = pack.entries.find((entry: SyncPackEntry): boolean => entry.epoch === epoch &&
        entry.hash === hash && entry.bytes === bytes)
      if (item !== undefined) return item.body
    }
    return undefined
  }

  private async discover(store: SyncPackStore, writer: string, guard: () => void): Promise<void> {
    const dir = writer + '/packs/'
    const names = await store.list(dir)
    guard()
    let invalid = false
    const checked = new Set<string>()
    for (const name of names) {
      const match = PACK.exec(name)
      if (match === null || checked.has(match[2])) continue
      const key = writer + '/' + name
      if (this.cache.has(key)) { checked.add(match[2]); continue }
      const body = await store.read(dir + name)
      guard()
      if (body === undefined) { invalid = true; continue }
      let pack: SyncPack
      try { pack = await taskpool.execute(decodePack, writer, name, body) as SyncPack }
      catch (_error) { guard(); invalid = true; continue }
      guard()
      checked.add(match[2])
      const size = body.length * 2
      while (this.bytes + size > 8 * SYNC_MAX_OBJECT_BYTES && this.cache.size > 0) {
        const oldest = this.cache.keys().next().value as string
        this.bytes -= this.sizes.get(oldest) ?? 0
        this.cache.delete(oldest)
        this.sizes.delete(oldest)
      }
      this.cache.set(key, pack)
      this.sizes.set(key, size)
      this.bytes += size
    }
    if (invalid) throw new Error('sync_pack_incomplete')
  }

  async read(store: SyncPackStore, writer: string, epoch: number, hash: string, bytes: number,
    guard: () => void): Promise<string> {
    guard()
    const found = this.cached(writer, epoch, hash, bytes)
    if (found !== undefined) return found
    let byGuard = this.loading.get(writer)
    if (byGuard === undefined) {
      byGuard = new Map<() => void, Promise<void>>()
      this.loading.set(writer, byGuard)
    }
    let job = byGuard.get(guard)
    if (job === undefined) {
      job = this.discover(store, writer, guard)
      byGuard.set(guard, job)
    }
    try {
      await job
    } catch (error) {
      guard()
      const recovered = this.cached(writer, epoch, hash, bytes)
      if (recovered !== undefined) return recovered
      throw error as Error
    } finally {
      if (byGuard.get(guard) === job) byGuard.delete(guard)
      if (byGuard.size === 0) this.loading.delete(writer)
    }
    guard()
    const value = this.cached(writer, epoch, hash, bytes)
    if (value !== undefined) return value
    // A large discovery can evict an early pack before all packs are indexed.
    // Scan directly and return as soon as the requested item is found.
    const fallback = await readSyncPackObject(store, writer, epoch, hash, bytes, guard)
    guard()
    if (fallback !== undefined) return fallback
    throw new Error('sync_pack_not_found')
  }
}
