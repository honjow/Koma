import { common } from '@kit.AbilityKit'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { MOCK_LIBRARY_READER_SESSION } from './MockLibraryData'
import { createReaderSessionConfigFromComic } from './ReaderSessionStore'
import { RemoteServerStore, WebDavServerRecord } from './RemoteServerStore'
import { SourceManga } from './SourceModels'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { KomgaSeriesDto } from '../remote/KomgaModels'
import {
  KavitaSearchResultDto,
  KavitaSeriesDto,
} from '../remote/KavitaModels'
import {
  OpdsClient,
  mapOpdsPublicationToImages,
  resolveOpdsHref,
  resolveOpdsSearchUrl,
} from '../remote/OpdsParser'
import {
  OpdsBookDto,
  OpdsImageDto,
  OpdsLink,
  OpdsParseResult,
} from '../remote/OpdsModels'
import { DavComicCandidateKind, DavResource } from '../remote/WebDavModels'
import { WebDavClient, readWebDavUrlPath } from '../remote/WebDavClient'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import {
  CrossSearchSectionState,
  SearchDiagnostic,
  safeSearchDiagnostic,
  searchStateUserText,
} from './SearchStateMapper'
import { AppStrings } from '../i18n/AppStrings'
import { compareNaturalPath } from '../import/ImageSortUtils'

export type CrossSearchSourceKind = 'local' | 'komga' | 'kavita' | 'opds' | 'webdav' | 'wasm'
export type CrossSearchSourceFilter = 'all' | 'local' | 'private' | 'source'
export type CrossSearchMatchQuality = 'title_exact' | 'title_prefix' | 'title_contains' | 'metadata_prefix' | 'metadata_contains' | 'weak'

export interface CrossSearchResultItem {
  id: string
  title: string
  subtitle: string
  sourceKind: CrossSearchSourceKind
  sourceLabel: string
  remoteServerId?: string
  coverUri?: string
  localComicId?: string
  sourceId?: string
  sourceMangaId?: string
  sourceMangaUrl?: string
  komgaSeriesId?: string
  kavitaLibraryId?: number
  kavitaSeriesId?: string
  opdsFeedUrl?: string
  opdsSearchQuery?: string
  opdsPublicationId?: string
  webDavRootUrl?: string
  webDavHref?: string
  webDavPathSegments?: string[]
  webDavIsCollection?: boolean
  matchQuality?: CrossSearchMatchQuality
  matchScore?: number
}

export interface CrossSearchSection {
  id: string
  title: string
  sourceKind: CrossSearchSourceKind
  loading: boolean
  state: CrossSearchSectionState
  resultCount: number
  diagnosticCode: string
  errorText: string
  items: CrossSearchResultItem[]
}

interface SourceSearchOutcome {
  section: CrossSearchSection
}

interface PagedSearchRun {
  cancelled: boolean
}

interface WebDavSearchRun {
  cancelled: boolean
  resources: DavResource[]
  serverId?: string
  client?: WebDavClient
  diagnostic?: SearchDiagnostic
}

const SEARCH_TIMEOUT_MS: number = 5000
const KOMGA_PAGE_SIZE: number = 20
const SOURCE_PAGE_SIZE: number = 20

export function normalizeCrossSearchText(value: string): string {
  const trimmed = value.trim()
  const lower = trimmed.toLowerCase() === trimmed ? trimmed : trimmed.toLocaleLowerCase()
  let normalized = ''
  let previousWasSpace = true
  for (let index = 0; index < lower.length; index += 1) {
    const ch = lower.charAt(index)
    const code = lower.charCodeAt(index)
    const isAsciiLetter = ch >= 'a' && ch <= 'z'
    const isDigit = ch >= '0' && ch <= '9'
    const isNonAsciiText = code > 127
    if (isAsciiLetter || isDigit || isNonAsciiText) {
      normalized += ch
      previousWasSpace = false
    } else if (!previousWasSpace) {
      normalized += ' '
      previousWasSpace = true
    }
  }
  return previousWasSpace && normalized.length > 0 ? normalized.substring(0, normalized.length - 1) : normalized
}

export function isCrossSearchQueryMeaningful(value: string): boolean {
  return normalizeCrossSearchText(value).length > 0
}

export class CrossSearchService {
  private context: common.UIAbilityContext
  private remoteStore: RemoteServerStore
  private sourceViewModel: BrowseViewModel
  private libraryStore: LibraryStore
  private pagedSearchRuns: PagedSearchRun[] = []
  private webDavSearchRun?: WebDavSearchRun = undefined

  constructor(context: common.UIAbilityContext, libraryStore: LibraryStore) {
    this.context = context
    this.libraryStore = libraryStore
    this.remoteStore = new RemoteServerStore(context)
    this.sourceViewModel = new BrowseViewModel(appSourceRuntimeRegistry)
  }

  async search(
    query: string,
    sourceFilter: CrossSearchSourceFilter = 'all',
    onSectionResolved: ((section: CrossSearchSection) => void) | undefined = undefined,
  ): Promise<CrossSearchSection[]> {
    this.cancelPendingSearch()
    const normalizedQuery = query.trim()
    if (normalizedQuery.length === 0) {
      return []
    }
    if (!isCrossSearchQueryMeaningful(normalizedQuery)) {
      return []
    }
    console.info(`[Search] step=query_start length=${normalizedQuery.length}`)
    const tasks: Promise<SourceSearchOutcome>[] = []
    if (this.sourceMatchesFilter('local', sourceFilter)) {
      tasks.push(this.withTimeout(this.searchLocal(normalizedQuery), this.emptySection('local', AppStrings.get('tab_library'), 'local')))
    }
    if (this.sourceMatchesFilter('komga', sourceFilter)) {
      const run: PagedSearchRun = { cancelled: false }
      this.pagedSearchRuns.push(run)
      tasks.push(this.withTimeout(this.searchKomga(normalizedQuery, run), this.emptySection('komga', AppStrings.get('route_komga_title'), 'komga'), () => {
        run.cancelled = true
        return this.timeoutSection('komga', AppStrings.get('route_komga_title'), 'komga')
      }))
    }
    if (this.sourceMatchesFilter('kavita', sourceFilter)) {
      tasks.push(this.withTimeout(this.searchKavita(normalizedQuery), this.emptySection('kavita', AppStrings.get('route_kavita_title'), 'kavita')))
    }
    if (this.sourceMatchesFilter('opds', sourceFilter)) {
      const run: PagedSearchRun = { cancelled: false }
      this.pagedSearchRuns.push(run)
      tasks.push(this.withTimeout(this.searchOpds(normalizedQuery, run), this.emptySection('opds', AppStrings.get('route_opds_title'), 'opds'), () => {
        run.cancelled = true
        return this.timeoutSection('opds', AppStrings.get('route_opds_title'), 'opds')
      }))
    }
    if (this.sourceMatchesFilter('webdav', sourceFilter)) {
      const run: WebDavSearchRun = { cancelled: false, resources: [] }
      this.webDavSearchRun = run
      const search = this.searchWebDav(normalizedQuery, run).finally(() => {
        if (this.webDavSearchRun === run) this.webDavSearchRun = undefined
      })
      tasks.push(this.withTimeout(search, this.emptySection('webdav', AppStrings.get('route_webdav_title'), 'webdav'), () => {
        run.cancelled = true
        return this.webDavSearchSection(normalizedQuery, run, true)
      }))
    }

    const sourceTasks: Promise<SourceSearchOutcome>[] = this.sourceMatchesFilter('wasm', sourceFilter) ?
      appSourceRuntimeRegistry.listInstalledSourceSummaries().map((source: SourceRuntimeRegistryInstalledSourceSummary) => {
        return this.withTimeout(this.searchWasmSource(source, normalizedQuery), this.emptySection(`wasm:${source.sourceId}`, source.displayName, 'wasm'))
      }) :
      []
    const reportedTasks = tasks.concat(sourceTasks).map((task: Promise<SourceSearchOutcome>) => {
      return task.then((outcome: SourceSearchOutcome): SourceSearchOutcome => {
        if (onSectionResolved !== undefined) {
          onSectionResolved(outcome.section)
        }
        return outcome
      })
    })
    const outcomes = await Promise.all(reportedTasks)
    const sections = outcomes.map((outcome: SourceSearchOutcome): CrossSearchSection => outcome.section)
    console.info(`[Search] step=query_done sections=${sections.length}`)
    return sections
  }

  cancelPendingSearch(): void {
    this.pagedSearchRuns.forEach((run: PagedSearchRun) => { run.cancelled = true })
    this.pagedSearchRuns = []
    // One-shot provider calls retain their existing UI ownership guards. Stop
    // the directory traversal before it can issue any further PROPFIND calls.
    if (this.webDavSearchRun !== undefined) this.webDavSearchRun.cancelled = true
    this.webDavSearchRun = undefined
  }

  private ensureWebDavSearchActive(run: WebDavSearchRun): void {
    if (run.cancelled) throw new Error('search_cancelled')
  }

  pendingSections(sourceFilter: CrossSearchSourceFilter = 'all'): CrossSearchSection[] {
    const sections: CrossSearchSection[] = []
    if (this.sourceMatchesFilter('local', sourceFilter)) {
      sections.push(this.stateSection('local', AppStrings.get('tab_library'), 'local', 'running'))
    }
    if (this.sourceMatchesFilter('komga', sourceFilter)) {
      sections.push(this.stateSection('komga', AppStrings.get('route_komga_title'), 'komga', 'running'))
    }
    if (this.sourceMatchesFilter('kavita', sourceFilter)) {
      sections.push(this.stateSection('kavita', AppStrings.get('route_kavita_title'), 'kavita', 'running'))
    }
    if (this.sourceMatchesFilter('opds', sourceFilter)) {
      sections.push(this.stateSection('opds', AppStrings.get('route_opds_title'), 'opds', 'running'))
    }
    if (this.sourceMatchesFilter('webdav', sourceFilter)) {
      sections.push(this.stateSection('webdav', AppStrings.get('route_webdav_title'), 'webdav', 'running'))
    }
    if (this.sourceMatchesFilter('wasm', sourceFilter)) {
      appSourceRuntimeRegistry.listInstalledSourceSummaries().forEach((source: SourceRuntimeRegistryInstalledSourceSummary) => {
        sections.push(this.sourceSupportsSearch(source) ?
          this.stateSection(`wasm:${source.sourceId}`, source.displayName, 'wasm', 'running') :
          this.stateSection(`wasm:${source.sourceId}`, source.displayName, 'wasm', 'unsupported', 'search_not_supported'))
      })
    }
    return sections
  }

  private sourceMatchesFilter(sourceKind: CrossSearchSourceKind, sourceFilter: CrossSearchSourceFilter): boolean {
    if (sourceFilter === 'all') {
      return true
    }
    if (sourceFilter === 'local') {
      return sourceKind === 'local'
    }
    if (sourceFilter === 'source') {
      return sourceKind === 'wasm'
    }
    return sourceKind === 'komga' || sourceKind === 'kavita' || sourceKind === 'opds' || sourceKind === 'webdav'
  }

  async openWebDavReader(item: CrossSearchResultItem): Promise<boolean> {
    if (item.sourceKind !== 'webdav') {
      return false
    }
    const record = await this.remoteStore.loadWebDav()
    if (record === undefined) {
      throw new Error(AppStrings.get('search_webdav_config_required'))
    }
    const client = this.remoteStore.createWebDavClient(record)
    const pathSegments = item.webDavPathSegments ?? []
    const resources = await client.propfind(pathSegments, 1)
    const images = this.sortDavResources(resources.filter((resource: DavResource): boolean => {
      if (item.webDavIsCollection === true) {
        return !resource.isCollection && resource.candidateKind === DavComicCandidateKind.IMAGE_FILE
      }
      return resource.href === item.webDavHref && resource.candidateKind === DavComicCandidateKind.IMAGE_FILE
    }))
    if (images.length === 0) {
      throw new Error(AppStrings.get('search_webdav_no_images'))
    }
    this.installWebDavReaderSession(record, client, pathSegments, item.title, images)
    console.info(`[Search] step=open_webdav_reader pages=${images.length}`)
    return true
  }

  private async searchLocal(query: string): Promise<SourceSearchOutcome> {
    const libraryStore = this.libraryStore
    const normalizedQuery = this.normalizeSearchText(query)
    const compactQuery = this.compactSearchText(query)
    const items = this.sortSearchResultItems(query, libraryStore.listComics()
      .filter((comic: Comic): boolean => this.localComicMatches(comic, normalizedQuery, compactQuery))
      .map((comic: Comic): CrossSearchResultItem => {
        return {
          id: `local:${comic.id}`,
          title: comic.title,
          subtitle: this.localSearchSubtitle(comic, normalizedQuery, compactQuery),
          sourceKind: 'local',
          sourceLabel: AppStrings.get('tab_library'),
          coverUri: comic.coverUri,
          localComicId: comic.id,
        }
      }))
    console.info(`[Search] step=local_done count=${items.length}`)
    return { section: this.section('local', AppStrings.get('tab_library'), 'local', items) }
  }

  private async searchKomga(query: string, run: PagedSearchRun): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadKomga()
      if (record === undefined) {
        return { section: this.stateSection('komga', AppStrings.get('route_komga_title'), 'komga', 'unsupported', 'not_configured') }
      }
      const client = this.remoteStore.createKomgaClient(record)
      const seriesRows: KomgaSeriesDto[] = []
      const seen = new Set<string>()
      let page = 0
      while (true) {
        if (run.cancelled) throw new Error('search_cancelled')
        const response = await client.listSeries({ page, size: KOMGA_PAGE_SIZE, search: query, sort: ['metadata.titleSort,asc'] })
        if (run.cancelled) throw new Error('search_cancelled')
        let added = 0
        response.content.forEach((series: KomgaSeriesDto) => {
          if (!seen.has(series.id)) {
            seen.add(series.id)
            seriesRows.push(series)
            added += 1
          }
        })
        const more = response.last === false || (response.totalPages !== undefined && page + 1 < response.totalPages)
        const last = response.last === true || (response.totalPages !== undefined && page + 1 >= response.totalPages)
        if (added === 0 && (response.content.length > 0 || more)) throw new Error('Komga search pagination made no progress')
        if (last || (!more && response.content.length < KOMGA_PAGE_SIZE)) break
        page += 1
      }
      const items = this.sortSearchResultItems(query, seriesRows.map((series: KomgaSeriesDto): CrossSearchResultItem => {
        const title = this.komgaSeriesTitle(series)
        return {
          id: `komga:${record.server.id}:${series.id}`,
          title,
          subtitle: `${series.booksCount === undefined ? 0 : series.booksCount} books`,
          remoteServerId: record.server.id,
          sourceKind: 'komga',
          sourceLabel: AppStrings.get('route_komga_title'),
          komgaSeriesId: series.id,
        }
      }))
      console.info(`[Search] step=komga_done count=${items.length}`)
      return { section: this.section('komga', AppStrings.get('route_komga_title'), 'komga', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error('[Search] step=komga_failed code=' + diagnostic.code)
      return { section: this.errorSection('komga', AppStrings.get('route_komga_title'), 'komga', diagnostic) }
    }
  }

  private async searchKavita(query: string): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadKavita()
      if (record === undefined) {
        return { section: this.stateSection('kavita', AppStrings.get('route_kavita_title'), 'kavita', 'unsupported', 'not_configured') }
      }
      const client = this.remoteStore.createKavitaClient(record)
      const matches = await client.searchSeries(query)
      const rows = await client.getSeriesByIds(matches.map((match: KavitaSearchResultDto): number => match.seriesId))
      const matchedItems: CrossSearchResultItem[] = []
      matches.forEach((match: KavitaSearchResultDto) => {
        const series = rows.find((row: KavitaSeriesDto): boolean => row.id === match.seriesId)
        // Hydration rechecks access; a removed series must not become a fabricated result.
        if (series === undefined) {
          return
        }
        matchedItems.push({
          id: `kavita:${record.server.id}:${match.libraryId}:${series.id}`,
          title: this.kavitaSeriesTitle(series),
          subtitle: this.kavitaSeriesSubtitle(series, match.libraryName),
          sourceKind: 'kavita',
          sourceLabel: AppStrings.get('route_kavita_title'),
          remoteServerId: record.server.id,
          coverUri: series.coverImage,
          kavitaLibraryId: match.libraryId,
          kavitaSeriesId: `${series.id}`,
        })
      })
      const items = this.sortSearchResultItems(query, matchedItems)
      console.info(`[Search] step=kavita_done candidates=${matches.length} count=${items.length}`)
      return { section: this.section('kavita', AppStrings.get('route_kavita_title'), 'kavita', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error('[Search] step=kavita_failed code=' + diagnostic.code)
      return { section: this.errorSection('kavita', AppStrings.get('route_kavita_title'), 'kavita', diagnostic) }
    }
  }

  private async searchOpds(query: string, run: PagedSearchRun): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadOpds()
      if (record === undefined) {
        return { section: this.stateSection('opds', AppStrings.get('route_opds_title'), 'opds', 'unsupported', 'not_configured') }
      }
      const client = this.remoteStore.createOpdsClient(record)
      if (run.cancelled) throw new Error('search_cancelled')
      const root = await client.fetchCatalog()
      if (run.cancelled) throw new Error('search_cancelled')
      const searchUrl = this.findOpdsSearchUrl(root, query)
      let catalog = searchUrl.length === 0 ? root : await client.fetchCatalog(searchUrl)
      const items: CrossSearchResultItem[] = []
      const visited = new Set<string>()
      while (true) {
        if (run.cancelled) throw new Error('search_cancelled')
        visited.add(catalog.feedUrl)
        this.filterOpdsPublications(client, catalog, query).forEach((item: CrossSearchResultItem) => {
          item.remoteServerId = record.server.id
          items.push(item)
        })
        const next = catalog.links.find((link: OpdsLink): boolean => link.rel?.toLocaleLowerCase() === 'next')
        if (next === undefined) break
        const url = resolveOpdsHref(catalog.feedUrl, next.href)
        if (visited.has(url)) throw new Error('OPDS search pagination cycle')
        if (run.cancelled) throw new Error('search_cancelled')
        catalog = await client.fetchCatalog(url)
      }
      console.info(`[Search] step=opds_done count=${items.length}`)
      return { section: this.section('opds', AppStrings.get('route_opds_title'), 'opds', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error('[Search] step=opds_failed code=' + diagnostic.code)
      return { section: this.errorSection('opds', AppStrings.get('route_opds_title'), 'opds', diagnostic) }
    }
  }

  private async searchWebDav(query: string, run: WebDavSearchRun): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadWebDav()
      this.ensureWebDavSearchActive(run)
      if (record === undefined) {
        return { section: this.stateSection('webdav', AppStrings.get('route_webdav_title'), 'webdav', 'unsupported', 'not_configured') }
      }
      const client = this.remoteStore.createWebDavClient(record)
      run.client = client
      run.serverId = record.server.id
      const rootResources = await client.propfind([], 1)
      this.ensureWebDavSearchActive(run)
      const uniqueRoot: Map<string, DavResource> = new Map()
      rootResources.forEach((resource: DavResource) => {
        const key = this.normalizeUrl(resource.href)
        if (!uniqueRoot.has(key)) uniqueRoot.set(key, resource)
      })
      run.resources = Array.from(uniqueRoot.values())
      await this.collectWebDavSearchResources(client, rootResources, run)
      this.ensureWebDavSearchActive(run)
      return { section: this.webDavSearchSection(query, run) }
    } catch (error) {
      run.diagnostic = safeSearchDiagnostic(error as Error)
      console.error('[Search] step=webdav_failed code=' + run.diagnostic.code)
      return { section: this.webDavSearchSection(query, run) }
    }
  }

  private webDavSearchSection(query: string, run: WebDavSearchRun, timedOut: boolean = false): CrossSearchSection {
    const client = run.client
    const normalizedQuery = this.normalizeSearchText(query)
    const compactQuery = this.compactSearchText(query)
    const matchedItems: CrossSearchResultItem[] = client === undefined ? [] : run.resources.filter((resource: DavResource): boolean => {
      if (this.isCurrentWebDavResource(client, [], resource)) return false
      const supported = resource.isCollection || resource.candidateKind === DavComicCandidateKind.IMAGE_FILE
      return supported && this.textMatchesQuery(this.davResourceName(resource), normalizedQuery, compactQuery)
    }).map((resource: DavResource): CrossSearchResultItem => {
      return {
        id: `webdav:${resource.href}`,
        title: this.davResourceName(resource),
        subtitle: AppStrings.get(resource.isCollection ? 'search_webdav_folder' : 'search_webdav_image'),
        sourceKind: 'webdav',
        sourceLabel: AppStrings.get('route_webdav_title'),
        remoteServerId: run.serverId,
        webDavRootUrl: client.buildUrl([]),
        webDavHref: resource.href,
        webDavPathSegments: resource.isCollection ?
          this.webDavRelativeSegments(client, resource.href) :
          this.webDavParentSegments(client, resource.href),
        webDavIsCollection: resource.isCollection,
      }
    })
    const items = this.sortSearchResultItems(query, matchedItems)
    const section = timedOut ? this.timeoutSection('webdav', AppStrings.get('route_webdav_title'), 'webdav') :
      run.diagnostic !== undefined ? this.errorSection('webdav', AppStrings.get('route_webdav_title'), 'webdav', run.diagnostic) :
        this.section('webdav', AppStrings.get('route_webdav_title'), 'webdav', items)
    section.items = items
    section.resultCount = items.length
    console.info(`[Search] step=webdav_done count=${items.length} state=${section.state}`)
    return section
  }

  private async searchWasmSource(source: SourceRuntimeRegistryInstalledSourceSummary, query: string): Promise<SourceSearchOutcome> {
    try {
      if (!this.sourceSupportsSearch(source)) {
        return { section: this.stateSection(`wasm:${source.sourceId}`, source.displayName, 'wasm', 'unsupported', 'search_not_supported') }
      }
      const result = await this.sourceViewModel.searchSource(source, query, 1)
      const items = this.sortSearchResultItems(query, result.manga.map((manga: SourceManga): CrossSearchResultItem => {
        return {
          id: `wasm:${manga.sourceId}:${manga.id}`,
          title: manga.title,
          subtitle: manga.author ?? source.displayName,
          sourceKind: 'wasm',
          sourceLabel: source.displayName,
          coverUri: manga.coverUrl,
          sourceId: manga.sourceId,
          sourceMangaId: manga.id,
          sourceMangaUrl: manga.url,
        }
      })).slice(0, SOURCE_PAGE_SIZE)
      console.info(`[Search] step=wasm_done source=${source.sourceId} count=${items.length}`)
      return { section: this.section(`wasm:${source.sourceId}`, source.displayName, 'wasm', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error(`[Search] step=wasm_failed source=${source.sourceId} code=${diagnostic.code}`)
      return { section: this.errorSection(`wasm:${source.sourceId}`, source.displayName, 'wasm', diagnostic) }
    }
  }

  private async collectWebDavSearchResources(client: WebDavClient, rootResources: DavResource[], run: WebDavSearchRun): Promise<void> {
    const folders: string[][] = []
    const queued: Set<string> = new Set([this.normalizeUrl(client.buildUrl([]))])
    const known: Set<string> = new Set(rootResources.map((resource: DavResource): string => this.normalizeUrl(resource.href)))
    const enqueue = (resource: DavResource): void => {
      if (!resource.isCollection) return
      const pathSegments = this.webDavRelativeSegments(client, resource.href)
      // A self/outside-root/unparseable href must not turn into a new root scan.
      if (pathSegments.length === 0) return
      const key = this.normalizeUrl(client.buildUrl(pathSegments))
      if (queued.has(key)) return
      queued.add(key)
      folders.push(pathSegments)
    }
    rootResources.forEach(enqueue)
    for (let index = 0; index < folders.length; index += 1) {
      this.ensureWebDavSearchActive(run)
      const pathSegments = folders[index]
      try {
        const children = await client.propfind(pathSegments, 1)
        this.ensureWebDavSearchActive(run)
        children.forEach((child: DavResource) => {
          if (this.isCurrentWebDavResource(client, pathSegments, child)) return
          const key = this.normalizeUrl(child.href)
          if (!known.has(key)) {
            known.add(key)
            run.resources.push(child)
          }
          enqueue(child)
        })
      } catch (error) {
        this.ensureWebDavSearchActive(run)
        const diagnostic = safeSearchDiagnostic(error as Error)
        if (run.diagnostic === undefined) run.diagnostic = diagnostic
        console.error('[Search] step=webdav_child_scan_failed code=' + diagnostic.code)
      }
    }
  }

  private async withTimeout(task: Promise<SourceSearchOutcome>, fallback: CrossSearchSection, onTimeout: (() => CrossSearchSection) | undefined = undefined): Promise<SourceSearchOutcome> {
    return new Promise<SourceSearchOutcome>((resolve) => {
      let done = false
      const timer = setTimeout(() => {
        if (done) {
          return
        }
        done = true
        console.error(`[Search] step=source_timeout source=${fallback.id}`)
        resolve({
          section: onTimeout === undefined ? this.timeoutSection(fallback.id, fallback.title, fallback.sourceKind) : onTimeout(),
        })
      }, SEARCH_TIMEOUT_MS)
      task.then((value: SourceSearchOutcome) => {
        if (done) {
          return
        }
        done = true
        clearTimeout(timer)
        resolve(value)
      }).catch((error: Error) => {
        if (done) {
          return
        }
        done = true
        clearTimeout(timer)
        resolve({
          section: this.errorSection(fallback.id, fallback.title, fallback.sourceKind, safeSearchDiagnostic(error)),
        })
      })
    })
  }

  private localComicMatches(comic: Comic, normalizedQuery: string, compactQuery: string): boolean {
    if (this.textMatchesQuery(comic.title, normalizedQuery, compactQuery)) {
      return true
    }
    if (comic.subtitle !== undefined && this.textMatchesQuery(comic.subtitle, normalizedQuery, compactQuery)) {
      return true
    }
    if (comic.author !== undefined && this.textMatchesQuery(comic.author, normalizedQuery, compactQuery)) {
      return true
    }
    return this.localMatchedChapterTitle(comic, normalizedQuery, compactQuery) !== undefined
  }

  private localSearchSubtitle(comic: Comic, normalizedQuery: string, compactQuery: string): string {
    const titleMatches = this.textMatchesQuery(comic.title, normalizedQuery, compactQuery)
    const subtitleMatches = comic.subtitle !== undefined && this.textMatchesQuery(comic.subtitle, normalizedQuery, compactQuery)
    const authorMatches = comic.author !== undefined && this.textMatchesQuery(comic.author, normalizedQuery, compactQuery)
    const matchedChapterTitle = this.localMatchedChapterTitle(comic, normalizedQuery, compactQuery)
    if (!titleMatches && subtitleMatches && comic.subtitle !== undefined) {
      return comic.subtitle
    }
    if (!titleMatches && authorMatches && comic.author !== undefined) {
      return comic.author
    }
    if (!titleMatches && !subtitleMatches && !authorMatches && matchedChapterTitle !== undefined) {
      return matchedChapterTitle
    }
    return comic.author ?? AppStrings.get('search_local_subtitle')
      .replace('%s', `${comic.chapterCount}`)
      .replace('%s', `${comic.pageCount}`)
  }

  private localMatchedChapterTitle(comic: Comic, normalizedQuery: string, compactQuery: string): string | undefined {
    const chapter = comic.chapters.find((item: Chapter): boolean => {
      return this.textMatchesQuery(item.title, normalizedQuery, compactQuery)
    })
    return chapter?.title
  }

  private findOpdsSearchUrl(catalog: OpdsParseResult, query: string): string {
    return resolveOpdsSearchUrl(catalog, query)
  }

  private filterOpdsPublications(client: OpdsClient, catalog: OpdsParseResult, query: string): CrossSearchResultItem[] {
    const normalizedQuery = this.normalizeSearchText(query)
    const compactQuery = this.compactSearchText(query)
    const items = catalog.publications.filter((publication: OpdsBookDto): boolean => {
      return this.textMatchesQuery(publication.title, normalizedQuery, compactQuery) ||
        (publication.author !== undefined && this.textMatchesQuery(publication.author, normalizedQuery, compactQuery)) ||
        (publication.summary !== undefined && this.textMatchesQuery(publication.summary, normalizedQuery, compactQuery))
    }).map((publication: OpdsBookDto): CrossSearchResultItem => {
      const images = mapOpdsPublicationToImages(publication)
      return {
        id: `opds:${this.shortHash(catalog.feedUrl)}:${publication.id}`,
        title: publication.title,
        subtitle: publication.author ?? (publication.pageCount === undefined
          ? AppStrings.get('route_opds_title')
          : AppStrings.get('search_opds_image_count').replace('%s', `${publication.pageCount}`)),
        sourceKind: 'opds',
        sourceLabel: AppStrings.get('route_opds_title'),
        coverUri: images.length === 0 ? undefined : images[0].href,
        opdsFeedUrl: catalog.feedUrl,
        opdsSearchQuery: query,
        opdsPublicationId: publication.id,
      }
    })
    return this.sortSearchResultItems(query, items)
  }

  private installWebDavReaderSession(
    record: WebDavServerRecord,
    client: WebDavClient,
    pathSegments: string[],
    title: string,
    images: DavResource[],
  ): void {
    const now = Date.now()
    const sourcePath = client.buildUrl(pathSegments)
    const comicId = `webdav:${record.server.id}:comic:${this.shortHash(sourcePath)}`
    const chapterId = `webdav:${record.server.id}:chapter:${this.shortHash(sourcePath)}`
    const pages = images.map((resource: DavResource, index: number): Page => {
      const name = this.davResourceName(resource)
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: client.getResourceUrl(resource),
        sortKey: normalizeSortKey(name),
        byteSize: resource.contentLength,
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title,
      index: 0,
      sourcePath,
      sortKey: normalizeSortKey(title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    const comic: Comic = {
      id: comicId,
      title,
      sourceKind: ComicSourceKind.WEBDAV_REMOTE,
      sourcePath,
      remoteServerId: record.server.id,
      remoteResourceId: sourcePath,
      coverUri: pages[0].uri,
      sortTitle: normalizeSortKey(title),
      preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    MOCK_LIBRARY_READER_SESSION.comicId = config.comicId
    MOCK_LIBRARY_READER_SESSION.chapterId = config.chapterId
    MOCK_LIBRARY_READER_SESSION.chapterIds = config.chapterIds
    MOCK_LIBRARY_READER_SESSION.chapterTitles = config.chapterTitles
    MOCK_LIBRARY_READER_SESSION.title = config.title
    MOCK_LIBRARY_READER_SESSION.chapterTitle = config.chapterTitle
    MOCK_LIBRARY_READER_SESSION.totalPages = config.totalPages
    MOCK_LIBRARY_READER_SESSION.pageUris = config.pageUris
    MOCK_LIBRARY_READER_SESSION.pageIds = config.pageIds
    MOCK_LIBRARY_READER_SESSION.pageWidths = config.pageWidths
    MOCK_LIBRARY_READER_SESSION.pageHeights = config.pageHeights
    MOCK_LIBRARY_READER_SESSION.sourceRuntimeId = config.sourceRuntimeId
    MOCK_LIBRARY_READER_SESSION.sourceMangaUrl = config.sourceMangaUrl
    MOCK_LIBRARY_READER_SESSION.sourceKind = config.sourceKind
    MOCK_LIBRARY_READER_SESSION.remoteServerId = config.remoteServerId
  }

  private isCurrentWebDavResource(client: WebDavClient, pathSegments: string[], resource: DavResource): boolean {
    return this.normalizeUrl(client.buildUrl(pathSegments)) === this.normalizeUrl(resource.href)
  }

  private normalizeUrl(value: string): string {
    let normalized = value
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1)
    }
    return normalized
  }

  private webDavRelativeSegments(client: WebDavClient, href: string): string[] {
    try {
      const rawRootPath = readWebDavUrlPath(client.buildUrl([]))
      const rootPath = rawRootPath.endsWith('/') ? rawRootPath : rawRootPath + '/'
      let childPath = readWebDavUrlPath(href)
      if (childPath.endsWith('/')) {
        childPath = childPath.substring(0, childPath.length - 1)
      }
      if (!childPath.startsWith(rootPath)) {
        return []
      }
      return childPath.substring(rootPath.length).split('/').filter((segment: string): boolean => {
        return segment.length > 0
      }).map((segment: string): string => decodeURIComponent(segment))
    } catch (_err) {
      return []
    }
  }

  private webDavParentSegments(client: WebDavClient, href: string): string[] {
    const segments = this.webDavRelativeSegments(client, href)
    if (segments.length === 0) {
      return []
    }
    return segments.slice(0, segments.length - 1)
  }

  private sortDavResources(resources: DavResource[]): DavResource[] {
    return resources.slice().sort((left: DavResource, right: DavResource): number => {
      return compareNaturalPath(this.davResourceName(left), this.davResourceName(right))
    })
  }

  private davResourceName(resource: DavResource): string {
    if (resource.displayname !== undefined && resource.displayname.length > 0) {
      return resource.displayname
    }
    try {
      const pathname = readWebDavUrlPath(resource.href)
      const trimmed = pathname.endsWith('/') ? pathname.substring(0, pathname.length - 1) : pathname
      const name = trimmed.split('/').pop()
      return name === undefined || name.length === 0 ? resource.href : decodeURIComponent(name)
    } catch (_err) {
      return resource.href
    }
  }

  private sortSearchResultItems(query: string, items: CrossSearchResultItem[]): CrossSearchResultItem[] {
    const normalizedQuery = this.normalizeSearchText(query)
    const compactQuery = this.compactSearchText(query)
    return items.map((item: CrossSearchResultItem): CrossSearchResultItem => {
      return this.searchResultWithMatchQuality(item, normalizedQuery, compactQuery)
    }).sort((left: CrossSearchResultItem, right: CrossSearchResultItem): number => {
      const scoreDiff = (left.matchScore ?? 9) - (right.matchScore ?? 9)
      return scoreDiff !== 0 ? scoreDiff : left.title.localeCompare(right.title)
    })
  }

  private searchResultWithMatchQuality(
    item: CrossSearchResultItem,
    normalizedQuery: string,
    compactQuery: string,
  ): CrossSearchResultItem {
    const matchQuality = this.searchResultMatchQuality(item, normalizedQuery, compactQuery)
    return {
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      sourceKind: item.sourceKind,
      sourceLabel: item.sourceLabel,
      remoteServerId: item.remoteServerId,
      coverUri: item.coverUri,
      localComicId: item.localComicId,
      sourceId: item.sourceId,
      sourceMangaId: item.sourceMangaId,
      sourceMangaUrl: item.sourceMangaUrl,
      komgaSeriesId: item.komgaSeriesId,
      kavitaLibraryId: item.kavitaLibraryId,
      kavitaSeriesId: item.kavitaSeriesId,
      opdsFeedUrl: item.opdsFeedUrl,
      opdsSearchQuery: item.opdsSearchQuery,
      opdsPublicationId: item.opdsPublicationId,
      webDavRootUrl: item.webDavRootUrl,
      webDavHref: item.webDavHref,
      webDavPathSegments: item.webDavPathSegments,
      webDavIsCollection: item.webDavIsCollection,
      matchQuality,
      matchScore: this.searchResultScoreForQuality(matchQuality),
    }
  }

  private searchResultMatchQuality(item: CrossSearchResultItem, normalizedQuery: string, compactQuery: string): CrossSearchMatchQuality {
    const title = this.normalizeSearchText(item.title)
    const titleCompact = this.compactSearchText(item.title)
    const subtitle = this.normalizeSearchText(item.subtitle)
    const subtitleCompact = this.compactSearchText(item.subtitle)
    if (title === normalizedQuery || titleCompact === compactQuery) {
      return 'title_exact'
    }
    if (title.startsWith(normalizedQuery) || titleCompact.startsWith(compactQuery)) {
      return 'title_prefix'
    }
    if (title.indexOf(normalizedQuery) >= 0 || titleCompact.indexOf(compactQuery) >= 0) {
      return 'title_contains'
    }
    if (subtitle.startsWith(normalizedQuery) || subtitleCompact.startsWith(compactQuery)) {
      return 'metadata_prefix'
    }
    if (subtitle.indexOf(normalizedQuery) >= 0 || subtitleCompact.indexOf(compactQuery) >= 0) {
      return 'metadata_contains'
    }
    return 'weak'
  }

  private searchResultScoreForQuality(matchQuality: CrossSearchMatchQuality): number {
    if (matchQuality === 'title_exact') {
      return 0
    }
    if (matchQuality === 'title_prefix') {
      return 1
    }
    if (matchQuality === 'title_contains') {
      return 2
    }
    if (matchQuality === 'metadata_prefix') {
      return 3
    }
    if (matchQuality === 'metadata_contains') {
      return 4
    }
    return 9
  }

  private textMatchesQuery(value: string, normalizedQuery: string, compactQuery: string): boolean {
    const normalized = this.normalizeSearchText(value)
    if (normalized.indexOf(normalizedQuery) >= 0) {
      return true
    }
    return normalized.replace(/ /g, '').indexOf(compactQuery) >= 0
  }

  private compactSearchText(value: string): string {
    return this.normalizeSearchText(value).replace(/ /g, '')
  }

  private normalizeSearchText(value: string): string {
    return normalizeCrossSearchText(value)
  }

  private komgaSeriesTitle(item: KomgaSeriesDto): string {
    if (item.metadata?.title !== undefined && item.metadata.title.length > 0) {
      return item.metadata.title
    }
    return item.name
  }

  private kavitaSeriesTitle(item: KavitaSeriesDto): string {
    if (item.localizedName !== undefined && item.localizedName.length > 0) {
      return item.localizedName
    }
    return item.name
  }

  private kavitaSeriesSubtitle(item: KavitaSeriesDto, libraryName: string): string {
    const pages = item.pages === undefined ? 0 : item.pages
    const read = item.pagesRead === undefined ? 0 : item.pagesRead
    return `${libraryName} · ${AppStrings.get('kavita_series_pages_progress').replace('%s', `${read}`).replace('%s', `${pages}`)}`
  }

  private section(id: string, title: string, kind: CrossSearchSourceKind, items: CrossSearchResultItem[]): CrossSearchSection {
    return {
      id,
      title,
      sourceKind: kind,
      loading: false,
      state: items.length === 0 ? 'empty' : 'ready',
      resultCount: items.length,
      diagnosticCode: '',
      errorText: '',
      items,
    }
  }

  private emptySection(id: string, title: string, kind: CrossSearchSourceKind): CrossSearchSection {
    return this.section(id, title, kind, [])
  }

  private stateSection(
    id: string,
    title: string,
    kind: CrossSearchSourceKind,
    state: CrossSearchSectionState,
    diagnosticCode: string = '',
  ): CrossSearchSection {
    return {
      id,
      title,
      sourceKind: kind,
      loading: state === 'pending' || state === 'running',
      state,
      resultCount: 0,
      diagnosticCode,
      errorText: searchStateUserText(state, diagnosticCode),
      items: [],
    }
  }

  private errorSection(id: string, title: string, kind: CrossSearchSourceKind, diagnostic: SearchDiagnostic): CrossSearchSection {
    return {
      id,
      title,
      sourceKind: kind,
      loading: false,
      state: 'failed',
      resultCount: 0,
      diagnosticCode: diagnostic.code,
      errorText: diagnostic.userText,
      items: [],
    }
  }

  private timeoutSection(id: string, title: string, kind: CrossSearchSourceKind): CrossSearchSection {
    return {
      id,
      title,
      sourceKind: kind,
      loading: false,
      state: 'timeout',
      resultCount: 0,
      diagnosticCode: 'timeout',
      errorText: searchStateUserText('timeout', 'timeout'),
      items: [],
    }
  }

  private shortHash(value: string): string {
    let hash = 2166136261
    for (let index = 0; index < value.length; index += 1) {
      hash = (hash ^ value.charCodeAt(index)) >>> 0
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return hash.toString(16).padStart(8, '0').slice(-8)
  }

  private sourceSupportsSearch(source: SourceRuntimeRegistryInstalledSourceSummary): boolean {
    return source.enabled && source.capabilities.indexOf('search') >= 0
  }
}
