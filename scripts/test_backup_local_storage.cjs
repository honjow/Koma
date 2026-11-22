const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const crypto = require('node:crypto')
const { gzipSync, gunzipSync } = require('node:zlib')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function evaluate(model, requireMock) {
 const src = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model', model + '.ets'), 'utf8')
 const js = ts.transpileModule(src, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
 const exports = {}
 new Function('exports', 'require', js)(exports, requireMock)
 return exports
}
const exactBytes = b => b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)
const fileIoBytes = {
 OpenMode: { READ_ONLY: fs.constants.O_RDONLY, WRITE_ONLY: fs.constants.O_WRONLY,
  CREATE: fs.constants.O_CREAT, TRUNC: fs.constants.O_TRUNC },
 open: async (p, mode) => ({ fd: fs.openSync(p, mode) }),
 stat: async fd => fs.fstatSync(fd),
 read: async (fd, bytes) => fs.readSync(fd, Buffer.from(bytes)),
 write: async (fd, bytes) => fs.writeSync(fd, Buffer.from(bytes)),
 fsync: async fd => fs.fsyncSync(fd), close: async file => fs.closeSync(file.fd),
 rename: fs.promises.rename, unlink: fs.promises.unlink,
}
const arkTS = { buffer: { from(value, ...args) {
 const bytes = Buffer.from(value, ...args)
 return typeof value === 'string' ? Buffer.from(exactBytes(bytes)) : bytes
} }, util: { generateRandomUUID: () => crypto.randomUUID(), Base64Helper: class {
 encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64') }
 decodeSync(value) { return Uint8Array.from(Buffer.from(value, 'base64')) }
} } }
const format = evaluate('BackupFileFormat', name => ({
 '@kit.ArkTS': arkTS, '@kit.CoreFileKit': { fileIo: fileIoBytes },
 '@kit.BasicServicesKit': { zlib: {
  CompressLevel: { COMPRESS_LEVEL_DEFAULT_COMPRESSION: -1 }, CompressMethod: { DEFLATED: 8 },
  MemLevel: { MEM_LEVEL_DEFAULT: 8 }, CompressStrategy: { COMPRESS_STRATEGY_DEFAULT_STRATEGY: 0 },
  CompressFlushMode: { FINISH: 4 }, ReturnStatus: { OK: 0, STREAM_END: 1 },
  createZipSync() {
   let totalOut
   function transform(stream, fn) {
    const output = fn(Buffer.from(stream.nextIn))
    new Uint8Array(stream.nextOut).set(output)
    totalOut = output.length
    return 1
   }
   return {
    async deflateInit2() { return 0 }, async inflateInit2() { return 0 },
    async compressBound(size) { return size + 128 + Math.ceil(size / 64) },
    async deflate(stream) { return transform(stream, gzipSync) },
    async inflate(stream) { return transform(stream, gunzipSync) },
    async getZStream() { return { totalOut, availableIn: 0 } },
    async deflateEnd() {}, async inflateEnd() {},
   }
  },
 } },
})[name])

function legacyPreview(read = fileIoBytes.read) {
 return evaluate('LegacyBackupPreview', name => ({
  '@kit.CoreFileKit': { fileIo: { ...fileIoBytes, read } },
  '@kit.ArkTS': { util: { TextDecoder: { create(label, options) {
   const decoder = new TextDecoder(label, options)
   return { decodeToString: (bytes, options) => decoder.decode(bytes, options) }
  } } } },
 })[name]).readLegacyBackupPreviewJson
}

test('large legacy backup preview reads bounded chunks and retains metadata after the book payload', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-preview-'))
 t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const file = path.join(root, 'large.json')
 const fd = fs.openSync(file, 'w')
 try {
  fs.writeSync(fd, '{"libraryStore":"')
  const page = Buffer.alloc(64 * 1024, 'a')
  for (let i = 0; i < 2048; i++) fs.writeSync(fd, page)
  fs.writeSync(fd, '","readingProgress":"{}","exportedAt":42,"schemaVersion":3,"settings":{"exportedAt":99}}')
 } finally {
  fs.closeSync(fd)
 }
 let totalBytes = 0
 const preview = legacyPreview(async (fd, buffer) => {
  assert.ok(buffer.byteLength <= 64 * 1024)
  const size = await fileIoBytes.read(fd, buffer)
  totalBytes += size
  return size
 })
 assert.deepEqual(JSON.parse(await preview(file)), {
  libraryStore: '', readingProgress: '', exportedAt: 42, schemaVersion: 3,
 })
 assert.equal(totalBytes, fs.statSync(file).size)
})

test('legacy backup metadata survives split UTF-8 and escapes, and corrupt files are rejected', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-preview-'))
 t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const file = path.join(root, 'legacy.koma-backup')
 const preview = legacyPreview(async (fd, buffer) => fs.readSync(fd, Buffer.from(buffer), 0, 7))
 const encrypted = evaluate('BackupEncryptionService', name => ({
  '@kit.ArkTS': arkTS, '@kit.CryptoArchitectureKit': { cryptoFramework: {} },
  '../i18n/AppStrings': { AppStrings: { get: key => key } }, './BackupFileFormat': format,
 })[name])
 const aad = encrypted.backupEncryptedAad(4)
 const envelope = {
  ...aad, createdAt: 42, kdf: { id: aad.kdfId, iterations: 600000, salt: 'salt' },
  nonce: 'nonce', tag: 'tag', aad, payload: 'contains \"quotes\", a \\ and 漫画🐈',
 }
 fs.writeFileSync(file, JSON.stringify(envelope))
 assert.equal(encrypted.previewEncryptedBackupEnvelope(await preview(file)).exportedAt, 42)
 fs.writeFileSync(file, JSON.stringify({ ...envelope, aad: { ...aad, unexpected: 1 } }))
 await assert.rejects(async () => encrypted.previewEncryptedBackupEnvelope(await preview(file)), /backup_invalid_encrypted_envelope/)
 for (const malformed of ['{"readingProgress": "a\\u123X"}', '{"libraryStore":"abc', '{"unknown":[0,]}', '{} {}']) {
  fs.writeFileSync(file, malformed)
  await assert.rejects(preview(file), /backup_invalid_legacy_preview/)
 }
})

function load(overrides = {}) {
 const fileIo = {
  access: async p => fs.existsSync(p),
  mkdir: async (p, recursive) => fs.promises.mkdir(p, { recursive }),
  listFile: p => fs.promises.readdir(p), stat: p => fs.promises.stat(p),
  copyFile: (a, b) => fs.promises.copyFile(a, b), rename: (a, b) => fs.promises.rename(a, b),
  OpenMode: { READ_WRITE: fs.constants.O_RDWR }, open: async (p, mode) => ({ fd: fs.openSync(p, mode) }),
  fsync: async fd => fs.fsyncSync(fd), close: async file => fs.closeSync(file.fd),
  unlink: p => fs.promises.unlink(p), ...overrides,
 }
 const hash = { hash: async p => crypto.createHash('sha256').update(await fs.promises.readFile(p)).digest('hex') }
 const requireMock = name => name === '@kit.CoreFileKit' ? { fileIo, hash } :
  name === './BackupFileFormat' ? format :
  name === './KomaContentStorage' ? { ensureKomaContentStorageBase: async context => context.publicBase,
   hasKomaPublicContentStorage: context => context.publicExpected === true } : {}
 return evaluate('BackupLocalStorage', requireMock)
}
test('migrate preserves old backups, resolves conflicting names, and does not repeat deleted records', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-test-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const priv = path.join(root, 'private'), pub = path.join(root, 'public')
 fs.mkdirSync(path.join(priv, 'backups'), { recursive: true }); fs.mkdirSync(path.join(pub, 'backups'), { recursive: true })
 fs.writeFileSync(path.join(priv, 'backups', 'same.json'), 'old'); fs.writeFileSync(path.join(pub, 'backups', 'same.json'), 'new')
 fs.writeFileSync(path.join(priv, 'backups', 'protected.koma-backup'), 'encrypted')
 const compressed = await format.encodeBackupFile('{"readingProgress":"18-5"}', { exportedAt: 100, encrypted: false })
 fs.writeFileSync(path.join(priv, 'backups', 'compressed.komabk'), Buffer.from(compressed))
 const { migrateLocalBackups } = load(); await migrateLocalBackups(priv, pub)
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'same.json'), 'utf8'), 'new')
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'same-2.json'), 'utf8'), 'old')
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'protected.koma-backup'), 'utf8'), 'encrypted')
 assert.deepEqual(fs.readFileSync(path.join(pub, 'backups', 'compressed.komabk')), Buffer.from(compressed))
 assert.deepEqual(fs.readdirSync(path.join(priv, 'backups')), [])
 fs.unlinkSync(path.join(pub, 'backups', 'same-2.json')); await migrateLocalBackups(priv, pub)
 assert.equal(fs.existsSync(path.join(pub, 'backups', 'same-2.json')), false)
})
test('interrupted copy keeps all originals and retry completes', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-test-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const priv = path.join(root, 'private'), pub = path.join(root, 'public'); fs.mkdirSync(path.join(priv, 'backups'), { recursive: true })
 fs.writeFileSync(path.join(priv, 'backups', 'a.json'), 'first'); fs.writeFileSync(path.join(priv, 'backups', 'b.json'), 'second')
 let count = 0; const broken = load({ copyFile: async (a, b) => { if (++count === 2) throw new Error('disk full'); await fs.promises.copyFile(a, b) } })
 await assert.rejects(broken.migrateLocalBackups(priv, pub), /disk full/)
 assert.deepEqual(fs.readdirSync(path.join(priv, 'backups')).sort(), ['a.json', 'b.json'])
 await load().migrateLocalBackups(priv, pub)
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'a.json'), 'utf8'), 'first')
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'b.json'), 'utf8'), 'second')
 assert.deepEqual(fs.readdirSync(path.join(priv, 'backups')), [])
})
test('a corrupt copy is rejected without deleting its original', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-test-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const priv = path.join(root, 'private'), pub = path.join(root, 'public'); fs.mkdirSync(path.join(priv, 'backups'), { recursive: true })
 fs.writeFileSync(path.join(priv, 'backups', 'a.json'), 'original')
 const broken = load({ copyFile: async (_a, b) => fs.promises.writeFile(b, 'corrupt') })
 await assert.rejects(broken.migrateLocalBackups(priv, pub), /backup_migration_copy_mismatch/)
 assert.equal(fs.readFileSync(path.join(priv, 'backups', 'a.json'), 'utf8'), 'original')
 await load().migrateLocalBackups(priv, pub)
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'a.json'), 'utf8'), 'original')
})
test('compressed files retain unicode and exact positions and reject corrupt gzip', async () => {
 const payload = JSON.stringify({ chapters: Array.from({ length: 200 }, () => ({ title: '漫画🐈', page: 37 })) })
 const plain = await format.encodeBackupFile(payload, { exportedAt: 100, encrypted: false })
 assert.ok(plain.byteLength < Buffer.byteLength(payload))
 assert.deepEqual(format.readBackupFileHeader(plain.slice(0, 16)), { exportedAt: 100, encrypted: false })
 assert.equal(gunzipSync(Buffer.from(plain.slice(16))).toString(), payload)
 assert.equal(await format.decodeBackupFile(plain), payload)
 assert.equal(await format.decodeBackupFile(exactBytes(Buffer.from(payload))), payload)
 await assert.rejects(format.decodeBackupFile(plain.slice(0, -1)))
})
const mihon = evaluate('MihonBackupReader', name => ({
 '@kit.ArkTS': arkTS, './BackupFileFormat': format,
})[name])

test('Mihon backup retains history-only works and exact chapter and source identities', async () => {
 function varint(value) {
  let remaining = BigInt.asUintN(64, BigInt(value))
  const bytes = []
  while (remaining > 127n) {
   bytes.push(Number(remaining & 127n) | 128)
   remaining >>= 7n
  }
  return Buffer.from([...bytes, Number(remaining)])
 }
 const field = (n, value) => Buffer.concat([varint(n * 8), varint(value)])
 function message(n, ...parts) {
  const bytes = Buffer.concat(parts.map(value => Buffer.from(value)))
  return Buffer.concat([varint(n * 8 + 2), varint(bytes.length), bytes])
 }
 const sourceId = 9223372036854775806n
 const time = 1794759125903
 const url = '/work/chapter-16?edition=alternate'
 const work = message(1, field(1, sourceId), message(2, '/work'), message(3, '備份漫畫'),
  message(16, message(1, url), message(2, '第16話'), field(5, 1), field(6, 8)),
  message(17, varint(8), varint(3)), field(17, 5), field(100, 0),
  message(104, message(1, url), field(2, time)), message(110, '讀者筆記'))
 const source = message(101, field(2, sourceId))
 const category = message(2, message(1, '自訂分類'), field(2, 8), field(3, 42))
 const backup = await mihon.readMihonBackup(exactBytes(gzipSync(Buffer.concat([work, source, category]))))
 assert.equal(backup.works[0].favorite, false)
 assert.deepEqual(backup.works[0].categoryIds, ['8', '3', '5'])
 assert.deepEqual(backup.categories, [{ name: '自訂分類', order: 8, id: '42' }])
 assert.equal(backup.works[0].sourceId, '9223372036854775806')
 assert.deepEqual(backup.sources, [{ id: backup.works[0].sourceId, name: '' }])
 assert.equal(backup.works[0].notes, '讀者筆記')
 assert.equal(backup.works[0].chapters[0].pageIndex, 8)
 assert.equal(backup.works[0].chapters[0].bookmarked, true)
 assert.deepEqual(backup.works[0].history[0], { chapterUrl: url, readAt: time, readDuration: 0 })
 await assert.rejects(mihon.readMihonBackup(exactBytes(gzipSync(work.subarray(0, -1)))), /mihon_backup_truncated/)
})

test('Mihon import merges an existing edition and keeps a newer local reading position', () => {
 const models = evaluate('ComicModels', () => ({}))
 const appStrings = { AppStrings: { get: key => key } }
 const migration = evaluate('SourceMangaMigration', () => models)
 const { InMemoryLibraryStore } = evaluate('LibraryStore', name => ({
  './ComicModels': models, '../i18n/AppStrings': appStrings,
  '@kit.ArkTS': { util: { generateRandomUUID: require('node:crypto').randomUUID } },
  './LibrarySmartCategory': evaluate('LibrarySmartCategory', dep =>
   dep === './ComicModels' ? models : appStrings),
 })[name] ?? {})
 const planning = evaluate('MihonImportPlanning', name => ({
  './ComicModels': models, './MangaWebLink': evaluate('MangaWebLink', () => ({})),
  './MangaDetailModels': evaluate('MangaDetailModels', () => ({})),
  './SourceMangaMigration': migration, '../i18n/AppStrings': appStrings,
  '../sourceRuntime/MihonSourceIdentity': evaluate('../sourceRuntime/MihonSourceIdentity', () => ({})),
 })[name] ?? {})
 const work = {
  sourceId: '8212829630734804062', url: '/work/17', title: 'Original title',
  coverUrl: 'https://img.example/work/17.jpg',
  notes: 'Imported note', author: 'Original author', genres: [], status: 1, favorite: true,
  addedAt: 10, modifiedAt: 50, categoryIds: ['0', '8'], tracking: [],
  chapters: [{ url: '/work/17/chapter/6', title: 'Chapter 6', number: 6, scanlator: '', read: true,
   bookmarked: true, pageIndex: 4, fetchedAt: 0, uploadedAt: 0, sourceOrder: 1, modifiedAt: 50 }],
  history: [{ chapterUrl: '/work/17/chapter/6', readAt: 50, readDuration: 1 }],
 }
 const library = new InMemoryLibraryStore()
 const category = library.createCustomCategory('Local category')
 const existing = planning.mihonPlaceholder({ id: 'retained-id', work, categoryIds: [category.id], sourceName: 'Book source' })
 existing.sourceRuntimeId = 'books'
 existing.personalNotes = 'Local note'
 existing.sourcePath = 'source://books/work:17'
 existing.subtitle = 'Locally cached description'
 library.upsertComic(existing)
 const current = { comicId: existing.id, chapterId: work.chapters[0].url, pageIndex: 9, totalPages: 20,
  progressRatio: 0.5, completed: false, updatedAt: 100 }
 const snapshot = { progress: [current], sourceHistory: [], chapterStates: [{
  comicId: existing.id, chapterId: current.chapterId, position: current, isRead: false, bookmarked: false, updatedAt: 100,
 }] }
 const backup = { works: [work], sources: [{ id: work.sourceId, name: 'Book source' }],
  categories: [{ id: '4', name: 'First category', order: 0 },
   { id: '8', name: 'Unassigned category', order: 1 },
   { id: '9', name: 'Later category', order: 8 }] }
 for (let round = 0; round < 2; round++) {
  const merged = planning.importMihonWorks(backup, library)
  assert.equal(planning.mergeMihonReading(snapshot, merged), 0)
 }
 assert.equal(library.listComics().length, 1)
 const result = library.getComic(existing.id)
 assert.equal(result.title, 'Original title')
 assert.equal(result.subtitle, 'Locally cached description')
 assert.equal(result.personalNotes, 'Local note')
 const categoryById = new Map(library.listCustomCategories().map(row => [row.id, row.name]))
 assert.deepEqual(result.categoryIds.map(id => categoryById.get(id)).sort(),
  ['First category', 'Later category', 'Local category'])
 assert.equal(categoryById.size, 4)
 assert.equal(library.listMihonImports()[0].work.chapters[0].pageIndex, 4)
 assert.deepEqual(snapshot.progress, [current])
 assert.equal(snapshot.chapterStates[0].bookmarked, false)
 const differentLanguage = new InMemoryLibraryStore()
 differentLanguage.upsertComic(existing)
 const originalIdentity = { sourceIds: [work.sourceId], work: { pathPrefix: '/work/', idPrefix: 'localized:' } }
 const identities = new Map([['localized-books', originalIdentity]])
 const missing = planning.importMihonWorks(backup, differentLanguage, identities)[0]
 assert.equal(missing.record.targetComicId, undefined)
 assert.equal(missing.target.sourceRuntimeId, 'mihon:' + work.sourceId)
 differentLanguage.upsertComic({ ...existing, id: 'correct-language', sourceRuntimeId: 'localized-books',
  remoteResourceId: 'localized:17' })
 const localized = planning.importMihonWorks(backup, differentLanguage, identities)[0]
 assert.equal(localized.record.targetComicId, 'correct-language')
 assert.equal(localized.identity, originalIdentity)
 assert.equal(differentLanguage.getComic(missing.record.id), undefined)
 assert.ok(differentLanguage.getComic(existing.id))
 const sameName = { id: 'unrelated-edition', sourceId: 'books', title: work.title,
  url: 'https://book.example/work/54', coverUrl: 'https://img.example/work/54.jpg' }
 assert.equal(planning.pickMihonSourceWork(work, [sameName]), undefined)
 const onOriginalSite = { ...sameName, id: 'matching-edition', url: 'https://book.example/work/17' }
 assert.equal(planning.pickMihonSourceWork(work, [sameName, onOriginalSite]), onOriginalSite)
 assert.equal(planning.pickMihonSourceWork(work, [onOriginalSite, { ...onOriginalSite, id: 'second-edition' }]), undefined)
 const aliased = { ...work, title: '學生會也有洞！', description: '簡介提到另一部作品\n***别名**：腦洞學生會*' }
 const shelfEdition = { ...result, title: '腦洞學生會', sourceRuntimeId: 'another-source' }
 const otherWork = { ...result, title: '另一部作品' }
 const unresolved = planning.mihonPlaceholder({ id: 'unresolved', work: aliased, categoryIds: [], sourceName: 'Imported source' })
 assert.deepEqual(planning.suggestedMihonShelfWorks(aliased, [otherWork, unresolved, shelfEdition]), [shelfEdition])
 assert.equal(planning.matchingMihonShelfWork(aliased, 'Book source', [shelfEdition]), undefined)
 const readChapter = { ...work.chapters[0], title: '第6話 続き', read: false }
 const appendix = { ...readChapter, url: '/work/17/appendix/6', title: '附錄6', pageIndex: 0 }
 const chapterProgress = { ...aliased, favorite: false, chapters: [readChapter, appendix] }
 const from = { id: 'unresolved', work: chapterProgress, categoryIds: [], sourceName: 'Imported source' }
 const shelfChapter = { ...result.chapters[0], id: 'serial-6', title: '06話（17P）', pageCount: 17 }
 const shelfVolume = { ...shelfChapter, id: 'volume-6', title: '06卷（174P）', volumeNumber: '06', pageCount: 174 }
 shelfEdition.chapters = [shelfVolume, shelfChapter]
 const resumed = { progress: [], sourceHistory: [], chapterStates: [] }
 planning.mergeMihonReading(resumed, [{ record: from, target: shelfEdition, sameEdition: false }])
 assert.equal(resumed.progress[0].chapterId, 'serial-6')
 assert.equal(resumed.progress[0].pageIndex, 0)
 assert.equal(from.work.chapters[0].pageIndex, 4)
 const savedPage = { ...resumed.progress[0], pageIndex: 11, updatedAt: 10 }
 const currentEdition = { progress: [{ ...savedPage, chapterId: 'older-chapter', updatedAt: 30 }], sourceHistory: [],
  chapterStates: [{ comicId: shelfEdition.id, chapterId: shelfChapter.id, updatedAt: 10, position: savedPage }] }
 planning.mergeMihonReading(currentEdition, [{ record: from, target: shelfEdition, sameEdition: false }])
 assert.equal(currentEdition.progress[0].chapterId, 'serial-6')
 assert.equal(currentEdition.progress[0].pageIndex, 11)
 assert.equal(currentEdition.progress[0].updatedAt, 50)
 const exactChapter = { ...shelfChapter, id: 'chapter:example:17:20' }
 const samePage = { ...shelfEdition, chapters: [exactChapter] }
 const exact = { progress: [], sourceHistory: [], chapterStates: [] }
 const exactImport = { record: from, target: samePage, sameEdition: true,
  identity: { sourceIds: [work.sourceId], work: { pathPrefix: '/', idPrefix: '/' }, samePageOrder: true,
   chapter: { pathPrefix: '/work/', pathSuffix: '/chapter/6', idPrefix: '', targetIdSegment: 2 } } }
 planning.mergeMihonReading(exact, [exactImport])
 assert.equal(exact.progress[0].chapterId, exactChapter.id)
 assert.equal(exact.progress[0].pageIndex, 4)
 const fallback = { ...exact.progress[0], pageIndex: 0, pageId: undefined, totalPages: 0 }
 exact.progress = [fallback]
 exact.chapterStates[0].position = fallback
 planning.mergeMihonReading(exact, [exactImport])
 assert.equal(exact.progress[0].pageIndex, 4)
 const later = { ...fallback, updatedAt: fallback.updatedAt + 1, pageIndex: 1, totalPages: 17 }
 exact.progress = [later]
 exact.chapterStates[0].position = later
 planning.mergeMihonReading(exact, [exactImport])
 assert.equal(exact.progress[0].pageIndex, 1)
})

test('Mihon package rules map the saved path and reject foreign addresses or traversal', () => {
 const identity = evaluate('../sourceRuntime/MihonSourceIdentity', () => ({}))
 const source = { sourceIds: ['7289707411592168382'],
  work: {pathPrefix: '/detail/', pathSuffix: '.html', idPrefix: 'bilimanga:'},
  chapter: {pathPrefix: '/read/', pathSuffix: '.html', idPrefix: 'bilimanga-read:', idSuffix: '.html'} }
 assert.equal(identity.validMihonSourceIdentity(source), true)
 assert.equal(identity.validMihonSourceIdentity({...source, sourceIds: [7289707411592168382]}), false)
 assert.equal(identity.mihonPathIdentity('/detail/917.html', source.work), 'bilimanga:917')
 assert.equal(identity.mihonPathIdentity('/read/917/73015.html', source.chapter), 'bilimanga-read:917/73015.html')
 const query = {pathPrefix: '/comic.php?id=', idPrefix: 'comic:'}
 const bare = {pathPrefix: '', idPrefix: 'comic:'}
 assert.equal(identity.validMihonSourceIdentity({...source, work: query}), true)
 assert.equal(identity.validMihonSourceIdentity({...source, work: bare}), true)
 assert.equal(identity.mihonPathIdentity('/comic.php?id=42', query), 'comic:42')
 assert.equal(identity.mihonPathIdentity('old-site-slug', bare), 'comic:old-site-slug')
 assert.equal(identity.mihonPathIdentity('/comic.php?id=42&next=43', query), undefined)
 assert.equal(identity.mihonPathIdentity('https://other.example/42', bare), undefined)
 const absolute = {pathPrefix: 'https://book.example/comics/', idPrefix: 'book:'}
 assert.equal(identity.validMihonSourceIdentity({...source, work: absolute}), true)
 assert.equal(identity.mihonPathIdentity('https://book.example/comics/42', absolute), 'book:42')
 assert.equal(identity.mihonPathIdentity('https://book.example.fake/comics/42', absolute), undefined)
 assert.equal(identity.mihonPathIdentity('https://book.example/comics/../42', absolute), undefined)
 assert.equal(identity.mihonPathIdentity('42,1', bare), 'comic:42,1')
 const photo = {pathPrefix: '/photo/', idPrefix: '', pathIdSegment: 0, targetIdSegment: 2}
 assert.equal(identity.mihonPathIdentity('/photo/1478353', photo), '1478353')
 assert.equal(identity.mihonPathIdentity('/photo/1478353/', photo), '1478353')
 const catalog = { sourceIds: ['5724751873601868259'], work: { pathPrefix: '/comic/', idPrefix: 'manga:' },
  chapter: { pathPrefix: '/user/page_direct?comic_id=', pathWorkIdSeparator: '&section_slot=0&chapter_slot=',
   idPrefix: '', targetIdSegment: 2 }, samePageOrder: true }
 const address = '/user/page_direct?comic_id=book&section_slot=0&chapter_slot=1242#最终章：再见'
 assert.equal(identity.validMihonSourceIdentity(catalog), true)
 assert.equal(identity.mihonChapterPathIdentity(address, 'manga:book', catalog), '1242')
 assert.equal(identity.mihonTargetChapterId('chapter:book:1242#最終章：再見', catalog.chapter), '1242')
 assert.equal(identity.mihonChapterPathIdentity(address, 'manga:another-book', catalog), undefined)
 assert.equal(identity.mihonChapterPathIdentity(address.replace('section_slot=0', 'section_slot=1'),
  'manga:book', catalog), undefined)
 for (const input of ['https://other.example/detail/917.html', '/detail/../917.html', '/detail/.html']) {
  assert.equal(identity.mihonPathIdentity(input, source.work), undefined)
 }
})

test('a Mihon link waits for existing writes and skips a closed detail', async () => {
 const { BackupRestoreActivity } = evaluate('BackupRestoreActivity', () => ({}))
 let finishWrite
 const writer = BackupRestoreActivity.runWrite(() => new Promise(resolve => { finishWrite = resolve }))
 let current = true
 const closed = BackupRestoreActivity.beginRestoreWhenIdle(() => current)
 const open = BackupRestoreActivity.beginRestoreWhenIdle()
 assert.equal(BackupRestoreActivity.isRestoring(), false)
 current = false
 finishWrite()
 await writer
 assert.equal(await closed, false)
 assert.equal(await open, true)
 assert.equal(BackupRestoreActivity.isRestoring(), true)
 BackupRestoreActivity.finishRestore()
})

test('a failed Mihon import lookup remembers its source and history retries the original address before search', async () => {
 const record = { id: 'original', sourceName: 'Old label', categoryIds: [],
  work: { sourceId: '5183325399429659419', url: '/book/12/', title: 'Saved work' } }
 const source = { sourceId: 'confirmed-source', displayName: 'Current label', enabled: true, capabilities: ['search'] }
 const entry = { sourceId: source.sourceId, enabled: true, mihonImport: {
  sourceIds: [record.work.sourceId], work: { pathPrefix: '/book/', pathSuffix: '/', idPrefix: 'book:' },
 } }
 const registry = { list: () => [entry], listInstalledSourceSummaries: () => [source], lookup: () => ({ entry }) }
 let stored = [record]
 let available = false
 const requests = []
 let titleSearches = 0
 class Store {
  constructor(records = []) { this.records = records }
  listMihonImports() { return this.records.slice() }
  replaceMihonImports(records) { this.records = records.slice() }
  listComics() { return [] }
 }
 class Persistence {
  constructor(library) { this.library = library }
  persist() { stored = JSON.parse(JSON.stringify(this.library.records)) }
 }
 const { MihonImportService } = evaluate('MihonImportService', name => ({
  './LibraryStore': { InMemoryLibraryStore: Store,
   libraryContents: source => source.listMihonImports(),
   replaceLibraryContents: (target, records) => target.replaceMihonImports(records) },
  './LibraryPersistence': { LibraryStorePersistenceService: Persistence, AppFilesLibraryStorePersistenceAdapter: class {} },
  './BackupRestoreActivity': { BackupRestoreActivity: { runWrite: fn => fn() } },
  '../sourceRuntime/SourceRuntimeAppRegistry': { appSourceRuntimeRegistry: registry },
  '../sourceRuntime/MihonSourceIdentity': evaluate('../sourceRuntime/MihonSourceIdentity', () => ({})),
  './MihonImportPlanning': evaluate('MihonImportPlanning', name => ({
   '../sourceRuntime/MihonSourceIdentity': evaluate('../sourceRuntime/MihonSourceIdentity', () => ({})),
   './MangaWebLink': evaluate('MangaWebLink', () => ({})),
  })[name] || {}),
  './SourceMangaMigrationService': { async prepareMangaMigration(_registry, manga) {
   assert.equal(stored[0].matchedSourceId, source.sourceId)
   requests.push(manga)
   if (!available) throw new Error('temporarily unavailable')
   return { comic: { id: 'native-work' } }
  } },
  './SourceRuntimeError': { SourceRuntimeError: class extends Error {} },
  '../viewmodel/BrowseViewModel': { BrowseViewModel: class {
   async searchSource() { titleSearches++; return { manga: [] } }
  } },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {} } },
 })[name] || {})
 const live = new Store(stored)
 const service = new MihonImportService({ filesDir: '/mock' }, live)
 service.commit = async (links, bytes, sourceMatches) => {
  if (sourceMatches !== undefined) {
   assert.equal(links, undefined)
   assert.equal(bytes, undefined)
   assert.equal(sourceMatches.length, 1)
   assert.equal(sourceMatches[0].id, record.id)
   live.replaceMihonImports([{ ...record, matchedSourceId: sourceMatches[0].sourceId, linkedWork: sourceMatches[0].work }])
   new Persistence(live).persist()
   return { unmatchedChapters: 0 }
  }
  assert.equal(links.length, 1)
  assert.equal(links[0].id, record.id)
  assert.equal(links[0].verifiedEdition, true)
  assert.equal(links[0].identity, entry.mihonImport)
  const targetComicId = links[0].target.id
  live.replaceMihonImports([{ ...stored[0], targetComicId }])
  new Persistence(live).persist()
  return { unmatchedChapters: 0, targetComicId }
 }
 assert.equal(await service.matchUnresolved(undefined, true), true)
 assert.equal(stored[0].matchedSourceId, source.sourceId)
 assert.equal(live.listMihonImports()[0].matchedSourceId, source.sourceId)
 assert.equal(stored[0].targetComicId, undefined)
 await service.retryFromHistory(record.id, () => true)
 assert.equal(stored[0].matchedSourceId, source.sourceId)
 assert.equal(stored[0].targetComicId, undefined)
 available = true
 await service.retryFromHistory(record.id, () => true)
 assert.deepEqual(requests.map(({ id, sourceId, title }) => ({ id, sourceId, title })), Array.from({ length: 2 }, () => ({
  id: 'book:12', sourceId: source.sourceId, title: record.work.title,
 })))
 assert.equal(stored[0].targetComicId, 'native-work')
 assert.equal(titleSearches, 0)
 assert.deepEqual(stored[0].work, record.work)
})

if (process.env.KOMA_MIHON_BACKUP_FIXTURE) {
 test('read the supplied Mihon backup without mutating it or logging work titles', async () => {
  const archive = fs.readFileSync(process.env.KOMA_MIHON_BACKUP_FIXTURE)
  const decoded = await mihon.readMihonBackup(exactBytes(archive))
  assert.ok(decoded.works.length > 0)
  assert.ok(decoded.works.every(work => /^-?\d+$/.test(work.sourceId)))
  console.log('Mihon backup totals', {
   works: decoded.works.length, favorites: decoded.works.filter(work => work.favorite).length,
   sources: decoded.sources.length, categories: decoded.categories.length,
   unnamedSources: decoded.sources.filter(source => !source.name).length,
   chapters: decoded.works.reduce((count, work) => count + work.chapters.length, 0),
   nonzeroPages: decoded.works.reduce((count, work) => count + work.chapters.filter(chapter => chapter.pageIndex > 0).length, 0),
   history: decoded.works.reduce((count, work) => count + work.history.length, 0),
  })
 })
}
test('encrypted snapshots protect gzip bytes and still decrypt the legacy envelope', async () => {
 const encryption = evaluate('BackupEncryptionService', name => ({
  '@kit.ArkTS': arkTS, '@kit.CryptoArchitectureKit': {}, './BackupFileFormat': format,
 })[name])
 const service = new encryption.BackupEncryptionService()
 service.randomBytes = size => Uint8Array.from(crypto.randomBytes(size))
 service.deriveKey = async (secret, salt, iterations) => crypto.pbkdf2Sync(secret, salt, iterations, 32, 'sha256')
 service.encryptBytes = async (key, nonce, aad, data) => {
  const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce)
  cipher.setAAD(aad)
  return Uint8Array.from(Buffer.concat([cipher.update(data), cipher.final(), cipher.getAuthTag()]))
 }
 let decryptedBytes
 service.decryptBytes = async (key, nonce, aad, data, tag) => {
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce)
  decipher.setAAD(aad); decipher.setAuthTag(tag)
  decryptedBytes = Buffer.concat([decipher.update(data), decipher.final()])
  return Uint8Array.from(decryptedBytes)
 }
 const payload = '{"readingProgress":"第18话 · 37页"}'
 const passphrase = 'fixture password'
 const envelope = await service.encrypt(payload, passphrase)
 const wrapped = await format.encodeBackupFile(envelope, { exportedAt: 100, encrypted: true })
 assert.equal(format.readBackupFileHeader(wrapped.slice(0, 16)).encrypted, true)
 const decoded = await format.decodeBackupFile(wrapped)
 assert.equal(await service.decrypt(decoded, passphrase), payload)
 assert.equal(gunzipSync(decryptedBytes).toString(), payload)
 await assert.rejects(service.decrypt(decoded, 'wrong password'), /backup_decrypt_failed/)

 const legacy = JSON.parse(envelope)
 legacy.envelopeVersion = 1
 legacy.aad = encryption.backupEncryptedAad(4)
 const b64 = value => Buffer.from(value, 'base64url')
 const key = await service.deriveKey(passphrase, b64(legacy.kdf.salt), legacy.kdf.iterations)
 const protectedText = Buffer.from(await service.encryptBytes(key, b64(legacy.nonce),
  Buffer.from(encryption.canonicalBackupJson(legacy.aad)), Buffer.from(payload)))
 legacy.payload = protectedText.subarray(0, -16).toString('base64url')
 legacy.tag = protectedText.subarray(-16).toString('base64url')
 const restored = await format.decodeBackupFile(exactBytes(Buffer.from(JSON.stringify(legacy))))
 assert.equal(await service.decrypt(restored, passphrase), payload)
})
test('background app-managed backup writes to public directory after migration', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-background-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const priv = path.join(root, 'private'), pub = path.join(root, 'public'); fs.mkdirSync(path.join(priv, 'backups'), { recursive: true }); fs.mkdirSync(pub)
 fs.writeFileSync(path.join(priv, 'backups', 'old.json'), 'legacy')
 fs.writeFileSync(path.join(priv, 'config.json'), JSON.stringify({ backup: { enabled: true, backgroundEnabled: true, lastRunAt: 0, intervalHours: 24, directoryUri: '', retentionCount: 5 } }))
 fs.writeFileSync(path.join(priv, 'snapshot.json'), JSON.stringify({ libraryStore: '{"comics":[]}', readingProgress: 'stale-page' }))
 const fileIo = { accessSync: fs.existsSync, readTextSync: p => fs.readFileSync(p, 'utf8'), access: async p => fs.existsSync(p),
  readText: p => fs.promises.readFile(p, 'utf8'), mkdir: async (p, recursive) => fs.promises.mkdir(p, { recursive }), listFile: p => fs.promises.readdir(p), unlink: p => fs.promises.unlink(p) }
 const deps = {
  '@kit.AbilityKit': { appManager: { getRunningProcessInformation: async () => [], ProcessState: {} } },
  '@kit.CoreFileKit': { fileIo }, './ComicPersonalization': { exportComicCovers: async () => [] },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {}, warn() {}, exception() {} } }, './LibraryStore': { InMemoryLibraryStore: class {} },
  './LibraryPersistence': { prepareLiveLibraryStorage: async () => {}, readLiveLibrarySnapshot: () => '{"comics":[]}' },
  './ReaderSessionStore': { prepareLiveReaderStorage: async () => {}, readLiveReaderSnapshot: () => 'page-3' },
  './OfflineDownloadQueueStore': { readableOfflineDownloadQueuePath: () => path.join(priv, 'queue.json'),
    offlineDownloadQueuePath: () => path.join(priv, 'queue.json'),
    prepareOfflineQueueDatabase: async () => {}, usesOfflineQueueDatabase: () => false,
  },
  './KomaContentStorage': { ensureKomaBackgroundContentStorageBase: async () => pub, hasKomaPublicContentStorage: () => true }, './BackupLocalStorage': load(),
  '../common/Constants': { KOMA_BUNDLE_NAME: 'com.honjow.koma' }, './AutomationStateEpoch': { automationEpoch: () => ({ restoring: false, generation: 1 }), currentAutomationEpoch: () => true },
  './BackupAutomaticDirectory': { writeAutomaticBackupToDirectory: async () => { throw new Error('unexpected external destination') } },
  './BackupFileFormat': format,
  './AppFileTextPersistence': { writeAppTextFile: (p, value) => fs.writeFileSync(p, value) }, './RemoteServerStore': { RemoteServerStore: class {} },
  '../sourceRuntime/SourceRuntimeAppRegistry': { exportInstalledSourcePackages: () => [] },
  './LocalLibraryMetadataService': { exportLocalLibraryMetadataBackupEntries: () => [] },
  './BackgroundMaintenanceContract': { BACKUP_BACKGROUND_WORK_ID: 7102, MAINTENANCE_CONFIG_FILE: 'config.json', BACKUP_SNAPSHOT: 'snapshot.json', BACKUP_BACKGROUND_RESULT: 'result.json' },
 }
 const exports = evaluate('BackgroundMaintenanceWorker', name => deps[name] || {})
 await exports.executeBackgroundMaintenance({ filesDir: priv }, 7102, {}, () => false)
 const names = fs.readdirSync(path.join(pub, 'backups'))
 assert.ok(names.includes('old.json')); const generated = names.find(name => name.startsWith('koma-backup-'))
 assert.ok(generated.endsWith('.komabk'))
 const payload = await format.decodeBackupFile(exactBytes(fs.readFileSync(path.join(pub, 'backups', generated))))
 assert.equal(JSON.parse(payload).readingProgress, 'page-3')
 assert.deepEqual(fs.readdirSync(path.join(priv, 'backups')), [])
})
test('automatic directory retains one mixed-format history and leaves other files alone', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-external-'))
 t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const directory = path.join(root, 'Koma-Backups')
 fs.mkdirSync(directory)
 const at = 1700000000000
 const oldJson = `koma-auto-${at - 2}-${at - 2}.json`
 const oldCompressed = `koma-auto-${at - 3}-${at - 3}.komabk`
 const unrelated = 'personal.json'
 const plain = '{"readingProgress":"page-37"}'
 const bytes = await format.encodeBackupFile(plain, { exportedAt: at, encrypted: false })
 fs.writeFileSync(path.join(directory, oldJson), plain)
 fs.writeFileSync(path.join(directory, oldCompressed), Buffer.from(bytes))
 fs.writeFileSync(path.join(directory, unrelated), plain)
 const automatic = evaluate('BackupAutomaticDirectory', name => ({
  '@kit.CoreFileKit': {
   fileIo: { access: fs.existsSync, mkdir: fs.promises.mkdir, listFile: fs.promises.readdir, unlink: fs.promises.unlink },
   fileShare: { activatePermission: async () => {}, OperationMode: { READ_MODE: 1, WRITE_MODE: 2 } },
   fileUri: { FileUri: class { constructor(uri) { this.path = uri } } },
  },
  './BackupFileFormat': format,
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception(_tag, _event, error) { throw error } } },
 })[name])
 const saved = await automatic.writeAutomaticBackupToDirectory(root, bytes, 2, at)
 assert.ok(saved.endsWith('.komabk'))
 assert.deepEqual(fs.readdirSync(directory).sort(), [oldJson, path.basename(saved), unrelated].sort())
 assert.equal(await format.decodeBackupFile(exactBytes(fs.readFileSync(saved))), plain)
})
test('a previously used public root cannot silently become an empty private backup list', async () => {
 const service = load(); const context = { filesDir: '/private-root', publicBase: '/private-root', publicExpected: true }
 await assert.rejects(service.ensureLocalBackupDirectory(context), /backup_public_storage_unavailable/)
})
