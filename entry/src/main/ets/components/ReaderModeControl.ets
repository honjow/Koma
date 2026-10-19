import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode, getReaderModeLabel } from '../model/ReaderSessionStore'

/** Koma's native four page-mode choices, reused by both reader backends. */
@ComponentV2
export struct ReaderModeControl {
  @Param readerMode: ReaderMode = ReaderMode.SINGLE_PAGE
  @Param controlEnabled: boolean = true
  @Event onModeChange: (mode: ReaderMode) => void = (_mode: ReaderMode): void => {}
  @Event onMenuVisible: (visible: boolean) => void = (_visible: boolean): void => {}
  @Local private modeShown: boolean = false

  @Builder
  private ModeMenu() {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.SINGLE_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.DUAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.VERTICAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.VERTICAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.VERTICAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.CONTINUOUS_SCROLL); this.modeShown = false })
    }
  }

  build() {
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph(this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? $r('sys.symbol.scroll_vertical') : $r('sys.symbol.arrow_right_and_square')).fontSize(22).fontColor([Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.controlEnabled).onClick(() => { this.modeShown = true }).bindMenu(this.modeShown, this.ModeMenu, { placement: Placement.TopRight, aboutToAppear: (): void => { this.onMenuVisible(true) }, onDisappear: () => { this.modeShown = false; this.onMenuVisible(false) } })
  }
}
