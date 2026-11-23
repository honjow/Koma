import {
  DEFAULT_DETAIL_TRANSITION_MODE,
  appearanceAccentValue,
  normalizeAppearanceDetailTransitionMode,
  connectAppearanceState,
  DEFAULT_APPEARANCE_COLOR_FAVORITES,
  isCustomAppearanceAccentColor,
  MAX_APPEARANCE_COLOR_FAVORITES,
} from '../state/AppearanceState'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'

export interface AppearancePreferences {
  accentColor: string
}

const APPEARANCE_PREFERENCES_STORE_NAME: string = 'koma_appearance_preferences_v1'
const DETAIL_TRANSITION_MODE_KEY: string = 'appearance.detailTransitionMode'
const ACCENT_COLOR_KEY: string = 'appearance.accentColor'
const ACCENT_FAVORITES_KEY: string = 'appearance.accentColorFavorites'
const AUTO_HIDE_BOTTOM_BAR_KEY: string = 'appearance.autoHideBottomBar'
const SHOW_RESUME_MINI_BAR_KEY: string = 'appearance.showResumeMiniBar'
const DOUBLE_BACK_TO_EXIT_KEY: string = 'navigation.backGuardEnabled'

export const DEFAULT_APPEARANCE_PREFERENCES: AppearancePreferences = {
  accentColor: 'emerald',
}

export const APPEARANCE_ACCENT_PRESETS: string[] = ['emerald', 'ocean', 'rose', 'amber', 'mono']

export function normalizeAppearanceAccentColor(value: string): string {
  if (typeof value !== 'string') return DEFAULT_APPEARANCE_PREFERENCES.accentColor
  const color = value.trim()
  if (APPEARANCE_ACCENT_PRESETS.includes(color)) return color
  if (isCustomAppearanceAccentColor(color)) return color.toUpperCase()
  return DEFAULT_APPEARANCE_PREFERENCES.accentColor
}

export function getAppearanceAccentColorLabel(value: string): string {
  if (isCustomAppearanceAccentColor(value)) {
    return AppStrings.get('appearance_accent_custom')
  }
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

export function getAppearanceAccentColorValue(value: string): ResourceColor {
  return appearanceAccentValue(value, $r('app.color.koma_accent'))
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
      const state = connectAppearanceState()
      state.accentColor = accentColor
      state.detailTransitionMode = normalizeAppearanceDetailTransitionMode(
        await store.get(DETAIL_TRANSITION_MODE_KEY, DEFAULT_DETAIL_TRANSITION_MODE) as string)
      state.autoHideBottomBar = await store.get(AUTO_HIDE_BOTTOM_BAR_KEY, true) as boolean
      state.showResumeMiniBar = await store.get(SHOW_RESUME_MINI_BAR_KEY, true) !== false
      state.doubleBackToExit = await store.get(DOUBLE_BACK_TO_EXIT_KEY, true) as boolean
      const favorites = await store.get(ACCENT_FAVORITES_KEY, '') as string
      state.accentColorFavorites = this.readAccentFavorites(favorites)
      return { accentColor }
    })
  }

  async saveAccentColor(accentColor: string): Promise<AppearancePreferences> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<AppearancePreferences> => {
      const normalized = normalizeAppearanceAccentColor(accentColor)
      const store = await this.preferences()
      await this.writePreference(store, ACCENT_COLOR_KEY, normalized)
      connectAppearanceState().accentColor = normalized
      return { accentColor: normalized }
    }))
  }

  changeAccentFavorite(color: string, add: boolean): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      if (!isCustomAppearanceAccentColor(color)) return
      const normalized = color.toUpperCase()
      const state = connectAppearanceState()
      const next = state.accentColorFavorites.slice()
      const index = next.indexOf(normalized)
      if (add) {
        if (index >= 0 || next.length >= MAX_APPEARANCE_COLOR_FAVORITES) return
        next.push(normalized)
      } else {
        if (index < 0) return
        next.splice(index, 1)
      }
      await this.writePreference(await this.preferences(), ACCENT_FAVORITES_KEY, JSON.stringify(next))
      state.accentColorFavorites = next
    }))
  }

  private readAccentFavorites(raw: string): string[] {
    if (raw === '') return DEFAULT_APPEARANCE_COLOR_FAVORITES.slice()
    try {
      const decoded = JSON.parse(raw) as Object
      if (Array.isArray(decoded)) {
        const colors: string[] = []
        for (const value of decoded as Object[]) {
          if (typeof value !== 'string' || !isCustomAppearanceAccentColor(value)) continue
          const color = value.toUpperCase()
          if (!colors.includes(color)) colors.push(color)
          if (colors.length === MAX_APPEARANCE_COLOR_FAVORITES) break
        }
        return colors
      }
    } catch (_error) {
      // Use the initial palette for malformed stored values.
    }
    return DEFAULT_APPEARANCE_COLOR_FAVORITES.slice()
  }

  saveDetailTransitionMode(mode: string): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      const normalized = normalizeAppearanceDetailTransitionMode(mode)
      await this.writePreference(await this.preferences(), DETAIL_TRANSITION_MODE_KEY, normalized)
      connectAppearanceState().detailTransitionMode = normalized
    }))
  }

  saveAutoHideBottomBar(enabled: boolean): Promise<void> {
    return this.saveBooleanPreference(AUTO_HIDE_BOTTOM_BAR_KEY, enabled, () => {
      connectAppearanceState().autoHideBottomBar = enabled
    })
  }

  saveShowResumeMiniBar(enabled: boolean): Promise<void> {
    return this.saveBooleanPreference(SHOW_RESUME_MINI_BAR_KEY, enabled, () => {
      connectAppearanceState().showResumeMiniBar = enabled
    })
  }

  saveDoubleBackToExit(enabled: boolean): Promise<void> {
    return this.saveBooleanPreference(DOUBLE_BACK_TO_EXIT_KEY, enabled, () => {
      connectAppearanceState().doubleBackToExit = enabled
    })
  }

  private saveBooleanPreference(key: string, enabled: boolean, publish: () => void): Promise<void> {
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<void> => {
      const store = await this.preferences()
      await this.writePreference(store, key, enabled)
      publish()
    }))
  }

  private async writePreference(store: preferences.Preferences, key: string, value: string | boolean): Promise<void> {
    const existed = await store.has(key)
    const previous = await store.get(key, value)
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
    return preferences.getPreferences(this.context, APPEARANCE_PREFERENCES_STORE_NAME)
  }
}
