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
import {
  KavitaChapterId,
  KavitaChapterInfoDto,
  KavitaProgressDto,
} from '../remote/KavitaModels'

const KOMGA_PROGRESS_PUSH_DEBOUNCE_MS: number = 1000
const KAVITA_PROGRESS_PUSH_DEBOUNCE_MS: number = 1000

interface PendingKomgaProgressPush {
  bookId: KomgaBookId
  progress: ReadingProgress
}

interface PendingKavitaProgressPush {
  chapterId: KavitaChapterId
  progress: ReadingProgress
}

export class RemoteProgressSyncService {
  private context: common.UIAbilityContext
  private pushTimers: Map<string, number> = new Map<string, number>()
  private pendingPushes: Map<string, PendingKomgaProgressPush> = new Map<string, PendingKomgaProgressPush>()
  private kavitaPushTimers: Map<string, number> = new Map<string, number>()
  private pendingKavitaPushes: Map<string, PendingKavitaProgressPush> = new Map<string, PendingKavitaProgressPush>()

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async pull(comic: Comic): Promise<ReadingProgress | undefined> {
    if (comic.sourceKind !== ComicSourceKind.KOMGA_REMOTE) {
      if (comic.sourceKind !== ComicSourceKind.KAVITA_REMOTE) {
        return undefined
      }
      return this.pullKavitaComic(comic)
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
    if (this.isKomgaSession(config) && bookId !== undefined) {
      return this.pullKomgaBook(bookId, config.comicId, config.chapterId, config.totalPages, config.pageIds)
    }
    const kavitaChapterId = this.parseKavitaChapterId(config.chapterId)
    if (this.isKavitaSession(config) && kavitaChapterId !== undefined) {
      return this.pullKavitaChapter(kavitaChapterId, config.comicId, config.chapterId, config.totalPages, config.pageIds)
    }
    return undefined
  }

  async push(comic: Comic, progress: ReadingProgress): Promise<void> {
    if (comic.sourceKind !== ComicSourceKind.KOMGA_REMOTE) {
      if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
        const chapterId = this.parseKavitaChapterId(progress.chapterId)
        if (chapterId !== undefined) {
          this.scheduleKavitaPush(chapterId, progress)
        }
      }
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
    if (this.isKomgaSession(config) && bookId !== undefined) {
      this.scheduleKomgaPush(bookId, progress)
      return
    }
    const kavitaChapterId = this.parseKavitaChapterId(config.chapterId)
    if (this.isKavitaSession(config) && kavitaChapterId !== undefined) {
      this.scheduleKavitaPush(kavitaChapterId, progress)
    }
  }

  dispose(): void {
    this.flushPendingPushes()
  }

  flushPendingPushes(): void {
    const pendingPushes = Array.from(this.pendingPushes.values())
    this.pushTimers.forEach((timer: number) => {
      clearTimeout(timer)
    })
    this.pushTimers.clear()
    this.pendingPushes.clear()
    pendingPushes.forEach((pending: PendingKomgaProgressPush) => {
      void this.flushKomgaPush(pending)
    })
    const pendingKavitaPushes = Array.from(this.pendingKavitaPushes.values())
    this.kavitaPushTimers.forEach((timer: number) => {
      clearTimeout(timer)
    })
    this.kavitaPushTimers.clear()
    this.pendingKavitaPushes.clear()
    pendingKavitaPushes.forEach((pending: PendingKavitaProgressPush) => {
      void this.flushKavitaPush(pending)
    })
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
      void error
      console.warn('[KomgaSync] step=pull_fail page=0 code=remote_progress_pull_failed')
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
        console.warn(`[KomgaSync] step=push_fail page=${page} code=server_not_configured`)
        return
      }
      await store.createKomgaClient(record).patchBookReadProgress(pending.bookId, page, pending.progress.completed)
      console.info(`[KomgaSync] step=push_ok page=${page}`)
    } catch (error) {
      void error
      console.warn(`[KomgaSync] step=push_fail page=${page} code=remote_progress_push_failed`)
    }
  }

  private async pullKavitaComic(comic: Comic): Promise<ReadingProgress | undefined> {
    const chapters = comic.chapters.slice().sort((a: Chapter, b: Chapter) => {
      if (a.index !== b.index) {
        return a.index - b.index
      }
      return a.sortKey.localeCompare(b.sortKey)
    })
    let latest: ReadingProgress | undefined = undefined
    for (let index = 0; index < chapters.length; index += 1) {
      const chapter = chapters[index]
      if (chapter.pageCount <= 0) {
        continue
      }
      const chapterId = this.parseKavitaChapterId(chapter.id)
      if (chapterId === undefined) {
        continue
      }
      const progress = await this.pullKavitaChapter(chapterId, comic.id, chapter.id, chapter.pageCount, chapter.pages.map((page) => page.id))
      if (progress === undefined) {
        continue
      }
      if (latest === undefined || progress.updatedAt > latest.updatedAt) {
        latest = progress
      }
    }
    return latest
  }

  private async pullKavitaChapter(
    chapterId: KavitaChapterId,
    comicId: string,
    mappedChapterId: string,
    totalPages: number,
    pageIds: string[]
  ): Promise<ReadingProgress | undefined> {
    try {
      const store = new RemoteServerStore(this.context)
      const record = await store.loadKavita()
      if (record === undefined) {
        return undefined
      }
      const remote = await store.createKavitaClient(record).getReadProgress(chapterId)
      if (remote.pageNum <= 0) {
        return undefined
      }
      const progress = this.mapKavitaProgress(comicId, mappedChapterId, totalPages, pageIds, remote)
      console.info(`[KavitaSync] step=pull_ok page=${remote.pageNum}`)
      return progress
    } catch (error) {
      void error
      console.warn('[KavitaSync] step=pull_fail page=0 code=remote_progress_pull_failed')
      return undefined
    }
  }

  private scheduleKavitaPush(chapterId: KavitaChapterId, progress: ReadingProgress): void {
    const key = `${chapterId}`
    const previousTimer = this.kavitaPushTimers.get(key)
    if (previousTimer !== undefined && previousTimer > 0) {
      clearTimeout(previousTimer)
    }
    this.pendingKavitaPushes.set(key, { chapterId, progress })
    const timer = setTimeout(() => {
      this.kavitaPushTimers.delete(key)
      const pending = this.pendingKavitaPushes.get(key)
      this.pendingKavitaPushes.delete(key)
      if (pending === undefined) {
        return
      }
      void this.flushKavitaPush(pending)
    }, KAVITA_PROGRESS_PUSH_DEBOUNCE_MS)
    this.kavitaPushTimers.set(key, timer)
  }

  private async flushKavitaPush(pending: PendingKavitaProgressPush): Promise<void> {
    const page = this.toKavitaPageNum(pending.progress)
    try {
      const store = new RemoteServerStore(this.context)
      const record = await store.loadKavita()
      if (record === undefined) {
        console.warn(`[KavitaSync] step=push_fail page=${page} code=server_not_configured`)
        return
      }
      const client = store.createKavitaClient(record)
      const info = await client.getChapterInfo(pending.chapterId)
      await client.saveReadProgress(this.createKavitaProgressPayload(pending.chapterId, page, info))
      console.info(`[KavitaSync] step=push_ok page=${page}`)
    } catch (error) {
      void error
      console.warn(`[KavitaSync] step=push_fail page=${page} code=remote_progress_push_failed`)
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

  private mapKavitaProgress(
    comicId: string,
    chapterId: string,
    totalPages: number,
    pageIds: string[],
    remote: KavitaProgressDto
  ): ReadingProgress {
    const pageIndex = clampPageIndex(remote.pageNum - 1, totalPages)
    return {
      comicId,
      chapterId,
      pageId: pageIndex < pageIds.length ? pageIds[pageIndex] : undefined,
      pageIndex,
      totalPages,
      progressRatio: calculateProgressRatio(pageIndex, totalPages),
      completed: totalPages <= 0 || remote.pageNum >= totalPages,
      updatedAt: this.parseRemoteTimestamp(remote.lastModifiedUtc),
    }
  }

  private toKomgaPage(progress: ReadingProgress): number {
    return progress.pageIndex + 1
  }

  private toKavitaPageNum(progress: ReadingProgress): number {
    if (progress.completed) {
      return progress.totalPages
    }
    return progress.pageIndex + 1
  }

  private createKavitaProgressPayload(chapterId: KavitaChapterId, pageNum: number, info: KavitaChapterInfoDto): KavitaProgressDto {
    if (info.volumeId === undefined || info.seriesId === undefined || info.libraryId === undefined) {
      throw new Error('kavita_progress_context_missing')
    }
    return {
      volumeId: info.volumeId,
      chapterId,
      pageNum,
      seriesId: info.seriesId,
      libraryId: info.libraryId,
    } as KavitaProgressDto
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

  private isKavitaSession(config: ReaderSessionConfig): boolean {
    return config.comicId.startsWith('kavita:') && config.chapterId.includes(':chapter:')
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

  private parseKavitaChapterId(chapterId: string): KavitaChapterId | undefined {
    const marker = ':chapter:'
    const index = chapterId.indexOf(marker)
    if (!chapterId.startsWith('kavita:') || index < 0) {
      return undefined
    }
    const parsed = Number.parseInt(chapterId.slice(index + marker.length), 10)
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return undefined
    }
    return parsed
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
