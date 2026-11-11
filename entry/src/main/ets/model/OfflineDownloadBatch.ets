import { common } from '@kit.AbilityKit'
import { sameComicIdentity } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { LibraryStorePersistenceService } from './LibraryPersistence'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceChapterPageHydrator, SourceChapterPageHydrationResult } from './SourceChapterPageHydrator'
import { OfflineDownloadQueueEntry, OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { canRunOfflineDownloadQueueNow, OfflineDownloadService } from './OfflineDownloadService'
import { OfflineDownloadStatus, OfflineDownloadStore } from './OfflineDownloadStore'
import { BackgroundDownloadOwner } from './BackgroundDownloadOwner'
import { runOrderedDownloadQueueBatch } from './OfflineDownloadQueueExecution'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from './KomaContentStorage'

export interface OfflineDownloadBatchRequest {
  context: common.UIAbilityContext
  library: LibraryStore
  registry: SourceRuntimeRegistry
  persistence?: LibraryStorePersistenceService
  onLibraryChanged?: () => void
}

export function recoverableDownloadEntry(entry: OfflineDownloadQueueEntry): boolean {
  return entry.status !== OfflineDownloadStatus.BLOCKED ||
    ['pages_missing', 'source_pages_failed', 'source_lookup_failed', 'source_not_installed', 'source_disabled', 'wifi_only', 'paused', 'download_interrupted']
      .includes(entry.failureReasonCode ?? '')
}

/** Page actions and automatic updates execute through the same hydrator, identity check and runtime slots. */
async function runOfflineDownloadBatch(
  request: OfflineDownloadBatchRequest, targets: OfflineDownloadQueueEntry[],
): Promise<number> {
  const storageBase = await ensureKomaContentStorageBase(request.context)
  const runtimeKey = komaRuntimeStorageKey(request.context)
  const queue = new OfflineDownloadQueueStore(storageBase, runtimeKey)
  if (targets.length === 0 || !canRunOfflineDownloadQueueNow(queue.loadPreferences())) return 0
  return BackgroundDownloadOwner.run(request.context, () => executeBatch(request, targets, storageBase, runtimeKey))
}

async function executeBatch(request: OfflineDownloadBatchRequest, targets: OfflineDownloadQueueEntry[],
  storageBase: string, runtimeKey: string): Promise<number> {
  const queue = new OfflineDownloadQueueStore(storageBase, runtimeKey)
  await OfflineDownloadService.ensureQueueInitialized(storageBase, runtimeKey)
  const service = new OfflineDownloadService(new OfflineDownloadStore(storageBase, runtimeKey), queue, request.context)
  let completed = 0
  await runOrderedDownloadQueueBatch(queue, targets, async (entry: OfflineDownloadQueueEntry): Promise<void> => {
      const isPending = (): boolean => !OfflineDownloadRuntime.isRemovingChapter(runtimeKey,
        entry.comicId, entry.chapterId) && queue.load().some((current: OfflineDownloadQueueEntry): boolean =>
          current.comicId === entry.comicId && current.chapterId === entry.chapterId &&
          current.status !== OfflineDownloadStatus.DOWNLOADED)
      if (!recoverableDownloadEntry(entry) || !isPending()) return
      const comic = request.library.getComic(entry.comicId)
      if (comic === undefined) {
        queue.upsert({ comicId: entry.comicId, chapterId: entry.chapterId, comicTitle: entry.comicTitle,
          chapterTitle: entry.chapterTitle, status: OfflineDownloadStatus.BLOCKED,
          pageCount: entry.pageCount, downloadedPageCount: entry.downloadedPageCount,
          failureReasonCode: 'comic_missing', updatedAt: Date.now() })
        return
      }
      let hydration: SourceChapterPageHydrationResult = { hydrated: true, pageCount: 0 }
      try {
        if (comic.sourceRuntimeId) {
          hydration = await new SourceChapterPageHydrator(request.library, request.registry, request.persistence,
            request.onLibraryChanged).ensureChapterPages(comic.id, comic.sourceRuntimeId, entry.chapterId)
        }
      } catch (error) {
        DiagnosticLogger.exception('downloads', 'chapter_hydration_failed', error as Error)
        hydration = { hydrated: false, pageCount: 0, reasonCode: 'source_pages_failed' }
      }
      const current = request.library.getComic(entry.comicId)
      if (!isPending()) return
      if (current === undefined) {
        entry.status = OfflineDownloadStatus.BLOCKED
        entry.failureReasonCode = 'comic_missing'
        queue.upsert(entry)
        return
      }
      if (!sameComicIdentity(comic, current)) return
      if (!hydration.hydrated) {
        await service.blockChapterDownload(current, entry.chapterId, hydration.reasonCode ?? 'pages_missing',
          { comicTitle: entry.comicTitle ?? current.title, chapterTitle: entry.chapterTitle })
        return
      }
      try {
        const result = await service.downloadChapter(current, entry.chapterId,
          { comicTitle: entry.comicTitle ?? current.title, chapterTitle: entry.chapterTitle }, isPending)
        if (result.status === OfflineDownloadStatus.DOWNLOADED) completed += 1
      } catch (error) {
        if (!isPending()) return
        DiagnosticLogger.exception('downloads', 'chapter_execution_failed', error as Error)
        entry.status = OfflineDownloadStatus.FAILED
        entry.failureReasonCode = undefined
        queue.upsert(entry)
      }
  }, () => canRunOfflineDownloadQueueNow(queue.loadPreferences()))
  return completed
}

const automaticBatches: Map<string, Promise<void>> = new Map()

export function resumeAutomaticDownloads(request: OfflineDownloadBatchRequest): Promise<void> {
  const filesDir = request.context.filesDir
  const active = automaticBatches.get(filesDir)
  if (active !== undefined) return active
  const pending = Promise.resolve().then(async (): Promise<void> => {
    const storageBase = await ensureKomaContentStorageBase(request.context)
    const runtimeKey = komaRuntimeStorageKey(request.context)
    const queue = new OfflineDownloadQueueStore(storageBase, runtimeKey)
    while (canRunOfflineDownloadQueueNow(queue.loadPreferences())) {
      // New requests resume when eligible. Previously staged records stay staged.
      const targets = queue.load().filter((entry: OfflineDownloadQueueEntry): boolean =>
        entry.automatic === true && (entry.status === OfflineDownloadStatus.QUEUED ||
          ['wifi_only', 'paused', 'download_interrupted'].includes(entry.failureReasonCode ?? '')))
      if (targets.length === 0) return
      if (await runOfflineDownloadBatch(request, targets) === 0) return
    }
  }).finally(() => { automaticBatches.delete(filesDir) })
  automaticBatches.set(filesDir, pending)
  return pending
}
