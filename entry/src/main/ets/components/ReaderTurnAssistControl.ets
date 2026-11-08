import { SymbolGlyphModifier } from '@kit.ArkUI'
import { komaMenuOptions, komaReaderMenuTextColor } from '../theme/KomaPopupOptions'
import { ThemeConstants } from '../theme/ThemeConstants'

const GAZE_SYMBOL: Resource = $r('sys.symbol.eye_viewfinder')

export type ReaderTurnAssist = 'off' | 'auto' | 'gaze'

/** The existing clock slot: opening is passive, and tapping the checked item returns to manual paging. */
@ComponentV2
export struct ReaderTurnAssistControl {
  @Param mode: ReaderTurnAssist = 'off'
  @Param gazeTracking: boolean = false
  @Param controlEnabled: boolean = true
  @Param autoAvailable: boolean = true
  @Param gazeAvailable: boolean = true
  @Event onSelect: (mode: ReaderTurnAssist) => void = () => {}
  @Event onMenuVisible: (visible: boolean) => void = () => {}
  @Local private menuShown: boolean = false
  @Local private menuColor: ResourceColor = $r('sys.color.font_primary')

  private choose(mode: 'auto' | 'gaze'): void {
    this.onSelect(this.mode === mode ? 'off' : mode)
    this.menuShown = false
  }

  @Builder
  private TurnAssistMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.reader_turn_assist_auto'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        symbolEndIcon: this.mode === 'auto' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .enabled(this.autoAvailable || this.mode === 'auto').onClick((): void => { this.choose('auto') })
      MenuItem({ content: $r('app.string.settings_row_reader_eye_gaze_page_turn_title'),
        symbolStartIcon: new SymbolGlyphModifier(GAZE_SYMBOL),
        symbolEndIcon: this.mode === 'gaze' ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .enabled(this.gazeAvailable || this.mode === 'gaze').onClick((): void => { this.choose('gaze') })
    }.fontColor(this.menuColor)
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.gazeTracking ? GAZE_SYMBOL : $r('sys.symbol.clock')).fontSize(22)
        .fontColor([this.mode === 'auto' || this.gazeTracking ? ThemeConstants.BRAND_PRIMARY : Color.White])
    }
    .width(44).height(44).backgroundColor(Color.Transparent)
    .id('koma-reader-turn-assist')
    .enabled(this.controlEnabled)
    .accessibilityText(this.mode === 'gaze' ? $r('app.string.settings_row_reader_eye_gaze_page_turn_title') :
      this.mode === 'auto' ? $r('app.string.reader_turn_assist_auto') : $r('app.string.reader_turn_assist'))
    .onClick((): void => {
      this.menuColor = komaReaderMenuTextColor()
      this.menuShown = true
    })
    .bindMenu(this.menuShown, this.TurnAssistMenu, komaMenuOptions({
      placement: Placement.TopRight,
      aboutToAppear: (): void => { this.onMenuVisible(true) },
      onDisappear: (): void => { this.menuShown = false; this.onMenuVisible(false) },
    }))
  }
}
