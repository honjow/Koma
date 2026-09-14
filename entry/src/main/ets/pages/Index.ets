import { common } from '@kit.AbilityKit'
import { KomaReaderLabPage } from '../readerLab/KomaReaderLabPage'
import { KomaReaderCatalogHost } from '../readerLab/KomaReaderCatalogHost'
import { ReaderLabLaunchState, ReaderLabRequest, connectReaderLabLaunch } from '@reader-kit/ui'
import { ReaderCancellation, ReaderObservedPosition, ReaderUnitKey } from '@reader-kit/core'
import {
  BlurStrategy,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsAnimationMode,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HideMode,
  BottomBuilderShowType,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { ComponentContent } from '@kit.ArkUI'
import { LibraryPage, LibraryTitleBarPresentation } from './LibraryPage'
import { BrowsePage } from './BrowsePage'
import { HistoryPage } from './HistoryPage'
import { SearchPage } from './SearchPage'
import { SEARCH_TITLE_BOTTOM_HEIGHT, SearchTitleFieldContentBuilder } from '../components/SearchTitleField'
import { SettingsPage, SettingsPaneKey, settingsPaneTitle } from './SettingsPage'
import { ImportPage, LocalFolderImportPersistResult } from './ImportPage'
import { LocalImportCoordinator } from '../import/LocalImportCoordinator'
import { ReaderPage } from './ReaderPage'
import { MangaDetailPage } from './MangaDetailPage'
import { resolveSourceChapterList } from '../model/SourceChapterListResolver'
import { ReaderChapterDescriptor, cloneReaderChapterDescriptor, continuationChapterIds } from '../model/ReaderChapterSequence'
import { SourceBrowsePage } from './SourceBrowsePage'
import { SourceSearchPage } from './SourceSearchPage'
import { SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT, SourceSearchTitleFieldContentBuilder } from '../components/SourceSearchTitleField'
import { SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT, SourceBrowseTitleFieldContentBuilder } from '../components/SourceBrowseTitleField'
import { KomgaSeriesPage, KomgaSeriesRouteParam } from './KomgaSeriesPage'
import { KavitaBrowsePage, KavitaBrowseRouteParam } from './KavitaBrowsePage'
import { OpdsBrowsePage, OpdsBrowseRouteParam } from './OpdsBrowsePage'
import { WebDavBrowsePage } from './WebDavBrowsePage'
import { LibraryUpdateResultPage } from './LibraryUpdateResultPage'
import { LibraryCategoryManagementPage } from './LibraryCategoryManagementPage'
import { KomgaServerPage } from './KomgaServerPage'
import { KavitaServerPage } from './KavitaServerPage'
import { OpdsServerPage } from './OpdsServerPage'
import { SourcePackageManagerPage } from './SourcePackageManagerPage'
import { WebDavServerPage } from './WebDavServerPage'
import { DownloadsPage } from './DownloadsPage'
import { BackupManagementPage } from './BackupManagementPage'
import { TrackerSettingsPage } from './TrackerSettingsPage'
import { RouteName, TabIndex, tabLabel } from '../common/Constants'
import { MangaDetailTitleAction } from '../state/MangaDetailRouteChromeState'
import {
  MangaDetailRouteParam,
  RouterHelper,
  SearchRouteParam,
  SourceBrowseRouteParam,
  SourceSearchRouteParam,
} from '../common/RouterHelper'
import { KomaTabIcon } from '../components/KomaTabIcon'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  LibraryPresentationByComicId,
  MOCK_LIBRARY_READER_SESSION,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import {
  Chapter,
  Comic,
  ComicId,
  ComicSourceKind,
  Page,
  withComicAddedCategoryId,
  withComicCategoryIds,
  withComicRemovedCategoryId,
} from '../model/ComicModels'
import {
  LocalLibraryFolderScanResult,
  buildKnownLocalLibraryFolderSeriesFromComics,
  buildComicsFromLocalLibraryFolderScan,
} from '../model/LocalLibraryFolderContract'
import { LibraryStore } from '../model/LibraryStore'
import {
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
  assignComicCategoriesAndPersistLibraryStore,
  isRemovableLocalComic,
  removeComicAndPersistLibraryStore,
  removeComicsAndPersistLibraryStore,
  updateComicCategoryMembershipAndPersistLibraryStore,
  upsertComicAndPersistLibraryStore,
  upsertLocalLibraryFolderScanAndPersistLibraryStore,
  upsertLocalLibraryFolderRescanAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { OfflineDownloadQueueStore } from '../model/OfflineDownloadQueueStore'
import {
  OfflineDownloadedChapterStatus,
  OfflineDownloadedPage,
  OfflineDownloadStore,
} from '../model/OfflineDownloadStore'
import {
  appReaderSessionStore,
  InMemoryReaderSessionStore,
  ReaderSessionConfig,
  ReaderSessionStore,
  cloneReaderSessionConfig,
  createReaderSessionConfigFromComic,
  getReaderSessionPageId,
  sortedReaderChapters,
} from '../model/ReaderSessionStore'
import { createReaderOfflineMissingUri, installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'
import { SourceChapterPageHydrator, resolveSourceChapterPages } from '../model/SourceChapterPageHydrator'
import {
  SourceReaderSessionRequest,
  cloneSourceReaderSessionRequest,
  sourceReadHistoryEntryFromRequest,
  sourceReaderSessionRequestForChapter,
} from '../model/SourceReaderSession'
import { SourceRuntimeRegistry, sourceRuntimeEntryEnabled } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceManga } from '../model/SourceModels'
import {
  appSourceRuntimeRegistry,
  bootstrapSourceRuntimeAppRegistry,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import { configureSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { configureSourceFilterPreferencesStore } from '../sourceRuntime/SourceFilterPreferencesStore'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { BackupService, BackupAutomaticRunResult } from '../model/BackupService'
import { TrackerPendingProgressDrainSummary, TrackerProgressSyncService } from '../model/TrackerProgressSyncService'
import { TRACKER_PROVIDER_CONFIGS, TrackerProviderConfig, TrackerProviderId } from '../model/TrackerModels'
import { SourceBrowseRouteChromeState, SourceSearchRouteChromeState } from '../state/SourceRouteChromeState'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'

const readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
const seededLibraryStore: LibraryStore = createSeededLibraryStore()
const libraryPresentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
const sourceRuntimeRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
interface SettingsPaneRouteParam {
  pane: string
}

interface TrackerProviderRouteParam {
  providerId: TrackerProviderId
}

interface BackupTaskRouteParam {
  pane: string
  fileName: string
}

@Entry
@ComponentV2
struct Index {
  @Local private readerLabLaunch: ReaderLabLaunchState = connectReaderLabLaunch()

  @Monitor('readerLabLaunch.version')
  private handleReaderLabLaunch(): void {
    const request = this.readerLabLaunch.consume()
    if (request !== null) this.appPathStack.pushPath({ name: 'ReaderLab', param: request })
  }
  @Local selectedTab: number = TabIndex.LIBRARY
  @Local private importMenuShown: boolean = false
  @Local private trackerSettingsRevision: number = 0
  @Local private backupSettingsRevision: number = 0
  @Local private libraryPreferencesRevision: number = 0
  @Local private libraryTitleBar: LibraryTitleBarPresentation = {
    selectionMode: false,
    batchDownloadBusy: false,
    selectedCount: 0,
    menuItems: [],
    cancelSelection: () => {},
  }
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private readerOpen: boolean = false
  @Local private readerClosing: boolean = false
  @Local private readerRouteVisible: boolean = false
  @Local private readerSessionLoading: boolean = false
  @Local private readerCloseRequestId: number = 0
  @Local private readerPageIndex: number = 0
  @Local private readerChromeVisible: boolean = false
  @Local private readerWebtoonMode: boolean = false
  @Local private readerSessionConfig: ReaderSessionConfig = MOCK_LIBRARY_READER_SESSION
  // ReaderPage writes this store directly. Bump the revision only after its
  // close path has flushed so LibraryPage can rebuild `lastRead` ordering from
  // the same in-memory snapshot rather than reopening a second store.
  @Local private readerProgressRevision: number = 0
  @Local private libraryRevision: number = 0
  @Local private libraryComics: Comic[] = seededLibraryStore.listComics()
  private tabController: HdsTabsController = new HdsTabsController()
  private tabBarHiddenForKeyboard: boolean = false
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId
  private sourceRegistry: SourceRuntimeRegistry = sourceRuntimeRegistry
  private appPathStack: NavPathStack = new NavPathStack()
  private searchFieldContents: Map<SearchRouteChromeState, ComponentContent<SearchRouteChromeState>> = new Map()
  private sourceSearchFieldContents: Map<SourceSearchRouteChromeState, ComponentContent<SourceSearchRouteChromeState>> = new Map()
  private sourceBrowseFieldContents: Map<SourceBrowseRouteChromeState, ComponentContent<SourceBrowseRouteChromeState>> = new Map()
  private readonly localImportCoordinator: LocalImportCoordinator = new LocalImportCoordinator()
  private libraryPersistenceService?: LibraryStorePersistenceService
  private readerSessionPersistenceReady: boolean = false
  private libraryPersistenceRestored: boolean = false
  private automaticBackupChecked: boolean = false
  private pendingTrackerProgressChecked: boolean = false
  private readerOpenEpoch: number = 0
  /** Present only while Reader was launched from an un-shelved source item. */
  private activeSourceReaderRequest?: SourceReaderSessionRequest

  @Monitor('layoutSafeArea.keyboardHeight')
  private updateRootTabBarForKeyboard(): void {
    const shouldHide: boolean = this.layoutSafeArea.keyboardHeight > 0
    if (shouldHide === this.tabBarHiddenForKeyboard) {
      return
    }
    this.tabBarHiddenForKeyboard = shouldHide
    if (shouldHide) {
      this.tabController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
      return
    }
    this.tabController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
  }

  private refreshLibrarySnapshot(): void {
    this.libraryComics = this.libraryStore.listComics()
    this.libraryRevision += 1
  }

  private onMangaDetailLibraryChanged(): void {
    this.refreshLibrarySnapshot()
    const transientRequest = this.activeSourceReaderRequest
    if (transientRequest === undefined) {
      return
    }
    if (this.libraryStore.getComic(transientRequest.comicId) !== undefined) {
      // The user explicitly collected this source item while its Reader was
      // open. From this point it owns normal shelf/history semantics, so a
      // later chapter switch must not recreate transient source history.
      this.activeSourceReaderRequest = undefined
    }
  }

  private readerChapterIdForOpen(comic: Comic, requestedChapterId?: string): string | undefined {
    if (requestedChapterId !== undefined && requestedChapterId.trim().length > 0) {
      return requestedChapterId
    }
    const progress = this.readerSessionStore.getProgress(comic.id)
    if (progress !== undefined && comic.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId)) {
      return progress.chapterId
    }
    const firstChapter = sortedReaderChapters(comic.chapters)[0]
    return firstChapter?.id
  }

  private chapterNeedsReaderSourcePages(comic: Comic, chapterId: string | undefined): boolean {
    if (chapterId === undefined ||
      comic.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY ||
      comic.sourceRuntimeId === undefined ||
      comic.sourceRuntimeId.trim().length === 0) {
      return false
    }
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === chapterId)
    // Cache-first: if the chapter already has resolved pages, do not block the reader
    return chapter !== undefined && chapter.pages.length === 0
  }

  private logReaderSourcePagesUnavailable(reasonCode?: string): void {
    if (reasonCode === 'pages_missing' ||
      reasonCode === 'chapter_missing' ||
      reasonCode === 'source_missing' ||
      reasonCode === 'source_not_installed' ||
      reasonCode === 'source_lookup_failed' ||
      reasonCode === 'source_disabled' ||
      reasonCode === 'source_pages_failed') {
      console.warn(`[Reader] step=open_source_pages_unavailable failed=true reason=${reasonCode}`)
      return
    }
    console.warn('[Reader] step=open_source_pages_unavailable failed=true reason=source_pages_unavailable')
  }

  private hasAvailableOfflineReaderPages(comicId: ComicId, chapterId: string | undefined): boolean {
    if (chapterId === undefined || chapterId.length === 0) {
      return false
    }
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        return false
      }
      const validation = new OfflineDownloadStore(context.filesDir)
        .validateDownloadedChapter(comicId, chapterId, { validateContentHash: false })
      return validation.manifest !== undefined &&
        validation.availablePageCount > 0 &&
        (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
          validation.status === OfflineDownloadedChapterStatus.PARTIAL)
    } catch (_error) {
      console.warn('[ReaderOffline] step=open_manifest_probe failed=true reason=manifest_session')
      return false
    }
  }

  private async ensureReaderSourceChapterPages(comic: Comic, chapterId: string | undefined): Promise<boolean> {
    if (!this.chapterNeedsReaderSourcePages(comic, chapterId)) {
      return true
    }
    try {
      const result = await new SourceChapterPageHydrator(
        this.libraryStore,
        this.sourceRegistry,
        this.ensureLibraryPersistenceService(),
        () => {
          this.refreshLibrarySnapshot()
        },
      ).ensureChapterPages(comic.id, comic.sourceRuntimeId, chapterId as string, false)
      if (!result.hydrated) {
        this.logReaderSourcePagesUnavailable(result.reasonCode)
        return false
      }
      return true
    } catch (_error) {
      this.logReaderSourcePagesUnavailable('source_pages_lookup')
      return false
    }
  }

  private async prepareReaderSession(
    comicId: ComicId,
    chapterId: string | undefined,
    openEpoch: number,
  ): Promise<void> {
    const originalComic = this.libraryStore.getComic(comicId)
    if (originalComic === undefined) {
      if (openEpoch === this.readerOpenEpoch) {
        this.readerSessionLoading = false
      }
      return
    }
    const offlineReaderPagesReady = this.hasAvailableOfflineReaderPages(originalComic.id, chapterId)
    let sourcePagesReady = true
    if (!offlineReaderPagesReady) {
      sourcePagesReady = await this.ensureReaderSourceChapterPages(originalComic, chapterId)
    }
    const comic = this.libraryStore.getComic(comicId) ?? originalComic
    try {
      await installReaderRemoteHeadersForComic(getContext(this) as common.UIAbilityContext, comic)
    } catch (_error) {
      console.error('[Favorite] step=open_remote_reader_headers_failed code=remote_headers_failed')
    }
    if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) {
      return
    }
    let nextSessionConfig = this.createReaderSessionConfigForOpen(comic, chapterId)
    if (!sourcePagesReady && nextSessionConfig.totalPages <= 0) {
      nextSessionConfig = this.createSourceUnavailableReaderSessionConfig(comic, chapterId, nextSessionConfig)
    }
    this.readerSessionConfig = nextSessionConfig
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(nextSessionConfig)
    this.readerSessionLoading = false
  }

  private createSourceReaderSessionConfig(
    request: SourceReaderSessionRequest,
    pages: Page[],
  ): ReaderSessionConfig {
    const chapterIds = request.chapterIds.includes(request.chapterId)
      ? request.chapterIds.slice()
      : request.chapterIds.concat([request.chapterId])
    const selectedIndex = chapterIds.indexOf(request.chapterId)
    const chapterTitles = chapterIds.map((chapterId: string, index: number): string => {
      const knownTitle = request.chapterTitles?.[index] ?? ''
      if (knownTitle.trim().length > 0 || chapterId !== request.chapterId) {
        return knownTitle
      }
      return request.chapterTitles?.[selectedIndex] ?? ''
    })
    return {
      comicId: request.comicId,
      chapterId: request.chapterId,
      chapterIds,
      chapterTitles,
      continuationChapterIds: request.chaptersResolved === true && request.chapters !== undefined
        ? continuationChapterIds(request.chapters, request.chapterId) : undefined,
      title: request.title,
      chapterTitle: chapterTitles[selectedIndex],
      totalPages: pages.length,
      pageUris: pages.map((page: Page): string => page.uri),
      pageIds: pages.map((page: Page): string => page.id),
      pageWidths: pages.map((page: Page): number | undefined => page.width),
      pageHeights: pages.map((page: Page): number | undefined => page.height),
      sourceRuntimeId: request.sourceId,
    }
  }

  private createUnavailableSourceReaderSessionConfig(request: SourceReaderSessionRequest): ReaderSessionConfig {
    const config = this.createSourceReaderSessionConfig(request, [])
    config.totalPages = 1
    config.pageUris = ['source-placeholder://chapter']
    config.pageIds = [`${request.chapterId}:source-unavailable`]
    config.pageWidths = [undefined]
    config.pageHeights = [undefined]
    return config
  }

  private async prepareSourceReaderSession(
    request: SourceReaderSessionRequest,
    openEpoch: number,
  ): Promise<void> {
    const preparedRequest = cloneSourceReaderSessionRequest(request)
    if (preparedRequest.chaptersResolved !== true) {
      try {
        const lookup = this.sourceRegistry.lookup(request.sourceId)
        if (lookup.ok && lookup.entry !== undefined && sourceRuntimeEntryEnabled(lookup.entry)) {
          const catalog = await resolveSourceChapterList(lookup.entry, request.mangaId)
          if (catalog.resolved && catalog.chapters.some((chapter: ReaderChapterDescriptor): boolean => chapter.id === request.chapterId)) {
            preparedRequest.chapters = catalog.chapters.map((chapter: ReaderChapterDescriptor): ReaderChapterDescriptor =>
              cloneReaderChapterDescriptor(chapter))
            preparedRequest.chapterIds = catalog.chapters.map((chapter: ReaderChapterDescriptor): string => chapter.id)
            preparedRequest.chapterTitles = catalog.chapters.map((chapter: ReaderChapterDescriptor): string => chapter.title)
            preparedRequest.chaptersResolved = true
          }
        }
      } catch (_error) {
        // A failed catalog must not prevent opening the known current chapter.
        console.warn('[ReaderSource] chapter catalog unresolved')
      }
    }
    // Do not share the library hydrator's result here. Source hosts may issue
    // short-lived descriptors; a transient Reader open always resolves pages
    // afresh and never writes them to LibraryStore.
    const resolution = await resolveSourceChapterPages(this.sourceRegistry, {
      comicId: request.comicId,
      sourceId: request.sourceId,
      mangaId: request.mangaId,
      chapterId: request.chapterId,
    })
    const activeRequest = this.activeSourceReaderRequest
    if (openEpoch !== this.readerOpenEpoch ||
      !this.readerOpen ||
      this.readerClosing ||
      activeRequest === undefined ||
      activeRequest.comicId !== request.comicId ||
      activeRequest.chapterId !== request.chapterId) {
      return
    }
    this.activeSourceReaderRequest = preparedRequest
    if (resolution.pages.length === 0) {
      this.logReaderSourcePagesUnavailable(resolution.reasonCode)
      const unavailableConfig = this.createUnavailableSourceReaderSessionConfig(preparedRequest)
      this.readerSessionConfig = unavailableConfig
      this.readerPageIndex = this.readerSessionStore.restorePageIndex(unavailableConfig)
      this.readerSessionLoading = false
      return
    }
    const nextSessionConfig = this.createSourceReaderSessionConfig(preparedRequest, resolution.pages)
    this.readerSessionConfig = nextSessionConfig
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(nextSessionConfig)
    // Persist only stable identity/title/cover/current-chapter metadata. Page
    // descriptors intentionally stay in the route-local Reader config.
    this.readerSessionStore.saveSourceHistory(sourceReadHistoryEntryFromRequest(preparedRequest))
    this.readerSessionStore.flush()
    this.readerSessionLoading = false
  }

  private readerLabInitialConfig(work: string, unit: string): ReaderSessionConfig | null {
    if (this.readerSessionConfig.comicId === work && this.readerSessionConfig.chapterId === unit &&
      this.readerSessionConfig.totalPages > 0) return cloneReaderSessionConfig(this.readerSessionConfig)
    const comic = this.libraryStore.getComic(work)
    if (comic === undefined) return null
    const config = this.createReaderSessionConfigForOpen(comic, unit)
    return config.chapterId === unit && config.totalPages > 0 ? config : null
  }

  private async prepareReaderLabCatalog(target: ReaderUnitKey,
    cancellation: ReaderCancellation): Promise<ReaderSessionConfig | null> {
    if (target.scope !== 'koma-local') return null
    const sourceRequest = this.activeSourceReaderRequest
    if (sourceRequest !== undefined && sourceRequest.comicId === target.work) {
      const nextRequest = sourceReaderSessionRequestForChapter(sourceRequest, target.unit)
      if (nextRequest === undefined) return null
      const resolution = await resolveSourceChapterPages(this.sourceRegistry, {
        comicId: nextRequest.comicId,
        sourceId: nextRequest.sourceId,
        mangaId: nextRequest.mangaId,
        chapterId: nextRequest.chapterId,
      })
      cancellation.check()
      // A chapter handoff is prepared beside the still-readable shared session.
      // Do not turn a provider failure into a committed placeholder unit: reject
      // the handoff so the current chapter stays visible and can be retried.
      if (resolution.pages.length === 0) throw new Error('koma_reader_chapter_pages_unavailable')
      return this.createSourceReaderSessionConfig(nextRequest, resolution.pages)
    }
    const original = this.libraryStore.getComic(target.work)
    if (original === undefined) return null
    // Keep local-folder permission activation in the adapter's established path.
    if (original.sourceKind === ComicSourceKind.LOCAL_FOLDER) return null
    const offlineReady = this.hasAvailableOfflineReaderPages(original.id, target.unit)
    if (!offlineReady) await this.ensureReaderSourceChapterPages(original, target.unit)
    cancellation.check()
    const comic = this.libraryStore.getComic(target.work) ?? original
    try {
      await installReaderRemoteHeadersForComic(getContext(this) as common.UIAbilityContext, comic)
    } catch (_error) {
      console.warn('[KomaReaderLab] remote_headers_unavailable')
    }
    cancellation.check()
    const config = this.createReaderSessionConfigForOpen(comic, target.unit)
    if (config.totalPages > 0) return config
    if (this.chapterNeedsReaderSourcePages(comic, target.unit)) {
      throw new Error('koma_reader_chapter_pages_unavailable')
    }
    return null
  }

  private createReaderLabCatalogHost(): KomaReaderCatalogHost {
    return new KomaReaderCatalogHost(
      (work: string, unit: string): ReaderSessionConfig | null => this.readerLabInitialConfig(work, unit),
      (target: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderSessionConfig | null> =>
        this.prepareReaderLabCatalog(target, cancellation),
      (target: ReaderUnitKey, config: ReaderSessionConfig): void => this.commitReaderLabCatalog(target, config),
    )
  }

  private commitReaderLabCatalog(target: ReaderUnitKey, config: ReaderSessionConfig): void {
    if (target.scope !== 'koma-local' || config.comicId !== target.work || config.chapterId !== target.unit ||
      config.totalPages < 1 || config.pageUris.length !== config.totalPages) return
    this.readerSessionConfig = cloneReaderSessionConfig(config)
    const sourceRequest = this.activeSourceReaderRequest
    if (sourceRequest === undefined || sourceRequest.comicId !== target.work) return
    const committedRequest = sourceReaderSessionRequestForChapter(sourceRequest, target.unit)
    if (committedRequest === undefined) return
    if (sourceRequest.chapterId === committedRequest.chapterId) return
    this.activeSourceReaderRequest = committedRequest
    this.readerSessionStore.saveSourceHistory(sourceReadHistoryEntryFromRequest(committedRequest))
    this.readerSessionStore.flush()
  }

  private readerNeedsAsyncPreparation(comic: Comic, chapterId: string | undefined): boolean {
    if (this.hasAvailableOfflineReaderPages(comic.id, chapterId)) {
      return false
    }
    if (this.chapterNeedsReaderSourcePages(comic, chapterId)) {
      return true
    }
    return comic.sourceKind === ComicSourceKind.KOMGA_REMOTE ||
      comic.sourceKind === ComicSourceKind.KAVITA_REMOTE ||
      comic.sourceKind === ComicSourceKind.OPDS_REMOTE ||
      comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE
  }

  private async openReader(comicId: ComicId, chapterId?: string): Promise<void> {
    this.activeSourceReaderRequest = undefined
    const comic = this.libraryStore.getComic(comicId)
    const targetChapterId = comic === undefined ? chapterId : this.readerChapterIdForOpen(comic, chapterId)
    const readerDetailVisible = this.isReaderDetailRouteVisible()
    const shouldPresentReader = !this.readerOpen || this.readerClosing
    const openEpoch = this.readerOpenEpoch + 1
    this.readerOpenEpoch = openEpoch
    this.readerChromeVisible = false
    this.readerSessionLoading = comic !== undefined && this.readerNeedsAsyncPreparation(comic, targetChapterId)
    this.readerSessionConfig = comic === undefined
      ? MOCK_LIBRARY_READER_SESSION
      : this.createReaderSessionConfigForOpen(comic, targetChapterId)
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(this.readerSessionConfig)
    // Starting a chapter from a detail page that was opened by Reader updates
    // the already-mounted Reader beneath it.  It is not a second Reader route.
    if (readerDetailVisible) {
      this.appPathStack.pop(true)
    }
    if (shouldPresentReader) {
      this.readerClosing = false
      this.readerRouteVisible = false
      this.readerOpen = true
      // Native root navigation presents the Reader immediately. Descriptor
      // refresh remains session work and never blocks route presentation.
      this.appPathStack.pushPath({ name: RouteName.READER }, true)
    }
    if (comic !== undefined) {
      void this.prepareReaderSession(comicId, targetChapterId, openEpoch)
    }
  }

  private async openSourceReader(request: SourceReaderSessionRequest): Promise<void> {
    const nextRequest = cloneSourceReaderSessionRequest(request)
    if (nextRequest.sourceId.trim().length === 0 ||
      nextRequest.mangaId.trim().length === 0 ||
      nextRequest.comicId.trim().length === 0 ||
      nextRequest.chapterId.trim().length === 0 ||
      !nextRequest.chapterIds.includes(nextRequest.chapterId)) {
      return
    }
    const readerDetailVisible = this.isReaderDetailRouteVisible()
    const shouldPresentReader = !this.readerOpen || this.readerClosing
    const openEpoch = this.readerOpenEpoch + 1
    this.readerOpenEpoch = openEpoch
    this.activeSourceReaderRequest = nextRequest
    this.readerChromeVisible = false
    this.readerSessionLoading = true
    this.readerSessionConfig = this.createSourceReaderSessionConfig(nextRequest, [])
    this.readerPageIndex = 0
    // This matches normal Reader chapter switching: a detail page opened from
    // Reader is popped before the already-mounted Reader receives its next
    // transient session.
    if (readerDetailVisible) {
      this.appPathStack.pop(true)
    }
    if (shouldPresentReader) {
      this.readerClosing = false
      this.readerRouteVisible = false
      this.readerOpen = true
      this.appPathStack.pushPath({ name: RouteName.READER }, true)
    }
    void this.prepareSourceReaderSession(nextRequest, openEpoch)
  }

  private openExternalReaderSession(): void {
    if (this.readerOpen && !this.readerClosing) {
      return
    }
    this.readerOpenEpoch += 1
    this.activeSourceReaderRequest = undefined
    this.readerChromeVisible = false
    this.readerSessionLoading = false
    this.readerSessionConfig = cloneReaderSessionConfig(MOCK_LIBRARY_READER_SESSION)
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(this.readerSessionConfig)
    this.readerClosing = false
    this.readerRouteVisible = false
    this.readerOpen = true
    this.appPathStack.pushPath({ name: RouteName.READER }, true)
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_error) {
    }
  }

  private createSourceUnavailableReaderSessionConfig(
    comic: Comic,
    chapterId: string | undefined,
    baseConfig: ReaderSessionConfig,
  ): ReaderSessionConfig {
    const resolvedChapterId = chapterId !== undefined && chapterId.length > 0 ? chapterId : baseConfig.chapterId
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === resolvedChapterId)
    const fallbackChapterId = resolvedChapterId.length > 0 ? resolvedChapterId : 'source-unavailable'
    const chapterIds = baseConfig.chapterIds.includes(fallbackChapterId) ? baseConfig.chapterIds : baseConfig.chapterIds.concat([fallbackChapterId])
    const chapterTitles = chapterIds.map((item: string, index: number): string => {
      const existingTitle = baseConfig.chapterTitles?.[index] ?? ''
      if (existingTitle.length > 0 || item !== fallbackChapterId) {
        return existingTitle
      }
      return chapter?.title ?? ''
    })
    return {
      comicId: comic.id,
      chapterId: fallbackChapterId,
      title: comic.title,
      chapterTitle: baseConfig.chapterTitle ?? chapter?.title,
      chapterIds,
      continuationChapterIds: baseConfig.continuationChapterIds,
      chapterTitles,
      totalPages: 1,
      pageUris: ['source-placeholder://chapter'],
      pageIds: [`${fallbackChapterId}:source-unavailable`],
      pageWidths: [undefined],
      pageHeights: [undefined],
      sourceRuntimeId: comic.sourceRuntimeId,
    }
  }

  private createReaderSessionConfigForOpen(comic: Comic, chapterId?: string): ReaderSessionConfig {
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    const offlineChapterId = chapterId ?? config.chapterId
    if (config.totalPages > 0 || offlineChapterId.length === 0) {
      return config
    }
    return this.createOfflineDownloadReaderSessionConfig(comic, offlineChapterId, config) ?? config
  }

  private createOfflineDownloadReaderSessionConfig(
    comic: Comic,
    chapterId: string,
    baseConfig: ReaderSessionConfig
  ): ReaderSessionConfig | undefined {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        return undefined
      }
      const store = new OfflineDownloadStore(context.filesDir)
      const validation = store.validateDownloadedChapter(comic.id, chapterId, { validateContentHash: false })
      const hasReaderReadyPages = validation.availablePageCount > 0 &&
        (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
          validation.status === OfflineDownloadedChapterStatus.PARTIAL)
      const hasCorruptManifestPageMap = validation.status === OfflineDownloadedChapterStatus.CORRUPT &&
        validation.pageCount > 0
      if (validation.manifest === undefined ||
        validation.pageCount <= 0 ||
        (!hasReaderReadyPages && !hasCorruptManifestPageMap)) {
        return undefined
      }
      const pageUris: string[] = []
      const pageIds: string[] = []
      const pageWidths: Array<number | undefined> = []
      const pageHeights: Array<number | undefined> = []
      for (let index = 0; index < validation.pageCount; index += 1) {
        const page = validation.manifest.pages.find((item: OfflineDownloadedPage): boolean => item.pageIndex === index)
        const pageId = page?.pageId ?? `page-${index + 1}`
        pageIds.push(pageId)
        // `validateDownloadedChapter` above is the one structural validation
        // for this open: it already checks the manifest identity, safe root,
        // each page index, file existence and byte size. Calling
        // `resolveDownloadedPage` here would repeat that full validation once
        // for every page (53 × for the affected chapter) before ReaderPage can
        // even present. Keep a corrupt manifest fail-closed; for a validated
        // downloaded or partial chapter, hand its local path to the session.
        const localPagePath = hasReaderReadyPages ? (page?.localPath ?? '') : ''
        pageUris.push(localPagePath.length > 0
          ? localPagePath
          : createReaderOfflineMissingUri(comic.id, chapterId, index))
        pageWidths.push(page?.width)
        pageHeights.push(page?.height)
      }
      const chapterIds = baseConfig.chapterIds.includes(chapterId) ? baseConfig.chapterIds : baseConfig.chapterIds.concat([chapterId])
      const chapterTitles = chapterIds.map((item: string, index: number): string => {
        const title = baseConfig.chapterTitles?.[index] ?? ''
        if (title.length > 0 || item !== chapterId) {
          return title
        }
        return validation.manifest?.chapterTitle ?? ''
      })
      console.info(`[ReaderOffline] step=open_from_manifest pages=${validation.availablePageCount}/${validation.pageCount}`)
      return {
        comicId: comic.id,
        chapterId,
        title: comic.title,
        chapterTitle: baseConfig.chapterTitle ?? validation.manifest.chapterTitle,
        chapterIds,
        continuationChapterIds: baseConfig.continuationChapterIds,
        chapterTitles,
        totalPages: validation.pageCount,
        pageUris,
        pageIds,
        pageWidths,
        pageHeights,
        sourceRuntimeId: comic.sourceRuntimeId,
      }
    } catch (_error) {
      console.warn('[ReaderOffline] step=open_from_manifest failed=true reason=manifest_session')
      return undefined
    }
  }

  private isReaderDetailRouteVisible(): boolean {
    const names = this.appPathStack.getAllPathName()
    return names.length >= 2 &&
      names[names.length - 1] === RouteName.MANGA_DETAIL &&
      names[names.length - 2] === RouteName.READER
  }

  private isReaderRouteVisible(): boolean {
    const names = this.appPathStack.getAllPathName()
    return names.length > 0 && names[names.length - 1] === RouteName.READER
  }

  private closeReader(): void {
    if (!this.readerOpen || this.readerClosing) {
      return
    }
    // Detail is a normal root route above Reader. Its own destination handles
    // Back; never begin a Reader close while that route is still on top.
    if (this.isReaderDetailRouteVisible()) {
      this.appPathStack.pop(true)
      return
    }
    this.readerOpenEpoch += 1
    this.readerSessionLoading = false
    if (!this.isReaderRouteVisible()) {
      return
    }
    // During the native enter transition ReaderPage may not have received
    // onShown yet. There is no Reader-owned status bar to restore in that
    // window, so let the root stack cancel the in-flight route directly.
    if (!this.readerRouteVisible) {
      this.readerClosing = true
      this.readerChromeVisible = false
      this.appPathStack.pop(true)
      return
    }
    // ReaderPage restores the application system bar before the native pop.
    this.readerCloseRequestId += 1
  }

  private popReaderRouteAfterSystemBarRestore(): void {
    if (!this.readerOpen || this.readerClosing || !this.isReaderRouteVisible()) {
      return
    }
    // ReaderPage calls this callback after it persists its current page. Keep
    // the explicit flush here as the boundary before publishing the snapshot
    // to the shelf, including future Reader close implementations.
    this.readerSessionStore.flush()
    this.readerProgressRevision += 1
    this.readerClosing = true
    this.readerRouteVisible = false
    this.readerChromeVisible = false
    this.appPathStack.pop(true)
  }

  private finishReaderRouteClose(): void {
    if (!this.readerClosing) {
      return
    }
    this.readerOpen = false
    this.readerClosing = false
    this.readerRouteVisible = false
    this.readerSessionLoading = false
  }

  private reloadReaderSessionStore(reason: string): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context.filesDir === undefined || context.filesDir.length === 0) {
        return
      }
      this.readerSessionStore = appReaderSessionStore(context.filesDir)
      this.readerSessionPersistenceReady = true
      this.readerProgressRevision += 1
      console.info(`[Reader] step=progress_store_reloaded reason=${reason}`)
    } catch (_error) {
      console.warn('[Reader] step=restore_progress_failed reason=session_store')
    }
  }

  private readReaderLabInitialColumn(work: string, unit: string): 'odd_left' | 'even_left' {
    if (!this.readerSessionPersistenceReady) throw new Error('reader_lab_progress_owner_unavailable')
    const config: ReaderSessionConfig = {
      comicId: work, chapterId: unit, chapterIds: [unit], totalPages: 0, pageUris: []
    }
    return this.readerSessionStore.restoreColumnMode(config, 'odd_left')
  }

  private readReaderLabInitialPage(work: string, unit: string): number {
    if (!this.readerSessionPersistenceReady) throw new Error('reader_lab_progress_owner_unavailable')
    const config = this.readerLabInitialConfig(work, unit)
    if (config === null) return 0
    return this.readerSessionStore.restorePageIndex(config)
  }

  private persistReaderLabObserved(position: ReaderObservedPosition,
    column: 'odd_left' | 'even_left'): void {
    if (!this.readerSessionPersistenceReady || position.anchor.unit.scope !== 'koma-local') return
    const config = this.readerLabInitialConfig(position.anchor.unit.work, position.anchor.unit.unit)
    if (config === null) return
    if (config.chapterId !== position.anchor.unit.unit || config.totalPages !== position.pageCount ||
      position.anchor.sourceIndexHint < 0 || position.anchor.sourceIndexHint >= config.totalPages) return
    const index = position.anchor.sourceIndexHint
    this.readerSessionStore.saveProgress({
      comicId: config.comicId,
      chapterId: config.chapterId,
      pageId: getReaderSessionPageId(config, index),
      pageIndex: index,
      totalPages: config.totalPages,
      progressRatio: (index + 1) / config.totalPages,
      completed: position.terminalSourceDisplayed,
      updatedAt: Date.now(),
      columnMode: column,
    })
    this.readerProgressRevision += 1
  }

  private onBackupRestored(): void {
    this.ensureLibraryPersistenceService()?.restore()
    this.readerProgressRevision += 1
    this.refreshLibrarySnapshot()
  }

  private openLibraryMangaDetail(comicId: ComicId): void {
    const comic = this.libraryStore.getComic(comicId)
    if (comic === undefined) {
      return
    }
    const sourceId = comic.sourceRuntimeId?.trim() ?? ''
    const remoteMangaId = comic.remoteResourceId?.trim() ?? ''
    const params: MangaDetailRouteParam = sourceId.length > 0 && remoteMangaId.length > 0
      ? {
        mangaId: remoteMangaId,
        sourceId,
        initialManga: {
          id: remoteMangaId,
          sourceId,
          title: comic.title,
          coverUrl: comic.coverUri,
        },
      }
      : { mangaId: comic.id }
    RouterHelper.pushMangaDetail(params)
  }

  private openReaderMangaDetail(): void {
    const comicId = this.readerSessionConfig.comicId
    if (comicId.length === 0 || !this.isReaderRouteVisible()) {
      return
    }
    const sourceRequest = this.activeSourceReaderRequest
    if (sourceRequest !== undefined && sourceRequest.comicId === comicId) {
      const detailParam: MangaDetailRouteParam = {
        mangaId: sourceRequest.mangaId,
        sourceId: sourceRequest.sourceId,
        initialManga: {
          id: sourceRequest.mangaId,
          sourceId: sourceRequest.sourceId,
          title: sourceRequest.title,
          coverUrl: sourceRequest.coverUri,
        },
      }
      this.appPathStack.pushPath({
        name: RouteName.MANGA_DETAIL,
        param: detailParam,
      }, true)
      return
    }
    const comic = this.libraryStore.getComic(comicId)
    const sourceId = comic?.sourceRuntimeId?.trim() ?? ''
    const remoteMangaId = comic?.remoteResourceId?.trim() ?? ''
    const detailParam: MangaDetailRouteParam = sourceId.length > 0 && remoteMangaId.length > 0
      ? {
        mangaId: remoteMangaId,
        sourceId,
        initialManga: {
          id: remoteMangaId,
          sourceId,
          title: comic?.title ?? this.readerSessionConfig.title ?? comicId,
          coverUrl: comic?.coverUri,
        },
      }
      : { mangaId: comic?.id ?? comicId }
    this.appPathStack.pushPath({ name: RouteName.MANGA_DETAIL, param: detailParam }, true)
  }

  private openImport(): void {
    this.importMenuShown = true
  }

  private async startArchiveImport(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndImportArchives(context, 1)
      let succeededCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          succeededCount += 1
          this.handleArchiveImportSucceeded(result.extractionResult.importResult.comic)
        } else {
          failedCount += 1
        }
      })
      if (results.length === 0) {
        return
      }
      if (failedCount === 0) {
        this.showToast(AppStrings.format('import_feedback_success', succeededCount))
      } else if (succeededCount === 0) {
        this.showToast(AppStrings.format('import_feedback_failed_files', failedCount))
      } else {
        this.showToast(AppStrings.format('import_feedback_partial', succeededCount, failedCount))
      }
    } catch (error) {
      console.error('[Import] step=archive_import_failed code=archive_import_failed')
      this.showToast(AppStrings.get('import_feedback_failed_file'))
    }
  }

  private async startImageImport(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndImportImages(context)
      let succeededCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          succeededCount += 1
          this.handleArchiveImportSucceeded(result.importResult.comic)
        } else {
          failedCount += 1
        }
      })
      if (results.length === 0) {
        return
      }
      if (failedCount === 0) {
        this.showToast(AppStrings.format('import_feedback_success', succeededCount))
      } else if (succeededCount === 0) {
        this.showToast(AppStrings.get('import_feedback_failed_images'))
      } else {
        this.showToast(AppStrings.format('import_feedback_partial', succeededCount, failedCount))
      }
    } catch (error) {
      console.error('[Import] step=image_import_failed code=image_import_failed')
      this.showToast(AppStrings.get('import_feedback_failed_images'))
    }
  }

  private async startFolderImport(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndScanFolders(context, 1)
      let importedCount = 0
      let checkedCount = 0
      let addedCount = 0
      let changedCount = 0
      let missingCount = 0
      let metadataChangedCount = 0
      let rejectedEntryCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          try {
            const persistResult = this.handleLocalFolderImportSucceeded(result.scanResult, result.rootUri)
            importedCount += persistResult.importedCount
            checkedCount += persistResult.checkedCount
            addedCount += persistResult.addedCount
            changedCount += persistResult.changedCount
            missingCount += persistResult.missingCount
            metadataChangedCount += persistResult.metadataChangedCount
            rejectedEntryCount += persistResult.rejectedEntryCount
          } catch (error) {
            failedCount += 1
          }
          return
        }
        failedCount += 1
      })
      if (results.length === 0) {
        return
      }
      if (importedCount > 0 && failedCount === 0 &&
        (addedCount > 0 || changedCount > 0 || metadataChangedCount > 0 || missingCount > 0 || rejectedEntryCount > 0)) {
        this.showToast(AppStrings.format('import_feedback_folder_rescan_done', addedCount, changedCount, metadataChangedCount, missingCount, rejectedEntryCount))
      } else if (importedCount > 0 && failedCount === 0) {
        this.showToast(AppStrings.format('import_feedback_success', importedCount))
      } else if (importedCount > 0) {
        this.showToast(AppStrings.format('import_feedback_partial', importedCount, failedCount))
      } else if (failedCount > 0) {
        this.showToast(AppStrings.get('import_feedback_folder_unavailable'))
      } else if (checkedCount > 0 && (missingCount > 0 || rejectedEntryCount > 0)) {
        this.showToast(AppStrings.format('import_feedback_folder_rescan_missing', missingCount, rejectedEntryCount))
      } else if (checkedCount > 0) {
        this.showToast(AppStrings.get('import_feedback_folder_rescan_unchanged'))
      } else {
        this.showToast(AppStrings.get('import_feedback_folder_empty'))
      }
    } catch (error) {
      console.error('[Import] step=folder_import_failed code=folder_import_failed')
      this.showToast(AppStrings.get('import_feedback_folder_unavailable'))
    }
  }

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({
        startIcon: $r('sys.symbol.doc_plaintext'),
        content: AppStrings.get('import_archive_title'),
      })
      .onClick(() => {
        this.importMenuShown = false
        void this.startArchiveImport()
      })

      MenuItem({
        startIcon: $r('sys.symbol.picture'),
        content: AppStrings.get('import_image_title'),
      })
      .onClick(() => {
        this.importMenuShown = false
        void this.startImageImport()
      })

      MenuItem({
        startIcon: $r('sys.symbol.folder'),
        content: AppStrings.get('import_folder_title'),
      })
      .onClick(() => {
        this.importMenuShown = false
        void this.startFolderImport()
      })
    }
  }

  private openSettingsSecondary(routeName: string): void {
    this.appPathStack.pushPath({ name: routeName })
  }

  private openTrackerProvider(providerId: TrackerProviderId): void {
    const params: TrackerProviderRouteParam = { providerId }
    this.appPathStack.pushPath({ name: RouteName.TRACKER_PROVIDER_SETTINGS, param: params })
  }

  private openBackupTask(pane: string, fileName: string): void {
    const params: BackupTaskRouteParam = { pane, fileName }
    this.appPathStack.pushPath({ name: RouteName.BACKUP_TASK, param: params })
  }

  private backupTaskTitle(params: BackupTaskRouteParam): string {
    if (params.pane === 'create') { return AppStrings.get('backup_task_create') }
    if (params.pane === 'restore') { return AppStrings.get('backup_task_restore') }
    if (params.pane === 'files') { return AppStrings.get('backup_task_files') }
    return AppStrings.get('backup_task_settings')
  }

  private trackerProviderTitle(params: TrackerProviderRouteParam): string {
    const provider = TRACKER_PROVIDER_CONFIGS.find((item: TrackerProviderConfig): boolean => item.providerId === params.providerId)
    return provider?.displayName ?? AppStrings.get('route_tracker_settings_title')
  }

  private openSettingsPane(pane: SettingsPaneKey): void {
    const routeParam: SettingsPaneRouteParam = { pane: pane }
    this.appPathStack.pushPath({ name: RouteName.SETTINGS_PANE, param: routeParam })
  }

  private selectRootTab(index: number): void {
    this.leaveLibrarySelection(index)
    this.selectedTab = index
    this.tabController.changeIndex(index)
  }

  private leaveLibrarySelection(nextTab: number): void {
    if (this.selectedTab === TabIndex.LIBRARY && nextTab !== TabIndex.LIBRARY) {
      this.libraryTitleBar.cancelSelection()
    }
  }

  private settingsPaneFromParam(param: Object): SettingsPaneKey {
    const pane = (param as Record<string, string>)?.pane
    if (pane === 'appearance' ||
      pane === 'library' ||
      pane === 'reader' ||
      pane === 'services' ||
      pane === 'downloads' ||
      pane === 'tracking' ||
      pane === 'backup' ||
      pane === 'storage' ||
      pane === 'about') {
      return pane
    }
    return 'root'
  }

  private handleArchiveImportSucceeded(comic: Comic): void {
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      this.libraryStore.upsertComic(comic)
    } else {
      try {
        upsertComicAndPersistLibraryStore(this.libraryStore, persistenceService, comic)
      } catch (error) {
        console.error('[Library] step=persist_imported_comic_failed code=library_persist_failed')
        throw error as Error
      }
    }
    this.refreshLibrarySnapshot()
    this.selectRootTab(TabIndex.LIBRARY)
  }

  private handleLocalFolderImportSucceeded(scanResult: LocalLibraryFolderScanResult, rootUri: string): LocalFolderImportPersistResult {
    const persistenceService = this.ensureLibraryPersistenceService()
    let importedCount = 0
    let checkedCount = scanResult.series.length
    let addedCount = 0
    let changedCount = 0
    let missingCount = 0
    let metadataChangedCount = 0
    let rejectedEntryCount = 0
    if (persistenceService === undefined) {
      const comics = buildComicsFromLocalLibraryFolderScan(scanResult, rootUri)
      comics.forEach((comic: Comic) => {
        this.libraryStore.upsertComic(comic)
      })
      importedCount = comics.length
      rejectedEntryCount = scanResult.rejectedEntries.length
    } else {
      try {
        const previousKnownSeries = buildKnownLocalLibraryFolderSeriesFromComics(this.libraryStore.listComics(), rootUri)
        if (previousKnownSeries.length === 0) {
          importedCount = upsertLocalLibraryFolderScanAndPersistLibraryStore(
            this.libraryStore,
            persistenceService,
            scanResult,
            rootUri
          )
          rejectedEntryCount = scanResult.rejectedEntries.length
        } else {
          const result = upsertLocalLibraryFolderRescanAndPersistLibraryStore(
            this.libraryStore,
            persistenceService,
            previousKnownSeries,
            scanResult,
            rootUri
          )
          importedCount = result.upsertedCount
          checkedCount = result.summary.previousSeriesCount
          addedCount = result.summary.addedCount
          changedCount = result.summary.changedCount
          missingCount = result.summary.missingCount
          metadataChangedCount = result.summary.metadataChangedCount
          rejectedEntryCount = result.summary.rejectedEntryCount
          console.info('[Import] step=folder_rescan_persisted added=' + result.summary.addedCount +
            ' changed=' + result.summary.changedCount +
            ' metadata_changed=' + result.summary.metadataChangedCount +
            ' missing=' + result.summary.missingCount +
            ' rejected=' + result.summary.rejectedEntryCount +
            ' upserted=' + result.upsertedCount)
        }
      } catch (error) {
        console.error('[Library] step=persist_imported_folder_failed code=library_persist_failed')
        throw error as Error
      }
    }
    if (importedCount > 0) {
      this.refreshLibrarySnapshot()
      this.selectRootTab(TabIndex.LIBRARY)
    }
    return {
      importedCount,
      checkedCount,
      addedCount,
      changedCount,
      missingCount,
      metadataChangedCount,
      rejectedEntryCount,
    }
  }

  private handleRemoveComicRequested(comicId: ComicId): boolean {
    const requestedComic = this.libraryStore.getComic(comicId)
    const removable = isRemovableLocalComic(requestedComic)
    console.info(
      `[library-remove] requested found=${requestedComic !== undefined} removable=${removable}`
    )
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      if (!removable) {
        console.info('[library-remove] result removed=false persistence=unavailable')
        return false
      }
      this.libraryStore.removeComic(comicId)
      this.refreshLibrarySnapshot()
      this.cleanupRemovedComicDownloads(comicId)
      console.info('[library-remove] result removed=true persistence=unavailable')
      return true
    }
    try {
      if (removeComicAndPersistLibraryStore(this.libraryStore, persistenceService, comicId)) {
        this.refreshLibrarySnapshot()
        this.cleanupRemovedComicDownloads(comicId)
        console.info('[library-remove] result removed=true persistence=available')
        return true
      } else {
        console.info('[library-remove] result removed=false persistence=available')
        return false
      }
    } catch (error) {
      console.error('[Library] step=persist_removed_comic_failed code=library_persist_failed')
      throw error as Error
    }
  }

  private handleRemoveComicsRequested(comicIds: ComicId[]): number {
    const removableIds = comicIds.filter((comicId: ComicId): boolean => {
      return isRemovableLocalComic(this.libraryStore.getComic(comicId))
    })
    console.info(`[library-remove] batch_requested count=${comicIds.length} removable=${removableIds.length}`)
    if (removableIds.length === 0) {
      console.info('[library-remove] batch_result removed=0')
      return 0
    }
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      removableIds.forEach((comicId: ComicId) => {
        this.libraryStore.removeComic(comicId)
      })
      this.refreshLibrarySnapshot()
      removableIds.forEach((comicId: ComicId) => {
        this.cleanupRemovedComicDownloads(comicId)
      })
      console.info(`[library-remove] batch_result removed=${removableIds.length} persistence=unavailable`)
      return removableIds.length
    }
    try {
      const removedIds = removeComicsAndPersistLibraryStore(this.libraryStore, persistenceService, removableIds)
      if (removedIds.length > 0) {
        this.refreshLibrarySnapshot()
        removedIds.forEach((comicId: ComicId) => {
          this.cleanupRemovedComicDownloads(comicId)
        })
      }
      console.info(`[library-remove] batch_result removed=${removedIds.length} persistence=available`)
      return removedIds.length
    } catch (error) {
      console.error('[Library] step=persist_removed_comics_failed code=library_persist_failed')
      throw error as Error
    }
  }

  private cleanupRemovedComicDownloads(comicId: ComicId): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      void new OfflineDownloadQueueStore(context.filesDir).deleteComicDownloads(comicId)
        .then((removedCount: number) => {
          console.info(`[library-remove] downloads_cleanup removed=${removedCount}`)
        })
        .catch((_error: Error) => {
          console.warn('[library-remove] downloads_cleanup_failed reason=delete_downloads')
        })
    } catch (_error) {
      console.warn('[library-remove] downloads_cleanup_failed reason=context_unavailable')
    }
  }

  private handleAssignCategoriesRequested(comicIds: ComicId[], categoryIds?: string[]): boolean {
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      comicIds.forEach((comicId: ComicId) => {
        const comic = this.libraryStore.getComic(comicId)
        if (comic !== undefined) {
          this.libraryStore.upsertComic(withComicCategoryIds(comic, categoryIds))
        }
      })
      this.refreshLibrarySnapshot()
      return comicIds.length > 0
    }
    try {
      const changedCount = assignComicCategoriesAndPersistLibraryStore(
        this.libraryStore,
        persistenceService,
        comicIds,
        categoryIds
      )
      if (changedCount > 0) {
        this.refreshLibrarySnapshot()
      }
      return changedCount > 0
    } catch (error) {
      const e = error as Error
      console.error('[Library] step=persist_category_assignment_failed code=library_persist_failed')
      throw e
    }
  }

  private handleUpdateCategoryMembershipRequested(comicIds: ComicId[], categoryId: string, selected: boolean): boolean {
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      comicIds.forEach((comicId: ComicId) => {
        const comic = this.libraryStore.getComic(comicId)
        if (comic !== undefined) {
          this.libraryStore.upsertComic(
            selected ? withComicAddedCategoryId(comic, categoryId) : withComicRemovedCategoryId(comic, categoryId)
          )
        }
      })
      this.refreshLibrarySnapshot()
      return comicIds.length > 0
    }
    try {
      const changedCount = updateComicCategoryMembershipAndPersistLibraryStore(
        this.libraryStore,
        persistenceService,
        comicIds,
        categoryId,
        selected
      )
      if (changedCount > 0) {
        this.refreshLibrarySnapshot()
      }
      return changedCount > 0
    } catch (error) {
      const e = error as Error
      console.error('[Library] step=persist_category_membership_failed code=library_persist_failed')
      throw e
    }
  }

  private ensureLibraryPersistenceService(): LibraryStorePersistenceService | undefined {
    if (this.libraryPersistenceService !== undefined) {
      return this.libraryPersistenceService
    }
    const context = getContext(this) as common.UIAbilityContext
    if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
      return undefined
    }
    this.libraryPersistenceService = new LibraryStorePersistenceService(
      this.libraryStore,
      new AppFilesLibraryStorePersistenceAdapter(context.filesDir)
    )
    return this.libraryPersistenceService
  }

  private triggerAutomaticBackup(context: common.UIAbilityContext): void {
    if (this.automaticBackupChecked) {
      return
    }
    this.automaticBackupChecked = true
    void new BackupService(context).runAutomaticLocalBackupIfDue()
      .then((result: BackupAutomaticRunResult) => {
        if (result.ran) {
          console.info(`[Backup] step=app_open_auto_backup deleted=${result.deletedCount}`)
        } else if (result.failureCode !== undefined) {
          console.error(`[Backup] step=app_open_auto_backup_failed code=${result.failureCode}`)
        }
      })
      .catch((_error: Error) => {
        console.error('[Backup] step=app_open_auto_backup_failed code=backup_auto_export_failed')
      })
  }

  private triggerPendingTrackerProgressSync(context: common.UIAbilityContext): void {
    if (this.pendingTrackerProgressChecked) {
      return
    }
    this.pendingTrackerProgressChecked = true
    void new TrackerProgressSyncService(context).retryPendingProgress(10)
      .then((summary: TrackerPendingProgressDrainSummary) => {
        if (summary.scannedCount > 0) {
          console.info('[TrackerSync] step=app_open_pending_progress scanned=' + summary.scannedCount +
            ' synced=' + summary.syncedCount +
            ' retained=' + summary.retainedCount +
            ' failed=' + summary.failedCount +
            ' skipped=' + summary.skippedCount)
        }
      })
      .catch((_error: Error) => {
        console.warn('[TrackerSync] step=app_open_pending_progress status=failed reason=provider_failed')
      })
  }

  aboutToAppear(): void {
    this.handleReaderLabLaunch()
    RouterHelper.setAppPathStack(this.appPathStack)
    RouterHelper.setReaderOpener(() => {
      this.openExternalReaderSession()
    })
    RouterHelper.consumePendingLaunchRoute()
    const context = getContext(this) as common.UIAbilityContext
    if (!this.readerSessionPersistenceReady) {
      this.reloadReaderSessionStore('app_appear')
    }
    configureSourceSettingsStore(context)
    configureSourceFilterPreferencesStore(context)
    if (this.sourceRegistry.count() === 0) {
      bootstrapSourceRuntimeAppRegistry(context)
    }
    if (!this.libraryPersistenceRestored) {
      this.libraryPersistenceRestored = true
      const persistenceService = this.ensureLibraryPersistenceService()
      if (persistenceService !== undefined) {
        try {
          persistenceService.restore()
          this.refreshLibrarySnapshot()
        } catch (error) {
          void error
          console.error('[Library] step=restore_failed code=library_restore_failed')
        }
      }
    }
    setTimeout(() => {
      this.triggerAutomaticBackup(context)
      this.triggerPendingTrackerProgressSync(context)
    }, 250)
  }

  @Builder
  TabIcon(title: string, idx: number) {
    KomaTabIcon({
      title: title,
      idx: idx,
      currentIndex: this.selectedTab,
    })
  }

  @Builder
  private ReaderDestination() {
    HdsNavDestination() {
        ReaderPage({
          readerOpen: this.readerOpen!!,
        routeVisible: this.readerRouteVisible!!,
        sessionLoading: this.readerSessionLoading!!,
        closeRequestId: this.readerCloseRequestId!!,
        pageIndex: this.readerPageIndex!!,
        chromeVisible: this.readerChromeVisible!!,
        webtoonMode: this.readerWebtoonMode!!,
        sessionStore: this.readerSessionStore,
        sessionConfig: this.readerSessionConfig,
        onPageIndexChange: (value: number) => {
          this.readerPageIndex = value
        },
        onChromeVisibleChange: (value: boolean) => {
          this.readerChromeVisible = value
        },
        onWebtoonModeChange: (value: boolean) => {
          this.readerWebtoonMode = value
        },
        onCloseReader: () => {
          this.popReaderRouteAfterSystemBarRestore()
        },
        onOpenMangaDetail: () => {
          this.openReaderMangaDetail()
        },
        onOpenChapter: (chapterId: string) => {
          const sourceRequest = this.activeSourceReaderRequest
          if (sourceRequest !== undefined && sourceRequest.comicId === this.readerSessionConfig.comicId) {
            const nextRequest = sourceReaderSessionRequestForChapter(sourceRequest, chapterId)
            if (nextRequest !== undefined) {
              void this.openSourceReader(nextRequest)
            }
            return
          }
          if (this.readerSessionConfig.comicId.length > 0) {
            void this.openReader(this.readerSessionConfig.comicId, chapterId)
          }
        }
      })
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.closeReader()
      return true
    })
    .onShown(() => {
      this.readerRouteVisible = true
    })
    .onWillHide(() => {
      this.readerRouteVisible = false
    })
    .onWillDisappear(() => {
      this.readerRouteVisible = false
    })
    .onDisAppear(() => {
      // A detail route hides Reader but does not remove it. Cleanup only after
      // the genuine Reader pop has completed its native transition.
      this.finishReaderRouteClose()
    })
  }

  @Builder
  private SourceBrowseDestination(param: SourceBrowseRouteParam) {
    HdsNavDestination() {
      SourceBrowsePage({
        source: param.source,
        chrome: param.chrome,
        onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => {
          RouterHelper.pushSourceSearch({ source: source })
        },
        onMangaTap: (manga: SourceManga) => {
          RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
        },
      })
    }
    .onDisAppear(() => {
      this.disposeSourceBrowseFieldContent(param.chrome)
    })
    .titleBar(this.sourceBrowseTitleBarOpts(param))
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: false,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
    })
    .bindToScrollable([param.chrome.scroller])
  }

  @Builder
  private SourceSearchDestination(param: SourceSearchRouteParam) {
    HdsNavDestination() {
      SourceSearchPage({
        source: param.source,
        chrome: param.chrome,
        onMangaTap: (manga: SourceManga) => {
          RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
        },
      })
    }
    .titleBar(this.sourceSearchTitleBarOpts(param))
    .onDisAppear(() => {
      // A detail route only hides this destination. Dispose the cached title
      // field after the search route itself has genuinely left the stack.
      this.disposeSourceSearchFieldContent(param.chrome)
    })
  }

  @Builder
  private SearchDestination(param: SearchRouteParam) {
    HdsNavDestination() {
      SearchPage({
        chrome: RouterHelper.ensureSearchRouteChrome(param),
        libraryStore: this.libraryStore,
        libraryPersistenceService: this.ensureLibraryPersistenceService(),
        onLibraryChanged: () => {
          this.refreshLibrarySnapshot()
        },
        onOpenKomgaResult: (routeParam: KomgaSeriesRouteParam) => {
          this.appPathStack.pushPath({ name: RouteName.KOMGA_BROWSE, param: routeParam })
        },
        onOpenKavitaResult: (routeParam: KavitaBrowseRouteParam) => {
          this.appPathStack.pushPath({ name: RouteName.KAVITA_BROWSE, param: routeParam })
        },
        onOpenOpdsResult: (routeParam: OpdsBrowseRouteParam) => {
          this.appPathStack.pushPath({ name: RouteName.OPDS_BROWSE, param: routeParam })
        },
      })
    }
    .titleBar(this.searchTitleBarOpts(param))
    .onDisAppear(() => {
      this.disposeSearchFieldContent(RouterHelper.ensureSearchRouteChrome(param))
    })
  }

  @Builder
  private AppDestination(name: string, param: Object) {
    if (name === 'ReaderLab') {
      KomaReaderLabPage({ request: param as ReaderLabRequest,
        catalogHost: this.createReaderLabCatalogHost(),
        readInitialColumn: (work: string, unit: string): 'odd_left' | 'even_left' => {
          return this.readReaderLabInitialColumn(work, unit)
        }, readInitialPage: (work: string, unit: string): number => {
          return this.readReaderLabInitialPage(work, unit)
        }, persistObserved: (position: ReaderObservedPosition, column: 'odd_left' | 'even_left'): void => {
          this.persistReaderLabObserved(position, column)
        }, flushObserved: (): void => {
          if (this.readerSessionPersistenceReady) this.readerSessionStore.flush()
        }, onOpenMangaDetail: (work: string): void => {
          this.openLibraryMangaDetail(work)
        }, onClose: () => { this.appPathStack.pop() } })
    } else if (name === RouteName.READER) {
      this.ReaderDestination()
    } else if (name === RouteName.IMPORT) {
      HdsNavDestination() {
        ImportPage({
          onArchiveImportSucceeded: (comic: Comic) => {
            this.handleArchiveImportSucceeded(comic)
            this.appPathStack.pop(false)
          },
          onLocalImageImportSucceeded: (comic: Comic) => {
            this.handleArchiveImportSucceeded(comic)
            this.appPathStack.pop(false)
          },
          onLocalFolderImportSucceeded: (scanResult: LocalLibraryFolderScanResult, rootUri: string): LocalFolderImportPersistResult => {
            const result = this.handleLocalFolderImportSucceeded(scanResult, rootUri)
            if (result.importedCount > 0) {
              this.appPathStack.pop(false)
            }
            return result
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_import_title')))
    } else if (name === RouteName.SEARCH) {
      this.SearchDestination(param as SearchRouteParam)
    } else if (name === RouteName.MANGA_DETAIL) {
      HdsNavDestination() {
        MangaDetailPage({
          params: param as MangaDetailRouteParam,
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          readerSessionStore: this.readerSessionStore,
          readerProgressRevision: this.readerProgressRevision,
          onReadingStateChanged: () => { this.readerProgressRevision += 1 },
          sourceRegistry: this.sourceRegistry,
          chrome: RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam),
          onBack: () => {
            this.appPathStack.pop(this.isReaderDetailRouteVisible())
          },
          onOpenReader: (mangaId: string, chapterId?: string) => { void this.openReader(mangaId, chapterId) },
          onOpenSourceReader: (request: SourceReaderSessionRequest) => { void this.openSourceReader(request) },
          onOpenImportRequested: () => { this.openImport() },
          onLibraryChanged: () => { this.onMangaDetailLibraryChanged() }
        })
      }
      .titleBar(this.mangaDetailTitleBarOpts(param as MangaDetailRouteParam))
      .onShown(() => { this.readerProgressRevision += 1 })
    } else if (name === RouteName.SOURCE_BROWSE) {
      this.SourceBrowseDestination(param as SourceBrowseRouteParam)
    } else if (name === RouteName.SOURCE_SEARCH) {
      this.SourceSearchDestination(param as SourceSearchRouteParam)
    } else if (name === RouteName.KOMGA_BROWSE) {
      HdsNavDestination() {
        KomgaSeriesPage({
          params: param as KomgaSeriesRouteParam,
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_komga_title')))
    } else if (name === RouteName.KAVITA_BROWSE) {
      HdsNavDestination() {
        KavitaBrowsePage({
          params: param as KavitaBrowseRouteParam,
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          },
          onOpenReader: (comicId: string, chapterId?: string) => {
            void this.openReader(comicId, chapterId)
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_kavita_title')))
    } else if (name === RouteName.OPDS_BROWSE) {
      HdsNavDestination() {
        OpdsBrowsePage({
          params: param as OpdsBrowseRouteParam,
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_opds_title')))
    } else if (name === RouteName.WEBDAV_BROWSE) {
      HdsNavDestination() {
        WebDavBrowsePage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_webdav_title')))
    } else if (name === RouteName.KOMGA_SERVER) {
      HdsNavDestination() {
        KomgaServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_komga_title')))
    } else if (name === RouteName.KAVITA_SERVER) {
      HdsNavDestination() {
        KavitaServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_kavita_title')))
    } else if (name === RouteName.OPDS_SERVER) {
      HdsNavDestination() {
        OpdsServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_opds_title')))
    } else if (name === RouteName.WEBDAV_SERVER) {
      HdsNavDestination() {
        WebDavServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_webdav_title')))
    } else if (name === RouteName.SOURCE_PACKAGE_MANAGER) {
      HdsNavDestination() {
        SourcePackageManagerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_source_package_manager_title')))
    } else if (name === RouteName.SETTINGS_PANE) {
      HdsNavDestination() {
        SettingsPage({
          pane: this.settingsPaneFromParam(param),
          onLibraryPreferencesChanged: () => { this.libraryPreferencesRevision += 1 },
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          sourceRegistry: this.sourceRegistry,
          onOpenSettingsPane: (nextPane: SettingsPaneKey) => {
            this.openSettingsPane(nextPane)
          },
          onOpenKomgaSettings: () => {
            this.openSettingsSecondary(RouteName.KOMGA_SERVER)
          },
          onOpenKavitaSettings: () => {
            this.openSettingsSecondary(RouteName.KAVITA_SERVER)
          },
          onOpenOpdsSettings: () => {
            this.openSettingsSecondary(RouteName.OPDS_SERVER)
          },
          onOpenWebDavSettings: () => {
            this.openSettingsSecondary(RouteName.WEBDAV_SERVER)
          },
          onOpenSourcePackageManager: () => {
            this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER)
          },
          onOpenLibraryUpdateResults: () => {
            this.openSettingsSecondary(RouteName.LIBRARY_UPDATE_RESULTS)
          },
          onOpenLibraryCategories: () => {
            this.openSettingsSecondary(RouteName.LIBRARY_CATEGORIES)
          },
          onOpenDownloads: () => {
            this.openSettingsSecondary(RouteName.DOWNLOADS)
          },
          onOpenBackupManagement: () => {
            this.openSettingsSecondary(RouteName.BACKUP_MANAGEMENT)
          },
          onOpenTrackerSettings: () => {
            this.openSettingsSecondary(RouteName.TRACKER_SETTINGS)
          },
          onOpenImportRequested: () => {
            this.openImport()
          },
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(settingsPaneTitle(this.settingsPaneFromParam(param))))
    } else if (name === RouteName.LIBRARY_UPDATE_RESULTS) {
      HdsNavDestination() {
        LibraryUpdateResultPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_library_update_results_title')))
    } else if (name === RouteName.LIBRARY_CATEGORIES) {
      HdsNavDestination() {
        LibraryCategoryManagementPage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_library_categories_title')))
    } else if (name === RouteName.DOWNLOADS) {
      HdsNavDestination() {
        DownloadsPage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          sourceRegistry: this.sourceRegistry,
          onOpenReader: (comicId: ComicId, chapterId?: string) => {
            void this.openReader(comicId, chapterId)
          },
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_downloads_title')))
    } else if (name === RouteName.BACKUP_MANAGEMENT) {
      HdsNavDestination() {
        BackupManagementPage({ refreshRevision: this.backupSettingsRevision,
          onRestoreCompleted: () => { this.onBackupRestored() },
          onOpenTask: (pane: string, fileName: string) => { this.openBackupTask(pane, fileName) } })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_backup_management_title')))
      .onShown(() => { this.backupSettingsRevision += 1 })
    } else if (name === RouteName.BACKUP_TASK) {
      HdsNavDestination() {
        BackupManagementPage({ pane: (param as BackupTaskRouteParam).pane,
          localFileName: (param as BackupTaskRouteParam).fileName,
          refreshRevision: this.backupSettingsRevision,
          onRestoreCompleted: () => { this.onBackupRestored() },
          onOpenTask: (pane: string, fileName: string) => { this.openBackupTask(pane, fileName) } })
      }
      .titleBar(this.navDestTitleBarOpts(this.backupTaskTitle(param as BackupTaskRouteParam)))
      .onShown(() => { this.backupSettingsRevision += 1 })
    } else if (name === RouteName.TRACKER_SETTINGS) {
      HdsNavDestination() {
        TrackerSettingsPage({
          refreshRevision: this.trackerSettingsRevision,
          onOpenProvider: (providerId: TrackerProviderId) => {
            this.openTrackerProvider(providerId)
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_tracker_settings_title')))
      .onShown(() => {
        this.trackerSettingsRevision += 1
      })
    } else if (name === RouteName.TRACKER_PROVIDER_SETTINGS) {
      HdsNavDestination() {
        TrackerSettingsPage({ providerId: (param as TrackerProviderRouteParam).providerId })
      }
      .titleBar(this.navDestTitleBarOpts(this.trackerProviderTitle(param as TrackerProviderRouteParam)))
    }
  }

  onBackPress(): boolean {
    if (this.readerOpen && this.isReaderRouteVisible()) {
      this.closeReader()
      return true
    }
    if (this.appPathStack.getAllPathName().length === 0 && this.selectedTab === TabIndex.LIBRARY &&
      this.libraryTitleBar.selectionMode) {
      this.libraryTitleBar.cancelSelection()
      return true
    }
    return false
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.languageState.effectiveLocale.length >= 0) {
        HdsNavigation(this.appPathStack) {
          HdsTabs({ controller: this.tabController }) {
            TabContent() {
              LibraryPage({
                libraryStore: this.libraryStore,
                libraryPreferencesRevision: this.libraryPreferencesRevision,
                libraryComics: this.libraryComics,
                libraryRevision: this.libraryRevision,
                readerSessionStore: this.readerSessionStore,
                readerProgressRevision: this.readerProgressRevision,
                presentationByComicId: this.presentationByComicId,
                sourceRegistry: this.sourceRegistry,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onOpenMangaDetail: (comicId: ComicId) => {
                  this.openLibraryMangaDetail(comicId)
                },
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                },
                onProgressStoreReloadRequested: () => {
                  this.reloadReaderSessionStore('bootstrap_sync')
                },
                onImportRequested: () => {
                  this.openImport()
                },
                onSearchRequested: () => {
                  RouterHelper.openSearch({})
                },
                onOpenDownloadsRequested: () => {
                  this.openSettingsSecondary(RouteName.DOWNLOADS)
                },
                onTitleBarChange: (presentation: LibraryTitleBarPresentation) => {
                  this.libraryTitleBar = presentation
                },
                onRemoveComicRequested: (comicId: ComicId) => {
                  return this.handleRemoveComicRequested(comicId)
                },
                onRemoveComicsRequested: (comicIds: ComicId[]) => {
                  return this.handleRemoveComicsRequested(comicIds)
                },
                onAssignCategoriesRequested: (comicIds: ComicId[], categoryIds?: string[]) => {
                  return this.handleAssignCategoriesRequested(comicIds, categoryIds)
                },
                onUpdateCategoryMembershipRequested: (comicIds: ComicId[], categoryId: string, selected: boolean) => {
                  return this.handleUpdateCategoryMembershipRequested(comicIds, categoryId, selected)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.LIBRARY), TabIndex.LIBRARY))

            TabContent() {
              BrowsePage({
                sourceRegistry: this.sourceRegistry,
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onLibraryChanged: () => {
                  this.refreshLibrarySnapshot()
                  this.selectRootTab(TabIndex.LIBRARY)
                },
                onOpenReader: (comicId: string, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                },
                onOpenSourcePackageManager: () => {
                  this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER)
                },
                onOpenKomgaBrowse: () => {
                  this.appPathStack.pushPath({ name: RouteName.KOMGA_BROWSE })
                },
                onOpenKavitaBrowse: () => {
                  this.appPathStack.pushPath({ name: RouteName.KAVITA_BROWSE })
                },
                onOpenOpdsBrowse: () => {
                  this.appPathStack.pushPath({ name: RouteName.OPDS_BROWSE })
                },
                onOpenWebDavBrowse: () => {
                  this.appPathStack.pushPath({ name: RouteName.WEBDAV_BROWSE })
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.BROWSE), TabIndex.BROWSE))

            TabContent() {
              HistoryPage({
                libraryStore: this.libraryStore,
                active: this.selectedTab === TabIndex.HISTORY,
                readerSessionStore: this.readerSessionStore,
                readerProgressRevision: this.readerProgressRevision,
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                },
                onOpenSourceReader: (request: SourceReaderSessionRequest) => {
                  void this.openSourceReader(request)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.HISTORY), TabIndex.HISTORY))

            TabContent() {
              SettingsPage({
                pane: 'root',
                onLibraryPreferencesChanged: () => { this.libraryPreferencesRevision += 1 },
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                sourceRegistry: this.sourceRegistry,
                onOpenSettingsPane: (pane: SettingsPaneKey) => {
                  this.openSettingsPane(pane)
                },
                onOpenKomgaSettings: () => {
                  this.openSettingsSecondary(RouteName.KOMGA_SERVER)
                },
                onOpenKavitaSettings: () => {
                  this.openSettingsSecondary(RouteName.KAVITA_SERVER)
                },
                onOpenOpdsSettings: () => {
                  this.openSettingsSecondary(RouteName.OPDS_SERVER)
                },
                onOpenWebDavSettings: () => {
                  this.openSettingsSecondary(RouteName.WEBDAV_SERVER)
                },
                onOpenSourcePackageManager: () => {
                  this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER)
                },
                onOpenLibraryUpdateResults: () => {
                  this.openSettingsSecondary(RouteName.LIBRARY_UPDATE_RESULTS)
                },
                onOpenLibraryCategories: () => {
                  this.openSettingsSecondary(RouteName.LIBRARY_CATEGORIES)
                },
                onOpenDownloads: () => {
                  this.openSettingsSecondary(RouteName.DOWNLOADS)
                },
                onOpenBackupManagement: () => {
                  this.openSettingsSecondary(RouteName.BACKUP_MANAGEMENT)
                },
                onOpenTrackerSettings: () => {
                  this.openSettingsSecondary(RouteName.TRACKER_SETTINGS)
                },
                onOpenImportRequested: () => {
                  this.openImport()
                },
                onLibraryChanged: () => {
                  this.refreshLibrarySnapshot()
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.SETTINGS), TabIndex.SETTINGS))
          }
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .barMode(BarMode.Fixed)
          .scrollable(false)
          .animationDuration(0)
          .barFloatingStyle({
            barBottomMargin: ThemeConstants.SPACE_XL,
            adaptToHandedness: true,
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.ADAPTIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
            },
          } as HdsTabsFloatingStyle)
          .onChange((index: number) => {
            this.leaveLibrarySelection(index)
            this.selectedTab = index
          })
        }
        .titleBar(this.titleBarOptions())
        .titleMode(HdsNavigationTitleMode.MINI)
        .hideBackButton(this.selectedTab !== TabIndex.LIBRARY || !this.libraryTitleBar.selectionMode)
        .dynamicHideTitleBar({
          hideTitleArea: false,
          hideBottomBuilder: false,
          hideStatusBar: false,
          mode: HideMode.SCROLL_UP,
        })
        .navDestination(this.AppDestination)
        .mode(NavigationMode.Stack)
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }

      Row()
        .width(1)
        .height(1)
        .margin({ top: this.layoutSafeArea.topAvoidHeight + 48, right: ThemeConstants.SPACE_MD })
        .hitTestBehavior(HitTestMode.None)
        .bindMenu(this.importMenuShown, this.ImportMenu, {
          placement: Placement.BottomRight,
          onDisappear: () => {
            this.importMenuShown = false
          },
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': tabLabel(this.selectedTab) }
    let content: Record<string, Object> = { 'title': titleInfo }
    const menu: Record<string, Object> = {}
    if (this.selectedTab === TabIndex.LIBRARY) {
      if (this.libraryTitleBar.selectionMode) {
        titleInfo = {
          'mainTitle': AppStrings.get('library_selected_count').replace('%s', `${this.libraryTitleBar.selectedCount}`),
        }
        content['title'] = titleInfo
        const cancelContent: Record<string, Object> = {
          'label': AppStrings.get('common_cancel'),
          'icon': $r('sys.symbol.xmark'),
          'action': () => { this.libraryTitleBar.cancelSelection() },
        }
        content['backIcon'] = cancelContent
      }
      if (this.libraryTitleBar.batchDownloadBusy) {
        titleInfo = { 'mainTitle': AppStrings.get('library_download_enqueuing') }
        content['title'] = titleInfo
      }
      menu['value'] = this.libraryTitleBar.menuItems
      menu['maxCount'] = 3
    } else if (this.selectedTab === TabIndex.BROWSE) {
      const manageContent: Record<string, Object> = {
        'label': AppStrings.get('route_source_package_manager_title'),
        'icon': $r('sys.symbol.gearshape'),
        'isEnabled': true,
        'action': () => {
          this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER)
        },
      }
      const manageItem: Record<string, Object> = {}
      manageItem['content'] = manageContent
      menu['value'] = [manageItem]
      menu['maxCount'] = 1
    } else {
      // HDS retains the preceding title menu unless the next tab explicitly
      // supplies an empty menu. Global search belongs only to the Library root.
      menu['value'] = []
      menu['maxCount'] = 0
    }
    content['menu'] = menu
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }

  private sourceRouteTitleBarOpts(content: Record<string, Object>): Record<string, Object> {
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }

  private searchFieldContent(chrome: SearchRouteChromeState): ComponentContent<SearchRouteChromeState> {
    const existing = this.searchFieldContents.get(chrome)
    if (existing !== undefined && !existing.isDisposed()) {
      return existing
    }
    if (existing !== undefined) {
      this.searchFieldContents.delete(chrome)
    }
    const content = new ComponentContent<SearchRouteChromeState>(
      this.getUIContext(),
      wrapBuilder<[SearchRouteChromeState]>(SearchTitleFieldContentBuilder),
      chrome,
    )
    this.searchFieldContents.set(chrome, content)
    return content
  }

  private disposeSearchFieldContent(chrome: SearchRouteChromeState): void {
    const content = this.searchFieldContents.get(chrome)
    this.searchFieldContents.delete(chrome)
    if (content !== undefined && !content.isDisposed()) {
      content.dispose()
    }
  }

  private browseFieldContent(chrome: SourceBrowseRouteChromeState): ComponentContent<SourceBrowseRouteChromeState> {
    const existing = this.sourceBrowseFieldContents.get(chrome)
    if (existing !== undefined && !existing.isDisposed()) {
      return existing
    }
    if (existing !== undefined) {
      this.sourceBrowseFieldContents.delete(chrome)
    }
    const content = new ComponentContent<SourceBrowseRouteChromeState>(
      this.getUIContext(),
      wrapBuilder<[SourceBrowseRouteChromeState]>(SourceBrowseTitleFieldContentBuilder),
      chrome,
    )
    this.sourceBrowseFieldContents.set(chrome, content)
    return content
  }

  private disposeSourceBrowseFieldContent(chrome: SourceBrowseRouteChromeState): void {
    const content = this.sourceBrowseFieldContents.get(chrome)
    this.sourceBrowseFieldContents.delete(chrome)
    if (content !== undefined && !content.isDisposed()) {
      content.dispose()
    }
  }

  private searchTitleBarOpts(param: SearchRouteParam): Record<string, Object> {
    const chrome = RouterHelper.ensureSearchRouteChrome(param)
    const title: Record<string, Object> = {}
    title['mainTitle'] = AppStrings.get('tab_search')
    const bottomBuilder: Record<string, Object> = {}
    bottomBuilder['builderComponent'] = this.searchFieldContent(chrome)
    bottomBuilder['height'] = SEARCH_TITLE_BOTTOM_HEIGHT
    bottomBuilder['showType'] = BottomBuilderShowType.DIRECTLY_SHOW
    const filterContent: Record<string, Object> = {
      'label': AppStrings.get('search_filter_label'),
      'icon': $r('sys.symbol.funnel'),
      'isEnabled': true,
      'action': () => {
        chrome.requestFilters()
      },
    }
    const filterItem: Record<string, Object> = {}
    filterItem['content'] = filterContent
    const menu: Record<string, Object> = {}
    menu['value'] = [filterItem]
    menu['maxCount'] = 1
    const content: Record<string, Object> = {}
    content['title'] = title
    content['bottomBuilder'] = bottomBuilder
    content['menu'] = menu
    return this.sourceRouteTitleBarOpts(content)
  }

  private sourceBrowseTitleBarOpts(param: SourceBrowseRouteParam): Record<string, Object> {
    const source = param.source
    const chrome = param.chrome
    const title: Record<string, Object> = {}
    title['mainTitle'] = source.displayName
    const content: Record<string, Object> = {}
    content['title'] = title
    const bottomBuilder: Record<string, Object> = {}
    bottomBuilder['builderComponent'] = this.browseFieldContent(chrome)
    bottomBuilder['height'] = SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT
    bottomBuilder['showType'] = BottomBuilderShowType.DIRECTLY_SHOW
    content['bottomBuilder'] = bottomBuilder
    if (chrome.filtersAvailable) {
      const filterContent: Record<string, Object> = {}
      filterContent['label'] = AppStrings.get('common_filter')
      filterContent['icon'] = $r('sys.symbol.funnel')
      filterContent['isEnabled'] = true
      filterContent['action'] = () => {
        chrome.requestFilters()
      }
      const filterItem: Record<string, Object> = {}
      filterItem['content'] = filterContent
      const menu: Record<string, Object> = {}
      menu['value'] = [filterItem]
      menu['maxCount'] = 1
      content['menu'] = menu
    }
    return this.sourceRouteTitleBarOpts(content)
  }

  private sourceSearchFieldContent(chrome: SourceSearchRouteChromeState): ComponentContent<SourceSearchRouteChromeState> {
    const existing = this.sourceSearchFieldContents.get(chrome)
    if (existing !== undefined && !existing.isDisposed()) {
      return existing
    }
    if (existing !== undefined) {
      this.sourceSearchFieldContents.delete(chrome)
    }
    const content = new ComponentContent<SourceSearchRouteChromeState>(
      this.getUIContext(),
      wrapBuilder<[SourceSearchRouteChromeState]>(SourceSearchTitleFieldContentBuilder),
      chrome,
    )
    this.sourceSearchFieldContents.set(chrome, content)
    return content
  }

  private disposeSourceSearchFieldContent(chrome: SourceSearchRouteChromeState): void {
    const content = this.sourceSearchFieldContents.get(chrome)
    this.sourceSearchFieldContents.delete(chrome)
    if (content !== undefined && !content.isDisposed()) {
      content.dispose()
    }
  }

  private sourceSearchTitleBarOpts(param: SourceSearchRouteParam): Record<string, Object> {
    const source = param.source
    const chrome = param.chrome
    const title: Record<string, Object> = {}
    title['mainTitle'] = source.displayName.length > 0 ? source.displayName : AppStrings.get('tab_search')
    const bottomBuilder: Record<string, Object> = {}
    bottomBuilder['builderComponent'] = this.sourceSearchFieldContent(chrome)
    bottomBuilder['height'] = SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT
    bottomBuilder['showType'] = BottomBuilderShowType.DIRECTLY_SHOW
    const content: Record<string, Object> = {}
    content['title'] = title
    content['bottomBuilder'] = bottomBuilder
    if (chrome.filtersAvailable) {
      const filterContent: Record<string, Object> = {}
      filterContent['label'] = AppStrings.get('common_filter')
      filterContent['icon'] = $r('sys.symbol.funnel')
      filterContent['isEnabled'] = true
      filterContent['action'] = () => {
        chrome.requestFilters()
      }
      const filterItem: Record<string, Object> = {}
      filterItem['content'] = filterContent
      const menu: Record<string, Object> = {}
      menu['value'] = [filterItem]
      menu['maxCount'] = 1
      content['menu'] = menu
    }
    return this.sourceRouteTitleBarOpts(content)
  }

  private navDestTitleBarOpts(title?: string): Record<string, Object> {
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    let content: Record<string, Object> = {}
    if (title) {
      content['title'] = { 'mainTitle': title } as Record<string, Object>
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }

  private mangaDetailTitle(param: MangaDetailRouteParam): string {
    const initialTitle = param.initialManga?.title?.trim() ?? ''
    if (initialTitle.length > 0) {
      return initialTitle
    }
    const comic = this.libraryStore.getComic(param.mangaId)
    const comicTitle = comic?.title?.trim() ?? ''
    if (comicTitle.length > 0) {
      return comicTitle
    }
    return AppStrings.get('manga_detail_title_fallback')
  }

  private mangaDetailTitleBarOpts(param: MangaDetailRouteParam): Record<string, Object> {
    const chrome = RouterHelper.ensureMangaDetailRouteChrome(param)
    const title: Record<string, Object> = { 'mainTitle': this.mangaDetailTitle(param) }
    const content: Record<string, Object> = { 'title': title }
    if (!chrome.pageActionsAvailable) {
      return this.sourceRouteTitleBarOpts(content)
    }

    const menuItems: Record<string, Object>[] = []
    const trackerMappingContent: Record<string, Object> = {
      'label': AppStrings.get('manga_detail_menu_find_tracker_mapping'),
      'icon': $r('sys.symbol.magnifyingglass'),
      'isEnabled': !chrome.trackerMappingBusy,
      'action': () => {
        chrome.requestAction(MangaDetailTitleAction.FIND_TRACKER_MAPPING)
      },
    }
    menuItems.push({ 'content': trackerMappingContent })

    const trackerSyncContent: Record<string, Object> = {
      'label': AppStrings.get('manga_detail_menu_sync_tracker'),
      'icon': $r('sys.symbol.arrow_clockwise'),
      'isEnabled': !chrome.trackerSyncBusy,
      'action': () => {
        chrome.requestAction(MangaDetailTitleAction.SYNC_TRACKER)
      },
    }
    menuItems.push({ 'content': trackerSyncContent })

    const trackerPullContent: Record<string, Object> = {
      'label': AppStrings.get('manga_detail_menu_pull_tracker'),
      'icon': $r('sys.symbol.arrow_down_to_line'),
      'isEnabled': !chrome.trackerSyncBusy,
      'action': () => {
        chrome.requestAction(MangaDetailTitleAction.PULL_TRACKER)
      },
    }
    menuItems.push({ 'content': trackerPullContent })

    if (chrome.localRefreshAvailable) {
      const localRefreshContent: Record<string, Object> = {
        'label': chrome.localRefreshBusy
          ? AppStrings.get('manga_detail_local_refresh_checking')
          : AppStrings.get('manga_detail_menu_check_local_refresh'),
        'icon': $r('sys.symbol.arrow_clockwise'),
        'isEnabled': !chrome.localRefreshBusy,
        'action': () => {
          chrome.requestAction(MangaDetailTitleAction.CHECK_LOCAL_LIBRARY_REFRESH)
        },
      }
      menuItems.push({ 'content': localRefreshContent })
    }

    if (chrome.localMetadataAvailable) {
      const localMetadataContent: Record<string, Object> = {
        'label': AppStrings.get('manga_detail_menu_edit_local_metadata'),
        'icon': $r('sys.symbol.square_and_pencil'),
        'isEnabled': true,
        'action': () => {
          chrome.requestAction(MangaDetailTitleAction.EDIT_LOCAL_METADATA)
        },
      }
      menuItems.push({ 'content': localMetadataContent })
    }

    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 1 }
    content['menu'] = menu
    return this.sourceRouteTitleBarOpts(content)
  }

}
