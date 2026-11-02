import { taskpool, util } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'
import { imageFileContentHash } from './ImageFileContent'
import { imagePluginNative } from './ImagePluginNative'
import { ImagePluginPlan, ImagePluginConfiguration, ImagePluginContext, imagePluginDefaults, ImagePluginOutput,
  imagePluginStraightAlpha } from './ImageProcessingPlugins'
import { ImageRuleSnapshot, BannerFilterMode, ImageProcessingHint } from './ImageBannerRules'
import { connectImageRuleState } from '../state/ImageRuleState'

interface ProcessedPluginBytes { bytes: ArrayBuffer; extension: string }

export function imagePluginPlans(snapshot: ImageRuleSnapshot, policy: BannerFilterMode,
  hint?: ImageProcessingHint): ImagePluginPlan[] {
  if (policy === 'off') return []
  const seen: Set<string> = new Set()
  const plans: ImagePluginPlan[] = []
  for (const record of snapshot.records) for (const plugin of record.plugins ?? []) {
    const sourceApplies = hint !== undefined &&
      plugin.application.sourceHints.some((value): boolean => value.kind === hint.kind && value.modes.includes(hint.mode))
    if (!plugin.application.automatic && !sourceApplies) continue
    // Applicability belongs to the plugin, not another user-selected mode.
    // Keep the existing WASM context contract for hint-only processors.
    const context: ImagePluginContext = { application: plugin.application.automatic ? 'auto' : 'source', sourceHint: hint }
    const configuration: ImagePluginConfiguration = { parameters: plugin.parameters,
      settings: imagePluginDefaults(plugin, record.pluginSettings?.[plugin.id]), context }
    const identity = JSON.stringify([plugin.processor.sha256, configuration, plugin.output])
    if (seen.has(identity)) continue
    seen.add(identity)
    plans.push({ plugin, configuration, key: JSON.stringify([record.origin, plugin.id, plugin.id]),
      revision: JSON.stringify([record.origin, plugin.id, plugin.version, record.revision]) })
  }
  return plans
}

@Concurrent
async function processImagePlugins(path: string, plansJson: string, expectedHash: string): Promise<ProcessedPluginBytes> {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
  let original: ArrayBuffer
  try {
    original = new ArrayBuffer(fs.statSync(file.fd).size)
    if (fs.readSync(file.fd, original) !== original.byteLength) throw new Error('image_plugin_source_incomplete')
  } finally { fs.closeSync(file) }
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new Uint8Array(original) })
  const actual = Array.from(digest.digestSync().data).map((v: number): string => v.toString(16).padStart(2, '0')).join('')
  if (actual !== expectedHash) throw new Error('image_plugin_source_replaced')
  const source = image.createImageSource(original)
  let decoded: image.PixelMap | undefined = undefined
  let output: image.PixelMap | undefined = undefined
  let packer: image.ImagePacker | undefined = undefined
  try {
    const originalInfo = await source.getImageInfo()
    if (originalInfo.size.width * originalInfo.size.height * 4 > 256 * 1024 * 1024) throw new Error('image_plugin_image_size')
    decoded = await source.createPixelMap({ editable: false, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
    const info = await decoded.getImageInfo()
    let width = info.size.width, height = info.size.height
    let pixels = new ArrayBuffer(width * height * 4)
    // Unlike readPixelsToArea (BGRA), full-buffer reads retain this map's RGBA format.
    await decoded.readPixelsToBuffer(pixels)
    if (info.alphaType === image.AlphaType.PREMUL) imagePluginStraightAlpha(new Uint8Array(pixels))
    await decoded.release(); decoded = undefined
    let changed = false
    let encoding: ImagePluginOutput = { format: 'image/png', quality: 100 }
    for (const plan of JSON.parse(plansJson) as ImagePluginPlan[]) {
      const module = new util.Base64Helper().decodeSync(plan.plugin.processor.moduleBase64 ?? '')
      const moduleDigest = cryptoFramework.createMd('SHA256')
      moduleDigest.updateSync({ data: module })
      const moduleHash = Array.from(moduleDigest.digestSync().data).map((v: number): string => v.toString(16).padStart(2, '0')).join('')
      if (moduleHash !== plan.plugin.processor.sha256) throw new Error('image_plugin_module_changed')
      const result = imagePluginNative.runImageProcessor(module, pixels, width, height, JSON.stringify(plan.configuration))
      if (!result.ok) throw new Error('image_plugin_' + result.reason)
      if (!result.changed) continue
      pixels = result.pixels; width = result.width; height = result.height
      changed = true
      encoding = plan.plugin.output ?? { format: 'image/png', quality: 100 }
    }
    if (!changed) return { bytes: new ArrayBuffer(0), extension: '' }
    output = await image.createPixelMap(pixels, { size: { width, height }, pixelFormat: image.PixelMapFormat.RGBA_8888,
      srcPixelFormat: image.PixelMapFormat.RGBA_8888, alphaType: image.AlphaType.UNPREMUL, editable: false })
    packer = image.createImagePacker()
    return { bytes: await packer.packing(output, { format: encoding.format, quality: encoding.quality }),
      extension: encoding.format === 'image/jpeg' ? 'jpg' : encoding.format === 'image/webp' ? 'webp' : 'png' }
  } finally {
    if (packer !== undefined) await packer.release()
    if (output !== undefined) await output.release()
    if (decoded !== undefined) await decoded.release()
    await source.release()
  }
}

/** Algorithms are downloaded WASM. The host owns decoding, encoding, immutable
 * input identity and the existing managed cache, independently of algorithm type. */
export class ImagePluginService {
  private static inFlight: Map<string, Promise<string>> = new Map()
  private static transforms: Map<string, Promise<string | undefined>> = new Map()
  private static active: number = 0
  private static waiters: Array<() => void> = []
  private static report(plans: ImagePluginPlan[], failed: boolean): void {
    const state = connectImageRuleState()
    const failures: Record<string, string> = {}
    const keys = plans.map((plan: ImagePluginPlan): string => plan.key ?? JSON.stringify([plan.plugin.processor.sha256, plan.plugin.id, plan.plugin.id]))
    for (const key of Object.keys(state.processingFailures)) if (!keys.includes(key)) failures[key] = state.processingFailures[key]
    for (const plan of plans) {
      const key = plan.key ?? JSON.stringify([plan.plugin.processor.sha256, plan.plugin.id, plan.plugin.id])
      if (failed) failures[key] = 'processing_failed'
    }
    state.processingFailures = failures
  }
  static prepare(path: string, plans: ImagePluginPlan[], cache: RemoteImageCacheStore): Promise<string> {
    if (plans.length === 0) return Promise.resolve(path)
    const plansJson = JSON.stringify(plans)
    const pendingKey = JSON.stringify([path, ImagePluginService.identity(plans)])
    const pending = ImagePluginService.inFlight.get(pendingKey)
    if (pending) return pending
    const request = ImagePluginService.process(path, plans, plansJson, cache)
    ImagePluginService.inFlight.set(pendingKey, request)
    const retire = (): void => { if (ImagePluginService.inFlight.get(pendingKey) === request) ImagePluginService.inFlight.delete(pendingKey) }
    void request.then(retire, retire)
    return request
  }
  private static identity(plans: ImagePluginPlan[]): string {
    // Catalog names, revisions and unrelated plugins do not change processed pixels.
    return JSON.stringify(plans.map((plan: ImagePluginPlan): string =>
      JSON.stringify([plan.plugin.processor.abi, plan.plugin.processor.sha256, plan.plugin.output, plan.configuration])))
  }
  private static async process(path: string, plans: ImagePluginPlan[], plansJson: string, cache: RemoteImageCacheStore): Promise<string> {
    try {
      const content = await taskpool.execute<[string], string>(imageFileContentHash, path)
      const key = JSON.stringify(['koma-image-v1', content, ImagePluginService.identity(plans)])
      let pending = ImagePluginService.transforms.get(key)
      if (pending === undefined) {
        pending = ImagePluginService.transform(path, plansJson, content, key, cache)
        ImagePluginService.transforms.set(key, pending)
        const current = pending
        const retire = (): void => { if (ImagePluginService.transforms.get(key) === current) ImagePluginService.transforms.delete(key) }
        void pending.then(retire, retire)
      }
      const result = await pending
      ImagePluginService.report(plans, false)
      return await taskpool.execute<[string], string>(imageFileContentHash, path) === content ? (result ?? path) : path
    } catch (_error) {
      ImagePluginService.report(plans, true)
      console.warn('[ImagePlugin] processing_failed')
      return path
    }
  }
  private static async transform(path: string, plansJson: string, content: string, key: string,
    cache: RemoteImageCacheStore): Promise<string | undefined> {
    for (const extension of ['jpg', 'png', 'webp']) {
      const cached = await cache.get('image-plugin.' + extension, undefined, key)
      if (cached) return cached
    }
    if (await cache.get('image-plugin.nohit', undefined, key + ':nohit')) return undefined
    // Queue before TaskPool: native-slot waiters must not occupy every common
    // worker and delay source HTTP or other foreground work.
    if (ImagePluginService.active >= 2) await new Promise<void>((resolve) => { ImagePluginService.waiters.push(resolve) })
    else ImagePluginService.active += 1
    let result: ProcessedPluginBytes
    try {
      result = await taskpool.execute<[string, string, string], ProcessedPluginBytes>(processImagePlugins, path, plansJson, content)
    } finally {
      const next = ImagePluginService.waiters.shift()
      if (next) next()
      else ImagePluginService.active -= 1
    }
    if (result.bytes.byteLength === 0) {
      await cache.put('image-plugin.nohit', undefined, new Uint8Array([1]).buffer as ArrayBuffer, key + ':nohit')
      return undefined
    }
    return await cache.put('image-plugin.' + result.extension, undefined, result.bytes, key)
  }
}
