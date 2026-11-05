const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const { createHash, randomUUID } = require('node:crypto')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const root = path.resolve(__dirname, '../entry/src/main/ets/deviceSync')
function compile(file, ports = {}) {
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8')
  const compiled = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  const exports = {}
  new Function('require', 'exports', compiled)(key => {
    assert.ok(Object.hasOwn(ports, key), `Unexpected import ${key}`)
    return ports[key]
  }, exports)
  return exports
}

const facts = compile('DeviceSyncFacts')
const wire = compile('DeviceSyncWire', {
  './DeviceSyncFacts': facts,
  '@kit.ArkTS': { util: { TextEncoder: class { encodeInto(text) { return Buffer.from(text) } } } },
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

test('MangaDex public work proof accepts a romanized primary title and safe alternative titles', async () => {
  const source = data.MANGADEX_SYNC_SOURCE
  const manga = '65208a20-4253-42c8-b0e7-56524bbe795b'
  let attributes = { title: { 'zh-ro': 'Xīngjiǎ Húnjiàng Zhuàn' }, altTitles: [{ en: 'Legend of Star General' }] }
  const { DeviceSyncPublicSources } = compile('DeviceSyncPublicSource', {
    '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 1 }, createHttp: () => ({
      async request(address) {
        assert.equal(address, `https://api.mangadex.org/manga/${manga}`)
        const response = { result: 'ok', data: { id: manga, attributes } }
        return { responseCode: 200, result: new TextEncoder().encode(JSON.stringify(response)).buffer }
      },
      destroy() {},
    }) } },
    '@kit.ArkTS': { util: { TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) } } },
    '@kit.CoreFileKit': {},
    '../sourceRuntime/SourceRuntimeAppRegistry': {
      getInstalledSourcePackage: () => ({ enabled: true, version: '0.1.25', catalogOrigin: data.SYNC_OFFICIAL_CATALOG }),
      appSourceRuntimeRegistry: { lookup: () => ({ entry: { manifestId: source, manifestVersion: '0.1.25' } }) },
    },
    '../sourceRuntime/SourceIndexMetadata': { resolveIndexDocumentUrl: address => address, subscriptionIdentity: address => address },
    './DeviceSyncData': data,
    './DeviceSyncWire': { ...wire, syncDigestBytes: () => 'ff51c584cbb49819f073d0718d7b76fe855588717982effe033159096d4caed3' },
  })
  const read = () => new DeviceSyncPublicSources().work(source, `mdx:${manga}`, true)
  assert.equal((await read()).title, 'Legend of Star General')
  attributes.altTitles[0].en = 'token: rejected'
  assert.equal((await read()).title, 'Xīngjiǎ Húnjiàng Zhuàn')
  attributes.title['zh-ro'] = 'https://example.invalid/private'
  assert.equal(await read(), undefined)
  attributes.title = 'invalid primary title shape'
  assert.equal(await read(), undefined)
})

function engineFixture() {
  const assets = new Map()
  const servers = new Map()
  const clone = value => value === undefined ? undefined : structuredClone(value)
  class Provider {
    constructor(draft) {
      if (!servers.has(draft.directory)) servers.set(draft.directory, {
        tag: '', head: undefined, objects: new Map(), published: [], failures: [],
      })
      this.server = servers.get(draft.directory)
    }
    async probe(_id, guard) { guard() }
    async readManifest(guard, expected = '') {
      guard()
      const { head, tag } = this.server
      if (expected && expected !== tag) throw new Error('sync_preview_changed')
      return { manifest: clone(head), etag: tag, hash: head ? wire.syncDigest(JSON.stringify(head)) : '' }
    }
    async readObject(ref, guard) {
      guard()
      return this.server.objects.get(wire.syncShardPath(ref))
    }
    async storeObject(object, guard) {
      guard()
      this.server.objects.set(wire.syncShardPath(object.ref), object.body)
    }
    async publish(head, tag, guard) {
      guard()
      this.server.published.push(clone(head))
      if (this.server.tag !== tag) return false
      const failure = this.server.failures.shift()
      if (failure === '412') return false
      this.server.head = clone(head)
      this.server.tag = '"' + head.revision + '"'
      if (failure === 'lost-response') throw new Error('sync_network_failed')
      return true
    }
    async sweepable() { return [] }
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
    './DeviceSyncStorage': storagePort, './DeviceSyncWebDav': { DeviceSyncWebDav: Provider },
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID } },
  })
  const draft = { directory: 'https://local-fixture.invalid', username: '', password: '' }
  function replica(id, initial = []) {
    let document = { schema: 1, replica: id, counter: 0, probes: [] }
    const values = new Map(initial)
    const snapshotExtras = new Map()
    const store = {
      load: () => document,
      update(change) { const next = clone(document); change(next); document = next },
    }
    const owner = {
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
    return { engine: new DeviceSyncEngine(store, owner), values, store, snapshotExtras }
  }
  return { replica, draft, servers }
}

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

test('first conflict is deferred across runs and a choice for the other device is honored', async () => {
  const fixture = engineFixture()
  const mode = data.syncKey(['global', 'image-fit'])
  const animation = data.syncKey(['global', 'animation'])
  const left = fixture.replica(A, [['reader-settings', new Map([[mode, '"fit_width"']])]])
  const right = fixture.replica(B, [['reader-settings', new Map([[mode, '"contain"']])]])
  await left.engine.testConnection(fixture.draft)
  await left.engine.confirm((await left.engine.prepare(fixture.draft, ['reader-settings'])).token, [])
  await right.engine.testConnection(fixture.draft)
  const preview = await right.engine.prepare(fixture.draft, ['reader-settings'])
  assert.equal(preview.conflicts.length, 1)
  assert.equal(preview.groups[0].download, 0, 'an unresolved choice is not a download')
  await right.engine.confirm(preview.token, [])
  assert.equal(right.values.get('reader-settings').get(mode), '"contain"')
  right.values.get('reader-settings').set(animation, 'false')
  await right.engine.syncNow()
  await left.engine.syncNow()
  assert.equal(right.values.get('reader-settings').get(mode), '"contain"')
  assert.equal(left.values.get('reader-settings').get(mode), '"fit_width"')
  assert.equal(left.values.get('reader-settings').get(animation), 'false', 'ordinary sync continues for unrelated items')
  const next = await right.engine.prepare(fixture.draft, ['reader-settings'])
  await right.engine.confirm(next.token, [{ group: 'reader-settings', key: mode, useLocal: false }])
  assert.equal(right.values.get('reader-settings').get(mode), '"fit_width"')
  assert.equal(right.engine.active().reviewRequired, false)
})

test('a deferred book mode stays local even when source verification temporarily omits it', async () => {
  const { replica, draft } = engineFixture()
  const bookMode = data.syncKey(['book-mode', ...data.syncKeyParts(key).slice(1, 3)])
  const local = JSON.stringify({ mode: 'single_page', direction: 'right_to_left' })
  const other = JSON.stringify({ mode: 'vertical_page', direction: 'right_to_left' })
  const left = replica(A, [['reader-settings', new Map([[bookMode, other]])]])
  const right = replica(B, [['reader-settings', new Map([[bookMode, local]])]])
  for (const device of [left, right]) {
    await device.engine.testConnection(draft)
    await device.engine.confirm((await device.engine.prepare(draft, ['reader-settings'])).token, [])
  }
  right.snapshotExtras.set('reader-settings', { values: [] })
  await right.engine.syncNow()
  assert.equal(right.values.get('reader-settings').get(bookMode), local)
  assert.equal(right.engine.active().reviewRequired, true)
  right.snapshotExtras.delete('reader-settings')
  assert.equal((await right.engine.prepare(draft, ['reader-settings'])).conflicts[0].key, bookMode)
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

test('an explicit reading decision observes both concurrently saved page positions', async () => {
  const { replica, draft } = engineFixture()
  const left = replica(A, [['reading', new Map([[key, position(1)]])]])
  const right = replica(B)
  for (const device of [left, right]) {
    await device.engine.testConnection(draft)
    await device.engine.confirm((await device.engine.prepare(draft, ['reading'])).token, [])
  }
  left.engine.recordEdits('reading', [{ key, kind: 'set', value: position(3) }])
  right.engine.recordEdits('reading', [{ key, kind: 'set', value: position(4) }])
  await left.engine.syncNow()
  await right.engine.syncNow()
  assert.deepEqual(new Set(right.engine.readingDecisions()[0].values), new Set([position(3), position(4)]))
  right.snapshotExtras.set('reading', { protectedKeys: [key] })
  await assert.rejects(right.engine.chooseReadingDecision(key, position(3)), /sync_reading_proof_pending/)
  assert.equal(right.engine.readingDecisions().length, 1)
  right.snapshotExtras.delete('reading')
  const chosen = await right.engine.chooseReadingDecision(key, position(3))
  right.snapshotExtras.set('reading', { protectedKeys: [key] })
  await right.engine.syncNow()
  assert.equal(right.engine.readingWritePending(chosen), true)
  right.snapshotExtras.delete('reading')
  await right.engine.syncNow()
  await left.engine.syncNow()
  assert.equal(left.values.get('reading').get(key), position(3))
  assert.equal(right.values.get('reading').get(key), position(3))
  assert.equal(right.engine.readingDecisions().length, 0)
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

test('the first connection form retries the exact committed preview before proposing another merge', async () => {
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
  assert.equal(await right.engine.testConnection(draft, ['reader-settings']), true)
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
