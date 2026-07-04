import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import {
  KOMA_LAUNCH_ROUTE_DOWNLOADS,
  KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS,
  KOMA_LAUNCH_ROUTE_PARAM,
} from '../common/Constants'
import { RouterHelper } from '../common/RouterHelper'
import { ReaderPreferencesStore, applyReaderThemeMode } from '../model/ReaderPreferencesStore'
import { RemoteProgressBootstrapSync } from '../model/RemoteProgressBootstrapSync'
import { bootstrapSourceRuntimeAppRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { maybeRunSourceRuntimeDeviceSmoke } from '../sourceRuntime/SourceRuntimeDeviceSmoke'
import { configureSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { LayoutSafeAreaBridge } from '../state/LayoutSafeAreaState'
import { AppStrings } from '../i18n/AppStrings'
import { LanguageSettings } from '../i18n/LanguageSettings'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 107
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    AppStrings.init(this.context)
    void LanguageSettings.restore(this.context)
    this.applySavedThemeMode()
    configureSourceSettingsStore(this.context)
    bootstrapSourceRuntimeAppRegistry(this.context)
    this.openLaunchRouteFromWant(want)
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager, this.context)
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    this.openLaunchRouteFromWant(want)
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
      void error
      console.error('[EntryAbility] step=configure_window_failed code=window_configure_failed')
    }

    windowStage.loadContent(ENTRY_PAGE, (err) => {
      if (err.code) {
        console.error('[EntryAbility] step=load_content_failed code=load_content_failed')
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
      LayoutSafeAreaBridge.publishInsets(
        uiContext.px2vp(systemArea.topRect.height),
        uiContext.px2vp(navigationArea.bottomRect.height),
      )
      LayoutSafeAreaBridge.publishKeyboardHeight(0)
    } catch (error) {
      void error
      console.error('[EntryAbility] step=store_avoid_heights_failed code=avoid_area_failed')
      LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
      LayoutSafeAreaBridge.publishKeyboardHeight(0)
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
        void error
        console.warn('[Settings] step=apply_startup_theme_failed code=theme_apply_failed')
      })
  }

  private openLaunchRouteFromWant(want: Want): void {
    const route = want.parameters?.[KOMA_LAUNCH_ROUTE_PARAM]
    if (route === KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS) {
      RouterHelper.pushLibraryUpdateResults()
    } else if (route === KOMA_LAUNCH_ROUTE_DOWNLOADS) {
      RouterHelper.pushDownloads()
    }
  }
}
