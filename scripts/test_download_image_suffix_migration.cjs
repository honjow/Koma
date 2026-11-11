// Exercise real manifests and files, including interrupted and failed renames.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets/model')
function load(name, deps = {}) {
  const source = fs.readFileSync(path.join(root, name + '.ets'), 'utf8').replace(/@Concurrent\s*/g, '')
  const module = { exports: {} }
  new Function('require', 'module', 'exports', ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText)(key => { assert.ok(Object.hasOwn(deps, key), key); return deps[key] }, module, module.exports)
  return module.exports
}
let failRename = ''
const io = {
  accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
  openSync: (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }), closeSync: f => fs.closeSync(f.fd),
  readTextSync: p => fs.readFileSync(p, 'utf8'), writeSync: fs.writeSync, fsyncSync: fs.fsyncSync,
  renameSync: (from, to) => { if (to.endsWith(failRename) && failRename) throw Error('fixture rename failure'); fs.renameSync(from, to) },
  unlinkSync: fs.unlinkSync, statSync: fs.statSync, listFileSync: fs.readdirSync,
  readSync: (fd, array) => fs.readSync(fd, Buffer.from(array), 0, array.byteLength, null),
}
const logger = { exception() {}, info() {} }
const persistence = load('AppFileTextPersistence', { '@kit.CoreFileKit': { fileIo: io }, '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger } })
const index = load('DownloadDirectoryIndex', { '@kit.CoreFileKit': { fileIo: io }, './AppFileTextPersistence': persistence })
const overlays = load('SourceTextOverlay')
const models = load('ComicModels', { '../i18n/AppStrings': { AppStrings: { get: x => x } } })
const storeModule = load('OfflineDownloadStore', { '@kit.CoreFileKit': { fileIo: io }, './SourceTextOverlay': overlays,
  './AppFileTextPersistence': persistence, './DownloadDirectoryIndex': index, './ComicModels': models })
const format = load('DownloadImageFormat')
assert.equal(format.downloadImageExtension(Buffer.from('000000186674797061766966000000006d696631', 'hex')), 'avif')
assert.equal(format.downloadImageExtension(Buffer.from('00000014667479706d69663100000000', 'hex')), 'heif')
assert.equal(format.downloadImageExtension(Buffer.from('00000014667479706865696300000000', 'hex')), 'heic')
const migration = load('OfflineDownloadImageMigration', { '@kit.CoreFileKit': { fileIo: io },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger }, './AppFileTextPersistence': persistence,
  './DownloadImageFormat': format, './DownloadDirectoryIndex': index, './OfflineDownloadStore': storeModule })
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-suffix-migration-'))
try {
  const storage = path.join(tmp, 'public'), app = path.join(tmp, 'private')
  fs.mkdirSync(storage); fs.mkdirSync(app)
  const store = new storeModule.OfflineDownloadStore(storage, app)
  function chapter(id) {
    let m = store.createManifest('book', id, 2, 'downloaded', undefined, { comicTitle: 'Test', chapterTitle: id })
    const samples = [Buffer.from('ffd8ffe0112233', 'hex'), Buffer.from('89504e470d0a1a0a1011', 'hex')]
    samples.forEach((data, n) => {
      const file = store.pageFilePath('book', id, 'p'+n, n, 'img')
      fs.writeFileSync(file, data)
      m = store.recordPage(m, { pageId:'p'+n, pageIndex:n, localPath:file, size:data.length,
        contentHash:storeModule.createOfflineDownloadFileContentHash(file), updatedAt:1 })
    })
    return store.saveManifest(m)
  }
  chapter('success')
  const orphan = path.join(store.chapterDir('book', 'success'), '00001-old.img')
  fs.writeFileSync(orphan, Buffer.from('ffd8ffe0112233', 'hex'))
  assert.equal(migration.migrateOfflineChapterImageSuffixes(store, 'book', 'success'), 3)
  assert.equal(fs.existsSync(orphan), false)
  assert.equal(fs.readFileSync(orphan.replace(/\.img$/, '.jpg')).toString('hex'), 'ffd8ffe0112233')
  let result = store.validateDownloadedChapter('book', 'success')
  assert.equal(result.status, storeModule.OfflineDownloadedChapterStatus.DOWNLOADED)
  assert.deepEqual(result.manifest.pages.map(p => path.extname(p.localPath)), ['.jpg', '.png'])
  assert.ok(result.manifest.pages.every(p => fs.existsSync(p.localPath)))
  assert.equal(migration.migrateOfflineChapterImageSuffixes(store, 'book', 'success'), 0)
  chapter('failed')
  failRename = '002.png'
  assert.throws(() => migration.migrateOfflineChapterImageSuffixes(store, 'book', 'failed'), /fixture rename failure/)
  failRename = ''
  result = store.validateDownloadedChapter('book', 'failed')
  assert.equal(result.status, storeModule.OfflineDownloadedChapterStatus.DOWNLOADED)
  assert.ok(result.manifest.pages.every(p => p.localPath.endsWith('.img') && fs.existsSync(p.localPath)))
  assert.equal(migration.migrateOfflineChapterImageSuffixes(store, 'book', 'failed'), 2)
  const interrupted = chapter('interrupted'), dir = store.chapterDir('book', 'interrupted')
  const oldPath = interrupted.pages[0].localPath, newPath = oldPath.replace(/\.img$/, '.jpg')
  fs.writeFileSync(path.join(dir, '.koma/image-suffix-migration.json'), JSON.stringify({ version:1,
    renames:[{oldName:path.basename(oldPath),newName:path.basename(newPath)}] }))
  fs.renameSync(oldPath, newPath)
  assert.equal(migration.migrateOfflineChapterImageSuffixes(store, 'book', 'interrupted'), 2)
  assert.equal(store.validateDownloadedChapter('book', 'interrupted').status, storeModule.OfflineDownloadedChapterStatus.DOWNLOADED)
  const collision = chapter('collision'), existing = collision.pages[0].localPath.replace(/\.img$/, '.jpg')
  fs.writeFileSync(existing, Buffer.from('owned external file'))
  assert.equal(migration.migrateOfflineChapterImageSuffixes(store, 'book', 'collision'), 1)
  assert.equal(fs.readFileSync(existing, 'utf8'), 'owned external file')
  assert.ok(fs.existsSync(collision.pages[0].localPath))
  assert.equal(store.validateDownloadedChapter('book', 'collision').status, storeModule.OfflineDownloadedChapterStatus.DOWNLOADED)
  console.log('PASS: formats, manifests, retries, interrupted rename recovery and collisions')
} finally { fs.rmSync(tmp, { recursive: true, force: true }) }
