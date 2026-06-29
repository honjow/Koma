import { TabIndex } from '../common/Constants'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct KomaTabIcon {
  @Prop title: string = ''
  @Prop idx: number = 0
  @Prop currentIndex: number = 0

  private iconForIndex(index: number): Resource {
    if (index === TabIndex.LIBRARY) {
      return $r('sys.symbol.square_fill_grid_2x2')
    } else if (index === TabIndex.BROWSE) {
      return $r('sys.symbol.compass')
    } else if (index === TabIndex.HISTORY) {
      return $r('sys.symbol.clock')
    } else if (index === TabIndex.SEARCH) {
      return $r('sys.symbol.magnifyingglass')
    } else {
      return $r('sys.symbol.gearshape')
    }
  }

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SymbolGlyph(this.iconForIndex(this.idx))
        .fontSize(ThemeConstants.FONT_SIZE_H2)
        .fontColor([
          this.currentIndex === this.idx
            ? $r('sys.color.ohos_id_color_activated')
            : $r('sys.color.font_secondary'),
        ])
      Text(this.title)
        .fontSize(ThemeConstants.FONT_SIZE_TINY)
        .fontColor(
          this.currentIndex === this.idx
            ? $r('sys.color.ohos_id_color_activated')
            : $r('sys.color.font_secondary'),
        )
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XS })
  }
}
