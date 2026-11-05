import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { checkedSyncFact, isSyncReplica, SyncFact } from './DeviceSyncFacts'

export const SYNC_WIRE_VERSION = 2
export const SYNC_MAX_OBJECT_BYTES = 1024 * 1024
export const SYNC_MAX_ROUND_BYTES = 64 * SYNC_MAX_OBJECT_BYTES
export const SYNC_COLLECTION = 'koma-device-sync-v2'

export interface SyncShardRef {
  bucket: string
  epoch: number
  hash: string
  bytes: number
}

export interface SyncDatasetRef {
  id: string
  schema: number
  shards: SyncShardRef[]
}

export interface SyncManifest {
  format: 'KOMA_DEVICE_SYNC'
  schema: number
  minWriter: number
  space: string
  revision: number
  epoch: number
  maintenance: boolean
  datasets: SyncDatasetRef[]
  previous: SyncDatasetRef[]
  // Unselected/unknown groups retain every concurrent branch without reading their data.
  alternatives?: SyncDatasetRef[]
}

export interface SyncObject {
  ref: SyncShardRef
  body: string
}

export function copySyncManifest(value: SyncManifest, space: string = value.space): SyncManifest {
  return { format: value.format, schema: value.schema, minWriter: value.minWriter, space,
    revision: value.revision, epoch: value.epoch, maintenance: value.maintenance, datasets: value.datasets,
    previous: value.previous, alternatives: value.alternatives }
}

export interface SyncDataset {
  ref: SyncDatasetRef
  objects: SyncObject[]
}

export function syncUtf8(text: string): Uint8Array {
  return new util.TextEncoder().encodeInto(text)
}

export function syncDigest(text: string): string {
  return syncDigestBytes(syncUtf8(text))
}

export function syncDigestBytes(bytes: Uint8Array): string {
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: bytes })
  return Array.from(digest.digestSync().data).map((byte: number): string => byte.toString(16).padStart(2, '0')).join('')
}

function validNumber(value: number, min: number, max: number): boolean {
  return Number.isSafeInteger(value) && value >= min && value <= max
}

export function isSyncDigest(value: string): boolean {
  return typeof value === 'string' && /^[0-9a-f]{64}$/.test(value)
}

export function strongSyncTag(tag: string): boolean {
  return typeof tag === 'string' && /^"[\x21\x23-\x7e]+"$/.test(tag)
}

export function syncShardPath(ref: SyncShardRef): string {
  return `object-${ref.epoch}-${ref.hash}.json`
}

export function newSyncManifest(space: string): SyncManifest {
  if (!isSyncReplica(space)) throw new Error('sync_invalid_space')
  return { format: 'KOMA_DEVICE_SYNC', schema: 2, minWriter: SYNC_WIRE_VERSION, space, revision: 0,
    epoch: 1, maintenance: false, datasets: [], previous: [] }
}

export function checkedSyncDatasets(datasets: SyncDatasetRef[], epoch: number): void {
  if (!Array.isArray(datasets) || datasets.length > 128) throw new Error('sync_invalid_datasets')
  const ids = new Set<string>()
  datasets.forEach((dataset: SyncDatasetRef): void => {
    if (!dataset || typeof dataset.id !== 'string' || !/^[a-z0-9-]{1,64}$/.test(dataset.id) ||
      !validNumber(dataset.schema, 1, Number.MAX_SAFE_INTEGER) || ids.has(dataset.id) ||
      !Array.isArray(dataset.shards) || dataset.shards.length > 16384) throw new Error('sync_invalid_dataset')
    ids.add(dataset.id)
    const buckets = new Set<string>()
    dataset.shards.forEach((ref: SyncShardRef): void => {
      if (!ref || typeof ref.bucket !== 'string' || !/^(0[0-9a-f]|[1-3][0-9a-f])(-[0-9a-f]{1,64})?$/.test(ref.bucket) ||
        !validNumber(ref.epoch, 1, epoch) || !isSyncDigest(ref.hash) ||
        !validNumber(ref.bytes, 1, SYNC_MAX_OBJECT_BYTES) || buckets.has(ref.bucket)) {
        throw new Error('sync_invalid_shard_reference')
      }
      buckets.add(ref.bucket)
    })
  })
}

export function decodeSyncManifest(body: string): SyncManifest {
  let manifest: SyncManifest
  try {
    manifest = JSON.parse(body) as SyncManifest
  } catch (_error) {
    throw new Error('sync_invalid_manifest')
  }
  if (!manifest || manifest.format !== 'KOMA_DEVICE_SYNC') throw new Error('sync_invalid_manifest')
  if ((manifest.schema !== 1 && manifest.schema !== 2) || manifest.minWriter > SYNC_WIRE_VERSION) throw new Error('sync_update_required')
  if (!isSyncReplica(manifest.space) || !validNumber(manifest.revision, 1, Number.MAX_SAFE_INTEGER) ||
    !validNumber(manifest.epoch, 1, manifest.revision) || !validNumber(manifest.minWriter, 1, SYNC_WIRE_VERSION) ||
    typeof manifest.maintenance !== 'boolean') {
    throw new Error('sync_invalid_manifest')
  }
  checkedSyncDatasets(manifest.datasets, manifest.epoch)
  checkedSyncDatasets(manifest.previous, manifest.epoch)
  if (manifest.alternatives !== undefined) {
    if (manifest.schema !== 2 || !Array.isArray(manifest.alternatives) || manifest.alternatives.length > 512) {
      throw new Error('sync_invalid_datasets')
    }
    manifest.alternatives.forEach((ref: SyncDatasetRef): void => { checkedSyncDatasets([ref], manifest.epoch) })
  }
  return manifest
}

export function syncDatasetBranches(manifest: SyncManifest | undefined, id: string): SyncDatasetRef[] {
  return (manifest?.datasets ?? []).concat(manifest?.alternatives ?? [])
    .filter((ref: SyncDatasetRef): boolean => ref.id === id)
}

export function syncDatasetBytes(ref: SyncDatasetRef): number {
  return ref.shards.reduce((size: number, shard: SyncShardRef): number => size + shard.bytes, 0)
}

function compareKey(a: SyncFact, b: SyncFact): number {
  return a.key === b.key ? 0 : a.key < b.key ? -1 : 1
}

function rootBucket(key: string): string {
  return (parseInt(syncDigest(key).substring(0, 2), 16) & 63).toString(16).padStart(2, '0')
}

function shardBody(id: string, facts: SyncFact[]): string {
  return JSON.stringify({ dataset: id, schema: 1, facts })
}

interface WireShard {
  dataset: string
  schema: number
  facts: SyncFact[]
}

function splitBucket(id: string, root: string, prefix: string, facts: SyncFact[], epoch: number,
  old: Map<string, SyncShardRef>, result: SyncDataset): void {
  const body = shardBody(id, facts)
  const bytes = syncUtf8(body).byteLength
  if (bytes <= SYNC_MAX_OBJECT_BYTES) {
    const bucket = prefix.length === 0 ? root : `${root}-${prefix}`
    const hash = syncDigest(body)
    const cached = old.get(bucket)
    if (cached !== undefined && cached.hash === hash && cached.bytes === bytes) {
      result.ref.shards.push(cached)
    } else {
      const ref: SyncShardRef = { bucket, epoch, hash, bytes }
      result.ref.shards.push(ref)
      result.objects.push({ ref, body })
    }
    return
  }
  if (facts.length === 1 || prefix.length >= 64) throw new Error('sync_record_too_large')
  const children = new Map<string, SyncFact[]>()
  facts.forEach((fact: SyncFact): void => {
    const next = syncDigest(fact.key).charAt(prefix.length)
    const bucket = children.get(next)
    if (bucket === undefined) children.set(next, [fact])
    else bucket.push(fact)
  })
  Array.from(children.keys()).sort().forEach((next: string): void => {
    splitBucket(id, root, prefix + next, children.get(next) ?? [], epoch, old, result)
  })
}

export function buildSyncDataset(id: string, facts: SyncFact[], epoch: number, previous: SyncDatasetRef | undefined,
  bucketKey: (key: string) => string): SyncDataset {
  const roots = new Map<string, SyncFact[]>()
  const old = new Map<string, SyncShardRef>()
  previous?.shards.forEach((shard: SyncShardRef): void => { old.set(shard.bucket, shard) })
  facts.map(checkedSyncFact).sort(compareKey).forEach((fact: SyncFact): void => {
    const key = rootBucket(bucketKey(fact.key))
    const rows = roots.get(key)
    if (rows === undefined) roots.set(key, [fact])
    else rows.push(fact)
  })
  const result: SyncDataset = { ref: { id, schema: 1, shards: [] }, objects: [] }
  Array.from(roots.keys()).sort().forEach((key: string): void => {
    splitBucket(id, key, '', roots.get(key) ?? [], epoch, old, result)
  })
  return result
}

export function decodeSyncShard(id: string, ref: SyncShardRef, body: string,
  bucketKey: (key: string) => string): SyncFact[] {
  if (syncUtf8(body).byteLength !== ref.bytes || syncDigest(body) !== ref.hash) {
    throw new Error('sync_shard_damaged')
  }
  const shard = JSON.parse(body) as WireShard
  if (!shard || shard.dataset !== id || shard.schema !== 1 || !Array.isArray(shard.facts) ||
    Object.keys(shard).sort().join(',') !== 'dataset,facts,schema') throw new Error('sync_update_required')
  const parts = ref.bucket.split('-')
  const ids = new Set<string>()
  return shard.facts.map((raw: SyncFact): SyncFact => {
    const fact = checkedSyncFact(raw)
    if (ids.has(fact.key) || rootBucket(bucketKey(fact.key)) !== parts[0] ||
      (parts.length > 1 && !syncDigest(fact.key).startsWith(parts[1]))) throw new Error('sync_invalid_bucket')
    ids.add(fact.key)
    return fact
  })
}
