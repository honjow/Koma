const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const root=path.resolve(__dirname,'..');
function load(name,deps={}) {const module={exports:{}};const source=fs.readFileSync(path.join(root,'entry/src/main/ets/model/'+name+'.ets'),'utf8').replace(/@Concurrent\s*/g,'');new Function('require','module','exports',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(n=>{assert.ok(n in deps,'missing '+n);return deps[n]},module,module.exports);return module.exports}
const rules=load('ImageBannerRules');const {ImageBannerDetector:detector}=load('ImageBannerDetector',{'./ImageBannerRules':rules});
const pack=rules.validateImageRulePack(JSON.parse(fs.readFileSync(path.join(root,'entry/src/main/resources/rawfile/image-rules-bootstrap.json'),'utf8')));
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
 let runtimeRequests=0,hasOriginal=true,version='1',wasmPath='/installed/1',declaredHint={kind:'baozi_banner',mode:'1'};
 const hints=new Map();const entry={sourceId:'legacy-source',manifestVersion:version,wasmPath,enabled:true};
 const cacheDependencies={
  readerImageCacheStore:{get:async(url,_headers,key)=>url==='source-image-processing.json'?(hints.has(key)?key:undefined):(hasOriginal?'/raw':undefined),
   put:async(_url,_headers,bytes,key)=>{hints.set(key,Buffer.from(bytes).toString());return key},getOrFetch:async()=>'/fresh'},
  appSourceRuntimeRegistry:{lookup:()=>({ok:true,entry})},appSourceSettingsStore:{loadForSource:()=>({banner:'normal'})},
  sourceSettingsFingerprint:v=>JSON.stringify(v),SourceWorkerPriority:{FOREGROUND:0},
  fs:{readText:async key=>hints.get(key)},util:{TextEncoder:class{encodeInto(v){return Uint8Array.from(Buffer.from(v))}}},
  resolveSourceRuntimeImageRequest:async()=>{runtimeRequests++;return {url:'https://images.test/page',imageProcessing:declaredHint}},
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
 const rule=pack.rules[0],current=rule.signatures[0],old=rule.signatures[1];
 assert.deepEqual(await detector.detect(synthetic(800,1500,[{y:0,signature:current},{y:1218,signature:old}]),rule,'1'),{top:200,bottom:0});
 assert.deepEqual(await detector.detect(synthetic(800,1500,[{y:0,signature:current},{y:200,signature:old},{y:1218,signature:old}]),rule,'2'),{top:482,bottom:282});
 assert.deepEqual(await detector.detect(synthetic(800,1500,[]),rule,'2'),{top:0,bottom:0});
 // Exercise publication rollback/merge through the actual store with in-memory platform adapters.
 const files=new Map();let failWrite=false;const requests=new Map();const crypto=require('node:crypto');
 const indexUrl='https://rules.test/index.json',packUrl='https://rules.test/packs/rule.json';
 const resource=Buffer.from(JSON.stringify(pack)),digest=crypto.createHash('sha256').update(resource).digest('hex');
 const index={schemaVersion:1,revision:digest,packs:[{id:pack.id,version:pack.version,path:'packs/rule.json',sha256:digest}]};
 requests.set(indexUrl,Buffer.from(JSON.stringify(index)));requests.set(packUrl,resource);
 const {ImageRuleStore}=load('ImageRuleStore',{
  '@kit.ArkTS':{taskpool:{execute:async(fn,...args)=>fn(...args)},util:{TextDecoder:{create:()=>({decodeToString:bytes=>Buffer.from(bytes).toString('utf8')})}}},
  '@kit.CoreFileKit':{fileIo:{accessSync:p=>files.has(p),statSync:p=>({size:files.get(p).length}),readTextSync:p=>files.get(p)}},
  '@kit.NetworkKit':{http:{RequestMethod:{GET:0},HttpDataType:{ARRAY_BUFFER:0},createHttp:()=>({request:async url=>{const b=requests.get(url);return {responseCode:b?200:500,result:b?Uint8Array.from(b).buffer:new ArrayBuffer(0)}},destroy(){}})}},
  '@kit.CryptoArchitectureKit':{cryptoFramework:{createMd:()=>{const h=crypto.createHash('sha256');return {updateSync:v=>h.update(v.data),digestSync:()=>({data:new Uint8Array(h.digest())})}}}},
  './AppFileTextPersistence':{writeAppTextFile:(p,s)=>{if(failWrite)throw Error('disk full');files.set(p,s)}},
  './BackupRestoreActivity':{BackupRestoreActivity:{runWrite:async f=>f()}},'./ImageBannerRules':rules,
  '../sourceRuntime/SourceIndexMetadata':{isValidHttpUrl:v=>/^https:\/\//.test(v),safeResolveIndexRelativeUrl:(b,p)=>new URL(p,b).href},
 });
 const ctx={filesDir:'/fixture',resourceManager:{getRawFileContent:async()=>new Uint8Array(resource)}};
 const store=ImageRuleStore.forContext(ctx),initial=await store.pinned();assert.equal(initial.records[0].origin,'builtin:compatibility');
 await store.sync('subscription-a',{schemaVersion:1,indexUrl},async()=>true);
 const accepted=await store.pinned();assert.equal(accepted.records[0].origin,'subscription-a');
 assert.equal(initial.records[0].origin,'builtin:compatibility','reader snapshot must remain unchanged');
 requests.set(indexUrl,Buffer.from(JSON.stringify({...index,revision:'broken',packs:[{...index.packs[0],sha256:'0'.repeat(64)}]})));
 await assert.rejects(store.sync('subscription-a',{schemaVersion:1,indexUrl},async()=>true));assert.deepEqual(await store.pinned(),accepted);
 requests.set(indexUrl,Buffer.from(JSON.stringify({...index,revision:'two'})));failWrite=true;
 await assert.rejects(store.sync('subscription-a',{schemaVersion:1,indexUrl},async()=>true));assert.deepEqual(await store.pinned(),accepted);
 failWrite=false;await store.sync('subscription-b',{schemaVersion:1,indexUrl},async()=>false);assert.deepEqual(await store.pinned(),accepted);
 await store.sync('subscription-b',{schemaVersion:1,indexUrl},async()=>true);assert.equal((await store.pinned()).records.length,2);
 const backup=await store.exportSnapshot();await store.restore(initial);assert.deepEqual(await store.pinned(),initial);await store.restore(backup);assert.deepEqual(await store.pinned(),backup);
 await store.reload();assert.deepEqual(await store.pinned(),backup,'restored snapshot survives reload');
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
 console.log('image banner rules: source/auto/off, edge precedence, no-hit, pinned snapshots and failed/removed-subscription rollback passed');
})().catch(e=>{console.error(e);process.exitCode=1});
