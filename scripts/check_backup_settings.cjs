const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const policy = require('./backup_settings_policy.json')

const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
const read = name => fs.readFileSync(path.join(root, name), 'utf8')
const applicationSettingsModule = 'model/ApplicationSettingsBackup.ets'

// Declare only the platform boundary needed by the checker. Method symbols
// distinguish Preferences from Map and other stores with similarly named APIs.
const preferenceMethods = ['get', 'getSync', 'has', 'hasSync', 'put', 'putSync', 'delete', 'deleteSync']
const shim = path.join(root, '__backup_gate_preferences.d.ts')
const shimText = `
declare module '@kit.ArkData' {
  export namespace preferences {
    type ValueType = string | number | boolean | string[];
    interface Preferences {
      ${preferenceMethods.map(method => `${method}(key: string, value?: ValueType): unknown;`).join('\n')}
      getAll(): Promise<Record<string, ValueType>>;
      flush(): Promise<void>;
      clear(): Promise<void>;
    }
    function getPreferences(context: unknown, name: string | { name: string }): Promise<Preferences>;
    function getPreferencesSync(context: unknown, options: { name: string }): Preferences;
  }
}
declare module '@ohos.data.preferences' {
  import { preferences } from '@kit.ArkData';
  export default preferences;
}
`

function sourceFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name)
    if (entry.isDirectory()) return sourceFiles(file)
    return entry.name.endsWith('.ets') ? [file] : []
  })
}

function preferenceInventory() {
  const options = { target: ts.ScriptTarget.ES2022, allowNonTsExtensions: true, noEmit: true }
  const host = ts.createCompilerHost(options)
  const originalGet = host.getSourceFile.bind(host)
  host.getSourceFile = (name, ...args) => name === shim
    ? ts.createSourceFile(name, shimText, options.target, true) : originalGet(name, ...args)
  host.resolveModuleNames = (names, importer) => names.map(name => {
    if (!name.startsWith('.')) return undefined
    const file = path.resolve(path.dirname(importer), name + '.ets')
    return fs.existsSync(file) ? { resolvedFileName: file, extension: ts.Extension.Ts } : undefined
  })

  const program = ts.createProgram([shim, ...sourceFiles(root)], options, host)
  const checker = program.getTypeChecker()
  const calls = []
  const argumentsByDeclaration = new Map()
  for (const source of program.getSourceFiles().filter(file => file.fileName.endsWith('.ets'))) {
    const visit = node => {
      if (ts.isCallExpression(node)) {
        const declaration = checker.getResolvedSignature(node)?.declaration
        if (declaration) {
          const site = { node, declaration, source }
          calls.push(site)
          if (!argumentsByDeclaration.has(declaration)) argumentsByDeclaration.set(declaration, [])
          argumentsByDeclaration.get(declaration).push(site)
        }
      }
      ts.forEachChild(node, visit)
    }
    visit(source)
  }

  function resolveKeys(node, stack = new Set()) {
    if (!node || stack.has(node)) return { keys: [], unknown: true }
    if (ts.isStringLiteralLike(node)) return { keys: [node.text], unknown: false }
    const next = new Set(stack).add(node)
    if (ts.isElementAccessExpression(node)) return resolveKeys(node.expression, next)
    if (ts.isArrayLiteralExpression(node)) {
      const results = node.elements.map(item => resolveKeys(item, next))
      return { keys: results.flatMap(result => result.keys), unknown: results.some(result => result.unknown) }
    }
    if (!ts.isIdentifier(node)) return { keys: [], unknown: true }
    let symbol = checker.getSymbolAtLocation(node)
    if (symbol?.flags & ts.SymbolFlags.Alias) symbol = checker.getAliasedSymbol(symbol)
    const declaration = symbol?.valueDeclaration
    if (declaration && ts.isVariableDeclaration(declaration)) return resolveKeys(declaration.initializer, next)
    if (declaration && ts.isParameter(declaration)) {
      const owner = declaration.parent
      const index = owner.parameters.indexOf(declaration)
      const argumentsFound = (argumentsByDeclaration.get(owner) ?? [])
        .map(site => resolveKeys(site.node.arguments[index], next))
      return { keys: argumentsFound.flatMap(result => result.keys),
        unknown: argumentsFound.length === 0 || argumentsFound.some(result => result.unknown) }
    }
    return { keys: [], unknown: true }
  }

  const inventory = new Map()
  const dynamic = new Map()
  for (const { node, declaration, source } of calls) {
    if (declaration.getSourceFile().fileName !== shim) continue
    const method = declaration.name?.getText()
    if (!preferenceMethods.includes(method)) continue
    const owner = path.relative(root, source.fileName).split(path.sep).join('/')
    const result = resolveKeys(node.arguments[0])
    if (!inventory.has(owner)) inventory.set(owner, new Set())
    for (const key of result.keys) inventory.get(owner).add(key)
    if (!result.unknown) continue
    let enclosing = node.parent
    while (enclosing && !ts.isMethodDeclaration(enclosing) && !ts.isFunctionDeclaration(enclosing)) {
      enclosing = enclosing.parent
    }
    const description = `${enclosing?.name?.getText(source) ?? '<file>'}: ${node.arguments[0]?.getText(source)}`
    if (!dynamic.has(owner)) dynamic.set(owner, new Set())
    dynamic.get(owner).add(description)
  }
  return { inventory, dynamic }
}

function evaluate(source, ports) {
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true },
  }).outputText
  const exports = {}
  new Function('require', 'exports', 'ObservedV2', 'Trace', code)(
    name => ports[name] ?? {}, exports, () => {}, () => {})
  return exports
}

function checkInventory(portable) {
  const { inventory, dynamic } = preferenceInventory()
  const expected = new Map()
  const classify = (owner, keys, classification) => {
    if (!expected.has(owner)) expected.set(owner, new Map())
    for (const key of keys) {
      assert(!expected.get(owner).has(key), `${owner}: ${key} is classified twice`)
      expected.get(owner).set(key, classification)
    }
  }
  const coveredStores = new Set()
  for (const [owner, stores] of Object.entries(policy.applicationSettings)) {
    for (const store of stores) {
      assert(portable[store] && !coveredStores.has(store), `Invalid portable Preferences store: ${store}`)
      coveredStores.add(store)
      classify(owner, portable[store], 'applicationSettings')
    }
  }
  assert.deepEqual([...coveredStores].sort(), Object.keys(portable).sort(), 'Classify the owner of every portable store')
  for (const classification of ['separateBackupFields', 'deviceOnly', 'credentials', 'pending']) {
    for (const [owner, keys] of Object.entries(policy[classification])) classify(owner, keys, classification)
  }
  const problems = []
  for (const [owner, keys] of inventory) {
    for (const key of keys) {
      if (!expected.get(owner)?.has(key)) problems.push(`Unclassified Preferences key: ${owner} → ${key}`)
    }
  }
  for (const [owner, keys] of expected) {
    for (const key of keys.keys()) {
      if (!inventory.get(owner)?.has(key)) problems.push(`Stale classification: ${owner} → ${key}`)
    }
  }
  for (const [owner, sites] of dynamic) {
    for (const site of sites) {
      if (!policy.dynamic[owner]?.includes(site)) problems.push(`Unresolved Preferences key: ${owner} → ${site}`)
    }
  }
  for (const [owner, sites] of Object.entries(policy.dynamic)) {
    for (const site of sites) {
      if (!dynamic.get(owner)?.has(site)) problems.push(`Stale dynamic-key exception: ${owner} → ${site}`)
    }
  }
  assert.equal(problems.length, 0, problems.join('\n'))
  return [...inventory.values()].reduce((total, keys) => total + keys.size, 0)
}

async function verifyRoundTrip() {
  const stores = new Map()
  let download = { foregroundConcurrencyLimit: 2, wifiOnly: false, pause: true }
  let restoring = false
  let mutations = 0
  const ports = {
    '@kit.ArkData': { preferences: { getPreferences: async (_context, name) => {
      if (!stores.has(name)) stores.set(name, {})
      const values = stores.get(name)
      return {
        getAll: async () => values,
        put: async (key, value) => { mutations += 1; values[key] = value },
        delete: async key => { mutations += 1; delete values[key] },
        flush: async () => {},
      }
    } } },
    './BackupRestoreActivity': { BackupRestoreActivity: { isRestoring: () => restoring } },
    './KomaContentStorage': {
      ensureKomaContentStorageBase: async context => context.filesDir,
      komaContentStorageBase: context => context.filesDir,
      komaRuntimeStorageKey: context => context.filesDir,
    },
    './OfflineDownloadQueueStore': { OfflineDownloadQueueStore: class {
      loadPreferences() { return { ...download } }
      migratePublicQueue() {}
      savePreferencesForBackupRestore(value) { mutations += 1; download = value }
    } },
  }
  const packageMetadata = evaluate(read('sourceRuntime/SourcePackageMetadata.ets'), {
    '@kit.ArkTS': { url: { URL: { parseURL: value => new URL(value) } } },
  })
  ports['../sourceRuntime/SourceIndexMetadata'] = evaluate(read('sourceRuntime/SourceIndexMetadata.ets'), {
    './SourcePackageMetadata': packageMetadata,
    './SourceLocalizedNames': evaluate(read('sourceRuntime/SourceLocalizedNames.ets'), {}),
  })
  const backup = evaluate(read(applicationSettingsModule) + '\nexport { PORTABLE_FIELDS }', ports)
  const count = checkInventory(backup.PORTABLE_FIELDS)
  const valuesForStore = {}
  const structuredValues = {
    'migration.selectedSources': JSON.stringify(['source-b', 'source-a']),
    'migration.matchOptions': JSON.stringify({ deepSearch: true, prioritizeChapters: false }),
    'source_index.repositories.v1': JSON.stringify([
      { url: 'https://disabled.example.test', lastUsedAt: 17, disabled: true, customName: 'Disabled' },
      { url: 'https://sources.example.test/index.json', lastUsedAt: 0 },
    ]),
    'source_index.url': 'https://sources.example.test/index.json',
    'search.source.filter': 'wasm', 'search.results.only': 'true',
  }
  for (const [store, keys] of Object.entries(backup.PORTABLE_FIELDS)) {
    const values = Object.fromEntries(keys.map((key, index) => [key, structuredValues[key] ?? [false, 7, 'fixture'][index % 3]]))
    valuesForStore[store] = values
    stores.set(store, { ...values, 'test.credential': 'secret', 'test.deviceOnly': 'device' })
  }
  // Real device-scoped keys sharing a portable store must not leak either.
  Object.assign(stores.get('koma_backup_automatic_v1'), {
    'backup.automatic.directoryUri': 'file://test', 'backup.automatic.directoryOwnedModes': 3,
    'backup.automatic.lastRunAt': 123,
  })
  const exported = JSON.parse(JSON.stringify(await backup.exportApplicationSettings({})))
  assert.deepEqual(Object.fromEntries(exported.preferences.map(group => [group.name, group.values])), valuesForStore)
  assert.deepEqual(exported.downloadPreferences, { foregroundConcurrencyLimit: 2, wifiOnly: false })
  assert.equal(mutations, 0, 'Export must not change local settings')
  for (const store of Object.keys(valuesForStore)) stores.set(store, { 'test.deviceOnly': 'destination' })
  download = { foregroundConcurrencyLimit: 9, wifiOnly: true, pause: false }
  await assert.rejects(backup.importApplicationSettings({}, exported), /backup_restore_not_active/)
  assert.equal(mutations, 0)
  restoring = true
  for (const invalid of [
    { ...exported, schemaVersion: 999 },
    { ...exported, preferences: [...exported.preferences, exported.preferences[0]] },
    { ...exported, preferences: [{ name: 'koma_backup_automatic_v1', values: { 'backup.automatic.directoryUri': 'file://test' } }] },
    { ...exported, preferences: [{ name: 'koma_app_preferences_v1', values: { 'app.language': [] } }] },
  ]) {
    await assert.rejects(backup.importApplicationSettings({}, invalid), /backup_application_settings_invalid/)
    assert.equal(mutations, 0, 'Invalid documents must fail before the first write')
  }
  await backup.importApplicationSettings({}, exported)
  for (const [store, values] of Object.entries(valuesForStore)) {
    assert.deepEqual(stores.get(store), { ...values, 'test.deviceOnly': 'destination' })
  }
  assert.deepEqual(download, { foregroundConcurrencyLimit: 2, wifiOnly: false, pause: false })
  const before = mutations
  await backup.importApplicationSettings({}, undefined)
  await backup.importApplicationSettings({}, { schemaVersion: 1, preferences: [] })
  assert.equal(mutations, before, 'Legacy backups without the settings group preserve destination settings')
  const languageStore = stores.get('koma_app_preferences_v1')
  const languageBefore = languageStore['app.language']
  await backup.importApplicationSettings({}, { schemaVersion: 1,
    preferences: [{ name: 'koma_app_preferences_v1', values: {} }] })
  assert.equal(languageStore['app.language'], languageBefore,
    'A legacy group with an omitted field must not delete the destination setting')
  delete languageStore['app.language']
  const unset = await backup.exportApplicationSettings({})
  assert.deepEqual(unset.preferences.find(group => group.name === 'koma_app_preferences_v1').clearedKeys, ['app.language'])
  languageStore['app.language'] = 'zh-CN'
  await backup.importApplicationSettings({}, unset)
  assert.equal(Object.hasOwn(languageStore, 'app.language'), false,
    'An explicit v2 cleared key restores an intentionally unset preference')
  for (const clearedKeys of [['app.language', 'app.language'], ['test.credential']]) {
    const countBefore = mutations
    await assert.rejects(backup.importApplicationSettings({}, { schemaVersion: 2,
      preferences: [{ name: 'koma_app_preferences_v1', values: {}, clearedKeys }] }), /backup_application_settings_invalid/)
    assert.equal(mutations, countBefore, 'Invalid clear lists must fail before writes')
  }
  languageStore['app.language'] = languageBefore
  const sourceStore = stores.get('koma_source_package_manager_v1')
  const sourceValues = { ...sourceStore }
  delete sourceStore['source_index.repositories.v1']
  const legacyExport = await backup.exportApplicationSettings({})
  const legacySources = legacyExport.preferences.find(group => group.name === 'koma_source_package_manager_v1')
  assert.deepEqual(JSON.parse(legacySources.values['source_index.repositories.v1']),
    [{ url: structuredValues['source_index.url'], lastUsedAt: 0 }])
  assert(!Object.hasOwn(sourceStore, 'source_index.repositories.v1'), 'Exporting a legacy-only subscription is read-only')
  sourceStore['source_index.url'] = 'https://destination-only.example.test/'
  await backup.importApplicationSettings({}, exported)
  assert.deepEqual(sourceStore, sourceValues, 'The destination legacy pointer must not revive an extra subscription')
  const sourceGroup = exported.preferences.find(group => group.name === 'koma_source_package_manager_v1')
  for (const invalid of [
    { name: sourceGroup.name, values: { 'source_index.repositories.v1': '[]' }, clearedKeys: [] },
    { name: sourceGroup.name, values: { 'source_index.repositories.v1': '[]', 'source_index.url': 'https://extra.example.test/' }, clearedKeys: [] },
    { name: 'koma_manga_migration_v1', values: { 'migration.selectedSources': '[1]' }, clearedKeys: [] },
    { name: 'koma_search_history_v1', values: { 'search.results.only': true }, clearedKeys: [] },
  ]) {
    const countBefore = mutations
    await assert.rejects(backup.importApplicationSettings({}, { schemaVersion: 2, preferences: [invalid] }), /backup_application_settings_invalid/)
    assert.equal(mutations, countBefore, 'Malformed portable choices fail before the first live write')
  }
  await backup.importApplicationSettings({}, { schemaVersion: 2, preferences: [{ name: sourceGroup.name,
    values: {}, clearedKeys: ['source_index.repositories.v1', 'source_index.url'] }] })
  assert.deepEqual(sourceStore, { 'test.deviceOnly': 'destination' })
  Object.assign(sourceStore, sourceValues)
  await verifyCheckpoint(ports, backup, stores)
  await verifyBackupDocument(ports, backup, stores, value => { restoring = value })
  console.log(`Backup settings gate passed (${count} Preferences owner/key pairs; application settings export/restore verified).`)
  for (const [owner, keys] of Object.entries(policy.pending)) {
    console.log(`Existing backup gap: ${owner} → ${keys.join(', ')}`)
  }
}

async function verifyCheckpoint(ports, applicationSettings, stores) {
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'koma-backup-checkpoint-'))
  const checkpointPath = path.join(directory, 'backup-restore-checkpoint.v1.json')
  const context = { filesDir: directory }
  class FilesAdapter {
    constructor(root, relative) { this.path = path.join(root, relative) }
    load() { return fs.existsSync(this.path) ? fs.readFileSync(this.path, 'utf8') : undefined }
    save(value) { fs.mkdirSync(path.dirname(this.path), { recursive: true }); fs.writeFileSync(this.path, value) }
  }
  const activity = evaluate(read('model/BackupRestoreActivity.ets'), {})
  const checkpoint = evaluate(read('model/BackupRestoreCheckpoint.ets'), {
    ...ports,
    '@kit.ArkTS': { buffer: Buffer },
    '@kit.CoreFileKit': { fileIo: {
      accessSync: fs.existsSync, OpenMode: { READ_ONLY: 'r' },
      openSync: file => ({ fd: fs.openSync(file, 'r') }), statSync: fd => fs.fstatSync(fd),
      readSync: (fd, target) => fs.readSync(fd, new Uint8Array(target)), closeSync: file => fs.closeSync(file.fd),
      mkdirSync: folder => fs.mkdirSync(folder, { recursive: true }), unlinkSync: fs.unlinkSync,
    } },
    './BackupRestoreActivity': activity,
    './ApplicationSettingsBackup': applicationSettings,
    './OfflineDownloadQueueStore': { PUBLIC_CONTENT_QUEUE_PRIVATE_PATH: 'download-queue/queue.v1.json' },
    './LibraryPersistence': { AppFilesLibraryStorePersistenceAdapter: FilesAdapter },
  }).BackupRestoreCheckpoint
  // Add the platform clear operation used by the real checkpoint rollback.
  const getPreferences = ports['@kit.ArkData'].preferences.getPreferences
  const original = new Map([...stores].map(([name, values]) => [name, { ...values }]))
  ports['@kit.ArkData'].preferences.getPreferences = async (ctx, name) => {
    const store = await getPreferences(ctx, name)
    if (name === 'koma_search_history_v1') {
      const put = store.put
      store.put = async (key, value) => {
        if (failOnce && key === 'search.source.filter') { failOnce = false; throw new Error('fixture_disk_write_failed') }
        return put(key, value)
      }
    }
    store.clear = async () => { for (const key of Object.keys(stores.get(name))) delete stores.get(name)[key] }
    return store
  }
  let failOnce = false
  try {
    const privateQueue = path.join(directory, 'download-queue/queue.v1.json')
    fs.mkdirSync(path.dirname(privateQueue), { recursive: true })
    fs.writeFileSync(privateQueue, 'original queue')
    activity.BackupRestoreActivity.beginRestore()
    const pending = await checkpoint.prepare(context)
    fs.writeFileSync(privateQueue, 'restored queue')
    failOnce = true
    await assert.rejects(applicationSettings.importApplicationSettings(context, { schemaVersion: 2, preferences: [
      { name: 'koma_manga_migration_v1', values: { 'migration.selectedSources': '["changed"]' }, clearedKeys: ['migration.matchOptions'] },
      { name: 'koma_search_history_v1', values: { 'search.source.filter': 'local' }, clearedKeys: ['search.results.only'] },
    ] }), /fixture_disk_write_failed/)
    // Migration was already changed when the search write failed. Execute the
    // production checkpoint rollback and compare original values and presence.
    await pending.rollback()
    pending.completeRollback()
    activity.BackupRestoreActivity.finishRestore()
    assert.equal(fs.readFileSync(privateQueue, 'utf8'), 'original queue')
    for (const [name, values] of original) assert.deepEqual(stores.get(name), values)
    assert(!fs.existsSync(checkpointPath))

    // Exact domains written by released checkpoint versions, independent of
    // today's portable list. Recovery must leave the two new stores untouched.
    const first = ['koma_remote_servers_v1', 'koma_source_package_manager_v1', 'koma_tracker_preferences_v1', 'koma_reader_preferences_v1']
    const base = ['koma_app_preferences_v1', 'koma_appearance_preferences_v1', 'koma_library_filter_preferences',
      'koma_library_update_preferences_v1', 'koma_reader_remote_image_cache_v1', 'koma_backup_automatic_v1', 'koma_backup_content_v1']
    const files = ['library-store.v1.json', 'reader-sessions.v1.json', 'source-runtime/source-settings.json',
      'source-runtime/source-filter-preferences.json', 'downloads/queue.v1.json', 'source-runtime/source-runtime-registry.json']
    const domains = [[], ['koma_library_automation_v1'], ['koma_chapter_list_preferences_v1', 'koma_library_automation_v1'],
      ['koma_source_catalog_filters_v1', 'koma_chapter_list_preferences_v1', 'koma_library_automation_v1']]
    const v4Stores = first.concat(domains[3], base)
    const v5Stores = v4Stores.concat(applicationSettings.APPLICATION_SETTINGS_BACKUP_STORES.filter(name => !v4Stores.includes(name)))
    const versions = [[1, first], [2, first.concat(base)], ...domains.map(extra => [3, first.concat(extra, base)]),
      [4, v4Stores], [5, v5Stores]]
    for (const [version, names] of versions) {
      const recoveryFiles = files.concat(version >= 3 ? ['source-runtime/source-setting-observations.json'] : [],
        version >= 4 ? ['image-rules.v1.json'] : [])
      fs.writeFileSync(checkpointPath, JSON.stringify({ schemaVersion: version, phase: 'prepared',
        files: recoveryFiles.map(relative => ({ path: relative, exists: false, content: '' })),
        preferences: names.map(name => ({ name, values: { 'historical.fixture': version } })),
      }))
      await checkpoint.recoverBeforeStartup(context)
      assert.equal(fs.readFileSync(privateQueue, 'utf8'), 'original queue')
      for (const name of names) assert.deepEqual(stores.get(name), { 'historical.fixture': version })
      for (const name of ['koma_manga_migration_v1', 'koma_search_history_v1']) {
        if (!names.includes(name)) assert.deepEqual(stores.get(name), original.get(name))
      }
    }
  } finally {
    ports['@kit.ArkData'].preferences.getPreferences = getPreferences
    stores.clear()
    for (const [name, values] of original) stores.set(name, values)
    fs.rmSync(directory, { recursive: true, force: true })
  }
}

async function verifyBackupDocument(ports, applicationSettings, stores, setRestoring) {
  const readerKeys = policy.separateBackupFields['model/ReaderPreferencesStore.ets']
  const readerSettings = Object.fromEntries(readerKeys.filter(key => !key.endsWith('.v1')).map(key =>
    [key.slice('reader.'.length), 'saved:' + key]))
  let restoredReader
  let restoredBanners
  let committed = false
  let sourceConstructionFailure = false
  let restoreActive = false
  const content = { includeSettings: true, includeDownloadQueue: false, includeTrackerMappings: true }
  const tracker = { autoSyncEnabled: false, updateStrategy: 'manual', comicMappings: [{ comicId: 'comic' }],
    accounts: [{ accessToken: 'fixture-token' }] }
  const sourceIndexUrl = 'https://sources.example.test/index.json'
  const serverConfig = {
    endpointIdentities: 'endpoint-ids', komgaServer: 'komga', kavitaServer: 'kavita',
    webDavServer: 'webdav', opdsServer: 'opds',
    komgaCredential: 'fixture-token', webDavCredential: 'fixture-password',
  }
  const syncFacts = evaluate(read('deviceSync/DeviceSyncFacts.ets'), {})
  const libraryPersistence = evaluate(read('model/LibraryPersistence.ets'), {
    './ComicModels': evaluate(read('model/ComicModels.ets'), {}),
    '../deviceSync/DeviceSyncFacts': syncFacts,
    '../deviceSync/DeviceSyncData': evaluate(read('deviceSync/DeviceSyncData.ets'), { './DeviceSyncFacts': syncFacts }),
  })
  const { BackupService } = evaluate(read('model/BackupService.ets'), {
    ...ports,
    './ApplicationSettingsBackup': { ...applicationSettings, reloadApplicationSettingsRuntime: async () => {} },
    './BackupRestoreActivity': { BackupRestoreActivity: {
      runWrite: action => action(), beginRestore: () => { restoreActive = true; setRestoring(true) },
      finishRestore: () => { restoreActive = false; setRestoring(false) },
    } },
    '../deviceSync/DeviceSyncSignals': evaluate(read('deviceSync/DeviceSyncSignals.ets'), {}),
    './BackupRestoreCheckpoint': { BackupRestoreCheckpoint: {
      prepare: async () => ({ commit: () => { committed = true } }),
    } },
    './AppFileTextPersistence': { writeAppTextFile() {} },
    './AutomationStateEpoch': { beginAutomationRestore() {}, finishAutomationRestore() {}, resetGeneratedAutomationWork() {} },
    '@kit.CoreFileKit': { fileIo: { accessSync: () => false } },
    './LibraryPersistence': libraryPersistence,
    './ReaderSessionStore': {
      READER_PROGRESS_PERSISTENCE_FILE_NAME: 'reader.json', appReaderSessionStore: () => ({ flush: () => true, reload() {} }),
      normalizeReaderSessionBackupPayload: value => value,
    },
    './ComicPersonalization': { exportComicCovers: async () => [],
      prepareRestoredComicCovers: async (_context, libraryStore) => ({ libraryStore }) },
    './LocalLibraryMetadataService': {
      exportLocalLibraryMetadataBackupEntries: () => [], restoreLocalLibraryMetadataBackupEntries: value => value,
    },
    './ReaderPreferencesStore': { DEFAULT_READER_PREFERENCES: {}, ReaderPreferencesStore: class {
      async load() { return readerSettings }
      async exportBannerOverrides() { return { comic: 'banner-off' } }
      async saveForBackupRestore(value) { restoredReader = value }
      async restoreBannerOverrides(value) { restoredBanners = value }
    } },
    './RemoteServerStore': { REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY: 'server.endpoint-identities',
      parseRemoteServerEndpointIdentities: () => [], rememberRemoteServerEndpointIdentity() {},
      RemoteServerStore: class { async exportConfiguration() { return serverConfig } } },
    './TrackerModels': {
      TRACKER_PREFERENCES_STORE_NAME: 'koma_tracker_preferences_v1',
      TRACKER_AUTO_SYNC_ENABLED_KEY: 'tracker.autoSyncEnabled', TRACKER_UPDATE_STRATEGY_KEY: 'tracker.updateStrategy',
      TRACKER_COMIC_MAPPINGS_KEY: 'tracker.comicMappings',
      TrackerPreferencesStore: class { async load() { return tracker } },
      normalizeTrackerUpdateStrategy: value => value, normalizeComicTrackerMappings: value => value,
    },
    '../sourceRuntime/SourceIndexService': { SourceIndexService: class {
      constructor() { if (sourceConstructionFailure) { sourceConstructionFailure = false; throw new Error('fixture_cache_directory_failed') } }
      async loadSavedUrl() { return sourceIndexUrl }
      invalidateForBackupRestore() {}
      async reloadAfterBackupRestore() { assert(restoreActive, 'Rebuild subscription guards before releasing restore admission') }
    } },
    '../viewmodel/SourcePackageManagerCache': { appSourcePackageManagerCache: { invalidate() {} } },
    '../sourceRuntime/SourceRuntimeAppRegistry': { exportInstalledSourcePackages: () => [],
      prepareSourcePackagesFromBackup: async () => ({ ok: true, plan: { commit: async () => ({ ok: true }), discard() {} } }) },
    '../sourceRuntime/SourceSettingsStore': { configureSourceSettingsStore() {},
      appSourceSettingsStore: { exportAll: () => ({}), importAll() {} } },
    '../sourceRuntime/SourceFilterPreferencesStore': {
      configureSourceFilterPreferencesStore() {}, appSourceFilterPreferencesStore: { exportAll: () => ({}), importAll() {} },
    },
    '../sourceRuntime/SourceSettingObservationStore': { appSourceSettingObservationStore: {
      exportAll: async () => ({}), invalidateCachedDocument() {}, async importDuringRestore() {},
    } },
    '../sourceRuntime/SourceSettingObservations': { checkedSourceSettingObservationSources: value => value },
    './ImageRuleStore': { ImageRuleStore: {
      forContext: () => ({ exportSnapshot: async () => ({ subscriptions: [] }), async restore() {} }),
    } },
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {} } },
  })
  const context = { filesDir: '/test' }
  const service = new BackupService(context)
  const raw = await service.export(content)
  const document = JSON.parse(raw)
  assert.deepEqual(document.applicationSettings, await applicationSettings.exportApplicationSettings(context))
  assert.deepEqual(document.settings, readerSettings)
  assert.equal(document.sourceIndexUrl, sourceIndexUrl)
  assert.deepEqual(document.trackerSyncPreferences, { autoSyncEnabled: false, updateStrategy: 'manual' })
  assert.deepEqual(document.trackerMappings, tracker.comicMappings)
  assert.deepEqual(document.bannerFilters, { comic: 'banner-off' })
  for (const field of ['komgaCredential', 'kavitaCredential', 'webDavCredential', 'opdsCredential']) {
    assert.equal(document.remoteServers[field], '')
  }
  assert(!raw.includes('fixture-token') && !raw.includes('fixture-password'))
  // Restore into different local values so a missing import call cannot pass.
  stores.get('koma_app_preferences_v1')['app.language'] = 'destination'
  await service.import(raw)
  assert(committed)
  assert.deepEqual(await applicationSettings.exportApplicationSettings(context), document.applicationSettings)
  assert.deepEqual(restoredReader, readerSettings)
  assert.deepEqual(restoredBanners, { comic: 'banner-off' })
  assert.equal(stores.get('koma_source_package_manager_v1')['source_index.url'], sourceIndexUrl)
  assert.deepEqual(stores.get('koma_tracker_preferences_v1'), {
    'tracker.autoSyncEnabled': false, 'tracker.updateStrategy': 'manual',
    'tracker.comicMappings': JSON.stringify(tracker.comicMappings),
  })
  assert.deepEqual(stores.get('koma_remote_servers_v1'), {
    'server.endpoint-identities': 'endpoint-ids', 'komga.server': 'komga', 'kavita.server': 'kavita',
    'webdav.server': 'webdav', 'opds.server': 'opds',
  })
  sourceConstructionFailure = true
  await assert.rejects(service.import(raw), /fixture_cache_directory_failed/)
  assert.equal(restoreActive, false, 'Owner initialization failures must release the restore gate')
  const withoutSettings = JSON.parse(await service.export({ ...content, includeSettings: false, includeTrackerMappings: false }))
  for (const field of ['settings', 'applicationSettings', 'sourceIndexUrl', 'trackerSyncPreferences', 'trackerMappings']) {
    assert(!Object.hasOwn(withoutSettings, field), `Unexpected backup field when disabled: ${field}`)
  }
  service.loadContentPreferences = async () => ({ ...content, includeSettings: false })
  assert(!Object.hasOwn(JSON.parse(await service.exportBackgroundTemplate()), 'applicationSettings'))
  service.loadContentPreferences = async () => content
  assert.deepEqual(JSON.parse(await service.exportBackgroundTemplate()).applicationSettings, document.applicationSettings)
}

verifyRoundTrip().catch(error => { console.error(error); process.exitCode = 1 })
