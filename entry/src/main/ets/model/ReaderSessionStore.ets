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
import { continuationChapterIds, firstReaderChapter, ReaderChapterOpenIntent } from './ReaderChapterSequence'
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
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFailureDetails } from './SourceRuntimeError'
import { SourceReadHistoryEntry } from './SourceReaderSession'
import { MangaMigrationReadPlan, MangaMigrationReadState } from './SourceMangaMigration'
import { RemoteReadHistoryEntry, copyRemoteReadHistoryEntry } from './RemoteReaderSession'
import { ReadingSessionRecord } from './ReadingStatistics'
import { AppFilesChapterReadStatePersistenceAdapter, ChapterReadStateOverride } from './ChapterReadStateStore'

export interface ChapterReadingState {
  comicId: ComicId
  chapterId: ChapterId
  sourceIdentity?: SyncReadingSource
  position?: ReadingProgress
  isRead: boolean
  bookmarked?: boolean
  updatedAt: number
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
  return JSON.stringify([comicId, chapterId])
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
  chapterIds: string[]
  continuationChapterIds?: string[]
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
  load(): ReadingProgress[]
  save(progress: ReadingProgress[]): void
  /** Optional same-document metadata channel for transient source history. */
  loadSourceHistory?(): SourceReadHistoryEntry[]
  saveSourceHistory?(history: SourceReadHistoryEntry[]): void
  loadRemoteHistory?(): RemoteReadHistoryEntry[]
  saveRemoteHistory?(history: RemoteReadHistoryEntry[]): void
  loadSnapshot?(): ReaderSessionDocumentSnapshot
  saveSnapshot?(snapshot: ReaderSessionDocumentSnapshot): void
  /** Serialize and stage a complete sibling off the UI thread; commit stays atomic. */
  saveSnapshotAsync?(snapshot: ReaderSessionDocumentSnapshot, token: number): Promise<string>
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

function alignSnapshotChapterCompletion(snapshot: ReaderSessionDocumentSnapshot): ReaderSessionDocumentSnapshot {
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

/** Local outbox belongs to the same atomic file as the corresponding page turn.
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
function writeReaderSessionSnapshotTask(filePath: string, document: ReaderSessionDocument,
  token: number): string {
  const payload = JSON.stringify(document)
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

  saveSnapshot(snapshot: ReaderSessionDocumentSnapshot): void {
    this.saveDocument(snapshot)
  }

  saveSnapshotAsync(snapshot: ReaderSessionDocumentSnapshot, token: number): Promise<string> {
    const document: ReaderSessionDocument = {
      schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
      progress: snapshot.progress, sourceHistory: snapshot.sourceHistory, remoteHistory: snapshot.remoteHistory,
      chapters: snapshot.chapters, readingSessions: snapshot.readingSessions, syncPositions: snapshot.syncPositions,
      syncActions: snapshot.syncActions,
    }
    return taskpool.execute(writeReaderSessionSnapshotTask, this.filePath, document, token) as Promise<string>
  }

  commitSnapshotAsync(token: string): void {
    if (BackupRestoreActivity.hasPendingRecovery()) {
      this.discardSnapshotAsync(token)
      throw new Error('sync_local_busy')
    }
    try {
      fs.renameSync(token, this.filePath)
      this.migrationPending = false
    } catch (error) {
      this.discardSnapshotAsync(token)
      throw error as Error
    }
  }

  discardSnapshotAsync(token: string): void {
    try {
      if (fs.accessSync(token)) fs.unlinkSync(token)
    } catch (_error) {
    }
  }

  requiresMigration(): boolean {
    return this.migrationPending
  }

  private loadDocument(persistedText?: string | null): ReaderSessionDocumentSnapshot {
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

  private saveDocument(snapshot: ReaderSessionDocumentSnapshot): void {
    if (BackupRestoreActivity.hasPendingRecovery()) {
      throw new Error('sync_local_busy')
    }
    writeAppTextFile(this.filePath, serializeReaderSessionForDevice(snapshot))
    this.migrationPending = false
  }
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
  protected readingSessions: ReadingSessionRecord[] = []

  listReadingSessions(): ReadingSessionRecord[] {
    return this.readingSessions.map((record: ReadingSessionRecord): ReadingSessionRecord => ({
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
    this.readingSessions = snapshot.readingSessions.map((record: ReadingSessionRecord): ReadingSessionRecord => ({
      comicId: record.comicId, chapterId: record.chapterId, startedAt: record.startedAt,
      endedAt: record.endedAt, pagesRead: record.pagesRead,
    }))
  }

  /** Replace every in-memory row with the snapshot. Persistent stores flush. */
  abstract restoreReadingState(snapshot: ReaderSessionReadingSnapshot): void

  addReadingSession(record: ReadingSessionRecord): void {
    this.readingSessions.push({ comicId: record.comicId, chapterId: record.chapterId,
      startedAt: record.startedAt, endedAt: record.endedAt, pagesRead: record.pagesRead })
    this.chapterStatesChanged()
  }
  protected readonly chapterStates: Map<string, ChapterReadingState> = new Map<string, ChapterReadingState>()
  protected readonly remoteHistoryByComicId: Map<ComicId, RemoteReadHistoryEntry> = new Map<ComicId, RemoteReadHistoryEntry>()
  abstract getProgress(comicId: ComicId): ReadingProgress | undefined
  abstract saveProgress(progress: ReadingProgress): void
  abstract removeProgress(comicId: ComicId): void
  abstract listProgress(): ReadingProgress[]
  /** Metadata for a source item that has been read without being shelved. */
  abstract getSourceHistory(comicId: ComicId): SourceReadHistoryEntry | undefined
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
    return this.chapterStates.get(chapterStateKey(comicId, chapterId))?.bookmarked === true
  }

  commitChapterBookmark(comicId: ComicId, chapterId: ChapterId, bookmarked: boolean, identity?: SyncReadingSource): boolean {
    const committed = this.commitUserMutation((): void => {
      const key = chapterStateKey(comicId, chapterId)
      const old = this.chapterStates.get(key)
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
        const previous = this.chapterStates.get(key)
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
      this.readingSessions = this.readingSessions.filter((record: ReadingSessionRecord): boolean => !comicIds.includes(record.comicId))
      this.chapterStatesChanged()
    })
  }

  getRemoteHistory(comicId: ComicId): RemoteReadHistoryEntry | undefined {
    const entry = this.remoteHistoryByComicId.get(comicId)
    return entry === undefined ? undefined : copyRemoteReadHistoryEntry(entry)
  }

  saveRemoteHistory(entry: RemoteReadHistoryEntry): void {
    const copied = copyRemoteReadHistoryEntry(entry)
    if (copied === undefined) return
    this.remoteHistoryByComicId.set(copied.comicId, copied)
    this.remoteHistoryChanged(false)
  }

  removeRemoteHistory(comicId: ComicId): void {
    if (this.remoteHistoryByComicId.delete(comicId)) this.remoteHistoryChanged(true)
  }

  listRemoteHistory(): RemoteReadHistoryEntry[] {
    const entries: RemoteReadHistoryEntry[] = []
    this.remoteHistoryByComicId.forEach((entry: RemoteReadHistoryEntry): void => {
      const copied = copyRemoteReadHistoryEntry(entry)
      if (copied !== undefined) entries.push(copied)
    })
    return entries
  }

  protected remoteHistoryChanged(_immediate: boolean): void {}

  getComicProgress(comic: Comic): ReadingProgress | undefined {
    return currentComicReadingProgress(comic, this.getProgress(comic.id))
  }

  getChapterProgress(comicId: ComicId, chapterId: ChapterId): ReadingProgress | undefined {
    return this.chapterStates.get(chapterStateKey(comicId, chapterId))?.position
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
    return this.chapterStates.get(chapterStateKey(comicId, chapterId))?.isRead === true
  }

  unreadChapterCount(comic: Comic): number | undefined {
    // Compare completeness with received rows; a complete source catalog may repeat IDs.
    // Count logical chapters only once, without treating duplicates as missing chapters.
    const shared = comic.sourceMetadata?.sharedChapterIds
    if (shared === undefined && comic.chapterCount > comic.chapters.length) return undefined
    const chapterIds = new Set<ChapterId>(shared ?? comic.chapters.map((chapter: Chapter): ChapterId => chapter.id))
    if (chapterIds.size === 0) return undefined
    let unread = 0
    chapterIds.forEach((chapterId: ChapterId): void => {
      if (!this.isChapterRead(comic.id, chapterId)) unread += 1
    })
    return unread
  }

  listChapterStates(): ChapterReadingState[] {
    return Array.from(this.chapterStates.values())
  }

  comicReadingState(comic: Comic): ComicReadingState {
    const shared = comic.sourceMetadata?.sharedChapterIds
    const ids = shared ?? comic.chapters.map((chapter: Chapter): ChapterId => chapter.id)
    if (ids.length > 0 && (shared !== undefined || comic.chapterCount <= ids.length) &&
      ids.every((id: ChapterId): boolean => this.isChapterRead(comic.id, id))) return 'completed'
    return ids.some((id: ChapterId): boolean => {
      const state = this.chapterStates.get(chapterStateKey(comic.id, id))
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
      const old = this.chapterStates.get(key)
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

  protected recordChapterProgress(progress: ReadingProgress): void {
    const key = chapterStateKey(progress.comicId, progress.chapterId)
    const old = this.chapterStates.get(key)
    const history = this.getSourceHistory(progress.comicId)
    const identity: SyncReadingSource | undefined = history === undefined ? old?.sourceIdentity :
      { source: history.sourceId, work: history.mangaId }
    this.chapterStates.set(key, { comicId: progress.comicId, chapterId: progress.chapterId,
      sourceIdentity: identity, position: progress, isRead: old?.isRead === true || progress.completed === true,
      bookmarked: old?.bookmarked,
      updatedAt: progress.updatedAt })
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

  saveProgress(progress: ReadingProgress): void {
    const copied = copyReadingProgressWithTimestamp(progress)
    copied.completed = this.isChapterRead(progress.comicId, progress.chapterId) || progress.completed
    this.progressByComicId.set(progress.comicId, copied)
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
  private readonly sourceHistoryByComicId: Map<ComicId, SourceReadHistoryEntry> = new Map<ComicId, SourceReadHistoryEntry>()
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

  pendingDeviceSyncPositions(): SyncReadingCapture[] {
    return this.syncPositions.slice()
  }

  pendingDeviceSyncActions(): SyncReadingActionCapture[] {
    return this.syncActions.slice()
  }

  /** Reload a replaced backup without flushing the pre-restore pending snapshot. */
  reload(): void {
    this.restoreSnapshot(true)
    this.flushPendingMigration()
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
    this.persistPending = true
    this.flush()
  }

  private flushPendingMigration(): void {
    if (this.adapter.requiresMigration !== undefined && this.adapter.requiresMigration()) {
      this.persistPending = true
      this.flush()
    }
  }

  private restoreSnapshot(replace: boolean = false): void {
    const snapshot = this.adapter.loadSnapshot === undefined ? undefined : this.adapter.loadSnapshot()
    const progressRows = snapshot === undefined ? this.adapter.load() : snapshot.progress
    const sourceHistory = snapshot !== undefined ? snapshot.sourceHistory :
      (this.adapter.loadSourceHistory === undefined ? [] : this.adapter.loadSourceHistory())
    const remoteHistory = snapshot !== undefined ? snapshot.remoteHistory ?? [] :
      (this.adapter.loadRemoteHistory === undefined ? [] : this.adapter.loadRemoteHistory())
    // Finish loading before retiring the old snapshot or its pending write.
    if (replace) {
      if (this.persistTimerId >= 0) clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
      this.persistPending = false
      this.persistBarrier += 1
      this.progressByComicId.clear()
      this.sourceHistoryByComicId.clear()
      this.remoteHistoryByComicId.clear()
      this.chapterStates.clear()
      this.readingSessions = []
    }
    progressRows.forEach((progress: ReadingProgress): void => {
      this.progressByComicId.set(progress.comicId, progress)
      if (snapshot === undefined) this.recordChapterProgress(progress)
    })
    if (snapshot !== undefined) {
      this.syncPositions = snapshot.syncPositions ?? []
      this.syncActions = snapshot.syncActions ?? []
      this.readingSessions = snapshot.readingSessions ?? []
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

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    return this.progressByComicId.get(comicId)
  }

  protected saveTransferredProgress(progress: ReadingProgress): void {
    const copied = JSON.parse(JSON.stringify(progress)) as ReadingProgress
    this.progressByComicId.set(copied.comicId, copied)
    this.recordChapterProgress(copied)
    this.schedulePersist()
  }

  saveProgress(progress: ReadingProgress): void {
    if (!allowDeviceSyncReaderProgress(progress)) return
    const copied = copyReadingProgressWithTimestamp(progress)
    copied.completed = this.isChapterRead(progress.comicId, progress.chapterId) || progress.completed
    this.progressByComicId.set(progress.comicId, copied)
    this.recordChapterProgress(copied)
    this.schedulePersist()
  }

  protected chapterStatesChanged(): void {
    this.schedulePersist()
  }

  protected remoteHistoryChanged(immediate: boolean): void {
    this.schedulePersist()
    if (immediate) this.flush()
  }

  removeProgress(comicId: ComicId): void {
    this.progressByComicId.delete(comicId)
    // Destructive progress changes must be visible to a new store immediately;
    // queued page turns can remain coalesced.
    this.persistPending = true
    this.flush()
  }

  removeHistoryEntries(comicIds: ComicId[], clear: boolean = false): boolean {
    const ids = new Set<ComicId>(comicIds)
    const hasHistory = this.listProgress().some((row: ReadingProgress): boolean => ids.has(row.comicId)) ||
      this.listSourceHistory().some((row: SourceReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      this.listRemoteHistory().some((row: RemoteReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      this.readingSessions.some((row: ReadingSessionRecord): boolean => ids.has(row.comicId))
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
      this.readingSessions = this.readingSessions.filter((record: ReadingSessionRecord): boolean => !ids.has(record.comicId))
      this.persistPending = true
    }, Array.from(ids).map((comicId: string): SyncReadingSignal => ({
      comicId, chapterId: '', kind: clear ? 'clear-history' : 'remove-history',
    })))
    return committed
  }

  protected commitUserMutation(mutation: () => void, actions: SyncReadingSignal[] = []): boolean {
    const current: ReaderSessionDocumentSnapshot = { progress: this.listProgress(),
      sourceHistory: this.listSourceHistory(), remoteHistory: this.listRemoteHistory(), chapters: this.listChapterStates(),
      readingSessions: this.listReadingSessions() }
    // Read-state changes also mutate recent/position objects, so retain a detached snapshot.
    const previous = JSON.parse(JSON.stringify(current)) as ReaderSessionDocumentSnapshot
    const pendingBefore = this.persistPending
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
    this.readingSessions = previous.readingSessions ?? []
    previous.progress.forEach((row: ReadingProgress): void => { this.progressByComicId.set(row.comicId, row) })
    previous.sourceHistory.forEach((row: SourceReadHistoryEntry): void => { this.sourceHistoryByComicId.set(row.comicId, row) })
    previous.remoteHistory?.forEach((row: RemoteReadHistoryEntry): void => { this.remoteHistoryByComicId.set(row.comicId, row) })
    previous.chapters.forEach((row: ChapterReadingState): void => {
      this.chapterStates.set(chapterStateKey(row.comicId, row.chapterId), row)
    })
    // Preserve an earlier page-turn write, but never retry a rejected user operation silently.
    this.persistPending = pendingBefore
    this.syncActions = actionsBefore
    if (pendingBefore) this.schedulePersist()
    return false
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
    if (copied === undefined) {
      return
    }
    this.sourceHistoryByComicId.set(copied.comicId, copied)
    this.schedulePersist()
  }

  removeSourceHistory(comicId: ComicId): void {
    this.sourceHistoryByComicId.delete(comicId)
    this.persistPending = true
    this.flush()
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

  private schedulePersist(): void {
    this.deviceSyncRevision++
    this.persistRevision += 1
    this.persistPending = true
    if (this.persistTimerId >= 0) {
      return
    }
    this.persistTimerId = setTimeout(() => {
      this.persistTimerId = -1
      void this.persistLatest()
    }, READER_PROGRESS_PERSIST_DEBOUNCE_MS)
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
      const plan = this.buildPersistPlan()
      if (plan === undefined) {
        this.flush()
        return
      }
      const staged = await this.adapter.saveSnapshotAsync(plan.snapshot, barrier)
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

  private buildPersistPlan(): ReaderSessionPersistPlan | undefined {
    if (this.adapter.saveSnapshot === undefined) return undefined
    const rows: ReadingProgress[] = []
    this.progressByComicId.forEach((progress: ReadingProgress) => {
      rows.push(progress)
    })
    const chapters = this.listChapterStates()
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
      snapshot: { progress: rows, sourceHistory: this.listSourceHistory(),
        remoteHistory: this.listRemoteHistory(), chapters, readingSessions: this.listReadingSessions(),
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
    const plan = this.buildPersistPlan()
    if (plan !== undefined) {
      this.adapter.saveSnapshot!(plan.snapshot)
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
): ReaderSessionConfig {
  const targetChapterId = chapterId !== undefined && chapterId.length > 0
    ? chapterId
    : (firstReaderChapter(comic.chapters, sourceChapterOrderFor(comic.sourceRuntimeId))?.id ?? '')
  const chapter = comic.chapters.find((item) => item.id === targetChapterId)
  return {
    comicId: comic.id,
    chapterId: targetChapterId,
    chapterIds: comic.chapters.map((item) => item.id),
    continuationChapterIds: continuationChapterIds(comic.chapters, targetChapterId),
    chapterTitles: comic.chapters.map((item) => readerChapterDisplayTitle(item)),
    title: comic.title,
    chapterTitle: chapter === undefined ? undefined : readerChapterDisplayTitle(chapter),
    readingFormat: readerFormatFromTags(comic.sourceMetadata?.tags),
    totalPages: chapter === undefined ? 0 : chapter.pageCount,
    deferredLocalArchive: comic.sourceKind === ComicSourceKind.LOCAL_FOLDER && chapter !== undefined &&
      isDeferredFolderArchiveChapter(chapter),
    pageUris: chapter === undefined ? [] : chapter.pages.map((page) => page.uri),
    pageIds: chapter === undefined ? [] : chapter.pages.map((page) => page.id),
    pageWidths: chapter === undefined ? [] : chapter.pages.map((page) => page.width),
    pageHeights: chapter === undefined ? [] : chapter.pages.map((page) => page.height),
    pageTextOverlays: chapter === undefined ? [] : chapter.pages.map((page) => page.sourceTextOverlay),
    pageRequiredImageDecodes: chapter === undefined ? [] : chapter.pages.map((page) => page.requiredImageDecode),
    pageTextPages: chapter === undefined ? [] : chapter.pages.map((page) => page.sourceText),
    pageTextRequests: chapter === undefined ? [] : chapter.pages.map((page) => page.sourceTextRequest),
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
