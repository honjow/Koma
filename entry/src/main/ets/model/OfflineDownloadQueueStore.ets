import { BackupRestoreActivity } from './BackupRestoreActivity'
import { writeAppTextFile } from './AppFileTextPersistence'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { Chapter, Comic, ComicId } from './ComicModels'
import { selectedChapterIdsInReadingOrder } from './ReaderChapterSequence'
import { sourceLibraryComicId } from './SourceLibraryComic'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from './UserDataDatabase'
import { UserKeyedRecords, writeUserRecords } from './UserKeyedRecords'
import { booleanColumn, booleanValue, LocalColumnValue, LocalDataRows, textColumn } from './LocalDataRows'
import type { relationalStore } from '@kit.ArkData'
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
export const SANDBOX_CONTENT_QUEUE_PATH: string = 'downloads/queue.v1.json'
export const OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS: number[] = [1, 2, 3]
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
  sourceId?: string
  sourceMangaId?: string
  sourceMangaUrl?: string
  comicTitle?: string
  chapterTitle?: string
  status: OfflineDownloadStatus
  pageCount: number
  downloadedPageCount: number
  updatedAt: number
  failureReasonCode?: string
}

export interface OfflineDownloadChapterBatch {
  comic: Comic
  chapterIds: string[]
  standalone?: boolean
  sourceMangaUrl?: string
}

export function hasOfflineDownloadSourceIdentity(entry: OfflineDownloadQueueEntry): boolean {
  return typeof entry.sourceId === 'string' && entry.sourceId.length > 0 &&
    typeof entry.sourceMangaId === 'string' && entry.sourceMangaId.length > 0 &&
    sourceLibraryComicId(entry.sourceId, entry.sourceMangaId) === entry.comicId
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

interface OfflineQueueRow {
  order: number
  entry: OfflineDownloadQueueEntry
}

const QUEUE_PREFERENCES_ROW = 'settings'
const QUEUE_NEXT_ORDER = 'next-order'
const QUEUE_TASK_PREFIX = 'chapter/'
const sqliteQueues = new Map<string, OfflineQueueRdbStorage>()

interface OfflineTaskRow {
  queueId: string
  occurrence: number
  order: number
  entry: OfflineDownloadQueueEntry
}

const INCOMPLETE_DOWNLOAD_SQL: string = 'queue_id = ? AND status <> ? AND (is_canceling IS NULL OR is_canceling = 0)'
const UNPAUSED_DOWNLOAD_SQL: string = ' AND (paused_by_user IS NULL OR paused_by_user = 0)'

const offlineTasks = new LocalDataRows<OfflineTaskRow>('offline_download_tasks',
  ['queue_id', 'comic_id', 'chapter_id', 'task_occurrence'], [
    'list_order', 'is_automatic', 'paused_by_user', 'is_canceling', 'request_id', 'source_name', 'source_id',
    'source_manga_id', 'source_manga_url', 'comic_title', 'chapter_title', 'status', 'page_count', 'downloaded_page_count',
    'updated_at', 'failure_reason_code',
  ], 'list_order',
  (row: OfflineTaskRow): LocalColumnValue[] => {
    const entry = row.entry
    return [row.queueId, entry.comicId, entry.chapterId, row.occurrence, row.order, booleanValue(entry.automatic),
      booleanValue(entry.pausedByUser), booleanValue(entry.canceling), entry.requestId ?? null, entry.sourceName ?? null,
      entry.sourceId ?? null, entry.sourceMangaId ?? null, entry.sourceMangaUrl ?? null, entry.comicTitle ?? null,
      entry.chapterTitle ?? null, entry.status, entry.pageCount, entry.downloadedPageCount, entry.updatedAt,
      entry.failureReasonCode ?? null]
  },
  (row: relationalStore.ResultSet): OfflineTaskRow => ({
    queueId: row.getString(0), occurrence: row.getLong(3), order: row.getLong(4),
    entry: { comicId: row.getString(1), chapterId: row.getString(2), automatic: booleanColumn(row, 5),
      pausedByUser: booleanColumn(row, 6), canceling: booleanColumn(row, 7), requestId: textColumn(row, 8),
      sourceName: textColumn(row, 9), sourceId: textColumn(row, 10), sourceMangaId: textColumn(row, 11),
      sourceMangaUrl: textColumn(row, 12), comicTitle: textColumn(row, 13), chapterTitle: textColumn(row, 14),
      status: row.getString(15) as OfflineDownloadStatus, pageCount: row.getLong(16), downloadedPageCount: row.getLong(17),
      updatedAt: row.getLong(18), failureReasonCode: textColumn(row, 19) },
  }))

interface QueueStateRow {
  queueId: string
  nextOrder: number
  preferences: OfflineDownloadQueuePreferences
}

const offlineQueueState = new LocalDataRows<QueueStateRow>('offline_download_queues', ['queue_id'],
  ['next_order', 'concurrency_limit', 'is_paused', 'wifi_only'], 'queue_id',
  (row: QueueStateRow): LocalColumnValue[] => [row.queueId, row.nextOrder, row.preferences.foregroundConcurrencyLimit,
    booleanValue(row.preferences.isPaused), booleanValue(row.preferences.wifiOnly)],
  (row: relationalStore.ResultSet): QueueStateRow => ({
    queueId: row.getString(0), nextOrder: row.getLong(1),
    preferences: { foregroundConcurrencyLimit: row.getLong(2), isPaused: row.getLong(3) !== 0, wifiOnly: row.getLong(4) !== 0 },
  }))

class OfflineQueueRdbStorage {
  private readonly database: relationalStore.RdbStore
  private readonly queueId: string
  private readonly marker: string
  private readonly previous: UserKeyedRecords
  private migrated: boolean = false

  constructor(database: relationalStore.RdbStore, relativePath: string) {
    this.database = database
    this.queueId = relativePath
    this.marker = 'offline-download-relational/' + relativePath
    this.previous = new UserKeyedRecords(database, 'offline-queue/' + relativePath)
  }

  isMigrated(): boolean {
    if (!this.migrated) this.migrated = hasUserDataMigration(this.database, this.marker)
    return this.migrated
  }

  usesPreviousDatabase(): boolean {
    return this.previous.isMigrated()
  }

  migrate(document: OfflineDownloadQueueDocument | undefined): void {
    writeUserRecords(this.database, (): void => {
      if (hasUserDataMigration(this.database, this.marker)) return
      if (this.previous.isMigrated()) {
        const values = this.previous.entries()
        if (values !== undefined) {
          const rows: OfflineQueueRow[] = []
          values.forEach((value: string, key: string): void => {
            if (key.startsWith(QUEUE_TASK_PREFIX)) rows.push(JSON.parse(value) as OfflineQueueRow)
          })
          rows.sort((left: OfflineQueueRow, right: OfflineQueueRow): number => left.order - right.order)
          const prefs = values.get(QUEUE_PREFERENCES_ROW)
          this.replaceRows(rows, normalizePreferences(prefs === undefined ? undefined :
            JSON.parse(prefs) as OfflineDownloadQueuePreferences), Number(values.get(QUEUE_NEXT_ORDER) ?? '0'))
        }
      } else {
        this.replaceDocument(document)
      }
      markUserDataMigration(this.database, this.marker)
    })
    this.migrated = true
  }

  private state(): QueueStateRow | undefined {
    return offlineQueueState.read(this.database, 'queue_id = ?', [this.queueId])[0]
  }

  read(): OfflineDownloadQueueDocument | undefined {
    const state = this.state()
    if (state === undefined) return undefined
    return { schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: state.preferences,
      entries: offlineTasks.read(this.database, 'queue_id = ?', [this.queueId]).map((row: OfflineTaskRow) => row.entry) }
  }

  incompleteEntries(automaticOnly: boolean, includePaused: boolean): OfflineDownloadQueueEntry[] {
    let filter = INCOMPLETE_DOWNLOAD_SQL
    if (automaticOnly) filter += ' AND is_automatic = 1'
    if (!includePaused) filter += UNPAUSED_DOWNLOAD_SQL
    return offlineTasks.read(this.database, filter, [this.queueId, OfflineDownloadStatus.DOWNLOADED])
      .map((row: OfflineTaskRow): OfflineDownloadQueueEntry => row.entry)
  }

  findRunnableEntry(matches: (entry: OfflineDownloadQueueEntry) => boolean): OfflineDownloadQueueEntry | undefined {
    return offlineTasks.find(this.database, INCOMPLETE_DOWNLOAD_SQL + UNPAUSED_DOWNLOAD_SQL,
      [this.queueId, OfflineDownloadStatus.DOWNLOADED], (row: OfflineTaskRow): boolean => matches(row.entry))?.entry
  }

  private taskRow(task: OfflineDownloadTaskId): OfflineTaskRow | undefined {
    return offlineTasks.read(this.database, 'queue_id = ? AND comic_id = ? AND chapter_id = ? AND task_occurrence = 0',
      [this.queueId, task.comicId, task.chapterId])[0]
  }

  entry(task: OfflineDownloadTaskId): OfflineDownloadQueueEntry | undefined {
    return this.taskRow(task)?.entry
  }

  /** Keyed by `offlineDownloadTaskKey`, so batch callers can resolve a
   * requested chapter without reading the whole queue. */
  entryByKey(key: string): OfflineDownloadQueueEntry | undefined {
    const parsed = JSON.parse(key) as string[]
    if (!Array.isArray(parsed) || parsed.length !== 2) return undefined
    return this.entry({ comicId: parsed[0], chapterId: parsed[1] })
  }

  /** Resolve requested tasks without issuing one statement per chapter. */
  entriesByKeys(keys: Set<string>): Map<string, OfflineDownloadQueueEntry> {
    const found = new Map<string, OfflineDownloadQueueEntry>()
    if (keys.size === 0) return found
    if (keys.size <= 8) {
      keys.forEach((key: string): void => {
        const entry = this.entryByKey(key)
        if (entry !== undefined) found.set(key, entry)
      })
      return found
    }
    this.entriesInOrder().forEach((entry: OfflineDownloadQueueEntry): void => {
      const key = offlineDownloadTaskKey(entry)
      if (keys.has(key)) found.set(key, entry)
    })
    return found
  }

  /** Interrupted writers after a cold start: the only status whose meaning
   * depends on the previous process having finished its own work. */
  interruptedEntries(): OfflineDownloadQueueEntry[] {
    return offlineTasks.read(this.database, INCOMPLETE_DOWNLOAD_SQL + ' AND status = ?',
      [this.queueId, OfflineDownloadStatus.DOWNLOADED, OfflineDownloadStatus.DOWNLOADING])
      .map((row: OfflineTaskRow): OfflineDownloadQueueEntry => row.entry)
      .filter((entry: OfflineDownloadQueueEntry): boolean => !entry.canceling)
  }

  entriesInOrder(): OfflineDownloadQueueEntry[] {
    return offlineTasks.read(this.database, 'queue_id = ?', [this.queueId])
      .map((row: OfflineTaskRow): OfflineDownloadQueueEntry => row.entry)
  }

  entriesForComic(comicId: ComicId): OfflineDownloadQueueEntry[] {
    return offlineTasks.read(this.database, 'queue_id = ? AND comic_id = ?', [this.queueId, comicId])
      .map((row: OfflineTaskRow): OfflineDownloadQueueEntry => row.entry)
  }

  /** Staged rows keep the same eligibility as the document fallback. */
  stagedEntries(): OfflineDownloadQueueEntry[] {
    return offlineTasks.read(this.database, INCOMPLETE_DOWNLOAD_SQL +
      ' AND (paused_by_user IS NULL OR paused_by_user = 0) AND (is_automatic IS NULL OR is_automatic = 0)',
      [this.queueId, OfflineDownloadStatus.DOWNLOADED])
      .map((row: OfflineTaskRow): OfflineDownloadQueueEntry => row.entry)
      .filter((entry: OfflineDownloadQueueEntry): boolean =>
        isOfflineDownloadTaskPending(entry) && entry.status !== OfflineDownloadStatus.DOWNLOADING)
  }

  cancelingEntries(): OfflineDownloadQueueEntry[] {
    return offlineTasks.read(this.database, 'queue_id = ? AND is_canceling = 1', [this.queueId])
      .map((row: OfflineTaskRow): OfflineDownloadQueueEntry => row.entry)
  }

  preferences(): OfflineDownloadQueuePreferences {
    return normalizePreferences(this.state()?.preferences)
  }

  savePreferences(value: OfflineDownloadQueuePreferences): void {
    writeUserRecords(this.database, (): void => {
      offlineQueueState.put(this.database, { queueId: this.queueId, nextOrder: this.state()?.nextOrder ?? 0, preferences: value })
    })
  }

  saveEntry(entry: OfflineDownloadQueueEntry): void {
    writeUserRecords(this.database, (): void => {
      const previous = this.taskRow(entry)
      const state = this.state()
      const order = previous?.order ?? state?.nextOrder ?? 0
      if (previous === undefined) {
        offlineQueueState.put(this.database, { queueId: this.queueId, nextOrder: order + 1,
          preferences: normalizePreferences(state?.preferences) })
      }
      offlineTasks.put(this.database, { queueId: this.queueId, occurrence: 0, order, entry })
    })
  }

  /** Commit only the supplied rows. Structural queue edits must not rewrite every
   * historical chapter just to change one selection. */
  saveEntries(entries: OfflineDownloadQueueEntry[]): void {
    if (entries.length === 0) return
    writeUserRecords(this.database, (): void => {
      const state = this.state()
      const ranks = entries.length > 8 ? this.entryOrders() : undefined
      const rows: OfflineTaskRow[] = []
      let order = state?.nextOrder ?? 0
      entries.forEach((entry: OfflineDownloadQueueEntry): void => {
        const previousOrder = ranks === undefined ? this.taskRow(entry)?.order : ranks.get(offlineDownloadTaskKey(entry))
        rows.push({ queueId: this.queueId, occurrence: 0, order: previousOrder ?? order, entry: normalizeEntry(entry) })
        if (previousOrder === undefined) order += 1
      })
      offlineQueueState.put(this.database, { queueId: this.queueId, nextOrder: order,
        preferences: normalizePreferences(state?.preferences) })
      offlineTasks.putMany(this.database, rows)
    })
  }

  /** Persisted row order keyed by task, without decoding queue payload columns. */
  private entryOrders(): Map<string, number> {
    const rows = this.database.querySqlSync(
      'SELECT comic_id, chapter_id, list_order FROM offline_download_tasks WHERE queue_id = ?', [this.queueId])
    const orders = new Map<string, number>()
    try {
      while (rows.goToNextRow()) {
        orders.set(offlineDownloadTaskKey({ comicId: rows.getString(0), chapterId: rows.getString(1) }), rows.getLong(2))
      }
    } finally {
      rows.close()
    }
    return orders
  }

  removeEntries(entries: OfflineDownloadTaskId[]): void {
    if (entries.length === 0) return
    writeUserRecords(this.database, (): void => {
      entries.forEach((entry: OfflineDownloadTaskId): void => {
        this.removeEntryRow(entry)
      })
    })
  }

  removeEntryRow(entry: OfflineDownloadTaskId): void {
    offlineTasks.remove(this.database, [this.queueId, entry.comicId, entry.chapterId, 0])
  }

  removeComicEntries(comicId: ComicId): number {
    const previous = offlineTasks.read(this.database, 'queue_id = ? AND comic_id = ?', [this.queueId, comicId])
    if (previous.length === 0) return 0
    writeUserRecords(this.database, (): void => {
      offlineTasks.removeByColumn(this.database, 'queue_id', this.queueId, 'comic_id = ?', [comicId])
    })
    return previous.length
  }

  /** Publish a new persisted order without rewriting rows that already match it. */
  reorder(ordered: OfflineDownloadQueueEntry[]): void {
    const current = new Map<string, OfflineTaskRow>()
    offlineTasks.read(this.database, 'queue_id = ?', [this.queueId]).forEach((row: OfflineTaskRow): void => {
      current.set(offlineDownloadTaskKey(row.entry), row)
    })
    const updates: OfflineTaskRow[] = []
    ordered.forEach((entry: OfflineDownloadQueueEntry, order: number): void => {
      const row = current.get(offlineDownloadTaskKey(entry))
      if (row === undefined || row.order === order) return
      updates.push({ queueId: this.queueId, occurrence: row.occurrence, order, entry: row.entry })
    })
    if (updates.length === 0) return
    writeUserRecords(this.database, (): void => {
      offlineQueueState.put(this.database, { queueId: this.queueId, nextOrder: ordered.length,
        preferences: this.preferences() })
      offlineTasks.putMany(this.database, updates)
    })
  }

  save(document: OfflineDownloadQueueDocument | undefined): void {
    writeUserRecords(this.database, (): void => this.replaceDocument(document))
  }

  private replaceDocument(document: OfflineDownloadQueueDocument | undefined): void {
    if (document === undefined) {
      offlineTasks.replace(this.database, [], 'queue_id', this.queueId)
      offlineQueueState.replace(this.database, [], 'queue_id', this.queueId)
      return
    }
    const rows = document.entries.map((entry: OfflineDownloadQueueEntry, order: number): OfflineQueueRow =>
      ({ order, entry: normalizeEntry(entry) }))
    this.replaceRows(rows, normalizePreferences(document.preferences), rows.length)
  }

  private replaceRows(rows: OfflineQueueRow[], preferences: OfflineDownloadQueuePreferences, nextOrder: number): void {
    offlineQueueState.put(this.database, { queueId: this.queueId, nextOrder, preferences })
    const occurrences = new Map<string, number>()
    const tasks = rows.map((row: OfflineQueueRow): OfflineTaskRow => {
      const key = offlineDownloadTaskKey(row.entry)
      const occurrence = occurrences.get(key) ?? 0
      occurrences.set(key, occurrence + 1)
      return { queueId: this.queueId, occurrence, order: row.order, entry: row.entry }
    })
    offlineTasks.replace(this.database, tasks, 'queue_id', this.queueId)
  }
}

export async function prepareOfflineQueueDatabase(context: common.Context): Promise<void> {
  const database = await openUserDataDatabase(context)
  for (const path of [SANDBOX_CONTENT_QUEUE_PATH, PUBLIC_CONTENT_QUEUE_PRIVATE_PATH]) {
    const absolute = context.filesDir + '/' + path
    const queue = sqliteQueues.get(absolute) ?? new OfflineQueueRdbStorage(database, path)
    if (!queue.isMigrated() && queue.usesPreviousDatabase()) queue.migrate(undefined)
    sqliteQueues.set(absolute, queue)
  }
}

export function usesOfflineQueueDatabase(filesDir: string, path: string): boolean {
  return sqliteQueues.get(filesDir + '/' + path)?.isMigrated() === true
}

export function readOfflineQueueDatabaseSnapshot(filesDir: string, path: string): string | undefined {
  const value = sqliteQueues.get(filesDir + '/' + path)?.read()
  return value === undefined ? undefined : JSON.stringify(value)
}

export function restoreOfflineQueueDatabaseSnapshot(filesDir: string, path: string, content: string | undefined): void {
  const storage = sqliteQueues.get(filesDir + '/' + path)
  if (storage === undefined || !storage.isMigrated()) throw new Error('offline_download_queue_not_migrated')
  storage.save(content === undefined ? undefined : parseQueueDocument(content))
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

function parseQueueDocument(payload: string): OfflineDownloadQueueDocument {
  const document = JSON.parse(payload) as OfflineDownloadQueueDocument
  if (document.schemaVersion !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION || !Array.isArray(document.entries)) {
    throw new Error('offline_download_queue_invalid')
  }
  return { schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: normalizePreferences(document.preferences),
    entries: document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry)) }
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
  if (hasOfflineDownloadSourceIdentity(entry)) {
    next.sourceId = entry.sourceId
    next.sourceMangaId = entry.sourceMangaId
    next.sourceMangaUrl = typeof entry.sourceMangaUrl === 'string' && /^https?:\/\/[^\s/@?#]+(?:\/[^\s?#]*)?$/i
      .test(entry.sourceMangaUrl) ? entry.sourceMangaUrl : undefined
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

/** Queue status follows one manifest validation result. Shared by the startup
 * owner and the explicit rescan so both agree on interrupted downloads. */
function reconciledEntry(entry: OfflineDownloadQueueEntry,
  validation: OfflineDownloadManifestValidation): OfflineDownloadQueueEntry {
  const next: OfflineDownloadQueueEntry = normalizeEntry({
    automatic: entry.automatic,
    pausedByUser: entry.pausedByUser,
    requestId: entry.requestId,
    sourceName: entry.sourceName,
    sourceId: entry.sourceId,
    sourceMangaId: entry.sourceMangaId,
    sourceMangaUrl: entry.sourceMangaUrl,
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
  return next
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

interface CachedOfflineDownloadQueue {
  inode: bigint
  modifiedAt: bigint | number
  document: OfflineDownloadQueueDocument
}

export class OfflineDownloadQueueStore {
  private static readonly cachedDocuments = new Map<string, CachedOfflineDownloadQueue>()
  private readonly filesDir: string
  private readonly runtimeKeyValue: string
  private readonly legacyQueuePath: string
  private readonly queuePath: string

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

  loadAutomaticPendingEntries(includePaused: boolean = false): OfflineDownloadQueueEntry[] {
    const database = this.database()
    if (database !== undefined) return database.incompleteEntries(true, includePaused).filter(isOfflineDownloadTaskPending)
    return this.loadDocument(false).entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      entry.automatic === true && (includePaused || !entry.pausedByUser) && isOfflineDownloadTaskPending(entry))
  }

  loadRunnableEntries(): OfflineDownloadQueueEntry[] {
    const database = this.database()
    if (database !== undefined) return database.incompleteEntries(false, false)
    return this.loadDocument(false).entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      !entry.pausedByUser && !entry.canceling && entry.status !== OfflineDownloadStatus.DOWNLOADED)
  }

  findRunnableEntry(matches: (entry: OfflineDownloadQueueEntry) => boolean): OfflineDownloadQueueEntry | undefined {
    const database = this.database()
    if (database !== undefined) return database.findRunnableEntry(matches)
    return this.loadDocument(false).entries.find((entry: OfflineDownloadQueueEntry): boolean =>
      !entry.pausedByUser && !entry.canceling && entry.status !== OfflineDownloadStatus.DOWNLOADED && matches(entry))
  }

  loadTask(task: OfflineDownloadTaskId): OfflineDownloadQueueEntry | undefined {
    const database = this.database()
    if (database !== undefined) return database.entry(task)
    return this.loadDocument(false).entries.find((entry: OfflineDownloadQueueEntry): boolean =>
      entry.comicId === task.comicId && entry.chapterId === task.chapterId)
  }

  prepareDatabase(): void {
    this.database()
  }

  loadSnapshot(): OfflineDownloadQueueSnapshot {
    const document = this.loadDocument(false)
    return { entries: document.entries.slice(), preferences: normalizePreferences(document.preferences) }
  }

  /** One work's rows plus the queue preferences. Works with thousands of
   * chapters must not read every other work's queue history to paint state. */
  loadComicSnapshot(comicId: ComicId): OfflineDownloadQueueSnapshot {
    const storage = this.database()
    if (storage === undefined) {
      const document = this.loadDocument(false)
      return {
        entries: document.entries.filter((entry: OfflineDownloadQueueEntry): boolean => entry.comicId === comicId),
        preferences: normalizePreferences(document.preferences),
      }
    }
    return { entries: storage.entriesForComic(comicId), preferences: storage.preferences() }
  }

  exportSnapshotText(): string | undefined {
    const storage = this.database()
    if (storage !== undefined) {
      const document = storage.read()
      return document === undefined ? undefined : JSON.stringify(document)
    }
    const path = readableOfflineDownloadQueuePath(this.filesDir, this.runtimeKeyValue)
    return fs.accessSync(path) ? fs.readTextSync(path, { encoding: 'utf-8' }) : undefined
  }

  restoreSnapshotText(payload: string): void {
    this.persistDocument(parseQueueDocument(payload))
  }

  /** Full-document reconciliation kept for callers that own a whole queue
   * snapshot, such as backup import. Startup uses `reconcileInterruptedText`
   * so an ordinary launch does not pay for the entire history. */
  reconcileSnapshotText(payload: string): string | undefined {
    const document = parseQueueDocument(payload)
    const result = this.reconciledEntries(document, true, { validateContentHash: false, skipPageFiles: true })
    if (!result.changed) return undefined
    document.entries = result.entries
    return JSON.stringify(document)
  }

  /** Merge the old sandbox queue without allowing an older legacy row to replace current progress. */
  mergeFromLegacy(legacy: OfflineDownloadQueueStore): void {
    const current = this.loadDocument()
    const storage = this.database()
    const currentExists = storage !== undefined ? storage.read() !== undefined : fs.accessSync(this.queuePath)
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

  /** Startup only restores interrupted work. Finished chapters are validated
   * again when they are opened and by the explicit rescan, so reconciling the
   * whole history on every launch would add IO without changing the result. */
  entriesNeedingReconcile(): OfflineDownloadQueueEntry[] {
    const database = this.database()
    if (database !== undefined) {
      return database.interruptedEntries()
    }
    return this.loadDocument(false).entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      !entry.canceling && entry.status === OfflineDownloadStatus.DOWNLOADING &&
      !OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId))
  }

  /** Replace only the rows a startup reconciliation actually changed. */
  applyReconciledEntries(entries: OfflineDownloadQueueEntry[]): void {
    if (entries.length === 0) return
    const database = this.database()
    if (database !== undefined) {
      database.saveEntries(entries)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return
    }
    const document = this.loadDocument()
    const replacements = new Map<string, OfflineDownloadQueueEntry>()
    entries.forEach((entry: OfflineDownloadQueueEntry): void => {
      replacements.set(offlineDownloadTaskKey(entry), entry)
    })
    document.entries = document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry =>
      replacements.get(offlineDownloadTaskKey(entry)) ?? entry)
    this.saveDocument(document)
  }

  /** Worker-side startup reconciliation. The caller passes only interrupted
   * chapters, never the whole queue history. */
  reconcileInterruptedText(payload: string): string | undefined {
    const entries = JSON.parse(payload) as OfflineDownloadQueueEntry[]
    if (!Array.isArray(entries) || entries.length === 0) return undefined
    const store = new OfflineDownloadStore(this.filesDir, this.runtimeKeyValue)
    const changed: OfflineDownloadQueueEntry[] = []
    entries.forEach((entry: OfflineDownloadQueueEntry): void => {
      if (entry.canceling || !shouldReconcileEntry(entry) ||
        OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId)) return
      const validation = store.reconcileDownloadedChapter(entry.comicId, entry.chapterId, { validateContentHash: false })
      const next = reconciledEntry(entry, validation)
      if (!isSameEntry(entry, next)) changed.push(next)
    })
    return changed.length === 0 ? undefined : JSON.stringify(changed)
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
      const next = reconciledEntry(entry, validation)
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
        sourceId: existing.sourceId,
        sourceMangaId: existing.sourceMangaId,
        sourceMangaUrl: existing.sourceMangaUrl,
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
    const storage = this.database()
    if (storage !== undefined) return storage.preferences()
    return normalizePreferences(this.loadDocument(false).preferences)
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
    const normalized = normalizePreferences(preferences)
    const storage = this.database()
    if (storage !== undefined) {
      storage.savePreferences(normalized)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return normalized
    }
    const document = this.loadDocument()
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
    const storage = this.database()
    if (storage !== undefined) {
      // Selection and commit are complete before deleting the old public copy.
      storage.read()
    } else if (fs.accessSync(this.queuePath)) {
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

  private loadDocument(mutable: boolean = true): OfflineDownloadQueueDocument {
    const rows = this.database()
    if (rows !== undefined) return rows.read() ?? this.emptyQueue()
    if (!fs.accessSync(this.queuePath)) {
      this.migratePublicQueue()
      if (!fs.accessSync(this.queuePath)) return this.emptyQueue()
    }
    // Every queue writer replaces the document atomically, including restore
    // and TaskPool startup reconciliation. The inode follows those writes
    // without re-parsing the entire queue for each downloaded image.
    const stat = fs.statSync(this.queuePath)
    const modifiedAt = stat.mtimeNs ?? stat.mtime
    let snapshot = OfflineDownloadQueueStore.cachedDocuments.get(this.queuePath)
    if (snapshot === undefined || snapshot.inode !== stat.ino || snapshot.modifiedAt !== modifiedAt) {
      snapshot = { inode: stat.ino, modifiedAt, document: this.readDocument(this.queuePath) }
      OfflineDownloadQueueStore.cachedDocuments.set(this.queuePath, snapshot)
    }
    if (!mutable) return snapshot.document
    return {
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: snapshot.document.preferences,
      entries: snapshot.document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry =>
        normalizeEntry(entry)),
    }
  }

  private readDocument(path: string): OfflineDownloadQueueDocument {
    try {
      return parseQueueDocument(fs.readTextSync(path, { encoding: 'utf-8' }))
    } catch (_err) {
      throw new Error('offline_download_queue_read_failed')
    }
  }

  private emptyQueue(): OfflineDownloadQueueDocument {
    return { schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: normalizePreferences(), entries: [] }
  }

  private database(): OfflineQueueRdbStorage | undefined {
    const storage = sqliteQueues.get(this.queuePath)
    if (storage !== undefined && !storage.isMigrated()) {
      const source = readableOfflineDownloadQueuePath(this.filesDir, this.runtimeKeyValue)
      storage.migrate(fs.accessSync(source) ? this.readDocument(source) : undefined)
    }
    return storage
  }

  upsert(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
    return this.writeEntry(entry)
  }

  private writeEntry(entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry {
    const storage = this.database()
    const document = storage === undefined ? this.loadDocument() : undefined
    const previous = storage?.entry(entry) ?? document?.entries.find((item: OfflineDownloadQueueEntry): boolean =>
      item.comicId === entry.comicId && item.chapterId === entry.chapterId)
    const normalized = normalizeEntry({
      automatic: entry.automatic ?? previous?.automatic,
      pausedByUser: previous?.pausedByUser,
      canceling: previous?.canceling,
      requestId: previous?.requestId ?? entry.requestId,
      sourceName: entry.sourceName ?? previous?.sourceName,
      sourceId: entry.sourceId ?? previous?.sourceId,
      sourceMangaId: entry.sourceMangaId ?? previous?.sourceMangaId,
      sourceMangaUrl: entry.sourceMangaUrl ?? previous?.sourceMangaUrl,
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
    if (storage !== undefined) {
      storage.saveEntry(normalized)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue, entry.comicId)
      return normalized
    }
    if (document === undefined) throw new Error('offline_download_queue_missing')
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
    }, entry.comicId)
    return normalized
  }

  move(comicId: ComicId, chapterId: string, toTop: boolean, wholeComic: boolean = false): void {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    const database = this.database()
    const document = database === undefined ? this.loadDocument() : undefined
    const all = document === undefined ? database!.entriesInOrder() : document.entries
    const selected: OfflineDownloadQueueEntry[] = []
    const others: OfflineDownloadQueueEntry[] = []
    for (const entry of all) {
      const matches = entry.comicId === comicId && (wholeComic || entry.chapterId === chapterId) &&
        isOfflineDownloadTaskPending(entry) && entry.status !== OfflineDownloadStatus.DOWNLOADING &&
        !OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId)
      if (matches) selected.push(entry)
      else others.push(entry)
    }
    if (selected.length === 0) return
    const ordered = toTop ? selected.concat(others) : others.concat(selected)
    if (database !== undefined) {
      database.reorder(ordered)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return
    }
    this.saveDocument({ schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: document!.preferences,
      entries: ordered })
  }

  addNewEntries(entries: OfflineDownloadQueueEntry[]): number {
    const database = this.database()
    if (database !== undefined) {
      const added: OfflineDownloadQueueEntry[] = []
      entries.forEach((entry: OfflineDownloadQueueEntry) => {
        const normalized = normalizeEntry(entry)
        if (database.entry(normalized) !== undefined) return
        normalized.requestId = newOfflineDownloadRequestId()
        added.push(normalized)
      })
      if (added.length > 0) {
        database.saveEntries(added)
        OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      }
      return added.length
    }
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
  requestChapters(comic: Comic, chapterIds: string[], standalone: boolean = false, sourceMangaUrl?: string): number {
    return this.requestChapterBatches([{ comic, chapterIds, standalone, sourceMangaUrl }])
  }

  /** A selection across multiple works is published as one queue change. */
  requestChapterBatches(batches: OfflineDownloadChapterBatch[]): number {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    // Queue rows and the storage backend are chosen separately: the RDB owner
    // commits only requested chapters, while the JSON fallback still replaces
    // its single document.
    const database = this.database()
    const document = database === undefined ? this.loadDocument() : undefined
    const requestedKeys = new Set<string>()
    batches.forEach((batch: OfflineDownloadChapterBatch): void => {
      batch.chapterIds.forEach((id: string): void => {
        requestedKeys.add(offlineDownloadTaskKey({ comicId: batch.comic.id, chapterId: id }))
      })
    })
    const stored = database === undefined ?
      new Map<string, OfflineDownloadQueueEntry>(document!.entries
        .filter((entry: OfflineDownloadQueueEntry): boolean => requestedKeys.has(offlineDownloadTaskKey(entry)))
        .map((entry: OfflineDownloadQueueEntry): [string, OfflineDownloadQueueEntry] => [offlineDownloadTaskKey(entry), entry])) :
      database.entriesByKeys(requestedKeys)
    const added: OfflineDownloadQueueEntry[] = []
    const changed = new Map<string, OfflineDownloadQueueEntry>()
    let count = 0
    batches.forEach((batch: OfflineDownloadChapterBatch): void => {
      const comic = batch.comic
      const chapters = new Map(comic.chapters.map((chapter: Chapter): [string, Chapter] => [chapter.id, chapter]))
      const chapterIds = selectedChapterIdsInReadingOrder(comic.chapters, batch.chapterIds)
      chapterIds.forEach((id: string): void => {
        const chapter = chapters.get(id)
        const key = offlineDownloadTaskKey({ comicId: comic.id, chapterId: id })
        const entry = changed.get(key) ?? stored.get(key)
        if (chapter === undefined || entry?.canceling || entry?.pausedByUser ||
          entry?.status === OfflineDownloadStatus.DOWNLOADED ||
          entry?.status === OfflineDownloadStatus.DOWNLOADING ||
          OfflineDownloadRuntime.isActive(this.runtimeKeyValue, comic.id, id) ||
          OfflineDownloadRuntime.isRemovingChapter(this.runtimeKeyValue, comic.id, id)) return
        if (entry?.status === OfflineDownloadStatus.QUEUED && entry.automatic === true) return
        if (entry !== undefined) {
          if (batch.standalone) {
            entry.sourceId = comic.sourceRuntimeId
            entry.sourceMangaId = comic.remoteResourceId
            entry.sourceName = comic.sourceMetadata?.sourceName ?? entry.sourceName
            entry.sourceMangaUrl = batch.sourceMangaUrl ?? entry.sourceMangaUrl
          }
          entry.requestId = newOfflineDownloadRequestId()
          entry.automatic = true
          entry.status = OfflineDownloadStatus.QUEUED
          entry.failureReasonCode = undefined
          entry.updatedAt = Date.now()
          changed.set(key, entry)
        } else {
          const task: OfflineDownloadQueueEntry = { automatic: true, requestId: newOfflineDownloadRequestId(),
            comicId: comic.id, chapterId: id, comicTitle: comic.title,
            sourceId: batch.standalone ? comic.sourceRuntimeId : undefined,
            sourceMangaId: batch.standalone ? comic.remoteResourceId : undefined,
            sourceName: batch.standalone ? comic.sourceMetadata?.sourceName : undefined,
            sourceMangaUrl: batch.sourceMangaUrl,
            chapterTitle: chapter.title, status: OfflineDownloadStatus.QUEUED,
            pageCount: Math.max(chapter.pageCount, chapter.pages.length), downloadedPageCount: 0, updatedAt: Date.now() }
          added.push(task)
          changed.set(key, task)
        }
        count++
      })
    })
    if (count > 0) {
      if (database !== undefined) {
        const updates = Array.from(changed.values()).filter((entry: OfflineDownloadQueueEntry): boolean =>
          added.indexOf(entry) < 0)
        database.saveEntries(updates.concat(added))
        OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      } else {
        this.saveDocument({
          schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION, preferences: document!.preferences,
          entries: document!.entries.concat(added),
        })
      }
    }
    return count
  }

  startStagedWork(): void {
    const database = this.database()
    if (database !== undefined) {
      const staged = database.stagedEntries()
      if (staged.length === 0) return
      staged.forEach((entry: OfflineDownloadQueueEntry): void => { entry.automatic = true })
      database.saveEntries(staged)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return
    }
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
    const database = this.database()
    if (database !== undefined) {
      const changed: OfflineDownloadQueueEntry[] = []
      keys.forEach((key: string): void => {
        const entry = database.entryByKey(key)
        if (entry === undefined || !isOfflineDownloadTaskPending(entry) ||
          (entry.pausedByUser === true) === paused) return
        entry.pausedByUser = paused ? true : undefined
        if (!paused) entry.automatic = true
        entry.updatedAt = Date.now()
        changed.push(entry)
      })
      if (changed.length > 0) {
        database.saveEntries(changed)
        OfflineDownloadRuntime.publish(this.runtimeKeyValue)
        if (paused) {
          for (const entry of changed) {
            OfflineDownloadRuntime.requestChapterPause(this.runtimeKeyValue, entry.comicId, entry.chapterId)
          }
        }
      }
      return changed.length
    }
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
    const database = this.database()
    if (database !== undefined) {
      const changed: OfflineDownloadQueueEntry[] = []
      keys.forEach((key: string): void => {
        const entry = database.entryByKey(key)
        if (entry === undefined || !isOfflineDownloadTaskRetryable(entry) ||
          OfflineDownloadRuntime.isActive(this.runtimeKeyValue, entry.comicId, entry.chapterId)) return
        entry.requestId = newOfflineDownloadRequestId()
        entry.automatic = true
        entry.status = OfflineDownloadStatus.QUEUED
        entry.failureReasonCode = undefined
        entry.updatedAt = Date.now()
        changed.push(entry)
      })
      if (changed.length > 0) {
        database.saveEntries(changed)
        OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      }
      return changed.length
    }
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
    const database = this.database()
    if (database !== undefined) {
      const entries: OfflineDownloadQueueEntry[] = []
      keys.forEach((key: string): void => {
        const entry = database.entryByKey(key)
        if (entry !== undefined && !entry.canceling && entry.status !== OfflineDownloadStatus.DOWNLOADED) entries.push(entry)
      })
      if (entries.length === 0) return 0
      // Commit the whole scope before awaiting any transfer or touching any files.
      for (const entry of entries) entry.canceling = true
      database.saveEntries(entries)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      for (const entry of entries) {
        OfflineDownloadRuntime.requestChapterPause(this.runtimeKeyValue, entry.comicId, entry.chapterId)
      }
      return await this.finishCanceledTasks(entries)
    }
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

  async finishCanceledTasks(entries?: OfflineDownloadQueueEntry[]): Promise<number> {
    const database = this.database()
    if (database !== undefined) {
      const targets = entries ?? database.cancelingEntries()
      if (targets.length === 0) return 0
      return this.finishCanceledEntries(targets)
    }
    const targets = entries ?? this.load().filter((entry: OfflineDownloadQueueEntry): boolean => entry.canceling === true)
    if (targets.length === 0) return 0
    return this.finishCanceledEntries(targets)
  }

  private async finishCanceledEntries(entries: OfflineDownloadQueueEntry[]): Promise<number> {
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
    const database = this.database()
    if (database !== undefined) {
      const failedRows: OfflineDownloadQueueEntry[] = []
      entries.forEach((entry: OfflineDownloadQueueEntry): void => {
        const key = offlineDownloadTaskKey(entry)
        if (removed.has(key)) {
          database.removeEntries([entry])
        } else if (failed.has(key)) {
          const row = database.entry(entry)
          if (row === undefined) return
          row.canceling = undefined
          row.pausedByUser = undefined
          row.status = OfflineDownloadStatus.FAILED
          row.failureReasonCode = 'cancel_cleanup_failed'
          failedRows.push(row)
        }
      })
      if (failedRows.length > 0) database.saveEntries(failedRows)
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return removed.size
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
    const database = this.database()
    if (database !== undefined) {
      database.removeEntries([{ comicId, chapterId }])
      OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return
    }
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
    const database = this.database()
    if (database !== undefined) {
      const removedCount = database.removeComicEntries(comicId)
      if (removedCount > 0) OfflineDownloadRuntime.publish(this.runtimeKeyValue)
      return removedCount
    }
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
    const storage = this.database()
    if (storage !== undefined) {
      storage.save(document)
      return
    }
    ensureDirSync(this.queuePath.substring(0, this.queuePath.lastIndexOf('/')))
    writeAppTextFile(this.queuePath, JSON.stringify({
      schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
      preferences: document.preferences === undefined ? normalizePreferences() : normalizePreferences(document.preferences),
      entries: document.entries.map((entry: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => normalizeEntry(entry)),
    }))
  }

  private saveDocument(document: OfflineDownloadQueueDocument, comicId?: string): void {
    this.persistDocument(document)
    OfflineDownloadRuntime.publish(this.runtimeKeyValue, comicId)
  }

}
