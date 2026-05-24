import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  Chapter,
  Comic,
  ComicId,
  LibraryItem,
  ReadingProgress,
} from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import {
  AppFilesReaderSessionPersistenceAdapter,
  PersistentReaderSessionStore,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'

const HISTORY_LIMIT: number = 50
const MS_PER_MINUTE: number = 60 * 1000
const MS_PER_HOUR: number = 60 * MS_PER_MINUTE
const MS_PER_DAY: number = 24 * MS_PER_HOUR
const MS_PER_MONTH: number = 30 * MS_PER_DAY
const MS_PER_YEAR: number = 365 * MS_PER_DAY

@Component
export struct HistoryPage {
  libraryStore: LibraryStore = createSeededLibraryStore()
  @Prop @Watch('onActiveChanged') active: boolean = false
  @State private historyItems: LibraryItem[] = []
  @State private revision: number = 0
  onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}

  private onActiveChanged(): void {
    if (this.active) {
      this.reloadHistory('tab_active')
    }
  }

  private createReaderSessionStore(): ReaderSessionStore | undefined {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        console.info('[History] step=session_store_unavailable reason=context')
        return undefined
      }
      return new PersistentReaderSessionStore(
        new AppFilesReaderSessionPersistenceAdapter(context.filesDir)
      )
    } catch (error) {
      const e = error as Error
      console.info('[History] step=session_store_unavailable reason=' + e.message)
      return undefined
    }
  }

  private reloadHistory(reason: string): void {
    console.info(`[History] step=load_start reason=${reason}`)
    const sessionStore = this.createReaderSessionStore()
    const progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
    this.libraryStore.listComics().forEach((comic: Comic) => {
      const progress = sessionStore === undefined ? undefined : sessionStore.getProgress(comic.id)
      if (progress !== undefined) {
        progressByComicId.set(comic.id, progress)
      }
    })
    this.historyItems = this.libraryStore.listLibraryItems(progressByComicId)
      .filter((item: LibraryItem) => item.lastReadAt !== undefined)
      .sort((a: LibraryItem, b: LibraryItem) => {
        return (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0)
      })
      .slice(0, HISTORY_LIMIT)
    this.revision += 1
    console.info(`[History] step=load_done count=${this.historyItems.length} revision=${this.revision}`)
  }

  private relativeTime(timestampMs: number | undefined): string {
    if (timestampMs === undefined || timestampMs <= 0) {
      return ''
    }
    const diff = Math.max(0, Date.now() - timestampMs)
    if (diff < MS_PER_MINUTE) {
      return '刚刚'
    }
    if (diff < MS_PER_HOUR) {
      return `${Math.floor(diff / MS_PER_MINUTE)} 分钟前`
    }
    if (diff < MS_PER_DAY) {
      return `${Math.floor(diff / MS_PER_HOUR)} 小时前`
    }
    if (diff < MS_PER_MONTH) {
      return `${Math.floor(diff / MS_PER_DAY)} 天前`
    }
    if (diff < MS_PER_YEAR) {
      return `${Math.floor(diff / MS_PER_MONTH)} 个月前`
    }
    return `${Math.floor(diff / MS_PER_YEAR)} 年前`
  }

  private coverColor(item: LibraryItem): string {
    const colors: string[] = ['#16745F', '#D45B3E', '#2D5E8B', '#8A5A2B', '#6E4A86', '#4D6B3C']
    let hash = 0
    for (let index = 0; index < item.comicId.length; index += 1) {
      hash = (hash + item.comicId.charCodeAt(index)) % colors.length
    }
    return colors[hash]
  }

  private chapterText(item: LibraryItem): string {
    if (item.progress === undefined) {
      return `${item.chapterCount} 章`
    }
    const comic = this.libraryStore.getComic(item.comicId)
    const chapterIndex = comic === undefined ? -1 : comic.chapters.findIndex((chapter: Chapter) => {
      return chapter.id === item.progress?.chapterId
    })
    if (chapterIndex >= 0) {
      return `第 ${chapterIndex + 1} 章`
    }
    return item.progress.chapterId.length > 0 ? '已读章节' : `${item.chapterCount} 章`
  }

  private progressText(item: LibraryItem): string {
    if (item.progress === undefined) {
      return `${item.pageCount} 页 · ${item.chapterCount} 章`
    }
    const page = item.progress.pageIndex + 1
    const total = item.progress.totalPages > 0 ? item.progress.totalPages : item.pageCount
    return `第 ${page} / ${total} 页 · ${this.chapterText(item)}`
  }

  private openHistoryItem(item: LibraryItem): void {
    const chapterId = item.progress === undefined ? undefined : item.progress.chapterId
    console.info(`[History] step=open_resume comic=${item.comicId} chapter=${chapterId ?? ''} page=${item.progress?.pageIndex ?? 0}`)
    this.onOpenReader(item.comicId, chapterId)
  }

  @Builder
  private EmptyHistory() {
    Column({ space: 10 }) {
      Text('暂无阅读历史')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('打开漫画读几页后，最近阅读会显示在这里。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(220)
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private Cover(item: LibraryItem) {
    Stack({ alignContent: Alignment.Center }) {
      if (item.coverUri !== undefined && item.coverUri.length > 0) {
        Image(item.coverUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Text('K')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
    }
    .width(64)
    .height(88)
    .borderRadius(8)
    .clip(true)
    .backgroundColor(this.coverColor(item))
  }

  @Builder
  private HistoryRow(item: LibraryItem) {
    Row({ space: 14 }) {
      this.Cover(item)

      Column({ space: 7 }) {
        Row() {
          Text(item.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.relativeTime(item.lastReadAt))
            .fontSize(12)
            .fontColor($r('app.color.koma_text_secondary'))
            .margin({ left: 10 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(this.progressText(item))
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Progress({
          value: item.progress === undefined ? 0 : Math.round(item.progress.progressRatio * 100),
          total: 100,
          type: ProgressType.Linear,
        })
          .height(4)
          .color($r('app.color.koma_accent'))
          .backgroundColor('#1FE66A3A')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.openHistoryItem(item)
    })
  }

  aboutToAppear(): void {
    this.reloadHistory('appear')
  }

  onPageShow(): void {
    this.reloadHistory('page_show')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 12,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        if (this.historyItems.length === 0) {
          ListItem() {
            this.EmptyHistory()
          }
        } else {
          ForEach(this.historyItems, (item: LibraryItem) => {
            ListItem() {
              this.HistoryRow(item)
            }
          }, (item: LibraryItem) => `${this.revision}:${item.comicId}:${item.lastReadAt ?? 0}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
