import { ChapterSortOrder, MangaChapterItem } from '../model/MangaDetailModels'
import { ThemeConstants } from '../theme/ThemeConstants'

export enum ChapterReadFilter {
  ALL = 'all',
  UNREAD = 'unread',
  READ = 'read',
  DOWNLOADED = 'downloaded',
}

export enum ChapterBatchDownloadMode {
  ALL_VISIBLE = 'all_visible',
  FAILED_ONLY = 'failed_only',
  NOT_DOWNLOADED = 'not_downloaded',
}

class ChapterListDataSource implements IDataSource {
  private listeners: DataChangeListener[] = []
  private chapters: MangaChapterItem[] = []

  constructor(chapters: MangaChapterItem[]) {
    this.chapters = chapters
  }

  totalCount(): number {
    return this.chapters.length
  }

  getData(index: number): MangaChapterItem {
    return this.chapters[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  update(chapters: MangaChapterItem[]): void {
    this.chapters = chapters
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded()
    })
  }
}

@Component
export struct ChapterListSection {
  @Prop @Watch('rebuildDataSource') chapters: MangaChapterItem[] = []
  @State private sortOrder: ChapterSortOrder = ChapterSortOrder.NEWEST_FIRST
  @State private readFilter: ChapterReadFilter = ChapterReadFilter.ALL
  @State private sortedChapters: MangaChapterItem[] = []
  private dataSource: ChapterListDataSource = new ChapterListDataSource([])
  onOpenChapter: (chapterId: string) => void = (_chapterId: string) => {}
  onDownloadChapter: (chapterId: string) => void = (_chapterId: string) => {}
  onDownloadVisibleChapters: (chapterIds: string[], mode: ChapterBatchDownloadMode) => void =
    (_chapterIds: string[], _mode: ChapterBatchDownloadMode) => {}
  onMarkChapterReadState: (chapterId: string, isRead: boolean) => void =
    (_chapterId: string, _isRead: boolean) => {}
  onMarkVisibleChaptersReadState: (chapterIds: string[], isRead: boolean) => void =
    (_chapterIds: string[], _isRead: boolean) => {}

  private rebuildDataSource(): void {
    this.sortedChapters = this.sortedChapterList()
    this.dataSource.update(this.sortedChapters)
  }

  private sortedChapterList(): MangaChapterItem[] {
    const sorted = this.filteredChapterList()
    sorted.sort((left: MangaChapterItem, right: MangaChapterItem): number => {
      if (this.sortOrder === ChapterSortOrder.OLDEST_FIRST) {
        return this.dateValue(left) - this.dateValue(right)
      }
      if (this.sortOrder === ChapterSortOrder.BY_NUMBER_DESC) {
        return this.chapterNumberValue(right) - this.chapterNumberValue(left)
      }
      if (this.sortOrder === ChapterSortOrder.BY_NUMBER_ASC) {
        return this.chapterNumberValue(left) - this.chapterNumberValue(right)
      }
      return this.dateValue(right) - this.dateValue(left)
    })
    return sorted
  }

  private filteredChapterList(): MangaChapterItem[] {
    if (this.readFilter === ChapterReadFilter.UNREAD) {
      return this.chapters.filter((chapter: MangaChapterItem): boolean => !chapter.isRead)
    }
    if (this.readFilter === ChapterReadFilter.READ) {
      return this.chapters.filter((chapter: MangaChapterItem): boolean => chapter.isRead)
    }
    if (this.readFilter === ChapterReadFilter.DOWNLOADED) {
      return this.chapters.filter((chapter: MangaChapterItem): boolean => chapter.isDownloaded)
    }
    return this.chapters.slice()
  }

  private dateValue(chapter: MangaChapterItem): number {
    return chapter.dateUpload === undefined ? 0 : chapter.dateUpload
  }

  private chapterNumberValue(chapter: MangaChapterItem): number {
    return chapter.chapterNumber === undefined ? -1 : chapter.chapterNumber
  }

  private sortLabel(): string {
    if (this.sortOrder === ChapterSortOrder.OLDEST_FIRST) {
      return '最旧优先'
    }
    if (this.sortOrder === ChapterSortOrder.BY_NUMBER_DESC) {
      return '话数降序'
    }
    if (this.sortOrder === ChapterSortOrder.BY_NUMBER_ASC) {
      return '话数升序'
    }
    return '最新优先'
  }

  private filterLabel(): string {
    if (this.readFilter === ChapterReadFilter.UNREAD) {
      return '未读'
    }
    if (this.readFilter === ChapterReadFilter.READ) {
      return '已读'
    }
    if (this.readFilter === ChapterReadFilter.DOWNLOADED) {
      return '已下载'
    }
    return '全部'
  }

  private setSortOrder(sortOrder: ChapterSortOrder): void {
    this.sortOrder = sortOrder
    this.rebuildDataSource()
  }

  private setReadFilter(readFilter: ChapterReadFilter): void {
    this.readFilter = readFilter
    this.rebuildDataSource()
  }

  private visibleChapterIds(): string[] {
    return this.sortedChapters.map((chapter: MangaChapterItem): string => chapter.id)
  }

  private chapterTitle(chapter: MangaChapterItem): string {
    if (chapter.title.length > 0) {
      return chapter.title
    }
    if (chapter.chapterNumber !== undefined) {
      return `第${chapter.chapterNumber}话`
    }
    return '未命名章节'
  }

  private chapterSubtitle(chapter: MangaChapterItem): string {
    const parts: string[] = []
    if (chapter.scanlator !== undefined && chapter.scanlator.length > 0) {
      parts.push(chapter.scanlator)
    }
    if (chapter.dateUpload !== undefined) {
      parts.push(this.formatDate(chapter.dateUpload))
    }
    return parts.join(' · ')
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp)
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${date.getFullYear()}-${this.pad2(month)}-${this.pad2(day)}`
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  aboutToAppear(): void {
    this.rebuildDataSource()
  }

  @Builder
  private SortMenu() {
    Menu() {
      MenuItem({ content: '最新优先' })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.NEWEST_FIRST)
        })
      MenuItem({ content: '最旧优先' })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.OLDEST_FIRST)
        })
      MenuItem({ content: '话数降序' })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.BY_NUMBER_DESC)
        })
      MenuItem({ content: '话数升序' })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.BY_NUMBER_ASC)
        })
    }
  }

  @Builder
  private BatchDownloadMenu() {
    Menu() {
      MenuItem({ content: '下载可见章节' })
        .onClick(() => {
          this.onDownloadVisibleChapters(this.visibleChapterIds(), ChapterBatchDownloadMode.ALL_VISIBLE)
        })
      MenuItem({ content: '仅重试失败' })
        .onClick(() => {
          this.onDownloadVisibleChapters(this.visibleChapterIds(), ChapterBatchDownloadMode.FAILED_ONLY)
        })
      MenuItem({ content: '下载未完成' })
        .onClick(() => {
          this.onDownloadVisibleChapters(this.visibleChapterIds(), ChapterBatchDownloadMode.NOT_DOWNLOADED)
        })
    }
  }

  @Builder
  private FilterMenu() {
    Menu() {
      MenuItem({ content: '全部' })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.ALL)
        })
      MenuItem({ content: '未读' })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.UNREAD)
        })
      MenuItem({ content: '已读' })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.READ)
        })
      MenuItem({ content: '已下载' })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.DOWNLOADED)
        })
    }
  }

  @Builder
  private ReadStateMenu(chapter: MangaChapterItem) {
    Menu() {
      MenuItem({ content: '标记已读' })
        .onClick(() => {
          this.onMarkChapterReadState(chapter.id, true)
        })
      MenuItem({ content: '标记未读' })
        .onClick(() => {
          this.onMarkChapterReadState(chapter.id, false)
        })
    }
  }

  @Builder
  private VisibleReadStateMenu() {
    Menu() {
      MenuItem({ content: '可见章节标记已读' })
        .onClick(() => {
          this.onMarkVisibleChaptersReadState(this.visibleChapterIds(), true)
        })
      MenuItem({ content: '可见章节标记未读' })
        .onClick(() => {
          this.onMarkVisibleChaptersReadState(this.visibleChapterIds(), false)
        })
    }
  }

  @Builder
  private ChapterRow(chapter: MangaChapterItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Blank()
          .width(ThemeConstants.SPACE_SM)
          .height(ThemeConstants.SPACE_SM)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor(chapter.isRead ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.BRAND_PRIMARY)
          .opacity(chapter.isRead ? 0.45 : 1)

        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.chapterTitle(chapter))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(chapter.isRead ? FontWeight.Regular : FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.chapterSubtitle(chapter))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onOpenChapter(chapter.id)
      })

      if (chapter.isDownloaded) {
        Text('↓')
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }

      Button('↓')
        .width(ThemeConstants.FILTER_CHIP_HEIGHT)
        .height(ThemeConstants.FILTER_CHIP_HEIGHT)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onDownloadChapter(chapter.id)
        })

      Button('⋯')
        .width(ThemeConstants.FILTER_CHIP_HEIGHT)
        .height(ThemeConstants.FILTER_CHIP_HEIGHT)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .backgroundColor(Color.Transparent)
        .bindMenu(this.ReadStateMenu(chapter))
    }
    .width('100%')
    .height(62)
    .padding({ left: 14, right: 14 })
    .opacity(chapter.isRead ? 0.68 : 1)
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row() {
          Text(`章节 (${this.sortedChapters.length}/${this.chapters.length})`)
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Button(`${this.filterLabel()} ▾`)
            .height(ThemeConstants.FILTER_CHIP_HEIGHT)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(Color.Transparent)
            .bindMenu(this.FilterMenu())
          Button(`${this.sortLabel()} ↕`)
            .height(ThemeConstants.FILTER_CHIP_HEIGHT)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(Color.Transparent)
            .bindMenu(this.SortMenu())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Button('标记 ▾')
            .height(ThemeConstants.FILTER_CHIP_HEIGHT)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(Color.Transparent)
            .bindMenu(this.VisibleReadStateMenu())
          Button('批量下载 ▾')
            .height(ThemeConstants.FILTER_CHIP_HEIGHT)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(Color.Transparent)
            .bindMenu(this.BatchDownloadMenu())
          Blank()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      List() {
        LazyForEach(this.dataSource, (chapter: MangaChapterItem) => {
          ListItem() {
            this.ChapterRow(chapter)
          }
        }, (chapter: MangaChapterItem) => chapter.id)
      }
      .width('100%')
      .height(460)
      .divider({ strokeWidth: 1, color: ThemeConstants.DIVIDER, startMargin: ThemeConstants.SPACE_MD, endMargin: ThemeConstants.SPACE_MD })
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
