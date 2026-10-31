// Actual personal-data/cover backup code with owned files; native picker/decoder need device evidence.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets'), modules = new Map()
const io = {
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2 }, accessSync: fs.existsSync,
  access: async p => fs.existsSync(p), readTextSync: p => fs.readFileSync(p, 'utf8'),
  statSync: p => typeof p === 'number' ? fs.fstatSync(p) : fs.statSync(p),
  openSync: (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }),
  readSync: (fd, b) => fs.readSync(fd, Buffer.from(b), 0, b.byteLength, null), closeSync: f => fs.closeSync(f.fd),
  open: async (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }),
  write: async (fd, b) => fs.writeSync(fd, Buffer.from(b)), fsync: async fd => fs.fsyncSync(fd),
  close: async f => fs.closeSync(f.fd), mkdir: async p => fs.mkdirSync(p, { recursive: true }),
  unlink: async p => fs.unlinkSync(p),
}
const fileUri = { FileUri: class { constructor(uri) { this.path = decodeURI(uri.replace(/^file:\/\//, '')) } }, getUriFromPath: p => 'file://' + p }
const ports = {
  '@kit.CoreFileKit': { fileIo: io, fileUri },
  '@kit.ArkTS': { buffer: Buffer, util: { generateRandomUUID: require('node:crypto').randomUUID,
    Base64Helper: class { decodeSync(text) { return Uint8Array.from(Buffer.from(text, 'base64')) } } } },
  '@kit.ImageKit': { image: { createImageSource: b => ({
    async getImageInfo() { assert.equal(Buffer.from(b).subarray(0,8).toString('hex'), '89504e470d0a1a0a'); return { width: 1, height: 1 } },
    async release() {},
  }) } },
  '../i18n/AppStrings': { AppStrings: { get: key => key } },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception() {} } },
}
function load(file) {
  if (modules.has(file)) return modules.get(file)
  const exports = {}; modules.set(file, exports)
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8').replace(/@Concurrent\s*/g, '')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, { exports, console, Map, Set, Date, Uint8Array, ArrayBuffer, setTimeout, clearTimeout,
    require(name) {
      if (ports[name]) return ports[name]
      if (name.startsWith('@kit.')) return {}
      return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
    } })
  return exports
}
async function main() {
  const model = load('model/ComicModels'), { InMemoryLibraryStore } = load('model/LibraryStore')
  const persistence = load('model/LibraryPersistence'), personal = load('model/ComicPersonalization')
  const dir = fs.mkdtempSync('/private/tmp/koma-personal-data-')
  try {
    const coverDir = path.join(dir, 'comic-custom-covers'); fs.mkdirSync(coverDir)
    const coverPath = path.join(coverDir, 'owned.img')
    const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64')
    fs.writeFileSync(coverPath, bytes)
    const library = new InMemoryLibraryStore()
    const book = { id: 'owned', title: 'Owned', sourceKind: model.ComicSourceKind.PRIVATE_LIBRARY,
      sourcePath: 'https://owned.invalid/book', sortTitle: 'owned', preferredDirection: 'left_to_right',
      chapters: [], chapterCount: 0, pageCount: 0, createdAt: 1, updatedAt: 1, lastImportedAt: 1,
      coverUri: 'https://owned.invalid/original.jpg' }
    library.upsertComic(book)
    let disk
    personal.saveComicPersonalization(library, { persist() { disk = persistence.serializeLibraryStore(library) } },
      book, 'An independent note', fileUri.getUriFromPath(coverPath))
    const saved = library.getComic(book.id)
    model.assignComicSourceCover(saved, 'https://owned.invalid/refreshed.jpg')
    assert.equal(saved.coverUri, fileUri.getUriFromPath(coverPath))
    assert.equal(saved.sourceCoverUri, 'https://owned.invalid/refreshed.jpg')
    const categoryProjection = model.withComicCategoryIds(saved, ['favorite'])
    assert.equal(categoryProjection.personalNotes, 'An independent note')
    assert.equal(categoryProjection.customCoverUri, saved.customCoverUri)
    const covers = JSON.parse(personal.exportComicCoversWorker(dir, disk))
    assert.equal(covers.length, 1)
    assert.ok(Buffer.from(covers[0].base64, 'base64').equals(bytes))
    const restored = await personal.prepareRestoredComicCovers({ filesDir: dir }, disk, covers)
    const hydrated = persistence.hydrateComic(JSON.parse(restored.libraryStore).comics[0])
    assert.notEqual(hydrated.customCoverUri, saved.customCoverUri)
    assert.equal(hydrated.personalNotes, 'An independent note')
    assert.ok(fs.readFileSync(new fileUri.FileUri(hydrated.customCoverUri).path).equals(bytes))
    await personal.discardPreparedComicCovers(restored.files)
    await assert.rejects(personal.prepareRestoredComicCovers({ filesDir: dir }, disk, []), /cover_missing/)
    assert.ok(fs.readFileSync(coverPath).equals(bytes), 'Failed restore must leave the original selected cover intact')
    personal.saveComicPersonalization(library, { persist() {} }, saved, undefined, undefined, true)
    assert.equal(library.getComic(book.id).coverUri, 'https://owned.invalid/refreshed.jpg')
    assert.equal(library.getComic(book.id).personalNotes, 'An independent note')
    console.log('Personal data survives source/category changes; cover bytes round-trip and failed restore preserves originals')
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}
main().catch(error => { console.error(error); process.exitCode = 1 })
