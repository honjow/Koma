import { AppearancePreferencesStore } from './AppearancePreferencesStore'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { LanguageSettings } from '../i18n/LanguageSettings'
import { restoreReaderRemoteImageCache } from './ReaderPageSourceAdapter'

export type ApplicationSettingValue = string | number | boolean
export interface ApplicationPreferenceBackup {
  name: string
  values: Record<string, ApplicationSettingValue>
}
export interface BackupDownloadPreferences {
  foregroundConcurrencyLimit: number
  wifiOnly: boolean
}
export interface ApplicationSettingsBackup {
  schemaVersion: number
  preferences: ApplicationPreferenceBackup[]
  downloadPreferences?: BackupDownloadPreferences
}

// Portable user choices only. Runtime history, credentials, permissions, cache
// contents and download pause/work state are not application preferences.
const PORTABLE_FIELDS: Record<string, string[]> = {
  'koma_app_preferences_v1': ['app.language'],
  'koma_appearance_preferences_v1': ['appearance.accentColor'],
  'koma_library_filter_preferences': [
    'library.sort', 'library.viewMode', 'library.listDensity', 'library.showBadges',
    'library.filter.source', 'library.filter.readState', 'library.filter.category',
    'library.filter.availability', 'library.filter.metadataStatus',
  ],
  'koma_library_update_preferences_v1': [
    'libraryUpdate.autoCheckEnabled', 'libraryUpdate.intervalHours', 'libraryUpdate.foregroundOnly',
  ],
  'koma_reader_remote_image_cache_v1': [
    'readerRemoteImageCache.maxBytes', 'readerRemoteImageCache.autoCleanEnabled',
  ],
  'koma_backup_automatic_v1': [
    'backup.automatic.enabled', 'backup.automatic.intervalHours', 'backup.automatic.retentionCount',
  ],
  'koma_backup_content_v1': [
    'backup.content.includeSettings', 'backup.content.includeDownloadQueue', 'backup.content.includeTrackerMappings',
  ],
  // Global ReaderPreferences stay in the existing settings field.
  'koma_reader_preferences_v1': ['reader.seriesModeOverrides.v1'],
}
export const APPLICATION_SETTINGS_BACKUP_STORES: string[] = Object.keys(PORTABLE_FIELDS)

export function checkedApplicationSettingsBackup(
  value: ApplicationSettingsBackup | undefined,
): ApplicationSettingsBackup | undefined {
  if (value === undefined) return undefined
  if (value === null || value.schemaVersion !== 1 || !Array.isArray(value.preferences)) {
    throw new Error('backup_application_settings_invalid')
  }
  const seen = new Set<string>()
  for (let index = 0; index < value.preferences.length; index += 1) {
    const snapshot = value.preferences[index]
    const fields = snapshot === null ? undefined : PORTABLE_FIELDS[snapshot.name]
    if (fields === undefined || seen.has(snapshot.name) || snapshot.values === null ||
      typeof snapshot.values !== 'object' || Array.isArray(snapshot.values)) {
      throw new Error('backup_application_settings_invalid')
    }
    seen.add(snapshot.name)
    const keys = Object.keys(snapshot.values)
    for (let fieldIndex = 0; fieldIndex < keys.length; fieldIndex += 1) {
      const key = keys[fieldIndex]
      const item = snapshot.values[key]
      if (!fields.includes(key) || (typeof item !== 'string' && typeof item !== 'boolean' &&
        !(typeof item === 'number' && Number.isFinite(item)))) {
        throw new Error('backup_application_settings_invalid')
      }
    }
  }
  const download = value.downloadPreferences
  if (download !== undefined && (download === null ||
    typeof download.foregroundConcurrencyLimit !== 'number' ||
    !Number.isFinite(download.foregroundConcurrencyLimit) || typeof download.wifiOnly !== 'boolean')) {
    throw new Error('backup_application_settings_invalid')
  }
  return value
}

export async function exportApplicationSettings(context: common.UIAbilityContext): Promise<ApplicationSettingsBackup> {
  const snapshots: ApplicationPreferenceBackup[] = []
  for (let index = 0; index < APPLICATION_SETTINGS_BACKUP_STORES.length; index += 1) {
    const name = APPLICATION_SETTINGS_BACKUP_STORES[index]
    const store = await preferences.getPreferences(context, name)
    const all = await store.getAll() as Record<string, ApplicationSettingValue>
    const values: Record<string, ApplicationSettingValue> = {}
    const fields = PORTABLE_FIELDS[name]
    for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex += 1) {
      const key = fields[fieldIndex]
      const item = all[key]
      if (item !== undefined) values[key] = item as ApplicationSettingValue
    }
    // Copy before later Preferences.put calls can mutate a cached object.
    snapshots.push({ name, values: JSON.parse(JSON.stringify(values)) as Record<string, ApplicationSettingValue> })
  }
  const download = new OfflineDownloadQueueStore(context.filesDir).loadPreferences()
  const result: ApplicationSettingsBackup = {
    schemaVersion: 1,
    preferences: snapshots,
    downloadPreferences: { foregroundConcurrencyLimit: download.foregroundConcurrencyLimit, wifiOnly: download.wifiOnly },
  }
  checkedApplicationSettingsBackup(result)
  return result
}

export async function importApplicationSettings(
  context: common.UIAbilityContext, value: ApplicationSettingsBackup | undefined,
): Promise<void> {
  const document = checkedApplicationSettingsBackup(value)
  if (document === undefined) return // Older backups do not reset newly covered settings.
  if (!BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_not_active')
  for (let index = 0; index < document.preferences.length; index += 1) {
    const snapshot = document.preferences[index]
    const store = await preferences.getPreferences(context, snapshot.name)
    const fields = PORTABLE_FIELDS[snapshot.name]
    for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex += 1) {
      const key = fields[fieldIndex]
      if (snapshot.values[key] === undefined) await store.delete(key)
      else await store.put(key, snapshot.values[key])
    }
    await store.flush()
  }
  if (document.downloadPreferences !== undefined) {
    const store = new OfflineDownloadQueueStore(context.filesDir)
    const current = store.loadPreferences()
    current.foregroundConcurrencyLimit = document.downloadPreferences.foregroundConcurrencyLimit
    current.wifiOnly = document.downloadPreferences.wifiOnly
    store.savePreferencesForBackupRestore(current)
  }
}

export function countApplicationSettings(value: ApplicationSettingsBackup | undefined): number {
  if (value === undefined) return 0
  return value.preferences.reduce((count: number, snapshot: ApplicationPreferenceBackup): number =>
    count + (PORTABLE_FIELDS[snapshot.name]?.length ?? 0), value.downloadPreferences === undefined ? 0 : 2)
}

// Publish only after the durable restore has committed (or rollback has finished).
// In particular, a pending restore must not authorize cache eviction.
export async function reloadApplicationSettingsRuntime(context: common.UIAbilityContext): Promise<void> {
  await LanguageSettings.restore(context)
  await new AppearancePreferencesStore(context).load()
  await restoreReaderRemoteImageCache(context)
}
