import { AppStorageV2 } from '@kit.ArkUI'

interface TopCutout {
  left: number
  right: number
  bottom: number
}

@ObservedV2
export class LayoutSafeAreaState {
  @Trace topAvoidHeight: number = 0
  @Trace bottomAvoidHeight: number = 0
  @Trace keyboardHeight: number = 0
  @Trace windowWidthVp: number = 0
  // Window coordinates in vp. Publish the edges together on rotation, fold and resize.
  @Trace topCutout: TopCutout = { left: 0, right: 0, bottom: 0 }
}

const LAYOUT_SAFE_AREA_V2_KEY: string = 'v2:layoutSafeArea'

export function connectLayoutSafeArea(): LayoutSafeAreaState {
  return AppStorageV2.connect(LayoutSafeAreaState, LAYOUT_SAFE_AREA_V2_KEY, () => new LayoutSafeAreaState())!
}

export class LayoutSafeAreaBridge {
  static publishWindowWidth(windowWidthVp: number): void {
    if (!Number.isFinite(windowWidthVp) || windowWidthVp <= 0) return
    const state = connectLayoutSafeArea()
    if (state.windowWidthVp !== windowWidthVp) state.windowWidthVp = windowWidthVp
  }

  static publishInsets(topAvoidHeight: number, bottomAvoidHeight: number): void {
    const state = connectLayoutSafeArea()
    if (state.topAvoidHeight !== topAvoidHeight) {
      state.topAvoidHeight = topAvoidHeight
    }
    if (state.bottomAvoidHeight !== bottomAvoidHeight) {
      state.bottomAvoidHeight = bottomAvoidHeight
    }
  }

  static publishKeyboardHeight(keyboardHeight: number): void {
    const state = connectLayoutSafeArea()
    if (state.keyboardHeight !== keyboardHeight) {
      state.keyboardHeight = keyboardHeight
    }
  }

  static publishTopCutout(left: number, right: number, bottom: number): void {
    const state = connectLayoutSafeArea()
    const current = state.topCutout
    if (current.left !== left || current.right !== right || current.bottom !== bottom) {
      state.topCutout = { left, right, bottom }
    }
  }
}
