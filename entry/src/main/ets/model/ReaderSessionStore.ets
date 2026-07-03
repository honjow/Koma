import {
  Chapter,
  Comic,
  ComicId,
  Page,
  ReadingProgress,
  clampPageIndex,
} from './ComicModels'
import { fileIo as fs } from '@kit.CoreFileKit'
import {
  InMemoryReadingProgressStore,
  ReadingProgressStore,
} from './ReadingProgressStore'
import { AppStrings } from '../i18n/AppStrings'

export const READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 1
export const READER_PROGRESS_PERSISTENCE_FILE_NAME = 'reader-progress.v1.json'

export interface ReaderSessionConfig {
  comicId: ComicId
  chapterId: string
  title?: string
  chapterTitle?: string
  chapterIds: string[]
  totalPages: number
  pageUris: string[]
  pageIds: string[]
  pageWidths: Array<number | undefined>
  pageHeights: Array<number | undefined>
  sourceRuntimeId?: string
}

export const EMPTY_READER_SESSION_CONFIG: ReaderSessionConfig = {
  comicId: '',
  chapterId: '',
  title: '',
  chapterTitle: '',
  chapterIds: [],
  totalPages: 0,
  pageUris: [],
  pageIds: [],
  pageWidths: [],
  pageHeights: [],
  sourceRuntimeId: undefined,
}

export enum ReaderMode {
  SINGLE_PAGE = 'single_page',
  DUAL_PAGE = 'dual_page',
  CONTINUOUS_SCROLL = 'continuous_scroll',
}

export function readerModeFromContinuousScroll(enabled: boolean): ReaderMode {
  return enabled ? ReaderMode.CONTINUOUS_SCROLL : ReaderMode.SINGLE_PAGE
}

export function isContinuousScrollReaderMode(mode: ReaderMode): boolean {
  return mode === ReaderMode.CONTINUOUS_SCROLL
}

export function getReaderModeLabel(mode: ReaderMode): string {
  if (mode === ReaderMode.CONTINUOUS_SCROLL) {
    return AppStrings.get('reader_page_mode_continuous')
  }
  if (mode === ReaderMode.DUAL_PAGE) {
    return AppStrings.get('reader_page_mode_double')
  }
  return AppStrings.get('reader_page_mode_single')
}

export interface ReaderSessionStore {
  restorePageIndex(config: ReaderSessionConfig): number
  restoreMode(config: ReaderSessionConfig): ReaderMode
  updatePageIndex(config: ReaderSessionConfig, pageIndex: number, pageId?: string): ReadingProgress
  saveProgress(progress: ReadingProgress): void
  listProgress(): ReadingProgress[]
  removeProgress(comicId: ComicId): void
  updateMode(config: ReaderSessionConfig, mode: ReaderMode): void
  getProgress(comicId: ComicId): ReadingProgress | undefined
  clear(): void
}

export class InMemoryReaderSessionStore implements ReaderSessionStore {
  private progressStore: ReadingProgressStore

  constructor(progressStore: ReadingProgressStore = new InMemoryReadingProgressStore()) {
    this.progressStore = progressStore
  }

  restorePageIndex(config: ReaderSessionConfig): number {
    const progress = this.progressStore.get(config.comicId)
    if (progress === undefined || progress.chapterId !== config.chapterId) {
      return 0
    }
    return clampPageIndex(progress.pageIndex, config.totalPages)
  }

  restoreMode(config: ReaderSessionConfig): ReaderMode {
    void config
    return ReaderMode.SINGLE_PAGE
  }

  updatePageIndex(config: ReaderSessionConfig, pageIndex: number, pageId?: string): ReadingProgress {
    const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
    return this.progressStore.updatePage(
      config.comicId,
      config.chapterId,
      resolvedPageIndex,
      pageId,
      config.totalPages
    )
  }

  updateMode(config: ReaderSessionConfig, mode: ReaderMode): void {
    void config
    void mode
  }

  saveProgress(progress: ReadingProgress): void {
    this.progressStore.save(progress)
  }

  listProgress(): ReadingProgress[] {
    return this.progressStore.list()
  }

  removeProgress(comicId: ComicId): void {
    this.progressStore.remove(comicId)
  }

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    return this.progressStore.get(comicId)
  }

  clear(): void {
    this.progressStore.clear()
  }
}

export interface PersistedReaderMode {
  comicId: ComicId
  chapterId: string
  mode: ReaderMode
  updatedAt: number
}

export interface PersistedReaderProgressDocument {
  schemaVersion: number
  progress: ReadingProgress[]
  modes: PersistedReaderMode[]
}

export interface ReaderSessionPersistenceAdapter {
  load(): string | undefined
  save(payload: string): void
}

function joinReaderPersistencePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  if (left.length === 0) {
    return right
  }
  return `${left}/${right}`
}

function isReaderMode(value: ReaderMode | undefined): boolean {
  return value === ReaderMode.SINGLE_PAGE || value === ReaderMode.DUAL_PAGE || value === ReaderMode.CONTINUOUS_SCROLL
}

function parseReaderProgressDocument(payload: string): PersistedReaderProgressDocument {
  const parsed = JSON.parse(payload) as PersistedReaderProgressDocument
  if (parsed.schemaVersion !== READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION) {
    throw new Error(`Unsupported reader progress schema version: ${parsed.schemaVersion}`)
  }
  if (!Array.isArray(parsed.progress) || !Array.isArray(parsed.modes)) {
    throw new Error('Invalid reader progress persistence payload')
  }
  return parsed
}

export class AppFilesReaderSessionPersistenceAdapter implements ReaderSessionPersistenceAdapter {
  private readonly filePath: string

  constructor(filesDir: string, fileName: string = READER_PROGRESS_PERSISTENCE_FILE_NAME) {
    this.filePath = joinReaderPersistencePath(filesDir, fileName)
  }

  load(): string | undefined {
    if (!fs.accessSync(this.filePath)) {
      return undefined
    }
    return fs.readTextSync(this.filePath, { encoding: 'utf-8' })
  }

  save(payload: string): void {
    let file: fs.File | undefined = undefined
    try {
      file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    } finally {
      if (file !== undefined) {
        fs.closeSync(file)
      }
    }
  }
}

export class PersistentReaderSessionStore implements ReaderSessionStore {
  private progressStore: InMemoryReadingProgressStore = new InMemoryReadingProgressStore()
  private modes: Map<string, PersistedReaderMode> = new Map<string, PersistedReaderMode>()
  private adapter: ReaderSessionPersistenceAdapter

  constructor(adapter: ReaderSessionPersistenceAdapter) {
    this.adapter = adapter
    this.restore()
  }

  private modeKey(comicId: ComicId, chapterId: string): string {
    return `${comicId}::${chapterId}`
  }

  private restore(): void {
    const payload = this.adapter.load()
    if (payload === undefined || payload.length === 0) {
      return
    }
    const document = parseReaderProgressDocument(payload)
    this.progressStore.restoreJson(JSON.stringify(document.progress))
    document.modes.forEach((mode: PersistedReaderMode) => {
      if (mode.comicId.length > 0 && mode.chapterId.length > 0 && isReaderMode(mode.mode)) {
        this.modes.set(this.modeKey(mode.comicId, mode.chapterId), mode)
      }
    })
  }

  private persist(): void {
    const document: PersistedReaderProgressDocument = {
      schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
      progress: this.progressStore.list(),
      modes: Array.from(this.modes.values()),
    }
    this.adapter.save(JSON.stringify(document))
  }

  restorePageIndex(config: ReaderSessionConfig): number {
    const progress = this.progressStore.get(config.comicId)
    if (progress === undefined || progress.chapterId !== config.chapterId) {
      return 0
    }
    return clampPageIndex(progress.pageIndex, config.totalPages)
  }

  restoreMode(config: ReaderSessionConfig): ReaderMode {
    const row = this.modes.get(this.modeKey(config.comicId, config.chapterId))
    if (row === undefined || !isReaderMode(row.mode)) {
      return ReaderMode.SINGLE_PAGE
    }
    return row.mode
  }

  updatePageIndex(config: ReaderSessionConfig, pageIndex: number, pageId?: string): ReadingProgress {
    const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
    const progress = this.progressStore.updatePage(
      config.comicId,
      config.chapterId,
      resolvedPageIndex,
      pageId,
      config.totalPages
    )
    this.persist()
    return progress
  }

  updateMode(config: ReaderSessionConfig, mode: ReaderMode): void {
    if (config.comicId.length === 0 || config.chapterId.length === 0) {
      return
    }
    this.modes.set(this.modeKey(config.comicId, config.chapterId), {
      comicId: config.comicId,
      chapterId: config.chapterId,
      mode,
      updatedAt: Date.now(),
    })
    this.persist()
  }

  saveProgress(progress: ReadingProgress): void {
    this.progressStore.save(progress)
    this.persist()
  }

  listProgress(): ReadingProgress[] {
    return this.progressStore.list()
  }

  removeProgress(comicId: ComicId): void {
    this.progressStore.remove(comicId)
    this.persist()
  }

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    return this.progressStore.get(comicId)
  }

  clear(): void {
    this.progressStore.clear()
    this.modes.clear()
    this.persist()
  }
}

function sortedPages(chapter: Chapter): Page[] {
  return chapter.pages.slice().sort((a: Page, b: Page) => {
    if (a.index !== b.index) {
      return a.index - b.index
    }
    return a.sortKey.localeCompare(b.sortKey)
  })
}

export function createReaderSessionConfigFromComic(comic: Comic, chapterId?: string): ReaderSessionConfig {
  let chapter = comic.chapters.length === 0 ? undefined : comic.chapters[0]
  if (chapterId !== undefined) {
    const matchedChapter = comic.chapters.find((item: Chapter) => item.id === chapterId)
    if (matchedChapter !== undefined) {
      chapter = matchedChapter
    }
  }

  if (chapter === undefined) {
    return {
      comicId: comic.id,
      chapterId: '',
      title: comic.title,
      chapterIds: comic.chapters.map((item: Chapter): string => item.id),
      totalPages: 0,
      pageUris: [],
      pageIds: [],
      pageWidths: [],
      pageHeights: [],
      sourceRuntimeId: comic.sourceRuntimeId,
    }
  }

  const pages = sortedPages(chapter)
  return {
    comicId: comic.id,
    chapterId: chapter.id,
    title: comic.title,
    chapterTitle: chapter.title,
    chapterIds: comic.chapters.map((item: Chapter): string => item.id),
    totalPages: pages.length,
    pageUris: pages.map((page: Page) => page.uri),
    pageIds: pages.map((page: Page) => page.id),
    pageWidths: pages.map((page: Page) => page.width),
    pageHeights: pages.map((page: Page) => page.height),
    sourceRuntimeId: comic.sourceRuntimeId,
  }
}

export function getReaderSessionPageUri(config: ReaderSessionConfig, pageIndex: number): string {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  if (resolvedPageIndex >= config.pageUris.length) {
    return ''
  }
  return config.pageUris[resolvedPageIndex]
}

export function getReaderSessionPageId(config: ReaderSessionConfig, pageIndex: number): string {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  if (resolvedPageIndex >= config.pageIds.length) {
    return `page-${resolvedPageIndex + 1}`
  }
  return config.pageIds[resolvedPageIndex]
}

export function getReaderSessionPageWidth(config: ReaderSessionConfig, pageIndex: number): number | undefined {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  if (resolvedPageIndex >= config.pageWidths.length) {
    return undefined
  }
  return config.pageWidths[resolvedPageIndex]
}

export function getReaderSessionPageHeight(config: ReaderSessionConfig, pageIndex: number): number | undefined {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  if (resolvedPageIndex >= config.pageHeights.length) {
    return undefined
  }
  return config.pageHeights[resolvedPageIndex]
}
