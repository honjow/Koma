import {
  ComicId,
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
  totalPages: number
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
