import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct SectionHeader {
  @Param title: ResourceStr = ''

  build() {
    Text(this.title)
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
      .width('100%')
  }
}

@ComponentV2
export struct GroupedListSection {
  @BuilderParam content: () => void
  @Param inset: number = ThemeConstants.LIST_SECTION_INSET
  @Param radius: number = ThemeConstants.RADIUS_CARD

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(this.radius)
    .clip(true)
    .padding(this.inset)
    .backgroundColor(ThemeConstants.CARD)
  }
}

@ComponentV2
export struct ListDivider {
  build() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeConstants.DIVIDER)
      .margin({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }
}
