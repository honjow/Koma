import { ThemeConstants } from '../theme/ThemeConstants'
import { GroupedListSection } from './ui/GroupedListSection'
import { KomaActionButton } from './ui/KomaActionButton'

@ComponentV2
export struct SourceFiltersSheetScaffold {
  @Param title: ResourceStr = ''
  @Param resetLabel: ResourceStr = ''
  @Param closeAccessibilityText: string = ''
  @Param showReset: boolean = false
  @Param resetEnabled: boolean = true
  @Event onClose: () => void = () => {}
  @Event onReset: () => void = () => {}
  @BuilderParam content: () => void

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([ThemeConstants.TEXT_PRIMARY])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.closeAccessibilityText)
        .onClick(() => {
          this.onClose()
        })
      }
      .width('100%')
      .height(ThemeConstants.TITLE_BAR_HEIGHT)
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_SM })

      Divider()
        .strokeWidth(0.5)
        .color(ThemeConstants.DIVIDER)

      Scroll() {
        Column({ space: ThemeConstants.SPACE_LG }) {
          GroupedListSection() {
            this.content()
          }
          if (this.showReset) {
            KomaActionButton({
              label: this.resetLabel,
              kind: 'ghost',
              compact: true,
              isEnabled: this.resetEnabled,
              action: () => {
                this.onReset()
              },
            })
          }
          Blank().height(ThemeConstants.SPACE_XL)
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
