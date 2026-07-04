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

function privateMethodSource(source, methodName) {
  const start = source.indexOf(`private ${methodName}(`)
  assert.notEqual(start, -1, `${methodName} must exist`)
  const next = source.indexOf('\n  private ', start + 1)
  return source.slice(start, next === -1 ? source.length : next)
}

const exportEncryptedBackupSource = privateMethodSource(backupPageSource, 'exportEncryptedBackup')
const exportEncryptedLocalBackupSource = privateMethodSource(backupPageSource, 'exportEncryptedLocalBackup')
const confirmExportBackupSource = privateMethodSource(backupPageSource, 'confirmExportBackup')
const confirmExportLocalBackupSource = privateMethodSource(backupPageSource, 'confirmExportLocalBackup')

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
  'download queue metadata',
  'tracker comic mappings',
]) {
  assert.match(backupServiceSource, new RegExp(domain), `backup status constants must include ${domain}`)
}
assert.match(
  backupServiceSource,
  /backupIncludedDomainLabels\(preferencesValue: BackupContentPreferences = DEFAULT_BACKUP_CONTENT_PREFERENCES\)[\s\S]*normalizeBackupContentPreferences\(preferencesValue\)[\s\S]*if \(normalized\.includeSettings\)[\s\S]*backup_domain_reader_preferences[\s\S]*if \(normalized\.includeDownloadQueue\)[\s\S]*backup_domain_download_queue[\s\S]*if \(normalized\.includeTrackerMappings\)[\s\S]*backup_domain_tracker_mappings/,
  'backup included-domain labels must respect content preferences instead of always showing optional domains',
)
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
  /name === RouteName\.BACKUP_MANAGEMENT[\s\S]*HdsNavDestination\(\)[\s\S]*BackupManagementPage\(\)[\s\S]*\.titleBar\(this\.navDestTitleBarOpts\(AppStrings\.get\('route_backup_management_title'\)\)\)/,
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
  confirmExportBackupSource,
  /showAlertDialog\(\{[\s\S]*backup_unencrypted_confirm_title[\s\S]*backup_unencrypted_confirm_message[\s\S]*backupUnencryptedExportWarning\(\)[\s\S]*backup_unencrypted_confirm_action[\s\S]*this\.exportBackup\(\)/,
  'BackupManagementPage must confirm plaintext picker export before writing an unencrypted backup',
)
assert.match(
  confirmExportLocalBackupSource,
  /showAlertDialog\(\{[\s\S]*backup_unencrypted_confirm_title[\s\S]*backup_unencrypted_local_confirm_message[\s\S]*backupUnencryptedExportWarning\(\)[\s\S]*backup_unencrypted_confirm_action[\s\S]*this\.exportLocalBackup\(\)/,
  'BackupManagementPage must confirm plaintext local backup creation before writing an unencrypted backup',
)
assert.match(
  backupPageSource,
  /backup_export_action[\s\S]*this\.confirmExportBackup\(\)[\s\S]*backup_local_create_action[\s\S]*this\.confirmExportLocalBackup\(\)/,
  'BackupManagementPage unencrypted export buttons must route through confirmation handlers',
)
assert.match(
  backupServiceSource,
  /export const BACKUP_ENCRYPTION_STATE:\s*string = 'unencrypted'[\s\S]*function backupUnencryptedExportWarning\(\): string \{[\s\S]*AppStrings\.get\('backup_unencrypted_warning'\)/,
  'backup service must still label legacy JSON exports through i18n',
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
  backupServiceSource,
  /export const BACKUP_LOCAL_DIR_NAME:\s*string = 'backups'[\s\S]*export interface BackupLocalFileRecord[\s\S]*fileName:\s*string[\s\S]*displayName:\s*string[\s\S]*sizeBytes:\s*number[\s\S]*preview:\s*BackupImportPreview/,
  'backup service must expose local backup records without surfacing absolute sandbox paths',
)
assert.match(
  backupServiceSource,
  /exportLocal\(\): Promise<BackupLocalFileRecord>[\s\S]*writeLocalBackup[\s\S]*exportEncryptedLocal\(passphrase: string\): Promise<BackupLocalFileRecord>[\s\S]*listLocalBackups\(\): Promise<BackupLocalFileRecord\[\]>[\s\S]*renameLocalBackup\(fileName: string, displayName: string\): Promise<BackupLocalFileRecord>[\s\S]*deleteLocalBackup\(fileName: string\): Promise<void>[\s\S]*selectLocalBackup\(fileName: string\): Promise<BackupImportSelectionPreview>/,
  'backup service must support local backup create, list, rename, delete, and preview selection flows',
)
assert.match(
  backupServiceSource,
  /export interface BackupAutomaticPreferences[\s\S]*enabled:\s*boolean[\s\S]*intervalHours:\s*number[\s\S]*retentionCount:\s*number[\s\S]*lastRunAt:\s*number[\s\S]*lastFailureCode:\s*string[\s\S]*DEFAULT_BACKUP_AUTOMATIC_PREFERENCES[\s\S]*enabled:\s*false[\s\S]*intervalHours:\s*24[\s\S]*retentionCount:\s*5/,
  'backup service must define durable automatic backup preferences with conservative defaults',
)
assert.match(
  backupServiceSource,
  /loadAutomaticPreferences\(\): Promise<BackupAutomaticPreferences>[\s\S]*BACKUP_AUTOMATIC_ENABLED_KEY[\s\S]*saveAutomaticPreferences\(preferencesValue: BackupAutomaticPreferences\): Promise<void>[\s\S]*store\.put\(BACKUP_AUTOMATIC_RETENTION_COUNT_KEY, normalized\.retentionCount\)/,
  'backup service must persist automatic backup enabled, interval, retention, and run metadata',
)
assert.match(
  backupServiceSource,
  /export interface BackupContentPreferences[\s\S]*includeSettings:\s*boolean[\s\S]*includeDownloadQueue:\s*boolean[\s\S]*includeTrackerMappings:\s*boolean[\s\S]*DEFAULT_BACKUP_CONTENT_PREFERENCES[\s\S]*includeSettings:\s*true[\s\S]*includeDownloadQueue:\s*true[\s\S]*includeTrackerMappings:\s*true[\s\S]*loadContentPreferences\(\): Promise<BackupContentPreferences>[\s\S]*saveContentPreferences\(preferencesValue: BackupContentPreferences\): Promise<void>[\s\S]*BACKUP_CONTENT_INCLUDE_SETTINGS_KEY[\s\S]*BACKUP_CONTENT_INCLUDE_DOWNLOAD_QUEUE_KEY[\s\S]*BACKUP_CONTENT_INCLUDE_TRACKER_MAPPINGS_KEY/,
  'backup service must persist backup content preferences with settings, download queue metadata, and tracker mappings included by default',
)
assert.match(
  backupServiceSource,
  /const contentPreferences = await this\.loadContentPreferences\(\)[\s\S]*if \(contentPreferences\.includeSettings\) \{[\s\S]*document\.settings = await new ReaderPreferencesStore\(this\.context\)\.load\(\)[\s\S]*document\.sourceIndexUrl = await this\.exportSourceIndexUrl\(\)/,
  'backup export must include reader/settings preferences only when backup content settings allow it',
)
assert.match(
  backupServiceSource,
  /trackerSyncPreferences\?: BackupTrackerSyncPreferences[\s\S]*interface BackupTrackerSyncPreferences \{[\s\S]*autoSyncEnabled: boolean[\s\S]*updateStrategy: TrackerUpdateStrategy/,
  'backup schema may include non-secret tracker sync preferences',
)
assert.match(
  backupServiceSource,
  /const contentPreferences = await this\.loadContentPreferences\(\)[\s\S]*if \(contentPreferences\.includeSettings\) \{[\s\S]*document\.settings = await new ReaderPreferencesStore\(this\.context\)\.load\(\)[\s\S]*document\.sourceIndexUrl = await this\.exportSourceIndexUrl\(\)[\s\S]*document\.trackerSyncPreferences = await this\.exportTrackerSyncPreferences\(\)/,
  'backup export must include tracker sync preferences only with the settings domain',
)
assert.match(
  backupServiceSource,
  /if \(contentPreferences\.includeDownloadQueue\) \{[\s\S]*const downloadQueue = readTextIfExists\(this\.downloadQueuePath\(\), ''\)[\s\S]*document\.downloadQueue = normalizeBackupDownloadQueuePayload\(downloadQueue\)/,
  'backup export must include download queue metadata only when content preferences allow it',
)
assert.match(
  backupServiceSource,
  /if \(contentPreferences\.includeTrackerMappings\) \{[\s\S]*document\.trackerMappings = await this\.exportTrackerMappings\(\)/,
  'backup export must include tracker mappings only when content preferences allow it',
)
assert.match(
  backupServiceSource,
  /exportTrackerSyncPreferences\(\): Promise<BackupTrackerSyncPreferences>[\s\S]*TRACKER_AUTO_SYNC_ENABLED_KEY[\s\S]*TRACKER_UPDATE_STRATEGY_KEY[\s\S]*normalizeTrackerUpdateStrategy\(updateStrategy\)/,
  'backup export must read and normalize tracker sync preference keys',
)
assert.match(
  backupServiceSource,
  /importTrackerSyncPreferences\(preferencesValue: BackupTrackerSyncPreferences \| undefined\): Promise<void>[\s\S]*normalizeBackupTrackerSyncPreferences\(preferencesValue\)[\s\S]*store\.put\(TRACKER_AUTO_SYNC_ENABLED_KEY, normalized\.autoSyncEnabled\)[\s\S]*store\.put\(TRACKER_UPDATE_STRATEGY_KEY, normalized\.updateStrategy\)/,
  'backup import must restore only tracker sync preference keys',
)
assert.match(
  backupServiceSource,
  /await this\.importTrackerMappings\(document\.trackerMappings\)[\s\S]*await this\.importTrackerSyncPreferences\(document\.trackerSyncPreferences\)/,
  'backup import must restore tracker mappings and sync preferences through separate safe paths',
)
assert.match(
  backupServiceSource,
  /runAutomaticLocalBackupIfDue\(now: number = Date\.now\(\)\): Promise<BackupAutomaticRunResult>[\s\S]*skippedReason: 'disabled'[\s\S]*skippedReason: 'not_due'[\s\S]*runAutomaticLocalBackupWithPreferences\(now, preferencesValue\)[\s\S]*runAutomaticLocalBackupNow\(now: number = Date\.now\(\)\): Promise<BackupAutomaticRunResult>/,
  'backup service must support app-open due checks plus an explicit run-now path',
)
assert.match(
  backupServiceSource,
  /runAutomaticLocalBackupWithPreferences[\s\S]*const created = await this\.exportLocal\(\)[\s\S]*const deletedCount = await this\.pruneLocalBackups\(preferencesValue\.retentionCount\)[\s\S]*lastRunAt: normalizeBackupAutomaticLastRunAt\(now\)[\s\S]*lastFailureCode: ''[\s\S]*lastFailureCode: 'backup_auto_export_failed'/,
  'automatic backup must create a local backup, retain only the configured count, and store safe failure codes',
)
assert.match(
  backupServiceSource,
  /pruneLocalBackups\(retentionCount: number\): Promise<number>[\s\S]*normalizeBackupAutomaticRetentionCount\(retentionCount\)[\s\S]*records\.slice\(keepCount\)[\s\S]*deleteLocalBackup\(staleRecords\[index\]\.fileName\)/,
  'automatic backup retention must delete only bounded local backup file records',
)
assert.match(
  backupServiceSource,
  /function isLocalBackupFileName\(fileName: string\): boolean[\s\S]*!fileName\.includes\('\/'\)[\s\S]*!fileName\.includes\('\\\\'\)[\s\S]*fileName\.endsWith\('\.json'\) \|\| fileName\.endsWith\('\.koma-backup'\)[\s\S]*private requireLocalBackupFileName\(fileName: string\): string[\s\S]*throw new Error\('backup_local_file_invalid'\)/,
  'local backup file operations must be bounded to safe backup file names',
)
assert.match(
  backupServiceSource,
  /preview\(json: string\): BackupImportPreview \{[\s\S]*isEncryptedBackupPayload\(json\)[\s\S]*emptyEncryptedCountsPreview\(previewEncryptedBackupEnvelope\(json\)\)[\s\S]*private readLocalBackupRecord\(fileName: string\): BackupLocalFileRecord \| undefined[\s\S]*preview: this\.preview\(payload\)/,
  'local encrypted backup list preview must use public encrypted-envelope metadata until passphrase verification',
)
assert.match(
  backupPageSource,
  /private EncryptionCard\(\)[\s\S]*backupEncryptionStatusLabel\(\)[\s\S]*KomaFormTextField\(\{[\s\S]*value: this\.exportPassphrase[\s\S]*isPassword: true[\s\S]*backup_export_encrypted_action/,
  'BackupManagementPage must surface functional encrypted export controls with password input',
)
assert.match(
  exportEncryptedBackupSource,
  /const passphrase = this\.exportPassphrase[\s\S]*exportEncryptedToPicker\(passphrase\)[\s\S]*\.finally\(\(\) => \{[\s\S]*this\.exportPassphrase = ''[\s\S]*this\.exportPassphraseConfirm = ''[\s\S]*this\.busy = false/,
  'encrypted picker export must clear export passphrases in finally, including failure and cancellation paths',
)
assert.doesNotMatch(
  exportEncryptedBackupSource,
  /this\.importPassphrase = ''/,
  'encrypted picker export must not clear import passphrase state',
)
assert.match(
  exportEncryptedLocalBackupSource,
  /const passphrase = this\.exportPassphrase[\s\S]*exportEncryptedLocal\(passphrase\)[\s\S]*\.finally\(\(\) => \{[\s\S]*this\.exportPassphrase = ''[\s\S]*this\.exportPassphraseConfirm = ''[\s\S]*this\.busy = false/,
  'encrypted local export must clear export passphrases in finally, including failure paths',
)
assert.doesNotMatch(
  exportEncryptedLocalBackupSource,
  /this\.importPassphrase = ''/,
  'encrypted local export must not clear import passphrase state',
)
assert.match(
  backupPageSource,
  /localBackups: BackupLocalFileRecord\[\][\s\S]*loadLocalBackups\(\)[\s\S]*listLocalBackups\(\)[\s\S]*exportLocalBackup\(\)[\s\S]*exportLocal\(\)[\s\S]*exportEncryptedLocalBackup\(\)[\s\S]*exportEncryptedLocal\(passphrase\)/,
  'BackupManagementPage must load and create local backup records',
)
assert.match(
  backupPageSource,
  /contentPreferences: BackupContentPreferences = DEFAULT_BACKUP_CONTENT_PREFERENCES[\s\S]*loadContentPreferences\(\)[\s\S]*this\.backupService\(\)\.loadContentPreferences\(\)[\s\S]*ContentPreferenceSwitchRow[\s\S]*aboutToAppear\(\): void \{[\s\S]*this\.loadContentPreferences\(\)/,
  'BackupManagementPage included-data card must reflect saved backup content preferences',
)
assert.match(
  backupPageSource,
  /saveContentPreferences\(preferencesValue: BackupContentPreferences\)[\s\S]*this\.backupService\(\)\.saveContentPreferences\(preferencesValue\)[\s\S]*this\.contentPreferences = preferencesValue/,
  'BackupManagementPage must persist included-data preferences from the management page',
)
assert.match(
  backupPageSource,
  /setBackupIncludeSettings\(includeSettings: boolean\)[\s\S]*includeSettings,[\s\S]*includeDownloadQueue: this\.contentPreferences\.includeDownloadQueue[\s\S]*includeTrackerMappings: this\.contentPreferences\.includeTrackerMappings/,
  'BackupManagementPage must expose a settings-domain include toggle backed by content preferences',
)
assert.match(
  backupPageSource,
  /setBackupIncludeDownloadQueue\(includeDownloadQueue: boolean\)[\s\S]*includeSettings: this\.contentPreferences\.includeSettings[\s\S]*includeDownloadQueue,[\s\S]*includeTrackerMappings: this\.contentPreferences\.includeTrackerMappings/,
  'BackupManagementPage must expose a download-queue include toggle backed by content preferences',
)
assert.match(
  backupPageSource,
  /setBackupIncludeTrackerMappings\(includeTrackerMappings: boolean\)[\s\S]*includeSettings: this\.contentPreferences\.includeSettings[\s\S]*includeDownloadQueue: this\.contentPreferences\.includeDownloadQueue[\s\S]*includeTrackerMappings/,
  'BackupManagementPage must expose a tracker-mapping include toggle backed by content preferences',
)
assert.match(
  backupPageSource,
  /ContentPreferenceSwitchRow\(label: string, checked: boolean, onChange: \(isOn: boolean\) => void\)[\s\S]*Toggle\(\{ type: ToggleType\.Switch, isOn: checked \}\)[\s\S]*onChange\(isOn\)/,
  'BackupManagementPage content preferences must use real switches instead of static text or menus',
)
assert.match(
  backupPageSource,
  /backupIncludedDomainLabels\(\{[\s\S]*includeSettings: false,[\s\S]*includeDownloadQueue: false,[\s\S]*includeTrackerMappings: false,[\s\S]*ContentPreferenceSwitchRow\([\s\S]*backup_domain_reader_preferences[\s\S]*setBackupIncludeSettings[\s\S]*backup_domain_download_queue[\s\S]*setBackupIncludeDownloadQueue[\s\S]*backup_domain_tracker_mappings[\s\S]*setBackupIncludeTrackerMappings/,
  'BackupManagementPage included-data card must show core domains plus switchable optional domains',
)
assert.match(
  settingsPageSource,
  /pane === 'backup'[\s\S]*backup-include-settings[\s\S]*backup-include-download-queue[\s\S]*backup-include-tracker-mappings/,
  'Settings backup pane must expose all backup content preference switches',
)
assert.match(
  backupPageSource,
  /autoPreferences: BackupAutomaticPreferences = DEFAULT_BACKUP_AUTOMATIC_PREFERENCES[\s\S]*loadAutomaticPreferences\(\)[\s\S]*saveAutomaticPreferences\(preferencesValue: BackupAutomaticPreferences\)[\s\S]*setAutomaticBackupEnabled\(enabled: boolean\)/,
  'BackupManagementPage must load and save real automatic backup preferences',
)
assert.match(
  backupPageSource,
  /private AutomaticBackupCard\(\)[\s\S]*Toggle\(\{ type: ToggleType\.Switch, isOn: this\.autoPreferences\.enabled \}\)[\s\S]*backup_auto_interval_label[\s\S]*AutomaticIntervalMenu\(\)[\s\S]*backup_auto_retention_label[\s\S]*AutomaticRetentionMenu\(\)[\s\S]*runAutomaticBackupNow\(\)/,
  'BackupManagementPage must expose automatic backup as a switch plus interval, retention, and run-now controls',
)
assert.match(
  backupPageSource,
  /aboutToAppear\(\): void \{[\s\S]*this\.loadLocalBackups\(\)[\s\S]*this\.loadAutomaticPreferences\(\)/,
  'BackupManagementPage must load automatic backup settings alongside local backups',
)
assert.match(
  backupPageSource,
  /selectLocalBackup\(record: BackupLocalFileRecord\)[\s\S]*selectLocalBackup\(record\.fileName\)[\s\S]*selectedEncryptedBackupPayload[\s\S]*selectedBackupPreview[\s\S]*startRenameLocalBackup[\s\S]*renameLocalBackup\(fileName, displayName\)[\s\S]*confirmDeleteLocalBackup[\s\S]*deleteLocalBackup\(fileName\)/,
  'BackupManagementPage must allow local backup preview, rename, and delete without picker round-trips',
)
assert.match(
  settingsPageSource,
  /\{ key: 'backup-auto-export', titleKey: 'settings_row_backup_auto_export_title', detailKey: 'settings_row_backup_auto_export_detail' \}[\s\S]*row\.key === 'backup' \|\| row\.key === 'backup-auto-export'[\s\S]*this\.onOpenBackupManagement\(\)/,
  'Settings automatic backup row must open the real backup management page instead of remaining a placeholder',
)
assert.match(
  settingsPageSource,
  /\{ key: 'backup-include-settings', titleKey: 'settings_row_backup_include_settings_title', detailKey: 'settings_row_backup_include_settings_detail' \}[\s\S]*loadBackupContentPreferences\(\)[\s\S]*row\.key === 'backup-include-settings'[\s\S]*saveBackupIncludeSettings\(value\)/,
  'Settings backup include row must be a real switch backed by backup content preferences',
)
assert.match(
  settingsPageSource,
  /\{ key: 'backup-include-download-queue', titleKey: 'settings_row_backup_include_download_queue_title', detailKey: 'settings_row_backup_include_download_queue_detail' \}[\s\S]*includeBackupDownloadQueue: boolean = DEFAULT_BACKUP_CONTENT_PREFERENCES\.includeDownloadQueue[\s\S]*row\.key === 'backup-include-download-queue'[\s\S]*saveBackupIncludeDownloadQueue\(value\)/,
  'Settings backup download queue include row must be a real switch backed by backup content preferences',
)
assert.match(
  settingsPageSource,
  /\{ key: 'backup-include-tracker-mappings', titleKey: 'settings_row_backup_include_tracker_mappings_title', detailKey: 'settings_row_backup_include_tracker_mappings_detail' \}[\s\S]*includeBackupTrackerMappings: boolean = DEFAULT_BACKUP_CONTENT_PREFERENCES\.includeTrackerMappings[\s\S]*row\.key === 'backup-include-tracker-mappings'[\s\S]*saveBackupIncludeTrackerMappings\(value\)/,
  'Settings backup tracker mappings include row must be a real switch backed by backup content preferences',
)
assert.doesNotMatch(
  settingsPageSource,
  /\{ key: 'backup-include-settings'[^}]*placeholder:\s*true/,
  'Settings backup include row must not remain a placeholder',
)
assert.doesNotMatch(
  settingsPageSource,
  /\{ key: 'backup-include-download-queue'[^}]*placeholder:\s*true/,
  'Settings backup download queue include row must not remain a placeholder',
)
assert.doesNotMatch(
  settingsPageSource,
  /\{ key: 'backup-include-tracker-mappings'[^}]*placeholder:\s*true/,
  'Settings backup tracker mappings include row must not remain a placeholder',
)
assert.match(
  indexSource,
  /import \{ BackupService, BackupAutomaticRunResult \} from '\.\.\/model\/BackupService'[\s\S]*automaticBackupChecked: boolean = false[\s\S]*triggerAutomaticBackup\(context: common\.UIAbilityContext\)[\s\S]*new BackupService\(context\)\.runAutomaticLocalBackupIfDue\(\)[\s\S]*this\.triggerAutomaticBackup\(context\)/,
  'Index must trigger app-open automatic backup due checks after bootstrap',
)
assert.match(
  backupPageSource,
  /private LocalBackupRow\(record: BackupLocalFileRecord\)[\s\S]*backupLocalFileDetailText\(record\)[\s\S]*backup_local_preview_action[\s\S]*backup_local_rename_action[\s\S]*backup_local_delete_action[\s\S]*private LocalBackupsCard\(\)[\s\S]*backup_local_create_action[\s\S]*backup_local_create_encrypted_action[\s\S]*backup_local_empty/,
  'BackupManagementPage must render local backup list actions and metadata',
)
assert.match(
  backupPageSource,
  /showInfoDialog\([\s\S]*t\('backup_dialog_exported_title'\)[\s\S]*backupUnencryptedExportWarning\(\)/,
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
  /selectedEncryptedBackupPayload[\s\S]*KomaFormTextField\(\{[\s\S]*value: this\.importPassphrase[\s\S]*isPassword: true[\s\S]*backup_decrypt_preview_action/,
  'BackupManagementPage must require passphrase before encrypted import preview',
)
assert.match(
  backupServiceSource,
  /async importFromPicker\(\): Promise<boolean>[\s\S]*result\.length === 0[\s\S]*return false[\s\S]*await this\.import\(payload\)[\s\S]*return true/,
  'BackupService.importFromPicker must return false on picker cancellation and true only after restore',
)
assert.match(
  backupPageSource,
  /selectImportPreviewFromPicker\(\)[\s\S]*selectedBackupPayload[\s\S]*selectedBackupPreview[\s\S]*restoreSelectedBackup\(\)[\s\S]*showAlertDialog\(\{[\s\S]*backup_restore_confirm_title[\s\S]*restoreConfirmationMessage\(preview\)[\s\S]*backup_restore_confirm_action[\s\S]*runRestoreSelectedBackup\(\)[\s\S]*importPromise[\s\S]*backupService\(\)\.import\(this\.selectedBackupPayload\)[\s\S]*this\.showInfoDialog\(t\('backup_dialog_imported_title'\)/,
  'BackupManagementPage must preview picker-selected backups and require confirmation before restore',
)
assert.match(
  backupPageSource,
  /restoreConfirmationMessage\(preview: BackupImportPreview\): string[\s\S]*backup_restore_confirm_message[\s\S]*preview\.libraryConflictCount[\s\S]*preview\.progressConflictCount[\s\S]*backupImportConflictPolicy\(\)/,
  'BackupManagementPage restore confirmation must include conflict counts and restore policy',
)
assert.match(
  backupPageSource,
  /backupManagementStorageNote\(\)/,
  'BackupManagementPage must explain picker-selected files are user-managed',
)
assert.match(
  backupServiceSource,
  /export interface BackupImportPreview[\s\S]*schemaVersion:\s*number[\s\S]*exportedAtText:\s*string[\s\S]*encryptionText:\s*string[\s\S]*libraryItemCount:\s*number[\s\S]*progressCount:\s*number[\s\S]*currentLibraryItemCount:\s*number[\s\S]*currentProgressCount:\s*number[\s\S]*libraryConflictCount:\s*number[\s\S]*progressConflictCount:\s*number[\s\S]*settingsCount:\s*number[\s\S]*categoryCount:\s*number[\s\S]*downloadQueueCount:\s*number[\s\S]*trackerMappingCount:\s*number[\s\S]*sourcePackageCount:\s*number/,
  'backup import preview must expose version, exportedAt, encryption state, core counts, and restore conflict counts',
)
assert.match(
  backupServiceSource,
  /preview\(json: string\): BackupImportPreview[\s\S]*isEncryptedBackupPayload\(json\)[\s\S]*previewDocument\(json, false\)[\s\S]*readTextIfExists\(this\.libraryPath\(\), emptyLibraryStorePayload\(\)\)[\s\S]*readTextIfExists\(this\.readerProgressPath\(\), emptyReaderProgressPayload\(\)\)[\s\S]*libraryConflictCount: overlapCount\(backupComicIds, currentComicIds\)[\s\S]*progressConflictCount: overlapCount\(backupProgressComicIds, currentProgressComicIds\)/,
  'backup preview must detect encrypted envelopes, keep v1/v2/v3 compatibility, and compare restore data with current local state',
)
assert.match(
  backupPageSource,
  /SelectedPreviewCard\(preview: BackupImportPreview\)[\s\S]*backup_preview_current_library_items[\s\S]*backup_preview_library_conflicts[\s\S]*backup_preview_current_progress[\s\S]*backup_preview_progress_conflicts/,
  'BackupManagementPage must show current local counts and restore overlap counts before restore',
)
assert.match(
  backupServiceSource,
  /settingsCount: countReaderPreferences\(document\.settings\) \+ countBackupTrackerSyncPreferences\(document\.trackerSyncPreferences\)/,
  'backup preview settings count must include tracker sync preferences when present',
)
assert.match(
  backupServiceSource,
  /OFFLINE_DOWNLOAD_QUEUE_FILE_NAME[\s\S]*downloadQueue\?: string[\s\S]*normalizeBackupDownloadQueuePayload[\s\S]*DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES[\s\S]*document\.downloadQueue = normalizeBackupDownloadQueuePayload\(downloadQueue\)/,
  'backup export must include normalized download queue metadata when present',
)
assert.match(
  backupServiceSource,
  /downloadQueueCount: countBackupDownloadQueueEntries\(document\.downloadQueue\)[\s\S]*hasDownloadQueueCount: document\.downloadQueue !== undefined/,
  'backup preview must expose download queue count only when queue metadata is present',
)
assert.match(
  backupServiceSource,
  /importDownloadQueue\(document\.downloadQueue\)[\s\S]*normalizeBackupDownloadQueuePayload\(downloadQueue\)[\s\S]*writeText\(this\.downloadQueuePath\(\), payload\)/,
  'backup import must restore normalized download queue metadata under app files',
)
assert.match(
  backupServiceSource,
  /normalizeOfflineDownloadFailureReasonCode[\s\S]*const failureReasonCode = normalizeOfflineDownloadFailureReasonCode\(normalizeBackupString\(row\['failureReasonCode'\]\)\)/,
  'backup import must reuse the offline download failure allowlist before writing queue metadata back to disk',
)
assert.match(
  backupPageSource,
  /backup_restore_selected_action[\s\S]*backupImportPreviewNote\(\)[\s\S]*backupImportConflictPolicy\(\)/,
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
