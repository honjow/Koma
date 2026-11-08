import { SourceAuthenticationRequest } from '../sourceRuntime/SourceAuthenticationService'
import { runBrowseSourceRequestInWorker as runBrowseSourceOperationTask } from '../sourceRuntime/SourceRuntimeWorkerClient'
import { sourceLanguageName } from '../sourceRuntime/SourceLanguagePresentation'
import { SourceWebChallengeGate, SourceWebChallengeReceipt, SourceWebChallengeScope } from '../sourceRuntime/SourceWebChallengeGate'
import { appSourceWebSessionStore, sourceHttpIdentityJson, sourceWebPackageIdentity } from '../sourceRuntime/SourceWebSessionStore'
import { SourcePrivateSessionHost } from '../sourceRuntime/SourcePrivateSessionHost'
import { clearSourceRejectedRequest, selectSourceRejectedRequest } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { newSourceRuntimeOperationGuardId, registerSourceRuntimeOperationGuard } from '../sourceRuntime/SourceRuntimeOperationGuard'
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { AppStrings } from '../i18n/AppStrings'
import {
  SourceFilter,
  SourceFilterSchema,
  SourceManga,
  SourceMangaList,
  SourceMangaStatus,
  parseSourceFilterSchemaJson,
  sourceStaticCoverHeaders,
  sourceFiltersForQuery,
} from '../model/SourceModels'
import { normalizeSourceDisplayText, normalizeSourceImageUrl } from '../model/SourceTextNormalizer'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { safeDiagnosticCode, safeSearchDiagnostic } from '../model/SearchStateMapper'
import { SourceRuntimeError } from '../model/SourceRuntimeError'
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

interface SourceSearchResultsIdentity {
  entry?: SourceRuntimeRegistryEntry
  fingerprint: string
  page: number
  cursor: string
}

type RuntimeValue = Object | string | number | boolean | null
type RuntimeRecord = Record<string, RuntimeValue>

export interface SourceListingDescriptor {
  id: string
  name: string
  kind: string
  supportsFilters?: boolean
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

interface BrowseDestinationSnapshot {
  listingResult?: SourceMangaList
  homeSections?: SourceHomeSectionState[]
}

const BROWSE_DESTINATION_CACHE_LIMIT: number = 12

// A zero-length result is only meaningful after the request that produced it has
// completed. Keep that lifecycle separate from the arrays so a route never
// renders an empty result as the implicit loading placeholder.
export enum BrowseContentState {
  UNRESOLVED = 'unresolved',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error',
}

// The page needs the intent to keep a retained-content refresh distinct from a
// listing replacement and pagination failure.
export enum BrowseLoadIntent {
  NONE = 'none',
  INITIAL = 'initial',
  REFRESH = 'refresh',
  LISTING_REPLACEMENT = 'listingReplacement',
  PAGINATION = 'pagination',
}

interface SourceOperationPageArg {
  cursor: string | null
  limit: number
}

interface SourceHomeArgs {
}

interface SourceListingsArgs {
}

interface SourceFilterDataArgs {
  fetchFilterData: boolean
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

type SourceOperationArgs = SourceHomeArgs | SourceListingsArgs | SourceFilterDataArgs | SourceSearchArgs | SourceMangaListArgs

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
// Every source consumer uses the shared Worker admission owner, including
// covers. Stale Browse work is checked there before it can occupy a worker.
function enqueueSourceOperation(
  requestJson: string, wasmBytes: Uint8Array, httpContextJson: string, _sourceId: string,
  isActive: (() => boolean) | undefined = undefined,
): Promise<string> {
  return diagnoseSourceOperation(requestJson,
    () => runBrowseSourceOperationTask(requestJson, wasmBytes, httpContextJson, isActive))
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
  const coverUrl = sourceItemCoverUrl(item)
  return {
    id: optionalString(item['id']) ?? title,
    sourceId,
    title: normalizeSourceDisplayText(title) ?? title,
    author: firstDisplayText([item['author'], item['authors']]),
    artist: firstDisplayText([item['artist'], item['artists']]),
    description: firstDisplayText([item['description'], item['summary'], item['synopsis']]),
    coverUrl,
    coverHeaders: sourceStaticCoverHeaders(itemRecord(item['cover']), coverUrl),
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
  // A listing is navigation metadata (`id`, `name`, optional `kind`), not a
  // manga result.  Some older source packages accidentally return a manga
  // page in `items` from get_listings.  Treating that first manga as a
  // Listing made its title become both the picker value and the page heading.
  // Only the documented listings field is valid here; callers fall back to
  // the host's Popular/Latest descriptors when a package has no valid list.
  const rawListings = data?.['listings']
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
      const name = normalizeSourceDisplayText(optionalString(listing['name']))
      if (name === undefined) {
        return
      }
      const descriptor: SourceListingDescriptor = {
        id,
        name,
        kind: optionalString(listing['kind']) ?? 'custom',
      }
      if (listing['supportsFilters'] === false) descriptor.supportsFilters = false
      listings.push(descriptor)
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
  const fallback = AppStrings.get(fallbackKey)
  if (error instanceof SourceRuntimeError) return error.userTextFor(fallback)
  const diagnostic = safeSearchDiagnostic(error)
  return diagnostic.code === 'timeout' ? AppStrings.get('source_failure_timeout') :
    diagnostic.code === 'network_error' ? AppStrings.get('source_failure_network') : fallback
}


@ObservedV2
export class BrowseViewModel {
  @Trace sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
  @Trace popularManga: SourceManga[] = []
  @Trace latestManga: SourceManga[] = []
  @Trace listings: SourceListingDescriptor[] = []
  @Trace filters: SourceFilter[] = []
  @Trace loadingFilterData: boolean = false
  @Trace useSearchForFilters: boolean = false
  private supportsFilterFetching: boolean = false
  private filterDataReady: boolean = false
  private filterDataRevision: number = 0
  @Trace browseFilterValues: SourceMangaListFilters = {}
  @Trace searchFilterValues: SourceMangaListFilters = {}
  @Trace homeSections: SourceHomeSectionState[] = []
  @Trace homeAvailable: boolean = false
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
  @Trace sourceErrorMessage: string = ''
  @Trace browseErrorMessage: string = ''
  @Trace browseNeedsWebSession: boolean = false
  @Trace searchNeedsWebSession: boolean = false
  @Trace searchErrorMessage: string = ''

  @Computed
  get errorMessage(): string {
    return this.hasActiveSearch ? this.searchErrorMessage : this.browseErrorMessage
  }
  @Trace browseContentState: BrowseContentState = BrowseContentState.UNRESOLVED
  @Trace browseLoadIntent: BrowseLoadIntent = BrowseLoadIntent.NONE
  @Trace browseErrorIntent: BrowseLoadIntent = BrowseLoadIntent.NONE
  @Trace searchQuery: string = ''
  @Trace private filterOnlySearch: boolean = false
  get hasActiveSearch(): boolean {
    return this.filterOnlySearch || this.searchQuery.trim().length > 0
  }
  @Trace searchNextCursor: string = ''
  @Trace browseWebChallenge: SourceWebChallengeReceipt | null = null
  @Trace searchWebChallenge: SourceWebChallengeReceipt | null = null
  private browseWebChallengeGate: SourceWebChallengeGate = new SourceWebChallengeGate()
  private searchWebChallengeGate: SourceWebChallengeGate = new SourceWebChallengeGate()
  @Trace browseAuthentication: SourceWebChallengeReceipt | null = null
  @Trace searchAuthentication: SourceWebChallengeReceipt | null = null
  private browseDestinationCache: Map<string, BrowseDestinationSnapshot> = new Map()
  private browseCacheEntry?: SourceRuntimeRegistryEntry
  private browseCacheContext: string = ''
  private browseAuthenticationGate: SourceWebChallengeGate = new SourceWebChallengeGate()
  private searchAuthenticationGate: SourceWebChallengeGate = new SourceWebChallengeGate()

  authenticationRequest(scope: SourceWebChallengeScope, visible: () => boolean): SourceAuthenticationRequest | null {
    const receipt = scope === 'browse' ? this.browseAuthentication : this.searchAuthentication
    const gate = scope === 'browse' ? this.browseAuthenticationGate : this.searchAuthenticationGate
    if (receipt === null || !gate.claim(receipt.id, visible())) return null
    const current = (): boolean => visible() && gate.isCurrentClaim(receipt.id)
    return new SourceAuthenticationRequest(receipt.sourceId, current,
      async (): Promise<void> => {
        try { await gate.complete(receipt.id, visible()) }
        finally {
          if ((scope === 'browse' ? this.browseAuthentication : this.searchAuthentication)?.id === receipt.id) {
            if (scope === 'browse') this.browseAuthentication = null
            else this.searchAuthentication = null
          }
        }
      }, (): void => {
        const next = gate.releaseLogin(receipt.id)
        if (scope === 'browse' && this.browseAuthentication?.id === receipt.id) this.browseAuthentication = next
        else if (scope !== 'browse' && this.searchAuthentication?.id === receipt.id) this.searchAuthentication = next
      })
  }

  private browseChallengeHandle?: string
  private searchChallengeHandle?: string

  private challengeGate(scope: SourceWebChallengeScope): SourceWebChallengeGate {
    return scope === 'browse' ? this.browseWebChallengeGate : this.searchWebChallengeGate
  }

  private clearWebChallenge(scope: SourceWebChallengeScope): void {
    const authenticationGate = scope === 'browse' ? this.browseAuthenticationGate : this.searchAuthenticationGate
    authenticationGate.clear()
    if (scope === 'browse') this.browseAuthentication = null
    else this.searchAuthentication = null

    this.challengeGate(scope).clear()
    const receipt = scope === 'browse' ? this.browseWebChallenge : this.searchWebChallenge
    const handle = scope === 'browse' ? this.browseChallengeHandle : this.searchChallengeHandle
    if (receipt !== null && handle !== undefined) clearSourceRejectedRequest(receipt.sourceId, handle)
    if (scope === 'browse') { this.browseWebChallenge = null; this.browseChallengeHandle = undefined }
    else { this.searchWebChallenge = null; this.searchChallengeHandle = undefined }
  }

  claimWebChallenge(scope: SourceWebChallengeScope, id: number, routeVisible: boolean): boolean {
    return this.challengeGate(scope).claim(id, routeVisible)
  }

  canRetryWebChallenge(scope: SourceWebChallengeScope, id: number, routeVisible: boolean): boolean {
    return routeVisible && this.challengeGate(scope).isCurrentClaim(id)
  }

  cancelWebChallenge(scope: SourceWebChallengeScope, id: number): void {
    const receipt = scope === 'browse' ? this.browseWebChallenge : this.searchWebChallenge
    if (!this.challengeGate(scope).cancel(id)) return
    if (receipt?.requestHandle !== undefined) clearSourceRejectedRequest(receipt.sourceId, receipt.requestHandle)
    if (scope === 'browse') { this.browseWebChallenge = null; this.browseChallengeHandle = undefined }
    else { this.searchWebChallenge = null; this.searchChallengeHandle = undefined }
  }

  async completeWebChallenge(scope: SourceWebChallengeScope, id: number, routeVisible: boolean): Promise<boolean> {
    const receipt = scope === 'browse' ? this.browseWebChallenge : this.searchWebChallenge
    if (receipt?.id !== id) return false
    // Clear the visible receipt before retry so a repeated challenge cannot reuse it.
    try {
      return await this.challengeGate(scope).complete(id, routeVisible)
    } finally {
      if (receipt.requestHandle !== undefined) clearSourceRejectedRequest(receipt.sourceId, receipt.requestHandle)
      if ((scope === 'browse' ? this.browseWebChallenge : this.searchWebChallenge)?.id === id) {
        if (scope === 'browse') { this.browseWebChallenge = null; this.browseChallengeHandle = undefined }
        else { this.searchWebChallenge = null; this.searchChallengeHandle = undefined }
      }
    }
  }

  private challengeFingerprint(scope: SourceWebChallengeScope): string {
    const source = this.selectedSource
    return JSON.stringify([source?.sourceId, source?.version, source?.wasmByteCount,
      scope === 'browse' ? this.browseRequestId : this.searchRequestId,
      scope === 'browse' ? this.selectedListingId : this.searchQuery,
      scope === 'browse' ? this.browseFilterValues : this.searchFilterValues,
      scope === 'browse' ? this.browsePage : this.searchPage,
      scope === 'browse' ? this.browseNextCursor : this.searchNextCursor])
  }

  private webChallengeGuard(scope: SourceWebChallengeScope): () => boolean {
    const sourceId = this.selectedSource?.sourceId ?? ''
    const entry = this.registry.lookup(sourceId).entry
    const settingsRevision = appSourceSettingsStore.revisionForSource(sourceId)
    const fingerprint = this.challengeFingerprint(scope)
    return (): boolean => sourceId.length > 0 && entry !== undefined &&
      this.registry.lookup(sourceId).entry === entry &&
      appSourceSettingsStore.revisionForSource(sourceId) === settingsRevision &&
      this.challengeFingerprint(scope) === fingerprint
  }

  private publishWebChallenge(scope: SourceWebChallengeScope, error: Error, automaticRecovery: boolean,
    current: () => boolean, retry: (handle?: string) => Promise<void>): void {
    const source = this.selectedSource
    const explicitLogin = error instanceof SourceRuntimeError &&
      (error.diagnostic.code === 'auth_required' || error.diagnostic.reason === 'auth_required') &&
      (error.diagnostic.status === 0 || error.diagnostic.status === 401)
    if (!automaticRecovery && explicitLogin && source?.authentication !== undefined) {
      const gate = scope === 'browse' ? this.browseAuthenticationGate : this.searchAuthenticationGate
      const receipt = gate.issue(source.sourceId, scope, true, current, async (): Promise<void> => { await retry() })
      if (scope === 'browse') this.browseAuthentication = receipt
      else this.searchAuthentication = receipt
      return
    }
    const eligible = !automaticRecovery && error instanceof SourceRuntimeError &&
      (error.diagnostic.kind === 'challenge' || (error.diagnostic.code === 'auth_required' && source?.authentication === undefined)) &&
      source !== undefined && (source.webSessionOrigins ?? []).length > 0
    const handle = scope === 'browse' ? this.browseChallengeHandle : this.searchChallengeHandle
    const sourceId = source?.sourceId ?? ''
    const receipt = this.challengeGate(scope).issue(sourceId, scope, eligible, current, async (): Promise<void> => {
      // Detach the receipt before retry: begin-load clears old UI state, while
      // the same operation ID must survive until its one verified response is consumed.
      if (scope === 'browse') this.browseChallengeHandle = undefined
      else this.searchChallengeHandle = undefined
      try { await retry(handle) } finally {
        if (handle !== undefined) clearSourceRejectedRequest(sourceId, handle)
      }
    }, error instanceof SourceRuntimeError && error.diagnostic.kind === 'challenge', handle)
    if (receipt === null && handle !== undefined) clearSourceRejectedRequest(sourceId, handle)
    if (scope === 'browse') { this.browseWebChallenge = receipt; if (receipt === null) this.browseChallengeHandle = undefined }
    else { this.searchWebChallenge = receipt; if (receipt === null) this.searchChallengeHandle = undefined }
  }

  private browseRequestId: number = 0
  private searchRequestId: number = 0
  private searchResultsIdentity?: SourceSearchResultsIdentity
  private searchErrorIsFirstPage: boolean = false
  private persistSearchFilters: boolean = true
  private failedBrowseListing?: SourceListingDescriptor
  private failedBrowseHome: boolean = false

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
    this.sourceErrorMessage = ''
    try {
      // Registry summaries are fresh descriptive DTOs. Stable ForEach keys do
      // not prevent every unchanged SourceListItem receiving a new @Param.
      // Keep equal row inputs within this model only; compare the complete DTO
      // so names, icons, capabilities and future fields cannot become stale.
      // Still publish a new ordered array. Request/package validity continues
      // to use the live registry, never this presentation-only reuse.
      // Preserve this boundary for SOURCE_PACKAGE_INSTALL_UI_STALL in the
      // current work record; ordering and locale remain the callers' owners.
      const previous = new Map<string, SourceRuntimeRegistryInstalledSourceSummary>()
      this.sources.forEach((source: SourceRuntimeRegistryInstalledSourceSummary): void => {
        previous.set(source.sourceId, source)
      })
      this.sources = this.registry.listInstalledSourceSummaries().map(
        (source: SourceRuntimeRegistryInstalledSourceSummary): SourceRuntimeRegistryInstalledSourceSummary => {
          const retained = previous.get(source.sourceId)
          return retained !== undefined && JSON.stringify(retained) === JSON.stringify(source) ? retained : source
        })
    } catch (error) {
      const e = error as Error
      this.sourceErrorMessage = safeSourceBrowseErrorText(e, 'browse_error_load_sources')
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
    this.cancelFilterDataLoad()
    this.supportsFilterFetching = false
    this.useSearchForFilters = false
    this.filterDataReady = false
    this.clearWebChallenge('browse')
    this.clearWebChallenge('search')
    this.browseRequestId += 1
    this.selectedSource = source
    this.clearBrowseContent()
    this.listings = []
    this.homeAvailable = false
    this.filters = []
    this.browseFilterValues = {}
    this.searchFilterValues = {}
    this.browseErrorMessage = ''
    this.browseNeedsWebSession = false
    this.browseContentState = BrowseContentState.UNRESOLVED
    this.browseLoadIntent = BrowseLoadIntent.NONE
    this.browseErrorIntent = BrowseLoadIntent.NONE
    this.failedBrowseListing = undefined
    this.failedBrowseHome = false
  }

  private isCurrentBrowseSource(source: SourceRuntimeRegistryInstalledSourceSummary): boolean {
    const selected = this.selectedSource
    return selected !== undefined && selected.sourceId === source.sourceId &&
      selected.version === source.version && selected.wasmByteCount === source.wasmByteCount
  }

  private isSameBrowseSource(source: SourceRuntimeRegistryInstalledSourceSummary): boolean {
    return this.selectedSource?.sourceId === source.sourceId
  }

  private hasBrowseContent(): boolean {
    return this.homeSections.length > 0 || this.browseSections.some((section: BrowseSourceSectionState): boolean => {
      return section.manga.length > 0
    })
  }

  private clearBrowseListing(): void {
    this.popularManga = []
    this.latestManga = []
    this.browseSections = []
    this.selectedListingId = ''
    this.browsePage = 1
    this.browseNextCursor = ''
    this.hasMoreBrowse = false
  }

  private clearBrowseContent(): void {
    this.homeSections = []
    this.clearBrowseListing()
  }

  private browseDestinationCacheKey(source: SourceRuntimeRegistryInstalledSourceSummary,
    listing?: SourceListingDescriptor, values: SourceMangaListFilters = this.browseFilterValues,
    filters: SourceFilter[] = this.filters): string {
    const entry = this.registry.lookup(source.sourceId).entry
    if (entry === undefined || entry.enabled !== true) return ''
    const identity = sourceWebPackageIdentity(entry)
    const webSessions = (entry.webSessionOrigins ?? []).map((origin: string): string =>
      appSourceWebSessionStore.status(source.sourceId, origin).sessionId)
    const context = JSON.stringify([appSourceSettingsStore.revisionForSource(source.sourceId),
      SourcePrivateSessionHost.authenticationRevision(source.sourceId, identity), webSessions])
    // Keep only route-local first results. Settings and account changes cannot
    // display an earlier mirror's cards or another account's recommendations.
    if (this.browseCacheEntry !== entry || this.browseCacheContext !== context) {
      this.browseDestinationCache.clear()
      this.browseCacheEntry = entry
      this.browseCacheContext = context
    }
    if (listing === undefined) return JSON.stringify([identity, context, 'home'])
    const active = listing.supportsFilters === false ? {} as SourceMangaListFilters :
      this.filterValuesForQuery(values, '', filters)
    const ordered: SourceMangaListFilters = {}
    Object.keys(active).sort().forEach((key: string): void => { ordered[key] = active[key] })
    return JSON.stringify([identity, context, listing.id, ordered])
  }

  private rememberBrowseDestination(key: string, snapshot: BrowseDestinationSnapshot): void {
    if (key.length === 0) return
    this.browseDestinationCache.delete(key)
    if (this.browseDestinationCache.size >= BROWSE_DESTINATION_CACHE_LIMIT) {
      const keys: string[] = Array.from(this.browseDestinationCache.keys())
      this.browseDestinationCache.delete(keys[0])
    }
    this.browseDestinationCache.set(key, snapshot)
  }

  private beginBrowseLoad(intent: BrowseLoadIntent, retainsCurrentContent: boolean): void {
    this.clearWebChallenge('browse')
    this.loadingBrowse = true
    this.browseLoadIntent = intent
    this.browseErrorIntent = BrowseLoadIntent.NONE
    this.browseErrorMessage = ''
    this.browseNeedsWebSession = false
    this.failedBrowseListing = undefined
    this.failedBrowseHome = false
    this.browseContentState = retainsCurrentContent ? BrowseContentState.CONTENT : BrowseContentState.LOADING
  }

  private resolveBrowseLoad(): void {
    this.browseContentState = this.hasBrowseContent() ? BrowseContentState.CONTENT : BrowseContentState.EMPTY
    this.browseLoadIntent = BrowseLoadIntent.NONE
    this.browseErrorIntent = BrowseLoadIntent.NONE
    this.browseErrorMessage = ''
    this.browseNeedsWebSession = false
    this.failedBrowseListing = undefined
    this.failedBrowseHome = false
  }

  private failBrowseLoad(error: Error, intent: BrowseLoadIntent, fallbackKey: string): void {
    if (intent !== BrowseLoadIntent.PAGINATION && error instanceof SourceRuntimeError &&
      error.diagnostic.code === 'auth_required') {
      this.browseDestinationCache.clear()
      // Preserve the request identity for the login receipt and its retry.
      this.homeSections = []
      this.browseSections = []
      this.popularManga = []
      this.latestManga = []
      this.hasMoreBrowse = false
    }
    this.browseErrorMessage = safeSourceBrowseErrorText(error, fallbackKey)
    this.browseNeedsWebSession = error instanceof SourceRuntimeError &&
      (error.diagnostic.kind === 'challenge' || error.diagnostic.code === 'auth_required')
    this.browseContentState = BrowseContentState.ERROR
    this.browseLoadIntent = BrowseLoadIntent.NONE
    this.browseErrorIntent = intent
  }

  async loadBrowseHome(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    intent: BrowseLoadIntent = BrowseLoadIntent.INITIAL,
    automaticRecovery: boolean = false,
    operationGuardId?: string,
  ): Promise<void> {
    const sourceMatchesCurrent = this.isCurrentBrowseSource(source)
    const sameSourceRefresh = intent === BrowseLoadIntent.REFRESH && this.isSameBrowseSource(source)
    const previousListingId = sameSourceRefresh ? this.selectedListingId : ''
    const previousHomeAvailable = this.homeAvailable
    const previousCacheContext = this.browseCacheContext
    const refreshKey = sameSourceRefresh ? this.browseDestinationCacheKey(source) : ''
    // A user refresh belongs to the source identity, not to the currently
    // installed package bytes.  Keep ready content visible while a source
    // package has been reloaded or updated, then replace it atomically.
    const retainsCurrentContent = sameSourceRefresh && this.hasBrowseContent() && refreshKey.length > 0 &&
      (previousCacheContext.length === 0 || previousCacheContext === this.browseCacheContext)
    const effectiveIntent = sourceMatchesCurrent || sameSourceRefresh
      ? intent : BrowseLoadIntent.INITIAL
    if (sameSourceRefresh) {
      this.browseRequestId += 1
      this.selectedSource = source
      if (!retainsCurrentContent) {
        this.clearBrowseContent()
        this.selectedListingId = previousListingId
      }
    } else {
      this.setSelectedSource(source)
    }
    const requestId = this.browseRequestId
    this.beginBrowseLoad(effectiveIntent, retainsCurrentContent)
    // Listings, schema and saved preferences are resolved before the actual
    // browse request. Capture its guard at that request boundary, not before
    // asynchronous preparation; the catch keeps the same request guard.
    let challengeCurrent = this.webChallengeGuard('browse')
    try {
      const listings = await this.loadSourceListings(source)
      if (requestId !== this.browseRequestId) {
        return
      }
      const filterSchema = await this.loadSourceFilters(source)
      const filters = filterSchema.filters
      if (requestId !== this.browseRequestId) {
        return
      }
      const browseFilterValues: SourceMangaListFilters = filterSchema.useSearchForFilters === true ? {} :
        this.mergeSavedSourceFilterValues(
          source.sourceId,
          'browse',
          this.defaultSourceFilterValues(filters, ''),
          filters,
        )
      // Home and a listing are mutually exclusive destinations (CURRENT_STATUS:
      // SOURCE_BROWSE_HOME_STRUCTURE, user adopted 2026-10-25). An empty selected
      // listing ID denotes Home; refresh must not append/reset to Popular.
      // Only an independent source home may advertise this capability (source-runtime-abi).
      // Do not invent it from an existing listing or infer it from matching sampled cards.
      let listing = listings.find((item: SourceListingDescriptor): boolean => item.id === previousListingId)
      let homeAvailable = source.capabilities.indexOf('home') >= 0 ||
        (source.capabilities.indexOf('sourceInfo') < 0 && previousHomeAvailable)
      let homeSections: SourceHomeSectionState[] = []
      let cacheKey: string = ''
      if (listing === undefined) {
        if (this.sourceSupportsOperation(source, 'home')) {
          try {
            challengeCurrent = this.webChallengeGuard('browse')
            cacheKey = this.browseDestinationCacheKey(source)
            homeSections = await this.loadSourceHomeSections(source, listings, challengeCurrent, operationGuardId)
            homeAvailable = source.capabilities.indexOf('home') >= 0 || homeSections.length > 0
          } catch (error) {
            if (source.capabilities.indexOf('home') >= 0 || retainsCurrentContent) throw error as Error
            // Preserve the undeclared legacy operation fallback; a declared
            // Home failure remains an error, never a successful empty listing.
            homeAvailable = false
          }
          if (requestId !== this.browseRequestId) return
        }
        if (!homeAvailable && this.sourceSupportsOperation(source, 'mangaList')) {
          listing = this.defaultListingForBrowse(listings)
        }
      }
      let listingResult: SourceMangaList | undefined = undefined
      if (listing !== undefined) {
        challengeCurrent = this.webChallengeGuard('browse')
        cacheKey = this.browseDestinationCacheKey(source, listing, browseFilterValues, filters)
        listingResult = await this.loadMangaListing(source, listing.id, 1, '', browseFilterValues, filters,
          challengeCurrent, operationGuardId, listing.supportsFilters !== false)
        if (requestId !== this.browseRequestId) {
          return
        }
      }
      if ((listingResult !== undefined || homeAvailable) && challengeCurrent() &&
        cacheKey === this.browseDestinationCacheKey(source, listing, browseFilterValues, filters)) {
        this.rememberBrowseDestination(cacheKey, listingResult !== undefined ? { listingResult } : { homeSections })
      }
      this.listings = listings
      this.homeAvailable = homeAvailable
      this.publishFilterSchema(filterSchema)
      this.browseFilterValues = browseFilterValues
      this.homeSections = listing === undefined ? homeSections : []
      if (listing !== undefined && listingResult !== undefined) {
        this.applyBrowseListing(listing, listingResult, 1)
      } else {
        this.clearBrowseListing()
      }
      this.resolveBrowseLoad()
    } catch (error) {
      if (requestId !== this.browseRequestId) {
        return
      }
      const e = error as Error
      this.failBrowseLoad(e, effectiveIntent, 'browse_error_load_home')
      this.publishWebChallenge('browse', e, automaticRecovery, challengeCurrent,
        async (handle?: string): Promise<void> => { await this.retryBrowseFailure(true, handle) })
    } finally {
      if (requestId === this.browseRequestId) {
        this.loadingBrowse = false
      }
    }
  }

  async selectBrowseHome(automaticRecovery: boolean = false, operationGuardId?: string): Promise<void> {
    if (!this.homeAvailable) return
    await this.selectBrowseDestination(undefined, automaticRecovery, operationGuardId)
  }

  async selectBrowseListing(listing: SourceListingDescriptor, replacePending: boolean = false, automaticRecovery: boolean = false, operationGuardId?: string): Promise<void> {
    if (!replacePending && this.loadingBrowse && this.selectedListingId === listing.id) return
    await this.selectBrowseDestination(listing, automaticRecovery, operationGuardId)
  }

  private async selectBrowseDestination(listing?: SourceListingDescriptor, automaticRecovery: boolean = false,
    operationGuardId?: string): Promise<void> {
    const source = this.selectedSource
    if (source === undefined || (this.loadingBrowse && this.browseLoadIntent === BrowseLoadIntent.INITIAL)) return
    const cacheKey = this.browseDestinationCacheKey(source, listing)
    const cached = automaticRecovery ? undefined : this.browseDestinationCache.get(cacheKey)
    const requestId = ++this.browseRequestId
    if (listing === undefined) {
      this.clearBrowseListing()
      this.homeSections = cached?.homeSections ?? []
    } else {
      this.homeSections = []
      this.applyBrowseListing(listing, cached?.listingResult ?? { manga: [], hasNextPage: false }, 1)
    }
    this.beginBrowseLoad(BrowseLoadIntent.LISTING_REPLACEMENT, cached !== undefined)
    if (cached !== undefined && !this.hasBrowseContent()) this.browseContentState = BrowseContentState.EMPTY
    const challengeCurrent = this.webChallengeGuard('browse')
    try {
      if (listing === undefined) {
        const sections = await this.loadSourceHomeSections(source, this.listings, challengeCurrent, operationGuardId)
        if (requestId !== this.browseRequestId) return
        if (challengeCurrent() && cacheKey === this.browseDestinationCacheKey(source)) {
          this.rememberBrowseDestination(cacheKey, { homeSections: sections })
        }
        this.homeSections = sections
      } else {
        const result = await this.loadMangaListing(source, listing.id, 1, '', this.browseFilterValues, this.filters,
          challengeCurrent, operationGuardId)
        if (requestId !== this.browseRequestId) return
        if (challengeCurrent() && cacheKey === this.browseDestinationCacheKey(source, listing)) {
          this.rememberBrowseDestination(cacheKey, { listingResult: result })
        }
        this.applyBrowseListing(listing, result, 1)
      }
      this.resolveBrowseLoad()
    } catch (error) {
      if (requestId !== this.browseRequestId) {
        return
      }
      const e = error as Error
      this.failedBrowseHome = listing === undefined
      this.failedBrowseListing = listing
      this.failBrowseLoad(e, BrowseLoadIntent.LISTING_REPLACEMENT, 'browse_error_load_home')
      this.publishWebChallenge('browse', e, automaticRecovery, challengeCurrent,
        async (handle?: string): Promise<void> => { await this.retryBrowseFailure(true, handle) })
    } finally {
      if (requestId === this.browseRequestId) {
        this.loadingBrowse = false
      }
    }
  }

  private updateFilterValue(values: SourceMangaListFilters, filterId: string, value: SourceFilterValue | undefined): SourceMangaListFilters | undefined {
    const filter = this.filters.find((item: SourceFilter): boolean => item.id === filterId)
    if (filter === undefined || filter.type === 'header') {
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
    await this.applyBrowseFilterValues(nextValues)
  }

  private textFilterValues(current: SourceMangaListFilters, changes: Record<string, string>): SourceMangaListFilters {
    let next = current
    for (const id of Object.keys(changes)) {
      const value = changes[id].trim()
      next = this.updateFilterValue(next, id, value.length > 0 ? value : undefined) ?? next
    }
    return next
  }

  async applyBrowseTextFilters(changes: Record<string, string>): Promise<void> {
    const next = this.textFilterValues(this.browseFilterValues, changes)
    if (next !== this.browseFilterValues) await this.applyBrowseFilterValues(next)
  }

  private async applyBrowseFilterValues(nextValues: SourceMangaListFilters): Promise<void> {
    if (!this.browseListingAllowsFilters()) return
    this.saveSourceFilterValues('browse', nextValues)
    this.browseFilterValues = nextValues
    const listing = this.currentListing()
    if (this.selectedSource !== undefined && listing !== undefined) {
      await this.selectBrowseListing(listing, true)
    }
  }

  async resetBrowseFilters(): Promise<void> {
    if (this.selectedSource === undefined || !this.browseListingAllowsFilters()) {
      return
    }
    const nextValues = this.defaultSourceFilterValues(this.filters, '')
    this.clearSavedSourceFilterValues('browse')
    this.browseFilterValues = nextValues
    const listing = this.currentListing()
    if (listing !== undefined) {
      await this.selectBrowseListing(listing, true)
    }
  }

  async retryBrowseFailure(automaticRecovery: boolean = false, operationGuardId?: string): Promise<void> {
    const intent = this.browseErrorIntent
    if (intent === BrowseLoadIntent.NONE) {
      return
    }
    if (intent === BrowseLoadIntent.PAGINATION) {
      await this.loadMoreBrowse(automaticRecovery, operationGuardId)
      return
    }
    if (intent === BrowseLoadIntent.LISTING_REPLACEMENT && this.failedBrowseHome) {
      await this.selectBrowseHome(automaticRecovery, operationGuardId)
      return
    }
    if (intent === BrowseLoadIntent.LISTING_REPLACEMENT && this.failedBrowseListing !== undefined) {
      await this.selectBrowseListing(this.failedBrowseListing, false, automaticRecovery, operationGuardId)
      return
    }
    if (this.selectedSource === undefined) {
      return
    }
    await this.loadBrowseHome(
      this.selectedSource,
      intent === BrowseLoadIntent.REFRESH ? BrowseLoadIntent.REFRESH : BrowseLoadIntent.INITIAL,
      automaticRecovery,
      operationGuardId,
    )
  }

  async ensureSearchFilters(source: SourceRuntimeRegistryInstalledSourceSummary, persistFilters: boolean = true): Promise<void> {
    this.persistSearchFilters = persistFilters
    this.prepareSearchSource(source)
    if (this.filters.length > 0) {
      if (Object.keys(this.searchFilterValues).length === 0) {
        this.searchFilterValues = this.initialSearchFilterValues()
        this.restoreSavedSearchFilterValues(source.sourceId)
      }
      return
    }
    const selected = this.selectedSource
    const requestId = this.searchRequestId
    const entry = this.registry.lookup(source.sourceId).entry
    const settingsRevision = appSourceSettingsStore.revisionForSource(source.sourceId)
    const values = this.searchFilterValues
    const schema = await this.loadSourceFilters(source)
    if (this.selectedSource !== selected || this.searchRequestId !== requestId ||
      this.registry.lookup(source.sourceId).entry !== entry ||
      appSourceSettingsStore.revisionForSource(source.sourceId) !== settingsRevision ||
      this.searchFilterValues !== values || this.persistSearchFilters !== persistFilters) return
    this.publishFilterSchema(schema)
    // An empty schema is still a completed initialization. Central search
    // preparation must preserve current temporary/legacy values on re-entry.
    if (Object.keys(this.searchFilterValues).length === 0) {
      this.searchFilterValues = this.initialSearchFilterValues()
      this.restoreSavedSearchFilterValues(source.sourceId)
    }
  }

  private prepareSearchSource(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    const sourceChanged = this.selectedSource === undefined || this.selectedSource.sourceId !== source.sourceId
    if (sourceChanged) {
      this.clearSearch(source)
      this.filters = []
      this.useSearchForFilters = false
      this.browseFilterValues = {}
      this.searchFilterValues = {}
    }
  }

  setSearchFilterValue(filterId: string, value: SourceFilterValue | undefined): boolean {
    const nextValues = this.updateFilterValue(this.searchFilterValues, filterId, value)
    if (nextValues === undefined) {
      return false
    }
    this.saveSourceFilterValues('search', nextValues)
    this.searchFilterValues = nextValues
    return true
  }

  applySearchTextFilters(changes: Record<string, string>): boolean {
    const next = this.textFilterValues(this.searchFilterValues, changes)
    if (next === this.searchFilterValues) return false
    this.saveSourceFilterValues('search', next)
    this.searchFilterValues = next
    return true
  }

  resetSearchFilters(query: string = this.searchQuery): void {
    if (!this.filters.some((filter: SourceFilter): boolean => filter.scope !== undefined)) {
      this.clearSavedSourceFilterValues('search')
      this.searchFilterValues = this.initialSearchFilterValues()
      return
    }
    // Reset only the active scope; choices in the other scope remain available
    // when the query changes, including in the persisted search preferences.
    const activeFilters = sourceFiltersForQuery(this.filters, query, this.useSearchForFilters)
    const nextValues: SourceMangaListFilters = {}
    Object.keys(this.searchFilterValues).forEach((key: string) => {
      if (!activeFilters.some((filter: SourceFilter): boolean => this.filterRequestKey(filter) === key)) {
        nextValues[key] = this.searchFilterValues[key]
      }
    })
    const defaults: SourceMangaListFilters = this.persistSearchFilters ? this.defaultSourceFilterValues(activeFilters) : {}
    activeFilters.forEach((filter: SourceFilter) => {
      if (filter.type === 'header') return
      const key = this.filterRequestKey(filter)
      if (defaults[key] !== undefined) nextValues[key] = defaults[key]
    })
    this.searchFilterValues = nextValues
    this.saveSourceFilterValues('search', nextValues)
  }

  hasSearchFilterChanges(query: string = this.searchQuery): boolean {
    return !this.sourceFilterValuesEqual(this.filterValuesForQuery(this.searchFilterValues, query, this.filters, this.useSearchForFilters),
      this.filterValuesForQuery(this.initialSearchFilterValues(), query, this.filters, this.useSearchForFilters))
  }

  private initialSearchFilterValues(): SourceMangaListFilters {
    // Global search sends no filter values. Its continuation is route-local and
    // must neither inherit nor overwrite an independent source search's choices.
    return this.persistSearchFilters ? this.defaultSourceFilterValues(this.filters) : {}
  }

  async loadMoreBrowse(automaticRecovery: boolean = false, operationGuardId?: string): Promise<void> {
    if (this.loadingBrowse || !this.hasMoreBrowse || this.selectedSource === undefined) {
      return
    }
    // The retained old tail must not replace a failed switch/refresh with a
    // pagination attempt and consume that destination's verification/retry.
    if (this.browseErrorIntent === BrowseLoadIntent.LISTING_REPLACEMENT ||
      this.browseErrorIntent === BrowseLoadIntent.REFRESH) return
    const requestId = this.browseRequestId
    const source = this.selectedSource
    const page = this.browsePage + 1
    const cursor = this.browseNextCursor
    const listing = this.currentListing()
    if (listing === undefined) {
      this.hasMoreBrowse = false
      return
    }
    this.beginBrowseLoad(BrowseLoadIntent.PAGINATION, true)
    const challengeCurrent = this.webChallengeGuard('browse')
    try {
      const more = await this.loadMangaListing(source, listing.id, page, cursor, this.browseFilterValues, this.filters, challengeCurrent, operationGuardId)
      if (requestId !== this.browseRequestId) {
        return
      }
      this.browsePage = page
      this.mergeBrowseListingPage(listing, more, page)
      this.hasMoreBrowse = more.hasNextPage
      this.resolveBrowseLoad()
    } catch (error) {
      if (requestId !== this.browseRequestId) {
        return
      }
      const e = error as Error
      this.failBrowseLoad(e, BrowseLoadIntent.PAGINATION, 'browse_error_load_more')
      this.publishWebChallenge('browse', e, automaticRecovery, challengeCurrent,
        async (handle?: string): Promise<void> => { await this.retryBrowseFailure(true, handle) })
    } finally {
      if (requestId === this.browseRequestId) {
        this.loadingBrowse = false
      }
    }
  }

  private searchResultFingerprint(source: SourceRuntimeRegistryInstalledSourceSummary, query: string): string {
    return JSON.stringify([source.sourceId, source.version, source.wasmByteCount,
      appSourceSettingsStore.revisionForSource(source.sourceId), query.trim(), this.searchFilterValues])
  }

  async runSearch(source: SourceRuntimeRegistryInstalledSourceSummary, query: string, automaticRecovery: boolean = false,
    operationGuardId?: string, fromFilters: boolean = this.filterOnlySearch): Promise<void> {
    // In-place Browse search also comes here without ensureSearchFilters.
    // Search owns its defaults/saved choices; a late Browse listing must never
    // overwrite them and retire the new search's HTTP guard (237 MangaBall).
    this.prepareSearchSource(source)
    const normalizedQuery = query.trim()
    const filterOnly = fromFilters && this.useSearchForFilters && normalizedQuery.length === 0
    this.filterOnlySearch = filterOnly
    const entry = this.registry.lookup(source.sourceId).entry
    const settingsRevision = appSourceSettingsStore.revisionForSource(source.sourceId)
    const persistFilters = this.persistSearchFilters
    let fingerprint = this.searchResultFingerprint(source, query)
    const retained = this.searchResultsIdentity
    let retainsCurrentResults = this.searchResults.length > 0 && entry !== undefined &&
      retained?.entry === entry && retained.fingerprint === fingerprint
    const requestId = this.searchRequestId + 1
    this.searchRequestId = requestId
    this.selectedSource = source
    this.searchQuery = query
    this.searchPage = retainsCurrentResults ? retained!.page : 1
    this.searchNextCursor = retainsCurrentResults ? retained!.cursor : ''
    this.searchErrorIsFirstPage = false
    this.loadingSearch = true
    this.searchErrorMessage = ''
    this.searchNeedsWebSession = false
    this.clearWebChallenge('search')
    let challengeCurrent = this.webChallengeGuard('search')
    let continueEmptyPage = false
    try {
      if (normalizedQuery.length === 0 && !filterOnly) {
        this.searchResults = []
        this.hasMoreSearch = false
        return
      }
      await this.ensureSearchFilters(source, persistFilters)
      if (requestId !== this.searchRequestId || !this.isCurrentBrowseSource(source) ||
        this.registry.lookup(source.sourceId).entry !== entry ||
        appSourceSettingsStore.revisionForSource(source.sourceId) !== settingsRevision ||
        this.persistSearchFilters !== persistFilters) return
      fingerprint = this.searchResultFingerprint(source, query)
      retainsCurrentResults = this.searchResults.length > 0 && entry !== undefined &&
        retained?.entry === entry && retained.fingerprint === fingerprint
      this.searchPage = retainsCurrentResults ? retained!.page : 1
      this.searchNextCursor = retainsCurrentResults ? retained!.cursor : ''
      challengeCurrent = this.webChallengeGuard('search')
      const result = await this.searchSource(source, normalizedQuery, 1, '', challengeCurrent, operationGuardId)
      if (requestId !== this.searchRequestId) {
        return
      }
      this.searchResults = result.manga
      this.searchPage = 1
      this.hasMoreSearch = result.hasNextPage
      this.searchNextCursor = result.nextCursor ?? ''
      this.searchResultsIdentity = { entry, fingerprint, page: 1, cursor: this.searchNextCursor }
      continueEmptyPage = result.manga.length === 0 && result.hasNextPage
    } catch (error) {
      if (requestId !== this.searchRequestId) {
        return
      }
      const e = error as Error
      this.searchErrorMessage = safeSearchDiagnostic(e).userText
      this.searchNeedsWebSession = e instanceof SourceRuntimeError &&
        (e.diagnostic.kind === 'challenge' || e.diagnostic.code === 'auth_required')
      this.publishWebChallenge('search', e, automaticRecovery, challengeCurrent,
        async (handle?: string): Promise<void> => { await this.runSearch(source, query, true, handle, fromFilters) })
      this.searchErrorIsFirstPage = true
      if (!retainsCurrentResults) {
        this.searchResults = []
        this.searchNextCursor = ''
      }
      this.hasMoreSearch = false
    } finally {
      if (requestId === this.searchRequestId) {
        this.loadingSearch = false
      }
    }
    if (continueEmptyPage && requestId === this.searchRequestId &&
      this.registry.lookup(source.sourceId).entry === entry &&
      this.searchResultFingerprint(source, query) === fingerprint) {
      await this.loadMoreSearch(automaticRecovery)
    }
  }

  clearSearch(source?: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.clearWebChallenge('search')
    this.searchRequestId += 1
    if (source !== undefined) {
      this.selectedSource = source
    }
    this.searchQuery = ''
    this.filterOnlySearch = false
    this.searchResultsIdentity = undefined
    this.searchErrorIsFirstPage = false
    this.searchPage = 1
    this.searchResults = []
    this.hasMoreSearch = false
    this.loadingSearch = false
    this.searchErrorMessage = ''
    this.searchNeedsWebSession = false
    this.searchNextCursor = ''
  }

  async retrySearchPage(automaticRecovery: boolean = false, operationGuardId?: string): Promise<void> {
    if (this.loadingSearch || this.searchErrorMessage.length === 0 ||
      this.selectedSource === undefined || !this.hasActiveSearch) {
      return
    }
    if (this.searchErrorIsFirstPage) {
      await this.runSearch(this.selectedSource, this.searchQuery, automaticRecovery, operationGuardId)
      return
    }
    this.hasMoreSearch = true
    await this.loadMoreSearch(automaticRecovery, operationGuardId)
  }

  async loadMoreSearch(automaticRecovery: boolean = false, operationGuardId?: string): Promise<void> {
    if (this.loadingSearch || !this.hasMoreSearch || this.selectedSource === undefined || !this.hasActiveSearch) {
      return
    }
    const requestId = this.searchRequestId
    const source = this.selectedSource
    const query = this.searchQuery.trim()
    this.searchErrorIsFirstPage = false
    this.loadingSearch = true
    this.searchErrorMessage = ''
    this.searchNeedsWebSession = false
    this.clearWebChallenge('search')
    let challengeCurrent = this.webChallengeGuard('search')
    try {
      // Empty filtered pages do not change the native grid's geometry, so it
      // cannot emit another reach-end event. Follow the source's advancing
      // cursors until rows arrive or the source ends. Commit each valid cursor
      // so failure/verification retries only the request that actually failed.
      const visited = new Set<string>()
      while (requestId === this.searchRequestId && this.hasMoreSearch) {
        const page = this.searchPage + 1
        const cursor = this.searchNextCursor
        const requestedCursor = cursor.length > 0 ? cursor : `${page}`
        challengeCurrent = this.webChallengeGuard('search')
        if (!challengeCurrent()) return
        if (visited.has(requestedCursor)) {
          const failure: SourceRuntimeCallResponse = { ok: false, reasonCode: 'parse_error' }
          throw new SourceRuntimeError(failure)
        }
        visited.add(requestedCursor)
        const more = await this.searchSource(source, query, page, cursor, challengeCurrent, operationGuardId)
        if (requestId !== this.searchRequestId || !challengeCurrent()) return
        const previousCount = this.searchResults.length
        this.searchPage = page
        this.searchResults = appendUniqueSourceManga(this.searchResults, more.manga)
        this.hasMoreSearch = more.hasNextPage
        this.searchNextCursor = more.nextCursor ?? ''
        if (this.searchResultsIdentity !== undefined) {
          this.searchResultsIdentity.page = page
          this.searchResultsIdentity.cursor = this.searchNextCursor
        }
        if (this.searchResults.length > previousCount || !this.hasMoreSearch) return
      }
    } catch (error) {
      if (requestId !== this.searchRequestId) {
        return
      }
      const e = error as Error
      this.searchErrorMessage = safeSearchDiagnostic(e).userText
      this.searchNeedsWebSession = e instanceof SourceRuntimeError &&
        (e.diagnostic.kind === 'challenge' || e.diagnostic.code === 'auth_required')
      this.publishWebChallenge('search', e, automaticRecovery, challengeCurrent,
        async (handle?: string): Promise<void> => { await this.retrySearchPage(true, handle) })
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
    isActive: (() => boolean) | undefined = undefined,
    operationGuardId: string | undefined = undefined,
  ): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: this.pageCursor(page, cursor),
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const args: SourceSearchArgs = {
      query,
      page: pageArg,
      filters: this.filterValuesForQuery(this.searchFilterValues, query, this.filters, this.useSearchForFilters),
    }
    return this.runSourceOperation(source.sourceId, 'search', args, page, isActive, operationGuardId)
  }

  async loadMangaList(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    section: BrowseSourceSection,
    page: number,
  ): Promise<SourceMangaList> {
    return this.loadMangaListing(source, section === 'latest' ? 'listing:latest' : 'listing:popular', page)
  }

  browseListingAllowsFilters(listingId: string = this.selectedListingId): boolean {
    return this.listings.find((listing: SourceListingDescriptor): boolean => listing.id === listingId)
      ?.supportsFilters !== false
  }

  async loadMangaListing(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    listingId: string,
    page: number,
    cursor: string = '',
    filterValues: SourceMangaListFilters = this.browseFilterValues,
    filters: SourceFilter[] = this.filters,
    isActive: (() => boolean) | undefined = undefined,
    operationGuardId?: string,
    listingAllowsFilters: boolean = this.browseListingAllowsFilters(listingId),
  ): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: this.pageCursor(page, cursor),
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const args: SourceMangaListArgs = {
      listingId,
      page: pageArg,
      filters: listingAllowsFilters ? this.filterValuesForQuery(filterValues, '', filters) : {},
    }
    return this.runSourceOperation(source.sourceId, 'get_manga_list', args, page, isActive, operationGuardId)
  }

  private publishFilterSchema(schema: SourceFilterSchema): void {
    this.cancelFilterDataLoad()
    this.filters = schema.filters
    this.useSearchForFilters = schema.useSearchForFilters === true
    this.supportsFilterFetching = schema.supportsFilterFetching
    this.filterDataReady = false
  }

  cancelFilterDataLoad(): void {
    this.filterDataRevision += 1
    this.loadingFilterData = false
  }

  // Initial filters contain defaults and stable deferred field IDs only.
  // Optional network metadata belongs to opening the filter panel; its failure
  // must not erase catalogue/search results or the user's saved selections.
  async fetchSourceFilterData(): Promise<string> {
    if (!this.supportsFilterFetching || this.filterDataReady || this.loadingFilterData) return ''
    const source = this.selectedSource
    if (source === undefined) return ''
    const entry = this.registry.lookup(source.sourceId).entry
    const settingsRevision = appSourceSettingsStore.revisionForSource(source.sourceId)
    const revision = ++this.filterDataRevision
    const current = (): boolean => revision === this.filterDataRevision && this.selectedSource === source &&
      this.registry.lookup(source.sourceId).entry === entry &&
      appSourceSettingsStore.revisionForSource(source.sourceId) === settingsRevision
    this.loadingFilterData = true
    try {
      const args: SourceFilterDataArgs = { fetchFilterData: true }
      const response = await this.runSourceOperationResponse(source.sourceId, 'get_filters', args, 1, current)
      if (!current()) return ''
      const schema = parseSourceFilterSchemaJson(JSON.stringify(response.data ?? {}))
      this.filters = schema.filters
      this.filterDataReady = true
      return ''
    } catch (error) {
      return current() ? safeSourceBrowseErrorText(error as Error, 'source_failure_runtime') : ''
    } finally {
      if (revision === this.filterDataRevision) this.loadingFilterData = false
    }
  }

  private async loadSourceFilters(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<SourceFilterSchema> {
    if (!this.sourceSupportsOperation(source, 'filters')) {
      return { filters: [], supportsFilterFetching: false }
    }
    try {
      const args: SourceListingsArgs = {}
      const response = await this.runSourceOperationResponse(source.sourceId, 'get_filters', args, 1)
      return parseSourceFilterSchemaJson(JSON.stringify(response.data ?? {}))
    } catch (error) {
      if (source.capabilities.indexOf('filters') >= 0) {
        throw error as Error
      }
      return { filters: [], supportsFilterFetching: false }
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
      return listings.length > 0 || source.capabilities.indexOf('listings') >= 0 ? listings : this.defaultListings()
    } catch (error) {
      if (source.capabilities.indexOf('listings') >= 0) {
        throw error as Error
      }
      return this.defaultListings()
    }
  }

  private async loadSourceHomeSections(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    listings: SourceListingDescriptor[],
    isActive?: () => boolean,
    operationGuardId?: string,
  ): Promise<SourceHomeSectionState[]> {
    if (!this.sourceSupportsOperation(source, 'home')) {
      return []
    }
    const args: SourceHomeArgs = {}
    const response = await this.runSourceOperationResponse(source.sourceId, 'get_home', args, 1, isActive, operationGuardId)
    return parseSourceHomeSectionsFromResponse(source.sourceId, response)
      .filter((section: SourceHomeSectionState): boolean => {
        if (section.kind === 'mangaList') return section.manga.length > 0
        return section.kind === 'listingLink' && section.listingId !== undefined &&
          listings.some((listing: SourceListingDescriptor): boolean => listing.id === section.listingId)
      })
  }

  private applyBrowseListing(
    listing: SourceListingDescriptor,
    result: SourceMangaList,
    page: number,
  ): void {
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
      this.browseSections[0]?.listing ?? this.defaultListingForBrowse(this.listings)
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

  private defaultSourceFilterValues(filters: SourceFilter[], query?: string): SourceMangaListFilters {
    const values: SourceMangaListFilters = {}
    const applicable = query === undefined ? filters : sourceFiltersForQuery(filters, query)
    applicable.forEach((filter: SourceFilter) => {
      if (filter.type !== 'header' && filter.value !== undefined) {
        const key = this.filterRequestKey(filter)
        values[key] = this.normalizeFilterRequestValue(key, filter.value)
      }
    })
    return values
  }

  private filterValuesForQuery(values: SourceMangaListFilters, query: string,
    filters: SourceFilter[] = this.filters, searchWithoutQuery: boolean = false): SourceMangaListFilters {
    const applicable = sourceFiltersForQuery(filters, query, searchWithoutQuery)
    const result: SourceMangaListFilters = {}
    Object.keys(values).forEach((key: string) => {
      const matching = filters.filter((filter: SourceFilter): boolean => this.filterRequestKey(filter) === key)
      // Preserve unknown legacy keys; declared headers and out-of-scope keys never reach a source.
      if (matching.length === 0 || matching.some((filter: SourceFilter): boolean =>
        filter.type !== 'header' && applicable.indexOf(filter) >= 0)) result[key] = values[key]
    })
    return result
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
    if (!this.persistSearchFilters) {
      return
    }
    this.searchFilterValues = this.mergeSavedSourceFilterValues(sourceId, 'search', this.searchFilterValues)
  }

  private mergeSavedSourceFilterValues(
    sourceId: string,
    kind: SourceFilterPreferenceKind,
    defaults: SourceMangaListFilters,
    filters: SourceFilter[] = this.filters,
  ): SourceMangaListFilters {
    const saved = appSourceFilterPreferencesStore.loadForSource(sourceId, kind, filters.filter((filter: SourceFilter): boolean => filter.type !== 'header'))
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
    if (kind === 'search' && !this.persistSearchFilters) {
      return
    }
    const sourceId = this.selectedSource?.sourceId
    if (sourceId === undefined) {
      return
    }
    appSourceFilterPreferencesStore.saveForSource(sourceId, kind, values, this.filters.filter((filter: SourceFilter): boolean => filter.type !== 'header'))
  }

  private clearSavedSourceFilterValues(kind: SourceFilterPreferenceKind): void {
    if (kind === 'search' && !this.persistSearchFilters) {
      return
    }
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
    isActive: (() => boolean) | undefined = undefined,
    operationGuardId: string | undefined = undefined,
  ): Promise<SourceMangaList> {
    const lookup = this.registry.lookup(sourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      throw new Error(AppStrings.get('browse_error_source_unavailable'))
    }
    const requestJson = this.buildRequestJson(sourceId, operation, args, page)
    const scope: SourceWebChallengeScope = operation === 'search' ? 'search' : 'browse'
    const ownGuard = isActive !== undefined && operationGuardId === undefined
    const guardId = isActive === undefined ? undefined : operationGuardId ?? newSourceRuntimeOperationGuardId()
    const releaseGuard = isActive === undefined || guardId === undefined ? undefined :
      registerSourceRuntimeOperationGuard(guardId, isActive)
    let keepRejected = false
    try {
      const responseJson = await enqueueSourceOperation(requestJson, lookup.entry.wasmBytes,
        sourceHttpIdentityJson(lookup.entry, guardId, false, operation), sourceId, isActive)
      const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
      if (response.ok !== true) {
        throw this.runtimeError(response, operation)
      }
      return parseSourceMangaListFromResponse(sourceId, response)
    } catch (error) {
      const e = error as Error
      if (ownGuard && guardId !== undefined && isActive?.() &&
        e instanceof SourceRuntimeError && (e.diagnostic.kind === 'challenge' || e.diagnostic.code === 'auth_required') &&
        (lookup.entry.webSessionOrigins ?? []).length > 0) {
        selectSourceRejectedRequest(sourceId, guardId, e.challengeRequestId)
        if (scope === 'search') this.searchChallengeHandle = guardId
        else this.browseChallengeHandle = guardId
        keepRejected = true
      }
      throw e
    } finally {
      releaseGuard?.()
      if (ownGuard && guardId !== undefined && !keepRejected) {
        clearSourceRejectedRequest(sourceId, guardId)
      }
    }
  }

  private async runSourceOperationResponse(
    sourceId: string,
    operation: string,
    args: SourceOperationArgs,
    page: number,
    isActive?: () => boolean,
    operationGuardId?: string,
  ): Promise<SourceRuntimeCallResponse> {
    const lookup = this.registry.lookup(sourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      throw new Error(AppStrings.get('browse_error_source_unavailable'))
    }
    const requestJson = this.buildRequestJson(sourceId, operation, args, page)
    const ownGuard = isActive !== undefined && operationGuardId === undefined
    const guardId = isActive === undefined ? undefined : operationGuardId ?? newSourceRuntimeOperationGuardId()
    const releaseGuard = guardId === undefined || isActive === undefined ? undefined :
      registerSourceRuntimeOperationGuard(guardId, isActive)
    let keepRejected = false
    try {
      const responseJson = await enqueueSourceOperation(requestJson, lookup.entry.wasmBytes,
        sourceHttpIdentityJson(lookup.entry, guardId, false, operation), sourceId, isActive)
      const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
      if (response.ok !== true) throw this.runtimeError(response, operation)
      return response
    } catch (error) {
      const e = error as Error
      if (operation === 'get_home' && ownGuard && guardId !== undefined && isActive?.() &&
        e instanceof SourceRuntimeError && (e.diagnostic.kind === 'challenge' || e.diagnostic.code === 'auth_required') &&
        (lookup.entry.webSessionOrigins ?? []).length > 0) {
        // Keep the rejected home request available until verification retries or cancels it.
        selectSourceRejectedRequest(sourceId, guardId, e.challengeRequestId)
        this.browseChallengeHandle = guardId
        keepRejected = true
      }
      throw e
    } finally {
      releaseGuard?.()
      if (ownGuard && guardId !== undefined && !keepRejected) clearSourceRejectedRequest(sourceId, guardId)
    }
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

  private runtimeError(response: SourceRuntimeCallResponse, operation: string): SourceRuntimeError {
    const error = new SourceRuntimeError(response)
    const details = error.diagnostic
    DiagnosticLogger.warn('browse_view_model', 'source_operation_failed',
      'operation=' + safeDiagnosticCode(operation) + ' reason=' + details.reason +
      ' error=' + details.code + ' http=' + details.status + ' kind=' + details.kind)
    return error
  }

  sourceLanguageBadge(source: SourceRuntimeRegistryInstalledSourceSummary): string {
    return sourceLanguageName(source.language)
  }
}
