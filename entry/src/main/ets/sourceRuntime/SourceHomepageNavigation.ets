import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { appSourceRuntimeRegistry } from './SourceRuntimeAppRegistry'
import { SourceIndexEntry, SourceIndexService } from './SourceIndexService'
import { normalizeSourceHomepage } from './SourcePackageImporter'

/** Resolve declared site metadata independently of browse/search success. */
export async function resolveSourceHomepage(context: common.UIAbilityContext, sourceId: string): Promise<string | undefined> {
  const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
  if (entry === undefined) return undefined
  const installed = normalizeSourceHomepage(entry.packageHomepage)
  if (installed !== undefined) return installed
  const service = new SourceIndexService(context)
  let indexUrl: string = ''
  try {
    indexUrl = await service.loadSavedUrl()
    const cached = await service.loadCachedIndex(indexUrl)
    const homepage = normalizeSourceHomepage(cached?.find((item: SourceIndexEntry): boolean => item.id === sourceId)?.homepage)
    if (homepage !== undefined) return homepage
  } catch (_error) {
    // Optional index metadata must not hide an installed source's own site.
  }
  const legacy = normalizeSourceHomepage((entry.webSessionOrigins ?? [])[0])
  if (legacy !== undefined) return legacy
  if (indexUrl.length === 0) return undefined
  try {
    const fresh = await service.fetchIndex(indexUrl)
    if (!fresh.ok) return undefined
    return normalizeSourceHomepage(fresh.entries.find((item: SourceIndexEntry): boolean => item.id === sourceId)?.homepage)
  } catch (_error) {
    return undefined
  }
}

/** Ordinary browser navigation has no sourceSession or source-cookie grant. */
export async function openSourceHomepage(
  context: common.UIAbilityContext, sourceId: string, title: string, isCurrent: () => boolean,
): Promise<boolean> {
  const homepage = await resolveSourceHomepage(context, sourceId)
  if (!isCurrent()) return true
  if (homepage === undefined) return false
  try {
    RouterHelper.pushMangaWeb({ url: homepage, title })
    return true
  } catch (_error) {
    return false
  }
}
