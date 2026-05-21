import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/model/ComicModels.ets')
const libraryStorePath = resolve(root, 'entry/src/main/ets/model/LibraryStore.ets')
const progressStorePath = resolve(root, 'entry/src/main/ets/model/ReadingProgressStore.ets')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')
const mockLibraryDataPath = resolve(root, 'entry/src/main/ets/model/MockLibraryData.ets')
const libraryRepositoryPath = resolve(root, 'entry/src/main/ets/model/LibraryRepository.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const libraryStoreSource = readFileSync(libraryStorePath, 'utf8')
const progressStoreSource = readFileSync(progressStorePath, 'utf8')
const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')
const mockLibraryDataSource = readFileSync(mockLibraryDataPath, 'utf8')
const libraryRepositorySource = readFileSync(libraryRepositoryPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
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
assertExport(mockLibraryDataSource, 'MockLibraryComic')
assertExport(mockLibraryDataSource, 'LibraryViewModel')
assertExport(mockLibraryDataSource, 'MOCK_LIBRARY_READER_SESSION')
assertExport(mockLibraryDataSource, 'createSeededLibraryStore')
assertExport(mockLibraryDataSource, 'createLibraryViewModelFromStores')
assertExport(mockLibraryDataSource, 'createLibraryViewModel')
assertExport(libraryRepositorySource, 'LibraryRepository')
assertExport(libraryRepositorySource, 'StoreBackedLibraryRepository')
assertExport(libraryRepositorySource, 'upsertComicAndCreateLibraryViewModel')

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

const mockLibraryReaderSession = {
  comicId: 'local-01',
  chapterId: 'chapter-8',
  totalPages: 5,
}

const mockLibraryComics = [
  {
    id: 'local-01',
    title: '雨后街区',
    subtitle: '本地 ZIP - 12 章',
    chapterTitle: '第 8 话',
    fallbackProgressText: '第 8 话',
    coverColor: '#16745F',
    accentColor: '#2FAE84',
    pageCount: 5,
  },
  {
    id: 'local-02',
    title: '北窗短篇集',
    subtitle: '图片文件夹 - 6 章',
    chapterTitle: '第 1 话',
    fallbackProgressText: '未读',
    coverColor: '#344E7A',
    accentColor: '#6E92CE',
    pageCount: 1,
  },
  {
    id: 'local-03',
    title: '海边的慢速列车',
    subtitle: 'CBZ - 4 章',
    chapterTitle: '第 2 话',
    fallbackProgressText: '42%',
    coverColor: '#8A6240',
    accentColor: '#D39A62',
    pageCount: 1,
  },
  {
    id: 'local-04',
    title: '午后三点的笔记',
    subtitle: '本地 ZIP - 18 章',
    chapterTitle: '第 3 话',
    fallbackProgressText: '第 3 话',
    coverColor: '#7A405D',
    accentColor: '#C46B92',
    pageCount: 1,
  },
  {
    id: 'local-05',
    title: '旧书店巡礼',
    subtitle: '图片文件夹 - 9 章',
    chapterTitle: '第 1 话',
    fallbackProgressText: '新加入',
    coverColor: '#51624D',
    accentColor: '#89A57D',
    pageCount: 1,
  },
  {
    id: 'local-06',
    title: '银河便签',
    subtitle: 'CBZ - 21 章',
    chapterTitle: '第 15 话',
    fallbackProgressText: '第 15 话',
    coverColor: '#4C4A70',
    accentColor: '#928FD2',
    pageCount: 1,
  },
]

function progressPercent(progress) {
  if (progress === undefined) return 0
  return Math.round(progress.progressRatio * 100)
}

function formatLibraryProgressText(comic, progress) {
  if (progress === undefined) return comic.fallbackProgressText
  if (progress.completed) return '已读完'
  return `${progressPercent(progress)}%`
}

function createMockComic(item, createdAt) {
  const chapterId = item.id === mockLibraryReaderSession.comicId ? mockLibraryReaderSession.chapterId : `${item.id}-chapter-1`
  const pages = Array.from({ length: item.pageCount }, (_, index) => ({
    id: `${chapterId}-page-${index + 1}`,
    comicId: item.id,
    chapterId,
    index,
    fileName: `${String(index + 1).padStart(3, '0')}.jpg`,
    uri: `mock://${item.id}/${String(index + 1).padStart(3, '0')}.jpg`,
    sortKey: `${String(index + 1).padStart(3, '0')}.jpg`,
  }))
  return {
    id: item.id,
    title: item.title,
    subtitle: item.subtitle,
    sourceKind: 'local_archive',
    sourcePath: `mock://${item.id}`,
    coverUri: pages[0]?.uri,
    sortTitle: normalizeSortKey(item.title),
    preferredDirection: 'right_to_left',
    chapters: [{
      id: chapterId,
      comicId: item.id,
      title: item.chapterTitle,
      index: 0,
      sourcePath: `mock://${item.id}`,
      sortKey: normalizeSortKey(item.chapterTitle),
      pages,
      pageCount: pages.length,
      createdAt,
      updatedAt: createdAt,
    }],
    chapterCount: 1,
    pageCount: pages.length,
    createdAt,
    updatedAt: createdAt,
    lastImportedAt: createdAt,
  }
}

function createSeededStore() {
  const comics = new Map()
  mockLibraryComics.forEach((item, index) => {
    const comic = createMockComic(item, index + 1)
    comics.set(comic.id, comic)
  })
  return {
    upsertComic(comic) {
      comics.set(comic.id, comic)
    },
    listComics() {
      return Array.from(comics.values()).sort((a, b) => {
        const titleCompare = a.sortTitle.localeCompare(b.sortTitle)
        return titleCompare !== 0 ? titleCompare : a.createdAt - b.createdAt
      })
    },
  }
}

function createPresentationMap() {
  return new Map(mockLibraryComics.map((item) => [item.id, item]))
}

function getChapterTitle(comic, progress, presentation) {
  if (progress !== undefined) {
    const chapter = comic.chapters.find((item) => item.id === progress.chapterId)
    if (chapter !== undefined) return chapter.title
  }
  return presentation?.chapterTitle ?? comic.chapters[0]?.title ?? comic.title
}

function createLibraryViewModelFromStores(store, progressByComicId, presentationByComicId = new Map()) {
  const storeComics = store.listComics()
  const comics = storeComics.map((comic) => {
    const itemProgress = progressByComicId.get(comic.id)
    const presentation = presentationByComicId.get(comic.id)
    return {
      id: comic.id,
      title: comic.title,
      subtitle: presentation?.subtitle ?? comic.subtitle ?? `本地 ZIP - ${comic.chapterCount} 章`,
      progressText: formatLibraryProgressText(presentation ?? { fallbackProgressText: '未读' }, itemProgress),
      coverColor: presentation?.coverColor ?? '#16745F',
      accentColor: presentation?.accentColor ?? '#2FAE84',
      pageCount: comic.pageCount,
      coverUri: comic.coverUri,
    }
  })
  let continueComic = storeComics[0]
  let continueProgress
  for (const item of storeComics) {
    const itemProgress = progressByComicId.get(item.id)
    if (itemProgress !== undefined && (continueProgress === undefined || itemProgress.updatedAt > continueProgress.updatedAt)) {
      continueComic = item
      continueProgress = itemProgress
    }
  }
  const continuePresentation = presentationByComicId.get(continueComic.id)
  const chapterTitle = getChapterTitle(continueComic, continueProgress, continuePresentation)
  return {
    comics,
    continueReading: {
      title: continueComic.title,
      detail: continueProgress === undefined ? `继续阅读 ${chapterTitle}` : `继续阅读 ${chapterTitle} / 第 ${continueProgress.pageIndex + 1} 页 · ${progressPercent(continueProgress)}%`,
      progress: continueProgress === undefined ? 0 : progressPercent(continueProgress),
      color: continuePresentation?.coverColor ?? '#16745F',
      comicId: continueComic.id,
      coverUri: continueComic.coverUri,
    },
  }
}

const sessionProgress = updateReadingProgress(
  createReadingProgress(mockLibraryReaderSession.comicId, mockLibraryReaderSession.chapterId, mockLibraryReaderSession.totalPages),
  1,
  'mock-page-2',
  mockLibraryReaderSession.totalPages,
)
const seededStore = createSeededStore()
const seededVm = createLibraryViewModelFromStores(seededStore, new Map(), createPresentationMap())
assert.equal(seededVm.comics.length, 6, 'initial mock seed should generate the current six-book shelf')
assert.equal(seededVm.comics.find((item) => item.id === 'local-01').title, '雨后街区')
assert.equal(seededVm.comics.find((item) => item.id === 'local-01').coverUri, 'mock://local-01/001.jpg')

const libraryVm = createLibraryViewModelFromStores(seededStore, new Map([[sessionProgress.comicId, sessionProgress]]), createPresentationMap())
assert.equal(libraryVm.continueReading.title, '雨后街区')
assert.equal(libraryVm.continueReading.detail, '继续阅读 第 8 话 / 第 2 页 · 40%')
assert.equal(libraryVm.continueReading.progress, 40)
assert.equal(libraryVm.continueReading.comicId, 'local-01')
assert.equal(libraryVm.comics.find((item) => item.id === 'local-01').progressText, '40%')

const importedComic = {
  id: 'imported-01',
  title: 'Imported Volume',
  sourceKind: 'local_archive',
  sourcePath: '/library/Imported Volume.cbz',
  coverUri: '/library/Imported Volume.cbz#001.jpg',
  sortTitle: normalizeSortKey('Imported Volume'),
  preferredDirection: 'right_to_left',
  chapters: [{
    id: 'imported-01-chapter-1',
    comicId: 'imported-01',
    title: 'Imported Volume',
    index: 0,
    sourcePath: '/library/Imported Volume.cbz',
    sortKey: normalizeSortKey('Imported Volume'),
    pages: [
      { id: 'imported-page-1', comicId: 'imported-01', chapterId: 'imported-01-chapter-1', index: 0, fileName: '001.jpg', uri: '/library/Imported Volume.cbz#001.jpg', sortKey: '001.jpg' },
      { id: 'imported-page-2', comicId: 'imported-01', chapterId: 'imported-01-chapter-1', index: 1, fileName: '002.jpg', uri: '/library/Imported Volume.cbz#002.jpg', sortKey: '002.jpg' },
      { id: 'imported-page-3', comicId: 'imported-01', chapterId: 'imported-01-chapter-1', index: 2, fileName: '003.jpg', uri: '/library/Imported Volume.cbz#003.jpg', sortKey: '003.jpg' },
    ],
    pageCount: 3,
    createdAt: 500,
    updatedAt: 500,
  }],
  chapterCount: 1,
  pageCount: 3,
  createdAt: 500,
  updatedAt: 500,
  lastImportedAt: 500,
}

seededStore.upsertComic(importedComic)
const importedVm = createLibraryViewModelFromStores(seededStore, new Map(), createPresentationMap())
const importedCard = importedVm.comics.find((item) => item.id === 'imported-01')
assert.equal(importedVm.comics.length, 7, 'upsert should add imported comic to the shelf view model')
assert.equal(importedCard.title, 'Imported Volume')
assert.equal(importedCard.pageCount, 3)
assert.equal(importedCard.coverUri, '/library/Imported Volume.cbz#001.jpg')

const importedProgress = updateReadingProgress(
  createReadingProgress('imported-01', 'imported-01-chapter-1', 3),
  1,
  'imported-page-2',
  3,
)
const importedProgressVm = createLibraryViewModelFromStores(seededStore, new Map([[importedProgress.comicId, importedProgress]]), createPresentationMap())
assert.equal(importedProgressVm.continueReading.title, 'Imported Volume')
assert.equal(importedProgressVm.continueReading.detail, '继续阅读 Imported Volume / 第 2 页 · 67%')
assert.equal(importedProgressVm.continueReading.progress, 67)
assert.equal(importedProgressVm.comics.find((item) => item.id === 'imported-01').progressText, '67%')

console.log('PASS Koma model contracts')
