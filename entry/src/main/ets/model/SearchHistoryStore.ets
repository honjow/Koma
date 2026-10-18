import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { CrossSearchSourceFilter } from './CrossSearchService'

export interface SearchHistoryEntry {
  query: string
  updatedAt: number
}

export const SEARCH_HISTORY_STORE_NAME: string = 'koma_search_history_v1'
export const SEARCH_HISTORY_QUERIES_KEY: string = 'search.history.queries'
export const SEARCH_SOURCE_FILTER_KEY: string = 'search.source.filter'
export const MAX_SEARCH_HISTORY_COUNT: number = 20

export interface SearchHistoryRecord {
  query?: string
  updatedAt?: number
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
    if (query.length === 0) {
      return
    }
    const updatedAt = normalizeSearchHistoryTimestamp(record.updatedAt, now)
    const existing = entries.find((entry: SearchHistoryEntry): boolean => {
      return entry.query.toLocaleLowerCase() === query.toLocaleLowerCase()
    })
    if (existing === undefined) {
      entries.push({ query, updatedAt })
      return
    }
    if (updatedAt > existing.updatedAt) {
      existing.query = query
      existing.updatedAt = updatedAt
    }
  })
  return entries.sort((left: SearchHistoryEntry, right: SearchHistoryEntry): number => {
    return right.updatedAt - left.updatedAt
  }).slice(0, MAX_SEARCH_HISTORY_COUNT)
}

export function addSearchHistoryEntry(entries: SearchHistoryEntry[], query: string, updatedAt: number = Date.now()): SearchHistoryEntry[] {
  const normalizedQuery = normalizeSearchQuery(query)
  if (normalizedQuery.length === 0) {
    return normalizeSearchHistoryEntries(entries)
  }
  const next = entries.filter((entry: SearchHistoryEntry): boolean => {
    return entry.query.toLocaleLowerCase() !== normalizedQuery.toLocaleLowerCase()
  })
  next.unshift({ query: normalizedQuery, updatedAt: normalizeSearchHistoryTimestamp(updatedAt, Date.now()) })
  return normalizeSearchHistoryEntries(next)
}

export function removeSearchHistoryEntry(entries: SearchHistoryEntry[], query: string): SearchHistoryEntry[] {
  const normalizedQuery = normalizeSearchQuery(query)
  if (normalizedQuery.length === 0) {
    return normalizeSearchHistoryEntries(entries)
  }
  return normalizeSearchHistoryEntries(entries).filter((entry: SearchHistoryEntry): boolean => {
    return entry.query.toLocaleLowerCase() !== normalizedQuery.toLocaleLowerCase()
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
        (record.updatedAt !== undefined && typeof record.updatedAt !== 'number')) {
        throw new Error('search_history_invalid')
      }
    })
    return normalizeSearchHistoryEntries(parsed)
  }

  async record(query: string): Promise<SearchHistoryEntry[]> {
    return this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      const store = await this.preferences()
      const entries = addSearchHistoryEntry(await this.readEntries(store), query)
      await this.commit(store, SEARCH_HISTORY_QUERIES_KEY, JSON.stringify(entries))
      return entries
    })
  }

  async clear(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      await this.commit(await this.preferences(), SEARCH_HISTORY_QUERIES_KEY, '[]')
    })
  }

  async remove(query: string): Promise<SearchHistoryEntry[]> {
    return this.ordered(async (): Promise<SearchHistoryEntry[]> => {
      const store = await this.preferences()
      const entries = removeSearchHistoryEntry(await this.readEntries(store), query)
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
