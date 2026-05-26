import { MangaDetailHeader } from '../components/MangaDetailHeader'
import { common } from '@kit.AbilityKit'
import { MangaDescriptionSection } from '../components/MangaDescriptionSection'
import { MangaTagsSection } from '../components/MangaTagsSection'
import { ChapterListSection } from '../components/ChapterListSection'
import { StorageKeys } from '../constants/StorageKeys'
import { ThemeConstants } from '../theme/ThemeConstants'
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
  Page,
  ReadingDirection,
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
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
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
}

interface SourceOperationResponsePayload {
  ok?: boolean
  data?: SourceOperationDataPayload
}

interface SourcePagesRequestArgs {
  chapterId: string
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

interface SourcePagesRequestHostHints extends SourceDetailRequestHostHints {
  imageStrategy: string
}

interface SourceDetailRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceMangaRequestArgs | SourceChaptersRequestArgs | SourcePagesRequestArgs
  settings: SourceSettingsRecord
  hostHints: SourceDetailRequestHostHints | SourcePagesRequestHostHints
}

@Concurrent
function executeMangaDetailSourceOperation(requestJson: string, wasmBytes: Uint8Array): string {
  const response = runSourceOperationFromBytes(requestJson, wasmBytes)
  return JSON.stringify(response)
}

@Component
export struct MangaDetailPage {
  @Prop params: MangaDetailRouteParams = {}
  @State private manga: MangaDetail = _mockMangaDetail()
  @State private chapters: MangaChapterItem[] = _mockChapterList()
  @State private isInLibrary: boolean = false
  @State private isLoading: boolean = false
  @State private downloadBusy: boolean = false
  @State private downloadStatusText: string = ''
  @State private feedbackText: string = ''
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  libraryStore?: LibraryStore
  libraryPersistenceService?: LibraryStorePersistenceService
  sourceRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  onBack: () => void = () => {}
  onOpenReader: (mangaId: string, chapterId?: string) => void = (_mangaId: string, _chapterId?: string) => {}
  onLibraryChanged: () => void = () => {}

  private topContentInset(): number {
    return this.topH + 12
  }

  private bottomContentInset(): number {
    return this.bottomH + ThemeConstants.FLOAT_BAR_HEIGHT + 20
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
    this.loadLocalOrMockManga(mangaId)
  }

  private loadLocalOrMockManga(mangaId?: string): void {
    const comic = mangaId === undefined || this.libraryStore === undefined ? undefined : this.libraryStore.getComic(mangaId)
    if (comic === undefined) {
      this.manga = _mockMangaDetail(mangaId, this.params.sourceId)
      this.chapters = _mockChapterList()
      this.isInLibrary = this.manga.isInLibrary
      this.feedbackText = ''
      this.refreshDownloadStatus()
      return
    }
    this.manga = mangaDetailFromComic(comic)
    this.chapters = comic.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter))
    this.isInLibrary = true
    this.feedbackText = ''
    this.refreshDownloadStatus()
  }

  private async loadSourceMangaDetail(sourceId: string, mangaId: string): Promise<void> {
    this.isLoading = true
    this.feedbackText = '正在加载源详情...'
    try {
      const lookup = this.sourceRegistry.lookup(sourceId)
      if (!lookup.ok || lookup.entry === undefined) {
        throw new Error(lookup.reasonCode ?? 'source lookup failed')
      }
      const detail = await this.runSourceMangaOperation(lookup.entry, 'get_manga', mangaId)
      const chapters = await this.runSourceChaptersOperation(lookup.entry, mangaId)
      const comicId = this.sourceComicId(sourceId, mangaId)
      detail.chapterCount = chapters.length
      detail.isInLibrary = this.libraryStore?.getComic(comicId) !== undefined
      detail.sourceName = lookup.entry.manifestName
      this.manga = detail
      this.chapters = chapters
      this.isInLibrary = detail.isInLibrary
      this.feedbackText = ''
      this.refreshDownloadStatus()
    } catch (error) {
      const e = error as Error
      console.error('[manga-detail] source detail load failed: ' + e.message)
      this.manga = _mockMangaDetail(mangaId, sourceId)
      this.chapters = _mockChapterList()
      this.isInLibrary = false
      this.feedbackText = '源详情加载失败，已显示占位内容。'
      this.downloadStatusText = ''
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
    const args: SourceChaptersRequestArgs = {
      mangaId,
      page: {
        cursor: null,
        limit: 100,
      },
    }
    const request = this.buildSourceDetailRequestJson(entry.sourceId, 'get_chapters', args, { network: true })
    const responseJson = await taskpool.execute(
      executeMangaDetailSourceOperation,
      request,
      this.copyWasmBytes(entry)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    const rows = this.sourceChapterResponseItems(response)
    if (response.ok !== true || rows.length === 0) {
      throw new Error('get_chapters returned no items')
    }
    return rows.map((item: Record<string, Object>): MangaChapterItem => {
      return parseMangaChapterFromSourceItem(item)
    })
  }

  private buildSourceDetailRequestJson(
    sourceId: string,
    operation: string,
    args: SourceMangaRequestArgs | SourceChaptersRequestArgs | SourcePagesRequestArgs,
    hostHints: SourceDetailRequestHostHints | SourcePagesRequestHostHints,
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

  private async handleAddToLibrary(): Promise<boolean> {
    if (this.isInLibrary) {
      this.showToast('已在书架中')
      return true
    }
    if (this.libraryStore === undefined) {
      this.feedbackText = '书架不可用。'
      this.showToast('书架不可用')
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
      this.feedbackText = '已收藏到书架。'
      this.onLibraryChanged()
      this.refreshDownloadStatus()
      this.showToast('已收藏到书架')
      return true
    } catch (error) {
      const e = error as Error
      console.error('[manga-detail] add to library failed: ' + e.message)
      this.feedbackText = '收藏失败。'
      this.showToast('收藏失败')
      return false
    }
  }

  private async handleStartReading(): Promise<void> {
    if (!this.isInLibrary && this.manga.sourceId !== undefined) {
      const added = await this.handleAddToLibrary()
      if (!added) {
        return
      }
    }
    if (this.manga.sourceId !== undefined && this.firstChapterId() !== undefined) {
      await this.ensureSourceChapterPages(this.firstChapterId() as string)
    }
    this.onOpenReader(this.currentComicId(), this.firstChapterId())
  }

  private async handleDownloadChapter(chapterId?: string): Promise<void> {
    if (this.downloadBusy) {
      return
    }
    const resolvedChapterId = chapterId ?? this.firstChapterId()
    if (resolvedChapterId === undefined) {
      this.downloadStatusText = '暂无可下载章节'
      this.showToast('暂无可下载章节')
      return
    }
    const service = this.offlineDownloadService()
    if (service === undefined) {
      this.downloadStatusText = '下载不可用'
      this.showToast('下载不可用')
      return
    }
    this.downloadBusy = true
    this.downloadStatusText = '下载中...'
    try {
      if (!this.isInLibrary && this.manga.sourceId !== undefined) {
        const added = await this.handleAddToLibrary()
        if (!added) {
          this.downloadStatusText = '下载已取消'
          return
        }
      }
      if (this.manga.sourceId !== undefined) {
        await this.ensureSourceChapterPages(resolvedChapterId)
      }
      const comic = this.libraryStore?.getComic(this.currentComicId())
      if (comic === undefined) {
        this.downloadStatusText = '请先收藏到书架'
        this.showToast('请先收藏到书架')
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
      this.downloadStatusText = this.formatDownloadStatus({
        comicId: manifest.comicId,
        chapterId: manifest.chapterId,
        pageCount: manifest.pageCount,
        downloadedPageCount: manifest.downloadedPageCount,
        status: manifest.status,
        updatedAt: manifest.updatedAt,
      })
      this.showToast(manifest.status === OfflineDownloadStatus.DOWNLOADED ? '章节已下载' : '章节下载失败')
    } finally {
      this.downloadBusy = false
    }
  }

  private async ensureSourceChapterPages(chapterId: string): Promise<void> {
    if (this.libraryStore === undefined || this.manga.sourceId === undefined) {
      return
    }
    const comic = this.libraryStore.getComic(this.currentComicId())
    const chapter = comic?.chapters.find((item: Chapter): boolean => item.id === chapterId)
    if (comic === undefined || chapter === undefined || chapter.pages.length > 0) {
      return
    }
    const lookup = this.sourceRegistry.lookup(this.manga.sourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      throw new Error(lookup.reasonCode ?? 'source lookup failed')
    }
    const pages = await this.runSourcePagesOperation(lookup.entry, comic.id, chapterId)
    chapter.pages = pages
    chapter.pageCount = pages.length
    chapter.updatedAt = Date.now()
    comic.pageCount = comic.chapters.reduce((total: number, item: Chapter): number => total + item.pageCount, 0)
    comic.updatedAt = chapter.updatedAt
    if (this.libraryPersistenceService === undefined) {
      this.libraryStore.upsertComic(comic)
    } else {
      upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
    }
    this.onLibraryChanged()
  }

  private async runSourcePagesOperation(
    entry: SourceRuntimeRegistryEntry,
    comicId: string,
    chapterId: string
  ): Promise<Page[]> {
    const args: SourcePagesRequestArgs = { chapterId }
    const hostHints: SourcePagesRequestHostHints = { network: true, imageStrategy: 'descriptor-or-url' }
    const request = this.buildSourceDetailRequestJson(entry.sourceId, 'get_pages', args, hostHints)
    const responseJson = await taskpool.execute(
      executeMangaDetailSourceOperation,
      request,
      this.copyWasmBytes(entry)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    const rows = response.data?.pages !== undefined ? response.data.pages : (response.data?.items ?? [])
    if (response.ok !== true || rows.length === 0) {
      throw new Error('get_pages returned no pages')
    }
    return rows.map((item: Record<string, Object>, index: number): Page => {
      const pageId = this.optionalSourceString(item['id']) ?? this.optionalSourceString(item['pageId']) ?? `${chapterId}:page:${index + 1}`
      const url = this.sourcePageImageUrl(item) ?? ''
      const page: Page = {
        id: pageId,
        comicId,
        chapterId,
        index,
        fileName: `source-page-${index + 1}`,
        uri: url,
        sortKey: `${index}`.padStart(6, '0'),
      }
      const width = this.optionalSourceNumber(item['width'])
      if (width !== undefined) {
        page.width = width
      }
      const height = this.optionalSourceNumber(item['height'])
      if (height !== undefined) {
        page.height = height
      }
      return page
    })
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

  private sourcePageImageUrl(item: Record<string, Object>): string | undefined {
    const directUrl = this.optionalSourceString(item['url']) ?? this.optionalSourceString(item['uri'])
    if (directUrl !== undefined) {
      return directUrl
    }
    const image = item['image']
    if (image === undefined || image === null || Array.isArray(image) || typeof image !== 'object') {
      return undefined
    }
    const imageRecord = image as Record<string, Object>
    return this.optionalSourceString(imageRecord['url']) ?? this.optionalSourceString(imageRecord['uri'])
  }

  private optionalSourceNumber(value: Object | string | number | boolean | null | undefined): number | undefined {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    if (typeof value !== 'string') {
      return undefined
    }
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : undefined
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
      sourceName: this.manga.sourceName,
      chapterCount: this.chapters.length,
      isInLibrary: this.isInLibrary,
      url: this.manga.url,
    }
  }

  private primaryReadLabel(): string {
    return this.chapters.some((chapter: MangaChapterItem): boolean => chapter.isRead) ? '继续阅读' : '开始阅读'
  }

  private formatDownloadStatus(summary: OfflineDownloadSummary | undefined): string {
    if (summary === undefined) {
      return ''
    }
    if (summary.status === OfflineDownloadStatus.DOWNLOADED) {
      return `已下载 ${summary.downloadedPageCount}/${summary.pageCount} 页`
    }
    if (summary.status === OfflineDownloadStatus.DOWNLOADING || summary.status === OfflineDownloadStatus.QUEUED) {
      return `下载中 ${summary.downloadedPageCount}/${summary.pageCount} 页`
    }
    if (summary.status === OfflineDownloadStatus.PARTIAL) {
      return `部分下载 ${summary.downloadedPageCount}/${summary.pageCount} 页`
    }
    if (summary.status === OfflineDownloadStatus.BLOCKED) {
      return '暂无法下载'
    }
    return '下载失败'
  }

  private downloadButtonLabel(): string {
    if (this.downloadBusy) {
      return '下载中'
    }
    return this.downloadStatusText.startsWith('已下载 ') ? '重新下载' : '下载章节'
  }

  @Builder
  private Toolbar() {
    Row() {
      Button('‹')
        .width(40)
        .height(40)
        .borderRadius(8)
        .fontSize(30)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#00000000')
        .onClick(() => {
          this.onBack()
        })
      Blank()
      Button('…')
        .width(40)
        .height(40)
        .borderRadius(8)
        .fontSize(24)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#00000000')
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ActionButtons() {
    Row({ space: 12 }) {
      Button(this.isInLibrary ? '已收藏' : '收藏书架', { type: ButtonType.Capsule })
        .height(44)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isInLibrary ? Color.White : $r('app.color.koma_accent'))
        .backgroundColor(this.isInLibrary ? $r('app.color.koma_accent') : '#00000000')
        .border({ width: 1, color: $r('app.color.koma_accent') })
        .onClick(() => {
          this.handleAddToLibrary()
        })

      Button(this.primaryReadLabel(), { type: ButtonType.Capsule })
        .height(44)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.koma_accent'))
        .onClick(() => {
          this.handleStartReading()
        })

      Button(this.downloadButtonLabel(), { type: ButtonType.Capsule })
        .height(44)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_accent'))
        .backgroundColor('#00000000')
        .border({ width: 1, color: $r('app.color.koma_accent') })
        .enabled(!this.downloadBusy)
        .onClick(() => {
          this.handleDownloadChapter()
        })
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        this.Toolbar()

        MangaDetailHeader({
          manga: this.displayedManga(),
        })

        this.ActionButtons()

        if (this.isLoading || this.feedbackText.length > 0) {
          Text(this.isLoading ? '加载中...' : this.feedbackText)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
        }

        if (this.downloadStatusText.length > 0) {
          Text(this.downloadStatusText)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
        }

        MangaDescriptionSection({
          description: this.manga.description,
        })

        MangaTagsSection({
          tags: this.manga.tags === undefined ? [] : this.manga.tags,
        })

        ChapterListSection({
          chapters: this.chapters,
          onOpenChapter: (chapterId: string) => {
            void this.ensureSourceChapterPages(chapterId)
              .then(() => {
                this.onOpenReader(this.currentComicId(), chapterId)
              })
              .catch((error: Error) => {
                console.error('[manga-detail] source pages load failed: ' + error.message)
                this.showToast('章节页面加载失败')
              })
          },
          onDownloadChapter: (chapterId: string) => {
            this.handleDownloadChapter(chapterId)
          },
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.topContentInset(), bottom: this.bottomContentInset() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.koma_background'))
  }
}

function mangaDetailFromComic(comic: Comic): MangaDetail {
  return {
    id: comic.id,
    title: comic.title,
    author: comic.author,
    description: comic.subtitle,
    coverUrl: comic.coverUri,
    status: MangaStatus.UNKNOWN,
    chapterCount: comic.chapterCount,
    isInLibrary: true,
    sourceId: undefined,
    sourceName: '书架',
    url: comic.sourcePath,
  }
}

function mangaChapterItemFromComicChapter(chapter: Chapter): MangaChapterItem {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.index + 1,
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
      title: chapter.title.length > 0 ? chapter.title : `第${index + 1}话`,
      index,
      sourcePath: `${manga.url ?? manga.id}#${chapter.id}`,
      sortKey: chapter.chapterNumber === undefined ? `${index}` : `${chapter.chapterNumber}`,
      pages: [],
      pageCount: 0,
      createdAt: now,
      updatedAt: now,
    }
  })
  return {
    id: comicId,
    title: manga.title,
    subtitle: manga.description,
    author: manga.author,
    sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
    sourcePath: manga.url ?? `source://${manga.sourceId ?? 'unknown'}/${manga.id}`,
    sourceRuntimeId: manga.sourceId,
    coverUri: manga.coverUrl,
    sortTitle: normalizeSortKey(manga.title),
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters: comicChapters,
    chapterCount: comicChapters.length,
    pageCount: 0,
    createdAt: now,
    updatedAt: now,
    lastImportedAt: now,
  }
}

function _mockMangaDetail(mangaId?: string, sourceId?: string): MangaDetail {
  const resolvedSourceId = sourceId === undefined || sourceId.length === 0 ? 'mock-source' : sourceId
  return {
    id: mangaId === undefined || mangaId.length === 0 ? 'mock-rain-after-town' : mangaId,
    title: '雨后街区',
    author: '青井遥',
    artist: '青井遥',
    description: '一场漫长的梅雨结束后，旧城区的每个人都像重新学会呼吸。高中生真央在整理祖母留下的照相馆时，发现了一卷没有显影的胶片，也因此遇见了总在末班车前出现的少年。两个人沿着被雨水洗亮的街道，寻找照片里消失的夏天。',
    status: MangaStatus.ONGOING,
    tags: ['剧情', '青春', '日常', '治愈', '悬疑', '摄影', '城市'],
    sourceId: resolvedSourceId,
    sourceName: 'Mock Source',
    chapterCount: 128,
    isInLibrary: false,
    url: 'https://example.invalid/manga/rain-after-town',
  }
}

function _mockChapterList(): MangaChapterItem[] {
  const chapters: MangaChapterItem[] = []
  const startTime = new Date(2024, 0, 15).getTime()
  const weekMs = 7 * 24 * 60 * 60 * 1000
  for (let index = 128; index >= 1; index -= 1) {
    chapters.push({
      id: `chapter-${index}`,
      title: `第${index}话 ${_mockChapterTitle(index)}`,
      chapterNumber: index,
      scanlator: index % 3 === 0 ? 'Koma 汉化组' : '官方',
      dateUpload: startTime - (128 - index) * weekMs,
      isRead: index > 122,
      isDownloaded: index === 128 || index === 127,
    })
  }
  return chapters
}

function _mockChapterTitle(index: number): string {
  const titles: string[] = ['雨停之后', '旧照片', '便利店灯光', '七分钟', '借来的伞', '河岸边', '暗房', '下一班车']
  return titles[index % titles.length]
}
