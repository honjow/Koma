import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { preferences } from '@kit.ArkData'
import { fileIo as fs } from '@kit.CoreFileKit'
import { AppFilesLibraryStorePersistenceAdapter } from './LibraryPersistence'
import { BackupRestoreActivity } from './BackupRestoreActivity'

const CHECKPOINT_FILE: string = 'backup-restore-checkpoint.v1.json'
const RESTORE_FILES: string[] = [
  'library-store.v1.json',
  'reader-sessions.v1.json',
  'source-runtime/source-settings.json',
  'source-runtime/source-filter-preferences.json',
  'downloads/queue.v1.json',
  'source-runtime/source-runtime-registry.json',
]
const RESTORE_PREFERENCES: string[] = [
  'koma_remote_servers_v1',
  'koma_source_package_manager_v1',
  'koma_tracker_preferences_v1',
  'koma_reader_preferences_v1',
]
type RestorePreferenceValue = string | number | boolean

interface RestoreFileImage {
  path: string
  exists: boolean
  content: string
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
}

function checkedPreferenceValues(value: Object): Record<string, RestorePreferenceValue> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('backup_checkpoint_invalid_preferences')
  }
  const values = value as Record<string, RestorePreferenceValue>
  const keys = Object.keys(values)
  for (let index = 0; index < keys.length; index += 1) {
    const item = values[keys[index]]
    // These four app stores persist scalar values (structured values as JSON).
    // Reject unknown types before any live write rather than coerce/lossily copy.
    if (typeof item !== 'string' && typeof item !== 'boolean' &&
      !(typeof item === 'number' && Number.isFinite(item))) {
      throw new Error('backup_checkpoint_unsupported_preference_type')
    }
  }
  return values
}

function readExactUtf8(path: string): string {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
  try {
    const size = fs.statSync(file.fd).size
    const bytes = new Uint8Array(size)
    let offset = 0
    while (offset < size) {
      const chunk = new ArrayBuffer(Math.min(65536, size - offset))
      const count = fs.readSync(file.fd, chunk)
      if (count <= 0) throw new Error('backup_checkpoint_incomplete_read')
      bytes.set(new Uint8Array(chunk, 0, count), offset)
      offset += count
    }
    const content = buffer.from(bytes).toString('utf-8')
    if (buffer.compare(buffer.from(content, 'utf-8'), bytes) !== 0) {
      throw new Error('backup_checkpoint_invalid_utf8')
    }
    return content
  } finally {
    fs.closeSync(file)
  }
}

function checkedDocument(payload: string): RestoreCheckpointDocument {
  const document = JSON.parse(payload) as RestoreCheckpointDocument
  if (document === null || document.schemaVersion !== 1 ||
    (document.phase !== 'prepared' && document.phase !== 'committed') ||
    !Array.isArray(document.files) || document.files.length !== RESTORE_FILES.length ||
    !Array.isArray(document.preferences) || document.preferences.length !== RESTORE_PREFERENCES.length) {
    throw new Error('backup_checkpoint_invalid_document')
  }
  for (let index = 0; index < RESTORE_FILES.length; index += 1) {
    const image = document.files[index]
    if (image === null || image.path !== RESTORE_FILES[index] ||
      typeof image.exists !== 'boolean' || typeof image.content !== 'string' ||
      (!image.exists && image.content.length !== 0)) {
      throw new Error('backup_checkpoint_invalid_file')
    }
  }
  for (let index = 0; index < RESTORE_PREFERENCES.length; index += 1) {
    const image = document.preferences[index]
    if (image === null || image.name !== RESTORE_PREFERENCES[index]) {
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

  static async prepare(context: common.UIAbilityContext): Promise<BackupRestoreCheckpoint> {
    const adapter = new AppFilesLibraryStorePersistenceAdapter(context.filesDir, CHECKPOINT_FILE)
    if (adapter.load() !== undefined) throw new Error('backup_checkpoint_recovery_pending')
    const files: RestoreFileImage[] = RESTORE_FILES.map((path: string): RestoreFileImage => {
      const absolutePath = `${context.filesDir}/${path}`
      const exists = fs.accessSync(absolutePath)
      return { path, exists, content: exists ? readExactUtf8(absolutePath) : '' }
    })
    const images: RestorePreferenceImage[] = []
    for (let index = 0; index < RESTORE_PREFERENCES.length; index += 1) {
      const name = RESTORE_PREFERENCES[index]
      const store = await preferences.getPreferences(context, name)
      const values = checkedPreferenceValues(await store.getAll())
      // Freeze a copy before later put/delete operations mutate the cache.
      images.push({ name, values: JSON.parse(JSON.stringify(values)) as Record<string, RestorePreferenceValue> })
    }
    const document: RestoreCheckpointDocument = { schemaVersion: 1, phase: 'prepared', files, preferences: images }
    adapter.save(JSON.stringify(document))
    console.info('[BackupRecovery] step=prepared')
    return new BackupRestoreCheckpoint(context, document)
  }

  static async recoverBeforeStartup(context: common.UIAbilityContext): Promise<void> {
    const payload = new AppFilesLibraryStorePersistenceAdapter(context.filesDir, CHECKPOINT_FILE).load()
    if (payload === undefined) return
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
    for (let index = 0; index < this.document.files.length; index += 1) {
      const image = this.document.files[index]
      const path = `${this.context.filesDir}/${image.path}`
      if (image.exists) {
        const parent = path.substring(0, path.lastIndexOf('/'))
        if (!fs.accessSync(parent)) fs.mkdirSync(parent, true)
        new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir, image.path).save(image.content)
      } else if (fs.accessSync(path)) {
        fs.unlinkSync(path)
      }
    }
    for (let index = 0; index < this.document.preferences.length; index += 1) {
      const image = this.document.preferences[index]
      const store = await preferences.getPreferences(this.context, image.name)
      await store.clear()
      const keys = Object.keys(image.values)
      for (let keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
        await store.put(keys[keyIndex], image.values[keys[keyIndex]])
      }
      await store.flush()
      const restored = checkedPreferenceValues(await store.getAll())
      const restoredKeys = Object.keys(restored)
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
  }

  commit(): void {
    this.document.phase = 'committed'
    new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir, CHECKPOINT_FILE).save(JSON.stringify(this.document))
    this.discardCommitted()
    console.info('[BackupRecovery] step=committed')
  }

  private discardCommitted(): void {
    try {
      fs.unlinkSync(`${this.context.filesDir}/${CHECKPOINT_FILE}`)
    } catch (_error) {
      // A retained COMMITTED image is cleanup-only on the next startup.
    }
  }
}
