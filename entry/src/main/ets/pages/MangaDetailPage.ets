import { MangaDetailHeader } from '../components/MangaDetailHeader'
import { MangaDescriptionSection } from '../components/MangaDescriptionSection'
import { MangaTagsSection } from '../components/MangaTagsSection'
import { ChapterListSection } from '../components/ChapterListSection'
import { MangaChapterItem, MangaDetail, MangaStatus } from '../model/MangaDetailModels'

export const MANGA_DETAIL_ROUTE_NAME: string = 'MangaDetailPage'

interface MangaDetailRouteParams {
  mangaId?: string
  sourceId?: string
}

@Component
export struct MangaDetailPage {
  @Prop params: MangaDetailRouteParams = {}
  @State private manga: MangaDetail = _mockMangaDetail()
  @State private chapters: MangaChapterItem[] = _mockChapterList()
  @State private isInLibrary: boolean = false
  onBack: () => void = () => {}
  onOpenReader: (mangaId: string, chapterId?: string) => void = (_mangaId: string, _chapterId?: string) => {}

  aboutToAppear(): void {
    this.manga = _mockMangaDetail(this.params.mangaId, this.params.sourceId)
    this.chapters = _mockChapterList()
    this.isInLibrary = this.manga.isInLibrary
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
          this.isInLibrary = !this.isInLibrary
        })

      Button(this.primaryReadLabel(), { type: ButtonType.Capsule })
        .height(44)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.koma_accent'))
        .onClick(() => {
          this.onOpenReader(this.manga.id)
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
