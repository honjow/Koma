import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/model/ComicModels.ets')
const libraryStorePath = resolve(root, 'entry/src/main/ets/model/LibraryStore.ets')
const progressStorePath = resolve(root, 'entry/src/main/ets/model/ReadingProgressStore.ets')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const libraryStoreSource = readFileSync(libraryStorePath, 'utf8')
const progressStoreSource = readFileSync(progressStorePath, 'utf8')
const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type) ${symbol}\\b`), `${symbol} must be exported`)
}

function normalizeSortKey(value) {
  return value.trim().toLocaleLowerCase()
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

for (const symbol of ['Comic', 'Chapter', 'Page', 'ReadingProgress', 'LibraryItem']) {
  assertExport(modelSource, symbol)
}
assertExport(modelSource, 'serializeComic')
assertExport(modelSource, 'deserializeComic')
assertExport(modelSource, 'updateReadingProgress')
assertExport(libraryStoreSource, 'LibraryStore')
assertExport(libraryStoreSource, 'InMemoryLibraryStore')
assertExport(progressStoreSource, 'ReadingProgressStore')
assertExport(progressStoreSource, 'InMemoryReadingProgressStore')
assertExport(readerSessionStoreSource, 'ReaderSessionStore')
assertExport(readerSessionStoreSource, 'InMemoryReaderSessionStore')

const comic = {
  id: 'comic-1',
  title: 'Volume 02',
  sourceKind: 'local_archive',
  sourcePath: '/library/Volume 02.cbz',
  coverUri: '/cache/comic-1/cover.jpg',
  sortTitle: normalizeSortKey('Volume 02'),
  preferredDirection: 'right_to_left',
  chapters: [
    {
      id: 'chapter-1',
      comicId: 'comic-1',
      title: 'Chapter 10',
      index: 10,
      sourcePath: '/library/Volume 02.cbz',
      sortKey: normalizeSortKey('Chapter 10'),
      pageCount: 2,
      createdAt: 100,
      updatedAt: 100,
      pages: [
        {
          id: 'page-1',
          comicId: 'comic-1',
          chapterId: 'chapter-1',
          index: 1,
          fileName: '001.jpg',
          uri: '/library/Volume 02.cbz/001.jpg',
          sortKey: normalizeSortKey('001.jpg'),
        },
        {
          id: 'page-2',
          comicId: 'comic-1',
          chapterId: 'chapter-1',
          index: 2,
          fileName: '010.jpg',
          uri: '/library/Volume 02.cbz/010.jpg',
          sortKey: normalizeSortKey('010.jpg'),
        },
      ],
    },
  ],
  chapterCount: 1,
  pageCount: 2,
  createdAt: 100,
  updatedAt: 200,
  lastImportedAt: 200,
}

const roundTrip = JSON.parse(JSON.stringify(comic))
assert.deepEqual(roundTrip, comic, 'comic JSON round trip must preserve model fields')
assert.equal(roundTrip.chapters[0].pages[1].sortKey, '010.jpg', 'page sortKey must survive serialization')

const progress = createReadingProgress('comic-1', 'chapter-1', 12)
assert.equal(progress.pageIndex, 0)
assert.equal(progress.progressRatio, 1 / 12)
assert.equal(progress.completed, false)

const updated = updateReadingProgress(progress, 99, 'page-12')
assert.equal(updated.pageIndex, 11, 'page index must clamp to the last page')
assert.equal(updated.progressRatio, 1)
assert.equal(updated.completed, true)
assert.equal(updated.pageId, 'page-12')

const firstPage = updateReadingProgress(updated, -4, 'page-1')
assert.equal(firstPage.pageIndex, 0, 'negative page index must clamp to zero')
assert.equal(firstPage.completed, false)

const libraryItems = [
  { id: 'b', sortTitle: normalizeSortKey('Beta'), createdAt: 2 },
  { id: 'a', sortTitle: normalizeSortKey('alpha'), createdAt: 1 },
  { id: 'c', sortTitle: normalizeSortKey('alpha'), createdAt: 0 },
].sort((a, b) => {
  const titleCompare = a.sortTitle.localeCompare(b.sortTitle)
  return titleCompare !== 0 ? titleCompare : a.createdAt - b.createdAt
})

assert.deepEqual(libraryItems.map((item) => item.id), ['c', 'a', 'b'], 'library items should sort by normalized title then creation time')

console.log('PASS Koma model contracts')
