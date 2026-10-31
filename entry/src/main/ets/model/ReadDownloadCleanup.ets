import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { ReadingProgress } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { chaptersToRemoveAfterReading } from './LibraryAutomationPolicy'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { writeAppTextFile } from './AppFileTextPersistence'

interface ReadCleanupCandidate { comicId: string; chapterId: string }

/** Record completion now; remove downloaded files only after Reader has closed and committed progress. */
export class ReadDownloadCleanup {
  private path: string
  private filesDir: string
  private pending?: ReadCleanupCandidate[]
  private inFlight?: Promise<void>
  private observations: Promise<void> = Promise.resolve()

  constructor(filesDir: string) {
    this.filesDir = filesDir
    this.path = `${filesDir}/read-download-cleanup.v1.json`
  }

  invalidateAfterRestore(): void { this.pending = undefined }

  private candidates(): ReadCleanupCandidate[] {
    if (this.pending === undefined) this.pending = fs.accessSync(this.path)
      ? JSON.parse(fs.readTextSync(this.path)) as ReadCleanupCandidate[] : []
    return this.pending
  }

  observe(context: common.UIAbilityContext, progress: ReadingProgress): Promise<void> {
    if (!progress.completed) return Promise.resolve()
    const run = this.observations.then(() => BackupRestoreActivity.runWrite(async (): Promise<void> => {
      if ((await new LibraryAutomationPreferencesStore(context).load()).removeAfterRead < 0) return
      const candidates = this.candidates()
      if (candidates.some((item: ReadCleanupCandidate): boolean =>
        item.comicId === progress.comicId && item.chapterId === progress.chapterId)) return
      const next = candidates.concat([{ comicId: progress.comicId, chapterId: progress.chapterId }])
      writeAppTextFile(this.path, JSON.stringify(next))
      this.pending = next
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
      const queue = new OfflineDownloadQueueStore(this.filesDir)
      for (const candidate of this.candidates().slice()) {
        const comic = library.getComic(candidate.comicId)
        const ids = comic === undefined ? [] : chaptersToRemoveAfterReading(comic, candidate.chapterId, reader, policy)
        let active = false
        for (const chapterId of ids) {
          if (OfflineDownloadRuntime.isActive(this.filesDir, candidate.comicId, chapterId)) { active = true; continue }
          await queue.deleteChapterDownload(candidate.comicId, chapterId)
        }
        if (active) continue
        const next = this.candidates().filter((item: ReadCleanupCandidate): boolean =>
          item.comicId !== candidate.comicId || item.chapterId !== candidate.chapterId)
        writeAppTextFile(this.path, JSON.stringify(next))
        this.pending = next
      }
    }).finally(() => { this.inFlight = undefined })
    this.inFlight = run
    return run
  }
}
