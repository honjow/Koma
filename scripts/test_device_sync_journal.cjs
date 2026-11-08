const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')

// Reuse the existing ArkTS loader; execute production Journal, Engine and HTTP adapter.
// Only NetworkKit, native credentials and owner persistence are host substitutes.
const support = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync.cjs'), 'utf8') +
  '\nreturn { compile, wire, facts, data, journal, engineFixture, runtimeFixture, A, B, C, dot, edit };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)
const { compile, wire, facts, data, journal, engineFixture, runtimeFixture, A, B, C, dot, edit } = support
const models = compile('../remote/WebDavModels')
const xml = compile('../remote/WebDavClient', { './WebDavModels': models })

test('a staged sync state cannot overwrite a newer local write or publish after cancellation', async () => {
  const path = '/test/device-sync-state.v1.json'
  const files = new Map()
  let staged
  let resume
  let blocked = false
  const fileIo = {
    accessSync: file => files.has(file),
    readTextSync: file => files.get(file),
    renameSync: (from, to) => {
      assert.ok(files.has(from))
      files.set(to, files.get(from))
      files.delete(from)
    },
    unlink: async file => files.delete(file),
  }
  const { DeviceSyncStorage } = compile('DeviceSyncStorage', {
    '@kit.CoreFileKit': { fileIo }, '@kit.AssetStoreKit': {},
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID }, taskpool: {
      async execute(worker, ...args) {
        const result = worker(...args)
        if (blocked) {
          blocked = false
          await new Promise(resolve => { resume = resolve; staged() })
        }
        return result
      },
    } },
    '../model/AppFileTextPersistence': { writeAppTextFile: (file, body) => files.set(file, body) },
    './DeviceSyncFacts': facts, './DeviceSyncWire': wire, './DeviceSyncWebDav': {},
  })
  const storage = new DeviceSyncStorage('/test')
  storage.update(state => { state.counter = 1 })
  const pauseNext = () => new Promise(resolve => { blocked = true; staged = resolve })
  const firstStage = pauseNext()
  const saving = storage.updateInBackground(state => { state.counter += 1; return true }, () => {})
  await firstStage
  storage.update(state => { state.counter = 5 })
  resume()
  await saving
  assert.equal(JSON.parse(files.get(path)).counter, 6)
  assert.equal(storage.load().counter, 6)

  let allowed = true
  const secondStage = pauseNext()
  const cancelled = storage.updateInBackground(state => { state.counter = 9; return true }, () => {
    if (!allowed) throw new Error('sync_connection_changed')
  })
  await secondStage
  allowed = false
  resume()
  await assert.rejects(cancelled, /sync_connection_changed/)
  assert.equal(JSON.parse(files.get(path)).counter, 6)
  assert.deepEqual([...files.keys()], [path])
})
const noop = () => {}
const clone = value => structuredClone(value)
const response = (status, body = '') => ({ responseCode: status,
  result: Uint8Array.from(Buffer.from(body)).buffer, header: {} })

function transportFixture() {
  const draft = { directory: 'https://local-fixture.invalid', username: '', password: '' }
  const directory = draft.directory + '/'
  const root = directory + 'koma-device-sync-v2/'
  const writerRoot = directory + 'koma-device-sync-v3/'
  const legacy = directory + 'koma-device-sync-v1/'
  const files = new Map()
  const directories = new Set([directory, root])
  const trace = []
  const faults = []
  let filterListing = names => names
  let beforeCommit = async () => {}
  let beforeRequest = async () => {}
  const resource = (address, collection) => '<d:response><d:href>' + new URL(address).pathname +
    '</d:href><d:propstat><d:prop><d:resourcetype>' + (collection ? '<d:collection/>' : '') +
    '</d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
  const http = { HttpDataType: { ARRAY_BUFFER: 2 }, createHttp: () => ({
    async request(address, options) {
      const method = options.customMethod
      trace.push({ method, address, body: options.extraData, headers: clone(options.header) })
      await beforeRequest(method, address)
      assert.equal(options.usingCache, false)
      assert.equal(options.maxRedirects, 0)
      if (method === 'PROPFIND') {
        if (!directories.has(address)) return response(404)
        const names = options.header.Depth === '0' ? [] : filterListing([...files.keys(), ...directories]
          .filter(name => name.startsWith(address) && name !== address &&
            !name.slice(address.length).replace(/\/$/, '').includes('/')).map(name => name.slice(address.length)))
        return response(207, '<d:multistatus xmlns:d="DAV:">' + resource(address, true) +
          names.map(name => resource(address + name, directories.has(address + name))).join('') + '</d:multistatus>')
      }
      if (method === 'MKCOL') { directories.add(address); return response(201) }
      if (method === 'GET') return files.has(address) ? response(200, files.get(address)) : response(404)
      if (method === 'DELETE') { files.delete(address); return response(204) }
      if (method === 'PUT') {
        const isCommit = journal.SYNC_COMMIT_NAME.test(address.slice(root.length)) ||
          (address.startsWith(writerRoot) && /\/[0-9]{16}-[0-9a-f]{64}\.json$/.test(address))
        if (isCommit) await beforeCommit(address, options.extraData)
        const failure = isCommit ? faults.shift() : undefined
        if (failure === 'before-accept') throw Object.assign(new Error('offline'), { code: 2300007 })
        // Intentionally no ETag or conditional-header enforcement: this models the reported server.
        files.set(address, options.extraData)
        if (failure === 'lost-response') throw Object.assign(new Error('reply lost'), { code: 2300007 })
        return response(201)
      }
      throw new Error('Unexpected method ' + method)
    },
    destroy() {},
  }) }
  const { DeviceSyncWebDav } = compile('DeviceSyncWebDav', {
    './DeviceSyncWire': wire, './DeviceSyncJournal': journal, '../remote/WebDavClient': xml,
    '@kit.NetworkKit': { http },
    '@kit.ArkTS': { taskpool: { execute: async (fn, ...args) => fn(...args) },
      url: { URL: { parseURL: text => new URL(text) } }, util: {
      Base64Helper: class { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64') } },
      TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder('utf-8', { fatal: true }).decode(bytes) }) },
    } },
  })
  function seedObject(object, base = root) { files.set(base + wire.syncShardPath(object.ref), object.body) }
  function seedCommit(manifest, parents = []) {
    const body = journal.syncCommitBody(manifest, parents)
    const name = journal.syncCommitName(body)
    files.set(root + name, body)
    return name
  }
  class V2WebDav extends DeviceSyncWebDav {
    constructor(draft, witnesses, space) { super(draft, witnesses, space) }
  }
  return { draft, root, writerRoot, legacy, files, directories, trace, faults,
    DeviceSyncWebDav: V2WebDav, WriterWebDav: DeviceSyncWebDav, seedObject, seedCommit,
    provider: witnesses => new DeviceSyncWebDav(draft, witnesses),
    listing: filter => { filterListing = filter }, onCommit: hook => { beforeCommit = hook },
    onRequest: hook => { beforeRequest = hook } }
}

function dataset(group, key, replica, value) {
  return wire.buildSyncDataset(group,
    [edit(facts.emptySyncFact(key), dot(replica, 1), 'set', value)], 1, undefined, data.syncBucketKey)
}
function manifest(space, datasets, revision = 1) {
  return { ...wire.newSyncManifest(space), revision, datasets, previous: [] }
}
const pageNumber = data.syncKey(['global', 'page-number'])
const animation = data.syncKey(['global', 'animation'])

function readingDevice(fixture, id, installed, withShelf = false) {
  const filesDir = '/' + id
  const files = new Map()
  const fileIo = { access: async file => files.has(file), readText: async file => files.get(file),
    accessSync: file => files.has(file), readTextSync: file => files.get(file),
    unlinkSync: file => files.delete(file) }
  const writeAppTextFile = (file, content) => files.set(file, content)
  const nativeFs = { fileIo }
  const signals = compile('DeviceSyncSignals')
  const backup = compile('../model/BackupRestoreActivity')
  const comics = compile('../model/ComicModels')
  const registry = { getInstalledSourcePackage: source => installed.get(source) }
  const sessions = compile('../model/ReaderSessionStore', {
    '@kit.CoreFileKit': nativeFs, './AppFileTextPersistence': { writeAppTextFile },
    './BackupRestoreActivity': backup, '../deviceSync/DeviceSyncSignals': signals, './ComicModels': comics,
    './SourceTextOverlay': {}, './SourceRequiredImageDecode': {}, './SourceTextPageDescriptor': {},
    '../sourceRuntime/SourceRuntimeAppRegistry': registry, '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn: noop } },
    './ReaderChapterSequence': {}, '../i18n/AppStrings': {}, './RemoteReaderSession': {}, './ChapterReadStateStore': {},
  })
  files.set(filesDir + '/' + sessions.READER_PROGRESS_PERSISTENCE_FILE_NAME, sessions.serializeReaderSessionForDevice({
    progress: [], sourceHistory: [], chapters: [],
  }))
  const strings = { AppStrings: { get: key => key } }
  const smart = withShelf ? compile('../model/LibrarySmartCategory', { './ComicModels': comics, '../i18n/AppStrings': strings }) : undefined
  const stores = withShelf ? compile('../model/LibraryStore', { './ComicModels': comics, './ReaderSessionStore': sessions,
    './LibrarySmartCategory': smart, '../i18n/AppStrings': strings }) : undefined
  const persistence = withShelf ? compile('../model/LibraryPersistence', {
    './ComicModels': comics, './LibraryStore': stores, './LibrarySmartCategory': smart, '@kit.CoreFileKit': nativeFs,
    './AppFileTextPersistence': { writeAppTextFile }, '../deviceSync/DeviceSyncSignals': signals,
    '../deviceSync/DeviceSyncData': data, '../deviceSync/DeviceSyncFacts': facts,
    './BackupRestoreActivity': backup, '../i18n/AppStrings': strings, './SourceTextOverlay': {},
    './SourceRequiredImageDecode': {}, './SourceChapterMetadata': {}, './SourceTextPageDescriptor': {},
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { debug: noop, exception: noop } },
    './LocalLibraryMetadataService': {}, './LocalLibraryFolderContract': {},
    './LocalLibraryRescanService': {},
  }) : { LIBRARY_STORE_PERSISTENCE_FILE_NAME: 'library.json', LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION: 1 }
  const { KomaDeviceSyncOwners } = compile('DeviceSyncOwners', {
    '@kit.CoreFileKit': nativeFs, '@kit.ArkTS': {
      util: { generateRandomUUID: randomUUID },
      taskpool: { execute: async (fn, ...args) => fn(...args) },
    },
    '../model/AppFileTextPersistence': { writeAppTextFile }, '../model/BackupRestoreActivity': backup,
    '../model/LibraryPersistence': persistence,
    '../model/ReaderSessionStore': sessions, '../model/ReaderPreferencesStore': {}, '../model/ComicModels': comics,
    '../model/SearchHistoryStore': {}, '../model/SourceLibraryComic': compile('../model/SourceLibraryComic', {
      './ComicModels': comics, '../i18n/AppStrings': {},
    }),
    '../sourceRuntime/SourceIndexService': {}, '../sourceRuntime/SourceIndexMetadata': {},
    './DeviceSyncFacts': facts, './DeviceSyncData': data, './DeviceSyncSignals': signals, './DeviceSyncWire': wire,
  })
  const context = { filesDir }
  let owner
  const replica = fixture.replica(id, [], store => { owner = new KomaDeviceSyncOwners(context, store); return owner })
  const runtime = runtimeFixture({ './DeviceSyncSignals': signals, '../model/ReaderSessionStore': sessions,
    '../sourceRuntime/SourceRuntimeAppRegistry': registry, '@kit.ArkTS': { util: { generateRandomUUID: randomUUID } } })
  Object.assign(runtime, { context, owners: owner, engine: replica.engine, storage: replica.store })
  signals.connectDeviceSyncReadingCapture(rows => runtime.stagePositions(rows), capture => owner.readingAcknowledged(capture),
    rows => runtime.stageReaderActions(rows), capture => owner.readingActionAcknowledged(capture))
  const reader = sessions.appReaderSessionStore(filesDir)
  const coldReader = () => new sessions.PersistentReaderSessionStore(new sessions.AppFilesReaderSessionPersistenceAdapter(filesDir))
  const coldShelf = () => {
    const shelf = new stores.InMemoryLibraryStore()
    const service = new persistence.LibraryStorePersistenceService(shelf, new persistence.AppFilesLibraryStorePersistenceAdapter(filesDir))
    service.restore()
    return { shelf, service }
  }
  if (withShelf) {
    signals.connectDeviceSyncOwnerEdits(actions => runtime.recordLibrary(actions), noop, noop,
      () => replica.engine.groupScope('shelf') ? replica.engine.active()?.space : undefined)
  }
  return { ...replica, runtime, reader, coldReader, coldShelf, persistence, owner }
}

function shelfComic(source, work, categoryIds = [], url = 'https://works.example.test/title/12') {
  return { id: source + ':' + work, sourceRuntimeId: source, remoteResourceId: work, title: 'Series ' + work,
    sourceKind: 'private_library', sourcePath: url, sortTitle: work, preferredDirection: 'right_to_left',
    categoryIds, sourceMetadata: { sourceName: 'Source ' + source }, chapters: [], chapterCount: 0, pageCount: 0,
    createdAt: 1, updatedAt: 1, lastImportedAt: 1 }
}

test('automatic first merge persists a shared chapter directory and unread count with no source installed', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = readingDevice(fixture, A, new Map(), true)
  const b = readingDevice(fixture, B, new Map(), true)
  const source = 'org.example.login', work = 'account-book:series'
  const comic = shelfComic(source, work)
  comic.coverUri = comic.customCoverUri = 'file:///local/custom-cover.png'
  comic.sourceCoverUri = 'https://images.example.test/covers/series.jpg'
  const ids = Array.from({ length: 440 }, (_, index) => 'stable-chapter-id:' + index)
  comic.sourceMetadata = { ...comic.sourceMetadata, sharedChapterIds: ids, chapterCatalogUpdatedAt: 123 }
  comic.chapterCount = ids.length
  const local = a.coldShelf()
  a.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, comic)
  a.reader.markChapterReadStates([{ comicId: comic.id, chapterId: ids[0], isRead: true }],
    { sourceId: source, mangaId: work })
  assert.equal(a.reader.flush(), true)
  for (const device of [a, b]) {
    device.engine.setSelection(['shelf', 'reading'])
    await device.engine.saveConfiguration(transport.draft)
    device.engine.setEnabled(true)
    await device.engine.syncNow()
    assert.equal(device.engine.active().reviewRequired, false)
  }
  const received = b.coldShelf().shelf.getComic(comic.id)
  assert.equal(received.coverUri, comic.sourceCoverUri)
  assert.equal(received.customCoverUri, undefined)
  assert.equal(received.chapterCount, ids.length)
  assert.deepEqual(received.sourceMetadata.sharedChapterIds, ids)
  assert.equal(b.coldReader().unreadChapterCount(received), ids.length - 1)
  assert.equal(b.coldReader().comicReadingState(received), 'reading')
})

test('revoking a scope during the first network request neither applies it nor restores the old selection', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const a = fixture.replica(A, [['reader-settings', new Map([[pageNumber, 'false']])]])
  const b = fixture.replica(B, [['reader-settings', new Map([[pageNumber, 'true']])]])
  b.snapshotExtras.set('reader-settings', { defaultKeys: [pageNumber] })
  a.engine.setSelection(['shelf', 'reader-settings'])
  await a.engine.saveConfiguration(f.draft)
  a.engine.setEnabled(true)
  await a.engine.syncNow()
  b.engine.setSelection(['shelf', 'reader-settings'])
  await b.engine.saveConfiguration(f.draft)
  b.engine.setEnabled(true)
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const resumed = new Promise(resolve => { release = resolve })
  f.onRequest(async (method, address) => {
    if (method === 'PROPFIND' && address === f.root) { enter(); await resumed }
  })
  const rejected = assert.rejects(b.engine.syncNow(), /connection_changed/)
  await entered
  b.engine.setSelection(['shelf'])
  release()
  await rejected
  f.onRequest(async () => {})
  await b.engine.syncNow()
  assert.deepEqual(b.engine.active().selected, ['shelf'])
  assert.equal(b.values.get('reader-settings').get(pageNumber), 'true')
  b.engine.setSelection(['shelf', 'reader-settings'])
  await b.engine.syncNow()
  assert.equal(b.values.get('reader-settings').get(pageNumber), 'false')
  b.values.get('reader-settings').set(pageNumber, 'true')
  await b.engine.syncNow()
  await a.engine.syncNow()
  assert.equal(a.values.get('reader-settings').get(pageNumber), 'true')
})

test('a missing settings shard keeps that group pending while the received bookshelf lands', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const book = data.syncKey(['book', 'org.example.other', 'book:12'])
  const label = JSON.stringify({ title: 'Book 12', sourceName: 'Source' })
  const a = fixture.replica(A, [['shelf', new Map([[book, label]])],
    ['reader-settings', new Map([[pageNumber, 'false']])]])
  const b = fixture.replica(B, [])
  const groups = ['shelf', 'reader-settings']
  a.engine.setSelection(groups)
  await a.engine.saveConfiguration(f.draft)
  a.engine.setEnabled(true)
  await a.engine.syncNow()
  const published = [...f.files.entries()].find(([address]) => address.startsWith(f.writerRoot) &&
    /\/[0-9]{16}-[0-9a-f]{64}\.json$/.test(address))
  const settings = JSON.parse(published[1]).manifest.datasets.find(row => row.id === 'reader-settings-records')
  const path = f.writerRoot + wire.syncShardPath(settings.shards[0])
  const body = f.files.get(path)
  assert.ok(f.files.delete(path))
  b.engine.setSelection(groups)
  await b.engine.saveConfiguration(f.draft)
  b.engine.setEnabled(true)
  await assert.rejects(b.engine.syncNow(), /sync_partial:sync_shard_missing/)
  assert.equal(b.values.get('shelf').get(book), label)
  assert.equal(b.values.get('reader-settings')?.get(pageNumber), undefined)
  f.files.set(path, body)
  await b.engine.syncNow()
  assert.equal(b.values.get('reader-settings').get(pageNumber), 'false')
})

test('a damaged current group falls back across writer segments for a new device without rewinding an existing one', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const scope = ['shelf', 'reader-settings']
  const settings = 'reader-settings-records'
  const book = data.syncKey(['book', 'org.example.source', 'fallback'])
  const label = JSON.stringify({ title: 'Healthy group', sourceName: 'Source' })
  const first = [edit(facts.emptySyncFact(pageNumber), dot(A, 1), 'set', 'true'),
    edit(facts.emptySyncFact(animation), dot(A, 2), 'set', 'false')]
  const second = [edit(first[0], dot(A, 3), 'set', 'false'), edit(first[1], dot(A, 4), 'set', 'true')]
  const previous = wire.buildSyncDataset(settings, first, 1, undefined, data.syncBucketKey)
  const latest = wire.buildSyncDataset(settings, second, 1, previous.ref, data.syncBucketKey)
  assert.equal(latest.objects.length, 2, 'damage one of two separately updated shards')
  const shelf = dataset(data.SYNC_SHELF_CATALOG_DATASET, book, A, label)
  for (const [revision, datasets] of [[128, [previous]], [129, [latest, shelf]]]) {
    for (const d of datasets) for (const obj of d.objects) await writer.storeObject(obj, noop)
    await writer.publish(manifest(writer.spaceId(), datasets.map(d => d.ref), revision), '', noop, noop,
      [settings, data.SYNC_SHELF_CATALOG_DATASET])
  }
  const connect = async device => {
    device.engine.setSelection(scope)
    await device.engine.saveConfiguration(f.draft)
    device.engine.setEnabled(true)
  }
  const warm = fixture.replica(C)
  await connect(warm)
  await warm.engine.syncNow()
  assert.equal(warm.values.get('reader-settings').get(pageNumber), 'false')
  const shard = latest.objects[0]
  f.files.set(f.writerRoot + wire.syncShardPath(shard.ref), 'broken')
  const cold = fixture.replica(B)
  await connect(cold)
  const firstWrites = f.trace.filter(row => row.method === 'PUT' && row.address.startsWith(f.writerRoot)).length
  await assert.rejects(cold.engine.syncNow(), /sync_partial:sync_shard_damaged/)
  assert.deepEqual([...cold.values.get('reader-settings')].sort(), [[pageNumber, 'true'], [animation, 'false']].sort())
  assert.equal(cold.values.get('shelf').get(book), label)
  assert.equal(cold.engine.active().frontier.some(path => path.includes('/0000000000000129-')), true)
  assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address.startsWith(f.writerRoot)).length, firstWrites)
  await assert.rejects(warm.restart().syncNow(), /sync_partial:sync_shard_damaged/)
  assert.equal(warm.values.get('reader-settings').get(pageNumber), 'false')
  const explicit = fixture.replica(randomUUID(), [['reader-settings', new Map([[animation, 'true']])]])
  explicit.snapshotExtras.set('reader-settings', { defaultKeys: [animation], unsetKeys: [] })
  await connect(explicit)
  await assert.rejects(explicit.engine.syncNow(), /sync_partial:sync_shard_damaged/)
  assert.equal(explicit.values.get('reader-settings').get(animation), 'true',
    'an explicitly stored default is not an unset setting eligible for fallback')
  warm.values.get('reader-settings').set(animation, 'false')
  warm.engine.recordEdits('reader-settings', [{ key: animation, kind: 'set', value: 'false' }])
  const pending = structuredClone(warm.engine.active().groups.find(group => group.id === 'reader-settings').pending)
  assert.ok(pending.length > 0)
  await assert.rejects(warm.restart().syncNow(), /sync_partial:sync_shard_damaged/)
  assert.deepEqual(warm.engine.active().groups.find(group => group.id === 'reader-settings').pending, pending)
  f.files.set(f.writerRoot + wire.syncShardPath(shard.ref), shard.body)
  await cold.restart().syncNow()
  assert.equal(cold.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(cold.values.get('reader-settings').get(animation), 'true')
  assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address.startsWith(f.writerRoot)).length, firstWrites)
  await warm.restart().syncNow()
  assert.equal(warm.engine.active().groups.find(group => group.id === 'reader-settings').pending.length, 0)
  await cold.restart().syncNow()
  assert.equal(cold.values.get('reader-settings').get(animation), 'false')
})

test('the writer can retry a healthy group publication without revalidating an unchanged damaged group', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const book = data.syncKey(['book', 'org.example.source', 'healthy'])
  const label = JSON.stringify({ title: 'Healthy', sourceName: 'Source' })
  const writer = fixture.replica(A, [['reader-settings', new Map([[pageNumber, 'false']])]])
  writer.engine.setSelection(['shelf', 'reader-settings'])
  await writer.engine.saveConfiguration(f.draft)
  writer.engine.setEnabled(true)
  await writer.engine.syncNow()
  const prior = (await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)).own
  const broken = prior.datasets.find(ref => ref.id === 'reader-settings-records')
  const shardPath = f.writerRoot + wire.syncShardPath(broken.shards[0])
  const body = f.files.get(shardPath)
  f.files.delete(shardPath)
  writer.values.set('shelf', new Map([[book, label]]))
  f.faults.push('before-accept')
  const reopened = writer.restart()
  await assert.rejects(reopened.syncNow(), /sync_remote_result_unknown/)
  assert.deepEqual(writer.store.load().intent.writtenDatasets, [data.SYNC_SHELF_CATALOG_DATASET])
  await assert.rejects(writer.restart().syncNow(), /sync_partial:sync_shard_missing/)
  const current = (await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)).own
  assert.deepEqual(current.datasets.find(ref => ref.id === broken.id), broken)
  const receiver = fixture.replica(B)
  receiver.engine.setSelection(['shelf'])
  await receiver.engine.saveConfiguration(f.draft)
  receiver.engine.setEnabled(true)
  await receiver.engine.syncNow()
  assert.equal(receiver.values.get('shelf').get(book), label)
  f.files.set(shardPath, body)
  await writer.restart().syncNow()
})

test('source shelf and category survive an interrupted move; retry publishes both, and a new favorite stays uncategorized', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = readingDevice(fixture, A, new Map(), true)
  const b = readingDevice(fixture, B, new Map(), true)
  const c = readingDevice(fixture, C, new Map(), true)
  const connect = async device => {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const local = a.coldShelf()
  const category = local.shelf.createCustomCategory('Reading')
  const original = shelfComic('com.example.public', 'old', [category.id])
  const target = shelfComic('org.example.login', 'new', [category.id], 'https://works.example.test/title/12?session_id=private')
  a.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, original)
  await a.runtime.libraryEdits
  await connect(a)
  await connect(b)
  assert.equal(b.coldShelf().shelf.getComic(original.id).sourcePath, original.sourcePath)
  assert.equal(b.coldShelf().shelf.listCustomCategories()[0].name, 'Reading')
  assert.equal(b.coldShelf().shelf.getComic(original.id).categoryIds.length, 1)
  a.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, target)
  a.persistence.removeComicRecordAndPersistLibraryStore(local.shelf, local.service, original.id, target)
  assert.equal(a.coldShelf().shelf.listSyncShelfMoves()[0].target.toSource, target.sourceRuntimeId)
  const backup = a.persistence.libraryStoreBackupPayload(a.persistence.serializeLibraryStore(a.coldShelf().shelf))
  assert.equal(JSON.parse(backup).syncShelfMoves, undefined)
  await a.runtime.libraryEdits
  transport.faults.push('before-accept')
  await assert.rejects(a.engine.syncNow(), /sync_remote_result_unknown/)
  await b.engine.syncNow()
  assert.ok(b.coldShelf().shelf.getComic(original.id))
  assert.equal(b.coldShelf().shelf.getComic(target.id), undefined)
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldShelf().shelf.getComic(original.id), undefined)
  const received = b.coldShelf().shelf.getComic(target.id)
  assert.equal(received.categoryIds.length, 1)
  assert.match(received.sourcePath, /^source:\/\//)
  assert.equal([...transport.files.values()].some(value => value.includes('session_id=private')), false)
  const firstMerge = c.coldShelf()
  c.persistence.upsertComicAndPersistLibraryStore(firstMerge.shelf, firstMerge.service, original)
  await connect(c)
  assert.equal(c.coldShelf().shelf.getComic(original.id), undefined)
  assert.equal(c.engine.active().reviewRequired, false)
  const onB = b.coldShelf()
  b.persistence.upsertComicAndPersistLibraryStore(onB.shelf, onB.service, { ...original, categoryIds: [] })
  await b.runtime.libraryEdits
  await b.engine.syncNow()
  await a.engine.syncNow()
  await c.engine.syncNow()
  for (const device of [a, b, c]) assert.deepEqual(device.coldShelf().shelf.getComic(original.id).categoryIds ?? [], [])
})

test('a move keeps the original if the destination was independently removed, including a receiver with local notes', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = readingDevice(fixture, A, new Map(), true)
  const b = readingDevice(fixture, B, new Map(), true)
  const original = shelfComic('com.example.public', 'old')
  const target = shelfComic('org.example.login', 'new')
  const left = a.coldShelf()
  for (const book of [original, target]) a.persistence.upsertComicAndPersistLibraryStore(left.shelf, left.service, book)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const right = b.coldShelf()
  b.persistence.upsertComicAndPersistLibraryStore(right.shelf, right.service,
    { ...right.shelf.getComic(original.id), personalNotes: 'My notes' })
  b.persistence.removeComicRecordAndPersistLibraryStore(right.shelf, right.service, target.id)
  a.persistence.removeComicRecordAndPersistLibraryStore(left.shelf, left.service, original.id, target)
  await b.runtime.libraryEdits
  await b.engine.syncNow()
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldShelf().shelf.getComic(target.id), undefined)
  assert.equal(b.coldShelf().shelf.getComic(original.id).personalNotes, 'My notes')
  assert.deepEqual(b.owner.blockedShelfItems(), [])
})

test('shelf receipts cannot update an unrelated row with the same storage ID', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = readingDevice(fixture, A, new Map(), true)
  const b = readingDevice(fixture, B, new Map(), true)
  const original = shelfComic('org.example.source', 'same')
  const left = a.coldShelf()
  a.persistence.upsertComicAndPersistLibraryStore(left.shelf, left.service, original)
  const right = b.coldShelf()
  const resident = { ...original, sourceRuntimeId: undefined, sourceKind: 'komga_remote',
    remoteServerId: 'server', sourcePath: 'komga://server/same', title: 'Private library' }
  b.persistence.upsertComicAndPersistLibraryStore(right.shelf, right.service, resident)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  a.persistence.removeComicRecordAndPersistLibraryStore(left.shelf, left.service, original.id)
  await a.runtime.libraryEdits
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldShelf().shelf.getComic(original.id).title, 'Private library')
})

test('batch shelf removal persists selected source favorites and syncs their removals', async () => {
  const transport = transportFixture()
  const fixture = engineFixture(transport.WriterWebDav)
  const a = readingDevice(fixture, A, new Map(), true)
  const b = readingDevice(fixture, B, new Map(), true)
  const left = a.coldShelf()
  const books = ['first', 'second', 'retained'].map(work => shelfComic('org.example.source', work))
  for (const book of books) a.persistence.upsertComicAndPersistLibraryStore(left.shelf, left.service, book)
  for (const device of [a, b]) {
    await device.engine.testConnection(transport.draft)
    await device.engine.confirm((await device.engine.prepare(transport.draft, ['shelf'])).token, [])
  }
  const ids = books.slice(0, 2).map(book => book.id)
  assert.throws(() => a.persistence.removeComicsAndPersistLibraryStore(left.shelf,
    { persist: () => { throw Error('disk full') } }, ids), /disk full/)
  assert.ok(ids.every(id => left.shelf.getComic(id)))
  assert.deepEqual(Array.from(a.persistence.removeComicsAndPersistLibraryStore(left.shelf, left.service, ids)), ids)
  await a.runtime.libraryEdits
  await a.engine.syncNow()
  await b.engine.syncNow()
  const right = b.coldShelf().shelf
  assert.ok(ids.every(id => right.getComic(id) === undefined))
  assert.ok(right.getComic(books[2].id))
})

test('a writer keeps its original shelf shards while publishing new source books after upgrade', async () => {
  const f = transportFixture()
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const old = shelfComic('com.xkcd.zh.koma', 'xkcd:zh')
  const oldKey = data.syncKey(['book', old.sourceRuntimeId, old.remoteResourceId])
  const oldShard = dataset('shelf', oldKey, A, JSON.stringify({ title: 'xkcd', sourceName: 'xkcd 中文', sourceVersion: '0.1.7' }))
  for (const object of oldShard.objects) await writer.storeObject(object, noop)
  await writer.publish(manifest(writer.spaceId(), [oldShard.ref]), '', noop, noop, ['shelf'])
  const device = readingDevice(engineFixture(f.WriterWebDav), A, new Map(), true)
  const connect = async row => {
    await row.engine.testConnection(f.draft)
    await row.engine.confirm((await row.engine.prepare(f.draft, ['shelf'])).token, [])
  }
  await connect(device)
  const local = device.coldShelf()
  assert.equal(local.shelf.getComic(old.id).title, 'xkcd')
  const added = shelfComic('com.example.public', 'new')
  device.persistence.upsertComicAndPersistLibraryStore(local.shelf, local.service, added)
  await device.runtime.libraryEdits
  await device.engine.syncNow()
  const receipt = await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)
  assert.deepEqual(receipt.own.datasets.find(item => item.id === 'shelf'), oldShard.ref)
  assert.ok(receipt.own.datasets.some(item => item.id === data.SYNC_SHELF_CATALOG_DATASET))
  const other = readingDevice(engineFixture(f.WriterWebDav), B, new Map(), true)
  await connect(other)
  assert.deepEqual(other.coldShelf().shelf.listComics().map(book => book.id).sort(), [old.id, added.id].sort())
})

test('saved history and live page turns from other sources reach a fresh reader without a source request', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const publicId = 'com.webtoons.zh-hant.koma'
  const loginId = 'org.example.login-required'
  const enabled = { enabled: true, version: '7.0.1', name: 'Login source' }
  const installedOnB = new Map()
  const a = readingDevice(fixture, A, new Map([[loginId, enabled]]))
  const b = readingDevice(fixture, B, installedOnB)
  const work = 'webtoon:1860'
  const chapter = 'chapter:webtoons:zh-Hant:/zh-hant/title/viewer?title_no=1860&episode_no=15'
  const previousChapter = chapter.replace('episode_no=15', 'episode_no=14')
  const publicComic = publicId + ':' + work
  const publicUrl = 'https://www.webtoons.com/zh-hant/title/list?title_no=1860'
  const publicCover = 'https://images.example.test/covers/1860.jpg?width=300'
  const save = (reader, comicId, chapterId, pageIndex, totalPages, updatedAt) => reader.saveProgress({
    comicId, chapterId, pageIndex, totalPages, updatedAt, progressRatio: (pageIndex + 1) / totalPages, completed: false,
  })
  save(a.reader, publicComic, previousChapter, 2, 9, 100)
  save(a.reader, publicComic, chapter, 5, 11, 200)
  a.reader.saveSourceHistory({ comicId: publicComic, sourceId: publicId, mangaId: work, title: '普通書源',
    sourceName: 'WEBTOON', chapterId: chapter, chapterTitle: '第 15 話', mangaUrl: publicUrl, coverUri: publicCover })
  const removedWork = 'webtoon:cleared-history'
  const removedComic = publicId + ':' + removedWork
  save(a.reader, removedComic, previousChapter, 4, 10, 100)
  a.reader.saveSourceHistory({ comicId: removedComic, sourceId: publicId, mangaId: removedWork, title: 'Cleared history',
    chapterId: previousChapter })
  assert.equal(a.reader.removeHistoryEntries([removedComic]), true)
  assert.equal(a.reader.flush(), true)
  const connect = async device => {
    await device.engine.testConnection(f.draft)
    await device.engine.confirm((await device.engine.prepare(f.draft, ['reading'])).token, [])
  }
  await connect(a)
  await connect(b)
  let cold = b.coldReader()
  assert.equal(cold.getSourceHistory(publicComic).mangaUrl, publicUrl)
  assert.equal(cold.getSourceHistory(publicComic).coverUri, publicCover)
  const head = (await new f.WriterWebDav(f.draft, [], undefined, A).readManifest(noop)).own
  const coverRef = head.datasets.find(row => row.id === 'reading-cover-records')
  const readingRef = head.datasets.find(row => row.id === data.SYNC_READING_DATASET)
  assert.ok(coverRef && readingRef)
  for (const ref of readingRef.shards) {
    assert.equal(f.files.get(f.writerRoot + wire.syncShardPath(ref)).includes(publicCover), false)
  }
  assert.equal(cold.getProgress(publicComic).updatedAt, a.reader.getProgress(publicComic).updatedAt)
  assert.equal(cold.getProgress(publicComic).pageIndex, 5)
  assert.equal(cold.getChapterProgress(publicComic, previousChapter).pageIndex, 2)
  assert.equal(cold.getSourceHistory(removedComic), undefined)
  assert.equal(cold.getChapterProgress(removedComic, previousChapter).pageIndex, 4)
  // The previous app could save a page without a capture when its gate rejected the source.
  save(a.reader, publicComic, chapter, 7, 11, 250)
  assert.equal(a.reader.flush(), true)
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldReader().getChapterProgress(publicComic, chapter).pageIndex, 7)
  const loginWork = loginId + ':work-77'
  const loginChapter = 'chapter:work-77:2#第 2 話'
  const request = { comicId: loginWork, sourceId: loginId, mangaId: loginWork, chapterId: loginChapter,
    chapterIds: [loginChapter], chapterTitles: ['第 2 話'], title: 'Login work',
    mangaUrl: 'https://login.invalid/77?%2574oken=credential-sentinel' }
  assert.equal(a.runtime.openReading(request), 'ready')
  save(a.reader, loginWork, loginChapter, 6, 13, 300)
  a.runtime.observeReading(a.reader.getProgress(loginWork))
  assert.equal(a.reader.flush(), true)
  await a.runtime.recordPositions()
  await a.engine.syncNow()
  await b.engine.syncNow()
  cold = b.coldReader()
  assert.equal(cold.getSourceHistory(loginWork).chapterId, loginChapter)
  assert.equal(cold.getSourceHistory(loginWork).mangaUrl, undefined)
  assert.equal(cold.getChapterProgress(loginWork, loginChapter).pageIndex, 6)
  assert.equal(cold.openPageIndex({ comicId: loginWork, chapterId: loginChapter, totalPages: 13, pageUris: [] }, 'resume'), 6)
  assert.equal(b.runtime.openReading(request), 'missing')
  installedOnB.set(loginId, enabled)
  assert.equal(b.runtime.openReading(request), 'ready')
  assert.equal(b.runtime.validateReadingPages(loginWork, loginChapter, 13), true)
  assert.equal(b.runtime.validateReadingPages(loginWork, loginChapter, 12), false)
  assert.ok([...f.files.values()].every(body => !body.includes('credential-sentinel')))
  const puts = f.trace.filter(row => row.method === 'PUT').length
  await b.engine.syncNow()
  assert.equal(f.trace.filter(row => row.method === 'PUT').length, puts, 'receiving reading progress must not reupload it')
  assert.equal(a.reader.removeHistoryEntries([loginWork]), true)
  await a.runtime.recordPositions()
  await a.engine.syncNow()
  await b.engine.syncNow()
  assert.equal(b.coldReader().getSourceHistory(loginWork), undefined)
  assert.equal(b.coldReader().getChapterProgress(loginWork, loginChapter).pageIndex, 6, 'removing history keeps the saved chapter position')
})

test('a local position missed by the old client survives an independent remote position on upgrade', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const source = 'org.example.newly-supported'
  const key = data.syncKey(['position', source, 'work:1', 'chapter:1'])
  const a = fixture.replica(A)
  const b = fixture.replica(B)
  for (const device of [a, b]) {
    await device.engine.testConnection(f.draft)
    await device.engine.confirm((await device.engine.prepare(f.draft, ['reading'])).token, [])
  }
  const local = JSON.stringify({ page: 5, total: 11, date: 100 })
  const remote = JSON.stringify({ page: 8, total: 11, date: 200 })
  a.values.set('reading', new Map([[key, local]]))
  b.values.set('reading', new Map([[key, remote]]))
  b.engine.recordEdits('reading', [{ key, kind: 'set', value: remote }])
  await b.engine.syncNow()
  await a.engine.syncNow()
  const merged = a.engine.active().groups.find(group => group.id === 'reading').facts.find(row => row.key === key)
  assert.deepEqual(new Set(facts.syncVisibleHeads(merged).map(head => head.value)), new Set([local, remote]))
  assert.equal(a.values.get('reading').get(key), remote)
})

test('independent writer publications receive chapter and page without shared conditional writes', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const a = fixture.replica(A)
  const b = fixture.replica(B)
  const source = 'org.mangadex.koma'
  const work = 'mdx:11111111-1111-1111-1111-111111111111'
  const chapter = 'ch:22222222-2222-2222-2222-222222222222'
  const recent = data.syncKey(['recent', source, work])
  const position = data.syncKey(['position', source, work, chapter])
  const chapterValue = JSON.stringify({ title: 'Public work', sourceName: 'MangaDex', sourceVersion: '0.1.25',
    chapter, chapterTitle: 'Chapter', date: 123 })
  const pageValue = JSON.stringify({ page: 5, total: 9, pageTable: 'a'.repeat(64) })
  const connect = async replica => {
    await replica.engine.testConnection(f.draft)
    const preview = await replica.engine.prepare(f.draft, ['reading', 'reader-settings'])
    await replica.engine.confirm(preview.token, [])
  }
  await connect(a)
  await connect(b)
  a.values.get('reading').set(recent, chapterValue)
  a.values.get('reading').set(position, pageValue)
  a.engine.recordEdits('reading', [{ key: recent, kind: 'set', value: chapterValue },
    { key: position, kind: 'set', value: pageValue }])
  b.values.get('reader-settings').set(pageNumber, 'false')
  await Promise.all([a.engine.syncNow(), b.engine.syncNow()])
  await b.engine.syncNow()
  assert.equal(b.values.get('reading').get(recent), chapterValue)
  assert.equal(b.values.get('reading').get(position), pageValue)
  await a.engine.syncNow()
  assert.equal(a.values.get('reader-settings').get(pageNumber), 'false')
  const own = await new f.WriterWebDav(f.draft, [], undefined, B).readManifest(noop)
  assert.equal(own.own.datasets.some(row => row.id === data.SYNC_READING_DATASET), false)
  assert.equal(f.trace.some(row => row.method === 'PUT' &&
    ('If-Match' in row.headers || 'If-None-Match' in row.headers)), false)
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))), false)
})

test('reading publications retain the old dataset and verify new shards before recovering a missing publication', async () => {
  const f = transportFixture()
  const oldWriter = new f.WriterWebDav(f.draft, [], undefined, C)
  const legacy = dataset('reading', data.syncKey(['position', 'com.xkcd.zh.koma', 'xkcd:zh', 'xkcdch:zh:1']),
    C, JSON.stringify({ page: 1, total: 3, pageTable: 'a'.repeat(64) }))
  for (const object of legacy.objects) await oldWriter.storeObject(object, noop)
  await oldWriter.publish(manifest(oldWriter.spaceId(), [legacy.ref]), '', noop, noop, ['reading'])
  const writer = engineFixture(f.WriterWebDav).replica(A)
  await writer.engine.testConnection(f.draft)
  await writer.engine.confirm((await writer.engine.prepare(f.draft, ['reading'])).token, [])
  const key = data.syncKey(['position', 'org.example.login-required', 'work:77', 'chapter:77:2'])
  const value = JSON.stringify({ page: 5, total: 9, date: 123 })
  writer.values.get('reading').set(key, value)
  const version = writer.engine.recordEdits('reading', [{ key, kind: 'set', value }])
  f.faults.push('before-accept')
  await assert.rejects(writer.engine.syncNow())
  const intent = writer.store.load().intent
  assert.ok(intent?.sent)
  const shard = JSON.parse(intent.commitBody).manifest.datasets.find(row => row.id === data.SYNC_READING_DATASET).shards[0]
  const address = [...f.files.keys()].find(name => name.endsWith('/' + wire.syncShardPath(shard)))
  const bytes = f.files.get(address)
  assert.ok(bytes)
  f.files.delete(address)
  await assert.rejects(writer.restart().syncNow())
  assert.ok(writer.store.load().active.groups[0].pending.some(row => row.version.sequence === version.sequence))
  f.files.set(address, bytes)
  await writer.restart().syncNow()
  assert.equal(writer.store.load().active.groups[0].pending.length, 0)
  const remote = (await new f.WriterWebDav(f.draft, [], undefined, B).readManifest(noop)).manifest
  assert.equal(wire.syncDatasetBranches(remote, 'reading').length, 1)
  assert.equal(wire.syncDatasetBranches(remote, data.SYNC_READING_DATASET).length, 1)
})

test('an empty next segment preserves the last complete publication on a fresh client', async () => {
  const f = transportFixture()
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const ref = dataset('reader-settings', pageNumber, A, 'false')
  for (const object of ref.objects) await writer.storeObject(object, noop)
  const last = manifest(writer.spaceId(), [ref.ref], 128)
  await writer.publish(last, '', noop, noop, ['reader-settings'])
  f.directories.add(f.writerRoot + A + '/00000000000001/')
  const reader = new f.WriterWebDav(f.draft, [], undefined, B)
  assert.equal((await reader.readManifest(noop)).manifest.revision, 128)
})

test('a broken cover shard does not stop reading or get replaced by a retry', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.WriterWebDav)
  const source = 'org.example.login-required', work = 'work:77'
  const position = data.syncKey(['position', source, work, 'chapter:77:2'])
  const cover = data.syncKey(['cover', source, work])
  const url = 'https://images.example.test/covers/77.jpg'
  const first = JSON.stringify({ page: 2, total: 9, date: 100 })
  const latest = JSON.stringify({ page: 5, total: 9, date: 200 })
  const a = fixture.replica(A, [['reading', new Map([[position, first], [cover, JSON.stringify(url)]])]])
  const b = fixture.replica(B)
  for (const device of [a, b]) {
    device.engine.setSelection(['reading'])
    await device.engine.saveConfiguration(f.draft)
    device.engine.setEnabled(true)
    await device.engine.syncNow()
  }
  const writer = new f.WriterWebDav(f.draft, [], undefined, A)
  const coverRef = (await writer.readManifest(noop)).own.datasets.find(row => row.id === 'reading-cover-records')
  const address = f.writerRoot + wire.syncShardPath(coverRef.shards[0])
  const bytes = f.files.get(address)
  assert.ok(bytes)
  f.files.delete(address)
  a.values.get('reading').set(position, latest)
  a.engine.recordEdits('reading', [{ key: position, kind: 'set', value: latest }])
  f.faults.push('lost-response')
  await assert.rejects(a.engine.syncNow())
  await a.restart().syncNow()
  await b.restart().syncNow()
  assert.equal(b.values.get('reading').get(position), latest)
  assert.equal(b.values.get('reading').get(cover), JSON.stringify(url))
  assert.deepEqual((await writer.readManifest(noop)).own.datasets.find(row => row.id === coverRef.id), coverRef)
  assert.equal(f.files.has(address), false)
  f.files.set(address, bytes)
  const c = fixture.replica(C)
  c.engine.setSelection(['reading'])
  await c.engine.saveConfiguration(f.draft)
  c.engine.setEnabled(true)
  await c.engine.syncNow()
  assert.equal(c.values.get('reading').get(position), latest)
  assert.equal(c.values.get('reading').get(cover), JSON.stringify(url))
})

test('upgrading without local edits preserves legacy facts in a writer publication', async () => {
  const f = transportFixture()
  const v2 = f.provider()
  const old = dataset('reader-settings', pageNumber, A, 'false')
  for (const object of old.objects) f.seedObject(object)
  const oldName = f.seedCommit(manifest(v2.spaceId(), [old.ref]))
  const reader = engineFixture(f.WriterWebDav).replica(B)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  const current = await new f.WriterWebDav(f.draft, [], undefined, B).readManifest(noop)
  assert.equal(current.own.datasets[0].id, data.SYNC_READER_SETTINGS_DATASET)
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))), false)
  f.files.delete(f.root + oldName)
  reader.values.get('reader-settings').set(pageNumber, 'true')
  await assert.rejects(reader.engine.syncNow(), /sync_legacy_unavailable/)
  const reopened = await new f.WriterWebDav(f.draft, reader.engine.active().frontier, undefined, B).readManifest(noop)
  assert.equal(reopened.warning, 'sync_legacy_unavailable')
  const ref = reopened.own.datasets.find(row => row.id === data.SYNC_READER_SETTINGS_DATASET)
  const values = (await Promise.all(ref.shards.map(async shard => wire.decodeSyncShard(ref.id, shard,
    await new f.WriterWebDav(f.draft, [], undefined, B).readObject(shard, noop), data.syncBucketKey)))).flat()
  assert.equal(facts.syncVisibleValue(values.find(row => row.key === pageNumber)), 'true')
})

test('connection creates the selected directory and cleans its probe without ETag or conditional-write support', async () => {
  const f = transportFixture()
  f.directories.clear()
  const id = '11111111-1111-1111-1111-111111111111'
  await f.provider().probe(id, noop)
  assert.deepEqual(f.trace.filter(row => row.method === 'MKCOL').map(row => row.address),
    [f.draft.directory + '/', f.root])
  assert.equal(f.files.has(f.root + 'probe-' + id + '.json'), false)
  assert.equal(f.trace.some(row => row.method === 'LOCK'), false)
})

test('parallel immutable publications retain both heads and merge their selected facts', async () => {
  const f = transportFixture()
  const left = f.provider(), right = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'false')
  const b = dataset('reader-settings', animation, B, 'false')
  for (const object of a.objects.concat(b.objects)) await left.storeObject(object, noop)
  let arrived = 0, release
  const gate = new Promise(resolve => { release = resolve })
  f.onCommit(async () => { if (++arrived === 2) release(); await gate })
  const sent = [0, 0]
  assert.deepEqual(await Promise.all([
    left.publish(manifest(left.spaceId(), [a.ref]), '', noop, () => sent[0]++),
    right.publish(manifest(right.spaceId(), [b.ref]), '', noop, () => sent[1]++),
  ]), [true, true])
  assert.deepEqual(sent, [1, 1])
  const merged = await f.provider().readManifest(noop)
  assert.equal(merged.frontier.length, 2)
  const fixture = engineFixture(f.DeviceSyncWebDav)
  const reader = fixture.replica(C)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'false')
  assert.equal(reader.values.get('reader-settings').get(animation), 'false')
})

test('merging one group preserves both opaque branches without reading disabled group objects', async () => {
  const f = transportFixture()
  const provider = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'false')
  const b = dataset('reader-settings', animation, B, 'false')
  for (const object of a.objects.concat(b.objects)) f.seedObject(object)
  const opaque = text => ({ id: 'future-group', schema: 9, shards: [{ bucket: '00', epoch: 1,
    hash: wire.syncDigest(text), bytes: Buffer.byteLength(text) }] })
  const oa = opaque('opaque-a'), ob = opaque('opaque-b')
  f.seedCommit(manifest(provider.spaceId(), [a.ref, oa]))
  f.seedCommit(manifest(provider.spaceId(), [b.ref, ob]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(C)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  const merged = await f.provider().readManifest(noop)
  assert.equal(merged.frontier.length, 1)
  assert.deepEqual(wire.syncDatasetBranches(merged.manifest, 'future-group')
    .map(ref => ref.shards[0].hash).sort(), [oa.shards[0].hash, ob.shards[0].hash].sort())
  for (const ref of [oa, ob]) assert.equal(f.trace.some(row => row.method === 'GET' &&
    row.address === f.root + wire.syncShardPath(ref.shards[0])), false)
})

test('a provider retains a newly seen head when the next listing omits it', async () => {
  const f = transportFixture(), provider = f.provider()
  const a = f.seedCommit(manifest(provider.spaceId(), []))
  const b = f.seedCommit(manifest(provider.spaceId(), [], 2))
  assert.deepEqual((await provider.readManifest(noop)).frontier, [a, b].sort())
  f.listing(names => names.filter(name => name !== b))
  assert.deepEqual((await provider.readManifest(noop)).frontier, [a, b].sort())
  assert.deepEqual((await f.provider([a, b]).readManifest(noop)).frontier, [a, b].sort(),
    'a reconstructed provider must also use the saved frontier as direct witnesses')
  f.files.delete(f.root + b)
  await assert.rejects(provider.readManifest(noop), /sync_space_changed/)
})

for (const fault of ['before-accept', 'lost-response']) {
  test('exact commit recovery after ' + fault + ' preserves the original edit dot', async () => {
    const f = transportFixture()
    const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
      [['reader-settings', new Map([[pageNumber, 'true']])]])
    await reader.engine.testConnection(f.draft)
    await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
    reader.values.get('reader-settings').set(pageNumber, 'false')
    f.faults.push(fault)
    await assert.rejects(reader.engine.syncNow(), /sync_remote_result_unknown/)
    const intent = clone(reader.store.load().intent)
    assert.equal(journal.syncCommitName(intent.commitBody), intent.commit)
    assert.equal(f.files.has(f.root + intent.commit), fault === 'lost-response')
    await reader.engine.syncNow()
    assert.equal(reader.store.load().intent, undefined)
    const current = await f.provider().readManifest(noop)
    const ref = wire.syncDatasetBranches(current.manifest, data.SYNC_READER_SETTINGS_DATASET)[0]
    const values = ref.shards.flatMap(shard => wire.decodeSyncShard(ref.id, shard,
      f.files.get(f.root + wire.syncShardPath(shard)), data.syncBucketKey))
    const fact = values.find(value => value.key === pageNumber)
    assert.equal(fact.values[0].value, 'false')
    assert.deepEqual(fact.values[0].version, dot(A, 2))
    assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address === f.root + intent.commit).length,
      fault === 'lost-response' ? 1 : 2)
  })
}

test('a disconnected submitted intent is never retried into the old connection', async () => {
  const f = transportFixture()
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
    [['reader-settings', new Map([[pageNumber, 'true']])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  reader.values.get('reader-settings').set(pageNumber, 'false')
  f.faults.push('before-accept')
  await assert.rejects(reader.engine.syncNow(), /sync_remote_result_unknown/)
  const name = reader.store.load().intent.commit
  await reader.engine.disconnect()
  await reader.engine.recoverOnForeground()
  assert.equal(f.files.has(f.root + name), false)
  assert.equal(reader.engine.active(), undefined)
  assert.equal(reader.store.load().intent.detached, true)
})

test('disconnect during an accepted request prevents its late callback from applying local data', async () => {
  const f = transportFixture()
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
    [['reader-settings', new Map([[pageNumber, 'true']])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  const runtime = runtimeFixture()
  runtime.engine = reader.engine
  runtime.storage = reader.store
  runtime.refresh()
  reader.values.get('reader-settings').set(pageNumber, 'false')
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const resumed = new Promise(resolve => { release = resolve })
  f.onCommit(async () => { enter(); await resumed })
  const pending = runtime.sync()
  const rejected = assert.rejects(pending, /sync_connection_changed/)
  await entered
  const name = reader.store.load().intent.commit
  await runtime.disconnect()
  assert.equal(runtime.view.configured, false)
  assert.equal(runtime.view.error, '')
  release()
  await rejected
  assert.equal(runtime.view.error, '', 'the rejected old task must not publish an error into the disconnected service')
  assert.equal(runtime.view.busy, false)
  assert.equal(f.files.has(f.root + name), true, 'the in-flight request may already commit')
  assert.equal(reader.engine.active(), undefined)
  assert.equal(reader.store.load().intent.detached, true)
  const writes = f.trace.filter(row => row.method === 'PUT').length
  await reader.engine.recoverOnForeground()
  assert.equal(f.trace.filter(row => row.method === 'PUT').length, writes)
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'false')
})

test('v1 migration copies old objects and legacy probe cleanup touches only its exact v1 path', async () => {
  const f = transportFixture(), provider = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of a.objects) f.seedObject(object, f.legacy)
  const old = { ...manifest(A, [a.ref]), schema: 1, minWriter: 1 }
  f.files.set(f.legacy + 'manifest.json', JSON.stringify(old))
  const before = await provider.readManifest(noop)
  assert.ok(before.legacyHash)
  const next = { ...before.manifest, revision: 2 }
  assert.equal(await provider.publish(next, before.etag, noop), true)
  for (const object of a.objects) assert.equal(f.files.get(f.root + wire.syncShardPath(object.ref)), object.body)
  for (const name of [...f.files.keys()]) if (name.startsWith(f.legacy)) f.files.delete(name)
  const current = await f.provider().readManifest(noop)
  assert.equal(await f.provider().readObject(current.manifest.datasets[0].shards[0], noop), a.objects[0].body)
  const id = '11111111-1111-1111-1111-111111111111'
  f.files.set(f.legacy + 'probe-' + id + '.json', 'old-probe')
  f.files.set(f.root + 'probe-' + id + '.json', 'new-probe')
  await provider.cleanProbe(id, noop, true)
  assert.equal(f.files.has(f.legacy + 'probe-' + id + '.json'), false)
  assert.equal(f.files.get(f.root + 'probe-' + id + '.json'), 'new-probe')
})

test('combining individually valid opaque snapshots never publishes an invalid aggregate commit', async () => {
  const f = transportFixture(), provider = f.provider()
  const a = dataset('reader-settings', pageNumber, A, 'false')
  const b = dataset('reader-settings', animation, B, 'false')
  for (const object of a.objects.concat(b.objects)) f.seedObject(object)
  for (const [prefix, selected] of [['left', a], ['right', b]]) {
    const refs = Array.from({ length: 127 }, (_, index) => ({ id: prefix + '-' + index,
      schema: 9, shards: [] }))
    const head = manifest(provider.spaceId(), [selected.ref].concat(refs))
    const name = f.seedCommit(head)
    assert.doesNotThrow(() => journal.decodeSyncCommit(name, f.files.get(f.root + name)))
  }
  const reader = engineFixture(f.DeviceSyncWebDav).replica(C)
  await reader.engine.testConnection(f.draft)
  const preview = await reader.engine.prepare(f.draft, ['reader-settings'])
  await assert.rejects(reader.engine.confirm(preview.token, []), /sync_(invalid_datasets|round_too_large|manifest_too_large)/)
  assert.equal(f.trace.some(row => row.method === 'PUT' && journal.SYNC_COMMIT_NAME.test(row.address.slice(f.root.length))),
    false, 'invalid aggregate metadata must be rejected before its immutable name becomes discoverable')
})

test('migration preserves protected v1 maintenance objects without advancing or finishing old maintenance', async () => {
  const f = transportFixture(), provider = f.provider()
  const current = dataset('reader-settings', pageNumber, A, 'false')
  const previous = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of current.objects.concat(previous.objects)) f.seedObject(object, f.legacy)
  const old = { ...manifest(A, [current.ref], 2), schema: 1, minWriter: 1, epoch: 2,
    maintenance: true, previous: [previous.ref] }
  const original = JSON.stringify(old)
  f.files.set(f.legacy + 'manifest.json', original)
  const remote = await provider.readManifest(noop)
  assert.equal(remote.manifest.maintenance, false)
  assert.equal(await provider.publish({ ...remote.manifest, revision: 3 }, remote.etag, noop), true)
  assert.equal(f.files.get(f.legacy + 'manifest.json'), original)
  assert.equal(f.trace.some(row => row.address.startsWith(f.legacy) &&
    (row.method === 'PUT' || row.method === 'DELETE' || row.method === 'MKCOL')), false)
  for (const object of current.objects.concat(previous.objects)) {
    assert.equal(f.files.get(f.root + wire.syncShardPath(object.ref)), object.body)
  }
})

test('retrying a missing commit preserves opaque references without downloading disabled group data', async () => {
  const f = transportFixture(), provider = f.provider()
  const selected = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of selected.objects) f.seedObject(object)
  const body = 'opaque-disabled-group'
  const opaque = { id: 'future-group', schema: 9, shards: [{ bucket: '00', epoch: 1,
    hash: wire.syncDigest(body), bytes: Buffer.byteLength(body) }] }
  const opaqueAddress = f.root + wire.syncShardPath(opaque.shards[0])
  f.files.set(opaqueAddress, body)
  f.seedCommit(manifest(provider.spaceId(), [selected.ref, opaque]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(B)
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  reader.values.get('reader-settings').set(pageNumber, 'false')
  f.faults.push('before-accept')
  await assert.rejects(reader.engine.syncNow(), /sync_remote_result_unknown/)
  await reader.engine.syncNow()
  assert.equal(f.trace.some(row => row.method === 'GET' && row.address === opaqueAddress), false,
    'recovery must retain the ordinary unselected-group transfer boundary')
})

test('a first automatic connection retries local application without losing the received fact', async () => {
  const f = transportFixture(), provider = f.provider()
  const remote = dataset('reader-settings', pageNumber, A, 'true')
  for (const object of remote.objects) f.seedObject(object)
  f.seedCommit(manifest(provider.spaceId(), [remote.ref]))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(B)
  reader.engine.setSelection(['reader-settings'])
  await reader.engine.saveConfiguration(f.draft)
  reader.engine.setEnabled(true)
  const owner = reader.engine.owner
  const commit = owner.commit.bind(owner)
  let fail = true
  owner.commit = async (...args) => {
    if (fail) { fail = false; throw new Error('synthetic_owner_boundary') }
    return commit(...args)
  }
  await assert.rejects(reader.engine.syncNow(), /synthetic_owner_boundary/)
  assert.equal(reader.engine.active(), undefined)
  await reader.engine.syncNow()
  assert.ok(reader.engine.active(), 'automatic retry must finish the previously interrupted receive')
  assert.equal(reader.values.get('reader-settings').get(pageNumber), 'true')
})

test('service pause preserves scope and capture dots, blocks sync traffic, and is local to one engine', async () => {
  const f = transportFixture()
  const fixture = engineFixture(f.DeviceSyncWebDav)
  const source = 'org.mangadex.koma'
  const work = 'mdx:11111111-1111-1111-1111-111111111111'
  const chapter = 'ch:22222222-2222-2222-2222-222222222222'
  const positionKey = data.syncKey(['position', source, work, chapter])
  const value = JSON.stringify({ page: 1, total: 8, pageTable: 'a'.repeat(64) })
  const left = fixture.replica(A, [['reader-settings', new Map([[pageNumber, 'true']])],
    ['reading', new Map([[positionKey, value]])]])
  const right = fixture.replica(B)
  for (const replica of [left, right]) {
    await replica.engine.testConnection(f.draft)
    await replica.engine.confirm((await replica.engine.prepare(f.draft, ['reading', 'reader-settings'])).token, [])
  }
  left.store.update(state => { delete state.active.enabled })
  assert.equal(left.engine.isEnabled(), true, 'legacy credentials default to enabled')
  left.engine.setAutomatic(true)
  const before = clone(left.engine.active())
  const scope = left.engine.readingScope()
  const stale = await left.engine.prepare(f.draft, ['reading', 'reader-settings'])
  left.engine.setEnabled(false)
  assert.equal(left.engine.isEnabled(), false)
  assert.equal(left.engine.active().credential, before.credential)
  assert.deepEqual(left.engine.selection(), before.selected)
  assert.equal(left.engine.active().automatic, true)
  assert.equal(left.engine.readingScope(), scope)
  const requests = f.trace.length
  await assert.rejects(left.engine.syncNow(), /disabled|paused/)
  await assert.rejects(left.engine.prepare(f.draft, ['reading']), /disabled|paused/)
  await assert.rejects(left.engine.confirm(stale.token, []), /disabled|paused|preview_changed|connection_changed/)
  await left.engine.recoverOnForeground()
  assert.equal(f.trace.length, requests)
  left.values.get('reading').delete(positionKey)
  const captured = left.engine.recordEdits('reading', [{ key: positionKey, kind: 'delete', value: '' }])
  assert.ok(captured)
  assert.equal(f.trace.length, requests)
  right.values.get('reader-settings').set(pageNumber, 'false')
  await right.engine.syncNow()
  assert.equal(right.engine.isEnabled(), true)
  assert.equal(left.values.get('reader-settings').get(pageNumber), 'true')
  left.engine.setEnabled(true)
  await left.engine.syncNow()
  assert.equal(left.values.get('reader-settings').get(pageNumber), 'false')
  const remote = await f.provider().readManifest(noop)
  const refs = wire.syncDatasetBranches(remote.manifest, data.SYNC_READING_DATASET)
  const stored = refs.flatMap(ref => ref.shards.flatMap(shard => wire.decodeSyncShard(ref.id, shard,
    f.files.get(f.root + wire.syncShardPath(shard)), data.syncBucketKey))).find(fact => fact.key === positionKey)
  assert.deepEqual(stored.barriers.find(edit => edit.kind === 'delete').version, captured)
  const reread = JSON.stringify({ page: 0, total: 8, date: 500 })
  left.values.get('reading').set(positionKey, reread)
  const staged = left.engine.recordEdits('reading', [{ key: positionKey, kind: 'set', value: reread }])
  assert.ok(staged)
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const gate = new Promise(resolve => { release = resolve })
  const snapshot = left.engine.owner.snapshot.bind(left.engine.owner)
  left.engine.owner.snapshot = async (...args) => { enter(); await gate; return snapshot(...args) }
  const cancelled = assert.rejects(left.engine.syncNow(), /connection_changed|disabled|paused/)
  await entered
  left.engine.setEnabled(false)
  release()
  await cancelled
  assert.equal(left.engine.readingWritePending(staged), true)
  left.engine.setEnabled(true)
  await left.engine.syncNow()
  await right.engine.syncNow()
  assert.equal(right.values.get('reading').get(positionKey), reread)
})

test('pause invalidates an in-flight callback but keeps its intent for enabled recovery', async () => {
  const f = transportFixture()
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A,
    [['reader-settings', new Map([[pageNumber, 'true']])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reader-settings'])).token, [])
  reader.values.get('reader-settings').set(pageNumber, 'false')
  let enter, release
  const entered = new Promise(resolve => { enter = resolve })
  const resumed = new Promise(resolve => { release = resolve })
  f.onCommit(async () => { enter(); await resumed })
  const pending = reader.engine.syncNow()
  const rejected = assert.rejects(pending, /connection_changed|disabled|paused/)
  await entered
  reader.engine.setEnabled(false)
  const name = reader.store.load().intent.commit
  release()
  await rejected
  assert.equal(reader.engine.isEnabled(), false)
  assert.ok(reader.store.load().intent)
  assert.notEqual(reader.store.load().intent.detached, true)
  const requests = f.trace.length
  await reader.engine.recoverOnForeground()
  assert.equal(f.trace.length, requests)
  assert.equal(await reader.engine.testConnection(f.draft, ['reader-settings']), false)
  assert.ok(reader.store.load().intent, 'a synthetic probe must not consume the paused receipt')
  assert.equal(reader.engine.isEnabled(), false)
  f.onCommit(async () => {})
  reader.engine.setAutomatic(true)
  reader.engine.setEnabled(true)
  await reader.engine.recoverOnForeground()
  assert.equal(reader.engine.isEnabled(), true, 'the old intent must preserve the latest service switch')
  assert.equal(reader.engine.active().automatic, true, 'receipt recovery must keep the latest automatic preference')
  assert.equal(reader.store.load().intent, undefined)
  assert.equal(f.files.has(f.root + name), true)
  assert.equal(f.trace.filter(row => row.method === 'PUT' && row.address === f.root + name).length, 1)
})

test('paused runtime keeps Reader clears and bookmarks local until enabled', async () => {
  const f = transportFixture()
  const source = 'org.example.login', work = 'account-work:42'
  const comicId = source + ':' + work
  const recentKey = data.syncKey(['recent', source, work])
  const chapter = 'chapter:42:2'
  const recent = JSON.stringify(data.syncReadingRecent(source, chapter, 123, 'Work', source, 'Chapter', 4))
  const reader = engineFixture(f.DeviceSyncWebDav).replica(A, [['reading', new Map([[recentKey, recent]])]])
  await reader.engine.testConnection(f.draft)
  await reader.engine.confirm((await reader.engine.prepare(f.draft, ['reading'])).token, [])
  const signals = compile('DeviceSyncSignals')
  const runtime = runtimeFixture({ './DeviceSyncSignals': signals,
    '@kit.ArkTS': { util: { generateRandomUUID: require('node:crypto').randomUUID } } })
  runtime.engine = reader.engine
  runtime.storage = reader.store
  runtime.owners = {
    receivedSubscriptions: () => [], readingAcknowledged: () => false,
    readingIdentities: () => new Map([[comicId, { source, work }]]),
    readingActionAcknowledged: capture => !!runtime.owners.readingActionReceipt(capture),
    readingActionReceipt: capture => reader.store.load().readingReceipts?.find(row => row.key === signals.deviceSyncActionCaptureKey(capture)),
  }
  runtime.refresh()
  let fired = false
  runtime.timer = setTimeout(() => { fired = true }, 30)
  runtime.timer.unref()
  runtime.setEnabled(false)
  const scope = reader.engine.readingScope()
  const captures = runtime.stageReaderActions([
    { comicId, chapterId: '', kind: 'clear-history' },
    { comicId, chapterId: chapter, kind: 'bookmark' },
  ])
  assert.equal(captures.length, 2)
  const requests = f.trace.length
  await runtime.recordReaderActions(captures, scope)
  assert.equal(reader.engine.knownReadingValue(recentKey), undefined)
  assert.equal(reader.engine.active().groups[0].pending.length, 2)
  assert.equal(f.trace.length, requests)
  await new Promise(resolve => setTimeout(resolve, 50))
  assert.equal(fired, false)
  runtime.setEnabled(true)
  await reader.engine.syncNow()
  assert.equal(reader.engine.active().groups[0].pending.length, 0)
})

test('disconnect removes this engine probe credentials while pause and another engine keep theirs', async () => {
  const fixture = engineFixture()
  const left = fixture.replica(A), right = fixture.replica(B)
  for (const replica of [left, right]) {
    await replica.engine.testConnection(fixture.draft)
    await replica.engine.confirm((await replica.engine.prepare(fixture.draft, ['reader-settings'])).token, [])
  }
  const leftCredential = left.engine.active().credential
  const rightCredential = right.engine.active().credential
  const leftProbe = '11111111-1111-1111-1111-111111111111'
  const rightProbe = '22222222-2222-2222-2222-222222222222'
  fixture.assets.set(leftProbe, clone(fixture.draft))
  fixture.assets.set(rightProbe, clone(fixture.draft))
  left.store.update(state => { state.probes.push({ credential: leftProbe, id: C, collection: 2 }) })
  right.store.update(state => { state.probes.push({ credential: rightProbe, id: C, collection: 2 }) })
  const before = clone(left.store.load())
  left.engine.setEnabled(false)
  assert.equal(fixture.assets.has(leftCredential), true)
  assert.equal(fixture.assets.has(leftProbe), true)
  await left.engine.disconnect()
  assert.deepEqual(left.store.load().probes, [])
  assert.equal(fixture.assets.has(leftCredential), false)
  assert.equal(fixture.assets.has(leftProbe), false)
  assert.equal(left.store.load().replica, before.replica)
  assert.equal(left.store.load().counter, before.counter)
  assert.equal(fixture.assets.has(rightCredential), true)
  assert.equal(fixture.assets.has(rightProbe), true)
  assert.equal(right.store.load().probes.length, 1)
  assert.equal(right.engine.isEnabled(), true)
})
