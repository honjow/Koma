import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode, getReaderModeLabel } from '../model/ReaderSessionStore'
import {
  ReaderBackgroundMode,
  ReaderColumnMode,
  ReaderImageScalingQuality,
  ReaderPageGapMode,
  ReaderPageMode,
  ReaderPreferences,
  ReaderSpreadLayoutMode,
  ReaderTapZoneInvert,
  ReaderTapZonePreset,
  ReaderVolumeKeyBehavior,
  ReaderWideImageMode,
  DEFAULT_READER_PREFERENCES,
  getReaderBackgroundModeLabel,
  getReaderPageGapModeLabel,
  getReaderTapZoneInvertLabel,
  getReaderTapZonePresetLabel,
  getReaderVolumeKeyBehaviorLabel,
  getReaderWideImageModeLabel,
  getReadingDirectionLabel,
} from '../model/ReaderPreferencesStore'
import { ReadingDirection } from '../model/ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from './ui/GroupedListSection'

function s(key: string): string {
  return AppStrings.get(key)
}

export interface ReaderChromePreferencesChange {
  preferences: ReaderPreferences
}

/**
 * Reader chrome owns only presentation and navigation controls. Page gestures
 * are intrinsic reader behavior: there are no switches for tap/swipe/zoom or
 * for the transient tap-zone preview.
 */
@ComponentV2
export struct ReaderChrome {
  @Param visible: boolean = false
  /** One physical bar per component, matching NextE's sibling bar layers. */
  @Param placement: 'top' | 'bottom' = 'top'
  @Param viewportHeight: number = 0
  @Param pageIndex: number = 0
  @Param pageTotal: number = 0
  @Param title: string = ''
  @Param chapterIndex: number = 0
  @Param chapterTotal: number = 0
  @Param chapterTitles: string[] = []
  @Param readerMode: ReaderMode = ReaderMode.SINGLE_PAGE
  @Param preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Param topInset: number = 0
  @Param bottomInset: number = 0
  @Param canGoPrevious: boolean = false
  @Param canGoNext: boolean = false
  @Param canGoPreviousChapter: boolean = false
  @Param canGoNextChapter: boolean = false
  @Param pageFailed: boolean = false
  @Param zoomScale: number = 1
  @Param autoPageActive: boolean = false
  @Param canTurnOnePageInDoublePage: boolean = false
  @Param thumbStripVisible: boolean = false
  @Param pageImageWidth: number = 0
  @Param pageImageHeight: number = 0
  @Param pageImageSourceLabel: string = ''
  @Event onVisibleChange: (visible: boolean) => void = (_visible: boolean) => {}
  @Event onPageChange: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onSeekPage: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onPreviousChapter: () => void = () => {}
  @Event onNextChapter: () => void = () => {}
  @Event onOpenChapter: (chapterIndex: number) => void = (_chapterIndex: number) => {}
  @Event onModeChange: (mode: ReaderMode) => void = (_mode: ReaderMode) => {}
  @Event onPreferencesChange: (change: ReaderChromePreferencesChange) => void = (_change: ReaderChromePreferencesChange) => {}
  @Event onCloseReader: () => void = () => {}
  @Event onOpenMangaDetail: () => void = () => {}
  @Event onResetZoom: () => void = () => {}
  @Event onReloadPage: () => void = () => {}
  @Event onToggleAutoPage: () => void = () => {}
  @Event onTurnOnePageInDoublePage: () => void = () => {}
  @Event onToggleThumbStrip: () => void = () => {}
  @Event onSaveImage: () => void = () => {}
  @Event onShareImage: () => void = () => {}
  @BuilderParam thumbnailStrip?: () => void

  @Local private settingsShown: boolean = false
  @Local private moreShown: boolean = false
  @Local private modeShown: boolean = false
  @Local private imageInfoShown: boolean = false
  @Local private chapterPickerShown: boolean = false
  @Local private chapterPickerTarget: number = -1
  private chapterPickerScroller: Scroller = new Scroller()

  @Builder
  private ChapterSelectedCheckmark() {
    SymbolGlyph($r('sys.symbol.checkmark'))
      .fontSize(ThemeConstants.FONT_SIZE_H3)
      .fontWeight(FontWeight.Medium)
      .fontColor([ThemeConstants.BRAND_PRIMARY])
  }

  @Monitor('chapterPickerShown')
  private onChapterPickerVisibilityChanged(): void {
    if (this.chapterPickerShown && this.chapterIndex >= 0) {
      setTimeout(() => {
        this.chapterPickerScroller.scrollToIndex(Math.max(0, this.chapterIndex), true, ScrollAlign.CENTER)
      }, 120)
    }
  }

  private pageText(): string {
    const total = Math.max(this.pageTotal, 0)
    return total <= 0 ? '0 / 0' : `${Math.min(Math.max(this.pageIndex + 1, 1), total)} / ${total}`
  }

  private barHeight(): number {
    return this.placement === 'top'
      ? this.topInset + 56
      : this.bottomInset + 104 + (this.thumbStripVisible ? 156 : 0)
  }

  private barOffsetY(): number {
    return this.placement === 'top' ? 0 : Math.max(this.viewportHeight - this.barHeight(), 0)
  }

  private chapterText(): string {
    return this.chapterTotal <= 0 ? '' : `${s('reader_control_chapter')} ${this.chapterIndex + 1} / ${this.chapterTotal}`
  }

  private chapterTitleText(): string {
    const rawTitle = this.chapterIndex >= 0 && this.chapterIndex < this.chapterTitles.length
      ? this.chapterTitles[this.chapterIndex]
      : ''
    const title = rawTitle.trim().replace(/\s+/g, ' ')
    return title.length > 0 ? title : this.chapterText()
  }

  private chapterPickerTitle(index: number): string {
    const title = index >= 0 && index < this.chapterTitles.length ? this.chapterTitles[index] : ''
    return title.length > 0 ? title : `${s('reader_control_chapter')} ${index + 1}`
  }

  private chapterPickerIndexes(): number[] {
    const count = Math.max(this.chapterTotal, this.chapterTitles.length)
    const indexes: number[] = []
    for (let index = 0; index < count; index += 1) {
      indexes.push(index)
    }
    return indexes
  }

  private selectChapterFromPicker(index: number): void {
    if (index < 0 || index >= this.chapterTotal) {
      return
    }
    this.chapterPickerTarget = index
    this.chapterPickerShown = false
  }

  private finishChapterPickerDismissal(): void {
    const target = this.chapterPickerTarget
    this.chapterPickerTarget = -1
    this.chapterPickerShown = false
    if (target >= 0 && target < this.chapterTotal) {
      this.onOpenChapter(target)
    }
  }

  private openImageInfo(): void {
    // The detail surface is hosted by the dedicated back-button anchor, not
    // the menu trigger.  It can therefore be opened in the same event without
    // competing with the Menu overlay for ownership.
    this.moreShown = false
    this.imageInfoShown = true
  }

  private imageDimensionsText(): string {
    if (this.pageImageWidth <= 0 || this.pageImageHeight <= 0) {
      return s('reader_image_info_unavailable')
    }
    return `${this.pageImageWidth} × ${this.pageImageHeight}`
  }

  private update(next: ReaderPreferences): void {
    this.onPreferencesChange({ preferences: next })
  }

  private copyPreferences(): ReaderPreferences {
    const p = this.preferences
    return {
      pageMode: p.pageMode,
      readingDirection: p.readingDirection,
      themeMode: p.themeMode,
      backgroundMode: p.backgroundMode,
      showProgressControls: true,
      keepScreenAwake: p.keepScreenAwake,
      fullscreen: p.fullscreen,
      imageFitMode: p.imageFitMode,
      imageScalingQuality: p.imageScalingQuality,
      showPageNumber: p.showPageNumber,
      pageTurnAnimation: p.pageTurnAnimation,
      autoPageSeconds: p.autoPageSeconds,
      preloadPages: p.preloadPages,
      spreadLayoutMode: p.spreadLayoutMode,
      columnMode: p.columnMode,
      tapZonePreset: p.tapZonePreset,
      tapZoneInvert: p.tapZoneInvert,
      pageGapMode: p.pageGapMode,
      trimPageMarginsEnabled: p.trimPageMarginsEnabled,
      wideImageMode: p.wideImageMode,
      volumeKeyNavigationEnabled: p.volumeKeyNavigationEnabled,
      volumeKeyBehavior: p.volumeKeyBehavior,
    }
  }

  private setPageMode(mode: ReaderPageMode): void {
    const next = this.copyPreferences()
    next.pageMode = mode
    this.update(next)
  }

  private setDirection(direction: ReadingDirection): void {
    const next = this.copyPreferences()
    next.readingDirection = direction
    this.update(next)
  }

  private setBackground(mode: ReaderBackgroundMode): void {
    const next = this.copyPreferences()
    next.backgroundMode = mode
    this.update(next)
  }

  private setImageScalingQuality(mode: ReaderImageScalingQuality): void {
    const next = this.copyPreferences()
    next.imageScalingQuality = mode
    this.update(next)
  }

  private setTapZone(mode: ReaderTapZonePreset): void {
    const next = this.copyPreferences()
    next.tapZonePreset = mode
    this.update(next)
    this.revealTapZonePreview()
  }

  private setTapInvert(mode: ReaderTapZoneInvert): void {
    const next = this.copyPreferences()
    next.tapZoneInvert = mode
    this.update(next)
    this.revealTapZonePreview()
  }

  private setSpreadLayout(mode: ReaderSpreadLayoutMode): void {
    const next = this.copyPreferences()
    next.spreadLayoutMode = mode
    this.update(next)
  }

  private setColumnMode(mode: ReaderColumnMode): void {
    const next = this.copyPreferences()
    next.columnMode = mode
    this.update(next)
  }

  private setGap(mode: ReaderPageGapMode): void {
    const next = this.copyPreferences()
    next.pageGapMode = mode
    this.update(next)
  }

  private setWide(mode: ReaderWideImageMode): void {
    const next = this.copyPreferences()
    next.wideImageMode = mode
    this.update(next)
  }

  private setAutoPageSeconds(seconds: number): void {
    const next = this.copyPreferences()
    next.autoPageSeconds = Math.max(1, Math.min(60, Math.round(seconds)))
    this.update(next)
  }

  private setPreloadPages(pages: number): void {
    const next = this.copyPreferences()
    next.preloadPages = Math.max(0, Math.min(5, Math.round(pages)))
    this.update(next)
  }

  private setVolumeKeyBehavior(behavior: ReaderVolumeKeyBehavior): void {
    const next = this.copyPreferences()
    next.volumeKeyBehavior = behavior
    this.update(next)
  }

  private scalingQualityLabel(): string {
    if (this.preferences.imageScalingQuality === 'low') {
      return s('reader_image_scaling_quality_low')
    }
    if (this.preferences.imageScalingQuality === 'high') {
      return s('reader_image_scaling_quality_high')
    }
    return s('reader_image_scaling_quality_medium')
  }

  private setToggle(key: string, value: boolean): void {
    const next = this.copyPreferences()
    if (key === 'fullscreen') next.fullscreen = value
    if (key === 'page-number') next.showPageNumber = value
    if (key === 'page-animation') next.pageTurnAnimation = value
    if (key === 'awake') next.keepScreenAwake = value
    if (key === 'volume') next.volumeKeyNavigationEnabled = value
    this.update(next)
  }

  private closeSettings(): void {
    this.settingsShown = false
  }

  private isWebtoonLayout(): boolean {
    return this.readerMode === ReaderMode.CONTINUOUS_SCROLL ||
      (this.preferences.readingDirection === ReadingDirection.WEBTOON && this.readerMode !== ReaderMode.VERTICAL_PAGE)
  }

  private revealTapZonePreview(): void {
    // Match the reference interaction: applying a zone immediately returns to
    // the reader so the full-screen, one-shot preview is actually visible.
    this.closeSettings()
    this.onVisibleChange(false)
  }

  @Builder
  private PageModeMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('single_page') }) })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('double_page') }) })
      MenuItem({ content: getReaderModeLabel(ReaderMode.VERTICAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.VERTICAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('vertical_page') }) })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('continuous_scroll') }) })
    }
  }

  @Builder
  private DirectionMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.LEFT_TO_RIGHT), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.LEFT_TO_RIGHT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setDirection(ReadingDirection.LEFT_TO_RIGHT) }) })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.RIGHT_TO_LEFT), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setDirection(ReadingDirection.RIGHT_TO_LEFT) }) })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.WEBTOON), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.WEBTOON ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setDirection(ReadingDirection.WEBTOON) }) })
    }
  }

  @Builder
  private BackgroundMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderBackgroundModeLabel('black'), symbolEndIcon: this.preferences.backgroundMode === 'black' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setBackground('black') }) })
      MenuItem({ content: getReaderBackgroundModeLabel('gray'), symbolEndIcon: this.preferences.backgroundMode === 'gray' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setBackground('gray') }) })
      MenuItem({ content: getReaderBackgroundModeLabel('white'), symbolEndIcon: this.preferences.backgroundMode === 'white' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setBackground('white') }) })
      MenuItem({ content: getReaderBackgroundModeLabel('auto'), symbolEndIcon: this.preferences.backgroundMode === 'auto' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setBackground('auto') }) })
    }
  }

  @Builder
  private TapZoneMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderTapZonePresetLabel('right_left'), symbolEndIcon: this.preferences.tapZonePreset === 'right_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapZone('right_left') }) })
      MenuItem({ content: getReaderTapZonePresetLabel('l_shaped'), symbolEndIcon: this.preferences.tapZonePreset === 'l_shaped' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapZone('l_shaped') }) })
      MenuItem({ content: getReaderTapZonePresetLabel('kindle'), symbolEndIcon: this.preferences.tapZonePreset === 'kindle' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapZone('kindle') }) })
      MenuItem({ content: getReaderTapZonePresetLabel('edge'), symbolEndIcon: this.preferences.tapZonePreset === 'edge' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapZone('edge') }) })
    }
  }

  @Builder
  private TapInvertMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderTapZoneInvertLabel('none'), symbolEndIcon: this.preferences.tapZoneInvert === 'none' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapInvert('none') }) })
      MenuItem({ content: getReaderTapZoneInvertLabel('horizontal'), symbolEndIcon: this.preferences.tapZoneInvert === 'horizontal' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapInvert('horizontal') }) })
      MenuItem({ content: getReaderTapZoneInvertLabel('vertical'), symbolEndIcon: this.preferences.tapZoneInvert === 'vertical' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapInvert('vertical') }) })
      MenuItem({ content: getReaderTapZoneInvertLabel('both'), symbolEndIcon: this.preferences.tapZoneInvert === 'both' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setTapInvert('both') }) })
    }
  }

  @Builder
  private SpreadLayoutMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('reader_spread_layout_joined'), symbolEndIcon: this.preferences.spreadLayoutMode === 'joined' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setSpreadLayout('joined') }) })
      MenuItem({ content: s('reader_spread_layout_split'), symbolEndIcon: this.preferences.spreadLayoutMode === 'split' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setSpreadLayout('split') }) })
    }
  }

  @Builder
  private ColumnModeMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('reader_column_mode_odd_left'), symbolEndIcon: this.preferences.columnMode === 'odd_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setColumnMode('odd_left') }) })
      MenuItem({ content: s('reader_column_mode_even_left'), symbolEndIcon: this.preferences.columnMode === 'even_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setColumnMode('even_left') }) })
    }
  }

  @Builder
  private ScalingQualityMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('reader_image_scaling_quality_low'), symbolEndIcon: this.preferences.imageScalingQuality === 'low' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setImageScalingQuality('low') }) })
      MenuItem({ content: s('reader_image_scaling_quality_medium'), symbolEndIcon: this.preferences.imageScalingQuality === 'medium' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setImageScalingQuality('medium') }) })
      MenuItem({ content: s('reader_image_scaling_quality_high'), symbolEndIcon: this.preferences.imageScalingQuality === 'high' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setImageScalingQuality('high') }) })
    }
  }

  @Builder
  private VolumeKeyBehaviorMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderVolumeKeyBehaviorLabel('up_previous_down_next'), symbolEndIcon: this.preferences.volumeKeyBehavior === 'up_previous_down_next' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setVolumeKeyBehavior('up_previous_down_next') }) })
      MenuItem({ content: getReaderVolumeKeyBehaviorLabel('up_next_down_previous'), symbolEndIcon: this.preferences.volumeKeyBehavior === 'up_next_down_previous' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setVolumeKeyBehavior('up_next_down_previous') }) })
    }
  }

  @Builder
  private GapMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderPageGapModeLabel('compact'), symbolEndIcon: this.preferences.pageGapMode === 'compact' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setGap('compact') }) })
      MenuItem({ content: getReaderPageGapModeLabel('normal'), symbolEndIcon: this.preferences.pageGapMode === 'normal' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setGap('normal') }) })
      MenuItem({ content: getReaderPageGapModeLabel('wide'), symbolEndIcon: this.preferences.pageGapMode === 'wide' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setGap('wide') }) })
    }
  }

  @Builder
  private WideMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderWideImageModeLabel('keep_single'), symbolEndIcon: this.preferences.wideImageMode === 'keep_single' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setWide('keep_single') }) })
      MenuItem({ content: getReaderWideImageModeLabel('split_wide_pages'), symbolEndIcon: this.preferences.wideImageMode === 'split_wide_pages' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setWide('split_wide_pages') }) })
      MenuItem({ content: getReaderWideImageModeLabel('rotate_wide_pages'), symbolEndIcon: this.preferences.wideImageMode === 'rotate_wide_pages' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setWide('rotate_wide_pages') }) })
    }
  }

  @Builder
  private AutoPageMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach([2, 3, 5, 8, 10], (seconds: number) => {
        MenuItem({ content: `${seconds}s`, symbolEndIcon: this.preferences.autoPageSeconds === seconds ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setAutoPageSeconds(seconds) }) })
      }, (seconds: number) => `auto-page-${seconds}`)
    }
  }

  @Builder
  private PreloadMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach([0, 1, 2, 3, 4, 5], (pages: number) => {
        MenuItem({ content: `${pages}`, symbolEndIcon: this.preferences.preloadPages === pages ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPreloadPages(pages) }) })
      }, (pages: number) => `preload-${pages}`)
    }
  }

  @Builder
  private ReaderSettingsSheet() {
    KomaModalScaffold({
      title: s('settings_pane_reader_title'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      onClose: () => {
        this.closeSettings()
      },
    }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
          SectionHeader({ title: s('settings_reader_group_layout') })
          GroupedListSection() {
            ConciseListRow({ title: s('reader_control_mode'), trailingText: getReaderModeLabel(this.readerMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PageModeMenu(select) } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reading_direction_title'), trailingText: getReadingDirectionLabel(this.preferences.readingDirection), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.DirectionMenu(select) } })
            ListDivider()
            if (this.readerMode === ReaderMode.DUAL_PAGE) {
              ConciseListRow({ title: s('reader_spread_layout_title'), trailingText: this.preferences.spreadLayoutMode === 'split' ? s('reader_spread_layout_split') : s('reader_spread_layout_joined'), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.SpreadLayoutMenu(select) } })
              ListDivider()
              ConciseListRow({ title: s('reader_column_mode_title'), trailingText: this.preferences.columnMode === 'even_left' ? s('reader_column_mode_even_left') : s('reader_column_mode_odd_left'), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ColumnModeMenu(select) } })
              ListDivider()
            }
            if (!this.isWebtoonLayout()) {
              ConciseListRow({ title: s('reader_page_turn_animation_title'), hasSwitch: true, checked: this.preferences.pageTurnAnimation, showChevron: false, switchAction: (value: boolean) => { this.setToggle('page-animation', value) } })
            }
          }
          SectionHeader({ title: s('settings_reader_group_tap_zones') })
          GroupedListSection() {
            ConciseListRow({ title: s('settings_row_reader_tap_zone_preset_title'), trailingText: getReaderTapZonePresetLabel(this.preferences.tapZonePreset), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.TapZoneMenu(select) } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_tap_zone_invert_title'), trailingText: getReaderTapZoneInvertLabel(this.preferences.tapZoneInvert), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.TapInvertMenu(select) } })
          }
          SectionHeader({ title: s('settings_reader_group_display') })
          GroupedListSection() {
            ConciseListRow({ title: s('settings_row_reader_background_title'), trailingText: getReaderBackgroundModeLabel(this.preferences.backgroundMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.BackgroundMenu(select) } })
            ListDivider()
            ConciseListRow({ title: s('reader_image_scaling_quality_title'), trailingText: this.scalingQualityLabel(), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ScalingQualityMenu(select) } })
            ListDivider()
            ConciseListRow({ title: s('reader_show_page_number_title'), hasSwitch: true, checked: this.preferences.showPageNumber, showChevron: false, switchAction: (value: boolean) => { this.setToggle('page-number', value) } })
            ListDivider()
            ConciseListRow({ title: s('reader_fullscreen_title'), hasSwitch: true, checked: this.preferences.fullscreen, showChevron: false, switchAction: (value: boolean) => { this.setToggle('fullscreen', value) } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_keep_screen_awake_title'), hasSwitch: true, checked: this.preferences.keepScreenAwake, showChevron: false, switchAction: (value: boolean) => { this.setToggle('awake', value) } })
          }
          SectionHeader({ title: s('settings_reader_group_navigation') })
          GroupedListSection() {
            ConciseListRow({ title: s('reader_auto_page_title'), trailingText: `${this.preferences.autoPageSeconds}s`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutoPageMenu(select) } })
            ListDivider()
            ConciseListRow({ title: s('reader_preload_pages_title'), trailingText: `${this.preferences.preloadPages}`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PreloadMenu(select) } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_volume_key_navigation_title'), hasSwitch: true, checked: this.preferences.volumeKeyNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('volume', value) } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_volume_key_behavior_title'), trailingText: getReaderVolumeKeyBehaviorLabel(this.preferences.volumeKeyBehavior), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.volumeKeyNavigationEnabled, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.VolumeKeyBehaviorMenu(select) } })
          }
          SectionHeader({ title: s('settings_row_reader_page_gap_title') })
          GroupedListSection() {
            ConciseListRow({ title: s('settings_row_reader_page_gap_title'), trailingText: getReaderPageGapModeLabel(this.preferences.pageGapMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.GapMenu(select) } })
            ListDivider()
            if (!this.isWebtoonLayout()) {
              ConciseListRow({ title: s('settings_row_reader_wide_image_mode_title'), trailingText: getReaderWideImageModeLabel(this.preferences.wideImageMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.WideMenu(select) } })
            }
          }
        Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_LG })
    }
  }

  @Builder
  private ModeMenu() {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.SINGLE_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.DUAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.VERTICAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.VERTICAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.VERTICAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.CONTINUOUS_SCROLL); this.modeShown = false })
    }
  }

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: s('reader_action_image_info') }).enabled(this.pageTotal > 0).onClick(() => { this.openImageInfo() })
      MenuItem({ content: s('reader_action_save_image') }).enabled(this.pageTotal > 0).onClick(() => { this.onSaveImage(); this.moreShown = false })
      MenuItem({ content: s('reader_action_share_image') }).enabled(this.pageTotal > 0).onClick(() => { this.onShareImage(); this.moreShown = false })
      MenuItem({ content: s('reader_action_reset_zoom') }).enabled(this.zoomScale > 1.01).onClick(() => { this.onResetZoom(); this.moreShown = false })
      MenuItem({ content: s('reader_action_previous_chapter') }).enabled(this.canGoPreviousChapter).onClick(() => { this.onPreviousChapter(); this.moreShown = false })
      MenuItem({ content: s('reader_action_next_chapter') }).enabled(this.canGoNextChapter).onClick(() => { this.onNextChapter(); this.moreShown = false })
      MenuItem({ content: s('reader_action_return_to_detail') }).onClick(() => { this.onOpenMangaDetail(); this.moreShown = false })
      MenuItem({ content: s('reader_page_load_failed') }).enabled(this.pageFailed).onClick(() => { this.onReloadPage(); this.moreShown = false })
    }
  }

  @Builder
  private ImageInfoSheet() {
    KomaModalScaffold({
      title: s('reader_image_info_title'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      onClose: () => {
        this.imageInfoShown = false
      },
    }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        GroupedListSection() {
          ConciseListRow({ title: s('reader_image_info_page'), trailingText: this.pageText(), showChevron: false })
          ListDivider()
          ConciseListRow({ title: s('reader_image_info_dimensions'), trailingText: this.imageDimensionsText(), showChevron: false })
          ListDivider()
          ConciseListRow({ title: s('reader_image_info_source'), trailingText: this.pageImageSourceLabel, showChevron: false })
        }
      }
      .width('100%').padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  private ChapterPickerSheet() {
    KomaModalScaffold({
      title: s('reader_control_chapter'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      contentOwnsScrolling: true,
      onClose: () => {
        this.chapterPickerShown = false
      },
    }) {
      List({ scroller: this.chapterPickerScroller, space: ThemeConstants.SPACE_SM }) {
        ForEach(this.chapterPickerIndexes(), (index: number) => {
          ListItem() {
            ConciseListRow({
              title: this.chapterPickerTitle(index),
              primaryColor: index === this.chapterIndex ? ThemeConstants.BRAND_PRIMARY : undefined,
              showChevron: index !== this.chapterIndex,
              suffixBuilderParam: index === this.chapterIndex ? () => {
                this.ChapterSelectedCheckmark()
              } : undefined,
              action: () => {
                this.selectChapterFromPicker(index)
              },
            })
          }
          .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
        }, (index: number) => `reader-chapter-picker-${index}`)
      }
      .width('100%')
      .height('100%')
      .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XL })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  private TopBar() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => { this.onCloseReader() })
      .bindSheet($$this.imageInfoShown, this.ImageInfoSheet, {
        detents: [SheetSize.MEDIUM],
        showClose: false,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        enableFloatingDragBar: true,
        onDisappear: () => { this.imageInfoShown = false },
      })

      Column({ space: 2 }) {
        Text(this.title.length > 0 ? this.title : s('reader_title_default'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineBreakStrategy(LineBreakStrategy.BALANCED)
          .textAlign(TextAlign.Start)
          .width('100%')

        Row({ space: ThemeConstants.SPACE_XS }) {
          Text(this.pageText())
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .maxLines(1)
            .flexShrink(0)
          Text('·')
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .flexShrink(0)
          Text(this.chapterTitleText())
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_SM })
      .alignItems(HorizontalAlign.Start)

      Row({ space: ThemeConstants.SPACE_XS }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor([Color.White])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => { this.settingsShown = true })
        .bindSheet($$this.settingsShown, this.ReaderSettingsSheet, {
          detents: [SheetSize.MEDIUM, SheetSize.LARGE],
          showClose: false,
          enableOutsideInteractive: false,
          scrollSizeMode: ScrollSizeMode.CONTINUOUS,
          enableFloatingDragBar: true,
          onDisappear: () => { this.closeSettings() },
        })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2')).fontSize(22).fontColor([Color.White])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(s('common_more_actions'))
        .onClick(() => { this.moreShown = true })
        .bindMenu(this.moreShown, this.MoreMenu, {
          placement: Placement.BottomRight,
          onDisappear: () => { this.moreShown = false },
        })
      }
    }
    .width('100%')
    .height(this.topInset + 56)
    .padding({
      top: this.topInset,
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_SM,
    })
    .backgroundColor('#CC000000')
    .hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private BottomBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.thumbnailStrip) {
          this.thumbnailStrip()
        }
      }
      .width('100%')
      .height(this.thumbStripVisible ? 156 : 0)
      .padding({ top: this.thumbStripVisible ? ThemeConstants.SPACE_SM : 0, bottom: this.thumbStripVisible ? ThemeConstants.SPACE_SM : 0 })
      .margin({ bottom: this.bottomInset + 104 })
      .backgroundColor('#CC000000')
      .clip(true)
      .hitTestBehavior(this.thumbStripVisible ? HitTestMode.Default : HitTestMode.None)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Row({ space: 4 }) {
          Text(`${this.pageIndex + 1}`).fontSize(14).fontColor(Color.White).width(30).textAlign(TextAlign.Start)
          Slider({ value: this.pageIndex + 1, min: 1, max: Math.max(this.pageTotal, 1), step: 1, style: SliderStyle.InSet, reverse: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT })
            .layoutWeight(1).trackColor('#33FFFFFF').selectedColor(ThemeConstants.BRAND_PRIMARY)
            .onChange((value: number, mode: SliderChangeMode) => {
              const target = Math.max(0, Math.min(Math.round(value) - 1, Math.max(this.pageTotal - 1, 0)))
              if (this.readerMode === ReaderMode.CONTINUOUS_SCROLL || mode === SliderChangeMode.End) this.onSeekPage(target)
              else this.onPageChange(target)
            })
          Text(`${Math.max(this.pageTotal, 0)}`).fontSize(14).fontColor(Color.White).width(30).textAlign(TextAlign.End)
        }.width('100%').height(32)
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.book')).fontSize(22).fontColor([this.readerMode === ReaderMode.DUAL_PAGE ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.pageTotal > 1).onClick(() => { this.onModeChange(this.readerMode === ReaderMode.DUAL_PAGE ? ReaderMode.SINGLE_PAGE : ReaderMode.DUAL_PAGE) })
          if (this.readerMode === ReaderMode.DUAL_PAGE) {
            Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.transfer')).fontSize(22).fontColor([this.canTurnOnePageInDoublePage ? Color.White : ThemeConstants.STATUS_MUTED]) }
              .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.canTurnOnePageInDoublePage).onClick(() => { this.onTurnOnePageInDoublePage() })
          }
          Blank().layoutWeight(1)
          Text(this.chapterText())
            .fontSize(13)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              if (this.chapterTotal > 0) {
                this.chapterPickerShown = true
              }
            })
            .bindSheet($$this.chapterPickerShown, this.ChapterPickerSheet, {
              detents: [SheetSize.MEDIUM, SheetSize.LARGE],
              showClose: false,
              enableOutsideInteractive: false,
              scrollSizeMode: ScrollSizeMode.CONTINUOUS,
              enableFloatingDragBar: true,
              onDisappear: () => {
                this.finishChapterPickerDismissal()
              },
            })
          Blank().layoutWeight(1)
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.clock')).fontSize(22).fontColor([this.autoPageActive ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.readerMode !== ReaderMode.CONTINUOUS_SCROLL).onClick(() => { this.onToggleAutoPage() })
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.rectangle_grid_2x1')).fontSize(22).fontColor([this.thumbStripVisible ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.onToggleThumbStrip() })
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph(this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? $r('sys.symbol.scroll_vertical') : $r('sys.symbol.arrow_right_and_square')).fontSize(22).fontColor([Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.modeShown = true }).bindMenu(this.modeShown, this.ModeMenu, { placement: Placement.TopRight, onDisappear: () => { this.modeShown = false } })
        }.width('100%').height(52).padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG }).alignItems(VerticalAlign.Center)
      }
      .width('100%').height(this.bottomInset + 104).padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: this.bottomInset + ThemeConstants.SPACE_SM }).backgroundColor('#CC000000')
    }
    .width('100%').height(this.bottomInset + 104 + (this.thumbStripVisible ? 156 : 0)).hitTestBehavior(HitTestMode.Default)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.visible && this.placement === 'top') {
        this.TopBar()
      }
      if (this.visible && this.placement === 'bottom') {
        this.BottomBar()
      }
    }
    .width('100%')
    .height(this.barHeight())
    .position({ x: 0, y: this.barOffsetY() })
    .hitTestBehavior(HitTestMode.Default)
  }
}
