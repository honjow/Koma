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
      if (dependency === '@kit.CoreFileKit') return { fileIo: fs }
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
    const { PreferenceColumnRows } = env.load('PreferenceColumnRows')
    const database = await openUserDataDatabase({ filesDir: '/keyed' })
    const domain = new PreferenceColumnRows(database, 'work-settings', '')
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
    const reopened = new PreferenceColumnRows(database, 'work-settings', '')
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
    const chapter = (comicId, id) => ({ comicId, id, pages: [] })
    const original = { schemaVersion: 1, customCategories: [
      { id: 'hidden', name: 'Private', sortOrder: 0, createdAt: 1, updatedAt: 2, isPrivate: true },
    ], comics: [{ id: 'a', categoryIds: ['hidden'], chapters: [chapter('a', 'a-1'), chapter('a', 'a-2')] },
      { id: 'b', chapters: [chapter('b', 'b-1')] }], smartCategories: [],
    syncShelfMoves: [{ space: 'original', source: 'source', work: 'old-work' }] }
    env.failNextCommit()
    await assert.rejects(library.migrate(original), /interrupted write/)
    assert.equal(await library.migrated(), false)
    assert.equal(library.read(), undefined)
    await library.migrate(original)
    assert.deepEqual(plain(library.read()), original)
    const edited = { id: 'a', categoryIds: [], chapters: [{ ...chapter('a', 'a-1'), title: 'edited' }] }
    library.saveExistingWorks([edited])
    const changed = library.read()
    assert.deepEqual(plain(changed.comics[0]), edited)
    assert.deepEqual(plain(changed.comics[1]), original.comics[1])
    assert.deepEqual(plain(changed.customCategories), original.customCategories)
    const memberships = [{ comicId: 'a', categoryIds: ['hidden'], updatedAt: 5 }, { comicId: 'b', updatedAt: 6 }]
    env.failNextCommit()
    assert.throws(() => library.saveMemberships(memberships), /interrupted write/)
    assert.deepEqual(library.read(), changed)
    library.saveMemberships(memberships)
    const reassigned = plain(library.read())
    assert.deepEqual(reassigned.comics, [
      { ...edited, categoryIds: ['hidden'], updatedAt: 5 }, { ...original.comics[1], updatedAt: 6 },
    ])
    assert.deepEqual(reassigned.customCategories, original.customCategories)
    const inserted = { id: 'c', chapters: [chapter('c', 'c-1')] }
    const edits = { comicIds: ['a', 'b', 'c'], unchangedCatalogs: ['a'],
      before: { present: true, works: [{ ...reassigned.comics[0], chapters: [] }, reassigned.comics[1]], order: ['a', 'b'] },
      after: { present: true, works: [{ ...reassigned.comics[0], coverUri: 'https://example.com/cover.png', chapters: [] }, inserted],
        order: ['c', 'a'], categories: null } }
    edits.before.categories = reassigned.customCategories
    env.failNextCommit()
    assert.throws(() => library.saveSyncEdits(edits, edits.after), /interrupted write/)
    assert.deepEqual(plain(library.read()), reassigned)
    library.saveSyncEdits(edits, edits.after)
    assert.deepEqual(plain(library.read().comics), [inserted, { ...reassigned.comics[0], coverUri: 'https://example.com/cover.png' }])
    assert.equal(library.read().customCategories, undefined)
    library.saveSyncEdits(edits, edits.before)
    library.saveSyncEdits(edits, edits.before)
    assert.deepEqual(plain(library.read()), reassigned)
    library.save(undefined)
    assert.equal(library.read(), undefined)
    assert.equal(await library.migrated(), true)
  } finally {
    env.close()
  }
})

test('reading sync joins saved chapter metadata without loading unrelated shelf works or page contents', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/reading-sync' })
    const library = new LibraryRdbStorage(store)
    const reader = new ReaderRdbStorage(store)
    const chapter = (id, title) => ({ comicId: 'saved', id, title, pages: [{ id: 'page-1' }] })
    await library.migrate({ schemaVersion: 1, comics: [
      { id: 'saved', sourceRuntimeId: 'source', remoteResourceId: 'work', title: 'Saved work',
        coverUri: 'https://example.com/custom', customCoverUri: 'file://local-cover',
        chapters: [chapter('ten', '第10章'), chapter('sixty-six', '第66章'), chapter('sixty-six', '重复标题')] },
      { id: 'unread', sourceRuntimeId: 'source', remoteResourceId: 'unread', title: 'Unrelated work', chapters: [] },
    ] })
    const position = { comicId: 'saved', chapterId: 'sixty-six', pageIndex: 4, totalPages: 16,
      progressRatio: 0.25, completed: false, updatedAt: 100 }
    await reader.migrate({ progress: [position], sourceHistory: [],
      chapters: [{ comicId: 'saved', chapterId: 'sixty-six', position, isRead: false, updatedAt: 100 }],
      readingSessions: [{ comicId: 'saved', chapterId: 'sixty-six', startedAt: 1, endedAt: 100, pagesRead: 4 }] })
    assert.deepEqual(plain(library.readReadingMetadata()), [{
      comicId: 'saved', source: 'source', work: 'work', title: 'Saved work',
      chapterId: 'sixty-six', chapterTitle: '第66章',
    }])
    assert.equal(library.readReadingMetadata('saved', 'ten')[0].chapterTitle, '第10章')
    assert.equal(library.readReadingMetadata('unread')[0].work, 'unread')
    assert.deepEqual(plain(reader.readForSync().progress), [position])
    assert.equal(reader.readForSync().readingSessions, undefined)
    assert.equal(reader.read().readingSessions.length, 1)
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
    const oldPosition = { comicId: 'a', chapterId: 'a-1', pageIndex: 3, totalPages: 10,
      progressRatio: 0.3, completed: false, updatedAt: 100 }
    const oldChapter = { comicId: 'a', chapterId: 'a-1', position: oldPosition, isRead: false, bookmarked: true, updatedAt: 100 }
    const action = { id: 'prior', space: 'space', source: 'source', work: 'a', chapterId: 'a-1',
      edits: [{ key: 'bookmark', kind: 'set', value: 'true', observed: [{ replica: 'other', sequence: 2 }] }] }
    const initial = { progress: [oldPosition],
      sourceHistory: [{ comicId: 'a', sourceId: 'source', mangaId: 'a', title: 'Book', chapterId: 'a-1' }],
      remoteHistory: [],
      chapters: [oldChapter],
      readingSessions: [{ comicId: 'a', chapterId: 'a-1', startedAt: 1, endedAt: 100, pagesRead: 3 }],
      syncActions: [action] }
    await reader.migrate(initial)
    assert.equal(await reader.migrated(), true)
    const position = { ...oldPosition, chapterId: 'a-2', pageIndex: 8, progressRatio: 0.8, updatedAt: 200 }
    const turn = { comicId: 'a', chapterId: 'a-2', position, isRead: false, updatedAt: 200 }
    const pending = [{ id: 'position', space: 'space', source: 'source', work: 'a', comicId: 'a', chapterId: 'a-2',
      page: 8, total: 10, date: 200, complete: false, observedActions: ['prior'],
      positionSeen: [{ replica: 'other', sequence: 2 }], recentSeen: [], recentCleared: [], readSeen: [] }]
    const sourceHistory = [{ ...initial.sourceHistory[0], chapterId: 'a-2', chapterTitle: 'New chapter' }]
    const delta = { progress: [], sourceHistory, chapters: [turn], syncPositions: pending, syncActions: initial.syncActions }
    env.failNextCommit()
    assert.throws(() => reader.save(delta, [turn]), /interrupted write/)
    assert.deepEqual(plain(reader.read()), initial)
    reader.save(delta, [turn])
    const afterTurn = { ...initial, progress: [position], sourceHistory, chapters: [oldChapter, turn], syncPositions: pending }
    assert.deepEqual(plain(reader.read()), afterTurn)
    const scope = [{ comicId: 'a', chapterIds: ['a-2'] }]
    const before = reader.readSyncEdits(scope)
    assert.deepEqual(plain(before.chapters), [turn])
    const received = { ...before, chapters: [{ ...turn, bookmarked: true }], syncPositions: [] }
    env.failNextCommit()
    assert.throws(() => reader.writeSyncEdits(scope, received), /interrupted write/)
    assert.deepEqual(plain(reader.read()), afterTurn)
    reader.writeSyncEdits(scope, received)
    assert.deepEqual(plain(reader.read()), plain({
      ...afterTurn, chapters: [oldChapter, { ...turn, bookmarked: true }], syncPositions: undefined,
    }))
    reader.writeSyncEdits(scope, before)
    assert.deepEqual(plain(reader.read()), afterTurn)
  } finally {
    env.close()
  }
})

test('reading moves from the previously committed database once, even with stale files still available', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const database = await openUserDataDatabase({ filesDir: '/reader-upgrade' })
    database.executeSync('CREATE TABLE reading_works (kind TEXT, comic_id TEXT, payload TEXT)')
    database.executeSync('CREATE TABLE reading_chapter_states (comic_id TEXT, chapter_id TEXT, payload TEXT)')
    database.executeSync('CREATE TABLE reading_local_records (kind TEXT, list_order INTEGER, payload TEXT)')
    database.executeSync('INSERT INTO local_data_migrations (name) VALUES (?)', ['reading-from-json-v1'])
    const progress = { comicId: 'a', chapterId: 'a-5', pageIndex: 7, totalPages: 20,
      progressRatio: 0.35, updatedAt: 10, completed: false }
    database.executeSync('INSERT INTO reading_works (kind, comic_id, payload) VALUES (?, ?, ?)',
      ['progress', 'a', JSON.stringify(progress)])
    const reading = new ReaderRdbStorage(database)
    const stale = { progress: [{ ...progress, pageIndex: 1 }], chapters: [], sourceHistory: [] }
    env.failNextCommit()
    await assert.rejects(reading.migrate(stale), /interrupted write/)
    assert.equal(reading.migrated(), false)
    assert.deepEqual(reading.read().progress, [])
    await reading.migrate(stale)
    assert.deepEqual(plain(reading.read().progress), [progress])
    reading.save({ progress: [], chapters: [], sourceHistory: [] })
    await new ReaderRdbStorage(database).migrate(stale)
    assert.deepEqual(reading.read().progress, [])
  } finally {
    env.close()
  }
})
