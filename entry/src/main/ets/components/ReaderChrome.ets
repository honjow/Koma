import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode, getReaderModeLabel } from '../model/ReaderSessionStore'
import {
  ReaderBackgroundMode,
  ReaderColumnMode,
  ReaderImageFitMode,
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
  getReaderImageFitModeLabel,
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

  @Local private settingsShown: boolean = false
  @Local private moreShown: boolean = false
  @Local private modeShown: boolean = false
  @Local private menuKey: string = ''

  private pageText(): string {
    const total = Math.max(this.pageTotal, 0)
    return total <= 0 ? '0 / 0' : `${Math.min(Math.max(this.pageIndex + 1, 1), total)} / ${total}`
  }

  private chapterText(): string {
    return this.chapterTotal <= 0 ? '' : `${s('reader_control_chapter')} ${this.chapterIndex + 1} / ${this.chapterTotal}`
  }

  private chapterTitleText(): string {
    const title = this.chapterIndex >= 0 && this.chapterIndex < this.chapterTitles.length
      ? this.chapterTitles[this.chapterIndex]
      : ''
    return title.length > 0 ? title : this.chapterText()
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
      tapNavigationEnabled: true,
      swipeNavigationEnabled: true,
      zoomGesturesEnabled: true,
      tapZonePreset: p.tapZonePreset,
      tapZoneInvert: p.tapZoneInvert,
      showTapZones: false,
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

  private setImageFit(mode: ReaderImageFitMode): void {
    const next = this.copyPreferences()
    next.imageFitMode = mode
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
    if (key === 'trim-margins') next.trimPageMarginsEnabled = value
    if (key === 'volume') next.volumeKeyNavigationEnabled = value
    this.update(next)
  }

  private closeSettings(): void {
    this.settingsShown = false
    this.menuKey = ''
  }

  private revealTapZonePreview(): void {
    // Match the reference interaction: applying a zone immediately returns to
    // the reader so the full-screen, one-shot preview is actually visible.
    this.closeSettings()
    this.onVisibleChange(false)
  }

  private closeMenus(): void {
    this.menuKey = ''
  }

  @Builder
  private PageModeMenu() {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setPageMode('single_page'); this.closeMenus() })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setPageMode('double_page'); this.closeMenus() })
      MenuItem({ content: getReaderModeLabel(ReaderMode.VERTICAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.VERTICAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setPageMode('vertical_page'); this.closeMenus() })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setPageMode('continuous_scroll'); this.closeMenus() })
    }
  }

  @Builder
  private DirectionMenu() {
    Menu() {
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.LEFT_TO_RIGHT), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.LEFT_TO_RIGHT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setDirection(ReadingDirection.LEFT_TO_RIGHT); this.closeMenus() })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.RIGHT_TO_LEFT), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setDirection(ReadingDirection.RIGHT_TO_LEFT); this.closeMenus() })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.WEBTOON), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.WEBTOON ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setDirection(ReadingDirection.WEBTOON); this.closeMenus() })
    }
  }

  @Builder
  private BackgroundMenu() {
    Menu() {
      MenuItem({ content: getReaderBackgroundModeLabel('black'), symbolEndIcon: this.preferences.backgroundMode === 'black' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('black'); this.closeMenus() })
      MenuItem({ content: getReaderBackgroundModeLabel('gray'), symbolEndIcon: this.preferences.backgroundMode === 'gray' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('gray'); this.closeMenus() })
      MenuItem({ content: getReaderBackgroundModeLabel('white'), symbolEndIcon: this.preferences.backgroundMode === 'white' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('white'); this.closeMenus() })
      MenuItem({ content: getReaderBackgroundModeLabel('auto'), symbolEndIcon: this.preferences.backgroundMode === 'auto' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('auto'); this.closeMenus() })
    }
  }

  @Builder
  private ImageFitMenu() {
    Menu() {
      MenuItem({ content: getReaderImageFitModeLabel('contain'), symbolEndIcon: this.preferences.imageFitMode === 'contain' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setImageFit('contain'); this.closeMenus() })
      MenuItem({ content: getReaderImageFitModeLabel('fit_width'), symbolEndIcon: this.preferences.imageFitMode === 'fit_width' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setImageFit('fit_width'); this.closeMenus() })
      MenuItem({ content: getReaderImageFitModeLabel('fit_height'), symbolEndIcon: this.preferences.imageFitMode === 'fit_height' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setImageFit('fit_height'); this.closeMenus() })
    }
  }

  @Builder
  private TapZoneMenu() {
    Menu() {
      MenuItem({ content: getReaderTapZonePresetLabel('right_left'), symbolEndIcon: this.preferences.tapZonePreset === 'right_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('right_left'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('l_shaped'), symbolEndIcon: this.preferences.tapZonePreset === 'l_shaped' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('l_shaped'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('kindle'), symbolEndIcon: this.preferences.tapZonePreset === 'kindle' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('kindle'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('edge'), symbolEndIcon: this.preferences.tapZonePreset === 'edge' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('edge'); this.closeMenus() })
    }
  }

  @Builder
  private TapInvertMenu() {
    Menu() {
      MenuItem({ content: getReaderTapZoneInvertLabel('none'), symbolEndIcon: this.preferences.tapZoneInvert === 'none' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapInvert('none'); this.closeMenus() })
      MenuItem({ content: getReaderTapZoneInvertLabel('horizontal'), symbolEndIcon: this.preferences.tapZoneInvert === 'horizontal' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapInvert('horizontal'); this.closeMenus() })
      MenuItem({ content: getReaderTapZoneInvertLabel('vertical'), symbolEndIcon: this.preferences.tapZoneInvert === 'vertical' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapInvert('vertical'); this.closeMenus() })
      MenuItem({ content: getReaderTapZoneInvertLabel('both'), symbolEndIcon: this.preferences.tapZoneInvert === 'both' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapInvert('both'); this.closeMenus() })
    }
  }

  @Builder
  private SpreadLayoutMenu() {
    Menu() {
      MenuItem({ content: s('reader_spread_layout_joined'), symbolEndIcon: this.preferences.spreadLayoutMode === 'joined' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setSpreadLayout('joined'); this.closeMenus() })
      MenuItem({ content: s('reader_spread_layout_split'), symbolEndIcon: this.preferences.spreadLayoutMode === 'split' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setSpreadLayout('split'); this.closeMenus() })
    }
  }

  @Builder
  private ColumnModeMenu() {
    Menu() {
      MenuItem({ content: s('reader_column_mode_odd_left'), symbolEndIcon: this.preferences.columnMode === 'odd_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setColumnMode('odd_left'); this.closeMenus() })
      MenuItem({ content: s('reader_column_mode_even_left'), symbolEndIcon: this.preferences.columnMode === 'even_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setColumnMode('even_left'); this.closeMenus() })
    }
  }

  @Builder
  private ScalingQualityMenu() {
    Menu() {
      MenuItem({ content: s('reader_image_scaling_quality_low'), symbolEndIcon: this.preferences.imageScalingQuality === 'low' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setImageScalingQuality('low'); this.closeMenus() })
      MenuItem({ content: s('reader_image_scaling_quality_medium'), symbolEndIcon: this.preferences.imageScalingQuality === 'medium' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setImageScalingQuality('medium'); this.closeMenus() })
      MenuItem({ content: s('reader_image_scaling_quality_high'), symbolEndIcon: this.preferences.imageScalingQuality === 'high' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setImageScalingQuality('high'); this.closeMenus() })
    }
  }

  @Builder
  private VolumeKeyBehaviorMenu() {
    Menu() {
      MenuItem({ content: getReaderVolumeKeyBehaviorLabel('up_previous_down_next'), symbolEndIcon: this.preferences.volumeKeyBehavior === 'up_previous_down_next' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setVolumeKeyBehavior('up_previous_down_next'); this.closeMenus() })
      MenuItem({ content: getReaderVolumeKeyBehaviorLabel('up_next_down_previous'), symbolEndIcon: this.preferences.volumeKeyBehavior === 'up_next_down_previous' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setVolumeKeyBehavior('up_next_down_previous'); this.closeMenus() })
    }
  }

  @Builder
  private GapMenu() {
    Menu() {
      MenuItem({ content: getReaderPageGapModeLabel('compact'), symbolEndIcon: this.preferences.pageGapMode === 'compact' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setGap('compact'); this.closeMenus() })
      MenuItem({ content: getReaderPageGapModeLabel('normal'), symbolEndIcon: this.preferences.pageGapMode === 'normal' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setGap('normal'); this.closeMenus() })
      MenuItem({ content: getReaderPageGapModeLabel('wide'), symbolEndIcon: this.preferences.pageGapMode === 'wide' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setGap('wide'); this.closeMenus() })
    }
  }

  @Builder
  private WideMenu() {
    Menu() {
      MenuItem({ content: getReaderWideImageModeLabel('keep_single'), symbolEndIcon: this.preferences.wideImageMode === 'keep_single' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setWide('keep_single'); this.closeMenus() })
      MenuItem({ content: getReaderWideImageModeLabel('split_wide_pages'), symbolEndIcon: this.preferences.wideImageMode === 'split_wide_pages' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setWide('split_wide_pages'); this.closeMenus() })
      MenuItem({ content: getReaderWideImageModeLabel('rotate_wide_pages'), symbolEndIcon: this.preferences.wideImageMode === 'rotate_wide_pages' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setWide('rotate_wide_pages'); this.closeMenus() })
    }
  }

  @Builder
  private AutoPageMenu() {
    Menu() {
      ForEach([2, 3, 5, 8, 10], (seconds: number) => {
        MenuItem({ content: `${seconds}s`, symbolEndIcon: this.preferences.autoPageSeconds === seconds ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setAutoPageSeconds(seconds); this.closeMenus() })
      }, (seconds: number) => `auto-page-${seconds}`)
    }
  }

  @Builder
  private PreloadMenu() {
    Menu() {
      ForEach([0, 1, 2, 3, 4, 5], (pages: number) => {
        MenuItem({ content: `${pages}`, symbolEndIcon: this.preferences.preloadPages === pages ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setPreloadPages(pages); this.closeMenus() })
      }, (pages: number) => `preload-${pages}`)
    }
  }

  @Builder
  private ReaderSettingsSheet() {
    Column() {
      Row() {
        Text(s('settings_pane_reader_title')).fontSize(ThemeConstants.FONT_SIZE_H3).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(20).fontColor([$r('sys.color.font_primary')])
        }
        .width(44).height(44).backgroundColor(Color.Transparent)
        .accessibilityText(s('common_close'))
        .onClick(() => { this.closeSettings() })
      }
      .width('100%').height(56).padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_SM })
      Divider().strokeWidth(0.5).color(ThemeConstants.DIVIDER)
      Scroll() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          SectionHeader({ title: s('settings_reader_group_layout') })
          GroupedListSection() {
            Column() { ConciseListRow({ title: s('reader_control_mode'), trailingText: getReaderModeLabel(this.readerMode), trailingDropdown: true, action: () => { this.menuKey = 'mode' } }) }.bindMenu(this.menuKey === 'mode', this.PageModeMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('settings_row_reading_direction_title'), trailingText: getReadingDirectionLabel(this.preferences.readingDirection), trailingDropdown: true, action: () => { this.menuKey = 'direction' } }) }.bindMenu(this.menuKey === 'direction', this.DirectionMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('reader_spread_layout_title'), trailingText: this.preferences.spreadLayoutMode === 'split' ? s('reader_spread_layout_split') : s('reader_spread_layout_joined'), trailingDropdown: true, isEnabled: this.readerMode === ReaderMode.DUAL_PAGE, action: () => { this.menuKey = 'spread' } }) }.bindMenu(this.menuKey === 'spread', this.SpreadLayoutMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('reader_column_mode_title'), trailingText: this.preferences.columnMode === 'even_left' ? s('reader_column_mode_even_left') : s('reader_column_mode_odd_left'), trailingDropdown: true, isEnabled: this.readerMode === ReaderMode.DUAL_PAGE, action: () => { this.menuKey = 'column' } }) }.bindMenu(this.menuKey === 'column', this.ColumnModeMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            ConciseListRow({ title: s('reader_page_turn_animation_title'), hasSwitch: true, checked: this.preferences.pageTurnAnimation, showChevron: false, switchAction: (value: boolean) => { this.setToggle('page-animation', value) } })
          }
          SectionHeader({ title: s('settings_reader_group_tap_zones') })
          GroupedListSection() {
            Column() { ConciseListRow({ title: s('settings_row_reader_tap_zone_preset_title'), trailingText: getReaderTapZonePresetLabel(this.preferences.tapZonePreset), trailingDropdown: true, action: () => { this.menuKey = 'tap-zone' } }) }.bindMenu(this.menuKey === 'tap-zone', this.TapZoneMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('settings_row_reader_tap_zone_invert_title'), trailingText: getReaderTapZoneInvertLabel(this.preferences.tapZoneInvert), trailingDropdown: true, action: () => { this.menuKey = 'tap-invert' } }) }.bindMenu(this.menuKey === 'tap-invert', this.TapInvertMenu, { onDisappear: () => { this.closeMenus() } })
          }
          SectionHeader({ title: s('settings_reader_group_display') })
          GroupedListSection() {
            Column() { ConciseListRow({ title: s('settings_row_reader_background_title'), trailingText: getReaderBackgroundModeLabel(this.preferences.backgroundMode), trailingDropdown: true, action: () => { this.menuKey = 'background' } }) }.bindMenu(this.menuKey === 'background', this.BackgroundMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('settings_row_reader_image_fit_title'), trailingText: getReaderImageFitModeLabel(this.preferences.imageFitMode), trailingDropdown: true, action: () => { this.menuKey = 'fit' } }) }.bindMenu(this.menuKey === 'fit', this.ImageFitMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('reader_image_scaling_quality_title'), trailingText: this.scalingQualityLabel(), trailingDropdown: true, action: () => { this.menuKey = 'scaling' } }) }.bindMenu(this.menuKey === 'scaling', this.ScalingQualityMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            ConciseListRow({ title: s('reader_show_page_number_title'), hasSwitch: true, checked: this.preferences.showPageNumber, showChevron: false, switchAction: (value: boolean) => { this.setToggle('page-number', value) } })
            ListDivider()
            ConciseListRow({ title: s('reader_fullscreen_title'), hasSwitch: true, checked: this.preferences.fullscreen, showChevron: false, switchAction: (value: boolean) => { this.setToggle('fullscreen', value) } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_keep_screen_awake_title'), hasSwitch: true, checked: this.preferences.keepScreenAwake, showChevron: false, switchAction: (value: boolean) => { this.setToggle('awake', value) } })
          }
          SectionHeader({ title: s('settings_reader_group_navigation') })
          GroupedListSection() {
            Column() { ConciseListRow({ title: s('reader_auto_page_title'), trailingText: `${this.preferences.autoPageSeconds}s`, trailingDropdown: true, action: () => { this.menuKey = 'auto' } }) }.bindMenu(this.menuKey === 'auto', this.AutoPageMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('reader_preload_pages_title'), trailingText: `${this.preferences.preloadPages}`, trailingDropdown: true, action: () => { this.menuKey = 'preload' } }) }.bindMenu(this.menuKey === 'preload', this.PreloadMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_volume_key_navigation_title'), hasSwitch: true, checked: this.preferences.volumeKeyNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('volume', value) } })
            ListDivider()
            Column() { ConciseListRow({ title: s('settings_row_reader_volume_key_behavior_title'), trailingText: getReaderVolumeKeyBehaviorLabel(this.preferences.volumeKeyBehavior), trailingDropdown: true, isEnabled: this.preferences.volumeKeyNavigationEnabled, action: () => { this.menuKey = 'volume-behavior' } }) }.bindMenu(this.menuKey === 'volume-behavior', this.VolumeKeyBehaviorMenu, { onDisappear: () => { this.closeMenus() } })
          }
          SectionHeader({ title: s('settings_row_reader_page_gap_title') })
          GroupedListSection() {
            Column() { ConciseListRow({ title: s('settings_row_reader_page_gap_title'), trailingText: getReaderPageGapModeLabel(this.preferences.pageGapMode), trailingDropdown: true, action: () => { this.menuKey = 'gap' } }) }.bindMenu(this.menuKey === 'gap', this.GapMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            Column() { ConciseListRow({ title: s('settings_row_reader_wide_image_mode_title'), trailingText: getReaderWideImageModeLabel(this.preferences.wideImageMode), trailingDropdown: true, action: () => { this.menuKey = 'wide' } }) }.bindMenu(this.menuKey === 'wide', this.WideMenu, { onDisappear: () => { this.closeMenus() } })
            ListDivider()
            ConciseListRow({ title: s('settings_row_reader_trim_page_margins_title'), hasSwitch: true, checked: this.preferences.trimPageMarginsEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('trim-margins', value) } })
          }
          Blank().height(ThemeConstants.SPACE_XL)
        }
        .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_LG })
      }
      .scrollBar(BarState.Off).width('100%').layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
      MenuItem({ content: s('reader_action_reset_zoom') }).enabled(this.zoomScale > 1.01).onClick(() => { this.onResetZoom(); this.moreShown = false })
      MenuItem({ content: s('reader_action_previous_chapter') }).enabled(this.canGoPreviousChapter).onClick(() => { this.onPreviousChapter(); this.moreShown = false })
      MenuItem({ content: s('reader_action_next_chapter') }).enabled(this.canGoNextChapter).onClick(() => { this.onNextChapter(); this.moreShown = false })
      MenuItem({ content: s('reader_action_return_to_detail') }).onClick(() => { this.onOpenMangaDetail(); this.moreShown = false })
      MenuItem({ content: s('reader_page_load_failed') }).enabled(this.pageFailed).onClick(() => { this.onReloadPage(); this.moreShown = false })
    }
  }

  @Builder
  private TopBar() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White]) }
          .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.onCloseReader() })
        Blank().layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor([Color.White]) }
          .width(44).height(44).backgroundColor(Color.Transparent)
          .onClick(() => { this.settingsShown = true })
          .bindSheet($$this.settingsShown, this.ReaderSettingsSheet, { detents: [SheetSize.MEDIUM, SheetSize.LARGE], showClose: false, onDisappear: () => { this.closeSettings() } })
        Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.dot_grid_2x2')).fontSize(22).fontColor([Color.White]) }
          .width(44).height(44).backgroundColor(Color.Transparent).accessibilityText(s('common_more_actions'))
          .onClick(() => { this.moreShown = true })
          .bindMenu(this.moreShown, this.MoreMenu, { placement: Placement.BottomRight, onDisappear: () => { this.moreShown = false } })
      }
      .width('100%').height(56).padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM }).alignItems(VerticalAlign.Center)
      Column({ space: 1 }) {
        Text(this.title.length > 0 ? this.title : s('reader_title_default')).fontSize(13).fontColor(Color.White).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
        Text(this.chapterTitleText()).fontSize(11).fontColor('#CCFFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
        Text(this.pageText()).fontSize(11).fontColor('#CCFFFFFF').maxLines(1)
      }
      .width('54%').hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height(this.topInset + 72).padding({ top: this.topInset }).backgroundColor('#CC000000').hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private BottomBar() {
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
        Text(this.chapterText()).fontSize(13).fontColor(Color.White).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank().layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.clock')).fontSize(22).fontColor([this.autoPageActive ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
          .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.readerMode !== ReaderMode.CONTINUOUS_SCROLL).onClick(() => { this.onToggleAutoPage() })
        Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph(this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? $r('sys.symbol.scroll_vertical') : $r('sys.symbol.arrow_right_and_square')).fontSize(22).fontColor([Color.White]) }
          .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.modeShown = true }).bindMenu(this.modeShown, this.ModeMenu, { placement: Placement.TopRight, onDisappear: () => { this.modeShown = false } })
      }.width('100%').height(52).padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG }).alignItems(VerticalAlign.Center)
    }
    .width('100%').padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: this.bottomInset + ThemeConstants.SPACE_SM }).backgroundColor('#CC000000').hitTestBehavior(HitTestMode.Default)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.visible) {
        Column() {
          Blank().layoutWeight(1).hitTestBehavior(HitTestMode.Block).onClick(() => { this.onVisibleChange(false) })
          this.BottomBar()
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.Default)
        this.TopBar()
      } else {
        Blank().width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%').height('100%').hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.Transparent)
  }
}
