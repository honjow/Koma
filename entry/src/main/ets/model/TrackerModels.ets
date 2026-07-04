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

export type TrackerCredentialSecretKind = 'access_token' | 'refresh_token' | 'oauth_code_verifier'
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
  autoSyncEnabled: boolean
  updateStrategy: TrackerUpdateStrategy
}

export const TRACKER_PREFERENCES_STORE_NAME: string = 'koma_tracker_preferences_v1'
export const TRACKER_ACCOUNTS_KEY: string = 'tracker.accounts'
export const TRACKER_COMIC_MAPPINGS_KEY: string = 'tracker.comicMappings'
export const TRACKER_AUTO_SYNC_ENABLED_KEY: string = 'tracker.autoSyncEnabled'
export const TRACKER_UPDATE_STRATEGY_KEY: string = 'tracker.updateStrategy'
export const TRACKER_ASSET_ALIAS_PREFIX: string = 'koma.tracker'
export const TRACKER_ASSET_GROUP_ID: string = 'koma-tracker-credentials'
export const TRACKER_OAUTH_STATE_BYTES: number = 32
export const TRACKER_PKCE_VERIFIER_BYTES: number = 32

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
  autoSyncEnabled: false,
  updateStrategy: 'on_chapter_complete',
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

export function createTrackerPkcePair(): TrackerPkcePair {
  const codeVerifier = trackerRandomBase64Url(TRACKER_PKCE_VERIFIER_BYTES)
  return {
    codeVerifier,
    codeChallenge: trackerSha256Base64Url(codeVerifier),
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

function trackerCredentialAlias(ref: TrackerCredentialSecretRef): string {
  return `${TRACKER_ASSET_ALIAS_PREFIX}.${ref.providerId}.${ref.accountKey}.${ref.secretKind}`
}

function trackerAssetQuery(ref: TrackerCredentialSecretRef): asset.AssetMap {
  const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
  query.set(asset.Tag.ALIAS, trackerUtf8Encode(trackerCredentialAlias(ref)))
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

export class AssetStoreTrackerCredentialSecretStore implements TrackerCredentialSecretStore {
  isAvailable(): boolean {
    return true
  }

  async writeToken(request: TrackerCredentialWriteRequest): Promise<TrackerCredentialStoreResult> {
    if (request.secretBytes.byteLength === 0 || request.accountKey.trim().length === 0) {
      return trackerCredentialFailureResult('invalid_request', 'write', request.providerId)
    }
    const attributes = trackerAssetQuery(request)
    attributes.set(asset.Tag.SECRET, request.secretBytes)
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try {
      await asset.add(attributes)
      return trackerCredentialResult(true, 'write', request.providerId)
    } catch (error) {
      return trackerCredentialResult(false, 'write', request.providerId, error as BusinessError)
    }
  }

  async readToken(ref: TrackerCredentialSecretRef): Promise<Uint8Array | undefined> {
    const query = trackerAssetQuery(ref)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    query.set(asset.Tag.RETURN_LIMIT, 1)
    try {
      const rows = await asset.query(query)
      if (rows.length === 0) {
        return undefined
      }
      return rows[0].get(asset.Tag.SECRET) as Uint8Array | undefined
    } catch (_error) {
      return undefined
    }
  }

  async deleteToken(ref: TrackerCredentialSecretRef): Promise<TrackerCredentialStoreResult> {
    try {
      await asset.remove(trackerAssetQuery(ref))
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
    const autoSyncEnabled = await store.get(TRACKER_AUTO_SYNC_ENABLED_KEY, DEFAULT_TRACKER_PREFERENCES.autoSyncEnabled) as boolean
    const updateStrategy = await store.get(TRACKER_UPDATE_STRATEGY_KEY, DEFAULT_TRACKER_PREFERENCES.updateStrategy) as string
    return {
      accounts: mergeTrackerAccounts(this.parseAccounts(accountsJson), this.secretStore.isAvailable()),
      comicMappings: normalizeComicTrackerMappings(this.parseMappings(mappingsJson)),
      autoSyncEnabled: autoSyncEnabled === true,
      updateStrategy: normalizeTrackerUpdateStrategy(updateStrategy),
    }
  }

  async saveAccounts(accounts: TrackerAccount[]): Promise<TrackerPreferences> {
    const current = await this.load()
    const next: TrackerPreferences = {
      accounts: mergeTrackerAccounts(accounts, this.secretStore.isAvailable()),
      comicMappings: current.comicMappings,
      autoSyncEnabled: current.autoSyncEnabled,
      updateStrategy: current.updateStrategy,
    }
    const store = await this.preferences()
    await store.put(TRACKER_ACCOUNTS_KEY, JSON.stringify(next.accounts))
    await store.flush()
    return next
  }

  async disconnectAccount(providerId: TrackerProviderId): Promise<TrackerPreferences> {
    const current = await this.load()
    const account = current.accounts.find((item: TrackerAccount): boolean => item.providerId === providerId)
    if (account === undefined || account.status === 'disconnected') {
      return current
    }
    if (account.credentialAccountKey !== undefined) {
      const deleted = await this.secretStore.deleteAccount({
        providerId,
        accountKey: account.credentialAccountKey,
      })
      if (!deleted.ok) {
        return this.saveAccounts(current.accounts.map((item: TrackerAccount): TrackerAccount => {
          if (item.providerId !== providerId) {
            return item
          }
          return {
            providerId,
            status: 'error',
            statusReason: deleted.error?.code ?? 'storage_unavailable',
          }
        }))
      }
    }
    return this.saveAccounts(current.accounts.map((item: TrackerAccount): TrackerAccount => {
      if (item.providerId !== providerId) {
        return item
      }
      return {
        providerId,
        status: 'disconnected',
      }
    }))
  }

  async saveComicMappings(mappings: ComicTrackerMapping[]): Promise<TrackerPreferences> {
    const current = await this.load()
    const next: TrackerPreferences = {
      accounts: current.accounts,
      comicMappings: normalizeComicTrackerMappings(mappings),
      autoSyncEnabled: current.autoSyncEnabled,
      updateStrategy: current.updateStrategy,
    }
    const store = await this.preferences()
    await store.put(TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify(next.comicMappings))
    await store.flush()
    return next
  }

  async saveSyncPreferences(autoSyncEnabled: boolean, updateStrategy: TrackerUpdateStrategy): Promise<TrackerPreferences> {
    const current = await this.load()
    const next: TrackerPreferences = {
      accounts: current.accounts,
      comicMappings: current.comicMappings,
      autoSyncEnabled,
      updateStrategy: normalizeTrackerUpdateStrategy(updateStrategy),
    }
    const store = await this.preferences()
    await store.put(TRACKER_AUTO_SYNC_ENABLED_KEY, next.autoSyncEnabled)
    await store.put(TRACKER_UPDATE_STRATEGY_KEY, next.updateStrategy)
    await store.flush()
    return next
  }

  async upsertComicMapping(mapping: ComicTrackerMapping): Promise<TrackerPreferences> {
    const current = await this.load()
    const nextMappings = current.comicMappings.filter((item: ComicTrackerMapping): boolean => {
      return item.comicId !== mapping.comicId.trim() || item.providerId !== mapping.providerId
    })
    nextMappings.push(mapping)
    return this.saveComicMappings(nextMappings)
  }

  async listComicMappings(comicId: ComicId): Promise<ComicTrackerMapping[]> {
    const current = await this.load()
    return findComicTrackerMappings(comicId, current.comicMappings)
  }

  async confirmComicMapping(comicId: ComicId, providerId: TrackerProviderId, now: number = Date.now()): Promise<TrackerPreferences> {
    return this.updateComicMappingState(comicId, providerId, 'confirmed', true, now)
  }

  async rejectComicMapping(comicId: ComicId, providerId: TrackerProviderId, now: number = Date.now()): Promise<TrackerPreferences> {
    return this.updateComicMappingState(comicId, providerId, 'rejected', false, now)
  }

  async removeComicMapping(comicId: ComicId, providerId: TrackerProviderId): Promise<TrackerPreferences> {
    const normalizedComicId = comicId.trim()
    const current = await this.load()
    const nextMappings = current.comicMappings.filter((mapping: ComicTrackerMapping): boolean => {
      return mapping.comicId !== normalizedComicId || mapping.providerId !== providerId
    })
    return this.saveComicMappings(nextMappings)
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
      return this.load()
    }
    const current = await this.load()
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
    return this.saveComicMappings(nextMappings)
  }

  async prepareConnect(providerId: TrackerProviderId): Promise<TrackerOAuthStartPreparation> {
    const state = createTrackerOAuthState()
    const pkce = createTrackerPkcePair()
    const preparation = prepareTrackerOAuthStart({
      providerId,
      state,
      codeChallenge: pkce.codeChallenge,
    }, this.secretStore.isAvailable())
    if (preparation.status !== 'ready') {
      return preparation
    }
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
    return preparation
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
