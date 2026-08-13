import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { isUserScrollSource } from '../utils/ScrollUserInput'
import { PullRefresh, PullRefreshController } from './PullRefresh'

// Koma's root-tab extension of NextE's PullRefreshListScaffold contract.
// PullRefresh and List always share one Scroller. Koma keeps its explicit
// floating-tab, keyboard, and title reserves instead of changing the root HDS
// shell or SecondaryListScaffold.
@ComponentV2
export struct PullRefreshListScaffold {
  @BuilderParam content: () => void
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private pullScrollEnabled: boolean = true
  @Param scroller: Scroller = new Scroller()
  @Param controller: PullRefreshController = new PullRefreshController()
  @Param listSpace: number = ThemeConstants.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeConstants.SPACE_MD
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeConstants.SPACE_XL
  @Param stickyHeaders: boolean = false
  // Number of real content rows, excluding this scaffold's two reserve rows.
  @Param itemCount: number = 0
  @Param normalizeContentIndexes: boolean = false
  @Param floatingTabTailPadding: number = 0
  @Param includeKeyboardPadding: boolean = true
  @Param reserveTitleBar: boolean = true
  @Param indicatorTop: number = -1
  // Keep the caller's scroll gate separate from PullRefresh's short-lived
  // gesture gate. Browse has no external owner and therefore uses the default.
  @Param scrollEnabled: boolean = true
  @Param backToTop: boolean = true
  @Event onRefresh?: () => Promise<void>
  @Event onBottomRefresh?: () => Promise<void>
  @Event canStartBottomRefresh?: () => boolean
  @Event onReachEnd?: () => void
  @Event onScrollIndex?: (start: number, end: number, center: number) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  @Event onScrollEnableChange?: (enabled: boolean) => void
  @Event onContentWidth?: (contentWidth: number) => void
  @Event onListAreaChange?: (area: Area) => void

  build() {
    Stack() {
      PullRefresh({
      scroller: this.scroller,
      controller: this.controller,
      indicatorTop: this.resolvedIndicatorTop(),
      bottomIndicatorBottom: this.safeArea.bottomAvoidHeight + this.bottomPadding + this.floatingTabTailPadding + this.keyboardPadding(),
      onRefresh: async () => {
        if (this.onRefresh) {
          await this.onRefresh()
        }
      },
      onBottomRefresh: async () => {
        if (this.onBottomRefresh) {
          await this.onBottomRefresh()
        }
      },
      canStartBottomRefresh: () => {
        if (this.canStartBottomRefresh) {
          return this.canStartBottomRefresh()
        }
        return false
      },
      onScrollEnableChange: (enabled: boolean) => {
        this.pullScrollEnabled = enabled
        if (this.onScrollEnableChange) {
          this.onScrollEnableChange(enabled)
        }
      },
    }) {
      if (this.languageState.effectiveLocale.length >= 0) {
        List({ space: this.listSpace, scroller: this.scroller }) {
          ListItem() {
            Column() {
              Blank().height(this.safeArea.topAvoidHeight + this.titleBarPadding() + this.topPadding)
            }
            .width('100%')
          }
          .clip(false)

          this.content()

          ListItem() {
            Column() {
              Blank().height(
                this.safeArea.bottomAvoidHeight +
                  this.bottomPadding +
                  this.floatingTabTailPadding +
                  this.keyboardPadding(),
              )
            }
            .width('100%')
          }
          .onAppear(() => {
            this.maybeLoadOnTailAppear()
          })
        }
        .enableScrollInteraction(this.scrollEnabled && this.pullScrollEnabled)
        .maintainVisibleContentPosition(true)
        .backToTop(this.backToTop)
        .sticky(this.stickyHeaders ? StickyStyle.Header : StickyStyle.None)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .padding({
          left: this.horizontalPadding,
          right: this.horizontalPadding,
        })
        .clip(false)
        // PullRefresh owns the overscroll displacement, so native spring must
        // remain disabled to avoid a second, misaligned movement layer.
        .edgeEffect(EdgeEffect.None)
        .onWillScroll((_scrollOffset: number, _scrollState: ScrollState, source: ScrollSource) => {
          if (this.onUserScroll && isUserScrollSource(source)) {
            this.onUserScroll()
          }
        })
        .onDidScroll((_scrollOffset: number, scrollState: ScrollState) => {
          if (this.onDidScroll) {
            this.onDidScroll(this.scroller.currentOffset().yOffset, scrollState)
          }
        })
        .onScrollIndex((start: number, end: number, center: number) => {
          const adjustedStart = this.normalizeContentIndexes ? this.contentIndex(start) : start
          const adjustedEnd = this.normalizeContentIndexes ? this.contentIndex(end) : end
          const adjustedCenter = this.normalizeContentIndexes ? this.contentIndex(center) : center
          if (this.onScrollIndex) {
            this.onScrollIndex(adjustedStart, adjustedEnd, adjustedCenter)
          }
          if (this.onDidScroll) {
            this.onDidScroll(this.scroller.currentOffset().yOffset, ScrollState.Scroll)
          }
        })
        .onReachEnd(() => {
          if (this.onReachEnd) {
            this.onReachEnd()
          }
        })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          if (this.onListAreaChange) {
            this.onListAreaChange(newValue)
          }
          if (this.onContentWidth) {
            const contentWidth = (newValue.width as number) - 2 * this.horizontalPadding
            this.onContentWidth(contentWidth > 0 ? contentWidth : 0)
          }
        })
      }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
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

  private resolvedIndicatorTop(): number {
    if (this.indicatorTop >= 0) {
      return this.indicatorTop
    }
    return this.safeArea.topAvoidHeight +
      (this.reserveTitleBar ? ThemeConstants.TITLE_BAR_HEIGHT / 2 : 0) +
      this.topPadding
  }

  private contentIndex(rawIndex: number): number {
    const index = rawIndex - 1
    if (index < 0) {
      return 0
    }
    if (this.itemCount > 0 && index >= this.itemCount) {
      return this.itemCount - 1
    }
    return index
  }

  private maybeLoadOnTailAppear(): void {
    if (this.canStartBottomRefresh && !this.canStartBottomRefresh()) {
      return
    }
    if (this.onReachEnd) {
      this.onReachEnd()
    }
  }
}
