import { Chip, ChipSize } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { KomaIconButton } from './ui/KomaIconButton'
import { ChapterSortOrder, MangaChapterItem } from '../model/MangaDetailModels'
import { ThemeConstants } from '../theme/ThemeConstants'

function s(name: string): string {
  return AppStrings.get(name)
}

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

@ComponentV2
export struct ChapterListSection {
  @Param chapters: MangaChapterItem[] = []
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sortOrder: ChapterSortOrder = ChapterSortOrder.NEWEST_FIRST
  @Local private readFilter: ChapterReadFilter = ChapterReadFilter.ALL
  @Local private sortedChapters: MangaChapterItem[] = []
  private dataSource: ChapterListDataSource = new ChapterListDataSource([])
  @Event onOpenChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event onDownloadChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event onDownloadVisibleChapters: (chapterIds: string[], mode: ChapterBatchDownloadMode) => void =
    (_chapterIds: string[], _mode: ChapterBatchDownloadMode) => {}
  @Event onMarkChapterReadState: (chapterId: string, isRead: boolean) => void =
    (_chapterId: string, _isRead: boolean) => {}
  @Event onMarkVisibleChaptersReadState: (chapterIds: string[], isRead: boolean) => void =
    (_chapterIds: string[], _isRead: boolean) => {}

  @Monitor('chapters')
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
      return s('chapter_list_sort_oldest')
    }
    if (this.sortOrder === ChapterSortOrder.BY_NUMBER_DESC) {
      return s('chapter_list_sort_number_desc')
    }
    if (this.sortOrder === ChapterSortOrder.BY_NUMBER_ASC) {
      return s('chapter_list_sort_number_asc')
    }
    return s('chapter_list_sort_newest')
  }

  private filterLabel(): string {
    if (this.readFilter === ChapterReadFilter.UNREAD) {
      return s('chapter_list_filter_unread')
    }
    if (this.readFilter === ChapterReadFilter.READ) {
      return s('chapter_list_filter_read')
    }
    if (this.readFilter === ChapterReadFilter.DOWNLOADED) {
      return s('chapter_list_filter_downloaded')
    }
    return s('chapter_list_filter_all')
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
      return s('library_update_chapter_fallback_title').replace('%s', `${chapter.chapterNumber}`)
    }
    return s('manga_detail_chapter_untitled')
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

  private formatString(key: string, args: Array<string | number>): string {
    let text = s(key)
    args.forEach((value: string | number) => {
      text = text.replace('%s', `${value}`)
    })
    return text
  }

  aboutToAppear(): void {
    this.rebuildDataSource()
  }

  @Builder
  private SortMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_sort_newest') })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.NEWEST_FIRST)
        })
      MenuItem({ content: s('chapter_list_sort_oldest') })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.OLDEST_FIRST)
        })
      MenuItem({ content: s('chapter_list_sort_number_desc') })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.BY_NUMBER_DESC)
        })
      MenuItem({ content: s('chapter_list_sort_number_asc') })
        .onClick(() => {
          this.setSortOrder(ChapterSortOrder.BY_NUMBER_ASC)
        })
    }
  }

  @Builder
  private BatchDownloadMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_menu_download_visible') })
        .onClick(() => {
          this.onDownloadVisibleChapters(this.visibleChapterIds(), ChapterBatchDownloadMode.ALL_VISIBLE)
        })
      MenuItem({ content: s('chapter_list_menu_retry_failed') })
        .onClick(() => {
          this.onDownloadVisibleChapters(this.visibleChapterIds(), ChapterBatchDownloadMode.FAILED_ONLY)
        })
      MenuItem({ content: s('chapter_list_menu_download_incomplete') })
        .onClick(() => {
          this.onDownloadVisibleChapters(this.visibleChapterIds(), ChapterBatchDownloadMode.NOT_DOWNLOADED)
        })
    }
  }

  @Builder
  private FilterMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_filter_all') })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.ALL)
        })
      MenuItem({ content: s('chapter_list_filter_unread') })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.UNREAD)
        })
      MenuItem({ content: s('chapter_list_filter_read') })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.READ)
        })
      MenuItem({ content: s('chapter_list_filter_downloaded') })
        .onClick(() => {
          this.setReadFilter(ChapterReadFilter.DOWNLOADED)
        })
    }
  }

  @Builder
  private ReadStateMenu(chapter: MangaChapterItem) {
    Menu() {
      MenuItem({ content: s('chapter_list_menu_mark_read') })
        .onClick(() => {
          this.onMarkChapterReadState(chapter.id, true)
        })
      MenuItem({ content: s('chapter_list_menu_mark_unread') })
        .onClick(() => {
          this.onMarkChapterReadState(chapter.id, false)
        })
    }
  }

  @Builder
  private VisibleReadStateMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_menu_mark_visible_read') })
        .onClick(() => {
          this.onMarkVisibleChaptersReadState(this.visibleChapterIds(), true)
        })
      MenuItem({ content: s('chapter_list_menu_mark_visible_unread') })
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

      KomaIconButton({
        icon: $r('sys.symbol.arrow_down_to_line'),
        controlSize: ThemeConstants.FILTER_CHIP_HEIGHT,
        iconSize: ThemeConstants.FONT_SIZE_TITLE,
        accentColor: ThemeConstants.BRAND_PRIMARY,
        action: () => {
          this.onDownloadChapter(chapter.id)
        },
      })

      KomaIconButton({
        icon: $r('sys.symbol.more'),
        controlSize: ThemeConstants.FILTER_CHIP_HEIGHT,
        iconSize: ThemeConstants.FONT_SIZE_HEADING,
        accentColor: ThemeConstants.BRAND_PRIMARY,
      })
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
          Text(this.formatString('chapter_list_title', [this.sortedChapters.length, this.chapters.length]))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Row() {
            Chip({
              label: {
                text: `${this.filterLabel()} ▾`,
                fontSize: ThemeConstants.FONT_SIZE_TAG,
                fontColor: ThemeConstants.TEXT_PRIMARY,
                activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
              },
              activated: this.readFilter !== ChapterReadFilter.ALL,
              size: ChipSize.SMALL,
              backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
              activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
              borderRadius: ThemeConstants.RADIUS_ROUND,
              allowClose: false,
            })
          }
          .bindMenu(this.FilterMenu())
          Row() {
            Chip({
              label: {
                text: `${this.sortLabel()} ↕`,
                fontSize: ThemeConstants.FONT_SIZE_TAG,
                fontColor: ThemeConstants.TEXT_PRIMARY,
                activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
              },
              activated: this.sortOrder !== ChapterSortOrder.NEWEST_FIRST,
              size: ChipSize.SMALL,
              backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
              activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
              borderRadius: ThemeConstants.RADIUS_ROUND,
              allowClose: false,
            })
          }
          .bindMenu(this.SortMenu())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Row() {
            Chip({
              label: {
                text: `${s('chapter_list_action_mark')} ▾`,
                fontSize: ThemeConstants.FONT_SIZE_TAG,
                fontColor: ThemeConstants.TEXT_PRIMARY,
                activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
              },
              activated: false,
              size: ChipSize.SMALL,
              backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
              activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
              borderRadius: ThemeConstants.RADIUS_ROUND,
              allowClose: false,
            })
          }
          .bindMenu(this.VisibleReadStateMenu())
          Row() {
            Chip({
              label: {
                text: `${s('chapter_list_action_batch_download')} ▾`,
                fontSize: ThemeConstants.FONT_SIZE_TAG,
                fontColor: ThemeConstants.TEXT_PRIMARY,
                activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
              },
              activated: false,
              size: ChipSize.SMALL,
              backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
              activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
              borderRadius: ThemeConstants.RADIUS_ROUND,
              allowClose: false,
            })
          }
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
