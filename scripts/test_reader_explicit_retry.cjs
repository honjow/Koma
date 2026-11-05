const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function methods(file, owner, names, globals = {}) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.getText(tree) === owner)
  assert.ok(cls)
  const members = names.map(name => {
    const member = cls.members.find(n => n.name?.getText(tree) === name)
    assert.ok(member, name)
    return member.getText(tree)
  })
  const exports = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject { ${members.join('\n')} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, Map, console, ...globals })
  return exports.Subject
}
const Cache = methods('model/RemoteImageCacheStore.ets', 'RemoteImageCacheStore', ['getOrFetch'], {
  cacheKeyFor: (url, _headers, seed) => seed || url,
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
    open: async (...args) => open(...args), write: async (...args) => write(...args), close: async file => close(file),
    rename: async (...args) => {
      if (denyRename) throw new Error('storage unavailable')
      renames++
      return fs.promises.rename(...args)
    },
  }
  const exports = {}
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/RemoteImageCacheStore.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, {
    exports, require: name => ({ '@kit.CoreFileKit': { fileIo: io }, '@kit.ArkTS': { buffer: Buffer } })[name],
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
