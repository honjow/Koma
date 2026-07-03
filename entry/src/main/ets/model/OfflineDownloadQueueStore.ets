import { fileIo as fs } from '@kit.CoreFileKit'
import {
  ComicId,
} from './ComicModels'
import {
  OFFLINE_DOWNLOAD_ROOT_DIR_NAME,
  OfflineChapterDownloadManifest,
  OfflineDownloadedChapterStatus,
  OfflineDownloadStatus,
  OfflineDownloadStore,
  assertSafeOfflineDownloadRoot,
} from './OfflineDownloadStore'

export const OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION: number = 1
export const OFFLINE_DOWNLOAD_QUEUE_FILE_NAME: string = 'queue.v1.json'
export const OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS: number[] = [1, 2, 3]
export const DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES: OfflineDownloadQueuePreferences = {
  foregroundConcurrencyLimit: 1,
  isPaused: false,
}
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

export interface OfflineDownloadQueuePreferences {
  foregroundConcurrencyLimit: number
  isPaused: boolean
}

export interface OfflineDownloadQueueSummary {
  totalCount: number
  queuedCount: number
  downloadingCount: number
  downloadedCount: number
  partialCount: number
  failedCount: number
  blockedCount: number
  pageCount: number
  downloadedPageCount: number
}

interface OfflineDownloadQueueDocument {
  schemaVersion: number
  preferences?: OfflineDownloadQueuePreferences
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

function normalizeForegroundConcurrencyLimit(value: number): number {
  const normalized = Math.floor(value)
  return OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS.indexOf(normalized) >= 0 ?
    normalized :
    DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.foregroundConcurrencyLimit
}

function normalizePreferences(preferences?: OfflineDownloadQueuePreferences): OfflineDownloadQueuePreferences {
  if (preferences === undefined) {
    return {
      foregroundConcurrencyLimit: DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.foregroundConcurrencyLimit,
      isPaused: DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.isPaused,
    }
  }
  return {
    foregroundConcurrencyLimit: normalizeForegroundConcurrencyLimit(preferences.foregroundConcurrencyLimit),
    isPaused: preferences.isPaused === true,
  }
}

export function summarizeOfflineDownloadQueue(entries: OfflineDownloadQueueEntry[]): OfflineDownloadQueueSummary {
  const summary: OfflineDownloadQueueSummary = {
    totalCount: 0,
    queuedCount: 0,
    downloadingCount: 0,
    downloadedCount: 0,
    partialCount: 0,
    failedCount: 0,
    blockedCount: 0,
    pageCount: 0,
    downloadedPageCount: 0,
  }
  entries.forEach((entry: OfflineDownloadQueueEntry) => {
    const normalized = normalizeEntry(entry)
    summary.totalCount += 1
    summary.pageCount += normalized.pageCount
    summary.downloadedPageCount += Math.min(normalized.downloadedPageCount, normalized.pageCount)
    if (normalized.status === OfflineDownloadStatus.QUEUED) {
      summary.queuedCount += 1
    } else if (normalized.status === OfflineDownloadStatus.DOWNLOADING) {
      summary.downloadingCount += 1
    } else if (normalized.status === OfflineDownloadStatus.DOWNLOADED) {
      summary.downloadedCount += 1
    } else if (normalized.status === OfflineDownloadStatus.PARTIAL) {
      summary.partialCount += 1
    } else if (normalized.status === OfflineDownloadStatus.BLOCKED) {
      summary.blockedCount += 1
    } else {
      summary.failedCount += 1
    }
  })
  return summary
}

function shouldReconcileEntry(entry: OfflineDownloadQueueEntry): boolean {
  return entry.status === OfflineDownloadStatus.DOWNLOADED || entry.status === OfflineDownloadStatus.PARTIAL
}

function isSameEntry(left: OfflineDownloadQueueEntry, right: OfflineDownloadQueueEntry): boolean {
  return left.status === right.status &&
    left.pageCount === right.pageCount &&
    left.downloadedPageCount === right.downloadedPageCount &&
    left.failureReasonCode === right.failureReasonCode
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
    return this.loadDocument().entries
  }

  reconcileWithManifests(): OfflineDownloadQueueEntry[] {
    const document = this.loadDocument()
    const store = new OfflineDownloadStore(this.filesDir)
    let changed = false
    const entries = document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => {
      if (!shouldReconcileEntry(entry)) {
        return entry
      }
      const validation = store.validateDownloadedChapter(entry.comicId, entry.chapterId)
      const next: OfflineDownloadQueueEntry = normalizeEntry({
        comicId: entry.comicId,
        chapterId: entry.chapterId,
        comicTitle: entry.comicTitle,
        chapterTitle: entry.chapterTitle,
        status: entry.status,
        pageCount: validation.pageCount,
        downloadedPageCount: validation.availablePageCount,
        updatedAt: Date.now(),
        failureReasonCode: entry.failureReasonCode,
      })
      if (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED) {
        next.status = OfflineDownloadStatus.DOWNLOADED
        next.failureReasonCode = undefined
      } else if (validation.status === OfflineDownloadedChapterStatus.PARTIAL) {
        next.status = OfflineDownloadStatus.PARTIAL
        next.failureReasonCode = validation.reasonCode ?? 'page_file_missing'
      } else {
        next.status = OfflineDownloadStatus.FAILED
        next.failureReasonCode = validation.reasonCode ?? 'manifest_unavailable'
      }
      if (!isSameEntry(entry, next)) {
        changed = true
      }
      return next
    })
    if (changed) {
      this.saveDocument({
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: document.preferences,
        entries,
      })
    }
    return changed ? entries : document.entries
  }

  loadSummary(): OfflineDownloadQueueSummary {
    return summarizeOfflineDownloadQueue(this.load())
  }

  loadPreferences(): OfflineDownloadQueuePreferences {
    return this.loadDocument().preferences ?? normalizePreferences()
  }

  savePreferences(preferences: OfflineDownloadQueuePreferences): OfflineDownloadQueuePreferences {
    const document = this.loadDocument()
    const normalized = normalizePreferences(preferences)
    this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: normalized,
      entries: document.entries,
    })
    return normalized
  }

  setForegroundConcurrencyLimit(limit: number): OfflineDownloadQueuePreferences {
    const preferences = this.loadPreferences()
    preferences.foregroundConcurrencyLimit = normalizeForegroundConcurrencyLimit(limit)
    return this.savePreferences(preferences)
  }

  pauseAllQueuedWork(): OfflineDownloadQueuePreferences {
    const preferences = this.loadPreferences()
    preferences.isPaused = true
    return this.savePreferences(preferences)
  }

  resumeAllQueuedWork(): OfflineDownloadQueuePreferences {
    const preferences = this.loadPreferences()
    preferences.isPaused = false
    return this.savePreferences(preferences)
  }

  private loadDocument(): OfflineDownloadQueueDocument {
    if (!fs.accessSync(this.queuePath)) {
      return {
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: normalizePreferences(),
        entries: [],
      }
    }
    try {
      const document = JSON.parse(fs.readTextSync(this.queuePath, { encoding: 'utf-8' })) as OfflineDownloadQueueDocument
      if (document.schemaVersion !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION || !Array.isArray(document.entries)) {
        return {
          schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
          preferences: normalizePreferences(),
          entries: [],
        }
      }
      return {
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: normalizePreferences(document.preferences),
        entries: document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry)),
      }
    } catch (_err) {
      return {
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: normalizePreferences(),
        entries: [],
      }
    }
  }

  upsert(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
    const document = this.loadDocument()
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
    const entries = document.entries.filter((item: OfflineDownloadQueueEntry): boolean => {
      return item.comicId !== normalized.comicId || item.chapterId !== normalized.chapterId
    })
    entries.unshift(normalized)
    this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences,
      entries,
    })
    return normalized
  }

  remove(comicId: ComicId, chapterId: string): void {
    const document = this.loadDocument()
    const entries = document.entries.filter((item: OfflineDownloadQueueEntry): boolean => {
      return item.comicId !== comicId || item.chapterId !== chapterId
    })
    this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences,
      entries,
    })
  }

  async deleteChapterDownload(comicId: ComicId, chapterId: string): Promise<void> {
    const store = new OfflineDownloadStore(this.filesDir)
    await store.deleteChapterDownload(comicId, chapterId)
    this.remove(comicId, chapterId)
  }

  private saveDocument(document: OfflineDownloadQueueDocument): void {
    assertSafeOfflineDownloadRoot(this.filesDir, this.queuePath)
    ensureDirSync(this.rootDir)
    const tempPath = joinPath(this.rootDir, OFFLINE_DOWNLOAD_QUEUE_TEMP_FILE_NAME)
    assertSafeOfflineDownloadRoot(this.filesDir, tempPath)
    writeTextSync(tempPath, JSON.stringify({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences === undefined ? normalizePreferences() : normalizePreferences(document.preferences),
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
    void OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS
  }
}
