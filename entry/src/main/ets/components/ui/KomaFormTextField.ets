import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct KomaFormTextField {
  @Param label: ResourceStr = ''
  // Source settings opt in; other forms retain their existing single-line label.
  @Param wrapLabel: boolean = false
  @Param placeholder: ResourceStr = ''
  @Param value: string = ''
  @Param isPassword: boolean = false
  @Param isEnabled: boolean = true
  // Only forms with field validation opt in to the native error state.
  @Param validationError: string | undefined = undefined
  @Event change: (value: string) => void = (_value: string) => {}
  @Event submit?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(this.label)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Regular)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(this.wrapLabel ? 2147483647 : 1)
        .textOverflow({ overflow: this.wrapLabel ? TextOverflow.Clip : TextOverflow.Ellipsis })
        .width('100%')

      TextInput({ placeholder: this.placeholder, text: this.value })
        .type(this.isPassword ? InputType.Password : InputType.Normal)
        .showPassword(false)
        .height(ThemeConstants.BUTTON_HEIGHT)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
        .enabled(this.isEnabled)
        .showError(this.validationError)
        .onChange((next: string) => {
          this.change(next)
        })
        .onSubmit(() => {
          if (this.submit) {
            this.submit()
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
