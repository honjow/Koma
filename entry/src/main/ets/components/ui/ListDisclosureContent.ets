import { AnimatorResult, FrameCallback, UIContext } from '@kit.ArkUI'
import { ThemeConstants } from '../../theme/ThemeConstants'

export const LIST_DISCLOSURE_MS: number = 350
// A source card has two lines of text. Use its normal HDS row height
// until ArkUI has laid out that particular card.
const SOURCE_ROW_HEIGHT: number = 64

class DisclosureLayoutFrame extends FrameCallback {
  private start: () => void

  constructor(start: () => void) {
    super()
    this.start = start
  }

  onFrame(_frameTimeInNano: number): void {
    this.start()
  }

  onIdle(_timeLeftInNano: number): void {}
}

@ObservedV2
export class ListDisclosureMotion {
  @Trace section: string | undefined = undefined
  @Trace progress: number = 0
  heightBudget: number = 0
  private animator?: AnimatorResult
  private viewportHeight: number = 0
  private viewportBottom: number = 0
  private viewportWidth: number = 0
  private rowHeights: Map<string, number[]> = new Map()
  private visibleRows: number = 0

  setViewport(area: Area): void {
    this.viewportHeight = Number(area.height)
    this.viewportBottom = Number(area.globalPosition.y) + this.viewportHeight
    if (Number(area.width) !== this.viewportWidth) {
      this.viewportWidth = Number(area.width)
      this.rowHeights.clear()
    }
  }

  rememberHeight(section: string, index: number, height: number): void {
    if (!Number.isFinite(height) || height <= 0) return
    let heights = this.rowHeights.get(section)
    if (heights === undefined) {
      heights = []
      this.rowHeights.set(section, heights)
    }
    heights[index] = height
  }

  rowLimit(section: string, expanded: boolean, rows: number): number {
    if (this.section === section) {
      return Math.min(rows, this.visibleRows)
    }
    return expanded ? rows : 0
  }

  run(uiContext: UIContext, section: string, wasExpanded: boolean, rowCount: number, headerBottom?: number): void {
    const reversing = this.section === section
    if (!reversing) {
      this.heightBudget = headerBottom === undefined ? this.viewportHeight : this.viewportBottom - headerBottom
      const heights = this.rowHeights.get(section)
      let height = 0
      this.visibleRows = 0
      while (this.visibleRows < rowCount && height < this.heightBudget) {
        height += heights?.[this.visibleRows] ?? SOURCE_ROW_HEIGHT
        this.visibleRows++
      }
    }
    const begin = reversing ? this.progress : wasExpanded ? 1 : 0
    this.animator?.cancel()
    if (this.visibleRows === 0) {
      this.animator = undefined
      this.section = undefined
      return
    }
    const end = wasExpanded ? 0 : 1
    this.progress = begin
    this.section = section
    const animator = uiContext.createAnimator({
      duration: Math.max(1, Math.round(LIST_DISCLOSURE_MS * Math.abs(end - begin))),
      easing: 'ease-in-out', delay: 0, fill: 'forwards',
      direction: 'normal', iterations: 1, begin, end,
    })
    this.animator = animator
    animator.onFrame = (value: number): void => {
      if (this.animator === animator) this.progress = value
    }
    animator.onFinish = (): void => {
      if (this.animator !== animator) return
      this.animator = undefined
      this.section = undefined
    }
    if (wasExpanded || reversing) {
      animator.play()
    } else {
      // Mount the bounded group head while it is still clipped to zero.
      // Start the clock after ArkUI has had a layout frame for those cards.
      uiContext.postFrameCallback(new DisclosureLayoutFrame((): void => {
        if (this.animator !== animator) return
        uiContext.postFrameCallback(new DisclosureLayoutFrame((): void => {
          if (this.animator === animator) animator.play()
        }))
      }))
    }
  }
}

@ComponentV2
export struct ListDisclosureContent {
  @Param progress: number = 1
  @Param heightBudget: number = 0
  @BuilderParam content: () => void

  onMeasureSize(_self: GeometryInfo, children: Measurable[], constraint: ConstraintSizeOptions): SizeResult {
    const content = children[0].measure(constraint)
    // The same viewport-bounded height clips the cards and takes up space in
    // the list. Following groups move with that edge; cards stay at their own
    // positions under the header.
    return { width: content.width, height: Math.min(content.height, this.heightBudget) * this.progress }
  }

  onPlaceChildren(_self: GeometryInfo, children: Layoutable[], _constraint: ConstraintSizeOptions): void {
    children[0].layout({ x: 0, y: 0 })
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    // Source rows already exceed the touch target. Vary the child's minimum
    // within that range to request a new measure without altering its full height.
    .constraintSize({ minHeight: this.progress * ThemeConstants.TOUCH_TARGET_SM })
  }
}
