import { AppearancePreferencesStore } from './AppearancePreferencesStore'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from './KomaContentStorage'
import { LanguageSettings } from '../i18n/LanguageSettings'
import { restoreReaderRemoteImageCache } from './ReaderPageSourceAdapter'
import { invalidateLibraryAutomationPolicyCache } from './LibraryAutomationPreferencesStore'
import { decodePreferenceRecordMap, migratedBackupPreference } from './MigratedPreferenceRecords'
import { isValidHttpUrl, normalizeIndexUrl, parseSavedSourceIndexRepositories, SourceIndexRepository,
  serializeSourceIndexRepositories, effectiveSourceIndexRepositories } from '../sourceRuntime/SourceIndexMetadata'
import { loadSourceSubscriptionPreferences, saveSourceSubscriptionPreferences, sourceSubscriptionBackupValues,
  SOURCE_INDEX_PREFERENCES, SOURCE_INDEX_REPOSITORIES, SOURCE_INDEX_URL } from '../sourceRuntime/SourceSubscriptionStorage'

export type ApplicationSettingValue = string | number | boolean
export interface ApplicationPreferenceBackup {
  name: string
  values: Record<string, ApplicationSettingValue>
  clearedKeys?: string[]
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
  'koma_source_catalog_filters_v1': ['catalog.filters'],
  'koma_chapter_list_preferences_v1': ['chapterList.overrides.v1'],
  'koma_library_automation_v1': ['automation.policy'],
  'koma_app_preferences_v1': ['app.language'],
  // Keep accepting the alert style in older backups. The system now owns sound and vibration.
  'koma_download_notifications_v1': ['download.notifications.enabled', 'download.notifications.sound'],
  'koma_appearance_preferences_v1': ['appearance.accentColor', 'appearance.autoHideBottomBar', 'navigation.backGuardEnabled'],
  'koma_library_filter_preferences': [
    'library.sort', 'library.sortDirection', 'library.sortConfigured', 'library.viewMode', 'library.listDensity', 'library.showBadges',
    'library.showContinueReadingCard',
    'library.filter.source', 'library.filter.readState', 'library.filter.category',
    'library.filter.availability', 'library.filter.metadataStatus', 'library.gridColumnWidth',
  ],
  'koma_library_update_preferences_v1': [
    'libraryUpdate.autoCheckEnabled', 'libraryUpdate.intervalHours', 'libraryUpdate.foregroundOnly',
  ],
  'koma_reader_remote_image_cache_v1': [
    'readerRemoteImageCache.maxBytes', 'readerRemoteImageCache.autoCleanEnabled',
  ],
  'koma_backup_automatic_v1': [
    'backup.automatic.enabled', 'backup.automatic.intervalHours', 'backup.automatic.retentionCount', 'backup.automatic.backgroundEnabled',
  ],
  'koma_backup_content_v1': [
    'backup.content.includeSettings', 'backup.content.includeDownloadQueue', 'backup.content.includeTrackerMappings',
  ],
  // Global ReaderPreferences stay in the existing settings field.
  'koma_reader_preferences_v1': ['reader.seriesModeOverrides.v1'],
  'koma_manga_migration_v1': ['migration.selectedSources', 'migration.matchOptions'],
  'koma_source_package_manager_v1': ['source_index.repositories.v1', 'source_index.url'],
  'koma_search_history_v1': ['search.source.filter', 'search.results.only'],
}
export const APPLICATION_SETTINGS_BACKUP_STORES: string[] = Object.keys(PORTABLE_FIELDS)

function checkPortableValue(name: string, key: string, value: ApplicationSettingValue): void {
  if (migratedBackupPreference(name, key) !== undefined) {
    decodePreferenceRecordMap(value)
  } else if (name === 'koma_library_filter_preferences' && key === 'library.gridColumnWidth') {
    if (typeof value !== 'number' || value < 0) throw new Error('backup_application_settings_invalid')
  } else if (name === 'koma_download_notifications_v1') {
    if (key === 'download.notifications.enabled' && typeof value !== 'boolean') throw new Error('backup_application_settings_invalid')
    if (key === 'download.notifications.sound' && (typeof value !== 'string' ||
      !['silent', 'sound', 'vibrate', 'sound_vibrate'].includes(value))) throw new Error('backup_application_settings_invalid')
  } else if (name === 'koma_appearance_preferences_v1' &&
    (key === 'appearance.autoHideBottomBar' || key === 'navigation.backGuardEnabled')) {
    if (typeof value !== 'boolean') throw new Error('backup_application_settings_invalid')
  } else if (name === 'koma_manga_migration_v1') {
    if (typeof value !== 'string') throw new Error('backup_application_settings_invalid')
    const parsed = JSON.parse(value) as Object
    if (key === 'migration.selectedSources') {
      if (!Array.isArray(parsed) || (parsed as Object[]).some((item: Object): boolean =>
        typeof item !== 'string' || item.trim().length === 0)) throw new Error('backup_application_settings_invalid')
    } else {
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('backup_application_settings_invalid')
      const options = parsed as Record<string, Object>
      if (Object.keys(options).some((option: string): boolean =>
        !['deepSearch', 'prioritizeChapters'].includes(option) || typeof options[option] !== 'boolean')) {
        throw new Error('backup_application_settings_invalid')
      }
    }
  } else if (name === 'koma_search_history_v1') {
    if (typeof value !== 'string' || !(key === 'search.results.only' ? ['true', 'false'] :
      ['all', 'local', 'private', 'source', 'wasm']).includes(value)) throw new Error('backup_application_settings_invalid')
  } else if (name === 'koma_source_package_manager_v1') {
    if (typeof value !== 'string') throw new Error('backup_application_settings_invalid')
    if (key === 'source_index.repositories.v1') {
      if (!Array.isArray(JSON.parse(value))) throw new Error('backup_application_settings_invalid')
      parseSavedSourceIndexRepositories(value, '')
    } else if (value !== '' && !isValidHttpUrl(value)) throw new Error('backup_application_settings_invalid')
  }
}

export function checkedApplicationSettingsBackup(
  value: ApplicationSettingsBackup | undefined,
): ApplicationSettingsBackup | undefined {
  if (value === undefined) return undefined
  if (value === null || (value.schemaVersion !== 1 && value.schemaVersion !== 2) || !Array.isArray(value.preferences)) {
    throw new Error('backup_application_settings_invalid')
  }
  const seen = new Set<string>()
  for (let index = 0; index < value.preferences.length; index += 1) {
    const snapshot = value.preferences[index]
    const fields = snapshot === null ? undefined : PORTABLE_FIELDS[snapshot.name]
    if (!Array.isArray(fields) || seen.has(snapshot.name) || snapshot.values === null ||
      typeof snapshot.values !== 'object' || Array.isArray(snapshot.values)) {
      throw new Error('backup_application_settings_invalid')
    }
    seen.add(snapshot.name)
    const keys = Object.keys(snapshot.values)
    if (value.schemaVersion === 2) {
      if (!Array.isArray(snapshot.clearedKeys) || snapshot.clearedKeys.some((key: string, index: number): boolean =>
        !fields.includes(key) || keys.includes(key) || snapshot.clearedKeys?.indexOf(key) !== index)) {
        throw new Error('backup_application_settings_invalid')
      }
    } else if (snapshot.clearedKeys !== undefined) {
      throw new Error('backup_application_settings_invalid')
    }
    for (let fieldIndex = 0; fieldIndex < keys.length; fieldIndex += 1) {
      const key = keys[fieldIndex]
      const item = snapshot.values[key]
      if (!fields.includes(key) || (typeof item !== 'string' && typeof item !== 'boolean' &&
        !(typeof item === 'number' && Number.isFinite(item)))) {
        throw new Error('backup_application_settings_invalid')
      }
      try { checkPortableValue(snapshot.name, key, item) }
      catch (_error) { throw new Error('backup_application_settings_invalid') }
    }
    if (value.schemaVersion === 2 && snapshot.name === 'koma_source_package_manager_v1') {
      if (!(keys.includes('source_index.repositories.v1') || snapshot.clearedKeys?.includes('source_index.repositories.v1')) ||
        !(keys.includes('source_index.url') || snapshot.clearedKeys?.includes('source_index.url'))) {
        throw new Error('backup_application_settings_invalid')
      }
      const list = parseSavedSourceIndexRepositories(snapshot.values['source_index.repositories.v1'] ?? '[]', '')
      const primary = snapshot.values['source_index.url']
      if (typeof primary === 'string' && primary !== '' &&
        !list.some((item: SourceIndexRepository): boolean => item.url === normalizeIndexUrl(primary))) throw new Error('backup_application_settings_invalid')
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
    const values: Record<string, ApplicationSettingValue> = {}
    const fields = PORTABLE_FIELDS[name]
    if (name === SOURCE_INDEX_PREFERENCES) {
      const snapshot = await loadSourceSubscriptionPreferences(context)
      if (snapshot.url !== undefined) values[SOURCE_INDEX_URL] = snapshot.url
      const repositories = effectiveSourceIndexRepositories(snapshot.repositories ?? [], snapshot.url ?? '')
      if (snapshot.repositories !== undefined || repositories.length > 0) {
        values[SOURCE_INDEX_REPOSITORIES] = serializeSourceIndexRepositories(repositories)
      }
    } else {
      const store = await preferences.getPreferences(context, name)
      const all = await store.getAll() as Record<string, ApplicationSettingValue>
      for (const key of fields) {
        const migrated = migratedBackupPreference(name, key)
        const item = migrated === undefined ? all[key] : await migrated.readBackupValue(context)
        if (item !== undefined) values[key] = item
      }
    }
    // Copy before later Preferences.put calls can mutate a cached object.
    snapshots.push({ name, values: JSON.parse(JSON.stringify(values)) as Record<string, ApplicationSettingValue>,
      clearedKeys: fields.filter((key: string): boolean => values[key] === undefined) })
  }
  const storageBase = await ensureKomaContentStorageBase(context)
  const download = new OfflineDownloadQueueStore(storageBase, komaRuntimeStorageKey(context)).loadPreferences()
  const result: ApplicationSettingsBackup = {
    schemaVersion: 2,
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
    if (snapshot.name === SOURCE_INDEX_PREFERENCES) {
      const url = snapshot.values[SOURCE_INDEX_URL]
      const repositories = snapshot.values[SOURCE_INDEX_REPOSITORIES]
      await saveSourceSubscriptionPreferences(context, sourceSubscriptionBackupValues(url, repositories),
        url !== undefined || snapshot.clearedKeys?.includes(SOURCE_INDEX_URL) === true,
        repositories !== undefined || snapshot.clearedKeys?.includes(SOURCE_INDEX_REPOSITORIES) === true)
      continue
    }
    const store = await preferences.getPreferences(context, snapshot.name)
    // A missing v1 field cannot distinguish an old writer from an intentional
    // reset. Preserve it; only v2's explicit clearedKeys authorize deletion.
    const keys = Object.keys(snapshot.values)
    for (const key of keys) {
      const migrated = migratedBackupPreference(snapshot.name, key)
      if (migrated === undefined) await store.put(key, snapshot.values[key])
      else await migrated.restoreBackupValue(context, snapshot.values[key])
    }
    for (const key of snapshot.clearedKeys ?? []) {
      const migrated = migratedBackupPreference(snapshot.name, key)
      if (migrated === undefined) await store.delete(key)
      else await migrated.restoreBackupValue(context, undefined)
    }
    await store.flush()
  }
  if (document.downloadPreferences !== undefined) {
    const storageBase = await ensureKomaContentStorageBase(context)
    const store = new OfflineDownloadQueueStore(storageBase, komaRuntimeStorageKey(context))
    const current = store.loadPreferences()
    current.foregroundConcurrencyLimit = document.downloadPreferences.foregroundConcurrencyLimit
    current.wifiOnly = document.downloadPreferences.wifiOnly
    store.savePreferencesForBackupRestore(current)
  }
}

export function countApplicationSettings(value: ApplicationSettingsBackup | undefined): number {
  if (value === undefined) return 0
  return value.preferences.reduce((count: number, snapshot: ApplicationPreferenceBackup): number =>
    count + Object.keys(snapshot.values).length + (snapshot.clearedKeys?.length ?? 0),
    value.downloadPreferences === undefined ? 0 : 2)
}

// Publish only after the durable restore has committed (or rollback has finished).
// In particular, a pending restore must not authorize cache eviction.
export async function reloadApplicationSettingsRuntime(context: common.UIAbilityContext): Promise<void> {
  await LanguageSettings.restore(context)
  await new AppearancePreferencesStore(context).load()
  invalidateLibraryAutomationPolicyCache()
  await restoreReaderRemoteImageCache(context)
}
