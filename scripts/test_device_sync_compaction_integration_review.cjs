const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const crypto = require('node:crypto')
let uuidSequence = 0
const randomUUID = () => '00000000-0000-4000-8000-' + (++uuidSequence).toString(16).padStart(12, '0')
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_v4.cjs'), 'utf8') +
  '\nreturn { transportFixture, wire, data, A, B, C, noop, dataset, manifest };')(
  name => name === 'node:test' ? () => {} : name === 'node:crypto' ? { ...crypto, randomUUID } : require(name), __dirname)
const { transportFixture, wire, data, A, B, C, noop, dataset, manifest } = support
const compaction = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_pack_compaction.cjs'), 'utf8') +
  '\nreturn { fixture, pack, guard, ensure };')(
  name => name === 'node:test' ? () => {} : name === 'node:crypto' ? { ...crypto, randomUUID } : require(name), __dirname)

test('oversized early group does not starve later eligible groups', async () => {
  const f = compaction.fixture()
  const add = (datasetName, payloadSize, start) => {
    let bucket, added = 0
    for (let i = 0; added < 3; i++) {
      const body = JSON.stringify({ dataset: datasetName, schema: 1, facts: [{ payload: 'x'.repeat(payloadSize), i }] })
      const entry = { epoch: 1, hash: wire.syncDigest(body), bytes: Buffer.byteLength(body), body }
      const packed = JSON.stringify({ version: 1, writer: A, entries: [entry] })
      const hash = wire.syncDigest(packed)
      if (bucket === undefined) bucket = hash[0]
      if (hash[0] !== bucket) continue
      const name = `pack-00000000-0000-4000-8000-${(start + added).toString(16).padStart(12, '0')}-${hash}.json`
      f.files.set(A + '/packs/' + name, packed)
      added++
    }
  }
  add('oversized', 132 * 1024, 1)
  add('mergeable', 100, 100)
  const before = [...f.files.keys()].filter(name => JSON.parse(f.files.get(name)).entries[0].body.includes('mergeable'))
  const session = new compaction.pack.SyncPackMaintenanceSession()
  for (let i = 0; i < 4; i++) {
    await compaction.pack.compactSyncPublicationPacks(f.store, A, compaction.guard, compaction.ensure,
      [...f.files.keys()].filter(name => name.startsWith(A + '/packs/')).map(name => name.substring((A + '/packs/').length)), 16, [], session)
  }
  assert.ok(before.some(name => !f.files.has(name)), 'eligible later group should be compacted despite oversized earlier group')
})

test('shared collection leaves another writer’s unpublished legacy pack alone', async () => {
  let now = 0
  const f = transportFixture('https://shared-collection-protection.invalid', () => now)
  const id = 'reader-settings-records'
  const first = dataset(id, data.syncKey(['global', 'page-number']), A, 'true')
  const second = dataset(id, data.syncKey(['global', 'page-number']), A, 'false')
  const writer = new f.SharedWebDav(f.draft, [], undefined, A)
  const { ref, body } = second.objects[0]
  const pack = JSON.stringify({ version: 1, writer: B, entries: [{ epoch: ref.epoch, hash: ref.hash, bytes: ref.bytes, body }] })
  const packDirectory = f.writerRootV4 + B + '/packs/'
  const pending = packDirectory + 'pack-' + randomUUID() + '-' + wire.syncDigest(pack) + '.json'
  for (const directory of [f.writerRootV4, f.writerRootV4 + B + '/', packDirectory]) f.directories.add(directory)
  f.files.set(pending, pack)
  const original = manifest(writer.spaceId(), [first.ref])
  const originalObjects = first.objects.map(object => ({ ...object, dataset: id }))
  await writer.prepareSharedMigration(original, originalObjects, noop)
  const initial = await writer.publishShared(original, originalObjects, '', noop, noop)
  const obsolete = f.trace.find(row => row.method === 'PUT' && row.address.includes(original.datasets[0].shards[0].hash)).address
  const updated = manifest(writer.spaceId(), [second.ref], 2)
  const updatedObjects = second.objects.map(object => ({ ...object, dataset: id }))
  await writer.prepareSharedMigration(updated, updatedObjects, noop)
  await writer.publishShared(updated, updatedObjects, initial.sharedHash, noop, noop)
  const sweep = { unreferenced: new Map() }
  await writer.collectSharedObjects(sweep, noop)
  assert.ok(f.files.has(obsolete), 'the first scan only marks unreferenced files')
  now = 120001
  await writer.collectSharedObjects(sweep, noop)
  assert.equal(f.files.has(obsolete), false)
  assert.equal(f.files.get(pending), pack)
  const cold = new f.SharedWebDav(f.draft, [], writer.spaceId(), C)
  const latest = await cold.readSharedHead(noop)
  assert.equal(await cold.readSharedObject(id, latest.manifest.datasets[0].shards[0], noop), updatedObjects[0].body)
})
