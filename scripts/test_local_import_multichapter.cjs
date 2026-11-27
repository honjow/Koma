const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
function load(file, ports = {}) {
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file + '.ets'), 'utf8').replace(/@Concurrent\s*/g, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exports = {}
  new Function('require', 'exports', js)(name => {
    if (!Object.hasOwn(ports, name)) throw Error('Unexpected import: ' + name)
    return ports[name]
  }, exports)
  return exports
}
const models = load('model/ComicModels')
const pdf = load('import/PdfPageService', { '@kit.ArkTS': {}, '@kit.PDFKit': {}, '@kit.ImageKit': {} })
const zipPage = load('import/ComicZipPage', {
  '@kit.ArkTS': {}, './ImageSortUtils': load('import/ImageSortUtils'), './NativeArchiveExtraction': { nativeComicArchive: {
    readZipEntry: async (_path, entry) => Uint8Array.from(Buffer.from(entry)).buffer,
  } },
})
const api = load('import/LocalImportCommitService', {
  '@kit.CoreFileKit': { hash: { hash: async path => Buffer.from(path.split('/').pop()).toString('hex') } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd() {
    let data
    return { update: async blob => { data = blob.data }, digest: async () => ({ data }) }
  } } },
  '@kit.ArkTS': { util: { generateRandomUUID: () => 'new-id' } },
  '../model/ComicModels': models, '../model/BackupRestoreActivity': {}, '../model/LibraryPersistence': {},
  './PdfPageService': pdf, './ComicZipPage': zipPage, './ImageSortUtils': load('import/ImageSortUtils'),
})
const sameOrder = () => new Map([[0, 0], [1, 1], [2, 2]])
function comic(id, root) {
  const chapters = ['one', 'two', 'three'].map((name, index) => ({ id: `${id}-${name}`, comicId:id,
    title:name,index,sourcePath:'file://book.zip#'+name,pages:[{ id:`${id}-${name}-p`,comicId:id,chapterId:`${id}-${name}`,index:0,
      uri:`file://${root}/${name}.jpg` }],pageCount:1,createdAt:1 }))
  return { id,title:'Title',sortTitle:'title',sourceKind:models.ComicSourceKind.LOCAL_ARCHIVE,
    localImportOrigin:{kind:'archive',sourceUris:['file://book.zip']},chapters,createdAt:1 }
}
test('reimporting the same multi-chapter archive keeps every chapter and page identity', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.author = 'Archive author'
  old.coverUri = old.chapters[1].pages[0].uri
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), sameOrder())
  const merged = api.mergeLocalImport(old,fresh,sameOrder())
  assert.deepEqual(merged.chapters.map(chapter => chapter.id),['old-one','old-two','old-three'])
  assert.deepEqual(merged.chapters.map(chapter => chapter.pages[0].id),['old-one-p','old-two-p','old-three-p'])
  assert.equal(merged.coverUri,'file:///new/two.jpg')
  assert.equal(merged.chapters[2].pages[0].comicId,'old')
  assert.equal(merged.author,'Archive author')
})
test('reimport does not replace a user-edited author', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  old.author = 'Custom'; fresh.author = 'Archive author'
  assert.equal(api.mergeLocalImport(old,fresh,sameOrder()).author,'Custom')
})
test('reimport fills a missing description but preserves an existing one', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.subtitle = 'Archive description'
  assert.equal(api.mergeLocalImport(old,fresh,sameOrder()).subtitle,'Archive description')
  const oldWithDescription = comic('old','/old'), newer = comic('fresh','/new')
  oldWithDescription.subtitle = 'Previously saved'; newer.subtitle = 'Archive description'
  assert.equal(api.mergeLocalImport(oldWithDescription,newer,sameOrder()).subtitle,'Previously saved')
})
test('PDF reimport compares the original document and keeps page identities', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  for (const [value, rootPath] of [[old, '/old'], [fresh, '/new']]) {
    value.chapters.forEach((chapter, index) => { chapter.pages[0].uri = pdf.pdfPageUri(rootPath + '/book.pdf', index) })
  }
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), sameOrder())
  assert.equal(api.mergeLocalImport(old, fresh, sameOrder()).chapters[1].pages[0].id, 'old-two-p')
  fresh.chapters[1].pages[0].uri = pdf.pdfPageUri('/new/book.pdf', 9)
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), new Map([[0, 0], [2, 2]]))
})
test('PDF reimport replaces its generated cover but retains a custom cover', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  old.chapters[0].pages[0].uri = pdf.pdfPageUri('/old/archive.zip', 0)
  old.coverUri = 'file:///old/extract/cover.jpg'; fresh.coverUri = 'file:///new/extract/cover.jpg'
  assert.equal(api.mergeLocalImport(old, fresh, sameOrder()).coverUri, 'file:///new/extract/cover.jpg')
  const custom = comic('old','/old'), newer = comic('fresh','/new')
  custom.chapters[0].pages[0].uri = pdf.pdfPageUri('/old/archive.zip', 0)
  custom.coverUri = 'file:///custom.jpg'; custom.customCoverUri = custom.coverUri
  newer.coverUri = 'file:///new/extract/cover.jpg'
  assert.equal(api.mergeLocalImport(custom, newer, sameOrder()).coverUri, custom.coverUri)
})

test('EPUB reimport updates the automatic cover and keeps a personal cover and page identity', () => {
  const old = comic('old', '/old')
  const fresh = comic('fresh', '/new')
  fresh.localImportOrigin.sourceUris = ['file://book.epub']
  const expectedCover = 'file:///new/cover.png'
  fresh.coverUri = expectedCover
  old.coverUri = old.chapters[0].pages[0].uri
  assert.equal(api.mergeLocalImport(old, structuredClone(fresh), sameOrder()).coverUri, expectedCover)
  old.customCoverUri = 'file:///personal.png'
  old.coverUri = old.customCoverUri
  old.personalNotes = 'Keep this note'
  const merged = api.mergeLocalImport(old, fresh, sameOrder())
  assert.equal(merged.coverUri, old.customCoverUri)
  assert.equal(merged.sourceCoverUri, expectedCover)
  assert.equal(merged.personalNotes, old.personalNotes)
  assert.equal(merged.chapters[0].pages[0].id, old.chapters[0].pages[0].id)
})
test('a changed chapter is not mistaken for the same archive contents', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.chapters[1].pages[0].uri = 'file:///new/changed.jpg'
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), new Map([[0, 0], [2, 2]]))
})

test('a CBZ reimport keeps the personal cover, enhancement, and notes', () => {
  const old = comic('old', '/old'), fresh = comic('fresh', '/new')
  fresh.localImportOrigin.sourceUris = old.localImportOrigin.sourceUris = ['file://book.cbz']
  old.customCoverUri = old.coverUri = 'file:///personal-cover.png'
  old.sourceCoverUri = old.chapters[0].pages[0].uri
  old.enhancedCoverUri = 'file:///personal-enhanced.png'
  old.personalNotes = 'Keep this note'
  fresh.coverUri = fresh.chapters[0].pages[0].uri
  const merged = api.mergeLocalImport(old, fresh, sameOrder())
  assert.equal(merged.customCoverUri, old.customCoverUri)
  assert.equal(merged.enhancedCoverUri, old.enhancedCoverUri)
  assert.equal(merged.personalNotes, old.personalNotes)
  assert.equal(merged.sourceCoverUri, 'file:///new/one.jpg')
})

test('reimporting a changed archive preserves unchanged chapters even when a new chapter shifts them', async () => {
  const old = comic('old', '/old'), fresh = comic('fresh', '/new')
  const added = structuredClone(fresh.chapters[0])
  added.sourcePath = 'file://book.zip#added'
  added.title = 'new chapter'
  added.pages[0].uri = 'file:///new/added.jpg'
  fresh.chapters[1].pages[0].uri = 'file:///new/replaced.jpg'
  fresh.chapters.unshift(added)
  const merged = api.mergeLocalImport(old, fresh, await api.matchLocalImportChapters(old, fresh))
  assert.equal(merged.chapters[1].pages[0].id, 'old-one-p')
  assert.notEqual(merged.chapters[2].id, 'old-two')
  assert.equal(merged.chapters[3].pages[0].id, 'old-three-p')
  const position = { comicId: old.id, chapterId: 'old-three', pageId: 'old-three-p', pageIndex: 0, totalPages: 1 }
  assert.equal(models.currentComicReadingProgress(merged, position), position)
  assert.equal(models.currentComicReadingProgress(merged, { ...position, chapterId: 'old-two', pageId: 'old-two-p' }), undefined)
})

test('ZIP reimport preserves page IDs when replacing an older extracted copy', async () => {
  const old = comic('old', '/old'), fresh = comic('fresh', '/new')
  for (const chapter of fresh.chapters) {
    const page = chapter.pages[0]
    page.uri = zipPage.comicZipPageUri('/new/archive.zip', page.uri.split('/').pop())
  }
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), sameOrder())
  const edited = comic('edited', '/old')
  edited.chapters[1].pages[0].uri = 'file:///old/replaced.jpg'
  assert.deepEqual(await api.matchLocalImportChapters(edited, fresh), new Map([[0, 0], [2, 2]]))
  const merged = api.mergeLocalImport(old, fresh, sameOrder())
  assert.deepEqual(merged.chapters.map(chapter => chapter.pages[0].id), ['old-one-p', 'old-two-p', 'old-three-p'])
})

const { execFileSync } = require('node:child_process')
const { createHash, randomUUID } = require('node:crypto')
const os = require('node:os')
const realHash = async file => createHash('sha256').update(await fs.promises.readFile(file)).digest('hex')
const fileUri = file => 'file://' + file.split('/').map(encodeURIComponent).join('/')
const zipOutput = (command, archive, entry) => execFileSync('python3', ['-c',
  'import sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); ' + command, archive, entry ?? ''], { stdio: ['ignore', 'pipe', 'pipe'] })
const readEntry = (archive, entry) => Uint8Array.from(zipOutput('sys.stdout.buffer.write(z.read(sys.argv[2]))', archive, entry)).buffer
const zipNative = {
  listZip: async archive => zipOutput('print("\\n".join(z.namelist()))', archive).toString().trim().split('\n')
    .map(path => ({ path, size: 1 })),
  readZipEntry: async (archive, entry) => readEntry(archive, entry),
  copyZipEntry: async (archive, entry, limit, target) => fs.promises.writeFile(target, new Uint8Array(readEntry(archive, entry))),
}
const migrationZip = load('import/ComicZipPage', {
  '@kit.ArkTS': { util: { TextDecoder: { create: () => new TextDecoder() } } },
  './ImageSortUtils': load('import/ImageSortUtils'),
  './NativeArchiveExtraction': { nativeComicArchive: zipNative },
})
const imageSort = load('import/ImageSortUtils')
const nodeFiles = {
  lstat: async file => fs.promises.lstat(file).catch(error => {
    if (error.code === 'ENOENT') error.code = 13900002
    throw error
  }),
  copyFile: fs.promises.copyFile,
  listFile: async file => fs.promises.readdir(file),
  readText: async file => fs.promises.readFile(file, 'utf8'),
  mkdir: async (file, recursive) => fs.promises.mkdir(file, { recursive }),
  rmdir: async file => fs.promises.rm(file, { recursive: true }),
  unlink: fs.promises.unlink,
  open: async file => ({ fd: await fs.promises.open(file, 'r+') }),
  close: async file => file.fd.close(),
  fsync: async fd => fd.sync(),
  OpenMode: { READ_WRITE: 2 },
}
const realImports = load('import/LocalImportCommitService', {
  '@kit.CoreFileKit': { hash: { hash: realHash } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd() {
    const digest = createHash('sha256')
    return { update: async blob => digest.update(blob.data), digest: async () => ({ data: new Uint8Array(digest.digest()) }) }
  } } },
  '@kit.ArkTS': { util: { generateRandomUUID: randomUUID } },
  '../model/ComicModels': models,
  '../model/BackupRestoreActivity': load('model/BackupRestoreActivity'),
  '../model/LibraryPersistence': {},
  './PdfPageService': pdf,
  './ComicZipPage': migrationZip,
  './ImageSortUtils': imageSort,
})
const archiveExtraction = load('import/ArchiveExtractionService', {
  '@kit.CoreFileKit': { fileIo: nodeFiles },
  '../model/ComicModels': models,
  './NativeArchiveExtraction': { nativeComicArchive: zipNative },
  './ComicZipPage': migrationZip,
  './EpubArchiveReader': {},
  './PdfPageService': pdf,
  './ArchiveImageChapters': load('import/ArchiveImageChapters', {
    './ImageSortUtils': imageSort,
    '../model/LocalLibraryFolderContract': { scanLocalLibraryFolderEntries: () => ({ series: [] }) },
  }),
  '../model/LocalLibraryMetadataService': { parseLocalLibrarySidecarMetadata: () => ({ status: 'missing' }) },
  './ArchiveImportService': load('import/ArchiveImportService', {
    '@kit.ArkTS': { util: { generateRandomUUID: randomUUID } },
    '../model/ComicModels': models, './ImageSortUtils': imageSort, './ComicZipPage': migrationZip,
  }),
  './ImageSortUtils': imageSort,
})
const migration = load('import/LegacyZipImportMigration', {
  '@kit.CoreFileKit': { fileIo: nodeFiles, hash: { hash: realHash } },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception: (_tag, code, error) => diagnostic.push([code, error.message]) } },
  '../model/AppFileTextPersistence': { writeAppTextFile: fs.writeFileSync },
  '../model/BackupRestoreActivity': load('model/BackupRestoreActivity'),
  '../model/ComicModels': models,
  '../model/KomaContentStorage': { komaContentStorageBase: context => context.publicDir },
  '../model/LocalLibraryFolderContract': { localLibraryFolderRootUriFromComic: comic => comic.folderRoot },
  './ArchiveExtractionService': archiveExtraction,
  './ComicZipPage': migrationZip,
  './LocalImportCoordinator': {
    createManagedImportPaths(filesDir) {
      const rootDir = path.join(filesDir, 'import', 'v1-' + randomUUID())
      return { rootDir, archiveZipPath: path.join(rootDir, 'archive.zip'), extractionDir: path.join(rootDir, 'extract') }
    },
    async createManagedImportRoot(filesDir, rootDir) {
      await fs.promises.mkdir(path.join(filesDir, 'import'), { recursive: true })
      await fs.promises.mkdir(rootDir)
    },
  },
  './LocalImportCommitService': realImports,
  './PdfPageService': pdf,
})
const diagnostic = []

function legacyFixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-zip-upgrade-'))
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }))
  const context = { filesDir: path.join(dir, 'files'), cacheDir: path.join(dir, 'cache'), publicDir: path.join(dir, 'Download/Koma') }
  fs.mkdirSync(context.filesDir)
  const oldRoot = path.join(context.publicDir, 'import', 'v1-' + randomUUID())
  const extracted = path.join(oldRoot, 'extract')
  const child = path.join(oldRoot, 'extract.chapters/0/extract')
  fs.mkdirSync(extracted, { recursive: true })
  fs.mkdirSync(child, { recursive: true })
  const source = path.join(dir, '用户的原包.zip')
  const outerPage = path.join(extracted, '第 1 页.jpg')
  const childPage = path.join(child, '第 2 页.jpg')
  const cover = path.join(extracted, 'cover.jpg')
  execFileSync('python3', ['-c', [
    'import io, pathlib, sys, zipfile',
    'archive, outer, child, cover = map(pathlib.Path, sys.argv[1:])',
    'inner = io.BytesIO()',
    'with zipfile.ZipFile(inner, "w", zipfile.ZIP_DEFLATED) as nested: nested.writestr(child.name, b"chapter-two")',
    'with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as book:',
    '    book.writestr(outer.name, b"chapter-one")',
    '    book.writestr(cover.name, b"cover")',
    '    book.writestr("第二章.cbz", inner.getvalue())',
    'outer.write_bytes(b"chapter-one")',
    'child.write_bytes(b"chapter-two")',
    'cover.write_bytes(b"cover")',
  ].join('\n'), source, outerPage, childPage, cover])
  const originalBytes = fs.readFileSync(source)
  fs.copyFileSync(source, path.join(oldRoot, 'archive.zip'))
  const old = comic('old-book', extracted)
  // Keep an intentionally persisted order which differs from a fresh import.
  old.sourcePath = fileUri(source)
  old.localImportOrigin.sourceUris = [old.sourcePath]
  old.chapters = old.chapters.slice(0, 2)
  old.chapters[0].sourcePath = old.sourcePath + '#第二章.cbz'
  old.chapters[0].pages[0].uri = fileUri(childPage)
  old.chapters[1].sourcePath = old.sourcePath
  old.chapters[1].pages[0].uri = fileUri(outerPage)
  old.coverUri = fileUri(cover)
  old.personalNotes = 'Keep note'
  old.categoryIds = ['library-category']
  const works = new Map([[old.id, old]])
  const library = {
    getComic: id => works.get(id),
    upsertComic: value => works.set(value.id, value),
    listComicSummaries: () => [...works.values()],
    listComicSummariesByKind: kinds => [...works.values()].filter(comic => kinds.includes(comic.sourceKind)),
  }
  const storage = { value: old, fail: false, persistExistingWorks([value]) {
    if (this.fail) throw new Error('write failed')
    this.value = structuredClone(value)
  } }
  const make = () => new migration.LegacyZipImportMigration(library, storage,
    new realImports.LocalImportCommitService(library, storage))
  return { context, oldRoot, source, originalBytes, old, outerPage, works, storage, make }
}

test('upgrade restores nested ZIP pages and the cover in place in the catalog, then clears only old app files', async t => {
  const fixture = legacyFixture(t)
  const { context, oldRoot, source, originalBytes, old, storage, make } = fixture
  fs.writeFileSync(path.join(oldRoot, 'user-note.txt'), 'Keep this file')
  let allowCleanup = true
  diagnostic.length = 0
  await make().run(context, () => allowCleanup, () => { allowCleanup = false })
  assert.equal(fs.existsSync(path.join(oldRoot, 'extract')), true)
  assert.deepEqual(storage.value.chapters.map(ch => [ch.id, ch.pages[0].id]),
    old.chapters.map(ch => [ch.id, ch.pages[0].id]), JSON.stringify(diagnostic))
  assert.equal(storage.value.personalNotes, old.personalNotes)
  assert.deepEqual(storage.value.categoryIds, old.categoryIds)
  const zip = uri => migrationZip.parseComicZipPage(uri)
  const newCover = zip(storage.value.coverUri)
  assert.ok(newCover.archive.startsWith(context.filesDir + '/import/'), JSON.stringify(diagnostic))
  assert.deepEqual(fs.readFileSync(newCover.archive), originalBytes)
  assert.equal(Buffer.from(readEntry(newCover.archive, newCover.entry)).toString(), 'cover')
  assert.deepEqual(storage.value.chapters.map(ch => {
    const { archive, entry } = zip(ch.pages[0].uri)
    return Buffer.from(readEntry(archive, entry)).toString()
  }), ['chapter-two', 'chapter-one'])
  // Reload only the durable catalog, as on a new process after publication.
  fixture.works.set(old.id, structuredClone(storage.value))
  await make().run(context, () => true, () => assert.fail('The already migrated catalog must not be written again'))
  assert.deepEqual(fs.readdirSync(oldRoot), ['user-note.txt'])
  assert.deepEqual(fs.readFileSync(source), originalBytes)
})

test('missing archives, failed persistence and mismatched pages leave the readable old import intact', async t => {
  const { context, oldRoot, outerPage, old, storage, make } = legacyFixture(t)
  const idle = () => true
  const retained = path.join(oldRoot, 'archive.zip')
  const bytes = fs.readFileSync(retained)
  fs.unlinkSync(retained)
  await make().run(context, idle, () => assert.fail('A missing original must not publish'))
  assert.equal(storage.value, old)
  assert.ok(fs.existsSync(outerPage))
  fs.writeFileSync(retained, bytes)
  storage.fail = true
  await make().run(context, idle, () => assert.fail('A failed commit must not publish'))
  assert.equal(storage.value, old)
  assert.ok(fs.existsSync(outerPage))
  storage.fail = false
  fs.writeFileSync(outerPage, 'changed page')
  await make().run(context, idle, () => assert.fail('A content mismatch must not publish'))
  assert.equal(fs.readFileSync(outerPage, 'utf8'), 'changed page')
  assert.deepEqual(fs.readdirSync(path.join(context.filesDir, 'import')), [])
  fs.writeFileSync(outerPage, 'chapter-one')
  await make().run(context, idle, () => {})
  assert.notEqual(storage.value, old, JSON.stringify(diagnostic))
  assert.equal(fs.existsSync(oldRoot), false)
})
