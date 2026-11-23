const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function load(file, ports = {}) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8')
  const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
  const exports = {}
  new Function('exports', 'require', code)(exports, name => {
    assert.ok(ports[name], `Unexpected import: ${name}`)
    return ports[name]
  })
  return exports
}

test('shelf projection uses exact source/work identity and preserves source pages', () => {
  const { sourceLibraryKeys, projectSourceLibrary } = load('model/SourceLibraryProjection.ets')
  const comics = [{ sourceRuntimeId: 'a', remoteResourceId: '1' }, { sourceRuntimeId: 'a:b', remoteResourceId: 'c' }, { id: 'local' }]
  const page = Object.freeze([{ sourceId: 'a', id: '1', title: 'Same title' },
    { sourceId: 'b', id: '1', title: 'Same title' }, { sourceId: 'a', id: '2', title: 'Same title' },
    { sourceId: 'a', id: 'b:c', title: 'Another' }].map(Object.freeze))
  const keys = sourceLibraryKeys(comics)
  assert.deepEqual(projectSourceLibrary(page, keys, false).map(x => x.inLibrary), [true, false, false, false])
  assert.deepEqual(projectSourceLibrary(page, keys, true).map(x => x.manga), page.slice(1))
  assert.deepEqual(projectSourceLibrary(page.slice(0, 1), keys, true), [])
  // Filtering a fully collected page does not consume/mutate the next page.
  assert.equal(projectSourceLibrary(page.slice(1), keys, true)[0].manga, page[1])
  assert.equal(page.length, 4)
  assert.equal(projectSourceLibrary(page, sourceLibraryKeys([]), false)[0].inLibrary, false)
})

test('source browse preference serializes writes and preserves committed state on failure', async () => {
  const data = new Map()
  const state = { hideInLibrary: false }
  let fail = false
  const pref = { has: async key => data.has(key), get: async (key, value) => data.has(key) ? data.get(key) : value,
    put: async (key, value) => data.set(key, value), delete: async key => data.delete(key),
    flush: async () => { if (fail) { fail = false; throw new Error('disk full') } } }
  const { SourceBrowsePreferencesStore, SOURCE_BROWSE_HIDE_IN_LIBRARY: key } = load('model/SourceBrowsePreferencesStore.ets', {
    '@kit.ArkData': { preferences: { getPreferences: async () => pref } },
    '../state/SourceBrowseState': { connectSourceBrowseState: () => state },
    './BackupRestoreActivity': { BackupRestoreActivity: { runWrite: task => task() } },
  })
  const store = new SourceBrowsePreferencesStore({ filesDir: '/source-library-test' })
  await store.load()
  assert.equal(state.hideInLibrary, false)
  fail = true
  await assert.rejects(store.saveHideInLibrary(true), /disk full/)
  assert.equal(data.has(key), false)
  assert.equal(state.hideInLibrary, false)
  await Promise.all([store.saveHideInLibrary(true), store.saveHideInLibrary(false), store.saveHideInLibrary(true)])
  assert.equal(data.get(key), true)
  assert.equal(state.hideInLibrary, true)
  fail = true
  await assert.rejects(store.saveHideInLibrary(false), /disk full/)
  assert.equal(data.get(key), true)
  assert.equal(state.hideInLibrary, true)
  state.hideInLibrary = false
  await new SourceBrowsePreferencesStore({ filesDir: '/source-library-test' }).load()
  assert.equal(state.hideInLibrary, true)
})
