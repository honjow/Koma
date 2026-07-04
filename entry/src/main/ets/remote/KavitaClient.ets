import {
  KavitaLibraryDto,
  KavitaResolvedCredential,
  KavitaServerConfig,
  KavitaSeriesDto,
} from './KavitaModels'

export interface KavitaHeaders {
  accept?: string
  contentType?: string
  xApiKey?: string
}

export interface KavitaHttpRequest {
  method: 'GET' | 'POST'
  url: string
  headers: KavitaHeaders
  body?: string
}

export interface KavitaHttpResponse {
  status: number
  body: string
}

export interface KavitaHttpAdapter {
  request(request: KavitaHttpRequest): Promise<KavitaHttpResponse>
}

export interface KavitaClientOptions {
  server: KavitaServerConfig
  credential: KavitaResolvedCredential
  http?: KavitaHttpAdapter
}

interface KavitaSeriesFilterStatement {
  comparison: number
  field: number
  value: string
}

interface KavitaSeriesSortOptions {
  sortField: number
  isAscending: boolean
}

interface KavitaSeriesFilterRequest {
  statements: KavitaSeriesFilterStatement[]
  combination: number
  sortOptions: KavitaSeriesSortOptions
  limitTo: number
}

export class KavitaPaths {
  static libraries(): string {
    return '/api/Library/libraries'
  }

  static librarySeries(pageNumber: number = 1, pageSize: number = 50): string {
    return `/api/Series/all-v2?PageNumber=${pageNumber}&PageSize=${pageSize}`
  }
}

export function normalizeKavitaBaseUrl(baseUrl: string): string {
  const trimmed = baseUrl.trim()
  let end = trimmed.length
  while (end > 0 && trimmed.charAt(end - 1) === '/') {
    end -= 1
  }
  return trimmed.substring(0, end)
}

export function buildKavitaUrl(baseUrl: string, path: string): string {
  const normalizedBase = normalizeKavitaBaseUrl(baseUrl)
  if (path.startsWith('/')) {
    return `${normalizedBase}${path}`
  }
  return `${normalizedBase}/${path}`
}

export function buildKavitaAuthHeaders(credential: KavitaResolvedCredential): KavitaHeaders {
  if (credential.apiKey.length === 0) {
    throw new Error('Kavita API key credential is required')
  }
  return { xApiKey: credential.apiKey } as KavitaHeaders
}

export function kavitaHeadersToHttpHeaderObject(headers: KavitaHeaders): Object {
  const entries: string[] = []
  if (headers.accept !== undefined) {
    entries.push(`"Accept":${JSON.stringify(headers.accept)}`)
  }
  if (headers.contentType !== undefined) {
    entries.push(`"Content-Type":${JSON.stringify(headers.contentType)}`)
  }
  if (headers.xApiKey !== undefined) {
    entries.push(`"x-api-key":${JSON.stringify(headers.xApiKey)}`)
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

function parseKavitaJson<T>(body: string): T {
  try {
    return JSON.parse(body) as T
  } catch (_error) {
    throw new Error('kavita_invalid_json')
  }
}

export class KavitaClient {
  private server: KavitaServerConfig
  private credential: KavitaResolvedCredential
  private http?: KavitaHttpAdapter

  constructor(options: KavitaClientOptions) {
    this.server = options.server
    this.credential = options.credential
    this.http = options.http
  }

  getBaseUrl(): string {
    return normalizeKavitaBaseUrl(this.server.baseUrl)
  }

  buildUrl(path: string): string {
    return buildKavitaUrl(this.server.baseUrl, path)
  }

  buildHeaders(extraHeaders: KavitaHeaders = {} as KavitaHeaders): KavitaHeaders {
    const authHeaders = buildKavitaAuthHeaders(this.credential)
    const headers: KavitaHeaders = {} as KavitaHeaders
    headers.accept = extraHeaders.accept === undefined ? authHeaders.accept : extraHeaders.accept
    headers.contentType = extraHeaders.contentType === undefined ? authHeaders.contentType : extraHeaders.contentType
    headers.xApiKey = extraHeaders.xApiKey === undefined ? authHeaders.xApiKey : extraHeaders.xApiKey
    return headers
  }

  async listLibraries(): Promise<KavitaLibraryDto[]> {
    const response = await this.request('GET', KavitaPaths.libraries(), {
      accept: 'application/json',
    } as KavitaHeaders)
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`kavita_http_status_${response.status}`)
    }
    return parseKavitaJson<KavitaLibraryDto[]>(response.body)
  }

  async listSeries(libraryId: number, pageNumber: number = 1, pageSize: number = 50): Promise<KavitaSeriesDto[]> {
    const request: KavitaSeriesFilterRequest = {
      statements: [{
        comparison: 0,
        field: 19,
        value: `${libraryId}`,
      }],
      combination: 1,
      sortOptions: {
        sortField: 1,
        isAscending: true,
      },
      limitTo: 0,
    }
    const body = JSON.stringify(request)
    const response = await this.request('POST', KavitaPaths.librarySeries(pageNumber, pageSize), {
      accept: 'application/json',
      contentType: 'application/json',
    } as KavitaHeaders, body)
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`kavita_http_status_${response.status}`)
    }
    return parseKavitaJson<KavitaSeriesDto[]>(response.body)
  }

  private async request(method: 'GET' | 'POST', path: string, headers: KavitaHeaders, body?: string): Promise<KavitaHttpResponse> {
    if (this.http === undefined) {
      throw new Error('Kavita HTTP adapter is required')
    }
    return this.http.request({
      method,
      url: this.buildUrl(path),
      headers: this.buildHeaders(headers),
      body,
    })
  }
}
