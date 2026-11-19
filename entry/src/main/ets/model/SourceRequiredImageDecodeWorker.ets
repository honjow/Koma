import { image } from '@kit.ImageKit'
import { downloadImageExtension } from './DownloadImageFormat'
import { imagePluginNative } from './ImagePluginNative'
import { imagePluginStraightAlpha } from './ImageProcessingPlugins'
import { inflateSourceGzip, restoreJmStripePixels } from './SourceRequiredImageDecodePrimitives'

export interface SourceRequiredDecodedImage { bytes: ArrayBuffer; extension: string }

/** Required processors produce a complete result. Keeping the wire image is an error. */
@Concurrent
export async function sourceImageProcessorTask(original: ArrayBuffer, module: Uint8Array,
  byteConfig: string, pixelConfig: string): Promise<SourceRequiredDecodedImage> {
  if (original.byteLength === 0 || original.byteLength > 128 * 1024 * 1024) {
    throw new Error('source_required_decode_input_size')
  }
  let bytes = original
  if (byteConfig.length > 0) {
    const result = imagePluginNative.runImageProcessor(module, bytes, 0, 0, byteConfig, true)
    if (!result.ok || !result.changed) throw new Error('source_required_decode_processor_failed')
    bytes = result.pixels
  }
  const extension = downloadImageExtension(new Uint8Array(bytes, 0, Math.min(32, bytes.byteLength)))
  if (extension === undefined) throw new Error('source_required_decode_output_format')
  const source = image.createImageSource(bytes)
  let decoded: image.PixelMap | undefined
  let output: image.PixelMap | undefined
  let packer: image.ImagePacker | undefined
  try {
    const info = await source.getImageInfo()
    const width = info.size.width, height = info.size.height
    if (width < 1 || height < 1 || width * height * 4 > 256 * 1024 * 1024) {
      throw new Error('source_required_decode_dimensions')
    }
    if (pixelConfig.length > 0 && await source.getFrameCount() !== 1) {
      throw new Error('source_required_decode_animated_pixels')
    }
    // Decode once before accepting the output, including byte-only results.
    // The encoded result remains intact, preserving animated formats.
    decoded = await source.createPixelMap({ editable: false, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
    if (pixelConfig.length === 0) return { bytes, extension }
    const decodedInfo = await decoded.getImageInfo()
    if (decodedInfo.size.width !== width || decodedInfo.size.height !== height) {
      throw new Error('source_required_decode_dimensions')
    }
    const pixels = new ArrayBuffer(width * height * 4)
    await decoded.readPixelsToBuffer(pixels)
    if (decodedInfo.alphaType === image.AlphaType.PREMUL) imagePluginStraightAlpha(new Uint8Array(pixels))
    await decoded.release(); decoded = undefined
    const result = imagePluginNative.runImageProcessor(module, pixels, width, height, pixelConfig, true)
    if (!result.ok || !result.changed) throw new Error('source_required_decode_processor_failed')
    output = await image.createPixelMap(result.pixels, { size: { width: result.width, height: result.height },
      pixelFormat: image.PixelMapFormat.RGBA_8888, srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.UNPREMUL, editable: false })
    packer = image.createImagePacker()
    const packed = await packer.packing(output, { format: 'image/png', quality: 100 })
    if (packed.byteLength === 0 || packed.byteLength > 128 * 1024 * 1024) {
      throw new Error('source_required_decode_output_size')
    }
    return { bytes: packed, extension: 'png' }
  } finally {
    if (packer !== undefined) await packer.release()
    if (output !== undefined) await output.release()
    if (decoded !== undefined) await decoded.release()
    await source.release()
  }
}

@Concurrent
export async function requiredDecodeTask(original: ArrayBuffer, rows: number): Promise<SourceRequiredDecodedImage> {
  let bytes = original
  let head = new Uint8Array(bytes)
  if (head.length >= 2 && head[0] === 0x1f && head[1] === 0x8b) {
    bytes = await inflateSourceGzip(bytes)
    head = new Uint8Array(bytes)
  }
  // The upstream checks actual bytes, not a URL suffix: retain GIF animation.
  if (head.length >= 6 && head[0] === 0x47 && head[1] === 0x49 && head[2] === 0x46 && head[3] === 0x38 &&
    (head[4] === 0x37 || head[4] === 0x39) && head[5] === 0x61) {
    return { bytes, extension: 'gif' }
  }
  const source = image.createImageSource(bytes)
  let decoded: image.PixelMap | undefined
  let output: image.PixelMap | undefined
  let packer: image.ImagePacker | undefined
  try {
    const info = await source.getImageInfo()
    const width = info.size.width, height = info.size.height
    if (width < 1 || height < 1 || width * height * 4 > 256 * 1024 * 1024) throw new Error('source_required_decode_dimensions')
    // JM can serve a 1-pixel spacer below the stripe count. The restore loop
    // treats such an image as a no-op instead of rejecting the whole page.
    decoded = await source.createPixelMap({ editable: false, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
    const decodedInfo = await decoded.getImageInfo()
    if (decodedInfo.size.width !== width || decodedInfo.size.height !== height) throw new Error('source_required_decode_dimensions')
    const packed = new ArrayBuffer(width * height * 4)
    // Full-buffer reads are tightly packed; native row stride can include padding.
    await decoded.readPixelsToBuffer(packed)
    if (decodedInfo.alphaType === image.AlphaType.PREMUL) imagePluginStraightAlpha(new Uint8Array(packed))
    const restored = restoreJmStripePixels(packed, width, height, rows)
    output = await image.createPixelMap(restored, { size: { width, height }, pixelFormat: image.PixelMapFormat.RGBA_8888,
      srcPixelFormat: image.PixelMapFormat.RGBA_8888, alphaType: image.AlphaType.UNPREMUL, editable: false })
    packer = image.createImagePacker()
    return { bytes: await packer.packing(output, { format: 'image/jpeg', quality: 90 }), extension: 'jpg' }
  } finally {
    if (packer !== undefined) await packer.release()
    if (output !== undefined) await output.release()
    if (decoded !== undefined) await decoded.release()
    await source.release()
  }
}
