import { taskpool } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'
import { ImageBannerDetector, SourceBannerCrop } from './ImageBannerDetector'
import { ImageBannerPlan } from './ImageBannerRules'
import { SourceBannerImageReader } from './ImageBannerImageReader'

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
async function sourceBannerProcessedBytes(path: string, plansJson: string, expectedHash: string): Promise<ArrayBuffer> {
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
    let top = 0
    let bottom = 0
    const plans = JSON.parse(plansJson) as ImageBannerPlan[]
    for (const plan of plans) {
      const remaining: SourceBannerImageReader = new SourceBannerImageReader(pixels, info.size.width, info.size.height)
      // Each rule sees the current remaining edges. Never apply two copies of one rule.
      const crop = await ImageBannerDetector.detect(remaining, plan.rule, plan.mode)
      if (crop.top + crop.bottom === 0) continue
      const height = info.size.height - crop.top - crop.bottom
      if (height <= 0) continue
      await pixels.crop({ x: 0, y: crop.top, size: { width: info.size.width, height } })
      top += crop.top; bottom += crop.bottom
      info.size.height = height
    }
    const crop: SourceBannerCrop = { top, bottom }
    if (crop.top + crop.bottom === 0) return new ArrayBuffer(0)
    packer = image.createImagePacker()
    return await packer.packing(pixels, { format: 'image/jpeg', quality: 90 })
  } finally {
    if (packer !== undefined) await packer.release()
    if (pixels !== undefined) await pixels.release()
    await source.release()
  }
}

/** Source presentation only: original download files, hashes and cover cache stay untouched. */
export class ImageBannerService {
  private static transforms: Map<string, Promise<string | undefined>> = new Map()
  private static inFlight: Map<string, Promise<string>> = new Map()

  static prepare(originalPath: string, plans: ImageBannerPlan[], store: RemoteImageCacheStore): Promise<string> {
    if (plans.length === 0) return Promise.resolve(originalPath)
    const plansJson = JSON.stringify(plans)
    const requestKey = JSON.stringify([originalPath, plansJson])
    const pending = ImageBannerService.inFlight.get(requestKey)
    if (pending !== undefined) return pending
    const request = ImageBannerService.process(originalPath, plansJson, store)
    ImageBannerService.inFlight.set(requestKey, request)
    const release = (): void => {
      if (ImageBannerService.inFlight.get(requestKey) === request) {
        ImageBannerService.inFlight.delete(requestKey)
      }
    }
    void request.then(release, release)
    return request
  }

  private static async process(
    originalPath: string, plansJson: string, store: RemoteImageCacheStore,
  ): Promise<string> {
    try {
      const contentHash = await taskpool.execute<[string], string>(sourceBannerContentHash, originalPath)
      const key = JSON.stringify(['edge-signature-v1', contentHash, plansJson])
      let pending = ImageBannerService.transforms.get(key)
      if (pending === undefined) {
        pending = ImageBannerService.transform(originalPath, plansJson, contentHash, store, key)
        ImageBannerService.transforms.set(key, pending)
        const current = pending
        const retire = (): void => { if (ImageBannerService.transforms.get(key) === current) ImageBannerService.transforms.delete(key) }
        void pending.then(retire, retire)
      }
      const prepared = await pending
      const currentHash = await taskpool.execute<[string], string>(sourceBannerContentHash, originalPath)
      return currentHash === contentHash ? (prepared ?? originalPath) : originalPath
    } catch (_error) {
      // Processing failure is not a negative detection and is never cached.
      return originalPath
    }
  }
  private static async transform(originalPath: string, plansJson: string, contentHash: string,
    store: RemoteImageCacheStore, key: string): Promise<string | undefined> {
    const cached = await store.get('image-banner.jpg', undefined, key)
    if (cached !== undefined) return cached
    if (await store.get('image-banner.nohit', undefined, key + ':nohit') !== undefined) return undefined
    const bytes = await taskpool.execute<[string, string, string], ArrayBuffer>(
      sourceBannerProcessedBytes, originalPath, plansJson, contentHash)
    if (bytes.byteLength === 0) {
      await store.put('image-banner.nohit', undefined, new Uint8Array([1]).buffer as ArrayBuffer, key + ':nohit')
      return undefined
    }
    return store.put('image-banner.jpg', undefined, bytes, key)
  }

}
