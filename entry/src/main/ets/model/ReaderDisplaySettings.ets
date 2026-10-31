/** Display-only settings. Never enter image preparation, export or per-book mode overrides. */
export type ReaderFilterBlendMode = 'default' | 'multiply' | 'screen' | 'overlay' | 'lighten' | 'darken'

export class ReaderDisplaySettings {
  brightnessEnabled: boolean = false
  brightness: number = 0
  filterEnabled: boolean = false
  red: number = 0
  green: number = 0
  blue: number = 0
  alpha: number = 0
  blendMode: ReaderFilterBlendMode = 'default'
  grayscale: boolean = false
  inverted: boolean = false
}

function bounded(value: number, min: number, max: number): number {
  return Number.isFinite(value) ? Math.max(min, Math.min(max, Math.round(value))) : 0
}

export function normalizeReaderDisplaySettings(value?: ReaderDisplaySettings): ReaderDisplaySettings {
  const next = new ReaderDisplaySettings()
  if (value === undefined || value === null) return next
  next.brightnessEnabled = value.brightnessEnabled === true
  next.brightness = bounded(value.brightness, -75, 100)
  next.filterEnabled = value.filterEnabled === true
  next.red = bounded(value.red, 0, 255)
  next.green = bounded(value.green, 0, 255)
  next.blue = bounded(value.blue, 0, 255)
  next.alpha = bounded(value.alpha, 0, 255)
  next.blendMode = ['multiply', 'screen', 'overlay', 'lighten', 'darken'].includes(value.blendMode)
    ? value.blendMode : 'default'
  next.grayscale = value.grayscale === true
  next.inverted = value.inverted === true
  return next
}

export function parseReaderDisplaySettings(value: string): ReaderDisplaySettings {
  try { return normalizeReaderDisplaySettings(JSON.parse(value) as ReaderDisplaySettings) }
  catch (_) { return new ReaderDisplaySettings() }
}

/** Rebase one slider/toggle edit onto the latest committed display settings. */
export function rebaseReaderDisplaySettings(base: ReaderDisplaySettings, before: ReaderDisplaySettings,
  after: ReaderDisplaySettings): ReaderDisplaySettings {
  const next = normalizeReaderDisplaySettings(base)
  if (before.brightnessEnabled !== after.brightnessEnabled) next.brightnessEnabled = after.brightnessEnabled
  if (before.brightness !== after.brightness) next.brightness = after.brightness
  if (before.filterEnabled !== after.filterEnabled) next.filterEnabled = after.filterEnabled
  if (before.red !== after.red) next.red = after.red
  if (before.green !== after.green) next.green = after.green
  if (before.blue !== after.blue) next.blue = after.blue
  if (before.alpha !== after.alpha) next.alpha = after.alpha
  if (before.blendMode !== after.blendMode) next.blendMode = after.blendMode
  if (before.grayscale !== after.grayscale) next.grayscale = after.grayscale
  if (before.inverted !== after.inverted) next.inverted = after.inverted
  return normalizeReaderDisplaySettings(next)
}

/** Mihon contract: zero follows system, negatives use minimum brightness plus dimming. */
export function readerWindowBrightness(settings: ReaderDisplaySettings): number {
  if (!settings.brightnessEnabled || settings.brightness === 0) return -1
  return settings.brightness < 0 ? 0.01 : settings.brightness / 100
}

export function readerDisplayDimOpacity(settings: ReaderDisplaySettings): number {
  return settings.brightnessEnabled && settings.brightness < 0 ? -settings.brightness / 100 : 0
}
