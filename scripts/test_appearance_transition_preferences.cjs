const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs'), path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture() {
  const modules = new Map(), states = new Map(), values = new Map()
  let failFlush = false
  const preference = {
    has: async key => values.has(key), get: async (key, fallback) => values.get(key) ?? fallback,
    put: async (key, value) => { values.set(key, value) }, delete: async key => { values.delete(key) },
    flush: async () => { if (failFlush) { failFlush = false; throw Error('disk full') } },
  }
  function load(file) {
    if (modules.has(file)) return modules.get(file)
    const exports = {}; modules.set(file, exports)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8')
    const js = ts.transpileModule(source, { compilerOptions: {
      target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true,
    } }).outputText
    new Function('require', 'exports', 'ObservedV2', 'Trace', js)(name => {
      if (name === '@kit.ArkUI') return { AppStorageV2: { connect(_type, key, factory) {
        if (!states.has(key)) states.set(key, factory())
        return states.get(key)
      } } }
      if (name === '@kit.ArkData') return { preferences: { getPreferences: async () => preference } }
      if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key } }
      if (name.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
      throw Error('Unexpected import ' + name)
    }, exports, () => {}, () => {})
    return exports
  }
  const state = load('state/AppearanceState').connectAppearanceState()
  const Store = load('model/AppearancePreferencesStore').AppearancePreferencesStore
  return { state, Store, values, context: { filesDir: '/appearance-transition' },
    failNextFlush() { failFlush = true } }
}

test('all three detail modes persist and reload; missing or invalid values use the user-selected cover expansion default', async () => {
  const f = fixture(), store = new f.Store(f.context)
  assert.equal(f.state.detailTransitionMode, 'coverExpand')
  await store.load()
  assert.equal(f.state.detailTransitionMode, 'coverExpand')
  for (const mode of ['system', 'seamless', 'coverExpand']) {
    await store.saveDetailTransitionMode(mode)
    assert.equal(f.values.get('appearance.detailTransitionMode'), mode)
    assert.equal(f.state.detailTransitionMode, mode)
    f.state.detailTransitionMode = 'stale'
    await new f.Store(f.context).load()
    assert.equal(f.state.detailTransitionMode, mode)
  }
  f.values.set('appearance.detailTransitionMode', 'unsupported')
  await store.load()
  assert.equal(f.state.detailTransitionMode, 'coverExpand')
  f.values.delete('appearance.detailTransitionMode')
  await store.load()
  assert.equal(f.state.detailTransitionMode, 'coverExpand')
})

test('a failed detail-mode write restores the saved value and does not publish an uncommitted selection', async () => {
  const f = fixture(), store = new f.Store(f.context)
  await store.saveDetailTransitionMode('system')
  f.failNextFlush()
  await assert.rejects(store.saveDetailTransitionMode('coverExpand'), /disk full/)
  assert.equal(f.values.get('appearance.detailTransitionMode'), 'system')
  assert.equal(f.state.detailTransitionMode, 'system')
  f.values.delete('appearance.detailTransitionMode')
  await store.load()
  f.failNextFlush()
  await assert.rejects(store.saveDetailTransitionMode('coverExpand'), /disk full/)
  assert.equal(f.values.has('appearance.detailTransitionMode'), false)
  assert.equal(f.state.detailTransitionMode, 'coverExpand')
  await store.saveDetailTransitionMode('coverExpand')
  assert.equal(f.state.detailTransitionMode, 'coverExpand')
})
