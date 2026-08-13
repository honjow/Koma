import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from '../model/ComicModels'

export type KavitaServerId = string
export type KavitaCredentialRef = string
export type KavitaLibraryId = number
export type KavitaSeriesId = number
export type KavitaVolumeId = number
export type KavitaChapterId = number

export interface KavitaServerConfig {
  id: KavitaServerId
  name: string
  baseUrl: string
  credentialRef: KavitaCredentialRef
}

export interface KavitaResolvedCredential {
  credentialRef: KavitaCredentialRef
  apiKey: string
}

export interface KavitaLibraryDto {
  id: KavitaLibraryId
  name: string
  type?: number
  lastScanned?: string
  coverImage?: string
  includeInSearch?: boolean
}

export interface KavitaSeriesDto {
  id: KavitaSeriesId
  name: string
  localizedName?: string
  sortName?: string
  pages?: number
  pagesRead?: number
  libraryId?: KavitaLibraryId
  libraryName?: string
  coverImage?: string
  created?: string
  lastChapterAdded?: string
  lastChapterAddedUtc?: string
}

export interface KavitaChapterDto {
  id: KavitaChapterId
  range?: string
  number?: string
  minNumber?: number
  maxNumber?: number
  title?: string
  titleName?: string
  pages?: number
  pagesRead?: number
  volumeId?: KavitaVolumeId
  sortOrder?: number
  created?: string
  createdUtc?: string
  lastModifiedUtc?: string
  releaseDate?: string
}

export interface KavitaVolumeDto {
  id: KavitaVolumeId
  name?: string
  number?: number
  minNumber?: number
  maxNumber?: number
  pages?: number
  pagesRead?: number
  seriesId?: KavitaSeriesId
  chapters?: KavitaChapterDto[]
}

export interface KavitaFileDimensionDto {
  width?: number
  height?: number
  pageNumber?: number
  fileName?: string
  isWide?: boolean
}

export interface KavitaChapterInfoDto {
  chapterNumber?: string
  volumeNumber?: string
  volumeId?: KavitaVolumeId
  seriesName?: string
  seriesId?: KavitaSeriesId
  libraryId?: KavitaLibraryId
  chapterTitle?: string
  pages?: number
  fileName?: string
  subtitle?: string
  title?: string
  seriesTotalPages?: number
  seriesTotalPagesRead?: number
  pageDimensions?: KavitaFileDimensionDto[]
}

export interface KavitaProgressDto {
  volumeId: KavitaVolumeId
  chapterId: KavitaChapterId
  pageNum: number
  seriesId: KavitaSeriesId
  libraryId: KavitaLibraryId
  bookScrollId?: string
  lastModifiedUtc?: string
}

export function createKavitaComicId(serverId: KavitaServerId, seriesId: KavitaSeriesId): string {
  return `kavita:${serverId}:series:${seriesId}`
}

export function createKavitaChapterId(serverId: KavitaServerId, chapterId: KavitaChapterId): string {
  return `kavita:${serverId}:chapter:${chapterId}`
}

export function createKavitaPageId(serverId: KavitaServerId, chapterId: KavitaChapterId, pageIndex: number): string {
  return `kavita:${serverId}:chapter:${chapterId}:page:${pageIndex}`
}

function parseKavitaTime(value?: string, fallback?: number): number {
  if (value === undefined || value.length === 0) {
    return fallback === undefined ? Date.now() : fallback
  }
  const parsed = Date.parse(value)
  if (Number.isNaN(parsed)) {
    return fallback === undefined ? Date.now() : fallback
  }
  return parsed
}

function pickSeriesTitle(series: KavitaSeriesDto, info?: KavitaChapterInfoDto): string {
  if (info?.seriesName !== undefined && info.seriesName.length > 0) {
    return info.seriesName
  }
  if (series.localizedName !== undefined && series.localizedName.length > 0) {
    return series.localizedName
  }
  return series.name
}

function pickChapterTitle(chapter: KavitaChapterDto, info?: KavitaChapterInfoDto): string {
  if (info?.chapterTitle !== undefined && info.chapterTitle.length > 0) {
    return info.chapterTitle
  }
  if (chapter.titleName !== undefined && chapter.titleName.length > 0) {
    return chapter.titleName
  }
  if (chapter.title !== undefined && chapter.title.length > 0) {
    return chapter.title
  }
  if (chapter.range !== undefined && chapter.range.length > 0) {
    return chapter.range
  }
  return `${chapter.id}`
}

export function mapKavitaPageToPage(
  serverId: KavitaServerId,
  chapterId: KavitaChapterId,
  comicId: string,
  mappedChapterId: string,
  pageIndex: number,
  uri: string,
  dimension?: KavitaFileDimensionDto,
): Page {
  const fileName = dimension?.fileName === undefined || dimension.fileName.length === 0 ? `page-${pageIndex + 1}` : dimension.fileName
  return {
    id: createKavitaPageId(serverId, chapterId, pageIndex),
    comicId,
    chapterId: mappedChapterId,
    index: pageIndex,
    fileName,
    uri,
    sortKey: normalizeSortKey(`${pageIndex}:${fileName}`),
    width: dimension?.width,
    height: dimension?.height,
  }
}

export function mapKavitaChapterToChapter(
  serverId: KavitaServerId,
  chapter: KavitaChapterDto,
  comicId: string,
  pages: Page[],
  info?: KavitaChapterInfoDto,
  mappedAt: number = Date.now(),
): Chapter {
  const title = pickChapterTitle(chapter, info)
  const createdAt = parseKavitaTime(chapter.created ?? chapter.createdUtc, mappedAt)
  const updatedAt = parseKavitaTime(chapter.lastModifiedUtc ?? chapter.releaseDate, mappedAt)
  const sortIndex = chapter.sortOrder === undefined ? chapter.minNumber === undefined ? pages.length : chapter.minNumber : chapter.sortOrder
  return {
    id: createKavitaChapterId(serverId, chapter.id),
    comicId,
    title,
    index: sortIndex,
    sourcePath: `kavita://${serverId}/chapters/${chapter.id}`,
    sortKey: normalizeSortKey(`${sortIndex}:${title}`),
    pages,
    pageCount: pages.length,
    createdAt,
    updatedAt,
  }
}

export function mapKavitaSeriesToComic(
  serverId: KavitaServerId,
  series: KavitaSeriesDto,
  chapter: Chapter,
  info?: KavitaChapterInfoDto,
  mappedAt: number = Date.now(),
): Comic {
  const title = pickSeriesTitle(series, info)
  const createdAt = parseKavitaTime(series.created, mappedAt)
  const updatedAt = parseKavitaTime(series.lastChapterAddedUtc ?? series.lastChapterAdded, mappedAt)
  return {
    id: createKavitaComicId(serverId, series.id),
    title,
    sourceKind: ComicSourceKind.KAVITA_REMOTE,
    sourcePath: `kavita://${serverId}/series/${series.id}`,
    remoteServerId: serverId,
    remoteResourceId: `${series.id}`,
    coverUri: series.coverImage,
    sortTitle: normalizeSortKey(series.sortName === undefined ? title : series.sortName),
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters: [chapter],
    chapterCount: 1,
    pageCount: chapter.pageCount,
    createdAt,
    updatedAt,
    lastImportedAt: mappedAt,
  }
}
