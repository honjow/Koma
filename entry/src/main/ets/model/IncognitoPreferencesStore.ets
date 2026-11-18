import { connectIncognitoState } from '../state/IncognitoState'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export interface IncognitoPreferences {
  enabled: boolean
}

const INCOGNITO_PREFERENCES_STORE_NAME: string = 'koma_incognito_preferences_v1'
const INCOGNITO_ENABLED_KEY: string = 'incognito.enabled'
const INCOGNITO_SOURCES_KEY: string = 'incognito.sourceIds'

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
      const sourceIds = await this.loadSourceIds(store)
      const state = connectIncognitoState()
      state.enabled = enabled
      state.sourceIds = sourceIds
      return { enabled }
    })
  }

  async saveEnabled(enabled: boolean): Promise<IncognitoPreferences> {
    return this.ordered(async (): Promise<IncognitoPreferences> => {
      const store = await this.preferences()
      await this.persist(store, INCOGNITO_ENABLED_KEY, enabled, DEFAULT_INCOGNITO_PREFERENCES.enabled)
      connectIncognitoState().enabled = enabled
      return { enabled }
    })
  }

  // The app owns this local preference by source ID across source updates.
  async saveSourceEnabled(sourceId: string, enabled: boolean): Promise<void> {
    return this.ordered(async (): Promise<void> => {
      const store = await this.preferences()
      const current = await this.loadSourceIds(store)
      if (current.includes(sourceId) === enabled) return
      const sourceIds = enabled ? current.concat(sourceId) : current.filter((id: string): boolean => id !== sourceId)
      await this.persist(store, INCOGNITO_SOURCES_KEY, sourceIds, [])
      connectIncognitoState().sourceIds = sourceIds
    })
  }

  private async loadSourceIds(store: preferences.Preferences): Promise<string[]> {
    const raw = await store.get(INCOGNITO_SOURCES_KEY, [])
    return Array.isArray(raw) ? (raw as string[]).filter((id: string): boolean => typeof id === 'string' && id.length > 0) : []
  }

  private async persist(store: preferences.Preferences, key: string, value: boolean | string[],
    fallback: boolean | string[]): Promise<void> {
    const existed = await store.has(key)
    const previous = await store.get(key, fallback)
    try {
      await store.put(key, value)
      await store.flush()
    } catch (error) {
      if (existed) await store.put(key, previous)
      else await store.delete(key)
      await store.flush()
      throw error as Error
    }
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, INCOGNITO_PREFERENCES_STORE_NAME)
  }
}
