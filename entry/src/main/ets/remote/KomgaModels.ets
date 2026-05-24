import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from '../model/ComicModels'

export type KomgaServerId = string
export type KomgaCredentialRef = string
export type KomgaLibraryId = string
export type KomgaSeriesId = string
export type KomgaBookId = string

export enum KomgaAuthKind {
  NONE = 'none',
  BASIC = 'basic',
  API_KEY = 'api_key',
  SESSION_TOKEN = 'session_token',
}

export enum KomgaPageImageKind {
  STREAM = 'stream',
  RAW = 'raw',
  THUMBNAIL = 'thumbnail',
}

export interface KomgaServerConfig {
  id: KomgaServerId
  name: string
  baseUrl: string
  authKind: KomgaAuthKind
  credentialRef?: KomgaCredentialRef
}

export interface KomgaAccount {
  id: string
  serverId: KomgaServerId
  displayName: string
  credentialRef: KomgaCredentialRef
  authKind: KomgaAuthKind
  createdAt: number
  updatedAt: number
}

export interface KomgaResolvedCredential {
  credentialRef: KomgaCredentialRef
  basicToken?: string
  apiKey?: string
  sessionToken?: string
}

export interface KomgaLibraryDto {
  id: KomgaLibraryId
  name: string
  root?: string
  type?: string
}

export interface KomgaSeriesDto {
  id: KomgaSeriesId
  name: string
  sortName?: string
  metadata?: KomgaSeriesMetadataDto
  booksCount?: number
  created?: string
  lastModified?: string
}

export interface KomgaSeriesMetadataDto {
  title?: string
  titleSort?: string
  summary?: string
  authors?: KomgaAuthorDto[]
  genres?: string[]
  tags?: string[]
  status?: string
  readingDirection?: string
}

export interface KomgaAuthorDto {
  name: string
  role?: string
}

export interface KomgaBookDto {
  id: KomgaBookId
  seriesId: KomgaSeriesId
  name: string
  url?: string
  number?: string
  numberSort?: number
  fileLastModified?: string
  sizeBytes?: number
  media?: KomgaBookMediaDto
  metadata?: KomgaBookMetadataDto
  readProgress?: KomgaReadProgressDto
  created?: string
  lastModified?: string
}

export interface KomgaReadProgressDto {
  completed: boolean
  created?: string
  deviceId?: string
  deviceName?: string
  lastModified?: string
  page: number
  readDate?: string
}

export interface KomgaBookMediaDto {
  pagesCount?: number
  status?: string
  mediaType?: string
}

export interface KomgaBookMetadataDto {
  title?: string
  summary?: string
  number?: string
  numberSort?: number
  releaseDate?: string
  authors?: KomgaAuthorDto[]
}

export interface KomgaPageDto {
  number: number
  fileName: string
  mediaType?: string
  width?: number
  height?: number
  sizeBytes?: number
}

export interface KomgaPageResponseDto {
  content: KomgaPageDto[]
}

export interface KomgaPageList<T> {
  content: T[]
  totalPages?: number
  totalElements?: number
  size?: number
  number?: number
  first?: boolean
  last?: boolean
}

export interface KomgaListRequest {
  page?: number
  size?: number
  search?: string
  libraryIds?: KomgaLibraryId[]
  seriesIds?: KomgaSeriesId[]
  sort?: string[]
}

export interface RemotePageRef {
  sourceType: 'komga'
  serverId: KomgaServerId
  bookId: KomgaBookId
  pageNumber: number
  imageKind: KomgaPageImageKind
  path: string
}

export function createKomgaComicId(serverId: KomgaServerId, seriesId: KomgaSeriesId): string {
  return `komga:${serverId}:series:${seriesId}`
}

export function createKomgaChapterId(serverId: KomgaServerId, bookId: KomgaBookId): string {
  return `komga:${serverId}:book:${bookId}`
}

export function createKomgaPageId(serverId: KomgaServerId, bookId: KomgaBookId, pageNumber: number): string {
  return `komga:${serverId}:book:${bookId}:page:${pageNumber}`
}

export function createRemotePageUri(serverId: KomgaServerId, bookId: KomgaBookId, pageNumber: number): string {
  return `komga://${serverId}/books/${bookId}/pages/${pageNumber}`
}

function parseKomgaTime(value?: string, fallback?: number): number {
  if (value === undefined || value.length === 0) {
    return fallback === undefined ? Date.now() : fallback
  }
  const parsed = Date.parse(value)
  if (Number.isNaN(parsed)) {
    return fallback === undefined ? Date.now() : fallback
  }
  return parsed
}

function pickSeriesTitle(series: KomgaSeriesDto): string {
  if (series.metadata?.title !== undefined && series.metadata.title.length > 0) {
    return series.metadata.title
  }
  return series.name
}

function pickBookTitle(book: KomgaBookDto): string {
  if (book.metadata?.title !== undefined && book.metadata.title.length > 0) {
    return book.metadata.title
  }
  return book.name
}

function pickSeriesAuthor(series: KomgaSeriesDto): string | undefined {
  const authors = series.metadata?.authors
  if (authors === undefined || authors.length === 0) {
    return undefined
  }
  return authors.map((author: KomgaAuthorDto) => author.name).join(', ')
}

function mapReadingDirection(value?: string): ReadingDirection {
  if (value === 'LEFT_TO_RIGHT') {
    return ReadingDirection.LEFT_TO_RIGHT
  }
  if (value === 'WEBTOON') {
    return ReadingDirection.WEBTOON
  }
  return ReadingDirection.RIGHT_TO_LEFT
}

export function mapKomgaSeriesToComic(
  serverId: KomgaServerId,
  series: KomgaSeriesDto,
  chapters: Chapter[] = [],
  mappedAt: number = Date.now()
): Comic {
  const title = pickSeriesTitle(series)
  const createdAt = parseKomgaTime(series.created, mappedAt)
  const updatedAt = parseKomgaTime(series.lastModified, mappedAt)
  const pageCount = chapters.reduce((total: number, chapter: Chapter) => total + chapter.pageCount, 0)
  return {
    id: createKomgaComicId(serverId, series.id),
    title,
    subtitle: series.metadata?.summary,
    author: pickSeriesAuthor(series),
    sourceKind: ComicSourceKind.KOMGA_REMOTE,
    sourcePath: `komga://${serverId}/series/${series.id}`,
    remoteServerId: serverId,
    remoteResourceId: series.id,
    sortTitle: normalizeSortKey(series.metadata?.titleSort === undefined ? series.sortName === undefined ? title : series.sortName : series.metadata.titleSort),
    preferredDirection: mapReadingDirection(series.metadata?.readingDirection),
    chapters,
    chapterCount: chapters.length,
    pageCount,
    createdAt,
    updatedAt,
    lastImportedAt: mappedAt,
  }
}

export function mapKomgaBookToChapter(
  serverId: KomgaServerId,
  book: KomgaBookDto,
  comicId: string,
  pages: Page[] = [],
  fallbackIndex: number = 0,
  mappedAt: number = Date.now()
): Chapter {
  const title = pickBookTitle(book)
  const pageCount = book.media?.pagesCount === undefined ? pages.length : book.media.pagesCount
  const createdAt = parseKomgaTime(book.created, mappedAt)
  const updatedAt = parseKomgaTime(book.lastModified === undefined ? book.fileLastModified : book.lastModified, mappedAt)
  return {
    id: createKomgaChapterId(serverId, book.id),
    comicId,
    title,
    index: book.metadata?.numberSort === undefined ? book.numberSort === undefined ? fallbackIndex : book.numberSort : book.metadata.numberSort,
    sourcePath: `komga://${serverId}/books/${book.id}`,
    sortKey: normalizeSortKey(`${book.metadata?.numberSort === undefined ? book.numberSort === undefined ? fallbackIndex : book.numberSort : book.metadata.numberSort}:${title}`),
    pages,
    pageCount,
    createdAt,
    updatedAt,
  }
}

export function mapKomgaPageToPage(
  serverId: KomgaServerId,
  bookId: KomgaBookId,
  comicId: string,
  chapterId: string,
  page: KomgaPageDto
): Page {
  return {
    id: createKomgaPageId(serverId, bookId, page.number),
    comicId,
    chapterId,
    index: page.number - 1,
    fileName: page.fileName,
    uri: createRemotePageUri(serverId, bookId, page.number),
    sortKey: normalizeSortKey(page.fileName),
    width: page.width,
    height: page.height,
    byteSize: page.sizeBytes,
  }
}
