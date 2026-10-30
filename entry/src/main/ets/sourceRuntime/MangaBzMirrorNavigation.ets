import { appSourceRuntimeRegistry } from './SourceRuntimeAppRegistry'
import { appSourceSettingsStore } from './SourceSettingsStore'

/** Use only an installed package's declared mirror origin; other sources keep their metadata route. */
export function selectedMangaBzMirror(sourceId: string): string | undefined {
  if (sourceId !== 'com.mangabz.koma') return undefined
  const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
  if (entry === undefined || !entry.enabled) return undefined
  const origins = entry.webSessionOrigins ?? []
  if (!origins.includes('https://www.mangabz.com') || !origins.includes('https://xmanhua.com') ||
    !origins.includes('https://yymanhua.com')) return undefined
  const saved = appSourceSettingsStore.loadForSource(sourceId)['preferredMirror']
  const selected = saved === 'https://xmanhua.com' || saved === 'https://yymanhua.com' ? saved : 'https://www.mangabz.com'
  return selected
}
