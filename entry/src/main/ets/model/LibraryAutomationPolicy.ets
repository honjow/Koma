import { Chapter, Comic } from './ComicModels'
import { ReaderSessionStore } from './ReaderSessionStore'
import { continuationChapterIds } from './ReaderChapterSequence'

export interface LibraryAutomationPreferences {
  updateWifiOnly: boolean
  updateChargingOnly: boolean
  updateIncludedCategories: string[]
  updateExcludedCategories: string[]
  skipCompleted: boolean
  skipNotStarted: boolean
  skipHasUnread: boolean
  autoDownloadNewChapters: boolean
  downloadUnreadOnly: boolean
  downloadIncludedCategories: string[]
  downloadExcludedCategories: string[]
  removeAfterRead: number
  cleanupExcludedCategories: string[]
}

export function defaultLibraryAutomationPreferences(): LibraryAutomationPreferences {
  // New automatic actions are opt-in. Existing manual updates and downloads keep their scope.
  return {
    updateWifiOnly: false, updateChargingOnly: false,
    updateIncludedCategories: [], updateExcludedCategories: [],
    skipCompleted: false, skipNotStarted: false, skipHasUnread: false,
    autoDownloadNewChapters: false, downloadUnreadOnly: true,
    downloadIncludedCategories: [], downloadExcludedCategories: [],
    removeAfterRead: -1, cleanupExcludedCategories: [],
  }
}

export function comicMatchesAutomationCategories(comic: Comic, included: string[], excluded: string[]): boolean {
  const categories = comic.categoryIds?.length ? comic.categoryIds : ['uncategorized']
  // A comic in both an included and excluded category is excluded, as in Mihon.
  return !categories.some((id: string): boolean => excluded.includes(id)) &&
    (included.length === 0 || categories.some((id: string): boolean => included.includes(id)))
}

export function shouldAutomaticallyUpdateComic(
  comic: Comic, reader: ReaderSessionStore, policy: LibraryAutomationPreferences,
): boolean {
  if (!comicMatchesAutomationCategories(comic, policy.updateIncludedCategories, policy.updateExcludedCategories)) return false
  if (policy.skipCompleted && (comic.sourceMetadata?.status ?? comic.localMetadata?.status) === 'completed') return false
  const started = reader.getProgress(comic.id) !== undefined || comic.chapters.some((chapter: Chapter): boolean =>
    reader.isChapterRead(comic.id, chapter.id) || reader.getChapterProgress(comic.id, chapter.id) !== undefined)
  if (policy.skipNotStarted && !started) return false
  return !(policy.skipHasUnread && comic.chapters.some((chapter: Chapter): boolean =>
    !reader.isChapterRead(comic.id, chapter.id)))
}

export function newlyAddedChapterIds(previousIds: Set<string>, comic: Comic): string[] {
  return Array.from(new Set<string>(comic.chapters.filter((chapter: Chapter): boolean =>
    !previousIds.has(chapter.id)).map((chapter: Chapter): string => chapter.id)))
}

export function chaptersToRemoveAfterReading(
  comic: Comic, currentId: string, reader: ReaderSessionStore, policy: LibraryAutomationPreferences,
): string[] {
  if (policy.removeAfterRead < 0 || !reader.isChapterRead(comic.id, currentId) ||
    !comicMatchesAutomationCategories(comic, [], policy.cleanupExcludedCategories)) return []
  if (policy.removeAfterRead === 0) return [currentId]
  // Keep counts use the same absolute edition/chronology as Reader; never the displayed list order.
  const sequence = continuationChapterIds(comic.chapters, currentId)
  if (sequence === undefined) return []
  const position = sequence.indexOf(currentId)
  if (position < 0) return []
  return sequence.slice(0, Math.max(0, position + 1 - policy.removeAfterRead))
    .filter((id: string): boolean => reader.isChapterRead(comic.id, id))
}
