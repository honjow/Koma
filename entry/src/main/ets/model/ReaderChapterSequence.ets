import { SourceChapterOrder } from '../sourceRuntime/SourceChapterOrder'

/** Complete manual catalog metadata; never derives edition or order from a title. */
export interface ReaderChapterDescriptor {
  id: string
  title: string
  chapterNumber?: number
  dateUpload?: number
  volumeNumber?: string
  readingGroup?: string
  continuationEligible?: boolean
}

export function cloneReaderChapterDescriptor(chapter: ReaderChapterDescriptor): ReaderChapterDescriptor {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.chapterNumber,
    dateUpload: chapter.dateUpload,
    volumeNumber: chapter.volumeNumber,
    readingGroup: chapter.readingGroup,
    continuationEligible: chapter.continuationEligible,
  }
}

/** Initial reading follows published chapter metadata, never the display-list direction. */
export function firstReaderChapter(
  chapters: ReaderChapterDescriptor[],
  sourceOrder?: SourceChapterOrder,
  isRead?: (chapterId: string) => boolean,
): ReaderChapterDescriptor | undefined {
  // Adopted Mihon rule: chronology belongs to the source contract, not the
  // user's display direction or inferred numbers. Existing resume/explicit
  // targets remain owned by callers. Undeclared sources keep the legacy
  // fallback until their actual catalog direction has been established.
  if (sourceOrder === 'newest_first' || sourceOrder === 'oldest_first') {
    for (let offset = 0; offset < chapters.length; offset += 1) {
      const index = sourceOrder === 'newest_first' ? chapters.length - 1 - offset : offset
      const chapter = chapters[index]
      if (isRead === undefined || !isRead(chapter.id)) return chapter
    }
    return undefined
  }
  let numbered: ReaderChapterDescriptor | undefined = undefined
  let dated: ReaderChapterDescriptor | undefined = undefined
  chapters.forEach((chapter: ReaderChapterDescriptor): void => {
    const number = chapter.chapterNumber
    if (number !== undefined && Number.isFinite(number) && number >= 0 &&
      (numbered === undefined || number < (numbered.chapterNumber as number))) numbered = chapter
    const date = chapter.dateUpload
    if (date !== undefined && Number.isFinite(date) && date > 0 &&
      (dated === undefined || date < (dated.dateUpload as number))) dated = chapter
  })
  return numbered ?? dated ?? chapters[0]
}

function readingOrder(chapter: ReaderChapterDescriptor): number | undefined {
  if (chapter.volumeNumber !== undefined && chapter.volumeNumber.trim().length > 0) {
    const volume = Number(chapter.volumeNumber)
    if (Number.isFinite(volume)) {
      return volume
    }
  }
  return chapter.chapterNumber !== undefined && Number.isFinite(chapter.chapterNumber)
    ? chapter.chapterNumber : undefined
}

/**
 * One-shot chapter open intent for the natural chapter-edge crossing
 * (RDR-004-B). `resume` keeps the saved position; `start`/`end` are only
 * produced by a boundary crossing and are never persisted.
 */
export type ReaderChapterOpenIntent = 'resume' | 'start' | 'end'

/**
 * Automatic chapter-edge crossing needs a verified derived sequence: more than
 * one entry and the current chapter inside it. `undefined` (legacy) and
 * `[currentId]` (a contract without an eligible group) are explicit navigation
 * only — `continuationChapterIds`'s `?? chapterIds` fallback must never be used
 * to justify an automatic crossing.
 */
export function automaticContinuationChapterIds(
  ids: string[] | undefined,
  currentId: string,
): string[] | undefined {
  if (ids === undefined || ids.length <= 1) {
    return undefined
  }
  return ids.includes(currentId) ? ids : undefined
}

/** undefined is legacy explicit navigation, not a verified automatic sequence. */
export function continuationChapterIds(
  chapters: ReaderChapterDescriptor[],
  currentId: string,
): string[] | undefined {
  const current = chapters.find((chapter: ReaderChapterDescriptor): boolean => chapter.id === currentId)
  if (current === undefined) {
    return undefined
  }
  if (current.readingGroup === undefined && current.continuationEligible === undefined) {
    return undefined
  }
  const group = current.readingGroup
  if (current.continuationEligible !== true || group === undefined || group.trim().length === 0 ||
    readingOrder(current) === undefined) {
    return [currentId]
  }
  // Filter before numeric comparison: unknown ordinals must not participate in sorting.
  const eligible = chapters.filter((chapter: ReaderChapterDescriptor): boolean =>
    chapter.readingGroup === group && chapter.continuationEligible === true && readingOrder(chapter) !== undefined)
  eligible.sort((left: ReaderChapterDescriptor, right: ReaderChapterDescriptor): number =>
    (readingOrder(left) as number) - (readingOrder(right) as number) || chapters.indexOf(left) - chapters.indexOf(right))
  return eligible.map((chapter: ReaderChapterDescriptor): string => chapter.id)
}
