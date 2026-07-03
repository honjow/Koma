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
  if (value === 'ocean') {
    return '#3268B8'
  }
  if (value === 'rose') {
    return '#B8466A'
  }
  if (value === 'amber') {
    return '#A66A1F'
  }
  if (value === 'mono') {
    return '#6C706C'
  }
  return '#256E5D'
}

export class AppearancePreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<AppearancePreferences> {
    const store = await this.preferences()
    const accentColor = await store.get(ACCENT_COLOR_KEY, DEFAULT_APPEARANCE_PREFERENCES.accentColor) as string
    return {
      accentColor: normalizeAppearanceAccentColor(accentColor),
    }
  }

  async saveAccentColor(accentColor: AppearanceAccentColor): Promise<AppearancePreferences> {
    const normalized = normalizeAppearanceAccentColor(accentColor)
    const store = await this.preferences()
    await store.put(ACCENT_COLOR_KEY, normalized)
    await store.flush()
    return {
      accentColor: normalized,
    }
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, APPEARANCE_PREFERENCES_STORE_NAME)
  }
}
