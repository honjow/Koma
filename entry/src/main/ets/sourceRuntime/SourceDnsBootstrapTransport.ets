import { connection } from '@kit.NetworkKit'
import { url, util } from '@kit.ArkTS'
import { SourceDnsBootstrap, sourceDnsTarget } from './SourceWebsitePolicy'
import { requestSourceRcpHop, sourceRcpPublicUrl as publicUrl, sourceRcpResponseText, SourceRcpHopResponse,
  SourceRcpTransportFailure as SourceDnsTransportFailure } from './SourceRcpTransport'

export interface SourceDnsOverride { kind: string; proof: string }
export interface SourceDnsBootstrapScope {
  policy: SourceDnsBootstrap
  packageIdentity: string
  current: () => boolean
}
export interface SourceDnsBootstrapResult extends SourceRcpHopResponse {
  bodyText: string
  dnsOverride?: SourceDnsOverride
}
interface SourceDnsBootstrapPlan { packageIdentity: string; address: string; result: SourceDnsBootstrapResult }

const DNS_BOOTSTRAP_LIMIT: number = 64 * 1024
const dnsPlans = new WeakMap<SourceDnsBootstrap, SourceDnsBootstrapPlan>()

export function sourceDnsOverride(value: Object): SourceDnsOverride {
  if (value === null || Array.isArray(value) || typeof value !== 'object') throw new SourceDnsTransportFailure('invalid_request')
  const record = value as Record<string, Object>
  if (Object.keys(record).some((key: string): boolean => key !== 'kind' && key !== 'proof') ||
    record['kind'] !== 'dns_bootstrap_v1' || typeof record['proof'] !== 'string' ||
    (record['proof'] as string).length < 1 || (record['proof'] as string).length > 128) {
    throw new SourceDnsTransportFailure('invalid_request')
  }
  return { kind: 'dns_bootstrap_v1', proof: record['proof'] as string }
}

// ChannelDns accepts one IP/hostname, not a URL, userinfo, port or second address.
export function sourceDnsBootstrapAddress(value: Object): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > 253 || /[\s\u0000-\u001f\u007f/@?#%\\]/.test(value)) {
    throw new SourceDnsTransportFailure('invalid_response', true)
  }
  const text = value as string
  if (text.includes(':')) {
    // URL parsing validates a bare IPv6 literal; reject brackets/ports supplied by the source response.
    if (text.includes('[') || text.includes(']') || !/^[0-9a-fA-F:.]+$/.test(text)) throw new SourceDnsTransportFailure('invalid_response', true)
    try { new url.URL('http://[' + text + ']/') } catch (_error) { throw new SourceDnsTransportFailure('invalid_response', true) }
    return text
  }
  if (/^[0-9.]+$/.test(text)) {
    const parts = text.split('.')
    if (parts.length !== 4 || parts.some((part: string): boolean => !/^(0|[1-9][0-9]{0,2})$/.test(part) || Number(part) > 255)) {
      throw new SourceDnsTransportFailure('invalid_response', true)
    }
    return text
  }
  const name = text.endsWith('.') ? text.substring(0, text.length - 1) : text
  if (name.split('.').some((label: string): boolean => !/^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(label))) {
    throw new SourceDnsTransportFailure('invalid_response', true)
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

function requireCurrent(scope: SourceDnsBootstrapScope, performed: boolean = false): void {
  if (!scope.current()) throw new SourceDnsTransportFailure('source_request_cancelled', performed)
}

export async function requestSourceDnsHop(fullUrl: string, method: string, headers: Record<string, string>,
  body: string, timeoutMs: number, current: () => boolean, ip?: string, maxBytes?: number,
): Promise<SourceRcpHopResponse> {
  return requestSourceRcpHop(fullUrl, method, headers, body, timeoutMs, current, { ip, maxBytes })
}

/** Only the Host-selected committed preference reaches this public, unsigned preparation. */
export async function initializeSourceDnsBootstrap(initUrl: string, scope: SourceDnsBootstrapScope,
  timeoutMs: number): Promise<SourceDnsBootstrapResult> {
  requireCurrent(scope)
  // The reference retains the verified channel for the process lifetime.
  // Pending initialization is still bound to the caller's settings revision.
  const cached = dnsPlans.get(scope.policy)
  if (cached?.packageIdentity === scope.packageIdentity) return cached.result
  let nextUrl = publicUrl(initUrl).toString()
  const started = Date.now()
  for (let redirects = 0; ; redirects += 1) {
    requireCurrent(scope, redirects > 0)
    const remaining = timeoutMs - (Date.now() - started)
    if (remaining <= 0) throw new SourceDnsTransportFailure('timeout', redirects > 0)
    const response = await requestSourceDnsHop(nextUrl, 'GET', { 'User-Agent': scope.policy.userAgent, 'Accept-Encoding': 'gzip' },
      '', remaining, scope.current, undefined, DNS_BOOTSTRAP_LIMIT)
    requireCurrent(scope, true)
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = headerValue(response.headers, 'location')
      if (location === undefined || redirects >= 20) throw new SourceDnsTransportFailure('invalid_response', true)
      try { nextUrl = publicUrl(new url.URL(location, nextUrl).toString()).toString() }
      catch (_error) { throw new SourceDnsTransportFailure('invalid_response', true) }
      continue
    }
    const bodyText = sourceRcpResponseText(response.bytes)
    const result: SourceDnsBootstrapResult = { status: response.status, bytes: response.bytes, headers: response.headers, bodyText }
    if (response.status < 200 || response.status >= 300) return result
    let data: Record<string, Object>
    try { data = JSON.parse(bodyText) as Record<string, Object> } catch (_error) { throw new SourceDnsTransportFailure('invalid_response', true) }
    if (data === null || Array.isArray(data) || data[scope.policy.statusKey] !== scope.policy.statusValue || !Array.isArray(data[scope.policy.addressesKey]) ||
      (data[scope.policy.addressesKey] as Object[]).length === 0) throw new SourceDnsTransportFailure('invalid_response', true)
    const address = sourceDnsBootstrapAddress((data[scope.policy.addressesKey] as Object[])[0])
    requireCurrent(scope, true)
    const published = dnsPlans.get(scope.policy)
    if (published?.packageIdentity === scope.packageIdentity) return published.result
    result.dnsOverride = { kind: 'dns_bootstrap_v1', proof: util.generateRandomUUID(true) }
    dnsPlans.set(scope.policy, { packageIdentity: scope.packageIdentity, address, result })
    return result
  }
}

export async function sourceDnsBootstrapIp(fullUrl: string, hint: SourceDnsOverride,
  scope: SourceDnsBootstrapScope, timeoutMs: number = 60000): Promise<string> {
  requireCurrent(scope)
  if (!sourceDnsTarget(scope.policy, fullUrl)) throw new SourceDnsTransportFailure('invalid_request')
  const plan = dnsPlans.get(scope.policy)
  if (hint.kind !== 'dns_bootstrap_v1' || plan === undefined || plan.packageIdentity !== scope.packageIdentity ||
    plan.result.dnsOverride?.proof !== hint.proof) throw new SourceDnsTransportFailure('invalid_request')
  // InetAddress.getByName in the adopted reference uses the first system result,
  // even when the cached first channel address is itself a DNS hostname.
  let timer = 0
  const started = Date.now()
  const stopped = new Promise<connection.NetAddress[]>((_resolve, reject): void => {
    timer = setInterval((): void => {
      if (!scope.current() || Date.now() - started >= timeoutMs) {
        reject(new SourceDnsTransportFailure(scope.current() ? 'timeout' : 'source_request_cancelled'))
      }
    }, 50)
  })
  let resolved: connection.NetAddress[]
  try { resolved = await Promise.race([connection.getAddressesByName(plan.address), stopped]) }
  finally { clearInterval(timer) }
  requireCurrent(scope)
  if (resolved.length === 0) throw new SourceDnsTransportFailure('network_error')
  return resolved[0].address
}
