import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export type SourceBrowseLayout = 'grid' | 'list'

const STORE = 'koma_source_browse_layout_v1'
let writes: Promise<void> = Promise.resolve()

/** Host display preferences are keyed by source identity, independent of the source package. */
export class SourceBrowseLayoutPreferences {
  private context: common.Context
  constructor(context: common.Context) { this.context = context }

  load(sourceId: string): SourceBrowseLayout {
    const store = preferences.getPreferencesSync(this.context, { name: STORE })
    return store.getSync(sourceId, 'grid') === 'list' ? 'list' : 'grid'
  }

  save(sourceId: string, layout: SourceBrowseLayout): Promise<void> {
    const write = writes.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, STORE)
      const previous = await store.get(sourceId, 'grid')
      if (previous === layout) return
      try {
        await store.put(sourceId, layout)
        await store.flush()
      } catch (error) {
        await store.put(sourceId, previous)
        await store.flush()
        throw error as Error
      }
    })
    writes = write.catch((): void => {})
    return write
  }
}
