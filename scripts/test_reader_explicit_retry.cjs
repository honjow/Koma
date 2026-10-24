const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function methods(file, owner, names, globals = {}) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.getText(tree) === owner)
  assert.ok(cls)
  const members = names.map(name => {
    const member = cls.members.find(n => n.name?.getText(tree) === name)
    assert.ok(member, name)
    return member.getText(tree)
  })
  const exports = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject { ${members.join('\n')} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, Map, console, ...globals })
  return exports.Subject
}
const Cache = methods('model/RemoteImageCacheStore.ets', 'RemoteImageCacheStore', ['getOrFetch'], {
  cacheKeyFor: (url, _headers, seed) => seed || url,
})
function cacheFixture() {
  const cache = new Cache(), writes = []
  Object.assign(cache, { imageRequests: new Map(), reloadRequests: new Map(),
    get: async () => '/cache/existing.jpg', put: async (_url, _headers, bytes) => {
      writes.push(bytes); return '/cache/replacement.jpg'
    } })
  return { cache, writes }
}
test('force retry bypasses an existing file and publishes only a complete replacement', async () => {
  const { cache, writes } = cacheFixture(); let fetched = 0
  const fetch = async () => { fetched++; return new Uint8Array([1, 2, 3]).buffer }
  assert.equal(await cache.getOrFetch('url', undefined, fetch), '/cache/existing.jpg')
  assert.equal(fetched, 0)
  assert.equal(await cache.getOrFetch('url', undefined, fetch, undefined, true), '/cache/replacement.jpg')
  assert.equal(fetched, 1); assert.equal(writes.length, 1)
  assert.equal(cache.imageRequests.size, 0); assert.equal(cache.reloadRequests.size, 0)
})
test('failed forced fetch keeps the old file and does not poison the next retry', async () => {
  const { cache, writes } = cacheFixture()
  await assert.rejects(cache.getOrFetch('url', undefined, async () => { throw Error('network failure') }, undefined, true), /network failure/)
  assert.equal(writes.length, 0)
  assert.equal(cache.imageRequests.size, 0); assert.equal(cache.reloadRequests.size, 0)
  assert.equal(await cache.getOrFetch('url', undefined, async () => new ArrayBuffer(2), undefined, true), '/cache/replacement.jpg')
})
test('a forced refresh retires an older publisher and all new consumers join the replacement', async () => {
  const { cache, writes } = cacheFixture(); let finishOld, finishNew, freshCalls = 0
  cache.get = async () => undefined
  const old = cache.getOrFetch('url', undefined, () => new Promise(resolve => { finishOld = resolve }))
  await new Promise(setImmediate)
  const fresh = cache.getOrFetch('url', undefined, () => { freshCalls++; return new Promise(resolve => { finishNew = resolve }) }, undefined, true)
  const duplicate = cache.getOrFetch('url', undefined, () => { throw Error('duplicate fetch') }, undefined, true)
  const ordinary = cache.getOrFetch('url', undefined, () => { throw Error('stale join') })
  assert.equal(fresh, duplicate); assert.equal(fresh, ordinary); assert.equal(freshCalls, 0)
  finishOld('old'); await old; await new Promise(setImmediate)
  finishNew('fresh'); await fresh
  assert.deepEqual(writes, ['old', 'fresh']); assert.equal(freshCalls, 1)
})
const Index = methods('pages/Index.ets', 'Index', ['prepareReaderLabCatalog'], {
  ComicSourceKind: { LOCAL_FOLDER: 'folder' }, KomaReaderFailure: { sourceError: () => Error('source failure') },
})
const cancel = { check() {} }
const target = { scope: 'koma-local', work: 'book', unit: 'chapter' }
function shelfFixture(ok = true) {
  const index = new Index(), calls = [], book = { id: 'book', sourceKind: 'source' }
  Object.assign(index, { readerComicForOpen: () => book, hasAvailableOfflineReaderPages: () => false,
    ensureReaderSourceChapterPages: async (_book, _chapter, _failure, force) => { calls.push(force); return ok },
    createReaderSessionConfigForOpen: () => ({ totalPages: 24 }), chapterNeedsReaderSourcePages: () => false })
  return { index, calls }
}
test('ordinary shelf opening keeps cache-first and explicit retry reaches the hydrator with force', async () => {
  const { index, calls } = shelfFixture()
  assert.equal((await index.prepareReaderLabCatalog(target, cancel)).totalPages, 24)
  assert.equal((await index.prepareReaderLabCatalog(target, cancel, true)).totalPages, 24)
  assert.deepEqual(calls, [false, true])
})
test('explicit source-plan failure cannot be reported as success from previously saved pages', async () => {
  const { index } = shelfFixture(false)
  await assert.rejects(index.prepareReaderLabCatalog(target, cancel, true), /source failure/)
})
test('available offline chapters bypass provider refresh even on explicit retry', async () => {
  const { index, calls } = shelfFixture()
  index.hasAvailableOfflineReaderPages = () => true
  assert.equal((await index.prepareReaderLabCatalog(target, cancel, true)).totalPages, 24)
  assert.deepEqual(calls, [])
})
