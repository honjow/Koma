import { image } from '@kit.ImageKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import nativeAvif from 'libkoma_reader_avif.so'
import { readSourceImageBytesTask } from './SourceRequiredImageDecodePrimitives'

interface NativeReaderAvif {
  decodeDisplayPng(bytes: ArrayBuffer): ArrayBuffer
}

@Concurrent
export async function prepareReaderAvifTask(path: string, expectedHash: string): Promise<ArrayBuffer> {
  let source: image.ImageSource | undefined
  let pixelMap: image.PixelMap | undefined
  try {
    source = image.createImageSource(path)
    pixelMap = await source.createPixelMap({ editable: false, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
    const info = await pixelMap.getImageInfo()
    // An empty result denotes a successful native decode of the original file.
    if (info.size.width > 0 && info.size.height > 0) return new ArrayBuffer(0)
  } catch (_error) {
    // ImageKit's advertised AVIF support depends on the device and profile.
  } finally {
    if (pixelMap !== undefined) await pixelMap.release()
    if (source !== undefined) await source.release()
  }

  const bytes = readSourceImageBytesTask(path)
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new Uint8Array(bytes) })
  const hash = Array.from(digest.digestSync().data).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  if (hash !== expectedHash) throw new Error('reader_avif_source_replaced')
  return (nativeAvif as NativeReaderAvif).decodeDisplayPng(bytes)
}
