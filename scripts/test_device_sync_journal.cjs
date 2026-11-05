const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')

// Reuse the existing ArkTS loader; execute production Journal, Engine and HTTP adapter.
// Only NetworkKit, native credentials and owner persistence are host substitutes.
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { compile, wire, facts, data, journal, engineFixture, A, B, C, dot, edit };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { compile, wire, facts, data, journal, engineFixture, A, B, C, dot, edit } = support
const models = compile('../remote/WebDavModels')
const xml = compile('../remote/WebDavClient', { './WebDavModels': models })
const noop = () => {}
const clone = value => structuredClone(value)
const response = (status, body = '') => ({ responseCode: status,
  result: Uint8Array.from(Buffer.from(body)).buffer, header: {} })

function transportFixture() {
  const draft = { directory: 'https://local-fixture.invalid', username: '', password: '' }
  const directory = draft.directory + '/'
  const root = directory + 'koma-device-sync-v2/'
  const legacy = directory + 'koma-device-sync-v1/'
  const files = new Map()
  const directories = new Set([directory, root])
  const trace = []
  const faults = []
  let filterListing = names => names
  let beforeCommit = async () => {}
  const resource = (address, collection) => '<d:response><d:href>' + new URL(address).pathname +
    '</d:href><d:propstat><d:prop><d:resourcetype>' + (collection ? '<d:collection/>' : '') +
    '</d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
  const http = { HttpDataType: { ARRAY_BUFFER: 2 }, createHttp: () => ({
    async request(address, options) {
      const method = options.customMethod
      trace.push({ method, address, body: options.extraData, headers: clone(options.header) })
      assert.equal(options.usingCache, false)
      assert.equal(options.maxRedirects, 0)
      if (method === 'PROPFIND') {
        if (!directories.has(address)) return response(404)
        const names = options.header.Depth === '0' ? [] : filterListing([...files.keys()]
          .filter(name => name.startsWith(root)).map(name => name.slice(root.length)))
        return response(207, '<d:multistatus xmlns:d="DAV:">' + resource(address, true) +
          names.map(name => resource(root + name, false)).join('') + '</d:multistatus>')
      }
      if (method === 'MKCOL') { directories.add(address); return response(201) }
      if (method === 'GET') return files.has(address) ? response(200, files.get(address)) : response(404)
      if (method === 'DELETE') { files.delete(address); return response(204) }
      if (method === 'PUT') {
        const isCommit = journal.SYNC_COMMIT_NAME.test(address.slice(root.length))
        if (isCommit) await beforeCommit(address, options.extraData)
        const failure = isCommit ? faults.shift() : undefined
        if (failure === 'before-accept') throw Object.assign(new Error('offline'), { code: 2300007 })
        // Intentionally no ETag or conditional-header enforcement: this models the reported server.
        files.set(address, options.extraData)
        if (failure === 'lost-response') throw Object.assign(new Error('reply lost'), { code: 2300007 })
        return response(201)
      }
      throw new Error('Unexpected method ' + method)
    },
    destroy() {},
  }) }
  const { DeviceSyncWebDav } = compile('DeviceSyncWebDav', {
    './DeviceSyncWire': wire, './DeviceSyncJournal': journal, '../remote/WebDavClient': xml,
    '@kit.NetworkKit': { http },
    '@kit.ArkTS': { url: { URL: { parseURL: text => new URL(text) } }, util: {
      Base64Helper: class { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64') } },
      TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder('utf-8', { fatal: true }).decode(bytes) }) },
    } },
  })
  function seedObject(object, base = root) { files.set(base + wire.syncShardPath(object.ref), object.body) }
  function seedCommit(manifest, parents = []) {
    const body = journal.syncCommitBody(manifest, parents)
    const name = journal.syncCommitName(body)
    files.set(root + name, body)
    return name
  }
  return { draft, root, legacy, files, directories, trace, faults, DeviceSyncWebDav, seedObject, seedCommit,
    provider: witnesses => new DeviceSyncWebDav(draft, witnesses),
    listing: filter => { filterListing = filter }, onCommit: hook => { beforeCommit = hook } }
}

function dataset(group, key, replica, value) {
  return wire.buildSyncDataset(group,
    [edit(facts.emptySyncFact(key), dot(replica, 1), 'set', value)], 1, undefined, data.syncBucketKey)
}
function manifest(space, datasets, revision = 1) {
  return { ...wire.newSyncManifest(space), revision, datasets, previous: [] }
}
const pageNumber = data.syncKey(['global', 'page-number'])
const animation = data.syncKey(['global', 'animation'])

test('connection creates the selected directory and cleans its probe without ETag or conditional-write support', async () => {
  const f = transportFixture()
  f.directories.clear()
  const id = '11111111-1111-1111-1111-111111111111'
  await f.provider().probe(id, noop)
  assert.deepEqual(f.trace.filter(row => row.method === 'MKCOL').map(row => row.address),
    [f.draft.directory + '/', f.root])
  assert.equal(f.files.has(f.root + 'probe-' + id + '.json'), false)
  assert.equal(f.trace.some(row => row.method === 'LOCK'), false)
})

test('parallel immutable publications retain both heads and merge their selected facts', async () => {
  const f = transportFixture()
  const left = f.provider(), right = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'false')
  const b = dataset('reader-settings', animation, B, 'false')
  for (const object of a.objects.concat(b.objects)) await left.storeObject(object, noop)
  let arrived = 0, release
  const gate = new Promise(resolve => { release = resolve })
  f.onCommit(async () => { if (++arrived === 2) release(); await gate })
  const sent = [0, 0]
  assert.deepEqual(await Promise.all([
    left.publish(manifest(left.spaceId(), [a.ref]), '', noop, () => sent[0]++),
    right.publish(manifest(right.spaceId(), [b.ref]), '', noop, () => sent[1]++),
  ]), [true, true])
  assert.deepEqual(sent, [1, 1])
  const merged = await f.provider().readManifest(noop)
  assert.equal(merged.frontier.length, 2)
  const fixture = engineFixture(f.DeviceSyncWebDav)
  const reader = fixture.replica(C)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(reader.values.get('reader-settings').get(animation), 'false')
})

test('merging one group preserves both opaque branches without reading disabled group objects', async () => {
  const f = transportFixture()
  const provider = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'false')
  const b = dataset('reader-settings', animation, B, 'false')
  for (const object of a.objects.concat(b.objects)) f.seedObject(object)
  const opaque = text => ({ id: 'future-group', schema: 9, shards: [{ bucket: '00', epoch: 1,
    hash: wire.syncDigest(text), bytes: Buffer.byteLength(text) }] })
  const oa = opaque('opaque-a'), ob = opaque('opaque-b')
  f.seedCommit(manifest(provider.spaceId(), [a.ref, oa]))
  f.seedCommit(manifest(provider.spaceId(), [b.ref, ob]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(C)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  const merged = await f.provider().readManifest(noop)
  assert.equal(merged.frontier.length, 1)
  assert.deepEqual(wire.syncDatasetBranches(merged.manifest, 'future-group')
    .map(ref => ref.shards[0].hash).sort(), [oa.shards[0].hash, ob.shards[0].hash].sort())
  for (const ref of [oa, ob]) assert.equal(f.trace.some(row => row.method === 'GET' &&
    row.address === f.root + wire.syncShardPath(ref.shards[0])), false)
})

test('a provider retains a newly seen head when the next listing omits it', async () => {
  const f = transportFixture(), provider = f.provider()
  const a = f.seedCommit(manifest(provider.spaceId(), []))
  const b = f.seedCommit(manifest(provider.spaceId(), [], 2))
  assert.deepEqual((await provider.readManifest(noop)).frontier, [a, b].sort())
  f.listing(names => names.filter(name => name !== b))
  assert.deepEqual((await provider.readManifest(noop)).frontier, [a, b].sort())
  assert.deepEqual((await f.provider([a, b]).readManifest(noop)).frontier, [a, b].sort(),
    'a reconstructed provider must also use the saved frontier as direct witnesses')
  f.files.delete(f.root + b)
  await assert.rejects(provider.readManifest(noop), /sync_space_changed/)
})

for (const fault of ['before-accept', 'lost-response']) {
  test('exact commit recovery after ' + fault + ' preserves the original edit dot', async () => {
    const f = transportFixture()
    const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
      [['reader-settings', new Map([[pageNumber, 'true']])]])
    await reader.engine.testConnection(f.draft)
    await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
    reader.values.get('reader-settings').set(pageNumber, 'false')
    f.faults.push(fault)
    await assert.rejects(reader.engine.syncNow(), /sync_remote_result_unknown/)
    const intent = clone(reader.store.load().intent)
    assert.equal(journal.syncCommitName(intent.commitBody), intent.commit)
    assert.equal(f.files.has(f.root + intent.commit), fault === 'lost-response')
    await reader.engine.syncNow()
    assert.equal(reader.store.load().intent, undefined)
    const current = await f.provider().readManifest(noop)
    const ref = wire.syncDatasetBranches(current.manifest, 'reader-settings')[0]
    const values = ref.shards.flatMap(shard => wire.decodeSyncShard('reader-settings', shard,
      f.files.get(f.root + wire.syncShardPath(shard)), data.syncBucketKey))
    const fact = values.find(value => value.key === pageNumber)
    assert.equal(fact.values[0].value, 'false')
    assert.deepEqual(fact.values[0].version, dot(A, 2))
    assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address === f.root + intent.commit).length,
      fault === 'lost-response' ? 1 : 2)
  })
}

test('a disconnected submitted intent is never retried into the old connection', async () => {
  const f = transportFixture()
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
    [['reader-settings', new Map([[pageNumber, 'true']])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  reader.values.get('reader-settings').set(pageNumber, 'false')
  f.faults.push('before-accept')
  await assert.rejects(reader.engine.syncNow(), /sync_remote_result_unknown/)
  const name = reader.store.load().intent.commit
  await reader.engine.disconnect()
  await reader.engine.recoverOnForeground()
  assert.equal(f.files.has(f.root + name), false)
  assert.equal(reader.engine.active(), undefined)
  assert.equal(reader.store.load().intent.detached, true)
})

test('disconnect during an accepted request prevents its late callback from applying local data', async () => {
  const f = transportFixture()
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
    [['reader-settings', new Map([[pageNumber, 'true']])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  reader.values.get('reader-settings').set(pageNumber, 'false')
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const resumed = new Promise(resolve => { release = resolve })
  f.onCommit(async () => { enter(); await resumed })
  const pending = reader.engine.syncNow()
  const rejected = assert.rejects(pending, /sync_connection_changed/)
  await entered
  const name = reader.store.load().intent.commit
  await reader.engine.disconnect()
  release()
  await rejected
  assert.equal(f.files.has(f.root + name), true, 'the in-flight request may already commit')
  assert.equal(reader.engine.active(), undefined)
  assert.equal(reader.store.load().intent.detached, true)
  const writes = f.trace.filter(row => row.method === 'PUT').length
  await reader.engine.recoverOnForeground()
  assert.equal(f.trace.filter(row => row.method === 'PUT').length, writes)
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'false')
})

test('v1 migration copies old objects and legacy probe cleanup touches only its exact v1 path', async () => {
  const f = transportFixture(), provider = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of a.objects) f.seedObject(object, f.legacy)
  const old = { ...manifest(A, [a.ref]), schema: 1, minWriter: 1 }
  f.files.set(f.legacy + 'manifest.json', JSON.stringify(old))
  const before = await provider.readManifest(noop)
  assert.ok(before.legacyHash)
  const next = { ...before.manifest, revision: 2 }
  assert.equal(await provider.publish(next, before.etag, noop), true)
  for (const object of a.objects) assert.equal(f.files.get(f.root + wire.syncShardPath(object.ref)), object.body)
  for (const name of [...f.files.keys()]) if (name.startsWith(f.legacy)) f.files.delete(name)
  const current = await f.provider().readManifest(noop)
  assert.equal(await f.provider().readObject(current.manifest.datasets[0].shards[0], noop), a.objects[0].body)
  const id = '11111111-1111-1111-1111-111111111111'
  f.files.set(f.legacy + 'probe-' + id + '.json', 'old-probe')
  f.files.set(f.root + 'probe-' + id + '.json', 'new-probe')
  await provider.cleanProbe(id, noop, true)
  assert.equal(f.files.has(f.legacy + 'probe-' + id + '.json'), false)
  assert.equal(f.files.get(f.root + 'probe-' + id + '.json'), 'new-probe')
})

test('combining individually valid opaque snapshots never publishes an invalid aggregate commit', async () => {
  const f = transportFixture(), provider = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'false')
  const b = dataset('reader-settings', animation, B, 'false')
  for (const object of a.objects.concat(b.objects)) f.seedObject(object)
  for (const [prefix, selected] of [['left', a], ['right', b]]) {
    const refs = Array.from({ length: 127 }, (_, index) => ({ id: prefix + '-' + index,
      schema: 9, shards: [] }))
    const head = manifest(provider.spaceId(), [selected.ref].concat(refs))
    const name = f.seedCommit(head)
    assert.doesNotThrow(() => journal.decodeSyncCommit(name, f.files.get(f.root + name)))
  }
  const reader = engineFixture(f.DeviceSyncWebDav).replica(C)
  await reader.engine.testConnection(f.draft)
  const preview = await reader.engine.prepare(f.draft, ['reader-settings'])
  await assert.rejects(reader.engine.confirm(preview.token, []), /sync_(invalid_datasets|round_too_large|manifest_too_large)/)
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))),
    false, 'invalid aggregate metadata must be rejected before its immutable name becomes discoverable')
})

test('migration preserves protected v1 maintenance objects without advancing or finishing old maintenance', async () => {
  const f = transportFixture(), provider = f.provider()
  const current = dataset('reader-settings', pageNumber, A, 'false')
  const previous = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of current.objects.concat(previous.objects)) f.seedObject(object, f.legacy)
  const old = { ...manifest(A, [current.ref], 2), schema: 1, minWriter: 1, epoch: 2,
    maintenance: true, previous: [previous.ref] }
  const original = JSON.stringify(old)
  f.files.set(f.legacy + 'manifest.json', original)
  const remote = await provider.readManifest(noop)
  assert.equal(remote.manifest.maintenance, false)
  assert.equal(await provider.publish({ ...remote.manifest, revision: 3 }, remote.etag, noop), true)
  assert.equal(f.files.get(f.legacy + 'manifest.json'), original)
  assert.equal(f.trace.some(row => row.address.startsWith(f.legacy) &&
    (row.method === 'PUT' || row.method === 'DELETE' || row.method === 'MKCOL')), false)
  for (const object of current.objects.concat(previous.objects)) {
    assert.equal(f.files.get(f.root + wire.syncShardPath(object.ref)), object.body)
  }
})

test('retrying a missing commit preserves opaque references without downloading disabled group data', async () => {
  const f = transportFixture(), provider = f.provider()
  const selected = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of selected.objects) f.seedObject(object)
  const body = 'opaque-disabled-group'
  const opaque = { id: 'future-group', schema: 9, shards: [{ bucket: '00', epoch: 1,
    hash: wire.syncDigest(body), bytes: Buffer.byteLength(body) }] }
  const opaqueAddress = f.root + wire.syncShardPath(opaque.shards[0])
  f.files.set(opaqueAddress, body)
  f.seedCommit(manifest(provider.spaceId(), [selected.ref, opaque]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(B)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  reader.values.get('reader-settings').set(pageNumber, 'false')
  f.faults.push('before-accept')
  await assert.rejects(reader.engine.syncNow(), /sync_remote_result_unknown/)
  await reader.engine.syncNow()
  assert.equal(f.trace.some(row => row.method === 'GET' && row.address === opaqueAddress), false,
    'recovery must retain the ordinary unselected-group transfer boundary')
})

test('an approved download-only first merge resumes its local apply without another confirmation', async () => {
  const f = transportFixture(), provider = f.provider()
  const remote = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of remote.objects) f.seedObject(object)
  f.seedCommit(manifest(provider.spaceId(), [remote.ref]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(B)
  await reader.engine.testConnection(f.draft)
  const preview = await reader.engine.prepare(f.draft, ['reader-settings'])
  const owner = reader.engine.owner
  const commit = owner.commit.bind(owner)
  let fail = true
  owner.commit = async (...args) => {
    if (fail) { fail = false; throw new Error('synthetic_owner_boundary') }
    return commit(...args)
  }
  await assert.rejects(reader.engine.confirm(preview.token, []), /synthetic_owner_boundary/)
  assert.equal(reader.engine.active(), undefined)
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))), false)
  await reader.engine.recoverOnForeground()
  assert.ok(reader.engine.active(), 'the previously approved local plan must survive the owner interruption')
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'true')
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))), false)
})
