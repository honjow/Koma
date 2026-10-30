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
  const DiagnosticLogger = { debug() {}, info() {}, warn() {}, error() {}, exception() {} }
  dependencies = { DiagnosticLogger, '../diagnostics/DiagnosticLogger': { DiagnosticLogger }, ...dependencies }
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
const service = compile(helperNodes.map((node) => node.getText(serviceFile)).join('\n') +
  '\nexport { safeLibraryUpdateFailureCode }', {})
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

function checkChapterIdentityProtection() {
  const { reconcileSourceChapterIdentity: reconcile, sourceChapterForRetainedIdentity: resume } =
    compile(source('SourceChapterIdentity'), {})
  const oldId = '/go/' + Buffer.from('9330-123-0123456789').toString('base64url')
  const currentId = '/comic/9330/123.html'
  const old = { id: oldId, pages: [{ id: 'page-1', uri: 'file://kept-page' }], pageCount: 1 }
  const emptyDuplicate = { id: currentId, pages: [], pageCount: 0 }
  const comic = { id: 'identity-fixture', sourceRuntimeId: 'com.mh1234.koma',
    chapters: [old, emptyDuplicate] }
  const incoming = [{ id: currentId, title: 'chapter', sourcePath: 'original-request-path' }]
  const before = JSON.stringify({ comic, incoming })
  const merged = reconcile(comic, '/comic/9330.html', incoming, new Set())
  assert.deepEqual(merged.removedDuplicateIds, [currentId])
  assert.deepEqual(merged.storedChapters, [old])
  assert.equal(merged.storedChapters[0], old, 'preserve the original chapter and cached pages')
  assert.equal(merged.chapters[0].id, oldId)
  assert.equal(merged.chapters[0].sourcePath, incoming[0].sourcePath)
  assert.equal(JSON.stringify({ comic, incoming }), before, 'do not mutate either input')
  for (const references of [undefined, new Set([currentId])]) {
    assert.deepEqual(reconcile(comic, '/comic/9330.html', incoming, references).storedChapters,
      comic.chapters, 'unknown or referenced duplicates must remain')
  }
  const populated = { ...comic, chapters: [old, { ...emptyDuplicate, pageCount: 2 }] }
  assert.equal(reconcile(populated, '/comic/9330.html', incoming, new Set()).storedChapters.length, 2)
  const ambiguous = { ...comic, chapters: [...comic.chapters,
    { ...old, id: '/go/' + Buffer.from('9330-123-abcdef0123').toString('base64url') }] }
  assert.deepEqual(reconcile(ambiguous, '/comic/9330.html', incoming, new Set()).removedDuplicateIds, [])
  assert.deepEqual(reconcile({ ...comic, sourceRuntimeId: 'other-source' }, '/comic/9330.html',
    incoming, new Set()).removedDuplicateIds, [])
  assert.equal(resume(comic.sourceRuntimeId, '/comic/9330.html', oldId, incoming).id, oldId)
  assert.equal(resume(comic.sourceRuntimeId, '/comic/9330.html', oldId,
    [{ ...incoming[0], id: '/comic/9999/123.html' }]), undefined)
}

function checkBaoziChapterIdentityProtection() {
  const { reconcileSourceChapterIdentity: reconcile, sourceChapterForRetainedIdentity: resume } =
    compile(source('SourceChapterIdentity'), {})
  const sourceId = 'online.baozimh.koma'
  const mangaId = 'manga:fixture'
  const id = 'chapter:fixture:7'
  const title = '第７话 "名字\\#"'
  const titled = `${id}#${title}`
  const kept = { id, title, isRead: true, pages: [{ id: 'page-1' }], pageCount: 1 }
  const comic = { sourceRuntimeId: sourceId, chapters: [kept] }
  const remote = [{ id: titled, title }, { id: `${id}#第８话`, title: '第８话' }]
  const before = JSON.stringify({ comic, remote })
  const enabled = reconcile(comic, mangaId, remote)
  assert.deepEqual(enabled.chapters.map((row) => row.id), [id, remote[1].id])
  assert.equal(enabled.storedChapters[0], kept, 'keep read state and downloaded page ownership')
  assert.equal(JSON.stringify({ comic, remote }), before, 'identity preparation never writes a partial result')
  const disabled = reconcile({ ...comic, chapters: [{ ...kept, id: titled }] }, mangaId, [{ id, title }])
  assert.equal(disabled.chapters[0].id, titled, 'switching off retains the persisted title identity')
  for (const rows of [
    [{ id: `${id}#different`, title: 'different' }],
    [{ id: titled, title }, { id: `${id}#other`, title }],
  ]) assert.throws(() => reconcile(comic, mangaId, rows), /source_chapter_identity_ambiguous/)
  const titleComic = { ...comic, chapters: [{ ...kept, id: titled }] }
  assert.throws(() => reconcile(titleComic, mangaId,
    [{ id, title }, { id, title: 'different' }]), /source_chapter_identity_ambiguous/,
  'switching off cannot collapse distinct chapter rows')
  assert.equal(reconcile({ ...comic, chapters: [] }, mangaId, remote).chapters, remote,
    'first load keeps the full source catalog')
  assert.equal(resume(sourceId, mangaId, titled, [{ id, title }]).id, titled)
  assert.equal(resume(sourceId, mangaId, id, [{ id: titled, title }]), undefined,
    'an orphaned legacy history ID has no title and cannot be guessed')
  assert.equal(resume(sourceId, mangaId, titled, [{ id, title }, { id, title: 'different' }]), undefined)
  const opaque = 'chapter:fixture:slot-A'
  assert.equal(reconcile({ ...comic, chapters: [{ ...kept, id: opaque }] }, mangaId,
    [{ id: `${opaque}#${title}`, title }]).chapters[0].id, opaque)
}

async function checkBaoziUpdateFailure() {
  const identity = compile(source('SourceChapterIdentity'), {})
  const owner = serviceFile.statements.find((node) => ts.isClassDeclaration(node) &&
    node.name?.text === 'LibraryUpdateService')
  const method = owner.members.find((node) => node.name?.text === 'checkSourceRuntimeComic')
  let conflictObserved = false
  const { Update } = compile(`const { sourceMangaIdFromComic, sourceRuntimeEntryEnabled,
    reconcileSourceChapterIdentity, providerKindForComic, sourceKeyForComic,
    safeLibraryUpdateFailureCode } = require('fixture');
    export class Update { ${method.getText(serviceFile)} }`, { fixture: {
    sourceMangaIdFromComic: () => 'manga:fixture', sourceRuntimeEntryEnabled: () => true,
    reconcileSourceChapterIdentity: (...args) => {
      try { return identity.reconcileSourceChapterIdentity(...args) }
      catch (error) { conflictObserved = error.message === 'source_chapter_identity_ambiguous'; throw error }
    },
    providerKindForComic: () => 'source_runtime', sourceKeyForComic: () => 'source:fixture',
    safeLibraryUpdateFailureCode: service.safeLibraryUpdateFailureCode,
  } })
  const kept = { id: 'chapter:fixture:7', title: '第7话', isRead: true, pages: [{ id: 'page-1' }] }
  const comic = { id: 'saved', sourceRuntimeId: 'online.baozimh.koma', chapters: [kept] }
  const update = new Update()
  let writes = 0
  update.sourceRegistry = { lookup: () => ({ ok: true, entry: { enabled: true } }) }
  update.libraryStore = { upsertComic: () => { writes++ } }
  update.fetchSourceRuntimeChapters = async () => [{ id: kept.id + '#different', title: 'different' }]
  const before = JSON.stringify(comic)
  const result = await update.checkSourceRuntimeComic(comic, 1)
  assert.equal(result.status, 'failed')
  assert.equal(result.newChapterCount, 1)
  assert.equal(conflictObserved, true)
  assert.equal(writes, 0, 'a failed whole-catalog match cannot publish a partial library update')
  assert.equal(JSON.stringify(comic), before)
}

async function main() {
  checkChapterIdentityProtection()
  checkBaoziChapterIdentityProtection()
  await checkBaoziUpdateFailure()
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
  console.log('PASS library update outcome: chapter identity/reference protection, classification, snapshot roundtrip, result persistence, failure backoff and recovery')
}

main().catch((error) => { console.error(error); process.exitCode = 1 })
