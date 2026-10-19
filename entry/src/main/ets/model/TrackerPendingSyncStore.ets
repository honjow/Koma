import { common } from '@kit.AbilityKit'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { preferences } from '@kit.ArkData'
import { ChapterId, ComicId, ReadingProgress } from './ComicModels'
import { TrackerProviderId, TrackerUpdateStrategy } from './TrackerModels'

export const TRACKER_PENDING_SYNC_STORE_NAME: string = 'koma_tracker_pending_sync_v1'
export const TRACKER_PENDING_PROGRESS_QUEUE_KEY: string = 'tracker.pendingProgressQueue'

export type TrackerPendingProgressReason =
  'account_missing' |
  'credential_missing' |
  'client_unavailable' |
  'provider_failed'

export interface TrackerPendingProgressSyncEntry {
  providerId: TrackerProviderId
  comicId: ComicId
  chapterId: ChapterId
  chapterIds: string[]
  trigger?: TrackerUpdateStrategy
  pageIndex: number
  totalPages: number
  progressRatio: number
  completed: boolean
  providerProgress: number
  attempts: number
  firstQueuedAt: number
  updatedAt: number
  lastReason: TrackerPendingProgressReason
}

export interface TrackerPendingProgressSummary {
  totalCount: number
  anilistCount: number
  myAnimeListCount: number
  completedCount: number
  failedAttemptCount: number
}

function normalizeFiniteNumber(value: number, fallback: number = 0): number {
  if (!Number.isFinite(value) || value !== value) {
    return fallback
  }
  return value
}

function normalizeCount(value: number): number {
  return Math.max(0, Math.floor(normalizeFiniteNumber(value)))
}

function normalizeRatio(value: number): number {
  return Math.max(0, Math.min(1, normalizeFiniteNumber(value)))
}

function normalizeProviderProgress(value: number): number {
  return Math.max(0, Math.floor(normalizeFiniteNumber(value)))
}

function normalizeTextId(value: string | undefined): string {
  // These are opaque local/source identities, not display text.
  return typeof value === 'string' && value.trim().length > 0 ? value : ''
}

function normalizeChapterIds(chapterIds: string[] | undefined): string[] {
  const result: string[] = []
  const source = Array.isArray(chapterIds) ? chapterIds : []
  source.forEach((chapterId: string) => {
    const normalized = normalizeTextId(chapterId)
    if (normalized.length > 0 && !result.includes(normalized)) {
      result.push(normalized)
    }
  })
  return result
}

function normalizeReason(reason: TrackerPendingProgressReason): TrackerPendingProgressReason {
  if (reason === 'account_missing' ||
    reason === 'credential_missing' ||
    reason === 'client_unavailable' ||
    reason === 'provider_failed') {
    return reason
  }
  return 'provider_failed'
}

function normalizeEntry(entry: TrackerPendingProgressSyncEntry): TrackerPendingProgressSyncEntry | undefined {
  const comicId = normalizeTextId(entry.comicId)
  const chapterId = normalizeTextId(entry.chapterId)
  if ((entry.providerId !== 'anilist' && entry.providerId !== 'myanimelist') || comicId.length === 0 || chapterId.length === 0) {
    return undefined
  }
  const totalPages = normalizeCount(entry.totalPages)
  const pageIndex = Math.min(normalizeCount(entry.pageIndex), Math.max(0, totalPages - 1))
  const chapterIds = normalizeChapterIds(entry.chapterIds)
  const firstQueuedAt = normalizeFiniteNumber(entry.firstQueuedAt, Date.now())
  const updatedAt = normalizeFiniteNumber(entry.updatedAt, firstQueuedAt)
  return {
    providerId: entry.providerId,
    comicId,
    chapterId,
    chapterIds,
    pageIndex,
    totalPages,
    progressRatio: normalizeRatio(entry.progressRatio),
    completed: entry.completed === true,
    providerProgress: normalizeProviderProgress(entry.providerProgress),
    attempts: Math.max(1, normalizeCount(entry.attempts)),
    firstQueuedAt,
    updatedAt,
    lastReason: normalizeReason(entry.lastReason),
    trigger: entry.trigger === 'on_chapter_complete' || entry.trigger === 'on_reader_close' ||
      entry.trigger === 'manual' ? entry.trigger : undefined,
  }
}

function normalizeEntries(entries: TrackerPendingProgressSyncEntry[]): TrackerPendingProgressSyncEntry[] {
  const normalizedEntries: TrackerPendingProgressSyncEntry[] = []
  entries.forEach((entry: TrackerPendingProgressSyncEntry) => {
    const normalized = normalizeEntry(entry)
    if (normalized === undefined) {
      throw new Error('tracker_pending_invalid_entry')
    }
    const existingIndex = normalizedEntries.findIndex((item: TrackerPendingProgressSyncEntry): boolean => {
      return item.providerId === normalized.providerId &&
        item.comicId === normalized.comicId &&
        item.chapterId === normalized.chapterId
    })
    if (existingIndex < 0) {
      normalizedEntries.push(normalized)
    } else if (normalized.updatedAt >= normalizedEntries[existingIndex].updatedAt) {
      normalizedEntries[existingIndex] = normalized
    }
  })
  return normalizedEntries
    .sort((left: TrackerPendingProgressSyncEntry, right: TrackerPendingProgressSyncEntry): number => {
      return right.updatedAt - left.updatedAt
    })
}

export function summarizeTrackerPendingProgress(entries: TrackerPendingProgressSyncEntry[]): TrackerPendingProgressSummary {
  const summary: TrackerPendingProgressSummary = {
    totalCount: 0,
    anilistCount: 0,
    myAnimeListCount: 0,
    completedCount: 0,
    failedAttemptCount: 0,
  }
  normalizeEntries(entries).forEach((entry: TrackerPendingProgressSyncEntry) => {
    summary.totalCount += 1
    if (entry.providerId === 'anilist') {
      summary.anilistCount += 1
    } else if (entry.providerId === 'myanimelist') {
      summary.myAnimeListCount += 1
    }
    if (entry.completed) {
      summary.completedCount += 1
    }
    summary.failedAttemptCount += entry.attempts
  })
  return summary
}

export function readingProgressFromPendingEntry(entry: TrackerPendingProgressSyncEntry, now: number = Date.now()): ReadingProgress {
  const normalized = normalizeEntry(entry)
  if (normalized === undefined) {
    return {
      comicId: '',
      chapterId: '',
      pageIndex: 0,
      totalPages: 0,
      progressRatio: 0,
      completed: false,
      updatedAt: now,
    }
  }
  return {
    comicId: normalized.comicId,
    chapterId: normalized.chapterId,
    pageIndex: normalized.pageIndex,
    totalPages: normalized.totalPages,
    progressRatio: normalized.progressRatio,
    completed: normalized.completed,
    updatedAt: now,
  }
}

// Every Store instance writing this app resource shares one read-modify-flush owner.
const pendingProgressOperations: Map<string, Promise<void>> = new Map()

export class TrackerPendingSyncStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const previous = pendingProgressOperations.get(key) ?? Promise.resolve()
    const result = previous.then(operation)
    const settled = result.then((): void => {}, (): void => {})
    pendingProgressOperations.set(key, settled)
    void settled.then((): void => {
      if (pendingProgressOperations.get(key) === settled) pendingProgressOperations.delete(key)
    })
    return result
  }

  private mutate<T>(operation: () => Promise<T>): Promise<T> {
    return BackupRestoreActivity.runWrite(() => this.ordered(operation))
  }

  loadPendingProgress(): Promise<TrackerPendingProgressSyncEntry[]> {
    return this.ordered(() => this.readPendingProgress())
  }

  private async readPendingProgress(): Promise<TrackerPendingProgressSyncEntry[]> {
    const store = await this.preferences()
    const payload = await store.get(TRACKER_PENDING_PROGRESS_QUEUE_KEY, '[]') as string
    // A corrupt queue is a load failure, never an empty queue that a later write replaces.
    const parsed = JSON.parse(payload) as TrackerPendingProgressSyncEntry[]
    if (!Array.isArray(parsed)) throw new Error('tracker_pending_invalid_payload')
    return normalizeEntries(parsed)
  }

  savePendingProgress(entries: TrackerPendingProgressSyncEntry[]): Promise<TrackerPendingProgressSyncEntry[]> {
    const requested = normalizeEntries(entries)
    return this.mutate(() => this.persistPendingProgress(requested))
  }

  private async persistPendingProgress(entries: TrackerPendingProgressSyncEntry[]): Promise<TrackerPendingProgressSyncEntry[]> {
    const normalized = normalizeEntries(entries)
    const payload = JSON.stringify(normalized)
    const store = await this.preferences()
    const existed = store.hasSync(TRACKER_PENDING_PROGRESS_QUEUE_KEY)
    const previous = store.getSync(TRACKER_PENDING_PROGRESS_QUEUE_KEY, '[]') as string
    try {
      // Keep the complete queue. Platform capacity failures are explicit, not oldest-item eviction.
      await store.put(TRACKER_PENDING_PROGRESS_QUEUE_KEY, payload)
      await store.flush()
    } catch (error) {
      if (existed) store.putSync(TRACKER_PENDING_PROGRESS_QUEUE_KEY, previous)
      else store.deleteSync(TRACKER_PENDING_PROGRESS_QUEUE_KEY)
      try {
        await store.flush()
      } catch (_restoreError) {
        throw new Error('tracker_pending_rollback_failed')
      }
      throw error as Error
    }
    return normalized
  }

  enqueueFailedProgress(
    providerId: TrackerProviderId,
    progress: ReadingProgress,
    chapterIds: string[],
    providerProgress: number,
    reason: TrackerPendingProgressReason,
    now: number = Date.now(),
    trigger?: TrackerUpdateStrategy,
  ): Promise<TrackerPendingProgressSyncEntry> {
    // Capture the reading fact before waiting behind another writer.
    const requested = normalizeEntry({
      providerId, comicId: progress.comicId, chapterId: progress.chapterId, chapterIds,
      pageIndex: progress.pageIndex, totalPages: progress.totalPages,
      progressRatio: progress.progressRatio, completed: progress.completed,
      providerProgress, attempts: 1, firstQueuedAt: now, updatedAt: now, lastReason: reason, trigger,
    })
    if (requested === undefined) return Promise.reject(new Error('tracker_pending_invalid_entry'))
    return this.mutate(async (): Promise<TrackerPendingProgressSyncEntry> => {
      const current = await this.readPendingProgress()
      const existing = current.find((entry: TrackerPendingProgressSyncEntry): boolean =>
        entry.providerId === requested.providerId && entry.comicId === requested.comicId &&
          entry.chapterId === requested.chapterId)
      requested.attempts = existing === undefined ? 1 : existing.attempts + 1
      requested.firstQueuedAt = existing === undefined ? now : existing.firstQueuedAt
      const next = current.filter((entry: TrackerPendingProgressSyncEntry): boolean =>
        entry.providerId !== requested.providerId || entry.comicId !== requested.comicId ||
          entry.chapterId !== requested.chapterId)
      next.unshift(requested)
      await this.persistPendingProgress(next)
      return requested
    })
  }

  private removeMatching(matches: (entry: TrackerPendingProgressSyncEntry) => boolean): Promise<number> {
    return this.mutate(async (): Promise<number> => {
      const current = await this.readPendingProgress()
      const next = current.filter((entry: TrackerPendingProgressSyncEntry): boolean => !matches(entry))
      if (next.length !== current.length) await this.persistPendingProgress(next)
      return current.length - next.length
    })
  }

  removeProgress(providerId: TrackerProviderId, comicId: ComicId, chapterId: ChapterId): Promise<number> {
    return this.removeMatching((entry: TrackerPendingProgressSyncEntry): boolean =>
      entry.providerId === providerId && entry.comicId === comicId && entry.chapterId === chapterId)
  }

  removeProgressThrough(providerId: TrackerProviderId, comicId: ComicId, count: number): Promise<number> {
    return this.removeMatching((entry: TrackerPendingProgressSyncEntry): boolean =>
      entry.providerId === providerId && entry.comicId === comicId && entry.providerProgress <= count)
  }

  removeProgressForComic(providerId: TrackerProviderId, comicId: ComicId): Promise<number> {
    return this.removeMatching((entry: TrackerPendingProgressSyncEntry): boolean =>
      entry.providerId === providerId && entry.comicId === comicId)
  }

  removeProgressForProvider(providerId: TrackerProviderId): Promise<number> {
    return this.removeMatching((entry: TrackerPendingProgressSyncEntry): boolean => entry.providerId === providerId)
  }

  clear(): Promise<void> {
    return this.mutate(async (): Promise<void> => { await this.persistPendingProgress([]) })
  }

  private preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, TRACKER_PENDING_SYNC_STORE_NAME)
  }
}
