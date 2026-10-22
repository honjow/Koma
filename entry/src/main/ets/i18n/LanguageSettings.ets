import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { i18n } from '@kit.LocalizationKit'
import { AppStrings } from './AppStrings'
import { connectLanguageState } from '../state/LanguageState'

const APP_PREFERENCES_STORE_NAME: string = 'koma_app_preferences_v1'
const APP_LANGUAGE_KEY: string = 'app.language'

// Startup restore and settings edits share the same app preference publication order.
let languageMutations: Promise<void> = Promise.resolve()

function mutateLanguage(action: () => Promise<void>): Promise<void> {
  const result = languageMutations.then(action)
  languageMutations = result.catch((): void => {})
  return result
}

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
    return i18n.System.getSystemLanguage()
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
    const state = connectLanguageState()
    const previousMode = state.mode
    try {
      // The platform's documented sentinel restores future system-language following.
      i18n.System.setAppPreferredLanguage(normalized === LanguageSettings.MODE_SYSTEM ? 'default' : normalized)
      // Prepare and publish a separate resource manager; do not mutate the context's shared override.
      AppStrings.setOverrideLocale(locale)
    } catch (error) {
      try {
        i18n.System.setAppPreferredLanguage(previousMode === LanguageSettings.MODE_SYSTEM ? 'default' : previousMode)
      } catch (_rollbackError) {
        DiagnosticLogger.warn('language_settings', 'platform_restore_failed', '[Language] platform_restore_failed')
      }
      throw error as Error
    }
    state.mode = normalized
    state.effectiveLocale = locale
  }

  static restore(context: common.UIAbilityContext): Promise<void> {
    return mutateLanguage(async (): Promise<void> => {
      let mode = LanguageSettings.MODE_SYSTEM
      try {
        const store = await preferences.getPreferences(context, APP_PREFERENCES_STORE_NAME)
        mode = store.getSync(APP_LANGUAGE_KEY, LanguageSettings.MODE_SYSTEM) as string
      } catch (_error) {
        DiagnosticLogger.warn('language_settings', 'restore_failed', '[Language] restore_failed using_system=true')
      }
      LanguageSettings.apply(mode)
    })
  }

  static setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized = LanguageSettings.normalize(mode)
    return BackupRestoreActivity.runWrite(() => mutateLanguage(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, APP_PREFERENCES_STORE_NAME)
      const existed = store.hasSync(APP_LANGUAGE_KEY)
      const previous = store.getSync(APP_LANGUAGE_KEY, LanguageSettings.MODE_SYSTEM) as string
      try {
        store.putSync(APP_LANGUAGE_KEY, normalized)
        store.flushSync()
        LanguageSettings.apply(normalized)
      } catch (error) {
        // Preferences also caches putSync in memory. Do not let a later restore publish it.
        try {
          if (existed) store.putSync(APP_LANGUAGE_KEY, previous)
          else store.deleteSync(APP_LANGUAGE_KEY)
          store.flushSync()
        } catch (_rollbackError) {
          throw new Error('language_preference_restore_failed')
        }
        throw error as Error
      }
    }))
  }
}
