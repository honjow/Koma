import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import {
  LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION,
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

const BACKUP_SCHEMA_VERSION: number = 3
const BACKUP_SCHEMA_VERSION_V2: number = 2
const BACKUP_SCHEMA_VERSION_V1: number = 1
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

interface KomaBackupDocument {
  schemaVersion: number
  exportedAt: number
  libraryStore: string
  readingProgress: string
  remoteServers: RemoteServerBackupDocument
  sourcePackages?: SourcePackageBackupEntry[]
  sourceSettings?: Record<string, SourceSettingsRecord>
  settings?: ReaderPreferences
  sourceIndexUrl?: string
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

export class BackupService {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
    configureSourceSettingsStore(context)
  }

  async export(): Promise<string> {
    const document: KomaBackupDocument = {
      schemaVersion: BACKUP_SCHEMA_VERSION,
      exportedAt: Date.now(),
      libraryStore: readTextIfExists(this.libraryPath(), emptyLibraryStorePayload()),
      readingProgress: readTextIfExists(this.readerProgressPath(), emptyReaderProgressPayload()),
      remoteServers: await this.exportRemoteServers(),
      sourcePackages: exportInstalledSourcePackages(),
      sourceSettings: appSourceSettingsStore.exportAll(),
      settings: await new ReaderPreferencesStore(this.context).load(),
      sourceIndexUrl: await this.exportSourceIndexUrl(),
    }
    console.info('[Backup] step=export_json')
    return JSON.stringify(document)
  }

  async import(json: string): Promise<void> {
    const document = JSON.parse(json) as KomaBackupDocument
    if (document.schemaVersion !== BACKUP_SCHEMA_VERSION &&
      document.schemaVersion !== BACKUP_SCHEMA_VERSION_V2 &&
      document.schemaVersion !== BACKUP_SCHEMA_VERSION_V1) {
      throw new Error(`Unsupported backup schema version: ${document.schemaVersion}`)
    }
    if (typeof document.libraryStore !== 'string' || typeof document.readingProgress !== 'string') {
      throw new Error('Invalid backup payload')
    }
    JSON.parse(document.libraryStore)
    JSON.parse(document.readingProgress)
    writeText(this.libraryPath(), document.libraryStore)
    writeText(this.readerProgressPath(), document.readingProgress)
    await this.importRemoteServers(document.remoteServers)
    if (document.schemaVersion >= BACKUP_SCHEMA_VERSION) {
      this.importSourceSettings(document.sourceSettings)
      await this.importSourceIndexUrl(document.sourceIndexUrl)
    }
    if (document.schemaVersion >= BACKUP_SCHEMA_VERSION_V2) {
      await this.importSourcePackages(document.sourcePackages)
      await this.importSettings(document.settings)
    }
    console.info('[Backup] step=import_json')
  }

  async exportToPicker(): Promise<string | undefined> {
    const payload = await this.export()
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`koma-backup-${Date.now()}.json`]
    options.fileSuffixChoices = ['JSON 文件|.json']
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.save(options)
    if (result.length === 0) {
      console.info('[Backup] step=export_cancel')
      return undefined
    }
    writeText(result[0], payload)
    console.info('[Backup] step=export_save uri=' + result[0])
    return result[0]
  }

  async importFromPicker(): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    const documentPicker = new picker.DocumentViewPicker(this.context)
    const result = await documentPicker.select(options)
    if (result.length === 0) {
      console.info('[Backup] step=import_cancel')
      return
    }
    const payload = fs.readTextSync(result[0], { encoding: 'utf-8' })
    await this.import(payload)
    console.info('[Backup] step=import_select uri=' + result[0])
  }

  private libraryPath(): string {
    return joinBackupPath(this.context.filesDir, LIBRARY_STORE_PERSISTENCE_FILE_NAME)
  }

  private readerProgressPath(): string {
    return joinBackupPath(this.context.filesDir, READER_PROGRESS_PERSISTENCE_FILE_NAME)
  }

  private async exportRemoteServers(): Promise<RemoteServerBackupDocument> {
    const store = await preferences.getPreferences(this.context, REMOTE_SERVER_STORE_NAME)
    return {
      komgaServer: await store.get(KOMGA_SERVER_KEY, '') as string,
      komgaCredential: await store.get(KOMGA_CREDENTIAL_KEY, '') as string,
      webDavServer: await store.get(WEBDAV_SERVER_KEY, '') as string,
      webDavCredential: await store.get(WEBDAV_CREDENTIAL_KEY, '') as string,
      opdsServer: await store.get(OPDS_SERVER_KEY, '') as string,
      opdsCredential: await store.get(OPDS_CREDENTIAL_KEY, '') as string,
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
}
