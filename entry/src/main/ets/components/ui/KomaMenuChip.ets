import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct KomaMenuChip {
  @Param label: string = ''
  @Param active: boolean = false
  @Param maxWidth: number = 220

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.label)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .lineHeight(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.active ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(9)
        .fontColor([this.active ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_TERTIARY])
    }
    .height(ThemeConstants.ACTION_CHIP_HEIGHT)
    .constraintSize({ maxWidth: this.maxWidth })
    .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
    .borderRadius(ThemeConstants.RADIUS_SM)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
