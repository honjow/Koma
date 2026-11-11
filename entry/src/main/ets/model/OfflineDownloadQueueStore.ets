import { BackupRestoreActivity } from './BackupRestoreActivity'
import { writeAppTextFile } from './AppFileTextPersistence'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { fileIo as fs } from '@kit.CoreFileKit'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { Chapter, Comic, ComicId } from './ComicModels'
import {
  OFFLINE_DOWNLOAD_ROOT_DIR_NAME,
  OfflineChapterDownloadManifest,
  OfflineDownloadedChapterStatus,
  OfflineDownloadManifestValidation,
  OfflineDownloadStatus,
  OfflineDownloadStore,
  OfflineDownloadValidationOptions,
  assertSafeOfflineDownloadRoot,
} from './OfflineDownloadStore'

export const OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION: number = 1
const OFFLINE_DOWNLOAD_QUEUE_FILE_NAME: string = 'queue.v1.json'
export const PUBLIC_CONTENT_QUEUE_PRIVATE_PATH: string = 'download-queue/queue.v1.json'
export const OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS: number[] = [1, 2, 3]
const OFFLINE_DOWNLOAD_QUEUE_PROGRESS_INTERVAL_MS: number = 1000
export const DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES: OfflineDownloadQueuePreferences = {
  foregroundConcurrencyLimit: 1,
  isPaused: false,
  wifiOnly: false,
}
export const OFFLINE_DOWNLOAD_FAILURE_REASON_CODES: string[] = [
  'paused',
  'wifi_only',
  'offline',
  'download_interrupted',
  'manifest_missing',
  'manifest_malformed',
  'manifest_unavailable',
  'manifest_validation_failed',
  'identity_mismatch',
  'status_invalid',
  'status_not_reader_ready',
  'integrity_missing',
  'integrity_mismatch',
  'downloaded_count_mismatch',
  'page_count_empty',
  'pages_missing',
  'source_not_installed',
  'source_lookup_failed',
  'source_disabled',
  'source_login_required',
  'source_pages_failed',
  'unsafe_page_path',
  'outside_chapter_dir',
  'page_index_invalid',
  'page_size_mismatch',
  'page_hash_mismatch',
  'page_file_missing',
  'comic_missing',
  'chapter_missing',
  'page_fetch_failed',
  'cancel_cleanup_failed',
]

export interface OfflineDownloadTaskId {
  comicId: ComicId
  chapterId: string
}

export interface OfflineDownloadQueueEntry extends OfflineDownloadTaskId {
  /** Resume on an eligible network. Older manually staged entries lack this flag. */
  automatic?: boolean
  pausedByUser?: boolean
  canceling?: boolean
  requestId?: string
  sourceName?: string
  comicTitle?: string
  chapterTitle?: string
  status: OfflineDownloadStatus
  pageCount: number
  downloadedPageCount: number
  updatedAt: number
  failureReasonCode?: string
}

export function offlineDownloadTaskKey(task: OfflineDownloadTaskId): string {
  return JSON.stringify([task.comicId, task.chapterId])
}

export function isOfflineDownloadDeferred(reason?: string): boolean {
  return reason === 'paused' || reason === 'wifi_only' || reason === 'offline' || reason === 'download_interrupted'
}

export function isOfflineDownloadTaskPending(entry: OfflineDownloadQueueEntry): boolean {
  return !entry.canceling && entry.status !== OfflineDownloadStatus.DOWNLOADED &&
    (entry.status === OfflineDownloadStatus.QUEUED || entry.status === OfflineDownloadStatus.DOWNLOADING ||
      isOfflineDownloadDeferred(entry.failureReasonCode))
}

export function isOfflineDownloadTaskRetryable(entry: OfflineDownloadQueueEntry): boolean {
  // Book and chapter availability is checked against the current library by
  // the caller; old missing-record errors can outlive the repair.
  return !entry.canceling && !entry.pausedByUser && entry.status !== OfflineDownloadStatus.DOWNLOADED &&
    !isOfflineDownloadTaskPending(entry) && entry.failureReasonCode !== 'cancel_cleanup_failed'
}

let requestSerial: number = 0

function newOfflineDownloadRequestId(): string {
  requestSerial += 1
  return `${Date.now()}:${requestSerial}`
}

export interface OfflineDownloadQueuePreferences {
  foregroundConcurrencyLimit: number
  isPaused: boolean
  wifiOnly: boolean
}

export interface OfflineDownloadQueueSnapshot {
  entries: OfflineDownloadQueueEntry[]
  preferences: OfflineDownloadQueuePreferences
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

export interface OfflineDownloadQueueRecoverySummary {
  scannedCount: number
  restoredCount: number
  updatedCount: number
  downloadedCount: number
  partialCount: number
  failedCount: number
  skippedCount: number
}

interface OfflineDownloadQueueDocument {
  schemaVersion: number
  preferences?: OfflineDownloadQueuePreferences
  entries: OfflineDownloadQueueEntry[]
}

interface OfflineDownloadQueueReconcileResult {
  entries: OfflineDownloadQueueEntry[]
  changed: boolean
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

function legacyDownloadQueuePath(contentBase: string): string {
  return joinPath(joinPath(contentBase, OFFLINE_DOWNLOAD_ROOT_DIR_NAME), OFFLINE_DOWNLOAD_QUEUE_FILE_NAME)
}

// There is one system-provided public content directory. Its queue is durable
// app data, separate from the sandbox download fallback and the chapter index.
export function offlineDownloadQueuePath(contentBase: string, appFilesDir: string): string {
  return trimTrailingSlash(contentBase) === trimTrailingSlash(appFilesDir) ? legacyDownloadQueuePath(appFilesDir) :
    joinPath(appFilesDir, PUBLIC_CONTENT_QUEUE_PRIVATE_PATH)
}

export function readableOfflineDownloadQueuePath(contentBase: string, appFilesDir: string): string {
  const privatePath = offlineDownloadQueuePath(contentBase, appFilesDir)
  return fs.accessSync(privatePath) ? privatePath : legacyDownloadQueuePath(contentBase)
}


function ensureDirSync(path: string): void {
  if (!fs.accessSync(path)) {
    fs.mkdirSync(path, true)
  }
}



function normalizeCount(value: number): number {
  return Math.max(0, Math.floor(value))
}

export function normalizeOfflineDownloadFailureReasonCode(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  return OFFLINE_DOWNLOAD_FAILURE_REASON_CODES.indexOf(value) >= 0 ? value : undefined
}

function normalizeEntry(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
  const next: OfflineDownloadQueueEntry = {
    automatic: entry.automatic === true ? true : undefined,
    pausedByUser: entry.pausedByUser === true && entry.status !== OfflineDownloadStatus.DOWNLOADED ? true : undefined,
    canceling: entry.canceling === true ? true : undefined,
    requestId: typeof entry.requestId === 'string' ? entry.requestId : undefined,
    sourceName: typeof entry.sourceName === 'string' && entry.sourceName.length > 0 ? entry.sourceName : undefined,
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
  const failureReasonCode = normalizeOfflineDownloadFailureReasonCode(entry.failureReasonCode)
  if (failureReasonCode !== undefined) {
    next.failureReasonCode = failureReasonCode
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
      wifiOnly: DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.wifiOnly,
    }
  }
  return {
    foregroundConcurrencyLimit: normalizeForegroundConcurrencyLimit(preferences.foregroundConcurrencyLimit),
    isPaused: preferences.isPaused === true,
    wifiOnly: preferences.wifiOnly === true,
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
  return entry.status === OfflineDownloadStatus.DOWNLOADING ||
    entry.status === OfflineDownloadStatus.DOWNLOADED ||
    entry.status === OfflineDownloadStatus.PARTIAL
}

function isSameEntry(left: OfflineDownloadQueueEntry, right: OfflineDownloadQueueEntry): boolean {
  return left.status === right.status &&
    left.automatic === right.automatic &&
    left.sourceName === right.sourceName &&
    left.pageCount === right.pageCount &&
    left.downloadedPageCount === right.downloadedPageCount &&
    left.failureReasonCode === right.failureReasonCode
}

function entryFromManifestValidation(validation: OfflineDownloadManifestValidation): OfflineDownloadQueueEntry | undefined {
  const manifest = validation.manifest
  if (manifest === undefined) {
    return undefined
  }
  let status = OfflineDownloadStatus.FAILED
  let failureReasonCode = validation.reasonCode
  let pageCount = validation.pageCount
  let downloadedPageCount = validation.availablePageCount
  if (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED) {
    status = OfflineDownloadStatus.DOWNLOADED
    failureReasonCode = undefined
  } else if (validation.status === OfflineDownloadedChapterStatus.PARTIAL) {
    status = OfflineDownloadStatus.PARTIAL
    failureReasonCode = validation.reasonCode ?? 'page_file_missing'
  } else if (validation.status === OfflineDownloadedChapterStatus.MISSING &&
    validation.reasonCode === 'status_not_reader_ready') {
    if (manifest.status === OfflineDownloadStatus.DOWNLOADING) {
      status = OfflineDownloadStatus.FAILED
      failureReasonCode = 'download_interrupted'
    } else {
      status = manifest.status
      failureReasonCode = manifest.failureReasonCode ?? validation.reasonCode
    }
    pageCount = manifest.pageCount
    downloadedPageCount = manifest.downloadedPageCount
  }
  return normalizeEntry({
    comicId: manifest.comicId,
    chapterId: manifest.chapterId,
    comicTitle: manifest.comicTitle,
    chapterTitle: manifest.chapterTitle,
    sourceName: manifest.sourceName,
    status,
    pageCount,
    downloadedPageCount,
    updatedAt: manifest.updatedAt,
    failureReasonCode,
  })
}

export class OfflineDownloadQueueStore {
  private readonly filesDir: string
  private readonly runtimeKeyValue: string
  private readonly legacyQueuePath: string
  private readonly queuePath: string
  private lastProgressPersistedAt: number = 0

  constructor(filesDir: string, runtimeKey?: string) {
    this.filesDir = trimTrailingSlash(filesDir)
    this.runtimeKeyValue = trimTrailingSlash(runtimeKey ?? filesDir)
    this.legacyQueuePath = legacyDownloadQueuePath(this.filesDir)
    this.queuePath = offlineDownloadQueuePath(this.filesDir, this.runtimeKeyValue)
    assertSafeOfflineDownloadRoot(this.filesDir, this.legacyQueuePath)
  }

  runtimeKey(): string {
    return this.runtimeKeyValue
  }

  fromManifest(
    manifest: OfflineChapterDownloadManifest,
    comicTitle?: string,
    chapterTitle?: string
  ): OfflineDownloadQueueEntry {
    const entry: OfflineDownloadQueueEntry = {
      comicId: manifest.comicId,
      chapterId: manifest.chapterId,
      comicTitle: comicTitle ?? manifest.comicTitle,
      sourceName: manifest.sourceName,
      chapterTitle: chapterTitle ?? manifest.chapterTitle,
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

  loadSnapshot(): OfflineDownloadQueueSnapshot {
    const document: OfflineDownloadQueueDocument = this.loadDocument()
    return { entries: document.entries, preferences: normalizePreferences(document.preferences) }
  }

  /** Merge the old sandbox queue without allowing an older legacy row to replace current progress. */
  mergeFromLegacy(legacy: OfflineDownloadQueueStore): void {
    const current = this.loadDocument()
    const currentExists = fs.accessSync(this.queuePath)
    const previous = legacy.loadDocument()
    const entries = current.entries.slice()
    previous.entries.forEach((entry: OfflineDownloadQueueEntry): void => {
      const index = entries.findIndex((item: OfflineDownloadQueueEntry): boolean =>
        item.comicId === entry.comicId && item.chapterId === entry.chapterId)
      if (index < 0) {
        entries.push(entry)
      } else if (entry.updatedAt > entries[index].updatedAt) {
        entries[index] = entry
      }
    })
    this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: currentExists ? current.preferences : previous.preferences,
      entries,
    })
  }

  loadReconciledSnapshot(): OfflineDownloadQueueEntry[] {
    // Library filtering only needs file availability; do not scan every image on the UI thread.
    return this.reconciledEntries(this.loadDocument(), false, { validateContentHash: false }).entries
  }

  reconcileWithManifests(options?: OfflineDownloadValidationOptions): OfflineDownloadQueueEntry[] {
    const document = this.loadDocument()
    const result = this.reconciledEntries(document, true, options)
    if (result.changed) {
      this.saveDocument({
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: document.preferences,
        entries: result.entries,
      })
    }
    return result.changed ? result.entries : document.entries
  }

  private reconciledEntries(document: OfflineDownloadQueueDocument, persistManifestState: boolean,
    options?: OfflineDownloadValidationOptions): OfflineDownloadQueueReconcileResult {
    const store = new OfflineDownloadStore(this.filesDir, this.runtimeKeyValue)
    let changed = false
    const entries = document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => {
      if (entry.canceling || !shouldReconcileEntry(entry) ||
        OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId)) {
        return entry
      }
      const validation = persistManifestState ?
        store.reconcileDownloadedChapter(entry.comicId, entry.chapterId, options) :
        store.validateDownloadedChapter(entry.comicId, entry.chapterId, options)
      const next: OfflineDownloadQueueEntry = normalizeEntry({
        automatic: entry.automatic,
        pausedByUser: entry.pausedByUser,
        requestId: entry.requestId,
        sourceName: entry.sourceName,
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
        next.failureReasonCode = validation.manifest?.failureReasonCode ?? validation.reasonCode ?? 'page_file_missing'
      } else if (entry.status === OfflineDownloadStatus.DOWNLOADING &&
        validation.reasonCode === 'status_not_reader_ready') {
        next.status = OfflineDownloadStatus.FAILED
        next.failureReasonCode = 'download_interrupted'
      } else {
        next.status = OfflineDownloadStatus.FAILED
        next.failureReasonCode = validation.reasonCode === 'status_not_reader_ready' ?
          validation.manifest?.failureReasonCode ?? 'manifest_unavailable' :
          validation.reasonCode ?? 'manifest_unavailable'
      }
      if (!isSameEntry(entry, next)) {
        changed = true
      }
      return next
    })
    return { entries, changed }
  }

  async recoverFromManifests(): Promise<OfflineDownloadQueueRecoverySummary> {
    const store = new OfflineDownloadStore(this.filesDir, this.runtimeKeyValue)
    const scan = await store.scanDownloadedChapterManifests()
    const document = this.loadDocument()
    const entries = document.entries.slice()
    const summary: OfflineDownloadQueueRecoverySummary = {
      scannedCount: scan.scannedManifestCount,
      restoredCount: 0,
      updatedCount: 0,
      downloadedCount: 0,
      partialCount: 0,
      failedCount: 0,
      skippedCount: scan.skippedManifestCount,
    }
    let changed = false
    scan.validations.forEach((validation: OfflineDownloadManifestValidation) => {
      if (OfflineDownloadRuntime.isActive(this.runtimeKeyValue, validation.comicId, validation.chapterId)) {
        summary.skippedCount += 1
        return
      }
      const recovered = entryFromManifestValidation(validation)
      if (recovered === undefined) {
        summary.skippedCount += 1
        return
      }
      if (recovered.status === OfflineDownloadStatus.DOWNLOADED) {
        summary.downloadedCount += 1
      } else if (recovered.status === OfflineDownloadStatus.PARTIAL) {
        summary.partialCount += 1
      } else if (recovered.status === OfflineDownloadStatus.FAILED) {
        summary.failedCount += 1
      }
      const existingIndex = entries.findIndex((entry: OfflineDownloadQueueEntry): boolean => {
        return entry.comicId === recovered.comicId && entry.chapterId === recovered.chapterId
      })
      if (existingIndex < 0) {
        entries.unshift(recovered)
        summary.restoredCount += 1
        changed = true
        return
      }
      const existing = entries[existingIndex]
      if (existing.canceling || existing.updatedAt > recovered.updatedAt) {
        summary.skippedCount += 1
        return
      }
      const next = normalizeEntry({
        automatic: existing.automatic,
        pausedByUser: existing.pausedByUser,
        requestId: existing.requestId,
        sourceName: existing.sourceName ?? recovered.sourceName,
        comicId: existing.comicId,
        chapterId: existing.chapterId,
        comicTitle: existing.comicTitle,
        chapterTitle: existing.chapterTitle,
        status: recovered.status,
        pageCount: recovered.pageCount,
        downloadedPageCount: recovered.downloadedPageCount,
        updatedAt: recovered.updatedAt,
        failureReasonCode: recovered.failureReasonCode,
      })
      if (!isSameEntry(existing, next)) {
        entries[existingIndex] = next
        summary.updatedCount += 1
        changed = true
      }
    })
    if (changed) {
      this.saveDocument({
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: document.preferences,
        entries,
      })
    }
    return summary
  }

  loadSummary(): OfflineDownloadQueueSummary {
    return summarizeOfflineDownloadQueue(this.load())
  }

  loadPreferences(): OfflineDownloadQueuePreferences {
    return this.loadDocument().preferences ?? normalizePreferences()
  }

  savePreferences(preferences: OfflineDownloadQueuePreferences): OfflineDownloadQueuePreferences {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    return this.persistPreferences(preferences)
  }

  savePreferencesForBackupRestore(preferences: OfflineDownloadQueuePreferences): OfflineDownloadQueuePreferences {
    if (!BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_not_active')
    return this.persistPreferences(preferences)
  }

  private persistPreferences(preferences: OfflineDownloadQueuePreferences): OfflineDownloadQueuePreferences {
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
    const committed = this.savePreferences(preferences)
    OfflineDownloadRuntime.requestPause(this.runtimeKeyValue)
    return committed
  }

  resumeAllQueuedWork(): OfflineDownloadQueuePreferences {
    const preferences = this.loadPreferences()
    preferences.isPaused = false
    return this.savePreferences(preferences)
  }

  setWifiOnly(wifiOnly: boolean): OfflineDownloadQueuePreferences {
    const preferences = this.loadPreferences()
    preferences.wifiOnly = wifiOnly
    return this.savePreferences(preferences)
  }

  migratePublicQueue(): void {
    if (this.queuePath === this.legacyQueuePath || !fs.accessSync(this.legacyQueuePath)) return
    if (fs.accessSync(this.queuePath)) {
      this.readDocument(this.queuePath)
    } else {
      const document = this.readDocument(this.legacyQueuePath)
      this.persistDocument(document)
    }
    try {
      const tempPath = `${this.legacyQueuePath}.tmp`
      if (fs.accessSync(tempPath)) fs.unlinkSync(tempPath)
      fs.unlinkSync(this.legacyQueuePath)
      DiagnosticLogger.info('storage', 'public_download_queue_migrated', '')
    } catch (error) {
      DiagnosticLogger.exception('storage', 'public_download_queue_cleanup_failed', error as Error)
    }
  }

  private loadDocument(): OfflineDownloadQueueDocument {
    if (!fs.accessSync(this.queuePath)) {
      this.migratePublicQueue()
      if (!fs.accessSync(this.queuePath)) {
        return {
          schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
          preferences: normalizePreferences(),
          entries: [],
        }
      }
    }
    return this.readDocument(this.queuePath)
  }

  private readDocument(path: string): OfflineDownloadQueueDocument {
    try {
      const document = JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as OfflineDownloadQueueDocument
      if (document.schemaVersion !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION || !Array.isArray(document.entries)) {
        throw new Error('offline_download_queue_invalid')
      }
      return {
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: normalizePreferences(document.preferences),
        entries: document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry)),
      }
    } catch (_err) {
      throw new Error('offline_download_queue_read_failed')
    }
  }

  upsert(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
    return this.writeEntry(entry, false)
  }

  /** Intermediate page progress is checkpointed, not fsynced once per page. */
  upsertProgress(entry: OfflineDownloadQueueEntry): void {
    const now: number = Date.now()
    if (now - this.lastProgressPersistedAt < OFFLINE_DOWNLOAD_QUEUE_PROGRESS_INTERVAL_MS) {
      return
    }
    this.lastProgressPersistedAt = now
    this.writeEntry(entry, true)
  }

  private writeEntry(entry: OfflineDownloadQueueEntry, progressOnly: boolean): OfflineDownloadQueueEntry {
    const document = this.loadDocument()
    const previous = document.entries.find((item: OfflineDownloadQueueEntry): boolean =>
      item.comicId === entry.comicId && item.chapterId === entry.chapterId)
    const normalized = normalizeEntry({
      automatic: entry.automatic ?? previous?.automatic,
      pausedByUser: previous?.pausedByUser,
      canceling: previous?.canceling,
      requestId: previous?.requestId ?? entry.requestId,
      sourceName: entry.sourceName ?? previous?.sourceName,
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
    // The persisted array is the queue order. Progress writes replace the row in
    // place, otherwise each page completion would undo a user's reordering.
    const entries = document.entries.slice()
    const index = entries.findIndex((item: OfflineDownloadQueueEntry): boolean =>
      item.comicId === normalized.comicId && item.chapterId === normalized.chapterId)
    if (index < 0) entries.push(normalized)
    else entries[index] = normalized
    this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences,
      entries,
    }, progressOnly)
    return normalized
  }

  move(comicId: ComicId, chapterId: string, toTop: boolean, wholeComic: boolean = false): void {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    const document = this.loadDocument()
    const selected: OfflineDownloadQueueEntry[] = []
    const others: OfflineDownloadQueueEntry[] = []
    for (const entry of document.entries) {
      const matches = entry.comicId === comicId && (wholeComic || entry.chapterId === chapterId) &&
        isOfflineDownloadTaskPending(entry) && entry.status !== OfflineDownloadStatus.DOWNLOADING &&
        !OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId)
      if (matches) selected.push(entry)
      else others.push(entry)
    }
    if (selected.length === 0) return
    this.saveDocument({ schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: document.preferences,
      entries: toTop ? selected.concat(others) : others.concat(selected) })
  }

  addNewEntries(entries: OfflineDownloadQueueEntry[]): number {
    const document = this.loadDocument()
    const keys = new Set<string>(document.entries.map((entry: OfflineDownloadQueueEntry): string =>
      JSON.stringify([entry.comicId, entry.chapterId])))
    const added: OfflineDownloadQueueEntry[] = []
    entries.forEach((entry: OfflineDownloadQueueEntry) => {
      const normalized = normalizeEntry(entry)
      const key = JSON.stringify([normalized.comicId, normalized.chapterId])
      if (!keys.has(key)) {
        keys.add(key)
        normalized.requestId = newOfflineDownloadRequestId()
        added.push(normalized)
      }
    })
    if (added.length > 0) {
      this.saveDocument({
        schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
        preferences: document.preferences,
        entries: document.entries.concat(added),
      })
    }
    return added.length
  }

  /** Explicit chapter requests also start previously staged or failed entries. */
  requestChapters(comic: Comic, chapterIds: string[]): number {
    const document = this.loadDocument()
    const entries = new Map<string, OfflineDownloadQueueEntry>()
    document.entries.forEach((entry: OfflineDownloadQueueEntry) => {
      if (entry.comicId === comic.id) entries.set(entry.chapterId, entry)
    })
    const chapters = new Map<string, Chapter>()
    comic.chapters.forEach((chapter: Chapter) => { chapters.set(chapter.id, chapter) })
    const added: OfflineDownloadQueueEntry[] = []
    let count = 0
    new Set(chapterIds).forEach((id: string) => {
      const chapter = chapters.get(id)
      const entry = entries.get(id)
      if (chapter === undefined || entry?.canceling || entry?.pausedByUser ||
        entry?.status === OfflineDownloadStatus.DOWNLOADED ||
        entry?.status === OfflineDownloadStatus.DOWNLOADING ||
        OfflineDownloadRuntime.isActive(this.runtimeKeyValue, comic.id, id) ||
        OfflineDownloadRuntime.isRemovingChapter(this.runtimeKeyValue, comic.id, id)) return
      if (entry?.status === OfflineDownloadStatus.QUEUED && entry.automatic === true) return
      if (entry !== undefined) {
        entry.requestId = newOfflineDownloadRequestId()
        entry.automatic = true
        entry.status = OfflineDownloadStatus.QUEUED
        entry.failureReasonCode = undefined
      } else {
        added.push({ automatic: true, requestId: newOfflineDownloadRequestId(),
          comicId: comic.id, chapterId: id, comicTitle: comic.title,
          chapterTitle: chapter.title, status: OfflineDownloadStatus.QUEUED,
          pageCount: Math.max(chapter.pageCount, chapter.pages.length), downloadedPageCount: 0, updatedAt: Date.now() })
      }
      count++
    })
    if (count > 0) this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: document.preferences,
      entries: document.entries.concat(added),
    })
    return count
  }

  startStagedWork(): void {
    const document = this.loadDocument()
    let changed = false
    for (const entry of document.entries) {
      if (!entry.pausedByUser && entry.automatic !== true && isOfflineDownloadTaskPending(entry) &&
        entry.status !== OfflineDownloadStatus.DOWNLOADING) {
        entry.automatic = true
        changed = true
      }
    }
    if (changed) this.saveDocument(document)
  }

  setTasksPaused(targets: OfflineDownloadTaskId[], paused: boolean): number {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    const keys = new Set<string>(targets.map(offlineDownloadTaskKey))
    const document = this.loadDocument()
    const changed: OfflineDownloadQueueEntry[] = []
    for (const entry of document.entries) {
      if (!keys.has(offlineDownloadTaskKey(entry)) || !isOfflineDownloadTaskPending(entry) ||
        (entry.pausedByUser === true) === paused) continue
      entry.pausedByUser = paused ? true : undefined
      if (!paused) entry.automatic = true
      changed.push(entry)
    }
    if (changed.length > 0) {
      this.saveDocument(document)
      if (paused) {
        for (const entry of changed) {
          OfflineDownloadRuntime.requestChapterPause(this.runtimeKeyValue, entry.comicId, entry.chapterId)
        }
      }
    }
    return changed.length
  }

  retryTasks(targets: OfflineDownloadTaskId[]): number {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    const keys = new Set<string>(targets.map(offlineDownloadTaskKey))
    const document = this.loadDocument()
    let count = 0
    for (const entry of document.entries) {
      if (!keys.has(offlineDownloadTaskKey(entry)) || !isOfflineDownloadTaskRetryable(entry) ||
        OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId)) continue
      entry.requestId = newOfflineDownloadRequestId()
      entry.automatic = true
      entry.status = OfflineDownloadStatus.QUEUED
      entry.failureReasonCode = undefined
      count += 1
    }
    if (count > 0) this.saveDocument(document)
    return count
  }

  async cancelTasks(targets: OfflineDownloadTaskId[]): Promise<number> {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    const keys = new Set<string>(targets.map(offlineDownloadTaskKey))
    const document = this.loadDocument()
    const entries = document.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      keys.has(offlineDownloadTaskKey(entry)) && !entry.canceling && entry.status !== OfflineDownloadStatus.DOWNLOADED)
    if (entries.length === 0) return 0
    // Commit the whole scope before awaiting any transfer or touching any files.
    for (const entry of entries) entry.canceling = true
    this.saveDocument(document)
    for (const entry of entries) {
      OfflineDownloadRuntime.requestChapterPause(this.runtimeKeyValue, entry.comicId, entry.chapterId)
    }
    return await this.finishCanceledTasks(entries)
  }

  async finishCanceledTasks(entries: OfflineDownloadQueueEntry[] =
    this.load().filter((entry: OfflineDownloadQueueEntry): boolean => entry.canceling === true)): Promise<number> {
    if (entries.length === 0) return 0
    const removed = new Set<string>()
    const failed = new Set<string>()
    for (const entry of entries) {
      const key = offlineDownloadTaskKey(entry)
      try {
        await OfflineDownloadRuntime.removeChapterDownload(this.runtimeKeyValue, entry.comicId, entry.chapterId,
          async (): Promise<void> => {
            const store = new OfflineDownloadStore(this.filesDir, this.runtimeKeyValue)
            await store.deleteChapterDownload(entry.comicId, entry.chapterId)
          })
        removed.add(key)
      } catch (_error) {
        failed.add(key)
      }
    }
    const document = this.loadDocument()
    document.entries = document.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      if (!entry.canceling) return true
      const key = offlineDownloadTaskKey(entry)
      if (failed.has(key)) {
        entry.canceling = undefined
        entry.pausedByUser = undefined
        entry.status = OfflineDownloadStatus.FAILED
        entry.failureReasonCode = 'cancel_cleanup_failed'
      }
      return !removed.has(key)
    })
    this.saveDocument(document)
    return removed.size
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

  removeComic(comicId: ComicId): number {
    const document = this.loadDocument()
    const entries = document.entries.filter((item: OfflineDownloadQueueEntry): boolean => item.comicId !== comicId)
    const removedCount = document.entries.length - entries.length
    if (removedCount <= 0) {
      return 0
    }
    this.saveDocument({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences,
      entries,
    })
    return removedCount
  }

  async deleteChapterDownload(comicId: ComicId, chapterId: string): Promise<void> {
    await OfflineDownloadRuntime.removeChapterDownload(this.runtimeKeyValue, comicId, chapterId, async (): Promise<void> => {
      const store = new OfflineDownloadStore(this.filesDir, this.runtimeKeyValue)
      await store.deleteChapterDownload(comicId, chapterId)
      this.remove(comicId, chapterId)
    })
  }

  async deleteComicDownloads(comicId: ComicId): Promise<number> {
    return OfflineDownloadRuntime.removeComicDownloads(this.runtimeKeyValue, comicId, async (): Promise<number> => {
      const store = new OfflineDownloadStore(this.filesDir, this.runtimeKeyValue)
      await store.deleteComicDownloads(comicId)
      return this.removeComic(comicId)
    })
  }

  private persistDocument(document: OfflineDownloadQueueDocument): void {
    ensureDirSync(this.queuePath.substring(0, this.queuePath.lastIndexOf('/')))
    writeAppTextFile(this.queuePath, JSON.stringify({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences === undefined ? normalizePreferences() : normalizePreferences(document.preferences),
      entries: document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry)),
    }))
  }

  private saveDocument(document: OfflineDownloadQueueDocument, progressOnly: boolean = false): void {
    this.persistDocument(document)
    if (progressOnly) {
      OfflineDownloadRuntime.publishProgress(this.runtimeKeyValue)
    } else {
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
    }
  }

}
