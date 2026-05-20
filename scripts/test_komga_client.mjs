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

function pageImage(bookId, pageNumber, kind = 'stream') {
  const base = `/api/v1/books/${encodeURIComponent(bookId)}/pages/${pageNumber}`
  if (kind === 'raw') return `${base}/raw`
  if (kind === 'thumbnail') return `${base}/thumbnail`
  return base
}

function buildKomgaAuthHeaders(config, credential) {
  if (config.authKind === 'none') return {}
  assert.equal(config.credentialRef, credential?.credentialRef, 'credentialRef must match before secret material is used')
  if (config.authKind === 'basic') return { Authorization: `Basic ${credential.basicToken}` }
  if (config.authKind === 'api_key') return { 'X-API-Key': credential.apiKey }
  return { 'X-Auth-Token': credential.sessionToken }
}

function redactKomgaHeaders(headers) {
  const out = {}
  for (const [key, value] of Object.entries(headers)) {
    out[key] = ['authorization', 'x-api-key', 'x-auth-token', 'cookie'].includes(key.toLowerCase()) ? '<redacted>' : value
  }
  return out
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
    preferredDirection: 'right_to_left',
    chapters,
    chapterCount: chapters.length,
    pageCount: chapters.reduce((sum, chapter) => sum + chapter.pageCount, 0),
    createdAt: mappedAt,
    updatedAt: mappedAt,
    lastImportedAt: mappedAt,
  }
}

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
  'buildKomgaUrl',
  'createRemotePageRef',
]) {
  assertExport(clientSource, symbol)
}

assert.equal(buildKomgaUrl('https://komga.example.test///', '/api/v1/libraries'), 'https://komga.example.test/api/v1/libraries')
assert.equal(pageImage('book id/1', 3), '/api/v1/books/book%20id%2F1/pages/3')
assert.equal(pageImage('book id/1', 3, 'raw'), '/api/v1/books/book%20id%2F1/pages/3/raw')
assert.equal(pageImage('book id/1', 3, 'thumbnail'), '/api/v1/books/book%20id%2F1/pages/3/thumbnail')

const apiKeyHeaders = buildKomgaAuthHeaders(
  { id: 'server-1', baseUrl: 'https://komga.example.test', authKind: 'api_key', credentialRef: 'cred-komga' },
  { credentialRef: 'cred-komga', apiKey: 'runtime-api-key-placeholder' },
)
assert.deepEqual(apiKeyHeaders, { 'X-API-Key': 'runtime-api-key-placeholder' })
assert.deepEqual(redactKomgaHeaders({ ...apiKeyHeaders, Accept: 'application/json' }), {
  'X-API-Key': '<redacted>',
  Accept: 'application/json',
})

const basicHeaders = buildKomgaAuthHeaders(
  { id: 'server-1', baseUrl: 'https://komga.example.test', authKind: 'basic', credentialRef: 'cred-basic' },
  { credentialRef: 'cred-basic', basicToken: 'base64-placeholder' },
)
assert.deepEqual(basicHeaders, { Authorization: 'Basic base64-placeholder' })
assert.deepEqual(redactKomgaHeaders(basicHeaders), { Authorization: '<redacted>' })

assert.throws(() => buildKomgaAuthHeaders(
  { id: 'server-1', baseUrl: 'https://komga.example.test', authKind: 'api_key', credentialRef: 'cred-a' },
  { credentialRef: 'cred-b', apiKey: 'runtime-api-key-placeholder' },
), /credentialRef/)

const comicId = 'komga:server-1:series:series-1'
const chapterId = 'komga:server-1:book:book-1'
const pages = [
  mapKomgaPageToPage('server-1', 'book-1', comicId, chapterId, {
    number: 1,
    fileName: '001.JPG',
    width: 1200,
    height: 1800,
    sizeBytes: 42,
  }),
]
assert.equal(pages[0].index, 0)
assert.equal(pages[0].uri, 'komga://server-1/books/book-1/pages/1')
assert.equal(pages[0].sortKey, '001.jpg')

const chapter = mapKomgaBookToChapter('server-1', {
  id: 'book-1',
  seriesId: 'series-1',
  name: 'File.cbz',
  metadata: { title: 'Chapter 5', numberSort: 5 },
  media: { pagesCount: 12 },
}, comicId, pages)
assert.equal(chapter.id, chapterId)
assert.equal(chapter.pageCount, 12)
assert.equal(chapter.index, 5)

const comic = mapKomgaSeriesToComic('server-1', {
  id: 'series-1',
  name: 'Server Name',
  metadata: {
    title: 'Actual Title',
    titleSort: 'actual title',
    summary: 'Private library series',
    authors: [{ name: 'Author A' }, { name: 'Author B' }],
  },
}, [chapter])
assert.equal(comic.id, comicId)
assert.equal(comic.sourceKind, 'private_library')
assert.equal(comic.author, 'Author A, Author B')
assert.equal(comic.chapterCount, 1)
assert.equal(comic.pageCount, 12)

assert.doesNotMatch(modelSource + clientSource, /password|secret/i, 'Komga skeleton should not define persisted password/secret fields')
assert.match(clientSource, /'<redacted>'/, 'sensitive headers must have a redaction helper')

console.log('PASS Komga client contracts')
