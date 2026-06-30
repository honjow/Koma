import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { i18n } from '@kit.LocalizationKit'
import { AppStrings } from './AppStrings'
import { connectLanguageState } from '../state/LanguageState'

const APP_PREFERENCES_STORE_NAME: string = 'koma_app_preferences_v1'
const APP_LANGUAGE_KEY: string = 'app.language'

export class LanguageSettings {
  static readonly MODE_SYSTEM: string = 'system'
  static readonly MODE_ZH_CN: string = 'zh-Hans'
  static readonly MODE_EN_US: string = 'en-US'

  static normalize(mode: string): string {
    if (mode === LanguageSettings.MODE_ZH_CN || mode === LanguageSettings.MODE_EN_US) {
      return mode
    }
    return LanguageSettings.MODE_SYSTEM
  }

  private static resolveLocale(mode: string): string {
    if (mode !== LanguageSettings.MODE_SYSTEM) {
      return mode
    }
    try {
      return i18n.System.getSystemLanguage()
    } catch (_error) {
      return ''
    }
  }

  static label(mode: string): string {
    const normalized = LanguageSettings.normalize(mode)
    if (normalized === LanguageSettings.MODE_ZH_CN) {
      return AppStrings.get('language_zh_cn')
    }
    if (normalized === LanguageSettings.MODE_EN_US) {
      return AppStrings.get('language_en_us')
    }
    return AppStrings.get('language_system')
  }

  static apply(mode: string): void {
    const normalized: string = LanguageSettings.normalize(mode)
    const locale: string = LanguageSettings.resolveLocale(normalized)
    if (locale.length > 0) {
      try {
        i18n.System.setAppPreferredLanguage(locale)
      } catch (_error) {
      }
    }
    AppStrings.setOverrideLocale(normalized === LanguageSettings.MODE_SYSTEM ? '' : normalized)
    const state = connectLanguageState()
    state.mode = normalized
    state.effectiveLocale = normalized === LanguageSettings.MODE_SYSTEM ? locale : normalized
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, APP_PREFERENCES_STORE_NAME)
      const mode = store.getSync(APP_LANGUAGE_KEY, LanguageSettings.MODE_SYSTEM) as string
      LanguageSettings.apply(mode)
    } catch (_error) {
      LanguageSettings.apply(LanguageSettings.MODE_SYSTEM)
    }
  }

  static async setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = LanguageSettings.normalize(mode)
    LanguageSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, APP_PREFERENCES_STORE_NAME)
      store.putSync(APP_LANGUAGE_KEY, normalized)
      store.flushSync()
    } catch (_error) {
    }
  }
}
