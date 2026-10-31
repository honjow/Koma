const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm')
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root=path.resolve(__dirname,'../entry/src/main/ets'),modules=new Map(),values=new Map()
let failFlush=false
const preference={has:async k=>values.has(k),get:async(k,d)=>values.get(k)??d,getSync:(k,d)=>values.get(k)??d,
  put:async(k,v)=>values.set(k,v),delete:async k=>values.delete(k),flush:async()=>{if(failFlush){failFlush=false;throw Error('disk full')}}}
const ports={
  '@kit.ArkData':{preferences:{getPreferences:async()=>preference,getPreferencesSync:()=>preference}},
  '../i18n/AppStrings':{AppStrings:{get:k=>k,format:(k,...v)=>k+v.join(',')}},
  '../sourceRuntime/SourceRuntimeAppRegistry':{sourceChapterOrderFor:()=>undefined},
  '../diagnostics/DiagnosticLogger':{DiagnosticLogger:{warn(){},exception(){}}},
}
function load(file){
 if(modules.has(file))return modules.get(file)
 const exports={};modules.set(file,exports)
 const source=fs.readFileSync(path.join(root,file+'.ets'),'utf8').replace(/@Concurrent\s*/g,'')
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
 vm.runInNewContext(js,{exports,console,Map,Set,Date,setTimeout,clearTimeout,require(name){
  if(ports[name])return ports[name]
  if(name.startsWith('@kit.'))return {}
  if(name.startsWith('.'))return load(path.posix.normalize(path.posix.join(path.posix.dirname(file),name)))
  throw Error('Missing port '+name)
 }})
 return exports
}
const clone=v=>JSON.parse(JSON.stringify(v)),smart=load('model/LibrarySmartCategory'),models=load('model/ComicModels')
const {InMemoryLibraryStore}=load('model/LibraryStore'),{InMemoryReaderSessionStore}=load('model/ReaderSessionStore')
const persistence=load('model/LibraryPersistence'),{TrackerPreferencesStore}=load('model/TrackerModels')
function book(id,source=id){return {id,title:id,sortTitle:id,sourceKind:models.ComicSourceKind.PRIVATE_LIBRARY,sourceRuntimeId:source,
 sourcePath:'https://owned.invalid/'+id,preferredDirection:'right_to_left',chapterCount:2,pageCount:2,createdAt:1,updatedAt:1,lastImportedAt:1,
 chapters:[0,1].map(index=>({id:id+index,comicId:id,title:''+index,index,pageCount:1,pages:[],createdAt:1,updatedAt:1,sortKey:''+index,sourcePath:''+index}))}}
const rule=(method,value,exclude=false)=>({method,value,exclude})
const group=filters=>({id:'smart:1',name:'Smart',sortOrder:0,createdAt:1,updatedAt:1,filters})
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
test('tracker mapping projection publishes only committed public mappings and refreshes after backup replacement',async()=>{
 const store=new TrackerPreferencesStore({filesDir:'/smart-test'}),seen=[]
 const stop=store.subscribeMappings(()=>seen.push(clone(store.mappingSnapshot())))
 const mapping={comicId:'a',providerId:'anilist',providerTitleId:'123',mappingState:'confirmed',userConfirmed:true,createdAt:1}
 await store.saveComicMappings([mapping]);assert.equal(seen.length,1);assert.equal(store.mappingSnapshot()[0].comicId,'a')
 failFlush=true;await assert.rejects(store.saveComicMappings([]),/disk full/)
 assert.equal(seen.length,1);assert.equal(store.mappingSnapshot().length,1)
 values.set('tracker.comicMappings','[]');store.invalidateMappingSnapshot();assert.equal(seen.length,2);assert.equal(store.mappingSnapshot().length,0)
 stop()
})
