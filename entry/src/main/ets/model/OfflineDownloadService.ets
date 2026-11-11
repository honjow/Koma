import { appSourceRuntimeRegistry, sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { DiagnosticLogger, DiagnosticOperation } from '../diagnostics/DiagnosticLogger'
import { SourceRequiredImageDecodeService } from './SourceRequiredImageDecode'
import { downloadImagePathForBytes } from './DownloadImageFormat'
import { BackgroundDownloadOwner } from './BackgroundDownloadOwner'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool, url } from '@kit.ArkTS'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { connection } from '@kit.NetworkKit'
import {
  Chapter,
  Comic,
  Page,
} from './ComicModels'
import {
  ReaderPageRenderKind,
  cacheSourceTextPageImage,
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
} from './OfflineDownloadNotificationStore'

const OFFLINE_DOWNLOAD_MANIFEST_PROGRESS_INTERVAL_MS: number = 1000

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
  localPath?: string
  requiredImageDecodeResolved?: boolean
}

@Concurrent
function writeDownloadPageBytesWorker(path: string, bytes: ArrayBuffer): OfflineDownloadPageWriteResult {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    const written = fs.writeSync(file.fd, bytes)
    if (written !== bytes.byteLength) throw new Error('Incomplete download page write')
  } finally {
    if (file !== undefined) {
      try {
        fs.closeSync(file)
      } catch (_error) {
      }
    }
  }
  const size = fs.statSync(path).size
  if (size !== bytes.byteLength) throw new Error('Incomplete download page file')
  return {
    size,
    contentHash: createOfflineDownloadStableByteHash(new Uint8Array(bytes)),
  }
}

async function writeDownloadPageBytes(path: string, bytes: ArrayBuffer): Promise<OfflineDownloadPageWriteResult> {
  return await taskpool.execute(writeDownloadPageBytesWorker, path, bytes) as OfflineDownloadPageWriteResult
}

@Concurrent
function copyDownloadPageFileWorker(sourcePath: string, targetPath: string): OfflineDownloadPageWriteResult {
  const source = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY)
  const header = new ArrayBuffer(32)
  let count: number = 0
  try { count = fs.readSync(source.fd, header) } finally { fs.closeSync(source) }
  targetPath = downloadImagePathForBytes(targetPath, new Uint8Array(header, 0, count))
  if (sourcePath !== targetPath) {
    fs.copyFileSync(sourcePath, targetPath, 0)
  }
  return {
    size: fs.statSync(targetPath).size,
    contentHash: createOfflineDownloadFileContentHash(targetPath),
    localPath: targetPath,
  }
}

async function copyLocalFile(sourcePath: string, targetPath: string): Promise<OfflineDownloadPageWriteResult> {
  return await taskpool.execute(copyDownloadPageFileWorker, sourcePath, targetPath) as OfflineDownloadPageWriteResult
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

// Only the installed package's public work origins can persist a safe URL.
function publicSourceWorkUri(sourceId: string | undefined, value: string | undefined): string | undefined {
  if (sourceId === undefined || value === undefined) return undefined
  const domains = appSourceRuntimeRegistry.lookup(sourceId).entry?.websitePolicy?.publicWorkUrlDomains
  if (domains === undefined) return undefined
  try {
    const parsed = new url.URL(value)
    const host = parsed.hostname.toLowerCase()
    if ((parsed.protocol !== 'https:' && parsed.protocol !== 'http:') || parsed.username.length > 0 ||
      parsed.password.length > 0 || parsed.search.length > 0 || parsed.hash.length > 0 ||
      !domains.some((domain: string): boolean => host === domain || host.endsWith('.' + domain))) return undefined
    return value
  } catch (_error) { return undefined }
}

function manifestIdentityFromComic(comic: Comic): OfflineChapterManifestIdentity {
  return {
    sourceKind: comic.sourceKind,
    sourceId: comic.sourceRuntimeId ?? comic.remoteServerId ?? comic.sourceKind,
    sourceMangaUrl: publicSourceWorkUri(comic.sourceRuntimeId, comic.sourcePath),
    seriesId: comic.id,
  }
}

function manifestSourceNameFromComic(comic: Comic): string | undefined {
  const storedName = comic.sourceMetadata?.sourceName?.trim() ?? ''
  const sourceId = comic.sourceRuntimeId?.trim() ?? ''
  if (sourceId.length === 0) return storedName.length > 0 ? storedName : undefined
  const fallback = storedName.length > 0 ? storedName : sourceId
  const displayName = sourceDisplayName(sourceId, fallback).trim()
  return displayName.length > 0 ? displayName : fallback
}

function manifestLabelsFromDownload(comic: Comic, chapter?: Chapter, labels?: OfflineDownloadLabels): OfflineChapterManifestLabels {
  return {
    comicTitle: labels?.comicTitle ?? comic.title,
    chapterTitle: labels?.chapterTitle ?? chapter?.title,
    sourceName: manifestSourceNameFromComic(comic),
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
  manifest.sourceName = manifestLabels.sourceName
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

export type OfflineDownloadWaitReason = 'paused' | 'wifi_only' | 'offline'

export function downloadBlockedReason(preferences: OfflineDownloadQueuePreferences): OfflineDownloadWaitReason | undefined {
  if (preferences.isPaused) return 'paused'
  try {
    const netHandle = connection.getDefaultNetSync()
    if (netHandle.netId === 0) return 'offline'
    if (preferences.wifiOnly) {
      const capabilities = connection.getNetCapabilitiesSync(netHandle)
      if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) < 0) return 'wifi_only'
    }
  } catch (_error) {
    return 'offline'
  }
  return undefined
}

export function canRunOfflineDownloadQueueNow(preferences: OfflineDownloadQueuePreferences): boolean {
  return downloadBlockedReason(preferences) === undefined
}

@Concurrent
function initializeOfflineDownloadQueue(filesDir: string, runtimeKey: string): void {
  // Startup restores queue state; explicit scans retain full page-content validation.
  new OfflineDownloadQueueStore(filesDir, runtimeKey).reconcileWithManifests({ validateContentHash: false })
}

export class OfflineDownloadService {
  private readonly requestContext?: common.UIAbilityContext
  private readonly store: OfflineDownloadStore
  private readonly queueStore: OfflineDownloadQueueStore
  private lastManifestProgressPersistedAt: number = 0

  constructor(store: OfflineDownloadStore, queueStore?: OfflineDownloadQueueStore, requestContext?: common.UIAbilityContext) {
    this.requestContext = requestContext
    this.store = store
    this.queueStore = queueStore ?? new OfflineDownloadQueueStore(store.filesRootDir(), store.runtimeKey())
  }

  static ensureQueueInitialized(filesDir: string, runtimeKey: string = filesDir): Promise<void> {
    return OfflineDownloadRuntime.initialize(runtimeKey, async (): Promise<void> => {
      await taskpool.execute(new taskpool.Task(initializeOfflineDownloadQueue, filesDir, runtimeKey))
      await new OfflineDownloadQueueStore(filesDir, runtimeKey).finishCanceledTasks()
      OfflineDownloadRuntime.publish(runtimeKey)
    })
  }

  getChapterSummary(comicId: string, chapterId: string): OfflineDownloadSummary | undefined {
    return this.store.loadSummary(comicId, chapterId)
  }

  async blockChapterDownload(comic: Comic, chapterId: string, reasonCode: string, labels?: OfflineDownloadLabels,
    isRequested: () => boolean = () => true): Promise<OfflineChapterDownloadManifest> {
    const filesDir = this.store.filesRootDir()
    const runtimeKey = this.store.runtimeKey()
    await OfflineDownloadService.ensureQueueInitialized(filesDir, runtimeKey)
    return OfflineDownloadRuntime.run(runtimeKey, comic.id, chapterId,
      async (): Promise<OfflineChapterDownloadManifest> => {
        if (!isRequested()) throw new Error('download_request_removed')
        return this.saveBlockedChapter(comic, chapterId, reasonCode, labels)
      })
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
    return manifest
  }

  async downloadChapter(comic: Comic, chapterId: string, labels?: OfflineDownloadLabels,
    isRequested: () => boolean = () => true): Promise<OfflineChapterDownloadManifest> {
    const trace = DiagnosticLogger.begin('download', 'chapter')
    try {
      const filesDir = this.store.filesRootDir()
      const runtimeKey = this.store.runtimeKey()
      await OfflineDownloadService.ensureQueueInitialized(filesDir, runtimeKey)
      const key = OfflineDownloadRuntime.key(runtimeKey, comic.id, chapterId)
      const manifest = await OfflineDownloadRuntime.run(runtimeKey, comic.id, chapterId,
        () => {
          const start = (): Promise<OfflineChapterDownloadManifest> => {
            if (!isRequested()) throw new Error('download_request_removed')
            return this.runChapterDownload(comic, chapterId, key, trace, labels)
          }
          return canRunOfflineDownloadQueueNow(this.queueStore.loadPreferences())
            ? BackgroundDownloadOwner.run(this.requestContext, start) : start()
        },
        () => this.queueStore.loadPreferences().foregroundConcurrencyLimit)
      trace.finish(manifest.status === OfflineDownloadStatus.DOWNLOADED ? 'completed' : manifest.status,
        'pages=' + manifest.downloadedPageCount + '/' + manifest.pageCount + ' reason=' + (manifest.failureReasonCode ?? 'none'))
      return manifest
    } catch (error) { trace.fail(error as Error); throw error as Error }
  }

  private async runChapterDownload(
    comic: Comic, chapterId: string, executionKey: string, trace: DiagnosticOperation, labels?: OfflineDownloadLabels,
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
    const blockedReason = downloadBlockedReason(latestPreferences) ?? downloadBlockedReason(initialPreferences)
    if (blockedReason !== undefined) {
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
      trace.warn('download_blocked', `[ReaderOffline] step=download_blocked reason=chapter_missing`)
      return this.saveBlockedChapter(comic, chapterId, 'chapter_missing', labels)
    }
    if (chapter.pages.length === 0) {
      trace.warn('download_blocked', `[ReaderOffline] step=download_blocked reason=pages_missing`)
      return this.saveBlockedChapter(comic, chapterId, 'pages_missing', labels)
    }

    const existingValidation = this.store.validateDownloadedChapter(comic.id, chapterId)
    if (existingValidation.status === OfflineDownloadedChapterStatus.DOWNLOADED &&
      existingValidation.manifest !== undefined) {
      const manifest = this.store.saveManifest(applyManifestLabels(existingValidation.manifest, comic, chapter, labels))
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      trace.info('download_reused', `[ReaderOffline] step=download_reused pages=${existingValidation.availablePageCount}/${existingValidation.pageCount}`)
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
    this.lastManifestProgressPersistedAt = Date.now()
    let pageFetchFailed = false
    const waitReason = (): OfflineDownloadWaitReason | undefined => {
      return OfflineDownloadRuntime.isPauseRequested(executionKey) ? 'paused' :
        downloadBlockedReason(this.queueStore.loadPreferences())
    }
    const saveDeferred = (reason: OfflineDownloadWaitReason): OfflineChapterDownloadManifest => {
      manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.QUEUED
      manifest.failureReasonCode = reason
      manifest = this.store.saveManifest(manifest)
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      return manifest
    }
    try {
      for (let index = 0; index < config.totalPages; index += 1) {
        const reason = waitReason()
        if (reason !== undefined) return saveDeferred(reason)
        const page = pageAtIndex(chapter, index)
        const pageId = page?.id ?? `page-${index + 1}`
        const reusablePage = reusableDownloadedPage(reusablePages, pageId, index)
        if (reusablePage !== undefined) {
          const persistProgress: boolean = this.shouldPersistManifestProgress(index + 1 >= config.totalPages)
          manifest = this.store.recordPage(manifest, {
            pageId,
            pageIndex: index,
            fileName: reusablePage.fileName,
            width: page?.width ?? reusablePage.width,
            height: page?.height ?? reusablePage.height,
            localPath: reusablePage.localPath,
            size: reusablePage.size,
            contentHash: reusablePage.contentHash,
            imageProcessing: reusablePage.imageProcessing,
            imageProcessingResolved: reusablePage.imageProcessingResolved,
            imageProcessingFingerprint: reusablePage.imageProcessingFingerprint,
            sourceOriginalUri: reusablePage.sourceOriginalUri,
            sourceTextOverlay: page === undefined ? reusablePage.sourceTextOverlay : page.sourceTextOverlay,
            requiredImageDecodeResolved: reusablePage.requiredImageDecodeResolved,
            updatedAt: reusablePage.updatedAt,
          }, persistProgress)
          if (persistProgress) {
            this.queueStore.upsertProgress(this.queueStore.fromManifest(
              manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
          }
          continue
        }
        const source = createReaderPageRenderSource(config, index, { preferOffline: false })
        const extension = source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST ? 'png' :
          extensionFromUri(source.uri.length > 0 ? source.uri : source.imageUri)
        let localPath = this.store.pageFilePath(comic.id, chapterId, pageId, index, extension)
        let writtenPage: OfflineDownloadPageWriteResult
        try {
          writtenPage = await this.writePage(source, localPath)
          localPath = writtenPage.localPath ?? localPath
        } catch (error) {
          void error
          pageFetchFailed = true
          trace.warn('download_page_failed', `[ReaderOffline] step=download_page_failed page=${index} reason=page_fetch_failed ${DiagnosticLogger.errorSummary(error as Error)}`)
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
          imageProcessing: source.imageProcessing,
          imageProcessingResolved: source.imageProcessingResolved,
          imageProcessingFingerprint: source.imageProcessingFingerprint,
          sourceOriginalUri: publicSourceWorkUri(comic.sourceRuntimeId, page?.uri),
          sourceTextOverlay: page?.sourceTextOverlay,
          requiredImageDecodeResolved: writtenPage.requiredImageDecodeResolved,
          updatedAt: Date.now(),
        }
        const persistProgress: boolean = this.shouldPersistManifestProgress(index + 1 >= config.totalPages)
        manifest = this.store.recordPage(manifest, row, persistProgress)
        BackgroundDownloadOwner.progress(labels?.chapterTitle ?? chapter.title, manifest.downloadedPageCount, manifest.pageCount)
        if (persistProgress) {
          this.queueStore.upsertProgress(this.queueStore.fromManifest(
            manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
        }
      }
      const finalWait = waitReason()
      if (finalWait !== undefined) return saveDeferred(finalWait)
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
        trace.warn('download_final_validation_failed', `[ReaderOffline] step=download_final_validation_failed pages=${finalValidation.availablePageCount}/${finalValidation.pageCount} reason=${manifest.failureReasonCode}`)
        return manifest
      }
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      trace.info('download_done', `[ReaderOffline] step=download_done pages=${manifest.downloadedPageCount}/${manifest.pageCount}`)
      return manifest
    } catch (error) {
      void error
      manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.FAILED
      manifest.failureReasonCode = 'page_fetch_failed'
      manifest = this.store.saveManifest(manifest)
      this.queueStore.upsert(this.queueStore.fromManifest(manifest, labels?.comicTitle ?? comic.title, labels?.chapterTitle ?? chapter.title))
      trace.warn('download_failed', `[ReaderOffline] step=download_failed pages=${manifest.downloadedPageCount}/${manifest.pageCount} reason=page_fetch_failed ${DiagnosticLogger.errorSummary(error as Error)}`)
      return manifest
    }
  }

  private shouldPersistManifestProgress(finalPage: boolean): boolean {
    const now: number = Date.now()
    if (!finalPage && now - this.lastManifestProgressPersistedAt < OFFLINE_DOWNLOAD_MANIFEST_PROGRESS_INTERVAL_MS) {
      return false
    }
    this.lastManifestProgressPersistedAt = now
    return true
  }

  private async writePage(source: ReaderPageRenderSource, localPath: string): Promise<OfflineDownloadPageWriteResult> {
    if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
      if (source.sourceText !== undefined) {
        if (source.requiredImageDecode !== undefined) throw new Error('source_required_decode_invalid')
        const path = await cacheSourceTextPageImage(source.sourceText)
        return copyLocalFile(path, localPath)
      }
      if (source.requiredImageDecode === undefined || source.requiredImageDecodeResolved === true) {
        const copied = await copyLocalFile(source.imageUri, localPath)
        if (source.requiredImageDecodeResolved === true) copied.requiredImageDecodeResolved = true
        return copied
      }
    }
    if (source.kind !== ReaderPageRenderKind.LOCAL_FILE_IMAGE && source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE &&
      source.kind !== ReaderPageRenderKind.SOURCE_TEXT_REQUEST) {
      throw new Error('unsupported page source')
    }
    if (source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST && source.requiredImageDecode !== undefined) {
      throw new Error('source_required_decode_invalid')
    }
    const bytes = await fetchReaderRemoteSourceBytes(source, this.requestContext)
    if (source.requiredImageDecode !== undefined && source.requiredImageDecodeResolved !== true) {
      const decoded = await SourceRequiredImageDecodeService.decodeBytes(bytes, source.requiredImageDecode)
      // Canonical file extension follows actual GIF bytes, never the URL suffix.
      const canonicalPath = localPath.replace(/\.[^/.]+$/, '.' + decoded.extension)
      const result = await writeDownloadPageBytes(canonicalPath, decoded.bytes)
      result.localPath = canonicalPath
      result.requiredImageDecodeResolved = true
      return result
    }
    const detectedPath = downloadImagePathForBytes(localPath, new Uint8Array(bytes, 0, Math.min(32, bytes.byteLength)))
    const result = await writeDownloadPageBytes(detectedPath, bytes)
    result.localPath = detectedPath
    return result
  }
}
