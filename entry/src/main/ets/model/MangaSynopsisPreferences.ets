import { common } from '@kit.AbilityKit'
import { synopsisRecords } from './MigratedPreferenceRecords'

const pendingSynopsis = new Map<string, boolean>()

/** Local presentation state, keyed by the same comic ID as the detail route. */
export class MangaSynopsisPreferences {
  static isExpanded(context: common.Context, comicId: string): boolean {
    try {
      return comicId.length > 0 && (pendingSynopsis.get(comicId) ??
        synopsisRecords.prepared(context.filesDir)?.get(comicId) === 'true')
    } catch (_error) { return false }
  }

  static async save(context: common.Context, comicId: string, expanded: boolean): Promise<void> {
    if (comicId.length === 0) return
    // A quick return to the same detail sees the new value while the write is queued.
    pendingSynopsis.set(comicId, expanded)
    try {
      (await synopsisRecords.prepare(context)).put(comicId, expanded ? 'true' : undefined)
    } finally {
      if (pendingSynopsis.get(comicId) === expanded) pendingSynopsis.delete(comicId)
    }
  }
}
