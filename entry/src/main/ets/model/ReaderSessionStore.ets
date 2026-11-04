import { SourceTextOverlay, sourceTextOverlay } from './SourceTextOverlay'
import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceTextPage, sourceTextPage, SourceTextPageRequest, sourceTextPageRequest } from './SourceTextPageDescriptor'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { writeAppTextFile } from './AppFileTextPersistence'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { continuationChapterIds, firstReaderChapter, ReaderChapterOpenIntent } from './ReaderChapterSequence'
import {
  Chapter,
  ChapterId,
  Comic,
  ComicId,
  ComicSourceKind,
  ReadingProgress,
  currentComicReadingProgress,
  readingProgressPageIndex,
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFailureDetails } from './SourceRuntimeError'
import { SourceReadHistoryEntry } from './SourceReaderSession'
import { MangaMigrationReadPlan, MangaMigrationReadState } from './SourceMangaMigration'
import { RemoteReadHistoryEntry, copyRemoteReadHistoryEntry } from './RemoteReaderSession'
import { ReadingSessionRecord } from './ReadingStatistics'
import { mergeSyncWorks, SyncChapter, SyncPosition, SyncRecent, SyncWork, SyncWorkIdentity } from '../historySync/HistorySyncModel'
import { sourceLibraryComicId } from './SourceLibraryComic'
import { AppFilesChapterReadStatePersistenceAdapter, ChapterReadStateOverride } from './ChapterReadStateStore'

export interface ChapterReadingState {
  comicId: ComicId
  chapterId: ChapterId
  position?: ReadingProgress
  isRead: boolean
  bookmarked?: boolean
  updatedAt: number
  syncReadAt?: number
  syncPositionAt?: number
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
  totalPages: number
  pageUris: string[]
  /** Original public image URIs retained by newer offline manifests, when available. */
  sourceOriginalImageUris?: (string | undefined)[]
  pageIds?: string[]
  pageWidths?: (number | undefined)[]
  pageHeights?: (number | undefined)[]
  pageTextOverlays?: (SourceTextOverlay | null | undefined)[]
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
    totalPages: config.totalPages,
    pageUris: config.pageUris.slice(),
    sourceOriginalImageUris: config.sourceOriginalImageUris?.slice(),
    pageIds: config.pageIds?.slice(),
    pageWidths: config.pageWidths?.slice(),
    pageHeights: config.pageHeights?.slice(),
    pageTextOverlays: config.pageTextOverlays?.map((page: SourceTextOverlay | null | undefined): SourceTextOverlay | undefined =>
      page === undefined || page === null ? undefined : sourceTextOverlay(page)),
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
  /** Legacy data is readable while its normalized document still awaits commit. */
  requiresMigration?(): boolean
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

interface SourceSyncIdentity extends SyncWorkIdentity {
  deletedAt?: number
}

interface ReaderSessionDocument {
  schemaVersion: number
  progress: ReadingProgress[]
  sourceHistory?: SourceReadHistoryEntry[]
  remoteHistory?: RemoteReadHistoryEntry[]
  chapters?: ChapterReadingState[]
  readingSessions?: ReadingSessionRecord[]
  sourceSyncIdentities?: SourceSyncIdentity[]
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
  sourceSyncIdentities?: SourceSyncIdentity[]
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
    readingSessions: document.readingSessions ?? [], sourceSyncIdentities: document.sourceSyncIdentities ?? [] })
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
    sourceSyncIdentities: snapshot.sourceSyncIdentities,
  }
  return JSON.stringify(normalized)
}

function normalizeReaderSessionFilePath(filesDir: string): string {
  let dir = filesDir.trim()
  while (dir.length > 1 && dir.endsWith('/')) {
    dir = dir.substring(0, dir.length - 1)
  }
  return dir.length === 0 ? READER_PROGRESS_PERSISTENCE_FILE_NAME : `${dir}/${READER_PROGRESS_PERSISTENCE_FILE_NAME}`
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

  loadSnapshot(): ReaderSessionDocumentSnapshot {
    return this.loadDocument()
  }

  saveSnapshot(snapshot: ReaderSessionDocumentSnapshot): void {
    this.saveDocument(snapshot)
  }

  requiresMigration(): boolean {
    return this.migrationPending
  }

  private loadDocument(): ReaderSessionDocumentSnapshot {
    let document: ReaderSessionDocument
    try {
      document = fs.accessSync(this.filePath)
        ? JSON.parse(fs.readTextSync(this.filePath, { encoding: 'utf-8' })) as ReaderSessionDocument
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
    const document: ReaderSessionDocument = {
      schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
      progress: snapshot.progress,
      sourceHistory: snapshot.sourceHistory,
      remoteHistory: snapshot.remoteHistory,
      chapters: snapshot.chapters,
      readingSessions: snapshot.readingSessions,
      sourceSyncIdentities: snapshot.sourceSyncIdentities,
    }
    writeAppTextFile(this.filePath, JSON.stringify(document))
    this.migrationPending = false
  }
}

export abstract class ReaderSessionStore {
  protected readingSessions: ReadingSessionRecord[] = []

  listReadingSessions(): ReadingSessionRecord[] {
    return this.readingSessions.map((record: ReadingSessionRecord): ReadingSessionRecord => ({
      comicId: record.comicId, chapterId: record.chapterId, startedAt: record.startedAt,
      endedAt: record.endedAt, pagesRead: record.pagesRead,
    }))
  }

  addReadingSession(record: ReadingSessionRecord): void {
    this.readingSessions.push({ comicId: record.comicId, chapterId: record.chapterId,
      startedAt: record.startedAt, endedAt: record.endedAt, pagesRead: record.pagesRead })
    this.chapterStatesChanged()
  }
  protected readonly chapterStates: Map<string, ChapterReadingState> = new Map<string, ChapterReadingState>()
  protected readonly remoteHistoryByComicId: Map<ComicId, RemoteReadHistoryEntry> = new Map<ComicId, RemoteReadHistoryEntry>()
  /** Keep exact source identities even for chapters marked before the first read. */
  rememberSourceSyncIdentity(_comicId: ComicId, _sourceId: string, _mangaId: string): void {}
  setSourceSyncShelf(_comics: Comic[]): void {}

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

  commitChapterReadStates(mutations: ChapterReadMutation[]): ChapterReadCommitResult {
    let changedCount = 0
    const committed = this.commitUserMutation((): void => {
      changedCount = this.markChapterReadStates(mutations)
    })
    return { committed, changedCount: committed ? changedCount : 0 }
  }

  isChapterBookmarked(comicId: ComicId, chapterId: ChapterId): boolean {
    return this.chapterStates.get(chapterStateKey(comicId, chapterId))?.bookmarked === true
  }

  commitChapterBookmark(comicId: ComicId, chapterId: ChapterId, bookmarked: boolean): boolean {
    return this.commitUserMutation((): void => {
      const key = chapterStateKey(comicId, chapterId)
      const old = this.chapterStates.get(key)
      this.chapterStates.set(key, { comicId, chapterId, position: old?.position,
        isRead: old?.isRead === true, bookmarked, updatedAt: old?.updatedAt ?? Date.now(),
        syncReadAt: old?.syncReadAt ?? old?.updatedAt ?? 0, syncPositionAt: old?.syncPositionAt })
      this.chapterStatesChanged()
    })
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
          bookmarked: previous?.bookmarked === true || state.bookmarked === true, updatedAt: state.updatedAt,
          syncReadAt: Math.max(previous?.syncReadAt ?? previous?.updatedAt ?? 0, state.updatedAt),
          syncPositionAt: previous?.syncPositionAt }
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

  protected commitUserMutation(mutation: () => void): boolean {
    mutation()
    return this.flush()
  }

  removeHistoryEntries(comicIds: ComicId[]): boolean {
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

  isChapterRead(comicId: ComicId, chapterId: ChapterId): boolean {
    return this.chapterStates.get(chapterStateKey(comicId, chapterId))?.isRead === true
  }

  unreadChapterCount(comic: Comic): number | undefined {
    // Compare completeness with received rows; a complete source catalog may repeat IDs.
    // Count logical chapters only once, without treating duplicates as missing chapters.
    const chapterIds = new Set<ChapterId>(comic.chapters.map((chapter: Chapter): ChapterId => chapter.id))
    if (chapterIds.size === 0 || comic.chapterCount > comic.chapters.length) return undefined
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
    if (comic.chapters.length > 0 && comic.chapters.every((chapter: Chapter): boolean =>
      this.isChapterRead(comic.id, chapter.id))) return 'completed'
    return comic.chapters.some((chapter: Chapter): boolean => {
      const state = this.chapterStates.get(chapterStateKey(comic.id, chapter.id))
      return state !== undefined && (state.isRead || (state.position !== undefined &&
        state.position.totalPages > 0 && state.position.pageIndex > 0))
    }) ? 'reading' : 'unread'
  }

  markChapterReadState(comicId: ComicId, chapterId: ChapterId, isRead: boolean): void {
    this.markChapterReadStates([{ comicId, chapterId, isRead }])
  }

  markChapterReadStates(mutations: ChapterReadMutation[]): number {
    let changed = 0
    mutations.forEach((mutation: ChapterReadMutation): void => {
      if (mutation.comicId.length === 0 || mutation.chapterId.length === 0) return
      const key = chapterStateKey(mutation.comicId, mutation.chapterId)
      const old = this.chapterStates.get(key)
      const state: ChapterReadingState = { comicId: mutation.comicId, chapterId: mutation.chapterId,
        position: old?.position, isRead: mutation.isRead, bookmarked: old?.bookmarked, updatedAt: Date.now(),
        syncPositionAt: old?.syncPositionAt }
      state.syncReadAt = Math.max(state.updatedAt, (old?.syncReadAt ?? old?.updatedAt ?? 0) + 1)
      if (!mutation.isRead && state.position !== undefined) {
        const previous = state.position
        state.syncPositionAt = Math.max(state.updatedAt, (old?.syncPositionAt ?? previous.updatedAt) + 1)
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
    const previous = this.chapterStates.get(key)
    const isRead = previous?.isRead === true || progress.completed === true
    this.chapterStates.set(key, { comicId: progress.comicId, chapterId: progress.chapterId,
      position: progress, isRead, bookmarked: previous?.bookmarked, updatedAt: progress.updatedAt,
      syncReadAt: previous === undefined || previous.isRead !== isRead ? progress.updatedAt :
        previous.syncReadAt ?? previous.updatedAt, syncPositionAt: progress.updatedAt })
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

  flush(): boolean {
    return true
  }
}

export class PersistentReaderSessionStore extends ReaderSessionStore {
  private readonly adapter: ReaderSessionPersistenceAdapter
  private readonly progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
  private readonly sourceHistoryByComicId: Map<ComicId, SourceReadHistoryEntry> = new Map<ComicId, SourceReadHistoryEntry>()
  private readonly sourceSyncShelf = new Map<ComicId, Comic>()
  private readonly sourceSyncIdentities = new Map<ComicId, SourceSyncIdentity>()
  private onCommittedLocally: () => void = (): void => {}
  private sourceReloadRevision: number = 0
  private applyingSourceSync: boolean = false
  private persistTimerId: number = -1
  private persistPending: boolean = false

  constructor(adapter: ReaderSessionPersistenceAdapter) {
    super()
    this.adapter = adapter
    this.restoreSnapshot()
    this.flushPendingMigration()
  }

  /** Reload a replaced backup without flushing the pre-restore pending snapshot. */
  reload(): void {
    this.restoreSnapshot(true)
    this.sourceReloadRevision += 1
    this.flushPendingMigration()
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
      this.progressByComicId.clear()
      this.sourceHistoryByComicId.clear()
      this.remoteHistoryByComicId.clear()
      this.chapterStates.clear()
      this.readingSessions = []
      this.sourceSyncIdentities.clear()
    }
    progressRows.forEach((progress: ReadingProgress): void => {
      this.progressByComicId.set(progress.comicId, progress)
      if (snapshot === undefined) this.recordChapterProgress(progress)
    })
    if (snapshot !== undefined) {
      this.readingSessions = snapshot.readingSessions ?? []
      snapshot.sourceSyncIdentities?.forEach((identity: SourceSyncIdentity): void => {
        this.sourceSyncIdentities.set(sourceLibraryComicId(identity.sourceId, identity.mangaId), identity)
      })
      snapshot.chapters.forEach((state: ChapterReadingState): void => {
        this.chapterStates.set(chapterStateKey(state.comicId, state.chapterId), state)
      })
    }
    sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
        const copied = copySourceReadHistoryEntry(entry)
        if (copied !== undefined) {
          this.sourceHistoryByComicId.set(copied.comicId, copied)
        this.rememberSourceSyncIdentity(copied.comicId, copied.sourceId, copied.mangaId)
        }
    })
    remoteHistory.forEach((entry: RemoteReadHistoryEntry): void => {
      const copied = copyRemoteReadHistoryEntry(entry)
      if (copied !== undefined) this.remoteHistoryByComicId.set(copied.comicId, copied)
    })
  }

  sourceSyncReloadRevision(): number {
    return this.sourceReloadRevision
  }

  onLocalHistoryCommitted(listener: () => void): void {
    this.onCommittedLocally = listener
  }

  rememberSourceSyncIdentity(comicId: ComicId, sourceId: string, mangaId: string): void {
    if (sourceId.length === 0 || mangaId.length === 0 || sourceLibraryComicId(sourceId, mangaId) !== comicId) return
    if (!this.sourceSyncIdentities.has(comicId)) this.sourceSyncIdentities.set(comicId, { sourceId, mangaId })
  }

  setSourceSyncShelf(comics: Comic[]): void {
    this.sourceSyncShelf.clear()
    comics.forEach((comic: Comic): void => {
      const sourceId = comic.sourceRuntimeId
      const mangaId = comic.remoteResourceId
      if (sourceId !== undefined && mangaId !== undefined && comic.remoteServerId === undefined &&
        sourceLibraryComicId(sourceId, mangaId) === comic.id) {
        this.rememberSourceSyncIdentity(comic.id, sourceId, mangaId)
        this.sourceSyncShelf.set(comic.id, comic)
      }
    })
  }

  sourceSyncSnapshot(): SyncWork[] {
    const chapters = new Map<string, SyncChapter[]>()
    this.chapterStates.forEach((row: ChapterReadingState): void => {
      if (!this.sourceSyncIdentities.has(row.comicId)) return
      const pos = row.position
      const position: SyncPosition | undefined = pos !== undefined && pos.totalPages > pos.pageIndex &&
        pos.pageIndex >= 0 ? { updatedAt: row.syncPositionAt ?? pos.updatedAt, pageIndex: pos.pageIndex,
          totalPages: pos.totalPages, columnMode: pos.columnMode } : undefined
      const readAt = row.syncReadAt ?? row.updatedAt
      if (readAt === 0 && position === undefined) return
      const chapter: SyncChapter = { chapterId: row.chapterId, readAt, isRead: row.isRead, position }
      const workChapters = chapters.get(row.comicId)
      if (workChapters === undefined) chapters.set(row.comicId, [chapter])
      else workChapters.push(chapter)
    })
    const works: SyncWork[] = []
    this.sourceSyncIdentities.forEach((identity: SourceSyncIdentity, comicId: ComicId): void => {
      const progress = this.progressByComicId.get(comicId)
      const history = this.sourceHistoryByComicId.get(comicId)
      const shelf = this.sourceSyncShelf.get(comicId)
      const workChapters = chapters.get(comicId) ?? []
      const deletedAt = identity.deletedAt
      let recent: SyncRecent | undefined = deletedAt === undefined ? undefined : { updatedAt: deletedAt, deleted: true }
      if (progress !== undefined && progress.updatedAt > (deletedAt ?? -1) &&
        workChapters.some((chapter: SyncChapter): boolean =>
          chapter.chapterId === progress.chapterId && chapter.position !== undefined)) {
        // A shelved source comic is opened through LibraryStore and may never
        // create a transient SourceReadHistoryEntry. Use its exact shelf identity.
        const sourceHistory = history?.chapterId === progress.chapterId ? history : undefined
        const title = sourceHistory?.title ?? shelf?.title.trim() ?? ''
        if (title.length > 0) {
          const chapterTitle = sourceHistory?.chapterTitle ?? shelf?.chapters.find(
            (chapter: Chapter): boolean => chapter.id === progress.chapterId)?.title.trim()
          recent = { updatedAt: progress.updatedAt, deleted: false, chapterId: progress.chapterId,
            title, chapterTitle: chapterTitle === '' ? undefined : chapterTitle }
        }
      }
      if (recent !== undefined || workChapters.length > 0) {
        works.push({ sourceId: identity.sourceId, mangaId: identity.mangaId, recent, chapters: workChapters })
      }
    })
    return mergeSyncWorks(works, [])
  }

  /** Merge against the live store again after the network request, then commit
   * all affected reader maps and deletion markers in the same file transaction.
   * Imported history must not trigger tracker writes or local reading statistics.
   */
  applySourceSync(remote: SyncWork[]): boolean {
    const local = this.sourceSyncSnapshot()
    const merged = mergeSyncWorks(local, remote)
    if (JSON.stringify(local) === JSON.stringify(merged)) return false
    this.applyingSourceSync = true
    try {
      const committed = this.commitUserMutation((): void => {
        merged.forEach((work: SyncWork): void => { this.applySourceSyncWork(work) })
        this.persistPending = true
      })
      if (!committed) throw new Error('storage')
      return true
    } finally {
      this.applyingSourceSync = false
    }
  }

  private applySourceSyncWork(work: SyncWork): void {
    const comicId = sourceLibraryComicId(work.sourceId, work.mangaId)
    const identity = this.sourceSyncIdentities.get(comicId)
    if (identity !== undefined && (identity.sourceId !== work.sourceId || identity.mangaId !== work.mangaId)) return
    this.rememberSourceSyncIdentity(comicId, work.sourceId, work.mangaId)
    work.chapters.forEach((chapter: SyncChapter): void => {
      const key = chapterStateKey(comicId, chapter.chapterId)
      const old = this.chapterStates.get(key)
      const wire = chapter.position
      const previous = old?.position
      const position: ReadingProgress | undefined = wire === undefined ? previous :
        { comicId, chapterId: chapter.chapterId, pageIndex: wire.pageIndex, totalPages: wire.totalPages,
          progressRatio: (wire.pageIndex + 1) / wire.totalPages, completed: chapter.isRead,
          updatedAt: previous?.updatedAt === undefined || (old?.syncPositionAt ?? previous.updatedAt) !== wire.updatedAt
            ? wire.updatedAt : previous.updatedAt, columnMode: wire.columnMode }
      if (position !== undefined && previous !== undefined && previous.pageIndex === position.pageIndex &&
        (old?.syncPositionAt ?? previous.updatedAt) === wire?.updatedAt) position.pageId = previous.pageId
      this.chapterStates.set(key, { comicId, chapterId: chapter.chapterId, position, isRead: chapter.isRead,
        bookmarked: old?.bookmarked, updatedAt: Math.max(chapter.readAt, wire?.updatedAt ?? 0),
        syncReadAt: chapter.readAt, syncPositionAt: wire?.updatedAt })
    })
    const recent = work.recent
    if (recent === undefined) return
    if (recent.deleted) {
      this.sourceSyncIdentities.set(comicId, { sourceId: work.sourceId, mangaId: work.mangaId, deletedAt: recent.updatedAt })
      const progress = this.progressByComicId.get(comicId)
      if (progress === undefined || progress.updatedAt <= recent.updatedAt) {
        this.progressByComicId.delete(comicId)
        this.sourceHistoryByComicId.delete(comicId)
      }
      return
    }
    const chapterId = recent.chapterId as string
    const state = this.chapterStates.get(chapterStateKey(comicId, chapterId))
    const existing = this.progressByComicId.get(comicId)
    if (existing !== undefined && existing.updatedAt > recent.updatedAt) return
    if (state?.position !== undefined) {
      const pos = state.position
      this.progressByComicId.set(comicId, { comicId, chapterId, pageId: pos.pageId, pageIndex: pos.pageIndex,
        totalPages: pos.totalPages, progressRatio: pos.progressRatio, completed: state.isRead,
        updatedAt: recent.updatedAt, columnMode: pos.columnMode })
      const metadata = this.sourceHistoryByComicId.get(comicId)
      this.sourceHistoryByComicId.set(comicId, { comicId, chapterId, sourceId: work.sourceId, mangaId: work.mangaId,
        title: recent.title as string, chapterTitle: recent.chapterTitle, mangaUrl: metadata?.mangaUrl,
        coverUri: metadata?.coverUri, sourceName: metadata?.sourceName })
    }
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
    const copied = copyReadingProgressWithTimestamp(progress)
    const identity = this.sourceSyncIdentities.get(progress.comicId)
    if (identity !== undefined) {
      const oldChapter = this.chapterStates.get(chapterStateKey(progress.comicId, progress.chapterId))
      const latest = Math.max(identity.deletedAt ?? 0, this.getProgress(progress.comicId)?.updatedAt ?? 0,
        oldChapter?.syncReadAt ?? 0, oldChapter?.syncPositionAt ?? 0)
      copied.updatedAt = Math.max(copied.updatedAt, latest + 1)
    }
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

  removeHistoryEntries(comicIds: ComicId[]): boolean {
    const ids = new Set<ComicId>(comicIds)
    const hasHistory = this.listProgress().some((row: ReadingProgress): boolean => ids.has(row.comicId)) ||
      this.listSourceHistory().some((row: SourceReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      this.listRemoteHistory().some((row: RemoteReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      this.readingSessions.some((row: ReadingSessionRecord): boolean => ids.has(row.comicId))
    if (!hasHistory) return true
    return this.commitUserMutation((): void => {
      ids.forEach((comicId: ComicId): void => {
        const identity = this.sourceSyncIdentities.get(comicId)
        if (identity !== undefined && this.progressByComicId.has(comicId)) {
          const recent = this.progressByComicId.get(comicId) as ReadingProgress
          this.sourceSyncIdentities.set(comicId, { sourceId: identity.sourceId, mangaId: identity.mangaId,
            deletedAt: Math.max(Date.now(), recent.updatedAt + 1, (identity.deletedAt ?? 0) + 1) })
        }
        this.progressByComicId.delete(comicId)
        this.sourceHistoryByComicId.delete(comicId)
        this.remoteHistoryByComicId.delete(comicId)
      })
      this.readingSessions = this.readingSessions.filter((record: ReadingSessionRecord): boolean => !ids.has(record.comicId))
      this.persistPending = true
    })
  }

  protected commitUserMutation(mutation: () => void): boolean {
    const current: ReaderSessionDocumentSnapshot = { progress: this.listProgress(),
      sourceHistory: this.listSourceHistory(), remoteHistory: this.listRemoteHistory(), chapters: this.listChapterStates(),
      readingSessions: this.listReadingSessions(), sourceSyncIdentities: Array.from(this.sourceSyncIdentities.values()) }
    // Read-state changes also mutate recent/position objects, so retain a detached snapshot.
    const previous = JSON.parse(JSON.stringify(current)) as ReaderSessionDocumentSnapshot
    const pendingBefore = this.persistPending
    try {
      mutation()
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
    this.sourceSyncIdentities.clear()
    previous.sourceSyncIdentities?.forEach((identity: SourceSyncIdentity): void => {
      this.sourceSyncIdentities.set(sourceLibraryComicId(identity.sourceId, identity.mangaId), identity)
    })
    previous.progress.forEach((row: ReadingProgress): void => { this.progressByComicId.set(row.comicId, row) })
    previous.sourceHistory.forEach((row: SourceReadHistoryEntry): void => { this.sourceHistoryByComicId.set(row.comicId, row) })
    previous.remoteHistory?.forEach((row: RemoteReadHistoryEntry): void => { this.remoteHistoryByComicId.set(row.comicId, row) })
    previous.chapters.forEach((row: ChapterReadingState): void => {
      this.chapterStates.set(chapterStateKey(row.comicId, row.chapterId), row)
    })
    // Preserve an earlier page-turn write, but never retry a rejected user operation silently.
    this.persistPending = pendingBefore
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
    this.rememberSourceSyncIdentity(copied.comicId, copied.sourceId, copied.mangaId)
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
    try {
      this.persist()
      // Only a completed commit discharges pending work. A later normal boundary can retry a failure.
      this.persistPending = false
      if (!this.applyingSourceSync) this.onCommittedLocally()
      return true
    } catch (_error) {
      DiagnosticLogger.warn('reader_session_store', 'persist_failed', '[ReaderProgress] persist_failed pending=true')
      return false
    }
  }

  private schedulePersist(): void {
    this.persistPending = true
    if (this.persistTimerId >= 0) {
      return
    }
    this.persistTimerId = setTimeout(() => {
      this.persistTimerId = -1
      this.flush()
    }, READER_PROGRESS_PERSIST_DEBOUNCE_MS)
  }

  private persist(): void {
    const rows: ReadingProgress[] = []
    this.progressByComicId.forEach((progress: ReadingProgress) => {
      rows.push(progress)
    })
    if (this.adapter.saveSnapshot !== undefined) {
      this.adapter.saveSnapshot({ progress: rows, sourceHistory: this.listSourceHistory(),
        remoteHistory: this.listRemoteHistory(), chapters: this.listChapterStates(), readingSessions: this.listReadingSessions(),
        sourceSyncIdentities: Array.from(this.sourceSyncIdentities.values()) })
      return
    }
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
    totalPages: chapter === undefined ? 0 : chapter.pageCount,
    pageUris: chapter === undefined ? [] : chapter.pages.map((page) => page.uri),
    pageIds: chapter === undefined ? [] : chapter.pages.map((page) => page.id),
    pageWidths: chapter === undefined ? [] : chapter.pages.map((page) => page.width),
    pageHeights: chapter === undefined ? [] : chapter.pages.map((page) => page.height),
    pageTextOverlays: chapter === undefined ? [] : chapter.pages.map((page) => page.sourceTextOverlay),
    pageTextPages: chapter === undefined ? [] : chapter.pages.map((page) => page.sourceText),
    pageTextRequests: chapter === undefined ? [] : chapter.pages.map((page) => page.sourceTextRequest),
    sourceRuntimeId: comic.sourceRuntimeId,
    sourceMangaUrl: comic.sourceRuntimeId === undefined ? undefined : comic.sourcePath,
    sourceKind: comic.sourceKind,
    remoteServerId: comic.remoteServerId,
  }
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
