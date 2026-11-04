import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { HarmonyTrackerJsonAdapter, TrackerJsonClient } from './AdditionalTrackerClients'
import {
  TrackerAccount, TrackerCredentialSecretStore, TrackerPreferencesStore,
  decodeTrackerSecretBytes, getConfiguredTrackerProviderConfig,
} from './TrackerModels'

interface BangumiOAuthTokens {
  accessToken: string
  refreshToken: string
  expiresAt: number
}

interface BangumiRefreshResponse {
  access_token?: string
  refresh_token?: string
  expires_in?: number
}

class BangumiOAuthRefreshClient extends TrackerJsonClient {
  constructor() { super(new HarmonyTrackerJsonAdapter(), 'https://bgm.tv') }

  async renew(clientId: string, clientSecret: string, redirectUri: string,
    refreshToken: string): Promise<BangumiOAuthTokens | undefined> {
    const result = await this.sendForm<BangumiRefreshResponse>('/oauth/access_token', {
      'grant_type': 'refresh_token', 'client_id': clientId, 'client_secret': clientSecret,
      'redirect_uri': redirectUri, 'refresh_token': refreshToken,
    })
    const value = result.value
    if (!result.ok || value === undefined || !value.access_token || !value.refresh_token ||
      !Number.isFinite(value.expires_in) || value.expires_in! <= 0) return undefined
    return { accessToken: value.access_token, refreshToken: value.refresh_token,
      expiresAt: Date.now() + value.expires_in! * 1000 }
  }
}

const renewals: Map<string, Promise<string | undefined>> = new Map()

export async function readBangumiAccessToken(context: common.UIAbilityContext, secretStore: TrackerCredentialSecretStore,
  account: TrackerAccount): Promise<string | undefined> {
  const key = account.credentialAccountKey
  if (key === undefined) return undefined
  const data = await secretStore.readToken({ providerId: 'bangumi', accountKey: key, secretKind: 'bangumi_oauth' })
  if (data === undefined) {
    // Accounts linked before OAuth hold a personal access token and do not renew.
    const personalToken = await secretStore.readToken({ providerId: 'bangumi', accountKey: key, secretKind: 'access_token' })
    return personalToken === undefined ? undefined : decodeTrackerSecretBytes(personalToken).trim() || undefined
  }
  let tokens: BangumiOAuthTokens
  try { tokens = JSON.parse(decodeTrackerSecretBytes(data)) as BangumiOAuthTokens }
  catch (_) { return undefined }
  if (tokens === null || !tokens.accessToken || !tokens.refreshToken || !Number.isFinite(tokens.expiresAt)) return undefined
  if (tokens.expiresAt > Date.now() + 30000) return tokens.accessToken

  const renewalKey = context.filesDir + ':' + key
  const existing = renewals.get(renewalKey)
  if (existing !== undefined) return existing
  const operation = renewBangumiAccessToken(context, secretStore, key, tokens.refreshToken)
  renewals.set(renewalKey, operation)
  try { return await operation }
  catch (_) { return undefined }
  finally { renewals.delete(renewalKey) }
}

async function renewBangumiAccessToken(context: common.UIAbilityContext, secretStore: TrackerCredentialSecretStore,
  accountKey: string, refreshToken: string): Promise<string | undefined> {
  const store = new TrackerPreferencesStore(context, secretStore)
  const preferences = await store.load()
  const provider = getConfiguredTrackerProviderConfig('bangumi', preferences.providerOAuthConfigs)
  if (provider?.clientId === undefined || provider.clientSecret === undefined || provider.redirectUri === undefined) return undefined
  const tokens = await new BangumiOAuthRefreshClient().renew(provider.clientId, provider.clientSecret,
    provider.redirectUri, refreshToken)
  if (tokens === undefined) return undefined
  const replaced = await store.replaceLinkedCredential('bangumi', accountKey, async (): Promise<void> => {
    await saveBangumiOAuthTokens(secretStore, accountKey, tokens.accessToken, tokens.refreshToken, tokens.expiresAt)
  })
  return replaced ? tokens.accessToken : undefined
}

export async function saveBangumiOAuthTokens(secretStore: TrackerCredentialSecretStore, accountKey: string,
  accessToken: string, refreshToken: string, expiresAt: number): Promise<void> {
  const tokens: BangumiOAuthTokens = { accessToken, refreshToken, expiresAt }
  const result = await secretStore.writeToken({ providerId: 'bangumi', accountKey, secretKind: 'bangumi_oauth',
    secretBytes: new util.TextEncoder().encodeInto(JSON.stringify(tokens)) })
  if (!result.ok) throw new Error('credential_store_failed')
}
