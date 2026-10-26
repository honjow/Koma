const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function load(relative, imports = {}, globals = {}) {
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(root, relative), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', ...Object.keys(globals), js)(exports, name => imports[name] ?? {}, ...Object.values(globals))
  return exports
}
function functions(relative, names, globals) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8')
  const tree = ts.createSourceFile(relative, source, ts.ScriptTarget.Latest, true)
  const body = names.map(name => tree.statements.find(n => n.name?.text === name).getText(tree)).join('\n')
  const js = ts.transpileModule(body, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  return new Function('exports', ...Object.keys(globals), js + ';return {' + names.join(',') + '}')({}, ...Object.values(globals))
}

function fileCache(directory) {
  const io = { accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
    OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4, READ_ONLY: 0 }, openSync: (p, mode) => ({ fd: fs.openSync(p, mode === 0 ? 'r' : 'w') }),
    closeSync: file => fs.closeSync(file.fd), statSync: fs.statSync, renameSync: fs.renameSync,
    readSync: (fd, bytes) => fs.readSync(fd, new Uint8Array(bytes)),
    writeSync: (fd, bytes) => fs.writeSync(fd, typeof bytes === 'string' ? bytes : new Uint8Array(bytes)),
    unlinkSync: fs.unlinkSync, unlink: p => fs.promises.unlink(p), listFile: p => fs.promises.readdir(p),
    readTextSync: p => fs.readFileSync(p, 'utf8') }
  const { RemoteImageCacheStore } = load('model/RemoteImageCacheStore.ets', { '@kit.CoreFileKit': { fileIo: io } })
  return { io, cache: new RemoteImageCacheStore(directory) }
}

test('host capability handoff preserves requests and validates plain text without interpreting markup', () => {
  const host = load('sourceRuntime/SourceHostFeatures.ets')
  const request = { operation: 'get_pages', settings: { enabled: true }, args: { chapterId: '123' } }
  const enriched = JSON.parse(host.sourceRequestWithHostFeatures(JSON.stringify(request)))
  assert.deepEqual(enriched.args, request.args)
  assert.deepEqual(enriched.settings, request.settings)
  assert.deepEqual(enriched.hostFeatures, ['text_page_image_v1', 'source_rate_limit_v1', 'text_page_image_zaimanhua_comments_v1', 'source_text_page_request_v1'])
  assert.deepEqual(JSON.parse(host.sourceRequestWithHostFeatures(JSON.stringify({ operation: 'get_settings' }))).hostFeatures,
    enriched.hostFeatures)
  assert.equal(host.sourceRequestWithHostFeatures('{'), '{')
  const { sourceTextPage } = load('model/SourceTextPageDescriptor.ets')
  const spec = { template: 'dm5-chapter-comments', heading: '', paragraphs: ['甲: 中文 & <literal> 😀'] }
  assert.deepEqual(sourceTextPage(spec), spec)
  assert.deepEqual(sourceTextPage({ ...spec, template: 'zaimanhua-chapter-comments' }),
    { ...spec, template: 'zaimanhua-chapter-comments' })
  assert.throws(() => sourceTextPage({ ...spec, template: 'remote-html' }))
  assert.throws(() => sourceTextPage({ ...spec, paragraphs: [123] }))
  assert.throws(() => sourceTextPage({ ...spec, paragraphs: ['x'.repeat(64001)] }))
})

test('native worker follows the adopted comment cutoff and minimum height without changing existing templates', async () => {
  // Fixed paragraph metrics exercise layout policy and paint placement, not
  // HarmonyOS glyph shaping or PNG output, which require an installed route.
  let bitmapSize
  let painted
  let released = 0
  const metrics = { '章末吐槽：': [40, 1], heading: [40, 1], small: [30, 1],
    full: [1700, 20], oversized: [2000, 24], single: [100, 1] }
  const paragraph = (value, width, size, bold, notes) => {
    const [height, lines] = metrics[value]
    return { getHeight: () => height, getLineCount: () => lines,
      paint: (_canvas, x, y) => painted.push({ value, x, y, width, size, bold, notes }) }
  }
  const image = { PixelMapFormat: { RGBA_8888: 1 }, AlphaType: { OPAQUE: 1 },
    createPixelMap: async (_buffer, options) => { bitmapSize = options.size; return { release: async () => released++ } },
    createImagePacker: () => ({ packing: async () => new ArrayBuffer(1), release: async () => released++ }) }
  const { renderSourceTextPageWorker } = load('model/SourceTextPageRenderer.ets', {
    '@kit.ImageKit': { image }, '@kit.ArkGraphics2D': { drawing: { Canvas: class { drawColor() {} } } },
    './SourceTextPageLayout': { sourceTextParagraph: paragraph },
  })
  const render = async (template, paragraphs, heading = '') => {
    painted = []; await renderSourceTextPageWorker({ template, heading, paragraphs })
  }
  await render('zaimanhua-chapter-comments', ['small'])
  assert.deepEqual(bitmapSize, { width: 1080, height: 1080 })
  assert.deepEqual(painted, [
    { value: '章末吐槽：', x: 50, y: 25, width: 980, size: 36, bold: true, notes: false },
    { value: 'small', x: 50, y: 95, width: 980, size: 30, bold: false, notes: false },
  ])
  await render('zaimanhua-chapter-comments', ['full', 'oversized', 'small'])
  assert.deepEqual(painted.map(p => p.value), ['章末吐槽：', 'full', 'small'])
  assert.equal(painted[2].y, 1825)
  assert.equal(bitmapSize.height, 1880)
  await render('zaimanhua-chapter-comments', ['full', 'single', 'small'])
  assert.deepEqual(painted.map(p => p.value), ['章末吐槽：', 'full'])
  assert.equal(bitmapSize.height, 1820)
  await render('dm5-chapter-comments', ['oversized', 'small'])
  assert.deepEqual(painted, [])
  assert.deepEqual(bitmapSize, { width: 1080, height: 32 })
  await render('webtoon-author-notes', ['small'], 'heading')
  assert.deepEqual(bitmapSize, { width: 1000, height: 120 })
  assert.deepEqual(painted.map(p => [p.value, p.x, p.y, p.notes]), [['heading', 50, 25, true], ['small', 50, 65, true]])
  assert.equal(released, 10)
})

test('deferred text keeps the body available, retries only its page, and shares prepared files with export', async () => {
  const descriptor = load('model/SourceTextPageDescriptor.ets')
  const feature = load('sourceRuntime/SourceHostFeatures.ets')
  const hydrate = functions('model/SourceChapterPageHydrator.ets', ['optionalSourceString', 'optionalSourceNumber',
    'sourcePageImageRecord', 'sourcePageImageUrl', 'sourcePageDimension', 'sourcePageId', 'pagesFromSourceRows'], {
    ...descriptor, normalizeSourceImageUrl: value => value,
    cacheSourceTextPageImage: async () => { throw Error('get_pages must not render the deferred page') },
  })
  const pages = await hydrate.pagesFromSourceRows('book', 'chapter', [
    { id: 'body', image: { kind: 'url', url: 'https://images.example/body.jpg' } },
    { id: 'chapter-comments:1/2', image: { kind: 'text_request', textRequest: { template: 'zaimanhua-chapter-comments' } } },
  ])
  assert.equal(pages[0].uri, 'https://images.example/body.jpg')
  assert.equal(pages[1].uri, 'chapter-comments:1/2')
  const persistence = functions('model/LibraryPersistence.ets', ['assertPersistedObject', 'assertStringField',
    'assertNumberField', 'assertOptionalNumberField', 'assertValidPersistedPage', 'persistPage', 'hydratePage'], descriptor)
  const restored = persistence.hydratePage(JSON.parse(JSON.stringify(persistence.persistPage(pages[1]))))
  assert.deepEqual(restored.sourceTextRequest, { template: 'zaimanhua-chapter-comments' })
  const session = functions('model/ReaderSessionStore.ets', ['cloneReaderSessionConfig'], descriptor)
  const config = session.cloneReaderSessionConfig({ comicId: 'book', chapterId: 'chapter', chapterIds: ['chapter'],
    totalPages: 2, pageIds: pages.map(p => p.id), pageUris: pages.map(p => p.uri),
    pageTextRequests: [undefined, restored.sourceTextRequest], sourceRuntimeId: 'source' })
  restored.sourceTextRequest.template = 'outside change'
  assert.equal(config.pageTextRequests[1].template, 'zaimanhua-chapter-comments')

  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'koma-deferred-text-'))
  const { cache, io } = fileCache(directory)
  let settings = { COMMENTS: true }, calls = 0, renders = 0, fail = true, changeDuringRequest = false, changeDuringMaintenance = false
  const entry = { sourceId: 'source', enabled: true, manifestVersion: '1', wasmPath: '/installed/1/source.wasm',
    capabilities: ['imageRequest'], wasmBytes: new Uint8Array([1]) }
  const error = load('model/SourceRuntimeError.ets', { '../i18n/AppStrings': { AppStrings: {
    get: () => 'Source failure', format: () => 'Source failure HTTP 503',
  } } })
  const kinds = { LOCAL_FILE_IMAGE: 'local', REMOTE_URL_IMAGE: 'remote', URI_PLACEHOLDER: 'missing', SOURCE_TEXT_REQUEST: 'deferred' }
  const adapter = functions('model/ReaderPageSourceAdapter.ets', ['sourceImageMangaRoute', 'ReaderImageRuntimeArgs',
    'ReaderImageRuntimeHostHints', 'readerImageRequestForPage', 'runReaderSourceImageOperation', 'sourceTextRequestCurrent',
    'fetchAndCacheSourceRuntimeTextPage', 'readerPageIdAt', 'createReaderPageRenderSourceWithOfflinePath',
    'fetchAndCacheReaderRemoteSource', 'fetchReaderRemoteSourceBytes'], {
    ...descriptor, ...feature, ...error, fs: io, ReaderPageRenderKind: kinds, readerImageCacheStore: cache,
    appSourceRuntimeRegistry: { lookup: () => ({ ok: true, entry }) },
    appSourceSettingsStore: { loadForSource: () => ({ ...settings }) }, sourceSettingsFingerprint: JSON.stringify,
    configureSourceRequestPolicy() {}, sourceHttpIdentityJson: () => '{}',
    diagnoseSourceOperation: (_request, execute) => execute(), taskpool: { execute: (fn, ...args) => fn(...args) },
    maintainReaderImageCacheAfterWrite: async () => { if (changeDuringMaintenance) settings = { COMMENTS: false } },
    createReaderOfflineMissingUri: () => 'offline-missing',
    renderSourceTextPage: async spec => { renders++; assert.equal(spec.template, 'zaimanhua-chapter-comments'); return Uint8Array.of(1, 2, 3, 4).buffer },
    executeReaderSourceImageRequestOperation: async request => {
      calls++; const req = JSON.parse(request)
      assert.equal(req.operation, 'get_image_request'); assert.equal(req.args.pageId, 'chapter-comments:1/2')
      assert.equal(req.args.url, ''); assert(req.hostFeatures.includes('source_text_page_request_v1'))
      if (changeDuringRequest) settings = { COMMENTS: false }
      return JSON.stringify(fail ? { ok: false, error: { code: 'http_error', status: 503 } } :
        { ok: true, data: { image: { kind: 'text', text: { template: 'zaimanhua-chapter-comments', paragraphs: ['真实文字'] } } } })
    },
  })
  try {
    const source = adapter.createReaderPageRenderSourceWithOfflinePath(config, 1, '', false)
    assert.equal(source.kind, kinds.SOURCE_TEXT_REQUEST)
    await assert.rejects(adapter.fetchAndCacheReaderRemoteSource(source), e => e instanceof error.SourceRuntimeError && e.diagnostic.status === 503)
    assert.equal(pages[0].uri, 'https://images.example/body.jpg')
    fail = false
    const first = await adapter.fetchAndCacheReaderRemoteSource(source)
    assert(fs.existsSync(first)); assert.equal(calls, 2); assert.equal(renders, 1)
    assert.deepEqual(new Uint8Array(await adapter.fetchReaderRemoteSourceBytes(source)), Uint8Array.of(1, 2, 3, 4))
    assert.equal(calls, 2)
    await adapter.fetchAndCacheReaderRemoteSource(source, undefined, true)
    assert.equal(calls, 3); assert.equal(renders, 2)
    changeDuringRequest = true
    await assert.rejects(adapter.fetchAndCacheReaderRemoteSource(source, undefined, true), /source_text_request_stale/)
    assert.equal(renders, 2)
    changeDuringRequest = false; settings = { COMMENTS: true }; changeDuringMaintenance = true
    await assert.rejects(adapter.fetchAndCacheReaderRemoteSource(source), /source_text_request_stale/)
    assert.equal(adapter.createReaderPageRenderSourceWithOfflinePath(config, 1, '', true).kind, kinds.URI_PLACEHOLDER)
    assert.equal(adapter.createReaderPageRenderSourceWithOfflinePath(config, 1, first, true).kind, kinds.LOCAL_FILE_IMAGE)
  } finally { fs.rmSync(directory, { recursive: true, force: true }) }
})

test('actual sliding windows share the CDN quota, isolate main-site quota and release cancelled waiters', async () => {
  let now = 0
  const timers = []
  const policy = load('sourceRuntime/SourceRequestPolicy.ets', { '@kit.ArkTS': { url: { URL } } }, {
    Date: { now: () => now }, setTimeout: (fn, delay) => { timers.push({ fn, due: now + delay }) },
  })
  const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve() }
  const advance = async time => {
    now = time
    for (const timer of timers.splice(0)) {
      if (timer.due <= now) timer.fn()
      else timers.push(timer)
    }
    await flush()
  }
  const id = 'com.manhuagui.koma'
  policy.configureSourceRequestPolicy(id, { mainSiteRatelimitPreference: '1', imgCDNRatelimitPreference: '1' })
  const starts = []
  await policy.waitForSourceRequestSlot(id, 'https://i.hamreus.com/a')
  const image = policy.waitForSourceRequestSlot(id, 'https://cf.hamreus.com/b').then(() => starts.push(['cdn', now]))
  await policy.waitForSourceRequestSlot(id, 'https://www.manhuagui.com/a')
  const main = policy.waitForSourceRequestSlot(id, 'https://www.manhuagui.com/b').then(() => starts.push(['main', now]))
  await flush()
  assert.deepEqual(starts, [])
  await advance(1000); await image
  assert.deepEqual(starts, [['cdn', 1000]])
  let current = true
  const cancelled = policy.waitForSourceRequestSlot(id, 'https://cf.hamreus.com/c', () => current)
  const rejected = assert.rejects(cancelled, /source_request_cancelled/)
  await flush(); current = false
  const next = policy.waitForSourceRequestSlot(id, 'https://i.hamreus.com/d')
  await advance(2000); await rejected; await next
  await policy.waitForSourceRequestSlot('other.source', 'https://i.hamreus.com/e')
  await policy.waitForSourceRequestSlot(id, 'https://unrelated.example/a')
  await advance(10000); await main
  assert.deepEqual(starts, [['cdn', 1000], ['main', 10000]])
})

test('source text survives persistence and session cloning, then rebuilds through the real image cache after cleanup', async () => {
  const { sourceTextPage } = load('model/SourceTextPageDescriptor.ets')
  const persistence = functions('model/LibraryPersistence.ets', ['assertPersistedObject', 'assertStringField',
    'assertNumberField', 'assertOptionalNumberField', 'assertOptionalStringField', 'assertValidPersistedPage',
    'assertValidPersistedChapter', 'persistPage', 'hydratePage', 'persistChapter', 'hydrateChapter'], { sourceTextPage })
  const spec = { template: 'dm5-chapter-comments', heading: '', paragraphs: ['甲: 原始评论 😀'] }
  const page = { id: 'text-page', comicId: 'comic', chapterId: 'chapter', index: 0,
    uri: '/cache/old.png', fileName: 'text.png', sortKey: '0', sourceText: spec }
  const restored = persistence.hydratePage(JSON.parse(JSON.stringify(persistence.persistPage(page))))
  const chapter = { id: 'chapter', comicId: 'comic', title: 'Chapter', index: 0, sourcePath: 'source:chapter',
    sortKey: '0', pages: [restored], pageCount: 1, createdAt: 1, updatedAt: 1, sourceSettingsFingerprint: 'a'.repeat(64) }
  const cold = persistence.hydrateChapter(JSON.parse(JSON.stringify(persistence.persistChapter(chapter))))
  assert.equal(cold.sourceSettingsFingerprint, chapter.sourceSettingsFingerprint)
  delete chapter.sourceSettingsFingerprint
  assert.equal(persistence.hydrateChapter(JSON.parse(JSON.stringify(persistence.persistChapter(chapter)))).sourceSettingsFingerprint, undefined)
  const session = functions('model/ReaderSessionStore.ets', ['createReaderSessionConfigFromComic', 'cloneReaderSessionConfig'], {
    sourceTextPage, continuationChapterIds: chapters => chapters.map(c => c.id), readerChapterDisplayTitle: chapter => chapter.title,
  })
  const config = session.cloneReaderSessionConfig(session.createReaderSessionConfigFromComic({ id: 'comic', title: 'Comic',
    chapters: [{ id: 'chapter', title: 'Chapter', pageCount: 1, pages: [restored] }] }, 'chapter'))
  assert.deepEqual(config.pageTextPages[0], spec)
  spec.paragraphs[0] = 'Changed outside the prepared session'
  assert.equal(config.pageTextPages[0].paragraphs[0], '甲: 原始评论 😀')
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'koma-text-cache-'))
  const io = { accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
    OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 }, openSync: p => ({ fd: fs.openSync(p, 'w') }),
    closeSync: file => fs.closeSync(file.fd), statSync: fs.statSync, renameSync: fs.renameSync,
    writeSync: (fd, bytes) => fs.writeSync(fd, typeof bytes === 'string' ? bytes : new Uint8Array(bytes)),
    unlinkSync: fs.unlinkSync, unlink: p => fs.promises.unlink(p), listFile: p => fs.promises.readdir(p),
    readTextSync: p => fs.readFileSync(p, 'utf8') }
  try {
    const { RemoteImageCacheStore } = load('model/RemoteImageCacheStore.ets', { '@kit.CoreFileKit': { fileIo: io } })
    const cache = new RemoteImageCacheStore(directory)
    let renders = 0
    const adapter = functions('model/ReaderPageSourceAdapter.ets', ['isLocalFileUri', 'isRemoteHttpUrl', 'readerPageIdAt',
      'createReaderPageRenderSourceWithOfflinePath', 'cacheSourceTextPageImage', 'fetchAndCacheReaderRemoteSource'], {
      ReaderPageRenderKind: { LOCAL_FILE_IMAGE: 'local', URI_PLACEHOLDER: 'placeholder' }, readerImageCacheStore: cache,
      maintainReaderImageCacheAfterWrite: async () => {},
      // Native glyph/PNG output is verified on 237; this test observes cache ownership and regeneration only.
      renderSourceTextPage: async () => { renders++; return Uint8Array.of(1, 2, 3, 4).buffer },
    })
    const source = adapter.createReaderPageRenderSourceWithOfflinePath(config, 0, '', false)
    const first = await adapter.fetchAndCacheReaderRemoteSource(source)
    assert(fs.existsSync(first)); assert.equal(renders, 1)
    assert.equal(await adapter.fetchAndCacheReaderRemoteSource(source), first); assert.equal(renders, 1)
    await adapter.fetchAndCacheReaderRemoteSource(source, undefined, true)
    assert.equal(renders, 2)
    await cache.clear(); assert.equal(fs.existsSync(first), false)
    const rebuilt = await adapter.fetchAndCacheReaderRemoteSource(source)
    assert(fs.existsSync(rebuilt)); assert.equal(renders, 3)
  } finally { fs.rmSync(directory, { recursive: true, force: true }) }
})
