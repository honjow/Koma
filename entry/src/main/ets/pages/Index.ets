import { CachedCoverImage } from '../components/CachedCoverImage'
import { MangaDetailTransitionCoordinator, MANGA_DETAIL_ROOT_ID } from '../navigation/MangaDetailTransitionCoordinator'
import { MangaDetailTransitionCoverSource, sameTransitionCover } from '../state/MangaDetailTransitionCoverSource'
import { connectMangaDetailTransition, MangaDetailTransitionState, MangaDetailTransitionPhase } from '../state/MangaDetailTransitionState'
import { appDeviceSync } from '../deviceSync/DeviceSyncRuntime'
import { SyncGroup } from '../deviceSync/DeviceSyncFacts'
import { SyncReadingWorkConflict } from '../deviceSync/DeviceSyncEngine'
import { continuationResumeResolution, SyncReadingWorkProgress } from '../deviceSync/DeviceSyncData'
import { DeviceSyncConnectionPage, DeviceSyncHuaweiCloudPage, DeviceSyncOverviewPage, DeviceSyncReviewPage, DeviceSyncReviewReason,
  DeviceSyncWebDavChrome, DeviceSyncWebDavPage } from './DeviceSyncPages'
import { ImagePluginsPage } from './ImagePluginsPage'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { AppearanceState, connectAppearanceState } from '../state/AppearanceState'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { SourceCatalogSectionsBuilder, SOURCE_MANAGER_SECTIONS_HEIGHT } from '../components/SourceCatalogSections'
import { ImagePluginsRequest } from '../model/ImagePluginManagement'
import { ReaderPreferencesStore } from '../model/ReaderPreferencesStore'
import { LibraryUpdatesPage } from './LibraryUpdatesPage'
import { PullRefreshController } from '../components/PullRefresh'
import { classifyLibraryUpdateSummary, LibraryUpdateResultStore } from '../model/LibraryUpdateResultStore'
import { countLibraryUpdateNewChapters } from '../model/LibraryUpdateService'
import { setCachedLibraryChapterUpdates } from '../model/LibraryChapterUpdates'
import { SourceSubscriptionsPage } from './SourceSubscriptionsPage'
import { HdsNavigationBadgeOptions, TextStyleMode } from '@kit.UIDesignKit'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { SourceCatalogBottomSearchBuilder } from '../components/SourceCatalogBottomSearch'
import { SourceCatalogHeaderActionsBuilder, SourceCatalogHeaderActionsParams } from '../components/SourceCatalogHeaderActions'
import { appSourceCatalogFilters, SourceCatalogFilterState } from '../state/SourceCatalogFilterState'
import { appSourcePackageLocalImport, SourcePackageLocalImport } from '../sourceRuntime/SourcePackageLocalImport'
import { connectReaderDisplayPreview, ReaderDisplayPreviewState } from '../state/ReaderDisplayPreviewState'
import { ReaderBrightnessController } from '../model/ReaderBrightnessController'
import { connectReaderModeState, ReaderModeState } from '../state/ReaderModeState'
import { applyBackgroundLibraryResults, synchronizeBackgroundMaintenance } from '../model/BackgroundMaintenance'
import { bindRemoteProgressLibrary } from '../model/RemoteProgressBootstrapSync'
import { SourcePackageManagerCache, appSourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { komaDialogMaterial, komaMenuOptions, komaSheetOptions, komaToastOptions } from "../theme/KomaPopupOptions"
import { firstReaderChapter, readerChapterPickerChapters } from '../model/ReaderChapterSequence'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { OfflineDownloadService } from '../model/OfflineDownloadService'
import { AutomaticDownloadController } from '../model/AutomaticDownloadController'
import { ReadDownloadCleanup } from '../model/ReadDownloadCleanup'
import {
  appReaderContinuation,
  connectReaderContinuationRuntimeState,
  ReaderContinuationRuntimeState,
  ReaderContinuationSnapshot,
  RestoredContinuationTask,
} from '../continuation/ReaderContinuationService'
import {
  buildSourceRequestFromContinuation,
  canContinueSourceSession,
  ReaderContinuationPayload,
  resolveContinuationPageIndex,
} from '../continuation/ReaderContinuationPayload'
import { connectContinuationState, ContinuationState } from '../state/ContinuationState'
import {
  getInstalledSourcePackage,
  setEnabled as setSourcePackageEnabled,
  sourceDisplayName,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { common } from '@kit.AbilityKit'
import { KomaReaderEntryStage, KomaReaderLabPage } from '../readerLab/KomaReaderLabPage'
import { KomaReaderCatalogHost, KomaReaderChapterCatalogUpdate } from '../readerLab/KomaReaderCatalogHost'
import { KomaReaderFailure } from '../readerLab/KomaReaderFailure'
import { comicArchiveExtractionRoot } from '../import/ComicArchiveBookmarks'
import { readOrderedEpubImages } from '../import/EpubArchiveReader'
import { planLegacyEpubOrder } from '../import/LegacyEpubOrder'
import { SourceFailureDetails, SourceRuntimeError } from '../model/SourceRuntimeError'
import { createKomaReaderLabOfflineConfig } from '../readerLab/KomaReaderLabOfflineConfig'
import { ReaderLabLaunchState, ReaderLabRequest, connectReaderLabLaunch, ReaderRouteTransition } from '@reader-kit/ui'
import { ReaderCancellation, ReaderObservedPosition, ReaderUnitKey } from '@reader-kit/core'
import {
  BlurStrategy,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsAnimationMode,
  HdsBarStyle,
  HdsNavigationMenuItemOptions,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HdsTabsMiniBar,
  HideMode,
  BottomBuilderShowType,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AdvancedDialogV2Button, ColorMetrics, ComponentContent, CustomContentDialogV2, FrameCallback, LoadingDialogV2, SymbolGlyphModifier } from '@kit.ArkUI'
import { LibraryPage, LibraryTitleBarPresentation } from './LibraryPage'
import { BrowsePage } from './BrowsePage'
import { HistoryPage } from './HistoryPage'
import { ReadingStatisticsPage } from './ReadingStatisticsPage'
import { ReadingSessionRecorder, ReadingSessionRecord } from '../model/ReadingStatistics'
import { TrackerPreferencesStore } from '../model/TrackerModels'
import { RemoteReadHistoryEntry, copyRemoteReadHistoryEntry } from '../model/RemoteReaderSession'
import { SearchPage } from './SearchPage'
import { SEARCH_TITLE_BOTTOM_HEIGHT, SearchTitleFieldContentBuilder } from '../components/SearchTitleField'
import { SettingsPage, SettingsPaneKey, settingsPaneTitle, usesWideSettingsHome } from './SettingsPage'
import { LibraryResumeMiniBar } from '../components/LibraryResumeMiniBar'
import { KomaModalContent, KomaModalScaffold, komaModalCloseAction, komaModalTitleBarOptions } from '../components/KomaModalScaffold'
import { FormTitleActionState } from '../state/FormTitleActionState'
import { MODEL_SOURCE_ADD_BUTTON_ID, ModelSourcesTitleAction } from '../components/KomaTranslationSourcesContent'
import { KomaMenuController, KomaMenuAction, KomaMenuGroup, komaTitleMoreIcon } from '../components/ui/KomaMenuController'
import { ImportPage, LocalFolderImportPersistResult } from './ImportPage'
import { LocalImportCoordinator, LOCAL_IMPORT_PDF_PASSWORD_REQUIRED } from '../import/LocalImportCoordinator'
import { LocalImportCommitService } from '../import/LocalImportCommitService'
import { MangaDetailPage } from './MangaDetailPage'
import { MangaWebPage } from './MangaWebPage'
import { resolveSourceChapterList, SourceChapterListResult } from '../model/SourceChapterListResolver'
import {
  ReaderChapterDescriptor,
  ReaderChapterOpenIntent,
  cloneReaderChapterDescriptor,
  continuationChapterIds,
  needsSourceCatalogChronology,
} from '../model/ReaderChapterSequence'
import { SourceBrowsePage } from './SourceBrowsePage'
import { chapterReadingChaptersFor, chapterReadingMetadataPendingFor, chapterReadingSortFor } from '../model/ChapterListPreferencesStore'
import { SourceWebFetchBridgeHost } from '../components/SourceWebFetchBridgeHost'
import { SourceSearchPage } from './SourceSearchPage'
import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { MangaGridItem } from '../components/MangaGridItem'
import { MangaMigrationPage } from './MangaMigrationPage'
import { MihonImportWork } from '../model/MihonBackupReader'
import { MihonImportService } from '../model/MihonImportService'
import { LibraryFilterStore } from '../model/LibraryFilterStore'
import { SourceMangaDetailSnapshot, sourceMangaDetailSnapshotCache } from '../model/SourceMangaDetailSnapshotCache'
import { MangaMigrationPreferencesStore } from '../model/MangaMigrationPreferencesStore'
import { MigrationCommand } from '../state/MangaMigrationRouteChromeState'
import { MangaMigrationRouteParam, MangaMigrationSearchRouteParam } from '../common/RouterHelper'
import { SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT, SourceSearchTitleFieldContentBuilder } from '../components/SourceSearchTitleField'
import { SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT, SourceBrowseTitleFieldContentBuilder } from '../components/SourceBrowseTitleField'
import { KomgaSeriesPage, KomgaSeriesRouteParam } from './KomgaSeriesPage'
import { KavitaBrowsePage, KavitaBrowseRouteParam } from './KavitaBrowsePage'
import { OpdsBrowsePage, OpdsBrowseRouteParam } from './OpdsBrowsePage'
import { WebDavBrowsePage, WebDavBrowseRouteParam } from './WebDavBrowsePage'
import { LibraryCategoryManagementChrome, LibraryCategoryManagementPage } from './LibraryCategoryManagementPage'
import { KomgaServerPage } from './KomgaServerPage'
import { KavitaServerPage } from './KavitaServerPage'
import { OpdsServerPage } from './OpdsServerPage'
import { SourcePackageManagerPage } from './SourcePackageManagerPage'
import { WebDavServerPage } from './WebDavServerPage'
import { DownloadsPage } from './DownloadsPage'
import { DownloadsChrome, DownloadsCommand } from '../state/DownloadsChrome'
import { LibraryUpdatesChrome } from '../state/LibraryUpdatesChrome'
import { BackupManagementPage } from './BackupManagementPage'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { TrackerSettingsPage } from './TrackerSettingsPage'
import { RouteName, TabIndex, tabLabel } from '../common/Constants'
import { MangaDetailTitleAction, MangaDetailRouteChromeState } from '../state/MangaDetailRouteChromeState'
import {
  MangaDetailRouteParam,
  MangaWebRouteParam,
  RouterHelper,
  SearchRouteParam,
  SourceBrowseRouteParam,
  SourcePackageManagerRouteParam,
  SourceRelatedRouteParam,
  SourceSearchRouteParam,
} from '../common/RouterHelper'
import { KomaTabIcon } from '../components/KomaTabIcon'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  LibraryPresentationByComicId,
  ContinueReadingCardViewModel,
  createLibraryContinueReadingCard,
  MOCK_LIBRARY_READER_SESSION,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import {
  Chapter,
  Comic,
  ComicId,
  ComicSourceKind,
  copyComicShell,
  ReadingDirection,
  Page,
  ReadingProgress,
  setCompleteSourceChapterCatalog,
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
import { LibraryStore } from '../model/LibraryStore'
import type { LibraryShelfSyncEdits } from '../model/LibraryRdbStorage'
import { privateLibraryCategoryIds, showLibraryComic } from '../model/LibraryPrivacyVisibility'
import { connectLibraryPrivacyState, LibraryPrivacyAuthResult, LibraryPrivacyState, libraryPrivacyAuthMessage } from '../state/LibraryPrivacyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import {
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
  applyLibraryShelfSyncEdits,
  editComicCategoriesAndPersistLibraryStore,
  isRemovableLocalComic,
  isRemovableShelfComic,
  localLibraryFolderComicsForRoot,
  removeComicAndPersistLibraryStore,
  removeComicsAndPersistLibraryStore,
  retainLibrarySourceNameAndPersist,
  upsertComicAndPersistLibraryStore,
  upsertLocalLibraryFolderScanAndPersistLibraryStore,
  upsertLocalLibraryFolderRescanAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { OfflineDownloadQueueStore } from '../model/OfflineDownloadQueueStore'
import { validateStoredDownloadManifestAsync } from '../model/OfflineDownloadManifestWorker'
import {
  OfflineDownloadedChapterStatus,
  OfflineDownloadManifestValidation,
} from '../model/OfflineDownloadStore'
import {
  ensureKomaContentStorageBase,
  komaContentStorageBase,
  komaContentStorageUri,
  komaRuntimeStorageKey,
} from '../model/KomaContentStorage'
import {
  appReaderSessionStore,
  InMemoryReaderSessionStore,
  ReaderSessionConfig,
  ReadingPresentationChange,
  ReaderSessionStore,
  cloneReaderSessionConfig,
  createReaderSessionConfigFromComic,
  getReaderSessionPageId,
} from '../model/ReaderSessionStore'
import { SourceChapterPageFailure, SourceChapterPageHydrator, SourceChapterPageHydrationResult,
  SourceChapterPagesResolveResult, resolveSourceChapterPages, sourceChapterPagesMatchSettings } from '../model/SourceChapterPageHydrator'
import {
  SourceReadHistoryEntry,
  SourceReaderSessionRequest,
  cloneSourceReaderSessionRequest,
  mergeSourceReaderResumeRequest,
  sourceReadHistoryEntryFromRequest,
  sourceReaderSessionRequestFromHistory,
  sourceReaderSessionRequestForChapter,
} from '../model/SourceReaderSession'
import { SourceRuntimeRegistry, sourceRuntimeEntryEnabled } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { connectSourceRuntimeState, SourceRuntimeState } from '../state/SourceRuntimeState'
import { SourceManga } from '../model/SourceModels'
import {
  appSourceRuntimeRegistry,
  bootstrapSourceRuntimeAppRegistry,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import { appSourceSettingsStore, configureSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { appSourceWebSessionStore, sourceWebOrigin } from '../sourceRuntime/SourceWebSessionStore'
import { openSourceWebSession, prepareSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { clearSourceRejectedRequest, sourceRejectedRequestUrl } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { newSourceRuntimeOperationGuardId, registerSourceRuntimeOperationGuard } from '../sourceRuntime/SourceRuntimeOperationGuard'
import { ReaderSourceWebChallenge } from '../readerLab/ReaderSourceWebChallenge'
import { normalizeSourceHomepage } from '../sourceRuntime/SourcePackageMetadata'
import { selectedSourceHomepage } from '../sourceRuntime/SourceHomepageSelection'
import { configureSourceFilterPreferencesStore } from '../sourceRuntime/SourceFilterPreferencesStore'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectIncognitoState, IncognitoState } from '../state/IncognitoState'
import { IncognitoStatusBarOverlay } from '../components/IncognitoStatusBarOverlay'
import { BackupService, BackupAutomaticRunResult } from '../model/BackupService'
import { TrackerPendingProgressDrainSummary, TrackerProgressSyncService } from '../model/TrackerProgressSyncService'
import { ReaderTrackerProgressCoordinator } from '../model/TrackerReadingProgress'
import { SourceBrowseRouteChromeState, SourceSearchRouteChromeState } from '../state/SourceRouteChromeState'
import { SourceBrowseLayout, SourceBrowseLayoutPreferences } from '../model/SourceBrowseLayoutPreferences'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'
import { AppForegroundState, connectAppForegroundState } from '../state/AppForegroundState'
import { RootNavigationState } from '../state/RootNavigationState'
import { shouldSuppressKomaDeviceVerificationBackgroundSideEffects } from '../state/KomaDeviceVerificationIsolation'
import { LibraryUpdateState, connectLibraryUpdateState } from '../state/LibraryUpdateState'
import { LibraryUpdateCheckResult, pendingLibraryUpdateCheck, requestLibraryUpdateCheck } from '../model/LibraryUpdateCoordinator'

const readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
const seededLibraryStore: LibraryStore = createSeededLibraryStore()
const libraryPresentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
const sourceRuntimeRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
// HDS uses one slot for More when the source has more than three actions.
const SOURCE_ROUTE_TITLE_MENU_MAX_COUNT = 3
const SETTINGS_MODAL_ROUTE = 'SettingsModal'
const ROOT_BACK_CONFIRMATION_MS: number = 1000
const SETTINGS_MODAL_HOME = 'SettingsModalHome'
interface ContinuationTargetPage {
  comicId: string
  chapterId: string
  pageIndex: number
}

interface SettingsPaneRouteParam {
  pane: string
  searchTarget?: string
  formTitleAction: FormTitleActionState
  modelSourcesTitleAction: ModelSourcesTitleAction
}

interface DeviceSyncWebDavRouteParam {
  chrome: DeviceSyncWebDavChrome
}

interface DeviceSyncConnectionRouteParam extends DeviceSyncWebDavRouteParam {
  titleKey: string
}

interface DeviceSyncReviewRouteParam extends DeviceSyncWebDavRouteParam {
  groups: SyncGroup[]
  reason: DeviceSyncReviewReason
}

interface SettingsSearchRouteParam {
  searchTarget: string
}

interface BackupManagementRouteParam {
  searchTarget: string
  scroller: Scroller
}

interface SettingsModalDestination {
  name: string
  param: Object
  scroller: Scroller
}

interface SettingsModalMotion {
  from: NavPathInfo
  to: NavPathInfo
  pushing: boolean
}

class SettingsModalLayoutFrame extends FrameCallback {
  private readonly onLayout: () => void

  constructor(onLayout: () => void) {
    super()
    this.onLayout = onLayout
  }

  onIdle(): void {
    this.onLayout()
  }
}

class StartupFrame extends FrameCallback {
  private readonly publish: () => void
  constructor(publish: () => void) {
    super()
    this.publish = publish
  }
  onFrame(_timestamp: number): void { this.publish() }
  onIdle(_timeLeft: number): void {}
}

@Entry
@ComponentV2
struct Index {
  private libraryUpdatesRefreshController: PullRefreshController = new PullRefreshController()
  private libraryManualUpdate?: Promise<void>
  private libraryUpdateBadgeRevision: number = 0
  @Local private enhancementModelsRevision: number = 0

  @Local private tabIconBounceTriggers: number[] = [-1, -1, -1, -1]
  @Local private readerLabLaunch: ReaderLabLaunchState = connectReaderLabLaunch()
  @Local private sharedReaderRequest: ReaderLabRequest = new ReaderLabRequest('', '', 0)
  private sharedReaderCatalogHost: KomaReaderCatalogHost | null = null
  private readerPreparation: Promise<void> | null = null
  @Local private readerEntryStage: KomaReaderEntryStage = 'chapter'
  @Local private detailTransition: MangaDetailTransitionState = connectMangaDetailTransition()
  @Local private readerRouteTransition: ReaderRouteTransition = new ReaderRouteTransition()

  private captureSharedReaderEntry(newRoute: boolean, animated: boolean = true): void {
    this.continuationObservedPage = undefined
    if (this.readerWebChallenge !== null) this.finishReaderWebChallenge(this.readerWebChallenge, false)
    if (newRoute) {
      if (animated) this.readerRouteTransition.begin()
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
  @Local private rootNavigation: RootNavigationState = new RootNavigationState()
  private lastRootBackAt: number | undefined = undefined
  @Local private settingsModalShown: boolean = false
  private settingsModalStack: NavPathStack = new NavPathStack()
  @Local private settingsModalTop?: NavPathInfo = undefined
  @Local private settingsModalMotion?: SettingsModalMotion = undefined
  @Local private settingsModalProgress: number = 1
  private afterSettingsModalDismiss?: () => void
  @Local private settingsModalDestination?: SettingsModalDestination = undefined
  @Local private importMenuShown: boolean = false
  @Local private trackerSettingsRevision: number = 0
  @Local private applicationSettingsRestoreRevision: number = 0
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
  @Local private appForegroundState: AppForegroundState = connectAppForegroundState()
  @Local private libraryPrivacy: LibraryPrivacyState = connectLibraryPrivacyState()
  private handledForegroundReauthRevision: number = 0
  @Local private incognito: IncognitoState = connectIncognitoState()
  @Local private libraryUpdateState: LibraryUpdateState = connectLibraryUpdateState()
  @Local private libraryUpdatesUnseen: boolean = false
  @Local private readerOpen: boolean = false
  @Local private readerClosing: boolean = false
  @Local private readerRouteVisible: boolean = false
  @Local private readerWebChallenge: ReaderSourceWebChallenge | null = null
  @Local private readerSessionLoading: boolean = false
  @Local private readerCloseRequestId: number = 0
  @Local private continuationState: ContinuationState = connectContinuationState()
  @Local private continuationRuntime: ReaderContinuationRuntimeState = connectReaderContinuationRuntimeState()
  @Local private continuationAwayResuming: boolean = false
  private continuationAwayDialogId: number = -1
  private continuationReadyForRestore: boolean = false
  private rootNavigationMounted: boolean = false
  private pendingContinuationAfterSourceInstall?: RestoredContinuationTask
  private activeContinuationRestore?: RestoredContinuationTask
  private continuationTargetPage?: ContinuationTargetPage
  private continuationObservedPage?: ContinuationTargetPage
  // Passed through the entry request when opening. Progress writes can update
  // the resume position without invalidating the navigation root mid-turn.
  private readerPageIndex: number = 0
  @Local private readerSessionConfig: ReaderSessionConfig = MOCK_LIBRARY_READER_SESSION
  // The reader writes this store directly. Bump the revision only after its
  // close path has flushed so LibraryPage can rebuild `lastRead` ordering from
  // the same in-memory snapshot rather than reopening a second store.
  @Local private readerProgressRevision: number = 0
  @Local private readingPresentationChange?: ReadingPresentationChange = undefined
  @Local private libraryRevision: number = 0
  private libraryPresentationPending: boolean = false
  private readingPresentationPending: boolean = false
  private pendingReadingComicIds?: string[]
  @Local private imageRuleState: ImageRuleState = connectImageRuleState()
  @Local private sourcePackageManagerCache: SourcePackageManagerCache = appSourcePackageManagerCache
  private migrationOpening: boolean = false
  private pendingMihonResume: string | undefined = undefined
  @Local private mihonSourceState: SourceRuntimeState = connectSourceRuntimeState()
  private mihonMatching: Promise<void> = Promise.resolve()
  private mihonSourceVersions: Map<string, string> = new Map()
  private mihonSourceVersionsLoaded: boolean = false
  private detailMenu: KomaMenuController = new KomaMenuController()
  private downloadsMenu: KomaMenuController = new KomaMenuController()
  private sourceBrowseMenu: KomaMenuController = new KomaMenuController()
  @Local private browseCatalogChrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  @Local private catalogFilters: SourceCatalogFilterState = appSourceCatalogFilters
  @Local private localSourceImport: SourcePackageLocalImport = appSourcePackageLocalImport
  private defaultSourceManagerChrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  private sourceManagerSectionContents: Map<SourceCatalogPageChrome, ComponentContent<SourceCatalogPageChrome>> = new Map()
  private catalogSearchContents: Map<SourceCatalogPageChrome, ComponentContent<SourceCatalogPageChrome>> = new Map()
  private catalogHeaderActions?: ComponentContent<SourceCatalogHeaderActionsParams>

  private catalogHeaderActionsContent(): ComponentContent<SourceCatalogHeaderActionsParams> {
    const existing = this.catalogHeaderActions
    if (existing !== undefined && !existing.isDisposed()) return existing
    const params = new SourceCatalogHeaderActionsParams(this.browseCatalogChrome,
      (): void => { this.setCatalogSearch(this.browseCatalogChrome, !this.browseCatalogChrome.searchExpanded) },
      (): void => { this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER) })
    const content = new ComponentContent<SourceCatalogHeaderActionsParams>(this.getUIContext(),
      wrapBuilder<[SourceCatalogHeaderActionsParams]>(SourceCatalogHeaderActionsBuilder), params)
    this.catalogHeaderActions = content
    return content
  }

  private catalogSearchContent(chrome: SourceCatalogPageChrome): ComponentContent<SourceCatalogPageChrome> {
    const existing = this.catalogSearchContents.get(chrome)
    if (existing !== undefined && !existing.isDisposed()) return existing
    const content = new ComponentContent<SourceCatalogPageChrome>(this.getUIContext(),
      wrapBuilder<[SourceCatalogPageChrome]>(SourceCatalogBottomSearchBuilder), chrome)
    this.catalogSearchContents.set(chrome, content)
    return content
  }

  private disposeCatalogSearch(chrome: SourceCatalogPageChrome): void {
    const content = this.catalogSearchContents.get(chrome)
    this.catalogSearchContents.delete(chrome)
    if (content !== undefined && !content.isDisposed()) content.dispose()
  }

  private setCatalogSearch(chrome: SourceCatalogPageChrome, expanded: boolean): void {
    if (chrome.searchExpanded === expanded) return
    const transition = ++chrome.searchTransitionId
    chrome.searchAnimating = true
    if (expanded) chrome.openSearch()
    else {
      this.getUIContext().getFocusController().clearFocus()
      chrome.closeSearch()
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut, onFinish: (): void => {
      if (chrome.searchTransitionId !== transition) return
      chrome.searchAnimating = false
      if (expanded && chrome.searchExpanded) chrome.searchFocus = true
      else if (!chrome.searchExpanded) chrome.searchVisible = false
    } }, (): void => { chrome.searchHeight = expanded ? SEARCH_TITLE_BOTTOM_HEIGHT : 0 })
  }

  private toggleManagerCatalogSearch(chrome: SourceCatalogPageChrome): void {
    // Adopted NextE downloads contract: replace the fixed segment slot; no extra bottom row.
    if (chrome.searchExpanded) {
      this.getUIContext().getFocusController().clearFocus()
      chrome.closeSearch()
      chrome.searchVisible = false
    } else chrome.openSearch()
  }

  private sourceManagerSectionContent(chrome: SourceCatalogPageChrome): ComponentContent<SourceCatalogPageChrome> {
    const existing = this.sourceManagerSectionContents.get(chrome)
    if (existing !== undefined && !existing.isDisposed()) return existing
    const content = new ComponentContent<SourceCatalogPageChrome>(this.getUIContext(),
      wrapBuilder<[SourceCatalogPageChrome]>(SourceCatalogSectionsBuilder), chrome)
    this.sourceManagerSectionContents.set(chrome, content)
    return content
  }

  private disposeSourceManagerSection(chrome: SourceCatalogPageChrome): void {
    const content = this.sourceManagerSectionContents.get(chrome)
    this.sourceManagerSectionContents.delete(chrome)
    if (content !== undefined && !content.isDisposed()) content.dispose()
  }

  private sourceManagerChrome(param?: SourcePackageManagerRouteParam): SourceCatalogPageChrome {
    if (param === undefined) return this.defaultSourceManagerChrome
    if (param.chrome === undefined) param.chrome = new SourceCatalogPageChrome()
    return param.chrome
  }

  private sourceManagerTitleBarOptions(param?: SourcePackageManagerRouteParam, stack: NavPathStack = this.appPathStack): Record<string, Object> {
    // Flat actions use HDS's native overflow; only Filter remains exposed.
    const options = this.navDestTitleBarOpts(AppStrings.get('route_source_package_manager_title'))
    if ((param?.settingsSourceId.length ?? 0) > 0) return options
    const chrome = this.sourceManagerChrome(param)
    const content = options['content'] as Record<string, Object>
    content['bottomBuilder'] = { 'builderComponent': this.sourceManagerSectionContent(chrome),
      'height': SOURCE_MANAGER_SECTIONS_HEIGHT,
      'showType': BottomBuilderShowType.DIRECTLY_SHOW } as Record<string, Object>
    if (chrome.section === 'plugins') {
      content['menu'] = (this.imagePluginsTitleBarOptions(stack)['content'] as Record<string, Object>)['menu']
      return options
    }
    const filter: Record<string, Object> = { 'label': AppStrings.get('common_filter'), 'icon': $r('sys.symbol.funnel'),
      'action': (): void => { chrome.request('filters') } }
    const local: Record<string, Object> = { 'label': AppStrings.get('source_pkg_local_import'), 'icon': $r('sys.symbol.folder'),
      'isEnabled': !this.localSourceImport.busy, 'action': (): void => { chrome.request('import') } }
    const subscriptions: Record<string, Object> = { 'label': AppStrings.get('source_pkg_index_url_heading'), 'icon': $r('sys.symbol.link'),
      'action': (): void => { stack.pushPath({ name: RouteName.SOURCE_SUBSCRIPTIONS, param: new SourceCatalogPageChrome() }) } }
    const filterItem: Record<string, Object> = { 'content': filter }
    const localItem: Record<string, Object> = { 'content': local }
    const subscriptionsItem: Record<string, Object> = { 'content': subscriptions }
    const search: Record<string, Object> = { 'label': AppStrings.get(chrome.searchExpanded ?
      'source_catalog_search_close' : 'source_catalog_search_placeholder'),
      'icon': chrome.searchExpanded ? $r('sys.symbol.xmark') : $r('sys.symbol.magnifyingglass'),
      'componentId': 'source-catalog-manager-search',
      'action': (): void => { this.toggleManagerCatalogSearch(chrome) } }
    const items: Record<string, Object>[] = (param?.recoverySourceId?.length ?? 0) > 0 ?
      [filterItem, localItem, subscriptionsItem] : [{ 'content': search }, filterItem, localItem, subscriptionsItem]
    content['menu'] = { 'value': items, 'maxCount': (param?.recoverySourceId?.length ?? 0) > 0 ? 2 : 3 } as Record<string, Object>
    return options
  }

  private imagePluginsTitleBarOptions(stack: NavPathStack = this.appPathStack): Record<string, Object> {
    const options = this.navDestTitleBarOpts(AppStrings.get('image_plugins_title'))
    const content = options['content'] as Record<string, Object>
    const subscriptions: Record<string, Object> = { 'label': AppStrings.get('source_pkg_index_url_heading'),
      'type': TextStyleMode.NORMAL, 'action': (): void => {
        stack.pushPath({ name: RouteName.SOURCE_SUBSCRIPTIONS, param: new SourceCatalogPageChrome() })
      } }
    const items: Record<string, Object>[] = [{ 'content': subscriptions }]
    content['menu'] = { 'value': items, 'maxCount': 1 } as Record<string, Object>
    return options
  }

  private sourceSubscriptionsTitleBarOptions(chrome: SourceCatalogPageChrome): Record<string, Object> {
    const options = this.navDestTitleBarOpts(AppStrings.get('source_pkg_index_url_heading'))
    const content = options['content'] as Record<string, Object>
    const add: Record<string, Object> = { 'label': AppStrings.get('source_pkg_add_subscription'),
      'type': TextStyleMode.NORMAL, 'action': (): void => { chrome.request('addSubscription') } }
    const items: Record<string, Object>[] = [{ 'content': add }]
    content['menu'] = { 'value': items, 'maxCount': 1 } as Record<string, Object>
    return options
  }

  private libraryCategoryTitleBarOptions(chrome: LibraryCategoryManagementChrome): Record<string, Object> {
    const options = this.navDestTitleBarOpts(AppStrings.get('route_library_categories_title'))
    const content = options['content'] as Record<string, Object>
    const add: Record<string, Object> = { 'label': AppStrings.get('library_category_create_section'),
      'icon': $r('sys.symbol.plus'), 'componentId': 'library-category-create',
      'action': (): void => { chrome.createRequest++ } }
    const items: Record<string, Object>[] = [{ 'content': add }]
    content['menu'] = { 'value': items, 'maxCount': 1 } as Record<string, Object>
    return options
  }

  private downloadsTitleBarOptions(chrome: DownloadsChrome): Record<string, Object> {
    // HDS keeps the modifier used by the play icon; refresh the title options
    // when the system changes colour mode, without changing queue state.
    void this.appearanceState.colorMode
    const title = chrome.selecting ? AppStrings.get('downloads_selected_count').replace('%s', String(chrome.selectedCount)) :
      AppStrings.get('route_downloads_title')
    const options = this.navDestTitleBarOpts(title)
    const content = options['content'] as Record<string, Object>
    const items: Record<string, Object>[] = []
    const iconAction = (label: string, icon: Resource | SymbolGlyphModifier, command: DownloadsCommand): void => {
      items.push({ 'content': { 'label': AppStrings.get(label), 'icon': icon,
        'action': (): void => { chrome.request(command) } } as Record<string, Object> })
    }
    // HDS can promote remaining items when the queue state changes. Give the
    // toolbar explicit symbol actions and keep localized text in the menu.
    if (chrome.selecting && chrome.hasVisible) {
      iconAction(chrome.allSelected ? 'downloads_deselect_all' : 'library_action_select_all',
        chrome.allSelected ? $r('sys.symbol.square') : $r('sys.symbol.checkmark_square'), 'toggleAll')
    } else if (!chrome.selecting && chrome.queueAction.length > 0) {
      let icon: Resource | SymbolGlyphModifier = $r('sys.symbol.pause')
      if (chrome.queueAction !== 'downloads_action_pause_all') {
        // Match the HDS icon size and center the triangle's visual weight.
        icon = new SymbolGlyphModifier($r('sys.symbol.play'))
          .fontSize(ThemeConstants.FONT_SIZE_H1).fontColor([$r('sys.color.font_primary')]).translate({ x: 2 })
      }
      iconAction(chrome.queueAction, icon, 'queue')
    } else if (!chrome.selecting && chrome.hasRetryable) {
      iconAction('downloads_action_retry_failed', $r('sys.symbol.arrow_clockwise'), 'retryAll')
    }
    const more: Record<string, Object> = { 'label': AppStrings.get('common_more_actions'),
      'icon': komaTitleMoreIcon(), 'componentId': chrome.menuAnchorId, 'action': (): void => {
        this.downloadsMenu.open(this.getUIContext(), chrome.menuAnchorId,
          (): KomaMenuGroup[] => [{ id: 'downloads', items: this.downloadsMenuActions(chrome) }],
          (): void => { DiagnosticLogger.warn('downloads', 'menu_open_failed', 'result=failed') })
      } }
    items.push({ 'content': more })
    content['menu'] = { 'value': items, 'maxCount': items.length } as Record<string, Object>
    return options
  }

  private downloadsMenuActions(chrome: DownloadsChrome): KomaMenuAction[] {
    const items: KomaMenuAction[] = []
    const add = (label: string, command: DownloadsCommand, visible: boolean = true): void => {
      if (!visible) return
      items.push({ label: AppStrings.get(label), action: (): void => { chrome.request(command) } })
    }
    if (chrome.selecting) {
      add('downloads_pause_selected', 'pauseSelected', chrome.canPauseSelected)
      add('downloads_resume_selected', 'resumeSelected', chrome.canResumeSelected)
      add('downloads_retry_selected', 'retrySelected', chrome.canRetrySelected)
      add('downloads_cancel_selected', 'cancelSelected', chrome.canCancelSelected)
      add('downloads_delete_selected', 'deleteSelected', chrome.canDeleteSelected)
      add('downloads_exit_selection', 'exitSelection')
    } else {
      add('downloads_cancel_all_tasks', 'cancelAll', chrome.hasTasks)
      add('downloads_action_retry_failed', 'retryAll', chrome.queueAction.length > 0 && chrome.hasRetryable)
      add('downloads_clear_failed', 'clearFailed', chrome.hasFailures)
      add('downloads_delete_all', 'deleteDownloaded', chrome.hasDownloaded)
      add('chapter_list_menu_enter_selection', 'select', chrome.hasVisible)
      add('downloads_action_rescan', 'rescan')
    }
    return items
  }

  private tabController: HdsTabsController = new HdsTabsController()
  @Local private resumeMiniBarExpanded: boolean = false
  private libraryScroller: ListScroller = new ListScroller()
  private rootTabScrollers: Scroller[] = [this.libraryScroller, new Scroller(), new Scroller(), new Scroller()]
  @Local private appearanceState: AppearanceState = connectAppearanceState()
  private bottomBarVisibleByScroll: boolean = true
  private bottomBarOffsets: number[] = [0, 0, 0, 0]
  private bottomBarAnimationTimer: number = -1
  @Local private titleScroller: Scroller = this.rootTabScrollers[TabIndex.LIBRARY]
  private tabBarHiddenForKeyboard: boolean = false
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private persistentReaderSessionStore: ReaderSessionStore | undefined = undefined
  private incognitoReaderSessionStore: ReaderSessionStore | undefined = undefined
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
  private sourceReaderOpenRequest: number = 0
  private historyResumeLoadingTimer: number = -1
  private historyResumeCanContinue?: () => boolean
  private historyResumeLoadingDialog: number = -1
  private readingConflictHold?: () => void
  /** Present only while Reader was launched from an un-shelved source item. */
  private activeSourceReaderRequest?: SourceReaderSessionRequest
  /** Read-only snapshots for Kavita and standalone downloads. */
  private activeReaderComicSnapshot?: Comic

  private readerComicForOpen(comicId: ComicId): Comic | undefined {
    if (this.activeReaderComicSnapshot?.id === comicId) return this.activeReaderComicSnapshot
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

  @Monitor('readerRouteVisible', 'readerOpen', 'readerSessionLoading', 'appForegroundState.active', 'continuationRuntime.continuedAway')
  private syncReadingSessionActivity(): void {
    const active = this.readerSessionPersistenceReady && this.readerOpen && this.readerRouteVisible &&
      !this.readerSessionLoading && this.appForegroundState.active && !this.continuationRuntime.continuedAway &&
      !this.privateContinuationSession(this.readerSessionConfig.comicId) &&
      !this.incognito.isSourceEnabled(this.readerSessionConfig.sourceRuntimeId)
    this.readingStatisticsRecorder.setActive(active)
    if (!active && this.readerSessionPersistenceReady) this.readerSessionStore.flush()
  }

  @Monitor('readerOpen', 'readerClosing', 'readerRouteVisible', 'readerSessionLoading', 'readerSessionConfig',
    'appForegroundState.active', 'incognito.enabled', 'incognito.sourceIds',
    'libraryPrivacy.unlocked', 'libraryPrivacy.presenting',
    'continuationState.enabled', 'continuationRuntime.continuedAway', 'libraryRevision',
    'libraryPrivacy.continuationPrivacyRevision')
  private syncReaderContinuationState(): void {
    const config = this.readerSessionConfig
    const observed = this.continuationObservedPage
    if (!this.continuationState.enabled || !this.readerOpen || !this.readerRouteVisible ||
      this.readerClosing || this.readerSessionLoading || !this.appForegroundState.active ||
      observed?.comicId !== config.comicId || observed.chapterId !== config.chapterId) {
      appReaderContinuation.publishActiveReading(undefined)
      return
    }
    const sourceRequest = this.activeSourceReaderRequest
    const usingSourceRequest = sourceRequest !== undefined && sourceRequest.comicId === config.comicId
    const privacySummary = this.libraryStore.getComicSummary(config.comicId)
    const activeComic = this.activeReaderComicSnapshot
    const comic = usingSourceRequest ? undefined : activeComic?.id === config.comicId ? activeComic : privacySummary
    const sourceId = usingSourceRequest ? sourceRequest.sourceId : (comic?.sourceRuntimeId ?? config.sourceRuntimeId)
    const mangaId = usingSourceRequest ? sourceRequest.mangaId : (comic?.remoteResourceId ?? '')
    const sourceKind = usingSourceRequest ? ComicSourceKind.PRIVATE_LIBRARY : (comic?.sourceKind ?? config.sourceKind)
    const privateCategoryId = privacySummary?.categoryIds?.find((id: string): boolean => this.privateCategoryIds.has(id))
    const standalonePrivate = this.privateContinuationSession(config.comicId)
    const requiresPrivacyAuth = standalonePrivate || privateCategoryId !== undefined
    const eligible = canContinueSourceSession({
      continuationEnabled: this.continuationState.enabled,
      readerOpen: this.readerOpen && this.appForegroundState.active,
      readerClosing: this.readerClosing,
      readerRouteVisible: this.readerRouteVisible && this.isReaderRouteVisible(),
      readerSessionLoading: this.readerSessionLoading,
      continuedAway: this.continuationRuntime.continuedAway,
      incognitoEnabled: this.incognito.enabled,
      sourceIncognitoEnabled: this.incognito.isSourceEnabled(sourceId),
      privacyLocked: this.showPrivateRouteLock() ||
        (requiresPrivacyAuth && (!this.libraryPrivacy.presenting ||
          (standalonePrivate ? !this.libraryPrivacy.visibleContinuation(config.comicId) : !this.libraryPrivacy.unlocked))),
      sourceKind,
      sourceId,
      mangaId,
      chapterId: config.chapterId,
    })
    if (!eligible || sourceId === undefined || sourceId.trim().length === 0 || mangaId.trim().length === 0) {
      appReaderContinuation.publishActiveReading(undefined)
      return
    }
    const resolvedSourceName = sourceDisplayName(sourceId,
      (usingSourceRequest ? sourceRequest.sourceName : comic?.sourceMetadata?.sourceName) ?? sourceId)
    const snapshot: ReaderContinuationSnapshot = {
      sourceId,
      sourceName: resolvedSourceName,
      mangaId,
      comicId: config.comicId,
      title: (usingSourceRequest ? sourceRequest.title : comic?.title) ?? config.title ?? config.comicId,
      chapterId: config.chapterId,
      pageIndex: observed.pageIndex,
      totalPages: Math.max(0, config.totalPages),
      requiresPrivacyAuth,
    }
    const mangaUrl = usingSourceRequest ? sourceRequest.mangaUrl : (comic?.sourcePath ?? config.sourceMangaUrl)
    if (mangaUrl !== undefined && mangaUrl.length > 0) snapshot.mangaUrl = mangaUrl
    const coverUri = usingSourceRequest ? sourceRequest.coverUri : comic?.coverUri
    if (coverUri !== undefined && coverUri.length > 0) snapshot.coverUri = coverUri
    const readingFormat = usingSourceRequest ? sourceRequest.readingFormat : config.readingFormat
    if (readingFormat !== undefined) snapshot.readingFormat = readingFormat
    if (config.chapterTitle !== undefined && config.chapterTitle.length > 0) snapshot.chapterTitle = config.chapterTitle
    if (privateCategoryId !== undefined) snapshot.privateCategoryId = privateCategoryId
    appReaderContinuation.publishActiveReading(snapshot)
  }

  private tryStartPendingContinuationTask(): void {
    if (this.continuationReadyForRestore && this.rootNavigationMounted &&
      this.appForegroundState.active && !this.readerClosing && this.continuationRuntime.pendingTaskId > 0) {
      void this.processPendingContinuationTask().catch((error: Error): void => {
        DiagnosticLogger.exception('continuation', 'target_open_failed', error)
      })
    }
  }

  @Monitor('continuationRuntime.pendingTaskId', 'appForegroundState.active', 'readerClosing')
  private onContinuationTaskChanged(): void {
    this.tryStartPendingContinuationTask()
  }

  @Monitor('continuationRuntime.continuedAway')
  private onContinuedAwayChanged(): void {
    if (!this.continuationRuntime.continuedAway) {
      this.closeContinuationAwayDialog()
    }
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
    if (this.bottomBarVisibleByScroll) this.tabController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
  }

  @Monitor('appearanceState.autoHideBottomBar')
  private applyBottomBarAutoHide(): void {
    this.rootTabScrollers.forEach((scroller: Scroller, index: number): void => {
      this.tabController.unbindScroller(scroller)
      if (this.appearanceState.autoHideBottomBar) this.tabController.bindScroller(index, scroller)
    })
    this.restoreBottomBar()
  }

  private restoreBottomBar(): void {
    if (this.bottomBarVisibleByScroll) return
    this.bottomBarVisibleByScroll = true
    if (!this.tabBarHiddenForKeyboard) this.tabController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
  }

  private onRootTabScroll(index: number, offset: number, state: ScrollState): void {
    // Accumulate small scroll updates so a slow reverse gesture also restores the bar.
    const previous = this.bottomBarOffsets[index]
    if (index !== this.selectedTab || !this.appearanceState.autoHideBottomBar || this.tabBarHiddenForKeyboard) {
      this.bottomBarOffsets[index] = offset
      return
    }
    if (offset <= 6) {
      this.bottomBarOffsets[index] = offset
      this.restoreBottomBar()
      return
    }
    if (state === ScrollState.Idle || this.bottomBarAnimationTimer !== -1) return
    const delta = offset - previous
    if (Math.abs(delta) <= 6) return
    this.bottomBarOffsets[index] = offset
    const visible = delta < 0
    if (visible === this.bottomBarVisibleByScroll) return
    this.bottomBarVisibleByScroll = visible
    if (visible) this.tabController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    else this.tabController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    this.bottomBarAnimationTimer = setTimeout((): void => { this.bottomBarAnimationTimer = -1 }, 180)
  }

  @Monitor('libraryUpdateState.revision')
  private onLibraryUpdateCompleted(): void {
    this.refreshLibraryUpdateBadge(getContext(this) as common.UIAbilityContext)
    if (this.libraryUpdateState.shelfChanged) this.refreshLibrarySnapshot()
  }

  private refreshLibrarySnapshot(): void {
    this.libraryPresentationPending = true
    if (!this.isReaderRouteVisible()) this.publishDeferredReaderBackgroundPresentation()
    this.resumeAutomaticDownloadQueue()
  }

  @Computed
  private get continueReadingCard(): ContinueReadingCardViewModel {
    return this.latestVisibleContinueReadingCard('')
  }

  @Computed
  private get scopedContinueReadingCard(): ContinueReadingCardViewModel | undefined {
    const scope = this.libraryPrivacy.visibleCategoryId
    return scope.length > 0 ? this.latestVisibleContinueReadingCard(scope) : undefined
  }

  private latestVisibleContinueReadingCard(scope: string): ContinueReadingCardViewModel {
    // A private work can contribute only while its current category is unlocked.
    void this.libraryRevision
    void this.readerProgressRevision
    void this.languageState.effectiveLocale
    const candidates: Comic[] = []
    const positions = new Map<ComicId, ReadingProgress>()
    const latest = this.readerSessionStore.latestMatchingProgress((progress: ReadingProgress): boolean => {
      const comic = this.libraryStore.getComicSummary(progress.comicId)
      if (comic === undefined || !showLibraryComic(comic, this.privateCategoryIds, scope)) return false
      const saved = this.libraryStore.shelfProgress(comic, progress)
      if (saved === undefined) return false
      positions.set(comic.id, saved)
      return true
    })
    for (const progress of latest) {
      const comic = this.libraryStore.getComicSummary(progress.comicId)
      if (comic !== undefined) candidates.push(comic)
    }
    // Only equal last-read times need the existing shelf title tie-breaker.
    candidates.sort((left: Comic, right: Comic): number =>
      left.sortTitle.localeCompare(right.sortTitle) || left.createdAt - right.createdAt)
    return createLibraryContinueReadingCard(candidates, this.readerSessionStore, this.presentationByComicId,
      positions, (id: ComicId, chapterId?: string): string | undefined =>
        this.libraryStore.readComicChapterTitle(id, chapterId))
  }

  @Computed
  private get privateCategoryIds(): Set<string> {
    void this.libraryRevision
    return privateLibraryCategoryIds(this.libraryStore.listCustomCategories())
  }

  @Monitor('libraryRevision')
  private reconcileLibraryPrivacy(): void {
    const scope = this.libraryPrivacy.categoryId
    if (scope.length > 0 && !this.privateCategoryIds.has(scope)) this.libraryPrivacy.leaveCategory()
  }

  private canOpenLibraryComic(comicId: ComicId): boolean {
    return showLibraryComic(this.libraryStore.getComicSummary(comicId), this.privateCategoryIds, this.libraryPrivacy.visibleCategoryId)
  }

  private readerChapterIdForComic(comic: Comic): string | undefined {
    const progress = this.readerSessionStore.getComicProgress(comic)
    if (progress !== undefined && comic.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId)) {
      return progress.chapterId
    }
    return firstReaderChapter(chapterReadingChaptersFor(comic.id, comic.chapters), sourceChapterOrderFor(comic.sourceRuntimeId),
      (id: string): boolean => this.readerSessionStore.isChapterRead(comic.id, id), chapterReadingSortFor(comic.id))?.id
  }

  private openLibraryContinueReading(comicId: ComicId): void {
    const comic = this.libraryStore.getComic(comicId)
    if (comic === undefined) {
      this.showToast(AppStrings.get('common_unavailable'))
      return
    }
    const chapterId = this.readerChapterIdForComic(comic)
    void this.openReader(comicId, chapterId)
  }

  private resumeMiniBarCard(): ContinueReadingCardViewModel {
    const scoped = this.scopedContinueReadingCard
    if (this.libraryPrivacy.visibleCategoryId.length > 0 && scoped !== undefined &&
      this.canOpenLibraryComic(scoped.comicId)) return scoped
    return this.continueReadingCard
  }

  private canShowResumeMiniBar(): boolean {
    // This device's bottom MiniBar preference is independent of the shelf card.
    const comicId = this.resumeMiniBarCard().comicId
    return this.appearanceState.showResumeMiniBar && comicId.length > 0 && this.canOpenLibraryComic(comicId) &&
      (this.selectedTab !== TabIndex.LIBRARY || !this.libraryTitleBar.selectionMode)
  }

  private resumeMiniBarOptions(): HdsTabsMiniBar | undefined {
    if (!this.canShowResumeMiniBar()) {
      return undefined
    }
    // Let HdsTabs size the expanded slot for the current window.
    return {
      miniBarBuilder: (): void => { this.ResumeMiniBarContent() },
      // Only style changes own the content state. An interrupted animation can
      // report its old style after the user has switched the bar again.
      onBarStyleChange: (style: HdsBarStyle): void => {
        this.resumeMiniBarExpanded = style === HdsBarStyle.EXPAND
      },
    }
  }

  @Builder
  private ResumeMiniBarContent() {
    LibraryResumeMiniBar({
      info: this.resumeMiniBarCard(),
      expanded: this.resumeMiniBarExpanded,
      onContinueReading: (comicId: ComicId): void => {
        if (this.resumeMiniBarExpanded && this.canShowResumeMiniBar() &&
          comicId === this.resumeMiniBarCard().comicId) {
          this.tabController.applyMiniBarStyle(HdsBarStyle.COLLAPSE)
          this.openLibraryContinueReading(comicId)
        }
      },
    })
  }

  private queueReadingPresentation(comicIds?: string[]): void {
    if (!this.readingPresentationPending) this.pendingReadingComicIds = comicIds
    else if (comicIds === undefined) this.pendingReadingComicIds = undefined
    else if (this.pendingReadingComicIds !== undefined) {
      this.pendingReadingComicIds = Array.from(new Set(this.pendingReadingComicIds.concat(comicIds)))
    }
    this.readingPresentationPending = true
  }

  private refreshReadingPresentation(comicIds?: string[], immediate: boolean = false): void {
    this.queueReadingPresentation(comicIds)
    if (immediate || !this.isReaderRouteVisible()) this.publishDeferredReaderBackgroundPresentation()
  }

  /** The stores and sync continue live. Refresh the covered views when Reader yields the route. */
  private publishDeferredReaderBackgroundPresentation(): void {
    if (this.libraryPresentationPending) {
      this.libraryPresentationPending = false
      this.libraryRevision += 1
    }
    if (this.readingPresentationPending) {
      this.readingPresentationPending = false
      const ids = this.pendingReadingComicIds
      this.pendingReadingComicIds = undefined
      this.readingPresentationChange = ids === undefined ? undefined : { revision: this.readerProgressRevision + 1, comicIds: ids }
      this.readerProgressRevision += 1
    }
  }

  private cleanupService(): ReadDownloadCleanup {
    if (this.readDownloadCleanup === undefined) {
      this.readDownloadCleanup = new ReadDownloadCleanup()
    }
    return this.readDownloadCleanup
  }

  private resumeAutomaticDownloadQueue(): void {
    if (!this.libraryUpdateReady || shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) return
    if (this.automaticDownloads === undefined) {
      this.automaticDownloads = new AutomaticDownloadController({ context: getContext(this) as common.UIAbilityContext,
        library: this.libraryStore, registry: this.sourceRegistry })
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
      if (result !== undefined) this.showLibraryUpdateResult(result, false)
    }).catch((_error: Error) => {
      DiagnosticLogger.warn('index', 'foreground_check_failed', '[LibraryUpdate] step=foreground_check_failed')
    })
  }

  private checkLibraryUpdatesNow(showStart: boolean = false): Promise<void> {
    if (this.libraryManualUpdate !== undefined) return this.libraryManualUpdate
    if (showStart && this.appForegroundState.active) this.showLibraryUpdateToast(AppStrings.get('library_updates_checking'))
    this.libraryManualUpdate = this.runLibraryUpdateCheck().finally((): void => { this.libraryManualUpdate = undefined })
    return this.libraryManualUpdate
  }

  private async runLibraryUpdateCheck(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      await applyBackgroundLibraryResults(context, this.libraryStore, this.libraryPersistenceService)
      const result = await requestLibraryUpdateCheck({ context, libraryStore: this.libraryStore,
        sourceRegistry: this.sourceRegistry, libraryPersistenceService: this.libraryPersistenceService,
        reason: 'manual', requireForeground: true })
      this.showLibraryUpdateResult(result, true)
    } catch (error) {
      DiagnosticLogger.exception('library_updates', 'check_failed', error as Error)
      if (this.appForegroundState.active) this.showLibraryUpdateToast(AppStrings.get('library_updates_check_failed'))
    }
  }

  private showLibraryUpdateToast(message: string): void {
    this.getUIContext().getPromptAction().showToast(komaToastOptions({ message }))
  }

  private showLibraryUpdateResult(result: LibraryUpdateCheckResult, manual: boolean): void {
    if (!this.appForegroundState.active) return
    const summary = result.summary
    const count = summary === undefined ? 0 : countLibraryUpdateNewChapters(summary)
    if (count > 0) {
      this.showLibraryUpdateToast(AppStrings.get('library_update_found_new_chapters').replace('%s', `${count}`))
    } else if (manual) {
      const failed = result.status === 'failed' || result.status === 'unavailable' ||
        (summary !== undefined && classifyLibraryUpdateSummary(summary) === 'all-failed')
      this.showLibraryUpdateToast(AppStrings.get(result.persistenceFailed ? 'library_updates_save_failed' :
        failed ? 'library_updates_check_failed' : 'library_update_no_new_chapters'))
    }
  }

  private async refreshBookshelf(): Promise<void> {
    try {
      await this.syncFromRootRefresh()
    } finally {
      // Include newly synced books and avoid competing for the library write guard.
      void this.checkLibraryUpdatesNow(true)
    }
  }

  private async syncFromRootRefresh(): Promise<void> {
    try {
      await appDeviceSync.syncFromRefresh()
    } catch (error) {
      const checking = pendingLibraryUpdateCheck()
      if ((error as Error).message !== 'sync_local_busy' || checking === undefined) throw error as Error
      await checking.catch(() => {})
      await appDeviceSync.syncFromRefresh()
    }
  }

  private libraryUpdatesTitleBarOptions(chrome: LibraryUpdatesChrome): Record<string, Object> {
    const options = this.navDestTitleBarOpts(chrome.selecting
      ? AppStrings.get('chapter_list_selected_count').replace('%s', `${chrome.selectedKeys.size}`)
      : AppStrings.get('library_updates_title'))
    const content = options['content'] as Record<string, Object>
    // Clearing the override restores the system back button after selection.
    const close: Record<string, Object> = {
      'label': AppStrings.get('common_cancel'), 'icon': $r('sys.symbol.xmark'), 'isEnabled': !chrome.busy,
      'action': (): void => { if (!chrome.busy) chrome.exitSelection() },
    }
    content['backIcon'] = chrome.selecting ? close : {} as Record<string, Object>
    if (chrome.selecting) {
      const select: Record<string, Object> = {
        'label': AppStrings.get(chrome.allSelected ? 'chapter_list_menu_deselect_all_filtered' :
          'chapter_list_menu_select_all_filtered'),
        'icon': chrome.allSelected ? $r('sys.symbol.square') : $r('sys.symbol.checkmark_square'),
        'isEnabled': !chrome.busy, 'action': (): void => { chrome.request('toggleAll') },
      }
      const enabled = chrome.selectedKeys.size > 0 && !chrome.busy
      const download: Record<string, Object> = { 'label': AppStrings.get('manga_detail_action_download_chapter'),
        'isEnabled': enabled, 'action': (): void => { chrome.request('download') } }
      const mark: Record<string, Object> = { 'label': AppStrings.get('chapter_list_menu_mark_read'),
        'isEnabled': enabled, 'action': (): void => { chrome.request('markRead') } }
      const items: Record<string, Object>[] = [{ 'content': select }, { 'content': download }, { 'content': mark }]
      content['menu'] = { 'value': items, 'maxCount': 2 } as Record<string, Object>
      return options
    }
    // The dot follows the unread-only view, independently of the shelf's new-update badge.
    const visibilityIcon: Resource | SymbolGlyphModifier = chrome.unreadOnly
      ? new SymbolGlyphModifier($r('sys.symbol.envelope_badge_dot')).fontSize(ThemeConstants.FONT_SIZE_H1)
        .fontColor([ThemeConstants.BRAND_PRIMARY])
      : $r('sys.symbol.envelope')
    const visibility: Record<string, Object> = { 'label': AppStrings.get(chrome.unreadOnly ?
      'library_updates_show_all' : 'library_updates_unread_only'), 'icon': visibilityIcon,
      'action': (): void => {
        chrome.unreadOnly = !chrome.unreadOnly
        this.showLibraryUpdateToast(AppStrings.get(chrome.unreadOnly ?
          'library_updates_showing_unread' : 'library_updates_showing_all'))
      } }
    const check: Record<string, Object> = { 'label': AppStrings.get('source_pkg_check_updates'),
      'icon': $r('sys.symbol.arrow_clockwise'), 'isEnabled': !this.libraryUpdateState.busy,
      'action': (): void => { this.libraryUpdatesRefreshController.triggerTopRefresh() } }
    const items: Record<string, Object>[] = [{ 'content': visibility }, { 'content': check }]
    content['menu'] = { 'value': items, 'maxCount': 2 } as Record<string, Object>
    return options
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
    const firstChapter = firstReaderChapter(chapterReadingChaptersFor(comic.id, comic.chapters), sourceChapterOrderFor(comic.sourceRuntimeId),
      (id: string): boolean => this.readerSessionStore.isChapterRead(comic.id, id), chapterReadingSortFor(comic.id))
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

  private async readOfflineReaderChapter(comicId: ComicId, chapterId: string | undefined):
    Promise<OfflineDownloadManifestValidation | undefined> {
    if (chapterId === undefined || chapterId.length === 0) {
      return undefined
    }
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        return undefined
      }
      const root = komaContentStorageBase(context)
      const key = komaRuntimeStorageKey(context)
      const queue = new OfflineDownloadQueueStore(root, key)
      const before = queue.loadTask({ comicId, chapterId })
      const validation = await validateStoredDownloadManifestAsync(root, key, comicId, chapterId,
        { validateContentHash: false })
      if (before !== undefined) queue.recordChapterAvailability(before, validation)
      return validation
    } catch (_error) {
      DiagnosticLogger.warn('index', 'open_manifest_probe', '[ReaderOffline] step=open_manifest_probe failed=true reason=manifest_session')
      return undefined
    }
  }

  private async readReaderPagesWithVerification<T>(sourceId: string | undefined,
    read: (guardId?: string) => Promise<T>, current?: () => boolean): Promise<T> {
    const entry = sourceId === undefined ? undefined : this.sourceRegistry.lookup(sourceId).entry
    if (sourceId === undefined || entry === undefined || current === undefined || (entry.webSessionOrigins ?? []).length === 0) {
      return read()
    }
    const guard = newSourceRuntimeOperationGuardId()
    const release = registerSourceRuntimeOperationGuard(guard, current)
    try {
      // Page plans return structured failures; chapter catalogues throw them.
      // Both belong to the same visible reader operation and exact HTTP retry.
      let result: T | undefined = undefined
      let failure: SourceRuntimeError | undefined = undefined
      try { result = await read(guard) } catch (error) {
        if (!(error instanceof SourceRuntimeError)) throw error as Error
        failure = error
      }
      const details = failure?.diagnostic ?? (result as SourceChapterPageFailure | undefined)?.sourceFailure
      const finish = (): T => {
        if (failure !== undefined) throw failure
        return result as T
      }
      if (details?.kind !== 'challenge' || !current()) return finish()
      const pending = this.readerWebChallenge
      if (pending !== null) {
        if (pending.params.sourceSession?.sourceId !== sourceId) return finish()
        const verified = await pending.completed
        return verified && current() ? await read(guard) : finish()
      }
      const exactUrl = sourceRejectedRequestUrl(sourceId, guard)
      if (exactUrl.length === 0 || !(entry.webSessionOrigins ?? []).includes(sourceWebOrigin(exactUrl))) return finish()
      const params = prepareSourceWebSession(sourceId, entry.manifestName, guard)
      if (params?.sourceSession === undefined) return finish()
      const verified = await new Promise<boolean>((resolve: (value: boolean) => void): void => {
        this.readerWebChallenge = new ReaderSourceWebChallenge(params, current, resolve)
      })
      return verified && current() ? await read(guard) : finish()
    } finally {
      release()
      clearSourceRejectedRequest(sourceId, guard)
    }
  }

  private finishReaderWebChallenge(request: ReaderSourceWebChallenge, verified: boolean): void {
    if (this.readerWebChallenge !== request) return
    this.readerWebChallenge = null
    request.finish(verified)
  }

  private readerPageRequestCurrent(openEpoch: number): boolean {
    return this.readerOpenEpoch === openEpoch && this.readerOpen && !this.readerClosing
  }

  private async ensureReaderSourceChapterPages(comic: Comic, chapterId: string | undefined,
    onSourceFailure?: (reason: string | undefined, details?: SourceFailureDetails) => void,
    forceRefresh: boolean = false, current?: () => boolean): Promise<boolean> {
    if (!forceRefresh && !this.chapterNeedsReaderSourcePages(comic, chapterId)) {
      return true
    }
    try {
      const hydrator = new SourceChapterPageHydrator(
        this.libraryStore,
        this.sourceRegistry,
        this.ensureLibraryPersistenceService(),
        () => {
          this.refreshLibrarySnapshot()
        },
      )
      const result = await this.readReaderPagesWithVerification<SourceChapterPageHydrationResult>(comic.sourceRuntimeId,
        (guard?: string): Promise<SourceChapterPageHydrationResult> =>
          hydrator.ensureChapterPages(comic.id, comic.sourceRuntimeId, chapterId as string, forceRefresh, guard), current)
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
    offline: Promise<OfflineDownloadManifestValidation | undefined>,
    checkOffline: boolean,
  ): Promise<void> {
    let originalComic = this.readerComicForOpen(comicId)
    if (originalComic === undefined) {
      if (openEpoch === this.readerOpenEpoch) {
        this.readerSessionLoading = false
      }
      return
    }
    if (this.readerPageRequestCurrent(openEpoch) && originalComic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE) {
      this.readerEntryStage = 'local'
    }
    await this.upgradeLegacyEpubOrder(originalComic, openEpoch)
    if (!this.readerPageRequestCurrent(openEpoch)) return
    originalComic = this.readerComicForOpen(comicId) ?? originalComic
    if (originalComic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
      const rootUri = localLibraryFolderRootUriFromComic(originalComic)
      if (rootUri !== undefined) {
        this.readerEntryStage = 'local'
        const access = await activateLocalLibraryFolderAccess(rootUri)
        console.info('[LocalFolderAccess] step=reader_activate status=' + access.status)
      }
    }
    if (!this.readerPageRequestCurrent(openEpoch)) return
    if (checkOffline) this.readerEntryStage = 'offline'
    const validation = await offline
    if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) return
    const offlineReaderPagesReady = validation?.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
      validation?.status === OfflineDownloadedChapterStatus.PARTIAL
    let sourcePagesReady = true
    let sourceFailureReason: string | undefined = undefined
    let sourceFailure: SourceFailureDetails | undefined = undefined
    if (!offlineReaderPagesReady && this.chapterNeedsReaderSourcePages(originalComic, chapterId)) {
      this.readerEntryStage = 'source'
      sourcePagesReady = await this.ensureReaderSourceChapterPages(originalComic, chapterId,
        (reason: string | undefined, details?: SourceFailureDetails): void => { sourceFailureReason = reason; sourceFailure = details },
        false, (): boolean => this.readerPageRequestCurrent(openEpoch))
    }
    const comic = this.readerComicForOpen(comicId) ?? originalComic
    if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) {
      return
    }
    this.readerEntryStage = 'chapter'
    let nextSessionConfig = createKomaReaderLabOfflineConfig(createReaderSessionConfigFromComic(comic, chapterId), validation)
    if (!sourcePagesReady && nextSessionConfig.totalPages <= 0) {
      nextSessionConfig = this.createSourceUnavailableReaderSessionConfig(comic, chapterId, nextSessionConfig, sourceFailureReason, sourceFailure)
    }
    this.readerSessionConfig = nextSessionConfig
    this.readerPageIndex = this.openPageIndexForSession(nextSessionConfig, this.readerOpenIntent, true)
    // Terminal publication: the one-shot crossing intent has been consumed.
    this.readerOpenIntent = 'resume'
    this.readerSessionLoading = false
  }

  /** A legacy EPUB is changed only when every saved position maps to the same
   * image in the corrected spine. Pin old page IDs before publishing the new
   * list so an interrupted write cannot move the reader to another image. */
  private async upgradeLegacyEpubOrder(comic: Comic, openEpoch: number): Promise<void> {
    if (!this.readerSessionPersistenceReady || comic.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE ||
      !/\.epub$/i.test(comic.sourcePath) || comic.localImportOrigin?.epubOrderRevision === 1 ||
      comic.chapters.length !== 1 || this.activeReaderComicSnapshot?.id === comic.id) return
    const root = comicArchiveExtractionRoot(comic.chapters[0].pages[0]?.uri ?? '')
    if (root === undefined) return
    try {
      const paths = await readOrderedEpubImages(root)
      await BackupRestoreActivity.runWrite(async (): Promise<void> => {
        if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) return
        const current = this.libraryStore.getComic(comic.id)
        if (current === undefined || current.sourcePath !== comic.sourcePath || current.chapters.length !== 1 ||
          current.chapters[0].id !== comic.chapters[0].id || current.localImportOrigin?.epubOrderRevision === 1) return
        const chapterId = current.chapters[0].id
        const positions: ReadingProgress[] = []
        const recent = this.readerSessionStore.getProgress(current.id)
        if (recent !== undefined && recent.chapterId === chapterId) positions.push(recent)
        const chapter = this.readerSessionStore.getChapterProgress(current.id, chapterId)
        if (chapter !== undefined) positions.push(chapter)
        const plan = planLegacyEpubOrder(current, root, paths, positions)
        if (plan === undefined || !this.readerSessionStore.reconcileLocalEpubPositions(
          current.id, chapterId, plan.anchoredPageIds, false)) return
        const persistence = this.ensureLibraryPersistenceService()
        if (persistence === undefined) return
        upsertComicAndPersistLibraryStore(this.libraryStore, persistence, plan.comic)
        this.readerSessionStore.reconcileLocalEpubPositions(current.id, chapterId,
          plan.comic.chapters[0].pages.map((page: Page): string => page.id), true)
        this.refreshLibrarySnapshot()
      })
    } catch (_error) {
      DiagnosticLogger.warn('local_import', 'epub_order_upgrade', '[LocalImport] epub_order_upgrade_failed')
    }
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
    const metadata = new Map<string, ReaderChapterDescriptor>()
    request.chapters?.forEach((chapter: ReaderChapterDescriptor): void => { metadata.set(chapter.id, chapter) })
    const readingChapters = chapterReadingChaptersFor(request.comicId,
      chapterIds.map((id: string, index: number): ReaderChapterDescriptor =>
        metadata.get(id) ?? { id, title: chapterTitles[index] }), request.chapterId)
    const picker = readerChapterPickerChapters(readingChapters, sourceChapterOrderFor(request.sourceId),
      chapterReadingSortFor(request.comicId))
    return {
      comicId: request.comicId,
      chapterId: request.chapterId,
      chapterIds: picker.map((chapter: ReaderChapterDescriptor): string => chapter.id),
      chapterTitles: picker.map((chapter: ReaderChapterDescriptor): string => chapter.title),
      continuationChapterIds: request.chaptersResolved === true && request.chapters !== undefined
        ? continuationChapterIds(readingChapters, request.chapterId, true, chapterReadingSortFor(request.comicId)) : undefined,
      sourceChapterChronologyPending: needsSourceCatalogChronology(metadata.get(request.chapterId)) ||
        chapterReadingMetadataPendingFor(request.comicId, metadata.get(request.chapterId)),
      title: request.title,
      chapterTitle: chapterTitles[selectedIndex],
      readingFormat: request.readingFormat,
      totalPages: pages.length,
      pageUris: pages.map((page: Page): string => page.uri),
      pageIds: pages.map((page: Page): string => page.id),
      pageWidths: pages.map((page: Page): number | undefined => page.width),
      pageHeights: pages.map((page: Page): number | undefined => page.height),
      pageTextPages: pages.map((page: Page) => page.sourceText),
      pageTextRequests: pages.map((page: Page) => page.sourceTextRequest),
      pageTextOverlays: pages.map((page: Page) => page.sourceTextOverlay),
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
    offline: Promise<OfflineDownloadManifestValidation | undefined>,
  ): Promise<void> {
    const preparedRequest = cloneSourceReaderSessionRequest(request)
    if (!this.readerPageRequestCurrent(openEpoch)) return
    this.readerEntryStage = 'offline'
    const validation = await offline
    if (!this.readerPageRequestCurrent(openEpoch)) return
    const local = validation?.status === OfflineDownloadedChapterStatus.DOWNLOADED
      ? createKomaReaderLabOfflineConfig(this.createSourceReaderSessionConfig(preparedRequest, []), validation) : undefined
    // History already identifies the exact chapter. The adapter fills in the
    // manual catalog and verified continuation in the background.
    // Do not share the library hydrator's result here. Source hosts may issue
    // short-lived descriptors; transient online opens resolve pages afresh.
    const pagePlanStartedAt = Date.now()
    if (local === undefined) this.readerEntryStage = 'source'
    const resolution = local !== undefined ? undefined :
      await this.readReaderPagesWithVerification<SourceChapterPagesResolveResult>(request.sourceId,
      (guard?: string): Promise<SourceChapterPagesResolveResult> => resolveSourceChapterPages(this.sourceRegistry, {
      comicId: request.comicId,
      sourceId: request.sourceId,
      mangaId: request.mangaId,
      mangaUrl: request.mangaUrl,
      chapterId: request.chapterId,
      operationGuardId: guard,
    }), (): boolean => this.readerPageRequestCurrent(openEpoch))
    const activeRequest = this.activeSourceReaderRequest
    if (openEpoch !== this.readerOpenEpoch ||
      !this.readerOpen ||
      this.readerClosing ||
      activeRequest === undefined ||
      activeRequest.comicId !== request.comicId ||
      activeRequest.chapterId !== request.chapterId) {
      return
    }
    this.readerEntryStage = 'chapter'
    DiagnosticLogger.info('reader', 'source_entry_page_plan',
      `elapsedMs=${Date.now() - pagePlanStartedAt} ready=${local !== undefined || (resolution?.pages.length ?? 0) > 0} offline=${local !== undefined}`)
    this.activeSourceReaderRequest = preparedRequest
    if (resolution !== undefined && resolution.pages.length === 0) {
      this.logReaderSourcePagesUnavailable(resolution.reasonCode)
      const unavailableConfig = this.createUnavailableSourceReaderSessionConfig(preparedRequest, resolution.sourceFailureReason, resolution.sourceFailure)
      this.readerSessionConfig = unavailableConfig
      // An unavailable placeholder has no real pages: an 'end' intent must not
      // be consumed as a successful landing (openPageIndex returns 0 there).
      const saved = this.readerOpenIntent === 'resume' &&
        appDeviceSync.receivedReading(request.comicId, request.chapterId) ?
        this.readerSessionStore.getChapterProgress(request.comicId, request.chapterId) : undefined
      // The shared reader retries with its initial index after local login.
      // Do not clamp a synced resume position against the failure placeholder.
      this.readerPageIndex = this.hasContinuationPage(unavailableConfig)
        ? this.openPageIndexForSession(unavailableConfig, this.readerOpenIntent, false)
        : saved?.pageIndex ?? this.readerSessionStore.openPageIndex(unavailableConfig, this.readerOpenIntent)
      this.readerSessionLoading = false
      return
    }
    const nextSessionConfig = local ?? this.createSourceReaderSessionConfig(preparedRequest, resolution?.pages ?? [])
    const hasContinuationOverride = this.hasContinuationPage(nextSessionConfig)
    if (!hasContinuationOverride && !this.privateContinuationSession(preparedRequest.comicId) && this.readerOpenIntent !== 'start' &&
      !appDeviceSync.validateReadingPages(preparedRequest.comicId, preparedRequest.chapterId, nextSessionConfig.totalPages)) {
      if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) return
      this.readerSessionConfig = this.createUnavailableSourceReaderSessionConfig(preparedRequest, 'sync_saved_position_changed')
      this.readerSessionLoading = false
      this.showSyncedChapterChanged(preparedRequest)
      return
    }
    if (openEpoch !== this.readerOpenEpoch || !this.readerOpen || this.readerClosing) return
    this.readerSessionConfig = nextSessionConfig
    this.readerPageIndex = this.openPageIndexForSession(nextSessionConfig, this.readerOpenIntent, true)
    // Terminal publication for the transient source session.
    this.readerOpenIntent = 'resume'
    // Persist only stable identity/title/cover/current-chapter metadata. Page
    // descriptors intentionally stay in the route-local Reader config.
    this.saveSourceReaderHistory(preparedRequest)
    this.readerSessionLoading = false
  }

  private rememberSharedChapterCatalog(request: SourceReaderSessionRequest): void {
    const comic = this.libraryStore.getComic(request.comicId)
    if (request.chaptersResolved !== true || request.chapters === undefined || comic === undefined ||
      comic.sourceRuntimeId !== request.sourceId || comic.remoteResourceId !== request.mangaId) return
    const next = copyComicShell(comic)
    if (!setCompleteSourceChapterCatalog(next, request.chapters.map((item: ReaderChapterDescriptor): string => item.id), Date.now())) return
    const persistence = this.ensureLibraryPersistenceService()
    if (persistence === undefined) return
    upsertComicAndPersistLibraryStore(this.libraryStore, persistence, next, false)
    this.refreshLibrarySnapshot()
  }

  private showSyncedChapterChanged(request: SourceReaderSessionRequest): void {
    this.getUIContext().showAlertDialog({ title: AppStrings.get('device_sync_changed_chapter'),
      message: AppStrings.get('device_sync_saved_location'), systemMaterial: komaDialogMaterial(),
      primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => { this.closeReader() } },
      secondaryButton: { value: AppStrings.get('device_sync_start_chapter'), action: (): void => {
        void this.openSourceReader(request, 'start')
      } },
    })
  }

  private readerLabInitialConfig(work: string, unit: string): ReaderSessionConfig | null {
    if (this.readerSessionConfig.comicId === work && this.readerSessionConfig.chapterId === unit &&
      this.readerSessionConfig.totalPages > 0) return cloneReaderSessionConfig(this.readerSessionConfig)
    const comic = this.readerComicForOpen(work)
    if (comic === undefined) return null
    const config = createReaderSessionConfigFromComic(comic, unit)
    return config.chapterId === unit && config.totalPages > 0 ? config : null
  }

  private async prepareReaderLabCatalog(target: ReaderUnitKey,
    cancellation: ReaderCancellation, forceRefresh: boolean = false): Promise<ReaderSessionConfig | null> {
    if (target.scope !== 'koma-local') return null
    const openEpoch = this.readerOpenEpoch
    // Adjacent preparation is part of this visible reader too. Bind recovery
    // to its originating chapter; leaving or changing it retires the request.
    const originChapter = this.readerSessionConfig.chapterId
    const current = this.readerSessionConfig.comicId === target.work
      ? (): boolean => !cancellation.isCancelled() && this.readerPageRequestCurrent(openEpoch) &&
        this.readerSessionConfig.comicId === target.work && this.readerSessionConfig.chapterId === originChapter : undefined
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
      const validation = await this.readOfflineReaderChapter(target.work, target.unit)
      cancellation.check()
      if (validation?.status === OfflineDownloadedChapterStatus.DOWNLOADED) {
        return createKomaReaderLabOfflineConfig(this.createSourceReaderSessionConfig(nextRequest, []), validation)
      }
      const resolution = await this.readReaderPagesWithVerification<SourceChapterPagesResolveResult>(nextRequest.sourceId,
        (guard?: string): Promise<SourceChapterPagesResolveResult> => resolveSourceChapterPages(this.sourceRegistry, {
        comicId: nextRequest.comicId,
        sourceId: nextRequest.sourceId,
        mangaId: nextRequest.mangaId,
        mangaUrl: nextRequest.mangaUrl,
        chapterId: nextRequest.chapterId,
        operationGuardId: guard,
      }), current)
      cancellation.check()
      // A chapter handoff is prepared beside the still-readable shared session.
      // Do not turn a provider failure into a committed placeholder unit: reject
      // the handoff so the current chapter stays visible and can be retried.
      if (resolution.pages.length === 0) throw KomaReaderFailure.sourceError(resolution.sourceFailureReason, resolution.sourceFailure)
      if (!this.hasContinuationPage(this.readerSessionConfig) && !this.privateContinuationSession(target.work) &&
        this.readerOpenIntent === 'resume' && this.readerSessionConfig.chapterId === target.unit &&
        this.readerSessionConfig.pageUris.includes('source-placeholder://chapter') &&
        !appDeviceSync.validateReadingPages(target.work, target.unit, resolution.pages.length)) {
        this.showSyncedChapterChanged(nextRequest)
        throw new Error('sync_saved_position_changed')
      }
      return this.createSourceReaderSessionConfig(nextRequest, resolution.pages)
    }
    let original = this.readerComicForOpen(target.work)
    if (original === undefined) return null
    // Keep local-folder permission activation in the adapter's established path.
    if (original.sourceKind === ComicSourceKind.LOCAL_FOLDER) return null
    const validation = await this.readOfflineReaderChapter(target.work, target.unit)
    cancellation.check()
    if (validation?.status === OfflineDownloadedChapterStatus.DOWNLOADED) {
      return createKomaReaderLabOfflineConfig(createReaderSessionConfigFromComic(original, target.unit), validation)
    }
    if (original.sourceRuntimeId !== undefined &&
      !original.chapters.some((chapter: Chapter): boolean => chapter.id === target.unit)) {
      await this.readReaderPagesWithVerification<boolean>(original.sourceRuntimeId,
        (guard?: string): Promise<boolean> => new SourceChapterPageHydrator(this.libraryStore, this.sourceRegistry,
          this.ensureLibraryPersistenceService()).ensureChapterDescriptor(target.work, target.unit,
            (): boolean => !cancellation.isCancelled() && this.readerPageRequestCurrent(openEpoch), guard), current)
      cancellation.check()
      original = this.readerComicForOpen(target.work) ?? original
    }
    let sourceFailureReason: string | undefined = undefined
    let sourceFailure: SourceFailureDetails | undefined = undefined
    if (validation?.status !== OfflineDownloadedChapterStatus.PARTIAL) {
      const hydrated = await this.ensureReaderSourceChapterPages(original, target.unit,
        (reason: string | undefined, details?: SourceFailureDetails): void => { sourceFailureReason = reason; sourceFailure = details },
        forceRefresh, current)
      // A failed explicit refresh must not silently reuse the same stale page plan.
      if (forceRefresh && !hydrated) throw KomaReaderFailure.sourceError(sourceFailureReason, sourceFailure)
    }
    cancellation.check()
    const comic = this.readerComicForOpen(target.work) ?? original
    cancellation.check()
    const config = createKomaReaderLabOfflineConfig(createReaderSessionConfigFromComic(comic, target.unit), validation)
    if (config.totalPages > 0) return config
    if (this.chapterNeedsReaderSourcePages(comic, target.unit)) {
      throw KomaReaderFailure.sourceError(sourceFailureReason, sourceFailure)
    }
    return null
  }

  /** Legacy libraries acquire source ordinals in the background, never by
   * reversing their possibly merged stored array or delaying the cached page. */
  private async prepareReaderLabSequence(target: ReaderUnitKey,
    cancellation: ReaderCancellation): Promise<KomaReaderChapterCatalogUpdate | undefined> {
    const epoch = this.readerOpenEpoch
    const isCurrent = (): boolean => !cancellation.isCancelled() && epoch === this.readerOpenEpoch &&
      this.readerOpen && !this.readerClosing
    const source = this.activeSourceReaderRequest
    if (source !== undefined && source.comicId === target.work) {
      const lookup = this.sourceRegistry.lookup(source.sourceId)
      if (!lookup.ok || lookup.entry === undefined || !sourceRuntimeEntryEnabled(lookup.entry)) return undefined
      const settingsRevision = appSourceSettingsStore.revisionForSource(source.sourceId)
      const sourceCurrent = (): boolean => isCurrent() && this.sourceRegistry.lookup(source.sourceId).entry === lookup.entry
      const catalog = await this.readReaderPagesWithVerification<SourceChapterListResult>(source.sourceId,
        (guard?: string): Promise<SourceChapterListResult> => resolveSourceChapterList(lookup.entry!, source.mangaId,
          source.mangaUrl, sourceCurrent, undefined, guard), sourceCurrent)
      cancellation.check()
      if (!catalog.resolved || !sourceCurrent() ||
        !catalog.chapters.some((chapter: ReaderChapterDescriptor): boolean => chapter.id === target.unit)) return undefined
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
      this.rememberSharedChapterCatalog(updated)
      sourceMangaDetailSnapshotCache.rememberVerifiedReaderCatalog(lookup.entry, source.mangaId, source.mangaUrl,
        settingsRevision, catalog.chapters, catalog.excludedChapterIds)
      const readingChapters = chapterReadingChaptersFor(target.work, catalog.chapters, target.unit)
      const picker = readerChapterPickerChapters(readingChapters, sourceChapterOrderFor(source.sourceId),
        chapterReadingSortFor(target.work))
      return {
        continuation: continuationChapterIds(readingChapters, target.unit, true, chapterReadingSortFor(target.work)),
        chapterIds: picker.map((chapter: ReaderChapterDescriptor): string => chapter.id),
        chapterTitles: picker.map((chapter: ReaderChapterDescriptor): string => chapter.title),
      }
    }
    const continuation = await this.readReaderPagesWithVerification<string[] | undefined>(
      this.readerComicForOpen(target.work)?.sourceRuntimeId,
      (guard?: string): Promise<string[] | undefined> => new SourceChapterPageHydrator(this.libraryStore, this.sourceRegistry,
        this.ensureLibraryPersistenceService()).resolveChapterSequence(target.work, target.unit, isCurrent, guard), isCurrent)
    if (continuation === undefined) return undefined
    const comic = this.readerComicForOpen(target.work)
    if (comic === undefined) return { continuation }
    const updated = createReaderSessionConfigFromComic(comic, target.unit)
    return { continuation, chapterIds: updated.chapterIds, chapterTitles: updated.chapterTitles }
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
      (target: ReaderUnitKey, cancellation: ReaderCancellation): Promise<KomaReaderChapterCatalogUpdate | undefined> =>
        this.prepareReaderLabSequence(target, cancellation),
      (work: string): Comic | undefined => this.readerComicForOpen(work),
    )
  }

  private commitReaderLabCatalog(target: ReaderUnitKey, config: ReaderSessionConfig): void {
    if (target.scope !== 'koma-local' || config.comicId !== target.work || config.chapterId !== target.unit ||
      config.totalPages < 1 || config.pageUris.length !== config.totalPages) return
    // The catalog host has already detached this snapshot from the adapter.
    this.readerSessionConfig = config
    if (this.continuationRuntime.continuedAway || this.privateContinuationSession(config.comicId)) return
    const sourceRequest = this.activeSourceReaderRequest
    if (sourceRequest === undefined || sourceRequest.comicId !== target.work) {
      this.beginShelfReadingSync(this.readerComicForOpen(target.work), target.unit)
      return
    }
    const committedRequest = sourceReaderSessionRequestForChapter(sourceRequest, target.unit)
    if (committedRequest === undefined) return
    if (sourceRequest.chapterId === committedRequest.chapterId &&
      this.readerSessionStore.getSourceHistory(target.work)?.chapterId === target.unit) return
    this.activeSourceReaderRequest = committedRequest
    if (!this.incognito.isEnabledForSource(committedRequest.sourceId)) appDeviceSync.beginReadingChapter(committedRequest)
    // The first displayed page queues its position immediately after this
    // callback. Keep chapter history in that batch, outside the scroll callback.
    this.saveSourceReaderHistory(committedRequest, false)
  }

  private saveSourceReaderHistory(request: SourceReaderSessionRequest, flush: boolean = true): void {
    // A private source doesn't publish activity even into the global incognito
    // history overlay. Existing recorded history remains available for resume.
    if (this.incognito.isSourceEnabled(request.sourceId) || this.privateContinuationSession(request.comicId)) return
    this.readerSessionStore.saveSourceHistory(sourceReadHistoryEntryFromRequest(request))
    if (flush) this.readerSessionStore.flush()
  }

  private readerNeedsAsyncPreparation(comic: Comic, chapterId: string | undefined): boolean {
    if (this.chapterNeedsReaderSourcePages(comic, chapterId)) {
      return true
    }
    return comic.sourceKind === ComicSourceKind.LOCAL_FOLDER ||
      comic.sourceKind === ComicSourceKind.KOMGA_REMOTE ||
      comic.sourceKind === ComicSourceKind.KAVITA_REMOTE ||
      comic.sourceKind === ComicSourceKind.OPDS_REMOTE ||
      comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE
  }

  private beginShelfReadingSync(comic: Comic | undefined, chapter: string): void {
    if (comic?.sourceRuntimeId === undefined || comic.remoteResourceId === undefined) return
    if (this.incognito.isSourceEnabled(comic.sourceRuntimeId) || this.privateContinuationSession(comic.id)) return
    appDeviceSync.beginReadingChapter({ comicId: comic.id, sourceId: comic.sourceRuntimeId,
      mangaId: comic.remoteResourceId, mangaUrl: comic.sourcePath, sourceName: comic.sourceMetadata?.sourceName,
      title: comic.title, chapterId: chapter, chapterIds: [chapter],
      chapterTitles: [comic.chapters.find((item: Chapter): boolean => item.id === chapter)?.title ?? ''] })
  }

  private async openDownloadedChapter(comicId: ComicId, chapterId: string,
    validatedDownload?: OfflineDownloadManifestValidation): Promise<void> {
    const comic = this.libraryStore.getComic(comicId)
    if (comic?.chapters.some((chapter: Chapter): boolean => chapter.id === chapterId)) {
      void this.openReader(comicId, chapterId, 'resume', undefined, validatedDownload)
      return
    }
    // Finished downloads own their local bytes and labels even after unfavoriting.
    // A detached Reader snapshot must never re-add the work to the bookshelf.
    const epoch = ++this.readerOpenEpoch
    const origin = this.appPathStack.getAllPathName().join('|')
    const validation = validatedDownload ?? await this.readOfflineReaderChapter(comicId, chapterId)
    if (epoch !== this.readerOpenEpoch || origin !== this.appPathStack.getAllPathName().join('|')) return
    const manifest = validation?.manifest
    if (validation === undefined || manifest === undefined || validation.status !== OfflineDownloadedChapterStatus.DOWNLOADED) {
      this.showToast(AppStrings.get('downloads_toast_entry_unavailable'))
      return
    }
    const title = comic?.title ?? manifest.comicTitle ?? AppStrings.get('downloads_local_section')
    const chapter: Chapter = {
      id: chapterId, comicId, title: manifest.chapterTitle ?? chapterId, index: 0,
      sourcePath: '', sortKey: '', pages: [], pageCount: manifest.pageCount,
      createdAt: manifest.updatedAt, updatedAt: manifest.updatedAt,
    }
    const snapshot: Comic = {
      id: comicId, title, sortTitle: title, sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
      sourceRuntimeId: comic?.sourceRuntimeId ?? manifest.sourceId,
      sourcePath: '', preferredDirection: comic?.preferredDirection ?? ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter], chapterCount: 1, pageCount: manifest.pageCount,
      createdAt: manifest.updatedAt, updatedAt: manifest.updatedAt, lastImportedAt: manifest.updatedAt,
    }
    void this.openReader(comicId, chapterId, 'resume', snapshot, validation)
  }

  private privateContinuationSession(comicId: string): boolean {
    // Without a local private category, normal history would expose the work
    // in recent reads and on other devices. Keep this grant and activity route-local.
    return this.libraryPrivacy.privateContinuation(comicId)
  }

  private hasContinuationPage(config: ReaderSessionConfig): boolean {
    const target = this.continuationTargetPage
    return target?.comicId === config.comicId && target.chapterId === config.chapterId
  }

  private openPageIndexForSession(
    config: ReaderSessionConfig,
    intent: ReaderChapterOpenIntent,
    consume: boolean,
  ): number {
    const target = this.continuationTargetPage
    if (target !== undefined && target.comicId === config.comicId && target.chapterId === config.chapterId) {
      const totalPages = config.pageUris.includes('source-placeholder://chapter') ? 0 : config.totalPages
      const resolved = resolveContinuationPageIndex(target.pageIndex, totalPages)
      if (consume && totalPages > 0) {
        this.continuationTargetPage = undefined
      }
      return resolved
    }
    return this.readerSessionStore.openPageIndex(config, intent)
  }

  private async openReader(
    comicId: ComicId,
    chapterId?: string,
    intent: ReaderChapterOpenIntent = 'resume',
    comicSnapshot?: Comic,
    validatedDownload?: OfflineDownloadManifestValidation,
    continuationPageIndex?: number,
  ): Promise<void> {
    if (!this.canOpenLibraryComic(comicId)) return
    if (comicId.startsWith('mihon:')) {
      if (!await this.openMihonImportedWork(comicId)) this.showToast(AppStrings.get('mihon_import_resume_failed'))
      return
    }
    this.continuationTargetPage = continuationPageIndex !== undefined && chapterId !== undefined
      ? { comicId, chapterId, pageIndex: continuationPageIndex } : undefined
    if (comicSnapshot !== undefined) this.activeReaderComicSnapshot = comicSnapshot
    else if (this.activeReaderComicSnapshot?.id !== comicId) this.activeReaderComicSnapshot = undefined
    let comic = this.readerComicForOpen(comicId)
    let targetChapterId = comic === undefined ? chapterId : this.readerChapterIdForOpen(comic, chapterId)
    if (continuationPageIndex !== undefined && targetChapterId !== undefined) {
      this.continuationTargetPage = { comicId, chapterId: targetChapterId, pageIndex: continuationPageIndex }
    }
    if (chapterId === undefined && comic !== undefined && comic.sourceRuntimeId !== undefined &&
      comic.remoteResourceId !== undefined && !this.incognito.isEnabledForSource(comic.sourceRuntimeId)) {
      const syncChapter = targetChapterId ?? comic.chapters[0]?.id
      if (syncChapter !== undefined) {
        const syncRequest: SourceReaderSessionRequest = { comicId: comic.id, sourceId: comic.sourceRuntimeId,
          mangaId: comic.remoteResourceId, mangaUrl: comic.sourcePath, sourceName: comic.sourceMetadata?.sourceName,
          title: comic.title, chapterId: syncChapter, chapterIds: [syncChapter],
          chapterTitles: [comic.chapters.find((item: Chapter): boolean => item.id === syncChapter)?.title ?? ''] }
        const conflict = await appDeviceSync.waitForReadingSync(syncRequest)
        if (!this.canOpenLibraryComic(comicId)) return
        if (conflict !== undefined) {
          this.showReadingResumeConflict(conflict, syncRequest)
          return
        }
        comic = this.readerComicForOpen(comicId) ?? comic
        targetChapterId = this.readerChapterIdForOpen(comic, chapterId)
      }
    }
    const openEpoch = ++this.readerOpenEpoch
    const originPaths = this.appPathStack.getAllPathName().join('|')
    const originTab = this.selectedTab
    const isCurrent = (): boolean => openEpoch === this.readerOpenEpoch &&
      originPaths === this.appPathStack.getAllPathName().join('|') && originTab === this.selectedTab
    const offline = validatedDownload !== undefined ? Promise.resolve(validatedDownload)
      : this.readOfflineReaderChapter(comicId, targetChapterId)
    if (targetChapterId !== undefined && comic?.sourceRuntimeId && appDeviceSync.receivedReading(comicId, targetChapterId)) {
      const history = this.readerSessionStore.getSourceHistoryForResume(comicId)
      const request = history === undefined || history.chapterId !== targetChapterId ? undefined :
        sourceReaderSessionRequestFromHistory(history)
      if (request !== undefined) {
        const validation = await offline
        if (!isCurrent()) return
        if (validation?.status !== OfflineDownloadedChapterStatus.DOWNLOADED &&
          validation?.status !== OfflineDownloadedChapterStatus.PARTIAL) {
          await this.openSourceReader(request, intent, offline, continuationPageIndex)
          return
        }
      }
    }
    const remoteHistory = this.readerSessionStore.getRemoteHistory(comicId)
    if (comic?.sourceKind === ComicSourceKind.KAVITA_REMOTE && remoteHistory?.kind === 'kavita' && targetChapterId !== undefined) {
      remoteHistory.chapterId = targetChapterId
      remoteHistory.chapterTitle = comic.chapters.find((item: Chapter): boolean => item.id === targetChapterId)?.title
      this.readerSessionStore.saveRemoteHistory(remoteHistory)
    }
    if (comic !== undefined && targetChapterId !== undefined &&
      comic.sourceRuntimeId !== undefined && comic.sourceRuntimeId.trim().length > 0 &&
      !comic.chapters.some((chapter: Chapter): boolean => chapter.id === targetChapterId)) {
      const validation = await offline
      if (!isCurrent()) return
      if (validation?.status !== OfflineDownloadedChapterStatus.DOWNLOADED) {
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
          // Only restore the chapter identity before navigation. Foreground page
          // resolution belongs to the reader and may need its verification sheet.
          if (!restored || comic === undefined) {
            if (isCurrent()) {
              this.showToast(AppStrings.get('manga_detail_load_source_chapters_failed'))
            }
            return
          }
        } catch (_error) {
          if (isCurrent()) {
            this.showToast(AppStrings.get('manga_detail_load_source_chapters_failed'))
          }
          return
        }
      }
    }
    this.readerOpenIntent = intent
    this.activeSourceReaderRequest = undefined
    const readerDetailVisible = this.isReaderDetailRouteVisible()
    const shouldPresentReader = !this.readerOpen || this.readerClosing
    this.readerSessionLoading = comic !== undefined && this.readerNeedsAsyncPreparation(comic, targetChapterId)
    this.readerSessionConfig = comic === undefined
      ? MOCK_LIBRARY_READER_SESSION
      : createKomaReaderLabOfflineConfig(createReaderSessionConfigFromComic(comic, targetChapterId), validatedDownload)
    this.beginShelfReadingSync(comic, this.readerSessionConfig.chapterId)
    this.readerPageIndex = this.openPageIndexForSession(this.readerSessionConfig, this.readerOpenIntent, false)
    this.readerPreparation = null
    const animatedRoute = continuationPageIndex === undefined
    this.readerEntryStage = 'chapter'
    this.captureSharedReaderEntry(shouldPresentReader, animatedRoute)
    // Starting a chapter from a detail page that was opened by Reader updates
    // the already-mounted Reader beneath it.  It is not a second Reader route.
    if (readerDetailVisible) {
      this.appPathStack.pop(true)
    }
    if (shouldPresentReader) {
      if (this.readerSessionPersistenceReady && !this.privateContinuationSession(comicId) &&
        !this.incognito.isSourceEnabled(comic?.sourceRuntimeId)) {
        this.readerTrackerCoordinator().beginReading()
      }
      this.readerClosing = false
      this.readerRouteVisible = false
      this.readerOpen = true
      // Native root navigation presents the Reader immediately. Descriptor
      // refresh remains session work and never blocks route presentation.
      this.appPathStack.pushPath({ name: RouteName.READER }, animatedRoute)
      if (!animatedRoute) {
        DiagnosticLogger.info('continuation', 'reader_route_pushed',
          'kind=library stack=' + this.appPathStack.getAllPathName().join(',') +
          ' navMounted=' + this.rootNavigationMounted + ' navVisible=' + this.rootNavigation.visible)
      }
    }
    if (comic !== undefined) {
      this.readerPreparation = this.prepareReaderSession(comicId, targetChapterId, openEpoch, offline,
        validatedDownload === undefined && targetChapterId !== undefined)
    } else {
      // No session preparation will follow, so this publication is terminal.
      this.readerOpenIntent = 'resume'
    }
  }

  private reuseVerifiedReaderCatalog(request: SourceReaderSessionRequest): void {
    const existing = request.chapters?.find((chapter: ReaderChapterDescriptor): boolean => chapter.id === request.chapterId)
    if (request.chaptersResolved === true && existing !== undefined && !needsSourceCatalogChronology(existing) &&
      !chapterReadingMetadataPendingFor(request.comicId, existing)) return
    const lookup = this.sourceRegistry.lookup(request.sourceId)
    if (!lookup.ok || lookup.entry === undefined || !sourceRuntimeEntryEnabled(lookup.entry) ||
      lookup.entry.authentication !== undefined) return
    const cached = sourceMangaDetailSnapshotCache.read(lookup.entry, request.sourceId, request.mangaId, request.mangaUrl)
    const current = cached?.chapters.find((chapter: ReaderChapterDescriptor): boolean => chapter.id === request.chapterId)
    if (cached?.chaptersResolved !== true || current === undefined || needsSourceCatalogChronology(current) ||
      chapterReadingMetadataPendingFor(request.comicId, current)) return
    // Restore only a verified catalog. Each new source-reader entry still
    // requests fresh page descriptors so signed URLs and auth stay current.
    request.chapters = cached.chapters
    request.chapterIds = cached.chapters.map((chapter: ReaderChapterDescriptor): string => chapter.id)
    request.chapterTitles = cached.chapters.map((chapter: ReaderChapterDescriptor): string => chapter.title)
    request.chaptersResolved = true
  }

  private async openSourceReader(
    request: SourceReaderSessionRequest,
    intent: ReaderChapterOpenIntent = 'resume',
    offline?: Promise<OfflineDownloadManifestValidation | undefined>,
    continuationPageIndex?: number,
  ): Promise<void> {
    if (!this.canOpenLibraryComic(request.comicId)) return
    const nextRequest = cloneSourceReaderSessionRequest(request)
    if (nextRequest.sourceId.trim().length === 0 ||
      nextRequest.mangaId.trim().length === 0 ||
      nextRequest.comicId.trim().length === 0 ||
      nextRequest.chapterId.trim().length === 0 ||
      !nextRequest.chapterIds.includes(nextRequest.chapterId)) {
      return
    }
    this.continuationTargetPage = continuationPageIndex !== undefined
      ? { comicId: nextRequest.comicId, chapterId: nextRequest.chapterId, pageIndex: continuationPageIndex } : undefined
    const generation = ++this.sourceReaderOpenRequest
    if (nextRequest.sourceId.startsWith('mihon:')) {
      if (!await this.openMihonImportedWork(nextRequest.comicId)) this.showToast(AppStrings.get('mihon_import_resume_failed'))
      return
    }
    this.reuseVerifiedReaderCatalog(nextRequest)
    const sourceIncognito = this.incognito.isSourceEnabled(nextRequest.sourceId) ||
      this.privateContinuationSession(nextRequest.comicId)
    const downloaded = offline ?? this.readOfflineReaderChapter(nextRequest.comicId, nextRequest.chapterId)
    if (appDeviceSync.openReading(nextRequest, !sourceIncognito) === 'missing') {
      const origin = this.appPathStack.getAllPathName().join('|')
      const originTab = this.selectedTab
      const epoch = this.readerOpenEpoch
      const validation = await downloaded
      if (generation !== this.sourceReaderOpenRequest || epoch !== this.readerOpenEpoch ||
        origin !== this.appPathStack.getAllPathName().join('|') || originTab !== this.selectedTab ||
        !this.canOpenLibraryComic(nextRequest.comicId)) return
      if (validation?.status !== OfflineDownloadedChapterStatus.DOWNLOADED) {
        const name = nextRequest.sourceName || nextRequest.sourceId
        RouterHelper.promptMissingSourceRecovery(this.getUIContext(), nextRequest.sourceId, name, true)
        return
      }
      if (!sourceIncognito) appDeviceSync.beginReadingChapter(nextRequest)
    }
    this.readerOpenIntent = intent
    const readerDetailVisible = this.isReaderDetailRouteVisible()
    const shouldPresentReader = !this.readerOpen || this.readerClosing
    const openEpoch = this.readerOpenEpoch + 1
    this.readerOpenEpoch = openEpoch
    this.activeSourceReaderRequest = nextRequest
    this.activeReaderComicSnapshot = undefined
    this.readerSessionLoading = true
    this.readerSessionConfig = this.createSourceReaderSessionConfig(nextRequest, [])
    this.readerPageIndex = this.openPageIndexForSession(this.readerSessionConfig, this.readerOpenIntent, false)
    this.readerPreparation = null
    const animatedRoute = continuationPageIndex === undefined
    this.readerEntryStage = 'chapter'
    this.captureSharedReaderEntry(shouldPresentReader, animatedRoute)
    // This matches normal Reader chapter switching: a detail page opened from
    // Reader is popped before the already-mounted Reader receives its next
    // transient session.
    if (readerDetailVisible) {
      this.appPathStack.pop(true)
    }
    if (shouldPresentReader) {
      if (this.readerSessionPersistenceReady && !sourceIncognito) this.readerTrackerCoordinator().beginReading()
      this.readerClosing = false
      this.readerRouteVisible = false
      this.readerOpen = true
      this.appPathStack.pushPath({ name: RouteName.READER }, animatedRoute)
      if (!animatedRoute) {
        DiagnosticLogger.info('continuation', 'reader_route_pushed',
          'kind=source stack=' + this.appPathStack.getAllPathName().join(',') +
          ' navMounted=' + this.rootNavigationMounted + ' navVisible=' + this.rootNavigation.visible)
      }
    }
    this.readerPreparation = this.prepareSourceReaderSession(nextRequest, openEpoch, downloaded)
  }

  private async resumeSourceFromHistory(request: SourceReaderSessionRequest): Promise<void> {
    if (!this.canOpenLibraryComic(request.comicId)) return
    if (request.sourceId.startsWith('mihon:')) {
      await this.resumeMihonFromHistory(request.comicId)
      return
    }
    this.closeHistoryResumeLoading()
    const local = this.readerSessionStore.getSourceHistoryForResume(request.comicId)
    const savedRequest = local === undefined ? undefined : sourceReaderSessionRequestFromHistory(local)
    if (savedRequest === undefined) return
    if (this.incognito.isSourceEnabled(request.sourceId)) {
      await this.openSourceReader(savedRequest)
      return
    }
    const generation = ++this.sourceReaderOpenRequest
    const isCurrent = (): boolean => generation === this.sourceReaderOpenRequest &&
      this.selectedTab === TabIndex.HISTORY && this.rootNavigation.visible && this.appForegroundState.active &&
      this.canOpenLibraryComic(request.comicId)
    const timer = this.startHistoryResumeLoading(isCurrent)
    const syncStartedAt = Date.now()
    let conflict: SyncReadingWorkConflict | undefined
    try {
      conflict = await appDeviceSync.waitForReadingSync(savedRequest)
    } finally {
      if (this.historyResumeLoadingTimer === timer) this.closeHistoryResumeLoading()
    }
    if (!isCurrent()) return
    DiagnosticLogger.info('reader', 'history_resume_sync',
      `elapsedMs=${Date.now() - syncStartedAt} conflict=${conflict !== undefined}`)
    if (conflict !== undefined) {
      this.showReadingResumeConflict(conflict, savedRequest)
      return
    }
    const history = this.readerSessionStore.getSourceHistoryForResume(request.comicId)
    const latest = history === undefined ? undefined : sourceReaderSessionRequestFromHistory(history)
    if (latest !== undefined) await this.openSourceReader(latest)
  }

  private async resumeMihonFromHistory(comicId: string): Promise<void> {
    await this.openMihonImportedWork(comicId, true, true)
  }

  private startHistoryResumeLoading(isCurrent: () => boolean, content: Resource = $r('app.string.history_resume_loading')): number {
    const prompt = this.getUIContext().getPromptAction()
    let dismissed = false
    // Delay only the dialog so a warm resume never flashes before navigation.
    const timer = setTimeout((): void => {
      if (!isCurrent()) return
      void prompt.openCustomDialog({
        builder: () => { this.HistoryResumeLoading(content) },
        alignment: DialogAlignment.Center,
        autoCancel: false,
        onWillDismiss: (action: DismissDialogAction): void => {
          dismissed = true
          if (this.historyResumeLoadingTimer === timer) {
            this.historyResumeLoadingDialog = -1
            this.cancelHistoryResume()
          }
          action.dismiss()
        },
      }).then((id: number): void => {
        if (dismissed) return
        if (this.historyResumeLoadingTimer === timer && isCurrent()) this.historyResumeLoadingDialog = id
        else prompt.closeCustomDialog(id)
      }).catch((): void => {
        // Failure to show feedback must not prevent resuming the saved chapter.
      })
    }, 220)
    this.historyResumeLoadingTimer = timer
    this.historyResumeCanContinue = isCurrent
    return timer
  }

  private readingProgressLabel(progress: SyncReadingWorkProgress): string {
    const chapter = progress.recent.chapterTitle || progress.recent.chapter || progress.recent.title
    const total = progress.total > 0 ? ' / ' + progress.total.toString() : ''
    return chapter + ' · ' + (progress.page + 1).toString() + total
  }

  private showReadingResumeConflict(conflict: SyncReadingWorkConflict, request: SourceReaderSessionRequest): void {
    this.readingConflictHold?.()
    this.readingConflictHold = appDeviceSync.holdAutomaticForReview()
    const message = AppStrings.get('device_sync_progress_conflict_message') + '\n' +
      AppStrings.get('device_sync_progress_remote') + ': ' + this.readingProgressLabel(conflict.remote) + '\n' +
      AppStrings.get('device_sync_progress_local') + ': ' + this.readingProgressLabel(conflict.local)
    this.getUIContext().showAlertDialog({ title: AppStrings.get('device_sync_progress_conflict_title'), message,
      systemMaterial: komaDialogMaterial(), autoCancel: false,
      primaryButton: { value: AppStrings.get('device_sync_keep_local_progress'), action: (): void => {
        void this.resolveReadingResumeConflict(conflict, false, request)
      } },
      secondaryButton: { value: AppStrings.get('device_sync_use_remote_progress'), action: (): void => {
        void this.resolveReadingResumeConflict(conflict, true, request)
      } },
    })
  }

  private async resolveReadingResumeConflict(conflict: SyncReadingWorkConflict, useRemote: boolean,
    request: SourceReaderSessionRequest): Promise<void> {
    const chosen = useRemote ? conflict.remote : conflict.local
    try {
      await appDeviceSync.resolveReadingResumeConflict(conflict, useRemote)
      const history = this.readerSessionStore.getSourceHistoryForResume(request.comicId)
      const rawLatest = history === undefined ? undefined : sourceReaderSessionRequestFromHistory(history)
      if (rawLatest !== undefined) {
        if (rawLatest.chapterId !== chosen.chapter) throw new Error('sync_reading_choice_not_applied')
        const latest = mergeSourceReaderResumeRequest(rawLatest, request)
        DiagnosticLogger.info('device-sync', 'reading-choice-applied', `useRemote=${useRemote}`)
        await this.openSourceReader(latest)
        return
      }
      if (this.libraryStore.getComicSummary(request.comicId) !== undefined) {
        const progress = this.readerSessionStore.getProgress(request.comicId)
        if (progress !== undefined && progress.chapterId !== chosen.chapter) throw new Error('sync_reading_choice_not_applied')
        DiagnosticLogger.info('device-sync', 'reading-choice-applied', `useRemote=${useRemote} library=true`)
        await this.openReader(request.comicId, chosen.chapter)
        return
      }
      throw new Error('sync_reading_choice_not_applied')
    } catch (error) {
      DiagnosticLogger.exception('device-sync', 'reading-choice-failed', error as Error)
      this.showToast(AppStrings.get('device_sync_progress_resolve_failed'))
    } finally {
      this.readingConflictHold?.()
      this.readingConflictHold = undefined
    }
  }

  @Builder
  private HistoryResumeLoading(content: Resource) {
    LoadingDialogV2({ content })
  }

  private closeHistoryResumeLoading(): void {
    if (this.historyResumeLoadingTimer >= 0) clearTimeout(this.historyResumeLoadingTimer)
    this.historyResumeLoadingTimer = -1
    this.historyResumeCanContinue = undefined
    if (this.historyResumeLoadingDialog < 0) return
    const id = this.historyResumeLoadingDialog
    this.historyResumeLoadingDialog = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }

  private cancelHistoryResume(): void {
    if (this.historyResumeLoadingTimer < 0) return
    this.sourceReaderOpenRequest++
    this.closeHistoryResumeLoading()
  }

  @Monitor('selectedTab', 'rootNavigation.visible', 'appForegroundState.active')
  private cancelHistoryResumeWhenCovered(): void {
    if (this.historyResumeCanContinue?.() === false) {
      this.cancelHistoryResume()
    }
  }

  private openHistoryDetail(comicId: ComicId, source?: SourceReadHistoryEntry, remote?: RemoteReadHistoryEntry): void {
    if (!this.canOpenLibraryComic(comicId)) return
    this.cancelHistoryResume()
    if (comicId.startsWith('mihon:')) {
      void this.openMihonImportedWork(comicId, false, true)
      return
    }
    if (source !== undefined) {
      RouterHelper.pushMangaDetail({
        mangaId: source.mangaId, sourceId: source.sourceId, sourceName: source.sourceName,
        initialManga: {
          id: source.mangaId, sourceId: source.sourceId, title: source.title,
          coverUrl: source.coverUri, url: source.mangaUrl,
        },
      })
    } else if (remote !== undefined) {
      this.openRemoteHistory(remote, false)
    } else {
      this.openLibraryMangaDetail(comicId)
    }
  }

  private openRemoteHistory(entry: RemoteReadHistoryEntry, resume: boolean = true): void {
    if (!this.canOpenLibraryComic(entry.comicId)) return
    const history = copyRemoteReadHistoryEntry(entry)
    if (history === undefined || (resume && this.readerSessionStore.getProgress(history.comicId)?.chapterId !== history.chapterId)) return
    const resumeChapterId = resume ? history.chapterId : undefined
    if (history.kind === 'komga') {
      const params: KomgaSeriesRouteParam = { seriesId: history.resourceId, seriesTitle: history.title,
        expectedServerId: history.serverId, resumeChapterId }
      this.appPathStack.pushPath({ name: RouteName.KOMGA_BROWSE, param: params })
    } else if (history.kind === 'kavita') {
      const params: KavitaBrowseRouteParam = { libraryId: history.libraryId, seriesId: history.resourceId,
        seriesTitle: history.title, expectedServerId: history.serverId, resumeChapterId }
      this.appPathStack.pushPath({ name: RouteName.KAVITA_BROWSE, param: params })
    } else if (history.kind === 'webdav') {
      const params: WebDavBrowseRouteParam = { pathSegments: history.pathSegments,
        expectedServerId: history.serverId, resumeChapterId }
      this.appPathStack.pushPath({ name: RouteName.WEBDAV_BROWSE, param: params })
    } else {
      const params: OpdsBrowseRouteParam = { remoteHistory: history, historyDetailOnly: !resume }
      this.appPathStack.pushPath({ name: RouteName.OPDS_BROWSE, param: params })
    }
  }

  private openExternalReaderSession(): void {
    if (this.readerOpen && !this.readerClosing) {
      return
    }
    this.readerOpenEpoch += 1
    this.activeSourceReaderRequest = undefined
    this.activeReaderComicSnapshot = undefined
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
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message }))
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
      sourceChapterChronologyPending: baseConfig.sourceChapterChronologyPending,
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
    // During the native enter transition the reader may not have received
    // onShown yet. There is no Reader-owned status bar to restore in that
    // window, so let the root stack cancel the in-flight route directly.
    if (!this.readerRouteVisible) {
      this.readerClosing = true
      this.appPathStack.pop(true)
      return
    }
    // The reader restores the application system bar before the native pop.
    this.readerCloseRequestId += 1
  }

  private popReaderRouteAfterSystemBarRestore(): void {
    if (!this.readerOpen || this.readerClosing || !this.isReaderRouteVisible()) {
      return
    }
    // The reader calls this callback after it persists its current page. Keep
    // the explicit flush here as the boundary before publishing the snapshot
    // to the shelf, including future Reader close implementations.
    this.readingStatisticsRecorder.close()
    const committed = this.readerSessionPersistenceReady && this.readerSessionStore.flush()
    const sourceIncognito = this.incognito.isSourceEnabled(this.readerSessionConfig.sourceRuntimeId) ||
      this.privateContinuationSession(this.readerSessionConfig.comicId)
    if (!sourceIncognito) {
      appDeviceSync.retainBlockedReading()
      if (committed) appDeviceSync.readerClosed()
    }
    this.cleanupProgressCommitted = committed && !sourceIncognito
    this.readerTrackerProgress?.close(committed)
    this.refreshReadingPresentation([this.readerSessionConfig.comicId], true)
    this.readerClosing = true
    this.readerRouteVisible = false
    this.appPathStack.pop(true)
  }

  private finishReaderRouteClose(): void {
    if (this.readerWebChallenge !== null) this.finishReaderWebChallenge(this.readerWebChallenge, false)
    if (!this.readerClosing) {
      return
    }
    this.readerOpen = false
    this.readerClosing = false
    this.readerRouteVisible = false
    this.readerSessionLoading = false
    this.activeReaderComicSnapshot = undefined
    this.continuationTargetPage = undefined
    this.continuationObservedPage = undefined
    this.libraryPrivacy.releaseContinuationPrivacy(this.readerSessionConfig.comicId)
    appReaderContinuation.setContinuedAway(false)
    this.syncReaderContinuationState()
    if (this.cleanupProgressCommitted) {
      this.cleanupProgressCommitted = false
      void this.cleanupService().run(getContext(this) as common.UIAbilityContext,
        this.libraryStore, this.readerSessionStore).then(() => { this.readerProgressRevision += 1 }).catch((error: Error): void => {
        DiagnosticLogger.exception('downloads', 'read_cleanup_failed', error)
      })
    }
  }

  private handleSourceContinuedAway(): void {
    if (!this.readerOpen || this.readerClosing || !this.isReaderRouteVisible()) {
      appReaderContinuation.setContinuedAway(false)
      return
    }
    this.readingStatisticsRecorder.setActive(false)
    const committed = this.readerSessionPersistenceReady && this.readerSessionStore.flush()
    const sourceIncognito = this.incognito.isSourceEnabled(this.readerSessionConfig.sourceRuntimeId) ||
      this.privateContinuationSession(this.readerSessionConfig.comicId)
    if (!sourceIncognito) {
      if (committed) appDeviceSync.readingContinuedAway()
      else appDeviceSync.retainBlockedReading()
    }
    this.syncReaderContinuationState()
    this.showContinuationAwayDialog()
  }

  @Builder
  private ContinuationAwayDialogContent() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(AppStrings.get('continuation_source_away_message'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      if (this.continuationAwayResuming) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          LoadingProgress().width(20).height(20).color(ThemeConstants.BRAND_PRIMARY)
          Text(AppStrings.get('history_resume_loading'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_XS })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ContinuationAwayDialog() {
    CustomContentDialogV2({
      primaryTitle: AppStrings.get('continuation_source_away_title'),
      contentBuilder: (): void => { this.ContinuationAwayDialogContent() },
      buttons: [
        new AdvancedDialogV2Button({
          content: AppStrings.get('continuation_close_reader'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          enabled: !this.continuationAwayResuming,
          action: (): void => {
            this.closeContinuationAwayDialog()
            // The shared reader emits its last observed page while closing.
            // Keep the sent session frozen until that callback has finished.
            this.closeReader()
          },
        }),
        new AdvancedDialogV2Button({
          content: AppStrings.get('continuation_resume_here'),
          fontColor: ColorMetrics.resourceColor(ThemeConstants.BRAND_PRIMARY),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          enabled: !this.continuationAwayResuming,
          action: (): void => {
            void this.resumeReaderAfterContinuationAway()
          },
        }),
      ],
    })
  }

  private showContinuationAwayDialog(): void {
    if (this.continuationAwayDialogId >= 0) return
    this.continuationAwayResuming = false
    const prompt = this.getUIContext().getPromptAction()
    void prompt.openCustomDialog({
      systemMaterial: komaDialogMaterial(),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      builder: (): void => { this.ContinuationAwayDialog() },
      onWillDismiss: (_action: DismissDialogAction): void => {},
    }).then((id: number): void => {
      if (this.continuationRuntime.continuedAway && this.readerOpen && !this.readerClosing) {
        this.continuationAwayDialogId = id
      } else {
        prompt.closeCustomDialog(id)
      }
    }).catch((): void => {
      appReaderContinuation.setContinuedAway(false)
    })
  }

  private closeContinuationAwayDialog(): void {
    this.continuationAwayResuming = false
    if (this.continuationAwayDialogId < 0) return
    const id = this.continuationAwayDialogId
    this.continuationAwayDialogId = -1
    try {
      this.getUIContext().getPromptAction().closeCustomDialog(id)
    } catch (_error) {
    }
  }

  private async resumeReaderAfterContinuationAway(): Promise<void> {
    if (this.continuationAwayResuming) return
    this.continuationAwayResuming = true
    const config = this.readerSessionConfig
    const openEpoch = this.readerOpenEpoch
    const sourceRequest = this.activeSourceReaderRequest
    const comic = sourceRequest !== undefined && sourceRequest.comicId === config.comicId
      ? undefined : this.readerComicForOpen(config.comicId)
    const syncSourceId = sourceRequest?.sourceId ?? comic?.sourceRuntimeId ?? config.sourceRuntimeId ?? ''
    const syncMangaId = sourceRequest?.mangaId ?? comic?.remoteResourceId ?? ''
    let syncedChapterId: string | undefined
    let syncedPageIndex: number | undefined
    let askConflict: SyncReadingWorkConflict | undefined
    let askRequest: SourceReaderSessionRequest | undefined
    let refreshedSession: SourceReaderSessionRequest | undefined
    try {
      if (syncSourceId.length > 0 && syncMangaId.length > 0 && !this.incognito.enabled &&
        !this.privateContinuationSession(config.comicId) &&
        !this.incognito.isSourceEnabled(syncSourceId)) {
        const syncRequest: SourceReaderSessionRequest = sourceRequest !== undefined && sourceRequest.comicId === config.comicId
          ? sourceRequest : {
            comicId: config.comicId,
            sourceId: syncSourceId,
            mangaId: syncMangaId,
            mangaUrl: comic?.sourcePath ?? config.sourceMangaUrl,
            sourceName: comic?.sourceMetadata?.sourceName,
            title: comic?.title ?? config.title ?? config.comicId,
            chapterId: config.chapterId,
            chapterIds: config.chapterIds.slice(),
            chapterTitles: config.chapterTitles?.slice(),
          }
        const conflict = await appDeviceSync.waitForReadingSync(syncRequest)
        if (conflict !== undefined) {
          const decision = continuationResumeResolution(conflict.local, conflict.remote)
          if (decision === 'ask') {
            askConflict = conflict
            askRequest = syncRequest
          } else {
            await appDeviceSync.resolveReadingResumeConflict(conflict, decision === 'remote')
            refreshedSession = syncRequest
          }
        }
        const latest = this.readerSessionStore.getProgress(config.comicId)
        if (askConflict === undefined && latest !== undefined &&
          (latest.chapterId !== config.chapterId || latest.pageIndex !== this.readerPageIndex)) {
          syncedChapterId = latest.chapterId
          syncedPageIndex = latest.pageIndex
        }
      }
    } catch (_error) {
    }
    if (this.readerOpenEpoch !== openEpoch || !this.continuationRuntime.continuedAway) return
    this.closeContinuationAwayDialog()
    appReaderContinuation.setContinuedAway(false)
    if (!this.readerOpen || this.readerClosing) return
    if (askConflict !== undefined && askRequest !== undefined) {
      this.syncReadingSessionActivity()
      this.syncReaderContinuationState()
      this.showReadingResumeConflict(askConflict, askRequest)
      return
    }
    if (syncedChapterId !== undefined && syncedPageIndex !== undefined) {
      if (sourceRequest !== undefined && sourceRequest.comicId === config.comicId) {
        const nextRequest = sourceReaderSessionRequestForChapter(sourceRequest, syncedChapterId) ?? {
          comicId: sourceRequest.comicId,
          sourceId: sourceRequest.sourceId,
          mangaId: sourceRequest.mangaId,
          mangaUrl: sourceRequest.mangaUrl,
          title: sourceRequest.title,
          coverUri: sourceRequest.coverUri,
          sourceName: sourceRequest.sourceName,
          readingFormat: sourceRequest.readingFormat,
          chapterId: syncedChapterId,
          chapterIds: sourceRequest.chapterIds.includes(syncedChapterId)
            ? sourceRequest.chapterIds.slice() : sourceRequest.chapterIds.concat([syncedChapterId]),
          chapterTitles: sourceRequest.chapterTitles?.slice(),
          chapters: sourceRequest.chapters,
          chaptersResolved: false,
        }
        await this.openSourceReader(nextRequest, 'resume', undefined, syncedPageIndex)
      } else {
        await this.openReader(config.comicId, syncedChapterId, 'resume', undefined, undefined, syncedPageIndex)
      }
    } else if (refreshedSession !== undefined) {
      appDeviceSync.beginReadingChapter(refreshedSession)
    }
    this.syncReadingSessionActivity()
    this.syncReaderContinuationState()
  }

  private async processPendingContinuationTask(): Promise<void> {
    const task = appReaderContinuation.consumePendingRestore()
    if (task === undefined) return
    this.pendingContinuationAfterSourceInstall = undefined
    await this.restoreContinuedWork(task)
  }

  private async restoreContinuedWork(task: RestoredContinuationTask): Promise<void> {
    const isCurrent = (): boolean => this.continuationReadyForRestore && this.continuationState.enabled &&
      appReaderContinuation.isCurrentRestore(task.id)
    if (!isCurrent()) return
    this.activeContinuationRestore = task
    try {
      if (!isCurrent() || !await this.ensureContinuationPrivacyUnlocked(task, isCurrent) || !isCurrent()) return
      if (!await this.ensureContinuationSourceReady(task, isCurrent) || !isCurrent()) return
      // Installing or enabling a source can outlive the first local auth grant.
      if (!await this.ensureContinuationPrivacyUnlocked(task, isCurrent) || !isCurrent()) return
      await this.openContinuedWork(task.payload)
    } finally {
      appReaderContinuation.cleanupDistributedTempFile(task.sourcePackagePath)
      if (this.activeContinuationRestore === task) this.activeContinuationRestore = undefined
      if (this.activeContinuationRestore?.payload.comicId !== task.payload.comicId &&
        (!this.readerOpen || this.readerSessionConfig.comicId !== task.payload.comicId)) {
        this.libraryPrivacy.releaseContinuationPrivacy(task.payload.comicId)
      }
    }
  }

  private async ensureContinuationPrivacyUnlocked(
    task: RestoredContinuationTask,
    isCurrent: () => boolean,
  ): Promise<boolean> {
    const payload = task.payload
    const summary = this.libraryStore.getComicSummary(payload.comicId)
    const localPrivateCategoryId = summary?.categoryIds?.find((id: string): boolean => this.privateCategoryIds.has(id))
    const needsAuth = payload.requiresPrivacyAuth || localPrivateCategoryId !== undefined
    if (!needsAuth) return true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const authResult = localPrivateCategoryId === undefined
      ? await this.libraryPrivacy.activateContinuationPrivacy(context, payload.comicId, isCurrent)
      : await this.libraryPrivacy.openCategory(context, localPrivateCategoryId, isCurrent)
    if (!isCurrent()) return false
    if (authResult === LibraryPrivacyAuthResult.SUCCESS) return true
    const message = libraryPrivacyAuthMessage(authResult) || AppStrings.get('continuation_privacy_required')
    this.showToast(message)
    return false
  }

  private async ensureContinuationSourceReady(
    task: RestoredContinuationTask,
    isCurrent: () => boolean,
  ): Promise<boolean> {
    const payload = task.payload
    const lookup = this.sourceRegistry.lookup(payload.sourceId)
    if (lookup.ok && lookup.entry !== undefined && sourceRuntimeEntryEnabled(lookup.entry)) {
      return true
    }
    const offline = await this.readOfflineReaderChapter(payload.comicId, payload.chapterId)
    if (!isCurrent()) return false
    if (offline?.status === OfflineDownloadedChapterStatus.DOWNLOADED) {
      return true
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const installed = getInstalledSourcePackage(payload.sourceId)
    if (installed !== undefined && !installed.enabled) {
      if (this.continuationState.autoInstallMissingSource) {
        return this.enableContinuationSource(context, payload)
      }
      return new Promise<boolean>((resolve: (value: boolean) => void): void => {
        let settled = false
        const finish = (value: boolean): void => {
          if (!settled) { settled = true; resolve(value) }
        }
        this.getUIContext().showAlertDialog({
          title: AppStrings.format('continuation_enable_source_title', payload.sourceName),
          message: AppStrings.format('continuation_enable_source_message', payload.sourceName),
          systemMaterial: komaDialogMaterial(),
          autoCancel: false,
          primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => { finish(false) } },
          secondaryButton: {
            value: AppStrings.get('continuation_enable_and_continue'),
            action: (): void => { finish(isCurrent() && this.enableContinuationSource(context, payload)) },
          },
          cancel: (): void => { finish(false) },
        })
      })
    }

    if (task.sourcePackageUri !== undefined && task.sourcePackageUri.length > 0) {
      if (this.continuationState.autoInstallMissingSource) {
        this.showToast(AppStrings.format('continuation_auto_installing_source', payload.sourceName))
        return this.installContinuationSourceArchive(context, task, isCurrent)
      }
      const accepted = await new Promise<boolean>((resolve: (value: boolean) => void): void => {
        let settled = false
        const finish = (value: boolean): void => {
          if (!settled) { settled = true; resolve(value) }
        }
        this.getUIContext().showAlertDialog({
          title: AppStrings.get('continuation_install_source_title'),
          message: payload.requiresPrivacyAuth
            ? payload.sourceName
            : AppStrings.format('continuation_install_source_message', payload.sourceName, payload.sourceId, payload.title),
          systemMaterial: komaDialogMaterial(),
          autoCancel: false,
          primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => { finish(false) } },
          secondaryButton: {
            value: AppStrings.get('continuation_install_and_continue'),
            action: (): void => { finish(true) },
          },
          cancel: (): void => { finish(false) },
        })
      })
      if (!isCurrent() || !accepted) return false
      return this.installContinuationSourceArchive(context, task, isCurrent)
    }

    this.pendingContinuationAfterSourceInstall = task
    RouterHelper.promptMissingSourceRecovery(this.getUIContext(), payload.sourceId, payload.sourceName, true)
    return false
  }

  private enableContinuationSource(context: common.UIAbilityContext, payload: ReaderContinuationPayload): boolean {
    if (!setSourcePackageEnabled(context, payload.sourceId, true)) {
      this.showToast(AppStrings.format('continuation_install_source_failed', payload.sourceName))
      return false
    }
    const source = getInstalledSourcePackage(payload.sourceId)
    if (source !== undefined) appSourcePackageManagerCache.recordInstalledPackage(source)
    return true
  }

  private async installContinuationSourceArchive(
    context: common.UIAbilityContext,
    task: RestoredContinuationTask,
    isCurrent: () => boolean,
  ): Promise<boolean> {
    const uri = task.sourcePackageUri
    const payload = task.payload
    if (uri === undefined || uri.length === 0) return false
    try {
      const result = await new SourceIndexService(context).installLocalArchive(uri, payload.sourceId, isCurrent)
      if (!isCurrent()) return false
      if (result.ok) {
        const installedId = result.id ?? payload.sourceId
        const source = getInstalledSourcePackage(installedId)
        if (source !== undefined) appSourcePackageManagerCache.recordInstalledPackage(source)
        const lookup = this.sourceRegistry.lookup(payload.sourceId)
        if (lookup.ok && lookup.entry !== undefined) {
          if (!sourceRuntimeEntryEnabled(lookup.entry)) {
            return this.enableContinuationSource(context, payload)
          }
          return true
        }
      }
    } catch (error) {
      DiagnosticLogger.exception('continuation', 'install_source_archive_failed', error as Error)
    }
    if (!isCurrent()) return false
    this.pendingContinuationAfterSourceInstall = {
      id: task.id,
      payload,
    }
    this.showToast(AppStrings.format('continuation_install_source_failed', payload.sourceName))
    RouterHelper.openMissingSourceRecovery(payload.sourceId, payload.sourceName)
    return false
  }

  private async openContinuedWork(payload: ReaderContinuationPayload): Promise<void> {
    const previousWork = this.readerSessionConfig.comicId
    this.closeContinuationAwayDialog()
    this.settingsModalShown = false
    const routes = this.appPathStack.getAllPathName()
    if (routes.length > 0 && !this.isReaderRouteVisible() && !this.isReaderDetailRouteVisible()) {
      if (routes.includes(RouteName.READER)) this.appPathStack.popToName(RouteName.READER, false)
      else this.appPathStack.clear(false)
    }
    appReaderContinuation.setContinuedAway(false)
    const libraryComic = this.libraryStore.getComicSummary(payload.comicId)
    if (libraryComic !== undefined && libraryComic.sourceRuntimeId === payload.sourceId) {
      await this.openReader(libraryComic.id, payload.chapterId, 'resume', undefined, undefined, payload.pageIndex)
    } else {
      await this.openSourceReader(buildSourceRequestFromContinuation(payload), 'resume', undefined, payload.pageIndex)
    }
    if (this.readerSessionConfig.comicId !== previousWork) this.libraryPrivacy.releaseContinuationPrivacy(previousWork)
  }

  private reloadReaderSessionStore(reason: string): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context.filesDir === undefined || context.filesDir.length === 0) {
        return
      }
      this.persistentReaderSessionStore = appReaderSessionStore(context.filesDir)
      this.incognitoReaderSessionStore = undefined
      this.applyIncognitoReaderStore()
      this.readerSessionPersistenceReady = true
      this.readerProgressRevision += 1
      console.info(`[Reader] step=progress_store_reloaded reason=${reason}`)
    } catch (_error) {
      DiagnosticLogger.warn('index', 'restore_progress_failed', '[Reader] step=restore_progress_failed reason=session_store')
    }
  }

  // Incognito keeps reading progress in a memory overlay seeded from the real
  // store: resume and history work during the session, while nothing reaches
  // the persistent record. Turning incognito off switches back to the real
  // store, so the pre-incognito state returns intact.
  private applyIncognitoReaderStore(): void {
    const base = this.persistentReaderSessionStore
    if (base === undefined) return
    if (this.incognito.enabled) {
      if (this.incognitoReaderSessionStore === undefined) {
        const memory = new InMemoryReaderSessionStore()
        memory.restoreReadingState(base.snapshotReadingState())
        this.incognitoReaderSessionStore = memory
      }
      this.readerSessionStore = this.incognitoReaderSessionStore
    } else {
      this.incognitoReaderSessionStore = undefined
      this.readerSessionStore = base
    }
    this.readerTrackerProgress = undefined
  }

  @Monitor('incognito.enabled')
  private syncIncognitoReaderStore(): void {
    this.applyIncognitoReaderStore()
    this.readerProgressRevision += 1
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
    if (this.continuationRuntime.continuedAway || !this.readerSessionPersistenceReady ||
      this.privateContinuationSession(comicId) ||
      comicId !== this.readerSessionConfig.comicId ||
      chapterId !== this.readerSessionConfig.chapterId ||
      this.incognito.isSourceEnabled(this.readerSessionConfig.sourceRuntimeId)) return
    this.syncReadingSessionActivity()
    this.readingStatisticsRecorder.observePages(comicId, chapterId, pages)
  }

  private persistReaderLabObserved(position: ReaderObservedPosition,
    column: 'odd_left' | 'even_left'): void {
    if (this.continuationRuntime.continuedAway || !this.readerSessionPersistenceReady ||
      this.privateContinuationSession(position.anchor.unit.work) ||
      position.anchor.unit.scope !== 'koma-local') return
    const anchor = position.anchor
    const current = this.readerSessionConfig
    // The active route only reads the exact page ID and page count here.
    // Catalog consumers still receive detached configs with their full arrays.
    const config = current.comicId === anchor.unit.work && current.chapterId === anchor.unit.unit && current.totalPages > 0
      ? current : this.readerLabInitialConfig(anchor.unit.work, anchor.unit.unit)
    // The reader still advances its live page index, so paging and crossing
    // chapters work while the last recorded position and history stay intact.
    if (config === null || this.incognito.isSourceEnabled(config.sourceRuntimeId)) return
    if (config.chapterId !== anchor.unit.unit || config.totalPages !== position.pageCount ||
      anchor.sourceIndexHint < 0 || anchor.sourceIndexHint >= config.totalPages) return
    const index = anchor.sourceIndexHint
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
    // Incognito writes progress into its memory overlay so resume works, but
    // cross-device sync and tracker observation stay suppressed.
    this.readerSessionStore.saveProgress(progress, config.chapterTitle)
    if (!this.incognito.enabled) {
      appDeviceSync.observeReading(progress)
      if (this.readerOpen) this.observeReaderTrackerProgress(progress)
    }
    // Keep page persistence live, but do not rebuild the covered shelf/history
    // and full chapter catalog on every page crossing. Reader close publishes
    // the saved state; a detail destination also refreshes in onShown.
    if (!this.isReaderRouteVisible()) this.readerProgressRevision += 1
  }

  private onBackupRestored(): void {
    this.readingStatisticsRecorder.reset()
    setCachedLibraryChapterUpdates(undefined)
    appSourcePackageManagerCache.invalidate()
    this.catalogFilters.invalidate()
    void this.catalogFilters.prepare(getContext(this) as common.UIAbilityContext)
      .catch((): void => { DiagnosticLogger.warn('source_catalog', 'filters_load_failed', 'phase=restore') })
    this.readerTrackerProgress?.resetAfterRestore()
    this.ensureLibraryPersistenceService()?.restoreForLaunch(this.savedShelfCategory())
    new TrackerPreferencesStore(getContext(this) as common.UIAbilityContext).invalidateMappingSnapshot()
    this.libraryPreferencesRevision += 1
    void synchronizeBackgroundMaintenance(getContext(this) as common.UIAbilityContext)
      .catch((error: Error): void => { DiagnosticLogger.exception('maintenance', 'restore_schedule_failed', error) })
    this.applicationSettingsRestoreRevision += 1
    this.readerProgressRevision += 1
    this.refreshLibrarySnapshot()
    this.loadLibraryChapterUpdateHistory(getContext(this) as common.UIAbilityContext)
    this.syncReaderContinuationState()
  }

  private refreshMihonImport(): void {
    this.refreshLibrarySnapshot()
    this.refreshReadingPresentation()
  }

  private onMihonImported(): void {
    this.refreshMihonImport()
    this.queueMihonMatching()
  }

  private queueMihonMatching(sourceIds?: string[], directOnly: boolean = false): void {
    if (!this.libraryStore.listMihonImportWorks().some((record: MihonImportWork): boolean => !record.targetComicId)) return
    const service = new MihonImportService(getContext(this) as common.UIAbilityContext, this.libraryStore)
    this.mihonMatching = this.mihonMatching.then((): Promise<boolean> =>
      service.matchUnresolved(sourceIds, directOnly))
      .then((changed: boolean): void => {
      if (changed) this.refreshMihonImport()
    }).catch((error: Error): void => { DiagnosticLogger.exception('backup', 'mihon_background_match_failed', error) })
  }

  @Monitor('mihonSourceState.revision')
  private retryMihonAfterSourceChange(): void {
    if (!this.libraryPersistenceRestored) return
    const versions = new Map<string, string>()
    const changed: string[] = []
    for (const source of this.sourceRegistry.listInstalledSourceSummaries()) {
      const entry = this.sourceRegistry.lookup(source.sourceId).entry
      if (!source.enabled || entry === undefined) continue
      const version = entry.manifestVersion + ':' + JSON.stringify(entry.mihonImport ?? null) + ':' + (entry.catalogOrigin ?? '')
      versions.set(source.sourceId, version)
      if (version !== this.mihonSourceVersions.get(source.sourceId)) changed.push(source.sourceId)
    }
    const firstLoad = !this.mihonSourceVersionsLoaded
    this.mihonSourceVersionsLoaded = true
    this.mihonSourceVersions = versions
    if (changed.length > 0) this.queueMihonMatching(changed, firstLoad)
    const pending = this.pendingContinuationAfterSourceInstall
    if (pending !== undefined) {
      const lookup = this.sourceRegistry.lookup(pending.payload.sourceId)
      if (lookup.ok && lookup.entry !== undefined && sourceRuntimeEntryEnabled(lookup.entry)) {
        this.pendingContinuationAfterSourceInstall = undefined
        void this.restoreContinuedWork(pending).catch((error: Error): void => {
          DiagnosticLogger.exception('continuation', 'target_open_after_install_failed', error)
        })
      }
    }
  }

  private loadLibraryChapterUpdateHistory(context: common.UIAbilityContext): void {
    void new LibraryUpdateResultStore(context).loadChapterUpdates()
      .then((): void => {
        this.libraryPresentationPending = true
        if (!this.isReaderRouteVisible()) this.publishDeferredReaderBackgroundPresentation()
      })
      .catch((): void => { DiagnosticLogger.warn('library_updates', 'history_load_failed', 'phase=preferences') })
    this.refreshLibraryUpdateBadge(context)
  }

  private refreshLibraryUpdateBadge(context: common.UIAbilityContext): void {
    const revision = ++this.libraryUpdateBadgeRevision
    void new LibraryUpdateResultStore(context).hasUnseenChapterUpdates().then((unseen: boolean): void => {
      if (revision === this.libraryUpdateBadgeRevision) this.libraryUpdatesUnseen = unseen
    }).catch((): void => {})
  }

  private markLibraryUpdatesSeen(): void {
    const context = getContext(this) as common.UIAbilityContext
    void new LibraryUpdateResultStore(context).markChapterUpdatesSeen()
      .then((): void => { this.refreshLibraryUpdateBadge(context) }).catch((): void => {})
  }

  private openLibraryMangaDetail(comicId: ComicId, newInstance: boolean = false): void {
    if (!this.canOpenLibraryComic(comicId)) return
    // Existing search rows can still refer to the imported ID after a
    // successful link has replaced the corresponding shelf entry.
    if (comicId.startsWith('mihon:')) {
      void this.openMihonImportedWork(comicId, false)
      return
    }
    const comic = this.libraryStore.getComicSummary(comicId)
    if (comic === undefined) {
      return
    }
    const sourceId = comic.sourceRuntimeId?.trim() ?? ''
    const remoteMangaId = comic.remoteResourceId?.trim() ?? ''
    const params: MangaDetailRouteParam = sourceId.length > 0 && remoteMangaId.length > 0
      ? {
        mangaId: remoteMangaId,
        sourceId,
        sourceName: comic.sourceMetadata?.sourceName,
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
        sourceName: sourceRequest.sourceName,
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
    if (comic === undefined && (this.activeReaderComicSnapshot?.id === comicId ||
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
        sourceName: comic?.sourceMetadata?.sourceName,
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
        const passwordRequired = results.length === 1 && results[0].status === 'failed' &&
          results[0].error === LOCAL_IMPORT_PDF_PASSWORD_REQUIRED
        this.showToast(passwordRequired ? AppStrings.get('import_pdf_password_required') :
          AppStrings.format('import_feedback_failed_files', failedCount))
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

  private openSettingsSecondary(routeName: string, stack: NavPathStack = this.appPathStack): void {
    if (routeName === RouteName.DOWNLOADS) {
      this.leaveSettingsModalFor((): void => { RouterHelper.pushDownloads() }, stack !== this.appPathStack)
      return
    }
    if (routeName !== RouteName.SOURCE_PACKAGE_MANAGER) {
      stack.pushPath({ name: routeName })
      return
    }
    if (this.sourceManagerOpening) return
    this.sourceManagerOpening = true
    const context = getContext(this) as common.UIAbilityContext
    // Disk hydration finishes before the destination exists; a warm revisit
    // consumes the same ready snapshot, without another network check.
    void appSourcePackageManagerCache.prepare(context, connectLanguageState().effectiveLocale).then((): void => {
      if (stack !== this.appPathStack && stack !== this.settingsModalStack) return
      appSourcePackageManagerCache.revalidateInBackground(context)
      stack.pushPath({ name: routeName,
        param: { settingsSourceId: '', chrome: new SourceCatalogPageChrome() } as SourcePackageManagerRouteParam })
    }).finally((): void => { this.sourceManagerOpening = false })
  }

  private async openMihonImportedWork(comicId: string, resume: boolean = true, fromHistory: boolean = false): Promise<boolean> {
    let imported = this.libraryStore.getMihonImportWork(comicId)
    if (imported === undefined) return false
    // An exact edition can show its detail immediately. Its successful catalog
    // load resolves the original progress with the same response.
    if (!imported.targetComicId && (resume ? fromHistory || imported.linkedWork !== undefined ||
      imported.matchedSourceId !== undefined : imported.linkedWork === undefined && imported.matchedSourceId !== undefined)) {
      this.closeHistoryResumeLoading()
      const generation = ++this.sourceReaderOpenRequest
      const tab = this.selectedTab
      const route = this.appPathStack.getAllPathName().join('/')
      const current = (): boolean => generation === this.sourceReaderOpenRequest && this.selectedTab === tab &&
        this.appPathStack.getAllPathName().join('/') === route && this.appForegroundState.active &&
        (!fromHistory || this.rootNavigation.visible)
      const timer = this.startHistoryResumeLoading(current,
        resume ? $r('app.string.history_resume_loading') : $r('app.string.manga_detail_loading_source'))
      try {
        const service = new MihonImportService(getContext(this) as common.UIAbilityContext, this.libraryStore)
        await service.retryFromHistory(comicId, current)
      } catch (error) {
        DiagnosticLogger.exception('backup', 'mihon_history_retry_failed', error as Error)
      } finally {
        if (this.historyResumeLoadingTimer === timer) this.closeHistoryResumeLoading()
      }
      if (!current()) return true
      const updated = this.libraryStore.getMihonImportWork(comicId)
      if (updated === undefined) {
        this.showToast(AppStrings.get('mihon_import_resume_failed'))
        return true
      }
      if (updated !== imported) {
        // The reader can open from the committed rows. Refresh the covered
        // list on its next appearance instead of rebuilding it during resume.
        this.libraryPresentationPending = true
        this.queueReadingPresentation(updated.targetComicId === undefined ? [comicId] : [comicId, updated.targetComicId])
      }
      imported = updated
    }
    const target = imported.targetComicId
    const existing = target === undefined ? undefined : this.libraryStore.getComic(target)
    const progress = target === undefined ? undefined : this.readerSessionStore.getProgress(target)
    const paths = this.appPathStack.getAllPathName()
    const top = paths.length - 1
    const detail = paths[top] === RouteName.MANGA_DETAIL ?
      this.appPathStack.getParamByIndex(top) as MangaDetailRouteParam | undefined : undefined
    if (resume && (target !== undefined || imported.linkedWork !== undefined) &&
      (detail?.mangaId === comicId || detail?.sourceId === 'mihon:' + imported.work.sourceId &&
        detail.mangaId === (imported.work.url.trim() || comicId))) {
      this.appPathStack.pop(false)
    }
    if (existing !== undefined) {
      if (resume && progress !== undefined && existing.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId)) {
        await this.openReader(existing.id, progress.chapterId)
      } else {
        const hasOriginalHistory = resume && (this.libraryStore.readMihonImport(comicId)?.work.history.length ?? 0) > 0
        if (resume && !hasOriginalHistory && existing.chapters.length > 0) {
          await this.openReader(existing.id)
        } else {
          if (hasOriginalHistory) this.showToast(AppStrings.get('mihon_import_resume_chapter_unmatched'))
          this.openLibraryMangaDetail(existing.id, !resume)
        }
      }
    } else if (imported.linkedWork !== undefined) {
      const work = imported.linkedWork
      const history = target === undefined ? undefined : this.readerSessionStore.getSourceHistoryForResume(target)
      const request = history !== undefined && history.chapterId === progress?.chapterId ?
        sourceReaderSessionRequestFromHistory(history) : undefined
      if (resume && request !== undefined) {
        await this.openSourceReader(request)
      } else if (detail?.sourceId !== work.sourceId || detail.mangaId !== work.id) {
        if (resume && target !== undefined) this.showToast(AppStrings.get('mihon_import_resume_chapter_unmatched'))
        RouterHelper.pushMangaDetail({ mangaId: work.id, sourceId: work.sourceId, initialManga: work,
          mihonImportId: target === undefined ? comicId : undefined }, true)
      } else if (resume) {
        this.showToast(AppStrings.get(target === undefined ? 'mihon_import_resume_failed' : 'mihon_import_resume_chapter_unmatched'))
      }
    } else if (!resume) {
      RouterHelper.pushMangaDetail({ mangaId: comicId }, true)
    } else {
      this.showToast(AppStrings.get('mihon_import_original_source_unmatched'))
      // A successful match removes the placeholder from the library. Retire
      // its detail route too when reading from it opened the matching flow.
      const fromDetail = paths[paths.length - 1] === RouteName.MANGA_DETAIL
      await this.openMangaMigration([comicId], fromDetail, true)
    }
    if (this.rootNavigation.visible && this.appPathStack.getAllPathName().length === 0) {
      this.publishDeferredReaderBackgroundPresentation()
    }
    return true
  }

  private async openMangaMigration(comicIds: string[], fromDetail: boolean, fromMihon: boolean = false): Promise<void> {
    if (this.migrationOpening) return
    this.migrationOpening = true
    try {
      const store = new MangaMigrationPreferencesStore(getContext(this) as common.UIAbilityContext)
      const selectedSources = await store.load()
      const matchOptions = await store.loadOptions()
      const param: MangaMigrationRouteParam = { comicIds, fromDetail, fromMihon, selectedSources, matchOptions }
      RouterHelper.ensureMigrationRouteChrome(param)
      this.appPathStack.pushPath({ name: RouteName.MANGA_MIGRATION, param })
    } catch (_) {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('migration_preferences_load_failed') }))
    } finally { this.migrationOpening = false }
  }

  private openSettingsPane(pane: SettingsPaneKey, rowKey?: string, fromHome: boolean = false, stack: NavPathStack = this.appPathStack): void {
    if (pane === 'backup' && rowKey === 'device-sync') {
      const param: DeviceSyncWebDavRouteParam = { chrome: new DeviceSyncWebDavChrome() }
      this.presentSettingsDestination(RouteName.DEVICE_SYNC, param, fromHome, param.chrome.scroller, stack)
      return
    }
    if (pane === 'backup' && rowKey === 'device-sync-webdav') {
      const param: DeviceSyncWebDavRouteParam = { chrome: new DeviceSyncWebDavChrome() }
      this.presentSettingsDestination(RouteName.DEVICE_SYNC_WEBDAV, param, fromHome, param.chrome.scroller, stack)
      return
    }
    if (pane === 'backup' && rowKey === 'device-sync-huawei') {
      const param: DeviceSyncWebDavRouteParam = { chrome: new DeviceSyncWebDavChrome() }
      this.presentSettingsDestination(RouteName.DEVICE_SYNC_HUAWEI, param, fromHome, param.chrome.scroller, stack)
      return
    }
    // Backup owns its configuration and task navigation; do not insert a
    // second settings directory whose entries all open the same home page.
    if (pane === 'backup') {
      const param: BackupManagementRouteParam = { searchTarget: rowKey ?? '', scroller: new Scroller() }
      this.presentSettingsDestination(RouteName.BACKUP_MANAGEMENT, param, fromHome, param.scroller, stack)
      return
    }
    if (pane === 'tracking') {
      this.presentSettingsDestination(RouteName.TRACKER_SETTINGS, { searchTarget: rowKey ?? '' } as SettingsSearchRouteParam, fromHome, undefined, stack)
      return
    }
    const routeParam: SettingsPaneRouteParam = { pane: pane, searchTarget: rowKey, formTitleAction: new FormTitleActionState(),
      modelSourcesTitleAction: new ModelSourcesTitleAction() }
    this.presentSettingsDestination(RouteName.SETTINGS_PANE, routeParam, fromHome, undefined, stack)
  }

  private presentSettingsDestination(name: string, param: Object, fromHome: boolean, scroller?: Scroller,
    stack: NavPathStack = this.appPathStack): void {
    // This decision belongs to the entry action. Keep an open sheet and its
    // scroll position through resizes and deeper navigation until dismissal.
    if (fromHome && usesWideSettingsHome(this.layoutSafeArea.windowWidthVp)) {
      if (this.settingsModalDestination !== undefined) return
      const modalStack = new NavPathStack()
      modalStack.setInterception({
        interception: (from: NavPathInfo | NavBar, to: NavPathInfo | NavBar, _stack: NavPathStack,
          operation: NavigationOperation, animated: boolean): void => {
          if (from === 'navBar' || to === 'navBar' || !animated) {
            this.settingsModalTop = to === 'navBar' ? undefined : to
            this.settingsModalMotion = undefined
            return
          }
          // Set the initial positions before the framework creates the new route.
          this.settingsModalProgress = 0
          this.settingsModalMotion = { from, to, pushing: operation === NavigationOperation.PUSH }
        },
      })
      this.settingsModalStack = modalStack
      this.settingsModalDestination = { name, param, scroller: scroller ?? new Scroller() }
      const home: NavPathInfo = { name: SETTINGS_MODAL_HOME, param: this.settingsModalDestination }
      this.settingsModalTop = home
      this.settingsModalStack.pushPath(home, false)
      this.appPathStack.pushPath({ name: SETTINGS_MODAL_ROUTE }, false)
    } else {
      stack.pushPath({ name, param })
    }
  }

  private canDismissSettingsModal(): boolean {
    return this.settingsModalDestination?.name !== RouteName.BACKUP_MANAGEMENT || !BackupRestoreActivity.isRestoring()
  }

  private shouldDismissSettingsModal(reason: DismissReason): boolean {
    // ArkUI delivers Back to the sheet before its inner Navigation on some
    // window modes. Forward it to the displayed destination when it has a parent.
    if (reason === DismissReason.PRESS_BACK && this.settingsModalStack.size() > 1) {
      this.backWithinSettingsModal()
      return false
    }
    return this.canDismissSettingsModal()
  }

  private openDeviceSyncOverview(stack: NavPathStack = this.appPathStack): void {
    const param: DeviceSyncWebDavRouteParam = { chrome: new DeviceSyncWebDavChrome() }
    stack.pushPath({ name: RouteName.DEVICE_SYNC, param })
  }

  private openDeviceSyncWebDav(stack: NavPathStack = this.appPathStack): void {
    const param: DeviceSyncWebDavRouteParam = { chrome: new DeviceSyncWebDavChrome() }
    stack.pushPath({ name: RouteName.DEVICE_SYNC_WEBDAV, param })
  }

  private openDeviceSyncHuaweiCloud(stack: NavPathStack): void {
    const param: DeviceSyncWebDavRouteParam = { chrome: new DeviceSyncWebDavChrome() }
    stack.pushPath({ name: RouteName.DEVICE_SYNC_HUAWEI, param })
  }

  private openDeviceSyncConnection(stack: NavPathStack = this.appPathStack): void {
    const param: DeviceSyncConnectionRouteParam = { chrome: new DeviceSyncWebDavChrome(),
      titleKey: appDeviceSync.view.configured ? 'device_sync_edit' : 'device_sync_configure' }
    stack.pushPath({ name: RouteName.DEVICE_SYNC_CONNECTION, param })
  }

  private openDeviceSyncReview(groups: SyncGroup[], reason: DeviceSyncReviewReason,
    stack: NavPathStack = this.appPathStack): void {
    const param: DeviceSyncReviewRouteParam = { chrome: new DeviceSyncWebDavChrome(), groups, reason }
    stack.pushPath({ name: RouteName.DEVICE_SYNC_REVIEW, param })
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
    if (this.selectedTab === TabIndex.BROWSE && nextTab !== TabIndex.BROWSE) {
      this.setCatalogSearch(this.browseCatalogChrome, false)
    }
  }

  private settingsPaneFromParam(param: Object): SettingsPaneKey {
    const pane = (param as Record<string, string>)?.pane
    if (pane === 'appearance' ||
      pane === 'app-icon' ||
      pane === 'library' ||
      pane === 'grid-column-width' ||
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
      const boundScan = bindLocalLibraryFolderScanIdentity(scanResult, rootUri, localLibraryFolderComicsForRoot(this.libraryStore, rootUri))
      const comics = buildComicsFromLocalLibraryFolderScan(boundScan, rootUri)
      comics.forEach((comic: Comic) => {
        this.libraryStore.upsertComic(comic)
      })
      importedCount = comics.length
      rejectedEntryCount = scanResult.rejectedEntries.length
    } else {
      try {
        const previousKnownSeries = buildKnownLocalLibraryFolderSeriesFromComics(localLibraryFolderComicsForRoot(this.libraryStore, rootUri), rootUri)
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
      targetComics = this.libraryStore.listComicSummariesByKind([ComicSourceKind.LOCAL_FOLDER])
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
        localLibraryFolderComicsForRoot(this.libraryStore, rootUri),
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
      return isRemovableShelfComic(this.libraryStore.getComic(comicId))
    })
    console.info(`[library-remove] batch_requested count=${comicIds.length} removable=${removableIds.length}`)
    if (removableIds.length === 0) {
      console.info('[library-remove] batch_result removed=0')
      return 0
    }
    // A source favorite can be removed while its downloads remain usable,
    // matching the detail page's shelf toggle. Keep local cleanup separate.
    const localIds = new Set<ComicId>(removableIds.filter((comicId: ComicId): boolean =>
      isRemovableLocalComic(this.libraryStore.getComic(comicId))))
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      removableIds.forEach((comicId: ComicId) => {
        this.libraryStore.removeComic(comicId)
      })
      this.refreshLibrarySnapshot()
      removableIds.forEach((comicId: ComicId) => {
        if (localIds.has(comicId)) this.cleanupRemovedComicDownloads(comicId)
      })
      console.info(`[library-remove] batch_result removed=${removableIds.length} persistence=unavailable`)
      return removableIds.length
    }
    try {
      const removedIds = removeComicsAndPersistLibraryStore(this.libraryStore, persistenceService, removableIds)
      if (removedIds.length > 0) {
        this.refreshLibrarySnapshot()
        removedIds.forEach((comicId: ComicId) => {
          if (localIds.has(comicId)) this.cleanupRemovedComicDownloads(comicId)
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
      void new ReaderPreferencesStore(context).copyBannerOverride(comicId, '', true).catch((): void => {
        DiagnosticLogger.warn('index', 'banner_choice_cleanup_failed', '[library-remove] banner_choice_cleanup_failed')
      })
      void ensureKomaContentStorageBase(context)
        .then(async (storageBase: string): Promise<number> => {
          const runtimeKey = komaRuntimeStorageKey(context)
          await OfflineDownloadService.ensureQueueInitialized(storageBase, runtimeKey)
          return new OfflineDownloadQueueStore(storageBase, runtimeKey).deleteComicDownloads(comicId)
        })
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

  private savedShelfCategory(): string {
    try {
      return new LibraryFilterStore(getContext(this) as common.UIAbilityContext).loadSync().category
    } catch (_error) {
      return 'all'
    }
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
    const service = new BackupService(context)
    void service.ensureDefaultAutomaticBackupDirectory(komaContentStorageUri())
      .catch((error: Error): void => {
        DiagnosticLogger.exception('backup', 'automatic_default_directory_failed', error)
      })
      .then(() => service.runAutomaticLocalBackupIfDue(Date.now(), true))
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
    this.continuationReadyForRestore = false
    appReaderContinuation.attachSourceHandlers()
    this.detailTransition.reset()
    this.rootTabScrollers.forEach((scroller: Scroller): void => { this.tabController.unbindScroller(scroller) })
    if (this.bottomBarAnimationTimer !== -1) clearTimeout(this.bottomBarAnimationTimer)
    this.bottomBarAnimationTimer = -1
    this.cancelHistoryResume()
    this.readingConflictHold?.()
    this.readingConflictHold = undefined
    this.readingStatisticsRecorder.close()
    if (this.catalogHeaderActions !== undefined && !this.catalogHeaderActions.isDisposed()) this.catalogHeaderActions.dispose()
    this.catalogHeaderActions = undefined
    this.catalogSearchContents.forEach((content: ComponentContent<SourceCatalogPageChrome>): void => {
      if (!content.isDisposed()) content.dispose()
    })
    this.catalogSearchContents.clear()
    if (this.readerSessionPersistenceReady) this.readerSessionStore.flush()
    this.closeContinuationAwayDialog()
    this.libraryPrivacy.releaseContinuationPrivacy(this.readerSessionConfig.comicId)
    appReaderContinuation.publishActiveReading(undefined)
    this.automaticDownloads?.dispose()
    this.automaticDownloads = undefined
  }

  aboutToAppear(): void {
    this.handleReaderLabLaunch()
    appReaderContinuation.attachSourceHandlers((): void => { this.handleSourceContinuedAway() })
    RouterHelper.setAppPathStack(this.appPathStack)
    RouterHelper.setReaderOpener(() => {
      this.openExternalReaderSession()
    })
    RouterHelper.consumePendingLaunchRoute()
    const context = getContext(this) as common.UIAbilityContext
    if (komaContentStorageBase(context) === context.filesDir) this.retryPublicContentStorage(0)
    if (!this.readerSessionPersistenceReady) {
      this.reloadReaderSessionStore('app_appear')
    }
    appDeviceSync.attachPublisher((groups: SyncGroup[], readingComicIds?: string[], shelfEdits?: LibraryShelfSyncEdits): void => {
      if (groups.includes('shelf')) {
        if (shelfEdits === undefined) this.ensureLibraryPersistenceService()?.restoreForLaunch(this.savedShelfCategory())
        else applyLibraryShelfSyncEdits(context.filesDir, this.libraryStore, shelfEdits)
        this.refreshLibrarySnapshot()
      }
      if (groups.includes('reading')) this.refreshReadingPresentation(readingComicIds)
    })
    this.loadLibraryChapterUpdateHistory(context)
    configureSourceSettingsStore(context)
    configureSourceFilterPreferencesStore(context)
    void this.catalogFilters.prepare(context).catch((): void => {
      DiagnosticLogger.warn('source_catalog', 'filters_load_failed', 'phase=preferences')
    })
    if (this.sourceRegistry.count() === 0) {
      bootstrapSourceRuntimeAppRegistry(context)
    }
    // Publish saved package state for the first frame, including a saved
    // Browse tab. Network revalidation belongs to the first-frame follow-up.
    const sourcePackagesReady = appSourcePackageManagerCache.prepare(context, connectLanguageState().effectiveLocale)
      .then((): boolean => true)
      .catch((error: Error): boolean => {
        DiagnosticLogger.exception('source_index', 'startup_prepare_failed', error)
        return false
      })
    appSourceWebSessionStore.configure(context, this.sourceRegistry)
    if (!this.libraryPersistenceRestored) {
      this.libraryPersistenceRestored = true
      const persistenceService = this.ensureLibraryPersistenceService()
      if (persistenceService !== undefined) {
        try {
          persistenceService.restoreForLaunch(this.savedShelfCategory())
          bindRemoteProgressLibrary((): Comic[] => this.libraryStore.listComicSummariesByKind(
            [ComicSourceKind.KOMGA_REMOTE, ComicSourceKind.KAVITA_REMOTE])
            .map((comic: Comic): Comic => this.libraryStore.getComic(comic.id) as Comic))
          void activateLocalLibraryFolderAccessForComics(this.libraryStore.listComicSummariesByKind([ComicSourceKind.LOCAL_FOLDER]))
            .then((summary) => {
              console.info('[LocalFolderAccess] step=restore_activate roots=' + summary.rootCount +
                ' activated=' + summary.activatedCount +
                ' reselect=' + summary.notPersistedCount +
                ' unsupported=' + summary.unsupportedCount +
                ' failed=' + summary.failedCount)
            })
            .finally(() => {
              this.refreshLibrarySnapshot()
              this.afterStartupFrame((): void => {
                this.libraryUpdateReady = true
                this.retryMihonAfterSourceChange()
                if (!this.appForegroundState.active) this.resumeAutomaticDownloadQueue()
                this.runForegroundLibraryUpdate()
                this.runForegroundAutomaticBackup()
              })
            })
        } catch (error) {
          void error
          DiagnosticLogger.error('index', 'restore_failed', '[Library] step=restore_failed code=library_restore_failed')
        }
      }
    }
    this.afterStartupFrame((): void => {
      this.continuationReadyForRestore = true
      this.tryStartPendingContinuationTask()
      void sourcePackagesReady.then((ready: boolean): void => {
        if (ready) appSourcePackageManagerCache.revalidateInBackground(context)
      })
      ImageRuleStore.forContext(context).revalidateInBackground()
      if (!shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) this.triggerPendingTrackerProgressSync(context)
    })
  }

  /** The first layout requests its own frame. Start optional application work
   * from the following frame so it cannot delay rendering the initial page. */
  private afterStartupFrame(work: () => void): void {
    const ui = this.getUIContext()
    ui.postFrameCallback(new StartupFrame((): void => {
      ui.postFrameCallback(new StartupFrame(work))
    }))
  }

  /** The DOWNLOAD picker needs a foreground UI ability; retry after the first page is present. */
  private retryPublicContentStorage(attempt: number): void {
    setTimeout(() => {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      void ensureKomaContentStorageBase(hostContext).then((storageBase: string) => {
        if (storageBase !== hostContext.filesDir) {
          DiagnosticLogger.info('storage', 'content_storage_activated', 'root=public')
          void new BackupService(hostContext).ensureDefaultAutomaticBackupDirectory(komaContentStorageUri())
            .catch((error: Error): void => {
              DiagnosticLogger.exception('backup', 'automatic_default_directory_failed', error)
            })
          this.refreshLibrarySnapshot()
          this.refreshReadingPresentation()
          return
        }
        if (attempt < 2) this.retryPublicContentStorage(attempt + 1)
      }).catch((error: Error): void => {
        DiagnosticLogger.exception('storage', 'content_storage_retry_failed', error)
      })
    }, attempt === 0 ? 800 : 2500)
  }

  private catalogUpdateCount(): number {
    void this.sourcePackageManagerCache.revision
    return this.sourcePackageManagerCache.updateCount + this.imageRuleState.updateCount
  }

  @Builder
  TabIcon(title: string, idx: number) {
    KomaTabIcon({
      title: title,
      idx: idx,
      currentIndex: this.selectedTab,
      bounceTrigger: this.tabIconBounceTriggers[idx] ?? -1,
      badgeCount: idx === TabIndex.BROWSE ? this.catalogUpdateCount() : 0,
    })
  }

  private popMangaDetail(param: MangaDetailRouteParam): void {
    if (!MangaDetailTransitionCoordinator.preparePop(this.getUIContext(), param.transitionToken,
      (systemAnimation: boolean): void => {
        this.appPathStack.pop(systemAnimation || this.isReaderDetailRouteVisible())
      })) {
      this.appPathStack.pop(this.isReaderDetailRouteVisible())
    }
  }

  private ownsDetailTransition(param: MangaDetailRouteParam): boolean {
    return this.detailTransition.owns(param.transitionToken)
  }

  private readerOrdinaryNavTransition(_from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    if (operation !== NavigationOperation.PUSH || to.name !== RouteName.READER ||
      !this.readerRouteTransition.pending()) return undefined
    return this.readerRouteTransition.transition(this.getUIContext(), (_success: boolean): void => {})
  }

  @Builder
  private ReaderDestination() {
    KomaReaderLabPage({
        request: this.sharedReaderRequest,
        productionEntry: true,
        inputLocked: this.continuationRuntime.continuedAway,
        routeTransition: this.readerRouteTransition,
        closeRequestId: this.readerCloseRequestId,
        entryStage: this.readerEntryStage,
        catalogHost: this.sharedReaderCatalogHost,
        webChallenge: this.readerWebChallenge,
        onWebChallengeFinished: (request: ReaderSourceWebChallenge, verified: boolean): void => {
          this.finishReaderWebChallenge(request, verified)
        },
        prepareInitial: async (): Promise<void> => { await this.readerPreparation },
        readInitialColumn: (work: string, unit: string): 'odd_left' | 'even_left' =>
          this.readReaderLabInitialColumn(work, unit),
        readInitialPage: (work: string, unit: string): number =>
          this.readerSessionConfig.comicId === work && this.readerSessionConfig.chapterId === unit
            ? this.readerPageIndex : this.readReaderLabInitialPage(work, unit),
        persistObserved: (position: ReaderObservedPosition, column: 'odd_left' | 'even_left'): void => {
          this.persistReaderLabObserved(position, column)
          if (!this.continuationRuntime.continuedAway &&
            position.anchor.unit.work === this.readerSessionConfig.comicId &&
            position.anchor.unit.unit === this.readerSessionConfig.chapterId &&
            position.anchor.sourceIndexHint >= 0 && position.anchor.sourceIndexHint < this.readerSessionConfig.totalPages) {
            this.readerPageIndex = position.anchor.sourceIndexHint
            this.continuationObservedPage = {
              comicId: position.anchor.unit.work, chapterId: position.anchor.unit.unit, pageIndex: position.anchor.sourceIndexHint,
            }
            this.syncReaderContinuationState()
          }
        },
        flushObserved: (): void => { if (this.readerSessionPersistenceReady) this.readerSessionStore.flush() },
        observeReadingPages: (work: string, chapter: string, pages: number[]): void => {
          this.observeReadingPages(work, chapter, pages)
        },
        onOpenMangaDetail: (_work: string): void => { this.openReaderMangaDetail() },
        onRouteVisibleChange: (visible: boolean): void => {
          this.readerRouteVisible = visible
          if (!visible) {
            this.readerRouteTransition.cancel()
            this.publishDeferredReaderBackgroundPresentation()
          }
        },
        onRouteDisappear: (): void => { this.finishReaderRouteClose() },
        onClose: (): void => { this.popReaderRouteAfterSystemBarRestore() },
      })
  }

  @Builder
  private SourceBrowseDestination(param: SourceBrowseRouteParam) {
    HdsNavDestination() {
      SourceBrowsePage({
        libraryStore: this.libraryStore, libraryRevision: this.libraryRevision,
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
    .onHidden((reason: VisibilityChangeReason) => {
      param.chrome.hide(reason === VisibilityChangeReason.CONTENT_COVER)
      this.sourceBrowseMenu.close()
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
  private SourceRelatedDestination(param: SourceRelatedRouteParam) {
    HdsNavDestination() {
      SourceMangaGrid({ contentItemCount: param.manga.length }) {
        ForEach(param.manga, (manga: SourceManga) => {
          GridItem() {
            MangaGridItem({ manga,
              onMangaTap: (item: SourceManga): void => {
                RouterHelper.pushMangaDetail({ mangaId: item.id, sourceId: item.sourceId, initialManga: item }, true)
              },
            })
          }
          .padding({ bottom: ThemeConstants.SPACE_LG })
          .clip(false)
        }, (manga: SourceManga): string => manga.id)
      }
    }
    .titleBar(this.navDestTitleBarOpts(AppStrings.get('manga_detail_related')))
  }

  @Builder
  private SourceSearchDestination(param: SourceSearchRouteParam) {
    HdsNavDestination() {
      SourceSearchPage({
        libraryStore: this.libraryStore, libraryRevision: this.libraryRevision,
        source: param.source,
        chrome: param.chrome,
        selectionMode: param.onMangaSelected !== undefined,
        onMangaTap: (manga: SourceManga) => {
          RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
        },
        onMangaSelected: (manga: SourceManga) => {
          if (param.onMangaSelected !== undefined) {
            const onSelected = param.onMangaSelected
            this.appPathStack.pop(false)
            onSelected(manga)
          } else {
            RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
          }
        },
      })
    }
    .onShown(() => { param.chrome.resume() })
    .onHidden((reason: VisibilityChangeReason) => { param.chrome.hide(reason === VisibilityChangeReason.CONTENT_COVER) })
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
        initialLibrarySource: param.librarySource,
        initialSourceFilter: param.sourceFilter,
        onOpenLibraryResult: (comicId: string) => { this.openLibraryMangaDetail(comicId) },
        libraryStore: this.libraryStore,
        libraryRevision: this.libraryRevision,
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

  private closeMigrationSearch(param: MangaMigrationSearchRouteParam): boolean {
    const top = this.appPathStack.getAllPathName().length - 1
    if (top < 0 || this.appPathStack.getParamByIndex(top) !== param) return false
    this.appPathStack.pop()
    return true
  }

  @Builder
  private MigrationSearchDestination(param: MangaMigrationSearchRouteParam) {
    HdsNavDestination() {
      SearchPage({ chrome: param.chrome, migrationSources: param.sourceIds,
        onMigrationShelfResults: param.onShelfResults,
        automaticallyOpenWebChallenge: !param.fromMihon,
        libraryStore: this.libraryStore, libraryRevision: this.libraryRevision,
        libraryPersistenceService: this.ensureLibraryPersistenceService(),
        onMangaSelected: (manga: SourceManga): void => {
          if (this.closeMigrationSearch(param)) param.onMangaSelected(manga)
        },
      })
    }
    .titleBar(this.migrationSearchTitleBarOpts(param.chrome, param.fromMihon, true, (): void => {
      if (this.closeMigrationSearch(param)) param.onChooseSources()
    }))
    .onShown((): void => { param.chrome.visible = true })
    .onHidden((): void => { param.chrome.visible = false })
    .onDisAppear((): void => { this.disposeSearchFieldContent(param.chrome) })
  }

  @Builder
  private AppDestination(name: string, param: Object) {
    if (name === SETTINGS_MODAL_ROUTE) {
      HdsNavDestination() {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)
          .bindSheet($$this.settingsModalShown, this.SettingsModal, this.settingsModalOptions())
      }
      .mode(NavDestinationMode.DIALOG)
      .hideTitleBar(true)
      .backgroundColor(Color.Transparent)
      .onShown((): void => { this.settingsModalShown = true })
    } else if (name === 'ReaderLab') {
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
        Stack() {
          Column() {}.width('100%').height('100%').backgroundColor(ThemeConstants.BG_SUB)
          if (this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand() && this.detailTransition.cardSnapshot !== undefined) {
            Image(this.detailTransition.cardSnapshot)
              .width('100%').height('100%').objectFit(ImageFit.Fill).syncLoad(true)
              .opacity(this.detailTransition.cardOpacity).hitTestBehavior(HitTestMode.None)
              .transition(TransitionEffect.IDENTITY)
          }
          MangaDetailPage({
            params: param as MangaDetailRouteParam,
          transitionCoverId: this.ownsDetailTransition(param as MangaDetailRouteParam) && this.detailTransition.isCoverExpand()
            ? this.detailTransition.targetCoverComponentId : '',
            libraryStore: this.libraryStore,
            libraryRevision: this.libraryRevision,
            libraryPersistenceService: this.ensureLibraryPersistenceService(),
            readerSessionStore: this.readerSessionStore,
            readerProgressRevision: this.readerProgressRevision,
            onReadingStateChanged: (comicId: string) => { this.queueReadingPresentation([comicId]) },
            sourceRegistry: this.sourceRegistry,
            chrome: RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam),
            onBack: () => {
              this.popMangaDetail(param as MangaDetailRouteParam)
            },
            onOpenReader: (mangaId: string, chapterId: string, intent: ReaderChapterOpenIntent) => {
              void this.openReader(mangaId, chapterId, intent)
            },
            onOpenSourceReader: (request: SourceReaderSessionRequest, intent: ReaderChapterOpenIntent) => {
              const importedId = (param as MangaDetailRouteParam).mihonImportId
              const imported = importedId === undefined ? undefined : this.libraryStore.getMihonImportWork(importedId)
              if (imported !== undefined && !imported.targetComicId) void this.openMihonImportedWork(imported.id)
              else void this.openSourceReader(request, intent)
            },
            onMihonCatalogReady: async (snapshot: SourceMangaDetailSnapshot, fingerprint: string,
              isCurrent: () => boolean): Promise<boolean> => {
              const importedId = (param as MangaDetailRouteParam).mihonImportId
              if (importedId === undefined) return false
              try {
                const service = new MihonImportService(getContext(this) as common.UIAbilityContext, this.libraryStore)
                if (!await service.linkOpenedCatalog(importedId, snapshot, fingerprint, isCurrent)) return false
                // The detail reads the committed live stores. Reproject the
                // covered shelf and history when the root becomes visible.
                this.libraryPresentationPending = true
                this.queueReadingPresentation()
                if (this.rootNavigation.visible) this.publishDeferredReaderBackgroundPresentation()
                return true
              } catch (error) {
                DiagnosticLogger.exception('backup', 'mihon_detail_restore_failed', error as Error)
                if (isCurrent()) this.showToast(AppStrings.get('mihon_import_resume_failed'))
                return false
              }
            },
            onOpenImportRequested: () => { this.openImport() },
            onRefreshLocalFolder: (comicId: string) => this.rescanLocalLibraryFolders(comicId),
            onLibraryChanged: () => { this.onMangaDetailLibraryChanged() },
            onOpenExistingFavorite: (comicId: string): void => { this.openLibraryMangaDetail(comicId, true) },
            onMigrationRequested: (comicId: string) => {
              const imported = this.libraryStore.getMihonImportWork(comicId)
              void this.openMangaMigration([comicId], true, imported !== undefined && !imported.targetComicId)
            }
          })
          .opacity(this.ownsDetailTransition(param as MangaDetailRouteParam) ? this.detailTransition.contentOpacity : 1)
        }.width('100%').height('100%')
      }
      .titleBar(this.mangaDetailTitleBarOpts(param as MangaDetailRouteParam))
      .hideTitleBar(this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.chromeVisible, false)
      .backgroundColor(this.ownsDetailTransition(param as MangaDetailRouteParam) ? Color.Transparent : ThemeConstants.BG_SUB)
      .scale({ x: this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand() ? this.detailTransition.scaleX : 1,
        y: this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand() ? this.detailTransition.scaleY : 1,
        centerX: '50%', centerY: '50%' })
      .translate({ x: this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand() ? this.detailTransition.translateX : 0,
        y: this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand() ? this.detailTransition.translateY : 0 })
      .borderRadius(this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand() ? this.detailTransition.radius : 0)
      .clip(this.ownsDetailTransition(param as MangaDetailRouteParam) && !this.detailTransition.isCoverExpand())
      .bindToScrollable(this.mangaDetailScrollers(param as MangaDetailRouteParam))
      .onBackPressed((): boolean => {
        const selection = RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam).chapterPresentation
        if (selection.selectionMode) { selection.setSelectionMode(false); return true }
        return MangaDetailTransitionCoordinator.preparePop(this.getUIContext(),
          (param as MangaDetailRouteParam).transitionToken, (): void => { this.appPathStack.pop() })
      })
      .onShown(() => {
        RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam).visible = true
      })
      .onHidden(() => {
        RouterHelper.ensureMangaDetailRouteChrome(param as MangaDetailRouteParam).visible = false
        this.detailMenu.close()
      })
    } else if (name === RouteName.MANGA_MIGRATION) {
      HdsNavDestination() {
        MangaMigrationPage({
          comicIds: (param as MangaMigrationRouteParam).comicIds,
          fromMihon: (param as MangaMigrationRouteParam).fromMihon === true,
          initialSources: (param as MangaMigrationRouteParam).selectedSources ?? [],
          initialMatchOptions: (param as MangaMigrationRouteParam).matchOptions ?? { deepSearch: false, prioritizeChapters: false },
          chrome: RouterHelper.ensureMigrationRouteChrome(param as MangaMigrationRouteParam),
          registry: this.sourceRegistry, libraryStore: this.libraryStore,
          persistence: this.ensureLibraryPersistenceService(), readerStore: this.readerSessionStore,
          onBusyChanged: (busy: boolean): void => { (param as MangaMigrationRouteParam).committing = busy },
          onOpenSearch: (search: MangaMigrationSearchRouteParam): void => {
            const top = this.appPathStack.getAllPathName().length - 1
            if (top >= 0 && this.appPathStack.getParamByIndex(top) === param) {
              this.appPathStack.pushPath({ name: RouteName.MANGA_MIGRATION_SEARCH, param: search },
                { launchMode: LaunchMode.NEW_INSTANCE })
            }
          },
          onLibraryChanged: (): void => {
            this.onMangaDetailLibraryChanged()
            this.readerProgressRevision += 1
          },
          onComplete: (ids: string[]): void => {
            const route = param as MangaMigrationRouteParam
            const fromDetail = route.fromDetail === true
            DiagnosticLogger.info('manga_migration', 'return', `fromDetail=${fromDetail} targets=${ids.length}`)
            if (route.fromMihon && ids.length === 1 && route.comicIds.length === 1) {
              // The reader's entrance needs the root page to be visible after
              // the migration route is dismissed.
              const resumeFromRoot = !fromDetail && this.appPathStack.getAllPathName().length === 1
              if (resumeFromRoot) this.pendingMihonResume = route.comicIds[0]
              this.appPathStack.pop(false)
              if (fromDetail) this.appPathStack.pop(false)
              if (!resumeFromRoot) void this.openMihonImportedWork(route.comicIds[0], false)
              return
            }
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
      .titleBar(this.migrationTitleBarOpts(param as MangaMigrationRouteParam))
      .onShown((): void => {
        const chrome = RouterHelper.ensureMigrationRouteChrome(param as MangaMigrationRouteParam)
        chrome.visible = true
      })
      .onHidden((): void => { RouterHelper.ensureMigrationRouteChrome(param as MangaMigrationRouteParam).visible = false })
      .onDisAppear((): void => {
        this.disposeSearchFieldContent(RouterHelper.ensureMigrationRouteChrome(param as MangaMigrationRouteParam).search)
      })
      .onBackPressed((): boolean => RouterHelper.ensureMigrationRouteChrome(param as MangaMigrationRouteParam).busy)
    } else if (name === RouteName.MANGA_MIGRATION_SEARCH) {
      this.MigrationSearchDestination(param as MangaMigrationSearchRouteParam)
    } else if (name === RouteName.SOURCE_BROWSE) {
      this.SourceBrowseDestination(param as SourceBrowseRouteParam)
    } else if (name === RouteName.SOURCE_SEARCH) {
      this.SourceSearchDestination(param as SourceSearchRouteParam)
    } else if (name === RouteName.SOURCE_RELATED) {
      this.SourceRelatedDestination(param as SourceRelatedRouteParam)
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
    } else if (name === RouteName.LIBRARY_UPDATES) {
      HdsNavDestination() {
        LibraryUpdatesPage({ chrome: param as LibraryUpdatesChrome,
          libraryStore: this.libraryStore, libraryRevision: this.libraryRevision,
          refreshController: this.libraryUpdatesRefreshController,
          readerSessionStore: this.readerSessionStore, readerProgressRevision: this.readerProgressRevision,
          onOpenReader: (comicId: string, chapterId: string): void => { void this.openReader(comicId, chapterId) },
          onOpenComic: (comicId: string): void => { this.openLibraryMangaDetail(comicId) },
          onReadingStateChanged: (comicIds: string[]): void => { this.refreshReadingPresentation(comicIds) },
          onRefresh: async (): Promise<void> => { await this.checkLibraryUpdatesNow() } })
      }
      .titleBar(this.libraryUpdatesTitleBarOptions(param as LibraryUpdatesChrome))
      .onBackPressed((): boolean => {
        const chrome = param as LibraryUpdatesChrome
        if (!chrome.selecting) return false
        if (!chrome.busy) chrome.exitSelection()
        return true
      })
      .onShown((): void => { this.markLibraryUpdatesSeen() })
    } else if (name === RouteName.LIBRARY_CATEGORIES) {
      HdsNavDestination() {
        LibraryCategoryManagementPage({
          chrome: param as LibraryCategoryManagementChrome,
          libraryStore: this.libraryStore,
          libraryRevision: this.libraryRevision,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          }
        })
      }
      .titleBar(this.libraryCategoryTitleBarOptions(param as LibraryCategoryManagementChrome))
    } else if (name === RouteName.DOWNLOADS) {
      HdsNavDestination() {
        DownloadsPage({ chrome: param as DownloadsChrome, libraryStore: this.libraryStore,
          onOpenReader: (comicId: ComicId, chapterId: string, validation?: OfflineDownloadManifestValidation): void => {
            void this.openDownloadedChapter(comicId, chapterId, validation)
          } })
      }
      .titleBar(this.downloadsTitleBarOptions(param as DownloadsChrome))
      .onHidden((): void => { this.downloadsMenu.close() })
      .onBackPressed((): boolean => {
        const chrome = param as DownloadsChrome
        if (!chrome.selecting) return false
        chrome.request('exitSelection')
        return true
      })
    } else if (name === RouteName.READING_STATISTICS) {
      HdsNavDestination() {
        ReadingStatisticsPage({ libraryStore: this.libraryStore, sessionStore: this.readerSessionStore })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('reading_statistics_title')))
    } else {
      this.SettingsDestination(name, param, this.appPathStack)
    }
  }

  private settingsModalOffset(name: string, param?: Object): string {
    const motion = this.settingsModalMotion
    if (motion !== undefined) {
      const direction: number = motion.pushing ? 1 : -1
      if (motion.from.name === name && motion.from.param === param) {
        return `${-direction * this.settingsModalProgress * 100}%`
      }
      if (motion.to.name === name && motion.to.param === param) {
        return `${direction * (1 - this.settingsModalProgress) * 100}%`
      }
    }
    // Navigation may reveal a cached parent before the pop's reactive updates are painted.
    // Park every covered destination at the left edge even between transitions.
    return this.settingsModalTop?.name === name && this.settingsModalTop.param === param ? '0%' : '-100%'
  }

  private settingsModalTransition(from: NavContentInfo, to: NavContentInfo): NavigationAnimatedTransition | undefined {
    if (from.index < 0 || to.index < 0) return undefined
    const motion = this.settingsModalMotion
    if (motion === undefined) return undefined
    const ui = this.getUIContext()
    return {
      transition: (proxy: NavigationTransitionProxy): void => {
        // Let the incoming destination lay out at the viewport edge before
        // animating both pages through adjacent, non-overlapping positions.
        ui.postFrameCallback(new SettingsModalLayoutFrame((): void => {
          if (this.settingsModalMotion !== motion) {
            proxy.finishTransition()
            return
          }
          ui.animateTo({ duration: 300, curve: Curve.FastOutSlowIn,
            onFinish: (): void => { proxy.finishTransition() } },
            (): void => { this.settingsModalProgress = 1 })
        }))
      },
      onTransitionEnd: (): void => {
        if (this.settingsModalMotion === motion) {
          const paths = this.settingsModalStack.getAllPathName()
          const top = paths.length - 1
          this.settingsModalTop = top < 0 ? undefined :
            { name: paths[top], param: this.settingsModalStack.getParamByIndex(top) }
          this.settingsModalMotion = undefined
        }
      },
    }
  }

  private settingsDestinationTitleMode(inModal: boolean): HdsNavDestinationTitleMode {
    // HDS reserves the same top inset on every sheet route, including the native back button.
    return inModal ? HdsNavDestinationTitleMode.MODAL : HdsNavDestinationTitleMode.MINI
  }

  private settingsDestinationTitleOptions(inModal: boolean, options: Record<string, Object>): Record<string, Object> {
    if (inModal) {
      options['avoidLayoutSafeArea'] = false
      options['enableComponentSafeArea'] = true
    }
    return options
  }

  @Builder
  private ModalSettingsDestination(name: string, param: Object) {
    if (name === SETTINGS_MODAL_HOME) {
      this.SettingsModalHome(param as SettingsModalDestination)
    } else {
      this.SettingsDestination(name, param, this.settingsModalStack, true)
    }
  }

  @Builder
  private SettingsDestination(name: string, param: Object, stack: NavPathStack, inModal: boolean = false) {
    if (name === RouteName.KOMGA_SERVER) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          KomgaServerPage({ inModal: inModal })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('route_komga_title'))))
    } else if (name === RouteName.KAVITA_SERVER) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          KavitaServerPage({ inModal: inModal })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('route_kavita_title'))))
    } else if (name === RouteName.OPDS_SERVER) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          OpdsServerPage({ inModal: inModal })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('route_opds_title'))))
    } else if (name === RouteName.WEBDAV_SERVER) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          WebDavServerPage({ inModal: inModal })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('route_webdav_title'))))
    } else if (name === RouteName.SOURCE_PACKAGE_MANAGER) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          SourcePackageManagerPage({
            inModal: inModal,
            onOpenSubscriptions: (): void => {
              stack.pushPath({ name: RouteName.SOURCE_SUBSCRIPTIONS, param: new SourceCatalogPageChrome() })
            },
            onCloseSettingsRoute: (): void => { stack.pop() },
            onOpenSourceCatalog: (action: () => void): void => { this.leaveSettingsModalFor(action, inModal) },
            chrome: this.sourceManagerChrome(param as SourcePackageManagerRouteParam | undefined),
            initialSettingsSourceId: (param as SourcePackageManagerRouteParam | undefined)?.settingsSourceId ?? '',
            recoverySourceId: (param as SourcePackageManagerRouteParam | undefined)?.recoverySourceId ?? '',
            recoverySourceName: (param as SourcePackageManagerRouteParam | undefined)?.recoverySourceName ?? '',
            onSettingsSaved: () => { (param as SourcePackageManagerRouteParam | undefined)?.onSettingsSaved?.() },
            onBeforeRemove: (sourceId: string, sourceName: string): void => {
              const persistence = this.ensureLibraryPersistenceService()
              if (persistence === undefined) throw new Error('library_persistence_unavailable')
              if (retainLibrarySourceNameAndPersist(this.libraryStore, persistence, sourceId, sourceName)) {
                this.refreshLibrarySnapshot()
              }
            },
          })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.sourceManagerTitleBarOptions(param as SourcePackageManagerRouteParam | undefined, stack)))
      .dynamicHideTitleBar({
        hideTitleArea: this.sourceManagerChrome(param as SourcePackageManagerRouteParam | undefined).searchExpanded,
        hideBottomBuilder: false,
        hideStatusBar: false,
        mode: HideMode.SCROLL_UP,
      })
      .bindToScrollable([this.sourceManagerChrome(param as SourcePackageManagerRouteParam | undefined).scroller])
      .onBackPressed((): boolean => {
        const chrome = this.sourceManagerChrome(param as SourcePackageManagerRouteParam | undefined)
        if (!chrome.searchExpanded) return false
        this.toggleManagerCatalogSearch(chrome)
        return true
      })
      .onDisAppear((): void => {
        const chrome = this.sourceManagerChrome(param as SourcePackageManagerRouteParam | undefined)
        this.disposeSourceManagerSection(chrome)
        this.disposeCatalogSearch(chrome)
      })
    } else if (name === RouteName.SOURCE_SUBSCRIPTIONS) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          SourceSubscriptionsPage({ chrome: param as SourceCatalogPageChrome, embedded: inModal })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.sourceSubscriptionsTitleBarOptions(param as SourceCatalogPageChrome)))
    } else if (name === RouteName.IMAGE_PLUGINS) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
            ImagePluginsPage({ request: param as ImagePluginsRequest, embedded: inModal })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.imagePluginsTitleBarOptions(stack)))
    } else if (name === RouteName.SETTINGS_PANE) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          this.SettingsPaneContent(param as SettingsPaneRouteParam, new Scroller(), inModal, stack)
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.settingsPaneTitleBarOpts(param as SettingsPaneRouteParam)))
    } else if (name === RouteName.BACKUP_MANAGEMENT) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          this.BackupSettingsContent(param as BackupManagementRouteParam, inModal)
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('route_backup_management_title'))))
      .bindToScrollable([(param as BackupManagementRouteParam).scroller])
      .onBackPressed(() => BackupRestoreActivity.isRestoring())
    } else if (name === RouteName.DEVICE_SYNC) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          DeviceSyncOverviewPage({ inModal: inModal, scroller: (param as DeviceSyncWebDavRouteParam).chrome.scroller,
            onOpenWebDav: (): void => { this.openDeviceSyncWebDav(stack) },
            onOpenHuaweiCloud: (): void => { this.openDeviceSyncHuaweiCloud(stack) } })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('device_sync_title'))))
      .bindToScrollable([(param as DeviceSyncWebDavRouteParam).chrome.scroller])
    } else if (name === RouteName.DEVICE_SYNC_HUAWEI) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          DeviceSyncHuaweiCloudPage({ inModal: inModal, scroller: (param as DeviceSyncWebDavRouteParam).chrome.scroller })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(AppStrings.get('device_sync_cloud_title'))))
      .bindToScrollable([(param as DeviceSyncWebDavRouteParam).chrome.scroller])
    } else if (name === RouteName.DEVICE_SYNC_WEBDAV) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          this.DeviceSyncWebDavContent(param as DeviceSyncWebDavRouteParam, stack, inModal)
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.deviceSyncWebDavTitleBarOpts()))
      .bindToScrollable([(param as DeviceSyncWebDavRouteParam).chrome.scroller])
      .onShown((): void => {
        (param as DeviceSyncWebDavRouteParam).chrome.shownSeq++
      })
    } else if (name === RouteName.DEVICE_SYNC_CONNECTION) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          DeviceSyncConnectionPage({ inModal: inModal, chrome: (param as DeviceSyncConnectionRouteParam).chrome,
            titleAction: (param as DeviceSyncConnectionRouteParam).chrome.confirm,
            onSaved: (): void => { stack.pop() } })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.deviceSyncActionTitleBarOpts((param as DeviceSyncConnectionRouteParam).chrome,
        (param as DeviceSyncConnectionRouteParam).titleKey, 'common_save')))
      .bindToScrollable([(param as DeviceSyncConnectionRouteParam).chrome.scroller])
      .onBackPressed((): boolean => (param as DeviceSyncConnectionRouteParam).chrome.busy)
    } else if (name === RouteName.DEVICE_SYNC_REVIEW) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          DeviceSyncReviewPage({ inModal: inModal, chrome: (param as DeviceSyncReviewRouteParam).chrome,
            titleAction: (param as DeviceSyncReviewRouteParam).chrome.confirm,
            selected: (param as DeviceSyncReviewRouteParam).groups, reason: (param as DeviceSyncReviewRouteParam).reason,
            onCompleted: (): void => { stack.pop() } })
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.deviceSyncActionTitleBarOpts((param as DeviceSyncReviewRouteParam).chrome,
        this.deviceSyncReviewTitle((param as DeviceSyncReviewRouteParam).reason), 'device_sync_confirm_merge')))
      .bindToScrollable([(param as DeviceSyncReviewRouteParam).chrome.scroller])
      .onBackPressed((): boolean => (param as DeviceSyncReviewRouteParam).chrome.busy)

    } else if (name === RouteName.TRACKER_SETTINGS) {
      HdsNavDestination() {
        KomaModalContent({ useInset: inModal }) {
          this.TrackerSettingsContent(param as SettingsSearchRouteParam, new Scroller(), inModal)
        }
      }
      .backgroundColor(inModal ? Color.Transparent : undefined)
      .translate({ x: inModal ? this.settingsModalOffset(name, param) : '0%' })
      .titleMode(this.settingsDestinationTitleMode(inModal))
      .titleBar(this.settingsDestinationTitleOptions(inModal, this.navDestTitleBarOpts(settingsPaneTitle('tracking'))))
      .onShown(() => {
        this.trackerSettingsRevision += 1
      })
    }
  }

  @Builder
  private DeviceSyncWebDavContent(param: DeviceSyncWebDavRouteParam, stack: NavPathStack, inModal: boolean) {
    DeviceSyncWebDavPage({ inModal: inModal, chrome: param.chrome,
      onEditConnection: (): void => { this.openDeviceSyncConnection(stack) },
      onReview: (groups: SyncGroup[], reason: DeviceSyncReviewReason): void => {
        this.openDeviceSyncReview(groups, reason, stack)
      } })
  }

  @Builder
  private SettingsPaneContent(param: SettingsPaneRouteParam, scroller: Scroller = new Scroller(),
    inModal: boolean = false, stack: NavPathStack = this.appPathStack) {
    SettingsPage({
      enhancementModelsRevision: this.enhancementModelsRevision,
      onEnhancementModelsChanged: () => { this.enhancementModelsRevision += 1 },
      preferencesRestoreRevision: this.applicationSettingsRestoreRevision,
      pane: this.settingsPaneFromParam(param),
      inModal: inModal,
      scroller: scroller,
      searchTarget: param.searchTarget ?? '',
      formTitleAction: param.formTitleAction,
      modelSourcesTitleAction: param.modelSourcesTitleAction,
      onClosePane: () => {
        if (inModal && stack.size() === 1) this.settingsModalShown = false
        else stack.pop()
      },
      onLibraryPreferencesChanged: () => { this.libraryPreferencesRevision += 1 },
      libraryStore: this.libraryStore,
      libraryPersistenceService: this.ensureLibraryPersistenceService(),
      sourceRegistry: this.sourceRegistry,
      onOpenSettingsPane: (nextPane: SettingsPaneKey, rowKey?: string) => {
        this.openSettingsPane(nextPane, rowKey, false, stack)
      },
      onOpenKomgaSettings: () => {
        this.openSettingsSecondary(RouteName.KOMGA_SERVER, stack)
      },
      onOpenKavitaSettings: () => {
        this.openSettingsSecondary(RouteName.KAVITA_SERVER, stack)
      },
      onOpenOpdsSettings: () => {
        this.openSettingsSecondary(RouteName.OPDS_SERVER, stack)
      },
      onOpenWebDavSettings: () => {
        this.openSettingsSecondary(RouteName.WEBDAV_SERVER, stack)
      },
      onOpenImagePlugins: (request: ImagePluginsRequest): void => { stack.pushPath({ name: RouteName.IMAGE_PLUGINS, param: request }) },
      onOpenSourcePackageManager: () => {
        this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER, stack)
      },
      onOpenDownloads: () => {
        this.openSettingsSecondary(RouteName.DOWNLOADS, stack)
      },
      onOpenImportRequested: () => {
        this.leaveSettingsModalFor((): void => { this.openImport() }, inModal)
      },
      onRefreshLocalFolders: () => this.rescanLocalLibraryFolders(),
      onLibraryChanged: () => {
        this.refreshLibrarySnapshot()
      }
    })
  }

  @Builder
  private BackupSettingsContent(param: BackupManagementRouteParam, inModal: boolean = false) {
    BackupManagementPage({ refreshRevision: this.backupSettingsRevision, searchTarget: param.searchTarget,
      backupScroller: param.scroller, inModal: inModal, libraryStore: this.libraryStore,
      onMihonImported: (): void => { this.onMihonImported() },
      onOpenDeviceSync: (): void => { this.openDeviceSyncOverview(inModal ? this.settingsModalStack : this.appPathStack) },
      onRestoreCompleted: () => { this.onBackupRestored() } })
  }

  @Builder
  private TrackerSettingsContent(param: SettingsSearchRouteParam, scroller: Scroller = new Scroller(),
    inModal: boolean = false) {
    TrackerSettingsPage({ refreshRevision: this.trackerSettingsRevision, settingsScroller: scroller, inModal: inModal,
      searchTarget: param?.searchTarget ?? '', preferencesRestoreRevision: this.applicationSettingsRestoreRevision })
  }

  private settingsModalTitle(destination: SettingsModalDestination): string {
    if (destination.name === RouteName.BACKUP_MANAGEMENT) return AppStrings.get('route_backup_management_title')
    if (destination.name === RouteName.TRACKER_SETTINGS) return settingsPaneTitle('tracking')
    if (destination.name === RouteName.DEVICE_SYNC) return AppStrings.get('device_sync_title')
    if (destination.name === RouteName.DEVICE_SYNC_WEBDAV) return AppStrings.get('device_sync_webdav')
    if (destination.name === RouteName.DEVICE_SYNC_HUAWEI) return AppStrings.get('device_sync_cloud_title')
    return settingsPaneTitle(this.settingsPaneFromParam(destination.param))
  }

  private settingsModalActions(destination: SettingsModalDestination): HdsNavigationMenuItemOptions[] {
    let actions: HdsNavigationMenuItemOptions[] = []
    if (destination.name === RouteName.SETTINGS_PANE) {
      actions = this.settingsPaneTitleActions(destination.param as SettingsPaneRouteParam)
    }
    // HDS reserves the final slot for overflow. Keep Close on the title bar.
    actions.splice(actions.length > 2 ? 1 : actions.length, 0, komaModalCloseAction((): void => {
      if (this.canDismissSettingsModal()) this.settingsModalShown = false
    }))
    return actions
  }

  @Builder
  private SettingsModalHome(destination: SettingsModalDestination) {
    HdsNavDestination() {
      KomaModalContent() {
        if (destination.name === RouteName.BACKUP_MANAGEMENT) {
          this.BackupSettingsContent(destination.param as BackupManagementRouteParam, true)
        } else if (destination.name === RouteName.TRACKER_SETTINGS) {
          this.TrackerSettingsContent(destination.param as SettingsSearchRouteParam, destination.scroller, true)
        } else if (destination.name === RouteName.DEVICE_SYNC) {
          DeviceSyncOverviewPage({ inModal: true, scroller: destination.scroller,
            onOpenWebDav: (): void => { this.openDeviceSyncWebDav(this.settingsModalStack) },
            onOpenHuaweiCloud: (): void => { this.openDeviceSyncHuaweiCloud(this.settingsModalStack) } })
        } else if (destination.name === RouteName.DEVICE_SYNC_WEBDAV) {
          this.DeviceSyncWebDavContent(destination.param as DeviceSyncWebDavRouteParam, this.settingsModalStack, true)
        } else if (destination.name === RouteName.DEVICE_SYNC_HUAWEI) {
          DeviceSyncHuaweiCloudPage({ inModal: true, scroller: destination.scroller })
        } else {
          this.SettingsPaneContent(destination.param as SettingsPaneRouteParam, destination.scroller, true,
            this.settingsModalStack)
        }
      }
    }
    .titleBar(komaModalTitleBarOptions(this.settingsModalTitle(destination), this.settingsModalActions(destination)))
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .hideBackButton(true)
    .bindToScrollable([destination.scroller])
    .backgroundColor(Color.Transparent)
    .translate({ x: this.settingsModalOffset(SETTINGS_MODAL_HOME, destination) })
    .onBackPressed((): boolean => !this.canDismissSettingsModal())
  }

  @Builder
  private SettingsModalContent() {
    KomaModalScaffold({ contentOwnsNavigation: true }) {
      Column() {
        HdsNavigation(this.settingsModalStack) {}
          .hideNavBar(true)
          .navDestination(this.ModalSettingsDestination)
          .customNavContentTransition((from: NavContentInfo, to: NavContentInfo): NavigationAnimatedTransition | undefined =>
            this.settingsModalTransition(from, to))
          .mode(NavigationMode.Stack)
          .expandSafeArea([], [])
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')
    }
  }

  private backWithinSettingsModal(): void {
    const paths = this.settingsModalStack.getAllPathName()
    const name = paths[paths.length - 1]
    const param = this.settingsModalStack.getParamByIndex(paths.length - 1) as Object | undefined
    if (name === RouteName.SOURCE_PACKAGE_MANAGER) {
      const chrome = this.sourceManagerChrome(param as SourcePackageManagerRouteParam | undefined)
      if (chrome.searchExpanded) {
        this.toggleManagerCatalogSearch(chrome)
        return
      }
    }
    if (name === RouteName.BACKUP_MANAGEMENT && BackupRestoreActivity.isRestoring()) return
    if ((name === RouteName.DEVICE_SYNC_CONNECTION || name === RouteName.DEVICE_SYNC_REVIEW) &&
      (param as DeviceSyncWebDavRouteParam).chrome.busy) return
    this.settingsModalStack.pop()
  }

  private leaveSettingsModalFor(action: () => void, inModal: boolean): void {
    if (inModal) {
      this.afterSettingsModalDismiss = action
      this.settingsModalShown = false
    } else {
      action()
    }
  }

  private settingsModalOptions(): SheetOptions {
    // The platform chooses the sheet's presentation. Settings destinations
    // share its native Navigation stack and the same content transition.
    return komaSheetOptions({
      onDisappear: (): void => {
        this.settingsModalDestination = undefined
        this.settingsModalStack = new NavPathStack()
        this.settingsModalTop = undefined
        this.settingsModalMotion = undefined
        const paths = this.appPathStack.getAllPathName()
        if (paths[paths.length - 1] === SETTINGS_MODAL_ROUTE) this.appPathStack.pop(false)
        const action = this.afterSettingsModalDismiss
        this.afterSettingsModalDismiss = undefined
        action?.()
      },
    }, (reason: DismissReason): boolean => this.shouldDismissSettingsModal(reason))
  }

  @Builder
  private SettingsModal() {
    if (this.settingsModalDestination !== undefined) {
      this.SettingsModalContent()
    }
  }

  @Monitor('selectedTab', 'appForegroundState.revision', 'appearanceState.doubleBackToExit')
  private resetRootBackConfirmation(): void {
    this.lastRootBackAt = undefined
  }

  onBackPress(): boolean {
    const previousRootBackAt = this.lastRootBackAt
    this.lastRootBackAt = undefined
    if (this.readerOpen && this.isReaderRouteVisible()) {
      this.closeReader()
      return true
    }
    if (this.appPathStack.getAllPathName().length > 0) return false
    if (this.selectedTab === TabIndex.BROWSE && this.browseCatalogChrome.searchExpanded) {
      this.setCatalogSearch(this.browseCatalogChrome, false)
      return true
    }
    if (this.selectedTab === TabIndex.LIBRARY && this.libraryTitleBar.selectionMode) {
      this.libraryTitleBar.cancelSelection()
      return true
    }
    if (!this.appearanceState.doubleBackToExit) return false

    // NextE uses a one-second confirmation at the root. Child navigation and
    // transient modes handle Back first. Let the system handle the confirmed exit.
    const now = Date.now()
    if (previousRootBackAt !== undefined && now >= previousRootBackAt &&
      now - previousRootBackAt < ROOT_BACK_CONFIRMATION_MS) return false
    this.lastRootBackAt = now
    this.showToast(AppStrings.get('navigation_back_guard_toast'))
    return true
  }

  private showPrivateRouteLock(): boolean {
    if ((this.isReaderRouteVisible() || this.isReaderDetailRouteVisible()) &&
      this.privateContinuationSession(this.readerSessionConfig.comicId) &&
      !this.libraryPrivacy.visibleContinuation(this.readerSessionConfig.comicId)) return true
    const scope = this.libraryPrivacy.categoryId
    if (scope.length === 0 || this.libraryPrivacy.visibleCategoryId === scope || this.rootNavigation.visible) return false
    const paths = this.appPathStack.getAllPathName()
    const destination = paths[paths.length - 1]
    if (destination === RouteName.READER) return !this.canOpenLibraryComic(this.readerSessionConfig.comicId)
    if (destination !== RouteName.MANGA_DETAIL) return false
    const detail = this.appPathStack.getParamByIndex(paths.length - 1) as MangaDetailRouteParam | undefined
    if (detail === undefined) return false
    const sourceId = detail.sourceId?.trim() ?? ''
    const comic = sourceId.length > 0 ? this.libraryStore.findBySourceManga(sourceId, detail.mangaId) :
      this.libraryStore.getComic(detail.mangaId)
    return !showLibraryComic(comic, this.privateCategoryIds)
  }

  @Monitor('libraryPrivacy.foregroundReauthRevision', 'libraryPrivacy.presenting')
  private offerAutomaticShelfReauth(): void {
    const revision = this.libraryPrivacy.foregroundReauthRevision
    if (!this.libraryPrivacy.presenting || this.handledForegroundReauthRevision === revision) return
    // Consume the foreground request once, even if the user came back to a
    // different tab or dismisses the system authentication.
    this.handledForegroundReauthRevision = revision
    if (this.libraryPrivacy.categoryId.length > 0 && this.isShelfForeground()) {
      void this.unlockPrivateCategory((): boolean => this.isShelfForeground())
    }
  }

  private isShelfForeground(): boolean {
    return this.rootNavigation.visible && this.selectedTab === TabIndex.LIBRARY
  }

  private async unlockPrivateCategory(isCurrent: () => boolean): Promise<void> {
    const category = this.libraryPrivacy.categoryId
    const result = await this.libraryPrivacy.openCategory(this.getUIContext().getHostContext() as common.UIAbilityContext,
      category, (): boolean => isCurrent() && this.libraryPrivacy.categoryId === category &&
        this.privateCategoryIds.has(category))
    const message = libraryPrivacyAuthMessage(result)
    if (result !== LibraryPrivacyAuthResult.SUCCESS && message.length > 0) this.showToast(message)
  }

  @Builder
  private PrivateRouteLock() {
    Column() {
      Row() {
        KomaIconButton({
          icon: $r('sys.symbol.chevron_left'),
          accessibilityLabel: AppStrings.get('common_back'),
          action: (): void => {
            if (this.isReaderRouteVisible()) this.closeReader()
            else this.appPathStack.pop(false)
          },
        })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, top: this.layoutSafeArea.topAvoidHeight })
      .justifyContent(FlexAlign.Start)
      Column() {
        KomaIconButton({
          icon: $r('sys.symbol.lock'),
          accessibilityLabel: AppStrings.get('library_privacy_unlock'),
          kind: 'secondary',
          controlSize: ThemeConstants.BUTTON_HEIGHT,
          isEnabled: this.libraryPrivacy.presenting && !this.libraryPrivacy.authenticating,
          action: (): void => {
            const workId = this.readerSessionConfig.comicId
            if (this.privateContinuationSession(workId)) {
              const context = this.getUIContext().getHostContext() as common.UIAbilityContext
              void this.libraryPrivacy.activateContinuationPrivacy(context, workId,
                (): boolean => this.readerSessionConfig.comicId === workId && this.showPrivateRouteLock())
              return
            }
            void this.unlockPrivateCategory((): boolean => this.showPrivateRouteLock())
          },
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private coverExpandSurfaceActive(): boolean {
    return this.detailTransition.eligible &&
      this.detailTransition.isCoverExpand() &&
      !this.detailTransition.independentPopSurfaceActive &&
      (this.detailTransition.phase === MangaDetailTransitionPhase.OPENING ||
        this.detailTransition.phase === MangaDetailTransitionPhase.CLOSING)
  }

  private sourceCoverLeftInCard(): number {
    return Math.max(0, Math.min(
      this.detailTransition.handoffWidth,
      this.detailTransition.sourceCoverX - this.detailTransition.handoffX,
    ))
  }

  private sourceCoverTopInCard(): number {
    return Math.max(0, Math.min(
      this.detailTransition.handoffHeight,
      this.detailTransition.sourceCoverY - this.detailTransition.handoffY,
    ))
  }

  private sourceCoverRightInCard(): number {
    return Math.max(this.sourceCoverLeftInCard(), Math.min(
      this.detailTransition.handoffWidth,
      this.detailTransition.sourceCoverX + this.detailTransition.sourceCoverWidth -
        this.detailTransition.handoffX,
    ))
  }

  private sourceCoverBottomInCard(): number {
    return Math.max(this.sourceCoverTopInCard(), Math.min(
      this.detailTransition.handoffHeight,
      this.detailTransition.sourceCoverY + this.detailTransition.sourceCoverHeight -
        this.detailTransition.handoffY,
    ))
  }

  // These nodes are disposable transition resources, not another animation owner. Identity only
  // disables ArkUI's implicit If enter/exit; the coordinator still owns all 350ms geometry/opacity.
  @Builder
  private MangaDetailCardSnapshotSlice(
    sliceX: number,
    sliceY: number,
    sliceWidth: number,
    sliceHeight: number,
  ) {
    if (
      this.detailTransition.cardSnapshot !== undefined &&
      sliceWidth > 0 &&
      sliceHeight > 0
    ) {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.detailTransition.cardSnapshot)
          .width(this.detailTransition.handoffWidth)
          .height(this.detailTransition.handoffHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({
            x: -sliceX,
            y: -sliceY,
          })
          .hitTestBehavior(HitTestMode.None)
          .transition(TransitionEffect.IDENTITY)
      }
      .width(sliceWidth)
      .height(sliceHeight)
      .position({
        x: sliceX,
        y: sliceY,
      })
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
      .transition(TransitionEffect.IDENTITY)
    }
  }

  @Builder
  private MangaDetailSourceCardRemainder() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.MangaDetailCardSnapshotSlice(
        0,
        0,
        this.detailTransition.handoffWidth,
        this.sourceCoverTopInCard(),
      )
      this.MangaDetailCardSnapshotSlice(
        0,
        this.sourceCoverTopInCard(),
        this.sourceCoverLeftInCard(),
        this.sourceCoverBottomInCard() - this.sourceCoverTopInCard(),
      )
      this.MangaDetailCardSnapshotSlice(
        this.sourceCoverRightInCard(),
        this.sourceCoverTopInCard(),
        this.detailTransition.handoffWidth - this.sourceCoverRightInCard(),
        this.sourceCoverBottomInCard() - this.sourceCoverTopInCard(),
      )
      this.MangaDetailCardSnapshotSlice(
        0,
        this.sourceCoverBottomInCard(),
        this.detailTransition.handoffWidth,
        this.detailTransition.handoffHeight - this.sourceCoverBottomInCard(),
      )
    }
    .width(this.detailTransition.handoffWidth)
    .height(this.detailTransition.handoffHeight)
    .position({
      x: this.detailTransition.handoffX,
      y: this.detailTransition.handoffY,
    })
    // The cropped cover slot on a list row should reveal that row's background
    // while the flying cover is still on its way back.
    .backgroundColor(this.detailTransition.sourceSurfaceBackground ?? Color.Transparent)
    .borderRadius(this.detailTransition.sourceSurfaceRadius)
    .clip(true)
    .opacity(this.detailTransition.cardOpacity)
    .zIndex(2)
    .hitTestBehavior(HitTestMode.None)
    .transition(TransitionEffect.IDENTITY)
  }

  @Builder
  private MangaDetailSourceSurfaceSnapshot(zIndex: number) {
    if (this.detailTransition.sourceSnapshot !== undefined) {
      Image(this.detailTransition.sourceSnapshot)
        .width(this.detailTransition.sourceSnapshotWidth)
        .height(this.detailTransition.sourceSnapshotHeight)
        .objectFit(ImageFit.Fill)
        .syncLoad(true)
        .position({
          x: this.detailTransition.sourceSnapshotX,
          y: this.detailTransition.sourceSnapshotY,
        })
        .zIndex(zIndex)
        .hitTestBehavior(HitTestMode.None)
        .transition(TransitionEffect.IDENTITY)
    }
  }

  @Builder
  private MangaDetailFlightCover(token: number, source: MangaDetailTransitionCoverSource | undefined) {
    if (source !== undefined && source.uri.length > 0) {
      CachedCoverImage({
        uri: source.uri,
        sourceRuntimeId: source.sourceRuntimeId,
        sourceImageId: source.sourceImageId,
        sourceMangaUrl: source.sourceMangaUrl,
        sourceCoverHeaders: source.sourceCoverHeaders,
        sourceKind: source.sourceKind,
        remoteServerId: source.remoteServerId,
        decodeMaxEdge: source.decodeMaxEdge,
        onReady: (): void => {
          if (this.detailTransition.owns(token) && sameTransitionCover(source, this.detailTransition.coverSource)) {
            this.detailTransition.markCoverResourceReady()
          }
        },
      }).transition(TransitionEffect.IDENTITY)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // Application-scoped bridged WebView: history and shelf reader entries
      // must not depend on SourceBrowsePage still being mounted.
      SourceWebFetchBridgeHost()
      if (this.detailTransition.eligible && this.detailTransition.sourceSnapshot !== undefined &&
        !this.detailTransition.independentPopSurfaceActive && (!this.detailTransition.isCoverExpand() ||
          this.detailTransition.phase === MangaDetailTransitionPhase.OPENING ||
          this.detailTransition.phase === MangaDetailTransitionPhase.CLOSING ||
          this.detailTransition.phase === MangaDetailTransitionPhase.POST_POP_HANDOFF)) {
        Image(this.detailTransition.sourceSnapshot)
          .width(this.detailTransition.sourceSnapshotWidth).height(this.detailTransition.sourceSnapshotHeight)
          .position({ x: this.detailTransition.sourceSnapshotX, y: this.detailTransition.sourceSnapshotY }).objectFit(ImageFit.Fill).syncLoad(true)
          .hitTestBehavior(HitTestMode.None)
          .transition(TransitionEffect.IDENTITY)
      }
      if (this.languageState.effectiveLocale.length >= 0) {
        Stack({ alignContent: Alignment.TopStart }) {
        HdsNavigation(this.appPathStack) {
          HdsTabs({ controller: this.tabController }) {
            TabContent() {
              LibraryPage({
                libraryScroller: this.libraryScroller,
                onRootScroll: (offset: number, state: ScrollState): void => { this.onRootTabScroll(TabIndex.LIBRARY, offset, state) },
                active: this.selectedTab === TabIndex.LIBRARY,
                rootNavigation: this.rootNavigation,
                libraryStore: this.libraryStore,
                libraryPreferencesRevision: this.libraryPreferencesRevision,
                libraryRevision: this.libraryRevision,
                readerSessionStore: this.readerSessionStore,
                readerProgressRevision: this.readerProgressRevision,
                readingPresentationChange: this.readingPresentationChange,
                continueReadingCard: this.continueReadingCard,
                scopedContinueReadingCard: this.scopedContinueReadingCard,
                presentationByComicId: this.presentationByComicId,
                sourceRegistry: this.sourceRegistry,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onOpenMangaDetail: (comicId: ComicId) => {
                  this.openLibraryMangaDetail(comicId)
                },
                onContinueReading: (comicId: ComicId) => {
                  this.openLibraryContinueReading(comicId)
                },
                onProgressStoreReloadRequested: () => {
                  this.reloadReaderSessionStore('bootstrap_sync')
                },
                onReadingStateChanged: (comicIds: string[]): void => { this.refreshReadingPresentation(comicIds) },
                onRefresh: async (): Promise<void> => { await this.refreshBookshelf() },
                onImportRequested: () => {
                  this.openImport()
                },
                onSearchRequested: () => {
                  RouterHelper.openSearch({})
                },
                onMigrationRequested: (comicIds: string[]): void => {
                  void this.openMangaMigration(comicIds, false)
                },
                onOpenUpdatesRequested: (): void => {
                  RouterHelper.pushLibraryUpdates()
                },
                onOpenCategoriesRequested: (): void => {
                  this.appPathStack.pushPath({ name: RouteName.LIBRARY_CATEGORIES, param: new LibraryCategoryManagementChrome() })
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
                onEditCategoriesRequested: (comicIds: ComicId[], added: string[], removed: string[]): void => {
                  const changed = editComicCategoriesAndPersistLibraryStore(this.libraryStore,
                    this.ensureLibraryPersistenceService(), comicIds, added, removed)
                  if (changed > 0) this.refreshLibrarySnapshot()
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.LIBRARY), TabIndex.LIBRARY))

            TabContent() {
              BrowsePage({
                chrome: this.browseCatalogChrome,
                browseScroller: this.rootTabScrollers[TabIndex.BROWSE],
                onRootScroll: (offset: number, state: ScrollState): void => { this.onRootTabScroll(TabIndex.BROWSE, offset, state) },
                active: this.selectedTab === TabIndex.BROWSE,
                rootNavigation: this.rootNavigation,
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
                onRootScroll: (offset: number, state: ScrollState): void => { this.onRootTabScroll(TabIndex.HISTORY, offset, state) },
                libraryStore: this.libraryStore,
                libraryRevision: this.libraryRevision,
                active: this.selectedTab === TabIndex.HISTORY,
                rootNavigation: this.rootNavigation,
                readerSessionStore: this.readerSessionStore,
                readerProgressRevision: this.readerProgressRevision,
                readingPresentationChange: this.readingPresentationChange,
                onReadingStateChanged: (comicIds: string[]): void => { this.refreshReadingPresentation(comicIds) },
                onRefresh: async (): Promise<void> => { await this.syncFromRootRefresh() },
                onOpenDetail: (comicId: ComicId, source?: SourceReadHistoryEntry, remote?: RemoteReadHistoryEntry) => {
                  this.openHistoryDetail(comicId, source, remote)
                },
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  this.cancelHistoryResume()
                  const comic = this.libraryStore.getComic(comicId)
                  if (comic?.sourceRuntimeId?.startsWith('mihon:')) {
                    void this.resumeMihonFromHistory(comicId)
                    return
                  }
                  // A history row resumes the work, including progress received
                  // since it was rendered. Explicit chapter opens keep their ID.
                  const sourceResume = comic?.sourceRuntimeId !== undefined && comic.remoteResourceId !== undefined
                  void this.openReader(comicId, sourceResume ? undefined : chapterId)
                },
                onOpenSourceReader: (request: SourceReaderSessionRequest) => {
                  void this.resumeSourceFromHistory(request)
                },
                onOpenRemoteReader: (entry: RemoteReadHistoryEntry) => {
                  this.cancelHistoryResume()
                  this.openRemoteHistory(entry)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.HISTORY), TabIndex.HISTORY))

            TabContent() {
              SettingsPage({
                enhancementModelsRevision: this.enhancementModelsRevision,
                onEnhancementModelsChanged: () => { this.enhancementModelsRevision += 1 },
                scroller: this.rootTabScrollers[TabIndex.SETTINGS],
                onRootScroll: (offset: number, state: ScrollState): void => { this.onRootTabScroll(TabIndex.SETTINGS, offset, state) },
            preferencesRestoreRevision: this.applicationSettingsRestoreRevision,
                pane: 'root',
                onLibraryPreferencesChanged: () => { this.libraryPreferencesRevision += 1 },
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                sourceRegistry: this.sourceRegistry,
                onOpenSettingsPane: (pane: SettingsPaneKey, rowKey?: string) => {
                  this.openSettingsPane(pane, rowKey, true)
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
                onOpenDownloads: () => {
                  this.openSettingsSecondary(RouteName.DOWNLOADS)
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
            miniBar: this.resumeMiniBarOptions(),
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.ADAPTIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
            },
          } as HdsTabsFloatingStyle)
          .onAppear(() => { this.applyBottomBarAutoHide() })
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
            this.restoreBottomBar()
            if (index === TabIndex.HISTORY) appDeviceSync.historyOpened()
            if (index === TabIndex.LIBRARY) appDeviceSync.bookshelfOpened()
          })
        }
        .titleBar(this.titleBarOptions())
        .bindToScrollable([this.titleScroller])
        .titleMode(HdsNavigationTitleMode.MINI)
        .hideBackButton(this.selectedTab !== TabIndex.LIBRARY || !this.libraryTitleBar.selectionMode)
        .dynamicHideTitleBar({
          hideTitleArea: this.selectedTab === TabIndex.BROWSE && this.browseCatalogChrome.searchExpanded,
          hideBottomBuilder: false,
          hideStatusBar: false,
          mode: HideMode.SCROLL_UP,
        })
        .navDestination(this.AppDestination)
        .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
          operation: NavigationOperation): NavigationAnimatedTransition | undefined =>
          MangaDetailTransitionCoordinator.transition(this.getUIContext(), from, to, operation) ??
          this.readerOrdinaryNavTransition(from, to, operation))
        .mode(NavigationMode.Stack)
        .accessibilityLevel(this.showPrivateRouteLock() ? 'no-hide-descendants' : 'auto')
        .onAppear(() => {
          this.rootNavigationMounted = true
          this.tryStartPendingContinuationTask()
        })
        .onNavBarStateChange((visible: boolean) => {
          this.rootNavigation.visible = visible
          if (visible) {
            if (!this.rootNavigationMounted) this.rootNavigationMounted = true
            this.tryStartPendingContinuationTask()
            this.publishDeferredReaderBackgroundPresentation()
            const comicId = this.pendingMihonResume
            this.pendingMihonResume = undefined
            if (comicId !== undefined) void this.openMihonImportedWork(comicId)
          } else this.resetRootBackConfirmation()
        })
        .width(this.coverExpandSurfaceActive() ? Math.max(1, this.detailTransition.rootWidth) : '100%')
        .height(this.coverExpandSurfaceActive() ? Math.max(1, this.detailTransition.rootHeight) : '100%')
        .position({ x: this.coverExpandSurfaceActive() ? -this.detailTransition.clipX : 0,
          y: this.coverExpandSurfaceActive() ? -this.detailTransition.clipY : 0 })
        .id(MANGA_DETAIL_ROOT_ID)
        .backgroundColor(this.detailTransition.eligible ? Color.Transparent : $r('sys.color.ohos_id_color_sub_background'))
        }
        .width(this.coverExpandSurfaceActive() ? Math.max(1, this.detailTransition.clipWidth) : '100%')
        .height(this.coverExpandSurfaceActive() ? Math.max(1, this.detailTransition.clipHeight) : '100%')
        .position({ x: this.coverExpandSurfaceActive() ? this.detailTransition.clipX : 0,
          y: this.coverExpandSurfaceActive() ? this.detailTransition.clipY : 0 })
        .backgroundColor(ThemeConstants.BG_SUB)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .borderRadius(this.coverExpandSurfaceActive() ? this.detailTransition.radius : 0)
        .clip(this.coverExpandSurfaceActive())
      }
      if (this.detailTransition.independentPopSurfaceVisible()) {
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.detailTransition.detailSnapshot)
            .width(this.detailTransition.rootWidth)
            .height(this.detailTransition.rootHeight)
            .objectFit(ImageFit.Fill)
            .syncLoad(true)
            .position({
              x: -this.detailTransition.clipX,
              y: -this.detailTransition.clipY,
            })
            .hitTestBehavior(HitTestMode.None)
            .transition(TransitionEffect.IDENTITY)
        }
        .width(Math.max(1, this.detailTransition.clipWidth))
        .height(Math.max(1, this.detailTransition.clipHeight))
        .position({
          x: this.detailTransition.clipX,
          y: this.detailTransition.clipY,
        })
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .borderRadius(this.detailTransition.radius)
        .clip(true)
        .zIndex(1)
        .hitTestBehavior(HitTestMode.None)
        .transition(TransitionEffect.IDENTITY)
      }
      if (
        (this.detailTransition.phase === MangaDetailTransitionPhase.PREPARING ||
          (this.detailTransition.phase === MangaDetailTransitionPhase.OPENING && !this.detailTransition.animationStarted)) &&
        this.detailTransition.cardSnapshot !== undefined
      ) {
        Image(this.detailTransition.cardSnapshot)
          .width(this.detailTransition.handoffWidth)
          .height(this.detailTransition.handoffHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({
            x: this.detailTransition.handoffX,
            y: this.detailTransition.handoffY,
          })
          .hitTestBehavior(HitTestMode.None)
          .transition(TransitionEffect.IDENTITY)
      }
      if (
        this.detailTransition.eligible &&
        this.detailTransition.isCoverExpand() &&
        this.detailTransition.cardSnapshot !== undefined
      ) {
        if (this.detailTransition.preserveSourceCoverBackground) {
          // The card snapshot was captured after only the foreground image became transparent. Its real
          // blur/gradient layer therefore remains complete and needs no synthetic mask or background patch.
          Image(this.detailTransition.cardSnapshot)
            .width(this.detailTransition.handoffWidth)
            .height(this.detailTransition.handoffHeight)
            .objectFit(ImageFit.Fill)
            .syncLoad(true)
            .position({
              x: this.detailTransition.handoffX,
              y: this.detailTransition.handoffY,
            })
            .borderRadius(this.detailTransition.sourceSurfaceRadius)
            .clip(true)
            .opacity(this.detailTransition.cardOpacity)
            .zIndex(2)
            .hitTestBehavior(HitTestMode.None)
            .transition(TransitionEffect.IDENTITY)
        } else {
          // Covers without a separate backdrop keep the existing four-slice path so the expanding detail
          // surface is revealed instead of exposing the thumbnail's generic loading placeholder.
          this.MangaDetailSourceCardRemainder()
        }
      }
      if (
        this.detailTransition.coverFlightVisible() &&
        this.detailTransition.coverSnapshot !== undefined
      ) {
        // The cover belongs to the expanding card surface. Give it a second clip with exactly the
        // surface bounds/radius so it can never protrude past a rounded container corner while flying.
        Stack({ alignContent: Alignment.TopStart }) {
          Stack() {
            this.MangaDetailFlightCover(this.detailTransition.routeToken, this.detailTransition.coverSource)
            if (!this.detailTransition.coverResourceReady) {
              // The click-time pixels guarantee that the first transition frame cannot be blank.
              // Once the already-cached thumbnail resource paints, it takes over at the identical
              // Cover crop and can reveal the full image continuously as the flight rect changes.
              Image(this.detailTransition.coverSnapshot)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .syncLoad(true)
                .transition(TransitionEffect.IDENTITY)
            }
          }
            .width(this.detailTransition.flightCoverWidth)
            .height(this.detailTransition.flightCoverHeight)
            .position({
              x: this.detailTransition.flightCoverX - this.detailTransition.clipX,
              y: this.detailTransition.flightCoverY - this.detailTransition.clipY,
            })
            .borderRadius(this.detailTransition.flightCoverRadius)
            .clip(true)
            .renderGroup(true)
            .hitTestBehavior(HitTestMode.None)
            .transition(TransitionEffect.IDENTITY)
        }
        .width(Math.max(1, this.detailTransition.clipWidth))
        .height(Math.max(1, this.detailTransition.clipHeight))
        .position({
          x: this.detailTransition.clipX,
          y: this.detailTransition.clipY,
        })
        .borderRadius(this.detailTransition.radius)
        .clip(true)
        .zIndex(3)
        .hitTestBehavior(HitTestMode.None)
        .transition(TransitionEffect.IDENTITY)
      }
      if (
        this.detailTransition.fallbackCoverVisible() &&
        this.detailTransition.coverSnapshot !== undefined
      ) {
        // When the detail cover is off-screen there is no valid flight origin. Fade the click-time
        // source pixels in at their exact landing rect while the detail surface finishes collapsing;
        // this avoids exposing the intentionally hidden source card as an empty cover slot.
        Image(this.detailTransition.coverSnapshot)
          .width(this.detailTransition.sourceCoverWidth)
          .height(this.detailTransition.sourceCoverHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({
            x: this.detailTransition.sourceCoverX,
            y: this.detailTransition.sourceCoverY,
          })
          .borderRadius(this.detailTransition.sourceCoverRadius)
          .clip(true)
          .opacity(this.detailTransition.fallbackCoverOpacity)
          .zIndex(3)
          .hitTestBehavior(HitTestMode.None)
          .transition(TransitionEffect.IDENTITY)
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

      // Incognito status strip sits above every page below the reader. The
      // reader route owns its own chrome, so hide the strip while it is open.
      if (!this.readerOpen && !this.readerRouteVisible) {
        IncognitoStatusBarOverlay()
      }
      if (this.showPrivateRouteLock()) this.PrivateRouteLock()
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
      menu['value'] = this.libraryTitleBar.menuItems.map((item: Record<string, Object>): Record<string, Object> => {
        const action = item['content'] as Record<string, Object>
        if (action['componentId'] !== 'library-title-updates') return item
        const bell: Record<string, Object> = { 'content': action }
        if (this.libraryUpdatesUnseen) {
          const badge: HdsNavigationBadgeOptions = { value: '' }
          bell['badge'] = badge
        }
        return bell
      })
      menu['maxCount'] = 3
    } else if (this.selectedTab === TabIndex.HISTORY) {
      const statisticsContent: Record<string, Object> = { 'label': AppStrings.get('reading_statistics_title'),
        'icon': $r('app.media.ic_reading_statistics'),
        'action': (): void => { this.appPathStack.pushPath({ name: RouteName.READING_STATISTICS }) } }
      const statisticsItem: Record<string, Object> = { 'content': statisticsContent }
      menu['value'] = [statisticsItem]
      menu['maxCount'] = 1
    } else if (this.selectedTab === TabIndex.BROWSE) {
      // HDS must first attach this bottomBuilder at its real nonzero height;
      // mounting it at zero retained an invisible proxy on the tested device.
      // The inner component and list reserve still animate from/to zero.
      if (this.browseCatalogChrome.searchVisible) {
        content['bottomBuilder'] = { 'builderComponent': this.catalogSearchContent(this.browseCatalogChrome),
          'height': SEARCH_TITLE_BOTTOM_HEIGHT,
          'showType': BottomBuilderShowType.DIRECTLY_SHOW } as Record<string, Object>
      }
      content['stackBuilderComponent'] = this.catalogHeaderActionsContent()
      menu['value'] = []
      menu['maxCount'] = 0
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

  private searchTitleBarOpts(param: SearchRouteParam, migration: boolean = false): Record<string, Object> {
    const chrome = RouterHelper.ensureSearchRouteChrome(param)
    const title: Record<string, Object> = {}
    title['mainTitle'] = AppStrings.get(migration ? 'migration_title' : 'tab_search')
    const bottomBuilder: Record<string, Object> = {}
    bottomBuilder['builderComponent'] = this.searchFieldContent(chrome)
    bottomBuilder['height'] = SEARCH_TITLE_BOTTOM_HEIGHT
    bottomBuilder['showType'] = BottomBuilderShowType.DIRECTLY_SHOW
    const filterContent: Record<string, Object> = {
      'label': AppStrings.get('search_filter_label'),
      'icon': $r('sys.symbol.funnel'),
      'componentId': chrome.filterAnchorId,
      'isEnabled': true,
      'action': () => {
        chrome.requestFilters()
      },
    }
    const filterItem: Record<string, Object> = {}
    filterItem['content'] = filterContent
    const modeContent: Record<string, Object> = {
      'label': AppStrings.get(chrome.resultsOnly ? 'search_results_only' : 'search_results_all'),
      'type': TextStyleMode.NORMAL,
      'componentId': chrome.resultModeAnchorId,
      'action': (): void => { chrome.requestResultMode() },
    }
    const modeItem: Record<string, Object> = { 'content': modeContent }
    const menu: Record<string, Object> = {}
    menu['value'] = [filterItem, modeItem]
    menu['maxCount'] = 2
    const content: Record<string, Object> = {}
    content['title'] = title
    content['bottomBuilder'] = bottomBuilder
    if (!migration) content['menu'] = menu
    return this.sourceRouteTitleBarOpts(content)
  }

  private sourceHomepageMenuItem(source: SourceRuntimeRegistryInstalledSourceSummary,
    isCurrent: () => boolean): Record<string, Object> | undefined {
    // 2026-10-27: only advertise an address already declared by this source.
    // The user's no-empty-entry decision replaces optimistic IO on menu taps.
    const installedHomepage = normalizeSourceHomepage(source.homepage)
    const homepage = installedHomepage ?? normalizeSourceHomepage(
      appSourcePackageManagerCache.indexEntries.find((entry): boolean => entry.id === source.sourceId)?.homepage)
    if (homepage === undefined) return undefined
    const content: Record<string, Object> = {
      'label': AppStrings.get('manga_detail_menu_open_webview'),
      'icon': $r('sys.symbol.worldclock'),
      'isEnabled': true,
      'action': (): void => {
        if (!isCurrent()) return
        const selected = selectedSourceHomepage(source.sourceId)
        RouterHelper.pushMangaWeb({ url: selected ?? homepage, sourceId: source.sourceId, title: sourceDisplayName(source.sourceId, source.displayName) })
      },
    }
    return { 'content': content }
  }

  private setSourceBrowseLayout(chrome: SourceBrowseRouteChromeState, layout: SourceBrowseLayout): void {
    if (!chrome.visible) return
    const store = new SourceBrowseLayoutPreferences(getContext(this) as common.UIAbilityContext)
    void store.save(chrome.sourceId, layout).then((): void => {
      chrome.layout = layout
    }).catch((): void => {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({
        message: AppStrings.get('source_browse_layout_save_failed'),
      }))
    })
  }

  private sourceBrowseOverflow(chrome: SourceBrowseRouteChromeState, items: Record<string, Object>[]): Record<string, Object> {
    const content: Record<string, Object> = {
      'label': AppStrings.get('common_more_actions'),
      'icon': komaTitleMoreIcon(), 'componentId': chrome.menuAnchorId, 'isEnabled': true,
      'action': (): void => {
        if (!chrome.visible) return
        this.sourceBrowseMenu.open(this.getUIContext(), chrome.menuAnchorId, (): KomaMenuGroup[] => {
          const actions: KomaMenuAction[] = items.map((item: Record<string, Object>): KomaMenuAction => {
            const action = item['content'] as Record<string, Object>
            return { label: action['label'] as string, icon: action['icon'] as Resource,
              isEnabled: action['isEnabled'] as boolean, action: action['action'] as () => void }
          })
          const layout: KomaMenuAction = {
            label: AppStrings.get('source_browse_layout_style'), action: (): void => {},
            children: [
              { label: AppStrings.get('library_view_mode_grid'), selected: chrome.layout === 'grid',
                action: (): void => { this.setSourceBrowseLayout(chrome, 'grid') } },
              { label: AppStrings.get('library_view_mode_list'), selected: chrome.layout === 'list',
                action: (): void => { this.setSourceBrowseLayout(chrome, 'list') } },
            ],
          }
          return [{ id: 'source-actions', items: actions }, { id: 'source-layout', items: [layout] }]
        }, (): void => { DiagnosticLogger.warn('source_browse', 'menu_open_failed', 'result=failed') })
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
    if (chrome.authenticationAvailable) {
      const authenticationContent: Record<string, Object> = {
        'label': AppStrings.get('source_login'), 'icon': $r('sys.symbol.person'),
        'isEnabled': source.enabled, 'action': () => { chrome.requestAuthentication() },
      }
      menuItems.push({ 'content': authenticationContent })
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
            this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_not_allowed') }))
          }
        },
      }
      menuItems.push({ 'content': webContent })
    }
    // The HDS automatic overflow is flat. Keep the existing action order and
    // two direct slots, with the shared native layout submenu in the last slot.
    const direct = menuItems.slice(0, SOURCE_ROUTE_TITLE_MENU_MAX_COUNT - 1)
    direct.push(this.sourceBrowseOverflow(chrome, menuItems.slice(direct.length)))
    const menu: Record<string, Object> = { 'value': direct, 'maxCount': SOURCE_ROUTE_TITLE_MENU_MAX_COUNT }
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
    if (chrome.authenticationAvailable) {
      const authenticationContent: Record<string, Object> = {
        'label': AppStrings.get('source_login'), 'icon': $r('sys.symbol.person'),
        'isEnabled': source.enabled, 'action': () => { chrome.requestAuthentication() },
      }
      menuItems.push({ 'content': authenticationContent })
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
            this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_not_allowed') }))
          }
        },
      }
      menuItems.push({ 'content': webContent })
    }
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': SOURCE_ROUTE_TITLE_MENU_MAX_COUNT }
    content['menu'] = menu
    return this.sourceRouteTitleBarOpts(content)
  }

  private settingsPaneTitleBarOpts(param: SettingsPaneRouteParam): Record<string, Object> {
    const options = this.navDestTitleBarOpts(settingsPaneTitle(this.settingsPaneFromParam(param)))
    const actions = this.settingsPaneTitleActions(param)
    if (actions.length > 0) {
      const content = options['content'] as Record<string, Object>
      content['menu'] = { 'value': actions, 'maxCount': 1 } as Record<string, Object>
    }
    return options
  }

  private settingsPaneTitleActions(param: SettingsPaneRouteParam): HdsNavigationMenuItemOptions[] {
    if (param.pane === 'llm-sources') {
      return [{ content: { 'label': AppStrings.get('llm_source_add'),
        'icon': $r('sys.symbol.plus'), 'componentId': MODEL_SOURCE_ADD_BUTTON_ID,
        'isEnabled': param.modelSourcesTitleAction.enabled,
        'action': (): void => { param.modelSourcesTitleAction.requestId++ } } }]
    }
    if (param.pane !== 'translation') return []
    return [{ content: {
      'label': AppStrings.get('common_save'), 'icon': $r('sys.symbol.checkmark'),
      'isEnabled': param.formTitleAction.enabled,
      'action': (): void => { param.formTitleAction.requestSave() },
    } }]
  }

  private deviceSyncReviewTitle(reason: DeviceSyncReviewReason): string {
    if (reason === 'first') return 'device_sync_review_first_title'
    if (reason === 'scope') return 'device_sync_review_scope_title'
    if (reason === 'restore') return 'device_sync_review_restore_title'
    if (reason === 'pending') return 'device_sync_pending_items'
    if (reason === 'recovery') return 'device_sync_continue_previous'
    return 'device_sync_review_differences'
  }

  private deviceSyncActionTitleBarOpts(chrome: DeviceSyncWebDavChrome, titleKey: string, actionKey: string): Record<string, Object> {
    const titleAction = chrome.confirm
    const options = this.navDestTitleBarOpts(AppStrings.get(titleKey))
    const content = options['content'] as Record<string, Object>
    const items: Record<string, Object>[] = []
    if (chrome.actionVisible) {
      const action: Record<string, Object> = { 'label': AppStrings.get(actionKey),
        'type': TextStyleMode.NORMAL, 'isEnabled': titleAction.enabled,
        'action': (): void => { titleAction.requestSave() } }
      items.push({ 'content': action })
    }
    // HDS preserves the previous menu when the property is omitted.
    const menu: Record<string, Object> = { 'value': items, 'maxCount': 1 }
    content['menu'] = menu
    return options
  }

  private deviceSyncWebDavTitleBarOpts(): Record<string, Object> {
    const options = this.navDestTitleBarOpts(AppStrings.get('device_sync_webdav'))
    const content = options['content'] as Record<string, Object>
    const state = appDeviceSync.view
    const items: Record<string, Object>[] = []
    if (state.configured) {
      const automatic: Record<string, Object> = { 'type': TextStyleMode.NORMAL,
        'label': AppStrings.get(state.automatic ? 'device_sync_switch_manual' : 'device_sync_switch_auto'),
        'action': (): void => { appDeviceSync.setAutomatic(!appDeviceSync.view.automatic) } }
      items.push({ 'content': automatic })
      const disconnect: Record<string, Object> = { 'type': TextStyleMode.NORMAL, 'label': AppStrings.get('device_sync_disconnect'),
        'action': (): void => {
          this.getUIContext().showAlertDialog({ title: AppStrings.get('device_sync_disconnect'),
            message: AppStrings.get('device_sync_disconnect_detail'), systemMaterial: komaDialogMaterial(),
            primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
            secondaryButton: { value: AppStrings.get('device_sync_disconnect'), action: (): void => {
              void appDeviceSync.disconnect().catch((): void => {})
            } } })
        } }
      items.push({ 'content': disconnect })
    }
    content['menu'] = { 'value': items, 'maxCount': 1 } as Record<string, Object>
    return options
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

  private migrationSearchTitleBarOpts(chrome: SearchRouteChromeState, fromMihon: boolean, enabled: boolean,
    onChooseSources: () => void): Record<string, Object> {
    const options = this.searchTitleBarOpts({ chrome }, true)
    const content = options['content'] as Record<string, Object>
    if (fromMihon) {
      content['title'] = { 'mainTitle': AppStrings.get('tab_search') } as Record<string, Object>
    }
    const itemContent: Record<string, Object> = { 'label': AppStrings.get('migration_choose_sources'),
      'icon': $r('sys.symbol.funnel'), 'isEnabled': enabled, 'action': onChooseSources }
    const item: Record<string, Object> = { 'content': itemContent }
    content['menu'] = { 'value': [item], 'maxCount': 1 } as Record<string, Object>
    return options
  }

  private migrationTitleBarOpts(param: MangaMigrationRouteParam): Record<string, Object> {
    const chrome = RouterHelper.ensureMigrationRouteChrome(param)
    if (chrome.stage === 'search') {
      return this.migrationSearchTitleBarOpts(chrome.search, param.fromMihon === true, !chrome.busy,
        (): void => { chrome.request('sources') })
    }
    const items: Record<string, Object>[] = []
    const add = (label: string, icon: Resource, command: MigrationCommand, enabled: boolean): void => {
      const content: Record<string, Object> = { 'label': AppStrings.get(label), 'icon': icon,
        'isEnabled': enabled && !chrome.busy, 'action': (): void => { chrome.request(command) } }
      const item: Record<string, Object> = { 'content': content }
      items.push(item)
    }
    if (chrome.stage === 'sources') {
      add('migration_continue', $r('sys.symbol.arrow_right'), 'continue', chrome.canContinue)
    } else {
      if (!param.fromMihon) add('migration_copy', $r('sys.symbol.doc_plaintext'), 'copy', chrome.readyCount > 0)
      add(param.fromMihon ? 'mihon_import_match_action' : 'migration_move', $r('sys.symbol.arrow_right'), 'move', chrome.readyCount > 0)
      add('migration_choose_sources', $r('sys.symbol.funnel'), 'sources', true)
      if (!param.fromMihon) {
        add('migration_retry_failed', $r('sys.symbol.arrow_clockwise'), 'retryFailed', chrome.failedCount > 0 && chrome.searchingCount === 0)
      }
      add('migration_finish', $r('sys.symbol.checkmark'), 'finish', true)
    }
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get(param.fromMihon ? 'mihon_import_find_work' : 'migration_title') }
    const menu: Record<string, Object> = { 'value': items, 'maxCount': 2 }
    const content: Record<string, Object> = { 'title': title, 'menu': menu }
    return this.sourceRouteTitleBarOpts(content)
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
      ? this.libraryStore.findBySourceManga(sourceId, mangaId)
      : this.libraryStore.getComic(param.mangaId)
    const comicTitle = comic?.title?.trim() ?? ''
    if (comicTitle.length > 0) {
      return comicTitle
    }
    return ''
  }

  private mangaDetailMenuGroups(chrome: MangaDetailRouteChromeState): KomaMenuGroup[] {
    const work: KomaMenuAction[] = []
    const opening: KomaMenuAction[] = []
    const add = (items: KomaMenuAction[], key: string, command: MangaDetailTitleAction, enabled: boolean = true,
      count?: number): void => {
      const label = AppStrings.get(key)
      items.push({ label: count === undefined ? label : label.replace('%s', `${count}`), isEnabled: enabled,
        action: (): void => { if (chrome.visible) chrome.requestAction(command) } })
    }
    if (chrome.chapterPresentation.selectionMode) {
      const items: KomaMenuAction[] = []
      const count = chrome.chapterPresentation.selectedChapterIds.size
      const hasSelection = count > 0
      add(items, 'chapter_list_menu_download_selected', MangaDetailTitleAction.DOWNLOAD_SELECTED_CHAPTERS,
        hasSelection && chrome.selectedChapterDownloadEnabled, count)
      add(items, 'chapter_list_menu_mark_read', MangaDetailTitleAction.MARK_SELECTED_CHAPTERS_READ, hasSelection)
      add(items, 'chapter_list_menu_mark_unread', MangaDetailTitleAction.MARK_SELECTED_CHAPTERS_UNREAD, hasSelection)
      return [{ id: 'selected-chapters', items }]
    }
    if (chrome.sourceReloadAvailable) add(opening, 'manga_detail_menu_reload_source', MangaDetailTitleAction.RELOAD_SOURCE)
    if (chrome.relatedMangaAvailable) add(opening, 'manga_detail_related', MangaDetailTitleAction.OPEN_RELATED)
    if (chrome.pageActionsAvailable) {
      if (chrome.personalDataAvailable) add(work, 'manga_notes', MangaDetailTitleAction.EDIT_NOTES, !chrome.personalizationBusy)
      if (chrome.coverActionsAvailable) {
        add(work, 'manga_cover_change', MangaDetailTitleAction.CHANGE_COVER, !chrome.personalizationBusy)
        if (chrome.coverEnhancementAvailable) add(work, 'cover_sr_title', MangaDetailTitleAction.ENHANCE_COVER, !chrome.personalizationBusy)
        if (chrome.customCoverAvailable) add(work, 'manga_cover_restore', MangaDetailTitleAction.RESTORE_COVER, !chrome.personalizationBusy)
      }
      if (chrome.migrationAvailable) add(work, 'migration_title', MangaDetailTitleAction.MIGRATE)
      if (chrome.localMetadataAvailable) add(work, 'manga_detail_menu_edit_local_metadata', MangaDetailTitleAction.EDIT_LOCAL_METADATA)
      if (chrome.webActionsAvailable) add(opening, 'manga_detail_menu_open_browser', MangaDetailTitleAction.OPEN_BROWSER)
      if (chrome.localRefreshAvailable) add(opening, chrome.localRefreshBusy ? 'manga_detail_local_refresh_checking' :
        'manga_detail_menu_check_local_refresh', MangaDetailTitleAction.CHECK_LOCAL_LIBRARY_REFRESH, !chrome.localRefreshBusy)
    }
    const chapters: KomaMenuAction[] = []
    if (chrome.hasDisplayedChapters) {
      add(chapters, 'chapter_list_menu_enter_selection', MangaDetailTitleAction.SELECT_CHAPTERS)
      if (chrome.chapterDownloadAvailable) {
        const downloads: KomaMenuAction[] = []
        add(downloads, 'chapter_list_menu_download_incomplete', MangaDetailTitleAction.DOWNLOAD_INCOMPLETE)
        add(downloads, 'chapter_list_menu_retry_failed', MangaDetailTitleAction.RETRY_FAILED_DOWNLOADS)
        chapters.push({ label: AppStrings.get('manga_detail_action_download_chapter'),
          children: downloads, action: (): void => {} })
      }
    }
    return [{ id: 'chapters', items: chapters }, { id: 'work', items: work }, { id: 'opening', items: opening }]
  }

  private mangaDetailScrollers(param: MangaDetailRouteParam): ListScroller[] {
    const chrome = RouterHelper.ensureMangaDetailRouteChrome(param)
    return [chrome.detailScroller, chrome.chapterScroller]
  }

  private mangaDetailOverflow(chrome: MangaDetailRouteChromeState): Record<string, Object> {
    const content: Record<string, Object> = {
      'label': AppStrings.get('common_more_actions'),
      'icon': komaTitleMoreIcon(), 'componentId': chrome.menuAnchorId, 'isEnabled': true,
      'action': (): void => {
        this.detailMenu.open(this.getUIContext(), chrome.menuAnchorId, () => this.mangaDetailMenuGroups(chrome), (): void => {
          DiagnosticLogger.warn('manga_detail', 'menu_open_failed', 'result=failed')
        })
      },
    }
    return { 'content': content }
  }

  private mangaDetailTitleBarOpts(param: MangaDetailRouteParam): Record<string, Object> {
    const chrome = RouterHelper.ensureMangaDetailRouteChrome(param)
    const selection = chrome.chapterPresentation
    if (selection.selectionMode) {
      const allSelected = chrome.allFilteredChaptersSelected()
      const selectAllContent: Record<string, Object> = {
        'label': AppStrings.get(allSelected ? 'chapter_list_menu_deselect_all_filtered' : 'chapter_list_menu_select_all_filtered'),
        'icon': allSelected ? $r('sys.symbol.square') : $r('sys.symbol.checkmark_square'),
        'isEnabled': chrome.hasDisplayedChapters,
        'action': (): void => { chrome.requestAction(MangaDetailTitleAction.SELECT_ALL_CHAPTERS) },
      }
      const selectionMenu: Record<string, Object>[] = [{ 'content': selectAllContent }, this.mangaDetailOverflow(chrome)]
      return this.sourceRouteTitleBarOpts({
        'title': { 'mainTitle': AppStrings.get('chapter_list_selected_count')
          .replace('%s', `${selection.selectedChapterIds.size}`) } as Record<string, Object>,
        'backIcon': {
          'label': AppStrings.get('common_cancel'),
          'icon': $r('sys.symbol.xmark'),
          'action': (): void => { selection.setSelectionMode(false) },
        } as Record<string, Object>,
        'menu': { 'value': selectionMenu, 'maxCount': 3 } as Record<string, Object>,
      })
    }
    const title: Record<string, Object> = { 'mainTitle': chrome.showTitle ? this.mangaDetailTitle(param) : '' }
    // Send empty back-button options on exit. Omitting the option leaves HDS
    // with the previous selection icon. Normal navigation uses the default icon and action.
    const content: Record<string, Object> = { 'title': title, 'backIcon': {} as Record<string, Object> }
    const items: Record<string, Object>[] = []
    // Fixed work-page pair: the host always renders WebView and Share together
    // when a public page URL exists. Sources supply only that URL; they never
    // add their own title button or a duplicate Share in the overflow menu.
    // A work without a page URL must not advertise either action.
    if (chrome.webActionsAvailable) {
      items.push({ 'content': { 'label': AppStrings.get('manga_detail_menu_open_webview'),
        'icon': $r('sys.symbol.worldclock'), 'isEnabled': true,
        'action': (): void => { chrome.requestAction(MangaDetailTitleAction.OPEN_WEBVIEW) },
      } as Record<string, Object> })
      items.push({ 'content': { 'label': AppStrings.get('manga_detail_menu_share_link'),
        'icon': $r('sys.symbol.share'), 'isEnabled': !chrome.linkShareBusy,
        'action': (): void => { chrome.requestAction(MangaDetailTitleAction.SHARE_LINK) },
      } as Record<string, Object> })
    }
    if (chrome.pageActionsAvailable || chrome.sourceReloadAvailable || chrome.hasDisplayedChapters) {
      items.push(this.mangaDetailOverflow(chrome))
    }
    if (items.length > 0) content['menu'] = { 'value': items, 'maxCount': 3 } as Record<string, Object>
    return this.sourceRouteTitleBarOpts(content)
  }

}
