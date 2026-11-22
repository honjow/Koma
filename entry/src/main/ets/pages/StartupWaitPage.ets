import { LoadingDialogV2 } from '@kit.ArkUI'

@Entry({ useSharedStorage: true })
@Component
struct StartupWaitPage {
  @LocalStorageProp('startupFailed') @Watch('onStartupFailed') startupFailed: boolean = false
  private active: boolean = false
  private dialogId: number = -1

  onPageShow(): void {
    if (this.active) return
    this.active = true
    if (this.startupFailed) return
    const prompt = this.getUIContext().getPromptAction()
    void prompt.openCustomDialog({
      builder: () => { this.Loading() },
      alignment: DialogAlignment.Center,
      autoCancel: false,
      onWillDismiss: (): void => {},
    }).then((id: number): void => {
      if (this.active && !this.startupFailed) this.dialogId = id
      else prompt.closeCustomDialog(id)
    }).catch((): void => {})
  }

  onPageHide(): void {
    this.active = false
    this.closeLoading()
  }

  aboutToDisappear(): void {
    this.onPageHide()
  }

  private onStartupFailed(): void {
    if (this.startupFailed) this.closeLoading()
  }

  private closeLoading(): void {
    if (this.dialogId < 0) return
    const id = this.dialogId
    this.dialogId = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }

  @Builder
  private Loading() {
    LoadingDialogV2({ content: $r('app.string.startup_preparing_local_data') })
  }

  build() {
    Stack() {
      if (this.startupFailed) {
        Text($r('app.string.startup_local_data_failed'))
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
          .padding(24)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }
}
