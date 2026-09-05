const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '../entry/src/main/ets')
const read = path => readFileSync(resolve(root, path), 'utf8')
function evaluate(source, globals) {
  const js = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
  const exports = {}
  new Function('exports', ...Object.keys(globals), js)(exports, ...Object.values(globals))
  return exports
}
const source = read('pages/BackupManagementPage.ets')
const appear = source.slice(source.lastIndexOf('  aboutToAppear(): void {'), source.lastIndexOf('\n}'))
const plain = (source.slice(0, source.indexOf('  @Builder')) + appear + '\n}')
  .replace(/import[\s\S]*?from '[^']+'\n/g, '').replace('@ComponentV2', '')
  .replace(/@(Local|Param|Event) /g, '').replace(/@Monitor\('[^']+'\)/g, '')
  .replace('export struct', 'export class')
const globals = {
  DEFAULT_BACKUP_AUTOMATIC_PREFERENCES: {}, DEFAULT_BACKUP_CONTENT_PREFERENCES: {},
  AppStrings: { get: key => key, format: key => key }, connectLanguageState: () => ({}),
  console: { info() {}, warn() {}, error() {} },
  backupEncryptedExportSuccess: () => 'encrypted success', backupUnencryptedExportWarning: () => 'plaintext warning',
}
const { BackupManagementPage } = evaluate(plain, globals)
const drain = async () => { for (let i = 0; i < 30; i++) await Promise.resolve() }
function fixture() {
  const calls = [], page = new BackupManagementPage()
  const service = {
    listLocalBackups: async () => { calls.push('files'); return [] },
    loadAutomaticPreferences: async () => { calls.push('automatic'); return {} },
    loadContentPreferences: async () => { calls.push('content'); return {} },
    selectImportPreviewFromPicker: async () => undefined,
    selectLocalBackup: async fileName => { calls.push(fileName); return {
      payload: 'encrypted fixture', preview: { encrypted: true, decrypted: false },
    } },
    decryptPreview: async () => ({ payload: 'decrypted fixture', preview: { encrypted: true, decrypted: true } }),
    import: async payload => { calls.push(['plain', payload]) },
    importDecrypted: async payload => { calls.push(['decrypted', payload]) },
    exportEncryptedToPicker: async () => { calls.push('encrypted picker'); return undefined },
  }
  page.backupService = () => service
  page.showToast = () => {}
  page.showInfoDialog = title => calls.push(title)
  return { page, service, calls }
}
async function run() {
  const dispatch = fixture().page, selected = []
  assert.equal(dispatch.createLocal, false); assert.equal(dispatch.createEncrypted, true)
  for (const method of ['confirmExportBackup', 'exportEncryptedBackup', 'confirmExportLocalBackup', 'exportEncryptedLocalBackup']) {
    dispatch[method] = () => selected.push(method)
  }
  for (const [local, encrypted] of [[false, false], [false, true], [true, false], [true, true]]) {
    dispatch.createLocal = local; dispatch.createEncrypted = encrypted; dispatch.createBackup()
  }
  assert.deepEqual(selected, ['confirmExportBackup', 'exportEncryptedBackup', 'confirmExportLocalBackup', 'exportEncryptedLocalBackup'])
  dispatch.busy = true; dispatch.createBackup(); assert.equal(selected.length, 4)

  const f = fixture(), p = f.page
  p.pane = 'create'; p.exportPassphrase = 'draft'; p.exportPassphraseConfirm = 'draft'
  p.onRefreshRevision(); await drain()
  assert.deepEqual(f.calls, ['content']); assert.equal(p.exportPassphrase, 'draft')
  f.calls.length = 0; p.exportEncryptedBackup(); await drain()
  assert.deepEqual(f.calls, ['backup_dialog_export_blocked_title'], 'original passphrase validation prevents export')
  f.calls.length = 0
  for (const pane of ['home', 'files']) { p.pane = pane; p.onRefreshRevision(); await drain() }
  assert.deepEqual(f.calls, ['files', 'automatic', 'files', 'automatic'])
  f.calls.length = 0; p.pane = 'restore'; p.localFileName = 'fixture.koma-backup'
  p.aboutToAppear(); await drain(); p.aboutToAppear(); p.onRefreshRevision(); await drain()
  assert.deepEqual(f.calls, ['fixture.koma-backup'], 'local file read only once, not on returning')
  assert.equal(p.selectedEncryptedBackupPayload, 'encrypted fixture')
  p.importPassphrase = 'passphrase'; p.decryptSelectedBackup(); await drain()
  assert.equal(p.selectedBackupPreview.encrypted, true); assert.equal(p.selectedBackupPreview.decrypted, true)
  p.onRefreshRevision(); await drain()
  assert.equal(p.selectedBackupPayload, 'decrypted fixture')
  p.runRestoreSelectedBackup(); await drain()
  assert.deepEqual(f.calls[1], ['decrypted', 'decrypted fixture'])
  assert.equal(p.selectedBackupPayload, ''); assert.equal(p.selectedBackupPreview, undefined)
  p.selectedBackupPayload = 'plain fixture'; p.selectedBackupPreview = { encrypted: false, decrypted: false }
  p.runRestoreSelectedBackup(); await drain()
  assert.ok(f.calls.some(call => Array.isArray(call) && call[0] === 'plain'))
  p.selectedBackupPayload = 'old'; p.selectedEncryptedBackupPayload = 'old encrypted'; p.importPassphrase = 'old'
  p.importBackup(); await drain()
  assert.equal(p.selectedBackupPayload, ''); assert.equal(p.selectedEncryptedBackupPayload, '')
  assert.equal(p.selectedBackupPreview, undefined); assert.equal(p.importPassphrase, '')

  const index = read('pages/Index.ets'), constants = read('common/Constants.ets')
  const methods = index.slice(index.indexOf('  private openBackupTask('), index.indexOf('  private trackerProviderTitle('))
  const routeName = constants.match(/BACKUP_TASK: string = '([^']+)'/)[1]
  const { RouteFixture } = evaluate(`export class RouteFixture { ${methods} }`, {
    ...globals, RouteName: { BACKUP_TASK: routeName },
  })
  const route = new RouteFixture(), routes = []
  route.appPathStack = { pushPath: value => routes.push(value) }
  route.openBackupTask('restore', 'renamed.koma-backup')
  assert.deepEqual(routes, [{ name: routeName, param: { pane: 'restore', fileName: 'renamed.koma-backup' } }])
  assert.equal(route.backupTaskTitle(routes[0].param), 'backup_task_restore')
  const destinations = index.slice(index.indexOf('} else if (name === RouteName.BACKUP_MANAGEMENT)'),
    index.indexOf('} else if (name === RouteName.TRACKER_SETTINGS)'))
  const shown = [...destinations.matchAll(/\.onShown\(\(\) => \{([^}]+)\}\)/g)]
  assert.equal(shown.length, 2)
  const state = { backupSettingsRevision: 0 }
  shown.forEach(match => new Function(match[1]).call(state))
  assert.equal(state.backupSettingsRevision, 2)
  assert.ok(source.includes("this.onOpenTask('restore', record.fileName)"))
  const create = source.slice(source.indexOf('private CreateActions('), source.indexOf('private ContentSummaryCard('))
  assert.ok(create.includes("kind: 'primary', fullWidth: true") && create.includes('this.createBackup()'))
  assert.ok(source.includes("Text(t('backup_passphrase_recovery_warning'))"))
  assert.ok(source.includes("Text(t('backup_auto_plaintext_note'))"))
  const restoreActions = source.slice(source.indexOf('private RestoreActions('), source.indexOf('private AutomaticIntervalMenu('))
  assert.ok(!restoreActions.includes('KomaFormTextField('), 'restore input is not drawn in the card-external action area')
  assert.ok(restoreActions.indexOf('this.decryptSelectedBackup()') < restoreActions.indexOf('this.importBackup()'))
  assert.ok(restoreActions.indexOf('this.restoreSelectedBackup()') < restoreActions.indexOf('this.importBackup()'))
  const restorePane = source.slice(source.indexOf("} else if (this.pane === 'restore') {"),
    source.indexOf("} else if (this.pane === 'files') {"))
  assert.ok(restorePane.indexOf('this.RestorePassphraseCard()') < restorePane.indexOf('this.RestoreActions()'))
  assert.ok(source.includes("trailingText: t(this.showTechnicalDetails ? 'common_collapse' : 'common_expand')"))
  assert.ok(source.includes("trailingText: t(this.showPreviewDetails ? 'common_collapse' : 'common_expand')"))
  const technical = source.slice(source.indexOf('private TechnicalDetailsCard('), source.indexOf('private StatusCard('))
  const status = source.slice(source.indexOf('private StatusCard('), source.indexOf('private CreateFormCard('))
  assert.ok(!technical.includes('Text(backupEncryptionPlanLabel())') && status.includes('Text(backupEncryptionPlanLabel())'),
    'encryption mechanism belongs inside the existing version/compatibility information card')
  console.log('PASS: Backup production task dispatch, routing, refresh/draft retention, local selection, picker cancellation and decrypted/plain restore. Source layout checks are not device visual acceptance.')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
