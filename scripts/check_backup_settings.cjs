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
    './OfflineDownloadQueueStore': { OfflineDownloadQueueStore: class {
      loadPreferences() { return { ...download } }
      savePreferencesForBackupRestore(value) { mutations += 1; download = value }
    } },
  }
  const backup = evaluate(read(applicationSettingsModule) + '\nexport { PORTABLE_FIELDS }', ports)
  const count = checkInventory(backup.PORTABLE_FIELDS)
  const valuesForStore = {}
  for (const [store, keys] of Object.entries(backup.PORTABLE_FIELDS)) {
    const values = Object.fromEntries(keys.map((key, index) => [key, [false, 7, 'fixture'][index % 3]]))
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
  await verifyBackupDocument(ports, backup, stores, value => { restoring = value })
  console.log(`Backup settings gate passed (${count} Preferences owner/key pairs; application settings export/restore verified).`)
  for (const [owner, keys] of Object.entries(policy.pending)) {
    console.log(`Existing backup gap: ${owner} → ${keys.join(', ')}`)
  }
}

async function verifyBackupDocument(ports, applicationSettings, stores, setRestoring) {
  const readerKeys = policy.separateBackupFields['model/ReaderPreferencesStore.ets']
  const readerSettings = Object.fromEntries(readerKeys.filter(key => !key.endsWith('.v1')).map(key =>
    [key.slice('reader.'.length), 'saved:' + key]))
  let restoredReader
  let restoredBanners
  let committed = false
  const content = { includeSettings: true, includeDownloadQueue: false, includeTrackerMappings: true }
  const tracker = { autoSyncEnabled: false, updateStrategy: 'manual', comicMappings: [{ comicId: 'comic' }],
    accounts: [{ accessToken: 'fixture-token' }] }
  const sourceIndexUrl = 'https://sources.example.test/index.json'
  const serverConfig = {
    endpointIdentities: 'endpoint-ids', komgaServer: 'komga', kavitaServer: 'kavita',
    webDavServer: 'webdav', opdsServer: 'opds',
    komgaCredential: 'fixture-token', webDavCredential: 'fixture-password',
  }
  const { BackupService } = evaluate(read('model/BackupService.ets'), {
    ...ports,
    './ApplicationSettingsBackup': { ...applicationSettings, reloadApplicationSettingsRuntime: async () => {} },
    './BackupRestoreActivity': { BackupRestoreActivity: {
      runWrite: action => action(), beginRestore: () => setRestoring(true), finishRestore: () => setRestoring(false),
    } },
    '../deviceSync/DeviceSyncSignals': evaluate(read('deviceSync/DeviceSyncSignals.ets'), {}),
    './BackupRestoreCheckpoint': { BackupRestoreCheckpoint: {
      prepare: async () => ({ commit: () => { committed = true } }),
    } },
    './AppFileTextPersistence': { writeAppTextFile() {} },
    './AutomationStateEpoch': { beginAutomationRestore() {}, finishAutomationRestore() {}, resetGeneratedAutomationWork() {} },
    '@kit.CoreFileKit': { fileIo: { accessSync: () => false } },
    './LibraryPersistence': { LIBRARY_STORE_PERSISTENCE_FILE_NAME: 'library.json', assertValidLibraryStoreJson() {} },
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
    '../sourceRuntime/SourceIndexService': { SourceIndexService: class { async loadSavedUrl() { return sourceIndexUrl } } },
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
