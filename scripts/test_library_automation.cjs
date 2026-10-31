const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets/model')
function load(name, deps = {}) {
  const text = fs.readFileSync(path.join(root, name + '.ets'), 'utf8')
  const js = ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
  const module = { exports: {} }
  new Function('require', 'module', 'exports', js)(key => {
    assert.ok(Object.hasOwn(deps, key), 'Unexpected dependency ' + key)
    return deps[key]
  }, module, module.exports)
  return module.exports
}
const sequence = load('ReaderChapterSequence')
const policy = load('LibraryAutomationPolicy', { './ReaderChapterSequence': sequence })
const activity = load('BackupRestoreActivity')
const read = new Set(['chapter-0', 'chapter-2', 'chapter-3'])
const reader = { isChapterRead: (_comic, id) => read.has(id), getProgress: () => undefined, getChapterProgress: () => undefined }
const comic = { id: 'book', categoryIds: ['included', 'excluded'], sourceMetadata: { status: 'completed' },
  chapters: [4,3,2,1,0].map(n => ({ id: 'chapter-' + n, readingOrder: n, readingGroup: 'main', continuationEligible: true })) }
assert.equal(policy.comicMatchesAutomationCategories(comic, ['included'], ['excluded']), false)
assert.equal(policy.comicMatchesAutomationCategories({ categoryIds: [] }, ['uncategorized'], []), true)
assert.equal(policy.shouldAutomaticallyUpdateComic(comic, reader, policy.defaultLibraryAutomationPreferences()), true)
for (const field of ['skipCompleted', 'skipHasUnread']) {
  const config = policy.defaultLibraryAutomationPreferences(); config[field] = true
  assert.equal(policy.shouldAutomaticallyUpdateComic(comic, reader, config), false)
}
const notStarted = policy.defaultLibraryAutomationPreferences(); notStarted.skipNotStarted = true
assert.equal(policy.shouldAutomaticallyUpdateComic(comic, reader, notStarted), true)
assert.equal(policy.shouldAutomaticallyUpdateComic(comic, { ...reader, isChapterRead: () => false }, notStarted), false)
assert.deepEqual(policy.newlyAddedChapterIds(new Set(['chapter-4','chapter-3','chapter-1']), comic), ['chapter-2','chapter-0'])
const config = policy.defaultLibraryAutomationPreferences(); config.removeAfterRead = 2
assert.deepEqual(policy.chaptersToRemoveAfterReading(comic, 'chapter-3', reader, config), ['chapter-0'])
config.cleanupExcludedCategories = ['included']
assert.deepEqual(policy.chaptersToRemoveAfterReading(comic, 'chapter-3', reader, config), [])
config.cleanupExcludedCategories = []; config.removeAfterRead = 0
assert.deepEqual(policy.chaptersToRemoveAfterReading(comic, 'chapter-3', reader, config), ['chapter-3'])
assert.deepEqual(policy.chaptersToRemoveAfterReading(comic, 'chapter-1', reader, config), [])

async function main() {
  const data = new Map(); let fail = false
  const platform = { preferences: { getPreferences: async () => ({
    get: async (key, fallback) => data.has(key) ? data.get(key) : fallback,
    put: async (key, value) => { data.set(key, value) },
    flush: async () => { if (fail) { fail = false; throw Error('disk full') } },
  }) } }
  const store = load('LibraryAutomationPreferencesStore', {
    '@kit.ArkData': platform, './BackupRestoreActivity': activity, './LibraryAutomationPolicy': policy,
  })
  const preferences = new store.LibraryAutomationPreferencesStore({})
  assert.equal((await preferences.load()).autoDownloadNewChapters, false)
  await Promise.all([preferences.update(p => { p.autoDownloadNewChapters = true }),
    preferences.update(p => { p.skipCompleted = true })])
  assert.equal((await preferences.load()).autoDownloadNewChapters, true)
  assert.equal((await preferences.load()).skipCompleted, true)
  fail = true
  await assert.rejects(preferences.update(p => { p.removeAfterRead = 0 }), /disk full/)
  assert.equal((await preferences.load()).removeAfterRead, -1)

  const directory = fs.mkdtempSync('/private/tmp/koma-auto-cleanup-')
  const deleted = []
  const cleanup = load('ReadDownloadCleanup', {
    '@kit.CoreFileKit': { fileIo: { accessSync: fs.existsSync, readTextSync: p => fs.readFileSync(p, 'utf8') } },
    './LibraryAutomationPreferencesStore': store, './LibraryAutomationPolicy': policy,
    './OfflineDownloadQueueStore': { OfflineDownloadQueueStore: class { async deleteChapterDownload(_comic, chapter) { deleted.push(chapter) } } },
    './OfflineDownloadRuntime': { OfflineDownloadRuntime: { isActive: () => false } },
    './BackupRestoreActivity': activity,
    './AppFileTextPersistence': { writeAppTextFile: (p, value) => fs.writeFileSync(p, value) },
  })
  const context = { filesDir: directory }
  const session = new cleanup.ReadDownloadCleanup(directory)
  const progress = { comicId: comic.id, chapterId: 'chapter-3', completed: true }
  await session.observe(context, progress)
  assert.equal(fs.readdirSync(directory).length, 0, 'Disabled cleanup must not write a pending-work file')
  await preferences.update(p => { p.removeAfterRead = 2 })
  await session.observe(context, progress)
  assert.deepEqual(deleted, [], 'Observed completion does not delete images during Reader')
  const reopened = new cleanup.ReadDownloadCleanup(directory)
  await reopened.run(context, { getComic: () => comic }, reader)
  assert.deepEqual(deleted, ['chapter-0'], 'Recovered work uses absolute chapter order and preserves unread chapters')
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(directory, 'read-download-cleanup.v1.json'), 'utf8')), [])
  let failQueue = true
  const queued = []
  const automatic = load('LibraryAutomaticDownload', {
    './LibraryAutomationPreferencesStore': store, './LibraryAutomationPolicy': policy,
    '@kit.CoreFileKit': { fileIo: { accessSync: fs.existsSync, readTextSync: p => fs.readFileSync(p, 'utf8') } },
    './AppFileTextPersistence': { writeAppTextFile: (p, value) => fs.writeFileSync(p, value) },
    './LibraryBatchDownloadQueue': { LibraryBatchDownloadQueue: class {
      prepare() { return { targets: comic.chapters.filter(c => !queued.includes(c.id)).map(c => ({ comicId: comic.id, chapterId: c.id })) } }
      async enqueue(targets, unreadOnly, automatic) {
        assert.equal(unreadOnly, true); assert.equal(automatic, true)
        if (failQueue) { failQueue = false; throw Error('queue storage unavailable') }
        queued.push(...targets.map(t => t.chapterId))
      }
    } },
  })
  const library = { getComic: () => comic, listComics: () => [comic] }
  const previous = new Map([[comic.id, new Set(['chapter-0','chapter-1','chapter-2','chapter-3'])]])
  await assert.rejects(automatic.enqueueAutomaticallyAddedChapters(context, library, reader,
    { results: [{ comicId: comic.id, status: 'updated' }] }, previous), /queue storage unavailable/)
  assert.deepEqual(queued, [])
  await automatic.drainPendingAutomaticChapters(context, library, reader)
  assert.deepEqual(queued, ['chapter-4'], 'A failed queue commit retains the actual new ID for retry after library has already committed')
  await automatic.drainPendingAutomaticChapters(context, library, reader)
  assert.deepEqual(queued, ['chapter-4'])
  const epoch = load('AutomationStateEpoch', {
    '@kit.CoreFileKit': { fileIo: { accessSync: fs.existsSync, readTextSync: p => fs.readFileSync(p, 'utf8'),
      unlinkSync: fs.unlinkSync, listFileSync: fs.readdirSync } },
    './AppFileTextPersistence': { writeAppTextFile: (p, value) => fs.writeFileSync(p, value) },
  })
  const generation = epoch.automationEpoch(context).generation
  epoch.beginAutomationRestore(context)
  assert.equal(epoch.currentAutomationEpoch(context, generation), false, 'An awaiting pre-restore task must not commit')
  const nextGeneration = epoch.automationEpoch(context).generation
  assert.equal(epoch.currentAutomationEpoch(context, nextGeneration), false, 'No task may commit during restore')
  epoch.resetGeneratedAutomationWork(context)
  assert.equal(fs.existsSync(path.join(directory, 'read-download-cleanup.v1.json')), false)
  epoch.finishAutomationRestore(context)
  assert.equal(epoch.currentAutomationEpoch(context, generation), false, 'The old task remains invalid after restore')
  assert.equal(epoch.currentAutomationEpoch(context, nextGeneration), true)

  const contract = load('BackgroundMaintenanceContract')
  const oldChange = { before: { id: 'book', updatedAt: 1 }, after: { id: 'book', updatedAt: 2 } }
  const newChange = { before: { id: 'book', updatedAt: 1 }, after: { id: 'book', updatedAt: 3 } }
  const older = { generation: 1, summary: { checkedAt: 10, results: [{ comicId: 'book', status: 'updated' }] }, changes: [oldChange] }
  const newer = { generation: 1, summary: { checkedAt: 20, results: [{ comicId: 'book', status: 'updated' }] }, changes: [newChange] }
  for (const journals of [[older, newer], [newer, older]]) {
    const observations = contract.latestBackgroundObservations(journals)
    assert.equal(observations.length, 1)
    assert.equal(observations[0].change.after.updatedAt, 3, 'Multiple background runs merge the newest result once per book')
  }
  const liveLibrary = JSON.stringify({ comics: [comic] })
  const liveProgress = JSON.stringify({ current: 'chapter-3' })
  const liveQueue = JSON.stringify({ schemaVersion: 1, entries: [] })
  fs.mkdirSync(path.join(directory, 'downloads'))
  fs.writeFileSync(path.join(directory, 'library-store.v1.json'), liveLibrary)
  fs.writeFileSync(path.join(directory, 'reader-sessions.v1.json'), liveProgress)
  fs.writeFileSync(path.join(directory, 'downloads/queue.v1.json'), liveQueue)
  fs.writeFileSync(path.join(directory, contract.BACKUP_SNAPSHOT), JSON.stringify({
    libraryStore: JSON.stringify({ comics: [] }), readingProgress: 'old', downloadQueue: 'old', settings: { retained: true },
  }))
  fs.writeFileSync(path.join(directory, contract.MAINTENANCE_CONFIG_FILE), JSON.stringify({
    backup: { enabled: true, backgroundEnabled: true, lastRunAt: 0, intervalHours: 24, directoryUri: 'test://backup', retentionCount: 5 },
  }))
  let produced
  const packages = [{ sourceId: 'source', version: '1' }]
  const worker = load('BackgroundMaintenanceWorker', {
    './ComicPersonalization': { exportComicCovers: async () => [] },
    '@kit.AbilityKit': { appManager: { getRunningProcessInformation: async () => [] } },
    '@kit.CoreFileKit': { fileIo: { accessSync: fs.existsSync, readTextSync: p => fs.readFileSync(p, 'utf8'),
      access: async p => fs.existsSync(p), readText: p => fs.promises.readFile(p, 'utf8') } },
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {}, warn() {} } },
    './LibraryStore': { InMemoryLibraryStore: class {} },
    './LibraryPersistence': { LIBRARY_STORE_PERSISTENCE_FILE_NAME: 'library-store.v1.json' },
    './ReaderSessionStore': { READER_PROGRESS_PERSISTENCE_FILE_NAME: 'reader-sessions.v1.json' },
    './OfflineDownloadStore': { OFFLINE_DOWNLOAD_ROOT_DIR_NAME: 'downloads' },
    './OfflineDownloadQueueStore': { OFFLINE_DOWNLOAD_QUEUE_FILE_NAME: 'queue.v1.json' },
    '../common/Constants': { KOMA_BUNDLE_NAME: 'com.honjow.koma' },
    './AutomationStateEpoch': epoch,
    './SourceChapterIdentityGuard': {}, './LibraryAutomationPolicy': policy,
    './AutomaticUpdateConditions': {}, './LibraryUpdateService': {}, './LibraryUpdateResultStore': {},
    './BackupAutomaticDirectory': { writeAutomaticBackupToDirectory: async (_uri, value) => { produced = JSON.parse(value) } },
    './AppFileTextPersistence': { writeAppTextFile: (p, value) => fs.writeFileSync(p, value) },
    './RemoteServerStore': { RemoteServerStore: class {} },
    '../sourceRuntime/SourceRuntimeAppRegistry': { exportInstalledSourcePackages: () => packages },
    './LocalLibraryMetadataService': { exportLocalLibraryMetadataBackupEntries: value => {
      assert.equal(value, liveLibrary); return []
    } },
    './BackgroundMaintenanceContract': contract,
  })
  await worker.executeBackgroundMaintenance(context, contract.BACKUP_BACKGROUND_WORK_ID, {}, () => false)
  assert.equal(produced.libraryStore, liveLibrary, 'A UI template is never exported as an empty library')
  assert.equal(produced.readingProgress, liveProgress)
  assert.equal(produced.downloadQueue, liveQueue)
  assert.deepEqual(produced.sourcePackages, packages, 'Package encoding belongs to the background execution owner')
  assert.deepEqual(produced.settings, { retained: true }, 'UI-owned settings survive background assembly')
  fs.rmSync(directory, { recursive: true })
  console.log('Production automation policy, serialized preferences, save rollback and deferred cleanup passed; device paths remain unverified.')
}
main().catch(error => { console.error(error); process.exitCode = 1 })
