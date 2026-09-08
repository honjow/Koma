import { Chapter, Comic, ComicId, ComicSourceKind } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ReaderSessionStore } from './ReaderSessionStore'
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
  private readonly library: LibraryStore
  private readonly reader: ReaderSessionStore

  constructor(filesDir: string, library: LibraryStore, reader: ReaderSessionStore) {
    this.filesDir = filesDir
    this.library = library
    this.reader = reader
    this.queue = new OfflineDownloadQueueStore(filesDir)
    this.downloads = new OfflineDownloadStore(filesDir)
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
    return OfflineDownloadRuntime.isActive(this.filesDir, comicId, chapterId) ? OfflineDownloadStatus.DOWNLOADING : undefined
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
      const seen = new Set<string>()
      comic.chapters.forEach((chapter: Chapter) => {
        if (chapter.id.length === 0 || seen.has(chapter.id) ||
          (unreadOnly && this.reader.isChapterRead(comicId, chapter.id))) {
          return
        }
        seen.add(chapter.id)
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

  async enqueue(targets: LibraryBatchDownloadTarget[], unreadOnly: boolean): Promise<number> {
    const snapshot = targets.map((target: LibraryBatchDownloadTarget): LibraryBatchDownloadTarget => ({
      comicId: target.comicId, chapterId: target.chapterId, comicTitle: target.comicTitle,
      chapterTitle: target.chapterTitle, pageCount: target.pageCount,
    }))
    await OfflineDownloadService.ensureQueueInitialized(this.filesDir)
    const entries = this.queue.load()
    const additions: OfflineDownloadQueueEntry[] = []
    for (const target of snapshot) {
      const comic = this.library.getComic(target.comicId)
      if (comic === undefined || !this.isRemoteComic(comic) ||
        !comic.chapters.some((chapter: Chapter): boolean => chapter.id === target.chapterId) ||
        (unreadOnly && this.reader.isChapterRead(target.comicId, target.chapterId)) ||
        this.existingStatus(target.comicId, target.chapterId, entries) !== undefined) {
        continue
      }
      additions.push({
        comicId: target.comicId, chapterId: target.chapterId,
        comicTitle: target.comicTitle, chapterTitle: target.chapterTitle,
        status: OfflineDownloadStatus.QUEUED, pageCount: target.pageCount,
        downloadedPageCount: 0, updatedAt: Date.now(),
      })
    }
    return this.queue.addNewEntries(additions)
  }
}
