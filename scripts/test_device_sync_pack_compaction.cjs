const test=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs'), path=require('node:path')
const {randomUUID}=require('node:crypto')
const {compile,wire,facts,A}=new Function('require','__dirname',fs.readFileSync(path.join(__dirname,'test_device_sync.cjs'),'utf8')+'\nreturn {compile,wire,facts,A};')(name=>name==='node:test'?()=>{}:require(name),__dirname)
const codec=compile('DeviceSyncPublicationPackCodec',{'./DeviceSyncFacts':facts,'./DeviceSyncWire':wire})
const pack=compile('DeviceSyncPackCompaction',{'./DeviceSyncFacts':facts,'./DeviceSyncWire':wire,'./DeviceSyncPublicationPackCodec':codec,'./DeviceSyncObjectPack':{},'@kit.ArkTS':{util:{generateRandomUUID:randomUUID},taskpool:{execute:async(fn,...args)=>fn(...args)}}})
const guard=()=>{}
function fixture(){
 const files=new Map(),pending=new Map(),ops=[]; let fault=()=>{}
 const store={async read(p){ops.push(['read',p]);fault('read',p);return files.get(p)},async write(p,b){ops.push(['write',p]);fault('write',p);files.set(p,b)},async list(d){ops.push(['list',d]);fault('list',d);return [...files.keys()].filter(p=>p.startsWith(d)).map(p=>p.slice(d.length)).filter(n=>!n.includes('/'))},async remove(p){ops.push(['remove',p]);fault('remove',p);files.delete(p)},async loadPending(){return [...pending.values()]},async recordPending(row){pending.set(row.path,{...row})},async forgetPending(p){pending.delete(p)},async deferPending(p,startedAt,nextCheckAt,checks,awaitingListing){const row=pending.get(p);if(row?.startedAt===startedAt)pending.set(p,{...row,nextCheckAt,checks,awaitingListing})}}
 return {files,pending,ops,store,fault:fn=>{fault=fn}}
}
function sources(f,dataset='reader-settings-records',count=4){
 const entries=[];let bucket=''
 for(let i=0;entries.length<count;i++){
  const body=JSON.stringify({dataset,schema:1,facts:[{i}]}), hash=wire.syncDigest(body)
  const entry={epoch:1,hash,bytes:Buffer.byteLength(body),body}
  const packed=JSON.stringify({version:1,writer:A,entries:[entry]}), digest=wire.syncDigest(packed)
  if(!bucket)bucket=digest[0]
  if(digest[0]!==bucket)continue
  const name=`pack-${randomUUID()}-${digest}.json`,file=A+'/packs/'+name
  f.files.set(file,packed);entries.push({file,entry,digest})
 }
 return entries
}
const ensure=async()=>{}
const allowed=f=>[...f.files.keys()].filter(p=>p.startsWith(A+'/packs/')).map(p=>p.slice((A+'/packs/').length))
test('compaction preserves every entry in two verified copies after interrupted deletion',async()=>{
 const f=fixture(), input=sources(f);let deletes=0
 f.fault(op=>{if(op==='remove'&&++deletes===2)throw Error('offline')})
 await assert.rejects(pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f)),/offline/)
 assert.equal([...f.files.keys()].filter(p=>p.includes('/archive/')).length,2)
 f.fault(()=>{}); await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f))
 assert.ok(input.every(x=>!f.files.has(x.file)))
 const refs=input.map(x=>({epoch:1,hash:x.entry.hash,bytes:x.entry.bytes,bucket:''}))
 const result=await pack.readCompactedSyncPublicationPacks(f.store,A,'reader-settings-records',input[0].digest,refs,guard)
 assert.deepEqual(result.objects.map(x=>x.body).sort(),input.map(x=>x.entry.body).sort())
 assert.equal([...f.files.keys()].filter(p=>p.includes('/archive/')).length,2)
})
test('timeout never overwrites an attempt; late partial write is retained for recheck',async()=>{
 const f=fixture(), input=sources(f);let delayed
 f.fault((op,p)=>{if(op==='write'){delayed=p;throw Error('timeout')}})
 await assert.rejects(pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f)),/timeout/)
 f.fault(()=>{});await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f))
 assert.equal([...f.files.keys()].filter(p=>p.includes('/archive/')).length,2)
 f.files.set(delayed,'partial late body')
 await pack.reconcileCompactionAttempts(f.store,A,guard)
 assert.ok(f.pending.has(delayed)); assert.ok(input.every(x=>!f.files.has(x.file)))
})
test('mixed or unknown dataset entries remain at their source path',async()=>{
 const f=fixture(), input=sources(f)
 const file=input[0].file, old=JSON.parse(f.files.get(file)), extra=JSON.stringify({dataset:'cover-records',facts:[]})
 old.entries.push({epoch:1,hash:wire.syncDigest(extra),bytes:Buffer.byteLength(extra),body:extra})
 const body=JSON.stringify(old), name=`${A}/packs/pack-${randomUUID()}-${wire.syncDigest(body)}.json`
 f.files.delete(file);f.files.set(name,body)
 await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f))
 assert.ok(f.files.has(name))
})

test('concurrent reads in the same bucket serialize discovery without skipping a pack',async()=>{
 const f=fixture(),dataset='reader-settings-records',sourceHash='a'+'0'.repeat(63)
 const dir=pack.compactionArchiveDirectory(A,dataset,sourceHash), rows=[]
 for(let i=1;i<=2;i++){
  const body=JSON.stringify({dataset,schema:1,facts:[{page:i}]}),entry={epoch:1,hash:wire.syncDigest(body),bytes:Buffer.byteLength(body),body}
  const value=JSON.stringify({version:1,writer:A,entries:[entry]}),id=`00000000-0000-0000-0000-${String(i).padStart(12,'0')}`
  f.files.set(dir+`pack-${id}-${wire.syncDigest(value)}.json`,value);rows.push(entry)
 }
 const session=new pack.SyncPackCompactionSession(),originalRead=f.store.read;let release,entered
 const gate=new Promise(resolve=>{release=resolve}),started=new Promise(resolve=>{entered=resolve});let first=true
 f.store.read=async p=>{if(first){first=false;entered();await gate}return originalRead(p)}
 const p1=pack.readCompactedSyncPublicationPacks(f.store,A,dataset,sourceHash,[{...rows[0],bucket:''}],guard,session)
 await started
 const p2=pack.readCompactedSyncPublicationPacks(f.store,A,dataset,sourceHash,[{...rows[1],bucket:''}],guard,session)
 release()
 const [one,two]=await Promise.all([p1,p2])
 assert.equal(one.objects[0].body,rows[0].body);assert.equal(two.objects[0].body,rows[1].body)
 assert.equal(f.ops.filter(x=>x[0]==='list'&&x[1]===dir).length,1)
 assert.equal(f.ops.filter(x=>x[0]==='read'&&x[1].startsWith(dir)).length,2)
})

test('maintenance cursor reaches mergeable packs beyond the first batch',async()=>{
 const f=fixture()
 for(let i=0;i<16;i++){
  const body=JSON.stringify({dataset:'independent-'+i,facts:[i]}),entry={epoch:1,hash:wire.syncDigest(body),bytes:Buffer.byteLength(body),body}
  const value=JSON.stringify({version:1,writer:A,entries:[entry]}),id=`00000000-0000-0000-0000-${String(i+1).padStart(12,'0')}`
  f.files.set(`${A}/packs/pack-${id}-${wire.syncDigest(value)}.json`,value)
 }
 let bucket='',added=0
 for(let i=0;added<3;i++){
  const body=JSON.stringify({dataset:'reader-settings-records',facts:[i]}),entry={epoch:1,hash:wire.syncDigest(body),bytes:Buffer.byteLength(body),body}
  const value=JSON.stringify({version:1,writer:A,entries:[entry]}),hash=wire.syncDigest(value)
  if(!bucket)bucket=hash[0];if(hash[0]!==bucket)continue
  const id=`00000000-0000-0000-0000-${String(20+added).padStart(12,'0')}`
  f.files.set(`${A}/packs/pack-${id}-${hash}.json`,value);added++
 }
 const session=new pack.SyncPackMaintenanceSession()
 const first=await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f),16,[],session)
 assert.equal(first.deferred,true)
 const second=await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f),16,[],session)
 assert.equal(second.removed,3);assert.equal(second.written,2)
})

test('later maintenance batch reuses verified archive index instead of rereading unrelated packs',async()=>{
 const f=fixture();sources(f,'reader-settings-records',8)
 const session=new pack.SyncPackMaintenanceSession()
 const first=await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f),4,[],session)
 assert.equal(first.written,2)
 f.ops.length=0
 const second=await pack.compactSyncPublicationPacks(f.store,A,guard,ensure,allowed(f),4,[],session)
 assert.equal(second.written,2)
 const archiveReads=f.ops.filter(x=>x[0]==='read'&&x[1].includes('/archive/'))
 assert.equal(archiveReads.length,2,'only the two new copies require readback')
})

test('failed or cancelled discovery does not poison a later caller in the same round',async()=>{
 const f=fixture(),dataset='reader-settings-records',sourceHash='b'+'0'.repeat(63)
 const dir=pack.compactionArchiveDirectory(A,dataset,sourceHash)
 const body=JSON.stringify({dataset,facts:[1]}),entry={epoch:1,hash:wire.syncDigest(body),bytes:Buffer.byteLength(body),body}
 const value=JSON.stringify({version:1,writer:A,entries:[entry]})
 f.files.set(dir+`pack-${randomUUID()}-${wire.syncDigest(value)}.json`,value)
 const session=new pack.SyncPackCompactionSession();let failed=false
 f.fault(op=>{if(op==='read'&&!failed){failed=true;throw Error('offline')}})
 await assert.rejects(pack.readCompactedSyncPublicationPacks(f.store,A,dataset,sourceHash,[{...entry,bucket:''}],guard,session),/offline/)
 f.fault(()=>{})
 const result=await pack.readCompactedSyncPublicationPacks(f.store,A,dataset,sourceHash,[{...entry,bucket:''}],guard,session)
 assert.equal(result.objects[0].body,body)
})
