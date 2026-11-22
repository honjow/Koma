import { bundleManager } from '@kit.AbilityKit'
import { AppStorageV2 } from '@kit.ArkUI'
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export interface AppIconOption {
  name: string
  labelKey: string
  foreground: Resource
  background: Resource
}

// Stable system names match AppScope/app.json5. An empty name restores the original icon.
export const APP_ICON_OPTIONS: AppIconOption[] = [
  { name: '', labelKey: 'settings_app_icon_default',
    foreground: $r('app.media.app_icon_emerald_solid_foreground'), background: $r('app.media.app_icon_emerald_solid_background') },
  { name: 'lake', labelKey: 'settings_app_icon_lake',
    foreground: $r('app.media.app_icon_lake_foreground'), background: $r('app.media.app_icon_lake_background') },
  { name: 'plum', labelKey: 'settings_app_icon_plum',
    foreground: $r('app.media.app_icon_plum_foreground'), background: $r('app.media.app_icon_plum_background') },
  { name: 'cinnabar', labelKey: 'settings_app_icon_cinnabar',
    foreground: $r('app.media.app_icon_cinnabar_foreground'), background: $r('app.media.app_icon_cinnabar_background') },
  { name: 'paper', labelKey: 'settings_app_icon_paper',
    foreground: $r('app.media.app_icon_paper_foreground'), background: $r('app.media.app_icon_paper_background') },
  { name: 'night', labelKey: 'settings_app_icon_night',
    foreground: $r('app.media.app_icon_night_foreground'), background: $r('app.media.app_icon_night_background') },
]

@ObservedV2
export class AppIconState {
  @Trace activeName: string | undefined = undefined
  @Trace availableNames: string[] = []
  @Trace loadFailed: boolean = false
  @Trace changing: boolean = false

  activeOption(): AppIconOption | undefined {
    return APP_ICON_OPTIONS.find((option: AppIconOption): boolean => option.name === this.activeName)
  }
}

export function connectAppIconState(): AppIconState {
  return AppStorageV2.connect(AppIconState, 'koma:launcherIcon', () => new AppIconState())!
}

export class AppIconSettings {
  private static refreshRequest: Promise<void> | undefined = undefined

  static supported(): boolean {
    return deviceInfo.apiAvailable('26.0.0')
  }

  // The system owns persistence. The settings row and grid share its last confirmed state.
  static refresh(): Promise<void> {
    if (!AppIconSettings.supported()) return Promise.resolve()
    const state = connectAppIconState()
    if (state.changing) return Promise.resolve()
    if (AppIconSettings.refreshRequest === undefined) {
      AppIconSettings.refreshRequest = AppIconSettings.read(state).finally((): void => {
        AppIconSettings.refreshRequest = undefined
      })
    }
    return AppIconSettings.refreshRequest
  }

  private static async read(state: AppIconState): Promise<void> {
    state.loadFailed = false
    try {
      const icons = await bundleManager.getAlternateIcons()
      state.availableNames = icons.map((icon: bundleManager.AlternateIconInfo): string => icon.iconName)
      state.activeName = icons.find((icon: bundleManager.AlternateIconInfo): boolean => icon.enabled)?.iconName ?? ''
    } catch (error) {
      state.loadFailed = state.activeName === undefined
      DiagnosticLogger.warn('app_icon', 'load_failed', 'code=' + (error as BusinessError).code)
    }
  }

  static async select(name: string): Promise<void> {
    if (!AppIconSettings.supported()) return
    const state = connectAppIconState()
    if (state.changing || state.activeName === undefined) return
    state.changing = true
    try {
      await AppIconSettings.refreshRequest
      if (name === state.activeName || (name.length > 0 && !state.availableNames.includes(name))) return
      await bundleManager.setAlternateIcon(name)
      state.activeName = name
    } catch (error) {
      DiagnosticLogger.warn('app_icon', 'switch_failed', 'code=' + (error as BusinessError).code)
      throw error as Error
    } finally {
      state.changing = false
    }
  }
}
