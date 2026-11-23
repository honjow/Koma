import { webview } from '@kit.ArkWeb'
import { util } from '@kit.ArkTS'
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
  requestBytes?: ArrayBuffer
  responseKind?: string
  onResponseChunk?: (bytes: ArrayBuffer) => void
  timeoutMs?: number
}

/** Unavailable is the only state that permits another transport to send. */
export interface SourceWebHttpResult {
  attempted: boolean
  status?: number
  body?: string
  bytes?: ArrayBuffer
  headers?: Record<string, string[]>
  error?: string
}

interface ActiveWebFetch {
  controller: webview.WebviewController
  id: string
  deadline: number
}

const WEB_FETCH_TIMEOUT_MS: number = 20000
const WEB_FETCH_POLL_MS: number = 200
export const WEB_FETCH_PREPARE_TIMEOUT_MS: number = 20000

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
 * persistent page. HTTP data is returned through bounded text/byte envelopes or
 * an internal chunk sink; it never grants the source a WebView/script handle.
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
      if (!current() || Date.now() >= deadline) {
        reject(new Error(current() ? 'timeout' : 'source_request_cancelled'))
        return
      }
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
          if (!current() || Date.now() >= deadline) reject(new Error(current() ? 'timeout' : 'source_request_cancelled'))
          else resolve(value)
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
        "; const retired=window.__komaFetchRetired || (window.__komaFetchRetired=Object.create(null)); " +
        "for (const k of Object.keys(retired)) if (retired[k] <= Date.now()) delete retired[k]; " +
        "retired[id]=" + call.deadline + "; " +
        "const job = window.__komaFetchJobs && window.__komaFetchJobs[id]; if (job) job.abort(); " +
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
      (['GET', 'HEAD'].includes(request.method) && ((request.body?.length ?? 0) > 0 || request.requestBytes !== undefined)) ||
      (request.requestBytes !== undefined && ((request.body?.length ?? 0) > 0 || !['POST', 'PUT', 'PATCH'].includes(request.method))) ||
      (request.responseKind !== undefined && !['bodyText', 'bodyBytes', 'bodyRef'].includes(request.responseKind)) ||
      (request.responseKind === 'bodyRef' && request.onResponseChunk === undefined)) {
      return { attempted: false, error: 'invalid_request' }
    }
    if (request.requestBytes !== undefined && request.requestBytes.byteLength > 1048576) {
      return { attempted: false, error: 'request_too_large' }
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
    // TEMP R11 cancellation observation; remove with the R10 Host diagnostics.
    const observed = (result: SourceWebHttpResult): SourceWebHttpResult => {
      try {
        if (result.error === 'source_request_cancelled') DiagnosticLogger.info('source_web_fetch', 'cancel_state',
          'op=' + operationCurrent() + ' rev=' + (revision === this.contextRevision) +
          ' ctl=' + (this.controller === controller) +
          ' avail=' + this.availableFor(sourceId, request.url, userAgent, authorizationRevision) + ' ready=' + this.ready)
      } catch (_error) { /* Observation cannot affect the original result. */ }
      return result
    }
    this.sequence += 1
    const id = 'koma-' + this.sequence
    const timeoutMs = Math.max(1, request.timeoutMs ?? WEB_FETCH_TIMEOUT_MS)
    const deadline = Date.now() + timeoutMs
    const call: ActiveWebFetch = { controller, id, deadline }
    this.active.set(id, call)
    try {
      if (!legacy) return observed(await this.performData(controller, id, request, headers, referrer, timeoutMs, deadline, current))
      // The closure's live flag is cleared BEFORE abort/delete. Even a fetch
      // implementation that resolves after abort cannot resurrect its mailbox.
      // New HTTP requests reject redirects, including same-origin redirects:
      // browsers hide manual Location, so guessing/reposting is unsafe.
      const script = "(() => { const id = " + JSON.stringify(id) + ", url = " + JSON.stringify(request.url) +
        "; if (Date.now() >= " + deadline + " || (window.__komaFetchRetired && window.__komaFetchRetired[id]) || " +
        "typeof AbortController !== 'function') return 'unavailable'; " +
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
      if (!current()) return observed({ attempted: true, error: 'source_request_cancelled' })
      if (started === 'unavailable') return { attempted: false }
      if (started !== 'started') return { attempted: true, error: 'network_error' }
      while (Date.now() < deadline) {
        await this.delay(WEB_FETCH_POLL_MS)
        if (!current()) return observed({ attempted: true, error: 'source_request_cancelled' })
        const raw = this.decode(await this.runScript(controller,
          "(() => { const value = (window.__komaFetch && window.__komaFetch[" + JSON.stringify(id) +
          "]) || ''; if (value) delete window.__komaFetch[" + JSON.stringify(id) + "]; return value; })()", deadline, current))
        if (!current()) return observed({ attempted: true, error: 'source_request_cancelled' })
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
      const reason = error instanceof Error && ['timeout', 'source_request_cancelled', 'body_limit_exceeded',
        'body_write_failed', 'body_unavailable'].includes(error.message)
        ? error.message : 'network_error'
      return observed({ attempted: true, error: reason })
    } finally {
      await this.retire(call)
    }
  }

  /** The browser owns fetch; this bounded mailbox only moves data. Four 64 KiB
   * chunks apply backpressure to its reader. Drain immediately when populated,
   * rather than paying the legacy document polling interval for every chunk.
   */
  private async performData(controller: webview.WebviewController, id: string, request: SourceWebHttpRequest,
    headers: Record<string, string>, referrer: string | undefined, timeoutMs: number, deadline: number,
    current: () => boolean): Promise<SourceWebHttpResult> {
    const kind = request.responseKind ?? 'bodyText'
    const limit = kind === 'bodyRef' ? 134217728 : kind === 'bodyBytes' ? 1048576 : 4194304
    const binaryUpload = request.requestBytes !== undefined
    const script = `(() => {
      const id = ${JSON.stringify(id)}, url = ${JSON.stringify(request.url)}, kind = ${JSON.stringify(kind)};
      if (Date.now() >= ${deadline} || (window.__komaFetchRetired && window.__komaFetchRetired[id]) ||
          typeof AbortController !== 'function' || location.origin !== ${JSON.stringify(this.origin)} ||
          new URL(url).origin !== location.origin ||
          (kind !== 'bodyText' && typeof btoa !== 'function') ||
          (${binaryUpload} && (typeof atob !== 'function' || typeof Blob !== 'function'))) return 'unavailable';
      const textBody = ${JSON.stringify(request.body ?? '')};
      if (new TextEncoder().encode(textBody).byteLength > 1048576) return 'request_too_large';
      const jobs = window.__komaFetchJobs || (window.__komaFetchJobs = Object.create(null));
      const boxes = window.__komaFetch || (window.__komaFetch = Object.create(null));
      const box = {chunks:[],done:false}; boxes[id] = box;
      const abort = new AbortController(); let live = true, completed = false, started = false, wake, timer;
      const active = () => live && !completed && jobs[id] === job;
      const notify = () => { if (wake) { const f = wake; wake = undefined; f(); } };
      const finish = value => { if (active()) { completed = true; clearTimeout(timer); Object.assign(box,value,{done:true}); notify(); } };
      const job = {parts:[],length:0,notify,
        abort: () => { live = false; clearTimeout(timer); abort.abort(); notify(); delete jobs[id]; delete boxes[id]; },
        push: encoded => {
          if (!active() || started) return false;
          const raw = atob(encoded); if (raw.length > 65536 || job.length + raw.length > 1048576) return false;
          const bytes = new Uint8Array(raw.length); for (let i=0;i<raw.length;i++) bytes[i]=raw.charCodeAt(i);
          job.parts.push(bytes); job.length += bytes.length; return true;
        },
        start: () => {
          if (!active() || started || location.origin !== new URL(url).origin) return false;
          started = true;
          const options = {method:${JSON.stringify(request.method)},headers:${JSON.stringify(headers)},
            credentials:'include',mode:'same-origin',redirect:'error',cache:'no-store',signal:abort.signal};
          ${referrer === undefined ? '' : 'options.referrer=' + JSON.stringify(referrer) + "; options.referrerPolicy='same-origin';"}
          if (${binaryUpload}) { options.body = new Blob(job.parts); job.parts = []; }
          else if (textBody && !['GET','HEAD'].includes(options.method)) options.body=textBody;
          (async () => { try {
            const r = await fetch(url,options); if (!active()) return;
            const headers = Object.create(null); let headerBytes = 0;
            r.headers && r.headers.forEach((v,k) => { if (!['set-cookie','set-cookie2'].includes(k.toLowerCase())) {
              headerBytes += new TextEncoder().encode(k+v).byteLength; headers[k]=[v];
            }});
            if (headerBytes > 65536) { finish({error:'response_headers_too_large'}); abort.abort(); return; }
            box.status = r.status; box.headers = headers;
            let count = 0, text = ''; const decoder = kind === 'bodyText' ? new TextDecoder() : undefined;
            if (r.body && r.body.getReader) {
              const reader = r.body.getReader();
              while (active()) {
                const part = await reader.read(); if (!active()) return; if (part.done) break;
                count += part.value.byteLength;
                if (count > ${limit}) { finish({error:'response_too_large'}); abort.abort(); return; }
                if (decoder) { text += decoder.decode(part.value,{stream:true}); continue; }
                for (let offset=0;offset<part.value.byteLength;offset+=65536) {
                  while (active() && box.chunks.length >= 4) await new Promise(resolve => { wake=resolve; });
                  if (!active()) return;
                  const chunk=part.value.subarray(offset,offset+65536); let raw='';
                  for (let i=0;i<chunk.length;i++) raw+=String.fromCharCode(chunk[i]);
                  box.chunks.push(btoa(raw));
                }
              }
              if (decoder) text += decoder.decode();
            } else if (kind === 'bodyText') {
              text = await r.text(); if (!active()) return;
              if (new TextEncoder().encode(text).byteLength > ${limit}) { finish({error:'response_too_large'}); return; }
            } else if (r.body) { finish({error:'unsupported_response_stream'}); abort.abort(); return; }
            finish(kind === 'bodyText' ? {body:text} : {});
          } catch(e) { finish({error:'network_error'}); } })(); return true;
        }
      }; jobs[id]=job;
      timer=setTimeout(() => { finish({error:'timeout'}); abort.abort(); },${timeoutMs});
      return ${binaryUpload ? "'ready'" : "job.start() ? 'started' : 'unavailable'"};
    })()`
    const initial = this.decode(await this.runScript(controller, script, deadline, current))
    if (initial === 'unavailable') return { attempted: false }
    if (initial === 'request_too_large') return { attempted: false, error: initial }
    if (!current()) return { attempted: true, error: 'source_request_cancelled' }
    if (binaryUpload) {
      if (initial !== 'ready') return { attempted: true, error: 'network_error' }
      const bytes = new Uint8Array(request.requestBytes as ArrayBuffer)
      for (let offset = 0; offset < bytes.length; offset += 65536) {
        const encoded = new util.Base64Helper().encodeToStringSync(bytes.subarray(offset, offset + 65536))
        const accepted = this.decode(await this.runScript(controller,
          "(() => { const j=window.__komaFetchJobs && window.__komaFetchJobs[" + JSON.stringify(id) +
          "]; return !!j && j.push(" + JSON.stringify(encoded) + "); })()", deadline, current))
        if (accepted !== 'true') return { attempted: false, error: 'network_error' }
      }
      const started = this.decode(await this.runScript(controller,
        "(() => { const j=window.__komaFetchJobs && window.__komaFetchJobs[" + JSON.stringify(id) +
        "]; return !!j && j.start(); })()", deadline, current))
      if (started !== 'true') return { attempted: false, error: 'network_error' }
    } else if (initial !== 'started') return { attempted: true, error: 'network_error' }
    const inline = kind === 'bodyBytes' ? new Uint8Array(1048576) : undefined
    let received = 0
    while (Date.now() < deadline) {
      if (!current()) return { attempted: true, error: 'source_request_cancelled' }
      const raw = this.decode(await this.runScript(controller,
        "(() => { const b=window.__komaFetch && window.__komaFetch[" + JSON.stringify(id) +
        "], j=window.__komaFetchJobs && window.__komaFetchJobs[" + JSON.stringify(id) +
        "]; if (!b || !j) return ''; const chunks=b.chunks.splice(0,4); j.notify(); " +
        "return JSON.stringify({chunks,done:b.done,status:b.status,headers:b.headers,body:b.body,error:b.error}); })()", deadline, current))
      if (!current()) return { attempted: true, error: 'source_request_cancelled' }
      if (raw.length === 0) { await this.delay(8); continue }
      const part = JSON.parse(raw) as Record<string, Object>
      if (typeof part['error'] === 'string') return { attempted: true, error: part['error'] as string }
      const chunks = part['chunks'] as string[]
      if (!Array.isArray(chunks) || chunks.length > 4) return { attempted: true, error: 'network_error' }
      for (const chunk of chunks) {
        if (typeof chunk !== 'string' || chunk.length > 87384 ||
          !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(chunk)) {
          return { attempted: true, error: 'network_error' }
        }
        const decoded = new util.Base64Helper().decodeSync(chunk)
        if (decoded.byteLength > 65536 || received + decoded.byteLength > limit) return { attempted: true, error: 'response_too_large' }
        if (!current()) return { attempted: true, error: 'source_request_cancelled' }
        if (inline !== undefined) inline.set(decoded, received)
        else if (request.onResponseChunk !== undefined) request.onResponseChunk(
          decoded.buffer.slice(decoded.byteOffset, decoded.byteOffset + decoded.byteLength) as ArrayBuffer)
        received += decoded.byteLength
      }
      if (part['done'] === true) {
        const status = part['status']
        if (typeof status !== 'number' || status < 100 || status > 599) return { attempted: true, error: 'network_error' }
        return { attempted: true, status: status as number, body: typeof part['body'] === 'string' ? part['body'] as string : '',
          headers: part['headers'] as Record<string, string[]>, bytes: inline?.buffer.slice(0, received) as ArrayBuffer | undefined }
      }
      if (chunks.length === 0) await this.delay(8)
    }
    return { attempted: true, error: 'timeout' }
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
