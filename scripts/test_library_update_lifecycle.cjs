const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..', 'entry/src/main/ets')
const read = (path) => readFileSync(resolve(root, path + '.ets'), 'utf8')
function compile(text, dependencies) {
  const DiagnosticLogger = { debug() {}, info() {}, warn() {}, error() {}, exception() {} }
  dependencies = { DiagnosticLogger, '../diagnostics/DiagnosticLogger': { DiagnosticLogger }, ...dependencies }
  const { outputText } = ts.transpileModule(text, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  })
  const module = { exports: {} }
  const globals = Object.keys(dependencies).filter((key) => /^[A-Za-z_$]\w*$/.test(key))
  new Function('require', 'module', 'exports', ...globals, outputText)(
    (name) => { assert.ok(Object.hasOwn(dependencies, name), name); return dependencies[name] },
    module, module.exports, ...globals.map((key) => dependencies[key]))
  return module.exports
}
function method(path, name) {
  const file = ts.createSourceFile(path + '.ts', read(path).replace(/\bstruct (\w+)/g, 'class $1'),
    ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
  const owner = file.statements.find((node) => ts.isClassDeclaration(node) &&
    node.members.some((member) => member.name?.text === name))
  assert.ok(owner, `Missing actual class method ${name}`)
  const node = owner.members.find((member) => member.name?.text === name)
  return node.getText(file).replace(/@Monitor\([^]*?\)\s*/g, '')
}
function deferred() {
  let resolve
  const promise = new Promise((yes) => { resolve = yes })
  return { promise, resolve }
}
const tick = () => new Promise(setImmediate)

function environment({ restoreFails = false, noPersistence = false } = {}) {
  const states = new Map()
  const bridge = compile(read('state/AppForegroundState').replace(/^@ObservedV2\n/gm, '').replace(/@Trace /g, ''), {
    '@kit.ArkUI': { AppStorageV2: { connect: (_type, key, factory) => {
      if (!states.has(key)) states.set(key, factory())
      return states.get(key)
    } } },
  })
  const foreground = bridge.connectAppForegroundState()
  const activation = deferred()
  const calls = []
  const events = []
  const library = { listComics: () => [{ id: 'restored-fixture' }] }
  const registry = { count: () => 0 }
  const persistence = { restore: () => {
    events.push('restore')
    if (restoreFails) throw new Error('restore failed')
  } }
  const context = {}
  const isolation = compile(read('state/KomaDeviceVerificationIsolation'), {})
  const dependencies = {
    ...isolation,
    appDeviceSync: { attachPublisher() {} },
    bindRemoteProgressLibrary() {},
    applyBackgroundLibraryResults: async () => {},
    appSourceWebSessionStore: { configure() {} },
    appSourcePackageManagerCache: { prepare: async () => {}, revalidateInBackground() {} },
    connectLanguageState: () => ({ effectiveLocale: 'zh-CN' }),
    ImageRuleStore: { forContext: () => ({ revalidateInBackground() {} }) },
    getContext: () => context,
    RouterHelper: { setAppPathStack() {}, setReaderOpener() {}, consumePendingLaunchRoute() {} },
    configureSourceSettingsStore() {}, configureSourceFilterPreferencesStore() {},
    bootstrapSourceRuntimeAppRegistry: () => events.push('registry'),
    activateLocalLibraryFolderAccessForComics: (comics) => {
      assert.equal(comics[0].id, 'restored-fixture')
      events.push('activation')
      return activation.promise
    },
    requestLibraryUpdateCheck: async (request) => {
      assert.equal(request.context, context)
      assert.equal(request.libraryStore, library)
      assert.equal(request.sourceRegistry, registry)
      assert.equal(request.libraryPersistenceService, persistence)
      assert.equal(request.reason, 'due')
      assert.equal(request.requireForeground, true)
      calls.push(request)
      return { status: 'not-due', persistenceFailed: false }
    },
    setTimeout: () => 0, // Unrelated backup/progress timers are not executed in this lifecycle test.
  }
  const Index = compile(`export class Index {
    libraryUpdateReady = false; libraryPersistenceRestored = false; readerSessionPersistenceReady = true;
    libraryRevision = 0; appPathStack = {}; libraryComics = [];
    libraryUpdateState = { busy: false };
    catalogFilters = { prepare: async () => {} };
    appForegroundState; libraryStore; sourceRegistry; libraryPersistenceService;
    ensureLibraryPersistenceService() { return this.libraryPersistenceService }
    retryPublicContentStorage() {} retryMihonAfterSourceChange() {}
    isReaderRouteVisible() { return false } publishDeferredReaderBackgroundPresentation() {}
    handleReaderLabLaunch() {} openExternalReaderSession() {} reloadReaderSessionStore() {}
    triggerAutomaticBackup() {} triggerPendingTrackerProgressSync() {} runForegroundAutomaticBackup() {}
    loadLibraryChapterUpdateHistory() {} refreshLibraryUpdateBadge() {} resumeAutomaticDownloadQueue() {}
    showLibraryUpdateResult() {}
    ${['aboutToAppear', 'runForegroundLibraryUpdate', 'refreshLibrarySnapshot']
      .map((name) => method('pages/Index', name)).join('\n')}
  }`, dependencies).Index
  const index = new Index()
  Object.assign(index, { appForegroundState: foreground, libraryStore: library,
    sourceRegistry: registry, libraryPersistenceService: noPersistence ? undefined : persistence })
  const Entry = compile(`export class Entry {
    context = { applicationInfo: { debug: false } };
    startupPromise = Promise.resolve(); syncForegroundGeneration = 0;
    syncRemoteProgressInBackground() {}
    ${['onForeground', 'onBackground'].map((name) => method('entryability/EntryAbility', name)).join('\n')}
  }`, { ...isolation, AppForegroundStateBridge: bridge.AppForegroundStateBridge,
    connectLibraryPrivacyState: () => ({ onForeground() {}, onBackground() {} }),
    appDeviceSync: { onForeground() {} }, synchronizeBackgroundMaintenance: async () => {},
    updateReaderLabForeground: () => {}, setTimeout: () => 0 }).Entry
  const entry = new Entry()
  return { index, entry, calls, events, foreground,
    finishActivation: () => activation.resolve({ rootCount: 1, activatedCount: 1,
      notPersistedCount: 0, unsupportedCount: 0, failedCount: 0 }),
    foregroundEvent: () => {
      entry.onForeground()
      // Simulate delivery of the declared Monitor; native subscription/rendering is device acceptance.
      index.runForegroundLibraryUpdate()
    } }
}

async function main() {
  assert.match(read('pages/Index'), /@Monitor\('appForegroundState.revision'\)\s+private runForegroundLibraryUpdate/)
  assert.match(read('pages/Index'), /@Monitor\('libraryUpdateState.revision'\)\s+private refreshLibrarySnapshot/)
  assert.match(read('pages/SettingsPage'), /@Monitor\('libraryUpdateState.revision'\)\s+private reloadCompletedLibraryUpdate/)

  const foregroundFirst = environment()
  foregroundFirst.foregroundEvent()
  foregroundFirst.index.aboutToAppear()
  await tick()
  assert.deepEqual(foregroundFirst.events, ['registry', 'restore', 'activation'])
  assert.equal(foregroundFirst.calls.length, 0, 'Unfinished activation must block due admission')
  assert.equal(foregroundFirst.index.libraryUpdateReady, false)
  foregroundFirst.finishActivation()
  await tick()
  assert.equal(foregroundFirst.calls.length, 1)

  const uiFirst = environment()
  uiFirst.index.aboutToAppear()
  uiFirst.finishActivation()
  await tick()
  assert.equal(uiFirst.index.libraryUpdateReady, true)
  assert.equal(uiFirst.calls.length, 0, 'UI bootstrap alone is not proof of foreground')
  uiFirst.foregroundEvent()
  await tick()
  assert.equal(uiFirst.calls.length, 1)
  uiFirst.entry.onBackground()
  uiFirst.index.runForegroundLibraryUpdate()
  assert.equal(uiFirst.calls.length, 1)
  uiFirst.foregroundEvent()
  await tick()
  assert.equal(uiFirst.calls.length, 2, 'Return to foreground must check the shared entry again')

  const backgroundDuringRestore = environment()
  backgroundDuringRestore.foregroundEvent()
  backgroundDuringRestore.index.aboutToAppear()
  backgroundDuringRestore.entry.onBackground()
  backgroundDuringRestore.finishActivation()
  await tick()
  assert.equal(backgroundDuringRestore.calls.length, 0)
  backgroundDuringRestore.foregroundEvent()
  await tick()
  assert.equal(backgroundDuringRestore.calls.length, 1)

  for (const options of [{ restoreFails: true }, { noPersistence: true }]) {
    const unavailable = environment(options)
    unavailable.foregroundEvent()
    unavailable.index.aboutToAppear()
    unavailable.foregroundEvent()
    await tick()
    assert.equal(unavailable.index.libraryUpdateReady, false)
    assert.equal(unavailable.calls.length, 0)
    assert.ok(!unavailable.events.includes('activation'))
  }

  let loadFails = false
  let loads = 0
  const savedPreferences = { autoCheckEnabled: true, intervalHours: 48, failureCount: 0 }
  const Settings = compile(`export class Settings {
    libraryUpdatePreferencesEpoch = 0;
    libraryUpdatePreferences = undefined; latestReloads = 0; toasts = [];
    libraryUpdatePreferencesStore() { return preferenceStore }
    clearStaleLibraryUpdateSummaryAfterFailure() {}
    loadLatestLibraryUpdateSummary() { this.latestReloads++ }
    runDueLibraryUpdateCheck() { throw new Error('Settings loading must not run due checks') }
    showToast(message) { this.toasts.push(message) }
    ${['loadLibraryUpdatePreferences', 'reloadCompletedLibraryUpdate', 'saveLibraryUpdatePreferences',
      'setLibraryAutoUpdateEnabled', 'saveLibraryUpdateInterval']
      .map((name) => method('pages/SettingsPage', name)).join('\n')}
  }`, {
    preferenceStore: {
      load: async (strict) => {
        assert.equal(strict, true)
        loads++
        if (loadFails) throw new Error('storage unreadable')
        return savedPreferences
      },
      saveAutoCheckEnabled: async () => { throw new Error('save failed') },
      saveIntervalHours: async () => { throw new Error('save failed') },
    },
    mutateLibraryUpdatePreferences: (operation) => operation(),
    safeSettingsErrorCode: () => 'test_storage_error',
    s: (key) => key,
  }).Settings
  const root = new Settings()
  const pane = new Settings()
  root.loadLibraryUpdatePreferences()
  pane.reloadCompletedLibraryUpdate()
  await tick()
  assert.equal(loads, 2)
  assert.equal(root.libraryUpdatePreferences, savedPreferences)
  assert.equal(pane.libraryUpdatePreferences, savedPreferences)
  assert.equal(pane.latestReloads, 1)
  loadFails = true
  root.reloadCompletedLibraryUpdate()
  await tick()
  assert.equal(root.libraryUpdatePreferences, savedPreferences, 'Failed load must retain known UI preferences')
  root.setLibraryAutoUpdateEnabled(false)
  root.saveLibraryUpdateInterval(12)
  assert.equal(root.libraryUpdatePreferences, savedPreferences, 'Pending edits must not advertise unsaved preferences')
  await tick()
  await tick()
  assert.equal(root.libraryUpdatePreferences, savedPreferences, 'Save plus reread failures must retain the known preference')
  assert.deepEqual(root.toasts, ['settings_library_auto_update_save_failed', 'settings_library_update_interval_save_failed'])

  let recordsRead = deferred()
  let failureRead = deferred()
  const failure = { results: [{ comicId: 'failed-book' }] }
  const clear = { results: [] }
  const records = [{ comicId: 'book', chapterId: 'new-chapter' }]
  const Updates = compile(`export class Updates {
    records = []; loading = true; error = false; failures = { results: [] }; loadRevision = 0;
    ${['aboutToAppear', 'aboutToDisappear', 'reload']
      .map((name) => method('pages/LibraryUpdatesPage', name)).join('\n')}
  }`, {
    getContext: () => ({}),
    LibraryUpdateResultStore: class {
      loadChapterUpdates() { return recordsRead.promise }
      loadFailureDetails() { return failureRead.promise }
    },
  }).Updates
  const updates = new Updates()
  updates.aboutToAppear()
  recordsRead.resolve(records)
  failureRead.resolve(failure)
  await tick()
  assert.equal(updates.records, records)
  assert.equal(updates.failures, failure)
  assert.equal(updates.loading, false)

  failureRead = deferred()
  const olderRead = failureRead
  updates.reload()
  failureRead = deferred()
  updates.reload()
  failureRead.resolve(clear)
  await tick()
  olderRead.resolve(failure)
  await tick()
  assert.equal(updates.failures, clear, 'A delayed failure cannot replace a newer successful check')
  assert.equal(updates.records, records, 'Changing check failures does not clear chapter updates')

  failureRead = deferred()
  updates.reload()
  updates.aboutToDisappear()
  failureRead.resolve(failure)
  await tick()
  assert.equal(updates.failures, clear)
  console.log('PASS library update lifecycle: settings, delayed failure reads and retained new chapters')
}
main().catch((error) => { console.error(error); process.exitCode = 1 })
