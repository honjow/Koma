const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_v4.cjs'), 'utf8') +
  '\nreturn { transportFixture, engineFixture, wire, facts, data, A, B, edit, dot, seedV3Revision, seedArchivedV3 };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { transportFixture, engineFixture, wire, facts, data, A, B, edit, dot, seedV3Revision, seedArchivedV3 } = support

for (const damaged of [false, true]) test('cold Engine batches v3 archive reads' + (damaged ? ' and retries a damaged copy' : ''), async () => {
  const f = transportFixture('https://legacy-batch-' + damaged + '.invalid')
  const factsRows = Array.from({ length: 400 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    return edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const dataset = wire.buildSyncDataset('reader-settings-records', factsRows, 1, undefined, data.syncBucketKey)
  assert.ok(dataset.objects.length >= 40)
  seedV3Revision(f, A, 1, [dataset])
  const groups = new Map()
  for (let i = 0; i < dataset.objects.length; i++) {
    if (i % 4 === 0) continue // Retain ordinary physical v3 files as well.
    const object = dataset.objects[i]
    const name = wire.syncShardPath(object.ref)
    const bucket = object.ref.hash[0]
    const entries = groups.get(bucket) ?? []
    entries.push([name, object.body])
    groups.set(bucket, entries)
    f.files.delete(f.writerRoot + name)
  }
  for (const [bucket, entries] of groups) {
    for (let i = 0; entries.length < 3; i++) {
      const body = JSON.stringify({ filler: i })
      const hash = wire.syncDigest(body)
      if (hash[0] === bucket) entries.push([`object-1-${hash}.json`, body])
    }
    seedArchivedV3(f, `objects/${bucket}/`, entries)
    const dir = f.writerRootV4 + `legacy-v3/objects/${bucket}/`
    const first = [...f.files.keys()].find(name => name.startsWith(dir + 'pack-'))
    assert.ok(first)
    const second = first.replace(`pack-${A}-`, `pack-${B}-`)
    f.files.set(second, f.files.get(first))
    if (damaged && bucket === [...groups.keys()][0]) f.files.set(first, 'damaged')
  }
  const fixture = engineFixture(f.WriterWebDav)
  const reader = fixture.replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  const start = f.trace.length
  await reader.engine.syncNow()
  assert.equal(reader.values.get('reader-settings').size, factsRows.length)
  const reads = f.trace.slice(start).filter(row => row.method === 'GET' && row.address.includes('/legacy-v3/objects/'))
  assert.ok(reads.length <= groups.size + (damaged ? 1 : 0) + 2,
    `expected at most one valid pack read per bucket; got ${reads.length} for ${groups.size} buckets`)
  reader.engine.setEnabled(false)
})

test('an absent archived shard does not apply a partial reader-settings group', async () => {
  const f = transportFixture('https://legacy-batch-missing.invalid')
  const rows = Array.from({ length: 400 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    return edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const dataset = wire.buildSyncDataset('reader-settings-records', rows, 1, undefined, data.syncBucketKey)
  assert.ok(dataset.objects.length >= 40)
  seedV3Revision(f, A, 1, [dataset])
  const missing = dataset.objects[0]
  f.files.delete(f.writerRoot + wire.syncShardPath(missing.ref))
  const bucket = missing.ref.hash[0]
  const filler = []
  for (let i = 0; filler.length < 3; i++) {
    const body = JSON.stringify({ filler: i })
    const hash = wire.syncDigest(body)
    if (hash[0] === bucket) filler.push([`object-1-${hash}.json`, body])
  }
  seedArchivedV3(f, `objects/${bucket}/`, filler)
  const fixture = engineFixture(f.WriterWebDav)
  const reader = fixture.replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  try {
    await assert.rejects(reader.engine.syncNow(), /sync_legacy_archive_unavailable|sync_shard_missing|sync_partial/)
    assert.equal(reader.values.get('reader-settings')?.size ?? 0, 0)
    assert.equal(reader.engine.active(), undefined)
  } finally { reader.engine.setEnabled(false) }
})

test('archive prefetch network failure stops the round without a per-shard request storm', async () => {
  const f = transportFixture('https://legacy-batch-outage.invalid')
  const rows = Array.from({ length: 400 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    return edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
  })
  const dataset = wire.buildSyncDataset('reader-settings-records', rows, 1, undefined, data.syncBucketKey)
  assert.ok(dataset.objects.length >= 40)
  seedV3Revision(f, A, 1, [dataset])
  const groups = new Map()
  for (const object of dataset.objects) {
    const name = wire.syncShardPath(object.ref)
    const bucket = object.ref.hash[0]
    const entries = groups.get(bucket) ?? []
    entries.push([name, object.body])
    groups.set(bucket, entries)
    f.files.delete(f.writerRoot + name)
  }
  for (const [bucket, entries] of groups) {
    for (let i = 0; entries.length < 3; i++) {
      const body = JSON.stringify({ filler: i })
      const hash = wire.syncDigest(body)
      if (hash[0] === bucket) entries.push([`object-1-${hash}.json`, body])
    }
    seedArchivedV3(f, `objects/${bucket}/`, entries)
  }
  const failingBucket = [...groups.keys()].sort()[0]
  const failingDirectory = f.writerRootV4 + `legacy-v3/objects/${failingBucket}/`
  let failures = 0
  f.onRequest(async (method, address) => {
    if (method === 'PROPFIND' && address === failingDirectory && failures++ < 2) {
      throw Object.assign(new Error('temporary network failure'), { code: 2300007 })
    }
  })
  const reader = engineFixture(f.WriterWebDav).replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  const start = f.trace.length
  try {
    await assert.rejects(reader.engine.syncNow(), /sync_network_failed/)
    const requests = f.trace.slice(start)
    const gets = requests.filter(row => row.method === 'GET').length
    const propfinds = requests.filter(row => row.method === 'PROPFIND').length
    assert.ok(gets <= 8, `outage triggered ${gets} GETs`)
    assert.ok(propfinds <= 16, `outage triggered ${propfinds} PROPFINDs`)
    assert.equal(reader.values.get('reader-settings')?.size ?? 0, 0)
  } finally { reader.engine.setEnabled(false) }
})

test('a cold Engine reads 600 distributed shards with far fewer total requests', async () => {
  const f = transportFixture('https://legacy-batch-600.invalid')
  const id = 'reader-settings-records'
  const objects = Array.from({ length: 600 }, (_, i) => {
    const key = data.syncKey(['book-mode', 'org.example.source', 'work-' + i])
    const fact = edit(facts.emptySyncFact(key), dot(A, i + 1), 'set',
      JSON.stringify({ direction: 'right_to_left', mode: 'single_page' }))
    const body = JSON.stringify({ dataset: id, schema: 1, facts: [fact] })
    return { body, ref: { bucket: wire.syncRootBucket(data.syncBucketKey(key)) + '-' + wire.syncDigest(key),
      epoch: 1, hash: wire.syncDigest(body), bytes: Buffer.byteLength(body) } }
  })
  const dataset = { ref: { id, schema: 1, shards: objects.map(item => item.ref) }, objects }
  seedV3Revision(f, A, 1, [dataset])
  const groups = new Map()
  for (let i = 0; i < objects.length; i++) {
    if (i % 10 === 0) continue
    const object = objects[i], name = wire.syncShardPath(object.ref), bucket = object.ref.hash[0]
    const entries = groups.get(bucket) ?? []
    entries.push([name, object.body]); groups.set(bucket, entries)
    f.files.delete(f.writerRoot + name)
  }
  for (const [bucket, entries] of groups) {
    seedArchivedV3(f, `objects/${bucket}/`, entries)
    const dir = f.writerRootV4 + `legacy-v3/objects/${bucket}/`
    const first = [...f.files.keys()].find(name => name.startsWith(dir + 'pack-'))
    assert.ok(first)
    f.files.set(first.replace(`pack-${A}-`, `pack-${B}-`), f.files.get(first))
  }
  const reader = engineFixture(f.WriterWebDav).replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  const start = f.trace.length
  try {
    await reader.engine.syncNow()
    assert.equal(reader.values.get('reader-settings').size, 600)
    const requests = f.trace.slice(start)
    const gets = requests.filter(row => row.method === 'GET').length
    const propfinds = requests.filter(row => row.method === 'PROPFIND').length
    assert.ok(gets + propfinds < 160, `600 shards needed ${gets} GET + ${propfinds} PROPFIND`)
    console.info(`600 shards: GET=${gets} PROPFIND=${propfinds} total=${gets + propfinds}`)
  } finally { reader.engine.setEnabled(false) }
})
