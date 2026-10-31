import { common } from '@kit.AbilityKit'
import { KitsuTrackerClient } from './KitsuTrackerClient'
import { util } from '@kit.ArkTS'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { BangumiTrackerClient, MangaUpdatesTrackerClient, RemoteTrackerLogin, RemoteTrackerResult } from './AdditionalTrackerClients'
import { AssetStoreTrackerCredentialSecretStore, TrackerAccount, TrackerCredentialSecretStore,
  TrackerPreferences, TrackerPreferencesStore } from './TrackerModels'

export type DirectTrackerProviderId = 'bangumi' | 'mangaupdates' | 'kitsu'
export interface TrackerDirectConnectionResult {
  ok: boolean
  reason?: 'secure_storage_unavailable' | 'login_failed' | 'account_changed' | 'credential_store_failed'
  preferences?: TrackerPreferences
}
export interface TrackerDirectConnectionOptions {
  secretStore?: TrackerCredentialSecretStore
  bangumiClient?: BangumiTrackerClient
  mangaUpdatesClient?: MangaUpdatesTrackerClient
  kitsuClient?: KitsuTrackerClient
}

/** Network authentication is outside the store transaction. Only a verified session is committed. */
export class TrackerDirectConnectionService {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore
  private bangumi: BangumiTrackerClient
  private mangaUpdates: MangaUpdatesTrackerClient
  private kitsu: KitsuTrackerClient

  constructor(context: common.UIAbilityContext, options: TrackerDirectConnectionOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.bangumi = options.bangumiClient ?? new BangumiTrackerClient()
    this.mangaUpdates = options.mangaUpdatesClient ?? new MangaUpdatesTrackerClient()
    this.kitsu = options.kitsuClient ?? new KitsuTrackerClient()
  }

  async connect(providerId: DirectTrackerProviderId, username: string, secret: string,
    now: number = Date.now()): Promise<TrackerDirectConnectionResult> {
    if (!this.secretStore.isAvailable()) return { ok: false, reason: 'secure_storage_unavailable' }
    return BackupRestoreActivity.runWrite(async (): Promise<TrackerDirectConnectionResult> => {
      const store = new TrackerPreferencesStore(this.context, this.secretStore)
      const before = (await store.load()).accounts.find((account: TrackerAccount): boolean => account.providerId === providerId)
      if (before === undefined) return { ok: false, reason: 'account_changed' }
      const result = await this.authenticate(providerId, username, secret)
      if (!result.ok || result.value === undefined) return { ok: false, reason: 'login_failed' }
      const key = util.generateRandomUUID()
      const next: TrackerAccount = { providerId, status: 'connected', credentialAccountKey: key,
        profile: { username: result.value.profile.username, displayName: result.value.profile.displayName,
          providerUserId: result.value.profile.providerUserId }, connectedAt: now, lastSyncAt: now }
      let credentialWritten = false
      let connected: TrackerPreferences | null = null
      try {
        const session = result.value
        const commit = await store.saveAccountIfCurrent(before, next, async (): Promise<void> => {
          const saved = await this.secretStore.writeToken({ providerId, accountKey: key, secretKind: 'access_token',
            secretBytes: new util.TextEncoder().encodeInto(session.token) })
          if (!saved.ok) throw new Error('tracker_credential_store_failed')
          credentialWritten = true
        })
        if (!commit.applied) return { ok: false, reason: 'account_changed', preferences: commit.preferences }
        connected = commit.preferences
      } catch (_) {
        // A rejected preference commit leaves the previous account/token usable.
        if (credentialWritten) await this.secretStore.deleteAccount({ providerId, accountKey: key })
        return { ok: false, reason: 'credential_store_failed' }
      }
      // Cleanup follows the committed transaction; cleanup failure cannot retire the new session.
      if (before.credentialAccountKey !== undefined) {
        try { await this.secretStore.deleteAccount({ providerId, accountKey: before.credentialAccountKey }) }
        catch (_) { console.warn('[TrackerConnect] previous credential cleanup failed') }
      }
      return { ok: true, preferences: connected ?? undefined }
    })
  }

  private async authenticate(providerId: DirectTrackerProviderId, username: string,
    secret: string): Promise<RemoteTrackerResult<RemoteTrackerLogin>> {
    if (providerId === 'mangaupdates') return this.mangaUpdates.login(username, secret)
    if (providerId === 'kitsu') return this.kitsu.login(username, secret)
    const token = secret.trim()
    const profile = await this.bangumi.fetchProfile(token)
    return profile.ok && profile.value !== undefined ? { ok: true, value: { token, profile: profile.value } } :
      { ok: false, errorCode: profile.errorCode }
  }
}
