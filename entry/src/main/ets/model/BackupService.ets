import { BACKUP_BACKGROUND_RESULT, BackgroundBackupResult } from './BackgroundMaintenanceContract'
import { localLibraryFolderRootUrisFromComics } from './LocalLibraryFolderContract'
import { InMemoryLibraryStore } from './LibraryStore'
import { hydrateLibraryStoreFromJson } from './LibraryPersistence'
import { writeAutomaticBackupToDirectory, releaseAutomaticBackupDirectory } from './BackupAutomaticDirectory'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { ApplicationSettingsBackup, checkedApplicationSettingsBackup, exportApplicationSettings,
  importApplicationSettings, countApplicationSettings, reloadApplicationSettingsRuntime } from './ApplicationSettingsBackup'
import { writeAppTextFile } from './AppFileTextPersistence'
import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { preferences } from '@kit.ArkData'
import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { beginAutomationRestore, finishAutomationRestore, resetGeneratedAutomationWork } from './AutomationStateEpoch'
import { connectAppForegroundState } from '../state/AppForegroundState'
import { RemoteServerStore, REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, parseRemoteServerEndpointIdentities, rememberRemoteServerEndpointIdentity } from './RemoteServerStore'
import { BackupRestoreCheckpoint } from './BackupRestoreCheckpoint'
import {
  LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION,
  assertValidLibraryStoreJson,
} from './LibraryPersistence'
import {
  READER_PROGRESS_PERSISTENCE_FILE_NAME,
  READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
  appReaderSessionStore,
  normalizeReaderSessionBackupPayload,
} from './ReaderSessionStore'
import {
  DEFAULT_READER_PREFERENCES,
  ReaderPreferences,
  ReaderPreferencesStore,
} from './ReaderPreferencesStore'
import {
  SourcePackageBackupEntry,
  exportInstalledSourcePackages,
  prepareSourcePackagesFromBackup,
  PreparedSourcePackageRestore,
  restoreInstalledSourcePackagesAfterBackup,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
  configureSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { appSourceSettingObservationStore } from '../sourceRuntime/SourceSettingObservationStore'
import { SourceSettingObservationSources, checkedSourceSettingObservationSources } from '../sourceRuntime/SourceSettingObservations'
import {
  SourceFilterPreferenceSourceRecord,
  appSourceFilterPreferencesStore,
  configureSourceFilterPreferencesStore,
} from '../sourceRuntime/SourceFilterPreferencesStore'
import {
  BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION,
  BACKUP_PASSPHRASE_MIN_LENGTH,
  BackupEncryptedPublicPreview,
  BackupEncryptionService,
  isEncryptedBackupPayload,
  previewEncryptedBackupEnvelope,
} from './BackupEncryptionService'
import {
  OFFLINE_DOWNLOAD_ROOT_DIR_NAME,
  OfflineDownloadStatus,
} from './OfflineDownloadStore'
import {
  DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES,
  OFFLINE_DOWNLOAD_QUEUE_FILE_NAME,
  OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS,
  OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
  OfflineDownloadQueueEntry,
  OfflineDownloadQueuePreferences,
  normalizeOfflineDownloadFailureReasonCode,
} from './OfflineDownloadQueueStore'
import {
  LocalLibraryMetadataBackupEntry,
  exportLocalLibraryMetadataBackupEntries,
  restoreLocalLibraryMetadataBackupEntries,
} from './LocalLibraryMetadataService'
import {
  DEFAULT_TRACKER_PREFERENCES,
  TrackerPreferencesStore,
  TRACKER_AUTO_SYNC_ENABLED_KEY,
  TRACKER_COMIC_MAPPINGS_KEY,
  TRACKER_PREFERENCES_STORE_NAME,
  TRACKER_UPDATE_STRATEGY_KEY,
  ComicTrackerMapping,
  TrackerUpdateStrategy,
  normalizeComicTrackerMappings,
  normalizeTrackerUpdateStrategy,
} from './TrackerModels'

export const BACKUP_SCHEMA_VERSION: number = 3
export const BACKUP_ENCRYPTED_SCHEMA_VERSION: number = BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION
export const BACKUP_SCHEMA_VERSION_V2: number = 2
export const BACKUP_SCHEMA_VERSION_V1: number = 1
export const BACKUP_ACCEPTED_SCHEMA_VERSIONS: number[] = [
  BACKUP_SCHEMA_VERSION_V1,
  BACKUP_SCHEMA_VERSION_V2,
  BACKUP_SCHEMA_VERSION,
]
export const BACKUP_INCLUDED_DOMAINS: string[] = [
  'library',
  'progress',
  'remote servers',
  'source packages and sanitized source settings',
  'reader and settings preferences',
  'download queue metadata',
  'tracker comic mappings',
]
export const BACKUP_ENCRYPTION_STATE: string = 'unencrypted'
export const BACKUP_LOCAL_DIR_NAME: string = 'backups'
export const BACKUP_AUTOMATIC_INTERVAL_HOUR_OPTIONS: number[] = [24, 72, 168]
export const BACKUP_AUTOMATIC_RETENTION_COUNT_OPTIONS: number[] = [3, 5, 10]
const REMOTE_SERVER_STORE_NAME: string = 'koma_remote_servers_v1'
const SOURCE_INDEX_PREFS_STORE_NAME: string = 'koma_source_package_manager_v1'
const BACKUP_AUTOMATIC_PREFS_STORE_NAME: string = 'koma_backup_automatic_v1'
const BACKUP_CONTENT_PREFS_STORE_NAME: string = 'koma_backup_content_v1'
const BACKUP_AUTOMATIC_DIRECTORY_MODES_KEY: string = 'backup.automatic.directoryOwnedModes'
const BACKUP_AUTOMATIC_DIRECTORY_KEY: string = 'backup.automatic.directoryUri'
const BACKUP_AUTOMATIC_BACKGROUND_KEY: string = 'backup.automatic.backgroundEnabled'
const BACKUP_AUTOMATIC_ENABLED_KEY: string = 'backup.automatic.enabled'
const BACKUP_AUTOMATIC_INTERVAL_HOURS_KEY: string = 'backup.automatic.intervalHours'
const BACKUP_AUTOMATIC_RETENTION_COUNT_KEY: string = 'backup.automatic.retentionCount'
const BACKUP_AUTOMATIC_LAST_RUN_AT_KEY: string = 'backup.automatic.lastRunAt'
const BACKUP_AUTOMATIC_LAST_FAILURE_CODE_KEY: string = 'backup.automatic.lastFailureCode'
const BACKUP_CONTENT_INCLUDE_SETTINGS_KEY: string = 'backup.content.includeSettings'
const BACKUP_CONTENT_INCLUDE_DOWNLOAD_QUEUE_KEY: string = 'backup.content.includeDownloadQueue'
const BACKUP_CONTENT_INCLUDE_TRACKER_MAPPINGS_KEY: string = 'backup.content.includeTrackerMappings'
const SOURCE_INDEX_URL_KEY: string = 'source_index.url'
const KOMGA_SERVER_KEY: string = 'komga.server'
const KOMGA_CREDENTIAL_KEY: string = 'komga.credential'
const KAVITA_SERVER_KEY: string = 'kavita.server'
const KAVITA_CREDENTIAL_KEY: string = 'kavita.credential'
const WEBDAV_SERVER_KEY: string = 'webdav.server'
const WEBDAV_CREDENTIAL_KEY: string = 'webdav.credential'
const OPDS_SERVER_KEY: string = 'opds.server'
const OPDS_CREDENTIAL_KEY: string = 'opds.credential'

interface RemoteServerBackupDocument {
  endpointIdentities?: string
  komgaServer: string
  komgaCredential: string
  kavitaServer: string
  kavitaCredential: string
  webDavServer: string
  webDavCredential: string
  opdsServer: string
  opdsCredential: string
}

interface BackupEncryptionMetadata {
  state: string
  algorithm: string
}

interface KomaBackupDocument {
  schemaVersion: number
  exportedAt: number
  encryption: BackupEncryptionMetadata
  libraryStore: string
  localLibraryMetadata?: LocalLibraryMetadataBackupEntry[]
  readingProgress: string
  remoteServers: RemoteServerBackupDocument
  sourcePackages?: SourcePackageBackupEntry[]
  sourceSettings?: Record<string, SourceSettingsRecord>
  sourceSettingObservations?: SourceSettingObservationSources
  sourceFilterPreferences?: Record<string, SourceFilterPreferenceSourceRecord>
  settings?: ReaderPreferences
  applicationSettings?: ApplicationSettingsBackup
  sourceIndexUrl?: string
  downloadQueue?: string
  trackerMappings?: ComicTrackerMapping[]
  trackerSyncPreferences?: BackupTrackerSyncPreferences
}

interface BackupTrackerSyncPreferences {
  autoSyncEnabled: boolean
  updateStrategy: TrackerUpdateStrategy
}

export interface BackupImportPreview {
  schemaVersion: number
  exportedAt: number
  exportedAtText: string
  encryptionText: string
  encrypted: boolean
  decrypted: boolean
  algorithm: string
  kdfId: string
  libraryItemCount: number
  progressCount: number
  currentLibraryItemCount: number
  currentProgressCount: number
  libraryAddCount: number
  libraryConflictCount: number
  progressAddCount: number
  progressConflictCount: number
  settingsCount: number
  categoryCount: number
  downloadQueueCount: number
  trackerMappingCount: number
  sourcePackageCount: number
  sourceSettingsCount: number
  hasDownloadQueueCount: boolean
  hasTrackerMappingCount: boolean
}

export interface BackupImportSelectionPreview {
  payload: string
  preview: BackupImportPreview
}

export interface BackupLocalFileRecord {
  fileName: string
  displayName: string
  sizeBytes: number
  preview: BackupImportPreview
}

export interface BackupAutomaticPreferences {
  directoryOwnedModes?: number
  directoryUri?: string
  backgroundEnabled?: boolean
  enabled: boolean
  intervalHours: number
  retentionCount: number
  lastRunAt: number
  lastFailureCode: string
}

export interface BackupContentPreferences {
  includeSettings: boolean
  includeDownloadQueue: boolean
  includeTrackerMappings: boolean
}

export interface BackupAutomaticPreferencesPatch {
  directoryOwnedModes?: number
  directoryUri?: string
  backgroundEnabled?: boolean
  enabled?: boolean
  intervalHours?: number
  retentionCount?: number
}

export interface BackupAutomaticRunResult {
  ran: boolean
  deletedCount: number
  preferences: BackupAutomaticPreferences
  created?: BackupLocalFileRecord
  skippedReason?: string
  failureCode?: string
}

export const DEFAULT_BACKUP_AUTOMATIC_PREFERENCES: BackupAutomaticPreferences = {
  directoryUri: '', directoryOwnedModes: 0, backgroundEnabled: false,
  enabled: false,
  intervalHours: 24,
  retentionCount: 5,
  lastRunAt: 0,
  lastFailureCode: '',
}

export const DEFAULT_BACKUP_CONTENT_PREFERENCES: BackupContentPreferences = {
  includeSettings: true,
  includeDownloadQueue: true,
  includeTrackerMappings: true,
}

let automaticBackupInFlight: Promise<BackupAutomaticRunResult> | undefined = undefined
let automaticBackupInFlightReason: 'due' | 'manual' | undefined = undefined
let automaticPreferenceOperation: Promise<void> = Promise.resolve()

function queueAutomaticPreferences<T>(operation: () => Promise<T>): Promise<T> {
  const result = automaticPreferenceOperation.then(operation)
  automaticPreferenceOperation = result.then(() => {}, () => {})
  return result
}

export function backupIncludedDomainLabels(preferencesValue: BackupContentPreferences = DEFAULT_BACKUP_CONTENT_PREFERENCES): string[] {
  const labels: string[] = [
    AppStrings.get('backup_domain_library_categories'),
    AppStrings.get('backup_domain_progress'),
    AppStrings.get('backup_domain_remote_servers'),
    AppStrings.get('backup_domain_source_packages'),
  ]
  const normalized = normalizeBackupContentPreferences(preferencesValue)
  if (normalized.includeSettings) {
    labels.push(AppStrings.get('backup_domain_reader_preferences'))
  }
  if (normalized.includeDownloadQueue) {
    labels.push(AppStrings.get('backup_domain_download_queue'))
  }
  if (normalized.includeTrackerMappings) {
    labels.push(AppStrings.get('backup_domain_tracker_mappings'))
  }
  return labels
}

export function backupManagementStorageNote(): string {
  return AppStrings.get('backup_storage_note')
}

export function backupEncryptionStatusLabel(): string {
  return AppStrings.get('backup_encryption_status_available')
}

export function backupEncryptionPlanLabel(): string {
  return AppStrings.get('backup_encryption_plan')
}

export function backupUnencryptedExportWarning(): string {
  return AppStrings.get('backup_unencrypted_warning')
}

export function backupEncryptedExportSuccess(): string {
  return AppStrings.get('backup_encrypted_export_success')
}

export function backupPassphraseHelpText(): string {
  return AppStrings.format('backup_passphrase_help', BACKUP_PASSPHRASE_MIN_LENGTH)
}

export function backupImportPreviewNote(): string {
  return AppStrings.get('backup_import_preview_note')
}

export function backupImportConflictPolicy(): string {
  return AppStrings.get('backup_import_conflict_policy')
}

function joinBackupPath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  if (left.length === 0) {
    return right
  }
  return `${left}/${right}`
}

function readTextIfExists(path: string, fallback: string): string {
  if (!fs.accessSync(path)) {
    return fallback
  }
  return fs.readTextSync(path, { encoding: 'utf-8' })
}

// DocumentViewPicker grants a URI. readTextSync only accepts sandbox paths;
// openSync can consume the grant and the descriptor keeps partial reads exact.
function readPickedBackupText(uri: string): string {
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
  try {
    const size = fs.statSync(file.fd).size
    const bytes = new Uint8Array(size)
    let offset = 0
    while (offset < size) {
      const chunk = new ArrayBuffer(Math.min(65536, size - offset))
      const count = fs.readSync(file.fd, chunk)
      if (count <= 0) throw new Error('Incomplete backup file')
      bytes.set(new Uint8Array(chunk, 0, count), offset)
      offset += count
    }
    return buffer.from(bytes.buffer).toString('utf-8')
  } finally {
    fs.closeSync(file)
  }
}

function writePickedBackupText(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    const written = fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    if (written !== buffer.byteLength(payload, 'utf-8')) {
      throw new Error('backup_file_write_incomplete')
    }
    fs.fsyncSync(file.fd)
  } finally {
    if (file !== undefined) {
      fs.closeSync(file)
    }
  }
}

function ensureDir(path: string): void {
  if (!fs.accessSync(path)) {
    fs.mkdirSync(path, true)
  }
}

function backupFileSizeText(sizeBytes: number): string {
  const size = Math.max(0, Math.floor(sizeBytes))
  if (size >= 1024 * 1024) {
    return `${Math.round(size / (1024 * 1024))} MB`
  }
  if (size >= 1024) {
    return `${Math.round(size / 1024)} KB`
  }
  return `${size} B`
}

export function backupLocalFileDetailText(record: BackupLocalFileRecord): string {
  return AppStrings.format(
    'backup_local_file_detail',
    record.preview.exportedAtText,
    backupFileSizeText(record.sizeBytes),
  )
}

export function backupAutomaticIntervalLabel(intervalHours: number): string {
  if (intervalHours === 24) {
    return AppStrings.get('backup_auto_interval_24h')
  }
  if (intervalHours === 72) {
    return AppStrings.get('backup_auto_interval_72h')
  }
  if (intervalHours === 168) {
    return AppStrings.get('backup_auto_interval_168h')
  }
  return AppStrings.format('backup_auto_interval_hours', intervalHours)
}

export function backupAutomaticRetentionLabel(retentionCount: number): string {
  return AppStrings.format('backup_auto_retention_count', retentionCount)
}

export function backupAutomaticLastRunText(preferencesValue: BackupAutomaticPreferences): string {
  if (preferencesValue.lastRunAt <= 0) {
    return AppStrings.get('backup_auto_last_run_never')
  }
  return formatBackupExportedAt(preferencesValue.lastRunAt)
}

export function backupAutomaticLastFailureText(preferencesValue: BackupAutomaticPreferences): string {
  if (preferencesValue.lastFailureCode.length === 0) {
    return AppStrings.get('backup_auto_no_failure')
  }
  return AppStrings.format('backup_failure_message', preferencesValue.lastFailureCode)
}

function normalizeLocalBackupName(value: string, fallback: string): string {
  const normalized = value.trim().replace(/\s+/g, '-').replace(/[^a-zA-Z0-9._-]/g, '-').replace(/-+/g, '-')
  if (normalized.length === 0 || normalized === '.' || normalized === '..') {
    return fallback
  }
  return normalized
}

function backupFileExtension(fileName: string): string {
  return fileName.endsWith('.koma-backup') ? '.koma-backup' : '.json'
}

function normalizeLocalBackupFileName(value: string, fallback: string, extension: string): string {
  let normalized = normalizeLocalBackupName(value, fallback)
  if (!normalized.endsWith('.json') && !normalized.endsWith('.koma-backup')) {
    normalized = `${normalized}${extension}`
  }
  return normalized
}

function isLocalBackupFileName(fileName: string): boolean {
  return fileName.length > 0 &&
    !fileName.includes('/') &&
    !fileName.includes('\\') &&
    fileName !== '.' &&
    fileName !== '..' &&
    (fileName.endsWith('.json') || fileName.endsWith('.koma-backup'))
}

function normalizeBackupAutomaticIntervalHours(value: number): number {
  const normalized = Number.isFinite(value) ? Math.floor(value) : DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.intervalHours
  return BACKUP_AUTOMATIC_INTERVAL_HOUR_OPTIONS.indexOf(normalized) >= 0 ?
    normalized :
    DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.intervalHours
}

function normalizeBackupAutomaticRetentionCount(value: number): number {
  const normalized = Number.isFinite(value) ? Math.floor(value) : DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.retentionCount
  return BACKUP_AUTOMATIC_RETENTION_COUNT_OPTIONS.indexOf(normalized) >= 0 ?
    normalized :
    DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.retentionCount
}

function normalizeBackupAutomaticLastRunAt(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : 0
}

function normalizeBackupAutomaticPreferences(value: BackupAutomaticPreferences): BackupAutomaticPreferences {
  return {
    directoryOwnedModes: value.directoryOwnedModes ?? 0,
    directoryUri: value.directoryUri?.trim() ?? '', backgroundEnabled: value.backgroundEnabled === true,
    enabled: value.enabled === true,
    intervalHours: normalizeBackupAutomaticIntervalHours(value.intervalHours),
    retentionCount: normalizeBackupAutomaticRetentionCount(value.retentionCount),
    lastRunAt: normalizeBackupAutomaticLastRunAt(value.lastRunAt),
    lastFailureCode: value.lastFailureCode.trim(),
  }
}

function normalizeBackupContentPreferences(value: BackupContentPreferences): BackupContentPreferences {
  return {
    includeSettings: value.includeSettings !== false,
    includeDownloadQueue: value.includeDownloadQueue !== false,
    includeTrackerMappings: value.includeTrackerMappings !== false,
  }
}

function emptyLibraryStorePayload(): string {
  return JSON.stringify({
    schemaVersion: LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION,
    comics: [],
  })
}

function emptyReaderProgressPayload(): string {
  return JSON.stringify({
    schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
    progress: [],
    modes: [],
  })
}

function asJsonObject(value: Object, label: string): Record<string, Object> {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error(`Invalid backup ${label}`)
  }
  return value as Record<string, Object>
}

function arrayFieldCount(source: Record<string, Object>, key: string): number {
  const value = source[key]
  if (!Array.isArray(value)) {
    return 0
  }
  return value.length
}

function stringFieldSet(source: Record<string, Object>, arrayKey: string, fieldKey: string): Set<string> {
  const value = source[arrayKey]
  const ids = new Set<string>()
  if (!Array.isArray(value)) {
    return ids
  }
  const rows = value as Object[]
  rows.forEach((row: Object) => {
    if (row === null || Array.isArray(row) || typeof row !== 'object') {
      return
    }
    const id = (row as Record<string, Object>)[fieldKey]
    if (typeof id === 'string' && id.length > 0) {
      ids.add(id)
    }
  })
  return ids
}

function overlapCount(left: Set<string>, right: Set<string>): number {
  let count = 0
  left.forEach((id: string) => {
    if (right.has(id)) {
      count += 1
    }
  })
  return count
}

function missingInRightCount(left: Set<string>, right: Set<string>): number {
  let count = 0
  left.forEach((id: string) => {
    if (!right.has(id)) {
      count += 1
    }
  })
  return count
}

function countLibraryCategories(libraryStore: Record<string, Object>): number {
  const customCategories = libraryStore['customCategories']
  const comics = libraryStore['comics']
  if (Array.isArray(customCategories)) {
    return customCategories.length
  }
  if (!Array.isArray(comics)) {
    return 0
  }
  const categories = new Set<string>()
  comics.forEach((item: Object) => {
    if (item === null || Array.isArray(item) || typeof item !== 'object') {
      return
    }
    const row = item as Record<string, Object>
    const categoryIds = row['categoryIds']
    if (!Array.isArray(categoryIds)) {
      return
    }
    categoryIds.forEach((categoryId: Object) => {
      if (typeof categoryId === 'string' && categoryId.trim().length > 0) {
        categories.add(categoryId.trim())
      }
    })
  })
  return categories.size
}

function countReaderPreferences(settings: ReaderPreferences | undefined): number {
  if (settings === undefined || settings === null || Array.isArray(settings) || typeof settings !== 'object') {
    return 0
  }
  return Object.keys(settings).length
}

function countBackupTrackerSyncPreferences(preferencesValue: BackupTrackerSyncPreferences | undefined): number {
  return preferencesValue === undefined ? 0 : 2
}

function normalizeBackupTrackerSyncPreferences(
  preferencesValue: BackupTrackerSyncPreferences | undefined,
): BackupTrackerSyncPreferences | undefined {
  if (preferencesValue === undefined) {
    return undefined
  }
  return {
    autoSyncEnabled: preferencesValue.autoSyncEnabled === true,
    updateStrategy: normalizeTrackerUpdateStrategy(preferencesValue.updateStrategy),
  }
}

function normalizeBackupString(value: Object | undefined): string | undefined {
  return typeof value === 'string' && value.trim().length > 0 ? value : undefined
}

function normalizeBackupCount(value: Object | undefined): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0
}

function normalizeBackupForegroundConcurrencyLimit(value: Object | undefined): number {
  const normalized = normalizeBackupCount(value)
  return OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS.indexOf(normalized) >= 0 ?
    normalized :
    DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.foregroundConcurrencyLimit
}

function normalizeBackupDownloadStatus(value: Object | undefined): OfflineDownloadStatus {
  if (value === OfflineDownloadStatus.DOWNLOADED) {
    return OfflineDownloadStatus.DOWNLOADED
  }
  if (value === OfflineDownloadStatus.PARTIAL) {
    return OfflineDownloadStatus.PARTIAL
  }
  if (value === OfflineDownloadStatus.FAILED) {
    return OfflineDownloadStatus.FAILED
  }
  if (value === OfflineDownloadStatus.BLOCKED) {
    return OfflineDownloadStatus.BLOCKED
  }
  return OfflineDownloadStatus.QUEUED
}

function normalizeBackupDownloadQueuePayload(payload: string): string {
  const document = asJsonObject(JSON.parse(payload) as Object, 'download queue')
  if (document['schemaVersion'] !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION || !Array.isArray(document['entries'])) {
    throw new Error('Invalid backup download queue')
  }
  const preferencesRecord = document['preferences'] === undefined ? undefined :
    asJsonObject(document['preferences'] as Object, 'download queue preferences')
  const preferences: OfflineDownloadQueuePreferences = {
    foregroundConcurrencyLimit: preferencesRecord === undefined ?
      DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.foregroundConcurrencyLimit :
      normalizeBackupForegroundConcurrencyLimit(preferencesRecord['foregroundConcurrencyLimit']),
    isPaused: preferencesRecord === undefined ?
      DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.isPaused :
      preferencesRecord['isPaused'] === true,
    wifiOnly: preferencesRecord === undefined ?
      DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES.wifiOnly :
      preferencesRecord['wifiOnly'] === true,
  }
  const entries = (document['entries'] as Object[]).map((item: Object): OfflineDownloadQueueEntry => {
    const row = asJsonObject(item, 'download queue entry')
    const comicId = normalizeBackupString(row['comicId'])
    const chapterId = normalizeBackupString(row['chapterId'])
    if (comicId === undefined || chapterId === undefined) {
      throw new Error('Invalid backup download queue entry')
    }
    const entry: OfflineDownloadQueueEntry = {
      comicId,
      chapterId,
      status: normalizeBackupDownloadStatus(row['status']),
      pageCount: normalizeBackupCount(row['pageCount']),
      downloadedPageCount: normalizeBackupCount(row['downloadedPageCount']),
      updatedAt: normalizeBackupCount(row['updatedAt']),
    }
    const comicTitle = normalizeBackupString(row['comicTitle'])
    if (comicTitle !== undefined) {
      entry.comicTitle = comicTitle
    }
    const chapterTitle = normalizeBackupString(row['chapterTitle'])
    if (chapterTitle !== undefined) {
      entry.chapterTitle = chapterTitle
    }
    const failureReasonCode = normalizeOfflineDownloadFailureReasonCode(normalizeBackupString(row['failureReasonCode']))
    if (failureReasonCode !== undefined) {
      entry.failureReasonCode = failureReasonCode
    }
    return entry
  })
  return JSON.stringify({
    schemaVersion: OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION,
    preferences,
    entries,
  })
}

function countBackupDownloadQueueEntries(payload: string | undefined): number {
  if (payload === undefined || payload.length === 0) {
    return 0
  }
  const document = asJsonObject(JSON.parse(normalizeBackupDownloadQueuePayload(payload)) as Object, 'download queue')
  return Array.isArray(document['entries']) ? document['entries'].length : 0
}

function countBackupTrackerMappings(mappings: ComicTrackerMapping[] | undefined): number {
  if (mappings === undefined || !Array.isArray(mappings)) {
    return 0
  }
  return normalizeComicTrackerMappings(mappings).length
}

function formatBackupExportedAt(exportedAt: number | undefined): string {
  if (exportedAt === undefined || !Number.isFinite(exportedAt) || exportedAt <= 0) {
    return AppStrings.get('backup_preview_not_provided')
  }
  return new Date(exportedAt).toLocaleString()
}

function normalizeBackupExportedAt(exportedAt: number | undefined): number {
  return exportedAt === undefined || !Number.isFinite(exportedAt) || exportedAt <= 0 ? 0 : Math.floor(exportedAt)
}

function formatBackupEncryption(encryption: BackupEncryptionMetadata | undefined): string {
  if (encryption !== undefined && encryption.state === BACKUP_ENCRYPTION_STATE && encryption.algorithm === 'none') {
    return AppStrings.get('backup_encryption_unencrypted_json')
  }
  return AppStrings.get('backup_encryption_unencrypted_legacy')
}

function emptyEncryptedCountsPreview(publicPreview: BackupEncryptedPublicPreview): BackupImportPreview {
  return {
    schemaVersion: publicPreview.contentSchemaVersion,
    exportedAt: normalizeBackupExportedAt(publicPreview.exportedAt),
    exportedAtText: publicPreview.exportedAtText,
    encryptionText: AppStrings.get('backup_encryption_encrypted_preview_needed'),
    encrypted: true,
    decrypted: false,
    algorithm: publicPreview.algorithm,
    kdfId: publicPreview.kdfId,
    libraryItemCount: 0,
    progressCount: 0,
    currentLibraryItemCount: 0,
    currentProgressCount: 0,
    libraryAddCount: 0,
    libraryConflictCount: 0,
    progressAddCount: 0,
    progressConflictCount: 0,
    settingsCount: 0,
    categoryCount: 0,
    downloadQueueCount: 0,
    trackerMappingCount: 0,
    sourcePackageCount: 0,
    sourceSettingsCount: 0,
    hasDownloadQueueCount: false,
    hasTrackerMappingCount: false,
  }
}

function isAcceptedPlaintextSchemaVersion(schemaVersion: number): boolean {
  return schemaVersion === BACKUP_SCHEMA_VERSION ||
    schemaVersion === BACKUP_SCHEMA_VERSION_V2 ||
    schemaVersion === BACKUP_SCHEMA_VERSION_V1
}

function isAcceptedDecryptedSchemaVersion(schemaVersion: number): boolean {
  return isAcceptedPlaintextSchemaVersion(schemaVersion) || schemaVersion === BACKUP_ENCRYPTED_SCHEMA_VERSION
}

/** Normalize every payload that can fail before any live restore writer runs. */
function prepareBackupRestoreDocument(json: string, allowEncryptedContentSchema: boolean): KomaBackupDocument {
  const document = JSON.parse(json) as KomaBackupDocument
  asJsonObject(document as Object, 'document')
  const accepted = allowEncryptedContentSchema ?
    isAcceptedDecryptedSchemaVersion(document.schemaVersion) :
    isAcceptedPlaintextSchemaVersion(document.schemaVersion)
  if (!accepted) throw new Error(`Unsupported backup schema version: ${document.schemaVersion}`)
  if (typeof document.libraryStore !== 'string' || typeof document.readingProgress !== 'string') {
    throw new Error('Invalid backup payload')
  }
  document.libraryStore = restoreLocalLibraryMetadataBackupEntries(document.libraryStore, document.localLibraryMetadata)
  assertValidLibraryStoreJson(document.libraryStore)
  document.readingProgress = normalizeReaderSessionBackupPayload(document.readingProgress)

  if (document.remoteServers !== undefined && document.remoteServers !== null) {
    const remote = asJsonObject(document.remoteServers as Object, 'remote servers')
    const keys: string[] = [
      'komgaServer', 'komgaCredential', 'kavitaServer', 'kavitaCredential',
      'webDavServer', 'webDavCredential', 'opdsServer', 'opdsCredential', 'endpointIdentities',
    ]
    keys.forEach((key: string): void => {
      if (remote[key] !== undefined && typeof remote[key] !== 'string') throw new Error('Invalid backup remote servers')
    })
    if (typeof document.remoteServers.endpointIdentities === 'string' && document.remoteServers.endpointIdentities.length > 0) {
      const identities = parseRemoteServerEndpointIdentities(document.remoteServers.endpointIdentities)
      rememberRemoteServerEndpointIdentity(identities, 'komga', document.remoteServers.komgaServer ?? '')
      rememberRemoteServerEndpointIdentity(identities, 'kavita', document.remoteServers.kavitaServer ?? '')
      rememberRemoteServerEndpointIdentity(identities, 'webdav', document.remoteServers.webDavServer ?? '')
      rememberRemoteServerEndpointIdentity(identities, 'opds', document.remoteServers.opdsServer ?? '')
    }
  }
  if (document.schemaVersion >= BACKUP_SCHEMA_VERSION) {
    if (document.sourceSettings !== undefined) {
      const sources = asJsonObject(document.sourceSettings as Object, 'source settings')
      Object.keys(sources).forEach((sourceId: string): void => {
        if (sources[sourceId] !== null) asJsonObject(sources[sourceId], 'source settings record')
      })
    }
    if (document.sourceSettingObservations !== undefined) {
      document.sourceSettingObservations = checkedSourceSettingObservationSources(document.sourceSettingObservations)
    }
    if (document.sourceFilterPreferences !== undefined) {
      asJsonObject(document.sourceFilterPreferences as Object, 'source filter preferences')
    }
    if (document.sourceIndexUrl !== undefined && typeof document.sourceIndexUrl !== 'string') {
      throw new Error('Invalid backup source index URL')
    }
    if (document.downloadQueue !== undefined && document.downloadQueue !== '') {
      if (typeof document.downloadQueue !== 'string') throw new Error('Invalid backup download queue')
      document.downloadQueue = normalizeBackupDownloadQueuePayload(document.downloadQueue)
    }
    if (document.trackerMappings !== undefined) {
      if (!Array.isArray(document.trackerMappings)) throw new Error('Invalid backup tracker mappings')
      document.trackerMappings = normalizeComicTrackerMappings(document.trackerMappings)
    }
    if (document.trackerSyncPreferences !== undefined) {
      asJsonObject(document.trackerSyncPreferences as Object, 'tracker sync preferences')
      document.trackerSyncPreferences = normalizeBackupTrackerSyncPreferences(document.trackerSyncPreferences)
    }
  }
  if (document.schemaVersion >= BACKUP_SCHEMA_VERSION_V2) {
    if (document.sourcePackages !== undefined && !Array.isArray(document.sourcePackages)) {
      throw new Error('Invalid backup source packages')
    }
    if (document.settings !== undefined) {
      const settings = asJsonObject(document.settings as Object, 'reader settings')
      const defaults = DEFAULT_READER_PREFERENCES as Object as Record<string, Object>
      Object.keys(defaults).forEach((key: string): void => {
        if (settings[key] !== undefined && typeof settings[key] !== typeof defaults[key]) {
          throw new Error('Invalid backup reader settings')
        }
      })
    }
  }
  document.applicationSettings = checkedApplicationSettingsBackup(document.applicationSettings)
  return document
}

export class BackupService {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
    configureSourceSettingsStore(context)
    configureSourceFilterPreferencesStore(context)
  }

  async export(): Promise<string> {
    return JSON.stringify(await this.buildBackupDocument(BACKUP_SCHEMA_VERSION))
  }

  async exportBackgroundTemplate(): Promise<string> {
    // Capture only UI-owned Preferences here; the Extension reads the current library
    // and encodes packages itself, keeping the large export off the UI lifecycle.
    return JSON.stringify(await this.buildBackupDocument(BACKUP_SCHEMA_VERSION, true))
  }

  async exportEncrypted(passphrase: string): Promise<string> {
    const document = await this.buildBackupDocument(BACKUP_ENCRYPTED_SCHEMA_VERSION)
    const payload = await new BackupEncryptionService().encrypt(JSON.stringify(document), passphrase)
    DiagnosticLogger.info('backup', 'export_encrypted', '[Backup] step=export_encrypted')
    return payload
  }

  async exportLocal(): Promise<BackupLocalFileRecord> {
    const payload = await this.export()
    const fileName = `koma-backup-${Date.now()}.json`
    const record = this.writeLocalBackup(fileName, payload)
    DiagnosticLogger.info('backup', 'local_export', '[Backup] step=local_export')
    return record
  }

  async exportEncryptedLocal(passphrase: string): Promise<BackupLocalFileRecord> {
    const payload = await this.exportEncrypted(passphrase)
    const fileName = `koma-backup-${Date.now()}.koma-backup`
    const record = this.writeLocalBackup(fileName, payload)
    DiagnosticLogger.info('backup', 'local_export_encrypted', '[Backup] step=local_export_encrypted')
    return record
  }

  async loadAutomaticPreferences(): Promise<BackupAutomaticPreferences> {
    return queueAutomaticPreferences(() => this.readAutomaticPreferences())
  }

  private async readAutomaticPreferences(): Promise<BackupAutomaticPreferences> {
    const store = await this.automaticPreferences()
    const enabled = await store.get(BACKUP_AUTOMATIC_ENABLED_KEY, DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.enabled) as boolean
    const intervalHours = await store.get(BACKUP_AUTOMATIC_INTERVAL_HOURS_KEY, DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.intervalHours) as number
    const retentionCount = await store.get(BACKUP_AUTOMATIC_RETENTION_COUNT_KEY, DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.retentionCount) as number
    let lastRunAt = await store.get(BACKUP_AUTOMATIC_LAST_RUN_AT_KEY, DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.lastRunAt) as number
    let lastFailureCode = await store.get(BACKUP_AUTOMATIC_LAST_FAILURE_CODE_KEY, DEFAULT_BACKUP_AUTOMATIC_PREFERENCES.lastFailureCode) as string
    const backgroundResultPath = `${this.context.filesDir}/${BACKUP_BACKGROUND_RESULT}`
    if (fs.accessSync(backgroundResultPath)) {
      const background = JSON.parse(fs.readTextSync(backgroundResultPath)) as BackgroundBackupResult
      if (background.at > lastRunAt) lastFailureCode = background.failureCode
      lastRunAt = Math.max(lastRunAt, background.lastRunAt)
    }
    const directoryOwnedModes = await store.get(BACKUP_AUTOMATIC_DIRECTORY_MODES_KEY, 0) as number
    const directoryUri = await store.get(BACKUP_AUTOMATIC_DIRECTORY_KEY, '') as string
    const backgroundEnabled = await store.get(BACKUP_AUTOMATIC_BACKGROUND_KEY, false) as boolean
    return normalizeBackupAutomaticPreferences({
      directoryUri, directoryOwnedModes, backgroundEnabled,
      enabled,
      intervalHours,
      retentionCount,
      lastRunAt,
      lastFailureCode,
    })
  }

  async saveAutomaticPreferences(patch: BackupAutomaticPreferencesPatch): Promise<BackupAutomaticPreferences> {
    return queueAutomaticPreferences(() => BackupRestoreActivity.runWrite(async (): Promise<BackupAutomaticPreferences> => {
      const current = await this.readAutomaticPreferences()
      const next = normalizeBackupAutomaticPreferences({
        directoryUri: patch.directoryUri ?? current.directoryUri,
        directoryOwnedModes: patch.directoryUri === undefined || patch.directoryUri === current.directoryUri
          ? (current.directoryOwnedModes ?? 0) | (patch.directoryOwnedModes ?? 0) : patch.directoryOwnedModes ?? 0,
        backgroundEnabled: patch.backgroundEnabled ?? current.backgroundEnabled,
        enabled: patch.enabled ?? current.enabled,
        intervalHours: patch.intervalHours ?? current.intervalHours,
        retentionCount: patch.retentionCount ?? current.retentionCount,
        lastRunAt: current.lastRunAt,
        lastFailureCode: current.lastFailureCode,
      })
      try { await this.persistAutomaticPreferences(next) }
      catch (error) {
        if (next.directoryUri && next.directoryUri !== current.directoryUri && next.directoryOwnedModes) {
          try { await this.releaseOwnedBackupDirectory(next.directoryUri, next.directoryOwnedModes) }
          catch (releaseError) { DiagnosticLogger.exception('backup', 'directory_release_failed', releaseError as Error) }
        }
        throw error as Error
      }
      if (current.directoryUri && current.directoryUri !== next.directoryUri && current.directoryOwnedModes) {
        try {
          await this.releaseOwnedBackupDirectory(current.directoryUri, current.directoryOwnedModes)
        } catch (error) { DiagnosticLogger.exception('backup', 'directory_release_failed', error as Error) }
      }
      return next
    }))
  }

  private async releaseOwnedBackupDirectory(uri: string, ownedModes: number): Promise<void> {
    const library = new InMemoryLibraryStore()
    if (fs.accessSync(this.libraryPath())) hydrateLibraryStoreFromJson(library, fs.readTextSync(this.libraryPath()))
    await releaseAutomaticBackupDirectory(uri, ownedModes, localLibraryFolderRootUrisFromComics(library.listComics()))
  }

  private async persistAutomaticPreferences(preferencesValue: BackupAutomaticPreferences): Promise<void> {
    const normalized = normalizeBackupAutomaticPreferences(preferencesValue)
    const store = await this.automaticPreferences()
    const keys: string[] = [BACKUP_AUTOMATIC_DIRECTORY_MODES_KEY, BACKUP_AUTOMATIC_DIRECTORY_KEY, BACKUP_AUTOMATIC_BACKGROUND_KEY, BACKUP_AUTOMATIC_ENABLED_KEY, BACKUP_AUTOMATIC_INTERVAL_HOURS_KEY,
      BACKUP_AUTOMATIC_RETENTION_COUNT_KEY, BACKUP_AUTOMATIC_LAST_RUN_AT_KEY, BACKUP_AUTOMATIC_LAST_FAILURE_CODE_KEY]
    const values: preferences.ValueType[] = [normalized.directoryOwnedModes ?? 0, normalized.directoryUri ?? '', normalized.backgroundEnabled === true, normalized.enabled, normalized.intervalHours,
      normalized.retentionCount, normalized.lastRunAt, normalized.lastFailureCode]
    const existed: boolean[] = keys.map((key: string): boolean => store.hasSync(key))
    const previous: preferences.ValueType[] = keys.map((key: string): preferences.ValueType => store.getSync(key, ''))
    try {
      for (let i = 0; i < keys.length; i++) await store.put(keys[i], values[i])
      await store.flush()
    } catch (error) {
      try {
        for (let i = 0; i < keys.length; i++) {
          if (existed[i]) store.putSync(keys[i], previous[i])
          else store.deleteSync(keys[i])
        }
        await store.flush()
      } catch (_rollbackError) {
        throw new Error('backup_automatic_preferences_rollback_failed')
      }
      throw error as Error
    }
  }

  async loadContentPreferences(): Promise<BackupContentPreferences> {
    const store = await this.contentPreferences()
    const includeSettings =
      await store.get(BACKUP_CONTENT_INCLUDE_SETTINGS_KEY, DEFAULT_BACKUP_CONTENT_PREFERENCES.includeSettings) as boolean
    const includeDownloadQueue =
      await store.get(BACKUP_CONTENT_INCLUDE_DOWNLOAD_QUEUE_KEY, DEFAULT_BACKUP_CONTENT_PREFERENCES.includeDownloadQueue) as boolean
    const includeTrackerMappings =
      await store.get(BACKUP_CONTENT_INCLUDE_TRACKER_MAPPINGS_KEY, DEFAULT_BACKUP_CONTENT_PREFERENCES.includeTrackerMappings) as boolean
    return normalizeBackupContentPreferences({
      includeSettings,
      includeDownloadQueue,
      includeTrackerMappings,
    })
  }

  async saveContentPreferences(preferencesValue: BackupContentPreferences): Promise<void> {
    const normalized = normalizeBackupContentPreferences(preferencesValue)
    const store = await this.contentPreferences()
    await store.put(BACKUP_CONTENT_INCLUDE_SETTINGS_KEY, normalized.includeSettings)
    await store.put(BACKUP_CONTENT_INCLUDE_DOWNLOAD_QUEUE_KEY, normalized.includeDownloadQueue)
    await store.put(BACKUP_CONTENT_INCLUDE_TRACKER_MAPPINGS_KEY, normalized.includeTrackerMappings)
    await store.flush()
  }

  async runAutomaticLocalBackupIfDue(now: number = Date.now(), requireForeground: boolean = false): Promise<BackupAutomaticRunResult> {
    return this.requestAutomaticLocalBackup('due', now, requireForeground)
  }

  async runAutomaticLocalBackupNow(now: number = Date.now()): Promise<BackupAutomaticRunResult> {
    return this.requestAutomaticLocalBackup('manual', now, false)
  }

  private requestAutomaticLocalBackup(
    reason: 'due' | 'manual', now: number, requireForeground: boolean,
  ): Promise<BackupAutomaticRunResult> {
    const active = automaticBackupInFlight
    const activeReason = automaticBackupInFlightReason
    if (active !== undefined) {
      if (reason === 'manual') {
        return active.then((result: BackupAutomaticRunResult): Promise<BackupAutomaticRunResult> | BackupAutomaticRunResult => {
          const skippedDue = activeReason === 'due' && !result.ran && result.failureCode === undefined
          return skippedDue ? this.requestAutomaticLocalBackup(reason, now, requireForeground) : result
        })
      }
      return active
    }
    automaticBackupInFlightReason = reason
    // Reserve the slot before preference IO; restore admission covers export, pruning and status commit.
    const operation = Promise.resolve().then(() => BackupRestoreActivity.runWrite(() =>
      this.runAdmittedAutomaticLocalBackup(reason, now, requireForeground)))
    automaticBackupInFlight = operation.finally(() => {
      automaticBackupInFlight = undefined
      automaticBackupInFlightReason = undefined
    })
    return automaticBackupInFlight
  }

  private async runAdmittedAutomaticLocalBackup(
    reason: 'due' | 'manual', now: number, requireForeground: boolean,
  ): Promise<BackupAutomaticRunResult> {
    const preferencesValue = await this.loadAutomaticPreferences()
    if (reason === 'due' && !preferencesValue.enabled) {
      return {
        ran: false,
        deletedCount: 0,
        preferences: preferencesValue,
        skippedReason: 'disabled',
      }
    }
    const intervalMs = preferencesValue.intervalHours * 60 * 60 * 1000
    if (reason === 'due' && preferencesValue.lastRunAt > 0 && now - preferencesValue.lastRunAt < intervalMs) {
      return {
        ran: false,
        deletedCount: 0,
        preferences: preferencesValue,
        skippedReason: 'not_due',
      }
    }
    if (reason === 'due' && requireForeground && !connectAppForegroundState().active) {
      return { ran: false, deletedCount: 0, preferences: preferencesValue, skippedReason: 'background' }
    }
    DiagnosticLogger.info('backup', 'auto_started', '[Backup] step=auto_started reason=' + reason)
    return this.runAutomaticLocalBackupWithPreferences(now)
  }

  async pruneLocalBackups(retentionCount: number): Promise<number> {
    const keepCount = normalizeBackupAutomaticRetentionCount(retentionCount)
    const records = await this.listLocalBackups()
    const staleRecords = records.slice(keepCount)
    for (let index = 0; index < staleRecords.length; index += 1) {
      await this.deleteLocalBackup(staleRecords[index].fileName)
    }
    return staleRecords.length
  }

  async listLocalBackups(): Promise<BackupLocalFileRecord[]> {
    ensureDir(this.localBackupsDir())
    const options: ListFileOptions = {
      recursion: false,
      listNum: 0,
    }
    const fileNames = (await fs.listFile(this.localBackupsDir(), options))
      .map((name: string): string => name.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, ''))
      .filter((name: string): boolean => isLocalBackupFileName(name))
    const records: BackupLocalFileRecord[] = []
    for (let index = 0; index < fileNames.length; index += 1) {
      const record = this.readLocalBackupRecord(fileNames[index], true)
      if (record !== undefined) {
        records.push(record)
      }
    }
    return records.sort((left: BackupLocalFileRecord, right: BackupLocalFileRecord): number => {
      const exportedDiff = right.preview.exportedAt - left.preview.exportedAt
      return exportedDiff !== 0 ? exportedDiff : right.fileName.localeCompare(left.fileName)
    })
  }

  async renameLocalBackup(fileName: string, displayName: string): Promise<BackupLocalFileRecord> {
    const sourceName = this.requireLocalBackupFileName(fileName)
    const extension = backupFileExtension(sourceName)
    const targetName = this.uniqueLocalBackupFileName(normalizeLocalBackupFileName(displayName, sourceName, extension), sourceName)
    const sourcePath = this.localBackupPath(sourceName)
    const targetPath = this.localBackupPath(targetName)
    if (targetName !== sourceName) {
      fs.moveFileSync(sourcePath, targetPath, 0)
    }
    const record = this.readLocalBackupRecord(targetName)
    if (record === undefined) {
      throw new Error('backup_local_rename_failed')
    }
    DiagnosticLogger.info('backup', 'local_rename', '[Backup] step=local_rename')
    return record
  }

  async deleteLocalBackup(fileName: string): Promise<void> {
    const safeName = this.requireLocalBackupFileName(fileName)
    const path = this.localBackupPath(safeName)
    if (fs.accessSync(path)) {
      fs.unlinkSync(path)
    }
    DiagnosticLogger.info('backup', 'local_delete', '[Backup] step=local_delete')
  }

  async selectLocalBackup(fileName: string): Promise<BackupImportSelectionPreview> {
    const safeName = this.requireLocalBackupFileName(fileName)
    const payload = fs.readTextSync(this.localBackupPath(safeName), { encoding: 'utf-8' })
    const preview = this.preview(payload)
    DiagnosticLogger.info('backup', 'local_select', '[Backup] step=local_select')
    return {
      payload,
      preview,
    }
  }

  private async buildBackupDocument(schemaVersion: number, backgroundTemplate: boolean = false): Promise<KomaBackupDocument> {
    return BackupRestoreActivity.runWrite(async (): Promise<KomaBackupDocument> => {
      const contentPreferences = await this.loadContentPreferences()
      if (appReaderSessionStore(this.context.filesDir).flush() === false) {
        throw new Error('reader_progress_save_failed')
      }
      const sourceSettingObservations = await appSourceSettingObservationStore.exportAll()
      const libraryStore = backgroundTemplate ? emptyLibraryStorePayload() : readTextIfExists(this.libraryPath(), emptyLibraryStorePayload())
      assertValidLibraryStoreJson(libraryStore)
      const document: KomaBackupDocument = {
        schemaVersion,
        exportedAt: Date.now(),
        encryption: {
          state: BACKUP_ENCRYPTION_STATE,
          algorithm: 'none',
        },
        libraryStore,
        readingProgress: readTextIfExists(this.readerProgressPath(), emptyReaderProgressPayload()),
        remoteServers: await this.exportRemoteServers(),
        sourcePackages: backgroundTemplate ? undefined : exportInstalledSourcePackages(),
        sourceSettings: appSourceSettingsStore.exportAll(),
        sourceSettingObservations,
        sourceFilterPreferences: appSourceFilterPreferencesStore.exportAll(),
      }
      if (contentPreferences.includeSettings) {
        document.settings = await new ReaderPreferencesStore(this.context).load()
        document.applicationSettings = await exportApplicationSettings(this.context)
        document.sourceIndexUrl = await this.exportSourceIndexUrl()
        document.trackerSyncPreferences = await this.exportTrackerSyncPreferences()
      }
      if (contentPreferences.includeDownloadQueue) {
        const downloadQueue = readTextIfExists(this.downloadQueuePath(), '')
        if (downloadQueue.length > 0) {
          document.downloadQueue = normalizeBackupDownloadQueuePayload(downloadQueue)
        }
      }
      if (contentPreferences.includeTrackerMappings) {
        document.trackerMappings = await this.exportTrackerMappings()
      }
      document.localLibraryMetadata = exportLocalLibraryMetadataBackupEntries(document.libraryStore)
      DiagnosticLogger.info('backup', backgroundTemplate ? 'background_template' : 'export_json', '')
      return document
    })
  }

  async import(json: string): Promise<void> {
    await this.importDocument(json, false)
  }

  async importDecrypted(json: string): Promise<void> {
    await this.importDocument(json, true)
  }

  private async importDocument(json: string, allowEncryptedContentSchema: boolean): Promise<void> {
    const document = prepareBackupRestoreDocument(json, allowEncryptedContentSchema)
    BackupRestoreActivity.beginRestore()
    appSourceSettingObservationStore.invalidateCachedDocument()
    let sourcePlan: PreparedSourcePackageRestore | undefined
    let checkpoint: BackupRestoreCheckpoint | undefined
    try {
      beginAutomationRestore(this.context)
      if (document.schemaVersion >= BACKUP_SCHEMA_VERSION_V2 && document.sourcePackages !== undefined) {
        const prepared = await prepareSourcePackagesFromBackup(this.context, document.sourcePackages)
        if (!prepared.ok || prepared.plan === undefined) {
          throw new Error('Invalid backup source packages: ' + (prepared.reasonCode ?? 'restore_failed'))
        }
        sourcePlan = prepared.plan
      }
      const sessionStore = appReaderSessionStore(this.context.filesDir)
      // Include the user's already pending progress in the original state.
      if (sessionStore.flush() === false) throw new Error('reader_progress_save_failed')
      checkpoint = await BackupRestoreCheckpoint.prepare(this.context)
      writeAppTextFile(this.libraryPath(), document.libraryStore)
      writeAppTextFile(this.readerProgressPath(), document.readingProgress)
      sessionStore.reload()
      await this.importRemoteServers(document.remoteServers)
      if (document.schemaVersion >= BACKUP_SCHEMA_VERSION) {
        this.importSourceSettings(document.sourceSettings)
        if (document.sourceSettingObservations !== undefined) {
          await appSourceSettingObservationStore.importDuringRestore(document.sourceSettingObservations)
        }
        this.importSourceFilterPreferences(document.sourceFilterPreferences)
        await this.importSourceIndexUrl(document.sourceIndexUrl)
        this.importDownloadQueue(document.downloadQueue)
        await this.importTrackerMappings(document.trackerMappings)
        await this.importTrackerSyncPreferences(document.trackerSyncPreferences)
      }
      if (document.schemaVersion >= BACKUP_SCHEMA_VERSION_V2) {
        if (sourcePlan !== undefined) {
          const restored = await sourcePlan.commit(true)
          if (!restored.ok) throw new Error('Backup source registry commit failed')
        }
        await this.importSettings(document.settings)
        await importApplicationSettings(this.context, document.applicationSettings)
      }
      resetGeneratedAutomationWork(this.context)
      checkpoint.commit()
      DiagnosticLogger.info('backup', 'import_json', '[Backup] step=import_json')
    } catch (error) {
      if (checkpoint !== undefined) {
        try {
          await checkpoint.rollback()
          appReaderSessionStore(this.context.filesDir).reload()
          if (!restoreInstalledSourcePackagesAfterBackup(this.context)) {
            throw new Error('backup_registry_recovery_failed')
          }
          await new ReaderPreferencesStore(this.context).load()
          await reloadApplicationSettingsRuntime(this.context)
          checkpoint.completeRollback()
        } catch (_recoveryError) {
          BackupRestoreActivity.blockUntilRestart()
          DiagnosticLogger.error('backup', 'rollback_failed', '[BackupRecovery] step=rollback_failed code=backup_recovery_pending')
          // Keep PREPARED and prevent this Ability from consuming mixed state.
          await this.context.terminateSelf()
          throw new Error('backup_recovery_pending')
        }
      }
      throw error as Error
    } finally {
      try {
        await sourcePlan?.discard()
      } finally {
        try { finishAutomationRestore(this.context) } finally { BackupRestoreActivity.finishRestore() }
      }
    }
    await reloadApplicationSettingsRuntime(this.context)
  }

  preview(json: string): BackupImportPreview {
    if (isEncryptedBackupPayload(json)) {
      return emptyEncryptedCountsPreview(previewEncryptedBackupEnvelope(json))
    }
    return this.previewDocument(json, false)
  }

  private previewDecrypted(json: string): BackupImportPreview {
    return this.previewDocument(json, true)
  }

  private previewDocument(json: string, allowEncryptedContentSchema: boolean): BackupImportPreview {
    const document = JSON.parse(json) as KomaBackupDocument
    const accepted = allowEncryptedContentSchema ?
      isAcceptedDecryptedSchemaVersion(document.schemaVersion) :
      isAcceptedPlaintextSchemaVersion(document.schemaVersion)
    if (!accepted) {
      throw new Error(`Unsupported backup schema version: ${document.schemaVersion}`)
    }
    if (typeof document.libraryStore !== 'string' || typeof document.readingProgress !== 'string') {
      throw new Error('Invalid backup payload')
    }
    assertValidLibraryStoreJson(document.libraryStore)
    const libraryStore = asJsonObject(JSON.parse(document.libraryStore) as Object, 'library')
    const readingProgress = asJsonObject(JSON.parse(document.readingProgress) as Object, 'progress')
    const currentLibraryPayload = readTextIfExists(this.libraryPath(), emptyLibraryStorePayload())
    assertValidLibraryStoreJson(currentLibraryPayload)
    const currentLibraryStore = asJsonObject(JSON.parse(currentLibraryPayload) as Object, 'current library')
    const currentReadingProgress = asJsonObject(JSON.parse(readTextIfExists(this.readerProgressPath(), emptyReaderProgressPayload())) as Object, 'current progress')
    const backupComicIds = stringFieldSet(libraryStore, 'comics', 'id')
    const backupProgressComicIds = stringFieldSet(readingProgress, 'progress', 'comicId')
    const currentComicIds = stringFieldSet(currentLibraryStore, 'comics', 'id')
    const currentProgressComicIds = stringFieldSet(currentReadingProgress, 'progress', 'comicId')
    return {
      schemaVersion: document.schemaVersion,
      exportedAt: normalizeBackupExportedAt(document.exportedAt),
      exportedAtText: formatBackupExportedAt(document.exportedAt),
      encryptionText: formatBackupEncryption(document.encryption),
      encrypted: false,
      decrypted: true,
      algorithm: 'none',
      kdfId: '',
      libraryItemCount: arrayFieldCount(libraryStore, 'comics'),
      progressCount: arrayFieldCount(readingProgress, 'progress'),
      currentLibraryItemCount: arrayFieldCount(currentLibraryStore, 'comics'),
      currentProgressCount: arrayFieldCount(currentReadingProgress, 'progress'),
      libraryAddCount: missingInRightCount(backupComicIds, currentComicIds),
      libraryConflictCount: overlapCount(backupComicIds, currentComicIds),
      progressAddCount: missingInRightCount(backupProgressComicIds, currentProgressComicIds),
      progressConflictCount: overlapCount(backupProgressComicIds, currentProgressComicIds),
      settingsCount: countReaderPreferences(document.settings) + countBackupTrackerSyncPreferences(document.trackerSyncPreferences) +
        countApplicationSettings(checkedApplicationSettingsBackup(document.applicationSettings)),
      categoryCount: countLibraryCategories(libraryStore),
      downloadQueueCount: countBackupDownloadQueueEntries(document.downloadQueue),
      trackerMappingCount: countBackupTrackerMappings(document.trackerMappings),
      sourcePackageCount: Array.isArray(document.sourcePackages) ? document.sourcePackages.length : 0,
      sourceSettingsCount: (document.sourceSettings === undefined ? 0 : Object.keys(document.sourceSettings).length) +
        (document.sourceFilterPreferences === undefined ? 0 : Object.keys(document.sourceFilterPreferences).length),
      hasDownloadQueueCount: document.downloadQueue !== undefined,
      hasTrackerMappingCount: document.trackerMappings !== undefined,
    }
  }

  async decryptPreview(json: string, passphrase: string): Promise<BackupImportSelectionPreview> {
    const plaintext = await new BackupEncryptionService().decrypt(json, passphrase)
    const encryptedPreview = previewEncryptedBackupEnvelope(json)
    const preview = this.previewDecrypted(plaintext)
    return {
      payload: plaintext,
      preview: {
        schemaVersion: preview.schemaVersion,
        exportedAt: preview.exportedAt,
        exportedAtText: preview.exportedAtText,
        algorithm: encryptedPreview.algorithm,
        kdfId: encryptedPreview.kdfId,
        libraryItemCount: preview.libraryItemCount,
        progressCount: preview.progressCount,
        currentLibraryItemCount: preview.currentLibraryItemCount,
        currentProgressCount: preview.currentProgressCount,
        libraryAddCount: preview.libraryAddCount,
        libraryConflictCount: preview.libraryConflictCount,
        progressAddCount: preview.progressAddCount,
        progressConflictCount: preview.progressConflictCount,
        settingsCount: preview.settingsCount,
        categoryCount: preview.categoryCount,
        downloadQueueCount: preview.downloadQueueCount,
        trackerMappingCount: preview.trackerMappingCount,
        sourcePackageCount: preview.sourcePackageCount,
        sourceSettingsCount: preview.sourceSettingsCount,
        hasDownloadQueueCount: preview.hasDownloadQueueCount,
        hasTrackerMappingCount: preview.hasTrackerMappingCount,
        encrypted: true,
        decrypted: true,
        encryptionText: AppStrings.get('backup_encryption_encrypted_verified'),
      },
    }
  }

  async exportToPicker(): Promise<string | undefined> {
    const payload = await this.export()
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`koma-backup-${Date.now()}.json`]
    options.fileSuffixChoices = [AppStrings.get('backup_file_choice_json')]
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.save(options)
    if (result.length === 0) {
      DiagnosticLogger.info('backup', 'export_cancel', '[Backup] step=export_cancel')
      return undefined
    }
    writePickedBackupText(result[0], payload)
    DiagnosticLogger.info('backup', 'export_save', '[Backup] step=export_save')
    return result[0]
  }

  private writeLocalBackup(fileName: string, payload: string): BackupLocalFileRecord {
    ensureDir(this.localBackupsDir())
    const targetName = this.uniqueLocalBackupFileName(fileName)
    writeAppTextFile(this.localBackupPath(targetName), payload)
    const record = this.readLocalBackupRecord(targetName)
    if (record === undefined) {
      throw new Error('backup_local_write_failed')
    }
    return record
  }

  private readLocalBackupRecord(fileName: string, strictRead: boolean = false): BackupLocalFileRecord | undefined {
    const safeName = this.requireLocalBackupFileName(fileName)
    const path = this.localBackupPath(safeName)
    if (!fs.accessSync(path)) {
      return undefined
    }
    try {
      const payload = fs.readTextSync(path, { encoding: 'utf-8' })
      return {
        fileName: safeName,
        displayName: safeName.replace(/\.koma-backup$/, '').replace(/\.json$/, ''),
        sizeBytes: fs.statSync(path).size,
        preview: this.preview(payload),
      }
    } catch (_error) {
      if (strictRead) {
        throw new Error('backup_local_read_failed')
      }
      return undefined
    }
  }

  private requireLocalBackupFileName(fileName: string): string {
    const normalized = fileName.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, '')
    if (!isLocalBackupFileName(normalized)) {
      throw new Error('backup_local_file_invalid')
    }
    return normalized
  }

  private uniqueLocalBackupFileName(fileName: string, existingName?: string): string {
    const safeName = this.requireLocalBackupFileName(fileName)
    const extension = backupFileExtension(safeName)
    const baseName = safeName.substring(0, safeName.length - extension.length)
    let candidate = safeName
    let index = 2
    while (fs.accessSync(this.localBackupPath(candidate)) && candidate !== existingName) {
      candidate = `${baseName}-${index}${extension}`
      index += 1
    }
    return candidate
  }

  async exportEncryptedToPicker(passphrase: string): Promise<string | undefined> {
    const payload = await this.exportEncrypted(passphrase)
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`koma-backup-${Date.now()}.koma-backup`]
    options.fileSuffixChoices = [AppStrings.get('backup_file_choice_encrypted')]
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.save(options)
    if (result.length === 0) {
      DiagnosticLogger.info('backup', 'export_encrypted_cancel', '[Backup] step=export_encrypted_cancel')
      return undefined
    }
    writePickedBackupText(result[0], payload)
    DiagnosticLogger.info('backup', 'export_encrypted_save', '[Backup] step=export_encrypted_save')
    return result[0]
  }

  async importFromPicker(): Promise<boolean> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.select(options)
    if (result.length === 0) {
      DiagnosticLogger.info('backup', 'import_cancel', '[Backup] step=import_cancel')
      return false
    }
    const payload = readPickedBackupText(result[0])
    await this.import(payload)
    DiagnosticLogger.info('backup', 'import_select', '[Backup] step=import_select')
    return true
  }

  async selectImportPreviewFromPicker(): Promise<BackupImportSelectionPreview | undefined> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.select(options)
    if (result.length === 0) {
      DiagnosticLogger.info('backup', 'preview_cancel', '[Backup] step=preview_cancel')
      return undefined
    }
    const payload = readPickedBackupText(result[0])
    const preview = this.preview(payload)
    DiagnosticLogger.info('backup', 'preview_select', '[Backup] step=preview_select')
    return {
      payload,
      preview,
    }
  }

  private libraryPath(): string {
    return joinBackupPath(this.context.filesDir, LIBRARY_STORE_PERSISTENCE_FILE_NAME)
  }

  private localBackupsDir(): string {
    return joinBackupPath(this.context.filesDir, BACKUP_LOCAL_DIR_NAME)
  }

  private localBackupPath(fileName: string): string {
    return joinBackupPath(this.localBackupsDir(), this.requireLocalBackupFileName(fileName))
  }

  private readerProgressPath(): string {
    return joinBackupPath(this.context.filesDir, READER_PROGRESS_PERSISTENCE_FILE_NAME)
  }

  private downloadQueuePath(): string {
    return joinBackupPath(joinBackupPath(this.context.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME), OFFLINE_DOWNLOAD_QUEUE_FILE_NAME)
  }

  private async exportRemoteServers(): Promise<RemoteServerBackupDocument> {
    const snapshot = await new RemoteServerStore(this.context).exportConfiguration()
    return {
      endpointIdentities: snapshot.endpointIdentities,
      komgaServer: snapshot.komgaServer,
      komgaCredential: '',
      kavitaServer: snapshot.kavitaServer,
      kavitaCredential: '',
      webDavServer: snapshot.webDavServer,
      webDavCredential: '',
      opdsServer: snapshot.opdsServer,
      opdsCredential: '',
    }
  }

  private async importRemoteServers(remoteServers: RemoteServerBackupDocument): Promise<void> {
    const store = await preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
    const backup = remoteServers ?? {
      komgaServer: '',
      komgaCredential: '',
      kavitaServer: '',
      kavitaCredential: '',
      webDavServer: '',
      webDavCredential: '',
      opdsServer: '',
      opdsCredential: '',
    }
    await this.putOrDelete(store, REMOTE_SERVER_ENDPOINT_IDENTITIES_KEY, backup.endpointIdentities ?? '')
    await this.putOrDelete(store, KOMGA_SERVER_KEY, backup.komgaServer)
    await this.putOrDelete(store, KOMGA_CREDENTIAL_KEY, backup.komgaCredential)
    await this.putOrDelete(store, KAVITA_SERVER_KEY, backup.kavitaServer)
    await this.putOrDelete(store, KAVITA_CREDENTIAL_KEY, backup.kavitaCredential)
    await this.putOrDelete(store, WEBDAV_SERVER_KEY, backup.webDavServer)
    await this.putOrDelete(store, WEBDAV_CREDENTIAL_KEY, backup.webDavCredential)
    await this.putOrDelete(store, OPDS_SERVER_KEY, backup.opdsServer)
    await this.putOrDelete(store, OPDS_CREDENTIAL_KEY, backup.opdsCredential)
    await store.flush()
  }


  private async importSettings(settings: ReaderPreferences | undefined): Promise<void> {
    if (settings === undefined) {
      return
    }
    const nextSettings: ReaderPreferences = {
      readerImplementation: settings.readerImplementation ?? DEFAULT_READER_PREFERENCES.readerImplementation,
      pageMode: settings.pageMode ?? DEFAULT_READER_PREFERENCES.pageMode,
      readingDirection: settings.readingDirection ?? DEFAULT_READER_PREFERENCES.readingDirection,
      themeMode: settings.themeMode ?? DEFAULT_READER_PREFERENCES.themeMode,
      backgroundMode: settings.backgroundMode ?? DEFAULT_READER_PREFERENCES.backgroundMode,
      showProgressControls: settings.showProgressControls ?? DEFAULT_READER_PREFERENCES.showProgressControls,
      keepScreenAwake: settings.keepScreenAwake ?? DEFAULT_READER_PREFERENCES.keepScreenAwake,
      fullscreen: settings.fullscreen ?? DEFAULT_READER_PREFERENCES.fullscreen,
      imageFitMode: settings.imageFitMode ?? DEFAULT_READER_PREFERENCES.imageFitMode,
      imageScalingQuality: settings.imageScalingQuality ?? DEFAULT_READER_PREFERENCES.imageScalingQuality,
      showPageNumber: settings.showPageNumber ?? DEFAULT_READER_PREFERENCES.showPageNumber,
      pageTurnAnimation: settings.pageTurnAnimation ?? DEFAULT_READER_PREFERENCES.pageTurnAnimation,
      doubleTapZoomEnabled: settings.doubleTapZoomEnabled ?? DEFAULT_READER_PREFERENCES.doubleTapZoomEnabled,
      doubleTapIntervalMs: settings.doubleTapIntervalMs ?? DEFAULT_READER_PREFERENCES.doubleTapIntervalMs,
      autoPageSeconds: settings.autoPageSeconds ?? DEFAULT_READER_PREFERENCES.autoPageSeconds,
      preloadPages: settings.preloadPages ?? DEFAULT_READER_PREFERENCES.preloadPages,
      spreadLayoutMode: settings.spreadLayoutMode ?? DEFAULT_READER_PREFERENCES.spreadLayoutMode,
      columnMode: settings.columnMode ?? DEFAULT_READER_PREFERENCES.columnMode,
      tapZonePreset: settings.tapZonePreset ?? DEFAULT_READER_PREFERENCES.tapZonePreset,
      tapZoneInvert: settings.tapZoneInvert ?? DEFAULT_READER_PREFERENCES.tapZoneInvert,
      pageGapMode: settings.pageGapMode ?? DEFAULT_READER_PREFERENCES.pageGapMode,
      trimPageMarginsEnabled: settings.trimPageMarginsEnabled ?? DEFAULT_READER_PREFERENCES.trimPageMarginsEnabled,
      cropStrength: settings.cropStrength ?? DEFAULT_READER_PREFERENCES.cropStrength,
      superResolutionEnabled: settings.superResolutionEnabled ?? DEFAULT_READER_PREFERENCES.superResolutionEnabled,
      superResolutionModel: settings.superResolutionModel ?? DEFAULT_READER_PREFERENCES.superResolutionModel,
      superResolutionBackend: settings.superResolutionBackend ?? DEFAULT_READER_PREFERENCES.superResolutionBackend,
      superResolutionMaxHeight: settings.superResolutionMaxHeight ?? DEFAULT_READER_PREFERENCES.superResolutionMaxHeight,
      wideImageMode: settings.wideImageMode ?? DEFAULT_READER_PREFERENCES.wideImageMode,
      volumeKeyNavigationEnabled: settings.volumeKeyNavigationEnabled ?? DEFAULT_READER_PREFERENCES.volumeKeyNavigationEnabled,
      volumeKeyBehavior: settings.volumeKeyBehavior ?? DEFAULT_READER_PREFERENCES.volumeKeyBehavior,
    }
    await new ReaderPreferencesStore(this.context).saveForBackupRestore(nextSettings)
  }

  private importSourceSettings(sourceSettings: Record<string, SourceSettingsRecord> | undefined): void {
    if (sourceSettings === undefined) {
      return
    }
    if (sourceSettings === null || Array.isArray(sourceSettings) || typeof sourceSettings !== 'object') {
      throw new Error('Invalid backup source settings')
    }
    appSourceSettingsStore.importAll(sourceSettings)
  }

  private importSourceFilterPreferences(sourceFilterPreferences: Record<string, SourceFilterPreferenceSourceRecord> | undefined): void {
    if (sourceFilterPreferences === undefined) {
      return
    }
    if (sourceFilterPreferences === null || Array.isArray(sourceFilterPreferences) || typeof sourceFilterPreferences !== 'object') {
      throw new Error('Invalid backup source filter preferences')
    }
    appSourceFilterPreferencesStore.importAll(sourceFilterPreferences)
  }

  private async putOrDelete(store: preferences.Preferences, key: string, value: string | undefined): Promise<void> {
    if (value === undefined || value.length === 0) {
      await store.delete(key)
      return
    }
    await store.put(key, value)
  }

  private async automaticPreferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, BACKUP_AUTOMATIC_PREFS_STORE_NAME)
  }

  private async contentPreferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, BACKUP_CONTENT_PREFS_STORE_NAME)
  }

  private async runAutomaticLocalBackupWithPreferences(
    now: number,
  ): Promise<BackupAutomaticRunResult> {
    let created: BackupLocalFileRecord | undefined = undefined
    try {
      created = await this.exportLocal()
      // A settings edit during export must survive. Only the completion fields belong to this job.
      let deletedCount = 0
      const nextPreferences = await queueAutomaticPreferences(async (): Promise<BackupAutomaticPreferences> => {
        const current = await this.readAutomaticPreferences()
        if (current.directoryUri !== undefined && current.directoryUri.length > 0) {
          await writeAutomaticBackupToDirectory(current.directoryUri,
            await fs.readText(this.localBackupPath(created!.fileName)), current.retentionCount, now)
        }
        deletedCount = await this.pruneLocalBackups(current.retentionCount)
        current.lastRunAt = normalizeBackupAutomaticLastRunAt(now)
        current.lastFailureCode = ''
        await this.persistAutomaticPreferences(current)
        return current
      })
      DiagnosticLogger.info('backup', 'auto_export', `[Backup] step=auto_export deleted=${deletedCount}`)
      return {
        ran: true,
        created,
        deletedCount,
        preferences: nextPreferences,
      }
    } catch (_error) {
      const nextPreferences = await queueAutomaticPreferences(async (): Promise<BackupAutomaticPreferences> => {
        const current = await this.readAutomaticPreferences()
        // The export already exists even when retention cleanup fails; do not recreate it on every foreground.
        if (created !== undefined) {
          current.lastRunAt = normalizeBackupAutomaticLastRunAt(now)
        }
        current.lastFailureCode = 'backup_auto_export_failed'
        await this.persistAutomaticPreferences(current)
        return current
      })
      DiagnosticLogger.error('backup', 'auto_export_failed', '[Backup] step=auto_export_failed code=backup_auto_export_failed')
      return {
        ran: false,
        deletedCount: 0,
        preferences: nextPreferences,
        skippedReason: 'failed',
        failureCode: 'backup_auto_export_failed',
      }
    }
  }

  private async exportSourceIndexUrl(): Promise<string | undefined> {
    const url = await new SourceIndexService(this.context).loadSavedUrl()
    return url.length > 0 ? url : undefined
  }

  private async importSourceIndexUrl(url: string | undefined): Promise<void> {
    if (url === undefined || url.trim().length === 0) {
      return
    }
    const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
    await store.put(SOURCE_INDEX_URL_KEY, url.trim())
    await store.flush()
  }

  private async exportTrackerMappings(): Promise<ComicTrackerMapping[]> {
    return (await new TrackerPreferencesStore(this.context).load()).comicMappings
  }

  private async importTrackerMappings(mappings: ComicTrackerMapping[] | undefined): Promise<void> {
    if (mappings === undefined) {
      return
    }
    if (!Array.isArray(mappings)) {
      throw new Error('Invalid backup tracker mappings')
    }
    const store = await preferences.getPreferences(this.context, TRACKER_PREFERENCES_STORE_NAME)
    await store.put(TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify(normalizeComicTrackerMappings(mappings)))
    await store.flush()
  }

  private async exportTrackerSyncPreferences(): Promise<BackupTrackerSyncPreferences> {
    const current = await new TrackerPreferencesStore(this.context).load()
    return { autoSyncEnabled: current.autoSyncEnabled, updateStrategy: current.updateStrategy }
  }

  private async importTrackerSyncPreferences(preferencesValue: BackupTrackerSyncPreferences | undefined): Promise<void> {
    const normalized = normalizeBackupTrackerSyncPreferences(preferencesValue)
    if (normalized === undefined) {
      return
    }
    const store = await preferences.getPreferences(this.context, TRACKER_PREFERENCES_STORE_NAME)
    await store.put(TRACKER_AUTO_SYNC_ENABLED_KEY, normalized.autoSyncEnabled)
    await store.put(TRACKER_UPDATE_STRATEGY_KEY, normalized.updateStrategy)
    await store.flush()
  }

  private importDownloadQueue(downloadQueue: string | undefined): void {
    if (downloadQueue === undefined || downloadQueue.length === 0) {
      return
    }
    const payload = normalizeBackupDownloadQueuePayload(downloadQueue)
    ensureDir(joinBackupPath(this.context.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME))
    writeAppTextFile(this.downloadQueuePath(), payload)
  }
}
