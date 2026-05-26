import { fileIo as fs } from '@kit.CoreFileKit'
import {
  ComicId,
} from './ComicModels'
import {
  OFFLINE_DOWNLOAD_ROOT_DIR_NAME,
  OfflineChapterDownloadManifest,
  OfflineDownloadStatus,
  OfflineDownloadStore,
  assertSafeOfflineDownloadRoot,
} from './OfflineDownloadStore'

export const OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION: number = 1
export const OFFLINE_DOWNLOAD_QUEUE_FILE_NAME: string = 'queue.v1.json'
const OFFLINE_DOWNLOAD_QUEUE_TEMP_FILE_NAME: string = 'queue.v1.json.tmp'

export interface OfflineDownloadQueueEntry {
  comicId: ComicId
  chapterId: string
  comicTitle?: string
  chapterTitle?: string
  status: OfflineDownloadStatus
  pageCount: number
  downloadedPageCount: number
  updatedAt: number
  failureReasonCode?: string
}

interface OfflineDownloadQueueDocument {
  schemaVersion: number
  entries: OfflineDownloadQueueEntry[]
}

function normalizePath(value: string): string {
  return value.replace(/\\/g, '/').trim()
}

function trimTrailingSlash(value: string): string {
  let normalized = normalizePath(value)
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function joinPath(parent: string, child: string): string {
  const left = trimTrailingSlash(parent)
  const right = normalizePath(child).replace(/^\/+/, '').replace(/\/+$/, '')
  return right.length === 0 ? left : `${left}/${right}`
}

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function ensureDirSync(path: string): void {
  if (!fs.accessSync(path)) {
    fs.mkdirSync(path, true)
  }
}

function unlinkQuietly(path: string): void {
  try {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path)
    }
  } catch (_err) {
  }
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    fs.fsyncSync(file.fd)
  } finally {
    closeFileQuietly(file)
  }
}

function normalizeCount(value: number): number {
  return Math.max(0, Math.floor(value))
}

function normalizeEntry(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
  const next: OfflineDownloadQueueEntry = {
    comicId: entry.comicId,
    chapterId: entry.chapterId,
    status: entry.status,
    pageCount: normalizeCount(entry.pageCount),
    downloadedPageCount: normalizeCount(entry.downloadedPageCount),
    updatedAt: entry.updatedAt,
  }
  if (entry.comicTitle !== undefined && entry.comicTitle.length > 0) {
    next.comicTitle = entry.comicTitle
  }
  if (entry.chapterTitle !== undefined && entry.chapterTitle.length > 0) {
    next.chapterTitle = entry.chapterTitle
  }
  if (entry.failureReasonCode !== undefined && entry.failureReasonCode.length > 0) {
    next.failureReasonCode = entry.failureReasonCode
  }
  return next
}

export class OfflineDownloadQueueStore {
  private readonly filesDir: string
  private readonly rootDir: string
  private readonly queuePath: string

  constructor(filesDir: string) {
    this.filesDir = trimTrailingSlash(filesDir)
    this.rootDir = joinPath(this.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
    this.queuePath = joinPath(this.rootDir, OFFLINE_DOWNLOAD_QUEUE_FILE_NAME)
    this.ensureRoot()
  }

  fromManifest(
    manifest: OfflineChapterDownloadManifest,
    comicTitle?: string,
    chapterTitle?: string
  ): OfflineDownloadQueueEntry {
    const entry: OfflineDownloadQueueEntry = {
      comicId: manifest.comicId,
      chapterId: manifest.chapterId,
      comicTitle,
      chapterTitle,
      status: manifest.status,
      pageCount: manifest.pageCount,
      downloadedPageCount: manifest.downloadedPageCount,
      updatedAt: manifest.updatedAt,
      failureReasonCode: manifest.failureReasonCode,
    }
    return normalizeEntry(entry)
  }

  load(): OfflineDownloadQueueEntry[] {
    if (!fs.accessSync(this.queuePath)) {
      return []
    }
    try {
      const document = JSON.parse(fs.readTextSync(this.queuePath, { encoding: 'utf-8' })) as OfflineDownloadQueueDocument
      if (document.schemaVersion !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION || !Array.isArray(document.entries)) {
        return []
      }
      return document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry))
    } catch (_err) {
      return []
    }
  }

  upsert(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
    const normalized = normalizeEntry({
      comicId: entry.comicId,
      chapterId: entry.chapterId,
      comicTitle: entry.comicTitle,
      chapterTitle: entry.chapterTitle,
      status: entry.status,
      pageCount: entry.pageCount,
      downloadedPageCount: entry.downloadedPageCount,
      updatedAt: Date.now(),
      failureReasonCode: entry.failureReasonCode,
    })
    const entries = this.load().filter((item: OfflineDownloadQueueEntry): boolean => {
      return item.comicId !== normalized.comicId || item.chapterId !== normalized.chapterId
    })
    entries.unshift(normalized)
    this.saveDocument({ schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, entries })
    return normalized
  }

  remove(comicId: ComicId, chapterId: string): void {
    const entries = this.load().filter((item: OfflineDownloadQueueEntry): boolean => {
      return item.comicId !== comicId || item.chapterId !== chapterId
    })
    this.saveDocument({ schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, entries })
  }

  async deleteChapterDownload(comicId: ComicId, chapterId: string): Promise<void> {
    this.remove(comicId, chapterId)
    const store = new OfflineDownloadStore(this.filesDir)
    await store.deleteChapterDownload(comicId, chapterId)
  }

  private saveDocument(document: OfflineDownloadQueueDocument): void {
    assertSafeOfflineDownloadRoot(this.filesDir, this.queuePath)
    ensureDirSync(this.rootDir)
    const tempPath = joinPath(this.rootDir, OFFLINE_DOWNLOAD_QUEUE_TEMP_FILE_NAME)
    assertSafeOfflineDownloadRoot(this.filesDir, tempPath)
    writeTextSync(tempPath, JSON.stringify({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      entries: document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry)),
    }))
    try {
      // Harmony fileIo moveFileSync mode 0 replaces an existing app-sandbox file.
      fs.moveFileSync(tempPath, this.queuePath, 0)
    } finally {
      unlinkQuietly(tempPath)
    }
  }

  private ensureRoot(): void {
    assertSafeOfflineDownloadRoot(this.filesDir, this.queuePath)
    ensureDirSync(this.rootDir)
    void OfflineDownloadStatus.QUEUED
    void OfflineDownloadStatus.DOWNLOADING
    void OfflineDownloadStatus.DOWNLOADED
    void OfflineDownloadStatus.PARTIAL
    void OfflineDownloadStatus.FAILED
    void OfflineDownloadStatus.BLOCKED
  }
}
