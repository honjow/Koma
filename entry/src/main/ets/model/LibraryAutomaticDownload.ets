import { common } from '@kit.AbilityKit'
import { Comic, Chapter } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
import { LibraryUpdateSummary } from './LibraryUpdateService'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { newlyAddedChapterIds, comicMatchesAutomationCategories } from './LibraryAutomationPolicy'
import { LibraryBatchDownloadQueue, LibraryBatchDownloadTarget } from './LibraryBatchDownloadQueue'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { AUTOMATIC_DOWNLOAD_WORK, GeneratedDownloadChapter, readGeneratedDownloadWork,
  saveGeneratedDownloadWork, removeGeneratedDownloadWork } from './GeneratedDownloadWork'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from './KomaContentStorage'

let draining: Promise<void> = Promise.resolve()

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
  const pending: GeneratedDownloadChapter[] = []
  for (const entry of summary.results) {
    if (entry.status !== 'updated') continue
    const comic = library.getComic(entry.comicId)
    if (comic === undefined || !comicMatchesAutomationCategories(comic,
      policy.downloadIncludedCategories, policy.downloadExcludedCategories)) continue
    const previous = previousChapterIds.get(comic.id)
    if (previous === undefined) continue // No received pre-update baseline means no proven new chapters.
    const ids = newlyAddedChapterIds(previous, comic)
    for (const chapterId of ids) {
      pending.push({ comicId: comic.id, chapterId })
    }
  }
  await BackupRestoreActivity.runWrite(() => saveGeneratedDownloadWork(context, AUTOMATIC_DOWNLOAD_WORK, pending))
  await drainPendingAutomaticChapters(context, library, reader)
}

export function drainPendingAutomaticChapters(context: common.UIAbilityContext,
  library: LibraryStore, reader: ReaderSessionStore): Promise<void> {
  const run = draining.then(() => BackupRestoreActivity.runWrite(async (): Promise<void> => {
    const policy = await new LibraryAutomationPreferencesStore(context).load()
    if (!policy.autoDownloadNewChapters) return
    const pending = await readGeneratedDownloadWork(context, AUTOMATIC_DOWNLOAD_WORK)
    if (pending.length === 0) return
    const storageBase = await ensureKomaContentStorageBase(context)
    const batch = new LibraryBatchDownloadQueue(storageBase, library, reader, komaRuntimeStorageKey(context))
    for (const comicId of Array.from(new Set<string>(pending.map((item: GeneratedDownloadChapter): string => item.comicId)))) {
      const comic = library.getComic(comicId)
      if (comic === undefined || !comicMatchesAutomationCategories(comic, policy.downloadIncludedCategories,
        policy.downloadExcludedCategories)) continue
      const ids = pending.filter((item: GeneratedDownloadChapter): boolean => item.comicId === comicId)
        .map((item: GeneratedDownloadChapter): string => item.chapterId)
      const targets = batch.prepare([comicId], policy.downloadUnreadOnly).targets
        .filter((target: LibraryBatchDownloadTarget): boolean => ids.includes(target.chapterId))
      await batch.enqueue(targets, policy.downloadUnreadOnly, true)
    }
    // Preserve newer additions recorded while queue initialization was awaiting its worker.
    await removeGeneratedDownloadWork(context, AUTOMATIC_DOWNLOAD_WORK, pending)
  }))
  draining = run.catch(() => {})
  return run
}
