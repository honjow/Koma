import { komaContextMenuOptions, komaMenuOptions } from '../theme/KomaPopupOptions'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaEmptyState } from './ui/KomaEmptyState'
import { KomaIconButton } from './ui/KomaIconButton'
import { KomaMenuChip } from './ui/KomaMenuChip'
import { ConciseListRow } from './ui/ConciseListRow'
import { ChapterSortBasis, ChapterSortDirection, MangaChapterDownloadStatus, MangaChapterItem } from '../model/MangaDetailModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ChapterListPreferencesStore, ChapterReadFilter } from '../model/ChapterListPreferencesStore'
export { ChapterReadFilter } from '../model/ChapterListPreferencesStore'

function s(name: string): string {
  return AppStrings.get(name)
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
  @Param comicId: string = ''
  @Param archiveBusy: boolean = false
  @Param chapters: MangaChapterItem[] = []
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sortBasis: ChapterSortBasis = ChapterSortBasis.SOURCE_ORDER
  @Local private sortDirection: ChapterSortDirection = ChapterSortDirection.FORWARD
  @Local private readFilter: ChapterReadFilter = ChapterReadFilter.ALL
  @Local private languageFilter: string = ''
  @Local private groupFilter: string = ''
  @Local private bookmarkFilter: 'all' | 'bookmarked' | 'unbookmarked' = 'all'
  @Local private sectionActionsMenuShown: boolean = false
  @Local private readStateMenuChapterId: string = ''
  @Local private selectionMode: boolean = false
  @Local private selectedChapterIds: Set<string> = new Set<string>()
  @Event onOpenChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event onDownloadChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event onExportChapter: (chapterId: string, share: boolean) => void = (_chapterId: string, _share: boolean) => {}
  @Event onBookmarkChapter: (chapterId: string, bookmarked: boolean) => void = (_chapterId: string, _bookmarked: boolean) => {}
  @Event onDownloadFilteredChapters: (chapterIds: string[], mode: ChapterBatchDownloadMode, scope: ChapterBatchScope) => void =
    (_chapterIds: string[], _mode: ChapterBatchDownloadMode, _scope: ChapterBatchScope) => {}
  @Event onMarkChapterReadState: (chapterId: string, isRead: boolean) => void =
    (_chapterId: string, _isRead: boolean) => {}
  @Event onMarkFilteredChaptersReadState: (chapterIds: string[], isRead: boolean, scope: ChapterBatchScope) => void =
    (_chapterIds: string[], _isRead: boolean, _scope: ChapterBatchScope) => {}

  @Computed
  private get sortedChapters(): MangaChapterItem[] {
    return this.sortedChapterList()
  }

  @Monitor('chapters')
  private rebuildDataSource(): void {
    this.ensureMetadataFiltersAvailable()
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
    if (this.sortBasis === ChapterSortBasis.CHAPTER_NUMBER) {
      // Source position and optional chapter numbers are distinct inputs.
      // Equal/missing numbers retain source order in this fixed baseline.
      sorted.sort((left: MangaChapterItem, right: MangaChapterItem): number =>
        this.chapterNumberValue(left) - this.chapterNumberValue(right))
    }
    // Direction reverses the entire result, including all equal/missing values.
    // Neither the source catalog nor chapter IDs/reading state are mutated.
    return this.sortDirection === ChapterSortDirection.REVERSE ? sorted.reverse() : sorted
  }

  private filteredChapterList(): MangaChapterItem[] {
    let filtered = this.chapters.slice()
    if (this.bookmarkFilter !== 'all') {
      filtered = filtered.filter((chapter: MangaChapterItem): boolean =>
        (chapter.isBookmarked === true) === (this.bookmarkFilter === 'bookmarked'))
    }
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

  private chapterNumberValue(chapter: MangaChapterItem): number {
    return typeof chapter.chapterNumber === 'number' && Number.isFinite(chapter.chapterNumber) && chapter.chapterNumber >= 0
      ? chapter.chapterNumber : -1
  }

  private sortLabel(): string {
    const basis = s(this.sortBasis === ChapterSortBasis.SOURCE_ORDER
      ? 'chapter_list_sort_source_order' : 'chapter_list_sort_number')
    const direction = s(this.sortDirection === ChapterSortDirection.FORWARD
      ? 'chapter_list_sort_forward' : 'chapter_list_sort_reverse')
    return basis + ' · ' + direction
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

  private setSortBasis(basis: ChapterSortBasis): void {
    if (this.sortBasis === basis) return
    this.sortBasis = basis
    this.savePreferences()
  }

  private setSortDirection(direction: ChapterSortDirection): void {
    if (this.sortDirection === direction) return
    this.sortDirection = direction
    this.savePreferences()
  }

  private setReadFilter(readFilter: ChapterReadFilter): void {
    this.readFilter = readFilter
    this.rebuildDataSource()
    this.savePreferences()
  }

  private setLanguageFilter(language: string): void {
    this.languageFilter = language
    this.rebuildDataSource()
    this.savePreferences()
  }

  private setGroupFilter(group: string): void {
    this.groupFilter = group
    this.rebuildDataSource()
    this.savePreferences()
  }

  private hasActiveFilters(): boolean {
    return this.sortBasis !== ChapterSortBasis.SOURCE_ORDER ||
      this.sortDirection !== ChapterSortDirection.FORWARD ||
      this.readFilter !== ChapterReadFilter.ALL ||
      this.languageFilter.length > 0 ||
      this.groupFilter.length > 0 || this.bookmarkFilter !== 'all'
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
    this.sortBasis = ChapterSortBasis.SOURCE_ORDER
    this.sortDirection = ChapterSortDirection.FORWARD
    this.readFilter = ChapterReadFilter.ALL
    this.languageFilter = ''
    this.groupFilter = ''
    this.bookmarkFilter = 'all'
    this.rebuildDataSource()
    this.savePreferences()
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
    this.restorePreferences()
    this.rebuildDataSource()
  }

  @Monitor('comicId')
  private restorePreferences(): void {
    try {
      const value = new ChapterListPreferencesStore(getContext(this) as common.UIAbilityContext).load(this.comicId)
      this.sortBasis = value.sortBasis
      this.sortDirection = value.sortDirection
      this.readFilter = value.readFilter
      this.languageFilter = value.languageFilter
      this.groupFilter = value.groupFilter
      this.bookmarkFilter = value.bookmarkFilter
    } catch (error) { DiagnosticLogger.exception('chapters', 'preferences_load_failed', error as Error) }
    this.setSelectionMode(false)
  }

  private savePreferences(): void {
    void new ChapterListPreferencesStore(getContext(this) as common.UIAbilityContext).save(this.comicId, {
      sortBasis: this.sortBasis, sortDirection: this.sortDirection, readFilter: this.readFilter,
      languageFilter: this.languageFilter, groupFilter: this.groupFilter,
      bookmarkFilter: this.bookmarkFilter,
    }).catch((error: Error): void => { DiagnosticLogger.exception('chapters', 'preferences_save_failed', error) })
  }

  @Builder
  private SortGroupHeader(title: string) {
    Text(title)
      .fontSize($r('sys.float.Body_S'))
      .fontWeight(FontWeight.Regular)
      .fontColor($r('sys.color.font_secondary'))
  }

  @Builder
  private SortMenu() {
    Menu() {
      MenuItemGroup({ header: () => { this.SortGroupHeader(s('chapter_list_sort_by')) } }) {
        MenuItem({ content: s('chapter_list_sort_source_order') })
          .selected(this.sortBasis === ChapterSortBasis.SOURCE_ORDER)
          .selectIcon(true)
          .enabled(this.sortBasis !== ChapterSortBasis.SOURCE_ORDER)
          .onClick(() => { this.setSortBasis(ChapterSortBasis.SOURCE_ORDER) })
        MenuItem({ content: s('chapter_list_sort_number') })
          .selected(this.sortBasis === ChapterSortBasis.CHAPTER_NUMBER)
          .selectIcon(true)
          .enabled(this.sortBasis !== ChapterSortBasis.CHAPTER_NUMBER)
          .onClick(() => { this.setSortBasis(ChapterSortBasis.CHAPTER_NUMBER) })
      }
      MenuItemGroup({ header: () => { this.SortGroupHeader(s('chapter_list_sort_direction')) } }) {
        MenuItem({ content: s('chapter_list_sort_forward') })
          .selected(this.sortDirection === ChapterSortDirection.FORWARD)
          .selectIcon(true)
          .enabled(this.sortDirection !== ChapterSortDirection.FORWARD)
          .onClick(() => { this.setSortDirection(ChapterSortDirection.FORWARD) })
        MenuItem({ content: s('chapter_list_sort_reverse') })
          .selected(this.sortDirection === ChapterSortDirection.REVERSE)
          .selectIcon(true)
          .enabled(this.sortDirection !== ChapterSortDirection.REVERSE)
          .onClick(() => { this.setSortDirection(ChapterSortDirection.REVERSE) })
      }
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
  private BookmarkFilterMenu() {
    Menu() {
      MenuItem({ content: s('common_all') }).onClick(() => { this.setBookmarkFilter('all') })
      MenuItem({ content: s('chapter_filter_bookmarked') }).onClick(() => { this.setBookmarkFilter('bookmarked') })
      MenuItem({ content: s('chapter_filter_unbookmarked') }).onClick(() => { this.setBookmarkFilter('unbookmarked') })
    }
  }

  private setBookmarkFilter(value: 'all' | 'bookmarked' | 'unbookmarked'): void {
    this.bookmarkFilter = value
    this.rebuildDataSource()
    this.savePreferences()
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
      MenuItem({ content: s(ri.item.isBookmarked ? 'chapter_bookmark_remove' : 'chapter_bookmark_add') })
        .onClick(() => { this.onBookmarkChapter(ri.item.id, ri.item.isBookmarked !== true) })
      MenuItem({ content: s('chapter_list_menu_mark_read') })
        .onClick(() => {
          this.onMarkChapterReadState(ri.item.id, true)
        })
      MenuItem({ content: s('chapter_list_menu_mark_unread') })
        .onClick(() => {
          this.onMarkChapterReadState(ri.item.id, false)
        })
      if (ri.item.isDownloaded && (ri.item.downloadStatus === undefined || ri.item.downloadStatus === 'downloaded')) {
        MenuItem({ content: s('chapter_export_cbz') }).enabled(!this.archiveBusy)
          .onClick(() => { this.onExportChapter(ri.item.id, false) })
        MenuItem({ content: s('chapter_share_cbz') }).enabled(!this.archiveBusy)
          .onClick(() => { this.onExportChapter(ri.item.id, true) })
      }
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
  private ChapterDownloadAction(ri: RepeatItem<MangaChapterItem>) {
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

  @Builder
  private ChapterText(ri: RepeatItem<MangaChapterItem>) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        if (ri.item.isBookmarked) {
          SymbolGlyph($r('sys.symbol.bookmark_fill'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
        }
        Text(this.chapterTitle(ri.item))
        .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
        .fontColor(ri.item.isRead ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
        .fontWeight(ri.item.isRead ? FontWeight.Regular : FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      }
      .width('100%')
      if (this.chapterSubtitle(ri.item).length > 0) {
        Text(this.chapterSubtitle(ri.item))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // HDS measures the text slot independently of a custom suffix. Preserve
    // the original row's 36vp download-button minimum without fixing height.
    .constraintSize({ minHeight: this.shouldShowDownloadStatus(ri.item) ? 0 : 36 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ChapterRow(ri: RepeatItem<MangaChapterItem>) {
    // Use the same inset HDS press surface as other grouped rows. The outer
    // ListItem/card never owns feedback; its 4vp margin stays unchanged.
    ConciseListRow({
      title: this.chapterTitle(ri.item),
      subtitle: this.chapterSubtitle(ri.item),
      subtitleMaxLines: 1,
      showChevron: false,
      primaryColor: ri.item.isRead ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'),
      textBuilderParam: () => { this.ChapterText(ri) },
      suffixPaddingRight: ThemeConstants.SPACE_SM,
      suffixBuilderParam: () => { this.ChapterDownloadAction(ri) },
      action: () => { this.onOpenChapter(ri.item.id) },
    })
    .bindContextMenu(this.ReadStateMenu(ri), ResponseType.LongPress, komaContextMenuOptions())
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
      .bindContextMenu(this.SectionActionsMenu, ResponseType.LongPress, komaContextMenuOptions())

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
        .bindMenu(this.sectionActionsMenuShown, this.SectionActionsMenu, komaMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: () => {
            this.sectionActionsMenuShown = false
          },
        }))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Flex({ wrap: FlexWrap.Wrap }) {
        Row() {
          KomaMenuChip({ label: this.filterLabel(), active: this.readFilter !== ChapterReadFilter.ALL })
        }
        .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .bindMenu(this.FilterMenu(), komaMenuOptions())
        Row() {
          KomaMenuChip({ label: s(this.bookmarkFilter === 'all' ? 'chapter_bookmarks' :
            this.bookmarkFilter === 'bookmarked' ? 'chapter_filter_bookmarked' : 'chapter_filter_unbookmarked'),
            active: this.bookmarkFilter !== 'all' })
        }
        .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .bindMenu(this.BookmarkFilterMenu(), komaMenuOptions())
        if (this.shouldShowLanguageFilter()) {
          Row() {
            KomaMenuChip({ label: this.languageFilterLabel(), active: this.languageFilter.length > 0 })
          }
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.LanguageFilterMenu(), komaMenuOptions())
        }
        if (this.shouldShowGroupFilter()) {
          Row() {
            KomaMenuChip({ label: this.groupFilterLabel(), active: this.groupFilter.length > 0 })
          }
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
          .bindMenu(this.GroupFilterMenu(), komaMenuOptions())
        }
        Row() {
          KomaMenuChip({ label: this.sortLabel(), active: this.sortBasis !== ChapterSortBasis.SOURCE_ORDER ||
            this.sortDirection !== ChapterSortDirection.FORWARD })
        }
        .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .bindMenu(this.SortMenu(), komaMenuOptions())
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
              }
              .width('100%')
              .padding({
                left: ThemeConstants.LIST_SECTION_INSET,
                right: ThemeConstants.LIST_SECTION_INSET,
                top: ri.index === 0 ? ThemeConstants.LIST_SECTION_INSET : 0,
                // The native group reserves the separator's own stroke height;
                // a second per-cell spacer would increase every row.
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
    // The native group owns separators across virtualized, independently
    // clipped cells. Chapter/open/download/selection handlers stay independent.
    .divider({ strokeWidth: 0.5, color: ThemeConstants.DIVIDER,
      startMargin: ThemeConstants.LIST_SECTION_INSET + ThemeConstants.SPACE_LG,
      endMargin: ThemeConstants.LIST_SECTION_INSET })
  }
}
