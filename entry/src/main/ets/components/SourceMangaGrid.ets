import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { PullRefresh } from './PullRefresh'

export const SOURCE_MANGA_GRID_GAP: number = ThemeConstants.SPACE_MD

class SourceGridClipModifier implements AttributeModifier<GridAttribute> {
  private unclipped: boolean
  constructor(unclipped: boolean) { this.unclipped = unclipped }
  applyNormalAttribute(grid: GridAttribute): void {
    if (this.unclipped) grid.clip(false)
    else grid.clipContent(ContentClipMode.CONTENT_ONLY)
  }
}

// A source page has one scrolling Grid and one parent for all keyed cover items.
// Headers, empty/error states and pagination remain full-width items in that Grid.
@ComponentV2
export struct SourceMangaGrid {
  @BuilderParam content: () => void
  @Param scroller: Scroller = new Scroller()
  @Param contentItemCount: number = 0
  @Param fullRowIndexes: number[] = []
  @Param pinnedOverlayHeight: number = 0
  @Param withPullRefresh: boolean = false
  @Param resumeAtVisibleTail: boolean = false
  @Local private lastVisibleIndex: number = -1
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private pullScrollEnabled: boolean = true
  @Event onRefresh?: () => Promise<void>
  @Event onReachEnd?: () => void

  @Monitor('resumeAtVisibleTail')
  private resumePendingTail(): void {
    // An empty source page leaves the same tail item visible, so no new scroll
    // or appearance event occurs. Re-evaluate demand when loading completes.
    if (this.resumeAtVisibleTail && this.withPullRefresh &&
      this.lastVisibleIndex >= this.contentItemCount + 1 && this.onReachEnd) {
      this.onReachEnd()
    }
  }

  private layoutOptions(): GridLayoutOptions {
    const indexes: number[] = [0]
    this.fullRowIndexes.forEach((index: number) => indexes.push(index + 1))
    indexes.push(this.contentItemCount + 1)
    return { regularSize: [1, 1], irregularIndexes: indexes }
  }

  @Builder
  private GridSurface() {
    Grid(this.scroller, this.layoutOptions()) {
      GridItem() {
        Column() {
          Blank().height(this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT +
            Math.max(0, this.pinnedOverlayHeight - ThemeConstants.SPACE_MD))
        }.width('100%')
      }
      .padding({ bottom: ThemeConstants.SPACE_MD })
      .clip(false)

      this.content()

      GridItem() {
        Column() {
          Blank().height(this.safeArea.bottomAvoidHeight + ThemeConstants.SPACE_XL +
            Math.max(0, this.safeArea.keyboardHeight))
        }.width('100%')
      }
      .onAppear(() => {
        // The existing Browse list loads at tail appearance; Search only at reach-end.
        if (this.withPullRefresh && this.onReachEnd) this.onReachEnd()
      })
    }
    .columnsTemplate(`repeat(auto-fit, ${ThemeConstants.SOURCE_GRID_MIN_COLUMN_WIDTH}vp)`)
    .columnsGap(SOURCE_MANGA_GRID_GAP)
    .rowsGap(0)
    .enableScrollInteraction(this.pullScrollEnabled)
    .backToTop(true)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ left: SOURCE_MANGA_GRID_GAP, right: SOURCE_MANGA_GRID_GAP })
    .attributeModifier(new SourceGridClipModifier(this.withPullRefresh))
    .edgeEffect(EdgeEffect.None)
    .onScrollIndex((_first: number, last: number) => {
      this.lastVisibleIndex = last
      if (this.withPullRefresh && last >= this.contentItemCount + 1 && this.onReachEnd) {
        this.onReachEnd()
      }
    })
    .onReachEnd(() => { if (this.onReachEnd) this.onReachEnd() })
  }

  build() {
    Stack() {
      if (this.withPullRefresh) {
        PullRefresh({
          scroller: this.scroller,
          indicatorTop: this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT / 2 +
            this.pinnedOverlayHeight,
          bottomIndicatorBottom: this.safeArea.bottomAvoidHeight + ThemeConstants.SPACE_XL +
            Math.max(0, this.safeArea.keyboardHeight),
          onRefresh: async () => { if (this.onRefresh) await this.onRefresh() },
          onScrollEnableChange: (enabled: boolean) => { this.pullScrollEnabled = enabled },
        }) { this.GridSurface() }
      } else {
        this.GridSurface()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
