/*
 * Palette target scoring adapted from AndroidX Palette and Target.
 * Copyright 2018 The Android Open Source Project
 * SPDX-License-Identifier: Apache-2.0
 * Sources: https://github.com/androidx/androidx/tree/androidx-main/palette/palette/src/main/java/androidx/palette/graphics
 * License: docs/licenses/AndroidX-Palette.txt
 * Host adaptation: HarmonyOS provides quantized swatches; their populations
 * are measured from sampled decoded pixels in CoverPaletteWorker.
 */
export interface CoverPaletteColor {
  red: number
  green: number
  blue: number
}

function hsl(color: CoverPaletteColor): number[] {
  const r = color.red / 255, g = color.green / 255, b = color.blue / 255
  const max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min
  const lightness = (max + min) / 2
  let hue = 0, saturation = 0
  if (delta > 0) {
    saturation = delta / (1 - Math.abs(2 * lightness - 1))
    if (max === r) hue = ((g - b) / delta) % 6
    else if (max === g) hue = (b - r) / delta + 2
    else hue = (r - g) / delta + 4
    hue = (hue * 60 + 360) % 360
  }
  return [hue, saturation, lightness]
}

// User decision: exclude overly white colors before scoring, including every
// fallback target. A cover color must retain at least 30% HSL color depth;
// choose another original swatch rather than darkening its RGB into gray.
const MAX_COVER_LIGHTNESS: number = 0.7

function allowed(values: number[]): boolean {
  return values[2] > 0.05 && values[2] <= MAX_COVER_LIGHTNESS &&
    !(values[0] >= 10 && values[0] <= 37 && values[1] <= 0.82)
}

// Exact AndroidX Target weights and VIBRANT / DARK_VIBRANT / LIGHT_VIBRANT
// ranges. Text contrast never filters or changes a cover's selected RGB.
export function selectCoverPaletteColor(colors: Array<CoverPaletteColor | null>,
  populations: number[] = []): CoverPaletteColor | undefined {
  let dominant: CoverPaletteColor | undefined = undefined
  let dominantPopulation = -1
  let maxPopulation = 1
  for (let index = 0; index < colors.length; index += 1) {
    const color = colors[index]
    if (color !== null && allowed(hsl(color))) maxPopulation = Math.max(maxPopulation, populations[index] ?? 1)
  }
  const targets: number[][] = [[0.35, 1, 0.3, 0.5, 0.7], [0.35, 1, 0, 0.26, 0.45],
    [0.35, 1, 0.55, 0.74, 1], [0, 0.3, 0.3, 0.5, 0.7], [0, 0.3, 0.55, 0.74, 1], [0, 0.3, 0, 0.26, 0.45]]
  for (let targetIndex = 0; targetIndex < targets.length; targetIndex += 1) {
    const target = targets[targetIndex]
    let winner: CoverPaletteColor | undefined = undefined
    let highest = -1
    for (let index = 0; index < colors.length; index += 1) {
      const color = colors[index]
      if (color === null || !Number.isFinite(color.red) || !Number.isFinite(color.green) || !Number.isFinite(color.blue)) continue
      const values = hsl(color)
      const population = populations[index] ?? 1
      // AndroidX DEFAULT_FILTER plus the user's stronger near-white exclusion.
      if (!allowed(values)) continue
      if (population > dominantPopulation) { dominant = color; dominantPopulation = population }
      const maxSaturation = targetIndex < 3 ? 1 : 0.4
      if (values[1] < target[0] || values[1] > maxSaturation || values[2] < target[2] || values[2] > target[4]) continue
      const score = 0.24 * (1 - Math.abs(values[1] - target[1])) +
        0.52 * (1 - Math.abs(values[2] - target[3])) + 0.24 * population / maxPopulation
      if (score > highest) { highest = score; winner = color }
    }
    if (winner !== undefined) return winner
  }
  // A rejected pale color must never re-enter through the final fallback.
  return dominant
}
