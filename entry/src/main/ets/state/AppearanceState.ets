import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class AppearanceState {
  @Trace accentColor: string = 'emerald'
}

export function connectAppearanceState(): AppearanceState {
  return AppStorageV2.connect(AppearanceState, 'koma:appearance', () => new AppearanceState())!
}

// Existing user-selectable palette; default emerald retains its light/dark resource.
export function appearanceAccentValue(value: string, emerald: ResourceStr): ResourceStr {
  if (value === 'ocean') return '#3268B8'
  if (value === 'rose') return '#B8466A'
  if (value === 'amber') return '#A66A1F'
  if (value === 'mono') return '#6C706C'
  return emerald
}
