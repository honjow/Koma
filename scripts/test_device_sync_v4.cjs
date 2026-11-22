const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

// Execute the production WebDAV adapter using the established in-memory DAV
// transport; these cases exercise the old→new path and failure recovery.
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_journal.cjs'), 'utf8') +
  '\nreturn { transportFixture, engineFixture, wire, facts, data, metrics, A, B, C, noop, edit, dot, dataset, manifest, pageNumber, animation };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { transportFixture, engineFixture, wire, facts, data, metrics, A, B, C, noop, edit, dot,
  dataset, manifest, pageNumber, animation } = support
const v4root = f => f.draft.directory + '/koma-device-sync-v4/'
const objectPath = (f, writer, ref) => f.writerObject(writer, ref)

test('round metrics count actual retry attempts and stop recording after detaching', async () => {
  const f = transportFixture('https://metric-private.invalid')
  const client = new f.WriterWebDav(f.draft, [], undefined, A)
  const round = new metrics.DeviceSyncMetrics(metrics.syncMetricUptime())
  client.setRoundMetrics(round)
  let attempts = 0
  f.onRequest(async method => {
    if (method === 'GET' && ++attempts === 1) throw Object.assign(new Error('temporary'), { code: 2300007 })
  })
  await client.readLegacyManifest(noop)
  const before = round.snapshot(metrics.syncMetricUptime())
  assert.equal(before.requests[0].attempts, 2)
  assert.equal(before.requests[0].retries, 1)
  assert.equal(before.requests[0].namespace, 'v1')
  assert.doesNotMatch(JSON.stringify(before), /metric-private/)
  client.setRoundMetrics(undefined)
  await client.readLegacyManifest(noop)
  assert.equal(round.snapshot(metrics.syncMetricUptime()).requests[0].attempts, 2)
})

test('transient read failures retry once after the failed request is destroyed', async () => {
  for (const method of ['GET', 'PROPFIND']) {
    const f = transportFixture(`https://v4-retry-${method.toLowerCase()}.invalid`)
    let count = 0
    let destroyed = 0
    f.onDestroy(() => { destroyed++ })
    f.onRequest(async candidate => {
      if (candidate !== method) return
      count++
      if (count === 1) throw Object.assign(new Error('temporary'), { code: 2300007 })
      if (count === 2) assert.ok(destroyed >= 1)
    })
    const client = new f.WriterWebDav(f.draft, [], undefined, A)
    if (method === 'GET') await client.readLegacyManifest(noop)
    else await client.readManifest(noop)
    assert.ok(count >= 2)
  }
})

test('read retry is bounded, honours cancellation, and does not replay writes or TLS failures', async () => {
  for (const mode of ['twice', 'cancel', 'put', 'tls']) {
    const f = transportFixture(`https://v4-retry-${mode}.invalid`)
    let count = 0
    let cancelled = false
    const method = mode === 'put' ? 'PUT' : 'GET'
    f.onRequest(async candidate => {
      if (candidate !== method) return
      count++
      if (mode === 'cancel') cancelled = true
      throw Object.assign(new Error('failure'), { code: mode === 'tls' ? 2300051 : 2300007 })
    })
    const client = new f.WriterWebDav(f.draft, [], undefined, A)
    const guard = () => { if (cancelled) throw new Error('sync_connection_changed') }
    if (mode === 'put') {
      const value = dataset('reader-settings-records', pageNumber, A, 'true')
      await assert.rejects(client.storeObject(value.objects[0], guard), /sync_network_failed/)
    } else {
      await assert.rejects(client.readLegacyManifest(guard), mode === 'cancel' ? /sync_connection_changed/ :
        mode === 'tls' ? /sync_tls_failed/ : /sync_network_failed/)
    }
    assert.equal(count, mode === 'twice' ? 2 : 1)
  }
})

test('authentication, permission, not-found and malformed DAV responses are not retried', async () => {
  for (const status of [401, 403, 404]) {
    const f = transportFixture(`https://v4-status-${status}.invalid`)
    f.responseStatus(method => method === 'GET' ? status : undefined)
    const client = new f.WriterWebDav(f.draft, [], undefined, A)
    if (status === 404) assert.equal((await client.readLegacyManifest(noop)).manifest, undefined)
    else await assert.rejects(client.readLegacyManifest(noop), status === 401 ? /sync_authentication_failed/ : /sync_permission_denied/)
    assert.equal(f.trace.filter(row => row.method === 'GET').length, 1)
  }
  const f = transportFixture('https://v4-status-invalid-xml.invalid')
  f.listingBody(() => '<invalid>')
  await assert.rejects(new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop), /sync_response_invalid/)
  assert.equal(f.trace.filter(row => row.method === 'PROPFIND').length, 1)
})

function seedV3(f, writer, value) {
  f.directories.add(f.writerRoot)
  f.directories.add(f.writerRoot + writer + '/')
  f.directories.add(f.writerRoot + writer + '/00000000000000/')
  for (const object of value.objects) f.seedObject(object, f.writerRoot)
  const publication = { writer, manifest: manifest(new f.WriterWebDav(f.draft, [], undefined, writer).spaceId(), [value.ref]) }
  const body = JSON.stringify(publication)
  const name = writer + '/00000000000000/0000000000000001-' + wire.syncDigest(body) + '.json'
  f.files.set(f.writerRoot + name, body)
  return name
}

function seedV3Revision(f, writer, sequence, datasets) {
  const segment = Math.floor((sequence - 1) / 128).toString().padStart(14, '0')
  f.directories.add(f.writerRoot)
  f.directories.add(f.writerRoot + writer + '/')
  f.directories.add(f.writerRoot + writer + '/' + segment + '/')
  for (const dataset of datasets) for (const object of dataset.objects) f.seedObject(object, f.writerRoot)
  const space = new f.WriterWebDav(f.draft, [], undefined, writer).spaceId()
  const body = JSON.stringify({ writer, manifest: manifest(space, datasets.map(value => value.ref), sequence) })
  const name = writer + '/' + segment + '/' + sequence.toString().padStart(16, '0') + '-' + wire.syncDigest(body) + '.json'
  f.files.set(f.writerRoot + name, body)
  return name
}

function seedArchivedV3(f, directory, entries, writer = A) {
  const parts = ('legacy-v3/' + directory).split('/').filter(Boolean)
  let parent = v4root(f)
  f.directories.add(parent)
  for (const part of parts) { parent += part + '/'; f.directories.add(parent) }
  const values = entries.map(([path, body]) => ({ path, bytes: wire.syncUtf8(body).length, hash: wire.syncDigest(body), body }))
  const body = JSON.stringify({ format: 'KOMA_V3_ARCHIVE', version: 1, entries: values })
  const name = `pack-${writer}-${wire.syncDigest(body)}.json`
  f.files.set(parent + name, body)
}

test('a new reader discovers a v3 head that is present only in the archive', async () => {
  const f = transportFixture('https://v3-archived-head.invalid')
  const first = dataset('reader-settings-records', pageNumber, A, 'true')
  const second = dataset('reader-settings-records', animation, A, 'false')
  const old = seedV3Revision(f, A, 1, [first])
  const archived = [seedV3Revision(f, A, 2, [second]), seedV3Revision(f, A, 3, [second]),
    seedV3Revision(f, A, 4, [second])]
  seedArchivedV3(f, `commits/${A}/00000000000000/`, archived.map(name => [name, f.files.get(f.writerRoot + name)]))
  for (const name of archived) f.files.delete(f.writerRoot + name)
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  const remote = await reader.readManifest(noop)
  assert.ok(remote.frontier.includes(archived[2]))
  assert.ok(!remote.frontier.includes(old))
  assert.equal(await reader.readObject(second.ref.shards[0], noop), second.objects[0].body)
})

test('a v4 head can read an archived v3 ref absent from current v3 heads', async () => {
  const f = transportFixture('https://v3-archived-old-ref.invalid')
  const first = dataset('reader-settings-records', pageNumber, A, 'true')
  const second = dataset('reader-settings-records', animation, A, 'false')
  seedV3Revision(f, A, 1, [first])
  const owner = new f.WriterWebDav(f.draft, [], undefined, B)
  const initial = await owner.readManifest(noop)
  const carried = { ...initial.manifest, revision: 2 }
  await owner.preparePublication(carried, [], ['reader-settings-records'], noop)
  await owner.publish(carried, '', noop, noop, ['reader-settings-records'])
  seedV3Revision(f, A, 2, [second])
  const ref = first.ref.shards[0]
  const oldPath = wire.syncShardPath(ref)
  f.files.delete(f.writerRoot + oldPath)
  const reader = new f.WriterWebDav(f.draft, [], undefined, C)
  await reader.readManifest(noop)
  await assert.rejects(reader.readObject(ref, noop))
  const prefix = ref.hash[0]
  const extras = []
  for (let i = 0; extras.length < 2; i++) {
    const body = JSON.stringify({ i })
    if (wire.syncDigest(body)[0] === prefix) extras.push(['object-1-' + wire.syncDigest(body) + '.json', body])
  }
  seedArchivedV3(f, `objects/${prefix}/`, [[oldPath, first.objects[0].body], ...extras])
  assert.equal(await reader.readObject(ref, noop), first.objects[0].body)
})

test('v3 history remains readable without copying unchanged objects to the new writer', async () => {
  const f = transportFixture()
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  seedV3(f, A, old)
  const b = new f.WriterWebDav(f.draft, [], undefined, B)
  const prior = await b.readManifest(noop)
  assert.ok(prior.manifest)
  const next = { ...prior.manifest, revision: 2, previous: [old.ref] }
  await b.preparePublication(next, [], ['reader-settings-records'], noop)
  const commit = b.commitName(next, prior.frontier)
  await b.publish(next, prior.etag, noop, noop, ['reader-settings-records'])
  assert.ok(commit.startsWith('v4/' + B + '/'))
  assert.ok(!f.files.has(objectPath(f, B, old.ref.shards[0])))
  assert.equal(f.trace.filter(item => item.method === 'PUT' && item.address.includes('/' + B + '/objects/')).length, 0)
  const c = new f.WriterWebDav(f.draft, [], undefined, C)
  const remote = await c.readManifest(noop)
  assert.ok(remote.frontier.some(name => name.startsWith('v4/' + B + '/')))
  assert.equal(await c.readObject(old.ref.shards[0], noop), old.objects[0].body)
})

test('a missing v4 publication can be replayed after restart using staged private objects', async () => {
  const f = transportFixture()
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const first = new f.WriterWebDav(f.draft, [], undefined, A)
  const next = manifest(first.spaceId(), [value.ref])
  await first.preparePublication(next, value.objects, ['reader-settings-records'], noop)
  const name = first.commitName(next, [], value.objects)
  const body = first.commitBody(next, [], value.objects)
  for (const object of value.objects) await first.storeObject(object, noop)
  // Simulate a process exiting after an accepted intent but before the head PUT.
  const resumed = new f.WriterWebDav(f.draft, [], first.spaceId(), A)
  const receipt = await resumed.retryCommit(body, noop, ['reader-settings-records'], name)
  assert.equal(receipt.manifest.revision, next.revision)
  assert.notEqual(receipt.frontier[0], name)
  assert.equal(f.files.get(v4root(f) + receipt.frontier[0].substring(3)), body)
  const reader = new f.WriterWebDav(f.draft, [], first.spaceId(), B)
  await reader.readManifest(noop)
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
})

test('an existing publication is not accepted when a selected object is missing', async () => {
  const f = transportFixture('https://v4-existing-head-missing.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const next = manifest(writer.spaceId(), [value.ref])
  await writer.preparePublication(next, value.objects, ['reader-settings-records'], noop)
  const name = writer.commitName(next, [], value.objects)
  const body = writer.commitBody(next, [], value.objects)
  for (const object of value.objects) await writer.storeObject(object, noop)
  await writer.publish(next, '', noop, noop, ['reader-settings-records'])
  const resumed = new f.WriterWebDav(f.draft, [], writer.spaceId(), A)
  assert.ok(await resumed.readCommit(name, noop))
  await resumed.verifyV4Publication(name, body, ['reader-settings-records'], noop)
  f.files.delete(objectPath(f, A, value.ref.shards[0]))
  await resumed.verifyV4Publication(name, body, [], noop)
  // The exact target is recorded by this still-protected intent and cannot
  // have been retired by maintenance; it may safely be replanned.
  await assert.rejects(resumed.verifyV4Publication(name, body, ['reader-settings-records'], noop), /sync_replan_required/)
})

test('a lost v3 publication remains recoverable at its old path after upgrade', async () => {
  const f = transportFixture()
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const name = seedV3(f, A, value)
  const body = f.files.get(f.writerRoot + name)
  f.files.delete(f.writerRoot + name)
  const resumed = new f.WriterWebDav(f.draft, [], undefined, A)
  const receipt = await resumed.retryCommit(body, noop, [], name)
  assert.equal(receipt.manifest.revision, 1)
  assert.equal(f.files.get(f.writerRoot + name), body)
})

test('damaged legacy v3 head falls back across versions before and after v4 exists', async () => {
  for (const hasV4 of [false, true]) {
    const f = transportFixture()
    const settings = 'reader-settings-records'
    const first = [edit(facts.emptySyncFact(pageNumber), dot(A, 1), 'set', 'true')]
    const next = [edit(first[0], dot(A, 2), 'set', 'false')]
    const previous = wire.buildSyncDataset(settings, first, 1, undefined, data.syncBucketKey)
    const latest = wire.buildSyncDataset(settings, next, 1, previous.ref, data.syncBucketKey)
    seedV3Revision(f, A, 128, [previous])
    seedV3Revision(f, A, 129, [latest])
    f.files.set(f.writerRoot + wire.syncShardPath(latest.ref.shards[0]), 'damaged')
    if (hasV4) {
      const b = new f.WriterWebDav(f.draft, [], undefined, B)
      const extra = dataset('reader-settings-records', animation, B, 'false')
      for (const object of extra.objects) await b.storeObject(object, noop)
      await b.publish(manifest(b.spaceId(), [extra.ref]), '', noop, noop, [settings])
    }
    for (let i = 0; i < 2; i++) {
      const reader = new f.WriterWebDav(f.draft, [], undefined, C)
      const remote = await reader.readManifest(noop)
      assert.equal(remote.old, undefined, 'v3 heads must not masquerade as the shared v1/v2 baseline')
      const head = remote.writerHeads.find(row => row.path.startsWith(A + '/'))
      assert.ok(head)
      let recovered
      assert.equal(await reader.readEarlierWriterGroup(head, noop, async candidate => {
        recovered = candidate
        return true
      }), true)
      assert.equal(recovered.revision, 128)
      assert.equal(await reader.readObject(previous.ref.shards[0], noop), previous.objects[0].body)
    }
    const device = engineFixture(f.WriterWebDav).replica(C)
    device.engine.setSelection(['reader-settings'])
    await device.engine.saveConfiguration(f.draft)
    device.engine.setEnabled(true)
    await assert.rejects(device.engine.syncNow(), /sync_partial:sync_shard_damaged/)
    assert.equal(device.values.get('reader-settings').get(pageNumber), 'true')
  }
})

test('an unrelated damaged v3 group, including empty written scope, is preserved without blocking publication', async () => {
  for (const scope of [[], ['shelf-records']]) {
    const f = transportFixture()
    const old = dataset('reader-settings-records', pageNumber, A, 'true')
    seedV3(f, A, old)
    const writer = new f.WriterWebDav(f.draft, [], undefined, B)
    const remote = await writer.readManifest(noop)
    f.files.set(f.writerRoot + wire.syncShardPath(old.ref.shards[0]), 'damaged')
    const denied = wire.syncShardPath(old.ref.shards[0])
    f.onRequest(async (method, address) => {
      if (method === 'GET' && address.endsWith('/' + denied)) throw Object.assign(new Error('unavailable'), { code: 2300007 })
    })
    const healthy = dataset('shelf-records', data.syncKey(['book', 'x', '1']), B, 'true')
    for (const item of healthy.objects) await writer.storeObject(item, noop)
    const next = { ...remote.manifest, revision: 2, datasets: [old.ref, healthy.ref] }
    await writer.preparePublication(next, [], scope, noop)
    const name = writer.commitName(next, remote.frontier)
    const before = f.trace.length
    await writer.publish(next, '', noop, noop, scope)
    assert.equal(f.trace.slice(before).some(row => row.method === 'GET' && row.address.endsWith('/' + denied)), false)
    const body = f.files.get(v4root(f) + name.substring(3))
    assert.ok(body)
    assert.ok(JSON.parse(body).manifest.datasets.some(value => value.id === old.ref.id))
    assert.ok(!JSON.parse(body).locations.some(location => location.hash === old.ref.shards[0].hash))
  }
})

test('a damaged old object falls back to a verified v2 copy', async () => {
  const f = transportFixture()
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  seedV3(f, A, value)
  const ref = value.ref.shards[0]
  f.files.set(f.writerRoot + wire.syncShardPath(ref), 'broken')
  f.seedObject(value.objects[0])
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  await reader.readManifest(noop)
  assert.equal(await reader.readObject(ref, noop), value.objects[0].body)
})

test('v3 shard lookup reads its known location before probing other v4 writers', async () => {
  const f = transportFixture()
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  seedV3(f, A, value)
  const carrier = new f.WriterWebDav(f.draft, [], undefined, B)
  const previous = await carrier.readManifest(noop)
  const carried = { ...previous.manifest, revision: 2 }
  await carrier.preparePublication(carried, [], ['reader-settings-records'], noop)
  await carrier.publish(carried, '', noop, noop, ['reader-settings-records'])
  for (const writer of [B, C]) {
    f.directories.add(v4root(f))
    f.directories.add(v4root(f) + writer + '/')
  }
  const reader = new f.WriterWebDav(f.draft, [], undefined, C)
  await reader.readManifest(noop)
  const before = f.trace.length
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
  const gets = f.trace.slice(before).filter(row => row.method === 'GET')
  assert.equal(gets.length, 1)
  assert.equal(gets[0].address, f.writerRoot + wire.syncShardPath(value.ref.shards[0]))
})

test('an exact v4 locator takes priority and falls back to v3 if its content is damaged', async () => {
  const f = transportFixture('https://v4-locator-priority.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  seedV3(f, A, value)
  const writer = new f.WriterWebDav(f.draft, [], undefined, B)
  const prior = await writer.readManifest(noop)
  const next = { ...prior.manifest, revision: 2 }
  await writer.preparePublication(next, value.objects, ['reader-settings-records'], noop)
  for (const object of value.objects) await writer.storeObject(object, noop)
  await writer.publish(next, '', noop, noop, ['reader-settings-records'])
  const reader = new f.WriterWebDav(f.draft, [], undefined, C)
  await reader.readManifest(noop)
  let before = f.trace.length
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
  let gets = f.trace.slice(before).filter(row => row.method === 'GET')
  assert.equal(gets.length, 1)
  assert.equal(gets[0].address, objectPath(f, B, value.ref.shards[0]))
  f.files.set(objectPath(f, B, value.ref.shards[0]), 'broken')
  before = f.trace.length
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
  gets = f.trace.slice(before).filter(row => row.method === 'GET')
  assert.equal(gets[0].address, objectPath(f, B, value.ref.shards[0]))
  assert.equal(gets.at(-1).address, f.writerRoot + wire.syncShardPath(value.ref.shards[0]))
})

test('two upgraded v3 writers keep their own records instead of duplicating received records', async () => {
  const f = transportFixture()
  const aOld = dataset('reader-settings-records', pageNumber, A, 'true')
  const bOld = dataset('reader-settings-records', animation, B, 'false')
  seedV3Revision(f, A, 1, [aOld])
  seedV3Revision(f, B, 1, [bOld])
  const fixture = engineFixture(f.WriterWebDav)
  const a = fixture.replica(A)
  const b = fixture.replica(B)
  for (const device of [a, b]) {
    device.engine.setSelection(['reader-settings'])
    await device.engine.saveConfiguration(f.draft)
    device.engine.setEnabled(true)
    await device.engine.syncNow()
    device.store.update(state => { state.counter = Math.max(state.counter, 2) })
  }
  a.values.get('reader-settings').set(pageNumber, 'false')
  a.engine.recordEdits('reader-settings', [{ key: pageNumber, kind: 'set', value: 'false' }])
  await a.engine.syncNow()
  b.values.get('reader-settings').set(animation, 'true')
  b.engine.recordEdits('reader-settings', [{ key: animation, kind: 'set', value: 'true' }])
  await b.engine.syncNow()
  const keys = writer => {
    const entries = [...f.files.entries()].filter(([name]) => name.startsWith(v4root(f) + writer + '/') &&
      /\/[0-9]{16}-[0-9a-f]{64}(?:-[0-9a-f-]{36})?\.json$/.test(name)).sort(([a], [b]) => a.localeCompare(b))
    assert.ok(entries.length > 0)
    const head = JSON.parse(entries.at(-1)[1]).manifest
    return head.datasets.flatMap(ref => ref.shards.flatMap(shard => {
      const body = f.files.get(objectPath(f, writer, shard))
      assert.ok(body)
      return wire.decodeSyncShard(ref.id, shard, body, data.syncBucketKey).map(fact => fact.key)
    }))
  }
  assert.ok(keys(A).includes(pageNumber))
  assert.ok(!keys(A).includes(animation))
  assert.ok(keys(B).includes(animation))
  assert.ok(!keys(B).includes(pageNumber))
})

test('healthy v4 writer can advance despite a damaged older v3 head', async () => {
  const f = transportFixture('https://v4-damaged-v3.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const name = seedV3Revision(f, A, 1, [old])
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  for (const object of old.objects) await writer.storeObject(object, noop)
  const next = manifest(writer.spaceId(), [old.ref], 2)
  await writer.publish(next, '', noop, noop, ['reader-settings-records'])
  f.files.set(f.writerRoot + name, 'damaged-publication')
  const restarted = new f.WriterWebDav(f.draft, [], writer.spaceId(), A)
  const remote = await restarted.readManifest(noop)
  assert.equal(remote.ownWritable, true)
  assert.equal(remote.own.revision, 2)
  assert.ok(remote.warning)
  const newer = { ...remote.own, revision: 3 }
  await restarted.publish(newer, '', noop, noop, ['reader-settings-records'])
  assert.ok(f.files.has(v4root(f) + restarted.commitName(newer, []).substring(3)))
})

test('a previously missing unselected ref becomes readable when later selected without copying', async () => {
  const f = transportFixture('https://v4-reopen-group.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  seedV3(f, A, value)
  const b = new f.WriterWebDav(f.draft, [], undefined, B)
  const old = await b.readManifest(noop)
  const legacyPath = f.writerRoot + wire.syncShardPath(value.ref.shards[0])
  const healthy = f.files.get(legacyPath)
  f.files.delete(legacyPath)
  const first = { ...old.manifest, revision: 2 }
  await b.publish(first, '', noop, noop, [])
  assert.ok(!f.files.has(objectPath(f, B, value.ref.shards[0])))
  f.files.set(legacyPath, healthy)
  const reopened = new f.WriterWebDav(f.draft, [], b.spaceId(), B)
  const remote = await reopened.readManifest(noop)
  const updated = { ...remote.own, revision: 3 }
  await reopened.publish(updated, '', noop, noop, ['reader-settings-records'])
  assert.ok(!f.files.has(objectPath(f, B, value.ref.shards[0])))
  const reader = new f.WriterWebDav(f.draft, [], b.spaceId(), C)
  await reader.readManifest(noop)
  assert.equal(await reader.readObject(value.ref.shards[0], noop), healthy)
})

test('a second writer publishes one change without copying existing v4 shards', async () => {
  const f = transportFixture('https://v4-reuse-shards.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const added = dataset('shelf-records', data.syncKey(['book', 'x', '1']), B, 'true')
  const a = new f.WriterWebDav(f.draft, [], undefined, A)
  const first = manifest(a.spaceId(), [old.ref])
  await a.preparePublication(first, old.objects, ['reader-settings-records'], noop)
  for (const object of old.objects) await a.storeObject(object, noop)
  await a.publish(first, '', noop, noop, ['reader-settings-records'])
  const b = new f.WriterWebDav(f.draft, [], a.spaceId(), B)
  const prior = await b.readManifest(noop)
  const next = manifest(a.spaceId(), [old.ref, added.ref], 2)
  await b.preparePublication(next, added.objects, ['reader-settings-records', 'shelf-records'], noop)
  b.commitName(next, prior.frontier, added.objects)
  const start = f.trace.length
  for (const object of added.objects) await b.storeObject(object, noop)
  await b.publish(next, '', noop, noop, ['reader-settings-records', 'shelf-records'])
  const puts = f.trace.slice(start).filter(item => item.method === 'PUT' && item.address.includes('/' + B + '/objects/'))
  assert.equal(puts.length, added.objects.length)
  assert.ok(!f.files.has(objectPath(f, B, old.ref.shards[0])))
  const c = new f.WriterWebDav(f.draft, [], a.spaceId(), C)
  await c.readManifest(noop)
  assert.equal(await c.readObject(old.ref.shards[0], noop), old.objects[0].body)
  assert.equal(await c.readObject(added.ref.shards[0], noop), added.objects[0].body)
})

test('a different writer reads objects after the source writer packs them', async () => {
  const f = transportFixture('https://v4-pack-cross-writer.invalid')
  const id = 'reader-settings-records'
  const rows = Array.from({ length: 100 }, (_, index) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + index])
    return edit(facts.emptySyncFact(key), dot(A, index + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const value = wire.buildSyncDataset(id, rows, 1, undefined, data.syncBucketKey)
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const next = manifest(writer.spaceId(), [value.ref])
  await writer.preparePublication(next, value.objects, [id], noop)
  const singles = await writer.writePlannedPacks(noop, noop, noop)
  for (const object of singles) await writer.storeObject(object, noop)
  await writer.publish(next, '', noop, noop, [id])
  const packed = value.objects.find(object => !singles.includes(object))
  assert.ok(packed)
  assert.equal(f.files.has(objectPath(f, A, packed.ref)), false)
  const reader = new f.WriterWebDav(f.draft, [], writer.spaceId(), B)
  await reader.readManifest(noop)
  // An eventually consistent server may briefly hide both pack copies.
  f.responseStatus((method, address) =>
    (method === 'GET' || method === 'PROPFIND') && address.includes('/' + A + '/packs/') ? 404 : undefined)
  await assert.rejects(reader.readObject(packed.ref, noop), /sync_pack_not_found|sync_shard_not_found/)
  f.responseStatus(() => undefined)
  assert.equal(await reader.readObject(packed.ref, noop), packed.body)
})

test('cached focus manifest can read another work from the original writer pack', async () => {
  const f = transportFixture('https://v4-pack-focus.invalid')
  const device = engineFixture(f.WriterWebDav).replica(B)
  device.engine.setSelection(['reading'])
  await device.engine.saveConfiguration(f.draft)
  device.engine.setEnabled(true)
  await device.engine.syncNow()
  const source = 'org.example.focus'
  const records = []
  for (let i = 0; i < 120; i++) {
    const work = 'work:' + i
    const chapter = 'chapter:' + i
    const recent = data.syncKey(['recent', source, work])
    const value = JSON.stringify(data.syncReadingRecent(source, chapter, 200 + i, 'Book', 'Source', chapter, 5))
    records.push(edit(facts.emptySyncFact(recent), dot(A, i + 1), 'set', value))
  }
  const value = wire.buildSyncDataset(data.SYNC_READING_DATASET, records, 1, undefined, data.syncBucketKey)
  assert.ok(value.objects.length >= 32)
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const head = manifest(writer.spaceId(), [value.ref])
  await writer.preparePublication(head, value.objects, [value.ref.id], noop)
  const singles = await writer.writePlannedPacks(noop, noop, noop)
  assert.ok(singles.length < value.objects.length)
  for (const object of singles) await writer.storeObject(object, noop)
  await writer.publish(head, '', noop, noop, [value.ref.id])
  try {
    const first = await device.engine.syncReadingWork(source, 'work:0')
    const second = await device.engine.syncReadingWork(source, 'work:1')
    assert.equal(first.applied, true)
    assert.equal(second.applied, true)
    assert.ok(device.values.get('reading').has(data.syncKey(['recent', source, 'work:0'])))
    assert.ok(device.values.get('reading').has(data.syncKey(['recent', source, 'work:1'])))
  } finally { device.engine.setEnabled(false) }
})

test('a staged private v4 object can recover when another advertised owner lacks that object', async () => {
  const f = transportFixture('https://v4-staged-fallback.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const a = new f.WriterWebDav(f.draft, [], undefined, A)
  const next = manifest(a.spaceId(), [value.ref])
  for (const item of value.objects) await a.storeObject(item, noop)
  await a.publish(next, '', noop, noop, ['reader-settings-records'])
  const b = new f.WriterWebDav(f.draft, [], undefined, B)
  for (const item of value.objects) await b.storeObject(item, noop)
  await b.readManifest(noop)
  f.files.delete(objectPath(f, A, value.ref.shards[0]))
  assert.equal(await b.readObject(value.ref.shards[0], noop), value.objects[0].body)
})

test('v3 background discovery cache honors known witnesses and manual rescans', async () => {
  const f = transportFixture('https://v3-cache-witness.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const aHead = seedV3Revision(f, A, 1, [old])
  const newWriter = new f.WriterWebDav(f.draft, [], undefined, B)
  const extra = dataset('reader-settings-records', animation, B, 'false')
  for (const item of extra.objects) await newWriter.storeObject(item, noop)
  const current = manifest(newWriter.spaceId(), [extra.ref])
  await newWriter.publish(current, '', noop, noop, ['reader-settings-records'])
  const v4Head = newWriter.commitName(current, [])
  const reader = new f.WriterWebDav(f.draft, [aHead, v4Head], undefined, C)
  await reader.readManifest(noop)
  const prior = f.trace.length
  await reader.readManifest(noop, '', true)
  assert.equal(f.trace.slice(prior).filter(row => row.method === 'PROPFIND' && row.address === f.writerRoot).length, 0)
  const late = dataset('reader-settings-records', animation, C, 'true')
  const lateHead = seedV3Revision(f, C, 1, [late])
  const withWitness = new f.WriterWebDav(f.draft, [aHead, v4Head, lateHead], undefined, B)
  const before = f.trace.length
  const result = await withWitness.readManifest(noop, '', true)
  assert.ok(f.trace.slice(before).some(row => row.method === 'PROPFIND' && row.address === f.writerRoot))
  assert.ok(result.frontier.includes(lateHead))
  const manual = f.trace.length
  await reader.readManifest(noop, '', false)
  assert.ok(f.trace.slice(manual).some(row => row.method === 'PROPFIND' && row.address === f.writerRoot))
})

test('v3 background snapshots belong to their writer and each root is scanned once', async () => {
  const f = transportFixture('https://v3-writer-cache-isolation.invalid')
  const aOld = dataset('reader-settings-records', pageNumber, A, 'true')
  const bOld = dataset('reader-settings-records', animation, B, 'false')
  const aHead = seedV3Revision(f, A, 1, [aOld])
  const bHead = seedV3Revision(f, B, 1, [bOld])
  const c = new f.WriterWebDav(f.draft, [], undefined, C)
  const current = manifest(c.spaceId(), [])
  await c.publish(current, '', noop, noop, [])
  const witnesses = [aHead, bHead, c.commitName(current, [])]
  const a = new f.WriterWebDav(f.draft, witnesses, undefined, A)
  const beforeA = f.trace.length
  const aState = await a.readManifest(noop)
  const scansA = f.trace.slice(beforeA).filter(row => row.method === 'PROPFIND')
  assert.equal(scansA.filter(row => row.address === f.writerRoot).length, 1)
  assert.equal(scansA.filter(row => row.address === v4root(f)).length, 1)
  assert.equal(aState.own.datasets[0].shards[0].hash, aOld.ref.shards[0].hash)
  const b = new f.WriterWebDav(f.draft, witnesses, undefined, B)
  const beforeB = f.trace.length
  const bState = await b.readManifest(noop, '', true)
  assert.ok(f.trace.slice(beforeB).some(row => row.method === 'PROPFIND' && row.address === f.writerRoot))
  assert.equal(bState.own.datasets[0].shards[0].hash, bOld.ref.shards[0].hash)
})

test('racing old shard reads share one head rediscovery and retry if v4 advanced', async () => {
  const f = transportFixture('https://v4-reader-compaction-race.invalid')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const first = dataset('reader-settings-records', pageNumber, A, 'true')
  for (const object of first.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [first.ref], 1), '', noop, noop, ['reader-settings-records'])
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  await reader.readManifest(noop)
  const nextFacts = [edit(facts.emptySyncFact(pageNumber), dot(A, 2), 'set', 'false')]
  const next = wire.buildSyncDataset('reader-settings-records', nextFacts, 1, first.ref, data.syncBucketKey)
  for (const object of next.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [next.ref], 2), '', noop, noop, ['reader-settings-records'])
  f.files.delete(objectPath(f, A, first.ref.shards[0]))
  const before = f.trace.length
  const results = await Promise.allSettled(Array.from({ length: 4 }, () => reader.readObject(first.ref.shards[0], noop)))
  assert.ok(results.every(result => result.status === 'rejected' && result.reason.message === 'sync_remote_changed'))
  assert.equal(f.trace.slice(before).filter(row => row.method === 'PROPFIND' && row.address === v4root(f)).length, 1)
  const latest = await reader.readManifest(noop)
  assert.equal(latest.manifest.revision, 2)
})

test('a missing observed head cannot silently rewind to an older publication', async () => {
  const f = transportFixture('https://v4-missing-observed-head.invalid')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  for (const object of value.objects) await writer.storeObject(object, noop)
  const first = manifest(writer.spaceId(), [value.ref], 1)
  const second = manifest(writer.spaceId(), [value.ref], 2)
  await writer.publish(first, '', noop, noop, ['reader-settings-records'])
  await writer.publish(second, '', noop, noop, ['reader-settings-records'])
  const known = writer.commitName(second, [])
  const reader = new f.WriterWebDav(f.draft, [known], undefined, B)
  f.files.delete(v4root(f) + known.substring(3))
  await assert.rejects(reader.readManifest(noop), /sync_remote_changed/)
})

test('a later missing object rechecks the head after an earlier unchanged discovery', async () => {
  const f = transportFixture('https://v4-sequential-missing.invalid')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const first = dataset('reader-settings-records', pageNumber, A, 'true')
  for (const item of first.objects) await writer.storeObject(item, noop)
  await writer.publish(manifest(writer.spaceId(), [first.ref], 1), '', noop, noop, ['reader-settings-records'])
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  await reader.readManifest(noop)
  f.files.delete(objectPath(f, A, first.ref.shards[0]))
  await assert.rejects(reader.readObject(first.ref.shards[0], noop), /sync_pack_not_found/)
  const changed = dataset('reader-settings-records', animation, A, 'false')
  for (const item of changed.objects) await writer.storeObject(item, noop)
  await writer.publish(manifest(writer.spaceId(), [changed.ref], 2), '', noop, noop, ['reader-settings-records'])
  await assert.rejects(reader.readObject(first.ref.shards[0], noop), /sync_remote_changed/)
})

test('a stale listing that still names a missing known head cannot cause rewind', async () => {
  const f = transportFixture('https://v4-stale-listed-head.invalid')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  for (const object of value.objects) await writer.storeObject(object, noop)
  const first = manifest(writer.spaceId(), [value.ref], 1)
  const second = manifest(writer.spaceId(), [value.ref], 2)
  await writer.publish(first, '', noop, noop, ['reader-settings-records'])
  await writer.publish(second, '', noop, noop, ['reader-settings-records'])
  const known = writer.commitName(second, [])
  const filename = known.split('/').at(-1)
  f.files.delete(v4root(f) + known.substring(3))
  f.listing(names => names.some(name => /^0000000000000001-/.test(name)) ? names.concat(filename) : names)
  const reader = new f.WriterWebDav(f.draft, [known], undefined, B)
  await assert.rejects(reader.readManifest(noop), /sync_remote_changed/)
})

test('a cached known head is rechecked when a stale listing still names it', async () => {
  const f = transportFixture('https://v4-stale-cached-head.invalid')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  for (const item of value.objects) await writer.storeObject(item, noop)
  const first = manifest(writer.spaceId(), [value.ref], 1)
  const second = manifest(writer.spaceId(), [value.ref], 2)
  await writer.publish(first, '', noop, noop, ['reader-settings-records'])
  await writer.publish(second, '', noop, noop, ['reader-settings-records'])
  const known = writer.commitName(second, [])
  const reader = new f.WriterWebDav(f.draft, [known], undefined, B)
  await reader.readManifest(noop)
  f.files.delete(v4root(f) + known.substring(3))
  const filename = known.split('/').at(-1)
  f.listing(names => names.some(name => /^0000000000000001-/.test(name)) ? names.concat(filename) : names)
  await assert.rejects(reader.readManifest(noop), /sync_remote_changed/)
})

test('v2 and v4 listings reject empty, truncated, non-DAV and failed self responses', async () => {
  const bad = ['', '<html>error</html>', '<d:multistatus xmlns:d="DAV:"><d:response>',
    '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/koma-device-sync-v2/</d:href>' +
    '<d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>' +
    '<d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat></d:response></d:multistatus>',
    '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/koma-device-sync-v2/</d:href>' +
    '<d:propstat><d:prop><d:displayname>root</d:displayname></d:prop><d:status>HTTP/1.1 201 Created</d:status></d:propstat>' +
    '<d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>' +
    '<d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat></d:response></d:multistatus>']
  for (let i = 0; i < bad.length; i++) {
    const f = transportFixture('https://v2-bad-list-' + i + '.invalid')
    f.listingBody((address, body) => address === f.root ? bad[i] : body)
    const reader = new f.WriterWebDav(f.draft, [], undefined, A)
    await assert.rejects(reader.readManifest(noop), /sync_response_invalid/)
  }
  const f = transportFixture('https://v4-bad-list.invalid')
  f.directories.add(v4root(f))
  f.listingBody((address, body) => address === v4root(f) ? '<html>error</html>' : body)
  const reader = new f.WriterWebDav(f.draft, [], undefined, A)
  await assert.rejects(reader.readManifest(noop), /sync_response_invalid/)
})

test('a timed-out object PUT cannot overwrite the replacement when it arrives late', async () => {
  const f = transportFixture('https://v4-late-object.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const first = new f.WriterWebDav(f.draft, [], undefined, A)
  const next = manifest(first.spaceId(), [value.ref])
  await first.preparePublication(next, value.objects, ['reader-settings-records'], noop)
  const firstBody = first.commitBody(next, [], value.objects)
  let delayedAddress, delayedBody
  f.onRequest(async (method, address) => {
    if (method === 'PUT' && address.includes('/objects/') && !delayedAddress) {
      delayedAddress = address
      delayedBody = f.trace.at(-1).body
      throw Object.assign(new Error('timeout'), { code: 2300028 })
    }
  })
  await assert.rejects(first.storeObject(value.objects[0], noop), /sync_network_timeout/)
  f.onRequest(async () => {})
  const retry = new f.WriterWebDav(f.draft, [], first.spaceId(), A)
  await retry.preparePublication(next, value.objects, ['reader-settings-records'], noop)
  const retryBody = retry.commitBody(next, [], value.objects)
  for (const object of value.objects) await retry.storeObject(object, noop)
  await retry.publish(next, '', noop, noop, ['reader-settings-records'])
  assert.notEqual(JSON.parse(firstBody).locations[0].attempt, JSON.parse(retryBody).locations[0].attempt)
  // A late server-side write may be partial, not merely the same complete body.
  f.files.set(delayedAddress, delayedBody.slice(0, Math.max(1, delayedBody.length >> 1)))
  const reader = new f.WriterWebDav(f.draft, [], first.spaceId(), B)
  await reader.readManifest(noop)
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
})

test('a delayed publication and its retry have distinct paths and one logical head', async () => {
  const f = transportFixture('https://v4-late-publication.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const next = manifest(writer.spaceId(), [value.ref])
  await writer.preparePublication(next, value.objects, ['reader-settings-records'], noop)
  const firstName = writer.commitName(next, [], value.objects)
  const body = writer.commitBody(next, [], value.objects)
  for (const object of value.objects) await writer.storeObject(object, noop)
  f.faults.push('before-accept')
  await assert.rejects(writer.publish(next, '', noop, noop, ['reader-settings-records']))
  const resumed = new f.WriterWebDav(f.draft, [], writer.spaceId(), A)
  const receipt = await resumed.retryCommit(body, noop, ['reader-settings-records'], firstName)
  assert.notEqual(receipt.frontier[0], firstName)
  f.files.set(v4root(f) + firstName.substring(3), body)
  const reader = new f.WriterWebDav(f.draft, [], writer.spaceId(), B)
  const merged = await reader.readManifest(noop)
  assert.equal(merged.warning, '')
  assert.equal(merged.frontier.filter(path => path.startsWith('v4/' + A + '/')).length, 1)
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
})

test('different publications at the same writer sequence remain an explicit conflict', async () => {
  const f = transportFixture('https://v4-same-seq-conflict.invalid')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const first = dataset('reader-settings-records', pageNumber, A, 'true')
  const second = dataset('reader-settings-records', animation, A, 'false')
  for (const item of first.objects) await writer.storeObject(item, noop)
  await writer.publish(manifest(writer.spaceId(), [first.ref], 1), '', noop, noop, ['reader-settings-records'])
  for (const item of second.objects) await writer.storeObject(item, noop)
  await writer.publish(manifest(writer.spaceId(), [second.ref], 1), '', noop, noop, ['reader-settings-records'])
  const reader = new f.WriterWebDav(f.draft, [], writer.spaceId(), B)
  const remote = await reader.readManifest(noop)
  assert.equal(remote.warning, 'sync_writer_conflicting_publications')
})

test('an incomplete attempt does not mask another valid copy of the same publication', async () => {
  const f = transportFixture('https://v4-partial-attempt.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  for (const object of value.objects) await writer.storeObject(object, noop)
  const next = manifest(writer.spaceId(), [value.ref])
  await writer.publish(next, '', noop, noop, ['reader-settings-records'])
  const valid = writer.commitName(next, [])
  const physical = valid.substring(3)
  const parts = physical.match(/^(.*-)([0-9a-f-]{36})\.json$/)
  assert.ok(parts)
  f.files.set(v4root(f) + parts[1] + 'ffffffff-ffff-ffff-ffff-ffffffffffff.json', '{')
  const reader = new f.WriterWebDav(f.draft, [], writer.spaceId(), B)
  const remote = await reader.readManifest(noop)
  assert.equal(remote.warning, '')
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
})

test('cancelling while a shard is validated prevents its upload', async () => {
  const f = transportFixture('https://v4-worker-cancel.invalid')
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  let permitted = true
  f.onTask(async () => { permitted = false })
  const guard = () => { if (!permitted) throw new Error('sync_connection_changed') }
  await assert.rejects(writer.storeObject(value.objects[0], guard), /sync_connection_changed/)
  assert.equal(f.trace.some(row => row.method === 'PUT'), false)
})

test('a DAV listing may contain XML comments and processing instructions after its root', async () => {
  const f = transportFixture('https://v4-xml-trailing-comments.invalid')
  f.listingBody((_address, body) => body + '\n<!-- directory complete -->\n<?sample test?>\n')
  const reader = new f.WriterWebDav(f.draft, [], undefined, A)
  const remote = await reader.readManifest(noop)
  assert.equal(remote.manifest, undefined)
})

test('percent-escape case is ignored for DAV paths without decoding encoded slashes', async () => {
  const f = transportFixture('https://v4-escaped.invalid/%E6%B5%8B%E8%AF%95')
  f.listingBody((_address, body) => body.replace(/%[0-9A-F]{2}/g, value => value.toLowerCase()))
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  for (const object of value.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [value.ref]), '', noop, noop, ['reader-settings-records'])
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  const remote = await reader.readManifest(noop)
  assert.ok(remote.manifest)
  assert.equal(await reader.readObject(value.ref.shards[0], noop), value.objects[0].body)
  const escaped = transportFixture('https://v4-escaped-slash.invalid/%E6%B5%8B%E8%AF%95')
  escaped.listingBody((address, body) => address === escaped.root ?
    body.replace('%E8%AF%95/koma-device-sync-v2', '%E8%AF%95%2Fkoma-device-sync-v2') : body)
  await assert.rejects(new escaped.WriterWebDav(escaped.draft, [], undefined, A).readManifest(noop), /sync_response_invalid/)
})

test('DAV namespace prefixes may contain a dot and end tags may contain whitespace', async () => {
  const f = transportFixture('https://v4-dotted-prefix.invalid')
  f.listingBody((_address, body) => body.replace(/xmlns:d=/g, 'xmlns:d.foo=').replace(/d:/g, 'd.foo:')
    .replace(/<\/(d\.foo:[a-z]+)>/g, '</$1 >'))
  const reader = new f.WriterWebDav(f.draft, [], undefined, A)
  const remote = await reader.readManifest(noop)
  assert.equal(remote.manifest, undefined)
})
