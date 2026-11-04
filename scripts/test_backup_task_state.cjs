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
  DEFAULT_BACKUP_AUTOMATIC_PREFERENCES: { enabled: false },
  DEFAULT_BACKUP_CONTENT_PREFERENCES: {}, AppStrings: { get: key => key, format: key => key },
  connectLanguageState: () => ({}),
  DiagnosticLogger: { error() {}, warn() {} },
  synchronizeBackgroundMaintenance: async () => {},
  console: { info() {} },
})
const drain = async () => { for (let i = 0; i < 30; i++) await Promise.resolve() }

function fixture() {
  const calls = [], page = new BackupManagementPage()
  const service = {
    listLocalBackups: async () => [],
    loadAutomaticPreferences: async () => ({ enabled: true }),
    saveAutomaticPreferences: async patch => { calls.push(patch); return patch },
    loadContentPreferences: async () => ({}),
    exportLocal: async () => { calls.push('local') },
    exportEncryptedLocal: async passphrase => { calls.push(['encrypted local', passphrase]) },
    exportLocalCopyToPicker: async (fileName, passphrase) => { calls.push([fileName, passphrase]); return undefined },
    selectImportPreviewFromPicker: async () => undefined,
    selectLocalBackup: async fileName => {
      calls.push(fileName)
      return { payload: 'encrypted fixture', preview: { encrypted: true, decrypted: false } }
    },
    decryptPreview: async () => ({ payload: 'decrypted fixture', preview: { encrypted: true, decrypted: true } }),
    importDecrypted: async payload => { calls.push(['restore decrypted', payload]) },
  }
  page.context = () => ({})
  page.backupService = () => service
  page.showToast = message => calls.push(message)
  page.showInfoDialog = title => calls.push(title)
  return { page, service, calls }
}

async function run() {
  const { page, service, calls } = fixture()
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

  page.createLocalBackup()
  page.createLocalBackup()
  await drain()
  assert.deepEqual(calls.splice(0), ['local', 'backup_local_saved_toast'])

  page.openEncryptionPrompt()
  page.exportPassphrase = 'secure test value'
  page.exportPassphraseConfirm = 'different value'
  page.submitEncryptedBackup()
  assert.deepEqual(calls.splice(0), ['backup_dialog_export_blocked_title'])
  page.exportPassphraseConfirm = page.exportPassphrase
  page.submitEncryptedBackup(); await drain()
  assert.deepEqual(calls.splice(0), [['encrypted local', 'secure test value'], 'backup_local_saved_toast'])
  assert.equal(page.backupModalShown, false)

  page.openEncryptionPrompt('chosen.json')
  page.exportPassphrase = 'secure test value'
  page.exportPassphraseConfirm = page.exportPassphrase
  page.submitEncryptedBackup(); await drain()
  assert.deepEqual(calls.splice(0), [['chosen.json', 'secure test value']])
  assert.equal(page.backupModalShown, true, 'canceling the save picker leaves the prompt available')
  page.clearEncryptionPrompt()
  assert.equal(page.exportPassphrase, '')

  page.backupModalShown = false
  page.importBackup(); await drain()
  assert.equal(page.backupModalShown, false, 'canceling the picker never opens a blank restore view')
  page.selectLocalBackup({ fileName: 'local.koma-backup', displayName: 'Local', preview: { exportedAt: 1 } }); await drain()
  assert.equal(page.backupModal, 'restore')
  assert.equal(page.selectedBackupName, 'Local')
  assert.equal(page.selectedBackupPayload, '', 'encrypted data cannot be restored before decryption')
  page.importPassphrase = 'secure test value'
  page.decryptSelectedBackup(); await drain()
  assert.equal(page.selectedBackupPreview.decrypted, true)
  assert.deepEqual(calls.splice(0), ['local.koma-backup'])
  page.runRestoreSelectedBackup(); await drain()
  assert.deepEqual(calls.splice(0), [['restore decrypted', 'decrypted fixture'], 'backup_dialog_imported_title'])
  assert.equal(page.backupModalShown, false)
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

run().then(() => console.log('Backup workflow state OK')).catch(error => { console.error(error); process.exitCode = 1 })
