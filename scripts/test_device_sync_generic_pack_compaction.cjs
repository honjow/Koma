const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path')
const {randomUUID}=require('node:crypto')
const {compile,wire,facts,A}=new Function('require','__dirname',fs.readFileSync(path.join(__dirname,'test_device_sync.cjs'),'utf8')+'\nreturn {compile,wire,facts,A};')(n=>n==='node:test'?()=>{}:require(n),__dirname)
const codec=compile('DeviceSyncPublicationPackCodec',{'./DeviceSyncFacts':facts,'./DeviceSyncWire':wire})
const kit={'@kit.ArkTS':{util:{generateRandomUUID:randomUUID},taskpool:{execute:async(fn,...args)=>fn(...args)}}}
const pack=compile('DeviceSyncPackCompaction',{'./DeviceSyncFacts':facts,'./DeviceSyncWire':wire,'./DeviceSyncPublicationPackCodec':codec,'./DeviceSyncObjectPack':{},...kit})
const generic=compile('DeviceSyncGenericPackCompaction',{'./DeviceSyncFacts':facts,'./DeviceSyncWire':wire,'./DeviceSyncPublicationPackCodec':codec,'./DeviceSyncObjectPack':{},'./DeviceSyncPackCompaction':pack,...kit})
function fixture(){const files=new Map(),pending=new Map(),ops=[];let fault=()=>{};const store={async read(p){ops.push(['read',p]);fault('read',p);return files.get(p)},async write(p,b){ops.push(['write',p]);fault('write',p);files.set(p,b)},async list(d){ops.push(['list',d]);return [...files.keys()].filter(p=>p.startsWith(d)).map(p=>p.slice(d.length)).filter(n=>!n.includes('/'))},async remove(p){ops.push(['remove',p]);fault('remove',p);files.delete(p)},async loadPending(){return [...pending.values()]},async recordPending(r){pending.set(r.path,{...r})},async forgetPending(p){pending.delete(p)},async deferPending(){}};return {files,pending,ops,store,fault:fn=>{fault=fn}}}
function seed(f,count,dataset='reader-settings-records'){
 let digit='',rows=[]
 for(let i=0;rows.length<count;i++){
  const body=JSON.stringify({dataset,schema:1,facts:[{i}]}),hash=wire.syncDigest(body);if(!digit)digit=hash[0];if(hash[0]!==digit)continue
  const entry={epoch:1,hash,bytes:Buffer.byteLength(body),body},packed=JSON.stringify({version:1,writer:A,entries:[entry]})
  const name=`pack-${randomUUID()}-${wire.syncDigest(packed)}.json`;f.files.set(A+'/packs/'+name,packed);rows.push({name,entry})
 }
 return rows
}
const guard=()=>{},ensure=async()=>{}
test('generic objects merge by dataset and object hash with actual net file reduction',async()=>{
 const f=fixture(),rows=seed(f,6),session=new generic.GenericPackSession()
 const result=await generic.compactGenericSyncPacks(f.store,A,guard,ensure,rows.map(x=>x.name),session)
 assert.equal(result.removed,6);assert.equal(result.written,2)
 const dir=generic.genericPackArchiveDirectory(A,'reader-settings-records',rows[0].entry.hash)
 const outputs=[...f.files].filter(([name])=>name.startsWith(dir));assert.equal(outputs.length,2)
 for(const [,body] of outputs){const decoded=JSON.parse(body);assert.equal(decoded.entries.length,6);assert.deepEqual(decoded.entries.map(x=>x.hash).sort(),rows.map(x=>x.entry.hash).sort())}
})
test('a sparse set never increases file count and unknown members remain',async()=>{
 const f=fixture(),rows=seed(f,2)
 const result=await generic.compactGenericSyncPacks(f.store,A,guard,ensure,rows.map(x=>x.name),new generic.GenericPackSession())
 assert.equal(result.removed,0);assert.equal(result.written,0)
 const bad=JSON.stringify({version:1,writer:A,entries:[{epoch:1,hash:wire.syncDigest('{}'),bytes:2,body:'{}'}]})
 const name=`pack-${randomUUID()}-${wire.syncDigest(bad)}.json`;f.files.set(A+'/packs/'+name,bad)
 await generic.compactGenericSyncPacks(f.store,A,guard,ensure,rows.map(x=>x.name).concat(name),new generic.GenericPackSession())
 assert.ok(f.files.has(A+'/packs/'+name))
})
test('partial deletion resumes from verified archives without creating duplicate copies',async()=>{
 const f=fixture(),rows=seed(f,6),allow=rows.map(x=>x.name);let n=0
 f.fault(op=>{if(op==='remove'&&++n===5)throw Error('offline')})
 await assert.rejects(generic.compactGenericSyncPacks(f.store,A,guard,ensure,allow,new generic.GenericPackSession()),/offline/)
 f.fault(()=>{})
 await generic.compactGenericSyncPacks(f.store,A,guard,ensure,allow,new generic.GenericPackSession())
 assert.equal([...f.files.keys()].filter(n=>n.includes('/archive-objects/')).length,2)
 assert.ok(rows.every(x=>!f.files.has(A+'/packs/'+x.name)))
})
