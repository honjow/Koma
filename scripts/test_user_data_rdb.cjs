const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const test = require('node:test')
const { createHash } = require('node:crypto')
const { createRdbPort } = require('./user_data_rdb_fixture.cjs')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture(preferences = new Map(), runtimeImports = new Map(), rdb = createRdbPort()) {
  const modules = new Map()
  function load(name) {
    if (modules.has(name)) return modules.get(name)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model', name + '.ets'), 'utf8')
      .replace(/^@ObservedV2\s*$/gm, '').replace(/@Trace /g, '')
    const js = ts.transpileModule(source, { compilerOptions: {
      target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
    } }).outputText
    const exports = {}
    new Function('exports', 'require', js)(exports, dependency => {
      if (runtimeImports.has(dependency)) return runtimeImports.get(dependency)
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
      if (dependency === '@kit.ArkTS' || dependency === '@kit.CryptoArchitectureKit') return {}
      if (dependency === '../sourceRuntime/SourceSubscriptionStorage') return {}
      if (dependency.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(name), dependency)))
      throw new Error('Unexpected import ' + dependency)
    })
    modules.set(name, exports)
    return exports
  }
  return { load, failNextCommit: rdb.failNextCommit, close: rdb.close }
}

const plain = value => JSON.parse(JSON.stringify(value))

test('the first category migration keeps memberships when reads see only committed aliases', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-category-upgrade-'))
  const rdb = createRdbPort(path.join(directory, 'Koma.db'))
  const env = fixture(new Map(), new Map([
    ['@kit.ArkTS', { util: { TextEncoder: class { encodeInto(value) { return Buffer.from(value) } } } }],
    ['@kit.CryptoArchitectureKit', { cryptoFramework: { createMd() {
      const hash = createHash('sha256')
      return { updateSync: ({ data }) => hash.update(data), digestSync: () => ({ data: hash.digest() }) }
    } } }],
  ]), rdb)
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const store = await openUserDataDatabase({ filesDir: directory })
    const committed = await rdb.relationalStore.getRdbStore({ filesDir: directory + '/read' }, { name: 'Koma.db' })
    const library = new LibraryRdbStorage({ ...store, querySqlSync: committed.querySqlSync })
    const categoryId = 'custom_1795348835811_1'
    const workId = 'com.rumanhua.koma:/work/'
    await library.migrate({
      schemaVersion: 1,
      customCategories: [{ id: categoryId, name: '国漫', sortOrder: 0, createdAt: 1, updatedAt: 1 }],
      comics: [{ id: workId, title: 'Work', sourceKind: 'private_library', sourceRuntimeId: 'com.rumanhua.koma',
        remoteResourceId: '/work/', categoryIds: [categoryId], chapters: [] }],
    })

    library.migrateCategoryIds()
    const after = library.read()
    assert.equal(after.customCategories.length, 1)
    assert.notEqual(after.customCategories[0].id, categoryId)
    assert.deepEqual(after.comics[0].categoryIds, [after.customCategories[0].id])
    library.migrateCategoryIds()
    assert.deepEqual(library.read(), after)
  } finally {
    env.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('a synced removal refreshes only the affected work when its membership row is already gone', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const cloud = env.load('../deviceSync/HuaweiCloudBusinessTables')
    const store = await openUserDataDatabase({ filesDir: '/cloud-membership-delete' })
    const library = new LibraryRdbStorage(store)
    const affected = 'com.rumanhua.koma:/affected/'
    const other = 'com.rumanhua.koma:/other/'
    const sharedWork = id => ({
      id, title: id, sourceKind: 'private_library', sourceRuntimeId: 'com.rumanhua.koma',
      remoteResourceId: id.slice(id.indexOf(':') + 1), categoryIds: ['reading'], chapters: [],
    })
    await library.migrate({
      schemaVersion: 1, comics: [sharedWork(affected), sharedWork(other)],
      customCategories: [{ id: 'reading', name: 'Reading', sortOrder: 0, createdAt: 1, updatedAt: 1 }],
    })
    assert.deepEqual(library.readWork(affected).categoryIds, ['reading'])
    await cloud.prepareCloudWorkDeletions(store)
    const row = store.querySqlSync('SELECT rowid FROM shelf_memberships WHERE comic_id = ?', [affected])
    assert.equal(row.goToNextRow(), true)
    const rowId = row.getLong(0)
    row.close()
    await cloud.startCloudWorkDeletions(store)
    await store.execute('DELETE FROM shelf_memberships WHERE rowid = ?', [rowId])
    await cloud.stopCloudWorkDeletions(store)
    const change = { table: 'shelf_memberships', inserted: [], updated: [], deleted: [rowId] }

    // Exercise publication with and without the delayed ArkData callback.
    for (const changes of [[], [change]]) {
      const effects = await cloud.cloudBusinessChanges(store, changes, ['shelf'])
      assert.deepEqual(Array.from(effects.groups), ['shelf'])
      assert.deepEqual(Array.from(effects.shelfWorks), [affected])
      const edits = library.cloudShelfEdits(Array.from(effects.shelfWorks), effects.categories, effects.smartCategories)
      assert.deepEqual(edits.after.works.map(work => [work.id, work.categoryIds]), [[affected, []]])
    }
    const effects = await cloud.cloudBusinessChanges(store, [change], ['shelf'])
    await cloud.acknowledgeCloudWorkDeletions(store, effects.deletedWorkSerial)
    assert.deepEqual(Array.from((await cloud.cloudBusinessChanges(store, [change], ['shelf'])).groups), [])
    assert.deepEqual(library.readWork(other).categoryIds, ['reading'])
  } finally {
    env.close()
  }
})

test('cloud category changes publish valid rules and clear only memberships in the deleted category', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/cloud-category-delete' })
    const library = new LibraryRdbStorage(store)
    const deleted = 'custom_deleted'
    const kept = 'custom_kept'
    const shared = 'com.rumanhua.koma:/category-delete/'
    const category = id => ({ id, name: id, sortOrder: 0, createdAt: 1, updatedAt: 1 })
    await library.migrate({
      schemaVersion: 1,
      comics: [
        { id: shared, title: 'Shared work', sourceRuntimeId: 'com.rumanhua.koma', sourceKind: 'private_library',
          remoteResourceId: '/category-delete/', chapters: [], categoryIds: [deleted, kept] },
        { id: 'device-book', chapters: [], categoryIds: [deleted] },
        { id: 'untouched', chapters: [], categoryIds: [kept] },
      ],
      customCategories: [category(deleted), category(kept)],
    })
    await store.execute('DELETE FROM shelf_categories WHERE category_id = ?', [deleted])
    const edits = library.cloudShelfEdits([], true, false, [deleted])
    assert.deepEqual(edits.comicIds.sort(), [shared, 'device-book'].sort())
    assert.deepEqual(library.readWork(shared).categoryIds, [kept])
    assert.deepEqual(library.readWork('device-book').categoryIds, [])
    assert.deepEqual(library.readWork('untouched').categoryIds, [kept])

    const smart = 'smart:ede5a39b-c6a8-459a-b346-2b87c1405302'
    await store.execute('INSERT INTO shelf_smart_categories (category_id, name, sort_order, created_at, updated_at) ' +
      'VALUES (?, ?, ?, ?, ?)', [smart, 'Smart', 0, 1, 1])
    assert.deepEqual(library.cloudShelfEdits([], false, true).after.smartCategories, [])
    await store.execute('INSERT INTO shelf_smart_category_filters (category_id, filter_order, method, excluded) ' +
      'VALUES (?, ?, ?, ?)', [smart, 0, 'downloaded', 0])
    assert.equal(library.cloudShelfEdits([], false, true).after.smartCategories[0].id, smart)
    await store.execute('DELETE FROM shelf_smart_category_filters WHERE category_id = ?', [smart])
    assert.deepEqual(library.cloudShelfEdits([], false, true).after.smartCategories, [])
    assert.deepEqual(library.read().smartCategories, [])
  } finally {
    env.close()
  }
})

test('one old smart category keeps its rules and view settings when its WebDAV and cloud IDs meet', async () => {
  const env = fixture(new Map(), new Map([
    ['@kit.ArkTS', { util: { TextEncoder: class { encodeInto(value) { return Buffer.from(value) } } } }],
    ['@kit.CryptoArchitectureKit', { cryptoFramework: { createMd() {
      const hash = createHash('sha256')
      return { updateSync: ({ data }) => hash.update(data), digestSync: () => ({ data: hash.digest() }) }
    } } }],
  ]))
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/smart-category-legacy-identity' })
    const library = new LibraryRdbStorage(store)
    const legacy = 'smart:1794493520614'
    const canonical = 'smart:220a2111-e44f-5bc3-6982-42a8d386326a'
    const sourceRule = { method: 'source', value: 'source:net.bilimanga.koma', exclude: false }
    const strategy = { categoryId: legacy, sortBy: 'title', readState: 'all', updatedAt: 2 }
    await library.migrate({ schemaVersion: 1, comics: [],
      smartCategories: [{ id: canonical, name: '哔哩', sortOrder: 0, createdAt: 1, updatedAt: 1, filters: [sourceRule] }],
      categoryDisplayStrategies: [strategy],
    })
    await store.execute('INSERT INTO shelf_smart_categories VALUES (?, ?, ?, ?, ?, ?)', [legacy, 0, '哔哩', 0, 1, 2])
    assert.equal(library.cloudShelfEdits([], false, true).after.smartCategories[0].id, canonical)
    await store.execute('INSERT INTO shelf_smart_category_filters VALUES (?, ?, ?, ?, ?)',
      [legacy, 0, sourceRule.method, sourceRule.value, 0])
    const resultImage = library.cloudShelfEdits([], false, true).after
    const merged = resultImage.smartCategories
    assert.deepEqual(merged.map(category => [category.id, category.name, category.filters]), [[canonical, '哔哩', [sourceRule]]])
    assert.equal(resultImage.displayStrategies[0].categoryId, canonical)
    assert.equal(resultImage.displayStrategies[0].sortBy, 'title')
    const result = await store.querySql('SELECT category_id FROM shelf_smart_categories ORDER BY category_id')
    try {
      assert.equal(result.goToNextRow(), true)
      assert.equal(result.getString(0), canonical)
      assert.equal(result.goToNextRow(), false)
    } finally {
      result.close()
    }
    library.migrateCategoryIds()
    assert.deepEqual(library.read().smartCategories, merged)
  } finally {
    env.close()
  }
})

test('a downloaded work with no shared URL can be loaded again after restarting the shelf', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/cloud-shelf-reopen' })
    const library = new LibraryRdbStorage(store)
    await library.migrate({ schemaVersion: 1, comics: [] })
    const source = 'com.rumanhua.koma'
    const work = '/downloaded-work/'
    const comicId = `${source}:${work}`
    await store.execute('INSERT INTO shelf_works (comic_id, source_runtime_id, remote_resource_id, title) VALUES (?, ?, ?, ?)',
      [comicId, source, work, 'Downloaded work'])

    const edits = library.cloudShelfEdits([comicId], false, false)
    assert.equal(edits.after.works[0].sourcePath, work)
    const reopened = new LibraryRdbStorage(store).read()
    assert.equal(reopened.comics[0].sourcePath, work)
    assert.equal(reopened.comics[0].remoteResourceId, work)
  } finally {
    env.close()
  }
})

test('saving reader statistics keeps downloaded positions without recent history in their existing scope', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/cloud-reader-history-removed' })
    const reader = new ReaderRdbStorage(store)
    const comicId = 'com.utifa.koma:utifa:1413'
    const chapterId = 'utifa-read:1413:8810'
    await store.execute('INSERT INTO reader_current_positions (comic_id, chapter_id, page_index) VALUES (?, ?, 28)',
      [comicId, chapterId])
    await store.execute('INSERT INTO reader_chapter_states (comic_id, chapter_id, has_position, page_index) VALUES (?, ?, 1, 28)',
      [comicId, chapterId])
    const snapshot = reader.read()
    const local = { ...snapshot.chapters[0], chapterId: 'private-chapter', position: undefined }
    snapshot.chapters.push(local)
    reader.save(snapshot)

    for (const table of ['reader_current_positions', 'reader_chapter_states']) {
      const shared = await store.querySql('SELECT chapter_id, page_index FROM ' + table + ' WHERE comic_id = ?', [comicId])
      assert.equal(shared.goToNextRow(), true)
      assert.equal(shared.getString(0), chapterId)
      assert.equal(shared.getLong(1), 28)
      assert.equal(shared.goToNextRow(), false)
      shared.close()
    }
    const localChapter = await store.querySql('SELECT chapter_id FROM reader_chapter_states_local WHERE comic_id = ?', [comicId])
    assert.equal(localChapter.goToNextRow(), true)
    assert.equal(localChapter.getString(0), local.chapterId)
    localChapter.close()
  } finally {
    env.close()
  }
})

test('retaining a newer page does not restore deleted source history', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/cloud-history-delete' })
    const reader = new ReaderRdbStorage(store)
    const comicId = 'com.rumanhua.koma:/history-delete/'
    const chapterId = 'chapter'
    const progress = { comicId, chapterId, pageIndex: 3, totalPages: 8, progressRatio: 0.5, completed: false, updatedAt: 200 }
    const history = { comicId, sourceId: 'com.rumanhua.koma', mangaId: '/history-delete/', title: 'Test', chapterId }
    const before = { progress: [progress], sourceHistory: [history], chapters: [{
      comicId, chapterId, position: progress, sourceIdentity: { source: 'com.rumanhua.koma', work: '/history-delete/' },
      isRead: false, bookmarked: true, updatedAt: 200,
    }] }
    await reader.migrate(before)
    await store.execute('UPDATE reader_current_positions SET page_index = 1, saved_at = 100 WHERE comic_id = ?', [comicId])
    await store.execute('DELETE FROM reader_source_history WHERE comic_id = ?', [comicId])
    const scope = [{ comicId, chapterIds: [chapterId] }]
    const reading = reader.applyCloudReading(scope, before)
    assert.equal(reading.progress[0].pageIndex, 3)
    assert.equal(reading.chapters[0].bookmarked, true)
    assert.deepEqual(reading.sourceHistory, [])
    assert.deepEqual(reader.readSyncEdits(scope).sourceHistory, [])
  } finally {
    env.close()
  }
})

test('cloud publication drains late and partially successful changes without another transfer', async t => {
  const env = fixture(new Map(), new Map([
    ['@kit.AbilityKit', {}],
    ['./DeviceSyncOwners', {}],
    ['./DeviceSyncStorage', {}],
    ['../model/ReaderSessionStore', {}],
    ['../model/ReaderPreferencesStore', {}],
    ['../model/SearchHistoryStore', { SearchHistoryStore: class { async applyCloudTermRemovals() {} } }],
    ['../model/SourceLibraryComic', {}],
    ['../sourceRuntime/SourceIndexService', {}],
    ['../viewmodel/SourcePackageManagerCache', {}],
    ['../diagnostics/DiagnosticLogger', { DiagnosticLogger: { info() {}, warn() {}, exception() {} } }],
  ]))
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const { prepareCloudWorkDeletions } = env.load('../deviceSync/HuaweiCloudBusinessTables')
    const { appHuaweiCloudSync: sync } = env.load('../deviceSync/HuaweiCloudSync')
    const context = { filesDir: '/cloud-publication' }
    const store = await openUserDataDatabase(context)
    const library = new LibraryRdbStorage(store)
    const id = 'com.rumanhua.koma:/publication/'
    const categoryId = 'custom_publication'
    const work = { id, title: 'Test work', sourceKind: 'private_library', sourceRuntimeId: 'com.rumanhua.koma',
      remoteResourceId: '/publication/', chapters: [] }
    await library.migrate({ schemaVersion: 1, comics: [work],
      customCategories: [{ id: categoryId, name: 'Test', sortOrder: 0, createdAt: 1, updatedAt: 1 }] })
    await prepareCloudWorkDeletions(store)
    Object.assign(sync, { context, storage: { update: action => action({}) }, selection: () => ['shelf'],
      distributedStore: async () => store })
    sync.view.enabled = true
    sync.view.available = true
    const nativeConfiguration = []
    sync.configureCloudTables = async (_store, _tables, enabled) => { nativeConfiguration.push(enabled) }

    let visible = library.readWork(id)
    let published
    sync.attachPublisher((_groups, _reading, shelf) => {
      if (!shelf?.comicIds.includes(id)) return
      visible = shelf.after.works.find(comic => comic.id === id)
      published?.()
    })
    sync.transfer = async (_store, tables) => {
      if (tables.includes('shelf_works')) await store.execute('DELETE FROM shelf_works WHERE comic_id = ?', [id])
    }
    await sync.sync()
    assert.equal(library.readWork(id), undefined)
    assert.equal(visible.id, id)
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('late change was not published')), 1000)
      published = () => { clearTimeout(timer); resolve() }
      sync.receiveChanges([{ table: 'shelf_works', inserted: [], updated: [], deleted: [id] }])
    })
    assert.equal(visible, undefined)

    library.saveExistingWorks([{ ...work, categoryIds: [categoryId] }])
    visible = library.readWork(id)
    assert.deepEqual(visible.categoryIds, [categoryId])
    sync.transfer = async (_store, tables) => {
      if (!tables.includes('shelf_memberships')) return
      await store.execute('DELETE FROM shelf_memberships WHERE comic_id = ?', [id])
      throw Error('partial')
    }
    await sync.sync()
    assert.deepEqual(visible.categoryIds, [])
    assert.equal(sync.view.error, 'partial')

    let stopped = 0
    let finish
    let notifyStarted
    const started = new Promise(resolve => { notifyStarted = resolve })
    sync.transfer = async () => new Promise(resolve => { finish = resolve; notifyStarted() })
    store.stopCloudSync = async () => { stopped++; finish() }
    const active = sync.sync()
    await started
    await sync.setEnabled(false)
    finish()
    await active
    assert.equal(sync.view.enabled, false)
    assert.equal(stopped, 1)
    assert.equal(nativeConfiguration.at(-1), false)

    const { BackupRestoreActivity } = env.load('../model/BackupRestoreActivity')
    delete sync.transfer
    sync.view.enabled = true
    sync.selection = () => ['search-history']
    t.mock.timers.enable({ apis: ['setTimeout'] })
    try {
      for (const code of [0, 2, 4]) {
        let notifyNative
        const nativeStarted = new Promise(resolve => { notifyNative = resolve })
        store.cloudSync = async (_mode, _tables, callback) => { notifyNative(callback) }
        const receiving = sync.sync()
        const completeNative = await nativeStarted
        const previousSuccess = sync.view.lastSuccess
        try {
          assert.throws(() => BackupRestoreActivity.beginRestore(), /backup_restore_busy/)
          t.mock.timers.tick(240001)
          await new Promise(resolve => setImmediate(resolve))
          assert.equal(sync.view.busy, true)
          assert.equal(sync.view.error, '')
          assert.equal(sync.sync(), receiving)
          assert.throws(() => BackupRestoreActivity.beginRestore(), /backup_restore_busy/)
          await assert.rejects(BackupRestoreActivity.runDeviceSyncCommit(async () => {}), /sync_local_busy/)
        } finally {
          completeNative({ schedule: 2, code })
          await receiving
        }
        assert.equal(sync.view.busy, false)
        assert.equal(sync.view.error, code === 0 ? '' : String(code))
        assert.equal(await BackupRestoreActivity.runDeviceSyncCommit(async () => 'committed'), 'committed')
        if (code === 0) assert.ok(sync.view.lastSuccess > 0)
        else assert.equal(sync.view.lastSuccess, previousSuccess)
      }
    } finally {
      t.mock.timers.reset()
    }
    BackupRestoreActivity.beginRestore()
    BackupRestoreActivity.finishRestore()
  } finally {
    env.close()
  }
})

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

test('a cloud page update discards the receiver’s previous page anchor', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const { readingProgressPageIndex } = env.load('ComicModels')
    const store = await openUserDataDatabase({ filesDir: '/cloud-page-anchor' })
    const reader = new ReaderRdbStorage(store)
    const position = { comicId: 'source:work', chapterId: 'chapter', pageId: 'old-image', pageIndex: 1,
      totalPages: 5, progressRatio: 0.4, completed: false, updatedAt: 100 }
    const chapter = { comicId: position.comicId, chapterId: position.chapterId, position,
      sourceIdentity: { source: 'source', work: 'work' }, isRead: false, bookmarked: true, updatedAt: 100 }
    const before = { progress: [position], chapters: [chapter], sourceHistory: [] }
    const scope = [{ comicId: position.comicId, chapterIds: [position.chapterId] }]
    await reader.migrate(before)

    for (const table of ['reader_current_positions', 'reader_chapter_states']) {
      store.executeSync('UPDATE ' + table + ' SET page_index = ?, saved_at = ? WHERE comic_id = ?', [3, 200, position.comicId])
    }
    const received = reader.applyCloudReading(scope, before)
    const pages = ['first', 'old-image', 'middle', 'new-image', 'last']
    assert.equal(readingProgressPageIndex(received.chapters[0].position, pages.length, pages), 3)
    const reopened = new ReaderRdbStorage(store).readSyncEdits(scope)
    assert.equal(reopened.progress[0].pageIndex, 3)
    assert.equal(reopened.progress[0].pageId, undefined)
    assert.equal(reopened.chapters[0].position.pageId, undefined)
    assert.equal(reopened.chapters[0].bookmarked, true)
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
    const delta = { progress: [position], sourceHistory, chapters: [turn], syncPositions: pending, syncActions: initial.syncActions }
    env.failNextCommit()
    assert.throws(() => reader.save(delta, [turn]), /interrupted write/)
    assert.deepEqual(plain(reader.read()), initial)
    reader.save(delta, [turn])
    const afterTurn = { ...initial, progress: [position], sourceHistory, chapters: [oldChapter, turn], syncPositions: pending }
    assert.deepEqual(plain(reader.read()), afterTurn)
    // A queued turn in a different chapter persists its own position only.
    const oldChapterTurn = { ...oldChapter, position: { ...oldPosition, pageIndex: 4, updatedAt: 150 }, updatedAt: 150 }
    reader.save({ progress: [], sourceHistory: [], chapters: [oldChapterTurn], syncPositions: pending,
      syncActions: initial.syncActions }, [oldChapterTurn])
    assert.deepEqual(plain(reader.read()).progress, [position])
    assert.deepEqual(plain(reader.read()).chapters, [oldChapterTurn, turn])
    reader.save({ progress: [], sourceHistory: [], chapters: [oldChapter], syncPositions: pending,
      syncActions: initial.syncActions }, [oldChapter])
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
