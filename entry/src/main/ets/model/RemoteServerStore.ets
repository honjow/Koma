import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { buffer } from '@kit.ArkTS'
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
const KOMGA_SERVER_KEY: string = 'komga.server'
const KOMGA_CREDENTIAL_KEY: string = 'komga.credential'
const WEBDAV_SERVER_KEY: string = 'webdav.server'
const WEBDAV_CREDENTIAL_KEY: string = 'webdav.credential'
const OPDS_SERVER_KEY: string = 'opds.server'
const OPDS_CREDENTIAL_KEY: string = 'opds.credential'
const DEFAULT_KOMGA_SERVER_ID: string = 'komga-default'
const DEFAULT_KOMGA_CREDENTIAL_REF: string = 'komga-default-credential'
const DEFAULT_WEBDAV_SERVER_ID: string = 'webdav-default'
const DEFAULT_WEBDAV_CREDENTIAL_REF: string = 'webdav-default-credential'
const DEFAULT_OPDS_SERVER_ID: string = 'opds-default'
const DEFAULT_OPDS_CREDENTIAL_REF: string = 'opds-default-credential'

export interface KomgaServerDraft {
  baseUrl: string
  authKind: KomgaAuthKind
  apiKey?: string
  username?: string
  password?: string
}

export interface KomgaServerRecord {
  server: KomgaServerConfig
  credential?: KomgaResolvedCredential
}

export interface WebDavServerDraft {
  baseUrl: string
  username?: string
  password?: string
  rootPath?: string
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

interface StoredWebDavCredential {
  credentialRef: string
  basicToken?: string
}

interface StoredOpdsCredential {
  credentialRef: string
  basicToken?: string
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
      console.error(`[Komga] step=http_error code=${e.code}`)
      throw new Error(`komga_http_error_${e.code}`)
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
      console.error(`[WebDAV] step=http_error method=${request.method} code=${e.code}`)
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
      console.error(`[OPDS] step=http_error code=${e.code}`)
      throw new Error(`opds_http_error_${e.code}`)
    } finally {
      httpRequest.destroy()
    }
  }
}

export class RemoteServerStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async loadKomga(): Promise<KomgaServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(KOMGA_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as KomgaServerConfig
    const credentialPayload = await store.get(KOMGA_CREDENTIAL_KEY, '') as string
    if (credentialPayload.length === 0 || server.credentialRef === undefined) {
      return { server }
    }
    const stored = JSON.parse(credentialPayload) as StoredKomgaCredential
    if (stored.credentialRef !== server.credentialRef) {
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
    const baseUrl = normalizeKomgaBaseUrl(draft.baseUrl)
    if (baseUrl.length === 0) {
      throw new Error(AppStrings.get('komga_error_missing_server_url'))
    }
    const credential = this.createCredential(draft)
    const server: KomgaServerConfig = {
      id: DEFAULT_KOMGA_SERVER_ID,
      name: 'Komga',
      baseUrl,
      authKind: draft.authKind,
      credentialRef: draft.authKind === KomgaAuthKind.NONE ? undefined : DEFAULT_KOMGA_CREDENTIAL_REF,
    }
    const store = await this.preferences()
    await store.put(KOMGA_SERVER_KEY, JSON.stringify(server))
    if (credential === undefined) {
      await store.delete(KOMGA_CREDENTIAL_KEY)
    } else {
      await store.put(KOMGA_CREDENTIAL_KEY, JSON.stringify(credential))
    }
    await store.flush()
    console.info('[Komga] step=save_server')
    return {
      server,
      credential,
    }
  }

  async clearKomga(): Promise<void> {
    const store = await this.preferences()
    await store.delete(KOMGA_SERVER_KEY)
    await store.delete(KOMGA_CREDENTIAL_KEY)
    await store.flush()
    console.info('[Komga] step=clear_server')
  }

  async loadWebDav(): Promise<WebDavServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(WEBDAV_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as WebDavServerConfig
    const credentialPayload = await store.get(WEBDAV_CREDENTIAL_KEY, '') as string
    if (credentialPayload.length === 0 || server.credentialRef === undefined) {
      return { server }
    }
    const stored = JSON.parse(credentialPayload) as StoredWebDavCredential
    if (stored.credentialRef !== server.credentialRef) {
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
    const baseUrl = normalizeWebDavBaseUrl(draft.baseUrl)
    if (baseUrl.length === 0) {
      throw new Error(AppStrings.get('webdav_error_missing_server_url'))
    }
    const credential = this.createWebDavCredential(draft)
    const rootPath = draft.rootPath === undefined ? '' : draft.rootPath.trim()
    const server: WebDavServerConfig = {
      id: DEFAULT_WEBDAV_SERVER_ID,
      name: 'WebDAV',
      baseUrl,
      rootPath: rootPath.length === 0 ? undefined : rootPath,
      authKind: credential === undefined ? WebDavAuthKind.NONE : WebDavAuthKind.BASIC,
      credentialRef: credential === undefined ? undefined : DEFAULT_WEBDAV_CREDENTIAL_REF,
    }
    const store = await this.preferences()
    await store.put(WEBDAV_SERVER_KEY, JSON.stringify(server))
    if (credential === undefined) {
      await store.delete(WEBDAV_CREDENTIAL_KEY)
    } else {
      await store.put(WEBDAV_CREDENTIAL_KEY, JSON.stringify(credential))
    }
    await store.flush()
    console.info('[WebDAV] step=save_server')
    return {
      server,
      credential,
    }
  }

  async clearWebDav(): Promise<void> {
    const store = await this.preferences()
    await store.delete(WEBDAV_SERVER_KEY)
    await store.delete(WEBDAV_CREDENTIAL_KEY)
    await store.flush()
    console.info('[WebDAV] step=clear_server')
  }

  async loadOpds(): Promise<OpdsServerRecord | undefined> {
    const store = await this.preferences()
    const serverPayload = await store.get(OPDS_SERVER_KEY, '') as string
    if (serverPayload.length === 0) {
      return undefined
    }
    const server = JSON.parse(serverPayload) as OpdsServerConfig
    const credentialPayload = await store.get(OPDS_CREDENTIAL_KEY, '') as string
    if (credentialPayload.length === 0 || server.credentialRef === undefined) {
      return { server }
    }
    const stored = JSON.parse(credentialPayload) as StoredOpdsCredential
    if (stored.credentialRef !== server.credentialRef) {
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
    const rootUrl = normalizeOpdsRootUrl(draft.rootUrl)
    if (rootUrl.length === 0) {
      throw new Error(AppStrings.get('opds_error_missing_catalog_url'))
    }
    const credential = this.createOpdsCredential(draft)
    const server: OpdsServerConfig = {
      id: DEFAULT_OPDS_SERVER_ID,
      name: 'OPDS',
      rootUrl,
      version: draft.version,
      credentialRef: credential === undefined ? undefined : DEFAULT_OPDS_CREDENTIAL_REF,
    }
    const store = await this.preferences()
    await store.put(OPDS_SERVER_KEY, JSON.stringify(server))
    if (credential === undefined) {
      await store.delete(OPDS_CREDENTIAL_KEY)
    } else {
      await store.put(OPDS_CREDENTIAL_KEY, JSON.stringify(credential))
    }
    await store.flush()
    console.info('[OPDS] step=save_server')
    return {
      server,
      credential,
    }
  }

  async clearOpds(): Promise<void> {
    const store = await this.preferences()
    await store.delete(OPDS_SERVER_KEY)
    await store.delete(OPDS_CREDENTIAL_KEY)
    await store.flush()
    console.info('[OPDS] step=clear_server')
  }

  createKomgaClient(record: KomgaServerRecord): KomgaClient {
    return new KomgaClient({
      server: record.server,
      credential: record.credential,
      http: new HarmonyHttpAdapter(),
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

  private createCredential(draft: KomgaServerDraft): KomgaResolvedCredential | undefined {
    if (draft.authKind === KomgaAuthKind.NONE) {
      return undefined
    }
    if (draft.authKind === KomgaAuthKind.API_KEY) {
      const apiKey = draft.apiKey === undefined ? '' : draft.apiKey.trim()
      if (apiKey.length === 0) {
        throw new Error(AppStrings.get('server_error_missing_api_key'))
      }
      return {
        credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF,
        apiKey,
      }
    }
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 || password.length === 0) {
      throw new Error(AppStrings.get('server_error_missing_username_password'))
    }
    return {
      credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
  }

  private createWebDavCredential(draft: WebDavServerDraft): WebDavResolvedCredential | undefined {
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 && password.length === 0) {
      return undefined
    }
    if (username.length === 0 || password.length === 0) {
      throw new Error(AppStrings.get('server_error_missing_username_password'))
    }
    return {
      credentialRef: DEFAULT_WEBDAV_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
  }

  private createOpdsCredential(draft: OpdsServerDraft): OpdsResolvedCredential | undefined {
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 && password.length === 0) {
      return undefined
    }
    if (username.length === 0 || password.length === 0) {
      throw new Error(AppStrings.get('server_error_missing_username_password'))
    }
    return {
      credentialRef: DEFAULT_OPDS_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
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

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
  }
}
