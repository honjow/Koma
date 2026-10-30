import { taskpool } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'
import { SourceBaoziBannerDetector } from './SourceBaoziBannerDetector'
import { SourceBannerImageReader, SourceBaoziBannerResources } from './SourceBaoziBannerImageWorker'

@Concurrent
function sourceBannerContentHash(path: string): string {
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
  try {
    const digest = cryptoFramework.createMd('SHA256')
    const buffer = new ArrayBuffer(128 * 1024)
    while (true) {
      const count = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
      if (count <= 0) break
      digest.updateSync({ data: new Uint8Array(buffer, 0, count) })
    }
    return Array.from(digest.digestSync().data)
      .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  } finally {
    fileIo.closeSync(file)
  }
}

@Concurrent
async function sourceBannerProcessedBytes(path: string, mode: string, expectedHash: string): Promise<ArrayBuffer> {
  // Decode the same byte snapshot whose digest identifies the derivative. A
  // concurrent Force Reload may atomically replace the original cache path.
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
  let original: ArrayBuffer
  try {
    original = new ArrayBuffer(fileIo.statSync(file.fd).size)
    if (fileIo.readSync(file.fd, original) !== original.byteLength) throw new Error('incomplete_banner_source')
  } finally {
    fileIo.closeSync(file)
  }
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new Uint8Array(original) })
  const actualHash = Array.from(digest.digestSync().data)
    .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  if (actualHash !== expectedHash) throw new Error('banner_source_replaced')
  const source = image.createImageSource(original)
  let pixels: image.PixelMap | undefined = undefined
  let packer: image.ImagePacker | undefined = undefined
  try {
    const info = await source.getImageInfo()
    pixels = await source.createPixelMap({ editable: true, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
    const reader = new SourceBannerImageReader(pixels, info.size.width, info.size.height)
    const crop = await SourceBaoziBannerDetector.detect(reader, await SourceBaoziBannerResources.signatures(), mode)
    const height = info.size.height - crop.top - crop.bottom
    if (crop.top + crop.bottom === 0 || height <= 0) return new ArrayBuffer(0)
    await pixels.crop({ x: 0, y: crop.top, size: { width: info.size.width, height } })
    packer = image.createImagePacker()
    return await packer.packing(pixels, { format: 'image/jpeg', quality: 90 })
  } finally {
    if (packer !== undefined) await packer.release()
    if (pixels !== undefined) await pixels.release()
    await source.release()
  }
}

/** Source presentation only: original download files, hashes and cover cache stay untouched. */
export class SourceBaoziBannerService {
  private static inFlight: Map<string, Promise<string>> = new Map()
  private static noBanner: Set<string> = new Set()

  static prepare(originalPath: string, mode: string, store: RemoteImageCacheStore, profileIdentity: string): Promise<string> {
    if (mode !== '1' && mode !== '2') return Promise.resolve(originalPath)
    const requestKey = JSON.stringify([originalPath, mode, profileIdentity])
    const pending = SourceBaoziBannerService.inFlight.get(requestKey)
    if (pending !== undefined) return pending
    const request = SourceBaoziBannerService.process(originalPath, mode, store, profileIdentity)
    SourceBaoziBannerService.inFlight.set(requestKey, request)
    const release = (): void => {
      if (SourceBaoziBannerService.inFlight.get(requestKey) === request) {
        SourceBaoziBannerService.inFlight.delete(requestKey)
      }
    }
    void request.then(release, release)
    return request
  }

  private static async process(
    originalPath: string, mode: string, store: RemoteImageCacheStore, profileIdentity: string,
  ): Promise<string> {
    try {
      const contentHash = await taskpool.execute<[string], string>(sourceBannerContentHash, originalPath)
      const key = JSON.stringify(['baozi-banner-v1', profileIdentity, contentHash, mode])
      const negative = SourceBaoziBannerService.noBanner.has(key)
      const cached = negative ? undefined : await store.get('source-baozi-banner.jpg', undefined, key)
      if (negative || cached !== undefined) {
        const currentHash = await taskpool.execute<[string], string>(sourceBannerContentHash, originalPath)
        return currentHash === contentHash ? (cached ?? originalPath) : originalPath
      }
      const bytes = await taskpool.execute<[string, string, string], ArrayBuffer>(
        sourceBannerProcessedBytes, originalPath, mode, contentHash)
      if (bytes.byteLength === 0) {
        SourceBaoziBannerService.noBanner.add(key)
        if (SourceBaoziBannerService.noBanner.size > 256) {
          for (const oldest of SourceBaoziBannerService.noBanner) {
            SourceBaoziBannerService.noBanner.delete(oldest)
            break
          }
        }
        return originalPath
      }
      // Same cache owner means normal size limits, statistics and Clear Cache
      // include the derivative. A reused path never substitutes for content identity.
      return await store.put('source-baozi-banner.jpg', undefined, bytes, key)
    } catch (_error) {
      // Processing failure is not a negative detection and is never cached.
      return originalPath
    }
  }
}
