import { taskpool } from '@kit.ArkTS'
import { drawing, text } from '@kit.ArkGraphics2D'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'
import { SourceTextOverlay, SourceTextOverlayBalloon } from './SourceTextOverlay'

@Concurrent
function overlayHash(path: string): string {
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
  try {
    const digest = cryptoFramework.createMd('SHA256')
    const buffer = new ArrayBuffer(128 * 1024)
    while (true) {
      const count = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
      if (count <= 0) break
      digest.updateSync({ data: new Uint8Array(buffer, 0, count) })
    }
    return Array.from(digest.digestSync().data).map((b: number): string => b.toString(16).padStart(2, '0')).join('')
  } finally { fileIo.closeSync(file) }
}

@Concurrent
async function overlayBytes(path: string, spec: SourceTextOverlay, expectedHash: string): Promise<ArrayBuffer> {
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
  let bytes: ArrayBuffer
  try {
    bytes = new ArrayBuffer(fileIo.statSync(file.fd).size)
    if (fileIo.readSync(file.fd, bytes) !== bytes.byteLength) throw new Error('source_overlay_incomplete')
  } finally { fileIo.closeSync(file) }
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new Uint8Array(bytes) })
  const actual = Array.from(digest.digestSync().data).map((b: number): string => b.toString(16).padStart(2, '0')).join('')
  if (actual !== expectedHash) throw new Error('source_overlay_replaced')
  const source = image.createImageSource(bytes)
  let pixels: image.PixelMap | undefined
  let packer: image.ImagePacker | undefined
  try {
    pixels = await source.createPixelMap({ editable: true, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
    const canvas = new drawing.Canvas(pixels)
    for (const balloon of spec.balloons as SourceTextOverlayBalloon[]) {
      const style: text.TextStyle = { color: { alpha: 255, red: 0, green: 0, blue: 0 }, fontSize: 14, fontFamilies: ['sans-serif'] }
      const builder = new text.ParagraphBuilder({ textStyle: style, align: text.TextAlign.CENTER, breakStrategy: text.BreakStrategy.HIGH_QUALITY },
        text.FontCollection.getGlobalInstance())
      builder.addText(balloon.text)
      const paragraph = builder.build()
      paragraph.layoutSync(balloon.width)
      paragraph.paint(canvas, balloon.x, balloon.y)
    }
    packer = image.createImagePacker()
    return await packer.packing(pixels, { format: 'image/jpeg', quality: 95 })
  } finally {
    if (packer !== undefined) await packer.release()
    if (pixels !== undefined) await pixels.release()
    await source.release()
  }
}

/** Never return the original on error: it lacks the translated dialogue. */
export class SourceTextOverlayService {
  private static inFlight: Map<string, Promise<string>> = new Map()

  static prepare(path: string, spec: SourceTextOverlay, store: RemoteImageCacheStore,
    identity: string): Promise<string> {
    const requestKey = JSON.stringify([path, spec, identity])
    const existing = SourceTextOverlayService.inFlight.get(requestKey)
    if (existing !== undefined) return existing
    const pending = SourceTextOverlayService.process(path, spec, store, identity)
    SourceTextOverlayService.inFlight.set(requestKey, pending)
    const cleanup = (): void => {
      if (SourceTextOverlayService.inFlight.get(requestKey) === pending) SourceTextOverlayService.inFlight.delete(requestKey)
    }
    void pending.then(cleanup, cleanup)
    return pending
  }

  private static async process(path: string, spec: SourceTextOverlay, store: RemoteImageCacheStore,
    identity: string): Promise<string> {
    const hash = await taskpool.execute<[string], string>(overlayHash, path)
    const key = JSON.stringify(['source-text-overlay-v1', identity, hash, spec])
    const cached = await store.get('source-text-overlay.jpg', undefined, key)
    if (cached !== undefined) {
      const current = await taskpool.execute<[string], string>(overlayHash, path)
      if (current !== hash) throw new Error('source_overlay_replaced')
      return cached
    }
    const bytes = await taskpool.execute<[string, SourceTextOverlay, string], ArrayBuffer>(overlayBytes, path, spec, hash)
    if (await taskpool.execute<[string], string>(overlayHash, path) !== hash) throw new Error('source_overlay_replaced')
    return store.put('source-text-overlay.jpg', undefined, bytes, key)
  }
}
