import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'
import { ReaderPreferencesStore, applyReaderThemeMode } from '../model/ReaderPreferencesStore'
import { RemoteProgressBootstrapSync } from '../model/RemoteProgressBootstrapSync'
import { bootstrapSourceRuntimeAppRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { maybeRunSourceRuntimeDeviceSmoke } from '../sourceRuntime/SourceRuntimeDeviceSmoke'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 107
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    this.applySavedThemeMode()
    bootstrapSourceRuntimeAppRegistry(this.context)
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager, this.context)
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager, this.context)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync()
      win.setWindowLayoutFullScreen(true)
      win.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_COLOR,
        navigationBarColor: TRANSPARENT_COLOR,
      })
    } catch (error) {
      const e = error as Error
      console.error('configure window failed: ' + e.message)
    }

    windowStage.loadContent(ENTRY_PAGE, (err) => {
      if (err.code) {
        console.error('loadContent failed: ' + JSON.stringify(err))
      }
      this.storeAvoidHeights(windowStage)
      this.syncRemoteProgressInBackground()
    })
  }

  onForeground(): void {
    this.syncRemoteProgressInBackground()
  }

  private storeAvoidHeights(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync()
      const uiContext = win.getUIContext()
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const navigationArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      AppStorage.setOrCreate<number>(
        StorageKeys.TOP_AVOID_HEIGHT,
        uiContext.px2vp(systemArea.topRect.height),
      )
      AppStorage.setOrCreate<number>(
        StorageKeys.BOTTOM_AVOID_HEIGHT,
        uiContext.px2vp(navigationArea.bottomRect.height),
      )
      AppStorage.setOrCreate<number>(StorageKeys.KEYBOARD_HEIGHT, 0)
    } catch (error) {
      const e = error as Error
      console.error('store avoid heights failed: ' + e.message)
      AppStorage.setOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, FALLBACK_TOP_AVOID)
      AppStorage.setOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, FALLBACK_BOTTOM_AVOID)
      AppStorage.setOrCreate<number>(StorageKeys.KEYBOARD_HEIGHT, 0)
    }
  }

  private syncRemoteProgressInBackground(): void {
    void new RemoteProgressBootstrapSync(this.context).syncAllKomgaProgress()
  }

  private applySavedThemeMode(): void {
    void new ReaderPreferencesStore(this.context).load()
      .then((preferences) => {
        applyReaderThemeMode(this.context, preferences.themeMode)
        console.info('[Settings] step=apply_startup_theme value=' + preferences.themeMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=apply_startup_theme_failed message=' + error.message)
      })
  }
}
