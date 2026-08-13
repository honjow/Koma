import { common } from '@kit.AbilityKit'
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
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { LibraryPage } from './LibraryPage'
import { BrowsePage } from './BrowsePage'
import { HistoryPage } from './HistoryPage'
import { SearchPage } from './SearchPage'
import { SettingsPage, SettingsPaneKey, settingsPaneTitle } from './SettingsPage'
import { ImportPage, LocalFolderImportPersistResult } from './ImportPage'
import { ReaderPage } from './ReaderPage'
import { MangaDetailPage } from './MangaDetailPage'
import { SourceBrowsePage } from './SourceBrowsePage'
import { SourceSearchPage } from './SourceSearchPage'
import { KomgaSeriesPage } from './KomgaSeriesPage'
import { KavitaBrowsePage } from './KavitaBrowsePage'
import { OpdsBrowsePage } from './OpdsBrowsePage'
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
import { MangaDetailRouteParam, RouterHelper } from '../common/RouterHelper'
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
  AppFilesReaderSessionPersistenceAdapter,
  InMemoryReaderSessionStore,
  PersistentReaderSessionStore,
  ReaderSessionConfig,
  ReaderSessionStore,
  createReaderSessionConfigFromComic,
  sortedReaderChapters,
} from '../model/ReaderSessionStore'
import { createReaderOfflineMissingUri, installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'
import { SourceChapterPageHydrator } from '../model/SourceChapterPageHydrator'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
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

const readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
const seededLibraryStore: LibraryStore = createSeededLibraryStore()
const libraryPresentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
const sourceRuntimeRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
interface SettingsPaneRouteParam {
  pane: string
}

interface SourceRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
}

@Entry
@ComponentV2
struct Index {
  @Local selectedTab: number = TabIndex.LIBRARY
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
  @Local private libraryRevision: number = 0
  @Local private libraryComics: Comic[] = seededLibraryStore.listComics()
  @Local private searchRouteQuery: string = ''
  @Local private searchRouteSerial: number = 0
  private tabController: HdsTabsController = new HdsTabsController()
  private tabBarHiddenForKeyboard: boolean = false
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId
  private sourceRegistry: SourceRuntimeRegistry = sourceRuntimeRegistry
  private appPathStack: NavPathStack = new NavPathStack()
  private libraryPersistenceService?: LibraryStorePersistenceService
  private readerSessionPersistenceReady: boolean = false
  private libraryPersistenceRestored: boolean = false
  private automaticBackupChecked: boolean = false
  private pendingTrackerProgressChecked: boolean = false
  private readerOpenEpoch: number = 0

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
    // Source pages contain remotely issued request descriptors rather than
    // immutable local files.  Keep an existing page list only for the
    // offline branch above; every online open must re-hydrate it so source
    // upgrades and expiring page URLs cannot leave Reader on stale data.
    return chapter !== undefined
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
      // Source page descriptors are not durable image assets: a source upgrade
      // can change their shape, and many hosts issue short-lived page URLs or
      // headers.  An online Reader open therefore refreshes the chapter's
      // descriptors before it hands them to the page cache.  Offline chapters
      // take the earlier local-file branch and never pay this request.
      ).ensureChapterPages(comic.id, comic.sourceRuntimeId, chapterId as string, true)
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

  private cloneExternalReaderSession(config: ReaderSessionConfig): ReaderSessionConfig {
    return {
      comicId: config.comicId,
      chapterId: config.chapterId,
      chapterIds: config.chapterIds.slice(),
      chapterTitles: config.chapterTitles?.slice(),
      title: config.title,
      chapterTitle: config.chapterTitle,
      totalPages: config.totalPages,
      pageUris: config.pageUris.slice(),
      pageIds: config.pageIds?.slice(),
      pageWidths: config.pageWidths?.slice(),
      pageHeights: config.pageHeights?.slice(),
      sourceRuntimeId: config.sourceRuntimeId,
    }
  }

  private openExternalReaderSession(): void {
    if (this.readerOpen && !this.readerClosing) {
      return
    }
    this.readerOpenEpoch += 1
    this.readerChromeVisible = false
    this.readerSessionLoading = false
    this.readerSessionConfig = this.cloneExternalReaderSession(MOCK_LIBRARY_READER_SESSION)
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

  private openReaderMangaDetail(): void {
    const comicId = this.readerSessionConfig.comicId
    if (comicId.length === 0 || !this.isReaderRouteVisible()) {
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
    this.appPathStack.pushPath({ name: RouteName.IMPORT })
  }

  private openSettingsSecondary(routeName: string): void {
    this.appPathStack.pushPath({ name: routeName })
  }

  private openSettingsPane(pane: SettingsPaneKey): void {
    const routeParam: SettingsPaneRouteParam = { pane: pane }
    this.appPathStack.pushPath({ name: RouteName.SETTINGS_PANE, param: routeParam })
  }

  private selectRootTab(index: number): void {
    this.selectedTab = index
    this.tabController.changeIndex(index)
  }

  private openSearchQuery(query: string): void {
    const normalizedQuery = query.trim()
    if (normalizedQuery.length === 0) {
      return
    }
    if (this.readerOpen) {
      this.closeReader()
    }
    this.appPathStack.clear()
    this.searchRouteQuery = normalizedQuery
    this.searchRouteSerial += 1
    this.selectRootTab(TabIndex.SEARCH)
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
    RouterHelper.setAppPathStack(this.appPathStack)
    RouterHelper.setSearchOpener((param) => {
      this.openSearchQuery(param.query)
    })
    RouterHelper.setReaderOpener(() => {
      this.openExternalReaderSession()
    })
    RouterHelper.consumePendingLaunchRoute()
    const context = getContext(this) as common.UIAbilityContext
    if (!this.readerSessionPersistenceReady && context.filesDir !== undefined && context.filesDir.length > 0) {
      try {
        this.readerSessionStore = new PersistentReaderSessionStore(
          new AppFilesReaderSessionPersistenceAdapter(context.filesDir),
        )
        this.readerSessionPersistenceReady = true
      } catch (_error) {
        console.warn('[Reader] step=restore_progress_failed reason=session_store')
      }
    }
    configureSourceSettingsStore(context)
    configureSourceFilterPreferencesStore(context)
    bootstrapSourceRuntimeAppRegistry(context)
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
    this.triggerAutomaticBackup(context)
    this.triggerPendingTrackerProgressSync(context)
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
  private AppDestination(name: string, param: Object) {
    if (name === RouteName.READER) {
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
    } else if (name === RouteName.MANGA_DETAIL) {
      HdsNavDestination() {
        MangaDetailPage({
          params: param as MangaDetailRouteParam,
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          readerSessionStore: this.readerSessionStore,
          sourceRegistry: this.sourceRegistry,
          onBack: () => {
            this.appPathStack.pop(this.isReaderDetailRouteVisible())
          },
          onOpenReader: (mangaId: string, chapterId?: string) => { void this.openReader(mangaId, chapterId) },
          onOpenImportRequested: () => { this.openImport() },
          onLibraryChanged: () => { this.refreshLibrarySnapshot() }
        })
      }
      .titleBar(this.navDestTitleBarOpts(this.mangaDetailTitle(param as MangaDetailRouteParam)))
    } else if (name === RouteName.SOURCE_BROWSE) {
      HdsNavDestination() {
        SourceBrowsePage({
          source: (param as SourceRouteParam).source,
          onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => {
            RouterHelper.pushSourceSearch({ source: source })
          },
          onMangaTap: (manga: SourceManga) => {
            RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts((param as SourceRouteParam).source.displayName))
    } else if (name === RouteName.SOURCE_SEARCH) {
      HdsNavDestination() {
        SourceSearchPage({
          source: (param as SourceRouteParam).source,
          onMangaTap: (manga: SourceManga) => {
            RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
          },
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('tab_search')))
    } else if (name === RouteName.KOMGA_BROWSE) {
      HdsNavDestination() {
        KomgaSeriesPage({
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
        BackupManagementPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_backup_management_title')))
    } else if (name === RouteName.TRACKER_SETTINGS) {
      HdsNavDestination() {
        TrackerSettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_tracker_settings_title')))
    }
  }

  onBackPress(): boolean {
    if (this.readerOpen && this.isReaderRouteVisible()) {
      this.closeReader()
      return true
    }
    return false
  }

  build() {
    Stack() {
      if (this.languageState.effectiveLocale.length >= 0) {
        HdsNavigation(this.appPathStack) {
          HdsTabs({ controller: this.tabController }) {
            TabContent() {
              LibraryPage({
                libraryStore: this.libraryStore,
                libraryComics: this.libraryComics,
                libraryRevision: this.libraryRevision,
                presentationByComicId: this.presentationByComicId,
                sourceRegistry: this.sourceRegistry,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                },
                onImportRequested: () => {
                  this.openImport()
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
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.HISTORY), TabIndex.HISTORY))

            TabContent() {
              SearchPage({
                externalQuery: this.searchRouteQuery,
                externalQuerySerial: this.searchRouteSerial,
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onLibraryChanged: () => {
                  this.refreshLibrarySnapshot()
                  this.selectRootTab(TabIndex.LIBRARY)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.SEARCH), TabIndex.SEARCH))

            TabContent() {
              SettingsPage({
                pane: 'root',
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
            this.selectedTab = index
          })
        }
        .titleBar(this.titleBarOptions())
        .titleMode(HdsNavigationTitleMode.MINI)
        .hideBackButton(true)
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': tabLabel(this.selectedTab) }
    let content: Record<string, Object> = { 'title': titleInfo }
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

}
