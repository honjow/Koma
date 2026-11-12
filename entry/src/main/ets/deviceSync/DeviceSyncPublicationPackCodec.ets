import { isSyncReplica } from './DeviceSyncFacts'
import { SyncObject, SyncShardRef, syncDigest, syncUtf8, SYNC_MAX_OBJECT_BYTES } from './DeviceSyncWire'

export interface SyncPublicationPackMember { epoch: number; hash: string }
export interface SyncPublicationPackEntry extends SyncPublicationPackMember { bytes: number; body: string }
export interface SyncPublicationPackLocation {
  writer: string
  hash: string
  bytes: number
  attempts: string[]
  members: SyncPublicationPackMember[]
}
export interface SyncPublicationPackBatch {
  body: string
  hash: string
  bytes: number
  members: SyncPublicationPackMember[]
}
export interface SyncPublicationPackBuild { batches: SyncPublicationPackBatch[]; singles: SyncObject[] }
export interface SyncPublicationPackContent { version: number; writer: string; entries: SyncPublicationPackEntry[] }
export interface SyncClassifiedCompactionEntry { entry: SyncPublicationPackEntry; dataset: string }
interface CompactionShardIdentity { dataset: string }

export function compactionEntryDataset(entry: SyncPublicationPackEntry): string {
  let value: CompactionShardIdentity
  try { value = JSON.parse(entry.body) as CompactionShardIdentity } catch (_error) { return '' }
  return value && typeof value.dataset === 'string' ? value.dataset : ''
}

export function classifyCompactionPack(pack: SyncPublicationPackContent): SyncClassifiedCompactionEntry[] {
  const result: SyncClassifiedCompactionEntry[] = []
  for (const entry of pack.entries) {
    const dataset = compactionEntryDataset(entry)
    if (dataset.length === 0) return []
    result.push({ entry, dataset })
  }
  return result
}

export function buildCompactionBatch(writer: string, objects: SyncObject[]): SyncPublicationPackBatch | undefined {
  const built = buildPublicationPackBatches(writer, objects)
  if (built.batches.length === 1 && built.singles.length === 0) return built.batches[0]
  if (built.batches.length !== 0 || built.singles.length !== 1) return undefined
  const item = built.singles[0]
  const entry: SyncPublicationPackEntry = { epoch: item.ref.epoch, hash: item.ref.hash, bytes: item.ref.bytes, body: item.body }
  const body = JSON.stringify({ version: 1, writer, entries: [entry] })
  const bytes = syncUtf8(body).byteLength
  if (bytes > SYNC_MAX_OBJECT_BYTES) return undefined
  return { body, hash: syncDigest(body), bytes, members: [{ epoch: entry.epoch, hash: entry.hash }] }
}

/** Mixed or unrecognizable historical packs must stay at their original path. */
export function compactionPackDataset(pack: SyncPublicationPackContent): string {
  let dataset = ''
  for (const entry of pack.entries) {
    const current = compactionEntryDataset(entry)
    if (current.length === 0 || (dataset.length > 0 && dataset !== current)) return ''
    dataset = current
  }
  return dataset
}

/** Decode an existing immutable v4 pack using its filename digest. */
export function decodeCompactionPack(writer: string, name: string, body: string): SyncPublicationPackContent {
  const match = /^pack-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-([0-9a-f]{64})\.json$/.exec(name)
  if (!isSyncReplica(writer) || match === null || syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES) {
    throw new Error('sync_pack_damaged')
  }
  const locator: SyncPublicationPackLocation = { writer, hash: match[2], bytes: syncUtf8(body).byteLength,
    attempts: [], members: [] }
  const decoded = decodePublicationPack(locator, body)
  if (decoded.entries.length === 0) throw new Error('sync_pack_damaged')
  return decoded
}

function memberKey(epoch: number, hash: string): string { return epoch.toString() + ':' + hash }

export function buildPublicationPackBatches(writer: string, objects: SyncObject[]): SyncPublicationPackBuild {
  if (!isSyncReplica(writer)) throw new Error('sync_pack_invalid')
  const prefix = '{"version":1,"writer":' + JSON.stringify(writer) + ',"entries":['
  const suffix = ']}'
  const base = syncUtf8(prefix + suffix).byteLength
  const result: SyncPublicationPackBuild = { batches: [], singles: [] }
  const seen = new Set<string>()
  let rows: SyncObject[] = []
  let encoded: string[] = []
  let size = base
  const flush = (): void => {
    if (rows.length < 2) result.singles.push(...rows)
    else {
      const body = prefix + encoded.join(',') + suffix
      result.batches.push({ body, hash: syncDigest(body), bytes: syncUtf8(body).byteLength,
        members: rows.map((object: SyncObject): SyncPublicationPackMember => ({ epoch: object.ref.epoch, hash: object.ref.hash })) })
    }
    rows = []; encoded = []; size = base
  }
  for (const object of objects) {
    const ref = object.ref
    if (!Number.isSafeInteger(ref.epoch) || ref.epoch < 1 || !/^[0-9a-f]{64}$/.test(ref.hash) ||
      ref.bytes !== syncUtf8(object.body).byteLength || ref.bytes < 1 || ref.bytes > SYNC_MAX_OBJECT_BYTES ||
      syncDigest(object.body) !== ref.hash) throw new Error('sync_shard_damaged')
    const key = memberKey(ref.epoch, ref.hash)
    if (seen.has(key)) continue
    seen.add(key)
    const entry: SyncPublicationPackEntry = { epoch: ref.epoch, hash: ref.hash, bytes: ref.bytes, body: object.body }
    const encodedEntry = JSON.stringify(entry)
    const length = syncUtf8(encodedEntry).byteLength
    if (base + length > SYNC_MAX_OBJECT_BYTES) { result.singles.push(object); continue }
    if (size + length + (rows.length > 0 ? 1 : 0) > SYNC_MAX_OBJECT_BYTES) flush()
    size += length + (rows.length > 0 ? 1 : 0)
    rows.push(object); encoded.push(encodedEntry)
  }
  flush()
  return result
}

export function validatePublicationPackLocation(location: SyncPublicationPackLocation, refs: SyncShardRef[]): void {
  if (!location || !isSyncReplica(location.writer) || !/^[0-9a-f]{64}$/.test(location.hash) ||
    !Number.isSafeInteger(location.bytes) || location.bytes < 1 || location.bytes > SYNC_MAX_OBJECT_BYTES ||
    !Array.isArray(location.attempts) || location.attempts.length !== 2 ||
    location.attempts.some((attempt: string): boolean => !isSyncReplica(attempt)) ||
    location.attempts[0] === location.attempts[1] || !Array.isArray(location.members) || location.members.length < 1) {
    throw new Error('sync_pack_invalid')
  }
  const allowed = new Set<string>(refs.map((ref: SyncShardRef): string => memberKey(ref.epoch, ref.hash)))
  const members = new Set<string>()
  location.members.forEach((member: SyncPublicationPackMember): void => {
    if (!member || !Number.isSafeInteger(member.epoch) || member.epoch < 1 || !/^[0-9a-f]{64}$/.test(member.hash)) {
      throw new Error('sync_pack_invalid')
    }
    const key = memberKey(member.epoch, member.hash)
    if (!allowed.has(key) || members.has(key)) throw new Error('sync_pack_invalid')
    members.add(key)
  })
}

export function decodePublicationPack(location: SyncPublicationPackLocation, body: string): SyncPublicationPackContent {
  if (syncUtf8(body).byteLength !== location.bytes || syncDigest(body) !== location.hash) throw new Error('sync_pack_damaged')
  let pack: SyncPublicationPackContent
  try { pack = JSON.parse(body) as SyncPublicationPackContent } catch (_error) { throw new Error('sync_pack_damaged') }
  if (!pack || pack.version !== 1 || pack.writer !== location.writer || !Array.isArray(pack.entries)) {
    throw new Error('sync_pack_damaged')
  }
  const entries = new Map<string, SyncPublicationPackEntry>()
  pack.entries.forEach((entry: SyncPublicationPackEntry): void => {
    if (!entry || !Number.isSafeInteger(entry.epoch) || entry.epoch < 1 || !/^[0-9a-f]{64}$/.test(entry.hash) ||
      typeof entry.body !== 'string' || entry.bytes !== syncUtf8(entry.body).byteLength ||
      entry.bytes < 1 || entry.bytes > SYNC_MAX_OBJECT_BYTES || syncDigest(entry.body) !== entry.hash ||
      entries.has(memberKey(entry.epoch, entry.hash))) throw new Error('sync_pack_damaged')
    entries.set(memberKey(entry.epoch, entry.hash), entry)
  })
  location.members.forEach((member: SyncPublicationPackMember): void => {
    if (!entries.has(memberKey(member.epoch, member.hash))) throw new Error('sync_pack_damaged')
  })
  return pack
}

/** Keep every still-referenced inherited locator, including unselected/unknown groups. */
export function retainPublicationPackLocations(locations: SyncPublicationPackLocation[], refs: SyncShardRef[]): SyncPublicationPackLocation[] {
  const allowed = new Set<string>(refs.map((ref: SyncShardRef): string => memberKey(ref.epoch, ref.hash)))
  const kept: SyncPublicationPackLocation[] = []
  locations.forEach((location: SyncPublicationPackLocation): void => {
    const members = location.members.filter((member: SyncPublicationPackMember): boolean => allowed.has(memberKey(member.epoch, member.hash)))
    if (members.length === 0) return
    const next: SyncPublicationPackLocation = { writer: location.writer, hash: location.hash, bytes: location.bytes,
      attempts: location.attempts.slice(), members }
    validatePublicationPackLocation(next, refs)
    kept.push(next)
  })
  return kept
}
