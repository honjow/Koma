import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { ReaderDirectionChoice, readerControlDirectionLabelKey } from '../model/ReaderControlChoices'

export function readerDirectionIcon(direction: ReaderDirectionChoice): Resource {
  if (direction === 'rtl') return $r('sys.symbol.arrow_left_and_square')
  if (direction === 'vertical_page') return $r('sys.symbol.square_and_arrow_down_1')
  if (direction === 'continuous') return $r('sys.symbol.scroll_vertical')
  return $r('sys.symbol.arrow_right_and_square')
}

/** One menu definition for the control bar, in-reader settings and global reading settings. */
@Builder
export function ReaderDirectionMenuItems(selected: ReaderDirectionChoice,
  choose: (direction: ReaderDirectionChoice) => void) {
  ForEach(['ltr', 'rtl', 'vertical_page', 'continuous'] as ReaderDirectionChoice[], (direction: ReaderDirectionChoice) => {
    MenuItem({ content: AppStrings.get(readerControlDirectionLabelKey(direction)),
      symbolStartIcon: new SymbolGlyphModifier(readerDirectionIcon(direction)),
      symbolEndIcon: selected === direction ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
      .onClick((): void => { choose(direction) })
  }, (direction: ReaderDirectionChoice): string => direction)
}
