import { AppStorageV2 } from '@kit.ArkUI'

export const MAX_APPEARANCE_COLOR_FAVORITES: number = 36
export const DEFAULT_APPEARANCE_COLOR_FAVORITES: string[] = [
  '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4', '#009688',
  '#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107', '#FF9800', '#FF5722', '#795548', '#607D8B', '#9E9E9E',
]

export enum MangaDetailTransitionMode {
  SYSTEM = 'system',
  SEAMLESS = 'seamless',
  COVER_EXPAND = 'coverExpand',
}

// CURRENT_STATUS #359: the user chose cover expansion as the default.
// Explicit saved choices still win; do not migrate them to the new default.
export const DEFAULT_DETAIL_TRANSITION_MODE: string = MangaDetailTransitionMode.COVER_EXPAND

export function normalizeAppearanceDetailTransitionMode(mode: string): string {
  return mode === MangaDetailTransitionMode.SYSTEM || mode === MangaDetailTransitionMode.SEAMLESS ||
    mode === MangaDetailTransitionMode.COVER_EXPAND ? mode : DEFAULT_DETAIL_TRANSITION_MODE
}

@ObservedV2
export class AppearanceState {
  @Trace detailTransitionMode: string = DEFAULT_DETAIL_TRANSITION_MODE
  @Trace accentColor: string = 'emerald'
  // The picker owns this transient override until its sheet disappears. The store publishes confirmed colors separately.
  @Trace previewAccentColor: string = ''
  @Trace accentColorFavorites: string[] = DEFAULT_APPEARANCE_COLOR_FAVORITES.slice()
  @Trace autoHideBottomBar: boolean = true
  @Trace showResumeMiniBar: boolean = true
  @Trace doubleBackToExit: boolean = true
  @Trace colorMode: number = -1
}

export function connectAppearanceState(): AppearanceState {
  return AppStorageV2.connect(AppearanceState, 'koma:appearance', () => new AppearanceState())!
}

export function isCustomAppearanceAccentColor(value: string): boolean {
  return /^#[0-9a-fA-F]{6}$/.test(value)
}

export function effectiveAppearanceAccent(state: AppearanceState): string {
  return state.previewAccentColor || state.accentColor
}

// Existing presets keep their stored IDs. Emerald resolves to the host's light/dark resource.
export function appearanceAccentValue(value: string, emerald: ResourceStr): ResourceStr {
  if (value === 'ocean') return '#3268B8'
  if (value === 'rose') return '#B8466A'
  if (value === 'amber') return '#A66A1F'
  if (value === 'mono') return '#6C706C'
  if (isCustomAppearanceAccentColor(value)) return value
  return emerald
}
