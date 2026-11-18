import { common } from '@kit.AbilityKit'
import { Chapter, Comic, Page, sameComicIdentity } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { resolveDownloadChapterPages, resolveSourceChapterPages, SourceChapterPageHydrationResult } from './SourceChapterPageHydrator'
import { hasOfflineDownloadSourceIdentity, OfflineDownloadQueueEntry, OfflineDownloadQueueStore,
  isOfflineDownloadTaskPending } from './OfflineDownloadQueueStore'
import { comicFromSourceManga } from './SourceLibraryComic'
import { fetchSourceMangaDetail } from './SourceMangaDetailRequest'
import { sourceMangaDetailSnapshotCache } from './SourceMangaDetailSnapshotCache'
import { appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { sourceSettingsFingerprint } from '../sourceRuntime/SourceSettingsIdentity'
import { canRunOfflineDownloadQueueNow, OfflineDownloadService, publicSourceWorkUri } from './OfflineDownloadService'
import { OfflineDownloadStatus, OfflineDownloadStore } from './OfflineDownloadStore'
import { BackgroundDownloadOwner } from './BackgroundDownloadOwner'
import { publishOfflineDownloadSummary } from './OfflineDownloadNotificationStore'
import { runOrderedDownloadQueueBatch } from './OfflineDownloadQueueExecution'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from './KomaContentStorage'

export interface OfflineDownloadBatchRequest {
  context: common.UIAbilityContext
  library: LibraryStore
  registry: SourceRuntimeRegistry
}

export function recoverableDownloadEntry(entry: OfflineDownloadQueueEntry): boolean {
  return entry.status !== OfflineDownloadStatus.BLOCKED ||
    ['pages_missing', 'source_pages_failed', 'source_lookup_failed', 'source_not_installed', 'source_disabled', 'wifi_only', 'offline', 'paused', 'download_interrupted']
      .includes(entry.failureReasonCode ?? '')
}

/** Queue metadata can reconstruct a source request after a cold start, without
 * creating a shelf item or persisting resolved page URLs in the queue. */
function standaloneDownloadComic(entry: OfflineDownloadQueueEntry): Comic | undefined {
  if (!hasOfflineDownloadSourceIdentity(entry)) return undefined
  return comicFromSourceManga({ id: entry.sourceMangaId!, sourceId: entry.sourceId, title: entry.comicTitle ?? '',
    sourceName: entry.sourceName, url: publicSourceWorkUri(entry.sourceId, entry.sourceMangaUrl),
    chapterCount: 1, isInLibrary: false },
    [{ id: entry.chapterId, title: entry.chapterTitle ?? '', pageCount: entry.pageCount,
      isRead: false, isDownloaded: false }], entry.comicId)
}

async function standaloneWorkUrl(registry: SourceRuntimeRegistry, entry: OfflineDownloadQueueEntry): Promise<string | undefined> {
  const saved = publicSourceWorkUri(entry.sourceId, entry.sourceMangaUrl)
  if (saved !== undefined || entry.sourceId === undefined || entry.sourceMangaId === undefined) return saved
  const source = registry.lookup(entry.sourceId).entry
  if (source === undefined || !source.enabled) return undefined
  const settings = appSourceSettingsStore.loadForSource(entry.sourceId)
  const cached = sourceMangaDetailSnapshotCache.read(source, entry.sourceId, entry.sourceMangaId,
    undefined, sourceSettingsFingerprint(settings))
  if (cached?.detail.url) return cached.detail.url
  // Keep source-supplied routes in memory only. Some providers need their
  // canonical work URL in get_pages or get_image_request even with a chapter ID.
  try {
    const response = await fetchSourceMangaDetail(source, entry.sourceMangaId, undefined, settings, 'download')
    return response.detail.url
  } catch (_error) {
    return undefined
  }
}

/** Page actions and automatic updates execute through the same hydrator, identity check and runtime slots. */
async function runOfflineDownloadBatch(
  request: OfflineDownloadBatchRequest, targets: OfflineDownloadQueueEntry[],
): Promise<number> {
  const storageBase = await ensureKomaContentStorageBase(request.context)
  const runtimeKey = komaRuntimeStorageKey(request.context)
  const queue = new OfflineDownloadQueueStore(storageBase, runtimeKey)
  if (targets.length === 0 || !canRunOfflineDownloadQueueNow(queue.loadPreferences())) return 0
  return executeBatch(request, targets, storageBase, runtimeKey)
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
          current.requestId === entry.requestId && !current.pausedByUser && isOfflineDownloadTaskPending(current))
      if (!recoverableDownloadEntry(entry) || !isPending()) return
      const shelved = request.library.getComic(entry.comicId)
      const standalone = shelved?.chapters.some((chapter: Chapter): boolean => chapter.id === entry.chapterId) !== true
        ? standaloneDownloadComic(entry) : undefined
      const comic = standalone ?? shelved
      if (comic === undefined) {
        queue.upsert({ comicId: entry.comicId, chapterId: entry.chapterId, comicTitle: entry.comicTitle,
          chapterTitle: entry.chapterTitle, status: OfflineDownloadStatus.BLOCKED,
          pageCount: entry.pageCount, downloadedPageCount: entry.downloadedPageCount,
          failureReasonCode: 'comic_missing', updatedAt: Date.now() })
        return
      }
      let preparedPages: Page[] | undefined
      let hydration: SourceChapterPageHydrationResult = { hydrated: true, pageCount: 0 }
      try {
        if (standalone !== undefined) {
          const mangaUrl = await standaloneWorkUrl(request.registry, entry)
          if (!isPending()) return
          if (mangaUrl !== undefined) standalone.sourcePath = mangaUrl
          const resolved = await resolveSourceChapterPages(request.registry, { comicId: standalone.id,
            sourceId: entry.sourceId!, mangaId: entry.sourceMangaId, chapterId: entry.chapterId,
            mangaUrl })
          standalone.chapters[0].pages = resolved.pages
          standalone.chapters[0].pageCount = resolved.pages.length
          hydration = { hydrated: resolved.pages.length > 0, pageCount: resolved.pages.length,
            reasonCode: resolved.reasonCode, sourceFailure: resolved.sourceFailure }
        } else if (comic.sourceRuntimeId) {
          const chapter = comic.chapters.find((item: Chapter): boolean => item.id === entry.chapterId)
          if (chapter === undefined) return
          const plan = await resolveDownloadChapterPages(request.registry, comic, chapter)
          preparedPages = plan.pages
          hydration = { hydrated: plan.pages.length > 0, pageCount: plan.pages.length,
            reasonCode: plan.reasonCode, sourceFailure: plan.sourceFailure }
        }
      } catch (error) {
        DiagnosticLogger.exception('downloads', 'chapter_hydration_failed', error as Error)
        hydration = { hydrated: false, pageCount: 0, reasonCode: 'source_pages_failed' }
      }
      const current = standalone ?? request.library.getComic(entry.comicId)
      if (!isPending() || !canRunOfflineDownloadQueueNow(queue.loadPreferences())) return
      if (current === undefined) {
        entry.status = OfflineDownloadStatus.BLOCKED
        entry.failureReasonCode = 'comic_missing'
        queue.upsert(entry)
        return
      }
      if (!sameComicIdentity(comic, current)) return
      try {
        if (!hydration.hydrated) {
          const reason = hydration.sourceFailure?.kind === 'auth' ? 'source_login_required' :
            hydration.reasonCode ?? 'pages_missing'
          await service.blockChapterDownload(current, entry.chapterId, reason,
            { comicTitle: entry.comicTitle ?? current.title, chapterTitle: entry.chapterTitle }, isPending)
          return
        }
        const result = await service.downloadChapter(current, entry.chapterId,
          { comicTitle: entry.comicTitle ?? current.title, chapterTitle: entry.chapterTitle }, isPending, preparedPages)
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
    let completed = 0
    let failed = 0
    const first = queue.load().some((entry: OfflineDownloadQueueEntry): boolean =>
      entry.automatic === true && !entry.pausedByUser && isOfflineDownloadTaskPending(entry) &&
        entry.status !== OfflineDownloadStatus.DOWNLOADING)
    if (!first || !canRunOfflineDownloadQueueNow(queue.loadPreferences())) return
    await BackgroundDownloadOwner.run(request.context, async (): Promise<void> => {
      while (canRunOfflineDownloadQueueNow(queue.loadPreferences())) {
        // New requests resume when eligible. Previously staged records stay staged.
        const targets = queue.load().filter((entry: OfflineDownloadQueueEntry): boolean =>
          entry.automatic === true && !entry.pausedByUser && isOfflineDownloadTaskPending(entry) &&
            entry.status !== OfflineDownloadStatus.DOWNLOADING)
        if (targets.length === 0) break
        const count = await runOfflineDownloadBatch(request, targets)
        const current = queue.load()
        targets.forEach((target: OfflineDownloadQueueEntry): void => {
          const entry = current.find((item: OfflineDownloadQueueEntry): boolean => item.comicId === target.comicId &&
            item.chapterId === target.chapterId && item.requestId === target.requestId)
          if (entry === undefined) return
          if (entry.status === OfflineDownloadStatus.DOWNLOADED) completed += 1
          else if (!isOfflineDownloadTaskPending(entry) && !entry.pausedByUser && !entry.canceling) failed += 1
        })
        if (count === 0) break
      }
    })
    const pending = queue.load().some((entry: OfflineDownloadQueueEntry): boolean =>
      entry.automatic === true && isOfflineDownloadTaskPending(entry))
    if (!pending && (completed > 0 || failed > 0)) {
      await publishOfflineDownloadSummary(request.context, completed, failed)
    }
  }).finally(() => { automaticBatches.delete(filesDir) })
  automaticBatches.set(filesDir, pending)
  return pending
}
