import { http } from '@kit.NetworkKit'
import { TrackerProviderId } from './TrackerModels'

export type TrackerJsonMethod = 'GET' | 'POST' | 'PUT' | 'PATCH'
export interface TrackerJsonRequest {
  method: TrackerJsonMethod
  url: string
  token?: string
  body?: string
  contentType?: string
}
export interface TrackerJsonResponse { status: number; body: string }
export interface TrackerJsonAdapter { request(request: TrackerJsonRequest): Promise<TrackerJsonResponse> }
export interface RemoteTrackerResult<T> {
  ok: boolean
  value?: T
  errorCode?: 'auth_required' | 'unauthorized' | 'not_found' | 'rate_limited' | 'provider_error' | 'network_error' | 'malformed_response'
}
export interface RemoteTrackerProfile {
  providerId: TrackerProviderId
  providerUserId: string
  username: string
  displayName?: string
}
export interface RemoteTrackerTitle {
  providerId: TrackerProviderId
  providerTitleId: string
  title: string
  nativeTitle?: string
}
export interface RemoteTrackerProgress {
  providerId: TrackerProviderId
  providerTitleId: string
  progress: number
  completed: boolean
  status?: string
}
export interface RemoteTrackerLogin {
  token: string
  profile: RemoteTrackerProfile
}

export class HarmonyTrackerJsonAdapter implements TrackerJsonAdapter {
  async request(request: TrackerJsonRequest): Promise<TrackerJsonResponse> {
    const client = http.createHttp()
    const headers: Record<string, string> = {
      'Accept': 'application/json', 'Content-Type': request.contentType ?? 'application/json',
      'User-Agent': 'Koma/0.1 (https://github.com/honjow/Koma)',
    }
    if (request.token !== undefined && request.token.length > 0) headers['Authorization'] = `Bearer ${request.token}`
    try {
      const response = await client.request(request.url, {
        method: request.method === 'GET' ? http.RequestMethod.GET :
          request.method === 'PUT' ? http.RequestMethod.PUT : http.RequestMethod.POST,
        customMethod: request.method === 'PATCH' ? 'PATCH' : undefined,
        extraData: request.body ?? '', header: headers, expectDataType: http.HttpDataType.STRING,
        usingCache: false, connectTimeout: 15000, readTimeout: 30000,
      })
      return { status: response.responseCode,
        body: typeof response.result === 'string' ? response.result : JSON.stringify(response.result) }
    } finally { client.destroy() }
  }
}

export class TrackerJsonClient {
  private adapter: TrackerJsonAdapter
  private baseUrl: string
  constructor(adapter: TrackerJsonAdapter, baseUrl: string) { this.adapter = adapter; this.baseUrl = baseUrl }

  protected async send<T>(method: TrackerJsonMethod, path: string, token?: string,
    payload?: Object): Promise<RemoteTrackerResult<T>> {
    return this.sendRequest<T>({ method, url: this.baseUrl + path, token,
      body: payload === undefined ? undefined : JSON.stringify(payload) })
  }

  protected async sendForm<T>(path: string, fields: Record<string, string>): Promise<RemoteTrackerResult<T>> {
    return this.sendRequest<T>({ method: 'POST', url: this.baseUrl + path,
      contentType: 'application/x-www-form-urlencoded',
      body: Object.keys(fields).map((key: string): string =>
        `${encodeURIComponent(key)}=${encodeURIComponent(fields[key])}`).join('&') })
  }

  private async sendRequest<T>(request: TrackerJsonRequest): Promise<RemoteTrackerResult<T>> {
    try {
      const response = await this.adapter.request(request)
      if (response.status < 200 || response.status >= 300) {
        return { ok: false, errorCode: response.status === 401 || response.status === 403 ? 'unauthorized' :
          response.status === 404 ? 'not_found' : response.status === 429 ? 'rate_limited' : 'provider_error' }
      }
      if (response.body.trim().length === 0) return { ok: true }
      try { return { ok: true, value: JSON.parse(response.body) as T } }
      catch (_) { return { ok: false, errorCode: 'malformed_response' } }
    } catch (_) { return { ok: false, errorCode: 'network_error' } }
  }
}

interface BangumiSearchFilter { type: number[] }
interface BangumiSearchRequest { keyword: string; sort: string; filter: BangumiSearchFilter }
interface BangumiCollectionWrite { type?: number; ep_status: number }
interface BangumiUser { id?: number; username?: string; nickname?: string }
interface BangumiSubject { id?: number; name?: string; name_cn?: string; platform?: string }
interface BangumiSearch { data?: BangumiSubject[] }
interface BangumiCollection { type?: number; ep_status?: number }

/** Official v0 API. Personal tokens avoid embedding another application's OAuth secret. */
export class BangumiTrackerClient extends TrackerJsonClient {
  constructor(adapter: TrackerJsonAdapter = new HarmonyTrackerJsonAdapter()) { super(adapter, 'https://api.bgm.tv') }

  async fetchProfile(token: string): Promise<RemoteTrackerResult<RemoteTrackerProfile>> {
    if (token.trim().length === 0) return { ok: false, errorCode: 'auth_required' }
    const result = await this.send<BangumiUser>('GET', '/v0/me', token)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if (!result.value?.id || !result.value.username) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: { providerId: 'bangumi', providerUserId: `${result.value.id}`,
      username: result.value.username, displayName: result.value.nickname } }
  }

  async searchManga(token: string, query: string): Promise<RemoteTrackerResult<RemoteTrackerTitle[]>> {
    if (query.trim().length === 0) return { ok: true, value: [] }
    const body: BangumiSearchRequest = { keyword: query.trim().slice(0, 120), sort: 'match', filter: { type: [1] } }
    const result = await this.send<BangumiSearch>('POST', '/v0/search/subjects?limit=20', token, body)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if (!Array.isArray(result.value?.data)) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: result.value!.data!.filter((item: BangumiSubject): boolean =>
      Number.isSafeInteger(item.id) && (item.id ?? 0) > 0 && (item.name?.length ?? 0) > 0 &&
      (!item.platform || item.platform === '漫画')).map((item: BangumiSubject): RemoteTrackerTitle => ({
        providerId: 'bangumi', providerTitleId: `${item.id}`, title: item.name!, nativeTitle: item.name_cn,
      })) }
  }

  async fetchProgress(token: string, id: string): Promise<RemoteTrackerResult<RemoteTrackerProgress | undefined>> {
    if (!/^\d+$/.test(id)) return { ok: false, errorCode: 'not_found' }
    const result = await this.send<BangumiCollection>('GET', `/v0/users/-/collections/${id}`, token)
    if (!result.ok) return result.errorCode === 'not_found' ? { ok: true } : { ok: false, errorCode: result.errorCode }
    if (!Number.isSafeInteger(result.value?.type) || !Number.isFinite(result.value?.ep_status)) {
      return { ok: false, errorCode: 'malformed_response' }
    }
    return { ok: true, value: { providerId: 'bangumi', providerTitleId: id,
      progress: Math.max(0, result.value!.ep_status!), completed: result.value!.type === 2,
      status: `${result.value!.type}` } }
  }

  async pushProgress(token: string, id: string, progress: number): Promise<RemoteTrackerResult<RemoteTrackerProgress>> {
    const before = await this.fetchProgress(token, id)
    if (!before.ok) return { ok: false, errorCode: before.errorCode }
    const count = Math.max(0, Math.floor(progress))
    // Existing collection privacy, score, tags and state are not rewritten by reading progress.
    const body: BangumiCollectionWrite = { ep_status: count }
    if (before.value === undefined) body.type = 3
    const result = await this.send<Object>(before.value === undefined ? 'POST' : 'PATCH',
      `/v0/users/-/collections/${id}`, token, body)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const saved = await this.fetchProgress(token, id)
    if (!saved.ok || saved.value === undefined) return { ok: false, errorCode: saved.errorCode ?? 'malformed_response' }
    return { ok: true, value: saved.value }
  }
}

interface MangaUpdatesLoginRequest { username: string; password: string }
interface MangaUpdatesSearchRequest { search: string; filter_types: string[] }
interface MangaUpdatesUser { username?: string }
interface MangaUpdatesLoginContext { session_token?: string; uid?: number }
interface MangaUpdatesLoginResponse { context?: MangaUpdatesLoginContext }
interface MangaUpdatesRecord { series_id?: number; title?: string }
interface MangaUpdatesSearchItem { record?: MangaUpdatesRecord }
interface MangaUpdatesSearch { results?: MangaUpdatesSearchItem[] }
interface MangaUpdatesStatus { chapter?: number }
interface MangaUpdatesListItem { list_id?: number; status?: MangaUpdatesStatus }
interface MangaUpdatesSeriesRef { id: number }
interface MangaUpdatesListWrite { series: MangaUpdatesSeriesRef; list_id: number; status?: MangaUpdatesStatus }

export class MangaUpdatesTrackerClient extends TrackerJsonClient {
  constructor(adapter: TrackerJsonAdapter = new HarmonyTrackerJsonAdapter()) { super(adapter, 'https://api.mangaupdates.com/v1') }

  async login(username: string, password: string): Promise<RemoteTrackerResult<RemoteTrackerLogin>> {
    if (username.trim().length === 0 || password.length === 0) return { ok: false, errorCode: 'auth_required' }
    const body: MangaUpdatesLoginRequest = { username: username.trim(), password }
    const result = await this.send<MangaUpdatesLoginResponse>('PUT', '/account/login', undefined, body)
    const token = result.value?.context?.session_token
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if (!token || !Number.isSafeInteger(result.value?.context?.uid)) return { ok: false, errorCode: 'malformed_response' }
    const profile = await this.fetchProfile(token)
    if (!profile.ok || profile.value === undefined) return { ok: false, errorCode: profile.errorCode }
    profile.value.providerUserId = `${result.value!.context!.uid}`
    return { ok: true, value: { token, profile: profile.value } }
  }

  async fetchProfile(token: string): Promise<RemoteTrackerResult<RemoteTrackerProfile>> {
    if (token.trim().length === 0) return { ok: false, errorCode: 'auth_required' }
    const result = await this.send<MangaUpdatesUser>('GET', '/account/profile', token)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if (!result.value?.username) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: { providerId: 'mangaupdates', providerUserId: result.value.username,
      username: result.value.username, displayName: result.value.username } }
  }

  async searchManga(token: string, query: string): Promise<RemoteTrackerResult<RemoteTrackerTitle[]>> {
    if (query.trim().length === 0) return { ok: true, value: [] }
    const body: MangaUpdatesSearchRequest = { search: query.trim().slice(0, 120), filter_types: ['drama cd', 'novel'] }
    const result = await this.send<MangaUpdatesSearch>('POST', '/series/search', token, body)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if (!Array.isArray(result.value?.results)) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: result.value!.results!.filter((item: MangaUpdatesSearchItem): boolean =>
      Number.isSafeInteger(item.record?.series_id) && (item.record?.series_id ?? 0) > 0 &&
      (item.record?.title?.length ?? 0) > 0).map((item: MangaUpdatesSearchItem): RemoteTrackerTitle => ({
        providerId: 'mangaupdates', providerTitleId: `${item.record!.series_id}`, title: item.record!.title!,
      })) }
  }

  async fetchProgress(token: string, id: string): Promise<RemoteTrackerResult<RemoteTrackerProgress | undefined>> {
    if (!/^\d+$/.test(id) || !Number.isSafeInteger(Number(id))) return { ok: false, errorCode: 'not_found' }
    const result = await this.send<MangaUpdatesListItem>('GET', `/lists/series/${id}`, token)
    if (!result.ok) return result.errorCode === 'not_found' ? { ok: true } : { ok: false, errorCode: result.errorCode }
    if (!Number.isSafeInteger(result.value?.list_id)) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: { providerId: 'mangaupdates', providerTitleId: id,
      progress: Math.max(0, result.value!.status?.chapter ?? 0), completed: result.value!.list_id === 2,
      status: `${result.value!.list_id}` } }
  }

  async pushProgress(token: string, id: string, progress: number): Promise<RemoteTrackerResult<RemoteTrackerProgress>> {
    const before = await this.fetchProgress(token, id)
    if (!before.ok) return { ok: false, errorCode: before.errorCode }
    const count = Math.max(0, Math.floor(progress))
    const write: MangaUpdatesListWrite = { series: { id: Number(id) },
      list_id: before.value === undefined ? (count > 0 ? 0 : 1) : Number(before.value.status) }
    if (before.value === undefined) {
      const added = await this.send<Object>('POST', '/lists/series', token, [write])
      if (!added.ok) return { ok: false, errorCode: added.errorCode }
    }
    write.status = { chapter: count }
    const result = await this.send<Object>('POST', '/lists/series/update', token, [write])
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const saved = await this.fetchProgress(token, id)
    if (!saved.ok || saved.value === undefined) return { ok: false, errorCode: saved.errorCode ?? 'malformed_response' }
    return { ok: true, value: saved.value }
  }
}
