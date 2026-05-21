import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/remote/KomgaModels.ets')
const clientPath = resolve(root, 'entry/src/main/ets/remote/KomgaClient.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const clientSource = readFileSync(clientPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type) ${symbol}\\b`), `${symbol} must be exported`)
}

function normalizeSortKey(value) {
  return value.trim().toLocaleLowerCase()
}

function normalizeKomgaBaseUrl(baseUrl) {
  return baseUrl.trim().replace(/\/+$/, '')
}

function buildKomgaUrl(baseUrl, path) {
  const normalized = normalizeKomgaBaseUrl(baseUrl)
  return path.startsWith('/') ? `${normalized}${path}` : `${normalized}/${path}`
}

function komgaPath(name, ...args) {
  if (name === 'libraries') return '/api/v1/libraries'
  if (name === 'seriesList') return '/api/v1/series/list'
  if (name === 'booksList') return '/api/v1/books/list'
  if (name === 'bookPages') return `/api/v1/books/${encodeURIComponent(args[0])}/pages`
  if (name === 'pageImage') {
    const [bookId, pageNumber, kind = 'stream'] = args
    const base = `/api/v1/books/${encodeURIComponent(bookId)}/pages/${pageNumber}`
    if (kind === 'raw') return `${base}/raw`
    if (kind === 'thumbnail') return `${base}/thumbnail`
    return base
  }
  throw new Error(`Unknown path helper: ${name}`)
}

function buildKomgaAuthHeaders(config, credential) {
  if (config.authKind === 'none') return {}
  if (!config.credentialRef) throw new Error('Komga credentialRef is required for authenticated requests')
  if (credential !== undefined && credential.credentialRef !== config.credentialRef) {
    throw new Error('Komga credentialRef mismatch')
  }
  if (credential === undefined) throw new Error('Komga credential material is required')
  if (config.authKind === 'basic') return { Authorization: `Basic ${credential.basicToken}` }
  if (config.authKind === 'api_key') return { 'X-API-Key': credential.apiKey }
  return { 'X-Auth-Token': credential.sessionToken }
}

function redactKomgaHeaders(headers) {
  const sensitive = new Set(['authorization', 'x-api-key', 'x-auth-token', 'cookie'])
  return Object.fromEntries(Object.entries(headers).map(([key, value]) => [
    key,
    sensitive.has(key.toLowerCase()) ? '<redacted>' : value,
  ]))
}

function redactKomgaRequest(request) {
  return {
    method: request.method,
    url: request.url,
    headers: redactKomgaHeaders(request.headers),
    body: request.body,
  }
}

function mapKomgaPageToPage(serverId, bookId, comicId, chapterId, page) {
  return {
    id: `komga:${serverId}:book:${bookId}:page:${page.number}`,
    comicId,
    chapterId,
    index: page.number - 1,
    fileName: page.fileName,
    uri: `komga://${serverId}/books/${bookId}/pages/${page.number}`,
    sortKey: normalizeSortKey(page.fileName),
    width: page.width,
    height: page.height,
    byteSize: page.sizeBytes,
  }
}

function mapKomgaBookToChapter(serverId, book, comicId, pages, fallbackIndex = 0, mappedAt = 1000) {
  const title = book.metadata?.title ?? book.name
  const numberSort = book.metadata?.numberSort ?? book.numberSort ?? fallbackIndex
  return {
    id: `komga:${serverId}:book:${book.id}`,
    comicId,
    title,
    index: numberSort,
    sourcePath: `komga://${serverId}/books/${book.id}`,
    sortKey: normalizeSortKey(`${numberSort}:${title}`),
    pages,
    pageCount: book.media?.pagesCount ?? pages.length,
    createdAt: mappedAt,
    updatedAt: mappedAt,
  }
}

function mapKomgaSeriesToComic(serverId, series, chapters, mappedAt = 1000) {
  const title = series.metadata?.title ?? series.name
  return {
    id: `komga:${serverId}:series:${series.id}`,
    title,
    subtitle: series.metadata?.summary,
    author: series.metadata?.authors?.map((author) => author.name).join(', '),
    sourceKind: 'private_library',
    sourcePath: `komga://${serverId}/series/${series.id}`,
    sortTitle: normalizeSortKey(series.metadata?.titleSort ?? series.sortName ?? title),
    preferredDirection: series.metadata?.readingDirection === 'LEFT_TO_RIGHT' ? 'left_to_right' : 'right_to_left',
    chapters,
    chapterCount: chapters.length,
    pageCount: chapters.reduce((sum, chapter) => sum + chapter.pageCount, 0),
    createdAt: mappedAt,
    updatedAt: mappedAt,
    lastImportedAt: mappedAt,
  }
}

class ExecutableKomgaClient {
  constructor(options) {
    this.server = options.server
    this.credential = options.credential
    this.http = options.http
  }

  buildUrl(path) {
    return buildKomgaUrl(this.server.baseUrl, path)
  }

  buildHeaders(extraHeaders = {}) {
    return {
      ...buildKomgaAuthHeaders(this.server, this.credential),
      ...extraHeaders,
    }
  }

  buildJsonRequest(method, path, body) {
    const headers = this.buildHeaders({ Accept: 'application/json' })
    if (method === 'POST') headers['Content-Type'] = 'application/json'
    return {
      method,
      url: this.buildUrl(path),
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    }
  }

  buildLibrariesRequest() {
    return this.buildJsonRequest('GET', komgaPath('libraries'))
  }

  buildSeriesListRequest(request = {}) {
    return this.buildJsonRequest('POST', komgaPath('seriesList'), request)
  }

  buildBooksListRequest(request = {}) {
    return this.buildJsonRequest('POST', komgaPath('booksList'), request)
  }

  buildBookPagesRequest(bookId) {
    return this.buildJsonRequest('GET', komgaPath('bookPages', bookId))
  }

  getPageImageUrl(bookId, pageNumber, kind = 'stream') {
    return this.buildUrl(komgaPath('pageImage', bookId, pageNumber, kind))
  }

  async listLibraries() {
    const response = await this.send(this.buildLibrariesRequest())
    return JSON.parse(response.body)
  }

  async listSeries(request = {}) {
    const response = await this.send(this.buildSeriesListRequest(request))
    return JSON.parse(response.body)
  }

  async listBooks(request = {}) {
    const response = await this.send(this.buildBooksListRequest(request))
    return JSON.parse(response.body)
  }

  async listBookPages(bookId) {
    const response = await this.send(this.buildBookPagesRequest(bookId))
    const parsed = JSON.parse(response.body)
    return Array.isArray(parsed) ? parsed : parsed.content
  }

  async send(request) {
    if (this.http === undefined) throw new Error('KomgaHttpAdapter is required for network requests')
    return this.http.request(request)
  }
}

class MockKomgaAdapter {
  constructor(routes) {
    this.routes = routes
    this.requests = []
  }

  async request(request) {
    this.requests.push(request)
    assert.doesNotMatch(request.url, /192\.168\.|localhost|127\.0\.0\.1/, 'test must not target a real service')
    const route = this.routes.find((item) => item.method === request.method && item.url === request.url)
    assert.ok(route, `Unexpected Komga request: ${request.method} ${request.url}`)
    if (route.body !== undefined) assert.equal(request.body, JSON.stringify(route.body), 'request body must match route contract')
    if (route.assertHeaders !== undefined) route.assertHeaders(request.headers)
    return {
      status: 200,
      body: JSON.stringify(route.response),
    }
  }
}

const originalFetch = globalThis.fetch
let networkAttempted = false
globalThis.fetch = async () => {
  networkAttempted = true
  throw new Error('Real network fetch is forbidden in Komga mock adapter tests')
}

try {
  for (const symbol of [
    'KomgaServerConfig',
    'KomgaAccount',
    'KomgaResolvedCredential',
    'KomgaLibraryDto',
    'KomgaSeriesDto',
    'KomgaBookDto',
    'KomgaPageDto',
    'RemotePageRef',
    'mapKomgaSeriesToComic',
    'mapKomgaBookToChapter',
    'mapKomgaPageToPage',
  ]) {
    assertExport(modelSource, symbol)
  }

  for (const symbol of [
    'KomgaPaths',
    'KomgaClient',
    'KomgaHttpAdapter',
    'buildKomgaAuthHeaders',
    'redactKomgaHeaders',
    'redactKomgaRequest',
    'buildKomgaUrl',
    'createRemotePageRef',
  ]) {
    assertExport(clientSource, symbol)
  }

  assert.match(clientSource, /http\.request\(request\)/, 'KomgaClient must delegate network calls to the injected adapter')
  assert.doesNotMatch(clientSource, /\bfetch\s*\(/, 'KomgaClient must not call fetch directly')

  const token = 'runtime-api-key-placeholder'
  const server = {
    id: 'server-1',
    name: 'Mock Komga',
    baseUrl: 'https://komga.invalid///',
    authKind: 'api_key',
    credentialRef: 'cred-komga-ref',
  }
  const credential = {
    credentialRef: 'cred-komga-ref',
    apiKey: token,
  }

  const libraryDto = { id: 'lib-1', name: 'Private Shelf', type: 'books' }
  const seriesDto = {
    id: 'series-1',
    name: 'Server Name',
    sortName: 'server name',
    metadata: {
      title: 'Actual Title',
      titleSort: 'actual title',
      summary: 'Private library series',
      authors: [{ name: 'Author A' }, { name: 'Author B' }],
      readingDirection: 'LEFT_TO_RIGHT',
    },
    booksCount: 1,
  }
  const bookDto = {
    id: 'book id/1',
    seriesId: 'series-1',
    name: 'File.cbz',
    numberSort: 4,
    media: { pagesCount: 2, mediaType: 'application/zip' },
    metadata: { title: 'Chapter 5', numberSort: 5 },
  }
  const pageDtos = [
    { number: 1, fileName: '001.JPG', mediaType: 'image/jpeg', width: 1200, height: 1800, sizeBytes: 42 },
    { number: 2, fileName: '002.PNG', mediaType: 'image/png', width: 1200, height: 1800, sizeBytes: 43 },
  ]

  const base = 'https://komga.invalid'
  const assertJsonApiKeyHeaders = (headers) => {
    assert.equal(headers.Accept, 'application/json')
    assert.equal(headers['X-API-Key'], token)
    assert.equal(headers.Authorization, undefined)
  }
  const adapter = new MockKomgaAdapter([
    {
      method: 'GET',
      url: `${base}/api/v1/libraries`,
      assertHeaders: assertJsonApiKeyHeaders,
      response: [libraryDto],
    },
    {
      method: 'POST',
      url: `${base}/api/v1/series/list`,
      body: { page: 0, size: 20, libraryIds: ['lib-1'], sort: ['metadata.titleSort,asc'] },
      assertHeaders: (headers) => {
        assertJsonApiKeyHeaders(headers)
        assert.equal(headers['Content-Type'], 'application/json')
      },
      response: { content: [seriesDto], totalElements: 1, size: 20, number: 0 },
    },
    {
      method: 'POST',
      url: `${base}/api/v1/books/list`,
      body: { page: 0, size: 50, seriesIds: ['series-1'], sort: ['metadata.numberSort,asc'] },
      assertHeaders: (headers) => {
        assertJsonApiKeyHeaders(headers)
        assert.equal(headers['Content-Type'], 'application/json')
      },
      response: { content: [bookDto], totalElements: 1, size: 50, number: 0 },
    },
    {
      method: 'GET',
      url: `${base}/api/v1/books/book%20id%2F1/pages`,
      assertHeaders: assertJsonApiKeyHeaders,
      response: { content: pageDtos },
    },
  ])

  const client = new ExecutableKomgaClient({ server, credential, http: adapter })
  assert.equal(server.credentialRef, credential.credentialRef, 'credentialRef must identify secret material without storing it')
  assert.notEqual(server.credentialRef, token, 'credentialRef must not equal the runtime secret')

  const libraries = await client.listLibraries()
  const seriesPage = await client.listSeries({ page: 0, size: 20, libraryIds: ['lib-1'], sort: ['metadata.titleSort,asc'] })
  const booksPage = await client.listBooks({ page: 0, size: 50, seriesIds: ['series-1'], sort: ['metadata.numberSort,asc'] })
  const pages = await client.listBookPages('book id/1')

  assert.deepEqual(libraries, [libraryDto])
  assert.equal(seriesPage.content[0].metadata.title, 'Actual Title')
  assert.equal(booksPage.content[0].id, 'book id/1')
  assert.deepEqual(pages, pageDtos)

  assert.deepEqual(adapter.requests.map((request) => [request.method, new URL(request.url).pathname]), [
    ['GET', '/api/v1/libraries'],
    ['POST', '/api/v1/series/list'],
    ['POST', '/api/v1/books/list'],
    ['GET', '/api/v1/books/book%20id%2F1/pages'],
  ])

  const redactedRequests = adapter.requests.map(redactKomgaRequest)
  const redactedLog = JSON.stringify(redactedRequests)
  assert.doesNotMatch(redactedLog, new RegExp(token), 'redacted request logs must not leak token material')
  assert.match(redactedLog, /<redacted>/, 'redacted request logs must preserve evidence of redaction')
  assert.equal(redactedRequests[0].headers['X-API-Key'], '<redacted>')

  const pageUrl = client.getPageImageUrl('book id/1', 2, 'raw')
  assert.equal(pageUrl, 'https://komga.invalid/api/v1/books/book%20id%2F1/pages/2/raw')
  assert.equal(client.getPageImageUrl('book id/1', 2, 'thumbnail'), 'https://komga.invalid/api/v1/books/book%20id%2F1/pages/2/thumbnail')

  const comicId = `komga:${server.id}:series:${seriesDto.id}`
  const chapterId = `komga:${server.id}:book:${bookDto.id}`
  const mappedPages = pages.map((page) => mapKomgaPageToPage(server.id, bookDto.id, comicId, chapterId, page))
  const chapter = mapKomgaBookToChapter(server.id, bookDto, comicId, mappedPages)
  const comic = mapKomgaSeriesToComic(server.id, seriesDto, [chapter])

  assert.equal(mappedPages[0].id, `komga:${server.id}:book:${bookDto.id}:page:1`)
  assert.equal(mappedPages[0].index, 0)
  assert.equal(mappedPages[0].uri, `komga://${server.id}/books/${bookDto.id}/pages/1`)
  assert.equal(mappedPages[0].sortKey, '001.jpg')
  assert.equal(mappedPages[0].width, 1200)
  assert.equal(chapter.id, chapterId)
  assert.equal(chapter.title, 'Chapter 5')
  assert.equal(chapter.pageCount, 2)
  assert.equal(chapter.index, 5)
  assert.equal(comic.id, comicId)
  assert.equal(comic.sourceKind, 'private_library')
  assert.equal(comic.author, 'Author A, Author B')
  assert.equal(comic.preferredDirection, 'left_to_right')
  assert.equal(comic.chapterCount, 1)
  assert.equal(comic.pageCount, 2)

  assert.throws(() => buildKomgaAuthHeaders(
    { id: 'server-1', baseUrl: 'https://komga.invalid', authKind: 'api_key', credentialRef: 'cred-a' },
    { credentialRef: 'cred-b', apiKey: token },
  ), /credentialRef/)

  assert.equal(networkAttempted, false, 'fetch guard must remain unused')
  assert.equal(adapter.requests.length, 4, 'all remote list/page calls must go through the mock adapter')
  assert.doesNotMatch(modelSource + clientSource, /password|secret/i, 'Komga skeleton should not define persisted password/secret fields')

  console.log('PASS Komga mock adapter executable contracts')
} finally {
  globalThis.fetch = originalFetch
}
