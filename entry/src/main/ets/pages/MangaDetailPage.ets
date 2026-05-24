import { MangaDetailHeader } from '../components/MangaDetailHeader'
import { MangaDescriptionSection } from '../components/MangaDescriptionSection'
import { MangaTagsSection } from '../components/MangaTagsSection'
import { ChapterListSection } from '../components/ChapterListSection'
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
  normalizeSortKey,
} from '../model/ComicModels'
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
import { taskpool } from '@kit.ArkTS'

export const MANGA_DETAIL_ROUTE_NAME: string = 'MangaDetailPage'

interface MangaDetailRouteParams {
  mangaId?: string
  sourceId?: string
}

interface SourceOperationDataPayload {
  items?: Record<string, Object>[]
}

interface SourceOperationResponsePayload {
  ok?: boolean
  data?: SourceOperationDataPayload
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
  @State private feedbackText: string = ''
  libraryStore?: LibraryStore
  libraryPersistenceService?: LibraryStorePersistenceService
  sourceRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  onBack: () => void = () => {}
  onOpenReader: (mangaId: string, chapterId?: string) => void = (_mangaId: string, _chapterId?: string) => {}
  onLibraryChanged: () => void = () => {}

  aboutToAppear(): void {
    this.loadMangaDetail()
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
      return
    }
    this.manga = mangaDetailFromComic(comic)
    this.chapters = comic.chapters.map((chapter: Chapter): MangaChapterItem => mangaChapterItemFromComicChapter(chapter))
    this.isInLibrary = true
    this.feedbackText = ''
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
    } catch (error) {
      const e = error as Error
      console.error('[manga-detail] source detail load failed: ' + e.message)
      this.manga = _mockMangaDetail(mangaId, sourceId)
      this.chapters = _mockChapterList()
      this.isInLibrary = false
      this.feedbackText = '源详情加载失败，已显示占位内容。'
    } finally {
      this.isLoading = false
    }
  }

  private async runSourceMangaOperation(
    entry: SourceRuntimeRegistryEntry,
    operation: string,
    mangaId: string
  ): Promise<MangaDetail> {
    const request = JSON.stringify({ operation: operation, manga_id: mangaId })
    const responseJson = await taskpool.execute(
      executeMangaDetailSourceOperation,
      request,
      new Uint8Array(entry.wasmBytes.buffer)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    const item = response.data?.items === undefined || response.data.items.length === 0 ? undefined : response.data.items[0]
    if (response.ok !== true || item === undefined) {
      throw new Error('get_manga returned no item')
    }
    return parseMangaDetailFromSourceItem(entry.sourceId, item)
  }

  private async runSourceChaptersOperation(
    entry: SourceRuntimeRegistryEntry,
    mangaId: string
  ): Promise<MangaChapterItem[]> {
    const request = JSON.stringify({ operation: 'get_chapters', manga_id: mangaId })
    const responseJson = await taskpool.execute(
      executeMangaDetailSourceOperation,
      request,
      new Uint8Array(entry.wasmBytes.buffer)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    if (response.ok !== true || response.data?.items === undefined) {
      throw new Error('get_chapters returned no items')
    }
    return response.data.items.map((item: Record<string, Object>): MangaChapterItem => {
      return parseMangaChapterFromSourceItem(item)
    })
  }

  private sourceComicId(sourceId: string | undefined, mangaId: string): string {
    return sourceId === undefined || sourceId.trim().length === 0 ? mangaId : `${sourceId}:${mangaId}`
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
    this.onOpenReader(this.currentComicId(), this.firstChapterId())
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

        MangaDescriptionSection({
          description: this.manga.description,
        })

        MangaTagsSection({
          tags: this.manga.tags === undefined ? [] : this.manga.tags,
        })

        ChapterListSection({
          chapters: this.chapters,
          onOpenChapter: (chapterId: string) => {
            this.onOpenReader(this.manga.id, chapterId)
          },
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 32 })
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
