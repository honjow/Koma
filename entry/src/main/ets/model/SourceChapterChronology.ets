import { MangaChapterItem } from './MangaDetailModels'
import { SourceChapterOrder } from '../sourceRuntime/SourceChapterOrder'

/** Display numbers can identify the directory's direction. They never place
 * individual chapters, so an unnumbered entry or tied number keeps its slot. */
function catalogDirection(chapters: MangaChapterItem[]): SourceChapterOrder | undefined {
  let previous: MangaChapterItem | undefined
  let ascending = 0
  let descending = 0
  for (const chapter of chapters) {
    const number = chapter.chapterNumber
    const volume = chapter.volumeNumber?.trim() ? Number(chapter.volumeNumber) : NaN
    if (!Number.isFinite(number) && !Number.isFinite(volume)) continue
    if (previous !== undefined) {
      const previousVolume = previous.volumeNumber?.trim() ? Number(previous.volumeNumber) : NaN
      const volumeDifference = Number.isFinite(volume) && Number.isFinite(previousVolume) ? volume - previousVolume : 0
      const difference = volumeDifference || (number ?? NaN) - (previous.chapterNumber ?? NaN)
      if (difference > 0) ascending += 1
      if (difference < 0) descending += 1
    }
    previous = chapter
  }
  if (ascending === descending) return undefined
  return ascending > descending ? 'oldest_first' : 'newest_first'
}

/** Only the complete original directory can supply positions. The package's
 * direction wins. A plain list without direction evidence uses its own order.
 * Legacy groups keep their own members; explicit ordinals, alternatives and
 * source exclusions retain their existing meaning. */
export function sourceCatalogChronology(
  chapters: MangaChapterItem[], order: SourceChapterOrder | undefined,
): MangaChapterItem[] {
  if (chapters.length === 0 ||
    new Set<string>(chapters.map((chapter: MangaChapterItem): string => chapter.id)).size !== chapters.length) {
    return chapters
  }
  const hasContract = chapters.some((chapter: MangaChapterItem): boolean => chapter.readingGroup !== undefined ||
    chapter.continuationEligible !== undefined || chapter.readingOrder !== undefined ||
    chapter.readingVariantGroup !== undefined || chapter.readingVariantSequence !== undefined)
  const plainGroup = 'source-catalog'
  const directions = new Map<string, SourceChapterOrder>()
  if (!hasContract) {
    directions.set(plainGroup, order ?? catalogDirection(chapters) ?? 'oldest_first')
  } else {
    const explicitGroups = new Set<string>()
    const groups = new Map<string, MangaChapterItem[]>()
    chapters.forEach((chapter: MangaChapterItem): void => {
      const group = chapter.readingGroup
      if (!group?.trim()) return
      if (chapter.readingOrder !== undefined || chapter.readingVariantGroup !== undefined ||
        chapter.readingVariantSequence !== undefined) explicitGroups.add(group)
      if (chapter.continuationEligible !== true) return
      const rows = groups.get(group) ?? []
      rows.push(chapter)
      groups.set(group, rows)
    })
    groups.forEach((rows: MangaChapterItem[], group: string): void => {
      if (explicitGroups.has(group)) return
      directions.set(group, order ?? catalogDirection(rows) ?? 'oldest_first')
    })
  }
  if (directions.size === 0) return chapters
  return chapters.map((chapter: MangaChapterItem, index: number): MangaChapterItem => {
    const group = hasContract ? chapter.readingGroup : plainGroup
    const direction = group === undefined ? undefined : directions.get(group)
    if (direction === undefined || (hasContract && chapter.continuationEligible !== true)) return chapter
    return {
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
      readingGroup: group,
      readingOrder: direction === 'oldest_first' ? index : chapters.length - index - 1,
      continuationEligible: true,
    }
  })
}
