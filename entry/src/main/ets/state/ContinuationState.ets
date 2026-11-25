import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class ContinuationState {
  @Trace enabled: boolean = true
  @Trace autoInstallMissingSource: boolean = true
}

export function connectContinuationState(): ContinuationState {
  return AppStorageV2.connect(ContinuationState, 'koma:continuation', () => new ContinuationState())!
}
