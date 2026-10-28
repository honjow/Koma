import { ReadingDirection } from './ComicModels'
import { ReaderSeriesModeOverride, readerModeSelection } from './ReaderPreferencesStore'

export type ReaderDirectionChoice = 'ltr' | 'rtl' | 'vertical_page' | 'continuous'

/** Same four mutually exclusive reading methods as the existing control-bar direction button. */
export function readerControlDirection(current: ReaderSeriesModeOverride): ReaderDirectionChoice {
  if (current.pageMode === 'continuous_scroll' ||
    (current.pageMode !== 'vertical_page' && current.readingDirection === ReadingDirection.WEBTOON)) return 'continuous'
  if (current.pageMode === 'vertical_page') return 'vertical_page'
  return current.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? 'rtl' : 'ltr'
}

export function readerControlDirectionSelection(current: ReaderSeriesModeOverride,
  choice: ReaderDirectionChoice): ReaderSeriesModeOverride {
  if (choice === 'continuous') return readerModeSelection(current, 'continuous_scroll')
  if (choice === 'vertical_page') return readerModeSelection(current, 'vertical_page')
  return { pageMode: current.pageMode === 'double_page' && readerControlDirection(current) !== 'continuous' ? 'double_page' : 'single_page',
    readingDirection: choice === 'rtl' ? ReadingDirection.RIGHT_TO_LEFT : ReadingDirection.LEFT_TO_RIGHT }
}

export function readerControlDirectionLabelKey(choice: ReaderDirectionChoice): string {
  if (choice === 'continuous') return 'reader_page_mode_continuous'
  if (choice === 'vertical_page') return 'reader_page_mode_vertical_page'
  return choice === 'rtl' ? 'reader_direction_rtl' : 'reader_direction_ltr'
}
