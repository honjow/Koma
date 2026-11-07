import { SourceAuthenticationSheetHost } from '../components/SourceAuthenticationSheetHost'
import { SourceAuthenticationRequest } from '../sourceRuntime/SourceAuthenticationService'
import { gridColumnCount } from '../utils/GridColumns'
import { ActionBarButton, ActionBarStyle, BottomBuilderShowType, HdsActionBar } from '@kit.UIDesignKit'
import { ReaderPreferencesStore } from '../model/ReaderPreferencesStore'
import { comicFromSourceManga, sourceLibraryComicId } from '../model/SourceLibraryComic'
import { canMigrateLibraryComic } from '../model/SourceMangaMigration'
import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { komaMenuOptions, komaSheetOptions, komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { SEARCH_TITLE_BOTTOM_HEIGHT, TrackerSearchTitleFieldContentBuilder } from '../components/SearchTitleField'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'
import { KomaModalScaffold } from '../components/KomaModalScaffold'
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
import { trackerChapterProgress } from '../model/TrackerReadingProgress'
import { mangaHttpUrl } from '../model/MangaWebLink'
import { MangaDetailHeader } from '../components/MangaDetailHeader'
import { CachedCoverImage } from '../components/CachedCoverImage'
import { ChapterArchiveActions } from '../model/ChapterArchiveExport'
import { selectComicCover, saveComicPersonalization, discardUncommittedComicCover } from '../model/ComicPersonalization'
import { ColorMetrics, ComponentContent, LengthMetrics } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'
import { MangaDescriptionSection } from '../components/MangaDescriptionSection'
import { MangaTagsSection } from '../components/MangaTagsSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { TRACKER_BRAND_IMAGES } from '../components/TrackerBrandIcons'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaMenuAction, KomaMenuController } from '../components/ui/KomaMenuController'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { PullRefresh, PullRefreshController } from '../components/PullRefresh'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import {
  ChapterBatchDownloadMode,
  ChapterBatchScope,
  ChapterListPresentation,
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
  readerFormatFromTags,
  setCompleteSourceChapterCatalog,
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
import { parseSourceRelatedManga, SourceManga } from '../model/SourceModels'
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
import { SyncReadingSource } from '../deviceSync/DeviceSyncSignals'
import {
  TrackerProgressSyncResult,
  TrackerProgressSyncReason,
  TrackerProgressSyncService,
} from '../model/TrackerProgressSyncService'
import { RouterHelper } from '../common/RouterHelper'
import { MangaDetailRouteChromeState, MangaDetailTitleAction } from '../state/MangaDetailRouteChromeState'
import {
  TrackerMappingSearchService,
  TrackerTitleSearchCandidate,
} from '../model/TrackerMappingSearchService'
import { AssetStoreTrackerCredentialSecretStore, ComicTrackerMapping, TRACKER_PROVIDER_CONFIGS, TrackerEntryFields, TrackerProviderConfig, TrackerProviderId,
  TrackerPreferences, TrackerPreferencesStore } from '../model/TrackerModels'

type TrackingNumberField = 'chapters' | 'volumes' | 'score'

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

// Keep mid-size portrait windows such as device 103 in one column.
const DETAIL_PANES_MIN_CONTENT_WIDTH: number = 700

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
  @Local private trackingSheetShown: boolean = false
  @Local private trackingFieldGridWidth: number = 0
  @Local private trackingBodyHeight: number = 0
  @Local private trackingViewportHeight: number = 0
  @Local private trackingSheetType?: SheetType
  @Local private trackingProviders: TrackerProviderConfig[] = []
  @Local private trackingMappings: ComicTrackerMapping[] = []
  private unsubscribeTrackingMappings?: () => void
  @Local private trackingRemoteStates: Map<TrackerProviderId, TrackerProgressSyncResult> = new Map()
  private trackingCacheKeys: Map<TrackerProviderId, string> = new Map()
  private trackingRefreshes: Map<TrackerProviderId, string> = new Map()
  private trackingStatusMenu: KomaMenuController = new KomaMenuController()
  @Local private trackingMenuProvider?: TrackerProviderId
  @Local private trackingSearchProvider?: TrackerProviderConfig
  private trackingSearchChrome: SearchRouteChromeState = new SearchRouteChromeState(false)
  private trackingSearchContent?: ComponentContent<SearchRouteChromeState>
  @Local private trackingResults: TrackerTitleSearchCandidate[] = []
  @Local private trackingSelection?: TrackerTitleSearchCandidate
  @Local private trackingSearchMessage: string = ''
  @Local private localRefreshBusy: boolean = false
  @Local private localMetadataEditorVisible: boolean = false
  @Local private localMetadataTitle: string = ''
  @Local private localMetadataAuthors: string = ''
  @Local private localMetadataStatus: LocalLibraryMetadataStatus | 'unknown' = 'unknown'
  @Local private localMetadataCoverPath: string = ''
  @Local private personalNotes: string = ''
  @Local private notesDraft: string = ''
  @Local private notesEditorShown: boolean = false
  @Local private personalizationBusy: boolean = false
  @Local private downloadStatusText: string = ''
  @Local private localRefreshText: string = ''
  @Local private feedbackText: string = ''
  @Local private activeLibraryComicId: string = ''
  @Local private linkShareBusy: boolean = false
  private linkShareController?: systemShare.ShareController = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private detailSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private detailScrollEnabled: boolean = true
  @Local private detailScrollOffset: number = 0
  private get detailScroller(): ListScroller {
    return this.chrome.detailScroller
  }

  private get chapterScroller(): ListScroller {
    return this.chrome.chapterScroller
  }
  private get chapterPresentation(): ChapterListPresentation {
    return this.chrome.chapterPresentation
  }
  @Local private detailContentWidth: number = 0
  private visibleChapterId: string = ''
  private chapterToRestore: string = ''
  @Local private chapterActionBarHeight: number = 0
  // HDS keeps references to its button models. Update their tracked fields
  // in place so an existing bar reacts without rebuilding the chapter list.
  private readonly chapterDownloadAction = new ActionBarButton({
    id: 'detail-selected-download',
    baseIcon: $r('sys.symbol.arrow_down_to_line'),
    enabled: false,
    onClick: () => { this.downloadSelectedChapters() },
  })
  private readonly chapterMarkReadAction = new ActionBarButton({
    id: 'detail-selected-mark-read',
    baseIcon: $r('sys.symbol.checkmark_circle'),
    enabled: false,
    onClick: () => { this.markSelectedChaptersRead(true) },
  })
  private readonly chapterMarkUnreadAction = new ActionBarButton({
    id: 'detail-selected-mark-unread',
    baseIcon: $r('sys.symbol.circle'),
    enabled: false,
    onClick: () => { this.markSelectedChaptersRead(false) },
  })
  private readonly chapterDownloadActions: ActionBarButton[] = [this.chapterDownloadAction]
  private readonly chapterReadStateActions: ActionBarButton[] = [
    this.chapterMarkReadAction, this.chapterMarkUnreadAction,
  ]


  // Reserve both panes' usable widths before splitting. Window or device
  // orientation alone does not describe the space inside a destination.
  @Computed
  private get usesDetailPanes(): boolean {
    return this.detailContentWidth >= DETAIL_PANES_MIN_CONTENT_WIDTH
  }
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
  @Local private detailAuthentication: SourceWebChallengeReceipt | null = null
  @Local private authentication: SourceAuthenticationRequest | null = null
  private detailAuthenticationGate: SourceWebChallengeGate = new SourceWebChallengeGate()

  private authenticateSource(): void {
    const receipt = this.detailAuthentication
    if (receipt === null || !this.detailAuthenticationGate.claim(receipt.id, this.chrome.visible)) return
    this.authentication = new SourceAuthenticationRequest(receipt.sourceId,
      (): boolean => this.chrome.visible && this.detailAuthenticationGate.isCurrentClaim(receipt.id),
      async (): Promise<void> => {
        try { await this.detailAuthenticationGate.complete(receipt.id, this.chrome.visible) }
        finally { if (this.detailAuthentication?.id === receipt.id) this.detailAuthentication = null }
      }, (): void => {
        const next = this.detailAuthenticationGate.releaseLogin(receipt.id)
        if (this.detailAuthentication?.id === receipt.id) this.detailAuthentication = next
      })
  }

  private detailWebChallengeId: number = 0
  private detailWebChallengeClosing: boolean = false

  private clearDetailWebChallenge(): void {
    this.detailAuthenticationGate.clear()
    this.detailAuthentication = null
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
    const explicitLogin = error instanceof SourceRuntimeError &&
      (error.diagnostic.code === 'auth_required' || error.diagnostic.reason === 'auth_required') &&
      (error.diagnostic.status === 0 || error.diagnostic.status === 401)
    if (!automaticRecovery && explicitLogin && entry?.authentication !== undefined) {
      this.detailAuthentication = this.detailAuthenticationGate.issue(sourceId, 'detail', true,
        (): boolean => this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId),
        async (): Promise<void> => { await this.loadSourceMangaDetail(sourceId, mangaId, true, true, retryStage) })
      return
    }
    const eligible = !automaticRecovery && error instanceof SourceRuntimeError &&
      (error.diagnostic.kind === 'challenge' || (error.diagnostic.code === 'auth_required' && entry?.authentication === undefined)) &&
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
    this.syncChapterSelectionActions()
    configureSourceSettingsStore(getContext(this) as common.UIAbilityContext)
    this.chrome.showTitle = false
    this.seedSourceDetailFromInitialRouteManga()
    this.syncTitleActions()
    this.loadInitialDetailWhenVisible()
    this.unsubscribeTrackingMappings = this.trackingStore().subscribeMappings(() => {
      void this.refreshTrackingAvailability()
    })
    this.refreshTrackingWhenVisible()
  }

  private chapterArchives: ChapterArchiveActions = new ChapterArchiveActions()
  @Local private chapterArchiveBusy: boolean = false

  private async exportChapter(chapterId: string, share: boolean): Promise<void> {
    if (this.chapterArchiveBusy) return
    const chapter = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)
    if (chapter === undefined) return
    const comicId = this.currentComicId()
    this.chapterArchiveBusy = true
    try {
      await this.chapterArchives.perform(getContext(this) as common.UIAbilityContext, comicId, chapterId,
        this.manga?.title ?? '', chapter.title, share, () => this.chrome.visible && this.currentComicId() === comicId)
    } catch (error) {
      DiagnosticLogger.exception('chapters', 'archive_export_failed', error as Error)
      if (this.chrome.visible) this.showToast(s('chapter_archive_failed'))
    } finally { this.chapterArchiveBusy = false }
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
    this.trackingSearchContent?.dispose()
    this.trackingSearchContent = undefined
    this.unsubscribeTrackingMappings?.()
    this.unsubscribeTrackingMappings = undefined
    this.notesEditorShown = false
    // A hidden detail route must not let an old source response repaint a later route instance.
    this.closeDetailWebChallenge()
    this.clearDetailWebChallenge()
    this.sourceDetailRequestEpoch = this.sourceDetailRequestEpoch + 1
    this.chrome.pageActionsAvailable = false
    this.chrome.sourceReloadAvailable = false
    this.chrome.relatedMangaAvailable = false
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

  @Monitor('manga', 'isInLibrary', 'sourceDetailContentState', 'localRefreshBusy', 'personalizationBusy', 'linkShareBusy')
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
    this.chrome.relatedMangaAvailable = actionsAvailable && (this.manga?.relatedManga?.length ?? 0) > 0
    this.chrome.webActionsAvailable = actionsAvailable && this.mangaWebUrl() !== undefined
    this.chrome.linkShareBusy = this.linkShareBusy
    this.chrome.localRefreshAvailable = actionsAvailable && this.canCheckLocalLibraryRefresh()
    this.chrome.localMetadataAvailable = actionsAvailable && this.canEditLocalMetadata()
    this.chrome.migrationAvailable = actionsAvailable && canMigrateLibraryComic(this.libraryStore?.getComic(this.currentComicId()))
    const comic = this.libraryStore?.getComic(this.currentComicId())
    this.personalNotes = comic?.personalNotes ?? ''
    this.chrome.personalDataAvailable = actionsAvailable && comic !== undefined
    this.chrome.coverActionsAvailable = actionsAvailable && comic !== undefined && !chapterPagesAreLocalOffline(comic.sourceKind)
    this.chrome.customCoverAvailable = comic?.customCoverUri !== undefined
    this.chrome.chapterDownloadAvailable = actionsAvailable && this.offlineDownloadService() !== undefined &&
      (comic === undefined || !chapterPagesAreLocalOffline(comic.sourceKind))
    this.chrome.personalizationBusy = this.personalizationBusy
    this.chrome.localRefreshBusy = this.localRefreshBusy
  }

  private mangaWebUrl(): string | undefined {
    const page = mangaHttpUrl(this.manga?.webUrl)
    if (page !== undefined) return page
    // Private-library sourcePath may be a feed/download URL rather than a work page.
    if ((this.manga?.sourceId?.trim() ?? '').length === 0) return undefined
    return mangaHttpUrl(this.manga?.url)
  }

  private async shareMangaLink(): Promise<void> {
    const url = this.mangaWebUrl()
    if (url === undefined || this.linkShareBusy) return
    this.linkShareBusy = true
    let controller: systemShare.ShareController | undefined = undefined
    const dismissed = (): void => {
      controller?.off('dismiss', dismissed)
      if (this.linkShareController === controller) {
        this.linkShareController = undefined
        this.linkShareBusy = false
      }
    }
    try {
      controller = new systemShare.ShareController(new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK, content: url, title: this.manga?.title ?? '',
      }))
      this.linkShareController = controller
      controller.on('dismiss', dismissed)
      await controller.show(this.getUIContext().getHostContext() as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      })
    } catch (_error) {
      dismissed()
      if (this.chrome.visible) this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: s('manga_detail_share_failed') }))
    }
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
    if (action === MangaDetailTitleAction.SELECT_CHAPTERS && this.chrome.filteredChapterIds.length > 0) {
      this.chapterPresentation.setSelectionMode(true)
      return
    }
    if (action === MangaDetailTitleAction.SELECT_ALL_CHAPTERS) {
      this.chrome.toggleFilteredChapterSelection()
      return
    }
    if (action === MangaDetailTitleAction.DOWNLOAD_SELECTED_CHAPTERS) {
      this.downloadSelectedChapters()
      return
    }
    if (action === MangaDetailTitleAction.MARK_SELECTED_CHAPTERS_READ ||
      action === MangaDetailTitleAction.MARK_SELECTED_CHAPTERS_UNREAD) {
      this.markSelectedChaptersRead(action === MangaDetailTitleAction.MARK_SELECTED_CHAPTERS_READ)
      return
    }
    if (action === MangaDetailTitleAction.DOWNLOAD_INCOMPLETE || action === MangaDetailTitleAction.RETRY_FAILED_DOWNLOADS) {
      const mode = action === MangaDetailTitleAction.DOWNLOAD_INCOMPLETE
        ? ChapterBatchDownloadMode.NOT_DOWNLOADED : ChapterBatchDownloadMode.FAILED_ONLY
      this.confirmDownloadFilteredChapters(this.chrome.filteredChapterIds, mode)
      return
    }
    if (action === MangaDetailTitleAction.SHARE_LINK && this.chrome.webActionsAvailable) {
      void this.shareMangaLink()
      return
    }
    if (action === MangaDetailTitleAction.EDIT_NOTES && this.chrome.personalDataAvailable) {
      this.notesDraft = this.personalNotes
      this.notesEditorShown = true
      return
    }
    if (action === MangaDetailTitleAction.CHANGE_COVER && this.chrome.coverActionsAvailable) {
      void this.changeCover()
      return
    }
    if (action === MangaDetailTitleAction.RESTORE_COVER && this.chrome.customCoverAvailable) {
      this.commitPersonalization(undefined, undefined, true)
      return
    }
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
    if (action === MangaDetailTitleAction.OPEN_RELATED) {
      RouterHelper.pushSourceRelated(this.manga?.relatedManga ?? [])
      return
    }
    if (action === MangaDetailTitleAction.OPEN_WEBVIEW || action === MangaDetailTitleAction.OPEN_BROWSER) {
      const url = this.mangaWebUrl()
      if (url === undefined) return
      if (action === MangaDetailTitleAction.OPEN_WEBVIEW) {
        RouterHelper.pushMangaWeb({ url, title: this.manga?.title ?? '' })
      } else {
        this.openMangaExternalLink(url)
      }
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

  private openMangaExternalLink(url: string): void {
    const context = getContext(this) as common.UIAbilityContext
    void context.startAbility({ action: 'ohos.want.action.viewData', uri: url }).catch(() => {
      this.getUIContext().getPromptAction().openToast(komaToastOptions({ message: s('manga_detail_open_browser_failed') }))
    })
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
    this.refreshDownloadStatus()
  }

  private decorateChapterStates(chapters: MangaChapterItem[]): MangaChapterItem[] {
    const comicId = this.currentComicId()
    const downloadService = this.offlineDownloadService()
    const comic = this.libraryStore?.getComic(comicId)
    const localOffline = comic !== undefined && chapterPagesAreLocalOffline(comic.sourceKind)
    return chapters.map((chapter: MangaChapterItem): MangaChapterItem => {
      const next: MangaChapterItem = {
        id: chapter.id,
        title: chapter.title,
        chapterNumber: chapter.chapterNumber,
        volumeNumber: chapter.volumeNumber,
        readingOrder: chapter.readingOrder,
        readingGroup: chapter.readingGroup,
        continuationEligible: chapter.continuationEligible,
        localReadingIndex: chapter.localReadingIndex,
        scanlator: chapter.scanlator,
        language: chapter.language,
        dateUpload: chapter.dateUpload,
        pageCount: chapter.pageCount,
        isRead: this.readerSessionStore.isChapterRead(comicId, chapter.id),
        isBookmarked: this.readerSessionStore.isChapterBookmarked(comicId, chapter.id),
        // Re-read host downloads after cleanup; the prior decorated row is not persistent truth.
        // Local archives/folders remain available independently of the download queue.
        isDownloaded: localOffline && (chapter.pageCount ?? 0) > 0,
        downloadStatus: localOffline && (chapter.pageCount ?? 0) > 0 ? 'downloaded' : undefined,
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
    const retainedChapters = retainedDetail === undefined ? [] : this.chapters.slice()
    const retainedChaptersResolved = this.sourceChaptersResolved
    const waitingForChapters = retainedDetail !== undefined && retainedChapters.length === 0 && !retainedChaptersResolved
    // Automatic revalidation must not interrupt a readable collected detail
    // with loading/error text. A synced shelf entry can have a title and
    // chapter count before it has any locally usable chapter rows.
    const backgroundRefresh = !forceReload && retainedDetail !== undefined && !waitingForChapters
    const retainedState = this.isDetailPending() ? SourceDetailContentState.READY : this.sourceDetailContentState
    const requestEpoch = this.beginSourceDetailRequest(sourceId, mangaId)
    if (retainedDetail === undefined) {
      this.sourceDetailContentState = SourceDetailContentState.LOADING
      this.sourceDetailDataResolved = false
      this.feedbackText = s('manga_detail_loading_source')
    } else {
      this.sourceDetailContentState = waitingForChapters ? SourceDetailContentState.LOADING : retainedState
      this.sourceChaptersResolved = retainedChaptersResolved
      this.feedbackText = waitingForChapters ? s('manga_detail_loading_chapters') : ''
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
        this.sourceDetailContentState = waitingForChapters ? SourceDetailContentState.ERROR : retainedState
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
      if (libraryComic?.customCoverUri) this.manga.coverUrl = libraryComic.customCoverUri
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
    if (libraryComic?.customCoverUri) nextDetail.coverUrl = libraryComic.customCoverUri
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
      const cause = error.userTextFor('')
      if (cause && ['not_found', 'content_removed', 'no_chapters'].includes(details.kind)) return cause
      return cause ? s(fallbackKey) + ' ' + cause : s(fallbackKey)
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
    const detail = parseMangaDetailFromSourceItem(entry.sourceId, item)
    detail.relatedManga = parseSourceRelatedManga(entry.sourceId, mangaId, item['relatedManga'])
    return {
      detail,
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
      relatedManga: detail.relatedManga,
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
        await new ReaderPreferencesStore(this.getUIContext().getHostContext() as common.UIAbilityContext).copyBannerOverride(comicId, '', true)
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
    if (this.sourceChaptersResolved) {
      setCompleteSourceChapterCatalog(comic, this.chapters.map((chapter: MangaChapterItem): string => chapter.id), Date.now())
    }
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
      readingFormat: readerFormatFromTags(manga.tags),
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
      this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
        title,
        message,
        autoCancel: true,
        confirm: { value: s('common_confirm'), action: () => {} },
      })
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title,
      message,
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_confirm'),
        action: () => {
          void this.handleDownloadChapters(targetChapterIds, mode)
        },
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
      await service.runChapterBatch(initialComic, targetChapterIds, async (chapterId: string): Promise<void> => {
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


  private readingSourceIdentity(): SyncReadingSource | undefined {
    const manga = this.manga
    if (manga?.sourceId === undefined) return undefined
    return { source: manga.sourceId, work: manga.id }
  }

  private markChapterReadState(chapterId: string, isRead: boolean): void {
    if (chapterId.trim().length === 0) {
      return
    }
    const result = this.readerSessionStore.commitChapterReadStates([{ comicId: this.currentComicId(), chapterId, isRead }],
      this.readingSourceIdentity())
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
    if (scope !== ChapterBatchScope.FILTERED && targetIds.length === 0) {
      return
    }
    const title = scope === ChapterBatchScope.PREVIOUS ? s('chapter_list_menu_mark_previous_read')
      : scope === ChapterBatchScope.SELECTED
      ? this.formatString(isRead ? 'chapter_list_menu_mark_selected_read' : 'chapter_list_menu_mark_selected_unread', [targetIds.length])
      : isRead ? s('chapter_list_menu_mark_filtered_read') : s('chapter_list_menu_mark_filtered_unread')
    const message = this.formatString(scope === ChapterBatchScope.PREVIOUS
      ? 'manga_detail_mark_previous_read_confirm' : scope === ChapterBatchScope.SELECTED
      ? (isRead ? 'manga_detail_mark_selected_read_confirm' : 'manga_detail_mark_selected_unread_confirm')
      : (isRead ? 'manga_detail_mark_filtered_read_confirm' : 'manga_detail_mark_filtered_unread_confirm'), [targetIds.length])
    if (targetIds.length === 0) {
      this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
        title,
        message,
        autoCancel: true,
        confirm: { value: s('common_confirm'), action: () => {} },
      })
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title,
      message,
      autoCancel: true,
      primaryButton: { value: s('common_cancel'), action: () => {} },
      secondaryButton: {
        value: s('common_confirm'),
        action: () => {
          this.markChaptersReadState(targetIds, isRead)
        },
      },
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
      this.readingSourceIdentity(),
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

  @Monitor('chrome.visible', 'manga')
  private refreshTrackingWhenVisible(): void {
    if (this.chrome.visible && this.manga !== undefined) void this.refreshTrackingAvailability()
  }

  private async refreshTrackingAvailability(): Promise<void> {
    const comicId = this.currentComicId()
    try {
      const preferences = await this.trackingStore().load()
      if (!this.chrome.visible || comicId !== this.currentComicId()) return
      this.applyTrackingPreferences(preferences, comicId)
    } catch (_) {
      // A failed background read leaves the last known button state intact.
    }
  }

  private trackingButtonHighlighted(): boolean {
    // Account availability opens the sheet; only this manga's binding lights the button.
    const comicId = this.currentComicId()
    return this.trackingMappings.some((mapping: ComicTrackerMapping): boolean =>
      mapping.comicId === comicId && mapping.mappingState === 'confirmed' && mapping.userConfirmed)
  }

  private async openTrackingSheet(): Promise<void> {
    if (this.trackerMappingBusy || this.trackingSheetShown) return
    const comicId = this.currentComicId()
    this.trackerMappingBusy = true
    try {
      const preferences = await this.trackingStore().load()
      if (!this.chrome.visible || comicId !== this.currentComicId()) return
      this.applyTrackingPreferences(preferences, comicId)
      this.trackingSearchProvider = undefined
      this.trackingBodyHeight = 0
      this.trackingSheetShown = true
      void this.loadBoundTrackingStates()
    } catch (_) {
      this.showToast(s('tracker_message_load_failed'))
    } finally {
      this.trackerMappingBusy = false
    }
  }

  private trackingStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(getContext(this) as common.UIAbilityContext, new AssetStoreTrackerCredentialSecretStore())
  }

  private trackingMapping(providerId: TrackerProviderId): ComicTrackerMapping | undefined {
    return this.trackingMappings.find((mapping: ComicTrackerMapping): boolean => mapping.providerId === providerId)
  }

  private trackingVisibleProviders(): TrackerProviderConfig[] {
    return TRACKER_PROVIDER_CONFIGS.filter((provider: TrackerProviderConfig): boolean =>
      this.trackingProviderConnected(provider.providerId) || this.trackingMapping(provider.providerId)?.mappingState === 'confirmed')
      .sort((left: TrackerProviderConfig, right: TrackerProviderConfig): number =>
        Number(this.trackingMapping(right.providerId)?.mappingState === 'confirmed') -
        Number(this.trackingMapping(left.providerId)?.mappingState === 'confirmed'))
  }

  private trackingProviderConnected(providerId: TrackerProviderId): boolean {
    return this.trackingProviders.some((provider: TrackerProviderConfig): boolean => provider.providerId === providerId)
  }

  private trackingSyncService(): TrackerProgressSyncService {
    return new TrackerProgressSyncService(getContext(this) as common.UIAbilityContext)
  }

  private applyTrackingPreferences(preferences: TrackerPreferences, comicId: string): void {
    this.trackingProviders = TRACKER_PROVIDER_CONFIGS.filter((provider: TrackerProviderConfig): boolean =>
      preferences.accounts.some(account => account.providerId === provider.providerId && account.status === 'connected'))
    this.trackingMappings = preferences.comicMappings.filter((mapping: ComicTrackerMapping): boolean =>
      mapping.comicId === comicId)
    const keys = new Map<TrackerProviderId, string>()
    const cached = new Map<TrackerProviderId, TrackerProgressSyncResult>()
    this.trackingProviders.forEach((provider: TrackerProviderConfig): void => {
      const id = provider.providerId
      const mapping = this.trackingMapping(id)
      const account = preferences.accounts.find(item => item.providerId === id && item.status === 'connected')
      if (mapping?.mappingState !== 'confirmed' || account?.credentialAccountKey === undefined) return
      const key = JSON.stringify([comicId, account.credentialAccountKey, mapping.providerTitleId, mapping.createdAt])
      keys.set(id, key)
      const state = this.trackingRemoteStates.get(id)
      if (this.trackingCacheKeys.get(id) === key && state !== undefined) cached.set(id, state)
    })
    this.trackingCacheKeys = keys
    this.trackingRemoteStates = cached
  }

  private async loadBoundTrackingStates(): Promise<void> {
    const comicId = this.currentComicId()
    const service = this.trackingSyncService()
    await Promise.all(this.trackingProviders.map(async (provider: TrackerProviderConfig): Promise<void> => {
      const id = provider.providerId
      const key = this.trackingCacheKeys.get(id)
      if (key === undefined || this.trackingRefreshes.get(id) === key) return
      const cached = this.trackingRemoteStates.get(id)
      this.trackingRefreshes.set(id, key)
      try {
        const result = await service.pullReadingProgress(comicId, Date.now(), id)
        // A refresh can finish after the sheet closes. Keep it for reopening,
        // but do not replace a newer edit or a different binding's state.
        if (result.status !== 'failed' && comicId === this.currentComicId() &&
          this.trackingCacheKeys.get(id) === key && this.trackingRemoteStates.get(id) === cached) {
          this.setTrackingRemoteState(id, result)
        }
      } catch (_) {
        // Retain the last known values when the website is unavailable.
      } finally {
        if (this.trackingRefreshes.get(id) === key) this.trackingRefreshes.delete(id)
      }
    }))
  }

  private setTrackingRemoteState(providerId: TrackerProviderId, state: TrackerProgressSyncResult): void {
    const next = new Map<TrackerProviderId, TrackerProgressSyncResult>(this.trackingRemoteStates)
    next.set(providerId, state)
    this.trackingRemoteStates = next
  }

  private trackingStatusLabel(providerId: TrackerProviderId): string {
    if (!this.trackingProviderConnected(providerId)) return s('tracker_status_disconnected')
    const state = this.trackingRemoteStates.get(providerId)
    if (state?.status !== 'synced') return ''
    if (state.completed) return s('manga_detail_tracker_finished')
    const status = state.providerStatus?.toLowerCase() ?? ''
    if (status === 'repeating' || status === 'rereading') return s('manga_detail_tracker_rereading')
    if (['current', 'reading'].includes(status) ||
      (providerId === 'bangumi' && status === '3') || (providerId === 'mangaupdates' && status === '0')) {
      return s('manga_detail_tracker_reading')
    }
    if (['planning', 'planned', 'plan_to_read'].includes(status) ||
      (providerId === 'bangumi' && status === '1') || (providerId === 'mangaupdates' && status === '1')) {
      return s('manga_detail_tracker_planned')
    }
    if (['paused', 'on_hold'].includes(status) || (providerId === 'bangumi' && status === '4')) {
      return s('manga_detail_tracker_paused')
    }
    if (status === 'dropped' || (providerId === 'bangumi' && status === '5')) return s('manga_detail_tracker_dropped')
    return s('manga_status_unknown')
  }

  private async saveTrackingProgress(provider: TrackerProviderConfig, progress: number | undefined,
    status?: string, fields?: TrackerEntryFields): Promise<void> {
    const providerId = provider.providerId
    const previous = this.trackingRemoteStates.get(providerId)
    if (this.trackerSyncBusy || previous?.status !== 'synced') return
    const comicId = this.currentComicId()
    const optimistic: TrackerProgressSyncResult = {
      status: 'synced',
      providerId,
      providerTitleId: previous.providerTitleId,
      providerProgress: progress ?? previous.providerProgress,
      providerStatus: status ?? previous.providerStatus,
      completed: status === undefined ? previous.completed : status === '2' || status.toLowerCase() === 'completed',
      volumes: fields?.volumes ?? previous.volumes,
      score: fields?.score ?? previous.score,
      startedAt: fields?.startedAt ?? previous.startedAt,
      completedAt: fields?.completedAt ?? previous.completedAt,
    }
    this.trackerSyncBusy = true
    // Apply the selected value before awaiting the website. Restore only this edit's snapshot.
    this.setTrackingRemoteState(providerId, optimistic)
    try {
      const result = await this.trackingSyncService().editComicProgress(comicId, providerId, progress, status, fields)
      if (result.status !== 'synced' ||
        (progress !== undefined && result.providerProgress !== progress) ||
        (status !== undefined && result.providerStatus?.toLowerCase() !== status.toLowerCase()) ||
        (fields?.volumes !== undefined && (result.volumes ?? 0) !== fields.volumes) ||
        (fields?.score !== undefined && (result.score ?? 0) !== fields.score) ||
        (fields?.startedAt !== undefined && result.startedAt !== fields.startedAt) ||
        (fields?.completedAt !== undefined && result.completedAt !== fields.completedAt)) {
        throw new Error('tracker_edit_failed')
      }
      if (comicId === this.currentComicId() && this.trackingRemoteStates.get(providerId) === optimistic) {
        this.setTrackingRemoteState(providerId, result)
      }
    } catch (_) {
      if (comicId === this.currentComicId() && this.trackingRemoteStates.get(providerId) === optimistic) {
        this.setTrackingRemoteState(providerId, previous)
        this.showToast(s('manga_detail_tracker_edit_failed'))
      }
    } finally {
      this.trackerSyncBusy = false
    }
  }

  private confirmTrackingUnbind(provider: TrackerProviderConfig): void {
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('manga_detail_tracker_unbind'), message: s('manga_detail_tracker_unbind_message'),
      primaryButton: { value: s('common_cancel'), action: () => {} },
      secondaryButton: { value: s('manga_detail_tracker_unbind'), fontColor: ThemeConstants.DANGER,
        action: () => { void this.unbindTrackingTitle(provider.providerId) } },
    })
  }

  private async unbindTrackingTitle(providerId: TrackerProviderId): Promise<void> {
    if (this.trackerSyncBusy) return
    const comicId = this.currentComicId()
    this.trackerSyncBusy = true
    try {
      const preferences = await this.trackingSyncService().unbindComic(comicId, providerId)
      if (comicId === this.currentComicId()) this.applyTrackingPreferences(preferences, comicId)
    } catch (_) {
      this.showToast(s('manga_detail_tracker_stop_failed'))
    } finally {
      this.trackerSyncBusy = false
    }
  }

  private startTrackingSearch(provider: TrackerProviderConfig): void {
    if (this.trackingSearchContent === undefined || this.trackingSearchContent.isDisposed()) {
      this.trackingSearchContent = new ComponentContent<SearchRouteChromeState>(this.getUIContext(),
        wrapBuilder<[SearchRouteChromeState]>(TrackerSearchTitleFieldContentBuilder), this.trackingSearchChrome)
    }
    this.trackingSearchChrome.query = this.trackingMapping(provider.providerId)?.providerTitle ?? this.manga?.title ?? ''
    this.trackingSearchProvider = provider
    void this.searchTrackingTitles()
  }

  @Monitor('trackingSearchChrome.queryChangeSeq')
  private onTrackingSearchQueryChange(): void {
    this.trackingSelection = undefined
  }

  @Monitor('trackingSearchChrome.querySubmitSeq')
  private onTrackingSearchQuerySubmit(): void {
    void this.searchTrackingTitles()
  }

  private async searchTrackingTitles(): Promise<void> {
    const provider = this.trackingSearchProvider
    const query = this.trackingSearchChrome.query.trim()
    if (provider === undefined || query.length === 0 || this.trackerMappingBusy) return
    this.trackingSelection = undefined
    this.trackingResults = []
    this.trackingSearchMessage = ''
    this.trackerMappingBusy = true
    try {
      const result = await new TrackerMappingSearchService(getContext(this) as common.UIAbilityContext)
        .searchComicTitles(provider.providerId, query)
      this.trackingResults = result ?? []
      this.trackingSearchMessage = result === undefined ? s('manga_detail_tracker_mapping_failed') :
        result.length === 0 ? s('manga_detail_tracker_mapping_not_found') : ''
    } catch (_) {
      this.trackingSearchMessage = s('manga_detail_tracker_mapping_failed')
    } finally {
      this.trackerMappingBusy = false
    }
  }

  private async bindTrackingTitle(): Promise<void> {
    const selected = this.trackingSelection
    if (selected === undefined || this.trackerMappingBusy) return
    const comicId = this.currentComicId()
    const now = Date.now()
    this.trackerMappingBusy = true
    try {
      const local = this.localTrackerReadingProgress()
      const localProgress = local === undefined ? 0 : this.trackerProgressCount(local) ?? 0
      const result = await this.trackingSyncService().bindComic({
        comicId, providerId: selected.providerId, providerTitleId: selected.providerTitleId,
        providerTitle: selected.title, mappingState: 'confirmed', userConfirmed: true,
        createdAt: this.trackingMapping(selected.providerId)?.createdAt ?? now, updatedAt: now,
      }, localProgress)
      if (result.status !== 'synced') {
        this.showToast(s('manga_detail_tracker_start_failed'))
        return
      }
      await this.refreshTrackingAvailability()
      if (comicId !== this.currentComicId()) return
      this.setTrackingRemoteState(selected.providerId, result)
      this.trackingSearchProvider = undefined
      this.trackingSelection = undefined
    } catch (_) {
      this.showToast(s('manga_detail_tracker_start_failed'))
    } finally {
      this.trackerMappingBusy = false
    }
  }

  private localTrackerReadingProgress(): ReadingProgress | undefined {
    const comicId = this.currentComicId()
    const markedIds = this.chapters.filter((chapter: MangaChapterItem): boolean =>
      this.readerSessionStore.isChapterRead(comicId, chapter.id)).map((chapter: MangaChapterItem): string => chapter.id)
    // Resume location and completed chapters are stored independently.
    return this.latestTrackableMarkedReadProgress(markedIds) ?? this.currentReadingProgress()
  }

  private async syncTrackerProgressNow(providerId: TrackerProviderId): Promise<void> {
    if (this.trackerSyncBusy) {
      return
    }
    DiagnosticLogger.info('manga_detail_page', 'manual_tracker_upload', 'start provider=' + providerId)
    const progress = this.localTrackerReadingProgress()
    if (progress === undefined) {
      this.showToast(s('manga_detail_tracker_sync_no_local_reading'))
      return
    }
    this.trackerSyncBusy = true

    try {
      const context = getContext(this) as common.UIAbilityContext
      const result = await new TrackerProgressSyncService(context).pushReadingProgress(
        progress,
        this.allChapterIds(),
        'manual', Date.now(), providerId, this.trackerProgressCount(progress) ?? null,
      )
      DiagnosticLogger.info('manga_detail_page', 'manual_tracker_upload',
        `provider=${providerId} status=${result.status} reason=${result.reason ?? 'none'} queued=${result.queued === true}`)
      if (result.status === 'synced') {
        this.setTrackingRemoteState(providerId, result)
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

  private async pullTrackerProgressNow(providerId: TrackerProviderId): Promise<void> {
    if (this.trackerSyncBusy) {
      return
    }
    this.trackerSyncBusy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const result = await new TrackerProgressSyncService(context).pullReadingProgress(this.currentComicId(), Date.now(), providerId)
      console.info(`[TrackerSync] step=manual_pull_progress status=${result.status} reason=${result.reason ?? 'none'}`)
      if (result.status !== 'failed') this.setTrackingRemoteState(providerId, result)
      if (result.status === 'synced') {
        const count = result.providerProgress ?? 0
        const comicId = this.currentComicId()
        const matchingIds = this.chapters.filter((chapter: MangaChapterItem): boolean => {
          const number = chapter.chapterNumber
          return count > 0 && number !== undefined && Number.isFinite(number) && number > 0 && number <= count
        }).map((chapter: MangaChapterItem): string => chapter.id)
        const targetIds = matchingIds.filter((id: string): boolean => !this.readerSessionStore.isChapterRead(comicId, id))
        if (targetIds.length === 0) {
          this.showToast(s(count <= 0 ? 'manga_detail_tracker_pull_empty' :
            matchingIds.length === 0 ? 'manga_detail_tracker_pull_no_match' : 'manga_detail_tracker_pull_up_to_date'))
          return
        }
        this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
          title: s('manga_detail_menu_pull_tracker'),
          message: this.formatString('manga_detail_tracker_pull_confirm', [targetIds.length]),
          primaryButton: { value: s('common_cancel'), action: () => {} },
          secondaryButton: { value: s('common_confirm'), action: () => {
            if (comicId !== this.currentComicId()) return
            // Import only read facts. Keep the resume location and do not echo them back to trackers.
            const saved = this.readerSessionStore.commitChapterReadStates(
              targetIds.map((chapterId: string): ChapterReadMutation => ({ comicId, chapterId, isRead: true })),
              this.readingSourceIdentity())
            if (!saved.committed) {
              this.showToast(s('reader_progress_save_failed'))
              return
            }
            this.applyChapterStatesToCurrent()
            this.onReadingStateChanged()
            this.showToast(s('manga_detail_tracker_pull_done'))
          } },
        })
        return
      }
      if (result.reason === 'remote_progress_missing') {
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
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (_err) {
    }
  }

  private visibleCoverUrl(manga: MangaDetail): string {
    const custom = this.libraryStore?.getComic(this.currentComicId())?.customCoverUri
    if (custom) return custom
    // Keep Manhuaren's route preview stable while the provider's higher-resolution
    // detail cover remains available to the source snapshot and shelf.
    if (manga.sourceId === 'com.manhuaren.koma') {
      const preview = this.validInitialRouteManga(manga.sourceId, manga.id)?.coverUrl?.trim()
      if (preview && !preview.includes('/nopic.jpg')) return preview
    }
    return manga.coverUrl ?? ''
  }

  private displayedManga(manga: MangaDetail): MangaDetail {
    return {
      id: manga.id,
      title: manga.title,
      author: manga.author,
      artist: manga.artist,
      contentRating: manga.contentRating,
      description: manga.description,
      coverUrl: this.visibleCoverUrl(manga),
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
      if (this.isDetailPending()) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          LoadingProgress().width(20).height(20).color(ThemeConstants.BRAND_PRIMARY)
          Text(s('manga_detail_loading_chapters'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
        .height(ThemeConstants.ACTION_CHIP_HEIGHT)
        .justifyContent(FlexAlign.Center)
      } else if (this.progressChapterId() === undefined) {
        KomaActionButton({
          label: this.primaryReadLabel(),
          kind: 'primary',
          icon: $r('sys.symbol.doc_plaintext'),
          fullWidth: true,
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.hasReadableChapters() && !this.isDetailPending(),
          action: () => {
            this.handleStartReading()
          },
        })
      } else {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          if (this.hasReadableChapters() && !this.isDetailPending()) {
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
          .backgroundColor(this.hasReadableChapters() && !this.isDetailPending()
            ? ThemeConstants.BRAND_PRIMARY : undefined)
          .borderRadius(ThemeConstants.ACTION_CHIP_HEIGHT / 2)
          .opacity(1)
          .enabled(this.hasReadableChapters() && !this.isDetailPending())
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
          isEnabled: this.firstChapterId() !== undefined && !this.downloadBusy && !this.isDetailPending(),
          action: () => {
            this.handleDownloadChapter()
          },
        })

        if (this.canAddCurrentMangaToLibrary()) {
          KomaIconButton({
            icon: $r('sys.symbol.arrow_2_circlepath'),
            kind: this.trackingButtonHighlighted() ? 'primary' : 'secondary',
            controlSize: ThemeConstants.ACTION_CHIP_HEIGHT,
            iconSize: ThemeConstants.FONT_SIZE_TITLE,
            iconWeight: FontWeight.Bold,
            isEnabled: !this.trackerMappingBusy,
            action: () => { void this.openTrackingSheet() },
          })
            .accessibilityText(s('settings_pane_tracking_title'))
          KomaIconButton({
            icon: this.isInLibrary ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
            kind: this.isInLibrary ? 'primary' : 'secondary',
            controlSize: ThemeConstants.ACTION_CHIP_HEIGHT,
            iconSize: ThemeConstants.FONT_SIZE_TITLE,
            // Match the adjacent tracking glyph's weight while the bookmark is outlined.
            iconWeight: this.isInLibrary ? FontWeight.Normal : FontWeight.Bold,
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
    if (this.hasReadableChapters() && !this.isDetailPending()) {
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

  private trackingSheetHeight(): number {
    const estimatedBody = Math.max(1, this.trackingProviders.length) * ThemeConstants.TITLE_BAR_HEIGHT
    const content = this.trackingBodyHeight > 0 ? this.trackingBodyHeight : estimatedBody
    const searchHeight = this.trackingSearchProvider === undefined ? 0 : SEARCH_TITLE_BOTTOM_HEIGHT
    const chrome = ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD + this.detailSafeArea.bottomAvoidHeight + searchHeight
    const limit = this.trackingViewportHeight > 0 ? this.trackingViewportHeight * 0.8 : 520
    // The system clamps centered sheets to 90% of the window's short side.
    // Give the inner list the same bounds so the outer sheet cannot scroll its title away.
    const centeredLimit = this.trackingSheetType === SheetType.CENTER && this.detailContentWidth > 0
      ? Math.floor(Math.min(this.detailContentWidth, this.trackingViewportHeight) * 0.9) : limit
    return Math.min(Math.ceil(content + chrome), limit, centeredLimit)
  }

  @Builder
  private TrackingSheet() {
    Column() {
      KomaModalScaffold({
        title: this.trackingSearchProvider?.displayName ??
          s('settings_pane_tracking_title'),
        contentScrollsUnderTitle: this.trackingSearchProvider !== undefined,
        keepScrollInContent: this.trackingSearchProvider !== undefined,
        titleBottom: this.trackingSearchProvider === undefined ? undefined : {
          builder: () => {},
          builderComponent: this.trackingSearchContent,
          height: SEARCH_TITLE_BOTTOM_HEIGHT,
          showType: BottomBuilderShowType.DIRECTLY_SHOW,
        },
        confirmLabel: this.trackingSearchProvider === undefined ? undefined : s('manga_detail_tracker_bind'),
        confirmEnabled: this.trackingSelection !== undefined && !this.trackerMappingBusy,
        onClose: () => {
          if (this.trackerMappingBusy || this.trackerSyncBusy) return
          if (this.trackingSearchProvider !== undefined) this.trackingSearchProvider = undefined
          else this.trackingSheetShown = false
        },
        onConfirm: () => { void this.bindTrackingTitle() },
      }) {
        if (this.trackingSearchProvider !== undefined) {
          this.TrackingSearchContent()
        } else {
          ListItem() {
            Column({ space: ThemeConstants.SPACE_SM }) {
              if (this.trackingVisibleProviders().length === 0) {
                ConciseListRow({
                  title: s('manga_detail_tracker_mapping_account_missing'),
                  showChevron: true,
                  action: () => { this.trackingSheetShown = false; RouterHelper.pushTrackerSettings() },
                })
              } else {
                GroupedListSection() {
                  ForEach(this.trackingVisibleProviders(), (provider: TrackerProviderConfig, index: number) => {
                    this.TrackingProviderRow(provider)
                    if (index < this.trackingVisibleProviders().length - 1) ListDivider()
                  }, (provider: TrackerProviderConfig): string => provider.providerId)
                }
              }
            }
            .width('100%')
            .onSizeChange((_old: SizeOptions, size: SizeOptions): void => {
              const height = Math.ceil(Number(size.height))
              if (height > 0 && height !== this.trackingBodyHeight) this.trackingBodyHeight = height
            })
          }
        }
      }
    }
    // The sheet fits this measured root on tablets. The bottom detent uses the same height.
    .width('100%')
    .height(this.trackingSheetHeight())
  }

  @Builder
  private TrackingSearchContent() {
    ListItemGroup({ space: ThemeConstants.SPACE_SM }) {
      if (this.trackerMappingBusy && this.trackingResults.length === 0) {
        ListItem() {
          Column() {
            LoadingProgress()
              .width(ThemeConstants.LOADING_SIZE_LARGE)
              .height(ThemeConstants.LOADING_SIZE_LARGE)
              .color(ThemeConstants.BRAND_PRIMARY)
          }
          .width('100%')
          .height(ThemeConstants.TITLE_BAR_HEIGHT)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
      } else if (this.trackingSearchMessage.length > 0) {
        ListItem() {
          Text(this.trackingSearchMessage).fontColor(ThemeConstants.TEXT_SECONDARY)
        }
      }
      ForEach(this.trackingResults, (result: TrackerTitleSearchCandidate) => {
        ListItem() {
          this.TrackingResultCard(result)
        }
      }, (result: TrackerTitleSearchCandidate): string => result.providerTitleId)
    }
    .onSizeChange((_old: SizeOptions, size: SizeOptions): void => {
      const height = Math.ceil(Number(size.height))
      if (height > 0 && height !== this.trackingBodyHeight) this.trackingBodyHeight = height
    })
  }

  private trackingResultMetadata(result: TrackerTitleSearchCandidate): string {
    const details: string[] = []
    const format = result.format?.toLowerCase()
    if (format === 'manga') details.push(s('manga_detail_tracker_format_manga'))
    else if (format === 'one_shot' || format === 'oneshot') details.push(s('manga_detail_tracker_format_one_shot'))
    else if (result.format && !/^[a-z_]+$/i.test(result.format)) details.push(result.format)
    const status = result.status?.toLowerCase()
    if (status === 'finished' || status === 'finished_publishing') details.push(s('manga_status_completed'))
    else if (status === 'releasing' || status === 'currently_publishing' || status === 'current') {
      details.push(s('manga_status_ongoing'))
    } else if (status === 'hiatus') details.push(s('manga_status_hiatus'))
    else if (status === 'cancelled') details.push(s('manga_status_cancelled'))
    if (result.startYear && /^\d{4}$/.test(result.startYear)) details.push(result.startYear)
    if (result.chapterCount && result.chapterCount > 0) {
      details.push(this.formatString('manga_detail_tracker_chapter_count', [result.chapterCount]))
    }
    return details.join(' · ')
  }

  @Builder
  private TrackingResultCard(result: TrackerTitleSearchCandidate) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.bookmark'))
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontColor([ThemeConstants.TEXT_TERTIARY])
          if (result.coverImageUrl?.startsWith('https://')) {
            CachedCoverImage({ uri: result.coverImageUrl })
              .width('100%').height('100%')
          }
        }
        .width(60).height(88)
        .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
        .borderRadius(ThemeConstants.RADIUS_COVER)
        .clip(true)
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(result.title).fontSize(ThemeConstants.FONT_SIZE_TITLE).fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (result.nativeTitle && result.nativeTitle !== result.title) {
            Text(result.nativeTitle).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.trackingResultMetadata(result).length > 0) {
            Text(this.trackingResultMetadata(result)).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.trackingSelection?.providerTitleId === result.providerTitleId) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontColor([ThemeConstants.BRAND_PRIMARY])
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      if (result.summary?.trim()) {
        Text(result.summary.replace(/<[^>]*>/g, '').trim()).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .border({
      width: 1,
      color: this.trackingSelection?.providerTitleId === result.providerTitleId ?
        ThemeConstants.BRAND_PRIMARY : Color.Transparent
    })
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => { this.trackingSelection = result })
  }

  private trackingWebsiteUrl(providerId: TrackerProviderId): string | undefined {
    const id = this.trackingMapping(providerId)?.providerTitleId
    if (id === undefined || !/^\d+$/.test(id)) return undefined
    if (providerId === 'anilist') return `https://anilist.co/manga/${id}`
    if (providerId === 'myanimelist') return `https://myanimelist.net/manga/${id}`
    if (providerId === 'bangumi') return `https://bgm.tv/subject/${id}`
    return undefined
  }

  private openTrackingWebsite(providerId: TrackerProviderId): void {
    const uri = this.trackingWebsiteUrl(providerId)
    if (uri === undefined) return
    const context = getContext(this) as common.UIAbilityContext
    void context.startAbility({ action: 'ohos.want.action.viewData', uri }).catch(() => {
      this.showToast(s('manga_detail_open_browser_failed'))
    })
  }

  @Builder
  private TrackingProviderMenu(provider: TrackerProviderConfig) {
    Menu() {
      if (this.trackingWebsiteUrl(provider.providerId) !== undefined) {
        MenuItem({ content: s('manga_detail_tracker_view_website') })
          .onClick(() => { this.openTrackingWebsite(provider.providerId) })
      }
      if (this.trackingProviderConnected(provider.providerId)) {
        MenuItem({ content: s('manga_detail_tracker_change_title') }).onClick(() => { this.startTrackingSearch(provider) })
        MenuItem({ content: s('manga_detail_menu_sync_tracker') }).onClick(() => { void this.syncTrackerProgressNow(provider.providerId) })
        MenuItem({ content: s('manga_detail_menu_pull_tracker') }).onClick(() => { void this.pullTrackerProgressNow(provider.providerId) })
      }
      MenuItem({ content: s('manga_detail_tracker_unbind') }).onClick(() => { this.confirmTrackingUnbind(provider) })
    }
  }

  @Builder
  private TrackingProviderRow(provider: TrackerProviderConfig) {
    if (this.trackingMapping(provider.providerId)?.mappingState === 'confirmed') {
      Column() {
        ConciseListRow({
          title: this.trackingMapping(provider.providerId)?.providerTitle ?? provider.displayName,
          leadingImage: TRACKER_BRAND_IMAGES[provider.providerId],
          leadingImageSize: ThemeConstants.SOURCE_LIST_ICON_SIZE,
          leadingImageRadius: ThemeConstants.SOURCE_LIST_ICON_RADIUS,
          subtitle: provider.displayName,
          showChevron: false,
          trailingIcon: $r('sys.symbol.dot_grid_2x2'),
          trailingIconAction: () => { this.trackingMenuProvider = provider.providerId },
        })
        .bindMenu(this.trackingMenuProvider === provider.providerId, this.TrackingProviderMenu(provider),
          komaMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: () => { this.trackingMenuProvider = undefined },
          }))
        if (this.trackingStatusLabel(provider.providerId).length > 0) this.TrackingProgressControls(provider)
      }
    } else {
      ConciseListRow({
        title: provider.displayName,
        leadingImage: TRACKER_BRAND_IMAGES[provider.providerId],
        leadingImageSize: ThemeConstants.SOURCE_LIST_ICON_SIZE,
        leadingImageRadius: ThemeConstants.SOURCE_LIST_ICON_RADIUS,
        trailingText: s('manga_detail_tracker_start'),
        action: () => { this.startTrackingSearch(provider) },
      })
    }
  }

  private trackingStatusValues(providerId: TrackerProviderId): string[] {
    if (providerId === 'bangumi') return ['1', '3', '2', '4', '5']
    if (providerId === 'anilist') return ['PLANNING', 'CURRENT', 'COMPLETED', 'PAUSED', 'DROPPED', 'REPEATING']
    if (providerId === 'myanimelist') return ['plan_to_read', 'reading', 'completed', 'on_hold', 'dropped']
    return []
  }

  private openTrackingStatusMenu(provider: TrackerProviderConfig): void {
    if (this.trackerSyncBusy) return
    const providerId = provider.providerId
    const state = this.trackingRemoteStates.get(providerId)
    const progress = state?.providerProgress
    if (progress === undefined) return
    const labels = [s('manga_detail_tracker_planned'), s('manga_detail_tracker_reading'),
      s('manga_detail_tracker_finished'), s('manga_detail_tracker_paused'),
      s('manga_detail_tracker_dropped'), s('manga_detail_tracker_rereading')]
    const items = this.trackingStatusValues(providerId).map((status: string, index: number): KomaMenuAction => ({
      label: labels[index],
      selected: status.toLowerCase() === state?.providerStatus?.toLowerCase(),
      action: () => { void this.saveTrackingProgress(provider, undefined, status) },
    }))
    this.trackingStatusMenu.open(this.getUIContext(), 'tracking-status-' + providerId,
      () => [{ id: 'tracking-status', items }], () => { this.showToast(s('manga_detail_tracker_sync_failed')) })
  }

  private openTrackingNumberPicker(provider: TrackerProviderConfig, field: TrackingNumberField): void {
    const state = this.trackingRemoteStates.get(provider.providerId)
    const progress = state?.providerProgress
    if (progress === undefined || this.trackerSyncBusy || !this.trackingProviderConnected(provider.providerId)) return
    const selected = field === 'chapters' ? progress : field === 'volumes' ? state?.volumes ?? 0 : state?.score ?? 0
    const max = field === 'score' ? (provider.providerId === 'anilist' ? 100 : 10)
      : Math.max(field === 'volumes' ? 200 : 1000, selected + 100, this.chapters.length)
    const range = Array.from({ length: max + 1 }, (_: string, index: number): string => String(index))
    this.getUIContext().showTextPickerDialog({
      systemMaterial: komaDialogMaterial(),
      selectedTextStyle: { color: ThemeConstants.BRAND_PRIMARY },
      acceptButtonStyle: { fontColor: ThemeConstants.BRAND_PRIMARY },
      cancelButtonStyle: { fontColor: ThemeConstants.TEXT_SECONDARY },
      range,
      selected: Math.min(max, Math.floor(selected)),
      canLoop: false,
      onAccept: (result: TextPickerResult): void => {
        const value = Number(result.value)
        if (!Number.isSafeInteger(value) || value === selected) return
        if (field === 'chapters') void this.saveTrackingProgress(provider, value)
        else {
          const fields: TrackerEntryFields = field === 'volumes' ? { volumes: value } : { score: value }
          void this.saveTrackingProgress(provider, undefined, undefined, fields)
        }
      },
    })
  }

  private openTrackingDatePicker(provider: TrackerProviderConfig, start: boolean): void {
    const state = this.trackingRemoteStates.get(provider.providerId)
    const progress = state?.providerProgress
    if (progress === undefined || this.trackerSyncBusy || !this.trackingProviderConnected(provider.providerId)) return
    const value = start ? state?.startedAt : state?.completedAt
    const date = value ? new Date(value + 'T12:00:00') : new Date()
    this.getUIContext().showDatePickerDialog({
      systemMaterial: komaDialogMaterial(),
      selectedTextStyle: { color: ThemeConstants.BRAND_PRIMARY },
      acceptButtonStyle: { fontColor: ThemeConstants.BRAND_PRIMARY },
      cancelButtonStyle: { fontColor: ThemeConstants.TEXT_SECONDARY },
      selected: Number.isNaN(date.getTime()) ? new Date() : date,
      onDateAccept: (selected: Date): void => {
        const dateValue = `${selected.getFullYear()}-${String(selected.getMonth() + 1).padStart(2, '0')}-${String(selected.getDate()).padStart(2, '0')}`
        const fields: TrackerEntryFields = start ? { startedAt: dateValue } : { completedAt: dateValue }
        void this.saveTrackingProgress(provider, undefined, undefined, fields)
      },
    })
  }

  private trackingFieldWidth(providerId: TrackerProviderId): number {
    const minimum = 108
    const gap = ThemeConstants.SPACE_SM
    const padding = ThemeConstants.SPACE_LG
    const width = this.trackingFieldGridWidth
    if (width <= 0) return minimum
    const fieldCount = providerId === 'bangumi' ? 4 :
      providerId === 'anilist' || providerId === 'myanimelist' ? 6 : 2
    const columns = Math.min(fieldCount, gridColumnCount(width, minimum, gap, padding))
    return Math.floor((width - padding * 2 - (columns - 1) * gap) / columns)
  }

  @Builder
  private TrackingField(providerId: TrackerProviderId, label: string, readValue: () => string, action: () => void, anchorId: string = '',
    hasMenu: boolean = false) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(label).fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor(ThemeConstants.TEXT_SECONDARY)
      // Evaluate the value in this node's update scope. A precomputed
      // string passed by value to @Builder stays frozen after an edit.
      KomaActionButton({ label: readValue(), kind: 'secondary', fullWidth: true,
        icon: hasMenu ? $r('sys.symbol.arrowtriangle_down_fill') : undefined, action })
        .id(anchorId)
    }.width(this.trackingFieldWidth(providerId)).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private TrackingProgressControls(provider: TrackerProviderConfig) {
    // Like the reference tracker card, equal fields flow according to the card width.
    Flex({ wrap: FlexWrap.Wrap, space: {
      main: LengthMetrics.vp(ThemeConstants.SPACE_SM),
      cross: LengthMetrics.vp(ThemeConstants.SPACE_SM),
    } }) {
      this.TrackingField(provider.providerId, s('manga_detail_local_metadata_field_status'), () => this.trackingStatusLabel(provider.providerId),
        () => { this.openTrackingStatusMenu(provider) }, 'tracking-status-' + provider.providerId,
        this.trackingStatusValues(provider.providerId).length > 0 && this.trackingProviderConnected(provider.providerId))
      this.TrackingField(provider.providerId, s('manga_detail_tracker_read_chapters'),
        () => this.formatString('manga_detail_tracker_chapter_count',
          [this.trackingRemoteStates.get(provider.providerId)?.providerProgress ?? 0]),
        () => { this.openTrackingNumberPicker(provider, 'chapters') })
      if (provider.providerId === 'bangumi' || provider.providerId === 'anilist' || provider.providerId === 'myanimelist') {
        this.TrackingField(provider.providerId, s('manga_detail_tracker_read_volumes'),
          () => String(this.trackingRemoteStates.get(provider.providerId)?.volumes ?? 0),
          () => { this.openTrackingNumberPicker(provider, 'volumes') })
        this.TrackingField(provider.providerId, s('manga_detail_tracker_score'),
          () => this.trackingRemoteStates.get(provider.providerId)?.score
            ? String(this.trackingRemoteStates.get(provider.providerId)?.score) : s('manga_detail_tracker_unset'),
          () => { this.openTrackingNumberPicker(provider, 'score') })
      }
      if (provider.providerId === 'anilist' || provider.providerId === 'myanimelist') {
        this.TrackingField(provider.providerId, s('manga_detail_tracker_started'),
          () => this.trackingRemoteStates.get(provider.providerId)?.startedAt || s('manga_detail_tracker_unset'),
          () => { this.openTrackingDatePicker(provider, true) })
        this.TrackingField(provider.providerId, s('manga_detail_tracker_completed_date'),
          () => this.trackingRemoteStates.get(provider.providerId)?.completedAt || s('manga_detail_tracker_unset'),
          () => { this.openTrackingDatePicker(provider, false) })
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_MD })
    .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
      const width = Number(size.width)
      if (width > 0 && width !== this.trackingFieldGridWidth) this.trackingFieldGridWidth = width
    })
  }

  @Builder
  private NotesEditor() {
    KomaModalScaffold({ title: s('manga_notes'), contentHorizontalPadding: ThemeConstants.SPACE_LG,
      confirmLabel: s('common_save'), onClose: (): void => { this.notesEditorShown = false }, onConfirm: (): void => {
        if (this.commitPersonalization(this.notesDraft.trim(), undefined)) this.notesEditorShown = false
      } }) {
      ListItem() {
        TextArea({ text: this.notesDraft, placeholder: s('manga_notes_placeholder') })
          .height(240).fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_PRIMARY).backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
          .onChange((value: string): void => { this.notesDraft = value })
      }
    }
  }

  private commitPersonalization(notes: string | undefined, cover: string | undefined,
    reset: boolean = false, baseline?: Comic): boolean {
    const comic = baseline ?? this.libraryStore?.getComic(this.currentComicId())
    if (comic === undefined || this.libraryStore === undefined || this.libraryPersistenceService === undefined) return false
    try {
      saveComicPersonalization(this.libraryStore, this.libraryPersistenceService, comic, notes, cover, reset)
      const updated = this.libraryStore.getComic(comic.id)!
      this.personalNotes = updated.personalNotes ?? ''
      if (this.manga !== undefined) {
        const detail = JSON.parse(JSON.stringify(this.manga)) as MangaDetail
        detail.coverUrl = updated.coverUri
        this.manga = detail
      }
      this.syncTitleActions()
      this.onLibraryChanged()
      return true
    } catch (error) {
      DiagnosticLogger.exception('manga', 'personalization_save_failed', error as Error)
      this.showToast(s('manga_personalization_failed'))
      return false
    }
  }

  private async changeCover(): Promise<void> {
    const baseline = this.libraryStore?.getComic(this.currentComicId())
    if (baseline === undefined || this.personalizationBusy) return
    const context = getContext(this) as common.UIAbilityContext
    this.personalizationBusy = true
    let selected: string | undefined
    let committed = false
    try {
      selected = await selectComicCover(context)
      if (selected !== undefined && this.chrome.visible) committed = this.commitPersonalization(undefined, selected, false, baseline)
    } catch (error) {
      DiagnosticLogger.exception('manga', 'cover_selection_failed', error as Error)
      if (this.chrome.visible) this.showToast(s('manga_personalization_failed'))
    } finally {
      if (selected !== undefined && !committed) await discardUncommittedComicCover(context, selected)
      this.personalizationBusy = false
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
  private DetailPendingState(chaptersOnly: boolean = false) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color(ThemeConstants.BRAND_PRIMARY)
      Text(s(chaptersOnly ? 'manga_detail_loading_chapters' : 'manga_detail_loading_source'))
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
    if (this.manga !== undefined && this.visibleCoverUrl(this.manga).length > 0) {
      Stack() {
        Column() {
          CachedCoverImage({
            uri: this.visibleCoverUrl(this.manga),
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
  private DetailInformationItems() {
    if (this.manga !== undefined) {
      ListItem() {
        MangaDetailHeader({
          manga: this.displayedManga(this.manga),
          showChapterCount: this.shouldShowChapterCount(),
          sourceKind: this.libraryStore?.getComic(this.currentComicId())?.sourceKind,
          remoteServerId: this.libraryStore?.getComic(this.currentComicId())?.remoteServerId ?? '',
          onSourceClick: (): void => {
            const sourceId = this.manga?.sourceId
            const name = this.manga?.sourceName
            if (sourceId && name) RouterHelper.openSearch({ librarySource: { key: `source:${sourceId}`, name } })
          },
        })
      }
    }

    // Once metadata is visible, keep the final action row in place
    // while the chapter request completes.
    if (this.shouldRenderDetailActions() || this.shouldRenderDetailMetadata()) {
      ListItem() {
        this.ActionButtons()
      }
    } else if (this.isDetailPending()) {
      ListItem() {
        this.DetailPendingState()
      }
    }

    if ((!this.usesDetailPanes || this.shouldRenderChapterList()) && !this.isDetailPending() && this.feedbackText.length > 0) {
      ListItem() {
        this.DetailFailureFeedback()
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
        if (this.personalNotes.trim().length > 0) {
          ListItem() {
            MangaDescriptionSection({ description: this.personalNotes, titleKey: 'manga_notes',
              expandOnlyWhenOverflow: true })
          }
        }
        ListItem() {
          MangaDescriptionSection({
            description: this.manga.description,
            formatSynopsis: true,
            onLinkClick: (url: string) => { this.openMangaExternalLink(url) },
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
  }

  @Builder
  private DetailChapterItems() {
    if (this.shouldRenderChapterList()) {
      ChapterListSection({
        comicId: this.currentComicId(),
        presentation: this.chapterPresentation,
        onDisplayOrderChange: (chapterIds: string[]) => { this.chrome.filteredChapterIds = chapterIds },
        archiveBusy: this.chapterArchiveBusy,
        chapters: this.chapters,
        onExportChapter: (chapterId: string, share: boolean) => { void this.exportChapter(chapterId, share) },
        onBookmarkChapter: (chapterId: string, bookmarked: boolean) => {
          if (this.readerSessionStore.commitChapterBookmark(this.currentComicId(), chapterId, bookmarked, this.readingSourceIdentity())) {
            this.applyChapterStatesToCurrent()
            this.onReadingStateChanged()
          } else this.showToast(s('chapter_bookmark_save_failed'))
        },
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
        onMarkChapterReadState: (chapterId: string, isRead: boolean) => {
          this.markChapterReadState(chapterId, isRead)
        },
        onMarkFilteredChaptersReadState: (chapterIds: string[], isRead: boolean, scope: ChapterBatchScope) => {
          this.confirmMarkFilteredChaptersReadState(chapterIds, isRead, scope)
        },
      })
    } else if (this.usesDetailPanes && this.isDetailPending()) {
      ListItem() {
        this.DetailPendingState(this.sourceDetailDataResolved)
      }
    } else if (this.usesDetailPanes && this.feedbackText.length > 0) {
      ListItem() {
        this.DetailFailureFeedback()
      }
    }
  }

  private chapterGroupIndex(inChapterPane: boolean): number {
    if (inChapterPane) return 1 // SecondaryListScaffold owns the first inset row.
    let index = 1
    if (this.manga !== undefined) index++
    if (this.shouldRenderDetailActions() || this.shouldRenderDetailMetadata() || this.isDetailPending()) index++
    if (!this.isDetailPending() && this.feedbackText.length > 0) index++
    if (this.localRefreshText.length > 0) index++
    if (this.hasResolvedManga() && this.localMetadataEditorVisible) index++
    if (this.shouldRenderDetailMetadata()) index += this.personalNotes.trim().length > 0 ? 3 : 2
    return index
  }

  private onChapterViewport(start: VisibleListContentInfo, inChapterPane: boolean): void {
    if (inChapterPane !== this.usesDetailPanes || !this.shouldRenderChapterList()) return
    const groupIndex = this.chapterGroupIndex(inChapterPane)
    if (this.chapterToRestore.length > 0 && this.chrome.filteredChapterIds.length > 0) {
      const target = this.chrome.filteredChapterIds.indexOf(this.chapterToRestore)
      this.chapterToRestore = ''
      if (target >= 0) {
        const scroller = inChapterPane ? this.chapterScroller : this.detailScroller
        scroller.scrollToItemInGroup(groupIndex, target, false, ScrollAlign.START)
        return
      }
    }
    const row = start.itemIndexInGroup
    this.visibleChapterId = start.index === groupIndex && row !== undefined
      ? this.chrome.filteredChapterIds[row] ?? '' : ''
  }

  private onInformationScroll(offset: number): void {
    this.detailScrollOffset = offset
    const showTitle = offset > 160
    if (this.chrome.showTitle !== showTitle) this.chrome.showTitle = showTitle
  }

  private selectedChapterIds(): string[] {
    return this.chrome.filteredChapterIds.filter((id: string): boolean => this.chapterPresentation.selectedChapterIds.has(id))
  }

  private downloadSelectedChapters(): void {
    if (!this.chapterPresentation.selectionMode || !this.chrome.chapterDownloadAvailable) return
    this.confirmDownloadFilteredChapters(this.selectedChapterIds(), ChapterBatchDownloadMode.NOT_DOWNLOADED,
      ChapterBatchScope.SELECTED)
  }

  private markSelectedChaptersRead(isRead: boolean): void {
    if (!this.chapterPresentation.selectionMode) return
    this.confirmMarkFilteredChaptersReadState(this.selectedChapterIds(), isRead, ChapterBatchScope.SELECTED)
  }

  private chapterListBottomPadding(): number {
    return ThemeConstants.SPACE_XL + (this.chapterPresentation.selectionMode ? this.chapterActionBarHeight : 0)
  }

  @Monitor('chrome.chapterPresentation.selectedChapterIds', 'chrome.chapterDownloadAvailable',
    'downloadBusy', 'languageState.effectiveLocale')
  private syncChapterSelectionActions(): void {
    const hasSelection = this.chapterPresentation.selectedChapterIds.size > 0
    this.chrome.selectedChapterDownloadEnabled = hasSelection && this.chrome.chapterDownloadAvailable && !this.downloadBusy
    this.chapterDownloadAction.enabled = this.chrome.selectedChapterDownloadEnabled
    this.chapterMarkReadAction.enabled = hasSelection
    this.chapterMarkUnreadAction.enabled = hasSelection
    this.chapterDownloadAction.accessibilityText = s('manga_detail_action_download_chapter')
    this.chapterMarkReadAction.accessibilityText = s('chapter_list_menu_mark_read')
    this.chapterMarkUnreadAction.accessibilityText = s('chapter_list_menu_mark_unread')
    this.chapterDownloadAction.hoverTips = this.chapterDownloadAction.accessibilityText
    this.chapterMarkReadAction.hoverTips = this.chapterMarkReadAction.accessibilityText
    this.chapterMarkUnreadAction.hoverTips = this.chapterMarkUnreadAction.accessibilityText
  }

  @Builder
  private ChapterSelectionActions() {
    // Keep the native bar at its measured width, as in Huawei's horizontal
    // sample. The coextensive shadow separates its own backplate from cards.
    Row() {
      Stack() {
        HdsActionBar({
          startButtons: this.chapterDownloadActions,
          endButtons: this.chapterReadStateActions,
          actionBarStyle: new ActionBarStyle({ margin: LengthMetrics.vp(0) }),
        })
      }
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ThemeConstants.CARD)
      .shadow({ radius: 12, color: ThemeConstants.SHADOW_PROMINENT, offsetY: 4 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent)
    .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
    .margin({ bottom: this.detailSafeArea.bottomAvoidHeight })
    .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
      this.chapterActionBarHeight = Number(size.height)
    })
  }

  @Builder
  private ChapterViewport(inChapterPane: boolean) {
    // Keep the list mounted when toggling selection. The action bar overlays
    // only the chapter viewport, and the list tail clears its measured height.
    Stack({ alignContent: Alignment.Bottom }) {
      this.RefreshableDetail(inChapterPane)
      if (this.chapterPresentation.selectionMode) {
        this.ChapterSelectionActions()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private InformationList(nativeSpring: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      this.CoverBackdrop()
      SecondaryListScaffold({
        surfaceColor: Color.Transparent,
        scroller: this.detailScroller,
        scrollEnabled: this.usesDetailPanes || this.detailScrollEnabled,
        alwaysEnableEdgeSpring: this.usesDetailPanes || nativeSpring,
        horizontalPadding: this.usesDetailPanes ? 0 : ThemeConstants.SPACE_MD,
        bottomPadding: this.usesDetailPanes ? ThemeConstants.SPACE_XL : this.chapterListBottomPadding(),
        listSpace: ThemeConstants.SPACE_LG,
        onDidScroll: (offset: number) => { this.onInformationScroll(offset) },
        onVisibleContentChange: (start: VisibleListContentInfo) => {
          if (!this.usesDetailPanes) this.onChapterViewport(start, false)
        },
      }) {
        this.DetailInformationItems()
        if (!this.usesDetailPanes) {
          this.DetailChapterItems()
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ChapterPane(nativeSpring: boolean) {
    SecondaryListScaffold({
      surfaceColor: Color.Transparent,
      scroller: this.chapterScroller,
      scrollEnabled: this.detailScrollEnabled,
      alwaysEnableEdgeSpring: nativeSpring,
      horizontalPadding: 0,
      bottomPadding: this.chapterListBottomPadding(),
      listSpace: ThemeConstants.SPACE_LG,
      onVisibleContentChange: (start: VisibleListContentInfo) => { this.onChapterViewport(start, true) },
    }) {
      this.DetailChapterItems()
    }
  }

  @Builder
  private RefreshableDetail(chapterPane: boolean) {
    if (this.canPullRefreshDetail()) {
      PullRefresh({
        scroller: chapterPane ? this.chapterScroller : this.detailScroller,
        controller: this.detailRefreshController,
        indicatorTop: this.detailSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT / 2,
        onRefresh: async (): Promise<void> => { await this.refreshMangaDetail() },
        onScrollEnableChange: (enabled: boolean): void => { this.detailScrollEnabled = enabled },
      }) {
        if (chapterPane) {
          this.ChapterPane(false)
        } else {
          this.InformationList(false)
        }
      }
    } else if (chapterPane) {
      this.ChapterPane(true)
    } else {
      this.InformationList(true)
    }
  }

  @Builder
  private DetailLayout() {
    if (this.usesDetailPanes) {
      Row({ space: 24 }) {
        Column() {
          this.InformationList(true)
        }
        .width(Math.max(264, Math.min(360, (this.detailContentWidth - 24) * 0.38,
          this.detailContentWidth - 24 - 332)))
        .height('100%')

        Column() {
          this.ChapterViewport(true)
        }
        .layoutWeight(1)
        .height('100%')
      }
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      .width('100%')
      .height('100%')
    } else {
      this.ChapterViewport(false)
    }
  }

  @Builder
  private DetailFailureFeedback() {
    if (this.detailAuthentication !== null) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(s('source_login_required')).width('100%').fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
        KomaActionButton({ label: s('source_login'), kind: 'primary', action: () => { this.authenticateSource() } })
      }.width('100%')
    } else {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(this.feedbackText).width('100%').fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
        if (this.sourceDetailContentState === SourceDetailContentState.ERROR && this.canReloadSourceDetail()) {
          KomaActionButton({ label: s('common_retry'), action: () => { void this.refreshMangaDetail() } })
        }
      }.width('100%')
    }
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SourceAuthenticationSheetHost({ request: this.authentication, active: this.chrome.visible })
        Column() {}.width(0).height(0)
          .bindSheet($$this.notesEditorShown, this.NotesEditor, komaSheetOptions({
            detents: [SheetSize.LARGE], showClose: false, enableFloatingDragBar: true,
            onWillDismiss: (action: DismissSheetAction) => { this.notesEditorShown = false; action.dismiss() },
          }))
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
        Column() {}.width(0).height(0)
          .bindSheet($$this.trackingSheetShown, this.TrackingSheet, komaSheetOptions({
            height: SheetSize.FIT_CONTENT,
            detents: [this.trackingSheetHeight(), SheetSize.LARGE],
            detentSelection: this.trackingSheetHeight(),
            onTypeDidChange: (type: SheetType) => { this.trackingSheetType = type },
            scrollSizeMode: ScrollSizeMode.CONTINUOUS,
            showClose: false, enableFloatingDragBar: true,
            onWillDismiss: (action: DismissSheetAction) => {
              if (!this.trackerMappingBusy && !this.trackerSyncBusy) { this.trackingSheetShown = false; action.dismiss() }
            },
          }))
        this.DetailLayout()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
      .onSizeChange((_old: SizeOptions, size: SizeOptions): void => {
        const width = Number(size.width)
        const height = Number(size.height)
        if (height > 0 && height !== this.trackingViewportHeight) this.trackingViewportHeight = height
        if (Number.isFinite(width) && width > 0) {
          const availableWidth = Math.max(0, width - 2 * ThemeConstants.SPACE_MD)
          if ((availableWidth >= DETAIL_PANES_MIN_CONTENT_WIDTH) !== this.usesDetailPanes) {
            this.chapterToRestore = this.visibleChapterId
          }
          this.detailContentWidth = availableWidth
        }
      })
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
    contentRating: comic.sourceMetadata?.contentRating,
    tags: comic.sourceMetadata?.tags?.slice(),
    description: comic.subtitle,
    coverUrl: comic.coverUri,
    status,
    chapterCount: comic.chapterCount,
    isInLibrary: true,
    sourceId: comic.sourceRuntimeId,
    sourceImageId: comic.remoteResourceId,
    sourceName: comic.sourceRuntimeId === undefined ? '' :
      (registry.list().find((entry) => entry.sourceId === comic.sourceRuntimeId)?.manifestName?.trim() ||
        comic.sourceMetadata?.sourceName?.trim() || s('library_source_package')),
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
    localReadingIndex: chapterPagesAreLocalOffline(sourceKind) ? chapter.index : undefined,
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
