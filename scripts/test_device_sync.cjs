const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const { createHash, randomUUID } = require('node:crypto')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const root = path.resolve(__dirname, '../entry/src/main/ets/deviceSync')
function compile(file, ports = {}, globals = {}) {
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8')
  const compiled = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  const exports = {}
  new Function('require', 'exports', ...Object.keys(globals), compiled)(key => {
    assert.ok(Object.hasOwn(ports, key), `Unexpected import ${key}`)
    return ports[key]
  }, exports, ...Object.values(globals))
  return exports
}

const facts = compile('DeviceSyncFacts')
const metrics = compile('DeviceSyncMetrics', { '@kit.BasicServicesKit': {
  systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => performance.now() },
} })
const wire = compile('DeviceSyncWire', {
  './DeviceSyncFacts': facts,
  '@kit.ArkTS': { util: { generateRandomUUID: randomUUID, TextEncoder: class { encodeInto(text) { return Buffer.from(text) } } } },
  '@kit.CryptoArchitectureKit': {
    cryptoFramework: { createMd: () => {
      const digest = createHash('sha256')
      return { updateSync: ({ data }) => digest.update(data), digestSync: () => ({ data: digest.digest() }) }
    } },
  },
})
const data = compile('DeviceSyncData', {
  './DeviceSyncFacts': facts, './DeviceSyncWire': wire, './DeviceSyncCaseFold': compile('DeviceSyncCaseFold'),
})
const journal = compile('DeviceSyncJournal', { './DeviceSyncWire': wire })
const A = '10000000-0000-0000-0000-000000000000'
const B = 'f0000000-0000-0000-0000-000000000000'
const C = '20000000-0000-0000-0000-000000000000'
const position = page => JSON.stringify({ page, total: 8, pageTable: 'a'.repeat(64) })
const key = data.syncKey(['position', 'org.mangadex.koma',
  'mdx:11111111-1111-1111-1111-111111111111', 'ch:22222222-2222-2222-2222-222222222222'])
const dot = (replica, sequence) => ({ replica, sequence })
function edit(fact, version, kind, value, observed = fact.seen) {
  return facts.applySyncEdit(fact, { version, kind, value, observed })
}

test('a later reread does not let a concurrent stale page escape the reset', () => {
  const initial = facts.emptySyncFact(key)
  const reset = edit(initial, dot(A, 1), 'reset', position(0))
  const stale = edit(initial, dot(B, 200), 'set', position(7))
  const reread = edit(reset, dot(C, 1), 'set', position(2))
  for (const order of [[reset, stale, reread], [stale, reread, reset], [reread, reset, stale]]) {
    const merged = order.reduce(facts.mergeSyncFact)
    assert.equal(facts.syncVisibleValue(merged), position(2))
    assert.deepEqual(merged.barriers.map(barrier => barrier.version), [dot(A, 1)])
    assert.deepEqual(facts.mergeSyncFact(merged, merged), merged)
    assert.doesNotThrow(() => facts.checkedSyncFact(merged))
  }
})

test('sequential writes from one reader session compact its own heads', () => {
  let fact = facts.emptySyncFact(key)
  for (let index = 1; index <= 200; index++) {
    fact = edit(fact, dot(A, index), 'set', position(index % 8), [])
  }
  assert.equal(fact.values.length, 1)
  assert.deepEqual(facts.checkedSyncFact(fact), fact)
  assert.equal(facts.syncVisibleValue(fact), position(0))
})

test('clear only affects observed history; a single deletion fences a concurrent recreation', () => {
  const initial = edit(facts.emptySyncFact('recent'), dot(B, 1), 'set', '"old"')
  const fresh = edit(initial, dot(B, 2), 'set', '"new"')
  const cleared = edit(initial, dot(A, 1), 'clear-observed', '')
  const deleted = edit(initial, dot(A, 1), 'delete', '')
  assert.equal(facts.syncVisibleValue(facts.mergeSyncFact(cleared, fresh)), '"new"')
  assert.equal(facts.syncVisibleValue(facts.mergeSyncFact(deleted, fresh)), undefined)
  assert.equal(facts.syncVisibleValue(edit(deleted, dot(C, 1), 'set', '"new"')), '"new"')
})

test('same-value references are reusable, while incompatible buckets, checksums and fields are rejected', () => {
  const fact = edit(facts.emptySyncFact(key), dot(A, 1), 'set', position(1))
  const bucketFor = data.syncBucketKey
  const dataset = wire.buildSyncDataset('reading', [fact], 1, undefined, bucketFor)
  assert.equal(dataset.objects.length, 1)
  const item = dataset.objects[0]
  assert.deepEqual(wire.decodeSyncShard('reading', item.ref, item.body, bucketFor), [fact])
  assert.equal(wire.buildSyncDataset('reading', [fact], 2, dataset.ref, bucketFor).objects.length, 0)
  assert.throws(() => wire.decodeSyncShard('reading', item.ref, item.body.replace('aaaaaaaa', 'bbbbbbbb'), bucketFor), /damaged/)
  assert.throws(() => wire.decodeSyncShard('reading', { ...item.ref, bucket: item.ref.bucket === '00' ? '01' : '00' },
    item.body, bucketFor), /bucket/)
  assert.throws(() => facts.checkedSyncFact({ ...fact, values: [{ ...fact.values[0], future: true }] }), /edit/)
  assert.throws(() => facts.checkedSyncFact({ ...fact, seen: [{ ...fact.seen[0], future: true }] }), /version/)
})

test('wire search identity is independent of host language and folds Unicode expansions', () => {
  assert.equal(data.syncSearchIdentity('  ﬃ K  '), data.syncSearchIdentity('FFI k'))
  assert.equal(data.syncSearchIdentity('İ'), data.syncSearchIdentity('I\u0307'))
  assert.notEqual(data.syncSearchIdentity('ı'), data.syncSearchIdentity('I'))
  assert.equal(data.syncSearchIdentity('Straße'), data.syncSearchIdentity('STRASSE'))
  assert.equal(data.safeSyncSearch('Bearer abcdef'), false)
  assert.equal(data.safeSyncSearch('https://example.test/path-with-key'), false)
})

test('business records accept unfamiliar sources, catalog addresses and ordinary search punctuation', () => {
  const cases = [
    ['reader-settings', ['book-mode', 'net.example.new-source', 'opaque-work'], { mode: 'continuous_scroll', direction: 'right_to_left' }],
    ['source-subscriptions', data.syncKeyParts(data.syncCatalogRecordKey('https://catalog.example.test/index.json')),
      { address: 'https://catalog.example.test/index.json', label: 'My catalog' }],
    ['search-history', ['query', 'volume 1: a (story)'], { text: 'Volume 1: A (Story)', date: 2000 }],
  ]
  for (const [group, key, value] of cases) {
    const fact = edit(facts.emptySyncFact(data.syncKey(key)), dot(A, 1), 'set', JSON.stringify(value))
    assert.doesNotThrow(() => data.checkSyncGroupFact(group, fact))
  }
  assert.equal(data.syncCatalogAddress('https://user:secret@catalog.example.test/index.json'), false)
  assert.equal(data.syncCoverAddress('http://[fd00::1]:8080/cover.jpg'), 'http://[fd00::1]:8080/cover.jpg')
  assert.equal(data.syncCoverAddress('http://[fd00::1]:8080/cover.jpg?token=secret'), undefined)
})

function runtimeFixture(extra = {}, globals = {}) {
  return compile('DeviceSyncRuntime', {
    '@kit.NetworkKit': {}, '@kit.ArkTS': {}, '@kit.BackgroundTasksKit': {},
    '../model/ReaderSessionStore': {}, '../model/SearchHistoryStore': {},
    '../sourceRuntime/SourceIndexService': {}, '../sourceRuntime/SourceRuntimeAppRegistry': {},
    './DeviceSyncEngine': { syncRequiresExplicitReview: () => false },
    './DeviceSyncFacts': facts, './DeviceSyncOwners': {}, './DeviceSyncStorage': {},
    './DeviceSyncShardCache': { DeviceSyncShardCache: class {} },
    './DeviceSyncData': data, './DeviceSyncSignals': {},
    '../sourceRuntime/SourceIndexMetadata': {},
    ...extra,
  }, { ObservedV2: value => value, Trace: () => {}, ...globals }).appDeviceSync
}

test('foreground idle checks and retries slow down without delaying a reading update or polling in background', async () => {
  let now = 0, id = 0, requests = 0
  const timers = new Map()
  const runtime = runtimeFixture({}, {
    Date: { now: () => now },
    setTimeout: (fn, delay) => { timers.set(++id, { fn, due: now + delay }); return id },
    clearTimeout: timer => timers.delete(timer),
  })
  const advance = async ms => {
    const end = now + ms
    while (true) {
      const next = [...timers].filter(([, timer]) => timer.due <= end).sort((a, b) => a[1].due - b[1].due)[0]
      if (next === undefined) break
      const [key, timer] = next
      timers.delete(key)
      now = timer.due
      timer.fn()
      await new Promise(resolve => setImmediate(resolve))
    }
    now = end
  }
  Object.assign(runtime.view, { configured: true, connected: true, enabled: true, automatic: true, selected: ['reading'] })
  runtime.foreground = true
  let failNext = false
  runtime.sync = async () => {
    requests++
    if (failNext) { failNext = false; throw new Error('sync_network_failed') }
  }
  runtime.historyOpened()
  await advance(59999)
  assert.equal(requests, 1)
  await advance(1)
  assert.equal(requests, 2)
  await advance(119999)
  assert.equal(requests, 2)
  await advance(1)
  assert.equal(requests, 3)
  runtime.changed('reading')
  await advance(1500)
  assert.equal(requests, 4)
  failNext = true
  runtime.historyOpened()
  await advance(59999)
  assert.equal(requests, 5)
  await advance(1)
  assert.equal(requests, 6)
  runtime.onForeground(false)
  await advance(600000)
  assert.equal(requests, 6)
})

test('draft tests and merge failures preserve the active connection error', async () => {
  const runtime = runtimeFixture()
  const draft = { directory: 'https://draft.example.test/', username: '', password: '' }
  let failure = 'sync_authentication_failed'
  const execute = async () => { if (failure) throw new Error(failure) }
  runtime.engine = {
    active: () => ({ selected: ['reader-settings'], groups: [], lastSuccess: 123 }),
    configuration: () => ({ selected: ['reader-settings'], enabled: true, automatic: false }),
    selection: () => ['reader-settings'],
    hasUnresolvedCommit: () => false,
    stateGuard: () => () => {},
    readingScope: () => '',
    testConnection: async () => { await execute(); return false },
    prepare: execute, confirm: execute, syncNow: execute,
  }
  const operations = [() => runtime.test(draft, []), () => runtime.prepare(draft, [], false),
    () => runtime.confirm('preview', [], false)]
  for (const operation of operations) {
    runtime.view.error = 'sync_network_failed'
    await assert.rejects(operation(), /sync_authentication_failed/)
    assert.equal(runtime.view.error, 'sync_network_failed')
    assert.equal(runtime.view.busy, false)
  }
  failure = ''
  await runtime.test(draft, [])
  await runtime.prepare(draft, [], false)
  assert.equal(runtime.view.error, 'sync_network_failed')
  await runtime.confirm('preview', [], false)
  assert.equal(runtime.view.error, '')
  failure = 'sync_server_storage_full'
  await assert.rejects(runtime.sync(), /sync_server_storage_full/)
  assert.equal(runtime.view.error, 'sync_server_storage_full')
})

test('received reading opens through any enabled source and identifies a missing or disabled source', async () => {
  let installed = { enabled: true }
  let received = true
  const runtime = runtimeFixture({
    '../sourceRuntime/SourceRuntimeAppRegistry': { getInstalledSourcePackage: () => installed },
  })
  runtime.owners = { receivedReading: () => received }
  const request = { comicId: 'sample', sourceId: 'com.picacg.koma',
    mangaId: 'pica:0123456789', chapterId: 'pica:0123456789:1' }
  assert.equal(runtime.openReading(request), 'ready')
  installed.enabled = false
  assert.equal(await runtime.openReading(request), 'missing')
  installed = undefined
  assert.equal(await runtime.openReading(request), 'missing')
  received = false
  assert.equal(await runtime.openReading(request), 'ready')
})

function engineFixture(providerOverride, shardCache) {
  const assets = new Map()
  const servers = new Map()
  const clone = value => value === undefined ? undefined : structuredClone(value)
  class Provider {
    constructor(draft, witnesses = [], space = '') {
      if (!servers.has(draft.directory)) servers.set(draft.directory, {
        tag: '', head: undefined, objects: new Map(), commits: new Map(), frontier: [], published: [], failures: [],
      })
      this.server = servers.get(draft.directory)
      this.witnesses = witnesses.slice()
      const identity = wire.syncDigest(JSON.stringify([draft.directory.replace(/\/+$/, ''), draft.username.trim()]))
      this.space = space || [identity.slice(0, 8), identity.slice(8, 12), identity.slice(12, 16),
        identity.slice(16, 20), identity.slice(20, 32)].join('-')
      this.scope = identity + ':' + this.space
    }
    spaceId() { return this.space }
    cacheScope() { return this.scope }
    async prefetchLegacyObjects() { return new Map() }
    async prefetchPublicationObjects() { return new Map() }
    async writePlannedPacks(_guard, _begin, _complete) { return this.plannedObjects ?? [] }
    beginShardReadRound() {}
    async probe(_id, guard) {
      guard()
      if (this.server.probeError) throw new Error(this.server.probeError)
      return true
    }
    async cleanProbe(_id, guard) { guard() }
    async readSyncState(guard, expected = '') { return this.readManifest(guard, expected) }
    async readSharedHead(guard) { guard(); return { etag: '', hash: '' } }
    async readManifest(guard, expected = '') {
      guard()
      this.server.reads = (this.server.reads ?? 0) + 1
      const { head, tag } = this.server
      if (expected && expected !== tag) throw new Error('sync_preview_changed')
      return { manifest: clone(head), etag: tag, hash: head ? wire.syncDigest(JSON.stringify(head)) : '',
        frontier: this.server.frontier.slice(), journal: true }
    }
    async readLegacyManifest(guard) { guard(); return { etag: '', hash: '' } }
    commitName(head, frontier) { return journal.syncCommitName(journal.syncCommitBody(head, frontier)) }
    commitBody(head, frontier) { return journal.syncCommitBody(head, frontier) }
    async retryCommit(body, guard, selected) {
      guard()
      const name = journal.syncCommitName(body)
      const commit = journal.decodeSyncCommit(name, body)
      for (const parent of commit.parents) assert.ok(this.server.commits.has(parent))
      for (const dataset of commit.manifest.datasets.concat(commit.manifest.alternatives ?? [])) {
        if (!selected.includes(dataset.id)) continue
        for (const ref of dataset.shards) {
          const content = this.server.objects.get(wire.syncShardPath(ref))
          assert.equal(wire.syncDigest(content), ref.hash)
          assert.equal(wire.syncUtf8(content).byteLength, ref.bytes)
        }
      }
      this.server.commits.set(name, body)
      this.server.frontier = [name]
      this.server.head = clone(commit.manifest)
      this.server.tag = '"journal-' + wire.syncDigest(name) + '"'
      return this.readCommit(name, guard)
    }
    async readCommit(name, guard) {
      guard()
      const body = this.server.commits.get(name)
      if (body === undefined) return undefined
      const commit = journal.decodeSyncCommit(name, body)
      const manifest = { ...commit.manifest, space: this.space }
      return { manifest, etag: '"journal-' + wire.syncDigest(name) + '"',
        hash: wire.syncDigest(JSON.stringify(manifest)), frontier: [name], journal: true }
    }
    async readObject(ref, guard) {
      guard()
      this.server.objectReads = (this.server.objectReads ?? 0) + 1
      return this.server.objects.get(wire.syncShardPath(ref))
    }
    async storeObject(object, guard) {
      guard()
      this.server.objects.set(wire.syncShardPath(object.ref), object.body)
    }
    async publish(head, tag, guard, beforeSend = () => {}) {
      guard()
      this.server.published.push(clone(head))
      if (this.server.tag !== tag) return false
      const failure = this.server.failures.shift()
      if (failure === '412') return false
      const body = journal.syncCommitBody(head, this.server.frontier)
      const name = journal.syncCommitName(body)
      await beforeSend()
      guard()
      if (failure === 'before-accept') throw new Error('sync_network_failed')
      this.server.commits.set(name, body)
      this.server.frontier = [name]
      this.server.head = clone(head)
      this.server.tag = '"journal-' + wire.syncDigest(name) + '"'
      if (failure === 'lost-response') throw new Error('sync_network_failed')
      return true
    }
    async sweepable() { return [] }
    async compactWriterObjects() {}
    async compactLegacyObjects() {}
    async reconcileArchiveAttempts() {}
    configureArchiveWitness() {}
    setRoundMetrics() {}
    setGuardMetrics() {}
  }
  const storagePort = {
    checkedSyncDraft: draft => draft,
    copySyncConnection: clone,
    writeSyncCredential: async (ref, draft) => { assets.set(ref, clone(draft)) },
    readSyncCredential: async ref => {
      if (!assets.has(ref)) throw new Error('sync_credential_read_failed')
      return clone(assets.get(ref))
    },
    clearSyncCredential: async ref => { assets.delete(ref) },
  }
  const { DeviceSyncEngine } = compile('DeviceSyncEngine', {
    './DeviceSyncFacts': facts, './DeviceSyncData': data, './DeviceSyncWire': wire,
    './DeviceSyncPlanner': compile('DeviceSyncPlanner', {
      './DeviceSyncFacts': facts, './DeviceSyncData': data, './DeviceSyncWire': wire,
    }),
    './DeviceSyncStorage': storagePort, './DeviceSyncWebDav': { DeviceSyncWebDav: providerOverride ?? Provider },
    './DeviceSyncMetrics': metrics,
    '@kit.ArkTS': {
      util: { generateRandomUUID: randomUUID },
      taskpool: { execute: async (fn, ...args) => fn(...args) },
    },
  }, { setTimeout: (fn, ms) => setTimeout(fn, ms === 15000 ? 1 : ms) })
  const draft = { directory: 'https://local-fixture.invalid', username: '', password: '' }
  function replica(id, initial = [], ownerFactory) {
    let document = { schema: 1, replica: id, counter: 0, probes: [] }
    const values = new Map(initial)
    const snapshotExtras = new Map()
    const store = {
      load: () => document,
      update(change) { const next = clone(document); change(next); document = next },
      async updateInBackground(change, guard) {
        guard()
        const next = clone(document)
        if (change(next)) document = next
      },
    }
    const owner = ownerFactory?.(store) ?? {
      async snapshot(group) {
        const rows = [...(values.get(group) ?? new Map())].map(([key, value]) => ({ key, value }))
        return { values: rows, revision: JSON.stringify(rows), skipped: 0, ...snapshotExtras.get(group) }
      },
      removed: () => [],
      async commit(groups, expected, save) {
        for (const item of expected) {
          assert.equal(item.revision, (await this.snapshot(item.group)).revision)
        }
        for (const { group, changes } of groups) {
          if (!values.has(group)) values.set(group, new Map())
          for (const row of changes) {
            if (row.value === '') values.get(group).delete(row.key)
            else values.get(group).set(row.key, row.value)
          }
        }
        save(randomUUID())
      },
    }
    return { engine: new DeviceSyncEngine(store, owner, shardCache), values, store, snapshotExtras,
      restart: () => new DeviceSyncEngine(store, owner, shardCache) }
  }
  return { replica, draft, servers, assets }
}

test('saved zero-scope configuration survives a new engine and stays off until a confirmed first merge', async () => {
  const { replica, draft, servers, assets } = engineFixture()
  const page = data.syncKey(['global', 'page-number'])
  const device = replica(A, [['reader-settings', new Map([[page, 'true']])]])
  device.engine.setSelection([])
  assert.deepEqual(device.restart().selection(), [], 'shared content selection is saved before a service exists')
  await device.engine.saveConfiguration(draft)
  const reopened = device.restart()
  assert.equal(reopened.active(), undefined)
  assert.deepEqual(reopened.selection(), [])
  assert.deepEqual(await reopened.connectionDraft(), draft)
  assert.equal(reopened.isEnabled(), false)
  assert.equal(assets.size, 1)
  await assert.rejects(reopened.syncNow(), /sync_service_disabled/)
  await reopened.recoverOnForeground()
  assert.equal(servers.get(draft.directory).head, undefined)
  reopened.setSelection(['reader-settings'])
  const cancelled = await reopened.prepareSaved(['reader-settings'])
  reopened.discardPreview(cancelled.token)
  assert.equal(reopened.active(), undefined)
  assert.equal(reopened.isEnabled(), false)
  assert.equal(servers.get(draft.directory).published.length, 0)
  await assert.rejects(reopened.confirm(cancelled.token, []), /sync_preview_changed/)
  let release
  const gate = new Promise(resolve => { release = resolve })
  const connectionDraft = reopened.connectionDraft.bind(reopened)
  reopened.connectionDraft = async () => { await gate; return connectionDraft() }
  const reading = reopened.prepareSaved(['reader-settings'])
  const rejected = assert.rejects(reading, /sync_preview_changed/)
  const reads = servers.get(draft.directory).reads
  reopened.discardPreview()
  release()
  await rejected
  assert.equal(servers.get(draft.directory).reads, reads, 'cancel before credential return cannot start a new read permit')
  reopened.connectionDraft = connectionDraft
  await reopened.confirm((await reopened.prepareSaved(['reader-settings'])).token, [])
  assert.equal(reopened.active().enabled, true)
  assert.equal(reopened.active().automatic, true, 'new connections become automatic only after the confirmed first merge')
  assert.equal(device.store.load().pendingConfiguration, undefined)
  // The Runtime performs a local capture pass before asking the Engine for
  // data. Its first await must share the same cancellation identity.
  const runtime = runtimeFixture()
  runtime.engine = reopened
  runtime.refresh()
  const captureGate = new Promise(resolve => { release = resolve })
  runtime.recordPositions = async () => { await captureGate }
  const capture = runtime.prepareSaved(['reading'])
  const captureRejected = assert.rejects(capture, /sync_preview_changed/)
  const before = servers.get(draft.directory).reads
  runtime.discard()
  release()
  await captureRejected
  assert.equal(servers.get(draft.directory).reads, before)
  await reopened.disconnect()
  assert.deepEqual(device.restart().selection(), ['reader-settings'])
})

test('failed replacement keeps the original service; successful save stops it without syncing the new space', async () => {
  const { replica, draft, servers } = engineFixture()
  const device = replica(A)
  device.engine.setSelection(['reader-settings'])
  await device.engine.saveConfiguration(draft)
  await device.engine.confirm((await device.engine.prepareSaved(['reader-settings'])).token, [])
  device.engine.setAutomatic(true)
  device.store.update(state => { delete state.syncContents })
  assert.deepEqual(device.restart().selection(), ['reader-settings'], 'upgrade reads the existing WebDAV selection')
  const original = structuredClone(device.engine.active())
  const replacement = { ...draft, directory: 'https://replacement.invalid', password: 'new' }
  await device.engine.testConnection(replacement)
  const server = servers.get(replacement.directory)
  server.probeError = 'sync_authentication_failed'
  await assert.rejects(device.engine.saveConfiguration({ ...replacement, password: 'wrong' }), /sync_authentication_failed/)
  assert.deepEqual(device.engine.active(), original)
  const update = device.store.update
  device.store.update = change => update(state => {
    change(state)
    if (state.pendingConfiguration?.endpointIdentity !== undefined) throw new Error('sync_local_write_failed')
  })
  delete server.probeError
  await assert.rejects(device.engine.saveConfiguration(replacement), /sync_local_write_failed/)
  assert.deepEqual(device.engine.active(), original)
  assert.deepEqual(await device.engine.connectionDraft(), draft)
  device.store.update = update
  await device.engine.saveConfiguration(replacement)
  const reopened = device.restart()
  assert.equal(reopened.active(), undefined)
  assert.equal(reopened.isEnabled(), false)
  assert.deepEqual(await reopened.connectionDraft(), replacement)
  assert.deepEqual(reopened.selection(), ['reader-settings'], 'replacing the service connection preserves the common scope')
  await reopened.recoverOnForeground()
  assert.equal(server.published.length, 0)
  assert.ok(device.store.load().archives.some(item => item.space === original.space && item.credential === ''))
})

test('password save preserves a confirmed intent, its recovery and the latest paused policy', async () => {
  const { replica, draft, servers } = engineFixture()
  const page = data.syncKey(['global', 'page-number'])
  const device = replica(A, [['reader-settings', new Map([[page, 'true']])]])
  device.engine.setSelection(['reader-settings'])
  await device.engine.saveConfiguration(draft)
  const preview = await device.engine.prepareSaved(['reader-settings'])
  servers.get(draft.directory).failures.push('lost-response')
  await assert.rejects(device.engine.confirm(preview.token, []), /sync_remote_result_unknown/)
  const intent = structuredClone(device.store.load().intent)
  const changed = { ...draft, password: 'changed' }
  await device.engine.saveConfiguration(changed)
  assert.equal(device.store.load().intent.commitBody, intent.commitBody)
  assert.deepEqual(device.store.load().intent.applies, intent.applies)
  assert.equal(device.engine.active(), undefined)
  device.values.get('reader-settings').set(page, 'false')
  await assert.rejects(device.engine.recoverOnForeground(), /sync_review_required/)
  assert.equal(device.engine.active().requiresExplicitReview, true)
  await device.engine.confirm((await device.engine.prepareSaved(['reader-settings'])).token, [])
  assert.equal(device.store.load().intent, undefined)
  assert.equal(device.store.load().pendingConfiguration, undefined)
  assert.deepEqual(await device.engine.connectionDraft(), changed)
  assert.equal(servers.get(draft.directory).published.length, 1,
    'deferring the new local difference must retain the exact original remote commit')
  device.engine.setAutomatic(true)
  device.engine.setEnabled(false)
  await device.engine.saveConfiguration({ ...changed, password: 'changed-again' })
  const reopened = device.restart()
  assert.equal(reopened.isEnabled(), false)
  assert.equal(reopened.active().automatic, true)
  assert.deepEqual(reopened.selection(), ['reader-settings'])
})

test('review lists actual remote and local deletions before either side is changed', async () => {
  const { replica, draft } = engineFixture()
  const category = data.syncKey(['category', '11111111-1111-1111-1111-111111111111'])
  const left = replica(A, [['shelf', new Map([[category, '"Reading"']])]])
  const right = replica(B)
  for (const device of [left, right]) {
    device.engine.setSelection(['shelf'])
    await device.engine.saveConfiguration(draft)
    await device.engine.confirm((await device.engine.prepareSaved(['shelf'])).token, [])
  }
  right.values.get('shelf').delete(category)
  right.engine.recordEdits('shelf', [{ key: category, kind: 'delete', value: '' }])
  const outgoing = await right.engine.prepareSaved(['shelf'])
  assert.deepEqual(outgoing.removals.map(item => [item.key, item.value, item.target]), [[category, '"Reading"', 'remote']])
  assert.equal(outgoing.groups[0].remove, 1)
  assert.equal(left.values.get('shelf').get(category), '"Reading"')
  await right.engine.confirm(outgoing.token, [])
  const incoming = await left.engine.prepareSaved(['shelf'])
  assert.deepEqual(incoming.removals.map(item => [item.key, item.value, item.target]), [[category, '"Reading"', 'local']])
  assert.equal(incoming.groups[0].remove, 1)
  assert.equal(left.values.get('shelf').get(category), '"Reading"')
  await left.engine.confirm(incoming.token, [])
  assert.equal(left.values.get('shelf').has(category), false)
})

test('fixed local settings retain a shared deletion without implicit revival, but allow an explicit re-share', async () => {
  const { replica, draft, servers } = engineFixture()
  const animation = data.syncKey(['global', 'animation'])
  const remote = replica(B, [['reader-settings', new Map([[animation, 'true']])]])
  await remote.engine.testConnection(draft)
  await remote.engine.confirm((await remote.engine.prepare(draft, ['reader-settings'])).token, [])
  remote.values.get('reader-settings').delete(animation)
  remote.engine.recordEdits('reader-settings', [{ key: animation, kind: 'delete', value: '' }])
  await remote.engine.syncNow()
  const local = replica(A, [['reader-settings', new Map([[animation, 'true']])]])
  local.snapshotExtras.set('reader-settings', { retainedDeletionKeys: [animation] })
  local.engine.setSelection(['reader-settings'])
  await local.engine.saveConfiguration(draft)
  const preview = await local.engine.prepareSaved(['reader-settings'])
  assert.equal(preview.conflicts[0].retainLocalOnDelete, true)
  assert.equal(preview.groups[0].remove, 0)
  assert.equal(preview.groups[0].retained, 1)
  assert.deepEqual(preview.removals, [])
  const server = servers.get(draft.directory)
  const before = structuredClone(server.head)
  const writes = server.published.length
  await local.engine.confirm(preview.token, [])
  assert.equal(local.values.get('reader-settings').get(animation), 'true')
  assert.equal(local.engine.active().groups[0].baseline.find(item => item.key === animation).value, 'true')
  await local.engine.syncNow()
  assert.equal(server.published.length, writes)
  assert.deepEqual(server.head, before)
  // An older accepted intent stored the host's ignored empty apply. Recovery
  // must preserve the exact remote receipt and the owner's real baseline.
  local.store.update(state => {
    state.intent = { connection: structuredClone(state.active), expected: server.tag, sent: true,
      groupRevisions: [{ group: 'reader-settings', revision: JSON.stringify([{ key: animation, value: 'true' }]) }],
      applies: [{ group: 'reader-settings', changes: [{ key: animation, value: '' }] }],
      commit: server.frontier[0], commitBody: server.commits.get(server.frontier[0]) }
  })
  await local.restart().recoverOnForeground()
  assert.equal(local.values.get('reader-settings').get(animation), 'true')
  assert.equal(local.engine.active().groups[0].baseline.find(item => item.key === animation).value, 'true')
  await local.engine.syncNow()
  assert.equal(server.published.length, writes)
  assert.deepEqual(server.head, before)
  // The same old version could finish its receipt with this baseline absent.
  // Treat the already-observed deletion conservatively, then repair baseline.
  local.store.update(state => { state.active.groups[0].baseline = [] })
  await local.engine.syncNow()
  assert.equal(server.published.length, writes)
  assert.deepEqual(server.head, before)
  assert.equal(local.engine.active().groups[0].baseline.find(item => item.key === animation).value, 'true')
  const again = await local.engine.prepareSaved(['reader-settings'])
  const choices = [{ group: 'reader-settings', key: animation, useLocal: true }]
  const shared = local.engine.previewChoices(again.token, choices)
  assert.equal(shared.groups[0].retained, 0)
  assert.equal(shared.groups[0].upload, 1)
  server.failures.push('lost-response')
  await assert.rejects(local.engine.confirm(again.token, choices), /sync_remote_result_unknown/)
  await local.engine.recoverOnForeground()
  assert.equal(server.published.length, writes + 1)
  assert.equal(local.store.load().intent, undefined)
  const fact = local.engine.active().groups[0].facts.find(item => item.key === animation)
  assert.equal(facts.syncVisibleValue(fact), 'true')
  local.values.get('reader-settings').set(animation, 'false')
  await local.engine.syncNow()
  assert.equal(facts.syncVisibleValue(local.engine.active().groups[0].facts.find(item => item.key === animation)), 'false')
})

test('first merge cancellation and stale preview leave the remote manifest unchanged', async () => {
  const fixture = engineFixture()
  const cat = data.syncKey(['category', '11111111-1111-1111-1111-111111111111'])
  const left = fixture.replica(A, [['shelf', new Map([[cat, '"First"']])]])
  const right = fixture.replica(B)
  await left.engine.testConnection(fixture.draft)
  const stale = await left.engine.prepare(fixture.draft, ['shelf'])
  assert.equal(fixture.servers.get(fixture.draft.directory).head, undefined)
  left.engine.discardPreview(stale.token)
  await assert.rejects(left.engine.confirm(stale.token, []), /preview_changed/)
  const ready = await left.engine.prepare(fixture.draft, ['shelf'])
  await right.engine.testConnection(fixture.draft)
  const other = await right.engine.prepare(fixture.draft, ['shelf'])
  await right.engine.confirm(other.token, [])
  const before = structuredClone(fixture.servers.get(fixture.draft.directory).head)
  await assert.rejects(left.engine.confirm(ready.token, []), /preview_changed/)
  assert.deepEqual(fixture.servers.get(fixture.draft.directory).head, before)
  assert.equal(left.values.get('shelf').get(cat), '"First"')
})

test('enabling a saved connection merges a first difference automatically and continues unrelated changes', async () => {
  const fixture = engineFixture()
  const mode = data.syncKey(['global', 'image-fit'])
  const animation = data.syncKey(['global', 'animation'])
  const left = fixture.replica(A, [['reader-settings', new Map([[mode, '"fit_width"']])]])
  const right = fixture.replica(B, [['reader-settings', new Map([[mode, '"contain"']])]])
  for (const device of [left, right]) {
    device.engine.setSelection(['reader-settings'])
    await device.engine.saveConfiguration(fixture.draft)
    assert.equal(device.engine.active(), undefined)
    await assert.rejects(device.engine.syncNow(), /sync_service_disabled/)
    device.engine.setEnabled(true)
    await device.engine.syncNow()
    assert.equal(device.engine.active().reviewRequired, false)
  }
  right.values.get('reader-settings').set(animation, 'false')
  await right.engine.syncNow()
  await left.engine.syncNow()
  assert.equal(left.values.get('reader-settings').get(mode), right.values.get('reader-settings').get(mode))
  assert.equal(left.values.get('reader-settings').get(animation), 'false')
})

test('category dependencies wait for their choice and disabled legacy conflicts leave other groups running', async () => {
  const { replica, draft } = engineFixture()
  const id = '11111111-1111-1111-1111-111111111111'
  const category = data.syncKey(['category', id])
  const order = data.syncKey(['order'])
  const left = replica(A, [['shelf', new Map([[category, '"A"'], [order, JSON.stringify([id])]])]])
  const right = replica(B, [['shelf', new Map([[category, '"B"']])]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['shelf'])).token, [])
  await right.engine.testConnection(draft)
  const preview = await right.engine.prepare(draft, ['shelf', 'reader-settings'])
  const shelf = preview.groups.find(group => group.group === 'shelf')
  assert.equal(shelf.download, 0)
  assert.deepEqual(shelf.dependent, [{ action: 'download', choices: [category] }])
  await right.engine.confirm(preview.token, [])
  assert.equal(right.values.get('shelf').has(order), false)
  const legacy = structuredClone(right.store.load().active)
  legacy.requiresExplicitReview = undefined
  legacy.groups.find(group => group.id === 'shelf').deferredRoots = undefined
  right.store.update(state => {
    state.active = structuredClone(legacy)
    state.active.selected = ['reader-settings']
  })
  await right.engine.syncNow()
  assert.equal(right.engine.active().reviewRequired, false)
  right.store.update(state => { state.active = legacy })
  const resolve = await right.engine.prepare(draft, ['shelf', 'reader-settings'])
  assert.deepEqual(resolve.conflicts.map(item => item.key), [category])
  await right.engine.confirm(resolve.token, [{ group: 'shelf', key: category, useLocal: false }])
  assert.equal(right.values.get('shelf').get(order), JSON.stringify([id]))
})

test('an unverified durable Reader edit protects local position without changing the remote head', async () => {
  const { replica, draft, servers } = engineFixture()
  const first = replica(A, [['reading', new Map([[key, position(1)]])]])
  await first.engine.testConnection(draft)
  await first.engine.confirm((await first.engine.prepare(draft, ['reading'])).token, [])
  const before = structuredClone(servers.get(draft.directory).head)
  first.values.get('reading').set(key, position(6))
  first.snapshotExtras.set('reading', { protectedKeys: [key] })
  await first.engine.syncNow()
  assert.equal(first.values.get('reading').get(key), position(6))
  assert.deepEqual(servers.get(draft.directory).head, before)
})

test('a pre-restore action stays local until explicitly selected in the merge preview', async () => {
  const { replica, draft, servers } = engineFixture()
  const first = replica(A, [['reading', new Map([[key, position(1)]])]])
  await first.engine.testConnection(draft)
  await first.engine.confirm((await first.engine.prepare(draft, ['reading'])).token, [])
  const before = structuredClone(servers.get(draft.directory).head)
  first.snapshotExtras.set('reading', { restoreEdits: [{ key, kind: 'set', value: position(6) }] })
  const preview = await first.engine.prepare(draft, ['reading'])
  assert.equal(preview.beforeRestore[0].local, position(6))
  await first.engine.confirm(preview.token, [])
  assert.deepEqual(servers.get(draft.directory).head, before)
  const explicit = await first.engine.prepare(draft, ['reading'])
  await first.engine.confirm(explicit.token, [{ group: 'reading', key, useLocal: true, useBeforeRestore: true }])
  assert.equal(first.values.get('reading').get(key), position(6))
})

test('restoring a pending unread action resets the corresponding position in the same commit', async () => {
  const { replica, draft, servers } = engineFixture()
  const read = data.syncKey(['read', ...data.syncKeyParts(key).slice(1)])
  const first = replica(A, [['reading', new Map([[key, position(7)], [read, 'true']])]])
  await first.engine.testConnection(draft)
  await first.engine.confirm((await first.engine.prepare(draft, ['reading'])).token, [])
  first.snapshotExtras.set('reading', { restoreEdits: [
    { key: read, kind: 'reset', value: 'false', bundle: 'unread-action' },
    { key, kind: 'reset', value: position(0), bundle: 'unread-action' },
  ] })
  const preview = await first.engine.prepare(draft, ['reading'])
  assert.deepEqual(preview.beforeRestore.map(item => item.key), [key])
  await first.engine.confirm(preview.token, [{ group: 'reading', key, useLocal: true, useBeforeRestore: true }])
  assert.equal(first.values.get('reading').get(read), 'false')
  assert.equal(first.values.get('reading').get(key), position(0))
  const server = servers.get(draft.directory)
  const persisted = server.head.datasets.flatMap(dataset => dataset.shards
    .flatMap(ref => wire.decodeSyncShard(dataset.id, ref, server.objects.get(wire.syncShardPath(ref)), data.syncBucketKey)))
  assert.deepEqual(persisted.find(fact => fact.key === read).barriers[0].version,
    persisted.find(fact => fact.key === key).barriers[0].version)
})

test('a successful backup restore seals an already-sent intent before foreground recovery', async () => {
  const { replica, draft } = engineFixture()
  const first = replica(A, [['reading', new Map([[key, position(1)]])]])
  await first.engine.testConnection(draft)
  await first.engine.confirm((await first.engine.prepare(draft, ['reading'])).token, [])
  first.store.update(state => {
    state.intent = { connection: structuredClone(state.active), sent: true, expected: '"older"',
      groupRevisions: [{ group: 'reading', revision: JSON.stringify([{ key, value: position(1) }]) }],
      applies: [{ group: 'reading', changes: [{ key, value: position(5) }] }] }
  })
  first.engine.beginRestore()
  first.engine.finishRestore(true)
  await first.engine.recoverOnForeground()
  assert.equal(first.values.get('reading').get(key), position(1))
  assert.equal(first.store.load().intent.detached, true)
  assert.equal(first.engine.active().reviewRequired, true)
})

test('the newest reading time resolves equal positions on first merge and different pages during sync', async () => {
  const { replica, draft } = engineFixture()
  const at = (page, date) => JSON.stringify({ page, total: 8, date })
  const [, source, work, chapter] = data.syncKeyParts(key)
  const recentKey = data.syncKey(['recent', source, work])
  const nextChapter = 'ch:33333333-3333-3333-3333-333333333333'
  const recent = (id, date, page) => JSON.stringify(data.syncReadingRecent(source, id, date, 'Test work', 'Test source', id, page))
  const left = replica(A, [['reading', new Map([[key, at(1, 100)], [recentKey, recent(chapter, 100, 1)]])]])
  const right = replica(B, [['reading', new Map([[key, at(1, 200)], [recentKey, recent(chapter, 200, 1)]])]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['reading'])).token, [])
  await right.engine.testConnection(draft)
  const preview = await right.engine.prepare(draft, ['reading'])
  assert.equal(preview.conflicts.length, 0)
  await right.engine.confirm(preview.token, [])
  await left.engine.syncNow()
  assert.equal(left.values.get('reading').get(key), at(1, 200))
  assert.equal(right.values.get('reading').get(key), at(1, 200))

  const newerReread = at(0, 400)
  const olderLaterPage = at(6, 300)
  const newerRecent = recent(chapter, 400, 0)
  const olderRecent = recent(nextChapter, 300, 0)
  left.values.get('reading').set(key, newerReread)
  left.values.get('reading').set(recentKey, newerRecent)
  right.values.get('reading').set(key, olderLaterPage)
  right.values.get('reading').set(recentKey, olderRecent)
  left.engine.recordEdits('reading', [{ key, kind: 'set', value: newerReread }, { key: recentKey, kind: 'set', value: newerRecent }])
  right.engine.recordEdits('reading', [{ key, kind: 'set', value: olderLaterPage }, { key: recentKey, kind: 'set', value: olderRecent }])
  await left.engine.syncNow()
  right.snapshotExtras.set('reading', { protectedKeys: [key] })
  await right.engine.syncNow()
  assert.equal(right.values.get('reading').get(key), olderLaterPage)
  right.snapshotExtras.delete('reading')
  await right.engine.syncNow()
  await left.engine.syncNow()
  assert.equal(left.values.get('reading').get(key), newerReread)
  assert.equal(right.values.get('reading').get(key), newerReread)
  assert.equal(left.values.get('reading').get(recentKey), newerRecent)
  assert.equal(right.values.get('reading').get(recentKey), newerRecent)
  assert.equal(right.engine.knownReadingValue(key), newerReread)
})

test('a focused reading read fetches only the work bucket and applies newer progress', async () => {
  const { replica, draft, servers } = engineFixture()
  const source = 'org.focused.koma'
  const work = 'work:focused'
  const chapter = 'chapter:one'
  const nextChapter = 'chapter:two'
  const recentKey = data.syncKey(['recent', source, work])
  const firstPosition = data.syncKey(['position', source, work, chapter])
  const nextPosition = data.syncKey(['position', source, work, nextChapter])
  const recent = (id, date, page) => JSON.stringify(data.syncReadingRecent(source, id, date, 'Focused', 'Source', id, page))
  const position = (page, date) => JSON.stringify({ page, total: 10, date })
  const initial = new Map([[recentKey, recent(chapter, 100, 0)], [firstPosition, position(0, 100)]])
  const left = replica(A, [['reading', new Map(initial)]])
  const right = replica(B, [['reading', new Map(initial)]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['reading'])).token, [])
  await right.engine.testConnection(draft)
  await right.engine.confirm((await right.engine.prepare(draft, ['reading'])).token, [])

  const nextRecent = recent(nextChapter, 200, 4)
  const nextPage = position(4, 200)
  left.values.get('reading').set(recentKey, nextRecent)
  left.values.get('reading').set(nextPosition, nextPage)
  left.engine.recordEdits('reading', [{ key: recentKey, kind: 'set', value: nextRecent },
    { key: nextPosition, kind: 'set', value: nextPage }])
  await left.engine.syncNow()

  const server = servers.get(draft.directory)
  server.objectReads = 0
  const result = await right.engine.syncReadingWork(source, work)
  assert.equal(result.applied, true)
  assert.equal(server.objectReads, 1)
  assert.equal(right.values.get('reading').get(recentKey), nextRecent)
  assert.equal(right.values.get('reading').get(nextPosition), nextPage)
})

test('a focused reading read reports a concurrent local save instead of overwriting it', async () => {
  const { replica, draft, servers } = engineFixture()
  const source = 'org.focused.koma'
  const work = 'work:conflict'
  const chapter = 'chapter:one'
  const nextChapter = 'chapter:two'
  const recentKey = data.syncKey(['recent', source, work])
  const firstPosition = data.syncKey(['position', source, work, chapter])
  const nextPosition = data.syncKey(['position', source, work, nextChapter])
  const recent = (id, date, page) => JSON.stringify(data.syncReadingRecent(source, id, date, 'Focused', 'Source', id, page))
  const position = (page, date) => JSON.stringify({ page, total: 10, date })
  const initial = new Map([[recentKey, recent(chapter, 100, 0)], [firstPosition, position(0, 100)]])
  const left = replica(A, [['reading', new Map(initial)]])
  const right = replica(B, [['reading', new Map(initial)]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['reading'])).token, [])
  await right.engine.testConnection(draft)
  await right.engine.confirm((await right.engine.prepare(draft, ['reading'])).token, [])

  const remoteRecent = recent(nextChapter, 200, 4)
  const remotePage = position(4, 200)
  left.values.get('reading').set(recentKey, remoteRecent)
  left.values.get('reading').set(nextPosition, remotePage)
  left.engine.recordEdits('reading', [{ key: recentKey, kind: 'set', value: remoteRecent },
    { key: nextPosition, kind: 'set', value: remotePage }])
  await left.engine.syncNow()

  const localRecent = recent(chapter, 300, 7)
  const localPage = position(7, 300)
  right.values.get('reading').set(recentKey, localRecent)
  right.values.get('reading').set(firstPosition, localPage)
  right.engine.recordEdits('reading', [{ key: recentKey, kind: 'set', value: localRecent },
    { key: firstPosition, kind: 'set', value: localPage }])
  const server = servers.get(draft.directory)
  server.objectReads = 0
  const result = await right.engine.syncReadingWork(source, work)
  assert.equal(result.applied, false)
  assert.equal(result.conflict.local.chapter, chapter)
  assert.equal(result.conflict.remote.chapter, nextChapter)
  assert.equal(server.objectReads, 1)
  assert.equal(right.values.get('reading').get(recentKey), localRecent)
  assert.equal(right.values.get('reading').get(firstPosition), localPage)
})

test('a refreshed chapter catalog deletes the previous block generation', async () => {
  const { replica, draft } = engineFixture()
  const source = 'org.catalog.koma'
  const work = 'work:catalog'
  const catalog = (ids, date) => {
    const blocks = []
    let current = []
    let length = 2
    ids.forEach(id => {
      const size = JSON.stringify(id).length + 1
      if (length + size > 4096 && current.length > 0) { blocks.push(current); current = []; length = 2 }
      current.push(id)
      length += size
    })
    if (current.length > 0) blocks.push(current)
    const digest = require('node:crypto').createHash('sha256').update(JSON.stringify(ids)).digest('hex')
    return [[data.syncKey(['chapter-catalog', source, work]),
      JSON.stringify({ digest, count: ids.length, blocks: blocks.length, date })]].concat(
      blocks.map((block, index) => [data.syncKey(['chapter-catalog-block', source, work, digest, index.toString()]),
        JSON.stringify(block)]))
  }
  const first = catalog(Array.from({ length: 900 }, (_, index) => 'chapter-' + index.toString().padStart(6, '0')), 1)
  const second = catalog(Array.from({ length: 901 }, (_, index) => 'chapter-' + index.toString().padStart(6, '0')), 2)
  const left = replica(A, [['shelf', new Map(first)]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['shelf'])).token, [])
  const shelf = left.values.get('shelf')
  first.forEach(([key]) => { shelf.delete(key) })
  second.forEach(([key, value]) => { shelf.set(key, value) })
  left.engine.recordEdits('shelf', second.map(([key, value]) => ({ key, kind: 'set', value })))
  await left.engine.syncNow()
  const group = left.engine.active().groups.find(item => item.id === 'shelf')
  const oldKey = first.find(([key]) => key.includes('chapter-catalog-block'))[0]
  const oldFact = group.facts.find(fact => fact.key === oldKey)
  assert.ok(oldFact)
  assert.equal(facts.syncVisibleValue(oldFact), undefined)
  assert.ok(oldFact.barriers.length > 0)
})

test('a real preference change keeps its dot through a rejected conditional write and a lost reply', async () => {
  const { replica, draft, servers } = engineFixture()
  const pageNumber = data.syncKey(['global', 'page-number'])
  const first = replica(A, [['reader-settings', new Map([[pageNumber, 'true']])]])
  await first.engine.testConnection(draft)
  await first.engine.confirm((await first.engine.prepare(draft, ['reader-settings'])).token, [])
  const server = servers.get(draft.directory)
  server.failures.push('412', 'lost-response')
  first.values.get('reader-settings').set(pageNumber, 'false')
  await assert.rejects(first.engine.syncNow(), /sync_remote_result_unknown/)
  const attempts = server.published.slice(1)
  assert.equal(attempts.length, 2)
  assert.deepEqual(attempts[0].datasets, attempts[1].datasets)
  const fact = attempts[0].datasets.flatMap(dataset => dataset.shards
    .flatMap(ref => wire.decodeSyncShard(dataset.id, ref, server.objects.get(wire.syncShardPath(ref)), data.syncBucketKey)))
    .find(item => item.key === pageNumber)
  assert.equal(fact.values[0].value, 'false')
  assert.equal(fact.values[0].version.sequence, 2)
  await first.engine.syncNow()
  assert.equal(server.published.length, 3, 'the accepted write is not issued again')
})

test('receipt recovery keeps an independently received preference as remote data', async () => {
  const { replica, draft, servers } = engineFixture()
  const pageNumber = data.syncKey(['global', 'page-number'])
  const animation = data.syncKey(['global', 'animation'])
  const left = replica(A, [['reader-settings', new Map([[pageNumber, 'true'], [animation, 'true']])]])
  const right = replica(B)
  for (const device of [left, right]) {
    await device.engine.testConnection(draft)
    await device.engine.confirm((await device.engine.prepare(draft, ['reader-settings'])).token, [])
  }
  right.values.get('reader-settings').set(animation, 'false')
  await right.engine.syncNow()
  const server = servers.get(draft.directory)
  server.failures.push('412', 'lost-response')
  left.values.get('reader-settings').set(pageNumber, 'false')
  await assert.rejects(left.engine.syncNow(), /sync_remote_result_unknown/)
  const before = structuredClone(server.head)
  const writes = server.published.length
  await left.engine.syncNow()
  assert.equal(left.values.get('reader-settings').get(animation), 'false')
  assert.equal(server.published.length, writes)
  assert.deepEqual(server.head, before)
  const received = server.head.datasets.flatMap(dataset => dataset.shards
    .flatMap(ref => wire.decodeSyncShard(dataset.id, ref, server.objects.get(wire.syncShardPath(ref)), data.syncBucketKey)))
    .find(fact => fact.key === animation)
  assert.equal(received.values[0].version.replica, B)
})

// The redesigned connection form separates testing from real data actions.
// This replaces the former test-triggered recovery expectation: a lost reply
// must survive every probe until the user explicitly retries synchronization.
test('connection tests leave a sent commit untouched until an explicit sync retry', async () => {
  const { replica, draft, servers } = engineFixture()
  const mode = data.syncKey(['global', 'image-fit'])
  const left = replica(A, [['reader-settings', new Map([[mode, '"contain"']])]])
  const right = replica(B, [['reader-settings', new Map([[mode, '"fit_width"']])]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['reader-settings'])).token, [])
  assert.equal(await right.engine.testConnection(draft), false)
  const preview = await right.engine.prepare(draft, ['reader-settings'])
  const server = servers.get(draft.directory)
  server.failures.push('lost-response')
  await assert.rejects(right.engine.confirm(preview.token, [{ group: 'reader-settings', key: mode, useLocal: false }]),
    /sync_remote_result_unknown/)
  assert.equal(right.engine.active(), undefined)
  const accepted = structuredClone(server.head)
  const writes = server.published.length
  assert.equal(await right.engine.testConnection(draft), false)
  assert.equal(await right.engine.testConnection(draft, ['shelf']), false)
  assert.equal(await right.engine.testConnection({ ...draft, password: 'different' }, ['reader-settings']), false)
  assert.equal(right.engine.active(), undefined)
  assert.equal(right.values.get('reader-settings').get(mode), '"fit_width"')
  const intent = structuredClone(right.store.load().intent)
  assert.equal(await right.engine.testConnection(draft, ['reader-settings']), false)
  assert.equal(right.engine.active(), undefined)
  assert.equal(right.values.get('reader-settings').get(mode), '"fit_width"')
  assert.deepEqual(right.store.load().intent, intent)
  assert.equal(server.published.length, writes)
  assert.deepEqual(server.head, accepted)
  await right.engine.syncNow()
  assert.equal(right.values.get('reader-settings').get(mode), '"contain"')
  assert.equal(right.engine.active().revision, accepted.revision)
  assert.equal(server.published.length, writes)
  assert.deepEqual(server.head, accepted)
})

test('new credentials and a different group leave an earlier unconfirmed submission isolated', async () => {
  const { replica, draft, servers } = engineFixture()
  const mode = data.syncKey(['global', 'image-fit'])
  const left = replica(A, [['reader-settings', new Map([[mode, '"contain"']])]])
  const right = replica(B, [['reader-settings', new Map([[mode, '"fit_width"']])]])
  await left.engine.testConnection(draft)
  await left.engine.confirm((await left.engine.prepare(draft, ['reader-settings'])).token, [])
  await right.engine.testConnection(draft)
  const preview = await right.engine.prepare(draft, ['reader-settings'])
  servers.get(draft.directory).failures.push('lost-response')
  await assert.rejects(right.engine.confirm(preview.token, [{ group: 'reader-settings', key: mode, useLocal: false }]),
    /sync_remote_result_unknown/)
  const previous = right.store.load().intent.connection
  const edited = { ...draft, password: 'different' }
  assert.equal(await right.engine.testConnection(edited, ['shelf']), false)
  const shelf = await right.engine.prepare(edited, ['shelf'])
  assert.equal(shelf.earlierUnconfirmed, 1)
  await right.engine.confirm(shelf.token, [])
  const archived = right.store.load().archivedIntents
  assert.equal(archived[0].connection.manifestHash, previous.manifestHash)
  assert.equal(archived[0].connection.credential, '')
  assert.equal(right.values.get('reader-settings').get(mode), '"fit_width"')
})
