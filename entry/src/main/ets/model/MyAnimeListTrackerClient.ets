import { http } from '@kit.NetworkKit'
import { TrackerProviderId } from './TrackerModels'

export type MyAnimeListTrackerErrorCode =
  'auth_required' |
  'unauthorized' |
  'rate_limited' |
  'network_error' |
  'provider_error' |
  'malformed_response' |
  'not_found'

export type MyAnimeListTrackerHttpMethod = 'GET' | 'PUT'

export interface MyAnimeListTrackerHeaders {
  authorization?: string
  accept?: string
  contentType?: string
}

export interface MyAnimeListTrackerHttpRequest {
  method: MyAnimeListTrackerHttpMethod
  url: string
  headers: MyAnimeListTrackerHeaders
  body?: string
}

export interface RedactedMyAnimeListTrackerHttpRequest {
  method: MyAnimeListTrackerHttpMethod
  url: string
  headers: MyAnimeListTrackerHeaders
  body?: string
}

export interface MyAnimeListTrackerHttpResponse {
  status: number
  body: string
}

export interface MyAnimeListTrackerHttpAdapter {
  request(request: MyAnimeListTrackerHttpRequest): Promise<MyAnimeListTrackerHttpResponse>
}

export interface MyAnimeListTrackerResult<T> {
  ok: boolean
  value?: T
  errorCode?: MyAnimeListTrackerErrorCode
}

export interface MyAnimeListTrackerProfile {
  providerId: TrackerProviderId
  providerUserId: string
  username: string
  displayName?: string
}

export interface MyAnimeListTrackerTitleSearchResult {
  providerId: TrackerProviderId
  providerTitleId: string
  title: string
  nativeTitle?: string
  format?: string
  status?: string
  coverImageUrl?: string
}

export interface MyAnimeListTrackerProgress {
  providerId: TrackerProviderId
  providerTitleId: string
  progress: number
  completed: boolean
  status?: string
  updatedAt?: number
}

interface MyAnimeListQueryParams {
  q?: string
  fields?: string
  limit?: string
  offset?: string
}

interface MyAnimeListProfileDto {
  id?: number
  name?: string
}

interface MyAnimeListPictureDto {
  medium?: string
  large?: string
}

interface MyAnimeListAlternativeTitlesDto {
  en?: string
  ja?: string
}

interface MyAnimeListMangaNodeDto {
  id?: number
  title?: string
  main_picture?: MyAnimeListPictureDto
  media_type?: string
  status?: string
  alternative_titles?: MyAnimeListAlternativeTitlesDto
}

interface MyAnimeListMangaSearchItemDto {
  node?: MyAnimeListMangaNodeDto
}

interface MyAnimeListMangaSearchResponseDto {
  data?: MyAnimeListMangaSearchItemDto[]
}

interface MyAnimeListListStatusDto {
  status?: string
  num_chapters_read?: number
  updated_at?: string
}

interface MyAnimeListMangaDetailDto extends MyAnimeListMangaNodeDto {
  num_chapters?: number
  my_list_status?: MyAnimeListListStatusDto
}

interface MyAnimeListUpdateListStatusResponseDto {
  status?: string
  num_chapters_read?: number
  updated_at?: string
}

const MYANIMELIST_API_BASE: string = 'https://api.myanimelist.net/v2'
const MYANIMELIST_PROVIDER_ID: TrackerProviderId = 'myanimelist'

export function redactMyAnimeListTrackerRequest(request: MyAnimeListTrackerHttpRequest): RedactedMyAnimeListTrackerHttpRequest {
  const headers: MyAnimeListTrackerHeaders = {
    accept: request.headers.accept,
    contentType: request.headers.contentType,
  }
  if (request.headers.authorization !== undefined) {
    headers.authorization = '<redacted>'
  }
  return {
    method: request.method,
    url: request.url,
    headers,
    body: request.body,
  }
}

export function myAnimeListTrackerHeadersToHttpHeaderObject(headers: MyAnimeListTrackerHeaders): Object {
  const entries: string[] = []
  if (headers.authorization !== undefined) {
    entries.push(`"Authorization":${JSON.stringify(headers.authorization)}`)
  }
  if (headers.accept !== undefined) {
    entries.push(`"Accept":${JSON.stringify(headers.accept)}`)
  }
  if (headers.contentType !== undefined) {
    entries.push(`"Content-Type":${JSON.stringify(headers.contentType)}`)
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

export function normalizeMyAnimeListTrackerSearchQuery(query: string): string {
  return query.trim().slice(0, 120)
}

export function normalizeMyAnimeListTrackerProgress(progress: number): number {
  if (progress !== progress || progress < 0) {
    return 0
  }
  return Math.floor(progress)
}

export function myAnimeListTrackerErrorCode(response: MyAnimeListTrackerHttpResponse): MyAnimeListTrackerErrorCode {
  if (response.status === 401 || response.status === 403) {
    return 'unauthorized'
  }
  if (response.status === 404) {
    return 'not_found'
  }
  if (response.status === 429) {
    return 'rate_limited'
  }
  if (response.status < 200 || response.status >= 300) {
    return 'provider_error'
  }
  return 'malformed_response'
}

function encodeQueryValue(value: string): string {
  return encodeURIComponent(value)
}

function queryString(params?: MyAnimeListQueryParams): string {
  if (params === undefined) {
    return ''
  }
  const pairs: string[] = []
  if (params.q !== undefined) {
    pairs.push(`q=${encodeQueryValue(params.q)}`)
  }
  if (params.fields !== undefined) {
    pairs.push(`fields=${encodeQueryValue(params.fields)}`)
  }
  if (params.limit !== undefined) {
    pairs.push(`limit=${encodeQueryValue(params.limit)}`)
  }
  if (params.offset !== undefined) {
    pairs.push(`offset=${encodeQueryValue(params.offset)}`)
  }
  return pairs.length === 0 ? '' : `?${pairs.join('&')}`
}

export class HarmonyMyAnimeListTrackerHttpAdapter implements MyAnimeListTrackerHttpAdapter {
  async request(request: MyAnimeListTrackerHttpRequest): Promise<MyAnimeListTrackerHttpResponse> {
    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(request.url, {
        method: request.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.PUT,
        extraData: request.body ?? '',
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        header: myAnimeListTrackerHeadersToHttpHeaderObject(request.headers),
        readTimeout: 30000,
        connectTimeout: 15000,
      })
      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      return {
        status: response.responseCode,
        body,
      }
    } finally {
      httpRequest.destroy()
    }
  }
}

export class MyAnimeListTrackerClient {
  private http: MyAnimeListTrackerHttpAdapter

  constructor(http: MyAnimeListTrackerHttpAdapter) {
    this.http = http
  }

  buildApiRequest(
    accessToken: string,
    method: MyAnimeListTrackerHttpMethod,
    path: string,
    params?: MyAnimeListQueryParams,
    body?: string,
  ): MyAnimeListTrackerHttpRequest {
    const token = accessToken.trim()
    if (token.length === 0) {
      throw new Error('tracker_auth_required')
    }
    const headers: MyAnimeListTrackerHeaders = {
      authorization: `Bearer ${token}`,
      accept: 'application/json',
    }
    if (method === 'PUT') {
      headers.contentType = 'application/x-www-form-urlencoded'
    }
    return {
      method,
      url: `${MYANIMELIST_API_BASE}${path}${queryString(params)}`,
      headers,
      body,
    }
  }

  async fetchProfile(accessToken: string): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerProfile>> {
    return this.sendAndParseProfile(this.buildApiRequest(accessToken, 'GET', '/users/@me', { fields: 'id,name' }))
  }

  async searchManga(accessToken: string, query: string, page: number = 1, limit: number = 10): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerTitleSearchResult[]>> {
    const normalizedQuery = normalizeMyAnimeListTrackerSearchQuery(query)
    if (normalizedQuery.length === 0) {
      return {
        ok: true,
        value: [],
      }
    }
    const pageNumber = Math.max(1, Math.floor(page))
    const boundedLimit = Math.max(1, Math.min(20, Math.floor(limit)))
    const request = this.buildApiRequest(accessToken, 'GET', '/manga', {
      q: normalizedQuery,
      limit: `${Math.max(1, Math.min(20, Math.floor(limit)))}`,
      offset: `${(pageNumber - 1) * boundedLimit}`,
      fields: 'id,title,main_picture,media_type,status,alternative_titles',
    })
    return this.sendAndParseSearch(request)
  }

  async fetchProgress(accessToken: string, providerTitleId: string): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerProgress | undefined>> {
    const mangaId = normalizeMyAnimeListMangaId(providerTitleId)
    if (mangaId <= 0) {
      return {
        ok: false,
        errorCode: 'not_found',
      }
    }
    const request = this.buildApiRequest(accessToken, 'GET', `/manga/${mangaId}`, {
      fields: 'id,title,status,media_type,my_list_status,num_chapters',
    })
    return this.sendAndParseProgress(request, mangaId)
  }

  async pushProgress(accessToken: string, providerTitleId: string, progress: number, completed: boolean): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerProgress>> {
    const mangaId = normalizeMyAnimeListMangaId(providerTitleId)
    if (mangaId <= 0) {
      return {
        ok: false,
        errorCode: 'not_found',
      }
    }
    const normalizedProgress = normalizeMyAnimeListTrackerProgress(progress)
    const request = this.buildApiRequest(
      accessToken,
      'PUT',
      `/manga/${mangaId}/my_list_status`,
      undefined,
      `status=${completed ? 'completed' : 'reading'}&num_chapters_read=${normalizedProgress}`,
    )
    return this.sendAndParseSavedProgress(request, mangaId)
  }

  private async send<T>(request: MyAnimeListTrackerHttpRequest): Promise<MyAnimeListTrackerResult<T>> {
    let response: MyAnimeListTrackerHttpResponse
    try {
      response = await this.http.request(request)
    } catch (_error) {
      return {
        ok: false,
        errorCode: 'network_error',
      }
    }
    if (response.status < 200 || response.status >= 300) {
      return {
        ok: false,
        errorCode: myAnimeListTrackerErrorCode(response),
      }
    }
    try {
      return {
        ok: true,
        value: JSON.parse(response.body) as T,
      }
    } catch (_error) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
  }

  private async sendAndParseProfile(request: MyAnimeListTrackerHttpRequest): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerProfile>> {
    const result = await this.send<MyAnimeListProfileDto>(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    const profile = result.value
    if (profile.id === undefined || profile.id <= 0 || profile.name === undefined || profile.name.trim().length === 0) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
    return {
      ok: true,
      value: {
        providerId: MYANIMELIST_PROVIDER_ID,
        providerUserId: `${profile.id}`,
        username: profile.name.trim(),
        displayName: profile.name.trim(),
      },
    }
  }

  private async sendAndParseSearch(request: MyAnimeListTrackerHttpRequest): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerTitleSearchResult[]>> {
    const result = await this.send<MyAnimeListMangaSearchResponseDto>(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    if (result.value.data === undefined) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
    const values: MyAnimeListTrackerTitleSearchResult[] = []
    result.value.data.forEach((item: MyAnimeListMangaSearchItemDto) => {
      const normalized = normalizeMyAnimeListManga(item.node)
      if (normalized !== undefined) {
        values.push(normalized)
      }
    })
    return {
      ok: true,
      value: values,
    }
  }

  private async sendAndParseProgress(request: MyAnimeListTrackerHttpRequest, mangaId: number): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerProgress | undefined>> {
    const result = await this.send<MyAnimeListMangaDetailDto>(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    if (result.value.my_list_status === undefined) {
      return {
        ok: true,
        value: undefined,
      }
    }
    return {
      ok: true,
      value: normalizeMyAnimeListProgress(result.value.my_list_status, mangaId),
    }
  }

  private async sendAndParseSavedProgress(request: MyAnimeListTrackerHttpRequest, mangaId: number): Promise<MyAnimeListTrackerResult<MyAnimeListTrackerProgress>> {
    const result = await this.send<MyAnimeListUpdateListStatusResponseDto>(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    return {
      ok: true,
      value: normalizeMyAnimeListProgress(result.value, mangaId),
    }
  }
}

function normalizeMyAnimeListMangaId(value: string): number {
  const trimmed = value.trim()
  if (!/^[0-9]{1,12}$/.test(trimmed)) {
    return 0
  }
  const parsed = Number.parseInt(trimmed, 10)
  return parsed > 0 ? parsed : 0
}

function normalizeMyAnimeListText(value: string | undefined, limit: number): string | undefined {
  if (value === undefined || value.trim().length === 0) {
    return undefined
  }
  return value.trim().slice(0, limit)
}

function normalizeMyAnimeListManga(manga: MyAnimeListMangaNodeDto | undefined): MyAnimeListTrackerTitleSearchResult | undefined {
  if (manga === undefined || manga.id === undefined || manga.id <= 0) {
    return undefined
  }
  const title = normalizeMyAnimeListText(manga.title, 200)
  if (title === undefined) {
    return undefined
  }
  const result: MyAnimeListTrackerTitleSearchResult = {
    providerId: MYANIMELIST_PROVIDER_ID,
    providerTitleId: `${manga.id}`,
    title,
  }
  const nativeTitle = normalizeMyAnimeListText(manga.alternative_titles?.ja, 200)
  if (nativeTitle !== undefined) {
    result.nativeTitle = nativeTitle
  }
  const format = normalizeMyAnimeListText(manga.media_type, 40)
  if (format !== undefined) {
    result.format = format
  }
  const status = normalizeMyAnimeListText(manga.status, 40)
  if (status !== undefined) {
    result.status = status
  }
  const cover = manga.main_picture?.large ?? manga.main_picture?.medium
  if (cover !== undefined && cover.startsWith('https://')) {
    result.coverImageUrl = cover.slice(0, 512)
  }
  return result
}

function normalizeMyAnimeListUpdatedAt(value: string | undefined): number | undefined {
  if (value === undefined || value.trim().length === 0) {
    return undefined
  }
  const parsed = Date.parse(value)
  if (parsed !== parsed || parsed <= 0) {
    return undefined
  }
  return Math.floor(parsed / 1000)
}

function normalizeMyAnimeListProgress(progress: MyAnimeListListStatusDto | MyAnimeListUpdateListStatusResponseDto, fallbackMangaId: number): MyAnimeListTrackerProgress {
  const status = normalizeMyAnimeListText(progress.status, 40)
  const value: MyAnimeListTrackerProgress = {
    providerId: MYANIMELIST_PROVIDER_ID,
    providerTitleId: `${fallbackMangaId}`,
    progress: normalizeMyAnimeListTrackerProgress(progress.num_chapters_read ?? 0),
    completed: status === 'completed',
  }
  if (status !== undefined) {
    value.status = status
  }
  const updatedAt = normalizeMyAnimeListUpdatedAt(progress.updated_at)
  if (updatedAt !== undefined) {
    value.updatedAt = updatedAt
  }
  return value
}
