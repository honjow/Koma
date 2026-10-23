import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'
import { ReadingDirection } from './ComicModels'
import { ReaderModeSnapshot, ReaderModeStateBridge } from '../state/ReaderModeState'
import { KomaReaderBackend, connectKomaReaderBackendSelection } from '../state/KomaReaderBackendSelectionState'

export type ReaderPageMode = 'single_page' | 'double_page' | 'continuous_scroll' | 'vertical_page'
export type ReaderThemeMode = 'system' | 'light' | 'dark'
/** Matches NextE's persisted reader background contract. */
export type ReaderBackgroundMode = 'black' | 'gray' | 'white' | 'auto'
export type ReaderImageFitMode = 'contain' | 'fit_width' | 'fit_height'
export type ReaderImageScalingQuality = 'low' | 'medium' | 'high'
export type ReaderPageGapMode = 'compact' | 'normal' | 'wide'
export type ReaderTapZonePreset = 'edge' | 'wide_edges' | 'right_left' | 'l_shaped' | 'kindle'
export type ReaderTapZoneInvert = 'none' | 'horizontal' | 'vertical' | 'both'
export type ReaderVolumeKeyBehavior = 'up_previous_down_next' | 'up_next_down_previous'
export type ReaderWideImageMode = 'keep_single' | 'split_wide_pages' | 'rotate_wide_pages'
export type ReaderSpreadLayoutMode = 'joined' | 'split'
export type ReaderColumnMode = 'odd_left' | 'even_left'
export type ReaderImplementation = 'shared' | 'legacy'

export interface ReaderPreferences {
  pageMode: ReaderPageMode
  readingDirection: ReadingDirection
  themeMode: ReaderThemeMode
  backgroundMode: ReaderBackgroundMode
  showProgressControls: boolean
  keepScreenAwake: boolean
  fullscreen: boolean
  imageFitMode: ReaderImageFitMode
  imageScalingQuality: ReaderImageScalingQuality
  showPageNumber: boolean
  pageTurnAnimation: boolean
  autoPageSeconds: number
  preloadPages: number
  spreadLayoutMode: ReaderSpreadLayoutMode
  columnMode: ReaderColumnMode
  tapZonePreset: ReaderTapZonePreset
  tapZoneInvert: ReaderTapZoneInvert
  pageGapMode: ReaderPageGapMode
  trimPageMarginsEnabled: boolean
  wideImageMode: ReaderWideImageMode
  volumeKeyNavigationEnabled: boolean
  volumeKeyBehavior: ReaderVolumeKeyBehavior
  readerImplementation: ReaderImplementation
}

const READER_PREFERENCES_STORE_NAME: string = 'koma_reader_preferences_v1'
export const SERIES_OVERRIDES_KEY: string = 'reader.seriesOverrides.v1'
/**
 * RDR-005 narrow per-series override. Deliberately a DIFFERENT key and a
 * DIFFERENT shape from the legacy `SERIES_OVERRIDES_KEY` whole-preference
 * snapshots: only the two settings a reader legitimately wants per book, so a
 * per-book choice can never silently shadow the global defaults of the other
 * twenty settings. The legacy payload stays readable for backup/migration and
 * is still not consumed at runtime.
 */
export const SERIES_MODE_OVERRIDES_KEY: string = 'reader.seriesModeOverrides.v1'

export interface ReaderSeriesModeOverride {
  pageMode: ReaderPageMode
  readingDirection: ReadingDirection
}

/** Explicit commands reconcile legacy WEBTOON without rewriting stored data on load.
 * Horizontal direction remains dormant while a vertical mode owns movement. */
export function readerModeSelection(current: ReaderSeriesModeOverride, pageMode: ReaderPageMode): ReaderSeriesModeOverride {
  return {
    pageMode,
    readingDirection: pageMode !== 'continuous_scroll' && current.readingDirection === ReadingDirection.WEBTOON
      ? ReadingDirection.LEFT_TO_RIGHT : current.readingDirection,
  }
}

export function readerDirectionSelection(current: ReaderSeriesModeOverride, readingDirection: ReadingDirection): ReaderSeriesModeOverride {
  return {
    pageMode: readingDirection === ReadingDirection.WEBTOON ? 'continuous_scroll' : current.pageMode,
    readingDirection,
  }
}

export const DEFAULT_READER_PREFERENCES: ReaderPreferences = {
  pageMode: 'single_page',
  readingDirection: ReadingDirection.LEFT_TO_RIGHT,
  themeMode: 'system',
  backgroundMode: 'black',
  showProgressControls: true,
  keepScreenAwake: true,
  fullscreen: true,
  imageFitMode: 'fit_width',
  imageScalingQuality: 'medium',
  showPageNumber: true,
  pageTurnAnimation: true,
  autoPageSeconds: 3,
  preloadPages: 2,
  spreadLayoutMode: 'joined',
  columnMode: 'odd_left',
  // NextE's default RIGHT_LEFT layout is the neutral three-zone contract;
  // legacy edge layouts remain available as explicit user choices.
  tapZonePreset: 'right_left',
  tapZoneInvert: 'none',
  pageGapMode: 'normal',
  trimPageMarginsEnabled: false,
  wideImageMode: 'keep_single',
  volumeKeyNavigationEnabled: false,
  volumeKeyBehavior: 'up_previous_down_next',
  readerImplementation: 'shared',
}

export function normalizeReaderPageMode(value: string): ReaderPageMode {
  if (value === 'double_page' || value === 'continuous_scroll' || value === 'vertical_page') {
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
  if (value === 'gray' || value === 'white' || value === 'auto') {
    return value
  }
  // Migrate the pre-alignment Koma names without changing the visual intent.
  if (value === 'paper') {
    return 'gray'
  }
  if (value === 'light') {
    return 'white'
  }
  return 'black'
}

export function normalizeReaderImageFitMode(value: string): ReaderImageFitMode {
  if (value === 'fit_width' || value === 'fit_height') {
    return value
  }
  return 'contain'
}

export function normalizeReaderImageScalingQuality(value: string): ReaderImageScalingQuality {
  if (value === 'low' || value === 'high') {
    return value
  }
  return 'medium'
}

export function normalizeReaderSpreadLayoutMode(value: string): ReaderSpreadLayoutMode {
  return value === 'split' ? 'split' : 'joined'
}

export function normalizeReaderColumnMode(value: string): ReaderColumnMode {
  return value === 'even_left' ? 'even_left' : 'odd_left'
}

export function normalizeReaderAutoPageSeconds(value: number): number {
  if (!Number.isFinite(value)) {
    return 3
  }
  return Math.max(1, Math.min(60, Math.round(value)))
}

export function normalizeReaderPreloadPages(value: number): number {
  if (!Number.isFinite(value)) {
    return 2
  }
  return Math.max(0, Math.min(5, Math.round(value)))
}

export function normalizeReaderPageGapMode(value: string): ReaderPageGapMode {
  if (value === 'compact' || value === 'wide') {
    return value
  }
  return 'normal'
}

export function normalizeReaderTapZonePreset(value: string): ReaderTapZonePreset {
  if (value === 'edge' || value === 'wide_edges' || value === 'right_left' || value === 'l_shaped' || value === 'kindle') {
    return value
  }
  return 'right_left'
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
    readingDirection: value.readingDirection === ReadingDirection.RIGHT_TO_LEFT
      ? ReadingDirection.RIGHT_TO_LEFT
      : (value.readingDirection === ReadingDirection.WEBTOON
        ? ReadingDirection.WEBTOON
        : ReadingDirection.LEFT_TO_RIGHT),
    themeMode: normalizeReaderThemeMode(value.themeMode),
    backgroundMode: normalizeReaderBackgroundMode(value.backgroundMode),
    showProgressControls: value.showProgressControls !== false,
    keepScreenAwake: value.keepScreenAwake !== false,
    fullscreen: value.fullscreen !== false,
    imageFitMode: normalizeReaderImageFitMode(value.imageFitMode),
    imageScalingQuality: normalizeReaderImageScalingQuality(value.imageScalingQuality),
    showPageNumber: value.showPageNumber !== false,
    pageTurnAnimation: value.pageTurnAnimation !== false,
    autoPageSeconds: normalizeReaderAutoPageSeconds(value.autoPageSeconds),
    preloadPages: normalizeReaderPreloadPages(value.preloadPages),
    spreadLayoutMode: normalizeReaderSpreadLayoutMode(value.spreadLayoutMode),
    columnMode: normalizeReaderColumnMode(value.columnMode),
    tapZonePreset: normalizeReaderTapZonePreset(value.tapZonePreset),
    tapZoneInvert: normalizeReaderTapZoneInvert(value.tapZoneInvert),
    pageGapMode: normalizeReaderPageGapMode(value.pageGapMode),
    trimPageMarginsEnabled: value.trimPageMarginsEnabled === true,
    readerImplementation: value.readerImplementation === 'legacy' ? 'legacy' : 'shared',
    wideImageMode: normalizeReaderWideImageMode(value.wideImageMode),
    volumeKeyNavigationEnabled: value.volumeKeyNavigationEnabled === true,
    volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(value.volumeKeyBehavior),
  }
}

/**
 * Convert the shared runtime state into the persisted contract.  Pairing is
 * deliberately injected from the current ReaderSessionStore rather than read
 * from global preferences, matching NextE's per-gallery column mode.
 */
export function readerPreferencesFromRuntimeState(columnMode: ReaderColumnMode): ReaderPreferences {
  const runtime = ReaderModeStateBridge.snapshot(columnMode)
  return normalizeReaderPreferences({
    pageMode: normalizeReaderPageMode(runtime.pageMode),
    readingDirection: normalizeReaderDirection(runtime.readingDirection, ReadingDirection.LEFT_TO_RIGHT),
    themeMode: normalizeReaderThemeMode(runtime.themeMode),
    backgroundMode: normalizeReaderBackgroundMode(runtime.backgroundMode),
    showProgressControls: runtime.showProgressControls,
    keepScreenAwake: runtime.keepScreenAwake,
    fullscreen: runtime.fullscreen,
    imageFitMode: normalizeReaderImageFitMode(runtime.imageFitMode),
    imageScalingQuality: normalizeReaderImageScalingQuality(runtime.imageScalingQuality),
    showPageNumber: runtime.showPageNumber,
    pageTurnAnimation: runtime.pageTurnAnimation,
    autoPageSeconds: normalizeReaderAutoPageSeconds(runtime.autoPageSeconds),
    preloadPages: normalizeReaderPreloadPages(runtime.preloadPages),
    spreadLayoutMode: normalizeReaderSpreadLayoutMode(runtime.spreadLayoutMode),
    columnMode: normalizeReaderColumnMode(runtime.columnMode),
    tapZonePreset: normalizeReaderTapZonePreset(runtime.tapZonePreset),
    tapZoneInvert: normalizeReaderTapZoneInvert(runtime.tapZoneInvert),
    pageGapMode: normalizeReaderPageGapMode(runtime.pageGapMode),
    trimPageMarginsEnabled: runtime.trimPageMarginsEnabled,
    readerImplementation: connectKomaReaderBackendSelection().current(true),
    wideImageMode: normalizeReaderWideImageMode(runtime.wideImageMode),
    volumeKeyNavigationEnabled: runtime.volumeKeyNavigationEnabled,
    volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(runtime.volumeKeyBehavior),
  })
}

function publishReaderModeState(preferences: ReaderPreferences): void {
  applyPublishedTheme(preferences.themeMode)
  ReaderModeStateBridge.publish(new ReaderModeSnapshot(
    preferences.pageMode,
    preferences.readingDirection,
    preferences.themeMode,
    preferences.backgroundMode,
    preferences.showProgressControls,
    preferences.keepScreenAwake,
    preferences.fullscreen,
    preferences.imageFitMode,
    preferences.imageScalingQuality,
    preferences.showPageNumber,
    preferences.pageTurnAnimation,
    preferences.autoPageSeconds,
    preferences.preloadPages,
    preferences.spreadLayoutMode,
    preferences.tapZonePreset,
    preferences.tapZoneInvert,
    preferences.pageGapMode,
    preferences.trimPageMarginsEnabled,
    preferences.wideImageMode,
    preferences.volumeKeyNavigationEnabled,
    preferences.volumeKeyBehavior,
    preferences.columnMode,
  ))
  connectKomaReaderBackendSelection().select(
    preferences.readerImplementation === 'legacy' ? KomaReaderBackend.LEGACY : KomaReaderBackend.SHARED, true)
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
    fullscreen: booleanField(record, 'fullscreen', fallback.fullscreen),
    imageFitMode: normalizeReaderImageFitMode(stringField(record, 'imageFitMode', fallback.imageFitMode)),
    imageScalingQuality: normalizeReaderImageScalingQuality(stringField(record, 'imageScalingQuality', fallback.imageScalingQuality)),
    showPageNumber: booleanField(record, 'showPageNumber', fallback.showPageNumber),
    pageTurnAnimation: booleanField(record, 'pageTurnAnimation', fallback.pageTurnAnimation),
    autoPageSeconds: normalizeReaderAutoPageSeconds(Number(record['autoPageSeconds'] ?? fallback.autoPageSeconds)),
    preloadPages: normalizeReaderPreloadPages(Number(record['preloadPages'] ?? fallback.preloadPages)),
    spreadLayoutMode: normalizeReaderSpreadLayoutMode(stringField(record, 'spreadLayoutMode', fallback.spreadLayoutMode)),
    columnMode: normalizeReaderColumnMode(stringField(record, 'columnMode', fallback.columnMode)),
    tapZonePreset: normalizeReaderTapZonePreset(stringField(record, 'tapZonePreset', fallback.tapZonePreset)),
    tapZoneInvert: normalizeReaderTapZoneInvert(stringField(record, 'tapZoneInvert', fallback.tapZoneInvert)),
    pageGapMode: normalizeReaderPageGapMode(stringField(record, 'pageGapMode', fallback.pageGapMode)),
    trimPageMarginsEnabled: booleanField(record, 'trimPageMarginsEnabled', fallback.trimPageMarginsEnabled),
    readerImplementation: normalizeReaderImplementation(
      stringField(record, 'readerImplementation', fallback.readerImplementation)),
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

/**
 * RDR-005 normalize the narrow per-series override payload: only pageMode and
 * readingDirection are accepted, so an old or hand-edited payload can never
 * drag a whole preference snapshot back into the live reader. Corrupt rows and
 * empty comic identifiers are discarded, matching the legacy normalizer.
 */
export function normalizeReaderSeriesModeOverrides(value: string): Record<string, ReaderSeriesModeOverride> {
  if (value.length === 0) {
    return {}
  }
  let parsed: Object
  try {
    parsed = JSON.parse(value) as Object
  } catch (_error) {
    return {}
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    return {}
  }
  const source = parsed as Record<string, Object>
  const normalized: Record<string, ReaderSeriesModeOverride> = {}
  Object.keys(source).forEach((comicId: string) => {
    const key = comicId.trim()
    const raw = source[comicId]
    if (key.length === 0 || raw === undefined || raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
      return
    }
    const record = raw as Record<string, Object>
    const pageMode = record.pageMode
    const readingDirection = record.readingDirection
    if (typeof pageMode !== 'string' || typeof readingDirection !== 'string') {
      return
    }
    normalized[key] = {
      pageMode: normalizeReaderPageMode(pageMode),
      readingDirection: normalizeReaderDirection(readingDirection, DEFAULT_READER_PREFERENCES.readingDirection),
    }
  })
  return normalized
}

/** RDR-005 apply a comic's narrow override on top of the global defaults. */
export function applyReaderSeriesModeOverride(
  preferences: ReaderPreferences,
  override: ReaderSeriesModeOverride | undefined,
): ReaderPreferences {
  if (override === undefined) {
    return preferences
  }
  return {
    readerImplementation: preferences.readerImplementation,
    pageMode: override.pageMode,
    readingDirection: override.readingDirection,
    themeMode: preferences.themeMode,
    backgroundMode: preferences.backgroundMode,
    showProgressControls: preferences.showProgressControls,
    keepScreenAwake: preferences.keepScreenAwake,
    fullscreen: preferences.fullscreen,
    imageFitMode: preferences.imageFitMode,
    imageScalingQuality: preferences.imageScalingQuality,
    showPageNumber: preferences.showPageNumber,
    pageTurnAnimation: preferences.pageTurnAnimation,
    autoPageSeconds: preferences.autoPageSeconds,
    preloadPages: preferences.preloadPages,
    spreadLayoutMode: preferences.spreadLayoutMode,
    columnMode: preferences.columnMode,
    tapZonePreset: preferences.tapZonePreset,
    tapZoneInvert: preferences.tapZoneInvert,
    pageGapMode: preferences.pageGapMode,
    trimPageMarginsEnabled: preferences.trimPageMarginsEnabled,
    wideImageMode: preferences.wideImageMode,
    volumeKeyNavigationEnabled: preferences.volumeKeyNavigationEnabled,
    volumeKeyBehavior: preferences.volumeKeyBehavior,
  }
}

export function getReaderPageModeLabel(mode: ReaderPageMode): string {
  if (mode === 'double_page') {
    return AppStrings.get('reader_page_mode_double')
  }
  if (mode === 'continuous_scroll') {
    return AppStrings.get('reader_page_mode_continuous')
  }
  if (mode === 'vertical_page') {
    return AppStrings.get('reader_page_mode_vertical_page')
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
  if (mode === 'gray') {
    return AppStrings.get('reader_background_gray')
  }
  if (mode === 'white') {
    return AppStrings.get('reader_background_white')
  }
  if (mode === 'auto') {
    return AppStrings.get('reader_background_auto')
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

export function getReaderTrimPageMarginsLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

export function getReaderVolumeKeyNavigationLabel(enabled: boolean): string {
  return enabled ? AppStrings.get('common_on') : AppStrings.get('common_off')
}

// ApplicationContext.setColorMode requires a successfully loaded window.
let themeContext: common.UIAbilityContext | undefined = undefined
let appliedThemeMode: ReaderThemeMode | undefined = undefined

export function bindReaderThemeWindow(context: common.UIAbilityContext): void {
  themeContext = context
  appliedThemeMode = undefined
}

export function unbindReaderThemeWindow(): void {
  themeContext = undefined
  appliedThemeMode = undefined
}

function applyPublishedTheme(mode: ReaderThemeMode): void {
  if (themeContext === undefined || appliedThemeMode === mode) return
  const colorMode = mode === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    : mode === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  themeContext.getApplicationContext().setColorMode(colorMode)
  appliedThemeMode = mode
}

/** Apply only the fields changed by one UI action to the latest committed preferences. */
export function rebaseReaderPreferenceChanges(base: ReaderPreferences, previous: ReaderPreferences,
  next: ReaderPreferences): ReaderPreferences {
  const rebased = normalizeReaderPreferences(base)
  if (previous.pageMode !== next.pageMode) rebased.pageMode = next.pageMode
  if (previous.readingDirection !== next.readingDirection) rebased.readingDirection = next.readingDirection
  if (previous.themeMode !== next.themeMode) rebased.themeMode = next.themeMode
  if (previous.backgroundMode !== next.backgroundMode) rebased.backgroundMode = next.backgroundMode
  if (previous.showProgressControls !== next.showProgressControls) rebased.showProgressControls = next.showProgressControls
  if (previous.keepScreenAwake !== next.keepScreenAwake) rebased.keepScreenAwake = next.keepScreenAwake
  if (previous.fullscreen !== next.fullscreen) rebased.fullscreen = next.fullscreen
  if (previous.imageFitMode !== next.imageFitMode) rebased.imageFitMode = next.imageFitMode
  if (previous.imageScalingQuality !== next.imageScalingQuality) rebased.imageScalingQuality = next.imageScalingQuality
  if (previous.showPageNumber !== next.showPageNumber) rebased.showPageNumber = next.showPageNumber
  if (previous.pageTurnAnimation !== next.pageTurnAnimation) rebased.pageTurnAnimation = next.pageTurnAnimation
  if (previous.autoPageSeconds !== next.autoPageSeconds) rebased.autoPageSeconds = next.autoPageSeconds
  if (previous.preloadPages !== next.preloadPages) rebased.preloadPages = next.preloadPages
  if (previous.spreadLayoutMode !== next.spreadLayoutMode) rebased.spreadLayoutMode = next.spreadLayoutMode
  if (previous.columnMode !== next.columnMode) rebased.columnMode = next.columnMode
  if (previous.tapZonePreset !== next.tapZonePreset) rebased.tapZonePreset = next.tapZonePreset
  if (previous.tapZoneInvert !== next.tapZoneInvert) rebased.tapZoneInvert = next.tapZoneInvert
  if (previous.pageGapMode !== next.pageGapMode) rebased.pageGapMode = next.pageGapMode
  if (previous.trimPageMarginsEnabled !== next.trimPageMarginsEnabled) rebased.trimPageMarginsEnabled = next.trimPageMarginsEnabled
  if (previous.wideImageMode !== next.wideImageMode) rebased.wideImageMode = next.wideImageMode
  if (previous.volumeKeyNavigationEnabled !== next.volumeKeyNavigationEnabled) rebased.volumeKeyNavigationEnabled = next.volumeKeyNavigationEnabled
  if (previous.volumeKeyBehavior !== next.volumeKeyBehavior) rebased.volumeKeyBehavior = next.volumeKeyBehavior
  if (previous.readerImplementation !== next.readerImplementation) rebased.readerImplementation = next.readerImplementation
  return normalizeReaderPreferences(rebased)
}

// One ordering owner per persisted app resource, shared by every Store instance.
const readerPreferenceOperations: Map<string, Promise<void>> = new Map()

export class ReaderPreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const preceding = readerPreferenceOperations.get(key) ?? Promise.resolve()
    const result = preceding.then(operation)
    readerPreferenceOperations.set(key, result.then(() => {}, () => {}))
    return result
  }

  private mutate(operation: () => Promise<ReaderPreferences>): Promise<ReaderPreferences> {
    // Count queued writers too: restore must not enter ahead of an admitted edit.
    return BackupRestoreActivity.runWrite(() => this.ordered(operation))
  }

  private mutatePreferences(change: (next: ReaderPreferences) => void): Promise<ReaderPreferences> {
    return this.mutate(async (): Promise<ReaderPreferences> => {
      const next = await this.readPreferences()
      change(next)
      return this.persistPreferences(next)
    })
  }

  async load(): Promise<ReaderPreferences> {
    return this.ordered(async (): Promise<ReaderPreferences> => {
      const current = await this.readPreferences()
      publishReaderModeState(current)
      return current
    })
  }

  private async readPreferences(): Promise<ReaderPreferences> {
    const store = await this.preferences()
    const pageMode = await store.get('reader.pageMode', DEFAULT_READER_PREFERENCES.pageMode) as string
    const readingDirection = await store.get('reader.readingDirection', DEFAULT_READER_PREFERENCES.readingDirection) as string
    const themeMode = await store.get('reader.themeMode', DEFAULT_READER_PREFERENCES.themeMode) as string
    const backgroundMode = await store.get('reader.backgroundMode', DEFAULT_READER_PREFERENCES.backgroundMode) as string
    const showProgressControls = await store.get('reader.showProgressControls', DEFAULT_READER_PREFERENCES.showProgressControls) as boolean
    const keepScreenAwake = await store.get('reader.keepScreenAwake', DEFAULT_READER_PREFERENCES.keepScreenAwake) as boolean
    const fullscreen = await store.get('reader.fullscreen', DEFAULT_READER_PREFERENCES.fullscreen) as boolean
    const imageFitMode = await store.get('reader.imageFitMode', DEFAULT_READER_PREFERENCES.imageFitMode) as string
    const imageScalingQuality = await store.get('reader.imageScalingQuality', DEFAULT_READER_PREFERENCES.imageScalingQuality) as string
    const showPageNumber = await store.get('reader.showPageNumber', DEFAULT_READER_PREFERENCES.showPageNumber) as boolean
    const pageTurnAnimation = await store.get('reader.pageTurnAnimation', DEFAULT_READER_PREFERENCES.pageTurnAnimation) as boolean
    const autoPageSeconds = await store.get('reader.autoPageSeconds', DEFAULT_READER_PREFERENCES.autoPageSeconds) as number
    const preloadPages = await store.get('reader.preloadPages', DEFAULT_READER_PREFERENCES.preloadPages) as number
    const spreadLayoutMode = await store.get('reader.spreadLayoutMode', DEFAULT_READER_PREFERENCES.spreadLayoutMode) as string
    const columnMode = await store.get('reader.columnMode', DEFAULT_READER_PREFERENCES.columnMode) as string
    const tapZonePreset = await store.get('reader.tapZonePreset', DEFAULT_READER_PREFERENCES.tapZonePreset) as string
    const tapZoneInvert = await store.get('reader.tapZoneInvert', DEFAULT_READER_PREFERENCES.tapZoneInvert) as string
    const pageGapMode = await store.get('reader.pageGapMode', DEFAULT_READER_PREFERENCES.pageGapMode) as string
    const trimPageMarginsEnabled = await store.get('reader.trimPageMarginsEnabled', DEFAULT_READER_PREFERENCES.trimPageMarginsEnabled) as boolean
    const readerImplementation = await store.get('reader.readerImplementation', DEFAULT_READER_PREFERENCES.readerImplementation) as string
    const wideImageMode = await store.get('reader.wideImageMode', DEFAULT_READER_PREFERENCES.wideImageMode) as string
    const volumeKeyNavigationEnabled = await store.get('reader.volumeKeyNavigationEnabled', DEFAULT_READER_PREFERENCES.volumeKeyNavigationEnabled) as boolean
    const volumeKeyBehavior = await store.get('reader.volumeKeyBehavior', DEFAULT_READER_PREFERENCES.volumeKeyBehavior) as string
    const normalized = normalizeReaderPreferences({
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
      fullscreen,
      imageFitMode: normalizeReaderImageFitMode(imageFitMode),
      imageScalingQuality: normalizeReaderImageScalingQuality(imageScalingQuality),
      showPageNumber,
      pageTurnAnimation,
      autoPageSeconds: normalizeReaderAutoPageSeconds(autoPageSeconds),
      preloadPages: normalizeReaderPreloadPages(preloadPages),
      spreadLayoutMode: normalizeReaderSpreadLayoutMode(spreadLayoutMode),
      columnMode: normalizeReaderColumnMode(columnMode),
      tapZonePreset: normalizeReaderTapZonePreset(tapZonePreset),
      tapZoneInvert: normalizeReaderTapZoneInvert(tapZoneInvert),
      pageGapMode: normalizeReaderPageGapMode(pageGapMode),
      trimPageMarginsEnabled,
      readerImplementation: normalizeReaderImplementation(readerImplementation),
      wideImageMode: normalizeReaderWideImageMode(wideImageMode),
      volumeKeyNavigationEnabled,
      volumeKeyBehavior: normalizeReaderVolumeKeyBehavior(volumeKeyBehavior),
    })
    return normalized
  }

  async loadForComic(comicId: string): Promise<ReaderPreferences> {
    return this.ordered(async (): Promise<ReaderPreferences> => {
      const base = await this.readPreferences()
      const override = (await this.readSeriesModeOverrides())[comicId.trim()]
      const effective = normalizeReaderPreferences(applyReaderSeriesModeOverride(base, override))
      publishReaderModeState(effective)
      return effective
    })
  }

  /** Full replacement is intentional only for reset/import, not a reader UI edit. */
  async save(preferences: ReaderPreferences): Promise<ReaderPreferences> {
    const requested = normalizeReaderPreferences(preferences)
    return this.mutate(() => this.persistPreferences(requested))
  }

  async saveChanges(previous: ReaderPreferences, next: ReaderPreferences): Promise<ReaderPreferences> {
    const before = normalizeReaderPreferences(previous)
    const requested = normalizeReaderPreferences(next)
    return this.mutate(async (): Promise<ReaderPreferences> => {
      const current = await this.readPreferences()
      return this.persistPreferences(rebaseReaderPreferenceChanges(current, before, requested))
    })
  }

  async saveForBackupRestore(preferences: ReaderPreferences): Promise<ReaderPreferences> {
    if (!BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_not_active')
    const requested = normalizeReaderPreferences(preferences)
    return this.ordered(() => this.persistPreferences(requested))
  }

  private async persistPreferences(preferences: ReaderPreferences, publish: boolean = true,
    seriesModeOverrides: string | undefined = undefined): Promise<ReaderPreferences> {
    const normalized = normalizeReaderPreferences(preferences)
    const store = await this.preferences()
    const keys: string[] = [
      'reader.pageMode',
      'reader.readingDirection',
      'reader.themeMode',
      'reader.backgroundMode',
      'reader.showProgressControls',
      'reader.keepScreenAwake',
      'reader.fullscreen',
      'reader.imageFitMode',
      'reader.imageScalingQuality',
      'reader.showPageNumber',
      'reader.pageTurnAnimation',
      'reader.autoPageSeconds',
      'reader.preloadPages',
      'reader.spreadLayoutMode',
      'reader.columnMode',
      'reader.tapZonePreset',
      'reader.tapZoneInvert',
      'reader.pageGapMode',
      'reader.trimPageMarginsEnabled',
      'reader.readerImplementation',
      'reader.wideImageMode',
      'reader.volumeKeyNavigationEnabled',
      'reader.volumeKeyBehavior',
    ]
    // A book edit commits its global fields and narrow override together.
    if (seriesModeOverrides !== undefined) keys.push(SERIES_MODE_OVERRIDES_KEY)
    const previous: Map<string, preferences.ValueType> = new Map()
    for (const key of keys) {
      if (await store.has(key)) previous.set(key, await store.get(key, ''))
    }
    try {
      await store.put('reader.pageMode', normalized.pageMode)
      await store.put('reader.readingDirection', normalized.readingDirection)
      await store.put('reader.themeMode', normalized.themeMode)
      await store.put('reader.backgroundMode', normalized.backgroundMode)
      await store.put('reader.showProgressControls', normalized.showProgressControls)
      await store.put('reader.keepScreenAwake', normalized.keepScreenAwake)
      await store.put('reader.fullscreen', normalized.fullscreen)
      await store.put('reader.imageFitMode', normalized.imageFitMode)
      await store.put('reader.imageScalingQuality', normalized.imageScalingQuality)
      await store.put('reader.showPageNumber', normalized.showPageNumber)
      await store.put('reader.pageTurnAnimation', normalized.pageTurnAnimation)
      await store.put('reader.autoPageSeconds', normalized.autoPageSeconds)
      await store.put('reader.preloadPages', normalized.preloadPages)
      await store.put('reader.spreadLayoutMode', normalized.spreadLayoutMode)
      await store.put('reader.columnMode', normalized.columnMode)
      await store.put('reader.tapZonePreset', normalized.tapZonePreset)
      await store.put('reader.tapZoneInvert', normalized.tapZoneInvert)
      await store.put('reader.pageGapMode', normalized.pageGapMode)
      await store.put('reader.trimPageMarginsEnabled', normalized.trimPageMarginsEnabled)
      await store.put('reader.readerImplementation', normalized.readerImplementation)
      await store.put('reader.wideImageMode', normalized.wideImageMode)
      await store.put('reader.volumeKeyNavigationEnabled', normalized.volumeKeyNavigationEnabled)
      await store.put('reader.volumeKeyBehavior', normalized.volumeKeyBehavior)
      if (seriesModeOverrides !== undefined) await store.put(SERIES_MODE_OVERRIDES_KEY, seriesModeOverrides)
      await store.flush()
      applyPublishedTheme(normalized.themeMode)
    } catch (error) {
      // Restore the Preferences cache as well as disk before another ordered writer runs.
      try {
        for (const key of keys) {
          if (previous.has(key)) await store.put(key, previous.get(key)!)
          else await store.delete(key)
        }
        await store.flush()
      } catch (_rollbackError) {
        throw new Error('reader_preferences_restore_failed')
      }
      throw error as Error
    }
    if (publish) publishReaderModeState(normalized)
    return normalized
  }

  async saveChangesForComic(comicId: string, previous: ReaderPreferences,
    next: ReaderPreferences): Promise<ReaderPreferences> {
    const before = normalizeReaderPreferences(previous)
    const requested = normalizeReaderPreferences(next)
    return this.mutate(async (): Promise<ReaderPreferences> => {
      const global = await this.readPreferences()
      const override = (await this.readSeriesModeOverrides())[comicId.trim()]
      const current = normalizeReaderPreferences(applyReaderSeriesModeOverride(global, override))
      // Column alignment is session-owned; it is never taken from a global echo.
      current.columnMode = before.columnMode
      return this.persistForComic(comicId,
        rebaseReaderPreferenceChanges(current, before, requested), global)
    })
  }

  private async persistForComic(comicId: string, requested: ReaderPreferences,
    currentGlobal: ReaderPreferences): Promise<ReaderPreferences> {
    const narrowed = this.cloneBase(requested)
    // Keep global defaults, narrow book overrides and session pairing separate.
    narrowed.pageMode = currentGlobal.pageMode
    narrowed.readingDirection = currentGlobal.readingDirection
    narrowed.columnMode = currentGlobal.columnMode
    const key = comicId.trim()
    let seriesModeOverrides: string | undefined = undefined
    if (key.length > 0) {
      const overrides = await this.readSeriesModeOverrides()
      if (requested.pageMode !== currentGlobal.pageMode ||
        requested.readingDirection !== currentGlobal.readingDirection) {
        overrides[key] = {
          pageMode: requested.pageMode,
          readingDirection: requested.readingDirection,
        }
        seriesModeOverrides = JSON.stringify(overrides)
      } else if (overrides[key] !== undefined) {
        const remaining: Record<string, ReaderSeriesModeOverride> = {}
        Object.keys(overrides).forEach((id: string) => {
          if (id !== key) remaining[id] = overrides[id]
        })
        seriesModeOverrides = JSON.stringify(remaining)
      }
    }
    const normalized = await this.persistPreferences(narrowed, false, seriesModeOverrides)
    const effective = this.cloneBase(normalized)
    effective.pageMode = requested.pageMode
    effective.readingDirection = requested.readingDirection
    effective.columnMode = requested.columnMode
    publishReaderModeState(effective)
    return effective
  }

  /** RDR-005 read back this comic's narrow override, if it has one. */
  async seriesModeOverride(comicId: string): Promise<ReaderSeriesModeOverride | undefined> {
    const key = comicId.trim()
    if (key.length === 0) {
      return undefined
    }
    return this.ordered(async (): Promise<ReaderSeriesModeOverride | undefined> =>
      (await this.readSeriesModeOverrides())[key])
  }

  /** RDR-005 恢复默认: drop this comic's override and return the global defaults. */
  async clearSeriesOverride(comicId: string): Promise<ReaderPreferences> {
    return this.mutate(async (): Promise<ReaderPreferences> => {
      await this.clearSeriesModeOverride(comicId)
      const current = await this.readPreferences()
      publishReaderModeState(current)
      return current
    })
  }

  private async clearSeriesModeOverride(comicId: string): Promise<void> {
    const key = comicId.trim()
    if (key.length === 0) {
      return
    }
    const overrides = await this.readSeriesModeOverrides()
    if (overrides[key] === undefined) {
      return
    }
    const remaining: Record<string, ReaderSeriesModeOverride> = {}
    Object.keys(overrides).forEach((id: string) => {
      if (id !== key) {
        remaining[id] = overrides[id]
      }
    })
    await this.writeSeriesModeOverrides(remaining)
  }

  private async readSeriesModeOverrides(): Promise<Record<string, ReaderSeriesModeOverride>> {
    const store = await this.preferences()
    const raw = await store.get(SERIES_MODE_OVERRIDES_KEY, '') as string
    return normalizeReaderSeriesModeOverrides(raw)
  }

  private async writeSeriesModeOverrides(overrides: Record<string, ReaderSeriesModeOverride>): Promise<void> {
    const store = await this.preferences()
    const hadPrevious = await store.has(SERIES_MODE_OVERRIDES_KEY)
    const previous = await store.get(SERIES_MODE_OVERRIDES_KEY, '')
    try {
      await store.put(SERIES_MODE_OVERRIDES_KEY, JSON.stringify(overrides))
      await store.flush()
    } catch (error) {
      try {
        if (hadPrevious) await store.put(SERIES_MODE_OVERRIDES_KEY, previous)
        else await store.delete(SERIES_MODE_OVERRIDES_KEY)
        await store.flush()
      } catch (_rollbackError) {
        throw new Error('reader_preferences_restore_failed')
      }
      throw error as Error
    }
  }

  private cloneBase(current: ReaderPreferences): ReaderPreferences {
    return {
      pageMode: current.pageMode,
      readingDirection: current.readingDirection,
      themeMode: current.themeMode,
      backgroundMode: current.backgroundMode,
      showProgressControls: current.showProgressControls,
      keepScreenAwake: current.keepScreenAwake,
      fullscreen: current.fullscreen,
      imageFitMode: current.imageFitMode,
      imageScalingQuality: current.imageScalingQuality,
      showPageNumber: current.showPageNumber,
      pageTurnAnimation: current.pageTurnAnimation,
      autoPageSeconds: current.autoPageSeconds,
      preloadPages: current.preloadPages,
      spreadLayoutMode: current.spreadLayoutMode,
      columnMode: current.columnMode,
      tapZonePreset: current.tapZonePreset,
      tapZoneInvert: current.tapZoneInvert,
      pageGapMode: current.pageGapMode,
      trimPageMarginsEnabled: current.trimPageMarginsEnabled,
      readerImplementation: current.readerImplementation,
      wideImageMode: current.wideImageMode,
      volumeKeyNavigationEnabled: current.volumeKeyNavigationEnabled,
      volumeKeyBehavior: current.volumeKeyBehavior,
    }
  }

  async savePageMode(pageMode: ReaderPageMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      const choice = readerModeSelection({ pageMode: next.pageMode, readingDirection: next.readingDirection }, pageMode)
      next.pageMode = choice.pageMode
      next.readingDirection = choice.readingDirection
    })
  }

  async saveReadingDirection(readingDirection: ReadingDirection): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      const choice = readerDirectionSelection({ pageMode: next.pageMode, readingDirection: next.readingDirection }, readingDirection)
      next.pageMode = choice.pageMode
      next.readingDirection = choice.readingDirection
    })
  }

  async saveSpreadLayoutMode(spreadLayoutMode: ReaderSpreadLayoutMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.spreadLayoutMode = normalizeReaderSpreadLayoutMode(spreadLayoutMode)
    })
  }

  async saveThemeMode(themeMode: ReaderThemeMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.themeMode = themeMode
    })
  }

  async saveBackgroundMode(backgroundMode: ReaderBackgroundMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.backgroundMode = backgroundMode
    })
  }

  async saveImageScalingQuality(imageScalingQuality: ReaderImageScalingQuality): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.imageScalingQuality = normalizeReaderImageScalingQuality(imageScalingQuality)
    })
  }

  async saveShowPageNumber(showPageNumber: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.showPageNumber = showPageNumber
    })
  }

  async saveFullscreen(fullscreen: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.fullscreen = fullscreen
    })
  }

  async savePageTurnAnimation(pageTurnAnimation: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.pageTurnAnimation = pageTurnAnimation
    })
  }

  async saveAutoPageSeconds(autoPageSeconds: number): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.autoPageSeconds = normalizeReaderAutoPageSeconds(autoPageSeconds)
    })
  }

  async savePreloadPages(preloadPages: number): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.preloadPages = normalizeReaderPreloadPages(preloadPages)
    })
  }

  async saveShowProgressControls(showProgressControls: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.showProgressControls = showProgressControls
    })
  }

  async saveKeepScreenAwake(keepScreenAwake: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.keepScreenAwake = keepScreenAwake
    })
  }

  async saveImageFitMode(imageFitMode: ReaderImageFitMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.imageFitMode = imageFitMode
    })
  }

  async saveTapZonePreset(tapZonePreset: ReaderTapZonePreset): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.tapZonePreset = tapZonePreset
    })
  }

  async saveTapZoneInvert(tapZoneInvert: ReaderTapZoneInvert): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.tapZoneInvert = tapZoneInvert
    })
  }

  async savePageGapMode(pageGapMode: ReaderPageGapMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.pageGapMode = pageGapMode
    })
  }

  async saveTrimPageMarginsEnabled(trimPageMarginsEnabled: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.trimPageMarginsEnabled = trimPageMarginsEnabled
    })
  }

  async saveReaderImplementation(implementation: ReaderImplementation): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.readerImplementation = normalizeReaderImplementation(implementation)
    })
  }

  async saveWideImageMode(wideImageMode: ReaderWideImageMode): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.wideImageMode = wideImageMode
    })
  }

  async saveVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled: boolean): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.volumeKeyNavigationEnabled = volumeKeyNavigationEnabled
    })
  }

  async saveVolumeKeyBehavior(volumeKeyBehavior: ReaderVolumeKeyBehavior): Promise<ReaderPreferences> {
    return this.mutatePreferences((next: ReaderPreferences): void => {
      next.volumeKeyBehavior = volumeKeyBehavior
    })
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_PREFERENCES_STORE_NAME)
  }
}

function normalizeReaderImplementation(value: string): ReaderImplementation {
  return value === 'legacy' ? 'legacy' : 'shared'
}
