import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ChapterId, ComicId, ReadingProgress } from './ComicModels'
import { TrackerProviderId } from './TrackerModels'

export const TRACKER_PENDING_SYNC_STORE_NAME: string = 'koma_tracker_pending_sync_v1'
export const TRACKER_PENDING_PROGRESS_QUEUE_KEY: string = 'tracker.pendingProgressQueue'
export const TRACKER_PENDING_PROGRESS_MAX_ENTRIES: number = 100

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

function normalizeTextId(value: string | undefined, maxLength: number): string {
  if (value === undefined) {
    return ''
  }
  return value.trim().slice(0, maxLength)
}

function normalizeChapterIds(chapterIds: string[] | undefined): string[] {
  const result: string[] = []
  const source = Array.isArray(chapterIds) ? chapterIds : []
  source.forEach((chapterId: string) => {
    const normalized = normalizeTextId(chapterId, 256)
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
  const comicId = normalizeTextId(entry.comicId, 256)
  const chapterId = normalizeTextId(entry.chapterId, 256)
  if (entry.providerId !== 'anilist' || comicId.length === 0 || chapterId.length === 0) {
    return undefined
  }
  const totalPages = normalizeCount(entry.totalPages)
  const pageIndex = Math.min(normalizeCount(entry.pageIndex), Math.max(0, totalPages - 1))
  const chapterIds = normalizeChapterIds(entry.chapterIds)
  const firstQueuedAt = normalizeFiniteNumber(entry.firstQueuedAt, Date.now())
  const updatedAt = normalizeFiniteNumber(entry.updatedAt, firstQueuedAt)
  return {
    providerId: 'anilist',
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
  }
}

function normalizeEntries(entries: TrackerPendingProgressSyncEntry[]): TrackerPendingProgressSyncEntry[] {
  const normalizedEntries: TrackerPendingProgressSyncEntry[] = []
  entries.forEach((entry: TrackerPendingProgressSyncEntry) => {
    const normalized = normalizeEntry(entry)
    if (normalized === undefined) {
      return
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
    .slice(0, TRACKER_PENDING_PROGRESS_MAX_ENTRIES)
}

export function summarizeTrackerPendingProgress(entries: TrackerPendingProgressSyncEntry[]): TrackerPendingProgressSummary {
  const summary: TrackerPendingProgressSummary = {
    totalCount: 0,
    anilistCount: 0,
    completedCount: 0,
    failedAttemptCount: 0,
  }
  normalizeEntries(entries).forEach((entry: TrackerPendingProgressSyncEntry) => {
    summary.totalCount += 1
    if (entry.providerId === 'anilist') {
      summary.anilistCount += 1
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

export class TrackerPendingSyncStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async loadPendingProgress(): Promise<TrackerPendingProgressSyncEntry[]> {
    const store = await this.preferences()
    const payload = await store.get(TRACKER_PENDING_PROGRESS_QUEUE_KEY, '[]') as string
    return this.parseEntries(payload)
  }

  async savePendingProgress(entries: TrackerPendingProgressSyncEntry[]): Promise<TrackerPendingProgressSyncEntry[]> {
    const normalized = normalizeEntries(entries)
    const store = await this.preferences()
    await store.put(TRACKER_PENDING_PROGRESS_QUEUE_KEY, JSON.stringify(normalized))
    await store.flush()
    return normalized
  }

  async enqueueFailedProgress(
    progress: ReadingProgress,
    chapterIds: string[],
    providerProgress: number,
    reason: TrackerPendingProgressReason,
    now: number = Date.now(),
  ): Promise<TrackerPendingProgressSyncEntry> {
    const current = await this.loadPendingProgress()
    const existing = current.find((entry: TrackerPendingProgressSyncEntry): boolean => {
      return entry.providerId === 'anilist' &&
        entry.comicId === progress.comicId &&
        entry.chapterId === progress.chapterId
    })
    const next: TrackerPendingProgressSyncEntry = {
      providerId: 'anilist',
      comicId: progress.comicId,
      chapterId: progress.chapterId,
      chapterIds,
      pageIndex: progress.pageIndex,
      totalPages: progress.totalPages,
      progressRatio: progress.progressRatio,
      completed: progress.completed,
      providerProgress,
      attempts: existing === undefined ? 1 : existing.attempts + 1,
      firstQueuedAt: existing === undefined ? now : existing.firstQueuedAt,
      updatedAt: now,
      lastReason: reason,
    }
    const entries = current.filter((entry: TrackerPendingProgressSyncEntry): boolean => {
      return entry.providerId !== 'anilist' ||
        entry.comicId !== progress.comicId ||
        entry.chapterId !== progress.chapterId
    })
    entries.unshift(next)
    const saved = await this.savePendingProgress(entries)
    return saved.find((entry: TrackerPendingProgressSyncEntry): boolean => {
      return entry.providerId === 'anilist' &&
        entry.comicId === progress.comicId &&
        entry.chapterId === progress.chapterId
    }) ?? next
  }

  async removeProgress(providerId: TrackerProviderId, comicId: ComicId, chapterId: ChapterId): Promise<number> {
    const current = await this.loadPendingProgress()
    const next = current.filter((entry: TrackerPendingProgressSyncEntry): boolean => {
      return entry.providerId !== providerId || entry.comicId !== comicId || entry.chapterId !== chapterId
    })
    if (next.length === current.length) {
      return 0
    }
    await this.savePendingProgress(next)
    return current.length - next.length
  }

  async clear(): Promise<void> {
    await this.savePendingProgress([])
  }

  private parseEntries(payload: string): TrackerPendingProgressSyncEntry[] {
    try {
      const parsed = JSON.parse(payload) as TrackerPendingProgressSyncEntry[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return normalizeEntries(parsed)
    } catch (_error) {
      return []
    }
  }

  private preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, TRACKER_PENDING_SYNC_STORE_NAME)
  }
}
