import { common } from '@kit.AbilityKit'
import { komaToastOptions } from '../theme/KomaPopupOptions'
import { ReaderSettingOption } from './ReaderSettingOption'
import { HdsNavigationMenuItemOptions, TextStyleMode } from '@kit.UIDesignKit'
import { ImagePluginsPage } from '../pages/ImagePluginsPage'
import { SourceSubscriptionsPage } from '../pages/SourceSubscriptionsPage'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { ImagePluginsRequest } from '../model/ImagePluginManagement'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ReaderDisplaySettingsContent } from './ReaderDisplaySettingsContent'
import { ReaderDisplaySettings } from '../model/ReaderDisplaySettings'
import { ReaderImageSettingsContent } from './ReaderImageSettingsContent'
import { supportsReaderSmartKeyNavigation } from '../model/ReaderSmartKeyNavigation'
import { ReaderDirectionMenuItems } from './ReaderDirectionMenu'
import { ReaderDirectionChoice, readerControlDirection, readerControlDirectionSelection, readerControlDirectionLabelKey } from '../model/ReaderControlChoices'
import { ReaderSuperResolutionModelsContent } from './ReaderSuperResolutionModelsContent'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode } from '../model/ReaderSessionStore'
import {
  readerModeSelection,
  readerDirectionSelection,
  ReaderBackgroundMode,
  ReaderColumnMode,
  ReaderImageScalingQuality,
  ReaderPageGapMode,
  ReaderPageMode,
  ReaderScreenOrientation,
  getReaderPageModeLabel,
  getReaderScreenOrientationLabel,
  ReaderPreferences,
  ReaderPreferencesStore,
  ReaderSpreadLayoutMode,
  ReaderTapZoneInvert,
  ReaderTapZonePreset,
  ReaderVolumeKeyBehavior,
  ReaderWideImageMode,
  DEFAULT_READER_PREFERENCES,
  READER_DOUBLE_TAP_INTERVALS,
  getReaderBackgroundModeLabel,
  getReaderPageGapModeLabel,
  getReaderTapZoneInvertLabel,
  getReaderTapZonePresetLabel,
  getReaderWideImageModeLabel,
  getReadingDirectionLabel,
} from '../model/ReaderPreferencesStore'
import { ReadingDirection } from '../model/ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold, komaModalSheetOptions, KOMA_MODAL_TABS_HEADER_HEIGHT } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

const LAYOUT_SETTINGS: string[] = [
  'reader_control_mode',
  'settings_row_reading_direction_title',
  'reader_spread_layout_title',
  'reader_column_mode_title',
  'reader_page_turn_animation_title',
]

const TAP_ZONES_SETTINGS: string[] = [
  'settings_row_reader_tap_zone_preset_title',
  'settings_row_reader_tap_zone_invert_title',
  'reader_double_tap_zoom_title',
  'reader_double_tap_interval_title',
]

const PAGE_GAP_SETTINGS: string[] = [
  'settings_row_reader_page_gap_title',
  'settings_row_reader_wide_image_mode_title',
]

const DISPLAY_SETTINGS: string[] = [
  'reader_screen_orientation_title',
  'settings_row_reader_background_title',
  'reader_image_scaling_quality_title',
  'reader_show_page_number_title',
  'reader_fullscreen_title',
  'settings_row_reader_keep_screen_awake_title',
]

const NAVIGATION_SETTINGS: string[] = [
  'reader_auto_page_title',
  'reader_preload_pages_title',
  'settings_row_reader_eye_gaze_page_turn_title',
  'settings_row_reader_volume_key_navigation_title',
  'settings_row_reader_volume_key_behavior_title',
]

function s(key: string): string {
  return AppStrings.get(key)
}

/** Host-owned reader settings UI. */
@ComponentV2
export struct ReaderSettingsContent {
  // The tab bodies are declared here, outside the scaffold's builder scope.
  @Provider('koma.modal.groupedCards') private modalGroupedCards: boolean = true
  @Param readerMode: ReaderMode = ReaderMode.SINGLE_PAGE
  @Param preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Event onPreferencesChange: (preferences: ReaderPreferences) => void = (_preferences: ReaderPreferences) => {}
  @Event onClose: () => void = () => {}
  @Event onRevealTapZones: () => void = () => {}
  // Status never changes the menu contents or the settings row structure.
  @Param seriesOverrideActive: boolean = false
  @Param bookSettingsAvailable: boolean = false
  @Param cropControlsAvailable: boolean = false
  @Param enhancementControlsAvailable: boolean = false
  // Reader owns immediate reading controls. Provider/account configuration belongs
  // to the global translation settings route, not a form reachable only in this sheet.
  @Param selectedTab: number = 0
  @Event onTabSelect: (index: number) => void = (_index: number) => {}
  @Local private smartKeyAvailable: boolean = false
  @Local private tabScrolled: boolean = false
  @Local private tabHeaderHeight: number = KOMA_MODAL_TABS_HEADER_HEIGHT
  @Event onFilterSheetHeightChange: (height: number) => void = () => {}
  private filterContentHeight: number = 0
  @Event onFilterPreviewChange: (active: boolean) => void = () => {}
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()
  private modeScroller: Scroller = new Scroller()
  private generalScroller: Scroller = new Scroller()
  private filterScroller: Scroller = new Scroller()
  private favoriteScroller: Scroller = new Scroller()
  @Local private favoriteKeys: string[] = []
  private favoriteStore: ReaderPreferencesStore | null = null
  private favoriteSheetActive: boolean = false

  aboutToAppear(): void {
    if (this.bookSettingsAvailable) {
      this.favoriteSheetActive = true
      const store = new ReaderPreferencesStore(this.getUIContext().getHostContext() as common.UIAbilityContext)
      this.favoriteStore = store
      void store.favoriteSettingKeys().then((keys: string[]): void => {
        if (this.favoriteSheetActive) this.favoriteKeys = keys
      }).catch((): void => {})
    }
    void supportsReaderSmartKeyNavigation().then((available: boolean): void => { this.smartKeyAvailable = available })
  }

  aboutToDisappear(): void {
    this.favoriteSheetActive = false
    this.onFilterPreviewChange(false)
  }

  private selectTab(index: number): void {
    this.onTabSelect(index)
    const scroller = index === 0 ? this.modeScroller : index === 1 ? this.generalScroller :
      index === 2 ? this.filterScroller : this.favoriteScroller
    this.tabScrolled = scroller.currentOffset().yOffset > 0
    this.publishFilterSheetHeight(index)
    this.onFilterPreviewChange(index === 2)
  }
  private publishFilterSheetHeight(index: number = this.selectedTab): void {
    const height = index === 2 && this.filterContentHeight > 0 ?
      Math.ceil(this.tabHeaderHeight + this.filterContentHeight) : 0
    this.onFilterSheetHeightChange(height)
  }

  @Local private modelManagementShown: boolean = false
  @Local private imagePluginsShown: boolean = false
  @Local private pluginSubscriptionsShown: boolean = false
  @Local private modelsRevision: number = 0
  private pluginSubscriptionsChrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()

  @Event onResetSeriesOverride: () => void = () => {}
  @Event onEnhancementModelsChanged: () => void = () => {}

  private update(next: ReaderPreferences): void {
    this.onPreferencesChange(next)
  }

  private copyPreferences(): ReaderPreferences {
    const p = this.preferences
    return {
      readerImplementation: 'shared',
      pageMode: p.pageMode,
      readingDirection: p.readingDirection,
      themeMode: p.themeMode,
      backgroundMode: p.backgroundMode,
      showProgressControls: p.showProgressControls,
      keepScreenAwake: p.keepScreenAwake,
      fullscreen: p.fullscreen,
      screenOrientation: p.screenOrientation,
      imageFitMode: p.imageFitMode,
      imageScalingQuality: p.imageScalingQuality,
      showPageNumber: p.showPageNumber,
      pageTurnAnimation: p.pageTurnAnimation,
      doubleTapZoomEnabled: p.doubleTapZoomEnabled,
      doubleTapIntervalMs: p.doubleTapIntervalMs,
      autoPageSeconds: p.autoPageSeconds,
      preloadPages: p.preloadPages,
      preloadWifiOnly: p.preloadWifiOnly,
      displaySettings: p.displaySettings,
      spreadLayoutMode: p.spreadLayoutMode,
      columnMode: p.columnMode,
      tapZonePreset: p.tapZonePreset,
      tapZoneInvert: p.tapZoneInvert,
      pageGapMode: p.pageGapMode,
      bannerFilter: p.bannerFilter, bannerFilterOverride: p.bannerFilterOverride,
      trimPageMarginsEnabled: p.trimPageMarginsEnabled,
      cropStrength: p.cropStrength,
      superResolutionEnabled: p.superResolutionEnabled,
      superResolutionModel: p.superResolutionModel,
      superResolutionBackend: p.superResolutionBackend,
      superResolutionMaxHeight: p.superResolutionMaxHeight,
      wideImageMode: p.wideImageMode,
      volumeKeyNavigationEnabled: p.volumeKeyNavigationEnabled,
      eyeGazePageTurnEnabled: p.eyeGazePageTurnEnabled,
      smartKeyPageTurnEnabled: p.smartKeyPageTurnEnabled,
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

  private setReadingMethod(direction: ReaderDirectionChoice): void {
    const next = this.copyPreferences()
    const choice = readerControlDirectionSelection({ pageMode: next.pageMode, readingDirection: next.readingDirection }, direction)
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

  private setDoubleTapInterval(interval: number): void {
    const next = this.copyPreferences()
    next.doubleTapIntervalMs = interval
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
    if (key === 'double-tap-zoom') next.doubleTapZoomEnabled = value
    if (key === 'awake') next.keepScreenAwake = value
    if (key === 'volume') next.volumeKeyNavigationEnabled = value
    if (key === 'eye-gaze') next.eyeGazePageTurnEnabled = value
    if (key === 'smart-key') next.smartKeyPageTurnEnabled = value
    if (key === 'trim-margins') next.trimPageMarginsEnabled = value
    this.update(next)
  }

  private isHorizontalDirectionApplicable(): boolean {
    return this.readerMode === ReaderMode.SINGLE_PAGE || this.readerMode === ReaderMode.DUAL_PAGE
  }

  private effectiveDirectionLabel(): string {
    return s(readerControlDirectionLabelKey(readerControlDirection({ pageMode: this.preferences.pageMode, readingDirection: this.preferences.readingDirection })))
  }

  private isWebtoonLayout(): boolean {
    return this.readerMode === ReaderMode.CONTINUOUS_SCROLL ||
      (this.preferences.readingDirection === ReadingDirection.WEBTOON && this.readerMode !== ReaderMode.VERTICAL_PAGE)
  }

  @Builder
  private PageModeMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['single_page', 'double_page', 'auto_page'] as ReaderPageMode[], (mode: ReaderPageMode) => {
        MenuItem({ content: getReaderPageModeLabel(mode),
          symbolEndIcon: this.selectedPageMode() === mode ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick((): void => { select((): void => { this.setPageMode(mode) }) })
      }, (mode: ReaderPageMode): string => mode)
    }
  }

  private selectedPageMode(): ReaderPageMode {
    if (this.isWebtoonLayout()) return 'single_page'
    const mode = this.preferences.pageMode
    return mode === 'auto_page' || mode === 'double_page' ? mode : 'single_page'
  }

  @Builder
  private ScreenOrientationMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['system', 'portrait', 'landscape'] as ReaderScreenOrientation[], (orientation: ReaderScreenOrientation) => {
        MenuItem({ content: getReaderScreenOrientationLabel(orientation),
          symbolEndIcon: this.preferences.screenOrientation === orientation ?
            new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick((): void => { select((): void => {
            const next = this.copyPreferences()
            next.screenOrientation = orientation
            this.update(next)
          }) })
      }, (orientation: ReaderScreenOrientation): string => orientation)
    }
  }

  @Builder
  private DirectionMenu(select: (action: () => void) => void) {
    Menu() {
      ReaderDirectionMenuItems(readerControlDirection({ pageMode: this.preferences.pageMode, readingDirection: this.preferences.readingDirection }), (direction: ReaderDirectionChoice): void => {
        select(() => { this.setReadingMethod(direction) })
      })
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
  private DoubleTapIntervalMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(READER_DOUBLE_TAP_INTERVALS, (interval: number) => {
        MenuItem({ content: `${interval} ms`, symbolEndIcon: this.preferences.doubleTapIntervalMs === interval ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.setDoubleTapInterval(interval) }) })
      }, (interval: number) => `${interval}`)
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
  private ModelManagementSheet() {
    KomaModalScaffold({ title: s('settings_reader_super_resolution_models'),
      onClose: (): void => { this.modelManagementShown = false } }) {
      ReaderSuperResolutionModelsContent({ inModal: true, preferences: this.preferences,
        manageFilesOnly: this.bookSettingsAvailable,
        onPreferencesChange: (next: ReaderPreferences): void => { this.update(next) } })
    }
  }

  private pluginRequest(): ImagePluginsRequest {
    return new ImagePluginsRequest(this.preferences, true, (next: ReaderPreferences): void => {
      // The reading sheet stays mounted; only this book's plugin override is
      // owned by the child editor, not a captured snapshot of all preferences.
      const current = this.copyPreferences()
      current.bannerFilterOverride = next.bannerFilterOverride
      this.update(current)
    })
  }

  private pluginActions(): HdsNavigationMenuItemOptions[] {
    return [{ content: { label: s('source_pkg_index_url_heading'), type: TextStyleMode.NORMAL,
      action: (): void => { this.pluginSubscriptionsShown = true } } }]
  }

  @Builder
  private ImagePluginsSheet() {
    Stack() {
    KomaModalScaffold({ title: s('image_plugins_title'), contentOwnsScrolling: true,
      additionalActions: this.pluginActions(), onClose: (): void => { this.imagePluginsShown = false } }) {
      ImagePluginsPage({ request: this.pluginRequest(), embedded: true })
    }
    Row().width(1).height(1).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.pluginSubscriptionsShown, this.PluginSubscriptionsSheet, komaModalSheetOptions({ height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE] }))
    }.width('100%').height('100%')
  }

  private subscriptionActions(): HdsNavigationMenuItemOptions[] {
    return [{ content: { label: s('source_pkg_add_subscription'), type: TextStyleMode.NORMAL,
      action: (): void => { this.pluginSubscriptionsChrome.request('addSubscription') } } }]
  }

  @Builder
  private PluginSubscriptionsSheet() {
    KomaModalScaffold({ title: s('source_pkg_index_url_heading'), contentOwnsScrolling: true,
      additionalActions: this.subscriptionActions(), onClose: (): void => { this.pluginSubscriptionsShown = false } }) {
      SourceSubscriptionsPage({ chrome: this.pluginSubscriptionsChrome, embedded: true })
    }
  }

  private navigationSettingKeys(): string[] {
    return this.smartKeyAvailable ? NAVIGATION_SETTINGS.concat(['settings_row_reader_smart_key_title']) : NAVIGATION_SETTINGS
  }

  private toggleFavorite(key: string): void {
    void this.favoriteStore?.toggleFavoriteSetting(key).then((keys: string[]): void => {
      if (!this.favoriteSheetActive) return
      this.favoriteKeys = keys
      this.getUIContext().getPromptAction().showToast(komaToastOptions({
        message: s(keys.includes(key) ? 'reader_setting_favorite_added' : 'reader_setting_favorite_removed'),
      }))
    }).catch((): void => {
      if (this.favoriteSheetActive) this.getUIContext().getPromptAction().showToast(komaToastOptions({
        message: s('reader_setting_favorite_save_failed'),
      }))
    })
  }

  private shownSettingKeys(keys: string[], favoritesOnly: boolean): string[] {
    return favoritesOnly ? keys.filter((key: string): boolean => this.favoriteKeys.includes(key)) : keys
  }

  @Builder
  private PreferenceSection(title: string, keys: string[], favoritesOnly: boolean = false) {
    if (this.shownSettingKeys(keys, favoritesOnly).length > 0) {
      GroupedListSection({ title: s(title), headerSpacing: ThemeConstants.SPACE_SM }) {
        ForEach(this.shownSettingKeys(keys, favoritesOnly), (key: string, index: number) => {
          if (index > 0) {
            ListDivider()
          }
          ReaderSettingOption({ settingKey: key,
            onFavorite: this.bookSettingsAvailable ? (setting: string): void => { this.toggleFavorite(setting) } : undefined }) {
            this.PreferenceRow(key)
          }
        }, (key: string, index: number): string => key + ':' + (index === 0 ? 'first' : 'rest'))
      }
    }
  }

  @Builder
  private PreferenceRow(key: string) {
    if (key === 'reader_control_mode') {
      ConciseListRow({ title: s('reader_control_mode'), trailingText: getReaderPageModeLabel(this.selectedPageMode()), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.isWebtoonLayout(), dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PageModeMenu(select) } })
    } else if (key === 'settings_row_reading_direction_title') {
      ConciseListRow({ title: s('settings_row_reading_direction_title'), trailingText: this.effectiveDirectionLabel(), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.DirectionMenu(select) } })
    } else if (key === 'reader_spread_layout_title') {
      ConciseListRow({ title: s('reader_spread_layout_title'), trailingText: this.preferences.spreadLayoutMode === 'split' ? s('reader_spread_layout_split') : s('reader_spread_layout_joined'), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.pageMode === 'auto_page' || this.readerMode === ReaderMode.DUAL_PAGE, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.SpreadLayoutMenu(select) } })
    } else if (key === 'reader_column_mode_title') {
      ConciseListRow({ title: s('reader_column_mode_title'), trailingText: this.preferences.columnMode === 'even_left' ? s('reader_column_mode_even_left') : s('reader_column_mode_odd_left'), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.pageMode === 'auto_page' || this.readerMode === ReaderMode.DUAL_PAGE, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ColumnModeMenu(select) } })
    } else if (key === 'reader_page_turn_animation_title') {
      ConciseListRow({ title: s('reader_page_turn_animation_title'), hasSwitch: true, checked: this.preferences.pageTurnAnimation, showChevron: false, isEnabled: this.readerMode !== ReaderMode.VERTICAL_PAGE, switchAction: (value: boolean) => { this.setToggle('page-animation', value) } })
    } else if (key === 'settings_row_reader_tap_zone_preset_title') {
      ConciseListRow({ title: s('settings_row_reader_tap_zone_preset_title'), trailingText: getReaderTapZonePresetLabel(this.preferences.tapZonePreset), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.TapZoneMenu(select) } })
    } else if (key === 'settings_row_reader_tap_zone_invert_title') {
      ConciseListRow({ title: s('settings_row_reader_tap_zone_invert_title'), trailingText: getReaderTapZoneInvertLabel(this.preferences.tapZoneInvert), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.TapInvertMenu(select) } })
    } else if (key === 'reader_double_tap_zoom_title') {
      ConciseListRow({ title: s('reader_double_tap_zoom_title'), hasSwitch: true, checked: this.preferences.doubleTapZoomEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('double-tap-zoom', value) } })
    } else if (key === 'reader_double_tap_interval_title') {
      ConciseListRow({ title: s('reader_double_tap_interval_title'), trailingText: `${this.preferences.doubleTapIntervalMs} ms`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.DoubleTapIntervalMenu(select) } })
    } else if (key === 'settings_row_reader_page_gap_title') {
      ConciseListRow({ title: s('settings_row_reader_page_gap_title'), trailingText: getReaderPageGapModeLabel(this.preferences.pageGapMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.GapMenu(select) } })
    } else if (key === 'settings_row_reader_wide_image_mode_title') {
      ConciseListRow({ title: s('settings_row_reader_wide_image_mode_title'), trailingText: getReaderWideImageModeLabel(this.preferences.wideImageMode), trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.isWebtoonLayout(), dropdownMenuBuilder: (select: (action: () => void) => void) => { this.WideMenu(select) } })
    } else if (key === 'reader_screen_orientation_title') {
      ConciseListRow({ title: s('reader_screen_orientation_title'),
      trailingText: getReaderScreenOrientationLabel(this.preferences.screenOrientation), trailingDropdown: true,
      dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => {
      this.ScreenOrientationMenu(select)
      } })
    } else if (key === 'settings_row_reader_background_title') {
      ConciseListRow({ title: s('settings_row_reader_background_title'), trailingText: getReaderBackgroundModeLabel(this.preferences.backgroundMode), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.BackgroundMenu(select) } })
    } else if (key === 'reader_image_scaling_quality_title') {
      ConciseListRow({ title: s('reader_image_scaling_quality_title'), trailingText: this.scalingQualityLabel(), trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ScalingQualityMenu(select) } })
    } else if (key === 'reader_show_page_number_title') {
      ConciseListRow({ title: s('reader_show_page_number_title'), hasSwitch: true, checked: this.preferences.showPageNumber, showChevron: false, switchAction: (value: boolean) => { this.setToggle('page-number', value) } })
    } else if (key === 'reader_fullscreen_title') {
      ConciseListRow({ title: s('reader_fullscreen_title'), hasSwitch: true, checked: this.preferences.fullscreen, showChevron: false, switchAction: (value: boolean) => { this.setToggle('fullscreen', value) } })
    } else if (key === 'settings_row_reader_keep_screen_awake_title') {
      ConciseListRow({ title: s('settings_row_reader_keep_screen_awake_title'), hasSwitch: true, checked: this.preferences.keepScreenAwake, showChevron: false, switchAction: (value: boolean) => { this.setToggle('awake', value) } })
    } else if (key === 'reader_auto_page_title') {
      ConciseListRow({ title: s('reader_auto_page_title'), trailingText: `${this.preferences.autoPageSeconds}s`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutoPageMenu(select) } })
    } else if (key === 'reader_preload_pages_title') {
      ConciseListRow({ title: s('reader_preload_pages_title'), trailingText: `${this.preferences.preloadPages}`, trailingDropdown: true, dropdownMenuEnabled: true, dropdownMenuBuilder: (select: (action: () => void) => void) => { this.PreloadMenu(select) } })
    } else if (key === 'settings_row_reader_eye_gaze_page_turn_title') {
      ConciseListRow({ title: s('settings_row_reader_eye_gaze_page_turn_title'), subtitle: s('settings_row_reader_eye_gaze_page_turn_detail'), hasSwitch: true, checked: this.preferences.eyeGazePageTurnEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('eye-gaze', value) } })
    } else if (key === 'settings_row_reader_volume_key_navigation_title') {
      ConciseListRow({ title: s('settings_row_reader_volume_key_navigation_title'), hasSwitch: true, checked: this.preferences.volumeKeyNavigationEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('volume', value) } })
    } else if (key === 'settings_row_reader_volume_key_behavior_title') {
      ConciseListRow({ title: s('settings_row_reader_volume_key_behavior_title'), hasSwitch: true, checked: this.preferences.volumeKeyBehavior === 'up_next_down_previous', showChevron: false, isEnabled: this.preferences.volumeKeyNavigationEnabled, switchAction: (value: boolean) => { this.setVolumeKeyBehavior(value ? 'up_next_down_previous' : 'up_previous_down_next') } })
    } else if (key === 'settings_row_reader_smart_key_title') {
      ConciseListRow({ title: s('settings_row_reader_smart_key_title'), subtitle: s('settings_row_reader_smart_key_detail'), hasSwitch: true, checked: this.preferences.smartKeyPageTurnEnabled, showChevron: false, switchAction: (value: boolean) => { this.setToggle('smart-key', value) } })
    }
  }

  @Builder
  private ImageSettings(category: 'crop' | 'enhancement' | 'plugins', favoritesOnly: boolean = false) {
    ReaderImageSettingsContent({ preferences: this.preferences, showPlugins: category === 'plugins',
      bookBannerOptions: category === 'plugins', cropControlsAvailable: category === 'crop' && this.cropControlsAvailable,
      enhancementControlsAvailable: category === 'enhancement' && this.enhancementControlsAvailable,
      trackModelChangesOnlyOnUserAction: this.bookSettingsAvailable, modelsRevision: this.modelsRevision,
      favoriteKeys: favoritesOnly ? this.favoriteKeys : undefined,
      onFavorite: this.bookSettingsAvailable ? (setting: string): void => { this.toggleFavorite(setting) } : undefined,
      onPreferencesChange: (next: ReaderPreferences) => { this.update(next) },
      onOpenModels: (): void => { this.modelManagementShown = true },
      onOpenPlugins: (): void => { this.imagePluginsShown = true },
    })
  }

  @Builder
  private DisplaySettings(favoritesOnly: boolean = false) {
    ReaderDisplaySettingsContent({ embedded: true, settings: this.preferences.displaySettings,
      favoriteKeys: favoritesOnly ? this.favoriteKeys : undefined,
      previewActive: this.selectedTab === (favoritesOnly ? 3 : 2),
      onFavorite: this.bookSettingsAvailable ? (setting: string): void => { this.toggleFavorite(setting) } : undefined,
      onChange: (settings: ReaderDisplaySettings): void => {
        const next = this.copyPreferences()
        next.displaySettings = settings
        this.update(next)
      },
    })
  }

  @Builder
  private FavoriteSettings() {
    if (this.favoriteKeys.length === 0) {
      Text(s('reader_settings_favorites_empty'))
        .width('100%').textAlign(TextAlign.Center).fontColor(ThemeConstants.TEXT_SECONDARY)
        .padding({ top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    } else {
      this.PreferenceSection('settings_reader_group_layout', LAYOUT_SETTINGS, true)
      this.ImageSettings('crop', true)
      this.PreferenceSection('settings_reader_group_tap_zones', TAP_ZONES_SETTINGS, true)
      this.PreferenceSection('settings_row_reader_page_gap_title', PAGE_GAP_SETTINGS, true)
      this.ImageSettings('enhancement', true)
      this.PreferenceSection('settings_reader_group_display', DISPLAY_SETTINGS, true)
      this.PreferenceSection('settings_reader_group_navigation', this.navigationSettingKeys(), true)
      this.ImageSettings('plugins', true)
      this.DisplaySettings(true)
    }
    GroupedListSection() {
      ConciseListRow({ title: s('reader_series_override_reset'),
        subtitle: s(this.seriesOverrideActive ? 'reader_series_override_different' : 'reader_series_override_inherited'),
        subtitleMaxLines: 2, showChevron: false,
        action: (): void => {
          if (this.seriesOverrideActive) this.onResetSeriesOverride()
        } })
        .id('reader-use-global-settings')
    }
  }

  @Builder
  private TabContent(index: number, scroller: Scroller) {
    List({ scroller: scroller }) {
      ListItem() { Row().height(this.tabHeaderHeight).width('100%') }
      ListItem() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          if (index === 0) {
            this.PreferenceSection('settings_reader_group_layout', LAYOUT_SETTINGS)
            this.ImageSettings('crop')
            this.PreferenceSection('settings_reader_group_tap_zones', TAP_ZONES_SETTINGS)
            this.PreferenceSection('settings_row_reader_page_gap_title', PAGE_GAP_SETTINGS)
          } else if (index === 1) {
            this.ImageSettings('enhancement')
            this.PreferenceSection('settings_reader_group_display', DISPLAY_SETTINGS)
            this.PreferenceSection('settings_reader_group_navigation', this.navigationSettingKeys())
            this.ImageSettings('plugins')
          } else if (index === 2) {
            this.DisplaySettings()
          } else {
            this.FavoriteSettings()
          }
          if (index !== 2) {
            Blank().height(this.layout.bottomAvoidHeight + ThemeConstants.SPACE_MD)
          }
        }.width('100%').padding({
          top: ThemeConstants.SPACE_SM,
          // The measured filter list needs only one bottom inset.
          bottom: index === 2 ? this.layout.bottomAvoidHeight + ThemeConstants.SPACE_SM : ThemeConstants.SPACE_LG,
        })
          .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
            const height = Number(size.height)
            if (index === 2 && height > 0 && height !== this.filterContentHeight) {
              this.filterContentHeight = height
              this.publishFilterSheetHeight()
            }
          })
      }
    }.width('100%').height('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .onDidScroll(() => {
        if (this.selectedTab === index) {
          this.tabScrolled = scroller.currentOffset().yOffset > 0
        }
      })
      // Retain the hidden list's geometry, as in SourcePackageManagerPage.
      // Collapsing to None lets the segmented control's native animation scale
      // the next page from zero bounds, also disturbing retained scroll state.
      .visibility(this.selectedTab === index ? Visibility.Visible : Visibility.Hidden)
  }

  private tabLabels(): string[] {
    const labels = [s('reader_settings_tab_mode'), s('reader_settings_tab_general'), s('reader_settings_tab_filters')]
    return this.bookSettingsAvailable ? labels.concat([s('reader_settings_tab_favorites')]) : labels
  }

  build() {
    // Tabs retain their own scroll position; child managers remain independent
    // native sheets so dismissing one returns to this same selected tab.
    Stack() {
    KomaModalScaffold({ contentOwnsScrolling: true,
      tabLabels: this.tabLabels(),
      tabScrolled: this.tabScrolled,
      selectedTab: this.selectedTab, onTabSelect: (index: number): void => { this.selectTab(index) },
      onTabHeaderHeightChange: (height: number): void => {
        this.tabHeaderHeight = height
        this.publishFilterSheetHeight()
      },
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
    }) {
      Stack() {
        this.TabContent(0, this.modeScroller)
        this.TabContent(1, this.generalScroller)
        this.TabContent(2, this.filterScroller)
        if (this.bookSettingsAvailable) {
          this.TabContent(3, this.favoriteScroller)
        }
      }.width('100%').height('100%')
    }
    Row().width(1).height(1).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.modelManagementShown, this.ModelManagementSheet, komaModalSheetOptions({ height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        onDisappear: (): void => { this.modelsRevision += 1; this.onEnhancementModelsChanged() } }))
    Row().width(1).height(1).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.imagePluginsShown, this.ImagePluginsSheet, komaModalSheetOptions({ height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE] }))
    }.width('100%').height('100%')
  }
}
