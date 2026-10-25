import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class SourceRuntimeState {
  @Trace revision: number = 0
}

// This key owns only the process-local revision shared by Browse and its source
// routes. AppStorageV2 permits letters/digits/underscores; this is not a persisted
// registry/preference key. Keep all writers and consumers on this same connector.
const SOURCE_RUNTIME_STATE_KEY: string = 'koma_source_runtime_revision'

export function connectSourceRuntimeState(): SourceRuntimeState {
  return AppStorageV2.connect(SourceRuntimeState, SOURCE_RUNTIME_STATE_KEY, () => new SourceRuntimeState())!
}

export class SourceRuntimeStateBridge {
  static notifyChanged(): void {
    const state = connectSourceRuntimeState()
    state.revision += 1
  }
}
