import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ComicId } from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'

function s(name: string): string {
  return AppStrings.get(name)
}

export type TrackerProviderId = 'anilist' | 'myanimelist' | 'kitsu' | 'mangaupdates' | 'bangumi'
export type TrackerAccountStatus = 'disconnected' | 'auth_pending' | 'connected' | 'expired' | 'error'
export type TrackerProviderSupportStatus = 'available' | 'planned' | 'unsupported'
export type TrackerAuthPrepareStatus =
  'ready' |
  'provider_config_missing' |
  'secure_storage_unavailable' |
  'provider_unsupported' |
  'pkce_unavailable'

export type TrackerCredentialSecretKind = 'access_token' | 'refresh_token'
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
  authorizationEndpoint?: string
  clientId?: string
  redirectUri?: string
  scopes: string[]
  supportsPkce: boolean
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
  mappingState: 'unmapped' | 'candidate' | 'confirmed' | 'rejected' | 'stale'
  confidence?: number
  userConfirmed: boolean
  createdAt: number
  updatedAt?: number
}

export interface TrackerPreferences {
  accounts: TrackerAccount[]
  comicMappings: ComicTrackerMapping[]
}

export const TRACKER_PREFERENCES_STORE_NAME: string = 'koma_tracker_preferences_v1'
export const TRACKER_ACCOUNTS_KEY: string = 'tracker.accounts'
export const TRACKER_COMIC_MAPPINGS_KEY: string = 'tracker.comicMappings'

export const TRACKER_PROVIDER_CONFIGS: TrackerProviderConfig[] = [
  {
    providerId: 'anilist',
    displayName: 'AniList',
    supportStatus: 'available',
    authorizationEndpoint: 'https://anilist.co/api/v2/oauth/authorize',
    scopes: [],
    supportsPkce: true,
  },
  {
    providerId: 'myanimelist',
    displayName: 'MyAnimeList',
    supportStatus: 'available',
    authorizationEndpoint: 'https://myanimelist.net/v1/oauth2/authorize',
    scopes: ['list_write'],
    supportsPkce: true,
  },
  {
    providerId: 'kitsu',
    displayName: 'Kitsu',
    supportStatus: 'unsupported',
    scopes: [],
    supportsPkce: false,
  },
  {
    providerId: 'mangaupdates',
    displayName: 'MangaUpdates',
    supportStatus: 'planned',
    scopes: [],
    supportsPkce: false,
  },
  {
    providerId: 'bangumi',
    displayName: 'Bangumi',
    supportStatus: 'planned',
    scopes: [],
    supportsPkce: true,
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
}

export function getTrackerProviderConfig(providerId: TrackerProviderId): TrackerProviderConfig | undefined {
  return TRACKER_PROVIDER_CONFIGS.find((provider: TrackerProviderConfig): boolean => {
    return provider.providerId === providerId
  })
}

export function getTrackerAccountStatusLabel(status: TrackerAccountStatus): string {
  if (status === 'auth_pending') {
    return s('tracker_status_auth_pending')
  }
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

export function getTrackerAccountDetail(account: TrackerAccount, secureStorageAvailable: boolean): string {
  if (account.status === 'connected') {
    return account.profile?.displayName ?? account.profile?.username ?? s('tracker_detail_public_profile_saved')
  }
  if (!secureStorageAvailable) {
    return s('tracker_detail_secure_storage_unavailable')
  }
  if (account.status === 'auth_pending') {
    return s('tracker_detail_waiting_callback')
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
      providerTitleId: mapping.providerTitleId.trim(),
      mappingState: state,
      userConfirmed: state === 'confirmed' ? mapping.userConfirmed : false,
      createdAt: mapping.createdAt > 0 ? mapping.createdAt : Date.now(),
    }
    if (mapping.providerTitle !== undefined && mapping.providerTitle.trim().length > 0) {
      next.providerTitle = mapping.providerTitle.trim()
    }
    if (mapping.confidence !== undefined && mapping.confidence >= 0 && mapping.confidence <= 1) {
      next.confidence = mapping.confidence
    }
    if (mapping.updatedAt !== undefined && mapping.updatedAt > 0) {
      next.updatedAt = mapping.updatedAt
    }
    mappings.push(next)
  })
  return mappings
}

export function prepareTrackerOAuthStart(
  request: TrackerOAuthStartRequest,
  secureStorageAvailable: boolean,
): TrackerOAuthStartPreparation {
  const provider = getTrackerProviderConfig(request.providerId)
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
  if (!provider.supportsPkce || request.codeChallenge.trim().length === 0) {
    return {
      status: 'pkce_unavailable',
      providerId: request.providerId,
      message: 'pkce_unavailable',
    }
  }
  if (provider.authorizationEndpoint === undefined || provider.clientId === undefined || provider.redirectUri === undefined) {
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

export function buildTrackerAuthorizationUrl(
  provider: TrackerProviderConfig,
  state: string,
  codeChallenge: string,
): string {
  const params: string[] = [
    'response_type=code',
    'client_id=' + encodeURIComponent(provider.clientId ?? ''),
    'redirect_uri=' + encodeURIComponent(provider.redirectUri ?? ''),
    'state=' + encodeURIComponent(state),
    'code_challenge=' + encodeURIComponent(codeChallenge),
    'code_challenge_method=S256',
  ]
  if (provider.scopes.length > 0) {
    params.push('scope=' + encodeURIComponent(provider.scopes.join(' ')))
  }
  return `${provider.authorizationEndpoint}?${params.join('&')}`
}

export function parseTrackerOAuthCallback(callbackUri: string, expectedState: string): TrackerOAuthCallbackResult {
  let query: Record<string, string>
  try {
    query = parseQuery(callbackUri)
  } catch (_error) {
    return {
      ok: false,
      codePresent: false,
      reason: 'invalid_callback',
    }
  }
  const state = query['state']
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

export class TrackerPreferencesStore {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore

  constructor(context: common.UIAbilityContext, secretStore: TrackerCredentialSecretStore = new UnavailableTrackerCredentialSecretStore()) {
    this.context = context
    this.secretStore = secretStore
  }

  async load(): Promise<TrackerPreferences> {
    const store = await this.preferences()
    const accountsJson = await store.get(TRACKER_ACCOUNTS_KEY, JSON.stringify(DEFAULT_TRACKER_ACCOUNTS)) as string
    const mappingsJson = await store.get(TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify([])) as string
    return {
      accounts: mergeTrackerAccounts(this.parseAccounts(accountsJson), this.secretStore.isAvailable()),
      comicMappings: normalizeComicTrackerMappings(this.parseMappings(mappingsJson)),
    }
  }

  async saveAccounts(accounts: TrackerAccount[]): Promise<TrackerPreferences> {
    const current = await this.load()
    const next: TrackerPreferences = {
      accounts: mergeTrackerAccounts(accounts, this.secretStore.isAvailable()),
      comicMappings: current.comicMappings,
    }
    const store = await this.preferences()
    await store.put(TRACKER_ACCOUNTS_KEY, JSON.stringify(next.accounts))
    await store.flush()
    return next
  }

  async prepareConnect(providerId: TrackerProviderId): Promise<TrackerOAuthStartPreparation> {
    return prepareTrackerOAuthStart({
      providerId,
      state: '',
      codeChallenge: '',
    }, this.secretStore.isAvailable())
  }

  private parseAccounts(value: string): TrackerAccount[] {
    try {
      const parsed = JSON.parse(value) as TrackerAccount[]
      if (!Array.isArray(parsed)) {
        return DEFAULT_TRACKER_ACCOUNTS
      }
      return parsed
    } catch (_error) {
      return DEFAULT_TRACKER_ACCOUNTS
    }
  }

  private parseMappings(value: string): ComicTrackerMapping[] {
    try {
      const parsed = JSON.parse(value) as ComicTrackerMapping[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed
    } catch (_error) {
      return []
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

function parseQuery(uri: string): Record<string, string> {
  const queryStart = uri.indexOf('?')
  if (queryStart < 0) {
    return {}
  }
  const fragmentStart = uri.indexOf('#', queryStart)
  const query = fragmentStart < 0 ? uri.slice(queryStart + 1) : uri.slice(queryStart + 1, fragmentStart)
  const result: Record<string, string> = {}
  query.split('&').forEach((part: string) => {
    const separator = part.indexOf('=')
    const key = separator < 0 ? part : part.slice(0, separator)
    const value = separator < 0 ? '' : part.slice(separator + 1)
    if (key.length > 0) {
      result[decodeURIComponent(key)] = decodeURIComponent(value.replace(/\+/g, ' '))
    }
  })
  return result
}
