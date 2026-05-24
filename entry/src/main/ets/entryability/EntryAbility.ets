import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { registerBundledDevSourcesForBrowse } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { maybeRunSourceRuntimeDeviceSmoke } from '../sourceRuntime/SourceRuntimeDeviceSmoke'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID_HEIGHT: number = 0
const FALLBACK_BOTTOM_AVOID_HEIGHT: number = 0
const TITLE_BAR_HEIGHT: number = 56

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    registerBundledDevSourcesForBrowse(this.context.resourceManager)
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
    })
  }

  private storeAvoidHeights(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync()
      const uiContext = win.getUIContext()
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const navigationArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      AppStorage.setOrCreate<number>('topAvoidHeight', uiContext.px2vp(systemArea.topRect.height))
      AppStorage.setOrCreate<number>('bottomAvoidHeight', uiContext.px2vp(navigationArea.bottomRect.height))
      AppStorage.setOrCreate<number>('titleBarHeight', TITLE_BAR_HEIGHT)
    } catch (error) {
      const e = error as Error
      console.error('store avoid heights failed: ' + e.message)
      AppStorage.setOrCreate<number>('topAvoidHeight', FALLBACK_TOP_AVOID_HEIGHT)
      AppStorage.setOrCreate<number>('bottomAvoidHeight', FALLBACK_BOTTOM_AVOID_HEIGHT)
      AppStorage.setOrCreate<number>('titleBarHeight', TITLE_BAR_HEIGHT)
    }
  }
}
