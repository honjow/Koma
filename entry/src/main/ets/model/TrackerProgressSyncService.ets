import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { ReadingProgress } from './ComicModels'
import {
  AniListTrackerClient,
  AniListTrackerProgress,
} from './AniListTrackerClient'
import {
  AssetStoreTrackerCredentialSecretStore,
  ComicTrackerMapping,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferences,
  TrackerPreferencesStore,
} from './TrackerModels'

export type TrackerProgressSyncStatus = 'synced' | 'skipped' | 'failed'
export type TrackerProgressSyncReason =
  'auto_sync_disabled' |
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
}

export interface TrackerProgressSyncServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  aniListClient?: AniListTrackerClient
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

  constructor(context: common.UIAbilityContext, options: TrackerProgressSyncServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.aniListClient = options.aniListClient
  }

  async pushReadingProgress(progress: ReadingProgress, chapterIds: string[], now: number = Date.now()): Promise<TrackerProgressSyncResult> {
    const preferences = await this.preferencesStore().load()
    if (!preferences.autoSyncEnabled) {
      return this.skipped('auto_sync_disabled')
    }
    const mapping = this.findConfirmedAniListMapping(preferences, progress.comicId)
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
    const providerProgress = calculateAniListChapterProgress(progress, chapterIds)
    const result = await this.aniListClient.pushProgress(accessToken, mapping.providerTitleId, providerProgress, progress.completed)
    if (!result.ok || result.value === undefined) {
      return this.failed('provider_failed', mapping)
    }
    await this.markAniListAccountSynced(preferences, account, now)
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
}
