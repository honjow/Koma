import {
  KomgaAuthKind,
  KomgaBookDto,
  KomgaBookId,
  KomgaCredentialRef,
  KomgaLibraryDto,
  KomgaListRequest,
  KomgaPageDto,
  KomgaPageImageKind,
  KomgaPageList,
  KomgaPageResponseDto,
  KomgaResolvedCredential,
  RemotePageRef,
  KomgaSeriesDto,
  KomgaServerConfig,
} from './KomgaModels'

export interface KomgaHeaders {
  authorization?: string
  accept?: string
  contentType?: string
  xApiKey?: string
  xAuthToken?: string
}

export interface KomgaHttpRequest {
  method: 'GET' | 'POST'
  url: string
  headers: KomgaHeaders
  body?: string
}

export interface RedactedKomgaHttpRequest {
  method: 'GET' | 'POST'
  url: string
  headers: KomgaHeaders
  body?: string
}

export interface KomgaHttpResponse {
  status: number
  body: string
}

export interface KomgaHttpAdapter {
  request(request: KomgaHttpRequest): Promise<KomgaHttpResponse>
}

export interface KomgaClientOptions {
  server: KomgaServerConfig
  credential?: KomgaResolvedCredential
  http?: KomgaHttpAdapter
}

export class KomgaPaths {
  static libraries(): string {
    return '/api/v1/libraries'
  }

  static seriesList(): string {
    return '/api/v1/series/list'
  }

  static booksList(): string {
    return '/api/v1/books/list'
  }

  static bookPages(bookId: KomgaBookId): string {
    return `/api/v1/books/${encodePathSegment(bookId)}/pages`
  }

  static pageImage(bookId: KomgaBookId, pageNumber: number, kind: KomgaPageImageKind = KomgaPageImageKind.STREAM): string {
    const base = `/api/v1/books/${encodePathSegment(bookId)}/pages/${pageNumber}`
    if (kind === KomgaPageImageKind.RAW) {
      return `${base}/raw`
    }
    if (kind === KomgaPageImageKind.THUMBNAIL) {
      return `${base}/thumbnail`
    }
    return base
  }
}

export function normalizeKomgaBaseUrl(baseUrl: string): string {
  const trimmed = baseUrl.trim()
  let end = trimmed.length
  while (end > 0 && trimmed.charAt(end - 1) === '/') {
    end -= 1
  }
  return trimmed.substring(0, end)
}

export function buildKomgaUrl(baseUrl: string, path: string): string {
  const normalizedBase = normalizeKomgaBaseUrl(baseUrl)
  if (path.startsWith('/')) {
    return `${normalizedBase}${path}`
  }
  return `${normalizedBase}/${path}`
}

export function buildKomgaAuthHeaders(config: KomgaServerConfig, credential?: KomgaResolvedCredential): KomgaHeaders {
  if (config.authKind === KomgaAuthKind.NONE) {
    return {} as KomgaHeaders
  }
  assertCredentialRef(config, credential)
  if (credential === undefined) {
    throw new Error('Komga credential material is required')
  }
  if (config.authKind === KomgaAuthKind.BASIC) {
    if (credential.basicToken === undefined || credential.basicToken.length === 0) {
      throw new Error('Komga Basic credential token is required')
    }
    return { authorization: `Basic ${credential.basicToken}` } as KomgaHeaders
  }
  if (config.authKind === KomgaAuthKind.API_KEY) {
    if (credential.apiKey === undefined || credential.apiKey.length === 0) {
      throw new Error('Komga API key credential is required')
    }
    return { xApiKey: credential.apiKey } as KomgaHeaders
  }
  if (credential.sessionToken === undefined || credential.sessionToken.length === 0) {
    throw new Error('Komga session token credential is required')
  }
  return { xAuthToken: credential.sessionToken } as KomgaHeaders
}

export function redactKomgaHeaders(headers: KomgaHeaders): KomgaHeaders {
  const redacted: KomgaHeaders = {} as KomgaHeaders
  redacted.accept = headers.accept
  redacted.contentType = headers.contentType
  if (headers.authorization !== undefined) {
    redacted.authorization = '<redacted>'
  }
  if (headers.xApiKey !== undefined) {
    redacted.xApiKey = '<redacted>'
  }
  if (headers.xAuthToken !== undefined) {
    redacted.xAuthToken = '<redacted>'
  }
  return redacted
}

export function komgaHeadersToHttpHeaderObject(headers: KomgaHeaders): Object {
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
  if (headers.xApiKey !== undefined) {
    entries.push(`"X-API-Key":${JSON.stringify(headers.xApiKey)}`)
  }
  if (headers.xAuthToken !== undefined) {
    entries.push(`"X-Auth-Token":${JSON.stringify(headers.xAuthToken)}`)
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

export function redactKomgaRequest(request: KomgaHttpRequest): RedactedKomgaHttpRequest {
  return {
    method: request.method,
    url: request.url,
    headers: redactKomgaHeaders(request.headers),
    body: request.body,
  }
}

export function createRemotePageRef(
  serverId: string,
  bookId: KomgaBookId,
  pageNumber: number,
  imageKind: KomgaPageImageKind = KomgaPageImageKind.STREAM
): RemotePageRef {
  return {
    sourceType: 'komga',
    serverId,
    bookId,
    pageNumber,
    imageKind,
    path: KomgaPaths.pageImage(bookId, pageNumber, imageKind),
  }
}

export class KomgaClient {
  private server: KomgaServerConfig
  private credential?: KomgaResolvedCredential
  private http?: KomgaHttpAdapter

  constructor(options: KomgaClientOptions) {
    this.server = options.server
    this.credential = options.credential
    this.http = options.http
  }

  getBaseUrl(): string {
    return normalizeKomgaBaseUrl(this.server.baseUrl)
  }

  buildUrl(path: string): string {
    return buildKomgaUrl(this.server.baseUrl, path)
  }

  buildHeaders(extraHeaders: KomgaHeaders = {} as KomgaHeaders): KomgaHeaders {
    const authHeaders = buildKomgaAuthHeaders(this.server, this.credential)
    const headers: KomgaHeaders = {} as KomgaHeaders
    headers.authorization = extraHeaders.authorization === undefined ? authHeaders.authorization : extraHeaders.authorization
    headers.accept = extraHeaders.accept === undefined ? authHeaders.accept : extraHeaders.accept
    headers.contentType = extraHeaders.contentType === undefined ? authHeaders.contentType : extraHeaders.contentType
    headers.xApiKey = extraHeaders.xApiKey === undefined ? authHeaders.xApiKey : extraHeaders.xApiKey
    headers.xAuthToken = extraHeaders.xAuthToken === undefined ? authHeaders.xAuthToken : extraHeaders.xAuthToken
    return headers
  }

  buildLibrariesRequest(): KomgaHttpRequest {
    return this.buildJsonRequest('GET', KomgaPaths.libraries())
  }

  buildSeriesListRequest(request: KomgaListRequest = {}): KomgaHttpRequest {
    return this.buildJsonRequest('POST', KomgaPaths.seriesList(), request)
  }

  buildBooksListRequest(request: KomgaListRequest = {}): KomgaHttpRequest {
    return this.buildJsonRequest('POST', KomgaPaths.booksList(), request)
  }

  buildBookPagesRequest(bookId: KomgaBookId): KomgaHttpRequest {
    return this.buildJsonRequest('GET', KomgaPaths.bookPages(bookId))
  }

  getPageImageUrl(bookId: KomgaBookId, pageNumber: number, kind: KomgaPageImageKind = KomgaPageImageKind.STREAM): string {
    return this.buildUrl(KomgaPaths.pageImage(bookId, pageNumber, kind))
  }

  async listLibraries(): Promise<KomgaLibraryDto[]> {
    const response = await this.send(this.buildLibrariesRequest())
    return JSON.parse(response.body) as KomgaLibraryDto[]
  }

  async listSeries(request: KomgaListRequest = {}): Promise<KomgaPageList<KomgaSeriesDto>> {
    const response = await this.send(this.buildSeriesListRequest(request))
    return JSON.parse(response.body) as KomgaPageList<KomgaSeriesDto>
  }

  async listBooks(request: KomgaListRequest = {}): Promise<KomgaPageList<KomgaBookDto>> {
    const response = await this.send(this.buildBooksListRequest(request))
    return JSON.parse(response.body) as KomgaPageList<KomgaBookDto>
  }

  async listBookPages(bookId: KomgaBookId): Promise<KomgaPageDto[]> {
    const response = await this.send(this.buildBookPagesRequest(bookId))
    const parsed = JSON.parse(response.body) as KomgaPageDto[] | KomgaPageResponseDto
    if (Array.isArray(parsed)) {
      return parsed
    }
    return parsed.content
  }

  private buildJsonRequest(method: 'GET' | 'POST', path: string, body?: KomgaListRequest): KomgaHttpRequest {
    const headers = this.buildHeaders({ accept: 'application/json' } as KomgaHeaders)
    if (method === 'POST') {
      headers.contentType = 'application/json'
    }
    return {
      method,
      url: this.buildUrl(path),
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    }
  }

  private async send(request: KomgaHttpRequest): Promise<KomgaHttpResponse> {
    if (this.http === undefined) {
      throw new Error('KomgaHttpAdapter is required for network requests')
    }
    const response = await this.http.request(request)
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`Komga request failed with status ${response.status}`)
    }
    return response
  }
}

function encodePathSegment(value: string): string {
  return encodeURIComponent(value)
}

function assertCredentialRef(config: KomgaServerConfig, credential?: KomgaResolvedCredential): void {
  if (config.credentialRef === undefined || config.credentialRef.length === 0) {
    throw new Error('Komga credentialRef is required for authenticated requests')
  }
  if (credential !== undefined && credential.credentialRef !== config.credentialRef) {
    throw new Error('Komga credentialRef mismatch')
  }
}

function isSensitiveHeader(key: string): boolean {
  const normalized = key.toLocaleLowerCase()
  return normalized === 'authorization' || normalized === 'x-api-key' || normalized === 'x-auth-token' || normalized === 'cookie'
}
