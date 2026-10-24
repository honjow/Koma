import { komaMenuOptions } from '../theme/KomaPopupOptions'
import { SymbolGlyphModifier } from '@kit.ArkUI'

export type ReaderDirectionChoice = 'ltr' | 'rtl' | 'vertical_page' | 'continuous'

/** NextE's direction-only native control; spread selection has its own button. */
@ComponentV2
export struct ReaderDirectionControl {
  @Param readingMode: ReaderDirectionChoice = 'ltr'
  @Param controlEnabled: boolean = true
  @Event onDirectionChange: (direction: ReaderDirectionChoice) => void = () => {}
  @Event onMenuVisible: (visible: boolean) => void = () => {}
  @Local private menuShown: boolean = false

  private label(direction: ReaderDirectionChoice): Resource {
    if (direction === 'rtl') return $r('app.string.reader_direction_rtl')
    if (direction === 'vertical_page') return $r('app.string.reader_page_mode_vertical_page')
    if (direction === 'continuous') return $r('app.string.reader_page_mode_continuous')
    return $r('app.string.reader_direction_ltr')
  }

  private icon(direction: ReaderDirectionChoice): Resource {
    if (direction === 'rtl') return $r('sys.symbol.arrow_left_and_square')
    if (direction === 'vertical_page') return $r('sys.symbol.square_and_arrow_down_1')
    if (direction === 'continuous') return $r('sys.symbol.scroll_vertical')
    return $r('sys.symbol.arrow_right_and_square')
  }

  private choose(direction: ReaderDirectionChoice): void {
    this.onDirectionChange(direction)
    this.menuShown = false
  }

  @Builder
  private DirectionMenu() {
    Menu() {
      ForEach(['ltr', 'rtl', 'vertical_page', 'continuous'] as ReaderDirectionChoice[],
        (direction: ReaderDirectionChoice) => {
          MenuItem({ content: this.label(direction),
            symbolStartIcon: new SymbolGlyphModifier(this.icon(direction)),
            symbolEndIcon: this.readingMode === direction
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
            .onClick((): void => { this.choose(direction) })
        }, (direction: ReaderDirectionChoice): string => direction)
    }
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.icon(this.readingMode)).fontSize(22).fontColor([Color.White])
    }
    .width(44).height(44).backgroundColor(Color.Transparent)
    .enabled(this.controlEnabled).accessibilityText(this.label(this.readingMode))
    .onClick((): void => { this.menuShown = true })
    .bindMenu(this.menuShown, this.DirectionMenu, komaMenuOptions({
      placement: Placement.TopRight,
      aboutToAppear: (): void => { this.onMenuVisible(true) },
      onDisappear: (): void => { this.menuShown = false; this.onMenuVisible(false) },
    }))
  }
}
