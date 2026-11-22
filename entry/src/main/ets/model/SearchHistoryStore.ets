import { BackupRestoreActivity } from './BackupRestoreActivity'
import { safeSyncSearch, syncSearchIdentity } from '../deviceSync/DeviceSyncData'
import { signalDeviceSyncChange, signalDeviceSyncSearchRemoved } from '../deviceSync/DeviceSyncSignals'
import { common } from '@kit.AbilityKit'
import { preferences, relationalStore } from '@kit.ArkData'
import { taskpool } from '@kit.ArkTS'
import { CrossSearchSourceFilter } from './CrossSearchService'
import { LibrarySearchSource, copyLibrarySearchSource } from './LibrarySearchQuery'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase, openUserDataSnapshotDatabase } from './UserDataDatabase'
import { writeUserRecords } from './UserKeyedRecords'

export interface SearchHistoryScope {
  syncSourceSet?: string
  sourceFilter?: CrossSearchSourceFilter
  librarySource?: LibrarySearchSource
}

export interface SearchHistoryEntry extends SearchHistoryScope {
  query: string
  updatedAt: number
}

export const SEARCH_HISTORY_STORE_NAME: string = 'koma_search_history_v1'
export const SEARCH_HISTORY_QUERIES_KEY: string = 'search.history.queries'
export const SEARCH_SOURCE_FILTER_KEY: string = 'search.source.filter'
const SEARCH_RESULTS_ONLY_KEY: string = 'search.results.only'
export const MAX_SEARCH_HISTORY_COUNT: number = 20

export interface SearchHistoryRecord {
  syncSourceSet?: string
  query?: string
  updatedAt?: number
  sourceFilter?: string
  librarySource?: LibrarySearchSource
}

export function parseStoredSearchHistory(payload: string): SearchHistoryEntry[] {
  const parsed = JSON.parse(payload) as SearchHistoryRecord[]
  if (!Array.isArray(parsed)) {
    throw new Error('search_history_invalid')
  }
  parsed.forEach((record: SearchHistoryRecord): void => {
    if (record === null || typeof record !== 'object' || Array.isArray(record) ||
      (record.query !== undefined && typeof record.query !== 'string') ||
      (record.updatedAt !== undefined && typeof record.updatedAt !== 'number') ||
      (record.sourceFilter !== undefined && typeof record.sourceFilter !== 'string') ||
      (record.syncSourceSet !== undefined && typeof record.syncSourceSet !== 'string') ||
      (record.librarySource !== undefined && (record.librarySource === null || typeof record.librarySource !== 'object' ||
        typeof record.librarySource.key !== 'string' || record.librarySource.key.trim().length === 0 ||
        typeof record.librarySource.name !== 'string' || record.librarySource.name.trim().length === 0))) {
      throw new Error('search_history_invalid')
    }
  })
  return normalizeSearchHistoryEntries(parsed)
}

export function searchHistoryEntryKey(query: string, scope?: SearchHistoryScope): string {
  if (scope?.syncSourceSet !== undefined) {
    return JSON.stringify([syncSearchIdentity(query), 'source', '', scope.syncSourceSet])
  }
  return JSON.stringify([normalizeSearchQuery(query).toLocaleLowerCase(), scope?.sourceFilter ?? 'all', scope?.librarySource?.key ?? ''])
}

function copyHistoryScope(target: SearchHistoryEntry, scope: SearchHistoryScope): void {
  target.syncSourceSet = scope.syncSourceSet
  if (scope.sourceFilter !== undefined) target.sourceFilter = normalizeSearchSourceFilter(scope.sourceFilter)
  if (scope.librarySource !== undefined) target.librarySource = copyLibrarySearchSource(scope.librarySource)
}

function normalizeSearchQuery(value: string): string {
  return value.trim().replace(/\s+/g, ' ')
}

function normalizeSearchHistoryTimestamp(value: number | undefined, fallback: number): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return fallback
  }
  return Math.floor(value)
}

export function normalizeSearchSourceFilter(value: string | undefined): CrossSearchSourceFilter {
  if (value === 'wasm') {
    return 'source'
  }
  if (value === 'local' || value === 'private' || value === 'source') {
    return value
  }
  return 'all'
}

export function normalizeSearchHistoryEntries(input: SearchHistoryRecord[], now: number = Date.now()): SearchHistoryEntry[] {
  const entries: SearchHistoryEntry[] = []
  // Preserve the locale-sensitive query and scope identity used by the search UI.
  const byKey = new Map<string, SearchHistoryEntry>()
  input.forEach((record: SearchHistoryRecord) => {
    const query = normalizeSearchQuery(record.query ?? '')
    if (query.length === 0 && record.librarySource === undefined) {
      return
    }
    const updatedAt = normalizeSearchHistoryTimestamp(record.updatedAt, now)
    const scope: SearchHistoryScope = {
      sourceFilter: record.sourceFilter === undefined ? undefined : normalizeSearchSourceFilter(record.sourceFilter),
      librarySource: record.librarySource,
      syncSourceSet: record.sourceFilter === 'source' && record.librarySource === undefined ? record.syncSourceSet : undefined,
    }
    const key = searchHistoryEntryKey(query, scope)
    const existing = byKey.get(key)
    if (existing === undefined) {
      const entry: SearchHistoryEntry = { query, updatedAt }
      copyHistoryScope(entry, scope)
      entries.push(entry)
      byKey.set(key, entry)
      return
    }
    if (updatedAt > existing.updatedAt) {
      existing.query = query
      existing.updatedAt = updatedAt
      copyHistoryScope(existing, scope)
    }
  })
  return entries.sort((left: SearchHistoryEntry, right: SearchHistoryEntry): number => {
    return right.updatedAt - left.updatedAt
  }).slice(0, MAX_SEARCH_HISTORY_COUNT)
}

export function addSearchHistoryEntry(entries: SearchHistoryEntry[], query: string, updatedAt: number = Date.now(), scope?: SearchHistoryScope): SearchHistoryEntry[] {
  const normalizedQuery = normalizeSearchQuery(query)
  if (normalizedQuery.length === 0 && scope?.librarySource === undefined) {
    return normalizeSearchHistoryEntries(entries)
  }
  const key = searchHistoryEntryKey(normalizedQuery, scope)
  const next = entries.filter((entry: SearchHistoryEntry): boolean => searchHistoryEntryKey(entry.query, entry) !== key)
  const entry: SearchHistoryEntry = { query: normalizedQuery, updatedAt: normalizeSearchHistoryTimestamp(updatedAt, Date.now()) }
  if (scope !== undefined) copyHistoryScope(entry, scope)
  next.unshift(entry)
  return normalizeSearchHistoryEntries(next)
}

export function removeSearchHistoryEntry(entries: SearchHistoryEntry[], query: string, scope?: SearchHistoryScope): SearchHistoryEntry[] {
  const normalizedQuery = normalizeSearchQuery(query)
  if (normalizedQuery.length === 0 && scope?.librarySource === undefined) {
    return normalizeSearchHistoryEntries(entries)
  }
  const key = scope === undefined ? '' : searchHistoryEntryKey(normalizedQuery, scope)
  return normalizeSearchHistoryEntries(entries).filter((entry: SearchHistoryEntry): boolean => {
    return scope === undefined ? entry.query.toLocaleLowerCase() !== normalizedQuery.toLocaleLowerCase() :
      searchHistoryEntryKey(entry.query, entry) !== key
  })
}

const HISTORY_MIGRATION = 'search-history-from-preferences-v1'
const SHARED_HISTORY_MIGRATION = 'search-history-shared-terms-v1'
const HISTORY_COLUMNS = 'entry_key, query, updated_at, list_order, source_filter, library_source_key, library_source_name, sync_source_set'
const SAVE_HISTORY_ROW = ' (' + HISTORY_COLUMNS + ') VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(entry_key) DO UPDATE SET ' +
  'query=excluded.query, updated_at=excluded.updated_at, list_order=excluded.list_order, ' +
  'source_filter=excluded.source_filter, library_source_key=excluded.library_source_key, ' +
  'library_source_name=excluded.library_source_name, sync_source_set=excluded.sync_source_set'

interface StoredSearchHistoryEntry {
  key: string
  table: string
  order: number
  value: SearchHistoryEntry
}

/** WebDAV also reads search history while the reader is moving. Keep the
 * ResultSet iteration and native completion callback off the UI thread. */
@Concurrent
async function readSearchHistoryRows(context: common.UIAbilityContext): Promise<StoredSearchHistoryEntry[]> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    const columns = 'entry_key, query, updated_at, list_order, source_filter, library_source_key, library_source_name, sync_source_set'
    const result = store.querySqlSync('SELECT ' + columns + ", 'search_history' FROM search_history UNION ALL " +
      'SELECT ' + columns + ", 'search_history_local' FROM search_history_local ORDER BY updated_at DESC, list_order")
    const rows: StoredSearchHistoryEntry[] = []
    try {
      while (result.goToNextRow()) {
        const value: SearchHistoryEntry = { query: result.getString(1), updatedAt: result.getLong(2) }
        if (!result.isColumnNull(4)) value.sourceFilter = result.getString(4) as CrossSearchSourceFilter
        if (!result.isColumnNull(5)) value.librarySource = { key: result.getString(5), name: result.getString(6) }
        if (!result.isColumnNull(7)) value.syncSourceSet = result.getString(7)
        rows.push({ key: result.getString(0), table: result.getString(8), order: result.getLong(3), value })
      }
    } finally {
      result.close()
    }
    return rows
  } finally {
    await store.close()
  }
}

// Search pages and WebDAV share one write order, including the first migration.
const searchHistoryOperations: Map<string, Promise<void>> = new Map()

export class SearchHistoryStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (searchHistoryOperations.get(key) ?? Promise.resolve()).then(operation)
    searchHistoryOperations.set(key, result.then(() => {}, () => {}))
    return result
  }

  async load(): Promise<SearchHistoryEntry[]> {
    return this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      return this.listEntries()
    })
  }

  async prepareStorage(): Promise<void> {
    await this.ordered(() => this.historyStore())
  }

  private async historyStore(): Promise<relationalStore.RdbStore> {
    const store = await openUserDataDatabase(this.context)
    if (hasUserDataMigration(store, SHARED_HISTORY_MIGRATION)) return store
    if (hasUserDataMigration(store, HISTORY_MIGRATION)) {
      const previous = await this.readRows()
      this.writeHistory(store, previous, previous.map((row: StoredSearchHistoryEntry): SearchHistoryEntry => row.value), true)
    } else {
      const legacy = await (await this.preferences()).get(SEARCH_HISTORY_QUERIES_KEY, '[]') as string
      // Commit even an empty migration. A later clear cannot reread the old key.
      this.writeHistory(store, [], parseStoredSearchHistory(legacy), true)
    }
    return store
  }

  private async readRows(): Promise<StoredSearchHistoryEntry[]> {
    const rows = await taskpool.execute(readSearchHistoryRows, this.context) as StoredSearchHistoryEntry[]
    for (const row of rows) {
      if (row.value.sourceFilter !== undefined) row.value.sourceFilter = normalizeSearchSourceFilter(row.value.sourceFilter)
    }
    return rows
  }

  private async listEntries(): Promise<SearchHistoryEntry[]> {
    await this.historyStore()
    const rows = await this.readRows()
    return normalizeSearchHistoryEntries(rows.map((row: StoredSearchHistoryEntry): SearchHistoryEntry => row.value))
  }

  private writeHistory(store: relationalStore.RdbStore, previous: StoredSearchHistoryEntry[],
    entries: SearchHistoryEntry[], migrating: boolean = false): void {
    const remaining = new Map<string, StoredSearchHistoryEntry>()
    previous.forEach((row: StoredSearchHistoryEntry): void => { remaining.set(row.table + ':' + row.key, row) })
    const sharedTerms = new Set<string>()
    // The list is bounded to 20 entries. Finish the write without yielding
    // while holding the shared database's write transaction.
    writeUserRecords(store, (): void => {
      if (migrating && hasUserDataMigration(store, SHARED_HISTORY_MIGRATION)) return
      let tieOrder = 0
      for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index]
        tieOrder = index > 0 && entries[index - 1].updatedAt === entry.updatedAt ? tieOrder + 1 : 0
        const term = safeSyncSearch(entry.query) ? syncSearchIdentity(entry.query) : ''
        // Each portable term has one real history row. The other local
        // contexts for that term and unsafe terms retain their own device rows.
        const shared = term !== '' && !sharedTerms.has(term)
        if (shared) sharedTerms.add(term)
        const table = shared ? 'search_history' : 'search_history_local'
        const key = shared ? term : searchHistoryEntryKey(entry.query, entry)
        const identity = table + ':' + key
        const old = remaining.get(identity)
        remaining.delete(identity)
        if (old !== undefined && old.order === tieOrder && old.value.query === entry.query &&
          old.value.updatedAt === entry.updatedAt && old.value.sourceFilter === entry.sourceFilter &&
          old.value.syncSourceSet === entry.syncSourceSet && old.value.librarySource?.name === entry.librarySource?.name &&
          old.value.librarySource?.key === entry.librarySource?.key) continue
        store.executeSync('INSERT INTO ' + table + SAVE_HISTORY_ROW, [key, entry.query, entry.updatedAt, tieOrder,
          entry.sourceFilter ?? null, entry.librarySource?.key ?? null, entry.librarySource?.name ?? null,
          entry.syncSourceSet ?? null])
      }
      for (const row of remaining.values()) {
        store.executeSync('DELETE FROM ' + row.table + ' WHERE entry_key = ?', [row.key])
      }
      if (migrating) {
        markUserDataMigration(store, HISTORY_MIGRATION)
        markUserDataMigration(store, SHARED_HISTORY_MIGRATION)
      }
    })
  }

  /** Capture the persisted value under the same ordering as UI reads and edits. */
  captureDeviceSyncPayload(): Promise<string> {
    return this.ordered(async (): Promise<string> => JSON.stringify(await this.listEntries()))
  }

  async record(query: string, scope?: SearchHistoryScope): Promise<SearchHistoryEntry[]> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      const store = await this.historyStore()
      const previous = await this.readRows()
      const entries = addSearchHistoryEntry(previous.map((row: StoredSearchHistoryEntry): SearchHistoryEntry => row.value),
        query, Date.now(), scope)
      this.writeHistory(store, previous, entries)
      signalDeviceSyncChange('search-history')
      return entries
    }))
  }

  async clear(): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      const store = await this.historyStore()
      this.writeHistory(store, await this.readRows(), [])
      signalDeviceSyncSearchRemoved()
    }))
  }

  async remove(query: string, scope?: SearchHistoryScope): Promise<SearchHistoryEntry[]> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      const store = await this.historyStore()
      const previous = await this.readRows()
      const term = syncSearchIdentity(query)
      const matching: StoredSearchHistoryEntry[] = []
      const others: SearchHistoryEntry[] = []
      for (const row of previous) {
        if (syncSearchIdentity(row.value.query) === term) matching.push(row)
        else others.push(row.value)
      }
      // A cloud merge can temporarily exceed the visible history limit.
      // Removing a term can change its representative, but owns no other term.
      const kept = removeSearchHistoryEntry(matching.map(row => row.value), query, scope)
      if (matching.length > 0) this.writeHistory(store, matching, kept)
      if (kept.length === 0) {
        signalDeviceSyncSearchRemoved(query)
      }
      return normalizeSearchHistoryEntries(others.concat(kept))
    }))
  }

  async applyDeviceSyncEntries(entries: SearchHistoryEntry[]): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await this.historyStore()
      this.writeHistory(store, await this.readRows(), normalizeSearchHistoryEntries(entries))
    })
  }

  async applyCloudTermRemovals(terms: Set<string>): Promise<void> {
    if (terms.size === 0) return
    await this.ordered(async (): Promise<void> => {
      const store = await this.historyStore()
      const rows = await this.readRows()
      const restored = new Set(rows.filter(row => row.table === 'search_history').map(row => row.key))
      const removed = rows.filter(row => {
        const term = syncSearchIdentity(row.value.query)
        return terms.has(term) && !restored.has(term) && safeSyncSearch(row.value.query)
      })
      if (removed.length > 0) this.writeHistory(store, removed, [])
    })
  }

  async loadSourceFilter(): Promise<CrossSearchSourceFilter> {
    return this.ordered(async (): Promise<CrossSearchSourceFilter> => {
      const store = await this.preferences()
      const value = await store.get(SEARCH_SOURCE_FILTER_KEY, 'all') as string
      return normalizeSearchSourceFilter(value)
    })
  }

  async saveSourceFilter(sourceFilter: CrossSearchSourceFilter): Promise<CrossSearchSourceFilter> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<CrossSearchSourceFilter> => {
      const normalized = normalizeSearchSourceFilter(sourceFilter)
      await this.commit(await this.preferences(), SEARCH_SOURCE_FILTER_KEY, normalized)
      return normalized
    }))
  }

  async loadResultsOnly(): Promise<boolean> {
    return this.ordered(async (): Promise<boolean> => {
      return await (await this.preferences()).get(SEARCH_RESULTS_ONLY_KEY, 'false') === 'true'
    })
  }

  async saveResultsOnly(value: boolean): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      await this.commit(await this.preferences(), SEARCH_RESULTS_ONLY_KEY, value ? 'true' : 'false')
    }))
  }

  private async commit(store: preferences.Preferences, key: string, value: string): Promise<void> {
    const existed = await store.has(key)
    const previous = await store.get(key, '')
    try {
      await store.put(key, value)
      await store.flush()
    } catch (error) {
      if (existed) await store.put(key, previous)
      else await store.delete(key)
      await store.flush()
      throw error as Error
    }
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, SEARCH_HISTORY_STORE_NAME)
  }
}
