const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')
const { transportFixture, engineFixture, compile, facts, wire, A, B, dataset, manifest, pageNumber, noop } =
  new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_journal.cjs'), 'utf8') +
  '\nreturn { transportFixture, engineFixture, compile, facts, wire, A, B, dataset, manifest, pageNumber, noop };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)

test('real Engine and Storage verify the migrated publication before retiring the old collection', async () => {
  const transport = transportFixture('https://archive-storage-review.invalid')
  const old = dataset('reader-settings-records', pageNumber, B, 'false')
  const provider = new transport.SharedWebDav(transport.draft)
  for (const object of old.objects) transport.seedObject(object)
  transport.seedCommit(manifest(provider.spaceId(), [old.ref]))
  const files = new Map()
  const fileIo = { accessSync: file => files.has(file), readTextSync: file => files.get(file),
    renameSync: (from, to) => { files.set(to, files.get(from)); files.delete(from) },
    unlink: async file => files.delete(file) }
  const { DeviceSyncStorage } = compile('DeviceSyncStorage', {
    '@kit.CoreFileKit': { fileIo }, '@kit.AssetStoreKit': {},
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: { execute: async (worker, ...args) => worker(...args) } },
    '../model/AppFileTextPersistence': { writeAppTextFile: (file, body) => files.set(file, body) },
    './DeviceSyncFacts': facts, './DeviceSyncWire': wire, './DeviceSyncWebDav': {},
  })
  const storage = new DeviceSyncStorage('/archive-review')
  storage.update(state => { state.replica = A })
  const fixture = engineFixture(transport.SharedWebDav)
  const device = fixture.replica(A)
  device.engine.storage = storage
  device.engine.setSelection(['reader-settings'])
  try {
    await device.engine.saveConfiguration(transport.draft)
    device.engine.setEnabled(true)
    await device.engine.syncNow()
    const deadline = Date.now() + 5000
    while (transport.directories.has(transport.root) && Date.now() < deadline) {
      await new Promise(resolve => setTimeout(resolve, 20))
    }
    const deletion = transport.trace.findIndex(row => row.method === 'DELETE' && row.address === transport.root)
    assert.ok(deletion >= 0, 'verified migration must retire the old collection')
    const beforeCleanup = transport.trace.slice(0, deletion)
    const head = beforeCleanup.findIndex(row => row.method === 'PUT' && row.address.startsWith(transport.sharedRoot + 'heads/'))
    assert.ok(head >= 0, 'publish the new head before cleaning up the old collection')
    assert.ok(beforeCleanup.slice(head + 1).some(row => row.method === 'GET' &&
      row.address.startsWith(transport.sharedRoot) && row.address.includes(old.ref.shards[0].hash)),
    'read back the migrated shard after publishing the new head and before any old data is removed')
    const disk = JSON.parse(files.get('/archive-review/device-sync-state.v1.json'))
    assert.ok(disk.active.revision > 0)
    assert.equal(device.values.get('reader-settings').get(pageNumber), 'false')
    const saved = await provider.readSharedHead(noop)
    const settings = saved.manifest.datasets.find(row => row.id === old.ref.id)
    const restored = await provider.readSharedObject(settings.id, settings.shards[0], noop)
    assert.ok(JSON.parse(restored).facts.length > 0)
  } finally { device.engine.setEnabled(false) }
})
