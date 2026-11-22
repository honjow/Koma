const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { randomUUID } = require('node:crypto')
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_v4.cjs'), 'utf8') +
  '\nreturn { transportFixture, engineFixture, wire, facts, data, A, B, edit, dot, seedV3Revision, seedArchivedV3 };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { transportFixture, engineFixture, wire, facts, data, A, B, edit, dot, seedV3Revision, seedArchivedV3 } = support
const { compile } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') + '\nreturn { compile };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)

function diskCache(directory) {
  const counts = { open: 0, written: 0, renamed: 0 }
  const fileIo = {
    OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
    accessSync: fs.existsSync, mkdirSync: name => fs.mkdirSync(name, { recursive: true }),
    statSync: name => { const stat = fs.statSync(name); return { size: stat.size, mtime: stat.mtimeMs / 1000 } },
    readTextSync: name => fs.readFileSync(name, 'utf8'), listFileSync: fs.readdirSync,
    openSync: name => { counts.open++; return { fd: fs.openSync(name, 'w') } },
    writeSync: (fd, body) => { counts.written++; const value = fs.writeSync(fd, body); if (counts.written === 1) counts.sample = [value, Buffer.byteLength(body)]; return value },
    closeSync: file => fs.closeSync(file.fd),
    renameSync: (from, to) => { counts.renamed++; fs.renameSync(from, to) }, unlinkSync: fs.unlinkSync,
  }
  const { DeviceSyncShardCache } = compile('DeviceSyncShardCache', { './DeviceSyncWire': wire,
    '@kit.CoreFileKit': { fileIo }, '@kit.ArkTS': { util: { generateRandomUUID: randomUUID },
      taskpool: { execute: async (fn, ...args) => fn(...args) } } })
  const cache = new DeviceSyncShardCache(directory)
  cache.testCounts = counts
  return cache
}

test('fully archived 600 shards cold-read and then resume after one remote shard changes', async () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-sync-review-'))
  const f = transportFixture('https://legacy-all-600.invalid')
  const id = 'reader-settings-records'
  const entries = Array.from({ length: 600 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    const fact = edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
    const body = JSON.stringify({ dataset: id, schema: 1, facts: [fact] })
    return { fact, body, ref: { bucket: wire.syncRootBucket(data.syncBucketKey(key)) + '-' + wire.syncDigest(key),
      epoch: 1, hash: wire.syncDigest(body), bytes: Buffer.byteLength(body) } }
  })
  const dataset = { ref: { id, schema: 1, shards: entries.map(item => item.ref) }, objects: entries }
  seedV3Revision(f, A, 1, [dataset])
  const buckets = new Map()
  for (const object of entries) {
    const name = wire.syncShardPath(object.ref), bucket = object.ref.hash[0]
    const values = buckets.get(bucket) ?? []; values.push([name, object.body]); buckets.set(bucket, values)
    f.files.delete(f.writerRoot + name)
  }
  for (const [bucket, values] of buckets) {
    seedArchivedV3(f, `objects/${bucket}/`, values)
    const dir = f.writerRootV4 + `legacy-v3/objects/${bucket}/`
    const first = [...f.files.keys()].find(name => name.startsWith(dir + 'pack-'))
    f.files.set(first.replace(`pack-${A}-`, `pack-${B}-`), f.files.get(first))
  }
  const cache = diskCache(cacheDir)
  const reader = engineFixture(f.WriterWebDav, cache).replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  const counts = start => {
    const rows = f.trace.slice(start)
    return Object.fromEntries(['GET', 'PROPFIND', 'PUT'].map(method => [method, rows.filter(row => row.method === method).length]))
  }
  try {
    let start = f.trace.length
    await reader.engine.syncNow()
    const cold = counts(start)
    assert.equal(reader.values.get('reader-settings').size, 600)
    assert.equal(fs.readdirSync(path.join(cacheDir, 'device-sync-shards')).filter(name => name.endsWith('.json')).length, 600,
      `cache operations: ${JSON.stringify(cache.testCounts)}`)
    assert.ok(cold.GET + cold.PROPFIND < 100)
    const old = entries[0]
    const fact = edit(old.fact, dot(A, 10001), 'set', JSON.stringify({ direction: 'left_to_right', mode: 'single_page' }))
    const body = JSON.stringify({ dataset: id, schema: 1, facts: [fact] })
    const updated = { body, ref: { ...old.ref, hash: wire.syncDigest(body), bytes: Buffer.byteLength(body) } }
    const next = { ref: { ...dataset.ref, shards: [updated.ref, ...dataset.ref.shards.slice(1)] }, objects: [updated] }
    seedV3Revision(f, A, 2, [next])
    const restarted = reader.restart()
    start = f.trace.length
    await restarted.syncNow()
    const incremental = counts(start)
    assert.ok(incremental.GET < 15, `expected one changed shard plus heads, got ${JSON.stringify(incremental)}`)
    assert.equal(reader.values.get('reader-settings').get(fact.key), fact.values[0].value)
    const scope = new f.WriterWebDav(f.draft, [], undefined, B).cacheScope()
    const otherScope = new f.WriterWebDav({ ...f.draft, username: 'another-account', password: 'pw' }, [], undefined, B).cacheScope()
    assert.equal(await cache.read(otherScope, 'reader-settings', id, updated.ref), undefined)
    const key = wire.syncDigest(JSON.stringify([scope, 'reader-settings', id, updated.ref.bucket,
      updated.ref.epoch, updated.ref.hash, updated.ref.bytes]))
    const cachedPath = path.join(cacheDir, 'device-sync-shards', key + '.json')
    const damaged = body.replace('left_to_right', 'xxxx_to_right')
    assert.equal(Buffer.byteLength(damaged), Buffer.byteLength(body))
    fs.writeFileSync(cachedPath, damaged)
    const recovered = reader.restart()
    await recovered.syncNow()
    assert.equal(fs.readFileSync(cachedPath, 'utf8'), body, 'same-length corruption must be revalidated and refetched')
    console.info(`600 archived shards cold: ${JSON.stringify(cold)}; after restart and one changed shard: ${JSON.stringify(incremental)}`)
    recovered.setEnabled(false)
    restarted.setEnabled(false)
  } finally { reader.engine.setEnabled(false); fs.rmSync(cacheDir, { recursive: true, force: true }) }
})

test('the current v3 head migrates when its objects exist only in the legacy archive', async () => {
  const f = transportFixture('https://legacy-current-head-migration.invalid')
  const id = 'reader-settings-records'
  const rows = Array.from({ length: 400 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    return edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const dataset = wire.buildSyncDataset(id, rows, 1, undefined, data.syncBucketKey)
  assert.ok(dataset.objects.length >= 40)
  seedV3Revision(f, A, 1, [dataset])
  const archives = new Map()
  for (const object of dataset.objects) {
    const path = wire.syncShardPath(object.ref)
    const bucket = object.ref.hash[0]
    const entries = archives.get(bucket) ?? []
    entries.push([path, object.body])
    archives.set(bucket, entries)
    assert.equal(f.files.delete(f.writerRoot + path), true)
  }
  for (const [bucket, entries] of archives) {
    // The historical archive format requires at least three entries per pack.
    for (let index = 0; entries.length < 3; index++) {
      const key = data.syncKey(['book-mode', 'org.example.source', 'prior-work-' + index])
      const body = JSON.stringify({ dataset: id, schema: 1, facts: [
        edit(facts.emptySyncFact(key), dot(A, index + rows.length + 1), 'set',
          JSON.stringify({ direction: 'left_to_right', mode: 'single_page' })),
      ] })
      const hash = wire.syncDigest(body)
      if (hash[0] === bucket) entries.push(['object-1-' + hash + '.json', body])
    }
    for (const writer of [A, B]) seedArchivedV3(f, 'objects/' + bucket + '/', entries, writer)
  }
  const cold = engineFixture(f.SharedWebDav).replica(B)
  try {
    cold.engine.setSelection(['reader-settings'])
    await cold.engine.saveConfiguration(f.draft)
    cold.engine.setEnabled(true)
    await cold.engine.syncNow()
    const applied = cold.values.get('reader-settings')
    assert.equal(applied.size, rows.length)
    for (let i = 0; i < rows.length; i++) {
      assert.deepEqual(JSON.parse(applied.get(data.syncKey(['book-mode', 'org.example.source', 'work-' + i]))),
        { direction: 'right_to_left', mode: 'single_page' })
    }
    const shared = await new f.SharedWebDav(f.draft).readSharedHead(() => {})
    assert.ok(shared.sharedHeads.length > 0)
  } finally { cold.engine.setEnabled(false) }
})

test('missing another writer shard is not silently reported as a successful full sync', async () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-sync-publish-review-'))
  const f = transportFixture('https://legacy-publish-repair.invalid')
  const id = 'reader-settings-records'
  const rows = Array.from({ length: 400 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    return edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const dataset = wire.buildSyncDataset(id, rows, 1, undefined, data.syncBucketKey)
  seedV3Revision(f, A, 1, [dataset])
  const cache = diskCache(cacheDir)
  const fixtures = engineFixture(f.WriterWebDav, cache)
  const reader = fixtures.replica(B)
  const engines = [reader.engine]
  try {
    reader.engine.setSelection(['reader-settings'])
    await reader.engine.saveConfiguration(f.draft)
    reader.engine.setEnabled(true)
    await reader.engine.syncNow()
    assert.equal(reader.values.get('reader-settings').size, 400)
    const lost = dataset.objects[0]
    f.files.delete(f.writerRoot + wire.syncShardPath(lost.ref))
    const lostKeys = new Set(JSON.parse(lost.body).facts.map(row => row.key))
    const changed = rows.find(row => !lostKeys.has(row.key))
    assert.ok(changed)
    reader.values.get('reader-settings').set(changed.key,
      JSON.stringify({ direction: 'left_to_right', mode: 'single_page' }))
    const restarted = reader.restart(); engines.push(restarted)
    const start = f.trace.length
    await restarted.syncNow()
    const counts = Object.fromEntries(['GET', 'PROPFIND', 'PUT'].map(method =>
      [method, f.trace.slice(start).filter(row => row.method === method).length]))
    const recovered = [...f.files].find(([name, body]) => {
      if (!name.startsWith(f.writerRootV4)) return false
      if (body === lost.body) return true
      try { return JSON.parse(body).entries?.some(entry => entry.body === lost.body) === true } catch { return false }
    })
    const headPut = f.trace.slice(start).find(row => row.method === 'PUT' && /\/[0-9]{16}-/.test(row.address))
    const head = JSON.parse(headPut.body)
    const kept = head.manifest.datasets.find(item => item.id === id).shards.some(ref => ref.hash === lost.ref.hash)
    assert.equal(kept, false)
    assert.equal(recovered, undefined)
    const receiver = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'receiver')))
      .replica('33333333-3333-4333-8333-333333333333')
    engines.push(receiver.engine)
    receiver.engine.setSelection(['reader-settings'])
    await receiver.engine.saveConfiguration(f.draft)
    receiver.engine.setEnabled(true)
    let failure
    try { await receiver.engine.syncNow() } catch (error) { failure = error }
    assert.ok(failure, 'a device without the cached copy must not report successful full sync')
    console.info(`cold device missing-shard error: ${failure.message}`)
    assert.notEqual(receiver.values.get('reader-settings')?.size ?? 0, 400)
    console.info(`400-work local edit with missing unchanged shard: ${JSON.stringify(counts)}`)
  } finally {
    for (const engine of engines) engine.setEnabled(false)
    fs.rmSync(cacheDir, { recursive: true, force: true })
  }
})

test('new publication packs cold-read on another device and one later edit stays incremental', async () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-sync-pack-review-'))
  const f = transportFixture('https://publication-pack-incremental.invalid')
  const initial = new Map(Array.from({ length: 400 }, (_, i) => [
    data.syncKey(['book-mode', 'org.example.source', 'work-' + i]),
    JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }),
  ]))
  const first = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'writer')))
    .replica(A, [['reader-settings', initial]])
  const engines = [first.engine]
  const counts = start => Object.fromEntries(['GET', 'PROPFIND', 'PUT'].map(method =>
    [method, f.trace.slice(start).filter(row => row.method === method).length]))
  try {
    first.engine.setSelection(['reader-settings'])
    await first.engine.saveConfiguration(f.draft)
    first.engine.setEnabled(true)
    let start = f.trace.length
    await first.engine.syncNow()
    const initialWrite = counts(start)
    const packFiles = [...f.files.keys()].filter(name => /\/packs\/pack-/.test(name))
    assert.ok(packFiles.length >= 2, 'initial publication must use duplicate pack files')
    const second = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'reader'))).replica(B)
    engines.push(second.engine)
    second.engine.setSelection(['reader-settings'])
    await second.engine.saveConfiguration(f.draft)
    second.engine.setEnabled(true)
    start = f.trace.length
    await second.engine.syncNow()
    const cold = counts(start)
    assert.equal(second.values.get('reader-settings').size, 400)
    const changed = [...initial.keys()][0]
    const newValue = JSON.stringify({ direction: 'left_to_right', mode: 'single_page' })
    first.values.get('reader-settings').set(changed, newValue)
    const resumed = first.restart(); engines.push(resumed)
    start = f.trace.length
    await resumed.syncNow()
    const oneEdit = counts(start)
    const after = second.restart(); engines.push(after)
    await after.syncNow()
    assert.equal(second.values.get('reader-settings').get(changed), newValue)
    assert.equal(second.values.get('reader-settings').size, 400)
    console.info(`400-work new pack: initial ${JSON.stringify(initialWrite)}, cold reader ${JSON.stringify(cold)}, one edit ${JSON.stringify(oneEdit)}`)
  } finally {
    for (const engine of engines) engine.setEnabled(false)
    fs.rmSync(cacheDir, { recursive: true, force: true })
  }
})

test('own missing publication packs are rebuilt from verified cache before the new head is published', async () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-sync-pack-repair-'))
  const f = transportFixture('https://publication-pack-repair.invalid')
  const initial = new Map(Array.from({ length: 400 }, (_, i) => [
    data.syncKey(['book-mode', 'org.example.source', 'work-' + i]),
    JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }),
  ]))
  const writer = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'writer')))
    .replica(A, [['reader-settings', initial]])
  const engines = [writer.engine]
  try {
    writer.engine.setSelection(['reader-settings'])
    await writer.engine.saveConfiguration(f.draft)
    writer.engine.setEnabled(true)
    await writer.engine.syncNow()
    const packs = [...f.files.keys()].filter(name => /\/packs\/pack-/.test(name))
    assert.ok(packs.length >= 2)
    const shardCacheDir = path.join(cacheDir, 'writer', 'device-sync-shards')
    assert.ok(fs.existsSync(shardCacheDir) && fs.readdirSync(shardCacheDir).length > 0, 'initial publication must persist verified shards')
    for (const name of packs) f.files.delete(name)
    const key = [...initial.keys()][0]
    const value = JSON.stringify({ direction: 'left_to_right', mode: 'single_page' })
    writer.values.get('reader-settings').set(key, value)
    const resumed = writer.restart(); engines.push(resumed)
    const start = f.trace.length
    await resumed.syncNow()
    const counts = Object.fromEntries(['GET', 'PROPFIND', 'PUT'].map(method =>
      [method, f.trace.slice(start).filter(row => row.method === method).length]))
    const receiver = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'receiver'))).replica(B)
    engines.push(receiver.engine)
    receiver.engine.setSelection(['reader-settings'])
    await receiver.engine.saveConfiguration(f.draft)
    receiver.engine.setEnabled(true)
    await receiver.engine.syncNow()
    assert.equal(receiver.values.get('reader-settings').size, 400)
    assert.equal(receiver.values.get('reader-settings').get(key), value)
    console.info(`400-work own missing pack repair: ${JSON.stringify(counts)}`)
  } finally {
    for (const engine of engines) engine.setEnabled(false)
    fs.rmSync(cacheDir, { recursive: true, force: true })
  }
})

test('same-length corruption of both published packs is not hidden by directory listing', async () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-sync-pack-corrupt-'))
  const f = transportFixture('https://publication-pack-corrupt.invalid')
  const initial = new Map(Array.from({ length: 400 }, (_, i) => [
    data.syncKey(['book-mode', 'org.example.source', 'work-' + i]),
    JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }),
  ]))
  const writer = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'writer')))
    .replica(A, [['reader-settings', initial]])
  const engines = [writer.engine]
  try {
    writer.engine.setSelection(['reader-settings'])
    await writer.engine.saveConfiguration(f.draft)
    writer.engine.setEnabled(true)
    await writer.engine.syncNow()
    const packs = [...f.files.keys()].filter(name => /\/packs\/pack-/.test(name))
    assert.ok(packs.length >= 2)
    for (const name of packs) {
      const original = f.files.get(name)
      const damaged = original.replace('right_to_left', 'xxxxx_to_left')
      assert.equal(Buffer.byteLength(damaged), Buffer.byteLength(original))
      assert.notEqual(damaged, original)
      f.files.set(name, damaged)
    }
    const key = [...initial.keys()][0]
    const value = JSON.stringify({ direction: 'left_to_right', mode: 'single_page' })
    writer.values.get('reader-settings').set(key, value)
    const resumed = writer.restart(); engines.push(resumed)
    await resumed.syncNow()
    const receiver = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'receiver'))).replica(B)
    engines.push(receiver.engine)
    receiver.engine.setSelection(['reader-settings'])
    await receiver.engine.saveConfiguration(f.draft)
    receiver.engine.setEnabled(true)
    await receiver.engine.syncNow()
    assert.equal(receiver.values.get('reader-settings').size, 400)
    assert.equal(receiver.values.get('reader-settings').get(key), value)
  } finally {
    for (const engine of engines) engine.setEnabled(false)
    fs.rmSync(cacheDir, { recursive: true, force: true })
  }
})

test('damaged cover packs do not block reading progress on another device', async () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-sync-cover-domain-'))
  const f = transportFixture('https://publication-cover-domain.invalid')
  const source = 'org.example.source'
  const position = data.syncKey(['position', source, 'work-0', 'chapter-0'])
  const initial = new Map([[position, JSON.stringify({ page: 2, total: 9, date: 100 })]])
  for (let i = 0; i < 400; i++) {
    initial.set(data.syncKey(['cover', source, 'work-' + i]), JSON.stringify('https://example.invalid/' + i + '.jpg'))
  }
  const writer = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'writer')))
    .replica(A, [['reading', initial]])
  const receiver = engineFixture(f.WriterWebDav, diskCache(path.join(cacheDir, 'receiver'))).replica(B)
  const engines = [writer.engine, receiver.engine]
  try {
    for (const device of [writer, receiver]) {
      device.engine.setSelection(['reading'])
      await device.engine.saveConfiguration(f.draft)
      device.engine.setEnabled(true)
      await device.engine.syncNow()
    }
    const coverPacks = [...f.files].filter(([name, body]) => {
      if (!/\/packs\/pack-/.test(name)) return false
      try { return JSON.parse(body).entries.some(entry => JSON.parse(entry.body).dataset === 'reading-cover-records') }
      catch { return false }
    })
    assert.ok(coverPacks.length >= 2, 'scenario requires a multi-shard cover pack with two copies')
    for (const [name, body] of coverPacks) {
      const damaged = body.replace('example.invalid', 'xxxxxxx.invalid')
      assert.notEqual(damaged, body)
      assert.equal(Buffer.byteLength(damaged), Buffer.byteLength(body))
      f.files.set(name, damaged)
    }
    const latest = JSON.stringify({ page: 5, total: 9, date: 200 })
    writer.values.get('reading').set(position, latest)
    writer.engine.recordEdits('reading', [{ key: position, kind: 'set', value: latest }])
    await writer.engine.syncNow()
    await receiver.engine.syncNow()
    assert.equal(receiver.values.get('reading').get(position), latest)
  } finally {
    for (const engine of engines) engine.setEnabled(false)
    fs.rmSync(cacheDir, { recursive: true, force: true })
  }
})
