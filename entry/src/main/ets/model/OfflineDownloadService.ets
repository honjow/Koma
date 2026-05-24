import { fileIo as fs } from '@kit.CoreFileKit'
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
  OfflineDownloadSummary,
  OfflineDownloadStatus,
  OfflineDownloadStore,
  OfflineDownloadedPage,
  createOfflineDownloadStableHash,
} from './OfflineDownloadStore'

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

export class OfflineDownloadService {
  private readonly store: OfflineDownloadStore

  constructor(store: OfflineDownloadStore) {
    this.store = store
  }

  getChapterSummary(comicId: string, chapterId: string): OfflineDownloadSummary | undefined {
    return this.store.loadSummary(comicId, chapterId)
  }

  async downloadChapter(comic: Comic, chapterId: string): Promise<OfflineChapterDownloadManifest> {
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === chapterId)
    if (chapter === undefined) {
      console.warn(`[ReaderOffline] step=download_blocked comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} reason=chapter_missing`)
      return this.store.createManifest(comic.id, chapterId, 0, OfflineDownloadStatus.BLOCKED)
    }
    if (chapter.pages.length === 0) {
      console.warn(`[ReaderOffline] step=download_blocked comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} reason=pages_missing`)
      return this.store.saveManifest({
        schemaVersion: 1,
        comicId: comic.id,
        chapterId,
        pageCount: 0,
        downloadedPageCount: 0,
        status: OfflineDownloadStatus.BLOCKED,
        updatedAt: Date.now(),
        pages: [],
        failureReasonCode: 'pages_missing',
      })
    }

    let manifest = this.store.createManifest(comic.id, chapterId, chapter.pages.length, OfflineDownloadStatus.DOWNLOADING)
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    try {
      for (let index = 0; index < config.totalPages; index += 1) {
        const page = pageAtIndex(chapter, index)
        const pageId = page?.id ?? `page-${index + 1}`
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
      }
      manifest.status = OfflineDownloadStatus.DOWNLOADED
      manifest = this.store.saveManifest(manifest)
      console.info(`[ReaderOffline] step=download_done comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} pages=${manifest.downloadedPageCount}/${manifest.pageCount}`)
      return manifest
    } catch (error) {
      void error
      manifest.status = manifest.downloadedPageCount > 0 ? OfflineDownloadStatus.PARTIAL : OfflineDownloadStatus.FAILED
      manifest.failureReasonCode = 'page_fetch_failed'
      manifest = this.store.saveManifest(manifest)
      console.warn(`[ReaderOffline] step=download_failed comic=${createOfflineDownloadStableHash(comic.id)} chapter=${createOfflineDownloadStableHash(chapterId)} pages=${manifest.downloadedPageCount}/${manifest.pageCount} reason=page_fetch_failed`)
      return manifest
    }
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
