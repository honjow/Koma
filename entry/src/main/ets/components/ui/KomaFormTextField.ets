import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct KomaFormTextField {
  @Param label: ResourceStr = ''
  @Param placeholder: ResourceStr = ''
  @Param value: string = ''
  @Param isPassword: boolean = false
  @Param isEnabled: boolean = true
  @Event change: (value: string) => void = (_value: string) => {}
  @Event submit?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.label)
        .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      TextInput({ placeholder: this.placeholder, text: this.value })
        .type(this.isPassword ? InputType.Password : InputType.Normal)
        .showPassword(false)
        .height(ThemeConstants.BUTTON_HEIGHT)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .enabled(this.isEnabled)
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
