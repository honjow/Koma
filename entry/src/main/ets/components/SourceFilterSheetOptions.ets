import { KomaSheetOptions } from '../theme/KomaPopupOptions'

export function sourceFilterSheetOptions(onDisappear: () => void): KomaSheetOptions {
  return {
    detents: [SheetSize.MEDIUM, SheetSize.LARGE],
    showClose: false,
    enableOutsideInteractive: false,
    scrollSizeMode: ScrollSizeMode.CONTINUOUS,
    enableFloatingDragBar: true,
    keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
    onDisappear: onDisappear,
  }
}
