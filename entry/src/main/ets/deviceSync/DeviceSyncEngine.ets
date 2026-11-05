import { util } from '@kit.ArkTS'
import {
  applySyncEdit, emptySyncFact, mergeSyncFacts, syncObserves, syncVisibleHeads, syncVisibleValue, SyncEdit,
  SyncEditKind, SyncFact, SyncGroup, SyncVersion, SYNC_GROUPS,
} from './DeviceSyncFacts'
import { checkSyncGroupFact, SyncRecentValue, syncBucketKey, syncKey, syncKeyParts } from './DeviceSyncData'
import {
  buildSyncDataset, decodeSyncShard, newSyncManifest, syncDatasetBytes, syncDigest, syncShardPath,
  SyncDatasetRef, SyncManifest, SyncObject, SyncShardRef, SYNC_MAX_ROUND_BYTES,
} from './DeviceSyncWire'
import {
  DeviceSyncStorage, SyncCommitIntent, SyncGroupState, SyncLocalDocument, SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision,
  SyncPendingEdit, SyncProbeRecord, SyncReadingReceipt, SyncRestoreEdit, SyncSavedConnection, checkedSyncDraft, copySyncConnection,
  readSyncCredential, writeSyncCredential, clearSyncCredential,
} from './DeviceSyncStorage'
import { DeviceSyncWebDav, SyncConnectionDraft, SyncRemoteManifest, SyncRequestGuard } from './DeviceSyncWebDav'

export interface DeviceSyncLocalEdit {
  key: string
  kind: SyncEditKind
  value: string
  observed?: SyncVersion[]
}

export interface SyncApplyGroup {
  group: SyncGroup
  changes: SyncLocalValue[]
}

/** Real application owners participate in one local commit before UI publication. */
export interface DeviceSyncOwner {
  snapshot(group: SyncGroup, verifyPublic: boolean): Promise<SyncLocalSnapshot>
  removed(group: SyncGroup, keys: string[]): string[]
  commit(groups: SyncApplyGroup[], expected: SyncOwnerRevision[], saveCursor: (receipt: string) => void): Promise<void>
}

export interface SyncMergeConflict {
  group: SyncGroup
  key: string
  local: string
  remote: string
  deleted: boolean
  label?: string
}

export interface SyncMergeChoice {
  group: SyncGroup
  key: string
  useLocal: boolean
  useBeforeRestore?: boolean
}

export interface SyncPreviewGroup {
  group: SyncGroup
  upload: number
  download: number
  remove: number
  skipped: number
}

interface PreparedGroup {
  id: SyncGroup
  local: SyncLocalSnapshot
  remote: SyncFact[]
  previous?: SyncGroupState
  requiresPreview: boolean
  resetBaseline: boolean
  removed: string[]
}

export interface SyncPreview {
  token: string
  groups: SyncPreviewGroup[]
  conflicts: SyncMergeConflict[]
  freshConnection: boolean
  categories: string[]
  beforeRestore: SyncMergeConflict[]
  earlierUnconfirmed: number
}

export interface SyncReadingDecision {
  key: string
  title: string
  values: string[]
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
}

interface ProposedSync {
  manifest: SyncManifest
  objects: SyncObject[]
  groups: SyncGroupState[]
  staged: SyncGroupState[]
  remaining: SyncGroupState[]
  applies: SyncApplyGroup[]
  revisions: SyncOwnerRevision[]
  counter: number
  initialCounter: number
  publish: boolean
}

interface DatasetCache {
  path: string
  data: SyncFact[]
  bytes: number
}

const DEFAULT_GROUPS: SyncGroup[] = ['shelf', 'reading']

function selectedGroups(groups: SyncGroup[]): SyncGroup[] {
  return SYNC_GROUPS.filter((group: SyncGroup): boolean => groups.includes(group))
}

export function syncRequiresExplicitReview(value: SyncSavedConnection | undefined): boolean {
  if (value === undefined || !value.reviewRequired) return false
  if (value.requiresExplicitReview !== undefined) return value.requiresExplicitReview
  return value.restoreReview === true || value.lastError === 'sync_remote_committed_locally_changed' ||
    !value.groups.some((row: SyncGroupState): boolean => value.selected.includes(row.id) && (row.deferred?.length ?? 0) > 0)
}

function byLocalValue(values: SyncLocalValue[]): Map<string, string> {
  const map = new Map<string, string>()
  values.forEach((row: SyncLocalValue): void => { map.set(row.key, row.value) })
  return map
}

function localValueRows(values: Map<string, string>): SyncLocalValue[] {
  const rows: SyncLocalValue[] = []
  values.forEach((value: string, key: string): void => { rows.push({ key, value }) })
  return rows
}

function bySyncFact(facts: SyncFact[]): Map<string, SyncFact> {
  const map = new Map<string, SyncFact>()
  facts.forEach((fact: SyncFact): void => { map.set(fact.key, fact) })
  return map
}

function conflictChoice(choices: SyncMergeChoice[], group: SyncGroup, key: string): SyncMergeChoice | undefined {
  return choices.find((choice: SyncMergeChoice): boolean => choice.group === group && choice.key === key)
}

function restorableEdits(local: SyncLocalSnapshot): SyncRestoreEdit[] {
  const all = local.restoreEdits ?? []
  return all.filter((edit: SyncRestoreEdit): boolean => !local.protectedKeys?.includes(edit.key) &&
    (edit.bundle === undefined || !all.some((related: SyncRestoreEdit): boolean =>
      edit.bundle === related.bundle && local.protectedKeys?.includes(related.key) === true)))
}

function replaceGroup(groups: SyncGroupState[], next: SyncGroupState): SyncGroupState[] {
  return groups.filter((group: SyncGroupState): boolean => group.id !== next.id).concat(next)
}

function applyReceiptBaselines(groups: SyncGroupState[], applies: SyncApplyGroup[]): SyncGroupState[] {
  return groups.map((group: SyncGroupState): SyncGroupState => {
    const changes = applies.find((value: SyncApplyGroup): boolean => value.group === group.id)?.changes
    if (changes === undefined || changes.length === 0) return group
    const baseline = byLocalValue(group.baseline)
    changes.forEach((change: SyncLocalValue): void => {
      if (change.value === '') baseline.delete(change.key)
      else baseline.set(change.key, change.value)
    })
    return { id: group.id, facts: group.facts, pending: group.pending, baseline: localValueRows(baseline), deferred: group.deferred }
  })
}

function endpointIdentity(draft: SyncConnectionDraft): string {
  return syncDigest(JSON.stringify([draft.directory, draft.username]))
}

function sameConnection(a: SyncConnectionDraft, b: SyncConnectionDraft): boolean {
  return a.directory === b.directory && a.username === b.username
}

function detachedIntent(intent: SyncCommitIntent): SyncCommitIntent {
  return { connection: intent.connection, expected: intent.expected, sent: intent.sent, detached: true,
    groupRevisions: intent.groupRevisions, applies: intent.applies }
}

export class DeviceSyncEngine {
  private readonly storage: DeviceSyncStorage
  private readonly owner: DeviceSyncOwner
  private generation: number = 0
  private prepared?: PreparedSync
  private running?: Promise<void>
  private cache: DatasetCache[] = []
  private cacheSize: number = 0
  private restoreInProgress: boolean = false
  private tested?: SyncConnectionDraft
  private restoreBefore?: SyncSavedConnection
  private restoreBeforeIntent?: SyncCommitIntent
  private readonly groupEpochs: Map<SyncGroup, number> = new Map()

  constructor(storage: DeviceSyncStorage, owner: DeviceSyncOwner) {
    this.storage = storage
    this.owner = owner
  }

  active(): SyncSavedConnection | undefined {
    return this.storage.load().active
  }

  selection(): SyncGroup[] {
    return this.active()?.selected.slice() ?? DEFAULT_GROUPS.slice()
  }

  async connectionDraft(): Promise<SyncConnectionDraft | undefined> {
    const active = this.active()
    return active === undefined ? undefined : readSyncCredential(active.credential)
  }

  private guard(expected: number): SyncRequestGuard {
    return (): void => {
      if (this.generation !== expected || this.restoreInProgress) throw new Error('sync_connection_changed')
    }
  }

  async testConnection(raw: SyncConnectionDraft, input: SyncGroup[] = []): Promise<boolean> {
    const draft = checkedSyncDraft(raw)
    const guard = this.guard(this.generation)
    const credential = util.generateRandomUUID()
    const id = util.generateRandomUUID()
    this.storage.update((state: SyncLocalDocument): void => { state.probes.push({ credential, id }) })
    await writeSyncCredential(credential, draft)
    guard()
    const provider = new DeviceSyncWebDav(draft)
    try {
      await provider.probe(id, guard)
      this.tested = draft
      await this.retireProbe(credential)
    } catch (error) {
      // The old endpoint and exact probe path remain in private storage until cleanup succeeds.
      throw error as Error
    }
    const state = this.storage.load()
    const intent = state.intent
    const selected = selectedGroups(input)
    if (intent === undefined || !intent.sent || intent.detached ||
      intent.connection.endpointIdentity !== endpointIdentity(draft) || selected.length === 0 ||
      selected.length !== intent.connection.selected.length ||
      selected.some((group: SyncGroup): boolean => !intent.connection.selected.includes(group))) return false
    const previousDraft = await readSyncCredential(intent.connection.credential)
    guard()
    if (!sameConnection(previousDraft, draft) || previousDraft.password !== draft.password) return false
    // A retry from the connection form can also be the first connection.
    // Resolve the original intent before building any replacement preview.
    await this.recoverIntent()
    const recovered = this.storage.load()
    return recovered.localReceipt !== state.localReceipt && recovered.active?.space === intent.connection.space &&
      !syncRequiresExplicitReview(recovered.active)
  }

  async cleanProbes(): Promise<void> {
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
        await provider.cleanProbe(row.id, guard)
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

  async prepare(raw: SyncConnectionDraft, input: SyncGroup[]): Promise<SyncPreview> {
    this.prepared = undefined
    const draft = checkedSyncDraft(raw)
    const selected = selectedGroups(input)
    if (selected.length === 0) throw new Error('sync_select_contents')
    const generation = this.generation
    const counter = this.storage.load().counter
    const guard = this.guard(generation)
    const connection = this.active()
    const saved = connection === undefined ? undefined : await this.connectionDraft()
    const archived = this.storage.load().archives?.find((entry: SyncSavedConnection): boolean =>
      entry.endpointIdentity === endpointIdentity(draft))
    const existing = connection !== undefined && saved !== undefined && sameConnection(draft, saved) ? connection : archived
    if ((existing === undefined || existing.credential === '') && (this.tested === undefined || !sameConnection(draft, this.tested) ||
      draft.password !== this.tested.password)) throw new Error('sync_test_required')
    this.cache = []
    this.cacheSize = 0
    const provider = new DeviceSyncWebDav(draft)
    const remote = await provider.readManifest(guard)
    this.checkHighWater(existing, remote)
    if (remote.manifest?.maintenance === true) throw new Error('sync_maintenance_running')
    const groups = await this.prepareGroups(provider, selected, existing, remote.manifest, guard, true)
    const preview = this.summarize(groups, existing === undefined)
    if (remote.manifest !== undefined) {
      preview.earlierUnconfirmed = this.unconfirmedFromEarlierConnection(
        endpointIdentity(draft), remote.manifest.space, groups)
    }
    guard()
    if (this.storage.load().counter !== counter) throw new Error('sync_preview_changed')
    this.prepared = { preview, generation, counter, draft, connection: existing, remote, selected, groups }
    return preview
  }

  discardPreview(token: string): void {
    if (this.prepared?.preview.token === token) this.prepared = undefined
  }

  confirm(token: string, choices: SyncMergeChoice[]): Promise<void> {
    if (this.running !== undefined) return Promise.reject(new Error('sync_already_running'))
    const prepared = this.prepared
    this.prepared = undefined
    if (prepared === undefined || prepared.preview.token !== token) return Promise.reject(new Error('sync_preview_changed'))
    return this.start((): Promise<void> => this.confirmPrepared(prepared, choices))
  }

  private async confirmPrepared(prepared: PreparedSync, choices: SyncMergeChoice[]): Promise<void> {
    const guard = this.guard(prepared.generation)
    const provider = new DeviceSyncWebDav(prepared.draft)
    const current = await provider.readManifest(guard, prepared.remote.etag)
    if (current.etag !== prepared.remote.etag || current.hash !== prepared.remote.hash) {
      throw new Error('sync_preview_changed')
    }
    await this.assertRevisions(prepared.groups.map((row: PreparedGroup): SyncOwnerRevision => ({ group: row.id, revision: row.local.revision })))
    guard()
    const credential = util.generateRandomUUID()
    this.rememberRetired(credential)
    await writeSyncCredential(credential, prepared.draft)
    try {
      guard()
      if (this.storage.load().counter !== prepared.counter) throw new Error('sync_preview_changed')
      const proposal = this.propose(prepared.groups, current.manifest, choices)
      await this.execute(provider, prepared.connection, credential, prepared.selected, current, proposal, guard, true,
        endpointIdentity(prepared.draft), prepared.groups)
    } catch (error) {
      await this.removeUnusedCredential(credential)
      throw error as Error
    }
  }

  syncNow(): Promise<void> {
    if (this.running !== undefined) return this.running
    return this.start((): Promise<void> => this.runActive())
  }

  private start(work: () => Promise<void>): Promise<void> {
    const pending = work().finally((): void => { this.running = undefined })
    this.running = pending
    return pending
  }

  private async runActive(): Promise<void> {
    await this.recoverIntent()
    const connection = this.active()
    if (connection === undefined || connection.selected.length === 0) throw new Error('sync_select_contents')
    if (syncRequiresExplicitReview(connection)) throw new Error('sync_review_required')
    const guard = this.guard(this.generation)
    const draft = await readSyncCredential(connection.credential)
    const provider = new DeviceSyncWebDav(draft)
    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) await this.recoverIntent()
        let remote = await provider.readManifest(guard)
        this.checkHighWater(this.active(), remote)
        if (remote.manifest?.maintenance === true) remote = await this.finishMaintenance(provider, remote, guard)
        this.checkHighWater(this.active(), remote)
        this.rememberRemote(connection.space, remote)
        if (remote.manifest?.maintenance === true) throw new Error('sync_maintenance_running')
        const counter = this.storage.load().counter
        const groups = await this.prepareGroups(provider, connection.selected, this.active(), remote.manifest, guard, true)
        if (counter !== this.storage.load().counter) continue
        const proposal = this.propose(groups, remote.manifest, [])
        try {
          await this.execute(provider, this.active(), connection.credential, connection.selected, remote, proposal, guard, false, connection.endpointIdentity)
          await this.maybeMaintain(provider, guard).catch((): void => {})
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
        this.storage.update((state: SyncLocalDocument): void => {
          if (state.active !== undefined) state.active.lastError = (error as Error).message
        })
      }
      throw error as Error
    }
  }

  private checkHighWater(connection: SyncSavedConnection | undefined, remote: SyncRemoteManifest): void {
    if (connection === undefined || connection.revision === 0) return
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
      const path = id + ':' + ref.bucket + ':' + ref.bytes + ':' + syncShardPath(ref)
      let cache = this.cache.find((item: DatasetCache): boolean => item.path === path)
      if (cache === undefined) {
        const body = await provider.readObject(ref, guard)
        const data = decodeSyncShard(id, ref, body, syncBucketKey)
        cache = { path, data, bytes: ref.bytes }
        this.cache.push(cache)
        this.cacheSize += ref.bytes
        while (this.cacheSize > 8 * 1024 * 1024 && this.cache.length > 1) {
          this.cacheSize -= this.cache.shift()?.bytes ?? 0
        }
      }
      cache.data.forEach((fact: SyncFact): void => {
        if (keys.has(fact.key)) throw new Error('sync_duplicate_fact')
        checkSyncGroupFact(id, fact)
        keys.add(fact.key)
        rows.push(fact)
      })
    }
    return rows
  }

  private async prepareGroups(provider: DeviceSyncWebDav, selected: SyncGroup[], connection: SyncSavedConnection | undefined,
    manifest: SyncManifest | undefined, guard: SyncRequestGuard, verifyPublic: boolean): Promise<PreparedGroup[]> {
    let budget = SYNC_MAX_ROUND_BYTES
    const groups: PreparedGroup[] = []
    for (const id of selected) {
      const ref = manifest?.datasets.find((row: SyncDatasetRef): boolean => row.id === id)
      budget -= ref === undefined ? 0 : syncDatasetBytes(ref)
      if (budget < 0) throw new Error('sync_round_too_large')
      const remote = ref === undefined ? [] : await this.loadDataset(provider, ref, guard, id)
      const local = await this.owner.snapshot(id, verifyPublic)
      const previous = connection?.groups.find((row: SyncGroupState): boolean => row.id === id)
      const requiresPreview = previous === undefined || connection?.credential === '' ||
        syncRequiresExplicitReview(connection) || !connection?.selected.includes(id)
      const removed = requiresPreview || previous === undefined ? [] :
        this.owner.removed(id, previous.baseline.map((value: SyncLocalValue): string => value.key))
      groups.push({ id, local, remote, previous, requiresPreview, resetBaseline: connection?.restoreReview === true, removed })
      guard()
    }
    return groups
  }

  private summarize(groups: PreparedGroup[], fresh: boolean): SyncPreview {
    const conflicts: SyncMergeConflict[] = []
    const beforeRestore: SyncMergeConflict[] = []
    const categories: string[] = []
    const summaries = groups.map((entry: PreparedGroup): SyncPreviewGroup => {
      let upload = 0
      let download = 0
      let remove = 0
      const local = byLocalValue(entry.local.values)
      const remote = bySyncFact(entry.remote)
      restorableEdits(entry.local).forEach((edit: SyncRestoreEdit): void => {
        if ((edit.bundle === undefined || syncKeyParts(edit.key)[0] === 'position') &&
          (edit.kind !== 'set' || edit.value !== local.get(edit.key))) {
          beforeRestore.push({ group: entry.id, key: edit.key, local: edit.followUp ?? edit.value,
            remote: local.get(edit.key) ?? '', deleted: edit.kind === 'delete' || edit.kind === 'clear-observed' })
        }
      })
      local.forEach((value: string, key: string): void => {
        if (entry.local.protectedKeys?.includes(key)) return
        const fact = remote.get(key)
        if (key.startsWith('["category",')) categories.push(JSON.parse(value) as string)
        if (fact === undefined) {
          upload++
          return
        }
        const theirs = syncVisibleValue(fact)
        if (theirs === value) return
        if (entry.requiresPreview || entry.previous?.deferred?.includes(key) === true) {
          conflicts.push({ group: entry.id, key, local: value,
            remote: theirs ?? '', deleted: theirs === undefined, label: entry.local.labels?.[key] })
          return
        }
        if (theirs === undefined) remove++
        else download++
      })
      remote.forEach((fact: SyncFact, key: string): void => {
        if (!entry.local.protectedKeys?.includes(key) && !local.has(key) && syncVisibleValue(fact) !== undefined) download++
      })
      return { group: entry.id, upload, download, remove, skipped: entry.local.skipped }
    })
    return { token: util.generateRandomUUID(), groups: summaries, conflicts, freshConnection: fresh, categories, beforeRestore,
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

  private propose(prepared: PreparedGroup[], existing: SyncManifest | undefined, choices: SyncMergeChoice[]): ProposedSync {
    const current = this.storage.load()
    const base = existing ?? newSyncManifest(util.generateRandomUUID())
    let counter = current.counter
    const groups: SyncGroupState[] = []
    const staged: SyncGroupState[] = []
    const remaining: SyncGroupState[] = []
    const objects: SyncObject[] = []
    const applies: SyncApplyGroup[] = []
    const revisions: SyncOwnerRevision[] = []
    let datasets = base.datasets.slice()
    for (const row of prepared) {
      const remote = bySyncFact(row.remote)
      const local = byLocalValue(row.local.values)
      const prior = byLocalValue(row.previous?.baseline ?? [])
      const edits = bySyncFact(row.resetBaseline ? [] : row.previous?.facts ?? [])
      const pending = row.resetBaseline ? [] : row.previous?.pending.slice() ?? []
      const pendingBefore = pending.length
      const deferred = new Set<string>()
      const protectedKeys = new Set<string>(row.local.protectedKeys ?? [])
      const adopted = new Set<string>()
      const restoreEdits = restorableEdits(row.local)
      const selectedBundles = new Set<string>()
      restoreEdits.forEach((edit: SyncRestoreEdit): void => {
        if (edit.bundle !== undefined && conflictChoice(choices, row.id, edit.key)?.useBeforeRestore === true) {
          selectedBundles.add(edit.bundle)
        }
      })
      const useBeforeRestore = (edit: SyncRestoreEdit): boolean =>
        conflictChoice(choices, row.id, edit.key)?.useBeforeRestore === true ||
        (edit.bundle !== undefined && selectedBundles.has(edit.bundle))
      local.forEach((value: string, key: string): void => {
        if (protectedKeys.has(key) || restoreEdits.some((edit: SyncRestoreEdit): boolean => edit.key === key && useBeforeRestore(edit))) return
        const remoteFact = remote.get(key)
        const theirs = remoteFact === undefined ? undefined : syncVisibleValue(remoteFact)
        if (((row.requiresPreview && remoteFact !== undefined) || row.previous?.deferred?.includes(key) === true) &&
          theirs !== undefined && theirs !== value && conflictChoice(choices, row.id, key) === undefined) deferred.add(key)
      })
      const conflicts = Array.from(deferred).map(syncKeyParts)
      const isDeferred = (key: string): boolean => {
        if (deferred.has(key)) return true
        const parts = syncKeyParts(key)
        return conflicts.some((conflict: string[]): boolean =>
          (conflict[0] === 'book' && parts[0] === 'member' && parts[1] === conflict[1] && parts[2] === conflict[2]) ||
          (conflict[0] === 'category' && (parts[0] === 'order' || (parts[0] === 'member' && parts[3] === conflict[1]))) ||
          (conflict[0] === 'recent' && parts.length === 4 && parts[1] === conflict[1] && parts[2] === conflict[2]))
      }
      const editFact = (key: string, kind: SyncEditKind, value: string, remoteFact?: SyncFact, observed?: SyncVersion[],
        sharedVersion?: SyncVersion): void => {
        let fact = edits.get(key) ?? emptySyncFact(key)
        if (remoteFact !== undefined) fact = mergeSyncFacts([fact], [remoteFact])[0]
        const version: SyncVersion = sharedVersion ?? { replica: current.replica, sequence: ++counter }
        const edit: SyncEdit = { version, observed: observed ?? fact.seen, kind, value }
        const updated = applySyncEdit(fact, edit)
        checkSyncGroupFact(row.id, updated)
        edits.set(key, updated)
        pending.push({ key, version })
        if (value === '') prior.delete(key)
        else prior.set(key, value)
      }
      const bundleVersions = new Map<string, SyncVersion>()
      restoreEdits.forEach((edit: SyncRestoreEdit): void => {
        if (!useBeforeRestore(edit)) return
        deferred.delete(edit.key)
        let version = edit.bundle === undefined ? undefined : bundleVersions.get(edit.bundle)
        if (edit.bundle !== undefined && version === undefined) {
          version = { replica: current.replica, sequence: ++counter }
          bundleVersions.set(edit.bundle, version)
        }
        editFact(edit.key, edit.kind, edit.value, remote.get(edit.key),
          edit.kind === 'clear-observed' ? edit.observed : undefined, version)
        if (edit.followUp !== undefined) editFact(edit.key, 'set', edit.followUp)
        adopted.add(edit.key)
      })
      local.forEach((value: string, key: string): void => {
        if (isDeferred(key) || protectedKeys.has(key) || adopted.has(key)) return
        const remoteFact = remote.get(key)
        const theirs = remoteFact === undefined ? undefined : syncVisibleValue(remoteFact)
        const needsDecision = (row.requiresPreview || row.previous?.deferred?.includes(key) === true) &&
          remoteFact !== undefined && theirs !== value
        const choice = conflictChoice(choices, row.id, key)
        if (needsDecision && (choice?.useLocal === false || (theirs === undefined && choice === undefined))) {
          if (theirs !== undefined || remoteFact !== undefined) {
            editFact(key, theirs === undefined ? 'delete' : 'set', theirs ?? '', remoteFact)
          }
          return
        }
        if ((needsDecision && choice?.useLocal !== true) || (row.requiresPreview && theirs === value) ||
          (!row.requiresPreview && prior.get(key) === value && choice?.useLocal !== true) ||
          (row.id === 'reading' && !row.requiresPreview && choice?.useLocal !== true)) return
        editFact(key, 'set', value, row.requiresPreview || choice?.useLocal === true ? remoteFact : undefined)
      })
      row.removed.forEach((key: string): void => {
        if (!isDeferred(key) && !protectedKeys.has(key) && !local.has(key) && syncVisibleValue(edits.get(key) ?? emptySyncFact(key)) !== undefined) {
          editFact(key, 'delete', '')
        }
      })
      if (pending.length !== pendingBefore) {
        staged.push({ id: row.id, facts: Array.from(edits.values()), baseline: localValueRows(prior),
          pending: pending.slice(), deferred: row.previous?.deferred })
      }
      const facts = mergeSyncFacts(Array.from(edits.values()), row.remote)
      const changes: SyncLocalValue[] = []
      const baseline = row.local.values.slice()
      facts.forEach((fact: SyncFact): void => {
        const value = syncVisibleValue(fact)
        if (!isDeferred(fact.key) && !protectedKeys.has(fact.key) && value !== local.get(fact.key)) {
          changes.push({ key: fact.key, value: value ?? '' })
        }
      })
      const ref = datasets.find((dataset: SyncDatasetRef): boolean => dataset.id === row.id)
      const outgoing = facts.filter((fact: SyncFact): boolean => !isDeferred(fact.key) && !protectedKeys.has(fact.key))
        .concat(row.remote.filter((fact: SyncFact): boolean => isDeferred(fact.key) || protectedKeys.has(fact.key)))
      const published = bySyncFact(outgoing)
      const unpublished = pending.filter((item: SyncPendingEdit): boolean => {
        const fact = published.get(item.key)
        return fact === undefined || !syncObserves(fact.seen, item.version)
      })
      const built = buildSyncDataset(row.id, outgoing, base.epoch, ref, syncBucketKey)
      if (built.ref.shards.length > 0 || ref !== undefined) {
        datasets = datasets.filter((dataset: SyncDatasetRef): boolean => dataset.id !== row.id).concat(built.ref)
      }
      objects.push(...built.objects)
      const allDeferred = Array.from(new Set<string>(Array.from(deferred)
        .concat(facts.filter((fact: SyncFact): boolean => isDeferred(fact.key)).map((fact: SyncFact): string => fact.key))))
      groups.push({ id: row.id, facts, baseline, pending, deferred: allDeferred })
      remaining.push({ id: row.id, facts, baseline, pending: unpublished, deferred: allDeferred })
      applies.push({ group: row.id, changes })
      revisions.push({ group: row.id, revision: row.local.revision })
    }
    const outputBytes = datasets.filter((dataset: SyncDatasetRef): boolean =>
      prepared.some((group: PreparedGroup): boolean => group.id === dataset.id))
      .reduce((total: number, dataset: SyncDatasetRef): number => total + syncDatasetBytes(dataset), 0)
    if (outputBytes > SYNC_MAX_ROUND_BYTES) throw new Error('sync_round_too_large')
    datasets.sort((a: SyncDatasetRef, b: SyncDatasetRef): number => a.id < b.id ? -1 : a.id === b.id ? 0 : 1)
    const publish = existing === undefined || JSON.stringify(datasets) !== JSON.stringify(base.datasets)
    const manifest: SyncManifest = publish ? { format: base.format, schema: base.schema, minWriter: base.minWriter,
      space: base.space, revision: base.revision + 1, epoch: base.epoch, maintenance: base.maintenance,
      datasets, previous: base.datasets } : base
    return { manifest, objects, groups, staged, remaining, applies, revisions, counter, initialCounter: current.counter, publish }
  }

  private async assertRevisions(revisions: SyncOwnerRevision[]): Promise<void> {
    for (const item of revisions) {
      if ((await this.owner.snapshot(item.group, false)).revision !== item.revision) throw new Error('sync_preview_changed')
    }
  }

  private async execute(provider: DeviceSyncWebDav, prior: SyncSavedConnection | undefined, credential: string,
    selected: SyncGroup[], remote: SyncRemoteManifest, proposal: ProposedSync, guard: SyncRequestGuard,
    manualPreview: boolean, endpoint: string, reviewedGroups: PreparedGroup[] = []): Promise<void> {
    let groups = prior?.groups.slice() ?? []
    proposal.groups.forEach((row: SyncGroupState): void => { groups = replaceGroup(groups, row) })
    const connection: SyncSavedConnection = {
      credential, endpointIdentity: endpoint, space: proposal.manifest.space, revision: proposal.manifest.revision,
      manifestHash: proposal.publish ? syncDigest(JSON.stringify(proposal.manifest)) : remote.hash,
      selected, automatic: prior?.automatic ?? false, reviewRequired: groups.some((group: SyncGroupState): boolean =>
        selected.includes(group.id) && (group.deferred?.length ?? 0) > 0),
      requiresExplicitReview: false, lastSuccess: prior?.lastSuccess ?? 0, lastError: '', groups,
    }
    guard()
    this.storage.update((state: SyncLocalDocument): void => {
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
          groupRevisions: detached.groupRevisions, applies: detached.applies }
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
      state.intent = { connection, expected: remote.etag, sent: false, groupRevisions: proposal.revisions, applies: proposal.applies }
      state.retiredCredentials = state.retiredCredentials?.filter((ref: string): boolean => ref !== credential)
    })
    for (const object of proposal.objects) await provider.storeObject(object, guard)
    if (manualPreview) await this.assertRevisions(proposal.revisions)
    this.storage.update((state: SyncLocalDocument): void => {
      const intent = state.intent
      if (intent === undefined) throw new Error('sync_connection_changed')
      state.intent = { connection: intent.connection, expected: intent.expected, sent: true,
        detached: intent.detached, groupRevisions: intent.groupRevisions, applies: intent.applies }
    })
    let receipt: SyncRemoteManifest
    try {
      if (proposal.publish && !(await provider.publish(proposal.manifest, remote.etag, guard))) {
        this.storage.update((state: SyncLocalDocument): void => { state.intent = undefined })
        throw new Error(manualPreview ? 'sync_preview_changed' : 'sync_remote_changed')
      }
      receipt = await provider.readManifest(guard, proposal.publish ? '' : remote.etag)
    } catch (error) {
      const code = (error as Error).message
      // The durable intent has crossed the PUT boundary. An interrupted
      // transport cannot distinguish rejection from a committed manifest.
      if (proposal.publish && (code === 'sync_network_failed' || code === 'sync_server_unavailable')) {
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
    if (previousCredential !== undefined && previousCredential !== credential) {
      await this.removeUnusedCredential(previousCredential).catch((): void => {})
    }
  }

  private finishLocalReceipt(state: SyncLocalDocument, connection: SyncSavedConnection,
    committed: SyncGroupState[], localReceipt: string): void {
    const replaced = state.active
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
    active.groups = replaced?.space === connection.space ? replaced.groups.slice() : []
    committed.forEach((group: SyncGroupState): void => { active.groups = replaceGroup(active.groups, group) })
    active.lastSuccess = Date.now()
    state.active = active
    if (replaced !== undefined && replaced.credential !== connection.credential) {
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(replaced.credential)
    }
    state.archives = state.archives?.filter((entry: SyncSavedConnection): boolean => entry.endpointIdentity !== connection.endpointIdentity)
  }

  private async acknowledge(provider: DeviceSyncWebDav, connection: SyncSavedConnection, remote: SyncRemoteManifest,
    guard: SyncRequestGuard): Promise<void> {
    if (remote.manifest === undefined || remote.manifest.space !== connection.space) return
    const groups: SyncGroupState[] = []
    let budget = SYNC_MAX_ROUND_BYTES
    for (const group of connection.groups) {
      if (!connection.selected.includes(group.id)) continue
      const ref = remote.manifest.datasets.find((row: SyncDatasetRef): boolean => row.id === group.id)
      if (ref === undefined || group.pending.length === 0) {
        groups.push(group)
        continue
      }
      budget -= syncDatasetBytes(ref)
      if (budget < 0) throw new Error('sync_round_too_large')
      const facts = bySyncFact(await this.loadDataset(provider, ref, guard, group.id))
      const pending = group.pending.filter((row: SyncPendingEdit): boolean => {
        const remoteFact = facts.get(row.key)
        return remoteFact === undefined || !syncObserves(remoteFact.seen, row.version)
      })
      groups.push({ id: group.id, facts: group.facts, baseline: group.baseline, pending, deferred: group.deferred })
    }
    this.storage.update((state: SyncLocalDocument): void => {
      if (state.intent === undefined) return
      const confirmed = copySyncConnection(connection)
      confirmed.groups = groups
      state.intent = { connection: confirmed, expected: state.intent.expected, sent: state.intent.sent, detached: state.intent.detached,
        groupRevisions: state.intent.groupRevisions, applies: state.intent.applies }
    })
  }

  private async finishMaintenance(provider: DeviceSyncWebDav, remote: SyncRemoteManifest,
    guard: SyncRequestGuard): Promise<SyncRemoteManifest> {
    const current = remote.manifest
    if (current === undefined || !current.maintenance) return remote
    if (current.datasets.concat(current.previous).some((dataset: SyncDatasetRef): boolean =>
      dataset.schema !== 1 || !SYNC_GROUPS.includes(dataset.id as SyncGroup))) throw new Error('sync_update_required')
    const candidates = await provider.sweepable(current, guard)
    for (const path of candidates) await provider.removeUnreferenced(path, guard)
    const next: SyncManifest = { format: current.format, schema: current.schema, minWriter: current.minWriter,
      space: current.space, revision: current.revision + 1, epoch: current.epoch, maintenance: false,
      datasets: current.datasets, previous: current.previous }
    await provider.publish(next, remote.etag, guard)
    return provider.readManifest(guard)
  }

  private async maybeMaintain(provider: DeviceSyncWebDav, guard: SyncRequestGuard): Promise<void> {
    const active = this.active()
    if (active === undefined || active.revision === 0 || active.revision % 32 !== 0) return
    const remote = await provider.readManifest(guard)
    this.checkHighWater(active, remote)
    const current = remote.manifest
    if (current === undefined || current.maintenance || current.datasets.concat(current.previous)
      .some((dataset: SyncDatasetRef): boolean => dataset.schema !== 1 || !SYNC_GROUPS.includes(dataset.id as SyncGroup))) return
    const next: SyncManifest = { format: current.format, schema: current.schema, minWriter: current.minWriter,
      space: current.space, revision: current.revision + 1, epoch: current.epoch + 1, maintenance: true,
      datasets: current.datasets, previous: current.previous }
    if ((await provider.sweepable(next, guard)).length < 32 || !(await provider.publish(next, remote.etag, guard))) return
    await this.finishMaintenance(provider, await provider.readManifest(guard), guard)
  }

  private rememberRetired(ref: string): void {
    if (this.storage.load().retiredCredentials?.includes(ref)) return
    this.storage.update((state: SyncLocalDocument): void => {
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(ref)
    })
  }

  private async removeUnusedCredential(ref: string): Promise<void> {
    const state = this.storage.load()
    if (state.active?.credential === ref || (state.intent?.connection.credential === ref && !state.intent.detached)) return
    await clearSyncCredential(ref)
    this.storage.update((value: SyncLocalDocument): void => {
      value.retiredCredentials = value.retiredCredentials?.filter((item: string): boolean => item !== ref)
    })
  }

  setAutomatic(value: boolean): void {
    const current = this.storage.load()
    if (current.active === undefined || current.active.automatic === value) return
    this.storage.update((state: SyncLocalDocument): void => { if (state.active !== undefined) state.active.automatic = value })
  }

  setSelection(input: SyncGroup[]): void {
    const current = this.storage.load()
    if (current.active === undefined) return
    const selected = selectedGroups(input)
    if (selected.some((id: SyncGroup): boolean => !current.active?.selected.includes(id))) throw new Error('sync_review_required')
    this.generation++
    this.prepared = undefined
    current.active.selected.forEach((group: SyncGroup): void => {
      if (!selected.includes(group)) this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1)
    })
    this.storage.update((state: SyncLocalDocument): void => {
      const active = state.active
      const intent = state.intent
      if (active === undefined) return
      if (intent?.connection.space === active.space && active.selected.some((id: SyncGroup): boolean =>
        !selected.includes(id) && intent.connection.selected.includes(id))) {
        state.intent = detachedIntent(intent)
      }
      const explicit = syncRequiresExplicitReview(active)
      active.selected = selected
      if (!explicit) {
        active.reviewRequired = active.groups.some((group: SyncGroupState): boolean =>
          selected.includes(group.id) && (group.deferred?.length ?? 0) > 0)
      }
    })
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
    return fact === undefined ? undefined : syncVisibleValue(fact)
  }

  readingDecisions(): SyncReadingDecision[] {
    const group = this.active()?.groups.find((row: SyncGroupState): boolean => row.id === 'reading')
    if (group === undefined || this.readingScope() === '') return []
    const facts = bySyncFact(group.facts)
    const decisions: SyncReadingDecision[] = []
    group.facts.forEach((fact: SyncFact): void => {
      const parts = syncKeyParts(fact.key)
      if (parts[0] !== 'recent' && parts[0] !== 'position') return
      const byPosition = new Map<string, string>()
      syncVisibleHeads(fact).forEach((edit: SyncEdit): void => {
        const key = parts[0] === 'recent' ? (JSON.parse(edit.value) as SyncRecentValue).chapter : edit.value
        byPosition.set(key, edit.value)
      })
      const values = Array.from(byPosition.values())
      if (values.length < 2) return
      const recent = facts.get(syncKey(['recent', parts[1], parts[2]]))
      const label = recent === undefined ? undefined : syncVisibleValue(recent)
      decisions.push({ key: fact.key, title: label === undefined ? '' : (JSON.parse(label) as SyncRecentValue).title, values })
    })
    return decisions
  }

  async chooseReadingDecision(key: string, value: string): Promise<SyncVersion | undefined> {
    const scope = this.readingScope()
    await this.assertReadingUnprotected([key])
    if (scope !== this.readingScope()) throw new Error('sync_connection_changed')
    if (!this.readingDecisions().some((decision: SyncReadingDecision): boolean =>
      decision.key === key && decision.values.includes(value))) throw new Error('sync_preview_changed')
    return this.recordEdits('reading', [{ key, kind: 'set', value }])
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
    const current = this.storage.load()
    const active = current.active
    if (active === undefined || !active.selected.includes(group) || syncRequiresExplicitReview(active) || this.restoreInProgress) return
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
    const next: SyncGroupState = { id: previous.id, facts: Array.from(facts.values()), pending, baseline: rows, deferred: previous.deferred }
    this.storage.update((state: SyncLocalDocument): void => {
      if (changed) {
        state.counter = version.sequence
        if (state.active !== undefined) state.active.groups = replaceGroup(active.groups, next)
      }
      if (receipt !== undefined) {
        state.readingReceipts = (state.readingReceipts ?? []).filter((item: SyncReadingReceipt): boolean =>
          item.key !== receipt.key).concat({ key: receipt.key, id: receipt.id, version: changed ? version : undefined })
      }
    })
    return changed ? version : undefined
  }

  recoverOnForeground(): Promise<void> {
    if (this.running !== undefined) return this.running
    return this.start(async (): Promise<void> => {
      await this.cleanProbes()
      await this.recoverIntent()
    })
  }

  private rememberRemote(space: string, remote: SyncRemoteManifest): void {
    const manifest = remote.manifest
    if (manifest === undefined || manifest.space !== space || (this.active()?.revision ?? 0) >= manifest.revision) return
    this.storage.update((state: SyncLocalDocument): void => {
      if (state.active?.space !== space) return
      state.active.revision = manifest.revision
      state.active.manifestHash = remote.hash
    })
  }

  private async recoverIntent(): Promise<void> {
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
    const guard = this.guard(this.generation)
    const provider = new DeviceSyncWebDav(await readSyncCredential(connection.credential))
    const receipt = await provider.readManifest(guard)
    if (active?.space === connection.space) this.checkHighWater(active, receipt)
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
              baseline: currentGroup.baseline, pending: currentGroup.pending.concat(group.pending), deferred: currentGroup.deferred }
            value.active.groups = replaceGroup(value.active.groups, combined)
          })
        }
      })
      return
    }
    try {
      await this.assertRevisions(intent.groupRevisions)
    } catch (_error) {
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
    const accepted = this.storage.load().intent?.connection.groups ?? connection.groups
    const committed = applyReceiptBaselines(accepted, intent.applies)
    await this.owner.commit(intent.applies, intent.groupRevisions, (localReceipt: string): void => {
      guard()
      if (this.storage.load().counter !== starting.counter) throw new Error('sync_local_changed')
      this.storage.update((state: SyncLocalDocument): void => {
        this.finishLocalReceipt(state, connection, committed, localReceipt)
      })
    })
  }

  async disconnect(): Promise<void> {
    const current = this.storage.load()
    this.generation++
    this.prepared = undefined
    this.tested = undefined
    SYNC_GROUPS.forEach((group: SyncGroup): void => { this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1) })
    this.cache = []
    this.cacheSize = 0
    const active = current.active
    if (active === undefined) return
    const archive = copySyncConnection(active)
    archive.credential = ''
    archive.automatic = false
    this.storage.update((state: SyncLocalDocument): void => {
      state.active = undefined
      state.archives = (state.archives ?? []).filter((item: SyncSavedConnection): boolean =>
        item.endpointIdentity !== archive.endpointIdentity).concat(archive)
      state.retiredCredentials = (state.retiredCredentials ?? []).concat(active.credential)
      if (state.intent !== undefined) state.intent = detachedIntent(state.intent)
    })
    await this.removeUnusedCredential(active.credential)
  }

  beginRestore(): void {
    this.generation++
    this.prepared = undefined
    this.restoreInProgress = true
    SYNC_GROUPS.forEach((group: SyncGroup): void => { this.groupEpochs.set(group, (this.groupEpochs.get(group) ?? 0) + 1) })
    const current = this.storage.load()
    this.restoreBefore = current.active
    this.restoreBeforeIntent = current.intent
    if (this.restoreBefore !== undefined || this.restoreBeforeIntent !== undefined) {
      this.storage.update((state: SyncLocalDocument): void => {
        if (state.active !== undefined) {
          state.active.reviewRequired = true
          state.active.requiresExplicitReview = true
          state.active.restoreReview = true
        }
        if (state.intent !== undefined) state.intent = detachedIntent(state.intent)
      })
    }
  }

  finishRestore(committed: boolean): void {
    this.restoreInProgress = false
    const prior = this.restoreBefore
    const priorIntent = this.restoreBeforeIntent
    this.restoreBefore = undefined
    this.restoreBeforeIntent = undefined
    if (!committed && (prior !== undefined || priorIntent !== undefined)) {
      this.storage.update((state: SyncLocalDocument): void => {
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
