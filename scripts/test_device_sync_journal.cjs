const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')

// Reuse the existing ArkTS loader; execute production Journal, Engine and HTTP adapter.
// Only NetworkKit, native credentials and owner persistence are host substitutes.
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { ts, compile, wire, facts, data, journal, metrics, planner, engineFixture, runtimeFixture, A, B, C, dot, edit };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { ts, compile, wire, facts, data, journal, metrics, planner, engineFixture, runtimeFixture, A, B, C, dot, edit } = support
const models = compile('../remote/WebDavModels')
const xml = compile('../remote/WebDavClient', { './WebDavModels': models })

test('a staged sync state cannot overwrite a newer local write or publish after cancellation', async () => {
  const path = '/test/device-sync-state.v1.json'
  const files = new Map()
  let staged
  let resume
  let blocked = false
  const fileIo = {
    accessSync: file => files.has(file),
    readTextSync: file => files.get(file),
    renameSync: (from, to) => {
      assert.ok(files.has(from))
      files.set(to, files.get(from))
      files.delete(from)
    },
    unlink: async file => files.delete(file),
  }
  const { DeviceSyncStorage } = compile('DeviceSyncStorage', {
    '@kit.CoreFileKit': { fileIo }, '@kit.AssetStoreKit': {},
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: {
      async execute(worker, ...args) {
        const result = worker(...args)
        if (blocked) {
          blocked = false
          await new Promise(resolve => { resume = resolve; staged() })
        }
        return result
      },
    } },
    '../model/AppFileTextPersistence': { writeAppTextFile: (file, body) => files.set(file, body) },
    './DeviceSyncFacts': facts, './DeviceSyncWire': wire, './DeviceSyncWebDav': {},
  })
  const storage = new DeviceSyncStorage('/test')
  storage.update(state => {
    state.counter = 1
    const group = { id: 'reading',
      facts: Array.from({ length: 130 }, (_, i) => facts.emptySyncFact('测试,"[]' + i)),
      baseline: [{ key: 'baseline', value: '"\n' }], pending: [] }
    const connection = { credential: '', space: 'old', endpointIdentity: 'old', revision: 7, manifestHash: '',
      selected: ['reading'], automatic: true, reviewRequired: false, lastSuccess: 0, lastError: '', groups: [group] }
    state.archivedIntents = [{ connection, expected: '', sent: true, groupRevisions: [],
      applies: [{ group: 'reading', changes: group.baseline }], staged: [group] }]
  })
  const pauseNext = () => new Promise(resolve => { blocked = true; staged = resolve })
  const firstStage = pauseNext()
  const saving = storage.updateInBackground(state => { state.counter += 1; return true }, () => {})
  await firstStage
  storage.update(state => { state.counter = 5 })
  resume()
  await saving
  assert.equal(JSON.parse(files.get(path)).counter, 6)
  assert.equal(storage.load().counter, 6)
  assert.equal(files.get(path), JSON.stringify(storage.load()))

  let allowed = true
  const secondStage = pauseNext()
  const cancelled = storage.updateInBackground(state => { state.counter = 9; return true }, () => {
    if (!allowed) throw new Error('sync_connection_changed')
  })
  await secondStage
  allowed = false
  resume()
  await assert.rejects(cancelled, /sync_connection_changed/)
  assert.equal(JSON.parse(files.get(path)).counter, 6)
  assert.deepEqual([...files.keys()], [path])

  storage.update(state => { state.archivePending = [{ endpointIdentity: 'endpoint', space: A,
    path: 'attempt', startedAt: 1, checks: 1, awaitingListing: true }] })
  const original = storage.load()
  const thirdStage = pauseNext()
  const updating = storage.updateInBackground(state => {
    state.archivePending[0].checks = 2
    state.archivePending[0].awaitingListing = false
    return true
  }, () => { if (storage.load() !== original) throw new Error('sync_local_changed') })
  await thirdStage
  assert.equal(original.archivePending[0].checks, 1)
  assert.equal(original.archivePending[0].awaitingListing, true)
  storage.update(state => { state.counter = 7 })
  resume()
  await assert.rejects(updating, /sync_local_changed/)
  assert.equal(storage.load().archivePending[0].checks, 1)
  assert.equal(JSON.parse(files.get(path)).archivePending[0].awaitingListing, true)

  const receipt = await storage.prepareReceipt(state => { state.localReceipt = 'prepared' }, () => {})
  assert.equal(storage.load().localReceipt, undefined)
  assert.equal(JSON.parse(files.get(path)).localReceipt, undefined)
  assert.equal(JSON.parse(files.get(path + '.receipt')).localReceipt, 'prepared')
  storage.update(state => { state.counter = 8 })
  assert.throws(() => receipt.publish(), /sync_local_changed/)
  await receipt.dispose()
  assert.deepEqual([...files.keys()], [path])
  const retry = await storage.prepareReceipt(state => { state.localReceipt = 'committed' }, () => {})
  retry.publish()
  await retry.dispose()
  assert.equal(storage.load().counter, 8)
  assert.equal(JSON.parse(files.get(path)).localReceipt, 'committed')
  assert.deepEqual([...files.keys()], [path])

  let resumePreparation
  let markPreparing
  const preparing = new Promise(resolve => { markPreparing = resolve })
  const afterPreparation = storage.updateInBackground(async state => {
    if (state.counter === 8) await new Promise(resolve => { resumePreparation = resolve; markPreparing() })
    state.counter++
    return true
  }, () => {})
  await preparing
  storage.update(state => { state.counter = 10 })
  resumePreparation()
  await afterPreparation
  assert.equal(JSON.parse(files.get(path)).counter, 11)
  assert.equal(files.get(path), JSON.stringify(storage.load()))
})

test('reading receipt stages only its changes and rebases after a concurrent durable write', async () => {
  const files = new Map()
  const file = '/reading-delta/device-sync-state.v1.json'
  const fileIo = { accessSync: name => files.has(name), readTextSync: name => files.get(name),
    renameSync: (from, to) => { assert.ok(files.has(from)); files.set(to, files.get(from)); files.delete(from) },
    unlink: async name => files.delete(name) }
  let pause, entered, transfers = []
  const stageStarted = new Promise(resolve => { entered = resolve })
  const { DeviceSyncStorage } = compile('DeviceSyncStorage', {
    '@kit.CoreFileKit': { fileIo }, '@kit.AssetStoreKit': {},
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: { async execute(worker, ...args) {
      const payload = args.at(-1)
      transfers.push(payload)
      const result = worker(...structuredClone(args))
      if (transfers.length === 1) await new Promise(resolve => { pause = resolve; entered() })
      return result
    } } },
    '../model/AppFileTextPersistence': { writeAppTextFile: (name, content) => files.set(name, content) },
    './DeviceSyncFacts': facts, './DeviceSyncWire': wire, './DeviceSyncWebDav': {},
  })
  const storage = new DeviceSyncStorage('/reading-delta')
  storage.update(state => {
    state.replica = A
    state.active = { credential: 'fixture', space: 'test', endpointIdentity: 'endpoint', revision: 0, manifestHash: '',
      selected: ['reading', 'shelf'], automatic: true, reviewRequired: false, lastSuccess: 0, lastError: '',
      groups: [{ id: 'reading', facts: [facts.emptySyncFact('page'), facts.emptySyncFact('other')],
        pending: [], baseline: [{ key: 'page', value: 'old' }] },
        { id: 'shelf', facts: [facts.emptySyncFact('shelf-book')], baseline: [], pending: [] }] }
  })
  const saving = storage.updateInBackground(state => {
    const reading = state.active.groups.find(row => row.id === 'reading')
    const version = dot(A, ++state.counter)
    const editPage = edit(reading.facts[0], version, 'delete', '')
    state.active.groups = state.active.groups.filter(row => row !== reading).concat({
      ...reading, facts: [editPage, reading.facts[1]], baseline: [], pending: [{ key: 'page', version }],
    })
    state.readingReceipts = [{ key: 'page', id: 'received', version }]
    return true
  }, () => {}, true)
  await stageStarted
  storage.update(state => { state.counter = 7; state.active.lastSuccess = 123 })
  pause()
  await saving
  assert.deepEqual(transfers.map(delta => delta.facts.map(row => row.key)), [['page'], ['page']])
  assert.deepEqual(JSON.parse(files.get(file)), JSON.parse(JSON.stringify(storage.load())))
  assert.equal(storage.load().active.lastSuccess, 123)
  assert.equal(storage.load().readingReceipts[0].version.sequence, 8)
})
const noop = () => {}
const clone = value => structuredClone(value)
const response = (status, body = '') => ({ responseCode: status,
  result: Uint8Array.from(Buffer.from(body)).buffer, header: {} })

function transportFixture(directoryUrl = 'https://local-fixture.invalid', uptime) {
  const draft = { directory: directoryUrl, username: '', password: '' }
  const directory = draft.directory + '/'
  const root = directory + 'koma-device-sync-v2/'
  const sharedRoot = directory + 'koma-device-sync-v5/'
  const writerRoot = directory + 'koma-device-sync-v3/'
  const writerRootV4 = directory + 'koma-device-sync-v4/'
  const legacy = directory + 'koma-device-sync-v1/'
  const files = new Map()
  const directories = new Set([directory, root])
  const trace = []
  const faults = []
  const archivePending = new Map()
  const pendingPort = {
    async loadPending() { return [...archivePending.values()].map(value => ({ ...value })) },
    async recordPending(value) { archivePending.set(value.path, { ...value }) },
    async forgetPending(path) { archivePending.delete(path) },
    async deferPending(path, startedAt, nextCheckAt, checks, awaitingListing) {
      const old = archivePending.get(path)
      if (old?.startedAt === startedAt) archivePending.set(path, { ...old, nextCheckAt, checks, awaitingListing })
    },
    async recordSeen() {},
  }
  let filterListing = names => names
  let rewriteListing = (_address, body) => body
  let beforeCommit = async () => {}
  let beforeRequest = async () => {}
  let onDestroy = () => {}
  let overrideStatus = () => undefined
  let afterTask = async () => {}
  const resource = (address, collection) => '<d:response><d:href>' + new URL(address).pathname +
    '</d:href><d:propstat><d:prop><d:resourcetype>' + (collection ? '<d:collection/>' : '') +
    '</d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
  const http = { HttpDataType: { ARRAY_BUFFER: 2 }, createHttp: () => {
    const listeners = new Map()
    const request = {
    on(name, listener) { listeners.set(name, listener) },
    off(name, listener) { if (listeners.get(name) === listener) listeners.delete(name) },
    async requestInStream(address, options) {
      const result = await this.request(address, options)
      listeners.get('headersReceive')?.(result.header)
      if (result.result.byteLength > 0) listeners.get('dataReceive')?.(result.result)
      listeners.get('dataEnd')?.()
      return result.responseCode
    },
    async request(address, options) {
      const method = options.customMethod
      trace.push({ method, address, body: options.extraData, headers: clone(options.header) })
      await beforeRequest(method, address)
      assert.equal(options.usingCache, false)
      assert.equal(options.maxRedirects, 0)
      const forced = overrideStatus(method, address)
      if (forced !== undefined) return typeof forced === 'number' ? response(forced) : forced
      if (method === 'PROPFIND') {
        if (!directories.has(address)) return response(404)
        const names = options.header.Depth === '0' ? [] : filterListing([...files.keys(), ...directories]
          .filter(name => name.startsWith(address) && name !== address &&
            !name.slice(address.length).replace(/\/$/, '').includes('/')).map(name => name.slice(address.length)))
        const body = rewriteListing(address, '<d:multistatus xmlns:d="DAV:">' + resource(address, true) +
          names.map(name => resource(address + name, directories.has(address + name))).join('') + '</d:multistatus>')
        if (Buffer.byteLength(body) > options.maxLimit) throw Object.assign(new Error('response too large'), { code: 2300023 })
        return response(207, body)
      }
      if (method === 'MKCOL') { directories.add(address); return response(201) }
      if (method === 'GET') return files.has(address) ? response(200, files.get(address)) : response(404)
      if (method === 'DELETE') {
        if (directories.has(address)) {
          for (const name of [...files.keys()]) if (name.startsWith(address)) files.delete(name)
          for (const name of [...directories]) if (name.startsWith(address)) directories.delete(name)
        } else files.delete(address)
        return response(204)
      }
      if (method === 'PUT') {
        const isCommit = journal.SYNC_COMMIT_NAME.test(address.slice(root.length)) ||
          ((address.startsWith(writerRoot) || address.startsWith(writerRootV4)) &&
            /\/[0-9]{16}-[0-9a-f]{64}(?:-[0-9a-f-]{36})?\.json$/.test(address))
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
    destroy() { onDestroy() },
    }
    return request
  } }
  const arkts = { taskpool: { execute: async (fn, ...args) => {
    const result = fn(...args)
    await afterTask()
    return result
  } },
    url: { URL: { parseURL: text => new URL(text) } }, util: {
      generateRandomUUID: randomUUID,
      Base64Helper: class { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64') } },
      TextDecoder: { create: (encoding = 'utf-8', options = { fatal: true }) => {
        const decoder = new TextDecoder(encoding, options)
        return { decodeToString: (bytes, opts) => decoder.decode(bytes, opts) }
      } },
    } }
  const stream = compile('DeviceSyncHttpStream', { '@kit.NetworkKit': { http }, '@kit.ArkTS': arkts })
  const packs = compile('DeviceSyncObjectPack', { '@kit.ArkTS': arkts,
    './DeviceSyncFacts': facts, './DeviceSyncWire': wire })
  const codec = compile('DeviceSyncLegacyArchiveCodec', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire })
  const legacyArchive = compile('DeviceSyncLegacyArchive', { '@kit.ArkTS': arkts, './DeviceSyncFacts': facts,
    './DeviceSyncWire': wire, './DeviceSyncLegacyArchiveCodec': codec })
  const legacyAdapter = compile('DeviceSyncLegacyArchiveAdapter', { '@kit.ArkTS': arkts, './DeviceSyncFacts': facts,
    './DeviceSyncLegacyArchive': legacyArchive, './DeviceSyncLegacyArchiveCodec': codec })
  const publicationCodec = compile('DeviceSyncPublicationPackCodec', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire })
  const publicationPack = compile('DeviceSyncPublicationPack', { '@kit.ArkTS': arkts, './DeviceSyncWire': wire,
    './DeviceSyncPublicationPackCodec': publicationCodec })
  const compaction = compile('DeviceSyncPackCompaction', { '@kit.ArkTS': arkts, './DeviceSyncWire': wire,
    './DeviceSyncFacts': facts, './DeviceSyncObjectPack': packs, './DeviceSyncPublicationPackCodec': publicationCodec })
  const genericCompaction = compile('DeviceSyncGenericPackCompaction', { '@kit.ArkTS': arkts, './DeviceSyncWire': wire,
    './DeviceSyncFacts': facts, './DeviceSyncObjectPack': packs, './DeviceSyncPublicationPackCodec': publicationCodec,
    './DeviceSyncPackCompaction': compaction })
  const { DeviceSyncWebDav, canonicalSyncDirectory } = compile('DeviceSyncWebDav', {
    './DeviceSyncWire': wire, './DeviceSyncJournal': journal, '../remote/WebDavClient': xml,
    './DeviceSyncData': data, './DeviceSyncFacts': facts,
    './DeviceSyncHttpStream': stream, './DeviceSyncObjectPack': packs,
    './DeviceSyncLegacyArchive': legacyArchive, './DeviceSyncLegacyArchiveAdapter': legacyAdapter,
    './DeviceSyncMetrics': uptime === undefined ? metrics : { ...metrics, syncMetricUptime: uptime },
    './DeviceSyncPublicationPack': publicationPack, './DeviceSyncPublicationPackCodec': publicationCodec,
    './DeviceSyncPackCompaction': compaction,
    './DeviceSyncGenericPackCompaction': genericCompaction,
    '@kit.NetworkKit': { http },
    '@kit.ArkTS': arkts,
  }, { setTimeout: (fn, ms) => setTimeout(fn, ms === 30000 ? 1 : ms) })
  function seedObject(object, base = root) { files.set(base + wire.syncShardPath(object.ref), object.body) }
  function seedCommit(manifest, parents = []) {
    const body = journal.syncCommitBody(manifest, parents)
    const name = journal.syncCommitName(body)
    files.set(root + name, body)
    return name
  }
  // Keep the older publication fixtures exercising their protocol. The
  // shared migration test below enters through the production transport.
  class LegacyWriterWebDav extends DeviceSyncWebDav {
    async readSyncState(guard, requiredTag = '') { return this.readManifest(guard, requiredTag) }
  }
  class V2WebDav extends LegacyWriterWebDav {
    constructor(draft, witnesses, space) { super(draft, witnesses, space) }
  }
  return { draft, root, sharedRoot, writerRoot, writerRootV4, legacy, files, directories, trace, faults, pendingPort,
    writerObject: (writer, ref) => {
      const prefix = writerRootV4 + writer + '/objects/' + wire.syncShardPath(ref).slice(0, -5)
      return [...files.keys()].find(name => name.startsWith(prefix + '-')) ?? prefix + '.json'
    },
    DeviceSyncWebDav: V2WebDav, WriterWebDav: LegacyWriterWebDav, SharedWebDav: DeviceSyncWebDav,
    canonicalSyncDirectory, seedObject, seedCommit,
    provider: witnesses => new DeviceSyncWebDav(draft, witnesses),
    listing: filter => { filterListing = filter }, listingBody: filter => { rewriteListing = filter },
    onTask: hook => { afterTask = hook },
    onCommit: hook => { beforeCommit = hook },
    onRequest: hook => { beforeRequest = hook }, onDestroy: hook => { onDestroy = hook },
    responseStatus: hook => { overrideStatus = hook } }
}

test('a percent-encoded dot in a user-selected WebDAV folder remains usable', () => {
  const { canonicalSyncDirectory } = transportFixture()
  assert.equal(canonicalSyncDirectory('http://example.test/books%2Earchive/'), 'http://example.test/books%2Earchive')
})

test('a sync directory listing larger than one shard can still discover writer data', async () => {
  const f = transportFixture()
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const value = dataset('reader-settings-records', pageNumber, A, 'true')
  for (const object of value.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [value.ref]), '', noop, noop, ['reader-settings-records'])
  for (let i = 0; i < 5000; i++) {
    f.files.set(f.writerRoot + 'object-1-' + i.toString(16).padStart(64, '0') + '.json', '{}')
  }
  const result = await new f.WriterWebDav(f.draft, [], undefined, B).readManifest(noop)
  assert.equal(result.manifest.datasets[0].id, 'reader-settings-records')
})

function dataset(group, key, replica, value) {
  return wire.buildSyncDataset(group,
    [edit(facts.emptySyncFact(key), dot(replica, 1), 'set', value)], 1, undefined, data.syncBucketKey)
}
function manifest(space, datasets, revision = 1) {
  return { ...wire.newSyncManifest(space), revision, datasets, previous: [] }
}
const pageNumber = data.syncKey(['global', 'page-number'])
const animation = data.syncKey(['global', 'animation'])

function multipleReaderShards() {
  const rows = Array.from({ length: 40 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    return edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const dataset = wire.buildSyncDataset('reader-settings-records', rows, 1, undefined, data.syncBucketKey)
  assert.ok(dataset.objects.length >= 8)
  return { rows, dataset, bodies: new Map(dataset.objects.map(object => [wire.syncShardPath(object.ref), object.body])) }
}

test('immutable shards load concurrently within a fixed bound and retain all facts', async () => {
  const { rows, dataset, bodies } = multipleReaderShards()
  const engine = engineFixture().replica(B).engine
  let active = 0, maximum = 0
  const provider = { cacheScope: () => 'scope', async prefetchPublicationObjects() { return new Map() }, async prefetchLegacyObjects() { return new Map() }, async readObject(ref, guard) {
    guard()
    active++
    maximum = Math.max(maximum, active)
    await new Promise(resolve => setTimeout(resolve, 5))
    active--
    guard()
    return bodies.get(wire.syncShardPath(ref))
  } }
  const loaded = await engine.loadDataset(provider, dataset.ref, noop, 'reader-settings')
  assert.ok(maximum > 1 && maximum <= 4)
  assert.deepEqual(loaded.map(row => row.key).sort(), rows.map(row => row.key).sort())
  assert.equal(active, 0)
})

test('a failed or cancelled shard waits for the active batch before returning', async () => {
  const { dataset, bodies } = multipleReaderShards()
  for (const cancel of [false, true]) {
    const engine = engineFixture().replica(B).engine
    let release, entered
    const resumed = new Promise(resolve => { release = resolve })
    const started = new Promise(resolve => { entered = resolve })
    let count = 0, active = 0, returned = false, allowed = true
    const guard = () => { if (!allowed) throw new Error('sync_connection_changed') }
    const provider = { cacheScope: () => 'scope', async prefetchPublicationObjects() { return new Map() }, async prefetchLegacyObjects() { return new Map() }, async readObject(ref, check) {
      check()
      const index = count++
      active++
      if (count === 4) entered()
      try {
        if (!cancel && index === 0) throw new Error('sync_shard_damaged')
        await resumed
        check()
        return bodies.get(wire.syncShardPath(ref))
      } finally { active-- }
    } }
    const operation = engine.loadDataset(provider, dataset.ref, guard, 'reader-settings')
      .finally(() => { returned = true })
    const rejected = assert.rejects(operation, cancel ? /sync_connection_changed/ : /sync_shard_damaged/)
    await started
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(returned, false)
    if (cancel) allowed = false
    release()
    await rejected
    assert.equal(active, 0)
    assert.equal(count, 4)
  }
})

test('duplicate facts across loaded shards remain an error', async () => {
  const { dataset, bodies } = multipleReaderShards()
  const ref = dataset.ref.shards[0]
  const first = JSON.parse(bodies.get(wire.syncShardPath(ref)))
  const key = first.facts[0].key
  const body = JSON.stringify({ dataset: first.dataset, schema: first.schema, facts: [first.facts[0]] })
  const overlap = { ...ref, bucket: ref.bucket + '-' + wire.syncDigest(key).charAt(0),
    hash: wire.syncDigest(body), bytes: Buffer.byteLength(body) }
  bodies.set(wire.syncShardPath(overlap), body)
  const duplicate = { ...dataset.ref, shards: dataset.ref.shards.concat(overlap) }
  wire.checkedSyncDatasets([duplicate], 1)
  const engine = engineFixture().replica(B).engine
  const provider = { cacheScope: () => 'scope', async prefetchPublicationObjects() { return new Map() }, async prefetchLegacyObjects() { return new Map() }, async readObject(item) { return bodies.get(wire.syncShardPath(item)) } }
  await assert.rejects(engine.loadDataset(provider, duplicate, noop, 'reader-settings'), /sync_duplicate_fact/)
})

test('a failed shard can be retried, then a repeat uses the verified cache', async () => {
  const { rows, dataset, bodies } = multipleReaderShards()
  const engine = engineFixture().replica(B).engine
  const failedPath = wire.syncShardPath(dataset.ref.shards[1])
  let fail = true, reads = 0, active = 0
  const provider = { cacheScope: () => 'scope', async prefetchPublicationObjects() { return new Map() }, async prefetchLegacyObjects() { return new Map() }, async readObject(ref) {
    reads++
    active++
    try {
      await new Promise(resolve => setTimeout(resolve, 1))
      if (fail && wire.syncShardPath(ref) === failedPath) throw new Error('sync_shard_damaged')
      return bodies.get(wire.syncShardPath(ref))
    } finally { active-- }
  } }
  await assert.rejects(engine.loadDataset(provider, dataset.ref, noop, 'reader-settings'), /sync_shard_damaged/)
  assert.equal(active, 0)
  fail = false
  const loaded = await engine.loadDataset(provider, dataset.ref, noop, 'reader-settings')
  assert.deepEqual(loaded.map(row => row.key).sort(), rows.map(row => row.key).sort())
  const afterRecovery = reads
  const repeated = await engine.loadDataset(provider, dataset.ref, noop, 'reader-settings')
  assert.deepEqual(repeated, loaded)
  assert.equal(reads, afterRecovery)
})

test('a v4 receipt advances only its writer while retaining old and other writer witnesses', () => {
  const engine = engineFixture().replica(A).engine
  const one = `${A}/00000000000000/0000000000000001-${'1'.repeat(64)}.json`
  const other = `v4/${B}/00000000000000/0000000000000001-${'2'.repeat(64)}.json`
  const before = `v4/${A}/00000000000000/0000000000000001-${'3'.repeat(64)}.json`
  const after = `v4/${A}/00000000000000/0000000000000002-${'4'.repeat(64)}.json`
  assert.deepEqual(engine.receiptFrontier([one, other, before], { writer: true, frontier: [after] }),
    [one, other, after].sort())
})

async function readingDevice(fixture, id, installed, withShelf = false, afterReaderStage = async () => {}, database) {
  const filesDir = '/' + id
  const files = new Map()
  const rdb = require('./user_data_rdb_fixture.cjs').createRdbPort()
  test.after(() => rdb.close())
  const rdbModules = new Map()
  function dbLoad(name) {
    if (rdbModules.has(name)) return rdbModules.get(name)
    const exports = {}; rdbModules.set(name, exports)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', name + '.ets'), 'utf8')
    const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
    new Function('require', 'exports', js)(key => {
      if (key === '@kit.ArkData') return { relationalStore: rdb.relationalStore }
      if (key.startsWith('@kit.')) return {}
      if (key === '../deviceSync/DeviceSyncData') return data
      if (key.startsWith('.')) return dbLoad(path.posix.normalize(path.posix.join(path.posix.dirname(name), key)))
      throw Error('Unexpected database import ' + key)
    }, exports)
    return exports
  }
  const databaseApi = dbLoad('model/UserDataDatabase')
  const readerDatabase = dbLoad('model/ReaderRdbStorage')
  const shelfDatabase = dbLoad('model/LibraryRdbStorage')
  const fileIo = { OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
    openSync: fd => (files.set(fd, ''), { fd }), writeSync: (fd, body) => files.set(fd, body),
    fsyncSync: noop, closeSync: noop, renameSync: (from, to) => {
      assert.ok(files.has(from))
      files.set(to, files.get(from))
      files.delete(from)
    }, access: async file => files.has(file), readText: async file => files.get(file),
    accessSync: file => files.has(file), readTextSync: file => files.get(file),
    unlinkSync: file => files.delete(file) }
  let beforeWrite = noop
  const writeAppTextFile = (file, content) => {
    beforeWrite(file, content)
    files.set(file, content)
  }
  const nativeFs = { fileIo }
  const signals = compile('DeviceSyncSignals')
  const backup = compile('../model/BackupRestoreActivity')
  const comics = compile('../model/ComicModels')
  const registry = { getInstalledSourcePackage: source => installed.get(source) }
  const sessions = compile('../model/ReaderSessionStore', {
    '@kit.CoreFileKit': nativeFs,
    '@kit.ArkTS': { taskpool: { execute: async (worker, ...args) => {
      const staged = worker(...structuredClone(args))
      await afterReaderStage()
      return staged
    } } },
    './AppFileTextPersistence': { writeAppTextFile },
    './BackupRestoreActivity': backup, '../deviceSync/DeviceSyncSignals': signals, './ComicModels': comics,
    './SourceTextOverlay': {}, './SourceRequiredImageDecode': {}, './SourceTextPageDescriptor': {},
    '../sourceRuntime/SourceRuntimeAppRegistry': registry, '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn: noop, info: noop, exception: noop } },
    './ReaderChapterSequence': {}, '../i18n/AppStrings': {}, './RemoteReaderSession': {}, './ChapterReadStateStore': {},
    './ChapterListPreferencesStore': { chapterReadingSortFor: () => undefined },
    './ReaderRdbStorage': readerDatabase, './UserDataDatabase': databaseApi,
  })
  files.set(filesDir + '/' + sessions.READER_PROGRESS_PERSISTENCE_FILE_NAME, JSON.stringify({ schemaVersion: 4,
    progress: [], sourceHistory: [], chapters: [],
  }))
  const strings = { AppStrings: { get: key => key } }
  const sourceComic = compile('../model/SourceLibraryComic', { './ComicModels': comics, '../i18n/AppStrings': strings })
  const smart = compile('../model/LibrarySmartCategory', { './ComicModels': comics, '../i18n/AppStrings': strings })
  const stores = compile('../model/LibraryStore', { './ComicModels': comics, './ReaderSessionStore': sessions,
    './LibrarySmartCategory': smart, '../i18n/AppStrings': strings, '@kit.ArkTS': { util: { generateRandomUUID: randomUUID } } })
  const persistence = compile('../model/LibraryPersistence', {
    './ComicModels': comics, './LibraryStore': stores, './LibrarySmartCategory': smart, '@kit.CoreFileKit': nativeFs,
    './AppFileTextPersistence': { writeAppTextFile }, '../deviceSync/DeviceSyncSignals': signals,
    '../deviceSync/DeviceSyncData': data, '../deviceSync/DeviceSyncFacts': facts,
    './BackupRestoreActivity': backup, '../i18n/AppStrings': strings, './SourceTextOverlay': {},
    './SourceRequiredImageDecode': {}, './SourceChapterMetadata': {}, './SourceLibraryComic': sourceComic,
    './SourceTextPageDescriptor': {},
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { debug: noop, info: noop, exception: noop } },
    './LocalLibraryMetadataService': {}, './LocalLibraryFolderContract': {},
    './LocalLibraryRescanService': {}, './LibraryRdbStorage': shelfDatabase, './UserDataDatabase': databaseApi,
  })
  const stageSnapshot = sessions.AppFilesReaderSessionPersistenceAdapter.prototype.saveSnapshotAsync
  sessions.AppFilesReaderSessionPersistenceAdapter.prototype.saveSnapshotAsync = async function (...args) {
    const token = await stageSnapshot.apply(this, args)
    await afterReaderStage()
    return token
  }
  const context = { filesDir }
  await persistence.prepareLiveLibraryStorage(context, true)
  await sessions.prepareLiveReaderStorage(context, true)
  const backupExport = compile('../model/BusinessBackupExport', { './LibraryPersistence': persistence, './ReaderSessionStore': sessions })
  const shelfApply = compile('DeviceSyncShelfApply', {
    '@kit.PerformanceAnalysisKit': { hiTraceMeter: { traceByValue() {} } },
    '../model/LibraryPersistence': persistence, '../model/ComicModels': comics, '../model/SourceLibraryComic': sourceComic,
    './DeviceSyncFacts': facts, './DeviceSyncData': data, './DeviceSyncWire': wire,
  })
  const readingSnapshot = compile('DeviceSyncReadingSnapshot', {
    '../model/LibraryPersistence': persistence, '../model/ReaderSessionStore': sessions,
    '../model/SourceLibraryComic': sourceComic, './DeviceSyncData': data, './DeviceSyncShelfApply': shelfApply,
    './DeviceSyncWire': wire, './DeviceSyncStorage': { DATABASE_READING_REVISION_PREFIX: 'reading-rdb:' },
  })
  const forbiddenSnapshot = () => { throw new Error('unexpected_full_snapshot') }
  const { KomaDeviceSyncOwners } = compile('DeviceSyncOwners', {
    '@kit.PerformanceAnalysisKit': { hiTraceMeter: { traceByValue() {} } },
    '@kit.CoreFileKit': nativeFs, '@kit.ArkTS': {
      util: { generateRandomUUID: randomUUID },
      taskpool: { execute: async (fn, ...args) => fn(...args) },
    },
    '../model/AppFileTextPersistence': { writeAppTextFile }, '../model/BackupRestoreActivity': backup,
    '../model/LibraryPersistence': database === undefined ? persistence : { ...persistence,
      usesLibraryDatabase: () => true, readLibraryBackupDocument: forbiddenSnapshot, liveReadingMetadata: () => database.works,
      liveLibraryWriteRevision: database.shelfRevision, writeLiveLibrarySyncEdits: database.writeShelfEdits,
    },
    '../model/UserDataSnapshot': { readShelfSyncDatabaseInput: async () => {
        if (database?.readShelfSnapshot) {
          const raw = await database.readShelfSnapshot(context, 'shelf-sync')
          const library = raw === undefined ? undefined : JSON.parse(raw)
          return { library, revision: shelfApply.shelfRowsRevision(library) }
        }
        const library = persistence.readLiveShelfSync(filesDir)
        return { library, revision: shelfApply.shelfRowsRevision(library) }
      },
      readShelfWorksForRecovery: database?.readShelfWorksForRecovery ?? (async (_context, ids) => {
        const storage = new shelfDatabase.LibraryRdbStorage(await databaseApi.openUserDataDatabase(context))
        return ids.map(id => storage.readWork(id))
      }),
      readReadingSyncDatabaseInput: async () => database?.works ? structuredClone({ works: database.works, reading: database.reading })
        : { works: persistence.liveReadingMetadata(filesDir), reading: new readerDatabase.ReaderRdbStorage(await databaseApi.openUserDataDatabase(context)).readForSync() },
    },
    '../model/ReaderSessionStore': database?.readEdits === undefined ? sessions : { ...sessions,
      usesReaderDatabase: () => true, readReaderBackupDocument: forbiddenSnapshot,
      readLiveReadingEdits: database.readEdits, writeLiveReadingEdits: database.writeEdits,
    },
    '../model/ReaderPreferencesStore': {}, '../model/ComicModels': comics,
    '../model/SearchHistoryStore': {}, '../model/SourceLibraryComic': sourceComic,
    '../sourceRuntime/SourceIndexService': {}, '../sourceRuntime/SourceIndexMetadata': {},
    './DeviceSyncFacts': facts, './DeviceSyncData': data, './DeviceSyncSignals': signals, './DeviceSyncWire': wire,
    './DeviceSyncShelfApply': shelfApply, './DeviceSyncReadingSnapshot': readingSnapshot, './DeviceSyncPlanner': planner,
    './DeviceSyncStorage': { DATABASE_READING_REVISION_PREFIX: 'reading-rdb:' },
  })
  let owner
  const replica = fixture.replica(id, [], store => { owner = new KomaDeviceSyncOwners(context, store); return owner })
  const runtime = runtimeFixture({ './DeviceSyncSignals': signals, '../model/ReaderSessionStore': sessions,
    '../sourceRuntime/SourceRuntimeAppRegistry': registry, '@kit.ArkTS': { util: { generateRandomUUID: randomUUID } } })
  Object.assign(runtime, { context, owners: owner, engine: replica.engine, storage: replica.store })
  signals.connectDeviceSyncReadingCapture(rows => runtime.stagePositions(rows), capture => owner.readingAcknowledged(capture),
    rows => runtime.stageReaderActions(rows), capture => owner.readingActionAcknowledged(capture))
  const reader = sessions.appReaderSessionStore(filesDir)
  const coldReader = () => new sessions.PersistentReaderSessionStore(new sessions.AppFilesReaderSessionPersistenceAdapter(filesDir))
  const coldShelf = () => {
    const shelf = new stores.InMemoryLibraryStore()
    const service = new persistence.LibraryStorePersistenceService(shelf, new persistence.AppFilesLibraryStorePersistenceAdapter(filesDir))
    service.restore()
    return { shelf, service }
  }
  if (withShelf) {
    signals.connectDeviceSyncOwnerEdits(actions => runtime.recordLibrary(actions), noop, noop,
      () => replica.engine.groupScope('shelf') ? replica.engine.active()?.space : undefined)
  }
  return { ...replica, runtime, reader, coldReader, coldShelf, persistence, backupExport, backupExportReader: () => sessions.readReaderBackupDocument(filesDir), owner, files, filesDir, rdb,
    onWrite: handler => { beforeWrite = handler } }
}

test('automatic RDB reading projects and receives exact pages without a full shelf or reader snapshot', async () => {
  const source = 'com.example.reader'
  const work = 'book'
  const comicId = source + ':' + work
  const saved = { comicId, chapterId: '66', pageIndex: 4, totalPages: 16,
    progressRatio: 0.25, completed: false, updatedAt: 100 }
  const facts = [{ key: data.syncKey(['position', source, work, '67']), value: JSON.stringify({ page: 6, total: 16, date: 200 }) },
    { key: data.syncKey(['recent', source, work]), value: JSON.stringify({
      chapter: '67', title: 'Test manga', sourceName: 'Test source', chapterTitle: '第67章', date: 200, savedPage: 6,
    }) }]
  let persisted = { progress: [saved], chapters: [], sourceHistory: [], syncPositions: [], syncActions: [] }
  const database = {
    works: [{ comicId, source, work, title: 'Test manga', chapterId: '66', chapterTitle: '第66章' }],
    reading: persisted,
    readEdits: (_directory, scope) => {
      assert.deepEqual(scope, [{ comicId, chapterIds: ['67'] }])
      return structuredClone(persisted)
    },
    writeEdits: (_directory, _scope, next) => { persisted = structuredClone(next) },
  }
  const { owner, reader } = await readingDevice(engineFixture(), A, new Map(), false, async () => {}, database)
  const snapshot = await owner.snapshot('reading', false, undefined, undefined, false)
  const recent = JSON.parse(snapshot.values.find(row => row.key === facts[1].key).value)
  assert.equal(recent.chapter, '66')
  assert.equal(recent.chapterTitle, '第66章')
  assert.equal(recent.savedPage, 4)
  const commit = publish => owner.commit([{ group: 'reading', changes: facts }],
    [{ group: 'reading', revision: snapshot.revision }], async () => ({ check: noop, publish, dispose: async () => {} }))
  await assert.rejects(commit(() => { throw new Error('receipt_interrupted') }), /receipt_interrupted/)
  assert.equal(persisted.progress[0].chapterId, '66')
  await commit(noop)
  assert.equal(persisted.progress[0].chapterId, '67')
  assert.equal(persisted.progress[0].pageIndex, 6)
  assert.equal(reader.getProgress(comicId).chapterId, '67')
  assert.equal(reader.getSourceHistory(comicId).chapterTitle, '第67章')
})

test('background page turns retain chapter order and cannot replace a newer durable edit', async () => {
  let stage = async () => {}
  const device = await readingDevice(engineFixture(), A, new Map(), false, () => stage())
  const { reader, coldReader } = device
  const comicId = 'book'
  function turn(chapterId, pageIndex) {
    reader.saveProgress({ comicId, chapterId, pageIndex, totalPages: 20,
      updatedAt: 0, progressRatio: (pageIndex + 1) / 20, completed: false })
  }
  reader.addReadingSession({ comicId, chapterId: 'earlier', startedAt: 1, endedAt: 2, pagesRead: 1 })
  assert.equal(reader.flush(), true)
  turn('earlier', 3)
  turn('later', 5)
  turn('earlier', 6)
  assert.equal(await reader.flushAsync(), true)
  const saved = coldReader()
  assert.equal(saved.getProgress(comicId).pageIndex, 6)
  assert.equal(saved.getProgress(comicId).chapterId, 'earlier')
  assert.equal(saved.getChapterProgress(comicId, 'later').pageIndex, 5)
  assert.equal(saved.listReadingSessions()[0].pagesRead, 1)

  let release, staged
  const readerStaged = new Promise(resolve => { staged = resolve })
  stage = () => new Promise(resolve => { release = resolve; staged() })
  turn('later', 7)
  const saving = reader.flushAsync()
  await readerStaged
  assert.equal(reader.removeHistoryEntries([comicId]), true)
  release()
  assert.equal(await saving, true)
  const removed = coldReader()
  assert.equal(removed.getProgress(comicId), undefined)
  assert.equal(removed.getChapterProgress(comicId, 'later').pageIndex, 7)
  assert.equal(removed.listReadingSessions().length, 0)
})

function shelfComic(source, work, categoryIds = [], url = 'https://works.example.test/title/12') {
  return { id: source + ':' + work, sourceRuntimeId: source, remoteResourceId: work, title: 'Series ' + work,
    sourceKind: 'private_library', sourcePath: url, sortTitle: work, preferredDirection: 'right_to_left',
    categoryIds, sourceMetadata: { sourceName: 'Source ' + source }, chapters: [], chapterCount: 0, pageCount: 0,
    createdAt: 1, updatedAt: 1, lastImportedAt: 1 }
}

test('automatic first merge persists a shared chapter directory and unread count with no source installed', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const source = 'org.example.login', work = 'account-book:series'
  const comic = shelfComic(source, work)
  comic.coverUri = comic.customCoverUri = 'file:///local/custom-cover.png'
  comic.sourceCoverUri = 'https://images.example.test/covers/series.jpg'
  comic.enhancedCoverUri = 'file:///local/enhanced-cover.png'
  comic.enhancedCoverModel = 'system'
  const ids = Array.from({ length: 440 }, (_, index) => 'stable-chapter-id:' + index)
  comic.sourceMetadata = { ...comic.sourceMetadata, sharedChapterIds: ids, chapterCatalogUpdatedAt: 123 }
  comic.chapterCount = ids.length
  const local = a.coldShelf()
  a.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, comic)
  a.reader.markChapterReadStates([{ comicId: comic.id, chapterId: ids[0], isRead: true }],
    { sourceId: source, mangaId: work })
  assert.equal(a.reader.flush(), true)
  for (const device of [a, b]) {
    device.engine.setSelection(['shelf', 'reading'])
    await device.engine.saveConfiguration(transport.draft)
    device.engine.setEnabled(true)
    if (device === b) {
      const prepareReceipt = b.store.prepareReceipt.bind(b.store)
      b.store.prepareReceipt = async (...args) => {
        const receipt = await prepareReceipt(...args)
        assert.equal(b.coldShelf().shelf.getComic(comic.id), undefined)
        return { ...receipt, publish() {
          assert.ok(b.coldShelf().shelf.getComic(comic.id))
          throw new Error('synthetic_receipt_rename_failure')
        } }
      }
      await assert.rejects(b.engine.syncNow(), /synthetic_receipt_rename_failure/)
      assert.equal(b.store.load().localReceipt, undefined)
      assert.equal(b.coldShelf().shelf.getComic(comic.id), undefined)
      b.store.prepareReceipt = prepareReceipt
    }
    await device.engine.syncNow()
    assert.equal(device.engine.active().reviewRequired, false)
  }
  const received = b.coldShelf().shelf.getComic(comic.id)
  assert.equal(received.coverUri, comic.sourceCoverUri)
  assert.equal(received.customCoverUri, undefined)
  assert.equal(received.enhancedCoverUri, undefined)
  assert.equal(received.enhancedCoverModel, undefined)
  assert.equal(received.chapterCount, ids.length)
  assert.deepEqual(received.sourceMetadata.sharedChapterIds, ids)
  assert.equal(b.coldReader().unreadChapterCount(received), ids.length - 1)
  assert.equal(b.coldReader().comicReadingState(received), 'reading')
})

test('revoking a scope during the first network request neither applies it nor restores the old selection', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const a = fixture.replica(A, [['reader-settings', new Map([[pageNumber, 'false']])]])
  const b = fixture.replica(B, [['reader-settings', new Map([[pageNumber, 'true']])]])
  b.snapshotExtras.set('reader-settings', { defaultKeys: [pageNumber] })
  a.engine.setSelection(['shelf', 'reader-settings'])
  await a.engine.saveConfiguration(f.draft)
  a.engine.setEnabled(true)
  await a.engine.syncNow()
  b.engine.setSelection(['shelf', 'reader-settings'])
  await b.engine.saveConfiguration(f.draft)
  b.engine.setEnabled(true)
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const resumed = new Promise(resolve => { release = resolve })
  f.onRequest(async (method, address) => {
    if (method === 'PROPFIND' && address === f.root) { enter(); await resumed }
  })
  const rejected = assert.rejects(b.engine.syncNow(), /connection_changed/)
  await entered
  b.engine.setSelection(['shelf'])
  release()
  await rejected
  f.onRequest(async () => {})
  await b.engine.syncNow()
  assert.deepEqual(b.engine.active().selected, ['shelf'])
  assert.equal(b.values.get('reader-settings').get(pageNumber), 'true')
  b.engine.setSelection(['shelf', 'reader-settings'])
  await b.engine.syncNow()
  assert.equal(b.values.get('reader-settings').get(pageNumber), 'false')
  b.values.get('reader-settings').set(pageNumber, 'true')
  await b.engine.syncNow()
  await a.engine.syncNow()
  assert.equal(a.values.get('reader-settings').get(pageNumber), 'true')
})

test('a missing settings shard keeps that group pending while the received bookshelf lands', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const book = data.syncKey(['book', 'org.example.other', 'book:12'])
  const label = JSON.stringify({ title: 'Book 12', sourceName: 'Source' })
  const a = fixture.replica(A, [['shelf', new Map([[book, label]])],
    ['reader-settings', new Map([[pageNumber, 'false']])]])
  const b = fixture.replica(B, [])
  const groups = ['shelf', 'reader-settings']
  a.engine.setSelection(groups)
  await a.engine.saveConfiguration(f.draft)
  a.engine.setEnabled(true)
  await a.engine.syncNow()
  const published = [...f.files.entries()].find(([address]) => address.startsWith(f.writerRootV4) &&
    /\/[0-9]{16}-[0-9a-f]{64}(?:-[0-9a-f-]{36})?\.json$/.test(address))
  const settings = JSON.parse(published[1]).manifest.datasets.find(row => row.id === 'reader-settings-records')
  const path = f.writerObject(A, settings.shards[0])
  const body = f.files.get(path)
  assert.ok(f.files.delete(path))
  b.engine.setSelection(groups)
  await b.engine.saveConfiguration(f.draft)
  b.engine.setEnabled(true)
  const runtime = runtimeFixture({
    './DeviceSyncEngine': { SyncGroupError: fixture.SyncGroupError, syncRequiresExplicitReview: () => false },
  })
  runtime.engine = b.engine
  // A published shard may have moved to a temporarily invisible pack; keep
  // it pending while independent shelf data still lands.
  await assert.rejects(runtime.syncManually(), { message: 'sync_partial:sync_pack_not_found', group: 'reader-settings' })
  assert.equal(runtime.view.errorGroup, 'reader-settings')
  assert.equal(b.values.get('shelf').get(book), label)
  assert.equal(b.values.get('reader-settings')?.get(pageNumber), undefined)
  f.files.set(path, body)
  await runtime.syncManually()
  assert.equal(b.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(runtime.view.error, '')
  assert.equal(runtime.view.errorGroup, undefined)
})

test('a damaged current group falls back across writer segments for a new device without rewinding an existing one', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const scope = ['shelf', 'reader-settings']
  const settings = 'reader-settings-records'
  const book = data.syncKey(['book', 'org.example.source', 'fallback'])
  const label = JSON.stringify({ title: 'Healthy group', sourceName: 'Source' })
  const first = [edit(facts.emptySyncFact(pageNumber), dot(A, 1), 'set', 'true'),
    edit(facts.emptySyncFact(animation), dot(A, 2), 'set', 'false')]
  const second = [edit(first[0], dot(A, 3), 'set', 'false'), edit(first[1], dot(A, 4), 'set', 'true')]
  const previous = wire.buildSyncDataset(settings, first, 1, undefined, data.syncBucketKey)
  const latest = wire.buildSyncDataset(settings, second, 1, previous.ref, data.syncBucketKey)
  assert.equal(latest.objects.length, 2, 'damage one of two separately updated shards')
  const shelf = dataset(data.SYNC_SHELF_CATALOG_DATASET, book, A, label)
  for (const [revision, datasets] of [[128, [previous]], [129, [latest, shelf]]]) {
    for (const d of datasets) for (const obj of d.objects) await writer.storeObject(obj, noop)
    await writer.publish(manifest(writer.spaceId(), datasets.map(d => d.ref), revision), '', noop, noop,
      [settings, data.SYNC_SHELF_CATALOG_DATASET])
  }
  const connect = async device => {
    device.engine.setSelection(scope)
    await device.engine.saveConfiguration(f.draft)
    device.engine.setEnabled(true)
  }
  const warm = fixture.replica(C)
  await connect(warm)
  await warm.engine.syncNow()
  assert.equal(warm.values.get('reader-settings').get(pageNumber), 'false')
  const shard = latest.objects[0]
  f.files.set(f.writerObject(A, shard.ref), 'broken')
  const cold = fixture.replica(B)
  await connect(cold)
  const firstWrites = f.trace.filter(row => row.method === 'PUT' && row.address.startsWith(f.writerRootV4)).length
  await assert.rejects(cold.engine.syncNow(), /sync_partial:sync_pack_not_found/)
  assert.deepEqual([...cold.values.get('reader-settings')].sort(), [[pageNumber, 'true'], [animation, 'false']].sort())
  assert.equal(cold.values.get('shelf').get(book), label)
  assert.equal(cold.engine.active().frontier.some(path => path.includes('/0000000000000129-')), true)
  assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address.startsWith(f.writerRootV4)).length, firstWrites)
  await assert.rejects(warm.restart().syncNow(), /sync_partial:sync_pack_not_found/)
  assert.equal(warm.values.get('reader-settings').get(pageNumber), 'false')
  const explicit = fixture.replica(randomUUID(), [['reader-settings', new Map([[animation, 'true']])]])
  explicit.snapshotExtras.set('reader-settings', { defaultKeys: [animation], unsetKeys: [] })
  await connect(explicit)
  await assert.rejects(explicit.engine.syncNow(), /sync_partial:sync_pack_not_found/)
  assert.equal(explicit.values.get('reader-settings').get(animation), 'true',
    'an explicitly stored default is not an unset setting eligible for fallback')
  warm.values.get('reader-settings').set(animation, 'false')
  warm.engine.recordEdits('reader-settings', [{ key: animation, kind: 'set', value: 'false' }])
  const pending = structuredClone(warm.engine.active().groups.find(group => group.id === 'reader-settings').pending)
  assert.ok(pending.length > 0)
  await assert.rejects(warm.restart().syncNow(), /sync_partial:sync_pack_not_found/)
  assert.deepEqual(warm.engine.active().groups.find(group => group.id === 'reader-settings').pending, pending)
  f.files.set(f.writerObject(A, shard.ref), shard.body)
  await cold.restart().syncNow()
  assert.equal(cold.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(cold.values.get('reader-settings').get(animation), 'true')
  assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address.startsWith(f.writerRootV4)).length, firstWrites)
  await warm.restart().syncNow()
  assert.equal(warm.engine.active().groups.find(group => group.id === 'reader-settings').pending.length, 0)
  await cold.restart().syncNow()
  assert.equal(cold.values.get('reader-settings').get(animation), 'false')
})

test('the writer can retry a healthy group publication without revalidating an unchanged damaged group', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const book = data.syncKey(['book', 'org.example.source', 'healthy'])
  const label = JSON.stringify({ title: 'Healthy', sourceName: 'Source' })
  const writer = fixture.replica(A, [['reader-settings', new Map([[pageNumber, 'false']])]])
  writer.engine.setSelection(['shelf', 'reader-settings'])
  await writer.engine.saveConfiguration(f.draft)
  writer.engine.setEnabled(true)
  await writer.engine.syncNow()
  const prior = (await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)).own
  const broken = prior.datasets.find(ref => ref.id === 'reader-settings-records')
  const shardPath = f.writerObject(A, broken.shards[0])
  const body = f.files.get(shardPath)
  f.files.delete(shardPath)
  writer.values.set('shelf', new Map([[book, label]]))
  f.faults.push('before-accept')
  const reopened = writer.restart()
  await assert.rejects(reopened.syncNow(), /sync_remote_result_unknown/)
  assert.deepEqual(writer.store.load().intent.writtenDatasets, [data.SYNC_SHELF_CATALOG_DATASET])
  await assert.rejects(writer.restart().syncNow(), /sync_partial:sync_pack_not_found/)
  const current = (await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)).own
  assert.deepEqual(current.datasets.find(ref => ref.id === broken.id), broken)
  const receiver = fixture.replica(B)
  receiver.engine.setSelection(['shelf'])
  await receiver.engine.saveConfiguration(f.draft)
  receiver.engine.setEnabled(true)
  await receiver.engine.syncNow()
  assert.equal(receiver.values.get('shelf').get(book), label)
  f.files.set(shardPath, body)
  await writer.restart().syncNow()
})

test('source shelf and category survive an interrupted move; retry publishes both, and a new favorite stays uncategorized', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const c = await readingDevice(fixture, C, new Map(), true)
  const connect = async device => {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const local = a.coldShelf()
  const category = a.persistence.createCustomCategoryAndPersistLibraryStore(local.shelf, local.service, 'Reading')
  const original = shelfComic('com.example.public', 'old', [category.id])
  const target = shelfComic('org.example.login', 'new', [category.id], 'https://works.example.test/title/12?session_id=private')
  a.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, original)
  await a.runtime.libraryEdits
  await connect(a)
  await connect(b)
  assert.equal(b.coldShelf().shelf.getComic(original.id).sourcePath, original.sourcePath)
  assert.equal(b.coldShelf().shelf.listCustomCategories()[0].name, 'Reading')
  assert.deepEqual(b.coldShelf().shelf.getComic(original.id).categoryIds, [category.id])
  a.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, target)
  a.persistence.removeComicRecordAndPersistLibraryStore(local.shelf, local.service, original.id, target)
  assert.equal(a.coldShelf().shelf.listSyncShelfMoves()[0].target.toSource, target.sourceRuntimeId)
  const backup = a.persistence.libraryStoreBackupPayload(a.backupExport.serializeLibraryStoreForBackup(a.coldShelf().shelf))
  assert.equal(JSON.parse(backup).syncShelfMoves, undefined)
  await a.runtime.libraryEdits
  transport.faults.push('before-accept')
  await assert.rejects(a.engine.syncNow(), /sync_remote_result_unknown/)
  await b.engine.syncNow()
  assert.ok(b.coldShelf().shelf.getComic(original.id))
  assert.equal(b.coldShelf().shelf.getComic(target.id), undefined)
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldShelf().shelf.getComic(original.id), undefined)
  const received = b.coldShelf().shelf.getComic(target.id)
  assert.equal(received.categoryIds.length, 1)
  assert.match(received.sourcePath, /^source:\/\//)
  assert.equal([...transport.files.values()].some(value => value.includes('session_id=private')), false)
  const firstMerge = c.coldShelf()
  c.persistence.upsertComicAndPersistLibraryStore(firstMerge.shelf, firstMerge.service, original)
  await connect(c)
  assert.equal(c.coldShelf().shelf.getComic(original.id), undefined)
  assert.equal(c.engine.active().reviewRequired, false)
  const onB = b.coldShelf()
  b.persistence.upsertComicAndPersistLibraryStore(onB.shelf, onB.service, { ...original, categoryIds: [] })
  await b.runtime.libraryEdits
  await b.engine.syncNow()
  await a.engine.syncNow()
  await c.engine.syncNow()
  for (const device of [a, b, c]) assert.deepEqual(device.coldShelf().shelf.getComic(original.id).categoryIds ?? [], [])
})

test('shelf sync merges restored manual categories and repairs old automatic numbering without losing memberships', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const source = 'com.example.public'
  async function connect(device) {
    await device.engine.testConnection(transport.draft)
    const preview = await device.engine.prepare(transport.draft, ['shelf'])
    await device.engine.confirm(preview.token, preview.conflicts.map(conflict =>
      ({ group: conflict.group, key: conflict.key, useLocal: true })))
  }
  function add(device, work, category) {
    const { shelf, service } = device.coldShelf()
    const comic = shelfComic(source, work, [category])
    device.persistence.upsertComicAndPersistLibraryStore(shelf, service, comic)
    return comic.id
  }
  const original = a.coldShelf()
  // This is a pre-upgrade category that the old client published under a
  // replica-specific WebDAV key before another device restored its backup.
  const category = { ...original.shelf.createCustomCategory('Reading'), id: 'custom_100_1' }
  original.shelf.replaceCustomCategories([category])
  const numberedByUser = original.shelf.createCustomCategory('Reading (2)')
  a.persistence.writeLiveLibrarySnapshot(a.filesDir, a.backupExport.serializeLibraryStoreForBackup(original.shelf))
  const backup = a.persistence.libraryStoreBackupPayload(a.backupExport.serializeLibraryStoreForBackup(original.shelf))
  const restored = b.coldShelf()
  b.persistence.hydrateLibraryStoreFromJson(restored.shelf, backup)
  b.persistence.writeLiveLibrarySnapshot(b.filesDir, backup)
  const local = add(b, 'local', category.id)
  const remote = add(a, 'remote', category.id)
  const separate = add(b, 'separate', numberedByUser.id)
  const shared = add(a, 'shared', category.id)
  add(b, 'shared', category.id)
  const partlyRemoved = add(a, 'partly-removed', category.id)
  add(b, 'partly-removed', category.id)
  await connect(a)
  await connect(b)
  const assertShelf = (device, name = 'Reading') => {
    const shelf = device.coldShelf().shelf
    assert.deepEqual(shelf.listCustomCategories().map(item => item.name).sort(), [name, 'Reading (2)'].sort())
    assert.deepEqual(shelf.getComic(local).categoryIds, [category.id])
    assert.deepEqual(shelf.getComic(remote).categoryIds, [category.id])
    assert.deepEqual(shelf.getComic(separate).categoryIds, [numberedByUser.id])
    return shelf
  }
  assert.deepEqual(assertShelf(b).getComic(shared).categoryIds, [category.id])
  const beforeReceivingAlias = a.coldShelf()
  a.persistence.upsertComicAndPersistLibraryStore(beforeReceivingAlias.shelf, beforeReceivingAlias.service,
    { ...beforeReceivingAlias.shelf.getComic(partlyRemoved), categoryIds: [] })
  await a.runtime.libraryEdits
  await a.engine.syncNow()
  await b.engine.syncNow()
  for (const device of [a, b]) assert.deepEqual(assertShelf(device).getComic(partlyRemoved).categoryIds, [category.id])

  // A clean client joining this already-populated WebDAV has no backup or
  // local projection. It must still see one category and both writers' books.
  const remoteOnly = await readingDevice(fixture, C, new Map(), true)
  await connect(remoteOnly)
  const fromServer = remoteOnly.coldShelf().shelf
  const serverCategory = fromServer.listCustomCategories().find(item => item.name === 'Reading')
  assert.deepEqual(fromServer.listCustomCategories().map(item => item.name).sort(), ['Reading', 'Reading (2)'])
  for (const id of [local, remote, shared, partlyRemoved]) assert.deepEqual(fromServer.getComic(id).categoryIds, [serverCategory.id])

  // Replay a persisted pre-upgrade shelf with both original wire IDs. The
  // server already has every member, so a receive-only diff cannot fix it.
  const libraryFile = b.filesDir + '/' + b.persistence.LIBRARY_STORE_PERSISTENCE_FILE_NAME
  const projectionFile = b.filesDir + '/device-sync-projection.v1.json'
  const library = b.persistence.readLibraryBackupDocument(b.filesDir)
  const projection = JSON.parse(b.files.get(projectionFile))
  const alias = projection.categories.find(row => row.mergedInto === category.id)
  const primary = projection.categories.find(row => row.local === category.id)
  assert.ok(alias && primary)
  const oldName = 'Reading (3)'
  const old = library.customCategories.find(item => item.id === category.id)
  // A cloud download can restore the old row before the WebDAV alias changes.
  b.persistence.writeLiveLibrarySnapshot(b.filesDir, JSON.stringify({ ...library,
    customCategories: library.customCategories.concat({ ...old, id: alias.local, sortOrder: old.sortOrder + 1 }) }))
  const snapshot = await b.owner.snapshot('shelf', true)
  const order = snapshot.values.find(row => row.key === data.syncKey(['order']))
  const sharedOrder = JSON.parse(order.value)
  assert.equal(sharedOrder.filter(key => key === alias.shared).length, 1)
  data.checkSyncGroupFact('shelf', facts.applySyncEdit(facts.emptySyncFact(order.key),
    { kind: 'set', value: order.value, version: dot(B, 1), observed: [] }))
  library.customCategories.push({ ...old, id: alias.local, name: oldName, sortOrder: library.customCategories.length })
  for (const row of library.comics) {
    if (!row.categoryIds.includes(category.id)) continue
    row.categoryIds = [primary, alias].filter(item => item.members.includes(row.id)).map(item => item.local)
  }
  alias.displayedName = oldName
  delete alias.mergedInto
  delete alias.members
  delete primary.members
  b.persistence.writeLiveLibrarySnapshot(b.filesDir, JSON.stringify(library))
  b.files.set(projectionFile, JSON.stringify(projection))
  await b.engine.syncNow()
  assert.deepEqual(assertShelf(b).getComic(shared).categoryIds, [category.id])

  const next = b.coldShelf()
  b.persistence.renameCustomCategoryAndPersistLibraryStore(next.shelf, next.service, category.id, 'Current')
  b.persistence.upsertComicAndPersistLibraryStore(next.shelf, next.service, { ...next.shelf.getComic(shared), categoryIds: [] })
  await b.runtime.libraryEdits
  await b.engine.syncNow()
  await a.engine.syncNow()
  for (const device of [a, b]) assert.deepEqual(assertShelf(device, 'Current').getComic(shared).categoryIds ?? [], [])
  const published = transport.trace.filter(request => request.method === 'PUT').length
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(transport.trace.filter(request => request.method === 'PUT').length, published)
})

test('an already-published legacy backup alias is repaired in WebDAV and keeps both shelves intact', async () => {
  const transport = transportFixture()
  const writer = new transport.WriterWebDav(transport.draft, [], undefined, A)
  const original = A
  const copied = data.syncSharedCategoryId(B, 'custom_sync_' + original)
  const originalKey = data.syncKey(['category', original])
  const copiedKey = data.syncKey(['category', copied])
  const manualKey = data.syncKey(['category', C])
  const source = 'com.example.public'
  const values = [
    [originalKey, '"Reading"', A],
    [copiedKey, '"Reading (3)"', B],
    [manualKey, '"Reading (2)"', B],
    [data.syncKey(['book', source, 'original']), '{"title":"Original","sourceName":"Public"}', A],
    [data.syncKey(['book', source, 'copy']), '{"title":"Copy","sourceName":"Public"}', B],
    [data.syncKey(['member', source, 'original', original]), 'true', A],
    [data.syncKey(['member', source, 'copy', copied]), 'true', B],
  ]
  const seeded = wire.buildSyncDataset(data.SYNC_SHELF_CATALOG_DATASET, values.map(([key, value, replica], i) =>
    edit(facts.emptySyncFact(key), dot(replica, i + 1), 'set', value)), 1, undefined, data.syncBucketKey)
  for (const object of seeded.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [seeded.ref]), '', noop, noop, [seeded.ref.id])
  const receiver = await readingDevice(engineFixture(transport.WriterWebDav), C, new Map(), true)
  receiver.engine.setSelection(['shelf'])
  await receiver.engine.saveConfiguration(transport.draft)
  receiver.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(receiver.engine.syncNow(), /sync_remote_result_unknown/)
  await receiver.engine.syncNow()
  const shelf = receiver.coldShelf().shelf
  assert.deepEqual(shelf.listCustomCategories().map(item => item.name).sort(), ['Reading', 'Reading (2)'])
  const category = shelf.listCustomCategories().find(item => item.name === 'Reading')
  for (const work of ['original', 'copy']) assert.deepEqual(shelf.getComic(source + ':' + work).categoryIds, [category.id])

  const readback = new transport.WriterWebDav(transport.draft, [], undefined, C)
  const own = (await readback.readManifest(noop)).own
  const ref = own.datasets.find(item => item.id === seeded.ref.id)
  const repaired = (await Promise.all(ref.shards.map(async shard =>
    wire.decodeSyncShard(ref.id, shard, await readback.readObject(shard, noop), data.syncBucketKey)))).flat()
  assert.equal(facts.syncVisibleValue(repaired.find(fact => fact.key === copiedKey)), '"Reading"')
  const puts = transport.trace.filter(row => row.method === 'PUT').length
  await receiver.engine.syncNow()
  assert.equal(transport.trace.filter(row => row.method === 'PUT').length, puts)
})

test('an unsendable legacy reading capture is settled once without changing saved reading progress', async () => {
  const transport = transportFixture()
  const device = await readingDevice(engineFixture(transport.WriterWebDav), A, new Map(), true)
  await device.engine.testConnection(transport.draft)
  await device.engine.confirm((await device.engine.prepare(transport.draft, ['reading'])).token, [])
  device.runtime.refresh()
  const source = 'com.example.public', work = 'legacy-book', chapterId = 'chapter'
  const comicId = source + ':' + work
  const file = device.filesDir + '/reader-sessions.v1.json'
  const reader = { schemaVersion: 4, ...device.backupExportReader() }
  const progress = { comicId, chapterId, pageIndex: 1, totalPages: 2, updatedAt: 10, progressRatio: 1, completed: false }
  const capture = { id: 'old-invalid-capture', space: device.engine.active().space, source, work, comicId, chapterId,
    page: 9, total: 2, date: 10, complete: false, observedActions: [], positionSeen: [], recentSeen: [], recentCleared: [], readSeen: [] }
  reader.progress = [progress]
  reader.syncPositions = [capture]
  device.reader.adapter.activityDatabase().save(reader)
  device.reader.reload()
  await device.runtime.syncManually()
  assert.equal(device.owner.readingAcknowledged(capture), true)
  assert.equal(device.engine.active().groups.find(group => group.id === 'reading').pending.length, 0)
  assert.equal(device.coldReader().getProgress(comicId).pageIndex, 1)
  const receipts = device.store.load().readingReceipts.length
  await device.runtime.syncManually()
  assert.equal(device.store.load().readingReceipts.length, receipts)
  assert.equal(device.coldReader().getProgress(comicId).pageIndex, 1)
})

test('automatic and focused sync take clearly newer cloud resume positions without overriding a newer local branch', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.SharedWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const source = 'com.example.public', chapter = 'chapter'
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['reading'])).token, [])
  }
  const save = (device, work, page, date) => {
    const comicId = source + ':' + work
    device.reader.saveSourceHistory({ comicId, sourceId: source, mangaId: work, title: work, sourceName: 'Public',
      chapterId: chapter, chapterTitle: 'Chapter' })
    device.reader.saveProgress({ comicId, chapterId: chapter, pageIndex: page, totalPages: 30, updatedAt: date,
      progressRatio: (page + 1) / 30, completed: false })
    assert.equal(device.reader.flush(), true)
    device.engine.recordEdits('reading', [
      { key: data.syncKey(['recent', source, work]), kind: 'set',
        value: JSON.stringify(data.syncReadingRecent(source, chapter, date, work, 'Public', 'Chapter', page)) },
      { key: data.syncKey(['position', source, work, chapter]), kind: 'set',
        value: JSON.stringify(data.syncReadingPosition(page, 30, date)) },
    ])
  }
  for (const work of ['automatic', 'focused', 'newer-local']) {
    save(a, work, 21, 200)
    save(b, work, 7, work === 'newer-local' ? 300 : 100)
  }
  await a.engine.syncNow()
  const focused = await b.engine.syncReadingWork(source, 'focused')
  assert.equal(focused.applied, true)
  assert.equal(focused.conflict, undefined)
  await b.engine.syncNow()
  for (const work of ['automatic', 'focused']) {
    assert.equal(b.coldReader().getProgress(source + ':' + work).pageIndex, 21)
  }
  assert.equal(b.coldReader().getProgress(source + ':newer-local').pageIndex, 7)
  const heldWorks = () => Array.from(new Set(b.engine.active().groups.find(g => g.id === 'reading').pending.map(item =>
    data.syncKeyParts(item.key)[2])))
  assert.deepEqual(heldWorks(), ['newer-local'])
  const decision = (await b.engine.syncReadingWork(source, 'newer-local')).conflict
  assert.ok(decision)
  await b.engine.syncNow()
  assert.deepEqual(heldWorks(), ['newer-local'])
  await b.engine.resolveReadingWork(decision, false, b.engine.requestGuard())
  await b.engine.syncNow()
  await a.engine.syncNow()
  assert.equal(b.coldReader().getProgress(source + ':newer-local').pageIndex, 7)
  assert.equal(a.coldReader().getProgress(source + ':newer-local').pageIndex, 7)
})

test('keeping local restores the saved chapter while an obsolete choice leaves a newer save intact', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.SharedWebDav)
  const local = await readingDevice(fixture, A, new Map(), true)
  const remote = await readingDevice(fixture, B, new Map(), true)
  const source = 'com.example.reader', work = 'choice', comicId = source + ':' + work
  const save = (device, chapterId, pageIndex, updatedAt) => {
    device.reader.saveProgress({ comicId, chapterId, pageIndex, totalPages: 30, updatedAt,
      progressRatio: (pageIndex + 1) / 30, completed: false }, chapterId)
    assert.equal(device.reader.flush(), true)
  }
  for (const device of [local, remote]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['reading'])).token, [])
    device.reader.saveSourceHistory({ comicId, sourceId: source, mangaId: work, title: 'Choice', sourceName: 'Public',
      chapterId: 'chapter-10', chapterTitle: 'chapter-10' })
  }
  save(remote, 'chapter-10', 3, 100)
  await remote.engine.syncNow()
  save(local, 'chapter-66', 11, 300)
  assert.equal(local.coldReader().getSourceHistory(comicId).chapterId, 'chapter-66')
  // Reproduce the two incompatible persisted rows that the original device
  // reported, then open via the current progress and resolve the old branch.
  local.reader.saveSourceHistory({ comicId, sourceId: source, mangaId: work, title: 'Choice', sourceName: 'Public',
    chapterId: 'chapter-10', chapterTitle: 'chapter-10' })
  assert.equal(local.reader.flush(), true)
  const current = local.coldReader().getSourceHistoryForResume(comicId)
  assert.equal(current.chapterId, 'chapter-66')
  assert.equal(current.chapterTitle, undefined)
  const date = local.coldReader().getProgress(comicId).updatedAt
  const recent = data.syncReadingRecent(source, current.chapterId, date, 'Choice', 'Public', 'chapter-66', 11)
  const saved = { recent, position: data.syncReadingPosition(11, 30, date),
    chapter: current.chapterId, page: 11, total: 30, date }
  const { conflict } = await local.engine.syncReadingWork(source, work, saved)
  assert.equal(conflict.local.chapter, 'chapter-66')
  assert.equal(conflict.remote.chapter, 'chapter-10')
  const index = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/pages/Index.ets'), 'utf8')
  const syntax = ts.createSourceFile('Index.ts', index.replace(/\bstruct /g, 'class '), ts.ScriptTarget.Latest, true)
  const method = syntax.statements.find(node => ts.isClassDeclaration(node) &&
    node.members.some(row => row.name?.text === 'resolveReadingResumeConflict')).members
    .find(row => row.name?.text === 'resolveReadingResumeConflict')
  const ui = ts.transpileModule('class Resume {' + method.getText(syntax) + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 },
  }).outputText
  const failures = []
  const sourceSession = compile('../model/SourceReaderSession', { './ReaderChapterSequence': {} })
  const Resume = new Function('appDeviceSync', 'sourceReaderSessionRequestFromHistory',
    'mergeSourceReaderResumeRequest', 'DiagnosticLogger', 'AppStrings', ui + '\nreturn Resume')(
    { resolveReadingResumeConflict: (conflict, useRemote) =>
      local.engine.resolveReadingWork(conflict, useRemote, local.engine.requestGuard()) },
    sourceSession.sourceReaderSessionRequestFromHistory,
    sourceSession.mergeSourceReaderResumeRequest,
    { info: noop, exception: (_category, _event, error) => failures.push(error.message) }, { get: key => key })
  const opened = []
  const hints = []
  const page = new Resume()
  Object.assign(page, { readerSessionStore: local.reader, openSourceReader: async request => opened.push(request.chapterId),
    libraryStore: { getComicSummary: () => undefined },
    showToast: message => hints.push(message) })
  await page.resolveReadingResumeConflict(conflict, false, { comicId })
  assert.deepEqual(opened, ['chapter-66'])
  assert.equal(local.coldReader().getSourceHistory(comicId).chapterId, 'chapter-66')
  assert.equal(local.coldReader().getProgress(comicId).pageIndex, 11)
  save(local, 'chapter-67', 1, 400)
  await page.resolveReadingResumeConflict(conflict, false, { comicId })
  assert.deepEqual(opened, ['chapter-66'])
  assert.deepEqual(failures, ['sync_local_changed'])
  assert.deepEqual(hints, ['device_sync_progress_resolve_failed'])
  assert.equal(local.coldReader().getProgress(comicId).chapterId, 'chapter-67')
})

test('resolving a same-page conflict with newer known timestamp works for both local and remote choices', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.SharedWebDav)
  const local = await readingDevice(fixture, A, new Map(), true)
  const remote = await readingDevice(fixture, B, new Map(), true)
  const source = 'zh.test'
  const work = 'same-page-conflict'
  const comicId = source + ':' + work
  const setupDevice = async device => {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['reading'])).token, [])
    device.reader.saveSourceHistory({ comicId, sourceId: source, mangaId: work, title: 'SamePage',
      sourceName: 'Public', chapterId: 'chapter-1', chapterTitle: 'Ch 1' })
  }
  await setupDevice(local)
  await setupDevice(remote)

  remote.reader.saveProgress({ comicId, chapterId: 'chapter-1', pageIndex: 0, totalPages: 20, updatedAt: 500,
    progressRatio: 1 / 20, completed: false }, 'Ch 1')
  assert.equal(remote.reader.flush(), true)
  await remote.engine.syncNow()

  local.reader.saveProgress({ comicId, chapterId: 'chapter-1', pageIndex: 2, totalPages: 20, updatedAt: 400,
    progressRatio: 3 / 20, completed: false }, 'Ch 1')
  assert.equal(local.reader.flush(), true)
  const date = local.coldReader().getProgress(comicId).updatedAt
  const saved = {
    recent: data.syncReadingRecent(source, 'chapter-1', date, 'SamePage', 'Public', 'Ch 1', 2),
    position: data.syncReadingPosition(2, 20, date),
    chapter: 'chapter-1', page: 2, total: 20, date,
  }
  const { conflict } = await local.engine.syncReadingWork(source, work, saved)
  assert.ok(conflict)
  assert.equal(conflict.local.page, 2)
  assert.equal(conflict.remote.page, 0)

  // Both Keep Local and Use Remote must resolve cleanly even when expectedLocal.date
  // is skewed compared to the projected snapshot timestamp (and even with pending flush).
  const skewedConflict = {
    ...conflict,
    local: { ...conflict.local, date: date - 50 },
  }
  await local.engine.resolveReadingWork(skewedConflict, false, local.engine.requestGuard())
  assert.equal(local.coldReader().getProgress(comicId).pageIndex, 2)

  // A subsequent real local page turn must still be protected by sync_local_changed.
  local.reader.saveProgress({ comicId, chapterId: 'chapter-1', pageIndex: 4, totalPages: 20, updatedAt: 900,
    progressRatio: 5 / 20, completed: false }, 'Ch 1')
  assert.equal(local.reader.flush(), true)
  await assert.rejects(
    () => local.engine.resolveReadingWork(skewedConflict, true, local.engine.requestGuard()),
    /sync_local_changed/,
  )
  assert.equal(local.coldReader().getProgress(comicId).pageIndex, 4)

  // Re-syncing for the new page and choosing Use Remote switches cleanly to page 0.
  const latestDate = local.coldReader().getProgress(comicId).updatedAt
  const { conflict: conflict2 } = await local.engine.syncReadingWork(source, work, {
    recent: data.syncReadingRecent(source, 'chapter-1', latestDate, 'SamePage', 'Public', 'Ch 1', 4),
    position: data.syncReadingPosition(4, 20, latestDate),
    chapter: 'chapter-1', page: 4, total: 20, date: latestDate,
  })
  assert.ok(conflict2)
  await local.engine.resolveReadingWork(conflict2, true, local.engine.requestGuard())
  assert.equal(local.coldReader().getProgress(comicId).pageIndex, 0)
})

test('the next manual sync completes an interrupted local rollback and preserves a later Reader save', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const original = b.coldShelf()
  const kept = b.persistence.createCustomCategoryAndPersistLibraryStore(original.shelf, original.service, 'Local')
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  await a.engine.syncNow()
  const shelfChange = a.coldShelf()
  const category = a.persistence.createCustomCategoryAndPersistLibraryStore(shelfChange.shelf, shelfChange.service, 'Shared')
  const added = shelfComic('com.example.public', 'new', [category.id])
  a.persistence.upsertComicAndPersistLibraryStore(shelfChange.shelf, shelfChange.service, added)
  await a.runtime.libraryEdits
  await a.engine.syncNow()

  let projectionFailed = false
  let failedRollbacks = 0
  let storageRecovered = false
  b.rdb.beforeCommit(() => {
    if (projectionFailed && !storageRecovered) {
      failedRollbacks++
      throw new Error('volume still unavailable during rollback')
    }
  })
  b.onWrite(file => {
    if (!projectionFailed && file.endsWith('/device-sync-projection.v1.json')) {
      projectionFailed = true
      throw new Error('volume became unavailable')
    }

  })
  b.runtime.refresh()
  await assert.rejects(b.runtime.syncManually(), /sync_local_rollback_pending/)
  assert.equal(b.runtime.view.error, 'sync_local_rollback_pending')
  assert.equal(failedRollbacks, 1)
  const journal = b.filesDir + '/device-sync-local-commit.v1.json'
  assert.equal(b.files.has(journal), true)

  b.reader.saveProgress({ comicId: 'local-reader-book', chapterId: 'chapter', pageIndex: 2, totalPages: 5,
    updatedAt: Date.now(), progressRatio: 0.6, completed: false })
  await assert.rejects(b.runtime.syncManually(), /sync_local_rollback_pending/)
  assert.equal(failedRollbacks, 2)
  assert.equal(b.files.has(journal), true)

  storageRecovered = true
  await b.runtime.syncManually()
  assert.equal(b.files.has(journal), false)
  assert.equal(b.runtime.view.error, '')
  const received = b.coldShelf().shelf
  const receivedCategory = received.listCustomCategories().find(item => item.name === 'Shared')
  assert.equal(received.listCustomCategories().find(item => item.name === 'Local').id, kept.id)
  assert.deepEqual(received.getComic(added.id).categoryIds, [receivedCategory.id])
  assert.equal(b.coldReader().getProgress('local-reader-book').pageIndex, 2)
})

test('shelf sync round-trips smart rule changes using the same category ID', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.SharedWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const first = a.coldShelf()
  const second = b.coldShelf()
  const manual = a.persistence.createCustomCategoryAndPersistLibraryStore(first.shelf, first.service, 'Favorites')
  b.persistence.createCustomCategoryAndPersistLibraryStore(second.shelf, second.service, 'Weekend')
  const group = { id: 'smart:1700000000000', name: 'Weekend', sortOrder: 2, createdAt: 1700000000000,
    updatedAt: 1700000000000, filters: [
      { method: 'category', value: manual.id, exclude: false },
      { method: 'downloaded', exclude: true },
    ] }
  a.persistence.replaceSmartCategoriesAndPersistLibraryStore(first.shelf, first.service, [group])
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const received = b.coldShelf()
  const groups = received.shelf.listSmartCategories()
  assert.equal(groups.length, 1)
  const synced = groups[0]
  assert.equal(synced.name, 'Weekend (2)')
  assert.equal(synced.sortOrder, 2)
  const receiverCategory = received.shelf.listCustomCategories().find(category => category.name === 'Favorites')
  assert.equal(receiverCategory.id, manual.id)
  assert.deepEqual(synced.filters.map(filter => [filter.method, filter.value, filter.exclude]),
    [['category', receiverCategory.id, false], ['downloaded', undefined, true]])
  // A read-back of the local display name and remapped rule must be identical on the wire.
  const smartRows = device => device.owner.snapshot('shelf', false).then(snapshot =>
    snapshot.values.filter(row => data.syncKeyParts(row.key)[0] === 'smart-category'))
  assert.deepEqual(await smartRows(a), await smartRows(b))
  synced.name = 'To catch up'
  synced.sortOrder = 1
  synced.filters[1] = { method: 'hasUnread', exclude: false }
  b.persistence.replaceSmartCategoriesAndPersistLibraryStore(received.shelf, received.service, [synced])
  await b.engine.syncNow()
  await a.engine.syncNow()
  const edited = a.coldShelf()
  const updated = edited.shelf.listSmartCategories()
  assert.equal(updated.length, 1)
  assert.equal(updated[0].id, group.id)
  assert.equal(updated[0].name, 'To catch up')
  assert.equal(updated[0].sortOrder, 1)
  assert.deepEqual(updated[0].filters.map(filter => [filter.method, filter.value, filter.exclude]),
    [['category', manual.id, false], ['hasUnread', undefined, false]])
  a.persistence.replaceSmartCategoriesAndPersistLibraryStore(edited.shelf, edited.service, [])
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.deepEqual(b.coldShelf().shelf.listSmartCategories(), [])
  assert.ok(b.coldShelf().shelf.listCustomCategories().some(category => category.id === receiverCategory.id))
  const writes = transport.trace.filter(request => request.method === 'PUT').length
  await b.engine.syncNow()
  await a.engine.syncNow()
  assert.deepEqual(a.coldShelf().shelf.listSmartCategories(), [])
  assert.equal(transport.trace.filter(request => request.method === 'PUT').length, writes)
})

test('shelf sync transfers category privacy and membership together, including a reverse change', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.SharedWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const first = a.coldShelf()
  const source = 'com.example.public'
  const manual = a.persistence.createCustomCategoryAndPersistLibraryStore(first.shelf, first.service, 'Private shelf')
  const work = shelfComic(source, 'private-work', [manual.id])
  a.persistence.upsertComicAndPersistLibraryStore(first.shelf, first.service, work)
  a.persistence.setCustomCategoryPrivacyAndPersistLibraryStore(first.shelf, first.service, manual.id, true)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const received = b.coldShelf()
  const category = received.shelf.listCustomCategories().find(row => row.name === 'Private shelf')
  assert.equal(category.id, manual.id)
  assert.equal(category.isPrivate, true)
  assert.deepEqual(received.shelf.getComic(work.id).categoryIds, [category.id])
  b.persistence.setCustomCategoryPrivacyAndPersistLibraryStore(received.shelf, received.service, category.id, false)
  await b.runtime.libraryEdits
  await b.engine.syncNow()
  await a.engine.syncNow()
  const restored = a.coldShelf().shelf
  assert.equal(restored.listCustomCategories().find(row => row.id === manual.id).isPrivate, false)
  assert.deepEqual(restored.getComic(work.id).categoryIds, [manual.id])
})

test('a remote deletion blocked by local notes commits its receipt without reloading the shelf', async () => {
  const device = await readingDevice(engineFixture(), A, new Map(), true)
  const source = 'com.example.public'
  const { shelf, service } = device.coldShelf()
  const category = device.persistence.createCustomCategoryAndPersistLibraryStore(shelf, service, 'Reading')
  const book = { ...shelfComic(source, 'kept-work', [category.id]), personalNotes: 'My notes' }
  device.persistence.upsertComicAndPersistLibraryStore(shelf, service, book)
  const notifications = []
  device.owner.publishWith(groups => notifications.push(...groups))
  let received = false
  await device.owner.commit([{ group: 'shelf', changes: [{ key: data.syncKey(['book', source, 'kept-work']), value: '' }] }],
    [], async () => ({ check: noop, publish: () => { received = true }, dispose: async () => {} }))
  assert.equal(received, true)
  assert.equal(device.coldShelf().shelf.getComic(book.id).personalNotes, 'My notes')
  const projection = JSON.parse(device.files.get(`${device.filesDir}/device-sync-projection.v1.json`))
  assert.deepEqual(projection.blockedShelf, [book.id])
  assert.deepEqual(notifications, [])
})

test('WebDAV keeps a smart category until the cloud deletes its definition, even when its rules go first', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.SharedWebDav)
  const definition = { id: 'smart:1afed9c2-2bd0-422c-856b-4c75f9abf7d6', name: 'Smart', sortOrder: 0,
    createdAt: 1, updatedAt: 1, filters: [{ method: 'downloaded', exclude: false }] }
  let raw = JSON.stringify({ schemaVersion: 1, comics: [], smartCategories: [definition] })
  const database = { shelfRevision: () => 0, readShelfSnapshot: async () => raw,
    writeShelfEdits: (_directory, _edits, image) => {
      const snapshot = JSON.parse(raw)
      if (image.smartCategories !== undefined) snapshot.smartCategories = image.smartCategories ?? undefined
      raw = JSON.stringify(snapshot)
    },
  }
  const first = await readingDevice(fixture, A, new Map(), true, undefined, database)
  const second = await readingDevice(fixture, B, new Map(), true)
  for (const device of [first, second]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  assert.equal(second.coldShelf().shelf.listSmartCategories()[0].id, definition.id)

  raw = JSON.stringify({ schemaVersion: 1, comics: [], smartCategories: [], incompleteSmartCategoryIds: [definition.id] })
  await first.engine.syncNow()
  await second.engine.syncNow()
  assert.equal(second.coldShelf().shelf.listSmartCategories()[0].id, definition.id)

  raw = JSON.stringify({ schemaVersion: 1, comics: [], smartCategories: [] })
  await first.engine.syncNow()
  await second.engine.syncNow()
  assert.deepEqual(second.coldShelf().shelf.listSmartCategories(), [])
})

test('RDB shelf receipt rolls back scoped rows and rejects an intervening local edit before publication', async () => {
  let raw
  let revision = 0
  const savedImages = []
  const readDomains = []
  const database = {
    shelfRevision: () => revision,
    readShelfSnapshot: async (_context, domain) => { readDomains.push(domain); return raw },
    writeShelfEdits: (_directory, edits, image) => {
      savedImages.push(image)
      assert.deepEqual(edits.comicIds, [changedWork.id])
      assert.deepEqual(edits.unchangedCatalogs, [changedWork.id])
      assert.deepEqual(image.works[0].chapters, [])
      revision++
    },
  }
  const device = await readingDevice(engineFixture(), A, new Map(), true, undefined, database)
  const source = 'com.example.public'
  const changedWork = shelfComic(source, 'changed')
  const { shelf } = device.coldShelf()
  shelf.createCustomCategory('A category')
  shelf.addComic(changedWork)
  shelf.addComic(shelfComic(source, 'untouched'))
  raw = device.backupExport.serializeLibraryStoreForBackup(shelf)
  const notifications = []
  device.owner.publishWith((groups, _reading, edits) => notifications.push({ groups, edits }))
  const coverUri = 'https://works.example.test/cover.png'
  const earlierRevision = wire.syncDigest(raw)
  const earlier = await device.owner.snapshot('shelf', false, undefined, undefined, false, earlierRevision)
  // A token from the retired whole-file codec is rebased to the row revision.
  assert.notEqual(earlier.revision, earlierRevision)
  const current = await device.owner.snapshot('shelf', false)
  assert.ok(readDomains.length > 0 && readDomains.every(domain => domain === 'shelf-sync'))
  assert.deepEqual(current.values, earlier.values)
  const commit = prepare => device.owner.commit([{ group: 'shelf',
    changes: [{ key: data.syncKey(['cover', source, 'changed']), value: JSON.stringify(coverUri) }] }],
    [{ group: 'shelf', revision: current.revision }], prepare)
  await assert.rejects(commit(async () => {
    revision++
    return { check: noop, publish: () => assert.fail('receipt was published'), dispose: async () => {} }
  }), /sync_local_changed/)
  assert.deepEqual(savedImages, [])
  await assert.rejects(commit(async () => ({ check: noop, dispose: async () => {},
    publish: () => { throw new Error('receipt_interrupted') } })), /receipt_interrupted/)
  assert.deepEqual(savedImages.map(image => image.works[0].coverUri), [coverUri, undefined])
  assert.deepEqual(notifications, [])
  await commit(async () => ({ check: noop, publish: noop, dispose: async () => {} }))
  assert.deepEqual(notifications.map(event => event.groups), [['shelf']])
  assert.equal(notifications[0].edits.after.works[0].coverUri, coverUri)
})

test('a received RDB deletion captures the full catalog of only the deleted work for rollback', async () => {
  let raw
  const work = shelfComic('com.example.public', 'removed')
  const deleted = { ...work, chapters: [{ id: 'chapter-1', pages: [{ id: 'page-1' }] }] }
  const saved = []
  const scopes = []
  const database = { shelfRevision: () => 0, readShelfSnapshot: async () => raw,
    readShelfWorksForRecovery: async (_context, ids) => { scopes.push(ids); return [deleted] },
    writeShelfEdits: (_directory, edits, image) => saved.push({ ids: edits.comicIds, works: image.works }),
  }
  const device = await readingDevice(engineFixture(), A, new Map(), true, undefined, database)
  const { shelf } = device.coldShelf()
  shelf.addComic(work)
  shelf.addComic(shelfComic('com.example.public', 'untouched'))
  raw = device.backupExport.serializeLibraryStoreForBackup(shelf)
  await assert.rejects(device.owner.commit([{ group: 'shelf', changes: [
    { key: data.syncKey(['book', 'com.example.public', 'removed']), value: '' },
  ] }], [], async () => ({ check: noop, dispose: async () => {},
    publish: () => { throw new Error('receipt_interrupted') } })), /receipt_interrupted/)
  assert.deepEqual(scopes, [[work.id]])
  assert.deepEqual(saved, [{ ids: [work.id], works: [] }, { ids: [work.id], works: [deleted] }])
})

test('a move keeps the original if the destination was independently removed, including a receiver with local notes', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const original = shelfComic('com.example.public', 'old')
  const target = shelfComic('org.example.login', 'new')
  const left = a.coldShelf()
  for (const book of [original, target]) a.persistence.upsertComicAndPersistLibraryStore(left.shelf, left.service, book)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const right = b.coldShelf()
  b.persistence.upsertComicAndPersistLibraryStore(right.shelf, right.service,
    { ...right.shelf.getComic(original.id), personalNotes: 'My notes' })
  b.persistence.removeComicRecordAndPersistLibraryStore(right.shelf, right.service, target.id)
  a.persistence.removeComicRecordAndPersistLibraryStore(left.shelf, left.service, original.id, target)
  await b.runtime.libraryEdits
  await b.engine.syncNow()
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldShelf().shelf.getComic(target.id), undefined)
  assert.equal(b.coldShelf().shelf.getComic(original.id).personalNotes, 'My notes')
  assert.deepEqual(b.owner.blockedShelfItems(), [])
})

test('shelf receipts cannot update an unrelated row with the same storage ID', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const original = shelfComic('org.example.source', 'same')
  const left = a.coldShelf()
  a.persistence.upsertComicAndPersistLibraryStore(left.shelf, left.service, original)
  const right = b.coldShelf()
  const resident = { ...original, sourceRuntimeId: undefined, sourceKind: 'komga_remote',
    remoteServerId: 'server', sourcePath: 'komga://server/same', title: 'Private library' }
  b.persistence.upsertComicAndPersistLibraryStore(right.shelf, right.service, resident)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  a.persistence.removeComicRecordAndPersistLibraryStore(left.shelf, left.service, original.id)
  await a.runtime.libraryEdits
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldShelf().shelf.getComic(original.id).title, 'Private library')
})

test('batch shelf removal persists selected source favorites and syncs their removals', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = await readingDevice(fixture, A, new Map(), true)
  const b = await readingDevice(fixture, B, new Map(), true)
  const left = a.coldShelf()
  const books = ['first', 'second', 'retained'].map(work => shelfComic('org.example.source', work))
  for (const book of books) a.persistence.upsertComicAndPersistLibraryStore(left.shelf, left.service, book)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const ids = books.slice(0, 2).map(book => book.id)
  assert.throws(() => a.persistence.removeComicsAndPersistLibraryStore(left.shelf,
    { databaseForEdits: () => ({ saveLocalEdits() { throw Error('disk full') } }) }, ids), /disk full/)
  assert.ok(ids.every(id => left.shelf.getComic(id)))
  assert.deepEqual(Array.from(a.persistence.removeComicsAndPersistLibraryStore(left.shelf, left.service, ids)), ids)
  await a.runtime.libraryEdits
  await a.engine.syncNow()
  await b.engine.syncNow()
  const right = b.coldShelf().shelf
  assert.ok(ids.every(id => right.getComic(id) === undefined))
  assert.ok(right.getComic(books[2].id))
})

test('a writer keeps its original shelf shards while publishing new source books after upgrade', async () => {
  const f = transportFixture()
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const old = shelfComic('com.xkcd.zh.koma', 'xkcd:zh')
  const oldKey = data.syncKey(['book', old.sourceRuntimeId, old.remoteResourceId])
  const oldShard = dataset('shelf', oldKey, A, JSON.stringify({ title: 'xkcd', sourceName: 'xkcd 中文', sourceVersion: '0.1.7' }))
  for (const object of oldShard.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [oldShard.ref]), '', noop, noop, ['shelf'])
  const device = await readingDevice(engineFixture(f.WriterWebDav), A, new Map(), true)
  const connect = async row => {
    await row.engine.testConnection(f.draft)
    await row.engine.confirm((await row.engine.prepare(f.draft, ['shelf'])).token, [])
  }
  await connect(device)
  const local = device.coldShelf()
  assert.equal(local.shelf.getComic(old.id).title, 'xkcd')
  const added = shelfComic('com.example.public', 'new')
  device.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, added)
  await device.runtime.libraryEdits
  await device.engine.syncNow()
  const receipt = await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)
  assert.deepEqual(receipt.own.datasets.find(item => item.id === 'shelf'), oldShard.ref)
  assert.ok(receipt.own.datasets.some(item => item.id === data.SYNC_SHELF_CATALOG_DATASET))
  const other = await readingDevice(engineFixture(f.WriterWebDav), B, new Map(), true)
  await connect(other)
  assert.deepEqual(other.coldShelf().shelf.listComics().map(book => book.id).sort(), [old.id, added.id].sort())
})

test('saved history and live page turns from other sources reach a fresh reader without a source request', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const publicId = 'com.webtoons.zh-hant.koma'
  const loginId = 'org.example.login-required'
  const enabled = { enabled: true, version: '7.0.1', name: 'Login source' }
  const installedOnB = new Map()
  const a = await readingDevice(fixture, A, new Map([[loginId, enabled]]))
  const b = await readingDevice(fixture, B, installedOnB)
  const work = 'webtoon:1860'
  const chapter = 'chapter:webtoons:zh-Hant:/zh-hant/title/viewer?title_no=1860&episode_no=15'
  const previousChapter = chapter.replace('episode_no=15', 'episode_no=14')
  const publicComic = publicId + ':' + work
  const publicUrl = 'https://www.webtoons.com/zh-hant/title/list?title_no=1860'
  const publicCover = 'https://images.example.test/covers/1860.jpg?width=300'
  const save = (reader, comicId, chapterId, pageIndex, totalPages, updatedAt) => reader.saveProgress({
    comicId, chapterId, pageIndex, totalPages, updatedAt, progressRatio: (pageIndex + 1) / totalPages, completed: false,
  })
  save(a.reader, publicComic, previousChapter, 2, 9, 100)
  save(a.reader, publicComic, chapter, 5, 11, 200)
  a.reader.saveSourceHistory({ comicId: publicComic, sourceId: publicId, mangaId: work, title: '普通書源',
    sourceName: 'WEBTOON', chapterId: chapter, chapterTitle: '第 15 話', mangaUrl: publicUrl, coverUri: publicCover })
  const removedWork = 'webtoon:cleared-history'
  const removedComic = publicId + ':' + removedWork
  save(a.reader, removedComic, previousChapter, 4, 10, 100)
  a.reader.saveSourceHistory({ comicId: removedComic, sourceId: publicId, mangaId: removedWork, title: 'Cleared history',
    chapterId: previousChapter })
  assert.equal(a.reader.removeHistoryEntries([removedComic]), true)
  assert.equal(a.reader.flush(), true)
  const connect = async device => {
    await device.engine.testConnection(f.draft)
    await device.engine.confirm((await device.engine.prepare(f.draft, ['reading'])).token, [])
  }
  await connect(a)
  await connect(b)
  const reviewSnapshot = await a.owner.snapshot('reading', true)
  const ordinarySnapshot = await a.owner.snapshot('reading', true, undefined, undefined, false)
  for (const field of ['values', 'revision', 'skipped', 'readingHistoryKeys', 'protectedKeys']) {
    assert.deepEqual(ordinarySnapshot[field], reviewSnapshot[field])
  }
  let cold = b.coldReader()
  assert.equal(cold.getSourceHistory(publicComic).mangaUrl, publicUrl)
  assert.equal(cold.getSourceHistory(publicComic).coverUri, publicCover)
  const publishedReader = new f.WriterWebDav(f.draft, [], undefined, A)
  const head = (await publishedReader.readManifest(noop)).own
  const coverRef = head.datasets.find(row => row.id === 'reading-cover-records')
  const readingRef = head.datasets.find(row => row.id === data.SYNC_READING_DATASET)
  assert.ok(coverRef && readingRef)
  for (const ref of readingRef.shards) {
    const body = await publishedReader.readObject(ref, noop)
    assert.equal(body.includes(publicCover), false)
  }
  assert.equal(cold.getProgress(publicComic).updatedAt, a.reader.getProgress(publicComic).updatedAt)
  assert.equal(cold.getProgress(publicComic).pageIndex, 5)
  assert.equal(cold.getChapterProgress(publicComic, previousChapter).pageIndex, 2)
  assert.equal(cold.getSourceHistory(removedComic), undefined)
  assert.equal(cold.getChapterProgress(removedComic, previousChapter).pageIndex, 4)
  // The previous app could save a page without a capture when its gate rejected the source.
  save(a.reader, publicComic, chapter, 7, 11, 250)
  assert.equal(a.reader.flush(), true)
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldReader().getChapterProgress(publicComic, chapter).pageIndex, 7)
  const loginWork = loginId + ':work-77'
  const loginChapter = 'chapter:work-77:2#第 2 話'
  const request = { comicId: loginWork, sourceId: loginId, mangaId: loginWork, chapterId: loginChapter,
    chapterIds: [loginChapter], chapterTitles: ['第 2 話'], title: 'Login work',
    mangaUrl: 'https://login.invalid/77?%2574oken=credential-sentinel' }
  assert.equal(a.runtime.openReading(request), 'ready')
  save(a.reader, loginWork, loginChapter, 6, 13, 300)
  a.runtime.observeReading(a.reader.getProgress(loginWork))
  assert.equal(a.reader.flush(), true)
  await a.runtime.recordPositions()
  await a.engine.syncNow()
  await b.engine.syncNow()
  cold = b.coldReader()
  assert.equal(cold.getSourceHistory(loginWork).chapterId, loginChapter)
  assert.equal(cold.getSourceHistory(loginWork).mangaUrl, undefined)
  assert.equal(cold.getChapterProgress(loginWork, loginChapter).pageIndex, 6)
  assert.equal(cold.openPageIndex({ comicId: loginWork, chapterId: loginChapter, totalPages: 13, pageUris: [] }, 'resume'), 6)
  assert.equal(b.runtime.openReading(request), 'missing')
  installedOnB.set(loginId, enabled)
  assert.equal(b.runtime.openReading(request), 'ready')
  assert.equal(b.runtime.validateReadingPages(loginWork, loginChapter, 13), true)
  assert.equal(b.runtime.validateReadingPages(loginWork, loginChapter, 12), false)
  assert.ok([...f.files.values()].every(body => !body.includes('credential-sentinel')))
  const puts = f.trace.filter(row => row.method === 'PUT').length
  await b.engine.syncNow()
  assert.equal(f.trace.filter(row => row.method === 'PUT').length, puts, 'receiving reading progress must not reupload it')
  assert.equal(a.reader.removeHistoryEntries([loginWork]), true)
  await a.runtime.recordPositions()
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldReader().getSourceHistory(loginWork), undefined)
  assert.equal(b.coldReader().getChapterProgress(loginWork, loginChapter).pageIndex, 6, 'removing history keeps the saved chapter position')
})

test('opaque chapter identities and ordinary titles are preserved across devices', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const sourceId = 'org.example.source'
  const work = 'work?key=series-123'
  const chapter = 'chapter?key=chapter-456'
  const comicId = sourceId + ':' + work
  const a = await readingDevice(fixture, A, new Map([[sourceId, { enabled: true, name: 'Example' }]]))
  const b = await readingDevice(fixture, B, new Map())
  a.reader.saveProgress({ comicId, chapterId: chapter, pageIndex: 4, totalPages: 11,
    updatedAt: 200, progressRatio: 5 / 11, completed: false })
  a.reader.saveSourceHistory({ comicId, sourceId, mangaId: work, chapterId: chapter,
    title: 'Token: a story', sourceName: 'Example', chapterTitle: 'Secret: chapter one',
    coverUri: 'http://192.168.1.4:8080/covers/example.jpg' })
  assert.equal(a.reader.flush(), true)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['reading'])).token, [])
  }
  const received = b.coldReader()
  assert.equal(received.getSourceHistory(comicId).title, 'Token: a story')
  assert.equal(received.getSourceHistory(comicId).chapterTitle, 'Secret: chapter one')
  assert.equal(received.getSourceHistory(comicId).coverUri, 'http://192.168.1.4:8080/covers/example.jpg')
  assert.equal(received.getChapterProgress(comicId, chapter).pageIndex, 4)
})

test('a local position missed by the old client survives an independent remote position on upgrade', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const source = 'org.example.newly-supported'
  const key = data.syncKey(['position', source, 'work:1', 'chapter:1'])
  const a = fixture.replica(A)
  const b = fixture.replica(B)
  for (const device of [a, b]) {
    await device.engine.testConnection(f.draft)
    await device.engine.confirm((await device.engine.prepare(f.draft, ['reading'])).token, [])
  }
  const local = JSON.stringify({ page: 5, total: 11, date: 100 })
  const remote = JSON.stringify({ page: 8, total: 11, date: 200 })
  a.values.set('reading', new Map([[key, local]]))
  b.values.set('reading', new Map([[key, remote]]))
  b.engine.recordEdits('reading', [{ key, kind: 'set', value: remote }])
  await b.engine.syncNow()
  await a.engine.syncNow()
  const merged = a.engine.active().groups.find(group => group.id === 'reading').facts.find(row => row.key === key)
  assert.deepEqual(new Set(facts.syncVisibleHeads(merged).map(head => head.value)), new Set([local, remote]))
  assert.equal(a.values.get('reading').get(key), remote)
})

test('an independent old chapter does not hold the observed current chapter and recent position', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.SharedWebDav)
  const a = fixture.replica(A)
  const b = fixture.replica(B)
  const identity = ['com.example.reader', 'work:1']
  const old = data.syncKey(['position', ...identity, 'chapter:4'])
  const current = data.syncKey(['position', ...identity, 'chapter:2'])
  const recent = data.syncKey(['recent', ...identity])
  const position = (page, date) => JSON.stringify({ page, date, total: 212 })
  const recentAt = (page, date) => JSON.stringify({
    chapter: 'chapter:2', title: 'Test', sourceName: 'Test', chapterTitle: 'Chapter 2', savedPage: page, date,
  })
  const save = (device, changes) => {
    const local = device.values.get('reading') ?? new Map()
    device.values.set('reading', local)
    for (const [key, value] of changes) local.set(key, value)
    device.engine.recordEdits('reading', changes.map(([key, value]) => ({ key, value, kind: 'set' })))
  }
  for (const device of [a, b]) {
    await device.engine.testConnection(f.draft)
    await device.engine.confirm((await device.engine.prepare(f.draft, ['reading'])).token, [])
  }
  save(b, [[current, position(119, 100)], [recent, recentAt(119, 100)]])
  await b.engine.syncNow()
  await a.engine.syncNow()
  assert.equal(a.values.get('reading').get(current), position(119, 100))
  save(a, [[old, position(27, 150)]])
  save(b, [[old, position(57, 200)]])
  await b.engine.syncNow()
  save(a, [[current, position(57, 300)], [recent, recentAt(57, 300)]])
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(a.values.get('reading').get(old), position(27, 150))
  assert.equal(b.values.get('reading').get(old), position(57, 200))
  assert.equal(b.values.get('reading').get(current), position(57, 300))
  assert.equal(b.values.get('reading').get(recent), recentAt(57, 300))
  const group = a.engine.active().groups.find(row => row.id === 'reading')
  assert.ok(group.deferred.includes(old))
  assert.ok(!group.deferred.includes(current) && !group.deferred.includes(recent))
})

test('shared sync migrates live legacy data, removes obsolete files, and updates one bucket', async () => {
  const f = transportFixture()
  const cached = new Map()
  const device = engineFixture(f.SharedWebDav, {
    async read(_scope, _group, id, ref) { return cached.get(id + ':' + ref.hash) },
    async write(_scope, _group, id, ref, body) { cached.set(id + ':' + ref.hash, body) },
  }).replica(A)
  const other = engineFixture(f.SharedWebDav).replica(B)
  const old = await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)
  const space = old.manifest?.space ?? new f.WriterWebDav(f.draft, [], undefined, A).spaceId()
  const legacy = wire.buildSyncDataset(data.SYNC_READER_SETTINGS_DATASET, [
    facts.applySyncEdit(facts.emptySyncFact(pageNumber), { version: { replica: B, sequence: 1 }, observed: [], kind: 'set', value: 'false' }),
  ], 1, undefined, data.syncBucketKey)
  const position = data.syncKey(['position', 'test.sync.source', 'work', 'chapter'])
  const oldPage = JSON.stringify({ page: 5, total: 9, pageTable: 'a'.repeat(64) })
  const reading = dataset(data.SYNC_READING_DATASET, position, C, oldPage)
  for (const object of legacy.objects.concat(reading.objects)) f.seedObject(object)
  f.seedCommit({ ...wire.newSyncManifest(space), revision: 1, datasets: [legacy.ref, reading.ref] })
  for (let i = 0; i < 1000; i++) f.files.set(f.root + 'object-1-' + i.toString(16).padStart(64, '0') + '.json', '{}')
  f.files.set(f.draft.directory + '/unrelated.json', 'untouched')
  const connect = async (row, contents) => {
    await row.engine.testConnection(f.draft)
    const preview = await row.engine.prepare(f.draft, contents)
    await row.engine.confirm(preview.token, [])
  }
  await connect(device, ['reader-settings'])
  const shared = f.sharedRoot
  const headPath = shared + 'heads/'
  const headFiles = () => [...f.files.keys()].filter(name => name.startsWith(headPath))
  const reader = new f.SharedWebDav(f.draft)
  for (let attempt = 0; attempt < 100 && (f.directories.has(f.root) ||
    (await reader.readSharedHead(noop)).manifest?.legacyMigration); attempt++) await new Promise(setImmediate)
  assert.equal(device.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(device.values.has('reading'), false)
  assert.equal([...f.files.keys()].filter(name => name.startsWith(f.root)).length, 0)
  assert.equal(f.files.get(f.draft.directory + '/unrelated.json'), 'untouched')
  await connect(other, ['reader-settings', 'reading'])
  assert.equal(other.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(other.values.get('reading').get(position), oldPage)
  for (const value of ['true', 'false', 'true']) {
    f.trace.length = 0
    device.values.get('reader-settings').set(pageNumber, value)
    await device.engine.syncNow()
    assert.equal(f.trace.filter(row => row.method === 'PUT').length, 2)
    assert.ok(f.trace.every(row => row.address.startsWith(shared)))
    assert.equal(headFiles().length, 1)
  }
  await other.engine.syncNow()
  assert.equal(other.values.get('reader-settings').get(pageNumber), 'true')
  // Delay the first writer after its final base check. The second writer
  // commits against the same base and succeeds before the first PUT arrives.
  let waiting
  let release
  const firstSent = new Promise(resolve => { waiting = resolve })
  const gate = new Promise(resolve => { release = resolve })
  let blocked = false
  f.onRequest(async (method, address) => {
    if (method !== 'PUT' || !address.startsWith(headPath) || blocked) return
    blocked = true
    waiting()
    await gate
  })
  device.values.get('reader-settings').set(pageNumber, 'false')
  other.values.get('reader-settings').set(animation, 'false')
  const first = device.engine.syncNow()
  await firstSent
  try { await other.engine.syncNow() } finally { release() }
  await first
  f.onRequest(async () => {})
  assert.equal(headFiles().length, 2)
  const concurrent = await reader.readSharedHead(noop)
  for (const dataset of concurrent.manifest.datasets.concat(concurrent.manifest.alternatives ?? [])) {
    for (const shard of dataset.shards) await reader.readSharedObject(dataset.id, shard, noop)
  }
  await device.restart().syncNow()
  await other.engine.syncNow()
  assert.equal(other.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(device.values.get('reader-settings').get(animation), 'false')
  assert.equal(other.values.get('reading').get(position), oldPage)
  assert.equal(headFiles().length, 1)

  const blobs = () => [...f.files.keys()].filter(name => name.startsWith(shared) && !name.startsWith(headPath))
  assert.ok(blobs().length > 2)
  const clock = global.performance
  try {
    global.performance = { now: () => clock.now() + 121000 }
    reader.scheduleSharedCollection(noop)
    for (let attempt = 0; attempt < 20; attempt++) await new Promise(setImmediate)
    assert.ok(blobs().length > 2)
    global.performance = { now: () => clock.now() + 242000 }
    reader.scheduleSharedCollection(noop)
    for (let attempt = 0; attempt < 100 && blobs().length > 2; attempt++) await new Promise(setImmediate)
    assert.equal(blobs().length, 2)
  } finally { global.performance = clock }
})

test('automatic shared sync repairs missing and damaged objects from exact cached bytes', async () => {
  let now = 1
  const f = transportFixture('https://local-fixture.invalid/automatic-repair', () => now)
  const cached = new Map()
  const cacheKey = (scope, group, id, ref) => JSON.stringify([scope, group, id, ref.hash])
  const cachePort = {
    async read(scope, group, id, ref) { return cached.get(cacheKey(scope, group, id, ref)) },
    async write(scope, group, id, ref, body) { cached.set(cacheKey(scope, group, id, ref), body) },
  }
  const position = data.syncKey(['position', 'org.example.source', 'work', 'chapter'])
  const chapterPage = JSON.stringify({ page: 1, total: 8 })
  const book = data.syncKey(['book', 'org.example.source', 'work'])
  const label = JSON.stringify({ title: 'Shelf work', sourceName: 'Source' })
  const holder = engineFixture(f.SharedWebDav, cachePort).replica(A, [
    ['shelf', new Map([[book, label]])],
    ['reading', new Map([[position, chapterPage]])],
    ['reader-settings', new Map([[pageNumber, 'false']])],
  ])
  holder.engine.setSelection(['shelf', 'reading', 'reader-settings'])
  await holder.engine.saveConfiguration(f.draft)
  holder.engine.setEnabled(true)
  await holder.engine.syncNow()
  holder.engine.setSelection(['shelf', 'reader-settings'])
  await holder.engine.syncNow()

  const provider = new f.SharedWebDav(f.draft)
  const remote = await provider.readSharedHead(noop)
  const locate = id => {
    const ref = remote.manifest.datasets.find(row => row.id === id).shards[0]
    const address = f.sharedRoot + id + '-' + ref.bucket + '-' + ref.hash + '-' + ref.immutable + '.json'
    const body = f.files.get(address)
    assert.equal(wire.syncDigest(body), ref.hash)
    return { address, ref, body }
  }
  const shelf = locate(data.SYNC_SHELF_CATALOG_DATASET)
  const preferences = locate(data.SYNC_READER_SETTINGS_DATASET)
  const reading = locate(data.SYNC_READING_DATASET)
  const preferencesCache = cacheKey(provider.cacheScope(), 'reader-settings', data.SYNC_READER_SETTINGS_DATASET, preferences.ref)
  const invalid = 'x'.repeat(preferences.ref.bytes)
  assert.equal(cached.get(preferencesCache), preferences.body)
  cached.set(preferencesCache, invalid)
  f.files.delete(shelf.address)
  f.files.delete(reading.address)
  f.files.set(preferences.address, invalid)

  const receiver = engineFixture(f.SharedWebDav).replica(B)
  receiver.engine.setSelection(['shelf', 'reader-settings'])
  await receiver.engine.saveConfiguration(f.draft)
  receiver.engine.setEnabled(true)
  await assert.rejects(receiver.engine.syncNow(), /sync_shard_missing/)

  const writes = () => f.trace.filter(entry => entry.method === 'PUT')
  const drain = async () => { for (let i = 0; i < 80; i++) await new Promise(setImmediate) }
  f.trace.length = 0
  await holder.engine.syncNow(true)
  assert.deepEqual(f.trace.map(entry => entry.method), ['PROPFIND'])
  now += 60001
  await holder.engine.syncNow(true)
  await drain()
  assert.deepEqual(writes().map(entry => [entry.address, entry.body]), [[shelf.address, shelf.body]])
  assert.equal(f.files.get(preferences.address), invalid)

  cached.set(preferencesCache, preferences.body)
  now += 60001
  await holder.engine.syncNow(true)
  await drain()
  assert.deepEqual(writes().map(entry => [entry.address, entry.body]), [
    [shelf.address, shelf.body], [preferences.address, preferences.body],
  ])
  assert.equal(f.files.has(reading.address), false)
  assert.equal((await provider.readSharedHead(noop)).hash, remote.hash)
  await receiver.engine.syncNow()
  assert.equal(receiver.values.get('shelf').get(book), label)
  assert.equal(receiver.values.get('reader-settings').get(pageNumber), 'false')

  // An independent device publishes a newer shelf after the probe starts.
  // The old immutable address must never be restored once that newer head
  // has stopped referencing it.
  f.trace.length = 0
  f.files.delete(shelf.address)
  const changed = JSON.stringify({ title: 'Updated shelf work', sourceName: 'Source' })
  let replaced = false
  f.onRequest(async (method, address) => {
    if (method !== 'GET' || address !== shelf.address || replaced) return
    replaced = true
    receiver.values.get('shelf').set(book, changed)
    receiver.engine.recordEdits('shelf', [{ key: book, kind: 'set', value: changed }])
    await receiver.engine.syncNow()
  })
  now += 60001
  await holder.engine.syncNow(true)
  await drain()
  assert.equal(replaced, true)
  assert.equal(writes().some(entry => entry.address === shelf.address), false)
  assert.equal(f.files.has(shelf.address), false)
  assert.notEqual((await provider.readSharedHead(noop)).hash, remote.hash)
})

test('independent writer publications receive chapter and page without shared conditional writes', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const a = fixture.replica(A)
  const b = fixture.replica(B)
  const source = 'org.mangadex.koma'
  const work = 'mdx:11111111-1111-1111-1111-111111111111'
  const chapter = 'ch:22222222-2222-2222-2222-222222222222'
  const recent = data.syncKey(['recent', source, work])
  const position = data.syncKey(['position', source, work, chapter])
  const chapterValue = JSON.stringify({ title: 'Public work', sourceName: 'MangaDex', sourceVersion: '0.1.25',
    chapter, chapterTitle: 'Chapter', date: 123 })
  const pageValue = JSON.stringify({ page: 5, total: 9, pageTable: 'a'.repeat(64) })
  const connect = async replica => {
    await replica.engine.testConnection(f.draft)
    const preview = await replica.engine.prepare(f.draft, ['reading', 'reader-settings'])
    await replica.engine.confirm(preview.token, [])
  }
  await connect(a)
  await connect(b)
  a.values.get('reading').set(recent, chapterValue)
  a.values.get('reading').set(position, pageValue)
  a.engine.recordEdits('reading', [{ key: recent, kind: 'set', value: chapterValue },
    { key: position, kind: 'set', value: pageValue }])
  b.values.get('reader-settings').set(pageNumber, 'false')
  await Promise.all([a.engine.syncNow(), b.engine.syncNow()])
  await b.engine.syncNow()
  assert.equal(b.values.get('reading').get(recent), chapterValue)
  assert.equal(b.values.get('reading').get(position), pageValue)
  await a.engine.syncNow()
  assert.equal(a.values.get('reader-settings').get(pageNumber), 'false')
  const own = await new f.WriterWebDav(f.draft, [], undefined, B).readManifest(noop)
  assert.equal(own.own.datasets.some(row => row.id === data.SYNC_READING_DATASET), false)
  assert.equal(f.trace.some(row => row.method === 'PUT' &&
    ('If-Match' in row.headers || 'If-None-Match' in row.headers)), false)
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))), false)
})

test('a missing submitted shard is replanned automatically without losing reading progress', async () => {
  const f = transportFixture()
  const oldWriter = new f.WriterWebDav(f.draft, [], undefined, C)
  const legacy = dataset('reading', data.syncKey(['position', 'com.xkcd.zh.koma', 'xkcd:zh', 'xkcdch:zh:1']),
    C, JSON.stringify({ page: 1, total: 3, pageTable: 'a'.repeat(64) }))
  for (const object of legacy.objects) await oldWriter.storeObject(object, noop)
  await oldWriter.publish(manifest(oldWriter.spaceId(), [legacy.ref]), '', noop, noop, ['reading'])
  const writer = engineFixture(f.WriterWebDav).replica(A)
  await writer.engine.testConnection(f.draft)
  await writer.engine.confirm((await writer.engine.prepare(f.draft, ['reading'])).token, [])
  const key = data.syncKey(['position', 'org.example.login-required', 'work:77', 'chapter:77:2'])
  const value = JSON.stringify({ page: 5, total: 9, date: 123 })
  writer.values.get('reading').set(key, value)
  const version = writer.engine.recordEdits('reading', [{ key, kind: 'set', value }])
  f.faults.push('before-accept')
  await assert.rejects(writer.engine.syncNow())
  const intent = writer.store.load().intent
  assert.ok(intent?.sent)
  const shard = JSON.parse(intent.commitBody).manifest.datasets.find(row => row.id === data.SYNC_READING_DATASET).shards[0]
  const address = f.writerObject(A, shard)
  const bytes = f.files.get(address)
  assert.ok(bytes)
  f.files.delete(address)
  await writer.restart().syncNow()
  assert.equal(writer.store.load().active.groups[0].pending.length, 0)
  // The timed-out original request can still arrive after the replacement.
  // Its older revision must not roll the recovered reading position back.
  f.files.set(f.draft.directory + '/koma-device-sync-v4/' + intent.commit.substring(3), intent.commitBody)
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  const remote = (await reader.readManifest(noop)).manifest
  assert.equal(wire.syncDatasetBranches(remote, 'reading').length, 1)
  assert.equal(wire.syncDatasetBranches(remote, data.SYNC_READING_DATASET).length, 1)
  const newRef = wire.syncDatasetBranches(remote, data.SYNC_READING_DATASET)[0].shards[0]
  const received = await reader.readObject(newRef, noop)
  assert.ok(received.includes('org.example.login-required'))
  assert.ok(received.includes('\\"page\\":5'))
  assert.ok(writer.store.load().counter >= version.sequence)
})

test('an empty next segment preserves the last complete publication on a fresh client', async () => {
  const f = transportFixture()
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const ref = dataset('reader-settings', pageNumber, A, 'false')
  for (const object of ref.objects) await writer.storeObject(object, noop)
  const last = manifest(writer.spaceId(), [ref.ref], 128)
  await writer.publish(last, '', noop, noop, ['reader-settings'])
  f.directories.add(f.writerRootV4 + A + '/00000000000001/')
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  assert.equal((await reader.readManifest(noop)).manifest.revision, 128)
})

test('a broken cover shard does not stop reading or get replaced by a retry', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const source = 'org.example.login-required', work = 'work:77'
  const position = data.syncKey(['position', source, work, 'chapter:77:2'])
  const cover = data.syncKey(['cover', source, work])
  const url = 'https://images.example.test/covers/77.jpg'
  const first = JSON.stringify({ page: 2, total: 9, date: 100 })
  const latest = JSON.stringify({ page: 5, total: 9, date: 200 })
  const a = fixture.replica(A, [['reading', new Map([[position, first], [cover, JSON.stringify(url)]])]])
  const b = fixture.replica(B)
  for (const device of [a, b]) {
    device.engine.setSelection(['reading'])
    await device.engine.saveConfiguration(f.draft)
    device.engine.setEnabled(true)
    await device.engine.syncNow()
  }
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const coverRef = (await writer.readManifest(noop)).own.datasets.find(row => row.id === 'reading-cover-records')
  const address = f.writerObject(A, coverRef.shards[0])
  const bytes = f.files.get(address)
  assert.ok(bytes)
  f.files.delete(address)
  a.values.get('reading').set(position, latest)
  a.engine.recordEdits('reading', [{ key: position, kind: 'set', value: latest }])
  f.faults.push('lost-response')
  await assert.rejects(a.engine.syncNow())
  await a.restart().syncNow()
  await b.restart().syncNow()
  assert.equal(b.values.get('reading').get(position), latest)
  assert.equal(b.values.get('reading').get(cover), JSON.stringify(url))
  assert.deepEqual((await writer.readManifest(noop)).own.datasets.find(row => row.id === coverRef.id), coverRef)
  assert.equal(f.files.has(address), false)
  f.files.set(address, bytes)
  const c = fixture.replica(C)
  c.engine.setSelection(['reading'])
  await c.engine.saveConfiguration(f.draft)
  c.engine.setEnabled(true)
  await c.engine.syncNow()
  assert.equal(c.values.get('reading').get(position), latest)
  assert.equal(c.values.get('reading').get(cover), JSON.stringify(url))
})

test('upgrading without local edits preserves legacy facts in a writer publication', async () => {
  const f = transportFixture()
  const v2 = f.provider()
  const old = dataset('reader-settings', pageNumber, A, 'false')
  for (const object of old.objects) f.seedObject(object)
  const oldName = f.seedCommit(manifest(v2.spaceId(), [old.ref]))
  const reader = engineFixture(f.WriterWebDav).replica(B)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  const current = await new f.WriterWebDav(f.draft, [], undefined, B).readManifest(noop)
  assert.equal(current.own.datasets[0].id, data.SYNC_READER_SETTINGS_DATASET)
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))), false)
  f.files.delete(f.root + oldName)
  reader.values.get('reader-settings').set(pageNumber, 'true')
  await assert.rejects(reader.engine.syncNow(), /sync_legacy_unavailable/)
  const reopened = await new f.WriterWebDav(f.draft, reader.engine.active().frontier, undefined, B).readManifest(noop)
  assert.equal(reopened.warning, 'sync_legacy_unavailable')
  const ref = reopened.own.datasets.find(row => row.id === data.SYNC_READER_SETTINGS_DATASET)
  const values = (await Promise.all(ref.shards.map(async shard => wire.decodeSyncShard(ref.id, shard,
    await new f.WriterWebDav(f.draft, [], undefined, B).readObject(shard, noop), data.syncBucketKey)))).flat()
  assert.equal(facts.syncVisibleValue(values.find(row => row.key === pageNumber)), 'true')
})

test('connection test and first sync accept a missing old ancestor without ETag support', async () => {
  const f = transportFixture()
  f.directories.clear()
  const heads = f.sharedRoot + 'heads/'
  const legacy = f.legacy + 'manifest.json'
  f.responseStatus((method, address) => method === 'GET' && address === legacy ?
    response(409, '<?xml version="1.0"?><d:error><s:exception>AncestorsNotFound</s:exception></d:error>') : undefined)
  const replica = engineFixture(f.SharedWebDav).replica(A,
    [['reader-settings', new Map([[pageNumber, 'true']])]])
  replica.engine.setSelection(['reader-settings'])
  await replica.engine.testConnection(f.draft)
  assert.deepEqual(f.trace.filter(row => row.method === 'MKCOL').map(row => row.address),
    [f.draft.directory + '/', f.sharedRoot, heads])
  const writes = f.trace.filter(row => row.method === 'PUT').map(row => row.address)
  const probeName = writes[0]?.slice(f.sharedRoot.length)
  assert.match(probeName, /^probe-[0-9a-f-]{36}\.json$/)
  assert.deepEqual(writes, [f.sharedRoot + probeName, heads + probeName])
  assert.ok(f.trace.some(row => row.method === 'GET' && row.address === legacy))
  assert.equal(f.files.size, 0)
  assert.equal(replica.store.load().probes.length, 0)
  await replica.engine.saveConfiguration(f.draft)
  assert.equal(f.files.size, 0)
  replica.engine.setEnabled(true)
  await replica.engine.syncNow()
  const remote = await new f.SharedWebDav(f.draft).readSyncState(noop)
  assert.equal(remote.sharedHeads.length, 1)
  assert.equal(remote.manifest.datasets[0].id, data.SYNC_READER_SETTINGS_DATASET)
  assert.equal(f.trace.some(row => row.method === 'LOCK'), false)
})

test('an unrelated 409 still blocks both the connection test and sync discovery', async () => {
  const f = transportFixture()
  f.responseStatus((method, address) => method === 'GET' && address === f.legacy + 'manifest.json' ?
    response(409, '<d:error><s:exception>Conflict</s:exception></d:error>') : undefined)
  const provider = new f.SharedWebDav(f.draft, [], undefined, A)
  await assert.rejects(provider.probe(A, noop), /sync_server_http_409/)
  await assert.rejects(provider.readSyncState(noop), /sync_server_http_409/)
  assert.equal(f.trace.some(row => row.method === 'PUT'), false)
})

test('a new Nutstore root connection tests, saves and syncs in the same Koma folder', async () => {
  const root = 'https://dav.jianguoyun.com/dav'
  const f = transportFixture(root + '/Koma')
  f.directories.clear()
  f.directories.add(root + '/')
  const { replica } = engineFixture(f.SharedWebDav)
  const writer = replica(A, [['reader-settings', new Map([[pageNumber, 'true']])]])
  writer.engine.setSelection(['reader-settings'])
  const draft = { ...f.draft, directory: root }

  // Nutstore returns 409 when the top-level sync collection is absent.
  f.responseStatus((method, address) =>
    method === 'PROPFIND' && address === root + '/koma-device-sync-v5/heads/' ?
      response(409, '<d:error><s:exception>AncestorsNotFound</s:exception></d:error>') : undefined)
  await assert.rejects(new f.SharedWebDav(draft).readSyncState(noop), /sync_server_http_409/)
  f.trace.length = 0

  await writer.engine.testConnection(draft)
  assert.deepEqual(f.trace.filter(row => row.method === 'MKCOL').map(row => row.address),
    [f.draft.directory + '/', f.sharedRoot, f.sharedRoot + 'heads/'])
  assert.equal(f.files.size, 0)
  const testedRequests = f.trace.length
  await writer.engine.saveConfiguration(draft)
  assert.equal(f.trace.length, testedRequests)
  const reopened = writer.restart()
  assert.deepEqual(await reopened.connectionDraft(), f.draft)
  reopened.setEnabled(true)
  await reopened.syncNow()

  const reader = replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  await reader.engine.syncNow()
  assert.equal(reader.values.get('reader-settings')?.get(pageNumber), 'true')
  assert.ok(f.trace.every(row => row.address.startsWith(f.draft.directory + '/')))
})

test('Nutstore credential edits preserve existing root and explicit subdirectory connections', async () => {
  const root = 'https://dav.jianguoyun.com/dav'
  for (const directory of [root, root + '/Existing']) {
    const f = transportFixture(directory)
    const { replica, assets } = engineFixture(f.SharedWebDav)
    const { engine, store } = replica(A)
    const credential = randomUUID()
    const original = { ...f.draft, username: 'reader@example.test', password: 'old' }
    const endpointIdentity = wire.syncDigest(JSON.stringify([original.directory, original.username]))
    assets.set(credential, original)
    store.update(state => {
      state.pendingConfiguration = { credential, endpointIdentity, selected: ['reader-settings'], automatic: false, enabled: false }
    })

    const changed = { ...original, password: 'new' }
    await engine.saveConfiguration(changed)
    assert.deepEqual(await engine.connectionDraft(), changed)
    assert.equal(engine.configuration().endpointIdentity, endpointIdentity)
    assert.equal(engine.configuration().automatic, false)
    assert.ok(f.trace.some(row => row.method === 'PUT'))
    assert.ok(f.trace.every(row => row.address.startsWith(directory + '/') &&
      !row.address.startsWith(directory + '/Koma/')))
  }
})

test('a failed head probe is reported and a later cleanup removes a probe left in heads', async () => {
  const f = transportFixture()
  const provider = new f.SharedWebDav(f.draft, [], undefined, A)
  const heads = f.sharedRoot + 'heads/'
  const headProbe = heads + 'probe-' + A + '.json'
  f.responseStatus((method, address) => method === 'PUT' && address === headProbe ? 403 : undefined)
  await assert.rejects(provider.probe(A, noop), /sync_permission_denied/)
  assert.equal(f.files.size, 0)

  f.responseStatus((method, address) => method === 'DELETE' && address === headProbe ? 403 : undefined)
  assert.equal(await provider.probe(A, noop), false)
  assert.deepEqual([...f.files.keys()], [headProbe])
  f.responseStatus(() => undefined)
  await provider.cleanProbe(A, noop, false, 5, true)
  assert.equal(f.files.size, 0)
})

test('a LAN HTTP WebDAV directory completes connection and probe cleanup', async () => {
  const f = transportFixture('http://192.168.1.4:8080/dav')
  f.directories.clear()
  const id = '11111111-1111-1111-1111-111111111111'
  await f.provider().probe(id, noop)
  assert.deepEqual(f.trace.filter(row => row.method === 'MKCOL').map(row => row.address),
    [f.draft.directory + '/', f.sharedRoot, f.sharedRoot + 'heads/'])
  assert.ok(f.trace.some(row => row.method === 'PUT' && row.address.startsWith('http://')))
  assert.equal(f.files.has(f.sharedRoot + 'probe-' + id + '.json'), false)
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
    const ref = wire.syncDatasetBranches(current.manifest, data.SYNC_READER_SETTINGS_DATASET)[0]
    const values = ref.shards.flatMap(shard => wire.decodeSyncShard(ref.id, shard,
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
  const runtime = runtimeFixture()
  runtime.engine = reader.engine
  runtime.storage = reader.store
  runtime.refresh()
  reader.values.get('reader-settings').set(pageNumber, 'false')
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const resumed = new Promise(resolve => { release = resolve })
  f.onCommit(async () => { enter(); await resumed })
  const pending = runtime.sync()
  const rejected = assert.rejects(pending, /sync_connection_changed/)
  await entered
  const name = reader.store.load().intent.commit
  await runtime.disconnect()
  assert.equal(runtime.view.configured, false)
  assert.equal(runtime.view.error, '')
  release()
  await rejected
  assert.equal(runtime.view.error, '', 'the rejected old task must not publish an error into the disconnected service')
  assert.equal(runtime.view.busy, false)
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

test('a first automatic connection retries local application without losing the received fact', async () => {
  const f = transportFixture(), provider = f.provider()
  const remote = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of remote.objects) f.seedObject(object)
  f.seedCommit(manifest(provider.spaceId(), [remote.ref]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  const owner = reader.engine.owner
  const commit = owner.commit.bind(owner)
  let fail = true
  owner.commit = async (...args) => {
    if (fail) { fail = false; throw new Error('synthetic_owner_boundary') }
    return commit(...args)
  }
  await assert.rejects(reader.engine.syncNow(), /synthetic_owner_boundary/)
  assert.equal(reader.engine.active(), undefined)
  await reader.engine.syncNow()
  assert.ok(reader.engine.active(), 'automatic retry must finish the previously interrupted receive')
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'true')
})

test('service pause preserves scope and capture dots, blocks sync traffic, and is local to one engine', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.DeviceSyncWebDav)
  const source = 'org.mangadex.koma'
  const work = 'mdx:11111111-1111-1111-1111-111111111111'
  const chapter = 'ch:22222222-2222-2222-2222-222222222222'
  const positionKey = data.syncKey(['position', source, work, chapter])
  const value = JSON.stringify({ page: 1, total: 8, pageTable: 'a'.repeat(64) })
  const left = fixture.replica(A, [['reader-settings', new Map([[pageNumber, 'true']])],
    ['reading', new Map([[positionKey, value]])]])
  const right = fixture.replica(B)
  for (const replica of [left, right]) {
    await replica.engine.testConnection(f.draft)
    await replica.engine.confirm((await replica.engine.prepare(f.draft, ['reading', 'reader-settings'])).token, [])
  }
  left.store.update(state => { delete state.active.enabled })
  assert.equal(left.engine.isEnabled(), true, 'legacy credentials default to enabled')
  left.engine.setAutomatic(true)
  const before = clone(left.engine.active())
  const scope = left.engine.readingScope()
  const stale = await left.engine.prepare(f.draft, ['reading', 'reader-settings'])
  left.engine.setEnabled(false)
  assert.equal(left.engine.isEnabled(), false)
  assert.equal(left.engine.active().credential, before.credential)
  assert.deepEqual(left.engine.selection(), before.selected)
  assert.equal(left.engine.active().automatic, true)
  assert.equal(left.engine.readingScope(), scope)
  const requests = f.trace.length
  await assert.rejects(left.engine.syncNow(), /disabled|paused/)
  await assert.rejects(left.engine.prepare(f.draft, ['reading']), /disabled|paused/)
  await assert.rejects(left.engine.confirm(stale.token, []), /disabled|paused|preview_changed|connection_changed/)
  await left.engine.recoverOnForeground()
  assert.equal(f.trace.length, requests)
  left.values.get('reading').delete(positionKey)
  const captured = left.engine.recordEdits('reading', [{ key: positionKey, kind: 'delete', value: '' }])
  assert.ok(captured)
  assert.equal(f.trace.length, requests)
  right.values.get('reader-settings').set(pageNumber, 'false')
  await right.engine.syncNow()
  assert.equal(right.engine.isEnabled(), true)
  assert.equal(left.values.get('reader-settings').get(pageNumber), 'true')
  left.engine.setEnabled(true)
  await left.engine.syncNow()
  assert.equal(left.values.get('reader-settings').get(pageNumber), 'false')
  const remote = await f.provider().readManifest(noop)
  const refs = wire.syncDatasetBranches(remote.manifest, data.SYNC_READING_DATASET)
  const stored = refs.flatMap(ref => ref.shards.flatMap(shard => wire.decodeSyncShard(ref.id, shard,
    f.files.get(f.root + wire.syncShardPath(shard)), data.syncBucketKey))).find(fact => fact.key === positionKey)
  assert.deepEqual(stored.barriers.find(edit => edit.kind === 'delete').version, captured)
  const reread = JSON.stringify({ page: 0, total: 8, date: 500 })
  left.values.get('reading').set(positionKey, reread)
  const staged = left.engine.recordEdits('reading', [{ key: positionKey, kind: 'set', value: reread }])
  assert.ok(staged)
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const gate = new Promise(resolve => { release = resolve })
  const snapshot = left.engine.owner.snapshot.bind(left.engine.owner)
  left.engine.owner.snapshot = async (...args) => { enter(); await gate; return snapshot(...args) }
  const cancelled = assert.rejects(left.engine.syncNow(), /connection_changed|disabled|paused/)
  await entered
  left.engine.setEnabled(false)
  release()
  await cancelled
  assert.equal(left.engine.readingWritePending(staged), true)
  left.engine.setEnabled(true)
  await left.engine.syncNow()
  await right.engine.syncNow()
  assert.equal(right.values.get('reading').get(positionKey), reread)
})

test('pause invalidates an in-flight callback but keeps its intent for enabled recovery', async () => {
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
  const rejected = assert.rejects(pending, /connection_changed|disabled|paused/)
  await entered
  reader.engine.setEnabled(false)
  const name = reader.store.load().intent.commit
  release()
  await rejected
  assert.equal(reader.engine.isEnabled(), false)
  assert.ok(reader.store.load().intent)
  assert.notEqual(reader.store.load().intent.detached, true)
  const requests = f.trace.length
  await reader.engine.recoverOnForeground()
  assert.equal(f.trace.length, requests)
  assert.equal(await reader.engine.testConnection(f.draft, ['reader-settings']), false)
  assert.ok(reader.store.load().intent, 'a synthetic probe must not consume the paused receipt')
  assert.equal(reader.engine.isEnabled(), false)
  f.onCommit(async () => {})
  reader.engine.setAutomatic(true)
  reader.engine.setEnabled(true)
  await reader.engine.recoverOnForeground()
  assert.equal(reader.engine.isEnabled(), true, 'the old intent must preserve the latest service switch')
  assert.equal(reader.engine.active().automatic, true, 'receipt recovery must keep the latest automatic preference')
  assert.equal(reader.store.load().intent, undefined)
  assert.equal(f.files.has(f.root + name), true)
  assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address === f.root + name).length, 1)
})

test('paused runtime keeps Reader clears and bookmarks local until enabled', async () => {
  const f = transportFixture()
  const source = 'org.example.login', work = 'account-work:42'
  const comicId = source + ':' + work
  const recentKey = data.syncKey(['recent', source, work])
  const chapter = 'chapter:42:2'
  const recent = JSON.stringify(data.syncReadingRecent(source, chapter, 123, 'Work', source, 'Chapter', 4))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A, [['reading', new Map([[recentKey, recent]])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reading'])).token, [])
  const signals = compile('DeviceSyncSignals')
  const runtime = runtimeFixture({ './DeviceSyncSignals': signals,
    '@kit.ArkTS': { util: { generateRandomUUID: require('node:crypto').randomUUID } } })
  runtime.engine = reader.engine
  runtime.storage = reader.store
  runtime.owners = {
    receivedSubscriptions: () => [], readingAcknowledged: () => false,
    sourceIdentity: id => id === comicId ? { source, work } : undefined,
    readingActionAcknowledged: capture => !!runtime.owners.readingActionReceipt(capture),
    readingActionReceipt: capture => reader.store.load().readingReceipts?.find(row => row.key === signals.deviceSyncActionCaptureKey(capture)),
  }
  runtime.refresh()
  let fired = false
  runtime.timer = setTimeout(() => { fired = true }, 30)
  runtime.timer.unref()
  runtime.setEnabled(false)
  const scope = reader.engine.readingScope()
  const captures = runtime.stageReaderActions([
    { comicId, chapterId: '', kind: 'clear-history' },
    { comicId, chapterId: chapter, kind: 'bookmark' },
  ])
  assert.equal(captures.length, 2)
  const requests = f.trace.length
  await runtime.recordReaderActions(captures, scope)
  assert.equal(reader.engine.knownReadingValue(recentKey), undefined)
  assert.equal(reader.engine.active().groups[0].pending.length, 2)
  assert.equal(f.trace.length, requests)
  await new Promise(resolve => setTimeout(resolve, 50))
  assert.equal(fired, false)
  runtime.setEnabled(true)
  await reader.engine.syncNow()
  assert.equal(reader.engine.active().groups[0].pending.length, 0)
})

test('disconnect removes this engine probe credentials while pause and another engine keep theirs', async () => {
  const fixture = engineFixture()
  const left = fixture.replica(A), right = fixture.replica(B)
  for (const replica of [left, right]) {
    await replica.engine.testConnection(fixture.draft)
    await replica.engine.confirm((await replica.engine.prepare(fixture.draft, ['reader-settings'])).token, [])
  }
  const leftCredential = left.engine.active().credential
  const rightCredential = right.engine.active().credential
  const leftProbe = '11111111-1111-1111-1111-111111111111'
  const rightProbe = '22222222-2222-2222-2222-222222222222'
  fixture.assets.set(leftProbe, clone(fixture.draft))
  fixture.assets.set(rightProbe, clone(fixture.draft))
  left.store.update(state => { state.probes.push({ credential: leftProbe, id: C, collection: 2 }) })
  right.store.update(state => { state.probes.push({ credential: rightProbe, id: C, collection: 2 }) })
  const before = clone(left.store.load())
  left.engine.setEnabled(false)
  assert.equal(fixture.assets.has(leftCredential), true)
  assert.equal(fixture.assets.has(leftProbe), true)
  await left.engine.disconnect()
  assert.deepEqual(left.store.load().probes, [])
  assert.equal(fixture.assets.has(leftCredential), false)
  assert.equal(fixture.assets.has(leftProbe), false)
  assert.equal(left.store.load().replica, before.replica)
  assert.equal(left.store.load().counter, before.counter)
  assert.equal(fixture.assets.has(rightCredential), true)
  assert.equal(fixture.assets.has(rightProbe), true)
  assert.equal(right.store.load().probes.length, 1)
  assert.equal(right.engine.isEnabled(), true)
})
