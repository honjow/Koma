import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class IncognitoState {
  @Trace enabled: boolean = false
  @Trace sourceIds: string[] = []

  isSourceEnabled(sourceId?: string): boolean {
    return sourceId !== undefined && this.sourceIds.includes(sourceId)
  }

  isEnabledForSource(sourceId: string): boolean {
    return this.enabled || this.isSourceEnabled(sourceId)
  }
}

const INCOGNITO_STATE_V2_KEY: string = 'v2:incognito'

export function connectIncognitoState(): IncognitoState {
  return AppStorageV2.connect(IncognitoState, INCOGNITO_STATE_V2_KEY, () => new IncognitoState())!
}
