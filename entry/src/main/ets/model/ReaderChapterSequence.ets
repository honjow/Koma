import { SourceChapterOrder } from '../sourceRuntime/SourceChapterOrder'
import type { Chapter } from './ComicModels'
import { ChapterSortPolicy, compareChapterSort, SortableChapter } from './ChapterSortOrder'

/** Complete manual catalog metadata; never derives edition or order from a title. */
export interface ReaderChapterDescriptor extends SortableChapter {
  id: string
  volumeNumber?: string
  readingOrder?: number
  readingGroup?: string
  readingVariantGroup?: string
  readingVariantSequence?: string
  scanlator?: string
  continuationEligible?: boolean
}

export interface ChapterReadSequenceEntry extends ReaderChapterDescriptor {
  isRead: boolean
  localReadingIndex?: number
}

/** Old snapshots can have a numeric sequence (or just the current chapter).
 * A saved exclusion may also predate the installed source's catalog rules. */
export function needsSourceCatalogChronology(chapter: ReaderChapterDescriptor | Chapter | undefined,
  fromLibrary: boolean = false): boolean {
  return chapter !== undefined && (fromLibrary || chapter.continuationEligible !== false) && chapter.readingOrder === undefined &&
    chapter.readingVariantGroup === undefined && chapter.readingVariantSequence === undefined
}

/** A bulk edit follows the same edition and chronology as reading. Local
 * imports have their own persisted index, independent of displayed numbers. */
export function previousUnreadChapterIds(chapters: ChapterReadSequenceEntry[], currentId: string): string[] {
  const current = chapters.find((chapter: ChapterReadSequenceEntry): boolean => chapter.id === currentId)
  if (current === undefined) return []
  const sequence = current.localReadingIndex === undefined ? chapters :
    chapters.map((chapter: ChapterReadSequenceEntry): ChapterReadSequenceEntry => ({
      id: chapter.id,
      title: chapter.title,
      isRead: chapter.isRead,
      readingOrder: chapter.localReadingIndex,
      readingGroup: 'local-import',
      continuationEligible: chapter.localReadingIndex !== undefined,
    }))
  const ids = continuationChapterIds(sequence, currentId) ?? []
  const end = ids.indexOf(currentId)
  if (end <= 0) return []
  const readIds = new Set<string>()
  chapters.forEach((chapter: ChapterReadSequenceEntry): void => {
    if (chapter.isRead) readIds.add(chapter.id)
  })
  return ids.slice(0, end).filter((id: string): boolean => !readIds.has(id))
}

export function cloneReaderChapterDescriptor(chapter: ReaderChapterDescriptor): ReaderChapterDescriptor {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.chapterNumber,
    dateUpload: chapter.dateUpload,
    volumeNumber: chapter.volumeNumber,
    readingOrder: chapter.readingOrder,
    readingGroup: chapter.readingGroup,
    readingVariantGroup: chapter.readingVariantGroup,
    readingVariantSequence: chapter.readingVariantSequence,
    scanlator: chapter.scanlator,
    continuationEligible: chapter.continuationEligible,
  }
}

/** Initial reading follows published chapter metadata, never the display-list direction. */
export function firstReaderChapter(
  chapters: ReaderChapterDescriptor[],
  sourceOrder?: SourceChapterOrder,
  isRead?: (chapterId: string) => boolean,
  sort?: ChapterSortPolicy,
): ReaderChapterDescriptor | undefined {
  if (sort !== undefined) {
    // If the selected metadata is missing or tied, keep the existing start.
    let first = firstReaderChapter(chapters, sourceOrder, isRead)
    if (first?.continuationEligible === false) first = undefined
    for (const chapter of chapters) {
      if (chapter.continuationEligible === false || isRead?.(chapter.id)) continue
      if (first === undefined || compareChapterSort(chapter, first, sort) < 0) first = chapter
    }
    return first
  }
  const eligible = chapters.filter((chapter: ReaderChapterDescriptor): boolean => chapter.continuationEligible === true)
  const generated = eligible.filter((chapter: ReaderChapterDescriptor): boolean =>
    chapter.readingGroup === 'source-catalog' && chapter.readingOrder !== undefined && Number.isFinite(chapter.readingOrder))
  const sequence = generated.length > 0 ? generated : eligible
  const group = sequence[0]?.readingGroup
  const positions = new Set<number>()
  let first: ReaderChapterDescriptor | undefined = undefined
  // A single complete reading group can name its own positions. Several
  // groups or alternative editions have independent positions and no shared start.
  if (group && sequence.every((chapter: ReaderChapterDescriptor): boolean => {
    const position = chapter.readingOrder
    if (position === undefined) return false
    if (generated.length === 0 && (chapter.readingGroup !== group || chapter.readingVariantGroup !== undefined ||
      chapter.readingVariantSequence !== undefined || !Number.isFinite(position) || position < 0 || positions.has(position))) return false
    positions.add(position)
    if ((isRead === undefined || !isRead(chapter.id)) &&
      (first === undefined || position < (first.readingOrder as number))) first = chapter
    return true
  })) {
    return first
  }
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
    if (isRead?.(chapter.id)) return
    const number = chapter.chapterNumber
    if (number !== undefined && Number.isFinite(number) && number >= 0 &&
      (numbered === undefined || number < (numbered.chapterNumber as number))) numbered = chapter
    const date = chapter.dateUpload
    if (date !== undefined && Number.isFinite(date) && date > 0 &&
      (dated === undefined || date < (dated.dateUpload as number))) dated = chapter
  })
  return numbered ?? dated ?? chapters.find((chapter: ReaderChapterDescriptor): boolean => !isRead?.(chapter.id))
}

function readingOrder(chapter: ReaderChapterDescriptor): number | undefined {
  // A source-verified reading sequence can contain duplicate chapter numbers
  // and unnumbered extras. Its ordinal is distinct from displayed chapter/volume.
  if (chapter.readingOrder !== undefined && Number.isFinite(chapter.readingOrder) && chapter.readingOrder >= 0) {
    return chapter.readingOrder
  }
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

/** Persistent source ordinals and edition metadata define reading order, never display sort. */
export function continuationChapterIds(
  chapters: ReaderChapterDescriptor[],
  currentId: string,
  preferScanlator: boolean = false,
  sort?: ChapterSortPolicy,
): string[] | undefined {
  const current = chapters.find((chapter: ReaderChapterDescriptor): boolean => chapter.id === currentId)
  if (current === undefined) {
    return undefined
  }
  if (current.readingGroup === undefined && current.continuationEligible === undefined) {
    // Library merges can reorder this array. SourceChapterChronology assigns
    // persistent ordinals only while consuming a complete original catalog.
    return undefined
  }
  const group = current.readingGroup
  if (current.continuationEligible !== true || group === undefined || group.trim().length === 0 ||
    readingOrder(current) === undefined) {
    return [currentId]
  }
  // Filter before numeric comparison: unknown ordinals must not participate in sorting.
  const versionSequence = preferScanlator ? current.readingVariantSequence : undefined
  const eligible = chapters.filter((chapter: ReaderChapterDescriptor): boolean =>
    (versionSequence === undefined ? chapter.readingGroup === group : chapter.readingVariantSequence === versionSequence) &&
    chapter.continuationEligible === true && readingOrder(chapter) !== undefined)
  const explicitOrder = eligible.every((chapter: ReaderChapterDescriptor): boolean =>
    chapter.readingOrder !== undefined && Number.isFinite(chapter.readingOrder) && chapter.readingOrder >= 0)
  // An ordinal is not a volume or chapter number. Do not compare partial
  // explicit ordinals with numbers from a different coordinate system.
  if (!explicitOrder && eligible.some((chapter: ReaderChapterDescriptor): boolean =>
    chapter.readingOrder !== undefined)) return [currentId]
  const volumeOrder = !explicitOrder && eligible.every((chapter: ReaderChapterDescriptor): boolean =>
    chapter.volumeNumber !== undefined && chapter.volumeNumber.trim().length > 0 &&
    Number.isFinite(Number(chapter.volumeNumber)))
  const compare = (left: ReaderChapterDescriptor, right: ReaderChapterDescriptor): number => {
    if (explicitOrder) return (left.readingOrder as number) - (right.readingOrder as number)
    // Legacy grouped metadata uses (volume, chapter), not volume alone. All
    // chapters in volume 1 still need their 1/2/3 order before volume 2 begins.
    const volumeDifference = volumeOrder ? Number(left.volumeNumber) - Number(right.volumeNumber) : 0
    return volumeDifference || (left.chapterNumber ?? 0) - (right.chapterNumber ?? 0)
  }
  eligible.sort((left: ReaderChapterDescriptor, right: ReaderChapterDescriptor): number =>
    compare(left, right) || (left.id < right.id ? -1 : left.id > right.id ? 1 : 0))
  const sequence: string[] = []
  const seenVariantGroups = new Set<string>()
  const scanlator = current.scanlator?.trim()
  for (let start = 0; start < eligible.length;) {
    let end = start + 1
    while (end < eligible.length && compare(eligible[start], eligible[end]) === 0) end += 1
    const slot = eligible.slice(start, end)
    const first = slot[0]
    const variant = preferScanlator ? first.readingVariantGroup : undefined
    // Only source-declared alternatives at the same explicit ordinal are
    // interchangeable for next/previous. Keep all IDs in the manual catalog.
    if (variant !== undefined && seenVariantGroups.has(variant)) return [currentId]
    if (variant !== undefined) seenVariantGroups.add(variant)
    if (slot.length > 1 && (!preferScanlator || !explicitOrder || variant === undefined || variant.length === 0 ||
      !slot.every((chapter: ReaderChapterDescriptor): boolean => chapter.readingVariantGroup === variant))) return [currentId]
    const chosen = slot.find((chapter: ReaderChapterDescriptor): boolean => chapter.id === currentId) ??
      (versionSequence !== undefined ?
        slot.find((chapter: ReaderChapterDescriptor): boolean => chapter.readingGroup === group) :
        scanlator ? slot.find((chapter: ReaderChapterDescriptor): boolean => chapter.scanlator?.trim() === scanlator) : undefined) ?? first
    sequence.push(chosen.id)
    start = end
  }
  if (sort === undefined) return sequence
  // Apply the selected basis inside the already verified group. Preserve
  // source positions for ties and keep the chosen variant at every slot.
  const byId = new Map<string, ReaderChapterDescriptor>()
  eligible.forEach((chapter: ReaderChapterDescriptor): void => { byId.set(chapter.id, chapter) })
  const included = sequence.map((id: string): ReaderChapterDescriptor => byId.get(id)!)
  return included
    .sort((left: ReaderChapterDescriptor, right: ReaderChapterDescriptor): number => compareChapterSort(left, right, sort))
    .map((chapter: ReaderChapterDescriptor): string => chapter.id)
}
