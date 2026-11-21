const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const dir = __dirname
const { transportFixture, seedV3Revision, seedArchivedV3, dataset, pageNumber, animation, A, B, noop, v4root } =
  new Function('require', '__dirname', fs.readFileSync(path.join(dir, 'test_device_sync_v4.cjs'), 'utf8') +
    '\nreturn { transportFixture, seedV3Revision, seedArchivedV3, dataset, pageNumber, animation, A, B, noop, v4root };')(
    name => name === 'node:test' ? () => {} : require(name), dir)

test('an empty archive directory does not create an unrecoverable witness', async () => {
  const f = transportFixture('https://empty-archive-witness.invalid')
  const root = v4root(f) + 'legacy-v3/commits/'
  f.directories.add(v4root(f)); f.directories.add(root)
  const saved = new Set()
  const bind = provider => provider.configureArchiveWitness(kind => saved.has(kind), async kind => { saved.add(kind) })
  const first = new f.WriterWebDav(f.draft, [], undefined, A)
  bind(first)
  await first.readManifest(noop)
  assert.equal(saved.has('commits'), false)
  f.directories.delete(root)
  const cold = new f.WriterWebDav(f.draft, [], undefined, B)
  bind(cold)
  await cold.readManifest(noop)
})

test('a used archive persists its witness and refuses to rewind after restart', async () => {
  const f = transportFixture('https://used-archive-witness.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const next = dataset('reader-settings-records', animation, A, 'false')
  seedV3Revision(f, A, 1, [old])
  const names = [2, 3, 4].map(revision => seedV3Revision(f, A, revision, [next]))
  seedArchivedV3(f, `commits/${A}/00000000000000/`, names.map(name => [name, f.files.get(f.writerRoot + name)]))
  names.forEach(name => f.files.delete(f.writerRoot + name))
  const saved = new Set()
  const bind = provider => provider.configureArchiveWitness(kind => saved.has(kind), async kind => { saved.add(kind) })
  const first = new f.WriterWebDav(f.draft, [], undefined, B)
  bind(first)
  const receipt = await first.readManifest(noop)
  assert.ok(receipt.frontier.includes(names[2]))
  assert.equal(saved.has('commits'), true)
  f.onRequest(async (method, address) => {
    if (method === 'PROPFIND' && address === v4root(f) + 'legacy-v3/commits/') {
      throw Object.assign(Error('offline'), { code: 2300007 })
    }
  })
  const offline = new f.WriterWebDav(f.draft, receipt.frontier, undefined, B)
  bind(offline)
  await assert.rejects(offline.readManifest(noop))
  assert.equal(saved.has('commits'), true)
  f.onRequest(async () => {})
  f.directories.delete(v4root(f) + 'legacy-v3/commits/')
  const cold = new f.WriterWebDav(f.draft, receipt.frontier, undefined, B)
  bind(cold)
  await assert.rejects(cold.readManifest(noop), /sync_legacy_archive_unavailable|sync_remote_changed/)
})

test('an archive witness is scoped to its endpoint and space', async () => {
  const f = transportFixture('https://archive-scope-a.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const next = dataset('reader-settings-records', animation, A, 'false')
  seedV3Revision(f, A, 1, [old])
  const names = [2, 3, 4].map(revision => seedV3Revision(f, A, revision, [next]))
  seedArchivedV3(f, `commits/${A}/00000000000000/`, names.map(name => [name, f.files.get(f.writerRoot + name)]))
  names.forEach(name => f.files.delete(f.writerRoot + name))
  const saved = new Set()
  const bind = (provider, endpoint) => provider.configureArchiveWitness(
    kind => saved.has(endpoint + ':' + provider.spaceId() + ':' + kind),
    async kind => { saved.add(endpoint + ':' + provider.spaceId() + ':' + kind) })
  const first = new f.WriterWebDav(f.draft, [], undefined, A)
  bind(first, f.draft.directory)
  await first.readManifest(noop)
  assert.equal(saved.has(f.draft.directory + ':' + first.spaceId() + ':commits'), true)
  f.directories.delete(v4root(f) + 'legacy-v3/commits/')
  const otherSpace = new f.WriterWebDav(f.draft, [], B, B)
  bind(otherSpace, f.draft.directory)
  await otherSpace.readManifest(noop)
  const alternate = { ...f.draft, directory: 'https://archive-scope-b.invalid' }
  f.directories.add(alternate.directory + '/')
  f.directories.add(alternate.directory + '/koma-device-sync-v2/')
  const otherEndpoint = new f.WriterWebDav(alternate, [], undefined, B)
  bind(otherEndpoint, alternate.directory)
  await otherEndpoint.readManifest(noop)
})

test('a new archive created after an empty discovery is visible on the next sync', async () => {
  const f = transportFixture('https://archive-appears-after-empty.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const next = dataset('reader-settings-records', animation, A, 'false')
  const previous = seedV3Revision(f, A, 1, [old])
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  assert.ok((await reader.readManifest(noop)).frontier.includes(previous))
  const names = [2, 3, 4].map(revision => seedV3Revision(f, A, revision, [next]))
  seedArchivedV3(f, `commits/${A}/00000000000000/`, names.map(name => [name, f.files.get(f.writerRoot + name)]))
  names.forEach(name => f.files.delete(f.writerRoot + name))
  const nextReceipt = await reader.readManifest(noop)
  assert.ok(nextReceipt.frontier.includes(names[2]))
  assert.ok(!nextReceipt.frontier.includes(previous))
})
