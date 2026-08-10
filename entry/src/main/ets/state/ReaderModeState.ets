import { AppStorageV2 } from '@kit.ArkUI'

/**
 * The process-wide reader interaction state.
 *
 * This is intentionally separate from `ReaderPreferencesStore`: the store is
 * the durable boundary, while this class is the one runtime owner observed by
 * a live Reader and the Settings destination.  It mirrors NextE's
 * `ReadModeState` without putting page-pair parity here; `columnMode` is a
 * chapter-progress concern and is supplied by the active Reader session.
 */
export class ReaderModeSnapshot {
  pageMode: string
  readingDirection: string
  themeMode: string
  backgroundMode: string
  showProgressControls: boolean
  keepScreenAwake: boolean
  fullscreen: boolean
  imageFitMode: string
  imageScalingQuality: string
  showPageNumber: boolean
  pageTurnAnimation: boolean
  autoPageSeconds: number
  preloadPages: number
  spreadLayoutMode: string
  tapZonePreset: string
  tapZoneInvert: string
  pageGapMode: string
  trimPageMarginsEnabled: boolean
  wideImageMode: string
  volumeKeyNavigationEnabled: boolean
  volumeKeyBehavior: string
  columnMode: string

  constructor(
    pageMode: string,
    readingDirection: string,
    themeMode: string,
    backgroundMode: string,
    showProgressControls: boolean,
    keepScreenAwake: boolean,
    fullscreen: boolean,
    imageFitMode: string,
    imageScalingQuality: string,
    showPageNumber: boolean,
    pageTurnAnimation: boolean,
    autoPageSeconds: number,
    preloadPages: number,
    spreadLayoutMode: string,
    tapZonePreset: string,
    tapZoneInvert: string,
    pageGapMode: string,
    trimPageMarginsEnabled: boolean,
    wideImageMode: string,
    volumeKeyNavigationEnabled: boolean,
    volumeKeyBehavior: string,
    columnMode: string,
  ) {
    this.pageMode = pageMode
    this.readingDirection = readingDirection
    this.themeMode = themeMode
    this.backgroundMode = backgroundMode
    this.showProgressControls = showProgressControls
    this.keepScreenAwake = keepScreenAwake
    this.fullscreen = fullscreen
    this.imageFitMode = imageFitMode
    this.imageScalingQuality = imageScalingQuality
    this.showPageNumber = showPageNumber
    this.pageTurnAnimation = pageTurnAnimation
    this.autoPageSeconds = autoPageSeconds
    this.preloadPages = preloadPages
    this.spreadLayoutMode = spreadLayoutMode
    this.tapZonePreset = tapZonePreset
    this.tapZoneInvert = tapZoneInvert
    this.pageGapMode = pageGapMode
    this.trimPageMarginsEnabled = trimPageMarginsEnabled
    this.wideImageMode = wideImageMode
    this.volumeKeyNavigationEnabled = volumeKeyNavigationEnabled
    this.volumeKeyBehavior = volumeKeyBehavior
    this.columnMode = columnMode
  }
}

@ObservedV2
export class ReaderModeState {
  @Trace pageMode: string = 'single_page'
  @Trace readingDirection: string = 'ltr'
  @Trace themeMode: string = 'system'
  @Trace backgroundMode: string = 'black'
  @Trace showProgressControls: boolean = true
  @Trace keepScreenAwake: boolean = true
  @Trace fullscreen: boolean = true
  @Trace imageFitMode: string = 'fit_width'
  @Trace imageScalingQuality: string = 'medium'
  @Trace showPageNumber: boolean = true
  @Trace pageTurnAnimation: boolean = true
  @Trace autoPageSeconds: number = 3
  @Trace preloadPages: number = 2
  @Trace spreadLayoutMode: string = 'joined'
  @Trace tapZonePreset: string = 'right_left'
  @Trace tapZoneInvert: string = 'none'
  @Trace pageGapMode: string = 'normal'
  @Trace trimPageMarginsEnabled: boolean = false
  @Trace wideImageMode: string = 'keep_single'
  @Trace volumeKeyNavigationEnabled: boolean = false
  @Trace volumeKeyBehavior: string = 'up_previous_down_next'
  @Trace hydrated: boolean = false
  /** A single monitor target for consumers that need to apply a full snapshot. */
  @Trace revision: number = 0
}

const READER_MODE_STATE_KEY: string = 'koma:readerMode'

export function connectReaderModeState(): ReaderModeState {
  return AppStorageV2.connect(ReaderModeState, READER_MODE_STATE_KEY, () => new ReaderModeState())!
}

/**
 * Keeps mutation at the ReaderPreferencesStore boundary.  UI never writes
 * this state directly, avoiding races between the reader sheet and Settings.
 */
export class ReaderModeStateBridge {
  static publish(next: ReaderModeSnapshot): void {
    const state = connectReaderModeState()
    const changed = !state.hydrated ||
      state.pageMode !== next.pageMode ||
      state.readingDirection !== next.readingDirection ||
      state.themeMode !== next.themeMode ||
      state.backgroundMode !== next.backgroundMode ||
      state.showProgressControls !== next.showProgressControls ||
      state.keepScreenAwake !== next.keepScreenAwake ||
      state.fullscreen !== next.fullscreen ||
      state.imageFitMode !== next.imageFitMode ||
      state.imageScalingQuality !== next.imageScalingQuality ||
      state.showPageNumber !== next.showPageNumber ||
      state.pageTurnAnimation !== next.pageTurnAnimation ||
      state.autoPageSeconds !== next.autoPageSeconds ||
      state.preloadPages !== next.preloadPages ||
      state.spreadLayoutMode !== next.spreadLayoutMode ||
      state.tapZonePreset !== next.tapZonePreset ||
      state.tapZoneInvert !== next.tapZoneInvert ||
      state.pageGapMode !== next.pageGapMode ||
      state.trimPageMarginsEnabled !== next.trimPageMarginsEnabled ||
      state.wideImageMode !== next.wideImageMode ||
      state.volumeKeyNavigationEnabled !== next.volumeKeyNavigationEnabled ||
      state.volumeKeyBehavior !== next.volumeKeyBehavior

    state.pageMode = next.pageMode
    state.readingDirection = next.readingDirection
    state.themeMode = next.themeMode
    state.backgroundMode = next.backgroundMode
    state.showProgressControls = next.showProgressControls
    state.keepScreenAwake = next.keepScreenAwake
    state.fullscreen = next.fullscreen
    state.imageFitMode = next.imageFitMode
    state.imageScalingQuality = next.imageScalingQuality
    state.showPageNumber = next.showPageNumber
    state.pageTurnAnimation = next.pageTurnAnimation
    state.autoPageSeconds = next.autoPageSeconds
    state.preloadPages = next.preloadPages
    state.spreadLayoutMode = next.spreadLayoutMode
    state.tapZonePreset = next.tapZonePreset
    state.tapZoneInvert = next.tapZoneInvert
    state.pageGapMode = next.pageGapMode
    state.trimPageMarginsEnabled = next.trimPageMarginsEnabled
    state.wideImageMode = next.wideImageMode
    state.volumeKeyNavigationEnabled = next.volumeKeyNavigationEnabled
    state.volumeKeyBehavior = next.volumeKeyBehavior
    state.hydrated = true
    if (changed) {
      state.revision += 1
    }
  }

  static snapshot(columnMode: string): ReaderModeSnapshot {
    const state = connectReaderModeState()
    return new ReaderModeSnapshot(
      state.pageMode,
      state.readingDirection,
      state.themeMode,
      state.backgroundMode,
      state.showProgressControls,
      state.keepScreenAwake,
      state.fullscreen,
      state.imageFitMode,
      state.imageScalingQuality,
      state.showPageNumber,
      state.pageTurnAnimation,
      state.autoPageSeconds,
      state.preloadPages,
      state.spreadLayoutMode,
      state.tapZonePreset,
      state.tapZoneInvert,
      state.pageGapMode,
      state.trimPageMarginsEnabled,
      state.wideImageMode,
      state.volumeKeyNavigationEnabled,
      state.volumeKeyBehavior,
      columnMode,
    )
  }
}
