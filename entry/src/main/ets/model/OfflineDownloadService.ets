import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { connection } from '@kit.NetworkKit'
import {
  Chapter,
  Comic,
  Page,
} from './ComicModels'
import {
  ReaderPageRenderKind,
  ReaderPageRenderSource,
  createReaderPageRenderSource,
  fetchReaderRemoteSourceBytes,
} from './ReaderPageSourceAdapter'
import { createReaderSessionConfigFromComic } from './ReaderSessionStore'
import {
  OfflineChapterDownloadManifest,
  OfflineChapterManifestLabels,
  OfflineChapterManifestIdentity,
  OfflineDownloadedChapterStatus,
  OfflineDownloadSummary,
  OfflineDownloadStatus,
  OfflineDownloadStore,
  OfflineDownloadedPage,
  createOfflineDownloadFileContentHash,
  createOfflineDownloadStableByteHash,
} from './OfflineDownloadStore'
import {
  OfflineDownloadQueuePreferences,
  OfflineDownloadQueueStore,
} from './OfflineDownloadQueueStore'
import {
  OfflineDownloadNotificationLabels as OfflineDownloadLabels,
  publishOfflineDownloadNotification,
} from './OfflineDownloadNotificationStore'

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

interface OfflineDownloadPageWriteResult {
  size: number
  contentHash: string
}

function writeBytesSync(path: string, bytes: ArrayBuffer): OfflineDownloadPageWriteResult {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    const written = fs.writeSync(file.fd, bytes)
    if (written !== bytes.byteLength) throw new Error('Incomplete download page write')
  } finally {
    closeFileQuietly(file)
  }
  const size = fs.statSync(path).size
  if (size !== bytes.byteLength) throw new Error('Incomplete download page file')
  return {
    size,
    contentHash: createOfflineDownloadStableByteHash(new Uint8Array(bytes)),
  }
}

async function copyLocalFile(sourcePath: string, targetPath: string): Promise<OfflineDownloadPageWriteResult> {
  if (sourcePath === targetPath) {
    return {
      size: fs.statSync(targetPath).size,
      contentHash: createOfflineDownloadFileContentHash(targetPath),
    }
  }
  let sourceFile: fs.File | undefined = undefined
  let targetFile: fs.File | undefined = undefined
  try {
    sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY)
    targetFile = fs.openSync(targetPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    await fs.copyFile(sourceFile.fd, targetFile.fd, 0)
  } finally {
    closeFileQuietly(sourceFile)
    closeFileQuietly(targetFile)
  }
  return {
    size: fs.statSync(targetPath).size,
    contentHash: createOfflineDownloadFileContentHash(targetPath),
  }
}

function extensionFromUri(uri: string): string {
  const withoutRef = uri.split('?')[0].split('#')[0].toLocaleLowerCase()
  const lastSegment = withoutRef.split('/').pop() ?? ''
  const dotIndex = lastSegment.lastIndexOf('.')
  if (dotIndex < 0 || dotIndex === lastSegment.length - 1) {
    return 'img'
  }
  const extension = lastSegment.slice(dotIndex + 1).replace(/[^a-z0-9]/g, '')
  return extension.length === 0 ? 'img' : extension
}

function pageAtIndex(chapter: Chapter, index: number): Page | undefined {
  return chapter.pages.find((page: Page): boolean => page.index === index) ?? chapter.pages[index]
}

function manifestIdentityFromComic(comic: Comic): OfflineChapterManifestIdentity {
  return {
    sourceKind: comic.sourceKind,
    sourceId: comic.sourceRuntimeId ?? comic.remoteServerId ?? comic.sourceKind,
    seriesId: comic.id,
  }
}

function manifestLabelsFromDownload(comic: Comic, chapter?: Chapter, labels?: OfflineDownloadLabels): OfflineChapterManifestLabels {
  return {
    comicTitle: labels?.comicTitle ?? comic.title,
    chapterTitle: labels?.chapterTitle ?? chapter?.title,
  }
}

function applyManifestLabels(
  manifest: OfflineChapterDownloadManifest,
  comic: Comic,
  chapter?: Chapter,
  labels?: OfflineDownloadLabels
): OfflineChapterDownloadManifest {
  const manifestLabels = manifestLabelsFromDownload(comic, chapter, labels)
  manifest.comicTitle = manifestLabels.comicTitle
  manifest.chapterTitle = manifestLabels.chapterTitle
  return manifest
}

function reusableDownloadedPage(pages: OfflineDownloadedPage[], pageId: string, pageIndex: number): OfflineDownloadedPage | undefined {
  const page = pages.find((item: OfflineDownloadedPage): boolean => {
    if (pageId.trim().length > 0) {
      return item.pageId === pageId
    }
    return item.pageIndex === pageIndex
  })
  if (page === undefined || !fs.accessSync(page.localPath)) {
    return undefined
  }
  return page
}

function isDefaultNetworkWifi(): boolean {
  try {
    const netHandle = connection.getDefaultNetSync()
    if (netHandle.netId === 0) {
      return false
    }
    const capabilities = connection.getNetCapabilitiesSync(netHandle)
    return capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0
  } catch (_error) {
    return false
  }
}

export function downloadBlockedReason(preferences: OfflineDownloadQueuePreferences): string {
  return preferences.isPaused ? 'paused' : 'wifi_only'
}

export function canRunOfflineDownloadQueueNow(preferences: OfflineDownloadQueuePreferences): boolean {
  return !preferences.isPaused && (!preferences.wifiOnly || isDefaultNetworkWifi())
}

@Concurrent
function initializeOfflineDownloadQueue(filesDir: string): void {
  // Startup restores queue state; explicit scans retain full page-content validation.
  new OfflineDownloadQueueStore(filesDir).reconcileWithManifests({ validateContentHash: false })
}

export class OfflineDownloadService {
  private readonly requestContext?: common.UIAbilityContext
  private readonly store: OfflineDownloadStore
  private readonly queueStore: OfflineDownloadQueueStore

  constructor(store: OfflineDownloadStore, queueStore?: OfflineDownloadQueueStore, requestContext?: common.UIAbilityContext) {
    this.requestContext = requestContext
    this.store = store
    this.queueStore = queueStore ?? new OfflineDownloadQueueStore(store.filesRootDir())
  }

  static ensureQueueInitialized(filesDir: string): Promise<void> {
    return OfflineDownloadRuntime.initialize(filesDir, async (): Promise<void> => {
      await taskpool.execute(new taskpool.Task(initializeOfflineDownloadQueue, filesDir))
      OfflineDownloadRuntime.publish(filesDir)
    })
  }

  getChapterSummary(comicId: string, chapterId: string): OfflineDownloadSummary | undefined {
    return this.store.loadSummary(comicId, chapterId)
  }

  async blockChapterDownload(comic: Comic, chapterId: string, reasonCode: string, labels?: OfflineDownloadLabels): Promise<OfflineChapterDownloadManifest> {
    const filesDir = this.store.filesRootDir()
    await OfflineDownloadService.ensureQueueInitialized(filesDir)
    return OfflineDownloadRuntime.run(filesDir, comic.id, chapterId,
      async (): Promise<OfflineChapterDownloadManifest> => this.saveBlockedChapter(comic, chapterId, reasonCode, labels))
  }

  private saveBlockedChapter(comic: Comic, chapterId: string, reasonCode: string, labels?: OfflineDownloadLabels): OfflineChapterDownloadManifest {
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === chapterId)
    // A source lookup failure must not orphan pages already downloaded for this chapter.
    let manifest = this.store.loadManifest(comic.id, chapterId)
    if (manifest === undefined) {
      manifest = this.store.createManifest(
        comic.id,
        chapterId,
        0,
        OfflineDownloadStatus.BLOCKED,
        manifestIdentityFromComic(comic),
        manifestLabelsFromDownload(comic, chapter, labels)
      )
    } else if (manifest.pages.length > 0) {
      manifest.status = manifest.status === OfflineDownloadStatus.DOWNLOADED
        ? OfflineDownloadStatus.DOWNLOADED : OfflineDownloadStatus.PARTIAL
    } else {
      manifest.status = OfflineDownloadStatus.BLOCKED
    }
    manifest.failureReasonCode = reasonCode
    manifest = this.store.saveManifest(applyManifestLabels(manifest, comic, chapter, labels))
    this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter?.title))
    this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter?.title })
    return manifest
  }

  async downloadChapter(comic: Comic, chapterId: string, labels?: OfflineDownloadLabels): Promise<OfflineChapterDownloadManifest> {
    const filesDir = this.store.filesRootDir()
    await OfflineDownloadService.ensureQueueInitialized(filesDir)
    const key = OfflineDownloadRuntime.key(filesDir, comic.id, chapterId)
    return OfflineDownloadRuntime.run(filesDir, comic.id, chapterId,
      () => this.runChapterDownload(comic, chapterId, key, labels),
      () => this.queueStore.loadPreferences().foregroundConcurrencyLimit)
  }

  async runChapterBatch(chapterIds: string[], execute: (chapterId: string) => Promise<void>): Promise<void> {
    await OfflineDownloadRuntime.runBatch(chapterIds, this.queueStore.loadPreferences().foregroundConcurrencyLimit, execute)
  }

  private async runChapterDownload(
    comic: Comic, chapterId: string, executionKey: string, labels?: OfflineDownloadLabels,
  ): Promise<OfflineChapterDownloadManifest> {
    const initialPreferences = this.queueStore.loadPreferences()
    this.queueStore.upsert({
      comicId: comic.id,
      chapterId,
      comicTitle: labels?.comicTitle ?? comic.title,
      chapterTitle: labels?.chapterTitle,
      status: OfflineDownloadStatus.QUEUED,
      pageCount: 0,
      downloadedPageCount: 0,
      updatedAt: Date.now(),
    })
    const latestPreferences = this.queueStore.loadPreferences()
    const initialCanDownload = this.canDownloadNow(initialPreferences)
    const latestCanDownload = this.canDownloadNow(latestPreferences)
    if (!initialCanDownload || !latestCanDownload) {
      const blockedReason = downloadBlockedReason(!latestCanDownload ? latestPreferences : initialPreferences)
      let existingManifest = this.store.loadManifest(comic.id, chapterId)
      if (existingManifest !== undefined) {
        const validation = this.store.validateDownloadedChapter(comic.id, chapterId)
        const complete = validation.status === OfflineDownloadedChapterStatus.DOWNLOADED
        existingManifest.status = complete ? OfflineDownloadStatus.DOWNLOADED :
          (existingManifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.QUEUED)
        existingManifest.failureReasonCode = complete ? undefined : blockedReason
        existingManifest = this.store.saveManifest(applyManifestLabels(existingManifest, comic, undefined, labels))
        this.queueStore.upsert(this.queueStore.fromManifest(existingManifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle))
        return existingManifest
      }
      const queuedManifest = this.store.createManifest(
        comic.id,
        chapterId,
        0,
        OfflineDownloadStatus.QUEUED,
        manifestIdentityFromComic(comic),
        manifestLabelsFromDownload(comic, undefined, labels)
      )
      queuedManifest.failureReasonCode = blockedReason
      this.store.saveManifest(queuedManifest)
      this.queueStore.upsert(this.queueStore.fromManifest(queuedManifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle))
      return queuedManifest
    }
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === chapterId)
    if (chapter === undefined) {
      DiagnosticLogger.warn('download', 'download_blocked', `[ReaderOffline] step=download_blocked reason=chapter_missing`)
      return this.saveBlockedChapter(comic, chapterId, 'chapter_missing', labels)
    }
    if (chapter.pages.length === 0) {
      DiagnosticLogger.warn('download', 'download_blocked', `[ReaderOffline] step=download_blocked reason=pages_missing`)
      return this.saveBlockedChapter(comic, chapterId, 'pages_missing', labels)
    }

    const existingValidation = this.store.validateDownloadedChapter(comic.id, chapterId)
    if (existingValidation.status === OfflineDownloadedChapterStatus.DOWNLOADED &&
      existingValidation.manifest !== undefined) {
      const manifest = this.store.saveManifest(applyManifestLabels(existingValidation.manifest, comic, chapter, labels))
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      DiagnosticLogger.info('download', 'download_reused', `[ReaderOffline] step=download_reused pages=${existingValidation.availablePageCount}/${existingValidation.pageCount}`)
      return manifest
    }
    const reusablePages = existingValidation.status === OfflineDownloadedChapterStatus.PARTIAL && existingValidation.manifest !== undefined ?
      existingValidation.manifest.pages :
      []
    let manifest = this.store.createManifest(
      comic.id,
      chapterId,
      chapter.pages.length,
      OfflineDownloadStatus.DOWNLOADING,
      manifestIdentityFromComic(comic),
      manifestLabelsFromDownload(comic, chapter, labels)
    )
    this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    let pageFetchFailed = false
    try {
      for (let index = 0; index < config.totalPages; index += 1) {
        const preferences = this.queueStore.loadPreferences()
        if (OfflineDownloadRuntime.isPauseRequested(executionKey) || !this.canDownloadNow(preferences)) {
          manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.QUEUED
          manifest.failureReasonCode = OfflineDownloadRuntime.isPauseRequested(executionKey) || preferences.isPaused ? 'paused' : 'wifi_only'
          manifest = this.store.saveManifest(manifest)
          this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
          return manifest
        }
        const page = pageAtIndex(chapter, index)
        const pageId = page?.id ?? `page-${index + 1}`
        const reusablePage = reusableDownloadedPage(reusablePages, pageId, index)
        if (reusablePage !== undefined) {
          manifest = this.store.recordPage(manifest, {
            pageId,
            pageIndex: index,
            fileName: reusablePage.fileName,
            width: page?.width ?? reusablePage.width,
            height: page?.height ?? reusablePage.height,
            localPath: reusablePage.localPath,
            size: reusablePage.size,
            contentHash: reusablePage.contentHash,
            updatedAt: reusablePage.updatedAt,
          })
          this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
          continue
        }
        const source = createReaderPageRenderSource(config, index, { preferOffline: false })
        const localPath = this.store.pageFilePath(comic.id, chapterId, pageId, index, extensionFromUri(source.uri.length > 0 ? source.uri : source.imageUri))
        let writtenPage: OfflineDownloadPageWriteResult
        try {
          writtenPage = await this.writePage(source, localPath)
        } catch (error) {
          void error
          pageFetchFailed = true
          DiagnosticLogger.warn('download', 'download_page_failed', `[ReaderOffline] step=download_page_failed page=${index} reason=page_fetch_failed`)
          continue
        }
        const row: OfflineDownloadedPage = {
          pageId,
          pageIndex: index,
          width: page?.width,
          height: page?.height,
          localPath,
          size: writtenPage.size,
          contentHash: writtenPage.contentHash,
          updatedAt: Date.now(),
        }
        manifest = this.store.recordPage(manifest, row)
        this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      }
      manifest.status = OfflineDownloadStatus.DOWNLOADED
      manifest = this.store.saveManifest(manifest)
      const finalValidation = this.store.validateDownloadedChapter(comic.id, chapterId, { validateContentHash: false })
      if (finalValidation.status !== OfflineDownloadedChapterStatus.DOWNLOADED ||
        finalValidation.pageCount <= 0 ||
        finalValidation.availablePageCount !== finalValidation.pageCount ||
        finalValidation.missingPageCount !== 0) {
        manifest.status = finalValidation.availablePageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.FAILED
        manifest.failureReasonCode = pageFetchFailed ? 'page_fetch_failed' : (finalValidation.reasonCode ?? 'manifest_validation_failed')
        manifest = this.store.saveManifest(manifest)
        this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
        DiagnosticLogger.warn('download', 'download_final_validation_failed', `[ReaderOffline] step=download_final_validation_failed pages=${finalValidation.availablePageCount}/${finalValidation.pageCount} reason=${manifest.failureReasonCode}`)
        this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
        return manifest
      }
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      DiagnosticLogger.info('download', 'download_done', `[ReaderOffline] step=download_done pages=${manifest.downloadedPageCount}/${manifest.pageCount}`)
      this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
      return manifest
    } catch (error) {
      void error
      manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.FAILED
      manifest.failureReasonCode = 'page_fetch_failed'
      manifest = this.store.saveManifest(manifest)
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      DiagnosticLogger.warn('download', 'download_failed', `[ReaderOffline] step=download_failed pages=${manifest.downloadedPageCount}/${manifest.pageCount} reason=page_fetch_failed`)
      this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
      return manifest
    }
  }

  private canDownloadNow(preferences: OfflineDownloadQueuePreferences): boolean {
    return canRunOfflineDownloadQueueNow(preferences)
  }

  private publishNotification(manifest: OfflineChapterDownloadManifest, labels?: OfflineDownloadLabels): void {
    void publishOfflineDownloadNotification(manifest, labels)
      .then((result) => {
        DiagnosticLogger.info('download', 'download_notification', '[ReaderOffline] step=download_notification code=' + result.code)
      })
  }

  private async writePage(source: ReaderPageRenderSource, localPath: string): Promise<OfflineDownloadPageWriteResult> {
    if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
      return copyLocalFile(source.imageUri, localPath)
    }
    if (source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) {
      throw new Error('unsupported page source')
    }
    const bytes = await fetchReaderRemoteSourceBytes(source, this.requestContext)
    return writeBytesSync(localPath, bytes)
  }
}
