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
import { RemoteReadHistoryEntry, copyRemoteReadHistoryEntry } from './RemoteReaderSession'
import { AppFilesChapterReadStatePersistenceAdapter, ChapterReadStateOverride } from './ChapterReadStateStore'

export interface ChapterReadingState {
  comicId: ComicId
  chapterId: ChapterId
  position?: ReadingProgress
  isRead: boolean
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
  pageIds?: string[]
  pageWidths?: (number | undefined)[]
  pageHeights?: (number | undefined)[]
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
    pageIds: config.pageIds?.slice(),
    pageWidths: config.pageWidths?.slice(),
    pageHeights: config.pageHeights?.slice(),
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
  return alignSnapshotChapterCompletion({ progress, sourceHistory, remoteHistory, chapters })
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
    }
    writeAppTextFile(this.filePath, JSON.stringify(document))
    this.migrationPending = false
  }
}

export abstract class ReaderSessionStore {
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

  commitChapterReadStates(mutations: ChapterReadMutation[]): ChapterReadCommitResult {
    let changedCount = 0
    const committed = this.commitUserMutation((): void => {
      changedCount = this.markChapterReadStates(mutations)
    })
    return { committed, changedCount: committed ? changedCount : 0 }
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
        position: old?.position, isRead: mutation.isRead, updatedAt: Date.now() }
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
    this.chapterStates.set(key, { comicId: progress.comicId, chapterId: progress.chapterId,
      position: progress, isRead: this.chapterStates.get(key)?.isRead === true || progress.completed === true,
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
    }
    progressRows.forEach((progress: ReadingProgress): void => {
      this.progressByComicId.set(progress.comicId, progress)
      if (snapshot === undefined) this.recordChapterProgress(progress)
    })
    if (snapshot !== undefined) {
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

  saveProgress(progress: ReadingProgress): void {
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

  removeHistoryEntries(comicIds: ComicId[]): boolean {
    const ids = new Set<ComicId>(comicIds)
    const hasHistory = this.listProgress().some((row: ReadingProgress): boolean => ids.has(row.comicId)) ||
      this.listSourceHistory().some((row: SourceReadHistoryEntry): boolean => ids.has(row.comicId)) ||
      this.listRemoteHistory().some((row: RemoteReadHistoryEntry): boolean => ids.has(row.comicId))
    if (!hasHistory) return true
    return this.commitUserMutation((): void => {
      ids.forEach((comicId: ComicId): void => {
        this.progressByComicId.delete(comicId)
        this.sourceHistoryByComicId.delete(comicId)
        this.remoteHistoryByComicId.delete(comicId)
      })
      this.persistPending = true
    })
  }

  protected commitUserMutation(mutation: () => void): boolean {
    const current: ReaderSessionDocumentSnapshot = { progress: this.listProgress(),
      sourceHistory: this.listSourceHistory(), remoteHistory: this.listRemoteHistory(), chapters: this.listChapterStates() }
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
        remoteHistory: this.listRemoteHistory(), chapters: this.listChapterStates() })
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
