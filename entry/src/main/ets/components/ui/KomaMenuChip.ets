import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct KomaMenuChip {
  @Param label: string = ''
  @Param active: boolean = false
  @Param maxWidth: number = 220

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.label)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .lineHeight(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.active ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(8)
        .fontColor([this.active ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.TEXT_TERTIARY])
    }
    .height(ThemeConstants.ACTION_CHIP_HEIGHT)
    .constraintSize({ maxWidth: this.maxWidth })
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor(this.active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
    .border({ width: this.active ? 0 : 1, color: this.active ? Color.Transparent : ThemeConstants.BRAND_PRIMARY })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
