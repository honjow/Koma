import { waitForSourceRequestSlot } from './SourceRequestPolicy'
import { url as urlKit } from '@kit.ArkTS'
import { appSourceWebSessionStore, sourceWebOrigin, SourceHttpIdentity, SourcePendingWebSessionRequest } from './SourceWebSessionStore'
import { sourceClearanceCookieState } from './SourceWebChallengeGate'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { NativeSourceRuntime } from './NativeSourceRuntime'

interface SourceHttpRequestEnvelope {
  url?: Object | string | number | boolean | null
  method?: Object | string | number | boolean | null
  headers?: Object | string | number | boolean | null
  bodyBase64?: Object | string | number | boolean | null
  body?: Object | string | number | boolean | null
  timeoutMs?: Object | string | number | boolean | null
}

interface RejectedSourceGet {
  requestJson: string
  httpContextJson: string
  identity: SourceHttpIdentity
  rejectedUrl: string
}

interface SourceWebProbeContext {
  proof: SourcePendingWebSessionRequest
  current: () => boolean
}

interface ActiveSourceWebProbe {
  sourceId: string
  sessionId: string
}

interface VerifiedSourceGet {
  request: RejectedSourceGet
  sessionId: string
  responseJson: string
}

// Keep only the last failed read per source and one response ready for immediate handoff.
// Neither requests nor responses are persisted or exposed to the Web document.
const rejectedSourceGets: Map<string, RejectedSourceGet> = new Map<string, RejectedSourceGet>()
let activeSourceWebProbe: ActiveSourceWebProbe | undefined = undefined
let verifiedSourceGet: VerifiedSourceGet | undefined = undefined

const SOURCE_HTTP_DEFAULT_TIMEOUT_MS: number = 15000
const SOURCE_HTTP_MAX_TIMEOUT_MS: number = 60000

class SourceHttpErrorPayload {
  code: string
  message: string = 'network request failed'
  retryable: boolean

  constructor(code: string, retryable: boolean) {
    this.code = code
    this.retryable = retryable
  }
}

class SourceHttpErrorEnvelope {
  ok: boolean = false
  error: SourceHttpErrorPayload
  networkPerformed: boolean = false

  constructor(code: string, retryable: boolean) {
    this.error = new SourceHttpErrorPayload(code, retryable)
  }
}

class SourceHttpSuccessEnvelope {
  ok: boolean = true
  // Keep this field aligned with the source-host ABI.  Source packages use
  // `status` to distinguish HTTP failures from transport failures.
  status: number
  bodyText: string
  networkPerformed: boolean = true
  // An additive host signal, without forwarding response headers or cookies.
  accessSignal?: string

  constructor(status: number, bodyText: string, accessSignal?: string) {
    this.status = status
    this.bodyText = bodyText
    if (accessSignal !== undefined) this.accessSignal = accessSignal
  }
}

function sourceResponseAccessSignal(value: Object | undefined): string | undefined {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) return undefined
  const headers = value as Record<string, Object | string | number | boolean | null>
  const name = Object.keys(headers).find((key: string): boolean => key.toLowerCase() === 'cf-mitigated')
  const raw = name === undefined ? undefined : headers[name]
  // Cloudflare's documented Challenge Page marker. A 403, server name, body
  // keyword or a different mitigation value does not establish a challenge.
  return typeof raw === 'string' && raw.trim() === 'challenge' ? 'challenge_required' : undefined
}

function transportError(code: string, retryable: boolean = true): string {
  return JSON.stringify(new SourceHttpErrorEnvelope(code, retryable))
}

function sourceString(value: Object | string | number | boolean | null | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  return value
}

function sourceTimeout(value: Object | string | number | boolean | null | undefined): number {
  const parsed = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return SOURCE_HTTP_DEFAULT_TIMEOUT_MS
  }
  return Math.min(Math.max(Math.floor(parsed), 1000), SOURCE_HTTP_MAX_TIMEOUT_MS)
}

function sourceHeaders(value: Object | string | number | boolean | null | undefined): Record<string, string> {
  const headers: Record<string, string> = {}
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return headers
  }
  const record = value as Record<string, Object | string | number | boolean | null>
  Object.keys(record).forEach((name: string) => {
    const raw = sourceString(record[name])
    if (raw === undefined || name.trim().length === 0 || name.length > 256 || raw.length > 8192) {
      return
    }
    headers[name] = raw
  })
  return headers
}

/** The adopted MangaBz language preference is a public request option, not a
 * source-supplied login session. Only this source/domain/key/value may replace
 * its counterpart; WebView owns every other cookie and the user agent.
 * Keep the override request-local, including redirects, without writing the jar.
 */
function sourceSessionCookies(sourceId: string, fullUrl: string,
  originalHeaders: Record<string, string>, sessionCookie: string): string {
  if (sourceId !== 'com.mangabz.koma') return sessionCookie
  try {
    const parsed = new urlKit.URL(fullUrl)
    const host = parsed.hostname.toLowerCase()
    if ((parsed.protocol !== 'https:' && parsed.protocol !== 'http:') ||
      (host !== 'mangabz.com' && !host.endsWith('.mangabz.com'))) return sessionCookie
  } catch (_error) { return sessionCookie }
  const values: string[] = []
  Object.keys(originalHeaders).forEach((name: string) => {
    if (name.toLowerCase() !== 'cookie') return
    originalHeaders[name].split(';').forEach((part: string) => {
      const pair = part.trim()
      if (pair === 'mangabz_lang=1' || pair === 'mangabz_lang=2') values.push(pair)
    })
  })
  if (values.length !== 1) return sessionCookie
  const retained = sessionCookie.split(';').filter((part: string): boolean =>
    part.split('=')[0].trim() !== 'mangabz_lang').join(';').trim()
  return retained.length === 0 ? values[0] : retained + '; ' + values[0]
}

function sourceMethod(value: Object | string | number | boolean | null | undefined): string | undefined {
  const method = sourceString(value)?.trim().toUpperCase()
  if (method === undefined || !/^[A-Z]{3,12}$/.test(method)) {
    return undefined
  }
  return method
}

function sourceHttpUrl(value: Object | string | number | boolean | null | undefined): string | undefined {
  const url = sourceString(value)?.trim()
  if (url === undefined || (!url.startsWith('https://') && !url.startsWith('http://'))) {
    return undefined
  }
  return url
}

function sourceNetworkMethod(method: string): http.RequestMethod {
  // HEAD is a body-free NetworkKit operation, not a custom GET method.
  if (method === 'HEAD') return http.RequestMethod.HEAD
  return method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET
}

// Stop before NetworkKit issues a redirected request. maxRedirects=0 rejects
// the first redirect with 2300047 instead of exposing its response to this host.
class SourceRedirectStopInterceptor implements http.HttpInterceptor {
  interceptorType: http.InterceptorType = http.InterceptorType.REDIRECTION

  interceptorHandle(_request: http.HttpRequestContext, _response: http.HttpResponse): Promise<http.ChainContinue> {
    return Promise.resolve(false)
  }
}

function attachSourceRedirectStop(request: http.HttpRequest): boolean {
  try {
    const chain = new http.HttpInterceptorChain()
    return chain.addChain([new SourceRedirectStopInterceptor()]) && chain.apply(request)
  } catch (_error) {
    return false
  }
}

// NetworkKit reports cumulative checkpoints from the start of this hop, not
// individual phase durations. Missing/reused-connection values do not prove a
// DNS, TCP or TLS failure. Never include URLs, headers or response content here.
function sourceHttpTimingMs(value: number | undefined): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : -1
}

function sourceHttpTimingText(timing: http.PerformanceTiming | undefined): string {
  return 'dnsDoneMs=' + sourceHttpTimingMs(timing?.dnsTiming) +
    ' tcpDoneMs=' + sourceHttpTimingMs(timing?.tcpTiming) +
    ' tlsDoneMs=' + sourceHttpTimingMs(timing?.tlsTiming) +
    ' firstByteMs=' + sourceHttpTimingMs(timing?.firstReceiveTiming) +
    ' finishMs=' + sourceHttpTimingMs(timing?.totalFinishTiming)
}

async function executeSourceHttpRequest(requestJson: string, httpContextJson: string = '',
  probe?: SourceWebProbeContext): Promise<string> {
  let envelope: SourceHttpRequestEnvelope
  try {
    envelope = JSON.parse(requestJson) as SourceHttpRequestEnvelope
  } catch (_error) {
    return transportError('invalid_request', false)
  }
  const url = sourceHttpUrl(envelope.url)
  const method = sourceMethod(envelope.method)
  if (url === undefined || method === undefined) {
    return transportError('invalid_request', false)
  }
  const body = sourceString(envelope.bodyBase64) ?? sourceString(envelope.body) ?? ''
  if (body.length > 1024 * 1024) {
    return transportError('request_too_large', false)
  }
  const trace = DiagnosticLogger.begin('source_http', 'request', 'method=' + method + ' timeoutMs=' + sourceTimeout(envelope.timeoutMs))
  let identity: SourceHttpIdentity | undefined = undefined
  try {
    const parsed = JSON.parse(httpContextJson) as SourceHttpIdentity
    if (typeof parsed.sourceId === 'string' && typeof parsed.sourceVersion === 'string' && typeof parsed.packageIdentity === 'string' &&
      Array.isArray(parsed.webSessionOrigins) && parsed.webSessionOrigins.every((item: string): boolean => typeof item === 'string')) identity = parsed
  } catch (_error) {}
  if (probe === undefined && verifiedSourceGet !== undefined) {
    const ready = verifiedSourceGet
    if (identity !== undefined && ready.request.requestJson === requestJson &&
      ready.request.httpContextJson === httpContextJson) {
      // Other global-search sources can finish while this original read waits
      // in WAMR's queue. Only its exact request may consume the single handoff.
      verifiedSourceGet = undefined
      if (appSourceWebSessionStore.status(identity.sourceId).sessionId === ready.sessionId &&
        appSourceWebSessionStore.requestSession(identity, url) !== undefined) {
        DiagnosticLogger.info('source_http', 'verification_response_reused', 'state=used_once')
        trace.finish('completed', 'state=verification_response_reused')
        return ready.responseJson
      }
    }
  }
  const session = identity === undefined ? undefined : probe === undefined
    ? appSourceWebSessionStore.requestSession(identity, url)
    : appSourceWebSessionStore.pendingRequestSession(identity, url, probe.proof)
  if (probe !== undefined && (session === undefined || !probe.current())) {
    trace.finish('failed', 'reason=web_session_probe_unavailable')
    return transportError('web_session_unavailable', false)
  }
  try {
    let currentUrl = url
    let currentMethod = method
    let currentBody = body
    const startedAt = Date.now()
    let policyWaitMs: number = 0
    let redirects = 0
    while (true) {
    const policyStartedAt: number = Date.now()
    await waitForSourceRequestSlot(identity?.sourceId ?? '', currentUrl, () => probe === undefined || probe.current())
    // A rate-limit queue is not network time. Keep the original request/redirect
    // timeout budget intact once its slot becomes available.
    policyWaitMs += Math.max(0, Date.now() - policyStartedAt)
    const originalHeaders = sourceHeaders(envelope.headers)
    const headers: Record<string, string> = {}
    Object.keys(originalHeaders).forEach((name: string) => {
      if (session === undefined || (name.toLowerCase() !== 'cookie' && name.toLowerCase() !== 'user-agent')) headers[name] = originalHeaders[name]
    })
    if (session !== undefined && identity !== undefined) {
      const active = probe === undefined ? appSourceWebSessionStore.requestSession(identity, currentUrl) :
        appSourceWebSessionStore.pendingRequestSession(identity, currentUrl, probe.proof)
      if (active === undefined || (probe !== undefined && !probe.current())) {
        trace.finish('failed', 'reason=web_session_unavailable')
        return transportError('web_session_unavailable', false)
      }
      headers['User-Agent'] = active.userAgent
      const cookie = sourceSessionCookies(identity.sourceId, currentUrl, originalHeaders, active.cookie)
      if (cookie.length > 0) headers['Cookie'] = cookie
    }
    trace.info('session', 'identity=' + (identity === undefined ? 'none' : 'native') +
      ' session=' + (session === undefined ? 'none' : 'attached') +
      ' cookieState=' + (typeof headers['Cookie'] === 'string' && headers['Cookie'].length > 0 ? 'present' : 'empty') +
      ' uaSource=' + (session === undefined ? 'source' : 'webview'))
    if (session !== undefined) trace.info('clearance_cookie', 'state=' + sourceClearanceCookieState(headers['Cookie'] ?? ''))
    const remaining = session === undefined ? sourceTimeout(envelope.timeoutMs) :
      Math.max(1, sourceTimeout(envelope.timeoutMs) - (Date.now() - startedAt - policyWaitMs))
    const request = http.createHttp()
    let response: http.HttpResponse
    const hopStartedAt = Date.now()
    let firstHeaderMs = -1
    try {
      request.on('headersReceive', () => {
        if (firstHeaderMs < 0) firstHeaderMs = Math.max(0, Date.now() - hopStartedAt)
      })
      if (session !== undefined && !attachSourceRedirectStop(request)) {
        trace.finish('failed', 'reason=web_session_redirect_unavailable')
        return transportError('web_session_redirect_unavailable', false)
      }
      response = await request.request(currentUrl, {
      method: sourceNetworkMethod(currentMethod),
      customMethod: currentMethod === 'GET' || currentMethod === 'POST' || currentMethod === 'HEAD' ? undefined : currentMethod,
      extraData: currentBody.length > 0 ? currentBody : undefined,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      header: headers,
      readTimeout: remaining,
      connectTimeout: remaining,
      })
    } catch (error) {
      trace.warn('hop_failed', 'hop=' + redirects + ' headersReceived=' + (firstHeaderMs >= 0) +
        ' firstHeaderMs=' + firstHeaderMs + ' elapsedMs=' + Math.max(0, Date.now() - hopStartedAt))
      throw error as Error
    } finally {
      // A HttpRequest represents one hop and cannot be reused for the next URL.
      request.off('headersReceive')
      request.destroy()
    }
    trace.info('hop_response', 'hop=' + redirects + ' status=' + response.responseCode +
      ' headersReceived=' + (firstHeaderMs >= 0) + ' firstHeaderMs=' + firstHeaderMs +
      ' elapsedMs=' + Math.max(0, Date.now() - hopStartedAt) + ' ' + sourceHttpTimingText(response.performanceTiming))
    if (probe !== undefined && !probe.current()) {
      trace.finish('failed', 'reason=web_session_probe_cancelled')
      return transportError('web_session_unavailable', false)
    }
    if (session !== undefined && identity !== undefined) {
      // NetworkKit exposes each Set-Cookie as an array entry; preserve Expires commas.
      const responseHeaders = response.header as Record<string, Object | string | number | boolean | null>
      const key = Object.keys(responseHeaders).find((name: string): boolean => name.toLowerCase() === 'set-cookie')
      const raw = key === undefined ? undefined : responseHeaders[key]
      const values: string[] = []
      if (typeof raw === 'string') values.push(raw)
      else if (Array.isArray(raw)) {
        (raw as Object[]).forEach((value: Object) => { if (typeof value === 'string') values.push(value) })
      }
      if (probe === undefined) appSourceWebSessionStore.acceptResponseCookies(identity, currentUrl, values)
      else appSourceWebSessionStore.acceptPendingResponseCookies(identity, currentUrl, probe.proof, values)
    }
    const responseBody = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
    if (identity !== undefined && response.responseCode === 403) {
      appSourceWebSessionStore.observeRejectedRequest(identity, currentUrl)
      const origin = sourceWebOrigin(currentUrl)
      if (probe === undefined && method === 'GET' && body.length === 0 && requestJson.length <= 65536 &&
        origin.length > 0 && identity.webSessionOrigins.includes(origin)) {
        rejectedSourceGets.set(identity.sourceId, { requestJson, httpContextJson, identity, rejectedUrl: currentUrl })
      }
    }
    if (session !== undefined && [301, 302, 303, 307, 308].includes(response.responseCode)) {
      const responseHeaders = response.header as Record<string, Object | string | number | boolean | null>
      const locationKey = Object.keys(responseHeaders).find((name: string): boolean => name.toLowerCase() === 'location')
      const location = locationKey === undefined ? undefined : sourceString(responseHeaders[locationKey])
      if (location === undefined || redirects >= 30 || Date.now() - startedAt - policyWaitMs >= sourceTimeout(envelope.timeoutMs)) {
        trace.finish('failed', 'reason=web_session_redirect_rejected')
        return transportError('web_session_redirect_rejected', false)
      }
      const nextUrl = new urlKit.URL(location, currentUrl).toString()
      // Re-check the full next URL against this source's explicit session grant.
      const nextSession = identity === undefined ? undefined : probe === undefined
        ? appSourceWebSessionStore.requestSession(identity, nextUrl)
        : appSourceWebSessionStore.pendingRequestSession(identity, nextUrl, probe.proof)
      if (nextSession === undefined) {
        trace.finish('failed', 'reason=web_session_redirect_rejected')
        return transportError('web_session_redirect_rejected', false)
      }
      if (response.responseCode === 303 || ((response.responseCode === 301 || response.responseCode === 302) && currentMethod === 'POST')) {
        currentMethod = 'GET'
        currentBody = ''
      }
      currentUrl = nextUrl
      redirects += 1
      continue
    }
    const accessSignal = sourceResponseAccessSignal(response.header)
    if (accessSignal !== undefined) trace.info('access_signal', 'signal=' + accessSignal)
    trace.finish(response.responseCode >= 400 ? 'failed' : 'completed', 'status=' + response.responseCode + ' chars=' + responseBody.length)
    return JSON.stringify(new SourceHttpSuccessEnvelope(response.responseCode, responseBody, accessSignal))
    }
  } catch (_error) {
    const error = _error as BusinessError
    const platformCode = typeof error.code === 'number' && Number.isFinite(error.code) ? error.code : 0
    trace.fail(error)
    DiagnosticLogger.warn('source_http', 'transport_failed', 'platformCode=' + platformCode)
    return transportError(platformCode === 2300028 ? 'timeout' : 'network_error')
  }
}

/** One same-origin read of the exact rejected GET, while its verification sheet stays visible. */
export async function probeSourceWebSession(sourceId: string, sessionId: string, documentUrl: string,
  userAgent: string, current: () => boolean): Promise<boolean> {
  const request = rejectedSourceGets.get(sourceId)
  if (request === undefined || !current()) return false
  const active: ActiveSourceWebProbe = { sourceId, sessionId }
  if (activeSourceWebProbe !== undefined) return false
  activeSourceWebProbe = active
  const probe: SourceWebProbeContext = {
    proof: { sessionId, initialUrl: request.rejectedUrl, documentUrl, userAgent },
    current: (): boolean => activeSourceWebProbe === active && current(),
  }
  try {
    const responseJson = await executeSourceHttpRequest(request.requestJson, request.httpContextJson, probe)
    if (!probe.current() || rejectedSourceGets.get(sourceId) !== request || responseJson.length > 4 * 1024 * 1024) return false
    const response = JSON.parse(responseJson) as SourceHttpSuccessEnvelope
    if (response.ok !== true || !Number.isInteger(response.status) || response.status < 200 || response.status >= 300 ||
      response.accessSignal === 'challenge_required') return false
    if (appSourceWebSessionStore.pendingRequestSession(request.identity, request.rejectedUrl, probe.proof) === undefined) return false
    verifiedSourceGet = { request, sessionId, responseJson }
    DiagnosticLogger.info('source_http', 'verification_probe', 'state=ready_for_original_request')
    return true
  } catch (_error) {
    return false
  } finally {
    if (activeSourceWebProbe === active) activeSourceWebProbe = undefined
  }
}

export function cancelSourceWebProbe(sourceId: string, sessionId: string): void {
  if (activeSourceWebProbe?.sourceId === sourceId && activeSourceWebProbe.sessionId === sessionId) activeSourceWebProbe = undefined
  if (verifiedSourceGet?.request.identity.sourceId === sourceId && verifiedSourceGet.sessionId === sessionId) verifiedSourceGet = undefined
}

export function configureSourceRuntimeHttpTransport(): boolean {
  return NativeSourceRuntime.configureHttpTransport(executeSourceHttpRequest)
}
