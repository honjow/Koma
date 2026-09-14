const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')

function member(file, owner, name) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.getText(tree) === owner)
  assert.ok(cls, owner)
  const value = cls.members.find(item => item.name?.getText(tree) === name)
  assert.ok(value, `${owner}.${name}`)
  return value.getText(tree)
}

function exportedFunction(file, name) {
  const source = fs.readFileSync(path.join(root, file), 'utf8')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const value = tree.statements.find(item => ts.isFunctionDeclaration(item) && item.name?.getText(tree) === name)
  assert.ok(value, name)
  const output = {}
  vm.runInNewContext(ts.transpileModule(`export ${value.getText(tree)}`, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: output })
  return output[name]
}

function key(unit) {
  return {
    scope: 'koma-local', work: 'transient-work', unit,
    copy() { return key(this.unit) },
    equals(other) { return other?.scope === this.scope && other?.work === this.work && other?.unit === this.unit },
  }
}

const cloneReaderSessionConfig = exportedFunction('model/ReaderSessionStore.ets', 'cloneReaderSessionConfig')

test('Koma host catalog copies transient configs and fences cancellation around provider work', async () => {
  const source = fs.readFileSync(path.join(root, 'readerLab/KomaReaderCatalogHost.ets'), 'utf8')
  const output = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: output, require(name) {
    if (name === '../model/ReaderSessionStore') return { cloneReaderSessionConfig }
    if (name === '@reader-kit/core') return {}
    throw new Error(name)
  } })
  const config = {
    comicId: 'transient-work', chapterId: 'chapter-A', chapterIds: ['chapter-A', 'chapter-B'],
    continuationChapterIds: ['chapter-A', 'chapter-B'], chapterTitles: ['A', 'B'], totalPages: 2,
    pageUris: ['https://example/a1', 'https://example/a2'], pageIds: ['a1', 'a2'],
  }
  const checks = []
  const cancellation = { check() { checks.push('check') } }
  const host = new output.KomaReaderCatalogHost(() => config, async target => {
    assert.equal(target.unit, 'chapter-B')
    return { ...config, chapterId: 'chapter-B', totalPages: 1, pageUris: ['https://example/b1'], pageIds: ['b1'] }
  })
  const initial = host.initial('transient-work', 'chapter-A')
  initial.pageUris[0] = 'mutated'
  assert.equal(config.pageUris[0], 'https://example/a1')
  const prepared = await host.prepare(key('chapter-B'), cancellation)
  assert.equal(prepared.chapterId, 'chapter-B')
  assert.deepEqual(Array.from(prepared.pageUris), ['https://example/b1'])
  assert.equal(checks.length, 2)
})

test('adapter consumes a host-prepared transient chapter before touching its disk library', async () => {
  const methods = ['unitId', 'initialKey', 'prepare', 'installConfig'].map(name =>
    member('readerLab/KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter', name))
  const output = {}
  class ReaderUnitKey {
    constructor(scope, work, unit) { Object.assign(this, { scope, work, unit }) }
    copy() { return new ReaderUnitKey(this.scope, this.work, this.unit) }
  }
  class ReaderUnit {
    constructor(value, title, pageCount) { this.key = value.copy(); Object.assign(this, { title, pageCount }) }
    copy() { return new ReaderUnit(this.key, this.title, this.pageCount) }
  }
  vm.runInNewContext(ts.transpileModule(`export class Subject { ${methods.join('\n')} }`, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: output, ReaderUnitKey, ReaderUnit,
    createReaderPageRenderSources: config => config.pageUris.map(imageUri => ({ imageUri })),
    console: { info() {} } })
  const config = { comicId: 'transient-work', chapterId: 'chapter-A', chapterIds: ['chapter-A'],
    totalPages: 1, pageUris: ['https://example/a1'], title: 'Transient', chapterTitle: 'A' }
  const adapter = new output.Subject()
  Object.assign(adapter, {
    closed: false, configs: new Map(), sources: new Map(), preparedUnits: new Map(),
    catalogHost: { initial: () => config, prepare: async () => config },
    library: { getComic() { throw new Error('disk library must not be read') } },
  })
  const initial = adapter.initialKey('transient-work', 'chapter-A')
  assert.equal(initial.unit, 'chapter-A')
  const unit = await adapter.prepare(initial, { check() {} })
  assert.equal(unit.pageCount, 1)
  assert.equal(unit.title, 'Transient · A')
})

test('Index keeps provider resolution and remote headers in Koma while passing only the catalog host to the reader', () => {
  const index = fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8')
  const page = fs.readFileSync(path.join(root, 'readerLab/KomaReaderLabPage.ets'), 'utf8')
  assert.match(index, /prepareReaderLabCatalog[\s\S]*resolveSourceChapterPages\(this\.sourceRegistry/)
  assert.match(index, /prepareReaderLabCatalog[\s\S]*installReaderRemoteHeadersForComic/)
  assert.match(index, /sourceKind === ComicSourceKind\.LOCAL_FOLDER\) return null/)
  assert.match(index, /catalogHost: this\.createReaderLabCatalogHost\(\)/)
  assert.match(page, /new KomaReaderLabAdapter\(context\.filesDir, context\.cacheDir, this\.catalogHost\)/)
  assert.doesNotMatch(page, /SourceRuntimeRegistry|OfflineDownloadStore|LibraryStorePersistence/)
})
