import { common } from '@kit.AbilityKit'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from './ComicModels'
import { InMemoryLibraryStore, LibraryStore } from './LibraryStore'
import {
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
} from './LibraryPersistence'
import { createSeededLibraryStore } from './MockLibraryData'
import { MOCK_LIBRARY_READER_SESSION } from './MockLibraryData'
import { installReaderRemoteHeaders } from './ReaderPageSourceAdapter'
import { createReaderSessionConfigFromComic } from './ReaderSessionStore'
import { RemoteServerStore, WebDavServerRecord } from './RemoteServerStore'
import { SourceManga } from './SourceModels'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { KomgaSeriesDto } from '../remote/KomgaModels'
import {
  OpdsClient,
  mapOpdsPublicationToImages,
  resolveOpdsHref,
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

export type CrossSearchSourceKind = 'local' | 'komga' | 'opds' | 'webdav' | 'wasm'
export type CrossSearchSourceFilter = 'all' | 'local' | 'private' | 'source'
export type CrossSearchMatchQuality = 'title_exact' | 'title_prefix' | 'title_contains' | 'metadata_prefix' | 'metadata_contains' | 'weak'

export interface CrossSearchResultItem {
  id: string
  title: string
  subtitle: string
  sourceKind: CrossSearchSourceKind
  sourceLabel: string
  coverUri?: string
  localComicId?: string
  sourceId?: string
  sourceMangaId?: string
  komgaSeriesId?: string
  opdsFeedUrl?: string
  opdsPublicationId?: string
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

const SEARCH_TIMEOUT_MS: number = 5000
const KOMGA_PAGE_SIZE: number = 20
const SOURCE_PAGE_SIZE: number = 20

export function normalizeCrossSearchText(value: string): string {
  const lower = value.trim().toLocaleLowerCase()
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

  constructor(context: common.UIAbilityContext) {
    this.context = context
    this.remoteStore = new RemoteServerStore(context)
    this.sourceViewModel = new BrowseViewModel(appSourceRuntimeRegistry)
  }

  async search(query: string, sourceFilter: CrossSearchSourceFilter = 'all'): Promise<CrossSearchSection[]> {
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
      tasks.push(this.withTimeout(this.searchKomga(normalizedQuery), this.emptySection('komga', AppStrings.get('route_komga_title'), 'komga')))
    }
    if (this.sourceMatchesFilter('opds', sourceFilter)) {
      tasks.push(this.withTimeout(this.searchOpds(normalizedQuery), this.emptySection('opds', AppStrings.get('route_opds_title'), 'opds')))
    }
    if (this.sourceMatchesFilter('webdav', sourceFilter)) {
      tasks.push(this.withTimeout(this.searchWebDav(normalizedQuery), this.emptySection('webdav', AppStrings.get('route_webdav_title'), 'webdav')))
    }

    const sourceTasks: Promise<SourceSearchOutcome>[] = this.sourceMatchesFilter('wasm', sourceFilter) ?
      appSourceRuntimeRegistry.listInstalledSourceSummaries().map((source: SourceRuntimeRegistryInstalledSourceSummary) => {
        return this.withTimeout(this.searchWasmSource(source, normalizedQuery), this.emptySection(`wasm:${source.sourceId}`, source.displayName, 'wasm'))
      }) :
      []
    const outcomes = await Promise.all(tasks.concat(sourceTasks))
    const sections = outcomes.map((outcome: SourceSearchOutcome): CrossSearchSection => outcome.section)
    console.info(`[Search] step=query_done sections=${sections.length}`)
    return sections
  }

  pendingSections(sourceFilter: CrossSearchSourceFilter = 'all'): CrossSearchSection[] {
    const sections: CrossSearchSection[] = []
    if (this.sourceMatchesFilter('local', sourceFilter)) {
      sections.push(this.stateSection('local', AppStrings.get('tab_library'), 'local', 'running'))
    }
    if (this.sourceMatchesFilter('komga', sourceFilter)) {
      sections.push(this.stateSection('komga', AppStrings.get('route_komga_title'), 'komga', 'running'))
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
    return sourceKind === 'komga' || sourceKind === 'opds' || sourceKind === 'webdav'
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
    const libraryStore = this.loadLocalLibraryStore()
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
      })).slice(0, SOURCE_PAGE_SIZE)
    console.info(`[Search] step=local_done count=${items.length}`)
    return { section: this.section('local', AppStrings.get('tab_library'), 'local', items) }
  }

  private async searchKomga(query: string): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadKomga()
      if (record === undefined) {
        return { section: this.stateSection('komga', AppStrings.get('route_komga_title'), 'komga', 'unsupported', 'not_configured') }
      }
      const response = await this.remoteStore.createKomgaClient(record).listSeries({
        page: 0,
        size: KOMGA_PAGE_SIZE,
        search: query,
        sort: ['metadata.titleSort,asc'],
      })
      const items = this.sortSearchResultItems(query, response.content.map((series: KomgaSeriesDto): CrossSearchResultItem => {
        const title = this.komgaSeriesTitle(series)
        return {
          id: `komga:${record.server.id}:${series.id}`,
          title,
          subtitle: `${series.booksCount === undefined ? 0 : series.booksCount} books`,
          sourceKind: 'komga',
          sourceLabel: AppStrings.get('route_komga_title'),
          komgaSeriesId: series.id,
        }
      })).slice(0, SOURCE_PAGE_SIZE)
      console.info(`[Search] step=komga_done count=${items.length}`)
      return { section: this.section('komga', AppStrings.get('route_komga_title'), 'komga', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error('[Search] step=komga_failed code=' + diagnostic.code)
      return { section: this.errorSection('komga', AppStrings.get('route_komga_title'), 'komga', diagnostic) }
    }
  }

  private async searchOpds(query: string): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadOpds()
      if (record === undefined) {
        return { section: this.stateSection('opds', AppStrings.get('route_opds_title'), 'opds', 'unsupported', 'not_configured') }
      }
      const client = this.remoteStore.createOpdsClient(record)
      const root = await client.fetchCatalog()
      const searchUrl = this.findOpdsSearchUrl(root, query)
      const catalog = searchUrl.length === 0 ? root : await client.fetchCatalog(searchUrl)
      const items = this.filterOpdsPublications(client, catalog, query)
      console.info(`[Search] step=opds_done count=${items.length}`)
      return { section: this.section('opds', AppStrings.get('route_opds_title'), 'opds', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error('[Search] step=opds_failed code=' + diagnostic.code)
      return { section: this.errorSection('opds', AppStrings.get('route_opds_title'), 'opds', diagnostic) }
    }
  }

  private async searchWebDav(query: string): Promise<SourceSearchOutcome> {
    try {
      const record = await this.remoteStore.loadWebDav()
      if (record === undefined) {
        return { section: this.stateSection('webdav', AppStrings.get('route_webdav_title'), 'webdav', 'unsupported', 'not_configured') }
      }
      const client = this.remoteStore.createWebDavClient(record)
      const normalizedQuery = this.normalizeSearchText(query)
      const compactQuery = this.compactSearchText(query)
      const rootResources = await client.propfind([], 1)
      const resources = await this.collectWebDavSearchResources(client, rootResources)
      const matchedItems = resources.filter((resource: DavResource): boolean => {
        if (this.isCurrentWebDavResource(client, [], resource)) {
          return false
        }
        const supported = resource.isCollection || resource.candidateKind === DavComicCandidateKind.IMAGE_FILE
        return supported && this.textMatchesQuery(this.davResourceName(resource), normalizedQuery, compactQuery)
      }).map((resource: DavResource): CrossSearchResultItem => {
        return {
          id: `webdav:${resource.href}`,
          title: this.davResourceName(resource),
          subtitle: resource.isCollection
            ? AppStrings.get('search_webdav_folder')
            : AppStrings.get('search_webdav_image'),
          sourceKind: 'webdav',
          sourceLabel: AppStrings.get('route_webdav_title'),
          webDavHref: resource.href,
          webDavPathSegments: resource.isCollection ?
            this.webDavRelativeSegments(client, resource.href) :
            this.webDavParentSegments(client, resource.href),
          webDavIsCollection: resource.isCollection,
        }
      })
      const items = this.sortSearchResultItems(query, matchedItems).slice(0, SOURCE_PAGE_SIZE)
      console.info(`[Search] step=webdav_done count=${items.length}`)
      return { section: this.section('webdav', AppStrings.get('route_webdav_title'), 'webdav', items) }
    } catch (error) {
      const e = error as Error
      const diagnostic = safeSearchDiagnostic(e)
      console.error('[Search] step=webdav_failed code=' + diagnostic.code)
      return { section: this.errorSection('webdav', AppStrings.get('route_webdav_title'), 'webdav', diagnostic) }
    }
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

  private async collectWebDavSearchResources(client: WebDavClient, rootResources: DavResource[]): Promise<DavResource[]> {
    const collected: DavResource[] = rootResources.slice()
    const folders = rootResources.filter((resource: DavResource): boolean => {
      return resource.isCollection && !this.isCurrentWebDavResource(client, [], resource)
    }).slice(0, 20)
    for (let index = 0; index < folders.length; index += 1) {
      const folder = folders[index]
      try {
        const pathSegments = this.webDavRelativeSegments(client, folder.href)
        const children = await client.propfind(pathSegments, 1)
        children.forEach((child: DavResource) => {
          if (!this.isCurrentWebDavResource(client, pathSegments, child)) {
            collected.push(child)
          }
        })
      } catch (error) {
        const e = error as Error
        console.error('[Search] step=webdav_child_scan_failed code=' + safeSearchDiagnostic(e).code)
      }
    }
    return collected
  }

  private async withTimeout(task: Promise<SourceSearchOutcome>, fallback: CrossSearchSection): Promise<SourceSearchOutcome> {
    return new Promise<SourceSearchOutcome>((resolve) => {
      let done = false
      const timer = setTimeout(() => {
        if (done) {
          return
        }
        done = true
        console.error(`[Search] step=source_timeout source=${fallback.id}`)
        resolve({
          section: this.timeoutSection(fallback.id, fallback.title, fallback.sourceKind),
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

  private loadLocalLibraryStore(): LibraryStore {
    const store = createSeededLibraryStore()
    try {
      if (this.context.filesDir === undefined || this.context.filesDir.length === 0) {
        return store
      }
      const persistence = new LibraryStorePersistenceService(
        store,
        new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir)
      )
      persistence.restore()
      return store
    } catch (error) {
      const e = error as Error
      console.error('[Search] step=local_restore_failed code=' + safeSearchDiagnostic(e).code)
      return new InMemoryLibraryStore()
    }
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
    const searchLink = catalog.links.find((link: OpdsLink): boolean => {
      const rel = link.rel === undefined ? '' : link.rel.toLocaleLowerCase()
      const type = link.type === undefined ? '' : link.type.toLocaleLowerCase()
      return rel.indexOf('search') >= 0 || type.indexOf('opensearch') >= 0
    })
    if (searchLink === undefined) {
      return ''
    }
    const encoded = encodeURIComponent(query)
    let href = searchLink.href
    href = href.replace('{searchTerms}', encoded)
    href = href.replace('{query}', encoded)
    href = href.replace('{?q}', `?q=${encoded}`)
    href = href.replace('{?query}', `?query=${encoded}`)
    href = href.replace('{?searchTerms}', `?searchTerms=${encoded}`)
    href = href.replace('{?search}', `?search=${encoded}`)
    href = href.replace('{&q}', `&q=${encoded}`)
    href = href.replace('{&query}', `&query=${encoded}`)
    href = href.replace('{&searchTerms}', `&searchTerms=${encoded}`)
    return resolveOpdsHref(catalog.feedUrl, href)
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
        subtitle: publication.author ?? AppStrings.get('search_opds_image_count').replace('%s', `${images.length}`),
        sourceKind: 'opds',
        sourceLabel: AppStrings.get('route_opds_title'),
        coverUri: images.length === 0 ? undefined : images[0].href,
        opdsFeedUrl: catalog.feedUrl,
        opdsPublicationId: publication.id,
      }
    })
    return this.sortSearchResultItems(query, items).slice(0, SOURCE_PAGE_SIZE)
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
      sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
      sourcePath,
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
    MOCK_LIBRARY_READER_SESSION.title = config.title
    MOCK_LIBRARY_READER_SESSION.chapterTitle = config.chapterTitle
    MOCK_LIBRARY_READER_SESSION.totalPages = config.totalPages
    MOCK_LIBRARY_READER_SESSION.pageUris = config.pageUris
    MOCK_LIBRARY_READER_SESSION.pageIds = config.pageIds
    MOCK_LIBRARY_READER_SESSION.pageWidths = config.pageWidths
    MOCK_LIBRARY_READER_SESSION.pageHeights = config.pageHeights
    installReaderRemoteHeaders(client.getBaseUrl(), this.remoteStore.getWebDavImageHeaders(record))
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
      coverUri: item.coverUri,
      localComicId: item.localComicId,
      sourceId: item.sourceId,
      sourceMangaId: item.sourceMangaId,
      komgaSeriesId: item.komgaSeriesId,
      opdsFeedUrl: item.opdsFeedUrl,
      opdsPublicationId: item.opdsPublicationId,
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
    return this.compactSearchText(value).indexOf(compactQuery) >= 0
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
