import { url } from '@kit.ArkTS'

const MANHUAGUI: string = 'com.manhuagui.koma'
const BUONDUA: string = 'com.buondua.koma'
const JMCOMIC: string = 'com.jmcomic.koma'
const HENTAICLUB: string = 'com.hentaiclub.koma'
const WNACG: string = 'com.wnacg.koma'
let mainPermits: number = 10
let imagePermits: number = 4

class SourceRequestWindow {
  starts: number[] = []
  tail: Promise<void> = Promise.resolve()
}

const requestWindows: Map<string, SourceRequestWindow> = new Map()

/** One transport call keeps this object through its redirect hops. */
export interface SourceRequestAdmission { wnacgAdmitted?: boolean; jmAdmitted?: boolean }

function sourceRequestWindow(sourceId: string, group: string): SourceRequestWindow {
  const key = JSON.stringify([sourceId, group])
  let window = requestWindows.get(key)
  if (window === undefined) {
    window = new SourceRequestWindow()
    requestWindows.set(key, window)
  }
  return window
}

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
 * would multiply the allowance. BuonDua only limits its exact main host, 10 requests per second.
 * Separate source/group windows keep unrelated sources/hosts and cache hits from waiting.
 */
export async function waitForSourceRequestSlot(sourceId: string, requestUrl: string,
  isCurrent: () => boolean = (): boolean => true,
  headers?: Object | string | number | boolean | null, admission?: SourceRequestAdmission): Promise<void> {
  if (sourceId !== MANHUAGUI && sourceId !== BUONDUA && sourceId !== JMCOMIC && sourceId !== HENTAICLUB &&
    sourceId !== WNACG) return
  let host: string
  let origin: string
  try {
    const parsed = new url.URL(requestUrl)
    host = parsed.hostname.toLowerCase()
    origin = parsed.origin
  } catch (_error) { return }
  const main: boolean = sourceId === MANHUAGUI && host === 'www.manhuagui.com'
  const image: boolean = sourceId === MANHUAGUI && (host === 'i.hamreus.com' || host === 'cf.hamreus.com')
  const buondua: boolean = sourceId === BUONDUA && host === 'buondua.com'
  // The reference matches this hostname, including same-host images and all ports.
  const hentaiclub: boolean = sourceId === HENTAICLUB && host === 'www.hentaiclub.net'
  // All reference-matching mirrors share one window; one HTTP call is charged at most once.
  const wnacg: boolean = sourceId === WNACG && /^(?:www\.)?wn(?:acg\w*|\d+)\./.test(host)
  if (wnacg && admission?.wnacgAdmitted === true) return
  const rawHeaders: Record<string, Object> = headers !== undefined && headers !== null &&
    typeof headers === 'object' && !Array.isArray(headers) ? headers as Record<string, Object> : {}
  let token: boolean = false
  let tokenParam: boolean = false
  for (const key of Object.keys(rawHeaders)) {
    const value = rawHeaders[key]
    if (typeof value !== 'string' || value.length === 0) continue
    if (key.toLowerCase() === 'token') token = true
    if (key.toLowerCase() === 'tokenparam') tokenParam = true
  }
  // JM selects its API origin dynamically. Its signed API calls share a
  // three-per-two-second origin window; server-list and CDN lack these headers.
  const jm: boolean = sourceId === JMCOMIC && origin.startsWith('https://') && token && tokenParam
  if (jm && admission?.jmAdmitted === true) return
  if (!main && !image && !buondua && !jm && !hentaiclub && !wnacg) return
  const window = sourceRequestWindow(sourceId, jm ? origin : image ? 'image' : 'main')
  const period: number = wnacg ? 60000 : jm ? 2000 : main ? 10000 : 1000
  const previous: Promise<void> = window.tail
  let release: () => void = () => {}
  window.tail = new Promise<void>((resolve) => { release = resolve })
  try {
    await previous
    while (true) {
      if (!isCurrent()) throw new Error('source_request_cancelled')
      const now: number = Date.now()
      window.starts = window.starts.filter((started: number): boolean => now - started < period)
      const limit: number = wnacg ? 50 : jm ? 3 : hentaiclub ? 2 : buondua ? 10 : main ? mainPermits : imagePermits
      if (window.starts.length < limit) {
        window.starts.push(now)
        if (wnacg && admission !== undefined) admission.wnacgAdmitted = true
        if (jm && admission !== undefined) admission.jmAdmitted = true
        return
      }
      await new Promise<void>((resolve) => {
        setTimeout(resolve, Math.max(1, window.starts[0] + period - now))
      })
    }
  } finally { release() }
}
