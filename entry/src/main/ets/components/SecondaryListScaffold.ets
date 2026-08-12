import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct SecondaryListScaffold {
  @BuilderParam content: () => void
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private languageState: LanguageState = connectLanguageState()
  scroller: Scroller = new Scroller()
  @Param listSpace: number = ThemeConstants.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeConstants.SPACE_MD
  @Param bottomPadding: number = ThemeConstants.SPACE_XL
  // Only root HDS tabs float over content. Root tab pages pass their own
  // clearance explicitly; destinations keep ordinary safe-area spacing.
  @Param floatingTabTailPadding: number = 0
  @Param includeKeyboardPadding: boolean = true
  @Param reserveTitleBar: boolean = true
  @Event onReachEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  build() {
    Stack() {
      if (this.languageState.effectiveLocale.length >= 0) {
        List({ space: this.listSpace, scroller: this.scroller }) {
          ListItem() {
            Column() {
              Blank().height(this.safeArea.topAvoidHeight + this.titleBarPadding())
            }
            .width('100%')
          }
          .clip(false)

          this.content()

          ListItem() {
            Column() {
              Blank().height(this.safeArea.bottomAvoidHeight + this.bottomPadding + this.floatingTabTailPadding + this.keyboardPadding())
            }
            .width('100%')
          }
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .padding({
          left: this.horizontalPadding,
          right: this.horizontalPadding,
        })
        .clipContent(ContentClipMode.CONTENT_ONLY)
        .edgeEffect(EdgeEffect.None)
        .onDidScroll((_scrollOffset: number, scrollState: ScrollState) => {
          if (this.onDidScroll) {
            this.onDidScroll(this.scroller.currentOffset().yOffset, scrollState)
          }
        })
        .onScrollIndex((_start: number, _end: number, _center: number) => {
          if (this.onDidScroll) {
            this.onDidScroll(this.scroller.currentOffset().yOffset, ScrollState.Scroll)
          }
        })
        .onReachEnd(() => {
          if (this.onReachEnd) {
            this.onReachEnd()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_PRIMARY)
  }

  private keyboardPadding(): number {
    if (!this.includeKeyboardPadding) {
      return 0
    }
    return Math.max(0, this.safeArea.keyboardHeight)
  }

  private titleBarPadding(): number {
    return this.reserveTitleBar ? ThemeConstants.TITLE_BAR_HEIGHT : 0
  }
}
