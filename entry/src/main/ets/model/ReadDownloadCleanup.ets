import { common } from '@kit.AbilityKit'
import { ReadingProgress } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { chaptersToRemoveAfterReading } from './LibraryAutomationPolicy'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { AFTER_READING_WORK, readGeneratedDownloadWork, saveGeneratedDownloadWork, removeGeneratedDownloadWork } from './GeneratedDownloadWork'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from './KomaContentStorage'

/** Record completion now; remove downloaded files only after Reader has closed and committed progress. */
export class ReadDownloadCleanup {
  private inFlight?: Promise<void>
  private observations: Promise<void> = Promise.resolve()

  observe(context: common.UIAbilityContext, progress: ReadingProgress): Promise<void> {
    if (!progress.completed) return Promise.resolve()
    const run = this.observations.then(() => BackupRestoreActivity.runWrite(async (): Promise<void> => {
      if ((await new LibraryAutomationPreferencesStore(context).load()).removeAfterRead < 0) return
      await saveGeneratedDownloadWork(context, AFTER_READING_WORK, [{ comicId: progress.comicId, chapterId: progress.chapterId }])
    }))
    this.observations = run.catch(() => {})
    return run
  }

  run(context: common.UIAbilityContext,
    library: LibraryStore, reader: ReaderSessionStore): Promise<void> {
    if (this.inFlight !== undefined) return this.inFlight
    const run = BackupRestoreActivity.runWrite(async (): Promise<void> => {
      await this.observations
      const policy = await new LibraryAutomationPreferencesStore(context).load()
      const storageBase = await ensureKomaContentStorageBase(context)
      const runtimeKey = komaRuntimeStorageKey(context)
      const queue = new OfflineDownloadQueueStore(storageBase, runtimeKey)
      for (const candidate of await readGeneratedDownloadWork(context, AFTER_READING_WORK)) {
        const comic = library.getComic(candidate.comicId)
        const ids = comic === undefined ? [] : chaptersToRemoveAfterReading(comic, candidate.chapterId, reader, policy)
        let active = false
        for (const chapterId of ids) {
          if (OfflineDownloadRuntime.isActive(runtimeKey, candidate.comicId, chapterId)) { active = true; continue }
          await queue.deleteChapterDownload(candidate.comicId, chapterId)
        }
        if (active) continue
        await removeGeneratedDownloadWork(context, AFTER_READING_WORK, [candidate])
      }
    }).finally(() => { this.inFlight = undefined })
    this.inFlight = run
    return run
  }
}
