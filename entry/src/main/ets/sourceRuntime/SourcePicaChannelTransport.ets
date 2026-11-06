import { connection } from '@kit.NetworkKit'
import { url, util } from '@kit.ArkTS'
import { requestSourceRcpHop, sourceRcpPublicUrl as publicUrl, sourceRcpResponseText, SourceRcpHopResponse,
  SourceRcpTransportFailure as SourcePicaTransportFailure } from './SourceRcpTransport'

export interface SourcePicaDnsOverride { kind: string; proof: string }
export interface SourcePicaChannelScope {
  sourceId: string
  packageIdentity: string
  current: () => boolean
}
export interface SourcePicaInitializationResult extends SourceRcpHopResponse {
  bodyText: string
  dnsOverride?: SourcePicaDnsOverride
}
interface PicaChannelPlan { packageIdentity: string; address: string; result: SourcePicaInitializationResult }

const PICA_SOURCE: string = 'com.picacomic.koma'
const PICA_INIT_LIMIT: number = 64 * 1024
let publishedChannelPlan: PicaChannelPlan | undefined

export function sourcePicaDnsOverride(value: Object): SourcePicaDnsOverride {
  if (value === null || Array.isArray(value) || typeof value !== 'object') throw new SourcePicaTransportFailure('invalid_request')
  const record = value as Record<string, Object>
  if (Object.keys(record).some((key: string): boolean => key !== 'kind' && key !== 'proof') ||
    record['kind'] !== 'pica_channel_v1' || typeof record['proof'] !== 'string' ||
    (record['proof'] as string).length < 1 || (record['proof'] as string).length > 128) {
    throw new SourcePicaTransportFailure('invalid_request')
  }
  return { kind: 'pica_channel_v1', proof: record['proof'] as string }
}

// ChannelDns accepts one IP/hostname, not a URL, userinfo, port or second address.
export function sourcePicaChannelAddress(value: Object): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > 253 || /[\s\u0000-\u001f\u007f/@?#%\\]/.test(value)) {
    throw new SourcePicaTransportFailure('invalid_response', true)
  }
  const text = value as string
  if (text.includes(':')) {
    // URL parsing validates a bare IPv6 literal; reject brackets/ports supplied by the source response.
    if (text.includes('[') || text.includes(']') || !/^[0-9a-fA-F:.]+$/.test(text)) throw new SourcePicaTransportFailure('invalid_response', true)
    try { new url.URL('http://[' + text + ']/') } catch (_error) { throw new SourcePicaTransportFailure('invalid_response', true) }
    return text
  }
  if (/^[0-9.]+$/.test(text)) {
    const parts = text.split('.')
    if (parts.length !== 4 || parts.some((part: string): boolean => !/^(0|[1-9][0-9]{0,2})$/.test(part) || Number(part) > 255)) {
      throw new SourcePicaTransportFailure('invalid_response', true)
    }
    return text
  }
  const name = text.endsWith('.') ? text.substring(0, text.length - 1) : text
  if (name.split('.').some((label: string): boolean => !/^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(label))) {
    throw new SourcePicaTransportFailure('invalid_response', true)
  }
  return text
}

function headerValue(headers: Object, name: string): string | undefined {
  const fields = headers as Record<string, Object>
  const key = Object.keys(fields).find((key: string): boolean => key.toLowerCase() === name)
  if (key === undefined) return undefined
  const value = fields[key]
  return typeof value === 'string' ? value : undefined
}

function requireCurrent(scope: SourcePicaChannelScope, performed: boolean = false): void {
  if (scope.sourceId !== PICA_SOURCE || !scope.current()) throw new SourcePicaTransportFailure('source_request_cancelled', performed)
}

export async function requestSourcePicaHop(fullUrl: string, method: string, headers: Record<string, string>,
  body: string, timeoutMs: number, current: () => boolean, ip?: string, maxBytes?: number,
): Promise<SourceRcpHopResponse> {
  return requestSourceRcpHop(fullUrl, method, headers, body, timeoutMs, current, { ip, maxBytes })
}

/** Only the Host-selected committed preference reaches this public, unsigned preparation. */
export async function initializeSourcePicaChannel(initUrl: string, scope: SourcePicaChannelScope,
  timeoutMs: number): Promise<SourcePicaInitializationResult> {
  requireCurrent(scope)
  // The reference retains the verified channel for the process lifetime.
  // Pending initialization is still bound to the caller's settings revision.
  if (publishedChannelPlan?.packageIdentity === scope.packageIdentity) return publishedChannelPlan.result
  let nextUrl = publicUrl(initUrl).toString()
  const started = Date.now()
  for (let redirects = 0; ; redirects += 1) {
    requireCurrent(scope, redirects > 0)
    const remaining = timeoutMs - (Date.now() - started)
    if (remaining <= 0) throw new SourcePicaTransportFailure('timeout', redirects > 0)
    const response = await requestSourcePicaHop(nextUrl, 'GET', { 'User-Agent': 'okhttp/3.8.1', 'Accept-Encoding': 'gzip' },
      '', remaining, scope.current, undefined, PICA_INIT_LIMIT)
    requireCurrent(scope, true)
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = headerValue(response.headers, 'location')
      if (location === undefined || redirects >= 20) throw new SourcePicaTransportFailure('invalid_response', true)
      try { nextUrl = publicUrl(new url.URL(location, nextUrl).toString()).toString() }
      catch (_error) { throw new SourcePicaTransportFailure('invalid_response', true) }
      continue
    }
    const bodyText = sourceRcpResponseText(response.bytes)
    const result: SourcePicaInitializationResult = { status: response.status, bytes: response.bytes, headers: response.headers, bodyText }
    if (response.status < 200 || response.status >= 300) return result
    let data: Record<string, Object>
    try { data = JSON.parse(bodyText) as Record<string, Object> } catch (_error) { throw new SourcePicaTransportFailure('invalid_response', true) }
    if (data === null || Array.isArray(data) || data['status'] !== 'ok' || !Array.isArray(data['addresses']) ||
      (data['addresses'] as Object[]).length === 0) throw new SourcePicaTransportFailure('invalid_response', true)
    const address = sourcePicaChannelAddress((data['addresses'] as Object[])[0])
    requireCurrent(scope, true)
    result.dnsOverride = { kind: 'pica_channel_v1', proof: util.generateRandomUUID(true) }
    publishedChannelPlan = { packageIdentity: scope.packageIdentity, address, result }
    return result
  }
}

export async function sourcePicaChannelIp(fullUrl: string, hint: SourcePicaDnsOverride,
  scope: SourcePicaChannelScope, timeoutMs: number = 60000): Promise<string> {
  requireCurrent(scope)
  const target = publicUrl(fullUrl)
  const host = target.hostname.toLowerCase()
  if (target.protocol !== 'https:' || (host !== 'picacomic.com' && !host.endsWith('.picacomic.com'))) {
    throw new SourcePicaTransportFailure('invalid_request')
  }
  const plan = publishedChannelPlan
  if (hint.kind !== 'pica_channel_v1' || plan === undefined || plan.packageIdentity !== scope.packageIdentity ||
    plan.result.dnsOverride?.proof !== hint.proof) throw new SourcePicaTransportFailure('invalid_request')
  // InetAddress.getByName in the adopted reference uses the first system result,
  // even when the cached first channel address is itself a DNS hostname.
  let timer = 0
  const started = Date.now()
  const stopped = new Promise<connection.NetAddress[]>((_resolve, reject): void => {
    timer = setInterval((): void => {
      if (!scope.current() || Date.now() - started >= timeoutMs) {
        reject(new SourcePicaTransportFailure(scope.current() ? 'timeout' : 'source_request_cancelled'))
      }
    }, 50)
  })
  let resolved: connection.NetAddress[]
  try { resolved = await Promise.race([connection.getAddressesByName(plan.address), stopped]) }
  finally { clearInterval(timer) }
  requireCurrent(scope)
  if (resolved.length === 0) throw new SourcePicaTransportFailure('network_error')
  return resolved[0].address
}
