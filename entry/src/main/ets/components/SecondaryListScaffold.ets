import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ListModifier } from '@kit.ArkUI'
import { CutoutRect, viewportFromArea } from '../utils/ContentCutout'

@ComponentV2
export struct SecondaryListScaffold {
  @BuilderParam content: () => void
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private languageState: LanguageState = connectLanguageState()
  @Param scroller: Scroller = new Scroller()
  @Param listSpace: number = ThemeConstants.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeConstants.SPACE_MD
  @Param inModal: boolean = false
  // Total height owned by a pinned title-bar bottomBuilder. This is the
  // content boundary, not ordinary List padding: List.space already occupies
  // the final interval between the reserve row and the first real item.
  @Param pinnedOverlayHeight: number = 0
  @Param bottomPadding: number = ThemeConstants.SPACE_XL
  // Only root HDS tabs float over content. Root tab pages pass their own
  // clearance explicitly; destinations keep ordinary safe-area spacing.
  @Param floatingTabTailPadding: number = 0
  @Param includeKeyboardPadding: boolean = true
  @Param reserveTitleBar: boolean = true
  @Param alwaysEnableEdgeSpring: boolean = true
  @Param scrollEnabled: boolean = true
  @Param deferPrefetch: boolean = false
  @Param surfaceColor: ResourceColor = ThemeConstants.BG_SUB
  @Event onVisibleContentChange?: (start: VisibleListContentInfo) => void
  @Event onListAttach?: () => void
  @Event onReachEnd?: () => void
  @Event onScrollStart?: () => void
  @Event onScrollStop?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Local private listViewport?: CutoutRect = undefined
  private defaultList = new ListModifier()
  private visibleRowsOnly = new ListModifier()

  aboutToAppear(): void {
    this.visibleRowsOnly.cachedCount(0)
  }

  build() {
    Stack() {
      if (this.languageState.effectiveLocale.length >= 0) {
        List({ space: this.listSpace, scroller: this.scroller }) {
          ListItem() {
            Column() {
              // The modal's HDS navigation places the list below its title.
              Blank().height((this.inModal ? 0 : this.safeArea.topAvoidHeight + this.titleBarPadding()) +
                this.pinnedOverlayReserve())
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
        .attributeModifier(this.deferPrefetch ? this.visibleRowsOnly : this.defaultList)
        .onAttach(() => { this.onListAttach?.() })
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .padding(this.contentPadding())
        .onAreaChange((_old: Area, area: Area): void => { this.listViewport = viewportFromArea(area) })
        .clipContent(this.inModal ? ContentClipMode.SAFE_AREA : ContentClipMode.CONTENT_ONLY)
        .enableScrollInteraction(this.scrollEnabled)
        .edgeEffect(this.alwaysEnableEdgeSpring ? EdgeEffect.Spring : EdgeEffect.None, {
          alwaysEnabled: this.alwaysEnableEdgeSpring,
        })
        .onScrollStart(() => { this.onScrollStart?.() })
        .onScrollStop(() => { this.onScrollStop?.() })
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
        .onScrollVisibleContentChange((start: VisibleListContentInfo) => {
          this.onVisibleContentChange?.(start)
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
    .backgroundColor(this.inModal ? Color.Transparent : this.surfaceColor)
  }

  private contentPadding(): Padding {
    if (this.inModal && this.listViewport === undefined) return { left: 0, right: 0 }
    return this.safeArea.sidePadding(this.inModal ? 0 : this.horizontalPadding, this.listViewport)
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

  private pinnedOverlayReserve(): number {
    if (this.pinnedOverlayHeight <= 0) {
      return 0
    }
    return Math.max(0, this.pinnedOverlayHeight - this.listSpace)
  }
}
