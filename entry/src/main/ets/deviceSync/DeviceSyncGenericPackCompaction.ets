import { taskpool, util } from '@kit.ArkTS'
import { isSyncReplica } from './DeviceSyncFacts'
import { SyncObject, SyncShardRef, syncDigest } from './DeviceSyncWire'
import { SyncPackStore, SyncPackPendingAttempt } from './DeviceSyncObjectPack'
import { readCompactedSyncPublicationPacks, reconcileCompactionAttempts, SyncPackCompactionRead,
  SyncPackCompactionSession } from './DeviceSyncPackCompaction'
import { decodeCompactionPack, classifyCompactionPack, buildCompactionBatch, SyncPublicationPackContent,
  SyncClassifiedCompactionEntry, SyncPublicationPackBatch } from './DeviceSyncPublicationPackCodec'

const NAME = /^pack-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-([0-9a-f]{64})\.json$/
@Concurrent
function decodeTask(writer: string, name: string, body: string): SyncPublicationPackContent { return decodeCompactionPack(writer, name, body) }
@Concurrent
function classifyTask(pack: SyncPublicationPackContent): SyncClassifiedCompactionEntry[] { return classifyCompactionPack(pack) }
@Concurrent
function buildTask(writer: string, values: SyncObject[]): SyncPublicationPackBatch | undefined { return buildCompactionBatch(writer, values) }

interface GenericSource { name: string; entries: SyncClassifiedCompactionEntry[] }
interface GenericArchive { name: string; hash: string; refs: SyncShardRef[] }
interface GenericGroup { dataset: string; bucket: string; objects: SyncObject[] }
interface GenericWrite { dir: string; batch: SyncPublicationPackBatch; copies: GenericArchive[] }
interface GenericCachedSource { entries: SyncClassifiedCompactionEntry[]; bytes: number }
export interface GenericPackResult { removed: number; written: number; deferred: boolean }
export class GenericPackSession {
  cursor: string = ''
  readonly sourceNames: Set<string> = new Set()
  readonly index: Map<string, Map<string, GenericArchive>> = new Map()
  readonly hints: Map<string, string[]> = new Map()
  readonly sourceCache: Map<string, GenericCachedSource> = new Map()
  sourceCacheBytes: number = 0
}
export function genericPackArchiveDirectory(writer: string, dataset: string, objectHash: string): string {
  return writer + '/archive-objects/' + syncDigest(dataset).substring(0, 16) + '/' + objectHash.substring(0, 1) + '/'
}

export async function readGenericCompactedSyncPacks(store: SyncPackStore, writer: string, dataset: string,
  refs: SyncShardRef[], guard: () => void, session: SyncPackCompactionSession): Promise<SyncPackCompactionRead> {
  const groups = new Map<string, SyncShardRef[]>()
  refs.forEach((ref: SyncShardRef): void => {
    const key = ref.hash.substring(0, 1)
    groups.set(key, (groups.get(key) ?? []).concat(ref))
  })
  const objects: SyncObject[] = [], missing: SyncShardRef[] = []
  let incomplete = false
  for (const entry of groups.entries()) {
    const prefix = entry[0], values = entry[1]
    const result = await readCompactedSyncPublicationPacks(store, writer, dataset, prefix, values, guard, session, 'archive-objects')
    objects.push(...result.objects); missing.push(...result.missing); incomplete = incomplete || result.incomplete
  }
  return { objects, missing, incomplete }
}

export async function reconcileGenericCompactionAttempts(store: SyncPackStore, writer: string, guard: () => void): Promise<void> {
  await reconcileCompactionAttempts(store, writer, guard, 'archive-objects')
}
async function verified(store: SyncPackStore, writer: string, dir: string, name: string, guard: () => void): Promise<SyncPublicationPackContent | undefined> {
  const body = await store.read(dir + name); guard()
  if (body === undefined) return undefined
  try { const pack = await taskpool.execute(decodeTask, writer, name, body) as SyncPublicationPackContent; guard(); return pack }
  catch (_error) { guard(); return undefined }
}
async function indexedArchives(store: SyncPackStore, writer: string, dir: string, guard: () => void,
  session: GenericPackSession, pending: Set<string>): Promise<GenericArchive[]> {
  const names = Array.from(new Set<string>(await store.list(dir))).filter((name: string): boolean => NAME.test(name)).sort(); guard()
  const index = session.index.get(dir) ?? new Map<string, GenericArchive>()
  session.index.set(dir, index)
  const result: GenericArchive[] = []
  for (const name of names) {
    if (pending.has(dir + name)) continue
    let row = index.get(name)
    if (row === undefined) {
      const pack = await verified(store, writer, dir, name, guard)
      if (pack === undefined) continue
      row = { name, hash: NAME.exec(name)![2], refs: pack.entries.map((entry): SyncShardRef =>
        ({ epoch: entry.epoch, hash: entry.hash, bytes: entry.bytes, bucket: '' })) }
      index.set(name, row)
    }
    result.push(row)
  }
  return result
}
function identity(ref: SyncShardRef): string { return ref.epoch.toString() + ':' + ref.hash + ':' + ref.bytes.toString() }

/** Only locally owned, verified and non-pending source names explicitly supplied by the caller may be considered. */
export async function compactGenericSyncPacks(store: SyncPackStore, writer: string, guard: () => void,
  ensureDirectory: (path: string) => Promise<void>, allowNames: string[], session: GenericPackSession,
  limit: number = 16): Promise<GenericPackResult> {
  if (!isSyncReplica(writer)) throw new Error('sync_pack_invalid')
  const sourceDir = writer + '/packs/'
  const pendingRows = await store.loadPending(); guard()
  const pending = new Set<string>(pendingRows.map((item: SyncPackPendingAttempt): string => item.path))
  const allow = new Set<string>(allowNames)
  const allNames = Array.from(new Set<string>(await store.list(sourceDir))).filter((name: string): boolean =>
    NAME.test(name) && allow.has(name) && !pending.has(sourceDir + name)).sort(); guard()
  const batchSize = Math.max(0, Math.min(limit, 16))
  let window = allNames.filter((name: string): boolean => name > session.cursor).slice(0, batchSize)
  if (window.length === 0) { session.cursor = ''; window = allNames.slice(0, batchSize) }
  const cacheSource = (name: string, entries: SyncClassifiedCompactionEntry[]): void => {
    const bytes = entries.reduce((total: number, item: SyncClassifiedCompactionEntry): number => total + item.entry.body.length * 2, 0)
    while (session.sourceCacheBytes + bytes > 8 * 1024 * 1024 && session.sourceCache.size > 0) {
      const first = session.sourceCache.keys().next().value as string
      session.sourceCacheBytes -= session.sourceCache.get(first)!.bytes; session.sourceCache.delete(first)
    }
    if (bytes <= 8 * 1024 * 1024) { session.sourceCache.set(name, { entries, bytes }); session.sourceCacheBytes += bytes }
  }
  for (const name of window) {
    session.sourceNames.add(name); session.cursor = name
    while (session.sourceNames.size > 128) {
      const first = session.sourceNames.values().next().value as string
      session.sourceNames.delete(first); session.hints.delete(first)
      const old = session.sourceCache.get(first)
      if (old !== undefined) { session.sourceCacheBytes -= old.bytes; session.sourceCache.delete(first) }
    }
    if (session.hints.has(name)) continue
    const pack = await verified(store, writer, sourceDir, name, guard)
    if (pack === undefined) continue
    const entries = await taskpool.execute(classifyTask, pack) as SyncClassifiedCompactionEntry[]; guard()
    if (entries.length !== pack.entries.length) continue
    session.hints.set(name, Array.from(new Set<string>(entries.map((item: SyncClassifiedCompactionEntry): string =>
      item.dataset + ':' + item.entry.hash.substring(0, 1)))))
    cacheSource(name, entries)
  }
  const available = new Set<string>(allNames)
  for (const name of Array.from(session.sourceNames)) {
    if (available.has(name)) continue
    session.sourceNames.delete(name); session.hints.delete(name)
    const old = session.sourceCache.get(name)
    if (old !== undefined) { session.sourceCacheBytes -= old.bytes; session.sourceCache.delete(name) }
  }
  const hasMore = window.length > 0 && session.cursor !== allNames[allNames.length - 1]
  const buckets = new Set<string>()
  session.hints.forEach((items: string[]): void => { items.forEach((item: string): void => { buckets.add(item) }) })
  if (hasMore && 2 * buckets.size >= session.hints.size) return { removed: 0, written: 0, deferred: true }
  const sources: GenericSource[] = []
  let selectedBytes = 0, selectedEntries = 0
  for (const name of Array.from(session.sourceNames)) {
    if (!session.hints.has(name)) continue
    let cached = session.sourceCache.get(name)
    if (cached === undefined) {
      const pack = await verified(store, writer, sourceDir, name, guard)
      if (pack === undefined) continue
      const entries = await taskpool.execute(classifyTask, pack) as SyncClassifiedCompactionEntry[]; guard()
      if (entries.length !== pack.entries.length) continue
      cacheSource(name, entries); cached = session.sourceCache.get(name)
      if (cached === undefined) continue
    }
    const entries = cached.entries
    if (selectedBytes + cached.bytes > 8 * 1024 * 1024 || selectedEntries + entries.length > 2048) continue
    selectedBytes += cached.bytes; selectedEntries += entries.length
    sources.push({ name, entries })
  }
  if (sources.length === 0) return { removed: 0, written: 0, deferred: window.length > 0 && session.cursor !== allNames[allNames.length - 1] }
  const groups = new Map<string, GenericGroup>()
  for (const source of sources) for (const item of source.entries) {
    const entry = item.entry, bucket = entry.hash.substring(0, 1), key = item.dataset + ':' + bucket
    const group = groups.get(key) ?? { dataset: item.dataset, bucket, objects: [] }
    group.objects.push({ ref: { epoch: entry.epoch, hash: entry.hash, bytes: entry.bytes, bucket: '' }, body: entry.body })
    groups.set(key, group)
  }
  const byGroup = new Map<string, GenericArchive[]>()
  for (const entry of groups.entries()) {
    const key = entry[0], group = entry[1]
    const dir = genericPackArchiveDirectory(writer, group.dataset, group.bucket)
    byGroup.set(key, await indexedArchives(store, writer, dir, guard, session, pending))
  }
  const confirmed = new Set<string>()
  const hasTwo = async (item: SyncClassifiedCompactionEntry): Promise<boolean> => {
    const dir = genericPackArchiveDirectory(writer, item.dataset, item.entry.hash)
    const key = item.dataset + ':' + item.entry.hash.substring(0, 1)
    const target = item.entry.epoch.toString() + ':' + item.entry.hash + ':' + item.entry.bytes.toString()
    let count = 0
    for (const row of byGroup.get(key) ?? []) {
      if (!row.refs.some((ref: SyncShardRef): boolean => identity(ref) === target)) continue
      if (!confirmed.has(dir + row.name)) {
        if (await verified(store, writer, dir, row.name, guard) === undefined) continue
        confirmed.add(dir + row.name)
      }
      if (++count >= 2) return true
    }
    return false
  }
  let removed = 0, written = 0
  const needed: GenericSource[] = []
  for (const source of sources) {
    let covered = true
    for (const entry of source.entries) if (!(await hasTwo(entry))) { covered = false; break }
    if (!covered) { needed.push(source); continue }
    await store.remove(sourceDir + source.name); guard(); session.sourceNames.delete(source.name); removed++
  }
  if (needed.length === 0) return { removed, written, deferred: window.length > 0 && session.cursor !== allNames[allNames.length - 1] }
  const useful = new Map<string, GenericGroup>()
  for (const source of needed) for (const item of source.entries) {
    if (await hasTwo(item)) continue
    const key = item.dataset + ':' + item.entry.hash.substring(0, 1)
    const group = useful.get(key) ?? { dataset: item.dataset, bucket: item.entry.hash.substring(0, 1), objects: [] }
    group.objects.push({ ref: { epoch: item.entry.epoch, hash: item.entry.hash, bytes: item.entry.bytes, bucket: '' }, body: item.entry.body })
    useful.set(key, group)
  }
  const plans: GenericWrite[] = []
  let newFiles = 0
  for (const entry of useful.entries()) {
    const key = entry[0], group = entry[1]
    const batch = await taskpool.execute(buildTask, writer, group.objects) as SyncPublicationPackBatch | undefined; guard()
    if (batch === undefined) return { removed, written, deferred: hasMore }
    const dir = genericPackArchiveDirectory(writer, group.dataset, group.bucket)
    const copies: GenericArchive[] = []
    for (const row of (byGroup.get(key) ?? []).filter((item: GenericArchive): boolean => item.hash === batch.hash)) {
      if (confirmed.has(dir + row.name) || await verified(store, writer, dir, row.name, guard) !== undefined) {
        confirmed.add(dir + row.name); copies.push(row)
      }
    }
    newFiles += Math.max(0, 2 - copies.length)
    plans.push({ dir, batch, copies })
  }
  if (newFiles >= needed.length) return { removed, written, deferred: window.length > 0 && session.cursor !== allNames[allNames.length - 1] }
  for (const plan of plans) {
    await ensureDirectory(plan.dir); guard()
    while (plan.copies.length < 2) {
      const name = 'pack-' + util.generateRandomUUID() + '-' + plan.batch.hash + '.json', path = plan.dir + name
      await store.recordPending({ path, startedAt: Date.now() }); guard()
      await store.write(path, plan.batch.body); guard()
      const pack = await verified(store, writer, plan.dir, name, guard)
      if (pack === undefined || !(await store.list(plan.dir)).includes(name)) throw new Error('sync_pack_unconfirmed')
      guard(); await store.forgetPending(path); guard()
      const row: GenericArchive = { name, hash: plan.batch.hash, refs: pack.entries.map((entry): SyncShardRef =>
        ({ epoch: entry.epoch, hash: entry.hash, bytes: entry.bytes, bucket: '' })) }
      const index = session.index.get(plan.dir) ?? new Map<string, GenericArchive>(); index.set(name, row); session.index.set(plan.dir, index)
      plan.copies.push(row); written++
    }
  }
  for (const source of needed) { await store.remove(sourceDir + source.name); guard(); session.sourceNames.delete(source.name); removed++ }
  return { removed, written, deferred: window.length > 0 && session.cursor !== allNames[allNames.length - 1] }
}
