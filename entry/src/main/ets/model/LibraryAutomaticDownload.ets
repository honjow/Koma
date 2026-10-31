import { common } from '@kit.AbilityKit'
import { Comic, Chapter } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
import { LibraryUpdateSummary } from './LibraryUpdateService'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { newlyAddedChapterIds, comicMatchesAutomationCategories } from './LibraryAutomationPolicy'
import { LibraryBatchDownloadQueue, LibraryBatchDownloadTarget } from './LibraryBatchDownloadQueue'
import { fileIo as fs } from '@kit.CoreFileKit'
import { writeAppTextFile } from './AppFileTextPersistence'

interface PendingAutomaticChapter { comicId: string; chapterId: string }
let draining: Promise<void> = Promise.resolve()

function pendingPath(context: common.Context): string { return `${context.filesDir}/automatic-download-pending.v1.json` }
function loadPending(context: common.Context): PendingAutomaticChapter[] {
  const path = pendingPath(context)
  return fs.accessSync(path) ? JSON.parse(fs.readTextSync(path)) as PendingAutomaticChapter[] : []
}

export function libraryChapterIdSnapshot(library: LibraryStore): Map<string, Set<string>> {
  const snapshot: Map<string, Set<string>> = new Map()
  library.listComics().forEach((comic: Comic): void => {
    snapshot.set(comic.id, new Set<string>(comic.chapters.map((chapter: Chapter): string => chapter.id)))
  })
  return snapshot
}

export async function enqueueAutomaticallyAddedChapters(context: common.UIAbilityContext,
  library: LibraryStore, reader: ReaderSessionStore, summary: LibraryUpdateSummary,
  previousChapterIds: Map<string, Set<string>>): Promise<void> {
  const policy = await new LibraryAutomationPreferencesStore(context).load()
  if (!policy.autoDownloadNewChapters) return
  const pending = loadPending(context)
  for (const entry of summary.results) {
    if (entry.status !== 'updated') continue
    const comic = library.getComic(entry.comicId)
    if (comic === undefined || !comicMatchesAutomationCategories(comic,
      policy.downloadIncludedCategories, policy.downloadExcludedCategories)) continue
    const previous = previousChapterIds.get(comic.id)
    if (previous === undefined) continue // No received pre-update baseline means no proven new chapters.
    const ids = newlyAddedChapterIds(previous, comic)
    for (const chapterId of ids) {
      if (!pending.some((item: PendingAutomaticChapter): boolean => item.comicId === comic.id && item.chapterId === chapterId)) {
        pending.push({ comicId: comic.id, chapterId })
      }
    }
  }
  if (pending.length > 0) writeAppTextFile(pendingPath(context), JSON.stringify(pending))
  await drainPendingAutomaticChapters(context, library, reader)
}

export function drainPendingAutomaticChapters(context: common.UIAbilityContext,
  library: LibraryStore, reader: ReaderSessionStore): Promise<void> {
  const run = draining.then(async (): Promise<void> => {
    const policy = await new LibraryAutomationPreferencesStore(context).load()
    if (!policy.autoDownloadNewChapters) return
    const pending = loadPending(context)
    if (pending.length === 0) return
    const batch = new LibraryBatchDownloadQueue(context.filesDir, library, reader)
    for (const comicId of Array.from(new Set<string>(pending.map((item: PendingAutomaticChapter): string => item.comicId)))) {
      const comic = library.getComic(comicId)
      if (comic === undefined || !comicMatchesAutomationCategories(comic, policy.downloadIncludedCategories,
        policy.downloadExcludedCategories)) continue
      const ids = pending.filter((item: PendingAutomaticChapter): boolean => item.comicId === comicId)
        .map((item: PendingAutomaticChapter): string => item.chapterId)
      const targets = batch.prepare([comicId], policy.downloadUnreadOnly).targets
        .filter((target: LibraryBatchDownloadTarget): boolean => ids.includes(target.chapterId))
      await batch.enqueue(targets, policy.downloadUnreadOnly, true)
    }
    // Preserve newer additions recorded while queue initialization was awaiting its worker.
    const next = loadPending(context).filter((item: PendingAutomaticChapter): boolean => !pending.some(
      (completed: PendingAutomaticChapter): boolean => completed.comicId === item.comicId && completed.chapterId === item.chapterId))
    writeAppTextFile(pendingPath(context), JSON.stringify(next))
  })
  draining = run.catch(() => {})
  return run
}
