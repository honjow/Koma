import { webview } from '@kit.ArkWeb'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { sourceWebOrigin } from './SourceWebSessionStore'

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
  private origin: string = ''
  private userAgent: string = ''
  private contextRevision: number = 0
  private authorizationRevision: number = 0

  attach(controller: webview.WebviewController, sourceId: string, url: string, userAgent: string,
    authorizationRevision: number): void {
    this.contextRevision += 1
    this.controller = controller
    this.sourceId = sourceId
    this.origin = sourceWebOrigin(url)
    this.userAgent = userAgent
    this.authorizationRevision = authorizationRevision
    this.ready = false
  }

  markReady(sourceId: string, documentUrl: string, userAgent: string, authorizationRevision: number): void {
    if (this.sourceId === sourceId && this.controller !== undefined && this.origin.length > 0 &&
      sourceWebOrigin(documentUrl) === this.origin && userAgent.length > 0 && userAgent === this.userAgent &&
      authorizationRevision > 0 && authorizationRevision === this.authorizationRevision) this.ready = true
  }

  markLoading(sourceId: string): void {
    if (this.sourceId !== sourceId) return
    this.ready = false
    this.contextRevision += 1
  }

  detach(sourceId: string): void {
    if (this.sourceId !== sourceId) return
    this.controller = undefined
    this.sourceId = ''
    this.origin = ''
    this.userAgent = ''
    this.authorizationRevision = 0
    this.ready = false
    this.contextRevision += 1
  }

  availableFor(sourceId: string, url: string, userAgent: string, authorizationRevision: number): boolean {
    return this.controller !== undefined && this.sourceId === sourceId && this.ready &&
      this.origin.length > 0 && sourceWebOrigin(url) === this.origin &&
      userAgent.length > 0 && userAgent === this.userAgent && authorizationRevision > 0 &&
      authorizationRevision === this.authorizationRevision
  }

  /**
   * Ask the application-scoped host to open the session page, then wait until
   * that WebView reports its main document. A caller that already has a ready
   * bridge returns immediately; a missing grant still fails closed on timeout.
   */
  async prepare(sourceId: string, url: string, userAgent: string, authorizationRevision: number): Promise<boolean> {
    if (this.availableFor(sourceId, url, userAgent, authorizationRevision)) return true
    requestSourceWebFetchBridgeHost(sourceId, url)
    const deadline = Date.now() + WEB_FETCH_PREPARE_TIMEOUT_MS
    while (Date.now() < deadline) {
      await this.delay(WEB_FETCH_POLL_MS)
      if (this.availableFor(sourceId, url, userAgent, authorizationRevision)) return true
    }
    DiagnosticLogger.info('source_web_fetch', 'prepare_timeout', 'source=' + sourceId)
    return false
  }

  async fetch(sourceId: string, url: string, userAgent: string,
    authorizationRevision: number): Promise<SourceWebFetchResult | undefined> {
    const controller = this.controller
    if (controller === undefined || !this.availableFor(sourceId, url, userAgent, authorizationRevision)) return undefined
    const revision = this.contextRevision
    const current = (): boolean => revision === this.contextRevision && this.controller === controller &&
      this.availableFor(sourceId, url, userAgent, authorizationRevision)
    this.sequence += 1
    const id = 'koma-' + this.sequence
    try {
      const script = "(() => { try { fetch(" + JSON.stringify(url) +
        ", { credentials: 'include' }).then(async (r) => { const t = await r.text(); window.__komaFetch = window.__komaFetch || {}; window.__komaFetch[" +
        JSON.stringify(id) + "] = JSON.stringify({ status: r.status, body: t }); }).catch(() => { window.__komaFetch = window.__komaFetch || {}; window.__komaFetch[" +
        JSON.stringify(id) + "] = JSON.stringify({ status: -1, body: '' }); }); return 'started'; } catch (e) { return 'error'; } })()"
      const started = this.decode(await controller.runJavaScript(script))
      if (!current() || started !== 'started') return undefined
      const deadline = Date.now() + WEB_FETCH_TIMEOUT_MS
      while (Date.now() < deadline) {
        await this.delay(WEB_FETCH_POLL_MS)
        if (!current()) return undefined
        const raw = this.decode(await controller.runJavaScript(
          "(() => { const value = (window.__komaFetch && window.__komaFetch[" + JSON.stringify(id) +
          "]) || ''; if (value) delete window.__komaFetch[" + JSON.stringify(id) + "]; return value; })()"))
        if (!current()) return undefined
        if (raw.length === 0) continue
        const parsed = JSON.parse(raw) as Record<string, Object>
        const status = typeof parsed['status'] === 'number' ? parsed['status'] as number : -1
        const body = typeof parsed['body'] === 'string' ? parsed['body'] as string : ''
        if (status < 0 || body.length === 0 || this.isChallenge(body)) {
          DiagnosticLogger.info('source_web_fetch', 'rejected',
            'status=' + status + ' bytes=' + body.length + ' challenge=' + this.isChallenge(body))
          return undefined
        }
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

  // A hidden page can briefly expose its challenge document before the
  // session settles. Never hand that HTML to a source parser as a 200 read.
  private isChallenge(body: string): boolean {
    const head = body.slice(0, 8192).toLowerCase()
    return head.includes('cf-chl') || head.includes('challenge-platform') ||
      head.includes('just a moment') || head.includes('attention required')
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void): void => {
      setTimeout((): void => { resolve() }, milliseconds)
    })
  }
}

export const sourceWebFetchBridge: SourceWebFetchBridge = new SourceWebFetchBridge()
