import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import {
  Chapter,
  ChapterId,
  Comic,
  ComicId,
  ReadingProgress,
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { SourceReadHistoryEntry } from './SourceReaderSession'

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
  chapterTitles?: string[]
  title?: string
  chapterTitle?: string
  totalPages: number
  pageUris: string[]
  pageIds?: string[]
  pageWidths?: (number | undefined)[]
  pageHeights?: (number | undefined)[]
  sourceRuntimeId?: string
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

export interface ReaderSessionPersistenceAdapter {
  load(): ReadingProgress[]
  save(progress: ReadingProgress[]): void
  /** Optional same-document metadata channel for transient source history. */
  loadSourceHistory?(): SourceReadHistoryEntry[]
  saveSourceHistory?(history: SourceReadHistoryEntry[]): void
}

export const READER_PROGRESS_PERSISTENCE_FILE_NAME: string = 'reader-sessions.v1.json'
/**
 * v2 adds stable metadata for history entries opened directly from a source.
 * Keep the file name stable so existing v1 progress is migrated in place.
 */
export const READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 2
const READER_PROGRESS_LEGACY_SCHEMA_VERSION = 1
export const READER_PROGRESS_PERSIST_DEBOUNCE_MS: number = 3000

interface ReaderSessionDocument {
  schemaVersion: number
  progress: ReadingProgress[]
  sourceHistory?: SourceReadHistoryEntry[]
}

interface ReaderSessionDocumentSnapshot {
  progress: ReadingProgress[]
  sourceHistory: SourceReadHistoryEntry[]
}

function normalizeReaderSessionFilePath(filesDir: string): string {
  let dir = filesDir.trim()
  while (dir.length > 1 && dir.endsWith('/')) {
    dir = dir.substring(0, dir.length - 1)
  }
  return dir.length === 0 ? READER_PROGRESS_PERSISTENCE_FILE_NAME : `${dir}/${READER_PROGRESS_PERSISTENCE_FILE_NAME}`
}

function closeReaderSessionFile(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

export class AppFilesReaderSessionPersistenceAdapter implements ReaderSessionPersistenceAdapter {
  private readonly filePath: string

  constructor(filesDir: string) {
    this.filePath = normalizeReaderSessionFilePath(filesDir)
  }

  load(): ReadingProgress[] {
    return this.loadDocument().progress
  }

  loadSourceHistory(): SourceReadHistoryEntry[] {
    return this.loadDocument().sourceHistory
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

  private loadDocument(): ReaderSessionDocumentSnapshot {
    if (!fs.accessSync(this.filePath)) {
      return { progress: [], sourceHistory: [] }
    }
    try {
      const payload = fs.readTextSync(this.filePath, { encoding: 'utf-8' })
      const document = JSON.parse(payload) as ReaderSessionDocument
      if (document.schemaVersion === READER_PROGRESS_LEGACY_SCHEMA_VERSION) {
        if (!Array.isArray(document.progress)) {
          return { progress: [], sourceHistory: [] }
        }
        // v1 did not know about unshelved source history. Its normal reader
        // progress remains valid and will be written back as v2 on next save.
        return { progress: document.progress, sourceHistory: [] }
      }
      if (document.schemaVersion !== READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION) {
        console.warn(`Unsupported reader progress schema version: ${document.schemaVersion}`)
        return { progress: [], sourceHistory: [] }
      }
      if (!Array.isArray(document.progress)) {
        return { progress: [], sourceHistory: [] }
      }
      const sourceHistory: SourceReadHistoryEntry[] = []
      if (Array.isArray(document.sourceHistory)) {
        document.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
          const copied = copySourceReadHistoryEntry(entry)
          if (copied !== undefined) {
            sourceHistory.push(copied)
          }
        })
      }
      return { progress: document.progress, sourceHistory }
    } catch (_err) {
      return { progress: [], sourceHistory: [] }
    }
  }

  private saveDocument(snapshot: ReaderSessionDocumentSnapshot): void {
    const document: ReaderSessionDocument = {
      schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
      progress: snapshot.progress,
      sourceHistory: snapshot.sourceHistory,
    }
    let file: fs.File | undefined = undefined
    try {
      file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, JSON.stringify(document), { encoding: 'utf-8' })
    } catch (_err) {
    } finally {
      closeReaderSessionFile(file)
    }
  }
}

export abstract class ReaderSessionStore {
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
  abstract flush(): void

  restorePageIndex(config: ReaderSessionConfig): number {
    const progress = this.getProgress(config.comicId)
    if (progress === undefined || progress.chapterId !== config.chapterId) {
      return 0
    }
    if (config.totalPages <= 0) {
      return 0
    }
    if (progress.pageIndex < 0) {
      return 0
    }
    if (progress.pageIndex >= config.totalPages) {
      return config.totalPages - 1
    }
    return Math.floor(progress.pageIndex)
  }

  restoreColumnMode(
    config: ReaderSessionConfig,
    fallback: 'odd_left' | 'even_left',
  ): 'odd_left' | 'even_left' {
    const progress = this.getProgress(config.comicId)
    if (progress === undefined || progress.chapterId !== config.chapterId) {
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
    this.progressByComicId.set(progress.comicId, copyReadingProgressWithTimestamp(progress))
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

  flush(): void {
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
    adapter.load().forEach((progress: ReadingProgress) => {
      this.progressByComicId.set(progress.comicId, progress)
    })
    if (adapter.loadSourceHistory !== undefined) {
      adapter.loadSourceHistory().forEach((entry: SourceReadHistoryEntry): void => {
        const copied = copySourceReadHistoryEntry(entry)
        if (copied !== undefined) {
          this.sourceHistoryByComicId.set(copied.comicId, copied)
        }
      })
    }
  }

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    return this.progressByComicId.get(comicId)
  }

  saveProgress(progress: ReadingProgress): void {
    this.progressByComicId.set(progress.comicId, copyReadingProgressWithTimestamp(progress))
    this.schedulePersist()
  }

  removeProgress(comicId: ComicId): void {
    this.progressByComicId.delete(comicId)
    // Destructive progress changes must be visible to a new store immediately;
    // queued page turns can remain coalesced.
    this.persistPending = true
    this.flush()
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

  flush(): void {
    if (this.persistTimerId >= 0) {
      clearTimeout(this.persistTimerId)
      this.persistTimerId = -1
    }
    if (!this.persistPending) {
      return
    }
    this.persistPending = false
    this.persist()
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
    this.adapter.save(rows)
    if (this.adapter.saveSourceHistory !== undefined) {
      this.adapter.saveSourceHistory(this.listSourceHistory())
    }
  }
}

export function createReaderSessionConfigFromComic(
  comic: Comic,
  chapterId?: ChapterId,
): ReaderSessionConfig {
  const targetChapterId = chapterId !== undefined && chapterId.length > 0
    ? chapterId
    : (comic.chapters.length > 0 ? comic.chapters[0].id : '')
  const chapter = comic.chapters.find((item) => item.id === targetChapterId)
  return {
    comicId: comic.id,
    chapterId: targetChapterId,
    chapterIds: comic.chapters.map((item) => item.id),
    chapterTitles: comic.chapters.map((item) => readerChapterDisplayTitle(item)),
    title: comic.title,
    chapterTitle: chapter === undefined ? undefined : readerChapterDisplayTitle(chapter),
    totalPages: chapter === undefined ? 0 : chapter.pageCount,
    pageUris: chapter === undefined ? [] : chapter.pages.map((page) => page.uri),
    pageIds: chapter === undefined ? [] : chapter.pages.map((page) => page.id),
    pageWidths: chapter === undefined ? [] : chapter.pages.map((page) => page.width),
    pageHeights: chapter === undefined ? [] : chapter.pages.map((page) => page.height),
    sourceRuntimeId: comic.sourceRuntimeId,
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
