const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function load(file, imports = {}) {
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', js)(exports, name => imports[name] ?? {})
  return exports
}
function fixture() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-observations-'))
  const values = load('sourceRuntime/SourceSettingObservations.ets')
  const { BackupRestoreActivity: activity } = load('model/BackupRestoreActivity.ets')
  let fail = false, writes = 0
  const io = { accessSync: fs.existsSync, statSync: p => typeof p === 'number' ? fs.fstatSync(p) : fs.statSync(p), readTextSync: p => fs.readFileSync(p, 'utf8'),
    mkdirSync: p => fs.mkdirSync(p, { recursive: true }), OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
    openSync: (p, mode) => ({ fd: fs.openSync(p, mode === 0 ? 'r' : 'w') }), closeSync: f => fs.closeSync(f.fd),
    fsyncSync: fd => { if (fail) throw Error('disk failed'); fs.fsyncSync(fd) },
    writeSync: (fd, text) => fs.writeSync(fd, text), renameSync: fs.renameSync, unlinkSync: fs.unlinkSync }
  const worker = load('sourceRuntime/SourceSettingObservationFile.ets', {
    '@kit.CoreFileKit': { fileIo: io }, './SourceSettingObservations': values,
  })
  const imports = { './SourceSettingObservations': values,
    '../model/BackupRestoreActivity': { BackupRestoreActivity: activity },
    './SourceSettingObservationFile': worker, '@kit.ArkTS': { taskpool: { execute: async (fn, p, payload) => {
      if (payload !== undefined) writes++
      return fn(p, payload)
    } } } }
  const { SourceSettingObservationStore: Store } = load('sourceRuntime/SourceSettingObservationStore.ets', imports)
  const store = new Store(); store.configure(directory)
  return { directory, store, activity, values, Store, writes: () => writes, fail: value => { fail = value },
    io,
    file: path.join(directory, 'source-runtime/source-setting-observations.json'),
    cleanup: () => fs.rmSync(directory, { recursive: true, force: true }) }
}
const groups = names => ({ known_scanlators_pref: names })

test('real owner unions public candidates per source, keeps cold copies and publishes only committed writes', async () => {
  const f = fixture()
  try {
    const token = f.store.tokenForSource('source.A')
    await Promise.all([
      f.store.observe('source.A', groups([' Alpha ', '乙组']), token, () => true),
      f.store.observe('source.A', groups(['乙组', 'Beta']), token, () => true),
      f.store.observe('source.B', groups(['other']), f.store.tokenForSource('source.B'), () => true),
    ])
    // Fixed ScanlatorBlacklist.kt rememberScanlators retains the raw name;
    // this corrects the earlier test's invented trim-on-storage expectation.
    assert.deepEqual(await f.store.loadForSource('source.A'), groups([' Alpha ', '乙组', 'Beta']))
    const copy = await f.store.loadForSource('source.A'); copy.known_scanlators_pref.push('outside')
    await f.store.observe('source.A', groups([' Alpha ']), token, () => true)
    assert.equal(f.writes(), 3, 'duplicate observations do not rewrite the file')
    f.fail(true)
    await assert.rejects(f.store.observe('source.A', groups(['failed']), token, () => true), /disk failed/)
    assert.deepEqual(f.store.snapshotForSource('source.A'), groups([' Alpha ', '乙组', 'Beta']))
    f.fail(false)
    const cold = new f.Store(); cold.configure(f.directory)
    assert.deepEqual(await cold.loadForSource('source.A'), groups([' Alpha ', '乙组', 'Beta']))
    assert.deepEqual(await cold.loadForSource('source.B'), groups(['other']))
    assert.equal(fs.existsSync(f.file + '.tmp'), false)
  } finally { f.cleanup() }
})

test('uninstall serializes with catalogs, rolls back on registry failure, and rejects old completions after reinstall', async () => {
  const f = fixture()
  try {
    const token = f.store.tokenForSource('source.A')
    await f.store.observe('source.A', groups(['original']), token, () => true)
    await assert.rejects(f.activity.runWrite(() => f.store.withSourceRemoved('source.A', async () => {
      await assert.rejects(Promise.resolve().then(() => f.activity.beginRestore()), /backup_restore_busy/)
      throw Error('registry failed')
    })), /registry failed/)
    assert.deepEqual(await f.store.loadForSource('source.A'), groups(['original']))
    await f.activity.runWrite(() => f.store.withSourceRemoved('source.A', async () => true))
    await f.store.observe('source.A', groups(['late']), token, () => true)
    assert.deepEqual(await f.store.loadForSource('source.A'), {})
    await f.store.observe('source.A', groups(['new']), f.store.tokenForSource('source.A'), () => true)
    assert.deepEqual(await f.store.loadForSource('source.A'), groups(['new']))
    await f.store.observe('source.A', groups(['cancelled']), f.store.tokenForSource('source.A'), () => false)
    assert.deepEqual(await f.store.loadForSource('source.A'), groups(['new']))
  } finally { f.cleanup() }
})

test('backup public metadata restores separately from selections and invalidates queued observations', async () => {
  const f = fixture()
  try {
    const token = f.store.tokenForSource('source.A')
    await f.store.observe('source.A', groups(['old']), token, () => true)
    const backup = await f.store.exportAll()
    f.activity.beginRestore()
    await f.store.importDuringRestore({ 'source.B': groups(['restored']) })
    f.activity.finishRestore()
    await f.store.observe('source.A', groups(['late']), token, () => true)
    assert.deepEqual(await f.store.exportAll(), { 'source.B': groups(['restored']) })
    assert.deepEqual(backup, { 'source.A': groups(['old']) })
    assert.throws(() => f.values.checkedSourceSettingObservations({ access_token: ['never'] }), /invalid/)
    assert.throws(() => f.values.checkedSourceSettingObservations(groups(['<line>\ninvalid'])), /invalid/)
  } finally { f.cleanup() }
})

test('ordinary catalog learns real candidates and the async settings consumer receives only that source', async () => {
  const f = fixture()
  try {
    const entry = { sourceId: 'source.A', enabled: true, wasmBytes: Uint8Array.of(1) }
    const registry = { lookup: () => ({ entry }) }
    const host = load('sourceRuntime/SourceHostFeatures.ets')
    const observationImport = { appSourceSettingObservationStore: f.store }
    const settings = load('sourceRuntime/SourceSettingsStore.ets', {
      '@kit.CoreFileKit': { fileIo: f.io }, './SourceSettingObservationStore': observationImport,
      './SourceRuntimeService': { runRegisteredSourceRequestByIdAsync: async (_registry, _sourceId, json) => {
        const request = JSON.parse(json)
        assert.deepEqual(request.args.settingObservations, groups(['甲组', 'Beta']))
        return { response: { ok: true, data: { settings: [{ id: 'blacklist', name: 'Scanlator', kind: 'multiselect',
          default: [], options: request.args.settingObservations.known_scanlators_pref.map(id => ({ id, label: id })) }] } } }
      } },
    })
    settings.appSourceSettingsStore.configure({ filesDir: f.directory })
    entry.capabilities = ['get_chapters', 'settings']
    const revision = settings.appSourceSettingsStore.revisionForSource(entry.sourceId)
    const resolver = load('model/SourceChapterListResolver.ets', {
      './SourceChapterVisibility': load('model/SourceChapterVisibility.ets'),
      '../sourceRuntime/SourceSettingsStore': settings, '../sourceRuntime/SourceSettingObservationStore': observationImport,
      '../sourceRuntime/SourceRuntimeAppRegistry': { appSourceRuntimeRegistry: registry },
      '../sourceRuntime/SourceHostFeatures': host, './MangaDetailModels': { parseMangaChapterFromSourceItem: value => value },
      '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {}, warn() {} } },
      '../sourceRuntime/SourceWebSessionStore': { sourceHttpIdentityJson: () => '{}' },
      '../sourceRuntime/SourceRuntimeRunner': { diagnoseSourceOperation: (_json, fn) => fn() },
      '@kit.ArkTS': { taskpool: { execute: async (_fn, json) => {
        assert(JSON.parse(json).hostFeatures.includes('source_setting_observations_v1'))
        return JSON.stringify({ ok: true, data: { items: [{ id: 'chapter', title: 'Chapter' }], excludedChapterIds: ['hidden'], settingObservations: groups(['甲组', 'Beta']) } })
      } } },
    })
    const catalog = await resolver.resolveSourceChapterList(entry, 'work')
    assert.equal(catalog.chapters[0].id, 'chapter')
    assert.deepEqual(catalog.excludedChapterIds, ['hidden'])
    const result = await settings.loadSourceSettingsDescriptorsAsync(registry, entry.sourceId)
    assert.equal(result.ready, true)
    assert.deepEqual(result.descriptors[0].options.map(option => option.id), ['甲组', 'Beta'])
    assert.deepEqual(settings.appSourceSettingsStore.loadForSource(entry.sourceId), {})
    assert.equal(settings.appSourceSettingsStore.revisionForSource(entry.sourceId), revision)
    assert.deepEqual(await f.store.loadForSource('source.B'), {})
  } finally { f.cleanup() }
})

test('checkpoint recovery reads existing v1/v2 files and rolls back the added observation file in v3', async () => {
  const f = fixture()
  try {
    const preferences = { getPreferences: async () => ({ getAll: async () => ({}), clear: async () => {}, flush: async () => {} }) }
    class Adapter {
      constructor(dir, file) { this.file = path.join(dir, file) }
      load() { return fs.existsSync(this.file) ? fs.readFileSync(this.file, 'utf8') : undefined }
      save(text) { fs.mkdirSync(path.dirname(this.file), { recursive: true }); fs.writeFileSync(this.file, text) }
    }
    const { BackupRestoreCheckpoint: Checkpoint } = load('model/BackupRestoreCheckpoint.ets', {
      '@kit.CoreFileKit': { fileIo: { ...f.io, readSync: (fd, buffer) => fs.readSync(fd, new Uint8Array(buffer)) } },
      '@kit.ArkTS': { buffer: Buffer }, '@kit.ArkData': { preferences },
      './ApplicationSettingsBackup': { APPLICATION_SETTINGS_BACKUP_STORES: [] },
      './LibraryPersistence': { AppFilesLibraryStorePersistenceAdapter: Adapter },
      './BackupRestoreActivity': { BackupRestoreActivity: f.activity },
    })
    const checkpointFile = path.join(f.directory, 'backup-restore-checkpoint.v1.json')
    fs.mkdirSync(path.dirname(f.file), { recursive: true })
    for (const version of [1, 2, 3]) {
      fs.writeFileSync(f.file, 'original public metadata')
      await Checkpoint.prepare({ filesDir: f.directory })
      const image = JSON.parse(fs.readFileSync(checkpointFile, 'utf8'))
      assert.equal(image.schemaVersion, 3)
      if (version < 3) { image.schemaVersion = version; image.files.pop(); fs.writeFileSync(checkpointFile, JSON.stringify(image)) }
      fs.writeFileSync(f.file, 'new public metadata')
      await Checkpoint.recoverBeforeStartup({ filesDir: f.directory })
      assert.equal(fs.readFileSync(f.file, 'utf8'), version === 3 ? 'original public metadata' : 'new public metadata')
      assert.equal(fs.existsSync(checkpointFile), false)
    }
  } finally { f.cleanup() }
})
