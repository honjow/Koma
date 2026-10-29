const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function compile(file, dependencies) {
  const { outputText } = ts.transpileModule(fs.readFileSync(path.join(root, file + '.ets'), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  })
  const module = { exports: {} }
  new Function('require', 'module', 'exports', outputText)(name => {
    assert.ok(Object.hasOwn(dependencies, name), `Missing test dependency ${name}`)
    return dependencies[name]
  }, module, module.exports)
  return module.exports
}
const strings = { AppStrings: { get: key => ({
  library_progress_continue_page: '第 %s 页 · %s% · %s',
  library_progress_continue_page_only: '第 %s 页 · %s%',
}[key] || key), format: (key, ...values) => `${key}:${values.join('/')}` } }
const models = compile('model/ComicModels', { '../i18n/AppStrings': strings })
const stores = compile('model/ReaderSessionStore', {
  '../sourceRuntime/SourceRuntimeAppRegistry': { sourceChapterOrderFor: () => undefined },
  './SourceTextPageDescriptor': compile('model/SourceTextPageDescriptor', {}),
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: {} },
  './AppFileTextPersistence': { writeAppTextFile() {} },
  '@kit.CoreFileKit': { fileIo: {} },
  './ComicModels': models,
  './ReaderChapterSequence': compile('model/ReaderChapterSequence', {}),
  '../i18n/AppStrings': strings,
  './RemoteReaderSession': { copyRemoteReadHistoryEntry: entry => entry },
  './ChapterReadStateStore': { AppFilesChapterReadStatePersistenceAdapter: class {} },
})
const view = compile('model/MockLibraryData', {
  './ComicModels': models,
  './LibraryStore': { InMemoryLibraryStore: class {} },
  '../i18n/AppStrings': strings,
})
function comic(ids = ['first', 'middle', 'last'], id = 'book') {
  return { id, title: 'Test book', sourceKind: models.ComicSourceKind.LOCAL_ARCHIVE,
    sourcePath: 'test.cbz', sortTitle: 'test', preferredDirection: models.ReadingDirection.LEFT_TO_RIGHT,
    chapters: ids.map((chapterId, index) => ({ id: chapterId, title: `Chapter ${index + 1}`,
      index, pages: [], pageCount: 10 })), chapterCount: ids.length, pageCount: ids.length * 10,
    createdAt: 1, updatedAt: 1 }
}
function progress(book, chapterId, pageIndex = 9) {
  return { comicId: book.id, chapterId, pageIndex, totalPages: 10,
    progressRatio: (pageIndex + 1) / 10, completed: pageIndex === 9, updatedAt: 1 }
}
test('reading the newest chapter to 100% leaves earlier chapters unread', () => {
  const store = new stores.InMemoryReaderSessionStore(), book = comic()
  store.saveProgress(progress(book, 'last'))
  assert.equal(store.unreadChapterCount(book), 2)
  const projected = view.createLibraryViewModelFromComics([book], store)
  assert.equal(projected.comics[0].unreadChapterCount, 2)
  assert.equal(projected.continueReading.progress, 100)
  assert.equal(projected.continueReading.detail, '第 10 页 · 100% · Chapter 3')
})
test('manual read and unread state immediately changes only the canonical count', () => {
  const store = new stores.InMemoryReaderSessionStore(), book = comic()
  store.saveProgress(progress(book, 'last'))
  store.markChapterReadState(book.id, 'first', true)
  store.markChapterReadState(book.id, 'middle', true)
  assert.equal(store.unreadChapterCount(book), 0)
  const saved = structuredClone(store.getComicProgress(book))
  store.markChapterReadState(book.id, 'first', false)
  assert.equal(store.unreadChapterCount(book), 1)
  assert.equal(view.createLibraryViewModelFromComics([book], store).comics[0].unreadChapterCount, 1)
  assert.deepEqual(store.getComicProgress(book), saved)
})
test('only current distinct chapters count; orphan and other-book states do not', () => {
  const store = new stores.InMemoryReaderSessionStore(), book = comic(['first', 'first', 'last'])
  book.chapterCount = 2
  store.markChapterReadState(book.id, 'removed', true)
  store.markChapterReadState('another-book', 'first', true)
  assert.equal(store.unreadChapterCount(book), 2)
  store.markChapterReadState(book.id, 'first', true)
  assert.equal(store.unreadChapterCount(book), 1)
})
test('unknown, empty or incomplete catalogs and absent stores do not invent counts', () => {
  const store = new stores.InMemoryReaderSessionStore(), empty = comic([]), partial = comic(['one'])
  partial.chapterCount = 20
  assert.equal(store.unreadChapterCount(empty), undefined)
  assert.equal(store.unreadChapterCount(partial), undefined)
  assert.equal(view.createLibraryViewModelFromComics([comic()]).comics[0].unreadChapterCount, undefined)
})
test('large unread counts stay exact and newly added chapters become unread', () => {
  const store = new stores.InMemoryReaderSessionStore(), book = comic(Array.from({ length: 696 }, (_, i) => `ch${i}`))
  assert.equal(store.unreadChapterCount(book), 696)
  store.markChapterReadState(book.id, 'ch695', true)
  assert.equal(store.unreadChapterCount(book), 695)
  book.chapters.push({ id: 'new', title: 'New', index: 696, pages: [], pageCount: 10 })
  book.chapterCount++
  assert.equal(store.unreadChapterCount(book), 696)
})
test('projection is read-only and preserves a local single-chapter continue position', () => {
  const store = new stores.InMemoryReaderSessionStore(), book = comic(['one'])
  store.saveProgress(progress(book, 'one', 2))
  const before = structuredClone({ book, progress: store.listProgress(), chapters: store.listChapterStates() })
  const projected = view.createLibraryViewModelFromComics([book], store)
  assert.equal(projected.comics[0].unreadChapterCount, 1)
  assert.equal(projected.continueReading.detail, '第 3 页 · 30% · Chapter 1')
  assert.equal(projected.continueReading.progress, 30)
  assert.deepEqual({ book, progress: store.listProgress(), chapters: store.listChapterStates() }, before)
})

test('a complete source response with duplicate IDs still exposes its exact logical unread count', () => {
  const store = new stores.InMemoryReaderSessionStore()
  const book = comic(Array.from({ length: 600 }, (_, i) => `chapter${i}`))
  book.chapters.push(...book.chapters.slice(0, 24))
  book.chapterCount = 624
  for (let i = 0; i < 4; i++) store.markChapterReadState(book.id, `chapter${i}`, true)
  const before = structuredClone({ book, states: store.listChapterStates() })
  assert.equal(store.unreadChapterCount(book), 596)
  assert.equal(view.createLibraryViewModelFromComics([book], store).comics[0].unreadChapterCount, 596)
  assert.deepEqual({ book, states: store.listChapterStates() }, before)
})
