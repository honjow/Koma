const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_v4.cjs'), 'utf8') +
  '\nreturn { transportFixture, wire, A, B, C, noop, dataset, manifest, pageNumber, animation, seedV3Revision };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { transportFixture, wire, A, B, C, noop, dataset, manifest, pageNumber, animation, seedV3Revision } = support

function storePack(f, target) {
  const oldPath = wire.syncShardPath(target.ref)
  const entries = [{ path: oldPath, bytes: Buffer.byteLength(target.body), hash: target.ref.hash, body: target.body }]
  const bucket = target.ref.hash[0]
  for (let i = 0; entries.length < 3; i++) {
    const body = JSON.stringify({ opaque: i })
    const hash = wire.syncDigest(body)
    if (hash[0] === bucket) entries.push({ path: `object-1-${hash}.json`, bytes: Buffer.byteLength(body), hash, body })
  }
  const body = JSON.stringify({ format: 'KOMA_V3_ARCHIVE', version: 1, entries })
  const directory = f.writerRootV4 + 'legacy-v3/objects/' + bucket + '/'
  f.directories.add(f.writerRootV4 + 'legacy-v3/')
  f.directories.add(f.writerRootV4 + 'legacy-v3/objects/')
  f.directories.add(directory)
  f.files.set(directory + `pack-${A}-${wire.syncDigest(body)}.json`, body)
  f.files.set(directory + `pack-${B}-${wire.syncDigest(body)}.json`, body)
  f.files.delete(f.writerRoot + oldPath)
  return directory
}

test('a v4 reference to an archived v3 object remains readable after the v3 head changes', async () => {
  const f = transportFixture('https://retained-v3-ref.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const later = dataset('reader-settings-records', animation, A, 'false')
  seedV3Revision(f, A, 1, [old])
  const writer = new f.WriterWebDav(f.draft, [], undefined, B)
  const remote = await writer.readManifest(noop)
  const proposed = manifest(writer.spaceId(), [old.ref], 1)
  await writer.preparePublication(proposed, [], [], noop)
  await writer.publish(proposed, remote.etag, noop, noop, [])
  seedV3Revision(f, A, 2, [later])

  const target = old.objects[0]
  const directory = storePack(f, target)
  const reader = new f.WriterWebDav(f.draft, [], undefined, C)
  const latest = await reader.readManifest(noop)
  assert.ok(latest.writerHeads.some(head => head.path.startsWith('v4/' + B + '/')))
  const v3Head = latest.writerHeads.find(head => head.path.startsWith(A + '/'))
  assert.ok(v3Head)
  assert.equal(v3Head.manifest.revision, 2)
  assert.ok(!JSON.stringify(v3Head.manifest).includes(target.ref.hash))
  assert.equal(await reader.readObject(target.ref, noop), target.body)
  assert.ok(f.trace.some(row => row.method === 'GET' && row.address.startsWith(directory)))
})

test('a provider rechecks an earlier archive 404 after its original object is archived', async () => {
  const f = transportFixture('https://retained-v3-cache.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  seedV3Revision(f, A, 1, [old])
  const reader = new f.WriterWebDav(f.draft, [], undefined, C)
  await reader.readManifest(noop)
  assert.equal(await reader.hasLegacyArchive('objects', noop), false)
  const target = old.objects[0]
  const directory = storePack(f, target)
  assert.equal(await reader.readObject(target.ref, noop), target.body)
  assert.ok(f.trace.some(row => row.method === 'GET' && row.address.startsWith(directory)))
})

test('a provider rechecks an earlier commits archive 404 for a known archived head', async () => {
  const f = transportFixture('https://retained-v3-commit-cache.invalid')
  const old = dataset('reader-settings-records', pageNumber, A, 'true')
  const names = [1, 2, 3].map(revision => seedV3Revision(f, A, revision, [old]))
  const reader = new f.WriterWebDav(f.draft, [], undefined, C)
  assert.equal(await reader.hasLegacyArchive('commits', noop), false)
  const entries = names.map(name => {
    const body = f.files.get(f.writerRoot + name)
    return { path: name, bytes: Buffer.byteLength(body), hash: wire.syncDigest(body), body }
  })
  const body = JSON.stringify({ format: 'KOMA_V3_ARCHIVE', version: 1, entries })
  const root = f.writerRootV4 + 'legacy-v3/'
  const directory = root + 'commits/' + A + '/00000000000000/'
  for (const item of [root, root + 'commits/', root + 'commits/' + A + '/', directory]) f.directories.add(item)
  f.files.set(directory + `pack-${A}-${wire.syncDigest(body)}.json`, body)
  f.files.set(directory + `pack-${B}-${wire.syncDigest(body)}.json`, body)
  f.files.delete(f.writerRoot + names[0])
  const restored = await reader.readCommit(names[0], noop, true)
  assert.equal(restored.manifest.revision, 1)
  assert.ok(f.trace.some(row => row.method === 'GET' && row.address.startsWith(directory)))
})
