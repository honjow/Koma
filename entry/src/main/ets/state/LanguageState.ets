import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class LanguageState {
  @Trace mode: string = 'system'
  @Trace effectiveLocale: string = ''
}

// AppStorageV2 keys accept letters, digits and underscores. This key is only
// process-local UI state; LanguageSettings keeps the persisted app.language key.
// AppStrings reads this on every label, so an invalid key floods UI hot paths.
const LANGUAGE_STATE_KEY: string = 'koma_language'

export function connectLanguageState(): LanguageState {
  return AppStorageV2.connect(LanguageState, LANGUAGE_STATE_KEY, () => new LanguageState())!
}
