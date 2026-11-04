const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const root=path.resolve(__dirname,'..');
function load(name,deps={}) {const module={exports:{}};const source=fs.readFileSync(path.join(root,'entry/src/main/ets/model/'+name+'.ets'),'utf8').replace(/@Concurrent\s*/g,'');new Function('require','module','exports',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(n=>{assert.ok(n in deps,'missing '+n);return deps[n]},module,module.exports);return module.exports}
const metadataText=fs.readFileSync(path.join(root,'entry/src/main/ets/sourceRuntime/SourceIndexMetadata.ets'),'utf8');
const metadataAst=ts.createSourceFile('metadata.ts',metadataText,ts.ScriptTarget.Latest,true);
const metadataFunctions=new Set(['parseIndexEntriesDocument','subscriptionIdentity','resolveIndexDocumentUrl','parseSourceIndexHttpUrl','normalizeSourceIndexPath']);
const parseDocumentSource=metadataAst.statements.filter(n=>ts.isFunctionDeclaration(n)&&metadataFunctions.has(n.name?.text)).map(n=>n.getText(metadataAst)).join('\n');
const metadataModule={exports:{}};
new Function('module','exports',ts.transpileModule(parseDocumentSource,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(metadataModule,metadataModule.exports);
const {parseIndexEntriesDocument}=metadataModule.exports;
const plugins=load('ImageProcessingPlugins');
const alphaPixels=new Uint8Array([32,64,128,128,18,29,41,255,0,0,0,0]);plugins.imagePluginStraightAlpha(alphaPixels);
assert.deepEqual([...alphaPixels],[64,128,255,128,18,29,41,255,0,0,0,0]);
const rules=load('ImageBannerRules',{'./ImageProcessingPlugins':plugins});
const management=load('ImagePluginManagement',{'./ImageBannerRules':rules,'../sourceRuntime/SourceIndexMetadata':metadataModule.exports});const {imagePluginRows}=management;const {ImageBannerDetector:detector}=load('ImageBannerDetector',{'./ImageBannerRules':rules});
const pack=rules.validateImageRulePack(JSON.parse(fs.readFileSync(path.join(root,'scripts/fixtures/image-rules-edge.json'),'utf8')));
const snapshot={schemaVersion:1,records:[{origin:'subscription-a',revision:'1',packs:[pack]}]};
const pluginPlanning=load('ImagePluginService',{'@kit.ArkTS':{},'@kit.ImageKit':{},'@kit.CoreFileKit':{},
 '@kit.CryptoArchitectureKit':{},'./ImageFileContent':{},'./ImagePluginNative':{},'../state/ImageRuleState':{connectImageRuleState:()=>({processingFailures:{}})},'./ImageProcessingPlugins':plugins});
// User adopted one enable switch: legacy source/auto values both mean on.
assert.equal(rules.normalizeBannerFilter('source'),'auto');
assert.equal(rules.normalizeBannerFilter('auto'),'auto');
assert.equal(rules.normalizeBannerFilter('off'),'off');
assert.equal(rules.effectiveBannerFilter('off','source'),'auto');
assert.equal(rules.effectiveBannerFilter('off','global'),'off');
assert.equal(rules.imageBannerPlans(snapshot,'source').length,1);
assert.equal(rules.effectiveBannerFilter('auto','off'),'off');assert.equal(rules.effectiveBannerFilter('auto','global'),'auto');
assert.equal(rules.imageBannerPlans(snapshot,'off',{kind:'baozi_banner',mode:'2'}).length,0);
assert.equal(rules.imageBannerPlans(snapshot,'source',{kind:'baozi_banner',mode:'0'}).length,1);
assert.equal(rules.imageBannerPlans(snapshot,'source',{kind:'baozi_banner',mode:'1'})[0].mode,'2');
assert.equal(rules.imageBannerPlans(snapshot,'auto').length,1);
assert.equal(rules.canDiscoverSourceImageProcessing(snapshot,'online.baozimh.koma'),false);
const hintOnlySnapshot=structuredClone(snapshot);hintOnlySnapshot.records[0].packs[0].rules[0].crossSource=false;
assert.equal(rules.canDiscoverSourceImageProcessing(hintOnlySnapshot,'online.baozimh.koma'),true);
assert.equal(rules.imageBannerPlans(hintOnlySnapshot,'auto').length,0);
assert.equal(rules.imageBannerPlans(hintOnlySnapshot,'auto',{kind:'baozi_banner',mode:'1'})[0].mode,'1');
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
  imagePluginPlans:pluginPlanning.imagePluginPlans,ImagePluginService:{prepare:async(path)=>path},
 };
 const adapterModule={exports:{}};
 new Function(...Object.keys(cacheDependencies),'module','exports',ts.transpileModule(adapterFunctions,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(...Object.values(cacheDependencies),adapterModule,adapterModule.exports);
 const fetchCached=adapterModule.exports.fetchAndCacheSourceRuntimeRemoteImage;
 let received;const receive=hint=>{received=hint};
 await fetchCached('other-source','https://images.test/page','page','',false,0,receive,false);
 assert.equal(runtimeRequests,0,'unrelated cached page must stay instant');assert.equal(hints.size,0,'unknown is not a resolved absence');
 await fetchCached('legacy-source','https://images.test/page','page','',false,0,receive,false);
 assert.equal(runtimeRequests,0,'independent processing never discovers old source metadata');
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
 entry.enabled=true;
 const independentPage={sourceRuntimeId:'legacy-source',pageId:'cached'};const beforeIndependent=runtimeRequests;
 assert.equal(await adapterModule.exports.prepareSourcePagePresentation(independentPage,'/downloaded',{}, {snapshot,policy:'auto'}),'/filtered');
 assert.equal(runtimeRequests,beforeIndependent,'enabled general processing does not ask a source for cached metadata');
 const mixedSnapshot=structuredClone(snapshot),hintOnlyPack=structuredClone(pack);hintOnlyPack.id='hint-only';hintOnlyPack.rules[0].crossSource=false;
 hintOnlyPack.rules[0].legacy[0].sourceIds=['legacy-source'];mixedSnapshot.records[0].packs.push(hintOnlyPack);
 const unresolvedPage={sourceRuntimeId:'legacy-source',pageId:'cached-hint-only'};
 assert.equal(await adapterModule.exports.prepareSourcePagePresentation(unresolvedPage,'/downloaded',{}, {snapshot:mixedSnapshot,policy:'auto'}),'/filtered');
 assert.notEqual(unresolvedPage.imageProcessingResolved,true,'failed hint discovery stays unresolved while independent plugins continue');
 const stalePage={sourceRuntimeId:'legacy-source',pageId:'stale-hint',imageProcessing:declaredHint};
 assert.equal(await adapterModule.exports.prepareSourcePagePresentation(stalePage,'/downloaded',{},
  {snapshot:{schemaVersion:1,records:[{origin:'hint-only',revision:'1',packs:[hintOnlyPack]}]},policy:'auto'}),'/downloaded','failed refresh cannot execute a stale source declaration');
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
 let networkCalls=0,gate,waitForIndex=false,waitForModule=false,moduleGate;const state={dataRevision:0,userRevision:0,enabledRuleCount:0,processingFailures:{}};
 const requestedUrls=[];
 const {ImageRuleStore,subscriptionDocumentKind}=load('ImageRuleStore',{
  '@kit.ArkTS':{taskpool:{execute:async(fn,...args)=>fn(...args)},util:{TextDecoder:{create:()=>({decodeToString:bytes=>Buffer.from(bytes).toString('utf8')})},Base64Helper:class{encodeToStringSync(v){return Buffer.from(v).toString('base64')}}}},
  '@kit.CoreFileKit':{fileIo:{accessSync:p=>files.has(p),statSync:p=>({size:files.get(p).length}),readTextSync:p=>files.get(p)}},
  '@kit.NetworkKit':{http:{RequestMethod:{GET:0},HttpDataType:{ARRAY_BUFFER:0},createHttp:()=>({request:async url=>{requestedUrls.push(url);networkCalls++;if(waitForIndex&&url===indexUrl)await new Promise(resolve=>{gate=resolve});if(waitForModule&&url.endsWith('.wasm'))await new Promise(resolve=>{moduleGate=resolve});const b=requests.get(url);return {responseCode:b?200:500,result:b?Uint8Array.from(b).buffer:new ArrayBuffer(0)}},destroy(){}})}},
  '@kit.CryptoArchitectureKit':{cryptoFramework:{createMd:()=>{const h=crypto.createHash('sha256');return {updateSync:v=>h.update(v.data),digestSync:()=>({data:new Uint8Array(h.digest())})}}}},
  './AppFileTextPersistence':{writeAppTextFile:(p,s)=>{if(failWrite)throw Error('disk full');files.set(p,s)}},
  './BackupRestoreActivity':{BackupRestoreActivity:{runWrite:async f=>f()}},'./ImageBannerRules':rules,'./ImageProcessingPlugins':plugins,
  './ImagePluginManagement':management,'./ImagePluginNative':{imagePluginNative:{inspectImageProcessor:()=>''}}, // Storage contract only; real native execution has a separate runner.
  '../state/ImageRuleState':{connectImageRuleState:()=>state},
  '../sourceRuntime/SourceIndexMetadata':{parseIndexEntriesDocument,isValidHttpUrl:v=>/^https:\/\//.test(v),resolveIndexDocumentUrl:v=>v,safeResolveIndexRelativeUrl:(b,p)=>new URL(p,b).href},
 });
 const ctx={filesDir:'/fixture',resourceManager:{getRawFileContent:async()=>{throw Error('must not read bundled rules')}}};
 const store=ImageRuleStore.forContext(ctx);assert.deepEqual(await store.list(),[]);assert.deepEqual((await store.pinned()).records,[]);assert.equal(networkCalls,0);
 assert.equal(subscriptionDocumentKind('[]'),'source');assert.equal(subscriptionDocumentKind('{"sources":[]}'),'source');assert.equal(subscriptionDocumentKind(JSON.stringify(index)),'image_rules');assert.equal(subscriptionDocumentKind('{}'),'unknown');
 await store.add(indexUrl,'');assert.equal(networkCalls,2);assert.equal(state.enabledRuleCount,0,'adding a subscription only adds catalog information');
 await store.installRulePack(indexUrl,pack.id);assert.equal(state.enabledRuleCount,0,'legacy rules also require explicit installation and activation');
 for(const rule of subscribedPack.rules)await store.setRuleEnabled(indexUrl,pack.id,rule.id,true);
 const initial=await store.pinned();assert.equal(initial.records[0].origin,indexUrl);assert.equal((await store.list())[0].name,'Visible rules');
 await store.setRuleEnabled(indexUrl,pack.id,pack.rules[0].id,false);
 assert.deepEqual((await store.pinned()).records[0].packs[0].rules.map(r=>r.id),['second-rule'],'one switch cannot disable the other rule');
 assert.equal(initial.records[0].packs[0].rules.length,2,'existing reader snapshot stays immutable');
 const beforeRename=networkCalls,renameRevision=state.userRevision;await store.rename(indexUrl,'Custom name');assert.equal(networkCalls,beforeRename,'renaming is local');assert.equal(state.userRevision,renameRevision,'renaming does not reset the reader');
 const accepted=await store.exportSnapshot();
 requests.set(indexUrl,Buffer.from(JSON.stringify({...index,revision:'broken',packs:[{...index.packs[0],sha256:'0'.repeat(64)}]})));
 await assert.rejects(store.refresh(indexUrl));assert.deepEqual((await store.exportSnapshot()).installations,accepted.installations,'failed refresh retains installed algorithms');
 assert.equal((await store.list())[0].lastError,'image_rules_update_failed');
 failWrite=true;await assert.rejects(store.setRuleEnabled(indexUrl,pack.id,pack.rules[0].id,true));assert.deepEqual((await store.exportSnapshot()).installations,accepted.installations);failWrite=false;
 requests.set(indexUrl,Buffer.from(JSON.stringify({...index,revision:'two'})));const beforeUpdateRevision=state.userRevision;
 await store.refresh(indexUrl);assert.equal(state.userRevision,beforeUpdateRevision,'catalog refresh cannot reset current reader');
 assert.deepEqual((await store.pinned()).records[0].packs[0].rules.map(r=>r.id),['second-rule']);
 const backup=await store.exportSnapshot();await store.remove(indexUrl);assert.deepEqual(await store.list(),[]);assert.deepEqual((await store.exportSnapshot()).installations,backup.installations,'removing a subscription preserves installed rules');
 await store.restore(backup);await store.reload();assert.deepEqual(await store.exportSnapshot(),backup);
 waitForIndex=true;const late=store.refresh(indexUrl);while(!gate)await new Promise(r=>setImmediate(r));await store.remove(indexUrl);gate();await late;waitForIndex=false;
 assert.deepEqual(await store.list(),[],'removed subscription cannot be resurrected by a late update');
 // Adopted separation removes subscription execution/automatic-update gates.
 const legacy={schemaVersion:2,subscriptions:[{...backup.subscriptions[0],enabled:false,automaticUpdates:true,
  disabledRules:[],plugins:[],pluginSettings:{}}]};
 await store.restore(legacy);assert.equal(state.enabledRuleCount,0,'disabled legacy subscriptions migrate to disabled installed content');
 assert.equal((await store.exportSnapshot()).schemaVersion,3);
 assert.ok((await store.installed())[0].disabledRules.includes(rules.imageRuleKey(pack.id,pack.rules[0].id)));
 await store.restore(snapshot);assert.deepEqual(await store.list(),[],'old implicit downloads are not user-added subscriptions');
 assert.equal(state.enabledRuleCount,0);
 // Executable packages are separate from catalog refresh, with independent activation and atomic replacement.
 const pluginUrl='https://plugins.test/index.json',moduleUrl='https://plugins.test/processor.wasm';
 const moduleBytes=Buffer.from([0,97,115,109,1,0,0,0]),moduleDigest=crypto.createHash('sha256').update(moduleBytes).digest('hex');
 const plugin={schemaVersion:2,id:'independent-algorithm',version:1,meta:{name:'Example processor',description:'An independently installed algorithm'},
  processor:{abi:'koma-image-v1',path:'processor.wasm',sha256:moduleDigest},parameters:{},application:{automatic:true,sourceHints:[]},
  settings:[{id:'strength',label:'Strength',kind:'range',defaultValue:2,minValue:1,maxValue:4,step:1},{id:'preserve',label:'Preserve',kind:'boolean',defaultValue:true}]};
 const publishPlugin=version=>{plugin.version=version;const data=Buffer.from(JSON.stringify(plugin));const sha=crypto.createHash('sha256').update(data).digest('hex');
  const index={schemaVersion:2,kind:'image_plugins',meta:{name:'Plugin catalog'},revision:sha,packs:[{id:plugin.id,version,path:'plugin.json',sha256:sha}]};
  requests.set(pluginUrl,Buffer.from(JSON.stringify(index)));requests.set('https://plugins.test/plugin.json',data);return index};
 const pluginIndex=publishPlugin(1);requests.set(moduleUrl,moduleBytes);const beforeCatalog=networkCalls;
 assert.equal(subscriptionDocumentKind(JSON.stringify(pluginIndex)),'image_rules');await store.add(pluginUrl,'');
 assert.deepEqual(imagePluginRows(await store.list(),await store.installed()).map(row=>row.group),['available']);
 assert.equal(state.updateCount,0,'uninstalled offers do not count as updates');
 assert.equal(networkCalls,beforeCatalog+2,'adding a catalog never downloads an executable');assert.equal(state.enabledRuleCount,0);
 await store.installPlugin(pluginUrl,plugin.id);assert.equal((await store.installed())[0]?.plugins[0].version,1);assert.equal(state.enabledRuleCount,0,'new installation starts disabled');
 await store.setRuleEnabled(pluginUrl,plugin.id,plugin.id,true);await store.setPluginSettings(pluginUrl,plugin.id,{strength:9,preserve:false,unknown:'ignored'});
 const pinnedPlugin=await store.pinned();assert.deepEqual(pinnedPlugin.records[0].pluginSettings[plugin.id],{strength:4,preserve:false});
 assert.equal(pluginPlanning.imagePluginPlans(pinnedPlugin,'auto').length,1);assert.equal(pluginPlanning.imagePluginPlans(pinnedPlugin,'source').length,1);
 assert.equal(pluginPlanning.imagePluginPlans(pinnedPlugin,'off').length,0);
 const hintOnlyPlugin=structuredClone(pinnedPlugin);hintOnlyPlugin.records[0].plugins[0].application={automatic:false,sourceHints:[{kind:'scoped',modes:['1'],sourceIds:['scoped-source']}]};
 assert.equal(pluginPlanning.imagePluginPlans(hintOnlyPlugin,'auto').length,0);
 assert.equal(rules.canDiscoverSourceImageProcessing(hintOnlyPlugin,'scoped-source'),true);
 const scopedPlans=pluginPlanning.imagePluginPlans(hintOnlyPlugin,'auto',{kind:'scoped',mode:'1'});
 assert.equal(scopedPlans.length,1);assert.equal(scopedPlans[0].configuration.context.application,'source');
 const pluginBackup=await store.exportSnapshot();await store.reload();assert.deepEqual(await store.exportSnapshot(),pluginBackup,'installed bytes and settings survive restart');
 publishPlugin(2);
 store.revalidateInBackground();
 const check=store.checkUpdates();
 assert.equal(store.checkUpdates(),check,'foreground refresh joins the startup check');
 assert.equal(await check,true);
 assert.equal(state.updateCount,1,'a refreshed offer counts once for its installation');
 const validIndex=requests.get(pluginUrl);requests.delete(pluginUrl);
 assert.equal(await store.checkUpdates(),false);
 assert.equal(state.updateCount,1,'a failed check retains the last usable offer');
 requests.set(pluginUrl,validIndex);
 let catalog=(await store.list())[0],installed=(await store.installed())[0];
 assert.deepEqual(imagePluginRows(await store.list(),await store.installed()).map(row=>row.group),['updates']);
 assert.equal(catalog.catalog[0].version,2);assert.equal(installed.plugins[0].version,1,'refresh only updates offered metadata');
 requests.set(moduleUrl,Buffer.from('bad module'));await assert.rejects(store.installPlugin(pluginUrl,plugin.id));assert.equal((await store.installed())[0]?.plugins[0].version,1,'bad updates retain the installed plugin');
 requests.set(moduleUrl,moduleBytes);await store.installPlugin(pluginUrl,plugin.id);assert.equal((await store.installed())[0]?.plugins[0].version,2);assert.equal(state.enabledRuleCount,1,'update preserves activation');
 assert.deepEqual(imagePluginRows(await store.list(),await store.installed()).map(row=>row.group),['installed']);
 assert.equal(state.updateCount,0,'successful installation clears the count without a new check');
 await assert.rejects(store.setPluginSettings(pluginUrl,plugin.id,{strength:1},JSON.stringify([1,moduleDigest])),/image_plugin_settings_stale/);
 assert.deepEqual((await store.installed())[0].pluginSettings[plugin.id],{strength:4,preserve:false},'an old editor cannot overwrite settings after an algorithm update');
 assert.equal(pinnedPlugin.records[0].plugins[0].version,1,'current reading keeps its immutable algorithm');
 waitForModule=true;const lateInstall=store.installPlugin(pluginUrl,plugin.id);while(!moduleGate)await new Promise(r=>setImmediate(r));
 await store.uninstallPlugin(pluginUrl,plugin.id);moduleGate();await assert.rejects(lateInstall,/cancelled/);waitForModule=false;
 assert.deepEqual(await store.installed(),[],'uninstall cannot be undone by a late download');
 await store.restore(pluginBackup);await store.remove(pluginUrl);assert.deepEqual(await store.list(),[]);
 assert.deepEqual(await store.installed(),pluginBackup.installations,'removing subscription keeps executable bytes and settings');
 await store.reload();assert.deepEqual(await store.installed(),pluginBackup.installations,'detached installations survive restart');
 const anotherUrl='https://other.test/index.json';requests.set(anotherUrl,requests.get(pluginUrl));requests.set('https://other.test/plugin.json',requests.get('https://plugins.test/plugin.json'));requests.set('https://other.test/processor.wasm',moduleBytes);
 await store.add(anotherUrl,'Other publisher');await assert.rejects(store.installPlugin(anotherUrl,plugin.id),/source_conflict/);
 assert.equal((await store.installed())[0].origin,pluginUrl,'editing or adding a publisher cannot reparent an installation');
 await store.restore(pluginBackup);
 await store.add(anotherUrl,'Edited publisher',undefined,pluginUrl);
 assert.deepEqual((await store.list()).map(s=>s.url),[anotherUrl],'editing replaces only the subscription address');
 assert.deepEqual(await store.installed(),pluginBackup.installations,'editing the address retains the original installation and configuration');
 await store.restore(pluginBackup);
 const second=structuredClone(pluginBackup.installations[0].plugins[0]);second.id='second-processor';
 const ordered=structuredClone(pluginBackup);ordered.installations[0].plugins.push(second);await store.restore(ordered);
 publishPlugin(2);await store.refresh(pluginUrl);await store.installPlugin(pluginUrl,plugin.id);
 assert.deepEqual((await store.installed())[0].plugins.map(p=>p.id),[plugin.id,second.id],'algorithm update preserves execution order');
 await store.restore({schemaVersion:3,subscriptions:[],installations:[]});
 const distribution='github.com/example/source/releases/download/plugins-v1/';
 const originalBase='https://'+distribution,proxyBase='https://gh-proxy.org/'+distribution;
 publishPlugin(1);
 for(const base of [originalBase,proxyBase]){
  requests.set(base+'index.json',requests.get(pluginUrl));
  requests.set(base+'plugin.json',requests.get('https://plugins.test/plugin.json'));
  await store.add(base+'index.json','');
 }
 requests.set(proxyBase+'processor.wasm',moduleBytes);
 const available=imagePluginRows(await store.list(),[]);
 assert.equal(available.length,1);
 await store.installPlugin(available[0].source.origin,plugin.id,1);
 assert.deepEqual(requestedUrls.slice(-2),[originalBase+'processor.wasm',proxyBase+'processor.wasm']);
 assert.equal((await store.installed())[0].origin,originalBase+'index.json');
 await store.setSubscriptionDisabled(originalBase+'index.json',true);
 publishPlugin(2);
 requests.set(proxyBase+'index.json',requests.get(pluginUrl));
 requests.set(proxyBase+'plugin.json',requests.get('https://plugins.test/plugin.json'));
 await store.checkUpdates();
 assert.deepEqual(requestedUrls.slice(-2),[proxyBase+'index.json',proxyBase+'plugin.json']);
 assert.deepEqual(imagePluginRows(await store.list(),await store.installed()).map(row=>row.group),['updates']);
 await store.installPlugin(originalBase+'index.json',plugin.id,2);
 assert.equal((await store.installed())[0].plugins[0].version,2);
 assert.equal((await store.installed())[0].origin,originalBase+'index.json');
 const readable=await store.exportSnapshot();files.set('/fixture/image-rules.v1.json','broken JSON');await store.reload();await assert.rejects(store.list(),/storage_unavailable/);
 await assert.rejects(store.rename(pluginUrl,'Overwrite'),/storage_unavailable/);assert.equal(files.get('/fixture/image-rules.v1.json'),'broken JSON','read failure never overwrites saved data');
 await store.restore(readable);assert.deepEqual(await store.exportSnapshot(),readable,'explicit backup restore can recover storage');
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
 const pluginCache=new Map(),contents=new Map([['/a','a'],['/copy','a'],['/b','b'],['/c','c']]);let processing=0,peak=0,pluginTransforms=0,failPlugin=false;
 const pluginCacheStore={get:async(_url,_headers,key)=>pluginCache.get(key),put:async(url,_headers,_bytes,key)=>{const result='/cache/'+url+':'+key;pluginCache.set(key,result);return result}};
 const pluginService=load('ImagePluginService',{'@kit.ArkTS':{taskpool:{execute:async(fn,...args)=>{
  if(fn.name==='imageFileContentHash')return contents.get(args[0]);pluginTransforms++;processing++;peak=Math.max(peak,processing);
  await new Promise(r=>setImmediate(r));processing--;if(failPlugin)throw Error('processor failed');return {bytes:new Uint8Array([1]).buffer,extension:'png'};
 }}},'@kit.ImageKit':{},'@kit.CoreFileKit':{},'@kit.CryptoArchitectureKit':{},'./ImagePluginNative':{},
 './ImageFileContent':{imageFileContentHash:function imageFileContentHash(){}},'../state/ImageRuleState':{connectImageRuleState:()=>state},'./ImageProcessingPlugins':plugins}).ImagePluginService;
 const pluginPlans=pluginPlanning.imagePluginPlans(pinnedPlugin,'auto');
 const prepared=await Promise.all(['/a','/copy','/b','/c'].map(p=>pluginService.prepare(p,pluginPlans,pluginCacheStore)));
 assert.equal(prepared[0],prepared[1]);assert.equal(pluginTransforms,3,'identical content shares processing');assert.equal(peak,2,'decoding and execution use at most two common workers');
 const renamedPlans=structuredClone(pluginPlans);renamedPlans[0].revision='catalog revision';renamedPlans[0].plugin.meta.name='Renamed';
 assert.equal(await pluginService.prepare('/a',renamedPlans,pluginCacheStore),prepared[0]);assert.equal(pluginTransforms,3,'metadata refresh retains derived pixels');
 contents.set('/a','changed');failPlugin=true;const priorCacheSize=pluginCache.size;
 assert.equal(await pluginService.prepare('/a',pluginPlans,pluginCacheStore),'/a');assert.equal(pluginCache.size,priorCacheSize,'failed processor is never a cached no-hit');
 failPlugin=false;assert.notEqual(await pluginService.prepare('/a',pluginPlans,pluginCacheStore),'/a');
 console.log('PASS: subscription storage, catalog/install separation, atomic plugin updates, uninstall cancellation, portable backup, shared processing/cache and bounded workers');
})().catch(e=>{console.error(e);process.exitCode=1});
