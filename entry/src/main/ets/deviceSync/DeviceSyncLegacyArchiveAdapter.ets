import { isSyncReplica } from './DeviceSyncFacts'
import { SyncLegacyArchiveReader, SyncLegacyArchiveStore, listArchivedLegacyV3Commits } from './DeviceSyncLegacyArchive'
import { checkedLegacyEntry } from './DeviceSyncLegacyArchiveCodec'
import { taskpool } from '@kit.ArkTS'

const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const COMMIT = new RegExp('^(' + UUID + ')/([0-9]{14})/([0-9]{16})-([0-9a-f]{64})\\.json$')

@Concurrent
function checkLegacyOriginalTask(path: string, body: string): boolean {
  try { checkedLegacyEntry(path, body); return true } catch (_error) { return false }
}

function pathParts(path: string): RegExpExecArray | null { return COMMIT.exec(path) }

/** Merge physical and archived writers, including offline devices' witnesses. */
export async function legacyArchiveWriters(store: SyncLegacyArchiveStore, physical: string[], witnesses: string[],
  guard: () => void): Promise<string[]> {
  const archived = await store.listArchive('legacy-v3/commits/')
  guard()
  const all = physical.concat(archived).map((name: string): string => name.replace(/\/$/, ''))
    .filter((name: string): boolean => isSyncReplica(name))
  witnesses.forEach((path: string): void => {
    const parts = pathParts(path)
    if (parts !== null) all.push(parts[1])
  })
  return Array.from(new Set<string>(all)).sort()
}

/** Archive directories are needed even when a stale v3 listing omitted the latest head. */
export async function legacyArchiveSegments(store: SyncLegacyArchiveStore, writer: string, physical: string[],
  witnesses: string[], guard: () => void): Promise<string[]> {
  if (!isSyncReplica(writer)) throw new Error('sync_legacy_archive_invalid')
  const archived = await store.listArchive('legacy-v3/commits/' + writer + '/')
  guard()
  const all = physical.concat(archived).map((name: string): string => name.replace(/\/$/, ''))
    .filter((name: string): boolean => /^[0-9]{14}$/.test(name))
  witnesses.forEach((path: string): void => {
    const parts = pathParts(path)
    if (parts !== null && parts[1] === writer) all.push(parts[2])
  })
  return Array.from(new Set<string>(all)).sort().reverse()
}

/** Return original v3 paths in revision order, from both physical and archived commits. */
export async function legacyArchiveCandidates(store: SyncLegacyArchiveStore, writer: string, segment: string,
  physical: string[], witnesses: string[], guard: () => void): Promise<string[]> {
  if (!isSyncReplica(writer) || !/^[0-9]{14}$/.test(segment)) throw new Error('sync_legacy_archive_invalid')
  const prefix = writer + '/' + segment + '/'
  const archived = await listArchivedLegacyV3Commits(store, writer, segment, guard)
  guard()
  const candidates = physical.map((name: string): string => name.startsWith(prefix) ? name : prefix + name)
    .concat(archived, witnesses)
    .filter((path: string): boolean => {
      const parts = pathParts(path)
      return parts !== null && parts[1] === writer && parts[2] === segment
    })
  return Array.from(new Set<string>(candidates)).sort().reverse()
}

/** Prefer a verified original; a known witness must never turn missing into a rewind. */
export async function legacyArchiveRead(store: SyncLegacyArchiveStore, reader: SyncLegacyArchiveReader,
  originalPath: string, guard: () => void, required: boolean = false): Promise<string | undefined> {
  const original = await store.readOriginal(originalPath)
  guard()
  if (original !== undefined) {
    const valid = await taskpool.execute(checkLegacyOriginalTask, originalPath, original) as boolean
    guard()
    if (valid) return original
  }
  return reader.read(store, originalPath, guard, required)
}
