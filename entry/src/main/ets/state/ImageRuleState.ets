import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class ImageRuleState {
  @Trace dataRevision: number = 0
  @Trace userRevision: number = 0
  @Trace enabledRuleCount: number = 0
  @Trace readFailed: boolean = false
  @Trace processingFailures: Record<string, string> = {}
}
export function connectImageRuleState(): ImageRuleState {
  return AppStorageV2.connect(ImageRuleState, 'koma.image.rules', () => new ImageRuleState())!
}
