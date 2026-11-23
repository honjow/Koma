import { CoverPaletteColor, selectCoverPaletteColor } from './CoverPaletteSelection'

@Concurrent
export function scoreCoverPalettePixels(buffer: ArrayBuffer, width: number, height: number,
  rgbColors: number[], blueFirst: boolean): number {
  const pixels = new Uint8Array(buffer)
  const colors: CoverPaletteColor[] = rgbColors.map((rgb: number): CoverPaletteColor =>
    ({ red: (rgb >>> 16) & 255, green: (rgb >>> 8) & 255, blue: rgb & 255 }))
  const populations: number[] = colors.map((): number => 0)
  // AndroidX's default sampling area, with system quantization retained.
  const step = Math.max(1, Math.ceil(Math.sqrt(width * height / (112 * 112))))
  for (let y = 0; y < height; y += step) {
    for (let x = 0; x < width; x += step) {
      const offset = (y * width + x) * 4
      if (pixels[offset + 3] < 128) continue
      const r = pixels[offset + (blueFirst ? 2 : 0)], g = pixels[offset + 1], b = pixels[offset + (blueFirst ? 0 : 2)]
      let nearest = 0, distance = Number.MAX_VALUE
      for (let index = 0; index < colors.length; index += 1) {
        const color = colors[index]
        const dr = r - color.red, dg = g - color.green, db = b - color.blue
        const candidate = dr * dr + dg * dg + db * db
        if (candidate < distance) { distance = candidate; nearest = index }
      }
      populations[nearest] += 1
    }
  }
  const selected = selectCoverPaletteColor(colors, populations)
  return selected === undefined ? -1 : (selected.red << 16) | (selected.green << 8) | selected.blue
}
