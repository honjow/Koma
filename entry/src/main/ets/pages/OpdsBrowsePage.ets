import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { MOCK_LIBRARY_READER_SESSION } from '../model/MockLibraryData'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import { ReaderSessionConfig, appReaderSessionStore, createReaderSessionConfigFromComic } from '../model/ReaderSessionStore'
import { RemoteReadHistoryEntry, opdsHistoryLocator, opdsHistoryPublicationKey, resolveOpdsHistoryFeed, opdsSearchHistoryLocator, canRequestOpdsHistoryUrl, OpdsHistoryLocator } from '../model/RemoteReaderSession'
import { OpdsServerRecord, RemoteServerStore } from '../model/RemoteServerStore'
import {
  mapOpdsPublicationToAcquisitions,
  mapOpdsPublicationToImages,
  resolveOpdsSearchUrl,
  resolveOpdsHref,
  OpdsClient,
} from '../remote/OpdsParser'
import {
  OpdsAcquisitionDto,
  OpdsAcquisitionStatus,
  OpdsBookDto,
  OpdsCatalogDto,
  OpdsImageDto,
  OpdsLink,
  OpdsLinkKind,
  OpdsParseResult,
} from '../remote/OpdsModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

interface OpdsHistoryEntry {
  url: string
  title: string
}

export interface OpdsBrowseRouteParam {
  expectedServerId?: string
  feedUrl?: string
  searchQuery?: string
  publicationId?: string
  remoteHistory?: RemoteReadHistoryEntry
}

@ComponentV2
export struct OpdsBrowsePage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private title: string = ''
  @Local private currentUrl: string = ''
  @Local private history: OpdsHistoryEntry[] = []
  @Local private navigation: OpdsCatalogDto[] = []
  @Local private publications: OpdsBookDto[] = []
  @Local private selectedPublication: OpdsBookDto | undefined = undefined
  @Local private selectedImages: OpdsImageDto[] = []
  @Local private loading: boolean = true
  @Local private errorKey: string = ''
  @Local private errorRawText: string = ''
  @Local private favoriteRevision: number = 0
  private record?: OpdsServerRecord
  private initialPublicationOpened: boolean = false
  private pageEpoch: number = 0
  private catalogEpoch: number = 0
  private publicationEpoch: number = 0
  @Param params: OpdsBrowseRouteParam = {}
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  private currentTitle(): string {
    return this.title.length > 0 ? this.title : s('route_opds_title')
  }

  private clearError(): void {
    this.errorKey = ''
    this.errorRawText = ''
  }

  private setErrorKey(key: string): void {
    this.errorKey = key
    this.errorRawText = ''
  }

  private setErrorRaw(message: string): void {
    this.errorKey = ''
    this.errorRawText = message
  }

  private errorText(): string {
    if (this.errorRawText.length > 0) {
      return this.errorRawText
    }
    return this.errorKey.length > 0 ? s(this.errorKey) : ''
  }

  aboutToAppear(): void {
    this.loadInitial()
  }

  aboutToDisappear(): void {
    this.pageEpoch += 1
    this.catalogEpoch += 1
    this.publicationEpoch += 1
  }

  private async loadInitial(): Promise<void> {
    const pageEpoch = ++this.pageEpoch
    let catalogEpoch = ++this.catalogEpoch
    this.publicationEpoch += 1
    this.loading = true
    this.clearError()
    try {
      const saved = await this.store().loadOpds()
      if (pageEpoch !== this.pageEpoch) return
      if (saved === undefined) {
        this.setErrorKey('opds_config_required')
        return
      }
      const history = this.params?.remoteHistory
      if ((history !== undefined && history.serverId !== saved.server.id) ||
        (this.params?.expectedServerId !== undefined && this.params.expectedServerId !== saved.server.id)) {
        this.setErrorKey('remote_history_server_mismatch')
        return
      }
      this.record = saved
      const initialUrl = this.initialCatalogUrl(saved.server.rootUrl)
      this.currentUrl = initialUrl
      console.info('[OPDS] step=load_initial')
      catalogEpoch = this.catalogEpoch + 1
      await this.loadCatalog(initialUrl, false, undefined, history?.opdsSearchQuery === undefined ? undefined : history)
    } catch (error) {
      void error
      if (pageEpoch !== this.pageEpoch || catalogEpoch !== this.catalogEpoch) return
      this.setErrorKey('common_load_failed')
      console.error('[OPDS] step=load_initial_failed code=opds_initial_load_failed')
    } finally {
      if (pageEpoch === this.pageEpoch && catalogEpoch === this.catalogEpoch) this.loading = false
    }
  }

  private async loadCatalog(url: string, pushHistory: boolean, historyDepth?: number, searchHistory?: RemoteReadHistoryEntry): Promise<void> {
    const record = this.record
    if (record === undefined) {
      return
    }
    const pageEpoch = this.pageEpoch
    const catalogEpoch = ++this.catalogEpoch
    this.publicationEpoch += 1
    const previous: OpdsHistoryEntry = { url: this.currentUrl, title: this.title }
    const history = this.history.slice()
    this.loading = true
    this.clearError()
    try {
      console.info(`[OPDS] step=load_catalog_start urlHash=${this.shortHash(url)}`)
      const client = this.store().createOpdsClient(record)
      const ownsRequest = (): boolean => pageEpoch === this.pageEpoch && catalogEpoch === this.catalogEpoch
      const catalog = searchHistory === undefined ? await client.fetchCatalog(url) :
        await this.findSearchHistoryCatalog(client, record.server.rootUrl, searchHistory, ownsRequest)
      if (pageEpoch !== this.pageEpoch || catalogEpoch !== this.catalogEpoch) return
      if (pushHistory) {
        this.history = history.concat([previous])
      } else if (historyDepth !== undefined) {
        this.history = history.slice(0, historyDepth)
      }
      this.applyCatalog(catalog)
      await this.openInitialPublicationIfNeeded()
      console.info(`[OPDS] step=load_catalog_ok version=${catalog.version} navigation=${catalog.navigation.length} publications=${catalog.publications.length}`)
    } catch (error) {
      void error
      if (pageEpoch !== this.pageEpoch || catalogEpoch !== this.catalogEpoch) return
      this.setErrorKey('common_load_failed')
      console.error('[OPDS] step=load_catalog_failed code=opds_catalog_load_failed')
    } finally {
      if (pageEpoch === this.pageEpoch && catalogEpoch === this.catalogEpoch) this.loading = false
    }
  }

  private async findSearchHistoryCatalog(
    client: OpdsClient, rootUrl: string, history: RemoteReadHistoryEntry, ownsRequest: () => boolean,
  ): Promise<OpdsParseResult> {
    const query = history.opdsSearchQuery
    if (query === undefined) throw new Error('Missing OPDS search intent')
    const root = await client.fetchCatalog(rootUrl)
    if (!ownsRequest()) throw new Error('OPDS request cancelled')
    const searchUrl = resolveOpdsSearchUrl(root, query)
    if (!canRequestOpdsHistoryUrl(rootUrl, searchUrl)) throw new Error('Invalid OPDS search endpoint')
    let catalog = await client.fetchCatalog(searchUrl)
    const visited = new Set<string>()
    while (true) {
      if (!ownsRequest()) throw new Error('OPDS request cancelled')
      visited.add(catalog.feedUrl)
      if (catalog.publications.some((publication: OpdsBookDto): boolean =>
        opdsHistoryPublicationKey(publication.id) === history.resourceId)) return catalog
      const next = catalog.links.find((link: OpdsLink): boolean => link.rel?.toLocaleLowerCase() === 'next')
      if (next === undefined) throw new Error('OPDS history publication unavailable')
      const nextUrl = resolveOpdsHref(catalog.feedUrl, next.href)
      if (visited.has(nextUrl) || !canRequestOpdsHistoryUrl(rootUrl, nextUrl)) throw new Error('Invalid OPDS history pagination')
      catalog = await client.fetchCatalog(nextUrl)
    }
  }

  private readerHistoryLocator(publication: OpdsBookDto): OpdsHistoryLocator | undefined {
    const record = this.record
    if (record === undefined) return undefined
    const locator = opdsHistoryLocator(record.server.rootUrl, this.currentUrl)
    if (locator !== undefined) return locator
    const history = this.params?.remoteHistory
    const query = history !== undefined && history.resourceId === opdsHistoryPublicationKey(publication.id)
      ? history.opdsSearchQuery : this.currentUrl === this.params?.feedUrl && publication.id === this.params?.publicationId
        ? this.params?.searchQuery : undefined
    return query === undefined ? undefined : opdsSearchHistoryLocator(record.server.rootUrl, this.currentUrl, query)
  }

  private applyCatalog(catalog: OpdsParseResult): void {
    this.currentUrl = catalog.feedUrl
    this.title = catalog.title === undefined ? '' : catalog.title
    this.navigation = catalog.navigation
    this.publications = catalog.publications
    this.selectedPublication = undefined
    this.selectedImages = []
  }

  private initialCatalogUrl(rootUrl: string): string {
    const history = this.params?.remoteHistory
    if (history !== undefined) {
      const feed = resolveOpdsHistoryFeed(rootUrl, history)
      if (feed === undefined) throw new Error('Invalid OPDS history locator')
      return feed
    }
    const feedUrl = this.params?.feedUrl
    if (feedUrl === undefined || feedUrl.trim().length === 0) {
      return rootUrl
    }
    return feedUrl
  }

  private async openInitialPublicationIfNeeded(): Promise<void> {
    if (this.initialPublicationOpened) {
      return
    }
    const history = this.params?.remoteHistory
    const publicationId = this.params?.publicationId
    if (history === undefined && (publicationId === undefined || publicationId.length === 0)) {
      return
    }
    const publication = this.publications.find((item: OpdsBookDto): boolean => history === undefined
      ? item.id === publicationId : opdsHistoryPublicationKey(item.id) === history.resourceId)
    if (publication === undefined) {
      if (history !== undefined) this.setErrorKey('common_load_failed')
      return
    }
    this.initialPublicationOpened = true
    const pageEpoch = this.pageEpoch
    const catalogEpoch = this.catalogEpoch
    const publicationEpoch = this.publicationEpoch + 1
    await this.openPublication(publication)
    if (pageEpoch !== this.pageEpoch || catalogEpoch !== this.catalogEpoch || publicationEpoch !== this.publicationEpoch) return
    if (history !== undefined) {
      const serverId = this.record?.server.id
      const chapterId = `opds:${serverId}:chapter:${this.shortHash(publication.id + this.currentUrl)}`
      if (chapterId === history.chapterId && this.selectedImages.length > 0) this.openReader()
      else this.setErrorKey('common_load_failed')
    }
  }

  private openNavigation(item: OpdsCatalogDto): void {
    console.info(`[OPDS] step=open_navigation title=${item.title}`)
    this.loadCatalog(item.href, true)
  }

  private goUp(): void {
    if (this.selectedPublication !== undefined) {
      this.publicationEpoch += 1
      this.selectedPublication = undefined
      this.selectedImages = []
      return
    }
    if (this.history.length === 0) {
      return
    }
    const previous = this.history[this.history.length - 1]
    this.loadCatalog(previous.url, false, this.history.length - 1)
  }

  private async openPublication(publication: OpdsBookDto): Promise<void> {
    const pageEpoch = this.pageEpoch
    const catalogEpoch = this.catalogEpoch
    const publicationEpoch = ++this.publicationEpoch
    this.selectedPublication = publication
    const manifestLink = this.findManifestLink(publication)
    this.selectedImages = manifestLink === undefined ? mapOpdsPublicationToImages(publication) : []
    if (manifestLink === undefined) {
      console.info(`[OPDS] step=open_publication title=${publication.title} images=${this.selectedImages.length}`)
      return
    }
    const record = this.record
    if (record === undefined) {
      return
    }
    try {
      console.info(`[OPDS] step=load_publication_manifest_start urlHash=${this.shortHash(manifestLink.href)}`)
      const manifestImages = await this.store().createOpdsClient(record).fetchPublicationImages(manifestLink.href)
      if (pageEpoch !== this.pageEpoch || catalogEpoch !== this.catalogEpoch ||
        publicationEpoch !== this.publicationEpoch || this.selectedPublication !== publication) {
        return
      }
      if (manifestImages.length > 0) {
        this.selectedImages = manifestImages
      }
      console.info(`[OPDS] step=load_publication_manifest_ok images=${manifestImages.length}`)
    } catch (error) {
      void error
      if (pageEpoch !== this.pageEpoch || catalogEpoch !== this.catalogEpoch || publicationEpoch !== this.publicationEpoch) return
      console.error('[OPDS] step=load_publication_manifest_failed code=opds_manifest_load_failed')
    }
  }

  private findManifestLink(publication: OpdsBookDto): OpdsLink | undefined {
    return publication.links.find((link: OpdsLink): boolean => {
      const type = link.type === undefined ? '' : link.type.toLocaleLowerCase()
      return link.kind === OpdsLinkKind.SELF &&
        (type.indexOf('json') >= 0 || type.indexOf('divina') >= 0 || type.indexOf('webpub') >= 0)
    })
  }

  private openReader(): void {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined || this.selectedImages.length === 0) {
      this.setErrorKey('opds_no_direct_images')
      return
    }
    const now = Date.now()
    const comicId = `opds:${record.server.id}:comic:${this.shortHash(publication.id)}`
    const chapterId = `opds:${record.server.id}:chapter:${this.shortHash(publication.id + this.currentUrl)}`
    const pages = this.selectedImages.map((image: OpdsImageDto, index: number): Page => {
      const name = image.title === undefined || image.title.length === 0 ? `page-${index + 1}` : image.title
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: image.href,
        sortKey: normalizeSortKey(name),
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title: publication.title,
      index: 0,
      sourcePath: this.currentUrl,
      sortKey: normalizeSortKey(publication.title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    const comic: Comic = {
      id: comicId,
      title: publication.title,
      sourceKind: ComicSourceKind.OPDS_REMOTE,
      sourcePath: this.currentUrl,
      remoteServerId: record.server.id,
      remoteResourceId: publication.id,
      coverUri: pages[0].uri,
      sortTitle: normalizeSortKey(publication.title),
      preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    const locator = this.readerHistoryLocator(publication)
    if (locator !== undefined) {
      appReaderSessionStore((getContext(this) as common.UIAbilityContext).filesDir).saveRemoteHistory({
        kind: 'opds', comicId, chapterId, serverId: record.server.id,
        resourceId: opdsHistoryPublicationKey(publication.id), title: comic.title,
        chapterTitle: chapter.title, opdsRootFeed: locator.opdsRootFeed, opdsFeedPath: locator.opdsFeedPath,
        opdsSearchQuery: locator.opdsSearchQuery,
      })
    }
    this.installReaderSession(config)
    console.info(`[OPDS] step=open_reader images=${pages.length}`)
    RouterHelper.pushReader()
  }

  private isSelectedPublicationFavorited(): boolean {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined || this.favoriteRevision < 0) {
      return false
    }
    return this.libraryStore.findByRemote(record.server.id, publication.id) !== undefined
  }

  private createSelectedPublicationComic(): Comic | undefined {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined || this.selectedImages.length === 0) {
      return undefined
    }
    const now = Date.now()
    const comicId = `opds:${record.server.id}:comic:${this.shortHash(publication.id)}`
    const chapterId = `opds:${record.server.id}:chapter:${this.shortHash(publication.id + this.currentUrl)}`
    const pages = this.selectedImages.map((image: OpdsImageDto, index: number): Page => {
      const name = image.title === undefined || image.title.length === 0 ? `page-${index + 1}` : image.title
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: image.href,
        sortKey: normalizeSortKey(name),
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title: publication.title,
      index: 0,
      sourcePath: this.currentUrl,
      sortKey: normalizeSortKey(publication.title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    return {
      id: comicId,
      title: publication.title,
      subtitle: publication.summary,
      author: publication.author,
      sourceKind: ComicSourceKind.OPDS_REMOTE,
      sourcePath: this.currentUrl,
      remoteServerId: record.server.id,
      remoteResourceId: publication.id,
      coverUri: pages[0].uri,
      sortTitle: normalizeSortKey(publication.title),
      preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }
  }

  private addSelectedPublicationToLibrary(): void {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined) {
      return
    }
    if (this.libraryStore.findByRemote(record.server.id, publication.id) !== undefined) {
      this.showToast(s('common_already_in_library'))
      return
    }
    const comic = this.createSelectedPublicationComic()
    if (comic === undefined) {
      this.setErrorKey('opds_no_favoritable_images')
      this.showToast(s('common_no_images_to_add'))
      return
    }
    try {
      console.info(`[Favorite] step=opds_add_start server=${record.server.id} resource=${publication.id}`)
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.favoriteRevision += 1
      this.onLibraryChanged()
      this.showToast(s('common_added_to_library'))
      console.info(`[Favorite] step=opds_add_ok pages=${comic.pageCount}`)
    } catch (error) {
      void error
      this.setErrorKey('common_add_to_library_failed')
      this.showToast(s('common_add_to_library_failed'))
      console.error('[Favorite] step=opds_add_failed code=opds_add_failed')
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private installReaderSession(config: ReaderSessionConfig): void {
    const record = this.record
    if (record === undefined) {
      return
    }
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

  private acquisitionText(publication: OpdsBookDto): string {
    const acquisitions = mapOpdsPublicationToAcquisitions(publication)
    if (acquisitions.length === 0) {
      return s('opds_no_acquisition')
    }
    const supported = acquisitions.filter((item: OpdsAcquisitionDto): boolean => item.status === OpdsAcquisitionStatus.SUPPORTED).length
    return supported > 0
      ? s('opds_supported_files_count').replace('%s', `${supported}`)
      : s('opds_acquisition_unsupported')
  }

  private shortHash(value: string): string {
    let hash = 2166136261
    for (let index = 0; index < value.length; index += 1) {
      hash = (hash ^ value.charCodeAt(index)) >>> 0
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return hash.toString(16).padStart(8, '0').slice(-8)
  }

  @Builder
  private HeaderCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        KomaActionButton({
          label: s('common_back'),
          kind: 'ghost',
          compact: true,
          controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
          accentColor: (this.history.length === 0 && this.selectedPublication === undefined) ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.BRAND_PRIMARY,
          isEnabled: this.history.length > 0 || this.selectedPublication !== undefined,
          action: () => {
            this.goUp()
          },
        })
        Text(this.selectedPublication === undefined ? this.currentTitle() : this.selectedPublication.title)
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      if (this.selectedPublication !== undefined && this.selectedImages.length > 0) {
        KomaActionButton({
          label: this.isSelectedPublicationFavorited() ? s('common_in_library') : s('common_add_to_library'),
          kind: this.isSelectedPublicationFavorited() ? 'primary' : 'secondary',
          action: () => {
            this.addSelectedPublicationToLibrary()
          },
        })
          .width('100%')
        KomaActionButton({
          label: s('opds_action_read_images').replace('%s', `${this.selectedImages.length}`),
          kind: 'primary',
          action: () => {
            this.openReader()
          },
        })
          .width('100%')
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private NavigationRow(item: OpdsCatalogDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text('C')
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .width(ThemeConstants.SOURCE_ICON_SIZE)
        .height(ThemeConstants.SOURCE_ICON_SIZE)
        .textAlign(TextAlign.Center)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(ThemeConstants.RADIUS_THUMB)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.type === undefined ? s('opds_catalog_label') : item.type)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openNavigation(item)
    })
  }

  @Builder
  private PublicationRow(item: OpdsBookDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text(item.title.substring(0, 1).toLocaleUpperCase())
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .width(ThemeConstants.LIST_COVER_WIDTH)
        .height(ThemeConstants.LIST_COVER_HEIGHT)
        .textAlign(TextAlign.Center)
        .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
        .borderRadius(ThemeConstants.RADIUS_THUMB)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.acquisitionText(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openPublication(item)
    })
  }

  @Builder
  private PublicationDetail(publication: OpdsBookDto) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(publication.summary === undefined ? s('common_no_summary') : publication.summary)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      ForEach(mapOpdsPublicationToAcquisitions(publication), (item: OpdsAcquisitionDto) => {
        Text(
          item.status === OpdsAcquisitionStatus.SUPPORTED
            ? s('opds_acquisition_supported_item').replace('%s', item.type ?? item.href)
            : s('opds_acquisition_unsupported_item').replace('%s', item.type ?? item.href)
        )
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(item.status === OpdsAcquisitionStatus.SUPPORTED ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY)
      }, (item: OpdsAcquisitionDto) => item.href)
      ForEach(this.selectedImages, (item: OpdsImageDto, index: number) => {
        Text(`${index + 1}. ${item.title ?? item.href}`)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }, (item: OpdsImageDto) => item.href)
      if (this.selectedImages.length === 0) {
        Text(s('opds_no_readable_urls'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        if (this.loading) {
          ListItem() {
            Row() {
              LoadingProgress()
                .width(ThemeConstants.SPACE_XXL)
                .height(ThemeConstants.SPACE_XXL)
                .color(ThemeConstants.BRAND_PRIMARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        } else if (this.errorText().length > 0) {
          ListItem() {
            Text(this.errorText())
              .width('100%')
              .padding(ThemeConstants.SPACE_LG)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .borderRadius(ThemeConstants.RADIUS_CARD)
              .backgroundColor(ThemeConstants.CARD)
          }
        } else {
          ListItem() {
            this.HeaderCard()
          }
          if (this.selectedPublication !== undefined) {
            ListItem() {
              this.PublicationDetail(this.selectedPublication)
            }
          } else {
            ForEach(this.navigation, (item: OpdsCatalogDto) => {
              ListItem() {
                this.NavigationRow(item)
              }
            }, (item: OpdsCatalogDto) => item.href)
            ForEach(this.publications, (item: OpdsBookDto) => {
              ListItem() {
                this.PublicationRow(item)
              }
            }, (item: OpdsBookDto) => item.id)
            if (this.navigation.length === 0 && this.publications.length === 0) {
              ListItem() {
                Text(s('opds_empty_catalog'))
                  .width('100%')
                  .padding(ThemeConstants.SPACE_LG)
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontColor(ThemeConstants.TEXT_SECONDARY)
                  .borderRadius(ThemeConstants.RADIUS_CARD)
                  .backgroundColor(ThemeConstants.CARD)
              }
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
