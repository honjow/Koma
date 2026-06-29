import { TabIndex } from '../common/Constants'
import { ThemeConstants } from '../theme/ThemeConstants'

const TAB_SYMBOL_SIZE: number = 28
const TAB_SYMBOL_LAYOUT_OFFSET_VP: number = 3

@ComponentV2
export struct KomaTabIcon {
  @Param title: string = ''
  @Param idx: number = 0
  @Param currentIndex: number = 0
  @Event onSelectedClick?: (index: number) => void

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
    Column() {
      Row() {
        Blank().width(TAB_SYMBOL_LAYOUT_OFFSET_VP)
        SymbolGlyph(this.iconForIndex(this.idx))
          .fontSize(TAB_SYMBOL_SIZE - 6)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .fontColor([
            this.currentIndex === this.idx
              ? ThemeConstants.BRAND_PRIMARY
              : $r('sys.color.font_secondary'),
          ])
      }
      .width(TAB_SYMBOL_SIZE)
      .height(TAB_SYMBOL_SIZE - 2)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Text(this.title)
        .fontSize(ThemeConstants.FONT_SIZE_TINY)
        .fontColor(
          this.currentIndex === this.idx
            ? ThemeConstants.BRAND_PRIMARY
            : $r('sys.color.font_secondary'),
        )
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: ThemeConstants.SPACE_SM - 2, bottom: ThemeConstants.SPACE_XS })
    .onClick(() => {
      if (this.currentIndex === this.idx && this.onSelectedClick) {
        this.onSelectedClick(this.idx)
      }
    })
  }
}
