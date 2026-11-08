import { connectIncognitoState } from '../state/IncognitoState'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export interface IncognitoPreferences {
  enabled: boolean
}

const INCOGNITO_PREFERENCES_STORE_NAME: string = 'koma_incognito_preferences_v1'
const INCOGNITO_ENABLED_KEY: string = 'incognito.enabled'

export const DEFAULT_INCOGNITO_PREFERENCES: IncognitoPreferences = {
  enabled: false,
}

const incognitoOperations: Map<string, Promise<void>> = new Map()

export class IncognitoPreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (incognitoOperations.get(key) ?? Promise.resolve()).then(operation)
    incognitoOperations.set(key, result.then(() => {}, () => {}))
    return result
  }

  async load(): Promise<IncognitoPreferences> {
    return this.ordered(async (): Promise<IncognitoPreferences> => {
      const store = await this.preferences()
      const raw = await store.get(INCOGNITO_ENABLED_KEY, DEFAULT_INCOGNITO_PREFERENCES.enabled) as boolean
      const enabled = raw === true
      connectIncognitoState().enabled = enabled
      return { enabled }
    })
  }

  async saveEnabled(enabled: boolean): Promise<IncognitoPreferences> {
    return this.ordered(async (): Promise<IncognitoPreferences> => {
      const store = await this.preferences()
      const existed = await store.has(INCOGNITO_ENABLED_KEY)
      const previous = await store.get(INCOGNITO_ENABLED_KEY, DEFAULT_INCOGNITO_PREFERENCES.enabled)
      try {
        await store.put(INCOGNITO_ENABLED_KEY, enabled)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(INCOGNITO_ENABLED_KEY, previous)
        else await store.delete(INCOGNITO_ENABLED_KEY)
        await store.flush()
        throw error as Error
      }
      connectIncognitoState().enabled = enabled
      return { enabled }
    })
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, INCOGNITO_PREFERENCES_STORE_NAME)
  }
}
