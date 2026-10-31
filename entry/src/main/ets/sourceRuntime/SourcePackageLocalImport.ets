import { common } from '@kit.AbilityKit'
import { getInstalledSourcePackage, pickSourcePackageArchive, SourcePackageInstallResult } from './SourceRuntimeAppRegistry'
import { SourceIndexService } from './SourceIndexService'
import { appSourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'

// The root Browse button and manager share one picker owner. Archive install
// still enters SourceIndexService's existing exclusive install barrier.
@ObservedV2
export class SourcePackageLocalImport {
  @Trace busy: boolean = false

  async run(context: common.UIAbilityContext): Promise<SourcePackageInstallResult | undefined> {
    if (this.busy) return undefined
    this.busy = true
    try {
      const uri = await pickSourcePackageArchive(context)
      if (uri === undefined) return undefined
      const result = await new SourceIndexService(context).installLocalArchive(uri)
      const id = result.id
      if (result.ok && id !== undefined) {
        const source = getInstalledSourcePackage(id)
        if (source !== undefined) appSourcePackageManagerCache.recordInstalledPackage(source)
      }
      return result
    } finally { this.busy = false }
  }
}

export const appSourcePackageLocalImport: SourcePackageLocalImport = new SourcePackageLocalImport()
