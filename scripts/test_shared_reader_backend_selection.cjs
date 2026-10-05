const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

// Compile the real process owner. No preferences or backing file may be opened.
function processState() {
  const exports = {}
  const storage = new Map()
  const source = fs.readFileSync(path.join(__dirname,
    '../entry/src/main/ets/state/KomaReaderBackendSelectionState.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true,
  } }).outputText, {
    exports, ObservedV2: type => type, Trace() {},
    require(name) {
      assert.equal(name, '@kit.ArkUI', 'selection must not depend on persistent storage')
      return { AppStorageV2: { connect(type, key, create) {
        if (!storage.has(key)) storage.set(key, create())
        return storage.get(key)
      } } }
    },
  })
  return exports
}

test('cold process is legacy; debug selection is shared only within that process', () => {
  const owner = processState()
  const selection = owner.connectKomaReaderBackendSelection()
  assert.equal(selection.current(true), 'legacy')
  selection.select(owner.KomaReaderBackend.SHARED, true)
  assert.equal(selection.current(true), 'shared')
  assert.equal(owner.connectKomaReaderBackendSelection(), selection)
  assert.equal(processState().connectKomaReaderBackendSelection().current(true), 'legacy')
})

test('release reads and writes cannot select shared; invalid values fail closed', () => {
  const owner = processState()
  const selection = owner.connectKomaReaderBackendSelection()
  selection.select(owner.KomaReaderBackend.SHARED, true)
  assert.equal(selection.current(false), 'legacy')
  selection.select(owner.KomaReaderBackend.SHARED, false)
  assert.equal(selection.current(true), 'legacy')
  selection.select(owner.KomaReaderBackend.SHARED, true)
  selection.select('invalid', true)
  assert.equal(selection.current(true), 'legacy')
})

test('explicit legacy fallback affects the next selection, not an admitted value', () => {
  const owner = processState()
  const selection = owner.connectKomaReaderBackendSelection()
  selection.select(owner.KomaReaderBackend.SHARED, true)
  const admitted = selection.current(true)
  selection.select(owner.KomaReaderBackend.LEGACY, true)
  assert.equal(selection.current(true), 'legacy')
  assert.equal(admitted, 'shared')
})
