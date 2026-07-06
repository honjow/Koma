import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaEmptyState } from './ui/KomaEmptyState'
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

@ComponentV2
export struct ChapterListSection {
  @Param chapters: MangaChapterItem[] = []
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sortOrder: ChapterSortOrder = ChapterSortOrder.NEWEST_FIRST
  @Local private readFilter: ChapterReadFilter = ChapterReadFilter.ALL
  @Local private languageFilter: string = ''
  @Local private groupFilter: string = ''
  @Local private sortedChapters: MangaChapterItem[] = []
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
    this.ensureMetadataFiltersAvailable()
    this.sortedChapters = this.sortedChapterList()
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
    let filtered = this.chapters.slice()
    if (this.readFilter === ChapterReadFilter.UNREAD) {
      filtered = filtered.filter((chapter: MangaChapterItem): boolean => !chapter.isRead)
    }
    if (this.readFilter === ChapterReadFilter.READ) {
      filtered = filtered.filter((chapter: MangaChapterItem): boolean => chapter.isRead)
    }
    if (this.readFilter === ChapterReadFilter.DOWNLOADED) {
      filtered = filtered.filter((chapter: MangaChapterItem): boolean => chapter.isDownloaded)
    }
    if (this.languageFilter.length > 0) {
      filtered = filtered.filter((chapter: MangaChapterItem): boolean => {
        return this.normalizeMetadataValue(chapter.language) === this.languageFilter
      })
    }
    if (this.groupFilter.length > 0) {
      filtered = filtered.filter((chapter: MangaChapterItem): boolean => {
        return this.normalizeMetadataValue(chapter.scanlator) === this.groupFilter
      })
    }
    return filtered
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

  private languageFilterLabel(): string {
    if (this.languageFilter.length === 0) {
      return s('chapter_list_filter_language')
    }
    return `${s('chapter_list_filter_language')}: ${this.formatLanguage(this.languageFilter)}`
  }

  private groupFilterLabel(): string {
    if (this.groupFilter.length === 0) {
      return s('chapter_list_filter_group')
    }
    return `${s('chapter_list_filter_group')}: ${this.groupFilter}`
  }

  private setSortOrder(sortOrder: ChapterSortOrder): void {
    this.sortOrder = sortOrder
    this.rebuildDataSource()
  }

  private setReadFilter(readFilter: ChapterReadFilter): void {
    this.readFilter = readFilter
    this.rebuildDataSource()
  }

  private setLanguageFilter(language: string): void {
    this.languageFilter = language
    this.rebuildDataSource()
  }

  private setGroupFilter(group: string): void {
    this.groupFilter = group
    this.rebuildDataSource()
  }

  private hasActiveFilters(): boolean {
    return this.sortOrder !== ChapterSortOrder.NEWEST_FIRST ||
      this.readFilter !== ChapterReadFilter.ALL ||
      this.languageFilter.length > 0 ||
      this.groupFilter.length > 0
  }

  private resetFilters(): void {
    if (!this.hasActiveFilters()) {
      return
    }
    this.sortOrder = ChapterSortOrder.NEWEST_FIRST
    this.readFilter = ChapterReadFilter.ALL
    this.languageFilter = ''
    this.groupFilter = ''
    this.rebuildDataSource()
  }

  private ensureMetadataFiltersAvailable(): void {
    if (this.languageFilter.length > 0 && !this.languageOptions().includes(this.languageFilter)) {
      this.languageFilter = ''
    }
    if (this.groupFilter.length > 0 && !this.groupOptions().includes(this.groupFilter)) {
      this.groupFilter = ''
    }
  }

  private languageOptions(): string[] {
    const values: string[] = []
    this.chapters.forEach((chapter: MangaChapterItem) => {
      const value = this.normalizeMetadataValue(chapter.language)
      if (value.length > 0 && !values.includes(value)) {
        values.push(value)
      }
    })
    values.sort()
    return values
  }

  private groupOptions(): string[] {
    const values: string[] = []
    this.chapters.forEach((chapter: MangaChapterItem) => {
      const value = this.normalizeMetadataValue(chapter.scanlator)
      if (value.length > 0 && !values.includes(value)) {
        values.push(value)
      }
    })
    values.sort()
    return values
  }

  private normalizeMetadataValue(value: string | undefined): string {
    return value === undefined ? '' : value.trim()
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
    if (chapter.language !== undefined && chapter.language.length > 0) {
      parts.push(this.formatLanguage(chapter.language))
    }
    if (chapter.dateUpload !== undefined) {
      parts.push(this.formatDate(chapter.dateUpload))
    }
    return parts.join(' · ')
  }

  private formatLanguage(language: string): string {
    return language.length <= 3 ? language.toLocaleUpperCase() : language
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
  private LanguageFilterMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_filter_language_all') })
        .onClick(() => {
          this.setLanguageFilter('')
        })
      ForEach(this.languageOptions(), (language: string) => {
        MenuItem({ content: this.formatLanguage(language) })
          .onClick(() => {
            this.setLanguageFilter(language)
          })
      }, (language: string) => language)
    }
  }

  @Builder
  private GroupFilterMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_filter_group_all') })
        .onClick(() => {
          this.setGroupFilter('')
        })
      ForEach(this.groupOptions(), (group: string) => {
        MenuItem({ content: group })
          .onClick(() => {
            this.setGroupFilter(group)
          })
      }, (group: string) => group)
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
  private SectionActionsMenu() {
    Menu() {
      MenuItem({ content: s('chapter_list_menu_mark_visible_read') })
        .onClick(() => {
          this.onMarkVisibleChaptersReadState(this.visibleChapterIds(), true)
        })
      MenuItem({ content: s('chapter_list_menu_mark_visible_unread') })
        .onClick(() => {
          this.onMarkVisibleChaptersReadState(this.visibleChapterIds(), false)
        })
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
  private EmptyChapters() {
    KomaEmptyState({
      title: this.chapters.length === 0 ? s('chapter_list_empty_title') : s('chapter_list_filtered_empty_title'),
      message: this.chapters.length === 0 ? s('chapter_list_empty_message') : s('chapter_list_filtered_empty_message'),
      actionLabel: s('common_reset'),
      showAction: this.chapters.length > 0 && this.hasActiveFilters(),
      action: () => {
        this.resetFilters()
      },
    })
  }

  @Builder
  private DownloadedBadge() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([ThemeConstants.BRAND_PRIMARY])
      Text(s('downloads_status_downloaded'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .maxLines(1)
    }
    .height(ThemeConstants.FILTER_CHIP_HEIGHT)
    .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor(ThemeConstants.SOFT_TINT)
  }

  @Builder
  private ChapterRowPrefix(chapter: MangaChapterItem) {
    Row() {
      Blank()
        .width(ThemeConstants.SPACE_SM)
        .height(ThemeConstants.SPACE_SM)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(chapter.isRead ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.BRAND_PRIMARY)
        .opacity(chapter.isRead ? 0.45 : 1)
    }
    .width(24)
    .height(ThemeConstants.TOUCH_TARGET_SM)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ChapterRow(chapter: MangaChapterItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      this.ChapterRowPrefix(chapter)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.chapterTitle(chapter))
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.chapterSubtitle(chapter))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .onClick(() => {
        this.onOpenChapter(chapter.id)
      })

      if (chapter.isDownloaded) {
        this.DownloadedBadge()
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
    .alignItems(VerticalAlign.Center)
    .padding({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
    .opacity(chapter.isRead ? 0.68 : 1)
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.formatString('chapter_list_title', [this.sortedChapters.length, this.chapters.length]))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)

          KomaIconButton({
            icon: $r('sys.symbol.more'),
            kind: 'secondary',
            controlSize: ThemeConstants.TOUCH_TARGET_SM,
            iconSize: ThemeConstants.FONT_SIZE_H3,
          })
            .bindMenu(this.SectionActionsMenu(), {
              placement: Placement.BottomRight,
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Flex({ wrap: FlexWrap.Wrap }) {
          KomaActionButton({
            label: `${this.filterLabel()} ▾`,
            kind: this.readFilter === ChapterReadFilter.ALL ? 'secondary' : 'primary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          })
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.FilterMenu())
          KomaActionButton({
            label: `${this.languageFilterLabel()} ▾`,
            kind: this.languageFilter.length === 0 ? 'secondary' : 'primary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          })
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.LanguageFilterMenu())
          KomaActionButton({
            label: `${this.groupFilterLabel()} ▾`,
            kind: this.groupFilter.length === 0 ? 'secondary' : 'primary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          })
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.GroupFilterMenu())
          KomaActionButton({
            label: `${this.sortLabel()} ↕`,
            kind: this.sortOrder === ChapterSortOrder.NEWEST_FIRST ? 'secondary' : 'primary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          })
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.SortMenu())
          if (this.hasActiveFilters()) {
            KomaActionButton({
              label: s('common_reset'),
              kind: 'ghost',
              compact: true,
              controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
              action: () => {
                this.resetFilters()
              },
            })
              .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          }
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.sortedChapters.length === 0) {
        this.EmptyChapters()
      } else {
        Column() {
          ForEach(this.sortedChapters, (chapter: MangaChapterItem, index: number) => {
            this.ChapterRow(chapter)
            if (index < this.sortedChapters.length - 1) {
              Divider()
                .strokeWidth(1)
                .color(ThemeConstants.DIVIDER)
                .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
            }
          }, (chapter: MangaChapterItem) => chapter.id)
        }
        .width('100%')
        .borderRadius(ThemeConstants.RADIUS_MD)
        .clip(true)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
