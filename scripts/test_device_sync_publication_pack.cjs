const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')
const { compile, wire, facts, A } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') + '\nreturn { compile, wire, facts, A };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const codec = compile('DeviceSyncPublicationPackCodec', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire })
const publication = compile('DeviceSyncPublicationPack', { './DeviceSyncWire': wire,
  './DeviceSyncPublicationPackCodec': codec,
  '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: { execute: async (fn, ...args) => fn(...args) } } })
const existingPack = compile('DeviceSyncObjectPack', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire,
  '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: { execute: async (fn, ...args) => fn(...args) } } })
const guard = () => {}
function objects(count) {
  return Array.from({length:count}, (_, i) => {
    const body = JSON.stringify({ value: i })
    return {ref:{bucket:i.toString(16).padStart(2,'0'),epoch:1,hash:wire.syncDigest(body),bytes:wire.syncUtf8(body).length},body}
  })
}
function fixture() {
  const files = new Map(), attempted = new Set(), operations = []
  const store = {
    async beginUnique(path) { operations.push(['begin',path]); if (attempted.has(path)) throw Error('attempt reused'); attempted.add(path) },
    async completeUnique(path) { operations.push(['complete',path]) },
    async put(path, body) { operations.push(['put',path]); files.set(path,body) },
    async get(path) { operations.push(['get',path]); return files.get(path) }
  }
  return { files, operations, store }
}
test('new publication writes two pack copies and cold reads all 40 shards with one GET', async () => {
  const f = fixture(), input = objects(40), plan = await publication.planPublicationPacks(A,input,guard)
  assert.equal(plan.packs.length,1); assert.equal(plan.singles.length,0)
  assert.equal(plan.packs[0].location.members.length,40)
  await publication.writePublicationPacks(f.store,plan,guard)
  assert.equal(f.operations.filter(x=>x[0]==='put').length,2)
  assert.equal(f.operations.filter(x=>x[0]==='get').length,2)
  assert.equal(f.operations.filter(x=>x[0]==='complete').length,2)
  f.operations.length=0
  const refs=input.map(x=>x.ref)
  const result=await publication.readPublicationPacks(f.store,plan.packs.map(x=>x.location),refs,refs,guard)
  assert.deepEqual(result.objects.map(x=>x.body).sort(), input.map(x=>x.body).sort())
  assert.deepEqual(result.missing,[]); assert.equal(result.incomplete,false)
  assert.equal(f.operations.filter(x=>x[0]==='get').length,1)
})
test('focused read validates full head but retrieves only requested entries; alternate handles corruption',async()=>{
  const f=fixture(), input=objects(4), refs=input.map(x=>x.ref), plan=await publication.planPublicationPacks(A,input,guard)
  await publication.writePublicationPacks(f.store,plan,guard)
  f.files.set([...f.files.keys()][0],'bad')
  f.operations.length=0
  const result=await publication.readPublicationPacks(f.store,[plan.packs[0].location],refs,[refs[3]],guard)
  assert.equal(result.objects.length,1); assert.equal(result.objects[0].body,input[3].body)
  assert.equal(f.operations.filter(x=>x[0]==='get').length,2)
})
test('failed attempt cannot be overwritten and late completion cannot damage replacement',async()=>{
  const f=fixture(), input=objects(4), first=await publication.planPublicationPacks(A,input,guard)
  const put=f.store.put; let delayed
  f.store.put=async(path,body)=>{delayed=[path,body];throw Error('timeout')}
  await assert.rejects(publication.writePublicationPacks(f.store,first,guard),/timeout/)
  assert.equal(f.operations.filter(x=>x[0]==='complete').length,0)
  f.store.put=put
  await assert.rejects(publication.writePublicationPacks(f.store,first,guard),/attempt reused/)
  const second=await publication.planPublicationPacks(A,input,guard)
  await publication.writePublicationPacks(f.store,second,guard)
  f.files.set(delayed[0],'partial late write')
  const refs=input.map(x=>x.ref)
  const result=await publication.readPublicationPacks(f.store,[second.packs[0].location],refs,refs,guard)
  assert.equal(result.objects.length,4)
})
test('unselected inherited members remain addressable, and a singleton uses old object storage',async()=>{
  const input=objects(3), plan=await publication.planPublicationPacks(A,input,guard)
  const keep=codec.retainPublicationPackLocations([plan.packs[0].location],[input[0].ref,input[2].ref])
  assert.deepEqual(keep[0].members.map(x=>x.hash),[input[0].ref.hash,input[2].ref.hash])
  const single=await publication.planPublicationPacks(A,[input[0]],guard)
  assert.equal(single.packs.length,0); assert.equal(single.singles.length,1)
})

test('both copies damaged do not return partial shards as a successful read',async()=>{
  const f=fixture(), input=objects(5), refs=input.map(x=>x.ref), plan=await publication.planPublicationPacks(A,input,guard)
  await publication.writePublicationPacks(f.store,plan,guard)
  for (const key of f.files.keys()) f.files.set(key,'corrupted')
  const result=await publication.readPublicationPacks(f.store,[plan.packs[0].location],refs,refs,guard)
  assert.equal(result.incomplete,true); assert.equal(result.objects.length,0)
  assert.deepEqual(result.missing,refs)
})

test('separate locators referring to the same immutable pack perform one GET',async()=>{
  const f=fixture(), input=objects(4), refs=input.map(x=>x.ref), plan=await publication.planPublicationPacks(A,input,guard)
  await publication.writePublicationPacks(f.store,plan,guard)
  const original=plan.packs[0].location
  const first={...original,members:original.members.slice(0,2)}
  const second={...original,members:original.members.slice(2)}
  f.operations.length=0
  const result=await publication.readPublicationPacks(f.store,[first,second],refs,refs,guard)
  assert.equal(result.objects.length,4); assert.equal(f.operations.filter(x=>x[0]==='get').length,1)
})

test('new publication pack remains readable by existing v4 pack reader',async()=>{
  const f=fixture(), input=objects(4), plan=await publication.planPublicationPacks(A,input,guard)
  await publication.writePublicationPacks(f.store,plan,guard)
  const store={read:async path=>f.files.get(path),list:async dir=>[...f.files.keys()]
    .filter(name=>name.startsWith(dir)).map(name=>name.slice(dir.length))}
  const ref=input[2].ref
  assert.equal(await existingPack.readSyncPackObject(store,A,ref.epoch,ref.hash,ref.bytes),input[2].body)
})

test('transient network failure tries alternate but cannot become a false missing result',async()=>{
  const f=fixture(), input=objects(3), refs=input.map(x=>x.ref), plan=await publication.planPublicationPacks(A,input,guard)
  await publication.writePublicationPacks(f.store,plan,guard)
  const originalGet=f.store.get
  let calls=0
  f.store.get=async path=>{if (++calls===1) throw Error('sync_network_timeout'); return originalGet(path)}
  const result=await publication.readPublicationPacks(f.store,[plan.packs[0].location],refs,refs,guard)
  assert.equal(result.objects.length,3); assert.equal(calls,2)
  f.store.get=async()=>{throw Error('sync_network_failed')}
  await assert.rejects(publication.readPublicationPacks(f.store,[plan.packs[0].location],refs,refs,guard),/sync_network_failed/)
  calls=0; f.store.get=async()=>{calls++;throw Error('sync_authentication_failed')}
  await assert.rejects(publication.readPublicationPacks(f.store,[plan.packs[0].location],refs,refs,guard),/sync_authentication_failed/)
  assert.equal(calls,1)
})
