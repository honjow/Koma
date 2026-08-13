import { vibrator } from '@kit.SensorServiceKit'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

const PULL_START_DRAG_VP: number = 4
const PULL_ARM_VP: number = 10
const PULL_RESISTANCE_FACTOR: number = 0.8
const DEFAULT_PULL_REFRESH_THRESHOLD: number = 80
const REFRESH_HOLD_OFFSET: number = 56
const PULL_INDICATOR_SIZE: number = 28
const PULL_LOADING_SIZE_SMALL: number = 24
const HAPTIC_HD_INTENSITY: number = 80
const HAPTIC_FALLBACK_DURATION: number = 30
const DIRECTION_LOCK_VP: number = 6
const PROGRAMMATIC_PULL_ANIM_DURATION: number = 300
const PULL_ANIM_DURATION: number = 400
const PULL_ANIM_STATE_RESET_MS: number = 420
const PULL_ANIM_DONE_DELAY_MS: number = 200

export class PullRefreshController {
  private topRefreshAction: () => void = () => {}

  setTopRefreshAction(action: () => void): void {
    this.topRefreshAction = action
  }

  triggerTopRefresh(): void {
    this.topRefreshAction()
  }
}

// This is Koma's local equivalent of NextE's pull container. The pull gesture
// owns the same Scroller as its List so the indicator, content offset and
// edge-state all share one coordinate system.
@ComponentV2
export struct PullRefresh {
  @BuilderParam content: () => void
  @Param scroller: Scroller = new Scroller()
  @Param controller: PullRefreshController = new PullRefreshController()
  @Event onRefresh: () => Promise<void> = async () => {}
  @Event onBottomRefresh: () => Promise<void> = async () => {}
  @Param canStartBottomRefresh: () => boolean = () => false
  @Event onScrollEnableChange: (enabled: boolean) => void = (_enabled: boolean) => {}
  @Param indicatorTop: number = 0
  @Param threshold: number = DEFAULT_PULL_REFRESH_THRESHOLD
  @Param bottomIndicatorBottom: number = ThemeConstants.SPACE_XL

  @Local private pullOffset: number = 0
  @Local private bottomPullOffset: number = 0
  @Local private refreshState: number = 0
  @Local private bottomRefreshState: number = 0
  @Local private containerHeight: number = 0
  // The mount state is independent of the load lifecycle. It lets the spinner
  // fade with the collapsing pull gap instead of vanishing on the rebound.
  @Local private topIndicatorMounted: boolean = false
  @Local private bottomIndicatorMounted: boolean = false
  private hapticFired: boolean = false
  private touchStartX: number = 0
  private touchStartY: number = 0
  private touchStartPullOffset: number = 0
  private touchStartBottomPullOffset: number = 0
  private topEdgeDragStartY: number = 0
  private bottomEdgeDragStartY: number = 0
  private isTracking: boolean = false
  private isBottomTracking: boolean = false
  private isHorizontalGesture: boolean = false

  aboutToAppear(): void {
    this.controller.setTopRefreshAction(() => {
      this.triggerProgrammaticTopRefresh()
    })
  }

  private isListAtTop(): boolean {
    try {
      return this.scroller.currentOffset().yOffset <= 0
    } catch (_error) {
      return false
    }
  }

  private isListAtBottom(): boolean {
    try {
      return this.scroller.isAtEnd()
    } catch (_error) {
      return false
    }
  }

  private bounceBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    this.getUIContext().animateTo(
      { duration: PULL_ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.pullOffset = target
      },
    )
    if (target === 0) {
      setTimeout(() => {
        if (this.pullOffset <= 0) {
          this.refreshState = 0
          this.hapticFired = false
          this.topIndicatorMounted = false
        }
      }, PULL_ANIM_STATE_RESET_MS)
    }
  }

  private bounceBottomBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    this.getUIContext().animateTo(
      { duration: PULL_ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.bottomPullOffset = target
      },
    )
    if (target === 0) {
      setTimeout(() => {
        if (this.bottomPullOffset <= 0) {
          this.bottomRefreshState = 0
          this.hapticFired = false
          this.bottomIndicatorMounted = false
        }
      }, PULL_ANIM_STATE_RESET_MS)
    }
  }

  private onPullEnd(): void {
    if (this.pullOffset >= this.threshold && this.refreshState !== 2) {
      this.onScrollEnableChange(true)
      this.getUIContext().animateTo(
        { duration: PULL_ANIM_DURATION, curve: Curve.EaseOut },
        () => {
          this.pullOffset = REFRESH_HOLD_OFFSET
        },
      )
      this.refreshState = 2
      void this.doRefresh()
    } else if (this.pullOffset > 0) {
      this.bounceBack(0)
    }
  }

  private triggerProgrammaticTopRefresh(): void {
    if (this.refreshState >= 2 || this.topIndicatorMounted || this.pullOffset > 0 || this.bottomPullOffset > 0) {
      return
    }
    try {
      if (!this.isListAtTop()) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
      }
    } catch (_error) {}
    this.onScrollEnableChange(false)
    this.topIndicatorMounted = true
    this.getUIContext().animateTo(
      { duration: PROGRAMMATIC_PULL_ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.pullOffset = this.threshold
      },
    )
    setTimeout(() => {
      this.refreshState = 1
      this.triggerHaptic()
      this.onPullEnd()
    }, PROGRAMMATIC_PULL_ANIM_DURATION)
  }

  private onBottomPullEnd(): void {
    if (this.bottomPullOffset >= this.threshold && this.bottomRefreshState !== 2) {
      this.onScrollEnableChange(true)
      this.getUIContext().animateTo(
        { duration: PULL_ANIM_DURATION, curve: Curve.EaseOut },
        () => {
          this.bottomPullOffset = REFRESH_HOLD_OFFSET
        },
      )
      this.bottomRefreshState = 2
      void this.doBottomRefresh()
    } else if (this.bottomPullOffset > 0) {
      this.bounceBottomBack(0)
    }
  }

  private async doRefresh(): Promise<void> {
    try {
      await this.onRefresh()
    } catch (_error) {
      this.notifyRefreshFailed()
    } finally {
      this.refreshState = 3
      setTimeout(() => this.bounceBack(0), PULL_ANIM_DONE_DELAY_MS)
    }
  }

  private async doBottomRefresh(): Promise<void> {
    try {
      await this.onBottomRefresh()
    } catch (_error) {
      this.notifyRefreshFailed()
    } finally {
      this.bottomRefreshState = 3
      setTimeout(() => this.bounceBottomBack(0), PULL_ANIM_DONE_DELAY_MS)
    }
  }

  private notifyRefreshFailed(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('common_load_failed') })
    } catch (_error) {}
  }

  private triggerHaptic(): void {
    if (this.hapticFired) {
      return
    }
    this.hapticFired = true
    try {
      if (vibrator.isHdHapticSupported()) {
        vibrator.startVibration(
          {
            type: 'preset',
            effectId: 'haptic.effect.soft',
            count: 1,
            intensity: HAPTIC_HD_INTENSITY,
          },
          { usage: 'physicalFeedback' },
        )
      } else {
        vibrator.startVibration(
          { type: 'time', duration: HAPTIC_FALLBACK_DURATION },
          { usage: 'physicalFeedback' },
        )
      }
    } catch (_error) {}
  }

  private resetTouchState(): void {
    this.isTracking = false
    this.isBottomTracking = false
    this.isHorizontalGesture = false
    this.topEdgeDragStartY = 0
    this.bottomEdgeDragStartY = 0
  }

  private areaLength(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private indicatorOpacity(gap: number, indicatorSize: number): number {
    const range = REFRESH_HOLD_OFFSET - indicatorSize
    if (range <= 0) {
      return gap >= indicatorSize ? 1 : 0
    }
    return Math.min(Math.max((gap - indicatorSize) / range, 0), 1)
  }

  private bottomIndicatorY(): number {
    return Math.max(
      0,
      this.containerHeight -
        this.bottomIndicatorBottom -
        this.bottomPullOffset / 2 -
        REFRESH_HOLD_OFFSET / 2 +
        ThemeConstants.SPACE_SM,
    )
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.content()
      }
      .offset({ y: this.pullOffset - this.bottomPullOffset })
      .onTouch((event: TouchEvent) => {
        if (this.refreshState >= 2 || this.bottomRefreshState >= 2) {
          return
        }

        if (event.type === TouchType.Down) {
          const touch = event.touches[0]
          if (touch === undefined) {
            return
          }
          this.touchStartX = touch.x
          this.touchStartY = touch.y
          this.touchStartPullOffset = this.pullOffset
          this.touchStartBottomPullOffset = this.bottomPullOffset
          this.resetTouchState()
          return
        }

        if (event.type === TouchType.Move) {
          const touch = event.touches[0]
          if (touch === undefined) {
            return
          }
          const deltaX = touch.x - this.touchStartX
          const deltaY = touch.y - this.touchStartY
          if (this.isHorizontalGesture) {
            return
          }
          if (!this.isTracking && !this.isBottomTracking) {
            if (Math.abs(deltaX) > DIRECTION_LOCK_VP && Math.abs(deltaX) > Math.abs(deltaY)) {
              this.isHorizontalGesture = true
              return
            }
            const verticalDominant = Math.abs(deltaY) > Math.abs(deltaX) * 1.5
            if (verticalDominant && deltaY > PULL_ARM_VP && this.isListAtTop()) {
              this.isTracking = true
              this.topEdgeDragStartY = touch.y - PULL_START_DRAG_VP
              this.touchStartPullOffset = 0
              this.onScrollEnableChange(false)
            } else if (
              verticalDominant &&
              deltaY < -PULL_ARM_VP &&
              this.isListAtBottom() &&
              this.canStartBottomRefresh()
            ) {
              this.isBottomTracking = true
              this.bottomEdgeDragStartY = touch.y + PULL_START_DRAG_VP
              this.touchStartBottomPullOffset = 0
              this.onScrollEnableChange(false)
            } else {
              return
            }
          }
          if (this.isTracking) {
            const topPullDelta = touch.y - this.topEdgeDragStartY
            this.pullOffset = Math.max(0, this.touchStartPullOffset + topPullDelta * PULL_RESISTANCE_FACTOR)
            if (this.pullOffset > 0) {
              this.topIndicatorMounted = true
            }
            if (this.pullOffset >= this.threshold) {
              this.refreshState = 1
              this.triggerHaptic()
            } else {
              this.refreshState = 0
            }
          } else if (this.isBottomTracking) {
            const bottomPullDelta = this.bottomEdgeDragStartY - touch.y
            this.bottomPullOffset = Math.max(
              0,
              this.touchStartBottomPullOffset + bottomPullDelta * PULL_RESISTANCE_FACTOR,
            )
            if (this.bottomPullOffset > 0) {
              this.bottomIndicatorMounted = true
            }
            if (this.bottomPullOffset >= this.threshold) {
              this.bottomRefreshState = 1
              this.triggerHaptic()
            } else {
              this.bottomRefreshState = 0
            }
          }
        }

        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          if (this.isTracking && this.pullOffset > 0) {
            this.onPullEnd()
          } else if (this.isBottomTracking && this.bottomPullOffset > 0) {
            this.onBottomPullEnd()
          } else {
            this.topIndicatorMounted = false
            this.bottomIndicatorMounted = false
          }
          this.onScrollEnableChange(true)
          this.resetTouchState()
        }
      })

      if (this.topIndicatorMounted) {
        Column() {
          Row() {
            LoadingProgress()
              .width(PULL_INDICATOR_SIZE)
              .height(PULL_INDICATOR_SIZE)
          }
          .width('100%')
          .height(REFRESH_HOLD_OFFSET)
          .justifyContent(FlexAlign.Center)
          .opacity(this.indicatorOpacity(this.pullOffset, PULL_INDICATOR_SIZE))
        }
        .position({ y: this.indicatorTop + this.pullOffset / 2 })
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.bottomIndicatorMounted) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          LoadingProgress()
            .width(PULL_LOADING_SIZE_SMALL)
            .height(PULL_LOADING_SIZE_SMALL)
            .color(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
        .height(REFRESH_HOLD_OFFSET)
        .justifyContent(FlexAlign.Center)
        .opacity(this.indicatorOpacity(this.bottomPullOffset, PULL_LOADING_SIZE_SMALL))
        .position({ y: this.bottomIndicatorY() })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerHeight = this.areaLength(newValue.height)
    })
  }
}
