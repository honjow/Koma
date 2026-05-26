import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const backupServiceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/BackupService.ets'), 'utf8')
const backupPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/BackupManagementPage.ets'), 'utf8')
const settingsPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets'), 'utf8')
const indexSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8')
const constantsSource = readFileSync(resolve(root, 'entry/src/main/ets/common/Constants.ets'), 'utf8')
const progressDocSource = readFileSync(resolve(root, 'docs/FEATURE_PROGRESS_20260524.md'), 'utf8')

assert.match(
  backupServiceSource,
  /export const BACKUP_SCHEMA_VERSION:\s*number = 3/,
  'backup status must expose current schema v3',
)
assert.match(
  backupServiceSource,
  /export const BACKUP_ACCEPTED_SCHEMA_VERSIONS:[\s\S]*BACKUP_SCHEMA_VERSION_V1[\s\S]*BACKUP_SCHEMA_VERSION_V2[\s\S]*BACKUP_SCHEMA_VERSION/,
  'backup compatibility status must mention schema v1/v2/v3 restore support',
)
for (const domain of [
  'library',
  'progress',
  'remote servers',
  'source packages and sanitized source settings',
  'reader and settings preferences',
]) {
  assert.match(backupServiceSource, new RegExp(domain), `backup status constants must include ${domain}`)
}
assert.match(
  backupPageSource,
  /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20 \+ ThemeConstants\.SPACE_XL/,
  'BackupManagementPage must use SecondaryListScaffold with floating tab clearance',
)
assert.doesNotMatch(
  backupPageSource,
  /(Navigation|NavDestination)\(/,
  'BackupManagementPage must not nest a Navigation/NavDestination inside Settings',
)
assert.match(
  settingsPageSource,
  /onOpenBackupManagement:\s*\(\) => void/,
  'SettingsPage must accept a backup management route callback',
)
assert.match(
  settingsPageSource,
  /row\.key === 'backup'[\s\S]*this\.onOpenBackupManagement\(\)/,
  'Settings backup row must open the management page',
)
assert.match(
  indexSource,
  /import \{ BackupManagementPage \} from '\.\/BackupManagementPage'/,
  'Index must import BackupManagementPage',
)
assert.match(
  constantsSource,
  /static readonly BACKUP_MANAGEMENT: string = 'BackupManagementPage'/,
  'RouteName must include BackupManagementPage',
)
assert.match(
  indexSource,
  /name === RouteName\.BACKUP_MANAGEMENT[\s\S]*HdsNavDestination\(\)[\s\S]*BackupManagementPage\(\)[\s\S]*\.titleBar\(this\.navDestTitleBarOpts\('备份与恢复'\)\)/,
  'Index must render backup management as a top-level HDS destination',
)
assert.match(
  indexSource,
  /onOpenBackupManagement:\s*\(\) => \{[\s\S]*this\.openSettingsSecondary\(RouteName\.BACKUP_MANAGEMENT\)/,
  'Index must wire Settings backup callback to the top-level route',
)
assert.match(
  backupPageSource,
  /exportToPicker\(\)[\s\S]*selectImportPreviewFromPicker\(\)[\s\S]*restoreSelectedBackup\(\)/,
  'BackupManagementPage must expose export, import preview, and explicit restore actions',
)
assert.match(
  backupServiceSource,
  /export const BACKUP_ENCRYPTION_STATE:\s*string = 'unencrypted'[\s\S]*export const BACKUP_UNENCRYPTED_EXPORT_WARNING:[^\n]*未加密 JSON/,
  'backup service must still label legacy JSON exports as unencrypted JSON',
)
assert.match(
  backupServiceSource,
  /encryption:\s*\{[\s\S]*state:\s*BACKUP_ENCRYPTION_STATE[\s\S]*algorithm:\s*'none'[\s\S]*\}/,
  'plaintext backup document inside legacy export or encrypted payload must carry explicit unencrypted metadata',
)
assert.match(
  backupServiceSource,
  /exportEncrypted\(passphrase: string\)[\s\S]*BackupEncryptionService\(\)\.encrypt/,
  'backup service must route encrypted exports through BackupEncryptionService',
)
assert.match(
  backupPageSource,
  /private EncryptionCard\(\)[\s\S]*BACKUP_ENCRYPTION_STATUS_LABEL[\s\S]*TextInput\(\{ text: this\.exportPassphrase[\s\S]*InputType\.Password[\s\S]*导出加密备份/,
  'BackupManagementPage must surface functional encrypted export controls with password input',
)
assert.match(
  backupPageSource,
  /showInfoDialog\('备份已导出',[\s\S]*BACKUP_UNENCRYPTED_EXPORT_WARNING/,
  'BackupManagementPage must warn successful exports are unencrypted',
)
assert.doesNotMatch(
  backupPageSource,
  /showInfoDialog\('[^']*失败',\s*error\.message\)/,
  'BackupManagementPage failure dialogs must not surface raw Error.message details',
)
for (const code of [
  'backup_export_failed',
  'backup_preview_failed',
  'backup_decrypt_failed',
  'backup_import_failed',
]) {
  assert.match(backupPageSource, new RegExp(`code=${code}`), `BackupManagementPage must retain safe log code ${code}`)
}
assert.match(
  backupPageSource,
  /selectedEncryptedBackupPayload[\s\S]*TextInput\(\{ text: this\.importPassphrase[\s\S]*InputType\.Password[\s\S]*解密并预览/,
  'BackupManagementPage must require passphrase before encrypted import preview',
)
assert.match(
  backupServiceSource,
  /async importFromPicker\(\): Promise<boolean>[\s\S]*result\.length === 0[\s\S]*return false[\s\S]*await this\.import\(payload\)[\s\S]*return true/,
  'BackupService.importFromPicker must return false on picker cancellation and true only after restore',
)
assert.match(
  backupPageSource,
  /selectImportPreviewFromPicker\(\)[\s\S]*selectedBackupPayload[\s\S]*selectedBackupPreview[\s\S]*restoreSelectedBackup\(\)[\s\S]*importPromise[\s\S]*backupService\(\)\.import\(this\.selectedBackupPayload\)[\s\S]*this\.showInfoDialog\('备份已导入'/,
  'BackupManagementPage must preview picker-selected backups before explicit restore',
)
assert.match(
  backupPageSource,
  /BACKUP_MANAGEMENT_STORAGE_NOTE/,
  'BackupManagementPage must explain picker-selected files are user-managed',
)
assert.match(
  backupServiceSource,
  /export interface BackupImportPreview[\s\S]*schemaVersion:\s*number[\s\S]*exportedAtText:\s*string[\s\S]*encryptionText:\s*string[\s\S]*libraryItemCount:\s*number[\s\S]*progressCount:\s*number[\s\S]*settingsCount:\s*number[\s\S]*categoryCount:\s*number[\s\S]*downloadQueueCount:\s*number[\s\S]*trackerMappingCount:\s*number[\s\S]*sourcePackageCount:\s*number/,
  'backup import preview must expose version, exportedAt, encryption state, and core counts',
)
assert.match(
  backupServiceSource,
  /preview\(json: string\): BackupImportPreview[\s\S]*isEncryptedBackupPayload\(json\)[\s\S]*previewDocument\(json, false\)[\s\S]*formatBackupEncryption\(document\.encryption\)[\s\S]*libraryItemCount:[\s\S]*progressCount:/,
  'backup preview must detect encrypted envelopes and keep v1/v2/v3 compatibility',
)
assert.match(
  backupPageSource,
  /恢复所选备份[\s\S]*BACKUP_IMPORT_PREVIEW_NOTE[\s\S]*BACKUP_IMPORT_CONFLICT_POLICY/,
  'BackupManagementPage must state preview/conflict policy and require a separate restore action',
)
const safeStatusAndDocs = [
  backupServiceSource.match(/export const BACKUP_INCLUDED_DOMAINS[\s\S]*?export const BACKUP_MANAGEMENT_STORAGE_NOTE[^\n]*/)?.[0] ?? '',
  backupPageSource,
  progressDocSource.match(/D6 Backup Management UI[\s\S]*?(?=\n## |\n### |$)/)?.[0] ?? '',
].join('\n')
assert.doesNotMatch(
  safeStatusAndDocs,
  /\b(passwd|token|secret|cookie|credential|authorization|apikey|apiKey|api_key)\b/i,
  'backup status/docs must not include raw credential-like keys',
)
assert.match(
  backupServiceSource,
  /function isAcceptedPlaintextSchemaVersion[\s\S]*schemaVersion === BACKUP_SCHEMA_VERSION[\s\S]*schemaVersion === BACKUP_SCHEMA_VERSION_V2[\s\S]*schemaVersion === BACKUP_SCHEMA_VERSION_V1/,
  'backup restore must continue accepting schema v1/v2/v3',
)
assert.doesNotMatch(
  backupServiceSource.match(/async import\(json: string\): Promise<void> \{[\s\S]*?console\.info\('\[Backup\] step=import_json'\)/)?.[0] ?? '',
  /document\.encryption/,
  'backup restore must not require new encryption metadata so v1/v2/v3 schema restores stay compatible',
)
assert.doesNotMatch(
  backupPageSource,
  /showInfoDialog\('(?:导出失败|预览失败|导入失败)',\s*error\.message\)/,
  'BackupManagementPage must not expose raw native/provider/filesystem errors in user-visible non-decrypt failure dialogs',
)
for (const code of ['backup_export_failed', 'backup_preview_failed', 'backup_import_failed']) {
  assert.match(
    backupPageSource,
    new RegExp(`backupFailureMessage\\('${code}'\\)`),
    `BackupManagementPage must show neutral user-visible message with ${code}`,
  )
}

console.log('backup management checks PASS')
