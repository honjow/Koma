const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const root=path.resolve(__dirname,'..');
function load(name,deps={}) {const module={exports:{}};const source=fs.readFileSync(path.join(root,'entry/src/main/ets/model/'+name+'.ets'),'utf8').replace(/@Concurrent\s*/g,'');new Function('require','module','exports',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(n=>{assert.ok(n in deps,'missing '+n);return deps[n]},module,module.exports);return module.exports}
const metadataText=fs.readFileSync(path.join(root,'entry/src/main/ets/sourceRuntime/SourceIndexMetadata.ets'),'utf8');
const metadataAst=ts.createSourceFile('metadata.ts',metadataText,ts.ScriptTarget.Latest,true);
const parseDocumentSource=metadataAst.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text==='parseIndexEntriesDocument').getText(metadataAst);
const metadataModule={exports:{}};
new Function('module','exports',ts.transpileModule(parseDocumentSource,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(metadataModule,metadataModule.exports);
const {parseIndexEntriesDocument}=metadataModule.exports;
const rules=load('ImageBannerRules');const {ImageBannerDetector:detector}=load('ImageBannerDetector',{'./ImageBannerRules':rules});
const pack=rules.validateImageRulePack(JSON.parse(fs.readFileSync(path.join(root,'scripts/fixtures/image-rules-edge.json'),'utf8')));
const snapshot={schemaVersion:1,records:[{origin:'subscription-a',revision:'1',packs:[pack]}]};
assert.equal(rules.imageBannerPlans(snapshot,'source').length,0);
assert.equal(rules.effectiveBannerFilter('auto','off'),'off');assert.equal(rules.effectiveBannerFilter('auto','global'),'auto');
assert.equal(rules.imageBannerPlans(snapshot,'off',{kind:'baozi_banner',mode:'2'}).length,0);
assert.equal(rules.imageBannerPlans(snapshot,'source',{kind:'baozi_banner',mode:'0'}).length,0);
assert.equal(rules.imageBannerPlans(snapshot,'source',{kind:'baozi_banner',mode:'1'})[0].mode,'1');
assert.equal(rules.imageBannerPlans(snapshot,'auto').length,1);
assert.equal(rules.canDiscoverSourceImageProcessing(snapshot,'online.baozimh.koma'),true);
assert.equal(rules.canDiscoverSourceImageProcessing(snapshot,'other-source'),false);
assert.equal(rules.imageBannerPlans({...snapshot,records:snapshot.records.concat(snapshot.records)},'auto').length,1);
const bad=structuredClone(pack);bad.rules[0].signatures[0].averages.pop();assert.throws(()=>rules.validateImageRulePack(bad));
function synthetic(width,height,strips) {return {width,height,async readRegion(x,y,w,h){const pixels=new Uint8Array(w*h*4);for(let row=0;row<h;row++){const strip=strips.find(s=>y+row>=s.y && y+row<s.y+s.signature.height);const rgb=strip?strip.signature.averages.slice((y+row-strip.y)*3,(y+row-strip.y)*3+3):[18,29,41];for(let col=0;col<w;col++){const i=(row*w+col)*4;pixels[i]=rgb[2];pixels[i+1]=rgb[1];pixels[i+2]=rgb[0];pixels[i+3]=255}}return pixels}}}
(async()=>{
 // Execute the production original-cache dispatch with a controlled runtime resolver.
 // Existing cached pages must not acquire a new source/network dependency.
 const adapterText=fs.readFileSync(path.join(root,'entry/src/main/ets/model/ReaderPageSourceAdapter.ets'),'utf8');
 const adapterAst=ts.createSourceFile('adapter.ts',adapterText,ts.ScriptTarget.Latest,true);
 const selected=new Set(['sourceImageMangaRoute','sourceImageProcessingFingerprint','fetchAndCacheSourceRuntimeRemoteImage','prepareSourcePagePresentation','sourceTextRequestCurrent']);
 const adapterFunctions=adapterAst.statements.filter(n=>ts.isFunctionDeclaration(n)&&selected.has(n.name?.text)).map(n=>n.getText(adapterAst)).join('\n')+'\nexport { prepareSourcePagePresentation };';
 let runtimeRequests=0,hasOriginal=true,failRuntime=false,version='1',wasmPath='/installed/1',declaredHint={kind:'baozi_banner',mode:'1'};
 const hints=new Map();const entry={sourceId:'legacy-source',manifestVersion:version,wasmPath,enabled:true};
 const cacheDependencies={
  readerImageCacheStore:{get:async(url,_headers,key)=>url==='source-image-processing.json'?(hints.has(key)?key:undefined):(hasOriginal?'/raw':undefined),
   put:async(_url,_headers,bytes,key)=>{hints.set(key,Buffer.from(bytes).toString());return key},getOrFetch:async()=>'/fresh'},
  appSourceRuntimeRegistry:{lookup:()=>({ok:true,entry})},appSourceSettingsStore:{loadForSource:()=>({banner:'normal'})},
  sourceSettingsFingerprint:v=>JSON.stringify(v),SourceWorkerPriority:{FOREGROUND:0},
  fs:{readText:async key=>hints.get(key)},util:{TextEncoder:class{encodeInto(v){return Uint8Array.from(Buffer.from(v))}}},
  resolveSourceRuntimeImageRequest:async()=>{runtimeRequests++;if(failRuntime)throw Error('source unavailable');return {url:'https://images.test/page',imageProcessing:declaredHint}},
  maintainReaderImageCacheAfterWrite:async()=>{},downloadReaderRemoteBytes:async()=>new ArrayBuffer(0),
  canDiscoverSourceImageProcessing:rules.canDiscoverSourceImageProcessing,imageBannerPlans:rules.imageBannerPlans,
  ImageBannerService:{prepare:async(path,plans)=>plans.length?'/filtered':path},
 };
 const adapterModule={exports:{}};
 new Function(...Object.keys(cacheDependencies),'module','exports',ts.transpileModule(adapterFunctions,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(...Object.values(cacheDependencies),adapterModule,adapterModule.exports);
 const fetchCached=adapterModule.exports.fetchAndCacheSourceRuntimeRemoteImage;
 let received;const receive=hint=>{received=hint};
 await fetchCached('other-source','https://images.test/page','page','',false,0,receive,false);
 assert.equal(runtimeRequests,0,'unrelated cached page must stay instant');assert.equal(hints.size,0,'unknown is not a resolved absence');
 await fetchCached('legacy-source','https://images.test/page','page','',false,0,receive,false);
 assert.equal(runtimeRequests,0,'Auto/Off never discover old source metadata');
 await fetchCached('legacy-source','https://images.test/page','page','',false,0,receive,true);
 assert.equal(runtimeRequests,1);assert.deepEqual(received,declaredHint);
 await fetchCached('legacy-source','https://images.test/page','page','',false,0,receive,true);
 assert.equal(runtimeRequests,1,'resolved hint persists beside original');
 entry.manifestVersion='2';await fetchCached('legacy-source','https://images.test/page','page','',false,0,receive,true);
 assert.equal(runtimeRequests,2,'source replacement invalidates processing declaration');
 entry.wasmPath='/installed/2';await fetchCached('legacy-source','https://images.test/page','page','',false,0,receive,true);
 assert.equal(runtimeRequests,3,'same-version reinstall also invalidates declaration');
 hasOriginal=false;await fetchCached('other-source','https://images.test/new','new','',false,0,receive,false);
 assert.equal(runtimeRequests,4);assert.deepEqual(received,declaredHint,'fresh declaration works outside legacy producer IDs');
 entry.enabled=false;
 assert.equal(await adapterModule.exports.prepareSourcePagePresentation({sourceRuntimeId:'legacy-source',imageProcessing:declaredHint},'/downloaded',{}, {snapshot,policy:'source'}),'/filtered','disabled source cannot invalidate a downloaded declaration');
 assert.equal(await adapterModule.exports.prepareSourcePagePresentation({sourceRuntimeId:'other-source'},'/downloaded',{}, {snapshot,policy:'auto'}),'/filtered');
 assert.equal(runtimeRequests,4,'offline filtering never needs a disabled source runtime');
 hasOriginal=true;failRuntime=true;const hintsBeforeFailure=hints.size;
 assert.equal(await fetchCached('legacy-source','https://images.test/cached-old','old','',false,0,receive,true),'/raw');
 assert.equal(received,undefined);assert.equal(hints.size,hintsBeforeFailure,'failed discovery cannot persist absence');
 hasOriginal=false;await assert.rejects(fetchCached('legacy-source','https://images.test/new-failed','failed','',false,0,receive,true),/source unavailable/);
 const rule=pack.rules[0],current=rule.signatures[0],old=rule.signatures[1];
 assert.deepEqual(await detector.detect(synthetic(800,1500,[{y:0,signature:current},{y:1218,signature:old}]),rule,'1'),{top:200,bottom:0});
 assert.deepEqual(await detector.detect(synthetic(800,1500,[{y:0,signature:current},{y:200,signature:old},{y:1218,signature:old}]),rule,'2'),{top:482,bottom:282});
 assert.deepEqual(await detector.detect(synthetic(800,1500,[]),rule,'2'),{top:0,bottom:0});
 // Explicit subscriptions exercise production storage and update code with platform adapters.
 const files=new Map();let failWrite=false;const requests=new Map();const crypto=require('node:crypto');
 const indexUrl='https://rules.test/index.json',packUrl='https://rules.test/packs/rule.json';
 const subscribedPack=structuredClone(pack);subscribedPack.rules.push({...structuredClone(pack.rules[0]),id:'second-rule',name:'Second edge pattern'});
 const resource=Buffer.from(JSON.stringify(subscribedPack)),digest=crypto.createHash('sha256').update(resource).digest('hex');
 const index={schemaVersion:1,kind:'image_rules',meta:{name:'Visible rules',description:'Two independently managed rules'},revision:digest,packs:[{id:pack.id,version:pack.version,path:'packs/rule.json',sha256:digest}]};
 requests.set(indexUrl,Buffer.from(JSON.stringify(index)));requests.set(packUrl,resource);
 let networkCalls=0,gate,waitForIndex=false;const state={dataRevision:0,userRevision:0,enabledRuleCount:0};
 const {ImageRuleStore,subscriptionDocumentKind}=load('ImageRuleStore',{
  '@kit.ArkTS':{taskpool:{execute:async(fn,...args)=>fn(...args)},util:{TextDecoder:{create:()=>({decodeToString:bytes=>Buffer.from(bytes).toString('utf8')})}}},
  '@kit.CoreFileKit':{fileIo:{accessSync:p=>files.has(p),statSync:p=>({size:files.get(p).length}),readTextSync:p=>files.get(p)}},
  '@kit.NetworkKit':{http:{RequestMethod:{GET:0},HttpDataType:{ARRAY_BUFFER:0},createHttp:()=>({request:async url=>{networkCalls++;if(waitForIndex&&url===indexUrl)await new Promise(resolve=>{gate=resolve});const b=requests.get(url);return {responseCode:b?200:500,result:b?Uint8Array.from(b).buffer:new ArrayBuffer(0)}},destroy(){}})}},
  '@kit.CryptoArchitectureKit':{cryptoFramework:{createMd:()=>{const h=crypto.createHash('sha256');return {updateSync:v=>h.update(v.data),digestSync:()=>({data:new Uint8Array(h.digest())})}}}},
  './AppFileTextPersistence':{writeAppTextFile:(p,s)=>{if(failWrite)throw Error('disk full');files.set(p,s)}},
  './BackupRestoreActivity':{BackupRestoreActivity:{runWrite:async f=>f()}},'./ImageBannerRules':rules,
  '../state/ImageRuleState':{connectImageRuleState:()=>state},
  '../sourceRuntime/SourceIndexMetadata':{parseIndexEntriesDocument,isValidHttpUrl:v=>/^https:\/\//.test(v),resolveIndexDocumentUrl:v=>v,safeResolveIndexRelativeUrl:(b,p)=>new URL(p,b).href},
 });
 const ctx={filesDir:'/fixture',resourceManager:{getRawFileContent:async()=>{throw Error('must not read bundled rules')}}};
 const store=ImageRuleStore.forContext(ctx);assert.deepEqual(await store.list(),[]);assert.deepEqual((await store.pinned()).records,[]);assert.equal(networkCalls,0);
 assert.equal(subscriptionDocumentKind('[]'),'source');assert.equal(subscriptionDocumentKind('{"sources":[]}'),'source');assert.equal(subscriptionDocumentKind(JSON.stringify(index)),'image_rules');assert.equal(subscriptionDocumentKind('{}'),'unknown');
 await store.add(indexUrl,'');assert.equal(networkCalls,2);assert.equal(state.enabledRuleCount,2);
 const initial=await store.pinned();assert.equal(initial.records[0].origin,indexUrl);assert.equal((await store.list())[0].name,'Visible rules');
 await store.setRuleEnabled(indexUrl,pack.id,pack.rules[0].id,false);
 assert.deepEqual((await store.pinned()).records[0].packs[0].rules.map(r=>r.id),['second-rule'],'one switch cannot disable the other rule');
 assert.equal(initial.records[0].packs[0].rules.length,2,'existing reader snapshot stays immutable');
 const beforeRename=networkCalls,renameRevision=state.userRevision;await store.rename(indexUrl,'Custom name');assert.equal(networkCalls,beforeRename,'renaming is local');assert.equal(state.userRevision,renameRevision,'renaming does not reset the reader');
 await store.setEnabled(indexUrl,false);assert.deepEqual((await store.pinned()).records,[]);await store.setEnabled(indexUrl,true);
 const accepted=await store.exportSnapshot();
 requests.set(indexUrl,Buffer.from(JSON.stringify({...index,revision:'broken',packs:[{...index.packs[0],sha256:'0'.repeat(64)}]})));
 await assert.rejects(store.refresh(indexUrl));assert.deepEqual(await store.exportSnapshot(),accepted);
 failWrite=true;await assert.rejects(store.setEnabled(indexUrl,false));assert.deepEqual(await store.exportSnapshot(),accepted);failWrite=false;
 requests.set(indexUrl,Buffer.from(JSON.stringify({...index,revision:'two'})));const beforeUpdateRevision=state.userRevision;
 await store.refresh(indexUrl);assert.equal(state.userRevision,beforeUpdateRevision,'background update cannot reset current reader');
 assert.deepEqual((await store.pinned()).records[0].packs[0].rules.map(r=>r.id),['second-rule']);
 const backup=await store.exportSnapshot();await store.remove(indexUrl);assert.deepEqual(await store.list(),[]);assert.deepEqual((await store.pinned()).records,[]);
 await store.restore(backup);await store.reload();assert.deepEqual(await store.exportSnapshot(),backup);
 waitForIndex=true;const late=store.refresh(indexUrl);while(!gate)await new Promise(r=>setImmediate(r));await store.remove(indexUrl);gate();await late;waitForIndex=false;
 assert.deepEqual(await store.list(),[],'removed subscription cannot be resurrected by a late update');
 await store.restore(snapshot);assert.deepEqual(await store.list(),[],'old implicit downloads are not user-added subscriptions');
 await store.refreshAutomaticSubscriptions();assert.equal(state.enabledRuleCount,0);
 // Cache coordinator is production code; transform/decode is a controlled worker here (device proof is separate).
 let hash='raw-a',transforms=0,positive=false;const cache=new Map();
 const cacheStore={get:async(_url,_headers,key)=>cache.get(key),put:async(url,_headers,bytes,key)=>{const result='/cache/'+url+':'+key;cache.set(key,result);return result}};
 const serviceDependencies={
  '@kit.ArkTS':{taskpool:{execute:async(fn,...args)=>{if(fn.name==='sourceBannerContentHash')return hash;transforms++;return positive?new Uint8Array([1,2,3]).buffer:new ArrayBuffer(0)}}},
  '@kit.ImageKit':{},'@kit.CoreFileKit':{},'@kit.CryptoArchitectureKit':{},'./ImageBannerImageReader':{},
 './ImageBannerDetector':{ImageBannerDetector:detector},'./ImageBannerRules':rules,
 };
 const service=load('ImageBannerService',serviceDependencies).ImageBannerService;
 const plans=rules.imageBannerPlans(snapshot,'auto');
 assert.deepEqual(await Promise.all([service.prepare('/raw',plans,cacheStore),service.prepare('/raw',plans,cacheStore),service.prepare('/copy',plans,cacheStore)]),['/raw','/raw','/copy']);assert.equal(transforms,1);
 const reopenedService=load('ImageBannerService',serviceDependencies).ImageBannerService;
 assert.equal(await reopenedService.prepare('/raw',plans,cacheStore),'/raw');assert.equal(transforms,1,'no-hit survives service restart');
 hash='raw-b';positive=true;assert.match(await service.prepare('/raw',plans,cacheStore),/image-banner.jpg/);assert.equal(transforms,2);
 assert.equal(await service.prepare('/raw',[],cacheStore),'/raw');assert.equal(transforms,2,'disabled bypasses cache and transform');
 console.log('PASS: empty by default, typed subscriptions, independent rules, failed writes/updates, removal and backup; processing precedence and persistent cache');
})().catch(e=>{console.error(e);process.exitCode=1});
