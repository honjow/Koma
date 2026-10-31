import { synchronizeBackgroundMaintenance } from '../model/BackgroundMaintenance'
import { ChapterListPreferencesStore } from '../model/ChapterListPreferencesStore'
import { deviceInfo } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { DiagnosticsSettings } from '../diagnostics/DiagnosticsSettings'
import { AppearancePreferencesStore } from '../model/AppearancePreferencesStore'
import { restoreReaderRemoteImageCache } from '../model/ReaderPageSourceAdapter'
import { UIAbility, Want, AbilityConstant, Configuration, bundleManager } from '@kit.AbilityKit'
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
import { ReaderPreferencesStore, bindReaderThemeWindow, unbindReaderThemeWindow } from '../model/ReaderPreferencesStore'
import { RemoteProgressBootstrapSync } from '../model/RemoteProgressBootstrapSync'
import { bootstrapSourceRuntimeAppRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { maybeRunSourceRuntimeDeviceSmoke } from '../sourceRuntime/SourceRuntimeDeviceSmoke'
import { configureSourceRuntimeHttpTransport } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { configureSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { LayoutSafeAreaBridge } from '../state/LayoutSafeAreaState'
import { AppForegroundStateBridge } from '../state/AppForegroundState'
import {
  captureKomaDeviceVerificationIsolation,
  shouldSuppressKomaDeviceVerificationBackgroundSideEffects,
} from '../state/KomaDeviceVerificationIsolation'
import { AppStrings } from '../i18n/AppStrings'
import { LanguageSettings } from '../i18n/LanguageSettings'
import { BackupRestoreCheckpoint } from '../model/BackupRestoreCheckpoint'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { automationEpoch, finishAutomationRestore, resetGeneratedAutomationWork } from '../model/AutomationStateEpoch'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 40
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  private layoutWindow: window.Window | undefined = undefined
  private layoutWindowSizeCallback: ((size: window.Size) => void) | undefined = undefined
  private keyboardHeightCallback: ((height: number) => void) | undefined = undefined
  private startupReady: boolean = false
  private startupPromise: Promise<void> = Promise.resolve()
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    DiagnosticLogger.configure(false)
    DiagnosticLogger.initializePersistentSink(this.context)
    captureReaderLabWant(want, this.context.applicationInfo.debug)
    captureKomaDeviceVerificationIsolation(want, this.context.applicationInfo.debug)
    void launchParam
    AppStrings.init(this.context)
    this.startupPromise = this.prepareStartup(want).catch((_error: Error): void => {
      BackupRestoreActivity.blockUntilRestart()
      DiagnosticLogger.error('app', 'startup_failed', '[BackupRecovery] step=startup_failed code=backup_recovery_pending')
    })
  }

  private async prepareStartup(want: Want): Promise<void> {
    // Recover before theme Preferences, installed packages, Library or Reader
    // consumers are initialized. A failed recovery never loads ordinary Index.
    await DiagnosticsSettings.restore(this.context)
    try {
      const bundle = bundleManager.getBundleInfoForSelfSync(0)
      DiagnosticLogger.info('app', 'startup', 'version=' + bundle.versionName + ' versionCode=' + bundle.versionCode +
        ' debug=' + this.context.applicationInfo.debug + ' model=' + deviceInfo.productModel + ' sdk=' + deviceInfo.sdkApiVersion)
      DiagnosticLogger.info('app', 'platform', 'os=' + deviceInfo.osFullName)
    } catch (error) { DiagnosticLogger.exception('app', 'metadata_failed', error as Error) }
    await BackupRestoreCheckpoint.recoverBeforeStartup(this.context)
    if (automationEpoch(this.context).restoring) {
      resetGeneratedAutomationWork(this.context)
      finishAutomationRestore(this.context)
    }
    await LanguageSettings.restore(this.context).catch((_error: Error): void => {
      DiagnosticLogger.warn('app', 'startup_apply_failed', '[Language] startup_apply_failed retained_previous_runtime=true')
    })
    await restoreReaderRemoteImageCache(this.context)
    await new ChapterListPreferencesStore(this.context).prepare().catch((error: Error): void => {
      DiagnosticLogger.exception('chapters', 'preferences_prepare_failed', error)
    })
    await new AppearancePreferencesStore(this.context).load().catch((_error: Error): void => {
      DiagnosticLogger.warn('app', 'startup_load_failed', '[Appearance] startup_load_failed retained_previous_runtime=true')
    })
    configureSourceSettingsStore(this.context)
    configureSourceRuntimeHttpTransport()
    bootstrapSourceRuntimeAppRegistry(this.context)
    this.openLaunchRouteFromWant(want)
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager, this.context)
    this.startupReady = true
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    captureReaderLabWant(want, this.context.applicationInfo.debug)
    captureKomaDeviceVerificationIsolation(want, this.context.applicationInfo.debug)
    void launchParam
    void this.startupPromise.then((): void => {
      if (!this.startupReady) return
      this.openLaunchRouteFromWant(want)
      maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager, this.context)
    })
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync()
      win.setWindowLayoutFullScreen(true)
      win.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_COLOR,
        navigationBarColor: TRANSPARENT_COLOR,
      })
      // Match NextE: opt the main window into sensor-driven rotation. The
      // system rotation-lock toggle still pins portrait when enabled.
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_UNSPECIFIED)
        .catch((error: Error) => {
          DiagnosticLogger.error('app', 'set_orientation_failed', '[EntryAbility] step=set_orientation_failed code=orientation_request_failed msg=' + error.message)
        })
    } catch (error) {
      void error
      DiagnosticLogger.error('app', 'configure_window_failed', '[EntryAbility] step=configure_window_failed code=window_configure_failed')
    }

    void this.startupPromise.then((): void => {
      if (!this.startupReady) return
      windowStage.loadContent(ENTRY_PAGE, (err) => {
        if (err.code) {
          DiagnosticLogger.error('app', 'load_content_failed', '[EntryAbility] step=load_content_failed code=load_content_failed')
          return
        }
        bindReaderThemeWindow(this.context)
        this.applySavedThemeMode()
        this.configureAvoidAreas(windowStage)
        this.bindLayoutWindow(windowStage.getMainWindowSync())
        if (!shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) {
          setTimeout(() => {
            this.syncRemoteProgressInBackground()
          }, 250)
        }
      })
    })
  }

  onConfigurationUpdate(config: Configuration): void {
    this.publishLayoutWindowWidth()
  }

  onDestroy(): void {
    DiagnosticLogger.info('app', 'destroy', '')
    DiagnosticLogger.closePersistentSink()
    this.unbindLayoutWindow()
    unbindReaderThemeWindow()
  }

  onWindowStageDestroy(): void {
    this.unbindLayoutWindow()
    unbindReaderThemeWindow()
  }

  onForeground(): void {
    DiagnosticLogger.info('app', 'foreground', '')
    updateReaderLabForeground(true, this.context.applicationInfo.debug)
    AppForegroundStateBridge.onForeground()
    if (!shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) {
      setTimeout(() => {
        this.syncRemoteProgressInBackground()
      }, 250)
    }
  }

  onBackground(): void {
    DiagnosticLogger.info('app', 'background', '')
    updateReaderLabForeground(false, this.context.applicationInfo.debug)
    AppForegroundStateBridge.onBackground()
    if (!shouldSuppressKomaDeviceVerificationBackgroundSideEffects()) {
      void this.startupPromise.then(() => synchronizeBackgroundMaintenance(this.context, true))
        .catch((error: Error): void => { DiagnosticLogger.exception('maintenance', 'snapshot_failed', error) })
    }
  }

  private bindLayoutWindow(win: window.Window): void {
    this.unbindLayoutWindow()
    this.layoutWindow = win
    this.publishLayoutWindowWidth()
    this.layoutWindowSizeCallback = (size: window.Size): void => {
      try {
        LayoutSafeAreaBridge.publishWindowWidth(win.getUIContext().px2vp(size.width))
      } catch (_error) {
        // Keep the last valid width if this window is being torn down.
      }
    }
    try {
      win.on('windowSizeChange', this.layoutWindowSizeCallback)
    } catch (_error) {
      DiagnosticLogger.warn('app', 'window_listener_unavailable', '[LibraryLayout] step=window_listener_unavailable')
    }
  }

  private publishLayoutWindowWidth(): void {
    const win = this.layoutWindow
    if (win === undefined) return
    try {
      LayoutSafeAreaBridge.publishWindowWidth(win.getUIContext().px2vp(win.getWindowProperties().windowRect.width))
    } catch (_error) {
      // Keep the last valid width; Library retains its initial measured fallback.
    }
  }

  private unbindLayoutWindow(): void {
    if (this.layoutWindow !== undefined && this.layoutWindowSizeCallback !== undefined) {
      try {
        this.layoutWindow.off('windowSizeChange', this.layoutWindowSizeCallback)
      } catch (_error) {
        // This main window may already have been destroyed.
      }
    }
    this.layoutWindowSizeCallback = undefined
    this.layoutWindow = undefined
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
      DiagnosticLogger.error('app', 'configure_avoid_areas_failed', '[EntryAbility] step=configure_avoid_areas_failed code=avoid_area_failed')
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
      DiagnosticLogger.error('app', 'publish_avoid_heights_failed', '[EntryAbility] step=publish_avoid_heights_failed code=avoid_area_failed')
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
    void this.startupPromise.then((): void => {
      if (this.startupReady) void new RemoteProgressBootstrapSync(this.context).syncAllPrivateLibraryProgress()
    })
  }

  private applySavedThemeMode(): void {
    void new ReaderPreferencesStore(this.context).load()
      .then((preferences) => {
        DiagnosticLogger.info('app', 'apply_startup_theme', '[Settings] step=apply_startup_theme value=' + preferences.themeMode)
      })
      .catch((error: Error) => {
        void error
        DiagnosticLogger.warn('app', 'apply_startup_theme_failed', '[Settings] step=apply_startup_theme_failed code=theme_apply_failed')
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
    } else if (route === KOMA_LAUNCH_ROUTE_READER) {
      RouterHelper.pushReader()
    }
  }
}
