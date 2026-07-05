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
  /export interface ReaderSeriesPreferenceOverrides \{[\s\S]*pageMode\?: ReaderPageMode[\s\S]*readingDirection\?: ReadingDirection[\s\S]*tapNavigationEnabled\?: boolean[\s\S]*tapZonePreset\?: ReaderTapZonePreset/,
  'reader preferences must model per-series overrides for mode, direction, and tap-zone behavior',
)
assert.match(
  readerPreferencesStoreSource,
  /SERIES_OVERRIDES_KEY:\s*string = 'reader\.seriesOverrides\.v1'/,
  'per-series reader preferences must use a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /DEFAULT_READER_PREFERENCES:[\s\S]*backgroundMode:\s*'black'[\s\S]*imageFitMode:\s*'contain'[\s\S]*tapNavigationEnabled:\s*true[\s\S]*swipeNavigationEnabled:\s*true[\s\S]*tapZonePreset:\s*'edge'[\s\S]*showTapZones:\s*false[\s\S]*pageGapMode:\s*'normal'[\s\S]*trimPageMarginsEnabled:\s*false[\s\S]*wideImageMode:\s*'keep_single'[\s\S]*volumeKeyNavigationEnabled:\s*false/,
  'new reader settings must default to black background, contain fit, enabled narrow-edge tap and swipe navigation, hidden tap-zone overlay, normal spacing, no trim, keep-wide-as-single-page, and no volume-key navigation',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderBackgroundMode\(value: string\): ReaderBackgroundMode[\s\S]*value === 'paper' \|\| value === 'light'[\s\S]*return 'black'/,
  'reader background loading must normalize unsupported values back to the current black background',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderImageFitMode\(value: string\)[\s\S]*value === 'fit_width'[\s\S]*return 'contain'/,
  'image fit loading must be backward-compatible with missing or invalid saved values',
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
  /mergeReaderSeriesPreferences[\s\S]*pageMode: overrides\.pageMode \?\? globalPreferences\.pageMode[\s\S]*readingDirection: overrides\.readingDirection \?\? globalPreferences\.readingDirection[\s\S]*tapNavigationEnabled: overrides\.tapNavigationEnabled \?\? globalPreferences\.tapNavigationEnabled[\s\S]*tapZonePreset: overrides\.tapZonePreset \?\? globalPreferences\.tapZonePreset[\s\S]*wideImageMode: globalPreferences\.wideImageMode/,
  'per-series overrides must stay scoped to reader mode, direction, and tap zones while inheriting global image behavior',
)
assert.match(
  readerPageSource,
  /new ReaderPreferencesStore\(context\)\.loadForComic\(this\.sessionConfig\.comicId\)/,
  'ReaderPage must load per-series preferences for the active comic instead of only global defaults',
)
assert.match(
  readerPageSource,
  /currentSeriesPreferenceOverrides\(\): ReaderSeriesPreferenceOverrides[\s\S]*pageMode: this\.pageModeForSeriesPreferences\(\)[\s\S]*readingDirection: this\.readingDirection[\s\S]*tapNavigationEnabled: this\.tapNavigationEnabled[\s\S]*tapZonePreset: this\.tapZonePreset/,
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
  /onSaveSeriesPreferences[\s\S]*onClearSeriesPreferences[\s\S]*reader_action_save_series_settings[\s\S]*this\.onSaveSeriesPreferences\(\)[\s\S]*reader_action_clear_series_settings[\s\S]*this\.onClearSeriesPreferences\(\)/,
  'ReaderChrome must expose real per-series save and clear actions instead of leaving the store unreachable',
)
assert.match(
  readerChromeSource,
  /tapNavigationEnabled[\s\S]*tapZonePreset: ReaderTapZonePreset[\s\S]*readingDirection: ReadingDirection[\s\S]*onTapZonePresetChange[\s\S]*TapZonePresetOption\([\s\S]*this\.setTapZonePreset\(preset\)[\s\S]*TapZonePreview\(\)[\s\S]*reader_tap_zone_edge[\s\S]*reader_tap_zone_wide[\s\S]*tapZoneActionLabel\(true\)[\s\S]*reader_tap_zone_center[\s\S]*tapZoneActionLabel\(false\)/,
  'ReaderChrome must visualize and change the active tap-zone preset with RTL-aware left/right actions',
)
assert.match(
  readerPageSource,
  /ReaderChrome\(\{[\s\S]*tapNavigationEnabled: this\.tapNavigationEnabled[\s\S]*tapZonePreset: this\.tapZonePreset[\s\S]*readingDirection: this\.readingDirection[\s\S]*onTapZonePresetChange: \(preset: ReaderTapZonePreset\) => \{[\s\S]*this\.tapZonePreset = preset/,
  'ReaderPage must pass and apply live tap-zone preferences for runtime visualization',
)
allReaderStringSources.forEach((source, index) => {
  assert.match(source, /"name": "reader_tap_zone_center"/, `reader tap-zone center label must exist in locale ${index}`)
})

assert.match(settingsPageSource, /key: 'reader-image-fit', titleKey: 'settings_row_reader_image_fit_title'/, 'Settings must expose an image fit row')
assert.match(settingsPageSource, /key: 'reader-background', titleKey: 'settings_row_reader_background_title'/, 'Settings must expose a reader background row')
assert.match(settingsPageSource, /key: 'reader-tap-navigation', titleKey: 'settings_row_reader_tap_navigation_title'/, 'Settings must expose a tap navigation row')
assert.match(settingsPageSource, /key: 'reader-swipe-navigation', titleKey: 'settings_row_reader_swipe_navigation_title'/, 'Settings must expose a swipe navigation row')
assert.match(settingsPageSource, /key: 'reader-tap-zone-preset', titleKey: 'settings_row_reader_tap_zone_preset_title'/, 'Settings must expose a tap-zone preset row')
assert.match(settingsPageSource, /key: 'reader-show-tap-zones', titleKey: 'settings_row_reader_show_tap_zones_title'/, 'Settings must expose a tap-zone visualization row')
assert.match(settingsPageSource, /key: 'reader-page-gap', titleKey: 'settings_row_reader_page_gap_title'/, 'Settings must expose a page gap row')
assert.match(settingsPageSource, /key: 'reader-trim-page-margins', titleKey: 'settings_row_reader_trim_page_margins_title'/, 'Settings must expose an honest non-cropping trim row')
assert.match(settingsPageSource, /key: 'reader-wide-image-mode', titleKey: 'settings_row_reader_wide_image_mode_title'/, 'Settings must expose a wide image handling row')
assert.match(settingsPageSource, /key: 'reader-volume-key-navigation', titleKey: 'settings_row_reader_volume_key_navigation_title'/, 'Settings must expose a volume-key navigation preference row')
assert.match(settingsPageSource, /reader-image-fit[\s\S]*SelectionMenuItem\(s\('reader_image_fit_screen'\)[\s\S]*SelectionMenuItem\(s\('reader_image_fit_width'\)/, 'image fit menu must expose contain and fit-width choices')
assert.match(settingsPageSource, /reader-background[\s\S]*SelectionMenuItem\(s\('reader_background_black'\)[\s\S]*saveReaderBackgroundMode\('black'\)[\s\S]*SelectionMenuItem\(s\('reader_background_paper'\)[\s\S]*saveReaderBackgroundMode\('paper'\)[\s\S]*SelectionMenuItem\(s\('reader_background_light'\)[\s\S]*saveReaderBackgroundMode\('light'\)/, 'reader background menu must expose black, paper, and light choices')
assert.match(settingsPageSource, /reader-tap-navigation[\s\S]*saveReaderTapNavigationEnabled\(value\)/, 'tap navigation row must expose a real switch-backed on/off choice')
assert.match(settingsPageSource, /reader-swipe-navigation[\s\S]*saveReaderSwipeNavigationEnabled\(value\)/, 'swipe navigation row must expose a real switch-backed on/off choice')
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
  /backgroundMode = preferences\.backgroundMode[\s\S]*imageFitMode = preferences\.imageFitMode[\s\S]*tapNavigationEnabled = preferences\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled = preferences\.swipeNavigationEnabled[\s\S]*tapZonePreset = preferences\.tapZonePreset[\s\S]*showTapZones = preferences\.showTapZones[\s\S]*pageGapMode = preferences\.pageGapMode[\s\S]*trimPageMarginsEnabled = preferences\.trimPageMarginsEnabled[\s\S]*wideImageMode = preferences\.wideImageMode/,
  'ReaderPage must apply persisted advanced settings after load',
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
  /private pageContainerPadding\(compact: boolean\): number[\s\S]*this\.trimPageMarginsEnabled[\s\S]*return 0[\s\S]*return compact \? 8 : 10/,
  'trim page margins must remove only Koma page-container inset without cropping image pixels',
)
assert.match(
  readerPageSource,
  /private pageContainerRadius\(compact: boolean\): number[\s\S]*this\.trimPageMarginsEnabled[\s\S]*return 0[\s\S]*return compact \? 22 : 28/,
  'trim page margins must not combine zero inset with rounded clipped page containers',
)
assert.match(
  readerPageSource,
  /\.padding\(this\.pageContainerPadding\(compact\)\)[\s\S]*\.clip\(true\)/,
  'reader pages must apply trim through container padding, not image crop mode',
)
assert.match(
  readerPageSource,
  /private singlePageWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '98%'[\s\S]*this\.pageGapMode === 'compact'[\s\S]*return '96%'[\s\S]*this\.pageGapMode === 'wide'[\s\S]*return '90%'[\s\S]*return '94%'/,
  'single-page reader must default to a real reading width while preserving wider fit-width mode',
)
assert.match(
  readerPageSource,
  /private singlePageMaxWidth\(\): number[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return 900[\s\S]*return 720/,
  'single-page default max width must not regress to thumbnail-sized reader cards',
)
assert.match(
  readerPageSource,
  /private dualPageSlotWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '96%'[\s\S]*return '88%'/,
  'dual-page slots must widen for fit-width',
)
assert.match(
  readerPageSource,
  /private webtoonPageWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '98%'[\s\S]*return '94%'/,
  'webtoon page width must default to a real reading width and still widen for fit-width',
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
  /\.disableSwipe\(!this\.swipeNavigationEnabled\)/,
  'paged reader swipers must honor the swipe navigation switch without disabling tap or hardware navigation',
)
assert.match(
  readerPageSource,
  /private TapNavigationOverlay\(\)[\s\S]*\.width\(this\.tapEdgeZoneWidth\(\)\)[\s\S]*\.backgroundColor\(this\.tapZoneOverlayColor\(\)\)[\s\S]*\.layoutWeight\(1\)[\s\S]*\.backgroundColor\(Color\.Transparent\)[\s\S]*\.width\(this\.tapEdgeZoneWidth\(\)\)[\s\S]*\.backgroundColor\(this\.tapZoneOverlayColor\(\)\)/,
  'tap overlay must size only the center with layout weight, keep left/right as explicit edge zones, and visualize only the page-turn areas',
)
assert.doesNotMatch(
  readerPageSource,
  /Row\(\) \{\s*Column\(\)[\s\S]*?\.layoutWeight\(1\)[\s\S]*?Column\(\)[\s\S]*?\.layoutWeight\(1\)[\s\S]*?Column\(\)[\s\S]*?\.layoutWeight\(1\)[\s\S]*?this\.tapRightZone\(\)/,
  'tap overlay must not use three equal full-height layoutWeight(1) columns for left/center/right',
)

assert.match(
  backupServiceSource,
  /backgroundMode:\s*settings\.backgroundMode \?\? DEFAULT_READER_PREFERENCES\.backgroundMode[\s\S]*imageFitMode:\s*settings\.imageFitMode \?\? DEFAULT_READER_PREFERENCES\.imageFitMode[\s\S]*tapNavigationEnabled:\s*settings\.tapNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.tapNavigationEnabled[\s\S]*swipeNavigationEnabled:\s*settings\.swipeNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.swipeNavigationEnabled[\s\S]*tapZonePreset:\s*settings\.tapZonePreset \?\? DEFAULT_READER_PREFERENCES\.tapZonePreset[\s\S]*showTapZones:\s*settings\.showTapZones \?\? DEFAULT_READER_PREFERENCES\.showTapZones[\s\S]*pageGapMode:\s*settings\.pageGapMode \?\? DEFAULT_READER_PREFERENCES\.pageGapMode[\s\S]*trimPageMarginsEnabled:\s*settings\.trimPageMarginsEnabled \?\? DEFAULT_READER_PREFERENCES\.trimPageMarginsEnabled[\s\S]*wideImageMode:\s*settings\.wideImageMode \?\? DEFAULT_READER_PREFERENCES\.wideImageMode[\s\S]*volumeKeyNavigationEnabled:\s*settings\.volumeKeyNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.volumeKeyNavigationEnabled/,
  'backup import must preserve backward compatibility while restoring advanced reader settings',
)

console.log('reader settings static tests passed')
