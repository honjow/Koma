import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const readerPreferencesStorePath = resolve(root, 'entry/src/main/ets/model/ReaderPreferencesStore.ets')
const readerPagePath = resolve(root, 'entry/src/main/ets/pages/ReaderPage.ets')
const readerChromePath = resolve(root, 'entry/src/main/ets/components/ReaderChrome.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const backupServicePath = resolve(root, 'entry/src/main/ets/model/BackupService.ets')
const baseStringsPath = resolve(root, 'entry/src/main/resources/base/element/string.json')
const enStringsPath = resolve(root, 'entry/src/main/resources/en_US/element/string.json')
const zhStringsPath = resolve(root, 'entry/src/main/resources/zh_CN/element/string.json')

const readerPreferencesStoreSource = readFileSync(readerPreferencesStorePath, 'utf8')
const readerPageSource = readFileSync(readerPagePath, 'utf8')
const readerChromeSource = readFileSync(readerChromePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const backupServiceSource = readFileSync(backupServicePath, 'utf8')
const allReaderStringSources = [
  readFileSync(baseStringsPath, 'utf8'),
  readFileSync(enStringsPath, 'utf8'),
  readFileSync(zhStringsPath, 'utf8'),
]

assert.match(
  readerPreferencesStoreSource,
  /export type ReaderImageFitMode = 'contain' \| 'fit_width'/,
  'reader preferences must model persisted image fit choices',
)
assert.match(
  readerPreferencesStoreSource,
  /export type ReaderTapZonePreset = 'edge' \| 'wide_edges'/,
  'reader preferences must model persisted tap-zone preset choices',
)
assert.match(
  readerPreferencesStoreSource,
  /export type ReaderPageGapMode = 'compact' \| 'normal' \| 'wide'/,
  'reader preferences must model persisted page gap choices',
)
assert.match(
  readerPreferencesStoreSource,
  /export type ReaderWideImageMode = 'keep_single' \| 'rotate_wide_pages' \| 'split_wide_pages'/,
  'reader preferences must model persisted wide image choices with real rotate and split modes',
)
assert.match(
  readerPreferencesStoreSource,
  /export type ReaderBackgroundMode = 'black' \| 'paper' \| 'light'/,
  'reader preferences must model persisted background color choices',
)
assert.match(
  readerPreferencesStoreSource,
  /BACKGROUND_MODE_KEY:\s*string = 'reader\.backgroundMode'/,
  'reader background mode must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /IMAGE_FIT_MODE_KEY:\s*string = 'reader\.imageFitMode'/,
  'image fit mode must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /TAP_NAVIGATION_ENABLED_KEY:\s*string = 'reader\.tapNavigationEnabled'/,
  'tap navigation setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /SWIPE_NAVIGATION_ENABLED_KEY:\s*string = 'reader\.swipeNavigationEnabled'/,
  'swipe navigation setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /ZOOM_GESTURES_ENABLED_KEY:\s*string = 'reader\.zoomGesturesEnabled'/,
  'zoom gesture setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /TAP_ZONE_PRESET_KEY:\s*string = 'reader\.tapZonePreset'/,
  'tap zone preset must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /SHOW_TAP_ZONES_KEY:\s*string = 'reader\.showTapZones'/,
  'tap zone visualization setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /PAGE_GAP_MODE_KEY:\s*string = 'reader\.pageGapMode'/,
  'page gap setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /TRIM_PAGE_MARGINS_ENABLED_KEY:\s*string = 'reader\.trimPageMarginsEnabled'/,
  'trim page margins setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /WIDE_IMAGE_MODE_KEY:\s*string = 'reader\.wideImageMode'/,
  'wide image handling must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /VOLUME_KEY_NAVIGATION_ENABLED_KEY:\s*string = 'reader\.volumeKeyNavigationEnabled'/,
  'volume key navigation setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /VOLUME_KEY_BEHAVIOR_KEY:\s*string = 'reader\.volumeKeyBehavior'/,
  'volume key direction setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /export interface ReaderSeriesPreferenceOverrides \{[\s\S]*pageMode\?: ReaderPageMode[\s\S]*readingDirection\?: ReadingDirection[\s\S]*backgroundMode\?: ReaderBackgroundMode[\s\S]*imageFitMode\?: ReaderImageFitMode[\s\S]*tapNavigationEnabled\?: boolean[\s\S]*swipeNavigationEnabled\?: boolean[\s\S]*zoomGesturesEnabled\?: boolean[\s\S]*tapZonePreset\?: ReaderTapZonePreset[\s\S]*showTapZones\?: boolean[\s\S]*pageGapMode\?: ReaderPageGapMode[\s\S]*wideImageMode\?: ReaderWideImageMode/,
  'reader preferences must model per-series overrides for quick reader settings that affect per-title reading comfort',
)
assert.match(
  readerPreferencesStoreSource,
  /SERIES_OVERRIDES_KEY:\s*string = 'reader\.seriesOverrides\.v1'/,
  'per-series reader preferences must use a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /DEFAULT_READER_PREFERENCES:[\s\S]*backgroundMode:\s*'black'[\s\S]*imageFitMode:\s*'fit_width'[\s\S]*tapNavigationEnabled:\s*true[\s\S]*swipeNavigationEnabled:\s*true[\s\S]*zoomGesturesEnabled:\s*true[\s\S]*tapZonePreset:\s*'edge'[\s\S]*showTapZones:\s*false[\s\S]*pageGapMode:\s*'normal'[\s\S]*trimPageMarginsEnabled:\s*false[\s\S]*wideImageMode:\s*'keep_single'[\s\S]*volumeKeyNavigationEnabled:\s*false/,
  'new reader settings must default to black background, full-width image fit, enabled narrow-edge tap/swipe/zoom gestures, hidden tap-zone overlay, normal spacing, no trim, keep-wide-as-single-page, and no volume-key navigation',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderBackgroundMode\(value: string\): ReaderBackgroundMode[\s\S]*value === 'paper' \|\| value === 'light'[\s\S]*return 'black'/,
  'reader background loading must normalize unsupported values back to the current black background',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderImageFitMode\(value: string\)[\s\S]*value === 'fit_width' \|\| value === 'fit_height'[\s\S]*return 'contain'/,
  'image fit loading must accept width and height fit while staying backward-compatible with missing or invalid saved values',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderTapNavigationEnabled\(value: boolean \| string \| number\)[\s\S]*value === false[\s\S]*return false[\s\S]*return true/,
  'tap navigation loading must default to enabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderSwipeNavigationEnabled\(value: boolean \| string \| number\)[\s\S]*value === false[\s\S]*return false[\s\S]*return true/,
  'swipe navigation loading must default to enabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderZoomGesturesEnabled\(value: boolean \| string \| number\)[\s\S]*value === false[\s\S]*return false[\s\S]*return true/,
  'zoom gesture loading must default to enabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderTapZonePreset\(value: string\): ReaderTapZonePreset[\s\S]*value === 'wide_edges'[\s\S]*return value[\s\S]*return 'edge'/,
  'tap zone preset loading must normalize unsupported values back to the current narrow-edge behavior',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderShowTapZones\(value: boolean \| string \| number\)[\s\S]*value === true[\s\S]*return true[\s\S]*return false/,
  'tap zone visualization loading must default to disabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderPageGapMode\(value: string\)[\s\S]*value === 'compact' \|\| value === 'wide'[\s\S]*return 'normal'/,
  'page gap loading must be backward-compatible with missing or invalid saved values',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderTrimPageMarginsEnabled\(value: boolean \| string \| number\)[\s\S]*value === true[\s\S]*return true[\s\S]*return false/,
  'trim page margins loading must default to disabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderWideImageMode\(value: string\): ReaderWideImageMode[\s\S]*value === 'rotate_wide_pages' \|\| value === 'split_wide_pages'[\s\S]*return value[\s\S]*return 'keep_single'/,
  'wide image handling must accept real rotate and split modes and normalize unsupported values back to safe single-page display',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderVolumeKeyNavigationEnabled\(value: boolean \| string \| number\)[\s\S]*value === true[\s\S]*return true[\s\S]*return false/,
  'volume key navigation loading must default to disabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /getReaderVolumeKeyNavigationLabel\(volumeKeyNavigationEnabled: boolean\): string \{[\s\S]*volumeKeyNavigationEnabled \? AppStrings\.get\('common_on'\) : AppStrings\.get\('common_off'\)/,
  'volume key navigation label must reflect active runtime support instead of stale persisted-only copy',
)
assert.match(
  readerPreferencesStoreSource,
  /getReaderSwipeNavigationLabel\(swipeNavigationEnabled: boolean\): string \{[\s\S]*swipeNavigationEnabled \? AppStrings\.get\('common_on'\) : AppStrings\.get\('common_off'\)/,
  'swipe navigation label must reflect the persisted on/off setting',
)
assert.match(
  readerPreferencesStoreSource,
  /getReaderZoomGesturesLabel\(zoomGesturesEnabled: boolean\): string \{[\s\S]*zoomGesturesEnabled \? AppStrings\.get\('common_on'\) : AppStrings\.get\('common_off'\)/,
  'zoom gesture label must reflect the persisted on/off setting',
)
assert.match(
  readerPreferencesStoreSource,
  /getReaderTapZonePresetLabel\(preset: ReaderTapZonePreset\): string \{[\s\S]*preset === 'wide_edges'[\s\S]*return AppStrings\.get\('reader_tap_zone_wide'\)[\s\S]*return AppStrings\.get\('reader_tap_zone_edge'\)/,
  'tap zone preset labels must be user-facing names instead of internal enum values',
)
assert.match(
  readerPreferencesStoreSource,
  /getReaderShowTapZonesLabel\(showTapZones: boolean\): string \{[\s\S]*showTapZones \? AppStrings\.get\('common_show'\) : AppStrings\.get\('common_hide'\)/,
  'tap zone visualization label must reflect the persisted show or hide setting',
)
assert.match(
  readerPreferencesStoreSource,
  /getReaderBackgroundModeLabel\(mode: ReaderBackgroundMode\): string \{[\s\S]*reader_background_paper[\s\S]*reader_background_light[\s\S]*reader_background_black/,
  'reader background mode labels must be user-facing names instead of internal enum values',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(BACKGROUND_MODE_KEY, DEFAULT_READER_PREFERENCES\.backgroundMode\)/,
  'reader preferences load must read persisted background mode',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(IMAGE_FIT_MODE_KEY, DEFAULT_READER_PREFERENCES\.imageFitMode\)/,
  'reader preferences load must read persisted image fit mode',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(TAP_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES\.tapNavigationEnabled\)/,
  'reader preferences load must read persisted tap navigation setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(SWIPE_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES\.swipeNavigationEnabled\)/,
  'reader preferences load must read persisted swipe navigation setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(ZOOM_GESTURES_ENABLED_KEY, DEFAULT_READER_PREFERENCES\.zoomGesturesEnabled\)/,
  'reader preferences load must read persisted zoom gesture setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(TAP_ZONE_PRESET_KEY, DEFAULT_READER_PREFERENCES\.tapZonePreset\)/,
  'reader preferences load must read persisted tap zone preset',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(SHOW_TAP_ZONES_KEY, DEFAULT_READER_PREFERENCES\.showTapZones\)/,
  'reader preferences load must read persisted tap zone visualization setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(PAGE_GAP_MODE_KEY, DEFAULT_READER_PREFERENCES\.pageGapMode\)/,
  'reader preferences load must read persisted page gap setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(TRIM_PAGE_MARGINS_ENABLED_KEY, DEFAULT_READER_PREFERENCES\.trimPageMarginsEnabled\)/,
  'reader preferences load must read persisted trim page margins setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(WIDE_IMAGE_MODE_KEY, DEFAULT_READER_PREFERENCES\.wideImageMode\)/,
  'reader preferences load must read persisted wide image handling setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(VOLUME_KEY_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES\.volumeKeyNavigationEnabled\)/,
  'reader preferences load must read persisted volume key navigation setting',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveBackgroundMode\(backgroundMode: ReaderBackgroundMode\)[\s\S]*store\.put\(BACKGROUND_MODE_KEY, normalizeReaderBackgroundMode\(backgroundMode\)\)/,
  'reader preferences store must persist normalized background mode independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveImageFitMode\(imageFitMode: ReaderImageFitMode\)/,
  'reader preferences store must persist image fit mode independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveTapNavigationEnabled\(tapNavigationEnabled: boolean\)/,
  'reader preferences store must persist tap navigation independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveSwipeNavigationEnabled\(swipeNavigationEnabled: boolean\)/,
  'reader preferences store must persist swipe navigation independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveZoomGesturesEnabled\(zoomGesturesEnabled: boolean\)/,
  'reader preferences store must persist zoom gestures independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveTapZonePreset\(tapZonePreset: ReaderTapZonePreset\)/,
  'reader preferences store must persist tap zone preset independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveShowTapZones\(showTapZones: boolean\)/,
  'reader preferences store must persist tap zone visualization independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async savePageGapMode\(pageGapMode: ReaderPageGapMode\)/,
  'reader preferences store must persist page gap independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveTrimPageMarginsEnabled\(trimPageMarginsEnabled: boolean\)/,
  'reader preferences store must persist trim page margins independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveWideImageMode\(wideImageMode: ReaderWideImageMode\)/,
  'reader preferences store must persist wide image handling independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveVolumeKeyNavigationEnabled\(volumeKeyNavigationEnabled: boolean\)/,
  'reader preferences store must persist volume key navigation independently',
)
assert.match(
  readerPreferencesStoreSource,
  /loadForComic\(comicId: ComicId\): Promise<ReaderPreferences>[\s\S]*const globalPreferences = await this\.load\(\)[\s\S]*const overrides = await this\.loadSeriesOverrides\(\)[\s\S]*mergeReaderSeriesPreferences\(globalPreferences, overrides\[seriesId\]\)/,
  'reader preferences store must merge per-series overrides over global preferences when opening a comic',
)
assert.match(
  readerPreferencesStoreSource,
  /saveSeriesPreferences\(comicId: ComicId, overrides: ReaderSeriesPreferenceOverrides\)[\s\S]*normalizeReaderSeriesPreferenceOverrides\(overrides\)[\s\S]*allOverrides\[seriesId\] = normalized[\s\S]*store\.put\(SERIES_OVERRIDES_KEY, JSON\.stringify\(allOverrides\)\)[\s\S]*store\.flush\(\)/,
  'reader preferences store must persist sanitized per-series overrides',
)
assert.match(
  readerPreferencesStoreSource,
  /clearSeriesPreferences\(comicId: ComicId\)[\s\S]*readerSeriesOverridesWithout\(await this\.loadSeriesOverrides\(\), seriesId\)[\s\S]*store\.put\(SERIES_OVERRIDES_KEY, JSON\.stringify\(allOverrides\)\)[\s\S]*store\.flush\(\)/,
  'reader preferences store must clear per-series overrides independently',
)
assert.match(
  readerPreferencesStoreSource,
  /mergeReaderSeriesPreferences[\s\S]*pageMode: overrides\.pageMode \?\? globalPreferences\.pageMode[\s\S]*readingDirection: overrides\.readingDirection \?\? globalPreferences\.readingDirection[\s\S]*backgroundMode: overrides\.backgroundMode \?\? globalPreferences\.backgroundMode[\s\S]*imageFitMode: overrides\.imageFitMode \?\? globalPreferences\.imageFitMode[\s\S]*tapNavigationEnabled: overrides\.tapNavigationEnabled \?\? globalPreferences\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled: overrides\.swipeNavigationEnabled \?\? globalPreferences\.swipeNavigationEnabled[\s\S]*tapZonePreset: overrides\.tapZonePreset \?\? globalPreferences\.tapZonePreset[\s\S]*showTapZones: overrides\.showTapZones \?\? globalPreferences\.showTapZones[\s\S]*pageGapMode: overrides\.pageGapMode \?\? globalPreferences\.pageGapMode[\s\S]*wideImageMode: overrides\.wideImageMode \?\? globalPreferences\.wideImageMode/,
  'per-series overrides must restore quick reader settings while inheriting unrelated global theme/progress/keep-awake preferences',
)
assert.match(
  readerPageSource,
  /new ReaderPreferencesStore\(context\)\.loadForComic\(this\.sessionConfig\.comicId\)/,
  'ReaderPage must load per-series preferences for the active comic instead of only global defaults',
)
assert.match(
  readerPageSource,
  /currentSeriesPreferenceOverrides\(\): ReaderSeriesPreferenceOverrides[\s\S]*pageMode: this\.pageModeForSeriesPreferences\(\)[\s\S]*readingDirection: this\.readingDirection[\s\S]*backgroundMode: this\.backgroundMode[\s\S]*imageFitMode: this\.imageFitMode[\s\S]*tapNavigationEnabled: this\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled: this\.swipeNavigationEnabled[\s\S]*tapZonePreset: this\.tapZonePreset[\s\S]*showTapZones: this\.showTapZones[\s\S]*pageGapMode: this\.pageGapMode[\s\S]*wideImageMode: this\.wideImageMode/,
  'ReaderPage must build per-series overrides from the current runtime reader controls',
)
assert.match(
  readerPageSource,
  /saveCurrentSeriesPreferences\(\): void[\s\S]*saveSeriesPreferences\([\s\S]*this\.sessionConfig\.comicId[\s\S]*this\.currentSeriesPreferenceOverrides\(\)[\s\S]*reader_series_settings_saved/,
  'ReaderPage must let the user persist current reader controls as per-series settings',
)
assert.match(
  readerPageSource,
  /clearCurrentSeriesPreferences\(\): void[\s\S]*clearSeriesPreferences\(this\.sessionConfig\.comicId\)[\s\S]*reader_series_settings_cleared[\s\S]*this\.loadReaderPreferences\(\)/,
  'ReaderPage must let the user clear per-series settings and immediately reload global preferences',
)
assert.match(
  readerChromeSource,
  /@Local private quickSettingsVisible: boolean = false[\s\S]*private QuickSettingsPanel\(\)[\s\S]*reader_action_save_series_settings[\s\S]*onSaveSeriesSettings\(\)[\s\S]*reader_action_clear_series_settings[\s\S]*onClearSeriesSettings\(\)/,
  'ReaderChrome must expose per-series actions from the immersive quick settings panel',
)
assert.match(
  readerChromeSource,
  /private QuickSettingsPanel\(\)[\s\S]*Scroll\(\)[\s\S]*constraintSize\(\{ maxHeight: 420 \}\)[\s\S]*scrollable\(ScrollDirection\.Vertical\)/,
  'ReaderChrome quick settings must scroll vertically instead of clipping controls on small screens',
)
assert.match(
  readerChromeSource,
  /KomaSegmentedControl\(\{[\s\S]*getReaderImageFitModeLabel\('contain'\)[\s\S]*getReaderBackgroundModeLabel\('black'\)[\s\S]*getReaderPageGapModeLabel\('compact'\)[\s\S]*getReaderWideImageModeLabel\('split_wide_pages'\)[\s\S]*getReaderTapZonePresetLabel\('wide_edges'\)/,
  'ReaderChrome quick settings must use reusable segmented controls for reader display choices',
)
assert.match(
  readerChromeSource,
  /QuickSettingsToggle\(s\('settings_row_reader_tap_navigation_title'\)[\s\S]*onTapNavigationEnabledChange\(enabled\)[\s\S]*QuickSettingsToggle\(s\('settings_row_reader_swipe_navigation_title'\)[\s\S]*onSwipeNavigationEnabledChange\(enabled\)[\s\S]*QuickSettingsToggle\(s\('settings_row_reader_zoom_gestures_title'\)[\s\S]*onZoomGesturesEnabledChange\(enabled\)[\s\S]*QuickSettingsToggle\(s\('settings_row_reader_show_tap_zones_title'\)[\s\S]*onShowTapZonesChange\(enabled\)/,
  'ReaderChrome quick settings must use switch controls for binary reader interaction settings',
)
assert.match(
  readerChromeSource,
  /QuickSettingsToggle\(s\('settings_row_reader_progress_title'\), this\.showProgressControls[\s\S]*onShowProgressControlsChange\(enabled\)[\s\S]*QuickSettingsToggle\(s\('settings_row_reader_keep_screen_awake_title'\), this\.keepScreenAwake[\s\S]*onKeepScreenAwakeChange\(enabled\)[\s\S]*QuickSettingsToggle\(s\('settings_row_reader_trim_page_margins_title'\), this\.trimPageMarginsEnabled[\s\S]*onTrimPageMarginsEnabledChange\(enabled\)[\s\S]*QuickSettingsToggle\(s\('settings_row_reader_volume_key_navigation_title'\), this\.volumeKeyNavigationEnabled[\s\S]*onVolumeKeyNavigationEnabledChange\(enabled\)/,
  'ReaderChrome quick settings must expose progress, keep-awake, trim, and volume-key switches in the reader itself',
)
assert.match(
  readerPageSource,
  /private tapLeftZone\(\): void[\s\S]*ReadingDirection\.RIGHT_TO_LEFT[\s\S]*this\.nextPage\(\)[\s\S]*this\.previousPage\(\)[\s\S]*private tapRightZone\(\): void[\s\S]*ReadingDirection\.RIGHT_TO_LEFT[\s\S]*this\.previousPage\(\)[\s\S]*this\.nextPage\(\)/,
  'ReaderPage left/right tap navigation must remain reading-direction aware',
)
assert.match(
  readerChromeSource,
  /build\(\) \{[\s\S]*Stack\(\{ alignContent: Alignment\.TopStart \}\) \{[\s\S]*this\.TopBar\(\)[\s\S]*Column\(\{ space: 0 \}\)[\s\S]*this\.QuickSettingsPanel\(\)[\s\S]*this\.BottomBar\(\)[\s\S]*\.align\(Alignment\.Bottom\)/,
  'ReaderChrome must keep the middle reading surface non-intercepting while pinning controls to top and bottom',
)
assert.doesNotMatch(
  readerChromeSource,
  /private MiddleDismissSurface|HitTestMode\.Block[\s\S]*hideChrome|backgroundColor\('#01000000'\)/,
  'ReaderChrome must not reserve an invisible blocking middle surface over reader gestures',
)
assert.match(
  readerPageSource,
  /@Param chromeVisible: boolean = true/,
  'ReaderPage must keep chrome visibility controlled by the parent route state',
)
assert.match(
  readerPageSource,
  /@Local private activeChromeVisible: boolean = false[\s\S]*private toggleChrome\(\)[\s\S]*const nextVisible = !this\.activeChromeVisible[\s\S]*this\.activeChromeVisible = nextVisible[\s\S]*this\.\$chromeVisible\(nextVisible\)[\s\S]*visible: this\.activeChromeVisible/,
  'ReaderPage must render chrome from an immediate local state while syncing route state',
)
assert.match(
  readerPageSource,
  /private lastChromeToggleAt: number = 0[\s\S]*private toggleChrome\(\)[\s\S]*Date\.now\(\)[\s\S]*now - this\.lastChromeToggleAt < 250[\s\S]*this\.lastChromeToggleAt = now/,
  'ReaderPage chrome toggle must debounce duplicate platform click events from a single reader tap',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8'),
  /@Local private readerChromeVisible: boolean = false[\s\S]*this\.readerChromeVisible = false[\s\S]*this\.readerOpen = true/,
  'Reader should open into immersive reading mode and show chrome only after an explicit reader tap',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8'),
  /ReaderPage\(\{[\s\S]*chromeVisible: this\.readerChromeVisible!!/,
  'ReaderPage chrome visibility must use V2 two-way binding into the parent route state',
)
assert.match(
  readerPageSource,
  /ReaderChrome\(\{[\s\S]*backgroundMode: this\.backgroundMode[\s\S]*imageFitMode: this\.imageFitMode[\s\S]*tapNavigationEnabled: this\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled: this\.swipeNavigationEnabled[\s\S]*zoomGesturesEnabled: this\.zoomGesturesEnabled[\s\S]*tapZonePreset: this\.tapZonePreset[\s\S]*showTapZones: this\.showTapZones[\s\S]*pageGapMode: this\.pageGapMode[\s\S]*wideImageMode: this\.wideImageMode/,
  'ReaderPage must pass live reader display and interaction settings into the immersive quick settings panel',
)
assert.match(
  readerPageSource,
  /ReaderChrome\(\{[\s\S]*showProgressControls: this\.showProgressControls[\s\S]*keepScreenAwake: this\.keepScreenAwake[\s\S]*trimPageMarginsEnabled: this\.trimPageMarginsEnabled[\s\S]*volumeKeyNavigationEnabled: this\.volumeKeyNavigationEnabled/,
  'ReaderPage must pass all live binary reader settings into the immersive quick settings panel',
)
allReaderStringSources.forEach((source, index) => {
  assert.match(source, /"name": "reader_tap_zone_center"/, `reader tap-zone center label must exist in locale ${index}`)
  assert.match(source, /"name": "settings_row_reader_zoom_gestures_title"/, `reader zoom gesture setting title must exist in locale ${index}`)
})

assert.match(settingsPageSource, /key: 'reader-image-fit', titleKey: 'settings_row_reader_image_fit_title'/, 'Settings must expose an image fit row')
assert.match(settingsPageSource, /key: 'reader-background', titleKey: 'settings_row_reader_background_title'/, 'Settings must expose a reader background row')
assert.match(settingsPageSource, /key: 'reader-tap-navigation', titleKey: 'settings_row_reader_tap_navigation_title'/, 'Settings must expose a tap navigation row')
assert.match(settingsPageSource, /key: 'reader-swipe-navigation', titleKey: 'settings_row_reader_swipe_navigation_title'/, 'Settings must expose a swipe navigation row')
assert.match(settingsPageSource, /key: 'reader-zoom-gestures', titleKey: 'settings_row_reader_zoom_gestures_title'/, 'Settings must expose a zoom gesture row')
assert.match(settingsPageSource, /key: 'reader-tap-zone-preset', titleKey: 'settings_row_reader_tap_zone_preset_title'/, 'Settings must expose a tap-zone preset row')
assert.match(settingsPageSource, /key: 'reader-show-tap-zones', titleKey: 'settings_row_reader_show_tap_zones_title'/, 'Settings must expose a tap-zone visualization row')
assert.match(settingsPageSource, /key: 'reader-page-gap', titleKey: 'settings_row_reader_page_gap_title'/, 'Settings must expose a page gap row')
assert.match(settingsPageSource, /key: 'reader-trim-page-margins', titleKey: 'settings_row_reader_trim_page_margins_title'/, 'Settings must expose an honest non-cropping trim row')
assert.match(settingsPageSource, /key: 'reader-wide-image-mode', titleKey: 'settings_row_reader_wide_image_mode_title'/, 'Settings must expose a wide image handling row')
assert.match(settingsPageSource, /key: 'reader-volume-key-navigation', titleKey: 'settings_row_reader_volume_key_navigation_title'/, 'Settings must expose a volume-key navigation preference row')
assert.match(settingsPageSource, /reader-image-fit[\s\S]*SelectionMenuItem\(s\('reader_image_fit_screen'\)[\s\S]*SelectionMenuItem\(s\('reader_image_fit_width'\)[\s\S]*SelectionMenuItem\(s\('reader_image_fit_height'\)/, 'image fit menu must expose contain, fit-width, and fit-height choices')
assert.match(settingsPageSource, /reader-background[\s\S]*SelectionMenuItem\(s\('reader_background_black'\)[\s\S]*saveReaderBackgroundMode\('black'\)[\s\S]*SelectionMenuItem\(s\('reader_background_paper'\)[\s\S]*saveReaderBackgroundMode\('paper'\)[\s\S]*SelectionMenuItem\(s\('reader_background_light'\)[\s\S]*saveReaderBackgroundMode\('light'\)/, 'reader background menu must expose black, paper, and light choices')
assert.match(settingsPageSource, /reader-tap-navigation[\s\S]*saveReaderTapNavigationEnabled\(value\)/, 'tap navigation row must expose a real switch-backed on/off choice')
assert.match(settingsPageSource, /reader-swipe-navigation[\s\S]*saveReaderSwipeNavigationEnabled\(value\)/, 'swipe navigation row must expose a real switch-backed on/off choice')
assert.match(settingsPageSource, /reader-zoom-gestures[\s\S]*saveReaderZoomGesturesEnabled\(value\)/, 'zoom gesture row must expose a real switch-backed on/off choice')
assert.match(settingsPageSource, /reader-tap-zone-preset[\s\S]*SelectionMenuItem\(s\('reader_tap_zone_edge'\)[\s\S]*SelectionMenuItem\(s\('reader_tap_zone_wide'\)/, 'tap zone preset menu must expose user-facing preset names')
assert.match(settingsPageSource, /reader-show-tap-zones[\s\S]*saveReaderShowTapZones\(value\)/, 'tap zone visualization row must expose a real switch-backed on/off choice')
assert.match(
  settingsPageSource,
  /tapZonePreviewEdgeWidth\(\)[\s\S]*tapZonePreviewLeftLabel\(\)[\s\S]*tapZonePreviewRightLabel\(\)[\s\S]*private ReaderTapZonePreview\(\)[\s\S]*settings_row_reader_tap_zone_preset_title[\s\S]*reader_tap_zone_center[\s\S]*section\.key === 'reader'[\s\S]*this\.ReaderTapZonePreview\(\)/,
  'Settings reader pane must include a tap-zone preview tied to the persisted preset and current reading direction',
)
assert.match(settingsPageSource, /readerTapZonePreset === 'wide_edges' \? '32%' : '18%'/, 'Settings tap-zone preview must use the same narrow and wide edge ratios as the reader hit zones')
assert.match(settingsPageSource, /ReadingDirection\.RIGHT_TO_LEFT[\s\S]*reader_action_next_page[\s\S]*reader_action_previous_page/, 'Settings tap-zone preview must label edge actions with RTL-aware page direction')
assert.match(settingsPageSource, /reader-page-gap[\s\S]*SelectionMenuItem\(s\('reader_page_gap_compact'\)[\s\S]*SelectionMenuItem\(s\('common_standard'\)[\s\S]*SelectionMenuItem\(s\('reader_page_gap_wide'\)/, 'page gap menu must expose compact, normal, and wide choices')
assert.match(settingsPageSource, /reader-trim-page-margins[\s\S]*saveReaderTrimPageMarginsEnabled\(value\)/, 'trim page margins row must expose a real switch-backed on/off choice')
assert.match(
  settingsPageSource,
  /reader-wide-image-mode[\s\S]*SelectionMenuItem\(s\('reader_wide_mode_keep_single'\)[\s\S]*SelectionMenuItem\(s\('reader_wide_mode_split'\)[\s\S]*saveReaderWideImageMode\('split_wide_pages'\)[\s\S]*SelectionMenuItem\(s\('reader_wide_mode_rotate'\)/,
  'wide image handling sheet must expose real metadata-gated split and rotate modes with the mutual-exclusion priority',
)
assert.match(settingsPageSource, /reader-volume-key-navigation[\s\S]*saveReaderVolumeKeyNavigationEnabled\(value\)/, 'volume-key navigation row must expose a real switch-backed runtime preference')

assert.match(
  readerPageSource,
  /backgroundMode = preferences\.backgroundMode[\s\S]*imageFitMode = preferences\.imageFitMode[\s\S]*tapNavigationEnabled = preferences\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled = preferences\.swipeNavigationEnabled[\s\S]*zoomGesturesEnabled = preferences\.zoomGesturesEnabled[\s\S]*tapZonePreset = preferences\.tapZonePreset[\s\S]*showTapZones = preferences\.showTapZones[\s\S]*pageGapMode = preferences\.pageGapMode[\s\S]*trimPageMarginsEnabled = preferences\.trimPageMarginsEnabled[\s\S]*wideImageMode = preferences\.wideImageMode/,
  'ReaderPage must apply persisted advanced settings after load',
)
assert.match(
  readerPageSource,
  /private saveReaderPreference\(action: \(store: ReaderPreferencesStore\) => Promise<void>, reason: string\): void[\s\S]*new ReaderPreferencesStore\(context\)[\s\S]*quick_setting_saved[\s\S]*quick_setting_save_failed/,
  'ReaderPage quick settings must persist through ReaderPreferencesStore with fail-closed logging',
)
assert.match(
  readerPageSource,
  /private setReaderImageFitMode\(imageFitMode: ReaderImageFitMode\): void[\s\S]*this\.imageFitMode = imageFitMode[\s\S]*this\.resetReaderZoom\(false\)[\s\S]*this\.syncReaderDisplayAfterSettingChange\(\)[\s\S]*store\.saveImageFitMode\(imageFitMode\)/,
  'ReaderPage quick image-fit changes must apply immediately, reset zoom, sync the viewport, and persist',
)
assert.match(
  readerPageSource,
  /private setReaderTapNavigationEnabled\(tapNavigationEnabled: boolean\): void[\s\S]*this\.tapNavigationEnabled = tapNavigationEnabled[\s\S]*store\.saveTapNavigationEnabled\(tapNavigationEnabled\)[\s\S]*private setReaderSwipeNavigationEnabled\(swipeNavigationEnabled: boolean\): void[\s\S]*this\.swipeNavigationEnabled = swipeNavigationEnabled[\s\S]*store\.saveSwipeNavigationEnabled\(swipeNavigationEnabled\)[\s\S]*private setReaderZoomGesturesEnabled\(zoomGesturesEnabled: boolean\): void[\s\S]*this\.zoomGesturesEnabled = zoomGesturesEnabled[\s\S]*!zoomGesturesEnabled[\s\S]*this\.resetReaderZoom\(true\)[\s\S]*store\.saveZoomGesturesEnabled\(zoomGesturesEnabled\)/,
  'ReaderPage quick interaction switches must apply immediately and persist',
)
assert.match(
  readerPageSource,
  /private setReaderShowProgressControls\(showProgressControls: boolean\): void[\s\S]*this\.showProgressControls = showProgressControls[\s\S]*store\.saveShowProgressControls\(showProgressControls\)[\s\S]*private setReaderKeepScreenAwake\(keepScreenAwake: boolean\): void[\s\S]*this\.keepScreenAwake = keepScreenAwake[\s\S]*this\.readerActive[\s\S]*this\.applyReaderKeepScreenAwake\(keepScreenAwake, 'quick_settings'\)[\s\S]*store\.saveKeepScreenAwake\(keepScreenAwake\)/,
  'ReaderPage quick progress and keep-awake switches must apply immediately and persist',
)
assert.match(
  readerPageSource,
  /private onReaderDoubleTap\(tapX: number, tapY: number\): void \{[\s\S]*!this\.zoomGesturesEnabled[\s\S]*return[\s\S]*private onReaderPinchStart\(event\?: GestureEvent\): void \{[\s\S]*!this\.zoomGesturesEnabled \|\| event === undefined[\s\S]*private onReaderPanUpdate\(event\?: GestureEvent\): void \{[\s\S]*!this\.zoomGesturesEnabled \|\| event === undefined \|\| !this\.canPanReaderContent\(\)[\s\S]*private onReaderPanEnd\(\): void \{[\s\S]*!this\.zoomGesturesEnabled \|\| !this\.canPanReaderContent\(\)[\s\S]*this\.zoomScale <= 1\.01/,
  'ReaderPage must make double-tap, pinch zoom, and zoom-pan respect the zoom gesture preference at runtime',
)
assert.match(
  readerPageSource,
  /private setReaderWideImageMode\(wideImageMode: ReaderWideImageMode\): void[\s\S]*this\.wideImageMode = wideImageMode[\s\S]*this\.resetReaderZoom\(false\)[\s\S]*this\.syncReaderDisplayAfterSettingChange\(\)[\s\S]*store\.saveWideImageMode\(wideImageMode\)/,
  'ReaderPage quick wide-image mode changes must resync split display navigation and persist',
)
assert.match(
  readerPageSource,
  /private setReaderTrimPageMarginsEnabled\(trimPageMarginsEnabled: boolean\): void[\s\S]*this\.trimPageMarginsEnabled = trimPageMarginsEnabled[\s\S]*this\.resetReaderZoom\(false\)[\s\S]*this\.syncReaderDisplayAfterSettingChange\(\)[\s\S]*store\.saveTrimPageMarginsEnabled\(trimPageMarginsEnabled\)[\s\S]*private setReaderVolumeKeyNavigationEnabled\(volumeKeyNavigationEnabled: boolean\): void[\s\S]*this\.volumeKeyNavigationEnabled = volumeKeyNavigationEnabled[\s\S]*volumeKeyNavigationEnabled[\s\S]*this\.requestReaderKeyFocus\('quick_settings'\)[\s\S]*store\.saveVolumeKeyNavigationEnabled\(volumeKeyNavigationEnabled\)/,
  'ReaderPage quick trim and volume-key switches must apply immediately and persist',
)
assert.match(
  readerPageSource,
  /onBackgroundModeChange: \(mode: ReaderBackgroundMode\) => \{[\s\S]*this\.setReaderBackgroundMode\(mode\)[\s\S]*onShowProgressControlsChange: \(enabled: boolean\) => \{[\s\S]*this\.setReaderShowProgressControls\(enabled\)[\s\S]*onImageFitModeChange: \(mode: ReaderImageFitMode\) => \{[\s\S]*this\.setReaderImageFitMode\(mode\)[\s\S]*onZoomGesturesEnabledChange: \(enabled: boolean\) => \{[\s\S]*this\.setReaderZoomGesturesEnabled\(enabled\)[\s\S]*onTrimPageMarginsEnabledChange: \(enabled: boolean\) => \{[\s\S]*this\.setReaderTrimPageMarginsEnabled\(enabled\)[\s\S]*onWideImageModeChange: \(mode: ReaderWideImageMode\) => \{[\s\S]*this\.setReaderWideImageMode\(mode\)[\s\S]*onVolumeKeyNavigationEnabledChange: \(enabled: boolean\) => \{[\s\S]*this\.setReaderVolumeKeyNavigationEnabled\(enabled\)/,
  'ReaderPage must wire ReaderChrome quick settings callbacks into immediate preference updates',
)
assert.match(
  readerPageSource,
  /readerBackgroundColor\(\): ResourceColor[\s\S]*this\.backgroundMode === 'paper'[\s\S]*ThemeConstants\.READER_BG_PAPER[\s\S]*this\.backgroundMode === 'light'[\s\S]*ThemeConstants\.READER_BG_LIGHT[\s\S]*ThemeConstants\.READER_BG_DARK[\s\S]*\.backgroundColor\(this\.readerBackgroundColor\(\)\)/,
  'ReaderPage must apply the persisted reader background color to the reader surface',
)
assert.match(
  readerPageSource,
  /@Param readerOpen: boolean = false[\s\S]*@Monitor\('readerOpen'\)[\s\S]*private onReaderOpenChanged\(\): void \{[\s\S]*if \(this\.readerOpen\) \{[\s\S]*this\.loadReaderPreferences\(\)/,
  'ReaderPage must reload reader preferences when the reader is opened so setting changes apply without app restart',
)
assert.match(
  readerPageSource,
  /import \{ KeyCode \} from '@kit\.InputKit'/,
  'ReaderPage must use HarmonyOS InputKit key codes for volume-key runtime navigation',
)
assert.match(
  readerPageSource,
  /READER_VOLUME_KEY_FOCUS_ID:\s*string = 'reader-volume-key-surface'[\s\S]*\.id\(READER_VOLUME_KEY_FOCUS_ID\)[\s\S]*\.focusable\(true\)[\s\S]*\.defaultFocus\(true\)[\s\S]*\.onKeyEvent\(\(event: KeyEvent\) => \{[\s\S]*this\.handleVolumeKeyNavigation\(event\)/,
  'ReaderPage surface must be focusable and route key events into the volume-key handler',
)
assert.match(
  readerPageSource,
  /volumeKeyNavigationEnabled = preferences\.volumeKeyNavigationEnabled[\s\S]*volumeKeyNavigation=\$\{preferences\.volumeKeyNavigationEnabled\}/,
  'ReaderPage must load and log the persisted volume-key navigation preference',
)
assert.match(
  readerPageSource,
  /private handleVolumeKeyNavigation\(event: KeyEvent\): boolean[\s\S]*!this\.volumeKeyNavigationEnabled \|\| !this\.isVolumeNavigationKey\(event\.keyCode\)[\s\S]*return false[\s\S]*event\.type !== KeyType\.Down[\s\S]*return true[\s\S]*KeyCode\.KEYCODE_VOLUME_UP[\s\S]*this\.previousPage\(\)[\s\S]*this\.nextPage\(\)/,
  'ReaderPage must only consume volume keys when enabled, handle down events, and map volume up/down to previous/next page',
)
assert.match(
  readerPageSource,
  /export const READER_WIDE_IMAGE_ASPECT_RATIO_THRESHOLD:\s*number = 1\.2/,
  'ReaderPage must use a named conservative wide-image aspect-ratio threshold',
)
assert.match(
  readerPageSource,
  /export function hasReaderPageDimensions\(width: number \| undefined, height: number \| undefined\): boolean[\s\S]*width !== undefined && height !== undefined && width > 0 && height > 0/,
  'ReaderPage must require explicit positive page dimensions before wide-image handling',
)
assert.match(
  readerPageSource,
  /export function isReaderWideLandscapePage\(width: number \| undefined, height: number \| undefined\): boolean[\s\S]*if \(!hasReaderPageDimensions\(width, height\)\) \{[\s\S]*return false[\s\S]*\(width as number\) \/ \(height as number\) >= READER_WIDE_IMAGE_ASPECT_RATIO_THRESHOLD/,
  'ReaderPage must detect wide pages from actual width/height metadata and fail open when dimensions are missing',
)
assert.match(
  readerPageSource,
  /export function shouldRotateReaderWideImagePage\(mode: ReaderWideImageMode, width: number \| undefined, height: number \| undefined\): boolean[\s\S]*mode === 'rotate_wide_pages' && isReaderWideLandscapePage\(width, height\)[\s\S]*private shouldRotateWidePage\(index: number\): boolean[\s\S]*shouldRotateReaderWideImagePage\(this\.wideImageMode, this\.pageWidth\(index\), this\.pageHeight\(index\)\)/,
  'ReaderPage must consume only the rotate persisted wide-image setting before rotating a page',
)
assert.match(
  readerPageSource,
  /export function shouldSplitReaderWideImagePage\(mode: ReaderWideImageMode, readerMode: ReaderMode, width: number \| undefined, height: number \| undefined\): boolean[\s\S]*mode === 'split_wide_pages' && readerMode !== ReaderMode\.DUAL_PAGE && isReaderWideLandscapePage\(width, height\)[\s\S]*private shouldSplitWidePage\(index: number, readerMode: ReaderMode\): boolean[\s\S]*shouldSplitReaderWideImagePage\(this\.wideImageMode, readerMode, this\.pageWidth\(index\), this\.pageHeight\(index\)\)/,
  'ReaderPage must split only metadata-proven wide pages, suppress splitting in dual-page mode, and keep split separate from rotate',
)
assert.match(
  readerPageSource,
  /export function readerWidePageSplitSidesForDirection\(direction: ReadingDirection\): ReaderWidePageSplitSide\[\][\s\S]*ReadingDirection\.RIGHT_TO_LEFT[\s\S]*return \['right', 'left'\][\s\S]*return \['left', 'right'\]/,
  'ReaderPage must order split halves as left/right for LTR and right/left for RTL',
)
assert.match(
  readerPageSource,
  /rotateClockwise: this\.shouldRotateWidePage\(index\)/,
  'ReaderPage must pass metadata-gated wide-page rotation into image rendering',
)
assert.match(
  readerPageSource,
  /desiredRegion:[\s\S]*size: \{ width: splitWidth, height \}[\s\S]*x,[\s\S]*y: 0/,
  'split rendering must decode explicit left/right source regions instead of using cover or lossy visual crop',
)
assert.match(
  readerPageSource,
  /private readerDisplayEntries\(readerMode: ReaderMode\): ReaderPageDisplayEntry\[\][\s\S]*this\.shouldSplitWidePage\(index, readerMode\)[\s\S]*readerWidePageSplitSidesForDirection\(this\.readingDirection\)[\s\S]*splitSide: sides\[0\][\s\S]*splitSide: sides\[1\][\s\S]*splitSide: 'none'/,
  'single/webtoon display entries must duplicate only eligible wide pages into ordered split halves and leave normal pages unsplit',
)
assert.match(
  readerPageSource,
  /objectFit\(this\.imageFit\)[\s\S]*imageFit: this\.imageObjectFit\(\)/,
  'ReaderPage image rendering must use the persisted fit mode',
)
assert.match(
  readerPageSource,
  /private imageObjectFit\(\): ImageFit\s*\{[\s\S]*return ImageFit\.Contain[\s\S]*\}/,
  'ReaderPage image fit must use non-cropping contain semantics',
)
assert.doesNotMatch(
  readerPageSource,
  /imageObjectFit\(\): ImageFit[\s\S]*ImageFit\.Cover/,
  'fit-width must not map to crop-prone ImageFit.Cover',
)
assert.doesNotMatch(
  readerPageSource,
  /ImageFit\.Cover/,
  'wide image runtime must not add crop-prone rendering behavior',
)
assert.match(
  readerPageSource,
  /private pageContainerPadding\(compact: boolean\): number[\s\S]*return compact \? 0 : 0/,
  'reader pages must not add card padding around the image viewport',
)
assert.match(
  readerPageSource,
  /private pageContainerRadius\(compact: boolean\): number[\s\S]*return 0/,
  'reader pages must not use rounded card clipping in the main viewport',
)
assert.match(
  readerPageSource,
  /private pageImageTrimScale\(\): number[\s\S]*this\.trimPageMarginsEnabled \? 1\.04 : 1[\s\S]*id\('reader-page-local-file-image'\)[\s\S]*\.scale\(\{ x: this\.pageImageTrimScale\(\), y: this\.pageImageTrimScale\(\) \}\)[\s\S]*id\('reader-page-remote-url-image'\)[\s\S]*\.scale\(\{ x: this\.pageImageTrimScale\(\), y: this\.pageImageTrimScale\(\) \}\)/,
  'trim margins must visibly crop page edges by scaling image content inside the clipped page viewport',
)
assert.match(
  readerPageSource,
  /private shouldRenderPageFitWidth\(index: number, compact: boolean\): boolean \{[\s\S]*!compact && this\.imageFitMode === 'fit_width' && this\.hasPageDimensions\(index\)/,
  'fit-width image mode must activate the aspect-ratio page surface instead of falling through to the full-height contain surface',
)
assert.match(
  readerPageSource,
  /LocalImagePage\(imageUri: string, index: number, compact: boolean = false,[\s\S]*splitSide: ReaderWidePageSplitSide = 'none'\)[\s\S]*\.aspectRatio\(this\.readerDisplayPageAspectRatio\(index, splitSide\)\)[\s\S]*RemoteImagePage\(source: ReaderPageRenderSource, index: number, compact: boolean = false, splitSide: ReaderWidePageSplitSide = 'none'\)[\s\S]*\.aspectRatio\(this\.readerDisplayPageAspectRatio\(index, splitSide\)\)/,
  'fit-width image mode must lay out split and rotated pages using the visible page aspect ratio',
)
assert.match(
  readerPageSource,
  /private singlePageWidth\(\): string[\s\S]*return '100%'/,
  'single-page reader must use the full reader viewport width',
)
assert.match(
  readerPageSource,
  /private singlePageMaxWidth\(\): number[\s\S]*return 4096/,
  'single-page reader must not clamp phone/tablet pages to old card widths',
)
assert.match(
  readerPageSource,
  /private dualPageSlotWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '96%'[\s\S]*return '88%'/,
  'dual-page slots must widen for fit-width',
)
assert.match(
  readerPageSource,
  /private webtoonPageWidth\(\): string \{[\s\S]*return '100%'[\s\S]*\}/,
  'webtoon page width must use the full reader viewport width',
)
assert.match(
  readerPageSource,
  /SinglePageViewport\(\)[\s\S]*Column\(\) \{[\s\S]*this\.ReaderPageSurface\(entry\.pageIndex, false, entry\.splitSide\)[\s\S]*\.height\('100%'\)[\s\S]*\.justifyContent\(FlexAlign\.Center\)[\s\S]*DualPageSlot\(index: number\)[\s\S]*this\.ReaderPageSurface\(index\)[\s\S]*\.height\('100%'\)[\s\S]*\.justifyContent\(FlexAlign\.Center\)/,
  'single and dual page readers must vertically center the page surface instead of top-aligning images in a full-height column',
)
assert.match(
  readerPageSource,
  /\.width\(this\.singlePageWidth\(\)\)[\s\S]*\.constraintSize\(\{ maxWidth: this\.singlePageMaxWidth\(\) \}\)/,
  'single-page reader must apply the setting-dependent page card width functions',
)
assert.match(
  readerPageSource,
  /\.width\(this\.webtoonPageWidth\(\)\)[\s\S]*\.constraintSize\(\{ maxWidth: this\.webtoonPageMaxWidth\(\) \}\)/,
  'webtoon reader must apply the setting-dependent page width functions',
)
assert.match(
  readerPageSource,
  /private pageGapSpace\(\): number[\s\S]*this\.pageGapMode === 'compact'[\s\S]*this\.pageGapMode === 'wide'[\s\S]*return 18/,
  'ReaderPage must map page gap setting to visible spacing',
)
assert.match(
  readerPageSource,
  /List\(\{ space: this\.pageGapSpace\(\), initialIndex: this\.displayIndexForPage\(this\.pageIndex, ReaderMode\.CONTINUOUS_SCROLL\), scroller: this\.webtoonScroller \}\)/,
  'webtoon reader must visibly apply the page gap setting',
)
assert.match(
  readerPageSource,
  /Row\(\{ space: this\.pageGapSpace\(\) \}\)/,
  'dual-page reader must visibly apply the page gap setting',
)
assert.match(
  readerPageSource,
  /private tapLeftZone\(\): void \{[\s\S]*if \(!this\.tapNavigationEnabled\) \{[\s\S]*this\.toggleChrome\(\)[\s\S]*return[\s\S]*this\.previousPage\(\)/,
  'left tap zone must respect the tap navigation setting without breaking chrome toggling',
)
assert.match(
  readerPageSource,
  /private tapRightZone\(\): void \{[\s\S]*if \(!this\.tapNavigationEnabled\) \{[\s\S]*this\.toggleChrome\(\)[\s\S]*return[\s\S]*this\.nextPage\(\)/,
  'right tap zone must respect the tap navigation setting without breaking chrome toggling',
)
assert.match(
  readerPageSource,
  /private tapEdgeZoneWidth\(\): string[\s\S]*!this\.tapNavigationEnabled[\s\S]*return '0%'[\s\S]*this\.tapZonePreset === 'wide_edges'[\s\S]*return '32%'[\s\S]*return '18%'/,
  'tap navigation must use the persisted tap-zone preset for hit-test widths while preserving the current default edge width',
)
assert.match(
  readerPageSource,
  /private tapZoneOverlayColor\(\): ResourceColor[\s\S]*this\.tapNavigationEnabled && this\.showTapZones[\s\S]*ThemeConstants\.READER_TAP_ZONE_OVERLAY[\s\S]*Color\.Transparent/,
  'tap zone visualization must be a disabled-by-default overlay that only appears when tap navigation is active',
)
assert.match(
  readerPageSource,
  /\.disableSwipe\(!this\.swipeNavigationEnabled \|\| this\.zoomScale > 1\.01\)/,
  'paged reader swipers must honor the swipe navigation switch and pause swiping while zoomed so pan gestures do not flip pages',
)
assert.match(
  readerPageSource,
  /private syncReaderViewportToDisplayIndex\(displayIndex: number, readerMode: ReaderMode\): void[\s\S]*readerMode === ReaderMode\.CONTINUOUS_SCROLL[\s\S]*this\.webtoonScroller\.scrollToIndex\(displayIndex, true, ScrollAlign\.CENTER\)[\s\S]*this\.swiperController\.changeIndex\(displayIndex, true\)/,
  'programmatic reader navigation must move the visible webtoon list or paged swiper, not only persisted progress',
)
assert.match(
  readerPageSource,
  /private previousPage\(\)[\s\S]*const readerMode = this\.currentReaderMode\(\)[\s\S]*this\.setDualPairIndex\(pairIndex - 1, true\)[\s\S]*this\.setReaderDisplayEntryIndex\(displayIndex - 1, readerMode, true\)[\s\S]*private nextPage\(\)[\s\S]*this\.setDualPairIndex\(pairIndex \+ 1, true\)[\s\S]*this\.setReaderDisplayEntryIndex\(displayIndex \+ 1, readerMode, true\)/,
  'tap, chrome, and volume-key previous/next actions must synchronize the visible reader viewport',
)
assert.match(
  readerPageSource,
  /private ReaderInputLayer\(\)[\s\S]*\.zIndex\(12\)[\s\S]*\.hitTestBehavior\(HitTestMode\.Block\)[\s\S]*\.gesture\(GestureGroup\(GestureMode\.Parallel,[\s\S]*GestureGroup\(GestureMode\.Exclusive,[\s\S]*TapGesture\(\{ count: 2, fingers: 1, distanceThreshold: READER_TAP_MOVE_TOLERANCE_VP \}\)[\s\S]*this\.onReaderDoubleTap[\s\S]*TapGesture\(\{ count: 1, fingers: 1, distanceThreshold: READER_TAP_MOVE_TOLERANCE_VP \}\)[\s\S]*this\.onReaderTap[\s\S]*PinchGesture\(\{ fingers: 2 \}\)[\s\S]*this\.onReaderPinchUpdate\(event\)[\s\S]*PanGesture\(\{ fingers: 1, direction: PanDirection\.All, distance: 2 \}\)[\s\S]*this\.onReaderPanUpdate\(event\)[\s\S]*private ReaderInteractiveContentSurface\(\)[\s\S]*\.scale\(\{ x: this\.zoomScale, y: this\.zoomScale \}\)[\s\S]*\.translate\(\{ x: this\.zoomOffsetX, y: this\.zoomOffsetY \}\)[\s\S]*this\.ReaderInputLayer\(\)/,
  'reader input layer must stay below chrome while owning tap, pinch, and zoomed pan gestures for the scaled content surface',
)
assert.match(
  readerPageSource,
  /ReaderChrome\(\{[\s\S]*\.zIndex\(20\)[\s\S]*\.hitTestBehavior\(this\.activeChromeVisible \? HitTestMode\.Transparent : HitTestMode\.None\)/,
  'reader chrome wrapper must not block hidden reader input and must allow visible center taps to dismiss chrome through the reader input layer',
)
assert.match(
  readerPageSource,
  /private handleReaderSwipeCandidate\(point: ReaderTouchPoint\): boolean \{[\s\S]*!this\.swipeNavigationEnabled[\s\S]*this\.zoomScale > 1\.01[\s\S]*this\.currentReaderMode\(\) === ReaderMode\.CONTINUOUS_SCROLL[\s\S]*READER_SWIPE_PAGE_THRESHOLD_VP[\s\S]*READER_SWIPE_VERTICAL_REJECT_RATIO[\s\S]*this\.nextPage\(\)[\s\S]*this\.previousPage\(\)/,
  'reader input layer must keep unzoomed horizontal swipe navigation available without breaking zoomed panning or continuous scroll',
)
assert.match(
  readerPageSource,
  /const READER_ZOOM_EDGE_PAGE_DRAG_RATIO: number = 0\.16[\s\S]*type ReaderHorizontalEdge = 'left' \| 'right'[\s\S]*private onReaderPanUpdate\(event\?: GestureEvent\): void \{[\s\S]*this\.zoomPanLatestOffsetX = event\.offsetX as number[\s\S]*private onReaderPanEnd\(\): void \{[\s\S]*!this\.swipeNavigationEnabled \|\| this\.currentReaderMode\(\) === ReaderMode\.CONTINUOUS_SCROLL[\s\S]*pulledLeftEdge[\s\S]*this\.canNavigateFromReaderHorizontalEdge\('left'\)[\s\S]*this\.navigateFromReaderHorizontalEdge\('left'\)[\s\S]*pulledRightEdge[\s\S]*this\.canNavigateFromReaderHorizontalEdge\('right'\)[\s\S]*this\.navigateFromReaderHorizontalEdge\('right'\)/,
  'zoomed reader pan must turn an edge pull into direction-aware page navigation instead of trapping the user on the zoomed page',
)
assert.match(
  readerPageSource,
  /PanGesture\(\{ fingers: 1, direction: PanDirection\.All, distance: 2 \}\)[\s\S]*this\.onReaderPanUpdate\(event\)[\s\S]*\.onActionEnd\(\(\) => \{[\s\S]*this\.onReaderPanEnd\(\)[\s\S]*\.onActionCancel\(\(\) => \{[\s\S]*this\.onReaderPanEnd\(\)/,
  'reader pan gesture must run zoom edge navigation on both end and cancel paths',
)
assert.doesNotMatch(
  readerPageSource,
  /private ReaderTapLayer\(\)[\s\S]*\.onClick\(\(\) => \{[\s\S]*this\.tapRightZone\(\)/,
  'tap overlay must not regress to click-column navigation',
)
assert.match(
  readerPageSource,
  /const READER_WEBTOON_TAP_ROW_RATIO: number = 0\.33[\s\S]*private readerNavigationActionAt\(tapX: number, tapY: number\): ReaderNavigationAction[\s\S]*const x = this\.clampTapRatio\(tapX \/ width\)[\s\S]*const y = this\.clampTapRatio\(tapY \/ height\)[\s\S]*this\.currentReaderMode\(\) === ReaderMode\.CONTINUOUS_SCROLL[\s\S]*y <= READER_WEBTOON_TAP_ROW_RATIO[\s\S]*return 'previous'[\s\S]*y >= 1 - READER_WEBTOON_TAP_ROW_RATIO[\s\S]*return 'next'[\s\S]*x <= READER_WEBTOON_TAP_ROW_RATIO[\s\S]*return 'left'[\s\S]*x >= 1 - READER_WEBTOON_TAP_ROW_RATIO[\s\S]*return 'right'[\s\S]*x <= edge[\s\S]*return 'left'[\s\S]*x >= 1 - edge[\s\S]*return 'right'[\s\S]*return 'menu'/,
  'reader navigation must use Mihon-style mode-specific tap regions instead of one layout for every reader mode',
)
assert.match(
  readerPageSource,
  /private ReaderTapZoneVisualOverlay\(\)[\s\S]*this\.currentReaderMode\(\) === ReaderMode\.CONTINUOUS_SCROLL[\s\S]*this\.WebtoonTapZoneVisualOverlay\(\)[\s\S]*this\.PagerTapZoneVisualOverlay\(\)[\s\S]*private PagerTapZoneVisualOverlay\(\)[\s\S]*\.width\(this\.tapEdgeZoneWidth\(\)\)[\s\S]*private WebtoonTapZoneVisualOverlay\(\)[\s\S]*\.height\('33%'\)[\s\S]*\.width\('33%'\)/,
  'tap-zone visualization must mirror the active Mihon-style paged or webtoon navigation regions',
)
assert.match(
  readerPageSource,
  /private readDefaultDisplayWidthVp\(\): number[\s\S]*this\.getUIContext\(\)\.px2vp\(defaultDisplay\.width\)[\s\S]*private readDefaultDisplayHeightVp\(\): number[\s\S]*this\.getUIContext\(\)\.px2vp\(defaultDisplay\.height\)[\s\S]*const height = this\.readerSurfaceHeightVp > 0 \? this\.readerSurfaceHeightVp : this\.readDefaultDisplayHeightVp\(\)/,
  'reader tap navigation must keep display fallback size in vp so center taps do not become edge zones',
)

assert.match(
  backupServiceSource,
  /backgroundMode:\s*settings\.backgroundMode \?\? DEFAULT_READER_PREFERENCES\.backgroundMode[\s\S]*imageFitMode:\s*settings\.imageFitMode \?\? DEFAULT_READER_PREFERENCES\.imageFitMode[\s\S]*tapNavigationEnabled:\s*settings\.tapNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled:\s*settings\.swipeNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.swipeNavigationEnabled[\s\S]*tapZonePreset:\s*settings\.tapZonePreset \?\? DEFAULT_READER_PREFERENCES\.tapZonePreset[\s\S]*showTapZones:\s*settings\.showTapZones \?\? DEFAULT_READER_PREFERENCES\.showTapZones[\s\S]*pageGapMode:\s*settings\.pageGapMode \?\? DEFAULT_READER_PREFERENCES\.pageGapMode[\s\S]*trimPageMarginsEnabled:\s*settings\.trimPageMarginsEnabled \?\? DEFAULT_READER_PREFERENCES\.trimPageMarginsEnabled[\s\S]*wideImageMode:\s*settings\.wideImageMode \?\? DEFAULT_READER_PREFERENCES\.wideImageMode[\s\S]*volumeKeyNavigationEnabled:\s*settings\.volumeKeyNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.volumeKeyNavigationEnabled[\s\S]*volumeKeyBehavior:\s*settings\.volumeKeyBehavior \?\? DEFAULT_READER_PREFERENCES\.volumeKeyBehavior/,
  'backup import must preserve backward compatibility while restoring advanced reader settings',
)

console.log('reader settings static tests passed')
