const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { transportFixture, engineFixture, wire, data, A, B, dataset, manifest, pageNumber, noop } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_journal.cjs'), 'utf8') +
  '\nreturn { transportFixture, engineFixture, wire, data, A, B, dataset, manifest, pageNumber, noop };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)

test('a missing migrated shard prevents retiring the legacy publication and its packs', async () => {
  const f = transportFixture('https://pack-protection.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const provider = new f.SharedWebDav(f.draft, [], undefined, A)
  const old = manifest(provider.spaceId(), [value.ref])
  for (const object of value.objects) f.seedObject(object)
  f.seedCommit(old)
  const packDirectory = f.writerRootV4 + B + '/packs/'
  for (const directory of [f.writerRootV4, f.writerRootV4 + B + '/', packDirectory]) f.directories.add(directory)
  const { ref, body } = value.objects[0]
  const pack = JSON.stringify({ version: 1, writer: B, entries: [{ epoch: ref.epoch, hash: ref.hash, bytes: ref.bytes, body }] })
  const pending = packDirectory + 'pack-10000000-0000-0000-0000-000000000011-' + wire.syncDigest(pack) + '.json'
  f.files.set(pending, pack)
  const legacy = await provider.readManifest(noop)
  const migrated = { ...legacy.manifest,
    legacyMigration: { frontier: legacy.frontier ?? [], legacyHash: legacy.legacyHash } }
  const objects = []
  await provider.prepareSharedMigration(migrated, objects, noop)
  await provider.publishShared(migrated, objects, '', noop, noop)
  const shard = f.trace.find(row => row.method === 'PUT' && row.address.startsWith(f.sharedRoot) &&
    row.address.includes(value.ref.shards[0].hash))
  assert.ok(shard)
  f.files.delete(shard.address)

  await assert.rejects(provider.retireMigratedLegacy(noop), /sync_shard_missing/)
  assert.equal(f.files.get(pending), pack)
  assert.ok(f.directories.has(f.root))
  assert.equal(f.trace.some(row => row.method === 'DELETE' && row.address === f.writerRootV4), false)

  f.files.set(shard.address, shard.body)
  await provider.retireMigratedLegacy(noop)
  assert.equal(f.files.has(pending), false)
  const saved = await provider.readSharedHead(noop)
  assert.equal(saved.manifest.legacyMigration, undefined)
  assert.equal(await provider.readSharedObject(value.ref.id, saved.manifest.datasets[0].shards[0], noop), shard.body)
})

test('a missing pair of head locators falls back to another valid archived pack',async()=>{
  const f=transportFixture('https://pack-fallback.invalid')
  const writer=new f.WriterWebDav(f.draft,[],undefined,A), value=dataset('reader-settings-records',pageNumber,A,'true')
  const m=manifest(writer.spaceId(),[value.ref])
  const ref=value.objects[0].ref, entry={epoch:ref.epoch,hash:ref.hash,bytes:ref.bytes,body:value.objects[0].body}
  const packed=JSON.stringify({version:1,writer:A,entries:[entry]}), packhash=wire.syncDigest(packed)
  const locator={writer:A,hash:packhash,bytes:wire.syncUtf8(packed).length,
    attempts:['10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002'],
    members:[{epoch:ref.epoch,hash:ref.hash}]}
  const publication=JSON.stringify({writer:A,manifest:m,transaction:A,locations:[],newTargets:[],packLocations:[locator],newPackTargets:[]})
  const segment='00000000000000', seq='0000000000000001', root=f.writerRootV4
  for(const dir of [root,root+A+'/',root+A+'/'+segment+'/',root+A+'/packs/']) f.directories.add(dir)
  f.files.set(root+A+'/'+segment+'/'+seq+'-'+wire.syncDigest(publication)+'-'+A+'.json',publication)
  f.files.set(root+A+'/packs/pack-10000000-0000-0000-0000-000000000003-'+packhash+'.json',packed)
  const reader=new f.WriterWebDav(f.draft,[],writer.spaceId(),'20000000-0000-0000-0000-000000000000')
  await reader.readManifest(noop)
  assert.equal(await reader.readObject(ref,noop),value.objects[0].body)
})

for (const removeCount of [1,2]) test(`sent intent survives ${removeCount} replaced original pack copies and a late head`,async()=>{
  const transport=transportFixture(`https://pack-intent-${removeCount}.invalid`), f=engineFixture(transport.WriterWebDav)
  const entries=Array.from({length:30},(_,i)=>[data.syncKey(['book-mode','org.example.source','work-'+i]),
    JSON.stringify({direction:'right_to_left',mode:'single_page'})])
  const d=f.replica(A,[['reader-settings',new Map(entries)]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft); d.engine.setEnabled(true)
  try {
    transport.faults.push('before-accept')
    await assert.rejects(d.engine.syncNow(),/sync_remote_result_unknown/)
    const old=structuredClone(d.store.load().intent), pub=JSON.parse(old.commitBody)
    assert.ok(pub.newPackTargets.length>0,'fixture must exercise a real publication pack')
    const pack=pub.newPackTargets[0]
    const prefix=transport.writerRootV4+pack.writer+'/packs/pack-'
    const oldPaths=pack.attempts.map(attempt=>prefix+attempt+'-'+pack.hash+'.json')
    const body=transport.files.get(oldPaths[0]); assert.ok(body)
    // Model a fully verified merged archive followed by an interrupted removal of originals.
    const aggregate=JSON.parse(body), extra=JSON.stringify({value:'extra archive member'})
    aggregate.entries.push({epoch:1,hash:wire.syncDigest(extra),bytes:wire.syncUtf8(extra).length,body:extra})
    const mergedBody=JSON.stringify(aggregate), mergedHash=wire.syncDigest(mergedBody)
    for(const id of ['50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002'])
      transport.files.set(prefix+id+'-'+mergedHash+'.json',mergedBody)
    for(const name of oldPaths.slice(0,removeCount)) transport.files.delete(name)
    const restarted=d.restart()
    await restarted.syncNow()
    transport.files.set(transport.writerRootV4+old.commit.substring(3),old.commitBody)
    const receiver=f.replica(B)
    receiver.engine.setSelection(['reader-settings'])
    await receiver.engine.saveConfiguration(transport.draft); receiver.engine.setEnabled(true)
    try {
      await receiver.engine.syncNow()
      for(const [key,value] of entries) assert.equal(receiver.values.get('reader-settings').get(key),value)
    } finally {receiver.engine.setEnabled(false); restarted.setEnabled(false)}
  } finally {d.engine.setEnabled(false)}
})
