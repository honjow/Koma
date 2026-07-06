import { taskpool } from '@kit.ArkTS'
import { AppStrings } from '../i18n/AppStrings'
import {
  SourceFilter,
  SourceManga,
  SourceMangaList,
  SourceMangaStatus,
  parseSourceFiltersJson,
} from '../model/SourceModels'
import { normalizeSourceDisplayText, normalizeSourceImageUrl } from '../model/SourceTextNormalizer'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { safeDiagnosticCode, safeSearchDiagnostic } from '../model/SearchStateMapper'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import {
  SourceFilterPreferenceKind,
  appSourceFilterPreferencesStore,
} from '../sourceRuntime/SourceFilterPreferencesStore'
import {
  SourceRuntimeRegistryEntry,
  SourceRuntimeRegistry,
  SourceRuntimeRegistryInstalledSourceSummary,
} from '../sourceRuntime/SourceRuntimeRegistry'

export type BrowseSourceSection = 'popular' | 'latest'

type RuntimeValue = Object | string | number | boolean | null
type RuntimeRecord = Record<string, RuntimeValue>

export interface SourceListingDescriptor {
  id: string
  name: string
  kind: string
}

export interface BrowseSourceSectionState {
  listing: SourceListingDescriptor
  manga: SourceManga[]
  hasNextPage: boolean
  page: number
}

export interface SourceHomeSectionState {
  id: string
  title: string
  kind: string
  manga: SourceManga[]
  listingId?: string
}

interface SourceOperationPageArg {
  cursor: string | null
  limit: number
}

interface SourceHomeArgs {
}

interface SourceListingsArgs {
}

interface SourceSearchArgs {
  query: string
  page: SourceOperationPageArg
  filters: SourceMangaListFilters
}

type SourceFilterValue = string | number | boolean | string[]
type SourceMangaListFilters = Record<string, SourceFilterValue>

interface SourceMangaListArgs {
  listingId: string
  page: SourceOperationPageArg
  filters: SourceMangaListFilters
}

type SourceOperationArgs = SourceHomeArgs | SourceListingsArgs | SourceSearchArgs | SourceMangaListArgs

interface SourceOperationHostHints {
  network: boolean
}

interface SourceOperationRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceOperationArgs
  settings: SourceSettingsRecord
  hostHints: SourceOperationHostHints
}

const SOURCE_OPERATION_PAGE_SIZE: number = 20
const SOURCE_OPERATION_TIMEOUT_MS: number = 10000

@Concurrent
async function runBrowseSourceOperationTask(requestJson: string, wasmBytes: Uint8Array): Promise<string> {
  const mod: Record<string, Object> = await import('libkoma_source_runtime.so') as Record<string, Object>
  const nativeRuntime = (mod.default ?? mod) as Record<string, Function>
  return nativeRuntime.runJsonCallFromBytes(requestJson, wasmBytes) as string
}

function withSourceOperationTimeout(promise: Promise<string>, operation: string): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    let settled = false
    const timer = setTimeout(() => {
      if (settled) {
        return
      }
      settled = true
      reject(new Error(`${operation} timed out`))
    }, SOURCE_OPERATION_TIMEOUT_MS)
    promise.then((value: string) => {
      if (settled) {
        return
      }
      settled = true
      clearTimeout(timer)
      resolve(value)
    }).catch((error: Error) => {
      if (settled) {
        return
      }
      settled = true
      clearTimeout(timer)
      reject(error)
    })
  })
}

function optionalString(value: RuntimeValue | undefined): string | undefined {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined
  }
  return value
}

function normalizeStatus(value: RuntimeValue | undefined): SourceMangaStatus {
  const status = optionalString(value)
  if (status === 'ongoing' || status === 'completed' || status === 'hiatus' || status === 'cancelled') {
    return status as SourceMangaStatus
  }
  return 'unknown'
}

function normalizeStringArray(value: RuntimeValue | undefined): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const tags: string[] = []
  value.forEach((item: RuntimeValue) => {
    if (typeof item === 'string') {
      const normalized = normalizeSourceDisplayText(item)
      if (normalized !== undefined) {
        tags.push(normalized)
      }
    }
  })
  return tags.length > 0 ? tags : undefined
}

function firstDisplayText(values: (RuntimeValue | undefined)[]): string | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index]
    if (typeof value === 'string') {
      const normalized = normalizeSourceDisplayText(value)
      if (normalized !== undefined) {
        return normalized
      }
    } else if (Array.isArray(value)) {
      const normalizedItems: string[] = []
      value.forEach((item: RuntimeValue) => {
        if (typeof item !== 'string') {
          return
        }
        const normalized = normalizeSourceDisplayText(item)
        if (normalized !== undefined) {
          normalizedItems.push(normalized)
        }
      })
      if (normalizedItems.length > 0) {
        return normalizedItems.join(', ')
      }
    }
  }
  return undefined
}

function itemRecord(value: RuntimeValue): RuntimeRecord | undefined {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  return value as RuntimeRecord
}

function sourceItemCoverUrl(item: RuntimeRecord): string | undefined {
  const direct = optionalString(item['cover_url']) ??
    optionalString(item['coverUrl']) ??
    optionalString(item['cover_uri']) ??
    optionalString(item['coverUri']) ??
    optionalString(item['thumbnail']) ??
    optionalString(item['thumbnailUrl']) ??
    optionalString(item['imageUrl']) ??
    optionalString(item['image_url'])
  if (direct !== undefined) {
    return normalizeSourceImageUrl(direct)
  }
  const cover = itemRecord(item['cover'])
  const coverUrl = cover === undefined ? undefined : (
    optionalString(cover['url']) ??
      optionalString(cover['uri']) ??
      optionalString(cover['src']) ??
      optionalString(cover['href'])
  )
  if (coverUrl !== undefined) {
    return normalizeSourceImageUrl(coverUrl)
  }
  const image = itemRecord(item['image'])
  const imageUrl = image === undefined ? undefined : (
    optionalString(image['url']) ??
      optionalString(image['uri']) ??
      optionalString(image['src']) ??
      optionalString(image['href'])
  )
  return normalizeSourceImageUrl(imageUrl)
}

function parseSourceMangaFromItem(sourceId: string, item: RuntimeRecord): SourceManga {
  const title = optionalString(item['title']) ?? optionalString(item['id']) ?? AppStrings.get('browse_untitled_manga')
  return {
    id: optionalString(item['id']) ?? title,
    sourceId,
    title: normalizeSourceDisplayText(title) ?? title,
    author: firstDisplayText([item['author'], item['authors']]),
    artist: firstDisplayText([item['artist'], item['artists']]),
    description: firstDisplayText([item['description'], item['summary'], item['synopsis']]),
    coverUrl: sourceItemCoverUrl(item),
    status: normalizeStatus(item['status']),
    contentRating: normalizeSourceDisplayText(optionalString(item['content_rating']) ?? optionalString(item['contentRating'])),
    tags: normalizeStringArray(item['tags']),
    url: optionalString(item['url']),
  }
}

function sourceMangaIdentityKey(manga: SourceManga): string {
  return `${manga.sourceId.length}:${manga.sourceId}${manga.id.length}:${manga.id}`
}

function appendUniqueSourceManga(current: SourceManga[], incoming: SourceManga[]): SourceManga[] {
  const seen = new Set<string>()
  const merged: SourceManga[] = []
  current.forEach((manga: SourceManga) => {
    const key = sourceMangaIdentityKey(manga)
    if (seen.has(key)) {
      return
    }
    seen.add(key)
    merged.push(manga)
  })
  incoming.forEach((manga: SourceManga) => {
    const key = sourceMangaIdentityKey(manga)
    if (seen.has(key)) {
      return
    }
    seen.add(key)
    merged.push(manga)
  })
  return merged
}

function parseSourceMangaListFromResponse(sourceId: string, response: SourceRuntimeCallResponse): SourceMangaList {
  if (response.ok !== true) {
    return { manga: [], hasNextPage: false }
  }
  const data = response.data as RuntimeRecord | undefined
  const rawItems = data?.['items']
  const manga: SourceManga[] = []
  if (Array.isArray(rawItems)) {
    rawItems.forEach((rawItem: RuntimeValue) => {
      const directItem = itemRecord(rawItem)
      if (directItem === undefined) {
        return
      }
      const nestedItems = directItem['items']
      if (Array.isArray(nestedItems)) {
        nestedItems.forEach((nestedRawItem: RuntimeValue) => {
          const nestedItem = itemRecord(nestedRawItem)
          if (nestedItem !== undefined) {
            manga.push(parseSourceMangaFromItem(sourceId, nestedItem))
          }
        })
        return
      }
      manga.push(parseSourceMangaFromItem(sourceId, directItem))
    })
  }
  const rawPage = data?.['page']
  const page = rawPage === undefined ? undefined : itemRecord(rawPage)
  const nextCursor = optionalString(page?.['nextCursor']) ?? optionalString(page?.['next_cursor'])
  const hasNextPage = data?.['hasNextPage'] === true ||
    data?.['has_more'] === true ||
    data?.['hasMore'] === true ||
    page?.['hasMore'] === true ||
    page?.['hasNextPage'] === true ||
    nextCursor !== undefined
  return { manga: appendUniqueSourceManga([], manga), hasNextPage, nextCursor }
}

function parseSourceListingsFromResponse(response: SourceRuntimeCallResponse): SourceListingDescriptor[] {
  if (response.ok !== true) {
    return []
  }
  const data = response.data as RuntimeRecord | undefined
  const rawListings = data?.['listings'] ?? data?.['items']
  const listings: SourceListingDescriptor[] = []
  if (Array.isArray(rawListings)) {
    rawListings.forEach((rawListing: RuntimeValue) => {
      const listing = itemRecord(rawListing)
      if (listing === undefined) {
        return
      }
      const id = optionalString(listing['id'])
      if (id === undefined) {
        return
      }
      listings.push({
        id,
        name: normalizeSourceDisplayText(optionalString(listing['name']) ?? optionalString(listing['title']) ?? id) ?? id,
        kind: optionalString(listing['kind']) ?? 'custom',
      })
    })
  }
  return listings
}

function parseSourceHomeSectionsFromResponse(sourceId: string, response: SourceRuntimeCallResponse): SourceHomeSectionState[] {
  if (response.ok !== true) {
    return []
  }
  const data = response.data as RuntimeRecord | undefined
  const rawSections = data?.['sections'] ?? data?.['items']
  const sections: SourceHomeSectionState[] = []
  if (Array.isArray(rawSections)) {
    rawSections.forEach((rawSection: RuntimeValue) => {
      const section = itemRecord(rawSection)
      if (section === undefined) {
        return
      }
      const id = optionalString(section['id'])
      if (id === undefined) {
        return
      }
      const rawItems = section['items']
      const manga: SourceManga[] = []
      if (Array.isArray(rawItems)) {
        rawItems.forEach((rawItem: RuntimeValue) => {
          const item = itemRecord(rawItem)
          if (item !== undefined) {
            manga.push(parseSourceMangaFromItem(sourceId, item))
          }
        })
      }
      sections.push({
        id,
        title: normalizeSourceDisplayText(optionalString(section['title']) ?? id) ?? id,
        kind: optionalString(section['kind']) ?? 'mangaList',
        manga,
        listingId: optionalString(section['listingId']) ?? optionalString(section['listing_id']),
      })
    })
  }
  return sections
}

function safeSourceBrowseErrorText(error: Error, fallbackKey: string): string {
  const diagnostic = safeSearchDiagnostic(error)
  if (diagnostic.code === 'search_failed') {
    return AppStrings.get(fallbackKey)
  }
  return diagnostic.userText
}

function sourceLanguageBadgeFromLanguage(language: string): string | undefined {
  const normalized = language.trim()
  if (normalized.length === 0) {
    return undefined
  }
  const primary = normalized.split(/[-_]/)[0].trim().toLocaleLowerCase()
  if (primary.length === 0) {
    return undefined
  }
  if (primary === 'zh' || primary === 'zho' || primary === 'chi') {
    return 'ZH'
  }
  if (primary === 'ja' || primary === 'jp' || primary === 'jpn') {
    return 'JA'
  }
  if (primary === 'en' || primary === 'eng') {
    return 'EN'
  }
  return (primary.length <= 3 ? primary : primary.substring(0, 3)).toLocaleUpperCase()
}

@ObservedV2
export class BrowseViewModel {
  @Trace sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
  @Trace popularManga: SourceManga[] = []
  @Trace latestManga: SourceManga[] = []
  @Trace listings: SourceListingDescriptor[] = []
  @Trace filters: SourceFilter[] = []
  @Trace browseFilterValues: SourceMangaListFilters = {}
  @Trace searchFilterValues: SourceMangaListFilters = {}
  @Trace homeSections: SourceHomeSectionState[] = []
  @Trace browseSections: BrowseSourceSectionState[] = []
  @Trace selectedListingId: string = ''
  @Trace browseNextCursor: string = ''
  @Trace searchResults: SourceManga[] = []
  @Trace selectedSource?: SourceRuntimeRegistryInstalledSourceSummary
  @Trace browsePage: number = 1
  @Trace searchPage: number = 1
  @Trace hasMoreBrowse: boolean = false
  @Trace hasMoreSearch: boolean = false
  @Trace loadingSources: boolean = false
  @Trace loadingBrowse: boolean = false
  @Trace loadingSearch: boolean = false
  @Trace errorMessage: string = ''
  @Trace searchQuery: string = ''
  @Trace searchNextCursor: string = ''
  private browseRequestId: number = 0
  private searchRequestId: number = 0

  constructor(registry?: SourceRuntimeRegistry) {
    this.registry = registry ?? appSourceRuntimeRegistry
  }

  private registry: SourceRuntimeRegistry

  private sourceSupportsOperation(source: SourceRuntimeRegistryInstalledSourceSummary, capability: string): boolean {
    if (source.capabilities.indexOf(capability) >= 0) {
      return true
    }
    return source.capabilities.indexOf('sourceInfo') < 0
  }

  sourceCanSearch(source: SourceRuntimeRegistryInstalledSourceSummary): boolean {
    return this.sourceSupportsOperation(source, 'search')
  }

  sourceCanBrowse(source: SourceRuntimeRegistryInstalledSourceSummary): boolean {
    return this.sourceSupportsOperation(source, 'home') || this.sourceSupportsOperation(source, 'mangaList')
  }

  loadInstalledSources(): void {
    this.loadingSources = true
    this.errorMessage = ''
    try {
      this.sources = this.registry.listInstalledSourceSummaries()
    } catch (error) {
      const e = error as Error
      this.errorMessage = safeSourceBrowseErrorText(e, 'browse_error_load_sources')
      this.sources = []
    } finally {
      this.loadingSources = false
    }
  }

  sourceSummaryForId(sourceId: string): SourceRuntimeRegistryInstalledSourceSummary | undefined {
    const normalized = sourceId.trim()
    if (normalized.length === 0) {
      return undefined
    }
    const current = this.registry.listInstalledSourceSummaries().find((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => {
      return source.sourceId === normalized
    })
    if (current !== undefined) {
      return current
    }
    return this.sources.find((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => {
      return source.sourceId === normalized
    })
  }

  setSelectedSource(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.browseRequestId += 1
    this.selectedSource = source
    this.popularManga = []
    this.latestManga = []
    this.homeSections = []
    this.browseSections = []
    this.filters = []
    this.browseFilterValues = {}
    this.searchFilterValues = {}
    this.browsePage = 1
    this.browseNextCursor = ''
    this.hasMoreBrowse = false
    this.selectedListingId = ''
    this.errorMessage = ''
  }

  async loadBrowseHome(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<void> {
    this.setSelectedSource(source)
    const requestId = this.browseRequestId
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      const listings = await this.loadSourceListings(source)
      if (requestId !== this.browseRequestId) {
        return
      }
      const filters = await this.loadSourceFilters(source)
      if (requestId !== this.browseRequestId) {
        return
      }
      const homeSections = await this.loadSourceHomeSections(source)
      if (requestId !== this.browseRequestId) {
        return
      }
      this.listings = listings
      this.filters = filters
      this.browseFilterValues = this.defaultSourceFilterValues(this.filters)
      this.searchFilterValues = this.defaultSourceFilterValues(this.filters)
      this.restoreSavedBrowseFilterValues(source.sourceId)
      this.restoreSavedSearchFilterValues(source.sourceId)
      this.homeSections = homeSections
      const listing = this.sourceSupportsOperation(source, 'mangaList') ? this.defaultListingForBrowse(this.listings) : undefined
      if (listing === undefined) {
        this.popularManga = []
        this.latestManga = []
        this.browseSections = []
        this.hasMoreBrowse = false
        return
      }
      try {
        await this.loadBrowseListing(source, listing, 1, requestId)
      } catch (error) {
        const e = error as Error
        if (homeSections.length > 0) {
          this.errorMessage = safeSourceBrowseErrorText(e, 'browse_error_load_home')
          this.popularManga = []
          this.latestManga = []
          this.browseSections = []
          this.hasMoreBrowse = false
          return
        }
        throw e
      }
    } catch (error) {
      if (requestId !== this.browseRequestId) {
        return
      }
      const e = error as Error
      this.errorMessage = safeSourceBrowseErrorText(e, 'browse_error_load_home')
      this.popularManga = []
      this.latestManga = []
      this.homeSections = []
      this.browseSections = []
      this.hasMoreBrowse = false
    } finally {
      if (requestId === this.browseRequestId) {
        this.loadingBrowse = false
      }
    }
  }

  async selectBrowseListing(listing: SourceListingDescriptor): Promise<void> {
    if (this.selectedSource === undefined || this.loadingBrowse) {
      return
    }
    const requestId = this.browseRequestId + 1
    this.browseRequestId = requestId
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      const loaded = await this.loadBrowseListing(this.selectedSource, listing, 1, requestId)
      if (!loaded) {
        return
      }
      this.homeSections = []
    } catch (error) {
      if (requestId !== this.browseRequestId) {
        return
      }
      const e = error as Error
      this.errorMessage = safeSourceBrowseErrorText(e, 'browse_error_load_home')
      this.homeSections = []
      this.browseSections = []
      this.hasMoreBrowse = false
    } finally {
      if (requestId === this.browseRequestId) {
        this.loadingBrowse = false
      }
    }
  }

  private updateFilterValue(values: SourceMangaListFilters, filterId: string, value: SourceFilterValue | undefined): SourceMangaListFilters | undefined {
    const filter = this.filters.find((item: SourceFilter): boolean => item.id === filterId)
    if (filter === undefined) {
      return undefined
    }
    const key = this.filterRequestKey(filter)
    const nextValues: SourceMangaListFilters = {}
    Object.keys(values).forEach((itemKey: string) => {
      if (itemKey !== key) {
        nextValues[itemKey] = values[itemKey]
      }
    })
    if (value !== undefined) {
      const normalized = this.normalizeFilterRequestValue(key, value)
      if (!Array.isArray(normalized) || normalized.length > 0) {
        nextValues[key] = normalized
      }
    }
    return nextValues
  }

  async setBrowseFilterValue(filterId: string, value: SourceFilterValue | undefined): Promise<void> {
    const nextValues = this.updateFilterValue(this.browseFilterValues, filterId, value)
    if (nextValues === undefined) {
      return
    }
    this.browseFilterValues = nextValues
    this.saveSourceFilterValues('browse', nextValues)
    const listing = this.currentListing()
    if (this.selectedSource !== undefined && listing !== undefined && !this.loadingBrowse) {
      await this.selectBrowseListing(listing)
    }
  }

  async resetBrowseFilters(): Promise<void> {
    if (this.selectedSource === undefined || this.loadingBrowse) {
      return
    }
    this.browseFilterValues = this.defaultSourceFilterValues(this.filters)
    this.clearSavedSourceFilterValues('browse')
    const listing = this.currentListing()
    if (listing !== undefined) {
      await this.selectBrowseListing(listing)
    }
  }

  async ensureSearchFilters(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<void> {
    const sourceChanged = this.selectedSource === undefined || this.selectedSource.sourceId !== source.sourceId
    if (sourceChanged) {
      this.clearSearch(source)
      this.filters = []
      this.browseFilterValues = {}
      this.searchFilterValues = {}
    }
    if (this.filters.length > 0) {
      if (Object.keys(this.searchFilterValues).length === 0) {
        this.searchFilterValues = this.defaultSourceFilterValues(this.filters)
        this.restoreSavedSearchFilterValues(source.sourceId)
      }
      return
    }
    this.filters = await this.loadSourceFilters(source)
    this.searchFilterValues = this.defaultSourceFilterValues(this.filters)
    this.restoreSavedSearchFilterValues(source.sourceId)
  }

  setSearchFilterValue(filterId: string, value: SourceFilterValue | undefined): boolean {
    const nextValues = this.updateFilterValue(this.searchFilterValues, filterId, value)
    if (nextValues === undefined) {
      return false
    }
    this.searchFilterValues = nextValues
    this.saveSourceFilterValues('search', nextValues)
    return true
  }

  resetSearchFilters(): void {
    this.searchFilterValues = this.defaultSourceFilterValues(this.filters)
    this.clearSavedSourceFilterValues('search')
  }

  hasSearchFilterChanges(): boolean {
    return !this.sourceFilterValuesEqual(this.searchFilterValues, this.defaultSourceFilterValues(this.filters))
  }

  async loadMoreBrowse(): Promise<void> {
    if (this.loadingBrowse || !this.hasMoreBrowse || this.selectedSource === undefined) {
      return
    }
    const requestId = this.browseRequestId
    const source = this.selectedSource
    const page = this.browsePage + 1
    const cursor = this.browseNextCursor
    const listing = this.currentListing()
    if (listing === undefined) {
      this.hasMoreBrowse = false
      return
    }
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      const more = await this.loadMangaListing(source, listing.id, page, cursor)
      if (requestId !== this.browseRequestId) {
        return
      }
      this.browsePage = page
      this.mergeBrowseListingPage(listing, more, page)
      this.hasMoreBrowse = more.hasNextPage
    } catch (error) {
      if (requestId !== this.browseRequestId) {
        return
      }
      const e = error as Error
      this.errorMessage = safeSourceBrowseErrorText(e, 'browse_error_load_more')
    } finally {
      if (requestId === this.browseRequestId) {
        this.loadingBrowse = false
      }
    }
  }

  async runSearch(source: SourceRuntimeRegistryInstalledSourceSummary, query: string): Promise<void> {
    const requestId = this.searchRequestId + 1
    this.searchRequestId = requestId
    this.selectedSource = source
    this.searchQuery = query
    this.searchPage = 1
    this.loadingSearch = true
    this.errorMessage = ''
    try {
      const normalizedQuery = query.trim()
      if (normalizedQuery.length === 0) {
        this.searchResults = []
        this.hasMoreSearch = false
        return
      }
      const result = await this.searchSource(source, normalizedQuery, 1)
      if (requestId !== this.searchRequestId) {
        return
      }
      this.searchResults = result.manga
      this.hasMoreSearch = result.hasNextPage
      this.searchNextCursor = result.nextCursor ?? ''
    } catch (error) {
      if (requestId !== this.searchRequestId) {
        return
      }
      const e = error as Error
      this.errorMessage = safeSearchDiagnostic(e).userText
      this.searchResults = []
      this.hasMoreSearch = false
      this.searchNextCursor = ''
    } finally {
      if (requestId === this.searchRequestId) {
        this.loadingSearch = false
      }
    }
  }

  clearSearch(source?: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.searchRequestId += 1
    if (source !== undefined) {
      this.selectedSource = source
    }
    this.searchQuery = ''
    this.searchPage = 1
    this.searchResults = []
    this.hasMoreSearch = false
    this.loadingSearch = false
    this.errorMessage = ''
    this.searchNextCursor = ''
  }

  async loadMoreSearch(): Promise<void> {
    if (this.loadingSearch || !this.hasMoreSearch || this.selectedSource === undefined || this.searchQuery.trim().length === 0) {
      return
    }
    const requestId = this.searchRequestId
    const source = this.selectedSource
    const query = this.searchQuery.trim()
    const page = this.searchPage + 1
    const cursor = this.searchNextCursor
    this.loadingSearch = true
    this.errorMessage = ''
    try {
      const more = await this.searchSource(source, query, page, cursor)
      if (requestId !== this.searchRequestId) {
        return
      }
      this.searchPage = page
      this.searchResults = appendUniqueSourceManga(this.searchResults, more.manga)
      this.hasMoreSearch = more.hasNextPage
      this.searchNextCursor = more.nextCursor ?? ''
    } catch (error) {
      if (requestId !== this.searchRequestId) {
        return
      }
      const e = error as Error
      this.errorMessage = safeSearchDiagnostic(e).userText
      this.hasMoreSearch = false
    } finally {
      if (requestId === this.searchRequestId) {
        this.loadingSearch = false
      }
    }
  }

  async searchSource(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    query: string,
    page: number,
    cursor: string = '',
  ): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: this.pageCursor(page, cursor),
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const args: SourceSearchArgs = {
      query,
      page: pageArg,
      filters: this.searchFilterValues,
    }
    return this.runSourceOperation(source.sourceId, 'search', args, page)
  }

  async loadMangaList(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    section: BrowseSourceSection,
    page: number,
  ): Promise<SourceMangaList> {
    return this.loadMangaListing(source, section === 'latest' ? 'listing:latest' : 'listing:popular', page)
  }

  async loadMangaListing(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    listingId: string,
    page: number,
    cursor: string = '',
  ): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: this.pageCursor(page, cursor),
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const args: SourceMangaListArgs = {
      listingId,
      page: pageArg,
      filters: this.browseFilterValues,
    }
    return this.runSourceOperation(source.sourceId, 'get_manga_list', args, page)
  }

  private async loadSourceFilters(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<SourceFilter[]> {
    if (!this.sourceSupportsOperation(source, 'filters')) {
      return []
    }
    try {
      const args: SourceListingsArgs = {}
      const response = await this.runSourceOperationResponse(source.sourceId, 'get_filters', args, 1)
      return parseSourceFiltersJson(JSON.stringify(response.data ?? {}))
    } catch (_error) {
      return []
    }
  }

  private async loadSourceListings(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<SourceListingDescriptor[]> {
    if (!this.sourceSupportsOperation(source, 'mangaList')) {
      return []
    }
    if (!this.sourceSupportsOperation(source, 'listings')) {
      return this.defaultListings()
    }
    try {
      const args: SourceListingsArgs = {}
      const response = await this.runSourceOperationResponse(source.sourceId, 'get_listings', args, 1)
      const listings = parseSourceListingsFromResponse(response)
      return listings.length > 0 ? listings : this.defaultListings()
    } catch (_error) {
      return this.defaultListings()
    }
  }

  private async loadSourceHomeSections(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<SourceHomeSectionState[]> {
    if (!this.sourceSupportsOperation(source, 'home')) {
      return []
    }
    try {
      const args: SourceHomeArgs = {}
      const response = await this.runSourceOperationResponse(source.sourceId, 'get_home', args, 1)
      return parseSourceHomeSectionsFromResponse(source.sourceId, response)
        .filter((section: SourceHomeSectionState): boolean => section.kind === 'mangaList' && section.manga.length > 0)
    } catch (_error) {
      return []
    }
  }

  private async loadBrowseListing(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    listing: SourceListingDescriptor,
    page: number,
    requestId: number = this.browseRequestId,
  ): Promise<boolean> {
    const result = await this.loadMangaListing(source, listing.id, page)
    if (requestId !== this.browseRequestId) {
      return false
    }
    this.selectedListingId = listing.id
    this.browsePage = page
    this.browseNextCursor = result.nextCursor ?? ''
    this.popularManga = result.manga
    this.latestManga = []
    this.browseSections = [{
      listing,
      manga: result.manga,
      hasNextPage: result.hasNextPage,
      page,
    }]
    this.hasMoreBrowse = result.hasNextPage
    return true
  }

  private mergeBrowseListingPage(
    listing: SourceListingDescriptor,
    more: SourceMangaList,
    page: number,
  ): void {
    const current = this.browseSections.find((section: BrowseSourceSectionState): boolean => section.listing.id === listing.id)
    const manga = appendUniqueSourceManga(current === undefined ? [] : current.manga, more.manga)
    this.popularManga = manga
    this.browseNextCursor = more.nextCursor ?? ''
    this.browseSections = [{
      listing,
      manga,
      hasNextPage: more.hasNextPage,
      page,
    }]
  }

  private currentListing(): SourceListingDescriptor | undefined {
    return this.listings.find((listing: SourceListingDescriptor): boolean => listing.id === this.selectedListingId) ??
      this.browseSections[0]?.listing
  }

  private defaultListingForBrowse(listings: SourceListingDescriptor[]): SourceListingDescriptor | undefined {
    return listings.find((listing: SourceListingDescriptor): boolean => listing.kind === 'popular') ??
      listings.find((listing: SourceListingDescriptor): boolean => listing.id === 'listing:popular') ??
      listings[0]
  }

  private defaultListings(): SourceListingDescriptor[] {
    return [
      { id: 'listing:popular', name: AppStrings.get('common_popular'), kind: 'popular' },
      { id: 'listing:latest', name: AppStrings.get('common_latest'), kind: 'latest' },
    ]
  }

  private defaultSourceFilterValues(filters: SourceFilter[]): SourceMangaListFilters {
    const values: SourceMangaListFilters = {}
    filters.forEach((filter: SourceFilter) => {
      if (filter.value !== undefined) {
        const key = this.filterRequestKey(filter)
        values[key] = this.normalizeFilterRequestValue(key, filter.value)
      }
    })
    return values
  }

  private sourceFilterValueEqual(left: SourceFilterValue | undefined, right: SourceFilterValue | undefined): boolean {
    if (Array.isArray(left) || Array.isArray(right)) {
      if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length) {
        return false
      }
      for (let index = 0; index < left.length; index += 1) {
        if (left[index] !== right[index]) {
          return false
        }
      }
      return true
    }
    return left === right
  }

  private sourceFilterValuesEqual(left: SourceMangaListFilters, right: SourceMangaListFilters): boolean {
    const leftKeys = Object.keys(left).sort()
    const rightKeys = Object.keys(right).sort()
    if (leftKeys.length !== rightKeys.length) {
      return false
    }
    for (let index = 0; index < leftKeys.length; index += 1) {
      const key = leftKeys[index]
      if (key !== rightKeys[index] || !this.sourceFilterValueEqual(left[key], right[key])) {
        return false
      }
    }
    return true
  }

  private restoreSavedBrowseFilterValues(sourceId: string): void {
    this.browseFilterValues = this.mergeSavedSourceFilterValues(sourceId, 'browse', this.browseFilterValues)
  }

  private restoreSavedSearchFilterValues(sourceId: string): void {
    this.searchFilterValues = this.mergeSavedSourceFilterValues(sourceId, 'search', this.searchFilterValues)
  }

  private mergeSavedSourceFilterValues(
    sourceId: string,
    kind: SourceFilterPreferenceKind,
    defaults: SourceMangaListFilters,
  ): SourceMangaListFilters {
    const saved = appSourceFilterPreferencesStore.loadForSource(sourceId, kind, this.filters)
    const values: SourceMangaListFilters = {}
    Object.keys(defaults).forEach((key: string) => {
      values[key] = defaults[key]
    })
    Object.keys(saved).forEach((key: string) => {
      values[key] = saved[key]
    })
    return values
  }

  private saveSourceFilterValues(kind: SourceFilterPreferenceKind, values: SourceMangaListFilters): void {
    const sourceId = this.selectedSource?.sourceId
    if (sourceId === undefined) {
      return
    }
    appSourceFilterPreferencesStore.saveForSource(sourceId, kind, values, this.filters)
  }

  private clearSavedSourceFilterValues(kind: SourceFilterPreferenceKind): void {
    const sourceId = this.selectedSource?.sourceId
    if (sourceId === undefined) {
      return
    }
    appSourceFilterPreferencesStore.clearForSource(sourceId, kind)
  }

  private filterRequestKey(filter: SourceFilter): string {
    const raw = filter.id.length > 0 ? filter.id : filter.name
    return raw.startsWith('filter:') ? raw.substring('filter:'.length) : raw
  }

  private normalizeFilterRequestValue(key: string, value: SourceFilterValue): SourceFilterValue {
    if (Array.isArray(value)) {
      const normalized: string[] = []
      value.forEach((item: string) => {
        const next = this.normalizeFilterStringRequestValue(key, item)
        if (next.length > 0 && !normalized.includes(next)) {
          normalized.push(next)
        }
      })
      return normalized
    }
    if (typeof value !== 'string') {
      return value
    }
    return this.normalizeFilterStringRequestValue(key, value)
  }

  private normalizeFilterStringRequestValue(key: string, value: string): string {
    const prefix = `${key}:`
    return value.startsWith(prefix) ? value.substring(prefix.length) : value
  }

  private pageCursor(page: number, cursor: string): string | null {
    if (page <= 1) {
      return null
    }
    return cursor.length > 0 ? cursor : `${page}`
  }

  private async runSourceOperation(
    sourceId: string,
    operation: string,
    args: SourceOperationArgs,
    page: number,
  ): Promise<SourceMangaList> {
    const lookup = this.registry.lookup(sourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      throw new Error(AppStrings.get('browse_error_source_unavailable'))
    }
    const requestJson = this.buildRequestJson(sourceId, operation, args, page)
    const wasmBytes = this.copyWasmBytes(lookup.entry)
    const responseJson = await withSourceOperationTimeout(
      taskpool.execute(runBrowseSourceOperationTask, requestJson, wasmBytes) as Promise<string>,
      operation,
    )
    const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
    if (response.ok !== true) {
      throw new Error(this.runtimeErrorMessage(response))
    }
    return parseSourceMangaListFromResponse(sourceId, response)
  }

  private async runSourceOperationResponse(
    sourceId: string,
    operation: string,
    args: SourceOperationArgs,
    page: number,
  ): Promise<SourceRuntimeCallResponse> {
    const lookup = this.registry.lookup(sourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      throw new Error(AppStrings.get('browse_error_source_unavailable'))
    }
    const requestJson = this.buildRequestJson(sourceId, operation, args, page)
    const wasmBytes = this.copyWasmBytes(lookup.entry)
    const responseJson = await withSourceOperationTimeout(
      taskpool.execute(runBrowseSourceOperationTask, requestJson, wasmBytes) as Promise<string>,
      operation,
    )
    const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
    if (response.ok !== true) {
      throw new Error(this.runtimeErrorMessage(response))
    }
    return response
  }

  private buildRequestJson(
    sourceId: string,
    operation: string,
    args: SourceOperationArgs,
    page: number,
  ): string {
    const settings = appSourceSettingsStore.loadForSource(sourceId)
    const hostHints: SourceOperationHostHints = { network: true }
    const request: SourceOperationRequest = {
      type: 'request',
      version: 1,
      requestId: `browse-${operation}-${sourceId}-${page}-${Date.now()}`,
      operation,
      sourceId,
      args,
      settings,
      hostHints,
    }
    return JSON.stringify(request)
  }

  private copyWasmBytes(entry: SourceRuntimeRegistryEntry): Uint8Array {
    const copy = new Uint8Array(entry.wasmBytes.byteLength)
    copy.set(entry.wasmBytes)
    return copy
  }

  private runtimeErrorMessage(response: SourceRuntimeCallResponse): string {
    if (typeof response.reasonCode === 'string' && response.reasonCode.length > 0) {
      return AppStrings.format('browse_error_source_runtime_failed', safeDiagnosticCode(response.reasonCode))
    }
    const errorCode = response.error?.['code']
    if (typeof errorCode === 'string' && errorCode.length > 0) {
      return AppStrings.format('browse_error_source_runtime_failed', safeDiagnosticCode(errorCode))
    }
    return AppStrings.get('browse_error_source_runtime_failed_generic')
  }

  sourceLanguageBadge(source: SourceRuntimeRegistryInstalledSourceSummary): string {
    const manifestLanguageBadge = sourceLanguageBadgeFromLanguage(source.language)
    if (manifestLanguageBadge !== undefined) {
      return manifestLanguageBadge
    }
    const lowered = source.sourceId.toLocaleLowerCase()
    if (lowered.indexOf('zh') >= 0 || lowered.indexOf('cn') >= 0) {
      return 'ZH'
    }
    if (lowered.indexOf('ja') >= 0 || lowered.indexOf('jp') >= 0) {
      return 'JA'
    }
    if (lowered.indexOf('en') >= 0) {
      return 'EN'
    }
    return 'SRC'
  }
}
