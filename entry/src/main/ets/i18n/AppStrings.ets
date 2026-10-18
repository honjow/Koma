import { common } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { connectLanguageState } from '../state/LanguageState'

export class AppStrings {
  private static context: common.UIAbilityContext | null = null
  private static overrideResMgr: resourceManager.ResourceManager | null = null

  static init(context: common.UIAbilityContext): void {
    AppStrings.context = context
  }

  static setOverrideLocale(locale: string): string {
    if (locale.length === 0) {
      AppStrings.overrideResMgr = null
      return locale
    }
    if (AppStrings.context === null) throw new Error('language_resources_not_initialized')
    const config: resourceManager.Configuration = AppStrings.context.resourceManager.getOverrideConfiguration()
    config.locale = locale
    // Construction must succeed before replacing the previous manager.
    const next = AppStrings.context.resourceManager.getOverrideResourceManager(config)
    AppStrings.overrideResMgr = next
    return locale
  }

  static get(name: string): string {
    // Read the locale signal so computed labels repaint on in-app language switches.
    const observed: string = connectLanguageState().effectiveLocale
    if (observed.length < 0) {
      return name
    }
    const mgr: resourceManager.ResourceManager | undefined =
      AppStrings.overrideResMgr ?? AppStrings.context?.resourceManager
    if (mgr === undefined) {
      return name
    }
    try {
      return mgr.getStringByNameSync(name)
    } catch (_error) {
      return name
    }
  }

  static format(name: string, ...args: Array<string | number>): string {
    let value = AppStrings.get(name)
    args.forEach((arg: string | number) => {
      value = value.replace('%s', `${arg}`)
    })
    return value
  }
}
