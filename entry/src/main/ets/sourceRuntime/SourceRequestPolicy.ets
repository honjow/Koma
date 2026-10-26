import { url } from '@kit.ArkTS'

const MANHUAGUI: string = 'com.manhuagui.koma'
let mainPermits: number = 10
let imagePermits: number = 4

class SourceRequestWindow {
  starts: number[] = []
  tail: Promise<void> = Promise.resolve()
}

const mainWindow: SourceRequestWindow = new SourceRequestWindow()
const imageWindow: SourceRequestWindow = new SourceRequestWindow()

function permits(value: Object | undefined, fallback: number): number {
  const parsed: number = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : fallback
  return Number.isInteger(parsed) && parsed >= 1 && parsed <= 10 ? parsed : fallback
}

/** Publish the request's existing settings snapshot; the HTTP/image hot paths never read preferences. */
export function configureSourceRequestPolicy(sourceId: string, settings: Object | null | undefined): void {
  if (sourceId !== MANHUAGUI) return
  const values: Record<string, Object> = settings !== undefined && settings !== null &&
    typeof settings === 'object' && !Array.isArray(settings) ? settings as Record<string, Object> : {}
  mainPermits = permits(values['mainSiteRatelimitPreference'], 10)
  imagePermits = permits(values['imgCDNRatelimitPreference'], 4)
}

/** Keiyoushi's rules share one sliding window for the entire matched CDN set.
 * Metadata, covers and Reader cache misses must use this same owner; a per-image-host queue
 * would multiply the allowance. Unrelated sources/hosts and cache hits do not wait.
 */
export async function waitForSourceRequestSlot(sourceId: string, requestUrl: string,
  isCurrent: () => boolean = (): boolean => true): Promise<void> {
  if (sourceId !== MANHUAGUI) return
  let host: string
  try { host = new url.URL(requestUrl).hostname.toLowerCase() } catch (_error) { return }
  const main: boolean = host === 'www.manhuagui.com'
  const image: boolean = host === 'i.hamreus.com' || host === 'cf.hamreus.com'
  if (!main && !image) return
  const window: SourceRequestWindow = main ? mainWindow : imageWindow
  const period: number = main ? 10000 : 1000
  const previous: Promise<void> = window.tail
  let release: () => void = () => {}
  window.tail = new Promise<void>((resolve) => { release = resolve })
  try {
    await previous
    while (true) {
      if (!isCurrent()) throw new Error('source_request_cancelled')
      const now: number = Date.now()
      window.starts = window.starts.filter((started: number): boolean => now - started < period)
      const limit: number = main ? mainPermits : imagePermits
      if (window.starts.length < limit) {
        window.starts.push(now)
        return
      }
      await new Promise<void>((resolve) => {
        setTimeout(resolve, Math.max(1, window.starts[0] + period - now))
      })
    }
  } finally { release() }
}
