const test=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs')
const vm=require('node:vm')
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const sourcePath=require('node:path').join(__dirname,'../entry/src/main/ets/sourceRuntime/SourceIndexService.ets')
const cacheKey='source_index.metadata_cache.v1'
const item=(id='A',extra={})=>({id,name:id,pkg:`${id}.koma`,icon:`${id}.png`,version:'1',nsfw:true,...extra})
const tick=()=>new Promise(setImmediate)
function homepageGuard(){
 const text=fs.readFileSync(require('node:path').join(__dirname,'../entry/src/main/ets/sourceRuntime/SourcePackageMetadata.ets'),'utf8')
 const tree=ts.createSourceFile('importer',text,ts.ScriptTarget.Latest,true)
 const node=tree.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text==='normalizeSourceHomepage')
 const exports={};new Function('exports','url',ts.transpileModule(node.getText(tree),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText)(exports,{URL:{parseURL:value=>new URL(value)}})
 return exports.normalizeSourceHomepage
}
function harness(store=new Map(), installedOrigin){
 let requests=[],requestedUrls=[],installs=[],flushes=0,failFlush=false,gate
 const pref={async has(k){return store.has(k)},async delete(k){store.delete(k)},async get(k,d){return store.has(k)?store.get(k):d},async put(k,v){store.set(k,v)},async flush(){flushes++;if(gate)await gate;if(failFlush)throw Error('disk')}}
 const exports={}
 const serviceSource=fs.readFileSync(sourcePath,'utf8')
 const workerSource=(fs.readFileSync(sourcePath.replace('SourceIndexService.ets','SourceIndexMetadata.ets'),'utf8')+'\n'+fs.readFileSync(sourcePath.replace('SourceIndexService.ets','SourceIndexMetadataWorker.ets'),'utf8')).replace('const SOURCE_INDEX_REPOSITORY_LIMIT','const WORKER_REPOSITORY_LIMIT').replaceAll('SOURCE_INDEX_REPOSITORY_LIMIT','WORKER_REPOSITORY_LIMIT')
 const activitySource=fs.readFileSync(sourcePath.replace('sourceRuntime/SourceIndexService.ets','model/BackupRestoreActivity.ets'),'utf8')
 const signalsSource=fs.readFileSync(sourcePath.replace('sourceRuntime/SourceIndexService.ets','deviceSync/DeviceSyncSignals.ets'),'utf8')
 const source=(activitySource+'\n'+signalsSource+'\n'+workerSource+'\n'+serviceSource).replace(/^import[\s\S]*?from '[^']+'\n/gm,'').replace(/^export \{[^\n]+\} from '[^']+'\n/gm,'').replace(/@Concurrent/g,'').replace(/@ObservedV2/g,'').replace(/@Trace /g,'')
 const globals={exports,Map,Date,JSON,Array,Number,Promise,console,ArrayBuffer,Uint8Array,
  preferences:{getPreferences:async()=>pref}, taskpool:{execute:async(fn,...args)=>fn(...args)},
  RemoteImageCacheStore:class{}, DiagnosticLogger:{info(){},error(){}},
  isInvalidSourceLocalizedNames:v=>v!==undefined && (v===null || typeof v!=='object' || Array.isArray(v)),
  normalizeSourceHomepage:homepageGuard(),
  normalizeSourceLocalizedNames:v=>v, isValidSourcePackageMinAppVersion:v=>v==='' || /^\d+\.\d+\.\d+$/.test(v),
  SOURCE_REPO_PACKAGE_ICON_FILES:['icon.png','icon.jpg','icon.webp'],
  getInstalledSourcePackage:()=>installedOrigin === undefined ? undefined : {catalogOrigin:installedOrigin},
  isSourcePackageMinAppVersionSatisfied:()=>true,
  computeSourcePackageSha256:bytes=>require('node:crypto').createHash('sha256').update(bytes).digest('hex'),
  installFromBytes:async(_context,bytes,_name,id,origin,isCurrent,preserveSessionOnUpdate)=>{
   assert.equal(isCurrent(),true);installs.push({bytes,id,origin,preserveSessionOnUpdate});return {ok:true,id}
  },
  http:{RequestMethod:{GET:'GET'},HttpDataType:{STRING:'STRING',ARRAY_BUFFER:'ARRAY_BUFFER'},createHttp(){
   return {request(url){requestedUrls.push(url);return new Promise(resolve=>requests.push(resolve))},destroy(){}}
  }},
 }
 vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,globals)
 const make=(dir='data')=>new exports.SourceIndexService({filesDir:dir,cacheDir:'cache'})
 return {make,store,requests,requestedUrls,installs,pref,activity:exports.BackupRestoreActivity,setFail:v=>failFlush=v,setGate:v=>gate=v,get flushes(){return flushes}}
}
async function fetched(h,s,url,items){const r=s.fetchIndex(url);h.requests.shift()({responseCode:200,result:JSON.stringify(items)});const result=await r;await tick();return result}

test('adding and restoring more than twelve subscriptions keeps every saved address',async()=>{
 const h=harness(),service=h.make()
 const addresses=Array.from({length:15},(_,index)=>`https://repository-${index}.example/index.json`)
 for(const address of addresses)await service.saveRepository(address,'')
 const saved=await service.loadSavedRepositories()
 assert.equal(saved.length,addresses.length)
 assert.deepEqual([...saved.map(repo=>repo.url)].sort(),[...addresses].sort())
 const snapshot=await service.captureDeviceSyncSnapshot()
 await service.applyDeviceSyncSnapshot(snapshot)
 const reloaded=await h.make().loadSavedRepositories()
 assert.deepEqual([...reloaded.map(repo=>repo.url)].sort(),[...addresses].sort())
})

test('backup restore retires late subscription results even when the same URL remains enabled',async()=>{
 const h=harness(),service=h.make(),url='https://example.test/'
 await service.saveRepository(url,'before',{name:'Before'})
 const guard=service.restoreGuard()
 const index=service.fetchIndex(url),finishIndex=h.requests.shift()
 const metadata=service.refreshRepositoryMetadata({url,lastUsedAt:0}),finishMetadata=h.requests.shift()
 const metadataRejected=assert.rejects(metadata,/backup_restore_busy/)
 h.activity.beginRestore()
 service.invalidateForBackupRestore()
 h.store.set('source_index.repositories.v1',JSON.stringify([{url,lastUsedAt:0,customName:'Restored',name:'Restored metadata'}]))
 await service.reloadAfterBackupRestore()
 h.activity.finishRestore()
 assert.throws(guard,/backup_restore_busy/)
 finishIndex({responseCode:200,result:JSON.stringify([item('stale')])})
 finishMetadata({responseCode:200,result:JSON.stringify({meta:{name:'Stale metadata'}})})
 assert.equal((await index).ok,false)
 await metadataRejected
 await tick()
 assert.equal((await service.loadSavedRepositories())[0].name,'Restored metadata')
 assert.equal(await service.loadCachedIndex(url),undefined)
 assert.equal((await fetched(h,service,url,[item('fresh')])).ok,true)
 h.activity.beginRestore()
 service.invalidateForBackupRestore()
 h.store.set('source_index.repositories.v1',JSON.stringify([{url,lastUsedAt:0,disabled:true}]))
 await service.reloadAfterBackupRestore()
 h.activity.finishRestore()
 const before=h.requestedUrls.length
 assert.equal((await service.fetchIndex(url)).ok,false)
 assert.equal(h.requestedUrls.length,before,'Restored disabled state must block network use')
})

test('an unavailable book source package retries its verified enabled mirror',async()=>{
 const path='github.com/example/sources/releases/latest/download/'
 const original='https://'+path+'index.json',mirror='https://any-transport.test/'+path+'index.json'
 const h=harness(new Map(),original),service=h.make()
 const bytes=Uint8Array.of(1,2,3)
 const offer=item('A',{sha256:require('node:crypto').createHash('sha256').update(bytes).digest('hex')})
 for(const url of [original,mirror]){
  await service.saveRepository(url,'')
  await fetched(h,service,url,[offer])
 }
 const pending=service.installPackage(original,offer,true)
 await tick()
 h.requests.shift()({responseCode:503,result:new ArrayBuffer(0)})
 await tick()
 h.requests.shift()({responseCode:200,result:bytes.buffer})
 assert.equal((await pending).ok,true)
 assert.deepEqual(h.requestedUrls.slice(-2),[original.replace('index.json','A.koma'),mirror.replace('index.json','A.koma')])
 assert.equal(h.installs[0].origin,mirror)
 assert.equal(h.installs[0].preserveSessionOnUpdate,true)
 // A version the pinned endpoint never offered is not swap evidence: the mirror
 // candidate must install (device 237 gh-proxy shape, user decision 2026-11-09).
 const upgradeBytes=Uint8Array.of(9,9,9)
 const upgrade={...offer,version:'2',sha256:require('node:crypto').createHash('sha256').update(upgradeBytes).digest('hex')}
 const pendingUpgrade=service.installPackage(mirror,upgrade,true)
 await tick()
 h.requests.shift()({responseCode:200,result:upgradeBytes.buffer})
 assert.equal((await pendingUpgrade).ok,true)
 // Even when another cached address advertises different bytes for this
 // version, the selected subscription remains usable after its own hash check.
 const alternate={...offer,sha256:upgrade.sha256}
 const pendingAlternate=service.installPackage(mirror,alternate,true)
 await tick()
 h.requests.shift()({responseCode:200,result:upgradeBytes.buffer})
 assert.equal((await pendingAlternate).ok,true)
 const requestCountBeforeMismatch=h.requestedUrls.length
 // A different cached digest must not block the selected source. The bytes
 // actually downloaded still have to match that source's advertised digest.
 const forged={...offer,sha256:'a'.repeat(64)}
 const mismatch=service.installPackage(mirror,forged,true)
 await tick()
 h.requests.shift()({responseCode:200,result:bytes.buffer})
 assert.equal((await mismatch).reasonCode,'checksum_mismatch')
 assert.equal(h.requestedUrls.length,requestCountBeforeMismatch+1)
 await service.setSubscriptionDisabled(original,true)
 const mirrorOnly=service.installPackage(mirror,offer,true)
 await tick()
 h.requests.shift()({responseCode:200,result:bytes.buffer})
 assert.equal((await mirrorOnly).ok,true)
 assert.equal(h.installs[3].preserveSessionOnUpdate,true)
 for(const url of [original,mirror])await service.setSubscriptionDisabled(url,true)
 const requestCount=h.requestedUrls.length
 assert.equal((await service.installPackage(original,offer,true)).reasonCode,'subscription_unavailable')
 assert.equal(h.requestedUrls.length,requestCount)
})
test('updates use the selected enabled subscription without requiring the old address cache',async()=>{
 const old='https://old.test/index.json',next='https://new.test/index.json'
 const h=harness(new Map(),old),service=h.make()
 const bytes=Uint8Array.of(4,5,6)
 const offer=item('A',{version:'2',sha256:require('node:crypto').createHash('sha256').update(bytes).digest('hex')})
 await service.saveRepository(next,'')
 const pending=service.installPackage(next,offer,true)
 await tick()
 h.requests.shift()({responseCode:200,result:bytes.buffer})
 assert.equal((await pending).ok,true)
 assert.equal(h.installs[0].origin,next)
 assert.equal(h.installs[0].preserveSessionOnUpdate,true)
})
test('successful metadata persists across service/runtime recreation, normalized URL isolated, iconUri discarded',async()=>{
 const h=harness(),s=h.make()
 const r=await fetched(h,s,' HTTPS://Example.COM/repo/ ',[item('A',{iconUri:'file://expired'})]);assert.equal(r.ok,true)
 const fresh=harness(h.store).make()
 const entries=await fresh.loadCachedIndex('https://example.com/repo/index.json')
 assert.equal(entries[0].id,'A');assert.equal(entries[0].nsfw,true);assert.equal(entries[0].iconUri,undefined)
 assert.equal(await fresh.loadCachedIndex('https://other.test/repo/'),undefined)
 assert.equal(await fresh.loadCachedIndex('invalid'),undefined)
})
test('cache IO cannot delay online metadata publication and cache failure cannot fail fetch',async()=>{
 const h=harness(),s=h.make();let unblock;h.setGate(new Promise(r=>unblock=r))
 const r=s.fetchIndex('https://example.test/');h.requests.shift()({responseCode:200,result:JSON.stringify([item()])})
 assert.equal((await r).ok,true);await tick();assert.equal(h.flushes,1)
 unblock();await tick();h.setGate(undefined);h.setFail(true)
 assert.equal((await fetched(h,s,'https://example.test/',[item('B')])).ok,true)
 await tick();h.setFail(false)
 assert.equal((await s.loadCachedIndex('https://example.test/'))[0].id,'A')
})
test('same normalized URL late old response cannot overwrite newer request across service instances',async()=>{
 const h=harness(),a=h.make(),b=h.make()
 const old=a.fetchIndex('https://example.test/repo/'),oldResponse=h.requests.shift()
 const next=b.fetchIndex('https://EXAMPLE.test/repo/index.json'),nextResponse=h.requests.shift()
 nextResponse({responseCode:200,result:JSON.stringify([item('new')])});await next;await tick()
 oldResponse({responseCode:200,result:JSON.stringify([item('old')])});await old;await tick()
 assert.equal((await a.loadCachedIndex('https://example.test/repo'))[0].id,'new')
})
test('missing corrupt unknown schema invalid entries and unsafe icon paths are cache misses without altering settings',async()=>{
 const h=harness(),s=h.make();h.store.set('source_index.url','user-url');h.store.set('source_index.repositories.v1','user-repos')
 assert.equal(await s.loadCachedIndex('https://test/'),undefined)
 for(const value of ['bad','[]',JSON.stringify({schemaVersion:2,records:[]}),JSON.stringify({schemaVersion:1,records:[{url:'https://test/index.json',entries:[{}]}]}),JSON.stringify({schemaVersion:1,records:[{url:'https://test/index.json',entries:[item('A',{icon:'../escape.png'})]}]})]){
 h.store.set(cacheKey,value);assert.equal(await s.loadCachedIndex('https://test/'),undefined);assert.equal(h.store.get(cacheKey),value)
 }
 assert.equal(h.store.get('source_index.url'),'user-url');assert.equal(h.store.get('source_index.repositories.v1'),'user-repos');assert.equal(h.flushes,0)
})
test('cache bounds evict oldest repositories without truncating online entries or overwriting existing oversized record',async()=>{
 const h=harness(),s=h.make()
 for(let i=0;i<13;i++)assert.equal((await fetched(h,s,`https://test/r${i}/`,[item(String(i))])).ok,true)
 assert.equal(await s.loadCachedIndex('https://test/r0/'),undefined);assert.equal((await s.loadCachedIndex('https://test/r12/'))[0].id,'12')
 const before=h.store.get(cacheKey)
 const r=await fetched(h,s,'https://test/r12/',Array.from({length:4097},(_,i)=>item(String(i))))
 assert.equal(r.entries.length,4097);assert.equal(h.store.get(cacheKey),before)
 const large=await fetched(h,s,'https://test/r12/',[item('big',{description:'x'.repeat(1024*1024)})])
 assert.equal(large.ok,true);assert.equal(h.store.get(cacheKey),before)
})
test('failed network/index response keeps last successful cache and empty valid index remains a hit',async()=>{
 const h=harness(),s=h.make();await fetched(h,s,'https://test/',[])
 assert.equal((await s.loadCachedIndex('https://test/')).length,0)
 const before=h.store.get(cacheKey),r=s.fetchIndex('https://test/');h.requests.shift()({responseCode:403,result:''})
 assert.equal((await r).ok,false);await tick();assert.equal(h.store.get(cacheKey),before)
})

test('aggregate cache stays bounded and read IO failures are misses',async()=>{
 const h=harness(),s=h.make()
 for(let i=0;i<6;i++)await fetched(h,s,`https://large.test/r${i}/`,[item(String(i),{description:'x'.repeat(800000)})])
 assert.ok(h.store.get(cacheKey).length<=4*1024*1024)
 assert.equal(await s.loadCachedIndex('https://large.test/r0/'),undefined)
 assert.equal((await s.loadCachedIndex('https://large.test/r5/'))[0].id,'5')
 h.pref.get=async()=>{throw Error('read')}
 assert.equal(await s.loadCachedIndex('https://large.test/r5/'),undefined)
})

test('homepage persists with cached metadata and icon adoption without changing install/session identity',async()=>{
 const h=harness(),s=h.make(),homepage='https://example.org/comics/?sort=latest#all'
 const result=await fetched(h,s,'https://index.test/',[item('A',{homepage,webSessionOrigins:['https://not-granted.test']})])
 assert.equal(result.entries[0].homepage,homepage)
 const entry=(await harness(h.store).make().loadCachedIndex('https://index.test/'))[0]
 assert.equal(entry.homepage,homepage);assert.equal(entry.webSessionOrigins,undefined)
 const rejected=await fetched(h,s,'https://index.test/',[item('B',{homepage:'javascript:alert(1)'})])
 assert.equal(rejected.ok,true);assert.equal(rejected.entries[0].homepage,undefined)
})

// Subscription metadata is optional and never rewrites catalog/package origins.
test('repository names survive automatic checks and editing is atomic',async()=>{
 const h=harness(),s=h.make(),a='https://example.test/repo',b='https://other.test/repo'
 let repos=await s.saveRepository(a,'',{name:'Official name',website:'https://project.test/'})
 assert.equal(repos[0].name,'Official name');assert.equal(repos[0].customName,undefined)
 await s.saveUrl(a);repos=await s.loadSavedRepositories();assert.equal(repos[0].name,'Official name')
 await s.saveRepository(a,'My name',undefined,a)
 assert.equal((await s.loadSavedRepositories())[0].customName,'My name')
 await s.saveRepository(a,'',undefined,a);assert.equal((await s.loadSavedRepositories())[0].name,'Official name')
 const before=JSON.stringify([...h.store]);let failures=1;h.pref.flush=async()=>{if(failures-->0)throw Error('disk')}
 await assert.rejects(s.saveRepository(b,'Renamed',{name:'Other'},a));assert.equal(JSON.stringify([...h.store]),before)
 h.pref.flush=async()=>{};await s.saveRepository(b,'Renamed',{name:'Other'},a)
 const cold=harness(h.store).make();repos=await cold.loadSavedRepositories()
 assert.equal(repos.length,1);assert.equal(repos[0].url,b);assert.equal(repos[0].name,'Other');assert.equal(repos[0].website,undefined)
 assert.equal(await cold.loadSavedUrl(),b)
})
test('wrapped metadata and optional sidecar parse safely without requiring either',async()=>{
 const h=harness(),s=h.make(),url='https://example.test/repo/'
 let r=await fetched(h,s,url,{meta:{name:'Publisher',website:'https://project.test/'},sources:[item()]})
 assert.equal(r.metadata.name,'Publisher');assert.equal(r.entries[0].id,'A')
 assert.equal((await fetched(h,s,url,[item()])).metadata,undefined)
 const sidecar=s.fetchRepositoryMetadata(url);h.requests.shift()({responseCode:200,result:JSON.stringify({meta:{name:'From repo',website:'javascript:alert(1)'}})})
 assert.deepEqual(JSON.parse(JSON.stringify(await sidecar)),{name:'From repo'})
 const missing=s.fetchRepositoryMetadata(url);h.requests.shift()({responseCode:404,result:''});assert.equal(await missing,undefined)
})
