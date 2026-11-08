import { taskpool, util } from '@kit.ArkTS'
import {
  applySyncEdit, emptySyncFact, mergeSyncFacts, syncObserves, syncVisibleHeads, syncVisibleValue, SyncEdit,
  SyncEditKind, SyncFact, SyncGroup, SyncVersion, SYNC_GROUPS,
} from './DeviceSyncFacts'
import { checkSyncGroupFact, SyncRecentValue, SyncWorkLabel, syncBucketKey, syncBusinessKey, syncGroupVisibleValue, syncKey, syncKeyParts,
  SYNC_SHELF_DATASET, syncShelfMove } from './DeviceSyncData'
import {
  decodeSyncShard, syncDatasetBytes, syncDigest, syncShardPath, syncDatasetBranches,
  SyncDatasetRef, SyncManifest, SyncShardRef, SYNC_MAX_ROUND_BYTES,
} from './DeviceSyncWire'
import {
  DeviceSyncStorage, SyncCommitIntent, SyncGroupState, SyncLocalDocument, SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision,
  SyncPendingEdit, SyncProbeRecord, SyncReadingReceipt, SyncRestoreEdit, SyncSavedConfiguration, SyncSavedConnection, checkedSyncDraft, copySyncConnection,
  readSyncCredential, writeSyncCredential, clearSyncCredential,
} from './DeviceSyncStorage'
import { DeviceSyncWebDav, SyncConnectionDraft, SyncRemoteManifest, SyncRequestGuard } from './DeviceSyncWebDav'
import { DeviceSyncOwner, SyncApplyGroup } from './DeviceSyncOwner'
import {
  byLocalValue, bySyncFact, coverDatasetId, dependsOnConflict, hasLegacyRetainedDeletion,
  isCoverKey, isShelfBook, localValueRows, planDeviceSync,
  PreparedGroup, priorConflictRoots, ProposedSync, replaceGroup, restorableEdits, sameShelfBook, shelfMoveValue,
  SyncMergeChoice, SyncPlanTransport, usesReadingTime, writeDatasetId, writeDatasetIds,
} from './DeviceSyncPlanner'

export { SyncMergeChoice } from './DeviceSyncPlanner'

export interface DeviceSyncLocalEdit {
  key: string
  kind: SyncEditKind
  value: string
  observed?: SyncVersion[]
}

interface SyncLocalEditChange {
  apply: (state: SyncLocalDocument) => void
  version?: SyncVersion
}

export interface SyncMergeConflict {
  group: SyncGroup
  key: string
  local: string
  remote: string
  deleted: boolean
  label?: string
  retainLocalOnDelete?: boolean
}

export interface SyncPreviewGroup {
  group: SyncGroup
  upload: number
  download: number
  remove: number
  skipped: number
  readingOutsideScope?: number
  deferred?: number
  retained?: number
  dependent: SyncPreviewEffect[]
}

export interface SyncPreviewEffect {
  action: 'upload' | 'download' | 'remove'
  choices: string[]
}

export interface SyncPreviewRemoval {
  group: SyncGroup
  key: string
  value: string
  label?: string
  choices: string[]
  target?: 'local' | 'remote'
}

export interface SyncReviewPermit {
  generation: number
  review: number
}

export interface SyncPreview {
  token: string
  destination?: string
  groups: SyncPreviewGroup[]
  conflicts: SyncMergeConflict[]
  removals: SyncPreviewRemoval[]
  freshConnection: boolean
  categories: string[]
  beforeRestore: SyncMergeConflict[]
  earlierUnconfirmed: number
  migration?: boolean
}

export interface SyncReadingRound {
  uploaded: number
  downloaded: number
  pending: number
}

interface PreparedSync {
  preview: SyncPreview
  generation: number
  counter: number
  draft: SyncConnectionDraft
  connection?: SyncSavedConnection
  remote: SyncRemoteManifest
  selected: SyncGroup[]
  groups: PreparedGroup[]
  reviewGeneration: number
  activate: boolean
  credential?: string
}

interface DatasetCache {
  path: string
  data: SyncFact[]
  bytes: number
}

interface CheckedPlan {
  plan?: ProposedSync
  error?: string
}

@Concurrent
function prepareSyncPlan(prepared: PreparedGroup[], existing: SyncManifest | undefined, choices: SyncMergeChoice[],
  space: string, replica: string, counter: number, transport: SyncPlanTransport): CheckedPlan {
  try {
    return { plan: planDeviceSync(prepared, existing, choices, space, false, replica, counter, transport) }
  } catch (error) {
    return { error: (error as Error).message }
  }
}

interface CheckedShard {
  data?: SyncFact[]
  error?: string
}

const DEFAULT_GROUPS: SyncGroup[] = ['shelf', 'reading']

function groupDatasets(manifest: SyncManifest | undefined, group: SyncGroup): SyncDatasetRef[] {
  const refs = syncDatasetBranches(manifest, writeDatasetId(group))
  // Older clients still read their own dataset IDs. Never write records that
  // they cannot decode into those datasets.
  return refs.concat(syncDatasetBranches(manifest, group),
    group === 'shelf' ? syncDatasetBranches(manifest, SYNC_SHELF_DATASET) : [])
}

function selectedDatasetIds(groups: SyncGroup[]): string[] {
  const ids: string[] = groups.slice()
  groups.forEach((group: SyncGroup): void => { ids.push(...writeDatasetIds(group)) })
  if (groups.includes('shelf')) ids.push(SYNC_SHELF_DATASET)
  return ids
}

function businessFact(group: SyncGroup, fact: SyncFact): SyncFact {
  if (group !== 'source-subscriptions') return fact
  const key = syncBusinessKey(group, fact.key)
  return key === fact.key ? fact : { key, seen: fact.seen, values: fact.values, barriers: fact.barriers, cleared: fact.cleared }
}

@Concurrent
function validateSyncShard(group: SyncGroup, datasetId: string, ref: SyncShardRef, body: string, cover: boolean): CheckedShard {
  try {
    const data = decodeSyncShard(datasetId, ref, body, syncBucketKey)
    for (const fact of data) {
      if (fact.key.startsWith('["cover",') !== cover) throw new Error('sync_update_required')
      checkSyncGroupFact(group, fact, datasetId === 'shelf')
    }
    return { data }
  } catch (error) {
    return { error: (error as Error).message }
  }
}

function businessGroup(row: SyncGroupState | undefined): SyncGroupState | undefined {
  if (row === undefined || (row.id !== 'source-subscriptions' && row.id !== 'search-history')) return row
  return { id: row.id, facts: mergeSyncFacts([], row.facts.map((fact: SyncFact): SyncFact => businessFact(row.id, fact))),
    baseline: row.baseline.map((item: SyncLocalValue): SyncLocalValue =>
      ({ key: syncBusinessKey(row.id, item.key), value: item.value })),
    pending: row.pending.map((item: SyncPendingEdit): SyncPendingEdit =>
      ({ key: syncBusinessKey(row.id, item.key), version: item.version })),
    deferred: row.deferred?.map((key: string): string => syncBusinessKey(row.id, key)),
    deferredRoots: row.deferredRoots?.map((key: string): string => syncBusinessKey(row.id, key)) }
}

function selectedGroups(groups: SyncGroup[]): SyncGroup[] {
  return SYNC_GROUPS.filter((group: SyncGroup): boolean => groups.includes(group))
}

export function syncRequiresExplicitReview(value: SyncSavedConnection | undefined): boolean {
  if (value === undefined || !value.reviewRequired) return false
  if (value.requiresExplicitReview !== undefined) return value.requiresExplicitReview
  return value.restoreReview === true || value.lastError === 'sync_remote_committed_locally_changed' ||
    !value.groups.some((row: SyncGroupState): boolean => (row.deferred?.length ?? 0) > 0)
}

function applyReceiptBaselines(groups: SyncGroupState[], applies: SyncApplyGroup[]): SyncGroupState[] {
  return groups.map((group: SyncGroupState): SyncGroupState => {
    const changes = applies.find((value: SyncApplyGroup): boolean => value.group === group.id)?.changes
    if (changes === undefined || changes.length === 0) return group
    const baseline = byLocalValue(group.baseline)
    changes.forEach((change: SyncLocalValue): void => {
      if (shelfMoveValue(group.id, change.key, change.value)) {
        // A received move is never a local favorite. Even if the owner keeps
        // it because of a local note, this receipt cannot turn its later
        // absence into a separate delete of a newer remote re-add.
        baseline.delete(change.key)
        baseline.forEach((_value: string, key: string): void => {
          if (dependsOnConflict(key, change.key)) baseline.delete(key)
        })
        return
      }
      if (change.value === '') baseline.delete(change.key)
      else baseline.set(change.key, change.value)
    })
    return { id: group.id, facts: group.facts, pending: group.pending, baseline: localValueRows(baseline),
      deferred: group.deferred, deferredRoots: group.deferredRoots }
  })
}

function endpointIdentity(draft: SyncConnectionDraft): string {
  return syncDigest(JSON.stringify([draft.directory, draft.username]))
}

function sameConnection(a: SyncConnectionDraft, b: SyncConnectionDraft): boolean {
  return a.directory === b.directory && a.username === b.username
}

function detachedIntent(intent: SyncCommitIntent, state: SyncLocalDocument): SyncCommitIntent {
  if (intent.sent && intent.commit?.startsWith((state.publicationWriter ?? state.replica) + '/')) {
    // A revoked scope seals an in-flight writer. The old PUT may still arrive.
    // A new writer keeps it independently visible and never reuses its sequence.
    state.publicationWriter = util.generateRandomUUID()
  }
  return { connection: intent.connection, expected: intent.expected, sent: intent.sent, detached: true,
    groupRevisions: intent.groupRevisions, applies: intent.applies, commit: intent.commit, commitBody: intent.commitBody,
    writtenDatasets: intent.writtenDatasets }
}

export class DeviceSyncEngine {
  private readonly storage: DeviceSyncStorage
  private readonly owner: DeviceSyncOwner
  private generation: number = 0
  private reviewGeneration: number = 0
  private probeGeneration: number = 0
  private prepared?: PreparedSync
  private running?: Promise<void>
  lastReadingRound?: SyncReadingRound
  private appliedRemoteTag: string = ''
  private cache: DatasetCache[] = []
  private cacheSize: number = 0
  private restoreInProgress: boolean = false
  private tested?: SyncConnectionDraft
  private restoreBefore?: SyncSavedConnection
  private restoreBeforeIntent?: SyncCommitIntent
  private restoreBeforeConfiguration?: SyncSavedConfiguration
  private readonly groupEpochs: Map<SyncGroup, number> = new Map()

  constructor(storage: DeviceSyncStorage, owner: DeviceSyncOwner) {
    this.storage = storage
    this.owner = owner
  }

  active(): SyncSavedConnection | undefined {
    return this.storage.load().active
  }

  configuration(): SyncSavedConfiguration | SyncSavedConnection | undefined {
    const state = this.storage.load()
    // A pre-redesign first merge may have a durable accepted intent but no
    // active receipt yet. Keep its existing recovery permission, not a new form.
    return state.pendingConfiguration ?? state.active ??
      (state.intent !== undefined && !state.intent.detached ? state.intent.connection : undefined)
  }

  hasUnresolvedCommit(): boolean {
    const intent = this.storage.load().intent
    return intent !== undefined && !intent.detached
  }

  selection(): SyncGroup[] {
    const groups = this.storage.load().syncContents ?? this.configuration()?.selected ?? DEFAULT_GROUPS
    return selectedGroups(groups)
  }

  async connectionDraft(): Promise<SyncConnectionDraft | undefined> {
    const configuration = this.configuration()
    return configuration === undefined ? undefined : readSyncCredential(configuration.credential)
  }

  private guard(expected: number): SyncRequestGuard {
    return (): void => {
      if (this.generation !== expected || this.restoreInProgress) throw new Error('sync_connection_changed')
    }
  }

  isEnabled(): boolean { return this.configuration()?.enabled !== false }

  private requireEnabled(): void {
    if (!this.isEnabled()) throw new Error('sync_service_disabled')
  }

  private transferGuard(expected: number): SyncRequestGuard {
    const generationGuard = this.guard(expected)
    return (): void => { generationGuard(); this.requireEnabled() }
  }

  requestGuard(): SyncRequestGuard { return this.transferGuard(this.generation) }

  // UI error ownership only: this guard grants no permission to send requests.
  stateGuard(): SyncRequestGuard { return this.guard(this.generation) }

  setEnabled(value: boolean): void {
    const pending = this.storage.load().pendingConfiguration
    if (pending !== undefined) {
      if (pending.enabled === value) return
      this.storage.update((state: SyncLocalDocument): void => {
        if (state.pendingConfiguration !== undefined) state.pendingConfiguration.enabled = value
      })
      this.generation++
      this.prepared = undefined
      return
    }
    if (this.active() === undefined) {
      const configuration = this.configuration()
      if (configuration === undefined || this.isEnabled() === value) return
      this.storage.update((state: SyncLocalDocument): void => {
        state.pendingConfiguration = { credential: configuration.credential, endpointIdentity: configuration.endpointIdentity,
          selected: configuration.selected.slice(), automatic: configuration.automatic, enabled: value }
      })
      this.generation++
      this.prepared = undefined
      return
    }
    if (this.isEnabled() === value) return
    this.storage.update((state: SyncLocalDocument): void => {
      if (state.active !== undefined) state.active.enabled = value
    })
    // Stop transfer callbacks, not local observation: paused deletes and unread
    // actions keep their original scope and cannot resurrect after resuming.
    this.generation++
    this.prepared = undefined
  }

  async testConnection(raw: SyncConnectionDraft, _input: SyncGroup[] = []): Promise<boolean> {
    const draft = checkedSyncDraft(raw)
    this.tested = undefined
    const generationGuard = this.guard(this.generation)
    const probe = ++this.probeGeneration
    const guard = (): void => {
      generationGuard()
      if (this.probeGeneration !== probe) throw new Error('sync_connection_changed')
    }
    const credential = util.generateRandomUUID()
    const id = util.generateRandomUUID()
    this.storage.update((state: SyncLocalDocument): void => { state.probes.push({ credential, id, collection: 2 }) })
    await writeSyncCredential(credential, draft)
    guard()
    const provider = new DeviceSyncWebDav(draft)
    try {
      await provider.probe(id, guard)
      await this.retireProbe(credential)
      this.tested = draft
    } catch (error) {
      // The old endpoint and exact probe path remain in private storage until cleanup succeeds.
      throw error as Error
    }
    // A connection test authorizes only the synthetic probe, even when these
    // credentials match an unacknowledged data commit. Recover that exact
    // commit only through an explicit sync/review action or enabled scheduling.
    return false
  }

  cancelConnectionTest(): void { this.probeGeneration++; this.tested = undefined }

  async saveConfiguration(raw: SyncConnectionDraft): Promise<void> {
    const draft = checkedSyncDraft(raw)
    const guard = this.guard(this.generation)
    if (this.tested === undefined || !sameConnection(this.tested, draft) || this.tested.password !== draft.password) {
      await this.testConnection(draft)
    }
    guard()
    const credential = util.generateRandomUUID()
    this.rememberRetired(credential)
    try {
      await writeSyncCredential(credential, draft)
      guard()
      const endpoint = endpointIdentity(draft)
      const previous = this.configuration()
      const previousCredential = previous?.credential
      const selected = this.selection()
      this.storage.update((state: SyncLocalDocument): void => {
        state.syncContents = selected.slice()
        if (previous?.endpointIdentity === endpoint) {
          if (state.pendingConfiguration !== undefined) state.pendingConfiguration.credential = credential
          else if (state.active !== undefined) state.active.credential = credential
          else {
            state.pendingConfiguration = { credential, endpointIdentity: endpoint, selected: previous.selected.slice(),
              automatic: previous.automatic, enabled: previous.enabled !== false }
          }
        } else {
          if (state.active !== undefined) {
            const archive = copySyncConnection(state.active)
            archive.credential = ''
            archive.automatic = false
            state.archives = (state.archives ?? []).filter((item: SyncSavedConnection): boolean =>
              item.endpointIdentity !== archive.endpointIdentity).concat(archive)
          }
          state.active = undefined
          if (state.intent !== undefined) state.intent = detachedIntent(state.intent, state)
          state.pendingConfiguration = { credential, endpointIdentity: endpoint, selected: selected.slice(),
            automatic: true, enabled: false }
        }
        state.retiredCredentials = state.retiredCredentials?.filter((ref: string): boolean => ref !== credential)
        if (previousCredential !== undefined && previousCredential !== credential) {
          state.retiredCredentials = (state.retiredCredentials ?? []).concat(previousCredential)
        }
      })
      // Validation and AssetStore preparation precede this commit point. Only
      // successful persistence replaces the endpoint and invalidates old work.
      this.generation++
      this.prepared = undefined
      SYNC_GROUPS.forEach((group: SyncGroup): void => { this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1) })
      if (previousCredential !== undefined) await this.removeUnusedCredential(previousCredential).catch((): void => {})
    } catch (error) {
      await this.removeUnusedCredential(credential).catch((): void => {})
      throw error as Error
    }
  }

  beginReview(): SyncReviewPermit { return { generation: this.generation, review: ++this.reviewGeneration } }

  reviewRequestGuard(permit: SyncReviewPermit): SyncRequestGuard {
    return this.reviewGuard(permit.generation, permit.review, true)
  }

  async prepareSaved(input: SyncGroup[], permit: SyncReviewPermit = this.beginReview()): Promise<SyncPreview> {
    if (this.hasUnresolvedCommit()) throw new Error('sync_remote_result_unknown')
    // Bind cancellation before AssetStore can yield. A Back during this read
    // must not let the late continuation manufacture a new review permission.
    const guard = this.reviewRequestGuard(permit)
    guard()
    const draft = await this.connectionDraft()
    guard()
    if (draft === undefined) throw new Error('sync_not_configured')
    return this.prepare(draft, input, true, permit.review)
  }

  private reviewGuard(generation: number, review: number, activate: boolean): SyncRequestGuard {
    const guard = activate ? this.guard(generation) : this.transferGuard(generation)
    return (): void => {
      guard()
      if (this.reviewGeneration !== review) throw new Error('sync_preview_changed')
    }
  }

  async cleanProbes(): Promise<void> {
    if (!this.isEnabled()) return
    const guard = this.guard(this.generation)
    const retired = this.storage.load().retiredCredentials ?? []
    for (const ref of retired) {
      try {
        await this.removeUnusedCredential(ref)
      } catch (_error) {
      }
    }
    for (const row of this.storage.load().probes) {
      try {
        const provider = new DeviceSyncWebDav(await readSyncCredential(row.credential))
        await provider.cleanProbe(row.id, guard, row.collection !== 2)
        await this.retireProbe(row.credential)
      } catch (_error) {
      }
    }
  }

  private async retireProbe(credential: string): Promise<void> {
    await clearSyncCredential(credential)
    this.storage.update((state: SyncLocalDocument): void => {
      state.probes = state.probes.filter((row: SyncProbeRecord): boolean => row.credential !== credential)
    })
  }

  async prepare(raw: SyncConnectionDraft, input: SyncGroup[], savedReview: boolean = false, reviewPermit?: number): Promise<SyncPreview> {
    if (reviewPermit !== undefined && reviewPermit !== this.reviewGeneration) throw new Error('sync_preview_changed')
    this.prepared = undefined
    const draft = checkedSyncDraft(raw)
    const configuration = this.configuration()
    const activate = savedReview && configuration?.endpointIdentity === endpointIdentity(draft) &&
      (this.storage.load().pendingConfiguration !== undefined || syncRequiresExplicitReview(this.active()))
    if (!activate) this.requireEnabled()
    const selected = selectedGroups(input)
    if (selected.length === 0) throw new Error('sync_select_contents')
    const generation = this.generation
    const counter = this.storage.load().counter
    const review = reviewPermit ?? ++this.reviewGeneration
    const guard = this.reviewGuard(generation, review, activate)
    const connection = this.active()
    const saved = connection === undefined ? undefined : await this.connectionDraft()
    const archived = this.storage.load().archives?.find((entry: SyncSavedConnection): boolean =>
      entry.endpointIdentity === endpointIdentity(draft))
    const existing = connection !== undefined && saved !== undefined && sameConnection(draft, saved) ? connection : archived
    if (!(savedReview && configuration?.endpointIdentity === endpointIdentity(draft)) &&
      (existing === undefined || existing.credential === '') && (this.tested === undefined || !sameConnection(draft, this.tested) ||
      draft.password !== this.tested.password)) throw new Error('sync_test_required')
    this.cache = []
    this.cacheSize = 0
    const provider = new DeviceSyncWebDav(draft, existing?.frontier, existing?.space, this.publicationWriter())
    const remote = await provider.readManifest(guard)
    this.checkHighWater(existing, remote)
    if (remote.manifest?.maintenance === true) throw new Error('sync_maintenance_running')
    const groups = await this.prepareGroups(provider, selected, existing, remote.manifest, guard, true, remote)
    const preview = this.summarize(groups, existing === undefined)
    preview.destination = draft.directory + (draft.username ? '\n' + draft.username : '')
    preview.migration = remote.legacyHash !== undefined || (existing !== undefined && existing.frontier === undefined)
    if (remote.manifest !== undefined) {
      preview.earlierUnconfirmed = this.unconfirmedFromEarlierConnection(
        endpointIdentity(draft), remote.manifest.space, groups)
    }
    guard()
    if (this.storage.load().counter !== counter) throw new Error('sync_preview_changed')
    const prepared: PreparedSync = { preview, generation, counter, draft, connection: existing, remote, selected, groups,
      reviewGeneration: review, activate,
      credential: savedReview && configuration?.endpointIdentity === endpointIdentity(draft) ? configuration.credential : undefined }
    prepared.preview = this.projectPreview(prepared, [])
    this.prepared = prepared
    return prepared.preview
  }

  previewChoices(token: string, choices: SyncMergeChoice[]): SyncPreview {
    const prepared = this.prepared
    if (prepared === undefined || prepared.preview.token !== token || this.storage.load().counter !== prepared.counter) {
      throw new Error('sync_preview_changed')
    }
    this.reviewGuard(prepared.generation, prepared.reviewGeneration, prepared.activate)()
    prepared.preview = this.projectPreview(prepared, choices)
    return prepared.preview
  }

  private projectPreview(prepared: PreparedSync, choices: SyncMergeChoice[]): SyncPreview {
    // Read the same in-memory merge plan used by confirm. This projection skips
    // shard encoding/hashing and never allocates durable operation versions.
    const space = prepared.remote.manifest?.space ?? prepared.connection?.space ??
      new DeviceSyncWebDav(prepared.draft).spaceId()
    const state = this.storage.load()
    const plan = planDeviceSync(prepared.groups, prepared.remote.manifest, choices, space, true, state.replica, state.counter)
    const removals: SyncPreviewRemoval[] = []
    const groups = prepared.preview.groups.map((summary: SyncPreviewGroup): SyncPreviewGroup => {
      const input = prepared.groups.find((item: PreparedGroup): boolean => item.id === summary.group)
      const output = plan.groups.find((item: SyncGroupState): boolean => item.id === summary.group)
      if (input === undefined || output === undefined) return summary
      const remote = bySyncFact(input.remote)
      const local = byLocalValue(input.local.values)
      const before = byLocalValue(input.previous?.baseline ?? [])
      let upload = 0
      let download = 0
      let remove = 0
      let retained = 0
      const removed = (key: string, value: string, target: 'local' | 'remote'): void => {
        let label = input.local.labels?.[key]
        const parts = syncKeyParts(key)
        if (label === undefined && ['position', 'read', 'bookmark'].includes(parts[0])) {
          const recentKey = syncKey(['recent', parts[1], parts[2]])
          const recent = local.get(recentKey) ?? before.get(recentKey)
          if (recent !== undefined) {
            const metadata = JSON.parse(recent) as SyncRecentValue
            label = metadata.title + ' · ' + (metadata.chapter === parts[3] ? metadata.chapterTitle || parts[3] : parts[3])
          }
        }
        removals.push({ group: input.id, key, value, label, choices: [], target })
        remove++
      }
      output.facts.forEach((fact: SyncFact): void => {
        if (output.deferred?.includes(fact.key) || input.local.protectedKeys?.includes(fact.key)) return
        if (syncVisibleValue(fact) === undefined && local.has(fact.key) &&
          input.local.retainedDeletionKeys?.includes(fact.key)) retained++
        const prior = remote.get(fact.key)
        if (JSON.stringify(fact) === JSON.stringify(prior)) return
        const value = syncGroupVisibleValue(input.id, fact)
        const remoteValue = prior === undefined ? undefined : syncGroupVisibleValue(input.id, prior)
        if ((value === undefined || shelfMoveValue(input.id, fact.key, value)) &&
          remoteValue !== undefined && !shelfMoveValue(input.id, fact.key, remoteValue)) removed(fact.key, remoteValue, 'remote')
        else if (value !== undefined) upload++
      })
      const apply = plan.applies.find((item: SyncApplyGroup): boolean => item.group === input.id)
      apply?.changes.forEach((change: SyncLocalValue): void => {
        if (change.value === '' || shelfMoveValue(input.id, change.key, change.value)) {
          removed(change.key, local.get(change.key) ?? before.get(change.key) ?? '', 'local')
        }
        else download++
      })
      return { group: summary.group, upload, download, remove, skipped: summary.skipped,
        readingOutsideScope: summary.readingOutsideScope,
        deferred: output.deferredRoots?.length ?? 0, retained, dependent: summary.dependent }
    })
    return { token: prepared.preview.token, destination: prepared.preview.destination, groups, removals, conflicts: prepared.preview.conflicts,
      freshConnection: prepared.preview.freshConnection, categories: prepared.preview.categories,
      beforeRestore: prepared.preview.beforeRestore, earlierUnconfirmed: prepared.preview.earlierUnconfirmed,
      migration: prepared.preview.migration }
  }

  discardPreview(token?: string): void {
    if (token === undefined || this.prepared?.preview.token === token) {
      this.prepared = undefined
      this.reviewGeneration++
    }
  }

  confirm(token: string, choices: SyncMergeChoice[]): Promise<void> {
    if (this.running !== undefined) return Promise.reject(new Error('sync_already_running'))
    const prepared = this.prepared
    this.prepared = undefined
    if (prepared === undefined || prepared.preview.token !== token) return Promise.reject(new Error('sync_preview_changed'))
    return this.start((): Promise<void> => this.confirmPrepared(prepared, choices))
  }

  private async confirmPrepared(prepared: PreparedSync, choices: SyncMergeChoice[]): Promise<void> {
    if (!prepared.activate) this.requireEnabled()
    const guard = this.reviewGuard(prepared.generation, prepared.reviewGeneration, prepared.activate)
    const provider = new DeviceSyncWebDav(prepared.draft, prepared.connection?.frontier, prepared.connection?.space, this.publicationWriter())
    const current = await provider.readManifest(guard, prepared.remote.etag)
    if (current.etag !== prepared.remote.etag || current.hash !== prepared.remote.hash) {
      throw new Error('sync_preview_changed')
    }
    await this.assertRevisions(prepared.groups.map((row: PreparedGroup): SyncOwnerRevision => ({ group: row.id, revision: row.local.revision })))
    guard()
    const credential = prepared.credential ?? util.generateRandomUUID()
    if (prepared.credential === undefined) {
      this.rememberRetired(credential)
      await writeSyncCredential(credential, prepared.draft)
    }
    try {
      guard()
      if (this.storage.load().counter !== prepared.counter) throw new Error('sync_preview_changed')
      const proposal = await this.preparePlan(prepared.groups, current, choices, provider.spaceId(), guard)
      if (!current.writer && current.legacyHash !== undefined && !proposal.publish) {
        proposal.publish = true
        proposal.manifest.revision++
      }
      await this.execute(provider, prepared.connection, credential, prepared.selected, current, proposal, guard, true,
        endpointIdentity(prepared.draft), prepared.groups, prepared.activate)
    } catch (error) {
      await this.removeUnusedCredential(credential)
      throw error as Error
    }
  }

  syncNow(probeOnly: boolean = false): Promise<void> {
    if (this.running !== undefined) return this.running
    return this.start((): Promise<void> => this.runActive(probeOnly))
  }

  private start(work: () => Promise<void>): Promise<void> {
    const pending = work().finally((): void => { this.running = undefined })
    this.running = pending
    return pending
  }

  private async runActive(probeOnly: boolean): Promise<void> {
    this.lastReadingRound = undefined
    this.requireEnabled()
    await this.recoverIntent()
    const configured = this.configuration()
    if (configured === undefined || configured.selected.length === 0) throw new Error('sync_select_contents')
    const active = this.active()
    if (active?.restoreReview === true && syncRequiresExplicitReview(active)) throw new Error('sync_review_required')
    const connection = active ?? this.storage.load().archives?.find((item: SyncSavedConnection): boolean =>
      item.endpointIdentity === configured.endpointIdentity)
    const guard = this.transferGuard(this.generation)
    const draft = await readSyncCredential(configured.credential)
    guard()
    const provider = new DeviceSyncWebDav(draft, connection?.frontier, connection?.space, this.publicationWriter())
    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) await this.recoverIntent()
        let remote = await provider.readManifest(guard, '', probeOnly && attempt === 0)
        const appliedTag = JSON.stringify([configured.endpointIdentity, configured.selected, remote.etag, remote.hash])
        if (probeOnly && active !== undefined && !remote.warning && appliedTag === this.appliedRemoteTag &&
          !active.groups.some((group: SyncGroupState): boolean => configured.selected.includes(group.id) && group.pending.length > 0)) return
        this.checkHighWater(this.active(), remote)
        if (remote.manifest?.maintenance === true) remote = await this.finishMaintenance(provider, remote, guard)
        this.checkHighWater(this.active(), remote)
        await this.rememberRemote(provider.spaceId(), remote, guard)
        if (remote.manifest?.maintenance === true) throw new Error('sync_maintenance_running')
        const counter = this.storage.load().counter
        const groupErrors: string[] = []
        let groups = await this.prepareGroups(provider, configured.selected, this.active() ?? connection,
          remote.manifest, guard, true, remote, true, groupErrors)
        if (counter !== this.storage.load().counter) continue
        let proposal = await this.preparePlan(groups, remote, [], provider.spaceId(), guard)
        if (counter !== this.storage.load().counter) continue
        const rejected = new Set<SyncGroup>()
        for (const apply of proposal.applies) {
          try { await this.owner.validateChanges?.(apply) } catch (error) {
            guard()
            rejected.add(apply.group)
            groupErrors.push((error as Error).message)
          }
        }
        if (rejected.size > 0) {
          groups = groups.filter((row: PreparedGroup): boolean => !rejected.has(row.id))
          proposal = await this.preparePlan(groups, remote, [], provider.spaceId(), guard)
          if (counter !== this.storage.load().counter) continue
        }
        if (groups.length === 0 && groupErrors.length > 0) throw new Error(groupErrors[0])
        try {
          await this.execute(provider, this.active() ?? connection, configured.credential, configured.selected, remote,
            proposal, guard, false, configured.endpointIdentity, [], active === undefined)
          await this.maybeMaintain(provider, guard).catch((): void => {})
          if (remote.warning) throw new Error(remote.warning)
          if (groupErrors.length > 0) throw new Error('sync_partial:' + groupErrors[0])
          this.appliedRemoteTag = proposal.publish || groups.some((group: PreparedGroup): boolean =>
            group.coverUnavailable === true) ? '' : appliedTag
          return
        } catch (error) {
          if ((error as Error).message !== 'sync_remote_changed') throw error as Error
        }
      }
      throw new Error('sync_remote_changed')
    } catch (error) {
      guard()
      const active = this.active()
      if (active !== undefined) {
        await this.storage.updateInBackground((state: SyncLocalDocument): boolean => {
          if (state.active === undefined || state.active.lastError === (error as Error).message) return false
          state.active.lastError = (error as Error).message
          return true
        }, guard)
      }
      throw error as Error
    }
  }

  private checkHighWater(connection: SyncSavedConnection | undefined, remote: SyncRemoteManifest): void {
    if (connection === undefined || connection.revision === 0) return
    if (remote.journal) {
      // The provider directly GETs durable frontier witnesses. Concurrent DAG heads
      // may have equal/decreasing scalar revisions; those are not rollback evidence.
      if (connection.frontier !== undefined) return
      if (remote.legacyRevision === undefined) return // An explicit migration preview follows.
      if (remote.legacySpace !== connection.space || remote.legacyRevision < connection.revision ||
        (remote.legacyRevision === connection.revision && remote.legacyHash !== connection.manifestHash)) {
        throw new Error('sync_space_changed')
      }
      return
    }
    const manifest = remote.manifest
    if (manifest === undefined || manifest.space !== connection.space || manifest.revision < connection.revision ||
      (manifest.revision === connection.revision && remote.hash !== connection.manifestHash)) {
      throw new Error('sync_space_changed')
    }
  }

  private async loadDataset(provider: DeviceSyncWebDav, dataset: SyncDatasetRef,
    guard: SyncRequestGuard, id: SyncGroup): Promise<SyncFact[]> {
    if (dataset.schema !== 1) throw new Error('sync_update_required')
    const rows: SyncFact[] = []
    const keys = new Set<string>()
    for (const ref of dataset.shards) {
      const path = id + ':' + dataset.id + ':' + ref.bucket + ':' + ref.bytes + ':' + syncShardPath(ref)
      let cache = this.cache.find((item: DatasetCache): boolean => item.path === path)
      if (cache === undefined) {
        const body = await provider.readObject(ref, guard)
        const checked = await taskpool.execute(validateSyncShard, id, dataset.id, ref, body,
          dataset.id === coverDatasetId(id)) as CheckedShard
        guard()
        if (checked.data === undefined) throw new Error(checked.error ?? 'sync_shard_damaged')
        // The ref is content-addressed. Cached facts already passed wire,
        // group and cover checks; still check duplicates across current shards.
        cache = { path, data: checked.data, bytes: ref.bytes }
        this.cache.push(cache)
        this.cacheSize += ref.bytes
        while (this.cacheSize > 8 * 1024 * 1024 && this.cache.length > 1) {
          this.cacheSize -= this.cache.shift()?.bytes ?? 0
        }
      }
      for (const fact of cache.data) {
        if (keys.has(fact.key)) throw new Error('sync_duplicate_fact')
        keys.add(fact.key)
        rows.push(businessFact(id, fact))
      }
    }
    return mergeSyncFacts([], rows)
  }

  private damagedGroup(error: Error): boolean {
    return error.message === 'sync_shard_missing' || error.message === 'sync_shard_damaged'
  }

  private async loadGroup(provider: DeviceSyncWebDav, refs: SyncDatasetRef[], id: SyncGroup,
    guard: SyncRequestGuard): Promise<SyncFact[]> {
    let facts: SyncFact[] = []
    for (const ref of refs) facts = mergeSyncFacts(facts, await this.loadDataset(provider, ref, guard, id))
    return facts
  }

  private async prepareGroups(provider: DeviceSyncWebDav, selected: SyncGroup[], connection: SyncSavedConnection | undefined,
    manifest: SyncManifest | undefined, guard: SyncRequestGuard, verifyPublic: boolean, transport?: SyncRemoteManifest,
    automatic: boolean = false, groupErrors?: string[]): Promise<PreparedGroup[]> {
    let budget = SYNC_MAX_ROUND_BYTES
    const groups: PreparedGroup[] = []
    for (const id of selected) {
      const load = (refs: SyncDatasetRef[]): Promise<SyncFact[]> => {
        const bytes = refs.reduce((size: number, ref: SyncDatasetRef): number => size + syncDatasetBytes(ref), 0)
        if (bytes > budget) throw new Error('sync_round_too_large')
        budget -= bytes
        return this.loadGroup(provider, refs, id, guard)
      }
      try {
        const refs = groupDatasets(manifest, id)
        const local = await this.owner.snapshot(id, verifyPublic, guard, manifest?.space ?? connection?.space ?? '', !automatic)
        const previous = businessGroup(connection?.groups.find((row: SyncGroupState): boolean => row.id === id))
        let remote: SyncFact[]
        try { remote = await load(refs) } catch (error) {
          const failure = error as Error
          if (!automatic || groupErrors === undefined || !this.damagedGroup(failure) ||
            transport?.writerHeads === undefined) throw failure
          groupErrors.push(failure.message)
          // A receiver that has already applied this group keeps its durable
          // projection and pending edits. Only a fresh group needs a preview
          // of the last complete publication.
          if (previous !== undefined || local.values.some((item: SyncLocalValue): boolean =>
            local.unsetKeys?.includes(item.key) !== true)) continue
          let fallback = await load(groupDatasets(transport.old, id))
          let complete = true
          for (const writer of transport.writerHeads) {
            let contribution: SyncFact[] = []
            const currentRefs = groupDatasets(writer.manifest, id)
            try { contribution = await load(currentRefs) } catch (broken) {
              if (!this.damagedGroup(broken as Error)) throw broken as Error
              const tried = new Set<string>([JSON.stringify(currentRefs)])
              complete = await provider.readEarlierWriterGroup(writer, guard, async (candidate: SyncManifest): Promise<boolean> => {
                const older = groupDatasets(candidate, id)
                const signature = JSON.stringify(older)
                if (older.length === 0 || tried.has(signature)) return false
                tried.add(signature)
                try { contribution = await load(older); return true } catch (damage) {
                  if (!this.damagedGroup(damage as Error)) throw damage as Error
                  return false
                }
              })
              if (!complete) break
            }
            fallback = mergeSyncFacts(fallback, contribution)
          }
          guard()
          if (complete) groups.push({ id, local, remote: fallback, requiresPreview: false, resetBaseline: false,
            removed: [], degraded: true })
          continue
        }
        const requiresPreview = !automatic && (previous === undefined || connection?.credential === '' ||
          syncRequiresExplicitReview(connection) || !connection?.selected.includes(id))
        const removed = requiresPreview || previous === undefined ? [] : id === 'source-subscriptions' ?
          previous.baseline.filter((item: SyncLocalValue): boolean => !local.values.some((now: SyncLocalValue): boolean =>
            now.key === item.key)).map((item: SyncLocalValue): string => item.key) :
          await this.owner.removed(id, previous.baseline.map((value: SyncLocalValue): string => value.key))
        const ownRef = transport?.own?.datasets.find((dataset: SyncDatasetRef): boolean => dataset.id === writeDatasetId(id))
        let published = ownRef === undefined ? [] : await this.loadDataset(provider, ownRef, guard, id)
        let migrating: SyncFact[] = []
        for (const ref of groupDatasets(transport?.old, id)) {
          migrating = mergeSyncFacts(migrating, await this.loadDataset(provider, ref, guard, id))
        }
        let coverUnavailable = false
        const coverId = coverDatasetId(id)
        if (coverId !== '') {
          // Artwork is optional. An unreadable cover shard cannot interrupt
          // reading progress or shelf changes, or erase the writer's old ref.
          const savedBudget = budget
          try {
            const cover = await load(syncDatasetBranches(manifest, coverId))
            const ownCover = await this.loadGroup(provider, syncDatasetBranches(transport?.own, coverId), id, guard)
            const oldCover = await this.loadGroup(provider, syncDatasetBranches(transport?.old, coverId), id, guard)
            remote = mergeSyncFacts(remote, cover)
            published = mergeSyncFacts(published, ownCover)
            migrating = mergeSyncFacts(migrating, oldCover)
          } catch (_error) {
            guard()
            budget = savedBudget
            coverUnavailable = true
          }
        }
        guard()
        groups.push({ id, local, remote, previous, requiresPreview, resetBaseline: connection?.restoreReview === true,
          removed, published, migrating, coverUnavailable })
      } catch (error) {
        guard()
        if (groupErrors === undefined) throw error as Error
        groupErrors.push((error as Error).message)
      }
    }
    return groups
  }

  private summarize(groups: PreparedGroup[], fresh: boolean): SyncPreview {
    const conflicts: SyncMergeConflict[] = []
    const beforeRestore: SyncMergeConflict[] = []
    const categories: string[] = []
    const removals: SyncPreviewRemoval[] = []
    const summaries = groups.map((entry: PreparedGroup): SyncPreviewGroup => {
      let upload = 0
      let download = 0
      let remove = 0
      const dependent: SyncPreviewEffect[] = []
      const effects: SyncLocalValue[] = []
      const local = byLocalValue(entry.local.values)
      const remote = bySyncFact(entry.remote)
      const previous = priorConflictRoots(entry)
      const unresolved = previous.filter((key: string): boolean => !local.has(key) || entry.local.protectedKeys?.includes(key) === true)
      restorableEdits(entry.local).forEach((edit: SyncRestoreEdit): void => {
        if ((edit.bundle === undefined || syncKeyParts(edit.key)[0] === 'position') &&
          (edit.kind !== 'set' || edit.value !== local.get(edit.key))) {
          beforeRestore.push({ group: entry.id, key: edit.key, local: edit.followUp ?? edit.value,
            remote: local.get(edit.key) ?? '', deleted: edit.kind === 'delete' || edit.kind === 'clear-observed',
            label: edit.label ?? entry.local.labels?.[edit.key] })
        }
      })
      local.forEach((value: string, key: string): void => {
        if (isCoverKey(key) || entry.local.protectedKeys?.includes(key)) return
        const fact = remote.get(key)
        if (key.startsWith('["category",')) categories.push(JSON.parse(value) as string)
        if (fact === undefined) {
          effects.push({ key, value: 'upload' })
          return
        }
        const theirs = syncGroupVisibleValue(entry.id, fact)
        if (theirs === value || sameShelfBook(entry.id, key, value, theirs)) return
        const moving = shelfMoveValue(entry.id, key, theirs)
        const retainedDeletion = theirs === undefined && entry.local.retainedDeletionKeys?.includes(key) === true
        const unchangedRetainedValue = retainedDeletion && (entry.previous?.baseline.some((item: SyncLocalValue): boolean =>
          item.key === key && item.value === value) === true || hasLegacyRetainedDeletion(entry.local, entry.previous, key))
        const automaticReading = theirs !== undefined && usesReadingTime(entry, key)
        if (!automaticReading && (entry.requiresPreview || previous.includes(key) || unchangedRetainedValue)) {
          const label = entry.local.labels?.[key] ?? (theirs !== undefined && !moving && isShelfBook(entry.id, key) ?
            (JSON.parse(theirs) as SyncWorkLabel).title : undefined)
          conflicts.push({ group: entry.id, key, local: value,
            remote: moving ? '' : theirs ?? '', deleted: moving || theirs === undefined, label,
            retainLocalOnDelete: retainedDeletion })
          if (theirs !== undefined && !moving) unresolved.push(key)
          return
        }
        effects.push({ key, value: moving || theirs === undefined ? 'remove' : 'download' })
      })
      remote.forEach((fact: SyncFact, key: string): void => {
        if (isCoverKey(key)) return
        const value = syncGroupVisibleValue(entry.id, fact)
        if (!entry.local.protectedKeys?.includes(key) && !local.has(key) && value !== undefined &&
          !shelfMoveValue(entry.id, key, value)) {
          effects.push({ key, value: 'download' })
        }
      })
      effects.forEach((effect: SyncLocalValue): void => {
        if (unresolved.includes(effect.key)) return
        const choices = unresolved.filter((root: string): boolean => dependsOnConflict(effect.key, root))
        if (effect.value === 'remove') {
          removals.push({ group: entry.id, key: effect.key, value: local.get(effect.key) ?? '',
            label: entry.local.labels?.[effect.key], choices })
        }
        if (choices.length > 0) {
          dependent.push({ action: effect.value as 'upload' | 'download' | 'remove', choices })
        } else if (effect.value === 'upload') upload++
        else if (effect.value === 'download') download++
        else remove++
      })
      return { group: entry.id, upload, download, remove, skipped: entry.local.skipped,
        readingOutsideScope: entry.local.readingOutsideScope, dependent }
    })
    return { token: util.generateRandomUUID(), groups: summaries, conflicts, removals, freshConnection: fresh, categories, beforeRestore,
      earlierUnconfirmed: 0 }
  }

  private unconfirmedFromEarlierConnection(endpoint: string, space: string, groups: PreparedGroup[]): number {
    const state = this.storage.load()
    const earlier = (state.archivedIntents ?? []).slice()
    if (state.intent?.sent) earlier.push(state.intent)
    const remoteByGroup = new Map<SyncGroup, Map<string, SyncFact>>()
    groups.forEach((row: PreparedGroup): void => { remoteByGroup.set(row.id, bySyncFact(row.remote)) })
    let count = 0
    for (const intent of earlier) {
      if (intent.connection.endpointIdentity !== endpoint || intent.connection.space !== space) continue
      for (const group of intent.connection.groups) {
        const remote = remoteByGroup.get(group.id)
        for (const pending of group.pending) {
          const found = remote?.get(pending.key)
          if (found === undefined || !syncObserves(found.seen, pending.version)) count++
        }
      }
    }
    return count
  }

  private async preparePlan(groups: PreparedGroup[], remote: SyncRemoteManifest, choices: SyncMergeChoice[],
    space: string, guard: SyncRequestGuard): Promise<ProposedSync> {
    const state = this.storage.load()
    const transport: SyncPlanTransport = { writer: remote.writer, ownWritable: remote.ownWritable, own: remote.own }
    const checked = await taskpool.execute(prepareSyncPlan, groups, remote.manifest, choices,
      space, state.replica, state.counter, transport) as CheckedPlan
    guard()
    if (checked.plan === undefined) throw new Error(checked.error ?? 'sync_invalid_plan')
    return checked.plan
  }

  private async assertRevisions(revisions: SyncOwnerRevision[]): Promise<SyncLocalSnapshot[]> {
    const snapshots: SyncLocalSnapshot[] = []
    for (const item of revisions) {
      const snapshot = await this.owner.snapshot(item.group, false, undefined, undefined, false)
      if (snapshot.revision !== item.revision) throw new Error('sync_preview_changed')
      snapshots.push(snapshot)
    }
    return snapshots
  }

  private async execute(provider: DeviceSyncWebDav, prior: SyncSavedConnection | undefined, credential: string,
    selected: SyncGroup[], remote: SyncRemoteManifest, proposal: ProposedSync, guard: SyncRequestGuard,
    manualPreview: boolean, endpoint: string, reviewedGroups: PreparedGroup[] = [], activate: boolean = false): Promise<void> {
    let groups = prior?.groups.slice() ?? []
    proposal.groups.forEach((row: SyncGroupState): void => { groups = replaceGroup(groups, row) })
    const connection: SyncSavedConnection = {
      credential, endpointIdentity: endpoint, space: proposal.manifest.space, revision: proposal.manifest.revision,
      manifestHash: proposal.publish ? syncDigest(JSON.stringify(proposal.manifest)) : remote.hash,
      frontier: remote.frontier?.slice(),
      selected, automatic: prior?.automatic ?? false, reviewRequired: groups.some((group: SyncGroupState): boolean =>
        selected.includes(group.id) && (group.deferred?.length ?? 0) > 0),
      requiresExplicitReview: false, lastSuccess: prior?.lastSuccess ?? 0, lastError: '', groups,
      enabled: activate ? true : prior?.enabled ?? true,
    }
    guard()
    await this.storage.updateInBackground((state: SyncLocalDocument): boolean => {
      if (state.counter !== proposal.initialCounter) throw new Error('sync_preview_changed')
      state.counter = proposal.counter
      if (!manualPreview && state.active?.space === connection.space) {
        const active = state.active
        // Persist local observations separately from the proposed remote merge.
        // A conditional rejection or process exit must retain the original dots.
        proposal.staged.forEach((group: SyncGroupState): void => {
          active.groups = replaceGroup(active.groups, group)
        })
      }
      const detached = state.intent
      if (detached !== undefined && (detached.sent || detached.detached || detached.connection.endpointIdentity !== endpoint)) {
        const archived: SyncCommitIntent = { connection: copySyncConnection(detached.connection),
          expected: detached.expected, sent: detached.sent, detached: true,
          groupRevisions: detached.groupRevisions, applies: detached.applies, commit: detached.commit, commitBody: detached.commitBody,
          writtenDatasets: detached.writtenDatasets }
        archived.connection.credential = ''
        state.archivedIntents = (state.archivedIntents ?? []).filter((item: SyncCommitIntent): boolean =>
          item.connection.endpointIdentity !== detached.connection.endpointIdentity ||
          item.connection.space !== detached.connection.space ||
          item.connection.manifestHash !== detached.connection.manifestHash).concat(archived)
      }
      if (detached !== undefined && detached.connection.credential !== credential) {
        const ref = detached.connection.credential
        if (ref && !state.retiredCredentials?.includes(ref)) state.retiredCredentials = (state.retiredCredentials ?? []).concat(ref)
      }
      const commit = proposal.publish && remote.journal ? provider.commitName(proposal.manifest, remote.frontier ?? []) : undefined
      const commitBody = commit === undefined ? undefined : provider.commitBody(proposal.manifest, remote.frontier ?? [])
      state.intent = { connection, expected: remote.etag, sent: false, groupRevisions: proposal.revisions,
        applies: proposal.applies, commit, commitBody, writtenDatasets: proposal.writtenDatasets }
      if (activate) {
        if (state.pendingConfiguration?.endpointIdentity === endpoint) state.pendingConfiguration.enabled = true
        if (state.active?.endpointIdentity === endpoint) state.active.enabled = true
      }
      state.retiredCredentials = state.retiredCredentials?.filter((ref: string): boolean => ref !== credential)
      return true
    }, guard)
    for (const object of proposal.objects) await provider.storeObject(object, guard)
    if (manualPreview) await this.assertRevisions(proposal.revisions)
    let sent = false
    const beforeSend = async (): Promise<void> => {
      await this.storage.updateInBackground((state: SyncLocalDocument): boolean => {
        const intent = state.intent
        if (intent === undefined) throw new Error('sync_connection_changed')
        state.intent = { connection: intent.connection, expected: intent.expected, sent: true,
          detached: intent.detached, groupRevisions: intent.groupRevisions, applies: intent.applies,
          commit: intent.commit, commitBody: intent.commitBody, writtenDatasets: intent.writtenDatasets }
        return true
      }, guard)
      guard()
      sent = true
    }
    let receipt: SyncRemoteManifest
    try {
      if (proposal.publish && !(await provider.publish(proposal.manifest, remote.etag, guard, beforeSend,
        proposal.writtenDatasets ?? selectedDatasetIds(selected)))) {
        this.storage.update((state: SyncLocalDocument): void => { state.intent = undefined })
        throw new Error(manualPreview ? 'sync_preview_changed' : 'sync_remote_changed')
      }
      const commit = this.storage.load().intent?.commit
      receipt = proposal.publish && commit !== undefined ?
        (await provider.readCommit(commit, guard)) ?? { etag: '', hash: '' } :
        remote.writer && !manualPreview ? remote : await provider.readManifest(guard, proposal.publish ? '' : remote.etag)
    } catch (error) {
      const code = (error as Error).message
      // The durable intent has crossed the PUT boundary. An interrupted
      // transport cannot distinguish rejection from a committed manifest.
      if (proposal.publish && sent && (code === 'sync_network_failed' || code === 'sync_server_unavailable' ||
        code === 'sync_network_timeout' || code.startsWith('sync_server_http_5'))) {
        throw new Error('sync_remote_result_unknown')
      }
      throw error as Error
    }
    if (!proposal.publish && receipt.etag !== remote.etag) throw new Error('sync_preview_changed')
    if (receipt.manifest === undefined || receipt.manifest.space !== connection.space ||
      receipt.manifest.revision < connection.revision) throw new Error('sync_remote_result_unknown')
    if (receipt.hash !== connection.manifestHash) {
      await this.acknowledge(provider, connection, receipt, guard)
      throw new Error('sync_remote_changed')
    }
    connection.frontier = this.receiptFrontier(connection.frontier, receipt)
    // A download-only plan also needs durable recovery once its exact remote
    // receipt is verified. It must not disappear if the local owner write fails.
    if (!proposal.publish) await beforeSend()
    const previousCredential = this.active()?.credential
    await this.owner.commit(proposal.applies, proposal.revisions, (localReceipt: string): void => {
      guard()
      if (this.storage.load().counter !== proposal.counter) throw new Error('sync_local_changed')
      const committed = applyReceiptBaselines(proposal.remaining, proposal.applies)
      this.storage.update((state: SyncLocalDocument): void => {
        this.finishLocalReceipt(state, connection, committed, localReceipt)
        // Only the exact remote dots of the old, same-space plan prove that
        // it was accepted or superseded. A new merge does not stand in for it.
        state.archivedIntents = state.archivedIntents?.filter((entry: SyncCommitIntent): boolean => {
          if (entry.connection.endpointIdentity !== endpoint || entry.connection.space !== connection.space) return true
          return entry.connection.groups.some((group: SyncGroupState): boolean => {
            const current = reviewedGroups.find((row: PreparedGroup): boolean => row.id === group.id)
            return group.pending.some((item: SyncPendingEdit): boolean => {
              const fact = current?.remote.find((row: SyncFact): boolean => row.key === item.key)
              return fact === undefined || !syncObserves(fact.seen, item.version)
            })
          })
        })
      })
    })
    const before = proposal.groups.find((group: SyncGroupState): boolean => group.id === 'reading')?.pending ?? []
    const after = proposal.remaining.find((group: SyncGroupState): boolean => group.id === 'reading')?.pending ?? []
    const received = proposal.applies.find((group: SyncApplyGroup): boolean => group.group === 'reading')?.changes ?? []
    const versionKey = (version: SyncVersion): string => version.replica + ':' + version.sequence.toString()
    const uploaded = new Set<string>(before.filter((item: SyncPendingEdit): boolean =>
      !after.some((remaining: SyncPendingEdit): boolean => remaining.key === item.key &&
        remaining.version.replica === item.version.replica && remaining.version.sequence === item.version.sequence))
      .map((item: SyncPendingEdit): string => versionKey(item.version))).size
    const readingFacts = bySyncFact(proposal.groups.find((group: SyncGroupState): boolean => group.id === 'reading')?.facts ?? [])
    const downloaded = new Set<string>(received.map((item: SyncLocalValue): string => {
      const fact = readingFacts.get(item.key)
      if (fact === undefined) return item.key
      const heads = syncVisibleHeads(fact)
      const winner = heads[heads.length - 1] ?? fact.barriers[fact.barriers.length - 1]
      return winner === undefined ? item.key : versionKey(winner.version)
    })).size
    this.lastReadingRound = { uploaded, downloaded, pending: new Set<string>(
      after.map((item: SyncPendingEdit): string => versionKey(item.version))).size }
    if (previousCredential !== undefined && previousCredential !== credential) {
      await this.removeUnusedCredential(previousCredential).catch((): void => {})
    }
  }

  private finishLocalReceipt(state: SyncLocalDocument, connection: SyncSavedConnection,
    committed: SyncGroupState[], localReceipt: string): void {
    const replaced = state.active
    const pending = state.pendingConfiguration
    state.intent = undefined
    state.localReceipt = localReceipt
    if (replaced !== undefined && replaced.endpointIdentity !== connection.endpointIdentity) {
      const archived = copySyncConnection(replaced)
      archived.credential = ''
      archived.automatic = false
      state.archives = (state.archives ?? []).filter((entry: SyncSavedConnection): boolean =>
        entry.endpointIdentity !== archived.endpointIdentity).concat(archived)
    }
    const active = copySyncConnection(connection)
    if (pending?.endpointIdentity === connection.endpointIdentity) {
      active.enabled = pending.enabled
      active.automatic = pending.automatic
      active.credential = pending.credential
      active.selected = pending.selected.slice()
    } else if (replaced?.endpointIdentity === connection.endpointIdentity) {
      active.enabled = replaced.enabled ?? true
      active.automatic = replaced.automatic
      active.credential = replaced.credential
    }
    state.syncContents = selectedGroups(state.syncContents ?? active.selected)
    active.selected = state.syncContents.slice()
    const previous = replaced?.space === connection.space ? replaced : state.archives?.find((item: SyncSavedConnection): boolean =>
      item.endpointIdentity === connection.endpointIdentity && item.space === connection.space)
    active.groups = previous?.groups.slice() ?? []
    committed.forEach((group: SyncGroupState): void => { active.groups = replaceGroup(active.groups, group) })
    active.lastSuccess = Date.now()
    state.active = active
    if (pending?.endpointIdentity === connection.endpointIdentity) state.pendingConfiguration = undefined
    if (active.credential !== connection.credential) {
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(connection.credential)
    }
    if (replaced !== undefined && replaced.credential !== connection.credential) {
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(replaced.credential)
    }
    state.archives = state.archives?.filter((entry: SyncSavedConnection): boolean => entry.endpointIdentity !== connection.endpointIdentity)
  }

  private receiptFrontier(previous: string[] | undefined, receipt: SyncRemoteManifest): string[] | undefined {
    const paths = receipt.frontier?.slice()
    if (receipt.writer !== true || paths?.length !== 1 || !paths[0].includes('/')) return paths
    const prefix = paths[0].split('/')[0] + '/'
    return (previous ?? []).filter((path: string): boolean => !path.startsWith(prefix)).concat(paths).sort()
  }

  private publicationWriter(): string {
    const state = this.storage.load()
    return state.publicationWriter ?? state.replica
  }

  private async acknowledge(provider: DeviceSyncWebDav, connection: SyncSavedConnection, remote: SyncRemoteManifest,
    guard: SyncRequestGuard): Promise<void> {
    if (remote.manifest === undefined || remote.manifest.space !== connection.space) return
    const groups: SyncGroupState[] = []
    let budget = SYNC_MAX_ROUND_BYTES
    const written = this.storage.load().intent?.writtenDatasets
    for (const group of connection.groups) {
      if (!connection.selected.includes(group.id)) continue
      if (written !== undefined && !writeDatasetIds(group.id).some((id: string): boolean => written.includes(id))) {
        groups.push(group)
        continue
      }
      const coverId = coverDatasetId(group.id)
      const refs = groupDatasets(remote.manifest, group.id).concat(syncDatasetBranches(remote.manifest, coverId))
        .filter((ref: SyncDatasetRef): boolean => (written === undefined || written.includes(ref.id)) &&
          group.pending.some((row: SyncPendingEdit): boolean => isCoverKey(row.key) === (ref.id === coverId)))
      if (refs.length === 0 || group.pending.length === 0) {
        groups.push(group)
        continue
      }
      let received: SyncFact[] = []
      for (const ref of refs) {
        budget -= syncDatasetBytes(ref)
        if (budget < 0) throw new Error('sync_round_too_large')
        received = mergeSyncFacts(received, await this.loadDataset(provider, ref, guard, group.id))
      }
      const facts = bySyncFact(received)
      const pending = group.pending.filter((row: SyncPendingEdit): boolean => {
        const remoteFact = facts.get(row.key)
        return remoteFact === undefined || !syncObserves(remoteFact.seen, row.version)
      })
      groups.push({ id: group.id, facts: group.facts, baseline: group.baseline, pending,
        deferred: group.deferred, deferredRoots: group.deferredRoots })
    }
    this.storage.update((state: SyncLocalDocument): void => {
      if (state.intent === undefined) return
      const confirmed = copySyncConnection(connection)
      confirmed.groups = groups
      state.intent = { connection: confirmed, expected: state.intent.expected, sent: state.intent.sent, detached: state.intent.detached,
        groupRevisions: state.intent.groupRevisions, applies: state.intent.applies, commit: state.intent.commit, commitBody: state.intent.commitBody,
        writtenDatasets: state.intent.writtenDatasets }
    })
  }

  private async finishMaintenance(provider: DeviceSyncWebDav, remote: SyncRemoteManifest,
    guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const current = remote.manifest
    if (current === undefined || !current.maintenance) return remote
    if (current.datasets.concat(current.previous).some((dataset: SyncDatasetRef): boolean =>
      dataset.schema !== 1 || !selectedDatasetIds(SYNC_GROUPS).includes(dataset.id))) throw new Error('sync_update_required')
    const candidates = await provider.sweepable(current, guard)
    for (const path of candidates) await provider.removeUnreferenced(path, guard)
    const next: SyncManifest = { format: current.format, schema: current.schema, minWriter: current.minWriter,
      space: current.space, revision: current.revision + 1, epoch: current.epoch, maintenance: false,
      datasets: current.datasets, previous: current.previous }
    await provider.publish(next, remote.etag, guard)
    return provider.readManifest(guard)
  }

  private async maybeMaintain(provider: DeviceSyncWebDav, guard: SyncRequestGuard): Promise<void> {
    return // V2 keeps immutable ancestry; the v1 epoch collector cannot protect late writers.
  }

  private rememberRetired(ref: string): void {
    if (this.storage.load().retiredCredentials?.includes(ref)) return
    this.storage.update((state: SyncLocalDocument): void => {
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(ref)
    })
  }

  private async removeUnusedCredential(ref: string): Promise<void> {
    const state = this.storage.load()
    if (state.pendingConfiguration?.credential === ref || state.active?.credential === ref ||
      (state.intent?.connection.credential === ref && !state.intent.detached) ||
      state.probes.some((row: SyncProbeRecord): boolean => row.credential === ref)) return
    await clearSyncCredential(ref)
    this.storage.update((value: SyncLocalDocument): void => {
      value.retiredCredentials = value.retiredCredentials?.filter((item: string): boolean => item !== ref)
    })
  }

  setAutomatic(value: boolean): void {
    const current = this.storage.load()
    if (current.pendingConfiguration !== undefined) {
      this.storage.update((state: SyncLocalDocument): void => {
        if (state.pendingConfiguration !== undefined) state.pendingConfiguration.automatic = value
      })
      return
    }
    if (current.active === undefined || current.active.automatic === value) return
    this.storage.update((state: SyncLocalDocument): void => { if (state.active !== undefined) state.active.automatic = value })
  }

  setSelection(input: SyncGroup[]): void {
    const current = this.storage.load()
    const selected = selectedGroups(input)
    const before = this.selection()
    if (selected.join(',') === before.join(',')) return
    const configuration = this.configuration()
    this.storage.update((state: SyncLocalDocument): void => {
      state.syncContents = selected.slice()
      if (configuration !== undefined) this.adjustIntentSelection(state, configuration.endpointIdentity, selected)
      const pending = state.pendingConfiguration
      if (pending !== undefined) {
        pending.selected = selected.slice()
        return
      }
      const active = state.active
      if (active === undefined) {
        if (configuration !== undefined) {
          state.pendingConfiguration = { credential: configuration.credential, endpointIdentity: configuration.endpointIdentity,
            selected: selected.slice(), automatic: configuration.automatic, enabled: configuration.enabled !== false }
        }
        return
      }
      const explicit = syncRequiresExplicitReview(active)
      active.selected = selected.slice()
      if (!explicit) {
        active.reviewRequired = active.groups.some((group: SyncGroupState): boolean =>
          selected.includes(group.id) && (group.deferred?.length ?? 0) > 0)
      }
    })
    this.generation++
    this.reviewGeneration++
    this.prepared = undefined
    before.forEach((group: SyncGroup): void => {
      if (!selected.includes(group)) this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1)
    })
  }

  private adjustIntentSelection(state: SyncLocalDocument, endpoint: string, selected: SyncGroup[]): void {
    const intent = state.intent
    if (intent === undefined || intent.detached || intent.connection.endpointIdentity !== endpoint) return
    if (intent.connection.selected.some((id: SyncGroup): boolean => !selected.includes(id))) {
      state.intent = detachedIntent(intent, state)
    } else {
      // An earlier published round may finish, but must not overwrite a newer scope choice.
      const connection = copySyncConnection(intent.connection)
      connection.selected = selected.slice()
      state.intent = { connection, expected: intent.expected, sent: intent.sent, detached: intent.detached,
        commit: intent.commit, commitBody: intent.commitBody, applies: intent.applies, groupRevisions: intent.groupRevisions,
        writtenDatasets: intent.writtenDatasets }
    }
  }

  groupScope(group: SyncGroup): string {
    const active = this.active()
    if (active === undefined || !active.selected.includes(group) || this.restoreInProgress) return ''
    return active.space + ':' + group + ':' + (this.groupEpochs.get(group) ?? 0)
  }

  knownGroupKeys(group: SyncGroup): string[] {
    return this.active()?.groups.find((entry: SyncGroupState): boolean => entry.id === group)
      ?.facts.map((fact: SyncFact): string => fact.key) ?? []
  }

  readingScope(): string {
    return this.groupScope('reading')
  }

  cleared(group: SyncGroup, key: string): SyncVersion[] {
    return this.active()?.groups.find((entry: SyncGroupState): boolean => entry.id === group)
      ?.facts.find((fact: SyncFact): boolean => fact.key === key)?.cleared.slice() ?? []
  }

  hasUnseenBarrier(group: SyncGroup, key: string, observed: SyncVersion[], cleared: SyncVersion[] = []): boolean {
    const fact = this.active()?.groups.find((entry: SyncGroupState): boolean => entry.id === group)
      ?.facts.find((entry: SyncFact): boolean => entry.key === key)
    return fact?.barriers.some((edit: SyncEdit): boolean => !syncObserves(observed, edit.version)) === true ||
      fact?.cleared.some((version: SyncVersion): boolean => !syncObserves(cleared, version)) === true
  }

  observed(group: SyncGroup, key: string): SyncVersion[] {
    return this.active()?.groups.find((entry: SyncGroupState): boolean => entry.id === group)
      ?.facts.find((fact: SyncFact): boolean => fact.key === key)?.seen.slice() ?? []
  }

  knownReadingValue(key: string): string | undefined {
    const fact = this.active()?.groups.find((group: SyncGroupState): boolean => group.id === 'reading')
      ?.facts.find((item: SyncFact): boolean => item.key === key)
    return fact === undefined ? undefined : syncGroupVisibleValue('reading', fact)
  }

  hasShelfMove(key: string): boolean {
    return this.active()?.groups.find((group: SyncGroupState): boolean => group.id === 'shelf')
      ?.facts.find((fact: SyncFact): boolean => fact.key === key)
      ?.barriers.some((edit: SyncEdit): boolean => syncShelfMove(edit.value) !== undefined) === true
  }

  async assertReadingUnprotected(keys: string[]): Promise<void> {
    const local = await this.owner.snapshot('reading', false)
    if (keys.some((key: string): boolean => local.protectedKeys?.includes(key) === true)) throw new Error('sync_reading_proof_pending')
  }

  readingWritePending(version: SyncVersion | undefined): boolean {
    if (version === undefined) return false
    return this.active()?.groups.find((row: SyncGroupState): boolean => row.id === 'reading')
      ?.pending.some((row: SyncPendingEdit): boolean => row.version.replica === version.replica &&
        row.version.sequence === version.sequence) ?? false
  }

  recordEdits(group: SyncGroup, actions: DeviceSyncLocalEdit[], receipt?: SyncReadingReceipt): SyncVersion | undefined {
    const change = this.prepareEdits(this.storage.load(), group, actions, receipt)
    if (change === undefined) return undefined
    this.storage.update(change.apply)
    return change.version
  }

  async recordReadingEdits(actions: DeviceSyncLocalEdit[], receipt: SyncReadingReceipt, guard: () => void): Promise<SyncVersion | undefined> {
    let version: SyncVersion | undefined
    await this.storage.updateInBackground((state: SyncLocalDocument): boolean => {
      const change = this.prepareEdits(state, 'reading', actions, receipt)
      version = change?.version
      if (change === undefined) return false
      change.apply(state)
      return true
    }, guard)
    return version
  }

  private prepareEdits(current: SyncLocalDocument, group: SyncGroup, actions: DeviceSyncLocalEdit[],
    receipt?: SyncReadingReceipt): SyncLocalEditChange | undefined {
    const active = current.active
    if (active === undefined || !active.selected.includes(group) ||
      (active.restoreReview === true && syncRequiresExplicitReview(active)) || this.restoreInProgress) return
    const previous = active.groups.find((item: SyncGroupState): boolean => item.id === group)
    if (previous === undefined || (actions.length === 0 && receipt === undefined) ||
      current.readingReceipts?.some((item: SyncReadingReceipt): boolean => item.key === receipt?.key && item.id === receipt?.id)) return
    const facts = bySyncFact(previous.facts)
    const baseline = byLocalValue(previous.baseline)
    const pending = previous.pending.slice()
    const version: SyncVersion = { replica: current.replica, sequence: current.counter + 1 }
    actions.forEach((action: DeviceSyncLocalEdit): void => {
      const old = facts.get(action.key) ?? emptySyncFact(action.key)
      if (action.kind === 'set' && syncVisibleValue(old) === action.value && syncVisibleHeads(old).length <= 1) return
      const updated = applySyncEdit(old, { version, observed: action.observed ?? old.seen, kind: action.kind, value: action.value })
      checkSyncGroupFact(group, updated)
      facts.set(action.key, updated)
      pending.push({ key: action.key, version })
      if (action.value === '') baseline.delete(action.key)
      else baseline.set(action.key, action.value)
    })
    const changed = pending.length !== previous.pending.length
    if (!changed && receipt === undefined) return
    const rows: SyncLocalValue[] = []
    baseline.forEach((value: string, key: string): void => { rows.push({ key, value }) })
    const next: SyncGroupState = { id: previous.id, facts: Array.from(facts.values()), pending, baseline: rows,
      deferred: previous.deferred, deferredRoots: previous.deferredRoots }
    const apply = (state: SyncLocalDocument): void => {
      if (changed) {
        state.counter = version.sequence
        if (state.active !== undefined) state.active.groups = replaceGroup(active.groups, next)
      }
      if (receipt !== undefined) {
        state.readingReceipts = (state.readingReceipts ?? []).filter((item: SyncReadingReceipt): boolean =>
          item.key !== receipt.key).concat({ key: receipt.key, id: receipt.id, version: changed ? version : undefined })
      }
    }
    return { apply, version: changed ? version : undefined }
  }

  recoverOnForeground(): Promise<void> {
    if (!this.isEnabled()) return Promise.resolve()
    if (this.running !== undefined) return this.running
    return this.start(async (): Promise<void> => {
      await this.cleanProbes()
      await this.recoverIntent()
    })
  }

  private async rememberRemote(space: string, remote: SyncRemoteManifest, guard: SyncRequestGuard,
    clearIntent: boolean = false): Promise<void> {
    const manifest = remote.manifest
    const newFrontier = remote.frontier
    await this.storage.updateInBackground((state: SyncLocalDocument): boolean => {
      const active = state.active
      let changed = false
      if (manifest !== undefined && manifest.space === space && active?.space === space &&
        (remote.journal || active.revision < manifest.revision)) {
        const oldFrontier = active.frontier
        const sameFrontier = oldFrontier === undefined ? newFrontier === undefined :
          newFrontier !== undefined && oldFrontier.length === newFrontier.length &&
          oldFrontier.every((path: string, index: number): boolean => path === newFrontier[index])
        if (active.revision !== manifest.revision || active.manifestHash !== remote.hash || !sameFrontier) {
          active.revision = manifest.revision
          active.manifestHash = remote.hash
          active.frontier = newFrontier?.slice()
          changed = true
        }
      }
      if (clearIntent && state.intent !== undefined) {
        state.intent = undefined
        changed = true
      }
      return changed
    }, guard)
  }

  private async recoverIntent(): Promise<void> {
    if (!this.isEnabled()) return
    const starting = this.storage.load()
    const intent = starting.intent
    if (intent === undefined || intent.detached || this.restoreInProgress) return
    if (!intent.sent) {
      this.storage.update((state: SyncLocalDocument): void => { state.intent = undefined })
      this.rememberRetired(intent.connection.credential)
      return
    }
    const active = this.active()
    const connection = intent.connection
    // An explicit disable seals its intent when changing selection. An old
    // active selection alone can also mean that enabling a group was interrupted.
    const guard = this.transferGuard(this.generation)
    const configured = this.configuration()
    const credential = configured?.endpointIdentity === connection.endpointIdentity ? configured.credential : connection.credential
    const provider = new DeviceSyncWebDav(await readSyncCredential(credential), connection.frontier, connection.space, this.publicationWriter())
    let receipt = intent.commit !== undefined ? await provider.readCommit(intent.commit, guard) :
      connection.frontier !== undefined ? await provider.readManifest(guard) : await provider.readLegacyManifest(guard)
    if (receipt === undefined && intent.commitBody !== undefined) {
      // An absent reply may mean the original PUT never arrived. Replaying the
      // exact immutable bytes is safe even if that original request arrives late.
      receipt = await provider.retryCommit(intent.commitBody, guard,
        intent.writtenDatasets ?? selectedDatasetIds(connection.selected), intent.commit)
    }
    if (receipt === undefined) throw new Error('sync_remote_result_unknown')
    if (active?.space === connection.space && intent.commit === undefined) this.checkHighWater(active, receipt)
    if (receipt.hash !== connection.manifestHash && receipt.etag === intent.expected) {
      // A process can stop between persisting the sending intent and issuing
      // its conditional request. The original head still admits a fresh plan.
      this.storage.update((state: SyncLocalDocument): void => { state.intent = undefined })
      await this.removeUnusedCredential(connection.credential)
      return
    }
    if (receipt.manifest === undefined || receipt.manifest.space !== connection.space ||
      receipt.manifest.revision < connection.revision) throw new Error('sync_remote_result_unknown')
    if (receipt.hash !== connection.manifestHash) {
      await this.acknowledge(provider, connection, receipt, guard)
      const state = this.storage.load()
      if (state.intent === undefined) return
      const pending = state.intent.connection.groups
      this.storage.update((value: SyncLocalDocument): void => {
        value.intent = undefined
        if (value.active?.space !== connection.space) {
          const recovered = copySyncConnection(connection)
          recovered.groups = pending
          recovered.reviewRequired = true
          recovered.requiresExplicitReview = true
          recovered.lastError = 'sync_remote_committed_locally_changed'
          value.active = recovered
        } else {
          pending.forEach((group: SyncGroupState): void => {
            const currentGroup = value.active?.groups.find((entry: SyncGroupState): boolean => entry.id === group.id)
            if (currentGroup === undefined || value.active === undefined) return
            const combined: SyncGroupState = { id: group.id, facts: mergeSyncFacts(currentGroup.facts, group.facts),
              baseline: currentGroup.baseline, pending: currentGroup.pending.concat(group.pending), deferred: currentGroup.deferred,
              deferredRoots: currentGroup.deferredRoots }
            value.active.groups = replaceGroup(value.active.groups, combined)
          })
        }
      })
      return
    }
    let snapshots: SyncLocalSnapshot[] = []
    try {
      snapshots = await this.assertRevisions(intent.groupRevisions)
    } catch (_error) {
      guard()
      if (receipt.writer && active?.space === connection.space && !syncRequiresExplicitReview(active)) {
        // A new reading save can race the old local apply. The exact remote
        // publication is already durable. The next plan reads it and applies
        // against the latest owner snapshots, keeping any later local dots.
        receipt.frontier = this.receiptFrontier(active.frontier, receipt)
        await this.rememberRemote(connection.space, receipt, guard, true)
        return
      }
      this.storage.update((state: SyncLocalDocument): void => {
        state.intent = undefined
        if (state.active?.space !== connection.space) state.active = copySyncConnection(connection)
        if (state.active !== undefined) {
          state.active.reviewRequired = true
          state.active.requiresExplicitReview = true
          state.active.lastError = 'sync_remote_committed_locally_changed'
        }
      })
      throw new Error('sync_review_required')
    }
    await this.acknowledge(provider, connection, receipt, guard)
    connection.frontier = this.receiptFrontier(connection.frontier, receipt)
    const accepted = this.storage.load().intent?.connection.groups ?? connection.groups
    // Older persisted intents could contain an empty apply for a fixed host
    // setting. Keep their exact remote commit, but use the same checked owner
    // snapshot for both the local apply and its receipt baseline.
    const applies = intent.applies.map((group: SyncApplyGroup): SyncApplyGroup => {
      const index = intent.groupRevisions.findIndex((item: SyncOwnerRevision): boolean => item.group === group.group)
      const retained = snapshots[index]?.retainedDeletionKeys ?? []
      return { group: group.group, changes: group.changes.filter((change: SyncLocalValue): boolean =>
        change.value !== '' || !retained.includes(change.key)) }
    })
    const committed = applyReceiptBaselines(accepted, applies)
    await this.owner.commit(applies, intent.groupRevisions, (localReceipt: string): void => {
      guard()
      if (this.storage.load().counter !== starting.counter) throw new Error('sync_local_changed')
      this.storage.update((state: SyncLocalDocument): void => {
        this.finishLocalReceipt(state, connection, committed, localReceipt)
      })
    })
  }

  async disconnect(): Promise<void> {
    const current = this.storage.load()
    const selected = this.selection()
    this.generation++
    this.prepared = undefined
    this.tested = undefined
    SYNC_GROUPS.forEach((group: SyncGroup): void => { this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1) })
    this.cache = []
    this.cacheSize = 0
    const active = current.active
    const pendingCredential = current.pendingConfiguration?.credential
    const probeCredentials = current.probes.map((probe: SyncProbeRecord): string => probe.credential)
    if (pendingCredential !== undefined) probeCredentials.push(pendingCredential)
    if (current.intent?.connection.credential) probeCredentials.push(current.intent.connection.credential)
    probeCredentials.push(...(current.retiredCredentials ?? []))
    // Explicitly forgetting this service also withdraws its probe credentials.
    // Remote files are retained; a different service owns its own state/store.
    this.storage.update((state: SyncLocalDocument): void => {
      state.syncContents = selected.slice()
      state.probes = []
      state.pendingConfiguration = undefined
      if (state.intent !== undefined) state.intent = detachedIntent(state.intent, state)
      state.retiredCredentials = Array.from(new Set<string>((state.retiredCredentials ?? []).concat(probeCredentials)))
    })
    if (active === undefined) {
      for (const ref of probeCredentials) await this.removeUnusedCredential(ref)
      return
    }
    const archive = copySyncConnection(active)
    archive.credential = ''
    archive.automatic = false
    this.storage.update((state: SyncLocalDocument): void => {
      state.active = undefined
      state.archives = (state.archives ?? []).filter((item: SyncSavedConnection): boolean =>
        item.endpointIdentity !== archive.endpointIdentity).concat(archive)
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(active.credential)
      if (state.intent !== undefined) state.intent = detachedIntent(state.intent, state)
    })
    await this.removeUnusedCredential(active.credential)
    for (const ref of probeCredentials) await this.removeUnusedCredential(ref)
  }

  beginRestore(): void {
    this.generation++
    this.prepared = undefined
    this.restoreInProgress = true
    SYNC_GROUPS.forEach((group: SyncGroup): void => { this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1) })
    const current = this.storage.load()
    this.restoreBefore = current.active
    this.restoreBeforeIntent = current.intent
    this.restoreBeforeConfiguration = current.pendingConfiguration
    if (this.restoreBefore !== undefined || this.restoreBeforeIntent !== undefined || this.restoreBeforeConfiguration !== undefined) {
      this.storage.update((state: SyncLocalDocument): void => {
        if (state.pendingConfiguration !== undefined) state.pendingConfiguration.enabled = false
        if (state.active !== undefined) {
          state.active.reviewRequired = true
          state.active.requiresExplicitReview = true
          state.active.restoreReview = true
        }
        if (state.intent !== undefined) state.intent = detachedIntent(state.intent, state)
      })
    }
  }

  finishRestore(committed: boolean): void {
    this.restoreInProgress = false
    const prior = this.restoreBefore
    const priorIntent = this.restoreBeforeIntent
    const priorConfiguration = this.restoreBeforeConfiguration
    this.restoreBefore = undefined
    this.restoreBeforeIntent = undefined
    this.restoreBeforeConfiguration = undefined
    if (!committed && (prior !== undefined || priorIntent !== undefined || priorConfiguration !== undefined)) {
      this.storage.update((state: SyncLocalDocument): void => {
        if (priorConfiguration !== undefined) state.pendingConfiguration = priorConfiguration
        if (prior !== undefined && state.active?.space === prior.space) {
          state.active.reviewRequired = prior.reviewRequired
          state.active.requiresExplicitReview = prior.requiresExplicitReview
          state.active.restoreReview = prior.restoreReview
        }
        if (priorIntent !== undefined && state.intent?.connection.manifestHash === priorIntent.connection.manifestHash) {
          state.intent = priorIntent
        }
      })
    }
  }
}
