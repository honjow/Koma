import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaEmptyState } from './ui/KomaEmptyState'
import { KomaIconButton } from './ui/KomaIconButton'
import { KomaMenuChip } from './ui/KomaMenuChip'
import { ListDivider } from './ui/GroupedListSection'
import { ChapterSortOrder, MangaChapterDownloadStatus, MangaChapterItem } from '../model/MangaDetailModels'
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
  FAILED_ONLY = 'failed_only',
  NOT_DOWNLOADED = 'not_downloaded',
}

export enum ChapterBatchScope {
  FILTERED = 'filtered',
  SELECTED = 'selected',
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
  @Local private sectionActionsMenuShown: boolean = false
  @Local private readStateMenuChapterId: string = ''
  @Local private selectionMode: boolean = false
  @Local private selectedChapterIds: Set<string> = new Set<string>()
  @Event onOpenChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event onDownloadChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event onDownloadFilteredChapters: (chapterIds: string[], mode: ChapterBatchDownloadMode, scope: ChapterBatchScope) => void =
    (_chapterIds: string[], _mode: ChapterBatchDownloadMode, _scope: ChapterBatchScope) => {}
  @Event onMarkChapterReadState: (chapterId: string, isRead: boolean) => void =
    (_chapterId: string, _isRead: boolean) => {}
  @Event onMarkFilteredChaptersReadState: (chapterIds: string[], isRead: boolean, scope: ChapterBatchScope) => void =
    (_chapterIds: string[], _isRead: boolean, _scope: ChapterBatchScope) => {}

  @Monitor('chapters')
  private rebuildDataSource(): void {
    this.ensureMetadataFiltersAvailable()
    this.sortedChapters = this.sortedChapterList()
    this.selectedChapterIds = new Set<string>(this.selectedIdsInFilter())
  }

  private selectedIdsInFilter(): string[] {
    return Array.from(new Set<string>(this.filteredChapterIds().filter((id: string): boolean =>
      this.selectedChapterIds.has(id))))
  }

  private setChapterSelected(chapterId: string, selected: boolean): void {
    if (!this.selectionMode || !this.filteredChapterIds().includes(chapterId)) {
      return
    }
    const next = new Set<string>(this.selectedChapterIds)
    if (selected) {
      next.add(chapterId)
    } else {
      next.delete(chapterId)
    }
    this.selectedChapterIds = next
  }

  private setSelectionMode(enabled: boolean): void {
    this.selectionMode = enabled
    this.selectedChapterIds = new Set<string>()
  }

  private selectAllFilteredChapters(): void {
    if (this.selectionMode) {
      this.selectedChapterIds = new Set<string>(this.filteredChapterIds())
    }
  }

  private downloadSelectedChapters(): void {
    const ids = this.selectedIdsInFilter()
    if (this.selectionMode && ids.length > 0) {
      this.onDownloadFilteredChapters(ids, ChapterBatchDownloadMode.NOT_DOWNLOADED, ChapterBatchScope.SELECTED)
    }
  }

  private markSelectedChaptersReadState(isRead: boolean): void {
    const ids = this.selectedIdsInFilter()
    if (this.selectionMode && ids.length > 0) {
      this.onMarkFilteredChaptersReadState(ids, isRead, ChapterBatchScope.SELECTED)
    }
  }

  private sortedChapterList(): MangaChapterItem[] {
    const sorted = this.filteredChapterList()
    sorted.sort((left: MangaChapterItem, right: MangaChapterItem): number => {
      const numLeft = this.chapterNumberValue(left)
      const numRight = this.chapterNumberValue(right)
      if (numLeft >= 0 && numRight >= 0 && numLeft !== numRight) {
        return this.sortOrder === ChapterSortOrder.BY_NUMBER_ASC ? numLeft - numRight : numRight - numLeft
      }
      return this.sortOrder === ChapterSortOrder.BY_NUMBER_ASC ? 1 : -1
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

  private compareByDate(left: MangaChapterItem, right: MangaChapterItem, newestFirst: boolean): number {
    const leftDate = left.dateUpload
    const rightDate = right.dateUpload
    if (leftDate === undefined && rightDate === undefined) {
      // Keep the source's own order when it does not expose dates.
      return 0
    }
    if (leftDate === undefined) {
      return 1
    }
    if (rightDate === undefined) {
      return -1
    }
    return newestFirst ? rightDate - leftDate : leftDate - rightDate
  }

  private chapterNumberValue(chapter: MangaChapterItem): number {
    return chapter.chapterNumber === undefined ? -1 : chapter.chapterNumber
  }

  private sortLabel(): string {
    if (this.sortOrder === ChapterSortOrder.BY_NUMBER_ASC) {
      return s('chapter_list_sort_number_asc')
    }
    return s('chapter_list_sort_number_desc')
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

  private filteredChapterIds(): string[] {
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
  private ReadStateMenu(ri: RepeatItem<MangaChapterItem>) {
    Menu() {
      MenuItem({ content: s('chapter_list_menu_mark_read') })
        .onClick(() => {
          this.onMarkChapterReadState(ri.item.id, true)
        })
      MenuItem({ content: s('chapter_list_menu_mark_unread') })
        .onClick(() => {
          this.onMarkChapterReadState(ri.item.id, false)
        })
    }
  }

  @Builder
  private SectionActionsMenu() {
    Menu() {
      if (this.selectionMode) {
        MenuItem({ content: this.formatString('chapter_list_menu_download_selected', [this.selectedChapterIds.size]) })
          .enabled(this.selectedChapterIds.size > 0)
          .onClick(() => { this.downloadSelectedChapters() })
        MenuItem({ content: this.formatString('chapter_list_menu_mark_selected_read', [this.selectedChapterIds.size]) })
          .enabled(this.selectedChapterIds.size > 0)
          .onClick(() => { this.markSelectedChaptersReadState(true) })
        MenuItem({ content: this.formatString('chapter_list_menu_mark_selected_unread', [this.selectedChapterIds.size]) })
          .enabled(this.selectedChapterIds.size > 0)
          .onClick(() => { this.markSelectedChaptersReadState(false) })
        MenuItem({ content: s('chapter_list_menu_select_all_filtered') })
          .enabled(this.sortedChapters.length > 0)
          .onClick(() => { this.selectAllFilteredChapters() })
        MenuItem({ content: s('chapter_list_menu_exit_selection') })
          .onClick(() => { this.setSelectionMode(false) })
      } else {
        MenuItem({ content: s('chapter_list_menu_mark_filtered_read') })
          .onClick(() => {
            this.onMarkFilteredChaptersReadState(this.filteredChapterIds(), true, ChapterBatchScope.FILTERED)
          })
        MenuItem({ content: s('chapter_list_menu_mark_filtered_unread') })
          .onClick(() => {
            this.onMarkFilteredChaptersReadState(this.filteredChapterIds(), false, ChapterBatchScope.FILTERED)
          })
        MenuItem({ content: s('chapter_list_menu_download_filtered') })
          .onClick(() => {
            this.onDownloadFilteredChapters(this.filteredChapterIds(), ChapterBatchDownloadMode.NOT_DOWNLOADED, ChapterBatchScope.FILTERED)
          })
        MenuItem({ content: s('chapter_list_menu_retry_failed') })
          .onClick(() => {
            this.onDownloadFilteredChapters(this.filteredChapterIds(), ChapterBatchDownloadMode.FAILED_ONLY, ChapterBatchScope.FILTERED)
          })
        MenuItem({ content: s('chapter_list_menu_download_incomplete') })
          .onClick(() => {
            this.onDownloadFilteredChapters(this.filteredChapterIds(), ChapterBatchDownloadMode.NOT_DOWNLOADED, ChapterBatchScope.FILTERED)
          })
        MenuItem({ content: s('chapter_list_menu_enter_selection') })
          .enabled(this.sortedChapters.length > 0)
          .onClick(() => { this.setSelectionMode(true) })
      }
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
  private DownloadStatusBadge(ri: RepeatItem<MangaChapterItem>) {
    if (ri.item.downloadStatus !== undefined) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        SymbolGlyph(ri.item.downloadStatus === 'downloaded' ? $r('sys.symbol.checkmark') : $r('sys.symbol.arrow_down_to_line'))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontColor([this.downloadStatusColor(ri.item.downloadStatus!)])
        Text(this.downloadStatusLabel(ri.item.downloadStatus!))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.downloadStatusColor(ri.item.downloadStatus!))
          .maxLines(1)
      }
      .height(ThemeConstants.FILTER_CHIP_HEIGHT)
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ri.item.downloadStatus === 'downloaded' ? ThemeConstants.SOFT_TINT : Color.Transparent)
      .border({ width: ri.item.downloadStatus === 'downloaded' ? 0 : 1,
        color: this.downloadStatusColor(ri.item.downloadStatus!) })
    }
  }

  @Builder
  private ChapterRow(ri: RepeatItem<MangaChapterItem>) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.chapterTitle(ri.item))
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontColor(ri.item.isRead ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
          .fontWeight(ri.item.isRead ? FontWeight.Regular : FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.chapterSubtitle(ri.item).length > 0) {
          Text(this.chapterSubtitle(ri.item))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.shouldShowDownloadStatus(ri.item)) {
        this.DownloadStatusBadge(ri)
      } else {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(ri.item.isDownloaded ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.arrow_down_to_line'))
            .fontSize(18)
            .fontColor([ri.item.isDownloaded ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_tertiary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (!ri.item.isDownloaded) {
            this.onDownloadChapter(ri.item.id)
          }
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM, left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
    .onClick(() => {
      this.onOpenChapter(ri.item.id)
    })
    .bindContextMenu(this.ReadStateMenu(ri), ResponseType.LongPress)
  }

  @Builder
  private SelectedChapterRow(ri: RepeatItem<MangaChapterItem>) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Checkbox({ name: ri.item.id })
        .select(this.selectedChapterIds.has(ri.item.id))
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .unselectedColor(ThemeConstants.TEXT_SECONDARY)
        .width(24)
        .height(24)
        .margin(0)
        .responseRegion({ x: -6, y: -6, width: 36, height: 36 })
        .accessibilityText(this.chapterTitle(ri.item))
        .onChange((selected: boolean) => {
          this.setChapterSelected(ri.item.id, selected)
        })

      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.chapterTitle(ri.item))
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontColor(ri.item.isRead ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
          .fontWeight(ri.item.isRead ? FontWeight.Regular : FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.chapterSubtitle(ri.item).length > 0) {
          Text(this.chapterSubtitle(ri.item))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.setChapterSelected(ri.item.id, !this.selectedChapterIds.has(ri.item.id))
      })
      .bindContextMenu(this.SectionActionsMenu, ResponseType.LongPress)

      if (this.shouldShowDownloadStatus(ri.item)) {
        this.DownloadStatusBadge(ri)
      } else {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(ri.item.isDownloaded ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.arrow_down_to_line'))
            .fontSize(18)
            .fontColor([ri.item.isDownloaded ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_tertiary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .enabled(false)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM, left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
  }

  @Builder
  private SectionHeader() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.selectionMode ? this.formatString('library_selected_count', [this.selectedChapterIds.size])
          : this.formatString('chapter_list_title', [this.sortedChapters.length, this.chapters.length]))
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)

        Column() {
          KomaIconButton({
            icon: $r('sys.symbol.ellipsis_circle'),
            kind: 'secondary',
            controlSize: ThemeConstants.TOUCH_TARGET_SM,
            iconSize: ThemeConstants.FONT_SIZE_H3,
            action: () => {
              this.sectionActionsMenuShown = true
            },
          })
        }
        .bindMenu(this.sectionActionsMenuShown, this.SectionActionsMenu, {
          placement: Placement.BottomRight,
          onDisappear: () => {
            this.sectionActionsMenuShown = false
          },
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Flex({ wrap: FlexWrap.Wrap }) {
        Row() {
          KomaMenuChip({ label: this.filterLabel(), active: this.readFilter !== ChapterReadFilter.ALL })
        }
        .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .bindMenu(this.FilterMenu())
        if (this.shouldShowLanguageFilter()) {
          Row() {
            KomaMenuChip({ label: this.languageFilterLabel(), active: this.languageFilter.length > 0 })
          }
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.LanguageFilterMenu())
        }
        if (this.shouldShowGroupFilter()) {
          Row() {
            KomaMenuChip({ label: this.groupFilterLabel(), active: this.groupFilter.length > 0 })
          }
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.GroupFilterMenu())
        }
        Row() {
          KomaMenuChip({ label: this.sortLabel(), active: this.sortOrder !== ChapterSortOrder.NEWEST_FIRST })
        }
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
    .padding({ bottom: ThemeConstants.SPACE_MD })
  }

  build() {
    ListItemGroup({ header: this.SectionHeader(), space: 0 }) {
      if (this.sortedChapters.length === 0) {
        ListItem() {
          this.EmptyChapters()
        }
      } else {
        Repeat<MangaChapterItem>(this.sortedChapters)
          .each((ri: RepeatItem<MangaChapterItem>) => {
            ListItem() {
              Column() {
                if (this.selectionMode) {
                  this.SelectedChapterRow(ri)
                } else {
                  this.ChapterRow(ri)
                }
                if (ri.index < this.sortedChapters.length - 1) {
                  ListDivider()
                }
              }
              .width('100%')
              .padding({
                left: ThemeConstants.LIST_SECTION_INSET,
                right: ThemeConstants.LIST_SECTION_INSET,
                top: ri.index === 0 ? ThemeConstants.LIST_SECTION_INSET : 0,
                bottom: ri.index === this.sortedChapters.length - 1 ? ThemeConstants.LIST_SECTION_INSET : 0,
              })
              .backgroundColor(ThemeConstants.CARD)
              .borderRadius({
                topLeft: ri.index === 0 ? ThemeConstants.RADIUS_CARD : 0,
                topRight: ri.index === 0 ? ThemeConstants.RADIUS_CARD : 0,
                bottomLeft: ri.index === this.sortedChapters.length - 1 ? ThemeConstants.RADIUS_CARD : 0,
                bottomRight: ri.index === this.sortedChapters.length - 1 ? ThemeConstants.RADIUS_CARD : 0,
              })
              .clip(true)
            }
          })
          .key((chapter: MangaChapterItem): string => chapter.id)
          .virtualScroll()
      }
    }
    .width('100%')
  }
}
