// Actual personal-data/cover backup code with owned files; native picker/decoder need device evidence.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets'), modules = new Map()
const io = {
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 }, accessSync: fs.existsSync,
  access: async p => fs.existsSync(p), readTextSync: p => fs.readFileSync(p, 'utf8'),
  statSync: p => typeof p === 'number' ? fs.fstatSync(p) : fs.statSync(p),
  openSync: (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }),
  readSync: (fd, b) => fs.readSync(fd, Buffer.from(b), 0, b.byteLength, null), closeSync: f => fs.closeSync(f.fd),
  open: async (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }),
  write: async (fd, b) => fs.writeSync(fd, Buffer.from(b)), fsync: async fd => fs.fsyncSync(fd),
  close: async f => fs.closeSync(f.fd), mkdir: async p => fs.mkdirSync(p, { recursive: true }),
  unlink: async p => fs.unlinkSync(p),
  copyFile: async (fd, p) => fs.writeFileSync(p, fs.readFileSync(fd)),
}
const fileUri = { FileUri: class { constructor(uri) { this.path = decodeURI(uri.replace(/^file:\/\//, '')) } }, getUriFromPath: p => 'file://' + p }
const ports = {
  'libkoma_source_runtime.so': {},
  '@kit.CoreFileKit': { fileIo: io, fileUri },
  '@kit.ArkTS': { buffer: Buffer, util: { generateRandomUUID: require('node:crypto').randomUUID,
    Base64Helper: class { decodeSync(text) { return Uint8Array.from(Buffer.from(text, 'base64')) } } } },
  '@kit.ImageKit': { image: {
    createImageSource: input => ({
      async getImageInfo() {
        const bytes = typeof input === 'number' ? fs.readFileSync(input) : Buffer.from(input)
        assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a')
        return { size: { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) } }
      },
      async createPixelMap({ desiredSize }) { return { size: desiredSize, async release() {} } },
      async release() {},
    }),
    createImagePacker: () => ({
      async packToFile(pixels, fd, options) {
        assert.equal(options.format, 'image/png')
        fs.writeFileSync(fd, JSON.stringify(pixels.size))
      },
      async release() {},
    }),
  } },
  '../i18n/AppStrings': { AppStrings: { get: key => key } },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception() {}, info() {} } },
}
function load(file) {
  if (modules.has(file)) return modules.get(file)
  const exports = {}; modules.set(file, exports)
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8').replace(/@Concurrent\s*/g, '')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, { exports, console, Map, Set, Date, Uint8Array, ArrayBuffer, setTimeout, clearTimeout, Trace: () => {}, ObservedV2: () => {},
    require(name) {
      if (ports[name]) return ports[name]
      if (name.startsWith('@kit.')) return {}
      return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
    } })
  return exports
}
async function main() {
  const model = load('model/ComicModels'), { InMemoryLibraryStore } = load('model/LibraryStore')
  const backupExport = load('model/BusinessBackupExport'), persistence = load('model/LibraryPersistence'), personal = load('model/ComicPersonalization')
  const dir = fs.mkdtempSync('/private/tmp/koma-personal-data-')
  try {
    const coverDir = path.join(dir, 'comic-custom-covers'); fs.mkdirSync(coverDir)
    const coverPath = path.join(coverDir, 'owned.img')
    const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64')
    fs.writeFileSync(coverPath, bytes)
    const scratch = path.join(dir, 'engine-input')
    await personal.prepareComicCoverEnhancementInput(coverPath, scratch, 1024)
    assert.ok(fs.readFileSync(scratch).equals(bytes), 'a small image reaches the engine byte for byte')
    const large = Buffer.from(bytes)
    large.writeUInt32BE(2304, 16)
    large.writeUInt32BE(3072, 20)
    const oversized = path.join(dir, 'oversized-fixture')
    fs.writeFileSync(oversized, large)
    await personal.prepareComicCoverEnhancementInput(oversized, scratch, 1024)
    assert.deepEqual(JSON.parse(fs.readFileSync(scratch)), { width: 768, height: 1024 })
    assert.ok(fs.readFileSync(oversized).equals(large), 'only the inference copy changes')

    const library = new InMemoryLibraryStore()
    const book = { id: 'owned', title: 'Owned', sourceKind: model.ComicSourceKind.PRIVATE_LIBRARY,
      sourcePath: 'https://owned.invalid/book', sortTitle: 'owned', preferredDirection: 'left_to_right',
      chapters: [], chapterCount: 0, pageCount: 0, createdAt: 1, updatedAt: 1, lastImportedAt: 1,
      coverUri: 'https://owned.invalid/original.jpg' }
    library.upsertComic(book)
    let disk
    const store = { persistExistingWorks() { disk = backupExport.serializeLibraryStoreForBackup(library) } }
    personal.saveComicPersonalization(library, store,
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
    const enhancedPath = path.join(coverDir, 'enhanced.img')
    const enhancedBytes = Buffer.concat([bytes, Buffer.from([1, 2, 3])])
    fs.writeFileSync(enhancedPath, enhancedBytes)
    const enhancedUri = fileUri.getUriFromPath(enhancedPath)
    const enhanced = personal.saveComicCoverEnhancement(library, store, saved, enhancedUri, 'system_core_vision')
    assert.equal(model.comicToLibraryItem(enhanced).coverUri, enhancedUri)
    assert.equal(enhanced.coverUri, saved.coverUri)
    assert.equal(enhanced.sourceCoverUri, saved.sourceCoverUri)
    const snapshot = disk
    const customAssets = JSON.parse(personal.exportComicCoversWorker(dir, snapshot, false))
    const enhancedAssets = JSON.parse(personal.exportComicCoversWorker(dir, snapshot, true))
    const restoredBoth = await personal.prepareRestoredComicCovers({ filesDir: dir }, snapshot, customAssets, enhancedAssets)
    const roundTrip = persistence.hydrateComic(JSON.parse(restoredBoth.libraryStore).comics[0])
    assert.notEqual(roundTrip.enhancedCoverUri, enhancedUri)
    assert.equal(roundTrip.enhancedCoverModel, 'system_core_vision')
    assert.ok(fs.readFileSync(new fileUri.FileUri(roundTrip.enhancedCoverUri).path).equals(enhancedBytes))
    await personal.discardPreparedComicCovers(restoredBoth.files)
    await assert.rejects(personal.prepareRestoredComicCovers({ filesDir: dir }, snapshot, customAssets, []), /cover_missing/)
    assert.equal(library.getComic(book.id).enhancedCoverUri, enhancedUri)
    assert.throws(() => personal.saveComicCoverEnhancement(library, store, saved, undefined, undefined), /cover_changed/)
    const undone = personal.saveComicCoverEnhancement(library, store, enhanced, undefined, undefined)
    assert.equal(model.comicToLibraryItem(undone).coverUri, saved.customCoverUri)
    personal.saveComicPersonalization(library, store, saved, undefined, undefined, true)
    assert.equal(library.getComic(book.id).coverUri, 'https://owned.invalid/refreshed.jpg')
    assert.equal(library.getComic(book.id).personalNotes, 'An independent note')
    console.log('Personal data survives source/category changes; both cover files round-trip, failed restore preserves originals, and undo restores the custom cover')
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}
main().catch(error => { console.error(error); process.exitCode = 1 })
