const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..', 'entry/src/main/ets')
const read = (path) => readFileSync(resolve(root, path + '.ets'), 'utf8')
function compile(text, dependencies) {
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
  const dependencies = {
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
    appForegroundState; libraryStore; sourceRegistry; libraryPersistenceService;
    ensureLibraryPersistenceService() { return this.libraryPersistenceService }
    handleReaderLabLaunch() {} openExternalReaderSession() {} reloadReaderSessionStore() {}
    triggerAutomaticBackup() {} triggerPendingTrackerProgressSync() {}
    ${['aboutToAppear', 'runForegroundLibraryUpdate', 'refreshLibrarySnapshot']
      .map((name) => method('pages/Index', name)).join('\n')}
  }`, dependencies).Index
  const index = new Index()
  Object.assign(index, { appForegroundState: foreground, libraryStore: library,
    sourceRegistry: registry, libraryPersistenceService: noPersistence ? undefined : persistence })
  const Entry = compile(`export class Entry {
    context = { applicationInfo: { debug: false } };
    syncRemoteProgressInBackground() {}
    ${['onForeground', 'onBackground'].map((name) => method('entryability/EntryAbility', name)).join('\n')}
  }`, { AppForegroundStateBridge: bridge.AppForegroundStateBridge,
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
  assert.match(read('pages/LibraryUpdateResultPage'), /@Monitor\('libraryUpdateState.revision'\)\s+private reloadResults/)

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

  const summaryA = { checkedAt: 100, totalCount: 1 }
  const summaryB = { checkedAt: 200, totalCount: 2 }
  let latestJob = { state: 'success', updatedAt: 100 }
  let latestSummary = summaryA
  let jobRead = deferred()
  let resultRead = deferred()
  const Results = compile(`export class Results {
    summary; jobSnapshot;
    libraryUpdateResultStore() { return resultStore }
    formatTimestamp(value) { return String(value) }
    ${['aboutToAppear', 'reloadResults', 'loadPersistedSummary', 'isFailureJobSnapshot',
      'isSummaryBlockedByJob', 'effectiveSummaryForJob', 'summaryMetricValue']
      .map((name) => method('pages/LibraryUpdateResultPage', name)).join('\n')}
  }`, {
    resultStore: { loadJobSnapshot: () => jobRead.promise, load: () => resultRead.promise },
    getLatestLibraryUpdateJobSnapshot: () => latestJob,
    getLatestLibraryUpdateSummary: () => latestSummary,
    setLatestLibraryUpdateJobSnapshot: (value) => { latestJob = value },
    setLatestLibraryUpdateSummary: (value) => { latestSummary = value },
    clearLatestLibraryUpdateSummary: () => { latestSummary = undefined },
    countLibraryUpdateNewChapters: compile(ts.createSourceFile('service.ts', read('model/LibraryUpdateService'),
      ts.ScriptTarget.Latest, true, ts.ScriptKind.TS).statements
      .find((node) => node.name?.text === 'countLibraryUpdateNewChapters').getText(), {}).countLibraryUpdateNewChapters,
  }).Results
  const resultsPage = new Results()
  resultsPage.aboutToAppear()
  assert.equal(resultsPage.summary, summaryA)
  latestJob = { state: 'success', updatedAt: 200 }
  latestSummary = summaryB
  resultsPage.reloadResults() // Deliver the declared completion-revision monitor without recreating the page.
  assert.equal(resultsPage.summary, summaryB)
  jobRead.resolve({ state: 'success', updatedAt: 100 })
  await tick()
  assert.equal(resultsPage.summary, summaryB, 'Old disk callback must not replace a newly completed round')
  assert.equal(resultsPage.jobSnapshot.updatedAt, 200)

  const partial = { checkedAt: 300, totalCount: 3 }
  latestSummary = partial
  latestJob = { state: 'failed', updatedAt: 300 }
  resultsPage.reloadResults()
  await tick()
  assert.equal(resultsPage.summary, partial, 'Same-round failure snapshot keeps its summary')
  resultsPage.summary = undefined
  latestSummary = undefined
  resultRead = deferred()
  resultsPage.loadPersistedSummary(latestJob)
  latestJob = { state: 'failed', updatedAt: 400 }
  resultRead.resolve(summaryA)
  await tick()
  assert.equal(resultsPage.summary, undefined, 'Pending read must use the latest job at completion')

  // Test the actual rendering inputs, not merely assignment to page.summary.
  const resultSource = read('pages/LibraryUpdateResultPage')
  assert.match(resultSource, /private SummaryCard\(\)/)
  assert.match(resultSource, /private ProviderSummaryCard\(\)/)
  const textExpression = (prefix) => {
    const line = resultSource.split('\n').map((line) => line.trim()).find((line) => line.startsWith(prefix))
    assert.ok(line, prefix)
    return line.slice('Text('.length, -1)
  }
  const timestampExpression = textExpression('Text(this.summary === undefined')
  const metricExpression = textExpression('Text(`${this.summaryMetricValue(metric)}')
  const providerExpression = resultSource.match(/ForEach\(([^\n]+), \(provider:/)[1]
  const resultExpression = resultSource.match(/ForEach\(([^\n]+), \(result:/)[1]
  const keyExpression = (kind) => {
    const line = resultSource.split('\n').find((line) => line.includes(`}, (${kind}:`) && line.includes('this.summary?.checkedAt'))
    assert.ok(line, `${kind} key must include current check identity`)
    return line.slice(line.indexOf('=>') + 2, line.lastIndexOf(')')).trim()
  }
  const bindings = compile(`
    export function timestamp() { return (${timestampExpression}) }
    export function metric(metric) { return (${metricExpression}) }
    export function providers() { return (${providerExpression}) }
    export function results() { return (${resultExpression}) }
    export function providerKey(provider) { return (${keyExpression('provider')}) }
    export function resultKey(result) { return (${keyExpression('result')}) }
  `, {})
  const provider = { providerKind: 'source_runtime', sourceKey: 'fixture', totalCount: 2 }
  const comicResult = { comicId: 'fixture', status: 'updated', previousChapterCount: 1, newChapterCount: 4 }
  const firstSummary = { checkedAt: 1000, totalCount: 2, updatedCount: 1, unchangedCount: 0,
    skippedCount: 1, failedCount: 0, providerSummaries: [provider], results: [comicResult] }
  resultsPage.summary = firstSummary
  const firstProviderKey = bindings.providerKey.call(resultsPage, provider)
  const firstResultKey = bindings.resultKey.call(resultsPage, comicResult)
  assert.equal(bindings.timestamp.call(resultsPage), '1000')
  assert.deepEqual(['total', 'updated', 'unchanged', 'skipped', 'failed', 'new-chapters']
    .map((metric) => bindings.metric.call(resultsPage, metric)), ['2', '1', '0', '1', '0', '3'])
  const secondSummary = { ...firstSummary, checkedAt: 2000, totalCount: 9, updatedCount: 2,
    unchangedCount: 3, skippedCount: 0, failedCount: 4,
    providerSummaries: [{ ...provider, totalCount: 9 }],
    results: [{ ...comicResult, newChapterCount: 8 }] }
  resultsPage.summary = secondSummary
  assert.equal(firstSummary.checkedAt, 1000, 'Fixture must replace, not mutate, the captured summary')
  assert.equal(bindings.timestamp.call(resultsPage), '2000')
  assert.deepEqual(['total', 'updated', 'unchanged', 'skipped', 'failed', 'new-chapters']
    .map((metric) => bindings.metric.call(resultsPage, metric)), ['9', '2', '3', '0', '4', '7'])
  assert.equal(bindings.providers.call(resultsPage), secondSummary.providerSummaries)
  assert.equal(bindings.results.call(resultsPage), secondSummary.results)
  assert.notEqual(bindings.providerKey.call(resultsPage, provider), firstProviderKey)
  assert.notEqual(bindings.resultKey.call(resultsPage, comicResult), firstResultKey)
  resultsPage.summary = undefined
  assert.equal(bindings.timestamp.call(resultsPage), '')
  assert.equal(bindings.metric.call(resultsPage, 'total'), '0')
  assert.deepEqual(bindings.providers.call(resultsPage), [])
  assert.deepEqual(bindings.results.call(resultsPage), [])
  console.log('PASS library update lifecycle: actual lifecycle/settings methods, Results revision/late reads and live timestamp/metric/list expressions across replacement and clearing')
}
main().catch((error) => { console.error(error); process.exitCode = 1 })
