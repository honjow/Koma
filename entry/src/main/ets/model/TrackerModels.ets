import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { buffer, util } from '@kit.ArkTS'
import { asset } from '@kit.AssetStoreKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { ComicId } from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'

function s(name: string): string {
  return AppStrings.get(name)
}

export type TrackerProviderId = 'anilist' | 'myanimelist' | 'kitsu' | 'mangaupdates' | 'bangumi'
/** Executable remote data clients; pending writes and consumers share this capability boundary. */
export const TRACKER_REMOTE_PROVIDER_IDS: TrackerProviderId[] = ['anilist', 'myanimelist', 'bangumi', 'mangaupdates', 'kitsu']
export type TrackerAccountStatus = 'disconnected' | 'auth_pending' | 'connected' | 'expired' | 'error'
export type TrackerProviderSupportStatus = 'available' | 'planned' | 'unsupported'
export type TrackerMappingState = 'unmapped' | 'candidate' | 'confirmed' | 'rejected' | 'stale'
export type TrackerUpdateStrategy = 'on_chapter_complete' | 'on_reader_close' | 'manual'
export type TrackerAuthPrepareStatus =
  'ready' |
  'provider_config_missing' |
  'secure_storage_unavailable' |
  'provider_unsupported' |
  'pkce_unavailable'

export type TrackerCredentialSecretKind = 'access_token' | 'refresh_token' | 'oauth_code_verifier' | 'bangumi_oauth'
export type TrackerCredentialErrorCode =
  'not_found' |
  'locked' |
  'device_security_required' |
  'access_denied' |
  'storage_unavailable' |
  'corrupted' |
  'quota_exceeded' |
  'unsupported' |
  'invalid_request' |
  'unknown'

export interface TrackerProviderConfig {
  providerId: TrackerProviderId
  displayName: string
  supportStatus: TrackerProviderSupportStatus
  authentication?: 'oauth' | 'token' | 'password'
  authorizationEndpoint?: string
  clientId?: string
  clientSecret?: string
  redirectUri?: string
  scopes: string[]
  supportsPkce: boolean
}

export interface TrackerProviderOAuthConfig {
  providerId: TrackerProviderId
  clientId?: string
  redirectUri?: string
}

export interface TrackerEntryFields {
  volumes?: number
  score?: number
  startedAt?: string
  completedAt?: string
}

export interface TrackerPublicProfile {
  username?: string
  displayName?: string
  providerUserId?: string
}

export interface TrackerAccount {
  providerId: TrackerProviderId
  status: TrackerAccountStatus
  profile?: TrackerPublicProfile
  credentialAccountKey?: string
  connectedAt?: number
  lastSyncAt?: number
  statusReason?: string
}

export interface TrackerCredentialAccountRef {
  providerId: TrackerProviderId
  accountKey: string
}

export interface TrackerCredentialSecretRef extends TrackerCredentialAccountRef {
  secretKind: TrackerCredentialSecretKind
}

export interface TrackerCredentialWriteRequest extends TrackerCredentialSecretRef {
  secretBytes: Uint8Array
  expiresAt?: number
}

export interface TrackerCredentialStoreError {
  code: TrackerCredentialErrorCode
  retryable: boolean
  operation: 'write' | 'read' | 'delete'
  providerId?: TrackerProviderId
}

export interface TrackerCredentialStoreResult {
  ok: boolean
  error?: TrackerCredentialStoreError
}

export interface TrackerCredentialSecretStore {
  isAvailable(): boolean
  writeToken(request: TrackerCredentialWriteRequest): Promise<TrackerCredentialStoreResult>
  readToken(ref: TrackerCredentialSecretRef): Promise<Uint8Array | undefined>
  deleteToken(ref: TrackerCredentialSecretRef): Promise<TrackerCredentialStoreResult>
  deleteAccount(ref: TrackerCredentialAccountRef): Promise<TrackerCredentialStoreResult>
}

export interface TrackerOAuthStartRequest {
  providerId: TrackerProviderId
  state: string
  codeChallenge: string
  providerConfig?: TrackerProviderConfig
}

export interface TrackerOAuthStartPreparation {
  status: TrackerAuthPrepareStatus
  providerId: TrackerProviderId
  authorizationUrl?: string
  state?: string
  message: string
}

export interface TrackerOAuthCallbackResult {
  ok: boolean
  state?: string
  codePresent: boolean
  errorCode?: string
  reason?: 'state_mismatch' | 'provider_error' | 'missing_code' | 'invalid_callback'
}

export interface TrackerPkcePair {
  codeVerifier: string
  codeChallenge: string
}

export interface ComicTrackerMapping {
  comicId: ComicId
  providerId: TrackerProviderId
  providerTitleId: string
  providerTitle?: string
  mappingState: TrackerMappingState
  confidence?: number
  userConfirmed: boolean
  createdAt: number
  updatedAt?: number
}

export interface TrackerComicMappingSummary {
  total: number
  confirmed: number
  candidate: number
  stale: number
  rejected: number
  unmapped: number
}

export interface TrackerPreferences {
  accounts: TrackerAccount[]
  comicMappings: ComicTrackerMapping[]
  providerOAuthConfigs: TrackerProviderOAuthConfig[]
  autoSyncEnabled: boolean
  updateStrategy: TrackerUpdateStrategy
}

export const TRACKER_PREFERENCES_STORE_NAME: string = 'koma_tracker_preferences_v1'
export const TRACKER_ACCOUNTS_KEY: string = 'tracker.accounts'
const TRACKER_RETIRED_CREDENTIALS_KEY: string = 'tracker.retiredCredentials'
export const TRACKER_COMIC_MAPPINGS_KEY: string = 'tracker.comicMappings'
export const TRACKER_PROVIDER_OAUTH_CONFIGS_KEY: string = 'tracker.providerOAuthConfigs'
export const TRACKER_AUTO_SYNC_ENABLED_KEY: string = 'tracker.autoSyncEnabled'
export const TRACKER_UPDATE_STRATEGY_KEY: string = 'tracker.updateStrategy'
export const TRACKER_ASSET_ALIAS_PREFIX: string = 'koma.tracker'
export const TRACKER_ASSET_GROUP_ID: string = 'koma_tracker_credentials'
export const TRACKER_OAUTH_STATE_BYTES: number = 32
export const TRACKER_PKCE_VERIFIER_BYTES: number = 32

// This URI is also registered on EntryAbility for browser callbacks.
export const TRACKER_APP_CALLBACK_URI: string = 'koma://tracker/callback'

export const TRACKER_PROVIDER_CONFIGS: TrackerProviderConfig[] = [
  {
    providerId: 'anilist',
    displayName: 'AniList',
    supportStatus: 'available',
    authorizationEndpoint: 'https://anilist.co/api/v2/oauth/authorize',
    clientId: '55881',
    redirectUri: TRACKER_APP_CALLBACK_URI,
    scopes: [],
    supportsPkce: false,
  },
  {
    providerId: 'myanimelist',
    displayName: 'MyAnimeList',
    supportStatus: 'available',
    authorizationEndpoint: 'https://myanimelist.net/v1/oauth2/authorize',
    clientId: 'c5738b8faba18459c20216543af2cb35',
    redirectUri: TRACKER_APP_CALLBACK_URI,
    scopes: ['list_write'],
    supportsPkce: true,
  },
  {
    providerId: 'kitsu',
    displayName: 'Kitsu',
    supportStatus: 'available',
    authentication: 'password',
    scopes: [],
    supportsPkce: false,
  },
  {
    providerId: 'mangaupdates',
    displayName: 'MangaUpdates',
    supportStatus: 'available',
    authentication: 'password',
    scopes: [],
    supportsPkce: false,
  },
  {
    providerId: 'bangumi',
    displayName: 'Bangumi',
    supportStatus: 'available',
    authentication: 'oauth',
    authorizationEndpoint: 'https://bgm.tv/oauth/authorize',
    clientId: 'bgm74706aea0ee19a0c6',
    clientSecret: '18d9a96ad7c40770ea90f1eec4d50eab',
    redirectUri: TRACKER_APP_CALLBACK_URI,
    scopes: [],
    supportsPkce: false,
  },
]

export const DEFAULT_TRACKER_ACCOUNTS: TrackerAccount[] = TRACKER_PROVIDER_CONFIGS.map((provider: TrackerProviderConfig): TrackerAccount => {
  return {
    providerId: provider.providerId,
    status: 'disconnected',
  }
})

export const DEFAULT_TRACKER_PREFERENCES: TrackerPreferences = {
  accounts: DEFAULT_TRACKER_ACCOUNTS,
  comicMappings: [],
  providerOAuthConfigs: [],
  autoSyncEnabled: false,
  updateStrategy: 'on_chapter_complete',
}

export function getTrackerProviderConfig(providerId: TrackerProviderId): TrackerProviderConfig | undefined {
  return TRACKER_PROVIDER_CONFIGS.find((provider: TrackerProviderConfig): boolean => {
    return provider.providerId === providerId
  })
}

function trackerOptionalText(value: string | undefined): boolean {
  return value === undefined || typeof value === 'string'
}

function trackerOptionalNumber(value: number | undefined): boolean {
  return value === undefined || (typeof value === 'number' && Number.isFinite(value))
}

function trackerAccountMemberValid(value: TrackerAccount): boolean {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false
  if (typeof value.providerId !== 'string' || typeof value.status !== 'string') return false
  if (!trackerOptionalText(value.credentialAccountKey) || !trackerOptionalText(value.statusReason) ||
    !trackerOptionalNumber(value.connectedAt) || !trackerOptionalNumber(value.lastSyncAt)) return false
  const profile = value.profile
  if (profile === undefined) return true
  return profile !== null && typeof profile === 'object' && !Array.isArray(profile) &&
    trackerOptionalText(profile.username) && trackerOptionalText(profile.displayName) &&
    trackerOptionalText(profile.providerUserId)
}

function trackerMappingMemberValid(value: ComicTrackerMapping): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value) &&
    typeof value.providerId === 'string' && typeof value.comicId === 'string' &&
    typeof value.providerTitleId === 'string' && typeof value.mappingState === 'string' &&
    typeof value.userConfirmed === 'boolean' && typeof value.createdAt === 'number' &&
    Number.isFinite(value.createdAt) && trackerOptionalText(value.providerTitle) &&
    trackerOptionalNumber(value.confidence) && trackerOptionalNumber(value.updatedAt)
}

function trackerOAuthConfigMemberValid(value: TrackerProviderOAuthConfig): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value) &&
    typeof value.providerId === 'string' && trackerOptionalText(value.clientId) &&
    trackerOptionalText(value.redirectUri)
}

function normalizeTrackerOAuthText(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const normalized = value.trim()
  return normalized.length === 0 ? undefined : normalized
}

export function normalizeTrackerProviderOAuthConfigs(values: TrackerProviderOAuthConfig[]): TrackerProviderOAuthConfig[] {
  if (!Array.isArray(values) || !values.every(trackerOAuthConfigMemberValid)) {
    throw new Error('tracker_provider_configs_invalid')
  }
  const configs: TrackerProviderOAuthConfig[] = []
  values.forEach((config: TrackerProviderOAuthConfig) => {
    const provider = getTrackerProviderConfig(config.providerId)
    if (provider === undefined || provider.supportStatus !== 'available') {
      return
    }
    const next: TrackerProviderOAuthConfig = {
      providerId: provider.providerId,
    }
    const clientId = normalizeTrackerOAuthText(config.clientId)
    if (clientId !== undefined) {
      next.clientId = clientId
    }
    const redirectUri = normalizeTrackerOAuthText(config.redirectUri)
    if (redirectUri !== undefined) {
      next.redirectUri = redirectUri
    }
    if (next.clientId === undefined && next.redirectUri === undefined) {
      return
    }
    const existingIndex = configs.findIndex((item: TrackerProviderOAuthConfig): boolean => item.providerId === next.providerId)
    if (existingIndex < 0) {
      configs.push(next)
    } else {
      configs[existingIndex] = next
    }
  })
  return configs
}

export function getTrackerProviderOAuthConfig(
  providerId: TrackerProviderId,
  configs: TrackerProviderOAuthConfig[],
): TrackerProviderOAuthConfig | undefined {
  return normalizeTrackerProviderOAuthConfigs(configs).find((config: TrackerProviderOAuthConfig): boolean => {
    return config.providerId === providerId
  })
}

export function mergeTrackerProviderOAuthConfig(
  provider: TrackerProviderConfig,
  configs: TrackerProviderOAuthConfig[],
): TrackerProviderConfig {
  const override = getTrackerProviderOAuthConfig(provider.providerId, configs)
  if (override === undefined) {
    return provider
  }
  const merged: TrackerProviderConfig = {
    providerId: provider.providerId,
    displayName: provider.displayName,
    supportStatus: provider.supportStatus,
    authentication: provider.authentication,
    authorizationEndpoint: provider.authorizationEndpoint,
    clientId: override.clientId ?? provider.clientId,
    clientSecret: provider.clientSecret,
    redirectUri: override.redirectUri ?? provider.redirectUri,
    scopes: provider.scopes,
    supportsPkce: provider.supportsPkce,
  }
  return merged
}

export function getConfiguredTrackerProviderConfig(
  providerId: TrackerProviderId,
  configs: TrackerProviderOAuthConfig[],
): TrackerProviderConfig | undefined {
  const provider = getTrackerProviderConfig(providerId)
  return provider === undefined ? undefined : mergeTrackerProviderOAuthConfig(provider, configs)
}

export function getTrackerAccountStatusLabel(status: TrackerAccountStatus): string {
  if (status === 'connected') {
    return s('tracker_status_connected')
  }
  if (status === 'expired') {
    return s('tracker_status_expired')
  }
  if (status === 'error') {
    return s('tracker_status_error')
  }
  return s('tracker_status_disconnected')
}

export function normalizeTrackerUpdateStrategy(value: string): TrackerUpdateStrategy {
  if (value === 'on_reader_close' || value === 'manual') {
    return value
  }
  return 'on_chapter_complete'
}

export function getTrackerUpdateStrategyLabel(strategy: TrackerUpdateStrategy): string {
  if (strategy === 'on_reader_close') {
    return s('tracker_update_strategy_reader_close')
  }
  if (strategy === 'manual') {
    return s('tracker_update_strategy_manual')
  }
  return s('tracker_update_strategy_chapter_complete')
}

export function getTrackerAccountDetail(account: TrackerAccount, secureStorageAvailable: boolean): string {
  if (account.status === 'connected') {
    return account.profile?.displayName ?? account.profile?.username ?? s('tracker_detail_public_profile_saved')
  }
  if (!secureStorageAvailable) {
    return s('tracker_detail_secure_storage_unavailable')
  }
  if (account.status === 'expired') {
    return s('tracker_detail_reauth_required')
  }
  if (account.status === 'error') {
    return getTrackerAccountErrorDetail(account.statusReason)
  }
  return s('tracker_detail_disconnected')
}

function getTrackerAccountErrorDetail(reason: string | undefined): string {
  if (reason === 'secure_storage_unavailable' || reason === 'missing_credential_reference') {
    return s('tracker_detail_account_status_unavailable')
  }
  if (reason === 'provider_config_missing' || reason === 'pkce_unavailable') {
    return s('tracker_detail_connect_unavailable')
  }
  return s('tracker_detail_connect_failed')
}

export function normalizeTrackerAccountStatus(value: string): TrackerAccountStatus {
  if (value === 'auth_pending' || value === 'connected' || value === 'expired' || value === 'error') {
    return value
  }
  return 'disconnected'
}

export function normalizeTrackerAccount(value: TrackerAccount, secureStorageAvailable: boolean): TrackerAccount | undefined {
  const provider = getTrackerProviderConfig(value.providerId)
  if (provider === undefined) {
    return undefined
  }
  const status = normalizeTrackerAccountStatus(value.status)
  const credentialAccountKey = sanitizeOpaqueId(value.credentialAccountKey)
  // Older disconnects discarded the credential reference before a cleanup error.
  // That record represents a signed-out account, not a failed sign-in.
  if (status === 'error' && credentialAccountKey === undefined && value.connectedAt === undefined &&
    ['access_denied', 'invalid_request', 'locked', 'quota_exceeded', 'corrupted', 'unsupported',
      'storage_unavailable', 'unknown'].includes(value.statusReason ?? '')) {
    return { providerId: provider.providerId, status: 'disconnected' }
  }
  const next: TrackerAccount = {
    providerId: provider.providerId,
    status,
  }
  const profile = normalizePublicProfile(value.profile)
  if (profile !== undefined) {
    next.profile = profile
  }
  if (credentialAccountKey !== undefined) {
    next.credentialAccountKey = credentialAccountKey
  }
  if (value.connectedAt !== undefined && value.connectedAt > 0) {
    next.connectedAt = value.connectedAt
  }
  if (value.lastSyncAt !== undefined && value.lastSyncAt > 0) {
    next.lastSyncAt = value.lastSyncAt
  }
  if (value.statusReason !== undefined && value.statusReason.trim().length > 0) {
    next.statusReason = sanitizeStatusReason(value.statusReason)
  }
  if (status === 'connected' && (!secureStorageAvailable || credentialAccountKey === undefined)) {
    next.status = 'error'
    next.statusReason = 'secure_storage_unavailable'
  }
  return next
}

export function mergeTrackerAccounts(savedAccounts: TrackerAccount[], secureStorageAvailable: boolean): TrackerAccount[] {
  if (!Array.isArray(savedAccounts) || !savedAccounts.every(trackerAccountMemberValid)) {
    throw new Error('tracker_accounts_invalid')
  }
  return DEFAULT_TRACKER_ACCOUNTS.map((account: TrackerAccount): TrackerAccount => {
    const saved = savedAccounts.find((item: TrackerAccount): boolean => {
      return item.providerId === account.providerId
    })
    if (saved === undefined) {
      return account
    }
    const normalized = normalizeTrackerAccount(saved, secureStorageAvailable)
    return normalized === undefined ? account : normalized
  })
}

export function normalizeComicTrackerMappings(values: ComicTrackerMapping[]): ComicTrackerMapping[] {
  if (!Array.isArray(values) || !values.every(trackerMappingMemberValid)) {
    throw new Error('tracker_mappings_invalid')
  }
  const mappings: ComicTrackerMapping[] = []
  values.forEach((mapping: ComicTrackerMapping) => {
    const provider = getTrackerProviderConfig(mapping.providerId)
    if (provider === undefined || mapping.comicId.trim().length === 0 || mapping.providerTitleId.trim().length === 0) {
      return
    }
    const state = normalizeMappingState(mapping.mappingState)
    const next: ComicTrackerMapping = {
      comicId: mapping.comicId.trim(),
      providerId: provider.providerId,
      providerTitleId: mapping.providerTitleId.trim().slice(0, 128),
      mappingState: state,
      userConfirmed: state === 'confirmed' ? mapping.userConfirmed : false,
      createdAt: mapping.createdAt > 0 ? mapping.createdAt : Date.now(),
    }
    if (mapping.providerTitle !== undefined && mapping.providerTitle.trim().length > 0) {
      next.providerTitle = mapping.providerTitle.trim().slice(0, 200)
    }
    if (mapping.confidence !== undefined && mapping.confidence === mapping.confidence) {
      next.confidence = Math.max(0, Math.min(1, mapping.confidence))
    }
    if (mapping.updatedAt !== undefined && mapping.updatedAt > 0) {
      next.updatedAt = mapping.updatedAt
    }
    const existingIndex = mappings.findIndex((item: ComicTrackerMapping): boolean => {
      return item.comicId === next.comicId && item.providerId === next.providerId
    })
    if (existingIndex < 0) {
      mappings.push(next)
    } else if (shouldReplaceComicTrackerMapping(mappings[existingIndex], next)) {
      mappings[existingIndex] = next
    }
  })
  return mappings
}

export function findComicTrackerMappings(comicId: ComicId, mappings: ComicTrackerMapping[]): ComicTrackerMapping[] {
  const normalizedComicId = comicId.trim()
  if (normalizedComicId.length === 0) {
    return []
  }
  return normalizeComicTrackerMappings(mappings).filter((mapping: ComicTrackerMapping): boolean => {
    return mapping.comicId === normalizedComicId
  })
}

export function summarizeComicTrackerMappings(mappings: ComicTrackerMapping[]): TrackerComicMappingSummary {
  const summary: TrackerComicMappingSummary = {
    total: 0,
    confirmed: 0,
    candidate: 0,
    stale: 0,
    rejected: 0,
    unmapped: 0,
  }
  normalizeComicTrackerMappings(mappings).forEach((mapping: ComicTrackerMapping) => {
    summary.total += 1
    if (mapping.mappingState === 'confirmed') {
      summary.confirmed += 1
    } else if (mapping.mappingState === 'candidate') {
      summary.candidate += 1
    } else if (mapping.mappingState === 'stale') {
      summary.stale += 1
    } else if (mapping.mappingState === 'rejected') {
      summary.rejected += 1
    } else {
      summary.unmapped += 1
    }
  })
  return summary
}

export function prepareTrackerOAuthStart(
  request: TrackerOAuthStartRequest,
  secureStorageAvailable: boolean,
): TrackerOAuthStartPreparation {
  const provider = request.providerConfig ?? getTrackerProviderConfig(request.providerId)
  if (provider === undefined || provider.supportStatus === 'unsupported') {
    return {
      status: 'provider_unsupported',
      providerId: request.providerId,
      message: 'provider_unsupported',
    }
  }
  if (provider.supportStatus !== 'available') {
    return {
      status: 'provider_unsupported',
      providerId: request.providerId,
      message: 'provider_planned',
    }
  }
  if (!secureStorageAvailable) {
    return {
      status: 'secure_storage_unavailable',
      providerId: request.providerId,
      message: 'secure_storage_unavailable',
    }
  }
  if (provider.providerId === 'myanimelist' && (!provider.supportsPkce || request.codeChallenge.trim().length === 0)) {
    return {
      status: 'pkce_unavailable',
      providerId: request.providerId,
      message: 'pkce_unavailable',
    }
  }
  if (provider.authorizationEndpoint === undefined || provider.clientId === undefined || provider.redirectUri === undefined ||
    (provider.providerId === 'bangumi' && provider.clientSecret === undefined)) {
    return {
      status: 'provider_config_missing',
      providerId: request.providerId,
      message: 'provider_config_missing',
    }
  }
  const authorizationUrl = buildTrackerAuthorizationUrl(provider, request.state, request.codeChallenge)
  return {
    status: 'ready',
    providerId: request.providerId,
    authorizationUrl,
    state: request.state,
    message: 'ready',
  }
}

// Bangumi's login redirect rebuilds the query, dropping redirect_uri and copying state verbatim.
// Carry the fixed app callback through that redirect. The random state itself remains unchanged.
export function bangumiAuthorizationState(state: string): string {
  return state + '&redirect_uri=' + TRACKER_APP_CALLBACK_URI
}

export function buildTrackerAuthorizationUrl(
  provider: TrackerProviderConfig,
  state: string,
  codeChallenge: string,
): string {
  const implicitGrant = provider.providerId === 'anilist'
  const authorizationState = provider.providerId === 'bangumi' && provider.redirectUri === TRACKER_APP_CALLBACK_URI
    ? bangumiAuthorizationState(state) : state
  const params: string[] = [
    'response_type=' + (implicitGrant ? 'token' : 'code'),
    'client_id=' + encodeURIComponent(provider.clientId ?? ''),
    'state=' + encodeURIComponent(authorizationState),
  ]
  // AniList implicit authorization uses the redirect registered for this client.
  if (!implicitGrant) {
    params.push('redirect_uri=' + encodeURIComponent(provider.redirectUri ?? ''))
  }
  if (provider.supportsPkce) {
    params.push('code_challenge=' + encodeURIComponent(codeChallenge))
    params.push('code_challenge_method=' + (provider.providerId === 'myanimelist' ? 'plain' : 'S256'))
  }
  if (provider.scopes.length > 0) {
    params.push('scope=' + encodeURIComponent(provider.scopes.join(' ')))
  }
  return `${provider.authorizationEndpoint}?${params.join('&')}`
}

export function parseTrackerOAuthCallback(callbackUri: string, expectedState: string, implicitGrant: boolean = false,
  alternateState?: string): TrackerOAuthCallbackResult {
  let query: Record<string, string>
  try {
    query = parseQuery(callbackUri, implicitGrant)
  } catch (_error) {
    return {
      ok: false,
      codePresent: false,
      reason: 'invalid_callback',
    }
  }
  // Compare the full wire value, never a prefix of the random state.
  const receivedState = query['state']
  const state = receivedState !== undefined && receivedState === alternateState ? expectedState : receivedState
  const code = query['code']
  const providerError = query['error']
  if (state === undefined || state !== expectedState) {
    return {
      ok: false,
      state,
      codePresent: code !== undefined && code.length > 0,
      reason: 'state_mismatch',
    }
  }
  if (providerError !== undefined && providerError.length > 0) {
    return {
      ok: false,
      state,
      codePresent: false,
      errorCode: sanitizeStatusReason(providerError),
      reason: 'provider_error',
    }
  }
  if (implicitGrant) {
    const token = query['access_token']?.trim()
    const tokenType = query['token_type']?.toLowerCase()
    return token !== undefined && token.length > 0 && tokenType === 'bearer'
      ? { ok: true, state, codePresent: false }
      : { ok: false, state, codePresent: false, reason: 'invalid_callback' }
  }
  if (code === undefined || code.length === 0) {
    return {
      ok: false,
      state,
      codePresent: false,
      reason: 'missing_code',
    }
  }
  return {
    ok: true,
    state,
    codePresent: true,
  }
}

function trackerBase64UrlEncode(bytes: Uint8Array): string {
  const helper = new util.Base64Helper()
  return helper.encodeToStringSync(bytes)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

function trackerRandomBase64Url(byteLength: number): string {
  return trackerBase64UrlEncode(cryptoFramework.createRandom().generateRandomSync(byteLength).data)
}

function trackerSha256Base64Url(value: string): string {
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: trackerUtf8Encode(value) })
  return trackerBase64UrlEncode(md.digestSync().data)
}

export function createTrackerOAuthState(): string {
  return trackerRandomBase64Url(TRACKER_OAUTH_STATE_BYTES)
}

export function createTrackerPkcePair(providerId: TrackerProviderId = 'anilist'): TrackerPkcePair {
  const codeVerifier = trackerRandomBase64Url(TRACKER_PKCE_VERIFIER_BYTES)
  return {
    codeVerifier,
    // MyAnimeList accepts only plain PKCE; its challenge is the saved verifier.
    codeChallenge: providerId === 'myanimelist' ? codeVerifier : trackerSha256Base64Url(codeVerifier),
  }
}

export class UnavailableTrackerCredentialSecretStore implements TrackerCredentialSecretStore {
  isAvailable(): boolean {
    return false
  }

  async writeToken(request: TrackerCredentialWriteRequest): Promise<TrackerCredentialStoreResult> {
    return this.unavailable('write', request.providerId)
  }

  async readToken(_ref: TrackerCredentialSecretRef): Promise<Uint8Array | undefined> {
    return undefined
  }

  async deleteToken(ref: TrackerCredentialSecretRef): Promise<TrackerCredentialStoreResult> {
    return this.unavailable('delete', ref.providerId)
  }

  async deleteAccount(ref: TrackerCredentialAccountRef): Promise<TrackerCredentialStoreResult> {
    return this.unavailable('delete', ref.providerId)
  }

  private unavailable(operation: 'write' | 'delete', providerId: TrackerProviderId): TrackerCredentialStoreResult {
    return {
      ok: false,
      error: {
        code: 'storage_unavailable',
        retryable: false,
        operation,
        providerId,
      },
    }
  }
}

function trackerUtf8Encode(value: string): Uint8Array {
  return new Uint8Array(buffer.from(value, 'utf-8').buffer)
}

export function decodeTrackerSecretBytes(bytes: Uint8Array): string {
  const exact = new Uint8Array(bytes.byteLength)
  exact.set(bytes)
  return buffer.from(exact.buffer).toString('utf-8')
}

function trackerCredentialAlias(ref: TrackerCredentialSecretRef): string {
  return `${TRACKER_ASSET_ALIAS_PREFIX}.${ref.providerId}.${ref.accountKey}.${ref.secretKind}`
}

function trackerAssetQuery(ref: TrackerCredentialSecretRef, suffix: string = ''): asset.AssetMap {
  const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
  query.set(asset.Tag.ALIAS, trackerUtf8Encode(trackerCredentialAlias(ref) + suffix))
  query.set(asset.Tag.DATA_LABEL_CRITICAL_1, trackerUtf8Encode(ref.providerId))
  query.set(asset.Tag.DATA_LABEL_CRITICAL_2, trackerUtf8Encode(ref.accountKey))
  query.set(asset.Tag.DATA_LABEL_CRITICAL_3, trackerUtf8Encode(ref.secretKind))
  query.set(asset.Tag.GROUP_ID, trackerUtf8Encode(TRACKER_ASSET_GROUP_ID))
  return query
}

function trackerAssetAccountQuery(ref: TrackerCredentialAccountRef): asset.AssetMap {
  const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
  query.set(asset.Tag.DATA_LABEL_CRITICAL_1, trackerUtf8Encode(ref.providerId))
  query.set(asset.Tag.DATA_LABEL_CRITICAL_2, trackerUtf8Encode(ref.accountKey))
  query.set(asset.Tag.GROUP_ID, trackerUtf8Encode(TRACKER_ASSET_GROUP_ID))
  return query
}

function trackerCredentialErrorCode(error: BusinessError | undefined): TrackerCredentialErrorCode {
  const code = error?.code
  if (code === 201 || code === 24000004) {
    return 'access_denied'
  }
  if (code === 401) {
    return 'invalid_request'
  }
  if (code === 24000002) {
    return 'not_found'
  }
  if (code === 24000005) {
    return 'locked'
  }
  if (code === 24000006) {
    return 'quota_exceeded'
  }
  if (code === 24000007) {
    return 'corrupted'
  }
  if (code === 24000017) {
    return 'unsupported'
  }
  if (code === 24000001 || code === 24000008 || code === 24000009 || code === 24000010 ||
    code === 24000011 || code === 24000012 || code === 24000013 || code === 24000014 ||
    code === 24000015) {
    return 'storage_unavailable'
  }
  return 'unknown'
}

function trackerCredentialResult(
  ok: boolean,
  operation: 'write' | 'read' | 'delete',
  providerId: TrackerProviderId,
  error?: BusinessError,
): TrackerCredentialStoreResult {
  if (ok) {
    return { ok: true }
  }
  const code = trackerCredentialErrorCode(error)
  return trackerCredentialFailureResult(code, operation, providerId)
}

function trackerCredentialFailureResult(
  code: TrackerCredentialErrorCode,
  operation: 'write' | 'read' | 'delete',
  providerId: TrackerProviderId,
): TrackerCredentialStoreResult {
  return {
    ok: false,
    error: {
      code,
      retryable: code === 'locked' || code === 'storage_unavailable' || code === 'unknown',
      operation,
      providerId,
    },
  }
}

const TRACKER_ASSET_SECRET_LIMIT: number = 1024

export class AssetStoreTrackerCredentialSecretStore implements TrackerCredentialSecretStore {
  isAvailable(): boolean {
    return true
  }

  async writeToken(request: TrackerCredentialWriteRequest): Promise<TrackerCredentialStoreResult> {
    if (request.secretBytes.byteLength === 0 || request.accountKey.trim().length === 0) {
      return trackerCredentialFailureResult('invalid_request', 'write', request.providerId)
    }
    const partCount = Math.ceil(request.secretBytes.byteLength / TRACKER_ASSET_SECRET_LIMIT)
    if (partCount > 64) return trackerCredentialFailureResult('invalid_request', 'write', request.providerId)
    const generation = partCount > 1 ? util.generateRandomUUID() : ''
    let written = 0
    try {
      // Publish the root last so readers never see a partially written long secret.
      for (let part = 1; part < partCount; part++) {
        const offset = part * TRACKER_ASSET_SECRET_LIMIT
        const attributes = trackerAssetQuery(request, `.${generation}.${part}`)
        await this.writeAsset(attributes, request.secretBytes.slice(offset, offset + TRACKER_ASSET_SECRET_LIMIT))
        written++
      }
      const root = trackerAssetQuery(request)
      if (partCount > 1) {
        root.set(asset.Tag.DATA_LABEL_CRITICAL_4, trackerUtf8Encode(`${generation}:${partCount}`))
      }
      await this.writeAsset(root, request.secretBytes.slice(0, TRACKER_ASSET_SECRET_LIMIT))
      return trackerCredentialResult(true, 'write', request.providerId)
    } catch (error) {
      for (let part = 1; part <= written; part++) {
        try {
          await asset.remove(trackerAssetQuery(request, `.${generation}.${part}`))
        } catch (_) {}
      }
      return trackerCredentialResult(false, 'write', request.providerId, error as BusinessError)
    }
  }

  private async writeAsset(attributes: asset.AssetMap, secret: Uint8Array): Promise<void> {
    attributes.set(asset.Tag.SECRET, secret)
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    await asset.add(attributes)
  }

  async readToken(ref: TrackerCredentialSecretRef): Promise<Uint8Array | undefined> {
    try {
      const root = await this.readAsset(trackerAssetQuery(ref))
      const first = root?.get(asset.Tag.SECRET) as Uint8Array | undefined
      const metadata = root?.get(asset.Tag.DATA_LABEL_CRITICAL_4) as Uint8Array | undefined
      if (first === undefined || metadata === undefined) return first

      const fields = decodeTrackerSecretBytes(metadata).split(':')
      const partCount = Number(fields[1])
      if (first.length !== TRACKER_ASSET_SECRET_LIMIT || !Number.isInteger(partCount) || partCount < 2 ||
        partCount > 64 || !/^[0-9a-f-]{36}$/i.test(fields[0])) return undefined
      const result = new Uint8Array(partCount * TRACKER_ASSET_SECRET_LIMIT)
      result.set(first)
      let offset = first.length
      for (let part = 1; part < partCount; part++) {
        const row = await this.readAsset(trackerAssetQuery(ref, `.${fields[0]}.${part}`))
        const bytes = row?.get(asset.Tag.SECRET) as Uint8Array | undefined
        if (bytes === undefined || (part < partCount - 1 && bytes.length !== TRACKER_ASSET_SECRET_LIMIT)) {
          return undefined
        }
        result.set(bytes, offset)
        offset += bytes.length
      }
      return result.slice(0, offset)
    } catch (_) {
      return undefined
    }
  }

  private async readAsset(query: asset.AssetMap): Promise<asset.AssetMap | undefined> {
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    query.set(asset.Tag.RETURN_LIMIT, 1)
    const rows = await asset.query(query)
    return rows[0]
  }

  async deleteToken(ref: TrackerCredentialSecretRef): Promise<TrackerCredentialStoreResult> {
    const query = trackerAssetQuery(ref)
    query.delete(asset.Tag.ALIAS)
    try {
      await asset.remove(query)
      return trackerCredentialResult(true, 'delete', ref.providerId)
    } catch (error) {
      const code = trackerCredentialErrorCode(error as BusinessError)
      if (code === 'not_found') {
        return trackerCredentialResult(true, 'delete', ref.providerId)
      }
      return trackerCredentialResult(false, 'delete', ref.providerId, error as BusinessError)
    }
  }

  async deleteAccount(ref: TrackerCredentialAccountRef): Promise<TrackerCredentialStoreResult> {
    try {
      await asset.remove(trackerAssetAccountQuery(ref))
      return trackerCredentialResult(true, 'delete', ref.providerId)
    } catch (error) {
      const code = trackerCredentialErrorCode(error as BusinessError)
      if (code === 'not_found') {
        return trackerCredentialResult(true, 'delete', ref.providerId)
      }
      return trackerCredentialResult(false, 'delete', ref.providerId, error as BusinessError)
    }
  }
}

export interface TrackerSyncPreferencesPatch {
  autoSyncEnabled?: boolean
  updateStrategy?: TrackerUpdateStrategy
}

export interface TrackerAccountCommitResult {
  applied: boolean
  preferences: TrackerPreferences
}

const trackerPreferenceOperations: Map<string, Promise<void>> = new Map()
const trackerMappingListeners: Map<string, Set<() => void>> = new Map()
const trackerMappingSnapshots: Map<string, ComicTrackerMapping[]> = new Map()

export class TrackerPreferencesStore {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore

  constructor(context: common.UIAbilityContext, secretStore: TrackerCredentialSecretStore = new UnavailableTrackerCredentialSecretStore()) {
    this.context = context
    this.secretStore = secretStore
  }

  /** Public mapping projection only. No account/token is read for library filtering. */
  mappingSnapshot(): ComicTrackerMapping[] {
    const cached = trackerMappingSnapshots.get(this.context.filesDir)
    if (cached !== undefined) return normalizeComicTrackerMappings(cached)
    const store = preferences.getPreferencesSync(this.context, { name: TRACKER_PREFERENCES_STORE_NAME })
    const mappings = normalizeComicTrackerMappings(this.parseMappings(store.getSync(TRACKER_COMIC_MAPPINGS_KEY, '[]') as string))
    trackerMappingSnapshots.set(this.context.filesDir, mappings)
    return normalizeComicTrackerMappings(mappings)
  }

  subscribeMappings(listener: () => void): () => void {
    const key = this.context.filesDir
    const listeners = trackerMappingListeners.get(key) ?? new Set<() => void>()
    listeners.add(listener); trackerMappingListeners.set(key, listeners)
    return (): void => { listeners.delete(listener) }
  }

  invalidateMappingSnapshot(): void {
    trackerMappingSnapshots.delete(this.context.filesDir)
    trackerMappingListeners.get(this.context.filesDir)?.forEach((listener: () => void): void => { listener() })
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (trackerPreferenceOperations.get(key) ?? Promise.resolve()).then(operation)
    trackerPreferenceOperations.set(key, result.then(() => {}, () => {}))
    return result
  }

  private write<T>(operation: () => Promise<T>): Promise<T> {
    return BackupRestoreActivity.runWrite(() => this.ordered(operation))
  }

  async load(): Promise<TrackerPreferences> {
    return this.write(() => this.loadCurrent())
  }

  private async loadCurrent(): Promise<TrackerPreferences> {
    const store = await this.preferences()
    const accountsJson = await store.get(TRACKER_ACCOUNTS_KEY, JSON.stringify(DEFAULT_TRACKER_ACCOUNTS)) as string
    const mappingsJson = await store.get(TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify([])) as string
    trackerMappingSnapshots.set(this.context.filesDir, normalizeComicTrackerMappings(this.parseMappings(mappingsJson)))
    const providerOAuthConfigsJson = await store.get(TRACKER_PROVIDER_OAUTH_CONFIGS_KEY, JSON.stringify([])) as string
    const autoSyncEnabled = await store.get(TRACKER_AUTO_SYNC_ENABLED_KEY, DEFAULT_TRACKER_PREFERENCES.autoSyncEnabled) as boolean
    const updateStrategy = await store.get(TRACKER_UPDATE_STRATEGY_KEY, DEFAULT_TRACKER_PREFERENCES.updateStrategy) as string
    return {
      accounts: mergeTrackerAccounts(this.parseAccounts(accountsJson), this.secretStore.isAvailable()),
      comicMappings: normalizeComicTrackerMappings(this.parseMappings(mappingsJson)),
      providerOAuthConfigs: normalizeTrackerProviderOAuthConfigs(this.parseProviderOAuthConfigs(providerOAuthConfigsJson)),
      autoSyncEnabled: autoSyncEnabled === true,
      updateStrategy: normalizeTrackerUpdateStrategy(updateStrategy),
    }
  }

  async saveAccounts(accounts: TrackerAccount[]): Promise<TrackerPreferences> {
    return this.write(() => this.saveAccountsCurrent(accounts))
  }

  private async saveAccountsCurrent(accounts: TrackerAccount[]): Promise<TrackerPreferences> {
    const current = await this.loadCurrent()
    const next: TrackerPreferences = {
      accounts: mergeTrackerAccounts(accounts, this.secretStore.isAvailable()),
      comicMappings: current.comicMappings,
      providerOAuthConfigs: current.providerOAuthConfigs,
      autoSyncEnabled: current.autoSyncEnabled,
      updateStrategy: current.updateStrategy,
    }
    await this.commit(new Map<string, preferences.ValueType>([[TRACKER_ACCOUNTS_KEY, JSON.stringify(next.accounts)]]))
    return next
  }

  async markAccountSynced(providerId: TrackerProviderId, credentialAccountKey: string, now: number): Promise<void> {
    return this.write(async (): Promise<void> => {
      const current = await this.loadCurrent()
      const account = current.accounts.find((item: TrackerAccount): boolean => item.providerId === providerId &&
        item.status === 'connected' && item.credentialAccountKey === credentialAccountKey)
      if (account === undefined) return
      account.lastSyncAt = Math.max(account.lastSyncAt ?? 0, now)
      await this.saveAccountsCurrent(current.accounts)
    })
  }

  async saveAccountIfCurrent(
    expected: TrackerAccount,
    next: TrackerAccount,
    prepare?: () => Promise<void>,
  ): Promise<TrackerAccountCommitResult> {
    return this.write(async (): Promise<TrackerAccountCommitResult> => {
      const current = await this.loadCurrent()
      const account = current.accounts.find((item: TrackerAccount): boolean => item.providerId === expected.providerId)
      if (account === undefined || next.providerId !== expected.providerId ||
        account.status !== expected.status || account.credentialAccountKey !== expected.credentialAccountKey ||
        account.connectedAt !== expected.connectedAt || account.lastSyncAt !== expected.lastSyncAt) {
        return { applied: false, preferences: current }
      }
      // Local credential writes share admission with the identity check; network work stays outside.
      if (prepare !== undefined) await prepare()
      const saved = await this.saveAccountsCurrent(current.accounts.map((item: TrackerAccount): TrackerAccount =>
        item.providerId === expected.providerId ? next : item))
      return { applied: true, preferences: saved }
    })
  }

  async replaceLinkedCredential(providerId: TrackerProviderId, accountKey: string,
    replace: () => Promise<void>): Promise<boolean> {
    return this.write(async (): Promise<boolean> => {
      const current = await this.loadCurrent()
      const account = current.accounts.find((item: TrackerAccount): boolean => item.providerId === providerId)
      // Refresh may race a profile or progress update. Only unlinking or changing the credential invalidates it.
      if (account?.credentialAccountKey !== accountKey || account.connectedAt === undefined) return false
      await replace()
      return true
    })
  }

  async disconnectAccount(providerId: TrackerProviderId): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      const current = await this.loadCurrent()
      const account = current.accounts.find((item: TrackerAccount): boolean => item.providerId === providerId)
      if (account === undefined) return current
      const disconnected: TrackerAccount = { providerId, status: 'disconnected',
        credentialAccountKey: account.credentialAccountKey }
      const saved = account.status === 'disconnected' ? current :
        await this.saveAccountsCurrent(current.accounts.map((item: TrackerAccount): TrackerAccount =>
          item.providerId === providerId ? disconnected : item))
      return this.finishDisconnectCleanup(saved, disconnected)
    })
  }

  private async finishDisconnectCleanup(preferences: TrackerPreferences, account: TrackerAccount): Promise<TrackerPreferences> {
    if (account.credentialAccountKey === undefined) return preferences
    try {
      const deleted = await this.secretStore.deleteAccount({ providerId: account.providerId, accountKey: account.credentialAccountKey })
      if (!deleted.ok) {
        console.warn('[Tracker] disconnect_cleanup_failed provider=' + account.providerId + ' code=' + (deleted.error?.code ?? 'unknown'))
        return preferences
      }
    } catch (_) {
      console.warn('[Tracker] disconnect_cleanup_failed provider=' + account.providerId)
      return preferences
    }
    return this.saveAccountsCurrent(preferences.accounts.map((item: TrackerAccount): TrackerAccount =>
      item.providerId === account.providerId ? { providerId: account.providerId, status: 'disconnected' } : item))
  }

  async saveComicMappings(mappings: ComicTrackerMapping[]): Promise<TrackerPreferences> {
    return this.write(() => this.saveComicMappingsCurrent(mappings))
  }

  /** Local title bindings only: no account/session transfer or remote progress write.
   * Keep any destination binding selected by the user, including its rejection state. */
  async copyComicMappings(fromComicId: string, toComicId: string): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      const current = await this.loadCurrent()
      const destinationProviders = new Set<TrackerProviderId>(current.comicMappings
        .filter((row: ComicTrackerMapping): boolean => row.comicId === toComicId)
        .map((row: ComicTrackerMapping): TrackerProviderId => row.providerId))
      const copies = current.comicMappings.filter((row: ComicTrackerMapping): boolean =>
        row.comicId === fromComicId && row.mappingState === 'confirmed' && row.userConfirmed &&
        !destinationProviders.has(row.providerId))
        .map((row: ComicTrackerMapping): ComicTrackerMapping => ({ comicId: toComicId,
          providerId: row.providerId, providerTitleId: row.providerTitleId, providerTitle: row.providerTitle,
          mappingState: row.mappingState, confidence: row.confidence, userConfirmed: row.userConfirmed,
          createdAt: row.createdAt, updatedAt: row.updatedAt }))
      return copies.length === 0 ? current : this.saveComicMappingsCurrent(current.comicMappings.concat(copies))
    })
  }

  private async saveComicMappingsCurrent(mappings: ComicTrackerMapping[]): Promise<TrackerPreferences> {
    const current = await this.loadCurrent()
    const next: TrackerPreferences = {
      accounts: current.accounts,
      comicMappings: normalizeComicTrackerMappings(mappings),
      providerOAuthConfigs: current.providerOAuthConfigs,
      autoSyncEnabled: current.autoSyncEnabled,
      updateStrategy: current.updateStrategy,
    }
    await this.commit(new Map<string, preferences.ValueType>([[TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify(next.comicMappings)]]))
    return next
  }

  async saveSyncPreferences(autoSyncEnabled: boolean, updateStrategy: TrackerUpdateStrategy): Promise<TrackerPreferences> {
    return this.saveSyncPreferenceChanges({ autoSyncEnabled, updateStrategy })
  }

  async saveSyncPreferenceChanges(patch: TrackerSyncPreferencesPatch): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      // Missing keys have defaults; damaged existing documents must not be overwritten.
      await this.loadCurrent()
      const values: Map<string, preferences.ValueType> = new Map()
      if (patch.autoSyncEnabled !== undefined) values.set(TRACKER_AUTO_SYNC_ENABLED_KEY, patch.autoSyncEnabled)
      if (patch.updateStrategy !== undefined) values.set(TRACKER_UPDATE_STRATEGY_KEY, normalizeTrackerUpdateStrategy(patch.updateStrategy))
      await this.commit(values)
      return this.loadCurrent()
    })
  }

  async saveProviderOAuthConfig(
    providerId: TrackerProviderId,
    clientId: string,
    redirectUri: string,
  ): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      const current = await this.loadCurrent()
      const nextConfigs = current.providerOAuthConfigs.filter((config: TrackerProviderOAuthConfig): boolean => {
        return config.providerId !== providerId
      })
      nextConfigs.push({ providerId, clientId, redirectUri })
      const next: TrackerPreferences = {
        accounts: current.accounts,
        comicMappings: current.comicMappings,
        providerOAuthConfigs: normalizeTrackerProviderOAuthConfigs(nextConfigs),
        autoSyncEnabled: current.autoSyncEnabled,
        updateStrategy: current.updateStrategy,
      }
      await this.commit(new Map<string, preferences.ValueType>([[TRACKER_PROVIDER_OAUTH_CONFIGS_KEY, JSON.stringify(next.providerOAuthConfigs)]]))
      return next
    })
  }

  async upsertComicMapping(mapping: ComicTrackerMapping): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      const current = await this.loadCurrent()
      const nextMappings = current.comicMappings.filter((item: ComicTrackerMapping): boolean => {
        return item.comicId !== mapping.comicId.trim() || item.providerId !== mapping.providerId
      })
      nextMappings.push(mapping)
      return this.saveComicMappingsCurrent(nextMappings)
    })
  }

  async listComicMappings(comicId: ComicId): Promise<ComicTrackerMapping[]> {
    const current = await this.load()
    return findComicTrackerMappings(comicId, current.comicMappings)
  }

  async confirmComicMapping(comicId: ComicId, providerId: TrackerProviderId, now: number = Date.now()): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      return this.updateComicMappingState(comicId, providerId, 'confirmed', true, now)
    })
  }

  async rejectComicMapping(comicId: ComicId, providerId: TrackerProviderId, now: number = Date.now()): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      return this.updateComicMappingState(comicId, providerId, 'rejected', false, now)
    })
  }

  async removeComicMapping(comicId: ComicId, providerId: TrackerProviderId): Promise<TrackerPreferences> {
    return this.write(async (): Promise<TrackerPreferences> => {
      const normalizedComicId = comicId.trim()
      const current = await this.loadCurrent()
      const nextMappings = current.comicMappings.filter((mapping: ComicTrackerMapping): boolean => {
        return mapping.comicId !== normalizedComicId || mapping.providerId !== providerId
      })
      return this.saveComicMappingsCurrent(nextMappings)
    })
  }

  private async updateComicMappingState(
    comicId: ComicId,
    providerId: TrackerProviderId,
    mappingState: TrackerMappingState,
    userConfirmed: boolean,
    now: number,
  ): Promise<TrackerPreferences> {
    const normalizedComicId = comicId.trim()
    if (normalizedComicId.length === 0) {
      return this.loadCurrent()
    }
    const current = await this.loadCurrent()
    const nextMappings = current.comicMappings.map((mapping: ComicTrackerMapping): ComicTrackerMapping => {
      if (mapping.comicId !== normalizedComicId || mapping.providerId !== providerId) {
        return mapping
      }
      const next: ComicTrackerMapping = {
        comicId: mapping.comicId,
        providerId: mapping.providerId,
        providerTitleId: mapping.providerTitleId,
        mappingState,
        userConfirmed,
        createdAt: mapping.createdAt,
        updatedAt: now,
      }
      if (mapping.providerTitle !== undefined) {
        next.providerTitle = mapping.providerTitle
      }
      if (mapping.confidence !== undefined) {
        next.confidence = mapping.confidence
      }
      return next
    })
    return this.saveComicMappingsCurrent(nextMappings)
  }

  async prepareReconnect(providerId: TrackerProviderId): Promise<TrackerPreferences> {
    return this.write(() => this.prepareReconnectCurrent(providerId))
  }

  private async prepareReconnectCurrent(providerId: TrackerProviderId): Promise<TrackerPreferences> {
    const current = await this.loadCurrent()
    const store = await this.preferences()
    const retired = JSON.parse(await store.get(TRACKER_RETIRED_CREDENTIALS_KEY, '[]') as string) as TrackerCredentialAccountRef[]
    const pending = retired.filter((ref: TrackerCredentialAccountRef): boolean => ref.providerId !== providerId)
    const account = current.accounts.find((item: TrackerAccount): boolean => item.providerId === providerId)
    const candidates = retired.filter((ref: TrackerCredentialAccountRef): boolean =>
      ref.providerId === providerId && ref.accountKey !== account?.credentialAccountKey)
    const disconnectedKey = account?.status === 'disconnected' ? account.credentialAccountKey : undefined
    if (disconnectedKey !== undefined) candidates.push({ providerId, accountKey: disconnectedKey })
    if (candidates.length === 0) return current

    // New sessions use new keys. Keep failed deletions in the local journal
    // before forgetting the disconnected key, so a later retry can remove them.
    for (const ref of candidates) {
      try {
        const deleted = await this.secretStore.deleteAccount(ref)
        if (deleted.ok) continue
        console.warn('[Tracker] reconnect_cleanup_deferred provider=' + providerId + ' code=' + (deleted.error?.code ?? 'unknown'))
      } catch (_) {
        console.warn('[Tracker] reconnect_cleanup_deferred provider=' + providerId)
      }
      pending.push(ref)
    }
    const accounts = disconnectedKey === undefined ? current.accounts :
      current.accounts.map((item: TrackerAccount): TrackerAccount =>
        item.providerId === providerId ? { providerId, status: 'disconnected' } : item)
    await this.commit(new Map<string, preferences.ValueType>([
      [TRACKER_ACCOUNTS_KEY, JSON.stringify(accounts)],
      [TRACKER_RETIRED_CREDENTIALS_KEY, JSON.stringify(pending)],
    ]))
    return { accounts, comicMappings: current.comicMappings, providerOAuthConfigs: current.providerOAuthConfigs,
      autoSyncEnabled: current.autoSyncEnabled, updateStrategy: current.updateStrategy }
  }

  async prepareConnect(providerId: TrackerProviderId): Promise<TrackerOAuthStartPreparation> {
    return this.write(async (): Promise<TrackerOAuthStartPreparation> => {
      const current = await this.prepareReconnectCurrent(providerId)
      const state = createTrackerOAuthState()
      const provider = getConfiguredTrackerProviderConfig(providerId, current.providerOAuthConfigs)
      const pkce = provider?.supportsPkce ? createTrackerPkcePair(providerId) : undefined
      const preparation = prepareTrackerOAuthStart({
        providerId,
        state,
        codeChallenge: pkce?.codeChallenge ?? '',
        providerConfig: provider,
      }, this.secretStore.isAvailable())
      if (preparation.status !== 'ready') {
        return preparation
      }
      if (pkce !== undefined) {
        const written = await this.secretStore.writeToken({
          providerId,
          accountKey: state,
          secretKind: 'oauth_code_verifier',
          secretBytes: trackerUtf8Encode(pkce.codeVerifier),
        })
        if (!written.ok) {
          return {
            status: 'secure_storage_unavailable',
            providerId,
            message: written.error?.code ?? 'secure_storage_unavailable',
          }
        }
      }
      try {
        await this.saveAccountsCurrent(current.accounts.map((account: TrackerAccount): TrackerAccount => {
          if (account.providerId !== providerId) {
            return account
          }
          return {
            providerId,
            status: 'auth_pending',
            credentialAccountKey: state,
          }
        }))
      } catch (error) {
        if (pkce !== undefined) {
          await this.secretStore.deleteAccount({ providerId, accountKey: state })
        }
        return {
          status: 'secure_storage_unavailable',
          providerId,
          message: 'auth_pending_save_failed',
        }
      }
      return preparation
    })
  }

  private parseAccounts(value: string): TrackerAccount[] {
    try {
      const parsed = JSON.parse(value) as TrackerAccount[]
      if (!Array.isArray(parsed)) {
        throw new Error('tracker_accounts_invalid')
      }
      return parsed
    } catch (_error) {
      throw new Error('tracker_accounts_invalid')
    }
  }

  private parseMappings(value: string): ComicTrackerMapping[] {
    try {
      const parsed = JSON.parse(value) as ComicTrackerMapping[]
      if (!Array.isArray(parsed)) {
        throw new Error('tracker_mappings_invalid')
      }
      return parsed
    } catch (_error) {
      throw new Error('tracker_mappings_invalid')
    }
  }

  private parseProviderOAuthConfigs(value: string): TrackerProviderOAuthConfig[] {
    try {
      const parsed = JSON.parse(value) as TrackerProviderOAuthConfig[]
      if (!Array.isArray(parsed)) {
        throw new Error('tracker_provider_configs_invalid')
      }
      return parsed
    } catch (_error) {
      throw new Error('tracker_provider_configs_invalid')
    }
  }

  private async commit(values: Map<string, preferences.ValueType>): Promise<void> {
    if (values.size === 0) return
    const store = await this.preferences()
    const keys = Array.from(values.keys())
    const previous: Map<string, preferences.ValueType> = new Map()
    for (const key of keys) {
      if (await store.has(key)) previous.set(key, await store.get(key, ''))
    }
    try {
      for (const key of keys) await store.put(key, values.get(key)!)
      await store.flush()
    } catch (error) {
      try {
        for (const key of keys) {
          if (previous.has(key)) await store.put(key, previous.get(key)!)
          else await store.delete(key)
        }
        await store.flush()
      } catch (_restoreError) {
        throw new Error('tracker_preferences_restore_failed')
      }
      throw error as Error
    }
    if (values.has(TRACKER_COMIC_MAPPINGS_KEY)) {
      trackerMappingSnapshots.set(this.context.filesDir,
        normalizeComicTrackerMappings(this.parseMappings(values.get(TRACKER_COMIC_MAPPINGS_KEY) as string)))
      trackerMappingListeners.get(this.context.filesDir)?.forEach((listener: () => void): void => { listener() })
    }
  }

  private preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, TRACKER_PREFERENCES_STORE_NAME)
  }
}

function normalizePublicProfile(profile: TrackerPublicProfile | undefined): TrackerPublicProfile | undefined {
  if (profile === undefined) {
    return undefined
  }
  const next: TrackerPublicProfile = {}
  const username = sanitizePublicProfileField(profile.username)
  const displayName = sanitizePublicProfileField(profile.displayName)
  const providerUserId = sanitizePublicProfileField(profile.providerUserId)
  if (username !== undefined) {
    next.username = username
  }
  if (displayName !== undefined) {
    next.displayName = displayName
  }
  if (providerUserId !== undefined) {
    next.providerUserId = providerUserId
  }
  return username === undefined && displayName === undefined && providerUserId === undefined ? undefined : next
}

function sanitizePublicProfileField(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const trimmed = value.trim()
  return trimmed.length === 0 ? undefined : trimmed.slice(0, 120)
}

function sanitizeOpaqueId(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const trimmed = value.trim()
  if (!/^[A-Za-z0-9._:-]{1,96}$/.test(trimmed)) {
    return undefined
  }
  return trimmed
}

function sanitizeStatusReason(value: string): string {
  return value.replace(/[^A-Za-z0-9._-]/g, '_').slice(0, 48)
}

function normalizeMappingState(value: string): 'unmapped' | 'candidate' | 'confirmed' | 'rejected' | 'stale' {
  if (value === 'candidate' || value === 'confirmed' || value === 'rejected' || value === 'stale') {
    return value
  }
  return 'unmapped'
}

function shouldReplaceComicTrackerMapping(current: ComicTrackerMapping, next: ComicTrackerMapping): boolean {
  if (next.mappingState === 'confirmed' && current.mappingState !== 'confirmed') {
    return true
  }
  if (current.mappingState === 'confirmed' && next.mappingState !== 'confirmed') {
    return false
  }
  const currentUpdatedAt = current.updatedAt ?? current.createdAt
  const nextUpdatedAt = next.updatedAt ?? next.createdAt
  return nextUpdatedAt >= currentUpdatedAt
}

function parseQuery(uri: string, fragmentOnly: boolean = false): Record<string, string> {
  const queryStart = uri.indexOf(fragmentOnly ? '#' : '?')
  if (queryStart < 0) {
    return {}
  }
  const fragmentStart = fragmentOnly ? -1 : uri.indexOf('#', queryStart)
  const query = fragmentStart < 0 ? uri.slice(queryStart + 1) : uri.slice(queryStart + 1, fragmentStart)
  const result: Record<string, string> = {}
  query.split('&').forEach((part: string) => {
    const separator = part.indexOf('=')
    const key = separator < 0 ? part : part.slice(0, separator)
    const value = separator < 0 ? '' : part.slice(separator + 1)
    if (key.length > 0) {
      const decodedKey = decodeURIComponent(key)
      if (fragmentOnly && result[decodedKey] !== undefined) {
        throw new Error('invalid_callback')
      }
      result[decodedKey] = decodeURIComponent(value.replace(/\+/g, ' '))
    }
  })
  return result
}
