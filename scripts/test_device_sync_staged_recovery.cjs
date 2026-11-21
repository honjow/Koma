const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

const { engineFixture, wire, facts, data, A, dot, edit } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { engineFixture, wire, facts, data, A, dot, edit };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { transportFixture, B, noop } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_journal.cjs'), 'utf8') +
  '\nreturn { transportFixture, B, noop };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)

test('unsent first activation survives restart without inventing a receipt or losing local dots', async () => {
  const f = engineFixture()
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(f.draft)
  const configuration = d.store.load().pendingConfiguration
  const identity = wire.syncDigest(JSON.stringify([f.draft.directory, f.draft.username]))
  const space = [identity.slice(0, 8), identity.slice(8, 12), identity.slice(12, 16),
    identity.slice(16, 20), identity.slice(20, 32)].join('-')
  const version = dot(A, 1)
  const staged = { id: 'reader-settings', facts: [edit(facts.emptySyncFact(key), version, 'set', 'true')],
    baseline: [{ key, value: 'true' }], pending: [{ key, version }] }
  d.store.update(state => {
    state.counter = 1
    state.pendingConfiguration.enabled = true
    state.intent = { connection: { ...configuration, space, revision: 10, manifestHash: 'unconfirmed',
      reviewRequired: false, lastSuccess: 0, lastError: '', groups: [] }, expected: '', sent: false,
    groupRevisions: [], applies: [], staged: [staged] }
  })
  await d.restart().recoverIntent()
  assert.equal(d.store.load().active, undefined)
  assert.equal(d.store.load().pendingConfiguration.enabled, true)
  assert.equal(d.store.load().stagedRecovery[0].groups[0].pending[0].version.sequence, 1)
  const resumed = d.restart()
  await resumed.syncNow()
  assert.equal(d.store.load().active.space, space)
  assert.equal(d.store.load().counter, 1, 'the staged local dot must not be issued again')
  assert.equal(d.store.load().stagedRecovery.length, 0)
})

test('legacy unsent intent replans from the owner without inventing a receipt', async () => {
  const f = engineFixture()
  const d = f.replica(A)
  await d.engine.saveConfiguration(f.draft)
  d.store.update(state => {
    state.pendingConfiguration.enabled = true
    state.intent = { connection: { ...state.pendingConfiguration, space: A, revision: 1, manifestHash: 'old',
      reviewRequired: false, lastSuccess: 0, lastError: '', groups: [] }, expected: '', sent: false,
    groupRevisions: [], applies: [] }
  })
  await d.restart().recoverIntent()
  assert.equal(d.store.load().intent, undefined)
  assert.equal(d.store.load().active, undefined)
  d.engine.setSelection(['reader-settings'])
  await d.restart().syncNow()
  assert.ok(d.store.load().active)
})

test('unsent manual review retains the receipt and waits for its group to be selected again', async () => {
  const f = engineFixture()
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['shelf', 'reader-settings'])
  await d.engine.saveConfiguration(f.draft)
  d.engine.setEnabled(true)
  await d.engine.syncNow()
  const active = structuredClone(d.store.load().active)
  const old = active.groups.find(group => group.id === 'reader-settings')
  d.values.get('reader-settings').set(key, 'false')
  const version = dot(A, d.store.load().counter + 1)
  const fact = edit(old.facts.find(item => item.key === key), version, 'set', 'false')
  const staged = { id: 'reader-settings', facts: [fact], baseline: [{ key, value: 'false' }],
    pending: [{ key, version }] }
  d.store.update(state => {
    state.counter = version.sequence
    state.intent = { connection: { ...structuredClone(active), revision: 99, manifestHash: 'unconfirmed' },
      expected: '', sent: false, groupRevisions: [], applies: [], staged: [staged] }
  })
  d.engine.setSelection(['shelf'])
  assert.equal(d.store.load().active.revision, active.revision)
  assert.equal(d.store.load().active.manifestHash, active.manifestHash)
  assert.deepEqual(d.store.load().active.groups, active.groups)
  await d.engine.syncNow()
  assert.equal(d.store.load().stagedRecovery[0].groups[0].id, 'reader-settings')
  assert.deepEqual(d.engine.selection(), ['shelf'])
  d.engine.setSelection(['shelf', 'reader-settings'])
  await d.restart().syncNow()
  assert.equal(d.store.load().counter, version.sequence)
  assert.equal(d.store.load().stagedRecovery.length, 0)
})

for (const [headAlreadyExists, legacyIntent] of [[false, false], [true, false], [true, true]]) test('missing sent objects replan with head ' +
  (headAlreadyExists ? 'already present' : 'arriving late') + (legacyIntent ? ' and old intent' : ''), async () => {
  const transport = transportFixture('https://replan.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  if (legacyIntent) d.store.update(state => { delete state.intent.staged })
  const sent = structuredClone(d.store.load().intent)
  assert.ok(sent.sent && sent.commit.startsWith('v4/'))
  const publication = JSON.parse(sent.commitBody)
  for (const location of publication.locations) {
    transport.files.delete(transport.writerRootV4 + location.writer + '/objects/object-' + location.epoch + '-' +
      location.hash + '-' + location.attempt + '.json')
  }
  if (headAlreadyExists) transport.files.set(transport.writerRootV4 + sent.commit.substring(3), sent.commitBody)
  await d.restart().syncNow()
  assert.ok(d.store.load().active.revision > sent.connection.revision)
  assert.equal(d.store.load().replanIntents.length, 0)
  transport.files.set(transport.writerRootV4 + sent.commit.substring(3), sent.commitBody)
  const reader = new transport.WriterWebDav(transport.draft, [], undefined, B)
  const remote = await reader.readManifest(noop)
  assert.ok(remote.own === undefined)
  assert.ok(remote.writerHeads.find(head => head.path.startsWith('v4/' + A + '/')).manifest.revision > sent.connection.revision)
})

test('a temporary network failure while checking a sent head preserves its original intent', async () => {
  const transport = transportFixture('https://replan-network.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('lost-response')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const sent = structuredClone(d.store.load().intent)
  transport.onRequest(async (method, address) => {
    if (method === 'GET' && address.includes('/objects/')) throw Object.assign(new Error('offline'), { code: 2300007 })
  })
  await assert.rejects(d.restart().syncNow())
  assert.equal(d.store.load().intent.commitBody, sent.commitBody)
  assert.equal(d.store.load().replanIntents?.length ?? 0, 0)
  transport.onRequest(async () => {})
  await d.restart().syncNow()
  assert.ok(d.store.load().active)
})

test('a truly old publication without targets stays pending until its missing object is readable', async () => {
  const transport = transportFixture('https://replan-old-no-targets.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const previous = structuredClone(d.store.load().intent)
  const publication = JSON.parse(previous.commitBody)
  delete publication.newTargets
  const body = JSON.stringify(publication)
  const path = previous.commit.replace(/-[0-9a-f]{64}(-[0-9a-f-]{36}\.json)$/, '-' + wire.syncDigest(body) + '$1')
  d.store.update(state => { state.intent.commit = path; state.intent.commitBody = body })
  transport.files.set(transport.writerRootV4 + path.substring(3), body)
  const loc = publication.locations[0]
  const object = transport.writerRootV4 + loc.writer + '/objects/object-' + loc.epoch + '-' + loc.hash + '-' + loc.attempt + '.json'
  const bytes = transport.files.get(object)
  assert.ok(bytes)
  transport.files.delete(object)
  await assert.rejects(d.restart().syncNow(), /sync_pack_not_found/)
  assert.equal(d.store.load().intent.commit, path)
  assert.equal(d.store.load().intent.commitBody, body)
  assert.equal(d.store.load().replanIntents?.length ?? 0, 0)
  transport.files.set(object, bytes)
  await d.restart().syncNow()
  assert.ok(d.store.load().active)
  assert.equal(d.store.load().intent, undefined)
})

test('revoking a group during a second sent attempt preserves both late-head fences', async () => {
  const transport = transportFixture('https://replan-scope.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['shelf', 'reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const first = structuredClone(d.store.load().intent)
  for (const location of JSON.parse(first.commitBody).locations) {
    transport.files.delete(transport.writerRootV4 + location.writer + '/objects/object-' + location.epoch + '-' +
      location.hash + '-' + location.attempt + '.json')
  }
  transport.faults.push('before-accept')
  await assert.rejects(d.restart().syncNow(), /sync_remote_result_unknown/)
  const second = structuredClone(d.store.load().intent)
  assert.equal(d.store.load().replanIntents.length, 1)
  d.engine.setSelection(['shelf'])
  assert.equal(d.store.load().publicationWriter ?? A, A)
  assert.equal(d.store.load().replanIntents.length, 2)
  await d.restart().syncNow()
  assert.deepEqual(d.engine.selection(), ['shelf'])
  transport.files.set(transport.writerRootV4 + first.commit.substring(3), first.commitBody)
  transport.files.set(transport.writerRootV4 + second.commit.substring(3), second.commitBody)
  d.engine.setSelection(['shelf', 'reader-settings'])
  await d.restart().syncNow()
  const receiver = f.replica(B)
  receiver.engine.setSelection(['reader-settings'])
  await receiver.engine.saveConfiguration(transport.draft)
  receiver.engine.setEnabled(true)
  await receiver.engine.syncNow()
  assert.equal(receiver.values.get('reader-settings').get(key), 'true')
})

test('switching connections keeps an outstanding replan scoped to its original endpoint', async () => {
  const transport = transportFixture('https://replan-account-a.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const sent = structuredClone(d.store.load().intent)
  for (const location of JSON.parse(sent.commitBody).locations) {
    transport.files.delete(transport.writerRootV4 + location.writer + '/objects/object-' + location.epoch + '-' +
      location.hash + '-' + location.attempt + '.json')
  }
  transport.faults.push('before-accept')
  await assert.rejects(d.restart().syncNow(), /sync_remote_result_unknown/)
  const alternate = { ...transport.draft, directory: 'https://replan-account-b.invalid' }
  transport.directories.add(alternate.directory + '/')
  await d.engine.saveConfiguration(alternate)
  assert.equal(d.store.load().publicationWriter ?? A, A)
  assert.equal(d.store.load().replanIntents.length, 2)
  d.engine.setEnabled(true)
  await d.engine.syncNow()
  assert.equal(d.store.load().replanIntents.length, 2)
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  await d.restart().syncNow()
  assert.equal(d.store.load().replanIntents.length, 0)
})

test('manual review first recovers a sent attempt and excludes its late head through confirmation', async () => {
  const transport = transportFixture('https://replan-review.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const sent = structuredClone(d.store.load().intent)
  for (const location of JSON.parse(sent.commitBody).locations) {
    transport.files.delete(transport.writerRootV4 + location.writer + '/objects/object-' + location.epoch + '-' +
      location.hash + '-' + location.attempt + '.json')
  }
  const engine = d.restart()
  const preview = await engine.prepareSaved(['reader-settings'])
  assert.equal(d.store.load().replanIntents.length, 1)
  transport.files.set(transport.writerRootV4 + sent.commit.substring(3), sent.commitBody)
  await engine.confirm(preview.token, [])
  assert.ok(d.store.load().active.revision > sent.connection.revision)
  assert.equal(d.store.load().replanIntents.length, 0)
})

test('cancelling review stops sent intent recovery before retrying its PUT', async () => {
  const transport = transportFixture('https://replan-cancel-review.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const sent = structuredClone(d.store.load().intent)
  let entered, release
  const waiting = new Promise(resolve => { entered = resolve })
  const resume = new Promise(resolve => { release = resolve })
  transport.onRequest(async (method, address) => {
    if (method === 'GET' && address.endsWith(sent.commit.substring(3))) { entered(); await resume }
  })
  const engine = d.restart()
  const operation = engine.prepareSaved(['reader-settings'])
  const rejected = assert.rejects(operation, /sync_preview_changed/)
  await waiting
  const before = transport.trace.filter(row => row.method === 'PUT').length
  engine.discardPreview()
  release()
  await rejected
  assert.equal(transport.trace.filter(row => row.method === 'PUT').length, before)
  assert.equal(d.store.load().intent.commit, sent.commit)
})

test('new credential preview isolates a late sent head without changing writer on cancel', async () => {
  const transport = transportFixture('https://replan-new-credential.invalid')
  transport.draft.username = 'reader'
  transport.draft.password = 'first'
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['shelf', 'reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('before-accept')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const sent = structuredClone(d.store.load().intent)
  const edited = { ...transport.draft, password: 'second' }
  await d.engine.testConnection(edited)
  const cancelled = await d.engine.prepare(edited, ['shelf'])
  d.engine.discardPreview(cancelled.token)
  assert.equal(d.store.load().publicationWriter ?? A, A)
  assert.equal(d.store.load().intent.commit, sent.commit)
  const preview = await d.engine.prepare(edited, ['shelf'])
  await d.engine.confirm(preview.token, [])
  assert.notEqual(d.store.load().publicationWriter, A)
  transport.files.set(transport.writerRootV4 + sent.commit.substring(3), sent.commitBody)
  const reader = new transport.WriterWebDav(transport.draft, [], undefined, B)
  const remote = await reader.readManifest(noop)
  assert.notEqual(remote.warning, 'sync_writer_conflicting_publications')
  assert.ok(remote.writerHeads.some(head => head.path.startsWith('v4/' + A + '/')))
})

test('paused saved review is read-only and cancel keeps the sent intent', async () => {
  const transport = transportFixture('https://replan-paused-review.invalid')
  const f = engineFixture(transport.WriterWebDav)
  const key = data.syncKey(['global', 'page-number'])
  const d = f.replica(A, [['reader-settings', new Map([[key, 'true']])]])
  d.engine.setSelection(['reader-settings'])
  await d.engine.saveConfiguration(transport.draft)
  d.engine.setEnabled(true)
  transport.faults.push('lost-response')
  await assert.rejects(d.engine.syncNow(), /sync_remote_result_unknown/)
  const sent = structuredClone(d.store.load().intent)
  d.engine.setEnabled(false)
  const before = transport.trace.filter(row => row.method === 'PUT').length
  const preview = await d.engine.prepareSaved(['reader-settings'])
  d.engine.discardPreview(preview.token)
  assert.equal(transport.trace.filter(row => row.method === 'PUT').length, before)
  assert.equal(d.store.load().intent.commit, sent.commit)
  assert.equal(d.store.load().active, undefined)
  assert.equal(d.engine.isEnabled(), false)
  assert.equal(d.values.get('reader-settings').get(key), 'true')
  const confirmed = await d.engine.prepareSaved(['reader-settings'])
  await d.engine.confirm(confirmed.token, [])
  assert.equal(d.engine.isEnabled(), true)
  assert.ok(d.store.load().active)
})
