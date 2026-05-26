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
  /exportToPicker\(\)[\s\S]*importFromPicker\(\)/,
  'BackupManagementPage must expose export and import actions',
)
assert.match(
  backupServiceSource,
  /async importFromPicker\(\): Promise<boolean>[\s\S]*result\.length === 0[\s\S]*return false[\s\S]*await this\.import\(payload\)[\s\S]*return true/,
  'BackupService.importFromPicker must return false on picker cancellation and true only after restore',
)
assert.match(
  backupPageSource,
  /importFromPicker\(\)[\s\S]*\.then\(\(restored: boolean\) => \{[\s\S]*if \(restored\) \{[\s\S]*this\.showInfoDialog\('备份已导入'/,
  'BackupManagementPage must show import success only when a restore actually happened',
)
assert.match(
  backupPageSource,
  /BACKUP_MANAGEMENT_STORAGE_NOTE/,
  'BackupManagementPage must explain picker-selected files are user-managed',
)
const safeStatusAndDocs = [
  backupServiceSource.match(/export const BACKUP_INCLUDED_DOMAINS[\s\S]*?export const BACKUP_MANAGEMENT_STORAGE_NOTE[^\n]*/)?.[0] ?? '',
  backupPageSource,
  progressDocSource.match(/D6 Backup Management UI[\s\S]*?(?=\n## |\n### |$)/)?.[0] ?? '',
].join('\n')
assert.doesNotMatch(
  safeStatusAndDocs,
  /\b(password|passwd|token|secret|cookie|credential|authorization|apikey|apiKey|api_key)\b/i,
  'backup status/docs must not include credential-like keys',
)
assert.match(
  backupServiceSource,
  /if \(document\.schemaVersion !== BACKUP_SCHEMA_VERSION &&[\s\S]*document\.schemaVersion !== BACKUP_SCHEMA_VERSION_V2 &&[\s\S]*document\.schemaVersion !== BACKUP_SCHEMA_VERSION_V1\)/,
  'backup restore must continue accepting schema v1/v2/v3',
)

console.log('backup management checks PASS')
