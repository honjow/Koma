import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ComicId, ReadingDirection } from './ComicModels'
import { ReaderMode } from './ReaderSessionStore'
import { AppStrings } from '../i18n/AppStrings'

export type ReaderPageMode = 'single_page' | 'double_page' | 'continuous_scroll'
export type ReaderThemeMode = 'system' | 'light' | 'dark'
export type ReaderBackgroundMode = 'black' | 'paper' | 'light'
export type ReaderImageFitMode = 'contain' | 'fit_width'
export type ReaderTapZonePreset = 'edge' | 'wide_edges'
export type ReaderPageGapMode = 'compact' | 'normal' | 'wide'
export type ReaderWideImageMode = 'keep_single' | 'rotate_wide_pages' | 'split_wide_pages'
export type ReaderVolumeKeyBehavior = 'up_previous_down_next' | 'up_next_down_previous'

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
  showTapZones: boolean
  pageGapMode: ReaderPageGapMode
  trimPageMarginsEnabled: boolean
  wideImageMode: ReaderWideImageMode
  volumeKeyNavigationEnabled: boolean
  volumeKeyBehavior: ReaderVolumeKeyBehavior
}

export interface ReaderSeriesPreferenceOverrides {
  pageMode?: ReaderPageMode
  readingDirection?: ReadingDirection
  backgroundMode?: ReaderBackgroundMode
  imageFitMode?: ReaderImageFitMode
  tapNavigationEnabled?: boolean
  swipeNavigationEnabled?: boolean
  zoomGesturesEnabled?: boolean
  tapZonePreset?: ReaderTapZonePreset
  showTapZones?: boolean
  pageGapMode?: ReaderPageGapMode
  trimPageMarginsEnabled?: boolean
  wideImageMode?: ReaderWideImageMode
}

export const READER_PREFERENCES_STORE_NAME: string = 'koma_reader_preferences_v1'
export const PAGE_MODE_KEY: string = 'reader.pageMode'
export const READING_DIRECTION_KEY: string = 'reader.readingDirection'
export const THEME_MODE_KEY: string = 'reader.themeMode'
export const BACKGROUND_MODE_KEY: string = 'reader.backgroundMode'
export const SHOW_PROGRESS_CONTROLS_KEY: string = 'reader.showProgressControls'
export const KEEP_SCREEN_AWAKE_KEY: string = 'reader.keepScreenAwake'
export const IMAGE_FIT_MODE_KEY: string = 'reader.imageFitMode'
export const TAP_NAVIGATION_ENABLED_KEY: string = 'reader.tapNavigationEnabled'
export const SWIPE_NAVIGATION_ENABLED_KEY: string = 'reader.swipeNavigationEnabled'
export const ZOOM_GESTURES_ENABLED_KEY: string = 'reader.zoomGesturesEnabled'
export const TAP_ZONE_PRESET_KEY: string = 'reader.tapZonePreset'
export const SHOW_TAP_ZONES_KEY: string = 'reader.showTapZones'
export const PAGE_GAP_MODE_KEY: string = 'reader.pageGapMode'
export const TRIM_PAGE_MARGINS_ENABLED_KEY: string = 'reader.trimPageMarginsEnabled'
export const WIDE_IMAGE_MODE_KEY: string = 'reader.wideImageMode'
export const VOLUME_KEY_NAVIGATION_ENABLED_KEY: string = 'reader.volumeKeyNavigationEnabled'
export const VOLUME_KEY_BEHAVIOR_KEY: string = 'reader.volumeKeyBehavior'
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
  if (value === 'fit_width') {
    return value
  }
  return 'contain'
}

export function normalizeReaderTapZonePreset(value: string): ReaderTapZonePreset {
  if (value === 'wide_edges') {
    return value
  }
  return 'edge'
}

export function normalizeReaderPageGapMode(value: string): ReaderPageGapMode {
  if (value === 'compact' || value === 'wide') {
    return value
  }
  return 'normal'
}

export function normalizeReaderWideImageMode(value: string): ReaderWideImageMode {
  if (value === 'rotate_wide_pages' || value === 'split_wide_pages') {
    return value
  }
  return 'keep_single'
}

export function normalizeReaderVolumeKeyBehavior(value: string): ReaderVolumeKeyBehavior {
  if (value === 'up_next_down_previous') {
    return value
  }
  return 'up_previous_down_next'
}

export function normalizeReaderProgressControls(value: boolean | string | number): boolean {
  if (value === false || value === 'false' || value === 0 || value === '0') {
    return false
  }
  return true
}

export function normalizeReaderKeepScreenAwake(value: boolean | string | number): boolean {
  if (value === false || value === 'false' || value === 0 || value === '0') {
    return false
  }
  return true
}

export function normalizeReaderTapNavigationEnabled(value: boolean | string | number): boolean {
  if (value === false || value === 'false' || value === 0 || value === '0') {
    return false
  }
  return true
}

export function normalizeReaderSwipeNavigationEnabled(value: boolean | string | number): boolean {
  if (value === false || value === 'false' || value === 0 || value === '0') {
    return false
  }
  return true
}

export function normalizeReaderZoomGesturesEnabled(value: boolean | string | number): boolean {
  if (value === false || value === 'false' || value === 0 || value === '0') {
    return false
  }
  return true
}

export function normalizeReaderShowTapZones(value: boolean | string | number): boolean {
  if (value === true || value === 'true' || value === 1 || value === '1') {
    return true
  }
  return false
}

export function normalizeReaderTrimPageMarginsEnabled(value: boolean | string | number): boolean {
  if (value === true || value === 'true' || value === 1 || value === '1') {
    return true
  }
  return false
}

export function normalizeReaderVolumeKeyNavigationEnabled(value: boolean | string | number): boolean {
  if (value === true || value === 'true' || value === 1 || value === '1') {
    return true
  }
  return false
}

export function normalizeReaderReadingDirection(value: string): ReadingDirection {
  if (value === ReadingDirection.RIGHT_TO_LEFT || value === ReadingDirection.WEBTOON) {
    return value
  }
  return ReadingDirection.LEFT_TO_RIGHT
}

export function getReaderPageModeLabel(mode: ReaderPageMode): string {
  if (mode === 'continuous_scroll') {
    return AppStrings.get('reader_page_mode_continuous')
  }
  if (mode === 'double_page') {
    return AppStrings.get('reader_page_mode_double')
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
  if (mode === 'dark') {
    return AppStrings.get('theme_dark')
  }
  if (mode === 'light') {
    return AppStrings.get('theme_light')
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

export function getReaderProgressControlsLabel(showProgressControls: boolean): string {
  return showProgressControls ? AppStrings.get('common_show') : AppStrings.get('common_hide')
}

export function getReaderKeepScreenAwakeLabel(keepScreenAwake: boolean): string {
  return keepScreenAwake ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderImageFitModeLabel(mode: ReaderImageFitMode): string {
  if (mode === 'fit_width') {
    return AppStrings.get('reader_image_fit_width')
  }
  return AppStrings.get('reader_image_fit_screen')
}

export function getReaderTapNavigationLabel(tapNavigationEnabled: boolean): string {
  return tapNavigationEnabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderSwipeNavigationLabel(swipeNavigationEnabled: boolean): string {
  return swipeNavigationEnabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderZoomGesturesLabel(zoomGesturesEnabled: boolean): string {
  return zoomGesturesEnabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderTapZonePresetLabel(preset: ReaderTapZonePreset): string {
  if (preset === 'wide_edges') {
    return AppStrings.get('reader_tap_zone_wide')
  }
  return AppStrings.get('reader_tap_zone_edge')
}

export function getReaderShowTapZonesLabel(showTapZones: boolean): string {
  return showTapZones ? AppStrings.get('common_show') : AppStrings.get('common_hide')
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

export function getReaderTrimPageMarginsLabel(trimPageMarginsEnabled: boolean): string {
  return trimPageMarginsEnabled ? AppStrings.get('reader_trim_margins_on') : AppStrings.get('common_off')
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

export function getReaderVolumeKeyNavigationLabel(volumeKeyNavigationEnabled: boolean): string {
  return volumeKeyNavigationEnabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderVolumeKeyBehaviorLabel(behavior: ReaderVolumeKeyBehavior): string {
  if (behavior === 'up_next_down_previous') {
    return AppStrings.get('reader_volume_keys_up_next')
  }
  return AppStrings.get('reader_volume_keys_down_next')
}

export function readerModeFromPageMode(pageMode: ReaderPageMode): ReaderMode {
  if (pageMode === 'continuous_scroll') {
    return ReaderMode.CONTINUOUS_SCROLL
  }
  if (pageMode === 'double_page') {
    return ReaderMode.DUAL_PAGE
  }
  return ReaderMode.SINGLE_PAGE
}

function sanitizeReaderSeriesId(comicId: ComicId): ComicId | undefined {
  const trimmed = comicId.trim()
  if (trimmed.length === 0 || trimmed.length > 160) {
    return undefined
  }
  return trimmed
}

function normalizeReaderSeriesPreferenceOverrides(value: Object | undefined): ReaderSeriesPreferenceOverrides | undefined {
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  const source = value as Record<string, Object>
  const overrides: ReaderSeriesPreferenceOverrides = {}
  if (typeof source['pageMode'] === 'string') {
    overrides.pageMode = normalizeReaderPageMode(source['pageMode'] as string)
  }
  if (typeof source['readingDirection'] === 'string') {
    overrides.readingDirection = normalizeReaderReadingDirection(source['readingDirection'] as string)
  }
  if (typeof source['backgroundMode'] === 'string') {
    overrides.backgroundMode = normalizeReaderBackgroundMode(source['backgroundMode'] as string)
  }
  if (typeof source['imageFitMode'] === 'string') {
    overrides.imageFitMode = normalizeReaderImageFitMode(source['imageFitMode'] as string)
  }
  if (source['tapNavigationEnabled'] !== undefined) {
    overrides.tapNavigationEnabled = normalizeReaderTapNavigationEnabled(source['tapNavigationEnabled'] as boolean | string | number)
  }
  if (source['swipeNavigationEnabled'] !== undefined) {
    overrides.swipeNavigationEnabled = normalizeReaderSwipeNavigationEnabled(source['swipeNavigationEnabled'] as boolean | string | number)
  }
  if (source['zoomGesturesEnabled'] !== undefined) {
    overrides.zoomGesturesEnabled = normalizeReaderZoomGesturesEnabled(source['zoomGesturesEnabled'] as boolean | string | number)
  }
  if (typeof source['tapZonePreset'] === 'string') {
    overrides.tapZonePreset = normalizeReaderTapZonePreset(source['tapZonePreset'] as string)
  }
  if (source['showTapZones'] !== undefined) {
    overrides.showTapZones = normalizeReaderShowTapZones(source['showTapZones'] as boolean | string | number)
  }
  if (typeof source['pageGapMode'] === 'string') {
    overrides.pageGapMode = normalizeReaderPageGapMode(source['pageGapMode'] as string)
  }
  if (source['trimPageMarginsEnabled'] !== undefined) {
    overrides.trimPageMarginsEnabled = normalizeReaderTrimPageMarginsEnabled(source['trimPageMarginsEnabled'] as boolean | string | number)
  }
  if (typeof source['wideImageMode'] === 'string') {
    overrides.wideImageMode = normalizeReaderWideImageMode(source['wideImageMode'] as string)
  }
  return Object.keys(overrides).length === 0 ? undefined : overrides
}

function mergeReaderSeriesPreferences(
  globalPreferences: ReaderPreferences,
  overrides: ReaderSeriesPreferenceOverrides | undefined,
): ReaderPreferences {
  if (overrides === undefined) {
    return globalPreferences
  }
  return {
    pageMode: overrides.pageMode ?? globalPreferences.pageMode,
    readingDirection: overrides.readingDirection ?? globalPreferences.readingDirection,
    themeMode: globalPreferences.themeMode,
    backgroundMode: overrides.backgroundMode ?? globalPreferences.backgroundMode,
    showProgressControls: globalPreferences.showProgressControls,
    keepScreenAwake: globalPreferences.keepScreenAwake,
    imageFitMode: overrides.imageFitMode ?? globalPreferences.imageFitMode,
    tapNavigationEnabled: overrides.tapNavigationEnabled ?? globalPreferences.tapNavigationEnabled,
    swipeNavigationEnabled: overrides.swipeNavigationEnabled ?? globalPreferences.swipeNavigationEnabled,
    zoomGesturesEnabled: overrides.zoomGesturesEnabled ?? globalPreferences.zoomGesturesEnabled,
    tapZonePreset: overrides.tapZonePreset ?? globalPreferences.tapZonePreset,
    showTapZones: overrides.showTapZones ?? globalPreferences.showTapZones,
    pageGapMode: overrides.pageGapMode ?? globalPreferences.pageGapMode,
    trimPageMarginsEnabled: overrides.trimPageMarginsEnabled ?? globalPreferences.trimPageMarginsEnabled,
    wideImageMode: overrides.wideImageMode ?? globalPreferences.wideImageMode,
    volumeKeyNavigationEnabled: globalPreferences.volumeKeyNavigationEnabled,
    volumeKeyBehavior: globalPreferences.volumeKeyBehavior,
  }
}

function readerSeriesOverridesWithout(
  overrides: Record<string, ReaderSeriesPreferenceOverrides>,
  comicId: ComicId,
): Record<string, ReaderSeriesPreferenceOverrides> {
  const next: Record<string, ReaderSeriesPreferenceOverrides> = {}
  Object.keys(overrides).forEach((key: string): void => {
    if (key !== comicId) {
      next[key] = overrides[key]
    }
  })
  return next
}

export function applyReaderThemeMode(context: common.UIAbilityContext, mode: ReaderThemeMode): void {
  let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  if (mode === 'dark') {
    colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
  } else if (mode === 'light') {
    colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
  }
  context.getApplicationContext().setColorMode(colorMode)
}

export class ReaderPreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<ReaderPreferences> {
    const store = await this.preferences()
    const pageMode = await store.get(PAGE_MODE_KEY, DEFAULT_READER_PREFERENCES.pageMode) as string
    const readingDirection = await store.get(READING_DIRECTION_KEY, DEFAULT_READER_PREFERENCES.readingDirection) as string
    const themeMode = await store.get(THEME_MODE_KEY, DEFAULT_READER_PREFERENCES.themeMode) as string
    const backgroundMode = await store.get(BACKGROUND_MODE_KEY, DEFAULT_READER_PREFERENCES.backgroundMode) as string
    const showProgressControls =
      await store.get(SHOW_PROGRESS_CONTROLS_KEY, DEFAULT_READER_PREFERENCES.showProgressControls) as boolean | string | number
    const keepScreenAwake =
      await store.get(KEEP_SCREEN_AWAKE_KEY, DEFAULT_READER_PREFERENCES.keepScreenAwake) as boolean | string | number
    const imageFitMode = await store.get(IMAGE_FIT_MODE_KEY, DEFAULT_READER_PREFERENCES.imageFitMode) as string
    const tapNavigationEnabled =
      await store.get(TAP_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES.tapNavigationEnabled) as boolean | string | number
    const swipeNavigationEnabled =
      await store.get(SWIPE_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES.swipeNavigationEnabled) as boolean | string | number
    const zoomGesturesEnabled =
      await store.get(ZOOM_GESTURES_ENABLED_KEY, DEFAULT_READER_PREFERENCES.zoomGesturesEnabled) as boolean | string | number
    const tapZonePreset = await store.get(TAP_ZONE_PRESET_KEY, DEFAULT_READER_PREFERENCES.tapZonePreset) as string
    const showTapZones =
      await store.get(SHOW_TAP_ZONES_KEY, DEFAULT_READER_PREFERENCES.showTapZones) as boolean | string | number
    const pageGapMode = await store.get(PAGE_GAP_MODE_KEY, DEFAULT_READER_PREFERENCES.pageGapMode) as string
    const trimPageMarginsEnabled =
      await store.get(TRIM_PAGE_MARGINS_ENABLED_KEY, DEFAULT_READER_PREFERENCES.trimPageMarginsEnabled) as boolean | string | number
    const wideImageMode = await store.get(WIDE_IMAGE_MODE_KEY, DEFAULT_READER_PREFERENCES.wideImageMode) as string
    const volumeKeyNavigationEnabled =
      await store.get(VOLUME_KEY_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES.volumeKeyNavigationEnabled) as boolean | string | number
    const volumeKeyBehavior = await store.get(VOLUME_KEY_BEHAVIOR_KEY, DEFAULT_READER_PREFERENCES.volumeKeyBehavior) as string
    return {
      pageMode: normalizeReaderPageMode(pageMode),
      readingDirection: normalizeReaderReadingDirection(readingDirection),
      themeMode: normalizeReaderThemeMode(themeMode),
      backgroundMode: normalizeReaderBackgroundMode(backgroundMode),
      showProgressControls: normalizeReaderProgressControls(showProgressControls),
      keepScreenAwake: normalizeReaderKeepScreenAwake(keepScreenAwake),
      imageFitMode: normalizeReaderImageFitMode(imageFitMode),
      tapNavigationEnabled: normalizeReaderTapNavigationEnabled(tapNavigationEnabled),
      swipeNavigationEnabled: normalizeReaderSwipeNavigationEnabled(swipeNavigationEnabled),
      zoomGesturesEnabled: normalizeReaderZoomGesturesEnabled(zoomGesturesEnabled),
      tapZonePreset: normalizeReaderTapZonePreset(tapZonePreset),
      showTapZones: normalizeReaderShowTapZones(showTapZones),
      pageGapMode: normalizeReaderPageGapMode(pageGapMode),
      trimPageMarginsEnabled: normalizeReaderTrimPageMarginsEnabled(trimPageMarginsEnabled),
      wideImageMode: normalizeReaderWideImageMode(wideImageMode),
      volumeKeyNavigationEnabled: normalizeReaderVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled),
      volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(volumeKeyBehavior),
    }
  }

  async loadForComic(comicId: ComicId): Promise<ReaderPreferences> {
    const globalPreferences = await this.load()
    const seriesId = sanitizeReaderSeriesId(comicId)
    if (seriesId === undefined) {
      return globalPreferences
    }
    const overrides = await this.loadSeriesOverrides()
    return mergeReaderSeriesPreferences(globalPreferences, overrides[seriesId])
  }

  async loadSeriesOverrides(): Promise<Record<string, ReaderSeriesPreferenceOverrides>> {
    const store = await this.preferences()
    const payload = await store.get(SERIES_OVERRIDES_KEY, '') as string
    if (payload.length === 0) {
      return {}
    }
    try {
      const parsed = JSON.parse(payload) as Record<string, Object>
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return {}
      }
      const result: Record<string, ReaderSeriesPreferenceOverrides> = {}
      Object.keys(parsed).forEach((comicId: string): void => {
        const safeId = sanitizeReaderSeriesId(comicId)
        const overrides = normalizeReaderSeriesPreferenceOverrides(parsed[comicId])
        if (safeId !== undefined && overrides !== undefined) {
          result[safeId] = overrides
        }
      })
      return result
    } catch (_error) {
      return {}
    }
  }

  async saveSeriesPreferences(comicId: ComicId, overrides: ReaderSeriesPreferenceOverrides): Promise<void> {
    const seriesId = sanitizeReaderSeriesId(comicId)
    if (seriesId === undefined) {
      return
    }
    const normalized = normalizeReaderSeriesPreferenceOverrides(overrides)
    let allOverrides = await this.loadSeriesOverrides()
    if (normalized === undefined) {
      allOverrides = readerSeriesOverridesWithout(allOverrides, seriesId)
    } else {
      allOverrides[seriesId] = normalized
    }
    const store = await this.preferences()
    await store.put(SERIES_OVERRIDES_KEY, JSON.stringify(allOverrides))
    await store.flush()
  }

  async clearSeriesPreferences(comicId: ComicId): Promise<void> {
    const seriesId = sanitizeReaderSeriesId(comicId)
    if (seriesId === undefined) {
      return
    }
    const allOverrides = readerSeriesOverridesWithout(await this.loadSeriesOverrides(), seriesId)
    const store = await this.preferences()
    await store.put(SERIES_OVERRIDES_KEY, JSON.stringify(allOverrides))
    await store.flush()
  }

  async savePageMode(pageMode: ReaderPageMode): Promise<void> {
    const store = await this.preferences()
    await store.put(PAGE_MODE_KEY, pageMode)
    await store.flush()
  }

  async saveReadingDirection(readingDirection: ReadingDirection): Promise<void> {
    const store = await this.preferences()
    await store.put(READING_DIRECTION_KEY, readingDirection)
    await store.flush()
  }

  async saveThemeMode(themeMode: ReaderThemeMode): Promise<void> {
    const store = await this.preferences()
    await store.put(THEME_MODE_KEY, themeMode)
    await store.flush()
  }

  async saveBackgroundMode(backgroundMode: ReaderBackgroundMode): Promise<void> {
    const store = await this.preferences()
    await store.put(BACKGROUND_MODE_KEY, normalizeReaderBackgroundMode(backgroundMode))
    await store.flush()
  }

  async saveShowProgressControls(showProgressControls: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(SHOW_PROGRESS_CONTROLS_KEY, showProgressControls)
    await store.flush()
  }

  async saveKeepScreenAwake(keepScreenAwake: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(KEEP_SCREEN_AWAKE_KEY, keepScreenAwake)
    await store.flush()
  }

  async saveImageFitMode(imageFitMode: ReaderImageFitMode): Promise<void> {
    const store = await this.preferences()
    await store.put(IMAGE_FIT_MODE_KEY, normalizeReaderImageFitMode(imageFitMode))
    await store.flush()
  }

  async saveTapNavigationEnabled(tapNavigationEnabled: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(TAP_NAVIGATION_ENABLED_KEY, normalizeReaderTapNavigationEnabled(tapNavigationEnabled))
    await store.flush()
  }

  async saveSwipeNavigationEnabled(swipeNavigationEnabled: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(SWIPE_NAVIGATION_ENABLED_KEY, normalizeReaderSwipeNavigationEnabled(swipeNavigationEnabled))
    await store.flush()
  }

  async saveZoomGesturesEnabled(zoomGesturesEnabled: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(ZOOM_GESTURES_ENABLED_KEY, normalizeReaderZoomGesturesEnabled(zoomGesturesEnabled))
    await store.flush()
  }

  async saveTapZonePreset(tapZonePreset: ReaderTapZonePreset): Promise<void> {
    const store = await this.preferences()
    await store.put(TAP_ZONE_PRESET_KEY, normalizeReaderTapZonePreset(tapZonePreset))
    await store.flush()
  }

  async saveShowTapZones(showTapZones: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(SHOW_TAP_ZONES_KEY, normalizeReaderShowTapZones(showTapZones))
    await store.flush()
  }

  async savePageGapMode(pageGapMode: ReaderPageGapMode): Promise<void> {
    const store = await this.preferences()
    await store.put(PAGE_GAP_MODE_KEY, normalizeReaderPageGapMode(pageGapMode))
    await store.flush()
  }

  async saveTrimPageMarginsEnabled(trimPageMarginsEnabled: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(TRIM_PAGE_MARGINS_ENABLED_KEY, normalizeReaderTrimPageMarginsEnabled(trimPageMarginsEnabled))
    await store.flush()
  }

  async saveWideImageMode(wideImageMode: ReaderWideImageMode): Promise<void> {
    const store = await this.preferences()
    await store.put(WIDE_IMAGE_MODE_KEY, normalizeReaderWideImageMode(wideImageMode))
    await store.flush()
  }

  async saveVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled: boolean): Promise<void> {
    const store = await this.preferences()
    await store.put(VOLUME_KEY_NAVIGATION_ENABLED_KEY, normalizeReaderVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled))
    await store.flush()
  }

  async saveVolumeKeyBehavior(volumeKeyBehavior: ReaderVolumeKeyBehavior): Promise<void> {
    const store = await this.preferences()
    await store.put(VOLUME_KEY_BEHAVIOR_KEY, normalizeReaderVolumeKeyBehavior(volumeKeyBehavior))
    await store.flush()
  }

  async save(preferences: ReaderPreferences): Promise<void> {
    const store = await this.preferences()
    await store.put(PAGE_MODE_KEY, normalizeReaderPageMode(preferences.pageMode))
    await store.put(READING_DIRECTION_KEY, normalizeReaderReadingDirection(preferences.readingDirection))
    await store.put(THEME_MODE_KEY, normalizeReaderThemeMode(preferences.themeMode))
    await store.put(BACKGROUND_MODE_KEY, normalizeReaderBackgroundMode(preferences.backgroundMode))
    await store.put(SHOW_PROGRESS_CONTROLS_KEY, normalizeReaderProgressControls(preferences.showProgressControls))
    await store.put(KEEP_SCREEN_AWAKE_KEY, normalizeReaderKeepScreenAwake(preferences.keepScreenAwake))
    await store.put(IMAGE_FIT_MODE_KEY, normalizeReaderImageFitMode(preferences.imageFitMode))
    await store.put(TAP_NAVIGATION_ENABLED_KEY, normalizeReaderTapNavigationEnabled(preferences.tapNavigationEnabled))
    await store.put(SWIPE_NAVIGATION_ENABLED_KEY, normalizeReaderSwipeNavigationEnabled(preferences.swipeNavigationEnabled))
    await store.put(ZOOM_GESTURES_ENABLED_KEY, normalizeReaderZoomGesturesEnabled(preferences.zoomGesturesEnabled))
    await store.put(TAP_ZONE_PRESET_KEY, normalizeReaderTapZonePreset(preferences.tapZonePreset))
    await store.put(SHOW_TAP_ZONES_KEY, normalizeReaderShowTapZones(preferences.showTapZones))
    await store.put(PAGE_GAP_MODE_KEY, normalizeReaderPageGapMode(preferences.pageGapMode))
    await store.put(TRIM_PAGE_MARGINS_ENABLED_KEY, normalizeReaderTrimPageMarginsEnabled(preferences.trimPageMarginsEnabled))
    await store.put(WIDE_IMAGE_MODE_KEY, normalizeReaderWideImageMode(preferences.wideImageMode))
    await store.put(VOLUME_KEY_NAVIGATION_ENABLED_KEY, normalizeReaderVolumeKeyNavigationEnabled(preferences.volumeKeyNavigationEnabled))
    await store.put(VOLUME_KEY_BEHAVIOR_KEY, normalizeReaderVolumeKeyBehavior(preferences.volumeKeyBehavior))
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_PREFERENCES_STORE_NAME)
  }
}
