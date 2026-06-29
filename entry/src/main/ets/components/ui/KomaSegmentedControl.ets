import { LengthMetrics, SegmentButtonV2ItemOptions, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI'
import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct KomaSegmentedControl {
  @Param labels: string[] = []
  @Param selectedIndex: number = 0
  @Param controlHeight: number = ThemeConstants.BUTTON_HEIGHT
  @Event select: (index: number) => void = (_index: number) => {}

  private items(): SegmentButtonV2Items {
    const itemOptions: SegmentButtonV2ItemOptions[] = []
    this.labels.forEach((label: string) => {
      const item: SegmentButtonV2ItemOptions = { text: label }
      itemOptions.push(item)
    })
    return new SegmentButtonV2Items(itemOptions)
  }

  build() {
    TabSegmentButtonV2({
      items: this.items(),
      selectedIndex: this.selectedIndex,
      enableStateAnimation: true,
      itemFontSize: LengthMetrics.vp(ThemeConstants.FONT_SIZE_BODY),
      itemSelectedFontSize: LengthMetrics.vp(ThemeConstants.FONT_SIZE_BODY),
      itemFontWeight: FontWeight.Medium,
      itemSelectedFontWeight: FontWeight.Bold,
      itemPadding: {
        top: LengthMetrics.vp(ThemeConstants.SPACE_XS),
        bottom: LengthMetrics.vp(ThemeConstants.SPACE_XS),
        start: LengthMetrics.vp(ThemeConstants.SPACE_MD),
        end: LengthMetrics.vp(ThemeConstants.SPACE_MD),
      },
      onItemClicked: (index: number) => {
        this.select(index)
      },
    })
      .width('100%')
      .constraintSize({ minHeight: this.controlHeight })
      .padding({
        left: ThemeConstants.SPACE_XS,
        right: ThemeConstants.SPACE_XS,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
  }
}
