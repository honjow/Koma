import { webview } from '@kit.ArkWeb'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { sourceWebOrigin } from './SourceWebSessionStore'

export interface SourceWebFetchResult {
  status: number
  body: string
}

export interface SourceWebHttpRequest {
  url: string
  method: string
  headers: Record<string, string>
  body?: string
  timeoutMs?: number
}

/** Unavailable is the only state that permits another transport to send. */
export interface SourceWebHttpResult {
  attempted: boolean
  status?: number
  body?: string
  headers?: Record<string, string[]>
  error?: string
}

interface ActiveWebFetch {
  controller: webview.WebviewController
  id: string
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
  private active: Map<string, ActiveWebFetch> = new Map<string, ActiveWebFetch>()

  private runScript(controller: webview.WebviewController, script: string, deadline: number,
    current: () => boolean): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void): void => {
      let finished = false
      const timer = setInterval((): void => {
        if (!finished && (!current() || Date.now() >= deadline)) {
          finished = true
          clearInterval(timer)
          reject(new Error(current() ? 'timeout' : 'source_request_cancelled'))
        }
      }, 50)
      try {
        controller.runJavaScript(script).then((value: string): void => {
          if (finished) return
          finished = true
          clearInterval(timer)
          resolve(value)
        }, (): void => {
          if (finished) return
          finished = true
          clearInterval(timer)
          reject(new Error('network_error'))
        })
      } catch (_error) {
        finished = true
        clearInterval(timer)
        reject(new Error('network_error'))
      }
    })
  }

  private async retire(call: ActiveWebFetch): Promise<void> {
    this.active.delete(call.id)
    try {
      await this.runScript(call.controller, "(() => { const id = " + JSON.stringify(call.id) +
        "; const job = window.__komaFetchJobs && window.__komaFetchJobs[id]; if (job) job.abort(); " +
        "if (window.__komaFetch) delete window.__komaFetch[id]; return ''; })()", Date.now() + 1000, (): boolean => true)
    } catch (_error) { /* A destroyed document has no live fetch mailbox. */ }
  }

  private retireAll(): void {
    this.active.forEach((call: ActiveWebFetch): void => { this.retire(call) })
    this.active.clear()
  }

  attach(controller: webview.WebviewController, sourceId: string, url: string, userAgent: string,
    authorizationRevision: number): void {
    this.retireAll()
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
    this.retireAll()
    this.ready = false
    this.contextRevision += 1
  }

  detach(sourceId: string): void {
    if (this.sourceId !== sourceId) return
    this.retireAll()
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
  async prepare(sourceId: string, url: string, userAgent: string, authorizationRevision: number,
    current: () => boolean = (): boolean => true, timeoutMs: number = WEB_FETCH_PREPARE_TIMEOUT_MS): Promise<boolean> {
    if (!current()) return false
    if (this.availableFor(sourceId, url, userAgent, authorizationRevision)) return true
    requestSourceWebFetchBridgeHost(sourceId, url)
    const deadline = Date.now() + Math.min(timeoutMs, WEB_FETCH_PREPARE_TIMEOUT_MS)
    while (Date.now() < deadline) {
      await this.delay(WEB_FETCH_POLL_MS)
      if (!current()) return false
      if (this.availableFor(sourceId, url, userAgent, authorizationRevision)) return true
    }
    DiagnosticLogger.info('source_web_fetch', 'prepare_timeout', 'source=' + sourceId)
    return false
  }

  async fetch(sourceId: string, url: string, userAgent: string,
    authorizationRevision: number): Promise<SourceWebFetchResult | undefined> {
    const result = await this.perform(sourceId, { url, method: 'GET', headers: {} }, userAgent,
      authorizationRevision, (): boolean => true, true)
    if (result.status === undefined || result.error !== undefined || !result.body || this.isChallenge(result.body)) return undefined
    return { status: result.status, body: result.body }
  }

  async request(sourceId: string, request: SourceWebHttpRequest, userAgent: string,
    authorizationRevision: number, operationCurrent: () => boolean): Promise<SourceWebHttpResult> {
    return this.perform(sourceId, request, userAgent, authorizationRevision, operationCurrent, false)
  }

  private async perform(sourceId: string, request: SourceWebHttpRequest, userAgent: string,
    authorizationRevision: number, operationCurrent: () => boolean, legacy: boolean): Promise<SourceWebHttpResult> {
    const controller = this.controller
    if (controller === undefined || !operationCurrent() ||
      !this.availableFor(sourceId, request.url, userAgent, authorizationRevision)) return { attempted: false }
    if (!['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method) ||
      (['GET', 'HEAD'].includes(request.method) && (request.body?.length ?? 0) > 0)) {
      return { attempted: false, error: 'invalid_request' }
    }
    const headers: Record<string, string> = {}
    let referrer: string | undefined = undefined
    for (const name of Object.keys(request.headers)) {
      if (!legacy && name.toLowerCase() === 'referer') {
        // Fetch owns Referer. Preserve a source's same-origin public referer
        // through RequestInit instead of silently using the hidden document.
        if (/[\u0000-\u001f\u007f]/.test(request.headers[name]) || sourceWebOrigin(request.headers[name]) !== this.origin) {
          return { attempted: false, error: 'invalid_request' }
        }
        referrer = request.headers[name]
        continue
      }
      // The browser generates credential/origin/connection headers. A source
      // cannot impersonate the granted UA or smuggle forbidden fetch headers.
      if (/^(?:proxy-|sec-)/i.test(name) || ['accept-charset', 'accept-encoding', 'access-control-request-headers',
        'access-control-request-method', 'connection', 'content-length', 'cookie', 'cookie2', 'date', 'dnt',
        'expect', 'host', 'keep-alive', 'origin', 'referer', 'te', 'trailer', 'transfer-encoding', 'upgrade',
        'via', 'user-agent', 'set-cookie', 'x-http-method', 'x-http-method-override', 'x-method-override'].includes(name.toLowerCase())) continue
      if (['__proto__', 'constructor', 'prototype'].includes(name.toLowerCase()) ||
        !/^[a-zA-Z0-9!#$%&'*+.^_`|~-]+$/.test(name) || /[\u0000-\u001f\u007f]/.test(request.headers[name])) {
        return { attempted: false, error: 'invalid_request' }
      }
      headers[name] = request.headers[name]
    }
    const revision = this.contextRevision
    const current = (): boolean => operationCurrent() && revision === this.contextRevision && this.controller === controller &&
      this.availableFor(sourceId, request.url, userAgent, authorizationRevision)
    this.sequence += 1
    const id = 'koma-' + this.sequence
    const call: ActiveWebFetch = { controller, id }
    this.active.set(id, call)
    const timeoutMs = Math.max(1, request.timeoutMs ?? WEB_FETCH_TIMEOUT_MS)
    const deadline = Date.now() + timeoutMs
    try {
      // The closure's live flag is cleared BEFORE abort/delete. Even a fetch
      // implementation that resolves after abort cannot resurrect its mailbox.
      // New HTTP requests reject redirects, including same-origin redirects:
      // browsers hide manual Location, so guessing/reposting is unsafe.
      const script = "(() => { const id = " + JSON.stringify(id) + ", url = " + JSON.stringify(request.url) +
        "; if (typeof AbortController !== 'function') return 'unavailable'; " +
        (legacy ? '' : "if (location.origin !== " + JSON.stringify(this.origin) +
          " || new URL(url).origin !== location.origin) return 'unavailable'; ") +
        "const jobs = window.__komaFetchJobs || (window.__komaFetchJobs = Object.create(null)); " +
        "const box = window.__komaFetch || (window.__komaFetch = Object.create(null)); " +
        "const abort = new AbortController(); let live = true, completed = false, timer; " +
        "const job = { abort: () => { live = false; clearTimeout(timer); abort.abort(); delete jobs[id]; delete box[id]; } }; jobs[id] = job; " +
        "const done = value => { if (live && !completed && jobs[id] === job) { completed = true; clearTimeout(timer); box[id] = JSON.stringify(value); } }; " +
        "timer = setTimeout(() => { done({error:'timeout'}); abort.abort(); }, " + timeoutMs + "); " +
        "const options = { method: " + JSON.stringify(request.method) + ", headers: " + JSON.stringify(headers) +
        ", credentials: 'include', signal: abort.signal" + (legacy ? '' : ", mode: 'same-origin', redirect: 'error', cache: 'no-store'") +
        (referrer === undefined ? '' : ", referrer: " + JSON.stringify(referrer) + ", referrerPolicy: 'same-origin'") +
        (request.body === undefined || ['GET', 'HEAD'].includes(request.method) ? '' : ", body: " + JSON.stringify(request.body)) + " }; " +
        "(async () => { try { " +
        "if (options.body && new TextEncoder().encode(options.body).byteLength > 1048576) { done({attempted:false,error:'request_too_large'}); return; } " +
        "const r = await fetch(url, options); const headers = Object.create(null); let size = 0; " +
        (legacy ? '' : "if (r.headers) r.headers.forEach((v,k) => { if (!['set-cookie','set-cookie2'].includes(k.toLowerCase())) { size += new TextEncoder().encode(k+v).byteLength; headers[k] = [v]; } }); ") +
        "if (size > 65536) { done({error:'response_headers_too_large'}); return; } " +
        (legacy ? "const text = await r.text(); " :
        "let text = ''; if (r.body && r.body.getReader) { const reader = r.body.getReader(); const decoder = new TextDecoder(); let count = 0; " +
        "while (live) { const part = await reader.read(); if (part.done) break; count += part.value.byteLength; " +
        "if (count > 4194304) { await reader.cancel(); done({error:'response_too_large'}); return; } text += decoder.decode(part.value,{stream:true}); } text += decoder.decode(); " +
        "} else { text = await r.text(); if (new TextEncoder().encode(text).byteLength > 4194304) { done({error:'response_too_large'}); return; } } ") +
        "done({status:r.status, headers, body:text}); } catch(e) { done({error:'network_error'}); } })(); return 'started'; })()"
      const started = this.decode(await this.runScript(controller, script, deadline, current))
      if (!current()) return { attempted: true, error: 'source_request_cancelled' }
      if (started === 'unavailable') return { attempted: false }
      if (started !== 'started') return { attempted: true, error: 'network_error' }
      while (Date.now() < deadline) {
        await this.delay(WEB_FETCH_POLL_MS)
        if (!current()) return { attempted: true, error: 'source_request_cancelled' }
        const raw = this.decode(await this.runScript(controller,
          "(() => { const value = (window.__komaFetch && window.__komaFetch[" + JSON.stringify(id) +
          "]) || ''; if (value) delete window.__komaFetch[" + JSON.stringify(id) + "]; return value; })()", deadline, current))
        if (!current()) return { attempted: true, error: 'source_request_cancelled' }
        if (raw.length === 0) continue
        const parsed = JSON.parse(raw) as Record<string, Object>
        const status = typeof parsed['status'] === 'number' ? parsed['status'] as number : -1
        const body = typeof parsed['body'] === 'string' ? parsed['body'] as string : ''
        const error = typeof parsed['error'] === 'string' ? parsed['error'] as string : undefined
        if (error !== undefined || status < 100 || status > 599) return { attempted: parsed['attempted'] !== false, error: error ?? 'network_error' }
        const visibleHeaders = parsed['headers'] as Record<string, string[]>
        return { attempted: true, status, body, headers: visibleHeaders }
      }
      DiagnosticLogger.info('source_web_fetch', 'timeout', 'source=' + sourceId)
      return { attempted: true, error: 'timeout' }
    } catch (error) {
      // JS submission errors are ambiguous: it may already have called fetch.
      const reason = error instanceof Error && ['timeout', 'source_request_cancelled'].includes(error.message)
        ? error.message : 'network_error'
      return { attempted: true, error: reason }
    } finally {
      await this.retire(call)
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
