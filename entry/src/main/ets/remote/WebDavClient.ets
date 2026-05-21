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
  [key: string]: string
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
  try {
    return new URL(href, baseUrl).toString()
  } catch (error) {
    return href
  }
}

export function buildWebDavUrl(baseUrl: string, pathSegments: string[] = []): string {
  const base = new URL(normalizeWebDavBaseUrl(baseUrl) + '/')
  const baseSegments = base.pathname.split('/').filter((segment: string) => segment.length > 0)
  const nextSegments = pathSegments
    .map((segment: string): string[] => segment.split('/'))
    .reduce((all: string[], parts: string[]): string[] => all.concat(parts), [])
    .filter((segment: string) => segment.length > 0 && segment !== '.')

  nextSegments.forEach((segment: string) => {
    if (segment === '..') {
      if (baseSegments.length > 0) {
        baseSegments.pop()
      }
    } else {
      baseSegments.push(segment)
    }
  })

  base.pathname = '/' + baseSegments.map((segment: string) => encodeURIComponent(segment)).join('/')
  return base.toString()
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
  return { 'Authorization': `Basic ${credential.basicToken}` }
}

export function redactWebDavHeaders(headers: WebDavHeaders): WebDavHeaders {
  const redacted: WebDavHeaders = {}
  Object.keys(headers).forEach((key: string) => {
    redacted[key] = isSensitiveHeader(key) ? '<redacted>' : headers[key]
  })
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
    return {
      ...buildWebDavAuthHeaders(this.server, this.credential),
      ...extraHeaders,
    }
  }

  buildPropfindRequest(pathSegments: string[] = [], depth: 0 | 1 = 1): WebDavHttpRequest {
    return {
      method: 'PROPFIND',
      url: this.buildUrl(pathSegments),
      headers: this.buildHeaders({
        'Accept': 'application/xml, text/xml',
        'Content-Type': 'application/xml; charset=utf-8',
        'Depth': `${depth}`,
      }),
      body: buildPropfindBody(),
    }
  }

  buildGetRequest(pathSegments: string[] = []): WebDavHttpRequest {
    return {
      method: 'GET',
      url: this.buildUrl(pathSegments),
      headers: this.buildHeaders({ 'Accept': '*/*' }),
    }
  }

  async propfind(pathSegments: string[] = [], depth: 0 | 1 = 1): Promise<DavResource[]> {
    const response = await this.send(this.buildPropfindRequest(pathSegments, depth))
    if (response.status !== 207) {
      throw new Error(`WebDAV PROPFIND expected 207 but received ${response.status}`)
    }
    return parseWebDavMultiStatus(response.body, this.buildUrl(pathSegments))
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
  const pathname = new URL(href).pathname
  const trimmed = pathname.endsWith('/') ? pathname.substring(0, pathname.length - 1) : pathname
  const name = trimmed.split('/').pop()
  return name === undefined || name.length === 0 ? href : decodeURIComponent(name)
}

function isDirectChildHref(parentHref: string, childHref: string): boolean {
  const parent = new URL(parentHref)
  const child = new URL(childHref)
  if (parent.origin !== child.origin) {
    return false
  }
  const parentPath = parent.pathname.endsWith('/') ? parent.pathname : parent.pathname + '/'
  if (!child.pathname.startsWith(parentPath) || child.pathname === parentPath) {
    return false
  }
  const rest = child.pathname.substring(parentPath.length)
  return rest.length > 0 && rest.indexOf('/') < 0
}

function isSensitiveHeader(key: string): boolean {
  const normalized = key.toLocaleLowerCase()
  return normalized === 'authorization' || normalized === 'cookie' || normalized === 'x-auth-token'
}
