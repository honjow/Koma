import { Chapter, Comic, ComicSourceKind, ReadingProgress, normalizeCategoryIds } from './ComicModels'

export interface MangaMigrationOptions {
  copy: boolean
  readProgress: boolean
  categories: boolean
}

export interface MangaMigrationReadState {
  comicId: string
  chapterId: string
  isRead: boolean
  bookmarked?: boolean
  updatedAt: number
}

export interface MangaMigrationReadPlan {
  states: MangaMigrationReadState[]
  progress?: ReadingProgress
  unmatchedReadCount: number
}

export function canMigrateLibraryComic(comic: Comic | undefined): boolean {
  return comic !== undefined && comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY &&
    (comic.sourceRuntimeId?.trim().length ?? 0) > 0 && (comic.remoteResourceId?.trim().length ?? 0) > 0
}

function recognizedNumber(value: number | undefined): boolean {
  return value !== undefined && Number.isFinite(value) && value >= 0
}

function volumeKey(value: string | undefined): string | undefined {
  const text = value?.trim()
  if (text === undefined || text.length === 0) return undefined
  const number = Number(text)
  return Number.isFinite(number) && number >= 0 ? `${number}` : text
}

/** Cross-source correspondence is independent of either catalog's display or reading ordinal.
 * Keep explicitly unread gaps. Unique chapter numbers tolerate missing volume metadata but never
 * conflicting volumes; repeated numbers require an exact volume. Unnumbered extras require a unique
 * full title. An ambiguous chapter remains in the original history instead of guessing an index.
 */
export function migrationChapterMatch(chapter: Chapter, source: Chapter[], target: Chapter[]): Chapter | undefined {
  if (recognizedNumber(chapter.chapterNumber)) {
    const matches = target.filter((row: Chapter): boolean => row.chapterNumber === chapter.chapterNumber)
    const originals = source.filter((row: Chapter): boolean => row.chapterNumber === chapter.chapterNumber)
    if (matches.length === 1 && originals.length === 1) {
      const oldVolume = volumeKey(chapter.volumeNumber), newVolume = volumeKey(matches[0].volumeNumber)
      return oldVolume !== undefined && newVolume !== undefined && oldVolume !== newVolume ? undefined : matches[0]
    }
    if ((chapter.volumeNumber?.trim().length ?? 0) > 0) {
      const sameVolume = matches.filter((row: Chapter): boolean => volumeKey(row.volumeNumber) === volumeKey(chapter.volumeNumber))
      const sourceVolume = originals.filter((row: Chapter): boolean => volumeKey(row.volumeNumber) === volumeKey(chapter.volumeNumber))
      if (sameVolume.length === 1 && sourceVolume.length === 1) return sameVolume[0]
    }
    return undefined
  }
  const title = chapter.title.trim()
  if (title.length === 0) return undefined
  const sameTitle = (row: Chapter): boolean => !recognizedNumber(row.chapterNumber) &&
    row.title.trim() === title && volumeKey(row.volumeNumber) === volumeKey(chapter.volumeNumber)
  const matches = target.filter(sameTitle)
  return matches.length === 1 && source.filter(sameTitle).length === 1 ? matches[0] : undefined
}

export function planMangaMigrationReadState(
  source: Comic, target: Comic, states: MangaMigrationReadState[],
  sourceProgress?: ReadingProgress, targetProgress?: ReadingProgress,
): MangaMigrationReadPlan {
  const plan: MangaMigrationReadPlan = { states: [], unmatchedReadCount: 0 }
  const readStates = states.filter((state: MangaMigrationReadState): boolean =>
    state.comicId === source.id && (state.isRead || state.bookmarked === true))
  if (sourceProgress?.comicId === source.id && sourceProgress.completed &&
    !readStates.some((state: MangaMigrationReadState): boolean => state.chapterId === sourceProgress.chapterId)) {
    readStates.push({ comicId: source.id, chapterId: sourceProgress.chapterId, isRead: true, updatedAt: sourceProgress.updatedAt })
  }
  const assigned = new Set<string>()
  readStates.forEach((state: MangaMigrationReadState): void => {
    const old = source.chapters.find((row: Chapter): boolean => row.id === state.chapterId)
    const match = old === undefined ? undefined : migrationChapterMatch(old, source.chapters, target.chapters)
    if (match === undefined) { if (state.isRead) plan.unmatchedReadCount += 1; return }
    if (!plan.states.some((row: MangaMigrationReadState): boolean => row.chapterId === match.id)) {
      if (state.isRead) assigned.add(match.id)
      plan.states.push({ comicId: target.id, chapterId: match.id, isRead: state.isRead,
        bookmarked: state.bookmarked, updatedAt: state.updatedAt })
    }
  })
  if (targetProgress === undefined && sourceProgress?.comicId === source.id) {
    const old = source.chapters.find((row: Chapter): boolean => row.id === sourceProgress.chapterId)
    const match = old === undefined ? undefined : migrationChapterMatch(old, source.chapters, target.chapters)
    if (match !== undefined) {
      // Another edition has different images/page boundaries: resume the corresponding chapter,
      // never reuse the old page ID, page index, image URI or double-page pairing.
      plan.progress = { comicId: target.id, chapterId: match.id, pageIndex: 0, totalPages: 0,
        progressRatio: 0, completed: assigned.has(match.id), updatedAt: sourceProgress.updatedAt }
    }
  }
  return plan
}

export function migrationCategoryIds(source: Comic, target: Comic, include: boolean): string[] {
  return normalizeCategoryIds(include ? (target.categoryIds ?? []).concat(source.categoryIds ?? []) : target.categoryIds)
}
