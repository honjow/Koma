const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets/sourceRuntime')
function fixture() {
  const file = '/app/source-runtime/source-settings.json'
  const original = JSON.stringify({ schemaVersion: 1, sources: { A: { tags: ['one'], enabled: false } } })
  const disk = new Map([[file, original]])
  let reads = 0, failWrite = false
  const io = { accessSync: p => !p.endsWith('.json') || disk.has(p), mkdirSync() {},
    readTextSync: p => { reads++; return disk.get(p) }, unlinkSync: p => disk.delete(p) }
  const writeAppTextFile = (p, value) => { if (failWrite) throw Error('write failed'); disk.set(p, value) }
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(root, 'SourceSettingsStore.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', js)(exports, name => {
    if (name === '@kit.CoreFileKit') return { fileIo: io }
    if (name === '../model/AppFileTextPersistence') return { writeAppTextFile }
    if (name === './SourceSettingObservationStore') return { appSourceSettingObservationStore: { configure() {} } }
    return {}
  })
  const store = new exports.SourceSettingsStore(); store.configure({ filesDir: '/app' })
  return { file, original, disk, io, writeAppTextFile, store, reads: () => reads, failWrite: value => { failWrite = value } }
}

test('settings readers reuse one committed snapshot, cannot mutate it, and failed writes do not publish or advance revision', () => {
  const f = fixture(), revision = f.store.revisionForSource('A')
  f.store.loadForSource('A').tags.push('outside')
  f.store.exportAll().A.tags.push('outside-export')
  f.store.configure({ filesDir: '/app' })
  assert.deepEqual(f.store.loadForSource('A'), { tags: ['one'], enabled: false })
  assert.equal(f.reads(), 1)
  f.failWrite(true)
  assert.throws(() => f.store.saveForSource('A', { enabled: true }), /write failed/)
  assert.equal(f.store.revisionForSource('A'), revision)
  assert.deepEqual(f.store.loadForSource('A'), { tags: ['one'], enabled: false })
  f.failWrite(false); f.store.saveForSource('A', { enabled: true })
  assert.notEqual(f.store.revisionForSource('A'), revision)
  assert.deepEqual(f.store.loadForSource('A'), { enabled: true }); assert.equal(f.reads(), 1)
  f.store.importAll({ B: { enabled: false } })
  assert.deepEqual(f.store.exportAll(), { B: { enabled: false } })
})

test('raw removal rollback invalidates the snapshot; malformed reads stay errors and can recover without an empty success', () => {
  const f = fixture()
  f.store.loadForSource('A'); f.store.removeSource('A')
  const text = fs.readFileSync(path.join(root, 'SourceRuntimeAppRegistry.ets'), 'utf8')
  const tree = ts.createSourceFile('registry', text, ts.ScriptTarget.Latest, true)
  const fn = tree.statements.find(n => ts.isFunctionDeclaration(n) && n.name?.text === 'restoreSourceRemovePreferences')
  const js = ts.transpileModule(fn.getText(tree), { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText
  const rollback = new Function('fs', 'writeAppTextFile', 'appSourceSettingsStore', js + ';return restoreSourceRemovePreferences')
    (f.io, f.writeAppTextFile, f.store)
  rollback([{ path: f.file, exists: true, content: f.original }])
  const readsAfterRollbackVerification = f.reads()
  assert.deepEqual(f.store.loadForSource('A'), { tags: ['one'], enabled: false })
  // The pre-existing raw rollback verifies its file too; the next owner read
  // must reload once rather than reusing the newer removed-source snapshot.
  assert.equal(f.reads(), readsAfterRollbackVerification + 1)
  f.disk.set(f.file, '{'); f.store.invalidateCachedDocument()
  assert.throws(() => f.store.loadForSource('A'), /source_settings_invalid/)
  f.disk.set(f.file, f.original)
  assert.deepEqual(f.store.loadForSource('A'), { tags: ['one'], enabled: false })
})
