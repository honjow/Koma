const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')
const { compile, facts, wire } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { compile, facts, wire };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)

test('cancelled or superseded archive metadata never mutates the active document', async () => {
  const files = new Map()
  let entered, resume
  const fileIo = { accessSync: file => files.has(file), readTextSync: file => files.get(file),
    renameSync: (from, to) => { files.set(to, files.get(from)); files.delete(from) },
    unlink: async file => files.delete(file) }
  const { DeviceSyncStorage } = compile('DeviceSyncStorage', {
    '@kit.CoreFileKit': { fileIo }, '@kit.AssetStoreKit': {},
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: { async execute(worker, ...args) {
      const result = worker(...args)
      await new Promise(resolve => { resume = resolve; entered() })
      return result
    } } },
    '../model/AppFileTextPersistence': { writeAppTextFile: (file, body) => files.set(file, body) },
    './DeviceSyncFacts': facts, './DeviceSyncWire': wire, './DeviceSyncWebDav': {},
  })
  const storage = new DeviceSyncStorage('/test')
  storage.update(state => { state.counter = 1; state.archivePending = [
    { endpointIdentity: 'first', space: 'a', path: 'one', startedAt: 1, checks: 0 },
    { endpointIdentity: 'second', space: 'b', path: 'two', startedAt: 2 },
  ] })
  const original = storage.load()
  const waiting = new Promise(resolve => { entered = resolve })
  const work = storage.updateInBackground(state => {
    state.archivePending[0].nextCheckAt = 123
    state.archivePending[0].awaitingListing = true
    state.archivePending[0].checks = 1
    return true
  }, () => { if (storage.load() !== original) throw Error('superseded') })
  const rejected = assert.rejects(work, /superseded/)
  await waiting
  assert.equal(storage.load().archivePending[0].nextCheckAt, undefined)
  assert.equal(storage.load().archivePending[0].checks, 0)
  storage.update(state => { state.counter = 9; state.archivePending.push(
    { endpointIdentity: 'second', space: 'b', path: 'three', startedAt: 3 }) })
  resume()
  await rejected
  assert.equal(storage.load().counter, 9)
  assert.equal(storage.load().archivePending[0].nextCheckAt, undefined)
  assert.equal(storage.load().archivePending[0].checks, 0)
  assert.deepEqual(storage.load().archivePending.map(row => row.path), ['one', 'two', 'three'])
  assert.equal(files.get('/test/device-sync-state.v1.json'), JSON.stringify(storage.load()))
  const persisted = JSON.parse(files.get('/test/device-sync-state.v1.json'))
  assert.equal(persisted.counter, 9)
  assert.equal(persisted.archivePending[0].checks, 0)
  assert.equal(persisted.archivePending[0].nextCheckAt, undefined)
  assert.deepEqual(persisted.archivePending.map(row => row.path), ['one', 'two', 'three'])
})
