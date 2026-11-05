import { copySyncManifest, decodeSyncManifest, syncDigest, syncUtf8, SyncDatasetRef, SyncManifest, SYNC_MAX_OBJECT_BYTES } from './DeviceSyncWire'

export const SYNC_COMMIT_NAME = /^commit-([0-9a-f]{64})\.json$/

export interface SyncJournalCommit {
  format: 'KOMA_DEVICE_SYNC_COMMIT'
  schema: number
  parents: string[]
  manifest: SyncManifest
}

export function syncCommitBody(manifest: SyncManifest, parents: string[]): string {
  const commit: SyncJournalCommit = { format: 'KOMA_DEVICE_SYNC_COMMIT', schema: 1,
    parents: Array.from(new Set<string>(parents)).sort(), manifest }
  const body = JSON.stringify(commit)
  if (syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES) throw new Error('sync_manifest_too_large')
  // A union of individually valid branches can exceed a structural limit.
  // Reject it before PUT; an immutable invalid commit must never poison the directory.
  try {
    decodeSyncCommit(syncCommitName(body), body)
  } catch (error) {
    if ((error as Error).message === 'sync_invalid_datasets') throw new Error('sync_manifest_too_large')
    throw error as Error
  }
  return body
}

export function syncCommitName(body: string): string {
  return 'commit-' + syncDigest(body) + '.json'
}

export function decodeSyncCommit(name: string, body: string): SyncJournalCommit {
  if (!SYNC_COMMIT_NAME.test(name) || syncCommitName(body) !== name) throw new Error('sync_invalid_commit')
  let commit: SyncJournalCommit
  try { commit = JSON.parse(body) as SyncJournalCommit } catch (_error) { throw new Error('sync_invalid_commit') }
  if (!commit || commit.format !== 'KOMA_DEVICE_SYNC_COMMIT' || commit.schema !== 1 ||
    !Array.isArray(commit.parents) || commit.parents.length > 4096 ||
    commit.parents.some((parent: string): boolean => typeof parent !== 'string' || !SYNC_COMMIT_NAME.test(parent) || parent === name) ||
    new Set<string>(commit.parents).size !== commit.parents.length) throw new Error('sync_invalid_commit')
  commit.manifest = decodeSyncManifest(JSON.stringify(commit.manifest))
  if (commit.manifest.schema !== 2 || commit.manifest.maintenance) throw new Error('sync_invalid_commit')
  return commit
}

/** A parent is fully retained, including opaque refs for groups disabled on this device.
 * No shared mutable head, server ETag or LOCK is used as the publication authority.
 * Never apply the v1 single-head collector here: other branches and late PUTs remain valid.
 */
export function mergeSyncJournal(heads: SyncJournalCommit[], space: string): SyncManifest {
  if (heads.length === 0) throw new Error('sync_invalid_commit')
  if (heads.length === 1) return copySyncManifest(heads[0].manifest, space)
  const refs = new Map<string, SyncDatasetRef>()
  let revision = 1
  let epoch = 1
  heads.forEach((commit: SyncJournalCommit): void => {
    const manifest = commit.manifest
    revision = Math.max(revision, manifest.revision)
    epoch = Math.max(epoch, manifest.epoch)
    manifest.datasets.concat(manifest.alternatives ?? []).forEach((ref: SyncDatasetRef): void => {
      refs.set(ref.id + ':' + syncDigest(JSON.stringify(ref)), ref)
    })
  })
  const datasets: SyncDatasetRef[] = []
  const alternatives: SyncDatasetRef[] = []
  const ids = new Set<string>()
  Array.from(refs.keys()).sort().forEach((key: string): void => {
    const ref = refs.get(key)!
    if (ids.has(ref.id)) alternatives.push(ref)
    else { datasets.push(ref); ids.add(ref.id) }
  })
  return { format: 'KOMA_DEVICE_SYNC', schema: 2, minWriter: 2, space, revision, epoch,
    maintenance: false, datasets, previous: [], alternatives }
}
