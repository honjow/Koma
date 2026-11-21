const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const { createRdbPort } = require('./user_data_rdb_fixture.cjs')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture(preferences = new Map()) {
  const rdb = createRdbPort()
  const modules = new Map()
  function load(name) {
    if (modules.has(name)) return modules.get(name)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model', name + '.ets'), 'utf8')
    const js = ts.transpileModule(source, { compilerOptions: {
      target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
    } }).outputText
    const exports = {}
    new Function('exports', 'require', js)(exports, dependency => {
      if (dependency === '@kit.ArkData') return {
        relationalStore: rdb.relationalStore,
        preferences: { getPreferences: async (_context, name) => {
          const values = preferences.get(name) ?? {}
          return {
            has: async key => Object.hasOwn(values, key),
            get: async (key, fallback) => values[key] ?? fallback,
            getAll: async () => values,
          }
        } },
      }
      if (dependency === './TrackerModels') return { TRACKER_REMOTE_PROVIDER_IDS: ['anilist'] }
      if (dependency === '../sourceRuntime/SourceSubscriptionStorage') return {}
      if (dependency.startsWith('./')) return load(dependency.slice(2))
      throw new Error('Unexpected import ' + dependency)
    })
    modules.set(name, exports)
    return exports
  }
  return { load, failNextCommit: rdb.failNextCommit, close: rdb.close }
}

const plain = value => JSON.parse(JSON.stringify(value))

test('keyed migration retries atomically and a cleared domain never reloads retained legacy values', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { UserKeyedRecords } = env.load('UserKeyedRecords')
    const database = await openUserDataDatabase({ filesDir: '/keyed' })
    const domain = new UserKeyedRecords(database, 'work-settings')
    const legacy = new Map([['book-a', '"double_page"'], ['book-b', '"vertical_page"']])
    env.failNextCommit()
    assert.throws(() => domain.migrate(legacy), /interrupted write/)
    assert.equal(domain.isMigrated(), false)
    assert.equal(domain.entries(), undefined)
    domain.migrate(legacy)
    domain.put('book-a', '"single_page"')
    assert.equal(domain.get('book-a'), '"single_page"')
    assert.equal(domain.get('book-b'), '"vertical_page"')
    domain.replace(new Map())
    const reopened = new UserKeyedRecords(database, 'work-settings')
    reopened.migrate(legacy)
    assert.deepEqual(reopened.entries(), new Map())
    reopened.replace(undefined)
    assert.equal(reopened.entries(), undefined)
    assert.equal(reopened.isMigrated(), true)
  } finally {
    env.close()
  }
})

test('tracker work retains retry details across migration and a rejected progress update', async () => {
  const saved = { providerId: 'anilist', comicId: 'a', chapterId: 'c1', chapterIds: ['c1'],
    pageIndex: 3, totalPages: 8, progressRatio: 0.5, completed: false, providerProgress: 1,
    attempts: 2, firstQueuedAt: 100, updatedAt: 120, lastReason: 'provider_failed', trigger: 'manual' }
  const context = { filesDir: '/tracker' }
  const env = fixture(new Map([['koma_tracker_pending_sync_v1', { 'tracker.pendingProgressQueue': JSON.stringify([saved]) }]]))
  try {
    const { TrackerPendingSyncStore } = env.load('TrackerPendingSyncStore')
    const queue = new TrackerPendingSyncStore(context)
    assert.deepEqual(plain(await queue.loadPendingProgress()), [saved])
    const next = { comicId: 'a', chapterId: 'c1', pageIndex: 4, totalPages: 8, progressRatio: 0.625, completed: false }
    env.failNextCommit()
    await assert.rejects(queue.enqueueFailedProgress('anilist', next, ['c1'], 1, 'provider_failed', 130), /interrupted write/)
    assert.deepEqual(plain(await queue.loadPendingProgress()), [saved])
    const written = await queue.enqueueFailedProgress('anilist', next, ['c1'], 1, 'provider_failed', 130)
    assert.equal(written.attempts, 3)
    assert.equal(written.firstQueuedAt, 100)
    assert.equal(await queue.removeProgress('anilist', 'a', 'c1'), 1)
    assert.deepEqual(await new TrackerPendingSyncStore(context).loadPendingProgress(), [])
  } finally {
    env.close()
  }
})

test('library import rolls back and retries with all chapter and category relationships intact', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const library = new LibraryRdbStorage(await openUserDataDatabase({ filesDir: '/library' }))
    const original = { schemaVersion: 1, customCategories: [{ id: 'hidden', isPrivate: true }],
      comics: [{ id: 'a', categoryIds: ['hidden'], chapters: [{ id: 'a-1' }, { id: 'a-2' }] },
        { id: 'b', chapters: [{ id: 'b-1' }] }], smartCategories: [], syncShelfMoves: [{ space: 'original' }] }
    env.failNextCommit()
    await assert.rejects(library.migrate(original), /interrupted write/)
    assert.equal(await library.migrated(), false)
    assert.equal(library.read(), undefined)
    await library.migrate(original)
    assert.deepEqual(plain(library.read()), original)
    library.saveExistingWorks([{ id: 'a', categoryIds: [], chapters: [{ id: 'a-1', title: 'edited' }] }])
    const changed = library.read()
    assert.deepEqual(plain(changed.comics[0]), { id: 'a', categoryIds: [], chapters: [{ id: 'a-1', title: 'edited' }] })
    assert.deepEqual(plain(changed.comics[1]), original.comics[1])
    assert.deepEqual(plain(changed.customCategories), original.customCategories)
    library.save(undefined)
    assert.equal(library.read(), undefined)
    assert.equal(await library.migrated(), true)
  } finally {
    env.close()
  }
})

test('page turns atomically update the current and chapter positions with the corresponding pending operations', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const reader = new ReaderRdbStorage(await openUserDataDatabase({ filesDir: '/reader' }))
    const oldPosition = { comicId: 'a', chapterId: 'a-1', pageIndex: 3 }
    const oldChapter = { comicId: 'a', chapterId: 'a-1', position: oldPosition, isRead: false, bookmarked: true }
    const initial = { progress: [oldPosition], sourceHistory: [{ comicId: 'a' }], remoteHistory: [],
      chapters: [oldChapter], readingSessions: [{ comicId: 'a', pagesRead: 3 }], syncActions: [{ id: 'prior' }] }
    await reader.migrate(initial)
    assert.equal(await reader.migrated(), true)
    const position = { comicId: 'a', chapterId: 'a-2', pageIndex: 8 }
    const turn = { comicId: 'a', chapterId: 'a-2', position, isRead: false }
    const pending = [{ comicId: 'a', chapterId: 'a-2', page: 8 }]
    const delta = { progress: [], sourceHistory: [], chapters: [turn], syncPositions: pending, syncActions: initial.syncActions }
    env.failNextCommit()
    assert.throws(() => reader.save(delta, [turn]), /interrupted write/)
    assert.deepEqual(plain(reader.read()), initial)
    reader.save(delta, [turn])
    assert.deepEqual(plain(reader.read()), { ...initial, progress: [position], chapters: [oldChapter, turn], syncPositions: pending })
  } finally {
    env.close()
  }
})
