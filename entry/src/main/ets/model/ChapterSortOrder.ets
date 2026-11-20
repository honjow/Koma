import type { ChapterSortBasis } from './MangaDetailModels'

export interface ChapterSortPolicy {
  basis: ChapterSortBasis
  locale?: string
}

export interface SortableChapter {
  title: string
  chapterNumber?: number
  dateUpload?: number
}

function sortValue(value: number | undefined, fallback: number): number {
  return value !== undefined && Number.isFinite(value) && value >= 0 ? value : fallback
}

/** Ascending comparison. Callers provide source order for ties and choose
 * whether to reverse the displayed list. Reading always uses this direction. */
export function compareChapterSort(left: SortableChapter, right: SortableChapter, policy: ChapterSortPolicy): number {
  switch (policy.basis) {
    case 'chapter_number':
      return sortValue(left.chapterNumber, -1) - sortValue(right.chapterNumber, -1)
    case 'upload_date':
      return sortValue(left.dateUpload, 0) - sortValue(right.dateUpload, 0)
    case 'name':
      return left.title.localeCompare(right.title, policy.locale)
    default:
      return 0
  }
}
