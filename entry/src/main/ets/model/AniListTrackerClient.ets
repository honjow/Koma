import { TrackerProviderId } from './TrackerModels'

export type AniListTrackerErrorCode =
  'auth_required' |
  'unauthorized' |
  'rate_limited' |
  'network_error' |
  'provider_error' |
  'malformed_response' |
  'not_found'

export interface AniListTrackerHeaders {
  authorization?: string
  accept?: string
  contentType?: string
}

export interface AniListTrackerHttpRequest {
  method: 'POST'
  url: string
  headers: AniListTrackerHeaders
  body: string
}

export interface RedactedAniListTrackerHttpRequest {
  method: 'POST'
  url: string
  headers: AniListTrackerHeaders
  body: string
}

export interface AniListTrackerHttpResponse {
  status: number
  body: string
}

export interface AniListTrackerHttpAdapter {
  request(request: AniListTrackerHttpRequest): Promise<AniListTrackerHttpResponse>
}

export interface AniListTrackerResult<T> {
  ok: boolean
  value?: T
  errorCode?: AniListTrackerErrorCode
}

export interface AniListTrackerProfile {
  providerId: TrackerProviderId
  providerUserId: string
  username: string
  displayName?: string
}

export interface AniListTrackerTitleSearchResult {
  providerId: TrackerProviderId
  providerTitleId: string
  title: string
  nativeTitle?: string
  format?: string
  status?: string
  coverImageUrl?: string
}

export interface AniListTrackerProgress {
  providerId: TrackerProviderId
  providerTitleId: string
  progress: number
  completed: boolean
  status?: string
  updatedAt?: number
}

interface AniListGraphqlError {
  message?: string
  status?: number
}

interface AniListViewerDto {
  id?: number
  name?: string
}

interface AniListTitleDto {
  romaji?: string
  english?: string
  native?: string
}

interface AniListCoverDto {
  medium?: string
  large?: string
}

interface AniListMediaDto {
  id?: number
  title?: AniListTitleDto
  format?: string
  status?: string
  coverImage?: AniListCoverDto
}

interface AniListMediaListDto {
  mediaId?: number
  progress?: number
  status?: string
  updatedAt?: number
}

interface AniListPageDto {
  media?: AniListMediaDto[]
}

interface AniListGraphqlDataDto {
  Viewer?: AniListViewerDto
  Page?: AniListPageDto
  MediaList?: AniListMediaListDto
  SaveMediaListEntry?: AniListMediaListDto
}

interface AniListGraphqlResponseDto {
  data?: AniListGraphqlDataDto
  errors?: AniListGraphqlError[]
}

const ANILIST_GRAPHQL_ENDPOINT: string = 'https://graphql.anilist.co'
const ANILIST_PROVIDER_ID: TrackerProviderId = 'anilist'

const ANILIST_VIEWER_QUERY: string =
  'query KomaViewer { Viewer { id name } }'

const ANILIST_SEARCH_QUERY: string =
  'query KomaMangaSearch($search: String!, $page: Int, $perPage: Int) { Page(page: $page, perPage: $perPage) { media(type: MANGA, search: $search) { id title { romaji english native } format status coverImage { medium large } } } }'

const ANILIST_PROGRESS_QUERY: string =
  'query KomaMangaProgress($mediaId: Int!) { MediaList(mediaId: $mediaId, type: MANGA) { mediaId progress status updatedAt } }'

const ANILIST_SAVE_PROGRESS_MUTATION: string =
  'mutation KomaSaveMangaProgress($mediaId: Int!, $progress: Int!, $status: MediaListStatus) { SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) { mediaId progress status updatedAt } }'

export function redactAniListTrackerRequest(request: AniListTrackerHttpRequest): RedactedAniListTrackerHttpRequest {
  const headers: AniListTrackerHeaders = {
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

export function normalizeAniListTrackerSearchQuery(query: string): string {
  return query.trim().slice(0, 120)
}

export function normalizeAniListTrackerProgress(progress: number): number {
  if (progress !== progress || progress < 0) {
    return 0
  }
  return Math.floor(progress)
}

export function aniListTrackerErrorCode(response: AniListTrackerHttpResponse): AniListTrackerErrorCode {
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

export class AniListTrackerClient {
  private http: AniListTrackerHttpAdapter

  constructor(http: AniListTrackerHttpAdapter) {
    this.http = http
  }

  buildGraphqlRequest(accessToken: string, query: string, variables: Object = {}): AniListTrackerHttpRequest {
    const token = accessToken.trim()
    if (token.length === 0) {
      throw new Error('tracker_auth_required')
    }
    return {
      method: 'POST',
      url: ANILIST_GRAPHQL_ENDPOINT,
      headers: {
        authorization: `Bearer ${token}`,
        accept: 'application/json',
        contentType: 'application/json',
      },
      body: JSON.stringify({
        query,
        variables,
      }),
    }
  }

  async fetchProfile(accessToken: string): Promise<AniListTrackerResult<AniListTrackerProfile>> {
    return this.sendAndParseProfile(this.buildGraphqlRequest(accessToken, ANILIST_VIEWER_QUERY))
  }

  async searchManga(accessToken: string, query: string, page: number = 1, perPage: number = 10): Promise<AniListTrackerResult<AniListTrackerTitleSearchResult[]>> {
    const normalizedQuery = normalizeAniListTrackerSearchQuery(query)
    if (normalizedQuery.length === 0) {
      return {
        ok: true,
        value: [],
      }
    }
    const request = this.buildGraphqlRequest(accessToken, ANILIST_SEARCH_QUERY, {
      search: normalizedQuery,
      page: Math.max(1, Math.floor(page)),
      perPage: Math.max(1, Math.min(20, Math.floor(perPage))),
    } as Object)
    return this.sendAndParseSearch(request)
  }

  async fetchProgress(accessToken: string, providerTitleId: string): Promise<AniListTrackerResult<AniListTrackerProgress | undefined>> {
    const mediaId = normalizeAniListMediaId(providerTitleId)
    if (mediaId <= 0) {
      return {
        ok: false,
        errorCode: 'not_found',
      }
    }
    const request = this.buildGraphqlRequest(accessToken, ANILIST_PROGRESS_QUERY, { mediaId } as Object)
    return this.sendAndParseProgress(request, mediaId)
  }

  async pushProgress(accessToken: string, providerTitleId: string, progress: number, completed: boolean): Promise<AniListTrackerResult<AniListTrackerProgress>> {
    const mediaId = normalizeAniListMediaId(providerTitleId)
    if (mediaId <= 0) {
      return {
        ok: false,
        errorCode: 'not_found',
      }
    }
    const request = this.buildGraphqlRequest(accessToken, ANILIST_SAVE_PROGRESS_MUTATION, {
      mediaId,
      progress: normalizeAniListTrackerProgress(progress),
      status: completed ? 'COMPLETED' : 'CURRENT',
    } as Object)
    return this.sendAndParseSavedProgress(request, mediaId)
  }

  private async send(request: AniListTrackerHttpRequest): Promise<AniListTrackerResult<AniListGraphqlResponseDto>> {
    let response: AniListTrackerHttpResponse
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
        errorCode: aniListTrackerErrorCode(response),
      }
    }
    let parsed: AniListGraphqlResponseDto
    try {
      parsed = JSON.parse(response.body) as AniListGraphqlResponseDto
    } catch (_error) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
    if (parsed.errors !== undefined && parsed.errors.length > 0) {
      return {
        ok: false,
        errorCode: this.graphqlErrorCode(parsed.errors),
      }
    }
    return {
      ok: true,
      value: parsed,
    }
  }

  private async sendAndParseProfile(request: AniListTrackerHttpRequest): Promise<AniListTrackerResult<AniListTrackerProfile>> {
    const result = await this.send(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    const viewer = result.value.data?.Viewer
    if (viewer === undefined || viewer.id === undefined || viewer.name === undefined || viewer.name.trim().length === 0) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
    return {
      ok: true,
      value: {
        providerId: ANILIST_PROVIDER_ID,
        providerUserId: `${viewer.id}`,
        username: viewer.name.trim(),
        displayName: viewer.name.trim(),
      },
    }
  }

  private async sendAndParseSearch(request: AniListTrackerHttpRequest): Promise<AniListTrackerResult<AniListTrackerTitleSearchResult[]>> {
    const result = await this.send(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    const media = result.value.data?.Page?.media
    if (media === undefined) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
    const values: AniListTrackerTitleSearchResult[] = []
    media.forEach((item: AniListMediaDto) => {
      const normalized = normalizeAniListMedia(item)
      if (normalized !== undefined) {
        values.push(normalized)
      }
    })
    return {
      ok: true,
      value: values,
    }
  }

  private async sendAndParseProgress(request: AniListTrackerHttpRequest, mediaId: number): Promise<AniListTrackerResult<AniListTrackerProgress | undefined>> {
    const result = await this.send(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    const progress = result.value.data?.MediaList
    if (progress === undefined) {
      return {
        ok: true,
        value: undefined,
      }
    }
    return {
      ok: true,
      value: normalizeAniListProgress(progress, mediaId),
    }
  }

  private async sendAndParseSavedProgress(request: AniListTrackerHttpRequest, mediaId: number): Promise<AniListTrackerResult<AniListTrackerProgress>> {
    const result = await this.send(request)
    if (!result.ok || result.value === undefined) {
      return {
        ok: false,
        errorCode: result.errorCode ?? 'provider_error',
      }
    }
    const progress = result.value.data?.SaveMediaListEntry
    if (progress === undefined) {
      return {
        ok: false,
        errorCode: 'malformed_response',
      }
    }
    return {
      ok: true,
      value: normalizeAniListProgress(progress, mediaId),
    }
  }

  private graphqlErrorCode(errors: AniListGraphqlError[]): AniListTrackerErrorCode {
    const first = errors[0]
    if (first.status === 401 || first.status === 403) {
      return 'unauthorized'
    }
    if (first.status === 404) {
      return 'not_found'
    }
    if (first.status === 429) {
      return 'rate_limited'
    }
    const message = first.message?.toLowerCase() ?? ''
    if (message.indexOf('auth') >= 0 || message.indexOf('token') >= 0) {
      return 'unauthorized'
    }
    if (message.indexOf('rate') >= 0) {
      return 'rate_limited'
    }
    return 'provider_error'
  }
}

function normalizeAniListMediaId(value: string): number {
  const trimmed = value.trim()
  if (!/^[0-9]{1,12}$/.test(trimmed)) {
    return 0
  }
  const parsed = Number.parseInt(trimmed, 10)
  return parsed > 0 ? parsed : 0
}

function normalizeAniListMedia(media: AniListMediaDto): AniListTrackerTitleSearchResult | undefined {
  if (media.id === undefined || media.id <= 0) {
    return undefined
  }
  const title = media.title?.english ?? media.title?.romaji ?? media.title?.native
  if (title === undefined || title.trim().length === 0) {
    return undefined
  }
  const result: AniListTrackerTitleSearchResult = {
    providerId: ANILIST_PROVIDER_ID,
    providerTitleId: `${media.id}`,
    title: title.trim().slice(0, 200),
  }
  if (media.title?.native !== undefined && media.title.native.trim().length > 0) {
    result.nativeTitle = media.title.native.trim().slice(0, 200)
  }
  if (media.format !== undefined && media.format.trim().length > 0) {
    result.format = media.format.trim().slice(0, 40)
  }
  if (media.status !== undefined && media.status.trim().length > 0) {
    result.status = media.status.trim().slice(0, 40)
  }
  const cover = media.coverImage?.large ?? media.coverImage?.medium
  if (cover !== undefined && cover.startsWith('https://')) {
    result.coverImageUrl = cover.slice(0, 512)
  }
  return result
}

function normalizeAniListProgress(progress: AniListMediaListDto, fallbackMediaId: number): AniListTrackerProgress {
  const mediaId = progress.mediaId === undefined || progress.mediaId <= 0 ? fallbackMediaId : progress.mediaId
  const value: AniListTrackerProgress = {
    providerId: ANILIST_PROVIDER_ID,
    providerTitleId: `${mediaId}`,
    progress: normalizeAniListTrackerProgress(progress.progress ?? 0),
    completed: progress.status === 'COMPLETED',
  }
  if (progress.status !== undefined && progress.status.trim().length > 0) {
    value.status = progress.status.trim().slice(0, 40)
  }
  if (progress.updatedAt !== undefined && progress.updatedAt > 0) {
    value.updatedAt = progress.updatedAt
  }
  return value
}
