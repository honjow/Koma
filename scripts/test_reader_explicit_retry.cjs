const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function methods(file, owner, names, globals = {}, declarations = []) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.getText(tree) === owner)
  assert.ok(cls)
  const members = names.map(name => {
    const member = cls.members.find(n => n.name?.getText(tree) === name)
    assert.ok(member, name)
    return member.getText(tree)
  })
  const dependencies = declarations.map(name => {
    const declaration = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.getText(tree) === name)
    assert.ok(declaration, name)
    return declaration.getText(tree)
  }).join('\n')
  const exports = {}
  vm.runInNewContext(ts.transpileModule(`${dependencies}\nexport class Subject { ${members.join('\n')} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, Map, console, ...globals })
  return exports.Subject
}
const Cache = methods('model/RemoteImageCacheStore.ets', 'RemoteImageCacheStore', ['getOrFetch'], {
  cacheKeyFor: (url, _headers, seed) => seed || url,
}, ['RemoteImageFileRequest'])

test('a downloaded page reuses a plugin timeout until explicit retry or a new configuration', async () => {
  let pluginAttempts = 0
  let timedOut = true
  const files = new Map()
  const state = { processingFailures: {} }
  const output = {}
  const imports = {
    '@kit.ArkTS': { taskpool: { execute: async task => {
      if (task.name === 'imageFileContentHash') return 'downloaded-image'
      pluginAttempts++
      return timedOut ? { bytes: new ArrayBuffer(0), extension: '', timedOut: true }
        : { bytes: new Uint8Array([1]).buffer, extension: 'png' }
    } } },
    './ImageFileContent': { imageFileContentHash: function imageFileContentHash() {} },
    '../state/ImageRuleState': { connectImageRuleState: () => state },
  }
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/ImagePluginService.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(source.replace(/^@Concurrent\s*$/gm, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: output, require: name => imports[name] ?? {}, console: { info() {}, warn() {} } })
  const service = output.ImagePluginService
  const cache = {
    get: async (_name, _headers, key) => files.get(key),
    put: async (_name, _headers, _bytes, key) => {
      files.set(key, '/cache/processed.png')
      return '/cache/processed.png'
    },
  }
  const plan = { key: 'plugin', plugin: { processor: { abi: 'test', sha256: 'test' } }, configuration: { mode: 'initial' } }
  const page = '/download/page.png'
  assert.equal(await service.prepare(page, [plan], cache, true), page)
  assert.equal(await service.prepare(page, [plan], cache, true), page)
  assert.equal(pluginAttempts, 1)
  assert.equal(files.size, 0, 'A timeout must not become a persistent no-hit')
  assert.equal(state.processingFailures.plugin, 'processing_failed')
  await service.prepare(page, [{ ...plan, configuration: { mode: 'changed' } }], cache, true)
  assert.equal(pluginAttempts, 2)
  timedOut = false
  assert.equal(await service.prepare(page, [plan], cache, false), '/cache/processed.png')
  assert.equal(await service.prepare(page, [plan], cache, true), '/cache/processed.png')
  assert.equal(pluginAttempts, 3)
})

test('the source reader opens a complete local chapter before asking the provider for its page list', async () => {
  const statuses = { DOWNLOADED: 'downloaded', PARTIAL: 'partial', CORRUPT: 'corrupt', MISSING: 'missing' }
  const configExports = {}
  const configSource = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/readerLab/KomaReaderLabOfflineConfig.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(configSource, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, {
    exports: configExports,
    require: name => ({
      '../model/ReaderSessionStore': { cloneReaderSessionConfig: structuredClone },
      '../model/OfflineDownloadStore': { OfflineDownloadedChapterStatus: statuses },
      '../model/ReaderPageSourceAdapter': { createReaderOfflineMissingUri: (_work, _chapter, index) => `missing:${index}` },
    })[name],
  })
  const request = { comicId: 'source:work', chapterId: '10', chapterIds: ['9', '10', '11'] }
  let providerCalls = 0
  const subject = new (methods('pages/Index.ets', 'Index', ['prepareSourceReaderSession'], {
    OfflineDownloadedChapterStatus: statuses,
    createKomaReaderLabOfflineConfig: configExports.createKomaReaderLabOfflineConfig,
    cloneSourceReaderSessionRequest: structuredClone,
    DiagnosticLogger: { info() {} },
    appDeviceSync: { validateReadingPages: () => true },
    resolveSourceChapterPages: async () => {
      providerCalls++
      return { pages: [{ id: 'online-unit', uri: 'https://example.invalid/page' }] }
    },
  }))()
  Object.assign(subject, {
    readerOpen: true, readerClosing: false, readerOpenEpoch: 1, readerOpenIntent: 'resume',
    activeSourceReaderRequest: request, readerPageRequestCurrent: epoch => epoch === 1,
    createSourceReaderSessionConfig: (source, pages) => ({
      comicId: source.comicId, chapterId: source.chapterId, chapterIds: source.chapterIds,
      continuationChapterIds: ['9', '10', '11'], readingFormat: 'strip',
      totalPages: pages.length, pageUris: pages.map(page => page.uri), pageIds: pages.map(page => page.id),
    }),
    readReaderPagesWithVerification: (_source, read) => read(),
    readerSessionStore: { openPageIndex: config => config.pageIds.indexOf('page-2') },
    saveSourceReaderHistory() {},
  })
  const pages = [
    { pageIndex: 1, pageId: 'page-2', localPath: '/offline/2', requiredImageDecodeResolved: true },
    { pageIndex: 0, pageId: 'page-1', localPath: '/offline/1', imageProcessingResolved: true },
  ]
  await subject.prepareSourceReaderSession(request, 1, Promise.resolve({
    comicId: request.comicId, chapterId: request.chapterId, status: statuses.DOWNLOADED,
    pageCount: 2, availablePageCount: 2, manifest: { pages },
  }))
  assert.equal(providerCalls, 0)
  assert.deepEqual(Array.from(subject.readerSessionConfig.pageUris), ['/offline/1', '/offline/2'])
  assert.equal(subject.readerSessionConfig.offlinePages[1].requiredImageDecodeResolved, true)
  assert.deepEqual(subject.readerSessionConfig.continuationChapterIds, ['9', '10', '11'])
  assert.equal(subject.readerSessionConfig.readingFormat, 'strip')
  assert.equal(subject.readerPageIndex, 1)
  for (const status of [statuses.PARTIAL, statuses.CORRUPT, statuses.MISSING]) {
    await subject.prepareSourceReaderSession(request, 1, Promise.resolve({
      comicId: request.comicId, chapterId: request.chapterId, status, pageCount: 2,
      availablePageCount: 1, manifest: { pages },
    }))
    assert.equal(subject.readerSessionConfig.pageUris[0], 'https://example.invalid/page')
  }
  assert.equal(providerCalls, 3)
})

function cacheFixture() {
  const cache = new Cache(), writes = []
  Object.assign(cache, { imageRequests: new Map(), reloadRequests: new Map(),
    get: async () => '/cache/existing.jpg', put: async (_url, _headers, bytes) => {
      writes.push(bytes); return '/cache/replacement.jpg'
    } })
  return { cache, writes }
}

test('reader cache hits update live eviction and coalesce restart metadata without reviving cleared files', async () => {
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'koma-reader-access-'))
  const writes = new Map()
  let timer = 0, now = 1000, renames = 0, denyRename = false
  const open = (file, mode) => ({ fd: fs.openSync(file, mode ? 'w' : 'r') })
  const write = (fd, bytes) => fs.writeSync(fd, typeof bytes === 'string' ? bytes : new Uint8Array(bytes))
  const close = file => fs.closeSync(file.fd)
  const io = {
    accessSync: fs.existsSync, mkdirSync: (file, recursive) => fs.mkdirSync(file, { recursive }),
    OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 }, openSync: open, writeSync: write, closeSync: close,
    statSync: fs.statSync, renameSync: fs.renameSync, unlinkSync: fs.unlinkSync,
    readTextSync: file => fs.readFileSync(file, 'utf8'), listFile: fs.promises.readdir, unlink: fs.promises.unlink,
    access: async file => fs.existsSync(file), stat: fs.promises.stat,
    open: async (...args) => open(...args), write: async (...args) => write(...args), close: async file => close(file),
    rename: async (...args) => {
      if (denyRename) throw new Error('storage unavailable')
      if (args[0].endsWith('.access.tmp')) renames++
      return fs.promises.rename(...args)
    },
  }
  class Task {
    constructor(work, ...args) { this.run = () => work(...args) }
    setCloneList() {}
  }
  const exports = {}
  const imports = { '@kit.CoreFileKit': { fileIo: io }, '@kit.ArkTS': { buffer: Buffer,
    taskpool: { Task, execute: async (work, ...args) => typeof work === 'function' ? work(...args) : work.run() } } }
  const imageFileContent = {}
  const imageSource = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/ImageFileContent.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(imageSource.replace(/^@Concurrent\s*$/gm, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: imageFileContent, require: name => imports[name] })
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/RemoteImageCacheStore.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, {
    exports, require: name => name === './ImageFileContent' ? imageFileContent : imports[name],
    Date: { now: () => now }, console: { info() {} },
    setTimeout: callback => { writes.set(++timer, callback); return timer }, clearTimeout: id => writes.delete(id),
  })
  const cache = new exports.RemoteImageCacheStore(directory)
  const manifest = path.join(directory, 'reader-remote-image-cache', 'manifest.v1.json')
  const disk = () => JSON.parse(fs.readFileSync(manifest, 'utf8')).entries
  const bytes = new Uint8Array([1, 2, 3]).buffer
  const a = 'https://cache.invalid/a.jpg', b = 'https://cache.invalid/b.jpg', c = 'https://cache.invalid/c.jpg'
  const flush = async () => {
    const callbacks = [...writes.values()]
    writes.clear()
    callbacks.forEach(callback => callback())
    await cache.stats()
  }
  try {
    const first = await cache.put(a, undefined, bytes)
    now++; const oldest = await cache.put(b, undefined, bytes)
    now++; await cache.put(c, undefined, bytes)
    now++; assert.equal(await cache.get(a), first)
    now++; assert.equal(await cache.get(a), first)
    assert.equal(disk().find(e => e.url === a).lastAccessAt, 1000)
    assert.equal(writes.size, 1)
    await cache.evictIfOver(6)
    assert(fs.existsSync(first), 'a touched file is protected by the live LRU before any delayed write')
    assert(!fs.existsSync(oldest))
    assert.equal(disk().find(e => e.url === a).lastAccessAt, now)
    assert.equal(writes.size, 0)

    now++; denyRename = true
    assert.equal(await cache.get(a), first)
    await flush()
    assert.equal(disk().find(e => e.url === a).lastAccessAt, now - 1)
    denyRename = false
    now++; assert.equal(await cache.get(a), first)
    await flush()
    assert.equal(renames, 1)
    assert.equal(disk().find(e => e.url === a).lastAccessAt, now)

    now++; await cache.get(a)
    const late = [...writes.values()][0]
    await cache.clear()
    late()
    await cache.stats()
    assert(!fs.existsSync(manifest), 'a late access checkpoint cannot recreate a cleared manifest')
  } finally {
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('force retry bypasses an existing file and publishes only a complete replacement', async () => {
  const { cache, writes } = cacheFixture(); let fetched = 0
  const fetch = async () => { fetched++; return new Uint8Array([1, 2, 3]).buffer }
  assert.equal(await cache.getOrFetch('url', undefined, fetch), '/cache/existing.jpg')
  assert.equal(fetched, 0)
  assert.equal(await cache.getOrFetch('url', undefined, fetch, undefined, true), '/cache/replacement.jpg')
  assert.equal(fetched, 1); assert.equal(writes.length, 1)
  assert.equal(cache.imageRequests.size, 0); assert.equal(cache.reloadRequests.size, 0)
})
test('failed forced fetch keeps the old file and does not poison the next retry', async () => {
  const { cache, writes } = cacheFixture()
  await assert.rejects(cache.getOrFetch('url', undefined, async () => { throw Error('network failure') }, undefined, true), /network failure/)
  assert.equal(writes.length, 0)
  assert.equal(cache.imageRequests.size, 0); assert.equal(cache.reloadRequests.size, 0)
  assert.equal(await cache.getOrFetch('url', undefined, async () => new ArrayBuffer(2), undefined, true), '/cache/replacement.jpg')
})
test('a forced refresh retires an older publisher and all new consumers join the replacement', async () => {
  const { cache, writes } = cacheFixture(); let finishOld, finishNew, freshCalls = 0
  cache.get = async () => undefined
  const old = cache.getOrFetch('url', undefined, () => new Promise(resolve => { finishOld = resolve }))
  await new Promise(setImmediate)
  const fresh = cache.getOrFetch('url', undefined, () => { freshCalls++; return new Promise(resolve => { finishNew = resolve }) }, undefined, true)
  const duplicate = cache.getOrFetch('url', undefined, () => { throw Error('duplicate fetch') }, undefined, true)
  const ordinary = cache.getOrFetch('url', undefined, () => { throw Error('stale join') })
  assert.equal(fresh, duplicate); assert.equal(fresh, ordinary); assert.equal(freshCalls, 0)
  finishOld('old'); await old; await new Promise(setImmediate)
  finishNew('fresh'); await fresh
  assert.deepEqual(writes, ['old', 'fresh']); assert.equal(freshCalls, 1)
})

test('foreground joins the preload byte count before the cache publishes a file', async () => {
  const { cache, writes } = cacheFixture()
  cache.get = async () => undefined
  let report, finish
  const preload = cache.getOrFetch('url', undefined, publish => {
    report = publish
    return new Promise(resolve => { finish = resolve })
  })
  await new Promise(setImmediate)
  report(12, 80)
  const received = []
  const foreground = cache.getOrFetch('url', undefined, () => { throw Error('duplicate download') },
    undefined, false, (loaded, total) => { received.push([loaded, total]) })
  assert.deepEqual(received, [[12, 80]])
  report(48, 80)
  assert.deepEqual(received, [[12, 80], [48, 80]])
  assert.equal(writes.length, 0)
  finish(new ArrayBuffer(80))
  assert.equal(await foreground, await preload)
  assert.equal(writes.length, 1)
  report(80, 80)
  assert.deepEqual(received, [[12, 80], [48, 80]])
})

test('image streaming reports early body bytes even when the platform progress event skips them', async () => {
  let now = 1000
  let timerId = 0
  const timers = new Map()
  const advance = ms => {
    now += ms
    for (const [id, [due, callback]] of timers) {
      if (due > now) continue
      timers.delete(id)
      callback()
    }
  }
  const file = 'model/ReaderPageSourceAdapter.ets'
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const names = new Set(['readerImageResponseLength', 'observeReaderImageProgress', 'requestReaderImageStream'])
  const declarations = tree.statements.filter(node => names.has(node.name?.getText(tree)) ||
    (ts.isVariableStatement(node) && node.declarationList.declarations.some(declaration =>
      ['READER_IMAGE_PROGRESS_INTERVAL_MS', 'READER_PAGE_IMAGE_BUFFER_BYTES'].includes(declaration.name.getText(tree)))))
  const exports = {}
  vm.runInNewContext(ts.transpileModule(declarations.map(node => node.getText(tree)).join('\n') +
    '\nexport { readerImageResponseLength, observeReaderImageProgress, requestReaderImageStream }', {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, Date: { now: () => now },
    setTimeout: (callback, delay) => { timers.set(++timerId, [now + delay, callback]); return timerId },
    clearTimeout: id => timers.delete(id) })

  for (const encoded of [false, true]) {
    const length = exports.readerImageResponseLength({ 'Content-Length': '200', ...(encoded && { 'Content-Encoding': 'gzip' }) })
    const events = new Map(), reports = []
    const progress = exports.observeReaderImageProgress((loaded, total) => reports.push([loaded, total]))
    const request = {
      on: (name, callback) => events.set(name, callback),
      requestInStream: () => Promise.resolve(200),
    }
    const result = exports.requestReaderImageStream(request, 'https://images.invalid/page', {}, () => {},
      progress.report, () => length.stream)
    const chunk = count => events.get('dataReceive')(new ArrayBuffer(count))
    const platform = (receiveSize, totalSize) => events.get('dataReceiveProgress')({ receiveSize, totalSize })
    if (length.stream > 0) progress.report(0, length.stream)
    chunk(12)
    now += 25
    chunk(24)
    now += 28
    chunk(36)
    platform(80, 200)
    chunk(128)
    platform(200, 200)
    events.get('dataEnd')()
    assert.equal((await result).bytes.byteLength, 200)
    assert.deepEqual(reports, encoded ? [[80, 200]] : [[0, 200], [12, 200], [72, 200]])
    progress.complete()
    progress.close()
    advance(50)
    assert.deepEqual(reports.at(-1), [200, 200])
  }

  const updates = []
  const request = exports.observeReaderImageProgress((loaded, total) => updates.push([loaded, total]))
  request.report(0, 200)
  request.report(30, 200)
  advance(10)
  request.report(100, 200)
  request.report(120, 200)
  advance(39)
  assert.deepEqual(updates, [[0, 200], [30, 200]])
  advance(1)
  assert.deepEqual(updates.at(-1), [120, 200])
  request.report(180, 200)
  request.reset()
  request.report(200, 200)
  request.complete()
  request.close()
  advance(50)
  assert.deepEqual(updates, [[0, 200], [30, 200], [120, 200], [0, 200]])
  assert.equal(timers.size, 0)

  const singleChunk = []
  const fastRequest = exports.observeReaderImageProgress((loaded, total) => singleChunk.push([loaded, total]))
  fastRequest.report(0, 200)
  fastRequest.report(200, 200)
  fastRequest.complete()
  fastRequest.close()
  assert.deepEqual(singleChunk, [[0, 200], [200, 200]])
})

test('a measured download skips its own file probe while joined readers and cache hits still get dimensions', async () => {
  const file = 'model/ReaderPageSourceAdapter.ets'
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const method = tree.statements.find(node => node.name?.getText(tree) === 'fetchReaderRemoteFile')
  const exports = {}, probes = []
  vm.runInNewContext(ts.transpileModule(method.getText(tree) + '\nexport { fetchReaderRemoteFile }', {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, maintainReaderImageCacheAfterWrite: async () => {},
    probeReaderImageFileSize: async (path, report) => { probes.push(path); report(1200, 937) } })
  const { cache } = cacheFixture()
  const fetch = exports.fetchReaderRemoteFile
  const measurements = []
  const report = label => (width, height) => measurements.push([label, width, height])
  const unexpectedDownload = () => { throw new Error('an existing request must be reused') }
  await fetch(cache, 'hit', undefined, unexpectedDownload, undefined, false, report('hit'))
  cache.get = async () => undefined
  let finish
  const own = fetch(cache, 'shared', undefined, (_progress, measured) => new Promise(resolve => {
    finish = () => { report('download')(1200, 937); measured(); resolve(new ArrayBuffer(4)) }
  }), undefined, false, report('duplicate'))
  await new Promise(setImmediate)
  const join = fetch(cache, 'shared', undefined, unexpectedDownload, undefined, false, report('join'))
  finish()
  await Promise.all([own, join])
  await fetch(cache, 'unknown', undefined, async () => new ArrayBuffer(4), undefined, false, report('fallback'))
  assert.deepEqual(measurements, [['hit', 1200, 937], ['download', 1200, 937], ['join', 1200, 937], ['fallback', 1200, 937]])
  assert.deepEqual(probes, ['/cache/existing.jpg', '/cache/replacement.jpg', '/cache/replacement.jpg'])
})

const Index = methods('pages/Index.ets', 'Index', ['prepareReaderLabCatalog'], {
  ComicSourceKind: { LOCAL_FOLDER: 'folder' }, KomaReaderFailure: { sourceError: () => Error('source failure') },
})
const cancel = { check() {} }
const target = { scope: 'koma-local', work: 'book', unit: 'chapter' }
function shelfFixture(ok = true) {
  const index = new Index(), calls = [], book = { id: 'book', sourceKind: 'source' }
  Object.assign(index, { readerComicForOpen: () => book, hasAvailableOfflineReaderPages: () => false,
    ensureReaderSourceChapterPages: async (_book, _chapter, _failure, force) => { calls.push(force); return ok },
    createReaderSessionConfigForOpen: () => ({ totalPages: 24 }), chapterNeedsReaderSourcePages: () => false })
  return { index, calls }
}
test('ordinary shelf opening keeps cache-first and explicit retry reaches the hydrator with force', async () => {
  const { index, calls } = shelfFixture()
  assert.equal((await index.prepareReaderLabCatalog(target, cancel)).totalPages, 24)
  assert.equal((await index.prepareReaderLabCatalog(target, cancel, true)).totalPages, 24)
  assert.deepEqual(calls, [false, true])
})
test('explicit source-plan failure cannot be reported as success from previously saved pages', async () => {
  const { index } = shelfFixture(false)
  await assert.rejects(index.prepareReaderLabCatalog(target, cancel, true), /source failure/)
})
test('available offline chapters bypass provider refresh even on explicit retry', async () => {
  const { index, calls } = shelfFixture()
  index.hasAvailableOfflineReaderPages = () => true
  assert.equal((await index.prepareReaderLabCatalog(target, cancel, true)).totalPages, 24)
  assert.deepEqual(calls, [])
})

test('a deferred-page failure leaves body reading available and its explicit retry never refreshes the chapter', async () => {
  const kinds = { LOCAL_FILE_IMAGE: 'local', REMOTE_URL_IMAGE: 'remote', URI_PLACEHOLDER: 'missing', SOURCE_TEXT_REQUEST: 'deferred' }
  const Reader = methods('readerLab/KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter', ['load', 'preload'], {
    ReaderPageRenderKind: kinds, ReaderAsset: class { constructor(uri) { this.uri = uri } },
    KomaReaderFileInformation: class {}, KomaReaderCropSource: class {},
  })
  const reader = new Reader(), calls = []
  const sources = [{ kind: kinds.REMOTE_URL_IMAGE, uri: 'https://images.example/body.jpg', imageUri: 'https://images.example/body.jpg' },
    { kind: kinds.SOURCE_TEXT_REQUEST, uri: 'chapter-comments:1/2', imageUri: '' }]
  let noteFails = true
  Object.assign(reader, { closed: false, sources: new Map([['unit', sources]]), unitId: () => 'unit',
    refreshPageSources: async () => { throw Error('unrelated chapter refresh') },
    sourceFile: async (_unit, index, force = false) => {
      calls.push([index, force]); if (index === 1 && noteFails) throw Error('comment API failure')
      return index === 0 ? '/cache/body.jpg' : '/cache/comments.png'
    } })
  const page = index => ({ unit: target, sourceIndex: index, key: index === 0 ? 'body' : 'chapter-comments:1/2' })
  await assert.rejects(reader.load(page(1), 'original', cancel, false), /comment API failure/)
  assert.equal((await reader.load(page(0), 'original', cancel, false)).uri, 'file:///cache/body.jpg')
  noteFails = false
  assert.equal((await reader.load(page(1), 'original', cancel, true)).uri, 'file:///cache/comments.png')
  await reader.preload(page(1), cancel)
  assert.deepEqual(calls, [[1, false], [0, false], [1, true], [1, false]])
})

test('an automatic image retry keeps the current page when refreshing its chapter fails over the network', async () => {
  class SourceRuntimeError extends Error {
    diagnostic = { kind: 'network' }
  }
  const kinds = { REMOTE_URL_IMAGE: 'remote', URI_PLACEHOLDER: 'placeholder', SOURCE_TEXT_REQUEST: 'text' }
  const Reader = methods('readerLab/KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter', ['load', 'recoverableImageFailure'], {
    ReaderPageRenderKind: kinds, ReaderProcessingCancellation: class {},
    MAX_AUTOMATIC_PAGE_RETRIES: 3, AUTOMATIC_PAGE_RETRY_DELAY_MS: [300, 600, 1200],
    DiagnosticLogger: { info() {} }, SourceRuntimeError,
    ReaderAsset: class { constructor(uri) { this.uri = uri } }, KomaReaderFileInformation: class {},
    KomaReaderCropSource: class {}, prepareReaderDisplayImage: async file => file,
  })
  const reader = new Reader(), requests = []
  const source = { kind: kinds.REMOTE_URL_IMAGE, sourceRuntimeId: 'online-source', imageUri: 'https://images.example/page.jpg' }
  Object.assign(reader, { closed: false, sources: new Map([['unit', [source]]]),
    unitId: () => 'unit', automaticPageRetries: new Map(), automaticallyRefreshedUnits: new Set(),
    authenticationNotice: () => null, automaticPaging: () => false, delayAutomaticPageRetry: async () => {},
    refreshPageSources: async () => { throw new SourceRuntimeError('catalog transport failed') },
    sourceFile: async (_unit, _index, refresh) => {
      requests.push(refresh)
      if (!refresh) throw new Error('reader_remote_image_fetch_failed_2300018')
      return '/cache/recovered-page.jpg'
    },
  })
  const page = { unit: target, sourceIndex: 0, key: 'page' }
  assert.equal((await reader.load(page, 'original', cancel, false)).uri, 'file:///cache/recovered-page.jpg')
  assert.deepEqual(requests, [false, true])
})

// Load the actual descriptor resolver, with worker/network ports controlled in memory.
function sourceImageRequestSubject(ports) {
  const file = 'model/ReaderPageSourceAdapter.ets'
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const names = new Set(['sourceImageDescriptorAbsence', 'sourceExplicitlyLacksImageRequest', 'unavailableSourceImageDescriptor',
    'SourceImageRequestDescriptor', 'parseSourceImageRequestHeaders', 'parseSourceImageRequestDescriptor',
    'readerImageRequestForPage', 'sourceImageMangaRoute', 'ReaderImageRuntimeArgs',
    'ReaderImageRuntimeHostHints', 'runReaderSourceImageOperation', 'resolveSourceRuntimeImageRequest'])
  const nodes = tree.statements.filter(n => names.has(n.name?.getText(tree)) ||
    (ts.isVariableStatement(n) && n.declarationList.declarations.some(d => names.has(d.name.getText(tree)))))
  const exports = {}
  const hostFeatures = {}
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(__dirname,
    '../entry/src/main/ets/sourceRuntime/SourceHostFeatures.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: hostFeatures })
  vm.runInNewContext(ts.transpileModule(nodes.map(n => n.getText(tree)).join('\n') +
    '\nexport { resolveSourceRuntimeImageRequest };', {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, WeakMap, Uint8Array, console, ...hostFeatures, sourceHttpIdentityJson: () => '{}',
    appSourceSettingsStore: { loadForSource: () => ({}) }, configureSourceRequestPolicy() {},
    DiagnosticLogger: { warn() {} }, executeReaderSourceImageRequestOperation: (...args) => ports.taskpool.execute(undefined, ...args),
    SourceWorkerPriority: { FOREGROUND: 'foreground', BACKGROUND: 'background' },
    diagnoseSourceOperation: (_request, execute) => execute(), ...ports })
  return exports.resolveSourceRuntimeImageRequest
}

test('explicit unsupported metadata skips concurrent descriptor calls and a new package is probed independently', async () => {
  let entry = { enabled: true, capabilities: [], wasmBytes: new Uint8Array([1]) }
  let probes = 0, imageCalls = 0, warnings = 0
  const resolve = sourceImageRequestSubject({
    DiagnosticLogger: { warn() { warnings++ } },
    appSourceRuntimeRegistry: { lookup: () => ({ ok: true, entry }) },
    runSourceOperationFromValidatedBytesAsync: async (request, bytes) => {
      probes++; assert.equal(JSON.parse(request).hostHints.network, false)
      await new Promise(setImmediate)
      return { ok: true, operation: 'source_info', data: { capabilities: { imageRequest: bytes[0] !== 1 } } }
    },
    taskpool: { execute: async (_operation, request) => {
      assert(JSON.parse(request).hostFeatures.includes('mangabz_language_cookie_v1'))
      imageCalls++; return JSON.stringify({ ok: true, data: { url: 'https://images.example/page.jpg', headers: { Referer: 'https://site.example/' } } })
    } },
  })
  const pages = await Promise.all(Array.from({ length: 20 }, (_, i) => resolve('source', 'https://images.example/' + i, 'page-' + i)))
  assert.ok(pages.every(p => p === undefined)); assert.equal(probes, 1); assert.equal(imageCalls, 0); assert.equal(warnings, 0)
  entry = { ...entry, wasmBytes: new Uint8Array([2]) }
  const descriptor = await resolve('source', 'https://images.example/new', 'new-page')
  assert.equal(probes, 2); assert.equal(imageCalls, 1)
  assert.equal(descriptor.headers.Referer, 'https://site.example/')
})

test('unknown and failed metadata preserve legacy attempts; required descriptors keep headers and fail closed', async () => {
  for (const metadata of [undefined, { capabilities: {} }, { capabilities: { imageRequest: 'false' } }, 'failed']) {
    let attempts = 0
    const resolve = sourceImageRequestSubject({
      appSourceRuntimeRegistry: { lookup: () => ({ ok: true, entry: { enabled: true, capabilities: [], wasmBytes: new Uint8Array([1]) } }) },
      runSourceOperationFromValidatedBytesAsync: async () => {
        if (metadata === 'failed') throw Error('worker failed')
        return { ok: true, operation: 'source_info', data: metadata }
      },
      taskpool: { execute: async () => { attempts++; return JSON.stringify({ ok: true, data: { request: { method: 'GET', url: 'https://images.example/ticket', headers: { Referer: 'https://site.example/' } } } }) } },
    })
    assert.equal((await resolve('source', 'https://images.example/page', 'page')).headers.Referer, 'https://site.example/')
    assert.equal(attempts, 1)
  }
  let fail = false, requiredProbes = 0
  const resolve = sourceImageRequestSubject({
    appSourceRuntimeRegistry: { lookup: () => ({ ok: true, entry: { enabled: true, capabilities: ['imageRequest'], wasmBytes: new Uint8Array([1]) } }) },
    runSourceOperationFromValidatedBytesAsync: async () => { requiredProbes++; throw Error('required descriptor must not be probed') },
    taskpool: { execute: async () => {
      if (fail) throw Error('image worker failed')
      return JSON.stringify({ ok: true, data: { url: 'https://images.example/ticket', headers: { Referer: 'https://site.example/' } } })
    } },
  })
  assert.equal((await resolve('source', 'https://images.example/page', 'page')).headers.Referer, 'https://site.example/')
  assert.equal(requiredProbes, 0)
  fail = true
  await assert.rejects(resolve('source', 'https://images.example/page', 'page'), /reader_source_image_request_failed/)
})
