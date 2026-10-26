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
function harness(store=new Map()){
 let requests=[],flushes=0,failFlush=false,gate
 const pref={async get(k,d){return store.has(k)?store.get(k):d},async put(k,v){store.set(k,v)},async flush(){flushes++;if(gate)await gate;if(failFlush)throw Error('disk')}}
 const exports={}
 const serviceSource=fs.readFileSync(sourcePath,'utf8')
 const workerSource=(fs.readFileSync(sourcePath.replace('SourceIndexService.ets','SourceIndexMetadata.ets'),'utf8')+'\n'+fs.readFileSync(sourcePath.replace('SourceIndexService.ets','SourceIndexMetadataWorker.ets'),'utf8')).replace('const SOURCE_INDEX_REPOSITORY_LIMIT','const WORKER_REPOSITORY_LIMIT').replaceAll('SOURCE_INDEX_REPOSITORY_LIMIT','WORKER_REPOSITORY_LIMIT')
 const source=(workerSource+'\n'+serviceSource).replace(/^import[\s\S]*?from '[^']+'\n/gm,'').replace(/^export \{[^\n]+\} from '[^']+'\n/gm,'').replace(/@Concurrent/g,'').replace(/@ObservedV2/g,'').replace(/@Trace /g,'')
 const globals={exports,Map,Date,JSON,Array,Number,Promise,console,
  preferences:{getPreferences:async()=>pref}, taskpool:{execute:async(fn,...args)=>fn(...args)},
  BackupRestoreActivity:{async runWrite(fn){return fn()}},
  RemoteImageCacheStore:class{}, DiagnosticLogger:{info(){},error(){}},
  isInvalidSourceLocalizedNames:v=>v!==undefined && (v===null || typeof v!=='object' || Array.isArray(v)),
  normalizeSourceHomepage:homepageGuard(),
  normalizeSourceLocalizedNames:v=>v, isValidSourcePackageMinAppVersion:v=>v==='' || /^\d+\.\d+\.\d+$/.test(v),
  SOURCE_REPO_PACKAGE_ICON_FILES:['icon.png','icon.jpg','icon.webp'],
  http:{RequestMethod:{GET:'GET'},HttpDataType:{STRING:'STRING'},createHttp(){return {request(){return new Promise(resolve=>requests.push(resolve))},destroy(){}}}},
 }
 vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,globals)
 const make=(dir='data')=>new exports.SourceIndexService({filesDir:dir,cacheDir:'cache'})
 return {make,store,requests,pref,setFail:v=>failFlush=v,setGate:v=>gate=v,get flushes(){return flushes}}
}
async function fetched(h,s,url,items){const r=s.fetchIndex(url);h.requests.shift()({responseCode:200,result:JSON.stringify(items)});const result=await r;await tick();return result}
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
