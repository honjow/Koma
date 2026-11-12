import { SourceTextOverlay } from './SourceTextOverlay'
import { SourceRequiredImageDecode } from './SourceRequiredImageDecode'
import { SourceTextPage, SourceTextPageRequest } from './SourceTextPageDescriptor'
import { LocalLibraryStoredMetadata } from './LocalLibraryMetadataService'
import { ComicUpdateSchedule } from './ComicReleaseSchedule'

export type ComicId = string
export type ChapterId = string
export type PageId = string

export enum LibraryItemKind {
  LOCAL_COMIC = 'local_comic',
}

export enum ComicSourceKind {
  LOCAL_ARCHIVE = 'local_archive',
  LOCAL_FOLDER = 'local_folder',
  PRIVATE_LIBRARY = 'private_library',
  KOMGA_REMOTE = 'komga_remote',
  KAVITA_REMOTE = 'kavita_remote',
  OPDS_REMOTE = 'opds_remote',
  WEBDAV_REMOTE = 'webdav_remote',
}

export enum ReadingDirection {
  LEFT_TO_RIGHT = 'left_to_right',
  RIGHT_TO_LEFT = 'right_to_left',
  WEBTOON = 'webtoon',
}

export type ReaderSeriesFormat = 'manga' | 'webtoon'

/** Format tags describe the work, independently of the source or translation language. */
export function readerFormatFromTags(tags?: string[]): ReaderSeriesFormat | undefined {
  const labels = tags?.map((tag: string): string => tag.trim().toLowerCase().replace(/[\s_-]+/g, ' ')) ?? []
  if (labels.some((tag: string): boolean => ['webtoon', 'long strip', '条漫', '條漫', '縦読み', 'タテ読み', '웹툰'].includes(tag))) {
    return 'webtoon'
  }
  return labels.some((tag: string): boolean => ['manga', '日漫', '日本漫画', '日本漫畫'].includes(tag)) ? 'manga' : undefined
}

export interface Page {
  id: PageId
  comicId: ComicId
  chapterId: ChapterId
  index: number
  fileName: string
  uri: string
  sortKey: string
  width?: number
  height?: number
  byteSize?: number
  /** Rebuildable public source text; the cached PNG is never the sole copy. */
  sourceText?: SourceTextPage
  sourceTextRequest?: SourceTextPageRequest
  sourceTextOverlay?: SourceTextOverlay
  /** Required source decode is separate from optional image processing rules. */
  requiredImageDecode?: SourceRequiredImageDecode
}

export interface Chapter {
  id: ChapterId
  comicId: ComicId
  title: string
  index: number
  chapterNumber?: number
  volumeNumber?: string
  readingOrder?: number
  readingGroup?: string
  continuationEligible?: boolean
  scanlator?: string
  language?: string
  dateUpload?: number
  sourcePath: string
  sortKey: string
  pages: Page[]
  /** Source settings snapshot used for this page plan; absent legacy plans use empty settings. */
  sourceSettingsFingerprint?: string
  pageCount: number
  createdAt: number
  updatedAt: number
}

/** Folder scans identify archive chapters before indexing their pages. Keep this
 * extension set aligned with the formats accepted by ImageSortUtils. */
export function isDeferredFolderArchiveChapter(chapter: Chapter): boolean {
  return chapter.pageCount === 0 && /\.(?:cbz|zip|rar|cbr|7z|cb7|tar|cbt|epub)$/i.test(chapter.sourcePath)
}

export interface LocalImportOrigin {
  kind: 'archive' | 'images'
  sourceUris: string[]
}

export function copyLocalImportOrigin(origin: LocalImportOrigin): LocalImportOrigin {
  if ((origin.kind !== 'archive' && origin.kind !== 'images') ||
    !Array.isArray(origin.sourceUris) || origin.sourceUris.length === 0 ||
    origin.sourceUris.some((uri: string): boolean => typeof uri !== 'string' || uri.length === 0) ||
    (origin.kind === 'archive' && origin.sourceUris.length !== 1)) {
    throw new Error('Invalid local import origin')
  }
  return { kind: origin.kind, sourceUris: origin.sourceUris.slice() }
}

/** Collected source detail, owned by the library alongside its chapter table.
 * No page URLs, source settings or session credentials belong in this snapshot.
 */
export interface SourceMangaMetadata {
  /** Public fallback identity survives uninstall and portable backup restore. */
  sourceName?: string
  contentRating?: string
  artist?: string
  status?: string
  tags?: string[]
  webUrl?: string
  excludedChapterIds?: string[]
  settingsFingerprint?: string
  /** Ordered, complete chapter identities; available before this device fetches pages. */
  sharedChapterIds?: string[]
  chapterCatalogUpdatedAt?: number
}

export function copySourceMangaMetadata(value: SourceMangaMetadata): SourceMangaMetadata {
  return {
    sourceName: value.sourceName,
    contentRating: value.contentRating,
    artist: value.artist,
    status: value.status,
    tags: value.tags?.slice(),
    webUrl: value.webUrl,
    excludedChapterIds: value.excludedChapterIds?.slice(),
    settingsFingerprint: value.settingsFingerprint,
    sharedChapterIds: value.sharedChapterIds?.slice(),
    chapterCatalogUpdatedAt: value.chapterCatalogUpdatedAt,
  }
}

export function setCompleteSourceChapterCatalog(comic: Comic, ids: string[], observedAt: number): boolean {
  const distinct = Array.from(new Set<string>(ids))
  const old = comic.sourceMetadata?.sharedChapterIds
  if (old !== undefined && old.length === distinct.length && old.every((id: string, index: number): boolean => id === distinct[index])) {
    return false
  }
  comic.sourceMetadata = comic.sourceMetadata ?? {}
  comic.sourceMetadata.sharedChapterIds = distinct
  comic.sourceMetadata.chapterCatalogUpdatedAt = observedAt
  comic.chapterCount = distinct.length
  return true
}

export interface Comic {
  id: ComicId
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
  personalNotes?: string
  customCoverUri?: string
  sourceCoverUri?: string
  updateSchedule?: ComicUpdateSchedule
  localMetadata?: LocalLibraryStoredMetadata
  localImportOrigin?: LocalImportOrigin
  sourceMetadata?: SourceMangaMetadata
  sortTitle: string
  preferredDirection: ReadingDirection
  chapters: Chapter[]
  chapterCount: number
  pageCount: number
  createdAt: number
  updatedAt: number
  lastImportedAt: number
}

/** User choices survive source refreshes and category/metadata projections. */
export function copyComicPersonalFields(source: Comic, target: Comic): void {
  target.personalNotes = source.personalNotes
  target.customCoverUri = source.customCoverUri
  target.sourceCoverUri = source.sourceCoverUri
  if (source.customCoverUri) target.coverUri = source.customCoverUri
}

export function assignComicSourceCover(comic: Comic, coverUri: string): void {
  if (comic.customCoverUri) { comic.sourceCoverUri = coverUri; comic.coverUri = comic.customCoverUri }
  else comic.coverUri = coverUri
}

export function copyComicUpdateSchedule(source: Comic, target: Comic): void {
  target.updateSchedule = source.updateSchedule === undefined ? undefined : {
    intervalDays: source.updateSchedule.intervalDays, nextCheckAt: source.updateSchedule.nextCheckAt,
  }
}

export function sameComicIdentity(baseline: Comic, current: Comic): boolean {
  return baseline.id === current.id && baseline.createdAt === current.createdAt &&
    baseline.sourceKind === current.sourceKind && baseline.sourcePath === current.sourcePath &&
    baseline.sourceRuntimeId === current.sourceRuntimeId && baseline.remoteServerId === current.remoteServerId &&
    baseline.remoteResourceId === current.remoteResourceId
}

export const LIBRARY_CATEGORY_FAVORITE_ID: string = 'favorite'
export const LIBRARY_CATEGORY_READ_LATER_ID: string = 'read_later'
export const CUSTOM_LIBRARY_CATEGORY_ID_PREFIX: string = 'custom_'
export const LIBRARY_CATEGORY_NAME_MAX_LENGTH: number = 40

export interface LibraryCategoryDefinition {
  id: string
  name: string
  sortOrder?: number
  createdAt?: number
  updatedAt?: number
  builtIn?: boolean
}

// These identifiers survive old library files, backup rules and WebDAV membership keys.
export interface LegacyLibraryCategory {
  id: string
  nameKey: string
}

export const LEGACY_LIBRARY_CATEGORIES: LegacyLibraryCategory[] = [
  { id: LIBRARY_CATEGORY_FAVORITE_ID, nameKey: 'library_category_favorite' },
  { id: LIBRARY_CATEGORY_READ_LATER_ID, nameKey: 'library_category_read_later' },
]

export interface CustomLibraryCategory {
  id: string
  name: string
  sortOrder: number
  createdAt: number
  updatedAt: number
}

export function normalizeLibraryCategoryName(name: string): string {
  return name.trim().replace(/\s+/g, ' ')
}

export function libraryCategoryNameKey(name: string): string {
  return normalizeLibraryCategoryName(name).toLocaleLowerCase()
}

export function isManualLibraryCategoryId(categoryId: string): boolean {
  return categoryId.startsWith(CUSTOM_LIBRARY_CATEGORY_ID_PREFIX) ||
    categoryId === LIBRARY_CATEGORY_FAVORITE_ID || categoryId === LIBRARY_CATEGORY_READ_LATER_ID
}

export interface ReadingProgress {
  comicId: ComicId
  chapterId: ChapterId
  pageId?: PageId
  pageIndex: number
  totalPages: number
  progressRatio: number
  completed: boolean
  updatedAt: number
  /**
   * Double-page pairing is a reading-position concern in NextE, not a global
   * preference.  Keep it optional so older progress files and remote records
   * remain readable while a chapter-specific value can be restored locally.
   */
  columnMode?: 'odd_left' | 'even_left'
}

export interface LibraryItem {
  id: string
  kind: LibraryItemKind
  comicId: ComicId
  title: string
  coverUri?: string
  sourceRuntimeId?: string
  sourceImageId?: string
  sourceKind: ComicSourceKind
  remoteServerId?: string
  sourcePath: string
  chapterCount: number
  pageCount: number
  addedAt: number
  updatedAt: number
  lastReadAt?: number
  progress?: ReadingProgress
}

export function normalizeSortKey(value: string): string {
  return value.trim().toLocaleLowerCase()
}

export function normalizeCategoryIds(categoryIds?: string[]): string[] {
  if (categoryIds === undefined) {
    return []
  }
  const nextIds: string[] = []
  categoryIds.forEach((categoryId: string) => {
    const normalized = categoryId.trim()
    if (normalized.length > 0 && !nextIds.includes(normalized)) {
      nextIds.push(normalized)
    }
  })
  return nextIds
}

export function withComicCategoryIds(comic: Comic, categoryIds?: string[]): Comic {
  const normalizedCategoryIds = normalizeCategoryIds(categoryIds)
  const nextComic: Comic = {
    id: comic.id,
    title: comic.title,
    sourceKind: comic.sourceKind,
    sourcePath: comic.sourcePath,
    sortTitle: comic.sortTitle,
    preferredDirection: comic.preferredDirection,
    chapters: comic.chapters,
    chapterCount: comic.chapterCount,
    pageCount: comic.pageCount,
    createdAt: comic.createdAt,
    updatedAt: Date.now(),
    lastImportedAt: comic.lastImportedAt,
  }
  if (comic.subtitle !== undefined) {
    nextComic.subtitle = comic.subtitle
  }
  if (comic.author !== undefined) {
    nextComic.author = comic.author
  }
  if (comic.sourceRuntimeId !== undefined) {
    nextComic.sourceRuntimeId = comic.sourceRuntimeId
  }
  if (comic.remoteServerId !== undefined) {
    nextComic.remoteServerId = comic.remoteServerId
  }
  if (comic.remoteResourceId !== undefined) {
    nextComic.remoteResourceId = comic.remoteResourceId
  }
  if (comic.coverUri !== undefined) {
    nextComic.coverUri = comic.coverUri
  }
  if (comic.localImportOrigin !== undefined) {
    nextComic.localImportOrigin = copyLocalImportOrigin(comic.localImportOrigin)
  }
  if (comic.localMetadata !== undefined) {
    nextComic.localMetadata = comic.localMetadata
  }
  if (comic.sourceMetadata !== undefined) {
    nextComic.sourceMetadata = copySourceMangaMetadata(comic.sourceMetadata)
  }
  if (normalizedCategoryIds.length > 0) {
    nextComic.categoryIds = normalizedCategoryIds
  } else {
    nextComic.categoryIds = undefined
  }
  copyComicPersonalFields(comic, nextComic)
  copyComicUpdateSchedule(comic, nextComic)
  return nextComic
}

export function withComicAddedCategoryId(comic: Comic, categoryId: string): Comic {
  const categoryIds = normalizeCategoryIds(comic.categoryIds)
  const normalizedCategoryId = categoryId.trim()
  if (normalizedCategoryId.length === 0 || categoryIds.includes(normalizedCategoryId)) {
    return withComicCategoryIds(comic, categoryIds)
  }
  categoryIds.push(normalizedCategoryId)
  return withComicCategoryIds(comic, categoryIds)
}

export function withComicRemovedCategoryId(comic: Comic, categoryId: string): Comic {
  const normalizedCategoryId = categoryId.trim()
  const categoryIds = normalizeCategoryIds(comic.categoryIds).filter((item: string): boolean => {
    return item !== normalizedCategoryId
  })
  return withComicCategoryIds(comic, categoryIds)
}

export function clampPageIndex(pageIndex: number, totalPages: number): number {
  if (totalPages <= 0) {
    return 0
  }
  if (pageIndex < 0) {
    return 0
  }
  if (pageIndex >= totalPages) {
    return totalPages - 1
  }
  return Math.floor(pageIndex)
}

export function calculateProgressRatio(pageIndex: number, totalPages: number): number {
  if (totalPages <= 0) {
    return 0
  }
  return (clampPageIndex(pageIndex, totalPages) + 1) / totalPages
}

export function createReadingProgress(comicId: ComicId, chapterId: ChapterId, totalPages: number): ReadingProgress {
  const now = Date.now()
  return {
    comicId,
    chapterId,
    pageIndex: 0,
    totalPages,
    progressRatio: totalPages > 0 ? 1 / totalPages : 0,
    completed: totalPages === 0,
    updatedAt: now,
  }
}

export function updateReadingProgress(
  previous: ReadingProgress,
  pageIndex: number,
  pageId?: PageId,
  totalPages?: number
): ReadingProgress {
  const resolvedTotalPages = totalPages === undefined ? previous.totalPages : totalPages
  const resolvedPageIndex = clampPageIndex(pageIndex, resolvedTotalPages)
  return {
    comicId: previous.comicId,
    chapterId: previous.chapterId,
    pageId,
    pageIndex: resolvedPageIndex,
    totalPages: resolvedTotalPages,
    progressRatio: calculateProgressRatio(resolvedPageIndex, resolvedTotalPages),
    completed: resolvedTotalPages <= 0 || resolvedPageIndex >= resolvedTotalPages - 1,
    updatedAt: Date.now(),
    columnMode: previous.columnMode,
  }
}

export function readingProgressPageIndex(
  progress: ReadingProgress,
  totalPages: number,
  pageIds?: PageId[],
): number {
  const fallback = clampPageIndex(progress.pageIndex, totalPages)
  if (progress.pageId === undefined || pageIds === undefined || pageIds[fallback] === progress.pageId) {
    return fallback
  }
  const pageIndex = pageIds.indexOf(progress.pageId)
  return pageIndex >= 0 && pageIndex < totalPages ? pageIndex : fallback
}

export function currentComicReadingProgress(comic: Comic, progress?: ReadingProgress): ReadingProgress | undefined {
  if (comic.localImportOrigin !== undefined && progress !== undefined &&
    !comic.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId)) {
    return undefined
  }
  if (progress === undefined || comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER) {
    return progress
  }
  const chapter = comic.chapters.find((item: Chapter): boolean => item.id === progress.chapterId)
  if (chapter === undefined) {
    return progress
  }
  // A folder archive is indexed when opened; an empty scan is not a zero-page
  // update and must not erase the reader's saved page or completion state.
  if (chapter.pages.length === 0 && isDeferredFolderArchiveChapter(chapter)) return progress
  const totalPages = chapter.pages.length
  if (totalPages === progress.totalPages &&
    (progress.pageId === undefined || chapter.pages[progress.pageIndex]?.id === progress.pageId)) {
    return progress
  }
  const pageIndex = readingProgressPageIndex(progress, totalPages, chapter.pages.map((page: Page): PageId => page.id))
  return {
    comicId: progress.comicId,
    chapterId: progress.chapterId,
    pageId: progress.pageId,
    pageIndex,
    totalPages,
    progressRatio: calculateProgressRatio(pageIndex, totalPages),
    completed: progress.completed,
    updatedAt: progress.updatedAt,
    columnMode: progress.columnMode,
  }
}

export function comicToLibraryItem(comic: Comic, progress?: ReadingProgress): LibraryItem {
  return {
    id: comic.id,
    kind: LibraryItemKind.LOCAL_COMIC,
    comicId: comic.id,
    title: comic.title,
    coverUri: comic.coverUri,
    sourceRuntimeId: comic.sourceRuntimeId,
    sourceImageId: comic.remoteResourceId ?? comic.id,
    sourceKind: comic.sourceKind,
    remoteServerId: comic.remoteServerId,
    sourcePath: comic.sourcePath,
    chapterCount: comic.chapterCount,
    pageCount: comic.pageCount,
    addedAt: comic.createdAt,
    updatedAt: comic.updatedAt,
    lastReadAt: progress === undefined ? undefined : progress.updatedAt,
    progress: currentComicReadingProgress(comic, progress),
  }
}

export function serializeComic(comic: Comic): string {
  return JSON.stringify(comic)
}

export function deserializeComic(payload: string): Comic {
  const comic = JSON.parse(payload) as Comic
  const categoryIds = normalizeCategoryIds(comic.categoryIds)
  if (categoryIds.length > 0) {
    comic.categoryIds = categoryIds
  } else {
    comic.categoryIds = undefined
  }
  return comic
}

export function serializeReadingProgress(progress: ReadingProgress): string {
  return JSON.stringify(progress)
}

export function deserializeReadingProgress(payload: string): ReadingProgress {
  return JSON.parse(payload) as ReadingProgress
}
