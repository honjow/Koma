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
  sourceKind: ComicSourceKind
  sourcePath: string
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
  return JSON.parse(payload) as Comic
}

export function serializeReadingProgress(progress: ReadingProgress): string {
  return JSON.stringify(progress)
}

export function deserializeReadingProgress(payload: string): ReadingProgress {
  return JSON.parse(payload) as ReadingProgress
}
