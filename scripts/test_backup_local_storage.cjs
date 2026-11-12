const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const crypto = require('node:crypto')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const src = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/BackupLocalStorage.ets'), 'utf8')
const js = ts.transpileModule(src, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
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
 const exports = {}
 const requireMock = name => name === '@kit.CoreFileKit' ? { fileIo, hash } :
  name === './KomaContentStorage' ? { ensureKomaContentStorageBase: async context => context.publicBase,
   hasKomaPublicContentStorage: context => context.publicExpected === true } : {}
 new Function('exports', 'require', js)(exports, requireMock)
 return exports
}
test('migrate preserves old backups, resolves conflicting names, and does not repeat deleted records', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-test-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const priv = path.join(root, 'private'), pub = path.join(root, 'public')
 fs.mkdirSync(path.join(priv, 'backups'), { recursive: true }); fs.mkdirSync(path.join(pub, 'backups'), { recursive: true })
 fs.writeFileSync(path.join(priv, 'backups', 'same.json'), 'old'); fs.writeFileSync(path.join(pub, 'backups', 'same.json'), 'new')
 fs.writeFileSync(path.join(priv, 'backups', 'protected.koma-backup'), 'encrypted')
 const { migrateLocalBackups } = load(); await migrateLocalBackups(priv, pub)
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'same.json'), 'utf8'), 'new')
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'same-2.json'), 'utf8'), 'old')
 assert.equal(fs.readFileSync(path.join(pub, 'backups', 'protected.koma-backup'), 'utf8'), 'encrypted')
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
test('background app-managed backup writes to public directory after migration', async t => {
 const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-backup-background-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }))
 const priv = path.join(root, 'private'), pub = path.join(root, 'public'); fs.mkdirSync(path.join(priv, 'backups'), { recursive: true }); fs.mkdirSync(pub)
 fs.writeFileSync(path.join(priv, 'backups', 'old.json'), 'legacy')
 fs.writeFileSync(path.join(priv, 'config.json'), JSON.stringify({ backup: { enabled: true, backgroundEnabled: true, lastRunAt: 0, intervalHours: 24, directoryUri: '', retentionCount: 5 } }))
 fs.writeFileSync(path.join(priv, 'snapshot.json'), JSON.stringify({ libraryStore: '{"comics":[]}', readingProgress: 'page-3' }))
 const fileIo = { accessSync: fs.existsSync, readTextSync: p => fs.readFileSync(p, 'utf8'), access: async p => fs.existsSync(p),
  readText: p => fs.promises.readFile(p, 'utf8'), mkdir: async (p, recursive) => fs.promises.mkdir(p, { recursive }), listFile: p => fs.promises.readdir(p), unlink: p => fs.promises.unlink(p) }
 const deps = {
  '@kit.AbilityKit': { appManager: { getRunningProcessInformation: async () => [], ProcessState: {} } },
  '@kit.CoreFileKit': { fileIo }, './ComicPersonalization': { exportComicCovers: async () => [] },
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {}, warn() {} } }, './LibraryStore': { InMemoryLibraryStore: class {} },
  './LibraryPersistence': { LIBRARY_STORE_PERSISTENCE_FILE_NAME: 'library.json' }, './ReaderSessionStore': { READER_PROGRESS_PERSISTENCE_FILE_NAME: 'progress.json' },
  './OfflineDownloadQueueStore': { readableOfflineDownloadQueuePath: () => path.join(priv, 'queue.json') },
  './KomaContentStorage': { ensureKomaBackgroundContentStorageBase: async () => pub, hasKomaPublicContentStorage: () => true }, './BackupLocalStorage': load(),
  '../common/Constants': { KOMA_BUNDLE_NAME: 'com.honjow.koma' }, './AutomationStateEpoch': { automationEpoch: () => ({ restoring: false, generation: 1 }), currentAutomationEpoch: () => true },
  './BackupAutomaticDirectory': { writeAutomaticBackupToDirectory: async () => { throw new Error('unexpected external destination') } },
  './AppFileTextPersistence': { writeAppTextFile: (p, value) => fs.writeFileSync(p, value) }, './RemoteServerStore': { RemoteServerStore: class {} },
  '../sourceRuntime/SourceRuntimeAppRegistry': { exportInstalledSourcePackages: () => [] },
  './LocalLibraryMetadataService': { exportLocalLibraryMetadataBackupEntries: () => [] },
  './BackgroundMaintenanceContract': { BACKUP_BACKGROUND_WORK_ID: 7102, MAINTENANCE_CONFIG_FILE: 'config.json', BACKUP_SNAPSHOT: 'snapshot.json', BACKUP_BACKGROUND_RESULT: 'result.json' },
 }
 const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/BackgroundMaintenanceWorker.ets'), 'utf8')
 const compiled = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
 const exports = {}; new Function('exports', 'require', compiled)(exports, name => deps[name] || {})
 await exports.executeBackgroundMaintenance({ filesDir: priv }, 7102, {}, () => false)
 const names = fs.readdirSync(path.join(pub, 'backups'))
 assert.ok(names.includes('old.json')); const generated = names.find(name => name.startsWith('koma-backup-'))
 assert.ok(generated); assert.equal(JSON.parse(fs.readFileSync(path.join(pub, 'backups', generated), 'utf8')).readingProgress, 'page-3')
 assert.deepEqual(fs.readdirSync(path.join(priv, 'backups')), [])
})
test('a previously used public root cannot silently become an empty private backup list', async () => {
 const service = load(); const context = { filesDir: '/private-root', publicBase: '/private-root', publicExpected: true }
 await assert.rejects(service.ensureLocalBackupDirectory(context), /backup_public_storage_unavailable/)
})
