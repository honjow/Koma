import { taskpool, util } from '@kit.ArkTS'
import { SyncPackStore, SyncPackPendingAttempt } from './DeviceSyncObjectPack'
import { SyncObject, SyncShardRef, syncDigest } from './DeviceSyncWire'
import { isSyncReplica } from './DeviceSyncFacts'
import { buildPublicationPackBatches, decodeCompactionPack, compactionPackDataset, SyncPublicationPackBuild,
  SyncPublicationPackContent, SyncPublicationPackEntry } from './DeviceSyncPublicationPackCodec'

const NAME = /^pack-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-([0-9a-f]{64})\.json$/

@Concurrent
function decodeTask(writer: string, name: string, body: string): SyncPublicationPackContent {
  return decodeCompactionPack(writer, name, body)
}
@Concurrent
function buildTask(writer: string, objects: SyncObject[]): SyncPublicationPackBuild {
  return buildPublicationPackBatches(writer, objects)
}
@Concurrent
function identifyTask(pack: SyncPublicationPackContent): string { return compactionPackDataset(pack) }

export interface SyncPackCompactionResult { removed: number; written: number; deferred: boolean }
export interface SyncPackCompactionRead { objects: SyncObject[]; missing: SyncShardRef[]; incomplete: boolean }
interface VerifiedArchive { name: string; hash: string; members: SyncShardRef[] }
interface CompactionCandidate { name: string; pack: SyncPublicationPackContent; dataset: string; bucket: string }
interface CompactionReadBucket {
  names: string[]
  next: number
  seen: Set<string>
  index: Map<string, string[]>
}
interface CompactionCachedPack { pack: SyncPublicationPackContent; bytes: number }
interface CompactionSourceHint { name: string; dataset: string; bucket: string; bytes: number }

/** Kept per provider/endpoint: cursor covers later packs even if an early batch cannot merge. */
export class SyncPackMaintenanceSession {
  cursor: string = ''
  readonly groups: Map<string, CompactionSourceHint[]> = new Map()
  readonly archiveIndex: Map<string, Map<string, VerifiedArchive>> = new Map()
}

/** A fresh session per round: a temporary miss never becomes a durable negative cache. */
export class SyncPackCompactionSession {
  readonly buckets: Map<string, CompactionReadBucket> = new Map()
  readonly cache: Map<string, CompactionCachedPack> = new Map()
  readonly loading: Map<string, Promise<void>> = new Map()
  bytes: number = 0
}

export function compactionArchiveDirectory(writer: string, dataset: string, sourceHash: string, kind: string = 'archive'): string {
  return writer + '/' + kind + '/' + syncDigest(dataset).substring(0, 16) + '/' + sourceHash.substring(0, 1) + '/'
}

/** Timed-out PUTs can arrive after DELETE. Keep their markers and recheck with backoff. */
export async function reconcileCompactionAttempts(store: SyncPackStore, writer: string, guard: () => void,
  kind: string = 'archive'): Promise<void> {
  const base = writer + '/' + kind + '/'
  const all = await store.loadPending(); guard()
  const pending = all.filter((row: SyncPackPendingAttempt): boolean => row.path.startsWith(base) &&
    NAME.test(row.path.substring(row.path.lastIndexOf('/') + 1)) && (row.nextCheckAt ?? 0) <= Date.now())
  if (pending.length === 0) return
  const listings = new Map<string, string[]>()
  const pendingPaths = new Set<string>(all.map((row: SyncPackPendingAttempt): string => row.path))
  for (const row of pending) {
    const dir = row.path.substring(0, row.path.lastIndexOf('/') + 1)
    let names = listings.get(dir)
    if (names === undefined) { names = Array.from(new Set<string>(await store.list(dir))); guard(); listings.set(dir, names) }
    const name = row.path.substring(dir.length), hash = NAME.exec(name)![2]
    const body = await store.read(row.path); guard()
    if (body !== undefined && names.includes(name)) {
      let count = 0
      for (const candidate of names) {
        if (candidate === name || pendingPaths.has(dir + candidate) || NAME.exec(candidate)?.[2] !== hash) continue
        if (await verified(store, writer, dir, candidate, guard) !== undefined) count++
        if (count >= 2) break
      }
      if (count >= 2) { await store.remove(row.path); guard() }
    }
    const checks = (row.checks ?? 0) + 1
    const delays = [15000, 60000, 300000, 1800000, 21600000, 86400000]
    await store.deferPending(row.path, row.startedAt, Date.now() + delays[Math.min(checks - 1, delays.length - 1)], checks, false)
    guard()
  }
}

async function verified(store: SyncPackStore, writer: string, directory: string, name: string,
  guard: () => void): Promise<SyncPublicationPackContent | undefined> {
  const body = await store.read(directory + name)
  guard()
  if (body === undefined) return undefined
  try { const pack = await taskpool.execute(decodeTask, writer, name, body) as SyncPublicationPackContent; guard(); return pack }
  catch (_error) { guard(); return undefined }
}

async function archives(store: SyncPackStore, writer: string, directory: string, guard: () => void,
  session: SyncPackMaintenanceSession): Promise<VerifiedArchive[]> {
  const names = Array.from(new Set<string>(await store.list(directory))).filter((name: string): boolean => NAME.test(name)).sort()
  guard()
  const pending = new Set<string>((await store.loadPending()).map((item: SyncPackPendingAttempt): string => item.path))
  guard()
  const result: VerifiedArchive[] = []
  const index = session.archiveIndex.get(directory) ?? new Map<string, VerifiedArchive>()
  session.archiveIndex.set(directory, index)
  for (const name of names) {
    if (pending.has(directory + name)) continue
    const cached = index.get(name)
    if (cached !== undefined) { result.push(cached); continue }
    const pack = await verified(store, writer, directory, name, guard)
    if (pack !== undefined) {
      const value: VerifiedArchive = { name, hash: NAME.exec(name)![2], members: pack.entries.map(
        (entry: SyncPublicationPackEntry): SyncShardRef => ({ epoch: entry.epoch, hash: entry.hash, bytes: entry.bytes, bucket: '' })) }
      index.set(name, value); result.push(value)
    }
  }
  return result
}

/** Locate a requested batch in permanent compaction packs; missing is not a deletion proof. */
export async function readCompactedSyncPublicationPacks(store: SyncPackStore, writer: string,
  dataset: string, sourceHash: string, refs: SyncShardRef[], guard: () => void,
  session: SyncPackCompactionSession = new SyncPackCompactionSession(), kind: string = 'archive'): Promise<SyncPackCompactionRead> {
  const directory = compactionArchiveDirectory(writer, dataset, sourceHash, kind)
  const previous = session.loading.get(directory)
  let release: () => void = (): void => {}
  const completed = new Promise<void>((resolve: () => void): void => { release = resolve })
  session.loading.set(directory, completed)
  try {
    if (previous !== undefined) await previous
    guard()
    return await readCompactedBucket(store, writer, dataset, sourceHash, refs, guard, session, kind)
  } finally {
    release()
    if (session.loading.get(directory) === completed) session.loading.delete(directory)
  }
}

async function readCompactedBucket(store: SyncPackStore, writer: string,
  dataset: string, sourceHash: string, refs: SyncShardRef[], guard: () => void,
  session: SyncPackCompactionSession, kind: string): Promise<SyncPackCompactionRead> {
  if (!isSyncReplica(writer)) throw new Error('sync_pack_invalid')
  const result: SyncObject[] = []
  const remaining = new Map<string, SyncShardRef[]>()
  refs.forEach((ref: SyncShardRef): void => {
    const key = ref.epoch.toString() + ':' + ref.hash
    remaining.set(key, (remaining.get(key) ?? []).concat(ref))
  })
  const directory = compactionArchiveDirectory(writer, dataset, sourceHash, kind)
  let bucket = session.buckets.get(directory)
  if (bucket === undefined) {
    const names = Array.from(new Set<string>(await store.list(directory))).filter((name: string): boolean => NAME.test(name)).sort()
    guard()
    bucket = { names, next: 0, seen: new Set<string>(), index: new Map<string, string[]>() }
    session.buckets.set(directory, bucket)
  }
  const pending = new Set<string>((await store.loadPending()).map((item: SyncPackPendingAttempt): string => item.path))
  guard()
  const read = async (name: string): Promise<SyncPublicationPackContent | undefined> => {
    const path = directory + name
    if (pending.has(path)) return undefined
    let cached = session.cache.get(path)
    if (cached !== undefined) { session.cache.delete(path); session.cache.set(path, cached); return cached.pack }
    const pack = await verified(store, writer, directory, name, guard)
    if (pack === undefined) return undefined
    const identity = await taskpool.execute(identifyTask, pack) as string
    guard()
    if (identity !== dataset) return undefined
    const bytes = pack.entries.reduce((total: number, entry: SyncPublicationPackEntry): number => total + entry.body.length * 2, 0)
    while (session.bytes + bytes > 8 * 1024 * 1024 && session.cache.size > 0) {
      const first = session.cache.keys().next().value as string
      session.bytes -= session.cache.get(first)!.bytes; session.cache.delete(first)
    }
    if (bytes <= 8 * 1024 * 1024) { cached = { pack, bytes }; session.cache.set(path, cached); session.bytes += bytes }
    return pack
  }
  const consume = (pack: SyncPublicationPackContent): void => {
    for (const entry of pack.entries) {
      const key = entry.epoch.toString() + ':' + entry.hash
      const matches = remaining.get(key)
      if (matches === undefined) continue
      for (const ref of matches) {
        if (ref.bytes !== entry.bytes) throw new Error('sync_pack_damaged')
        result.push({ ref, body: entry.body })
      }
      remaining.delete(key)
    }
  }
  for (const key of Array.from(remaining.keys())) {
    for (const name of bucket.index.get(key) ?? []) {
      const pack = await read(name)
      if (pack !== undefined) { consume(pack); if (!remaining.has(key)) break }
    }
  }
  while (remaining.size > 0 && bucket.next < bucket.names.length) {
    const name = bucket.names[bucket.next], hash = NAME.exec(name)![2]
    if (pending.has(directory + name) || bucket.seen.has(hash)) { bucket.next++; continue }
    const pack = await read(name)
    guard()
    bucket.next++
    if (pack === undefined) continue
    bucket.seen.add(hash)
    const alternatives = bucket.names.filter((item: string): boolean => NAME.exec(item)?.[2] === hash)
    for (const entry of pack.entries) {
      const key = entry.epoch.toString() + ':' + entry.hash
      bucket.index.set(key, (bucket.index.get(key) ?? []).concat(alternatives))
    }
    consume(pack)
  }
  const missing: SyncShardRef[] = []
  remaining.forEach((items: SyncShardRef[]): void => { missing.push(...items) })
  return { objects: result, missing, incomplete: missing.length > 0 }
}

/** Source packs are immutable; archive outputs are never candidates for this compactor. */
export async function compactSyncPublicationPacks(store: SyncPackStore, writer: string, guard: () => void,
  ensureDirectory: (path: string) => Promise<void>, allowNames: string[], limit: number = 16,
  protectedNames: string[] = [], session: SyncPackMaintenanceSession = new SyncPackMaintenanceSession()): Promise<SyncPackCompactionResult> {
  if (!isSyncReplica(writer)) throw new Error('sync_pack_invalid')
  const sourceDir = writer + '/packs/', archiveBase = writer + '/archive/'
  const pending = new Set<string>((await store.loadPending()).map((item: SyncPackPendingAttempt): string => item.path))
  const protectedSet = new Set<string>(protectedNames)
  // A general pack lacks a head locator and cannot be found in a hash bucket after removal.
  const allowed = new Set<string>(allowNames)
  const allNames = Array.from(new Set<string>(await store.list(sourceDir))).filter((name: string): boolean =>
    NAME.test(name) && !pending.has(sourceDir + name) && !protectedSet.has(name) && allowed.has(name)).sort()
  let names = allNames.filter((name: string): boolean => name > session.cursor).slice(0, Math.max(0, limit))
  if (names.length === 0) { session.cursor = ''; names = allNames.slice(0, Math.max(0, limit)) }
  guard()
  let removed = 0, written = 0
  const scanned = new Map<string, SyncPublicationPackContent>()
  for (const name of names) {
    const pack = await verified(store, writer, sourceDir, name, guard)
    session.cursor = name
    if (pack === undefined) continue
    scanned.set(name, pack)
    const dataset = await taskpool.execute(identifyTask, pack) as string
    guard()
    if (dataset.length === 0) continue
    const bucket = NAME.exec(name)![2].substring(0, 1)
    const key = dataset + ':' + bucket
    const hints = session.groups.get(key) ?? []
    const bytes = pack.entries.reduce((total: number, entry: SyncPublicationPackEntry): number => total + entry.bytes, 0)
    if (!hints.some((item: CompactionSourceHint): boolean => item.name === name)) hints.push({ name, dataset, bucket, bytes })
    session.groups.set(key, hints)
  }
  const available = new Set<string>(allNames)
  let chosen: CompactionSourceHint[] | undefined
  for (const entry of session.groups.entries()) {
    const key = entry[0], hints = entry[1]
    const retained = hints.filter((hint: CompactionSourceHint): boolean => available.has(hint.name))
    session.groups.set(key, retained)
    if (chosen === undefined && retained.length >= 3) {
      const sorted = retained.slice().sort((a: CompactionSourceHint, b: CompactionSourceHint): number => a.bytes - b.bytes)
      const fits: CompactionSourceHint[] = []
      let bytes = 0
      for (const item of sorted) if (bytes + item.bytes <= 128 * 1024) { fits.push(item); bytes += item.bytes }
      if (fits.length >= 3) chosen = fits
    }
  }
  if (chosen === undefined) chosen = Array.from(session.groups.values()).find((items: CompactionSourceHint[]): boolean => items.length > 0)
  if (chosen === undefined) return { removed, written, deferred: names.length > 0 && session.cursor !== allNames[allNames.length - 1] }
  const group: CompactionCandidate[] = []
  for (const hint of chosen) {
    const pack = scanned.get(hint.name) ?? await verified(store, writer, sourceDir, hint.name, guard)
    if (pack === undefined) continue
    const identity = await taskpool.execute(identifyTask, pack) as string
    guard()
    if (identity === hint.dataset) group.push({ name: hint.name, pack, dataset: hint.dataset, bucket: hint.bucket })
  }
  if (group.length === 0) return { removed, written, deferred: false }
  const archiveDir = compactionArchiveDirectory(writer, group[0].dataset, group[0].bucket)
  await ensureDirectory(archiveDir); guard()
  let known = await archives(store, writer, archiveDir, guard, session)
  const confirmed = new Set<string>()
  const candidates: CompactionCandidate[] = []
  let total = 0
  for (const item of group) {
    const name = item.name, pack = item.pack
    let covered = pack.entries.every((entry: SyncPublicationPackEntry): boolean => known.filter((archive: VerifiedArchive): boolean =>
      archive.members.some((item: SyncShardRef): boolean => item.epoch === entry.epoch && item.hash === entry.hash &&
        item.bytes === entry.bytes)).length >= 2)
    if (covered) {
      const relevant = known.filter((archive: VerifiedArchive): boolean => archive.members.some((member: SyncShardRef): boolean =>
        pack.entries.some((entry: SyncPublicationPackEntry): boolean => entry.epoch === member.epoch && entry.hash === member.hash)))
      for (const archive of relevant) {
        if (confirmed.has(archive.name)) continue
        if (await verified(store, writer, archiveDir, archive.name, guard) !== undefined) confirmed.add(archive.name)
      }
      covered = pack.entries.every((entry: SyncPublicationPackEntry): boolean => relevant.filter((archive: VerifiedArchive): boolean =>
        confirmed.has(archive.name) && archive.members.some((member: SyncShardRef): boolean => member.epoch === entry.epoch &&
          member.hash === entry.hash && member.bytes === entry.bytes)).length >= 2)
    }
    if (covered) {
      try { await store.remove(sourceDir + name); guard(); removed++ }
      catch (error) { guard(); if ((error as Error).message !== 'sync_pack_in_use') throw error as Error }
      continue
    }
    // Bounded inputs also keep the generated pack within the existing wire size.
    const estimate = pack.entries.reduce((size: number, entry: SyncPublicationPackEntry): number => size + entry.bytes, 0)
    if (total + estimate > 128 * 1024) continue
    candidates.push(item); total += estimate
  }
  if (candidates.length < 3) return { removed, written,
    deferred: names.length > 0 && session.cursor !== allNames[allNames.length - 1] }
  const objects: SyncObject[] = []
  candidates.forEach((candidate): void => candidate.pack.entries.forEach((entry: SyncPublicationPackEntry): void => {
    objects.push({ ref: { epoch: entry.epoch, hash: entry.hash, bytes: entry.bytes, bucket: '' }, body: entry.body })
  }))
  const built = await taskpool.execute(buildTask, writer, objects) as SyncPublicationPackBuild
  guard()
  if (built.singles.length > 0 || built.batches.length !== 1) return { removed, written, deferred: false }
  const batch = built.batches[0]
  let copies: VerifiedArchive[] = []
  for (const item of known.filter((archive: VerifiedArchive): boolean => archive.hash === batch.hash)) {
    if (confirmed.has(item.name) || await verified(store, writer, archiveDir, item.name, guard) !== undefined) {
      confirmed.add(item.name); copies.push(item)
    }
  }
  const unresolved = (await store.loadPending()).filter((item: SyncPackPendingAttempt): boolean => item.path.startsWith(archiveBase))
  guard()
  if (unresolved.length >= 4 && Date.now() - Math.max(...unresolved.map((item: SyncPackPendingAttempt): number => item.startedAt)) < 300000) {
    return { removed, written, deferred: true }
  }
  while (copies.length < 2) {
    const name = 'pack-' + util.generateRandomUUID() + '-' + batch.hash + '.json', path = archiveDir + name
    await store.recordPending({ path, startedAt: Date.now() }); guard()
    await store.write(path, batch.body); guard()
    const actual = await verified(store, writer, archiveDir, name, guard)
    if (actual === undefined) throw new Error('sync_pack_unconfirmed')
    const listed = await store.list(archiveDir); guard()
    if (!listed.includes(name)) throw new Error('sync_pack_unconfirmed')
    await store.forgetPending(path); guard()
    const entry: VerifiedArchive = { name, hash: batch.hash, members: actual.entries.map(
      (item: SyncPublicationPackEntry): SyncShardRef => ({ epoch: item.epoch, hash: item.hash, bytes: item.bytes, bucket: '' })) }
    session.archiveIndex.get(archiveDir)?.set(name, entry)
    confirmed.add(name)
    known = known.concat(entry); copies = copies.concat(entry); written++
  }
  for (const candidate of candidates) {
    // The two new copies have both been read and discovered in this pass.
    try { await store.remove(sourceDir + candidate.name); guard(); removed++ }
    catch (error) { guard(); if ((error as Error).message !== 'sync_pack_in_use') throw error as Error }
  }
  const processed = new Set<string>(group.map((item: CompactionCandidate): string => item.name))
  const moreGroups = Array.from(session.groups.values()).some((hints: CompactionSourceHint[]): boolean => {
    const left = hints.filter((hint: CompactionSourceHint): boolean => available.has(hint.name) && !processed.has(hint.name))
      .sort((a: CompactionSourceHint, b: CompactionSourceHint): number => a.bytes - b.bytes)
    return left.length >= 3 && left[0].bytes + left[1].bytes + left[2].bytes <= 128 * 1024
  })
  return { removed, written, deferred: session.cursor !== allNames[allNames.length - 1] || moreGroups }
}
