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
assertExport(readerPageSourceAdapterSource, 'createReaderPageRenderSource')
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
assert.match(readerPageSource, /ReaderPageRenderKind\.URI_PLACEHOLDER/, 'reader page must isolate URI rendering behind an explicit placeholder path')
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

console.log('PASS Koma reader progress contracts')
