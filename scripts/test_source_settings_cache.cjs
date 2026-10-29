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
  const requests = []
  const run = (_registry, _sourceId, json) => {
    requests.push(JSON.parse(json))
    return { response: { ok: true, data: { settings: [] } } }
  }
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
    if (name === './SourceSettingObservationStore') return { appSourceSettingObservationStore: {
      configure() {}, snapshotForSource: () => ({}), loadForSource: async () => ({}),
    } }
    if (name === './SourceRuntimeService') return { runRegisteredSourceRequestById: run,
      runRegisteredSourceRequestByIdAsync: async (...args) => run(...args) }
    return {}
  })
  const store = new exports.SourceSettingsStore(); store.configure({ filesDir: '/app' })
  return { file, original, disk, io, writeAppTextFile, store, exports, requests,
    reads: () => reads, failWrite: value => { failWrite = value } }
}

test('UUID-list settings reject an invalid edit without overwriting the saved source settings', () => {
  const f = fixture(), api = f.exports
  const [groups] = api.normalizeSourceSettingDescriptors({ ok: true, data: { settings: [{
    id: 'blockedGroups_en', kind: 'string', label: 'Groups', default: '',
    validation: { kind: 'uuid_list', message: 'The text contains invalid UUIDs' },
  }] } })
  const uuid = '06a9fecb-b608-4f19-b93c-7caab06b7f44'
  assert.equal(groups.supported, true)
  for (const value of ['', '  ', uuid, ` ${uuid}, ${uuid} `]) {
    assert.equal(api.sourceSettingValidationError(groups, value), undefined)
  }
  for (const value of [uuid.toUpperCase(), `${uuid},`, `,${uuid}`, 'not-a-uuid']) {
    assert.equal(api.sourceSettingValidationError(groups, value), 'The text contains invalid UUIDs')
  }
  const revision = f.store.revisionForSource('A'), before = f.disk.get(f.file)
  assert.throws(() => f.store.saveForSource('A', { blockedGroups_en: `${uuid},` }, [groups]), /source_settings_invalid_value/)
  assert.equal(f.disk.get(f.file), before)
  assert.equal(f.store.revisionForSource('A'), revision)
  f.store.saveForSource('A', { blockedGroups_en: uuid }, [groups])
  assert.equal(f.store.loadForSource('A').blockedGroups_en, uuid)
})

test('the source settings form disables saving when either UUID field is invalid', () => {
  const f = fixture(), api = f.exports
  const input = fs.readFileSync(path.join(root, '../components/SourceSettingsSheetContent.ets'), 'utf8')
    .replace('export struct SourceSettingsSheetContent', 'export class SourceSettingsSheetContent')
  const tree = ts.createSourceFile('settings-form', input, ts.ScriptTarget.Latest, true)
  const owner = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'SourceSettingsSheetContent')
  const methods = ['settingValidationError', 'hasInvalidSettings', 'saveSettings'].map(name =>
    owner.members.find(node => node.name?.text === name).getText(tree)).join('\n')
  const js = ts.transpileModule(`export class Form { ${methods} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exports = {}, events = []
  new Function('exports', 'sourceSettingValidationError', 'appSourceSettingsStore', 't', js)(exports,
    api.sourceSettingValidationError, f.store, key => key)
  const descriptors = api.normalizeSourceSettingDescriptors({ ok: true, data: { settings: ['groups','uploaders'].map(id => ({
    id, kind: 'string', label: id, default: '', validation: { kind: 'uuid_list', message: 'invalid' },
  })) } })
  const form = new exports.Form()
  Object.assign(form, { settingsSourceId: 'A', settingDescriptors: descriptors,
    settingDraft: { groups: 'bad', uploaders: '' }, getUIContext: () => ({ getPromptAction: () => ({ showToast() {} }) }),
    onSaved: value => events.push(value), onClose: () => events.push('closed') })
  const before = f.disk.get(f.file)
  assert.equal(form.settingValidationError(descriptors[0]), 'source_pkg_invalid_uuid_list')
  assert.equal(form.settingValidationError(descriptors[1]), undefined)
  assert.equal(form.hasInvalidSettings(), true)
  form.saveSettings()
  assert.equal(f.disk.get(f.file), before)
  assert.deepEqual(events, [])
  form.settingDraft = { groups: '06a9fecb-b608-4f19-b93c-7caab06b7f44', uploaders: '' }
  assert.equal(form.hasInvalidSettings(), false)
  form.saveSettings()
  assert.equal(f.store.loadForSource('A').groups, form.settingDraft.groups)
  assert.deepEqual(events, [false, 'closed'])
})

test('descriptor requests carry only the current source public snapshot without migrating it, and unreadable differs from empty', async () => {
  const f = fixture(), api = f.exports
  f.disk.set(f.file, JSON.stringify({ schemaVersion: 1, sources: {
    A: { defaultContentRating: 'safe', api_token: 'fixture-only', selected: ['one'] },
    B: { defaultContentRating: 'erotica' },
  } }))
  const before = f.disk.get(f.file)
  assert.equal(api.appSourceSettingsStore.descriptorValuesForSource('A'), undefined)
  api.appSourceSettingsStore.configure({ filesDir: '/app' })
  const entry = { capabilities: ['settings'] }
  const registry = { lookup: () => ({ entry }) }
  const revision = api.appSourceSettingsStore.revisionForSource('A')
  api.fetchSourceSettingDescriptors(registry, 'A')
  await api.loadSourceSettingsDescriptorsAsync(registry, 'A')
  for (const request of f.requests) {
    assert.equal(request.sourceId, 'A')
    assert.deepEqual(request.settings, {})
    assert.deepEqual(request.args.settingValues, { defaultContentRating: 'safe', selected: ['one'] })
    assert.equal(request.hostHints.network, false)
  }
  f.requests[0].args.settingValues.selected.push('outside')
  assert.deepEqual(api.appSourceSettingsStore.loadForSource('A').selected, ['one'])
  assert.equal(api.appSourceSettingsStore.revisionForSource('A'), revision)
  assert.equal(f.disk.get(f.file), before)
  await api.loadSourceSettingsDescriptorsAsync(registry, 'missing')
  assert.deepEqual(f.requests.at(-1).args.settingValues, {})
  f.disk.set(f.file, '{'); api.appSourceSettingsStore.invalidateCachedDocument()
  const result = await api.loadSourceSettingsDescriptorsAsync(registry, 'A')
  assert.equal(result.ready, true)
  assert(!Object.hasOwn(f.requests.at(-1).args, 'settingValues'))
  assert.throws(() => api.appSourceSettingsStore.loadForSource('A'), /source_settings_invalid/)
  assert.equal(f.disk.get(f.file), '{')
})

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
