const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const text = fs.readFileSync('entry/src/main/ets/model/SourceTextOverlay.ets', 'utf8')
const js = ts.transpileModule(text, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
const actual = {}
vm.runInNewContext(js, { exports: actual, Object, Array, Number, Error })
const input = { version: 1, balloons: [{ text: '中文 A', x: 1.25, y: 3, width: 4 }] }
const clone = actual.sourceTextOverlay(input)
assert.equal(JSON.stringify(clone), JSON.stringify(input))
input.balloons[0].text = 'changed'
assert.equal(clone.balloons[0].text, '中文 A')
for (const value of [{ version: 2, balloons: [] }, { version: 1, balloons: [] },
  { version: 1, balloons: [{ text: 'x', x: NaN, y: 0, width: 1 }] },
  { version: 1, balloons: [{ text: 'x', x: 0, y: 0, width: 0 }] },
  { version: 1, balloons: [{ text: 'x'.repeat(4096), x: 0, y: 0, width: 1 }] }]) {
  assert.throws(() => actual.sourceTextOverlay(value), /source_text_overlay_invalid/)
}
console.log('source text overlay validation and independent copy passed')

// Execute the real download-manifest owner with an isolated temporary file.
const os = require('node:os'), path = require('node:path')
const base = 'entry/src/main/ets/model/'
const clean = value => value.replace(/import[\s\S]*?from '[^']+'\n/g, '')
function load(source, deps) {
  const out = {}
  new Function('exports', ...Object.keys(deps), ts.transpileModule(clean(source), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText)(out, ...Object.values(deps))
  return out
}
const io = { accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
  openSync: (p,m) => ({ fd: fs.openSync(p,m ? 'w' : 'r') }), closeSync: f => fs.closeSync(f.fd),
  writeSync: (fd,v) => fs.writeSync(fd, typeof v === 'string' ? v : Buffer.from(v)),
  readTextSync: p => fs.readFileSync(p,'utf8'), fsyncSync: fs.fsyncSync, renameSync: fs.renameSync,
  unlinkSync: fs.unlinkSync, statSync: p => typeof p === 'number' ? fs.fstatSync(p) : fs.statSync(p),
  listFileSync: p => fs.readdirSync(p), readSync: (fd,b) => fs.readSync(fd,Buffer.from(b),0,b.byteLength,null) }
const models = load(fs.readFileSync(base+'ComicModels.ets','utf8'), {})
const persistence = load(fs.readFileSync(base+'AppFileTextPersistence.ets','utf8'), { fs: io })
const directoryIndex = load(fs.readFileSync(base+'DownloadDirectoryIndex.ets','utf8'), { fs: io, ...persistence })
const offline = load(fs.readFileSync(base+'OfflineDownloadStore.ets','utf8'),
  { fs: io, ComicSourceKind: models.ComicSourceKind, sourceTextOverlay: actual.sourceTextOverlay,
    ...directoryIndex, ...persistence })
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-overlay-'))
try {
  const store = new offline.OfflineDownloadStore(tmp)
  let manifest = store.createManifest('book','chapter',1,'queued',
    { sourceKind: models.ComicSourceKind.PRIVATE_LIBRARY, sourceId:'dbm', seriesId:'book' })
  const target = store.pageFilePath('book','chapter','p1',0,'jpg')
  fs.writeFileSync(target, Buffer.from([1,2,3]))
  manifest = store.recordPage(manifest, { pageId:'p1',pageIndex:0,localPath:target,size:3,
    contentHash:offline.createOfflineDownloadFileContentHash(target),updatedAt:1,sourceTextOverlay:clone })
  const loaded = store.loadManifest('book','chapter')
  assert.equal(JSON.stringify(loaded.pages[0].sourceTextOverlay), JSON.stringify(clone))
  assert.equal(loaded.pages[0].contentHash, manifest.pages[0].contentHash)
  const old = store.createManifest('old','old-chapter',0,'queued',
    { sourceKind: models.ComicSourceKind.PRIVATE_LIBRARY, sourceId:'dbm',seriesId:'old' })
  assert.equal(store.loadManifest('old','old-chapter').pages.length, 0)
  console.log('offline manifest real owner preserves overlay and reads old manifest')
} finally { fs.rmSync(tmp, { recursive: true, force: true }) }

// Exercise actual worker/cache control with graphics and file ports; pixels need device verification.
async function workerTest() {
  const crypto = require('node:crypto')
  const events = []
  let failDecode = false
  const graphics = { drawing: { Canvas: class { constructor() {} } }, text: {
    TextAlign: { CENTER: 2 }, BreakStrategy: { HIGH_QUALITY: 1 },
    FontCollection: { getGlobalInstance: () => ({}) },
    ParagraphBuilder: class {
      constructor(style) { events.push(['style', style]) }
      addText(value) { events.push(['text', value]) }
      build() { return { layoutSync(width) { events.push(['width', width]) },
        paint(_canvas,x,y) { events.push(['paint',x,y]) } } }
    },
  } }
  const image = { createImageSource: () => ({ async createPixelMap() {
    if (failDecode) throw new Error('bad image'); return { async release() {} }
  }, async release() {} }), createImagePacker: () => ({ async packing() { return Uint8Array.from([9,8,7]).buffer },
    async release() {} }) , PixelMapFormat: { RGBA_8888: 3 } }
  const cryptoFramework = { createMd: () => { const hash = crypto.createHash('sha256'); return {
    updateSync(value) { hash.update(Buffer.from(value.data)) }, digestSync() { return { data: hash.digest() } }
  } } }
  const taskpool = { execute: (fn,...args) => Promise.resolve().then(() => fn(...args)) }
  const modules = { '@kit.ArkTS': { taskpool }, '@kit.ArkGraphics2D': graphics, '@kit.ImageKit': { image },
    '@kit.CoreFileKit': { fileIo: io }, '@kit.CryptoArchitectureKit': { cryptoFramework } }
  const source = fs.readFileSync(base+'SourceTextOverlayService.ets','utf8').replace(/@Concurrent\s*/g,'')
  const module = { exports: {} }
  const compiled = ts.transpileModule(source,{ compilerOptions:{ target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS }}).outputText
  new Function('require','module','exports',compiled)(name => modules[name] ?? {},module,module.exports)
  const dir = fs.mkdtempSync(path.join(os.tmpdir(),'koma-overlay-render-'))
  try {
    const file = path.join(dir,'original.img'); fs.writeFileSync(file,Buffer.from([1,2,3]))
    const cache = new Map(), store = { async get(_u,_h,k) { return cache.get(k) },
      async put(_u,_h,b,k) { assert.equal(b.byteLength,3);cache.set(k,'derived.jpg');return 'derived.jpg' } }
    const service = module.exports.SourceTextOverlayService
    const result = await service.prepare(file, clone, store, 'source')
    assert.equal(result,'derived.jpg')
    assert.deepEqual(events.find(x=>x[0]==='paint'),['paint',1.25,3])
    assert.deepEqual(events.find(x=>x[0]==='width'),['width',4])
    assert.equal(events.find(x=>x[0]==='style')[1].textStyle.fontSize,14)
    events.length = 0
    assert.equal(await service.prepare(file,clone,store,'source'),'derived.jpg')
    assert.equal(events.length,0)
    fs.writeFileSync(file,Buffer.from([4,5,6])); failDecode = true
    await assert.rejects(service.prepare(file,clone,store,'source'),/bad image/)
    console.log('worker control uses original content identity, cache and propagates render failure')
  } finally { fs.rmSync(dir,{recursive:true,force:true}) }
}
workerTest().catch(error => { console.error(error);process.exitCode=1 })
// Run the real library serializer/hydrator with a chapter-page overlay.
const library = load(fs.readFileSync(base+'LibraryPersistence.ets','utf8'), {
  ...models, sourceTextOverlay: actual.sourceTextOverlay, fs: io,
})
const book = { id:'book', title:'Book', sourceKind:models.ComicSourceKind.PRIVATE_LIBRARY,
  sourcePath:'book', sortTitle:'book', preferredDirection:'left_to_right', chapterCount:1, pageCount:1,
  createdAt:1,updatedAt:1,lastImportedAt:1, chapters:[{ id:'chapter',comicId:'book',title:'Chapter',
    index:0,sourcePath:'chapter',sortKey:'0',pageCount:1,createdAt:1,updatedAt:1,
    pages:[{id:'page',comicId:'book',chapterId:'chapter',index:0,fileName:'page',uri:'https://example.invalid/page',sortKey:'0',sourceTextOverlay:clone}]}] }
const serialized = library.persistComic(book)
const restored = library.hydrateComic(JSON.parse(JSON.stringify(serialized)))
assert.equal(JSON.stringify(restored.chapters[0].pages[0].sourceTextOverlay), JSON.stringify(clone))
console.log('library actual page persistence retains overlay')
