import { appSourceRuntimeRegistry } from './SourceRuntimeAppRegistry'
import { appSourceSettingsStore } from './SourceSettingsStore'
import { selectedPolicyHomepage } from './SourceWebsitePolicy'

export function selectedSourceHomepage(sourceId: string): string | undefined {
  const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
  if (entry?.enabled !== true) return undefined
  try {
    return selectedPolicyHomepage(entry.websitePolicy,
      (key: string): Object | undefined => appSourceSettingsStore.loadForSource(sourceId)[key] as Object | undefined)
  } catch (_error) { return undefined }
}
