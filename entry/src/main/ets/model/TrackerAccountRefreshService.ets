import { TRACKER_REMOTE_PROVIDER_IDS } from './TrackerModels'
import { KitsuTrackerClient } from './KitsuTrackerClient'
import { BangumiTrackerClient, MangaUpdatesTrackerClient, RemoteTrackerProfile } from './AdditionalTrackerClients'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import {
  AniListTrackerClient,
  AniListTrackerProfile,
  HarmonyAniListTrackerHttpAdapter,
} from './AniListTrackerClient'
import {
  HarmonyMyAnimeListTrackerHttpAdapter,
  MyAnimeListTrackerClient,
  MyAnimeListTrackerProfile,
} from './MyAnimeListTrackerClient'
import {
  AssetStoreTrackerCredentialSecretStore,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferences,
  TrackerPreferencesStore,
  TrackerProviderId,
  decodeTrackerSecretBytes,
} from './TrackerModels'

export type TrackerAccountRefreshStatus = 'refreshed' | 'skipped' | 'failed'
export type TrackerAccountRefreshReason =
  'account_missing' |
  'account_changed' |
  'credential_missing' |
  'client_unavailable' |
  'provider_failed'

export interface TrackerAccountRefreshResult {
  providerId: TrackerProviderId
  status: TrackerAccountRefreshStatus
  reason?: TrackerAccountRefreshReason
}

export interface TrackerAccountRefreshSummary {
  scannedCount: number
  refreshedCount: number
  skippedCount: number
  failedCount: number
  results: TrackerAccountRefreshResult[]
  preferences: TrackerPreferences
}

export interface TrackerAccountRefreshServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  aniListClient?: AniListTrackerClient
  myAnimeListClient?: MyAnimeListTrackerClient
  bangumiClient?: BangumiTrackerClient
  mangaUpdatesClient?: MangaUpdatesTrackerClient
  kitsuClient?: KitsuTrackerClient
}

interface TrackerProfileFetchResult {
  ok: boolean
  expired: boolean
  profile?: AniListTrackerProfile | MyAnimeListTrackerProfile | RemoteTrackerProfile
}

interface TrackerAccountRefreshProviderOutcome {
  result: TrackerAccountRefreshResult
  account: TrackerAccount
}

export class TrackerAccountRefreshService {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore
  private aniListClient?: AniListTrackerClient
  private myAnimeListClient?: MyAnimeListTrackerClient
  private bangumiClient?: BangumiTrackerClient
  private mangaUpdatesClient?: MangaUpdatesTrackerClient
  private kitsuClient?: KitsuTrackerClient

  constructor(context: common.UIAbilityContext, options: TrackerAccountRefreshServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.aniListClient = options.aniListClient ?? new AniListTrackerClient(new HarmonyAniListTrackerHttpAdapter())
    this.myAnimeListClient = options.myAnimeListClient ?? new MyAnimeListTrackerClient(new HarmonyMyAnimeListTrackerHttpAdapter())
    this.bangumiClient = options.bangumiClient ?? new BangumiTrackerClient()
    this.mangaUpdatesClient = options.mangaUpdatesClient ?? new MangaUpdatesTrackerClient()
    this.kitsuClient = options.kitsuClient ?? new KitsuTrackerClient()
  }

  async refreshAccounts(preferredProviderId?: TrackerProviderId, now: number = Date.now()): Promise<TrackerAccountRefreshSummary> {
    return BackupRestoreActivity.runWrite(async (): Promise<TrackerAccountRefreshSummary> => {
      const store = this.preferencesStore()
      const preferences = await store.load()
      const providerIds = this.refreshableProviderIds(preferences.accounts, preferredProviderId)
      const summary: TrackerAccountRefreshSummary = {
        scannedCount: providerIds.length,
        refreshedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        results: [],
        preferences,
      }
      if (providerIds.length === 0) {
        summary.skippedCount = preferredProviderId === undefined ? 0 : 1
        if (preferredProviderId !== undefined) {
          summary.results.push(this.skipped(preferredProviderId, 'account_missing'))
        }
        return summary
      }

      for (let index = 0; index < providerIds.length; index += 1) {
        const providerId = providerIds[index]
        const account = preferences.accounts.find((item: TrackerAccount): boolean => item.providerId === providerId)
        if (account === undefined) continue
        const result = await this.refreshAccount(account, providerId, now)
        const commit = await store.saveAccountIfCurrent(account, result.account)
        summary.preferences = commit.preferences
        if (!commit.applied) {
          summary.results.push(this.skipped(providerId, 'account_changed'))
          summary.skippedCount += 1
          continue
        }
        summary.results.push(result.result)
        if (result.result.status === 'refreshed') {
          summary.refreshedCount += 1
        } else if (result.result.status === 'failed') {
          summary.failedCount += 1
        } else {
          summary.skippedCount += 1
        }
      }
      return summary
    })
  }

  private async refreshAccount(
    account: TrackerAccount | undefined,
    providerId: TrackerProviderId,
    now: number,
  ): Promise<TrackerAccountRefreshProviderOutcome> {
    if (account === undefined || account.credentialAccountKey === undefined) {
      const disconnectedAccount: TrackerAccount = account ?? { providerId, status: 'disconnected' }
      return {
        result: this.skipped(providerId, 'credential_missing'),
        account: disconnectedAccount,
      }
    }
    if (!this.hasClient(providerId)) {
      const failedAccount: TrackerAccount = {
        providerId,
        status: 'error',
        credentialAccountKey: account.credentialAccountKey,
        statusReason: 'client_unavailable',
      }
      return {
        result: this.failed(providerId, 'client_unavailable'),
        account: failedAccount,
      }
    }
    const accessToken = await this.readAccessToken(account, providerId)
    if (accessToken === undefined) {
      const failedAccount: TrackerAccount = {
        providerId,
        status: 'error',
        credentialAccountKey: account.credentialAccountKey,
        statusReason: 'credential_missing',
      }
      return {
        result: this.failed(providerId, 'credential_missing'),
        account: failedAccount,
      }
    }
    const profileResult = await this.fetchProfile(providerId, accessToken)
    if (profileResult.ok && profileResult.profile !== undefined) {
      const refreshedResult: TrackerAccountRefreshResult = { providerId, status: 'refreshed' }
      const refreshedAccount: TrackerAccount = {
        providerId,
        status: 'connected',
        credentialAccountKey: account.credentialAccountKey,
        profile: {
          username: profileResult.profile.username,
          displayName: profileResult.profile.displayName,
          providerUserId: providerId === 'mangaupdates'
            ? account.profile?.providerUserId ?? profileResult.profile.providerUserId : profileResult.profile.providerUserId,
        },
        connectedAt: account.connectedAt ?? now,
        lastSyncAt: now,
      }
      return {
        result: refreshedResult,
        account: refreshedAccount,
      }
    }
    const failedAccount: TrackerAccount = {
      providerId,
      status: profileResult.expired ? 'expired' : 'error',
      credentialAccountKey: account.credentialAccountKey,
      profile: account.profile,
      connectedAt: account.connectedAt,
      lastSyncAt: account.lastSyncAt,
      statusReason: profileResult.expired ? 'unauthorized' : 'provider_failed',
    }
    return {
      result: this.failed(providerId, 'provider_failed'),
      account: failedAccount,
    }
  }

  private preferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context, this.secretStore)
  }

  private refreshableProviderIds(accounts: TrackerAccount[], preferredProviderId?: TrackerProviderId): TrackerProviderId[] {
    const ids: TrackerProviderId[] = []
    accounts.forEach((account: TrackerAccount) => {
      if (!this.isSupportedProvider(account.providerId)) {
        return
      }
      if (preferredProviderId !== undefined && account.providerId !== preferredProviderId) {
        return
      }
      if (account.credentialAccountKey === undefined) {
        return
      }
      ids.push(account.providerId)
    })
    return ids
  }

  private isSupportedProvider(providerId: TrackerProviderId): boolean {
    return TRACKER_REMOTE_PROVIDER_IDS.includes(providerId)
  }

  private hasClient(providerId: TrackerProviderId): boolean {
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

  private async fetchProfile(providerId: TrackerProviderId, accessToken: string): Promise<TrackerProfileFetchResult> {
    if (providerId === 'kitsu') {
      if (this.kitsuClient === undefined) return { ok: false, expired: false }
      const result = await this.kitsuClient.fetchProfile(accessToken)
      return { ok: result.ok && result.value !== undefined, profile: result.value,
        expired: result.errorCode === 'unauthorized' || result.errorCode === 'auth_required' }
    }
    if (providerId === 'bangumi' || providerId === 'mangaupdates') {
      const client = providerId === 'bangumi' ? this.bangumiClient : this.mangaUpdatesClient
      if (client === undefined) return { ok: false, expired: false }
      const result = await client.fetchProfile(accessToken)
      return { ok: result.ok && result.value !== undefined, profile: result.value,
        expired: result.errorCode === 'unauthorized' || result.errorCode === 'auth_required' }
    }
    if (providerId === 'anilist' && this.aniListClient !== undefined) {
      const result = await this.aniListClient.fetchProfile(accessToken)
      return {
        ok: result.ok && result.value !== undefined,
        expired: result.errorCode === 'unauthorized' || result.errorCode === 'auth_required',
        profile: result.value,
      }
    }
    if (providerId === 'myanimelist' && this.myAnimeListClient !== undefined) {
      const result = await this.myAnimeListClient.fetchProfile(accessToken)
      return {
        ok: result.ok && result.value !== undefined,
        expired: result.errorCode === 'unauthorized' || result.errorCode === 'auth_required',
        profile: result.value,
      }
    }
    return { ok: false, expired: false }
  }


  private skipped(providerId: TrackerProviderId, reason: TrackerAccountRefreshReason): TrackerAccountRefreshResult {
    return {
      providerId,
      status: 'skipped',
      reason,
    }
  }

  private failed(providerId: TrackerProviderId, reason: TrackerAccountRefreshReason): TrackerAccountRefreshResult {
    return {
      providerId,
      status: 'failed',
      reason,
    }
  }
}
