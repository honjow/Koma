import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { captureReaderLabWant, updateReaderLabForeground } from '@reader-kit/ui'
import { KeyboardAvoidMode, window } from '@kit.ArkUI'
import {
  KOMA_LAUNCH_ROUTE_DOWNLOADS,
  KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS,
  KOMA_LAUNCH_ROUTE_PARAM,
  KOMA_LAUNCH_ROUTE_READER,
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
import { AppForegroundStateBridge } from '../state/AppForegroundState'
import { AppStrings } from '../i18n/AppStrings'
import { LanguageSettings } from '../i18n/LanguageSettings'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 40
const FALLBACK_BOTTOM_AVOID: number = 0

/** Debug-only device lab: pin the main-window orientation for the shared-reader
 *  rotation acceptance on a large-screen device. Read from an explicit Want only,
 *  never a persisted setting, and unreachable in a release build (debug gate). */
function labOrientationFromWant(want: Want, debugBuild: boolean): window.Orientation | undefined {
  if (!debugBuild) {
    return undefined
  }
  const value = want.parameters?.['readerLabOrientation']
  if (value === 'landscape') {
    return window.Orientation.LANDSCAPE
  }
  if (value === 'portrait') {
    return window.Orientation.PORTRAIT
  }
  return undefined
}

export default class EntryAbility extends UIAbility {
  private keyboardHeightCallback: ((height: number) => void) | undefined = undefined
  /** Debug-only orientation override; undefined means the production auto-rotation opt-in. */
  private labOrientation: window.Orientation | undefined = undefined
  private windowStageRef: window.WindowStage | null = null
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    captureReaderLabWant(want, this.context.applicationInfo.debug)
    this.labOrientation = labOrientationFromWant(want, this.context.applicationInfo.debug)
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
    captureReaderLabWant(want, this.context.applicationInfo.debug)
    this.labOrientation = labOrientationFromWant(want, this.context.applicationInfo.debug)
    void launchParam
    this.applyPreferredOrientation()
    this.openLaunchRouteFromWant(want)
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager, this.context)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStageRef = windowStage
    try {
      const win = windowStage.getMainWindowSync()
      win.setWindowLayoutFullScreen(true)
      win.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_COLOR,
        navigationBarColor: TRANSPARENT_COLOR,
      })
      // Match NextE: opt the main window into sensor-driven rotation. The
      // system rotation-lock toggle still pins portrait when enabled. A debug
      // lab Want may pin a fixed orientation afterwards for rotation acceptance.
      this.applyPreferredOrientation()
    } catch (error) {
      void error
      console.error('[EntryAbility] step=configure_window_failed code=window_configure_failed')
    }

    windowStage.loadContent(ENTRY_PAGE, (err) => {
      if (err.code) {
        console.error('[EntryAbility] step=load_content_failed code=load_content_failed')
      }
      this.configureAvoidAreas(windowStage)
      setTimeout(() => {
        this.syncRemoteProgressInBackground()
      }, 250)
    })
  }

  onForeground(): void {
    updateReaderLabForeground(true, this.context.applicationInfo.debug)
    AppForegroundStateBridge.onForeground()
    setTimeout(() => {
      this.syncRemoteProgressInBackground()
    }, 250)
  }

  onBackground(): void {
    updateReaderLabForeground(false, this.context.applicationInfo.debug)
    AppForegroundStateBridge.onBackground()
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
        this.publishAvoidHeights(win)
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
      const top: number = Math.max(
        this.topHeight(win, uiContext, window.AvoidAreaType.TYPE_SYSTEM),
        this.topHeight(win, uiContext, window.AvoidAreaType.TYPE_CUTOUT),
      )
      const bottom: number = Math.max(
        this.bottomHeight(win, uiContext, window.AvoidAreaType.TYPE_SYSTEM),
        this.bottomHeight(win, uiContext, window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR),
        this.bottomHeight(win, uiContext, window.AvoidAreaType.TYPE_SYSTEM_GESTURE),
      )
      const keyboardArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD)
      LayoutSafeAreaBridge.publishInsets(top, bottom)
      LayoutSafeAreaBridge.publishKeyboardHeight(uiContext.px2vp(keyboardArea.bottomRect.height))
    } catch (error) {
      void error
      console.error('[EntryAbility] step=publish_avoid_heights_failed code=avoid_area_failed')
      LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
      LayoutSafeAreaBridge.publishKeyboardHeight(0)
    }
  }

  private topHeight(win: window.Window, uiCtx: UIContext, type: window.AvoidAreaType): number {
    try {
      return uiCtx.px2vp(win.getWindowAvoidArea(type).topRect.height)
    } catch (_error) {
      return 0
    }
  }

  private bottomHeight(win: window.Window, uiCtx: UIContext, type: window.AvoidAreaType): number {
    try {
      return uiCtx.px2vp(win.getWindowAvoidArea(type).bottomRect.height)
    } catch (_error) {
      return 0
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

  /** Applies the debug lab orientation override, else the production auto-rotation opt-in. */
  private applyPreferredOrientation(): void {
    const stage = this.windowStageRef
    if (stage === null) {
      return
    }
    try {
      const win = stage.getMainWindowSync()
      const orientation: window.Orientation = this.labOrientation !== undefined
        ? this.labOrientation
        : window.Orientation.AUTO_ROTATION_UNSPECIFIED
      win.setPreferredOrientation(orientation)
        .catch((error: Error) => {
          console.error('[EntryAbility] step=set_orientation_failed code=orientation_request_failed msg=' + error.message)
        })
    } catch (error) {
      void error
      console.error('[EntryAbility] step=configure_window_failed code=window_configure_failed')
    }
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
    } else if (route === KOMA_LAUNCH_ROUTE_READER) {
      RouterHelper.pushReader()
    }
  }
}
