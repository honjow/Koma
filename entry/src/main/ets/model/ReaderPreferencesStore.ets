import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ReadingDirection } from './ComicModels'
import { ReaderMode } from './ReaderSessionStore'

export type ReaderPageMode = 'single_page' | 'double_page' | 'continuous_scroll'
export type ReaderThemeMode = 'system' | 'light' | 'dark'

export interface ReaderPreferences {
  pageMode: ReaderPageMode
  readingDirection: ReadingDirection
  themeMode: ReaderThemeMode
}

const READER_PREFERENCES_STORE_NAME: string = 'koma_reader_preferences_v1'
const PAGE_MODE_KEY: string = 'reader.pageMode'
const READING_DIRECTION_KEY: string = 'reader.readingDirection'
const THEME_MODE_KEY: string = 'reader.themeMode'

export const DEFAULT_READER_PREFERENCES: ReaderPreferences = {
  pageMode: 'single_page',
  readingDirection: ReadingDirection.LEFT_TO_RIGHT,
  themeMode: 'system',
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
    return {
      pageMode: normalizeReaderPageMode(pageMode),
      readingDirection: normalizeReaderReadingDirection(readingDirection),
      themeMode: normalizeReaderThemeMode(themeMode),
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

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_PREFERENCES_STORE_NAME)
  }
}
