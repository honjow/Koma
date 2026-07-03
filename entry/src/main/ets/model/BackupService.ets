import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION,
  assertValidLibraryStoreJson,
} from './LibraryPersistence'
import {
  READER_PROGRESS_PERSISTENCE_FILE_NAME,
  READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
} from './ReaderSessionStore'
import {
  DEFAULT_READER_PREFERENCES,
  ReaderPreferences,
  ReaderPreferencesStore,
} from './ReaderPreferencesStore'
import {
  SourcePackageBackupEntry,
  exportInstalledSourcePackages,
  restoreSourcePackagesFromBackup,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
  configureSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
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
} from './OfflineDownloadQueueStore'
import {
  LocalLibraryMetadataBackupEntry,
  exportLocalLibraryMetadataBackupEntries,
  restoreLocalLibraryMetadataBackupEntries,
} from './LocalLibraryMetadataService'

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
]
export const BACKUP_ENCRYPTION_STATE: string = 'unencrypted'
const REMOTE_SERVER_STORE_NAME: string = 'koma_remote_servers_v1'
const SOURCE_INDEX_PREFS_STORE_NAME: string = 'koma_source_package_manager_v1'
const SOURCE_INDEX_URL_KEY: string = 'source_index.url'
const KOMGA_SERVER_KEY: string = 'komga.server'
const KOMGA_CREDENTIAL_KEY: string = 'komga.credential'
const WEBDAV_SERVER_KEY: string = 'webdav.server'
const WEBDAV_CREDENTIAL_KEY: string = 'webdav.credential'
const OPDS_SERVER_KEY: string = 'opds.server'
const OPDS_CREDENTIAL_KEY: string = 'opds.credential'

interface RemoteServerBackupDocument {
  komgaServer: string
  komgaCredential: string
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
  settings?: ReaderPreferences
  sourceIndexUrl?: string
  downloadQueue?: string
}

export interface BackupImportPreview {
  schemaVersion: number
  exportedAtText: string
  encryptionText: string
  encrypted: boolean
  decrypted: boolean
  algorithm: string
  kdfId: string
  libraryItemCount: number
  progressCount: number
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

export function backupIncludedDomainLabels(): string[] {
  return [
    AppStrings.get('backup_domain_library_categories'),
    AppStrings.get('backup_domain_progress'),
    AppStrings.get('backup_domain_remote_servers'),
    AppStrings.get('backup_domain_source_packages'),
    AppStrings.get('backup_domain_reader_preferences'),
    AppStrings.get('backup_domain_download_queue'),
  ]
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

function writeText(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
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
    const failureReasonCode = normalizeBackupString(row['failureReasonCode'])
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

function formatBackupExportedAt(exportedAt: number | undefined): string {
  if (exportedAt === undefined || !Number.isFinite(exportedAt) || exportedAt <= 0) {
    return AppStrings.get('backup_preview_not_provided')
  }
  return new Date(exportedAt).toLocaleString()
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
    exportedAtText: publicPreview.exportedAtText,
    encryptionText: AppStrings.get('backup_encryption_encrypted_preview_needed'),
    encrypted: true,
    decrypted: false,
    algorithm: publicPreview.algorithm,
    kdfId: publicPreview.kdfId,
    libraryItemCount: 0,
    progressCount: 0,
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

export class BackupService {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
    configureSourceSettingsStore(context)
  }

  async export(): Promise<string> {
    return JSON.stringify(await this.buildBackupDocument(BACKUP_SCHEMA_VERSION))
  }

  async exportEncrypted(passphrase: string): Promise<string> {
    const document = await this.buildBackupDocument(BACKUP_ENCRYPTED_SCHEMA_VERSION)
    const payload = await new BackupEncryptionService().encrypt(JSON.stringify(document), passphrase)
    console.info('[Backup] step=export_encrypted')
    return payload
  }

  private async buildBackupDocument(schemaVersion: number): Promise<KomaBackupDocument> {
    const document: KomaBackupDocument = {
      schemaVersion,
      exportedAt: Date.now(),
      encryption: {
        state: BACKUP_ENCRYPTION_STATE,
        algorithm: 'none',
      },
      libraryStore: readTextIfExists(this.libraryPath(), emptyLibraryStorePayload()),
      readingProgress: readTextIfExists(this.readerProgressPath(), emptyReaderProgressPayload()),
      remoteServers: await this.exportRemoteServers(),
      sourcePackages: exportInstalledSourcePackages(),
      sourceSettings: appSourceSettingsStore.exportAll(),
      settings: await new ReaderPreferencesStore(this.context).load(),
      sourceIndexUrl: await this.exportSourceIndexUrl(),
    }
    const downloadQueue = readTextIfExists(this.downloadQueuePath(), '')
    if (downloadQueue.length > 0) {
      document.downloadQueue = normalizeBackupDownloadQueuePayload(downloadQueue)
    }
    document.localLibraryMetadata = exportLocalLibraryMetadataBackupEntries(document.libraryStore)
    console.info('[Backup] step=export_json')
    return document
  }

  async import(json: string): Promise<void> {
    await this.importDocument(json, false)
  }

  async importDecrypted(json: string): Promise<void> {
    await this.importDocument(json, true)
  }

  private async importDocument(json: string, allowEncryptedContentSchema: boolean): Promise<void> {
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
    const libraryStorePayload = restoreLocalLibraryMetadataBackupEntries(document.libraryStore, document.localLibraryMetadata)
    assertValidLibraryStoreJson(libraryStorePayload)
    JSON.parse(document.readingProgress)
    writeText(this.libraryPath(), libraryStorePayload)
    writeText(this.readerProgressPath(), document.readingProgress)
    await this.importRemoteServers(document.remoteServers)
    if (document.schemaVersion >= BACKUP_SCHEMA_VERSION) {
      this.importSourceSettings(document.sourceSettings)
      await this.importSourceIndexUrl(document.sourceIndexUrl)
      this.importDownloadQueue(document.downloadQueue)
    }
    if (document.schemaVersion >= BACKUP_SCHEMA_VERSION_V2) {
      await this.importSourcePackages(document.sourcePackages)
      await this.importSettings(document.settings)
    }
    console.info('[Backup] step=import_json')
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
    const libraryStore = asJsonObject(JSON.parse(document.libraryStore) as Object, 'library')
    const readingProgress = asJsonObject(JSON.parse(document.readingProgress) as Object, 'progress')
    return {
      schemaVersion: document.schemaVersion,
      exportedAtText: formatBackupExportedAt(document.exportedAt),
      encryptionText: formatBackupEncryption(document.encryption),
      encrypted: false,
      decrypted: true,
      algorithm: 'none',
      kdfId: '',
      libraryItemCount: arrayFieldCount(libraryStore, 'comics'),
      progressCount: arrayFieldCount(readingProgress, 'progress'),
      settingsCount: countReaderPreferences(document.settings),
      categoryCount: countLibraryCategories(libraryStore),
      downloadQueueCount: countBackupDownloadQueueEntries(document.downloadQueue),
      trackerMappingCount: 0,
      sourcePackageCount: Array.isArray(document.sourcePackages) ? document.sourcePackages.length : 0,
      sourceSettingsCount: document.sourceSettings === undefined ? 0 : Object.keys(document.sourceSettings).length,
      hasDownloadQueueCount: document.downloadQueue !== undefined,
      hasTrackerMappingCount: false,
    }
  }

  async decryptPreview(json: string, passphrase: string): Promise<BackupImportSelectionPreview> {
    const plaintext = await new BackupEncryptionService().decrypt(json, passphrase)
    const preview = this.previewDecrypted(plaintext)
    return {
      payload: plaintext,
      preview: {
        schemaVersion: preview.schemaVersion,
        exportedAtText: preview.exportedAtText,
        algorithm: preview.algorithm,
        kdfId: preview.kdfId,
        libraryItemCount: preview.libraryItemCount,
        progressCount: preview.progressCount,
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
      console.info('[Backup] step=export_cancel')
      return undefined
    }
    writeText(result[0], payload)
    console.info('[Backup] step=export_save')
    return result[0]
  }

  async exportEncryptedToPicker(passphrase: string): Promise<string | undefined> {
    const payload = await this.exportEncrypted(passphrase)
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`koma-backup-${Date.now()}.koma-backup`]
    options.fileSuffixChoices = [AppStrings.get('backup_file_choice_encrypted')]
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.save(options)
    if (result.length === 0) {
      console.info('[Backup] step=export_encrypted_cancel')
      return undefined
    }
    writeText(result[0], payload)
    console.info('[Backup] step=export_encrypted_save')
    return result[0]
  }

  async importFromPicker(): Promise<boolean> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.select(options)
    if (result.length === 0) {
      console.info('[Backup] step=import_cancel')
      return false
    }
    const payload = fs.readTextSync(result[0], { encoding: 'utf-8' })
    await this.import(payload)
    console.info('[Backup] step=import_select')
    return true
  }

  async selectImportPreviewFromPicker(): Promise<BackupImportSelectionPreview | undefined> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.select(options)
    if (result.length === 0) {
      console.info('[Backup] step=preview_cancel')
      return undefined
    }
    const payload = fs.readTextSync(result[0], { encoding: 'utf-8' })
    const preview = this.preview(payload)
    console.info('[Backup] step=preview_select')
    return {
      payload,
      preview,
    }
  }

  private libraryPath(): string {
    return joinBackupPath(this.context.filesDir, LIBRARY_STORE_PERSISTENCE_FILE_NAME)
  }

  private readerProgressPath(): string {
    return joinBackupPath(this.context.filesDir, READER_PROGRESS_PERSISTENCE_FILE_NAME)
  }

  private downloadQueuePath(): string {
    return joinBackupPath(joinBackupPath(this.context.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME), OFFLINE_DOWNLOAD_QUEUE_FILE_NAME)
  }

  private async exportRemoteServers(): Promise<RemoteServerBackupDocument> {
    const store = await preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
    return {
      komgaServer: await store.get(KOMGA_SERVER_KEY, '') as string,
      komgaCredential: '',
      webDavServer: await store.get(WEBDAV_SERVER_KEY, '') as string,
      webDavCredential: '',
      opdsServer: await store.get(OPDS_SERVER_KEY, '') as string,
      opdsCredential: '',
    }
  }

  private async importRemoteServers(remoteServers: RemoteServerBackupDocument): Promise<void> {
    const store = await preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
    const backup = remoteServers ?? {
      komgaServer: '',
      komgaCredential: '',
      webDavServer: '',
      webDavCredential: '',
      opdsServer: '',
      opdsCredential: '',
    }
    await this.putOrDelete(store, KOMGA_SERVER_KEY, backup.komgaServer)
    await this.putOrDelete(store, KOMGA_CREDENTIAL_KEY, backup.komgaCredential)
    await this.putOrDelete(store, WEBDAV_SERVER_KEY, backup.webDavServer)
    await this.putOrDelete(store, WEBDAV_CREDENTIAL_KEY, backup.webDavCredential)
    await this.putOrDelete(store, OPDS_SERVER_KEY, backup.opdsServer)
    await this.putOrDelete(store, OPDS_CREDENTIAL_KEY, backup.opdsCredential)
    await store.flush()
  }

  private async importSourcePackages(sourcePackages: SourcePackageBackupEntry[] | undefined): Promise<void> {
    if (sourcePackages === undefined) {
      return
    }
    if (!Array.isArray(sourcePackages)) {
      throw new Error('Invalid backup source packages')
    }
    const restored = await restoreSourcePackagesFromBackup(this.context, sourcePackages)
    if (!restored.ok) {
      throw new Error('Invalid backup source packages: ' + (restored.reasonCode ?? 'restore_failed'))
    }
  }

  private async importSettings(settings: ReaderPreferences | undefined): Promise<void> {
    if (settings === undefined) {
      return
    }
    const nextSettings: ReaderPreferences = {
      pageMode: settings.pageMode ?? DEFAULT_READER_PREFERENCES.pageMode,
      readingDirection: settings.readingDirection ?? DEFAULT_READER_PREFERENCES.readingDirection,
      themeMode: settings.themeMode ?? DEFAULT_READER_PREFERENCES.themeMode,
      backgroundMode: settings.backgroundMode ?? DEFAULT_READER_PREFERENCES.backgroundMode,
      showProgressControls: settings.showProgressControls ?? DEFAULT_READER_PREFERENCES.showProgressControls,
      keepScreenAwake: settings.keepScreenAwake ?? DEFAULT_READER_PREFERENCES.keepScreenAwake,
      imageFitMode: settings.imageFitMode ?? DEFAULT_READER_PREFERENCES.imageFitMode,
      tapNavigationEnabled: settings.tapNavigationEnabled ?? DEFAULT_READER_PREFERENCES.tapNavigationEnabled,
      tapZonePreset: settings.tapZonePreset ?? DEFAULT_READER_PREFERENCES.tapZonePreset,
      pageGapMode: settings.pageGapMode ?? DEFAULT_READER_PREFERENCES.pageGapMode,
      trimPageMarginsEnabled: settings.trimPageMarginsEnabled ?? DEFAULT_READER_PREFERENCES.trimPageMarginsEnabled,
      wideImageMode: settings.wideImageMode ?? DEFAULT_READER_PREFERENCES.wideImageMode,
      volumeKeyNavigationEnabled: settings.volumeKeyNavigationEnabled ?? DEFAULT_READER_PREFERENCES.volumeKeyNavigationEnabled,
    }
    await new ReaderPreferencesStore(this.context).save(nextSettings)
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

  private async putOrDelete(store: preferences.Preferences, key: string, value: string | undefined): Promise<void> {
    if (value === undefined || value.length === 0) {
      await store.delete(key)
      return
    }
    await store.put(key, value)
  }

  private async exportSourceIndexUrl(): Promise<string | undefined> {
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      const url = await store.get(SOURCE_INDEX_URL_KEY, '') as string
      return typeof url === 'string' && url.trim().length > 0 ? url.trim() : undefined
    } catch (_err) {
      return undefined
    }
  }

  private async importSourceIndexUrl(url: string | undefined): Promise<void> {
    if (url === undefined || url.trim().length === 0) {
      return
    }
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      await store.put(SOURCE_INDEX_URL_KEY, url.trim())
      await store.flush()
    } catch (_err) {
    }
  }

  private importDownloadQueue(downloadQueue: string | undefined): void {
    if (downloadQueue === undefined || downloadQueue.length === 0) {
      return
    }
    const payload = normalizeBackupDownloadQueuePayload(downloadQueue)
    ensureDir(joinBackupPath(this.context.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME))
    writeText(this.downloadQueuePath(), payload)
  }
}
