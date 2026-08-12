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
        .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
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
    // Empty and error states belong to the page flow. A framed white card here
    // competes with the actual result list and makes an idle search look like
    // a modal surface. Keep the HDS hierarchy in text and a single optional
    // action instead.
    .padding({ top: ThemeConstants.SPACE_XXL, bottom: ThemeConstants.SPACE_XXL, left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
    .backgroundColor(Color.Transparent)
    .alignItems(HorizontalAlign.Center)
  }
}
