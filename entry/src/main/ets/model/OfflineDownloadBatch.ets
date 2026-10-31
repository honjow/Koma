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
export async function runOfflineDownloadBatch(
  request: OfflineDownloadBatchRequest, targets: OfflineDownloadQueueEntry[],
): Promise<number> {
  const queue = new OfflineDownloadQueueStore(request.context.filesDir)
  if (targets.length === 0 || !canRunOfflineDownloadQueueNow(queue.loadPreferences())) return 0
  return BackgroundDownloadOwner.run(request.context, () => executeBatch(request, targets))
}

async function executeBatch(request: OfflineDownloadBatchRequest, targets: OfflineDownloadQueueEntry[]): Promise<number> {
  const queue = new OfflineDownloadQueueStore(request.context.filesDir)
  await OfflineDownloadService.ensureQueueInitialized(request.context.filesDir)
  const service = new OfflineDownloadService(new OfflineDownloadStore(request.context.filesDir), queue, request.context)
  let completed = 0
  await runOrderedDownloadQueueBatch(queue, targets, async (entry: OfflineDownloadQueueEntry): Promise<void> => {
      if (!recoverableDownloadEntry(entry)) return
      const comic = request.library.getComic(entry.comicId)
      if (comic === undefined) {
        queue.upsert({ comicId: entry.comicId, chapterId: entry.chapterId, comicTitle: entry.comicTitle,
          chapterTitle: entry.chapterTitle, status: OfflineDownloadStatus.BLOCKED,
          pageCount: entry.pageCount, downloadedPageCount: entry.downloadedPageCount,
          failureReasonCode: 'comic_missing', updatedAt: Date.now() })
        return
      }
      const hydration: SourceChapterPageHydrationResult = comic.sourceRuntimeId === undefined || comic.sourceRuntimeId.trim().length === 0
        ? { hydrated: true, pageCount: 0 } :
        await new SourceChapterPageHydrator(request.library, request.registry, request.persistence,
          request.onLibraryChanged).ensureChapterPages(comic.id, comic.sourceRuntimeId, entry.chapterId)
      const current = request.library.getComic(entry.comicId)
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
      await service.downloadChapter(current, entry.chapterId,
        { comicTitle: entry.comicTitle ?? current.title, chapterTitle: entry.chapterTitle })
      completed += 1
  }, () => canRunOfflineDownloadQueueNow(queue.loadPreferences()))
  return completed
}

const automaticBatches: Map<string, Promise<void>> = new Map()

export function resumeAutomaticDownloads(request: OfflineDownloadBatchRequest): Promise<void> {
  const filesDir = request.context.filesDir
  const active = automaticBatches.get(filesDir)
  if (active !== undefined) return active
  const pending = Promise.resolve().then(async (): Promise<void> => {
    const queue = new OfflineDownloadQueueStore(filesDir)
    while (canRunOfflineDownloadQueueNow(queue.loadPreferences())) {
      // Explicitly queued manual work keeps its existing start/resume action.
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
