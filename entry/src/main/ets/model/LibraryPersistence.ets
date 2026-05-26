import {
  Chapter,
  Comic,
  ComicId,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeCategoryIds,
  withComicAddedCategoryId,
  withComicCategoryIds,
  withComicRemovedCategoryId,
} from './ComicModels'
import { fileIo as fs } from '@kit.CoreFileKit'
import { LibraryStore } from './LibraryStore'

export const LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION = 1
export const LIBRARY_STORE_PERSISTENCE_FILE_NAME = 'library-store.v1.json'

export interface PersistedLibraryStoreDocument {
  schemaVersion: number
  comics: PersistedComic[]
}

export interface PersistedComic {
  id: string
  title: string
  subtitle?: string
  author?: string
  categoryIds?: string[]
  sourceKind: ComicSourceKind
  sourcePath: string
  sourceRuntimeId?: string
  remoteServerId?: string
  remoteResourceId?: string
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
  assertValidPersistedPage(row)
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
  assertValidPersistedChapter(row)
  const pages = row.pages.map((page: PersistedPage) => hydratePage(page))
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
  const categoryIds = normalizeCategoryIds(comic.categoryIds)
  if (categoryIds.length > 0) {
    row.categoryIds = categoryIds
  }
  if (comic.sourceRuntimeId !== undefined) {
    row.sourceRuntimeId = comic.sourceRuntimeId
  }
  if (comic.remoteServerId !== undefined) {
    row.remoteServerId = comic.remoteServerId
  }
  if (comic.remoteResourceId !== undefined) {
    row.remoteResourceId = comic.remoteResourceId
  }
  if (comic.coverUri !== undefined) {
    row.coverUri = comic.coverUri
  }
  return row
}

export function hydrateComic(row: PersistedComic): Comic {
  assertValidPersistedComic(row)
  const chapters = row.chapters.map((chapter: PersistedChapter) => hydrateChapter(chapter))
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
  const categoryIds = normalizeCategoryIds(row.categoryIds)
  if (categoryIds.length > 0) {
    comic.categoryIds = categoryIds
  }
  if (row.sourceRuntimeId !== undefined) {
    comic.sourceRuntimeId = row.sourceRuntimeId
  }
  if (row.remoteServerId !== undefined) {
    comic.remoteServerId = row.remoteServerId
  }
  if (row.remoteResourceId !== undefined) {
    comic.remoteResourceId = row.remoteResourceId
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

function assertPersistedObject(value: Object | null, label: string): void {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected object`)
  }
}

function assertStringField(value: string | undefined, label: string): void {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid library store persistence ${label}: expected non-empty string`)
  }
}

function assertOptionalStringField(value: string | undefined, label: string): void {
  if (value !== undefined && typeof value !== 'string') {
    throw new Error(`Invalid library store persistence ${label}: expected string`)
  }
}

function assertOptionalStringArrayField(value: string[] | undefined, label: string): void {
  if (value === undefined) {
    return
  }
  if (!Array.isArray(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected string array`)
  }
  value.forEach((item: string, index: number) => {
    assertStringField(item, `${label}.${index}`)
  })
}

function assertNumberField(value: number | undefined, label: string): void {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected finite number`)
  }
}

function assertOptionalNumberField(value: number | undefined, label: string): void {
  if (value !== undefined && (typeof value !== 'number' || !Number.isFinite(value))) {
    throw new Error(`Invalid library store persistence ${label}: expected finite number`)
  }
}

function assertComicSourceKind(value: ComicSourceKind | undefined, label: string): void {
  if (
    value !== ComicSourceKind.LOCAL_ARCHIVE &&
    value !== ComicSourceKind.LOCAL_FOLDER &&
    value !== ComicSourceKind.PRIVATE_LIBRARY &&
    value !== ComicSourceKind.KOMGA_REMOTE &&
    value !== ComicSourceKind.OPDS_REMOTE &&
    value !== ComicSourceKind.WEBDAV_REMOTE
  ) {
    throw new Error(`Invalid library store persistence ${label}: expected comic source kind`)
  }
}

function assertReadingDirection(value: ReadingDirection | undefined, label: string): void {
  if (
    value !== ReadingDirection.LEFT_TO_RIGHT &&
    value !== ReadingDirection.RIGHT_TO_LEFT &&
    value !== ReadingDirection.WEBTOON
  ) {
    throw new Error(`Invalid library store persistence ${label}: expected reading direction`)
  }
}

function assertValidPersistedPage(row: PersistedPage): void {
  assertPersistedObject(row as Object, 'page')
  assertStringField(row.id, 'page.id')
  assertStringField(row.comicId, 'page.comicId')
  assertStringField(row.chapterId, 'page.chapterId')
  assertNumberField(row.index, 'page.index')
  assertStringField(row.fileName, 'page.fileName')
  assertStringField(row.uri, 'page.uri')
  assertStringField(row.sortKey, 'page.sortKey')
  assertOptionalNumberField(row.width, 'page.width')
  assertOptionalNumberField(row.height, 'page.height')
  assertOptionalNumberField(row.byteSize, 'page.byteSize')
}

function assertValidPersistedChapter(row: PersistedChapter): void {
  assertPersistedObject(row as Object, 'chapter')
  assertStringField(row.id, 'chapter.id')
  assertStringField(row.comicId, 'chapter.comicId')
  assertStringField(row.title, 'chapter.title')
  assertNumberField(row.index, 'chapter.index')
  assertStringField(row.sourcePath, 'chapter.sourcePath')
  assertStringField(row.sortKey, 'chapter.sortKey')
  if (!Array.isArray(row.pages)) {
    throw new Error('Invalid library store persistence chapter.pages: expected array')
  }
  assertNumberField(row.pageCount, 'chapter.pageCount')
  assertNumberField(row.createdAt, 'chapter.createdAt')
  assertNumberField(row.updatedAt, 'chapter.updatedAt')
}

function assertValidPersistedComic(row: PersistedComic): void {
  assertPersistedObject(row as Object, 'comic')
  assertStringField(row.id, 'comic.id')
  assertStringField(row.title, 'comic.title')
  assertOptionalStringField(row.subtitle, 'comic.subtitle')
  assertOptionalStringField(row.author, 'comic.author')
  assertOptionalStringArrayField(row.categoryIds, 'comic.categoryIds')
  assertComicSourceKind(row.sourceKind, 'comic.sourceKind')
  assertStringField(row.sourcePath, 'comic.sourcePath')
  assertOptionalStringField(row.sourceRuntimeId, 'comic.sourceRuntimeId')
  assertOptionalStringField(row.remoteServerId, 'comic.remoteServerId')
  assertOptionalStringField(row.remoteResourceId, 'comic.remoteResourceId')
  assertOptionalStringField(row.coverUri, 'comic.coverUri')
  assertStringField(row.sortTitle, 'comic.sortTitle')
  assertReadingDirection(row.preferredDirection, 'comic.preferredDirection')
  if (!Array.isArray(row.chapters)) {
    throw new Error('Invalid library store persistence comic.chapters: expected array')
  }
  assertNumberField(row.chapterCount, 'comic.chapterCount')
  assertNumberField(row.pageCount, 'comic.pageCount')
  assertNumberField(row.createdAt, 'comic.createdAt')
  assertNumberField(row.updatedAt, 'comic.updatedAt')
  assertNumberField(row.lastImportedAt, 'comic.lastImportedAt')
}

function parseValidatedLibraryStoreComics(payload: string): Comic[] {
  const document = JSON.parse(payload) as PersistedLibraryStoreDocument
  assertPersistedObject(document as Object, 'document')
  assertSupportedLibraryStoreDocument(document)
  if (!Array.isArray(document.comics)) {
    throw new Error('Invalid library store persistence comics: expected array')
  }
  return document.comics.map((row: PersistedComic) => hydrateComic(row))
}

export function hydrateLibraryStoreFromJson(libraryStore: LibraryStore, payload: string): void {
  const comics = parseValidatedLibraryStoreComics(payload)
  libraryStore.clear()
  comics.forEach((comic: Comic) => {
    libraryStore.upsertComic(comic)
  })
}

export interface LibraryStorePersistenceAdapter {
  load(): string | undefined
  save(payload: string): void
}

function joinLibraryPersistencePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  if (left.length === 0) {
    return right
  }
  return `${left}/${right}`
}

export class AppFilesLibraryStorePersistenceAdapter implements LibraryStorePersistenceAdapter {
  private readonly filePath: string

  constructor(filesDir: string, fileName: string = LIBRARY_STORE_PERSISTENCE_FILE_NAME) {
    this.filePath = joinLibraryPersistencePath(filesDir, fileName)
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
      return
    }
    hydrateLibraryStoreFromJson(this.libraryStore, payload)
  }

  persist(): void {
    this.adapter.save(serializeLibraryStore(this.libraryStore))
  }
}

export function isRemovableLocalComic(comic: Comic | undefined): boolean {
  if (comic === undefined) {
    return false
  }
  if (comic.sourcePath.startsWith('mock://')) {
    return false
  }
  return comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER
}

export function upsertComicAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comic: Comic
): void {
  const previousPayload = serializeLibraryStore(libraryStore)
  libraryStore.addComic(comic)
  try {
    persistenceService.persist()
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}

export function assignComicCategoriesAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicIds: ComicId[],
  categoryIds?: string[]
): number {
  const normalizedCategoryIds = normalizeCategoryIds(categoryIds)
  const previousPayload = serializeLibraryStore(libraryStore)
  let changedCount = 0
  comicIds.forEach((comicId: ComicId) => {
    const comic = libraryStore.getComic(comicId)
    if (comic !== undefined) {
      libraryStore.upsertComic(withComicCategoryIds(comic, normalizedCategoryIds))
      changedCount += 1
    }
  })
  if (changedCount === 0) {
    return 0
  }
  try {
    persistenceService.persist()
    return changedCount
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}

export function updateComicCategoryMembershipAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicIds: ComicId[],
  categoryId: string,
  selected: boolean
): number {
  const normalizedCategoryId = categoryId.trim()
  if (normalizedCategoryId.length === 0) {
    return 0
  }
  const previousPayload = serializeLibraryStore(libraryStore)
  let changedCount = 0
  comicIds.forEach((comicId: ComicId) => {
    const comic = libraryStore.getComic(comicId)
    if (comic !== undefined) {
      const nextComic = selected ?
        withComicAddedCategoryId(comic, normalizedCategoryId) :
        withComicRemovedCategoryId(comic, normalizedCategoryId)
      libraryStore.upsertComic(nextComic)
      changedCount += 1
    }
  })
  if (changedCount === 0) {
    return 0
  }
  try {
    persistenceService.persist()
    return changedCount
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}

export function removeComicAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: ComicId
): boolean {
  const comic = libraryStore.getComic(comicId)
  if (!isRemovableLocalComic(comic)) {
    return false
  }
  const previousPayload = serializeLibraryStore(libraryStore)
  libraryStore.removeComic(comicId)
  try {
    persistenceService.persist()
    return true
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}
