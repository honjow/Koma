import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class AppForegroundState {
  @Trace active: boolean = false
  @Trace revision: number = 0
}

export function connectAppForegroundState(): AppForegroundState {
  return AppStorageV2.connect(AppForegroundState, 'v2:appForeground', () => new AppForegroundState())!
}

export class AppForegroundStateBridge {
  static onForeground(): void {
    const state = connectAppForegroundState()
    state.active = true
    state.revision += 1
  }

  static onBackground(): void {
    connectAppForegroundState().active = false
  }
}
