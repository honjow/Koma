const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const read = path => readFileSync(resolve(__dirname, '../entry/src/main/ets', path), 'utf8')

function evaluate(source, globals) {
  const js = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
  const exports = {}
  new Function('exports', ...Object.keys(globals), js)(exports, ...Object.values(globals))
  return exports
}

const source = read('pages/BackupManagementPage.ets')
const pageLogic = (source.slice(0, source.indexOf('  @Builder')) + '\n}')
  .replace(/^import[\s\S]*?from '[^']+'\n/gm, '').replace('@ComponentV2', '')
  .replace(/@(Local|Param|Event) /g, '').replace(/@Monitor\('[^']+'\)/g, '')
  .replace('export struct', 'export class')
const { BackupManagementPage } = evaluate(pageLogic, {
  Scroller: class {}, connectLayoutSafeArea: () => ({}),
  BackupManagementState: class {},
  DEFAULT_BACKUP_AUTOMATIC_PREFERENCES: { enabled: false },
  DEFAULT_BACKUP_CONTENT_PREFERENCES: {}, AppStrings: { get: key => key, format: key => key },
  connectLanguageState: () => ({}),
  DiagnosticLogger: { error() {}, warn() {} },
  synchronizeBackgroundMaintenance: async () => {},
  BACKUP_PASSPHRASE_MIN_LENGTH: 8, komaDialogMaterial: () => undefined, DialogAlignment: { Center: 0 },
  backupUnencryptedExportWarning: () => "Unencrypted export",
  $r: () => ({}),
  console: { info() {} },
})
const drain = async () => { for (let i = 0; i < 30; i++) await Promise.resolve() }

function fixture() {
  const calls = [], page = new BackupManagementPage(), ui = {}
  const service = {
    refreshLocalBackupList: async () => {},
    loadAutomaticPreferences: async () => ({ enabled: true }),
    saveAutomaticPreferences: async patch => { calls.push(patch); return patch },
    loadContentPreferences: async () => ({}),
    exportLocal: async () => { calls.push('local') },
    exportEncryptedLocal: async passphrase => { calls.push(['encrypted local', passphrase]) },
    exportToPicker: async () => { calls.push('new file'); return undefined },
    exportEncryptedToPicker: async passphrase => { calls.push(['encrypted new file', passphrase]); return undefined },
    exportLocalCopyToPicker: async (fileName, passphrase) => { calls.push([fileName, passphrase]); return undefined },
    selectImportPreviewFromPicker: async () => undefined,
    selectLocalBackup: async fileName => {
      calls.push(fileName)
      return { payload: 'encrypted fixture', preview: { encrypted: true, decrypted: false } }
    },
    decryptPreview: async () => ({ payload: 'decrypted fixture', preview: { encrypted: true, decrypted: true } }),
    importDecrypted: async payload => { calls.push(['restore decrypted', payload]) },
  }
  page.active = true
  page.context = () => ({})
  page.getUIContext = () => ({
    getPromptAction: () => ({
      openCustomDialog: async options => { ui.dialog = options; return 1 },
      closeCustomDialog: () => ui.dialog.onDidDisappear(),
    }),
    showAlertDialog: options => { ui.alert = options },
  })
  page.backupService = () => service
  page.showToast = message => calls.push(message)
  page.showInfoDialog = title => calls.push(title)
  return { page, service, calls, ui }
}

async function run() {
  const { page, service, calls, ui } = fixture()
  // The reported regression was the native switch sending the hydrated value
  // on mount. A real edit should persist once, even before the first write settles.
  assert.equal(page.automaticPreferencesState, 'loading')
  page.setAutomaticBackupEnabled(true)
  page.onRefreshRevision(); await drain()
  assert.equal(page.autoPreferences.enabled, true)
  page.setAutomaticBackupEnabled(true)
  assert.deepEqual(calls, [])
  page.setAutomaticBackupEnabled(false)
  page.setAutomaticBackupEnabled(false)
  await drain()
  assert.deepEqual(calls.splice(0), [{ enabled: false }, 'backup_auto_saved_toast'])

  page.openSaveDialog()
  page.submitBackupSave()
  page.submitBackupSave()
  await drain()
  assert.deepEqual(calls.splice(0), ['local', 'backup_local_saved_toast'])

  page.openSaveDialog()
  page.encryptBackup = true
  page.exportPassphrase = 'secure test value'
  page.exportPassphraseConfirm = 'different value'
  page.submitBackupSave()
  assert.equal(page.passphraseError, 'backup_passphrase_mismatch')
  assert.deepEqual(calls, [])
  page.exportPassphraseConfirm = page.exportPassphrase
  page.submitBackupSave(); await drain()
  assert.deepEqual(calls.splice(0), [['encrypted local', 'secure test value'], 'backup_local_saved_toast'])
  assert.equal(page.backupDialogShown, false)

  page.openSaveDialog()
  page.saveToFile = true
  page.submitBackupSave()
  await drain()
  assert.deepEqual(calls.splice(0), ['new file'], 'direct export does not generate a local record')
  assert.equal(page.backupDialogShown, true)
  page.encryptBackup = true
  page.exportPassphrase = page.exportPassphraseConfirm = 'secure test value'
  page.submitBackupSave(); await drain()
  assert.deepEqual(calls.splice(0), [['encrypted new file', 'secure test value']])
  page.closeBackupDialog()

  page.openSaveDialog('chosen.json')
  page.encryptBackup = true
  page.exportPassphrase = page.exportPassphraseConfirm = 'secure test value'
  page.submitBackupSave(); await drain()
  assert.deepEqual(calls.splice(0), [['chosen.json', 'secure test value']])
  assert.equal(page.backupDialogShown, true, 'canceling the save picker leaves the dialog available')
  page.closeBackupDialog()
  assert.equal(page.exportPassphrase, '')

  page.importBackup(); await drain()
  assert.equal(page.backupDialogShown, false, 'canceling the picker never opens a blank restore view')
  page.selectLocalBackup({ fileName: 'local.koma-backup', displayName: 'Local', preview: { exportedAt: 1 } }); await drain()
  assert.equal(page.backupDialog, 'restore')
  assert.equal(page.selectedBackupName, 'Local')
  assert.equal(page.selectedBackupPayload, '', 'encrypted data cannot be restored before decryption')
  page.importPassphrase = 'secure test value'
  page.decryptSelectedBackup(); await drain()
  assert.equal(page.selectedBackupPreview.decrypted, true)
  assert.deepEqual(calls.splice(0), ['local.koma-backup'])
  page.runRestoreSelectedBackup(); await drain()
  assert.deepEqual(calls.splice(0), [['restore decrypted', 'decrypted fixture'], 'backup_dialog_imported_title'])
  assert.equal(page.backupDialogShown, false)
  assert.equal(page.selectedBackupPayload, '')

  const saved = []
  const backupSource = read('model/BackupService.ets')
  const copy = backupSource.slice(backupSource.indexOf('  async exportLocalCopyToPicker('),
    backupSource.indexOf('  private async saveBackupToPicker('))
  const { CopyService } = evaluate('export class CopyService { ' + copy + ' }', {
    backupFileExtension: name => name.endsWith('.json') ? '.json' : '.koma-backup',
    BackupEncryptionService: class { async encrypt(payload, password) { return [payload, password] } },
  })
  const copyService = new CopyService()
  copyService.requireLocalBackupFileName = name => name
  copyService.selectLocalBackup = async fileName => {
    saved.push(fileName)
    return { payload: 'earlier snapshot', preview: { encrypted: false } }
  }
  copyService.saveBackupToPicker = async (...args) => { saved.push(args); return 'saved' }
  assert.equal(await copyService.exportLocalCopyToPicker('earlier.json', 'test secret'), 'saved')
  assert.deepEqual(saved, ['earlier.json', [['earlier snapshot', 'test secret'], 'earlier.koma-backup', true]])
  copyService.selectLocalBackup = async () => ({ payload: 'existing envelope', preview: { encrypted: true } })
  await copyService.exportLocalCopyToPicker('renamed.json')
  assert.deepEqual(saved.at(-1), ['existing envelope', 'renamed.koma-backup', true])
  await assert.rejects(copyService.exportLocalCopyToPicker('renamed.json', 'test secret'), /backup_already_encrypted/)
}

async function testLocalListSnapshot() {
  const backupSource = read('model/BackupService.ets')
  const state = backupSource.slice(backupSource.indexOf('interface CachedLocalBackupFile'),
    backupSource.indexOf('export interface BackupAutomaticPreferences'))
    .replace('@ObservedV2', '').replaceAll('@Trace ', '')
  const list = backupSource.slice(backupSource.indexOf('  managementState()'),
    backupSource.indexOf('  async renameLocalBackup('))
  const files = new Map()
  const reads = []
  let listing
  const { ListService } = evaluate(state + 'export class ListService { ' + list + ' }', {
    ensureDir() {},
    isLocalBackupFileName: name => name.endsWith('.json'),
    DiagnosticLogger: { error() {} },
    fs: {
      listFile: async () => listing ? listing() : [...files.keys()],
      stat: async path => files.get(path).stat,
      readText: async path => { reads.push(path); return files.get(path).payload },
    },
  })
  const open = (directory = 'backups') => {
    const service = new ListService()
    service.localBackupsDir = () => directory
    service.localBackupPath = fileName => fileName
    service.localBackupFilePreview = JSON.parse
    service.localBackupRecord = (fileName, sizeBytes, preview) => ({ fileName, sizeBytes, preview })
    return service
  }
  const fixtureFile = (ino, exportedAt) => ({
    stat: { ino, size: 100, mtimeNs: BigInt(exportedAt), ctimeNs: BigInt(exportedAt) },
    payload: JSON.stringify({ exportedAt, encrypted: false }),
  })

  const first = open()
  const snapshot = first.managementState()
  assert.equal(snapshot.records, undefined)
  await first.refreshLocalBackupList()
  assert.deepEqual(snapshot.records, [])
  files.set('older.json', fixtureFile(1n, 1))
  files.set('newer.json', fixtureFile(2n, 2))
  await first.refreshLocalBackupList()
  assert.deepEqual(snapshot.records.map(record => record.fileName), ['newer.json', 'older.json'])

  const reopened = open()
  const retained = snapshot.records
  assert.equal(reopened.managementState().records, retained)
  assert.equal(open('other').managementState().records, undefined)
  await reopened.refreshLocalBackupList()
  assert.equal(snapshot.records, retained)
  assert.deepEqual(reads, ['older.json', 'newer.json'])

  listing = async () => { throw new Error('cannot list') }
  await reopened.refreshLocalBackupList()
  assert.equal(snapshot.failed, true)
  assert.equal(snapshot.records, retained)

  let finishOldScan
  listing = () => new Promise(resolve => { finishOldScan = resolve })
  const olderScan = first.refreshLocalBackupList()
  listing = undefined
  files.delete('newer.json')
  files.set('older.json', fixtureFile(3n, 3))
  await reopened.refreshLocalBackupList()
  finishOldScan(['newer.json'])
  await olderScan
  assert.deepEqual(snapshot.records.map(record => record.preview.exportedAt), [3])
  assert.deepEqual(reads, ['older.json', 'newer.json', 'older.json'])
  assert.equal(snapshot.failed, false)
}

run().then(testLocalListSnapshot).then(() => console.log('Backup workflow state OK')).catch(error => {
  console.error(error); process.exitCode = 1
})
