import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { ReadingProgress } from './ComicModels'
import {
  AniListTrackerClient,
  AniListTrackerProgress,
  HarmonyAniListTrackerHttpAdapter,
} from './AniListTrackerClient'
import {
  AssetStoreTrackerCredentialSecretStore,
  ComicTrackerMapping,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferences,
  TrackerPreferencesStore,
} from './TrackerModels'
import {
  readingProgressFromPendingEntry,
  TrackerPendingProgressReason,
  TrackerPendingSyncStore,
} from './TrackerPendingSyncStore'

export type TrackerProgressSyncStatus = 'synced' | 'skipped' | 'failed'
export type TrackerProgressSyncReason =
  'auto_sync_disabled' |
  'strategy_not_due' |
  'mapping_missing' |
  'account_missing' |
  'credential_missing' |
  'client_unavailable' |
  'remote_progress_missing' |
  'provider_failed'

export interface TrackerProgressSyncResult {
  status: TrackerProgressSyncStatus
  reason?: TrackerProgressSyncReason
  providerId?: 'anilist'
  providerTitleId?: string
  providerProgress?: number
  completed?: boolean
  queued?: boolean
}

export interface TrackerProgressSyncServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  aniListClient?: AniListTrackerClient
  pendingStore?: TrackerPendingSyncStore
}

export interface TrackerPendingProgressDrainSummary {
  scannedCount: number
  syncedCount: number
  retainedCount: number
  failedCount: number
  skippedCount: number
}

export function calculateAniListChapterProgress(progress: ReadingProgress, chapterIds: string[]): number {
  const chapterIndex = chapterIds.indexOf(progress.chapterId)
  if (chapterIndex < 0) {
    return progress.completed ? 1 : 0
  }
  return progress.completed ? chapterIndex + 1 : chapterIndex
}

export class TrackerProgressSyncService {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore
  private aniListClient?: AniListTrackerClient
  private pendingStore: TrackerPendingSyncStore

  constructor(context: common.UIAbilityContext, options: TrackerProgressSyncServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.aniListClient = options.aniListClient ?? new AniListTrackerClient(new HarmonyAniListTrackerHttpAdapter())
    this.pendingStore = options.pendingStore ?? new TrackerPendingSyncStore(context)
  }

  async pushReadingProgress(progress: ReadingProgress, chapterIds: string[], now: number = Date.now()): Promise<TrackerProgressSyncResult> {
    const preferences = await this.preferencesStore().load()
    if (!preferences.autoSyncEnabled) {
      return this.skipped('auto_sync_disabled')
    }
    if (preferences.updateStrategy !== 'on_chapter_complete') {
      return this.skipped('strategy_not_due')
    }
    const mapping = this.findConfirmedAniListMapping(preferences, progress.comicId)
    if (mapping === undefined) {
      return this.skipped('mapping_missing')
    }
    const providerProgress = calculateAniListChapterProgress(progress, chapterIds)
    const account = this.findConnectedAniListAccount(preferences)
    if (account === undefined || account.credentialAccountKey === undefined) {
      return this.failedWithPendingQueue('account_missing', mapping, progress, chapterIds, providerProgress, now)
    }
    if (this.aniListClient === undefined) {
      return this.failedWithPendingQueue('client_unavailable', mapping, progress, chapterIds, providerProgress, now)
    }
    const accessToken = await this.readAccessToken(account)
    if (accessToken === undefined) {
      return this.failedWithPendingQueue('credential_missing', mapping, progress, chapterIds, providerProgress, now)
    }
    const result = await this.aniListClient.pushProgress(accessToken, mapping.providerTitleId, providerProgress, progress.completed)
    if (!result.ok || result.value === undefined) {
      return this.failedWithPendingQueue('provider_failed', mapping, progress, chapterIds, providerProgress, now)
    }
    await this.markAniListAccountSynced(preferences, account, now)
    await this.pendingStore.removeProgress('anilist', progress.comicId, progress.chapterId)
    return {
      status: 'synced',
      providerId: 'anilist',
      providerTitleId: mapping.providerTitleId,
      providerProgress: result.value.progress,
      completed: result.value.completed,
    }
  }

  async pullReadingProgress(comicId: string, now: number = Date.now()): Promise<TrackerProgressSyncResult> {
    const preferences = await this.preferencesStore().load()
    const mapping = this.findConfirmedAniListMapping(preferences, comicId)
    if (mapping === undefined) {
      return this.skipped('mapping_missing')
    }
    const account = this.findConnectedAniListAccount(preferences)
    if (account === undefined || account.credentialAccountKey === undefined) {
      return this.failed('account_missing', mapping)
    }
    if (this.aniListClient === undefined) {
      return this.failed('client_unavailable', mapping)
    }
    const accessToken = await this.readAccessToken(account)
    if (accessToken === undefined) {
      return this.failed('credential_missing', mapping)
    }
    const result = await this.aniListClient.fetchProgress(accessToken, mapping.providerTitleId)
    if (!result.ok) {
      return this.failed('provider_failed', mapping)
    }
    await this.markAniListAccountSynced(preferences, account, now)
    return this.progressResult(mapping, result.value)
  }

  async retryPendingProgress(limit: number = 20, now: number = Date.now()): Promise<TrackerPendingProgressDrainSummary> {
    const pending = await this.pendingStore.loadPendingProgress()
    const normalizedLimit = Math.max(0, Math.min(50, Math.floor(limit)))
    const entries = pending.slice(0, normalizedLimit)
    const summary: TrackerPendingProgressDrainSummary = {
      scannedCount: entries.length,
      syncedCount: 0,
      retainedCount: 0,
      failedCount: 0,
      skippedCount: 0,
    }
    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index]
      const progress = readingProgressFromPendingEntry(entry, now)
      if (progress.comicId.length === 0 || progress.chapterId.length === 0) {
        summary.skippedCount += 1
        continue
      }
      const result = await this.pushReadingProgress(progress, entry.chapterIds, now)
      if (result.status === 'synced') {
        summary.syncedCount += 1
      } else {
        summary.retainedCount += 1
        if (result.status === 'failed') {
          summary.failedCount += 1
        } else {
          summary.skippedCount += 1
        }
      }
    }
    return summary
  }

  private preferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context, this.secretStore)
  }

  private findConfirmedAniListMapping(preferences: TrackerPreferences, comicId: string): ComicTrackerMapping | undefined {
    return preferences.comicMappings.find((mapping: ComicTrackerMapping): boolean => {
      return mapping.comicId === comicId &&
        mapping.providerId === 'anilist' &&
        mapping.mappingState === 'confirmed' &&
        mapping.userConfirmed
    })
  }

  private findConnectedAniListAccount(preferences: TrackerPreferences): TrackerAccount | undefined {
    return preferences.accounts.find((account: TrackerAccount): boolean => {
      return account.providerId === 'anilist' && account.status === 'connected'
    })
  }

  private async readAccessToken(account: TrackerAccount): Promise<string | undefined> {
    if (account.credentialAccountKey === undefined) {
      return undefined
    }
    const tokenBytes = await this.secretStore.readToken({
      providerId: 'anilist',
      accountKey: account.credentialAccountKey,
      secretKind: 'access_token',
    })
    if (tokenBytes === undefined || tokenBytes.byteLength === 0) {
      return undefined
    }
    const token = buffer.from(tokenBytes.buffer).toString('utf-8').trim()
    return token.length === 0 ? undefined : token
  }

  private async markAniListAccountSynced(preferences: TrackerPreferences, account: TrackerAccount, now: number): Promise<void> {
    const nextAccounts = preferences.accounts.map((item: TrackerAccount): TrackerAccount => {
      if (item.providerId !== account.providerId) {
        return item
      }
      const next: TrackerAccount = {
        providerId: item.providerId,
        status: item.status,
        lastSyncAt: now,
      }
      if (item.profile !== undefined) {
        next.profile = item.profile
      }
      if (item.credentialAccountKey !== undefined) {
        next.credentialAccountKey = item.credentialAccountKey
      }
      if (item.connectedAt !== undefined) {
        next.connectedAt = item.connectedAt
      }
      if (item.statusReason !== undefined) {
        next.statusReason = item.statusReason
      }
      return next
    })
    await this.preferencesStore().saveAccounts(nextAccounts)
  }

  private progressResult(mapping: ComicTrackerMapping, progress: AniListTrackerProgress | undefined): TrackerProgressSyncResult {
    if (progress === undefined) {
      return {
        status: 'skipped',
        reason: 'remote_progress_missing',
        providerId: 'anilist',
        providerTitleId: mapping.providerTitleId,
      }
    }
    return {
      status: 'synced',
      providerId: 'anilist',
      providerTitleId: mapping.providerTitleId,
      providerProgress: progress.progress,
      completed: progress.completed,
    }
  }

  private skipped(reason: TrackerProgressSyncReason): TrackerProgressSyncResult {
    return {
      status: 'skipped',
      reason,
      providerId: 'anilist',
    }
  }

  private failed(reason: TrackerProgressSyncReason, mapping?: ComicTrackerMapping): TrackerProgressSyncResult {
    const result: TrackerProgressSyncResult = {
      status: 'failed',
      reason,
      providerId: 'anilist',
    }
    if (mapping !== undefined) {
      result.providerTitleId = mapping.providerTitleId
    }
    return result
  }

  private async failedWithPendingQueue(
    reason: TrackerPendingProgressReason,
    mapping: ComicTrackerMapping,
    progress: ReadingProgress,
    chapterIds: string[],
    providerProgress: number,
    now: number,
  ): Promise<TrackerProgressSyncResult> {
    const result = this.failed(reason, mapping)
    await this.pendingStore.enqueueFailedProgress(progress, chapterIds, providerProgress, reason, now)
    result.queued = true
    return result
  }
}
