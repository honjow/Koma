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
  OPDS_REMOTE = 'opds_remote',
  WEBDAV_REMOTE = 'webdav_remote',
}

export enum ReadingDirection {
  LEFT_TO_RIGHT = 'left_to_right',
  RIGHT_TO_LEFT = 'right_to_left',
  WEBTOON = 'webtoon',
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
}

export interface Chapter {
  id: ChapterId
  comicId: ComicId
  title: string
  index: number
  sourcePath: string
  sortKey: string
  pages: Page[]
  pageCount: number
  createdAt: number
  updatedAt: number
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
  sortTitle: string
  preferredDirection: ReadingDirection
  chapters: Chapter[]
  chapterCount: number
  pageCount: number
  createdAt: number
  updatedAt: number
  lastImportedAt: number
}

export const LIBRARY_CATEGORY_FAVORITE_ID: string = 'favorite'
export const LIBRARY_CATEGORY_READ_LATER_ID: string = 'read_later'

export interface LibraryCategoryDefinition {
  id: string
  name: string
}

export const BUILT_IN_LIBRARY_CATEGORIES: LibraryCategoryDefinition[] = [
  { id: LIBRARY_CATEGORY_FAVORITE_ID, name: '收藏' },
  { id: LIBRARY_CATEGORY_READ_LATER_ID, name: '稍后阅读' },
]

export interface ReadingProgress {
  comicId: ComicId
  chapterId: ChapterId
  pageId?: PageId
  pageIndex: number
  totalPages: number
  progressRatio: number
  completed: boolean
  updatedAt: number
}

export interface LibraryItem {
  id: string
  kind: LibraryItemKind
  comicId: ComicId
  title: string
  coverUri?: string
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
  if (normalizedCategoryIds.length > 0) {
    nextComic.categoryIds = normalizedCategoryIds
  } else {
    nextComic.categoryIds = undefined
  }
  return nextComic
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
  }
}

export function comicToLibraryItem(comic: Comic, progress?: ReadingProgress): LibraryItem {
  return {
    id: comic.id,
    kind: LibraryItemKind.LOCAL_COMIC,
    comicId: comic.id,
    title: comic.title,
    coverUri: comic.coverUri,
    sourcePath: comic.sourcePath,
    chapterCount: comic.chapterCount,
    pageCount: comic.pageCount,
    addedAt: comic.createdAt,
    updatedAt: comic.updatedAt,
    lastReadAt: progress === undefined ? undefined : progress.updatedAt,
    progress,
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
