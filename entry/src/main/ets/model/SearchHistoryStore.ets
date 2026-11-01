import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { CrossSearchSourceFilter } from './CrossSearchService'
import { LibrarySearchSource, copyLibrarySearchSource } from './LibrarySearchQuery'

export interface SearchHistoryScope {
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
  query?: string
  updatedAt?: number
  sourceFilter?: string
  librarySource?: LibrarySearchSource
}

export function searchHistoryEntryKey(query: string, scope?: SearchHistoryScope): string {
  return JSON.stringify([normalizeSearchQuery(query).toLocaleLowerCase(), scope?.sourceFilter ?? 'all', scope?.librarySource?.key ?? ''])
}

function copyHistoryScope(target: SearchHistoryEntry, scope: SearchHistoryScope): void {
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
  input.forEach((record: SearchHistoryRecord) => {
    const query = normalizeSearchQuery(record.query ?? '')
    if (query.length === 0 && record.librarySource === undefined) {
      return
    }
    const updatedAt = normalizeSearchHistoryTimestamp(record.updatedAt, now)
    const existing = entries.find((entry: SearchHistoryEntry): boolean => {
      return searchHistoryEntryKey(entry.query, entry) === searchHistoryEntryKey(query, {
        sourceFilter: record.sourceFilter === undefined ? undefined : normalizeSearchSourceFilter(record.sourceFilter),
        librarySource: record.librarySource,
      })
    })
    if (existing === undefined) {
      const entry: SearchHistoryEntry = { query, updatedAt }
      copyHistoryScope(entry, { sourceFilter: record.sourceFilter === undefined ? undefined : normalizeSearchSourceFilter(record.sourceFilter),
        librarySource: record.librarySource })
      entries.push(entry)
      return
    }
    if (updatedAt > existing.updatedAt) {
      existing.query = query
      existing.updatedAt = updatedAt
      copyHistoryScope(existing, { sourceFilter: record.sourceFilter === undefined ? undefined : normalizeSearchSourceFilter(record.sourceFilter),
        librarySource: record.librarySource })
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
  const next = entries.filter((entry: SearchHistoryEntry): boolean => {
    return searchHistoryEntryKey(entry.query, entry) !== searchHistoryEntryKey(normalizedQuery, scope)
  })
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
  return normalizeSearchHistoryEntries(entries).filter((entry: SearchHistoryEntry): boolean => {
    return scope === undefined ? entry.query.toLocaleLowerCase() !== normalizedQuery.toLocaleLowerCase() :
      searchHistoryEntryKey(entry.query, entry) !== searchHistoryEntryKey(normalizedQuery, scope)
  })
}

// One Preferences resource is shared by old and new SearchPage instances.
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
      return this.readEntries(await this.preferences())
    })
  }

  private async readEntries(store: preferences.Preferences): Promise<SearchHistoryEntry[]> {
    const payload = await store.get(SEARCH_HISTORY_QUERIES_KEY, '[]') as string
    const parsed = JSON.parse(payload) as SearchHistoryRecord[]
    if (!Array.isArray(parsed)) {
      throw new Error('search_history_invalid')
    }
    parsed.forEach((record: SearchHistoryRecord): void => {
      if (record === null || typeof record !== 'object' || Array.isArray(record) ||
        (record.query !== undefined && typeof record.query !== 'string') ||
        (record.updatedAt !== undefined && typeof record.updatedAt !== 'number') ||
        (record.sourceFilter !== undefined && typeof record.sourceFilter !== 'string') ||
        (record.librarySource !== undefined && (record.librarySource === null || typeof record.librarySource !== 'object' ||
          typeof record.librarySource.key !== 'string' || record.librarySource.key.trim().length === 0 ||
          typeof record.librarySource.name !== 'string' || record.librarySource.name.trim().length === 0))) {
        throw new Error('search_history_invalid')
      }
    })
    return normalizeSearchHistoryEntries(parsed)
  }

  async record(query: string, scope?: SearchHistoryScope): Promise<SearchHistoryEntry[]> {
    return this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      const store = await this.preferences()
      const entries = addSearchHistoryEntry(await this.readEntries(store), query, Date.now(), scope)
      await this.commit(store, SEARCH_HISTORY_QUERIES_KEY, JSON.stringify(entries))
      return entries
    })
  }

  async clear(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      await this.commit(await this.preferences(), SEARCH_HISTORY_QUERIES_KEY, '[]')
    })
  }

  async remove(query: string, scope?: SearchHistoryScope): Promise<SearchHistoryEntry[]> {
    return this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      const store = await this.preferences()
      const entries = removeSearchHistoryEntry(await this.readEntries(store), query, scope)
      await this.commit(store, SEARCH_HISTORY_QUERIES_KEY, JSON.stringify(entries))
      return entries
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
    return this.ordered(async (): Promise<CrossSearchSourceFilter> => {
      const normalized = normalizeSearchSourceFilter(sourceFilter)
      await this.commit(await this.preferences(), SEARCH_SOURCE_FILTER_KEY, normalized)
      return normalized
    })
  }

  async loadResultsOnly(): Promise<boolean> {
    return this.ordered(async (): Promise<boolean> => {
      return await (await this.preferences()).get(SEARCH_RESULTS_ONLY_KEY, 'false') === 'true'
    })
  }

  async saveResultsOnly(value: boolean): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      await this.commit(await this.preferences(), SEARCH_RESULTS_ONLY_KEY, value ? 'true' : 'false')
    })
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
