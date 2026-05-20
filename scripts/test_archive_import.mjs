import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const sortPath = resolve(root, 'entry/src/main/ets/import/ImageSortUtils.ets')
const servicePath = resolve(root, 'entry/src/main/ets/import/ArchiveImportService.ets')
const extractionServicePath = resolve(root, 'entry/src/main/ets/import/ArchiveExtractionService.ets')
const sortSource = readFileSync(sortPath, 'utf8')
const serviceSource = readFileSync(servicePath, 'utf8')
const extractionServiceSource = readFileSync(extractionServicePath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|const) ${symbol}\\b`), `${symbol} must be exported`)
}

function getBaseName(path) {
  const normalized = path.replace(/\\/g, '/').trim()
  const parts = normalized.split('/').filter((part) => part.length > 0)
  return parts.length === 0 ? normalized : parts.at(-1)
}

function getExtension(path) {
  const baseName = getBaseName(path)
  const dotIndex = baseName.lastIndexOf('.')
  if (dotIndex <= 0 || dotIndex === baseName.length - 1) return ''
  return baseName.substring(dotIndex).toLocaleLowerCase()
}

function stripExtension(path) {
  const baseName = getBaseName(path)
  const dotIndex = baseName.lastIndexOf('.')
  return dotIndex <= 0 ? baseName : baseName.substring(0, dotIndex)
}

function normalizeSeparator(value) {
  return value.replace(/\\/g, '/')
}

function sanitizeCacheSegment(value) {
  const normalized = stripExtension(getBaseName(value)).trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, '-')
  const trimmed = normalized.replace(/^-+|-+$/g, '')
  return trimmed.length === 0 ? 'archive' : trimmed
}

function createStableCacheHash(value) {
  const normalized = normalizeSeparator(value).trim()
  let hash = 2166136261
  for (let index = 0; index < normalized.length; index += 1) {
    hash = (hash ^ normalized.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash.toString(16).padStart(8, '0')
}

function createArchiveExtractionCachePaths(cacheDir, archivePath, cacheKeySeed) {
  const readableSegment = sanitizeCacheSegment(archivePath)
  const uniqueSegment = createStableCacheHash(cacheKeySeed ?? archivePath)
  const rootDir = `${cacheDir.replace(/\/+$/, '')}/import/${readableSegment}-${uniqueSegment}`
  return {
    rootDir,
    archiveZipPath: `${rootDir}/archive.zip`,
    extractionDir: `${rootDir}/extract`,
    manifestPath: `${rootDir}/manifest.json`,
  }
}

function isSafeArchiveEntryPath(path) {
  const normalized = path.replace(/\\/g, '/').trim()
  if (normalized.length === 0 || normalized.startsWith('/')) return false
  return !normalized.split('/').some((part) => part === '..')
}

function isSupportedImagePath(path) {
  return ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'].includes(getExtension(path))
}

function naturalSortTokens(value) {
  const normalized = value.replace(/\\/g, '/').trim().toLocaleLowerCase()
  const tokens = []
  let index = 0
  while (index < normalized.length) {
    const isDigit = normalized.charCodeAt(index) >= 48 && normalized.charCodeAt(index) <= 57
    let end = index + 1
    while (end < normalized.length) {
      const nextIsDigit = normalized.charCodeAt(end) >= 48 && normalized.charCodeAt(end) <= 57
      if (nextIsDigit !== isDigit) break
      end += 1
    }
    const text = normalized.substring(index, end)
    tokens.push(isDigit ? { text, numberValue: Number(text) } : { text })
    index = end
  }
  return tokens
}

function compareNaturalPath(a, b) {
  const aTokens = naturalSortTokens(a)
  const bTokens = naturalSortTokens(b)
  const count = Math.min(aTokens.length, bTokens.length)
  for (let index = 0; index < count; index += 1) {
    const left = aTokens[index]
    const right = bTokens[index]
    if (left.numberValue !== undefined && right.numberValue !== undefined) {
      if (left.numberValue !== right.numberValue) return left.numberValue - right.numberValue
      if (left.text.length !== right.text.length) return left.text.length - right.text.length
      continue
    }
    const textCompare = left.text.localeCompare(right.text)
    if (textCompare !== 0) return textCompare
  }
  if (aTokens.length !== bTokens.length) return aTokens.length - bTokens.length
  return a.localeCompare(b)
}

function sortImageEntryPaths(paths) {
  const seenPaths = new Set()
  return paths
    .filter((path) => isSafeArchiveEntryPath(path) && isSupportedImagePath(path))
    .filter((path) => {
      if (seenPaths.has(path)) return false
      seenPaths.add(path)
      return true
    })
    .sort(compareNaturalPath)
}

function buildComicFromArchive(request) {
  if (!['.cbz', '.zip'].includes(getExtension(request.archivePath))) {
    throw new Error(`Unsupported archive path: ${request.archivePath}`)
  }
  const sortedImagePaths = sortImageEntryPaths(request.entries.map((entry) => entry.path))
  const entryByPath = new Map(request.entries.map((entry) => [entry.path, entry]))
  const now = request.importedAt ?? Date.now()
  const comicId = request.comicId ?? `local-archive-${stripExtension(request.archivePath).trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')}`
  const title = request.title ?? stripExtension(request.archivePath)
  const chapterId = `${comicId}-chapter-1`
  const pages = sortedImagePaths.map((path, index) => {
    const entry = entryByPath.get(path)
    return {
      id: `${chapterId}-page-${index + 1}`,
      comicId,
      chapterId,
      index,
      fileName: getBaseName(path),
      uri: `${request.archivePath}#${path}`,
      sortKey: path.trim().toLocaleLowerCase(),
      width: entry.width,
      height: entry.height,
      byteSize: entry.byteSize,
    }
  })
  return {
    comic: {
      id: comicId,
      title,
      sourceKind: 'local_archive',
      sourcePath: request.archivePath,
      coverUri: pages[0]?.uri,
      sortTitle: title.trim().toLocaleLowerCase(),
      preferredDirection: request.readingDirection ?? 'right_to_left',
      chapters: [{
        id: chapterId,
        comicId,
        title,
        index: 0,
        sourcePath: request.archivePath,
        sortKey: title.trim().toLocaleLowerCase(),
        pages,
        pageCount: pages.length,
        createdAt: now,
        updatedAt: now,
      }],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    },
    rejectedEntryCount: request.entries.length - pages.length,
    sourceEntryCount: request.entries.length,
  }
}

for (const symbol of [
  'SUPPORTED_ARCHIVE_EXTENSIONS',
  'SUPPORTED_IMAGE_EXTENSIONS',
  'isSafeArchiveEntryPath',
  'isSupportedImagePath',
  'compareNaturalPath',
  'sortImageEntryPaths',
]) {
  assertExport(sortSource, symbol)
}
assertExport(serviceSource, 'ArchiveImportService')
assertExport(serviceSource, 'buildComicFromArchive')
assertExport(extractionServiceSource, 'ArchiveExtractionService')
assertExport(extractionServiceSource, 'createArchiveExtractionCachePaths')
assertExport(extractionServiceSource, 'shouldCopyArchiveAsZip')
assertExport(extractionServiceSource, 'createExtractedPagePath')
assertExport(extractionServiceSource, 'extractArchive')

assert.match(extractionServiceSource, /zlib\.decompressFile\(request\.sandboxZipPath, request\.extractionDir\)/, 'extraction service must call zlib.decompressFile with sandbox zip and output dir')
assert.match(extractionServiceSource, /fs\.listFile\(extractionDir, listFileOptions\)/, 'extraction service must enumerate extracted files through fileIo.listFile')
assert.match(extractionServiceSource, /recursion:\s*true/, 'extraction listFile options must recurse')
assert.ok(extractionServiceSource.includes("replace(/^\\/+/, '')"), 'extraction service must strip listFile leading slash before DTO import')
assert.match(extractionServiceSource, /endsWith\('\.zip'\)/, 'extraction service must enforce zlib .zip input suffix')
assert.match(extractionServiceSource, /archive\.zip/, 'cache copy target must normalize zip and cbz input to archive.zip')
assert.match(extractionServiceSource, /createStableCacheHash/, 'cache root must include a stable hash component')
assert.match(extractionServiceSource, /cacheKeySeed \?\? archivePath/, 'cache hash must use caller seed when present and source path otherwise')

const firstCachePaths = createArchiveExtractionCachePaths('/cache', '/library/a/My Volume.cbz')
const secondCachePaths = createArchiveExtractionCachePaths('/cache', '/library/b/My Volume.cbz')
const seededCachePaths = createArchiveExtractionCachePaths('/cache', '/library/b/My Volume.cbz', 'comic-123')
assert.notEqual(firstCachePaths.rootDir, secondCachePaths.rootDir, 'same basename archives in different paths must not share cache roots')
assert.match(firstCachePaths.rootDir, /\/cache\/import\/my-volume-[a-f0-9]{8}$/)
assert.match(seededCachePaths.rootDir, /\/cache\/import\/my-volume-[a-f0-9]{8}$/)
assert.equal(seededCachePaths.rootDir, createArchiveExtractionCachePaths('/cache', '/library/b/My Volume.cbz', 'comic-123').rootDir)
assert.notEqual(seededCachePaths.rootDir, secondCachePaths.rootDir, 'caller seed must influence cache root when supplied')

const rawEntries = [
  { path: 'chapter/page10.JPG', byteSize: 10 },
  { path: 'chapter/page2.png', width: 800, height: 1200 },
  { path: 'chapter/page001.webp' },
  { path: 'chapter/page001.webp', byteSize: 999 },
  { path: 'chapter/notes.txt' },
  { path: '../escape.jpg' },
  { path: '/absolute.jpg' },
  { path: 'chapter/page02.jpg' },
]

assert.deepEqual(sortImageEntryPaths(rawEntries.map((entry) => entry.path)), [
  'chapter/page001.webp',
  'chapter/page2.png',
  'chapter/page02.jpg',
  'chapter/page10.JPG',
])

const result = buildComicFromArchive({
  archivePath: '/library/My Volume 02.cbz',
  comicId: 'comic-local-1',
  title: 'My Volume 02',
  importedAt: 12345,
  entries: rawEntries,
})

assert.equal(result.sourceEntryCount, 8)
assert.equal(result.rejectedEntryCount, 4)
assert.equal(result.comic.sourceKind, 'local_archive')
assert.equal(result.comic.chapterCount, 1)
assert.equal(result.comic.pageCount, 4)
assert.equal(result.comic.coverUri, '/library/My Volume 02.cbz#chapter/page001.webp')
assert.deepEqual(result.comic.chapters[0].pages.map((page) => page.fileName), [
  'page001.webp',
  'page2.png',
  'page02.jpg',
  'page10.JPG',
])
assert.equal(result.comic.chapters[0].pages[1].width, 800)
assert.equal(result.comic.chapters[0].pages[1].height, 1200)
assert.equal(result.comic.chapters[0].pages[3].byteSize, 10)

assert.throws(() => buildComicFromArchive({ archivePath: '/library/raw.rar', entries: [] }), /Unsupported archive path/)

console.log('PASS archive import contracts')
