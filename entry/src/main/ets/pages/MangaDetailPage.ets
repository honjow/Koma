import { MangaDetailHeader } from '../components/MangaDetailHeader'
import { common } from '@kit.AbilityKit'
import { MangaDescriptionSection } from '../components/MangaDescriptionSection'
import { MangaTagsSection } from '../components/MangaTagsSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  ChapterBatchDownloadMode,
  ChapterListSection,
} from '../components/ChapterListSection'
import {
  AppFilesChapterReadStatePersistenceAdapter,
  ChapterReadStateStore,
} from '../model/ChapterReadStateStore'
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
import {
  Chapter,
  Comic,
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
} from '../model/LibraryPersistence'
import {
  LocalLibraryMetadataStatus,
  LocalLibraryStoredMetadata,
} from '../model/LocalLibraryMetadataService'
import {
  LocalLibraryRefreshComicResult,
  LocalLibraryRefreshService,
} from '../model/LocalLibraryRefreshService'
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
import { runSourceOperationFromBytes } from '../sourceRuntime/SourceRuntimeRunner'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
  configureSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'
import {
  InMemoryReaderSessionStore,
  ReaderSessionStore,
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
import { taskpool } from '@kit.ArkTS'

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
}

interface SourceMangaRequestArgs {
  mangaId: string
}

interface SourceChaptersPageArg {
  cursor: string | null
  limit: number
}

interface SourceChaptersRequestArgs {
  mangaId: string
  page: SourceChaptersPageArg
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
  args: SourceMangaRequestArgs | SourceChaptersRequestArgs
  settings: SourceSettingsRecord
  hostHints: SourceDetailRequestHostHints
}

@Concurrent
function executeMangaDetailSourceOperation(requestJson: string, wasmBytes: Uint8Array): string {
  const response = runSourceOperationFromBytes(requestJson, wasmBytes)
  return JSON.stringify(response)
}

function s(name: string): string {
  return AppStrings.get(name)
}

const SOURCE_CHAPTER_PAGE_SIZE: number = 100
const SOURCE_CHAPTER_MAX_PAGES: number = 20

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
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Param readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param sourceRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  @Param chrome: MangaDetailRouteChromeState = new MangaDetailRouteChromeState()
  @Event onBack: () => void = () => {}
  @Event onOpenReader: (mangaId: string, chapterId?: string) => void = (_mangaId: string, _chapterId?: string) => {}
  @Event onOpenSourceReader: (request: SourceReaderSessionRequest) => void = (_request: SourceReaderSessionRequest) => {}
  @Event onOpenImportRequested: () => void = () => {}
  @Event onLibraryChanged: () => void = () => {}
  private chapterReadStateStore?: ChapterReadStateStore
  private sourceDetailRequestEpoch: number = 0
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
    this.seedSourceDetailFromInitialRouteManga()
    this.syncTitleActions()
    void this.loadMangaDetail()
  }

  aboutToDisappear(): void {
    // A hidden detail route must not let an old source response repaint a later route instance.
    this.sourceDetailRequestEpoch = this.sourceDetailRequestEpoch + 1
    this.chrome.pageActionsAvailable = false
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

  @Monitor('manga', 'sourceDetailContentState', 'localRefreshBusy', 'trackerMappingBusy', 'trackerSyncBusy')
  private syncTitleActionsFromDetailState(): void {
    this.syncTitleActions()
  }

  private syncTitleActions(): void {
    const actionsAvailable = this.shouldRenderDetailActions()
    this.chrome.pageActionsAvailable = actionsAvailable
    this.chrome.localRefreshAvailable = actionsAvailable && this.canCheckLocalLibraryRefresh()
    this.chrome.localMetadataAvailable = actionsAvailable && this.canEditLocalMetadata()
    this.chrome.localRefreshBusy = this.localRefreshBusy
    this.chrome.trackerMappingBusy = this.trackerMappingBusy
    this.chrome.trackerSyncBusy = this.trackerSyncBusy
  }

  private runTitleAction(action: MangaDetailTitleAction): void {
    if (!this.shouldRenderDetailActions()) {
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
      return new OfflineDownloadService(new OfflineDownloadStore(context.filesDir))
    } catch (error) {
      void error
      console.warn('[ReaderOffline] step=detail_service_unavailable failed=true')
      return undefined
    }
  }

  private ensureChapterReadStateStore(): ChapterReadStateStore | undefined {
    if (this.chapterReadStateStore !== undefined) {
      return this.chapterReadStateStore
    }
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        return undefined
      }
      this.chapterReadStateStore = new ChapterReadStateStore(
        new AppFilesChapterReadStatePersistenceAdapter(context.filesDir)
      )
      return this.chapterReadStateStore
    } catch (error) {
      void error
      console.warn('[manga-detail] step=chapter_read_state_unavailable failed=true')
      return undefined
    }
  }

  private decorateChapterStates(chapters: MangaChapterItem[]): MangaChapterItem[] {
    const comicId = this.currentComicId()
    const progress: ReadingProgress | undefined = this.readerSessionStore.getProgress(comicId)
    const readStateStore = this.ensureChapterReadStateStore()
    const downloadService = this.offlineDownloadService()
    return chapters.map((chapter: MangaChapterItem): MangaChapterItem => {
      const next: MangaChapterItem = {
        id: chapter.id,
        title: chapter.title,
        chapterNumber: chapter.chapterNumber,
        volumeNumber: chapter.volumeNumber,
        scanlator: chapter.scanlator,
        language: chapter.language,
        dateUpload: chapter.dateUpload,
        pageCount: chapter.pageCount,
        isRead: readStateStore === undefined ? this.isReadFromProgress(comicId, chapter.id, progress) :
          readStateStore.isRead(comicId, chapter.id, progress),
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

  private isReadFromProgress(comicId: string, chapterId: string, progress?: ReadingProgress): boolean {
    return progress !== undefined &&
      progress.comicId === comicId &&
      progress.chapterId === chapterId &&
      progress.completed === true
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
    this.sourceDetailRequestEpoch = this.sourceDetailRequestEpoch + 1
    return this.sourceDetailRequestEpoch
  }

  private isCurrentSourceDetailRequest(requestEpoch: number, sourceId: string, mangaId: string): boolean {
    return this.sourceDetailRequestEpoch === requestEpoch &&
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
    this.manga = mangaDetailFromComic(comic)
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
      this.manga = mangaDetailFromComic(updated)
      this.chapters = this.decorateChapterStates(
        updated.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter, updated.sourceKind))
      )
      this.localMetadataEditorVisible = false
      this.feedbackText = s('manga_detail_local_metadata_saved')
      this.onLibraryChanged()
      this.showToast(s('manga_detail_local_metadata_saved'))
    } catch (_error) {
      console.warn('[LocalMetadata] step=save_failed failed=true reason=metadata_validation')
      this.showToast(s('manga_detail_local_metadata_save_failed'))
    }
  }

  private resetLocalMetadataEditor(): void {
    this.localMetadataTitle = ''
    this.localMetadataAuthors = ''
    this.localMetadataStatus = 'unknown'
    this.localMetadataCoverPath = ''
  }

  private async loadSourceMangaDetail(sourceId: string, mangaId: string): Promise<void> {
    const requestEpoch = this.beginSourceDetailRequest(sourceId, mangaId)
    this.sourceDetailContentState = SourceDetailContentState.LOADING
    this.sourceDetailDataResolved = false
    this.feedbackText = s('manga_detail_loading_source')
    try {
      const lookup = this.sourceRegistry.lookup(sourceId)
      if (!lookup.ok || lookup.entry === undefined) {
        throw new Error(lookup.reasonCode ?? 'source lookup failed')
      }
      if (!sourceRuntimeEntryEnabled(lookup.entry)) {
        throw new Error('source_disabled')
      }
      const cached = sourceMangaDetailSnapshotCache.read(lookup.entry, sourceId, mangaId)
      let detail: MangaDetail
      let chapters: MangaChapterItem[]
      if (cached !== undefined) {
        detail = cached.detail
        chapters = cached.chapters
        if (cached.chaptersResolved) {
          this.applySourceMangaDetail(requestEpoch, lookup.entry, sourceId, mangaId, detail, chapters, '')
          return
        }
      } else {
        const loaded = await this.runSourceMangaOperation(lookup.entry, 'get_manga', mangaId)
        if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
          return
        }
        detail = this.sourceDetailWithRouteIdentity(loaded.detail, sourceId, mangaId)
        chapters = loaded.embeddedChapters
      }
      // The detail payload is already real data. Keep it visible while the
      // independent chapter request is pending instead of representing this
      // as an empty detail or a fabricated zero-chapter result.
      const detailApplied = this.applySourceMangaDetail(
        requestEpoch,
        lookup.entry,
        sourceId,
        mangaId,
        detail,
        chapters,
        '',
        SourceDetailContentState.LOADING,
      )
      if (!detailApplied) {
        return
      }
      if (cached === undefined) {
        sourceMangaDetailSnapshotCache.write(lookup.entry, sourceId, mangaId, {
          detail,
          chapters,
          chaptersResolved: false,
        })
      }
      let chaptersLoadFailed = false
      try {
        const remoteChapters = await this.runSourceChaptersOperation(lookup.entry, mangaId)
        if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
          return
        }
        if (remoteChapters.length > 0) {
          chapters = remoteChapters
        }
      } catch (_error) {
        if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
          return
        }
        chaptersLoadFailed = true
        console.warn('[manga-detail] source chapters load failed reason=source_chapters')
      }
      if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
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
        chaptersLoadFailed ? s('manga_detail_load_source_chapters_failed') : '',
        chaptersLoadFailed && chapters.length === 0
          ? SourceDetailContentState.ERROR
          : SourceDetailContentState.READY,
      )
      if (applied && !chaptersLoadFailed) {
        sourceMangaDetailSnapshotCache.write(lookup.entry, sourceId, mangaId, {
          detail,
          chapters,
          chaptersResolved: true,
        })
      }
    } catch (error) {
      const e = error as Error
      void e
      if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
        return
      }
      console.warn('[manga-detail] source detail load failed reason=source_detail')
      const fallbackDetail = this.sourceDetailFromInitialRouteManga(sourceId, mangaId)
      const fallbackComicId = this.sourceComicId(sourceId, mangaId)
      const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, fallbackComicId)
      if (fallbackDetail !== undefined) {
        fallbackDetail.isInLibrary = libraryComic !== undefined
        this.manga = fallbackDetail
      } else {
        this.manga = undefined
      }
      this.chapters = []
      this.isInLibrary = libraryComic !== undefined
      this.sourceDetailDataResolved = false
      this.activeLibraryComicId = libraryComic?.id ?? ''
      this.feedbackText = s('manga_detail_load_source_failed')
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
    const lookup = this.sourceRegistry.lookup(sourceId)
    if (lookup.ok && lookup.entry !== undefined) {
      detail.sourceName = lookup.entry.manifestName
    }
    const comicId = this.sourceComicId(sourceId, mangaId)
    const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, comicId)
    detail.isInLibrary = libraryComic !== undefined
    this.manga = detail
    this.chapters = []
    this.isInLibrary = detail.isInLibrary
    this.sourceDetailDataResolved = false
    this.activeLibraryComicId = libraryComic?.id ?? ''
    this.sourceDetailContentState = SourceDetailContentState.LOADING
    this.feedbackText = s('manga_detail_loading_source')
    this.downloadStatusText = ''
    this.localRefreshText = ''
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
  ): boolean {
    if (!this.isCurrentSourceDetailRequest(requestEpoch, sourceId, mangaId)) {
      return false
    }
    const nextDetail = this.sourceDetailWithRouteIdentity(detail, sourceId, mangaId)
    const comicId = this.sourceComicId(sourceId, mangaId)
    const libraryComic = this.findSourceRuntimeComic(sourceId, mangaId, comicId)
    this.activeLibraryComicId = libraryComic?.id ?? ''
    nextDetail.chapterCount = chapters.length
    nextDetail.isInLibrary = libraryComic !== undefined
    nextDetail.sourceName = entry.manifestName
    this.manga = nextDetail
    this.chapters = this.decorateChapterStates(chapters)
    this.isInLibrary = nextDetail.isInLibrary
    this.sourceDetailDataResolved = true
    this.feedbackText = feedbackText
    this.sourceDetailContentState = contentState
    this.refreshDownloadStatus()
    return true
  }

  private async runSourceMangaOperation(
    entry: SourceRuntimeRegistryEntry,
    operation: string,
    mangaId: string
  ): Promise<SourceMangaDetailLoadResult> {
    const args: SourceMangaRequestArgs = { mangaId }
    const request = this.buildSourceDetailRequestJson(entry.sourceId, operation, args, { network: true })
    const responseJson = await taskpool.execute(
      executeMangaDetailSourceOperation,
      request,
      this.copyWasmBytes(entry)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    const item = this.sourceMangaResponseItem(response)
    if (response.ok !== true || item === undefined) {
      throw new Error('get_manga returned no item')
    }
    return {
      detail: parseMangaDetailFromSourceItem(entry.sourceId, item),
      embeddedChapters: this.sourceEmbeddedChapterItems(response, item)
        .map((chapter: Record<string, Object>): MangaChapterItem => parseMangaChapterFromSourceItem(chapter)),
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
      url: detail.url,
    }
    return next
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
    }
  }

  private async runSourceChaptersOperation(
    entry: SourceRuntimeRegistryEntry,
    mangaId: string
  ): Promise<MangaChapterItem[]> {
    const chapters: MangaChapterItem[] = []
    let cursor: string | null = null
    for (let pageIndex = 1; pageIndex <= SOURCE_CHAPTER_MAX_PAGES; pageIndex += 1) {
      const response = await this.runSourceChaptersPage(entry, mangaId, cursor)
      const rows = this.sourceChapterResponseItems(response)
      rows.forEach((item: Record<string, Object>) => {
        chapters.push(parseMangaChapterFromSourceItem(item))
      })
      const nextCursor = this.sourcePageNextCursor(response)
      if (!this.sourcePageHasMore(response, nextCursor)) {
        break
      }
      cursor = nextCursor ?? `${pageIndex + 1}`
    }
    return chapters
  }

  private async runSourceChaptersPage(
    entry: SourceRuntimeRegistryEntry,
    mangaId: string,
    cursor: string | null,
  ): Promise<SourceOperationResponsePayload> {
    const args: SourceChaptersRequestArgs = {
      mangaId,
      page: {
        cursor,
        limit: SOURCE_CHAPTER_PAGE_SIZE,
      },
    }
    const request = this.buildSourceDetailRequestJson(entry.sourceId, 'get_chapters', args, { network: true })
    const responseJson = await taskpool.execute(
      executeMangaDetailSourceOperation,
      request,
      this.copyWasmBytes(entry)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    if (response.ok !== true) {
      throw new Error('get_chapters failed')
    }
    return response
  }

  private buildSourceDetailRequestJson(
    sourceId: string,
    operation: string,
    args: SourceMangaRequestArgs | SourceChaptersRequestArgs,
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

  private sourceChapterResponseItems(response: SourceOperationResponsePayload): Record<string, Object>[] {
    if (response.data?.items !== undefined) {
      return response.data.items
    }
    return response.data?.chapters ?? []
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

  private sourcePageNextCursor(response: SourceOperationResponsePayload): string | undefined {
    const nextCursor = response.data?.page?.nextCursor ?? response.data?.page?.next_cursor
    return nextCursor === null || nextCursor === undefined || nextCursor.trim().length === 0 ? undefined : nextCursor
  }

  private sourcePageHasMore(response: SourceOperationResponsePayload, nextCursor: string | undefined): boolean {
    return response.data?.hasNextPage === true ||
      response.data?.hasMore === true ||
      response.data?.has_more === true ||
      response.data?.page?.hasMore === true ||
      response.data?.page?.hasNextPage === true ||
      response.data?.page?.has_more === true ||
      nextCursor !== undefined
  }

  private sourceComicId(sourceId: string | undefined, mangaId: string): string {
    const normalizedSourceId = sourceId?.trim()
    if (normalizedSourceId === undefined || normalizedSourceId.length === 0) {
      return mangaId
    }
    return mangaId.startsWith(`${normalizedSourceId}:`) ? mangaId : `${normalizedSourceId}:${mangaId}`
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

  private earliestNumberedChapter(): MangaChapterItem | undefined {
    let selected: MangaChapterItem | undefined = undefined
    this.chapters.forEach((chapter: MangaChapterItem): void => {
      if (chapter.chapterNumber === undefined) {
        return
      }
      if (selected === undefined || (selected.chapterNumber !== undefined && chapter.chapterNumber < selected.chapterNumber)) {
        selected = chapter
      }
    })
    return selected
  }

  private oldestDatedChapter(): MangaChapterItem | undefined {
    let selected: MangaChapterItem | undefined = undefined
    this.chapters.forEach((chapter: MangaChapterItem): void => {
      if (chapter.dateUpload === undefined) {
        return
      }
      if (selected === undefined || (selected.dateUpload !== undefined && chapter.dateUpload < selected.dateUpload)) {
        selected = chapter
      }
    })
    return selected
  }

  private firstChapterId(): string | undefined {
    if (this.chapters.length === 0) {
      return undefined
    }
    return (this.earliestNumberedChapter() ?? this.oldestDatedChapter() ?? this.chapters[0]).id
  }

  private progressChapterId(): string | undefined {
    const progress = this.readerSessionStore.getProgress(this.currentComicId())
    if (progress === undefined || progress.chapterId.trim().length === 0) {
      return undefined
    }
    return this.chapters.some((chapter: MangaChapterItem): boolean => chapter.id === progress.chapterId)
      ? progress.chapterId
      : undefined
  }

  private primaryReadChapterId(): string | undefined {
    return this.progressChapterId() ?? this.firstChapterId()
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
    const orderedChapterIds = this.allChapterIds()
    let bestIndex = -1
    let bestChapterId = ''
    chapterIds.forEach((chapterId: string): void => {
      const index = orderedChapterIds.indexOf(chapterId)
      if (index > bestIndex) {
        bestIndex = index
        bestChapterId = chapterId
      }
    })
    if (bestIndex < 0 || bestChapterId.length === 0) {
      return undefined
    }
    const currentProgress = this.readerSessionStore.getProgress(this.currentComicId())
    if (currentProgress !== undefined) {
      const currentIndex = orderedChapterIds.indexOf(currentProgress.chapterId)
      if (currentIndex >= 0 && bestIndex < currentIndex) {
        return undefined
      }
    }
    return this.completedProgressForChapter(bestChapterId)
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
        'on_chapter_complete',
      )
        .then((result) => {
          console.info(`[TrackerSync] step=marked_read_progress status=${result.status} reason=${result.reason ?? 'none'} queued=${result.queued === true}`)
        })
        .catch((_error: Error) => {
          console.warn('[TrackerSync] step=marked_read_progress failed=true reason=marked_read')
        })
    } catch (_error) {
      console.warn('[TrackerSync] step=marked_read_progress failed=true reason=context')
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
        console.error('[manga-detail] step=remove_from_library_failed reason=library_persist')
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
      console.error('[manga-detail] step=add_to_library_failed reason=library_persist')
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
      title,
      chapterId: resolvedChapterId,
      chapterIds,
      chapterTitles: this.chapters.map((chapter: MangaChapterItem): string => chapter.title),
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
      const comic = this.libraryStore?.getComic(this.currentComicId())
      if (comic === undefined) {
        this.downloadStatusText = s('manga_detail_add_to_library_first')
        this.showToast(s('manga_detail_add_to_library_first'))
        return
      }
      if (manga.sourceId !== undefined) {
        const hydration = await this.ensureSourceChapterPages(resolvedChapterId)
        if (!hydration.hydrated) {
          const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === resolvedChapterId)?.title
          service.blockChapterDownload(comic, resolvedChapterId, hydration.reasonCode ?? 'pages_missing', {
            comicTitle: comic.title,
            chapterTitle,
          })
          this.applyChapterStatesToCurrent()
          this.downloadStatusText = s('manga_detail_chapter_pages_load_failed')
          this.showToast(s('manga_detail_chapter_pages_load_failed'))
          return
        }
      }
      try {
        await installReaderRemoteHeadersForComic(getContext(this) as common.UIAbilityContext, comic)
      } catch (error) {
        void error
        console.warn('[ReaderOffline] step=detail_headers_unavailable failed=true')
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
      this.showToast(manifest.status === OfflineDownloadStatus.DOWNLOADED
        ? s('manga_detail_chapter_downloaded')
        : s('manga_detail_chapter_download_failed'))
    } finally {
      this.downloadBusy = false
    }
  }

  private canCheckLocalLibraryRefresh(): boolean {
    const comic = this.libraryStore?.getComic(this.currentComicId())
    return comic !== undefined &&
      (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER)
  }

  private checkLocalLibraryRefreshNow(): void {
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
      console.warn('[LocalLibraryRefresh] step=detail_check_failed failed=true reason=local_refresh')
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

  private async handleDownloadVisibleChapters(chapterIds: string[], mode: ChapterBatchDownloadMode): Promise<void> {
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
      try {
        await installReaderRemoteHeadersForComic(getContext(this) as common.UIAbilityContext, initialComic)
      } catch (_error) {
        console.warn('[ReaderOffline] step=detail_batch_headers_unavailable failed=true')
      }
      for (let index = 0; index < targetChapterIds.length; index += 1) {
        const chapterId = targetChapterIds[index]
        if (manga.sourceId !== undefined) {
          try {
            const hydration = await this.ensureSourceChapterPages(chapterId)
            if (!hydration.hydrated) {
              const comic = this.libraryStore?.getComic(this.currentComicId())
              if (comic !== undefined) {
                const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)?.title
                service.blockChapterDownload(comic, chapterId, hydration.reasonCode ?? 'pages_missing', {
                  comicTitle: comic.title,
                  chapterTitle,
                })
              }
              blockedCount += 1
              console.warn(`[ReaderOffline] step=batch_pages_unavailable failed=true reason=${hydration.reasonCode ?? 'source_pages_missing'}`)
              this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [index + 1, targetChapterIds.length])
              continue
            }
          } catch (_error) {
            console.warn('[ReaderOffline] step=batch_pages_unavailable failed=true reason=source_pages_lookup')
            blockedCount += 1
            this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [index + 1, targetChapterIds.length])
            continue
          }
        }
        const comic = this.libraryStore?.getComic(this.currentComicId())
        if (comic === undefined) {
          failedCount += 1
          this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [index + 1, targetChapterIds.length])
          continue
        }
        const chapterTitle = this.chapters.find((item: MangaChapterItem): boolean => item.id === chapterId)?.title
        const manifest = await service.downloadChapter(comic, chapterId, {
          comicTitle: comic.title,
          chapterTitle,
        })
        if (manifest.status === OfflineDownloadStatus.DOWNLOADED) {
          downloadedCount += 1
        } else if (manifest.status === OfflineDownloadStatus.BLOCKED) {
          blockedCount += 1
        } else {
          failedCount += 1
        }
        this.downloadStatusText = this.formatString('manga_detail_batch_downloading', [index + 1, targetChapterIds.length])
      }
      this.applyChapterStatesToCurrent()
      this.downloadStatusText = this.formatString('manga_detail_batch_complete', [downloadedCount, blockedCount, failedCount])
      this.showToast(blockedCount > 0 ? s('manga_detail_batch_missing_pages') : s('manga_detail_batch_complete_toast'))
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
    const store = this.ensureChapterReadStateStore()
    if (store === undefined) {
      this.showToast(s('manga_detail_read_state_unavailable'))
      return
    }
    const row = store.mark(this.currentComicId(), chapterId, isRead)
    if (row === undefined) {
      this.showToast(s('manga_detail_read_state_unavailable'))
      return
    }
    this.applyChapterStatesToCurrent()
    if (isRead) {
      this.syncMarkedReadTrackerProgress([chapterId])
    }
    this.showToast(isRead ? s('manga_detail_marked_read') : s('manga_detail_marked_unread'))
  }

  private markVisibleChaptersReadState(chapterIds: string[], isRead: boolean): void {
    const targetIds = chapterIds.filter((chapterId: string): boolean => chapterId.trim().length > 0)
    if (targetIds.length === 0) {
      this.showToast(s('manga_detail_no_markable_chapters'))
      return
    }
    const store = this.ensureChapterReadStateStore()
    if (store === undefined) {
      this.showToast(s('manga_detail_read_state_unavailable'))
      return
    }
    const comicId = this.currentComicId()
    let changedCount = 0
    targetIds.forEach((chapterId: string) => {
      const row = store.mark(comicId, chapterId, isRead)
      if (row !== undefined) {
        changedCount += 1
      }
    })
    this.applyChapterStatesToCurrent()
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
    const chapterIds = this.allChapterIds()
    if (chapterIds.length === 0) {
      return undefined
    }
    const chapterIndex = Math.min(Math.max(Math.floor(result.providerProgress) - 1, 0), chapterIds.length - 1)
    return this.completedProgressForChapter(chapterIds[chapterIndex])
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
      console.warn('[TrackerMapping] step=manual_candidate_refresh failed=true')
      this.showToast(s('manga_detail_tracker_mapping_failed'))
    } finally {
      this.trackerMappingBusy = false
    }
  }

  private async syncTrackerProgressNow(): Promise<void> {
    if (this.trackerSyncBusy) {
      return
    }
    const progress = this.readerSessionStore.getProgress(this.currentComicId())
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
        'manual',
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
      console.warn('[TrackerSync] step=manual_progress failed=true reason=manual_progress')
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
      console.warn('[TrackerSync] step=manual_pull_progress failed=true reason=manual_pull')
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
      sourceName: manga.sourceId === undefined ? s('tab_library') : manga.sourceName,
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

  private formatDownloadStatus(summary: OfflineDownloadSummary | undefined): string {
    if (summary === undefined) {
      return ''
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
      return s('manga_detail_download_in_progress')
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
    Row({ space: ThemeConstants.SPACE_MD }) {
      KomaActionButton({
        label: this.primaryReadLabel(),
        kind: 'primary',
        icon: $r('sys.symbol.doc_plaintext'),
        fill: true,
        compact: true,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        isEnabled: this.hasReadableChapters() && !this.isSourceDetailLoading(),
        action: () => {
          this.handleStartReading()
        },
      })

      KomaActionButton({
        label: this.downloadButtonLabel(),
        kind: 'secondary',
        icon: $r('sys.symbol.arrow_down_to_line'),
        fill: true,
        compact: true,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        isEnabled: this.hasReadableChapters() && !this.downloadBusy && !this.isSourceDetailLoading(),
        action: () => {
          this.handleDownloadChapter()
        },
      })

      if (this.canAddCurrentMangaToLibrary()) {
        KomaIconButton({
          icon: $r('sys.symbol.bookmark'),
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
          .bindMenu(this.LocalMetadataStatusMenu())
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

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SecondaryListScaffold({
          listSpace: ThemeConstants.SPACE_LG,
          horizontalPadding: ThemeConstants.SPACE_XL,
          bottomPadding: ThemeConstants.SPACE_XL,
          reserveTitleBar: true,
        }) {
        if (this.manga !== undefined) {
          ListItem() {
            MangaDetailHeader({
              manga: this.displayedManga(this.manga),
              showChapterCount: this.shouldShowChapterCount(),
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

        if (this.downloadStatusText.length > 0) {
          ListItem() {
            Text(this.downloadStatusText)
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
          ListItem() {
            ChapterListSection({
              chapters: this.chapters,
              onOpenChapter: (chapterId: string) => {
                void this.handleOpenChapter(chapterId)
                  .catch((error: Error) => {
                    void error
                    console.error('[manga-detail] step=source_pages_load_failed reason=source_pages')
                    this.showToast(s('manga_detail_chapter_pages_load_failed'))
                  })
              },
              onDownloadChapter: (chapterId: string) => {
                this.handleDownloadChapter(chapterId)
              },
              onDownloadVisibleChapters: (chapterIds: string[], mode: ChapterBatchDownloadMode) => {
                this.handleDownloadVisibleChapters(chapterIds, mode)
              },
              onMarkChapterReadState: (chapterId: string, isRead: boolean) => {
                this.markChapterReadState(chapterId, isRead)
              },
              onMarkVisibleChaptersReadState: (chapterIds: string[], isRead: boolean) => {
                this.markVisibleChaptersReadState(chapterIds, isRead)
              },
            })
          }
        }
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}

function mangaDetailFromComic(comic: Comic): MangaDetail {
  let status = MangaStatus.UNKNOWN
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
    id: comic.id,
    title: comic.title,
    author: comic.author,
    description: comic.subtitle,
    coverUrl: comic.coverUri,
    status,
    chapterCount: comic.chapterCount,
    isInLibrary: true,
    sourceId: comic.sourceRuntimeId,
    sourceImageId: comic.remoteResourceId,
    sourceName: comic.sourceRuntimeId ?? '',
    url: comic.sourcePath,
  }
}

function chapterPagesAreLocalOffline(sourceKind: ComicSourceKind): boolean {
  return sourceKind === ComicSourceKind.LOCAL_ARCHIVE || sourceKind === ComicSourceKind.LOCAL_FOLDER
}

function mangaChapterItemFromComicChapter(chapter: Chapter, sourceKind: ComicSourceKind): MangaChapterItem {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.index + 1,
    scanlator: chapter.scanlator,
    language: chapter.language,
    dateUpload: chapter.dateUpload,
    pageCount: chapter.pageCount,
    isRead: false,
    isDownloaded: chapterPagesAreLocalOffline(sourceKind) && chapter.pageCount > 0,
    downloadStatus: chapterPagesAreLocalOffline(sourceKind) && chapter.pageCount > 0 ? 'downloaded' : undefined,
  }
}

function comicFromSourceManga(manga: MangaDetail, chapters: MangaChapterItem[], comicId: string): Comic {
  const now = Date.now()
  const comicChapters = chapters.map((chapter: MangaChapterItem, index: number): Chapter => {
    return {
      id: chapter.id,
      comicId,
      title: chapter.title.length > 0
        ? chapter.title
        : AppStrings.get('library_update_chapter_fallback_title').replace('%s', `${index + 1}`),
      index,
      scanlator: chapter.scanlator,
      language: chapter.language,
      dateUpload: chapter.dateUpload,
      sourcePath: `${manga.url ?? manga.id}#${chapter.id}`,
      sortKey: chapter.chapterNumber === undefined ? `${index}` : `${chapter.chapterNumber}`,
      pages: [],
      pageCount: chapter.pageCount ?? 0,
      createdAt: now,
      updatedAt: now,
    }
  })
  const title = manga.title.length > 0 ? manga.title : AppStrings.get('manga_detail_title_fallback')
  return {
    id: comicId,
    title,
    subtitle: manga.description,
    author: manga.author,
    sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
    sourcePath: manga.url ?? `source://${manga.sourceId ?? 'unknown'}/${manga.id}`,
    sourceRuntimeId: manga.sourceId,
    remoteResourceId: manga.id,
    coverUri: manga.coverUrl,
    sortTitle: normalizeSortKey(title),
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters: comicChapters,
    chapterCount: comicChapters.length,
    pageCount: comicChapters.reduce((total: number, chapter: Chapter): number => total + chapter.pageCount, 0),
    createdAt: now,
    updatedAt: now,
    lastImportedAt: now,
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
