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
      chapter.continuationEligible !== undefined || chapter.readingOrder !== undefined) ||
    new Set<string>(chapters.map((chapter: MangaChapterItem): string => chapter.id)).size !== chapters.length) {
    return chapters
  }
  const result = JSON.parse(JSON.stringify(chapters)) as MangaChapterItem[]
  result.forEach((chapter: MangaChapterItem, index: number): void => {
    chapter.readingGroup = 'source-catalog'
    chapter.readingOrder = order === 'oldest_first' ? index : result.length - index - 1
    chapter.continuationEligible = true
  })
  return result
}
