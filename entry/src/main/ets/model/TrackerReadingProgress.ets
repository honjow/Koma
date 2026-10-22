import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ReadingProgress } from './ComicModels'
import { ReaderSessionStore } from './ReaderSessionStore'
import { TrackerProgressSyncResult, ReaderTrackerProgressPort } from './TrackerProgressSyncService'
import { TrackerUpdateStrategy, TrackerProviderId } from './TrackerModels'

/** Provider progress is a chapter ordinal, never a position in a display catalog. */
export function trackerChapterProgress(progress: ReadingProgress, chapterNumber?: number): number | undefined {
  if (chapterNumber === undefined || !Number.isFinite(chapterNumber) || chapterNumber < 0) return undefined
  return progress.completed ? Math.floor(chapterNumber) : Math.max(0, Math.ceil(chapterNumber) - 1)
}

export interface TrackerChapterIdentity { id: string; chapterNumber?: number }

export function trackerChapterForProgress(
  chapters: TrackerChapterIdentity[], count: number, currentChapterId?: string,
): string | undefined {
  if (!Number.isSafeInteger(count) || count < 1) return undefined
  const eligible = chapters.filter((chapter: TrackerChapterIdentity): boolean =>
    chapter.chapterNumber !== undefined && Number.isFinite(chapter.chapterNumber) &&
    chapter.chapterNumber >= 0 && chapter.chapterNumber <= count)
  eligible.sort((left: TrackerChapterIdentity, right: TrackerChapterIdentity): number =>
    (right.chapterNumber as number) - (left.chapterNumber as number))
  const number = eligible[0]?.chapterNumber
  if (number === undefined) return undefined
  return eligible.find((chapter: TrackerChapterIdentity): boolean =>
    chapter.chapterNumber === number && chapter.id === currentChapterId)?.id ?? eligible[0].id
}


interface ObservedTrackerProgress {
  progress: ReadingProgress
  chapterIds: string[]
  chapterNumber?: number
}

/** Host-only business events. Backups and mark-read mutations are not Reader observations. */
export class ReaderTrackerProgressCoordinator {
  private readingEpoch: number = 0
  private restoreEpoch: number = 0
  private latest?: ObservedTrackerProgress
  private completed: Set<string> = new Set()
  private pending: Map<string, ObservedTrackerProgress> = new Map()
  private store: ReaderSessionStore
  private port: ReaderTrackerProgressPort

  constructor(store: ReaderSessionStore, port: ReaderTrackerProgressPort) {
    this.store = store
    this.port = port
  }

  beginReading(): void {
    this.readingEpoch += 1
    this.latest = undefined
    this.completed.clear()
  }

  resetAfterRestore(): void {
    this.restoreEpoch += 1
    this.beginReading()
    this.pending.clear()
  }

  observe(progress: ReadingProgress, chapterIds: string[], chapterNumber?: number): void {
    const snapshot: ObservedTrackerProgress = {
      progress: { comicId: progress.comicId, chapterId: progress.chapterId, pageId: progress.pageId,
        pageIndex: progress.pageIndex, totalPages: progress.totalPages, progressRatio: progress.progressRatio,
        completed: progress.completed, updatedAt: progress.updatedAt, columnMode: progress.columnMode },
      chapterIds: chapterIds.slice(), chapterNumber,
    }
    this.latest = snapshot
    if (!progress.completed) return
    const key = JSON.stringify([progress.comicId, progress.chapterId])
    if (this.completed.has(key)) return
    this.pending.set(key, snapshot)
    if (this.store.flush()) this.drainCompletions()
    else DiagnosticLogger.warn('tracker_reading_progress', 'deferred', '[ReaderTracker] step=deferred reason=local_progress_commit')
  }

  close(progressCommitted: boolean): void {
    const latest = this.latest
    this.latest = undefined
    if (!progressCommitted) {
      DiagnosticLogger.warn('tracker_reading_progress', 'deferred', '[ReaderTracker] step=deferred reason=local_progress_commit')
      return
    }
    this.drainCompletions()
    if (latest === undefined) return
    // Retain the store's independent read fact when a previously read chapter
    // is revisited, or Legacy's close observation is no longer terminal-visible.
    const saved = this.store.getChapterProgress(latest.progress.comicId, latest.progress.chapterId)
    if (saved !== undefined) {
      const copied: ReadingProgress = { comicId: saved.comicId, chapterId: saved.chapterId,
        pageId: saved.pageId, pageIndex: saved.pageIndex, totalPages: saved.totalPages,
        progressRatio: saved.progressRatio, completed: saved.completed, updatedAt: saved.updatedAt,
        columnMode: saved.columnMode }
      this.submit({ progress: copied, chapterIds: latest.chapterIds.slice(),
        chapterNumber: latest.chapterNumber }, 'on_reader_close')
    }
  }

  private drainCompletions(): void {
    this.pending.forEach((snapshot: ObservedTrackerProgress, key: string): void => {
      this.pending.delete(key)
      if (this.completed.has(key)) return
      this.completed.add(key)
      this.submit(snapshot, 'on_chapter_complete', key)
    })
  }

  private submit(snapshot: ObservedTrackerProgress, trigger: TrackerUpdateStrategy, completionKey?: string): void {
    const readingEpoch = this.readingEpoch
    const restoreEpoch = this.restoreEpoch
    const count = trackerChapterProgress(snapshot.progress, snapshot.chapterNumber)
    void this.port.pushReadingProgress(snapshot.progress, snapshot.chapterIds, trigger, Date.now(), undefined, count ?? null)
      .then((result: TrackerProgressSyncResult): void => {
        console.info('[ReaderTracker] step=event trigger=' + trigger + ' status=' + result.status +
          ' reason=' + (result.reason ?? 'none') + ' queued=' + (result.queued === true))
      })
      .catch((_error: Error): void => {
        if (completionKey !== undefined && restoreEpoch === this.restoreEpoch) {
          if (readingEpoch === this.readingEpoch) this.completed.delete(completionKey)
          const newer = this.pending.get(completionKey)
          if (newer === undefined || newer.progress.updatedAt <= snapshot.progress.updatedAt) {
            this.pending.set(completionKey, snapshot)
          }
        }
        DiagnosticLogger.warn('tracker_reading_progress', 'event_failed', '[ReaderTracker] step=event_failed trigger=' + trigger)
      })
  }
}
