import {
  ComicId,
  ReadingProgress,
  createReadingProgress,
  updateReadingProgress,
} from './ComicModels'

export interface ReadingProgressStore {
  get(comicId: ComicId): ReadingProgress | undefined
  list(): ReadingProgress[]
  save(progress: ReadingProgress): void
  updatePage(comicId: ComicId, chapterId: string, pageIndex: number, pageId?: string, totalPages?: number): ReadingProgress
  remove(comicId: ComicId): void
  clear(): void
  dumpJson(): string
  restoreJson(payload: string): void
}

export class InMemoryReadingProgressStore implements ReadingProgressStore {
  private items: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()

  get(comicId: ComicId): ReadingProgress | undefined {
    return this.items.get(comicId)
  }

  list(): ReadingProgress[] {
    return Array.from(this.items.values()).sort((a: ReadingProgress, b: ReadingProgress) => {
      return b.updatedAt - a.updatedAt
    })
  }

  save(progress: ReadingProgress): void {
    this.items.set(progress.comicId, progress)
  }

  updatePage(comicId: ComicId, chapterId: string, pageIndex: number, pageId?: string, totalPages?: number): ReadingProgress {
    const previous = this.items.get(comicId)
    let next: ReadingProgress
    if (previous === undefined) {
      next = createReadingProgress(comicId, chapterId, totalPages === undefined ? 0 : totalPages)
      next = updateReadingProgress(next, pageIndex, pageId, totalPages)
    } else {
      const base: ReadingProgress = {
        comicId: previous.comicId,
        chapterId,
        pageId: previous.pageId,
        pageIndex: previous.pageIndex,
        totalPages: previous.totalPages,
        progressRatio: previous.progressRatio,
        completed: previous.completed,
        updatedAt: previous.updatedAt,
      }
      next = updateReadingProgress(base, pageIndex, pageId, totalPages)
    }
    this.items.set(comicId, next)
    return next
  }

  remove(comicId: ComicId): void {
    this.items.delete(comicId)
  }

  clear(): void {
    this.items.clear()
  }

  dumpJson(): string {
    return JSON.stringify(this.list())
  }

  restoreJson(payload: string): void {
    this.items.clear()
    const rows = JSON.parse(payload) as ReadingProgress[]
    rows.forEach((progress: ReadingProgress) => {
      this.items.set(progress.comicId, progress)
    })
  }
}
