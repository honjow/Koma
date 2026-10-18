import { connectAppearanceState, appearanceAccentValue } from '../state/AppearanceState'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'

export type AppearanceAccentColor = 'emerald' | 'ocean' | 'rose' | 'amber' | 'mono'

export interface AppearancePreferences {
  accentColor: AppearanceAccentColor
}

const APPEARANCE_PREFERENCES_STORE_NAME: string = 'koma_appearance_preferences_v1'
const ACCENT_COLOR_KEY: string = 'appearance.accentColor'

export const DEFAULT_APPEARANCE_PREFERENCES: AppearancePreferences = {
  accentColor: 'emerald',
}

export function normalizeAppearanceAccentColor(value: string): AppearanceAccentColor {
  if (value === 'ocean' || value === 'rose' || value === 'amber' || value === 'mono') {
    return value
  }
  return 'emerald'
}

export function getAppearanceAccentColorLabel(value: AppearanceAccentColor): string {
  if (value === 'ocean') {
    return AppStrings.get('appearance_accent_ocean')
  }
  if (value === 'rose') {
    return AppStrings.get('appearance_accent_rose')
  }
  if (value === 'amber') {
    return AppStrings.get('appearance_accent_amber')
  }
  if (value === 'mono') {
    return AppStrings.get('appearance_accent_mono')
  }
  return AppStrings.get('appearance_accent_emerald')
}

export function getAppearanceAccentColorValue(value: AppearanceAccentColor): ResourceColor {
  return appearanceAccentValue(value, '#256E5D')
}

const appearanceOperations: Map<string, Promise<void>> = new Map()

export class AppearancePreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (appearanceOperations.get(key) ?? Promise.resolve()).then(operation)
    appearanceOperations.set(key, result.then(() => {}, () => {}))
    return result
  }

  async load(): Promise<AppearancePreferences> {
    return this.ordered(async (): Promise<AppearancePreferences> => {
      const store = await this.preferences()
      const raw = await store.get(ACCENT_COLOR_KEY, DEFAULT_APPEARANCE_PREFERENCES.accentColor) as string
      const accentColor = normalizeAppearanceAccentColor(raw)
      connectAppearanceState().accentColor = accentColor
      return { accentColor }
    })
  }

  async saveAccentColor(accentColor: AppearanceAccentColor): Promise<AppearancePreferences> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<AppearancePreferences> => {
      const normalized = normalizeAppearanceAccentColor(accentColor)
      const store = await this.preferences()
      const existed = await store.has(ACCENT_COLOR_KEY)
      const previous = await store.get(ACCENT_COLOR_KEY, DEFAULT_APPEARANCE_PREFERENCES.accentColor)
      try {
        await store.put(ACCENT_COLOR_KEY, normalized)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(ACCENT_COLOR_KEY, previous)
        else await store.delete(ACCENT_COLOR_KEY)
        await store.flush()
        throw error as Error
      }
      connectAppearanceState().accentColor = normalized
      return { accentColor: normalized }
    }))
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, APPEARANCE_PREFERENCES_STORE_NAME)
  }
}
