// Port of Keiyoushi baozimanhua BannerChecker.kt, fixed reference 949dea25.
// Preserve its row signatures, threshold and normal/extra precedence; this is
// source-owned banner detection, independent of the user's white-edge crop.
export interface SourceBannerPixelReader {
  width: number
  height: number
  /** ImageKit's region reads return packed BGRA, including when the map is RGBA. */
  readRegion(x: number, y: number, width: number, height: number): Promise<Uint8Array>
}

export class SourceBannerSignature {
  width: number
  height: number
  averages: number[]
  columns: number[]

  constructor(width: number, height: number, averages: number[]) {
    this.width = width
    this.height = height
    this.averages = averages
    this.columns = SourceBaoziBannerDetector.sampleColumns(width)
  }
}

export interface SourceBannerSignatures {
  current: SourceBannerSignature
  old: SourceBannerSignature
  narrow: SourceBannerSignature
}

export interface SourceBannerCrop {
  top: number
  bottom: number
}

export class SourceBaoziBannerDetector {
  static sampleColumns(width: number): number[] {
    const start = Math.floor(width * 0.2)
    const end = Math.floor(width * 0.8)
    const step = Math.max(1, (end - start) / 16)
    const result: number[] = []
    for (let index = 0; index < 16; index += 1) {
      result.push(Math.min(width - 1, start + Math.floor(index * step)))
    }
    return result
  }

  private static rowAverage(pixels: Uint8Array, width: number, row: number, columns: number[]): number[] {
    let red = 0
    let green = 0
    let blue = 0
    for (const column of columns) {
      const index = (row * width + column) * 4
      blue += pixels[index]
      green += pixels[index + 1]
      red += pixels[index + 2]
    }
    return [Math.floor(red / 16), Math.floor(green / 16), Math.floor(blue / 16)]
  }

  static signature(pixels: Uint8Array, width: number, height: number): SourceBannerSignature {
    const columns = SourceBaoziBannerDetector.sampleColumns(width)
    const averages: number[] = []
    for (let row = 0; row < height; row += 1) {
      const average = SourceBaoziBannerDetector.rowAverage(pixels, width, row, columns)
      averages.push(average[0], average[1], average[2])
    }
    return new SourceBannerSignature(width, height, averages)
  }

  private static scaled(source: SourceBannerSignature, width: number): SourceBannerSignature {
    const height = Math.max(1, Math.round(Math.fround(source.height * Math.fround(width / 640))))
    const averages: number[] = []
    for (let row = 0; row < height; row += 1) {
      const sourceY = Math.max(0, Math.min(source.height - 1, (row + 0.5) * source.height / height - 0.5))
      const before = Math.floor(sourceY)
      const after = Math.min(before + 1, source.height - 1)
      const fraction = sourceY - before
      for (let component = 0; component < 3; component += 1) {
        const value = source.averages[before * 3 + component]
        averages.push(Math.round(value + (source.averages[after * 3 + component] - value) * fraction))
      }
    }
    return new SourceBannerSignature(width, height, averages)
  }

  private static async matches(
    image: SourceBannerPixelReader, x: number, y: number, signature: SourceBannerSignature,
  ): Promise<boolean> {
    if (x < 0 || y < 0 || x + signature.width > image.width || y + signature.height > image.height) {
      return false
    }
    const pixels = await image.readRegion(x, y, signature.width, signature.height)
    const threshold = signature.height * 3 * 6
    let difference = 0
    // Match the reference's early rejection, then check all remaining rows.
    for (let row = 0; row < signature.height; row += 4) {
      const average = SourceBaoziBannerDetector.rowAverage(pixels, signature.width, row, signature.columns)
      for (let component = 0; component < 3; component += 1) {
        difference += Math.abs(average[component] - signature.averages[row * 3 + component])
      }
      if (difference > threshold / 2) return false
    }
    for (let row = 0; row < signature.height; row += 1) {
      if (row % 4 === 0) continue
      const average = SourceBaoziBannerDetector.rowAverage(pixels, signature.width, row, signature.columns)
      for (let component = 0; component < 3; component += 1) {
        difference += Math.abs(average[component] - signature.averages[row * 3 + component])
      }
      if (difference > threshold) return false
    }
    return true
  }

  static async detect(
    image: SourceBannerPixelReader, signatures: SourceBannerSignatures, mode: string,
  ): Promise<SourceBannerCrop> {
    if (mode !== '1' && mode !== '2') return { top: 0, bottom: 0 }
    const narrowWidth = image.width > 640 && image.width < 800 ? image.width : 640
    const narrow = narrowWidth === 640
      ? signatures.narrow : SourceBaoziBannerDetector.scaled(signatures.narrow, narrowWidth)
    const bottomHeight = Math.min(narrow.height, Math.max(1, Math.round(Math.fround(160 * Math.fround(narrowWidth / 640)))))
    const narrowBottom = new SourceBannerSignature(narrow.width, bottomHeight, narrow.averages.slice(0, bottomHeight * 3))
    const topSignatures: SourceBannerSignature[] = [signatures.current, signatures.old, narrow]
    const bottomSignatures: SourceBannerSignature[] = [signatures.old, signatures.current, narrowBottom]
    let top = 0
    while (top < image.height) {
      let consumed = 0
      for (const signature of topSignatures) {
        const x = Math.floor((image.width - signature.width) / 2)
        if (await SourceBaoziBannerDetector.matches(image, x, top, signature)) {
          consumed = signature.height
          break
        }
      }
      if (consumed === 0) break
      top += consumed
      if (mode === '1') return { top, bottom: 0 }
    }
    let bottom = 0
    while (top + bottom < image.height) {
      let consumed = 0
      for (const signature of bottomSignatures) {
        const y = image.height - signature.height - bottom
        if (y < top) continue
        const x = Math.floor((image.width - signature.width) / 2)
        if (await SourceBaoziBannerDetector.matches(image, x, y, signature)) {
          consumed = signature.height
          break
        }
      }
      if (consumed === 0) break
      bottom += consumed
      if (mode === '1') break
    }
    return { top, bottom }
  }
}
