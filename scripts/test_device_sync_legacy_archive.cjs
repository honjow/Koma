const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')

const { compile, wire, facts, A, B } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { compile, wire, facts, A, B };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const codec = compile('DeviceSyncLegacyArchiveCodec', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire })
const archive = compile('DeviceSyncLegacyArchive', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire,
  './DeviceSyncLegacyArchiveCodec': codec,
  '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: { execute: async (fn, ...args) => fn(...args) } } })

function fixture() {
  const originals = new Map(), packs = new Map(), pending = new Map(), operations = []
  let fail = () => {}
  const list = (map, directory) => [...new Set([...map.keys()].filter(key => key.startsWith(directory) && key !== directory)
    .map(key => key.slice(directory.length)).map(rest => rest.includes('/') ? rest.slice(0, rest.indexOf('/') + 1) : rest))]
  const store = {
    async readOriginal(key) { operations.push(['readOriginal', key]); fail('readOriginal', key); return originals.get(key) },
    async listOriginal(key) { operations.push(['listOriginal', key]); fail('listOriginal', key); return list(originals, key) },
    async removeOriginal(key) { operations.push(['removeOriginal', key]); fail('removeOriginal', key); originals.delete(key) },
    async readArchive(key) { operations.push(['readArchive', key]); fail('readArchive', key); return packs.get(key) },
    async listArchive(key) { operations.push(['listArchive', key]); fail('listArchive', key); return list(packs, key) },
    async ensureArchive(key) { operations.push(['ensureArchive', key]); fail('ensureArchive', key) },
    async writeArchive(key, value) { operations.push(['writeArchive', key]); fail('writeArchive', key); packs.set(key, value) },
    async removeArchive(key) { operations.push(['removeArchive', key]); fail('removeArchive', key); packs.delete(key) },
    async loadPending() { return [...pending.values()].map(row => ({ ...row })) },
    async recordPending(row) { pending.set(row.path, { ...row }) },
    async forgetPending(key) { pending.delete(key) },
    async deferPending(key, startedAt, nextCheckAt, checks, awaitingListing) {
      const row = pending.get(key)
      if (row?.startedAt === startedAt) pending.set(key, { ...row, nextCheckAt, checks, awaitingListing })
    },
  }
  return { originals, packs, pending, operations, store, fault: fn => { fail = fn } }
}

function object(body) { return 'object-1-' + wire.syncDigest(body) + '.json' }
function commit(writer, revision, body) {
  const segment = Math.floor((revision - 1) / 128).toString().padStart(14, '0')
  return writer + '/' + segment + '/' + revision.toString().padStart(16, '0') + '-' + wire.syncDigest(body) + '.json'
}
function relatedObjects(count) {
  const result = []
  for (let i = 0; result.length < count; i++) {
    const body = JSON.stringify({ source: 'original', value: i })
    const name = object(body)
    if (wire.syncDigest(body).startsWith('a')) result.push([name, body])
  }
  return result
}

test('shared v3 objects and old writer commits retain exact bytes while current heads stay in place', async () => {
  const f = fixture()
  const objects = relatedObjects(4)
  const commits = []
  for (const writer of [A, B]) for (let i = 126; i <= 130; i++) {
    const body = JSON.stringify({ writer, revision: i, opaque: { futureGroup: [i] } })
    commits.push([commit(writer, i, body), body])
  }
  for (const [name, body] of objects.concat(commits)) f.originals.set(name, body)
  const names = objects.concat(commits).map(row => row[0])
  const result = await archive.archiveLegacyV3(f.store, names)
  for (const [name, body] of objects) {
    assert.equal(f.originals.has(name), false)
    assert.equal(await archive.readArchivedLegacyV3(f.store, name), body)
  }
  for (const [name, body] of commits) {
    const revision = Number(name.split('/')[2].slice(0, 16))
    assert.equal(f.originals.has(name), revision >= 129)
    if (revision < 129) assert.equal(await archive.readArchivedLegacyV3(f.store, name), body)
  }
  assert.ok(result.archived.length > 0)
  const firstSegment = '00000000000000'
  const enumerated = await archive.listArchivedLegacyV3Commits(f.store, A, firstSegment)
  assert.deepEqual(enumerated, commits.filter(([name]) => name.startsWith(A + '/' + firstSegment + '/'))
    .map(([name]) => name).sort().reverse())
})

test('a failed or invisible second copy never removes an original', async () => {
  for (const mode of ['write', 'list']) {
    const f = fixture(), objects = relatedObjects(3)
    for (const [name, body] of objects) f.originals.set(name, body)
    let count = 0
    if (mode === 'write') f.fault(operation => { if (operation === 'writeArchive' && ++count === 2) throw Error('offline') })
    else f.store.listArchive = async () => []
    await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(row => row[0])))
    assert.equal(f.originals.size, objects.length)
    f.fault(() => {})
  }
})

test('one damaged copy is ignored but losing every copy is reported', async () => {
  const f = fixture(), objects = relatedObjects(3)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.map(row => row[0]))
  const copies = [...f.packs.keys()]
  assert.equal(copies.length, 2)
  f.packs.set(copies[0], 'broken')
  assert.equal(await archive.readArchivedLegacyV3(f.store, objects[0][0]), objects[0][1])
  f.packs.set(copies[1], 'broken')
  await assert.rejects(archive.readArchivedLegacyV3(f.store, objects[0][0]), /sync_legacy_archive_incomplete/)
})

test('deletion interruption is resumable and a reappearing old object remains recoverable', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  let count = 0
  f.fault(operation => { if (operation === 'removeOriginal' && ++count === 2) throw Error('offline') })
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(row => row[0])), /offline/)
  for (const [name, body] of objects) assert.equal(await archive.readArchivedLegacyV3(f.store, name), body)
  f.fault(() => {})
  await archive.archiveLegacyV3(f.store, objects.map(row => row[0]))
  f.originals.set(objects[0][0], objects[0][1])
  assert.equal(await archive.readArchivedLegacyV3(f.store, objects[0][0]), objects[0][1])
})

test('a bounded pass preserves unprocessed files and rejects changed original bytes', async () => {
  const f = fixture(), objects = relatedObjects(132)
  for (const [name, body] of objects) f.originals.set(name, body)
  f.originals.set(objects[1][0], 'bad body')
  const result = await archive.archiveLegacyV3(f.store, objects.map(row => row[0]))
  assert.equal(result.remaining.length, 4)
  assert.ok(result.skipped.includes(objects[1][0]))
  assert.equal(f.originals.get(objects[1][0]), 'bad body')
  for (const name of result.remaining) assert.ok(f.originals.has(name))
})

test('protected heads do not create repeated packs on any pass', async () => {
  const f = fixture(), names = []
  for (let revision = 1; revision <= 2; revision++) {
    const body = JSON.stringify({ revision })
    const name = commit(A, revision, body)
    f.originals.set(name, body); names.push(name)
  }
  for (let i = 0; i < 5; i++) await archive.archiveLegacyV3(f.store, names)
  assert.equal(f.packs.size, 0)
  assert.equal(f.originals.size, 2)
})

test('a stale listing can archive an old witness without losing its exact path', async () => {
  const f = fixture(), commits = []
  for (let revision = 1; revision <= 6; revision++) {
    const body = JSON.stringify({ revision })
    const name = commit(A, revision, body)
    f.originals.set(name, body); commits.push([name, body])
  }
  const listOriginal = f.store.listOriginal
  f.store.listOriginal = async directory => (await listOriginal(directory)).filter(name => !name.startsWith('0000000000000006-'))
  await archive.archiveLegacyV3(f.store, commits.map(item => item[0]))
  assert.equal(f.originals.has(commits[5][0]), false)
  assert.equal(await archive.readArchivedLegacyV3(f.store, commits[5][0], () => {}, true), commits[5][1])
  f.store.listArchive = async () => []
  await assert.rejects(archive.readArchivedLegacyV3(f.store, commits[5][0], () => {}, true), /sync_legacy_archive_unavailable/)
})

test('repeated failures before or during deletion reuse the two verified packs', async () => {
  for (const failAt of [0, 2]) {
    const f = fixture(), objects = relatedObjects(6)
    for (const [name, body] of objects) f.originals.set(name, body)
    const failures = failAt === 0 ? 3 : 1
    for (let pass = 0; pass < failures; pass++) {
      let count = 0
      f.fault(operation => { if (operation === 'removeOriginal' && (failAt === 0 || ++count === failAt)) throw Error('offline') })
      await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(row => row[0])), /offline/)
      assert.equal(f.packs.size, 2)
    }
    f.fault(() => {})
    await archive.archiveLegacyV3(f.store, objects.map(row => row[0]))
    assert.equal(f.originals.size, 0)
    assert.equal(f.packs.size, 2)
  }
})

test('a repeatedly failing second copy reuses the first verified copy', async () => {
  const f = fixture(), objects = relatedObjects(5)
  for (const [name, body] of objects) f.originals.set(name, body)
  let attempts = 0
  f.fault(operation => { if (operation === 'writeArchive' && ++attempts > 1) throw Error('offline') })
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /offline/)
  assert.equal(f.packs.size, 1)
  for (let pass = 0; pass < 3; pass++) {
    await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /offline/)
    assert.equal(f.packs.size, 1)
    assert.equal(f.originals.size, 5)
  }
  f.fault(() => {})
  for (const row of f.pending.values()) row.startedAt = 0 // Backoff elapsed while the network recovered.
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  assert.equal(f.packs.size, 2)
  assert.equal(f.originals.size, 0)
})

test('one failed second copy resumes immediately when the network returns', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  let attempts = 0
  f.fault(operation => { if (operation === 'writeArchive' && ++attempts === 2) throw Error('offline') })
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /offline/)
  f.fault(() => {})
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  assert.equal(f.originals.size, 0)
  assert.equal(f.packs.size, 2)
  assert.equal(f.pending.size, 1)
  const late = [...f.pending.keys()][0]
  f.packs.set(late, [...f.packs.values()][0])
  f.pending.get(late).nextCheckAt = 0
  assert.equal(f.packs.size, 3)
  await archive.reconcileLegacyArchivePending(f.store)
  assert.equal(f.packs.size, 2)
  assert.equal(f.pending.size, 1, 'a timed-out PUT can still arrive after deletion')
  f.packs.set(late, 'a late truncated upload')
  f.pending.get(late).nextCheckAt = 0
  await archive.reconcileLegacyArchivePending(f.store)
  assert.equal(f.packs.has(late), false)
  assert.equal(f.pending.size, 1)
  assert.equal(await archive.readArchivedLegacyV3(f.store, objects[0][0], () => {}, true), objects[0][1])
})

test('an accepted timeout hidden from listing is remembered without repeated PUTs', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  const write = f.store.writeArchive
  let hidden, injected = false
  f.store.writeArchive = async (name, body) => {
    await write(name, body)
    if (!injected) { injected = true; hidden = name; throw Error('timeout') }
  }
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /timeout/)
  const list = f.store.listArchive
  f.store.listArchive = async dir => (await list(dir)).filter(name => dir + name !== hidden)
  const writes = f.operations.filter(item => item[0] === 'writeArchive').length
  for (let pass = 0; pass < 3; pass++) {
    await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /sync_legacy_archive_unconfirmed/)
    assert.equal(f.operations.filter(item => item[0] === 'writeArchive').length, writes)
    assert.equal(f.originals.size, 4)
  }
  f.store.listArchive = list
  for (const row of f.pending.values()) row.nextCheckAt = 0 // Scheduled recheck after visibility recovers.
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  assert.equal(f.originals.size, 0)
  for (const row of f.pending.values()) row.nextCheckAt = 0
  await archive.reconcileLegacyArchivePending(f.store)
  assert.equal(f.packs.size, 2)
  assert.equal(f.pending.size, 1)
})

test('absent timed-out paths are polled with progressive durable backoff', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  f.fault(operation => { if (operation === 'writeArchive') throw Error('offline') })
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /offline/)
  f.fault(() => {})
  const path = [...f.pending.keys()][0]
  f.operations.length = 0
  await archive.reconcileLegacyArchivePending(f.store)
  assert.equal(f.pending.get(path).checks, 1)
  assert.ok(f.pending.get(path).nextCheckAt > Date.now())
  await archive.reconcileLegacyArchivePending(f.store)
  assert.equal(f.operations.filter(item => item[0] === 'readArchive' && item[1] === path).length, 1)
  f.pending.get(path).nextCheckAt = 0
  const before = Date.now()
  await archive.reconcileLegacyArchivePending(f.store)
  assert.equal(f.pending.get(path).checks, 2)
  assert.ok(f.pending.get(path).nextCheckAt >= before + 60000)
})

test('duplicate DAV entries for one pack cannot masquerade as two copies', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  let attempts = 0
  f.fault(operation => { if (operation === 'writeArchive' && ++attempts > 1) throw Error('offline') })
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /offline/)
  const list = f.store.listArchive
  f.store.listArchive = async directory => { const names = await list(directory); return names.concat(names) }
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /offline/)
  assert.equal(f.packs.size, 1)
  assert.equal(f.originals.size, objects.length)
})

test('an unrelated damaged pack does not hide a valid requested entry', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  const directory = [...f.packs.keys()][0].replace(/pack-[^/]+$/, '')
  f.packs.set(directory + 'pack-' + randomUUID() + '-' + '0'.repeat(64) + '.json', 'damaged')
  assert.equal(await archive.readArchivedLegacyV3(f.store, objects[0][0], () => {}, true), objects[0][1])
})

test('a late truncated old pack attempt cannot destroy the replacement copy', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  const write = f.store.writeArchive
  let firstPath
  f.store.writeArchive = async (path, body) => {
    await write(path, body)
    if (firstPath === undefined) { firstPath = path; throw Error('timeout') }
  }
  await assert.rejects(archive.archiveLegacyV3(f.store, objects.map(item => item[0])), /timeout/)
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  assert.equal(f.originals.size, 0)
  f.packs.set(firstPath, 'late truncated content')
  assert.equal(await archive.readArchivedLegacyV3(f.store, objects[0][0], () => {}, true), objects[0][1])
})

test('1062 old commits compact in bounded passes and a cold witness reads its original body', async () => {
  const f = fixture(), entries = []
  for (let revision = 1; revision <= 1062; revision++) {
    const body = JSON.stringify({ revision, future: { unknown: revision } })
    const name = commit(A, revision, body)
    f.originals.set(name, body); entries.push([name, body])
  }
  let pending = entries.map(entry => entry[0])
  let maxCalls = 20
  while (pending.length > 0 && maxCalls-- > 0) pending = (await archive.archiveLegacyV3(f.store, pending)).remaining
  assert.equal(pending.length, 0)
  assert.equal(f.originals.size, 2)
  assert.ok(f.packs.size <= 20)
  for (const index of [0, 127, 128, 510, 1000]) {
    assert.equal(await archive.readArchivedLegacyV3(f.store, entries[index][0], () => {}, true), entries[index][1])
  }
})

test('a failed concurrent read drains every in-flight request before returning', async () => {
  const f = fixture(), objects = relatedObjects(4)
  for (const [name, body] of objects) f.originals.set(name, body)
  let release, failFirst, entered
  const gate = new Promise(resolve => { release = resolve })
  const failGate = new Promise(resolve => { failFirst = resolve })
  const ready = new Promise(resolve => { entered = resolve })
  let active = 0, peak = 0, settled = false
  const read = f.store.readOriginal
  f.store.readOriginal = async name => {
    active++; peak = Math.max(peak, active)
    if (active === 4) entered()
    await (name === objects[0][0] ? failGate : gate)
    active--
    if (name === objects[0][0]) throw Error('offline')
    return read(name)
  }
  const operation = archive.archiveLegacyV3(f.store, objects.map(item => item[0])).finally(() => { settled = true })
  const rejected = assert.rejects(operation, /offline/)
  await ready
  assert.equal(peak, 4)
  assert.equal(settled, false)
  failFirst()
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(settled, false, 'failure must wait for the other reads to drain')
  release()
  await rejected
  assert.equal(active, 0)
  assert.equal(f.originals.size, 4)
})

test('concurrent archive reads share discovery, and evicted targets remain readable', async () => {
  const f = fixture(), objects = relatedObjects(6)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  f.operations.length = 0
  const reader = new archive.SyncLegacyArchiveReader()
  const guard = () => {}
  const values = await Promise.all(objects.map(item => reader.read(f.store, item[0], guard, true)))
  assert.deepEqual(values, objects.map(item => item[1]))
  assert.equal(f.operations.filter(item => item[0] === 'listArchive').length, 1)
  const small = new archive.SyncLegacyArchiveReader(100, 1)
  assert.equal(await small.read(f.store, objects[0][0], guard, true), objects[0][1])
})

test('archive discovery does not share one caller cancellation with another guard', async () => {
  const f = fixture(), objects = relatedObjects(3)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  let release, arrived
  const gate = new Promise(resolve => { release = resolve })
  const both = new Promise(resolve => { arrived = resolve })
  const read = f.store.readArchive
  let waiting = 0, cancelled = false
  f.store.readArchive = async name => { if (++waiting === 2) arrived(); await gate; return read(name) }
  const reader = new archive.SyncLegacyArchiveReader()
  const guardA = () => { if (cancelled) throw Error('cancelled') }
  const guardB = () => {}
  const a = reader.read(f.store, objects[0][0], guardA, true)
  const rejected = assert.rejects(a, /cancelled/)
  const b = reader.read(f.store, objects[1][0], guardB, true)
  await both
  cancelled = true
  release()
  await rejected
  assert.equal(await b, objects[1][1])
})

test('one maintenance session does not rescan old packs for each new batch', async () => {
  const f = fixture(), objects = relatedObjects(6)
  for (const [name, body] of objects) f.originals.set(name, body)
  const session = new archive.SyncLegacyArchiveSession()
  await archive.archiveLegacyV3(f.store, objects.slice(0, 3).map(item => item[0]), () => {}, session)
  const old = new Set(f.packs.keys())
  f.operations.length = 0
  await archive.archiveLegacyV3(f.store, objects.slice(3).map(item => item[0]), () => {}, session)
  assert.equal(f.operations.filter(item => item[0] === 'readArchive' && old.has(item[1])).length, 0)
  assert.equal(f.originals.size, 0)
})

test('cold batch reads every needed object from one pack without original GETs or LRU thrash', async () => {
  const f = fixture(), objects = relatedObjects(40)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  f.operations.length = 0
  const reader = new archive.SyncLegacyArchiveReader(1, 1)
  const result = await reader.readMany(f.store, objects.map(item => item[0]))
  assert.deepEqual(new Map(result.entries.map(item => [item.path, item.body])), new Map(objects))
  assert.deepEqual(result.missing, [])
  assert.equal(f.operations.filter(item => item[0] === 'listArchive').length, 1)
  assert.equal(f.operations.filter(item => item[0] === 'readArchive').length, 1)
  assert.equal(f.operations.filter(item => item[0] === 'readOriginal').length, 0)
})

test('batch misses are only current observations, not cached absence', async () => {
  const f = fixture(), objects = relatedObjects(6)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.slice(0, 3).map(item => item[0]))
  const reader = new archive.SyncLegacyArchiveReader()
  const first = await reader.readMany(f.store, objects.map(item => item[0]))
  assert.deepEqual(first.missing.sort(), objects.slice(3).map(item => item[0]).sort())
  await archive.archiveLegacyV3(f.store, objects.slice(3).map(item => item[0]))
  const second = await reader.readMany(f.store, objects.map(item => item[0]))
  assert.deepEqual(second.missing, [])
  assert.deepEqual(new Map(second.entries.map(item => [item.path, item.body])), new Map(objects))
})

test('batch discovery falls back from a damaged pack copy and drains other buckets on network failure', async () => {
  const f = fixture(), objects = relatedObjects(3)
  for (const [name, body] of objects) f.originals.set(name, body)
  await archive.archiveLegacyV3(f.store, objects.map(item => item[0]))
  f.packs.set([...f.packs.keys()].sort()[0], 'damaged')
  const reader = new archive.SyncLegacyArchiveReader()
  assert.equal((await reader.readMany(f.store, objects.map(item => item[0]))).entries.length, 3)
  let other
  for (let i = 0; other === undefined; i++) {
    const body = JSON.stringify({ other: i }), name = object(body)
    if (wire.syncDigest(body)[0] !== 'a') other = [name, body]
  }
  let release, entered, calls = 0, active = 0, settled = false
  const gate = new Promise(resolve => { release = resolve })
  const ready = new Promise(resolve => { entered = resolve })
  const list = f.store.listArchive
  f.store.listArchive = async directory => {
    calls++; active++
    if (calls === 2) entered()
    if (directory.endsWith('/a/')) { active--; throw Error('offline') }
    await gate
    active--
    return list(directory)
  }
  const operation = reader.readMany(f.store, [objects[0][0], other[0]]).finally(() => { settled = true })
  const rejected = assert.rejects(operation, /offline/)
  await ready
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(settled, false)
  release()
  await rejected
  assert.equal(active, 0)
})

test('one round scans a bucket once across datasets including misses; next round discovers new archives', async () => {
  const f=fixture(), originals=relatedObjects(6)
  for (const [name,body] of originals.slice(0,3)) f.originals.set(name,body)
  await archive.archiveLegacyV3(f.store, originals.slice(0,3).map(row=>row[0]))
  const reader=new archive.SyncLegacyArchiveReader(), session=new archive.SyncLegacyReadSession()
  f.operations.length=0
  const first=await reader.readMany(f.store,[originals[0][0],originals[3][0]],()=>{},session)
  const second=await reader.readMany(f.store,[originals[1][0],originals[4][0]],()=>{},session)
  assert.equal(first.entries[0].body,originals[0][1]); assert.deepEqual(first.missing,[originals[3][0]])
  assert.equal(second.entries[0].body,originals[1][1]); assert.deepEqual(second.missing,[originals[4][0]])
  assert.equal(f.operations.filter(row=>row[0]==='listArchive').length,1)
  for (const [name,body] of originals.slice(3)) f.originals.set(name,body)
  await archive.archiveLegacyV3(f.store, originals.slice(3).map(row=>row[0]))
  const later=await reader.readMany(f.store,[originals[3][0]],()=>{},new archive.SyncLegacyReadSession())
  assert.equal(later.entries[0].body,originals[3][1])
})

test('failed round scan does not cache a negative bucket result', async () => {
  const f=fixture(), originals=relatedObjects(3)
  for (const [name,body] of originals) f.originals.set(name,body)
  await archive.archiveLegacyV3(f.store, originals.map(row=>row[0]))
  const reader=new archive.SyncLegacyArchiveReader(), session=new archive.SyncLegacyReadSession()
  f.fault(op=>{if(op==='listArchive') throw Error('offline')})
  await assert.rejects(reader.readMany(f.store,[originals[0][0]],()=>{},session),/offline/)
  f.fault(()=>{})
  const result=await reader.readMany(f.store,[originals[0][0]],()=>{},session)
  assert.equal(result.entries[0].body,originals[0][1])
})

test('simultaneous datasets share a single full bucket discovery', async () => {
  const f=fixture(), originals=relatedObjects(3)
  for (const [name,body] of originals) f.originals.set(name,body)
  await archive.archiveLegacyV3(f.store, originals.map(row=>row[0]))
  const reader=new archive.SyncLegacyArchiveReader(), session=new archive.SyncLegacyReadSession()
  f.operations.length=0
  const results=await Promise.all(originals.map(([name])=>reader.readMany(f.store,[name],()=>{},session)))
  assert.deepEqual(results.map(r=>r.entries[0].body), originals.map(row=>row[1]))
  assert.equal(f.operations.filter(row=>row[0]==='listArchive').length,1)
})
