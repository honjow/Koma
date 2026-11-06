import { waitForSourceRequestSlot, SourceRequestAdmission } from './SourceRequestPolicy'
import { url as urlKit } from '@kit.ArkTS'
import { appSourceWebSessionStore, sourceWebOrigin, sourceWebPackageIdentity, SourceHttpIdentity, SourcePendingWebSessionRequest } from './SourceWebSessionStore'
import { appSourceRuntimeRegistry } from './SourceRuntimeAppRegistry'
import { sourceRuntimeEntryEnabled } from './SourceRuntimeRegistry'
import { SourcePrivateSessionHost, SourcePrivateSessionScope } from './SourcePrivateSessionHost'
import { sourceClearanceCookieState } from './SourceWebChallengeGate'
import { sourceRuntimeOperationIsCurrent } from './SourceRuntimeOperationGuard'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { NativeSourceRuntime, SourceBrowserHttpTiming } from './NativeSourceRuntime'
import { appSourceSettingsStore } from './SourceSettingsStore'
import { COPY_MANGA_API_MIN_SDK, copyMangaApiTarget } from './CopyMangaHostContract'
import { initializeSourcePicaChannel, requestSourcePicaHop, sourcePicaChannelIp, sourcePicaDnsOverride,
  SourcePicaDnsOverride, SourcePicaChannelScope } from './SourcePicaChannelTransport'
import { requestSourceRcpHop, sourceRcpResponseText, SourceRcpTransportFailure } from './SourceRcpTransport'

interface SourcePrivateFailure {
  ok: boolean
  error: SourcePrivateFailureCode
}
interface SourcePrivateFailureCode { code: string }
interface SourceRegexFailure { ok: boolean }
interface SourceRegexTextData { valid: boolean; text: string }
interface SourceRegexTextResult { ok: boolean; data: SourceRegexTextData }
interface SourcePrivateResultSummary {
  ok?: boolean
  state?: string
  error?: SourcePrivateFailureCode
}

function privateIdentityFailure(): string {
  DiagnosticLogger.warn('source_private_session', 'rpc', 'ok=false reason=invalid_identity')
  const failure: SourcePrivateFailure = { ok: false, error: { code: 'invalid_identity' } }
  return JSON.stringify(failure)
}

interface SourceHttpRequestEnvelope {
  type?: string
  version?: number
  op?: string
  pattern?: string
  text?: string
  texts?: string[]
  requests?: SourceHttpRequestEnvelope[]
  wantChallengeRequestId?: boolean
  url?: Object | string | number | boolean | null
  method?: Object | string | number | boolean | null
  headers?: Object | string | number | boolean | null
  bodyBase64?: Object | string | number | boolean | null
  body?: Object | string | number | boolean | null
  timeoutMs?: Object | string | number | boolean | null
  dnsOverride?: Object
}

interface RejectedSourceGet {
  requestJson: string
  httpContextJson: string
  identity: SourceHttpIdentity
  rejectedUrl: string
  effectiveUserAgent?: string
  selectedByChallengeId?: boolean
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

// Legacy callers keep their last failed read per source. A unified-search
// operation has its own handle, so another operation cannot replace that GET.
// Neither requests nor responses are persisted or exposed to the Web document.
const rejectedSourceGets: Map<string, RejectedSourceGet | null> = new Map<string, RejectedSourceGet | null>()
const rejectedSourceCandidates: Map<string, Map<string, RejectedSourceGet>> = new Map<string, Map<string, RejectedSourceGet>>()
let rejectedSourceSequence: number = 0
let activeSourceWebProbe: ActiveSourceWebProbe | undefined = undefined
let verifiedSourceGet: VerifiedSourceGet | undefined = undefined

function rejectedSourceGetKey(sourceId: string, requestHandle?: string): string {
  return JSON.stringify([sourceId, requestHandle ?? null])
}

export function sourceRejectedRequestUrl(sourceId: string, requestHandle: string): string {
  return rejectedSourceGets.get(rejectedSourceGetKey(sourceId, requestHandle))?.rejectedUrl ?? ''
}

/** Only the causally selected GET may lend its effective identity to its exact Web session. */
export function sourceRejectedRequestUserAgent(sourceId: string, requestHandle: string, fullUrl: string): string | undefined {
  const selected = rejectedSourceGets.get(rejectedSourceGetKey(sourceId, requestHandle))
  if (selected === undefined || selected === null || selected.selectedByChallengeId !== true ||
    selected.identity.sourceId !== sourceId || selected.identity.operationGuardId !== requestHandle ||
    selected.rejectedUrl !== fullUrl || !selected.identity.webSessionOrigins.includes(sourceWebOrigin(fullUrl))) return undefined
  return selected.effectiveUserAgent
}

export function clearSourceRejectedRequest(sourceId: string, requestHandle: string): void {
  const key = rejectedSourceGetKey(sourceId, requestHandle)
  rejectedSourceGets.delete(key)
  rejectedSourceCandidates.delete(key)
  if (verifiedSourceGet?.request.identity.sourceId === sourceId &&
    verifiedSourceGet.request.identity.operationGuardId === requestHandle) verifiedSourceGet = undefined
}

/** Select only a host-observed GET belonging to this source and operation. */
export function selectSourceRejectedRequest(sourceId: string, requestHandle: string, challengeRequestId?: string): void {
  const key = rejectedSourceGetKey(sourceId, requestHandle)
  const candidates = rejectedSourceCandidates.get(key)
  // Old sources do not opt in. Retain their existing single-GET fallback.
  if (candidates === undefined && challengeRequestId === undefined) return
  const selected = challengeRequestId === undefined ? undefined : candidates?.get(challengeRequestId)
  if (selected !== undefined) selected.selectedByChallengeId = true
  rejectedSourceGets.set(key, selected ?? null)
}

const SOURCE_HTTP_DEFAULT_TIMEOUT_MS: number = 15000
const SOURCE_HTTP_MAX_TIMEOUT_MS: number = 60000
// Matches the reference's bounded source-probe concurrency; a source with a
// large catalogue must submit successive groups, not fan out every edition.
const SOURCE_HTTP_BATCH_MAX_REQUESTS: number = 5

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
  networkPerformed?: boolean = false

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
  challengeRequestId?: string
  dnsOverride?: SourcePicaDnsOverride

  constructor(status: number, bodyText: string, accessSignal?: string, challengeRequestId?: string) {
    this.status = status
    this.bodyText = bodyText
    if (accessSignal !== undefined) this.accessSignal = accessSignal
    if (challengeRequestId !== undefined) this.challengeRequestId = challengeRequestId
  }
}

class SourceHttpBatchSuccessEnvelope {
  ok: boolean = true
  responses: Object[]

  constructor(responses: Object[]) {
    this.responses = responses
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

// A public redirect is not a grant to forward the previous origin's credentials.
// Web cookies remain independently authorized per hop (MH160 www -> m is a GET).
function sourcePublicRedirectHeaders(headers: Record<string, string>): Record<string, string> {
  const publicHeaders: Record<string, string> = {}
  Object.keys(headers).forEach((name: string) => {
    if (['accept', 'accept-language', 'user-agent'].includes(name.toLowerCase())) publicHeaders[name] = headers[name]
  })
  return publicHeaders
}

function sourceAllowsAnonymousRedirect(identity: SourceHttpIdentity | undefined, initialUrl: string,
  nextUrl: string, method: string, body: string, probe: SourceWebProbeContext | undefined): boolean {
  if (probe !== undefined || identity === undefined || method !== 'GET' || body.length > 0) return false
  const origin = sourceWebOrigin(nextUrl)
  if (origin.length === 0 || origin === sourceWebOrigin(initialUrl) || !identity.webSessionOrigins.includes(origin)) return false
  const entry = appSourceRuntimeRegistry.lookup(identity.sourceId).entry
  return entry !== undefined && sourceRuntimeEntryEnabled(entry) && entry.manifestVersion === identity.sourceVersion &&
    sourceWebPackageIdentity(entry) === identity.packageIdentity && (entry.webSessionOrigins ?? []).includes(origin)
}

/** The adopted MangaBz language preference is a public request option, not a
 * source-supplied login session. Only this source/domain/key/value may replace
 * its counterpart; WebView owns every other cookie and the user agent.
 * Keep the override request-local, including redirects, without writing the jar.
 */
function sourceSessionCookies(sourceId: string, fullUrl: string,
  originalHeaders: Record<string, string>, sessionCookie: string): string {
  if (sourceId !== 'com.mangabz.koma') return sessionCookie
  let languageKey: string = ''
  try {
    const parsed = new urlKit.URL(fullUrl)
    const host = parsed.hostname.toLowerCase()
    if ((parsed.protocol !== 'https:' && parsed.protocol !== 'http:') || parsed.username.length > 0 || parsed.password.length > 0) return sessionCookie
    if (host === 'mangabz.com' || host.endsWith('.mangabz.com')) languageKey = 'mangabz_lang'
    else if (parsed.protocol === 'https:' && (host === 'xmanhua.com' || host.endsWith('.xmanhua.com'))) languageKey = 'xmanhua_lang'
    else if (parsed.protocol === 'https:' && (host === 'yymanhua.com' || host.endsWith('.yymanhua.com'))) languageKey = 'yymanhua_lang'
    else return sessionCookie
  } catch (_error) { return sessionCookie }
  const values: string[] = []
  Object.keys(originalHeaders).forEach((name: string) => {
    if (name.toLowerCase() !== 'cookie') return
    originalHeaders[name].split(';').forEach((part: string) => {
      const pair = part.trim()
      if (pair === languageKey + '=1' || pair === languageKey + '=2') values.push(pair)
    })
  })
  if (values.length !== 1) return sessionCookie
  const retained = sessionCookie.split(';').filter((part: string): boolean =>
    part.split('=')[0].trim() !== languageKey).join(';').trim()
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

function sourceHttpTimingText(timing: http.PerformanceTiming | SourceBrowserHttpTiming | undefined): string {
  return 'dnsDoneMs=' + sourceHttpTimingMs(timing?.dnsTiming) +
    ' tcpDoneMs=' + sourceHttpTimingMs(timing?.tcpTiming) +
    ' tlsDoneMs=' + sourceHttpTimingMs(timing?.tlsTiming) +
    ' firstByteMs=' + sourceHttpTimingMs(timing?.firstReceiveTiming) +
    ' finishMs=' + sourceHttpTimingMs(timing?.totalFinishTiming)
}

interface SourceHopResponse { responseCode: number; result: string | Object | ArrayBuffer; header: Object; performanceTiming?: http.PerformanceTiming | SourceBrowserHttpTiming }
class SourceHopResult implements SourceHopResponse {
  responseCode: number; result: string | Object | ArrayBuffer; header: Object; performanceTiming?: http.PerformanceTiming | SourceBrowserHttpTiming
  constructor(code: number, body: string | Object | ArrayBuffer, headers: Object, timing?: http.PerformanceTiming | SourceBrowserHttpTiming) { this.responseCode = code; this.result = body; this.header = headers; this.performanceTiming = timing }
}
let sourceBrowserHttpSequence: number = 0
class SourceBrowserHttpFailure extends Error { code: number = 0; constructor(code: number) { super('source transport failed'); this.code = code } }
function sourceBrowserHttpHeaders(lines: string[]): Record<string, Object> {
  const result: Record<string, Object> = {}
  const cookies: string[] = []
  lines.forEach((line: string) => {
    const at = line.indexOf(':')
    if (at <= 0) return
    const name = line.substring(0, at).trim().toLowerCase()
    const value = line.substring(at + 1).trim()
    if (name === 'set-cookie') cookies.push(value)
    else result[name] = value
  })
  if (cookies.length > 0) result['set-cookie'] = cookies
  return result
}

function picaScope(identity: SourceHttpIdentity | undefined, current: () => boolean): SourcePicaChannelScope {
  if (identity?.sourceId !== 'com.picacomic.koma') throw new SourceRcpTransportFailure('invalid_request')
  const entry = appSourceRuntimeRegistry.lookup(identity.sourceId).entry
  if (entry === undefined || !sourceRuntimeEntryEnabled(entry) || sourceWebPackageIdentity(entry) !== identity.packageIdentity ||
    entry.manifestVersion !== identity.sourceVersion || typeof identity.privateCallId !== 'string') {
    throw new SourceRcpTransportFailure('invalid_request')
  }
  const scope: SourcePrivateSessionScope = { sourceId: identity.sourceId, packageIdentity: identity.packageIdentity, callId: identity.privateCallId }
  return { sourceId: identity.sourceId, packageIdentity: identity.packageIdentity, current: (): boolean => {
    const installed = appSourceRuntimeRegistry.lookup(identity.sourceId).entry
    return current() && installed === entry && sourceRuntimeEntryEnabled(installed) && SourcePrivateSessionHost.callIsActive(scope)
  } }
}

function rcpFailure(error: Object, priorNetworkPerformed: boolean = false): string {
  const known = error instanceof SourceRcpTransportFailure
  const reason = known ? (error as SourceRcpTransportFailure).fixedCode : 'network_error'
  const result = new SourceHttpErrorEnvelope(reason, reason === 'network_error' || reason === 'timeout')
  // An exception after a public request must not be described as zero network.
  result.networkPerformed = priorNetworkPerformed ? true : known ? (error as SourceRcpTransportFailure).networkPerformed : undefined
  return JSON.stringify(result)
}

async function executePicaInitialization(envelope: SourceHttpRequestEnvelope, httpContextJson: string): Promise<string> {
  try {
    if (envelope.version !== 1 || Object.keys(envelope).some((key: string): boolean =>
      !['type', 'version', 'timeoutMs'].includes(key))) throw new SourceRcpTransportFailure('invalid_request')
    const identity = JSON.parse(httpContextJson) as SourceHttpIdentity
    const scope = picaScope(identity, (): boolean => sourceRuntimeOperationIsCurrent(identity.operationGuardId))
    const privateScope: SourcePrivateSessionScope = { sourceId: identity.sourceId, packageIdentity: identity.packageIdentity,
      callId: identity.privateCallId ?? '' }
    const entry = appSourceRuntimeRegistry.lookup(identity.sourceId).entry
    // A metadata call cannot turn this independent public preparation into HTTP.
    // The existing credential grant still authorizes only its unchanged API origin.
    if (entry?.authentication?.kind !== 'credentials' ||
      sourceWebOrigin(entry.authentication.loginUrl) !== 'https://picaapi.picacomic.com' ||
      !SourcePrivateSessionHost.publicInitializationIsAllowed(privateScope)) throw new SourceRcpTransportFailure('invalid_request')
    const revision = appSourceSettingsStore.revisionForSource(identity.sourceId)
    const settings = appSourceSettingsStore.loadForSource(identity.sourceId)
    if (settings['APP_CHANNEL'] !== undefined && settings['APP_CHANNEL'] !== '2' && settings['APP_CHANNEL'] !== '3') {
      throw new SourceRcpTransportFailure('invalid_request')
    }
    const raw = settings['APP_CHANNEL_URL']
    if (raw !== undefined && typeof raw !== 'string') throw new SourceRcpTransportFailure('invalid_request')
    const initUrl = typeof raw === 'string' && raw.trim().length > 0 ? raw : 'http://68.183.234.72/init'
    const current = scope.current
    scope.current = (): boolean => current() && appSourceSettingsStore.revisionForSource(identity.sourceId) === revision &&
      SourcePrivateSessionHost.publicInitializationIsAllowed(privateScope) &&
      SourcePrivateSessionHost.credentialRequestAllowed(identity.privateCallId, identity.credentialGrantId, entry.authentication?.loginUrl ?? '')
    const response = await initializeSourcePicaChannel(initUrl, scope, sourceTimeout(envelope.timeoutMs))
    const result = new SourceHttpSuccessEnvelope(response.status, response.bodyText)
    if (response.dnsOverride !== undefined) result.dnsOverride = response.dnsOverride
    return JSON.stringify(result)
  } catch (error) { return rcpFailure(error as Object) }
}

async function executeSourceHttpRequest(requestJson: string, httpContextJson: string = '',
  probe?: SourceWebProbeContext): Promise<string> {
  let envelope: SourceHttpRequestEnvelope
  try {
    envelope = JSON.parse(requestJson) as SourceHttpRequestEnvelope
  } catch (_error) {
    return transportError('invalid_request', false)
  }
  if (envelope === null || Array.isArray(envelope) || typeof envelope !== 'object') {
    return transportError('invalid_request', false)
  }
  if (envelope.type === 'pica_channel_init') {
    if (probe !== undefined) return transportError('invalid_request', false)
    return executePicaInitialization(envelope, httpContextJson)
  }
  if (envelope.type === 'java_regex') {
    // The source worker waits on this bridge; native async work avoids
    // scheduling another task onto the same pool of blocked source workers.
    if (probe !== undefined || envelope.version !== 1 || typeof envelope.pattern !== 'string' ||
      (envelope.op !== 'validate' && envelope.op !== 'remove')) {
      return JSON.stringify({ ok: false } as SourceRegexFailure)
    }
    let identity: SourceHttpIdentity
    try { identity = (httpContextJson.length > 0 ? JSON.parse(httpContextJson) : {}) as SourceHttpIdentity }
    catch (_error) { return JSON.stringify({ ok: false } as SourceRegexFailure) }
    if (identity === null || !sourceRuntimeOperationIsCurrent(identity.operationGuardId)) {
      return JSON.stringify({ ok: false } as SourceRegexFailure)
    }
    const texts: string[] = envelope.op === 'validate' ? [] :
      Array.isArray(envelope.texts) ? envelope.texts :
        typeof envelope.text === 'string' ? [envelope.text] : []
    if (envelope.op === 'remove' && !Array.isArray(envelope.texts) && typeof envelope.text !== 'string') {
      return JSON.stringify({ ok: false } as SourceRegexFailure)
    }
    try {
      const result = await NativeSourceRuntime.javaRegex(envelope.pattern, texts)
      if (!sourceRuntimeOperationIsCurrent(identity.operationGuardId)) {
        return JSON.stringify({ ok: false } as SourceRegexFailure)
      }
      if (envelope.op === 'remove' && typeof envelope.text === 'string' && result.ok && result.data.valid) {
        const single: SourceRegexTextResult = { ok: true, data: { valid: true, text: result.data.texts[0] } }
        return JSON.stringify(single)
      }
      return JSON.stringify(result)
    } catch (_error) {
      return JSON.stringify({ ok: false } as SourceRegexFailure)
    }
  }
  if (envelope.type === 'private_session') {
    // This RPC uses the existing bridge, but never performs HTTP or logs its
    // opaque values. Its source/installation comes only from the Native context.
    let identity: SourceHttpIdentity
    try { identity = JSON.parse(httpContextJson) as SourceHttpIdentity }
    catch (_error) { return privateIdentityFailure() }
    if (probe !== undefined || identity === null || typeof identity.sourceId !== 'string' ||
      typeof identity.sourceVersion !== 'string' || typeof identity.packageIdentity !== 'string' ||
      typeof identity.privateCallId !== 'string') {
      return privateIdentityFailure()
    }
    const scope: SourcePrivateSessionScope = { sourceId: identity.sourceId,
      packageIdentity: identity.packageIdentity, callId: identity.privateCallId }
    const current = (): boolean => {
      const entry = appSourceRuntimeRegistry.lookup(identity.sourceId).entry
      return entry !== undefined && sourceRuntimeEntryEnabled(entry) &&
        entry.manifestVersion === identity.sourceVersion && sourceWebPackageIdentity(entry) === identity.packageIdentity &&
        sourceRuntimeOperationIsCurrent(identity.operationGuardId) && SourcePrivateSessionHost.callIsActive(scope)
    }
    const result = await SourcePrivateSessionHost.execute(requestJson, scope, current)
    const op = typeof envelope.op === 'string' &&
      ['begin', 'commit', 'abort', 'invalidate', 'clock', 'rsa_pkcs1', 'credential_input', 'process_scope'].includes(envelope.op) ? envelope.op : 'unknown'
    try {
      const summary = JSON.parse(result) as SourcePrivateResultSummary
      const state = summary.state === 'ready' || summary.state === 'owner' ? summary.state : 'none'
      DiagnosticLogger.info('source_private_session', 'rpc', 'operation=' + op +
        ' ok=' + (summary.ok === true) + ' state=' + state + ' reason=' + (summary.error?.code ?? 'none'))
    } catch (_error) {
      DiagnosticLogger.warn('source_private_session', 'rpc', 'operation=' + op + ' reason=invalid_private_response')
    }
    return result
  }
  if (envelope.requests !== undefined) {
    // A source may group independent reads without changing the synchronous
    // WASM import. Reuse every ordinary request's identity, rate policy,
    // redirects and transport errors; never grant a batch its own session.
    const requests = envelope.requests
    if (probe !== undefined || !Array.isArray(requests) || requests.length === 0 || requests.length > SOURCE_HTTP_BATCH_MAX_REQUESTS) {
      return transportError('invalid_request', false)
    }
    // Validate the whole group before starting any network request. Nested
    // groups would evade the concurrency bound and are not part of this ABI.
    for (const request of requests) {
      if (request === null || typeof request !== 'object' || Array.isArray(request) ||
        request.requests !== undefined || sourceHttpUrl(request.url) === undefined || sourceMethod(request.method) === undefined) {
        return transportError('invalid_request', false)
      }
      const body = sourceString(request.bodyBase64) ?? sourceString(request.body) ?? ''
      if (body.length > 1024 * 1024) return transportError('request_too_large', false)
    }
    const responses = await Promise.all(requests.map(async (request: SourceHttpRequestEnvelope): Promise<Object> => {
      const response = await executeSourceHttpRequest(JSON.stringify(request), httpContextJson)
      return JSON.parse(response) as Object
    }))
    return JSON.stringify(new SourceHttpBatchSuccessEnvelope(responses))
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
  // A verification probe has its own visible-session guard; the originating
  // worker has already ended and its search guard is intentionally released.
  const current = (): boolean => probe === undefined ?
    sourceRuntimeOperationIsCurrent(identity?.operationGuardId) &&
      SourcePrivateSessionHost.credentialRequestAllowed(identity?.privateCallId, identity?.credentialGrantId, url) : probe.current()
  if (!current()) {
    trace.finish('cancelled', 'reason=source_request_cancelled')
    return transportError('source_request_cancelled', false)
  }
  const copyMangaApi = identity !== undefined && copyMangaApiTarget(identity.sourceId, url)
  if (!copyMangaApi && probe === undefined && verifiedSourceGet !== undefined) {
    const ready = verifiedSourceGet
    if (identity !== undefined && ready.request.requestJson === requestJson &&
      ready.request.httpContextJson === httpContextJson) {
      // Other global-search sources can finish while this original read waits
      // in WAMR's queue. Only its exact request may consume the single handoff.
      verifiedSourceGet = undefined
      if (appSourceWebSessionStore.status(identity.sourceId, sourceWebOrigin(ready.request.rejectedUrl)).sessionId === ready.sessionId &&
        appSourceWebSessionStore.requestSession(identity, ready.request.rejectedUrl) !== undefined) {
        DiagnosticLogger.info('source_http', 'verification_response_reused', 'state=used_once')
        trace.finish('completed', 'state=verification_response_reused')
        return ready.responseJson
      }
    }
  }
  if (copyMangaApi) {
    if (deviceInfo.sdkApiVersion < COPY_MANGA_API_MIN_SDK) {
      trace.finish('rejected', 'reason=unsupported')
      return rcpFailure(new SourceRcpTransportFailure('unsupported'))
    }
    const forbiddenHeader = Object.keys(sourceHeaders(envelope.headers)).some((name: string): boolean =>
      ['authorization', 'proxy-authorization', 'cookie', 'host'].includes(name.toLowerCase()))
    if (probe !== undefined || method !== 'GET' || body.length > 0 || forbiddenHeader || identity?.credentialGrantId !== undefined) {
      trace.finish('rejected', 'reason=invalid_request')
      return rcpFailure(new SourceRcpTransportFailure('invalid_request'))
    }
  }
  const session = copyMangaApi || identity === undefined ? undefined : probe === undefined
    ? appSourceWebSessionStore.requestSession(identity, url)
    : appSourceWebSessionStore.pendingRequestSession(identity, url, probe.proof)
  if (probe !== undefined && (session === undefined || !probe.current())) {
    trace.finish('failed', 'reason=web_session_probe_unavailable')
    return transportError('web_session_unavailable', false)
  }
  let rcpNetworkPerformed = false
  try {
    const picaDns = envelope.dnsOverride === undefined ? undefined : sourcePicaDnsOverride(envelope.dnsOverride)
    if (picaDns !== undefined) {
      const initial = new urlKit.URL(url)
      if (initial.protocol !== 'https:' || (initial.hostname !== 'picacomic.com' && !initial.hostname.endsWith('.picacomic.com'))) {
        throw new SourceRcpTransportFailure('invalid_request')
      }
    }
    let currentUrl = url
    const requestAdmission: SourceRequestAdmission = {}
    let currentMethod = method
    let currentBody = body
    const startedAt = Date.now()
    let policyWaitMs: number = 0
    let redirects = 0
    while (true) {
    // Login input is granted only to this call and exact API origin, including redirects.
    if (!SourcePrivateSessionHost.credentialRequestAllowed(identity?.privateCallId, identity?.credentialGrantId, currentUrl)) {
      trace.finish('failed', 'reason=source_login_not_allowed')
      if (picaDns !== undefined) return rcpFailure(new SourceRcpTransportFailure('source_login_not_allowed'), rcpNetworkPerformed)
      return transportError('source_login_not_allowed', false)
    }
    const policyStartedAt: number = Date.now()
    await waitForSourceRequestSlot(identity?.sourceId ?? '', currentUrl, current, envelope.headers, requestAdmission)
    if (!current()) {
      trace.finish('cancelled', 'reason=source_request_cancelled')
      return transportError('source_request_cancelled', false)
    }
    // A rate-limit queue is not network time. Keep the original request/redirect
    // timeout budget intact once its slot becomes available.
    policyWaitMs += Math.max(0, Date.now() - policyStartedAt)
    const crossOrigin = sourceWebOrigin(currentUrl) !== sourceWebOrigin(url)
    let originalHeaders = crossOrigin && session !== undefined
      ? sourcePublicRedirectHeaders(sourceHeaders(envelope.headers)) : sourceHeaders(envelope.headers)
    if (picaDns !== undefined && crossOrigin) {
      // OkHttp drops Authorization when a redirect changes origin. The ordinary
      // transports retain their established behavior; this is only the opt-in channel path.
      const redirectedHeaders: Record<string, string> = {}
      Object.keys(originalHeaders).forEach((name: string): void => {
        if (name.toLowerCase() !== 'authorization') redirectedHeaders[name] = originalHeaders[name]
      })
      originalHeaders = redirectedHeaders
    }
    const active = session === undefined || identity === undefined ? undefined : probe === undefined
      ? appSourceWebSessionStore.requestSession(identity, currentUrl)
      : appSourceWebSessionStore.pendingRequestSession(identity, currentUrl, probe.proof)
    if (session !== undefined && active === undefined &&
      !sourceAllowsAnonymousRedirect(identity, url, currentUrl, currentMethod, currentBody, probe)) {
      trace.finish('failed', 'reason=web_session_unavailable')
      return transportError('web_session_unavailable', false)
    }
    const headers: Record<string, string> = {}
    Object.keys(originalHeaders).forEach((name: string) => {
      if (active === undefined || (name.toLowerCase() !== 'cookie' && name.toLowerCase() !== 'user-agent')) headers[name] = originalHeaders[name]
    })
    if (active !== undefined && identity !== undefined) {
      headers['User-Agent'] = active.userAgent
      const cookie = sourceSessionCookies(identity.sourceId, currentUrl, originalHeaders, active.cookie)
      if (cookie.length > 0) headers['Cookie'] = cookie
    }
    trace.info('session', 'identity=' + (identity === undefined ? 'none' : 'native') +
      ' session=' + (active === undefined ? 'none' : 'attached') +
      ' cookieState=' + (typeof headers['Cookie'] === 'string' && headers['Cookie'].length > 0 ? 'present' : 'empty') +
      ' uaSource=' + (active === undefined ? 'source' : 'webview'))
    trace.info('owner', 'operation=' + (identity?.diagnosticOperation ?? 'unknown'))
    if (active !== undefined) trace.info('clearance_cookie', 'state=' + sourceClearanceCookieState(headers['Cookie'] ?? ''))
    const remaining = session === undefined && picaDns === undefined && !copyMangaApi ? sourceTimeout(envelope.timeoutMs) :
      Math.max(1, sourceTimeout(envelope.timeoutMs) - (Date.now() - startedAt - policyWaitMs))
    let response: SourceHopResponse | undefined = undefined
    const hopStartedAt = Date.now()
    let firstHeaderMs = -1
    let usedSourceBrowserHttp = false
    if (copyMangaApi) {
      if (picaDns !== undefined) throw new SourceRcpTransportFailure('invalid_request')
      const hop = await requestSourceRcpHop(currentUrl, currentMethod, headers, currentBody, remaining, current, { freshHttp11: true })
      rcpNetworkPerformed = true
      response = new SourceHopResult(hop.status, sourceRcpResponseText(hop.bytes), hop.headers)
    } else if (picaDns !== undefined) {
      const scope = picaScope(identity, current)
      const parsed = new urlKit.URL(currentUrl)
      const host = parsed.hostname.toLowerCase()
      const matching = host === 'picacomic.com' || host.endsWith('.picacomic.com')
      const ip = matching ? await sourcePicaChannelIp(currentUrl, picaDns, scope, remaining) : undefined
      const remainingAfterDns = remaining - Math.max(0, Date.now() - hopStartedAt)
      if (remainingAfterDns <= 0) throw new SourceRcpTransportFailure('timeout')
      const hop = await requestSourcePicaHop(currentUrl, currentMethod, headers, currentBody, remainingAfterDns, scope.current, ip)
      rcpNetworkPerformed = true
      response = new SourceHopResult(hop.status, sourceRcpResponseText(hop.bytes), hop.headers)
    }
    // Only the named source/origin pairs use browser-compatible transport.
    // Request identity and grant boundaries remain with the existing owner.
    let browserProfile = ''
    if (currentMethod === 'GET' && currentBody.length === 0) {
      const origin = sourceWebOrigin(currentUrl)
      if (identity?.sourceId === 'com.simplyhentai.zh.koma' && origin === 'https://api.simply-hentai.com') {
        browserProfile = 'firefox133'
      } else if (identity?.sourceId === 'com.manhuawu.koma' && origin === 'https://www.mhua5.com') {
        browserProfile = 'chrome145'
      }
    }
    if (response === undefined && browserProfile.length > 0) {
      sourceBrowserHttpSequence += 1
      const callId = 'source-browser-http-' + sourceBrowserHttpSequence
      const requestHeaders: string[] = Object.keys(headers).map((name: string): string => name + ': ' + headers[name])
      const pending = NativeSourceRuntime.sourceBrowserHttp(callId, currentUrl, requestHeaders, remaining, browserProfile)
      const timer = setInterval(() => { if (!current()) NativeSourceRuntime.cancelSourceBrowserHttp(callId) }, 100)
      try {
        const native = await pending
        trace.info('native_transfer', 'eligible=' + native.eligible + ' code=' + native.code +
          ' status=' + native.status + ' connects=' + sourceHttpTimingMs(native.createdConnections) +
          ' ' + sourceHttpTimingText(native.performanceTiming))
        if (!current() || native.cancelled) throw new SourceBrowserHttpFailure(0)
        if (native.eligible) {
          if (native.code !== 0) throw new SourceBrowserHttpFailure(native.code === 28 ? 2300028 : 0)
          usedSourceBrowserHttp = true
          response = new SourceHopResult(native.status, native.body, sourceBrowserHttpHeaders(native.headers), native.performanceTiming)
        }
      } finally { clearInterval(timer) }
    }
    // NetworkKit owns proxy behavior when the native candidate cannot safely
    // honor the platform proxy or trust store. A non-session redirect is
    // replayed there so its existing automatic redirect semantics remain intact.
    if (response === undefined || (usedSourceBrowserHttp && session === undefined &&
      [301, 302, 303, 307, 308].includes(response.responseCode))) {
      const remainingForFallback = remaining - Math.max(0, Date.now() - hopStartedAt)
      if (remainingForFallback <= 0) throw new SourceBrowserHttpFailure(2300028)
      const request = http.createHttp()
      try {
        request.on('headersReceive', () => {
          if (firstHeaderMs < 0) firstHeaderMs = Math.max(0, Date.now() - hopStartedAt)
        })
        if (session !== undefined && !attachSourceRedirectStop(request)) {
          trace.finish('failed', 'reason=web_session_redirect_unavailable')
          return transportError('web_session_redirect_unavailable', false)
        }
        const networkResponse = await request.request(currentUrl, {
          method: sourceNetworkMethod(currentMethod),
          customMethod: currentMethod === 'GET' || currentMethod === 'POST' || currentMethod === 'HEAD' ? undefined : currentMethod,
          extraData: currentBody.length > 0 ? currentBody : undefined,
          expectDataType: http.HttpDataType.STRING, usingCache: false, header: headers,
          readTimeout: remainingForFallback, connectTimeout: remainingForFallback,
        })
        response = new SourceHopResult(networkResponse.responseCode, networkResponse.result, networkResponse.header, networkResponse.performanceTiming)
      } catch (error) {
        trace.warn('hop_failed', 'hop=' + redirects + ' headersReceived=' + (firstHeaderMs >= 0) +
          ' firstHeaderMs=' + firstHeaderMs + ' elapsedMs=' + Math.max(0, Date.now() - hopStartedAt))
        throw error as Error
      } finally { request.off('headersReceive'); request.destroy() }
    }
    trace.info('hop_response', 'hop=' + redirects + ' status=' + response.responseCode +
      ' headersReceived=' + (usedSourceBrowserHttp || firstHeaderMs >= 0) + ' firstHeaderMs=' + firstHeaderMs +
      ' elapsedMs=' + Math.max(0, Date.now() - hopStartedAt) + ' ' + sourceHttpTimingText(response.performanceTiming))
    if (probe !== undefined && !probe.current()) {
      trace.finish('failed', 'reason=web_session_probe_cancelled')
      return transportError('web_session_unavailable', false)
    }
    if (active !== undefined && identity !== undefined) {
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
    const accessSignal = sourceResponseAccessSignal(response.header)
    let challengeRequestId: string | undefined = undefined
    const optedIn = envelope.wantChallengeRequestId === true && identity?.operationGuardId !== undefined
    if (identity !== undefined && (response.responseCode === 403 ||
      ((accessSignal === 'challenge_required' || optedIn) && (response.responseCode === 401 || response.responseCode === 503)))) {
      if (response.responseCode === 403 || accessSignal === 'challenge_required') {
        appSourceWebSessionStore.observeRejectedRequest(identity, currentUrl)
      }
      const origin = sourceWebOrigin(currentUrl)
      if (!copyMangaApi && probe === undefined && method === 'GET' && body.length === 0 && requestJson.length <= 65536 &&
        origin.length > 0 && identity.webSessionOrigins.includes(origin)) {
        const key = rejectedSourceGetKey(identity.sourceId, identity.operationGuardId)
        const previous = rejectedSourceGets.get(key)
        const rejected: RejectedSourceGet = { requestJson, httpContextJson, identity, rejectedUrl: currentUrl }
        const uaNames = Object.keys(headers).filter((name: string): boolean => name.toLowerCase() === 'user-agent')
        // Ambiguous differently-cased headers do not establish one effective identity.
        const actualUa = uaNames.length === 1 ? headers[uaNames[0]] : undefined
        if (actualUa !== undefined && actualUa.trim().length > 0 && !/[\r\n]/.test(actualUa)) {
          rejected.effectiveUserAgent = actualUa
        }
        if (optedIn) {
          rejectedSourceSequence += 1
          challengeRequestId = `request-${rejectedSourceSequence}`
          let candidates = rejectedSourceCandidates.get(key)
          if (candidates === undefined) {
            candidates = new Map<string, RejectedSourceGet>()
            rejectedSourceCandidates.set(key, candidates)
          }
          candidates.set(challengeRequestId, rejected)
        }
        // Without a source-provided causal ID, two different rejected GETs
        // in one operation are ambiguous and must not be probed as one.
        if (identity.operationGuardId !== undefined && previous !== undefined &&
          (previous === null || previous.requestJson !== requestJson || previous.rejectedUrl !== currentUrl)) {
          rejectedSourceGets.set(key, null)
        } else rejectedSourceGets.set(key, rejected)
      }
    }
    if ((session !== undefined || picaDns !== undefined || copyMangaApi) && [301, 302, 303, 307, 308].includes(response.responseCode)) {
      const responseHeaders = response.header as Record<string, Object | string | number | boolean | null>
      const locationKey = Object.keys(responseHeaders).find((name: string): boolean => name.toLowerCase() === 'location')
      const locationValue = locationKey === undefined ? undefined : responseHeaders[locationKey]
      const location = copyMangaApi && Array.isArray(locationValue) && locationValue.length === 1
        ? sourceString(locationValue[0]) : sourceString(locationValue)
      if (location === undefined || redirects >= (picaDns === undefined && !copyMangaApi ? 30 : 20) ||
        Date.now() - startedAt - policyWaitMs >= sourceTimeout(envelope.timeoutMs)) {
        if (copyMangaApi) return rcpFailure(new SourceRcpTransportFailure('network_error', true))
        trace.finish('failed', 'reason=web_session_redirect_rejected')
        return transportError('web_session_redirect_rejected', false)
      }
      const nextTarget = new urlKit.URL(location, currentUrl)
      if (copyMangaApi && (nextTarget.protocol !== 'https:' || nextTarget.username.length > 0 || nextTarget.password.length > 0)) {
        return rcpFailure(new SourceRcpTransportFailure('invalid_response', true))
      }
      const nextUrl = nextTarget.toString()
      // Re-check the full next URL against this source's explicit session grant.
      const nextSession = copyMangaApi || identity === undefined ? undefined : probe === undefined
        ? appSourceWebSessionStore.requestSession(identity, nextUrl)
        : appSourceWebSessionStore.pendingRequestSession(identity, nextUrl, probe.proof)
      if (session !== undefined && nextSession === undefined && !sourceAllowsAnonymousRedirect(identity, url, nextUrl, currentMethod, currentBody, probe)) {
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
    if (accessSignal !== undefined) trace.info('access_signal', 'signal=' + accessSignal)
    trace.finish(response.responseCode >= 400 ? 'failed' : 'completed', 'status=' + response.responseCode + ' chars=' + responseBody.length)
    return JSON.stringify(new SourceHttpSuccessEnvelope(response.responseCode, responseBody, accessSignal, challengeRequestId))
    }
  } catch (_error) {
    if (envelope.dnsOverride !== undefined || _error instanceof SourceRcpTransportFailure || rcpNetworkPerformed) {
      return rcpFailure(_error as Object, rcpNetworkPerformed)
    }
    if (!current()) {
      trace.finish('cancelled', 'reason=source_request_cancelled')
      return transportError('source_request_cancelled', false)
    }
    const error = _error as BusinessError
    const platformCode = typeof error.code === 'number' && Number.isFinite(error.code) ? error.code : 0
    trace.fail(error)
    DiagnosticLogger.warn('source_http', 'transport_failed', 'platformCode=' + platformCode)
    return transportError(platformCode === 2300028 ? 'timeout' : 'network_error')
  }
}

/** One same-origin read of the exact rejected GET, while its verification sheet stays visible. */
export async function probeSourceWebSession(sourceId: string, sessionId: string, documentUrl: string,
  userAgent: string, current: () => boolean, requestHandle?: string): Promise<boolean> {
  const key = rejectedSourceGetKey(sourceId, requestHandle)
  const request = rejectedSourceGets.get(key)
  if (request === undefined || request === null || !current()) return false
  const active: ActiveSourceWebProbe = { sourceId, sessionId }
  if (activeSourceWebProbe !== undefined) return false
  activeSourceWebProbe = active
  const probe: SourceWebProbeContext = {
    proof: { sessionId, initialUrl: request.rejectedUrl, documentUrl, userAgent },
    current: (): boolean => activeSourceWebProbe === active && current(),
  }
  try {
    // Probe the Host-observed target GET; never replay the first origin's
    // sensitive headers using the target origin's pending grant.
    let probeRequestJson = request.requestJson
    const original = JSON.parse(request.requestJson) as SourceHttpRequestEnvelope
    if (sourceWebOrigin(sourceString(original.url) ?? '') !== sourceWebOrigin(request.rejectedUrl)) {
      original.url = request.rejectedUrl
      original.headers = sourcePublicRedirectHeaders(sourceHeaders(original.headers))
      probeRequestJson = JSON.stringify(original)
    }
    const responseJson = await executeSourceHttpRequest(probeRequestJson, request.httpContextJson, probe)
    if (!probe.current() || rejectedSourceGets.get(key) !== request || responseJson.length > 4 * 1024 * 1024) return false
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
