import { common } from '@kit.AbilityKit'
import { AppStorageV2 } from '@kit.ArkUI'
import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from '../model/KomaContentStorage'
import { convertDownloadedChaptersToCbz, DownloadCbzConversionResult, DownloadCbzMigrationOptions,
  listFlatCbzMigrationWork } from '../model/OfflineDownloadCbz'
import { createOfflineDownloadStableHash, OfflineDownloadStore } from '../model/OfflineDownloadStore'
import { loadDownloadSaveAsCbz } from '../model/DownloadFormatPreferences'
import { writeAppTextFile } from '../model/AppFileTextPersistence'

interface DownloadCbzJob {
  context: common.UIAbilityContext
  comicId: string
  title: string
  chapterIds: string[]
  migration?: DownloadCbzMigrationOptions
  onFinished?: (success: boolean) => void
}

export interface DownloadCbzQueueStatus {
  running: boolean
  comicId: string
  title: string
  processed: number
  total: number
  waiting: number
  converted: number
  failed: number
  insufficientSpace: number
  migrating: boolean
}

/** One writer for manual conversions. The queue belongs to the app process, so
 * leaving Download Management does not cancel accepted work. */
@ObservedV2
export class DownloadCbzConversionQueue {
  @Trace status?: DownloadCbzQueueStatus = undefined
  private readonly waiting: DownloadCbzJob[] = []
  private readonly reserved: Set<string> = new Set<string>()
  private active?: DownloadCbzJob = undefined
  private processed: number = 0
  private converted: number = 0
  private failed: number = 0
  private insufficientSpace: number = 0
  private checkedRoots: Set<string> = new Set<string>()

  private chapterKey(context: common.UIAbilityContext, comicId: string, chapterId: string): string {
    return JSON.stringify([komaRuntimeStorageKey(context), comicId, chapterId])
  }

  isScheduled(context: common.UIAbilityContext, comicId: string, chapterId: string): boolean {
    return this.reserved.has(this.chapterKey(context, comicId, chapterId))
  }

  isConverting(comicId: string, chapterId?: string): boolean {
    return this.active?.comicId === comicId &&
      (chapterId === undefined || this.active.chapterIds[this.processed] === chapterId)
  }

  enqueue(context: common.UIAbilityContext, comicId: string, title: string, chapterIds: string[],
    migration?: DownloadCbzMigrationOptions, onFinished?: (success: boolean) => void): number {
    const fresh: string[] = []
    for (const chapterId of chapterIds) {
      const key = this.chapterKey(context, comicId, chapterId)
      if (this.reserved.has(key)) continue
      this.reserved.add(key)
      fresh.push(chapterId)
    }
    if (fresh.length === 0) return 0
    this.waiting.push({ context, comicId, title, chapterIds: fresh, migration, onFinished })
    if (this.active === undefined) {
      this.converted = 0
      this.failed = 0
      this.insufficientSpace = 0
      void this.drain()
    } else {
      this.publish()
    }
    return fresh.length
  }

  dismissResult(): void {
    if (this.active === undefined) this.status = undefined
  }

  async startUpgradeMigration(context: common.UIAbilityContext, canRemoveOriginals: () => boolean): Promise<void> {
    try {
      const root = await ensureKomaContentStorageBase(context)
      const key = JSON.stringify([context.filesDir, root])
      if (this.checkedRoots.has(key)) return
      this.checkedRoots.add(key)
      const convertLoose = await loadDownloadSaveAsCbz(context)
      const marker = context.filesDir + '/.koma-cbz-flat-v1-' + createOfflineDownloadStableHash(root)
      if (fs.accessSync(marker)) {
        const finished = fs.readTextSync(marker, { encoding: 'utf-8' })
        if (finished === 'all' || (!convertLoose && finished === 'packed')) return
      }
      const jobs = await listFlatCbzMigrationWork(root, komaRuntimeStorageKey(context), convertLoose)
      const options: DownloadCbzMigrationOptions = { convertLoose, canRemoveOriginals }
      let remaining = jobs.length
      let complete = true
      const record = (): void => {
        try {
          writeAppTextFile(marker, convertLoose ? 'all' : 'packed')
        } catch (error) {
          DiagnosticLogger.exception('downloads', 'download_cbz_migration_marker_failed', error as Error)
        }
      }
      const finished = (success: boolean): void => {
        complete = complete && success
        remaining -= 1
        if (remaining === 0 && complete) record()
      }
      if (remaining === 0) record()
      for (const job of jobs) {
        const accepted = this.enqueue(context, job.comicId, job.title, job.chapterIds, options, finished)
        if (accepted !== job.chapterIds.length) complete = false
        if (accepted === 0) finished(false)
      }
    } catch (error) {
      DiagnosticLogger.exception('downloads', 'download_cbz_migration_start_failed', error as Error)
    }
  }

  private publish(): void {
    this.status = {
      running: this.active !== undefined,
      comicId: this.active?.comicId ?? '',
      title: this.active?.title ?? '',
      processed: this.processed,
      total: this.active?.chapterIds.length ?? 0,
      waiting: this.waiting.reduce((count: number, job: DownloadCbzJob): number => count + job.chapterIds.length, 0),
      converted: this.converted,
      failed: this.failed,
      insufficientSpace: this.insufficientSpace,
      migrating: this.active?.migration !== undefined,
    }
  }

  private async drain(): Promise<void> {
    while (this.waiting.length > 0) {
      const job = this.waiting.shift()!
      this.active = job
      this.processed = 0
      this.publish()
      let success = false
      try {
        const storage = await ensureKomaContentStorageBase(job.context)
        const store = new OfflineDownloadStore(storage, komaRuntimeStorageKey(job.context))
        const previousSpaceFailures = this.insufficientSpace
        const result = await convertDownloadedChaptersToCbz(store, job.comicId, job.chapterIds,
          (processed: number, progress: DownloadCbzConversionResult): void => {
            this.processed = processed
            this.insufficientSpace = previousSpaceFailures + progress.insufficientSpace
            this.publish()
          }, job.migration)
        this.converted += result.converted
        this.failed += result.failed
        success = result.failed === 0
      } catch (error) {
        DiagnosticLogger.exception('downloads', 'download_conversion_job_failed', error as Error)
        this.failed += job.chapterIds.length
      } finally {
        for (const chapterId of job.chapterIds) this.reserved.delete(this.chapterKey(job.context, job.comicId, chapterId))
        job.onFinished?.(success)
      }
    }
    this.active = undefined
    this.publish()
  }
}

export function connectDownloadCbzConversionQueue(): DownloadCbzConversionQueue {
  return AppStorageV2.connect(DownloadCbzConversionQueue, 'koma:downloadCbzConversionQueue',
    () => new DownloadCbzConversionQueue())!
}
