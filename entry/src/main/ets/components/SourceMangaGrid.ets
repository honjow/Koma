import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { PullRefresh } from './PullRefresh'
import { connectLibraryCoverLayout, LibraryCoverLayoutState } from '../state/LibraryCoverLayoutState'
import { LibraryCoverGridAdjustment } from '../state/LibraryCoverGridAdjustment'
import { libraryCoverGridColumnCount, libraryCoverGridGap } from '../utils/LibraryCoverLayout'
import { gridFallbackContainerWidth } from '../utils/GridColumns'

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
  @Param singleColumn: boolean = false
  @Param useSharedColumnWidth: boolean = false
  @Param gridAdjustment?: LibraryCoverGridAdjustment = undefined
  @Param withPullRefresh: boolean = false
  @Param paginationItemIndex: number = -1
  private lastVisibleIndex: number = -1
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private coverLayout: LibraryCoverLayoutState = connectLibraryCoverLayout()
  @Local private pullScrollEnabled: boolean = true
  @Event onRefresh?: () => Promise<void>
  @Event onPaginationRequested?: () => void

  @Monitor('paginationItemIndex')
  private requestNextPageIfVisible(): void {
    // The leading inset occupies Grid index 0. Use the visible range because
    // ForEach can mount offscreen items. Recheck when a short or empty page
    // completes without changing that range.
    if (this.paginationItemIndex >= 0 && this.lastVisibleIndex >= this.paginationItemIndex + 1 &&
      this.lastVisibleIndex <= this.contentItemCount + 1) {
      this.onPaginationRequested?.()
    }
  }

  private layoutOptions(): GridLayoutOptions {
    const indexes: number[] = [0]
    this.fullRowIndexes.forEach((index: number) => indexes.push(index + 1))
    indexes.push(this.contentItemCount + 1)
    return { regularSize: [1, 1], irregularIndexes: indexes }
  }

  private viewportWidth(): number {
    return this.safeArea.windowWidthVp > 0 ? this.safeArea.windowWidthVp : gridFallbackContainerWidth()
  }

  private columnsTemplate(): string {
    if (this.singleColumn) return '1fr'
    const preferredWidth = this.useSharedColumnWidth ? this.coverLayout.gridColumnWidth : 0
    const width = this.gridAdjustment?.width(preferredWidth) ?? preferredWidth
    return `repeat(${libraryCoverGridColumnCount(this.viewportWidth(), this.coverLayout.density, width)}, 1fr)`
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
    }
    .columnsTemplate(this.columnsTemplate())
    .columnsGap(libraryCoverGridGap(this.coverLayout.density))
    .rowsGap(0)
    .enableScrollInteraction(this.pullScrollEnabled)
    .backToTop(true)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ left: libraryCoverGridGap(this.coverLayout.density), right: libraryCoverGridGap(this.coverLayout.density) })
    .attributeModifier(new SourceGridClipModifier(this.withPullRefresh))
    .edgeEffect(this.withPullRefresh ? EdgeEffect.None : EdgeEffect.Spring, {
      alwaysEnabled: !this.withPullRefresh,
    })
    .gesture(PinchGesture({ fingers: 2 })
      .onActionStart((): void => {
        if (!this.singleColumn) {
          this.gridAdjustment?.beginPinch(this.viewportWidth(), this.coverLayout.density, this.coverLayout.gridColumnWidth)
        }
      })
      .onActionUpdate((event: GestureEvent): void => { this.gridAdjustment?.updatePinch(event.scale, this.getUIContext()) })
      .onActionEnd((): void => { this.gridAdjustment?.endPinch(this.getUIContext()) })
      .onActionCancel((): void => { this.gridAdjustment?.cancelPinch() }))
    .onScrollIndex((_first: number, last: number) => {
      this.lastVisibleIndex = last
      this.requestNextPageIfVisible()
    })
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
