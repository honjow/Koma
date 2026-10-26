import { common } from '@kit.AbilityKit'
import { ReaderSuperResolutionModelService } from '../model/ReaderSuperResolutionModelService'
import { ReaderSuperResolutionModelDefinition } from '../model/ReaderSuperResolutionModelRegistry'
import { readerSuperResolutionModelLabel } from '../model/ReaderSuperResolutionPresentation'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode, getReaderModeLabel } from '../model/ReaderSessionStore'
import {
  readerModeSelection,
  readerDirectionSelection,
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
  getReaderCropStrengthLabel,
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
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

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
  // Status never changes the menu contents or the settings row structure.
  @Param seriesOverrideActive: boolean = false
  @Param cropControlsAvailable: boolean = false
  @Param enhancementControlsAvailable: boolean = false
  @Local private enhancementModels: ReaderSuperResolutionModelDefinition[] = []
  @Local private installedEnhancementModels: string[] = []
  @Local private installingEnhancementModel: string = ''
  private settingsLifetime: number = 0
  private settingsActive: boolean = false

  aboutToAppear(): void {
    this.settingsActive = true
    const lifetime = ++this.settingsLifetime
    if (!this.enhancementControlsAvailable) return
    this.enhancementModels = ReaderSuperResolutionModelService.userAvailableDefinitions()
    void this.refreshEnhancementModels(lifetime)
  }

  aboutToDisappear(): void {
    this.settingsActive = false
    this.settingsLifetime += 1
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async refreshEnhancementModels(lifetime: number): Promise<void> {
    const installed = await ReaderSuperResolutionModelService.installedModels(this.context())
    if (this.settingsActive && this.settingsLifetime === lifetime) this.installedEnhancementModels = installed
  }

  private async selectEnhancementModel(model: string): Promise<void> {
    if (!this.settingsActive || this.installingEnhancementModel.length > 0) return
    if (model === 'none' || this.installedEnhancementModels.includes(model)) {
      const next = this.copyPreferences()
      next.superResolutionModel = model
      if (model === 'none') next.superResolutionEnabled = false
      this.update(next)
      return
    }
    // The menu explicitly says Download. Merely opening settings never starts a download.
    const lifetime = this.settingsLifetime
    const priorModel = this.preferences.superResolutionModel
    this.installingEnhancementModel = model
    try {
      await ReaderSuperResolutionModelService.install(this.context(), model)
      if (!this.settingsActive || this.settingsLifetime !== lifetime) return
      await this.refreshEnhancementModels(lifetime)
      if (!this.settingsActive || this.settingsLifetime !== lifetime ||
        this.preferences.superResolutionModel !== priorModel) return
      const next = this.copyPreferences()
      next.superResolutionModel = model
      // Selecting/downloading and enabling are deliberately separate user actions.
      this.update(next)
    } catch (_error) {
      if (this.settingsActive && this.settingsLifetime === lifetime) {
        this.getUIContext().getPromptAction().showToast({ message: s('settings_reader_super_resolution_model_download_failed') })
      }
    } finally {
      if (this.settingsActive && this.settingsLifetime === lifetime) this.installingEnhancementModel = ''
    }
  }

  private enhancementModelActionLabel(model: ReaderSuperResolutionModelDefinition): string {
    const title = readerSuperResolutionModelLabel(model.id)
    if (this.installedEnhancementModels.includes(model.id)) return title
    return `${title} · ${s('settings_reader_super_resolution_model_download')} ${(model.downloadBytes() / 1048576).toFixed(1)} MB`
  }

  @Event onResetSeriesOverride: () => void = () => {}

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
      cropStrength: p.cropStrength,
      superResolutionEnabled: p.superResolutionEnabled,
      superResolutionModel: p.superResolutionModel,
      superResolutionBackend: p.superResolutionBackend,
      superResolutionMaxHeight: p.superResolutionMaxHeight,
      wideImageMode: p.wideImageMode,
      volumeKeyNavigationEnabled: p.volumeKeyNavigationEnabled,
      volumeKeyBehavior: p.volumeKeyBehavior,
    }
  }

  private setPageMode(mode: ReaderPageMode): void {
    const next = this.copyPreferences()
    const choice = readerModeSelection({ pageMode: next.pageMode, readingDirection: next.readingDirection }, mode)
    next.pageMode = choice.pageMode
    next.readingDirection = choice.readingDirection
    this.update(next)
  }

  private setDirection(direction: ReadingDirection): void {
    const next = this.copyPreferences()
    const choice = readerDirectionSelection({ pageMode: next.pageMode, readingDirection: next.readingDirection }, direction)
    next.pageMode = choice.pageMode
    next.readingDirection = choice.readingDirection
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
  }

  private setTapInvert(mode: ReaderTapZoneInvert): void {
    const next = this.copyPreferences()
    next.tapZoneInvert = mode
    this.update(next)
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

  private setCropStrength(strength: string): void {
    const next = this.copyPreferences()
    next.cropStrength = strength
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
    if (key === 'trim-margins') next.trimPageMarginsEnabled = value
    if (key === 'super-resolution') next.superResolutionEnabled = value && this.installedEnhancementModels.includes(next.superResolutionModel)
    this.update(next)
  }

  private isHorizontalDirectionApplicable(): boolean {
    return this.readerMode === ReaderMode.SINGLE_PAGE || this.readerMode === ReaderMode.DUAL_PAGE
  }

  private effectiveDirectionLabel(): string {
    return this.isHorizontalDirectionApplicable() ? getReadingDirectionLabel(this.preferences.readingDirection) :
      s('reader_direction_effective_top_to_bottom')
  }

  private isWebtoonLayout(): boolean {
    return this.readerMode === ReaderMode.CONTINUOUS_SCROLL ||
      (this.preferences.readingDirection === ReadingDirection.WEBTOON && this.readerMode !== ReaderMode.VERTICAL_PAGE)
  }

  @Builder
  private CropStrengthMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['conservative', 'standard', 'strong'], (strength: string) => {
        MenuItem({ content: getReaderCropStrengthLabel(strength),
          symbolEndIcon: this.preferences.cropStrength === strength ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.setCropStrength(strength) }) })
      })
    }
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
  private EnhancementModelMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('settings_reader_super_resolution_model_not_selected'),
        symbolEndIcon: this.preferences.superResolutionModel === 'none' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { select(() => { void this.selectEnhancementModel('none') }) })
      ForEach(this.enhancementModels, (model: ReaderSuperResolutionModelDefinition) => {
        MenuItem({ content: this.enhancementModelActionLabel(model),
          symbolEndIcon: this.preferences.superResolutionModel === model.id ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { void this.selectEnhancementModel(model.id) }) })
      }, (model: ReaderSuperResolutionModelDefinition): string => model.id)
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
        GroupedListSection({ title: s('settings_reader_group_layout'), headerSpacing: ThemeConstants.SPACE_SM }) {
          ConciseListRow({ title: s('reader_control_mode'), trailingText: getReaderModeLabel(this.readerMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PageModeMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reading_direction_title'), trailingText: this.effectiveDirectionLabel(), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.isHorizontalDirectionApplicable(), dropdownMenuBuilder: (select: (action: () => void) => void) => { this.DirectionMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('reader_spread_layout_title'), trailingText: this.preferences.spreadLayoutMode === 'split' ? s('reader_spread_layout_split') : s('reader_spread_layout_joined'), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.readerMode === ReaderMode.DUAL_PAGE, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.SpreadLayoutMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('reader_column_mode_title'), trailingText: this.preferences.columnMode === 'even_left' ? s('reader_column_mode_even_left') : s('reader_column_mode_odd_left'), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.readerMode === ReaderMode.DUAL_PAGE, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ColumnModeMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('reader_page_turn_animation_title'), hasSwitch: true, checked: this.preferences.pageTurnAnimation, showChevron: false, isEnabled: this.readerMode !== ReaderMode.VERTICAL_PAGE && !this.isWebtoonLayout(), switchAction: (value: boolean) => { this.setToggle('page-animation', value) } })
          ListDivider()
          ConciseListRow({ title: s('reader_series_override_reset'), subtitle: s(this.seriesOverrideActive ? 'reader_series_override_different' : 'reader_series_override_inherited'), showChevron: false, isEnabled: this.seriesOverrideActive, action: () => { this.onResetSeriesOverride() } })
        }
        GroupedListSection({ title: s('settings_reader_group_tap_zones'), headerSpacing: ThemeConstants.SPACE_SM }) {
          ConciseListRow({ title: s('settings_row_reader_tap_zone_preset_title'), trailingText: getReaderTapZonePresetLabel(this.preferences.tapZonePreset), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.TapZoneMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_tap_zone_invert_title'), trailingText: getReaderTapZoneInvertLabel(this.preferences.tapZoneInvert), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.TapInvertMenu(select) } })
        }
        GroupedListSection({ title: s('settings_reader_group_display'), headerSpacing: ThemeConstants.SPACE_SM }) {
          ConciseListRow({ title: s('settings_row_reader_background_title'), trailingText: getReaderBackgroundModeLabel(this.preferences.backgroundMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.BackgroundMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('reader_image_scaling_quality_title'), trailingText: this.scalingQualityLabel(), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ScalingQualityMenu(select) } })
          ListDivider()
          if (this.cropControlsAvailable) {
            ConciseListRow({ title: s('settings_row_reader_trim_page_margins_title'), hasSwitch: true,
              checked: this.preferences.trimPageMarginsEnabled, showChevron: false,
              switchAction: (value: boolean) => { this.setToggle('trim-margins', value) } })
            ListDivider()
            ConciseListRow({ title: s('reader_crop_strength_title'), trailingText: getReaderCropStrengthLabel(this.preferences.cropStrength),
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.trimPageMarginsEnabled,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.CropStrengthMenu(select) } })
            ListDivider()
          }
          if (this.enhancementControlsAvailable) {
            ConciseListRow({ title: s('settings_reader_super_resolution'), hasSwitch: true,
              checked: this.preferences.superResolutionEnabled, showChevron: false,
              isEnabled: this.installedEnhancementModels.includes(this.preferences.superResolutionModel),
              switchAction: (value: boolean) => { this.setToggle('super-resolution', value) } })
            ListDivider()
            ConciseListRow({ title: s('settings_reader_super_resolution_model'),
              trailingText: this.installingEnhancementModel.length > 0
                ? s('settings_reader_super_resolution_model_downloading_short')
                : readerSuperResolutionModelLabel(this.preferences.superResolutionModel),
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.installingEnhancementModel.length === 0,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.EnhancementModelMenu(select) } })
            ListDivider()
          }
          ConciseListRow({ title: s('reader_show_page_number_title'), hasSwitch: true, checked: this.preferences.showPageNumber, showChevron: false, switchAction: (value: boolean) => { this.setToggle('page-number', value) } })
          ListDivider()
          ConciseListRow({ title: s('reader_fullscreen_title'), hasSwitch: true, checked: this.preferences.fullscreen, showChevron: false, switchAction: (value: boolean) => { this.setToggle('fullscreen', value) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_keep_screen_awake_title'), hasSwitch: true, checked: this.preferences.keepScreenAwake, showChevron: false, switchAction: (value: boolean) => { this.setToggle('awake', value) } })
        }
        GroupedListSection({ title: s('settings_reader_group_navigation'), headerSpacing: ThemeConstants.SPACE_SM }) {
          ConciseListRow({ title: s('reader_auto_page_title'), trailingText: `${this.preferences.autoPageSeconds}s`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutoPageMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('reader_preload_pages_title'), trailingText: `${this.preferences.preloadPages}`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PreloadMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_volume_key_navigation_title'), hasSwitch: true, checked: this.preferences.volumeKeyNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('volume', value) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_volume_key_behavior_title'), trailingText: getReaderVolumeKeyBehaviorLabel(this.preferences.volumeKeyBehavior), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.volumeKeyNavigationEnabled, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.VolumeKeyBehaviorMenu(select) } })
        }
        GroupedListSection({ title: s('settings_row_reader_page_gap_title'), headerSpacing: ThemeConstants.SPACE_SM }) {
          ConciseListRow({ title: s('settings_row_reader_page_gap_title'), trailingText: getReaderPageGapModeLabel(this.preferences.pageGapMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.GapMenu(select) } })
          ListDivider()
          ConciseListRow({ title: s('settings_row_reader_wide_image_mode_title'), trailingText: getReaderWideImageModeLabel(this.preferences.wideImageMode), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.isWebtoonLayout(), dropdownMenuBuilder: (select: (action: () => void) => void) => { this.WideMenu(select) } })
        }
        Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_LG })
    }
  }
}
