import { fileIo as fs } from '@kit.CoreFileKit'
import { asset } from '@kit.AssetStoreKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'
import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { isSyncReplica, SyncEditKind, SyncFact, SyncGroup, SyncVersion } from './DeviceSyncFacts'
import { canonicalSyncDirectory, SyncConnectionDraft } from './DeviceSyncWebDav'
import { syncUtf8 } from './DeviceSyncWire'
import { SyncReadingActionCapture, SyncReadingCapture } from './DeviceSyncSignals'

export interface SyncLocalValue {
  key: string
  value: string
}

export interface SyncLocalSnapshot {
  values: SyncLocalValue[]
  revision: string
  skipped: number
  protectedKeys?: string[]
  restoreEdits?: SyncRestoreEdit[]
}

export interface SyncRestoreEdit {
  key: string
  value: string
  kind: SyncEditKind
  observed?: SyncVersion[]
}

export interface SyncReadingReceipt {
  key: string
  id: string
  version?: SyncVersion
}

export interface SyncReadingRestoreCandidate {
  space: string
  positions: SyncReadingCapture[]
  actions: SyncReadingActionCapture[]
}

export interface SyncPendingEdit {
  key: string
  version: SyncVersion
}

export interface SyncGroupState {
  id: SyncGroup
  facts: SyncFact[]
  baseline: SyncLocalValue[]
  pending: SyncPendingEdit[]
  deferred?: string[]
}

export interface SyncSavedConnection {
  credential: string
  endpointIdentity: string
  space: string
  revision: number
  manifestHash: string
  selected: SyncGroup[]
  automatic: boolean
  reviewRequired: boolean
  restoreReview?: boolean
  lastSuccess: number
  lastError: string
  groups: SyncGroupState[]
}

export interface SyncStoredApplyGroup {
  group: SyncGroup
  changes: SyncLocalValue[]
}

export interface SyncCommitIntent {
  connection: SyncSavedConnection
  expected: string
  sent: boolean
  detached?: boolean
  groupRevisions: SyncOwnerRevision[]
  applies: SyncStoredApplyGroup[]
}

export interface SyncOwnerRevision {
  group: SyncGroup
  revision: string
}

export interface SyncProbeRecord {
  credential: string
  id: string
}

export interface SyncLocalDocument {
  schema: number
  replica: string
  counter: number
  active?: SyncSavedConnection
  intent?: SyncCommitIntent
  localReceipt?: string
  probes: SyncProbeRecord[]
  archives?: SyncSavedConnection[]
  archivedIntents?: SyncCommitIntent[]
  retiredCredentials?: string[]
  readingReceipts?: SyncReadingReceipt[]
  readingRestoreCandidates?: SyncReadingRestoreCandidate[]
}

export function copySyncConnection(value: SyncSavedConnection): SyncSavedConnection {
  return { credential: value.credential, endpointIdentity: value.endpointIdentity, space: value.space, revision: value.revision,
    manifestHash: value.manifestHash, selected: value.selected.slice(), automatic: value.automatic,
    reviewRequired: value.reviewRequired, restoreReview: value.restoreReview, lastSuccess: value.lastSuccess, lastError: value.lastError,
    groups: value.groups.slice() }
}

export class DeviceSyncStorage {
  private readonly path: string
  private current?: SyncLocalDocument

  constructor(filesDir: string) {
    this.path = filesDir + '/device-sync-state.v1.json'
  }

  load(): SyncLocalDocument {
    if (this.current !== undefined) return this.current
    if (!fs.accessSync(this.path)) {
      const created: SyncLocalDocument = { schema: 1, replica: util.generateRandomUUID(), counter: 0, probes: [] }
      this.current = created
      return created
    }
    const loaded = JSON.parse(fs.readTextSync(this.path, { encoding: 'utf-8' })) as SyncLocalDocument
    if (!loaded || loaded.schema !== 1 || !isSyncReplica(loaded.replica) ||
      !Number.isSafeInteger(loaded.counter) || loaded.counter < 0 || !Array.isArray(loaded.probes)) {
      throw new Error('sync_local_state_invalid')
    }
    this.current = loaded
    return loaded
  }

  update(change: (state: SyncLocalDocument) => void): void {
    const current = this.load()
    const state: SyncLocalDocument = { schema: current.schema, replica: current.replica, counter: current.counter,
      active: current.active === undefined ? undefined : copySyncConnection(current.active),
      intent: current.intent, probes: current.probes.slice(), localReceipt: current.localReceipt,
      archives: current.archives?.slice(), archivedIntents: current.archivedIntents?.slice(),
      retiredCredentials: current.retiredCredentials?.slice(), readingReceipts: current.readingReceipts?.slice(),
      readingRestoreCandidates: current.readingRestoreCandidates?.slice() }
    change(state)
    this.save(state)
  }

  save(value: SyncLocalDocument): void {
    writeAppTextFile(this.path, JSON.stringify(value))
    this.current = value
  }
}

function credentialQuery(ref: string): asset.AssetMap {
  if (!isSyncReplica(ref)) throw new Error('sync_invalid_credential')
  const query: asset.AssetMap = new Map()
  query.set(asset.Tag.ALIAS, syncUtf8('koma.device-sync.v1.' + ref))
  return query
}

export function checkedSyncDraft(draft: SyncConnectionDraft): SyncConnectionDraft {
  const directory = canonicalSyncDirectory(draft.directory)
  const username = draft.username.trim()
  if (username.includes(':') || /[\r\n\u0000]/.test(username) || (username.length === 0 && draft.password.length > 0)) {
    throw new Error('sync_invalid_username')
  }
  const result: SyncConnectionDraft = { directory, username, password: draft.password }
  if (syncUtf8(JSON.stringify(result)).byteLength > 1024) throw new Error('sync_credentials_too_long')
  return result
}

export async function writeSyncCredential(ref: string, draft: SyncConnectionDraft): Promise<void> {
  const payload = syncUtf8(JSON.stringify(checkedSyncDraft(draft)))
  const query = credentialQuery(ref)
  query.set(asset.Tag.SECRET, payload)
  query.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
  query.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
  try {
    await asset.add(query)
  } catch (_error) {
    throw new Error('sync_credential_write_failed')
  }
}

export async function readSyncCredential(ref: string): Promise<SyncConnectionDraft> {
  try {
    const query = credentialQuery(ref)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    query.set(asset.Tag.RETURN_LIMIT, 1)
    const rows = await asset.query(query)
    const payload = rows[0]?.get(asset.Tag.SECRET) as Uint8Array | undefined
    if (payload === undefined) throw new Error('sync_credential_missing')
    const json = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(payload)
    return checkedSyncDraft(JSON.parse(json) as SyncConnectionDraft)
  } catch (_error) {
    throw new Error('sync_credential_read_failed')
  }
}

export async function clearSyncCredential(ref: string): Promise<void> {
  try {
    await asset.remove(credentialQuery(ref))
  } catch (error) {
    if ((error as BusinessError).code !== 24000002) throw new Error('sync_credential_remove_failed')
  }
}
