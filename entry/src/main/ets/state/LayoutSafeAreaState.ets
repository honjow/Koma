import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class LayoutSafeAreaState {
  @Trace topAvoidHeight: number = 0
  @Trace bottomAvoidHeight: number = 0
  @Trace keyboardHeight: number = 0
  @Trace windowWidthVp: number = 0
  // Height of the camera cutout's avoid area measured from the top of the
  // window. Published from the window avoid area, so it updates on rotation,
  // fold and resize instead of relying on a display query.
  @Trace topCutoutHeight: number = 0
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

  static publishTopCutoutHeight(topCutoutHeight: number): void {
    if (!Number.isFinite(topCutoutHeight) || topCutoutHeight < 0) return
    const state = connectLayoutSafeArea()
    if (state.topCutoutHeight !== topCutoutHeight) {
      state.topCutoutHeight = topCutoutHeight
    }
  }
}
