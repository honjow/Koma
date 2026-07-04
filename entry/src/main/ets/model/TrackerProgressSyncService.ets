import { common } from '@kit.AbilityKit'
import { ReadingProgress } from './ComicModels'
import {
  AniListTrackerClient,
  AniListTrackerProgress,
  HarmonyAniListTrackerHttpAdapter,
} from './AniListTrackerClient'
import {
  HarmonyMyAnimeListTrackerHttpAdapter,
  MyAnimeListTrackerClient,
  MyAnimeListTrackerProgress,
} from './MyAnimeListTrackerClient'
import {
  AssetStoreTrackerCredentialSecretStore,
  ComicTrackerMapping,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferences,
  TrackerPreferencesStore,
  TrackerProviderId,
  TrackerUpdateStrategy,
  decodeTrackerSecretBytes,
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
  providerId?: TrackerProviderId
  providerTitleId?: string
  providerProgress?: number
  completed?: boolean
  queued?: boolean
}

export interface TrackerProgressSyncServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  aniListClient?: AniListTrackerClient
  myAnimeListClient?: MyAnimeListTrackerClient
  pendingStore?: TrackerPendingSyncStore
}

export interface TrackerPendingProgressDrainSummary {
  scannedCount: number
  syncedCount: number
  retainedCount: number
  failedCount: number
  skippedCount: number
}

interface TrackerProviderProgressResult {
  ok: boolean
  value?: AniListTrackerProgress | MyAnimeListTrackerProgress
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
  private myAnimeListClient?: MyAnimeListTrackerClient
  private pendingStore: TrackerPendingSyncStore

  constructor(context: common.UIAbilityContext, options: TrackerProgressSyncServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.aniListClient = options.aniListClient ?? new AniListTrackerClient(new HarmonyAniListTrackerHttpAdapter())
    this.myAnimeListClient = options.myAnimeListClient ?? new MyAnimeListTrackerClient(new HarmonyMyAnimeListTrackerHttpAdapter())
    this.pendingStore = options.pendingStore ?? new TrackerPendingSyncStore(context)
  }

  async pushReadingProgress(
    progress: ReadingProgress,
    chapterIds: string[],
    trigger: TrackerUpdateStrategy = 'on_chapter_complete',
    now: number = Date.now(),
    preferredProviderId?: TrackerProviderId,
  ): Promise<TrackerProgressSyncResult> {
    const preferences = await this.preferencesStore().load()
    if (!preferences.autoSyncEnabled) {
      return this.skipped('auto_sync_disabled')
    }
    if (trigger === 'on_chapter_complete' && !progress.completed) {
      return this.skipped('strategy_not_due')
    }
    if (trigger !== 'manual' && preferences.updateStrategy !== trigger) {
      return this.skipped('strategy_not_due')
    }
    const mapping = this.findConfirmedMapping(preferences, progress.comicId, preferredProviderId)
    if (mapping === undefined) {
      return this.skipped('mapping_missing')
    }
    const providerProgress = calculateAniListChapterProgress(progress, chapterIds)
    const account = this.findConnectedAccount(preferences, mapping.providerId)
    if (account === undefined || account.credentialAccountKey === undefined) {
      return this.failedWithPendingQueue('account_missing', mapping, progress, chapterIds, providerProgress, now)
    }
    if (!this.hasClientForProvider(mapping.providerId)) {
      return this.failedWithPendingQueue('client_unavailable', mapping, progress, chapterIds, providerProgress, now)
    }
    const accessToken = await this.readAccessToken(account, mapping.providerId)
    if (accessToken === undefined) {
      return this.failedWithPendingQueue('credential_missing', mapping, progress, chapterIds, providerProgress, now)
    }
    const result = await this.pushProviderProgress(mapping.providerId, accessToken, mapping.providerTitleId, providerProgress, progress.completed)
    if (!result.ok || result.value === undefined) {
      return this.failedWithPendingQueue('provider_failed', mapping, progress, chapterIds, providerProgress, now)
    }
    await this.markAccountSynced(preferences, account, now)
    await this.pendingStore.removeProgressForComic(mapping.providerId, progress.comicId)
    return {
      status: 'synced',
      providerId: mapping.providerId,
      providerTitleId: mapping.providerTitleId,
      providerProgress: result.value.progress,
      completed: result.value.completed,
    }
  }

  async pullReadingProgress(comicId: string, now: number = Date.now(), preferredProviderId?: TrackerProviderId): Promise<TrackerProgressSyncResult> {
    const preferences = await this.preferencesStore().load()
    const mapping = this.findConfirmedMapping(preferences, comicId, preferredProviderId)
    if (mapping === undefined) {
      return this.skipped('mapping_missing')
    }
    const account = this.findConnectedAccount(preferences, mapping.providerId)
    if (account === undefined || account.credentialAccountKey === undefined) {
      return this.failed('account_missing', mapping)
    }
    if (!this.hasClientForProvider(mapping.providerId)) {
      return this.failed('client_unavailable', mapping)
    }
    const accessToken = await this.readAccessToken(account, mapping.providerId)
    if (accessToken === undefined) {
      return this.failed('credential_missing', mapping)
    }
    const result = await this.fetchProviderProgress(mapping.providerId, accessToken, mapping.providerTitleId)
    if (!result.ok) {
      return this.failed('provider_failed', mapping)
    }
    await this.markAccountSynced(preferences, account, now)
    return this.progressResult(mapping, result.value)
  }

  async retryPendingProgress(limit: number = 20, now: number = Date.now()): Promise<TrackerPendingProgressDrainSummary> {
    const pending = await this.pendingStore.loadPendingProgress()
    const normalizedLimit = Math.max(0, Math.min(50, Math.floor(limit)))
    const entries = pending.slice(0, normalizedLimit)
    const preferences = await this.preferencesStore().load()
    const summary: TrackerPendingProgressDrainSummary = {
      scannedCount: entries.length,
      syncedCount: 0,
      retainedCount: 0,
      failedCount: 0,
      skippedCount: 0,
    }
    if (!preferences.autoSyncEnabled) {
      summary.retainedCount = entries.length
      summary.skippedCount = entries.length
      return summary
    }
    const syncedComicKeys: string[] = []
    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index]
      const comicKey = `${entry.providerId}:${entry.comicId}`
      if (syncedComicKeys.includes(comicKey)) {
        summary.skippedCount += 1
        continue
      }
      const progress = readingProgressFromPendingEntry(entry, now)
      if (progress.comicId.length === 0 || progress.chapterId.length === 0) {
        summary.skippedCount += 1
        continue
      }
      const result = await this.pushReadingProgress(progress, entry.chapterIds, 'manual', now, entry.providerId)
      if (result.status === 'synced') {
        summary.syncedCount += 1
        syncedComicKeys.push(comicKey)
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

  private isSupportedProgressProvider(providerId: TrackerProviderId): boolean {
    return providerId === 'anilist' || providerId === 'myanimelist'
  }

  private findConfirmedMapping(preferences: TrackerPreferences, comicId: string, providerId?: TrackerProviderId): ComicTrackerMapping | undefined {
    return preferences.comicMappings.find((mapping: ComicTrackerMapping): boolean => {
      return mapping.comicId === comicId &&
        (providerId === undefined || mapping.providerId === providerId) &&
        this.isSupportedProgressProvider(mapping.providerId) &&
        mapping.mappingState === 'confirmed' &&
        mapping.userConfirmed
    })
  }

  private findConnectedAccount(preferences: TrackerPreferences, providerId: TrackerProviderId): TrackerAccount | undefined {
    return preferences.accounts.find((account: TrackerAccount): boolean => {
      return account.providerId === providerId && account.status === 'connected'
    })
  }

  private async readAccessToken(account: TrackerAccount, providerId: TrackerProviderId): Promise<string | undefined> {
    if (account.credentialAccountKey === undefined) {
      return undefined
    }
    const tokenBytes = await this.secretStore.readToken({
      providerId,
      accountKey: account.credentialAccountKey,
      secretKind: 'access_token',
    })
    if (tokenBytes === undefined || tokenBytes.byteLength === 0) {
      return undefined
    }
    const token = decodeTrackerSecretBytes(tokenBytes).trim()
    return token.length === 0 ? undefined : token
  }

  private hasClientForProvider(providerId: TrackerProviderId): boolean {
    if (providerId === 'anilist') {
      return this.aniListClient !== undefined
    }
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient !== undefined
    }
    return false
  }

  private async pushProviderProgress(
    providerId: TrackerProviderId,
    accessToken: string,
    providerTitleId: string,
    providerProgress: number,
    completed: boolean,
  ): Promise<TrackerProviderProgressResult> {
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient === undefined
        ? { ok: false }
        : this.myAnimeListClient.pushProgress(accessToken, providerTitleId, providerProgress, completed)
    }
    return this.aniListClient === undefined
      ? { ok: false }
      : this.aniListClient.pushProgress(accessToken, providerTitleId, providerProgress, completed)
  }

  private async fetchProviderProgress(
    providerId: TrackerProviderId,
    accessToken: string,
    providerTitleId: string,
  ): Promise<TrackerProviderProgressResult> {
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient === undefined
        ? { ok: false }
        : this.myAnimeListClient.fetchProgress(accessToken, providerTitleId)
    }
    return this.aniListClient === undefined
      ? { ok: false }
      : this.aniListClient.fetchProgress(accessToken, providerTitleId)
  }

  private async markAccountSynced(preferences: TrackerPreferences, account: TrackerAccount, now: number): Promise<void> {
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

  private progressResult(mapping: ComicTrackerMapping, progress: AniListTrackerProgress | MyAnimeListTrackerProgress | undefined): TrackerProgressSyncResult {
    if (progress === undefined) {
      return {
        status: 'skipped',
        reason: 'remote_progress_missing',
        providerId: mapping.providerId,
        providerTitleId: mapping.providerTitleId,
      }
    }
    return {
      status: 'synced',
      providerId: mapping.providerId,
      providerTitleId: mapping.providerTitleId,
      providerProgress: progress.progress,
      completed: progress.completed,
    }
  }

  private skipped(reason: TrackerProgressSyncReason): TrackerProgressSyncResult {
    return {
      status: 'skipped',
      reason,
    }
  }

  private failed(reason: TrackerProgressSyncReason, mapping?: ComicTrackerMapping): TrackerProgressSyncResult {
    const result: TrackerProgressSyncResult = {
      status: 'failed',
      reason,
      providerId: mapping?.providerId,
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
    await this.pendingStore.enqueueFailedProgress(mapping.providerId, progress, chapterIds, providerProgress, reason, now)
    result.queued = true
    return result
  }
}
