import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')
const readerPageSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const remoteImageCacheStorePath = resolve(root, 'entry/src/main/ets/model/RemoteImageCacheStore.ets')
const offlineDownloadStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadStore.ets')
const readerPagePath = resolve(root, 'entry/src/main/ets/pages/ReaderPage.ets')
const readerChromePath = resolve(root, 'entry/src/main/ets/components/ReaderChrome.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const libraryPagePath = resolve(root, 'entry/src/main/ets/pages/LibraryPage.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const readerPreferencesStorePath = resolve(root, 'entry/src/main/ets/model/ReaderPreferencesStore.ets')
const baseStringsPath = resolve(root, 'entry/src/main/resources/base/element/string.json')
const zhStringsPath = resolve(root, 'entry/src/main/resources/zh_CN/element/string.json')
const enStringsPath = resolve(root, 'entry/src/main/resources/en_US/element/string.json')

const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')
const readerPageSourceAdapterSource = readFileSync(readerPageSourceAdapterPath, 'utf8')
const remoteImageCacheStoreSource = readFileSync(remoteImageCacheStorePath, 'utf8')
const offlineDownloadStoreSource = readFileSync(offlineDownloadStorePath, 'utf8')
const readerPageSource = readFileSync(readerPagePath, 'utf8')
const readerChromeSource = readFileSync(readerChromePath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const libraryPageSource = readFileSync(libraryPagePath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const readerPreferencesStoreSource = readFileSync(readerPreferencesStorePath, 'utf8')
const baseStringsSource = readFileSync(baseStringsPath, 'utf8')
const zhStringsSource = readFileSync(zhStringsPath, 'utf8')
const enStringsSource = readFileSync(enStringsPath, 'utf8')

assert.match(
  readerPreferencesStoreSource,
  /export type ReaderWideImageMode = 'keep_single' \| 'rotate_wide_pages' \| 'split_wide_pages'/,
  'reader preferences must persist wide-page split as a first-class mode alongside rotation',
)
assert.match(
  readerPageSource,
  /export const READER_WIDE_IMAGE_ASPECT_RATIO_THRESHOLD:\s*number = 1\.2[\s\S]*export function shouldSplitReaderWideImagePage\(mode: ReaderWideImageMode, readerMode: ReaderMode, width: number \| undefined, height: number \| undefined\): boolean[\s\S]*mode === 'split_wide_pages' && readerMode !== ReaderMode\.DUAL_PAGE && isReaderWideLandscapePage\(width, height\)/,
  'wide-page split must use the shared threshold, require dimensions, and stay disabled for dual-page mode',
)
assert.match(
  readerPageSource,
  /export function readerWidePageSplitSidesForDirection\(direction: ReadingDirection\): ReaderWidePageSplitSide\[\][\s\S]*ReadingDirection\.RIGHT_TO_LEFT[\s\S]*return \['right', 'left'\][\s\S]*return \['left', 'right'\]/,
  'wide-page split ordering must be right/left for RTL and left/right for LTR',
)
assert.match(
  readerPageSource,
  /shouldRotateReaderWideImagePage\(mode: ReaderWideImageMode, width: number \| undefined, height: number \| undefined\): boolean \{[\s\S]*mode === 'rotate_wide_pages'[\s\S]*shouldSplitReaderWideImagePage\(mode: ReaderWideImageMode, readerMode: ReaderMode, width: number \| undefined, height: number \| undefined\): boolean \{[\s\S]*mode === 'split_wide_pages'/,
  'wide-page rotate and split must be mutually exclusive mode checks',
)
assert.match(
  readerPageSource,
  /@Event onDecodeImageInfo: \(index: number, width: number, height: number\)[\s\S]*pixelMap\.getImageInfoSync\(\)[\s\S]*this\.onDecodeImageInfo\(this\.index, width, height\)/,
  'reader image decode must report real image dimensions when source/session metadata is missing',
)
assert.match(
  readerPageSource,
  /decodedImageDimensionKeys: string\[\][\s\S]*private pageWidth\(index: number\): number \| undefined \{[\s\S]*decodedPageDimensionWidth\(index\)[\s\S]*getReaderSessionPageWidth\(this\.sessionConfig, index\)[\s\S]*private pageHeight\(index: number\): number \| undefined \{[\s\S]*decodedPageDimensionHeight\(index\)[\s\S]*getReaderSessionPageHeight\(this\.sessionConfig, index\)/,
  'ReaderPage must prefer decoded runtime dimensions before falling back to persisted page metadata',
)
assert.match(
  readerPageSource,
  /private recordDecodedPageDimensions\(index: number, width: number, height: number\)[\s\S]*this\.syncReaderDisplayAfterSettingChange\(\)[\s\S]*LocalReaderPixelMapImage\(\{[\s\S]*onDecodeImageInfo: \(decodedIndex: number, width: number, height: number\) => \{[\s\S]*this\.recordDecodedPageDimensions\(decodedIndex, width, height\)/,
  'ReaderPage must reflow split-aware reader entries after real dimensions are learned from decoded images',
)
assert.match(
  readerPageSource,
  /@Monitor\('sessionConfig'\)[\s\S]*this\.decodedImageDimensionKeys = \[\][\s\S]*this\.decodedImageDimensionWidths = \[\][\s\S]*this\.decodedImageDimensionHeights = \[\]/,
  'runtime decoded page dimensions must be cleared when switching reader sessions',
)
assert.match(
  readerChromeSource,
  /@Param\s+canGoPrevious:\s*boolean = false[\s\S]*@Param\s+canGoNext:\s*boolean = false/,
  'ReaderChrome navigation enabled state must be supplied independently from physical page indexes',
)
assert.match(
  readerChromeSource,
  /RoundIconButton\(icon: Resource, enabled: boolean, action: \(\) => void\)[\s\S]*if \(enabled\) \{[\s\S]*action\(\)[\s\S]*RoundIconButton\(\$r\('sys\.symbol\.chevron_left'\), this\.canGoPrevious, \(\) => \{[\s\S]*this\.onPreviousPage\(\)/,
  'ReaderChrome previous control must use split-aware canGoPrevious before invoking the callback',
)
assert.match(
  readerChromeSource,
  /RoundIconButton\(icon: Resource, enabled: boolean, action: \(\) => void\)[\s\S]*if \(enabled\) \{[\s\S]*action\(\)[\s\S]*RoundIconButton\(\$r\('sys\.symbol\.chevron_right'\), this\.canGoNext, \(\) => \{[\s\S]*this\.onNextPage\(\)/,
  'ReaderChrome next control must use split-aware canGoNext before invoking the callback',
)
assert.match(
  readerPageSource,
  /private isSplitDisplayNavigationMode\(\): boolean \{[\s\S]*readerMode !== ReaderMode\.DUAL_PAGE && this\.wideImageMode === 'split_wide_pages'[\s\S]*private canGoPreviousPage\(\): boolean \{[\s\S]*this\.readerDisplayIndex > 0[\s\S]*return this\.pageIndex > 0/,
  'ReaderPage must preserve physical previous boundaries outside split display navigation mode',
)
assert.match(
  readerPageSource,
  /private canGoNextPage\(\): boolean \{[\s\S]*this\.readerDisplayIndex < this\.currentDisplayEntries\(\)\.length - 1[\s\S]*return this\.pageIndex < this\.pageTotal\(\) - 1/,
  'ReaderPage must preserve physical next boundaries outside split display navigation mode',
)
assert.match(
  readerPageSource,
  /ReaderChrome\(\{[\s\S]*canGoPrevious: this\.canGoPreviousPage\(\),[\s\S]*canGoNext: this\.canGoNextPage\(\),[\s\S]*onPreviousPage: \(\) => \{[\s\S]*this\.previousPage\(\)[\s\S]*onNextPage: \(\) => \{[\s\S]*this\.nextPage\(\)/,
  'ReaderPage must pass split-aware navigation state while keeping chrome callbacks wired to reader navigation',
)

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|async function) ${symbol}\\b`), `${symbol} must be exported`)
}

function clampPageIndex(pageIndex, totalPages) {
  if (totalPages <= 0) return 0
  if (pageIndex < 0) return 0
  if (pageIndex >= totalPages) return totalPages - 1
  return Math.floor(pageIndex)
}

function calculateProgressRatio(pageIndex, totalPages) {
  if (totalPages <= 0) return 0
  return (clampPageIndex(pageIndex, totalPages) + 1) / totalPages
}

function createReaderDisplayEntries(totalPages, widePageIndexes = []) {
  const widePages = new Set(widePageIndexes)
  const entries = []
  for (let pageIndex = 0; pageIndex < totalPages; pageIndex += 1) {
    if (widePages.has(pageIndex)) {
      entries.push({ pageIndex, splitSide: 'left' })
      entries.push({ pageIndex, splitSide: 'right' })
    } else {
      entries.push({ pageIndex, splitSide: 'none' })
    }
  }
  return entries
}

function splitAwareCanGoPrevious({ splitMode, readerDisplayIndex, pageIndex }) {
  return splitMode ? readerDisplayIndex > 0 : pageIndex > 0
}

function splitAwareCanGoNext({ splitMode, readerDisplayIndex, pageIndex, displayTotal, pageTotal }) {
  return splitMode ? readerDisplayIndex < displayTotal - 1 : pageIndex < pageTotal - 1
}

function createReadingProgress(comicId, chapterId, totalPages) {
  return {
    comicId,
    chapterId,
    pageIndex: 0,
    totalPages,
    progressRatio: totalPages > 0 ? 1 / totalPages : 0,
    completed: totalPages === 0,
    updatedAt: Date.now(),
  }
}

function updateReadingProgress(previous, pageIndex, pageId, totalPages = previous.totalPages) {
  const nextIndex = clampPageIndex(pageIndex, totalPages)
  return {
    comicId: previous.comicId,
    chapterId: previous.chapterId,
    pageId,
    pageIndex: nextIndex,
    totalPages,
    progressRatio: calculateProgressRatio(nextIndex, totalPages),
    completed: totalPages <= 0 || nextIndex >= totalPages - 1,
    updatedAt: Date.now(),
  }
}

class InMemoryReadingProgressStore {
  items = new Map()

  get(comicId) {
    return this.items.get(comicId)
  }

  updatePage(comicId, chapterId, pageIndex, pageId, totalPages) {
    const previous = this.items.get(comicId)
    const base = previous ?? createReadingProgress(comicId, chapterId, totalPages ?? 0)
    const next = updateReadingProgress(
      { ...base, chapterId },
      pageIndex,
      pageId,
      totalPages ?? base.totalPages
    )
    this.items.set(comicId, next)
    return next
  }

  clear() {
    this.items.clear()
  }
}

class InMemoryReaderSessionStore {
  constructor(progressStore = new InMemoryReadingProgressStore()) {
    this.progressStore = progressStore
  }

  restorePageIndex(config) {
    const progress = this.progressStore.get(config.comicId)
    if (progress === undefined || progress.chapterId !== config.chapterId) {
      return 0
    }
    return clampPageIndex(progress.pageIndex, config.totalPages)
  }

  updatePageIndex(config, pageIndex, pageId) {
    const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
    return this.progressStore.updatePage(
      config.comicId,
      config.chapterId,
      resolvedPageIndex,
      pageId,
      config.totalPages
    )
  }
}

function createReaderSessionConfigFromComic(comic, chapterId) {
  let chapter = comic.chapters[0]
  if (chapterId !== undefined) {
    chapter = comic.chapters.find((item) => item.id === chapterId) ?? chapter
  }
  if (chapter === undefined) {
    return {
      comicId: comic.id,
      chapterId: '',
      title: comic.title,
      totalPages: 0,
      pageUris: [],
      pageIds: [],
    }
  }
  const pages = [...chapter.pages].sort((a, b) => {
    if (a.index !== b.index) return a.index - b.index
    return a.sortKey.localeCompare(b.sortKey)
  })
  return {
    comicId: comic.id,
    chapterId: chapter.id,
    title: comic.title,
    chapterTitle: chapter.title,
    totalPages: pages.length,
    pageUris: pages.map((page) => page.uri),
    pageIds: pages.map((page) => page.id),
  }
}

function getReaderSessionPageUri(config, pageIndex) {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  return config.pageUris[resolvedPageIndex] ?? ''
}

const ReaderMode = {
  SINGLE_PAGE: 'single_page',
  CONTINUOUS_SCROLL: 'continuous_scroll',
}

function readerModeFromContinuousScroll(enabled) {
  return enabled ? ReaderMode.CONTINUOUS_SCROLL : ReaderMode.SINGLE_PAGE
}

function isContinuousScrollReaderMode(mode) {
  return mode === ReaderMode.CONTINUOUS_SCROLL
}

function getReaderModeLabel(mode) {
  return mode === ReaderMode.CONTINUOUS_SCROLL ? '连续滚动' : '单页'
}

const ReaderPageRenderKind = {
  LOCAL_FILE_IMAGE: 'local_file_image',
  REMOTE_URL_IMAGE: 'remote_url_image',
  URI_PLACEHOLDER: 'uri_placeholder',
}

const ReaderPageUnavailableReason = {
  OFFLINE_MISSING: 'offline_missing',
}

function normalizeReaderPageUri(uri) {
  return uri.trim().replace(/\\/g, '/')
}

function hasTraversalSegment(path) {
  return path.split('/').some((segment) => segment === '..')
}

function decodeFileUriPath(path) {
  try {
    return decodeURIComponent(path)
  } catch (_err) {
    return ''
  }
}

function isSupportedLocalImagePath(path) {
  const normalized = path.toLocaleLowerCase()
  return normalized.endsWith('.jpg') ||
    normalized.endsWith('.jpeg') ||
    normalized.endsWith('.png') ||
    normalized.endsWith('.webp') ||
    normalized.endsWith('.gif') ||
    normalized.endsWith('.bmp') ||
    normalized.endsWith('.avif')
}

function isAppImportExtractPath(path) {
  return READER_SANDBOX_ROOTS.some((root) => {
    if (!path.startsWith(root.path)) return false
    return path.indexOf('/extract/', root.path.length) > root.path.length
  })
}

const READER_SANDBOX_ROOTS = [
  { label: 'cache_haps_entry', path: '/data/storage/el2/base/haps/entry/cache/import/' },
  { label: 'files_haps_entry', path: '/data/storage/el2/base/haps/entry/files/import/' },
  { label: 'cache_base', path: '/data/storage/el2/base/cache/import/' },
  { label: 'files_base', path: '/data/storage/el2/base/files/import/' },
]

function matchReaderSandboxRoot(path) {
  const matched = READER_SANDBOX_ROOTS.find((root) => {
    return path.startsWith(root.path) && path.indexOf('/extract/', root.path.length) > root.path.length
  })
  return matched === undefined ? 'none' : matched.label
}

function getReaderUriExtension(uri) {
  const normalized = normalizeReaderPageUri(uri)
  const withoutQuery = normalized.split('?')[0].split('#')[0]
  const lastSegment = withoutQuery.split('/').pop() ?? ''
  const dotIndex = lastSegment.lastIndexOf('.')
  if (dotIndex < 0 || dotIndex === lastSegment.length - 1) return ''
  return lastSegment.slice(dotIndex + 1).toLocaleLowerCase()
}

function createShortReaderHash(value) {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash ^ value.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash.toString(16).padStart(8, '0').slice(-8)
}

function createReaderRedactedTail(uri) {
  const normalized = normalizeReaderPageUri(uri)
  const path = decodeFileUriPath(stripFileUriScheme(normalized))
  const extension = getReaderUriExtension(uri)
  const extensionTail = extension.length > 0 ? `<file.${extension}>` : '<file>'
  const extractIndex = path.indexOf('/extract/')
  if (extractIndex >= 0) {
    const afterExtract = path.slice(extractIndex + '/extract/'.length)
    const relativeSegments = afterExtract.split('/').filter((segment) => segment.length > 0)
    if (relativeSegments.length > 1) return `<segment>/extract/<segment>/${extensionTail}`
    return `<segment>/extract/${extensionTail}`
  }
  const strippedPath = stripFileUriScheme(normalized)
  const pathSegments = strippedPath.split('/').filter((segment) => segment.length > 0)
  if (pathSegments.length > 1) return `<segment>/${extensionTail}`
  return extensionTail
}

function getReaderImageSourceForm(source) {
  if (source.imageUri.length === 0) return 'none'
  if (source.imageUri.startsWith('file://')) return 'file_uri'
  if (source.imageUri.startsWith('/')) return 'absolute_path'
  return 'other'
}

function createReaderUriDiagnostics(uri, pageIndex = 0) {
  const normalized = normalizeReaderPageUri(uri)
  const path = stripFileUriScheme(normalized)
  const decodedPath = decodeFileUriPath(path)
  const source = createReaderPageRenderSource({
    comicId: 'diagnostic-case',
    chapterId: 'chapter-1',
    totalPages: 1,
    pageUris: [uri],
    pageIds: ['page-1'],
  }, pageIndex)
  const imageSource = source.imageUri.length > 0 ? source.imageUri : ''
  return {
    pageIndex,
    kind: source.kind,
    imageSourceForm: getReaderImageSourceForm(source),
    hasFileScheme: normalized.startsWith('file://'),
    hasRawFragmentOrQuery: normalized.includes('#') || normalized.includes('?'),
    matchedSandboxRoot: decodedPath.length > 0 ? matchReaderSandboxRoot(decodedPath) : 'none',
    extension: getReaderUriExtension(uri),
    uriHash: createShortReaderHash(normalized),
    sourceHash: createShortReaderHash(imageSource.length > 0 ? imageSource : normalized),
    redactedTail: createReaderRedactedTail(uri),
  }
}

/*
  Keep the JS mirror above aligned with ReaderPageSourceAdapter.ets; these tests
  execute the contract without depending on an ArkTS runtime.
*/
function assertNoPrivatePathLeak(diagnostics) {
  const privateFragments = [
    'koma-qa-import-real-image',
    'demo-12345678',
    '001-normal',
  ]
  privateFragments.forEach((fragment) => {
    assert.equal(diagnostics.redactedTail.includes(fragment), false, `redacted tail must not include ${fragment}`)
  })
}

function stripFileUriScheme(uri) {
  if (!uri.startsWith('file://')) return uri
  return uri.slice('file://'.length)
}

function isReaderLocalImageSourceUri(uri) {
  const normalized = normalizeReaderPageUri(uri)
  if (normalized.length === 0 || normalized.includes('#') || normalized.includes('?')) return false
  if (normalized.includes('://') && !normalized.startsWith('file://')) return false
  const path = stripFileUriScheme(normalized)
  if (!path.startsWith('/') || hasTraversalSegment(path)) return false
  const decodedPath = decodeFileUriPath(path)
  if (decodedPath.length === 0 || !decodedPath.startsWith('/') || hasTraversalSegment(decodedPath)) return false
  return isAppImportExtractPath(decodedPath) && isSupportedLocalImagePath(decodedPath)
}

function createReaderImageSourceUri(uri) {
  const normalized = normalizeReaderPageUri(uri)
  return decodeFileUriPath(stripFileUriScheme(normalized))
}

function createReaderPageRenderSource(config, pageIndex, options = {}) {
  const uri = getReaderSessionPageUri(config, pageIndex)
  if (options.offlineOnly === true) {
    if (isReaderLocalImageSourceUri(uri)) {
      return {
        kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
        uri,
        imageUri: createReaderImageSourceUri(uri),
        fallbackPageIndex: pageIndex,
      }
    }
    return {
      kind: ReaderPageRenderKind.URI_PLACEHOLDER,
      uri: `offline-missing://${createShortReaderHash(config.comicId)}/${createShortReaderHash(config.chapterId)}/${pageIndex}`,
      imageUri: '',
      fallbackPageIndex: pageIndex,
      pageId: getReaderSessionPageId(config, pageIndex),
      unavailableReason: ReaderPageUnavailableReason.OFFLINE_MISSING,
    }
  }
  if (config.sourceRuntimeId !== undefined && config.sourceRuntimeId.trim().length > 0) {
    const pageId = getReaderSessionPageId(config, pageIndex)
    const isUrl = uri.toLocaleLowerCase().startsWith('http://') || uri.toLocaleLowerCase().startsWith('https://')
    return {
      kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
      uri,
      imageUri: isUrl ? uri : `source-runtime://${config.sourceRuntimeId}/${encodeURIComponent(pageId)}`,
      fallbackPageIndex: pageIndex,
      sourceRuntimeId: config.sourceRuntimeId,
      pageId,
      pageUri: uri,
    }
  }
  if (uri.length === 0 || uri.startsWith('mock://')) {
    return {
      kind: ReaderPageRenderKind.URI_PLACEHOLDER,
      uri,
      imageUri: '',
      fallbackPageIndex: pageIndex,
    }
  }
  if (isReaderLocalImageSourceUri(uri)) {
    return {
      kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
      uri,
      imageUri: createReaderImageSourceUri(uri),
      fallbackPageIndex: pageIndex,
    }
  }
  if (uri.toLocaleLowerCase().startsWith('http://') || uri.toLocaleLowerCase().startsWith('https://')) {
    return {
      kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
      uri,
      imageUri: uri,
      fallbackPageIndex: pageIndex,
    }
  }
  return {
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    uri,
    imageUri: '',
    fallbackPageIndex: pageIndex,
  }
}

function stableHeadersKey(headers) {
  if (headers === undefined) return ''
  const names = Object.keys(headers).sort()
  if (names.length === 0) return ''
  return names.map((name) => `${name.toLocaleLowerCase()}=${headers[name] ?? ''}`).join('\n')
}

function cacheKeyFor(url, headers, cacheKeySeed) {
  if (cacheKeySeed !== undefined && cacheKeySeed.trim().length > 0) {
    return createShortReaderHash(`seed\n${cacheKeySeed.trim()}`)
  }
  return createShortReaderHash(`${url}\n${stableHeadersKey(headers)}`)
}

function sourceRuntimeImageRequestPayload(responseData) {
  if (responseData === undefined) return undefined
  if (responseData.imageRequest !== undefined) return responseData.imageRequest
  return responseData
}

function getReaderSessionPageId(config, pageIndex) {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  return config.pageIds[resolvedPageIndex] ?? `page-${resolvedPageIndex + 1}`
}

assertExport(readerSessionStoreSource, 'ReaderSessionConfig')
assertExport(readerSessionStoreSource, 'ReaderMode')
assertExport(readerSessionStoreSource, 'readerModeFromContinuousScroll')
assertExport(readerSessionStoreSource, 'isContinuousScrollReaderMode')
assertExport(readerSessionStoreSource, 'getReaderModeLabel')
assertExport(readerSessionStoreSource, 'ReaderSessionStore')
assertExport(readerSessionStoreSource, 'InMemoryReaderSessionStore')
assertExport(readerSessionStoreSource, 'createReaderSessionConfigFromComic')
assertExport(readerSessionStoreSource, 'getReaderSessionPageUri')
assertExport(readerPageSourceAdapterSource, 'ReaderPageRenderKind')
assertExport(readerPageSourceAdapterSource, 'ReaderPageUnavailableReason')
assertExport(readerPageSourceAdapterSource, 'isReaderLocalImageSourceUri')
assertExport(readerPageSourceAdapterSource, 'createReaderImageSourceUri')
assertExport(readerPageSourceAdapterSource, 'createReaderPageRenderSource')
assertExport(readerPageSourceAdapterSource, 'ReaderPageRenderDiagnostics')
assertExport(readerPageSourceAdapterSource, 'createReaderUriDiagnostics')
assertExport(readerPageSourceAdapterSource, 'createReaderPageRenderDiagnostics')
assertExport(readerPageSourceAdapterSource, 'ReaderRemoteImageCacheStats')
assertExport(readerPageSourceAdapterSource, 'ReaderRemoteImageCachePreferences')
assertExport(readerPageSourceAdapterSource, 'ReaderRemoteImageCachePreferencesStore')
assertExport(readerPageSourceAdapterSource, 'getReaderRemoteImageCacheStats')
assertExport(readerPageSourceAdapterSource, 'clearReaderRemoteImageCache')
assertExport(readerPageSourceAdapterSource, 'formatReaderRemoteImageCacheSize')
assert.match(readerPageSourceAdapterSource, /export const READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS/, 'reader cache limit options must be exported for settings menu use')
assertExport(readerPageSourceAdapterSource, 'configureReaderOfflineDownloads')
assertExport(readerPageSourceAdapterSource, 'fetchReaderRemoteSourceBytes')
assertExport(remoteImageCacheStoreSource, 'RemoteImageCacheStats')
assertExport(offlineDownloadStoreSource, 'OfflineDownloadStore')
assertExport(remoteImageCacheStoreSource, 'formatRemoteImageCacheSize')
assert.match(readerSessionStoreSource, /ReadingProgressStore/, 'reader session store must wrap ReadingProgressStore')
assert.match(readerSessionStoreSource, /clampPageIndex/, 'reader session restore/update must clamp page indexes')
assert.match(readerSessionStoreSource, /pageUris: pages\.map/, 'reader session config must carry ordered page URIs')
assert.match(readerSessionStoreSource, /sourceRuntimeId\?: string/, 'reader session config must carry optional source runtime id')
assert.match(readerPageSourceAdapterSource, /get_image_request/, 'reader cache path must call source runtime image request')
assert.match(readerPageSourceAdapterSource, /const hostHints: ReaderSourceImageRequestHostHints = \{ network: true \}[\s\S]*operation: 'get_image_request'[\s\S]*hostHints,/, 'source image requests must advertise network-capable image resolution to runtimes')
assert.match(readerPageSourceAdapterSource, /isSourceRuntimeImageRequestOperation\(operation: string \| undefined\)[\s\S]*operation === 'get_image_request'[\s\S]*operation === 'image_request'[\s\S]*operation === 'modify_image_request'[\s\S]*!isSourceRuntimeImageRequestOperation\(summary\.response\.operation\)/, 'reader cache path must accept source image-request response aliases')
assert.match(readerPageSourceAdapterSource, /fetchAndCacheReaderRemoteSource/, 'reader cache path must resolve source runtime image requests before fetch')
assert.match(readerPageSourceAdapterSource, /source_image_request_fallback allowed=false/, 'source image request fallback must fail closed for non-URL page URIs')
assert.match(readerPageSourceAdapterSource, /source_image_request_fallback allowed=true/, 'source image request fallback may use ordinary URL page URIs')
assert.match(readerPageSourceAdapterSource, /headers=\$\{(?:resolvedHeaders|headers) === undefined \? 0 : Object\.keys\((?:resolvedHeaders|headers)\)\.length\}/, 'source image request logs must report header count only')
assert.doesNotMatch(readerPageSourceAdapterSource, /step=source_image_request[^\n]*message=/, 'source image request logs must not emit raw exception messages')
assert.match(readerPageSourceAdapterSource, /readerRemoteHeadersToHttpHeaderObject/, 'reader remote fetch must support normalized header maps')
assert.match(readerPageSourceAdapterSource, /readerRemoteImageCacheStore\.stats\(\)/, 'adapter must expose remote image cache stats through the configured store')
assert.match(readerPageSourceAdapterSource, /readerRemoteImageCacheStore\.clear\(\)/, 'adapter must expose remote image cache clear through the configured store')
assert.match(readerPageSourceAdapterSource, /let readerOfflineDownloadStore: OfflineDownloadStore \| undefined = undefined/, 'reader adapter must keep durable offline downloads separate from remote image cache')
assert.match(readerPageSourceAdapterSource, /configureReaderOfflineDownloads\(filesDir: string\)[\s\S]*new OfflineDownloadStore\(filesDir\)/, 'reader adapter must configure offline downloads from filesDir')
assert.match(readerPageSourceAdapterSource, /function createReaderOfflineDownloadRenderSource[\s\S]*resolveDownloadedPage\(config\.comicId, config\.chapterId, pageId, pageIndex, \{[\s\S]*validateContentHash: false[\s\S]*ReaderPageRenderKind\.LOCAL_FILE_IMAGE/, 'reader adapter must resolve offline pages as local images')
assert.match(readerPageSourceAdapterSource, /export interface ReaderPageRenderSourceOptions\s*{[\s\S]*preferOffline\?: boolean[\s\S]*offlineOnly\?: boolean[\s\S]*}/, 'reader page render source must expose offline preference and offline-only options')
assert.match(readerPageSourceAdapterSource, /export enum ReaderPageUnavailableReason \{[\s\S]*OFFLINE_MISSING = 'offline_missing'[\s\S]*SOURCE_UNAVAILABLE = 'source_unavailable'/, 'reader placeholders must distinguish not-downloaded offline pages from source page lookup failures')
assert.match(readerPageSourceAdapterSource, /const READER_SOURCE_UNAVAILABLE_URI_PREFIX:\s*string = 'source-placeholder:\/\/'/, 'reader source-unavailable placeholders must use an internal URI prefix')
assert.match(readerPageSourceAdapterSource, /function createReaderUriRenderSource\(uri: string, pageIndex: number\)[\s\S]*uri\.startsWith\(READER_SOURCE_UNAVAILABLE_URI_PREFIX\)[\s\S]*ReaderPageRenderKind\.URI_PLACEHOLDER[\s\S]*unavailableReason:\s*ReaderPageUnavailableReason\.SOURCE_UNAVAILABLE/, 'reader adapter must resolve source-unavailable URIs directly as source failure placeholders')
assert.match(readerPageSourceAdapterSource, /export function createReaderPageRenderSource\(config: ReaderSessionConfig, pageIndex: number, options\?: ReaderPageRenderSourceOptions\)[\s\S]*options\?\.preferOffline !== false[\s\S]*createReaderOfflineDownloadRenderSource\(config, pageIndex, options\?\.offlineOnly === true\)[\s\S]*offlineDownloadSource !== undefined[\s\S]*return offlineDownloadSource[\s\S]*const uri = getReaderSessionPageUri\(config, pageIndex\)[\s\S]*uri\.startsWith\(READER_SOURCE_UNAVAILABLE_URI_PREFIX\)[\s\S]*return createReaderUriRenderSource\(uri, pageIndex\)[\s\S]*options\?\.offlineOnly === true[\s\S]*createReaderUriRenderSource\(uri, pageIndex\)[\s\S]*ReaderPageRenderKind\.LOCAL_FILE_IMAGE[\s\S]*createReaderOfflineUnavailableSource\(config, pageIndex\)[\s\S]*createReaderSourceRuntimeRenderSource/, 'reader page render source must prefer owned offline local files and must not turn source-unavailable placeholders into source runtime fetches')
assert.match(readerPageSourceAdapterSource, /function createReaderOfflineDownloadRenderSource\(config: ReaderSessionConfig, pageIndex: number, offlineOnly: boolean = false\)[\s\S]*localPath === undefined[\s\S]*offlineOnly && isOfflineManifestReaderOwned\(validation\)[\s\S]*createReaderOfflineUnavailableSource\(config, pageIndex\)[\s\S]*return undefined/, 'reader adapter must surface offline manifest page gaps as placeholders only for offline-only reads')
assert.match(readerPageSource, /isDefaultNetworkUnavailable\(\): boolean[\s\S]*connection\.getDefaultNetSync\(\)\.netId === 0[\s\S]*offlineOnly: isDefaultNetworkUnavailable\(\)/, 'ReaderPage must pass offline-only mode into page resolution when the platform reports no default network')
assert.match(readerPageSourceAdapterSource, /function isOfflineManifestReaderOwned\(validation: OfflineDownloadManifestValidation\): boolean[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*OfflineDownloadedChapterStatus\.CORRUPT/, 'reader adapter offline ownership must cover downloaded, partial, and corrupt manifests')
assert.match(readerPageSourceAdapterSource, /function createReaderOfflineUnavailableSource\(config: ReaderSessionConfig, pageIndex: number\): ReaderPageRenderSource[\s\S]*ReaderPageRenderKind\.URI_PLACEHOLDER[\s\S]*offline-missing:\/\//, 'reader adapter must expose missing offline pages as honest placeholders')
assert.match(readerPageSourceAdapterSource, /function createReaderOfflineUnavailableSource\(config: ReaderSessionConfig, pageIndex: number\): ReaderPageRenderSource[\s\S]*unavailableReason:\s*ReaderPageUnavailableReason\.OFFLINE_MISSING/, 'reader adapter must label offline missing placeholders with a user-facing reason')
assert.match(readerPageSource, /readerPlaceholderDetail\(source: ReaderPageRenderSource\): string[\s\S]*ReaderPageUnavailableReason\.OFFLINE_MISSING[\s\S]*reader_offline_page_missing[\s\S]*ReaderPageUnavailableReason\.SOURCE_UNAVAILABLE[\s\S]*reader_source_page_unavailable/, 'ReaderPage must render specific messages for offline missing and source-unavailable reader placeholders')
assert.match(readerPageSource, /import \{ KomaActionButton \} from '\.\.\/components\/ui\/KomaActionButton'/, 'ReaderPage error recovery must use the shared action button component')
assert.match(readerPageSource, /readerPlaceholderShowsReturnAction\(source: ReaderPageRenderSource\): boolean[\s\S]*ReaderPageUnavailableReason\.OFFLINE_MISSING[\s\S]*ReaderPageUnavailableReason\.SOURCE_UNAVAILABLE/, 'ReaderPage must show a recovery action for offline missing and source-unavailable chapter pages')
assert.match(readerPageSource, /KomaActionButton\(\{[\s\S]*reader_action_return_to_detail[\s\S]*this\.onCloseReader\(\)/, 'offline missing reader placeholder must offer a return action through the existing reader close route')
assert.match(readerPageSource, /context\.source\.kind === ReaderPageRenderKind\.URI_PLACEHOLDER[\s\S]*this\.readerPlaceholderDetail\(context\.source\)/, 'ReaderPage placeholder rendering must use the resolved source reason')
assert.match(readerPageSource, /context\.source\.kind === ReaderPageRenderKind\.URI_PLACEHOLDER[\s\S]*this\.readerPlaceholderShowsReturnAction\(context\.source\)/, 'ReaderPage placeholder rendering must bind recovery visibility to the resolved source reason')
assert.match(baseStringsSource, /"name": "reader_offline_page_missing"/, 'base strings must include the offline missing reader copy')
assert.match(baseStringsSource, /"name": "reader_source_page_unavailable"/, 'base strings must include the source reader failure copy')
assert.match(baseStringsSource, /"name": "reader_action_return_to_detail"/, 'base strings must include the offline missing recovery action')
assert.match(zhStringsSource, /"name": "reader_offline_page_missing"[\s\S]*本设备未下载该章节/, 'zh-CN strings must include the offline missing reader copy')
assert.match(zhStringsSource, /"name": "reader_source_page_unavailable"[\s\S]*源图片请求失败/, 'zh-CN strings must include the source reader failure copy')
assert.match(zhStringsSource, /"name": "reader_action_return_to_detail"[\s\S]*返回详情/, 'zh-CN strings must include the offline missing recovery action')
assert.match(enStringsSource, /"name": "reader_offline_page_missing"[\s\S]*not downloaded on this device/, 'en-US strings must include the offline missing reader copy')
assert.match(enStringsSource, /"name": "reader_source_page_unavailable"[\s\S]*Source page request failed/, 'en-US strings must include the source reader failure copy')
assert.match(enStringsSource, /"name": "reader_action_return_to_detail"[\s\S]*Return to details/, 'en-US strings must include the offline missing recovery action')
assert.match(readerPageSourceAdapterSource, /export function createReaderPageRenderDiagnostics\(config: ReaderSessionConfig, pageIndex: number\): ReaderPageRenderDiagnostics \{[\s\S]*createReaderSourceDiagnostics\(createReaderPageRenderSource\(config, pageIndex\)\)/, 'reader source diagnostics must report the resolved local-first render source')
assert.match(offlineDownloadStoreSource, /resolveDownloadedPage[\s\S]*options\?: OfflineDownloadValidationOptions[\s\S]*validateDownloadedChapter\(comicId, chapterId, options\)[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*fs\.accessSync\(page\.localPath\)/, 'offline resolver must allow validated existing local pages from partial downloads')
assert.match(remoteImageCacheStoreSource, /REMOTE_IMAGE_CACHE_DIR_NAME:\s*string = 'reader-remote-image-cache'/, 'remote image cache must remain under its dedicated cacheDir child')
assert.match(offlineDownloadStoreSource, /OFFLINE_DOWNLOAD_ROOT_DIR_NAME:\s*string = 'downloads'/, 'offline download store must use a durable files/downloads root')
assert.match(offlineDownloadStoreSource, /assertSafeOfflineDownloadRoot[\s\S]*hasTraversalSegment/, 'offline download store must include traversal-safe path validation')
assert.match(remoteImageCacheStoreSource, /async stats\(\): Promise<RemoteImageCacheStats>/, 'remote image cache store must expose stats')
assert.match(remoteImageCacheStoreSource, /totalBytes \+= entry\.size[\s\S]*entryCount \+= 1/, 'remote image cache stats must include total bytes and entry count')
assert.match(remoteImageCacheStoreSource, /async clear\(\): Promise<void>[\s\S]*await fs\.unlink\(path\)[\s\S]*this\.entries\.clear\(\)[\s\S]*await fs\.unlink\(this\.manifestPath\)/, 'remote image cache clear must remove cached files, entries, and manifest through RemoteImageCacheStore')
assert.doesNotMatch(remoteImageCacheStoreSource, /fs\.rmdir|rmdirSync|removeComputedArchiveImportCacheRoot|\/import\//, 'remote image cache clear must not recursively or broadly delete cache/import roots')
assert.match(settingsPageSource, /key: 'image-cache', titleKey: 'settings_row_image_cache_title'/, 'Settings must expose the image cache row')
assert.match(readerPageSourceAdapterSource, /DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES[\s\S]*maxBytes:\s*DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES[\s\S]*ReaderRemoteImageCachePreferencesStore[\s\S]*saveMaxBytes\(maxBytes: number\)/, 'reader remote image cache limit must have durable preferences with the existing max as default')
assert.match(settingsPageSource, /key: 'cache-limit', titleKey: 'settings_row_cache_limit_title'[\s\S]*READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS[\s\S]*saveImageCacheLimit\(maxBytes\)/, 'Settings must expose cache limit as a real option menu')
assert.doesNotMatch(settingsPageSource, /\{ key: 'cache-limit'[^}]*placeholder:\s*true/, 'Settings cache limit row must not remain a placeholder')
assert.match(readerPageSourceAdapterSource, /autoCleanEnabled:\s*true[\s\S]*saveAutoCleanEnabled\(autoCleanEnabled: boolean\)[\s\S]*if \(readerRemoteImageCacheAutoCleanEnabled\) \{[\s\S]*evictIfOver\(readerRemoteImageCacheMaxBytes\)/, 'reader remote image cache auto-clean must be a durable preference that gates LRU eviction')
assert.match(settingsPageSource, /key: 'cache-auto-clean', titleKey: 'settings_row_cache_auto_clean_title'[\s\S]*row\.key === 'cache-auto-clean'[\s\S]*saveImageCacheAutoCleanEnabled\(value\)/, 'Settings must expose cache auto clean as a real switch')
assert.doesNotMatch(settingsPageSource, /\{ key: 'cache-auto-clean'[^}]*placeholder:\s*true/, 'Settings cache auto clean row must not remain a placeholder')
assert.match(settingsPageSource, /configureReaderRemoteImageCache\(context\.cacheDir, this\.imageCacheMaxBytes, this\.imageCacheAutoCleanEnabled\)/, 'Settings must configure the reader remote image cache with the selected limit and auto-clean preference before stats or clear')
assert.match(readerPageSource, /ReaderRemoteImageCachePreferencesStore\(context\)\.load\(\)[\s\S]*configureReaderRemoteImageCache\(cacheDir, preferences\.maxBytes, preferences\.autoCleanEnabled\)/, 'ReaderPage must apply persisted cache limit and auto-clean preference before using the remote image cache')
assert.match(settingsPageSource, /getReaderRemoteImageCacheStats\(\)/, 'Settings must load remote image cache stats')
assert.match(settingsPageSource, /clearReaderRemoteImageCache\(\)/, 'Settings must call the remote image cache clear API')
assert.match(settingsPageSource, /value: s\('settings_image_cache_clear'\)[\s\S]*this\.clearImageCache\(\)/, 'Settings must expose the clear cache action')
assert.match(readerPageSource, /fetchAndCacheReaderRemoteSource\(this\.remoteSource\)/, 'reader image decode must route source runtime pages through the source-aware cache path')
assert.match(readerPageSource, /configureReaderOfflineDownloads\(context\.filesDir\)/, 'ReaderPage must configure durable offline downloads before page source resolution')
assert.match(readerPageSource, /PageErrorPlaceholderContent\([\s\S]*detail: string = s\('reader_page_unavailable'\)[\s\S]*showReturnAction: boolean = false[\s\S]*showRetryAction: boolean = false[\s\S]*Text\(detail\)/, 'reader error placeholder must render explicit failure detail copy')
assert.match(readerPageSource, /function readerPageImageIdentity\([\s\S]*readerRemoteSourceIdentity\(source\)[\s\S]*splitSide[\s\S]*readerRemoteHeadersSignature\(headers\)/, 'reader image identity must include source runtime page identity, split side, and headers')
assert.match(readerPageSource, /private createSourceSignature\(sourceUri: string\): string \{[\s\S]*readerPageImageIdentity\(sourceUri, this\.remoteSource, this\.splitSide, this\.headers\)[\s\S]*Math\.floor\(this\.sourceWidth\)\}x\$\{Math\.floor\(this\.sourceHeight\)\}/, 'reader pixel map reuse must reset when source runtime page identity changes even if the visible image URI is reused')
assert.match(readerPageSource, /remoteImageFailureDetail\(source: ReaderPageRenderSource\): string \{[\s\S]*source\.sourceRuntimeId !== undefined[\s\S]*reader_source_page_unavailable[\s\S]*reader_remote_page_unavailable[\s\S]*RemoteImagePage\(source: ReaderPageRenderSource[\s\S]*this\.hasImageLoadFailed\(source\.imageUri, source, splitSide\)[\s\S]*this\.PageErrorPlaceholder\(index, compact, this\.remoteImageFailureDetail\(source\), false, splitSide, true[\s\S]*this\.retryImageLoadFailure\(source\.imageUri, source, splitSide\)/, 'source-runtime reader failures must show source-specific recovery copy while ordinary remote failures keep offline/network copy')
assert.match(readerPageSource, /LocalImagePage\(imageUri: string[\s\S]*this\.hasImageLoadFailed\(imageUri, undefined, splitSide\)[\s\S]*this\.PageErrorPlaceholder\(index, compact, s\('reader_local_page_unavailable'\), false, splitSide, true[\s\S]*this\.retryImageLoadFailure\(imageUri, undefined, splitSide\)/, 'local reader failures must not masquerade as remote network success')
assert.match(indexSource, /createReaderSessionConfigFromComic/, 'index must open reader sessions from Comic records')
assert.match(indexSource, /import \{[\s\S]*OfflineDownloadedChapterStatus[\s\S]*OfflineDownloadedPage[\s\S]*OfflineDownloadStore[\s\S]*\} from '\.\.\/model\/OfflineDownloadStore'/, 'index must have access to durable offline manifests when opening the reader')
assert.match(indexSource, /createReaderSessionConfigForOpen\(comic: Comic, chapterId\?: string\): ReaderSessionConfig[\s\S]*createReaderSessionConfigFromComic\(comic, chapterId\)[\s\S]*config\.totalPages > 0[\s\S]*createOfflineDownloadReaderSessionConfig\(comic, offlineChapterId, config\) \?\? config/, 'reader opening must fall back to downloaded manifest pages when the library chapter has no page list')
assert.match(indexSource, /hasAvailableOfflineReaderPages\(comicId: ComicId, chapterId: string \| undefined\)[\s\S]*validateDownloadedChapter\(comicId, chapterId, \{ validateContentHash: false \}\)[\s\S]*availablePageCount > 0[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL/, 'reader opening must probe downloaded manifests before waiting on source page hydration')
assert.match(indexSource, /const offlineReaderPagesReady = comic === undefined \? false : this\.hasAvailableOfflineReaderPages\(comic\.id, targetChapterId\)[\s\S]*if \(comic !== undefined\) \{[\s\S]*if \(!offlineReaderPagesReady\) \{[\s\S]*sourcePagesReady = await this\.ensureReaderSourceChapterPages\(comic, targetChapterId\)[\s\S]*installReaderRemoteHeadersForComic/, 'reader opening must skip source hydration when local downloaded pages are already available while still installing remote headers')
assert.match(indexSource, /let nextSessionConfig = comic === undefined \? MOCK_LIBRARY_READER_SESSION : this\.createReaderSessionConfigForOpen\(comic, targetChapterId\)[\s\S]*!sourcePagesReady && comic !== undefined && nextSessionConfig\.totalPages <= 0[\s\S]*nextSessionConfig = this\.createSourceUnavailableReaderSessionConfig\(comic, targetChapterId, nextSessionConfig\)/, 'library reader opening must enter Reader with a source-unavailable placeholder instead of stopping at a toast when source pages cannot be hydrated')
assert.match(indexSource, /createSourceUnavailableReaderSessionConfig\([\s\S]*totalPages:\s*1[\s\S]*pageUris:\s*\['source-placeholder:\/\/chapter'\][\s\S]*pageIds:\s*\[`\$\{fallbackChapterId\}:source-unavailable`\]/, 'source-unavailable reader session must provide a single internal placeholder page')
assert.match(libraryPageSource, /hasAvailableOfflineReaderPages\(comicId: ComicId, chapterId: string \| undefined\)[\s\S]*validateDownloadedChapter\(comicId, chapterId, \{ validateContentHash: false \}\)[\s\S]*availablePageCount > 0[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL/, 'library opening must probe downloaded manifests before forcing source page hydration')
assert.match(libraryPageSource, /if \(!this\.chapterNeedsSourcePages\(comic, chapterId\) \|\|[\s\S]*this\.hasAvailableOfflineReaderPages\(comic\.id, chapterId\)\) \{[\s\S]*this\.onOpenReader\(comicId, chapterId\)[\s\S]*return[\s\S]*SourceChapterPageHydrator/, 'library opening must let reader-ready downloaded chapters reach the shared Reader opener even when source chapter pages are not hydrated')
assert.match(mangaDetailPageSource, /hasAvailableOfflineReaderPages\(chapterId: string \| undefined\)[\s\S]*validateDownloadedChapter\(this\.currentComicId\(\), chapterId, \{ validateContentHash: false \}\)[\s\S]*availablePageCount > 0[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL/, 'manga detail opening must probe downloaded manifests before forcing source page hydration')
assert.match(mangaDetailPageSource, /private async handleStartReading\(\)[\s\S]*if \(this\.manga\.sourceId !== undefined\) \{[\s\S]*if \(!this\.hasAvailableOfflineReaderPages\(chapterId\)\) \{[\s\S]*const hydration = await this\.ensureSourceChapterPages\(chapterId\)[\s\S]*this\.onOpenReader\(this\.currentComicId\(\), chapterId\)/, 'manga detail start reading must open reader-ready downloaded source chapters without waiting on the source runtime')
assert.match(mangaDetailPageSource, /private async handleOpenChapter\(chapterId: string\)[\s\S]*if \(this\.manga\.sourceId !== undefined\) \{[\s\S]*if \(!this\.hasAvailableOfflineReaderPages\(chapterId\)\) \{[\s\S]*const hydration = await this\.ensureSourceChapterPages\(chapterId\)[\s\S]*this\.onOpenReader\(this\.currentComicId\(\), chapterId\)/, 'manga detail chapter rows must open reader-ready downloaded source chapters without waiting on the source runtime')
assert.match(indexSource, /createOfflineDownloadReaderSessionConfig\([\s\S]*new OfflineDownloadStore\(context\.filesDir\)[\s\S]*validateDownloadedChapter\(comic\.id, chapterId, \{ validateContentHash: false \}\)[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*validation\.availablePageCount <= 0[\s\S]*return undefined/, 'offline manifest reader sessions must only use reader-ready downloaded or partial manifests with available pages')
assert.match(indexSource, /for \(let index = 0; index < validation\.pageCount; index \+= 1\)[\s\S]*validation\.manifest\.pages\.find\(\(item: OfflineDownloadedPage\): boolean => item\.pageIndex === index\)[\s\S]*pageIds\.push\(pageId\)[\s\S]*pageUris\.push\(store\.resolveDownloadedPage\(comic\.id, chapterId, pageId, index, \{ validateContentHash: false \}\) \?\? ''\)/, 'offline manifest reader sessions must preserve manifest page count and leave missing pages as honest placeholders')
assert.match(indexSource, /pageWidths\.push\(page\?\.width\)[\s\S]*pageHeights\.push\(page\?\.height\)/, 'offline manifest reader sessions must preserve downloaded page dimensions for wide-page reader behavior')
assert.match(indexSource, /const chapterTitles = chapterIds\.map\(\(item: string, index: number\): string => \{[\s\S]*baseConfig\.chapterTitles\?\.\[index\][\s\S]*item !== chapterId[\s\S]*validation\.manifest\?\.chapterTitle[\s\S]*chapterTitles,/, 'offline manifest reader sessions must preserve chapter titles for the reader chapter selector')
assert.match(indexSource, /readerChapterIdForOpen\(comic: Comic, requestedChapterId\?: string\)[\s\S]*this\.readerSessionStore\.getProgress\(comic\.id\)[\s\S]*progress\.chapterId[\s\S]*sortedReaderChapters\(comic\.chapters\)\[0\]/, 'opening reader without an explicit chapter must prefer saved chapter progress before the default chapter')
assert.match(libraryPageSource, /import \{[\s\S]*sortedReaderChapters,[\s\S]*\} from '\.\.\/model\/ReaderSessionStore'[\s\S]*private readerChapterIdForComic\(comic: Comic\): string \| undefined \{[\s\S]*this\.sessionStore\.getProgress\(comic\.id\)[\s\S]*progress\.chapterId[\s\S]*const orderedChapters = sortedReaderChapters\(comic\.chapters\)[\s\S]*orderedChapters\[0\]\.id/, 'library shelf reader entry must use the same sorted chapter fallback as ReaderSessionStore when no saved progress exists')
assert.match(indexSource, /let nextSessionConfig = comic === undefined \? MOCK_LIBRARY_READER_SESSION : this\.createReaderSessionConfigForOpen\(comic, targetChapterId\)[\s\S]*this\.readerSessionConfig = nextSessionConfig/, 'all reader entry points must share the offline-manifest-aware reader session creation path')
assert.match(indexSource, /restorePageIndex\(this\.readerSessionConfig\)/, 'opening reader must restore from the selected session config')
assert.match(indexSource, /ReaderPage\(\{[\s\S]*readerOpen: this\.readerOpen!!,[\s\S]*pageIndex: this\.readerPageIndex!!,[\s\S]*chromeVisible: this\.readerChromeVisible!!,[\s\S]*webtoonMode: this\.readerWebtoonMode!!,[\s\S]*onPageIndexChange: \(value: number\) => \{[\s\S]*this\.readerPageIndex = value[\s\S]*onChromeVisibleChange: \(value: boolean\) => \{[\s\S]*this\.readerChromeVisible = value[\s\S]*onWebtoonModeChange: \(value: boolean\) => \{[\s\S]*this\.readerWebtoonMode = value/, 'Index must bind ReaderPage state events so page, chrome, and mode do not desynchronize from the root reader route')
assert.match(indexSource, /sessionStore: this\.readerSessionStore/, 'library and reader must share the same session store')
assert.match(indexSource, /HdsNavigation\(this\.appPathStack\)/, 'reader must be hosted by an in-app Navigation stack')
assert.match(indexSource, /pushPath\(\{\s*name:\s*RouteName\.READER\s*\}\)/, 'opening reader must push a reader route')
assert.match(indexSource, /onOpenReader: \(mangaId: string, chapterId\?: string\) => \{ void this\.openReader\(mangaId, chapterId\) \}/, 'manga detail reader opening must preserve selected chapter id')
assert.match(indexSource, /\.onBackPressed\(\(\) => \{[\s\S]*this\.closeReader\(\)[\s\S]*return true/, 'reader route must intercept system back and close reader')
assert.match(indexSource, /onBackPress\(\): boolean \{[\s\S]*this\.closeReader\(\)[\s\S]*return true/, 'entry page back fallback must close an open reader instead of exiting')
assert.match(readerPageSource, /updatePageIndex\(this\.sessionConfig/, 'reader page changes must update session progress')
assert.match(readerSessionStoreSource, /export interface ReaderSessionConfig[\s\S]*chapterIds: string\[\]/, 'reader session config must carry chapter ids for tracker chapter progress sync')
assert.match(readerSessionStoreSource, /export function sortedReaderChapters\(chapters: Chapter\[\]\): Chapter\[\][\s\S]*optionalReaderChapterSortNumber[\s\S]*dateUpload[\s\S]*return a\.index - b\.index/, 'reader session config creation must derive a stable chronological chapter order for reader controls and tracker sync')
assert.match(readerSessionStoreSource, /const orderedChapters = sortedReaderChapters\(comic\.chapters\)[\s\S]*const chapterIds = orderedChapters\.map\(\(item: Chapter\): string => item\.id\)[\s\S]*let chapter = orderedChapters\.length === 0 \? undefined : orderedChapters\[0\]/, 'reader sessions must use the same ordered chapters for default open, chapter ids, and adjacent navigation')
assert.match(readerPageSource, /import \{ TrackerProgressSyncService, TrackerProgressSyncResult \} from '\.\.\/model\/TrackerProgressSyncService'/, 'ReaderPage must import tracker progress sync service')
assert.match(readerPageSource, /private trackerProgressSyncService\?: TrackerProgressSyncService[\s\S]*ensureTrackerProgressSyncService\(\): TrackerProgressSyncService \| undefined[\s\S]*new TrackerProgressSyncService\(context\)/, 'ReaderPage must lazily create tracker progress sync service')
assert.match(readerPageSource, /this\.pushRemoteProgress\(progress\)[\s\S]*this\.pushTrackerProgress\(progress\)/, 'ReaderPage must attempt tracker sync after local progress persistence')
assert.match(readerPageSource, /pushReadingProgress\(progress, this\.sessionConfig\.chapterIds, trigger\)/, 'ReaderPage tracker sync must use reader session chapter ids and the active trigger for provider chapter progress')
assert.match(readerPageSource, /pushTrackerProgress\(progress: ReadingProgress, trigger: 'on_chapter_complete' \| 'on_reader_close' = 'on_chapter_complete'\)/, 'ReaderPage tracker sync must distinguish page-turn and reader-close triggers')
assert.match(readerPageSource, /pushTrackerProgress\(progress: ReadingProgress, trigger: 'on_chapter_complete' \| 'on_reader_close' = 'on_chapter_complete'\): void \{[\s\S]*trigger === 'on_chapter_complete' && !progress\.completed[\s\S]*return[\s\S]*pushReadingProgress\(progress, this\.sessionConfig\.chapterIds, trigger\)/, 'ReaderPage must not call tracker sync for ordinary page turns until the chapter is complete')
assert.doesNotMatch(readerPageSource, /step=push_progress status=synced provider=anilist/, 'ReaderPage tracker sync logs must not hardcode a provider for every successful push')
assert.match(readerPageSource, /aboutToDisappear\(\): void \{[\s\S]*const progress = this\.setPageIndex\(this\.pageIndex\)[\s\S]*this\.pushTrackerProgress\(progress, 'on_reader_close'\)/, 'ReaderPage must sync tracker progress for the on-reader-close strategy before leaving the reader')
assert.doesNotMatch(readerPageSource, /\[TrackerSync\][^\n]*(token|authorization|Bearer|providerTitleId|comic=|chapter=|message=)/i, 'ReaderPage tracker sync logs must not leak tokens, provider ids, local comic ids, or raw errors')
assert.match(readerPageSource, /ReaderPageRenderKind\.LOCAL_FILE_IMAGE/, 'reader page must render accepted local file images through a distinct path')
assert.match(readerPageSource, /ReaderPageRenderKind\.URI_PLACEHOLDER/, 'reader page must isolate URI rendering behind an explicit placeholder path')
assert.match(readerPageSourceAdapterSource, /export function createReaderPageSourceDiagnostics\(source: ReaderPageRenderSource\): ReaderPageRenderDiagnostics \{[\s\S]*return createReaderSourceDiagnostics\(source\)/, 'reader adapter must expose diagnostics for an already-resolved render source')
assert.match(readerPageSource, /interface ReaderPageRenderContext \{[\s\S]*source: ReaderPageRenderSource[\s\S]*diagnostics: ReaderPageRenderDiagnostics[\s\S]*createLoggedReaderPageRenderContext\(index: number\): ReaderPageRenderContext[\s\S]*const source = createReaderPageRenderSource\(this\.sessionConfig, index, \{ offlineOnly: isDefaultNetworkUnavailable\(\) \}\)[\s\S]*const diagnostics = createReaderPageSourceDiagnostics\(source\)[\s\S]*ResolvedReaderPageSurface\(this\.createLoggedReaderPageRenderContext\(index\), index, compact, splitSide\)[\s\S]*context\.source\.kind === ReaderPageRenderKind\.LOCAL_FILE_IMAGE[\s\S]*this\.LocalImagePage\(context\.source\.imageUri, index, compact, context\.diagnostics, splitSide\)/, 'reader page must resolve each page source once and reuse the same diagnostics while rendering')
assert.match(readerPageSource, /LocalImageContent[\s\S]*LocalReaderPixelMapImage[\s\S]*\.id\('reader-page-local-file-image'\)[\s\S]*RemoteImageContent[\s\S]*LocalReaderPixelMapImage[\s\S]*\.id\('reader-page-remote-url-image'\)/, 'reader layout must expose stable non-visible ids for local-vs-remote page source verification')
assert.match(readerPageSource, /image\.createImageSource\(sourceUri\)/, 'reader page must decode accepted local image sources through ImageKit')
assert.match(readerPageSource, /createPixelMap\(\)/, 'reader page must create a PixelMap for local image rendering')
assert.match(readerPageSource, /Image\(this\.pixelMap\)/, 'reader page must pass decoded PixelMap objects to ArkUI Image')
assert.doesNotMatch(readerPageSource, /Image\(imageUri\)/, 'reader page must not pass sandbox path strings directly to ArkUI Image')
assert.match(readerPageSource, /onDecodeFailed:[\s\S]*recordImageLoadFailure\(imageUri, undefined, splitSide\)[\s\S]*onDecodeFailed:[\s\S]*recordImageLoadFailure\(source\.imageUri, source, splitSide\)/, 'reader image decode failures must return to a source-aware visible error placeholder')
assert.match(readerPageSource, /\[reader-source\]/, 'reader page must log redacted source diagnostics')
assert.match(readerPageSource, /\[reader-image-error\]/, 'reader page must log redacted image error diagnostics')
assert.doesNotMatch(readerPageSource, /Text\(`\$\{index \+ 1\}`\)[\s\S]*fontSize\(compact \? 28 : 38\)/, 'reader error placeholders must not center a giant page number over the reading surface')
assert.match(readerPageSource, /PageErrorPlaceholderContent\([\s\S]*index: number[\s\S]*Text\(s\('reader_page_load_failed'\)\)[\s\S]*Text\(detail\)[\s\S]*maxLines\(compact \? 2 : 3\)[\s\S]*Text\(s\('reader_page_number'\)\.replace\('%s', `\$\{index \+ 1\}`\)\)/, 'reader error placeholders must show failure copy first and keep the page number as small metadata')
assert.match(readerPageSource, /expandSafeArea\(\[SafeAreaType\.SYSTEM\], \[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/, 'reader background may extend into system safe areas')
assert.match(readerPageSource, /private refreshReaderSurfaceSize\(areaWidthVp: number = 0, areaHeightVp: number = 0\): void \{[\s\S]*const nextWidthVp = areaWidthVp > 0 \? areaWidthVp : this\.readDefaultDisplayWidthVp\(\)[\s\S]*const nextHeightVp = areaHeightVp > 0 \? areaHeightVp : Math\.max\(1, this\.readDefaultDisplayHeightVp\(\)\)/, 'reader measured content surface must use the full fullscreen reading area instead of subtracting chrome or safe-area gutters')
assert.match(readerPageSource, /private viewportHeight\(\): number \{[\s\S]*if \(this\.readerSurfaceHeightVp > 0\) \{[\s\S]*return this\.readerSurfaceHeightVp[\s\S]*return Math\.max\(1, this\.readDefaultDisplayHeightVp\(\)\)/, 'reader zoom viewport fallback must stay full-bleed and leave safe-area avoidance to chrome')
assert.doesNotMatch(readerPageSource, /ReaderSafeContentFrame|ReaderSafeAreaSpacer/, 'reader content must not be wrapped in top/bottom safe-area spacers that shrink the manga surface')
assert.match(readerPageSource, /build\(\) \{[\s\S]*Stack\(\) \{[\s\S]*this\.ReaderInteractiveContentSurface\(\)[\s\S]*ReaderChrome\(\{/, 'reader build must place the full-bleed manga surface behind safe-area-aware chrome')
assert.match(readerPageSource, /private ReaderInteractiveContentSurface\(\)[\s\S]*\.width\('100%'\)[\s\S]*\.height\('100%'\)[\s\S]*\.clip\(true\)/, 'reader full-bleed interactive surface must be explicitly constrained to the full root stack height')
assert.match(readerPageSource, /private currentReaderZoomContentWidth\(\): number \{[\s\S]*return this\.currentReaderZoomContentSize\(\)\.width[\s\S]*private currentReaderZoomContentHeight\(\): number \{[\s\S]*return this\.currentReaderZoomContentSize\(\)\.height/, 'reader zoom must expose the current visible manga content dimensions to the render stage')
assert.match(readerPageSource, /private ReaderInteractiveContentSurface\(\)[\s\S]*Stack\(\{ alignContent: Alignment\.Center \}\)[\s\S]*currentReaderMode\(\) === ReaderMode\.CONTINUOUS_SCROLL[\s\S]*\.width\('100%'\)[\s\S]*\.height\('100%'\)[\s\S]*\.width\(this\.currentReaderZoomContentWidth\(\)\)[\s\S]*\.height\(this\.currentReaderZoomContentHeight\(\)\)[\s\S]*\.scale\(\{ x: this\.zoomScale, y: this\.zoomScale \}\)[\s\S]*\.translate\(\{ x: this\.zoomOffsetX, y: this\.zoomOffsetY \}\)[\s\S]*this\.ReaderInputLayer\(\)[\s\S]*\.onAreaChange\(\(oldValue: Area, newValue: Area\) => \{[\s\S]*this\.onReaderAreaChanged\(oldValue, newValue\)/, 'reader measured surface must scale the visible manga page or spread instead of always scaling the whole viewport')
assert.match(readerPageSource, /private ReaderInputLayer\(\)[\s\S]*GestureGroup\(GestureMode\.Parallel[\s\S]*GestureGroup\(GestureMode\.Exclusive[\s\S]*TapGesture\(\{ count: 2[\s\S]*onReaderDoubleTap[\s\S]*TapGesture\(\{ count: 1 \}\)[\s\S]*onReaderTap[\s\S]*PinchGesture\(\{ fingers: 2 \}\)[\s\S]*onReaderPinchStart[\s\S]*onReaderPinchUpdate[\s\S]*onReaderPinchEnd[\s\S]*PanGesture\(\{ fingers: 1, direction: PanDirection\.All, distance: 2 \}\)[\s\S]*onReaderPanStart[\s\S]*onReaderPanUpdate[\s\S]*onReaderPanEnd/, 'reader gestures and tap input must share the top input surface instead of letting the tap layer block zoom gestures')
assert.match(readerPageSource, /interface ReaderZoomContentSize[\s\S]*width: number[\s\S]*height: number[\s\S]*interface ReaderZoomContentFrame[\s\S]*left: number[\s\S]*top: number[\s\S]*width: number[\s\S]*height: number/, 'reader zoom must model the visible manga content frame explicitly')
assert.match(readerPageSource, /private readerDisplayPageAspectRatio\(index: number, splitSide: ReaderWidePageSplitSide = 'none'\): number[\s\S]*splitSide !== 'none'[\s\S]*displayWidth \/ 2[\s\S]*this\.shouldRotateWidePage\(index\)[\s\S]*return displayWidth \/ displayHeight/, 'reader zoom content ratio must account for split wide pages and rotated wide pages')
assert.match(readerPageSource, /private currentReaderZoomContentAspectRatio\(\): number[\s\S]*ReaderMode\.DUAL_PAGE[\s\S]*readerDisplayPageAspectRatio\(headIndex\) \+ this\.readerDisplayPageAspectRatio\(secondIndex\)[\s\S]*entries\[entryIndex\]\.splitSide/, 'reader zoom bounds must be derived from the current visible page, split side, or dual-page pair')
assert.match(readerPageSource, /private currentReaderZoomContentBaseWidth\(\): number \{[\s\S]*ReaderMode\.DUAL_PAGE[\s\S]*pairIndex <= 0[\s\S]*0\.58[\s\S]*0\.42[\s\S]*0\.96[\s\S]*0\.88[\s\S]*this\.dualPageMaxWidth\(\)[\s\S]*ReaderMode\.CONTINUOUS_SCROLL[\s\S]*this\.webtoonPageMaxWidth\(\)[\s\S]*this\.singlePageMaxWidth\(\)/, 'reader zoom width must use the actual visible page or spread width instead of treating side gutters as manga content')
assert.match(readerPageSource, /private fitReaderZoomContentSizeToViewport\(aspectRatio: number\): ReaderZoomContentSize \{[\s\S]*let contentWidth = this\.currentReaderZoomContentBaseWidth\(\)[\s\S]*contentHeight = contentWidth \/ aspectRatio/, 'reader zoom content sizing must start from the mode-specific visible page width')
assert.match(readerPageSource, /private PageErrorPlaceholder\([\s\S]*splitSide: ReaderWidePageSplitSide = 'none'[\s\S]*\.aspectRatio\(this\.readerDisplayPageAspectRatio\(index, splitSide\)\)[\s\S]*private LocalImagePage\([\s\S]*this\.PageErrorPlaceholder\(index, compact, s\('reader_local_page_unavailable'\), false, splitSide[\s\S]*\.aspectRatio\(this\.readerDisplayPageAspectRatio\(index, splitSide\)\)[\s\S]*private RemoteImagePage\([\s\S]*this\.PageErrorPlaceholder\(index, compact, this\.remoteImageFailureDetail\(source\), false, splitSide[\s\S]*\.aspectRatio\(this\.readerDisplayPageAspectRatio\(index, splitSide\)\)[\s\S]*context\.source\.kind === ReaderPageRenderKind\.URI_PLACEHOLDER[\s\S]*this\.PageErrorPlaceholder\(index, compact, this\.readerPlaceholderDetail\(context\.source\), this\.readerPlaceholderShowsReturnAction\(context\.source\), splitSide\)/, 'reader page containers and placeholders must use the visible split/rotated page aspect ratio, not the original physical page ratio')
assert.match(readerPageSource, /private retryImageLoadFailure\(uri: string, source: ReaderPageRenderSource \| undefined = undefined, splitSide: ReaderWidePageSplitSide = 'none'\): void \{[\s\S]*this\.imageLoadFailureKey\(uri, source, splitSide\)[\s\S]*this\.failedImageUris = this\.failedImageUris\.filter[\s\S]*PageErrorPlaceholderContent\([\s\S]*showRetryAction[\s\S]*label: s\('common_retry'\)/, 'reader failed image pages must expose an in-reader retry that clears only the current failed page key')
assert.match(readerPageSource, /private clampZoomOffsetX\(value: number, scale: number\): number \{[\s\S]*const contentSize = this\.currentReaderZoomContentSize\(\)[\s\S]*contentSize\.width \* scale - this\.viewportWidth\(\)/, 'reader horizontal zoom pan bounds must use the visible manga content width rather than the whole viewport')
assert.match(readerPageSource, /private clampZoomOffsetY\(value: number, scale: number\): number \{[\s\S]*const contentSize = this\.currentReaderZoomContentSize\(\)[\s\S]*contentSize\.height \* scale - this\.viewportHeight\(\)/, 'reader vertical zoom pan bounds must use the visible manga content height rather than the whole viewport')
assert.match(readerPageSource, /private canPanReaderContent\(scale: number = this\.zoomScale\): boolean \{[\s\S]*contentSize\.width \* scale > this\.viewportWidth\(\) \+ READER_ZOOM_EDGE_TOLERANCE_VP[\s\S]*contentSize\.height \* scale > this\.viewportHeight\(\) \+ READER_ZOOM_EDGE_TOLERANCE_VP/, 'reader must allow panning any visible manga content that exceeds the viewport, even before zooming')
assert.match(readerPageSource, /private onReaderPanUpdate\(event\?: GestureEvent\): void \{[\s\S]*!this\.canPanReaderContent\(\)[\s\S]*this\.zoomOffsetX = this\.clampZoomOffsetX[\s\S]*this\.zoomOffsetY = this\.clampZoomOffsetY/, 'reader pan updates must not require zoomScale > 1 so fit-width tall pages can be inspected at 1x')
assert.match(readerPageSource, /private onReaderPanEnd\(\): void \{[\s\S]*!this\.canPanReaderContent\(\)[\s\S]*this\.zoomScale <= 1\.01[\s\S]*this\.clampZoomOffsets\(\)[\s\S]*return[\s\S]*zoom_edge_page/, 'reader pan end must clamp 1x fit-width page offsets while keeping zoomed edge page navigation')
assert.match(readerPageSource, /private captureZoomAnchor\(centerX: number, centerY: number\): void \{[\s\S]*const frame = this\.currentReaderZoomContentFrame\(\)[\s\S]*this\.zoomAnchorX = this\.clampTapRatio\(\(centerX - frame\.left\) \/ frame\.width\)[\s\S]*this\.zoomAnchorY = this\.clampTapRatio\(\(centerY - frame\.top\) \/ frame\.height\)/, 'reader double-tap and pinch anchors must lock to the current content frame')
assert.match(readerPageSource, /private applyAnchoredZoom\(nextScale: number, centerX: number, centerY: number\): void \{[\s\S]*const frame = this\.currentReaderZoomContentFrame\(scale, 0, 0\)[\s\S]*this\.zoomOffsetX = this\.clampZoomOffsetX\(centerX - pointX, scale\)[\s\S]*this\.zoomOffsetY = this\.clampZoomOffsetY\(centerY - pointY, scale\)/, 'reader anchored zoom must use content-frame math before clamping offsets')
assert.match(readerPageSource, /private setReaderDisplayEntryIndex\(displayIndex: number, readerMode: ReaderMode, syncViewport: boolean = false\): void \{[\s\S]*if \(resolvedIndex !== this\.readerDisplayIndex\) \{[\s\S]*this\.resetReaderZoom\(false\)/, 'reader zoom must reset when moving between split display entries even if the physical page index is unchanged')
assert.match(readerPageSource, /private onReaderAreaChanged\(_oldValue: Area, newValue: Area\): void \{[\s\S]*this\.refreshReaderSurfaceSize[\s\S]*this\.clampZoomOffsets\(\)/, 'reader zoom offsets must be reclamped after safe-area or viewport size changes')
assert.match(readerPageSource, /currentReaderMode\(\) === ReaderMode\.CONTINUOUS_SCROLL/, 'reader page must render continuous scroll through the normalized reader mode contract')
assert.match(readerChromeSource, /onCloseReader/, 'chrome return button must delegate to the reader route close callback')
assert.match(readerChromeSource, /top: Math\.max\(ThemeConstants\.SPACE_SM, this\.safeTopInset \+ ThemeConstants\.SPACE_SM\)/, 'top reader chrome must reserve room for the status bar on fullscreen windows')
assert.match(readerChromeSource, /bottom: Math\.max\(ThemeConstants\.SPACE_MD, this\.safeBottomInset \+ ThemeConstants\.SPACE_MD\)/, 'bottom reader controls must reserve room for the navigation safe area on fullscreen windows')
assert.match(readerChromeSource, /onPreviousPage/, 'chrome previous button must use reader callback')
assert.match(readerChromeSource, /onNextPage/, 'chrome next button must use reader callback')
assert.match(readerChromeSource, /ModeMenu\(\)[\s\S]*MenuItem\(\{ content: getReaderModeLabel\(ReaderMode\.SINGLE_PAGE\) \}\)[\s\S]*ReaderMode\.DUAL_PAGE[\s\S]*ReaderMode\.CONTINUOUS_SCROLL/, 'reader chrome must expose a bounded in-reader mode selector')
assert.match(readerChromeSource, /getReaderModeLabel\(ReaderMode\.SINGLE_PAGE\)/, 'reader chrome must expose the 单页 mode label from the mode contract')
assert.match(readerChromeSource, /getReaderModeLabel\(ReaderMode\.CONTINUOUS_SCROLL\)/, 'reader chrome must expose the 连续滚动 mode label from the mode contract')
assert.doesNotMatch(readerChromeSource, /Webtoon 纵向预览|纵向/, 'reader chrome must avoid internal/webtoon wording in visible labels')
assert.match(readerPreferencesStoreSource, /export type ReaderBackgroundMode = 'black' \| 'paper' \| 'light'/, 'reader preferences must model persisted reader background choices')
assert.match(readerPreferencesStoreSource, /export type ReaderVolumeKeyBehavior = 'up_previous_down_next' \| 'up_next_down_previous'/, 'reader preferences must model volume-key page-turn direction')
assert.match(readerPreferencesStoreSource, /export const BACKGROUND_MODE_KEY:\s*string = 'reader\.backgroundMode'/, 'reader background preference must have a stable persistence key')
assert.match(readerPreferencesStoreSource, /export const VOLUME_KEY_BEHAVIOR_KEY:\s*string = 'reader\.volumeKeyBehavior'/, 'reader volume-key direction preference must have a stable persistence key')
assert.match(readerPreferencesStoreSource, /export const SHOW_PROGRESS_CONTROLS_KEY:\s*string = 'reader\.showProgressControls'/, 'reader progress visibility must have a stable persistence key')
assert.match(readerPreferencesStoreSource, /export const KEEP_SCREEN_AWAKE_KEY:\s*string = 'reader\.keepScreenAwake'/, 'reader keep-screen-awake preference must have a stable persistence key')
assert.match(readerPreferencesStoreSource, /DEFAULT_READER_PREFERENCES:[\s\S]*backgroundMode:\s*'black'[\s\S]*showProgressControls:\s*true[\s\S]*keepScreenAwake:\s*true[\s\S]*volumeKeyBehavior:\s*'up_previous_down_next'/, 'reader settings MVP defaults must preserve the current dark reader, visible progress UI, keep-awake UX, and volume-down-next behavior')
assert.match(readerPreferencesStoreSource, /normalizeReaderBackgroundMode\(value: string\)[\s\S]*value === 'paper' \|\| value === 'light'[\s\S]*return 'black'/, 'reader background loading must remain backward-compatible with missing or invalid saved values')
assert.match(readerPreferencesStoreSource, /normalizeReaderVolumeKeyBehavior\(value: string\): ReaderVolumeKeyBehavior \{[\s\S]*value === 'up_next_down_previous'[\s\S]*return 'up_previous_down_next'/, 'reader volume-key behavior loading must remain backward-compatible with missing or invalid saved values')
assert.match(readerPreferencesStoreSource, /normalizeReaderProgressControls\(value: boolean \| string \| number\)[\s\S]*value === false[\s\S]*return false[\s\S]*return true/, 'reader progress visibility loading must default to visible for older preference stores')
assert.match(readerPreferencesStoreSource, /normalizeReaderKeepScreenAwake\(value: boolean \| string \| number\)[\s\S]*value === false[\s\S]*return false[\s\S]*return true/, 'reader keep-screen-awake loading must default to enabled for older preference stores')
assert.match(readerPreferencesStoreSource, /export interface ReaderSeriesPreferenceOverrides \{[\s\S]*trimPageMarginsEnabled\?: boolean[\s\S]*normalizeReaderSeriesPreferenceOverrides[\s\S]*source\['trimPageMarginsEnabled'\] !== undefined[\s\S]*normalizeReaderTrimPageMarginsEnabled[\s\S]*trimPageMarginsEnabled: overrides\.trimPageMarginsEnabled \?\? globalPreferences\.trimPageMarginsEnabled/, 'series reader overrides must preserve trim-page-margins for manga-specific reading layouts')
assert.match(readerPreferencesStoreSource, /store\.get\(BACKGROUND_MODE_KEY, DEFAULT_READER_PREFERENCES\.backgroundMode\)/, 'reader preferences load must read persisted background mode')
assert.match(readerPreferencesStoreSource, /store\.get\(SHOW_PROGRESS_CONTROLS_KEY, DEFAULT_READER_PREFERENCES\.showProgressControls\)/, 'reader preferences load must read persisted progress visibility')
assert.match(readerPreferencesStoreSource, /store\.get\(KEEP_SCREEN_AWAKE_KEY, DEFAULT_READER_PREFERENCES\.keepScreenAwake\)/, 'reader preferences load must read persisted keep-screen-awake setting')
assert.match(readerPreferencesStoreSource, /async saveBackgroundMode\(backgroundMode: ReaderBackgroundMode\)/, 'reader preferences store must persist background mode independently')
assert.match(readerPreferencesStoreSource, /async saveShowProgressControls\(showProgressControls: boolean\)/, 'reader preferences store must persist progress visibility independently')
assert.match(readerPreferencesStoreSource, /async saveKeepScreenAwake\(keepScreenAwake: boolean\)/, 'reader preferences store must persist keep-screen-awake independently')
assert.match(readerPreferencesStoreSource, /async saveVolumeKeyBehavior\(volumeKeyBehavior: ReaderVolumeKeyBehavior\)[\s\S]*VOLUME_KEY_BEHAVIOR_KEY[\s\S]*normalizeReaderVolumeKeyBehavior/, 'reader preferences store must persist volume-key direction independently')
assert.match(settingsPageSource, /key: 'reader-background', titleKey: 'settings_row_reader_background_title'/, 'Settings must expose a normal reader background row')
assert.match(settingsPageSource, /key: 'reader-volume-key-behavior', titleKey: 'settings_row_reader_volume_key_behavior_title'/, 'Settings must expose a normal reader volume-key direction row')
assert.match(settingsPageSource, /key: 'reader-progress', titleKey: 'settings_row_reader_progress_title'/, 'Settings must expose a normal page number/progress row')
assert.match(settingsPageSource, /key: 'reader-keep-screen-awake', titleKey: 'settings_row_reader_keep_screen_awake_title'/, 'Settings must expose a normal keep-screen-awake row')
assert.match(settingsPageSource, /SettingsSelectionMenu\(row: SettingsRow\)[\s\S]*row\.key === 'reader-background'[\s\S]*reader_background_black[\s\S]*reader_background_paper[\s\S]*reader_background_light/, 'reader background menu must expose black, paper, and light choices')
assert.match(settingsPageSource, /SettingsSelectionMenu\(row: SettingsRow\)[\s\S]*row\.key === 'reader-volume-key-behavior'[\s\S]*reader_volume_keys_down_next[\s\S]*saveReaderVolumeKeyBehavior\('up_previous_down_next'\)[\s\S]*reader_volume_keys_up_next[\s\S]*saveReaderVolumeKeyBehavior\('up_next_down_previous'\)/, 'reader volume-key direction must render as a selection menu, not another switch')
assert.match(settingsPageSource, /isSwitchRow\(row: SettingsRow\)[\s\S]*row\.key === 'reader-progress'[\s\S]*row\.key === 'reader-keep-screen-awake'[\s\S]*setSwitchRowValue\(row: SettingsRow, value: boolean\)/, 'reader boolean rows must use the shared switch row path')
assert.match(settingsPageSource, /SectionRow\(row: SettingsRow\)[\s\S]*this\.isSwitchRow\(row\)[\s\S]*ConciseListRow\(\{[\s\S]*hasSwitch: true[\s\S]*checked: this\.switchRowValue\(row\)[\s\S]*this\.setSwitchRowValue\(row, isOn\)/, 'reader boolean rows must render as switches instead of selection menus')
assert.match(readerPageSource, /backgroundMode = preferences\.backgroundMode[\s\S]*showProgressControls = preferences\.showProgressControls[\s\S]*keepScreenAwake = preferences\.keepScreenAwake/, 'ReaderPage must apply persisted reader settings after load')
assert.match(readerPageSource, /volumeKeyNavigationEnabled = preferences\.volumeKeyNavigationEnabled[\s\S]*volumeKeyBehavior = preferences\.volumeKeyBehavior/, 'ReaderPage must apply persisted volume-key direction after load')
assert.match(readerPageSource, /readerBackgroundColor\(\): ResourceColor[\s\S]*this\.backgroundMode === 'paper'[\s\S]*ThemeConstants\.READER_BG_PAPER[\s\S]*this\.backgroundMode === 'light'[\s\S]*ThemeConstants\.READER_BG_LIGHT[\s\S]*ThemeConstants\.READER_BG_DARK/, 'ReaderPage must map reader background setting to visible background colors')
assert.match(readerPageSource, /\.backgroundColor\(this\.readerBackgroundColor\(\)\)/, 'ReaderPage must apply the reader background without changing root padding')
assert.match(readerPageSource, /showProgressControls: this\.showProgressControls/, 'ReaderPage must pass progress visibility to ReaderChrome')
assert.match(readerPageSource, /@Event onPageIndexChange: \(value: number\) => void[\s\S]*@Event onChromeVisibleChange: \(value: boolean\) => void[\s\S]*@Event onWebtoonModeChange: \(value: boolean\) => void[\s\S]*this\.\$pageIndex\(restoredPageIndex\)[\s\S]*this\.onPageIndexChange\(restoredPageIndex\)[\s\S]*this\.\$webtoonMode\(restoredMode === ReaderMode\.CONTINUOUS_SCROLL\)[\s\S]*this\.onWebtoonModeChange\(restoredMode === ReaderMode\.CONTINUOUS_SCROLL\)[\s\S]*this\.\$pageIndex\(remoteProgress\.pageIndex\)[\s\S]*this\.onPageIndexChange\(remoteProgress\.pageIndex\)[\s\S]*this\.\$pageIndex\(progress\.pageIndex\)[\s\S]*this\.onPageIndexChange\(progress\.pageIndex\)[\s\S]*this\.\$chromeVisible\(false\)[\s\S]*this\.onChromeVisibleChange\(false\)[\s\S]*this\.\$chromeVisible\(nextVisible\)[\s\S]*this\.onChromeVisibleChange\(nextVisible\)[\s\S]*this\.\$webtoonMode\(mode === ReaderMode\.CONTINUOUS_SCROLL\)[\s\S]*this\.onWebtoonModeChange\(mode === ReaderMode\.CONTINUOUS_SCROLL\)/, 'ReaderPage must mirror restored, remote, page-turn, chrome, and mode changes through explicit root state events')
assert.match(readerPageSource, /private setReaderReadingDirection\(readingDirection: ReadingDirection\): void \{[\s\S]*this\.readingDirection = readingDirection[\s\S]*this\.resetReaderZoom\(false\)[\s\S]*this\.syncReaderDisplayAfterSettingChange\(\)[\s\S]*saveReadingDirection\(readingDirection\)/, 'ReaderPage must apply reader direction changes immediately and persist them')
assert.match(readerPageSource, /private handleVolumeKeyNavigation\(event: KeyEvent\): boolean \{[\s\S]*const volumeUpGoesNext = this\.volumeKeyBehavior === 'up_next_down_previous'[\s\S]*const goNext = event\.keyCode === KeyCode\.KEYCODE_VOLUME_UP \? volumeUpGoesNext : !volumeUpGoesNext[\s\S]*if \(!goNext\) \{[\s\S]*this\.previousPage\(\)[\s\S]*this\.nextPage\(\)/, 'ReaderPage volume-key navigation must honor the configured up/down direction')
assert.match(readerPageSource, /private setReaderVolumeKeyBehavior\(volumeKeyBehavior: ReaderVolumeKeyBehavior\): void \{[\s\S]*this\.volumeKeyBehavior = volumeKeyBehavior[\s\S]*saveVolumeKeyBehavior\(volumeKeyBehavior\)/, 'ReaderPage must apply volume-key direction changes immediately and persist them')
assert.match(readerPageSource, /private currentSeriesPreferenceOverrides\(\): ReaderSeriesPreferenceOverrides \{[\s\S]*pageGapMode: this\.pageGapMode,[\s\S]*trimPageMarginsEnabled: this\.trimPageMarginsEnabled,[\s\S]*wideImageMode: this\.wideImageMode/, 'ReaderPage series settings save must include the current trim-page-margins reading layout')
assert.match(readerPageSource, /ReaderChrome\(\{[\s\S]*readingDirection: this\.readingDirection[\s\S]*onReadingDirectionChange: \(direction: ReadingDirection\) => \{[\s\S]*this\.setReaderReadingDirection\(direction\)/, 'ReaderPage must wire ReaderChrome reading-direction changes to reader state')
assert.match(readerPageSource, /private chromePageIndex\(\): number \{[\s\S]*this\.isSplitDisplayNavigationMode\(\) \? this\.readerDisplayIndex : this\.pageIndex[\s\S]*private chromePageTotal\(\): number \{[\s\S]*this\.isSplitDisplayNavigationMode\(\) \? this\.currentDisplayEntries\(\)\.length : this\.pageTotal\(\)/, 'ReaderPage must show split display progress in chrome without changing persisted physical progress')
assert.match(readerPageSource, /ReaderChrome\(\{[\s\S]*pageIndex: this\.chromePageIndex\(\),[\s\S]*pageTotal: this\.chromePageTotal\(\)/, 'ReaderPage must pass split-aware page index and total to ReaderChrome')
assert.match(readerPageSource, /window\.getLastWindow\(context\)[\s\S]*setWindowKeepScreenOn\(keepScreenAwake\)/, 'ReaderPage must apply keep-screen-awake through localized window API')
assert.match(readerPageSource, /aboutToAppear\(\): void \{[\s\S]*applyReaderKeepScreenAwake\(this\.keepScreenAwake, 'appear'\)/, 'ReaderPage must apply keep-screen-awake only while reader appears')
assert.match(readerPageSource, /aboutToDisappear\(\): void \{[\s\S]*applyReaderKeepScreenAwake\(false, 'disappear'\)/, 'ReaderPage must restore screen timeout when leaving reader')
assert.match(readerChromeSource, /@Param\s+showProgressControls:\s*boolean = true/, 'ReaderChrome progress visibility must be reactive to ReaderPage preference updates')
assert.match(readerChromeSource, /@Param\s+readingDirection:\s*ReadingDirection = ReadingDirection\.LEFT_TO_RIGHT[\s\S]*@Event onReadingDirectionChange: \(direction: ReadingDirection\) => void[\s\S]*settings_row_reading_direction_title[\s\S]*getReadingDirectionLabel\(ReadingDirection\.LEFT_TO_RIGHT\)[\s\S]*getReadingDirectionLabel\(ReadingDirection\.RIGHT_TO_LEFT\)[\s\S]*this\.onReadingDirectionChange\(index === 1 \? ReadingDirection\.RIGHT_TO_LEFT : ReadingDirection\.LEFT_TO_RIGHT\)/, 'ReaderChrome quick settings must expose a real left-to-right/right-to-left reading direction control')
assert.match(readerChromeSource, /if \(this\.showProgressControls\) \{[\s\S]*this\.TextPill\(this\.pageCounterText\(\)\)/, 'ReaderChrome must hide the page number label when requested')
assert.match(readerChromeSource, /if \(this\.showProgressControls\) \{[\s\S]*Slider\(\{[\s\S]*value: this\.sliderPageValue\(\),[\s\S]*max: Math\.max\(this\.pageTotal, 1\)/, 'ReaderChrome must hide the draggable progress control when requested')
assert.match(readerChromeSource, /RoundIconButton\(\$r\('sys\.symbol\.chevron_left'\), this\.canGoPrevious[\s\S]*RoundIconButton\(\$r\('sys\.symbol\.chevron_right'\), this\.canGoNext/, 'ReaderChrome must keep previous/next navigation controls available')
assert.match(readerChromeSource, /ModeMenu\(\)[\s\S]*ReaderMode\.SINGLE_PAGE[\s\S]*ReaderMode\.DUAL_PAGE[\s\S]*ReaderMode\.CONTINUOUS_SCROLL/, 'ReaderChrome must expose reader mode switching beyond previous and next page buttons')
assert.match(readerChromeSource, /@Param\s+zoomScale:\s*number = 1[\s\S]*reader_action_reset_zoom[\s\S]*onResetZoom\(\)/, 'ReaderChrome must expose reset zoom when the reader is zoomed')
assert.match(readerChromeSource, /@Param\s+volumeKeyBehavior:\s*ReaderVolumeKeyBehavior = 'up_previous_down_next'[\s\S]*@Event onVolumeKeyBehaviorChange[\s\S]*settings_row_reader_volume_key_behavior_title[\s\S]*getReaderVolumeKeyBehaviorLabel\('up_previous_down_next'\)[\s\S]*getReaderVolumeKeyBehaviorLabel\('up_next_down_previous'\)[\s\S]*this\.onVolumeKeyBehaviorChange\(index === 1 \? 'up_next_down_previous' : 'up_previous_down_next'\)/, 'ReaderChrome quick settings must expose volume-key direction as a segmented control')
assert.match(readerChromeSource, /@Event onDismissChrome: \(\) => void = \(\) => \{\}[\s\S]*private hideChrome\(\): void \{[\s\S]*this\.onDismissChrome\(\)[\s\S]*this\.\$visible\(false\)[\s\S]*private MiddleDismissSurface\(\)[\s\S]*Button\(\{ type: ButtonType\.Normal, stateEffect: false \}\)[\s\S]*\.backgroundColor\('#01000000'\)[\s\S]*\.hitTestBehavior\(HitTestMode\.Block\)[\s\S]*\.onClick\(\(\) => \{[\s\S]*this\.hideChrome\(\)[\s\S]*this\.MiddleDismissSurface\(\)/, 'ReaderChrome middle blank area must close chrome through a real transparent hit target instead of swallowing reader taps')
assert.match(readerPageSource, /onDismissChrome: \(\) => \{[\s\S]*this\.activeChromeVisible = false[\s\S]*this\.\$chromeVisible\(false\)/, 'ReaderPage must bind ReaderChrome middle-dismiss clicks back to the parent chrome state')

assert.equal(clampPageIndex(-5, 5), 0, 'negative page indexes clamp to first page')
assert.equal(clampPageIndex(9, 5), 4, 'large page indexes clamp to last page')
assert.equal(clampPageIndex(2.8, 5), 2, 'fractional page indexes floor')
assert.equal(calculateProgressRatio(1, 5), 0.4, 'second page of five is 40%')
assert.equal(calculateProgressRatio(20, 5), 1, 'clamped last page is 100%')
assert.equal(readerModeFromContinuousScroll(false), ReaderMode.SINGLE_PAGE, 'paged reader state maps to single-page mode')
assert.equal(readerModeFromContinuousScroll(true), ReaderMode.CONTINUOUS_SCROLL, 'scroll reader state maps to continuous-scroll mode')
assert.equal(isContinuousScrollReaderMode(ReaderMode.SINGLE_PAGE), false, 'single-page mode is not continuous scroll')
assert.equal(isContinuousScrollReaderMode(ReaderMode.CONTINUOUS_SCROLL), true, 'continuous-scroll mode is recognized by contract')
assert.equal(getReaderModeLabel(ReaderMode.SINGLE_PAGE), '单页', 'single-page mode has a quiet user-facing label')
assert.equal(getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), '连续滚动', 'continuous-scroll mode has a quiet user-facing label')

const splitEdgeEntries = createReaderDisplayEntries(3, [0, 2])
assert.equal(splitEdgeEntries.length, 5, 'split display has more entries than physical pages when wide pages are duplicated into halves')
assert.equal(splitEdgeEntries[1].pageIndex, 0, 'second split half of the first physical page still reports physical page 0')
assert.equal(
  splitAwareCanGoPrevious({ splitMode: true, readerDisplayIndex: 1, pageIndex: splitEdgeEntries[1].pageIndex }),
  true,
  'chrome previous is enabled on the second split half of the first physical page',
)
assert.equal(splitEdgeEntries[3].pageIndex, 2, 'first split half of the last physical page still reports the last physical page')
assert.equal(
  splitAwareCanGoNext({
    splitMode: true,
    readerDisplayIndex: 3,
    pageIndex: splitEdgeEntries[3].pageIndex,
    displayTotal: splitEdgeEntries.length,
    pageTotal: 3,
  }),
  true,
  'chrome next is enabled on the first split half of the last physical page',
)
assert.equal(
  splitAwareCanGoPrevious({ splitMode: false, readerDisplayIndex: 1, pageIndex: 0 }),
  false,
  'non-split previous remains disabled at the first physical page',
)
assert.equal(
  splitAwareCanGoNext({ splitMode: false, readerDisplayIndex: 3, pageIndex: 2, displayTotal: splitEdgeEntries.length, pageTotal: 3 }),
  false,
  'non-split next remains disabled at the last physical page',
)

const config = {
  comicId: 'local-01',
  chapterId: 'chapter-8',
  totalPages: 5,
  pageUris: ['mock://local-01/001.jpg', 'mock://local-01/002.jpg', 'mock://local-01/003.jpg', 'mock://local-01/004.jpg', 'mock://local-01/005.jpg'],
  pageIds: ['mock-page-1', 'mock-page-2', 'mock-page-3', 'mock-page-4', 'mock-page-5'],
}
const store = new InMemoryReaderSessionStore()
assert.equal(store.restorePageIndex(config), 0, 'first open starts on page 1')

const pageTwo = store.updatePageIndex(config, 1, 'mock-page-2')
assert.equal(pageTwo.pageIndex, 1, 'next page stores zero-based page index 1')
assert.equal(pageTwo.pageId, 'mock-page-2')
assert.equal(pageTwo.progressRatio, 0.4)
assert.equal(pageTwo.completed, false)
assert.equal(store.restorePageIndex(config), 1, 'reopening mock reader restores page 2 of 5')

const lastPage = store.updatePageIndex(config, 99, 'mock-page-99')
assert.equal(lastPage.pageIndex, 4, 'stored page index is clamped before save')
assert.equal(lastPage.progressRatio, 1)
assert.equal(lastPage.completed, true)
assert.equal(store.restorePageIndex(config), 4, 'restore also returns clamped last page')

const otherChapter = { ...config, chapterId: 'chapter-9' }
assert.equal(store.restorePageIndex(otherChapter), 0, 'a different chapter starts from first page')

const importedComic = {
  id: 'imported-3-pages',
  title: 'Imported Three Pages',
  chapters: [{
    id: 'chapter-real',
    title: 'Chapter Real',
    pages: [
      { id: 'page-c', uri: 'file://comic/003.jpg', index: 2, sortKey: '003.jpg' },
      { id: 'page-a', uri: 'file://comic/001.jpg', index: 0, sortKey: '001.jpg' },
      { id: 'page-b', uri: 'file://comic/002.jpg', index: 1, sortKey: '002.jpg' },
    ],
  }],
}
const importedConfig = createReaderSessionConfigFromComic(importedComic)
assert.equal(importedConfig.totalPages, 3, 'reader session page count must come from Comic pages')
assert.deepEqual(importedConfig.pageUris, ['file://comic/001.jpg', 'file://comic/002.jpg', 'file://comic/003.jpg'], 'reader session must preserve ordered page URIs')
assert.equal(getReaderSessionPageUri(importedConfig, 1), 'file://comic/002.jpg', 'page index 1 must map to second page URI')
assert.equal(getReaderSessionPageId(importedConfig, 2), 'page-c', 'page index 2 must map to third page id')

const importedStore = new InMemoryReaderSessionStore()
assert.equal(importedStore.restorePageIndex(importedConfig), 0, 'imported comic first open starts on page 1')
const importedPageTwo = importedStore.updatePageIndex(importedConfig, 1, getReaderSessionPageId(importedConfig, 1))
assert.equal(importedPageTwo.totalPages, 3, 'imported progress stores real page count')
assert.equal(importedPageTwo.pageIndex, 1)
assert.equal(importedPageTwo.pageId, 'page-b')
assert.equal(importedStore.restorePageIndex(importedConfig), 1, 'imported comic restore uses saved real page index')
assert.equal(getReaderSessionPageUri(importedConfig, importedStore.restorePageIndex(importedConfig)), 'file://comic/002.jpg', 'restored page index maps back to the saved page URI')

const sourceRuntimeConfig = {
  comicId: 'source-comic',
  chapterId: 'source-chapter',
  totalPages: 2,
  pageUris: ['source://descriptor/one', 'https://cdn.example.test/fallback/002.jpg'],
  pageIds: ['page:source:001', 'page:source:002'],
  sourceRuntimeId: 'local.test.koma.fixture',
}
const descriptorPage = createReaderPageRenderSource(sourceRuntimeConfig, 0)
assert.equal(descriptorPage.kind, ReaderPageRenderKind.REMOTE_URL_IMAGE, 'source runtime descriptor pages render through remote cache path')
assert.equal(descriptorPage.sourceRuntimeId, 'local.test.koma.fixture', 'source runtime id is preserved on render source')
assert.equal(descriptorPage.pageId, 'page:source:001', 'source runtime page index resolves to pageId')
assert.equal(descriptorPage.imageUri, 'source-runtime://local.test.koma.fixture/page%3Asource%3A001', 'source runtime descriptor page gets a stable non-secret render key')
const fallbackUrlPage = createReaderPageRenderSource(sourceRuntimeConfig, 1)
assert.equal(fallbackUrlPage.pageUri, 'https://cdn.example.test/fallback/002.jpg', 'ordinary URL page URI is preserved for fallback')
const offlineSourceRuntimePage = createReaderPageRenderSource(sourceRuntimeConfig, 0, { offlineOnly: true })
assert.equal(offlineSourceRuntimePage.kind, ReaderPageRenderKind.URI_PLACEHOLDER, 'offline-only reader must not render source runtime remote pages when no downloaded page is available')
assert.match(offlineSourceRuntimePage.uri, /^offline-missing:\/\//, 'offline-only missing source pages must use an honest offline placeholder')

const imageRequestPayload = sourceRuntimeImageRequestPayload({
  imageRequest: {
    url: 'https://images.example.test/page/001.jpg',
    headersRef: 'defaultImage',
    cacheKey: 'chapter-1-page-1',
    headers: {
      Referer: 'https://images.example.test/chapter',
      'User-Agent': 'KomaSource/1',
    },
  },
})
assert.equal(imageRequestPayload.url, 'https://images.example.test/page/001.jpg', 'source image_request resolves effective image URL')
assert.equal(imageRequestPayload.headers.Referer, 'https://images.example.test/chapter', 'source image_request resolves request headers')
assert.equal(imageRequestPayload.headersRef, 'defaultImage', 'source image_request preserves host-owned header references')
assert.equal(imageRequestPayload.cacheKey, 'chapter-1-page-1', 'source image_request preserves source-owned cache keys')

const baseCacheKey = cacheKeyFor('https://images.example.test/page/001.jpg', { Accept: 'image/webp' })
const authCacheKey = cacheKeyFor('https://images.example.test/page/001.jpg', { Accept: 'image/webp', Cookie: 'session=opaque' })
const urlCacheKey = cacheKeyFor('https://images.example.test/page/002.jpg', { Accept: 'image/webp' })
const sourceCacheKey = cacheKeyFor('https://images.example.test/page/001.jpg', { Accept: 'image/webp' }, 'source:local.test.koma.fixture:image:chapter-1-page-1')
assert.notEqual(baseCacheKey, authCacheKey, 'remote image cache key must vary by headers')
assert.notEqual(baseCacheKey, urlCacheKey, 'remote image cache key must vary by effective URL')
assert.notEqual(baseCacheKey, sourceCacheKey, 'source image cache key seed must isolate source-owned cache identities')
assert.equal(stableHeadersKey({ 'User-Agent': 'A', Referer: 'B' }), 'referer=B\nuser-agent=A', 'header cache key is stable and sorted')

const renderCases = [
  {
    uri: 'mock://local-01/001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'mock URI remains placeholder',
  },
  {
    uri: '/data/storage/el2/base/cache/import/demo-12345678/extract/001.jpg',
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    imageUri: '/data/storage/el2/base/cache/import/demo-12345678/extract/001.jpg',
    label: 'app cache extracted image path renders locally',
  },
  {
    uri: 'file:///data/storage/el2/base/haps/entry/cache/import/koma-qa-import-real-image-977e3a1b/extract/001-normal.png',
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    imageUri: '/data/storage/el2/base/haps/entry/cache/import/koma-qa-import-real-image-977e3a1b/extract/001-normal.png',
    label: 'app haps entry cache extracted PNG file URI renders as an absolute path',
  },
  {
    uri: 'file:///data/storage/el2/base/cache/import/demo-12345678/extract/nested/002.webp',
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    imageUri: '/data/storage/el2/base/cache/import/demo-12345678/extract/nested/002.webp',
    label: 'app cache extracted file URI renders locally',
  },
  {
    uri: 'file:///data/storage/el2/base/haps/entry/cache/import/demo-12345678/extract/nested/page%231.avif',
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    imageUri: '/data/storage/el2/base/haps/entry/cache/import/demo-12345678/extract/nested/page#1.avif',
    label: 'encoded app cache extracted AVIF file URI renders as a decoded filesystem path',
  },
  {
    uri: 'file:///data/storage/el2/base/haps/entry/cache/import/demo-12345678/extract/002-hash%23query%3F.png',
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    imageUri: '/data/storage/el2/base/haps/entry/cache/import/demo-12345678/extract/002-hash#query?.png',
    label: 'encoded reserved path segments decode only after safe local classification',
  },
  {
    uri: '/data/storage/el2/base/files/import/demo-12345678/extract/003.png',
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    imageUri: '/data/storage/el2/base/files/import/demo-12345678/extract/003.png',
    label: 'app files extracted image path renders locally',
  },
  {
    uri: 'http://example.com/001.jpg',
    kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
    imageUri: 'http://example.com/001.jpg',
    label: 'http renders through remote image cache',
  },
  {
    uri: 'content://media/external/images/001',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'content URI stays unsupported placeholder',
  },
  {
    uri: 'docs://provider/001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'docs URI stays unsupported placeholder',
  },
  {
    uri: '/data/storage/el2/base/cache/import/demo-12345678/archive.zip#001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'archive entry DTO stays unsupported placeholder',
  },
  {
    uri: 'file:///data/storage/el2/base/haps/entry/cache/import/demo-12345678/archive.cbz#001-normal.png',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'raw cbz archive entry DTO under haps cache stays unsupported placeholder',
  },
  {
    uri: 'file:///data/storage/el2/base/cache/import/demo-12345678/extract/page#1.png',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'raw fragment-like local file URI stays unsupported placeholder',
  },
  {
    uri: 'file:///data/storage/el2/base/cache/import/demo-12345678/extract/page?1.png',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'raw query-like local file URI stays unsupported placeholder',
  },
  {
    uri: '/data/storage/el2/base/cache/import/demo-12345678/extract/../001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'traversal path stays unsupported placeholder',
  },
  {
    uri: '/sdcard/cache/import/demo/extract/001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'sdcard shaped import path stays unsupported placeholder',
  },
  {
    uri: '/tmp/cache/import/demo/extract/001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'tmp shaped import path stays unsupported placeholder',
  },
  {
    uri: 'file:///data/storage/el2/base/haps/entry/cache/import/demo-12345678/extract/%2E%2E/001.png',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'encoded traversal segments stay unsupported placeholder',
  },
  {
    uri: 'file:///sdcard/cache/import/demo/extract/001.jpg',
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'sdcard shaped file URI stays unsupported placeholder',
  },
]

renderCases.forEach((item, index) => {
  const source = createReaderPageRenderSource({
    comicId: `render-case-${index}`,
    chapterId: 'chapter-1',
    totalPages: 1,
    pageUris: [item.uri],
    pageIds: ['page-1'],
  }, 0)
  assert.equal(source.kind, item.kind, item.label)
  assert.equal(source.imageUri, item.imageUri, `${item.label} imageUri`)
})

const offlineLocalPage = createReaderPageRenderSource({
  comicId: 'offline-local',
  chapterId: 'chapter-1',
  totalPages: 1,
  pageUris: ['/data/storage/el2/base/cache/import/demo-12345678/extract/001.jpg'],
  pageIds: ['page-1'],
}, 0, { offlineOnly: true })
assert.equal(offlineLocalPage.kind, ReaderPageRenderKind.LOCAL_FILE_IMAGE, 'offline-only reader must still render app-sandbox local imported pages')

const qaUri = 'file:///data/storage/el2/base/haps/entry/cache/import/koma-qa-import-real-image-1c7a8c1-1680328b/extract/001-normal.png'
const qaDiagnostics = createReaderUriDiagnostics(qaUri, 0)
assert.equal(qaDiagnostics.kind, ReaderPageRenderKind.LOCAL_FILE_IMAGE, 'QA URI diagnostics must classify as local file image')
assert.equal(qaDiagnostics.imageSourceForm, 'absolute_path', 'QA URI diagnostics must report absolute Image source')
assert.equal(qaDiagnostics.hasFileScheme, true, 'QA URI diagnostics must report file scheme')
assert.equal(qaDiagnostics.hasRawFragmentOrQuery, false, 'QA URI diagnostics must reject raw fragment/query only when present')
assert.equal(qaDiagnostics.matchedSandboxRoot, 'cache_haps_entry', 'QA URI diagnostics must report haps entry cache root')
assert.equal(qaDiagnostics.extension, 'png', 'QA URI diagnostics must report extension')
assert.match(qaDiagnostics.uriHash, /^[0-9a-f]{8}$/, 'QA URI diagnostics must include short uri hash')
assert.match(qaDiagnostics.sourceHash, /^[0-9a-f]{8}$/, 'QA URI diagnostics must include short source hash')
assertNoPrivatePathLeak(qaDiagnostics)

const archiveDiagnostics = createReaderUriDiagnostics('file:///data/storage/el2/base/haps/entry/cache/import/demo-12345678/archive.cbz#001-normal.png', 1)
assert.equal(archiveDiagnostics.kind, ReaderPageRenderKind.URI_PLACEHOLDER, 'archive entry diagnostics must remain placeholder')
assert.equal(archiveDiagnostics.imageSourceForm, 'none', 'archive entry diagnostics must have no image source')
assert.equal(archiveDiagnostics.hasRawFragmentOrQuery, true, 'archive entry diagnostics must flag raw fragment')

const sdcardDiagnostics = createReaderUriDiagnostics('/sdcard/cache/import/demo/extract/001.jpg', 2)
assert.equal(sdcardDiagnostics.kind, ReaderPageRenderKind.URI_PLACEHOLDER, 'sdcard diagnostics must remain placeholder')
assert.equal(sdcardDiagnostics.matchedSandboxRoot, 'none', 'sdcard diagnostics must not match app sandbox roots')

const encodedDiagnostics = createReaderUriDiagnostics('file:///data/storage/el2/base/haps/entry/cache/import/demo-12345678/extract/002-hash%23query%3F.png', 3)
assert.equal(encodedDiagnostics.kind, ReaderPageRenderKind.LOCAL_FILE_IMAGE, 'encoded reserved filename diagnostics must remain local image')
assert.equal(encodedDiagnostics.imageSourceForm, 'absolute_path', 'encoded reserved filename diagnostics must report absolute path')
assert.equal(encodedDiagnostics.hasRawFragmentOrQuery, false, 'encoded reserved filename diagnostics must not flag raw fragment/query')
assert.equal(encodedDiagnostics.matchedSandboxRoot, 'cache_haps_entry', 'encoded reserved filename diagnostics must match haps cache root')
assert.equal(encodedDiagnostics.extension, 'png', 'encoded reserved filename diagnostics must report png extension')
assertNoPrivatePathLeak(encodedDiagnostics)

console.log('PASS Koma reader progress contracts')
