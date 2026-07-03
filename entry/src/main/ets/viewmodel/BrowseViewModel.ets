import { taskpool } from '@kit.ArkTS'
import { AppStrings } from '../i18n/AppStrings'
import { SourceManga, SourceMangaList, SourceMangaStatus } from '../model/SourceModels'
import { normalizeSourceDisplayText } from '../model/SourceTextNormalizer'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { safeDiagnosticCode, safeSearchDiagnostic } from '../model/SearchStateMapper'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
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
}

interface SourceMangaListFilters {
}

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

@Concurrent
async function runBrowseSourceOperationTask(requestJson: string, wasmBytes: Uint8Array): Promise<string> {
  const mod: Record<string, Object> = await import('libkoma_source_runtime.so') as Record<string, Object>
  const nativeRuntime = (mod.default ?? mod) as Record<string, Function>
  return nativeRuntime.runJsonCallFromBytes(requestJson, wasmBytes) as string
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

function itemRecord(value: RuntimeValue): RuntimeRecord | undefined {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  return value as RuntimeRecord
}

function parseSourceMangaFromItem(sourceId: string, item: RuntimeRecord): SourceManga {
  const title = optionalString(item['title']) ?? optionalString(item['id']) ?? AppStrings.get('browse_untitled_manga')
  return {
    id: optionalString(item['id']) ?? title,
    sourceId,
    title: normalizeSourceDisplayText(title) ?? title,
    author: normalizeSourceDisplayText(optionalString(item['author'])),
    artist: normalizeSourceDisplayText(optionalString(item['artist'])),
    description: normalizeSourceDisplayText(optionalString(item['description'])),
    coverUrl: optionalString(item['cover_url']) ?? optionalString(item['coverUrl']),
    status: normalizeStatus(item['status']),
    contentRating: normalizeSourceDisplayText(optionalString(item['content_rating']) ?? optionalString(item['contentRating'])),
    tags: normalizeStringArray(item['tags']),
    url: optionalString(item['url']),
  }
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
  const hasNextPage = data?.['hasNextPage'] === true || data?.['has_more'] === true || data?.['hasMore'] === true
  return { manga, hasNextPage }
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

@ObservedV2
export class BrowseViewModel {
  @Trace sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
  @Trace popularManga: SourceManga[] = []
  @Trace latestManga: SourceManga[] = []
  @Trace listings: SourceListingDescriptor[] = []
  @Trace homeSections: SourceHomeSectionState[] = []
  @Trace browseSections: BrowseSourceSectionState[] = []
  @Trace selectedListingId: string = ''
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

  constructor(registry?: SourceRuntimeRegistry) {
    this.registry = registry ?? appSourceRuntimeRegistry
  }

  private registry: SourceRuntimeRegistry

  loadInstalledSources(): void {
    this.loadingSources = true
    this.errorMessage = ''
    try {
      this.sources = this.registry.listInstalledSourceSummaries()
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : AppStrings.get('browse_error_load_sources')
      this.sources = []
    } finally {
      this.loadingSources = false
    }
  }

  setSelectedSource(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.selectedSource = source
    this.popularManga = []
    this.latestManga = []
    this.homeSections = []
    this.browseSections = []
    this.browsePage = 1
    this.hasMoreBrowse = false
    this.selectedListingId = ''
    this.errorMessage = ''
  }

  async loadBrowseHome(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<void> {
    this.setSelectedSource(source)
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      this.listings = await this.loadSourceListings(source)
      this.homeSections = await this.loadSourceHomeSections(source)
      const listing = this.defaultListingForBrowse(this.listings)
      if (listing === undefined) {
        this.popularManga = []
        this.latestManga = []
        this.homeSections = []
        this.browseSections = []
        this.hasMoreBrowse = false
        return
      }
      await this.loadBrowseListing(source, listing, 1)
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : AppStrings.get('browse_error_load_home')
      this.popularManga = []
      this.latestManga = []
      this.homeSections = []
      this.browseSections = []
      this.hasMoreBrowse = false
    } finally {
      this.loadingBrowse = false
    }
  }

  async selectBrowseListing(listing: SourceListingDescriptor): Promise<void> {
    if (this.selectedSource === undefined || this.loadingBrowse) {
      return
    }
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      await this.loadBrowseListing(this.selectedSource, listing, 1)
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : AppStrings.get('browse_error_load_home')
      this.browseSections = []
      this.hasMoreBrowse = false
    } finally {
      this.loadingBrowse = false
    }
  }

  async loadMoreBrowse(): Promise<void> {
    if (this.loadingBrowse || !this.hasMoreBrowse || this.selectedSource === undefined) {
      return
    }
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      this.browsePage += 1
      const listing = this.currentListing()
      if (listing === undefined) {
        this.hasMoreBrowse = false
        return
      }
      const more = await this.loadMangaListing(this.selectedSource, listing.id, this.browsePage)
      this.mergeBrowseListingPage(listing, more, this.browsePage)
      this.hasMoreBrowse = more.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : AppStrings.get('browse_error_load_more')
      this.hasMoreBrowse = false
    } finally {
      this.loadingBrowse = false
    }
  }

  async runSearch(source: SourceRuntimeRegistryInstalledSourceSummary, query: string): Promise<void> {
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
      this.searchResults = result.manga
      this.hasMoreSearch = result.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = safeSearchDiagnostic(e).userText
      this.searchResults = []
      this.hasMoreSearch = false
    } finally {
      this.loadingSearch = false
    }
  }

  async loadMoreSearch(): Promise<void> {
    if (this.loadingSearch || !this.hasMoreSearch || this.selectedSource === undefined || this.searchQuery.trim().length === 0) {
      return
    }
    this.loadingSearch = true
    this.errorMessage = ''
    try {
      this.searchPage += 1
      const more = await this.searchSource(this.selectedSource, this.searchQuery.trim(), this.searchPage)
      this.searchResults = this.searchResults.concat(more.manga)
      this.hasMoreSearch = more.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = safeSearchDiagnostic(e).userText
      this.hasMoreSearch = false
    } finally {
      this.loadingSearch = false
    }
  }

  async searchSource(source: SourceRuntimeRegistryInstalledSourceSummary, query: string, page: number): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: page <= 1 ? null : `${page}`,
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const args: SourceSearchArgs = {
      query,
      page: pageArg,
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
  ): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: page <= 1 ? null : `${page}`,
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const filters: SourceMangaListFilters = {}
    const args: SourceMangaListArgs = {
      listingId,
      page: pageArg,
      filters,
    }
    return this.runSourceOperation(source.sourceId, 'get_manga_list', args, page)
  }

  private async loadSourceListings(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<SourceListingDescriptor[]> {
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
  ): Promise<void> {
    const result = await this.loadMangaListing(source, listing.id, page)
    this.selectedListingId = listing.id
    this.browsePage = page
    this.popularManga = result.manga
    this.latestManga = []
    this.browseSections = [{
      listing,
      manga: result.manga,
      hasNextPage: result.hasNextPage,
      page,
    }]
    this.hasMoreBrowse = result.hasNextPage
  }

  private mergeBrowseListingPage(
    listing: SourceListingDescriptor,
    more: SourceMangaList,
    page: number,
  ): void {
    const current = this.browseSections.find((section: BrowseSourceSectionState): boolean => section.listing.id === listing.id)
    const manga = current === undefined ? more.manga : current.manga.concat(more.manga)
    this.popularManga = manga
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
    const responseJson = await taskpool.execute(runBrowseSourceOperationTask, requestJson, wasmBytes) as string
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
    const responseJson = await taskpool.execute(runBrowseSourceOperationTask, requestJson, wasmBytes) as string
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
