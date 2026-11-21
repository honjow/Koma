const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { compile, facts, wire, A, B };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { compile, facts, wire, A, B } = support
const pack = compile('DeviceSyncObjectPack', { './DeviceSyncFacts': facts, './DeviceSyncWire': wire,
  '@kit.ArkTS': { util: { generateRandomUUID: require('node:crypto').randomUUID },
    taskpool: { execute: async (fn, ...args) => fn(...args) } } })
const attempt = '30000000-0000-0000-0000-000000000000'

function fixture() {
  const files = new Map()
  const calls = []
  const pending = new Map()
  const store = {
    async read(path) { calls.push(['read', path]); return files.get(path) },
    async write(path, body) { calls.push(['write', path]); files.set(path, body) },
    async list(dir) { calls.push(['list', dir]); return [...files.keys()].filter(name => name.startsWith(dir)).map(name => name.slice(dir.length)) },
    async remove(path) { calls.push(['remove', path]); files.delete(path) },
    async loadPending() { return [...pending.values()] },
    async recordPending(attempt) { pending.set(attempt.path, { ...attempt }) },
    async forgetPending(path) { pending.delete(path) },
    async deferPending(path, startedAt, nextCheckAt, checks, awaitingListing) {
      const entry = pending.get(path)
      if (entry?.startedAt === startedAt) pending.set(path, { ...entry, nextCheckAt, checks, awaitingListing })
    },
  }
  function object(writer, value) {
    const body = JSON.stringify(value)
    const hash = wire.syncDigest(body)
    const name = `object-1-${hash}-${attempt}.json`
    files.set(`${writer}/objects/${name}`, body)
    return { name, body, hash, bytes: wire.syncUtf8(body).length }
  }
  return { files, calls, store, object, pending }
}

test('archive checks, lists and reads a pack before deleting the current writer objects', async () => {
  const f = fixture()
  const a = f.object(A, { page: 5 })
  const b = f.object(A, { page: 6 })
  const c = f.object(A, { page: 8 })
  const other = f.object(B, { page: 7 })
  const result = await pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt)
  const name = result.packs[0]
  assert.equal(f.files.has(`${A}/objects/${a.name}`), false)
  assert.equal(f.files.has(`${A}/objects/${b.name}`), false)
  assert.equal(f.files.get(`${B}/objects/${other.name}`), other.body)
  assert.ok(f.files.has(name))
  assert.equal(await pack.readSyncPackObject(f.store, A, 1, a.hash, a.bytes), a.body)
  assert.equal(await pack.readSyncPackObject(f.store, A, 1, b.hash, b.bytes), b.body)
  const firstRemove = f.calls.findIndex(call => call[0] === 'remove')
  assert.ok(f.calls.slice(0, firstRemove).some(call => call[0] === 'list'))
  assert.ok(f.calls.slice(0, firstRemove).some(call => call[0] === 'read' && call[1] === name))
})

test('failed, incomplete or invisible pack publication keeps every original', async () => {
  for (const failure of ['timeout', 'truncated', 'invisible']) {
    const f = fixture()
    const a = f.object(A, { chapter: 1 })
    const b = f.object(A, { chapter: 2 })
    const c = f.object(A, { chapter: 3 })
    const write = f.store.write
    if (failure === 'timeout') f.store.write = async () => { throw new Error('network_timeout') }
    if (failure === 'truncated') f.store.write = async (path, body) => write(path, body.slice(0, 9))
    if (failure === 'invisible') f.store.list = async () => []
    await assert.rejects(pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt))
    assert.equal(f.files.get(`${A}/objects/${a.name}`), a.body)
    assert.equal(f.calls.filter(call => call[0] === 'remove').length, 0)
  }
})

test('a damaged pack cannot mask a valid copy, and incomplete listings report an error', async () => {
  const f = fixture()
  const a = f.object(A, { page: 13 })
  const b = f.object(A, { page: 14 })
  const c = f.object(A, { page: 15 })
  const copies = (await pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt)).packs
  const name = copies[0]
  const valid = f.files.get(name)
  f.files.set(`${A}/packs/pack-${B}-${wire.syncDigest('bad')}.json`, 'bad')
  assert.equal(await pack.readSyncPackObject(f.store, A, 1, a.hash, a.bytes), a.body)
  f.files.delete(name)
  f.files.delete(copies[1])
  await assert.rejects(pack.readSyncPackObject(f.store, A, 1, a.hash, a.bytes), /sync_pack_damaged/)
  f.files.set(name, valid)
  f.store.read = async () => undefined
  await assert.rejects(pack.readSyncPackObject(f.store, A, 1, a.hash, a.bytes), /sync_pack_incomplete/)
})

test('archive rejects damaged sources and paths outside its writer directory', async () => {
  const f = fixture()
  const a = f.object(A, { page: 2 })
  await assert.rejects(pack.archiveSyncObjects(f.store, A, [`../${B}/objects/${a.name}`], attempt), /sync_pack_invalid/)
  f.files.set(`${A}/objects/${a.name}`, 'damaged')
  const result = await pack.archiveSyncObjects(f.store, A, [a.name], attempt)
  assert.deepEqual(result.skipped, [a.name])
  assert.equal(f.files.get(`${A}/objects/${a.name}`), 'damaged')
  assert.equal(f.calls.filter(call => call[0] === 'remove').length, 0)
})

test('byte-bounded batches skip oversized and singleton objects without inflating file count', async () => {
  const f = fixture()
  const values = Array.from({ length: 6 }, (_, index) => f.object(A, { index, text: 'x'.repeat(300000) }))
  const oversized = f.object(A, { text: '\\'.repeat(400000) })
  const result = await pack.archiveSyncObjects(f.store, A, values.map(item => item.name).concat(oversized.name), attempt)
  assert.equal(result.packs.length, 4)
  assert.deepEqual(result.skipped, [oversized.name])
  assert.equal(f.files.get(`${A}/objects/${oversized.name}`), oversized.body)
  for (const value of values) assert.equal(await pack.readSyncPackObject(f.store, A, 1, value.hash, value.bytes), value.body)
  const g = fixture()
  const one = g.object(A, { page: 1 })
  const single = await pack.archiveSyncObjects(g.store, A, [one.name, one.name], attempt)
  assert.deepEqual(single.packs, [])
  assert.equal(g.files.get(`${A}/objects/${one.name}`), one.body)
  const h = fixture()
  const tail = Array.from({ length: 5 }, (_, index) => h.object(A, { index, text: 'z'.repeat(300000) }))
  const partial = await pack.archiveSyncObjects(h.store, A, tail.map(item => item.name), attempt)
  assert.equal(partial.packs.length, 2)
  assert.deepEqual(partial.skipped, tail.slice(3).map(item => item.name))
  for (const item of tail.slice(3)) assert.equal(h.files.get(`${A}/objects/${item.name}`), item.body)
})

test('cancellation after writing a pack leaves all source objects untouched', async () => {
  const f = fixture()
  const a = f.object(A, { page: 1 })
  const b = f.object(A, { page: 2 })
  const c = f.object(A, { page: 3 })
  const write = f.store.write
  let cancelled = false
  f.store.write = async (path, body) => { await write(path, body); cancelled = true }
  const guard = () => { if (cancelled) throw new Error('sync_connection_changed') }
  await assert.rejects(pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt, guard), /sync_connection_changed/)
  assert.equal(f.files.get(`${A}/objects/${a.name}`), a.body)
  assert.equal(f.files.get(`${A}/objects/${b.name}`), b.body)
})

test('a bounded scan advances past unproductive large objects to later small objects', async () => {
  const f = fixture()
  const large = Array.from({ length: 6 }, (_, index) => f.object(A, { index, data: '\\'.repeat(400000) }))
  const small = Array.from({ length: 130 }, (_, index) => f.object(A, { index, data: 'small' }))
  const names = large.concat(small).map(item => item.name)
  const first = await pack.archiveSyncObjects(f.store, A, names, attempt)
  assert.ok(first.nextIndex < names.length)
  const reads = f.calls.filter(call => call[0] === 'read' && call[1].includes('/objects/'))
  assert.equal(reads.length, first.nextIndex)
  const second = await pack.archiveSyncObjects(f.store, A, names, B, () => {}, first.nextIndex)
  assert.equal(second.nextIndex, names.length)
  assert.ok(second.packs.length > 0)
  for (const item of small) assert.equal(await pack.readSyncPackObject(f.store, A, 1, item.hash, item.bytes), item.body)
})

test('concurrent shard reads share pack discovery and reuse the verified cache', async () => {
  const f = fixture()
  const a = f.object(A, { page: 1 })
  const b = f.object(A, { page: 2 })
  const c = f.object(A, { page: 3 })
  await pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt)
  f.calls.length = 0
  const reader = new pack.SyncPackReader()
  const guard = () => {}
  const [first, second] = await Promise.all([
    reader.read(f.store, A, 1, a.hash, a.bytes, guard),
    reader.read(f.store, A, 1, b.hash, b.bytes, guard),
  ])
  assert.equal(first, a.body)
  assert.equal(second, b.body)
  assert.equal(f.calls.filter(call => call[0] === 'list').length, 1)
  assert.equal(f.calls.filter(call => call[0] === 'read').length, 1)
  f.calls.length = 0
  assert.equal(await reader.read(f.store, A, 1, a.hash, a.bytes, () => {}), a.body)
  assert.equal(f.calls.length, 0)
})

test('a pack evicted during large discovery can still supply the first object', async () => {
  const f = fixture()
  let first
  const index = new pack.SyncPackArchiveIndex()
  for (let i = 0; i < 12; i++) {
    const a = f.object(A, { i, side: 0, text: 'a'.repeat(250000) })
    const b = f.object(A, { i, side: 1, text: 'b'.repeat(250000) })
    const c = f.object(A, { i, side: 2, text: 'c'.repeat(250000) })
    if (i === 0) first = a
    await pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], require('node:crypto').randomUUID(), () => {}, 0, index)
  }
  const reader = new pack.SyncPackReader()
  assert.equal(await reader.read(f.store, A, 1, first.hash, first.bytes, () => {}), first.body)
})

test('rebuilding the pack index reads at most eight packs per background pass', async () => {
  const f = fixture()
  const original = new pack.SyncPackArchiveIndex()
  for (let i = 0; i < 5; i++) {
    const values = Array.from({ length: 3 }, (_, j) => f.object(A, { i, j }))
    await pack.archiveSyncObjects(f.store, A, values.map(value => value.name), require('node:crypto').randomUUID(), () => {}, 0, original)
  }
  const values = Array.from({ length: 3 }, (_, j) => f.object(A, { fresh: true, j }))
  const restarted = new pack.SyncPackArchiveIndex()
  f.calls.length = 0
  const first = await pack.archiveSyncObjects(f.store, A, values.map(value => value.name), attempt, () => {}, 0, restarted)
  assert.equal(first.discoveryPending, true)
  assert.equal(first.nextIndex, 0)
  assert.ok(f.calls.filter(call => call[0] === 'read' && call[1].includes('/packs/')).length <= 8)
  assert.equal(f.calls.some(call => call[0] === 'remove'), false)
  const next = await pack.archiveSyncObjects(f.store, A, values.map(value => value.name), attempt, () => {}, 0, restarted)
  assert.equal(next.discoveryPending, false)
  assert.equal(next.packs.length, 2)
})

test('one cancelled reader does not cancel another guard on the same endpoint', async () => {
  const f = fixture()
  const a = f.object(A, { page: 1 })
  const b = f.object(A, { page: 2 })
  const c = f.object(A, { page: 3 })
  await pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt)
  let release
  const wait = new Promise(resolve => { release = resolve })
  const read = f.store.read
  f.store.read = async path => { await wait; return read(path) }
  const reader = new pack.SyncPackReader()
  let cancelled = false
  const cancelledGuard = () => { if (cancelled) throw new Error('sync_connection_changed') }
  const first = reader.read(f.store, A, 1, a.hash, a.bytes, cancelledGuard)
  const second = reader.read(f.store, A, 1, b.hash, b.bytes, () => {})
  cancelled = true
  release()
  await assert.rejects(first, /sync_connection_changed/)
  assert.equal(await second, b.body)
})

test('interrupted second copy and partial deletion reuse verified packs on retry', async () => {
  const f = fixture()
  const a = f.object(A, { page: 1 })
  const b = f.object(A, { page: 2 })
  const c = f.object(A, { page: 3 })
  const originalWrite = f.store.write
  let writes = 0
  f.store.write = async (path, body) => {
    writes++
    if (writes === 2) throw new Error('network_timeout')
    await originalWrite(path, body)
  }
  await assert.rejects(pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], attempt), /network_timeout/)
  assert.equal(f.files.get(`${A}/objects/${a.name}`), a.body)
  assert.equal(f.files.get(`${A}/objects/${b.name}`), b.body)
  f.store.write = originalWrite
  const list = f.store.list
  f.store.list = async dir => { const names = await list(dir); return names.concat(names) }
  const remove = f.store.remove
  let removed = 0
  f.store.remove = async path => {
    if (++removed === 2) throw new Error('network_timeout')
    await remove(path)
  }
  await assert.rejects(pack.archiveSyncObjects(f.store, A, [a.name, b.name, c.name], B), /network_timeout/)
  const packCount = [...f.files.keys()].filter(name => name.startsWith(`${A}/packs/`)).length
  assert.equal(packCount, 2)
  f.store.list = list
  f.store.remove = remove
  const retry = await pack.archiveSyncObjects(f.store, A, [b.name, c.name], B)
  assert.equal(retry.packs.length, 2)
  assert.equal([...f.files.keys()].filter(name => name.startsWith(`${A}/packs/`)).length, 2)
  assert.equal(await pack.readSyncPackObject(f.store, A, 1, a.hash, a.bytes), a.body)
  assert.equal(await pack.readSyncPackObject(f.store, A, 1, b.hash, b.bytes), b.body)
})
