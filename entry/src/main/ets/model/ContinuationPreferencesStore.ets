import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectContinuationState } from '../state/ContinuationState'
import { BackupRestoreActivity } from './BackupRestoreActivity'

export const CONTINUATION_PREFERENCES_STORE_NAME: string = 'koma_continuation_preferences_v1'
export const CONTINUATION_ENABLED_KEY: string = 'continuation.enabled'
export const CONTINUATION_AUTO_INSTALL_MISSING_SOURCE_KEY: string = 'continuation.autoInstallMissingSource'

const operations: Map<string, Promise<void>> = new Map()

/** Stores user preferences for HarmonyOS cross-device reading continuation. */
export class ContinuationPreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (operations.get(key) ?? Promise.resolve()).then(operation)
    operations.set(key, result.then(() => {}, () => {}))
    return result
  }

  async load(): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, CONTINUATION_PREFERENCES_STORE_NAME)
      const state = connectContinuationState()
      state.enabled = await store.get(CONTINUATION_ENABLED_KEY, true) !== false
      state.autoInstallMissingSource = await store.get(CONTINUATION_AUTO_INSTALL_MISSING_SOURCE_KEY, true) !== false
    })
  }

  saveEnabled(enabled: boolean): Promise<void> {
    return this.saveBoolean(CONTINUATION_ENABLED_KEY, enabled, () => {
      connectContinuationState().enabled = enabled
    })
  }

  saveAutoInstallMissingSource(enabled: boolean): Promise<void> {
    return this.saveBoolean(CONTINUATION_AUTO_INSTALL_MISSING_SOURCE_KEY, enabled, () => {
      connectContinuationState().autoInstallMissingSource = enabled
    })
  }

  private saveBoolean(key: string, value: boolean, publish: () => void): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, CONTINUATION_PREFERENCES_STORE_NAME)
      const existed = await store.has(key)
      const previous = await store.get(key, true)
      try {
        await store.put(key, value)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(key, previous)
        else await store.delete(key)
        await store.flush()
        throw error as Error
      }
      publish()
    }))
  }
}
