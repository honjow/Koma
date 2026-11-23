import type { relationalStore } from '@kit.ArkData'
import { allowDeviceSyncReaderProgress, deviceSyncReadingAcknowledged, deviceSyncReadingActionAcknowledged,
  signalDeviceSyncChange, stageDeviceSyncReading, stageDeviceSyncReadingActions, SyncReadingCapture,
  SyncReadingActionCapture, SyncReadingSignal, SyncReadingSource } from '../deviceSync/DeviceSyncSignals'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { SourceTextOverlay, sourceTextOverlay } from './SourceTextOverlay'
import { SourceRequiredImageDecode, sourceRequiredImageDecode } from './SourceRequiredImageDecode'
import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceTextPage, sourceTextPage, SourceTextPageRequest, sourceTextPageRequest } from './SourceTextPageDescriptor'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { writeAppTextFile } from './AppFileTextPersistence'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { continuationChapterIds, firstReaderChapter, needsSourceCatalogChronology, readerChapterPickerChapters, ReaderChapterOpenIntent } from './ReaderChapterSequence'
import { chapterReadingSortFor } from './ChapterListPreferencesStore'
import {
  Chapter,
  ChapterId,
  Comic,
  ComicId,
  ComicSourceKind,
  ReaderSeriesFormat,
  ReadingProgress,
  currentComicReadingProgress,
  readerFormatFromTags,
  readingProgressPageIndex,
  isDeferredFolderArchiveChapter,
  Page,
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFailureDetails } from './SourceRuntimeError'
import { SourceReadHistoryEntry } from './SourceReaderSession'
import { MangaMigrationReadPlan, MangaMigrationReadState } from './SourceMangaMigration'
import { RemoteReadHistoryEntry, copyRemoteReadHistoryEntry } from './RemoteReaderSession'
import { ReadingSessionRecord } from './ReadingStatistics'
import { AppFilesChapterReadStatePersistenceAdapter, ChapterReadStateOverride } from './ChapterReadStateStore'
import { ReaderRdbStorage, ReaderSyncWorkScope, ShelfChapterFacts } from './ReaderRdbStorage'
import { openUserDataDatabase } from './UserDataDatabase'

export interface ChapterReadingState {
  comicId: ComicId
  chapterId: ChapterId
  sourceIdentity?: SyncReadingSource
  position?: ReadingProgress
  isRead: boolean
  bookmarked?: boolean
  updatedAt: number
}

export interface ReadingPresentationChange {
  revision: number
  comicIds: string[]
}

export interface ChapterReadMutation {
  comicId: ComicId
  chapterId: ChapterId
  isRead: boolean
}

export interface ChapterReadCommitResult {
  committed: boolean
  changedCount: number
}

export type ComicReadingState = 'unread' | 'reading' | 'completed'

function chapterStateKey(comicId: ComicId, chapterId: ChapterId): string {
  // An in-memory lookup only. The length keeps arbitrary source IDs
  // unambiguous without encoding a JSON array for every chapter row.
  return `${comicId.length}:${comicId}${chapterId}`
}

function copyReadingProgressWithTimestamp(progress: ReadingProgress): ReadingProgress {
  return {
    comicId: progress.comicId,
    chapterId: progress.chapterId,
    pageId: progress.pageId,
    pageIndex: progress.pageIndex,
    totalPages: progress.totalPages,
    progressRatio: progress.progressRatio,
    completed: progress.completed,
    updatedAt: Date.now(),
    columnMode: progress.columnMode,
  }
}

function copyReadingProgress(progress: ReadingProgress): ReadingProgress {
  return {
    comicId: progress.comicId,
    chapterId: progress.chapterId,
    pageId: progress.pageId,
    pageIndex: progress.pageIndex,
    totalPages: progress.totalPages,
    progressRatio: progress.progressRatio,
    completed: progress.completed,
    updatedAt: progress.updatedAt,
    columnMode: progress.columnMode,
  }
}

function copySourceReadHistoryEntry(entry: SourceReadHistoryEntry): SourceReadHistoryEntry | undefined {
  const comicId = entry.comicId.trim()
  const sourceId = entry.sourceId.trim()
  const mangaId = entry.mangaId.trim()
  const title = entry.title.trim()
  const chapterId = entry.chapterId.trim()
  if (comicId.length === 0 || sourceId.length === 0 || mangaId.length === 0 || title.length === 0 || chapterId.length === 0) {
    return undefined
  }
  const next: SourceReadHistoryEntry = {
    comicId,
    sourceId,
    mangaId,
    title,
    chapterId,
  }
  if (entry.readingFormat === 'manga' || entry.readingFormat === 'webtoon') next.readingFormat = entry.readingFormat
  const mangaUrl = entry.mangaUrl?.trim()
  if (mangaUrl !== undefined && mangaUrl.length > 0) {
    next.mangaUrl = mangaUrl
  }
  const coverUri = entry.coverUri?.trim()
  if (coverUri !== undefined && coverUri.length > 0) {
    next.coverUri = coverUri
  }
  const sourceName = entry.sourceName?.trim()
  if (sourceName !== undefined && sourceName.length > 0) {
    next.sourceName = sourceName
  }
  const chapterTitle = entry.chapterTitle?.trim()
  if (chapterTitle !== undefined && chapterTitle.length > 0) {
    next.chapterTitle = chapterTitle
  }
  return next
}

export enum ReaderMode {
  SINGLE_PAGE = 'single_page',
  DUAL_PAGE = 'double_page',
  VERTICAL_PAGE = 'vertical_page',
  CONTINUOUS_SCROLL = 'continuous_scroll',
}

export function getReaderModeLabel(mode: ReaderMode): string {
  if (mode === ReaderMode.DUAL_PAGE) {
    return AppStrings.get('reader_page_mode_double')
  }
  if (mode === ReaderMode.CONTINUOUS_SCROLL) {
    return AppStrings.get('reader_page_mode_continuous')
  }
  if (mode === ReaderMode.VERTICAL_PAGE) {
    return AppStrings.get('reader_page_mode_vertical_page')
  }
  return AppStrings.get('reader_page_mode_single')
}

export function sortedReaderChapters(chapters: Chapter[]): Chapter[] {
  return chapters.slice().sort((left: Chapter, right: Chapter): number => {
    return left.index - right.index
  })
}

/**
 * Source transports frequently use an opaque chapter id (for example
 * `ch:<uuid>`) and leave `title` empty.  That id must never become reader
 * chrome copy: prefer the source title, otherwise render the persisted
 * chapter sort key through the normal localized chapter label.
 */
function readerChapterDisplayTitle(chapter: Chapter): string {
  const title = chapter.title.trim()
  if (title.length > 0 && title !== chapter.id) {
    return title
  }
  const parsedSortKey = Number(chapter.sortKey)
  const ordinal = Number.isFinite(parsedSortKey) ? `${parsedSortKey}` : `${chapter.index + 1}`
  return AppStrings.get('library_update_chapter_fallback_title').replace('%s', ordinal)
}

export interface ReaderSessionConfig {
  comicId: ComicId
  chapterId: ChapterId
  /** Complete manual picker in the selected basis's forward order; includes
   * other editions and locked entries. Never use it to infer automatic adjacency. */
  chapterIds: string[]
  /** Verified forward reading sequence for the current chapter's edition. */
  continuationChapterIds?: string[]
  sourceChapterChronologyPending?: boolean
  chapterTitles?: string[]
  title?: string
  chapterTitle?: string
  readingFormat?: ReaderSeriesFormat
  totalPages: number
  /** The folder archive's page list is resolved by the reader after opening. */
  deferredLocalArchive?: boolean
  pageUris: string[]
  /** Original public image URIs retained by newer offline manifests, when available. */
  sourceOriginalImageUris?: (string | undefined)[]
  pageIds?: string[]
  pageWidths?: (number | undefined)[]
  pageHeights?: (number | undefined)[]
  pageTextOverlays?: (SourceTextOverlay | null | undefined)[]
  pageRequiredImageDecodes?: (SourceRequiredImageDecode | null | undefined)[]
  pageTextPages?: (SourceTextPage | null | undefined)[]
  pageTextRequests?: (SourceTextPageRequest | null | undefined)[]
  sourceRuntimeId?: string
  /** Route-local provider category; never persisted with history or progress. */
  sourceFailureReason?: string
  /** Sanitized route-local source failure; excluded from durable history/progress. */
  sourceFailure?: SourceFailureDetails
  sourceMangaUrl?: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
}

export const EMPTY_READER_SESSION_CONFIG: ReaderSessionConfig = {
  comicId: '',
  chapterId: '',
  chapterIds: [],
  totalPages: 0,
  pageUris: [],
  pageIds: [],
  pageWidths: [],
  pageHeights: [],
}

export function cloneReaderSessionConfig(config: ReaderSessionConfig): ReaderSessionConfig {
  return {
    comicId: config.comicId,
    chapterId: config.chapterId,
    chapterIds: config.chapterIds.slice(),
    continuationChapterIds: config.continuationChapterIds?.slice(),
    sourceChapterChronologyPending: config.sourceChapterChronologyPending,
    chapterTitles: config.chapterTitles?.slice(),
    title: config.title,
    chapterTitle: config.chapterTitle,
    readingFormat: config.readingFormat,
    totalPages: config.totalPages,
    deferredLocalArchive: config.deferredLocalArchive,
    pageUris: config.pageUris.slice(),
    sourceOriginalImageUris: config.sourceOriginalImageUris?.slice(),
    pageIds: config.pageIds?.slice(),
    pageWidths: config.pageWidths?.slice(),
    pageHeights: config.pageHeights?.slice(),
    pageTextOverlays: config.pageTextOverlays?.map((page: SourceTextOverlay | null | undefined): SourceTextOverlay | undefined =>
      page === undefined || page === null ? undefined : sourceTextOverlay(page)),
    pageRequiredImageDecodes: config.pageRequiredImageDecodes?.map((page: SourceRequiredImageDecode | null | undefined): SourceRequiredImageDecode | undefined =>
      page === undefined || page === null ? undefined : sourceRequiredImageDecode(page)),
    pageTextPages: config.pageTextPages?.map((page: SourceTextPage | null | undefined): SourceTextPage | undefined =>
      page === undefined || page === null ? undefined : sourceTextPage(page)),
    pageTextRequests: config.pageTextRequests?.map((page: SourceTextPageRequest | null | undefined): SourceTextPageRequest | undefined =>
      page === undefined || page === null ? undefined : sourceTextPageRequest(page)),
    sourceRuntimeId: config.sourceRuntimeId,
    sourceFailureReason: config.sourceFailureReason,
    sourceFailure: config.sourceFailure === undefined ? undefined : {
      reason: config.sourceFailure.reason, code: config.sourceFailure.code,
      status: config.sourceFailure.status, kind: config.sourceFailure.kind,
    },
    sourceMangaUrl: config.sourceMangaUrl,
    sourceKind: config.sourceKind,
    remoteServerId: config.remoteServerId,
  }
}

export interface ReaderSessionPersistenceAdapter {
  supportsPageTurnWrites?(): boolean
  activityDatabase?(): ReaderRdbStorage | undefined
  load(): ReadingProgress[]
  save(progress: ReadingProgress[]): void
  /** Optional same-document metadata channel for transient source history. */
  loadSourceHistory?(): SourceReadHistoryEntry[]
  saveSourceHistory?(history: SourceReadHistoryEntry[]): void
  loadRemoteHistory?(): RemoteReadHistoryEntry[]
  saveRemoteHistory?(history: RemoteReadHistoryEntry[]): void
  loadSnapshot?(): ReaderSessionDocumentSnapshot
  saveSnapshot?(snapshot: ReaderSessionDocumentSnapshot, pageTurns?: ChapterReadingState[]): void
  /** Serialize and stage a complete sibling off the UI thread; commit stays atomic. */
  saveSnapshotAsync?(snapshot: ReaderSessionDocumentSnapshot, token: number,
    pageTurns?: ChapterReadingState[]): Promise<string>
  commitSnapshotAsync?(token: string): void
  discardSnapshotAsync?(token: string): void
  /** Legacy data is readable while its normalized document still awaits commit. */
  requiresMigration?(): boolean
}

interface ReaderSessionPersistPlan {
  snapshot: ReaderSessionDocumentSnapshot
  syncPositions: SyncReadingCapture[]
  syncActions: SyncReadingActionCapture[]
}

export const READER_PROGRESS_PERSISTENCE_FILE_NAME: string = 'reader-sessions.v1.json'
const liveReaderStorage = new Map<string, ReaderRdbStorage>()

/** Open current data before recovery, but import the old file only after replaying old recovery logs. */
export async function prepareLiveReaderStorage(context: common.Context, migrate: boolean): Promise<void> {
  if (liveReaderStorage.has(context.filesDir)) return
  const storage = new ReaderRdbStorage(await openUserDataDatabase(context))
  if (!storage.migrated()) {
    const previousDatabase = storage.usesPreviousDatabase()
    if (!previousDatabase && !migrate) return
    try {
      // Migrate an authoritative database before checkpoint replay. Only a
      // file-backed domain waits for the legacy checkpoint to be restored.
      const snapshot = previousDatabase ? undefined : new AppFilesReaderSessionPersistenceAdapter(context.filesDir).loadSnapshot()
      await storage.migrate(snapshot)
      DiagnosticLogger.info('persistence', 'reader_rdb_migrated',
        previousDatabase ? 'source=database' : 'source=legacy_file')
    } catch (error) {
      DiagnosticLogger.exception('persistence', 'reader_rdb_migration_failed', error as Error)
      throw error as Error
    }
  }
  liveReaderStorage.set(context.filesDir, storage)
}

export function usesReaderDatabase(filesDir: string): boolean {
  return liveReaderStorage.has(filesDir)
}

export function readLiveReadingWork(filesDir: string, comicId: string): ReaderSessionDocumentSnapshot {
  const storage = liveReaderStorage.get(filesDir)
  if (storage === undefined) throw new Error('reader_database_unavailable')
  return storage.readWorkForSync(comicId)
}

export function readLiveReadingEdits(filesDir: string, scope: ReaderSyncWorkScope[]): ReaderSessionDocumentSnapshot {
  const storage = liveReaderStorage.get(filesDir)
  if (storage === undefined) throw new Error('reader_database_unavailable')
  return storage.readSyncEdits(scope)
}

export function readLiveMihonReading(filesDir: string, comicIds: string[]): ReaderSessionDocumentSnapshot {
  const storage = liveReaderStorage.get(filesDir)
  if (storage === undefined) throw new Error('reader_database_unavailable')
  return storage.readCatalogLinkReading(comicIds)
}

export function stageLiveMihonReading(filesDir: string, transaction: relationalStore.Transaction, comicIds: string[],
  reading: ReaderSessionDocumentSnapshot): Promise<void> {
  const storage = liveReaderStorage.get(filesDir)
  if (storage === undefined) throw new Error('reader_database_unavailable')
  return storage.stageCatalogLink(transaction, comicIds, reading)
}

export function writeLiveReadingEdits(filesDir: string, scope: ReaderSyncWorkScope[], reading: ReaderSessionDocumentSnapshot): void {
  const storage = liveReaderStorage.get(filesDir)
  if (storage === undefined) throw new Error('reader_database_unavailable')
  storage.writeSyncEdits(scope, reading)
}

export function publishLiveCloudReading(filesDir: string, scope: ReaderSyncWorkScope[]): void {
  const storage = liveReaderStorage.get(filesDir)
  if (storage === undefined) throw new Error('reader_database_unavailable')
  appReaderSessionStore(filesDir).applyCloudReading(storage, scope)
}

export function readLiveReaderSnapshot(filesDir: string): string | undefined {
  const storage = liveReaderStorage.get(filesDir)
  if (storage !== undefined) return serializeReaderSessionForDevice(storage.read())
  const path = normalizeReaderSessionFilePath(filesDir)
  return fs.accessSync(path) ? fs.readTextSync(path, { encoding: 'utf-8' }) : undefined
}

export function writeLiveReaderSnapshot(filesDir: string, payload?: string): void {
  const storage = liveReaderStorage.get(filesDir)
  if (storage !== undefined) {
    const snapshot: ReaderSessionDocumentSnapshot = payload === undefined ? { progress: [], sourceHistory: [], chapters: [] }
      : new AppFilesReaderSessionPersistenceAdapter(filesDir).loadSnapshot(payload)
    storage.save(snapshot)
    return
  }
  const path = normalizeReaderSessionFilePath(filesDir)
  if (payload !== undefined) writeAppTextFile(path, payload)
  else if (fs.accessSync(path)) fs.unlinkSync(path)
}
/**
 * v4 adds OPDS search intent to recent history without retaining signed URLs.
 * Optional readingSessions are additive facts; missing legacy records mean no measured duration.
 * Keep v1/v2 progress and v3 independent chapter positions/read facts readable.
 */
export const READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 4
const READER_PROGRESS_LEGACY_SCHEMA_VERSION = 1
export const READER_PROGRESS_PERSIST_DEBOUNCE_MS: number = 3000

interface ReaderSessionDocument {
  schemaVersion: number
  progress: ReadingProgress[]
  sourceHistory?: SourceReadHistoryEntry[]
  remoteHistory?: RemoteReadHistoryEntry[]
  chapters?: ChapterReadingState[]
  readingSessions?: ReadingSessionRecord[]
  syncPositions?: SyncReadingCapture[]
  syncActions?: SyncReadingActionCapture[]
}

interface LegacyChapterReadDocument {
  schemaVersion: number
  overrides: ChapterReadStateOverride[]
}

export interface ReaderSessionDocumentSnapshot {
  progress: ReadingProgress[]
  sourceHistory: SourceReadHistoryEntry[]
  remoteHistory?: RemoteReadHistoryEntry[]
  chapters: ChapterReadingState[]
  readingSessions?: ReadingSessionRecord[]
  syncPositions?: SyncReadingCapture[]
  syncActions?: SyncReadingActionCapture[]
}

function projectChapterCompletion(state: ChapterReadingState, progress: ReadingProgress | undefined): void {
  if (progress !== undefined && progress.comicId === state.comicId && progress.chapterId === state.chapterId) {
    progress.completed = state.isRead
  }
}

export function alignSnapshotChapterCompletion(snapshot: ReaderSessionDocumentSnapshot): ReaderSessionDocumentSnapshot {
  const states = new Map<string, ChapterReadingState>()
  snapshot.chapters.forEach((state: ChapterReadingState): void => {
    states.set(chapterStateKey(state.comicId, state.chapterId), state)
    projectChapterCompletion(state, state.position)
  })
  snapshot.progress.forEach((progress: ReadingProgress): void => {
    const state = states.get(chapterStateKey(progress.comicId, progress.chapterId))
    if (state !== undefined) projectChapterCompletion(state, progress)
  })
  return snapshot
}

function readerSessionSnapshot(document: ReaderSessionDocument): ReaderSessionDocumentSnapshot {
  const progress = Array.isArray(document.progress) ? document.progress : []
  const sourceHistory: SourceReadHistoryEntry[] = []
  if (Array.isArray(document.sourceHistory)) {
    document.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
      const copied = copySourceReadHistoryEntry(entry)
      if (copied !== undefined) sourceHistory.push(copied)
    })
  }
  const chapters: ChapterReadingState[] = (document.schemaVersion === 3 || document.schemaVersion === READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION) &&
    Array.isArray(document.chapters) ? document.chapters : progress.map((row: ReadingProgress): ChapterReadingState => ({
      comicId: row.comicId, chapterId: row.chapterId, position: row,
      isRead: row.completed === true, updatedAt: row.updatedAt,
    }))
  const remoteHistory: RemoteReadHistoryEntry[] = []
  if (Array.isArray(document.remoteHistory)) {
    document.remoteHistory.forEach((entry: RemoteReadHistoryEntry): void => {
      const copied = copyRemoteReadHistoryEntry(entry)
      if (copied !== undefined) remoteHistory.push(copied)
    })
  }
  return alignSnapshotChapterCompletion({ progress, sourceHistory, remoteHistory, chapters,
    readingSessions: document.readingSessions ?? [] })
}

/** Backup replacement never reads legacy overrides from the receiving device. */
export function normalizeReaderSessionBackupPayload(payload: string): string {
  const document = JSON.parse(payload) as ReaderSessionDocument
  if (document.schemaVersion !== 1 && document.schemaVersion !== 2 && document.schemaVersion !== 3 &&
    document.schemaVersion !== READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION) {
    throw new Error('Unsupported reader progress backup schema')
  }
  if (!Array.isArray(document.progress)) throw new Error('Invalid reader progress backup')
  const snapshot = readerSessionSnapshot(document)
  const normalized: ReaderSessionDocument = {
    schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
    progress: snapshot.progress, sourceHistory: snapshot.sourceHistory, chapters: snapshot.chapters,
    remoteHistory: snapshot.remoteHistory,
    readingSessions: snapshot.readingSessions,
  }
  return JSON.stringify(normalized)
}

/** Local outbox belongs to the same atomic commit as the corresponding page turn.
 * Backup export and replacement use the normalizer above, which omits it. */
export function serializeReaderSessionForDevice(snapshot: ReaderSessionDocumentSnapshot): string {
  const document: ReaderSessionDocument = {
    schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
    progress: snapshot.progress, sourceHistory: snapshot.sourceHistory, remoteHistory: snapshot.remoteHistory,
    chapters: snapshot.chapters, readingSessions: snapshot.readingSessions, syncPositions: snapshot.syncPositions,
    syncActions: snapshot.syncActions,
  }
  return JSON.stringify(document)
}

function normalizeReaderSessionFilePath(filesDir: string): string {
  let dir = filesDir.trim()
  while (dir.length > 1 && dir.endsWith('/')) {
    dir = dir.substring(0, dir.length - 1)
  }
  return dir.length === 0 ? READER_PROGRESS_PERSISTENCE_FILE_NAME : `${dir}/${READER_PROGRESS_PERSISTENCE_FILE_NAME}`
}

@Concurrent
function writeReaderSessionSnapshotTask(filePath: string, documentText: string,
  token: number, pageTurns?: ChapterReadingState[]): string {
  let payload = documentText
  if (pageTurns !== undefined) {
    const document = JSON.parse(documentText) as ReaderSessionDocument
    let previous: ReaderSessionDocument
    try {
      previous = JSON.parse(fs.readTextSync(filePath, { encoding: 'utf-8' })) as ReaderSessionDocument
    } catch (_error) {
      return ''
    }
    if (previous?.schemaVersion !== document.schemaVersion || !Array.isArray(previous.progress) ||
      !Array.isArray(previous.chapters)) return ''

    const progress = new Map<ComicId, ReadingProgress>()
    const chapters = new Map<string, ChapterReadingState>()
    const chapterKey = (row: ChapterReadingState): string => `${row.comicId.length}:${row.comicId}${row.chapterId}`
    previous.progress.forEach((row: ReadingProgress): void => { progress.set(row.comicId, row) })
    previous.chapters.forEach((row: ChapterReadingState): void => { chapters.set(chapterKey(row), row) })
    pageTurns.forEach((row: ChapterReadingState): void => {
      if (row.position === undefined) return
      progress.set(row.comicId, row.position)
      chapters.set(chapterKey(row), row)
    })
    previous.progress = Array.from(progress.values())
    previous.chapters = Array.from(chapters.values())
    previous.syncPositions = document.syncPositions
    previous.syncActions = document.syncActions
    payload = JSON.stringify(previous)
  }
  const tempPath = `${filePath}.tmp-${token}`
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(tempPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    fs.fsyncSync(file.fd)
    fs.closeSync(file)
    file = undefined
    if (fs.readTextSync(tempPath, { encoding: 'utf-8' }) !== payload) {
      throw new Error('reader_progress_incomplete_write')
    }
    return tempPath
  } catch (error) {
    try {
      if (file !== undefined) fs.closeSync(file)
    } catch (_error) {
    }
    try {
      if (fs.accessSync(tempPath)) fs.unlinkSync(tempPath)
    } catch (_error) {
    }
    throw error as Error
  }
}


export class AppFilesReaderSessionPersistenceAdapter implements ReaderSessionPersistenceAdapter {
  private readonly filePath: string
  private readonly filesDir: string
  private migrationPending: boolean = false
  private hasSnapshotBase: boolean = false
  private stagedDatabaseWrite?: ReaderDatabaseWrite

  constructor(filesDir: string) {
    this.filesDir = filesDir
    this.filePath = normalizeReaderSessionFilePath(filesDir)
  }

  load(): ReadingProgress[] {
    return this.loadDocument().progress
  }

  loadSourceHistory(): SourceReadHistoryEntry[] {
    return this.loadDocument().sourceHistory
  }

  loadRemoteHistory(): RemoteReadHistoryEntry[] {
    return this.loadDocument().remoteHistory ?? []
  }

  saveRemoteHistory(history: RemoteReadHistoryEntry[]): void {
    const document = this.loadDocument()
    document.remoteHistory = history
    this.saveDocument(document)
  }

  save(progress: ReadingProgress[]): void {
    const document = this.loadDocument()
    document.progress = progress
    this.saveDocument(document)
  }

  saveSourceHistory(history: SourceReadHistoryEntry[]): void {
    const document = this.loadDocument()
    document.sourceHistory = history
    this.saveDocument(document)
  }

  loadSnapshot(persistedText?: string | null): ReaderSessionDocumentSnapshot {
    return this.loadDocument(persistedText)
  }

  saveSnapshot(snapshot: ReaderSessionDocumentSnapshot, pageTurns?: ChapterReadingState[]): void {
    this.saveDocument(snapshot, pageTurns)
  }

  supportsPageTurnWrites(): boolean {
    return usesReaderDatabase(this.filesDir)
  }

  activityDatabase(): ReaderRdbStorage | undefined {
    return liveReaderStorage.get(this.filesDir)
  }

  async saveSnapshotAsync(snapshot: ReaderSessionDocumentSnapshot, token: number,
    pageTurns?: ChapterReadingState[]): Promise<string> {
    if (usesReaderDatabase(this.filesDir)) {
      const key = 'rdb:' + token
      this.stagedDatabaseWrite = { key, snapshot, pageTurns }
      return key
    }
    if (this.hasSnapshotBase && pageTurns !== undefined) {
      const delta: ReaderSessionDocument = { schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
        progress: [], syncPositions: snapshot.syncPositions, syncActions: snapshot.syncActions }
      const staged = await taskpool.execute(writeReaderSessionSnapshotTask, this.filePath,
        JSON.stringify(delta), token, pageTurns) as string
      if (staged.length > 0) return staged
    }
    const document: ReaderSessionDocument = {
      schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
      progress: snapshot.progress, sourceHistory: snapshot.sourceHistory, remoteHistory: snapshot.remoteHistory,
      chapters: snapshot.chapters, readingSessions: snapshot.readingSessions, syncPositions: snapshot.syncPositions,
      syncActions: snapshot.syncActions,
    }
    // The full fallback can contain all older history. Pass flat text rather
    // than making Taskpool copy its object graph on the reading thread.
    return taskpool.execute(writeReaderSessionSnapshotTask, this.filePath, JSON.stringify(document), token) as Promise<string>
  }

  commitSnapshotAsync(token: string): void {
    if (BackupRestoreActivity.hasPendingRecovery()) {
      this.discardSnapshotAsync(token)
      throw new Error('sync_local_busy')
    }
    try {
      const staged = this.stagedDatabaseWrite
      if (staged?.key === token) {
        const database = liveReaderStorage.get(this.filesDir)
        if (database === undefined) throw new Error('reader_database_unavailable')
        database.save(staged.snapshot, staged.pageTurns)
        this.stagedDatabaseWrite = undefined
        return
      }
      fs.renameSync(token, this.filePath)
      this.migrationPending = false
      this.hasSnapshotBase = true
    } catch (error) {
      this.discardSnapshotAsync(token)
      throw error as Error
    }
  }

  discardSnapshotAsync(token: string): void {
    if (token.startsWith('rdb:')) {
      if (this.stagedDatabaseWrite?.key === token) this.stagedDatabaseWrite = undefined
      return
    }
    try {
      if (fs.accessSync(token)) fs.unlinkSync(token)
    } catch (_error) {
    }
  }

  requiresMigration(): boolean {
    return this.migrationPending
  }

  private loadDocument(persistedText?: string | null): ReaderSessionDocumentSnapshot {
    this.hasSnapshotBase = false
    const database = liveReaderStorage.get(this.filesDir)
    if (persistedText === undefined && database !== undefined) return database.read()
    let document: ReaderSessionDocument
    try {
      const text = persistedText === undefined ?
        (fs.accessSync(this.filePath) ? fs.readTextSync(this.filePath, { encoding: 'utf-8' }) : null) : persistedText
      document = text !== null
        ? JSON.parse(text) as ReaderSessionDocument
        : { schemaVersion: READER_PROGRESS_LEGACY_SCHEMA_VERSION, progress: [] }
    } catch (_error) {
      throw new Error('reader_progress_load_failed')
    }
    if (document === null || typeof document !== 'object' || Array.isArray(document) ||
      !Array.isArray(document.progress)) {
      throw new Error('Invalid reader progress persistence document')
    }
    if (document.schemaVersion !== READER_PROGRESS_LEGACY_SCHEMA_VERSION && document.schemaVersion !== 2 && document.schemaVersion !== 3 &&
      document.schemaVersion !== READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION) {
      throw new Error(`Unsupported reader progress schema version: ${document.schemaVersion}`)
    }
    const snapshot = readerSessionSnapshot(document)
    snapshot.syncPositions = document.syncPositions
    snapshot.syncActions = document.syncActions
    if (document.schemaVersion !== READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION) {
      const legacyPayload = document.schemaVersion <= 2
        ? new AppFilesChapterReadStatePersistenceAdapter(this.filesDir).load() : undefined
      if (legacyPayload !== undefined && legacyPayload.length > 0) {
        const legacy = JSON.parse(legacyPayload) as LegacyChapterReadDocument
        if (legacy.schemaVersion === 1 && Array.isArray(legacy.overrides)) {
          legacy.overrides.forEach((row: ChapterReadStateOverride): void => {
            const found = snapshot.chapters.find((state: ChapterReadingState): boolean =>
              state.comicId === row.comicId && state.chapterId === row.chapterId)
            if (found !== undefined) {
              found.isRead = row.isRead
              found.updatedAt = row.updatedAt
            } else {
              snapshot.chapters.push({ comicId: row.comicId, chapterId: row.chapterId,
                isRead: row.isRead, updatedAt: row.updatedAt })
            }
          })
        }
      }
      // The store owns migration admission and retry; keep both original files until commit.
      alignSnapshotChapterCompletion(snapshot)
      this.migrationPending = true
    }
    return snapshot
  }

  private saveDocument(snapshot: ReaderSessionDocumentSnapshot, pageTurns?: ChapterReadingState[]): void {
    if (BackupRestoreActivity.hasPendingRecovery()) {
      throw new Error('sync_local_busy')
    }
    const database = liveReaderStorage.get(this.filesDir)
    if (database === undefined) writeAppTextFile(this.filePath, serializeReaderSessionForDevice(snapshot))
    else database.save(snapshot, pageTurns)
    this.migrationPending = false
    this.hasSnapshotBase = true
  }
}

interface ReaderDatabaseWrite {
  key: string
  snapshot: ReaderSessionDocumentSnapshot
  pageTurns?: ChapterReadingState[]
}

/** Complete in-memory reading state, used to seed or restore a session store. */
export interface ReaderSessionReadingSnapshot {
  progress: ReadingProgress[]
  sourceHistory: SourceReadHistoryEntry[]
  remoteHistory: RemoteReadHistoryEntry[]
  chapterStates: ChapterReadingState[]
  readingSessions: ReadingSessionRecord[]
}

export abstract class ReaderSessionStore {
  private readonly readingSessions = new Set<ReadingSessionRecord>()
  private readonly readingSessionsByComic = new Map<ComicId, Set<ReadingSessionRecord>>()

  listReadingSessions(): ReadingSessionRecord[] {
    this.prepareReadingSessions()
    return Array.from(this.readingSessions).map((record: ReadingSessionRecord): ReadingSessionRecord => ({
      comicId: record.comicId, chapterId: record.chapterId, startedAt: record.startedAt,
      endedAt: record.endedAt, pagesRead: record.pagesRead,
    }))
  }

  snapshotReadingState(): ReaderSessionReadingSnapshot {
    return {
      progress: this.listProgress(),
      sourceHistory: this.listSourceHistory(),
      remoteHistory: this.listRemoteHistory(),
      chapterStates: this.listChapterStates(),
      readingSessions: this.listReadingSessions(),
    }
  }

  /** Replace the shared chapter/remote/session state from a snapshot. */
  protected restoreBaseReadingState(snapshot: ReaderSessionReadingSnapshot): void {
    this.chapterStates.clear()
    snapshot.chapterStates.forEach((state: ChapterReadingState): void => {
      this.chapterStates.set(chapterStateKey(state.comicId, state.chapterId), {
        comicId: state.comicId, chapterId: state.chapterId, sourceIdentity: state.sourceIdentity,
        position: state.position === undefined ? undefined : copyReadingProgress(state.position),
        isRead: state.isRead, bookmarked: state.bookmarked, updatedAt: state.updatedAt,
      })
    })
    this.remoteHistoryByComicId.clear()
    snapshot.remoteHistory.forEach((row: RemoteReadHistoryEntry): void => {
      const copied = copyRemoteReadHistoryEntry(row)
      if (copied !== undefined) this.remoteHistoryByComicId.set(copied.comicId, copied)
    })
    this.replaceReadingSessions(snapshot.readingSessions)
  }

  /** Replace every in-memory row with the snapshot. Persistent stores flush. */
  abstract restoreReadingState(snapshot: ReaderSessionReadingSnapshot): void

  addReadingSession(record: ReadingSessionRecord): void {
    const row: ReadingSessionRecord = { comicId: record.comicId, chapterId: record.chapterId,
      startedAt: record.startedAt, endedAt: record.endedAt, pagesRead: record.pagesRead }
    this.indexReadingSession(row)
    this.readingSessionAdded(row)
  }
  protected readingSessionAdded(_record: ReadingSessionRecord): void { this.chapterStatesChanged() }

  protected prepareReadingSessions(): void {}

  private indexReadingSession(row: ReadingSessionRecord): void {
    let work = this.readingSessionsByComic.get(row.comicId)
    if (work === undefined) {
      work = new Set<ReadingSessionRecord>()
      this.readingSessionsByComic.set(row.comicId, work)
    }
    work.add(row)
    this.readingSessions.add(row)
  }

  protected replaceReadingSessions(rows: ReadingSessionRecord[]): void {
    this.readingSessions.clear()
    this.readingSessionsByComic.clear()
    for (const row of rows) {
      this.indexReadingSession({ comicId: row.comicId, chapterId: row.chapterId, startedAt: row.startedAt,
        endedAt: row.endedAt, pagesRead: row.pagesRead })
    }
  }

  protected hasReadingSessions(comicId: ComicId): boolean {
    return this.readingSessionsByComic.has(comicId)
  }

  protected removeReadingSessions(comicIds: ComicId[]): void {
    for (const id of comicIds) {
      const records = this.readingSessionsByComic.get(id)
      if (records === undefined) continue
      for (const row of records) this.readingSessions.delete(row)
      this.readingSessionsByComic.delete(id)
    }
  }
  protected readonly chapterStates: Map<string, ChapterReadingState> = new Map<string, ChapterReadingState>()
  protected storedChapterState(comicId: ComicId, chapterId: ChapterId): ChapterReadingState | undefined {
    return this.chapterStates.get(chapterStateKey(comicId, chapterId))
  }
  protected readonly remoteHistoryByComicId: Map<ComicId, RemoteReadHistoryEntry> = new Map<ComicId, RemoteReadHistoryEntry>()
  abstract getProgress(comicId: ComicId): ReadingProgress | undefined
  abstract saveProgress(progress: ReadingProgress, sourceChapterTitle?: string): void
  abstract removeProgress(comicId: ComicId): void
  abstract listProgress(): ReadingProgress[]

  shelfPositions(comicIds: ComicId[]): Map<ComicId, ReadingProgress> {
    const result = new Map<ComicId, ReadingProgress>()
    for (const id of comicIds) {
      const position = this.getProgress(id)
      if (position !== undefined) result.set(id, position)
    }
    return result
  }

  latestMatchingProgress(matches: (progress: ReadingProgress) => boolean): ReadingProgress[] {
    return this.matchNewestProgress(this.listProgress(), matches)
  }

  protected matchNewestProgress(rows: ReadingProgress[], matches: (progress: ReadingProgress) => boolean): ReadingProgress[] {
    rows.sort((a: ReadingProgress, b: ReadingProgress): number => b.updatedAt - a.updatedAt)
    const latest: ReadingProgress[] = []
    for (const row of rows) {
      if (latest.length > 0 && row.updatedAt < latest[0].updatedAt) break
      if (matches(row)) latest.push(row)
    }
    return latest
  }
  /** Metadata for a source item that has been read without being shelved. */
  abstract getSourceHistory(comicId: ComicId): SourceReadHistoryEntry | undefined
  // Source history owns the work identity and display metadata. The latest
  // saved page owns the resume chapter, including older mismatched rows.
  getSourceHistoryForResume(comicId: ComicId): SourceReadHistoryEntry | undefined {
    const progress = this.getProgress(comicId)
    return (progress === undefined ? undefined : this.sourceHistoryForPage(progress)) ?? this.getSourceHistory(comicId)
  }

  protected sourceHistoryForPage(progress: ReadingProgress, chapterTitle?: string): SourceReadHistoryEntry | undefined {
    const history = this.getSourceHistory(progress.comicId)
    if (history === undefined || history.chapterId === progress.chapterId) return undefined
    history.chapterId = progress.chapterId
    history.chapterTitle = chapterTitle
    return history
  }
  abstract saveSourceHistory(entry: SourceReadHistoryEntry): void
  abstract removeSourceHistory(comicId: ComicId): void
  abstract listSourceHistory(): SourceReadHistoryEntry[]
  /** Writes any queued update before the Reader route releases its session. */
  abstract flush(): boolean
  /** Non-blocking durability boundary for work that can wait. */
  async flushAsync(): Promise<boolean> { return this.flush() }

  commitChapterReadStates(mutations: ChapterReadMutation[], identity?: SyncReadingSource): ChapterReadCommitResult {
    let changedCount = 0
    const committed = this.commitUserMutation((): void => {
      changedCount = this.markChapterReadStates(mutations, identity)
    }, mutations.map((mutation: ChapterReadMutation): SyncReadingSignal => ({
      comicId: mutation.comicId, chapterId: mutation.chapterId, kind: mutation.isRead ? 'read' : 'unread', identity,
    })))
    return { committed, changedCount: committed ? changedCount : 0 }
  }

  isChapterBookmarked(comicId: ComicId, chapterId: ChapterId): boolean {
    return this.storedChapterState(comicId, chapterId)?.bookmarked === true
  }

  chapterReadingState(comicId: ComicId, chapterId: ChapterId): Readonly<ChapterReadingState> | undefined {
    return this.storedChapterState(comicId, chapterId)
  }

  commitChapterBookmark(comicId: ComicId, chapterId: ChapterId, bookmarked: boolean, identity?: SyncReadingSource): boolean {
    const committed = this.commitUserMutation((): void => {
      const key = chapterStateKey(comicId, chapterId)
      const old = this.storedChapterState(comicId, chapterId)
      this.chapterStates.set(key, { comicId, chapterId, position: old?.position,
        sourceIdentity: identity ?? old?.sourceIdentity,
        isRead: old?.isRead === true, bookmarked, updatedAt: old?.updatedAt ?? Date.now() })
      this.chapterStatesChanged()
    }, [{ comicId, chapterId, kind: bookmarked ? 'bookmark' : 'unbookmark', identity }])
    return committed
  }

  /** Transfer only resolved chapter identities. Existing destination progress wins;
   * the original history remains available after a shelf-only migration. */
  commitMigrationReadPlan(plan: MangaMigrationReadPlan): boolean {
    return this.commitUserMutation((): void => {
      let changed = false
      plan.states.forEach((state: MangaMigrationReadState): void => {
        const key = chapterStateKey(state.comicId, state.chapterId)
        const previous = this.storedChapterState(state.comicId, state.chapterId)
        if (previous?.isRead === true && (state.bookmarked !== true || previous.bookmarked === true)) return
        const next: ChapterReadingState = { comicId: state.comicId, chapterId: state.chapterId,
          isRead: previous?.isRead === true || state.isRead, position: previous?.position,
          bookmarked: previous?.bookmarked === true || state.bookmarked === true, updatedAt: state.updatedAt }
        projectChapterCompletion(next, next.position)
        projectChapterCompletion(next, this.getProgress(state.comicId))
        this.chapterStates.set(key, next)
        changed = true
      })
      if (changed) this.chapterStatesChanged()
      if (plan.progress !== undefined && this.getProgress(plan.progress.comicId) === undefined) {
        this.saveTransferredProgress(plan.progress)
      }
    })
  }

  protected saveTransferredProgress(progress: ReadingProgress): void {
    this.saveProgress(progress)
  }

  protected commitUserMutation(mutation: () => void, _actions: SyncReadingSignal[] = []): boolean {
    mutation()
    return this.flush()
  }

  removeHistoryEntries(comicIds: ComicId[], clear: boolean = false): boolean {
    return this.commitUserMutation((): void => {
      comicIds.forEach((comicId: ComicId): void => {
        this.removeProgress(comicId)
        this.removeSourceHistory(comicId)
        this.removeRemoteHistory(comicId)
      })
      this.removeReadingSessions(comicIds)
      this.chapterStatesChanged()
    })
  }

  getRemoteHistory(comicId: ComicId): RemoteReadHistoryEntry | undefined {
    this.prepareRemoteHistory()
    const entry = this.remoteHistoryByComicId.get(comicId)
    return entry === undefined ? undefined : copyRemoteReadHistoryEntry(entry)
  }

  saveRemoteHistory(entry: RemoteReadHistoryEntry): void {
    this.prepareRemoteHistory()
    const copied = copyRemoteReadHistoryEntry(entry)
    if (copied === undefined) return
    this.remoteHistoryByComicId.set(copied.comicId, copied)
    this.remoteHistoryChanged(false)
  }

  removeRemoteHistory(comicId: ComicId): void {
    this.prepareRemoteHistory()
    if (this.remoteHistoryByComicId.delete(comicId)) this.remoteHistoryChanged(true)
  }

  listRemoteHistory(): RemoteReadHistoryEntry[] {
    this.prepareRemoteHistory()
    const entries: RemoteReadHistoryEntry[] = []
    this.remoteHistoryByComicId.forEach((entry: RemoteReadHistoryEntry): void => {
      const copied = copyRemoteReadHistoryEntry(entry)
      if (copied !== undefined) entries.push(copied)
    })
    return entries
  }

  protected remoteHistoryChanged(_immediate: boolean): void {}

  protected prepareRemoteHistory(): void {}

  getComicProgress(comic: Comic): ReadingProgress | undefined {
    return currentComicReadingProgress(comic, this.getProgress(comic.id))
  }

  getChapterProgress(comicId: ComicId, chapterId: ChapterId): ReadingProgress | undefined {
    return this.storedChapterState(comicId, chapterId)?.position
  }

  /** Anchor both saved positions to existing page IDs before replacing an EPUB
   * page list. After publication, normalize indexes without changing read time. */
  reconcileLocalEpubPositions(comicId: ComicId, chapterId: ChapterId, pageIds: string[],
    normalize: boolean): boolean {
    const rows: ReadingProgress[] = []
    const recent = this.getProgress(comicId)
    if (recent !== undefined && recent.chapterId === chapterId) rows.push(recent)
    const chapter = this.getChapterProgress(comicId, chapterId)
    if (chapter !== undefined) rows.push(chapter)
    if (normalize && rows.some((row: ReadingProgress): boolean => row.pageId === undefined || !pageIds.includes(row.pageId))) return false
    if (!normalize && rows.length !== pageIds.length) return false
    if (rows.length === 0) return true
    return this.commitUserMutation((): void => {
      rows.forEach((row: ReadingProgress, index: number): void => {
        if (!normalize) {
          row.pageId = pageIds[index]
        } else {
          const nextIndex = pageIds.indexOf(row.pageId as string)
          row.pageIndex = nextIndex
          row.totalPages = pageIds.length
          row.progressRatio = pageIds.length > 0 ? (nextIndex + 1) / pageIds.length : 0
        }
      })
      this.chapterStatesChanged()
    })
  }

  isChapterRead(comicId: ComicId, chapterId: ChapterId): boolean {
    return this.storedChapterState(comicId, chapterId)?.isRead === true
  }

  prepareShelfReadingFacts(_comics: Comic[]): boolean { return false }

  protected shelfChapterFacts(_comicId: ComicId): ShelfChapterFacts | undefined { return undefined }

  latestCatalogDate(comic: Comic): number | undefined {
    if (comic.chapterCatalogDeferred === true) {
      const date = this.shelfChapterFacts(comic.id)?.latestDate
      return date !== undefined && date > 0 ? date : undefined
    }
    let latest: number | undefined
    for (const chapter of comic.chapters) {
      const date = chapter.dateUpload
      if (date !== undefined && Number.isFinite(date) && date > (latest ?? 0)) latest = date
    }
    return latest
  }

  hasStartedComic(comic: Comic): boolean {
    if (this.getProgress(comic.id) !== undefined) return true
    if (comic.chapterCatalogDeferred === true) return this.shelfChapterFacts(comic.id)?.started === true
    return comic.chapters.some((chapter: Chapter): boolean =>
      this.isChapterRead(comic.id, chapter.id) || this.getChapterProgress(comic.id, chapter.id) !== undefined)
  }

  unreadChapterCount(comic: Comic): number | undefined {
    // Compare completeness with received rows; a complete source catalog may repeat IDs.
    // Count logical chapters only once, without treating duplicates as missing chapters.
    const shared = comic.sourceMetadata?.sharedChapterIds
    if (comic.chapterCatalogDeferred === true) {
      const facts = this.shelfChapterFacts(comic.id)
      if (facts === undefined || facts.chapterCount === 0 || (shared === undefined && comic.chapterCount > facts.storedRows)) {
        return undefined
      }
      return facts.chapterCount - facts.readCount
    }
    if (shared === undefined && comic.chapterCount > comic.chapters.length) return undefined
    const chapterIds = new Set<ChapterId>(shared ?? comic.chapters.map((chapter: Chapter): ChapterId => chapter.id))
    if (chapterIds.size === 0) return undefined
    let unread = 0
    chapterIds.forEach((chapterId: ChapterId): void => {
      if (!this.isChapterRead(comic.id, chapterId)) unread += 1
    })
    return unread
  }

  prepareWorkChapterStates(_comicId: ComicId): void {}

  listChapterStates(comicId?: ComicId): ChapterReadingState[] {
    const states = Array.from(this.chapterStates.values())
    return comicId === undefined ? states : states.filter((state: ChapterReadingState): boolean => state.comicId === comicId)
  }

  comicReadingState(comic: Comic): ComicReadingState {
    const shared = comic.sourceMetadata?.sharedChapterIds
    if (comic.chapterCatalogDeferred === true) {
      const facts = this.shelfChapterFacts(comic.id)
      if (facts !== undefined && facts.chapterCount > 0 && facts.chapterCount === facts.readCount &&
        (shared !== undefined || comic.chapterCount <= facts.storedRows)) return 'completed'
      return facts?.reading === true ? 'reading' : 'unread'
    }
    const ids = shared ?? comic.chapters.map((chapter: Chapter): ChapterId => chapter.id)
    if (ids.length > 0 && (shared !== undefined || comic.chapterCount <= ids.length) &&
      ids.every((id: ChapterId): boolean => this.isChapterRead(comic.id, id))) return 'completed'
    return ids.some((id: ChapterId): boolean => {
      const state = this.storedChapterState(comic.id, id)
      return state !== undefined && (state.isRead || (state.position !== undefined &&
        state.position.totalPages > 0 && state.position.pageIndex > 0))
    }) ? 'reading' : 'unread'
  }

  markChapterReadState(comicId: ComicId, chapterId: ChapterId, isRead: boolean): void {
    this.markChapterReadStates([{ comicId, chapterId, isRead }])
  }

  markChapterReadStates(mutations: ChapterReadMutation[], identity?: SyncReadingSource): number {
    let changed = 0
    mutations.forEach((mutation: ChapterReadMutation): void => {
      if (mutation.comicId.length === 0 || mutation.chapterId.length === 0) return
      const key = chapterStateKey(mutation.comicId, mutation.chapterId)
      const old = this.storedChapterState(mutation.comicId, mutation.chapterId)
      const state: ChapterReadingState = { comicId: mutation.comicId, chapterId: mutation.chapterId,
        sourceIdentity: identity ?? old?.sourceIdentity,
        position: old?.position, isRead: mutation.isRead, bookmarked: old?.bookmarked, updatedAt: Date.now() }
      if (!mutation.isRead && state.position !== undefined) {
        const previous = state.position
        state.position = { comicId: previous.comicId, chapterId: previous.chapterId,
          pageIndex: 0, totalPages: previous.totalPages,
          progressRatio: previous.totalPages > 0 ? 1 / previous.totalPages : 0,
          completed: false, updatedAt: previous.updatedAt, columnMode: previous.columnMode }
      }
      const recent = this.getProgress(mutation.comicId)
      if (!mutation.isRead && recent !== undefined && recent.chapterId === mutation.chapterId) {
        recent.pageId = undefined
        recent.pageIndex = 0
        recent.progressRatio = recent.totalPages > 0 ? 1 / recent.totalPages : 0
      }
      projectChapterCompletion(state, state.position)
      projectChapterCompletion(state, recent)
      this.chapterStates.set(key, state)
      changed += 1
    })
    if (changed > 0) this.chapterStatesChanged()
    return changed
  }

  protected recordChapterProgress(progress: ReadingProgress): ChapterReadingState {
    const key = chapterStateKey(progress.comicId, progress.chapterId)
    const old = this.storedChapterState(progress.comicId, progress.chapterId)
    const history = this.getSourceHistory(progress.comicId)
    const identity: SyncReadingSource | undefined = history === undefined ? old?.sourceIdentity :
      { source: history.sourceId, work: history.mangaId }
    const state: ChapterReadingState = { comicId: progress.comicId, chapterId: progress.chapterId,
      sourceIdentity: identity, position: progress, isRead: old?.isRead === true || progress.completed === true,
      bookmarked: old?.bookmarked,
      updatedAt: progress.updatedAt }
    this.chapterStates.set(key, state)
    return state
  }

  protected chapterStatesChanged(): void {}

  /**
   * RDR-004-B: resolve a one-shot chapter open intent into the initial page.
   * `start` is the chapter's first page, `end` its last (0 while a session has
   * no pages yet, so an unavailable placeholder is never consumed as a real
   * end landing), and `resume` keeps the existing stored position.
   */
  openPageIndex(config: ReaderSessionConfig, intent: ReaderChapterOpenIntent): number {
    if (intent === 'start') {
      return 0
    }
    if (intent === 'end') {
      return config.totalPages > 0 ? config.totalPages - 1 : 0
    }
    return this.restorePageIndex(config)
  }

  restorePageIndex(config: ReaderSessionConfig): number {
    const progress = this.getChapterProgress(config.comicId, config.chapterId)
    if (progress === undefined) {
      return 0
    }
    if (config.deferredLocalArchive === true && config.totalPages === 0) {
      return Math.max(0, progress.pageIndex)
    }
    return readingProgressPageIndex(progress, config.totalPages, config.pageIds)
  }

  restoreColumnMode(
    config: ReaderSessionConfig,
    fallback: 'odd_left' | 'even_left',
  ): 'odd_left' | 'even_left' {
    const progress = this.getChapterProgress(config.comicId, config.chapterId)
    if (progress === undefined) {
      return fallback
    }
    return progress.columnMode === 'even_left' ? 'even_left' :
      (progress.columnMode === 'odd_left' ? 'odd_left' : fallback)
  }
}

export class InMemoryReaderSessionStore extends ReaderSessionStore {
  private readonly progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
  private readonly sourceHistoryByComicId: Map<ComicId, SourceReadHistoryEntry> = new Map<ComicId, SourceReadHistoryEntry>()

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    return this.progressByComicId.get(comicId)
  }

  protected saveTransferredProgress(progress: ReadingProgress): void {
    const copied = JSON.parse(JSON.stringify(progress)) as ReadingProgress
    this.progressByComicId.set(copied.comicId, copied)
    this.recordChapterProgress(copied)
  }

  saveProgress(progress: ReadingProgress, sourceChapterTitle?: string): void {
    const copied = copyReadingProgressWithTimestamp(progress)
    copied.completed = this.isChapterRead(progress.comicId, progress.chapterId) || progress.completed
    this.progressByComicId.set(progress.comicId, copied)
    const history = this.sourceHistoryForPage(copied, sourceChapterTitle)
    if (history !== undefined) this.sourceHistoryByComicId.set(copied.comicId, history)
    this.recordChapterProgress(copied)
  }

  removeProgress(comicId: ComicId): void {
    this.progressByComicId.delete(comicId)
  }

  listProgress(): ReadingProgress[] {
    const out: ReadingProgress[] = []
    this.progressByComicId.forEach((progress: ReadingProgress) => {
      out.push(progress)
    })
    return out
  }

  getSourceHistory(comicId: ComicId): SourceReadHistoryEntry | undefined {
    const entry = this.sourceHistoryByComicId.get(comicId)
    return entry === undefined ? undefined : copySourceReadHistoryEntry(entry)
  }

  saveSourceHistory(entry: SourceReadHistoryEntry): void {
    const copied = copySourceReadHistoryEntry(entry)
    if (copied !== undefined) {
      this.sourceHistoryByComicId.set(copied.comicId, copied)
    }
  }

  removeSourceHistory(comicId: ComicId): void {
    this.sourceHistoryByComicId.delete(comicId)
  }

  listSourceHistory(): SourceReadHistoryEntry[] {
    const out: SourceReadHistoryEntry[] = []
    this.sourceHistoryByComicId.forEach((entry: SourceReadHistoryEntry): void => {
      const copied = copySourceReadHistoryEntry(entry)
      if (copied !== undefined) {
        out.push(copied)
      }
    })
    return out
  }

  restoreReadingState(snapshot: ReaderSessionReadingSnapshot): void {
    this.progressByComicId.clear()
    snapshot.progress.forEach((progress: ReadingProgress): void => {
      this.progressByComicId.set(progress.comicId, copyReadingProgress(progress))
    })
    this.sourceHistoryByComicId.clear()
    snapshot.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
      const copied = copySourceReadHistoryEntry(entry)
      if (copied !== undefined) this.sourceHistoryByComicId.set(copied.comicId, copied)
    })
    this.restoreBaseReadingState(snapshot)
  }

  flush(): boolean {
    return true
  }
}

export class PersistentReaderSessionStore extends ReaderSessionStore {
  private readonly adapter: ReaderSessionPersistenceAdapter
  private readonly progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
  private readonly queriedPositions = new Set<ComicId>()
  private readonly queriedSourceHistory = new Set<ComicId>()
  private deferredReadingDatabase?: ReaderRdbStorage
  private positionsComplete: boolean = true
  private sourceHistoryComplete: boolean = true
  private remoteHistoryComplete: boolean = true
  private readingSessionsComplete: boolean = true
  private syncOutboxComplete: boolean = true
  private readonly sourceHistoryByComicId: Map<ComicId, SourceReadHistoryEntry> = new Map<ComicId, SourceReadHistoryEntry>()
  private readonly pendingPageTurns: Map<string, ChapterReadingState> = new Map<string, ChapterReadingState>()
  private readonly pendingSourceHistory: Set<ComicId> = new Set<ComicId>()
  private readonly shelfFacts = new Map<ComicId, ShelfChapterFacts>()
  private deferredChapterDatabase?: ReaderRdbStorage
  private readonly loadedChapterWorks = new Set<ComicId>()
  private readonly missingChapters = new Set<string>()
  private cloudChaptersReady: boolean = false
  private needsFullSnapshot: boolean = false
  private pendingReadingSessions: ReadingSessionRecord[] = []
  private persistTimerId: number = -1
  private persistPending: boolean = false
  private persistRevision: number = 0
  private persistBarrier: number = 0
  private asyncPersistActive: boolean = false
  private asyncPersistQueued: boolean = false
  private asyncPersistWaiters: Array<() => void> = []
  private activePersistPromise: Promise<void> | undefined = undefined
  private deviceSyncRevision: number = 0
  private syncPositions: SyncReadingCapture[] = []
  private syncActions: SyncReadingActionCapture[] = []

  constructor(adapter: ReaderSessionPersistenceAdapter) {
    super()
    this.adapter = adapter
    this.restoreSnapshot()
    this.flushPendingMigration()
  }

  currentDeviceSyncRevision(): number {
    return this.deviceSyncRevision
  }

  prepareShelfReadingFacts(comics: Comic[]): boolean {
    const database = this.adapter.activityDatabase?.()
    if (database === undefined) return false
    const ids = comics.filter((comic: Comic): boolean => comic.chapterCatalogDeferred === true)
      .map((comic: Comic): ComicId => comic.id)
    try {
      for (const row of database.readShelfChapterFacts(ids)) this.shelfFacts.set(row.comicId, row)
      return true
    } catch (error) {
      DiagnosticLogger.exception('reader_session_store', 'shelf_facts_failed', error as Error)
      return false
    }
  }

  protected shelfChapterFacts(comicId: ComicId): ShelfChapterFacts | undefined {
    return this.shelfFacts.get(comicId)
  }

  protected storedChapterState(comicId: ComicId, chapterId: ChapterId): ChapterReadingState | undefined {
    const key = chapterStateKey(comicId, chapterId)
    const cached = this.chapterStates.get(key)
    const database = this.deferredChapterDatabase
    if (cached !== undefined || database === undefined || this.loadedChapterWorks.has(comicId) ||
      this.missingChapters.has(key)) return cached
    const rows = database.readChapters(comicId, chapterId)
    const row = rows[rows.length - 1]
    if (row === undefined) this.missingChapters.add(key)
    else this.chapterStates.set(key, row)
    return row
  }

  prepareWorkChapterStates(comicId: ComicId): void {
    const database = this.deferredChapterDatabase
    if (database === undefined || this.loadedChapterWorks.has(comicId)) return
    this.loadChapterRows(database.readChapters(comicId))
    this.loadedChapterWorks.add(comicId)
  }

  listChapterStates(comicId?: ComicId): ChapterReadingState[] {
    const database = this.deferredChapterDatabase
    if (database !== undefined) {
      if (comicId !== undefined) this.prepareWorkChapterStates(comicId)
      else {
        this.loadChapterRows(database.readChapters())
        this.deferredChapterDatabase = undefined
      }
    }
    return super.listChapterStates(comicId)
  }

  /** Capture portable positions before ArkData starts overwriting the shared
   * table. Chapter rows of unrelated, device-only works stay on demand. */
  prepareCloudChapterStates(): void {
    // The native transfer updates the shared rows in place. Take the local
    // comparison snapshot before that happens, including unread cached positions.
    this.prepareAllPositions()
    this.prepareSourceHistory()
    const database = this.deferredChapterDatabase
    if (database === undefined || this.cloudChaptersReady) return
    this.loadChapterRows(database.readSharedChapters())
    this.cloudChaptersReady = true
  }

  private loadChapterRows(rows: ChapterReadingState[]): void {
    const loaded = new Map<string, ChapterReadingState>()
    for (const row of rows) loaded.set(chapterStateKey(row.comicId, row.chapterId), row)
    loaded.forEach((row: ChapterReadingState, key: string): void => {
      if (!this.chapterStates.has(key)) this.chapterStates.set(key, row)
    })
  }

  pendingDeviceSyncPositions(): SyncReadingCapture[] {
    this.prepareSyncOutbox()
    return this.syncPositions.slice()
  }

  pendingDeviceSyncActions(): SyncReadingActionCapture[] {
    this.prepareSyncOutbox()
    return this.syncActions.slice()
  }

  /** Reload a replaced backup without flushing the pre-restore pending snapshot. */
  reload(): void {
    this.restoreSnapshot(true)
    this.flushPendingMigration()
  }

  /** The restore worker already loaded and normalized the committed documents. */
  applyCommittedSnapshot(snapshot: ReaderSessionDocumentSnapshot): void {
    this.restoreSnapshot(true, snapshot)
  }

  /** A committed Mihon link only replaces the affected works' recent records
   * and upserts their chapter states. The restore transaction flushed writes. */
  applyCommittedMihonLinks(comicIds: string[], snapshot: ReaderSessionDocumentSnapshot): void {
    this.applyCommittedReadingRows(comicIds, snapshot)
    this.deviceSyncRevision += 1
  }

  applyCommittedDeviceSyncEdits(scope: ReaderSyncWorkScope[], snapshot: ReaderSessionDocumentSnapshot): void {
    for (const work of scope) {
      for (const chapterId of work.chapterIds) {
        const key = chapterStateKey(work.comicId, chapterId)
        this.chapterStates.delete(key)
        this.missingChapters.delete(key)
      }
    }
    this.applyCommittedReadingRows(scope.map((work: ReaderSyncWorkScope): string => work.comicId), snapshot)
    this.syncPositions = snapshot.syncPositions ?? []
    this.syncActions = snapshot.syncActions ?? []
    this.syncOutboxComplete = true
  }

  applyCloudReading(storage: ReaderRdbStorage, scope: ReaderSyncWorkScope[]): void {
    const before: ReaderSessionDocumentSnapshot = { progress: [], chapters: [], sourceHistory: [] }
    for (const item of scope) {
      const progress = this.getProgress(item.comicId)
      const history = this.getSourceHistory(item.comicId)
      if (progress !== undefined) before.progress.push(progress)
      if (history !== undefined) before.sourceHistory.push(history)
      const chapterIds = new Set(item.chapterIds)
      if (progress !== undefined) chapterIds.add(progress.chapterId)
      for (const chapterId of chapterIds) {
        const chapter = this.chapterStates.get(chapterStateKey(item.comicId, chapterId))
        if (chapter !== undefined) before.chapters.push(chapter)
      }
    }
    const received = storage.applyCloudReading(scope, before)
    for (const item of scope) {
      for (const chapterId of item.chapterIds) {
        const key = chapterStateKey(item.comicId, chapterId)
        this.chapterStates.delete(key)
        this.missingChapters.delete(key)
      }
    }
    this.applyCommittedReadingRows(scope.map((work: ReaderSyncWorkScope): string => work.comicId), received)
    if (!this.persistPending) return
    // Retire a staged write made before the cloud commit. Preserve pending
    // turns in other chapters without making them the current position again.
    this.persistRevision += 1
    for (const item of scope) {
      for (const chapterId of item.chapterIds) {
        const key = chapterStateKey(item.comicId, chapterId)
        const pending = this.pendingPageTurns.get(key)
        if (pending === undefined) continue
        const applied = this.chapterStates.get(key)
        if (applied?.position !== undefined && applied.position === pending.position) this.pendingPageTurns.set(key, applied)
        else this.pendingPageTurns.delete(key)
      }
    }
  }

  private applyCommittedReadingRows(comicIds: string[], snapshot: ReaderSessionDocumentSnapshot): void {
    for (const id of comicIds) {
      this.queriedPositions.add(id)
      this.queriedSourceHistory.add(id)
      this.progressByComicId.delete(id)
      this.sourceHistoryByComicId.delete(id)
    }
    for (const progress of snapshot.progress) this.progressByComicId.set(progress.comicId, progress)
    for (const history of snapshot.sourceHistory) this.sourceHistoryByComicId.set(history.comicId, history)
    for (const chapter of snapshot.chapters) {
      this.chapterStates.set(chapterStateKey(chapter.comicId, chapter.chapterId), chapter)
    }
  }

  restoreReadingState(snapshot: ReaderSessionReadingSnapshot): void {
    this.prepareSyncOutbox()
    this.resetReadingCoverage()
    this.deferredChapterDatabase = undefined
    this.loadedChapterWorks.clear()
    this.missingChapters.clear()
    this.shelfFacts.clear()
    this.progressByComicId.clear()
    snapshot.progress.forEach((progress: ReadingProgress): void => {
      this.progressByComicId.set(progress.comicId, copyReadingProgress(progress))
    })
    this.sourceHistoryByComicId.clear()
    snapshot.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
      const copied = copySourceReadHistoryEntry(entry)
      if (copied !== undefined) this.sourceHistoryByComicId.set(copied.comicId, copied)
    })
    this.restoreBaseReadingState(snapshot)
    this.schedulePersist()
    this.flush()
  }

  private flushPendingMigration(): void {
    if (this.adapter.requiresMigration !== undefined && this.adapter.requiresMigration()) {
      this.schedulePersist()
      this.flush()
    }
  }

  private restoreSnapshot(replace: boolean = false, prepared?: ReaderSessionDocumentSnapshot): void {
    const database = prepared === undefined ? this.adapter.activityDatabase?.() : undefined
    // RDB is already authoritative. Bind it here and read each domain at its
    // consumer, so opening the shelf never restores the whole reader snapshot.
    const snapshot = prepared ?? (database === undefined ? this.adapter.loadSnapshot?.() : undefined)
    const progressRows = snapshot?.progress ?? (database === undefined ? this.adapter.load() : [])
    const sourceHistory = snapshot !== undefined ? snapshot.sourceHistory :
      (database === undefined ? this.adapter.loadSourceHistory?.() ?? [] : [])
    const remoteHistory = snapshot !== undefined ? snapshot.remoteHistory ?? [] :
      (database === undefined ? this.adapter.loadRemoteHistory?.() ?? [] : [])
    // Finish loading before retiring the old snapshot or its pending write.
    if (replace) {
      this.shelfFacts.clear()
      if (this.persistTimerId >= 0) clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
      this.persistPending = false
      this.pendingPageTurns.clear()
      this.pendingSourceHistory.clear()
      this.pendingReadingSessions = []
      this.needsFullSnapshot = false
      this.persistBarrier += 1
      this.progressByComicId.clear()
      this.sourceHistoryByComicId.clear()
      this.remoteHistoryByComicId.clear()
      this.chapterStates.clear()
      this.loadedChapterWorks.clear()
      this.missingChapters.clear()
      this.cloudChaptersReady = false
      this.replaceReadingSessions([])
    }
    this.resetReadingCoverage(database)
    this.deferredChapterDatabase = database
    this.syncPositions = snapshot?.syncPositions ?? []
    this.syncActions = snapshot?.syncActions ?? []
    progressRows.forEach((progress: ReadingProgress): void => {
      this.progressByComicId.set(progress.comicId, progress)
      if (snapshot === undefined) this.recordChapterProgress(progress)
    })
    if (snapshot !== undefined) {
      this.replaceReadingSessions(snapshot.readingSessions ?? [])
      snapshot.chapters.forEach((state: ChapterReadingState): void => {
        this.chapterStates.set(chapterStateKey(state.comicId, state.chapterId), state)
      })
    }
    sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
        const copied = copySourceReadHistoryEntry(entry)
        if (copied !== undefined) {
          this.sourceHistoryByComicId.set(copied.comicId, copied)
        }
    })
    remoteHistory.forEach((entry: RemoteReadHistoryEntry): void => {
      const copied = copyRemoteReadHistoryEntry(entry)
      if (copied !== undefined) this.remoteHistoryByComicId.set(copied.comicId, copied)
    })
  }

  private resetReadingCoverage(database?: ReaderRdbStorage): void {
    this.deferredReadingDatabase = database
    this.queriedPositions.clear()
    this.queriedSourceHistory.clear()
    this.positionsComplete = database === undefined
    this.sourceHistoryComplete = database === undefined
    this.remoteHistoryComplete = database === undefined
    this.readingSessionsComplete = database === undefined
    this.syncOutboxComplete = database === undefined
  }

  private preparePositions(comicIds: ComicId[]): void {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.positionsComplete) return
    const missing = comicIds.filter((id: ComicId): boolean => !this.queriedPositions.has(id) && !this.progressByComicId.has(id))
    if (missing.length === 0) return
    for (const row of database.readPositions(missing)) this.progressByComicId.set(row.comicId, row)
    for (const id of missing) this.queriedPositions.add(id)
  }

  private prepareAllPositions(): void {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.positionsComplete) return
    const ordered = new Map<ComicId, ReadingProgress>()
    for (const row of database.readPositions()) {
      const cached = this.progressByComicId.get(row.comicId)
      if (cached !== undefined) ordered.set(row.comicId, cached)
      else if (!this.queriedPositions.has(row.comicId)) ordered.set(row.comicId, row)
    }
    this.progressByComicId.forEach((row: ReadingProgress, id: ComicId): void => { ordered.set(id, row) })
    this.progressByComicId.clear()
    ordered.forEach((row: ReadingProgress, id: ComicId): void => { this.progressByComicId.set(id, row) })
    this.queriedPositions.clear()
    this.positionsComplete = true
  }

  private prepareSourceHistory(): void {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.sourceHistoryComplete) return
    for (const entry of database.readSourceHistory()) {
      if (this.queriedSourceHistory.has(entry.comicId)) continue
      const copied = copySourceReadHistoryEntry(entry)
      if (copied !== undefined) this.sourceHistoryByComicId.set(copied.comicId, copied)
    }
    this.queriedSourceHistory.clear()
    this.sourceHistoryComplete = true
  }

  protected prepareRemoteHistory(): void {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.remoteHistoryComplete) return
    for (const entry of database.readRemoteHistory()) {
      const copied = copyRemoteReadHistoryEntry(entry)
      if (copied !== undefined) this.remoteHistoryByComicId.set(copied.comicId, copied)
    }
    this.remoteHistoryComplete = true
  }

  protected prepareReadingSessions(): void {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.readingSessionsComplete) return
    this.replaceReadingSessions(database.readReadingSessions().concat(this.pendingReadingSessions))
    this.readingSessionsComplete = true
  }

  protected hasReadingSessions(comicId: ComicId): boolean {
    const database = this.deferredReadingDatabase
    return super.hasReadingSessions(comicId) || (database !== undefined && !this.readingSessionsComplete &&
      database.readReadingSessions(comicId).length > 0)
  }

  private prepareSyncOutbox(): void {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.syncOutboxComplete) return
    const outbox = database.readOutbox()
    this.syncPositions = outbox.syncPositions ?? []
    this.syncActions = outbox.syncActions ?? []
    this.syncOutboxComplete = true
  }

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    if (!this.positionsComplete && !this.queriedPositions.has(comicId) && !this.progressByComicId.has(comicId)) {
      this.preparePositions([comicId])
    }
    return this.progressByComicId.get(comicId)
  }

  shelfPositions(comicIds: ComicId[]): Map<ComicId, ReadingProgress> {
    this.preparePositions(comicIds)
    return super.shelfPositions(comicIds)
  }

  latestMatchingProgress(matches: (progress: ReadingProgress) => boolean): ReadingProgress[] {
    const database = this.deferredReadingDatabase
    if (database === undefined || this.positionsComplete) return super.latestMatchingProgress(matches)
    const latest = this.matchNewestProgress(Array.from(this.progressByComicId.values()), matches)
    const pageSize = 32
    for (let offset = 0; ; offset += pageSize) {
      const batch = database.readRecentPositions(pageSize, offset)
      for (const row of batch) {
        if (latest.length > 0 && row.updatedAt < latest[0].updatedAt) return latest
        if (this.queriedPositions.has(row.comicId) || this.progressByComicId.has(row.comicId)) continue
        const position = this.getProgress(row.comicId)
        if (position === undefined || (latest.length > 0 && position.updatedAt < latest[0].updatedAt) ||
          !matches(position)) continue
        if (latest.length > 0 && position.updatedAt > latest[0].updatedAt) latest.length = 0
        latest.push(position)
      }
      if (batch.length < pageSize) return latest
    }
  }

  protected saveTransferredProgress(progress: ReadingProgress): void {
    const copied = JSON.parse(JSON.stringify(progress)) as ReadingProgress
    this.progressByComicId.set(copied.comicId, copied)
    this.recordChapterProgress(copied)
    this.schedulePersist()
  }

  saveProgress(progress: ReadingProgress, sourceChapterTitle?: string): void {
    if (!allowDeviceSyncReaderProgress(progress)) return
    const copied = copyReadingProgressWithTimestamp(progress)
    copied.completed = this.isChapterRead(progress.comicId, progress.chapterId) || progress.completed
    this.progressByComicId.set(progress.comicId, copied)
    const history = this.sourceHistoryForPage(copied, sourceChapterTitle)
    if (history !== undefined) this.sourceHistoryByComicId.set(copied.comicId, history)
    const state = this.recordChapterProgress(copied)
    const key = chapterStateKey(state.comicId, state.chapterId)
    // Keep the latest turn for each changed chapter. The current book position
    // is read independently when the batch is built.
    this.pendingPageTurns.delete(key)
    this.pendingPageTurns.set(key, state)
    // RDB can write the changed history row with the new position. Old files
    // still need a complete snapshot when the chapter changes.
    this.schedulePersist(history === undefined || this.adapter.supportsPageTurnWrites?.() === true)
  }

  protected chapterStatesChanged(): void {
    this.schedulePersist()
  }

  protected readingSessionAdded(record: ReadingSessionRecord): void {
    if (this.adapter.supportsPageTurnWrites?.() === true) {
      this.pendingReadingSessions.push(record)
      this.schedulePersist(true)
    } else {
      this.schedulePersist()
    }
  }

  protected remoteHistoryChanged(immediate: boolean): void {
    this.schedulePersist()
    if (immediate) this.flush()
  }

  removeProgress(comicId: ComicId): void {
    this.queriedPositions.add(comicId)
    this.progressByComicId.delete(comicId)
    // Destructive progress changes must be visible to a new store immediately;
    // queued page turns can remain coalesced.
    this.schedulePersist()
    this.flush()
  }

  removeHistoryEntries(comicIds: ComicId[], clear: boolean = false): boolean {
    const ids = new Set<ComicId>(comicIds)
    const database = this.adapter.activityDatabase?.()
    if (database !== undefined) return this.removeDatabaseHistory(database, ids, clear)
    const hasHistory = this.listProgress().some((row: ReadingProgress): boolean => ids.has(row.comicId)) ||
      this.listSourceHistory().some((row: SourceReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      this.listRemoteHistory().some((row: RemoteReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      Array.from(ids).some((id: ComicId): boolean => this.hasReadingSessions(id))
    if (!hasHistory) return true
    const committed = this.commitUserMutation((): void => {
      // Clearing the recent item keeps independently saved chapter positions.
      // Carry their identity forward before removing the history that held it.
      this.chapterStates.forEach((state: ChapterReadingState): void => {
        if (!ids.has(state.comicId)) return
        const entry = this.sourceHistoryByComicId.get(state.comicId)
        if (entry !== undefined) state.sourceIdentity = { source: entry.sourceId, work: entry.mangaId }
      })
      ids.forEach((comicId: ComicId): void => {
        this.progressByComicId.delete(comicId)
        this.sourceHistoryByComicId.delete(comicId)
        this.remoteHistoryByComicId.delete(comicId)
      })
      this.removeReadingSessions(Array.from(ids))
      this.schedulePersist()
    }, Array.from(ids).map((comicId: string): SyncReadingSignal => ({
      comicId, chapterId: '', kind: clear ? 'clear-history' : 'remove-history',
    })))
    return committed
  }

  protected commitUserMutation(mutation: () => void, actions: SyncReadingSignal[] = []): boolean {
    const database = this.adapter.activityDatabase?.()
    if (database !== undefined && actions.length > 0 &&
      actions.every((action: SyncReadingSignal): boolean => action.chapterId.length > 0)) {
      return this.commitChapterActions(database, mutation, actions)
    }
    const current: ReaderSessionDocumentSnapshot = { progress: this.listProgress(),
      sourceHistory: this.listSourceHistory(), remoteHistory: this.listRemoteHistory(), chapters: this.listChapterStates(),
      readingSessions: this.listReadingSessions() }
    // Read-state changes also mutate recent/position objects, so retain a detached snapshot.
    const previous = JSON.parse(JSON.stringify(current)) as ReaderSessionDocumentSnapshot
    const pendingBefore = this.persistPending
    const fullSnapshotBefore = this.needsFullSnapshot
    const actionsBefore = this.syncActions
    try {
      mutation()
      if (actions.length > 0 && this.persistPending) this.syncActions = this.syncActions.concat(stageDeviceSyncReadingActions(actions))
      if (this.flush()) return true
    } catch (_error) {
      DiagnosticLogger.warn('reader_session_store', 'user_mutation_failed', '[ReaderProgress] user_mutation_failed')
    }
    if (this.persistTimerId >= 0) clearTimeout(this.persistTimerId)
    this.persistTimerId = -1
    this.progressByComicId.clear()
    this.sourceHistoryByComicId.clear()
    this.remoteHistoryByComicId.clear()
    this.chapterStates.clear()
    this.replaceReadingSessions(previous.readingSessions ?? [])
    previous.progress.forEach((row: ReadingProgress): void => { this.progressByComicId.set(row.comicId, row) })
    previous.sourceHistory.forEach((row: SourceReadHistoryEntry): void => { this.sourceHistoryByComicId.set(row.comicId, row) })
    previous.remoteHistory?.forEach((row: RemoteReadHistoryEntry): void => { this.remoteHistoryByComicId.set(row.comicId, row) })
    previous.chapters.forEach((row: ChapterReadingState): void => {
      this.chapterStates.set(chapterStateKey(row.comicId, row.chapterId), row)
    })
    // Preserve an earlier page-turn write, but never retry a rejected user operation silently.
    this.persistPending = pendingBefore
    this.needsFullSnapshot = fullSnapshotBefore
    this.syncActions = actionsBefore
    if (pendingBefore) this.schedulePersist()
    return false
  }

  private removeDatabaseHistory(database: ReaderRdbStorage, ids: Set<ComicId>, clear: boolean): boolean {
    if (BackupRestoreActivity.hasPendingRecovery() || !this.flush()) return false
    let affected: ComicId[]
    const chapters: ChapterReadingState[] = []
    const actions = Array.from(ids).map((comicId: ComicId): SyncReadingSignal => ({
      comicId, chapterId: '', kind: clear ? 'clear-history' : 'remove-history',
    }))
    try {
      this.preparePositions(Array.from(ids))
      affected = Array.from(ids).filter((id: ComicId): boolean => this.progressByComicId.has(id) ||
        this.getSourceHistory(id) !== undefined || this.getRemoteHistory(id) !== undefined || this.hasReadingSessions(id))
      if (affected.length === 0) return true
      for (const id of affected) {
        const source = this.getSourceHistory(id)
        if (source === undefined) continue
        // Keep each chapter's independent position and portable identity after deleting its recent item.
        for (const previous of database.readWorkForSync(id).chapters) {
          const state = this.chapterStates.get(chapterStateKey(id, previous.chapterId)) ?? previous
          if (state.sourceIdentity?.source === source.sourceId && state.sourceIdentity.work === source.mangaId) continue
          chapters.push({ comicId: id, chapterId: state.chapterId, position: state.position, isRead: state.isRead,
            bookmarked: state.bookmarked, updatedAt: state.updatedAt,
            sourceIdentity: { source: source.sourceId, work: source.mangaId } })
        }
      }
      this.saveDatabaseActivity(database, { progress: [], chapters, sourceHistory: [] }, actions, affected)
    } catch (_error) {
      DiagnosticLogger.warn('reader_session_store', 'user_mutation_failed', '[ReaderProgress] user_mutation_failed')
      return false
    }
    for (const id of affected) {
      this.queriedPositions.add(id)
      this.queriedSourceHistory.add(id)
      this.progressByComicId.delete(id)
      this.sourceHistoryByComicId.delete(id)
      this.remoteHistoryByComicId.delete(id)
    }
    for (const chapter of chapters) this.chapterStates.set(chapterStateKey(chapter.comicId, chapter.chapterId), chapter)
    this.removeReadingSessions(affected)
    this.deviceSyncRevision += 1
    signalDeviceSyncChange('reading')
    return true
  }

  private commitChapterActions(database: ReaderRdbStorage, mutation: () => void, actions: SyncReadingSignal[]): boolean {
    if (BackupRestoreActivity.hasPendingRecovery() || !this.flush()) return false
    const chapters = new Map<string, ChapterReadingState | undefined>()
    const recent = new Map<ComicId, ReadingProgress>()
    if (actions.length > 1) {
      for (const id of new Set(actions.map((action: SyncReadingSignal): ComicId => action.comicId))) {
        this.prepareWorkChapterStates(id)
      }
    }
    for (const action of actions) {
      const key = chapterStateKey(action.comicId, action.chapterId)
      const state = this.storedChapterState(action.comicId, action.chapterId)
      chapters.set(key, state === undefined ? undefined : JSON.parse(JSON.stringify(state)) as ChapterReadingState)
      const position = this.getProgress(action.comicId)
      if (position?.chapterId === action.chapterId) recent.set(action.comicId, copyReadingProgress(position))
    }
    try {
      mutation()
      if (!this.persistPending) return true
      const reading: ReaderSessionDocumentSnapshot = { progress: [], chapters: [], sourceHistory: [] }
      for (const key of chapters.keys()) {
        const state = this.chapterStates.get(key)
        if (state !== undefined) reading.chapters.push(state)
      }
      for (const id of recent.keys()) {
        const position = this.progressByComicId.get(id)
        if (position !== undefined) reading.progress.push(position)
      }
      for (const id of new Set(actions.map((action: SyncReadingSignal): ComicId => action.comicId))) {
        const source = this.getSourceHistory(id)
        if (source !== undefined) reading.sourceHistory.push(source)
      }
      this.saveDatabaseActivity(database, reading, actions)
    } catch (_error) {
      chapters.forEach((state: ChapterReadingState | undefined, key: string): void => {
        if (state === undefined) this.chapterStates.delete(key)
        else this.chapterStates.set(key, state)
      })
      recent.forEach((position: ReadingProgress, id: ComicId): void => { this.progressByComicId.set(id, position) })
      DiagnosticLogger.warn('reader_session_store', 'user_mutation_failed', '[ReaderProgress] user_mutation_failed')
      return false
    } finally {
      if (this.persistTimerId >= 0) clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
      this.persistPending = false
      this.needsFullSnapshot = false
    }
    signalDeviceSyncChange('reading')
    return true
  }

  private saveDatabaseActivity(database: ReaderRdbStorage, reading: ReaderSessionDocumentSnapshot,
    actions: SyncReadingSignal[], removedHistory?: ComicId[]): void {
    this.prepareSyncOutbox()
    const pending = this.syncActions.concat(stageDeviceSyncReadingActions(actions))
    const positions = this.syncPositions.filter((row: SyncReadingCapture): boolean => !deviceSyncReadingAcknowledged(row))
    const retained = pending.filter((row: SyncReadingActionCapture): boolean =>
      !deviceSyncReadingActionAcknowledged(row) || positions.length > 0)
    reading.syncActions = retained
    reading.syncPositions = positions
    database.saveActivityEdits(reading, removedHistory)
    this.syncActions = retained
    this.syncPositions = positions
  }

  updatePageIndex(
    config: ReaderSessionConfig,
    pageIndex: number,
    pageId?: string,
    columnMode?: 'odd_left' | 'even_left',
  ): void {
    const total = Math.max(config.totalPages, 1)
    const target = Math.max(0, Math.min(pageIndex, total - 1))
    this.saveProgress({
      comicId: config.comicId,
      chapterId: config.chapterId,
      pageId,
      pageIndex: target,
      totalPages: total,
      progressRatio: total > 0 ? (target + 1) / total : 0,
      completed: target >= total - 1,
      updatedAt: Date.now(),
      columnMode,
    })
  }

  listProgress(): ReadingProgress[] {
    this.prepareAllPositions()
    const out: ReadingProgress[] = []
    this.progressByComicId.forEach((progress: ReadingProgress) => {
      out.push(progress)
    })
    return out
  }

  getSourceHistory(comicId: ComicId): SourceReadHistoryEntry | undefined {
    const database = this.deferredReadingDatabase
    if (database !== undefined && !this.sourceHistoryComplete && !this.queriedSourceHistory.has(comicId) &&
      !this.sourceHistoryByComicId.has(comicId)) {
      for (const row of database.readSourceHistory(comicId)) {
        const copied = copySourceReadHistoryEntry(row)
        if (copied !== undefined) this.sourceHistoryByComicId.set(comicId, copied)
      }
      this.queriedSourceHistory.add(comicId)
    }
    const entry = this.sourceHistoryByComicId.get(comicId)
    return entry === undefined ? undefined : copySourceReadHistoryEntry(entry)
  }

  saveSourceHistory(entry: SourceReadHistoryEntry): void {
    const copied = copySourceReadHistoryEntry(entry)
    if (copied === undefined) {
      return
    }
    this.queriedSourceHistory.add(copied.comicId)
    this.sourceHistoryByComicId.set(copied.comicId, copied)
    const scoped = this.adapter.supportsPageTurnWrites?.() === true
    if (scoped) this.pendingSourceHistory.add(copied.comicId)
    this.schedulePersist(scoped)
  }

  removeSourceHistory(comicId: ComicId): void {
    this.queriedSourceHistory.add(comicId)
    this.sourceHistoryByComicId.delete(comicId)
    this.schedulePersist()
    this.flush()
  }

  listSourceHistory(): SourceReadHistoryEntry[] {
    this.prepareSourceHistory()
    const out: SourceReadHistoryEntry[] = []
    this.sourceHistoryByComicId.forEach((entry: SourceReadHistoryEntry): void => {
      const copied = copySourceReadHistoryEntry(entry)
      if (copied !== undefined) {
        out.push(copied)
      }
    })
    return out
  }

  flush(): boolean {
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
    }
    if (!this.persistPending) return true
    this.persistBarrier += 1
    try {
      this.persist()
      // Only a completed commit discharges pending work. A later normal boundary can retry a failure.
      this.persistPending = false
      this.pendingPageTurns.clear()
      this.pendingSourceHistory.clear()
      this.pendingReadingSessions = []
      this.needsFullSnapshot = false
      return true
    } catch (_error) {
      DiagnosticLogger.warn('reader_session_store', 'persist_failed', '[ReaderProgress] persist_failed pending=true')
      return false
    }
  }

  async flushAsync(): Promise<boolean> {
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
    }
    for (let attempt = 0; attempt < 2; attempt += 1) {
      if (!this.persistPending) return true
      if (this.asyncPersistActive) {
        await new Promise<void>((resolve: () => void): void => {
          this.asyncPersistWaiters.push(resolve)
        })
        continue
      }
      await this.persistLatest()
    }
    return !this.persistPending
  }

  private schedulePersist(pageTurn: boolean = false): void {
    this.deviceSyncRevision++
    this.persistRevision += 1
    this.persistPending = true
    if (!pageTurn) this.needsFullSnapshot = true
    if (this.persistTimerId >= 0) {
      return
    }
    this.persistTimerId = setTimeout(() => {
      this.persistTimerId = -1
      void this.persistLatest()
    }, READER_PROGRESS_PERSIST_DEBOUNCE_MS)
  }

  /** A flush sets a durability boundary. The mutation determines which rows to write. */
  private pendingTurns(): ChapterReadingState[] | undefined {
    return this.needsFullSnapshot ? undefined : Array.from(this.pendingPageTurns.values())
  }

  private async persistLatest(): Promise<void> {
    if (!this.persistPending) return
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
    }
    if (this.asyncPersistActive) {
      this.asyncPersistQueued = true
      return
    }
    if (this.adapter.saveSnapshot === undefined || this.adapter.saveSnapshotAsync === undefined ||
      this.adapter.commitSnapshotAsync === undefined || this.adapter.discardSnapshotAsync === undefined) {
      this.flush()
      return
    }
    this.asyncPersistActive = true
    const revision = this.persistRevision
    const barrier = ++this.persistBarrier
    try {
      const pageTurns = this.pendingTurns()
      const plan = this.buildPersistPlan(this.adapter.supportsPageTurnWrites?.() === true ? pageTurns : undefined)
      if (plan === undefined) {
        this.flush()
        return
      }
      // The regular page-turn path gives the worker only the changed rows.
      // History edits, imports and restores still own their full snapshot.
      const staged = await this.adapter.saveSnapshotAsync(plan.snapshot, barrier, pageTurns)
      if (barrier !== this.persistBarrier) {
        this.adapter.discardSnapshotAsync(staged)
        return
      }
      if (revision !== this.persistRevision) {
        this.adapter.discardSnapshotAsync(staged)
        this.asyncPersistQueued = true
        return
      }
      try {
        this.adapter.commitSnapshotAsync(staged)
      } catch (error) {
        this.adapter.discardSnapshotAsync(staged)
        throw error as Error
      }
      this.acceptPersistPlan(plan)
      this.persistPending = false
      this.pendingPageTurns.clear()
      this.pendingSourceHistory.clear()
      this.pendingReadingSessions = []
      this.needsFullSnapshot = false
      signalDeviceSyncChange('reading')
    } catch (_error) {
      DiagnosticLogger.warn('reader_session_store', 'persist_failed',
        '[ReaderProgress] persist_failed pending=true async=true')
    } finally {
      this.asyncPersistActive = false
      const waiters = this.asyncPersistWaiters
      this.asyncPersistWaiters = []
      waiters.forEach((resolve: () => void): void => { resolve() })
      if (this.persistPending && this.asyncPersistQueued && this.persistTimerId < 0) {
        this.asyncPersistQueued = false
        this.persistTimerId = setTimeout(() => {
          this.persistTimerId = -1
          void this.persistLatest()
        }, 0)
      }
    }
  }

  private buildPersistPlan(pageTurns?: ChapterReadingState[]): ReaderSessionPersistPlan | undefined {
    if (this.adapter.saveSnapshot === undefined) return undefined
    this.prepareSyncOutbox()
    const rows: ReadingProgress[] = pageTurns === undefined ? this.listProgress() : []
    const chapters = pageTurns ?? this.listChapterStates()
    const history: SourceReadHistoryEntry[] = pageTurns === undefined ? this.listSourceHistory() : []
    if (pageTurns !== undefined) {
      const works = new Set<ComicId>(this.pendingSourceHistory)
      for (const turn of pageTurns) {
        works.add(turn.comicId)
        const current = this.progressByComicId.get(turn.comicId)
        if (current !== undefined && current.chapterId === turn.chapterId && current.updatedAt === turn.position?.updatedAt) {
          rows.push(current)
        }
      }
      for (const id of works) {
        const entry = this.sourceHistoryByComicId.get(id)
        if (entry !== undefined) history.push(entry)
      }
    }
    // The most recent progress per book omits earlier chapters read before
    // this flush. Match captures against the positions being saved per chapter.
    const staged = stageDeviceSyncReading(chapters.flatMap((chapter: ChapterReadingState): ReadingProgress[] =>
      chapter.position === undefined ? [] : [chapter.position]))
    const syncPositions = this.syncPositions.filter((item: SyncReadingCapture): boolean =>
      !deviceSyncReadingAcknowledged(item) && !staged.some((capture: SyncReadingCapture): boolean =>
        item.comicId === capture.comicId && item.chapterId === capture.chapterId && item.space === capture.space))
    syncPositions.push(...staged)
    const syncActions = this.syncActions.filter((item: SyncReadingActionCapture): boolean =>
      !deviceSyncReadingActionAcknowledged(item) || syncPositions.length > 0)
    return {
      snapshot: { progress: rows, sourceHistory: history,
        remoteHistory: pageTurns === undefined ? this.listRemoteHistory() : undefined, chapters,
        readingSessions: pageTurns === undefined ? this.listReadingSessions() : this.pendingReadingSessions.slice(),
        syncPositions: syncPositions.length > 0 ? syncPositions : undefined,
        syncActions: syncActions.length > 0 ? syncActions : undefined },
      syncPositions: syncPositions,
      syncActions: syncActions,
    }
  }

  private acceptPersistPlan(plan: ReaderSessionPersistPlan): void {
    this.syncPositions = plan.syncPositions
    this.syncActions = plan.syncActions
  }

  private persist(): void {
    const pageTurns = this.adapter.supportsPageTurnWrites?.() === true ? this.pendingTurns() : undefined
    const plan = this.buildPersistPlan(pageTurns)
    if (plan !== undefined) {
      this.adapter.saveSnapshot!(plan.snapshot, pageTurns)
      this.acceptPersistPlan(plan)
      signalDeviceSyncChange('reading')
      return
    }
    const rows: ReadingProgress[] = []
    this.progressByComicId.forEach((progress: ReadingProgress) => {
      rows.push(progress)
    })
    this.adapter.save(rows)
    if (this.adapter.saveSourceHistory !== undefined) {
      this.adapter.saveSourceHistory(this.listSourceHistory())
    }
    if (this.adapter.saveRemoteHistory !== undefined) this.adapter.saveRemoteHistory(this.listRemoteHistory())
  }
}

const appReaderSessionStores: Map<string, PersistentReaderSessionStore> = new Map<string, PersistentReaderSessionStore>()

/** EntryAbility bootstrap, Index and backups share one writer for this app file. */
export function appReaderSessionStore(filesDir: string): PersistentReaderSessionStore {
  const key = normalizeReaderSessionFilePath(filesDir)
  const existing = appReaderSessionStores.get(key)
  if (existing !== undefined) return existing
  const store = new PersistentReaderSessionStore(new AppFilesReaderSessionPersistenceAdapter(filesDir))
  appReaderSessionStores.set(key, store)
  return store
}

export function createReaderSessionConfigFromComic(
  comic: Comic,
  chapterId?: ChapterId,
  preparedPages?: Page[],
  includeChapterNavigation: boolean = true,
): ReaderSessionConfig {
  const sort = includeChapterNavigation || !chapterId ? chapterReadingSortFor(comic.id) : undefined
  const targetChapterId = chapterId !== undefined && chapterId.length > 0
    ? chapterId
    : (firstReaderChapter(comic.chapters, sourceChapterOrderFor(comic.sourceRuntimeId), undefined, sort)?.id ?? '')
  const chapter = comic.chapters.find((item) => item.id === targetChapterId)
  const pages = preparedPages ?? chapter?.pages ?? []
  // Downloads resolve images for one chapter and do not open the reader's
  // chapter picker or cross-chapter navigation.
  const picker = includeChapterNavigation ? readerChapterPickerChapters(comic.chapters,
    sourceChapterOrderFor(comic.sourceRuntimeId), sort) : []
  return {
    comicId: comic.id,
    chapterId: targetChapterId,
    chapterIds: picker.map((item) => item.id),
    continuationChapterIds: includeChapterNavigation ? continuationChapterIds(comic.chapters, targetChapterId, true, sort) : undefined,
    sourceChapterChronologyPending: comic.sourceRuntimeId !== undefined && needsSourceCatalogChronology(chapter, true),
    chapterTitles: picker.map((item) => readerChapterDisplayTitle(item)),
    title: comic.title,
    chapterTitle: chapter === undefined ? undefined : readerChapterDisplayTitle(chapter),
    readingFormat: readerFormatFromTags(comic.sourceMetadata?.tags),
    totalPages: preparedPages?.length ?? chapter?.pageCount ?? 0,
    deferredLocalArchive: comic.sourceKind === ComicSourceKind.LOCAL_FOLDER && chapter !== undefined &&
      isDeferredFolderArchiveChapter(chapter),
    pageUris: pages.map((page) => page.uri),
    pageIds: pages.map((page) => page.id),
    pageWidths: pages.map((page) => page.width),
    pageHeights: pages.map((page) => page.height),
    pageTextOverlays: pages.map((page) => page.sourceTextOverlay),
    pageRequiredImageDecodes: pages.map((page) => page.requiredImageDecode),
    pageTextPages: pages.map((page) => page.sourceText),
    pageTextRequests: pages.map((page) => page.sourceTextRequest),
    sourceRuntimeId: comic.sourceRuntimeId,
    sourceMangaUrl: comic.sourceRuntimeId === undefined ? undefined : comic.sourcePath,
    sourceKind: comic.sourceKind,
    remoteServerId: comic.remoteServerId,
  }
}

export function readerSessionFormat(config?: ReaderSessionConfig): ReaderSeriesFormat | undefined {
  if (config?.readingFormat !== undefined) return config.readingFormat
  // A chapter of split strip tiles can look like ordinary pages. Only
  // several unmistakably long original images establish a format by shape.
  let known = 0
  let long = 0
  const widths = config?.pageWidths ?? []
  const heights = config?.pageHeights ?? []
  for (let i = 0; i < widths.length && known < 6; i++) {
    const width = widths[i] ?? 0
    const height = heights[i] ?? 0
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) continue
    known++
    if (height >= width * 3) long++
  }
  return known >= 3 && long * 3 >= known * 2 ? 'webtoon' : undefined
}

export function getReaderSessionPageUri(config: ReaderSessionConfig, pageIndex: number): string {
  if (pageIndex < 0 || pageIndex >= config.pageUris.length) {
    return ''
  }
  return config.pageUris[pageIndex]
}

export function getReaderSessionPageId(config: ReaderSessionConfig, pageIndex: number): string | undefined {
  if (config.pageIds === undefined || pageIndex < 0 || pageIndex >= config.pageIds.length) {
    return undefined
  }
  return config.pageIds[pageIndex]
}

export function getReaderSessionPageWidth(config: ReaderSessionConfig, pageIndex: number): number | undefined {
  if (config.pageWidths === undefined || pageIndex < 0 || pageIndex >= config.pageWidths.length) {
    return undefined
  }
  return config.pageWidths[pageIndex]
}

export function getReaderSessionPageHeight(config: ReaderSessionConfig, pageIndex: number): number | undefined {
  if (config.pageHeights === undefined || pageIndex < 0 || pageIndex >= config.pageHeights.length) {
    return undefined
  }
  return config.pageHeights[pageIndex]
}

export function readerSessionConfigFor(
  context: common.UIAbilityContext,
  config: ReaderSessionConfig,
): ReaderSessionConfig {
  return config
}
