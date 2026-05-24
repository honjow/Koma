import { TabIndex } from '../common/Constants'

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
    Column() {
      SymbolGlyph(this.iconForIndex(this.idx))
        .fontSize(22)
        .fontColor([
          this.currentIndex === this.idx
            ? $r('sys.color.ohos_id_color_activated')
            : $r('sys.color.font_secondary'),
        ])
      Text(this.title)
        .fontSize(10)
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
    .padding({ top: 6, bottom: 4 })
  }
}
