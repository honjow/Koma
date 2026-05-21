import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { maybeRunSourceRuntimeDeviceSmoke } from '../sourceRuntime/SourceRuntimeDeviceSmoke'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager)
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void launchParam
    maybeRunSourceRuntimeDeviceSmoke(want, this.context.resourceManager)
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
    })
  }
}
