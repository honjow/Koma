import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct KomaEmptyState {
  @Param icon: Resource | undefined = undefined
  @Param title: string = ''
  @Param message: string = ''
  @Param actionLabel: string = ''
  @Param showAction: boolean = false
  @Event action: () => void = () => {}

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      if (this.icon !== undefined) {
        SymbolGlyph(this.icon)
          .fontSize(56)
          .fontColor([$r('sys.color.font_tertiary')])
          .margin({ bottom: ThemeConstants.SPACE_XS })
      }
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
      }
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      }
      if (this.showAction) {
        Button(this.actionLabel)
          .type(ButtonType.Capsule)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .margin({ top: ThemeConstants.SPACE_MD })
          .onClick(() => {
            this.action()
          })
      }
    }
    .width('100%')
    // Empty and error states belong to the page flow. A framed white card here
    // competes with the actual result list and makes an idle search look like
    // a modal surface. Keep the HDS hierarchy in text and a single optional
    // action instead.
    .padding({ top: 80, bottom: ThemeConstants.SPACE_XXL, left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
    .backgroundColor(Color.Transparent)
    .alignItems(HorizontalAlign.Center)
  }
}
