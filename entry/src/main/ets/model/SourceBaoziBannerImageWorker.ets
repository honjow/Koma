import { util } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import { SourceBannerPixelReader, SourceBannerSignature, SourceBannerSignatures, SourceBaoziBannerDetector } from './SourceBaoziBannerDetector'
import { SourceBaoziBannerTemplates } from './SourceBaoziBannerTemplates'

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

export class SourceBaoziBannerResources {
  // TaskPool worker-local memoization; no UI-thread image decoding.
  private static pending: Promise<SourceBannerSignatures> | undefined = undefined

  static signatures(): Promise<SourceBannerSignatures> {
    if (SourceBaoziBannerResources.pending === undefined) {
      const pending = SourceBaoziBannerResources.load()
      SourceBaoziBannerResources.pending = pending
      void pending.catch((): void => { SourceBaoziBannerResources.pending = undefined })
    }
    return SourceBaoziBannerResources.pending
  }

  private static async load(): Promise<SourceBannerSignatures> {
    return {
      current: await SourceBaoziBannerResources.signature(SourceBaoziBannerTemplates.current(), 800, 200),
      old: await SourceBaoziBannerResources.signature(SourceBaoziBannerTemplates.old(), 800, 282),
      narrow: await SourceBaoziBannerResources.signature(SourceBaoziBannerTemplates.narrow(), 640, 186),
    }
  }

  private static async signature(base64: string, width: number, height: number): Promise<SourceBannerSignature> {
    const bytes = new util.Base64Helper().decodeSync(base64)
    const source = image.createImageSource(bytes.buffer as ArrayBuffer)
    let pixels: image.PixelMap | undefined = undefined
    try {
      const info = await source.getImageInfo()
      if (info.size.width < width || info.size.height < height) throw new Error('invalid_banner_template')
      pixels = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
      const reader = new SourceBannerImageReader(pixels, info.size.width, info.size.height)
      return SourceBaoziBannerDetector.signature(await reader.readRegion(0, 0, width, height), width, height)
    } finally {
      if (pixels !== undefined) await pixels.release()
      await source.release()
    }
  }
}
