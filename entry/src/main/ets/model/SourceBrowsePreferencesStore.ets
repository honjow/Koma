import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectSourceBrowseState } from '../state/SourceBrowseState'
import { BackupRestoreActivity } from './BackupRestoreActivity'

export const SOURCE_BROWSE_PREFERENCES = 'koma_source_browse_preferences_v1'
export const SOURCE_BROWSE_HIDE_IN_LIBRARY = 'sourceBrowse.hideInLibrary'
const operations: Map<string, Promise<void>> = new Map()

/** A global user choice, independent of each source's device-local grid/list layout. */
export class SourceBrowsePreferencesStore {
  private context: common.UIAbilityContext
  constructor(context: common.UIAbilityContext) { this.context = context }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (operations.get(key) ?? Promise.resolve()).then(operation)
    operations.set(key, result.then(() => {}, () => {}))
    return result
  }

  async load(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, SOURCE_BROWSE_PREFERENCES)
      connectSourceBrowseState().hideInLibrary = await store.get(SOURCE_BROWSE_HIDE_IN_LIBRARY, false) === true
    })
  }

  async saveHideInLibrary(value: boolean): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, SOURCE_BROWSE_PREFERENCES)
      const existed = await store.has(SOURCE_BROWSE_HIDE_IN_LIBRARY)
      const previous = await store.get(SOURCE_BROWSE_HIDE_IN_LIBRARY, false)
      try {
        await store.put(SOURCE_BROWSE_HIDE_IN_LIBRARY, value)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(SOURCE_BROWSE_HIDE_IN_LIBRARY, previous)
        else await store.delete(SOURCE_BROWSE_HIDE_IN_LIBRARY)
        await store.flush()
        throw error as Error
      }
      connectSourceBrowseState().hideInLibrary = value
    }))
  }
}
