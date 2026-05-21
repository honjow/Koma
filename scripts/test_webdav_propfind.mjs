import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/remote/WebDavModels.ets')
const clientPath = resolve(root, 'entry/src/main/ets/remote/WebDavClient.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const clientSource = readFileSync(clientPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

const DavComicCandidateKind = {
  ARCHIVE: 'archive',
  IMAGE_FILE: 'image_file',
  IMAGE_COLLECTION: 'image_collection',
  UNSUPPORTED: 'unsupported',
}

const archiveExtensions = ['.cbz', '.zip']
const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp']

function normalizeWebDavBaseUrl(baseUrl) {
  return baseUrl.trim().replace(/\/+$/, '')
}

function resolveWebDavHref(baseUrl, href) {
  try {
    return new URL(href, baseUrl).toString()
  } catch {
    return href
  }
}

function buildWebDavUrl(baseUrl, pathSegments = []) {
  const base = new URL(`${normalizeWebDavBaseUrl(baseUrl)}/`)
  const baseSegments = base.pathname.split('/').filter(Boolean)
  const nextSegments = pathSegments
    .flatMap((segment) => segment.split('/'))
    .filter((segment) => segment.length > 0 && segment !== '.')

  for (const segment of nextSegments) {
    if (segment === '..') {
      if (baseSegments.length > 0) baseSegments.pop()
    } else {
      baseSegments.push(segment)
    }
  }

  base.pathname = `/${baseSegments.map((segment) => encodeURIComponent(segment)).join('/')}`
  return base.toString()
}

function buildWebDavAuthHeaders(config, credential) {
  if (config.authKind === 'none') return {}
  if (!config.credentialRef) throw new Error('WebDAV credentialRef is required for authenticated requests')
  if (credential !== undefined && credential.credentialRef !== config.credentialRef) throw new Error('WebDAV credentialRef mismatch')
  if (credential === undefined) throw new Error('WebDAV credential material is required')
  if (!credential.basicToken) throw new Error('WebDAV Basic credential token is required')
  return { Authorization: `Basic ${credential.basicToken}` }
}

function redactWebDavHeaders(headers) {
  const sensitive = new Set(['authorization', 'cookie', 'x-auth-token'])
  return Object.fromEntries(Object.entries(headers).map(([key, value]) => [
    key,
    sensitive.has(key.toLowerCase()) ? '<redacted>' : value,
  ]))
}

function redactWebDavRequest(request) {
  return { method: request.method, url: request.url, headers: redactWebDavHeaders(request.headers), body: request.body }
}

function buildPropfindBody() {
  return '<?xml version="1.0" encoding="utf-8"?>' +
    '<d:propfind xmlns:d="DAV:"><d:prop>' +
    '<d:displayname/><d:resourcetype/><d:getcontentlength/>' +
    '<d:getcontenttype/><d:getlastmodified/><d:getetag/>' +
    '</d:prop></d:propfind>'
}

function decodeXmlEntities(value) {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
}

function readXmlBlocks(xml, tagName) {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${tagName}>`, 'gi')
  return [...xml.matchAll(pattern)].map((match) => match[1])
}

function readFirstXmlBlock(xml, tagName) {
  return readXmlBlocks(xml, tagName)[0]
}

function readFirstXmlText(xml, tagName) {
  const block = readFirstXmlBlock(xml, tagName)
  if (block === undefined) return undefined
  const text = decodeXmlEntities(block.replace(/<[^>]+>/g, '').trim())
  return text.length === 0 ? undefined : text
}

function hasXmlTag(xml, tagName) {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b(?:[^>]*)\\/?>`, 'i')
  return pattern.test(xml)
}

function readSuccessfulPropstat(responseXml) {
  return readXmlBlocks(responseXml, 'propstat').find((propstat) => {
    const status = readFirstXmlText(propstat, 'status') ?? ''
    return status.includes(' 200 ') || status.endsWith(' 200 OK')
  })
}

function stripWeakEtag(value) {
  if (value === undefined) return undefined
  return value.trim().startsWith('W/') ? value.trim().slice(2) : value.trim()
}

function classifyDavResource(resource) {
  if (resource.isCollection) return DavComicCandidateKind.UNSUPPORTED
  const lowerHref = resource.href.split('?')[0].split('#')[0].toLowerCase()
  const contentType = resource.contentType === undefined ? '' : resource.contentType.toLowerCase().split(';')[0].trim()
  if (archiveExtensions.some((extension) => lowerHref.endsWith(extension))) return DavComicCandidateKind.ARCHIVE
  if (imageExtensions.some((extension) => lowerHref.endsWith(extension)) || contentType.startsWith('image/')) {
    return DavComicCandidateKind.IMAGE_FILE
  }
  return DavComicCandidateKind.UNSUPPORTED
}

function parseWebDavMultiStatus(xml, baseUrl) {
  return readXmlBlocks(xml, 'response').map((responseXml) => {
    const href = resolveWebDavHref(baseUrl, readFirstXmlText(responseXml, 'href') ?? '')
    const propstat = readSuccessfulPropstat(responseXml) ?? responseXml
    const resource = {
      href,
      displayname: readFirstXmlText(propstat, 'displayname'),
      isCollection: hasXmlTag(propstat, 'collection'),
      contentLength: Number(readFirstXmlText(propstat, 'getcontentlength')) || undefined,
      contentType: readFirstXmlText(propstat, 'getcontenttype'),
      lastModified: readFirstXmlText(propstat, 'getlastmodified'),
      etag: stripWeakEtag(readFirstXmlText(propstat, 'getetag')),
      candidateKind: DavComicCandidateKind.UNSUPPORTED,
    }
    resource.candidateKind = classifyDavResource(resource)
    return resource
  })
}

function readNameFromHref(href) {
  const pathname = new URL(href).pathname
  const trimmed = pathname.endsWith('/') ? pathname.slice(0, -1) : pathname
  return decodeURIComponent(trimmed.split('/').pop() || href)
}

function isDirectChildHref(parentHref, childHref) {
  const parent = new URL(parentHref)
  const child = new URL(childHref)
  if (parent.origin !== child.origin) return false
  const parentPath = parent.pathname.endsWith('/') ? parent.pathname : `${parent.pathname}/`
  if (!child.pathname.startsWith(parentPath) || child.pathname === parentPath) return false
  const rest = child.pathname.slice(parentPath.length)
  return rest.length > 0 && !rest.includes('/')
}

function detectWebDavComicCandidates(resources) {
  const candidates = []
  for (const resource of resources) {
    if (resource.candidateKind === DavComicCandidateKind.ARCHIVE || resource.candidateKind === DavComicCandidateKind.IMAGE_FILE) {
      candidates.push({
        kind: resource.candidateKind,
        href: resource.href,
        title: resource.displayname ?? readNameFromHref(resource.href),
        resources: [resource],
      })
    }
  }
  for (const collection of resources.filter((resource) => resource.isCollection)) {
    const imageChildren = resources.filter((resource) => (
      !resource.isCollection &&
      resource.candidateKind === DavComicCandidateKind.IMAGE_FILE &&
      isDirectChildHref(collection.href, resource.href)
    ))
    if (imageChildren.length > 0) {
      candidates.push({
        kind: DavComicCandidateKind.IMAGE_COLLECTION,
        href: collection.href,
        title: collection.displayname ?? readNameFromHref(collection.href),
        resources: imageChildren,
      })
    }
  }
  return candidates
}

class ExecutableWebDavClient {
  constructor(options) {
    this.server = options.server
    this.credential = options.credential
    this.http = options.http
  }

  buildUrl(pathSegments = []) {
    const root = this.server.rootPath === undefined ? [] : [this.server.rootPath]
    return buildWebDavUrl(this.server.baseUrl, root.concat(pathSegments))
  }

  buildHeaders(extraHeaders = {}) {
    return { ...buildWebDavAuthHeaders(this.server, this.credential), ...extraHeaders }
  }

  buildPropfindRequest(pathSegments = [], depth = 1) {
    return {
      method: 'PROPFIND',
      url: this.buildUrl(pathSegments),
      headers: this.buildHeaders({
        Accept: 'application/xml, text/xml',
        'Content-Type': 'application/xml; charset=utf-8',
        Depth: `${depth}`,
      }),
      body: buildPropfindBody(),
    }
  }

  async propfind(pathSegments = [], depth = 1) {
    const response = await this.http.request(this.buildPropfindRequest(pathSegments, depth))
    assert.equal(response.status, 207)
    return parseWebDavMultiStatus(response.body, this.buildUrl(pathSegments))
  }
}

class MockWebDavAdapter {
  constructor(routes) {
    this.routes = routes
    this.requests = []
  }

  async request(request) {
    this.requests.push(request)
    assert.doesNotMatch(request.url, /192\.168\.|localhost|127\.0\.0\.1/, 'test must not target a real service')
    const route = this.routes.find((item) => item.method === request.method && item.url === request.url)
    assert.ok(route, `Unexpected WebDAV request: ${request.method} ${request.url}`)
    route.assertRequest?.(request)
    return { status: 207, body: route.response }
  }
}

const fixture = `<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/Manga/Volume%2001/</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>Volume 01</d:displayname>
        <d:resourcetype><d:collection/></d:resourcetype>
        <d:getlastmodified>Thu, 21 May 2026 01:01:00 GMT</d:getlastmodified>
        <d:getetag>"dir-etag"</d:getetag>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/Manga/Volume%2001/001.jpg</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>001.jpg</d:displayname>
        <d:getcontentlength>12345</d:getcontentlength>
        <d:getcontenttype>image/jpeg</d:getcontenttype>
        <d:getlastmodified>Thu, 21 May 2026 01:02:00 GMT</d:getlastmodified>
        <d:getetag>W/"img-etag"</d:getetag>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/Manga/Volume%2001/002.PNG</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>002.PNG</d:displayname>
        <d:getcontentlength>23456</d:getcontentlength>
        <d:getcontenttype>application/octet-stream</d:getcontenttype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/Manga/Standalone.cbz</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>Standalone.cbz</d:displayname>
        <d:getcontentlength>456789</d:getcontentlength>
        <d:getcontenttype>application/x-cbz</d:getcontenttype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/Manga/notes.txt</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>notes.txt</d:displayname>
        <d:getcontenttype>text/plain</d:getcontenttype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>`

const originalFetch = globalThis.fetch
let networkAttempted = false
globalThis.fetch = async () => {
  networkAttempted = true
  throw new Error('Real network fetch is forbidden in WebDAV tests')
}

try {
  for (const symbol of [
    'WebDavServerConfig',
    'WebDavResolvedCredential',
    'DavResource',
    'DavComicCandidate',
    'DavComicCandidateKind',
    'WEBDAV_ARCHIVE_EXTENSIONS',
    'WEBDAV_IMAGE_EXTENSIONS',
  ]) {
    assertExport(modelSource, symbol)
  }

  for (const symbol of [
    'WebDavClient',
    'WebDavHttpAdapter',
    'buildWebDavAuthHeaders',
    'redactWebDavRequest',
    'buildWebDavUrl',
    'resolveWebDavHref',
    'parseWebDavMultiStatus',
    'detectWebDavComicCandidates',
    'buildPropfindBody',
  ]) {
    assertExport(clientSource, symbol)
  }

  assert.match(clientSource, /method: 'PROPFIND'/, 'WebDAV request builder must use PROPFIND')
  assert.match(clientSource, /http\.request\(request\)/, 'WebDavClient must delegate network calls to the injected adapter')
  assert.doesNotMatch(clientSource, /\bfetch\s*\(/, 'WebDavClient must not call fetch directly')
  assert.doesNotMatch(modelSource + clientSource, /PUT|DELETE|MOVE|MKCOL|COPY|LOCK/, 'WebDAV lane must stay read-only')
  assert.doesNotMatch(modelSource + clientSource, /password|secret/i, 'WebDAV skeleton should not define persisted password/secret fields')

  const server = {
    id: 'webdav-1',
    name: 'Fixture WebDAV',
    baseUrl: 'https://dav.invalid/dav///',
    rootPath: 'Manga',
    authKind: 'basic',
    credentialRef: 'cred-webdav-ref',
  }
  const token = 'runtime-basic-token-placeholder'
  const credential = { credentialRef: 'cred-webdav-ref', basicToken: token }

  assert.equal(buildWebDavUrl('https://dav.invalid/dav', ['Manga', 'Space Name', 'Vol#1.cbz']), 'https://dav.invalid/dav/Manga/Space%20Name/Vol%231.cbz')
  assert.equal(buildWebDavUrl('https://dav.invalid/dav', ['Manga/Volume 01']), 'https://dav.invalid/dav/Manga/Volume%2001')
  assert.equal(resolveWebDavHref('https://dav.invalid/dav/Manga/', 'Volume%2001/001.jpg'), 'https://dav.invalid/dav/Manga/Volume%2001/001.jpg')

  const adapter = new MockWebDavAdapter([
    {
      method: 'PROPFIND',
      url: 'https://dav.invalid/dav/Manga/Volume%2001',
      response: fixture,
      assertRequest: (request) => {
        assert.equal(request.headers.Depth, '1')
        assert.equal(request.headers.Authorization, `Basic ${token}`)
        assert.match(request.body, /getcontentlength/)
      },
    },
    {
      method: 'PROPFIND',
      url: 'https://dav.invalid/dav/Manga',
      response: fixture,
      assertRequest: (request) => {
        assert.equal(request.headers.Depth, '0')
      },
    },
  ])

  const client = new ExecutableWebDavClient({ server, credential, http: adapter })
  const depthOneRequest = client.buildPropfindRequest(['Volume 01'], 1)
  const depthZeroRequest = client.buildPropfindRequest([], 0)
  assert.equal(depthOneRequest.method, 'PROPFIND')
  assert.equal(depthOneRequest.headers.Depth, '1')
  assert.equal(depthZeroRequest.headers.Depth, '0')
  assert.equal(server.credentialRef, credential.credentialRef, 'credentialRef must identify secret material without storing it')
  assert.notEqual(server.credentialRef, token, 'credentialRef must not equal the runtime credential material')

  const resources = await client.propfind(['Volume 01'], 1)
  assert.equal(resources.length, 5)
  assert.equal(resources[0].href, 'https://dav.invalid/dav/Manga/Volume%2001/')
  assert.equal(resources[0].isCollection, true)
  assert.equal(resources[1].contentLength, 12345)
  assert.equal(resources[1].contentType, 'image/jpeg')
  assert.equal(resources[1].etag, '"img-etag"')
  assert.equal(resources[1].candidateKind, DavComicCandidateKind.IMAGE_FILE)
  assert.equal(resources[2].candidateKind, DavComicCandidateKind.IMAGE_FILE, 'image extension must work when MIME is generic')
  assert.equal(resources[3].candidateKind, DavComicCandidateKind.ARCHIVE)
  assert.equal(resources[4].candidateKind, DavComicCandidateKind.UNSUPPORTED)

  const candidates = detectWebDavComicCandidates(resources)
  assert.deepEqual(candidates.map((candidate) => candidate.kind), [
    DavComicCandidateKind.IMAGE_FILE,
    DavComicCandidateKind.IMAGE_FILE,
    DavComicCandidateKind.ARCHIVE,
    DavComicCandidateKind.IMAGE_COLLECTION,
  ])
  assert.equal(candidates.at(-1).href, 'https://dav.invalid/dav/Manga/Volume%2001/')
  assert.equal(candidates.at(-1).resources.length, 2)

  await client.propfind([], 0)
  const redactedRequests = adapter.requests.map(redactWebDavRequest)
  const redactedLog = JSON.stringify(redactedRequests)
  assert.doesNotMatch(redactedLog, new RegExp(token), 'redacted request logs must not leak Basic material')
  assert.match(redactedLog, /<redacted>/, 'redacted request logs must preserve evidence of redaction')
  assert.equal(redactedRequests[0].headers.Authorization, '<redacted>')

  assert.throws(() => buildWebDavAuthHeaders(
    { id: 'webdav-1', baseUrl: 'https://dav.invalid', authKind: 'basic', credentialRef: 'cred-a' },
    { credentialRef: 'cred-b', basicToken: token },
  ), /credentialRef/)

  assert.equal(networkAttempted, false, 'fetch guard must remain unused')
  assert.equal(adapter.requests.length, 2, 'all WebDAV calls must go through the mock adapter')

  console.log('PASS WebDAV PROPFIND fixture contracts')
} finally {
  globalThis.fetch = originalFetch
}
