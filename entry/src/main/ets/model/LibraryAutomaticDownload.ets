import { common } from '@kit.AbilityKit'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
import type { LibraryChapterUpdate } from './LibraryChapterUpdates'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { comicMatchesAutomationCategories } from './LibraryAutomationPolicy'
import { LibraryBatchDownloadQueue, LibraryBatchDownloadTarget } from './LibraryBatchDownloadQueue'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { AUTOMATIC_DOWNLOAD_WORK, GeneratedDownloadChapter, readGeneratedDownloadWork,
  saveGeneratedDownloadWork, removeGeneratedDownloadWork } from './GeneratedDownloadWork'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from './KomaContentStorage'

let draining: Promise<void> = Promise.resolve()

export async function enqueueAutomaticallyAddedChapters(context: common.UIAbilityContext,
  library: LibraryStore, reader: ReaderSessionStore, updates: LibraryChapterUpdate[]): Promise<void> {
  const policy = await new LibraryAutomationPreferencesStore(context).load()
  if (!policy.autoDownloadNewChapters) return
  const pending: GeneratedDownloadChapter[] = []
  for (const entry of updates) {
    const comic = library.getComic(entry.comicId)
    if (comic === undefined || !comicMatchesAutomationCategories(comic,
      policy.downloadIncludedCategories, policy.downloadExcludedCategories)) continue
    pending.push({ comicId: comic.id, chapterId: entry.chapterId })
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
