import {
  Chapter,
  Comic,
  ComicId,
  Page,
  ReadingProgress,
  clampPageIndex,
} from './ComicModels'
import {
  InMemoryReadingProgressStore,
  ReadingProgressStore,
} from './ReadingProgressStore'

export interface ReaderSessionConfig {
  comicId: ComicId
  chapterId: string
  title?: string
  chapterTitle?: string
  totalPages: number
  pageUris: string[]
  pageIds: string[]
}

export interface ReaderSessionStore {
  restorePageIndex(config: ReaderSessionConfig): number
  updatePageIndex(config: ReaderSessionConfig, pageIndex: number, pageId?: string): ReadingProgress
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

  getProgress(comicId: ComicId): ReadingProgress | undefined {
    return this.progressStore.get(comicId)
  }

  clear(): void {
    this.progressStore.clear()
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
      totalPages: 0,
      pageUris: [],
      pageIds: [],
    }
  }

  const pages = sortedPages(chapter)
  return {
    comicId: comic.id,
    chapterId: chapter.id,
    title: comic.title,
    chapterTitle: chapter.title,
    totalPages: pages.length,
    pageUris: pages.map((page: Page) => page.uri),
    pageIds: pages.map((page: Page) => page.id),
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
