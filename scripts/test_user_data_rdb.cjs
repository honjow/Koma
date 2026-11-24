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

test('native recovery image restores business rows without a library JSON snapshot', async () => {
  const env = fixture()
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-native-checkpoint-'))
  try {
    const api = env.load('UserDataDatabase')
    const context = { filesDir: directory }
    const database = await api.openUserDataDatabase(context)
    database.executeSync('CREATE TABLE checkpoint_probe (id TEXT PRIMARY KEY, value TEXT)')
    database.executeSync('INSERT INTO checkpoint_probe VALUES (?, ?)', ['keep', 'before'])
    const image = path.join(directory, 'business.rdb')
    await api.backupUserDataDatabase(context, image)
    database.executeSync('UPDATE checkpoint_probe SET value = ?', ['changed'])
    database.executeSync('INSERT INTO checkpoint_probe VALUES (?, ?)', ['temporary', 'remove'])
    await api.restoreUserDataDatabase(context, image)
    const rows = database.querySqlSync('SELECT id, value FROM checkpoint_probe')
    try {
      assert.equal(rows.goToNextRow(), true)
      assert.equal(rows.getString(0), 'keep')
      assert.equal(rows.getString(1), 'before')
      assert.equal(rows.goToNextRow(), false)
    } finally { rows.close() }
  } finally {
    env.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('cold reading reads scoped positions and saves before loading history without dropping old records', async () => {
  const env = fixture(new Map(), new Map([
    ['../sourceRuntime/SourceRuntimeAppRegistry', {}],
    ['../i18n/AppStrings', { AppStrings: {} }],
    ['./SourceRequiredImageDecode', {}],
    ['./ChapterListPreferencesStore', {}],
    ['../diagnostics/DiagnosticLogger', { DiagnosticLogger: { warn() {} } }],
  ]))
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const { PersistentReaderSessionStore } = env.load('ReaderSessionStore')
    const store = await openUserDataDatabase({ filesDir: '/cold-reading' })
    const queries = []
    const reader = new ReaderRdbStorage({
      ...store, querySqlSync: (sql, args) => {
        queries.push(sql)
        return store.querySqlSync(sql, args)
      },
    })
    const position = (comicId, updatedAt) => ({ comicId, chapterId: 'c1',
      pageIndex: 4, totalPages: 10, progressRatio: 0.5, completed: false, updatedAt })
    const savedSession = { comicId: 'keep', chapterId: 'c1', startedAt: 1, endedAt: 2, pagesRead: 1 }
    const action = { id: 'prior', space: 'space', source: 'source', work: 'keep',
      chapterId: 'c1', edits: [{ key: 'bookmark', kind: 'set', value: 'true', observed: [] }] }
    const initial = { progress: [position('keep', 2), position('tie', 2),
      ...Array.from({ length: 33 }, (_, i) => position('hidden-' + i, 10 + i))],
      chapters: [], sourceHistory: [], readingSessions: [savedSession], syncActions: [action] }
    await reader.migrate(initial)
    queries.length = 0
    const session = new PersistentReaderSessionStore({
      load: () => { assert.fail('RDB must not fall back to the legacy snapshot') },
      activityDatabase: () => reader,
      supportsPageTurnWrites: () => true,
      saveSnapshot: (snapshot, turns) => reader.save(snapshot, turns),
    })
    assert.deepEqual(queries, [])
    assert.deepEqual([...session.shelfPositions(['keep', 'absent']).values()], [reader.readPositions(['keep'])[0]])
    assert.deepEqual(session.latestMatchingProgress(row => !row.comicId.startsWith('hidden-'))
      .map(row => row.comicId).sort(), ['keep', 'tie'])
    assert.ok(queries.every(sql => !sql.includes('reader_sessions') && !sql.includes('reader_source_history')))
    session.saveProgress({ ...position('keep', 5), pageIndex: 7 })
    const pending = { ...savedSession, startedAt: 3, endedAt: 4 }
    session.addReadingSession(pending)
    assert.deepEqual(session.listReadingSessions(), [savedSession, pending])
    assert.equal(session.flush(), true)
    assert.equal(reader.readPositions(['keep'])[0].pageIndex, 7)
    assert.equal(reader.readPositions().length, 35)
    assert.deepEqual(reader.readReadingSessions(), [savedSession, pending])
    assert.deepEqual(session.pendingDeviceSyncActions(), [action])
  } finally {
    env.close()
  }
})

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

    const repeated = { ...initial.readingSessions[0], pagesRead: 1 }
    const sessionOnly = { progress: [], chapters: [], sourceHistory: [], readingSessions: [repeated],
      syncPositions: pending, syncActions: initial.syncActions }
    env.failNextCommit()
    assert.throws(() => reader.save(sessionOnly, []), /interrupted write/)
    assert.deepEqual(plain(reader.read()), afterTurn)
    reader.save(sessionOnly, [])
    assert.deepEqual(plain(reader.read()), { ...afterTurn, readingSessions: [...initial.readingSessions, repeated] })
  } finally {
    env.close()
  }
})

test('chapter actions and one history deletion preserve other works and the sync outbox', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const database = await openUserDataDatabase({ filesDir: '/reading-user-actions' })
    const reader = new ReaderRdbStorage(database)
    const target = 'com.rumanhua.koma:/a/'
    const other = 'com.rumanhua.koma:/b/'
    const position = comicId => ({ comicId, chapterId: 'one', pageIndex: 3, totalPages: 10,
      progressRatio: 0.4, completed: false, updatedAt: 100 })
    const source = comicId => ({ comicId, sourceId: 'com.rumanhua.koma', mangaId: comicId.split(':')[1], chapterId: 'one' })
    await reader.migrate({ progress: [position(target), position(other)], sourceHistory: [source(target), source(other)],
      chapters: [{ comicId: other, chapterId: 'one', bookmarked: true, isRead: false, updatedAt: 100 }] })
    const action = { id: 'mark', space: 'space', source: 'com.rumanhua.koma', work: '/a/', chapterId: 'two',
      edits: [{ key: 'bookmark', kind: 'set', value: 'true', observed: [{ replica: 'other', sequence: 2 }] }] }
    const chapter = { comicId: target, chapterId: 'two', bookmarked: true, isRead: true, updatedAt: 200 }
    const edits = { progress: [], sourceHistory: [source(target)], chapters: [chapter], syncActions: [action] }
    const before = plain(reader.read())
    env.failNextCommit()
    assert.throws(() => reader.saveActivityEdits(edits), /interrupted write/)
    assert.deepEqual(plain(reader.read()), before)
    reader.saveActivityEdits(edits)
    const remove = { progress: [], sourceHistory: [], chapters: [], syncActions: [action] }
    const afterChapter = plain(reader.read())
    assert.deepEqual(afterChapter.chapters.find(row => row.comicId === target), chapter)
    env.failNextCommit()
    assert.throws(() => reader.saveActivityEdits(remove, [target]), /interrupted write/)
    assert.deepEqual(plain(reader.read()), afterChapter)
    reader.saveActivityEdits(remove, [target])
    const after = plain(reader.read())
    assert.deepEqual(after.progress, [position(other)])
    assert.deepEqual(after.sourceHistory, [source(other)])
    assert.deepEqual(after.chapters, afterChapter.chapters)
    assert.deepEqual(after.syncActions, [action])
  } finally {
    env.close()
  }
})

test('local shelf edits keep unrelated catalog rows and atomically save the affected memberships', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const database = await openUserDataDatabase({ filesDir: '/scoped-local-shelf' })
    const shelf = new LibraryRdbStorage(database)
    const category = { id: 'old', name: 'Old', createdAt: 1, updatedAt: 1, sortOrder: 0 }
    const works = [{ id: 'original', title: 'Original', categoryIds: ['old'], chapters: [{ id: 'kept', pages: [] }] },
      { id: 'other', title: 'Other', chapters: [{ id: 'unrelated', pages: [] }] }]
    await shelf.migrate({ schemaVersion: 1, comics: works, customCategories: [category] })
    const before = plain(shelf.read())
    assert.deepEqual(shelf.categoryMemberIds('old'), ['original'])
    const categoryId = 'test'
    const added = { id: 'test-work', title: 'Test', categoryIds: [categoryId], chapters: [{ id: 'new', pages: [] }] }
    const edits = { present: true, works: [added], categories: [{ ...category, id: categoryId, name: 'Test' }] }
    const memberships = [{ comicId: 'original', categoryIds: [], updatedAt: 2 }]
    env.failNextCommit()
    assert.throws(() => shelf.saveLocalEdits(edits, [], memberships), /interrupted write/)
    assert.deepEqual(plain(shelf.read()), before)
    shelf.saveLocalEdits(edits, [], memberships)
    assert.deepEqual(shelf.categoryMemberIds('test'), ['test-work'])
    assert.deepEqual(shelf.readWork('original').categoryIds, [])
    assert.deepEqual(plain(shelf.readWork('original').chapters), before.comics[0].chapters)
    assert.deepEqual(plain(shelf.readWork('other')), before.comics[1])
    shelf.saveLocalEdits({ present: true, works: [] }, ['test-work'])
    assert.equal(shelf.readWork('test-work'), undefined)
    assert.deepEqual(shelf.categoryMemberIds('test'), [])
  } finally {
    env.close()
  }
})

test('a repeated chapter discovery keeps its original timestamp and unrelated entries', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { PreferenceColumnRows } = env.load('PreferenceColumnRows')
    const database = await openUserDataDatabase({ filesDir: '/scoped-discoveries' })
    const rows = new PreferenceColumnRows(database, 'koma_library_update_results_v1', 'libraryUpdate.chapterUpdatesJson')
    const discovery = (comicId, discoveredAt) => JSON.stringify({ order: 0, value: { comicId, chapterId: 'one', discoveredAt } })
    rows.migrate(new Map([['["a","one"]', discovery('a', 10)]]))
    const inserted = rows.prependNewOrderedRecords(new Map([
      ['["b","one"]', discovery('b', 20)], ['["a","one"]', discovery('a', 20)],
    ]))
    assert.deepEqual(Array.from(inserted), ['["b","one"]'])
    assert.equal(JSON.parse(rows.get('["a","one"]')).value.discoveredAt, 10)
    assert.ok(JSON.parse(rows.get('["b","one"]')).order < JSON.parse(rows.get('["a","one"]')).order)
  } finally {
    env.close()
  }
})

test('first Mihon catalog commits the shelf link and reading position together', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/mihon-first-catalog' })
    const queries = []
    const library = new LibraryRdbStorage({ ...store, querySqlSync: (sql, args) => {
      queries.push(sql)
      return store.querySqlSync(sql, args)
    } })
    const reader = new ReaderRdbStorage(store)
    const original = 'mihon:old'
    const online = 'com.rumanhua.koma:/new/'
    const record = { id: original, sourceName: 'Original', categoryIds: ['reading'],
      work: { sourceId: '1', url: '/old/', title: 'Original', status: 0, favorite: true, genres: ['Genre'],
        categoryIds: ['old-category'], chapters: [{ url: '/old/chapter/1', title: 'Chapter 1', pageIndex: 7 }],
        history: [{ chapterUrl: '/old/chapter/1', readAt: 100, readDuration: 35 }], tracking: [] },
      linkedWork: { id: '/new/', sourceId: 'com.rumanhua.koma', title: 'Original', tags: ['old-tag'] } }
    const chapter = { id: 'chapter', title: 'Chapter', index: 0, pages: [] }
    const comic = { id: online, title: 'Online', sourceKind: 'private_library', sourceRuntimeId: 'com.rumanhua.koma',
      remoteResourceId: '/new/', categoryIds: ['reading'], chapters: [chapter] }
    const oldPosition = { comicId: original, chapterId: 'old-chapter', pageIndex: 7, totalPages: 20,
      progressRatio: 0.4, updatedAt: 100, completed: false }
    const position = { ...oldPosition, comicId: online, chapterId: chapter.id }
    const state = { comicId: online, chapterId: chapter.id, position, bookmarked: true, updatedAt: 100, isRead: false }
    await library.migrate({ schemaVersion: 1, comics: [
      { id: original, title: 'Original', categoryIds: ['reading'], chapters: [] },
      { id: 'unrelated', title: 'Unrelated', chapters: [] },
    ], mihonImports: [record] })
    await reader.migrate({ progress: [oldPosition], chapters: [], sourceHistory: [] })
    queries.length = 0
    const shelf = library.readForLaunch()
    const imports = library.readMihonImportWorks()
    assert.deepEqual(shelf.comics.map(work => work.id), [original, 'unrelated'])
    assert.equal(imports[0].work.title, record.work.title)
    assert.equal(queries.some(sql => /FROM shelf_mihon_(chapters|history|tracking)\b/i.test(sql)), false)
    assert.deepEqual(plain(library.readMihonImports(original)), plain([record]))
    assert.deepEqual(library.readMihonImports('unrelated'), [])
    const remembered = { ...imports[0], matchedSourceId: 'com.rumanhua.koma' }
    await library.saveMihonSourceMatches([remembered])
    assert.equal(library.readMihonImportWorks()[0].matchedSourceId, remembered.matchedSourceId)
    assert.deepEqual(plain(library.readMihonImports(original)[0].work), plain(record.work))
    const beforeLibrary = plain(library.read())
    const beforeReading = plain(reader.read())
    const linked = { ...record, matchedSourceId: remembered.matchedSourceId, targetComicId: online,
      linkedWork: { ...record.linkedWork, tags: ['new-tag'] } }
    const commit = () => library.commitCatalogLink(linked, comic, transaction => reader.stageCatalogLink(transaction,
      [original, online], { progress: [position], chapters: [state], sourceHistory: [
        { comicId: online, sourceId: comic.sourceRuntimeId, mangaId: comic.remoteResourceId, chapterId: chapter.id },
      ] }))
    env.failNextCommit()
    await assert.rejects(commit(), /interrupted write/)
    assert.deepEqual(plain(library.read()), beforeLibrary)
    assert.deepEqual(plain(reader.read()), beforeReading)
    await commit()
    assert.deepEqual(library.read().comics.map(work => work.id), ['unrelated', online])
    assert.deepEqual(library.readWork(online).categoryIds, ['reading'])
    assert.equal(library.readWork(online).chapters[0].id, chapter.id)
    assert.deepEqual(plain(library.read().mihonImports), plain([linked]))
    assert.deepEqual(plain(reader.read().progress), [position])
    assert.deepEqual(plain(reader.read().chapters), [state])
    assert.equal(store.querySqlSync('SELECT comic_id FROM reader_current_positions WHERE comic_id = ?', [online])
      .goToNextRow(), true)
  } finally {
    env.close()
  }
})

test('a scoped Mihon batch rolls back together and retains unrelated catalogs, imports and reading', async () => {
  const env = fixture()
  try {
    const { openUserDataDatabase } = env.load('UserDataDatabase')
    const { LibraryRdbStorage } = env.load('LibraryRdbStorage')
    const { ReaderRdbStorage } = env.load('ReaderRdbStorage')
    const store = await openUserDataDatabase({ filesDir: '/mihon-batch' })
    const shelf = new LibraryRdbStorage(store), reader = new ReaderRdbStorage(store)
    const book = id => ({ id, title: id, chapters: [{ id: id + '-chapter', title: id, index: 0,
      pages: [{ id: id + '-page', index: 0, sourcePath: '/owned/' + id }] }] })
    const record = id => ({ id, sourceName: 'Original source', categoryIds: [], work: { sourceId: 'source', url: '/' + id,
      title: id, genres: [], categoryIds: [], tracking: [], chapters: [], history: [] } })
    const original = book('changed'), untouched = book('untouched')
    await shelf.migrate({ schemaVersion: 1, comics: [original, untouched], mihonImports: [record('retained')] })
    const position = id => ({ comicId: id, chapterId: id + '-chapter', pageIndex: 3, totalPages: 10,
      progressRatio: 0.4, completed: false, updatedAt: 10 })
    await reader.migrate({ progress: [position('changed'), position('untouched')], chapters: [], sourceHistory: [] })
    const beforeShelf = plain(shelf.read()), beforeReader = plain(reader.read())
    const changed = { ...original, title: 'Imported title' }, added = book('added')
    const nextReading = { progress: [{ ...position('changed'), pageIndex: 7 }], chapters: [], sourceHistory: [] }
    const commit = () => shelf.commitMihonImport([record('new-import')], [changed, added], [], [],
      transaction => reader.stageCatalogLink(transaction, ['changed'], nextReading))
    env.failNextCommit()
    await assert.rejects(commit(), /interrupted write/)
    assert.deepEqual(plain(shelf.read()), beforeShelf)
    assert.deepEqual(plain(reader.read()), beforeReader)
    await commit()
    assert.deepEqual(shelf.read().comics.map(row => row.id), ['changed', 'untouched', 'added'])
    assert.equal(shelf.readWork('changed').title, 'Imported title')
    assert.deepEqual(plain(shelf.readWork('untouched')), beforeShelf.comics.find(row => row.id === 'untouched'))
    assert.deepEqual(shelf.readMihonImportWorks().map(row => row.id), ['retained', 'new-import'])
    assert.equal(reader.readPositions(['changed'])[0].pageIndex, 7)
    assert.equal(reader.readPositions(['untouched'])[0].pageIndex, 3)
  } finally { env.close() }
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

test('automatic download recovery reads only pending tasks in their saved order', async () => {
  const env = fixture(new Map(), new Map([
    ['@kit.CoreFileKit', { fileIo: { ...fs, accessSync: fs.existsSync } }],
    ['../i18n/AppStrings', { AppStrings: { get: key => key } }],
    ['../diagnostics/DiagnosticLogger', { DiagnosticLogger: { info() {}, warn() {}, exception() {} } }],
  ]))
  try {
    const { OfflineDownloadQueueStore, prepareOfflineQueueDatabase } = env.load('OfflineDownloadQueueStore')
    const context = { filesDir: '/download-queue-startup-test' }
    await prepareOfflineQueueDatabase(context)
    const queue = new OfflineDownloadQueueStore(context.filesDir)
    queue.prepareDatabase()
    const entry = (chapterId, status, change = {}) => ({ comicId: 'sample', chapterId, status,
      automatic: true, requestId: 'request-' + chapterId, pageCount: 1, downloadedPageCount: 0, updatedAt: 2, ...change })
    queue.restoreSnapshotText(JSON.stringify({ schemaVersion: 1, entries: [
      entry('complete', 'downloaded'), entry('paused', 'queued', { pausedByUser: true }),
      entry('offline', 'blocked', { failureReasonCode: 'offline' }), entry('manual', 'queued', { automatic: false }),
      entry('canceling', 'queued', { canceling: true }), entry('next', 'queued'), entry('error', 'failed'),
    ] }))
    assert.deepEqual(queue.loadAutomaticPendingEntries().map(item => item.chapterId), ['offline', 'next'])
    assert.deepEqual(queue.loadAutomaticPendingEntries(true).map(item => item.chapterId), ['paused', 'offline', 'next'])
    assert.deepEqual(queue.loadRunnableEntries().map(item => item.chapterId), ['offline', 'manual', 'next', 'error'])
    const visited = []
    const next = queue.findRunnableEntry(item => {
      visited.push(item.chapterId)
      return item.chapterId === 'manual'
    })
    assert.equal(next.requestId, 'request-manual')
    assert.deepEqual(visited, ['offline', 'manual'])
    const { runOrderedDownloadQueueBatch } = env.load('OfflineDownloadQueueExecution')
    const started = []
    let finishFirst
    const first = new Promise(resolve => { finishFirst = resolve })
    const targets = queue.loadRunnableEntries().filter(item => item.chapterId !== 'error')
    const running = runOrderedDownloadQueueBatch(queue, targets, async item => {
      started.push(item.chapterId)
      if (started.length === 1) await first
    }, () => true)
    assert.deepEqual(started, ['offline'])
    queue.move('sample', 'next', true)
    finishFirst()
    await running
    assert.deepEqual(started, ['offline', 'next', 'manual'])
    assert.equal(queue.loadTask({ comicId: 'sample', chapterId: 'complete' }).requestId, 'request-complete')
    assert.equal(queue.load().length, 7)
  } finally {
    env.close()
  }
})

test('large download batches keep unrelated ranks and interrupted recovery keeps live edits', async () => {
  const rdb = createRdbPort()
  const runtime = new Map([
    ['@kit.CoreFileKit', { fileIo: { ...fs, accessSync: fs.existsSync } }],
    ['../i18n/AppStrings', { AppStrings: { get: key => key } }],
    ['../diagnostics/DiagnosticLogger', { DiagnosticLogger: { info() {}, warn() {}, exception() {} } }],
  ])
  const env = fixture(new Map(), runtime, rdb)
  try {
    const context = { filesDir: '/download-batch-scope-test' }
    const { OfflineDownloadQueueStore, prepareOfflineQueueDatabase } = env.load('OfflineDownloadQueueStore')
    const database = await env.load('UserDataDatabase').openUserDataDatabase(context)
    await prepareOfflineQueueDatabase(context)
    const queue = new OfflineDownloadQueueStore(context.filesDir)
    const row = (comicId, chapterId, status, extra = {}) => ({ comicId, chapterId, status,
      requestId: chapterId, pageCount: 3, downloadedPageCount: 0, updatedAt: 1, ...extra })
    const historical = Array.from({ length: 500 }, (_, i) => row('history-' + i, 'done', 'downloaded'))
    queue.restoreSnapshotText(JSON.stringify({ schemaVersion: 1, entries: historical.concat([
      row('interrupted', 'pause', 'downloading'), row('interrupted', 'remove', 'downloading'),
      row('interrupted', 'replace', 'downloading'),
    ]) }))

    let decoded = 0
    const query = database.querySqlSync.bind(database)
    database.querySqlSync = (sql, args) => {
      const result = query(sql, args)
      if (sql.includes('FROM offline_download_tasks')) {
        const next = result.goToNextRow.bind(result)
        result.goToNextRow = () => { const hasRow = next(); if (hasRow) decoded++; return hasRow }
      }
      return result
    }
    const chapters = Array.from({ length: 260 }, (_, i) => ({ id: 'page-' + i, title: 'Chapter ' + i, pages: [],
      pageCount: 3, readingGroup: 'source-catalog', readingOrder: i, continuationEligible: true }))
    const work = { id: 'fresh', title: 'Fresh', chapters: chapters.slice().reverse() }
    assert.equal(queue.requestChapters(work, chapters.map(chapter => chapter.id).reverse()), chapters.length)
    assert.equal(decoded, 0, 'batch enqueue must not load the other 500 tasks')
    assert.deepEqual(queue.loadComicSnapshot(work.id).entries.map(entry => entry.chapterId), chapters.map(chapter => chapter.id))
    assert.equal(queue.addNewEntries([historical[0], row('fresh', 'unique', 'queued'), row('fresh', 'unique', 'queued')]), 1)
    queue.move(work.id, 'page-1', true)
    assert.equal(queue.load()[0].chapterId, 'page-1')
    queue.move(work.id, 'page-1', false)
    const order = queue.load()
    assert.equal(order.at(-1).chapterId, 'page-1')
    assert.deepEqual(order.filter(entry => entry.comicId.startsWith('history-')).map(plain), historical)

    const original = queue.entriesNeedingReconcile()
    const [paused, removed, replaced] = original
    assert.equal(queue.setTasksPaused([paused], true), 1)
    queue.remove(removed.comicId, removed.chapterId)
    queue.remove(replaced.comicId, replaced.chapterId)
    assert.equal(queue.addNewEntries([{ ...replaced, status: 'queued' }]), 1)
    assert.equal(queue.applyReconciledEntries(original, original.map(entry => ({ ...entry, status: 'partial',
      downloadedPageCount: 2, failureReasonCode: 'download_interrupted' }))), 1)
    assert.equal(queue.loadTask(paused).pausedByUser, true)
    assert.equal(queue.loadTask(paused).downloadedPageCount, 2)
    assert.equal(queue.loadTask(removed), undefined)
    assert.equal(queue.loadTask(replaced).status, 'queued')
  } finally { env.close() }
})

test('missing bytes update only the affected download and make it eligible for a new request', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-download-availability-'))
  const fileIo = { ...fs, accessSync: fs.existsSync, access: async file => fs.existsSync(file),
    readTextSync: file => fs.readFileSync(file, 'utf8'), listFileSync: file => fs.readdirSync(file),
    listFile: (file, options) => fs.promises.readdir(file, { recursive: options?.recursion }),
    mkdirSync: file => fs.mkdirSync(file, { recursive: true }),
    OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
    openSync: (file, mode) => ({ fd: fs.openSync(file, mode ? 'w' : 'r') }),
    closeSync: file => fs.closeSync(file.fd),
    writeSync: (fd, value) => fs.writeSync(fd, typeof value === 'string' ? value : Buffer.from(value)),
    readSync: (fd, value) => fs.readSync(fd, Buffer.from(value), 0, value.byteLength, null),
  }
  const env = fixture(new Map(), new Map([
    ['@kit.CoreFileKit', { fileIo }],
    ['../i18n/AppStrings', { AppStrings: { get: key => key } }],
    ['../diagnostics/DiagnosticLogger', { DiagnosticLogger: { info() {}, warn() {}, exception() {} } }],
  ]))
  try {
    const { OfflineDownloadQueueStore, prepareOfflineQueueDatabase } = env.load('OfflineDownloadQueueStore')
    const { OfflineDownloadStore, createOfflineDownloadFileContentHash } = env.load('OfflineDownloadStore')
    await prepareOfflineQueueDatabase({ filesDir: directory })
    const queue = new OfflineDownloadQueueStore(directory)
    const store = new OfflineDownloadStore(directory)
    const make = chapterId => {
      const saved = store.createManifest('work', chapterId, 1, 'queued', { seriesId: 'work' })
      const file = store.pageFilePath('work', chapterId, 'first', 0, 'jpg')
      fs.writeFileSync(file, Buffer.from([1, 2, 3]))
      const withPage = store.recordPage(saved, { pageId: 'first', pageIndex: 0, localPath: file, size: 3,
        updatedAt: 1, contentHash: createOfflineDownloadFileContentHash(file) })
      return store.saveManifest({ ...withPage, status: 'downloaded' })
    }
    const opened = make('opened'), scanned = make('scanned'), intact = make('intact')
    const initial = [opened, scanned, intact].map(manifest => ({ ...queue.fromManifest(manifest),
      requestId: manifest.chapterId, updatedAt: manifest.updatedAt + 1 }))
    queue.restoreSnapshotText(JSON.stringify({ schemaVersion: 1, entries: initial }))
    fs.unlinkSync(opened.pages[0].localPath)
    fs.unlinkSync(scanned.pages[0].localPath)
    const before = queue.loadTask(initial[0])
    const result = store.validateDownloadedChapter('work', 'opened')
    assert.equal(result.reasonCode, 'pages_missing')
    queue.recordChapterAvailability(before, result)
    assert.equal(queue.loadTask(before).status, 'failed')
    const newChapter = { id: 'opened', title: 'Opened', pages: [], pageCount: 1 }
    assert.equal(queue.requestChapters({ id: 'work', title: 'Work', chapters: [newChapter] }, ['opened']), 1)
    queue.recordChapterAvailability(before, result)
    assert.equal(queue.loadTask(before).status, 'queued')
    const intactBefore = queue.loadTask(initial[2])
    const summary = await queue.recoverFromManifests()
    assert.equal(summary.updatedCount, 1)
    assert.equal(queue.loadTask(initial[1]).status, 'failed')
    assert.deepEqual(queue.loadTask(initial[2]), intactBefore)
  } finally {
    env.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
