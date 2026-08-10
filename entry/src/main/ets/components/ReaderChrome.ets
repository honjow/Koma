import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode, getReaderModeLabel } from '../model/ReaderSessionStore'
import {
  ReaderBackgroundMode,
  ReaderImageFitMode,
  ReaderPageGapMode,
  ReaderPreferences,
  ReaderTapZoneInvert,
  ReaderTapZonePreset,
  ReaderVolumeKeyBehavior,
  ReaderWideImageMode,
  ReaderPageMode,
  DEFAULT_READER_PREFERENCES,
  getReadingDirectionLabel,
  getReaderBackgroundModeLabel,
  getReaderImageFitModeLabel,
  getReaderPageGapModeLabel,
  getReaderTapZoneInvertLabel,
  getReaderTapZonePresetLabel,
  getReaderVolumeKeyBehaviorLabel,
  getReaderWideImageModeLabel,
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

  @Local private settingsShown: boolean = false
  @Local private moreShown: boolean = false
  @Local private modeShown: boolean = false
  @Local private menuKey: string = ''

  private pageText(): string {
    const total = Math.max(this.pageTotal, 0)
    if (total === 0) {
      return '0 / 0'
    }
    return `${Math.min(Math.max(this.pageIndex + 1, 1), total)} / ${total}`
  }

  private chapterText(): string {
    if (this.chapterTotal <= 0) {
      return ''
    }
    return `${s('reader_control_chapter')} ${this.chapterIndex + 1} / ${this.chapterTotal}`
  }

  private chapterTitle(index: number): string {
    const title = index >= 0 && index < this.chapterTitles.length ? this.chapterTitles[index] : ''
    return title.length > 0 ? title : `${s('reader_control_chapter')} ${index + 1}`
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
      showProgressControls: p.showProgressControls,
      keepScreenAwake: p.keepScreenAwake,
      imageFitMode: p.imageFitMode,
      tapNavigationEnabled: p.tapNavigationEnabled,
      swipeNavigationEnabled: p.swipeNavigationEnabled,
      zoomGesturesEnabled: p.zoomGesturesEnabled,
      tapZonePreset: p.tapZonePreset,
      tapZoneInvert: p.tapZoneInvert,
      showTapZones: p.showTapZones,
      pageGapMode: p.pageGapMode,
      trimPageMarginsEnabled: p.trimPageMarginsEnabled,
      wideImageMode: p.wideImageMode,
      volumeKeyNavigationEnabled: p.volumeKeyNavigationEnabled,
      volumeKeyBehavior: p.volumeKeyBehavior,
    }
  }

  private setPageMode(pageMode: ReaderPageMode): void {
    const p = this.copyPreferences()
    p.pageMode = pageMode
    this.update(p)
  }

  private setDirection(direction: ReadingDirection): void {
    const p = this.copyPreferences()
    p.readingDirection = direction
    this.update(p)
  }

  private setBackground(mode: ReaderBackgroundMode): void {
    const p = this.copyPreferences()
    p.backgroundMode = mode
    this.update(p)
  }

  private setImageFit(mode: ReaderImageFitMode): void {
    const p = this.copyPreferences()
    p.imageFitMode = mode
    this.update(p)
  }

  private setTapZone(mode: ReaderTapZonePreset): void {
    const p = this.copyPreferences()
    p.tapZonePreset = mode
    this.update(p)
  }

  private setTapInvert(mode: ReaderTapZoneInvert): void {
    const p = this.copyPreferences()
    p.tapZoneInvert = mode
    this.update(p)
  }

  private setGap(mode: ReaderPageGapMode): void {
    const p = this.copyPreferences()
    p.pageGapMode = mode
    this.update(p)
  }

  private setWide(mode: ReaderWideImageMode): void {
    const p = this.copyPreferences()
    p.wideImageMode = mode
    this.update(p)
  }

  private setVolumeBehavior(mode: ReaderVolumeKeyBehavior): void {
    const p = this.copyPreferences()
    p.volumeKeyBehavior = mode
    this.update(p)
  }

  private setToggle(key: string, value: boolean): void {
    const p = this.copyPreferences()
    if (key === 'progress') p.showProgressControls = value
    if (key === 'awake') p.keepScreenAwake = value
    if (key === 'tap') p.tapNavigationEnabled = value
    if (key === 'swipe') p.swipeNavigationEnabled = value
    if (key === 'zoom') p.zoomGesturesEnabled = value
    if (key === 'zones') p.showTapZones = value
    if (key === 'trim') p.trimPageMarginsEnabled = value
    if (key === 'volume') p.volumeKeyNavigationEnabled = value
    this.update(p)
  }

  private closeMenus(): void {
    this.menuKey = ''
  }

  @Builder
  private PageModeMenu() {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { this.setPageMode('single_page'); this.closeMenus() })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { this.setPageMode('double_page'); this.closeMenus() })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { this.setPageMode('continuous_scroll'); this.closeMenus() })
    }
  }

  @Builder
  private DirectionMenu() {
    Menu() {
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.LEFT_TO_RIGHT), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_and_square')), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.LEFT_TO_RIGHT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { this.setDirection(ReadingDirection.LEFT_TO_RIGHT); this.closeMenus() })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.RIGHT_TO_LEFT), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_left_and_square')), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { this.setDirection(ReadingDirection.RIGHT_TO_LEFT); this.closeMenus() })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.WEBTOON), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.scroll_vertical')), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.WEBTOON ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { this.setDirection(ReadingDirection.WEBTOON); this.closeMenus() })
    }
  }

  @Builder
  private BackgroundMenu() {
    Menu() {
      MenuItem({ content: getReaderBackgroundModeLabel('black'), symbolEndIcon: this.preferences.backgroundMode === 'black' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('black'); this.closeMenus() })
      MenuItem({ content: getReaderBackgroundModeLabel('paper'), symbolEndIcon: this.preferences.backgroundMode === 'paper' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('paper'); this.closeMenus() })
      MenuItem({ content: getReaderBackgroundModeLabel('light'), symbolEndIcon: this.preferences.backgroundMode === 'light' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setBackground('light'); this.closeMenus() })
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
      MenuItem({ content: getReaderTapZonePresetLabel('edge'), symbolEndIcon: this.preferences.tapZonePreset === 'edge' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('edge'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('wide_edges'), symbolEndIcon: this.preferences.tapZonePreset === 'wide_edges' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('wide_edges'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('right_left'), symbolEndIcon: this.preferences.tapZonePreset === 'right_left' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('right_left'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('l_shaped'), symbolEndIcon: this.preferences.tapZonePreset === 'l_shaped' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('l_shaped'); this.closeMenus() })
      MenuItem({ content: getReaderTapZonePresetLabel('kindle'), symbolEndIcon: this.preferences.tapZonePreset === 'kindle' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setTapZone('kindle'); this.closeMenus() })
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
  private VolumeBehaviorMenu() {
    Menu() {
      MenuItem({ content: getReaderVolumeKeyBehaviorLabel('up_previous_down_next'), symbolEndIcon: this.preferences.volumeKeyBehavior === 'up_previous_down_next' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setVolumeBehavior('up_previous_down_next'); this.closeMenus() })
      MenuItem({ content: getReaderVolumeKeyBehaviorLabel('up_next_down_previous'), symbolEndIcon: this.preferences.volumeKeyBehavior === 'up_next_down_previous' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.setVolumeBehavior('up_next_down_previous'); this.closeMenus() })
    }
  }

  @Builder
  private ReaderSettingsSheet() {
    Scroll() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        SectionHeader({ title: s('settings_row_reader_image_fit_title') })
        GroupedListSection() {
          Column() {
            ConciseListRow({ title: s('settings_row_reader_image_fit_title'), trailingText: getReaderImageFitModeLabel(this.preferences.imageFitMode), trailingDropdown: true, action: () => { this.menuKey = 'fit' } })
          }.bindMenu(this.menuKey === 'fit', this.ImageFitMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          Column() {
            ConciseListRow({ title: s('settings_row_reader_background_title'), trailingText: getReaderBackgroundModeLabel(this.preferences.backgroundMode), trailingDropdown: true, action: () => { this.menuKey = 'background' } })
          }.bindMenu(this.menuKey === 'background', this.BackgroundMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          Column() {
            ConciseListRow({ title: s('reader_control_mode'), trailingText: getReaderModeLabel(this.readerMode), trailingDropdown: true, action: () => { this.menuKey = 'mode' } })
          }.bindMenu(this.menuKey === 'mode', this.PageModeMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          Column() {
            ConciseListRow({ title: s('settings_row_reading_direction_title'), trailingText: getReadingDirectionLabel(this.preferences.readingDirection), trailingDropdown: true, action: () => { this.menuKey = 'direction' } })
          }.bindMenu(this.menuKey === 'direction', this.DirectionMenu, { onDisappear: () => { this.closeMenus() } })
        }
        SectionHeader({ title: s('settings_row_reader_tap_zone_preset_title') })
        GroupedListSection() {
          Column() {
            ConciseListRow({ title: s('settings_row_reader_tap_zone_preset_title'), trailingText: getReaderTapZonePresetLabel(this.preferences.tapZonePreset), trailingDropdown: true, action: () => { this.menuKey = 'tap-zone' } })
          }.bindMenu(this.menuKey === 'tap-zone', this.TapZoneMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          Column() {
            ConciseListRow({ title: s('settings_row_reader_tap_zone_invert_title'), trailingText: getReaderTapZoneInvertLabel(this.preferences.tapZoneInvert), trailingDropdown: true, action: () => { this.menuKey = 'tap-invert' } })
          }.bindMenu(this.menuKey === 'tap-invert', this.TapInvertMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_tap_navigation_title'), subtitle: s('settings_row_reader_tap_navigation_detail'), hasSwitch: true, checked: this.preferences.tapNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('tap', value) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_swipe_navigation_title'), subtitle: s('settings_row_reader_swipe_navigation_detail'), hasSwitch: true, checked: this.preferences.swipeNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('swipe', value) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_zoom_gestures_title'), subtitle: s('settings_row_reader_zoom_gestures_detail'), hasSwitch: true, checked: this.preferences.zoomGesturesEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('zoom', value) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_show_tap_zones_title'), subtitle: s('settings_row_reader_show_tap_zones_detail'), hasSwitch: true, checked: this.preferences.showTapZones, showChevron: false, switchAction: (value: boolean) => { this.setToggle('zones', value) } })
        }
        SectionHeader({ title: s('settings_row_reader_page_gap_title') })
        GroupedListSection() {
          Column() {
            ConciseListRow({ title: s('settings_row_reader_page_gap_title'), trailingText: getReaderPageGapModeLabel(this.preferences.pageGapMode), trailingDropdown: true, action: () => { this.menuKey = 'gap' } })
          }.bindMenu(this.menuKey === 'gap', this.GapMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          Column() {
            ConciseListRow({ title: s('settings_row_reader_wide_image_mode_title'), trailingText: getReaderWideImageModeLabel(this.preferences.wideImageMode), trailingDropdown: true, action: () => { this.menuKey = 'wide' } })
          }.bindMenu(this.menuKey === 'wide', this.WideMenu, { onDisappear: () => { this.closeMenus() } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_trim_page_margins_title'), subtitle: s('settings_row_reader_trim_page_margins_detail'), hasSwitch: true, checked: this.preferences.trimPageMarginsEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('trim', value) } })
        }
        SectionHeader({ title: s('settings_row_reader_progress_title') })
        GroupedListSection() {
          ConciseListRow({ title: s('settings_row_reader_progress_title'), subtitle: s('settings_row_reader_progress_detail'), hasSwitch: true, checked: this.preferences.showProgressControls, showChevron: false, switchAction: (value: boolean) => { this.setToggle('progress', value) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_keep_screen_awake_title'), subtitle: s('settings_row_reader_keep_screen_awake_detail'), hasSwitch: true, checked: this.preferences.keepScreenAwake, showChevron: false, switchAction: (value: boolean) => { this.setToggle('awake', value) } })
        }
        SectionHeader({ title: s('settings_row_reader_volume_key_navigation_title') })
        GroupedListSection() {
          ConciseListRow({ title: s('settings_row_reader_volume_key_navigation_title'), subtitle: s('settings_row_reader_volume_key_navigation_detail'), hasSwitch: true, checked: this.preferences.volumeKeyNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('volume', value) } })
          ListDivider()
          Column() {
            ConciseListRow({ title: s('settings_row_reader_volume_key_behavior_title'), trailingText: getReaderVolumeKeyBehaviorLabel(this.preferences.volumeKeyBehavior), trailingDropdown: true, action: () => { this.menuKey = 'volume-behavior' } })
          }.bindMenu(this.menuKey === 'volume-behavior', this.VolumeBehaviorMenu, { onDisappear: () => { this.closeMenus() } })
        }
        Blank().height(ThemeConstants.SPACE_XL)
      }
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_LG })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  @Builder
  private ModeMenu() {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.book')), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.SINGLE_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.book')), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.DUAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.scroll_vertical')), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.CONTINUOUS_SCROLL); this.modeShown = false })
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
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
        }
        .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.onCloseReader() })
        Blank().layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor([Color.White])
        }
        .width(44).height(44).backgroundColor(Color.Transparent)
        .onClick(() => { this.settingsShown = true })
        .bindSheet($$this.settingsShown, this.ReaderSettingsSheet, { detents: [SheetSize.MEDIUM, SheetSize.LARGE], showClose: false, onDisappear: () => { this.settingsShown = false } })
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2')).fontSize(22).fontColor([Color.White])
        }
        .width(44).height(44).backgroundColor(Color.Transparent)
        .accessibilityText(s('common_more_actions'))
        .onClick(() => { this.moreShown = true })
        .bindMenu(this.moreShown, this.MoreMenu, { placement: Placement.BottomRight, onDisappear: () => { this.moreShown = false } })
      }
      .width('100%').height(56).padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM }).alignItems(VerticalAlign.Center)
      Text(this.pageText()).fontSize(14).fontColor(Color.White).maxLines(1).hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height(this.topInset + 56).padding({ top: this.topInset }).backgroundColor('#CC000000').hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private BottomBar() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.preferences.showProgressControls) {
        Row({ space: 4 }) {
          Text(`${this.pageIndex + 1}`).fontSize(14).fontColor(Color.White).width(30).textAlign(TextAlign.Start)
          Slider({ value: this.pageIndex + 1, min: 1, max: Math.max(this.pageTotal, 1), step: 1, style: SliderStyle.InSet, reverse: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT })
            .layoutWeight(1).trackColor('#33FFFFFF').selectedColor(ThemeConstants.BRAND_PRIMARY)
            .onChange((value: number, mode: SliderChangeMode) => {
              const target = Math.max(0, Math.min(Math.round(value) - 1, Math.max(this.pageTotal - 1, 0)))
              if (this.readerMode === ReaderMode.CONTINUOUS_SCROLL) this.onSeekPage(target)
              else if (mode === SliderChangeMode.End) this.onSeekPage(target)
              else this.onPageChange(target)
            })
          Text(`${Math.max(this.pageTotal, 0)}`).fontSize(14).fontColor(Color.White).width(30).textAlign(TextAlign.End)
        }.width('100%').height(32)
      }
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.book')).fontSize(22).fontColor([this.readerMode === ReaderMode.DUAL_PAGE ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
          .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.pageTotal > 1).onClick(() => { this.onModeChange(this.readerMode === ReaderMode.DUAL_PAGE ? ReaderMode.SINGLE_PAGE : ReaderMode.DUAL_PAGE) })
        Blank().layoutWeight(1)
        Text(this.chapterText()).fontSize(13).fontColor(Color.White).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank().layoutWeight(1)
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
          Blank().layoutWeight(1).hitTestBehavior(HitTestMode.Transparent)
          this.BottomBar()
        }
        .width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
        this.TopBar()
      } else {
        Blank().width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
  }
}
