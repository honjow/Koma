import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
} from './ComicModels'
import { LibraryStore } from './LibraryStore'

export const LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION = 1

export interface PersistedLibraryStoreDocument {
  schemaVersion: number
  comics?: PersistedComic[]
}

export interface PersistedComic {
  id: string
  title: string
  subtitle?: string
  author?: string
  sourceKind: ComicSourceKind
  sourcePath: string
  coverUri?: string
  sortTitle: string
  preferredDirection: ReadingDirection
  chapters: PersistedChapter[]
  chapterCount: number
  pageCount: number
  createdAt: number
  updatedAt: number
  lastImportedAt: number
}

export interface PersistedChapter {
  id: string
  comicId: string
  title: string
  index: number
  sourcePath: string
  sortKey: string
  pages: PersistedPage[]
  pageCount: number
  createdAt: number
  updatedAt: number
}

export interface PersistedPage {
  id: string
  comicId: string
  chapterId: string
  index: number
  fileName: string
  uri: string
  sortKey: string
  width?: number
  height?: number
  byteSize?: number
}

function persistPage(page: Page): PersistedPage {
  const row: PersistedPage = {
    id: page.id,
    comicId: page.comicId,
    chapterId: page.chapterId,
    index: page.index,
    fileName: page.fileName,
    uri: page.uri,
    sortKey: page.sortKey,
  }
  if (page.width !== undefined) {
    row.width = page.width
  }
  if (page.height !== undefined) {
    row.height = page.height
  }
  if (page.byteSize !== undefined) {
    row.byteSize = page.byteSize
  }
  return row
}

function hydratePage(row: PersistedPage): Page {
  const page: Page = {
    id: row.id,
    comicId: row.comicId,
    chapterId: row.chapterId,
    index: row.index,
    fileName: row.fileName,
    uri: row.uri,
    sortKey: row.sortKey,
  }
  if (row.width !== undefined) {
    page.width = row.width
  }
  if (row.height !== undefined) {
    page.height = row.height
  }
  if (row.byteSize !== undefined) {
    page.byteSize = row.byteSize
  }
  return page
}

function persistChapter(chapter: Chapter): PersistedChapter {
  return {
    id: chapter.id,
    comicId: chapter.comicId,
    title: chapter.title,
    index: chapter.index,
    sourcePath: chapter.sourcePath,
    sortKey: chapter.sortKey,
    pages: chapter.pages.map((page: Page) => persistPage(page)),
    pageCount: chapter.pageCount,
    createdAt: chapter.createdAt,
    updatedAt: chapter.updatedAt,
  }
}

function hydrateChapter(row: PersistedChapter): Chapter {
  const pages = row.pages === undefined ? [] : row.pages.map((page: PersistedPage) => hydratePage(page))
  return {
    id: row.id,
    comicId: row.comicId,
    title: row.title,
    index: row.index,
    sourcePath: row.sourcePath,
    sortKey: row.sortKey,
    pages,
    pageCount: row.pageCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  }
}

export function persistComic(comic: Comic): PersistedComic {
  const row: PersistedComic = {
    id: comic.id,
    title: comic.title,
    sourceKind: comic.sourceKind,
    sourcePath: comic.sourcePath,
    sortTitle: comic.sortTitle,
    preferredDirection: comic.preferredDirection,
    chapters: comic.chapters.map((chapter: Chapter) => persistChapter(chapter)),
    chapterCount: comic.chapterCount,
    pageCount: comic.pageCount,
    createdAt: comic.createdAt,
    updatedAt: comic.updatedAt,
    lastImportedAt: comic.lastImportedAt,
  }
  if (comic.subtitle !== undefined) {
    row.subtitle = comic.subtitle
  }
  if (comic.author !== undefined) {
    row.author = comic.author
  }
  if (comic.coverUri !== undefined) {
    row.coverUri = comic.coverUri
  }
  return row
}

export function hydrateComic(row: PersistedComic): Comic {
  const chapters = row.chapters === undefined ? [] : row.chapters.map((chapter: PersistedChapter) => hydrateChapter(chapter))
  const comic: Comic = {
    id: row.id,
    title: row.title,
    sourceKind: row.sourceKind,
    sourcePath: row.sourcePath,
    sortTitle: row.sortTitle,
    preferredDirection: row.preferredDirection,
    chapters,
    chapterCount: row.chapterCount,
    pageCount: row.pageCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    lastImportedAt: row.lastImportedAt,
  }
  if (row.subtitle !== undefined) {
    comic.subtitle = row.subtitle
  }
  if (row.author !== undefined) {
    comic.author = row.author
  }
  if (row.coverUri !== undefined) {
    comic.coverUri = row.coverUri
  }
  return comic
}

export function createLibraryStorePersistenceDocument(libraryStore: LibraryStore): PersistedLibraryStoreDocument {
  return {
    schemaVersion: LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION,
    comics: libraryStore.listComics().map((comic: Comic) => persistComic(comic)),
  }
}

export function serializeLibraryStore(libraryStore: LibraryStore): string {
  return JSON.stringify(createLibraryStorePersistenceDocument(libraryStore))
}

function assertSupportedLibraryStoreDocument(document: PersistedLibraryStoreDocument): void {
  if (document.schemaVersion !== LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION) {
    throw new Error(`Unsupported library store persistence schema version: ${document.schemaVersion}`)
  }
}

export function hydrateLibraryStoreFromJson(libraryStore: LibraryStore, payload: string): void {
  const document = JSON.parse(payload) as PersistedLibraryStoreDocument
  assertSupportedLibraryStoreDocument(document)
  const comics = document.comics === undefined ? [] : document.comics
  libraryStore.clear()
  comics.forEach((row: PersistedComic) => {
    libraryStore.upsertComic(hydrateComic(row))
  })
}

export interface LibraryStorePersistenceAdapter {
  load(): string | undefined
  save(payload: string): void
}

export class LibraryStorePersistenceService {
  private libraryStore: LibraryStore
  private adapter: LibraryStorePersistenceAdapter

  constructor(libraryStore: LibraryStore, adapter: LibraryStorePersistenceAdapter) {
    this.libraryStore = libraryStore
    this.adapter = adapter
  }

  restore(): void {
    const payload = this.adapter.load()
    if (payload === undefined || payload.length === 0) {
      this.libraryStore.clear()
      return
    }
    hydrateLibraryStoreFromJson(this.libraryStore, payload)
  }

  persist(): void {
    this.adapter.save(serializeLibraryStore(this.libraryStore))
  }
}
