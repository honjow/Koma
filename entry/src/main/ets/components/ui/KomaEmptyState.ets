import { ThemeConstants } from '../../theme/ThemeConstants'
import { KomaActionButton } from './KomaActionButton'

@ComponentV2
export struct KomaEmptyState {
  @Param title: string = ''
  @Param message: string = ''
  @Param actionLabel: string = ''
  @Param showAction: boolean = false
  @Event action: () => void = () => {}

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(this.title)
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
      if (this.showAction) {
        KomaActionButton({
          label: this.actionLabel,
          kind: 'primary',
          action: () => {
            this.action()
          },
        })
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_XL)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .alignItems(HorizontalAlign.Center)
  }
}
