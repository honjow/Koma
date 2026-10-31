import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { buffer, util } from '@kit.ArkTS'
import { asset } from '@kit.AssetStoreKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  KomgaAuthKind,
  KomgaResolvedCredential,
  KomgaServerConfig,
} from '../remote/KomgaModels'
import {
  KomgaClient,
  KomgaHeaders,
  KomgaHttpAdapter,
  KomgaHttpRequest,
  KomgaHttpResponse,
  komgaHeadersToHttpHeaderObject,
  normalizeKomgaBaseUrl,
} from '../remote/KomgaClient'
import {
  KavitaClient,
  KavitaHeaders,
  KavitaHttpAdapter,
  KavitaHttpRequest,
  KavitaHttpResponse,
  kavitaHeadersToHttpHeaderObject,
  normalizeKavitaBaseUrl,
} from '../remote/KavitaClient'
import {
  KavitaResolvedCredential,
  KavitaServerConfig,
} from '../remote/KavitaModels'
import {
  WebDavClient,
  WebDavHeaders,
  WebDavHttpAdapter,
  WebDavHttpRequest,
  WebDavHttpResponse,
  normalizeWebDavBaseUrl,
  webDavHeadersToHttpHeaderObject,
} from '../remote/WebDavClient'
import {
  WebDavAuthKind,
  WebDavResolvedCredential,
  WebDavServerConfig,
} from '../remote/WebDavModels'
import {
  OpdsClient,
  OpdsHeaders,
  OpdsHttpAdapter,
  OpdsHttpRequest,
  OpdsHttpResponse,
  normalizeOpdsRootUrl,
  opdsHeadersToHttpHeaderObject,
} from '../remote/OpdsParser'
import { OpdsVersion } from '../remote/OpdsModels'

const REMOTE_SERVER_STORE_NAME: string = 'koma_remote_servers_v1'
export const REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY: string = 'server.endpoint-identities'
const KOMGA_SERVER_KEY: string = 'komga.server'
const KOMGA_CREDENTIAL_KEY: string = 'komga.credential'
const KAVITA_SERVER_KEY: string = 'kavita.server'
const KAVITA_CREDENTIAL_KEY: string = 'kavita.credential'
const WEBDAV_SERVER_KEY: string = 'webdav.server'
const WEBDAV_CREDENTIAL_KEY: string = 'webdav.credential'
const OPDS_SERVER_KEY: string = 'opds.server'
const OPDS_CREDENTIAL_KEY: string = 'opds.credential'
const DEFAULT_KOMGA_CREDENTIAL_REF: string = 'komga-default-credential'
const DEFAULT_KAVITA_CREDENTIAL_REF: string = 'kavita-default-credential'
const DEFAULT_WEBDAV_CREDENTIAL_REF: string = 'webdav-default-credential'
const DEFAULT_OPDS_CREDENTIAL_REF: string = 'opds-default-credential'
const REMOTE_SERVER_CREDENTIAL_ASSET_GROUP_ID: string = 'koma_remote_server_credentials'
const REMOTE_SERVER_CREDENTIAL_ASSET_ALIAS_PREFIX: string = 'koma.remote-server'

export interface KomgaServerDraft {
  baseUrl: string
  authKind: KomgaAuthKind
  apiKey?: string
  username?: string
  password?: string
  preserveSavedCredentials?: boolean
}

export interface KomgaServerRecord {
  server: KomgaServerConfig
  credential?: KomgaResolvedCredential
}

export interface KavitaServerDraft {
  baseUrl: string
  apiKey?: string
}

export interface KavitaServerRecord {
  server: KavitaServerConfig
  credential: KavitaResolvedCredential
}

export interface WebDavServerDraft {
  baseUrl: string
  username?: string
  password?: string
  rootPath?: string
  preserveSavedCredentials?: boolean
}

export interface WebDavServerRecord {
  server: WebDavServerConfig
  credential?: WebDavResolvedCredential
}

export interface OpdsServerDraft {
  rootUrl: string
  username?: string
  password?: string
  version?: OpdsVersion
  preserveSavedCredentials?: boolean
}

export interface OpdsServerConfig {
  id: string
  name: string
  rootUrl: string
  version?: OpdsVersion
  credentialRef?: string
}

export interface OpdsResolvedCredential {
  credentialRef: string
  basicToken?: string
}

export interface OpdsServerRecord {
  server: OpdsServerConfig
  credential?: OpdsResolvedCredential
}

interface StoredKomgaCredential {
  credentialRef: string
  basicToken?: string
  apiKey?: string
  sessionToken?: string
}

interface StoredKavitaCredential {
  credentialRef: string
  apiKey: string
}

interface StoredWebDavCredential {
  credentialRef: string
  basicToken?: string
}

interface StoredOpdsCredential {
  credentialRef: string
  basicToken?: string
}

export type RemoteServerCredentialKind = 'komga' | 'kavita' | 'webdav' | 'opds'

interface RemoteServerEndpointIdentity {
  kind: RemoteServerCredentialKind
  endpointKey: string
  id: string
}

interface StoredRemoteServerIdentity {
  id: string
  baseUrl?: string
  rootUrl?: string
}

interface PreparedRemoteServerIdentity {
  id: string
  payload: string
}

export function parseRemoteServerEndpointIdentities(json: string): RemoteServerEndpointIdentity[] {
  if (json.length === 0) return []
  const identities = JSON.parse(json) as RemoteServerEndpointIdentity[]
  if (!Array.isArray(identities)) throw new Error('Invalid remote endpoint identities')
  identities.forEach((identity: RemoteServerEndpointIdentity, index: number): void => {
    if (identity === null || typeof identity !== 'object' ||
      !['komga', 'kavita', 'webdav', 'opds'].includes(identity.kind) ||
      typeof identity.endpointKey !== 'string' || !/^[0-9a-f]{64}$/.test(identity.endpointKey) ||
      typeof identity.id !== 'string' || identity.id.length === 0) {
      throw new Error('Invalid remote endpoint identity')
    }
    if (identities.some((other: RemoteServerEndpointIdentity, otherIndex: number): boolean =>
      otherIndex < index && (other.id === identity.id ||
        (other.kind === identity.kind && other.endpointKey === identity.endpointKey)))) {
      throw new Error('Conflicting remote endpoint identities')
    }
  })
  return identities
}

function normalizeRemoteServerEndpoint(kind: RemoteServerCredentialKind, endpoint: string): string {
  if (kind === 'komga') return normalizeKomgaBaseUrl(endpoint)
  if (kind === 'kavita') return normalizeKavitaBaseUrl(endpoint)
  if (kind === 'webdav') return normalizeWebDavBaseUrl(endpoint)
  return normalizeOpdsRootUrl(endpoint)
}

function remoteServerEndpointKey(kind: RemoteServerCredentialKind, endpoint: string): string {
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: remoteCredentialUtf8Encode(normalizeRemoteServerEndpoint(kind, endpoint)) })
  return Array.from(md.digestSync().data).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
}

export function rememberRemoteServerEndpointIdentity(
  identities: RemoteServerEndpointIdentity[],
  kind: RemoteServerCredentialKind,
  payload: string,
): void {
  if (payload.length === 0) return
  const current = JSON.parse(payload) as StoredRemoteServerIdentity
  const rawEndpoint = kind === 'opds' ? current.rootUrl : current.baseUrl
  if (typeof current.id !== 'string' || current.id.length === 0 || typeof rawEndpoint !== 'string') {
    throw new Error('Invalid configured remote identity')
  }
  const endpoint = normalizeRemoteServerEndpoint(kind, rawEndpoint)
  if (endpoint.length === 0) throw new Error('Invalid configured remote endpoint')
  const endpointKey = remoteServerEndpointKey(kind, endpoint)
  const remembered = identities.find((identity: RemoteServerEndpointIdentity): boolean => identity.kind === kind && identity.endpointKey === endpointKey)
  if (remembered !== undefined) {
    if (remembered.id !== current.id) throw new Error('Conflicting configured remote identity')
    return
  }
  if (identities.some((identity: RemoteServerEndpointIdentity): boolean => identity.id === current.id)) {
    throw new Error('Conflicting configured remote endpoint')
  }
  identities.push({ kind, endpointKey, id: current.id })
}

export class RemoteServerDraftError extends Error {
  readonly resourceKey: string

  constructor(resourceKey: string) {
    super(AppStrings.get(resourceKey))
    this.resourceKey = resourceKey
  }
}

export function remoteServerDraftErrorKey(error: Object): string {
  return error instanceof RemoteServerDraftError ? error.resourceKey : ''
}

function remoteCredentialUtf8Encode(value: string): Uint8Array {
  return new Uint8Array(buffer.from(value, 'utf8').buffer)
}

function remoteCredentialUtf8Decode(bytes: Uint8Array): string {
  const exact = new Uint8Array(bytes.byteLength)
  exact.set(bytes)
  return buffer.from(exact.buffer).toString('utf8')
}

function remoteCredentialAssetAlias(kind: RemoteServerCredentialKind, credentialRef: string): string {
  return `${REMOTE_SERVER_CREDENTIAL_ASSET_ALIAS_PREFIX}.${kind}.${credentialRef}`
}

function remoteCredentialAssetIdentity(kind: RemoteServerCredentialKind, credentialRef: string): asset.AssetMap {
  const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
  query.set(asset.Tag.ALIAS, remoteCredentialUtf8Encode(remoteCredentialAssetAlias(kind, credentialRef)))
  query.set(asset.Tag.GROUP_ID, remoteCredentialUtf8Encode(REMOTE_SERVER_CREDENTIAL_ASSET_GROUP_ID))
  return query
}

function remoteCredentialAssetQuery(kind: RemoteServerCredentialKind, credentialRef: string): asset.AssetMap {
  const query = remoteCredentialAssetIdentity(kind, credentialRef)
  query.set(asset.Tag.DATA_LABEL_CRITICAL_1, remoteCredentialUtf8Encode(kind))
  query.set(asset.Tag.DATA_LABEL_CRITICAL_2, remoteCredentialUtf8Encode(credentialRef))
  return query
}

function remoteCredentialFailureCode(error: Object): string {
  const businessError = error as BusinessError
  return businessError.code === undefined ? 'unknown' : `${businessError.code}`
}

export class HarmonyHttpAdapter implements KomgaHttpAdapter {
  async request(request: KomgaHttpRequest): Promise<KomgaHttpResponse> {
    const httpRequest = http.createHttp()
    const startedAt = Date.now()
    try {
      const response = await httpRequest.request(request.url, {
        method: request.method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        customMethod: request.method === 'PATCH' ? 'PATCH' : undefined,
        extraData: request.body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        header: komgaHeadersToHttpHeaderObject(request.headers),
        readTimeout: 60000,
        connectTimeout: 30000,
      })
      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      console.info(`[Komga] step=http status=${response.responseCode} elapsed=${Date.now() - startedAt}`)
      return {
        status: response.responseCode,
        body,
      }
    } catch (error) {
      const e = error as BusinessError
      DiagnosticLogger.error('remote_server_store', 'http_error', `[Komga] step=http_error code=${e.code}`)
      throw new Error(`komga_http_error_${e.code}`)
    } finally {
      httpRequest.destroy()
    }
  }
}

export class KavitaHarmonyHttpAdapter implements KavitaHttpAdapter {
  async request(request: KavitaHttpRequest): Promise<KavitaHttpResponse> {
    const httpRequest = http.createHttp()
    const startedAt = Date.now()
    try {
      const response = await httpRequest.request(request.url, {
        method: request.method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        extraData: request.body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        header: kavitaHeadersToHttpHeaderObject(request.headers),
        readTimeout: 60000,
        connectTimeout: 30000,
      })
      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      console.info(`[Kavita] step=http status=${response.responseCode} elapsed=${Date.now() - startedAt}`)
      return {
        status: response.responseCode,
        body,
      }
    } catch (error) {
      const e = error as BusinessError
      DiagnosticLogger.error('remote_server_store', 'http_error', `[Kavita] step=http_error code=${e.code}`)
      throw new Error(`kavita_http_error_${e.code}`)
    } finally {
      httpRequest.destroy()
    }
  }
}

export class WebDavHarmonyHttpAdapter implements WebDavHttpAdapter {
  async request(request: WebDavHttpRequest): Promise<WebDavHttpResponse> {
    const httpRequest = http.createHttp()
    const startedAt = Date.now()
    try {
      const options: http.HttpRequestOptions = {
        method: request.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.GET,
        customMethod: request.method === 'PROPFIND' ? 'PROPFIND' : undefined,
        extraData: request.body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        header: webDavHeadersToHttpHeaderObject(request.headers),
        readTimeout: 60000,
        connectTimeout: 30000,
      }
      const response = await httpRequest.request(request.url, options)
      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      console.info(`[WebDAV] step=http method=${request.method} status=${response.responseCode} elapsed=${Date.now() - startedAt}`)
      return {
        status: response.responseCode,
        body,
      }
    } catch (error) {
      const e = error as BusinessError
      DiagnosticLogger.error('remote_server_store', 'http_error', `[WebDAV] step=http_error method=${request.method} code=${e.code}`)
      throw new Error(`webdav_http_error_${e.code}`)
    } finally {
      httpRequest.destroy()
    }
  }
}

export class OpdsHarmonyHttpAdapter implements OpdsHttpAdapter {
  async request(request: OpdsHttpRequest): Promise<OpdsHttpResponse> {
    const httpRequest = http.createHttp()
    const startedAt = Date.now()
    try {
      const response = await httpRequest.request(request.url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        header: opdsHeadersToHttpHeaderObject(request.headers),
        readTimeout: 60000,
        connectTimeout: 30000,
      })
      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      const headerObject = response.header as Record<string, Object>
      const contentTypeValue = headerObject['content-type'] ?? headerObject['Content-Type']
      const contentType = typeof contentTypeValue === 'string' ? contentTypeValue : undefined
      console.info(`[OPDS] step=http status=${response.responseCode} elapsed=${Date.now() - startedAt}`)
      return {
        status: response.responseCode,
        body,
        contentType,
      }
    } catch (error) {
      const e = error as BusinessError
      DiagnosticLogger.error('remote_server_store', 'http_error', `[OPDS] step=http_error code=${e.code}`)
      throw new Error(`opds_http_error_${e.code}`)
    } finally {
      httpRequest.destroy()
    }
  }
}

export interface RemoteServerConfigurationSnapshot {
  endpointIdentities: string
  komgaServer: string
  kavitaServer: string
  webDavServer: string
  opdsServer: string
}

interface RemoteServerPreferenceChange {
  key: string
  value?: string
}

interface RemoteServerPreferenceSnapshot {
  key: string
  exists: boolean
  value: preferences.ValueType
}

export class RemoteServerStore {
  private static operations: Map<string, Promise<void>> = new Map<string, Promise<void>>()
  private context: common.Context

  constructor(context: common.Context) {
    this.context = context
  }

  exportConfiguration(): Promise<RemoteServerConfigurationSnapshot> {
    return this.ordered(async (): Promise<RemoteServerConfigurationSnapshot> => {
      const store = await this.preferences()
      return {
        endpointIdentities: await store.get(REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, '') as string,
        komgaServer: await store.get(KOMGA_SERVER_KEY, '') as string,
        kavitaServer: await store.get(KAVITA_SERVER_KEY, '') as string,
        webDavServer: await store.get(WEBDAV_SERVER_KEY, '') as string,
        opdsServer: await store.get(OPDS_SERVER_KEY, '') as string,
      }
    })
  }

  async hasSavedConfiguration(kind: RemoteServerCredentialKind): Promise<boolean> {
    return this.ordered(async (): Promise<boolean> => {
      const store = await this.preferences()
      let key: string = KOMGA_SERVER_KEY
      if (kind === 'kavita') {
        key = KAVITA_SERVER_KEY
      } else if (kind === 'webdav') {
        key = WEBDAV_SERVER_KEY
      } else if (kind === 'opds') {
        key = OPDS_SERVER_KEY
      }
      const payload = await store.get(key, '') as string
      return payload.length > 0
    })
  }

  async loadKomga(): Promise<KomgaServerRecord | undefined> {
    return this.ordered((): Promise<KomgaServerRecord | undefined> => this.readKomga())
  }

  private async readKomga(): Promise<KomgaServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(KOMGA_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as KomgaServerConfig
    if (server.credentialRef === undefined) {
      return { server }
    }
    const credentialPayload = await this.loadSecureCredentialPayload(
      store,
      KOMGA_CREDENTIAL_KEY,
      'komga',
      server.credentialRef,
    )
    if (credentialPayload === undefined) {
      return { server }
    }
    const stored = JSON.parse(credentialPayload) as StoredKomgaCredential
    if (stored === undefined || stored.credentialRef !== server.credentialRef) {
      return { server }
    }
    return {
      server,
      credential: {
        credentialRef: stored.credentialRef,
        basicToken: stored.basicToken,
        apiKey: stored.apiKey,
        sessionToken: stored.sessionToken,
      },
    }
  }

  async saveKomga(draft: KomgaServerDraft): Promise<KomgaServerRecord> {
    return this.ordered(async (): Promise<KomgaServerRecord> => {
      const baseUrl = normalizeKomgaBaseUrl(draft.baseUrl)
      if (baseUrl.length === 0) {
        throw new RemoteServerDraftError('komga_error_missing_server_url')
      }
      const credential = await this.createCredential(draft, baseUrl)
      const store = await this.preferences()
      const identity = await this.prepareServerIdentity(store, KOMGA_SERVER_KEY, 'komga', baseUrl)
      const server: KomgaServerConfig = {
        id: identity.id,
        name: 'Komga',
        baseUrl,
        authKind: draft.authKind,
        credentialRef: draft.authKind === KomgaAuthKind.NONE ? undefined : DEFAULT_KOMGA_CREDENTIAL_REF,
      }
      await this.commitStoredState(store, 'komga', KOMGA_CREDENTIAL_KEY,
        DEFAULT_KOMGA_CREDENTIAL_REF, credential === undefined ? undefined : JSON.stringify(credential), [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: identity.payload },
          { key: KOMGA_SERVER_KEY, value: JSON.stringify(server) },
        ])
      console.info('[Komga] step=save_server')
      return {
        server,
        credential,
      }
    })
  }

  async clearKomga(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await this.preferences()
      const identities = await this.currentServerIdentities(store, KOMGA_SERVER_KEY, 'komga')
      await this.commitStoredState(store, 'komga', KOMGA_CREDENTIAL_KEY,
        DEFAULT_KOMGA_CREDENTIAL_REF, undefined, [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: JSON.stringify(identities) },
          { key: KOMGA_SERVER_KEY },
        ])
      console.info('[Komga] step=clear_server')
    })
  }

  async loadKavita(): Promise<KavitaServerRecord | undefined> {
    return this.ordered((): Promise<KavitaServerRecord | undefined> => this.readKavita())
  }

  private async readKavita(): Promise<KavitaServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(KAVITA_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as KavitaServerConfig
    const credentialPayload = await this.loadSecureCredentialPayload(
      store,
      KAVITA_CREDENTIAL_KEY,
      'kavita',
      server.credentialRef,
    )
    if (credentialPayload === undefined) {
      return undefined
    }
    const stored = JSON.parse(credentialPayload) as StoredKavitaCredential
    if (stored === undefined || stored.credentialRef !== server.credentialRef || stored.apiKey.length === 0) {
      return undefined
    }
    return {
      server,
      credential: {
        credentialRef: stored.credentialRef,
        apiKey: stored.apiKey,
      },
    }
  }

  async saveKavita(draft: KavitaServerDraft): Promise<KavitaServerRecord> {
    return this.ordered(async (): Promise<KavitaServerRecord> => {
      const baseUrl = normalizeKavitaBaseUrl(draft.baseUrl)
      if (baseUrl.length === 0) {
        throw new RemoteServerDraftError('kavita_error_missing_server_url')
      }
      const credential = this.createKavitaCredential(draft)
      const store = await this.preferences()
      const identity = await this.prepareServerIdentity(store, KAVITA_SERVER_KEY, 'kavita', baseUrl)
      const server: KavitaServerConfig = {
        id: identity.id,
        name: 'Kavita',
        baseUrl,
        credentialRef: DEFAULT_KAVITA_CREDENTIAL_REF,
      }
      await this.commitStoredState(store, 'kavita', KAVITA_CREDENTIAL_KEY,
        DEFAULT_KAVITA_CREDENTIAL_REF, credential === undefined ? undefined : JSON.stringify(credential), [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: identity.payload },
          { key: KAVITA_SERVER_KEY, value: JSON.stringify(server) },
        ])
      console.info('[Kavita] step=save_server')
      return {
        server,
        credential,
      }
    })
  }

  async clearKavita(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await this.preferences()
      const identities = await this.currentServerIdentities(store, KAVITA_SERVER_KEY, 'kavita')
      await this.commitStoredState(store, 'kavita', KAVITA_CREDENTIAL_KEY,
        DEFAULT_KAVITA_CREDENTIAL_REF, undefined, [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: JSON.stringify(identities) },
          { key: KAVITA_SERVER_KEY },
        ])
      console.info('[Kavita] step=clear_server')
    })
  }

  async loadWebDav(): Promise<WebDavServerRecord | undefined> {
    return this.ordered((): Promise<WebDavServerRecord | undefined> => this.readWebDav())
  }

  private async readWebDav(): Promise<WebDavServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(WEBDAV_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as WebDavServerConfig
    if (server.credentialRef === undefined) {
      return { server }
    }
    const credentialPayload = await this.loadSecureCredentialPayload(
      store,
      WEBDAV_CREDENTIAL_KEY,
      'webdav',
      server.credentialRef,
    )
    if (credentialPayload === undefined) {
      return { server }
    }
    const stored = JSON.parse(credentialPayload) as StoredWebDavCredential
    if (stored === undefined || stored.credentialRef !== server.credentialRef) {
      return { server }
    }
    return {
      server,
      credential: {
        credentialRef: stored.credentialRef,
        basicToken: stored.basicToken,
      },
    }
  }

  async saveWebDav(draft: WebDavServerDraft): Promise<WebDavServerRecord> {
    return this.ordered(async (): Promise<WebDavServerRecord> => {
      const baseUrl = normalizeWebDavBaseUrl(draft.baseUrl)
      if (baseUrl.length === 0) {
        throw new RemoteServerDraftError('webdav_error_missing_server_url')
      }
      const credential = await this.createWebDavCredential(draft, baseUrl)
      const rootPath = draft.rootPath === undefined ? '' : draft.rootPath.trim()
      const store = await this.preferences()
      const identity = await this.prepareServerIdentity(store, WEBDAV_SERVER_KEY, 'webdav', baseUrl)
      const server: WebDavServerConfig = {
        id: identity.id,
        name: 'WebDAV',
        baseUrl,
        rootPath: rootPath.length === 0 ? undefined : rootPath,
        authKind: credential === undefined ? WebDavAuthKind.NONE : WebDavAuthKind.BASIC,
        credentialRef: credential === undefined ? undefined : DEFAULT_WEBDAV_CREDENTIAL_REF,
      }
      await this.commitStoredState(store, 'webdav', WEBDAV_CREDENTIAL_KEY,
        DEFAULT_WEBDAV_CREDENTIAL_REF, credential === undefined ? undefined : JSON.stringify(credential), [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: identity.payload },
          { key: WEBDAV_SERVER_KEY, value: JSON.stringify(server) },
        ])
      console.info('[WebDAV] step=save_server')
      return {
        server,
        credential,
      }
    })
  }

  async clearWebDav(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await this.preferences()
      const identities = await this.currentServerIdentities(store, WEBDAV_SERVER_KEY, 'webdav')
      await this.commitStoredState(store, 'webdav', WEBDAV_CREDENTIAL_KEY,
        DEFAULT_WEBDAV_CREDENTIAL_REF, undefined, [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: JSON.stringify(identities) },
          { key: WEBDAV_SERVER_KEY },
        ])
      console.info('[WebDAV] step=clear_server')
    })
  }

  async loadOpds(): Promise<OpdsServerRecord | undefined> {
    return this.ordered((): Promise<OpdsServerRecord | undefined> => this.readOpds())
  }

  private async readOpds(): Promise<OpdsServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(OPDS_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as OpdsServerConfig
    if (server.credentialRef === undefined) {
      return { server }
    }
    const credentialPayload = await this.loadSecureCredentialPayload(
      store,
      OPDS_CREDENTIAL_KEY,
      'opds',
      server.credentialRef,
    )
    if (credentialPayload === undefined) {
      return { server }
    }
    const stored = JSON.parse(credentialPayload) as StoredOpdsCredential
    if (stored === undefined || stored.credentialRef !== server.credentialRef) {
      return { server }
    }
    return {
      server,
      credential: {
        credentialRef: stored.credentialRef,
        basicToken: stored.basicToken,
      },
    }
  }

  async saveOpds(draft: OpdsServerDraft): Promise<OpdsServerRecord> {
    return this.ordered(async (): Promise<OpdsServerRecord> => {
      const rootUrl = normalizeOpdsRootUrl(draft.rootUrl)
      if (rootUrl.length === 0) {
        throw new RemoteServerDraftError('opds_error_missing_catalog_url')
      }
      const credential = await this.createOpdsCredential(draft, rootUrl)
      const store = await this.preferences()
      const identity = await this.prepareServerIdentity(store, OPDS_SERVER_KEY, 'opds', rootUrl)
      const server: OpdsServerConfig = {
        id: identity.id,
        name: 'OPDS',
        rootUrl,
        version: draft.version,
        credentialRef: credential === undefined ? undefined : DEFAULT_OPDS_CREDENTIAL_REF,
      }
      await this.commitStoredState(store, 'opds', OPDS_CREDENTIAL_KEY,
        DEFAULT_OPDS_CREDENTIAL_REF, credential === undefined ? undefined : JSON.stringify(credential), [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: identity.payload },
          { key: OPDS_SERVER_KEY, value: JSON.stringify(server) },
        ])
      console.info('[OPDS] step=save_server')
      return {
        server,
        credential,
      }
    })
  }

  async clearOpds(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await this.preferences()
      const identities = await this.currentServerIdentities(store, OPDS_SERVER_KEY, 'opds')
      await this.commitStoredState(store, 'opds', OPDS_CREDENTIAL_KEY,
        DEFAULT_OPDS_CREDENTIAL_REF, undefined, [
          { key: REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, value: JSON.stringify(identities) },
          { key: OPDS_SERVER_KEY },
        ])
      console.info('[OPDS] step=clear_server')
    })
  }

  createKomgaClient(record: KomgaServerRecord): KomgaClient {
    return new KomgaClient({
      server: record.server,
      credential: record.credential,
      http: new HarmonyHttpAdapter(),
    })
  }

  createKavitaClient(record: KavitaServerRecord): KavitaClient {
    return new KavitaClient({
      server: record.server,
      credential: record.credential,
      http: new KavitaHarmonyHttpAdapter(),
    })
  }

  createWebDavClient(record: WebDavServerRecord): WebDavClient {
    return new WebDavClient({
      server: record.server,
      credential: record.credential,
      http: new WebDavHarmonyHttpAdapter(),
    })
  }

  createOpdsClient(record: OpdsServerRecord): OpdsClient {
    return new OpdsClient({
      rootUrl: record.server.rootUrl,
      authorization: this.getOpdsAuthorization(record),
      http: new OpdsHarmonyHttpAdapter(),
    })
  }

  getKomgaImageHeaders(record: KomgaServerRecord): KomgaHeaders {
    return new KomgaClient({
      server: record.server,
      credential: record.credential,
    }).buildHeaders({ accept: 'image/*' } as KomgaHeaders)
  }

  getKavitaImageHeaders(record: KavitaServerRecord): KomgaHeaders {
    const kavitaHeaders: KavitaHeaders = new KavitaClient({
      server: record.server,
      credential: record.credential,
    }).buildHeaders({ accept: 'image/*' } as KavitaHeaders)
    return {
      xApiKey: kavitaHeaders.xApiKey,
      accept: kavitaHeaders.accept,
    } as KomgaHeaders
  }

  getWebDavImageHeaders(record: WebDavServerRecord): KomgaHeaders {
    const webDavHeaders: WebDavHeaders = new WebDavClient({
      server: record.server,
      credential: record.credential,
    }).buildHeaders({ accept: 'image/*' } as WebDavHeaders)
    return {
      authorization: webDavHeaders.authorization,
      accept: webDavHeaders.accept,
    } as KomgaHeaders
  }

  getOpdsImageHeaders(record: OpdsServerRecord): KomgaHeaders {
    const opdsHeaders: OpdsHeaders = new OpdsClient({
      rootUrl: record.server.rootUrl,
      authorization: this.getOpdsAuthorization(record),
    }).buildHeaders('image/*')
    return {
      authorization: opdsHeaders.authorization,
      accept: opdsHeaders.accept,
    } as KomgaHeaders
  }

  private async createCredential(draft: KomgaServerDraft, baseUrl: string): Promise<KomgaResolvedCredential | undefined> {
    if (draft.authKind === KomgaAuthKind.NONE) {
      return undefined
    }
    if (draft.authKind === KomgaAuthKind.API_KEY) {
      const apiKey = draft.apiKey === undefined ? '' : draft.apiKey.trim()
      if (apiKey.length === 0) {
        throw new RemoteServerDraftError('server_error_missing_api_key')
      }
      return {
        credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF,
        apiKey,
      }
    }
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 && password.length === 0 && draft.preserveSavedCredentials === true) {
      const savedToken = await this.preservedBasicToken('komga', baseUrl)
      if (savedToken !== undefined) {
        return { credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF, basicToken: savedToken }
      }
    }
    if (username.length === 0 || password.length === 0) {
      throw new RemoteServerDraftError('server_error_missing_username_password')
    }
    return {
      credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
  }

  private createKavitaCredential(draft: KavitaServerDraft): KavitaResolvedCredential {
    const apiKey = draft.apiKey === undefined ? '' : draft.apiKey.trim()
    if (apiKey.length === 0) {
      throw new RemoteServerDraftError('server_error_missing_api_key')
    }
    return {
      credentialRef: DEFAULT_KAVITA_CREDENTIAL_REF,
      apiKey,
    }
  }

  private async createWebDavCredential(draft: WebDavServerDraft, baseUrl: string): Promise<WebDavResolvedCredential | undefined> {
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 && password.length === 0) {
      if (draft.preserveSavedCredentials === true) {
        const savedToken = await this.preservedBasicToken('webdav', baseUrl)
        if (savedToken !== undefined) {
          return { credentialRef: DEFAULT_WEBDAV_CREDENTIAL_REF, basicToken: savedToken }
        }
      }
      return undefined
    }
    if (username.length === 0 || password.length === 0) {
      throw new RemoteServerDraftError('server_error_missing_username_password')
    }
    return {
      credentialRef: DEFAULT_WEBDAV_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
  }

  private async createOpdsCredential(draft: OpdsServerDraft, rootUrl: string): Promise<OpdsResolvedCredential | undefined> {
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 && password.length === 0) {
      if (draft.preserveSavedCredentials === true) {
        const savedToken = await this.preservedBasicToken('opds', rootUrl)
        if (savedToken !== undefined) {
          return { credentialRef: DEFAULT_OPDS_CREDENTIAL_REF, basicToken: savedToken }
        }
      }
      return undefined
    }
    if (username.length === 0 || password.length === 0) {
      throw new RemoteServerDraftError('server_error_missing_username_password')
    }
    return {
      credentialRef: DEFAULT_OPDS_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
  }

  private async preservedBasicToken(kind: RemoteServerCredentialKind, normalizedUrl: string): Promise<string | undefined> {
    let savedUrl: string = ''
    let token: string | undefined = undefined
    if (kind === 'komga') {
      const saved = await this.readKomga()
      if (saved === undefined || saved.server.authKind !== KomgaAuthKind.BASIC) {
        return undefined
      }
      savedUrl = normalizeKomgaBaseUrl(saved.server.baseUrl)
      token = saved.credential?.basicToken
    } else if (kind === 'webdav') {
      const saved = await this.readWebDav()
      if (saved === undefined || saved.server.authKind !== WebDavAuthKind.BASIC) {
        return undefined
      }
      savedUrl = normalizeWebDavBaseUrl(saved.server.baseUrl)
      token = saved.credential?.basicToken
    } else if (kind === 'opds') {
      const saved = await this.readOpds()
      if (saved === undefined || saved.server.credentialRef === undefined) {
        return undefined
      }
      savedUrl = normalizeOpdsRootUrl(saved.server.rootUrl)
      token = saved.credential?.basicToken
    }
    if (savedUrl !== normalizedUrl || token === undefined || token.length === 0) {
      throw new RemoteServerDraftError('server_error_reenter_credentials')
    }
    return token
  }

  private getOpdsAuthorization(record: OpdsServerRecord): string | undefined {
    if (record.server.credentialRef === undefined) {
      return undefined
    }
    if (record.credential === undefined || record.credential.basicToken === undefined || record.credential.basicToken.length === 0) {
      throw new Error('OPDS Basic credential token is required')
    }
    return `Basic ${record.credential.basicToken}`
  }

  private async loadSecureCredentialPayload(
    store: preferences.Preferences,
    legacyKey: string,
    kind: RemoteServerCredentialKind,
    credentialRef: string,
  ): Promise<string | undefined> {
    const secure = await this.readCredentialAssetPayload(kind, credentialRef)
    if (secure !== undefined) {
      return secure
    }
    const legacyPayload = await store.get(legacyKey, '') as string
    if (legacyPayload.length === 0) {
      return undefined
    }
    const legacyCredential = JSON.parse(legacyPayload) as StoredKomgaCredential
    if (legacyCredential.credentialRef !== credentialRef) {
      return undefined
    }
    try {
      await this.commitStoredState(store, kind, legacyKey, credentialRef, legacyPayload, [])
      console.info(`[RemoteServerStore] step=credential_migrated provider=${kind}`)
    } catch (error) {
      DiagnosticLogger.warn('remote_server_store', 'credential_migration_failed', `[RemoteServerStore] step=credential_migration_failed provider=${kind} code=${remoteCredentialFailureCode(error as Object)}`)
    }
    return legacyPayload
  }

  // One owner for the shared endpoint ledger, configuration, legacy values and secure assets.
  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    return BackupRestoreActivity.runWrite((): Promise<T> => {
      const key = this.context.filesDir
      const previous = RemoteServerStore.operations.get(key) ?? Promise.resolve()
      const result = previous.then(operation)
      const settled = result.then((): void => {}, (): void => {})
      RemoteServerStore.operations.set(key, settled)
      void settled.then((): void => {
        if (RemoteServerStore.operations.get(key) === settled) RemoteServerStore.operations.delete(key)
      })
      return result
    })
  }

  private async commitStoredState(
    store: preferences.Preferences,
    kind: RemoteServerCredentialKind,
    legacyKey: string,
    credentialRef: string,
    credentialPayload: string | undefined,
    changes: RemoteServerPreferenceChange[],
  ): Promise<void> {
    const keys = changes.map((change: RemoteServerPreferenceChange): string => change.key).concat([legacyKey])
    const before: RemoteServerPreferenceSnapshot[] = []
    for (const key of keys) {
      before.push({ key, exists: await store.has(key), value: await store.get(key, '') })
    }
    const previousCredential = await this.readCredentialAssetPayload(kind, credentialRef)
    try {
      await this.saveSecureCredential(store, legacyKey, kind, credentialRef, credentialPayload)
      for (const change of changes) {
        if (change.value === undefined) await store.delete(change.key)
        else await store.put(change.key, change.value)
      }
      await store.flush()
    } catch (error) {
      let restoreFailed = false
      try {
        if (previousCredential === undefined) await this.deleteCredentialAsset(kind, credentialRef)
        else await this.writeCredentialAsset(kind, credentialRef, previousCredential)
      } catch (restoreError) {
        restoreFailed = true
      }
      for (const value of before) {
        try {
          if (value.exists) await store.put(value.key, value.value)
          else await store.delete(value.key)
        } catch (restoreError) {
          restoreFailed = true
        }
      }
      try {
        await store.flush()
      } catch (restoreError) {
        restoreFailed = true
      }
      if (restoreFailed) {
        DiagnosticLogger.error('remote_server_store', 'state_restore_failed', `[RemoteServerStore] step=state_restore_failed provider=${kind}`)
        throw new Error('remote_server_state_restore_failed')
      }
      throw error as Error
    }
  }

  private async saveSecureCredential(
    store: preferences.Preferences,
    legacyKey: string,
    kind: RemoteServerCredentialKind,
    credentialRef: string,
    credentialPayload: string | undefined,
  ): Promise<void> {
    if (credentialPayload === undefined) {
      await this.deleteCredentialAsset(kind, credentialRef)
      await store.delete(legacyKey)
      return
    }
    await this.writeCredentialAsset(kind, credentialRef, credentialPayload)
    await store.delete(legacyKey)
  }

  private async writeCredentialAsset(
    kind: RemoteServerCredentialKind,
    credentialRef: string,
    payload: string,
  ): Promise<void> {
    const attributes = remoteCredentialAssetQuery(kind, credentialRef)
    attributes.set(asset.Tag.SECRET, remoteCredentialUtf8Encode(payload))
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try {
      await asset.add(attributes)
    } catch (error) {
      DiagnosticLogger.warn('remote_server_store', 'credential_write_failed', `[RemoteServerStore] step=credential_write_failed provider=${kind} code=${remoteCredentialFailureCode(error as Object)}`)
      throw new Error('remote_server_credential_write_failed')
    }
  }

  private async readCredentialAssetPayload(
    kind: RemoteServerCredentialKind,
    credentialRef: string,
  ): Promise<string | undefined> {
    const query = remoteCredentialAssetQuery(kind, credentialRef)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    query.set(asset.Tag.RETURN_LIMIT, 1)
    try {
      const rows = await asset.query(query)
      if (rows.length === 0) {
        return undefined
      }
      const secret = rows[0].get(asset.Tag.SECRET) as Uint8Array | undefined
      if (secret === undefined || secret.byteLength === 0) {
        throw new Error('remote_server_credential_read_failed')
      }
      return remoteCredentialUtf8Decode(secret)
    } catch (error) {
      if ((error as BusinessError).code === 24000002) return undefined
      DiagnosticLogger.warn('remote_server_store', 'credential_read_failed', `[RemoteServerStore] step=credential_read_failed provider=${kind} code=${remoteCredentialFailureCode(error as Object)}`)
      throw new Error('remote_server_credential_read_failed')
    }
  }

  private async deleteCredentialAsset(kind: RemoteServerCredentialKind, credentialRef: string): Promise<void> {
    try {
      await asset.remove(remoteCredentialAssetIdentity(kind, credentialRef))
    } catch (error) {
      if ((error as BusinessError).code === 24000002) return
      DiagnosticLogger.warn('remote_server_store', 'credential_delete_failed', `[RemoteServerStore] step=credential_delete_failed provider=${kind} code=${remoteCredentialFailureCode(error as Object)}`)
      throw new Error('remote_server_credential_delete_failed')
    }
  }

  private async currentServerIdentities(
    store: preferences.Preferences,
    serverKey: string,
    kind: RemoteServerCredentialKind,
  ): Promise<RemoteServerEndpointIdentity[]> {
    const identities = parseRemoteServerEndpointIdentities(await store.get(REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, '') as string)
    const payload = await store.get(serverKey, '') as string
    rememberRemoteServerEndpointIdentity(identities, kind, payload)
    return identities
  }

  private async prepareServerIdentity(
    store: preferences.Preferences,
    serverKey: string,
    kind: RemoteServerCredentialKind,
    endpoint: string,
  ): Promise<PreparedRemoteServerIdentity> {
    const identities = await this.currentServerIdentities(store, serverKey, kind)
    const endpointKey = remoteServerEndpointKey(kind, endpoint)
    let selected = identities.find((identity: RemoteServerEndpointIdentity): boolean => identity.kind === kind && identity.endpointKey === endpointKey)
    if (selected === undefined) {
      selected = { kind, endpointKey, id: `${kind}-${util.generateRandomUUID()}` }
      identities.push(selected)
    }
    return { id: selected.id, payload: JSON.stringify(identities) }
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
  }
}
