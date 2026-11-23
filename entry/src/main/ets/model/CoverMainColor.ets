import { effectKit } from '@kit.ArkGraphics2D'
import { image } from '@kit.ImageKit'
import { taskpool } from '@kit.ArkTS'
import { CoverPixelMapLease, coverPixelMapMemoryCache } from './CoverPixelMapMemoryCache'
import { scoreCoverPalettePixels } from './CoverPaletteWorker'

@ObservedV2
class CoverMainColors {
  @Trace colors: Map<string, string> = new Map<string, string>()
}

const mainColors: CoverMainColors = new CoverMainColors()
const tokens: Map<string, number> = new Map<string, number>()
const pending: Map<string, Promise<void>> = new Map<string, Promise<void>>()
const MAX_COLORS: number = 512

export function coverMainColor(key: string, fallback: ResourceColor): ResourceColor {
  return mainColors.colors.get(key) || fallback
}

function channelHex(channel: number): string {
  return Math.max(0, Math.min(255, Math.round(channel))).toString(16).padStart(2, '0')
}

// Main color is a display-only derivative of the decoded cover, never a new
// network request or a change to the stored artwork. Keep the original color
// as fallback, and retain 50% opacity/blur in LibraryUnreadBadge.
export function cacheCoverMainColor(key: string, lease: CoverPixelMapLease): Promise<void> {
  const requestKey = `${key}::${lease.entryToken}`
  const inFlight = pending.get(requestKey)
  if (inFlight !== undefined) return inFlight
  if (tokens.get(key) === lease.entryToken) return Promise.resolve()

  // Async native extraction needs its own lease: a recycled row or cache clear
  // must not release the bitmap while ColorPicker is still reading it.
  const retained = coverPixelMapMemoryCache.acquire(lease.key)
  if (retained === undefined) return Promise.resolve()
  if (retained.entryToken !== lease.entryToken) return coverPixelMapMemoryCache.release(retained)
  tokens.set(key, lease.entryToken)
  while (tokens.size > MAX_COLORS) {
    const oldest: string = tokens.keys().next().value
    tokens.delete(oldest)
    mainColors.colors.delete(oldest)
  }
  const loading = extractMainColor(key, retained).finally(() => { pending.delete(requestKey) })
  pending.set(requestKey, loading)
  return loading
}

async function extractMainColor(key: string, lease: CoverPixelMapLease): Promise<void> {
  try {
    const picker = await effectKit.createColorPicker(lease.pixelMap)
    const swatches: number[] = []
    for (const color of picker.getTopProportionColors(16)) {
      if (color !== null) swatches.push((Math.round(color.red) << 16) | (Math.round(color.green) << 8) | Math.round(color.blue))
    }
    if (swatches.length === 0) return
    const info = lease.pixelMap.getImageInfoSync()
    if (info.pixelFormat !== image.PixelMapFormat.RGBA_8888 && info.pixelFormat !== image.PixelMapFormat.BGRA_8888) return
    const bytes = new ArrayBuffer(lease.pixelMap.getPixelBytesNumber())
    await lease.pixelMap.readPixelsToBuffer(bytes)
    const selected = await taskpool.execute(scoreCoverPalettePixels, bytes, info.size.width, info.size.height,
      swatches, info.pixelFormat === image.PixelMapFormat.BGRA_8888) as number
    if (tokens.get(key) === lease.entryToken && selected >= 0) {
      mainColors.colors.set(key, `#${channelHex((selected >>> 16) & 255)}${channelHex((selected >>> 8) & 255)}${channelHex(selected & 255)}`)
    }
  } catch (_) {
    // Extraction is optional. Keep the cover and original badge color usable.
  } finally {
    await coverPixelMapMemoryCache.release(lease)
  }
}
