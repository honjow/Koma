import { readBangumiAccessToken } from './BangumiTrackerOAuth'
import { TRACKER_REMOTE_PROVIDER_IDS, TrackerEntryFields } from './TrackerModels'
import { KitsuTrackerClient } from './KitsuTrackerClient'
import { BangumiTrackerClient, MangaUpdatesTrackerClient } from './AdditionalTrackerClients'
import { BackupRestoreActivity } from './BackupRestoreActivity'
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
  'chapter_progress_unknown' |
  'mapping_missing' |
  'account_missing' |
  'credential_missing' |
  'client_unavailable' |
  'remote_progress_missing' |
  'provider_failed'

export interface TrackerProgressSyncResult extends TrackerEntryFields {
  status: TrackerProgressSyncStatus
  reason?: TrackerProgressSyncReason
  providerId?: TrackerProviderId
  providerTitleId?: string
  providerProgress?: number
  providerStatus?: string
  completed?: boolean
  queued?: boolean
}

export interface TrackerProgressSyncServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  aniListClient?: AniListTrackerClient
  myAnimeListClient?: MyAnimeListTrackerClient
  bangumiClient?: BangumiTrackerClient
  mangaUpdatesClient?: MangaUpdatesTrackerClient
  kitsuClient?: KitsuTrackerClient
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

const trackerProgressWrites: Map<string, Promise<void>> = new Map()

function mutateTrackerProgress<T>(filesDir: string, operation: () => Promise<T>): Promise<T> {
  const previous = trackerProgressWrites.get(filesDir) ?? Promise.resolve()
  const result = previous.catch((): void => {}).then(operation)
  const settled = result.then((): void => {}, (): void => {})
  trackerProgressWrites.set(filesDir, settled)
  void settled.then((): void => {
    if (trackerProgressWrites.get(filesDir) === settled) trackerProgressWrites.delete(filesDir)
  })
  return result
}

export interface ReaderTrackerProgressPort {
  pushReadingProgress(progress: ReadingProgress, chapterIds: string[], trigger?: TrackerUpdateStrategy,
    now?: number, preferredProviderId?: TrackerProviderId, providerProgress?: number | null): Promise<TrackerProgressSyncResult>
}

export class TrackerProgressSyncService implements ReaderTrackerProgressPort {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore
  private aniListClient?: AniListTrackerClient
  private myAnimeListClient?: MyAnimeListTrackerClient
  private bangumiClient?: BangumiTrackerClient
  private mangaUpdatesClient?: MangaUpdatesTrackerClient
  private kitsuClient?: KitsuTrackerClient
  private pendingStore: TrackerPendingSyncStore

  constructor(context: common.UIAbilityContext, options: TrackerProgressSyncServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.aniListClient = options.aniListClient ?? new AniListTrackerClient(new HarmonyAniListTrackerHttpAdapter())
    this.myAnimeListClient = options.myAnimeListClient ?? new MyAnimeListTrackerClient(new HarmonyMyAnimeListTrackerHttpAdapter())
    this.bangumiClient = options.bangumiClient ?? new BangumiTrackerClient()
    this.mangaUpdatesClient = options.mangaUpdatesClient ?? new MangaUpdatesTrackerClient()
    this.kitsuClient = options.kitsuClient ?? new KitsuTrackerClient()
    this.pendingStore = options.pendingStore ?? new TrackerPendingSyncStore(context)
  }

  async pushReadingProgress(
    progress: ReadingProgress,
    chapterIds: string[],
    trigger: TrackerUpdateStrategy = 'on_chapter_complete',
    now: number = Date.now(),
    preferredProviderId?: TrackerProviderId,
    providerProgress?: number | null,
  ): Promise<TrackerProgressSyncResult> {
    return BackupRestoreActivity.runWrite(() => mutateTrackerProgress(this.context.filesDir, async (): Promise<TrackerProgressSyncResult> => {
      if (preferredProviderId !== undefined || trigger === 'manual') {
        return this.pushReadingProgressNow(progress, chapterIds, trigger, now, preferredProviderId, providerProgress)
      }
      // Reader events target every confirmed service. Each provider keeps its own retry entry.
      const preferences = await this.preferencesStore().load()
      if (!preferences.autoSyncEnabled) return this.skipped('auto_sync_disabled')
      if (preferences.updateStrategy !== trigger || (trigger === 'on_chapter_complete' && !progress.completed)) {
        return this.skipped('strategy_not_due')
      }
      let summary = this.skipped('mapping_missing')
      for (const providerId of TRACKER_REMOTE_PROVIDER_IDS) {
        if (this.findConfirmedMapping(preferences, progress.comicId, providerId) === undefined) continue
        const result = await this.pushReadingProgressNow(progress, chapterIds, trigger, now, providerId, providerProgress)
        if (summary.status !== 'failed') summary = result
      }
      return summary
    }))
  }

  private async pushReadingProgressNow(
    progress: ReadingProgress, chapterIds: string[], trigger: TrackerUpdateStrategy,
    now: number, preferredProviderId?: TrackerProviderId, count?: number | null,
    origin: TrackerUpdateStrategy = trigger,
  ): Promise<TrackerProgressSyncResult> {
      const preferences = await this.preferencesStore().load()
      if (trigger !== 'manual' && !preferences.autoSyncEnabled) {
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
      // Undefined retains the previous API for existing callers/backups. Every
      // current UI/Reader producer supplies an explicit ordinal or null.
      const providerProgress = count === undefined ? calculateAniListChapterProgress(progress, chapterIds) : count
      if (providerProgress === null || !Number.isSafeInteger(providerProgress) || providerProgress < 0) {
        return this.skipped('chapter_progress_unknown')
      }
      const account = this.findConnectedAccount(preferences, mapping.providerId)
      if (account === undefined || account.credentialAccountKey === undefined) {
        return this.failedWithPendingQueue('account_missing', mapping, progress, chapterIds, providerProgress, now, origin)
      }
      if (!this.hasClientForProvider(mapping.providerId)) {
        return this.failedWithPendingQueue('client_unavailable', mapping, progress, chapterIds, providerProgress, now, origin)
      }
      const accessToken = await this.readAccessToken(account, mapping.providerId)
      if (accessToken === undefined) {
        return this.failedWithPendingQueue('credential_missing', mapping, progress, chapterIds, providerProgress, now, origin)
      }
      if (origin !== 'manual') {
        const remote = await this.fetchProviderProgress(account, accessToken, mapping.providerTitleId)
        if (!remote.ok) {
          return this.failedWithPendingQueue('provider_failed', mapping, progress, chapterIds, providerProgress, now, origin)
        }
        // Revisiting an older chapter must not lower an existing online count.
        if (remote.value !== undefined && remote.value.progress >= providerProgress) {
          await this.pendingStore.removeProgressThrough(mapping.providerId, progress.comicId, remote.value.progress)
          return this.progressResult(mapping, remote.value)
        }
      }
      const result = await this.pushProviderProgress(account, accessToken, mapping.providerTitleId, providerProgress)
      if (!result.ok || result.value === undefined) {
        return this.failedWithPendingQueue('provider_failed', mapping, progress, chapterIds, providerProgress, now, origin)
      }
      await this.markAccountSynced(preferences, account, now)
      await this.pendingStore.removeProgressThrough(mapping.providerId, progress.comicId, providerProgress)
      return this.progressResult(mapping, result.value)
  }

  async pullReadingProgress(comicId: string, now: number = Date.now(), preferredProviderId?: TrackerProviderId): Promise<TrackerProgressSyncResult> {
    return BackupRestoreActivity.runWrite(() => mutateTrackerProgress(this.context.filesDir, async (): Promise<TrackerProgressSyncResult> => {
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
      const result = await this.fetchProviderProgress(account, accessToken, mapping.providerTitleId)
      if (!result.ok) {
        return this.failed('provider_failed', mapping)
      }
      await this.markAccountSynced(preferences, account, now)
      return this.progressResult(mapping, result.value)
    }))
  }

  async bindComic(mapping: ComicTrackerMapping, localProgress: number = 0): Promise<TrackerProgressSyncResult> {
    return BackupRestoreActivity.runWrite(() => mutateTrackerProgress(this.context.filesDir, async () => {
      const store = this.preferencesStore()
      const preferences = await store.load()
      const account = this.findConnectedAccount(preferences, mapping.providerId)
      if (account === undefined) return this.failed('account_missing', mapping)
      const token = await this.readAccessToken(account, mapping.providerId)
      if (token === undefined) return this.failed('credential_missing', mapping)
      const remote = await this.fetchProviderProgress(account, token, mapping.providerTitleId)
      if (!remote.ok) return this.failed('provider_failed', mapping)

      // Reuse an existing remote entry without overwriting its state. A retry
      // after local persistence fails also finds the entry created previously.
      const progress = remote.value === undefined
        ? await this.pushProviderProgress(account, token, mapping.providerTitleId, Math.max(0, localProgress), false)
        : remote
      if (!progress.ok || progress.value === undefined) return this.failed('provider_failed', mapping)
      const currentAccount = this.findConnectedAccount(await store.load(), mapping.providerId)
      if (currentAccount?.credentialAccountKey !== account.credentialAccountKey) return this.failed('account_missing', mapping)
      const previous = this.findConfirmedMapping(preferences, mapping.comicId, mapping.providerId)
      if (previous !== undefined && previous.providerTitleId !== mapping.providerTitleId) {
        await this.pendingStore.removeProgressForComic(mapping.providerId, mapping.comicId)
      }
      await store.upsertComicMapping(mapping)
      return this.progressResult(mapping, progress.value)
    }))
  }

  async editComicProgress(comicId: string, providerId: TrackerProviderId,
    progress: number | undefined, completed?: boolean | string, fields?: TrackerEntryFields): Promise<TrackerProgressSyncResult> {
    return BackupRestoreActivity.runWrite(() => mutateTrackerProgress(this.context.filesDir, async () => {
      const preferences = await this.preferencesStore().load()
      const mapping = this.findConfirmedMapping(preferences, comicId, providerId)
      if (mapping === undefined) return this.skipped('mapping_missing')
      if (progress !== undefined && (!Number.isSafeInteger(progress) || progress < 0)) return this.skipped('chapter_progress_unknown')
      const account = this.findConnectedAccount(preferences, providerId)
      if (account === undefined) return this.failed('account_missing', mapping)
      const token = await this.readAccessToken(account, providerId)
      if (token === undefined) return this.failed('credential_missing', mapping)
      const result = await this.pushProviderProgress(account, token, mapping.providerTitleId, progress, completed, fields)
      if (!result.ok || result.value === undefined) return this.failed('provider_failed', mapping)
      if (progress !== undefined) await this.pendingStore.removeProgressForComic(providerId, comicId)
      return this.progressResult(mapping, result.value)
    }))
  }

  async unbindComic(comicId: string, providerId: TrackerProviderId): Promise<TrackerPreferences> {
    return BackupRestoreActivity.runWrite(() => mutateTrackerProgress(this.context.filesDir, async () => {
      await this.pendingStore.removeProgressForComic(providerId, comicId)
      return this.preferencesStore().removeComicMapping(comicId, providerId)
    }))
  }

  async retryPendingProgress(
    limit: number = 20,
    now: number = Date.now(),
    allowWhenAutoSyncDisabled: boolean = false,
  ): Promise<TrackerPendingProgressDrainSummary> {
    return BackupRestoreActivity.runWrite(() => mutateTrackerProgress(this.context.filesDir, async (): Promise<TrackerPendingProgressDrainSummary> => {
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
      if (!allowWhenAutoSyncDisabled && !preferences.autoSyncEnabled) {
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
        const result = await this.pushReadingProgressNow(progress, entry.chapterIds, 'manual', now, entry.providerId,
          entry.providerProgress, entry.trigger ?? 'manual')
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
    }))
  }

  private preferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context, this.secretStore)
  }

  private isSupportedProgressProvider(providerId: TrackerProviderId): boolean {
    return TRACKER_REMOTE_PROVIDER_IDS.includes(providerId)
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
    if (providerId === 'bangumi') return readBangumiAccessToken(this.context, this.secretStore, account)
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
    if (providerId === 'kitsu') return this.kitsuClient !== undefined
    if (providerId === 'bangumi') return this.bangumiClient !== undefined
    if (providerId === 'mangaupdates') return this.mangaUpdatesClient !== undefined
    if (providerId === 'anilist') {
      return this.aniListClient !== undefined
    }
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient !== undefined
    }
    return false
  }

  private async pushProviderProgress(
    account: TrackerAccount,
    accessToken: string,
    providerTitleId: string,
    providerProgress: number | undefined,
    completed?: boolean | string,
    fields?: TrackerEntryFields,
  ): Promise<TrackerProviderProgressResult> {
    const providerId = account.providerId
    if (providerId === 'kitsu') return this.kitsuClient === undefined || providerProgress === undefined ? { ok: false } : this.kitsuClient.pushProgress(accessToken, providerTitleId, providerProgress)
    if (providerId === 'bangumi') return this.bangumiClient === undefined ? { ok: false } : this.bangumiClient.pushProgress(accessToken, providerTitleId, providerProgress, account.profile?.username,
      typeof completed === 'string' ? Number(completed) : undefined, fields)
    if (providerId === 'mangaupdates') return this.mangaUpdatesClient === undefined || providerProgress === undefined ? { ok: false } : this.mangaUpdatesClient.pushProgress(accessToken, providerTitleId, providerProgress)
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient === undefined
        ? { ok: false }
        : this.myAnimeListClient.pushProgress(accessToken, providerTitleId, providerProgress, completed, fields)
    }
    return this.aniListClient === undefined
      ? { ok: false }
      : this.aniListClient.pushProgress(accessToken, providerTitleId, providerProgress, completed, fields)
  }

  private async fetchProviderProgress(
    account: TrackerAccount,
    accessToken: string,
    providerTitleId: string,
  ): Promise<TrackerProviderProgressResult> {
    const providerId = account.providerId
    if (providerId === 'kitsu') return this.kitsuClient === undefined ? { ok: false } : this.kitsuClient.fetchProgress(accessToken, providerTitleId)
    if (providerId === 'bangumi') return this.bangumiClient === undefined ? { ok: false } : this.bangumiClient.fetchProgress(accessToken, providerTitleId, account.profile?.username)
    if (providerId === 'mangaupdates') return this.mangaUpdatesClient === undefined ? { ok: false } : this.mangaUpdatesClient.fetchProgress(accessToken, providerTitleId)
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient === undefined
        ? { ok: false }
        : this.myAnimeListClient.fetchProgress(accessToken, providerTitleId)
    }
    return this.aniListClient === undefined
      ? { ok: false }
      : this.aniListClient.fetchProgress(accessToken, providerTitleId)
  }

  private async markAccountSynced(_preferences: TrackerPreferences, account: TrackerAccount, now: number): Promise<void> {
    if (account.credentialAccountKey !== undefined) {
      await this.preferencesStore().markAccountSynced(account.providerId, account.credentialAccountKey, now)
    }
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
      providerStatus: progress.status,
      completed: progress.completed,
      volumes: progress.volumes, score: progress.score, startedAt: progress.startedAt, completedAt: progress.completedAt,
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
    trigger: TrackerUpdateStrategy,
  ): Promise<TrackerProgressSyncResult> {
    const result = this.failed(reason, mapping)
    await this.pendingStore.enqueueFailedProgress(mapping.providerId, progress, chapterIds, providerProgress, reason, now, trigger)
    result.queued = true
    return result
  }
}
