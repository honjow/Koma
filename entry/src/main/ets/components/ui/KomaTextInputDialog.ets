import { CustomContentDialogV2 } from '@kit.ArkUI'
import { AppStrings } from '../../i18n/AppStrings'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { KomaFormTextField } from './KomaFormTextField'

// The system dialog owns the surface and title. Its AdvancedDialogV2Button
// always closes after the callback, so asynchronous forms use native Buttons
// here and let the caller close only on success or cancellation.
@ComponentV2
export struct KomaTextInputDialog {
  @Param title: string = ''
  @Param label: string = ''
  @Param placeholder: string = ''
  @Param value: string = ''
  @Param secondaryLabel: string = ''
  @Param secondaryPlaceholder: string = ''
  @Param secondaryValue: string = ''
  @Param error: string = ''
  @Param busy: boolean = false
  @Param confirmEnabled: boolean = true
  @Param confirmLabel: string = ''
  @Event change: (value: string) => void = () => {}
  @Event secondaryChange: (value: string) => void = () => {}
  @Event confirm: () => void = () => {}
  @Event cancel: () => void = () => {}

  @Builder
  private Field() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      KomaFormTextField({ label: this.label, placeholder: this.placeholder, value: this.value,
        isEnabled: !this.busy, change: this.change,
        submit: (): void => { if (this.confirmEnabled && !this.busy) this.confirm() } })
      if (this.secondaryLabel.length > 0) {
        KomaFormTextField({ label: this.secondaryLabel, placeholder: this.secondaryPlaceholder,
          value: this.secondaryValue, isEnabled: !this.busy, change: this.secondaryChange,
          submit: (): void => { if (this.confirmEnabled && !this.busy) this.confirm() } })
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.error).layoutWeight(1).fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
        LoadingProgress().width(24).height(24).color(ThemeConstants.BRAND_PRIMARY)
          .visibility(this.busy ? Visibility.Visible : Visibility.Hidden)
      }.width('100%').constraintSize({ minHeight: 24 })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button(AppStrings.get('common_cancel')).buttonStyle(ButtonStyleMode.TEXTUAL)
          .layoutWeight(1).enabled(!this.busy).onClick(() => { this.cancel() })
        Divider().vertical(true).height(24)
        Button(this.confirmLabel).buttonStyle(ButtonStyleMode.TEXTUAL)
          .layoutWeight(1).enabled(this.confirmEnabled && !this.busy)
          .onClick(() => { this.confirm() })
      }.width('100%').padding({ top: ThemeConstants.SPACE_SM })
    }.width('100%')
  }

  build() {
    CustomContentDialogV2({ primaryTitle: this.title, contentBuilder: (): void => { this.Field() } })
  }
}
