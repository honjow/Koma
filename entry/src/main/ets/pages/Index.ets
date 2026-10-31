import { connectReaderDisplayPreview, ReaderDisplayPreviewState } from '../state/ReaderDisplayPreviewState'
import { ReaderBrightnessController } from '../model/ReaderBrightnessController'
import { connectReaderModeState, ReaderModeState } from '../state/ReaderModeState'
import { applyBackgroundLibraryResults, synchronizeBackgroundMaintenance } from '../model/BackgroundMaintenance'
import { appSourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { komaMenuOptions } from '../theme/KomaPopupOptions'
import { firstReaderChapter } from '../model/ReaderChapterSequence'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { OfflineDownloadService } from '../model/OfflineDownloadService'
import { AutomaticDownloadController } from '../model/AutomaticDownloadController'
import { ReadDownloadCleanup } from '../model/ReadDownloadCleanup'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { common } from '@kit.AbilityKit'
import { KomaReaderLabPage } from '../readerLab/KomaReaderLabPage'
import { KomaReaderCatalogHost } from '../readerLab/KomaReaderCatalogHost'
import { KomaReaderFailure } from '../readerLab/KomaReaderFailure'
import { SourceFailureDetails } from '../model/SourceRuntimeError'
import { KomaReaderBackend, connectKomaReaderBackendSelection } from '../state/KomaReaderBackendSelectionState'
import { ReaderLabLaunchState, ReaderLabRequest, connectReaderLabLaunch, ReaderRouteTransition } from '@reader-kit/ui'
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
import { ReadingStatisticsPage } from './ReadingStatisticsPage'
import { ReadingSessionRecorder, ReadingSessionRecord } from '../model/ReadingStatistics'
import { TrackerPreferencesStore } from '../model/TrackerModels'
import { RemoteReadHistoryEntry, copyRemoteReadHistoryEntry } from '../model/RemoteReaderSession'
import { SearchPage } from './SearchPage'
import { SEARCH_TITLE_BOTTOM_HEIGHT, SearchTitleFieldContentBuilder } from '../components/SearchTitleField'
import { SettingsPage, SettingsPaneKey, settingsPaneTitle } from './SettingsPage'
import { ImportPage, LocalFolderImportPersistResult } from './ImportPage'
import { LocalImportCoordinator } from '../import/LocalImportCoordinator'
import { LocalImportCommitService } from '../import/LocalImportCommitService'
import { ReaderPage } from './ReaderPage'
import { MangaDetailPage } from './MangaDetailPage'
import { MangaWebPage } from './MangaWebPage'
import { resolveSourceChapterList } from '../model/SourceChapterListResolver'
import {
  ReaderChapterDescriptor,
  ReaderChapterOpenIntent,
  cloneReaderChapterDescriptor,
  continuationChapterIds,
} from '../model/ReaderChapterSequence'
import { SourceBrowsePage } from './SourceBrowsePage'
import { SourceSearchPage } from './SourceSearchPage'
import { MangaMigrationPage } from './MangaMigrationPage'
import { MangaMigrationRouteParam } from '../common/RouterHelper'
import { SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT, SourceSearchTitleFieldContentBuilder } from '../components/SourceSearchTitleField'
import { SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT, SourceBrowseTitleFieldContentBuilder } from '../components/SourceBrowseTitleField'
import { KomgaSeriesPage, KomgaSeriesRouteParam } from './KomgaSeriesPage'
import { KavitaBrowsePage, KavitaBrowseRouteParam } from './KavitaBrowsePage'
import { OpdsBrowsePage, OpdsBrowseRouteParam } from './OpdsBrowsePage'
import { WebDavBrowsePage, WebDavBrowseRouteParam } from './WebDavBrowsePage'
import { LibraryUpdateResultPage } from './LibraryUpdateResultPage'
import { LibraryCategoryManagementPage } from './LibraryCategoryManagementPage'
import { KomgaServerPage } from './KomgaServerPage'
import { KavitaServerPage } from './KavitaServerPage'
import { OpdsServerPage } from './OpdsServerPage'
import { SourcePackageManagerPage } from './SourcePackageManagerPage'
import { WebDavServerPage } from './WebDavServerPage'
import { DownloadsPage } from './DownloadsPage'
import { BackupManagementPage } from './BackupManagementPage'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { TrackerSettingsPage } from './TrackerSettingsPage'
import { RouteName, TabIndex, tabLabel } from '../common/Constants'
import { MangaDetailTitleAction } from '../state/MangaDetailRouteChromeState'
import {
  MangaDetailRouteParam,
  MangaWebRouteParam,
  RouterHelper,
  SearchRouteParam,
  SourceBrowseRouteParam,
  SourcePackageManagerRouteParam,
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
  ReadingProgress,
  withComicAddedCategoryId,
  withComicCategoryIds,
  withComicRemovedCategoryId,
} from '../model/ComicModels'
import {
  LocalLibraryFolderScanResult,
  buildKnownLocalLibraryFolderSeriesFromComics,
  buildComicsFromLocalLibraryFolderScan,
  localLibraryFolderRootUriFromComic,
  localLibraryFolderRootUrisFromComics,
  bindLocalLibraryFolderScanIdentity,
} from '../model/LocalLibraryFolderContract'
import {
  activateLocalLibraryFolderAccess,
  activateLocalLibraryFolderAccessForComics,
  canImportLocalLibraryFolder,
} from '../model/LocalLibraryFolderAccessService'
import { LocalLibraryFolderRescanActionResult } from '../model/LocalLibraryRefreshService'
import { LibraryCategoryDisplayStrategy, LibraryStore } from '../model/LibraryStore'
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
} from '../model/ReaderSessionStore'
import { createReaderOfflineMissingUri } from '../model/ReaderPageSourceAdapter'
import { SourceChapterPageHydrator, resolveSourceChapterPages, sourceChapterPagesMatchSettings } from '../model/SourceChapterPageHydrator'
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
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import { openSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { normalizeSourceHomepage } from '../sourceRuntime/SourcePackageMetadata'
import { configureSourceFilterPreferencesStore } from '../sourceRuntime/SourceFilterPreferencesStore'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { BackupService, BackupAutomaticRunResult } from '../model/BackupService'
import { TrackerPendingProgressDrainSummary, TrackerProgressSyncService } from '../model/TrackerProgressSyncService'
import { ReaderTrackerProgressCoordinator } from '../model/TrackerReadingProgress'
import { TRACKER_PROVIDER_CONFIGS, TrackerProviderConfig, TrackerProviderId } from '../model/TrackerModels'
import { SourceBrowseRouteChromeState, SourceSearchRouteChromeState } from '../state/SourceRouteChromeState'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'
import { AppForegroundState, connectAppForegroundState } from '../state/AppForegroundState'
import { shouldSuppressKomaDeviceVerificationBackgroundSideEffects } from '../state/KomaDeviceVerificationIsolation'
import { LibraryUpdateState, connectLibraryUpdateState } from '../state/LibraryUpdateState'
import { requestLibraryUpdateCheck } from '../model/LibraryUpdateCoordinator'

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
  @Local private enhancementModelsRevision: number = 0

  @Local private tabIconBounceTriggers: number[] = [-1, -1, -1, -1]
  @Local private readerLabLaunch: ReaderLabLaunchState = connectReaderLabLaunch()
  @Local private readerRouteBackend: KomaReaderBackend = KomaReaderBackend.SHARED
  @Local private sharedReaderRequest: ReaderLabRequest = new ReaderLabRequest('', '', 0)
  private sharedReaderCatalogHost: KomaReaderCatalogHost | null = null
  private readerPreparation: Promise<void> | null = null
  @Local private readerRouteTransition: ReaderRouteTransition = new ReaderRouteTransition()

  private captureSharedReaderEntry(newRoute: boolean): void {
    if (newRoute) {
      this.readerRouteBackend = connectKomaReaderBackendSelection().current(false)
      if (this.readerRouteBackend === KomaReaderBackend.SHARED) this.readerRouteTransition.begin()
      else this.readerRouteTransition.skip()
    }
    const config = this.readerSessionConfig
    const request = new ReaderLabRequest(config.comicId, config.chapterId, this.readerPageIndex)
    request.readingChrome = true
    request.progressReadWrite = true
    request.preferencesReadWrite = true
    this.sharedReaderCatalogHost = this.createReaderLabCatalogHost(true)
    this.sharedReaderRequest = request
  }


  @Monitor('readerLabLaunch.version')
  private handleReaderLabLaunch(): void {
    const request = this.readerLabLaunch.consume()
    if (request !== null) this.appPathStack.pushPath({ name: 'ReaderLab', param: request })
  }
  @Local selectedTab: number = TabIndex.LIBRARY
  @Local private rootNavigationVisible: boolean = true
  @Local private importMenuShown: boolean = false
  @Local private trackerSettingsRevision: number = 0
  @Local private applicationSettingsRestoreRevision: number = 0
  @Local private backupSettingsRevision: number = 0
  @Local private libraryPreferencesRevision: number = 0
  @Local private categoryDisplayStrategyChange?: LibraryCategoryDisplayStrategy = undefined
  @Local private libraryTitleBar: LibraryTitleBarPresentation = {
    selectionMode: false,
    batchDownloadBusy: false,
    selectedCount: 0,
    menuItems: [],
    cancelSelection: () => {},
  }
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private appForegroundState: AppForegroundState = connectAppForegroundState()
  @Local private libraryUpdateState: LibraryUpdateState = connectLibraryUpdateState()
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
  private rootTabScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller()]
  @Local private titleScroller: Scroller = this.rootTabScrollers[TabIndex.LIBRARY]
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
  private libraryUpdateReady: boolean = false
  private automaticDownloads?: AutomaticDownloadController
  private readDownloadCleanup?: ReadDownloadCleanup
  private cleanupProgressCommitted: boolean = false
  private automaticBackupPending: boolean = false
  private pendingTrackerProgressChecked: boolean = false
  private readerOpenEpoch: number = 0
  /**
   * RDR-004-B one-shot chapter open intent. It is runtime-only state: it never
   * enters ReaderSessionConfig, LibraryPersistence or any backup schema. The
   * open entry points set it, the terminal session publication consumes it, and
   * 'start'/'end' are only ever produced by a chapter-edge crossing.
   */
  private readerOpenIntent: ReaderChapterOpenIntent = 'resume'
  /**
   * Landing hint for the crossed-into chapter: 'end' asks a continuous session
   * to align the last image's bottom. It follows the same session publication
   * as readerOpenIntent and is recomputed by every open (no reset needed).
   */
  private readerOpenAlign: 'start' | 'end' = 'start'
  /** Present only while Reader was launched from an un-shelved source item. */
  private activeSourceReaderRequest?: SourceReaderSessionRequest
  /** Kavita read snapshot; favorite state remains owned by LibraryStore. */
  private activeKavitaReaderComic?: Comic

  private readerComicForOpen(comicId: ComicId): Comic | undefined {
    if (this.activeKavitaReaderComic?.id === comicId) return this.activeKavitaReaderComic
    return this.libraryStore.getComic(comicId)
  }

  private readerTrackerProgress?: ReaderTrackerProgressCoordinator
  private readerBrightness: ReaderBrightnessController = new ReaderBrightnessController()
  @Local private displayPreview: ReaderDisplayPreviewState = connectReaderDisplayPreview()
  @Local private displayReaderMode: ReaderModeState = connectReaderModeState()

  @Monitor('readerOpen', 'readerRouteVisible', 'appForegroundState.active', 'displayReaderMode.revision', 'displayPreview.settings')
  private syncReaderBrightness(): void {
    this.readerBrightness.update(this.getUIContext().getHostContext() as common.UIAbilityContext,
      this.readerOpen && this.readerRouteVisible && this.appForegroundState.active,
      this.displayPreview.settings ?? this.displayReaderMode.displaySettings)
  }

  private readingStatisticsRecorder: ReadingSessionRecorder = new ReadingSessionRecorder((record: ReadingSessionRecord): void => {
    if (this.readerSessionPersistenceReady) this.readerSessionStore.addReadingSession(record)
  })

  @Monitor('readerRouteVisible', 'readerOpen', 'readerSessionLoading', 'appForegroundState.active')
  private syncReadingSessionActivity(): void {
    const active = this.readerSessionPersistenceReady && this.readerOpen && this.readerRouteVisible &&
      !this.readerSessionLoading && this.appForegroundState.active
    this.readingStatisticsRecorder.setActive(active)
    if (!active && this.readerSessionPersistenceReady) this.readerSessionStore.flush()
  }

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

  @Monitor('libraryUpdateState.revision')
  private refreshLibrarySnapshot(): void {
    this.libraryComics = this.libraryStore.listComics()
    this.libraryRevision += 1
    this.resumeAutomaticDownloadQueue()
  }

  private cleanupService(): ReadDownloadCleanup {
    if (this.readDownloadCleanup === undefined) {
      this.readDownloadCleanup = new ReadDownloadCleanup((getContext(this) as common.UIAbilityContext).filesDir)
    }
    return this.readDownloadCleanup
  }

  private resumeAutomaticDownloadQueue(): void {
    if (!this.libraryUpdateReady || shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) return
    if (this.automaticDownloads === undefined) {
      this.automaticDownloads = new AutomaticDownloadController({ context: getContext(this) as common.UIAbilityContext,
        library: this.libraryStore, registry: this.sourceRegistry, persistence: this.libraryPersistenceService,
        onLibraryChanged: () => { this.refreshLibrarySnapshot() } })
    }
    this.automaticDownloads.wake()
  }

  @Monitor('appForegroundState.revision')
  private runForegroundLibraryUpdate(): void {
    if (!this.libraryUpdateReady || !this.appForegroundState.active ||
      shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) {
      return
    }
    this.resumeAutomaticDownloadQueue()
    const context = getContext(this) as common.UIAbilityContext
    void (this.libraryUpdateState.busy ? Promise.resolve() :
      applyBackgroundLibraryResults(context, this.libraryStore, this.libraryPersistenceService)).then(() => requestLibraryUpdateCheck({
      context,
      libraryStore: this.libraryStore,
      sourceRegistry: this.sourceRegistry,
      libraryPersistenceService: this.libraryPersistenceService,
      reason: 'due',
      requireForeground: true,
    })).then((result) => {
      console.info('[LibraryUpdate] step=foreground_check status=' + result.status)
    }).catch((_error: Error) => {
      DiagnosticLogger.warn('index', 'foreground_check_failed', '[LibraryUpdate] step=foreground_check_failed')
    })
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
    if (progress !== undefined && (comic.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId) ||
      (comic.sourceRuntimeId !== undefined && comic.sourceRuntimeId.trim().length > 0))) {
      return progress.chapterId
    }
    const firstChapter = firstReaderChapter(comic.chapters, sourceChapterOrderFor(comic.sourceRuntimeId),
      (id: string): boolean => this.readerSessionStore.isChapterRead(comic.id, id))
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
    // Keep valid plans cache-first. A changed source preference must reach
    // get_pages again; existing image files and downloaded chapters stay intact.
    return chapter !== undefined && !sourceChapterPagesMatchSettings(chapter, comic.sourceRuntimeId)
  }

  private logReaderSourcePagesUnavailable(reasonCode?: string): void {
    if (reasonCode === 'pages_missing' ||
      reasonCode === 'chapter_missing' ||
      reasonCode === 'source_missing' ||
      reasonCode === 'source_not_installed' ||
      reasonCode === 'source_lookup_failed' ||
      reasonCode === 'source_disabled' ||
      reasonCode === 'source_pages_failed') {
      DiagnosticLogger.warn('index', 'open_source_pages_unavailable', `[Reader] step=open_source_pages_unavailable failed=true reason=${reasonCode}`)
      return
    }
    DiagnosticLogger.warn('index', 'open_source_pages_unavailable', '[Reader] step=open_source_pages_unavailable failed=true reason=source_pages_unavailable')
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
      DiagnosticLogger.warn('index', 'open_manifest_probe', '[ReaderOffline] step=open_manifest_probe failed=true reason=manifest_session')
      return false
    }
  }

  private async ensureReaderSourceChapterPages(comic: Comic, chapterId: string | undefined,
    onSourceFailure?: (reason: string | undefined, details?: SourceFailureDetails) => void,
    forceRefresh: boolean = false): Promise<boolean> {
    if (!forceRefresh && !this.chapterNeedsReaderSourcePages(comic, chapterId)) {
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
      ).ensureChapterPages(comic.id, comic.sourceRuntimeId, chapterId as string, forceRefresh)
      if (!result.hydrated) {
        onSourceFailure?.(result.sourceFailureReason, result.sourceFailure)
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
    const originalComic = this.readerComicForOpen(comicId)
    if (originalComic === undefined) {
      if (openEpoch === this.readerOpenEpoch) {
        this.readerSessionLoading = false
      }
      return
    }
    if (originalComic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
      const rootUri = localLibraryFolderRootUriFromComic(originalComic)
      if (rootUri !== undefined) {
        const access = await activateLocalLibraryFolderAccess(rootUri)
        console.info('[LocalFolderAccess] step=reader_activate status=' + access.status)
      }
    }
    const offlineReaderPagesReady = this.hasAvailableOfflineReaderPages(originalComic.id, chapterId)
    let sourcePagesReady = true
    let sourceFailureReason: string | undefined = undefined
    let sourceFailure: SourceFailureDetails | undefined = undefined
    if (!offlineReaderPagesReady) {
      sourcePagesReady = await this.ensureReaderSourceChapterPages(originalComic, chapterId,
        (reason: string | undefined, details?: SourceFailureDetails): void => { sourceFailureReason = reason; sourceFailure = details })
    }
    const comic = this.readerComicForOpen(comicId) ?? originalComic
    if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) {
      return
    }
    let nextSessionConfig = this.createReaderSessionConfigForOpen(comic, chapterId)
    if (!sourcePagesReady && nextSessionConfig.totalPages <= 0) {
      nextSessionConfig = this.createSourceUnavailableReaderSessionConfig(comic, chapterId, nextSessionConfig, sourceFailureReason, sourceFailure)
    }
    this.readerSessionConfig = nextSessionConfig
    this.readerPageIndex = this.readerSessionStore.openPageIndex(nextSessionConfig, this.readerOpenIntent)
    // Terminal publication: the one-shot crossing intent has been consumed.
    this.readerOpenIntent = 'resume'
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
      pageTextPages: pages.map((page: Page) => page.sourceText),
      pageTextRequests: pages.map((page: Page) => page.sourceTextRequest),
      sourceRuntimeId: request.sourceId,
      sourceMangaUrl: request.mangaUrl,
    }
  }

  private createUnavailableSourceReaderSessionConfig(request: SourceReaderSessionRequest,
    sourceFailureReason?: string, sourceFailure?: SourceFailureDetails): ReaderSessionConfig {
    const config = this.createSourceReaderSessionConfig(request, [])
    config.totalPages = 1
    config.pageUris = ['source-placeholder://chapter']
    config.pageIds = [`${request.chapterId}:source-unavailable`]
    config.pageWidths = [undefined]
    config.pageHeights = [undefined]
    config.sourceFailureReason = sourceFailureReason
    config.sourceFailure = sourceFailure
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
          const catalog = await resolveSourceChapterList(lookup.entry, request.mangaId, request.mangaUrl,
            (): boolean => openEpoch === this.readerOpenEpoch && this.readerOpen && !this.readerClosing)
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
        DiagnosticLogger.warn('index', 'chapter', '[ReaderSource] chapter catalog unresolved')
      }
    }
    // Do not share the library hydrator's result here. Source hosts may issue
    // short-lived descriptors; a transient Reader open always resolves pages
    // afresh and never writes them to LibraryStore.
    const resolution = await resolveSourceChapterPages(this.sourceRegistry, {
      comicId: request.comicId,
      sourceId: request.sourceId,
      mangaId: request.mangaId,
      mangaUrl: request.mangaUrl,
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
      const unavailableConfig = this.createUnavailableSourceReaderSessionConfig(preparedRequest, resolution.sourceFailureReason, resolution.sourceFailure)
      this.readerSessionConfig = unavailableConfig
      // An unavailable placeholder has no real pages: an 'end' intent must not
      // be consumed as a successful landing (openPageIndex returns 0 there).
      this.readerPageIndex = this.readerSessionStore.openPageIndex(unavailableConfig, this.readerOpenIntent)
      this.readerSessionLoading = false
      return
    }
    const nextSessionConfig = this.createSourceReaderSessionConfig(preparedRequest, resolution.pages)
    this.readerSessionConfig = nextSessionConfig
    this.readerPageIndex = this.readerSessionStore.openPageIndex(nextSessionConfig, this.readerOpenIntent)
    // Terminal publication for the transient source session.
    this.readerOpenIntent = 'resume'
    // Persist only stable identity/title/cover/current-chapter metadata. Page
    // descriptors intentionally stay in the route-local Reader config.
    this.readerSessionStore.saveSourceHistory(sourceReadHistoryEntryFromRequest(preparedRequest))
    this.readerSessionStore.flush()
    this.readerSessionLoading = false
  }

  private readerLabInitialConfig(work: string, unit: string): ReaderSessionConfig | null {
    if (this.readerSessionConfig.comicId === work && this.readerSessionConfig.chapterId === unit &&
      this.readerSessionConfig.totalPages > 0) return cloneReaderSessionConfig(this.readerSessionConfig)
    const comic = this.readerComicForOpen(work)
    if (comic === undefined) return null
    const config = this.createReaderSessionConfigForOpen(comic, unit)
    return config.chapterId === unit && config.totalPages > 0 ? config : null
  }

  private async prepareReaderLabCatalog(target: ReaderUnitKey,
    cancellation: ReaderCancellation, forceRefresh: boolean = false): Promise<ReaderSessionConfig | null> {
    if (target.scope !== 'koma-local') return null
    const sourceRequest = this.activeSourceReaderRequest
    if (sourceRequest !== undefined && sourceRequest.comicId === target.work) {
      const nextRequest = sourceReaderSessionRequestForChapter(sourceRequest, target.unit)
      if (nextRequest === undefined) return null
      if (!forceRefresh && sourceRequest.chapterId === target.unit &&
        this.readerSessionConfig.comicId === target.work && this.readerSessionConfig.chapterId === target.unit &&
        this.readerSessionConfig.totalPages > 0 &&
        this.readerSessionConfig.pageUris.length === this.readerSessionConfig.totalPages &&
        !this.readerSessionConfig.pageUris.includes('source-placeholder://chapter')) {
        // The normal source open already resolved this exact current chapter.
        // Reuse that immutable route snapshot instead of issuing a second
        // provider request before the shared surface can display it.
        return cloneReaderSessionConfig(this.readerSessionConfig)
      }
      const resolution = await resolveSourceChapterPages(this.sourceRegistry, {
        comicId: nextRequest.comicId,
        sourceId: nextRequest.sourceId,
        mangaId: nextRequest.mangaId,
        mangaUrl: nextRequest.mangaUrl,
        chapterId: nextRequest.chapterId,
      })
      cancellation.check()
      // A chapter handoff is prepared beside the still-readable shared session.
      // Do not turn a provider failure into a committed placeholder unit: reject
      // the handoff so the current chapter stays visible and can be retried.
      if (resolution.pages.length === 0) throw KomaReaderFailure.sourceError(resolution.sourceFailureReason, resolution.sourceFailure)
      return this.createSourceReaderSessionConfig(nextRequest, resolution.pages)
    }
    let original = this.readerComicForOpen(target.work)
    if (original === undefined) return null
    if (original.sourceRuntimeId !== undefined &&
      !original.chapters.some((chapter: Chapter): boolean => chapter.id === target.unit)) {
      await new SourceChapterPageHydrator(this.libraryStore, this.sourceRegistry,
        this.ensureLibraryPersistenceService()).ensureChapterDescriptor(target.work, target.unit,
          (): boolean => !cancellation.isCancelled() && this.readerOpen && !this.readerClosing)
      cancellation.check()
      original = this.readerComicForOpen(target.work) ?? original
    }
    // Keep local-folder permission activation in the adapter's established path.
    if (original.sourceKind === ComicSourceKind.LOCAL_FOLDER) return null
    const offlineReady = this.hasAvailableOfflineReaderPages(original.id, target.unit)
    let sourceFailureReason: string | undefined = undefined
    let sourceFailure: SourceFailureDetails | undefined = undefined
    if (!offlineReady) {
      const hydrated = await this.ensureReaderSourceChapterPages(original, target.unit,
        (reason: string | undefined, details?: SourceFailureDetails): void => { sourceFailureReason = reason; sourceFailure = details },
        forceRefresh)
      // A failed explicit refresh must not silently reuse the same stale page plan.
      if (forceRefresh && !hydrated) throw KomaReaderFailure.sourceError(sourceFailureReason, sourceFailure)
    }
    cancellation.check()
    const comic = this.readerComicForOpen(target.work) ?? original
    cancellation.check()
    const config = this.createReaderSessionConfigForOpen(comic, target.unit)
    if (config.totalPages > 0) return config
    if (this.chapterNeedsReaderSourcePages(comic, target.unit)) {
      throw KomaReaderFailure.sourceError(sourceFailureReason, sourceFailure)
    }
    return null
  }

  /** Legacy libraries acquire source ordinals in the background, never by
   * reversing their possibly merged stored array or delaying the cached page. */
  private async prepareReaderLabSequence(target: ReaderUnitKey,
    cancellation: ReaderCancellation): Promise<string[] | undefined> {
    const epoch = this.readerOpenEpoch
    const isCurrent = (): boolean => !cancellation.isCancelled() && epoch === this.readerOpenEpoch &&
      this.readerOpen && !this.readerClosing
    const source = this.activeSourceReaderRequest
    if (source !== undefined && source.comicId === target.work) {
      const lookup = this.sourceRegistry.lookup(source.sourceId)
      if (!lookup.ok || lookup.entry === undefined || !sourceRuntimeEntryEnabled(lookup.entry)) return undefined
      const sourceCurrent = (): boolean => isCurrent() && this.sourceRegistry.lookup(source.sourceId).entry === lookup.entry
      const catalog = await resolveSourceChapterList(lookup.entry, source.mangaId, source.mangaUrl, sourceCurrent)
      cancellation.check()
      if (!catalog.resolved || !sourceCurrent()) return undefined
      const active = this.activeSourceReaderRequest
      if (active === undefined || active.comicId !== source.comicId || active.sourceId !== source.sourceId ||
        active.mangaId !== source.mangaId) return undefined
      const updated = cloneSourceReaderSessionRequest(active)
      updated.chapters = catalog.chapters.map((chapter: ReaderChapterDescriptor): ReaderChapterDescriptor =>
        cloneReaderChapterDescriptor(chapter))
      updated.chapterIds = catalog.chapters.map((chapter: ReaderChapterDescriptor): string => chapter.id)
      updated.chapterTitles = catalog.chapters.map((chapter: ReaderChapterDescriptor): string => chapter.title)
      updated.chaptersResolved = true
      this.activeSourceReaderRequest = updated
      return continuationChapterIds(catalog.chapters, target.unit)
    }
    return new SourceChapterPageHydrator(this.libraryStore, this.sourceRegistry,
      this.ensureLibraryPersistenceService()).resolveChapterSequence(target.work, target.unit, isCurrent)
  }

  private createReaderLabCatalogHost(production: boolean = false): KomaReaderCatalogHost {
    // The root already attempted this shelf chapter before publishing the
    // shared entry. Consume that terminal failure once for shelf and transient
    // source opens; only an explicit catalog retry asks the provider again.
    const initialConfig = this.readerSessionConfig
    let initialFailurePending = initialConfig.totalPages === 1 && initialConfig.pageUris.length === 1 &&
      initialConfig.pageUris[0] === 'source-placeholder://chapter'
    const initialWork = initialConfig.comicId
    const initialUnit = initialConfig.chapterId
    const openEpoch = this.readerOpenEpoch
    let initialProductionPending = production
    return new KomaReaderCatalogHost(
      (work: string, unit: string): ReaderSessionConfig | null => this.readerLabInitialConfig(work, unit),
      async (target: ReaderUnitKey, cancellation: ReaderCancellation, forceRefresh: boolean): Promise<ReaderSessionConfig | null> => {
        if (forceRefresh) return this.prepareReaderLabCatalog(target, cancellation, true)
        if (initialProductionPending && target.work === initialWork && target.unit === initialUnit) {
          initialProductionPending = false
          await this.readerPreparation
          cancellation.check()
          if (openEpoch !== this.readerOpenEpoch || !this.readerOpen) throw new Error('closed_koma_reader')
          const prepared = this.readerSessionConfig
          initialFailurePending = false
          if (prepared.pageUris.includes('source-placeholder://chapter')) {
            throw KomaReaderFailure.sourceError(prepared.sourceFailureReason, prepared.sourceFailure)
          }
          const ready = this.readerLabInitialConfig(target.work, target.unit)
          if (ready !== null) return ready
        }
        const consumeInitialFailure = initialFailurePending &&
          target.work === initialWork && target.unit === initialUnit
        initialFailurePending = false
        if (consumeInitialFailure) throw KomaReaderFailure.sourceError(initialConfig.sourceFailureReason, initialConfig.sourceFailure)
        return this.prepareReaderLabCatalog(target, cancellation)
      },
      (target: ReaderUnitKey, config: ReaderSessionConfig): void => this.commitReaderLabCatalog(target, config),
      (target: ReaderUnitKey, cancellation: ReaderCancellation): Promise<string[] | undefined> =>
        this.prepareReaderLabSequence(target, cancellation),
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
    if (sourceRequest.chapterId === committedRequest.chapterId &&
      this.readerSessionStore.getSourceHistory(target.work)?.chapterId === target.unit) return
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
    return comic.sourceKind === ComicSourceKind.LOCAL_FOLDER ||
      comic.sourceKind === ComicSourceKind.KOMGA_REMOTE ||
      comic.sourceKind === ComicSourceKind.KAVITA_REMOTE ||
      comic.sourceKind === ComicSourceKind.OPDS_REMOTE ||
      comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE
  }

  private async openReader(
    comicId: ComicId,
    chapterId?: string,
    intent: ReaderChapterOpenIntent = 'resume',
    kavitaComic?: Comic,
  ): Promise<void> {
    if (kavitaComic !== undefined) this.activeKavitaReaderComic = kavitaComic
    else if (this.activeKavitaReaderComic?.id !== comicId) this.activeKavitaReaderComic = undefined
    this.readerOpenIntent = intent
    this.readerOpenAlign = intent === 'end' ? 'end' : 'start'
    let comic = this.readerComicForOpen(comicId)
    const targetChapterId = comic === undefined ? chapterId : this.readerChapterIdForOpen(comic, chapterId)
    const remoteHistory = this.readerSessionStore.getRemoteHistory(comicId)
    if (comic?.sourceKind === ComicSourceKind.KAVITA_REMOTE && remoteHistory?.kind === 'kavita' && targetChapterId !== undefined) {
      remoteHistory.chapterId = targetChapterId
      remoteHistory.chapterTitle = comic.chapters.find((item: Chapter): boolean => item.id === targetChapterId)?.title
      this.readerSessionStore.saveRemoteHistory(remoteHistory)
    }
    const openEpoch = this.readerOpenEpoch + 1
    this.readerOpenEpoch = openEpoch
    if (comic !== undefined && targetChapterId !== undefined &&
      comic.sourceRuntimeId !== undefined && comic.sourceRuntimeId.trim().length > 0 &&
      !comic.chapters.some((chapter: Chapter): boolean => chapter.id === targetChapterId)) {
      const originPaths = this.appPathStack.getAllPathName().join('|')
      const originTab = this.selectedTab
      const isCurrent = (): boolean => openEpoch === this.readerOpenEpoch &&
        originPaths === this.appPathStack.getAllPathName().join('|') && originTab === this.selectedTab
      this.showToast(AppStrings.get('manga_detail_loading_source'))
      try {
        const restored = await new SourceChapterPageHydrator(
          this.libraryStore, this.sourceRegistry, this.ensureLibraryPersistenceService(),
          () => { this.refreshLibrarySnapshot() },
        ).ensureChapterDescriptor(comicId, targetChapterId, isCurrent)
        comic = this.libraryStore.getComic(comicId)
        if (!isCurrent()) {
          return
        }
        if (!restored || comic === undefined || !await this.ensureReaderSourceChapterPages(comic, targetChapterId)) {
          if (isCurrent()) {
            this.showToast(AppStrings.get('manga_detail_load_source_chapters_failed'))
          }
          return
        }
        if (!isCurrent()) {
          return
        }
        comic = this.libraryStore.getComic(comicId)
      } catch (_error) {
        if (isCurrent()) {
          this.showToast(AppStrings.get('manga_detail_load_source_chapters_failed'))
        }
        return
      }
    }
    this.activeSourceReaderRequest = undefined
    const readerDetailVisible = this.isReaderDetailRouteVisible()
    const shouldPresentReader = !this.readerOpen || this.readerClosing
    this.readerChromeVisible = false
    this.readerSessionLoading = comic !== undefined && this.readerNeedsAsyncPreparation(comic, targetChapterId)
    this.readerSessionConfig = comic === undefined
      ? MOCK_LIBRARY_READER_SESSION
      : this.createReaderSessionConfigForOpen(comic, targetChapterId)
    this.readerPageIndex = this.readerSessionStore.openPageIndex(this.readerSessionConfig, this.readerOpenIntent)
    this.readerPreparation = null
    this.captureSharedReaderEntry(shouldPresentReader)
    // Starting a chapter from a detail page that was opened by Reader updates
    // the already-mounted Reader beneath it.  It is not a second Reader route.
    if (readerDetailVisible) {
      this.appPathStack.pop(true)
    }
    if (shouldPresentReader) {
      if (this.readerSessionPersistenceReady) this.readerTrackerCoordinator().beginReading()
      this.readerClosing = false
      this.readerRouteVisible = false
      this.readerOpen = true
      // Native root navigation presents the Reader immediately. Descriptor
      // refresh remains session work and never blocks route presentation.
      this.appPathStack.pushPath({ name: RouteName.READER }, true)
    }
    if (comic !== undefined) {
      this.readerPreparation = this.prepareReaderSession(comicId, targetChapterId, openEpoch)
    } else {
      // No session preparation will follow, so this publication is terminal.
      this.readerOpenIntent = 'resume'
    }
  }

  private async openSourceReader(
    request: SourceReaderSessionRequest,
    intent: ReaderChapterOpenIntent = 'resume',
  ): Promise<void> {
    this.readerOpenIntent = intent
    this.readerOpenAlign = intent === 'end' ? 'end' : 'start'
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
    this.activeKavitaReaderComic = undefined
    this.readerChromeVisible = false
    this.readerSessionLoading = true
    this.readerSessionConfig = this.createSourceReaderSessionConfig(nextRequest, [])
    this.readerPageIndex = this.readerSessionStore.openPageIndex(this.readerSessionConfig, this.readerOpenIntent)
    this.readerPreparation = null
    this.captureSharedReaderEntry(shouldPresentReader)
    // This matches normal Reader chapter switching: a detail page opened from
    // Reader is popped before the already-mounted Reader receives its next
    // transient session.
    if (readerDetailVisible) {
      this.appPathStack.pop(true)
    }
    if (shouldPresentReader) {
      if (this.readerSessionPersistenceReady) this.readerTrackerCoordinator().beginReading()
      this.readerClosing = false
      this.readerRouteVisible = false
      this.readerOpen = true
      this.appPathStack.pushPath({ name: RouteName.READER }, true)
    }
    this.readerPreparation = this.prepareSourceReaderSession(nextRequest, openEpoch)
  }

  private openRemoteHistory(entry: RemoteReadHistoryEntry): void {
    const history = copyRemoteReadHistoryEntry(entry)
    if (history === undefined || this.readerSessionStore.getProgress(history.comicId)?.chapterId !== history.chapterId) return
    if (history.kind === 'komga') {
      const params: KomgaSeriesRouteParam = { seriesId: history.resourceId, seriesTitle: history.title,
        expectedServerId: history.serverId, resumeChapterId: history.chapterId }
      this.appPathStack.pushPath({ name: RouteName.KOMGA_BROWSE, param: params })
    } else if (history.kind === 'kavita') {
      const params: KavitaBrowseRouteParam = { libraryId: history.libraryId, seriesId: history.resourceId,
        seriesTitle: history.title, expectedServerId: history.serverId, resumeChapterId: history.chapterId }
      this.appPathStack.pushPath({ name: RouteName.KAVITA_BROWSE, param: params })
    } else if (history.kind === 'webdav') {
      const params: WebDavBrowseRouteParam = { pathSegments: history.pathSegments,
        expectedServerId: history.serverId, resumeChapterId: history.chapterId }
      this.appPathStack.pushPath({ name: RouteName.WEBDAV_BROWSE, param: params })
    } else {
      const params: OpdsBrowseRouteParam = { remoteHistory: history }
      this.appPathStack.pushPath({ name: RouteName.OPDS_BROWSE, param: params })
    }
  }

  private openExternalReaderSession(): void {
    if (this.readerOpen && !this.readerClosing) {
      return
    }
    this.readerOpenEpoch += 1
    this.activeSourceReaderRequest = undefined
    this.activeKavitaReaderComic = undefined
    this.readerChromeVisible = false
    this.readerSessionLoading = false
    this.readerSessionConfig = cloneReaderSessionConfig(MOCK_LIBRARY_READER_SESSION)
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(this.readerSessionConfig)
    this.readerPreparation = null
    this.captureSharedReaderEntry(true)
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
    sourceFailureReason?: string,
    sourceFailure?: SourceFailureDetails,
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
      sourceFailureReason,
      sourceFailure,
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
      DiagnosticLogger.warn('index', 'open_from_manifest', '[ReaderOffline] step=open_from_manifest failed=true reason=manifest_session')
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
    this.readingStatisticsRecorder.close()
    const committed = this.readerSessionPersistenceReady && this.readerSessionStore.flush()
    this.cleanupProgressCommitted = committed
    this.readerTrackerProgress?.close(committed)
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
    this.activeKavitaReaderComic = undefined
    if (this.cleanupProgressCommitted) {
      this.cleanupProgressCommitted = false
      void this.cleanupService().run(getContext(this) as common.UIAbilityContext,
        this.libraryStore, this.readerSessionStore).then(() => { this.readerProgressRevision += 1 }).catch((error: Error): void => {
        DiagnosticLogger.exception('downloads', 'read_cleanup_failed', error)
      })
    }
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
      DiagnosticLogger.warn('index', 'restore_progress_failed', '[Reader] step=restore_progress_failed reason=session_store')
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

  private readerTrackerCoordinator(): ReaderTrackerProgressCoordinator {
    if (this.readerTrackerProgress === undefined) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      this.readerTrackerProgress = new ReaderTrackerProgressCoordinator(this.readerSessionStore,
        new TrackerProgressSyncService(context))
    }
    return this.readerTrackerProgress
  }


  private observeReaderTrackerProgress(progress: ReadingProgress): void {
    if (!this.readerOpen || !this.readerSessionPersistenceReady ||
      progress.comicId !== this.readerSessionConfig.comicId || progress.chapterId !== this.readerSessionConfig.chapterId) return
    void this.cleanupService().observe(getContext(this) as common.UIAbilityContext, progress)
      .catch((error: Error): void => { DiagnosticLogger.exception('downloads', 'read_cleanup_record_failed', error) })
    const source = this.activeSourceReaderRequest
    const comic = this.libraryStore.getComic(progress.comicId)
    const chapter = comic?.chapters.find((item: Chapter): boolean => item.id === progress.chapterId)
    const sourceChapter = source?.comicId === progress.comicId ? source.chapters?.find((item: ReaderChapterDescriptor): boolean =>
      item.id === progress.chapterId) : undefined
    const localNumber = comic !== undefined && chapter !== undefined &&
      (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER)
      ? chapter.index + 1 : undefined
    this.readerTrackerCoordinator().observe(progress, this.readerSessionConfig.chapterIds,
      sourceChapter?.chapterNumber ?? chapter?.chapterNumber ?? localNumber)
  }

  private observeReadingPages(comicId: string, chapterId: string, pages: number[]): void {
    if (!this.readerSessionPersistenceReady || comicId !== this.readerSessionConfig.comicId ||
      chapterId !== this.readerSessionConfig.chapterId) return
    this.syncReadingSessionActivity()
    this.readingStatisticsRecorder.observePages(comicId, chapterId, pages)
  }

  private persistReaderLabObserved(position: ReaderObservedPosition,
    column: 'odd_left' | 'even_left'): void {
    if (!this.readerSessionPersistenceReady || position.anchor.unit.scope !== 'koma-local') return
    const config = this.readerLabInitialConfig(position.anchor.unit.work, position.anchor.unit.unit)
    if (config === null) return
    if (config.chapterId !== position.anchor.unit.unit || config.totalPages !== position.pageCount ||
      position.anchor.sourceIndexHint < 0 || position.anchor.sourceIndexHint >= config.totalPages) return
    const index = position.anchor.sourceIndexHint
    const progress: ReadingProgress = {
      comicId: config.comicId,
      chapterId: config.chapterId,
      pageId: getReaderSessionPageId(config, index),
      pageIndex: index,
      totalPages: config.totalPages,
      progressRatio: (index + 1) / config.totalPages,
      completed: position.terminalSourceDisplayed,
      updatedAt: Date.now(),
      columnMode: column,
    }
    this.readerSessionStore.saveProgress(progress)
    if (this.readerOpen) this.observeReaderTrackerProgress(progress)
    // Keep page persistence live, but do not rebuild the covered shelf/history
    // and full chapter catalog on every page crossing. Reader close publishes
    // the saved state; a detail destination also refreshes in onShown.
    if (!this.isReaderRouteVisible()) this.readerProgressRevision += 1
  }

  private onBackupRestored(): void {
    this.readingStatisticsRecorder.reset()
    appSourcePackageManagerCache.invalidate()
    this.readDownloadCleanup?.invalidateAfterRestore()
    this.readerTrackerProgress?.resetAfterRestore()
    this.ensureLibraryPersistenceService()?.restore()
    new TrackerPreferencesStore(getContext(this) as common.UIAbilityContext).invalidateMappingSnapshot()
    this.libraryPreferencesRevision += 1
    void synchronizeBackgroundMaintenance(getContext(this) as common.UIAbilityContext)
      .catch((error: Error): void => { DiagnosticLogger.exception('maintenance', 'restore_schedule_failed', error) })
    this.applicationSettingsRestoreRevision += 1
    this.readerProgressRevision += 1
    this.refreshLibrarySnapshot()
  }

  private openLibraryMangaDetail(comicId: ComicId, newInstance: boolean = false): void {
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
          url: comic.sourcePath,
        },
      }
      : { mangaId: comic.id }
    RouterHelper.pushMangaDetail(params, newInstance)
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
          url: sourceRequest.mangaUrl,
        },
      }
      this.appPathStack.pushPath({
        name: RouteName.MANGA_DETAIL,
        param: detailParam,
      }, true)
      return
    }
    const comic = this.libraryStore.getComic(comicId)
    const routes = this.appPathStack.getAllPathName()
    const belowReader = routes[routes.length - 2]
    const privateBrowse = belowReader === RouteName.KOMGA_BROWSE || belowReader === RouteName.KAVITA_BROWSE ||
      belowReader === RouteName.WEBDAV_BROWSE || belowReader === RouteName.OPDS_BROWSE
    if (comic === undefined && (this.activeKavitaReaderComic?.id === comicId ||
      privateBrowse)) {
      // The original private browse page is still below Reader. Retire Reader
      // through its normal persistence/system-bar close before returning there.
      this.closeReader()
      return
    }
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
          url: comic?.sourcePath,
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
      for (const result of results) {
        if (result.status === 'succeeded') {
          succeededCount += 1
          await this.handleArchiveImportSucceeded(result.extractionResult.importResult.comic)
        } else {
          failedCount += 1
        }
      }
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
      DiagnosticLogger.error('index', 'archive_import_failed', '[Import] step=archive_import_failed code=archive_import_failed')
      this.showToast(AppStrings.get('import_feedback_failed_file'))
    }
  }

  private async startImageImport(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndImportImages(context)
      let succeededCount = 0
      let failedCount = 0
      for (const result of results) {
        if (result.status === 'succeeded') {
          succeededCount += 1
          await this.handleArchiveImportSucceeded(result.importResult.comic)
        } else {
          failedCount += 1
        }
      }
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
      DiagnosticLogger.error('index', 'image_import_failed', '[Import] step=image_import_failed code=image_import_failed')
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
      DiagnosticLogger.error('index', 'folder_import_failed', '[Import] step=folder_import_failed code=folder_import_failed')
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

      if (canImportLocalLibraryFolder()) {
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
  }

  private sourceManagerOpening: boolean = false

  private openSettingsSecondary(routeName: string): void {
    if (routeName !== RouteName.SOURCE_PACKAGE_MANAGER) {
      this.appPathStack.pushPath({ name: routeName })
      return
    }
    if (this.sourceManagerOpening) return
    this.sourceManagerOpening = true
    const context = getContext(this) as common.UIAbilityContext
    // Disk hydration finishes before the destination exists; a warm revisit
    // consumes the same ready snapshot, without another network check.
    void appSourcePackageManagerCache.prepare(context, connectLanguageState().effectiveLocale).then((): void => {
      appSourcePackageManagerCache.revalidateInBackground(context)
      this.appPathStack.pushPath({ name: routeName })
    }).finally((): void => { this.sourceManagerOpening = false })
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
    this.titleScroller = this.rootTabScrollers[index]
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
      pane === 'advanced' || pane === 'translation' || pane === 'llm-sources' || pane === 'enhancement-models' ||
      pane === 'about' || pane === 'diagnostics') {
      return pane
    }
    return 'root'
  }

  private localImportCommitService?: LocalImportCommitService

  private async handleArchiveImportSucceeded(comic: Comic): Promise<void> {
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) throw new Error('Local import persistence unavailable')
    if (this.localImportCommitService === undefined) {
      this.localImportCommitService = new LocalImportCommitService(this.libraryStore, persistenceService)
    }
    try {
      await this.localImportCommitService.commit(comic)
    } catch (error) {
      DiagnosticLogger.error('index', 'persist_imported_comic_failed', '[Library] step=persist_imported_comic_failed code=library_persist_failed')
      throw error as Error
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
      const boundScan = bindLocalLibraryFolderScanIdentity(scanResult, rootUri, this.libraryStore.listComics())
      const comics = buildComicsFromLocalLibraryFolderScan(boundScan, rootUri)
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
        DiagnosticLogger.error('index', 'persist_imported_folder_failed', '[Library] step=persist_imported_folder_failed code=library_persist_failed')
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

  private emptyLocalLibraryFolderRescanResult(rootCount: number): LocalLibraryFolderRescanActionResult {
    return {
      status: rootCount === 0 ? 'no_local_folders' : 'failed',
      rootCount,
      scannedRootCount: 0,
      reselectRequiredCount: 0,
      failedRootCount: 0,
      addedCount: 0,
      changedCount: 0,
      missingCount: 0,
      metadataChangedCount: 0,
      rejectedEntryCount: 0,
      upsertedCount: 0,
    }
  }

  private finalizeLocalLibraryFolderRescanResult(
    result: LocalLibraryFolderRescanActionResult,
  ): LocalLibraryFolderRescanActionResult {
    if (result.scannedRootCount > 0) {
      result.status = result.addedCount > 0 ||
        result.changedCount > 0 ||
        result.missingCount > 0 ||
        result.metadataChangedCount > 0
        ? 'updated'
        : 'unchanged'
    } else if (result.reselectRequiredCount > 0 && result.failedRootCount === 0) {
      result.status = 'reselect_required'
    } else {
      result.status = 'failed'
    }
    return result
  }

  private async rescanLocalLibraryFolders(comicId?: string): Promise<LocalLibraryFolderRescanActionResult> {
    let targetComics: Comic[] = []
    if (comicId === undefined) {
      targetComics = this.libraryStore.listComics()
    } else {
      const targetComic = this.libraryStore.getComic(comicId)
      if (targetComic !== undefined) {
        targetComics.push(targetComic)
      }
    }
    const rootUris = localLibraryFolderRootUrisFromComics(targetComics)
    const result = this.emptyLocalLibraryFolderRescanResult(rootUris.length)
    if (rootUris.length === 0) {
      return result
    }
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      result.failedRootCount = rootUris.length
      return result
    }
    for (const rootUri of rootUris) {
      const runtimeResult = await this.localImportCoordinator.rescanPersistedFolder(rootUri)
      if (runtimeResult.status === 'reselect_required') {
        result.reselectRequiredCount += 1
        continue
      }
      if (runtimeResult.status !== 'succeeded' || runtimeResult.scanResult === undefined) {
        result.failedRootCount += 1
        continue
      }
      const previousKnownSeries = buildKnownLocalLibraryFolderSeriesFromComics(
        this.libraryStore.listComics(),
        rootUri,
      )
      if (previousKnownSeries.length === 0) {
        result.failedRootCount += 1
        continue
      }
      try {
        const persisted = upsertLocalLibraryFolderRescanAndPersistLibraryStore(
          this.libraryStore,
          persistenceService,
          previousKnownSeries,
          runtimeResult.scanResult,
          rootUri,
        )
        result.scannedRootCount += 1
        result.addedCount += persisted.summary.addedCount
        result.changedCount += persisted.summary.changedCount
        result.missingCount += persisted.summary.missingCount
        result.metadataChangedCount += persisted.summary.metadataChangedCount
        result.rejectedEntryCount += persisted.summary.rejectedEntryCount
        result.upsertedCount += persisted.upsertedCount
      } catch (_error) {
        result.failedRootCount += 1
      }
    }
    if (result.upsertedCount > 0) {
      this.refreshLibrarySnapshot()
    }
    const finalized = this.finalizeLocalLibraryFolderRescanResult(result)
    console.info('[LocalFolderRescan] step=done roots=' + finalized.rootCount +
      ' scanned=' + finalized.scannedRootCount +
      ' reselect=' + finalized.reselectRequiredCount +
      ' failed=' + finalized.failedRootCount +
      ' added=' + finalized.addedCount +
      ' changed=' + finalized.changedCount +
      ' missing=' + finalized.missingCount)
    return finalized
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
      DiagnosticLogger.error('index', 'persist_removed_comic_failed', '[Library] step=persist_removed_comic_failed code=library_persist_failed')
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
      DiagnosticLogger.error('index', 'persist_removed_comics_failed', '[Library] step=persist_removed_comics_failed code=library_persist_failed')
      throw error as Error
    }
  }

  private cleanupRemovedComicDownloads(comicId: ComicId): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      void OfflineDownloadService.ensureQueueInitialized(context.filesDir)
        .then((): Promise<number> => new OfflineDownloadQueueStore(context.filesDir).deleteComicDownloads(comicId))
        .then((removedCount: number) => {
          console.info(`[library-remove] downloads_cleanup removed=${removedCount}`)
        })
        .catch((_error: Error) => {
          DiagnosticLogger.warn('index', 'downloads_cleanup_failed', '[library-remove] downloads_cleanup_failed reason=delete_downloads')
        })
    } catch (_error) {
      DiagnosticLogger.warn('index', 'downloads_cleanup_failed', '[library-remove] downloads_cleanup_failed reason=context_unavailable')
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
      DiagnosticLogger.error('index', 'persist_category_assignment_failed', '[Library] step=persist_category_assignment_failed code=library_persist_failed')
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
      DiagnosticLogger.error('index', 'persist_category_membership_failed', '[Library] step=persist_category_membership_failed code=library_persist_failed')
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

  @Monitor('appForegroundState.revision')
  private runForegroundAutomaticBackup(): void {
    if (!this.libraryUpdateReady || !this.appForegroundState.active ||
      shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) return
    this.triggerAutomaticBackup(getContext(this) as common.UIAbilityContext)
  }

  private triggerAutomaticBackup(context: common.UIAbilityContext): void {
    if (this.automaticBackupPending) {
      return
    }
    this.automaticBackupPending = true
    void new BackupService(context).runAutomaticLocalBackupIfDue(Date.now(), true)
      .then((result: BackupAutomaticRunResult) => {
        if (result.ran || result.failureCode !== undefined) this.backupSettingsRevision += 1
        if (result.ran) {
          console.info(`[Backup] step=app_open_auto_backup deleted=${result.deletedCount}`)
        } else if (result.failureCode !== undefined) {
          DiagnosticLogger.error('index', 'app_open_auto_backup_failed', `[Backup] step=app_open_auto_backup_failed code=${result.failureCode}`)
        } else {
          console.info('[Backup] step=auto_admission status=' + result.skippedReason)
        }
      })
      .catch((error: Error) => {
        if (error.message === 'backup_restore_busy') {
          console.info('[Backup] step=auto_admission status=restore_busy')
        } else {
          DiagnosticLogger.error('index', 'app_open_auto_backup_failed', '[Backup] step=app_open_auto_backup_failed code=backup_auto_export_failed')
        }
      })
      .finally(() => { this.automaticBackupPending = false })
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
        DiagnosticLogger.warn('index', 'app_open_pending_progress', '[TrackerSync] step=app_open_pending_progress status=failed reason=provider_failed')
      })
  }

  aboutToDisappear(): void {
    this.readingStatisticsRecorder.close()
    if (this.readerSessionPersistenceReady) this.readerSessionStore.flush()
    this.automaticDownloads?.dispose()
    this.automaticDownloads = undefined
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
    // Only local cache warming at startup. Network revalidation belongs to an
    // actual manager-open intent; a direct settings route is not index browsing.
    void appSourcePackageManagerCache.prepare(context, connectLanguageState().effectiveLocale)
    appSourceWebSessionStore.configure(context, this.sourceRegistry)
    if (!this.libraryPersistenceRestored) {
      this.libraryPersistenceRestored = true
      const persistenceService = this.ensureLibraryPersistenceService()
      if (persistenceService !== undefined) {
        try {
          persistenceService.restore()
          void activateLocalLibraryFolderAccessForComics(this.libraryStore.listComics())
            .then((summary) => {
              console.info('[LocalFolderAccess] step=restore_activate roots=' + summary.rootCount +
                ' activated=' + summary.activatedCount +
                ' reselect=' + summary.notPersistedCount +
                ' unsupported=' + summary.unsupportedCount +
                ' failed=' + summary.failedCount)
            })
            .finally(() => {
              this.refreshLibrarySnapshot()
              this.libraryUpdateReady = true
              this.resumeAutomaticDownloadQueue()
              this.runForegroundLibraryUpdate()
              this.runForegroundAutomaticBackup()
            })
        } catch (error) {
          void error
          DiagnosticLogger.error('index', 'restore_failed', '[Library] step=restore_failed code=library_restore_failed')
        }
      }
    }
    this.runForegroundLibraryUpdate()
    if (!shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) {
      setTimeout(() => {
        this.runForegroundAutomaticBackup()
        this.triggerPendingTrackerProgressSync(context)
      }, 250)
    }
  }

  @Builder
  TabIcon(title: string, idx: number) {
    KomaTabIcon({
      title: title,
      idx: idx,
      currentIndex: this.selectedTab,
      bounceTrigger: this.tabIconBounceTriggers[idx] ?? -1,
    })
  }

  private readerOrdinaryNavTransition(_from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    if (operation !== NavigationOperation.PUSH || to.name !== RouteName.READER ||
      this.readerRouteBackend !== KomaReaderBackend.SHARED || !this.readerRouteTransition.pending()) return undefined
    return this.readerRouteTransition.transition(this.getUIContext(), (_success: boolean): void => {})
  }

  @Builder
  private ReaderDestination() {
    if (this.readerRouteBackend === KomaReaderBackend.SHARED) {
      KomaReaderLabPage({
        request: this.sharedReaderRequest,
        productionEntry: true,
        routeTransition: this.readerRouteTransition,
        closeRequestId: this.readerCloseRequestId,
        catalogHost: this.sharedReaderCatalogHost,
        prepareInitial: async (): Promise<void> => { await this.readerPreparation },
        readInitialColumn: (work: string, unit: string): 'odd_left' | 'even_left' =>
          this.readReaderLabInitialColumn(work, unit),
        readInitialPage: (work: string, unit: string): number =>
          this.readerSessionConfig.comicId === work && this.readerSessionConfig.chapterId === unit
            ? this.readerPageIndex : this.readReaderLabInitialPage(work, unit),
        persistObserved: (position: ReaderObservedPosition, column: 'odd_left' | 'even_left'): void => {
          this.persistReaderLabObserved(position, column)
          if (position.anchor.unit.work === this.readerSessionConfig.comicId &&
            position.anchor.unit.unit === this.readerSessionConfig.chapterId) {
            this.readerPageIndex = position.anchor.sourceIndexHint
          }
        },
        flushObserved: (): void => { if (this.readerSessionPersistenceReady) this.readerSessionStore.flush() },
        observeReadingPages: (work: string, chapter: string, pages: number[]): void => {
          this.observeReadingPages(work, chapter, pages)
        },
        onOpenMangaDetail: (_work: string): void => { this.openReaderMangaDetail() },
        onRouteVisibleChange: (visible: boolean): void => {
          this.readerRouteVisible = visible
          if (!visible) this.readerRouteTransition.cancel()
        },
        onRouteDisappear: (): void => { this.finishReaderRouteClose() },
        onClose: (): void => { this.popReaderRouteAfterSystemBarRestore() },
      })
    } else {
      this.LegacyReaderDestination()
    }
  }

  @Builder
  private LegacyReaderDestination() {
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
        onObservedProgress: (progress: ReadingProgress): void => {
          this.observeReaderTrackerProgress(progress)
        },
        onObservedReadingPages: (comic: string, chapter: string, pages: number[]): void => {
          this.observeReadingPages(comic, chapter, pages)
        },
        onCloseReader: () => {
          this.popReaderRouteAfterSystemBarRestore()
        },
        onOpenMangaDetail: () => {
          this.openReaderMangaDetail()
        },
        onOpenChapter: (chapterId: string, intent?: ReaderChapterOpenIntent) => {
          const sourceRequest = this.activeSourceReaderRequest
          if (sourceRequest !== undefined && sourceRequest.comicId === this.readerSessionConfig.comicId) {
            const nextRequest = sourceReaderSessionRequestForChapter(sourceRequest, chapterId)
            if (nextRequest !== undefined) {
              void this.openSourceReader(nextRequest, intent)
            }
            return
          }
          if (this.readerSessionConfig.comicId.length > 0) {
            void this.openReader(this.readerSessionConfig.comicId, chapterId, intent)
          }
        },
        // RDR-004-B: a crossed-into chapter may ask a continuous session to
        // land on the last image's bottom instead of its top. Runtime hint
        // only; it follows the same session publication as the open intent.
        initialScrollAlign: this.readerOpenAlign
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
    .onShown(() => { param.chrome.resume() })
    .onHidden(() => { param.chrome.hide() })
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
          if (param.onMangaSelected !== undefined) {
            const onSelected = param.onMangaSelected
            this.appPathStack.pop()
            onSelected(manga)
          } else {
            RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
          }
        },
      })
    }
    .onShown(() => { param.chrome.resume() })
    .onHidden(() => { param.chrome.hide() })
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
        onOpenLibraryResult: (comicId: string) => { this.openLibraryMangaDetail(comicId) },
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
    .onShown(() => { RouterHelper.ensureSearchRouteChrome(param).visible = true })
    .onHidden(() => { RouterHelper.ensureSearchRouteChrome(param).visible = false })
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
          onArchiveImportSucceeded: async (comic: Comic): Promise<void> => {
            await this.handleArchiveImportSucceeded(comic)
            this.appPathStack.pop(false)
          },
          onLocalImageImportSucceeded: async (comic: Comic): Promise<void> => {
            await this.handleArchiveImportSucceeded(comic)
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
    } else if (name === RouteName.MANGA_WEB) {
      MangaWebPage({ params: param as MangaWebRouteParam })
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
          onRefreshLocalFolder: (comicId: string) => this.rescanLocalLibraryFolders(comicId),
          onLibraryChanged: () => { this.onMangaDetailLibraryChanged() },
          onMigrationRequested: (comicId: string) => {
            this.appPathStack.pushPath({ name: RouteName.MANGA_MIGRATION,
              param: { comicIds: [comicId], fromDetail: true } as MangaMigrationRouteParam })
          }
        })
      }
      .titleBar(this.mangaDetailTitleBarOpts(param as MangaDetailRouteParam))
      .onShown(() => {
        RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam).visible = true
        this.readerProgressRevision += 1
      })
      .onHidden(() => {
        RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam).visible = false
      })
    } else if (name === RouteName.MANGA_MIGRATION) {
      HdsNavDestination() {
        MangaMigrationPage({
          comicIds: (param as MangaMigrationRouteParam).comicIds,
          registry: this.sourceRegistry, libraryStore: this.libraryStore,
          persistence: this.ensureLibraryPersistenceService(), readerStore: this.readerSessionStore,
          onBusyChanged: (busy: boolean): void => { (param as MangaMigrationRouteParam).committing = busy },
          onLibraryChanged: (): void => {
            this.onMangaDetailLibraryChanged()
            this.readerProgressRevision += 1
          },
          onComplete: (ids: string[]): void => {
            const fromDetail = (param as MangaMigrationRouteParam).fromDetail === true
            DiagnosticLogger.info('manga_migration', 'return', `fromDetail=${fromDetail} targets=${ids.length}`)
            this.appPathStack.pop(false)
            if (fromDetail && ids.length === 1) {
              this.appPathStack.pop(false)
              // NavPathStack otherwise reuses the just-popped same-name detail,
              // retaining the old source's component state after the migration.
              this.openLibraryMangaDetail(ids[0], true)
            }
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('migration_title')))
      .onBackPressed((): boolean => (param as MangaMigrationRouteParam).committing === true)
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
          onOpenReader: (comic: Comic, chapterId: string) => {
            void this.openReader(comic.id, chapterId, 'resume', comic)
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
          params: param as WebDavBrowseRouteParam,
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
        SourcePackageManagerPage({
          initialSettingsSourceId: (param as SourcePackageManagerRouteParam | undefined)?.settingsSourceId ?? '',
          onSettingsSaved: () => { (param as SourcePackageManagerRouteParam | undefined)?.onSettingsSaved?.() },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_source_package_manager_title')))
    } else if (name === RouteName.SETTINGS_PANE) {
      HdsNavDestination() {
        SettingsPage({
          enhancementModelsRevision: this.enhancementModelsRevision,
          onEnhancementModelsChanged: () => { this.enhancementModelsRevision += 1 },
          preferencesRestoreRevision: this.applicationSettingsRestoreRevision,
          pane: this.settingsPaneFromParam(param),
          onClosePane: () => { this.appPathStack.pop() },
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
          onRefreshLocalFolders: () => this.rescanLocalLibraryFolders(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(settingsPaneTitle(this.settingsPaneFromParam(param))))
    } else if (name === RouteName.LIBRARY_UPDATE_RESULTS) {
      HdsNavDestination() {
        LibraryUpdateResultPage({
          libraryStore: this.libraryStore,
          sourceRegistry: this.sourceRegistry,
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_library_update_results_title')))
    } else if (name === RouteName.LIBRARY_CATEGORIES) {
      HdsNavDestination() {
        LibraryCategoryManagementPage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onDisplayStrategyChanged: (strategy: LibraryCategoryDisplayStrategy) => {
            this.categoryDisplayStrategyChange = strategy
          },
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
      .onBackPressed(() => BackupRestoreActivity.isRestoring())
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
      .onBackPressed(() => BackupRestoreActivity.isRestoring())
      .onShown(() => { this.backupSettingsRevision += 1 })
    } else if (name === RouteName.READING_STATISTICS) {
      HdsNavDestination() {
        ReadingStatisticsPage({ libraryStore: this.libraryStore, sessionStore: this.readerSessionStore })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('reading_statistics_title')))
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
                libraryScroller: this.rootTabScrollers[TabIndex.LIBRARY],
                libraryStore: this.libraryStore,
                libraryPreferencesRevision: this.libraryPreferencesRevision,
                categoryDisplayStrategyChange: this.categoryDisplayStrategyChange,
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
                onMigrationRequested: (comicIds: string[]): void => {
                  this.appPathStack.pushPath({ name: RouteName.MANGA_MIGRATION,
                    param: { comicIds, fromDetail: false } as MangaMigrationRouteParam })
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
                browseScroller: this.rootTabScrollers[TabIndex.BROWSE],
                active: this.selectedTab === TabIndex.BROWSE,
                navigationVisible: this.rootNavigationVisible,
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
                scroller: this.rootTabScrollers[TabIndex.HISTORY],
                libraryStore: this.libraryStore,
                active: this.selectedTab === TabIndex.HISTORY,
                readerSessionStore: this.readerSessionStore,
                readerProgressRevision: this.readerProgressRevision,
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                },
                onOpenSourceReader: (request: SourceReaderSessionRequest) => {
                  void this.openSourceReader(request)
                },
                onOpenRemoteReader: (entry: RemoteReadHistoryEntry) => {
                  this.openRemoteHistory(entry)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.HISTORY), TabIndex.HISTORY))

            TabContent() {
              SettingsPage({
                enhancementModelsRevision: this.enhancementModelsRevision,
                onEnhancementModelsChanged: () => { this.enhancementModelsRevision += 1 },
                scroller: this.rootTabScrollers[TabIndex.SETTINGS],
            preferencesRestoreRevision: this.applicationSettingsRestoreRevision,
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
                onRefreshLocalFolders: () => this.rescanLocalLibraryFolders(),
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
          .onTabBarClick((index: number) => {
            if (index < 0 || index >= this.tabIconBounceTriggers.length) return
            const triggers = this.tabIconBounceTriggers.slice()
            triggers[index] += 1
            this.tabIconBounceTriggers = triggers
          })
          .onChange((index: number) => {
            this.leaveLibrarySelection(index)
            this.selectedTab = index
            this.titleScroller = this.rootTabScrollers[index]
          })
        }
        .titleBar(this.titleBarOptions())
        .bindToScrollable([this.titleScroller])
        .titleMode(HdsNavigationTitleMode.MINI)
        .hideBackButton(this.selectedTab !== TabIndex.LIBRARY || !this.libraryTitleBar.selectionMode)
        .dynamicHideTitleBar({
          hideTitleArea: false,
          hideBottomBuilder: false,
          hideStatusBar: false,
          mode: HideMode.SCROLL_UP,
        })
        .navDestination(this.AppDestination)
        .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
          operation: NavigationOperation): NavigationAnimatedTransition | undefined =>
          this.readerOrdinaryNavTransition(from, to, operation))
        .mode(NavigationMode.Stack)
        .onNavBarStateChange((visible: boolean) => { this.rootNavigationVisible = visible })
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }

      Row()
        .width(1)
        .height(1)
        .margin({ top: this.layoutSafeArea.topAvoidHeight + 48, right: ThemeConstants.SPACE_MD })
        .hitTestBehavior(HitTestMode.None)
        .bindMenu(this.importMenuShown, this.ImportMenu, komaMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: () => {
            this.importMenuShown = false
          },
        }))
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
    } else if (this.selectedTab === TabIndex.HISTORY) {
      const statisticsContent: Record<string, Object> = { 'label': AppStrings.get('reading_statistics_title'),
        'icon': $r('app.media.ic_reading_statistics'),
        'action': (): void => { this.appPathStack.pushPath({ name: RouteName.READING_STATISTICS }) } }
      const statisticsItem: Record<string, Object> = { 'content': statisticsContent }
      menu['value'] = [statisticsItem]
      menu['maxCount'] = 1
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
      'blurStrategy': BlurStrategy.ENABLE,
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
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
      'blurStrategy': BlurStrategy.ENABLE,
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
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

  private sourceHomepageMenuItem(source: SourceRuntimeRegistryInstalledSourceSummary,
    isCurrent: () => boolean): Record<string, Object> | undefined {
    // 2026-10-27: only advertise an address already declared by this source.
    // The user's no-empty-entry decision replaces optimistic IO on menu taps.
    const homepage = normalizeSourceHomepage(source.homepage) ?? normalizeSourceHomepage(
      appSourcePackageManagerCache.indexEntries.find((entry): boolean => entry.id === source.sourceId)?.homepage)
    if (homepage === undefined) return undefined
    const content: Record<string, Object> = {
      'label': AppStrings.get('manga_detail_menu_open_webview'),
      'icon': $r('sys.symbol.worldclock'),
      'isEnabled': true,
      'action': (): void => {
        if (isCurrent()) RouterHelper.pushMangaWeb({ url: homepage,
          title: sourceDisplayName(source.sourceId, source.displayName) })
      },
    }
    return { 'content': content }
  }

  private sourceBrowseTitleBarOpts(param: SourceBrowseRouteParam): Record<string, Object> {
    const source = param.source
    const chrome = param.chrome
    const title: Record<string, Object> = {}
    title['mainTitle'] = sourceDisplayName(source.sourceId, source.displayName)
    const content: Record<string, Object> = {}
    content['title'] = title
    const bottomBuilder: Record<string, Object> = {}
    bottomBuilder['builderComponent'] = this.browseFieldContent(chrome)
    bottomBuilder['height'] = SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT
    bottomBuilder['showType'] = BottomBuilderShowType.DIRECTLY_SHOW
    content['bottomBuilder'] = bottomBuilder
    const menuItems: Record<string, Object>[] = []
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
      menuItems.push(filterItem)
    }
    if (chrome.settingsAvailable) {
      const settingsContent: Record<string, Object> = {
        'label': AppStrings.get('source_pkg_settings'),
        'icon': $r('sys.symbol.gearshape'),
        'isEnabled': true,
        'action': () => { chrome.requestSettings() },
      }
      menuItems.push({ 'content': settingsContent })
    }
    const homepage = this.sourceHomepageMenuItem(source, (): boolean => chrome.visible)
    if (homepage !== undefined) menuItems.push(homepage)
    if (chrome.webSessionAvailable) {
      const webContent: Record<string, Object> = {
        'label': AppStrings.get('source_web_open'),
        'icon': $r('sys.symbol.website'),
        'isEnabled': source.enabled,
        'action': () => {
          if (!openSourceWebSession(source.sourceId, sourceDisplayName(source.sourceId, source.displayName),
            () => { chrome.markRefreshNeeded() })) {
            this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_web_not_allowed') })
          }
        },
      }
      menuItems.push({ 'content': webContent })
    }
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 1 }
    content['menu'] = menu
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
    title['mainTitle'] = sourceDisplayName(source.sourceId, source.displayName) || AppStrings.get('tab_search')
    const bottomBuilder: Record<string, Object> = {}
    bottomBuilder['builderComponent'] = this.sourceSearchFieldContent(chrome)
    bottomBuilder['height'] = SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT
    bottomBuilder['showType'] = BottomBuilderShowType.DIRECTLY_SHOW
    const content: Record<string, Object> = {}
    content['title'] = title
    content['bottomBuilder'] = bottomBuilder
    const menuItems: Record<string, Object>[] = []
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
      menuItems.push(filterItem)
    }
    if (chrome.settingsAvailable) {
      const settingsContent: Record<string, Object> = {
        'label': AppStrings.get('source_pkg_settings'),
        'icon': $r('sys.symbol.gearshape'),
        'isEnabled': true,
        'action': () => { chrome.requestSettings() },
      }
      menuItems.push({ 'content': settingsContent })
    }
    const homepage = this.sourceHomepageMenuItem(source, (): boolean => chrome.visible)
    if (homepage !== undefined) menuItems.push(homepage)
    if (chrome.webSessionAvailable) {
      const webContent: Record<string, Object> = {
        'label': AppStrings.get('source_web_open'),
        'icon': $r('sys.symbol.website'),
        'isEnabled': source.enabled,
        'action': () => {
          if (!openSourceWebSession(source.sourceId, sourceDisplayName(source.sourceId, source.displayName),
            () => { chrome.markRefreshNeeded() })) {
            this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_web_not_allowed') })
          }
        },
      }
      menuItems.push({ 'content': webContent })
    }
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 1 }
    content['menu'] = menu
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
      'blurStrategy': BlurStrategy.ENABLE,
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
      'content': content,
      'style': style,
    }
  }

  private mangaDetailTitle(param: MangaDetailRouteParam): string {
    const resolvedTitle = param.chrome?.resolvedTitle?.trim() ?? ''
    if (resolvedTitle.length > 0) return resolvedTitle
    const initialTitle = param.initialManga?.title?.trim() ?? ''
    if (initialTitle.length > 0) {
      return initialTitle
    }
    const sourceId = param.sourceId?.trim() ?? ''
    const mangaId = param.mangaId.trim()
    const comic = sourceId.length > 0
      ? this.libraryStore.listComics().find((item: Comic): boolean =>
        item.sourceRuntimeId === sourceId && item.remoteResourceId === mangaId)
      : this.libraryStore.getComic(param.mangaId)
    const comicTitle = comic?.title?.trim() ?? ''
    if (comicTitle.length > 0) {
      return comicTitle
    }
    return ''
  }

  private mangaDetailTitleBarOpts(param: MangaDetailRouteParam): Record<string, Object> {
    const chrome = RouterHelper.ensureMangaDetailRouteChrome(param)
    const title: Record<string, Object> = { 'mainTitle': chrome.showTitle ? this.mangaDetailTitle(param) : '' }
    const content: Record<string, Object> = { 'title': title }
    if (!chrome.pageActionsAvailable && !chrome.sourceReloadAvailable) {
      return this.sourceRouteTitleBarOpts(content)
    }

    const menuItems: Record<string, Object>[] = []
    if (chrome.sourceReloadAvailable) {
      menuItems.push({ 'content': {
        'label': AppStrings.get('manga_detail_menu_reload_source'),
        'icon': $r('sys.symbol.arrow_clockwise'),
        'isEnabled': true,
        'action': () => { chrome.requestAction(MangaDetailTitleAction.RELOAD_SOURCE) },
      } as Record<string, Object> })
    }
    if (!chrome.pageActionsAvailable) {
      content['menu'] = { 'value': menuItems, 'maxCount': 1 } as Record<string, Object>
      return this.sourceRouteTitleBarOpts(content)
    }
    if (chrome.webActionsAvailable) {
      menuItems.push({ 'content': {
        'label': AppStrings.get('manga_detail_menu_open_webview'),
        'icon': $r('sys.symbol.website'),
        'isEnabled': true,
        'action': () => { chrome.requestAction(MangaDetailTitleAction.OPEN_WEBVIEW) },
      } as Record<string, Object> })
      menuItems.push({ 'content': {
        'label': AppStrings.get('manga_detail_menu_open_browser'),
        'icon': $r('sys.symbol.arrow_right'),
        'isEnabled': true,
        'action': () => { chrome.requestAction(MangaDetailTitleAction.OPEN_BROWSER) },
      } as Record<string, Object> })
    }
    if (chrome.migrationAvailable) {
      menuItems.push({ 'content': {
        'label': AppStrings.get('migration_title'), 'icon': $r('sys.symbol.arrow_right'), 'isEnabled': true,
        'action': (): void => { chrome.requestAction(MangaDetailTitleAction.MIGRATE) },
      } as Record<string, Object> })
    }
    if (chrome.personalDataAvailable) {
      menuItems.push({ 'content': { 'label': AppStrings.get('manga_notes'),
        'icon': $r('sys.symbol.square_and_pencil'), 'isEnabled': !chrome.personalizationBusy,
        'action': (): void => { chrome.requestAction(MangaDetailTitleAction.EDIT_NOTES) },
      } as Record<string, Object> })
    }
    if (chrome.coverActionsAvailable) {
      menuItems.push({ 'content': { 'label': AppStrings.get('manga_cover_change'),
        'icon': $r('sys.symbol.ohos_photo'), 'isEnabled': !chrome.personalizationBusy,
        'action': (): void => { chrome.requestAction(MangaDetailTitleAction.CHANGE_COVER) },
      } as Record<string, Object> })
      if (chrome.customCoverAvailable) {
        menuItems.push({ 'content': { 'label': AppStrings.get('manga_cover_restore'),
          'icon': $r('sys.symbol.arrow_clockwise'), 'isEnabled': !chrome.personalizationBusy,
          'action': (): void => { chrome.requestAction(MangaDetailTitleAction.RESTORE_COVER) },
        } as Record<string, Object> })
      }
    }
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
