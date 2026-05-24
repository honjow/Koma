import { common } from '@kit.AbilityKit'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  ReadingProgress,
  clampPageIndex,
  calculateProgressRatio,
} from './ComicModels'
import { ReaderSessionConfig } from './ReaderSessionStore'
import { RemoteServerStore } from './RemoteServerStore'
import {
  KomgaBookId,
  KomgaReadProgressDto,
} from '../remote/KomgaModels'

const KOMGA_PROGRESS_PUSH_DEBOUNCE_MS: number = 1000

interface PendingKomgaProgressPush {
  bookId: KomgaBookId
  progress: ReadingProgress
}

export class RemoteProgressSyncService {
  private context: common.UIAbilityContext
  private pushTimers: Map<string, number> = new Map<string, number>()
  private pendingPushes: Map<string, PendingKomgaProgressPush> = new Map<string, PendingKomgaProgressPush>()

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async pull(comic: Comic): Promise<ReadingProgress | undefined> {
    if (comic.sourceKind !== ComicSourceKind.KOMGA_REMOTE) {
      return undefined
    }
    const chapter = this.firstReadableChapter(comic)
    if (chapter === undefined) {
      return undefined
    }
    const bookId = this.parseKomgaBookId(chapter.id)
    if (bookId === undefined) {
      return undefined
    }
    return this.pullKomgaBook(bookId, comic.id, chapter.id, chapter.pageCount, chapter.pages.map((page) => page.id))
  }

  async pullSession(config: ReaderSessionConfig): Promise<ReadingProgress | undefined> {
    const bookId = this.parseKomgaBookId(config.chapterId)
    if (!this.isKomgaSession(config) || bookId === undefined) {
      return undefined
    }
    return this.pullKomgaBook(bookId, config.comicId, config.chapterId, config.totalPages, config.pageIds)
  }

  async push(comic: Comic, progress: ReadingProgress): Promise<void> {
    if (comic.sourceKind !== ComicSourceKind.KOMGA_REMOTE) {
      return
    }
    const bookId = this.parseKomgaBookId(progress.chapterId)
    if (bookId === undefined) {
      return
    }
    this.scheduleKomgaPush(bookId, progress)
  }

  async pushSession(config: ReaderSessionConfig, progress: ReadingProgress): Promise<void> {
    const bookId = this.parseKomgaBookId(config.chapterId)
    if (!this.isKomgaSession(config) || bookId === undefined) {
      return
    }
    this.scheduleKomgaPush(bookId, progress)
  }

  dispose(): void {
    this.pushTimers.forEach((timer: number) => {
      clearTimeout(timer)
    })
    this.pushTimers.clear()
    this.pendingPushes.clear()
  }

  private async pullKomgaBook(
    bookId: KomgaBookId,
    comicId: string,
    chapterId: string,
    totalPages: number,
    pageIds: string[]
  ): Promise<ReadingProgress | undefined> {
    try {
      const record = await new RemoteServerStore(this.context).loadKomga()
      if (record === undefined) {
        return undefined
      }
      const remote = await new RemoteServerStore(this.context).createKomgaClient(record).getBookReadProgress(bookId)
      if (remote === undefined) {
        return undefined
      }
      const progress = this.mapKomgaProgress(comicId, chapterId, totalPages, pageIds, remote)
      console.info(`[KomgaSync] step=pull_ok page=${remote.page}`)
      return progress
    } catch (error) {
      const e = error as Error
      console.warn(`[KomgaSync] step=pull_fail page=0 message=${e.message}`)
      return undefined
    }
  }

  private scheduleKomgaPush(bookId: KomgaBookId, progress: ReadingProgress): void {
    const key = bookId
    const previousTimer = this.pushTimers.get(key)
    if (previousTimer !== undefined && previousTimer > 0) {
      clearTimeout(previousTimer)
    }
    this.pendingPushes.set(key, { bookId, progress })
    const timer = setTimeout(() => {
      this.pushTimers.delete(key)
      const pending = this.pendingPushes.get(key)
      this.pendingPushes.delete(key)
      if (pending === undefined) {
        return
      }
      void this.flushKomgaPush(pending)
    }, KOMGA_PROGRESS_PUSH_DEBOUNCE_MS)
    this.pushTimers.set(key, timer)
  }

  private async flushKomgaPush(pending: PendingKomgaProgressPush): Promise<void> {
    const page = this.toKomgaPage(pending.progress)
    try {
      const store = new RemoteServerStore(this.context)
      const record = await store.loadKomga()
      if (record === undefined) {
        console.warn(`[KomgaSync] step=push_fail page=${page} message=Komga server is not configured`)
        return
      }
      await store.createKomgaClient(record).patchBookReadProgress(pending.bookId, page, pending.progress.completed)
      console.info(`[KomgaSync] step=push_ok page=${page}`)
    } catch (error) {
      const e = error as Error
      console.warn(`[KomgaSync] step=push_fail page=${page} message=${e.message}`)
    }
  }

  private mapKomgaProgress(
    comicId: string,
    chapterId: string,
    totalPages: number,
    pageIds: string[],
    remote: KomgaReadProgressDto
  ): ReadingProgress {
    const pageIndex = clampPageIndex(remote.page - 1, totalPages)
    return {
      comicId,
      chapterId,
      pageId: pageIndex < pageIds.length ? pageIds[pageIndex] : undefined,
      pageIndex,
      totalPages,
      progressRatio: calculateProgressRatio(pageIndex, totalPages),
      completed: remote.completed || totalPages <= 0 || pageIndex >= totalPages - 1,
      updatedAt: this.parseRemoteTimestamp(remote.lastModified, remote.readDate, remote.created),
    }
  }

  private toKomgaPage(progress: ReadingProgress): number {
    return progress.pageIndex + 1
  }

  private parseRemoteTimestamp(primary?: string, secondary?: string, tertiary?: string): number {
    const candidates: string[] = []
    if (primary !== undefined) {
      candidates.push(primary)
    }
    if (secondary !== undefined) {
      candidates.push(secondary)
    }
    if (tertiary !== undefined) {
      candidates.push(tertiary)
    }
    for (let index = 0; index < candidates.length; index += 1) {
      const parsed = Date.parse(candidates[index])
      if (!Number.isNaN(parsed)) {
        return parsed
      }
    }
    return Date.now()
  }

  private isKomgaSession(config: ReaderSessionConfig): boolean {
    return config.comicId.startsWith('komga:') && config.chapterId.includes(':book:')
  }

  private parseKomgaBookId(chapterId: string): KomgaBookId | undefined {
    const marker = ':book:'
    const index = chapterId.indexOf(marker)
    if (!chapterId.startsWith('komga:') || index < 0) {
      return undefined
    }
    const bookId = chapterId.slice(index + marker.length)
    return bookId.length === 0 ? undefined : bookId
  }

  private firstReadableChapter(comic: Comic): Chapter | undefined {
    const chapters = comic.chapters.slice().sort((a: Chapter, b: Chapter) => {
      if (a.index !== b.index) {
        return a.index - b.index
      }
      return a.sortKey.localeCompare(b.sortKey)
    })
    return chapters.find((chapter: Chapter) => chapter.pageCount > 0)
  }
}
