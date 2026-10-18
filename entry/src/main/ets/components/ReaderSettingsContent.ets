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

/** Host-owned settings UI shared by the legacy and optional reader surfaces. */
@ComponentV2
export struct ReaderSettingsContent {
  @Param readerMode: ReaderMode = ReaderMode.SINGLE_PAGE
  @Param preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Event onPreferencesChange: (preferences: ReaderPreferences) => void = (_preferences: ReaderPreferences) => {}
  @Event onClose: () => void = () => {}
  @Event onRevealTapZones: () => void = () => {}
  /**
   * RDR-005: true while this comic carries its own narrow mode/direction
   * override. The two affected rows advertise it and both menus offer 恢复默认,
   * so a per-book choice can never silently outlive the user's awareness of it.
   */
  @Param seriesOverrideActive: boolean = false
  @Event onResetSeriesOverride: () => void = () => {}

  private seriesOverrideBadge(label: string): string {
    return this.seriesOverrideActive ? `${label} · ${s('reader_series_override_badge')}` : label
  }

  private update(next: ReaderPreferences): void {
    this.onPreferencesChange(next)
  }

  private copyPreferences(): ReaderPreferences {
    const p = this.preferences
    return {
      readerImplementation: p.readerImplementation === 'legacy' ? 'legacy' : 'shared',
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
    this.onClose()
    this.onRevealTapZones()
  }

  private setTapInvert(mode: ReaderTapZoneInvert): void {
    const next = this.copyPreferences()
    next.tapZoneInvert = mode
    this.update(next)
    this.onClose()
    this.onRevealTapZones()
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
    if (this.preferences.imageScalingQuality === 'low') return s('reader_image_scaling_quality_low')
    if (this.preferences.imageScalingQuality === 'high') return s('reader_image_scaling_quality_high')
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

  private isWebtoonLayout(): boolean {
    return this.readerMode === ReaderMode.CONTINUOUS_SCROLL ||
      (this.preferences.readingDirection === ReadingDirection.WEBTOON && this.readerMode !== ReaderMode.VERTICAL_PAGE)
  }

  @Builder
  private PageModeMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('single_page') }) })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('double_page') }) })
      MenuItem({ content: getReaderModeLabel(ReaderMode.VERTICAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.VERTICAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('vertical_page') }) })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setPageMode('continuous_scroll') }) })
      if (this.seriesOverrideActive) {
        MenuItem({ content: s('reader_series_override_reset') }).onClick(() => { select(() => { this.onResetSeriesOverride() }) })
      }
    }
  }

  @Builder
  private DirectionMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.LEFT_TO_RIGHT), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.LEFT_TO_RIGHT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setDirection(ReadingDirection.LEFT_TO_RIGHT) }) })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.RIGHT_TO_LEFT), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setDirection(ReadingDirection.RIGHT_TO_LEFT) }) })
      MenuItem({ content: getReadingDirectionLabel(ReadingDirection.WEBTOON), symbolEndIcon: this.preferences.readingDirection === ReadingDirection.WEBTOON ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { select(() => { this.setDirection(ReadingDirection.WEBTOON) }) })
      if (this.seriesOverrideActive) {
        MenuItem({ content: s('reader_series_override_reset') }).onClick(() => { select(() => { this.onResetSeriesOverride() }) })
      }
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

  build() {
    KomaModalScaffold({
      title: s('settings_pane_reader_title'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      onClose: (): void => { this.onClose() },
    }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        SectionHeader({ title: s('settings_reader_group_layout') })
        GroupedListSection() {
          ConciseListRow({ title: s('reader_control_mode'), trailingText: this.seriesOverrideBadge(getReaderModeLabel(this.readerMode)), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PageModeMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reading_direction_title'), trailingText: this.seriesOverrideBadge(getReadingDirectionLabel(this.preferences.readingDirection)), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.DirectionMenu(select) } })
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
}
