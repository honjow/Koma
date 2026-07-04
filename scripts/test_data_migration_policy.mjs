import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const source = (path) => readFileSync(resolve(root, path), 'utf8')

const policy = source('docs/DATA_MIGRATION_POLICY.md')
const backup = source('entry/src/main/ets/model/BackupService.ets')
const encryption = source('entry/src/main/ets/model/BackupEncryptionService.ets')
const library = source('entry/src/main/ets/model/LibraryPersistence.ets')
const readerProgress = source('entry/src/main/ets/model/ReaderSessionStore.ets')
const readerPrefs = source('entry/src/main/ets/model/ReaderPreferencesStore.ets')
const sourceSettings = source('entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets')
const offlineStore = source('entry/src/main/ets/model/OfflineDownloadStore.ets')
const offlineQueue = source('entry/src/main/ets/model/OfflineDownloadQueueStore.ets')
const tracker = source('entry/src/main/ets/model/TrackerModels.ets')

for (const required of [
  'LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION = 1',
  'READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 1',
  'READER_PREFERENCES_STORE_NAME = koma_reader_preferences_v1',
  'SERIES_OVERRIDES_KEY = reader.seriesOverrides.v1',
  'SOURCE_SETTINGS_SCHEMA_VERSION = 1',
  'OFFLINE_DOWNLOAD_SCHEMA_VERSION = 1',
  'OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION = 1',
  'plaintext v1/v2/v3 accepted',
  'BACKUP_ENVELOPE_VERSION = 1',
  'TRACKER_PREFERENCES_STORE_NAME = koma_tracker_preferences_v1',
]) {
  assert.ok(policy.includes(required), `migration policy must list ${required}`)
}

assert.match(library, /LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION = 1[\s\S]*assertValidLibraryStoreJson/, 'library schema must validate before hydrate')
assert.match(readerProgress, /READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 1[\s\S]*Unsupported reader progress schema version/, 'reader progress must reject unsupported schema')
assert.match(readerPrefs, /READER_PREFERENCES_STORE_NAME[\s\S]*SERIES_OVERRIDES_KEY[\s\S]*normalizeReaderSeriesPreferenceOverrides/, 'reader prefs must keep stable keys and normalize per-series overrides')
assert.match(sourceSettings, /SOURCE_SETTINGS_SCHEMA_VERSION: number = 1[\s\S]*filterSafeValues[\s\S]*descriptorIsCredentialLike/, 'source settings must schema and block credential-like values')
assert.match(offlineStore, /OFFLINE_DOWNLOAD_SCHEMA_VERSION: number = 1[\s\S]*validateDownloadedChapter[\s\S]*OfflineDownloadedChapterStatus\.CORRUPT/, 'offline downloads must validate manifests into safe states')
assert.match(offlineQueue, /OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION[\s\S]*reconcileWithManifests/, 'offline queue must reconcile persisted rows with manifests')
assert.match(backup, /BACKUP_ACCEPTED_SCHEMA_VERSIONS[\s\S]*BACKUP_SCHEMA_VERSION_V1[\s\S]*BACKUP_SCHEMA_VERSION_V2[\s\S]*BACKUP_SCHEMA_VERSION/, 'backup restore must keep accepted plaintext versions explicit')
assert.match(encryption, /BACKUP_ENVELOPE_VERSION: number = 1[\s\S]*BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION: number = 4/, 'encrypted backup envelope and content versions must stay explicit')
assert.match(tracker, /TRACKER_PREFERENCES_STORE_NAME[\s\S]*AssetStoreTrackerCredentialSecretStore[\s\S]*asset\.add/, 'tracker tokens must stay in AssetStore, outside JSON migration')

console.log('data migration policy checks passed')
