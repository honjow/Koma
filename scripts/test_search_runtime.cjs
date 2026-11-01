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
  vm.runInNewContext(code, { exports, require: name => load(name.replace('./', '')) })
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
const retained = source.getData(1)
source.update([ready, section('b', 'failed')], false)
assert.equal(source.getData(1), retained)
source.update([ready, empty], false, true)
assert.deepEqual(visible, ['a:header', 'a:one', 'a:two'])
source.update([empty, ready], true)
assert.deepEqual(visible, ['b:status', 'a:header', 'a:migration'])
source.update([], false)
assert.deepEqual(visible, [])
console.log('PASS: local title/author/chapter matching, stable order, lazy row deltas, unconfigured and results-only filters')
