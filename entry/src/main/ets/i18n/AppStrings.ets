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
    if (locale.length === 0 || AppStrings.context === null) {
      AppStrings.overrideResMgr = null
      return locale
    }
    try {
      const config: resourceManager.Configuration = AppStrings.context.resourceManager.getOverrideConfiguration()
      config.locale = locale
      AppStrings.context.resourceManager.updateOverrideConfiguration(config)
      AppStrings.overrideResMgr = AppStrings.context.resourceManager.getOverrideResourceManager(config)
    } catch (_error) {
      AppStrings.overrideResMgr = null
    }
    return locale
  }

  static get(name: string): string {
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
}
