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
import { SourceChapterPageHydrator } from '../model/SourceChapterPageHydrator'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
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
import {
  TrackerProgressSyncResult,
  TrackerProgressSyncReason,
  TrackerProgressSyncService,
} from '../model/TrackerProgressSyncService'
import { RouterHelper } from '../common/RouterHelper'
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

@ComponentV2
export struct MangaDetailPage {
  @Param params: MangaDetailRouteParams = {}
  @Local private manga: MangaDetail = missingMangaDetail(undefined, undefined)
  @Local private chapters: MangaChapterItem[] = []
  @Local private isInLibrary: boolean = false
  @Local private isLoading: boolean = false
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
  @Local private languageState: LanguageState = connectLanguageState()
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Param readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param sourceRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  @Event onBack: () => void = () => {}
  @Event onOpenReader: (mangaId: string, chapterId?: string) => void = (_mangaId: string, _chapterId?: string) => {}
  @Event onOpenImportRequested: () => void = () => {}
  @Event onLibraryChanged: () => void = () => {}
  private chapterReadStateStore?: ChapterReadStateStore

  private formatString(key: string, args: Array<string | number>): string {
    let text = s(key)
    args.forEach((value: string | number) => {
      text = text.replace('%s', `${value}`)
    })
    return text
  }

  aboutToAppear(): void {
    configureSourceSettingsStore(getContext(this) as common.UIAbilityContext)
    this.loadMangaDetail()
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
        isRead: readStateStore === undefined ? this.isReadFromProgress(comicId, chapter.id, progress) :
          readStateStore.isRead(comicId, chapter.id, progress),
        isDownloaded: chapter.isDownloaded,
      }
      const summary = downloadService?.getChapterSummary(comicId, chapter.id)
      if (summary?.status === OfflineDownloadStatus.DOWNLOADED) {
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

  private loadLocalOrMissingManga(mangaId?: string): void {
    const comic = mangaId === undefined || this.libraryStore === undefined ? undefined : this.libraryStore.getComic(mangaId)
    if (comic === undefined) {
      this.manga = missingMangaDetail(mangaId, this.params.sourceId)
      this.chapters = []
      this.isInLibrary = false
      this.feedbackText = mangaId === undefined || mangaId.trim().length === 0 ? '' : s('manga_detail_load_local_failed')
      this.downloadStatusText = ''
      this.localRefreshText = ''
      return
    }
    this.manga = mangaDetailFromComic(comic)
    this.chapters = this.decorateChapterStates(
      comic.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter))
    )
    this.isInLibrary = true
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
        updated.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter))
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
    this.isLoading = true
    this.feedbackText = s('manga_detail_loading_source')
    try {
      const lookup = this.sourceRegistry.lookup(sourceId)
      if (!lookup.ok || lookup.entry === undefined) {
        throw new Error(lookup.reasonCode ?? 'source lookup failed')
      }
      const detail = await this.runSourceMangaOperation(lookup.entry, 'get_manga', mangaId)
      let chapters: MangaChapterItem[] = []
      let chaptersLoadFailed = false
      try {
        chapters = await this.runSourceChaptersOperation(lookup.entry, mangaId)
      } catch (_error) {
        chaptersLoadFailed = true
        console.warn('[manga-detail] source chapters load failed reason=source_chapters')
      }
      const comicId = this.sourceComicId(sourceId, mangaId)
      detail.chapterCount = chapters.length
      detail.isInLibrary = this.libraryStore?.getComic(comicId) !== undefined
      detail.sourceName = lookup.entry.manifestName
      this.manga = detail
      this.chapters = this.decorateChapterStates(chapters)
      this.isInLibrary = detail.isInLibrary
      this.feedbackText = chaptersLoadFailed ? s('manga_detail_load_source_chapters_failed') : ''
      this.refreshDownloadStatus()
    } catch (error) {
      const e = error as Error
      void e
      console.warn('[manga-detail] source detail load failed reason=source_detail')
      this.manga = missingMangaDetail(mangaId, sourceId)
      this.chapters = []
      this.isInLibrary = false
      this.feedbackText = s('manga_detail_load_source_failed')
      this.downloadStatusText = ''
      this.localRefreshText = ''
    } finally {
      this.isLoading = false
    }
  }

  private async runSourceMangaOperation(
    entry: SourceRuntimeRegistryEntry,
    operation: string,
    mangaId: string
  ): Promise<MangaDetail> {
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
    return parseMangaDetailFromSourceItem(entry.sourceId, item)
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
    return this.sourceComicId(this.manga.sourceId, this.manga.id)
  }

  private firstChapterId(): string | undefined {
    return this.chapters.length === 0 ? undefined : this.chapters[0].id
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
    if (this.isInLibrary) {
      this.showToast(s('common_already_in_library'))
      return true
    }
    if (this.libraryStore === undefined) {
      this.feedbackText = s('manga_detail_library_unavailable')
      this.showToast(s('manga_detail_library_unavailable'))
      return false
    }
    const comic = comicFromSourceManga(this.manga, this.chapters, this.currentComicId())
    try {
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.isInLibrary = true
      this.manga.isInLibrary = true
      this.feedbackText = s('common_added_to_library')
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
    const chapterId = this.firstChapterId()
    if (chapterId === undefined) {
      this.showToast(s('manga_detail_no_readable_chapters'))
      return
    }
    if (!this.isInLibrary && this.manga.sourceId !== undefined) {
      const added = await this.handleAddToLibrary()
      if (!added) {
        return
      }
    }
    if (this.manga.sourceId !== undefined) {
      const hydrated = await this.ensureSourceChapterPages(chapterId)
      if (!hydrated) {
        this.showToast(s('manga_detail_chapter_pages_load_failed'))
        return
      }
    }
    this.onOpenReader(this.currentComicId(), chapterId)
  }

  private async handleOpenChapter(chapterId: string): Promise<void> {
    if (chapterId.trim().length === 0) {
      return
    }
    if (!this.isInLibrary && this.manga.sourceId !== undefined) {
      const added = await this.handleAddToLibrary()
      if (!added) {
        return
      }
    }
    if (this.manga.sourceId !== undefined) {
      const hydrated = await this.ensureSourceChapterPages(chapterId)
      if (!hydrated) {
        this.showToast(s('manga_detail_chapter_pages_load_failed'))
        return
      }
    }
    this.onOpenReader(this.currentComicId(), chapterId)
  }

  private async handleDownloadChapter(chapterId?: string): Promise<void> {
    if (this.downloadBusy) {
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
      if (!this.isInLibrary && this.manga.sourceId !== undefined) {
        const added = await this.handleAddToLibrary()
        if (!added) {
          this.downloadStatusText = s('manga_detail_download_canceled')
          return
        }
      }
      if (this.manga.sourceId !== undefined) {
        await this.ensureSourceChapterPages(resolvedChapterId)
      }
      const comic = this.libraryStore?.getComic(this.currentComicId())
      if (comic === undefined) {
        this.downloadStatusText = s('manga_detail_add_to_library_first')
        this.showToast(s('manga_detail_add_to_library_first'))
        return
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
      console.info(`[LocalLibraryRefresh] step=detail_check status=${result.status} chapters=${result.previousChapterCount} pages=${result.previousPageCount}`)
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
    return summary?.status === OfflineDownloadStatus.BLOCKED && summary.failureReasonCode === 'pages_missing'
  }

  private async handleDownloadVisibleChapters(chapterIds: string[], mode: ChapterBatchDownloadMode): Promise<void> {
    if (this.downloadBusy) {
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
      if (!this.isInLibrary && this.manga.sourceId !== undefined) {
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
        if (this.manga.sourceId !== undefined) {
          try {
            const hydrated = await this.ensureSourceChapterPages(chapterId)
            if (!hydrated) {
              console.warn('[ReaderOffline] step=batch_pages_unavailable failed=true reason=source_pages_missing')
            }
          } catch (_error) {
            console.warn('[ReaderOffline] step=batch_pages_unavailable failed=true reason=source_pages_lookup')
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

  private async ensureSourceChapterPages(chapterId: string): Promise<boolean> {
    if (this.libraryStore === undefined || this.manga.sourceId === undefined) {
      return false
    }
    const result = await new SourceChapterPageHydrator(
      this.libraryStore,
      this.sourceRegistry,
      this.libraryPersistenceService,
      () => {
        this.onLibraryChanged()
      },
    ).ensureChapterPages(this.currentComicId(), this.manga.sourceId, chapterId)
    return result.hydrated
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
    this.trackerMappingBusy = true
    this.showToast(s('manga_detail_tracker_mapping_searching'))
    try {
      const context = getContext(this) as common.UIAbilityContext
      const comic = this.libraryStore?.getComic(this.currentComicId()) ??
        comicFromSourceManga(this.manga, this.chapters, this.currentComicId())
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

  private displayedManga(): MangaDetail {
    return {
      id: this.manga.id,
      title: this.manga.title,
      author: this.manga.author,
      artist: this.manga.artist,
      description: this.manga.description,
      coverUrl: this.manga.coverUrl,
      status: this.manga.status,
      tags: this.manga.tags,
      sourceId: this.manga.sourceId,
      sourceName: this.manga.sourceId === undefined ? s('tab_library') : this.manga.sourceName,
      chapterCount: this.chapters.length,
      isInLibrary: this.isInLibrary,
      url: this.manga.url,
    }
  }

  private primaryReadLabel(): string {
    return this.chapters.some((chapter: MangaChapterItem): boolean => chapter.isRead)
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
  private DetailMoreMenu() {
    Menu() {
      MenuItem({ content: this.isInLibrary ? s('common_in_library') : s('common_add_to_library') })
        .onClick(() => {
          this.handleAddToLibrary()
        })
      MenuItem({ content: s('manga_detail_menu_download_all') })
        .onClick(() => {
          this.handleDownloadVisibleChapters(this.allChapterIds(), ChapterBatchDownloadMode.ALL_VISIBLE)
        })
      MenuItem({ content: s('manga_detail_menu_download_incomplete') })
        .onClick(() => {
          this.handleDownloadVisibleChapters(this.allChapterIds(), ChapterBatchDownloadMode.NOT_DOWNLOADED)
        })
      MenuItem({ content: s('manga_detail_menu_mark_all_read') })
        .onClick(() => {
          this.markVisibleChaptersReadState(this.allChapterIds(), true)
        })
      MenuItem({ content: s('manga_detail_menu_mark_all_unread') })
        .onClick(() => {
          this.markVisibleChaptersReadState(this.allChapterIds(), false)
        })
      if (this.canCheckLocalLibraryRefresh()) {
        MenuItem({ content: this.localRefreshBusy ? s('manga_detail_local_refresh_checking') : s('manga_detail_menu_check_local_refresh') })
          .onClick(() => {
            this.checkLocalLibraryRefreshNow()
          })
      }
      if (this.canEditLocalMetadata()) {
        MenuItem({ content: s('manga_detail_menu_edit_local_metadata') })
          .onClick(() => {
            this.openLocalMetadataEditor()
          })
      }
      MenuItem({ content: s('manga_detail_menu_find_tracker_mapping') })
        .onClick(() => {
          this.refreshTrackerMappingCandidates()
        })
      MenuItem({ content: s('manga_detail_menu_sync_tracker') })
        .onClick(() => {
          this.syncTrackerProgressNow()
        })
      MenuItem({ content: s('manga_detail_menu_pull_tracker') })
        .onClick(() => {
          this.pullTrackerProgressNow()
        })
    }
  }

  @Builder
  private Toolbar() {
    Row() {
      KomaIconButton({
        icon: $r('sys.symbol.chevron_left'),
        controlSize: ThemeConstants.ACTION_CHIP_HEIGHT,
        iconSize: ThemeConstants.FONT_SIZE_H2,
        action: () => {
          this.onBack()
        },
      })
      Blank()
      KomaIconButton({
        icon: $r('sys.symbol.more'),
        controlSize: ThemeConstants.ACTION_CHIP_HEIGHT,
        iconSize: ThemeConstants.FONT_SIZE_H2,
      })
        .bindMenu(this.DetailMoreMenu())
    }
    .width('100%')
    .height(ThemeConstants.SOURCE_ICON_SIZE)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ActionButtons() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      KomaActionButton({
        label: this.isInLibrary ? s('common_in_library') : s('common_add_to_library'),
        kind: this.isInLibrary ? 'primary' : 'secondary',
        icon: $r('sys.symbol.bookmark'),
        fill: true,
        action: () => {
          this.handleAddToLibrary()
        },
      })

      KomaActionButton({
        label: this.primaryReadLabel(),
        kind: 'primary',
        icon: $r('sys.symbol.doc_plaintext'),
        fill: true,
        action: () => {
          this.handleStartReading()
        },
      })

      KomaActionButton({
        label: this.downloadButtonLabel(),
        kind: 'secondary',
        icon: $r('sys.symbol.arrow_down_to_line'),
        fill: true,
        isEnabled: !this.downloadBusy,
        action: () => {
          this.handleDownloadChapter()
        },
      })
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

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_XL,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
        reserveTitleBar: false,
      }) {
        ListItem() {
          this.Toolbar()
        }

        ListItem() {
          MangaDetailHeader({
            manga: this.displayedManga(),
          })
        }

        ListItem() {
          this.ActionButtons()
        }

        if (this.isLoading || this.feedbackText.length > 0) {
          ListItem() {
            Text(this.isLoading ? s('common_loading') : this.feedbackText)
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

        if (this.localMetadataEditorVisible) {
          ListItem() {
            this.LocalMetadataEditor()
          }
        }

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
    sourceId: undefined,
    sourceName: '',
    url: comic.sourcePath,
  }
}

function mangaChapterItemFromComicChapter(chapter: Chapter): MangaChapterItem {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.index + 1,
    scanlator: chapter.scanlator,
    language: chapter.language,
    dateUpload: chapter.dateUpload,
    isRead: false,
    isDownloaded: chapter.pageCount > 0,
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
      pageCount: 0,
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
    pageCount: 0,
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
    sourceName: normalizedSourceId,
    chapterCount: 0,
    isInLibrary: false,
  }
}
