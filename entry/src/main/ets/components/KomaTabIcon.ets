import { TabIndex } from '../common/Constants'
import { ThemeConstants } from '../theme/ThemeConstants'

const TAB_SYMBOL_SIZE: number = 28
const TAB_SYMBOL_LAYOUT_OFFSET_VP: number = 3

@ComponentV2
export struct KomaTabIcon {
  @Param title: string = ''
  @Param idx: number = 0
  @Param currentIndex: number = 0
  @Param bounceTrigger: number = -1

  private iconForIndex(index: number): Resource {
    if (index === TabIndex.LIBRARY) {
      return this.currentIndex === index ? $r('sys.symbol.square_fill_grid_2x2') : $r('sys.symbol.square_grid_2x2')
    } else if (index === TabIndex.BROWSE) {
      return this.currentIndex === index ? $r('sys.symbol.compass_circle_fill') : $r('sys.symbol.compass_circle')
    } else if (index === TabIndex.HISTORY) {
      return this.currentIndex === index ? $r('sys.symbol.clock_fill') : $r('sys.symbol.clock')
    } else {
      return this.currentIndex === index ? $r('sys.symbol.gearshape_fill') : $r('sys.symbol.gearshape')
    }
  }

  @Builder
  private TabSymbol(trigger: number) {
    SymbolGlyph(this.iconForIndex(this.idx))
      .fontSize(TAB_SYMBOL_SIZE - 6)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), trigger)
      .fontColor([
        this.currentIndex === this.idx
          ? ThemeConstants.BRAND_PRIMARY
          : $r('sys.color.font_secondary'),
      ])
  }

  build() {
    Column() {
      Row() {
        Blank().width(TAB_SYMBOL_LAYOUT_OFFSET_VP)
        if (this.currentIndex === this.idx) {
          this.TabSymbol(this.bounceTrigger)
        } else {
          this.TabSymbol(-1)
        }
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
  }
}
