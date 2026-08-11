import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class SourceRuntimeState {
  @Trace revision: number = 0
}

const SOURCE_RUNTIME_STATE_KEY: string = 'v2:sourceRuntime'

export function connectSourceRuntimeState(): SourceRuntimeState {
  return AppStorageV2.connect(SourceRuntimeState, SOURCE_RUNTIME_STATE_KEY, () => new SourceRuntimeState())!
}

export class SourceRuntimeStateBridge {
  static notifyChanged(): void {
    const state = connectSourceRuntimeState()
    state.revision += 1
  }
}
