import {
  applySyncEdit, emptySyncFact, mergeSyncFacts, syncObserves, syncVisibleHeads, syncVisibleValue, SyncEdit,
  SyncEditKind, SyncFact, SyncGroup, SyncVersion,
} from './DeviceSyncFacts'
import {
  checkSyncGroupFact, SyncChapterCatalog, SyncPositionValue, SyncRecentValue, syncBucketKey, syncGroupVisibleValue, syncKey, syncKeyParts,
  SYNC_READING_DATASET, SYNC_SHELF_CATALOG_DATASET, SYNC_READER_SETTINGS_DATASET, SYNC_SUBSCRIPTIONS_DATASET,
  SYNC_SEARCH_DATASET, syncShelfMove, syncShelfMoveDestination,
} from './DeviceSyncData'
import {
  buildSyncDataset, newSyncManifest, syncDatasetBytes, SyncDatasetRef, SyncManifest, SyncObject, SYNC_MAX_ROUND_BYTES,
} from './DeviceSyncWire'
import { SyncGroupState, SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision, SyncPendingEdit,
  SyncRestoreEdit } from './DeviceSyncStorage'
import { SyncApplyGroup } from './DeviceSyncOwner'

export interface SyncMergeChoice {
  group: SyncGroup
  key: string
  useLocal: boolean
  useBeforeRestore?: boolean
}

export interface PreparedGroup {
  coverUnavailable?: boolean
  id: SyncGroup
  local: SyncLocalSnapshot
  remote: SyncFact[]
  previous?: SyncGroupState
  requiresPreview: boolean
  resetBaseline: boolean
  removed: string[]
  published?: SyncFact[]
  migrating?: SyncFact[]
  degraded?: boolean
}

export interface ProposedSync {
  writtenDatasets?: string[]
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

export interface SyncPlanTransport {
  writer?: boolean
  shared?: boolean
  ownWritable?: boolean
  own?: SyncManifest
}

export function writeDatasetId(group: SyncGroup): string {
  if (group === 'reading') return SYNC_READING_DATASET
  if (group === 'shelf') return SYNC_SHELF_CATALOG_DATASET
  if (group === 'reader-settings') return SYNC_READER_SETTINGS_DATASET
  return group === 'source-subscriptions' ? SYNC_SUBSCRIPTIONS_DATASET : SYNC_SEARCH_DATASET
}

export function coverDatasetId(group: SyncGroup): string {
  // Older readers validate keys strictly in the existing datasets.
  return group === 'shelf' || group === 'reading' ? group + '-cover-records' : ''
}

export function writeDatasetIds(group: SyncGroup): string[] {
  const cover = coverDatasetId(group)
  return cover === '' ? [writeDatasetId(group)] : [writeDatasetId(group), cover]
}

export function isCoverKey(key: string): boolean {
  return key.startsWith('["cover",')
}

export function byLocalValue(values: SyncLocalValue[]): Map<string, string> {
  const map = new Map<string, string>()
  values.forEach((row: SyncLocalValue): void => { map.set(row.key, row.value) })
  return map
}

export function localValueRows(values: Map<string, string>): SyncLocalValue[] {
  const rows: SyncLocalValue[] = []
  values.forEach((value: string, key: string): void => { rows.push({ key, value }) })
  return rows
}

export function bySyncFact(facts: SyncFact[]): Map<string, SyncFact> {
  const map = new Map<string, SyncFact>()
  facts.forEach((fact: SyncFact): void => { map.set(fact.key, fact) })
  return map
}

function conflictChoice(choices: SyncMergeChoice[], group: SyncGroup, key: string): SyncMergeChoice | undefined {
  return choices.find((choice: SyncMergeChoice): boolean => choice.group === group && choice.key === key)
}

export function restorableEdits(local: SyncLocalSnapshot): SyncRestoreEdit[] {
  const all = local.restoreEdits ?? []
  return all.filter((edit: SyncRestoreEdit): boolean => !local.protectedKeys?.includes(edit.key) &&
    (edit.bundle === undefined || !all.some((related: SyncRestoreEdit): boolean =>
      edit.bundle === related.bundle && local.protectedKeys?.includes(related.key) === true)))
}

export function priorConflictRoots(group: PreparedGroup): string[] {
  const previous = group.previous
  if (previous === undefined) return []
  if (previous.deferredRoots !== undefined) return previous.deferredRoots
  const legacy = previous.deferred ?? []
  const baseline = byLocalValue(previous.baseline)
  const facts = bySyncFact(previous.facts)
  // Older profiles persisted both differences and their expanded dependencies.
  // A dependent key without a different value on both sides was never a choice.
  return legacy.filter((key: string): boolean => {
    if (!legacy.some((root: string): boolean => root !== key && dependsOnConflict(key, root))) return true
    const local = baseline.get(key)
    const fact = facts.get(key)
    const remote = fact === undefined ? undefined : syncGroupVisibleValue(group.id, fact)
    return local !== undefined && remote !== undefined && local !== remote
  })
}

// Use the reading timestamp for ordinary progress, including when enabling this
// scope. A deliberate backup restore still has its own review and recovery.
export function usesReadingTime(group: PreparedGroup, key: string): boolean {
  if (group.id !== 'reading' || group.resetBaseline) return false
  const kind = syncKeyParts(key)[0]
  return kind === 'position' || kind === 'recent'
}

function sameReadingLocation(kind: string, left: string, right: string): boolean {
  if (kind === 'position') return (JSON.parse(left) as SyncPositionValue).page === (JSON.parse(right) as SyncPositionValue).page
  const a = JSON.parse(left) as SyncRecentValue
  const b = JSON.parse(right) as SyncRecentValue
  return a.chapter === b.chapter && (a.savedPage === undefined || b.savedPage === undefined || a.savedPage === b.savedPage)
}

export function dependsOnConflict(key: string, root: string): boolean {
  const parts = syncKeyParts(key)
  const conflict = syncKeyParts(root)
  return (conflict[0] === 'book' && parts[0] === 'member' && parts[1] === conflict[1] && parts[2] === conflict[2]) ||
    (conflict[0] === 'category' && (parts[0] === 'order' || (parts[0] === 'member' && parts[3] === conflict[1]))) ||
    (conflict[0] === 'recent' && parts.length === 4 && parts[1] === conflict[1] && parts[2] === conflict[2])
}

export function isShelfBook(group: SyncGroup, key: string): boolean {
  return group === 'shelf' && syncKeyParts(key)[0] === 'book'
}

export function shelfMoveValue(group: SyncGroup, key: string, value: string | undefined): boolean {
  return isShelfBook(group, key) && syncShelfMove(value) !== undefined
}

export function sameShelfBook(group: SyncGroup, key: string, left: string | undefined, right: string | undefined): boolean {
  return isShelfBook(group, key) && left !== undefined && right !== undefined &&
    syncShelfMove(left) === undefined && syncShelfMove(right) === undefined
}

export function replaceGroup(groups: SyncGroupState[], next: SyncGroupState): SyncGroupState[] {
  return groups.filter((group: SyncGroupState): boolean => group.id !== next.id).concat(next)
}

export function hasLegacyRetainedDeletion(local: SyncLocalSnapshot, previous: SyncGroupState | undefined, key: string): boolean {
  if (previous === undefined || !local.retainedDeletionKeys?.includes(key) ||
    previous.baseline.some((item: SyncLocalValue): boolean => item.key === key)) return false
  const fact = previous.facts.find((item: SyncFact): boolean => item.key === key)
  return fact !== undefined && syncVisibleValue(fact) === undefined
}

export function planDeviceSync(prepared: PreparedGroup[], existing: SyncManifest | undefined, choices: SyncMergeChoice[],
  space: string, projectOnly: boolean, replica: string, initialCounter: number, transport?: SyncPlanTransport): ProposedSync {
  const writer = transport?.writer === true
  const base = (writer ? transport?.own : existing) ?? newSyncManifest(space)
  let counter = initialCounter
  const groups: SyncGroupState[] = []
  const staged: SyncGroupState[] = []
  const remaining: SyncGroupState[] = []
  const objects: SyncObject[] = []
  const applies: SyncApplyGroup[] = []
  const revisions: SyncOwnerRevision[] = []
  let datasets = base.datasets.slice()
  let alternatives = base.alternatives?.slice() ?? []
  for (const row of prepared) {
    if (row.degraded === true) {
      const changes: SyncLocalValue[] = []
      const facts = row.remote.filter((fact: SyncFact): boolean => {
        if (row.local.protectedKeys?.includes(fact.key)) return false
        const value = syncGroupVisibleValue(row.id, fact)
        if (value !== undefined && shelfMoveValue(row.id, fact.key, value)) return false
        if (value !== undefined) changes.push({ key: fact.key, value })
        // Keep observed deletion dots for a future complete round, without
        // applying deletions or writing any recovered data back to WebDAV.
        return true
      })
      const group: SyncGroupState = { id: row.id, facts, baseline: row.local.values.slice(), pending: [] }
      groups.push(group)
      remaining.push(group)
      applies.push({ group: row.id, changes })
      revisions.push({ group: row.id, revision: row.local.revision })
      continue
    }
    const remote = bySyncFact(row.remote)
    const local = byLocalValue(row.local.values)
    const prior = byLocalValue(row.previous?.baseline ?? [])
    const edits = bySyncFact(row.resetBaseline ? [] : row.previous?.facts ?? [])
    const pending = row.resetBaseline ? [] : row.previous?.pending.slice() ?? []
    const pendingBefore = pending.length
    const protectedKeys = new Set<string>(row.local.protectedKeys ?? [])
    const previousRoots = priorConflictRoots(row)
    // Old review flags are not permission gates for already selected data.
    // The facts retain both candidates and owner protection still applies.
    const automaticMerge = !row.requiresPreview && choices.length === 0
    const reviewRoots = automaticMerge ? previousRoots.filter((key: string): boolean => protectedKeys.has(key)) : previousRoots
    const deferred = new Set<string>(reviewRoots.filter((key: string): boolean =>
      (protectedKeys.has(key) || !local.has(key)) && conflictChoice(choices, row.id, key) === undefined))
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
      if (isCoverKey(key) || protectedKeys.has(key) ||
        restoreEdits.some((edit: SyncRestoreEdit): boolean => edit.key === key && useBeforeRestore(edit))) return
      const remoteFact = remote.get(key)
      const theirs = remoteFact === undefined ? undefined : syncGroupVisibleValue(row.id, remoteFact)
      if (!usesReadingTime(row, key) && !sameShelfBook(row.id, key, value, theirs) &&
        ((row.requiresPreview && remoteFact !== undefined) || reviewRoots.includes(key)) &&
        theirs !== undefined && theirs !== value && !shelfMoveValue(row.id, key, theirs) &&
        conflictChoice(choices, row.id, key) === undefined) deferred.add(key)
    })
    const conflictRoots = Array.from(deferred)
    const heldReadingWorks = new Set<string>()
    const isDeferred = (key: string): boolean => {
      if (deferred.has(key)) return true
      if (heldReadingWorks.size > 0 && usesReadingTime(row, key) &&
        heldReadingWorks.has(syncBucketKey(key))) return true
      if (automaticMerge) return false
      return conflictRoots.some((root: string): boolean => deferred.has(root) && dependsOnConflict(key, root))
    }
    const editFact = (key: string, kind: SyncEditKind, value: string, remoteFact?: SyncFact, observed?: SyncVersion[],
      sharedVersion?: SyncVersion): void => {
      let fact = edits.get(key) ?? emptySyncFact(key)
      if (remoteFact !== undefined) fact = mergeSyncFacts([fact], [remoteFact])[0]
      const version: SyncVersion = sharedVersion ?? { replica: replica, sequence: ++counter }
      const edit: SyncEdit = { version, observed: observed ?? fact.seen, kind, value }
      const updated = applySyncEdit(fact, edit)
      checkSyncGroupFact(row.id, updated)
      edits.set(key, updated)
      pending.push({ key, version })
      if (value === '') prior.delete(key)
      else prior.set(key, value)
    }
    const bundleVersions = new Map<string, SyncVersion>()
    if (automaticMerge) {
      previousRoots.forEach((key: string): void => {
        const value = local.get(key)
        const fact = edits.get(key)
        // V2 review could hold an owner's value before giving it a dot.
        // Preserve that value as a concurrent candidate before releasing
        // the old review. Do not claim it saw a remote deletion or edit.
        if (value !== undefined && !protectedKeys.has(key) && value !== syncVisibleValue(fact ?? emptySyncFact(key)) &&
          !fact?.values.some((candidate: SyncEdit): boolean => candidate.value === value)) {
          editFact(key, 'set', value, undefined, [])
        }
      })
    }
    restoreEdits.forEach((edit: SyncRestoreEdit): void => {
      if (!useBeforeRestore(edit)) return
      deferred.delete(edit.key)
      let version = edit.bundle === undefined ? undefined : bundleVersions.get(edit.bundle)
      if (edit.bundle !== undefined && version === undefined) {
        version = { replica: replica, sequence: ++counter }
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
      const theirs = remoteFact === undefined ? undefined : syncGroupVisibleValue(row.id, remoteFact)
      const recorded = edits.get(key)
      if (isCoverKey(key)) {
        if (row.coverUnavailable !== true && remoteFact === undefined && recorded === undefined) editFact(key, 'set', value)
        return
      }
      // A fresh device's built-in defaults are not new edits. Once it has
      // a baseline, returning to the default is a normal, shareable change.
      if (automaticMerge && theirs !== undefined && recorded === undefined && !prior.has(key) &&
        row.local.defaultKeys?.includes(key) === true) return
      const automaticReading = theirs !== undefined && usesReadingTime(row, key)
      const needsDecision = !automaticReading && (row.requiresPreview || reviewRoots.includes(key)) &&
        remoteFact !== undefined && theirs !== value && !sameShelfBook(row.id, key, value, theirs)
      const choice = conflictChoice(choices, row.id, key)
      // A completed older receipt could omit a fixed setting's baseline.
      // Its already-observed tombstone is not evidence of a new local edit.
      if (!row.resetBaseline && theirs === undefined && hasLegacyRetainedDeletion(row.local, row.previous, key) &&
        choice?.useLocal !== true) return
      if (needsDecision && theirs === undefined && row.local.retainedDeletionKeys?.includes(key) && choice?.useLocal !== true) return
      // The review shows the same default as an ordinary removal, but a
      // received move must keep its dependency and its original version.
      if (needsDecision && choice?.useLocal !== true && shelfMoveValue(row.id, key, theirs)) return
      if (needsDecision && (choice?.useLocal === false || (theirs === undefined && choice === undefined))) {
        if (theirs !== undefined || remoteFact !== undefined) {
          editFact(key, theirs === undefined ? 'delete' : 'set', theirs ?? '', remoteFact)
        }
        return
      }
      if ((needsDecision && choice?.useLocal !== true) || (row.requiresPreview && theirs === value) ||
        (choice?.useLocal !== true && sameShelfBook(row.id, key, value,
          theirs ?? (recorded === undefined ? undefined : syncGroupVisibleValue(row.id, recorded))))) return
      if ((!row.requiresPreview || automaticReading) && choice?.useLocal !== true) {
        if (row.id === 'reading') {
          const existing = recorded === undefined ? remoteFact : remoteFact === undefined ? recorded :
            mergeSyncFacts([recorded], [remoteFact])[0]
          if (existing !== undefined) {
            const currentValue = syncVisibleValue(existing)
            // Older clients could save a newer position without staging it
            // for sync. Keep a distinct local save even if device clocks
            // disagree. An unchanged receive projection is not a local save.
            const kind = syncKeyParts(key)[0]
            if ((kind !== 'position' && kind !== 'recent') || currentValue === undefined || prior.get(key) === value ||
              pending.some((item: SyncPendingEdit): boolean => item.key === key) ||
              existing.barriers.length > 0 || existing.cleared.length > 0 ||
              existing.values.some((candidate: SyncEdit): boolean => candidate.value === value)) return
            // Opening the same page can update local history without producing
            // a reader capture. That timestamp alone cannot create a branch.
            const baseline = prior.get(key)
            if (transport?.shared === true && baseline !== undefined && sameReadingLocation(kind, baseline, value)) return
            const localDate = (JSON.parse(value) as SyncRecentValue).date
            if (localDate === undefined || localDate <= 0) return
            // The local save could only have observed the previous local
            // baseline, not records first seen in this round.
            editFact(key, 'set', value, remoteFact, recorded?.seen ?? [])
            return
          }
        } else if (prior.get(key) === value ||
          (!shelfMoveValue(row.id, key, value) && shelfMoveValue(row.id, key,
            recorded === undefined ? theirs : syncGroupVisibleValue(row.id, recorded)))) return
      }
      const kind: SyncEditKind = shelfMoveValue(row.id, key, value) ? 'reset' : 'set'
      editFact(key, kind, value, row.requiresPreview || choice?.useLocal === true ? remoteFact : undefined)
    })
    // A catalog block key includes the catalog digest. Without this pass every
    // catalog refresh leaves the previous block set in the writer's facts,
    // so a daily-updated shelf keeps re-uploading and re-reading old catalogs.
    if (row.id === 'shelf') {
      const currentCatalogDigests = new Map<string, string>()
      row.local.values.forEach((item: SyncLocalValue): void => {
        const parts = syncKeyParts(item.key)
        if (parts[0] !== 'chapter-catalog') return
        const header = JSON.parse(item.value) as SyncChapterCatalog
        currentCatalogDigests.set(syncKey([parts[1], parts[2]]), header.digest)
      })
      Array.from(edits.keys()).forEach((key: string): void => {
        const parts = syncKeyParts(key)
        if (parts[0] !== 'chapter-catalog-block') return
        const current = currentCatalogDigests.get(syncKey([parts[1], parts[2]]))
        if (current === undefined || parts[3] === current || isDeferred(key) || protectedKeys.has(key)) return
        const fact = edits.get(key)
        if (fact === undefined || syncVisibleValue(fact) === undefined) return
        editFact(key, 'delete', '')
      })
    }
    row.removed.forEach((key: string): void => {
      if (row.id === 'shelf') {
        const parts = syncKeyParts(key)
        if (parts[0] === 'book' || parts[0] === 'member') {
          const book = syncKey(['book', parts[1], parts[2]])
          const oldBook = edits.get(book)
          const newBook = remote.get(book)
          const candidates = mergeSyncFacts(oldBook === undefined ? [] : [oldBook], newBook === undefined ? [] : [newBook])
          if (candidates.length > 0 && shelfMoveValue(row.id, book, syncGroupVisibleValue(row.id, candidates[0]))) return
        }
      }
      if (!isDeferred(key) && !protectedKeys.has(key) && !local.has(key) && syncVisibleValue(edits.get(key) ?? emptySyncFact(key)) !== undefined) {
        editFact(key, 'delete', '')
      }
    })
    if (transport?.shared === true && automaticMerge && row.id === 'reading') {
      // Keep an independent local save and the published position on their
      // respective devices until the existing resume choice resolves them.
      for (const item of pending) {
        if (!usesReadingTime(row, item.key)) continue
        const localFact = edits.get(item.key)
        const remoteFact = remote.get(item.key)
        if (localFact === undefined || remoteFact === undefined) continue
        const localEdit = syncVisibleHeads(localFact).find((head: SyncEdit): boolean =>
          head.version.replica === item.version.replica && head.version.sequence === item.version.sequence)
        if (localEdit === undefined) continue
        const kind = syncKeyParts(item.key)[0]
        if (syncVisibleHeads(remoteFact).some((head: SyncEdit): boolean =>
          !syncObserves(localEdit.observed, head.version) && !syncObserves(head.observed, localEdit.version) &&
          (head.version.replica !== localEdit.version.replica || head.version.sequence !== localEdit.version.sequence) &&
          !sameReadingLocation(kind, localEdit.value, head.value))) heldReadingWorks.add(syncBucketKey(item.key))
      }
    }
    if (pending.length !== pendingBefore) {
      staged.push({ id: row.id, facts: Array.from(edits.values()), baseline: localValueRows(prior),
        pending: pending.slice(), deferred: row.previous?.deferred, deferredRoots: row.previous?.deferredRoots })
    }
    const facts = mergeSyncFacts(Array.from(edits.values()), row.remote)
    const divergentReadingWorks = new Set<string>()
    if (transport?.shared === true && automaticMerge && row.id === 'reading') {
      for (const fact of facts) {
        if (!usesReadingTime(row, fact.key)) continue
        const saved = local.get(fact.key)
        if (saved === undefined) continue
        const heads = syncVisibleHeads(fact)
        if (heads.length < 2) continue
        const kind = syncKeyParts(fact.key)[0]
        if (heads.some((head: SyncEdit): boolean => sameReadingLocation(kind, head.value, saved)) &&
          heads.some((head: SyncEdit): boolean => !sameReadingLocation(kind, head.value, saved))) {
          divergentReadingWorks.add(syncBucketKey(fact.key))
        }
      }
    }
    const accepted = bySyncFact(facts)
    const visible = (key: string): string | undefined => {
      const fact = accepted.get(key)
      return fact === undefined || isDeferred(key) || protectedKeys.has(key) ? undefined : syncGroupVisibleValue(row.id, fact)
    }
    const changes: SyncLocalValue[] = []
    const baseline = row.local.values.slice()
    facts.forEach((fact: SyncFact): void => {
      const value = syncGroupVisibleValue(row.id, fact)
      if (isCoverKey(fact.key) && (value === undefined || local.has(fact.key))) return
      if (value !== undefined && divergentReadingWorks.size > 0 && usesReadingTime(row, fact.key) &&
        divergentReadingWorks.has(syncBucketKey(fact.key))) return
      if (!isDeferred(fact.key) && !protectedKeys.has(fact.key) && value !== local.get(fact.key)) {
        if (row.id === 'shelf') {
          const parts = syncKeyParts(fact.key)
          if (parts[0] === 'member' && syncShelfMove(visible(syncKey(['book', parts[1], parts[2]]))) !== undefined) return
          if (shelfMoveValue(row.id, fact.key, value)) {
            if (!local.has(fact.key)) return
            const target = syncShelfMoveDestination(fact.key, visible, (key: string): boolean =>
              accepted.has(key) && !isDeferred(key) && !protectedKeys.has(key))
            if (target === undefined) return
            changes.push({ key: fact.key, value: JSON.stringify(target) })
            return
          }
        }
        // Keep the real owner value and its baseline. Dropping only the UI
        // count would still delete the receipt baseline and resurrect this
        // old setting on the next ordinary sync.
        if (value === undefined && row.local.retainedDeletionKeys?.includes(fact.key)) return
        changes.push({ key: fact.key, value: value ?? '' })
      }
    })
    let outgoing = facts.filter((fact: SyncFact): boolean => !isDeferred(fact.key) && !protectedKeys.has(fact.key))
      .concat(row.remote.filter((fact: SyncFact): boolean => isDeferred(fact.key) || protectedKeys.has(fact.key)))
    if (writer) {
      const touched = new Set<string>(pending.map((item: SyncPendingEdit): string => item.key))
      const owned = bySyncFact(mergeSyncFacts(row.published ?? [], row.migrating ?? []))
      outgoing.forEach((fact: SyncFact): void => {
        // The causal vector and heads must travel together for a touched key.
        // Receiving another writer's data alone never republishes its facts.
        if (touched.has(fact.key) && !isDeferred(fact.key) && !protectedKeys.has(fact.key)) owned.set(fact.key, fact)
      })
      outgoing = Array.from(owned.values())
    }
    const published = bySyncFact(outgoing)
    const unpublished = pending.filter((item: SyncPendingEdit): boolean => {
      if (row.coverUnavailable === true && isCoverKey(item.key)) return true
      const fact = published.get(item.key)
      return fact === undefined || !syncObserves(fact.seen, item.version)
    })
    if (!projectOnly) {
      for (const datasetId of writeDatasetIds(row.id)) {
        const ref = datasets.find((dataset: SyncDatasetRef): boolean => dataset.id === datasetId)
        const covers = datasetId === coverDatasetId(row.id)
        if (covers && row.coverUnavailable === true) continue
        const records = outgoing.filter((fact: SyncFact): boolean => isCoverKey(fact.key) === covers)
        const built = buildSyncDataset(datasetId, records, base.epoch, ref, syncBucketKey, transport?.shared === true)
        alternatives = alternatives.filter((entry: SyncDatasetRef): boolean => entry.id !== datasetId)
        if (built.ref.shards.length > 0 || ref !== undefined) {
          datasets = datasets.filter((dataset: SyncDatasetRef): boolean => dataset.id !== datasetId).concat(built.ref)
        }
        objects.push(...built.objects)
      }
    }
    const allDeferred = Array.from(new Set<string>(Array.from(deferred)
      .concat(facts.filter((fact: SyncFact): boolean => isDeferred(fact.key)).map((fact: SyncFact): string => fact.key))))
    const deferredRoots = Array.from(deferred)
    groups.push({ id: row.id, facts, baseline, pending, deferred: allDeferred, deferredRoots })
    remaining.push({ id: row.id, facts, baseline, pending: unpublished, deferred: allDeferred, deferredRoots })
    let applicable = changes
    if (row.local.readingHistoryKeys !== undefined && changes.some((change: SyncLocalValue): boolean => isCoverKey(change.key))) {
      const applied = byLocalValue(changes)
      const histories = new Set<string>(row.local.readingHistoryKeys)
      applicable = changes.filter((change: SyncLocalValue): boolean => {
        if (!isCoverKey(change.key)) return true
        // A cover is applied to a history entry. Keep the shared cover available
        // for a future entry without counting or writing it on every round.
        const parts = syncKeyParts(change.key)
        const recent = syncKey(['recent', parts[1], parts[2]])
        const next = applied.get(recent)
        return next === undefined ? histories.has(recent) : next !== ''
      })
    }
    applies.push({ group: row.id, changes: applicable })
    revisions.push({ group: row.id, revision: row.local.revision })
  }
  const outputBytes = datasets.filter((dataset: SyncDatasetRef): boolean =>
    prepared.some((group: PreparedGroup): boolean => writeDatasetId(group.id) === dataset.id ||
      (group.coverUnavailable !== true && coverDatasetId(group.id) === dataset.id)))
    .reduce((total: number, dataset: SyncDatasetRef): number => total + syncDatasetBytes(dataset), 0)
  if (outputBytes > SYNC_MAX_ROUND_BYTES) throw new Error('sync_round_too_large')
  datasets.sort((a: SyncDatasetRef, b: SyncDatasetRef): number => a.id < b.id ? -1 : a.id === b.id ? 0 : 1)
  const publish = transport?.ownWritable !== false && (existing === undefined || JSON.stringify(datasets) !== JSON.stringify(base.datasets) ||
    JSON.stringify(alternatives) !== JSON.stringify(base.alternatives ?? []))
  if (transport?.ownWritable === false) {
    objects.splice(0)
    remaining.splice(0, remaining.length, ...groups)
  }
  const manifest: SyncManifest = publish ? { format: base.format, schema: base.schema, minWriter: base.minWriter,
    space: base.space, revision: base.revision + 1, epoch: base.epoch, maintenance: base.maintenance,
    datasets, previous: writer || transport?.shared === true ? [] : base.datasets, alternatives,
    legacyMigration: base.legacyMigration } : writer ? existing ?? base : base
  // V3 republishes the writer's unchanged refs verbatim. Verify new refs
  // here, so known damage in an unrelated old group cannot block a repair.
  const writtenDatasets = writer ? datasets.filter((ref: SyncDatasetRef): boolean =>
    !base.datasets.some((old: SyncDatasetRef): boolean => JSON.stringify(old) === JSON.stringify(ref)))
    .map((ref: SyncDatasetRef): string => ref.id) : undefined
  return { manifest, objects, groups, staged, remaining, applies, revisions, counter, initialCounter,
    publish, writtenDatasets }
}
