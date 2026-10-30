import { comicFromSourceManga, sourceLibraryComicId } from '../model/SourceLibraryComic'
import { canMigrateLibraryComic } from '../model/SourceMangaMigration'
import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { komaMenuOptions, komaSheetOptions } from '../theme/KomaPopupOptions'
import { SourceWebSessionSheet } from '../components/SourceWebSessionSheet'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { prepareSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { SourceWebChallengeGate, SourceWebChallengeReceipt } from '../sourceRuntime/SourceWebChallengeGate'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { firstReaderChapter } from '../model/ReaderChapterSequence'
import { SourceRuntimeError } from '../model/SourceRuntimeError'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { reconcileSourceChapterIdentity } from '../model/SourceChapterIdentity'
import { protectedSourceChapterIds } from '../model/SourceChapterIdentityGuard'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { trackerChapterProgress, trackerChapterForProgress } from '../model/TrackerReadingProgress'
import { mangaHttpUrl } from '../model/MangaWebLink'
import { MangaDetailHeader } from '../components/MangaDetailHeader'
import { CachedCoverImage } from '../components/CachedCoverImage'
import { ColorMetrics } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { MangaDescriptionSection } from '../components/MangaDescriptionSection'
import { MangaTagsSection } from '../components/MangaTagsSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { PullRefresh, PullRefreshController } from '../components/PullRefresh'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import {
  ChapterBatchDownloadMode,
  ChapterBatchScope,
  ChapterListSection,
} from '../components/ChapterListSection'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import {
  MangaChapterItem,
  MangaDetail,
  MangaStatus,
  parseMangaChapterFromSourceItem,
  parseMangaDetailFromSourceItem,
} from '../model/MangaDetailModels'
import { sourceMangaDetailSnapshotCache } from '../model/SourceMangaDetailSnapshotCache'
import { sourceChapterDisplayRows } from '../model/SourceChapterVisibility'
import { resolveSourceChapterList } from '../model/SourceChapterListResolver'
import { ReaderChapterDescriptor, cloneReaderChapterDescriptor } from '../model/ReaderChapterSequence'
import {
  Chapter,
  Comic,
  sameComicIdentity,
  ComicSourceKind,
  ReadingDirection,
  ReadingProgress,
  updateReadingProgress,
  normalizeSortKey,
} from '../model/ComicModels'
import { OfflineDownloadService } from '../model/OfflineDownloadService'
import {
  OfflineDownloadStatus,
  OfflineDownloadStore,
  OfflineDownloadSummary,
} from '../model/OfflineDownloadStore'
import { LibraryStore } from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  removeComicRecordAndPersistLibraryStore,
  updateLocalLibraryMetadataAndPersistLibraryStore,
  upsertComicAndPersistLibraryStore,
  refreshSourceMangaDetailAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import {
  LocalLibraryMetadataStatus,
  LocalLibraryStoredMetadata,
} from '../model/LocalLibraryMetadataService'
import {
  LocalLibraryFolderRescanActionResult,
  LocalLibraryRefreshComicResult,
  LocalLibraryRefreshService,
  formatLocalLibraryFolderRescanActionResult,
} from '../model/LocalLibraryRefreshService'
import { canRescanLocalLibraryFolder } from '../model/LocalLibraryFolderAccessService'
import {
  SourceChapterPageHydrationResult,
  SourceChapterPageHydrator,
} from '../model/SourceChapterPageHydrator'
import { SourceManga } from '../model/SourceModels'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
  sourceRuntimeEntryEnabled,
} from '../sourceRuntime/SourceRuntimeRegistry'
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { executeSourceRequestInWorker as executeMangaDetailSourceOperation } from '../sourceRuntime/SourceRuntimeWorkerClient'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
  configureSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { sourceSettingsFingerprint } from '../sourceRuntime/SourceSettingsIdentity'
import {
  InMemoryReaderSessionStore,
  ReaderSessionConfig,
  ReaderSessionStore,
  ChapterReadMutation,
  createReaderSessionConfigFromComic,
} from '../model/ReaderSessionStore'
import { SourceReaderSessionRequest } from '../model/SourceReaderSession'
import {
  TrackerProgressSyncResult,
  TrackerProgressSyncReason,
  TrackerProgressSyncService,
} from '../model/TrackerProgressSyncService'
import { RouterHelper } from '../common/RouterHelper'
import { MangaDetailRouteChromeState, MangaDetailTitleAction } from '../state/MangaDetailRouteChromeState'
import {
  TrackerMappingSearchReason,
  TrackerMappingSearchService,
  TrackerMappingSearchSummary,
} from '../model/TrackerMappingSearchService'

export const MANGA_DETAIL_ROUTE_NAME: string = 'MangaDetailPage'

interface MangaDetailRouteParams {
  mangaId?: string
  sourceId?: string
  initialManga?: SourceManga
}

interface SourceOperationDataPayload {
  manga?: Record<string, Object>
  item?: Record<string, Object>
  items?: Record<string, Object>[]
  chapters?: Record<string, Object>[]
  chapterContext?: Record<string, Object>
  pages?: Record<string, Object>[]
  page?: SourceRuntimePagePayload
  hasNextPage?: boolean
  hasMore?: boolean
  has_more?: boolean
}

interface SourceRuntimePagePayload {
  hasMore?: boolean
  hasNextPage?: boolean
  has_more?: boolean
  nextCursor?: string | null
  next_cursor?: string | null
}

interface SourceOperationResponsePayload {
  ok?: boolean
  data?: SourceOperationDataPayload
}

interface SourceMangaDetailLoadResult {
  detail: MangaDetail
  embeddedChapters: MangaChapterItem[]
  chapterContext?: Record<string, Object>
}

interface SourceMangaRequestArgs {
  mangaId: string
  mangaUrl?: string
}

interface SourceDetailRequestHostHints {
  network: boolean
}

interface SourceDetailRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceMangaRequestArgs
  settings: SourceSettingsRecord
  hostHints: SourceDetailRequestHostHints
}

function s(name: string): string {
  return AppStrings.get(name)
}

// Keep the native button disabled without multiplying its disabled alpha into
// the explicit disabled palette, matching KomaActionButton's contract.
class DetailDisabledReadContent implements ContentModifier<ButtonConfiguration> {
  label: string
  chapter: string
  page: string

  constructor(label: string, chapter: string, page: string) {
    this.label = label
    this.chapter = chapter
    this.page = page
  }

  applyContent(): WrappedBuilder<[ButtonConfiguration]> {
    return wrapBuilder(detailDisabledReadContent)
  }
}

@Builder
function detailDisabledReadContent(configuration: ButtonConfiguration) {
  Row({ space: ThemeConstants.SPACE_SM }) {
    SymbolGlyph($r('sys.symbol.doc_plaintext'))
      .fontSize(ThemeConstants.FONT_SIZE_HEADING)
      .fontColor([$r('sys.color.font_secondary')])
      .flexShrink(0)
    Text((configuration.contentModifier as DetailDisabledReadContent).label)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(1)
      .flexShrink(0)
    Text(`· ${(configuration.contentModifier as DetailDisabledReadContent).chapter}`)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .flexShrink(1)
    if ((configuration.contentModifier as DetailDisabledReadContent).page.length > 0) {
      Text(`· ${(configuration.contentModifier as DetailDisabledReadContent).page}`)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .flexShrink(0)
    }
  }
  .width('100%')
  .height(ThemeConstants.ACTION_CHIP_HEIGHT)
  .justifyContent(FlexAlign.Center)
  .alignItems(VerticalAlign.Center)
  .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
  .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
  .borderRadius(ThemeConstants.ACTION_CHIP_HEIGHT / 2)
}


enum SourceDetailContentState {
  UNRESOLVED = 'unresolved',
  LOADING = 'loading',
  READY = 'ready',
  ERROR = 'error',
  LOCAL = 'local',
}

@ComponentV2
export struct MangaDetailPage {
  @Param params: MangaDetailRouteParams = {}
  // A detail object is data, not a loading placeholder. A source route may have a real list-row
  // preview before its full detail is resolved, but it must never render a fabricated manga merely
  // because the request has not started yet.
  @Local private manga: MangaDetail | undefined = undefined
  @Local private chapters: MangaChapterItem[] = []
  @Local private isInLibrary: boolean = false
  @Local private sourceDetailContentState: SourceDetailContentState = SourceDetailContentState.UNRESOLVED
  // A route list row is preview data. It is not a resolved detail payload.
  @Local private sourceDetailDataResolved: boolean = false
  private sourceChaptersResolved: boolean = false
  @Local private downloadBusy: boolean = false
  @Local private trackerSyncBusy: boolean = false
  @Local private trackerMappingBusy: boolean = false
  @Local private localRefreshBusy: boolean = false
  @Local private localMetadataEditorVisible: boolean = false
  @Local private localMetadataTitle: string = ''
  @Local private localMetadataAuthors: string = ''
  @Local private localMetadataStatus: LocalLibraryMetadataStatus | 'unknown' = 'unknown'
  @Local private localMetadataCoverPath: string = ''
  @Local private downloadStatusText: string = ''
  @Local private localRefreshText: string = ''
  @Local private feedbackText: string = ''
  @Local private activeLibraryComicId: string = ''
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private detailSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private detailScrollEnabled: boolean = true
  @Local private detailScrollOffset: number = 0
  private detailScroller: Scroller = new Scroller()
  private detailRefreshController: PullRefreshController = new PullRefreshController()
  private detailRefreshTask: Promise<void> | undefined = undefined
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Param readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param readerProgressRevision: number = 0
  @Event onReadingStateChanged: () => void = () => {}
  @Param sourceRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  @Param chrome: MangaDetailRouteChromeState = new MangaDetailRouteChromeState()
  @Event onBack: () => void = () => {}
  @Event onOpenReader: (mangaId: string, chapterId?: string) => void = (_mangaId: string, _chapterId?: string) => {}
  @Event onOpenSourceReader: (request: SourceReaderSessionRequest) => void = (_request: SourceReaderSessionRequest) => {}
  @Event onOpenImportRequested: () => void = () => {}
  @Event onRefreshLocalFolder: (comicId: string) => Promise<LocalLibraryFolderRescanActionResult | undefined> =
    async (_comicId: string) => undefined
  @Event onLibraryChanged: () => void = () => {}
  @Event onMigrationRequested: (comicId: string) => void = () => {}
  @Local private detailWebChallenge: SourceWebChallengeReceipt | null = null
  @Local private detailWebChallengeShown: boolean = false
  @Local private detailWebChallengeParams: MangaWebRouteParam = { url: '', title: '' }
  private detailWebChallengeGate: SourceWebChallengeGate = new SourceWebChallengeGate()
  private detailWebChallengeId: number = 0
  private detailWebChallengeClosing: boolean = false

  private clearDetailWebChallenge(): void {
    this.detailWebChallengeGate.clear()
    this.detailWebChallenge = null
  }

  @Monitor('chrome.visible', 'detailWebChallenge')
  private handleDetailWebChallenge(): void {
    if (!this.chrome.visible) { this.closeDetailWebChallenge(); return }
    if (this.detailWebChallengeShown || this.detailWebChallengeClosing) return
    const receipt = this.detailWebChallenge
    if (receipt === null || receipt.sourceId !== this.params.sourceId?.trim() ||
      !this.detailWebChallengeGate.claim(receipt.id, this.chrome.visible)) return
    const params = prepareSourceWebSession(receipt.sourceId, sourceDisplayName(receipt.sourceId, this.sourceDetailRegistryEntry?.manifestName ?? ''))
    if (params === undefined) {
      this.detailWebChallengeGate.cancel(receipt.id)
      this.detailWebChallenge = null
      return
    }
    this.detailWebChallengeId = receipt.id
    if (params.sourceSession !== undefined) params.sourceSession.allowClearanceRetry = receipt.allowClearanceRetry
    this.detailWebChallengeParams = params
    this.detailWebChallengeShown = true
  }

  private closeDetailWebChallenge(): void {
    if (this.detailWebChallengeShown) this.detailWebChallengeClosing = true
    const id = this.detailWebChallengeId
    const session = this.detailWebChallengeParams.sourceSession
    // Consume this sheet's receipt before callbacks or session cancellation can run.
    this.detailWebChallengeId = 0
    this.detailWebChallengeShown = false
    if (id > 0) {
      this.detailWebChallengeGate.cancel(id)
      if (this.detailWebChallenge?.id === id) this.detailWebChallenge = null
      if (session !== undefined) appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
    } else if (!this.detailWebChallengeClosing) this.clearDetailWebChallenge()
  }

  private completeDetailWebChallenge(): void {
    const id = this.detailWebChallengeId
    this.detailWebChallengeClosing = true
    this.detailWebChallengeId = 0
    this.detailWebChallengeShown = false
    if (id <= 0) return
    if (this.detailWebChallenge?.id === id) this.detailWebChallenge = null
    void this.detailWebChallengeGate.complete(id, this.chrome.visible)
  }

  private finishDetailWebChallengeDismiss(): void {
    // The old sheet has fully disappeared. Never cancel mutable params here:
    // a newer challenge may already be waiting for this presentation boundary.
    this.detailWebChallengeClosing = false
    this.handleDetailWebChallenge()
  }

  private publishDetailWebChallenge(error: Object, sourceId: string, mangaId: string, requestEpoch: number,
    retryStage: 'detail' | 'chapters', automaticRecovery: boolean): void {
    const entry = this.sourceDetailRegistryEntry
    const eligible = !automaticRecovery && error instanceof SourceRuntimeError &&
      (error.diagnostic.kind === 'challenge' || error.diagnostic.code === 'auth_required') &&
      entry !== undefined && (entry.webSessionOrigins ?? []).length > 0
    this.detailWebChallenge = this.detailWebChallengeGate.issue(sourceId, 'detail', eligible,
      (): boolean => this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId),
      async (): Promise<void> => { await this.loadSourceMangaDetail(sourceId, mangaId, true, true, retryStage) },
      error instanceof SourceRuntimeError && error.diagnostic.kind === 'challenge')
  }

  @Builder
  private DetailWebChallengeSheet() {
    SourceWebSessionSheet({
      params: this.detailWebChallengeParams,
      autoRetryOnClearance: this.detailWebChallengeParams.sourceSession?.allowClearanceRetry ?? false,
      canProbeOriginal: (): boolean => { return this.chrome.visible && this.detailWebChallengeGate.isCurrentClaim(this.detailWebChallengeId) },
      onClose: () => { this.closeDetailWebChallenge() },
      onCompleted: () => { this.completeDetailWebChallenge() },
    })
  }

  private sourceDetailRequestEpoch: number = 0
  private sourceDetailSettingsRevision: string = ''
  private sourceDetailSettingsFingerprint: string = ''
  private initialDetailLoadStarted: boolean = false
  private sourceDetailRegistryEntry?: SourceRuntimeRegistryEntry
  private handledTitleActionRequestSeq: number = 0

  private formatString(key: string, args: Array<string | number>): string {
    let text = s(key)
    args.forEach((value: string | number) => {
      text = text.replace('%s', `${value}`)
    })
    return text
  }

  private isSourceDetailLoading(): boolean {
    return this.sourceDetailContentState === SourceDetailContentState.LOADING
  }

  private isDetailPending(): boolean {
    return this.sourceDetailContentState === SourceDetailContentState.UNRESOLVED ||
      this.sourceDetailContentState === SourceDetailContentState.LOADING
  }

  private hasResolvedManga(): boolean {
    return this.manga !== undefined
  }

  private shouldRenderChapterList(): boolean {
    return this.manga !== undefined &&
      (this.sourceDetailContentState === SourceDetailContentState.LOCAL ||
        this.sourceDetailContentState === SourceDetailContentState.READY)
  }

  private shouldRenderDetailMetadata(): boolean {
    return this.manga !== undefined &&
      (this.sourceDetailContentState === SourceDetailContentState.LOCAL || this.sourceDetailDataResolved)
  }

  private shouldRenderDetailActions(): boolean {
    // Keep the existing error-state actions and menu behavior. Only a pending
    // request suppresses the row, because its controls cannot yet describe a
    // real chapter result.
    return this.manga !== undefined && !this.isDetailPending()
  }

  private shouldShowChapterCount(): boolean {
    return this.sourceDetailContentState === SourceDetailContentState.LOCAL ||
      this.sourceDetailContentState === SourceDetailContentState.READY
  }

  private canAddCurrentMangaToLibrary(): boolean {
    return this.manga !== undefined &&
      (this.sourceDetailContentState === SourceDetailContentState.LOCAL ||
        this.sourceDetailContentState === SourceDetailContentState.READY)
  }

  aboutToAppear(): void {
    configureSourceSettingsStore(getContext(this) as common.UIAbilityContext)
    this.chrome.showTitle = false
    this.seedSourceDetailFromInitialRouteManga()
    this.syncTitleActions()
    this.loadInitialDetailWhenVisible()
  }

  @Monitor('chrome.visible')
  private loadInitialDetailWhenVisible(): void {
    // The library/memory snapshot supplies the first frame. Start revalidation
    // from the destination's actual shown lifecycle, not an arbitrary delay.
    if (!this.chrome.visible || this.initialDetailLoadStarted) return
    this.initialDetailLoadStarted = true
    void this.loadMangaDetail()
  }

  aboutToDisappear(): void {
    // A hidden detail route must not let an old source response repaint a later route instance.
    this.closeDetailWebChallenge()
    this.clearDetailWebChallenge()
    this.sourceDetailRequestEpoch = this.sourceDetailRequestEpoch + 1
    this.chrome.pageActionsAvailable = false
    this.chrome.sourceReloadAvailable = false
  }

  @Monitor('chrome.actionRequestSeq')
  private consumeTitleActionRequest(): void {
    const requestSeq = this.chrome.actionRequestSeq
    if (requestSeq <= this.handledTitleActionRequestSeq) {
      return
    }
    this.handledTitleActionRequestSeq = requestSeq
    this.runTitleAction(this.chrome.requestedAction)
  }

  @Monitor('manga', 'isInLibrary', 'sourceDetailContentState', 'localRefreshBusy', 'trackerMappingBusy', 'trackerSyncBusy')
  private syncTitleActionsFromDetailState(): void {
    this.syncTitleActions()
  }

  private syncTitleActions(): void {
    if (this.sourceDetailContentState === SourceDetailContentState.LOCAL ||
      this.sourceDetailContentState === SourceDetailContentState.READY) {
      const title = this.manga?.title?.trim() ?? ''
      this.chrome.resolvedTitle = title === s('manga_detail_title_fallback') ? '' : title
    }
    const actionsAvailable = this.shouldRenderDetailActions()
    this.chrome.pageActionsAvailable = actionsAvailable
    this.chrome.sourceReloadAvailable = this.canReloadSourceDetail()
    this.chrome.webActionsAvailable = actionsAvailable && this.mangaWebUrl() !== undefined
    this.chrome.localRefreshAvailable = actionsAvailable && this.canCheckLocalLibraryRefresh()
    this.chrome.localMetadataAvailable = actionsAvailable && this.canEditLocalMetadata()
    this.chrome.migrationAvailable = actionsAvailable && canMigrateLibraryComic(this.libraryStore?.getComic(this.currentComicId()))
    this.chrome.localRefreshBusy = this.localRefreshBusy
    this.chrome.trackerMappingBusy = this.trackerMappingBusy
    this.chrome.trackerSyncBusy = this.trackerSyncBusy
  }

  private mangaWebUrl(): string | undefined {
    const page = mangaHttpUrl(this.manga?.webUrl)
    if (page !== undefined) return page
    // Private-library sourcePath may be a feed/download URL rather than a work page.
    if ((this.manga?.sourceId?.trim() ?? '').length === 0) return undefined
    return mangaHttpUrl(this.manga?.url)
  }

  private canReloadSourceDetail(): boolean {
    return (this.params.sourceId?.trim().length ?? 0) > 0 &&
      (this.params.mangaId?.trim().length ?? 0) > 0
  }

  private canPullRefreshDetail(): boolean {
    return this.canReloadSourceDetail() || this.canCheckLocalLibraryRefresh()
  }

  private refreshMangaDetail(): Promise<void> {
    if (this.detailRefreshTask !== undefined) return this.detailRefreshTask
    const task = this.performDetailRefresh().finally((): void => {
      if (this.detailRefreshTask === task) this.detailRefreshTask = undefined
    })
    this.detailRefreshTask = task
    return task
  }

  private async performDetailRefresh(): Promise<void> {
    if (this.canReloadSourceDetail()) {
      await this.loadSourceMangaDetail(this.params.sourceId!.trim(), this.params.mangaId!.trim(), true)
    } else if (this.canCheckLocalLibraryRefresh()) {
      await this.checkLocalLibraryRefreshNow()
    }
  }

  private runTitleAction(action: MangaDetailTitleAction): void {
    if (action === MangaDetailTitleAction.MIGRATE) {
      const comic = this.libraryStore?.getComic(this.currentComicId())
      if (canMigrateLibraryComic(comic) && comic !== undefined) this.onMigrationRequested(comic.id)
      return
    }
    // Recovery is route-owned and must remain available even before any manga loaded.
    if (action === MangaDetailTitleAction.RELOAD_SOURCE) {
      if (this.canReloadSourceDetail()) {
        void this.refreshMangaDetail()
      }
      return
    }
    if (!this.shouldRenderDetailActions()) {
      return
    }
    if (action === MangaDetailTitleAction.OPEN_WEBVIEW || action === MangaDetailTitleAction.OPEN_BROWSER) {
      const url = this.mangaWebUrl()
      if (url === undefined) return
      if (action === MangaDetailTitleAction.OPEN_WEBVIEW) {
        RouterHelper.pushMangaWeb({ url, title: this.manga?.title ?? '' })
      } else {
        const context = getContext(this) as common.UIAbilityContext
        void context.startAbility({ action: 'ohos.want.action.viewData', uri: url }).catch(() => {
          this.getUIContext().getPromptAction().openToast({ message: s('manga_detail_open_browser_failed') })
        })
      }
      return
    }
    if (action === MangaDetailTitleAction.FIND_TRACKER_MAPPING) {
      void this.refreshTrackerMappingCandidates()
      return
    }
    if (action === MangaDetailTitleAction.SYNC_TRACKER) {
      void this.syncTrackerProgressNow()
      return
    }
    if (action === MangaDetailTitleAction.PULL_TRACKER) {
      void this.pullTrackerProgressNow()
      return
    }
    if (action === MangaDetailTitleAction.CHECK_LOCAL_LIBRARY_REFRESH && this.canCheckLocalLibraryRefresh()) {
      void this.checkLocalLibraryRefreshNow()
      return
    }
    if (action === MangaDetailTitleAction.EDIT_LOCAL_METADATA && this.canEditLocalMetadata()) {
      this.openLocalMetadataEditor()
    }
  }

  private offlineDownloadService(): OfflineDownloadService | undefined {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        return undefined
      }
      return new OfflineDownloadService(new OfflineDownloadStore(context.filesDir), undefined, context)
    } catch (error) {
      void error
      DiagnosticLogger.warn('manga_detail_page', 'detail_service_unavailable', '[ReaderOffline] step=detail_service_unavailable failed=true')
      return undefined
    }
  }

  @Monitor('readerProgressRevision')
  private onReadingStateRevision(): void {
    this.applyChapterStatesToCurrent()
  }

  private decorateChapterStates(chapters: MangaChapterItem[]): MangaChapterItem[] {
    const comicId = this.currentComicId()
    const downloadService = this.offlineDownloadService()
    return chapters.map((chapter: MangaChapterItem): MangaChapterItem => {
      const next: MangaChapterItem = {
        id: chapter.id,
        title: chapter.title,
        chapterNumber: chapter.chapterNumber,
        volumeNumber: chapter.volumeNumber,
        readingOrder: chapter.readingOrder,
        readingGroup: chapter.readingGroup,
        continuationEligible: chapter.continuationEligible,
        scanlator: chapter.scanlator,
        language: chapter.language,
        dateUpload: chapter.dateUpload,
        pageCount: chapter.pageCount,
        isRead: this.readerSessionStore.isChapterRead(comicId, chapter.id),
        isDownloaded: chapter.isDownloaded,
        downloadStatus: chapter.downloadStatus,
      }
      const summary = downloadService?.getChapterSummary(comicId, chapter.id)
      if (summary !== undefined) {
        next.downloadStatus = summary.status
      }
      if (summary?.status === OfflineDownloadStatus.DOWNLOADED || summary?.status === OfflineDownloadStatus.PARTIAL) {
        next.isDownloaded = true
      }
      return next
    })
  }

  private applyChapterStatesToCurrent(): void {
    this.chapters = this.decorateChapterStates(this.chapters)
  }

  private refreshDownloadStatus(): void {
    const service = this.offlineDownloadService()
    const chapterId = this.firstChapterId()
    if (service === undefined || chapterId === undefined) {
      this.downloadStatusText = ''
      return
    }
    this.downloadStatusText = this.formatDownloadStatus(service.getChapterSummary(this.currentComicId(), chapterId))
  }

  private async loadMangaDetail(): Promise<void> {
    const mangaId = this.params.mangaId
    const sourceId = this.params.sourceId
    if (sourceId !== undefined && sourceId.trim().length > 0 &&
      mangaId !== undefined && mangaId.trim().length > 0) {
      await this.loadSourceMangaDetail(sourceId, mangaId)
      return
    }
    this.loadLocalOrMissingManga(mangaId)
  }

  private beginSourceDetailRequest(sourceId: string, mangaId: string): number {
    this.sourceChaptersResolved = false
    this.sourceDetailSettingsRevision = appSourceSettingsStore.revisionForSource(sourceId)
    this.sourceDetailRegistryEntry = undefined
    this.sourceDetailRequestEpoch = this.sourceDetailRequestEpoch + 1
    return this.sourceDetailRequestEpoch
  }

  private isCurrentSourceDetailRequest(requestEpoch: number, sourceId: string, mangaId: string): boolean {
    return this.sourceDetailRequestEpoch === requestEpoch &&
      appSourceSettingsStore.revisionForSource(sourceId) === this.sourceDetailSettingsRevision &&
      this.sourceRegistry.lookup(sourceId).entry === this.sourceDetailRegistryEntry &&
      this.params.sourceId?.trim() === sourceId.trim() &&
      this.params.mangaId?.trim() === mangaId.trim()
  }

  private loadLocalOrMissingManga(mangaId?: string): void {
    const comic = mangaId === undefined || this.libraryStore === undefined ? undefined : this.libraryStore.getComic(mangaId)
    if (comic === undefined) {
      // The sentinel is only a definitive invalid/missing local route. It is never used as a source
      // request's initial or failure value.
      this.manga = missingMangaDetail(mangaId, this.params.sourceId)
      this.chapters = []
      this.isInLibrary = false
      this.sourceDetailDataResolved = false
      this.activeLibraryComicId = ''
      this.feedbackText = mangaId === undefined || mangaId.trim().length === 0 ? '' : s('manga_detail_load_local_failed')
      this.sourceDetailContentState = SourceDetailContentState.ERROR
      this.downloadStatusText = ''
      this.localRefreshText = ''
      return
    }
    this.activeLibraryComicId = comic.id
    this.manga = mangaDetailFromComic(comic, this.sourceRegistry)
    this.chapters = this.decorateChapterStates(
      comic.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter, comic.sourceKind))
    )
    this.isInLibrary = true
    this.sourceDetailDataResolved = true
    this.sourceDetailContentState = SourceDetailContentState.LOCAL
    this.feedbackText = ''
    this.localRefreshText = ''
    this.refreshDownloadStatus()
  }

  private canEditLocalMetadata(): boolean {
    const comic = this.libraryStore?.getComic(this.currentComicId())
    return comic !== undefined &&
      (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER)
  }

  private canEditLocalCoverPath(): boolean {
    const comic = this.libraryStore?.getComic(this.currentComicId())
    return comic?.sourceKind === ComicSourceKind.LOCAL_FOLDER
  }

  private openLocalMetadataEditor(): void {
    const comic = this.libraryStore?.getComic(this.currentComicId())
    if (comic === undefined) {
      this.showToast(s('manga_detail_local_metadata_unavailable'))
      return
    }
    this.localMetadataTitle = comic.localMetadata?.titleOverride ?? comic.title
    this.localMetadataAuthors = comic.localMetadata?.authors?.join(', ') ?? comic.author ?? ''
    this.localMetadataStatus = comic.localMetadata?.status ?? 'unknown'
    this.localMetadataCoverPath = comic.localMetadata?.coverOverridePath ?? ''
    this.localMetadataEditorVisible = true
  }

  private localMetadataStatusLabel(status: LocalLibraryMetadataStatus | 'unknown'): string {
    if (status === 'ongoing') {
      return s('manga_status_ongoing')
    }
    if (status === 'completed') {
      return s('manga_status_completed')
    }
    if (status === 'hiatus') {
      return s('manga_status_hiatus')
    }
    if (status === 'cancelled') {
      return s('manga_status_cancelled')
    }
    return s('manga_status_unknown')
  }

  private localMetadataAuthorsList(): string[] | undefined {
    const authors: string[] = []
    this.localMetadataAuthors.split(/[,;\u3001]/).forEach((item: string): void => {
      const normalized = item.trim().replace(/\s+/g, ' ')
      if (normalized.length > 0 && !authors.includes(normalized)) {
        authors.push(normalized)
      }
    })
    return authors.length === 0 ? undefined : authors
  }

  private buildLocalMetadataOverride(): LocalLibraryStoredMetadata {
    const metadata: LocalLibraryStoredMetadata = {}
    const title = this.localMetadataTitle.trim().replace(/\s+/g, ' ')
    if (title.length > 0) {
      metadata.titleOverride = title
    }
    const authors = this.localMetadataAuthorsList()
    if (authors !== undefined) {
      metadata.authors = authors
    }
    if (this.localMetadataStatus !== 'unknown') {
      metadata.status = this.localMetadataStatus
    }
    const coverPath = this.localMetadataCoverPath.trim()
    if (coverPath.length > 0 && this.canEditLocalCoverPath()) {
      metadata.coverOverridePath = coverPath
    }
    return metadata
  }

  private saveLocalMetadataOverride(): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('manga_detail_local_metadata_unavailable'))
      return
    }
    try {
      const updated = updateLocalLibraryMetadataAndPersistLibraryStore(
        this.libraryStore,
        this.libraryPersistenceService,
        this.currentComicId(),
        this.buildLocalMetadataOverride(),
      )
      if (updated === undefined) {
        this.showToast(s('manga_detail_local_metadata_unavailable'))
        return
      }
      this.manga = mangaDetailFromComic(updated, this.sourceRegistry)
      this.chapters = this.decorateChapterStates(
        updated.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter, updated.sourceKind))
      )
      this.localMetadataEditorVisible = false
      this.feedbackText = s('manga_detail_local_metadata_saved')
      this.onLibraryChanged()
      this.showToast(s('manga_detail_local_metadata_saved'))
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'save_failed', '[LocalMetadata] step=save_failed failed=true reason=metadata_validation')
      this.showToast(s('manga_detail_local_metadata_save_failed'))
    }
  }

  private resetLocalMetadataEditor(): void {
    this.localMetadataTitle = ''
    this.localMetadataAuthors = ''
    this.localMetadataStatus = 'unknown'
    this.localMetadataCoverPath = ''
  }

  private async loadSourceMangaDetail(sourceId: string, mangaId: string, forceReload: boolean = false,
    automaticRecovery: boolean = false, retryStage: 'detail' | 'chapters' = 'detail'): Promise<void> {
    this.closeDetailWebChallenge()
    this.clearDetailWebChallenge()
    const retainedDetail = this.sourceDetailDataResolved ? this.manga : undefined
    // Automatic revalidation must not interrupt a readable collected detail
    // with loading/error text or a verification sheet. Explicit refresh keeps
    // its existing progress and challenge/recovery behavior.
    const backgroundRefresh = !forceReload && retainedDetail !== undefined
    const retainedChapters = retainedDetail === undefined ? [] : this.chapters.slice()
    const retainedChaptersResolved = this.sourceChaptersResolved
    const retainedState = this.isDetailPending() ? SourceDetailContentState.READY : this.sourceDetailContentState
    const requestEpoch = this.beginSourceDetailRequest(sourceId, mangaId)
    if (retainedDetail === undefined) {
      this.sourceDetailContentState = SourceDetailContentState.LOADING
      this.sourceDetailDataResolved = false
      this.feedbackText = s('manga_detail_loading_source')
    } else {
      this.sourceDetailContentState = retainedState
      this.sourceChaptersResolved = retainedChaptersResolved
      this.feedbackText = ''
    }
    try {
      const lookup = this.sourceRegistry.lookup(sourceId)
      if (!lookup.ok || lookup.entry === undefined) {
        throw new Error(lookup.reasonCode ?? 'source lookup failed')
      }
      this.sourceDetailRegistryEntry = lookup.entry
      if (!sourceRuntimeEntryEnabled(lookup.entry)) {
        throw new Error('source_disabled')
      }
      this.sourceDetailSettingsFingerprint = sourceSettingsFingerprint(appSourceSettingsStore.loadForSource(sourceId))
      const cached = forceReload ? undefined : sourceMangaDetailSnapshotCache.read(lookup.entry, sourceId, mangaId, this.sourceMangaRouteUrl(sourceId, mangaId))
      let detail: MangaDetail
      let chapters: MangaChapterItem[]
      // This value belongs only to the freshly loaded detail request. It must
      // never enter the persisted snapshot or an unrelated chapter recovery.
      let chapterContext: Record<string, Object> | undefined = undefined
      let excludedChapterIds: string[] = []
      if (retryStage === 'chapters' && retainedDetail !== undefined) {
        detail = retainedDetail
        chapters = retainedChapters
      } else {
        const loaded = await this.runSourceMangaOperation(lookup.entry, 'get_manga', mangaId)
        if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
          return
        }
        detail = this.sourceDetailWithRouteIdentity(loaded.detail, sourceId, mangaId)
        chapterContext = loaded.chapterContext
        chapters = loaded.embeddedChapters.length > 0 ? loaded.embeddedChapters : retainedChapters
      }
      // The detail payload is already real data. Keep it visible while the
      // independent chapter request is pending instead of representing this
      // as an empty detail or a fabricated zero-chapter result.
      const detailApplied = retainedDetail !== undefined || this.applySourceMangaDetail(
        requestEpoch,
        lookup.entry,
        sourceId,
        mangaId,
        detail,
        chapters,
        '',
        retainedDetail === undefined ? SourceDetailContentState.LOADING : SourceDetailContentState.READY,
      )
      if (!detailApplied) {
        return
      }
      if (cached === undefined && retainedDetail === undefined) {
        sourceMangaDetailSnapshotCache.write(lookup.entry, sourceId, mangaId, {
          detail,
          chapters,
          chaptersResolved: false,
        }, this.sourceDetailSettingsRevision)
      }
      let chaptersLoadFailed = false
      let chaptersFailureText = s('manga_detail_load_source_chapters_failed')
      try {
        const chapterResult = await resolveSourceChapterList(lookup.entry, mangaId, detail.url,
          (): boolean => this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId), chapterContext)
        if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
          return
        }
        chaptersLoadFailed = !chapterResult.resolved
        excludedChapterIds = chapterResult.resolved ? chapterResult.excludedChapterIds ?? [] : []
        this.sourceChaptersResolved = chapterResult.resolved &&
          (chapterResult.chapters.length > 0 || excludedChapterIds.length > 0)
        if (chapterResult.chapters.length > 0 || (chapterResult.resolved && (forceReload || excludedChapterIds.length > 0))) {
          chapters = chapterResult.chapters
        }
      } catch (_error) {
        if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
          return
        }
        chaptersLoadFailed = true
        chaptersFailureText = this.sourceOperationFailureText(_error, 'get_chapters', 'manga_detail_load_source_chapters_failed')
        if (!backgroundRefresh) {
          this.publishDetailWebChallenge(_error, sourceId, mangaId, requestEpoch, 'chapters', automaticRecovery)
        }
        const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, this.sourceComicId(sourceId, mangaId))
        if (libraryComic !== undefined && libraryComic.chapters.length > 0) {
          chapters = libraryComic.chapters.map((chapter: Chapter): MangaChapterItem =>
            mangaChapterItemFromComicChapter(chapter, libraryComic.sourceKind))
        }
      }
      if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
        return
      }
      if (chaptersLoadFailed && backgroundRefresh) {
        this.sourceChaptersResolved = retainedChaptersResolved
        return
      }
      if (!chaptersLoadFailed) {
        detail.chapterCount = chapters.length
        detail.sourceName = lookup.entry.manifestName
      }
      const applied = this.applySourceMangaDetail(
        requestEpoch,
        lookup.entry,
        sourceId,
        mangaId,
        detail,
        chapters,
        chaptersLoadFailed && !backgroundRefresh ? chaptersFailureText : '',
        chaptersLoadFailed && chapters.length === 0
          ? SourceDetailContentState.ERROR
          : SourceDetailContentState.READY,
        !chaptersLoadFailed && this.sourceChaptersResolved,
        excludedChapterIds,
      )
      if (applied && (chaptersLoadFailed || !this.sourceChaptersResolved)) {
        this.refreshSourceLibraryDetail(sourceId, mangaId, detail, chapters,
          !chaptersLoadFailed && this.sourceChaptersResolved, excludedChapterIds)
      }
      if (applied && !chaptersLoadFailed) {
        sourceMangaDetailSnapshotCache.write(lookup.entry, sourceId, mangaId, {
          detail,
          chapters,
          chaptersResolved: this.sourceChaptersResolved,
          excludedChapterIds,
        }, this.sourceDetailSettingsRevision)
      }
    } catch (error) {
      if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
        return
      }
      const failureText = this.sourceOperationFailureText(error, 'get_manga', 'manga_detail_load_source_failed')
      if (!backgroundRefresh) {
        this.publishDetailWebChallenge(error, sourceId, mangaId, requestEpoch, 'detail', automaticRecovery)
      }
      if (retainedDetail !== undefined) {
        this.manga = retainedDetail
        this.chapters = retainedChapters
        this.sourceDetailDataResolved = true
        this.sourceChaptersResolved = retainedChaptersResolved
        this.sourceDetailContentState = retainedState
        this.feedbackText = backgroundRefresh ? '' : failureText
        return
      }
      const fallbackDetail = this.sourceDetailFromInitialRouteManga(sourceId, mangaId)
      const fallbackComicId = this.sourceComicId(sourceId, mangaId)
      const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, fallbackComicId)
      if (libraryComic !== undefined) {
        this.loadLocalOrMissingManga(libraryComic.id)
        this.feedbackText = failureText
        return
      }
      if (fallbackDetail !== undefined) {
        fallbackDetail.isInLibrary = false
        this.manga = fallbackDetail
      } else {
        this.manga = undefined
      }
      this.chapters = []
      this.isInLibrary = false
      this.sourceDetailDataResolved = false
      this.activeLibraryComicId = ''
      this.feedbackText = failureText
      this.sourceDetailContentState = SourceDetailContentState.ERROR
      this.downloadStatusText = ''
      this.localRefreshText = ''
    }
  }

  private seedSourceDetailFromInitialRouteManga(): void {
    const sourceId = this.params.sourceId?.trim()
    const mangaId = this.params.mangaId?.trim()
    if (sourceId === undefined || sourceId.length === 0 || mangaId === undefined || mangaId.length === 0) {
      return
    }
    const comicId = this.sourceComicId(sourceId, mangaId)
    const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, comicId)
    const lookup = this.sourceRegistry.lookup(sourceId)
    const cached = lookup.entry === undefined ? undefined : sourceMangaDetailSnapshotCache.read(
      lookup.entry, sourceId, mangaId, this.sourceMangaRouteUrl(sourceId, mangaId))
    if (cached !== undefined && cached.chaptersResolved) {
      this.manga = cached.detail
      this.manga.isInLibrary = libraryComic !== undefined
      const stored = libraryComic?.chapters.map((ch: Chapter): MangaChapterItem =>
        mangaChapterItemFromComicChapter(ch, libraryComic.sourceKind)) ?? []
      this.chapters = this.decorateChapterStates(sourceChapterDisplayRows(cached.chapters, stored, cached.excludedChapterIds))
      this.manga.chapterCount = this.chapters.length
      this.activeLibraryComicId = libraryComic?.id ?? ''
      this.isInLibrary = libraryComic !== undefined
      this.sourceDetailDataResolved = true
      this.sourceChaptersResolved = true
      this.sourceDetailContentState = SourceDetailContentState.READY
      this.feedbackText = ''
      return
    }
    if (libraryComic !== undefined) {
      this.activeLibraryComicId = libraryComic.id
      this.manga = mangaDetailFromComic(libraryComic, this.sourceRegistry)
      const metadata = libraryComic.sourceMetadata
      let excluded = metadata?.excludedChapterIds ?? []
      if (excluded.length > 0) {
        try {
          const fingerprint = sourceSettingsFingerprint(appSourceSettingsStore.loadForSource(sourceId))
          if (metadata?.settingsFingerprint !== fingerprint) excluded = []
        } catch (error) {
          // Settings read failure does not discard an otherwise readable saved detail.
          DiagnosticLogger.exception('persistence', 'source_detail_settings_read_failed', error as Error)
        }
      }
      this.chapters = this.decorateChapterStates(sourceChapterDisplayRows(
        libraryComic.chapters.map((ch: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(ch, libraryComic.sourceKind)),
        [], excluded))
      this.manga.chapterCount = this.chapters.length
      this.isInLibrary = true
      this.sourceDetailDataResolved = true
      this.sourceDetailContentState = SourceDetailContentState.LOCAL
      this.feedbackText = ''
      return
    }
    const detail = this.sourceDetailFromInitialRouteManga(sourceId, mangaId)
    if (detail === undefined) {
      // A reused destination may previously have rendered another source. With no real list-row
      // preview for this route, start unresolved rather than carrying that prior detail forward.
      this.manga = undefined
      this.chapters = []
      this.isInLibrary = false
      this.sourceDetailDataResolved = false
      this.activeLibraryComicId = ''
      this.sourceDetailContentState = SourceDetailContentState.LOADING
      this.feedbackText = s('manga_detail_loading_source')
      this.downloadStatusText = ''
      this.localRefreshText = ''
      return
    }
    if (lookup.ok && lookup.entry !== undefined) {
      detail.sourceName = lookup.entry.manifestName
    }
    detail.isInLibrary = false
    this.manga = detail
    this.chapters = []
    this.isInLibrary = false
    this.sourceDetailDataResolved = false
    this.activeLibraryComicId = ''
    this.sourceDetailContentState = SourceDetailContentState.LOADING
    this.feedbackText = s('manga_detail_loading_source')
    this.downloadStatusText = ''
    this.localRefreshText = ''
  }

  private refreshSourceLibraryDetail(sourceId: string, mangaId: string, detail: MangaDetail,
    chapters: MangaChapterItem[], chaptersResolved: boolean, excludedChapterIds: string[]): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) return
    const comic = this.findSourceRuntimeComic(sourceId, mangaId, this.sourceComicId(sourceId, mangaId))
    if (comic === undefined) return
    try {
      if (refreshSourceMangaDetailAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService,
        comic.id, sourceId, mangaId, detail, chapters, chaptersResolved, excludedChapterIds,
        this.sourceDetailSettingsFingerprint)) {
        this.onLibraryChanged()
      }
    } catch (error) {
      DiagnosticLogger.exception('persistence', 'source_detail_refresh_failed', error as Error)
    }
  }

  private applySourceMangaDetail(
    requestEpoch: number,
    entry: SourceRuntimeRegistryEntry,
    sourceId: string,
    mangaId: string,
    detail: MangaDetail,
    chapters: MangaChapterItem[],
    feedbackText: string,
    contentState: SourceDetailContentState = SourceDetailContentState.READY,
    persistResolvedChapterMetadata: boolean = false,
    excludedChapterIds: string[] = [],
  ): boolean {
    if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
      return false
    }
    const nextDetail = this.sourceDetailWithRouteIdentity(detail, sourceId, mangaId)
    const comicId = this.sourceComicId(sourceId, mangaId)
    const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, comicId)
    this.activeLibraryComicId = libraryComic?.id ?? ''
    const identity = libraryComic !== undefined && this.sourceChaptersResolved
      ? reconcileSourceChapterIdentity(libraryComic, mangaId, chapters,
        protectedSourceChapterIds(libraryComic, (getContext(this) as common.UIAbilityContext).filesDir, this.readerSessionStore))
      : undefined
    if (persistResolvedChapterMetadata && this.sourceChaptersResolved) {
      this.refreshSourceLibraryDetail(sourceId, mangaId, detail, identity?.chapters ?? chapters, true, excludedChapterIds)
    }
    const retainedChapters: MangaChapterItem[] = []
    if (libraryComic !== undefined) {
      (identity?.storedChapters ?? libraryComic.chapters).forEach((chapter: Chapter): void => {
        retainedChapters.push(mangaChapterItemFromComicChapter(chapter, libraryComic.sourceKind))
      })
    }
    const displayedChapters = sourceChapterDisplayRows(identity?.chapters ?? chapters, retainedChapters, excludedChapterIds)
    nextDetail.chapterCount = displayedChapters.length
    nextDetail.isInLibrary = libraryComic !== undefined
    nextDetail.sourceName = entry.manifestName
    this.manga = nextDetail
    this.chapters = this.decorateChapterStates(displayedChapters)
    this.isInLibrary = nextDetail.isInLibrary
    this.sourceDetailDataResolved = true
    this.feedbackText = feedbackText
    this.sourceDetailContentState = contentState
    this.refreshDownloadStatus()
    return true
  }

  private sourceOperationFailureText(error: Object, operation: string, fallbackKey: string): string {
    if (error instanceof SourceRuntimeError) {
      const details = error.diagnostic
      DiagnosticLogger.warn('manga_detail_page', 'source_operation_failed',
        'operation=' + operation + ' reason=' + details.reason + ' error=' + details.code +
        ' http=' + details.status + ' kind=' + details.kind)
      return s(fallbackKey) + ' ' + error.userText
    }
    // Unexpected exceptions may contain URLs or credentials. Keep the phase, never their raw message.
    DiagnosticLogger.warn('manga_detail_page', 'source_operation_failed', 'operation=' + operation + ' reason=unexpected_failure')
    return s(fallbackKey)
  }

  private async runSourceMangaOperation(
    entry: SourceRuntimeRegistryEntry,
    operation: string,
    mangaId: string
  ): Promise<SourceMangaDetailLoadResult> {
    const args: SourceMangaRequestArgs = { mangaId, mangaUrl: this.sourceMangaRouteUrl(entry.sourceId, mangaId) }
    const request = this.buildSourceDetailRequestJson(entry.sourceId, operation, args, { network: true })
    const responseJson = await diagnoseSourceOperation(request, () => executeMangaDetailSourceOperation(
      request,
      this.copyWasmBytes(entry),
      sourceHttpIdentityJson(entry, undefined, operation === 'get_manga', operation),
    ))
    const runtimeResponse = JSON.parse(responseJson) as SourceRuntimeCallResponse
    if (runtimeResponse.ok !== true) {
      throw new SourceRuntimeError(runtimeResponse)
    }
    const response = runtimeResponse as SourceOperationResponsePayload
    const item = this.sourceMangaResponseItem(response)
    if (item === undefined) {
      const invalidResponse: SourceRuntimeCallResponse = { ok: false, reasonCode: 'invalid_response' }
      throw new SourceRuntimeError(invalidResponse)
    }
    const context = response.data?.chapterContext
    return {
      detail: parseMangaDetailFromSourceItem(entry.sourceId, item),
      embeddedChapters: this.sourceEmbeddedChapterItems(response, item)
        .map((chapter: Record<string, Object>): MangaChapterItem => parseMangaChapterFromSourceItem(chapter)),
      chapterContext: context !== undefined && context !== null && typeof context === 'object' && !Array.isArray(context)
        ? context : undefined,
    }
  }

  private sourceDetailWithRouteIdentity(
    detail: MangaDetail,
    sourceId: string,
    mangaId: string,
  ): MangaDetail {
    const normalizedMangaId = mangaId.trim()
    const initialManga = this.validInitialRouteManga(sourceId, mangaId)
    const next: MangaDetail = {
      id: normalizedMangaId.length > 0 ? normalizedMangaId : detail.id,
      title: this.firstRouteDetailText([detail.title, initialManga?.title]) ?? detail.title,
      author: this.firstRouteDetailText([detail.author, initialManga?.author]),
      artist: this.firstRouteDetailText([detail.artist, initialManga?.artist]),
      description: this.firstRouteDetailText([detail.description, initialManga?.description]),
      coverUrl: detail.coverUrl ?? initialManga?.coverUrl,
      status: detail.status === undefined || detail.status === MangaStatus.UNKNOWN ?
        this.mangaStatusFromSourceStatus(initialManga?.status) :
        detail.status,
      tags: detail.tags ?? initialManga?.tags,
      sourceId,
      sourceImageId: normalizedMangaId.length > 0 ? normalizedMangaId : (detail.sourceImageId ?? detail.id),
      sourceName: detail.sourceName,
      chapterCount: detail.chapterCount,
      isInLibrary: detail.isInLibrary,
      url: detail.url ?? this.sourceMangaRouteUrl(sourceId, mangaId),
      webUrl: detail.webUrl ?? initialManga?.webUrl,
    }
    return next
  }

  private sourceMangaRouteUrl(sourceId: string, mangaId: string): string | undefined {
    const current = this.manga
    const initial = this.validInitialRouteManga(sourceId, mangaId)
    const stored = this.findSourceRuntimeComic(sourceId, mangaId, this.sourceComicId(sourceId, mangaId))
    // A direct shelf lookup can return another owner. Only its matching source/work may supply a route.
    const storedRoute = stored?.sourceRuntimeId === sourceId && stored?.remoteResourceId === mangaId
      ? stored.sourcePath : undefined
    const currentRoute = current?.sourceId === sourceId && current?.id === mangaId ? current.url : undefined
    const routes: Array<string | undefined> = [currentRoute, initial?.url, storedRoute]
    for (let index = 0; index < routes.length; index += 1) {
      const route = routes[index]?.trim()
      if (route !== undefined && (route.startsWith('https://') || route.startsWith('http://'))) {
        return route
      }
    }
    return undefined
  }

  private firstRouteDetailText(values: Array<string | undefined>): string | undefined {
    for (let index = 0; index < values.length; index += 1) {
      const value = values[index]?.trim()
      if (value !== undefined && value.length > 0) {
        return value
      }
    }
    return undefined
  }

  private mangaStatusFromSourceStatus(status: string | undefined): MangaStatus | undefined {
    if (status === 'ongoing') {
      return MangaStatus.ONGOING
    }
    if (status === 'completed') {
      return MangaStatus.COMPLETED
    }
    if (status === 'hiatus') {
      return MangaStatus.HIATUS
    }
    if (status === 'cancelled') {
      return MangaStatus.CANCELLED
    }
    return undefined
  }

  private validInitialRouteManga(sourceId: string, mangaId: string): SourceManga | undefined {
    const initialManga = this.params.initialManga
    if (initialManga === undefined ||
      initialManga.sourceId.trim() !== sourceId.trim() ||
      initialManga.id.trim() !== mangaId.trim() ||
      initialManga.title.trim().length === 0) {
      return undefined
    }
    return initialManga
  }

  private sourceDetailFromInitialRouteManga(sourceId: string, mangaId: string): MangaDetail | undefined {
    const initialManga = this.validInitialRouteManga(sourceId, mangaId)
    if (initialManga === undefined) {
      return undefined
    }
    return {
      id: mangaId,
      title: initialManga.title.trim(),
      author: initialManga.author,
      artist: initialManga.artist,
      description: initialManga.description,
      coverUrl: initialManga.coverUrl,
      status: this.mangaStatusFromSourceStatus(initialManga.status),
      tags: initialManga.tags,
      sourceId,
      sourceImageId: mangaId,
      sourceName: sourceId,
      chapterCount: 0,
      isInLibrary: false,
      url: initialManga.url,
      webUrl: initialManga.webUrl,
    }
  }

  private buildSourceDetailRequestJson(
    sourceId: string,
    operation: string,
    args: SourceMangaRequestArgs,
    hostHints: SourceDetailRequestHostHints,
  ): string {
    const settings = appSourceSettingsStore.loadForSource(sourceId)
    const request: SourceDetailRequest = {
      type: 'request',
      version: 1,
      requestId: `detail-${operation}-${sourceId}-${Date.now()}`,
      operation,
      sourceId,
      args,
      settings,
      hostHints,
    }
    return JSON.stringify(request)
  }

  private sourceMangaResponseItem(response: SourceOperationResponsePayload): Record<string, Object> | undefined {
    if (response.data?.manga !== undefined) {
      return response.data.manga
    }
    if (response.data?.item !== undefined) {
      return response.data.item
    }
    return response.data?.items === undefined || response.data.items.length === 0 ? undefined : response.data.items[0]
  }

  private runtimeRecordArray(value: Object | undefined): Record<string, Object>[] {
    if (!Array.isArray(value)) {
      return []
    }
    const records: Record<string, Object>[] = []
    value.forEach((item: Object): void => {
      if (item === undefined || item === null || Array.isArray(item) || typeof item !== 'object') {
        return
      }
      records.push(item as Record<string, Object>)
    })
    return records
  }

  private sourceEmbeddedChapterItems(response: SourceOperationResponsePayload, item: Record<string, Object>): Record<string, Object>[] {
    const dataChapters = response.data?.chapters
    if (dataChapters !== undefined && dataChapters.length > 0) {
      return dataChapters
    }
    return this.runtimeRecordArray(item['chapters'])
  }

  private sourceComicId(sourceId: string | undefined, mangaId: string): string {
    return sourceLibraryComicId(sourceId, mangaId)
  }

  private currentComicId(): string {
    if (this.activeLibraryComicId.length > 0) {
      return this.activeLibraryComicId
    }
    const manga = this.manga
    return this.sourceComicId(
      manga?.sourceId ?? this.params.sourceId,
      manga?.id ?? this.params.mangaId?.trim() ?? '',
    )
  }

  private findSourceRuntimeComic(sourceId: string, mangaId: string, comicId: string): Comic | undefined {
    const direct = this.libraryStore?.getComic(comicId)
    if (direct !== undefined) {
      return direct
    }
    const normalizedSourceId = sourceId.trim()
    const normalizedMangaId = mangaId.trim()
    if (normalizedSourceId.length === 0 || normalizedMangaId.length === 0) {
      return undefined
    }
    return this.libraryStore?.listComics().find((comic: Comic): boolean => {
      return comic.sourceRuntimeId === normalizedSourceId && comic.remoteResourceId === normalizedMangaId
    })
  }

  private firstChapterId(): string | undefined {
    // The standalone download action retains its existing chapter target.
    // Earliest-unread is the adopted reading rule, not a download retargeting.
    return firstReaderChapter(this.chapters)?.id
  }

  private firstUnreadChapterId(): string | undefined {
    return firstReaderChapter(this.chapters, sourceChapterOrderFor(this.manga?.sourceId),
      (id: string): boolean => this.readerSessionStore.isChapterRead(this.currentComicId(), id))?.id
  }

  private currentReadingProgress(): ReadingProgress | undefined {
    void this.readerProgressRevision
    const comic = this.libraryStore?.getComic(this.currentComicId())
    return comic === undefined ? this.readerSessionStore.getProgress(this.currentComicId()) :
      this.readerSessionStore.getComicProgress(comic)
  }

  private progressChapterId(): string | undefined {
    const progress = this.currentReadingProgress()
    if (progress === undefined || progress.chapterId.trim().length === 0) {
      return undefined
    }
    return this.chapters.some((chapter: MangaChapterItem): boolean => chapter.id === progress.chapterId)
      ? progress.chapterId
      : undefined
  }

  private primaryReadChapterId(): string | undefined {
    return this.progressChapterId() ?? this.firstUnreadChapterId()
  }

  private hasReadableChapters(): boolean {
    return this.primaryReadChapterId() !== undefined
  }

  private allChapterIds(): string[] {
    return this.chapters.map((chapter: MangaChapterItem): string => chapter.id)
  }

  private completedProgressForChapter(chapterId: string): ReadingProgress | undefined {
    const chapter = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)
    if (chapter === undefined) {
      return undefined
    }
    const pageCount = 1
    const progress = updateReadingProgress({
      comicId: this.currentComicId(),
      chapterId,
      pageIndex: 0,
      totalPages: pageCount,
      progressRatio: 0,
      completed: false,
      updatedAt: Date.now(),
    }, pageCount - 1, undefined, pageCount)
    return progress
  }

  private latestTrackableMarkedReadProgress(chapterIds: string[]): ReadingProgress | undefined {
    let best: ReadingProgress | undefined
    let bestCount: number = -1
    chapterIds.forEach((id: string): void => {
      const progress = this.completedProgressForChapter(id)
      if (progress === undefined) return
      const count = this.trackerProgressCount(progress)
      if (count !== undefined && count > bestCount) { best = progress; bestCount = count }
    })
    const current = this.currentReadingProgress()
    const currentCount = current === undefined ? undefined : this.trackerProgressCount(current)
    return currentCount !== undefined && currentCount > bestCount ? undefined : best
  }

  private trackerProgressCount(progress: ReadingProgress): number | undefined {
    const chapter = this.chapters.find((item: MangaChapterItem): boolean => item.id === progress.chapterId)
    return trackerChapterProgress(progress, chapter?.chapterNumber)
  }

  private syncMarkedReadTrackerProgress(chapterIds: string[]): void {
    const progress = this.latestTrackableMarkedReadProgress(chapterIds)
    if (progress === undefined) {
      return
    }
    try {
      const context = getContext(this) as common.UIAbilityContext
      void new TrackerProgressSyncService(context).pushReadingProgress(
        progress,
        this.allChapterIds(),
        'on_chapter_complete', Date.now(), undefined, this.trackerProgressCount(progress) ?? null,
      )
        .then((result) => {
          console.info(`[TrackerSync] step=marked_read_progress status=${result.status} reason=${result.reason ?? 'none'} queued=${result.queued === true}`)
        })
        .catch((_error: Error) => {
          DiagnosticLogger.warn('manga_detail_page', 'marked_read_progress', '[TrackerSync] step=marked_read_progress failed=true reason=marked_read')
        })
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'marked_read_progress', '[TrackerSync] step=marked_read_progress failed=true reason=context')
    }
  }

  private async handleAddToLibrary(): Promise<boolean> {
    if (!this.canAddCurrentMangaToLibrary()) {
      return false
    }
    if (this.libraryStore === undefined) {
      this.feedbackText = s('manga_detail_library_unavailable')
      this.showToast(s('manga_detail_library_unavailable'))
      return false
    }
    const manga = this.manga
    if (manga === undefined) {
      return false
    }
    if (this.isInLibrary) {
      const comicId = this.currentComicId()
      try {
        const removed = this.libraryPersistenceService === undefined
          ? this.libraryStore.getComic(comicId) !== undefined
          : removeComicRecordAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comicId)
        if (this.libraryPersistenceService === undefined && removed) {
          this.libraryStore.removeComic(comicId)
        }
        if (!removed) {
          this.showToast(s('common_remove_from_library_failed'))
          return false
        }
        this.activeLibraryComicId = ''
        this.isInLibrary = false
        manga.isInLibrary = false
        this.onLibraryChanged()
        this.refreshDownloadStatus()
        this.showToast(s('common_removed_from_library'))
        return true
      } catch (error) {
        void error
        DiagnosticLogger.error('manga_detail_page', 'remove_from_library_failed', '[manga-detail] step=remove_from_library_failed reason=library_persist')
        this.showToast(s('common_remove_from_library_failed'))
        return false
      }
    }
    const comic = comicFromSourceManga(manga, this.chapters, this.currentComicId())
    try {
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.activeLibraryComicId = comic.id
      this.isInLibrary = true
      manga.isInLibrary = true
      // A source item becomes a normal shelf/history item only after this
      // explicit user action. Keep its existing progress, but remove the
      // transient-source metadata so History cannot render it twice.
      this.readerSessionStore.removeSourceHistory(comic.id)
      this.onLibraryChanged()
      this.refreshDownloadStatus()
      this.showToast(s('common_added_to_library'))
      return true
    } catch (error) {
      void error
      DiagnosticLogger.error('manga_detail_page', 'add_to_library_failed', '[manga-detail] step=add_to_library_failed reason=library_persist')
      this.feedbackText = s('common_add_to_library_failed')
      this.showToast(s('common_add_to_library_failed'))
      return false
    }
  }

  private async handleStartReading(): Promise<void> {
    const chapterId = this.primaryReadChapterId()
    if (chapterId === undefined) {
      this.showToast(s('manga_detail_no_readable_chapters'))
      return
    }
    const transientRequest = this.sourceReaderSessionRequest(chapterId)
    if (!this.isInLibrary && transientRequest !== undefined) {
      this.onOpenSourceReader(transientRequest)
      return
    }
    this.onOpenReader(this.currentComicId(), chapterId)
  }

  private async handleOpenChapter(chapterId: string): Promise<void> {
    if (chapterId.trim().length === 0) {
      return
    }
    const transientRequest = this.sourceReaderSessionRequest(chapterId)
    if (!this.isInLibrary && transientRequest !== undefined) {
      this.onOpenSourceReader(transientRequest)
      return
    }
    this.onOpenReader(this.currentComicId(), chapterId)
  }

  private sourceReaderSessionRequest(chapterId: string): SourceReaderSessionRequest | undefined {
    const manga = this.manga
    if (manga === undefined) {
      return undefined
    }
    const sourceId = manga.sourceId?.trim()
    const mangaId = manga.id.trim()
    const title = manga.title.trim()
    const resolvedChapterId = chapterId.trim()
    if (sourceId === undefined || sourceId.length === 0 || mangaId.length === 0 || title.length === 0 || resolvedChapterId.length === 0) {
      return undefined
    }
    const chapterIds = this.allChapterIds()
    if (!chapterIds.includes(resolvedChapterId)) {
      return undefined
    }
    const request: SourceReaderSessionRequest = {
      comicId: this.currentComicId(),
      sourceId,
      mangaId,
      mangaUrl: manga.url,
      title,
      chapterId: resolvedChapterId,
      chapterIds,
      chapterTitles: this.chapters.map((chapter: MangaChapterItem): string => chapter.title),
      chapters: this.chapters.map((chapter: MangaChapterItem): ReaderChapterDescriptor => cloneReaderChapterDescriptor(chapter)),
      chaptersResolved: this.sourceChaptersResolved,
    }
    const coverUri = manga.coverUrl?.trim()
    if (coverUri !== undefined && coverUri.length > 0) {
      request.coverUri = coverUri
    }
    const sourceName = manga.sourceName?.trim()
    if (sourceName !== undefined && sourceName.length > 0) {
      request.sourceName = sourceName
    }
    return request
  }

  private async handleDownloadChapter(chapterId?: string): Promise<void> {
    if (this.downloadBusy) {
      return
    }
    const manga = this.manga
    if (manga === undefined) {
      return
    }
    const resolvedChapterId = chapterId ?? this.firstChapterId()
    if (resolvedChapterId === undefined) {
      this.downloadStatusText = s('manga_detail_download_empty')
      this.showToast(s('manga_detail_download_empty'))
      return
    }
    const service = this.offlineDownloadService()
    if (service === undefined) {
      this.downloadStatusText = s('manga_detail_download_unavailable')
      this.showToast(s('manga_detail_download_unavailable'))
      return
    }
    this.downloadBusy = true
    this.downloadStatusText = s('manga_detail_download_in_progress')
    try {
      if (!this.isInLibrary && manga.sourceId !== undefined) {
        const added = await this.handleAddToLibrary()
        if (!added) {
          this.downloadStatusText = s('manga_detail_download_canceled')
          return
        }
      }
      let comic = this.libraryStore?.getComic(this.currentComicId())
      if (comic === undefined) {
        this.downloadStatusText = s('manga_detail_add_to_library_first')
        this.showToast(s('manga_detail_add_to_library_first'))
        return
      }
      if (manga.sourceId !== undefined) {
        const hydration = await this.ensureSourceChapterPages(resolvedChapterId)
        const currentComic = this.libraryStore?.getComic(comic.id)
        if (currentComic === undefined || !sameComicIdentity(comic, currentComic) ||
          !currentComic.chapters.some((item: Chapter): boolean => item.id === resolvedChapterId)) {
          throw new Error('download_target_changed')
        }
        comic = currentComic
        if (!hydration.hydrated) {
          const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === resolvedChapterId)?.title
          await service.blockChapterDownload(comic, resolvedChapterId, hydration.reasonCode ?? 'pages_missing', {
            comicTitle: comic.title,
            chapterTitle,
          })
          this.applyChapterStatesToCurrent()
          this.downloadStatusText = s('manga_detail_chapter_pages_load_failed')
          this.showToast(s('manga_detail_chapter_pages_load_failed'))
          return
        }
      }
      const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === resolvedChapterId)?.title
      const manifest = await service.downloadChapter(comic, resolvedChapterId, {
        comicTitle: comic.title,
        chapterTitle,
      })
      this.applyChapterStatesToCurrent()
      this.downloadStatusText = this.formatDownloadStatus({
        comicId: manifest.comicId,
        chapterId: manifest.chapterId,
        pageCount: manifest.pageCount,
        downloadedPageCount: manifest.downloadedPageCount,
        status: manifest.status,
        updatedAt: manifest.updatedAt,
        failureReasonCode: manifest.failureReasonCode,
      })
      this.showToast(this.isPausedDownload(manifest.status, manifest.failureReasonCode)
        ? s('downloads_status_paused')
        : manifest.status === OfflineDownloadStatus.DOWNLOADED
        ? s('manga_detail_chapter_downloaded')
        : s('manga_detail_chapter_download_failed'))
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'detail_download_failed', '[ReaderOffline] step=detail_download_failed failed=true reason=download_execution')
      this.downloadStatusText = s('manga_detail_chapter_download_failed')
      this.showToast(this.downloadStatusText)
    } finally {
      this.downloadBusy = false
    }
  }

  private canCheckLocalLibraryRefresh(): boolean {
    const comic = this.libraryStore?.getComic(this.currentComicId())
    return comic !== undefined &&
      (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE ||
        (comic.sourceKind === ComicSourceKind.LOCAL_FOLDER && canRescanLocalLibraryFolder()))
  }

  private async checkLocalLibraryRefreshNow(): Promise<void> {
    if (this.localRefreshBusy) {
      return
    }
    const libraryStore = this.libraryStore
    const comic = libraryStore?.getComic(this.currentComicId())
    if (libraryStore === undefined || comic === undefined) {
      this.localRefreshText = s('manga_detail_local_refresh_unavailable')
      this.showToast(this.localRefreshText)
      return
    }
    this.localRefreshBusy = true
    this.localRefreshText = s('manga_detail_local_refresh_checking')
    try {
      if (comic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
        const actionResult = await this.onRefreshLocalFolder(comic.id)
        if (actionResult === undefined) {
          throw new Error('local_folder_rescan_unavailable')
        }
        if (actionResult.scannedRootCount > 0) {
          this.loadLocalOrMissingManga(comic.id)
        }
        this.localRefreshText = formatLocalLibraryFolderRescanActionResult(actionResult)
        this.showToast(this.localRefreshText)
        if (actionResult.status === 'reselect_required') {
          this.onOpenImportRequested()
        }
        return
      }
      const result: LocalLibraryRefreshComicResult =
        new LocalLibraryRefreshService(libraryStore).checkLocalComicRefresh(comic)
      this.localRefreshText = result.message
      console.info(`[LocalLibraryRefresh] step=detail_check status=${result.status} chapters=${result.previousChapterCount} pages=${result.previousPageCount} missingPages=${result.missingPageCount}`)
      this.showToast(result.message)
      if (result.status === 'reselect_required') {
        this.onOpenImportRequested()
      }
    } catch (_error) {
      this.localRefreshText = s('manga_detail_local_refresh_unavailable')
      DiagnosticLogger.warn('manga_detail_page', 'detail_check_failed', '[LocalLibraryRefresh] step=detail_check_failed failed=true reason=local_refresh')
      this.showToast(this.localRefreshText)
    } finally {
      this.localRefreshBusy = false
    }
  }

  private batchDownloadChapterIds(chapterIds: string[], mode: ChapterBatchDownloadMode): string[] {
    const service = this.offlineDownloadService()
    if (service === undefined) {
      return []
    }
    const comicId = this.currentComicId()
    return chapterIds.filter((chapterId: string): boolean => {
      const summary = service.getChapterSummary(comicId, chapterId)
      if (mode === ChapterBatchDownloadMode.FAILED_ONLY) {
        return summary?.status === OfflineDownloadStatus.FAILED ||
          summary?.status === OfflineDownloadStatus.PARTIAL ||
          this.isRecoverableBlockedDownload(summary)
      }
      if (mode === ChapterBatchDownloadMode.NOT_DOWNLOADED) {
        return summary?.status !== OfflineDownloadStatus.DOWNLOADED
      }
      return true
    })
  }

  private isRecoverableBlockedDownload(summary: OfflineDownloadSummary | undefined): boolean {
    return summary?.status === OfflineDownloadStatus.BLOCKED &&
      (summary.failureReasonCode === 'pages_missing' ||
        summary.failureReasonCode === 'source_pages_failed' ||
        summary.failureReasonCode === 'source_lookup_failed' ||
        summary.failureReasonCode === 'source_not_installed' ||
        summary.failureReasonCode === 'source_disabled')
  }

  private confirmDownloadFilteredChapters(chapterIds: string[], mode: ChapterBatchDownloadMode,
    scope: ChapterBatchScope = ChapterBatchScope.FILTERED): void {
    if (this.downloadBusy || this.manga === undefined) {
      return
    }
    if (this.offlineDownloadService() === undefined) {
      this.showToast(s('manga_detail_download_unavailable'))
      return
    }
    const filteredChapterIds = Array.from(new Set<string>(chapterIds))
    if (scope === ChapterBatchScope.SELECTED && filteredChapterIds.length === 0) {
      return
    }
    const targetChapterIds = this.batchDownloadChapterIds(filteredChapterIds, mode)
    const title = scope === ChapterBatchScope.SELECTED
      ? this.formatString('chapter_list_menu_download_selected', [filteredChapterIds.length])
      : mode === ChapterBatchDownloadMode.FAILED_ONLY
      ? s('chapter_list_menu_retry_failed') : s('chapter_list_menu_download_filtered')
    const message = mode === ChapterBatchDownloadMode.FAILED_ONLY
      ? this.formatString('manga_detail_retry_filtered_confirm', [filteredChapterIds.length, targetChapterIds.length])
      : this.formatString(scope === ChapterBatchScope.SELECTED
        ? 'manga_detail_download_selected_confirm' : 'manga_detail_download_filtered_confirm', [
        filteredChapterIds.length, filteredChapterIds.length - targetChapterIds.length, targetChapterIds.length,
      ])
    if (targetChapterIds.length === 0) {
      this.getUIContext().showAlertDialog({
        title,
        message,
        autoCancel: true,
        confirm: { value: s('common_confirm'), action: () => {} },
      })
      return
    }
    this.getUIContext().showAlertDialog({
      title,
      message,
      autoCancel: true,
      primaryButton: {
        value: s('common_confirm'),
        action: () => {
          void this.handleDownloadChapters(targetChapterIds, mode)
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private async handleDownloadChapters(chapterIds: string[], mode: ChapterBatchDownloadMode): Promise<void> {
    if (this.downloadBusy) {
      return
    }
    const manga = this.manga
    if (manga === undefined) {
      return
    }
    const service = this.offlineDownloadService()
    if (service === undefined) {
      this.downloadStatusText = s('manga_detail_download_unavailable')
      this.showToast(s('manga_detail_download_unavailable'))
      return
    }
    const targetChapterIds = this.batchDownloadChapterIds(chapterIds, mode)
    if (targetChapterIds.length === 0) {
      this.downloadStatusText = s('manga_detail_no_matching_chapters')
      this.showToast(s('manga_detail_no_matching_chapters'))
      return
    }
    this.downloadBusy = true
    this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [0, targetChapterIds.length])
    let downloadedCount = 0
    let blockedCount = 0
    let failedCount = 0
    let pausedCount = 0
    let finishedCount = 0
    try {
      if (!this.isInLibrary && manga.sourceId !== undefined) {
        const added = await this.handleAddToLibrary()
        if (!added) {
          this.downloadStatusText = s('manga_detail_download_canceled')
          return
        }
      }
      const initialComic = this.libraryStore?.getComic(this.currentComicId())
      if (initialComic === undefined) {
        this.downloadStatusText = s('manga_detail_add_to_library_first')
        this.showToast(s('manga_detail_add_to_library_first'))
        return
      }
      await service.runChapterBatch(targetChapterIds, async (chapterId: string): Promise<void> => {
        if (manga.sourceId !== undefined) {
          let hydration: SourceChapterPageHydrationResult
          try {
            hydration = await this.ensureSourceChapterPages(chapterId)
          } catch (_error) {
            DiagnosticLogger.warn('manga_detail_page', 'batch_pages_unavailable', '[ReaderOffline] step=batch_pages_unavailable failed=true reason=source_pages_lookup')
            blockedCount += 1
            this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [++finishedCount, targetChapterIds.length])
            return
          }
          if (!hydration.hydrated) {
            const comic = this.libraryStore?.getComic(this.currentComicId())
            if (comic !== undefined && sameComicIdentity(initialComic, comic) &&
              comic.chapters.some((item: Chapter): boolean => item.id === chapterId)) {
              const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)?.title
              await service.blockChapterDownload(comic, chapterId, hydration.reasonCode ?? 'pages_missing', {
                comicTitle: comic.title,
                chapterTitle,
              })
            }
            blockedCount += 1
            DiagnosticLogger.warn('manga_detail_page', 'batch_pages_unavailable', `[ReaderOffline] step=batch_pages_unavailable failed=true reason=${hydration.reasonCode ?? 'source_pages_missing'}`)
            this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [++finishedCount, targetChapterIds.length])
            return
          }
        }
        const comic = this.libraryStore?.getComic(this.currentComicId())
        if (comic === undefined || !sameComicIdentity(initialComic, comic) ||
          !comic.chapters.some((item: Chapter): boolean => item.id === chapterId)) {
          failedCount += 1
          this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [++finishedCount, targetChapterIds.length])
          return
        }
        const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)?.title
        const manifest = await service.downloadChapter(comic, chapterId, {
          comicTitle: comic.title,
          chapterTitle,
        })
        if (this.isPausedDownload(manifest.status, manifest.failureReasonCode)) {
          pausedCount += 1
        } else if (manifest.status === OfflineDownloadStatus.DOWNLOADED) {
          downloadedCount += 1
        } else if (manifest.status === OfflineDownloadStatus.BLOCKED) {
          blockedCount += 1
        } else {
          failedCount += 1
        }
        this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [++finishedCount, targetChapterIds.length])
      })
      this.applyChapterStatesToCurrent()
      this.downloadStatusText = pausedCount > 0
        ? this.formatString('manga_detail_batch_paused', [downloadedCount, pausedCount, blockedCount, failedCount])
        : this.formatString('manga_detail_batch_complete', [downloadedCount, blockedCount, failedCount])
      this.showToast(this.downloadStatusText)
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'detail_batch_download_failed', '[ReaderOffline] step=detail_batch_download_failed failed=true reason=download_execution')
      this.downloadStatusText = s('manga_detail_chapter_download_failed')
      this.showToast(this.downloadStatusText)
    } finally {
      this.downloadBusy = false
    }
  }

  private async ensureSourceChapterPages(chapterId: string): Promise<SourceChapterPageHydrationResult> {
    const sourceId = this.manga?.sourceId
    if (this.libraryStore === undefined || sourceId === undefined) {
      return { hydrated: false, pageCount: 0, reasonCode: 'source_lookup_failed' }
    }
    const result = await new SourceChapterPageHydrator(
      this.libraryStore,
      this.sourceRegistry,
      this.libraryPersistenceService,
      () => {
        this.onLibraryChanged()
      },
    ).ensureChapterPages(this.currentComicId(), sourceId, chapterId)
    return result
  }


  private markChapterReadState(chapterId: string, isRead: boolean): void {
    if (chapterId.trim().length === 0) {
      return
    }
    const result = this.readerSessionStore.commitChapterReadStates([{ comicId: this.currentComicId(), chapterId, isRead }])
    if (!result.committed) {
      this.showToast(s('reader_progress_save_failed'))
      return
    }
    this.applyChapterStatesToCurrent()
    this.onReadingStateChanged()
    if (isRead) {
      this.syncMarkedReadTrackerProgress([chapterId])
    }
    this.showToast(isRead ? s('manga_detail_marked_read') : s('manga_detail_marked_unread'))
  }

  private confirmMarkFilteredChaptersReadState(chapterIds: string[], isRead: boolean,
    scope: ChapterBatchScope = ChapterBatchScope.FILTERED): void {
    if (this.manga === undefined) {
      return
    }
    const targetIds = Array.from(new Set<string>(chapterIds))
      .filter((chapterId: string): boolean => chapterId.trim().length > 0)
    if (scope === ChapterBatchScope.SELECTED && targetIds.length === 0) {
      return
    }
    const title = scope === ChapterBatchScope.SELECTED
      ? this.formatString(isRead ? 'chapter_list_menu_mark_selected_read' : 'chapter_list_menu_mark_selected_unread', [targetIds.length])
      : isRead ? s('chapter_list_menu_mark_filtered_read') : s('chapter_list_menu_mark_filtered_unread')
    const message = this.formatString(scope === ChapterBatchScope.SELECTED
      ? (isRead ? 'manga_detail_mark_selected_read_confirm' : 'manga_detail_mark_selected_unread_confirm')
      : (isRead ? 'manga_detail_mark_filtered_read_confirm' : 'manga_detail_mark_filtered_unread_confirm'), [targetIds.length])
    if (targetIds.length === 0) {
      this.getUIContext().showAlertDialog({
        title,
        message,
        autoCancel: true,
        confirm: { value: s('common_confirm'), action: () => {} },
      })
      return
    }
    this.getUIContext().showAlertDialog({
      title,
      message,
      autoCancel: true,
      primaryButton: {
        value: s('common_confirm'),
        action: () => {
          this.markChaptersReadState(targetIds, isRead)
        },
      },
      secondaryButton: { value: s('common_cancel'), action: () => {} },
    })
  }

  private markChaptersReadState(chapterIds: string[], isRead: boolean): void {
    const targetIds = chapterIds.filter((chapterId: string): boolean => chapterId.trim().length > 0)
    if (targetIds.length === 0) {
      this.showToast(s('manga_detail_no_markable_chapters'))
      return
    }
    const comicId = this.currentComicId()
    const result = this.readerSessionStore.commitChapterReadStates(
      targetIds.map((chapterId: string): ChapterReadMutation => ({ comicId, chapterId, isRead })),
    )
    if (!result.committed) {
      this.showToast(s('reader_progress_save_failed'))
      return
    }
    const changedCount = result.changedCount
    this.applyChapterStatesToCurrent()
    this.onReadingStateChanged()
    if (isRead) {
      this.syncMarkedReadTrackerProgress(targetIds)
    }
    this.showToast(isRead
      ? this.formatString('manga_detail_marked_count_read', [changedCount])
      : this.formatString('manga_detail_marked_count_unread', [changedCount]))
  }

  private trackerSyncSkippedText(reason: TrackerProgressSyncReason | undefined): string {
    if (reason === 'mapping_missing') {
      return s('manga_detail_tracker_sync_mapping_missing')
    }
    if (reason === 'auto_sync_disabled') {
      return s('manga_detail_tracker_sync_disabled')
    }
    if (reason === 'chapter_progress_unknown') return s('manga_detail_tracker_sync_no_progress')
    if (reason === 'strategy_not_due') {
      return s('manga_detail_tracker_sync_not_due')
    }
    return s('manga_detail_tracker_sync_failed')
  }

  private trackerMappingSkippedText(reason: TrackerMappingSearchReason | undefined): string {
    if (reason === 'account_missing' || reason === 'credential_missing') {
      return s('manga_detail_tracker_mapping_account_missing')
    }
    if (reason === 'confirmed_mapping_exists') {
      return s('manga_detail_tracker_mapping_confirmed_exists')
    }
    if (reason === 'results_empty' || reason === 'query_missing') {
      return s('manga_detail_tracker_mapping_not_found')
    }
    return s('manga_detail_tracker_mapping_failed')
  }

  private localProgressFromTrackerResult(result: TrackerProgressSyncResult): ReadingProgress | undefined {
    if (result.status !== 'synced' || result.providerProgress === undefined || result.providerProgress <= 0) {
      return undefined
    }
    const chapterId = trackerChapterForProgress(this.chapters, result.providerProgress,
      this.currentReadingProgress()?.chapterId)
    return chapterId === undefined ? undefined : this.completedProgressForChapter(chapterId)
  }

  private async refreshTrackerMappingCandidates(): Promise<void> {
    if (this.trackerMappingBusy) {
      return
    }
    const manga = this.manga
    if (manga === undefined) {
      return
    }
    this.trackerMappingBusy = true
    this.showToast(s('manga_detail_tracker_mapping_searching'))
    try {
      const context = getContext(this) as common.UIAbilityContext
      const comic = this.libraryStore?.getComic(this.currentComicId()) ??
        comicFromSourceManga(manga, this.chapters, this.currentComicId())
      const summary: TrackerMappingSearchSummary =
        await new TrackerMappingSearchService(context).refreshComicMappingCandidates(comic)
      console.info(`[TrackerMapping] step=manual_candidate_refresh scanned=${summary.scannedCount} mapped=${summary.mappedCount} failed=${summary.failedCount} skipped=${summary.skippedCount}`)
      if (summary.mappedCount > 0) {
        this.showToast(this.formatString('manga_detail_tracker_mapping_found', [summary.mappedCount]))
        return
      }
      const reason = summary.results.length === 0 ? undefined : summary.results[0].reason
      this.showToast(this.trackerMappingSkippedText(summary.failedCount > 0 ? 'provider_failed' : reason))
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'manual_candidate_refresh', '[TrackerMapping] step=manual_candidate_refresh failed=true')
      this.showToast(s('manga_detail_tracker_mapping_failed'))
    } finally {
      this.trackerMappingBusy = false
    }
  }

  private async syncTrackerProgressNow(): Promise<void> {
    if (this.trackerSyncBusy) {
      return
    }
    const progress = this.currentReadingProgress()
    if (progress === undefined) {
      this.showToast(s('manga_detail_tracker_sync_no_progress'))
      return
    }
    this.trackerSyncBusy = true
    this.showToast(s('manga_detail_tracker_sync_in_progress'))
    try {
      const context = getContext(this) as common.UIAbilityContext
      const result = await new TrackerProgressSyncService(context).pushReadingProgress(
        progress,
        this.allChapterIds(),
        'manual', Date.now(), undefined, this.trackerProgressCount(progress) ?? null,
      )
      console.info(`[TrackerSync] step=manual_progress status=${result.status} reason=${result.reason ?? 'none'} queued=${result.queued === true}`)
      if (result.status === 'synced') {
        this.showToast(s('manga_detail_tracker_sync_done'))
        return
      }
      if (result.queued === true) {
        this.showToast(s('manga_detail_tracker_sync_queued'))
        return
      }
      if (result.status === 'skipped') {
        this.showToast(this.trackerSyncSkippedText(result.reason))
        return
      }
      this.showToast(s('manga_detail_tracker_sync_failed'))
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'manual_progress', '[TrackerSync] step=manual_progress failed=true reason=manual_progress')
      this.showToast(s('manga_detail_tracker_sync_failed'))
    } finally {
      this.trackerSyncBusy = false
    }
  }

  private async pullTrackerProgressNow(): Promise<void> {
    if (this.trackerSyncBusy) {
      return
    }
    this.trackerSyncBusy = true
    this.showToast(s('manga_detail_tracker_pull_in_progress'))
    try {
      const context = getContext(this) as common.UIAbilityContext
      const result = await new TrackerProgressSyncService(context).pullReadingProgress(this.currentComicId())
      console.info(`[TrackerSync] step=manual_pull_progress status=${result.status} reason=${result.reason ?? 'none'}`)
      const progress = this.localProgressFromTrackerResult(result)
      if (progress !== undefined) {
        this.readerSessionStore.saveProgress(progress)
        this.applyChapterStatesToCurrent()
        this.onReadingStateChanged()
        this.showToast(s('manga_detail_tracker_pull_done'))
        return
      }
      if (result.reason === 'remote_progress_missing' || result.providerProgress === 0) {
        this.showToast(s('manga_detail_tracker_pull_empty'))
        return
      }
      if (result.status === 'skipped') {
        this.showToast(this.trackerSyncSkippedText(result.reason))
        return
      }
      this.showToast(s('manga_detail_tracker_sync_failed'))
    } catch (_error) {
      DiagnosticLogger.warn('manga_detail_page', 'manual_pull_progress', '[TrackerSync] step=manual_pull_progress failed=true reason=manual_pull')
      this.showToast(s('manga_detail_tracker_sync_failed'))
    } finally {
      this.trackerSyncBusy = false
    }
  }

  private copyWasmBytes(entry: SourceRuntimeRegistryEntry): Uint8Array {
    const copy = new Uint8Array(entry.wasmBytes.byteLength)
    copy.set(entry.wasmBytes)
    return copy
  }

  private optionalSourceString(value: Object | string | number | boolean | null | undefined): string | undefined {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return undefined
    }
    return value
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private displayedManga(manga: MangaDetail): MangaDetail {
    return {
      id: manga.id,
      title: manga.title,
      author: manga.author,
      artist: manga.artist,
      description: manga.description,
      coverUrl: manga.coverUrl,
      status: manga.status,
      tags: manga.tags,
      sourceId: manga.sourceId,
      sourceImageId: manga.sourceImageId,
      sourceName: manga.sourceId === undefined ? s('tab_library') : sourceDisplayName(manga.sourceId, manga.sourceName ?? ''),
      chapterCount: this.chapters.length,
      isInLibrary: this.isInLibrary,
      url: manga.url,
    }
  }

  private primaryReadLabel(): string {
    return this.progressChapterId() !== undefined
      ? s('library_continue_reading')
      : s('common_start_reading')
  }

  private primaryReadChapterLabel(): string {
    const chapterId = this.progressChapterId()
    const chapter = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)
    if (chapter === undefined) {
      return ''
    }
    return chapter.title.trim().replace(/\s+/g, ' ') || s('manga_detail_chapter_untitled')
  }

  private primaryReadPageLabel(): string {
    const chapterId = this.progressChapterId()
    if (chapterId === undefined) {
      return ''
    }
    const comicId = this.currentComicId()
    const progress = this.readerSessionStore.getChapterProgress(comicId, chapterId)
    const comic = this.libraryStore?.getComic(comicId)
    const chapter = comic?.chapters.find((item: Chapter): boolean => item.id === chapterId)
    let config: ReaderSessionConfig = {
      comicId, chapterId, chapterIds: this.allChapterIds(),
      totalPages: progress?.totalPages ?? 0, pageUris: [],
    }
    // Source metadata may not have hydrated pages yet. In that case the matching
    // chapter position supplies its known count; loaded chapters use Reader's config.
    if (comic !== undefined && chapter !== undefined &&
      (chapter.pages.length > 0 || chapterPagesAreLocalOffline(comic.sourceKind))) {
      config = createReaderSessionConfigFromComic(comic, chapterId)
    }
    if (config.totalPages <= 0) {
      return ''
    }
    return this.formatString('manga_detail_resume_page', [
      this.readerSessionStore.restorePageIndex(config) + 1, config.totalPages,
    ])
  }

  private primaryReadPositionLabel(): string {
    const chapter = this.primaryReadChapterLabel()
    const page = this.primaryReadPageLabel()
    return page.length > 0 ? `${chapter} · ${page}` : chapter
  }

  private isPausedDownload(status: OfflineDownloadStatus, reason?: string): boolean {
    return reason === 'paused' &&
      (status === OfflineDownloadStatus.QUEUED || status === OfflineDownloadStatus.PARTIAL)
  }

  private formatDownloadStatus(summary: OfflineDownloadSummary | undefined): string {
    if (summary === undefined) {
      return ''
    }
    if (this.isPausedDownload(summary.status, summary.failureReasonCode)) {
      return s('downloads_status_paused') + ' · ' +
        this.formatString('downloads_page_progress', [summary.downloadedPageCount, summary.pageCount])
    }
    if (summary.status === OfflineDownloadStatus.DOWNLOADED) {
      return this.formatString('manga_detail_download_status_downloaded', [summary.downloadedPageCount, summary.pageCount])
    }
    if (summary.status === OfflineDownloadStatus.DOWNLOADING || summary.status === OfflineDownloadStatus.QUEUED) {
      return this.formatString('manga_detail_download_status_downloading', [summary.downloadedPageCount, summary.pageCount])
    }
    if (summary.status === OfflineDownloadStatus.PARTIAL) {
      return this.formatString('manga_detail_download_status_partial', [summary.downloadedPageCount, summary.pageCount])
    }
    if (summary.status === OfflineDownloadStatus.BLOCKED) {
      return s('manga_detail_download_status_blocked')
    }
    return s('manga_detail_download_status_failed')
  }

  private downloadButtonLabel(): string {
    if (this.downloadBusy) {
      return this.downloadStatusText.length > 0 ? this.downloadStatusText : s('manga_detail_download_in_progress')
    }
    const service = this.offlineDownloadService()
    const chapterId = this.firstChapterId()
    if (service !== undefined && chapterId !== undefined) {
      const summary = service.getChapterSummary(this.currentComicId(), chapterId)
      if (summary?.status === OfflineDownloadStatus.DOWNLOADED) {
        return s('manga_detail_action_redownload')
      }
    }
    return s('manga_detail_action_download_chapter')
  }

  @Builder
  private ActionButtons() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      if (this.progressChapterId() === undefined) {
        KomaActionButton({
          label: this.primaryReadLabel(),
          kind: 'primary',
          icon: $r('sys.symbol.doc_plaintext'),
          fullWidth: true,
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.hasReadableChapters() && !this.isSourceDetailLoading(),
          action: () => {
            this.handleStartReading()
          },
        })
      } else {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          if (this.hasReadableChapters() && !this.isSourceDetailLoading()) {
            Row({ space: ThemeConstants.SPACE_SM }) {
              SymbolGlyph($r('sys.symbol.doc_plaintext'))
                .fontSize(ThemeConstants.FONT_SIZE_HEADING)
                .fontColor([$r('app.color.koma_action_on_accent')])
                .flexShrink(0)
              Text(this.primaryReadLabel())
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.koma_action_on_accent'))
                .maxLines(1)
                .flexShrink(0)
              Text(`· ${this.primaryReadChapterLabel()}`)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.koma_action_on_accent'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .flexShrink(1)
              if (this.primaryReadPageLabel().length > 0) {
                Text(`· ${this.primaryReadPageLabel()}`)
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.koma_action_on_accent'))
                  .maxLines(1)
                  .flexShrink(0)
              }
            }
            .width('100%')
            .height(ThemeConstants.ACTION_CHIP_HEIGHT)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
          }
        }
          .width('100%')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .backgroundColor(this.hasReadableChapters() && !this.isSourceDetailLoading()
            ? ThemeConstants.BRAND_PRIMARY : undefined)
          .borderRadius(ThemeConstants.ACTION_CHIP_HEIGHT / 2)
          .opacity(1)
          .enabled(this.hasReadableChapters() && !this.isSourceDetailLoading())
          .contentModifier(this.disabledPrimaryReadContent())
          .onClick(() => {
            this.handleStartReading()
          })
      }

      Row({ space: ThemeConstants.SPACE_MD }) {
        KomaActionButton({
          label: this.downloadButtonLabel(),
          kind: 'secondary',
          icon: $r('sys.symbol.arrow_down_to_line'),
          fill: true,
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.firstChapterId() !== undefined && !this.downloadBusy && !this.isSourceDetailLoading(),
          action: () => {
            this.handleDownloadChapter()
          },
        })

        if (this.canAddCurrentMangaToLibrary()) {
          KomaIconButton({
            icon: this.isInLibrary ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
            kind: this.isInLibrary ? 'primary' : 'secondary',
            controlSize: ThemeConstants.ACTION_CHIP_HEIGHT,
            iconSize: ThemeConstants.FONT_SIZE_TITLE,
            action: () => {
              this.handleAddToLibrary()
            },
          })
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  private disabledPrimaryReadContent(): DetailDisabledReadContent | undefined {
    if (this.hasReadableChapters() && !this.isSourceDetailLoading()) {
      return undefined
    }
    return new DetailDisabledReadContent(this.primaryReadLabel(), this.primaryReadChapterLabel(), this.primaryReadPageLabel())
  }

  @Builder
  private LocalMetadataStatusMenu() {
    Menu() {
      MenuItem({ content: this.localMetadataStatusLabel('unknown') })
        .onClick(() => {
          this.localMetadataStatus = 'unknown'
        })
      MenuItem({ content: this.localMetadataStatusLabel('ongoing') })
        .onClick(() => {
          this.localMetadataStatus = 'ongoing'
        })
      MenuItem({ content: this.localMetadataStatusLabel('completed') })
        .onClick(() => {
          this.localMetadataStatus = 'completed'
        })
      MenuItem({ content: this.localMetadataStatusLabel('hiatus') })
        .onClick(() => {
          this.localMetadataStatus = 'hiatus'
        })
      MenuItem({ content: this.localMetadataStatusLabel('cancelled') })
        .onClick(() => {
          this.localMetadataStatus = 'cancelled'
        })
    }
  }

  @Builder
  private LocalMetadataEditor() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row() {
        Text(s('manga_detail_local_metadata_title'))
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        Blank()
        KomaIconButton({
          icon: $r('sys.symbol.xmark'),
          controlSize: ThemeConstants.ACTION_CHIP_HEIGHT,
          iconSize: ThemeConstants.FONT_SIZE_BODY,
          action: () => {
            this.localMetadataEditorVisible = false
          },
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      KomaFormTextField({
        label: s('manga_detail_local_metadata_field_title'),
        placeholder: s('manga_detail_title_fallback'),
        value: this.localMetadataTitle,
        change: (value: string) => {
          this.localMetadataTitle = value
        },
      })
      KomaFormTextField({
        label: s('manga_detail_local_metadata_field_authors'),
        placeholder: s('manga_detail_creator_unknown'),
        value: this.localMetadataAuthors,
        change: (value: string) => {
          this.localMetadataAuthors = value
        },
      })
      Row() {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(s('manga_detail_local_metadata_field_status'))
            .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
          Text(this.localMetadataStatusLabel(this.localMetadataStatus))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
        }
        .layoutWeight(1)
        KomaActionButton({
          label: this.localMetadataStatusLabel(this.localMetadataStatus),
          kind: 'secondary',
          icon: $r('sys.symbol.chevron_down'),
          action: () => {},
        })
          .bindMenu(this.LocalMetadataStatusMenu(), komaMenuOptions())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.canEditLocalCoverPath()) {
        KomaFormTextField({
          label: s('manga_detail_local_metadata_field_cover'),
          placeholder: s('manga_detail_local_metadata_cover_placeholder'),
          value: this.localMetadataCoverPath,
          change: (value: string) => {
            this.localMetadataCoverPath = value
          },
        })
      }

      Row({ space: ThemeConstants.SPACE_MD }) {
        KomaActionButton({
          label: s('common_reset'),
          kind: 'ghost',
          fill: true,
          action: () => {
            this.resetLocalMetadataEditor()
          },
        })
        KomaActionButton({
          label: s('common_confirm'),
          kind: 'primary',
          fill: true,
          action: () => {
            this.saveLocalMetadataOverride()
          },
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private DetailPendingState() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color(ThemeConstants.BRAND_PRIMARY)
      Text(s('manga_detail_loading_source'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(260)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private CoverBackdrop() {
    // Same cover/cache identity as the foreground. Mihon's 4dp blur and 20%
    // image opacity sit under a theme-colour fade. Keep this layer outside the
    // inset list so it reaches the page edges without changing content layout.
    if (this.manga !== undefined && (this.manga.coverUrl?.length ?? 0) > 0) {
      Stack() {
        Column() {
          CachedCoverImage({
            uri: this.manga.coverUrl ?? '',
            objectFit: ImageFit.Cover,
            sourceRuntimeId: this.manga.sourceId ?? '',
            sourceImageId: this.manga.sourceImageId ?? this.manga.id,
            sourceKind: this.libraryStore?.getComic(this.currentComicId())?.sourceKind,
            remoteServerId: this.libraryStore?.getComic(this.currentComicId())?.remoteServerId ?? '',
            sourceMangaUrl: this.manga.url ?? '',
          })
        }
          .width('100%')
          .height('100%')
          .blur(4)
          .opacity(0.2)
        Column() {}
          .width('100%')
          .height('100%')
          .linearGradient({ direction: GradientDirection.Bottom,
            colors: [[this.backdropFadeStart(), 0], [ThemeConstants.BG_SUB, 1]],
          })
      }
      .width('100%')
      .height('60%')
      .translate({ y: -this.detailScrollOffset })
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
    }
  }

  private backdropFadeStart(): string {
    // Transparent black interpolates through grey on a light page. Keep the
    // theme background's RGB at both ends; only its alpha changes. The taller
    // page-relative backdrop reaches the description without changing layout.
    const background = ColorMetrics.resourceColor(ThemeConstants.BG_SUB)
    return ColorMetrics.rgba(background.red, background.green, background.blue, 0).color
  }

  @Builder
  private DetailList(nativeSpring: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
    this.CoverBackdrop()
    SecondaryListScaffold({
          surfaceColor: Color.Transparent,
          scroller: this.detailScroller,
          scrollEnabled: this.detailScrollEnabled,
          alwaysEnableEdgeSpring: nativeSpring,
          listSpace: ThemeConstants.SPACE_LG,
          bottomPadding: ThemeConstants.SPACE_XL,
          reserveTitleBar: true,
          onDidScroll: (offset: number) => {
            this.detailScrollOffset = offset
            const showTitle = offset > 160
            if (this.chrome.showTitle !== showTitle) this.chrome.showTitle = showTitle
          },
        }) {
        if (this.manga !== undefined) {
          ListItem() {
            MangaDetailHeader({
              manga: this.displayedManga(this.manga),
              showChapterCount: this.shouldShowChapterCount(),
              sourceKind: this.libraryStore?.getComic(this.currentComicId())?.sourceKind,
              remoteServerId: this.libraryStore?.getComic(this.currentComicId())?.remoteServerId ?? '',
            })
          }
        }

        if (this.shouldRenderDetailActions()) {
          ListItem() {
            this.ActionButtons()
          }
        }

        if (this.isDetailPending()) {
          ListItem() {
            this.DetailPendingState()
          }
        }

        if (!this.isDetailPending() && this.feedbackText.length > 0) {
          ListItem() {
            Text(this.feedbackText)
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
        }

        if (this.localRefreshText.length > 0) {
          ListItem() {
            Text(this.localRefreshText)
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
        }

        if (this.hasResolvedManga() && this.localMetadataEditorVisible) {
          ListItem() {
            this.LocalMetadataEditor()
          }
        }

        if (this.manga !== undefined) {
          if (this.shouldRenderDetailMetadata()) {
            ListItem() {
              MangaDescriptionSection({
                description: this.manga.description,
              })
            }

            ListItem() {
              MangaTagsSection({
                tags: this.manga.tags === undefined ? [] : this.manga.tags,
                onTagClick: (tag: string) => {
                  RouterHelper.openSearch({ query: tag })
                },
              })
            }
          }
        }

        if (this.shouldRenderChapterList()) {
          ChapterListSection({
            chapters: this.chapters,
            onOpenChapter: (chapterId: string) => {
              void this.handleOpenChapter(chapterId)
                .catch((error: Error) => {
                  void error
                  DiagnosticLogger.error('manga_detail_page', 'source_pages_load_failed', '[manga-detail] step=source_pages_load_failed reason=source_pages')
                  this.showToast(s('manga_detail_chapter_pages_load_failed'))
                })
            },
            onDownloadChapter: (chapterId: string) => {
              this.handleDownloadChapter(chapterId)
            },
            onDownloadFilteredChapters: (chapterIds: string[], mode: ChapterBatchDownloadMode, scope: ChapterBatchScope) => {
              this.confirmDownloadFilteredChapters(chapterIds, mode, scope)
            },
            onMarkChapterReadState: (chapterId: string, isRead: boolean) => {
              this.markChapterReadState(chapterId, isRead)
            },
            onMarkFilteredChaptersReadState: (chapterIds: string[], isRead: boolean, scope: ChapterBatchScope) => {
              this.confirmMarkFilteredChaptersReadState(chapterIds, isRead, scope)
            },
          })
        }
        }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {}
          .width(0)
          .height(0)
          .bindSheet($$this.detailWebChallengeShown, this.DetailWebChallengeSheet, komaSheetOptions({
            detents: [SheetSize.LARGE], showClose: false,
            enableOutsideInteractive: false, enableFloatingDragBar: true,
            onWillDismiss: (action: DismissSheetAction) => {
              this.closeDetailWebChallenge()
              action.dismiss()
            },
            onDisappear: () => { this.finishDetailWebChallengeDismiss() },
          }))
        if (this.canPullRefreshDetail()) {
          PullRefresh({
            scroller: this.detailScroller,
            controller: this.detailRefreshController,
            indicatorTop: this.detailSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT / 2,
            onRefresh: async (): Promise<void> => { await this.refreshMangaDetail() },
            onScrollEnableChange: (enabled: boolean): void => { this.detailScrollEnabled = enabled },
          }) {
            this.DetailList(false)
          }
        } else {
          this.DetailList(true)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
  }
}

function mangaDetailFromComic(comic: Comic, registry: SourceRuntimeRegistry): MangaDetail {
  let status = comic.sourceMetadata?.status as MangaStatus | undefined ?? MangaStatus.UNKNOWN
  if (comic.localMetadata?.status === 'ongoing') {
    status = MangaStatus.ONGOING
  } else if (comic.localMetadata?.status === 'completed') {
    status = MangaStatus.COMPLETED
  } else if (comic.localMetadata?.status === 'hiatus') {
    status = MangaStatus.HIATUS
  } else if (comic.localMetadata?.status === 'cancelled') {
    status = MangaStatus.CANCELLED
  }
  return {
    id: comic.sourceRuntimeId === undefined ? comic.id : comic.remoteResourceId ?? comic.id,
    title: comic.title,
    author: comic.author,
    artist: comic.sourceMetadata?.artist,
    tags: comic.sourceMetadata?.tags?.slice(),
    description: comic.subtitle,
    coverUrl: comic.coverUri,
    status,
    chapterCount: comic.chapterCount,
    isInLibrary: true,
    sourceId: comic.sourceRuntimeId,
    sourceImageId: comic.remoteResourceId,
    sourceName: comic.sourceRuntimeId === undefined ? '' :
      (registry.list().find((entry) => entry.sourceId === comic.sourceRuntimeId)?.manifestName?.trim() || s('library_source_package')),
    url: comic.sourcePath,
    webUrl: comic.sourceMetadata?.webUrl,
  }
}

function chapterPagesAreLocalOffline(sourceKind: ComicSourceKind): boolean {
  return sourceKind === ComicSourceKind.LOCAL_ARCHIVE || sourceKind === ComicSourceKind.LOCAL_FOLDER
}

function mangaChapterItemFromComicChapter(chapter: Chapter, sourceKind: ComicSourceKind): MangaChapterItem {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.chapterNumber ?? (sourceKind !== ComicSourceKind.PRIVATE_LIBRARY &&
      chapter.continuationEligible === undefined ? chapter.index + 1 : undefined),
    volumeNumber: chapter.volumeNumber,
    readingOrder: chapter.readingOrder,
    readingGroup: chapter.readingGroup,
    continuationEligible: chapter.continuationEligible,
    scanlator: chapter.scanlator,
    language: chapter.language,
    dateUpload: chapter.dateUpload,
    pageCount: chapter.pageCount,
    isRead: false,
    isDownloaded: chapterPagesAreLocalOffline(sourceKind) && chapter.pageCount > 0,
    downloadStatus: chapterPagesAreLocalOffline(sourceKind) && chapter.pageCount > 0 ? 'downloaded' : undefined,
  }
}


function missingMangaDetail(mangaId: string | undefined, sourceId: string | undefined): MangaDetail {
  const normalizedMangaId = mangaId?.trim() ?? ''
  const normalizedSourceId = sourceId?.trim() ?? ''
  return {
    id: normalizedMangaId.length > 0 ? normalizedMangaId : 'missing-manga',
    title: normalizedMangaId.length > 0 ? normalizedMangaId : AppStrings.get('manga_detail_title_fallback'),
    status: MangaStatus.UNKNOWN,
    sourceId: normalizedSourceId.length > 0 ? normalizedSourceId : undefined,
    sourceImageId: normalizedMangaId.length > 0 ? normalizedMangaId : undefined,
    sourceName: normalizedSourceId,
    chapterCount: 0,
    isInLibrary: false,
  }
}
