import { image } from '@kit.ImageKit'
import { SourceBannerPixelReader } from './ImageBannerDetector'

export class SourceBannerImageReader implements SourceBannerPixelReader {
  width: number
  height: number
  private pixels: image.PixelMap

  constructor(pixels: image.PixelMap, width: number, height: number) {
    this.pixels = pixels
    this.width = width
    this.height = height
  }

  async readRegion(x: number, y: number, width: number, height: number): Promise<Uint8Array> {
    // Copy only the candidate strip, never a second full long-comic bitmap.
    const buffer = new ArrayBuffer(width * height * 4)
    await this.pixels.readPixelsToArea({
      pixels: buffer, offset: 0, stride: width * 4,
      region: { x, y, size: { width, height } },
    })
    return new Uint8Array(buffer)
  }
}
