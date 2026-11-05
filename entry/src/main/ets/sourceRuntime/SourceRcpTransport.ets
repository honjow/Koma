import { rcp } from '@kit.RemoteCommunicationKit'
import { url, util } from '@kit.ArkTS'
import { inflateSourceGzip } from '../model/SourceRequiredImageDecodePrimitives'

export interface SourceRcpHopResponse { status: number; bytes: ArrayBuffer; headers: Object }
export interface SourceRcpHopOptions { ip?: string; maxBytes?: number; freshHttp11?: boolean }

export class SourceRcpTransportFailure extends Error {
  code: number = 0
  fixedCode: string
  networkPerformed: boolean
  constructor(reason: string, performed: boolean = false) {
    super('source HTTP transport failed')
    this.fixedCode = reason; this.networkPerformed = performed
    if (reason === 'timeout') this.code = 2300028
  }
}

export function sourceRcpPublicUrl(value: string): url.URL {
  let parsed: url.URL
  try { parsed = new url.URL(value) } catch (_error) { throw new SourceRcpTransportFailure('invalid_request') }
  if (!['http:', 'https:'].includes(parsed.protocol) || parsed.username.length > 0 || parsed.password.length > 0 ||
    /[\u0000-\u0020\u007f]/.test(value)) throw new SourceRcpTransportFailure('invalid_request')
  return parsed
}

/** A single RCP hop only. The original URL retains TLS SNI/hostname checking;
 * no CookieRepository, cache, custom certificate verifier, global DNS or proxy override is created. */
export async function requestSourceRcpHop(fullUrl: string, method: string, headers: Record<string, string>,
  body: string, timeoutMs: number, current: () => boolean, options: SourceRcpHopOptions = {},
): Promise<SourceRcpHopResponse> {
  if (!current()) throw new SourceRcpTransportFailure('source_request_cancelled')
  const parsed = sourceRcpPublicUrl(fullUrl)
  const maxBytes = options.maxBytes ?? 4 * 1024 * 1024
  const ip = options.ip
  const transfer: rcp.TransferConfiguration = {
    autoRedirect: false, timeout: { connectMs: timeoutMs, transferMs: timeoutMs, inactivityMs: timeoutMs },
  }
  if (options.freshHttp11 === true) {
    transfer.connectionReusePolicy = 'forbidden'
    transfer.httpVersionSelectCallback = (_target: rcp.URL): rcp.HttpVersion => '1.1'
  }
  const configuration: rcp.Configuration = { proxy: 'system', transfer }
  if (ip !== undefined) configuration.dns = { dnsRules: [{ host: parsed.hostname,
    port: parsed.port.length > 0 ? Number(parsed.port) : parsed.protocol === 'https:' ? 443 : 80, ipAddresses: [ip] }] }
  const request = new rcp.Request(fullUrl, method, headers, body.length > 0 ? body : undefined)
  request.configuration = configuration
  if (options.freshHttp11 === true) request.cacheControl = { noCache: true, noStore: true }
  const session = rcp.createSession()
  const chunks: Uint8Array[] = []
  let size = 0
  let failure = ''
  const cancel = (): void => { try { session.cancel(request) } catch (_error) {} }
  request.destination = (incoming: ArrayBuffer): void => {
    if (failure.length > 0) return
    size += incoming.byteLength
    if (size > maxBytes || !current()) {
      failure = size > maxBytes ? 'response_too_large' : 'source_request_cancelled'
      cancel()
      return
    }
    chunks.push(new Uint8Array(incoming).slice())
  }
  const started = Date.now()
  const timer = setInterval((): void => {
    if (failure.length > 0) return
    if (!current() || Date.now() - started >= timeoutMs) {
      failure = current() ? 'timeout' : 'source_request_cancelled'
      cancel()
    }
  }, 50)
  try {
    const response = await session.fetch(request)
    if (failure.length > 0) throw new SourceRcpTransportFailure(failure, true)
    if (!current()) throw new SourceRcpTransportFailure('source_request_cancelled', true)
    // Some platform implementations expose a body for a zero-callback response.
    if (chunks.length === 0 && response.body !== undefined) { size = response.body.byteLength; chunks.push(new Uint8Array(response.body)) }
    if (size > maxBytes) throw new SourceRcpTransportFailure('response_too_large', true)
    const bytes = new Uint8Array(size)
    let offset = 0
    chunks.forEach((chunk: Uint8Array): void => { bytes.set(chunk, offset); offset += chunk.length })
    let result = bytes.buffer as ArrayBuffer
    if (bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b) {
      const end = bytes.length
      const decodedSize = end < 18 ? 0 : (bytes[end - 4] | bytes[end - 3] << 8 | bytes[end - 2] << 16 | bytes[end - 1] << 24) >>> 0
      if (decodedSize < 1 || decodedSize > maxBytes) throw new SourceRcpTransportFailure('response_too_large', true)
      result = await inflateSourceGzip(result)
      if (result.byteLength > maxBytes) throw new SourceRcpTransportFailure('response_too_large', true)
    }
    if (!current()) throw new SourceRcpTransportFailure('source_request_cancelled', true)
    return { status: response.statusCode, bytes: result, headers: response.headers }
  } catch (error) {
    if (error instanceof SourceRcpTransportFailure) throw error
    const code = (error as SourceRcpTransportFailure).code
    throw new SourceRcpTransportFailure(failure.length > 0 ? failure : code === 1007900028 ? 'timeout' : 'network_error', true)
  } finally { clearInterval(timer); session.close() }
}

export function sourceRcpResponseText(bytes: ArrayBuffer): string {
  return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(bytes))
}
