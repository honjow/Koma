import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'
import { ReadingDirection } from './ComicModels'

export type ReaderPageMode = 'single_page' | 'double_page' | 'continuous_scroll'
export type ReaderThemeMode = 'system' | 'light' | 'dark'
export type ReaderBackgroundMode = 'black' | 'paper' | 'light'
export type ReaderImageFitMode = 'contain' | 'fit_width' | 'fit_height'
export type ReaderPageGapMode = 'compact' | 'normal' | 'wide'
export type ReaderTapZonePreset = 'edge' | 'wide_edges' | 'right_left' | 'l_shaped' | 'kindle'
export type ReaderTapZoneInvert = 'none' | 'horizontal' | 'vertical' | 'both'
export type ReaderVolumeKeyBehavior = 'up_previous_down_next' | 'up_next_down_previous'
export type ReaderWideImageMode = 'keep_single' | 'split_wide_pages' | 'rotate_wide_pages'

export interface ReaderPreferences {
  pageMode: ReaderPageMode
  readingDirection: ReadingDirection
  themeMode: ReaderThemeMode
  backgroundMode: ReaderBackgroundMode
  showProgressControls: boolean
  keepScreenAwake: boolean
  imageFitMode: ReaderImageFitMode
  tapNavigationEnabled: boolean
  swipeNavigationEnabled: boolean
  zoomGesturesEnabled: boolean
  tapZonePreset: ReaderTapZonePreset
  tapZoneInvert: ReaderTapZoneInvert
  showTapZones: boolean
  pageGapMode: ReaderPageGapMode
  trimPageMarginsEnabled: boolean
  wideImageMode: ReaderWideImageMode
  volumeKeyNavigationEnabled: boolean
  volumeKeyBehavior: ReaderVolumeKeyBehavior
}

const READER_PREFERENCES_STORE_NAME: string = 'koma_reader_preferences_v1'
export const SERIES_OVERRIDES_KEY: string = 'reader.seriesOverrides.v1'

export const DEFAULT_READER_PREFERENCES: ReaderPreferences = {
  pageMode: 'single_page',
  readingDirection: ReadingDirection.LEFT_TO_RIGHT,
  themeMode: 'system',
  backgroundMode: 'black',
  showProgressControls: true,
  keepScreenAwake: true,
  imageFitMode: 'fit_width',
  tapNavigationEnabled: true,
  swipeNavigationEnabled: true,
  zoomGesturesEnabled: true,
  tapZonePreset: 'edge',
  tapZoneInvert: 'none',
  showTapZones: false,
  pageGapMode: 'normal',
  trimPageMarginsEnabled: false,
  wideImageMode: 'keep_single',
  volumeKeyNavigationEnabled: false,
  volumeKeyBehavior: 'up_previous_down_next',
}

export function normalizeReaderPageMode(value: string): ReaderPageMode {
  if (value === 'double_page' || value === 'continuous_scroll') {
    return value
  }
  return 'single_page'
}

export function normalizeReaderThemeMode(value: string): ReaderThemeMode {
  if (value === 'light' || value === 'dark') {
    return value
  }
  return 'system'
}

export function normalizeReaderBackgroundMode(value: string): ReaderBackgroundMode {
  if (value === 'paper' || value === 'light') {
    return value
  }
  return 'black'
}

export function normalizeReaderImageFitMode(value: string): ReaderImageFitMode {
  if (value === 'fit_width' || value === 'fit_height') {
    return value
  }
  return 'contain'
}

export function normalizeReaderPageGapMode(value: string): ReaderPageGapMode {
  if (value === 'compact' || value === 'wide') {
    return value
  }
  return 'normal'
}

export function normalizeReaderTapZonePreset(value: string): ReaderTapZonePreset {
  if (value === 'wide_edges' || value === 'right_left' || value === 'l_shaped' || value === 'kindle') {
    return value
  }
  return 'edge'
}

export function normalizeReaderTapZoneInvert(value: string): ReaderTapZoneInvert {
  if (value === 'horizontal' || value === 'vertical' || value === 'both') {
    return value
  }
  return 'none'
}

export function normalizeReaderVolumeKeyBehavior(value: string): ReaderVolumeKeyBehavior {
  if (value === 'up_next_down_previous') {
    return value
  }
  return 'up_previous_down_next'
}

export function normalizeReaderWideImageMode(value: string): ReaderWideImageMode {
  if (value === 'split_wide_pages' || value === 'rotate_wide_pages') {
    return value
  }
  return 'keep_single'
}

export function normalizeReaderPreferences(value: ReaderPreferences): ReaderPreferences {
  return {
    pageMode: normalizeReaderPageMode(value.pageMode),
    readingDirection: value.readingDirection,
    themeMode: normalizeReaderThemeMode(value.themeMode),
    backgroundMode: normalizeReaderBackgroundMode(value.backgroundMode),
    showProgressControls: value.showProgressControls !== false,
    keepScreenAwake: value.keepScreenAwake !== false,
    imageFitMode: normalizeReaderImageFitMode(value.imageFitMode),
    tapNavigationEnabled: value.tapNavigationEnabled !== false,
    swipeNavigationEnabled: value.swipeNavigationEnabled !== false,
    zoomGesturesEnabled: value.zoomGesturesEnabled !== false,
    tapZonePreset: normalizeReaderTapZonePreset(value.tapZonePreset),
    tapZoneInvert: normalizeReaderTapZoneInvert(value.tapZoneInvert),
    showTapZones: value.showTapZones === true,
    pageGapMode: normalizeReaderPageGapMode(value.pageGapMode),
    trimPageMarginsEnabled: value.trimPageMarginsEnabled === true,
    wideImageMode: normalizeReaderWideImageMode(value.wideImageMode),
    volumeKeyNavigationEnabled: value.volumeKeyNavigationEnabled === true,
    volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(value.volumeKeyBehavior),
  }
}

function normalizeReaderDirection(value: string, fallback: ReadingDirection): ReadingDirection {
  if (value === ReadingDirection.RIGHT_TO_LEFT) {
    return ReadingDirection.RIGHT_TO_LEFT
  }
  if (value === ReadingDirection.WEBTOON) {
    return ReadingDirection.WEBTOON
  }
  if (value === ReadingDirection.LEFT_TO_RIGHT) {
    return ReadingDirection.LEFT_TO_RIGHT
  }
  return fallback
}

function stringField(record: Record<string, Object>, key: string, fallback: string): string {
  const value = record[key]
  return typeof value === 'string' ? value : fallback
}

function booleanField(record: Record<string, Object>, key: string, fallback: boolean): boolean {
  const value = record[key]
  return typeof value === 'boolean' ? value : fallback
}

function preferencesFromRecord(record: Record<string, Object>, fallback: ReaderPreferences): ReaderPreferences {
  return normalizeReaderPreferences({
    pageMode: normalizeReaderPageMode(stringField(record, 'pageMode', fallback.pageMode)),
    readingDirection: normalizeReaderDirection(stringField(record, 'readingDirection', fallback.readingDirection), fallback.readingDirection),
    themeMode: normalizeReaderThemeMode(stringField(record, 'themeMode', fallback.themeMode)),
    backgroundMode: normalizeReaderBackgroundMode(stringField(record, 'backgroundMode', fallback.backgroundMode)),
    showProgressControls: booleanField(record, 'showProgressControls', fallback.showProgressControls),
    keepScreenAwake: booleanField(record, 'keepScreenAwake', fallback.keepScreenAwake),
    imageFitMode: normalizeReaderImageFitMode(stringField(record, 'imageFitMode', fallback.imageFitMode)),
    tapNavigationEnabled: booleanField(record, 'tapNavigationEnabled', fallback.tapNavigationEnabled),
    swipeNavigationEnabled: booleanField(record, 'swipeNavigationEnabled', fallback.swipeNavigationEnabled),
    zoomGesturesEnabled: booleanField(record, 'zoomGesturesEnabled', fallback.zoomGesturesEnabled),
    tapZonePreset: normalizeReaderTapZonePreset(stringField(record, 'tapZonePreset', fallback.tapZonePreset)),
    tapZoneInvert: normalizeReaderTapZoneInvert(stringField(record, 'tapZoneInvert', fallback.tapZoneInvert)),
    showTapZones: booleanField(record, 'showTapZones', fallback.showTapZones),
    pageGapMode: normalizeReaderPageGapMode(stringField(record, 'pageGapMode', fallback.pageGapMode)),
    trimPageMarginsEnabled: booleanField(record, 'trimPageMarginsEnabled', fallback.trimPageMarginsEnabled),
    wideImageMode: normalizeReaderWideImageMode(stringField(record, 'wideImageMode', fallback.wideImageMode)),
    volumeKeyNavigationEnabled: booleanField(record, 'volumeKeyNavigationEnabled', fallback.volumeKeyNavigationEnabled),
    volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(stringField(record, 'volumeKeyBehavior', fallback.volumeKeyBehavior)),
  })
}

/**
 * Normalize the versioned per-series preference payload before it can affect
 * the live reader. Corrupt rows and empty comic identifiers are discarded.
 */
export function normalizeReaderSeriesPreferenceOverrides(value: string): Record<string, ReaderPreferences> {
  if (value.length === 0) {
    return {}
  }
  let parsed: Object
  try {
    parsed = JSON.parse(value) as Object
  } catch (_error) {
    return {}
  }
  if (typeof parsed !== 'object' || Array.isArray(parsed)) {
    return {}
  }
  const source = parsed as Record<string, Object>
  const normalized: Record<string, ReaderPreferences> = {}
  Object.keys(source).forEach((comicId: string) => {
    const key = comicId.trim()
    const raw = source[comicId]
    if (key.length === 0 || raw === undefined || raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
      return
    }
    normalized[key] = preferencesFromRecord(raw as Record<string, Object>, DEFAULT_READER_PREFERENCES)
  })
  return normalized
}

export function getReaderPageModeLabel(mode: ReaderPageMode): string {
  if (mode === 'double_page') {
    return AppStrings.get('reader_page_mode_double')
  }
  if (mode === 'continuous_scroll') {
    return AppStrings.get('reader_page_mode_continuous')
  }
  return AppStrings.get('reader_page_mode_single')
}

export function getReadingDirectionLabel(direction: ReadingDirection): string {
  if (direction === ReadingDirection.RIGHT_TO_LEFT) {
    return AppStrings.get('reader_direction_rtl')
  }
  if (direction === ReadingDirection.WEBTOON) {
    return AppStrings.get('reader_direction_vertical')
  }
  return AppStrings.get('reader_direction_ltr')
}

export function getReaderThemeModeLabel(mode: ReaderThemeMode): string {
  if (mode === 'light') {
    return AppStrings.get('theme_light')
  }
  if (mode === 'dark') {
    return AppStrings.get('theme_dark')
  }
  return AppStrings.get('theme_system')
}

export function getReaderBackgroundModeLabel(mode: ReaderBackgroundMode): string {
  if (mode === 'paper') {
    return AppStrings.get('reader_background_paper')
  }
  if (mode === 'light') {
    return AppStrings.get('reader_background_light')
  }
  return AppStrings.get('reader_background_black')
}

export function getReaderImageFitModeLabel(mode: ReaderImageFitMode): string {
  if (mode === 'fit_width') {
    return AppStrings.get('reader_image_fit_width')
  }
  if (mode === 'fit_height') {
    return AppStrings.get('reader_image_fit_height')
  }
  return AppStrings.get('reader_image_fit_screen')
}

export function getReaderPageGapModeLabel(mode: ReaderPageGapMode): string {
  if (mode === 'compact') {
    return AppStrings.get('reader_page_gap_compact')
  }
  if (mode === 'wide') {
    return AppStrings.get('reader_page_gap_wide')
  }
  return AppStrings.get('common_standard')
}

export function getReaderTapZonePresetLabel(mode: ReaderTapZonePreset): string {
  if (mode === 'wide_edges') {
    return AppStrings.get('reader_tap_zone_wide')
  }
  if (mode === 'right_left') {
    return AppStrings.get('reader_tap_zone_right_left')
  }
  if (mode === 'l_shaped') {
    return AppStrings.get('reader_tap_zone_l_shaped')
  }
  if (mode === 'kindle') {
    return AppStrings.get('reader_tap_zone_kindle')
  }
  return AppStrings.get('reader_tap_zone_edge')
}

export function getReaderTapZoneInvertLabel(mode: ReaderTapZoneInvert): string {
  if (mode === 'horizontal') {
    return AppStrings.get('reader_tap_zone_invert_horizontal')
  }
  if (mode === 'vertical') {
    return AppStrings.get('reader_tap_zone_invert_vertical')
  }
  if (mode === 'both') {
    return AppStrings.get('reader_tap_zone_invert_both')
  }
  return AppStrings.get('reader_tap_zone_invert_none')
}

export function getReaderVolumeKeyBehaviorLabel(behavior: ReaderVolumeKeyBehavior): string {
  if (behavior === 'up_next_down_previous') {
    return AppStrings.get('reader_volume_keys_up_next')
  }
  return AppStrings.get('reader_volume_keys_down_next')
}

export function getReaderWideImageModeLabel(mode: ReaderWideImageMode): string {
  if (mode === 'split_wide_pages') {
    return AppStrings.get('reader_wide_mode_split')
  }
  if (mode === 'rotate_wide_pages') {
    return AppStrings.get('reader_wide_mode_rotate')
  }
  return AppStrings.get('reader_wide_mode_keep_single')
}

export function getReaderKeepScreenAwakeLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderProgressControlsLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderSwipeNavigationLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderShowTapZonesLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderTapNavigationLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderTrimPageMarginsLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderVolumeKeyNavigationLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderZoomGesturesLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function applyReaderThemeMode(_context: common.UIAbilityContext, _mode: ReaderThemeMode): void {
  // Theme application is owned by the app shell; reader preferences only persist the selection.
}

export class ReaderPreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<ReaderPreferences> {
    const store = await this.preferences()
    const pageMode = await store.get('reader.pageMode', DEFAULT_READER_PREFERENCES.pageMode) as string
    const readingDirection = await store.get('reader.readingDirection', DEFAULT_READER_PREFERENCES.readingDirection) as string
    const themeMode = await store.get('reader.themeMode', DEFAULT_READER_PREFERENCES.themeMode) as string
    const backgroundMode = await store.get('reader.backgroundMode', DEFAULT_READER_PREFERENCES.backgroundMode) as string
    const showProgressControls = await store.get('reader.showProgressControls', DEFAULT_READER_PREFERENCES.showProgressControls) as boolean
    const keepScreenAwake = await store.get('reader.keepScreenAwake', DEFAULT_READER_PREFERENCES.keepScreenAwake) as boolean
    const imageFitMode = await store.get('reader.imageFitMode', DEFAULT_READER_PREFERENCES.imageFitMode) as string
    const tapNavigationEnabled = await store.get('reader.tapNavigationEnabled', DEFAULT_READER_PREFERENCES.tapNavigationEnabled) as boolean
    const swipeNavigationEnabled = await store.get('reader.swipeNavigationEnabled', DEFAULT_READER_PREFERENCES.swipeNavigationEnabled) as boolean
    const zoomGesturesEnabled = await store.get('reader.zoomGesturesEnabled', DEFAULT_READER_PREFERENCES.zoomGesturesEnabled) as boolean
    const tapZonePreset = await store.get('reader.tapZonePreset', DEFAULT_READER_PREFERENCES.tapZonePreset) as string
    const tapZoneInvert = await store.get('reader.tapZoneInvert', DEFAULT_READER_PREFERENCES.tapZoneInvert) as string
    const showTapZones = await store.get('reader.showTapZones', DEFAULT_READER_PREFERENCES.showTapZones) as boolean
    const pageGapMode = await store.get('reader.pageGapMode', DEFAULT_READER_PREFERENCES.pageGapMode) as string
    const trimPageMarginsEnabled = await store.get('reader.trimPageMarginsEnabled', DEFAULT_READER_PREFERENCES.trimPageMarginsEnabled) as boolean
    const wideImageMode = await store.get('reader.wideImageMode', DEFAULT_READER_PREFERENCES.wideImageMode) as string
    const volumeKeyNavigationEnabled = await store.get('reader.volumeKeyNavigationEnabled', DEFAULT_READER_PREFERENCES.volumeKeyNavigationEnabled) as boolean
    const volumeKeyBehavior = await store.get('reader.volumeKeyBehavior', DEFAULT_READER_PREFERENCES.volumeKeyBehavior) as string
    return normalizeReaderPreferences({
      pageMode: normalizeReaderPageMode(pageMode),
      readingDirection: readingDirection === ReadingDirection.RIGHT_TO_LEFT
        ? ReadingDirection.RIGHT_TO_LEFT
        : (readingDirection === ReadingDirection.WEBTOON
          ? ReadingDirection.WEBTOON
          : ReadingDirection.LEFT_TO_RIGHT),
      themeMode: normalizeReaderThemeMode(themeMode),
      backgroundMode: normalizeReaderBackgroundMode(backgroundMode),
      showProgressControls,
      keepScreenAwake,
      imageFitMode: normalizeReaderImageFitMode(imageFitMode),
      tapNavigationEnabled,
      swipeNavigationEnabled,
      zoomGesturesEnabled,
      tapZonePreset: normalizeReaderTapZonePreset(tapZonePreset),
      tapZoneInvert: normalizeReaderTapZoneInvert(tapZoneInvert),
      showTapZones,
      pageGapMode: normalizeReaderPageGapMode(pageGapMode),
      trimPageMarginsEnabled,
      wideImageMode: normalizeReaderWideImageMode(wideImageMode),
      volumeKeyNavigationEnabled,
      volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(volumeKeyBehavior),
    })
  }

  async loadForComic(comicId: string): Promise<ReaderPreferences> {
    const global = await this.load()
    const key = comicId.trim()
    if (key.length === 0) {
      return global
    }
    const store = await this.preferences()
    const payload = await store.get(SERIES_OVERRIDES_KEY, '') as string
    const overrides = normalizeReaderSeriesPreferenceOverrides(payload)
    const override = overrides[key]
    if (override === undefined) {
      return global
    }
    return normalizeReaderPreferences(override)
  }

  async save(preferences: ReaderPreferences): Promise<ReaderPreferences> {
    const normalized = normalizeReaderPreferences(preferences)
    const store = await this.preferences()
    await store.put('reader.pageMode', normalized.pageMode)
    await store.put('reader.readingDirection', normalized.readingDirection)
    await store.put('reader.themeMode', normalized.themeMode)
    await store.put('reader.backgroundMode', normalized.backgroundMode)
    await store.put('reader.showProgressControls', normalized.showProgressControls)
    await store.put('reader.keepScreenAwake', normalized.keepScreenAwake)
    await store.put('reader.imageFitMode', normalized.imageFitMode)
    await store.put('reader.tapNavigationEnabled', normalized.tapNavigationEnabled)
    await store.put('reader.swipeNavigationEnabled', normalized.swipeNavigationEnabled)
    await store.put('reader.zoomGesturesEnabled', normalized.zoomGesturesEnabled)
    await store.put('reader.tapZonePreset', normalized.tapZonePreset)
    await store.put('reader.tapZoneInvert', normalized.tapZoneInvert)
    await store.put('reader.showTapZones', normalized.showTapZones)
    await store.put('reader.pageGapMode', normalized.pageGapMode)
    await store.put('reader.trimPageMarginsEnabled', normalized.trimPageMarginsEnabled)
    await store.put('reader.wideImageMode', normalized.wideImageMode)
    await store.put('reader.volumeKeyNavigationEnabled', normalized.volumeKeyNavigationEnabled)
    await store.put('reader.volumeKeyBehavior', normalized.volumeKeyBehavior)
    await store.flush()
    return normalized
  }

  async saveForComic(comicId: string, preferences: ReaderPreferences): Promise<ReaderPreferences> {
    const normalized = normalizeReaderPreferences(preferences)
    const key = comicId.trim()
    if (key.length === 0) {
      return this.save(normalized)
    }
    const store = await this.preferences()
    const payload = await store.get(SERIES_OVERRIDES_KEY, '') as string
    const overrides = normalizeReaderSeriesPreferenceOverrides(payload)
    overrides[key] = normalized
    await store.put(SERIES_OVERRIDES_KEY, JSON.stringify(overrides))
    await store.flush()
    return normalized
  }

  private cloneBase(current: ReaderPreferences): ReaderPreferences {
    return {
      pageMode: current.pageMode,
      readingDirection: current.readingDirection,
      themeMode: current.themeMode,
      backgroundMode: current.backgroundMode,
      showProgressControls: current.showProgressControls,
      keepScreenAwake: current.keepScreenAwake,
      imageFitMode: current.imageFitMode,
      tapNavigationEnabled: current.tapNavigationEnabled,
      swipeNavigationEnabled: current.swipeNavigationEnabled,
      zoomGesturesEnabled: current.zoomGesturesEnabled,
      tapZonePreset: current.tapZonePreset,
      tapZoneInvert: current.tapZoneInvert,
      showTapZones: current.showTapZones,
      pageGapMode: current.pageGapMode,
      trimPageMarginsEnabled: current.trimPageMarginsEnabled,
      wideImageMode: current.wideImageMode,
      volumeKeyNavigationEnabled: current.volumeKeyNavigationEnabled,
      volumeKeyBehavior: current.volumeKeyBehavior,
    }
  }

  async savePageMode(pageMode: ReaderPageMode): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.pageMode = pageMode
    return this.save(next)
  }

  async saveReadingDirection(readingDirection: ReadingDirection): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.readingDirection = readingDirection
    return this.save(next)
  }

  async saveThemeMode(themeMode: ReaderThemeMode): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.themeMode = themeMode
    return this.save(next)
  }

  async saveBackgroundMode(backgroundMode: ReaderBackgroundMode): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.backgroundMode = backgroundMode
    return this.save(next)
  }

  async saveShowProgressControls(showProgressControls: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.showProgressControls = showProgressControls
    return this.save(next)
  }

  async saveKeepScreenAwake(keepScreenAwake: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.keepScreenAwake = keepScreenAwake
    return this.save(next)
  }

  async saveImageFitMode(imageFitMode: ReaderImageFitMode): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.imageFitMode = imageFitMode
    return this.save(next)
  }

  async saveTapNavigationEnabled(tapNavigationEnabled: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.tapNavigationEnabled = tapNavigationEnabled
    return this.save(next)
  }

  async saveSwipeNavigationEnabled(swipeNavigationEnabled: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.swipeNavigationEnabled = swipeNavigationEnabled
    return this.save(next)
  }

  async saveZoomGesturesEnabled(zoomGesturesEnabled: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.zoomGesturesEnabled = zoomGesturesEnabled
    return this.save(next)
  }

  async saveTapZonePreset(tapZonePreset: ReaderTapZonePreset): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.tapZonePreset = tapZonePreset
    return this.save(next)
  }

  async saveTapZoneInvert(tapZoneInvert: ReaderTapZoneInvert): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.tapZoneInvert = tapZoneInvert
    return this.save(next)
  }

  async saveShowTapZones(showTapZones: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.showTapZones = showTapZones
    return this.save(next)
  }

  async savePageGapMode(pageGapMode: ReaderPageGapMode): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.pageGapMode = pageGapMode
    return this.save(next)
  }

  async saveTrimPageMarginsEnabled(trimPageMarginsEnabled: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.trimPageMarginsEnabled = trimPageMarginsEnabled
    return this.save(next)
  }

  async saveWideImageMode(wideImageMode: ReaderWideImageMode): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.wideImageMode = wideImageMode
    return this.save(next)
  }

  async saveVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled: boolean): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.volumeKeyNavigationEnabled = volumeKeyNavigationEnabled
    return this.save(next)
  }

  async saveVolumeKeyBehavior(volumeKeyBehavior: ReaderVolumeKeyBehavior): Promise<ReaderPreferences> {
    const current = await this.load()
    const next = this.cloneBase(current)
    next.volumeKeyBehavior = volumeKeyBehavior
    return this.save(next)
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_PREFERENCES_STORE_NAME)
  }
}
