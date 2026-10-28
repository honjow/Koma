import { komaMenuOptions } from '../theme/KomaPopupOptions'
import { ReaderDirectionChoice } from '../model/ReaderControlChoices'
import { ReaderDirectionMenuItems, readerDirectionIcon } from './ReaderDirectionMenu'
export { ReaderDirectionChoice } from '../model/ReaderControlChoices'

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
    return readerDirectionIcon(direction)
  }

  private choose(direction: ReaderDirectionChoice): void {
    this.onDirectionChange(direction)
    this.menuShown = false
  }

  @Builder
  private DirectionMenu() {
    Menu() {
      ReaderDirectionMenuItems(this.readingMode, (direction: ReaderDirectionChoice): void => { this.choose(direction) })
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
