import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class LanguageState {
  @Trace mode: string = 'system'
  @Trace effectiveLocale: string = ''
}

const LANGUAGE_STATE_KEY: string = 'koma:language'

export function connectLanguageState(): LanguageState {
  return AppStorageV2.connect(LanguageState, LANGUAGE_STATE_KEY, () => new LanguageState())!
}
