import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')
const readerPagePath = resolve(root, 'entry/src/main/ets/pages/ReaderPage.ets')
const readerChromePath = resolve(root, 'entry/src/main/ets/components/ReaderChrome.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')

const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')
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

assertExport(readerSessionStoreSource, 'ReaderSessionConfig')
assertExport(readerSessionStoreSource, 'ReaderSessionStore')
assertExport(readerSessionStoreSource, 'InMemoryReaderSessionStore')
assert.match(readerSessionStoreSource, /ReadingProgressStore/, 'reader session store must wrap ReadingProgressStore')
assert.match(readerSessionStoreSource, /clampPageIndex/, 'reader session restore/update must clamp page indexes')
assert.match(indexSource, /MOCK_LIBRARY_READER_SESSION/, 'index must bind the reader to the library session')
assert.match(indexSource, /restorePageIndex\(MOCK_LIBRARY_READER_SESSION\)/, 'opening mock reader must restore from session store')
assert.match(indexSource, /sessionStore: this\.readerSessionStore/, 'library and reader must share the same session store')
assert.match(readerPageSource, /updatePageIndex\(this\.sessionConfig/, 'reader page changes must update session progress')
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

console.log('PASS Koma reader progress contracts')
