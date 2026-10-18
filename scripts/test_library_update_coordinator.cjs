const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..', 'entry/src/main/ets')
const source = (path) => readFileSync(resolve(root, path + '.ets'), 'utf8')
function compile(text, dependencies) {
  const { outputText } = ts.transpileModule(text, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  })
  const module = { exports: {} }
  new Function('require', 'module', 'exports', outputText)((name) => {
    assert.ok(Object.hasOwn(dependencies, name), `Unexpected dependency ${name}`)
    return dependencies[name]
  }, module, module.exports)
  return module.exports
}
function deferred() {
  let resolve, reject
  const promise = new Promise((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}
async function until(predicate) {
  for (let i = 0; i < 100; i++) {
    if (predicate()) return
    await new Promise(setImmediate)
  }
  assert.fail('Expected coordinator phase was not reached')
}

// Compile real production summary helpers, persistence models, coordinator and bridge.
// Only network/provider execution and platform IO are mocked.
const serviceFile = ts.createSourceFile('LibraryUpdateService.ts', source('model/LibraryUpdateService'),
  ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const helperNames = ['countLibraryUpdateNewChapters', 'summarizeLibraryUpdateProviders', 'safeLibraryUpdateFailureCode']
const helpers = compile(serviceFile.statements.filter((node) => helperNames.includes(node.name?.text))
  .map((node) => node.getText(serviceFile)).join('\n'), {})
function summary(statuses) {
  const results = statuses.map((status, index) => ({ comicId: `comic-${index}`, providerKind: 'source_runtime',
    sourceKey: 'source:fixture', status, previousChapterCount: 1, newChapterCount: status === 'updated' ? 2 : 1,
    message: status === 'failed' ? 'network_error' : 'checked' }))
  return { checkedAt: Date.now(), totalCount: results.length,
    updatedCount: statuses.filter((value) => value === 'updated').length,
    unchangedCount: statuses.filter((value) => value === 'unchanged').length,
    skippedCount: statuses.filter((value) => value === 'skipped').length,
    failedCount: statuses.filter((value) => value === 'failed').length,
    results, providerSummaries: helpers.summarizeLibraryUpdateProviders(results) }
}

async function environment(autoCheckEnabled = true) {
  const controls = { statuses: ['unchanged'] }
  const calls = { service: 0, resultSave: 0, preferenceSave: 0, notify: 0, failureNotify: 0, running: 0 }
  const events = []
  const maps = new Map()
  const strings = { AppStrings: { get: (key) => key } }
  const arkData = { preferences: { getPreferences: async (_context, name) => {
    if (controls.readError && name.includes('preferences')) throw new Error('preference read failed')
    if (!maps.has(name)) maps.set(name, new Map())
    const data = maps.get(name)
    return {
      get: async (key, fallback) => data.has(key) ? data.get(key) : fallback,
      put: async (key, value) => { data.set(key, value) }, flush: async () => {},
    }
  } } }
  const preferences = compile(source('model/LibraryUpdatePreferencesStore'), {
    '@kit.ArkData': arkData, '../i18n/AppStrings': strings,
  })
  const results = compile(source('model/LibraryUpdateResultStore'), {
    '@kit.AbilityKit': {}, '@kit.ArkData': arkData, '@kit.NotificationKit': {},
    './LibraryUpdateService': helpers, './LibraryUpdatePreferencesStore': preferences,
    '../common/Constants': {}, '../i18n/AppStrings': strings,
  })
  const storage = new Map()
  const bridge = compile(source('state/LibraryUpdateState').replace(/^@ObservedV2\n/gm, '').replace(/@Trace /g, ''), {
    '@kit.ArkUI': { AppStorageV2: { connect: (_type, key, factory) => {
      if (!storage.has(key)) storage.set(key, factory())
      return storage.get(key)
    } } },
  })
  const foreground = compile(source('state/AppForegroundState').replace(/^@ObservedV2\n/gm, '').replace(/@Trace /g, ''), {
    '@kit.ArkUI': { AppStorageV2: { connect: (_type, key, factory) => {
      if (!storage.has(key)) storage.set(key, factory())
      return storage.get(key)
    } } },
  })
  const request = { context: {}, libraryStore: {}, sourceRegistry: {}, libraryPersistenceService: {}, reason: 'manual' }
  class PreferencesStore extends preferences.LibraryUpdatePreferencesStore {
    async load(strict) {
      if (controls.readGate) await controls.readGate.promise
      return super.load(strict)
    }
    async saveLastSummary(...args) {
      calls.preferenceSave++
      if (controls.preferenceSaveError) throw new Error('preference save failed')
      return super.saveLastSummary(...args)
    }
    async saveFailedCheck(...args) {
      calls.preferenceSave++
      if (controls.preferenceSaveError) throw new Error('preference save failed')
      return super.saveFailedCheck(...args)
    }
  }
  class ResultStore extends results.LibraryUpdateResultStore {
    async saveJobSnapshot(snapshot) {
      events.push(snapshot.state)
      if (snapshot.state === 'running') {
        calls.running++
        if (controls.runningGate) await controls.runningGate.promise
        if (controls.runningError) throw new Error('running save failed')
      } else if (controls.failureResultError) {
        throw new Error('failure result save failed')
      }
      return super.saveJobSnapshot(snapshot)
    }
    async save(...args) {
      calls.resultSave++
      if (controls.resultGate) await controls.resultGate.promise
      if (controls.resultSaveError) throw new Error('result save failed')
      events.push('result')
      return super.save(...args)
    }
  }
  const coordinator = compile(source('model/LibraryUpdateCoordinator'), {
    './RemoteServerStore': { RemoteServerStore: class {} },
    './LibraryUpdateService': { ...helpers, LibraryUpdateService: class {
      constructor(store, registry, persistence) {
        assert.equal(store, request.libraryStore)
        assert.equal(registry, request.sourceRegistry)
        assert.equal(persistence, request.libraryPersistenceService)
      }
      async checkLibraryUpdates() {
        calls.service++
        events.push('service')
        if (controls.serviceGate) await controls.serviceGate.promise
        if (controls.serviceError) throw new Error('service failed')
        return summary(controls.statuses)
      }
    } },
    './LibraryUpdatePreferencesStore': { ...preferences, LibraryUpdatePreferencesStore: PreferencesStore },
    './LibraryUpdateResultStore': { ...results, LibraryUpdateResultStore: ResultStore,
      publishLibraryUpdateNotification: async () => {
        calls.notify++
        if (controls.notifyGate) await controls.notifyGate.promise
        if (controls.notifyError) throw new Error('notification failed')
        return { delivered: false, code: 'disabled' }
      },
      publishLibraryUpdateFailureNotification: async () => {
        calls.failureNotify++
        if (controls.notifyGate) await controls.notifyGate.promise
        if (controls.notifyError) throw new Error('notification failed')
        return { delivered: false, code: 'disabled' }
      },
    },
    '../state/LibraryUpdateState': bridge,
    '../state/AppForegroundState': foreground,
  })
  const prefsStore = new preferences.LibraryUpdatePreferencesStore(request.context)
  await prefsStore.save({ ...preferences.DEFAULT_LIBRARY_UPDATE_PREFERENCES, autoCheckEnabled })
  return { controls, calls, events, preferences, results, prefsStore, coordinator,
    state: bridge.connectLibraryUpdateState(), request,
    foreground: foreground.connectAppForegroundState(),
    run: (reason = 'manual', requireForeground = false) =>
      coordinator.requestLibraryUpdateCheck({ ...request, reason, requireForeground }) }
}

async function main() {
  for (const firstReason of ['manual', 'due']) {
    const env = await environment()
    env.controls.runningGate = deferred()
    env.controls.serviceGate = deferred()
    env.controls.resultGate = deferred()
    env.controls.notifyGate = deferred()
    const first = env.run(firstReason)
    assert.equal(env.state.busy, true)
    const second = env.run('manual')
    const third = env.run('due')
    await until(() => env.calls.running === 1)
    assert.equal(env.calls.service, 0, 'Running snapshot must settle before service starts')
    env.controls.runningGate.resolve()
    await until(() => env.calls.service === 1)
    env.controls.serviceGate.resolve()
    await until(() => env.calls.resultSave === 1)
    assert.equal(env.state.busy, true)
    assert.equal(env.state.revision, 0)
    env.controls.resultGate.resolve()
    await until(() => env.calls.notify === 1)
    assert.equal(env.state.busy, true, 'The gate includes notification completion')
    env.controls.notifyGate.resolve()
    const values = await Promise.all([first, second, third])
    assert.ok(values.every((value) => value.status === 'completed'))
    assert.equal(env.calls.service, 1)
    assert.equal(env.calls.preferenceSave, 1)
    assert.equal(env.calls.resultSave, 1)
    assert.equal(env.calls.notify, 1)
    assert.equal(env.state.revision, 1)
    assert.equal(env.state.busy, false)
    assert.deepEqual(env.events.slice(0, 3), ['running', 'service', 'result'])
  }

  const notDue = await environment(false)
  notDue.controls.readGate = deferred()
  const auto = notDue.run('due')
  const manual = notDue.run('manual')
  notDue.controls.readGate.resolve()
  assert.equal((await auto).status, 'not-due')
  assert.equal((await manual).status, 'completed', 'Not-due must not swallow manual')
  assert.equal(notDue.calls.service, 1)
  assert.equal(notDue.state.revision, 1)
  const disabled = await environment(false)
  assert.equal((await disabled.run('due')).status, 'not-due')
  assert.equal(disabled.calls.running, 0)
  assert.equal(disabled.state.revision, 0)

  const backgrounded = await environment()
  backgrounded.foreground.active = true
  backgrounded.controls.readGate = deferred()
  const foregroundJob = backgrounded.run('due', true)
  backgrounded.foreground.active = false
  backgrounded.controls.readGate.resolve()
  assert.equal((await foregroundJob).status, 'unavailable')
  assert.equal(backgrounded.calls.running, 0)
  assert.equal(backgrounded.calls.service, 0)
  assert.equal(backgrounded.state.revision, 0)
  assert.equal((await backgrounded.run('due')).status, 'completed',
    'Explicit Settings due is not suppressed by the lifecycle admission gate')
  assert.equal((await backgrounded.run('manual', true)).status, 'completed')

  for (const [statuses, state, count] of [
    [['failed', 'skipped'], 'backed-off', 1], [['updated', 'failed'], 'failed', 0],
  ]) {
    const env = await environment()
    env.controls.statuses = statuses
    const value = await env.run()
    assert.equal(value.status, 'completed')
    assert.equal(value.preferences.failureCount, count)
    assert.equal(env.results.getLatestLibraryUpdateJobSnapshot().state, state)
    assert.equal(env.results.getLatestLibraryUpdateSummary().failedCount, 1)
    assert.equal((await env.run('due')).status, 'not-due')
    assert.equal(env.calls.service, 1)
  }

  const failed = await environment()
  failed.results.setLatestLibraryUpdateSummary(summary(['updated']))
  failed.controls.serviceError = true
  failed.controls.notifyGate = deferred()
  const failing = failed.run()
  await until(() => failed.calls.failureNotify === 1)
  assert.equal(failed.state.busy, true)
  failed.controls.notifyGate.resolve()
  assert.equal((await failing).status, 'failed')
  assert.equal(failed.results.getLatestLibraryUpdateSummary(), undefined)
  assert.equal(failed.results.getLatestLibraryUpdateJobSnapshot().state, 'backed-off')
  assert.equal(failed.state.revision, 1)
  failed.controls.serviceError = false
  assert.equal((await failed.run()).status, 'completed', 'Service failure must release admission')

  for (const failure of ['preferenceSaveError', 'failureResultError', 'notifyError']) {
    const env = await environment()
    env.controls.serviceError = true
    env.controls[failure] = true
    const value = await env.run()
    assert.equal(value.status, 'failed')
    assert.equal(env.calls.service, 1)
    assert.equal(env.calls.failureNotify, 1)
    assert.equal(value.persistenceFailed, failure !== 'notifyError')
    if (failure === 'notifyError') assert.equal(value.notification.code, 'publish_failed')
    assert.equal(env.state.revision, 1)
    assert.equal(env.state.busy, false)
  }

  const loadFailed = await environment()
  loadFailed.controls.readError = true
  loadFailed.controls.readGate = deferred()
  const unreadableDue = loadFailed.run('due')
  const unreadableManual = loadFailed.run()
  loadFailed.controls.readGate.resolve()
  const unavailable = await unreadableDue
  assert.equal(unavailable.status, 'unavailable')
  assert.equal(unavailable.persistenceFailed, true)
  const degraded = await unreadableManual
  assert.equal(degraded.status, 'completed')
  assert.equal(degraded.preferences, undefined)
  assert.equal(degraded.persistenceFailed, true)
  assert.equal(loadFailed.calls.preferenceSave, 0, 'Unknown preferences must not be overwritten')
  assert.equal(loadFailed.calls.service, 1, 'A failed due preflight must not consume manual degradation')
  assert.equal(loadFailed.state.revision, 1)
  loadFailed.controls.readError = false
  assert.equal((await loadFailed.prefsStore.load()).autoCheckEnabled, true)

  const lateReadFailure = await environment()
  lateReadFailure.controls.serviceGate = deferred()
  const lateReadJob = lateReadFailure.run()
  await until(() => lateReadFailure.calls.service === 1)
  lateReadFailure.controls.readError = true
  lateReadFailure.controls.serviceGate.resolve()
  const lateReadResult = await lateReadJob
  assert.equal(lateReadResult.status, 'completed')
  assert.equal(lateReadResult.persistenceFailed, true)
  assert.equal(lateReadResult.preferences, undefined)
  assert.equal(lateReadFailure.calls.failureNotify, 0)
  lateReadFailure.controls.readError = false
  assert.equal((await lateReadFailure.prefsStore.load()).autoCheckEnabled, true,
    'Strict completion load failure must preserve prior settings')

  for (const failure of ['runningError', 'preferenceSaveError', 'resultSaveError', 'notifyError']) {
    const env = await environment()
    env.controls[failure] = true
    const value = await env.run()
    assert.equal(value.status, 'completed', failure)
    assert.ok(value.summary)
    assert.equal(env.calls.failureNotify, 0)
    assert.equal(env.state.revision, 1)
    assert.equal(value.persistenceFailed, failure !== 'notifyError')
    if (failure === 'notifyError') assert.equal(value.notification.code, 'publish_failed')
    env.controls[failure] = false
    assert.equal((await env.run()).status, 'completed', `${failure} must release admission`)
  }
  const edits = await environment()
  edits.controls.serviceGate = deferred()
  const checking = edits.run()
  await until(() => edits.calls.service === 1)
  await Promise.all([
    edits.coordinator.mutateLibraryUpdatePreferences(() => edits.prefsStore.saveAutoCheckEnabled(false)),
    edits.coordinator.mutateLibraryUpdatePreferences(() => edits.prefsStore.saveIntervalHours(48)),
  ])
  edits.controls.serviceGate.resolve()
  await checking
  const persisted = await edits.prefsStore.load()
  assert.equal(persisted.autoCheckEnabled, false)
  assert.equal(persisted.intervalHours, 48)
  assert.ok(persisted.lastCheckedAt)
  console.log('PASS library update coordinator: single-flight, manual admission, real summary persistence, failure isolation, shared state and preference edits')
}
main().catch((error) => { console.error(error); process.exitCode = 1 })
