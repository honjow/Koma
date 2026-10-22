// Executes the production metadata helper and existing persistence transaction; no device or network.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/LibraryPersistence.ets'), 'utf8')
const tree = ts.createSourceFile('persistence.ts', source, ts.ScriptTarget.Latest, true)
const names = ['upsertComicAndPersistLibraryStore', 'refreshSourceComicCoverAndPersistLibraryStore']
const code = names.map(name => tree.statements.find(n => ts.isFunctionDeclaration(n) && n.name?.text === name).getText(tree)).join('\n')
const output = ts.transpileModule(code, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
const exportsForTest = {}
const clone = value => JSON.parse(JSON.stringify(value))
new Function('exports', 'ComicSourceKind', 'serializeLibraryStore', 'hydrateLibraryStoreFromJson', output)(
  exportsForTest, { PRIVATE_LIBRARY: 'private_library' },
  store => JSON.stringify(store.values), (store, payload) => { store.values = JSON.parse(payload) })
const refresh = exportsForTest.refreshSourceComicCoverAndPersistLibraryStore
function fixture() {
  const original = { id: 'owned-work', sourceKind: 'private_library', sourceRuntimeId: 'owned-source', remoteResourceId: 'owned-remote',
    coverUri: 'https://owned.invalid/old', title: 'Owned title', createdAt: 1, updatedAt: 2, lastImportedAt: 3,
    chapters: [{ id: 'owned-chapter', pages: [{ id: 'owned-page', uri: 'file://owned-cache' }], index: 0 }],
    chapterCount: 458, pageCount: 18, categoryIds: ['owned-category'], localMetadata: { custom: 'keep' } }
  const store = { values: { [original.id]: clone(original) }, getComic(id) { return this.values[id] }, addComic(row) { this.values[row.id] = row } }
  let saves = 0
  return { original, store, service: { persist() { saves++ } }, saves: () => saves }
}
test('fresh cover changes only the cover field and persists once, preserving chapter/cache/category/order data', () => {
  const f = fixture()
  assert.equal(refresh(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), true)
  assert.deepEqual(f.store.getComic('owned-work'), { ...f.original, coverUri: 'https://owned.invalid/new' })
  assert.equal(f.saves(), 1)
  assert.equal(refresh(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), false)
  assert.equal(f.saves(), 1)
})
test('missing/wrong identity, local work, empty/invalid cover never writes or removes the existing cover', () => {
  for (const [id, sourceId, mangaId, cover] of [
    ['missing', 'owned-source', 'owned-remote', 'https://owned.invalid/new'],
    ['owned-work', 'other-source', 'owned-remote', 'https://owned.invalid/new'],
    ['owned-work', 'owned-source', 'other-remote', 'https://owned.invalid/new'],
    ['owned-work', 'owned-source', 'owned-remote', ''],
    ['owned-work', 'owned-source', 'owned-remote', undefined],
    ['owned-work', 'owned-source', 'owned-remote', 'file://wrong'],
  ]) {
    const f = fixture()
    assert.equal(refresh(f.store, f.service, id, sourceId, mangaId, cover), false)
    assert.deepEqual(f.store.getComic('owned-work'), f.original)
    assert.equal(f.saves(), 0)
  }
  const f = fixture(); f.store.values['owned-work'].sourceKind = 'local_folder'
  assert.equal(refresh(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), false)
  assert.equal(f.saves(), 0)
})
test('persistence failure rolls back the live owner and rethrows the original error', () => {
  const f = fixture(), failure = new Error('owned failure')
  assert.throws(() => refresh(f.store, { persist() { throw failure } }, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), e => e === failure)
  assert.deepEqual(f.store.getComic('owned-work'), f.original)
})
