import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
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

const REMOTE_SERVER_STORE_NAME: string = 'koma_remote_servers_v1'
const KOMGA_SERVER_KEY: string = 'komga.server'
const KOMGA_CREDENTIAL_KEY: string = 'komga.credential'
const DEFAULT_KOMGA_SERVER_ID: string = 'komga-default'
const DEFAULT_KOMGA_CREDENTIAL_REF: string = 'komga-default-credential'

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

interface StoredKomgaCredential {
  credentialRef: string
  basicToken?: string
  apiKey?: string
  sessionToken?: string
}

export class HarmonyHttpAdapter implements KomgaHttpAdapter {
  async request(request: KomgaHttpRequest): Promise<KomgaHttpResponse> {
    const httpRequest = http.createHttp()
    const startedAt = Date.now()
    try {
      const response = await httpRequest.request(request.url, {
        method: request.method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
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
      console.error(`[Komga] step=http_error code=${e.code} message=${e.message}`)
      throw new Error(e.message)
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
      throw new Error('请输入 Komga Server URL')
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

  createKomgaClient(record: KomgaServerRecord): KomgaClient {
    return new KomgaClient({
      server: record.server,
      credential: record.credential,
      http: new HarmonyHttpAdapter(),
    })
  }

  getKomgaImageHeaders(record: KomgaServerRecord): KomgaHeaders {
    return new KomgaClient({
      server: record.server,
      credential: record.credential,
    }).buildHeaders({ accept: 'image/*' } as KomgaHeaders)
  }

  private createCredential(draft: KomgaServerDraft): KomgaResolvedCredential | undefined {
    if (draft.authKind === KomgaAuthKind.NONE) {
      return undefined
    }
    if (draft.authKind === KomgaAuthKind.API_KEY) {
      const apiKey = draft.apiKey === undefined ? '' : draft.apiKey.trim()
      if (apiKey.length === 0) {
        throw new Error('请输入 API key')
      }
      return {
        credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF,
        apiKey,
      }
    }
    const username = draft.username === undefined ? '' : draft.username.trim()
    const password = draft.password === undefined ? '' : draft.password
    if (username.length === 0 || password.length === 0) {
      throw new Error('请输入用户名和密码')
    }
    return {
      credentialRef: DEFAULT_KOMGA_CREDENTIAL_REF,
      basicToken: buffer.from(`${username}:${password}`, 'utf8').toString('base64'),
    }
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
  }
}
