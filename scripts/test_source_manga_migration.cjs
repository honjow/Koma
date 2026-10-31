const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm')
const ts = require((process.env.DEVECO_HOME || '/Applications/DevEco-Studio.app/Contents') + '/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
const clone = value => JSON.parse(JSON.stringify(value))
const preferenceData = new Map(), modules = new Map()
let failTracking = false
const preferencePort = {
  async has(key) { return preferenceData.has(key) },
  async get(key, fallback) { return preferenceData.has(key) ? preferenceData.get(key) : fallback },
  async put(key, value) { if (failTracking) throw Error('storage failure'); preferenceData.set(key, value) },
  async delete(key) { preferenceData.delete(key) }, async flush() {},
}
const ports = {
  '@kit.ArkData': { preferences: { getPreferences: async () => preferencePort } },
  '@kit.ArkTS': { buffer: Buffer },
  '@kit.CoreFileKit': { fileIo: { accessSync: () => false } },
  '../i18n/AppStrings': { AppStrings: { get: key => key } },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn() {}, debug() {}, error() {}, exception() {} } },
  '../sourceRuntime/SourceRuntimeAppRegistry': { sourceChapterOrderFor: () => undefined },
  '../sourceRuntime/SourceRuntimeRegistry': { sourceRuntimeEntryEnabled: entry => !!entry && entry.enabled !== false },
  '../sourceRuntime/SourceRuntimeWorkerClient': { executeSourceRequestInWorker: () => { throw Error('unexpected network') } },
  '../sourceRuntime/SourceWebSessionStore': { sourceHttpIdentityJson: () => '{}' },
  '../sourceRuntime/SourceRuntimeRunner': { diagnoseSourceOperation: (_request, execute) => execute() },
  '../sourceRuntime/SourceHostFeatures': { sourceRequestWithHostFeatures: request => request },
  '../sourceRuntime/SourceSettingsStore': { appSourceSettingsStore: { revisionForSource: () => '0', loadForSource: () => ({}) } },
  './SourceChapterListResolver': {}, './SourceChapterIdentityGuard': { protectedSourceChapterIds: () => undefined },
  // Existing catalog merging is unchanged by this feature; these tests exercise new-target commits.
  './LibraryUpdateService': { mergeSourceChapters: () => { throw Error('unexpected existing catalog merge') } },
}
function load(file) {
  if (modules.has(file)) return modules.get(file)
  const exports = {}; modules.set(file, exports)
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, { exports, console, Map, Set, Date, Uint8Array, setTimeout, clearTimeout,
    require(name) {
      if (ports[name]) return ports[name]
      if (name.startsWith('@kit.')) return {}
      if (name.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
      throw Error('Missing port ' + name)
    } })
  return exports
}
const core = load('model/SourceMangaMigration')
const { InMemoryReaderSessionStore, PersistentReaderSessionStore } = load('model/ReaderSessionStore')
const { InMemoryLibraryStore } = load('model/LibraryStore')
const persistenceModule = load('model/LibraryPersistence')
const { commitMangaMigration } = load('model/SourceMangaMigrationService')
const tracking = load('model/TrackerModels')
const kind = load('model/ComicModels').ComicSourceKind.PRIVATE_LIBRARY

test('target preparation reuses a complete preview but rejects a changed source, route or incomplete catalog', async () => {
  const { prepareMangaMigration } = load('model/SourceMangaMigrationService')
  const { sourceMangaDetailSnapshotCache: cache } = load('model/SourceMangaDetailSnapshotCache')
  const entry = { sourceId: 'preview', manifestVersion: '1', wasmByteCount: 1, wasmBytes: new Uint8Array([0]) }
  let currentEntry = entry
  const registry = { lookup: () => ({ entry: currentEntry }) }
  const manga = { id: 'work', sourceId: 'preview', title: 'Series', url: 'https://owned.invalid/work' }
  const snapshot = { detail: { ...manga, chapterCount: 1 }, chaptersResolved: true,
    chapters: [{ id: 'chapter-1', title: 'Chapter 1', chapterNumber: 1 }], excludedChapterIds: ['ad'] }
  cache.write(entry, manga.sourceId, manga.id, snapshot, '0')
  const prepared = await prepareMangaMigration(registry, manga, () => true)
  assert.equal(prepared.comic.chapters.length, 1)
  assert.equal(prepared.comic.sourceRuntimeId, 'preview')
  assert.deepEqual(clone(prepared.comic.sourceMetadata.excludedChapterIds), ['ad'])
  await assert.rejects(prepareMangaMigration(registry, manga, () => false), /migration_source_changed/)
  await assert.rejects(prepareMangaMigration(registry, { ...manga, url: 'https://owned.invalid/other' }, () => true), /unexpected network/)
  currentEntry = { ...entry }
  await assert.rejects(prepareMangaMigration(registry, manga, () => true), /unexpected network/)
  cache.write(currentEntry, manga.sourceId, manga.id, { ...snapshot, chaptersResolved: false }, '0')
  await assert.rejects(prepareMangaMigration(registry, manga, () => true), /unexpected network/)
})
function book(id, numbers = [1, 2, 3]) {
  return { id, title: 'Same series', sourceKind: kind, sourceRuntimeId: id + '-source', remoteResourceId: id + '-work',
    sourcePath: 'https://owned.invalid/' + id, sortTitle: 'same series', preferredDirection: 'right_to_left',
    categoryIds: [], chapterCount: numbers.length, pageCount: 0, createdAt: 1, updatedAt: 1, lastImportedAt: 1,
    chapters: numbers.map((number, index) => ({ id: id + '-' + number, comicId: id, title: 'Chapter ' + number,
      index, chapterNumber: number, sortKey: '' + index, sourcePath: '' + number, pages: [], pageCount: 0, createdAt: 1, updatedAt: 1 })) }
}
function read(comic, number) { return { comicId: comic.id, chapterId: comic.id + '-' + number, isRead: true, updatedAt: 10 } }
test('bookmarks persist independently of read state, survive reading changes and transfer without marking unread chapters read', () => {
  let disk = { progress: [], sourceHistory: [], chapters: [] }, fail = false
  const adapter = { loadSnapshot: () => clone(disk), saveSnapshot: value => { if (fail) throw Error('disk failure'); disk = clone(value) } }
  const store = new PersistentReaderSessionStore(adapter)
  assert.equal(store.commitChapterBookmark('old', 'old-1', true), true)
  assert.equal(store.isChapterRead('old', 'old-1'), false)
  assert.equal(store.getProgress('old'), undefined)
  store.commitChapterReadStates([{ comicId: 'old', chapterId: 'old-1', isRead: true }])
  store.commitChapterReadStates([{ comicId: 'old', chapterId: 'old-1', isRead: false }])
  assert.equal(store.isChapterBookmarked('old', 'old-1'), true)
  const reloaded = new PersistentReaderSessionStore(adapter)
  assert.equal(reloaded.isChapterBookmarked('old', 'old-1'), true)
  const plan = core.planMangaMigrationReadState(book('old'), book('new'), reloaded.listChapterStates())
  assert.equal(reloaded.commitMigrationReadPlan(plan), true)
  assert.equal(reloaded.isChapterBookmarked('new', 'new-1'), true)
  assert.equal(reloaded.isChapterRead('new', 'new-1'), false)
  fail = true
  assert.equal(store.commitChapterBookmark('old', 'old-1', false), false)
  assert.equal(store.isChapterBookmarked('old', 'old-1'), true)
})
test('cross-source read transfer ignores display order, keeps unread gaps and never carries source page identity', () => {
  const source = book('old', [3, 2, 1]), target = book('new', [1, 2, 3])
  const plan = core.planMangaMigrationReadState(source, target, [read(source, 1), read(source, 3)], {
    comicId: 'old', chapterId: 'old-2', pageId: 'old-image', pageIndex: 8, totalPages: 10,
    progressRatio: .9, completed: false, updatedAt: 7, columnMode: 'odd_left',
  })
  assert.deepEqual(clone(plan.states).map(row => row.chapterId), ['new-1', 'new-3'])
  assert.equal(plan.progress.chapterId, 'new-2'); assert.equal(plan.progress.pageIndex, 0)
  assert.equal(plan.progress.pageId, undefined); assert.equal(plan.progress.columnMode, undefined)
  assert.equal(plan.progress.updatedAt, 7)
  const owned = { comicId: 'new', chapterId: 'new-3' }
  assert.equal(core.planMangaMigrationReadState(source, target, [], undefined, owned).progress, undefined)
})
test('restarted volume numbers require unique correspondence and ambiguous chapters stay unmatched', () => {
  const source = book('old', [1, 1]), target = book('new', [1, 1])
  source.chapters.forEach((row, index) => { row.id += index; row.volumeNumber = '' + (index + 1) })
  target.chapters.forEach((row, index) => { row.id += index; row.volumeNumber = '' + (index + 1) })
  assert.equal(core.migrationChapterMatch(source.chapters[1], source.chapters, target.chapters).id, target.chapters[1].id)
  target.chapters[0].volumeNumber = '2'
  const state = { comicId: source.id, chapterId: source.chapters[1].id, isRead: true, updatedAt: 1 }
  assert.equal(core.planMangaMigrationReadState(source, target, [state]).unmatchedReadCount, 1)
  const one = book('one', [1]), another = book('another', [1])
  one.chapters[0].volumeNumber = '1'; another.chapters[0].volumeNumber = '2'
  assert.equal(core.migrationChapterMatch(one.chapters[0], one.chapters, another.chapters), undefined)
  assert.deepEqual(clone(core.migrationCategoryIds({ categoryIds: ['favorite'] }, { categoryIds: ['custom:1'] }, true)), ['custom:1', 'favorite'])
})
test('a failed Reader persistence commit restores old memory and disk, and a retry preserves read timestamps', () => {
  let disk = { progress: [], sourceHistory: [], chapters: [] }, fail = true
  const store = new PersistentReaderSessionStore({ load: () => [], loadSnapshot: () => clone(disk),
    saveSnapshot(value) { if (fail) throw Error('disk failure'); disk = clone(value) } })
  const plan = { states: [{ comicId: 'new', chapterId: 'chapter', isRead: true, updatedAt: 4 }],
    progress: { comicId: 'new', chapterId: 'chapter', pageIndex: 0, totalPages: 0, completed: true, progressRatio: 0, updatedAt: 4 } }
  assert.equal(store.commitMigrationReadPlan(plan), false)
  assert.equal(store.isChapterRead('new', 'chapter'), false); assert.equal(store.getProgress('new'), undefined)
  assert.equal(disk.progress.length, 0)
  fail = false; assert.equal(store.commitMigrationReadPlan(plan), true)
  assert.equal(new PersistentReaderSessionStore({ loadSnapshot: () => clone(disk) }).getProgress('new').updatedAt, 4)
})
function fixture() {
  preferenceData.clear(); failTracking = false
  const library = new InMemoryLibraryStore(), source = book('old'), target = book('new')
  source.categoryIds = ['favorite']; library.addComic(source)
  let disk = '', fail = false
  const persistence = new persistenceModule.LibraryStorePersistenceService(library, {
    save(value) { if (fail) throw Error('disk failure'); disk = value }, load() { return disk },
  })
  persistence.persist()
  const reader = new InMemoryReaderSessionStore()
  reader.markChapterReadState('old', 'old-1', true)
  reader.saveProgress({ comicId: 'old', chapterId: 'old-2', pageIndex: 3, totalPages: 5, progressRatio: .8, completed: false, updatedAt: 1 })
  const entry = { sourceId: target.sourceRuntimeId, enabled: true }
  const prepared = { comic: target, entry, settingsRevision: '0', chapters: [],
    manga: { sourceId: target.sourceRuntimeId, id: target.remoteResourceId } }
  const context = { filesDir: '/owned-test' }, registry = { lookup: () => ({ entry }) }
  return { library, source, target, reader, context, registry, prepared, persistence,
    disk: () => disk, failPersistence: () => { fail = true } }
}
test('copy and move persist destination state first; moving keeps original history and confirmed tracker bindings', async () => {
  for (const copy of [true, false]) {
    const f = fixture(), store = new tracking.TrackerPreferencesStore(f.context)
    await store.saveComicMappings([{ comicId: 'old', providerId: 'anilist', providerTitleId: '123',
      mappingState: 'confirmed', userConfirmed: true, createdAt: 1 }])
    await commitMangaMigration(f.context, f.registry, f.library, f.persistence, f.reader, 'old', f.prepared,
      { copy, categories: true, readProgress: true })
    assert.equal(!!f.library.getComic('old'), copy)
    assert.equal(f.reader.isChapterRead('new', 'new-1'), true)
    assert.equal(f.reader.getProgress('new').chapterId, 'new-2')
    assert.equal(f.library.getComic('new').categoryIds[0], 'favorite')
    assert.equal((await store.listComicMappings('new'))[0].providerTitleId, '123')
    assert.equal(f.reader.getProgress('old').chapterId, 'old-2')
    if (!copy) assert.equal(f.reader.getSourceHistory('old').mangaId, 'old-work')
    assert.equal(JSON.parse(f.disk()).comics.some(row => row.id === 'old'), copy)
  }
})
test('failed destination or tracker writes never remove the original shelf entry', async () => {
  for (const stage of ['library', 'tracking']) {
    const f = fixture()
    if (stage === 'library') f.failPersistence()
    else {
      const store = new tracking.TrackerPreferencesStore(f.context)
      await store.saveComicMappings([{ comicId: 'old', providerId: 'anilist', providerTitleId: '123',
        mappingState: 'confirmed', userConfirmed: true, createdAt: 1 }]); failTracking = true
    }
    await assert.rejects(commitMangaMigration(f.context, f.registry, f.library, f.persistence, f.reader, 'old', f.prepared,
      { copy: false, categories: true, readProgress: true }))
    assert.ok(f.library.getComic('old')); assert.ok(JSON.parse(f.disk()).comics.some(row => row.id === 'old'))
    failTracking = false
  }
})
test('destination tracker choices survive migration and copying does not perform remote requests', async () => {
  const f = fixture(), store = new tracking.TrackerPreferencesStore(f.context)
  await store.saveComicMappings([
    { comicId: 'old', providerId: 'anilist', providerTitleId: '123', mappingState: 'confirmed', userConfirmed: true, createdAt: 1 },
    { comicId: 'new', providerId: 'anilist', providerTitleId: '456', mappingState: 'confirmed', userConfirmed: true, createdAt: 1 },
  ])
  await store.copyComicMappings('old', 'new')
  assert.equal((await store.listComicMappings('new'))[0].providerTitleId, '456')
  assert.equal((await store.listComicMappings('old'))[0].providerTitleId, '123')
})

test('migration source choice survives a new store, keeps order and explicit empty selection', async () => {
  preferenceData.clear()
  const { MangaMigrationPreferencesStore } = load('model/MangaMigrationPreferencesStore')
  const first = new MangaMigrationPreferencesStore({ filesDir: 'owned' })
  assert.deepEqual(clone(await first.loadOptions()), { deepSearch: false, prioritizeChapters: false })
  await first.save(['source-b', 'source-a', 'source-b'])
  assert.deepEqual(clone(await new MangaMigrationPreferencesStore({ filesDir: 'owned' }).load()), ['source-b', 'source-a'])
  await first.save([])
  assert.deepEqual(clone(await new MangaMigrationPreferencesStore({ filesDir: 'owned' }).load()), [])
  await first.saveOptions({ deepSearch: true, prioritizeChapters: true })
  assert.deepEqual(clone(await new MangaMigrationPreferencesStore({ filesDir: 'owned' }).loadOptions()),
    { deepSearch: true, prioritizeChapters: true })
})

test('migration search uses only selected sources in saved order and publishes each result independently', async () => {
  const source = fs.readFileSync(path.join(root, 'model/CrossSearchService.ets'), 'utf8')
  const ast = ts.createSourceFile('cross.ts', source, ts.ScriptTarget.Latest, true)
  const owner = ast.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'CrossSearchService')
  const names = ['search', 'selectedSourceSummaries', 'sourceMatchesFilter', 'pendingSections']
  const methods = owner.members.filter(n => names.includes(n.name?.getText(ast))).map(n => n.getText(ast)).join('\n')
  const exports = {}, registry = ['a', 'b', 'unselected'].map(sourceId => ({ sourceId, displayName: sourceId }))
  const js = ts.transpileModule('export class Subject { ' + methods + ' }', { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, { exports, console,
    DiagnosticLogger: { begin: () => ({ finish() {}, fail() {} }) },
    AppStrings: { get: k => k }, appSourceRuntimeRegistry: { listInstalledSourceSummaries: () => registry },
    isCrossSearchQueryMeaningful: q => q.trim().length > 0 })
  const service = new exports.Subject(), started = [], published = [], complete = new Map()
  service.cancelPendingSearch = () => { service.pagedSearchRuns = [] }
  service.sourceSupportsSearch = () => true
  service.stateSection = id => ({ id })
  service.searchWasmSource = source => {
    started.push(source.sourceId)
    return new Promise(resolve => complete.set(source.sourceId, () => resolve({ section: { id: source.sourceId } })))
  }
  assert.deepEqual(clone(service.pendingSections('source', ['b', 'a'])).map(s => s.id), ['wasm:b', 'wasm:a'])
  const running = service.search('query', 'source', section => published.push(section.id), undefined, ['b', 'a'])
  assert.deepEqual(started, ['b', 'a'])
  complete.get('b')(); await Promise.resolve(); await Promise.resolve()
  assert.deepEqual(published, ['b'])
  complete.get('a')(); assert.deepEqual(clone(await running).map(s => s.id), ['b', 'a'])
})
