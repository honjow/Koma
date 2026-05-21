import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')
const readerPageSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const readerPagePath = resolve(root, 'entry/src/main/ets/pages/ReaderPage.ets')
const readerChromePath = resolve(root, 'entry/src/main/ets/components/ReaderChrome.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')

const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')
const readerPageSourceAdapterSource = readFileSync(readerPageSourceAdapterPath, 'utf8')
const readerPageSource = readFileSync(readerPagePath, 'utf8')
const readerChromeSource = readFileSync(readerChromePath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type) ${symbol}\\b`), `${symbol} must be exported`)
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

const ReaderPageRenderKind = {
  MOCK_FALLBACK: 'mock_fallback',
  LOCAL_FILE_IMAGE: 'local_file_image',
  URI_PLACEHOLDER: 'uri_placeholder',
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

function createReaderPageRenderSource(config, pageIndex) {
  const uri = getReaderSessionPageUri(config, pageIndex)
  if (uri.length === 0 || uri.startsWith('mock://')) {
    return {
      kind: ReaderPageRenderKind.MOCK_FALLBACK,
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
  return {
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    uri,
    imageUri: '',
    fallbackPageIndex: pageIndex,
  }
}

function getReaderSessionPageId(config, pageIndex) {
  const resolvedPageIndex = clampPageIndex(pageIndex, config.totalPages)
  return config.pageIds[resolvedPageIndex] ?? `page-${resolvedPageIndex + 1}`
}

assertExport(readerSessionStoreSource, 'ReaderSessionConfig')
assertExport(readerSessionStoreSource, 'ReaderSessionStore')
assertExport(readerSessionStoreSource, 'InMemoryReaderSessionStore')
assertExport(readerSessionStoreSource, 'createReaderSessionConfigFromComic')
assertExport(readerSessionStoreSource, 'getReaderSessionPageUri')
assertExport(readerPageSourceAdapterSource, 'ReaderPageRenderKind')
assertExport(readerPageSourceAdapterSource, 'isReaderLocalImageSourceUri')
assertExport(readerPageSourceAdapterSource, 'createReaderImageSourceUri')
assertExport(readerPageSourceAdapterSource, 'createReaderPageRenderSource')
assertExport(readerPageSourceAdapterSource, 'ReaderPageRenderDiagnostics')
assertExport(readerPageSourceAdapterSource, 'createReaderUriDiagnostics')
assertExport(readerPageSourceAdapterSource, 'createReaderPageRenderDiagnostics')
assert.match(readerSessionStoreSource, /ReadingProgressStore/, 'reader session store must wrap ReadingProgressStore')
assert.match(readerSessionStoreSource, /clampPageIndex/, 'reader session restore/update must clamp page indexes')
assert.match(readerSessionStoreSource, /pageUris: pages\.map/, 'reader session config must carry ordered page URIs')
assert.match(indexSource, /createReaderSessionConfigFromComic/, 'index must open reader sessions from Comic records')
assert.match(indexSource, /restorePageIndex\(this\.readerSessionConfig\)/, 'opening reader must restore from the selected session config')
assert.match(indexSource, /sessionStore: this\.readerSessionStore/, 'library and reader must share the same session store')
assert.match(indexSource, /Navigation\(this\.readerPathStack\)/, 'reader must be hosted by an in-app Navigation stack')
assert.match(indexSource, /pushPath\(\{\s*name:\s*READER_ROUTE_NAME\s*\}\)/, 'opening reader must push a reader route')
assert.match(indexSource, /\.onBackPressed\(\(\) => \{[\s\S]*this\.closeReader\(\)[\s\S]*return true/, 'reader route must intercept system back and close reader')
assert.match(indexSource, /onBackPress\(\): boolean \{[\s\S]*this\.closeReader\(\)[\s\S]*return true/, 'entry page back fallback must close an open reader instead of exiting')
assert.match(readerPageSource, /updatePageIndex\(this\.sessionConfig/, 'reader page changes must update session progress')
assert.match(readerPageSource, /ReaderPageRenderKind\.LOCAL_FILE_IMAGE/, 'reader page must render accepted local file images through a distinct path')
assert.match(readerPageSource, /ReaderPageRenderKind\.URI_PLACEHOLDER/, 'reader page must isolate URI rendering behind an explicit placeholder path')
assert.match(readerPageSource, /image\.createImageSource\(sourceUri\)/, 'reader page must decode accepted local image sources through ImageKit')
assert.match(readerPageSource, /createPixelMap\(\)/, 'reader page must create a PixelMap for local image rendering')
assert.match(readerPageSource, /Image\(this\.pixelMap\)/, 'reader page must pass decoded PixelMap objects to ArkUI Image')
assert.doesNotMatch(readerPageSource, /Image\(imageUri\)/, 'reader page must not pass sandbox path strings directly to ArkUI Image')
assert.match(readerPageSource, /onDecodeFailed:[\s\S]*recordImageLoadFailure/, 'reader image decode failures must return to a visible error placeholder')
assert.match(readerPageSource, /\[reader-source\]/, 'reader page must log redacted source diagnostics')
assert.match(readerPageSource, /\[reader-image-error\]/, 'reader page must log redacted image error diagnostics')
assert.match(readerPageSource, /expandSafeArea\(\[SafeAreaType\.SYSTEM\], \[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/, 'reader background may extend into system safe areas')
assert.match(readerChromeSource, /onCloseReader/, 'chrome return button must delegate to the reader route close callback')
assert.match(readerChromeSource, /top: 24/, 'top reader chrome must reserve room for the status bar on fullscreen windows')
assert.match(readerChromeSource, /bottom: 42/, 'bottom reader controls must reserve room for the navigation safe area on fullscreen windows')
assert.match(readerChromeSource, /onPreviousPage/, 'chrome previous button must use reader callback')
assert.match(readerChromeSource, /onNextPage/, 'chrome next button must use reader callback')

assert.equal(clampPageIndex(-5, 5), 0, 'negative page indexes clamp to first page')
assert.equal(clampPageIndex(9, 5), 4, 'large page indexes clamp to last page')
assert.equal(clampPageIndex(2.8, 5), 2, 'fractional page indexes floor')
assert.equal(calculateProgressRatio(1, 5), 0.4, 'second page of five is 40%')
assert.equal(calculateProgressRatio(20, 5), 1, 'clamped last page is 100%')

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

const renderCases = [
  {
    uri: 'mock://local-01/001.jpg',
    kind: ReaderPageRenderKind.MOCK_FALLBACK,
    imageUri: '',
    label: 'mock URI remains mock fallback',
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
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    imageUri: '',
    label: 'http stays unsupported placeholder',
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
