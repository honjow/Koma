const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm')
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root=path.resolve(__dirname,'../entry/src/main/ets'),modules=new Map(),values=new Map()
const { createRdbPort } = require('./user_data_rdb_fixture.cjs')
const rdb = createRdbPort()
test.after(() => rdb.close())
const preference={has:async k=>values.has(k),get:async(k,d)=>values.get(k)??d,getSync:(k,d)=>values.get(k)??d,getAll:async()=>Object.fromEntries(values),
  put:async(k,v)=>values.set(k,v),delete:async k=>values.delete(k),flush:async()=>{}}
const ports={
  '@kit.ArkData':{relationalStore:rdb.relationalStore,preferences:{getPreferences:async()=>preference,getPreferencesSync:()=>preference}},
  'libkoma_source_runtime.so': {},
  '../i18n/AppStrings':{AppStrings:{get:k=>k,format:(k,...v)=>k+v.join(',')}},
  '../sourceRuntime/SourceRuntimeAppRegistry':{sourceChapterOrderFor:()=>undefined},
  '../diagnostics/DiagnosticLogger':{DiagnosticLogger:{debug(){},warn(){},exception(){}}},
}
function load(file){
 if(modules.has(file))return modules.get(file)
 const exports={};modules.set(file,exports)
 const source=fs.readFileSync(path.join(root,file+'.ets'),'utf8').replace(/@Concurrent\s*/g,'')
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
 vm.runInNewContext(js,{exports,console,Map,Set,Date,setTimeout,clearTimeout,
  ObservedV2: () => {},Trace: () => {},$r: name => name,require(name){
  if(ports[name])return ports[name]
  if(name.startsWith('@kit.'))return {}
  if(name.startsWith('.'))return load(path.posix.normalize(path.posix.join(path.posix.dirname(file),name)))
  throw Error('Missing port '+name)
 }},{filename:file+'.ets'})
 return exports
}
const clone=v=>JSON.parse(JSON.stringify(v)),smart=load('model/LibrarySmartCategory'),models=load('model/ComicModels')
const {InMemoryLibraryStore}=load('model/LibraryStore'),{InMemoryReaderSessionStore}=load('model/ReaderSessionStore')
const persistence=load('model/LibraryPersistence'),{TrackerPreferencesStore}=load('model/TrackerModels')
const { privateLibraryCategoryIds, showLibraryComic } = load('model/LibraryPrivacyVisibility')
function book(id,source=id){return {id,title:id,sortTitle:id,sourceKind:models.ComicSourceKind.PRIVATE_LIBRARY,sourceRuntimeId:source,
 sourcePath:'https://owned.invalid/'+id,preferredDirection:'right_to_left',chapterCount:2,pageCount:2,createdAt:1,updatedAt:1,lastImportedAt:1,
 chapters:[0,1].map(index=>({id:id+index,comicId:id,title:''+index,index,pageCount:1,pages:[],createdAt:1,updatedAt:1,sortKey:''+index,sourcePath:''+index}))}}
const rule=(method,value,exclude=false)=>({method,value,exclude})
const group=filters=>({id:'smart:1',name:'Smart',sortOrder:0,createdAt:1,updatedAt:1,filters})
function shelfSubject(names, globals = {}) {
 const file = path.join(root, 'pages/LibraryPage.ets')
 const source = fs.readFileSync(file, 'utf8').replace(/\bstruct LibraryPage\b/, 'class LibraryPage')
 const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
 const owner = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'LibraryPage')
 const members = names.map(name => owner.members.find(node => node.name?.text === name)).filter(Boolean)
  .map(method => method.getText(tree))
 const code = ts.transpileModule(`class Shelf { ${members.join('\n')} }; Shelf`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, experimentalDecorators: true },
 }).outputText
 return vm.runInNewContext(code, { Monitor: () => () => {}, ...globals })
}
test('the shelf publishes the selected sort and direction in the same refresh', () => {
 const library = new InMemoryLibraryStore()
 const reader = new InMemoryReaderSessionStore()
 const { librarySortDirection } = load('model/LibraryStore')
 const { effectiveLibraryDefaultSort } = load('model/LibraryFilterStore')
 const category = library.createCustomCategory('Manual')
 const books = ['a', 'b', 'c'].map(id => book(id))
 books[0].categoryIds = [category.id]
 books[1].categoryIds = [category.id]
 books.forEach(comic => library.addComic(comic))
 const progress = new Map(books.map((comic, index) => [comic.id, {
  comicId: comic.id, chapterId: comic.chapters[0].id, updatedAt: [10, 30, 20][index],
 }]))
 const updates = new Map([['a', 20], ['b', 10], ['c', 30]])
 let frame = 0
 const Shelf = shelfSubject(['setSortBy', 'refreshDisplayedSnapshotFromStore', 'applyCategorySort',
  'orderedShelfComics', 'orderedShelfCategories', 'orderedCategoryComics', 'currentListOptions',
  'syncDisplayedSnapshotFromProps', 'applyWorkReadingChange', 'usesLiveShelfFiltersOrSort'], {
  librarySortDirection, effectiveLibraryDefaultSort, normalizeCategoryIds: models.normalizeCategoryIds,
  cachedLibraryChapterUpdateTimes: () => updates,
  // ArkUI recomputes a dirty @Computed getter at the next frame, not during the click.
  Computed(_owner, _name, descriptor) {
   const get = descriptor.get
   let computedAt = -1, value
   descriptor.get = function () {
    if (computedAt !== frame) {
     value = get.call(this)
     computedAt = frame
    }
    return value
   }
  },
 })
 const shelf = new Shelf()
 const pass = comics => comics
 Object.assign(shelf, {
  active: true, rootNavigation: { visible: true },
  libraryStore: library, libraryRevision: 1, readerSessionStore: reader, readerProgressRevision: 1,
  privacy: { visibleCategoryId: '' }, privateCategoryIds: new Set(),
  shelfReadingProgress: progress, filterCategory: 'all', filterReadState: 'all', filterAvailability: 'all', displayedRevision: 0,
  defaultSort: { sortBy: 'lastRead', sortDirection: 'desc', sortConfigured: true },
  validCategoryFilter() { return this.filterCategory },
  selectedSmartCategory: () => undefined,
  sourceKindsForFilter: () => undefined,
  filterSmartCategoryComics: pass, filterMetadataStatusComics: pass,
  filterAvailabilityComics: pass, filterPreciseSourceComics: pass,
  removeMissingSelectedComics() {}, markFilterPreferencesMutation() {}, saveFilterPreferences() {},
 })
 const ids = () => Array.from(shelf.displayedComics, comic => comic.id)
 shelf.refreshDisplayedSnapshotFromStore()
 assert.deepEqual(ids(), ['b', 'c', 'a'])
 shelf.setSortBy('lastUpdate', 'desc')
 assert.deepEqual(ids(), ['c', 'a', 'b'])
 frame += 1
 void shelf.orderedShelfCategories
 shelf.setSortBy('lastRead', 'desc')
 assert.deepEqual(ids(), ['b', 'c', 'a'])
 shelf.setSortBy('lastRead', 'asc')
 assert.deepEqual(ids(), ['a', 'c', 'b'])
 shelf.filterCategory = category.id
 shelf.refreshDisplayedSnapshotFromStore()
 assert.deepEqual(ids(), ['a', 'b'])
 const publishedProgress = new Map(progress)
 publishedProgress.set('a', { ...progress.get('a'), updatedAt: 40 })
 shelf.shelfReadingProgress = publishedProgress
 shelf.syncDisplayedSnapshotFromProps()
 assert.deepEqual(ids(), ['b', 'a'])
})

test('privacy survives a rename and backup restore without removing any memberships', () => {
 const store = new InMemoryLibraryStore()
 const publicCategory = store.createCustomCategory('Public')
 const firstPrivate = store.createCustomCategory('Private one')
 const secondPrivate = store.createCustomCategory('Private two')
 const comic = book('both')
 comic.categoryIds = [publicCategory.id, firstPrivate.id]
 store.addComic(comic)
 const disk = { persist() {} }
 const setPrivacy = persistence.setCustomCategoryPrivacyAndPersistLibraryStore
 setPrivacy(store, disk, firstPrivate.id, true)
 setPrivacy(store, disk, secondPrivate.id, true)
 store.renameCustomCategory(firstPrivate.id, 'Renamed')
 const restored = new InMemoryLibraryStore()
 persistence.hydrateLibraryStoreFromJson(restored, persistence.serializeLibraryStore(store))
 const restoredComic = restored.getComic(comic.id)
 const ids = privateLibraryCategoryIds(restored.listCustomCategories())
 assert.equal(showLibraryComic(restoredComic, ids), false)
 assert.equal(showLibraryComic(restoredComic, ids, publicCategory.id), false)
 assert.equal(showLibraryComic(restoredComic, ids, secondPrivate.id), false)
 assert.equal(showLibraryComic(restoredComic, ids, firstPrivate.id), true)
 assert.deepEqual(clone(restoredComic.categoryIds), comic.categoryIds)
 assert.throws(() => setPrivacy(restored, { persist() { throw Error('disk full') } }, firstPrivate.id, false), /disk full/)
 assert.equal(restored.listCustomCategories().find(category => category.id === firstPrivate.id).isPrivate, true)
 assert.equal(setPrivacy(restored, disk, firstPrivate.id, false), true)
 assert.equal(showLibraryComic(restoredComic, privateLibraryCategoryIds(restored.listCustomCategories())), true)
})

test('a privacy session spends its grace in the background and expires immediately on screen lock', async () => {
 let time = 0
 let screenLock
 let stageEvent
 const stageEvents = { ACTIVE: 2, PAUSED: 6, HIDDEN: 4, RESUMED: 5 }
 ports['@kit.ArkUI'] = { window: { WindowStageEventType: stageEvents } }
 ports['@kit.BasicServicesKit'] = {
  systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => time },
  commonEventManager: { Support: {}, createSubscriber: async () => ({}),
   async subscribeToEvent(_subscriber, onLock) { screenLock = onLock }, unsubscribe() {} },
 }
 const { LibraryPrivacyState, LibraryPrivacyAuthResult } = load('state/LibraryPrivacyState')
 const privacy = new LibraryPrivacyState()
 const windowProtection = []
 await privacy.attach({ async setWindowPrivacyMode(enabled) { windowProtection.push(enabled) } },
  { on(_event, callback) { stageEvent = callback }, off() {} })
 privacy.verify = async () => LibraryPrivacyAuthResult.SUCCESS
 assert.equal(await privacy.openCategory({}, 'first', () => true), LibraryPrivacyAuthResult.SUCCESS)
 assert.deepEqual(windowProtection, [true])
 time += 90000
 stageEvent(stageEvents.PAUSED)
 assert.equal(privacy.visibleCategoryId, '')
 assert.equal(privacy.unlocked, true)
 privacy.onBackground()
 time += 29999
 stageEvent(stageEvents.ACTIVE)
 assert.equal(privacy.visibleCategoryId, '')
 privacy.onForeground()
 assert.equal(privacy.visibleCategoryId, 'first')
 assert.equal(privacy.foregroundReauthRevision, 0)
 privacy.onBackground()
 stageEvent(stageEvents.HIDDEN)
 time += 30000
 privacy.onForeground()
 stageEvent(stageEvents.RESUMED)
 assert.equal(privacy.categoryId, 'first')
 assert.equal(privacy.visibleCategoryId, '')
 assert.equal(privacy.foregroundReauthRevision, 1)
 assert.equal(await privacy.openCategory({}, 'first', () => true), LibraryPrivacyAuthResult.SUCCESS)
 screenLock()
 assert.equal(privacy.visibleCategoryId, '')
 privacy.onBackground()
 time += 30000
 privacy.onForeground()
 assert.equal(privacy.foregroundReauthRevision, 1)
 let finish
 privacy.verify = () => new Promise(resolve => { finish = resolve })
 const pending = privacy.openCategory({}, 'second', () => true)
 privacy.leaveCategory()
 finish(LibraryPrivacyAuthResult.SUCCESS)
 assert.equal(await pending, LibraryPrivacyAuthResult.CANCELED)
 assert.equal(privacy.visibleCategoryId, '')
 assert.equal(windowProtection.at(-1), false)
 delete ports['@kit.BasicServicesKit']
 delete ports['@kit.ArkUI']
})
test('positive source/category values are OR, methods are AND and exclusions do not rewrite manual membership',()=>{
 const a=book('a'),b=book('b'),c=book('c');a.categoryIds=['favorite'];b.categoryIds=['read_later']
 const context={reader:new InMemoryReaderSessionStore(),downloaded:new Set(),tracked:new Set()}
 const selected=group([rule('source','source:a'),rule('source','source:b'),rule('category','favorite'),rule('category','read_later')])
 assert.equal(smart.comicMatchesSmartCategory(a,selected,context),true)
 assert.equal(smart.comicMatchesSmartCategory(b,selected,context),true)
 assert.equal(smart.comicMatchesSmartCategory(c,selected,context),false)
 const before=clone(a.categoryIds);selected.filters.push(rule('category','favorite',true))
 assert.equal(smart.comicMatchesSmartCategory(a,selected,context),false);assert.deepEqual(clone(a.categoryIds),before)
 assert.equal(smart.comicSmartContentRating(a),'unknown','Source identity never invents work classification')
})
test('reading/download/tracking facts dynamically change membership, publication status is separate from read completion',()=>{
 const a=book('a'),reader=new InMemoryReaderSessionStore(),downloaded=new Set(),tracked=new Set(),context={reader,downloaded,tracked}
 const selected=group([rule('downloaded'),rule('tracking'),rule('hasUnread'),rule('started'),rule('completed')])
 assert.equal(smart.comicMatchesSmartCategory(a,selected,context),false)
 downloaded.add('a');tracked.add('a');reader.commitChapterReadStates([{comicId:'a',chapterId:'a0',isRead:true}]);a.sourceMetadata={status:'completed',contentRating:'safe'}
 assert.equal(smart.comicMatchesSmartCategory(a,selected,context),true)
 reader.commitChapterReadStates([{comicId:'a',chapterId:'a1',isRead:true}])
 assert.equal(smart.comicMatchesSmartCategory(a,selected,context),false)
})
test('returning to the shelf picks up new download facts with unchanged book and progress revisions', () => {
 const Shelf = shelfSubject(['syncDisplayedSnapshotFromProps', 'usesLiveShelfFiltersOrSort', 'selectedSmartCategory'])
 const shelf = new Shelf(), library = new InMemoryLibraryStore(), reader = new InMemoryReaderSessionStore()
 const comic = book('offline'), downloaded = new Set()
 const readingProgress = new Map()
 library.replaceSmartCategories([group([rule('downloaded')])])
 Object.assign(shelf, {
  active: false, rootNavigation: { visible: true }, filterAvailability: 'all', filterCategory: 'smart:1', sortBy: 'title',
  displayedLibraryRevision: 3, libraryRevision: 3, displayedProgressRevision: 5, readerProgressRevision: 5,
  displayedLibraryStore: library, libraryStore: library, displayedSessionStore: reader, readerSessionStore: reader,
  displayedReadingProgress: readingProgress, shelfReadingProgress: readingProgress, visibleIds: [],
  refreshDisplayedSnapshotFromStore() {
   const matches = smart.comicMatchesSmartCategory(comic, this.selectedSmartCategory(), { reader, downloaded, tracked: new Set() })
   this.visibleIds = matches ? [comic.id] : []
  },
 })
 downloaded.add(comic.id)
 shelf.syncDisplayedSnapshotFromProps()
 assert.deepEqual(shelf.visibleIds, [])
 shelf.active = true
 shelf.syncDisplayedSnapshotFromProps()
 assert.deepEqual(shelf.visibleIds, [comic.id])
 downloaded.delete(comic.id)
 shelf.syncDisplayedSnapshotFromProps()
 assert.deepEqual(shelf.visibleIds, [])
})
test('a visible ordinary shelf updates its download filter on completion and removal', () => {
 const { OfflineDownloadRuntime } = load('model/OfflineDownloadRuntime')
 const filesDir = '/visible-shelf-download-filter'
 const Shelf = shelfSubject(['aboutToAppear', 'filterAvailabilityComics'], {
  OfflineDownloadRuntime, TrackerPreferencesStore, komaRuntimeStorageKey: context => context.filesDir,
 })
 const shelf = new Shelf(), comic = book('offline'), availability = new Map()
 Object.assign(shelf, {
  active: true, rootNavigation: { visible: true }, filterAvailability: 'downloaded',
  getUIContext: () => ({ getHostContext: () => ({ filesDir }) }), selectedSmartCategory: () => undefined,
  restoreInitialFilterPreferences() {}, syncDisplayedSnapshotFromProps() {}, updateGridRows() {}, publishTitleBar() {},
  downloadedComicAvailability: () => availability,
  refreshDisplayedSnapshotFromStore() { this.visibleIds = Array.from(this.filterAvailabilityComics([comic]), row => row.id) },
 })
 shelf.aboutToAppear()
 try {
  shelf.refreshDisplayedSnapshotFromStore()
  const initialResults = shelf.visibleIds
  OfflineDownloadRuntime.publishProgress(filesDir)
  assert.equal(shelf.visibleIds, initialResults)
  availability.set(comic.id, 'downloaded')
  OfflineDownloadRuntime.publish(filesDir)
  assert.deepEqual(shelf.visibleIds, [comic.id])
  availability.delete(comic.id)
  OfflineDownloadRuntime.publish(filesDir)
  assert.deepEqual(shelf.visibleIds, [])
 } finally {
  shelf.smartSubscriptions.forEach(unsubscribe => unsubscribe())
 }
})
test('rules and work rating survive library/backup serialization; failed persistence retains the original groups',()=>{
 const library=new InMemoryLibraryStore(),a=book('a');a.sourceMetadata={contentRating:'safe'};library.addComic(a)
 const detail=load('model/MangaDetailModels').parseMangaDetailFromSourceItem('rated-source',{id:'rated',title:'Rated work',content_rating:'suggestive'})
 const rated=load('model/SourceLibraryComic').comicFromSourceManga(detail,[],'rated-work')
 assert.equal(rated.sourceMetadata.contentRating,'suggestive');library.addComic(rated)
 const manual=library.createCustomCategory('Manual',1);const selected=group([rule('category',manual.id)])
 let disk;persistence.replaceSmartCategoriesAndPersistLibraryStore(library,{persist(){disk=persistence.serializeLibraryStore(library)}},[selected])
 assert.equal(library.listCustomCategories().length,1,'Smart categories are absent from assignment/automation choices')
 const restored=new InMemoryLibraryStore();persistence.hydrateLibraryStoreFromJson(restored,disk)
 assert.deepEqual(clone(restored.listSmartCategories()),[selected]);assert.equal(restored.getComic('a').sourceMetadata.contentRating,'safe')
 assert.throws(()=>persistence.replaceSmartCategoriesAndPersistLibraryStore(library,{persist(){throw Error('disk full')}},[]),/disk full/)
 assert.deepEqual(clone(library.listSmartCategories()),[selected])
 assert.throws(()=>library.renameCustomCategory(manual.id,'Smart'),/duplicate/)
})
test('a used preset becomes an editable category while a fresh shelf stays empty of manual categories', () => {
 const library = new InMemoryLibraryStore()
 const empty = persistence.serializeLibraryStore(library)
 assert.equal(persistence.readLibraryStoreDocument(empty).customCategories, undefined)
 const existing = book('existing')
 existing.categoryIds = ['favorite']
 library.addComic(existing)
 persistence.hydrateLibraryStoreFromJson(library, persistence.serializeLibraryStore(library))
 assert.deepEqual(clone(library.listCustomCategories().map(category => category.id)), ['favorite'])
 library.renameCustomCategory('favorite', 'Keep')
 persistence.hydrateLibraryStoreFromJson(library, persistence.serializeLibraryStore(library))
 assert.equal(library.listCustomCategories()[0].name, 'Keep')
 assert.equal(library.deleteCustomCategory('favorite'), true)
 persistence.hydrateLibraryStoreFromJson(library, persistence.serializeLibraryStore(library))
 assert.equal(library.listCustomCategories().length, 0)
 assert.equal(library.listLibraryItems(undefined, { filterCategoryId: 'all' }).length, 1)
})
test('batch editing preserves untouched mixed memberships, saves once and rolls back on failure', () => {
 const library = new InMemoryLibraryStore()
 const a = library.createCustomCategory('A'), b = library.createCustomCategory('B')
 const first = book('first')
 first.categoryIds = [a.id]
 library.addComic(first)
 library.addComic(book('second'))
 let saves = 0
 const edit = persistence.editComicCategoriesAndPersistLibraryStore
 const selected = ['first', 'second']
 const disk = new persistence.LibraryStorePersistenceService(library, { load() {}, save() { saves++ } })
 assert.equal(edit(library, disk, selected, [b.id], []), 2)
 assert.deepEqual(clone(library.getComic('first').categoryIds), [a.id, b.id])
 assert.deepEqual(clone(library.getComic('second').categoryIds), [b.id])
 assert.equal(edit(library, disk, selected, [b.id], []), 0)
 assert.equal(saves, 1)
 const fullDisk = new persistence.LibraryStorePersistenceService(library, { load() {}, save() { throw Error('disk full') } })
 assert.throws(() => edit(library, fullDisk, selected, [], [a.id, b.id]), /disk full/)
 assert.deepEqual(clone(library.getComic('first').categoryIds), [a.id, b.id])
 assert.equal(edit(library, disk, selected, [], [a.id, b.id]), 2)
 assert.equal(library.listLibraryItems(undefined, { filterCategoryId: 'all' }).length, 2)
 assert.equal(library.listLibraryItems(undefined, { filterCategoryId: b.id }).length, 0)
})
test('a new favorite saves initial memberships and emits them with the shelf addition', () => {
 const library = new InMemoryLibraryStore()
 const category = library.createCustomCategory('Manual')
 const comic = book('favorite')
 comic.remoteResourceId = 'work'
 comic.categoryIds = [category.id]
 const batches = []
 const signals = load('deviceSync/DeviceSyncSignals')
 signals.connectDeviceSyncOwnerEdits(actions => batches.push(clone(actions)), () => {}, () => {}, () => undefined)
 try {
  assert.throws(() => persistence.upsertComicAndPersistLibraryStore(library, { persist() { throw Error('disk full') } }, comic), /disk full/)
  assert.equal(library.getComic(comic.id), undefined)
  assert.equal(batches.length, 0)
  let saves = 0
  persistence.upsertComicAndPersistLibraryStore(library, { persist() {
   saves++
   assert.deepEqual(clone(library.getComic(comic.id).categoryIds), [category.id])
  } }, comic)
  assert.equal(saves, 1)
  assert.deepEqual(batches, [[
   { kind: 'add-book', source: 'favorite', work: 'work' },
   { kind: 'add-member', source: 'favorite', work: 'work', category: category.id },
  ]])
 } finally {
  signals.connectDeviceSyncOwnerEdits(() => {}, () => {}, () => {}, () => undefined)
 }
})
test('tracker mapping projection publishes only committed public mappings and refreshes after backup replacement',async()=>{
 const store=new TrackerPreferencesStore({filesDir:'/smart-test'}),seen=[]
 const stop=store.subscribeMappings(()=>seen.push(clone(store.mappingSnapshot())))
 const mapping={comicId:'a',providerId:'anilist',providerTitleId:'123',mappingState:'confirmed',userConfirmed:true,createdAt:1}
 await store.saveComicMappings([mapping]);assert.equal(seen.length,1);assert.equal(store.mappingSnapshot()[0].comicId,'a')
 rdb.failNextCommit('disk full');await assert.rejects(store.saveComicMappings([]),/disk full/)
 assert.equal(seen.length,1);assert.equal(store.mappingSnapshot().length,1)
 const {BackupRestoreActivity}=load('model/BackupRestoreActivity')
 BackupRestoreActivity.beginRestore();await store.saveComicMappingsForBackupRestore([]);BackupRestoreActivity.finishRestore()
 store.invalidateMappingSnapshot();assert.equal(seen.length,2);assert.equal(store.mappingSnapshot().length,0)
 stop()
})
