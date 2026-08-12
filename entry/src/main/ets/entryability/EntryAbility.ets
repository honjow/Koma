import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { KeyboardAvoidMode, window } from '@kit.ArkUI'
import {
  KOMA_LAUNCH_ROUTE_DOWNLOADS,
  KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS,
  KOMA_LAUNCH_ROUTE_PARAM,
  KOMA_LAUNCH_ROUTE_SOURCE_PACKAGE_MANAGER,
  KOMA_LAUNCH_ROUTE_TRACKER_SETTINGS,
} from '../common/Constants'
import { RouterHelper } from '../common/RouterHelper'
import { ReaderPreferencesStore, applyReaderThemeMode } from '../model/ReaderPreferencesStore'
import { RemoteProgressBootstrapSync } from '../model/RemoteProgressBootstrapSync'
import { bootstrapSourceRuntimeAppRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { maybeRunSourceRuntimeDeviceSmoke } from '../sourceRuntime/SourceRuntimeDeviceSmoke'
import { configureSourceRuntimeHttpTransport } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { configureSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { LayoutSafeAreaBridge } from '../state/LayoutSafeAreaState'
import { AppStrings } from '../i18n/AppStrings'
import { LanguageSettings } from '../i18n/LanguageSettings'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 107
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  private keyboardHeightCallback: ((height: number) => void) | undefined = undefined
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    AppStrings.init(this.context)
    void LanguageSettings.restore(this.context)
    this.applySavedThemeMode()
    configureSourceSettingsStore(this.context)
    configureSourceRuntimeHttpTransport()
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
      this.configureAvoidAreas(windowStage)
      this.syncRemoteProgressInBackground()
    })
  }

  onForeground(): void {
    this.syncRemoteProgressInBackground()
  }

  private configureAvoidAreas(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync()
      const uiContext = win.getUIContext()
      // Forms are List-based.  Compression gives the List a smaller real
      // viewport and preserves native scrolling to its tail above the IME;
      // caret-only avoidance left the viewport at full height on device.
      uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
      this.publishAvoidHeights(win)
      win.on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_KEYBOARD) {
          LayoutSafeAreaBridge.publishKeyboardHeight(uiContext.px2vp(data.area.bottomRect.height))
          return
        }
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM ||
          data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.publishAvoidHeights(win)
        }
      })
      // Keyboard avoid-area notifications are not delivered consistently by
      // this device while the window is resized.  The Window keyboard-height
      // callback is the authoritative signal for the root tab shell and every
      // list scaffold; keep the avoid-area branch above only as a fallback.
      this.keyboardHeightCallback = (height: number): void => {
        LayoutSafeAreaBridge.publishKeyboardHeight(uiContext.px2vp(Math.max(0, height)))
      }
      win.on('keyboardHeightChange', this.keyboardHeightCallback)
    } catch (error) {
      void error
      console.error('[EntryAbility] step=configure_avoid_areas_failed code=avoid_area_failed')
      LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
      LayoutSafeAreaBridge.publishKeyboardHeight(0)
    }
  }

  private publishAvoidHeights(win: window.Window): void {
    try {
      const uiContext = win.getUIContext()
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const navigationArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      const keyboardArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD)
      LayoutSafeAreaBridge.publishInsets(
        uiContext.px2vp(systemArea.topRect.height),
        uiContext.px2vp(navigationArea.bottomRect.height),
      )
      LayoutSafeAreaBridge.publishKeyboardHeight(uiContext.px2vp(keyboardArea.bottomRect.height))
    } catch (error) {
      void error
      console.error('[EntryAbility] step=publish_avoid_heights_failed code=avoid_area_failed')
      LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
      LayoutSafeAreaBridge.publishKeyboardHeight(0)
    }
  }

  private syncRemoteProgressInBackground(): void {
    void new RemoteProgressBootstrapSync(this.context).syncAllPrivateLibraryProgress()
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
    } else if (route === KOMA_LAUNCH_ROUTE_SOURCE_PACKAGE_MANAGER) {
      RouterHelper.pushSourcePackageManager()
    } else if (route === KOMA_LAUNCH_ROUTE_TRACKER_SETTINGS) {
      RouterHelper.pushTrackerSettings()
    }
  }
}
