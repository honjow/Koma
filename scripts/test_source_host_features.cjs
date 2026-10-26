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
  const body = names.map(name => tree.statements.find(n => ts.isFunctionDeclaration(n) && n.name?.text === name).getText(tree)).join('\n')
  const js = ts.transpileModule(body, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  return new Function('exports', ...Object.keys(globals), js + ';return {' + names.join(',') + '}')({}, ...Object.values(globals))
}

test('host capability handoff preserves requests and validates plain text without interpreting markup', () => {
  const host = load('sourceRuntime/SourceHostFeatures.ets')
  const request = { operation: 'get_pages', settings: { enabled: true }, args: { chapterId: '123' } }
  const enriched = JSON.parse(host.sourceRequestWithHostFeatures(JSON.stringify(request)))
  assert.deepEqual(enriched.args, request.args)
  assert.deepEqual(enriched.settings, request.settings)
  assert.deepEqual(enriched.hostFeatures, ['text_page_image_v1', 'source_rate_limit_v1'])
  assert.equal(host.sourceRequestWithHostFeatures('{'), '{')
  const { sourceTextPage } = load('model/SourceTextPageDescriptor.ets')
  const spec = { template: 'dm5-chapter-comments', heading: '', paragraphs: ['甲: 中文 & <literal> 😀'] }
  assert.deepEqual(sourceTextPage(spec), spec)
  assert.throws(() => sourceTextPage({ ...spec, template: 'remote-html' }))
  assert.throws(() => sourceTextPage({ ...spec, paragraphs: [123] }))
  assert.throws(() => sourceTextPage({ ...spec, paragraphs: ['x'.repeat(64001)] }))
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
