// Execute the production worker matcher and lazy row updates; no source-shape assertions.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets/model')
const modules = new Map()
function load(name) {
  if (modules.has(name)) return modules.get(name)
  const exports = {}
  const source = fs.readFileSync(path.join(root, name + '.ets'), 'utf8').replace(/^@Concurrent\s*$/gm, '')
  const code = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText
  vm.runInNewContext(code, { exports, ObservedV2: value => value, Trace() {}, require: dependency => {
    if (dependency === '@kit.ArkData') return { preferences: { getPreferences: async () => prefs } }
    if (dependency === '../deviceSync/DeviceSyncSignals') return { signalDeviceSyncChange() {}, signalDeviceSyncSearchRemoved() {} }
    if (dependency === '../deviceSync/DeviceSyncData') return { syncSearchIdentity: value => value }
    return load(path.posix.normalize(path.posix.join(path.posix.dirname(name), dependency)))
  } })
  modules.set(name, exports)
  return exports
}
const plain = value => JSON.parse(JSON.stringify(value))
const { searchLocalLibraryTask } = load('LocalLibrarySearchTask')
const docs = [
  { id: 'new', title: 'Alpha', sortTitle: 'alpha', createdAt: 2, author: 'Alice',
    chapterCount: 1, pageCount: 4, chapterTitles: ['Opening'] },
  { id: 'chapter', title: 'Beta', sortTitle: 'beta', createdAt: 1,
    chapterCount: 1, pageCount: 8, chapterTitles: ['第42话 奇门'] },
  { id: 'old', title: 'Alpha', sortTitle: 'alpha', createdAt: 1,
    chapterCount: 2, pageCount: 6, chapterTitles: ['First', 'Second'] },
]
const find = query => plain(searchLocalLibraryTask(plain(docs), query, '%s chapters / %s pages'))
assert.deepEqual(find('alpha'), [
  { comicId: 'old', subtitle: '2 chapters / 6 pages' },
  { comicId: 'new', subtitle: 'Alice' },
])
assert.deepEqual(find('奇门'), [{ comicId: 'chapter', subtitle: '第42话 奇门' }])
assert.deepEqual(find('alice'), [{ comicId: 'new', subtitle: 'Alice' }])
assert.deepEqual(find('not present'), [])

const books = [
  { ...docs[0], sourceKey: 'source:a', sourceNames: ['漫画160'], tags: ['热血', '校园'], notes: '补番', unreadCount: 1 },
  { ...docs[1], sourceKey: 'source:b', sourceNames: ['另一源'], tags: ['恐怖'], unreadCount: 0 },
  { ...docs[2], sourceKey: 'source:a', sourceNames: ['漫画160'], tags: ['热血', '恐怖'], unreadCount: 2 },
]
const queryBooks = (query, source) => plain(searchLocalLibraryTask(plain(books), query, '%s / %s', source)).map(x => x.comicId)
assert.deepEqual(queryBooks('', { key: 'source:a', name: '卸载后仍保留的来源名' }), ['old', 'new'])
assert.deepEqual(queryBooks('alpha', { key: 'source:b', name: '另一源' }), [])
assert.deepEqual(queryBooks('source:"漫画160" author:Alice'), ['new'])
assert.deepEqual(queryBooks('src:"漫画160" tag:热血 -genre:恐怖'), ['new'])
assert.deepEqual(queryBooks('notes:补番 unread>0'), ['new'])
assert.deepEqual(queryBooks('(title:Alpha || author:nobody) && -tag:恐怖'), ['new'])
assert.deepEqual(queryBooks('tag:恐怖 || title:Alpha author:Alice'), ['old', 'new', 'chapter'])
assert.deepEqual(queryBooks('unread=0'), ['chapter'])
assert.deepEqual(queryBooks('total>=2 read=0'), ['old'])
const { parseLibrarySearchQuery } = load('LibrarySearchQuery')
assert.equal(parseLibrarySearchQuery('one-piece').libraryOnly, false)
assert.equal(parseLibrarySearchQuery('https://example.test').libraryOnly, false)
assert.equal(parseLibrarySearchQuery('source:漫画160').libraryOnly, true)

const { SearchResultRowSource } = load('SearchResultRowSource')
const source = new SearchResultRowSource(), visible = []
source.registerDataChangeListener({
  onDataAdd: index => visible.splice(index, 0, source.getData(index).key),
  onDataDelete: index => visible.splice(index, 1),
  onDataChange: index => { visible[index] = source.getData(index).key },
})
const section = (id, state, items = [], diagnosticCode = '') => ({ id, state, items, diagnosticCode })
const a = section('a', 'running'), absent = section('private', 'unsupported', [], 'not_configured')
const unknown = section('checking-private', 'running', [], 'configuration_loading')
source.update([a, absent, unknown], false)
assert.deepEqual(visible, ['a:status'])
const ready = section('a', 'ready', [{ id: 'one' }, { id: 'two' }])
const empty = section('b', 'empty')
source.update([ready, empty], false)
assert.deepEqual(visible, ['a:header', 'a:one', 'a:two', 'b:status'])
const statusRow = source.getData(3)
const retained = source.getData(1)
source.update([ready, section('b', 'failed')], false)
assert.equal(source.getData(1), retained)
assert.equal(source.getData(3), statusRow)
assert.equal(statusRow.section.state, 'failed')
source.update([ready, empty], false, true)
assert.deepEqual(visible, ['a:header', 'a:one', 'a:two'])
source.update([section('local', 'failed'), section('remote', 'timeout'), empty], false, true)
assert.deepEqual(visible, ['local:status', 'remote:status'])
source.update([empty, ready], true)
assert.deepEqual(visible, ['b:status', 'a:header', 'a:migration'])
source.update([], false)
assert.deepEqual(visible, [])
console.log('PASS: local matching, source identity, field/boolean predicates, stable order and existing result controls')

let persisted = new Map(), failFlush = false
const prefs = {
  has: async key => persisted.has(key),
  get: async (key, fallback) => persisted.get(key) ?? fallback,
  put: async (key, value) => { persisted.set(key, value) },
  flush: async () => { if (failFlush) { failFlush = false; throw Error('fixture save failure') } },
  delete: async key => persisted.delete(key),
}
async function historyScope() {
  const { SearchHistoryStore, SEARCH_HISTORY_QUERIES_KEY, SEARCH_SOURCE_FILTER_KEY } = load('SearchHistoryStore')
  persisted.set(SEARCH_HISTORY_QUERIES_KEY, JSON.stringify([{ query: 'legacy', updatedAt: 1 }]))
  persisted.set(SEARCH_SOURCE_FILTER_KEY, 'private')
  const store = new SearchHistoryStore({ filesDir: '/fixture/library-search' })
  assert.deepEqual(plain(await store.load()), [{ query: 'legacy', updatedAt: 1 }])
  await store.record('', { sourceFilter: 'local', librarySource: { key: 'source:a', name: '漫画160' } })
  await store.record('alpha', { sourceFilter: 'local', librarySource: { key: 'source:a', name: '漫画160' } })
  await store.record('alpha', { sourceFilter: 'local', librarySource: { key: 'source:b', name: '另一源' } })
  const fresh = new SearchHistoryStore({ filesDir: '/fixture/library-search' })
  const entries = plain(await fresh.load())
  assert.equal(entries.length, 4)
  assert.equal(entries.find(e => e.query === '').librarySource.key, 'source:a')
  assert.equal(entries.filter(e => e.query === 'alpha').length, 2)
  assert.equal(await fresh.loadSourceFilter(), 'private')
  const removed = entries.find(e => e.librarySource?.key === 'source:b')
  await fresh.remove(removed.query, removed)
  assert.equal((await fresh.load()).filter(e => e.query === 'alpha').length, 1)
  const beforeFailure = persisted.get(SEARCH_HISTORY_QUERIES_KEY)
  failFlush = true
  await assert.rejects(fresh.record('failed', { sourceFilter: 'local' }))
  assert.equal(persisted.get(SEARCH_HISTORY_QUERIES_KEY), beforeFailure)
  console.log('PASS: legacy history, distinct source scopes, empty scoped query, persisted replay and save rollback')

  // Execute the production dispatcher. Provider stubs record every call, so a
  // local predicate leaking to the network fails independently of the matcher.
  const serviceSource = fs.readFileSync(path.join(root, 'CrossSearchService.ets'), 'utf8')
  const tree = ts.createSourceFile('CrossSearchService', serviceSource, ts.ScriptTarget.Latest, true)
  const owner = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'CrossSearchService')
  const method = owner.members.find(n => n.name?.getText(tree) === 'search').getText(tree)
  const subjectExports = {}
  const code = ts.transpileModule('export class Subject {' + method + '}', { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText
  vm.runInNewContext(code, { exports: subjectExports, parseLibrarySearchQuery,
    isCrossSearchQueryMeaningful: value => load('CrossSearchText').normalizeSearchText(value).length > 0,
    DiagnosticLogger: { begin: () => ({ finish() {}, fail() {} }) },
    AppStrings: { get: key => key }, Promise,
  })
  const subject = new subjectExports.Subject(), calls = []
  subject.cancelPendingSearch = () => {}
  subject.searchLocal = async (query, source) => { calls.push(['library', query, source?.key]); return { section: { id: 'local', resultCount: 0 } } }
  subject.sourceMatchesFilter = kind => kind === 'wasm'
  subject.selectedSourceSummaries = ids => ids.map(id => ({ id }))
  subject.searchWasmSource = async (source, query) => { calls.push(['online', query, source.id]); return { section: { id: source.id, resultCount: 0 } } }
  subject.pagedSearchRuns = []
  await subject.search('tag:热血', 'all')
  await subject.search('', 'all', undefined, undefined, undefined, { key: 'source:a', name: '漫画160' })
  assert.deepEqual(calls, [['library', 'tag:热血', undefined], ['library', '', 'source:a']])
  calls.length = 0
  await subject.search('title:ordinary-migration-name', 'source', undefined, undefined, ['a'])
  assert.deepEqual(calls, [['online', 'title:ordinary-migration-name', 'a']])
  subject.sourceMatchesFilter = kind => kind === 'local'
  subject.withTimeout = () => { throw Error('local results must not use the network deadline') }
  let finishLocal
  subject.searchLocal = () => new Promise(resolve => { finishLocal = resolve })
  const received = []
  const pending = subject.search('imported', 'local', section => received.push(section))
  await Promise.resolve()
  assert.equal(received.length, 0)
  finishLocal({ section: { id: 'local', resultCount: 1, items: [{ title: 'imported' }] } })
  const sections = await pending
  assert.equal(received[0].items[0].title, 'imported')
  assert.equal(sections[0].resultCount, 1)
  console.log('PASS: library predicates never reach providers; migration keeps provider-only routing')
}
historyScope().catch(error => { console.error(error); process.exitCode = 1 })
