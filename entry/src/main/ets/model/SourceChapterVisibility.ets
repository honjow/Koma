import { MangaChapterItem } from './MangaDetailModels'

export function sourceChapterExclusions(value: Object | undefined): string[] {
  if (value === undefined) return []
  if (!Array.isArray(value) || value.length > 10000) throw new Error('source_chapter_exclusions_invalid')
  const ids: string[] = []
  const seen: Set<string> = new Set<string>()
  value.forEach((id: Object): void => {
    if (typeof id !== 'string' || id.trim().length === 0 || id.length > 4096) {
      throw new Error('source_chapter_exclusions_invalid')
    }
    if (!seen.has(id)) {
      ids.push(id)
      seen.add(id)
    }
  })
  return ids
}

/** Keep 9a55a47a's retained-chapter protection. Only a source's explicit current
 * filter exclusions change the displayed rows; this never edits stored chapters,
 * downloads or progress. Absence of a remote row alone is still not an exclusion.
 */
export function sourceChapterDisplayRows(
  current: MangaChapterItem[], retained: MangaChapterItem[], excludedChapterIds: string[] = [],
): MangaChapterItem[] {
  const excluded = new Set<string>(excludedChapterIds)
  const displayed = current.filter((chapter: MangaChapterItem): boolean => !excluded.has(chapter.id))
  const ids = new Set<string>(displayed.map((chapter: MangaChapterItem): string => chapter.id))
  retained.forEach((chapter: MangaChapterItem): void => {
    if (!ids.has(chapter.id) && !excluded.has(chapter.id)) {
      displayed.push(chapter)
      ids.add(chapter.id)
    }
  })
  return displayed
}
