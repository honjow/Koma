import { common } from '@kit.AbilityKit'
import { sourceBrowseLayoutRecords } from './MigratedPreferenceRecords'

export type SourceBrowseLayout = 'grid' | 'list'

/** Device-local display preferences keyed by source identity. Backup and sync leave this store local. */
export class SourceBrowseLayoutPreferences {
  private context: common.Context
  constructor(context: common.Context) { this.context = context }

  load(sourceId: string): SourceBrowseLayout {
    return sourceBrowseLayoutRecords.prepared(this.context.filesDir)?.get(sourceId) === '"list"' ? 'list' : 'grid'
  }

  async save(sourceId: string, layout: SourceBrowseLayout): Promise<void> {
    const records = await sourceBrowseLayoutRecords.prepare(this.context)
    const current = records.get(sourceId) === '"list"' ? 'list' : 'grid'
    if (layout !== current) records.put(sourceId, JSON.stringify(layout))
  }
}
