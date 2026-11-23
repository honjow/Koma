import { backupUserDataDatabase, restoreUserDataDatabase } from './UserDataDatabase'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { writeAppTextFile } from './AppFileTextPersistence'
import { AppFilesLibraryStorePersistenceAdapter, LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  usesLibraryDatabase, writeLiveLibrarySnapshot } from './LibraryPersistence'
import { READER_PROGRESS_PERSISTENCE_FILE_NAME, usesReaderDatabase, writeLiveReaderSnapshot } from './ReaderSessionStore'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { APPLICATION_SETTINGS_BACKUP_STORES } from './ApplicationSettingsBackup'
import { overlayMigratedCheckpointPreferences, recoverMigratedCheckpointPreferences } from './MigratedPreferenceRecords'
import { readSourceConfigurationSnapshot, restoreSourceConfigurationSnapshot,
  usesSourceConfigurationDatabase } from '../sourceRuntime/SourceConfigurationDatabases'
import { SOURCE_FILTERS_PATH, SOURCE_SETTINGS_PATH } from '../sourceRuntime/SourcePreferencePersistence'
import { SOURCE_REGISTRY_PATH } from '../sourceRuntime/SourceRegistryDatabase'
import { IMAGE_RULE_LEGACY_PATH, readImageRuleDatabaseCheckpoint, restoreImageRuleDatabaseCheckpoint,
  usesImageRuleDatabase } from './ImageRuleDatabase'
import { PUBLIC_CONTENT_QUEUE_PRIVATE_PATH, SANDBOX_CONTENT_QUEUE_PATH, readOfflineQueueDatabaseSnapshot,
  restoreOfflineQueueDatabaseSnapshot, usesOfflineQueueDatabase } from './OfflineDownloadQueueStore'

const CHECKPOINT_FILE: string = 'backup-restore-checkpoint.v1.json'
const CHECKPOINT_FILES: string = 'backup-restore-checkpoint-files'
const FILE_CHECKPOINT_VERSION: number = 7
const DATABASE_CHECKPOINT_VERSION: number = 8
const DATABASE_IMAGE: string = 'business.rdb'
const RESTORE_FILES_V2: string[] = [
  'library-store.v1.json',
  'reader-sessions.v1.json',
  SOURCE_SETTINGS_PATH,
  SOURCE_FILTERS_PATH,
  SANDBOX_CONTENT_QUEUE_PATH,
  SOURCE_REGISTRY_PATH,
]
const RESTORE_FILES_V3: string[] = RESTORE_FILES_V2.concat(['source-runtime/source-setting-observations.json'])
const RESTORE_FILES_V4: string[] = RESTORE_FILES_V3.concat([IMAGE_RULE_LEGACY_PATH])
const RESTORE_FILES: string[] = RESTORE_FILES_V4.concat([PUBLIC_CONTENT_QUEUE_PRIVATE_PATH])

function isDatabaseImage(filesDir: string, name: string): boolean {
  return (name === LIBRARY_STORE_PERSISTENCE_FILE_NAME && usesLibraryDatabase(filesDir)) ||
    (name === READER_PROGRESS_PERSISTENCE_FILE_NAME && usesReaderDatabase(filesDir)) ||
    usesOfflineQueueDatabase(filesDir, name) || usesSourceConfigurationDatabase(filesDir, name) ||
    (name === IMAGE_RULE_LEGACY_PATH && usesImageRuleDatabase(filesDir))
}
const RESTORE_PREFERENCES_V1: string[] = [
  'koma_remote_servers_v1',
  'koma_source_package_manager_v1',
  'koma_tracker_preferences_v1',
  'koma_reader_preferences_v1',
]
// Historical writers added these groups without always changing the checkpoint
// version. Accept only their exact deployed ordered domains, never a subset
// chosen by an incoming checkpoint. New coverage must not invalidate recovery.
const RESTORE_APPLICATION_PREFERENCES_V2: string[] = [
  'koma_app_preferences_v1', 'koma_appearance_preferences_v1', 'koma_library_filter_preferences',
  'koma_library_update_preferences_v1', 'koma_reader_remote_image_cache_v1',
  'koma_backup_automatic_v1', 'koma_backup_content_v1',
]
const RESTORE_PREFERENCES_V2: string[] = RESTORE_PREFERENCES_V1.concat(RESTORE_APPLICATION_PREFERENCES_V2)
const RESTORE_PREFERENCES_V3: string[][] = [
  RESTORE_PREFERENCES_V2,
  RESTORE_PREFERENCES_V1.concat(['koma_library_automation_v1'], RESTORE_APPLICATION_PREFERENCES_V2),
  RESTORE_PREFERENCES_V1.concat(['koma_chapter_list_preferences_v1', 'koma_library_automation_v1'], RESTORE_APPLICATION_PREFERENCES_V2),
  RESTORE_PREFERENCES_V1.concat(['koma_source_catalog_filters_v1', 'koma_chapter_list_preferences_v1',
    'koma_library_automation_v1'], RESTORE_APPLICATION_PREFERENCES_V2),
]
const RESTORE_PREFERENCES_V4: string[] = RESTORE_PREFERENCES_V3[3]
const RESTORE_PREFERENCES: string[] = RESTORE_PREFERENCES_V4.concat(
  APPLICATION_SETTINGS_BACKUP_STORES.filter((name: string): boolean => !RESTORE_PREFERENCES_V4.includes(name)))
type RestorePreferenceValue = string | number | boolean

interface RestoreFileImage {
  path: string
  exists: boolean
  content?: string
  byteSize?: number
}

interface RestorePreferenceImage {
  name: string
  values: Record<string, RestorePreferenceValue>
}

interface RestoreCheckpointDocument {
  schemaVersion: number
  phase: string
  files: RestoreFileImage[]
  preferences: RestorePreferenceImage[]
  databaseBytes?: number
}

function checkedPreferenceValues(value: Object): Record<string, RestorePreferenceValue> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('backup_checkpoint_invalid_preferences')
  }
  const values = value as Record<string, RestorePreferenceValue>
  const keys = Object.keys(values)
  for (let index = 0; index < keys.length; index += 1) {
    const item = values[keys[index]]
    // These app stores persist scalar values (structured values as JSON).
    // Reject unknown types before any live write rather than coerce/lossily copy.
    if (typeof item !== 'string' && typeof item !== 'boolean' &&
      !(typeof item === 'number' && Number.isFinite(item))) {
      throw new Error('backup_checkpoint_unsupported_preference_type')
    }
  }
  return values
}

function checkpointFilesPath(filesDir: string): string {
  return `${filesDir}/${CHECKPOINT_FILES}`
}

@Concurrent
function publishRestoreCheckpoint(path: string, payload: string): void {
  writeAppTextFile(path, payload)
}

async function copyCheckpointFile(source: string, destination: string, byteSize: number): Promise<void> {
  await fs.copyFile(source, destination)
  const file = fs.openSync(destination, fs.OpenMode.READ_WRITE)
  try {
    if (fs.statSync(file.fd).size !== byteSize) throw new Error('backup_checkpoint_incomplete_copy')
    await fs.fsync(file.fd)
  } finally {
    fs.closeSync(file)
  }
}

function checkedDocument(payload: string): RestoreCheckpointDocument {
  const document = JSON.parse(payload) as RestoreCheckpointDocument
  if (document === null || ![1, 2, 3, 4, 5, 6, FILE_CHECKPOINT_VERSION, DATABASE_CHECKPOINT_VERSION].includes(document.schemaVersion) ||
    (document.phase !== 'prepared' && document.phase !== 'committed') ||
    !Array.isArray(document.files) || !Array.isArray(document.preferences)) {
    throw new Error('backup_checkpoint_invalid_document')
  }
  if (document.schemaVersion === DATABASE_CHECKPOINT_VERSION &&
    (!Number.isSafeInteger(document.databaseBytes) || (document.databaseBytes ?? 0) <= 0)) {
    throw new Error('backup_checkpoint_incomplete_database')
  }
  const usesFileCopies = document.schemaVersion >= FILE_CHECKPOINT_VERSION
  const expectedFiles = document.schemaVersion >= 6 ? RESTORE_FILES : document.schemaVersion >= 4 ? RESTORE_FILES_V4 :
    document.schemaVersion === 3 ? RESTORE_FILES_V3 : RESTORE_FILES_V2
  if (document.files.length !== expectedFiles.length) throw new Error('backup_checkpoint_invalid_document')
  for (let index = 0; index < expectedFiles.length; index += 1) {
    const image = document.files[index]
    if (image === null || image.path !== expectedFiles[index] || typeof image.exists !== 'boolean') {
      throw new Error('backup_checkpoint_invalid_file')
    }
    if (usesFileCopies) {
      if (image.byteSize === undefined || !Number.isSafeInteger(image.byteSize) || image.byteSize < 0 ||
        (!image.exists && image.byteSize !== 0)) throw new Error('backup_checkpoint_invalid_file')
    } else if (typeof image.content !== 'string' || (!image.exists && image.content.length !== 0)) {
      throw new Error('backup_checkpoint_invalid_file')
    }
  }
  const expectedStores = document.schemaVersion === 1 ? RESTORE_PREFERENCES_V1 :
    document.schemaVersion === 2 ? RESTORE_PREFERENCES_V2 : document.schemaVersion === 3 ?
      RESTORE_PREFERENCES_V3.find((stores: string[]): boolean => stores.length === document.preferences.length) :
      document.schemaVersion === 4 ? RESTORE_PREFERENCES_V4 : RESTORE_PREFERENCES
  if (expectedStores === undefined || document.preferences.length !== expectedStores.length) {
    throw new Error('backup_checkpoint_invalid_store')
  }
  for (let index = 0; index < expectedStores.length; index += 1) {
    const image = document.preferences[index]
    if (image === null || image.name !== expectedStores[index]) {
      throw new Error('backup_checkpoint_invalid_store')
    }
    checkedPreferenceValues(image.values as Object)
  }
  return document
}

// Only the fixed restore domains are accepted. This private recovery image is
// never included in ordinary exports, which intentionally omit credentials.
export class BackupRestoreCheckpoint {
  private context: common.UIAbilityContext
  private document: RestoreCheckpointDocument

  private constructor(context: common.UIAbilityContext, document: RestoreCheckpointDocument) {
    this.context = context
    this.document = document
  }

  stagedFilesDirectory(): string {
    return checkpointFilesPath(this.context.filesDir)
  }

  static async prepare(context: common.UIAbilityContext, backgroundMarker: boolean = false): Promise<BackupRestoreCheckpoint> {
    const filesDir = context.filesDir
    const adapter = new AppFilesLibraryStorePersistenceAdapter(context.filesDir, CHECKPOINT_FILE)
    if (fs.accessSync(`${filesDir}/${CHECKPOINT_FILE}`)) throw new Error('backup_checkpoint_recovery_pending')
    const copies = checkpointFilesPath(filesDir)
    if (fs.accessSync(copies)) fs.rmdirSync(copies)
    fs.mkdirSync(copies)
    // Preference owners may complete a legacy schema migration while being
    // read. Finish those migrations before capturing the native image.
    const images: RestorePreferenceImage[] = []
    for (let index = 0; index < RESTORE_PREFERENCES.length; index += 1) {
      const name = RESTORE_PREFERENCES[index]
      const store = await preferences.getPreferences(context, name)
      // Freeze a copy before later put/delete operations mutate the cache.
      const values = JSON.parse(JSON.stringify(checkedPreferenceValues(await store.getAll()))) as Record<string, RestorePreferenceValue>
      images.push({ name, values: await overlayMigratedCheckpointPreferences(context, name, values) })
    }
    // All RDB domains share the native image. Legacy files are copied only
    // when they are still authoritative; no live domain is JSON-encoded.
    await backupUserDataDatabase(context, `${copies}/${DATABASE_IMAGE}`)
    const databaseBytes = fs.statSync(`${copies}/${DATABASE_IMAGE}`).size
    if (databaseBytes <= 0) throw new Error('backup_checkpoint_incomplete_database')
    const files: RestoreFileImage[] = []
    for (let index = 0; index < RESTORE_FILES.length; index += 1) {
      const path = RESTORE_FILES[index]
      if (isDatabaseImage(filesDir, path)) {
        files.push({ path, exists: false, byteSize: 0 })
        continue
      }
      const absolutePath = `${filesDir}/${path}`
      const exists = fs.accessSync(absolutePath)
      const byteSize = exists ? fs.statSync(absolutePath).size : 0
      if (exists) await copyCheckpointFile(absolutePath, `${copies}/${index}`, byteSize)
      files.push({ path, exists, byteSize })
    }
    // Publish the marker only once every rollback input is complete.
    const document: RestoreCheckpointDocument = { schemaVersion: DATABASE_CHECKPOINT_VERSION,
      phase: 'prepared', files, preferences: images, databaseBytes }
    const payload = JSON.stringify(document)
    if (backgroundMarker) await taskpool.execute(publishRestoreCheckpoint, `${filesDir}/${CHECKPOINT_FILE}`, payload)
    else adapter.save(payload)
    console.info('[BackupRecovery] step=prepared')
    return new BackupRestoreCheckpoint(context, document)
  }

  static async recoverBeforeStartup(context: common.UIAbilityContext): Promise<void> {
    const payload = new AppFilesLibraryStorePersistenceAdapter(context.filesDir, CHECKPOINT_FILE).load()
    if (payload === undefined) {
      BackupRestoreCheckpoint.discardFileCopies(context.filesDir)
      return
    }
    BackupRestoreActivity.beginRestore()
    try {
      const checkpoint = new BackupRestoreCheckpoint(context, checkedDocument(payload))
      if (checkpoint.document.phase === 'prepared') {
        console.info('[BackupRecovery] step=startup_restore')
        await checkpoint.rollback()
        checkpoint.completeRollback()
      } else {
        checkpoint.discardCommitted()
      }
    } catch (_error) {
      BackupRestoreActivity.blockUntilRestart()
      throw new Error('backup_startup_recovery_failed')
    } finally {
      BackupRestoreActivity.finishRestore()
    }
  }

  async rollback(): Promise<void> {
    const filesDir = this.context.filesDir
    const copies = checkpointFilesPath(filesDir)
    const usesFileCopies = this.document.schemaVersion >= FILE_CHECKPOINT_VERSION
    if (usesFileCopies) {
      // Check every backup before replacing any live document.
      for (let index = 0; index < this.document.files.length; index += 1) {
        const image = this.document.files[index]
        if (image.exists && fs.statSync(`${copies}/${index}`).size !== image.byteSize) {
          throw new Error('backup_checkpoint_incomplete_copy')
        }
      }
    }
    if (this.document.schemaVersion === DATABASE_CHECKPOINT_VERSION) {
      const path = `${copies}/${DATABASE_IMAGE}`
      if (fs.statSync(path).size !== this.document.databaseBytes) throw new Error('backup_checkpoint_incomplete_database')
      await restoreUserDataDatabase(this.context, path)
    }
    for (let index = 0; index < this.document.files.length; index += 1) {
      const image = this.document.files[index]
      if (this.document.schemaVersion === DATABASE_CHECKPOINT_VERSION && isDatabaseImage(filesDir, image.path)) continue
      const path = `${filesDir}/${image.path}`
      if (isDatabaseImage(filesDir, image.path)) {
        const payload = image.exists
          ? usesFileCopies ? await fs.readText(`${copies}/${index}`) : image.content as string
          : undefined
        if (image.path === LIBRARY_STORE_PERSISTENCE_FILE_NAME) writeLiveLibrarySnapshot(filesDir, payload)
        else if (image.path === READER_PROGRESS_PERSISTENCE_FILE_NAME) writeLiveReaderSnapshot(filesDir, payload)
        else if (image.path === IMAGE_RULE_LEGACY_PATH) await restoreImageRuleDatabaseCheckpoint(filesDir, payload)
        else if (usesOfflineQueueDatabase(filesDir, image.path)) restoreOfflineQueueDatabaseSnapshot(filesDir, image.path, payload)
        else restoreSourceConfigurationSnapshot(filesDir, image.path, payload)
        continue
      }
      if (image.exists) {
        const parent = path.substring(0, path.lastIndexOf('/'))
        if (!fs.accessSync(parent)) fs.mkdirSync(parent, true)
        if (usesFileCopies) {
          const staged = `${path}.backup-restore.tmp`
          try {
            await copyCheckpointFile(`${copies}/${index}`, staged, image.byteSize as number)
            fs.renameSync(staged, path)
          } finally {
            if (fs.accessSync(staged)) fs.unlinkSync(staged)
          }
        } else {
          new AppFilesLibraryStorePersistenceAdapter(filesDir, image.path).save(image.content as string)
        }
      } else if (fs.accessSync(path)) {
        fs.unlinkSync(path)
      }
    }
    for (let index = 0; index < this.document.preferences.length; index += 1) {
      const image = this.document.preferences[index]
      const store = await preferences.getPreferences(this.context, image.name)
      const legacyKeys = Object.keys(await store.getAll())
      const migrated = await recoverMigratedCheckpointPreferences(this.context, image.name, image.values, legacyKeys)
      if (migrated.size === 0) await store.clear()
      else {
        for (const key of legacyKeys) {
          if (!migrated.has(key)) await store.delete(key)
        }
      }
      const keys = Object.keys(image.values).filter((key: string): boolean => !migrated.has(key))
      for (let keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
        await store.put(keys[keyIndex], image.values[keys[keyIndex]])
      }
      await store.flush()
      const restored = checkedPreferenceValues(await store.getAll())
      const restoredKeys = Object.keys(restored).filter((key: string): boolean => !migrated.has(key))
      if (restoredKeys.length !== keys.length ||
        !keys.every((key: string): boolean => restored[key] === image.values[key])) {
        throw new Error('backup_checkpoint_preferences_readback_failed')
      }
    }
    console.info('[BackupRecovery] step=original_state_restored')
  }

  completeRollback(): void {
    // Call only after the existing in-process readers have reloaded old state.
    fs.unlinkSync(`${this.context.filesDir}/${CHECKPOINT_FILE}`)
    BackupRestoreCheckpoint.discardFileCopies(this.context.filesDir)
  }

  commit(): void {
    this.document.phase = 'committed'
    new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir, CHECKPOINT_FILE).save(JSON.stringify(this.document))
    this.discardCommitted()
    console.info('[BackupRecovery] step=committed')
  }

  /** The live restore lock stays held until the worker verifies the committed marker. */
  async commitAsync(): Promise<void> {
    const filesDir = this.context.filesDir
    const marker = `${filesDir}/${CHECKPOINT_FILE}`
    this.document.phase = 'committed'
    await taskpool.execute(publishRestoreCheckpoint, marker, JSON.stringify(this.document))
    console.info('[BackupRecovery] step=committed')
    try {
      await fs.unlink(marker)
    } catch (_error) {
      // A retained COMMITTED image is cleanup-only on the next startup.
      return
    }
    try {
      await fs.rmdir(checkpointFilesPath(filesDir))
    } catch (_error) {
      // A completed transaction no longer depends on the saved copies.
    }
  }

  private discardCommitted(): void {
    try {
      fs.unlinkSync(`${this.context.filesDir}/${CHECKPOINT_FILE}`)
    } catch (_error) {
      // A retained COMMITTED image is cleanup-only on the next startup.
      return
    }
    BackupRestoreCheckpoint.discardFileCopies(this.context.filesDir)
  }

  private static discardFileCopies(filesDir: string): void {
    const path = checkpointFilesPath(filesDir)
    try {
      if (fs.accessSync(path)) fs.rmdirSync(path)
    } catch (_error) {
      // Without the marker these copies cannot be used for recovery. Reclaim
      // them before the next restore if the current cleanup was interrupted.
    }
  }
}
