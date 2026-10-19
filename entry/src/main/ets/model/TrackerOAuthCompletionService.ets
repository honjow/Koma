import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import {
  AssetStoreTrackerCredentialSecretStore,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferences,
  TrackerPreferencesStore,
  TrackerProviderConfig,
  TrackerProviderId,
  decodeTrackerSecretBytes,
  getConfiguredTrackerProviderConfig,
  parseTrackerOAuthCallback,
} from './TrackerModels'
import { TrackerAccountRefreshService } from './TrackerAccountRefreshService'

export type TrackerOAuthCompletionStatus = 'connected' | 'failed'
export type TrackerOAuthCompletionReason =
  'account_missing' |
  'account_changed' |
  'provider_config_missing' |
  'invalid_callback' |
  'state_mismatch' |
  'provider_error' |
  'missing_code' |
  'verifier_missing' |
  'token_exchange_failed' |
  'credential_store_failed' |
  'profile_refresh_failed'

export interface TrackerOAuthCompletionResult {
  providerId: TrackerProviderId
  status: TrackerOAuthCompletionStatus
  reason?: TrackerOAuthCompletionReason
  preferences: TrackerPreferences
}

export interface TrackerOAuthTokenExchangeResult {
  ok: boolean
  accessToken?: string
  refreshToken?: string
}

export interface TrackerOAuthTokenExchanger {
  exchange(
    provider: TrackerProviderConfig,
    code: string,
    codeVerifier: string,
  ): Promise<TrackerOAuthTokenExchangeResult>
}

export interface TrackerOAuthCompletionServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  tokenExchanger?: TrackerOAuthTokenExchanger
}

interface TrackerOAuthCallbackFields {
  state?: string
  code?: string
  accessToken?: string
}

interface TrackerTokenResponsePayload {
  access_token?: string
  refresh_token?: string
}

function utf8Bytes(value: string): Uint8Array {
  return new Uint8Array(buffer.from(value, 'utf-8').buffer)
}

function appendFormField(pairs: string[], key: string, value: string): void {
  pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
}

function formEncodeTokenRequest(provider: TrackerProviderConfig, code: string, codeVerifier: string): string {
  const pairs: string[] = []
  appendFormField(pairs, 'grant_type', 'authorization_code')
  appendFormField(pairs, 'client_id', provider.clientId ?? '')
  appendFormField(pairs, 'redirect_uri', provider.redirectUri ?? '')
  appendFormField(pairs, 'code', code)
  appendFormField(pairs, 'code_verifier', codeVerifier)
  return pairs.join('&')
}

function parseCallbackFields(callbackUri: string, implicitGrant: boolean = false): TrackerOAuthCallbackFields {
  const queryStart = callbackUri.indexOf('?')
  const fragmentStart = callbackUri.indexOf('#')
  const start = implicitGrant ? fragmentStart + 1 : queryStart >= 0 ? queryStart + 1 : fragmentStart >= 0 ? fragmentStart + 1 : 0
  const payload = callbackUri.substring(start)
  const fields: TrackerOAuthCallbackFields = {}
  payload.split('&').forEach((pair: string) => {
    const separator = pair.indexOf('=')
    if (separator < 0) {
      return
    }
    const key = decodeURIComponent(pair.substring(0, separator).replace(/\+/g, ' '))
    const value = decodeURIComponent(pair.substring(separator + 1).replace(/\+/g, ' '))
    if (key === 'state') {
      fields.state = value
    } else if (key === 'code') {
      fields.code = value
    } else if (key === 'access_token') {
      fields.accessToken = value.trim()
    }
  })
  return fields
}

function tokenEndpoint(providerId: TrackerProviderId): string | undefined {
  if (providerId === 'anilist') {
    return 'https://anilist.co/api/v2/oauth/token'
  }
  if (providerId === 'myanimelist') {
    return 'https://myanimelist.net/v1/oauth2/token'
  }
  return undefined
}

export class HarmonyTrackerOAuthTokenExchanger implements TrackerOAuthTokenExchanger {
  async exchange(
    provider: TrackerProviderConfig,
    code: string,
    codeVerifier: string,
  ): Promise<TrackerOAuthTokenExchangeResult> {
    const endpoint = tokenEndpoint(provider.providerId)
    if (endpoint === undefined || provider.clientId === undefined || provider.redirectUri === undefined) {
      return { ok: false }
    }
    const request = http.createHttp()
    try {
      const response = await request.request(endpoint, {
        method: http.RequestMethod.POST,
        extraData: formEncodeTokenRequest(provider, code, codeVerifier),
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        header: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        readTimeout: 30000,
        connectTimeout: 15000,
      })
      if (response.responseCode < 200 || response.responseCode >= 300 || typeof response.result !== 'string') {
        return { ok: false }
      }
      const payload = JSON.parse(response.result) as TrackerTokenResponsePayload
      const accessToken = payload.access_token?.trim()
      if (accessToken === undefined || accessToken.length === 0) {
        return { ok: false }
      }
      const result: TrackerOAuthTokenExchangeResult = {
        ok: true,
        accessToken,
      }
      const refreshToken = payload.refresh_token?.trim()
      if (refreshToken !== undefined && refreshToken.length > 0) {
        result.refreshToken = refreshToken
      }
      return result
    } catch (_error) {
      return { ok: false }
    } finally {
      request.destroy()
    }
  }
}

export class TrackerOAuthCompletionService {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore
  private tokenExchanger: TrackerOAuthTokenExchanger

  constructor(context: common.UIAbilityContext, options: TrackerOAuthCompletionServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.tokenExchanger = options.tokenExchanger ?? new HarmonyTrackerOAuthTokenExchanger()
  }

  async completeCallback(providerId: TrackerProviderId, callbackUri: string, now: number = Date.now()): Promise<TrackerOAuthCompletionResult> {
    return BackupRestoreActivity.runWrite(async (): Promise<TrackerOAuthCompletionResult> => {
      const store = new TrackerPreferencesStore(this.context, this.secretStore)
      const preferences = await store.load()
      const account = preferences.accounts.find((item: TrackerAccount): boolean => {
        return item.providerId === providerId && item.status === 'auth_pending' && item.credentialAccountKey !== undefined
      })
      if (account === undefined || account.credentialAccountKey === undefined) {
        return this.failed(providerId, 'account_missing', preferences)
      }

      const implicitGrant = providerId === 'anilist'
      const callback = parseTrackerOAuthCallback(callbackUri, account.credentialAccountKey, implicitGrant)
      if (!callback.ok) {
        return this.failed(providerId, callback.reason ?? 'invalid_callback', await this.saveError(store, providerId, account, callback.reason ?? 'invalid_callback'))
      }

      let fields: TrackerOAuthCallbackFields
      try {
        fields = parseCallbackFields(callbackUri, implicitGrant)
      } catch (_error) {
        return this.failed(providerId, 'invalid_callback', await this.saveError(store, providerId, account, 'invalid_callback'))
      }
      if (!implicitGrant && (fields.code === undefined || fields.code.length === 0)) {
        return this.failed(providerId, 'missing_code', await this.saveError(store, providerId, account, 'missing_code'))
      }

      const configuredProvider = getConfiguredTrackerProviderConfig(providerId, preferences.providerOAuthConfigs)
      if (configuredProvider === undefined) {
        return this.failed(providerId, 'provider_config_missing', await this.saveError(store, providerId, account, 'provider_config_missing'))
      }

      let tokenResult: TrackerOAuthTokenExchangeResult
      if (implicitGrant) {
        if (callbackUri.substring(0, callbackUri.indexOf('#')) !== configuredProvider.redirectUri) {
          return this.failed(providerId, 'invalid_callback', await this.saveError(store, providerId, account, 'invalid_callback'))
        }
        tokenResult = { ok: true, accessToken: fields.accessToken }
      } else {
        const verifierBytes = await this.secretStore.readToken({
          providerId,
          accountKey: account.credentialAccountKey,
          secretKind: 'oauth_code_verifier',
        })
        const verifier = verifierBytes === undefined ? undefined : decodeTrackerSecretBytes(verifierBytes).trim()
        if (verifier === undefined || verifier.length === 0) {
          return this.failed(providerId, 'verifier_missing', await this.saveError(store, providerId, account, 'verifier_missing'))
        }

        tokenResult = await this.tokenExchanger.exchange(configuredProvider, fields.code ?? '', verifier)
      }
      if (!tokenResult.ok || tokenResult.accessToken === undefined) {
        return this.failed(providerId, 'token_exchange_failed', await this.saveError(store, providerId, account, 'token_exchange_failed'))
      }

      try {
        const commit = await store.saveAccountIfCurrent(account, {
          providerId,
          status: 'connected',
          credentialAccountKey: account.credentialAccountKey,
          connectedAt: now,
        }, async (): Promise<void> => {
          const accessTokenSaved = await this.secretStore.writeToken({
            providerId,
            accountKey: account.credentialAccountKey!,
            secretKind: 'access_token',
            secretBytes: utf8Bytes(tokenResult.accessToken!),
          })
          if (!accessTokenSaved.ok) throw new Error('credential_store_failed')
          if (tokenResult.refreshToken !== undefined) {
            const refreshTokenSaved = await this.secretStore.writeToken({
              providerId,
              accountKey: account.credentialAccountKey!,
              secretKind: 'refresh_token',
              secretBytes: utf8Bytes(tokenResult.refreshToken),
            })
            if (!refreshTokenSaved.ok) throw new Error('credential_store_failed')
          }
          if (!implicitGrant) {
            await this.secretStore.deleteToken({
              providerId,
              accountKey: account.credentialAccountKey!,
              secretKind: 'oauth_code_verifier',
            })
          }
        })
        if (!commit.applied) return this.failed(providerId, 'account_changed', commit.preferences)
      } catch (_error) {
        return this.failed(providerId, 'credential_store_failed', await this.saveError(store, providerId, account, 'credential_store_failed'))
      }

      const refresh = await new TrackerAccountRefreshService(this.context, { secretStore: this.secretStore }).refreshAccounts(providerId, now)
      if (refresh.refreshedCount <= 0) {
        return this.failed(providerId, 'profile_refresh_failed', refresh.preferences)
      }
      return {
        providerId,
        status: 'connected',
        preferences: refresh.preferences,
      }
    })
  }

  private async saveError(
    store: TrackerPreferencesStore,
    providerId: TrackerProviderId,
    account: TrackerAccount,
    reason: TrackerOAuthCompletionReason,
  ): Promise<TrackerPreferences> {
    const result = await store.saveAccountIfCurrent(account, {
      providerId,
      status: 'error',
      credentialAccountKey: account.credentialAccountKey,
      statusReason: reason,
    })
    return result.preferences
  }

  private failed(
    providerId: TrackerProviderId,
    reason: TrackerOAuthCompletionReason,
    preferences: TrackerPreferences,
  ): TrackerOAuthCompletionResult {
    return {
      providerId,
      status: 'failed',
      reason,
      preferences,
    }
  }
}
