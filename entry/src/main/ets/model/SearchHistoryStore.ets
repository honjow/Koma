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

export class SearchHistoryStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<SearchHistoryEntry[]> {
    const store = await this.preferences()
    const payload = await store.get(SEARCH_HISTORY_QUERIES_KEY, '[]') as string
    try {
      const parsed = JSON.parse(payload) as SearchHistoryRecord[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return normalizeSearchHistoryEntries(parsed)
    } catch (_err) {
      return []
    }
  }

  async record(query: string): Promise<SearchHistoryEntry[]> {
    const entries = addSearchHistoryEntry(await this.load(), query)
    await this.save(entries)
    return entries
  }

  async clear(): Promise<void> {
    const store = await this.preferences()
    await store.put(SEARCH_HISTORY_QUERIES_KEY, '[]')
    await store.flush()
  }

  async remove(query: string): Promise<SearchHistoryEntry[]> {
    const entries = removeSearchHistoryEntry(await this.load(), query)
    await this.save(entries)
    return entries
  }

  async loadSourceFilter(): Promise<CrossSearchSourceFilter> {
    const store = await this.preferences()
    const value = await store.get(SEARCH_SOURCE_FILTER_KEY, 'all') as string
    return normalizeSearchSourceFilter(value)
  }

  async saveSourceFilter(sourceFilter: CrossSearchSourceFilter): Promise<CrossSearchSourceFilter> {
    const normalized = normalizeSearchSourceFilter(sourceFilter)
    const store = await this.preferences()
    await store.put(SEARCH_SOURCE_FILTER_KEY, normalized)
    await store.flush()
    return normalized
  }

  private async save(entries: SearchHistoryEntry[]): Promise<void> {
    const store = await this.preferences()
    await store.put(SEARCH_HISTORY_QUERIES_KEY, JSON.stringify(normalizeSearchHistoryEntries(entries)))
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, SEARCH_HISTORY_STORE_NAME)
  }
}
