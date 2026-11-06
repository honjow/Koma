/** The wire-level facts are independent of WebDAV, clocks and local persistence. */
export type SyncGroup = 'shelf' | 'reading' | 'reader-settings' | 'source-subscriptions' | 'search-history'
export const SYNC_GROUPS: SyncGroup[] = ['shelf', 'reading', 'reader-settings', 'source-subscriptions', 'search-history']

export interface SyncVersion {
  replica: string
  sequence: number
}

export type SyncEditKind = 'set' | 'delete' | 'reset' | 'clear-observed'

export interface SyncEdit {
  version: SyncVersion
  observed: SyncVersion[]
  kind: SyncEditKind
  // Each group owns a closed schema for this canonical JSON value.
  value: string
}

export interface SyncFact {
  key: string
  seen: SyncVersion[]
  values: SyncEdit[]
  barriers: SyncEdit[]
  cleared: SyncVersion[]
}

const MAX_REPLICAS = 128
// Reading keys can include both opaque 512-character work and chapter IDs.
const MAX_KEY_LENGTH = 4096
const MAX_VALUE_LENGTH = 8192

export function isSyncReplica(value: string): boolean {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value)
}

function checkedVersion(version: SyncVersion): SyncVersion {
  if (!version || Object.keys(version).sort().join(',') !== 'replica,sequence' || !isSyncReplica(version.replica) || !Number.isSafeInteger(version.sequence) || version.sequence < 1) {
    throw new Error('sync_invalid_version')
  }
  return { replica: version.replica, sequence: version.sequence }
}

function compareReplica(a: string, b: string): number {
  return a === b ? 0 : a < b ? -1 : 1
}

function compareVersion(a: SyncVersion, b: SyncVersion): number {
  return compareReplica(a.replica, b.replica) || a.sequence - b.sequence
}

function versionKey(version: SyncVersion): string {
  return `${version.replica}:${version.sequence}`
}

export function syncObserves(vector: SyncVersion[], version: SyncVersion): boolean {
  return vector.some((candidate: SyncVersion): boolean =>
    candidate.replica === version.replica && candidate.sequence >= version.sequence)
}

export function mergeSyncVectors(a: SyncVersion[], b: SyncVersion[]): SyncVersion[] {
  const clocks = new Map<string, SyncVersion>()
  a.concat(b).forEach((value: SyncVersion): void => {
    const old = clocks.get(value.replica)
    if (old === undefined || old.sequence < value.sequence) clocks.set(value.replica, value)
  })
  if (clocks.size > MAX_REPLICAS) throw new Error('sync_replica_limit')
  return Array.from(clocks.values()).sort(compareVersion)
}

function checkedVector(vector: SyncVersion[]): SyncVersion[] {
  if (!Array.isArray(vector) || vector.length > MAX_REPLICAS) throw new Error('sync_invalid_vector')
  const canonical = mergeSyncVectors([], vector.map(checkedVersion))
  if (canonical.length !== vector.length) throw new Error('sync_duplicate_replica')
  return canonical
}

function isBarrier(kind: SyncEditKind): boolean {
  return kind === 'delete' || kind === 'reset'
}

function checkedEdit(edit: SyncEdit): SyncEdit {
  if (!edit || Object.keys(edit).sort().join(',') !== 'kind,observed,value,version' || typeof edit.value !== 'string' || edit.value.length > MAX_VALUE_LENGTH) {
    throw new Error('sync_invalid_edit')
  }
  const kind = edit.kind
  if (kind !== 'set' && kind !== 'reset' && kind !== 'delete' && kind !== 'clear-observed') {
    throw new Error('sync_unsupported_edit')
  }
  if ((kind === 'delete' || kind === 'clear-observed') !== (edit.value.length === 0)) {
    throw new Error('sync_invalid_edit_value')
  }
  const version = checkedVersion(edit.version)
  const observed = checkedVector(edit.observed)
  if (syncObserves(observed, version)) throw new Error('sync_invalid_causality')
  return { version, observed, kind, value: edit.value }
}

function checkedEdits(values: SyncEdit[], seen: SyncVersion[], barriers: boolean): SyncEdit[] {
  if (!Array.isArray(values) || values.length > MAX_REPLICAS) throw new Error('sync_invalid_heads')
  const known = new Set<string>()
  return values.map((input: SyncEdit): SyncEdit => {
    const edit = checkedEdit(input)
    const id = edit.version.replica
    if (known.has(id) || (barriers ? !isBarrier(edit.kind) : edit.kind !== 'set') ||
      !syncObserves(seen, edit.version) || edit.observed.some((version: SyncVersion): boolean => !syncObserves(seen, version))) {
      throw new Error('sync_invalid_head')
    }
    known.add(id)
    return edit
  }).sort((a: SyncEdit, b: SyncEdit): number => compareVersion(a.version, b.version))
}

function checkFactKey(key: string): void {
  if (typeof key !== 'string' || key.length === 0 || key.length > MAX_KEY_LENGTH) {
    throw new Error('sync_invalid_fact_key')
  }
}

export function emptySyncFact(key: string): SyncFact {
  checkFactKey(key)
  return { key, seen: [], values: [], barriers: [], cleared: [] }
}

/** Validates remote data before any owner sees it. A group still validates its own keys and values. */
export function checkedSyncFact(input: SyncFact): SyncFact {
  if (!input || Object.keys(input).sort().join(',') !== 'barriers,cleared,key,seen,values') {
    throw new Error('sync_unsupported_fact')
  }
  checkFactKey(input.key)
  const seen = checkedVector(input.seen)
  const cleared = checkedVector(input.cleared)
  if (cleared.some((version: SyncVersion): boolean => !syncObserves(seen, version))) {
    throw new Error('sync_invalid_clear')
  }
  const values = checkedEdits(input.values, seen, false)
  const barriers = checkedEdits(input.barriers, seen, true)
  if (values.some((value: SyncEdit): boolean => barriers.some((barrier: SyncEdit): boolean =>
    versionKey(value.version) === versionKey(barrier.version)))) {
    throw new Error('sync_duplicate_edit')
  }
  return { key: input.key, seen, values, barriers, cleared }
}

function withoutCovered(heads: SyncEdit[], vector: SyncVersion[]): SyncEdit[] {
  return heads.filter((edit: SyncEdit): boolean => !syncObserves(vector, edit.version))
}

/**
 * A reset is held independently of the current positive head. Otherwise a
 * causal reread would accidentally let a concurrent stale position win again.
 */
export function applySyncEdit(fact: SyncFact, input: SyncEdit): SyncFact {
  const edit = checkedEdit(input)
  if (syncObserves(fact.seen, edit.version)) return fact
  const seen = mergeSyncVectors(fact.seen, edit.observed.concat(edit.version))
  if (edit.kind === 'clear-observed') {
    const cleared = mergeSyncVectors(fact.cleared, edit.observed)
    return { key: fact.key, seen, cleared, values: withoutCovered(fact.values, cleared), barriers: fact.barriers }
  }
  if (isBarrier(edit.kind)) {
    const barriers = withoutCovered(fact.barriers, edit.observed).concat(edit)
    barriers.sort((a: SyncEdit, b: SyncEdit): number => compareVersion(a.version, b.version))
    return { key: fact.key, seen, cleared: fact.cleared, values: withoutCovered(fact.values, edit.observed), barriers }
  }
  const values = withoutCovered(fact.values, edit.observed).filter((value: SyncEdit): boolean =>
    value.version.replica !== edit.version.replica).concat(edit)
  values.sort((a: SyncEdit, b: SyncEdit): number => compareVersion(a.version, b.version))
  return { key: fact.key, seen, cleared: fact.cleared, values, barriers: fact.barriers }
}

function mergeHeads(a: SyncEdit[], aSeen: SyncVersion[], b: SyncEdit[], bSeen: SyncVersion[]): SyncEdit[] {
  const aByVersion = new Map<string, SyncEdit>()
  const bByVersion = new Map<string, SyncEdit>()
  a.forEach((edit: SyncEdit): void => { aByVersion.set(versionKey(edit.version), edit) })
  b.forEach((edit: SyncEdit): void => { bByVersion.set(versionKey(edit.version), edit) })
  const result: SyncEdit[] = []
  aByVersion.forEach((edit: SyncEdit, id: string): void => {
    const shared = bByVersion.get(id)
    if (shared !== undefined && JSON.stringify(edit) !== JSON.stringify(shared)) {
      throw new Error('sync_inconsistent_edit')
    }
    if (shared !== undefined || !syncObserves(bSeen, edit.version)) result.push(edit)
  })
  bByVersion.forEach((edit: SyncEdit, id: string): void => {
    if (!aByVersion.has(id) && !syncObserves(aSeen, edit.version)) result.push(edit)
  })
  return result.sort((left: SyncEdit, right: SyncEdit): number => compareVersion(left.version, right.version))
}

export function mergeSyncFact(a: SyncFact, b: SyncFact): SyncFact {
  if (a.key !== b.key) throw new Error('sync_fact_key_mismatch')
  const seen = mergeSyncVectors(a.seen, b.seen)
  const cleared = mergeSyncVectors(a.cleared, b.cleared)
  const values = withoutCovered(mergeHeads(a.values, a.seen, b.values, b.seen), cleared)
  const barriers = mergeHeads(a.barriers, a.seen, b.barriers, b.seen)
  return { key: a.key, seen, values, barriers, cleared }
}

export function mergeSyncFacts(local: SyncFact[], remote: SyncFact[]): SyncFact[] {
  const facts = new Map<string, SyncFact>()
  local.forEach((fact: SyncFact): void => { facts.set(fact.key, fact) })
  remote.forEach((fact: SyncFact): void => {
    const previous = facts.get(fact.key)
    facts.set(fact.key, previous === undefined ? fact : mergeSyncFact(previous, fact))
  })
  return Array.from(facts.values()).sort((a: SyncFact, b: SyncFact): number => compareReplica(a.key, b.key))
}

export function syncVisibleHeads(fact: SyncFact): SyncEdit[] {
  return fact.values.filter((value: SyncEdit): boolean =>
    !syncObserves(fact.cleared, value.version) &&
    fact.barriers.every((barrier: SyncEdit): boolean => syncObserves(value.observed, barrier.version)))
}

export function syncVisibleValue(fact: SyncFact): string | undefined {
  const values = syncVisibleHeads(fact)
  if (values.length > 0) return values[values.length - 1].value
  // Concurrent delete wins over a reset containing a value.
  if (fact.barriers.some((edit: SyncEdit): boolean => edit.kind === 'delete')) return undefined
  return fact.barriers.length === 0 ? undefined : fact.barriers[fact.barriers.length - 1].value
}
