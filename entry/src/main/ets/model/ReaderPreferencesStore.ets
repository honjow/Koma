import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ReadingDirection } from './ComicModels'
import { ReaderMode } from './ReaderSessionStore'

export type ReaderPageMode = 'single_page' | 'double_page' | 'continuous_scroll'
export type ReaderThemeMode = 'system' | 'light' | 'dark'
export type ReaderBackgroundMode = 'black' | 'paper' | 'light'
export type ReaderImageFitMode = 'contain' | 'fit_width'
export type ReaderPageGapMode = 'compact' | 'normal' | 'wide'

export interface ReaderPreferences {
  pageMode: ReaderPageMode
  readingDirection: ReadingDirection
  themeMode: ReaderThemeMode
  backgroundMode: ReaderBackgroundMode
  showProgressControls: boolean
  keepScreenAwake: boolean
  imageFitMode: ReaderImageFitMode
  tapNavigationEnabled: boolean
  pageGapMode: ReaderPageGapMode
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
export const PAGE_GAP_MODE_KEY: string = 'reader.pageGapMode'

export const DEFAULT_READER_PREFERENCES: ReaderPreferences = {
  pageMode: 'single_page',
  readingDirection: ReadingDirection.LEFT_TO_RIGHT,
  themeMode: 'system',
  backgroundMode: 'black',
  showProgressControls: true,
  keepScreenAwake: true,
  imageFitMode: 'contain',
  tapNavigationEnabled: true,
  pageGapMode: 'normal',
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

export function normalizeReaderPageGapMode(value: string): ReaderPageGapMode {
  if (value === 'compact' || value === 'wide') {
    return value
  }
  return 'normal'
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

export function normalizeReaderReadingDirection(value: string): ReadingDirection {
  if (value === ReadingDirection.RIGHT_TO_LEFT || value === ReadingDirection.WEBTOON) {
    return value
  }
  return ReadingDirection.LEFT_TO_RIGHT
}

export function getReaderPageModeLabel(mode: ReaderPageMode): string {
  if (mode === 'continuous_scroll') {
    return '连续滚动'
  }
  if (mode === 'double_page') {
    return '双页'
  }
  return '单页'
}

export function getReadingDirectionLabel(direction: ReadingDirection): string {
  if (direction === ReadingDirection.RIGHT_TO_LEFT) {
    return '从右到左'
  }
  if (direction === ReadingDirection.WEBTOON) {
    return '纵向'
  }
  return '从左到右'
}

export function getReaderThemeModeLabel(mode: ReaderThemeMode): string {
  if (mode === 'dark') {
    return '深色'
  }
  if (mode === 'light') {
    return '浅色'
  }
  return '跟随系统'
}

export function getReaderBackgroundModeLabel(mode: ReaderBackgroundMode): string {
  if (mode === 'paper') {
    return '纸张'
  }
  if (mode === 'light') {
    return '浅色'
  }
  return '黑色'
}

export function getReaderProgressControlsLabel(showProgressControls: boolean): string {
  return showProgressControls ? '显示' : '隐藏'
}

export function getReaderKeepScreenAwakeLabel(keepScreenAwake: boolean): string {
  return keepScreenAwake ? '开启' : '关闭'
}

export function getReaderImageFitModeLabel(mode: ReaderImageFitMode): string {
  if (mode === 'fit_width') {
    return '适合宽度'
  }
  return '适合屏幕'
}

export function getReaderTapNavigationLabel(tapNavigationEnabled: boolean): string {
  return tapNavigationEnabled ? '开启' : '关闭'
}

export function getReaderPageGapModeLabel(mode: ReaderPageGapMode): string {
  if (mode === 'compact') {
    return '紧凑'
  }
  if (mode === 'wide') {
    return '宽松'
  }
  return '标准'
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
    const pageGapMode = await store.get(PAGE_GAP_MODE_KEY, DEFAULT_READER_PREFERENCES.pageGapMode) as string
    return {
      pageMode: normalizeReaderPageMode(pageMode),
      readingDirection: normalizeReaderReadingDirection(readingDirection),
      themeMode: normalizeReaderThemeMode(themeMode),
      backgroundMode: normalizeReaderBackgroundMode(backgroundMode),
      showProgressControls: normalizeReaderProgressControls(showProgressControls),
      keepScreenAwake: normalizeReaderKeepScreenAwake(keepScreenAwake),
      imageFitMode: normalizeReaderImageFitMode(imageFitMode),
      tapNavigationEnabled: normalizeReaderTapNavigationEnabled(tapNavigationEnabled),
      pageGapMode: normalizeReaderPageGapMode(pageGapMode),
    }
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
    await store.put(BACKGROUND_MODE_KEY, backgroundMode)
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

  async savePageGapMode(pageGapMode: ReaderPageGapMode): Promise<void> {
    const store = await this.preferences()
    await store.put(PAGE_GAP_MODE_KEY, normalizeReaderPageGapMode(pageGapMode))
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
    await store.put(PAGE_GAP_MODE_KEY, normalizeReaderPageGapMode(preferences.pageGapMode))
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_PREFERENCES_STORE_NAME)
  }
}
