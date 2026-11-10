import { webview } from '@kit.ArkWeb'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export interface SourceWebFetchResult {
  status: number
  body: string
}

const WEB_FETCH_TIMEOUT_MS: number = 20000
const WEB_FETCH_POLL_MS: number = 200
const WEB_FETCH_PREPARE_TIMEOUT_MS: number = 20000

/**
 * AppStorage key for the one application-scoped hidden WebView. The bridge
 * cannot own a component, so a page-level host listens to this request and
 * loads the granted session URL. Keeping the host outside SourceBrowsePage is
 * what lets history and shelf entries read a bridged source after the browse
 * page is gone.
 */
export const SOURCE_WEB_FETCH_BRIDGE_REQUEST_KEY: string = 'source_web_fetch_bridge_request'

export function requestSourceWebFetchBridgeHost(sourceId: string, url: string): void {
  if (sourceId.length === 0 || url.length === 0) return
  AppStorage.setOrCreate(SOURCE_WEB_FETCH_BRIDGE_REQUEST_KEY,
    JSON.stringify({ sourceId, url, revision: Date.now() }))
}

/**
 * Host-owned bridge for sources whose native transport is rejected by a site but whose
 * granted WebView session can still read same-origin documents. The controller stays on a
 * persistent page; the source only ever receives status and body text.
 */
export class SourceWebFetchBridge {
  private controller?: webview.WebviewController
  private sourceId: string = ''
  private ready: boolean = false
  private sequence: number = 0

  attach(controller: webview.WebviewController, sourceId: string): void {
    this.controller = controller
    this.sourceId = sourceId
    this.ready = false
  }

  markReady(sourceId: string): void {
    if (this.sourceId === sourceId && this.controller !== undefined) this.ready = true
  }

  detach(sourceId: string): void {
    if (this.sourceId !== sourceId) return
    this.controller = undefined
    this.sourceId = ''
    this.ready = false
  }

  availableFor(sourceId: string): boolean {
    return this.controller !== undefined && this.sourceId === sourceId && this.ready
  }

  /**
   * Ask the application-scoped host to open the session page, then wait until
   * that WebView reports its main document. A caller that already has a ready
   * bridge returns immediately; a missing grant still fails closed on timeout.
   */
  async prepare(sourceId: string, url: string): Promise<boolean> {
    if (this.availableFor(sourceId)) return true
    requestSourceWebFetchBridgeHost(sourceId, url)
    const deadline = Date.now() + WEB_FETCH_PREPARE_TIMEOUT_MS
    while (Date.now() < deadline) {
      await this.delay(WEB_FETCH_POLL_MS)
      if (this.availableFor(sourceId)) return true
    }
    DiagnosticLogger.info('source_web_fetch', 'prepare_timeout', 'source=' + sourceId)
    return false
  }

  async fetch(sourceId: string, url: string): Promise<SourceWebFetchResult | undefined> {
    const controller = this.controller
    if (controller === undefined || this.sourceId !== sourceId || !this.ready) return undefined
    this.sequence += 1
    const id = 'koma-' + this.sequence
    try {
      const script = "(() => { try { fetch(" + JSON.stringify(url) +
        ", { credentials: 'include' }).then(async (r) => { const t = await r.text(); window.__komaFetch = window.__komaFetch || {}; window.__komaFetch[" +
        JSON.stringify(id) + "] = JSON.stringify({ status: r.status, body: t }); }).catch(() => { window.__komaFetch = window.__komaFetch || {}; window.__komaFetch[" +
        JSON.stringify(id) + "] = JSON.stringify({ status: -1, body: '' }); }); return 'started'; } catch (e) { return 'error'; } })()"
      const started = this.decode(await controller.runJavaScript(script))
      if (started !== 'started') return undefined
      const deadline = Date.now() + WEB_FETCH_TIMEOUT_MS
      while (Date.now() < deadline) {
        await this.delay(WEB_FETCH_POLL_MS)
        const raw = this.decode(await controller.runJavaScript(
          "(window.__komaFetch && window.__komaFetch[" + JSON.stringify(id) + "]) || ''"))
        if (raw.length === 0) continue
        const parsed = JSON.parse(raw) as Record<string, Object>
        const status = typeof parsed['status'] === 'number' ? parsed['status'] as number : -1
        const body = typeof parsed['body'] === 'string' ? parsed['body'] as string : ''
        if (status < 0 || body.length === 0) return undefined
        return { status, body }
      }
      DiagnosticLogger.info('source_web_fetch', 'timeout', 'source=' + sourceId)
      return undefined
    } catch (_error) {
      return undefined
    }
  }

  private decode(raw: string): string {
    if (!raw.startsWith('"')) return raw
    try { return JSON.parse(raw) as string } catch (_error) { return raw }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void): void => {
      setTimeout((): void => { resolve() }, milliseconds)
    })
  }
}

export const sourceWebFetchBridge: SourceWebFetchBridge = new SourceWebFetchBridge()
