import { Chapter, Comic, ComicId, ComicSourceKind } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
import { selectedChapterIdsInReadingOrder } from './ReaderChapterSequence'
import { OfflineDownloadQueueEntry, OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { OfflineDownloadStatus, OfflineDownloadStore } from './OfflineDownloadStore'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { OfflineDownloadService } from './OfflineDownloadService'

export interface LibraryBatchDownloadTarget {
  comicId: ComicId
  chapterId: string
  comicTitle: string
  chapterTitle: string
  pageCount: number
}

export interface LibraryBatchDownloadPlan {
  comicCount: number
  matchedChapterCount: number
  downloadedCount: number
  existingCount: number
  unavailableComicCount: number
  targets: LibraryBatchDownloadTarget[]
}

// Creates only new queue entries. Execution/hydration stays with DownloadsPage and OfflineDownloadService.
export class LibraryBatchDownloadQueue {
  private readonly queue: OfflineDownloadQueueStore
  private readonly downloads: OfflineDownloadStore
  private readonly filesDir: string
  private readonly runtimeKeyValue: string
  private readonly library: LibraryStore
  private readonly reader: ReaderSessionStore

  constructor(filesDir: string, library: LibraryStore, reader: ReaderSessionStore, runtimeKey?: string) {
    this.filesDir = filesDir
    this.runtimeKeyValue = runtimeKey ?? filesDir
    this.library = library
    this.reader = reader
    this.queue = new OfflineDownloadQueueStore(filesDir, this.runtimeKeyValue)
    this.downloads = new OfflineDownloadStore(filesDir, this.runtimeKeyValue)
  }

  private isRemoteComic(comic: Comic): boolean {
    return comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY ||
      comic.sourceKind === ComicSourceKind.KOMGA_REMOTE || comic.sourceKind === ComicSourceKind.KAVITA_REMOTE ||
      comic.sourceKind === ComicSourceKind.OPDS_REMOTE || comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE
  }

  private existingStatus(comicId: ComicId, chapterId: string,
    entries: OfflineDownloadQueueEntry[]): OfflineDownloadStatus | undefined {
    const entry = entries.find((item: OfflineDownloadQueueEntry): boolean => item.comicId === comicId && item.chapterId === chapterId)
    if (entry !== undefined) {
      return entry.status
    }
    const manifest = this.downloads.loadManifest(comicId, chapterId)
    if (manifest !== undefined) {
      return manifest.status
    }
    return OfflineDownloadRuntime.isActive(this.runtimeKeyValue, comicId, chapterId) ? OfflineDownloadStatus.DOWNLOADING : undefined
  }

  prepare(comicIds: ComicId[], unreadOnly: boolean): LibraryBatchDownloadPlan {
    const ids = Array.from(new Set<ComicId>(comicIds))
    const entries = this.queue.load()
    const plan: LibraryBatchDownloadPlan = {
      comicCount: ids.length, matchedChapterCount: 0, downloadedCount: 0,
      existingCount: 0, unavailableComicCount: 0, targets: [],
    }
    ids.forEach((comicId: ComicId) => {
      const comic = this.library.getComic(comicId)
      if (comic === undefined || !this.isRemoteComic(comic) || comic.chapters.length === 0) {
        plan.unavailableComicCount += 1
        return
      }
      const chapters = new Map<string, Chapter>()
      comic.chapters.forEach((chapter: Chapter): void => {
        if (!chapters.has(chapter.id)) chapters.set(chapter.id, chapter)
      })
      const chapterIds = selectedChapterIdsInReadingOrder(comic.chapters, Array.from(chapters.keys()))
      chapterIds.forEach((chapterId: string): void => {
        const chapter = chapters.get(chapterId)
        if (chapter === undefined || chapter.id.length === 0 ||
          (unreadOnly && this.reader.isChapterRead(comicId, chapter.id))) {
          return
        }
        plan.matchedChapterCount += 1
        const status = this.existingStatus(comicId, chapter.id, entries)
        if (status === OfflineDownloadStatus.DOWNLOADED) {
          plan.downloadedCount += 1
        } else if (status !== undefined) {
          plan.existingCount += 1
        } else {
          plan.targets.push({ comicId, chapterId: chapter.id, comicTitle: comic.title,
            chapterTitle: chapter.title, pageCount: Math.max(chapter.pages.length, chapter.pageCount) })
        }
      })
    })
    return plan
  }

  async enqueue(targets: LibraryBatchDownloadTarget[], unreadOnly: boolean, automatic: boolean = false): Promise<number> {
    const snapshot = targets.map((target: LibraryBatchDownloadTarget): LibraryBatchDownloadTarget => ({
      comicId: target.comicId, chapterId: target.chapterId, comicTitle: target.comicTitle,
      chapterTitle: target.chapterTitle, pageCount: target.pageCount,
    }))
    await OfflineDownloadService.ensureQueueInitialized(this.filesDir, this.runtimeKeyValue)
    const entries = this.queue.load()
    const additions: OfflineDownloadQueueEntry[] = []
    // Preserve the first requested book's batch position. Recheck chapter order
    // against current metadata after initialization, including automatic requests.
    const byComic = new Map<ComicId, LibraryBatchDownloadTarget[]>()
    snapshot.forEach((target: LibraryBatchDownloadTarget): void => {
      const selected = byComic.get(target.comicId) ?? []
      selected.push(target)
      byComic.set(target.comicId, selected)
    })
    byComic.forEach((selected: LibraryBatchDownloadTarget[], comicId: ComicId): void => {
      const comic = this.library.getComic(comicId)
      if (comic === undefined || !this.isRemoteComic(comic)) return
      const byChapter = new Map<string, LibraryBatchDownloadTarget>()
      selected.forEach((target: LibraryBatchDownloadTarget): void => {
        if (!byChapter.has(target.chapterId)) byChapter.set(target.chapterId, target)
      })
      const chapterIds = selectedChapterIdsInReadingOrder(comic.chapters, Array.from(byChapter.keys()))
      chapterIds.forEach((chapterId: string): void => {
        const target = byChapter.get(chapterId)
        if (target === undefined || !comic.chapters.some((chapter: Chapter): boolean => chapter.id === chapterId) ||
          (unreadOnly && this.reader.isChapterRead(comicId, chapterId)) ||
          this.existingStatus(comicId, chapterId, entries) !== undefined) return
        additions.push({
          automatic: automatic ? true : undefined,
          comicId, chapterId,
          comicTitle: target.comicTitle, chapterTitle: target.chapterTitle,
          status: OfflineDownloadStatus.QUEUED, pageCount: target.pageCount,
          downloadedPageCount: 0, updatedAt: Date.now(),
        })
      })
    })
    return this.queue.addNewEntries(additions)
  }
}
