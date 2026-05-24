import {
  DavComicCandidate,
  DavComicCandidateKind,
  DavResource,
  WEBDAV_ARCHIVE_EXTENSIONS,
  WEBDAV_IMAGE_EXTENSIONS,
  WebDavAuthKind,
  WebDavResolvedCredential,
  WebDavServerConfig,
} from './WebDavModels'

export interface WebDavHeaders {
  authorization?: string
  accept?: string
  contentType?: string
  depth?: string
}

export interface WebDavHttpRequest {
  method: 'GET' | 'PROPFIND'
  url: string
  headers: WebDavHeaders
  body?: string
}

export interface RedactedWebDavHttpRequest {
  method: 'GET' | 'PROPFIND'
  url: string
  headers: WebDavHeaders
  body?: string
}

export interface WebDavHttpResponse {
  status: number
  body: string
}

export interface WebDavHttpAdapter {
  request(request: WebDavHttpRequest): Promise<WebDavHttpResponse>
}

export interface WebDavClientOptions {
  server: WebDavServerConfig
  credential?: WebDavResolvedCredential
  http?: WebDavHttpAdapter
}

export function normalizeWebDavBaseUrl(baseUrl: string): string {
  const trimmed = baseUrl.trim()
  let end = trimmed.length
  while (end > 0 && trimmed.charAt(end - 1) === '/') {
    end -= 1
  }
  return trimmed.substring(0, end)
}

export function resolveWebDavHref(baseUrl: string, href: string): string {
  if (href.startsWith('http://') || href.startsWith('https://')) {
    return href
  }
  const origin = readUrlOrigin(baseUrl)
  if (origin.length === 0) {
    return href
  }
  if (href.startsWith('/')) {
    return origin + href
  }
  return joinUrlPath(baseUrl, href)
}

export function buildWebDavUrl(baseUrl: string, pathSegments: string[] = []): string {
  const normalizedBase = normalizeWebDavBaseUrl(stripQueryAndHash(baseUrl))
  const origin = readUrlOrigin(normalizedBase)
  const basePath = readUrlPath(normalizedBase)
  const baseSegments = splitPathSegments(basePath)
  const nextSegments = flattenWebDavPathSegments(pathSegments)
  nextSegments.forEach((segment: string) => {
    if (segment === '..') {
      if (baseSegments.length > 0) {
        baseSegments.pop()
      }
    } else {
      baseSegments.push(segment)
    }
  })
  const path = '/' + baseSegments.map((segment: string) => encodeURIComponent(segment)).join('/')
  return origin + path
}

export function buildWebDavAuthHeaders(config: WebDavServerConfig, credential?: WebDavResolvedCredential): WebDavHeaders {
  if (config.authKind === WebDavAuthKind.NONE) {
    return {}
  }
  if (config.credentialRef === undefined || config.credentialRef.length === 0) {
    throw new Error('WebDAV credentialRef is required for authenticated requests')
  }
  if (credential !== undefined && credential.credentialRef !== config.credentialRef) {
    throw new Error('WebDAV credentialRef mismatch')
  }
  if (credential === undefined) {
    throw new Error('WebDAV credential material is required')
  }
  if (credential.basicToken === undefined || credential.basicToken.length === 0) {
    throw new Error('WebDAV Basic credential token is required')
  }
  return { authorization: `Basic ${credential.basicToken}` } as WebDavHeaders
}

export function redactWebDavHeaders(headers: WebDavHeaders): WebDavHeaders {
  const redacted: WebDavHeaders = {} as WebDavHeaders
  redacted.accept = headers.accept
  redacted.contentType = headers.contentType
  redacted.depth = headers.depth
  if (headers.authorization !== undefined) {
    redacted.authorization = '<redacted>'
  }
  return redacted
}

export function redactWebDavRequest(request: WebDavHttpRequest): RedactedWebDavHttpRequest {
  return {
    method: request.method,
    url: request.url,
    headers: redactWebDavHeaders(request.headers),
    body: request.body,
  }
}

export function webDavHeadersToHttpHeaderObject(headers: WebDavHeaders): Object {
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
  if (headers.depth !== undefined) {
    entries.push(`"Depth":${JSON.stringify(headers.depth)}`)
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

export function buildPropfindBody(): string {
  return '<?xml version="1.0" encoding="utf-8"?>' +
    '<d:propfind xmlns:d="DAV:"><d:prop>' +
    '<d:displayname/><d:resourcetype/><d:getcontentlength/>' +
    '<d:getcontenttype/><d:getlastmodified/><d:getetag/>' +
    '</d:prop></d:propfind>'
}

export function parseWebDavMultiStatus(xml: string, baseUrl: string): DavResource[] {
  return readXmlBlocks(xml, 'response').map((responseXml: string): DavResource => {
    const href = resolveWebDavHref(baseUrl, readFirstXmlText(responseXml, 'href') ?? '')
    const propstat = readSuccessfulPropstat(responseXml) ?? responseXml
    const resource: DavResource = {
      href,
      displayname: readFirstXmlText(propstat, 'displayname'),
      isCollection: hasXmlTag(propstat, 'collection'),
      contentLength: readNumber(readFirstXmlText(propstat, 'getcontentlength')),
      contentType: readFirstXmlText(propstat, 'getcontenttype'),
      lastModified: readFirstXmlText(propstat, 'getlastmodified'),
      etag: stripWeakEtag(readFirstXmlText(propstat, 'getetag')),
      candidateKind: DavComicCandidateKind.UNSUPPORTED,
    }
    resource.candidateKind = classifyDavResource(resource)
    return resource
  })
}

export function classifyDavResource(resource: DavResource): DavComicCandidateKind {
  if (resource.isCollection) {
    return DavComicCandidateKind.UNSUPPORTED
  }
  const lowerHref = stripQueryAndHash(resource.href).toLocaleLowerCase()
  const contentType = resource.contentType === undefined ? '' : resource.contentType.toLocaleLowerCase().split(';')[0].trim()
  if (WEBDAV_ARCHIVE_EXTENSIONS.some((extension: string): boolean => lowerHref.endsWith(extension))) {
    return DavComicCandidateKind.ARCHIVE
  }
  if (WEBDAV_IMAGE_EXTENSIONS.some((extension: string): boolean => lowerHref.endsWith(extension)) || contentType.startsWith('image/')) {
    return DavComicCandidateKind.IMAGE_FILE
  }
  return DavComicCandidateKind.UNSUPPORTED
}

export function detectWebDavComicCandidates(resources: DavResource[]): DavComicCandidate[] {
  const candidates: DavComicCandidate[] = []
  resources.forEach((resource: DavResource) => {
    if (resource.candidateKind === DavComicCandidateKind.ARCHIVE || resource.candidateKind === DavComicCandidateKind.IMAGE_FILE) {
      candidates.push({
        kind: resource.candidateKind,
        href: resource.href,
        title: resource.displayname ?? readNameFromHref(resource.href),
        resources: [resource],
      })
    }
  })

  const collections = resources.filter((resource: DavResource): boolean => resource.isCollection)
  collections.forEach((collection: DavResource) => {
    const imageChildren = resources.filter((resource: DavResource): boolean => {
      return !resource.isCollection &&
        resource.candidateKind === DavComicCandidateKind.IMAGE_FILE &&
        isDirectChildHref(collection.href, resource.href)
    })
    if (imageChildren.length > 0) {
      candidates.push({
        kind: DavComicCandidateKind.IMAGE_COLLECTION,
        href: collection.href,
        title: collection.displayname ?? readNameFromHref(collection.href),
        resources: imageChildren,
      })
    }
  })
  return candidates
}

export class WebDavClient {
  private server: WebDavServerConfig
  private credential?: WebDavResolvedCredential
  private http?: WebDavHttpAdapter

  constructor(options: WebDavClientOptions) {
    this.server = options.server
    this.credential = options.credential
    this.http = options.http
  }

  getBaseUrl(): string {
    return normalizeWebDavBaseUrl(this.server.baseUrl)
  }

  buildUrl(pathSegments: string[] = []): string {
    const root = this.server.rootPath === undefined ? [] : [this.server.rootPath]
    return buildWebDavUrl(this.server.baseUrl, root.concat(pathSegments))
  }

  buildHeaders(extraHeaders: WebDavHeaders = {}): WebDavHeaders {
    const authHeaders = buildWebDavAuthHeaders(this.server, this.credential)
    const headers: WebDavHeaders = {} as WebDavHeaders
    headers.authorization = extraHeaders.authorization === undefined ? authHeaders.authorization : extraHeaders.authorization
    headers.accept = extraHeaders.accept === undefined ? authHeaders.accept : extraHeaders.accept
    headers.contentType = extraHeaders.contentType === undefined ? authHeaders.contentType : extraHeaders.contentType
    headers.depth = extraHeaders.depth === undefined ? authHeaders.depth : extraHeaders.depth
    return headers
  }

  buildPropfindRequest(pathSegments: string[] = [], depth: 0 | 1 = 1): WebDavHttpRequest {
    return {
      method: 'PROPFIND',
      url: this.buildUrl(pathSegments),
      headers: this.buildHeaders({
        accept: 'application/xml, text/xml',
        contentType: 'application/xml; charset=utf-8',
        depth: `${depth}`,
      } as WebDavHeaders),
      body: buildPropfindBody(),
    }
  }

  buildGetRequest(pathSegments: string[] = []): WebDavHttpRequest {
    return {
      method: 'GET',
      url: this.buildUrl(pathSegments),
      headers: this.buildHeaders({ accept: '*/*' } as WebDavHeaders),
    }
  }

  async propfind(pathSegments: string[] = [], depth: 0 | 1 = 1): Promise<DavResource[]> {
    const response = await this.send(this.buildPropfindRequest(pathSegments, depth))
    if (response.status !== 207) {
      throw new Error(`WebDAV PROPFIND expected 207 but received ${response.status}`)
    }
    return parseWebDavMultiStatus(response.body, this.buildUrl(pathSegments))
  }

  getResourceUrl(resource: DavResource): string {
    return resource.href
  }

  private async send(request: WebDavHttpRequest): Promise<WebDavHttpResponse> {
    if (this.http === undefined) {
      throw new Error('WebDavHttpAdapter is required for network requests')
    }
    return this.http.request(request)
  }
}

function readSuccessfulPropstat(responseXml: string): string | undefined {
  const propstats = readXmlBlocks(responseXml, 'propstat')
  return propstats.find((propstat: string): boolean => {
    const status = readFirstXmlText(propstat, 'status') ?? ''
    return status.indexOf(' 200 ') >= 0 || status.endsWith(' 200 OK')
  })
}

function readXmlBlocks(xml: string, tagName: string): string[] {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${tagName}>`, 'gi')
  return Array.from(xml.matchAll(pattern)).map((match: RegExpMatchArray): string => match[1])
}

function readFirstXmlBlock(xml: string, tagName: string): string | undefined {
  const blocks = readXmlBlocks(xml, tagName)
  return blocks.length === 0 ? undefined : blocks[0]
}

function readFirstXmlText(xml: string, tagName: string): string | undefined {
  const block = readFirstXmlBlock(xml, tagName)
  if (block === undefined) {
    return undefined
  }
  const text = decodeXmlEntities(block.replace(/<[^>]+>/g, '').trim())
  return text.length === 0 ? undefined : text
}

function hasXmlTag(xml: string, tagName: string): boolean {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b(?:[^>]*)\\/?>`, 'i')
  return pattern.test(xml)
}

function decodeXmlEntities(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
}

function readNumber(value?: string): number | undefined {
  if (value === undefined || value.length === 0) {
    return undefined
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : undefined
}

function stripWeakEtag(value?: string): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const trimmed = value.trim()
  return trimmed.startsWith('W/') ? trimmed.substring(2) : trimmed
}

function stripQueryAndHash(value: string): string {
  return value.split('?')[0].split('#')[0]
}

function readNameFromHref(href: string): string {
  const pathname = readUrlPath(href)
  const trimmed = pathname.endsWith('/') ? pathname.substring(0, pathname.length - 1) : pathname
  const name = trimmed.split('/').pop()
  return name === undefined || name.length === 0 ? href : decodeURIComponent(name)
}

function isDirectChildHref(parentHref: string, childHref: string): boolean {
  if (readUrlOrigin(parentHref) !== readUrlOrigin(childHref)) {
    return false
  }
  const rawParentPath = readUrlPath(parentHref)
  const childPath = readUrlPath(childHref)
  const parentPath = rawParentPath.endsWith('/') ? rawParentPath : rawParentPath + '/'
  if (!childPath.startsWith(parentPath) || childPath === parentPath) {
    return false
  }
  const rest = childPath.substring(parentPath.length)
  return rest.length > 0 && rest.indexOf('/') < 0
}

function readUrlOrigin(value: string): string {
  const schemeIndex = value.indexOf('://')
  if (schemeIndex < 0) {
    return ''
  }
  const pathIndex = value.indexOf('/', schemeIndex + 3)
  if (pathIndex < 0) {
    return value
  }
  return value.substring(0, pathIndex)
}

export function readWebDavUrlPath(value: string): string {
  return readUrlPath(value)
}

function readUrlPath(value: string): string {
  const withoutQuery = stripQueryAndHash(value)
  const schemeIndex = withoutQuery.indexOf('://')
  if (schemeIndex < 0) {
    return withoutQuery.startsWith('/') ? withoutQuery : '/' + withoutQuery
  }
  const pathIndex = withoutQuery.indexOf('/', schemeIndex + 3)
  if (pathIndex < 0) {
    return '/'
  }
  return withoutQuery.substring(pathIndex)
}

function splitPathSegments(path: string): string[] {
  return path.split('/').filter((segment: string): boolean => segment.length > 0).map((segment: string): string => {
    return decodeURIComponent(segment)
  })
}

function flattenWebDavPathSegments(pathSegments: string[]): string[] {
  const flattened: string[] = []
  pathSegments.forEach((segment: string) => {
    segment.split('/').forEach((part: string) => {
      if (part.length > 0 && part !== '.') {
        flattened.push(part)
      }
    })
  })
  return flattened
}

function joinUrlPath(baseUrl: string, href: string): string {
  const origin = readUrlOrigin(baseUrl)
  const basePath = readUrlPath(baseUrl)
  const parentPath = basePath.endsWith('/') ? basePath : basePath.substring(0, basePath.lastIndexOf('/') + 1)
  return origin + parentPath + href
}
