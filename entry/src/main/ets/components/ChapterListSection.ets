import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaEmptyState } from './ui/KomaEmptyState'
import { KomaIconButton } from './ui/KomaIconButton'
import { ChapterSortOrder, MangaChapterDownloadStatus, MangaChapterItem } from '../model/MangaDetailModels'
import { ThemeConstants } from '../theme/ThemeConstants'

function s(name: string): string {
  return AppStrings.get(name)
}

const INITIAL_VISIBLE_CHAPTER_LIMIT: number = 80
const VISIBLE_CHAPTER_INCREMENT: number = 80

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
  @Local private visibleChapterLimit: number = INITIAL_VISIBLE_CHAPTER_LIMIT
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
    this.clampVisibleChapterLimit()
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
    this.resetVisibleChapterLimit()
    this.rebuildDataSource()
  }

  private setReadFilter(readFilter: ChapterReadFilter): void {
    this.readFilter = readFilter
    this.resetVisibleChapterLimit()
    this.rebuildDataSource()
  }

  private setLanguageFilter(language: string): void {
    this.languageFilter = language
    this.resetVisibleChapterLimit()
    this.rebuildDataSource()
  }

  private setGroupFilter(group: string): void {
    this.groupFilter = group
    this.resetVisibleChapterLimit()
    this.rebuildDataSource()
  }

  private hasActiveFilters(): boolean {
    return this.sortOrder !== ChapterSortOrder.NEWEST_FIRST ||
      this.readFilter !== ChapterReadFilter.ALL ||
      this.languageFilter.length > 0 ||
      this.groupFilter.length > 0
  }

  private shouldShowLanguageFilter(): boolean {
    return this.languageFilter.length > 0 || this.languageOptions().length > 1
  }

  private shouldShowGroupFilter(): boolean {
    return this.groupFilter.length > 0 || this.groupOptions().length > 1
  }

  private resetFilters(): void {
    if (!this.hasActiveFilters()) {
      return
    }
    this.sortOrder = ChapterSortOrder.NEWEST_FIRST
    this.readFilter = ChapterReadFilter.ALL
    this.languageFilter = ''
    this.groupFilter = ''
    this.resetVisibleChapterLimit()
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
    return this.visibleChapters().map((chapter: MangaChapterItem): string => chapter.id)
  }

  private visibleChapters(): MangaChapterItem[] {
    return this.sortedChapters.slice(0, this.visibleChapterLimit)
  }

  private resetVisibleChapterLimit(): void {
    this.visibleChapterLimit = INITIAL_VISIBLE_CHAPTER_LIMIT
  }

  private clampVisibleChapterLimit(): void {
    if (this.visibleChapterLimit < INITIAL_VISIBLE_CHAPTER_LIMIT) {
      this.visibleChapterLimit = INITIAL_VISIBLE_CHAPTER_LIMIT
    }
    if (this.sortedChapters.length > 0 && this.visibleChapterLimit > this.sortedChapters.length) {
      this.visibleChapterLimit = Math.max(INITIAL_VISIBLE_CHAPTER_LIMIT, this.sortedChapters.length)
    }
  }

  private canShowMoreChapters(): boolean {
    return this.visibleChapterLimit < this.sortedChapters.length
  }

  private showMoreChapters(): void {
    if (!this.canShowMoreChapters()) {
      return
    }
    this.visibleChapterLimit = Math.min(this.sortedChapters.length, this.visibleChapterLimit + VISIBLE_CHAPTER_INCREMENT)
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
    if (chapter.pageCount !== undefined && chapter.pageCount > 0) {
      parts.push(this.formatString('chapter_list_page_count', [chapter.pageCount]))
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

  private downloadStatusLabel(status: MangaChapterDownloadStatus): ResourceStr {
    if (status === 'queued') {
      return s('downloads_status_queued')
    }
    if (status === 'downloading') {
      return s('downloads_status_downloading')
    }
    if (status === 'partial') {
      return s('downloads_status_partial')
    }
    if (status === 'failed') {
      return s('downloads_status_failed')
    }
    if (status === 'blocked') {
      return s('downloads_status_blocked')
    }
    return s('downloads_status_downloaded')
  }

  private downloadStatusColor(status: MangaChapterDownloadStatus): ResourceColor {
    if (status === 'downloaded') {
      return ThemeConstants.STATUS_SUCCESS
    }
    if (status === 'partial' || status === 'queued' || status === 'downloading') {
      return ThemeConstants.STATUS_INFO
    }
    if (status === 'blocked') {
      return ThemeConstants.STATUS_WARNING
    }
    return ThemeConstants.STATUS_DANGER
  }

  private shouldShowDownloadStatus(chapter: MangaChapterItem): boolean {
    return chapter.downloadStatus !== undefined
  }

  @Builder
  private DownloadStatusBadge(status: MangaChapterDownloadStatus) {
    Row({ space: ThemeConstants.SPACE_XS }) {
      SymbolGlyph(status === 'downloaded' ? $r('sys.symbol.checkmark') : $r('sys.symbol.arrow_down_to_line'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([this.downloadStatusColor(status)])
      Text(this.downloadStatusLabel(status))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.downloadStatusColor(status))
        .maxLines(1)
    }
    .height(ThemeConstants.FILTER_CHIP_HEIGHT)
    .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor(status === 'downloaded' ? ThemeConstants.SOFT_TINT : Color.Transparent)
    .border({ width: status === 'downloaded' ? 0 : 1, color: this.downloadStatusColor(status) })
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
      .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
      .onClick(() => {
        this.onOpenChapter(chapter.id)
      })

      if (this.shouldShowDownloadStatus(chapter) && chapter.downloadStatus !== undefined) {
        this.DownloadStatusBadge(chapter.downloadStatus)
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
            label: this.filterLabel(),
            kind: this.readFilter === ChapterReadFilter.ALL ? 'secondary' : 'primary',
            icon: $r('sys.symbol.chevron_down'),
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          })
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.FilterMenu())
          if (this.shouldShowLanguageFilter()) {
            KomaActionButton({
              label: this.languageFilterLabel(),
              kind: this.languageFilter.length === 0 ? 'secondary' : 'primary',
              icon: $r('sys.symbol.chevron_down'),
              compact: true,
              controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            })
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            .bindMenu(this.LanguageFilterMenu())
          }
          if (this.shouldShowGroupFilter()) {
            KomaActionButton({
              label: this.groupFilterLabel(),
              kind: this.groupFilter.length === 0 ? 'secondary' : 'primary',
              icon: $r('sys.symbol.chevron_down'),
              compact: true,
              controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            })
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            .bindMenu(this.GroupFilterMenu())
          }
          KomaActionButton({
            label: this.sortLabel(),
            kind: this.sortOrder === ChapterSortOrder.NEWEST_FIRST ? 'secondary' : 'primary',
            icon: $r('sys.symbol.chevron_down'),
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
          ForEach(this.visibleChapters(), (chapter: MangaChapterItem, index: number) => {
            this.ChapterRow(chapter)
            if (index < this.visibleChapters().length - 1) {
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
        if (this.canShowMoreChapters()) {
          KomaActionButton({
            label: this.formatString('chapter_list_show_more', [
              Math.min(VISIBLE_CHAPTER_INCREMENT, this.sortedChapters.length - this.visibleChapterLimit),
            ]),
            kind: 'secondary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            icon: $r('sys.symbol.chevron_down'),
            action: () => {
              this.showMoreChapters()
            },
          })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
