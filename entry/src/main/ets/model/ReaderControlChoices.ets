import { ReadingDirection } from './ComicModels'
import { ReaderSeriesModeOverride, readerModeSelection } from './ReaderPreferencesStore'

export type ReaderDirectionChoice = 'ltr' | 'rtl' | 'vertical_page' | 'continuous' | 'continuous_ltr' | 'continuous_rtl'

/** Direction and continuous/vertical layout share the existing per-series mode override. */
export function readerControlDirection(current: ReaderSeriesModeOverride): ReaderDirectionChoice {
  if (current.pageMode === 'horizontal_continuous_scroll') {
    return current.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? 'continuous_rtl' : 'continuous_ltr'
  }
  if (current.pageMode === 'continuous_scroll' ||
    (current.pageMode !== 'vertical_page' && current.readingDirection === ReadingDirection.WEBTOON)) return 'continuous'
  if (current.pageMode === 'vertical_page') return 'vertical_page'
  return current.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? 'rtl' : 'ltr'
}

export function readerControlDirectionSelection(current: ReaderSeriesModeOverride,
  choice: ReaderDirectionChoice): ReaderSeriesModeOverride {
  if (choice === 'continuous_ltr' || choice === 'continuous_rtl') {
    return { pageMode: 'horizontal_continuous_scroll',
      readingDirection: choice === 'continuous_rtl' ? ReadingDirection.RIGHT_TO_LEFT : ReadingDirection.LEFT_TO_RIGHT }
  }
  if (choice === 'continuous') return readerModeSelection(current, 'continuous_scroll')
  if (choice === 'vertical_page') return readerModeSelection(current, 'vertical_page')
  const horizontal = current.pageMode === 'double_page' || current.pageMode === 'auto_page'
  return { pageMode: horizontal && readerControlDirection(current) !== 'continuous' ? current.pageMode : 'single_page',
    readingDirection: choice === 'rtl' ? ReadingDirection.RIGHT_TO_LEFT : ReadingDirection.LEFT_TO_RIGHT }
}

export function readerControlDirectionLabelKey(choice: ReaderDirectionChoice): string {
  if (choice === 'continuous_ltr') return 'reader_direction_continuous_ltr'
  if (choice === 'continuous_rtl') return 'reader_direction_continuous_rtl'
  if (choice === 'continuous') return 'reader_page_mode_continuous'
  if (choice === 'vertical_page') return 'reader_page_mode_vertical_page'
  return choice === 'rtl' ? 'reader_direction_rtl' : 'reader_direction_ltr'
}
