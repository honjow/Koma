import { isSyncReplica } from './DeviceSyncFacts'
import { syncDigest, syncUtf8, SYNC_MAX_OBJECT_BYTES } from './DeviceSyncWire'

export interface LegacyEntry {
  path: string
  bytes: number
  hash: string
  body: string
}

export interface LegacyPack {
  format: string
  version: number
  entries: LegacyEntry[]
}

export interface LegacyBatch {
  directory: string
  entries: LegacyEntry[]
  body: string
  hash: string
}


export function legacyDirectory(path: string): string {
  const object = /^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/.exec(path)
  if (object !== null && Number.isSafeInteger(Number(object[1]))) return 'legacy-v3/objects/' + object[2].charAt(0) + '/'
  const commit = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/([0-9]{14})\/([0-9]{16})-([0-9a-f]{64})\.json$/.exec(path)
  if (commit !== null && isSyncReplica(commit[1])) return 'legacy-v3/commits/' + commit[1] + '/' + commit[2] + '/'
  throw new Error('sync_legacy_archive_invalid')
}

export function checkedLegacyEntry(path: string, body: string): LegacyEntry {
  legacyDirectory(path)
  const object = /^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/.exec(path)
  const commit = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/([0-9]{14})\/([0-9]{16})-([0-9a-f]{64})\.json$/.exec(path)
  const hash = object !== null ? object[2] : commit![4]
  const bytes = syncUtf8(body).byteLength
  if (bytes < 1 || bytes > SYNC_MAX_OBJECT_BYTES || syncDigest(body) !== hash) throw new Error('sync_legacy_archive_damaged')
  return { path, bytes, hash, body }
}

export function checkedLegacyPack(directory: string, name: string, body: string): LegacyPack {
  const match = /^pack-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-([0-9a-f]{64})\.json$/.exec(name)
  if (match === null || syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES || syncDigest(body) !== match[2]) {
    throw new Error('sync_legacy_archive_damaged')
  }
  let pack: LegacyPack
  try { pack = JSON.parse(body) as LegacyPack } catch (_error) { throw new Error('sync_legacy_archive_damaged') }
  if (!pack || pack.format !== 'KOMA_V3_ARCHIVE' || pack.version !== 1 || !Array.isArray(pack.entries) || pack.entries.length < 3) {
    throw new Error('sync_legacy_archive_damaged')
  }
  const seen = new Set<string>()
  pack.entries.forEach((entry: LegacyEntry): void => {
    if (!entry || typeof entry.path !== 'string' || typeof entry.body !== 'string' || legacyDirectory(entry.path) !== directory) {
      throw new Error('sync_legacy_archive_damaged')
    }
    const checked = checkedLegacyEntry(entry.path, entry.body)
    if (checked.bytes !== entry.bytes || checked.hash !== entry.hash || seen.has(entry.path)) {
      throw new Error('sync_legacy_archive_damaged')
    }
    seen.add(entry.path)
  })
  return pack
}

export function makeLegacyBatches(input: LegacyEntry[]): LegacyBatch[] {
  const grouped = new Map<string, LegacyEntry[]>()
  input.forEach((entry: LegacyEntry): void => {
    const directory = legacyDirectory(entry.path)
    grouped.set(directory, (grouped.get(directory) ?? []).concat(entry))
  })
  const batches: LegacyBatch[] = []
  grouped.forEach((entries: LegacyEntry[], directory: string): void => {
    let part: LegacyEntry[] = []
    const flush = (): void => {
      if (part.length >= 3) {
        const body = JSON.stringify({ format: 'KOMA_V3_ARCHIVE', version: 1, entries: part })
        batches.push({ directory, entries: part, body, hash: syncDigest(body) })
      }
      part = []
    }
    entries.forEach((entry: LegacyEntry): void => {
      const next = part.concat(entry)
      const body = JSON.stringify({ format: 'KOMA_V3_ARCHIVE', version: 1, entries: next })
      if (syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES) {
        flush()
        const single = JSON.stringify({ format: 'KOMA_V3_ARCHIVE', version: 1, entries: [entry] })
        if (syncUtf8(single).byteLength <= SYNC_MAX_OBJECT_BYTES) part.push(entry)
      } else part = next
    })
    flush()
  })
  return batches
}
