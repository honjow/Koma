import { MangaChapterItem } from './MangaDetailModels'
import { SourceChapterOrder } from '../sourceRuntime/SourceChapterOrder'

/** Only a complete source-order catalog can establish a persistent sequence.
 * Explicit source contracts and ambiguous duplicate IDs always remain untouched.
 */
export function sourceCatalogChronology(
  chapters: MangaChapterItem[], order: SourceChapterOrder | undefined,
): MangaChapterItem[] {
  if ((order !== 'oldest_first' && order !== 'newest_first') || chapters.length === 0 ||
    chapters.some((chapter: MangaChapterItem): boolean => chapter.readingGroup !== undefined ||
      chapter.continuationEligible !== undefined || chapter.readingOrder !== undefined ||
      chapter.readingVariantGroup !== undefined || chapter.readingVariantSequence !== undefined) ||
    new Set<string>(chapters.map((chapter: MangaChapterItem): string => chapter.id)).size !== chapters.length) {
    return chapters
  }
  return chapters.map((chapter: MangaChapterItem, index: number): MangaChapterItem => ({
    id: chapter.id,
    title: chapter.title,
    pageCount: chapter.pageCount,
    chapterNumber: chapter.chapterNumber,
    volumeNumber: chapter.volumeNumber,
    localReadingIndex: chapter.localReadingIndex,
    scanlator: chapter.scanlator,
    language: chapter.language,
    dateUpload: chapter.dateUpload,
    isRead: chapter.isRead,
    isBookmarked: chapter.isBookmarked,
    isDownloaded: chapter.isDownloaded,
    downloadStatus: chapter.downloadStatus,
    downloadProgress: chapter.downloadProgress,
    readingGroup: 'source-catalog',
    readingOrder: order === 'oldest_first' ? index : chapters.length - index - 1,
    continuationEligible: true,
  }))
}
