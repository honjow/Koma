const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')

function load(relative, dependencies = {}) {
  const file = fs.readFileSync(path.join(root, relative + '.ets'), 'utf8')
  const module = { exports: {} }
  const output = ts.transpileModule(file, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
  new Function('require', 'module', 'exports', output)(key => dependencies[key] ?? {}, module, module.exports)
  return module.exports
}

const wire = load('historySync/HistorySyncModel')
const library = load('model/SourceLibraryComic')
const { PersistentReaderSessionStore } = load('model/ReaderSessionStore', {
  '../historySync/HistorySyncModel': wire,
  './SourceLibraryComic': library,
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn() {} } },
})

const work = { comicId: 'source:work', sourceId: 'source', mangaId: 'work', title: 'Work', chapterId: 'chapter' }
const position = { ...work, pageIndex: 4, totalPages: 10, progressRatio: 0.5, completed: false,
  pageId: 'signed-page-url' }
const leftSnapshot = () => ({
  progress: [{ ...position, updatedAt: 10 }],
  sourceHistory: [{ ...work, mangaUrl: 'private-url', coverUri: 'private-cover' }],
  chapters: [{ comicId: work.comicId, chapterId: work.chapterId, position: { ...position, updatedAt: 10 },
    isRead: false, updatedAt: 10 }],
})
const createAdapter = (initial = { progress: [], sourceHistory: [], chapters: [] }) => {
  let saved = initial
  let reject = false
  return {
    loadSnapshot: () => structuredClone(saved),
    failNext: () => { reject = true },
    saveSnapshot: value => {
      if (reject) { reject = false; throw new Error('disk full') }
      saved = structuredClone(value)
    },
  }
}

const leftAdapter = createAdapter(leftSnapshot())
const left = new PersistentReaderSessionStore(leftAdapter)
const rightAdapter = createAdapter()
const right = new PersistentReaderSessionStore(rightAdapter)
const shelfOnly = leftSnapshot()
shelfOnly.sourceHistory = []
const shelfReader = new PersistentReaderSessionStore(createAdapter(shelfOnly))
shelfReader.setSourceSyncShelf([{ id: work.comicId, sourceRuntimeId: work.sourceId, remoteResourceId: work.mangaId,
  title: work.title, chapters: [{ id: work.chapterId, title: 'Shelf chapter' }] }])
assert.equal(shelfReader.sourceSyncSnapshot()[0].recent.chapterTitle, 'Shelf chapter')
const sent = left.sourceSyncSnapshot()
assert.equal(sent.length, 1)
assert.doesNotMatch(JSON.stringify(sent), /signed-page-url|private-url|private-cover/)
rightAdapter.failNext()
assert.throws(() => right.applySourceSync(sent), /storage/)
assert.deepEqual(right.listProgress(), [])
assert.equal(right.applySourceSync(wire.parseSyncWorks(JSON.stringify(sent))), true)
assert.equal(right.getProgress(work.comicId).pageIndex, 4)
assert.equal(new PersistentReaderSessionStore(rightAdapter).getProgress(work.comicId).pageIndex, 4)
assert.equal(right.applySourceSync(sent), false)

const rightRead = { ...sent[0], recent: undefined, chapters: [{ chapterId: 'chapter', readAt: 20, isRead: true }] }
const leftMoved = { ...sent[0], chapters: [{ chapterId: 'chapter', readAt: 10, isRead: false,
  position: { updatedAt: 30, pageIndex: 6, totalPages: 10 } }] }
const combined = wire.mergeSyncWorks([rightRead], [leftMoved])
assert.deepEqual(combined, wire.mergeSyncWorks([leftMoved], [rightRead]))
assert.equal(combined[0].chapters[0].isRead, true)
assert.equal(combined[0].chapters[0].position.pageIndex, 6)

assert.equal(left.removeHistoryEntries([work.comicId]), true)
const removed = new PersistentReaderSessionStore(leftAdapter).sourceSyncSnapshot()
assert.equal(removed[0].recent.deleted, true)
assert.equal(right.applySourceSync(removed), true)
assert.equal(right.getProgress(work.comicId), undefined)
assert.equal(right.getChapterProgress(work.comicId, work.chapterId).pageIndex, 4)
assert.equal(right.applySourceSync(sent), false, 'An older reader cannot resurrect a deleted history item')
right.saveSourceHistory(work)
right.saveProgress(position)
assert.equal(right.flush(), true)
assert.equal(right.sourceSyncSnapshot()[0].recent.deleted, false, 'Reading again revives the history item')

assert.throws(() => wire.parseSyncWorks(JSON.stringify([sent[0], sent[0]])), /data/)
assert.throws(() => wire.parseSyncWorks(JSON.stringify([{ ...sent[0], chapters: [] }])), /data/)
console.log('History sync legacy snapshots, independent facts, deletion, restoration and persistence rollback passed')
