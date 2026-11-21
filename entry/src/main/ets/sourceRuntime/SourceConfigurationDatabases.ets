import { common } from '@kit.AbilityKit'
import { appSourceSettingsStore, sourceSettingsPersistence } from './SourceSettingsStore'
import { appSourceFilterPreferencesStore, sourceFilterPersistence } from './SourceFilterPreferencesStore'
import { SOURCE_FILTERS_PATH, SOURCE_SETTINGS_PATH } from './SourcePreferencePersistence'
import { prepareSourceRegistryDatabase, readSourceRegistryMetadata, SOURCE_REGISTRY_PATH,
  usesSourceRegistryDatabase, writeSourceRegistryMetadata } from './SourceRegistryDatabase'
import type { SourceRuntimeRegistryPersistedMetadata } from './SourceRuntimeRegistry'
import { appSourceSettingObservationStore, sourceObservationPersistence, SOURCE_OBSERVATIONS_PATH } from './SourceSettingObservationStore'

export async function prepareSourceConfigurationDatabases(context: common.Context, migrate: boolean): Promise<void> {
  const results = await Promise.allSettled([
    appSourceSettingsStore.prepareDatabase(context, migrate),
    appSourceFilterPreferencesStore.prepareDatabase(context, migrate),
    appSourceSettingObservationStore.prepareDatabase(context, migrate),
    prepareSourceRegistryDatabase(context, migrate),
  ])
  for (const result of results) {
    if (result.status === 'rejected') throw result.reason as Error
  }
}

export function usesSourceConfigurationDatabase(filesDir: string, path: string): boolean {
  const absolute = filesDir + '/' + path
  if (path === SOURCE_SETTINGS_PATH) return sourceSettingsPersistence.database(absolute) !== undefined
  if (path === SOURCE_FILTERS_PATH) return sourceFilterPersistence.database(absolute) !== undefined
  if (path === SOURCE_REGISTRY_PATH) return usesSourceRegistryDatabase(absolute)
  if (path === SOURCE_OBSERVATIONS_PATH) return sourceObservationPersistence.database(absolute) !== undefined
  return false
}

export function readSourceConfigurationSnapshot(filesDir: string, path: string): string | undefined {
  const absolute = filesDir + '/' + path
  if (path === SOURCE_SETTINGS_PATH) return sourceSettingsPersistence.readSnapshot(absolute)
  if (path === SOURCE_FILTERS_PATH) return sourceFilterPersistence.readSnapshot(absolute)
  if (path === SOURCE_OBSERVATIONS_PATH) return sourceObservationPersistence.readSnapshot(absolute)
  if (path === SOURCE_REGISTRY_PATH) {
    const metadata = readSourceRegistryMetadata(absolute)
    return metadata === undefined ? undefined : JSON.stringify(metadata)
  }
  return undefined
}

export function restoreSourceConfigurationSnapshot(filesDir: string, path: string, value: string | undefined): void {
  const absolute = filesDir + '/' + path
  if (path === SOURCE_SETTINGS_PATH) {
    sourceSettingsPersistence.restoreSnapshot(absolute, value)
    appSourceSettingsStore.invalidateCachedDocument()
  } else if (path === SOURCE_FILTERS_PATH) {
    sourceFilterPersistence.restoreSnapshot(absolute, value)
  } else if (path === SOURCE_OBSERVATIONS_PATH) {
    sourceObservationPersistence.restoreSnapshot(absolute, value)
    appSourceSettingObservationStore.invalidateCachedDocument()
  } else if (path === SOURCE_REGISTRY_PATH) {
    writeSourceRegistryMetadata(absolute, value === undefined ? undefined : JSON.parse(value) as SourceRuntimeRegistryPersistedMetadata)
  }
}
