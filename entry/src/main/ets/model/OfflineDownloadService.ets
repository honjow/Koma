import { fileIo as fs } from '@kit.CoreFileKit'
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
  OfflineChapterManifestIdentity,
  OfflineDownloadedChapterStatus,
  OfflineDownloadSummary,
  OfflineDownloadStatus,
  OfflineDownloadStore,
  OfflineDownloadedPage,
  createOfflineDownloadStableHash,
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

function writeBytesSync(path: string, bytes: ArrayBuffer): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, bytes)
  } finally {
    closeFileQuietly(file)
  }
}

async function copyLocalFile(sourcePath: string, targetPath: string): Promise<number> {
  if (sourcePath === targetPath) {
    return fs.statSync(targetPath).size
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
  return fs.statSync(targetPath).size
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

function reusableDownloadedPage(pages: OfflineDownloadedPage[], pageId: string, pageIndex: number): OfflineDownloadedPage | undefined {
  const page = pages.find((item: OfflineDownloadedPage): boolean => {
    return item.pageId === pageId || item.pageIndex === pageIndex
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

export class OfflineDownloadService {
  private readonly store: OfflineDownloadStore
  private readonly queueStore: OfflineDownloadQueueStore

  constructor(store: OfflineDownloadStore, queueStore?: OfflineDownloadQueueStore) {
    this.store = store
    this.queueStore = queueStore ?? new OfflineDownloadQueueStore(store.filesRootDir())
  }

  getChapterSummary(comicId: string, chapterId: string): OfflineDownloadSummary | undefined {
    return this.store.loadSummary(comicId, chapterId)
  }

  async downloadChapter(comic: Comic, chapterId: string, labels?: OfflineDownloadLabels): Promise<OfflineChapterDownloadManifest> {
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
    if (!this.canDownloadNow(initialPreferences) || !this.canDownloadNow(this.queueStore.loadPreferences())) {
      const existingManifest = this.store.loadManifest(comic.id, chapterId)
      if (existingManifest !== undefined) {
        existingManifest.status = existingManifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.QUEUED
        existingManifest.failureReasonCode = initialPreferences.isPaused ? 'paused' : 'wifi_only'
        this.store.saveManifest(existingManifest)
        this.queueStore.upsert(this.queueStore.fromManifest(existingManifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle))
        return existingManifest
      }
      const queuedManifest = this.store.createManifest(comic.id, chapterId, 0, OfflineDownloadStatus.QUEUED, manifestIdentityFromComic(comic))
      queuedManifest.failureReasonCode = initialPreferences.isPaused ? 'paused' : 'wifi_only'
      this.store.saveManifest(queuedManifest)
      this.queueStore.upsert(this.queueStore.fromManifest(queuedManifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle))
      return queuedManifest
    }
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === chapterId)
    if (chapter === undefined) {
      console.warn(`[ReaderOffline] step=download_blocked comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} reason=chapter_missing`)
      let manifest = this.store.createManifest(comic.id, chapterId, 0, OfflineDownloadStatus.BLOCKED, manifestIdentityFromComic(comic))
      manifest.failureReasonCode = 'chapter_missing'
      manifest = this.store.saveManifest(manifest)
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle))
      this.publishNotification(manifest, labels ?? { comicTitle: comic.title })
      return manifest
    }
    if (chapter.pages.length === 0) {
      console.warn(`[ReaderOffline] step=download_blocked comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} reason=pages_missing`)
      const manifest = this.store.saveManifest({
        schemaVersion: 1,
        sourceKind: comic.sourceKind,
        sourceId: comic.sourceRuntimeId ?? comic.remoteServerId ?? comic.sourceKind,
        comicId: comic.id,
        seriesId: comic.id,
        chapterId,
        pageCount: 0,
        downloadedPageCount: 0,
        status: OfflineDownloadStatus.BLOCKED,
        updatedAt: Date.now(),
        pages: [],
        integrityHash: '',
        failureReasonCode: 'pages_missing',
      })
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
      return manifest
    }

    const existingValidation = this.store.validateDownloadedChapter(comic.id, chapterId)
    const reusablePages = existingValidation.status === OfflineDownloadedChapterStatus.PARTIAL && existingValidation.manifest !== undefined ?
      existingValidation.manifest.pages :
      []
    let manifest = this.store.createManifest(comic.id, chapterId, chapter.pages.length, OfflineDownloadStatus.DOWNLOADING, manifestIdentityFromComic(comic))
    this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    try {
      for (let index = 0; index < config.totalPages; index += 1) {
        const preferences = this.queueStore.loadPreferences()
        if (!this.canDownloadNow(preferences)) {
          manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.QUEUED
          manifest.failureReasonCode = preferences.isPaused ? 'paused' : 'wifi_only'
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
            localPath: reusablePage.localPath,
            size: reusablePage.size,
            updatedAt: reusablePage.updatedAt,
          })
          this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
          continue
        }
        const source = createReaderPageRenderSource(config, index, { preferOffline: false })
        const localPath = this.store.pageFilePath(comic.id, chapterId, pageId, index, extensionFromUri(source.uri.length > 0 ? source.uri : source.imageUri))
        const size = await this.writePage(source, localPath)
        const row: OfflineDownloadedPage = {
          pageId,
          pageIndex: index,
          localPath,
          size,
          updatedAt: Date.now(),
        }
        manifest = this.store.recordPage(manifest, row)
        this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      }
      manifest.status = OfflineDownloadStatus.DOWNLOADED
      manifest = this.store.saveManifest(manifest)
      const finalValidation = this.store.validateDownloadedChapter(comic.id, chapterId)
      if (!this.store.isChapterFullyDownloaded(comic.id, chapterId)) {
        manifest.status = finalValidation.availablePageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.FAILED
        manifest.failureReasonCode = finalValidation.reasonCode ?? 'manifest_validation_failed'
        manifest = this.store.saveManifest(manifest)
        this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
        console.warn(`[ReaderOffline] step=download_final_validation_failed comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} pages=${finalValidation.availablePageCount}/${finalValidation.pageCount} reason=${manifest.failureReasonCode}`)
        this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
        return manifest
      }
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      console.info(`[ReaderOffline] step=download_done comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} pages=${manifest.downloadedPageCount}/${manifest.pageCount}`)
      this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
      return manifest
    } catch (error) {
      void error
      manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.FAILED
      manifest.failureReasonCode = 'page_fetch_failed'
      manifest = this.store.saveManifest(manifest)
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      console.warn(`[ReaderOffline] step=download_failed comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} pages=${manifest.downloadedPageCount}/${manifest.pageCount} reason=page_fetch_failed`)
      this.publishNotification(manifest, labels ?? { comicTitle: comic.title, chapterTitle: chapter.title })
      return manifest
    }
  }

  private canDownloadNow(preferences: OfflineDownloadQueuePreferences): boolean {
    return !preferences.isPaused && (!preferences.wifiOnly || isDefaultNetworkWifi())
  }

  private publishNotification(manifest: OfflineChapterDownloadManifest, labels?: OfflineDownloadLabels): void {
    void publishOfflineDownloadNotification(manifest, labels)
      .then((result) => {
        console.info('[ReaderOffline] step=download_notification code=' + result.code)
      })
  }

  private async writePage(source: ReaderPageRenderSource, localPath: string): Promise<number> {
    if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
      return copyLocalFile(source.imageUri, localPath)
    }
    if (source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) {
      throw new Error('unsupported page source')
    }
    const bytes = await fetchReaderRemoteSourceBytes(source)
    writeBytesSync(localPath, bytes)
    return fs.statSync(localPath).size
  }
}
