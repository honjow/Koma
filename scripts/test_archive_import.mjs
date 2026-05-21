import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const sortPath = resolve(root, 'entry/src/main/ets/import/ImageSortUtils.ets')
const servicePath = resolve(root, 'entry/src/main/ets/import/ArchiveImportService.ets')
const extractionServicePath = resolve(root, 'entry/src/main/ets/import/ArchiveExtractionService.ets')
const readerPageSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const localImportCoordinatorPath = resolve(root, 'entry/src/main/ets/import/LocalImportCoordinator.ets')
const localImportDebugPath = resolve(root, 'entry/src/main/ets/import/LocalImportDebugModels.ets')
const importPagePath = resolve(root, 'entry/src/main/ets/pages/ImportPage.ets')
const indexPagePath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const sortSource = readFileSync(sortPath, 'utf8')
const serviceSource = readFileSync(servicePath, 'utf8')
const extractionServiceSource = readFileSync(extractionServicePath, 'utf8')
const readerPageSourceAdapterSource = readFileSync(readerPageSourceAdapterPath, 'utf8')
const localImportCoordinatorSource = readFileSync(localImportCoordinatorPath, 'utf8')
const localImportDebugSource = readFileSync(localImportDebugPath, 'utf8')
const importPageSource = readFileSync(importPagePath, 'utf8')
const indexPageSource = readFileSync(indexPagePath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|async function|function|const) ${symbol}\\b`), `${symbol} must be exported`)
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

function normalizeImportCachePath(value) {
  let normalized = value.replace(/\\/g, '/').trim()
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function hasUnsafeImportCachePathSegment(path) {
  const normalized = normalizeImportCachePath(path)
  if (normalized === '/') {
    return false
  }
  return normalized.split('/').some((segment, index) => {
    if (segment === '.' || segment === '..') {
      return true
    }
    return segment.length === 0 && index > 0
  })
}

function isSafeComputedArchiveImportCacheRoot(cacheDir, cacheRootDir) {
  const normalizedCacheDir = normalizeImportCachePath(cacheDir)
  const normalizedRootDir = normalizeImportCachePath(cacheRootDir)
  const importParentDir = normalizedCacheDir === '/' ? '/import' : `${normalizedCacheDir}/import`
  return !hasUnsafeImportCachePathSegment(normalizedCacheDir) &&
    !hasUnsafeImportCachePathSegment(normalizedRootDir) &&
    normalizedRootDir !== importParentDir &&
    normalizedRootDir.startsWith(`${importParentDir}/`)
}

function normalizeListedImportCacheEntry(path) {
  return path.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, '')
}

function isSafeListedImportCacheEntry(path) {
  const relativeEntry = normalizeListedImportCacheEntry(path)
  return relativeEntry.length > 0 && !hasUnsafeImportCachePathSegment(relativeEntry)
}

function sanitizeLocalArchiveDebugValue(value) {
  if (value === undefined) return ''
  const redacted = value
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/([?&](?:token|access_token|refresh_token|password|secret|signature|credential|auth|code|key)=)[^&#]*/gi, '$1<redacted>')
  if (redacted.length <= 180) return redacted
  return `${redacted.substring(0, 64)}...${redacted.substring(redacted.length - 96)}`
}

function formatLocalArchiveImportDebugEvent(event) {
  const fields = [event.step]
  if (event.uriCount !== undefined) fields.push(`uris=${event.uriCount}`)
  for (const [label, value] of [
    ['sourceUri', event.sourceUri],
    ['sandboxZipPath', event.sandboxZipPath],
    ['cacheRootDir', event.cacheRootDir],
    ['extractionDir', event.extractionDir],
    ['comicId', event.comicId],
    ['title', event.title],
  ]) {
    const sanitizedValue = sanitizeLocalArchiveDebugValue(value)
    if (sanitizedValue.length > 0) fields.push(`${label}=${sanitizedValue}`)
  }
  if (event.pageCount !== undefined) fields.push(`pages=${event.pageCount}`)
  const error = sanitizeLocalArchiveDebugValue(event.error)
  if (error.length > 0) fields.push(`error=${error}`)
  return fields.join(' | ')
}

function isSafeArchiveEntryPath(path) {
  const normalized = path.replace(/\\/g, '/').trim()
  if (normalized.length === 0 || normalized.startsWith('/')) return false
  return !normalized.split('/').some((part) => part === '..')
}

function isSupportedImagePath(path) {
  return ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'].includes(getExtension(path))
}

function trimTrailingSlash(value) {
  let normalized = normalizeSeparator(value).trim()
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function stripFileUriScheme(value) {
  return value.startsWith('file://') ? value.slice('file://'.length) : value
}

function encodeFileUriPath(path) {
  return path.split('/').map((segment) => encodeURIComponent(segment)).join('/')
}

function createExtractedPageUri(extractionDir, entryPath) {
  const normalizedEntryPath = normalizeSeparator(entryPath).replace(/^\/+/, '')
  if (!isSafeArchiveEntryPath(normalizedEntryPath)) {
    throw new Error(`Unsafe extracted entry path: ${entryPath}`)
  }
  const extractedPath = `${trimTrailingSlash(stripFileUriScheme(extractionDir))}/${normalizedEntryPath}`
  return `file://${encodeFileUriPath(extractedPath)}`
}

function isReaderLocalImageSourceUri(uri) {
  const normalized = uri.trim().replace(/\\/g, '/')
  if (normalized.length === 0 || normalized.includes('#') || normalized.includes('?')) return false
  if (normalized.includes('://') && !normalized.startsWith('file://')) return false
  const path = normalized.startsWith('file://') ? normalized.slice('file://'.length) : normalized
  if (!path.startsWith('/') || path.split('/').some((segment) => segment === '..')) return false
  const appImportRoots = [
    '/data/storage/el2/base/cache/import/',
    '/data/storage/el2/base/files/import/',
  ]
  return appImportRoots.some((root) => path.startsWith(root) && path.indexOf('/extract/', root.length) > root.length) &&
    isSupportedImagePath(path)
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
      uri: request.extractionDir === undefined ? `${request.archivePath}#${path}` : createExtractedPageUri(request.extractionDir, path),
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

function notifySuccessfulArchiveImports(results, onComic) {
  results.forEach((result) => {
    if (result.status === 'succeeded') {
      onComic(result.extractionResult.importResult.comic)
    }
  })
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
assertExport(localImportCoordinatorSource, 'ARCHIVE_FILE_SUFFIX_FILTER')
assertExport(localImportCoordinatorSource, 'LocalImportCoordinator')
assertExport(localImportCoordinatorSource, 'createArchiveDocumentSelectOptions')
assertExport(localImportCoordinatorSource, 'pickArchiveUris')
assertExport(localImportCoordinatorSource, 'copyPickedArchiveUriToSandbox')
assertExport(localImportCoordinatorSource, 'assertSafeComputedArchiveImportCacheRoot')
assertExport(localImportDebugSource, 'LocalArchiveImportDebugEvent')
assertExport(localImportDebugSource, 'LocalArchiveImportDebugSnapshot')
assertExport(localImportDebugSource, 'sanitizeLocalArchiveDebugValue')
assertExport(localImportDebugSource, 'formatLocalArchiveImportDebugEvent')

assert.match(extractionServiceSource, /zlib\.decompressFile\(request\.sandboxZipPath, request\.extractionDir\)/, 'extraction service must call zlib.decompressFile with sandbox zip and output dir')
assert.match(extractionServiceSource, /fs\.listFile\(extractionDir, listFileOptions\)/, 'extraction service must enumerate extracted files through fileIo.listFile')
assert.match(extractionServiceSource, /recursion:\s*true/, 'extraction listFile options must recurse')
assert.ok(extractionServiceSource.includes("replace(/^\\/+/, '')"), 'extraction service must strip listFile leading slash before DTO import')
assert.match(extractionServiceSource, /if \(entries\.length === 0\) \{[\s\S]*Archive contains no supported image pages/, 'archives with no supported image pages must fail before comic import')
assert.match(extractionServiceSource, /buildComicFromArchive\(\{[\s\S]*extractionDir: request\.extractionDir/, 'real extraction flow must pass extractionDir into archive import mapping')
assert.match(extractionServiceSource, /endsWith\('\.zip'\)/, 'extraction service must enforce zlib .zip input suffix')
assert.match(extractionServiceSource, /archive\.zip/, 'cache copy target must normalize zip and cbz input to archive.zip')
assert.match(extractionServiceSource, /createStableCacheHash/, 'cache root must include a stable hash component')
assert.match(extractionServiceSource, /cacheKeySeed \?\? archivePath/, 'cache hash must use caller seed when present and source path otherwise')
assert.match(localImportCoordinatorSource, /new picker\.DocumentViewPicker\(context\)/, 'local import must construct DocumentViewPicker with UIAbilityContext')
assert.match(localImportCoordinatorSource, /Comic archives\(\.zip, \.cbz\)\|\.zip,\.cbz/, 'archive picker must filter ZIP and CBZ suffixes')
assert.doesNotMatch(localImportCoordinatorSource, /DocumentSelectMode\.FOLDER/, 'archive picker must not request folder selection')
assert.match(localImportCoordinatorSource, /fs\.open\(sourceUri, fs\.OpenMode\.READ_ONLY\)/, 'picked URI must be opened through fileIo URI support')
assert.match(localImportCoordinatorSource, /fs\.open\(sandboxZipPath, fs\.OpenMode\.WRITE_ONLY \| fs\.OpenMode\.CREATE \| fs\.OpenMode\.TRUNC\)/, 'sandbox archive.zip must be opened for overwrite')
assert.match(localImportCoordinatorSource, /fs\.copyFile\(sourceFile\.fd, targetFile\.fd, 0\)/, 'copy must bridge URI to sandbox with file descriptors')
assert.match(localImportCoordinatorSource, /createArchiveExtractionCachePaths\(request\.context\.cacheDir, request\.sourceUri, request\.sourceUri\)/, 'local import must create archive.zip under app cache')
assert.match(localImportCoordinatorSource, /removeComputedArchiveImportCacheRoot\(request\.context\.cacheDir, paths\.rootDir\)[\s\S]*await fs\.mkdir\(paths\.rootDir, true\)[\s\S]*LOCAL_ARCHIVE_DEBUG_STEP_COPY_STARTED/, 'repeat import must clear the computed cache root before copying')
assert.match(localImportCoordinatorSource, /assertSafeComputedArchiveImportCacheRoot\(cacheDir, cacheRootDir\)[\s\S]*fs\.listFile\(cacheRootDir, listFileOptions\)[\s\S]*fs\.unlink\(entryPath\)[\s\S]*fs\.rmdir\(cacheRootDir\)/, 'cache cleanup must recursively remove files and root directory after safety validation')
assert.match(importPageSource, /onArchiveImportSucceeded:\s*\(comic:\s*Comic\)\s*=>\s*void/, 'ImportPage must expose a successful archive import callback')
assert.match(importPageSource, /const results = await this\.localImportCoordinator\.pickAndImportArchives\(context\)[\s\S]*成功 \$\{succeededCount\} 个，失败 \$\{failedCount\} 个/, 'ImportPage must summarize multi-archive successes and failures')
assert.match(importPageSource, /results\.forEach\(\(result\) => \{[\s\S]*if \(result\.status === 'succeeded'\) \{[\s\S]*this\.onArchiveImportSucceeded\(result\.extractionResult\.importResult\.comic\)/, 'ImportPage must only upsert successful archive import results')
assert.match(importPageSource, /results\.forEach\(\(result\) => \{[\s\S]*this\.onArchiveImportSucceeded\(result\.extractionResult\.importResult\.comic\)[\s\S]*\}\)[\s\S]*this\.feedbackText = results\.length === 0/, 'ImportPage must not report archive import success until shelf persistence callbacks finish')
assert.match(indexPageSource, /private handleArchiveImportSucceeded\(comic:\s*Comic\):\s*void \{[\s\S]*(this\.libraryStore\.upsertComic\(comic\)|upsertComicAndPersistLibraryStore\(this\.libraryStore, persistenceService, comic\))[\s\S]*catch \(error\) \{[\s\S]*console\.error\('persist imported comic failed: ' \+ e\.message\)[\s\S]*throw e[\s\S]*this\.libraryRevision \+= 1[\s\S]*this\.selectedTab = 0[\s\S]*\}/, 'Index must make persistence failures visible and only bump shelf success state after import persistence succeeds')
assert.match(indexPageSource, /aboutToAppear\(\):\s*void \{[\s\S]*persistenceService\.restore\(\)[\s\S]*this\.libraryRevision \+= 1/, 'Index must hydrate persisted library data during startup before shelf rendering where feasible')
assert.match(indexPageSource, /ImportPage\(\{[\s\S]*onArchiveImportSucceeded:\s*\(comic:\s*Comic\) => \{[\s\S]*this\.handleArchiveImportSucceeded\(comic\)/, 'Index must pass the import success callback into ImportPage')
assert.match(indexPageSource, /LibraryPage\(\{[\s\S]*libraryRevision:\s*this\.libraryRevision/, 'Index must pass an explicit shelf refresh signal into LibraryPage')
assert.match(localImportCoordinatorSource, /archiveExtractionService\.extractArchive/, 'local import must hand sandbox archive.zip to ArchiveExtractionService')
assert.match(readerPageSourceAdapterSource, /ReaderPageRenderKind\.LOCAL_FILE_IMAGE/, 'reader adapter must expose a local image render path')
assert.match(readerPageSourceAdapterSource, /isReaderLocalImageSourceUri/, 'reader adapter must keep local image URI classification explicit')
assert.match(serviceSource, /encodeURIComponent\(segment\)/, 'extracted file URI path segments must be percent-encoded')
assert.match(readerPageSourceAdapterSource, /endsWith\('\.avif'\)/, 'reader local image allowlist must match imported AVIF pages')
assert.match(localImportCoordinatorSource, /export interface LocalArchiveImportFailedResult[\s\S]*status: 'failed'[\s\S]*error: string/, 'local import must expose failed item results for partial multi-selection')
assert.match(localImportCoordinatorSource, /export type LocalArchiveImportItemResult = LocalArchiveImportResult \| LocalArchiveImportFailedResult/, 'local import must use an explicit success/failure result union')
assert.match(localImportCoordinatorSource, /for \(const uri of uris\) \{[\s\S]*try \{[\s\S]*results\.push\(await this\.importPickedArchive[\s\S]*\} catch \(error\) \{[\s\S]*status: 'failed'[\s\S]*sourceUri: uri[\s\S]*error: `\$\{error\}`/, 'multi-archive import must continue after per-item failures')
assert.match(localImportCoordinatorSource, /setDebugSink\(debugSink\?: LocalArchiveImportDebugSink\)/, 'coordinator must expose an optional debug sink for QA surfaces')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED/, 'coordinator must report picker start')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED/, 'coordinator must report picker returned URI count and source URI lines')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_CACHE_PATHS/, 'coordinator must report cache root and extraction paths')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_COPY_STARTED/, 'coordinator must report archive copy start')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_COPY_SUCCEEDED/, 'coordinator must report archive copy success')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_COPY_FAILED/, 'coordinator must report archive copy errors')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_STARTED/, 'coordinator must report extraction start')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_SUCCEEDED/, 'coordinator must report extraction success')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_FAILED/, 'coordinator must report extraction errors')
assert.match(localImportCoordinatorSource, /LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_SUCCEEDED/, 'coordinator must report imported comic metadata')
assert.match(localImportDebugSource, /token\|access_token\|refresh_token\|password\|secret\|signature\|credential\|auth\|code\|key/, 'debug formatting must redact common secret query values')
assert.match(localImportDebugSource, /DEBUG_VALUE_TAIL_LENGTH/, 'debug formatting must preserve a useful path suffix when truncating')

const firstCachePaths = createArchiveExtractionCachePaths('/cache', '/library/a/My Volume.cbz')
const secondCachePaths = createArchiveExtractionCachePaths('/cache', '/library/b/My Volume.cbz')
const seededCachePaths = createArchiveExtractionCachePaths('/cache', '/library/b/My Volume.cbz', 'comic-123')
assert.notEqual(firstCachePaths.rootDir, secondCachePaths.rootDir, 'same basename archives in different paths must not share cache roots')
assert.match(firstCachePaths.rootDir, /\/cache\/import\/my-volume-[a-f0-9]{8}$/)
assert.match(seededCachePaths.rootDir, /\/cache\/import\/my-volume-[a-f0-9]{8}$/)
assert.equal(seededCachePaths.rootDir, createArchiveExtractionCachePaths('/cache', '/library/b/My Volume.cbz', 'comic-123').rootDir)
assert.notEqual(seededCachePaths.rootDir, secondCachePaths.rootDir, 'caller seed must influence cache root when supplied')
assert.ok(isSafeComputedArchiveImportCacheRoot('/cache', seededCachePaths.rootDir), 'computed cache root must be safe to clean for repeat import')
assert.ok(isSafeComputedArchiveImportCacheRoot('/cache/', '/cache/import/my-volume-12345678/'), 'trailing slashes must not affect cache cleanup safety')
assert.ok(isSafeComputedArchiveImportCacheRoot('/cache', '/cache/import/leaf'), 'valid computed cache leaf must be safe to clean')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/cache/import'), false, 'cleanup must not delete the import parent')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/cache/import/../other'), false, 'cleanup must reject traversal')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/cache/import/.'), false, 'cleanup must reject import parent current-directory aliases')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/cache/import/./leaf'), false, 'cleanup must reject nested current-directory aliases')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/cache/import/leaf/.'), false, 'cleanup must reject computed leaf current-directory aliases')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/cache//import/leaf'), false, 'cleanup must reject duplicate slash aliases')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache/.', '/cache/import/leaf'), false, 'cleanup must reject unsafe cacheDir aliases')
assert.equal(isSafeComputedArchiveImportCacheRoot('/cache', '/tmp/import/my-volume-12345678'), false, 'cleanup must reject roots outside cacheDir/import')
assert.equal(isSafeListedImportCacheEntry('leaf/page.jpg'), true, 'cleanup must allow normal listed relative entries')
assert.equal(isSafeListedImportCacheEntry('./leaf/page.jpg'), false, 'cleanup must reject listed current-directory relative entries')
assert.equal(isSafeListedImportCacheEntry('leaf/../page.jpg'), false, 'cleanup must reject listed traversal relative entries')
assert.equal(isSafeListedImportCacheEntry('leaf/./page.jpg'), false, 'cleanup must reject listed nested current-directory relative entries')
assert.equal(isSafeListedImportCacheEntry('leaf//page.jpg'), false, 'cleanup must reject listed duplicate slash aliases')

const formattedPickerLine = formatLocalArchiveImportDebugEvent({
  step: 'picker_returned',
  uriCount: 2,
  sourceUri: 'file://docs/Long Path/Volume 01.cbz?token=secret-value',
})
assert.equal(formattedPickerLine, 'picker_returned | uris=2 | sourceUri=file://docs/Long Path/Volume 01.cbz?token=<redacted>')

const longDebugUri = `file://docs/${'nested/'.repeat(35)}Volume 99.cbz?access_token=secret`
const sanitizedLongUri = sanitizeLocalArchiveDebugValue(longDebugUri)
assert.ok(sanitizedLongUri.startsWith('file://docs/nested/'), 'long debug URI must retain scheme and prefix')
assert.ok(sanitizedLongUri.endsWith('Volume 99.cbz?access_token=<redacted>'), 'long debug URI must retain archive suffix')
assert.ok(!sanitizedLongUri.includes('secret'), 'long debug URI must redact secret query values')

assert.equal(formatLocalArchiveImportDebugEvent({
  step: 'import_succeeded',
  sandboxZipPath: '/cache/import/volume-12345678/archive.zip',
  extractionDir: '/cache/import/volume-12345678/extract',
  comicId: 'local-archive-volume',
  title: 'Volume',
  pageCount: 4,
}), 'import_succeeded | sandboxZipPath=/cache/import/volume-12345678/archive.zip | extractionDir=/cache/import/volume-12345678/extract | comicId=local-archive-volume | title=Volume | pages=4')

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

const extractedImportResult = buildComicFromArchive({
  archivePath: '/library/My Volume 02.cbz',
  comicId: 'comic-local-extracted',
  title: 'My Volume 02',
  importedAt: 12345,
  extractionDir: '/data/storage/el2/base/cache/import/my-volume-12345678/extract',
  entries: rawEntries,
})
assert.equal(extractedImportResult.comic.sourcePath, '/library/My Volume 02.cbz', 'extracted import must retain original archive source path')
assert.equal(extractedImportResult.comic.chapters[0].sourcePath, '/library/My Volume 02.cbz', 'extracted chapter must retain original archive source path')
assert.equal(extractedImportResult.comic.coverUri, 'file:///data/storage/el2/base/cache/import/my-volume-12345678/extract/chapter/page001.webp')
assert.deepEqual(extractedImportResult.comic.chapters[0].pages.map((page) => page.fileName), [
  'page001.webp',
  'page2.png',
  'page02.jpg',
  'page10.JPG',
])
assert.ok(extractedImportResult.comic.chapters[0].pages.every((page) => !page.uri.includes('#')), 'extracted import page.uri must not store archive-entry DTO fragments')
assert.ok(extractedImportResult.comic.chapters[0].pages.every((page) => isReaderLocalImageSourceUri(page.uri)), 'extracted import page.uri must classify as reader local file image')

const reservedCharacterImportResult = buildComicFromArchive({
  archivePath: '/library/Reserved.cbz',
  comicId: 'comic-local-reserved',
  title: 'Reserved',
  importedAt: 12345,
  extractionDir: 'file:///data/storage/el2/base/cache/import/reserved-12345678/extract',
  entries: [
    { path: 'chapter/page#1.png' },
    { path: 'chapter/page?2.avif' },
    { path: 'chapter/page 3.jpg' },
  ],
})
assert.deepEqual(reservedCharacterImportResult.comic.chapters[0].pages.map((page) => page.uri), [
  'file:///data/storage/el2/base/cache/import/reserved-12345678/extract/chapter/page%203.jpg',
  'file:///data/storage/el2/base/cache/import/reserved-12345678/extract/chapter/page%3F2.avif',
  'file:///data/storage/el2/base/cache/import/reserved-12345678/extract/chapter/page%231.png',
])
assert.ok(reservedCharacterImportResult.comic.chapters[0].pages.every((page) => !page.uri.includes('#')), 'reserved extracted page.uri must not contain raw fragment separators')
assert.ok(reservedCharacterImportResult.comic.chapters[0].pages.every((page) => !page.uri.includes('?')), 'reserved extracted page.uri must not contain raw query separators')
assert.ok(reservedCharacterImportResult.comic.chapters[0].pages.every((page) => isReaderLocalImageSourceUri(page.uri)), 'reserved extracted page.uri must classify as reader local file image')

const importedComics = new Map()
notifySuccessfulArchiveImports([], (comic) => {
  importedComics.set(comic.id, comic)
})
assert.equal(importedComics.size, 0, 'picker cancel/empty results must not upsert imported comics')

notifySuccessfulArchiveImports([
  {
    status: 'succeeded',
    extractionResult: {
      importResult: result,
    },
  },
], (comic) => {
  importedComics.set(comic.id, comic)
})
assert.equal(importedComics.size, 1, 'successful coordinator results must upsert imported comics')
assert.equal(importedComics.get('comic-local-1').pageCount, 4)

notifySuccessfulArchiveImports([
  {
    status: 'failed',
    sourceUri: '/library/broken.zip',
    error: 'Archive contains no supported image pages: /library/broken.zip',
  },
], (comic) => {
  importedComics.set(comic.id, comic)
})
assert.equal(importedComics.size, 1, 'failed coordinator results must not upsert imported comics')

const mixedImportResults = [
  {
    status: 'succeeded',
    sourceUri: '/library/My Volume 02.cbz',
    extractionResult: {
      importResult: result,
    },
  },
  {
    status: 'failed',
    sourceUri: '/library/corrupt.zip',
    error: 'Error: failed to decompress archive',
  },
]
const mixedImportedComics = new Map()
notifySuccessfulArchiveImports(mixedImportResults, (comic) => {
  mixedImportedComics.set(comic.id, comic)
})
assert.equal(mixedImportedComics.size, 1, 'mixed success/failure selections must preserve successful imports')
assert.equal(mixedImportedComics.get('comic-local-1').pageCount, 4)

assert.throws(() => buildComicFromArchive({ archivePath: '/library/raw.rar', entries: [] }), /Unsupported archive path/)

console.log('PASS archive import contracts')
