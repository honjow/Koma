const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')

// Use the installed compiler; no generated source or dependency installation.
let ts
for (const candidate of [process.env.KOMA_TYPESCRIPT_PATH, 'typescript',
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript']) {
  if (!candidate) continue
  try { ts = require(candidate); break } catch (_) {}
}
assert.ok(ts, 'Provide TypeScript via KOMA_TYPESCRIPT_PATH or the installed DevEco SDK')
const root = resolve(__dirname, '..')
const source = (name) => readFileSync(resolve(root, `entry/src/main/ets/model/${name}.ets`), 'utf8')
const stores = new Map()
const arkData = { preferences: { getPreferences: async (_context, name) => {
  if (!stores.has(name)) stores.set(name, new Map())
  const data = stores.get(name)
  return {
    has: async (key) => data.has(key),
    delete: async (key) => data.delete(key),
    get: async (key, fallback) => data.has(key) ? data.get(key) : fallback,
    put: async (key, value) => { data.set(key, value) },
    flush: async () => {},
  }
} } }

function compile(text, dependencies) {
  const { outputText } = ts.transpileModule(text, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  })
  const module = { exports: {} }
  const load = (name) => {
    assert.ok(Object.hasOwn(dependencies, name), `Unexpected dependency: ${name}`)
    return dependencies[name]
  }
  new Function('require', 'module', 'exports', outputText)(load, module, module.exports)
  return module.exports
}

// Compile the actual service helpers without loading platform network providers.
const serviceFile = ts.createSourceFile('LibraryUpdateService.ts', source('LibraryUpdateService'),
  ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const helperNames = ['countLibraryUpdateNewChapters', 'summarizeLibraryUpdateProviders', 'safeLibraryUpdateFailureCode']
const helperNodes = serviceFile.statements.filter((node) => helperNames.includes(node.name?.text))
assert.equal(helperNodes.length, helperNames.length)
const service = compile(helperNodes.map((node) => node.getText(serviceFile)).join('\n'), {})
const strings = { AppStrings: { get: (key) => key } }
const prefs = compile(source('LibraryUpdatePreferencesStore'), {
  '@kit.ArkData': arkData, '../i18n/AppStrings': strings,
})
const result = compile(source('LibraryUpdateResultStore'), {
  '@kit.AbilityKit': {}, '@kit.ArkData': arkData, '@kit.NotificationKit': {},
  './LibraryUpdateService': service, './LibraryUpdatePreferencesStore': prefs,
  '../common/Constants': {}, '../i18n/AppStrings': strings,
})

const checkedAt = 1800000000000
function summary(statuses, time = checkedAt) {
  const results = statuses.map((status, index) => ({
    comicId: `comic-${index}`, providerKind: 'source_runtime', sourceKey: 'source:fixture',
    status, previousChapterCount: 4, newChapterCount: status === 'updated' ? 5 : 4,
    message: status === 'failed' ? 'network_error' : 'checked',
  }))
  return {
    checkedAt: time, totalCount: results.length,
    updatedCount: statuses.filter((s) => s === 'updated').length,
    unchangedCount: statuses.filter((s) => s === 'unchanged').length,
    skippedCount: statuses.filter((s) => s === 'skipped').length,
    failedCount: statuses.filter((s) => s === 'failed').length,
    results, providerSummaries: service.summarizeLibraryUpdateProviders(results),
  }
}

async function main() {
  const cases = [
    [[], 'no-eligible', 'success'],
    [['skipped'], 'no-eligible', 'success'],
    [['failed'], 'all-failed', 'failed'],
    [['failed', 'skipped'], 'all-failed', 'failed'],
    [['failed', 'unchanged'], 'partial-failure', 'failed'],
    [['failed', 'updated'], 'partial-failure', 'failed'],
    [['updated', 'unchanged'], 'updated', 'success'],
    [['unchanged', 'skipped'], 'unchanged', 'success'],
  ]
  const store = new result.LibraryUpdateResultStore({})
  for (const [statuses, outcome, state] of cases) {
    const current = summary(statuses)
    assert.equal(result.classifyLibraryUpdateSummary(current), outcome)
    const snapshot = result.completedLibraryUpdateJobSnapshot(current, checkedAt - 100)
    assert.equal(snapshot.state, state)
    assert.equal(snapshot.startedAt, checkedAt - 100)
    const restored = result.hydrateLibraryUpdateJobSnapshotFromJson(result.serializeLibraryUpdateJobSnapshot(snapshot))
    assert.equal(restored.state, state)
    assert.equal(result.classifyLibraryUpdateSummary(restored.summary), outcome)
    assert.equal(restored.failureCode, snapshot.failureCode)
    await store.save(current)
    const cold = new result.LibraryUpdateResultStore({})
    assert.equal((await cold.loadJobSnapshot()).state, state)
    assert.equal(result.classifyLibraryUpdateSummary(await cold.load()), outcome)
  }

  const failed = summary(['failed', 'skipped'])
  const delayed = result.completedLibraryUpdateJobSnapshot(failed, checkedAt, checkedAt + 3600000)
  assert.equal(delayed.state, 'backed-off')
  assert.equal(delayed.failureCode, 'all_failed')
  assert.equal(result.completedLibraryUpdateJobSnapshot(failed, checkedAt, checkedAt).state, 'failed')
  await store.save(failed, delayed)
  assert.equal((await store.loadJobSnapshot()).state, 'backed-off')
  await store.saveJobSnapshot(delayed)
  assert.equal((await store.load()).failedCount, 1, 'same-run failure details survive')
  const partial = result.completedLibraryUpdateJobSnapshot(summary(['failed', 'updated']))
  await store.saveJobSnapshot(partial)
  assert.equal((await store.loadJobSnapshot()).failureCode, 'partial_failure')
  assert.equal((await store.load()).updatedCount, 1, 'partial success details survive')
  await store.saveJobSnapshot(result.createLibraryUpdateJobSnapshot('failed', checkedAt + 1))
  assert.equal(await store.load(), undefined, 'a failure without a summary invalidates the old result')

  const preferenceStore = new prefs.LibraryUpdatePreferencesStore({})
  await preferenceStore.saveAutoCheckEnabled(true)
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    await preferenceStore.saveLastSummary(checkedAt, 2, 0, 0, 1, 1)
    const cold = await new prefs.LibraryUpdatePreferencesStore({}).load()
    assert.equal(cold.failureCount, attempt)
    assert.equal(cold.lastFailureCode, 'all_failed')
    assert.equal(cold.lastSummaryFailedCount, 1)
    assert.equal(cold.lastSummarySkippedCount, 1)
    assert.equal(prefs.getLibraryUpdateBackoffHours(cold), attempt)
    assert.ok(prefs.getLibraryUpdateNextDueAt(cold) > checkedAt + 24 * 3600000)
  }
  await preferenceStore.saveLastSummary(checkedAt + 1, 2, 1, 1, 0, 1)
  const recovered = await new prefs.LibraryUpdatePreferencesStore({}).load()
  assert.equal(recovered.failureCount, 0)
  assert.equal(recovered.lastFailureCode, undefined)
  assert.equal(recovered.lastSummaryFailedCount, 1)
  await preferenceStore.saveLastSummary(checkedAt + 2, 1, 0, 0, 0, 0)
  assert.equal((await preferenceStore.load()).failureCount, 0)
  console.log('PASS library update outcome: classification, snapshot roundtrip, result persistence, failure backoff and recovery')
}

main().catch((error) => { console.error(error); process.exitCode = 1 })
