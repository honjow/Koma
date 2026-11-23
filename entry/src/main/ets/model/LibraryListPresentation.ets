import { Comic, ReadingProgress } from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'

export interface LibraryListDetails {
  authorText: string
  status: string
  readingText: string
  pageText: string
  unreadText: string
  sourceName: string
  chapterText: string
}

/** A shelf list describes the work, then its saved reading position, then
 * availability. Inputs are prepared shelf facts; this projection performs no I/O.
 * A completed chapter does not mean the entire work has been read. */
export function createLibraryListDetails(comic: Comic, progress: ReadingProgress | undefined,
  chapterTitle: string | undefined, unread: number | undefined, started: boolean, sourceName: string,
  chapterCount?: number): LibraryListDetails {
  const author = comic.localMetadata?.authors?.join('、') || comic.author?.trim() || ''
  const status = comic.sourceMetadata?.status ?? comic.localMetadata?.status
  const title = chapterTitle?.trim() ?? ''
  const readableTitle = title.length > 0 && !title.startsWith('ch:') && !(title.length >= 32 && title.includes('-'))
  let readingText: string
  if (progress !== undefined) {
    readingText = readableTitle ? title :
      AppStrings.get('library_progress_continue_generic')
  } else if (unread === 0) {
    readingText = AppStrings.get('library_progress_finished')
  } else if (started) {
    readingText = AppStrings.get('library_read_state_reading')
  } else {
    readingText = AppStrings.get('library_list_not_started')
  }
  const hasPage = progress !== undefined && Number.isFinite(progress.totalPages) && progress.totalPages > 0 &&
    Number.isFinite(progress.pageIndex) && progress.pageIndex >= 0
  return {
    authorText: author,
    status: status === 'ongoing' || status === 'completed' || status === 'hiatus' || status === 'cancelled' ? status : '',
    readingText,
    pageText: hasPage ? AppStrings.format('manga_detail_resume_page',
      Math.min(Math.floor((progress as ReadingProgress).pageIndex) + 1, (progress as ReadingProgress).totalPages),
      (progress as ReadingProgress).totalPages) : '',
    unreadText: unread !== undefined && unread >= 0 ? `${unread}` : '',
    sourceName,
    chapterText: chapterCount !== undefined && chapterCount > 0 ? `${chapterCount}` : '',
  }
}
