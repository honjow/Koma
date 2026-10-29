// Executes the production metadata helper and existing persistence transaction; no device or network.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/LibraryPersistence.ets'), 'utf8')
const tree = ts.createSourceFile('persistence.ts', source, ts.ScriptTarget.Latest, true)
const names = ['upsertComicAndPersistLibraryStore', 'refreshSourceComicCoverAndPersistLibraryStore', 'refreshSourceChapterMetadataAndPersistLibraryStore', 'refreshSourceMangaDetailAndPersistLibraryStore']
function productionFunctions(name) {
  const text = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/', name + '.ets'), 'utf8')
  const file = ts.createSourceFile(name + '.ts', text, ts.ScriptTarget.Latest, true)
  return file.statements.filter(ts.isFunctionDeclaration).map(node => node.getText(file)).join('\n')
}
const code = productionFunctions('SourceChapterMetadata') + '\n' + productionFunctions('SourceChapterVisibility') + '\n' + names.map(name => tree.statements.find(n => ts.isFunctionDeclaration(n) && n.name?.text === name).getText(tree)).join('\n')
const output = ts.transpileModule(code, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
const exportsForTest = {}
const clone = value => JSON.parse(JSON.stringify(value))
new Function('exports', 'ComicSourceKind', 'serializeLibraryStore', 'hydrateLibraryStoreFromJson', 'normalizeSortKey', output)(
  exportsForTest, { PRIVATE_LIBRARY: 'private_library' },
  store => JSON.stringify(store.values), (store, payload) => { store.values = JSON.parse(payload) }, value => value.toLowerCase())
const refresh = exportsForTest.refreshSourceComicCoverAndPersistLibraryStore
function fixture() {
  const original = { id: 'owned-work', sourceKind: 'private_library', sourceRuntimeId: 'owned-source', remoteResourceId: 'owned-remote',
    coverUri: 'https://owned.invalid/old', title: 'Owned title', createdAt: 1, updatedAt: 2, lastImportedAt: 3,
    chapters: [{ id: 'owned-chapter', pages: [{ id: 'owned-page', uri: 'file://owned-cache' }], index: 0 }],
    chapterCount: 458, pageCount: 18, categoryIds: ['owned-category'], localMetadata: { custom: 'keep' } }
  const store = { values: { [original.id]: clone(original) }, getComic(id) { return this.values[id] }, addComic(row) { this.values[row.id] = row } }
  let saves = 0
  return { original, store, service: { persist() { saves++ } }, saves: () => saves }
}
test('fresh cover changes only the cover field and persists once, preserving chapter/cache/category/order data', () => {
  const f = fixture()
  assert.equal(refresh(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), true)
  assert.deepEqual(f.store.getComic('owned-work'), { ...f.original, coverUri: 'https://owned.invalid/new' })
  assert.equal(f.saves(), 1)
  assert.equal(refresh(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), false)
  assert.equal(f.saves(), 1)
})
test('missing/wrong identity, local work, empty/invalid cover never writes or removes the existing cover', () => {
  for (const [id, sourceId, mangaId, cover] of [
    ['missing', 'owned-source', 'owned-remote', 'https://owned.invalid/new'],
    ['owned-work', 'other-source', 'owned-remote', 'https://owned.invalid/new'],
    ['owned-work', 'owned-source', 'other-remote', 'https://owned.invalid/new'],
    ['owned-work', 'owned-source', 'owned-remote', ''],
    ['owned-work', 'owned-source', 'owned-remote', undefined],
    ['owned-work', 'owned-source', 'owned-remote', 'file://wrong'],
  ]) {
    const f = fixture()
    assert.equal(refresh(f.store, f.service, id, sourceId, mangaId, cover), false)
    assert.deepEqual(f.store.getComic('owned-work'), f.original)
    assert.equal(f.saves(), 0)
  }
  const f = fixture(); f.store.values['owned-work'].sourceKind = 'local_folder'
  assert.equal(refresh(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), false)
  assert.equal(f.saves(), 0)
})
test('persistence failure rolls back the live owner and rethrows the original error', () => {
  const f = fixture(), failure = new Error('owned failure')
  assert.throws(() => refresh(f.store, { persist() { throw failure } }, 'owned-work', 'owned-source', 'owned-remote', 'https://owned.invalid/new'), e => e === failure)
  assert.deepEqual(f.store.getComic('owned-work'), f.original)
})

const refreshChapters = exportsForTest.refreshSourceChapterMetadataAndPersistLibraryStore
const sequenceExports = {}
const sequenceFile = ts.createSourceFile('sequence.ts', fs.readFileSync(path.join(__dirname,
  '../entry/src/main/ets/model/ReaderChapterSequence.ets'), 'utf8'), ts.ScriptTarget.Latest, true)
const firstChapterCode = sequenceFile.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === 'firstReaderChapter').getText(sequenceFile)
new Function('exports', ts.transpileModule(firstChapterCode, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText)(sequenceExports)
function chapterFixture() {
  const f = fixture(), comic = f.store.getComic('owned-work')
  comic.chapters = [
    { id: 'latest', title: 'Preserve original title', index: 0, chapterNumber: 99,
      pages: [{ id: 'cached-page', uri: 'file://owned-cache', width: 100 }], read: true, downloaded: true },
    { id: 'first', title: 'First original title', index: 1, dateUpload: 100, pages: [], read: false },
    { id: 'absent', title: 'Missing on remote', index: 2, chapterNumber: 50, pages: [{ uri: 'file://absent-cache' }] },
  ]
  comic.currentChapterId = 'latest'; comic.currentPageIndex = 14; comic.progress = 0.94
  f.before = clone(comic)
  f.remote = [
    { id: 'latest', title: 'New remote title', chapterNumber: 2, language: 'zh', volumeNumber: '1',
      readingGroup: 'main', continuationEligible: true, dateUpload: 200 },
    { id: 'first', title: 'New first title', chapterNumber: 1, language: 'zh', readingGroup: 'main', continuationEligible: true },
    { id: 'new-remote-only', title: 'Not collected', chapterNumber: 3 },
  ]
  return f
}
test('resolved metadata updates matching IDs only and keeps every page/progress/category/title/order value', () => {
  const f = chapterFixture(), heldOwner = f.store.getComic('owned-work')
  assert.equal(refreshChapters(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', f.remote), true)
  const next = f.store.getComic('owned-work')
  const expected = clone(f.before)
  Object.assign(expected.chapters[0], { chapterNumber: 2, language: 'zh', volumeNumber: '1', readingGroup: 'main',
    continuationEligible: true, dateUpload: 200, sortKey: '2' })
  Object.assign(expected.chapters[1], { chapterNumber: 1, language: 'zh', readingGroup: 'main', continuationEligible: true, sortKey: '1' })
  assert.deepEqual(clone(next), expected)
  assert.deepEqual(heldOwner, f.before, 'never mutates a detail/reader-held owner reference')
  assert.equal(sequenceExports.firstReaderChapter(next.chapters).id, 'first')
  assert.equal(f.saves(), 1)
  assert.equal(refreshChapters(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', f.remote), false)
  assert.equal(f.saves(), 1, 'identical resolved snapshots must not cause repeated disk writes')
})
test('unknown sequence metadata clears stale ordinals while an unknown date retains the stored upload date', () => {
  const f = chapterFixture()
  assert.equal(refreshChapters(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', [{ id: 'first' }, { id: 'latest' }]), true)
  const first = f.store.getComic('owned-work').chapters[1]
  assert.equal(first.dateUpload, 100)
  assert.equal(f.store.getComic('owned-work').chapters[0].chapterNumber, undefined, 'clear the stale stored 99 instead of guessing from its title')
  assert.equal(first.sortKey, '1')
  assert.equal(first.chapterNumber, undefined)
  assert.equal(refreshChapters(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', [{ id: 'first', dateUpload: 80 }]), true)
  assert.equal(f.store.getComic('owned-work').chapters[1].dateUpload, 80)
})
test('missing, wrong-source, wrong-manga, local and empty/unmatched directories never persist', () => {
  for (const [id, sourceId, mangaId, chapters] of [
    ['missing', 'owned-source', 'owned-remote', [{ id: 'latest', chapterNumber: 1 }]],
    ['owned-work', 'wrong', 'owned-remote', [{ id: 'latest', chapterNumber: 1 }]],
    ['owned-work', 'owned-source', 'wrong', [{ id: 'latest', chapterNumber: 1 }]],
    ['owned-work', 'owned-source', 'owned-remote', []],
    ['owned-work', 'owned-source', 'owned-remote', [{ id: 'remote-only', chapterNumber: 1 }]],
  ]) {
    const f = chapterFixture()
    assert.equal(refreshChapters(f.store, f.service, id, sourceId, mangaId, chapters), false)
    assert.deepEqual(f.store.getComic('owned-work'), f.before)
    assert.equal(f.saves(), 0)
  }
  const f = chapterFixture(); f.store.values['owned-work'].sourceKind = 'local_archive'
  assert.equal(refreshChapters(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', f.remote), false)
  assert.equal(f.saves(), 0)
})
test('metadata save failure rolls back all stored comics and preserves held owner references', () => {
  const f = chapterFixture(), held = f.store.getComic('owned-work'), failure = new Error('owned failure')
  f.store.values.other = { id: 'other', progress: 'keep' }
  const before = clone(f.store.values)
  assert.throws(() => refreshChapters(f.store, { persist() { throw failure } }, 'owned-work', 'owned-source', 'owned-remote', f.remote), error => error === failure)
  assert.deepEqual(f.store.values, before)
  assert.deepEqual(held, f.before)
})

const pageSource = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/pages/MangaDetailPage.ets'), 'utf8').replace(/\bstruct (\w+)/g, 'class $1')
const pageTree = ts.createSourceFile('page.ts', pageSource, ts.ScriptTarget.Latest, true)
const pageOwner = pageTree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'MangaDetailPage')
const pageMethods = ['refreshSourceLibraryDetail', 'applySourceMangaDetail'].map(name => pageOwner.members.find(node => node.name?.text === name).getText(pageTree)).join('\n')
function detailFixture() {
  const f = chapterFixture(), out = {}, notifications = [], errors = []
  const compiled = ts.transpileModule('export class Page { ' + pageMethods + ' }', { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText
  new Function('exports', 'refreshSourceMangaDetailAndPersistLibraryStore', 'DiagnosticLogger', 'SourceDetailContentState',
    'reconcileSourceChapterIdentity', 'protectedSourceChapterIds', 'getContext', 'mangaChapterItemFromComicChapter', 'sourceChapterDisplayRows', compiled)(
    out, exportsForTest.refreshSourceMangaDetailAndPersistLibraryStore, { exception: (...args) => errors.push(args) }, { READY: 'ready' },
    (_comic, _id, chapters) => ({ chapters, storedChapters: f.store.getComic('owned-work').chapters }), () => [], () => ({ filesDir: 'unused' }), chapter => clone(chapter), exportsForTest.sourceChapterDisplayRows)
  const page = new out.Page()
  Object.assign(page, { sourceChaptersResolved: true, sourceDetailSettingsFingerprint: '', libraryStore: f.store, libraryPersistenceService: f.service,
    isCurrentSourceDetailRequest: () => true, sourceDetailWithRouteIdentity: detail => ({ ...detail }),
    sourceComicId: () => 'owned-work', findSourceRuntimeComic: () => f.store.getComic('owned-work'),
    onLibraryChanged: () => notifications.push(true), decorateChapterStates: chapters => chapters, refreshDownloadStatus: () => {} })
  return { ...f, page, notifications, errors }
}
test('detail publication persists only the explicitly resolved snapshot, not pending data with an old resolved state', () => {
  const f = detailFixture(), entry = { manifestName: 'Owned' }
  assert.equal(f.page.applySourceMangaDetail(1, entry, 'owned-source', 'owned-remote', { title: 'Owned title' }, f.remote, '', 'loading'), true)
  assert.deepEqual(f.store.getComic('owned-work'), f.before)
  assert.equal(f.saves(), 0)
  assert.equal(f.page.applySourceMangaDetail(1, entry, 'owned-source', 'owned-remote', { title: 'Owned title' }, f.remote, '', 'ready', true), true)
  assert.equal(f.saves(), 1)
  assert.equal(f.notifications.length, 1)
  assert.equal(f.page.chapters.length, 4, 'remote and missing saved chapters remain in the manual catalog')
  assert.equal(f.store.getComic('owned-work').chapters.length, 3, 'display projection must not add stored rows')
})
test('stale detail epoch and unresolved directories cannot write sequence metadata', () => {
  const f = detailFixture()
  f.page.isCurrentSourceDetailRequest = () => false
  assert.equal(f.page.applySourceMangaDetail(0, {}, 'owned-source', 'owned-remote', { title: 'Owned title' }, f.remote, '', 'ready', true), false)
  f.page.isCurrentSourceDetailRequest = () => true; f.page.sourceChaptersResolved = false
  assert.equal(f.page.applySourceMangaDetail(1, {}, 'owned-source', 'owned-remote', { title: 'Owned title' }, f.remote, '', 'ready', true), true)
  assert.equal(f.saves(), 0); assert.equal(f.notifications.length, 0)
  assert.deepEqual(f.store.getComic('owned-work'), f.before)
})
test('detail persistence failure keeps readable detail and catalog without publishing a false library change', () => {
  const f = detailFixture()
  f.page.libraryPersistenceService = { persist() { throw new Error('owned failure') } }
  assert.equal(f.page.applySourceMangaDetail(1, {}, 'owned-source', 'owned-remote', { title: 'Real detail' }, f.remote, '', 'ready', true), true)
  assert.equal(f.page.manga.title, 'Real detail')
  assert.equal(f.notifications.length, 0); assert.equal(f.errors.length, 1)
  assert.deepEqual(f.store.getComic('owned-work'), f.before)
})

// Rich detail is now part of the existing library document, not an independent
// disk cache. Execute its real serializer/hydrator and the real update transaction.
test('collected rich detail survives library serialization and equal refreshes do not write again', () => {
  const exports = {}, all = productionFunctions('LibraryPersistence')
  const helpers = productionFunctions('ComicModels')
  const code = ts.transpileModule(helpers + '\n' + all, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  const kinds = { PRIVATE_LIBRARY: 'private_library', LOCAL_ARCHIVE: 'local_archive', LOCAL_FOLDER: 'local_folder',
    KOMGA_REMOTE: 'komga_remote', KAVITA_REMOTE: 'kavita_remote', OPDS_REMOTE: 'opds_remote', WEBDAV_REMOTE: 'webdav_remote' }
  new Function('exports', 'ComicSourceKind', 'ReadingDirection', code)(exports, kinds, { RIGHT_TO_LEFT: 'right_to_left' })
  const f = fixture(), previous = f.store.getComic('owned-work')
  Object.assign(previous, { sourcePath: 'https://source.invalid/work', sortTitle: 'owned title', preferredDirection: 'right_to_left',
    chapters: [], chapterCount: 0, pageCount: 0 })
  const detail = { title: 'Fresh title', description: 'Full description', author: 'Author', artist: 'Artist',
    status: 'ongoing', tags: ['A', 'B'], webUrl: 'https://source.invalid/work', coverUrl: 'https://owned.invalid/new' }
  const refreshDetail = exportsForTest.refreshSourceMangaDetailAndPersistLibraryStore
  assert.equal(refreshDetail(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', detail, [], true, ['hidden'], 'digest'), true)
  delete f.store.getComic('owned-work').localMetadata
  const stored = exports.persistComic(f.store.getComic('owned-work'))
  const restored = exports.hydrateComic(JSON.parse(JSON.stringify(stored)))
  assert.equal(restored.subtitle, 'Full description')
  assert.equal(restored.sourceMetadata.artist, 'Artist')
  assert.deepEqual(restored.sourceMetadata.tags, ['A', 'B'])
  assert.deepEqual(restored.sourceMetadata.excludedChapterIds, ['hidden'])
  assert.deepEqual(restored.categoryIds, ['owned-category'])
  assert.equal(restored.createdAt, 1)
  assert.equal(refreshDetail(f.store, f.service, 'owned-work', 'owned-source', 'owned-remote', detail, [], true, ['hidden'], 'digest'), false)
  assert.equal(f.saves(), 1)
  delete stored.sourceMetadata
  assert.equal(exports.hydrateComic(stored).sourceMetadata, undefined, 'old library documents remain valid')
})
