import { buffer, util } from '@kit.ArkTS'
import { webview } from '@kit.ArkWeb'
import { SourceWebTokenDescriptor, sourceAuthenticationOrigin } from './SourceAuthenticationDescriptor'
import { requestSourceRcpHop, sourceRcpResponseText } from './SourceRcpTransport'

export interface SourceWebTokenValue {
  token: string
  expiresAt: number
}

export function parseSourceWebAccessToken(token: string): SourceWebTokenValue | undefined {
  if (token.length > 8192 || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) return undefined
  try {
    let payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    payload = payload.padEnd(Math.ceil(payload.length / 4) * 4, '=')
    const bytes = new util.Base64Helper().decodeSync(payload)
    const claims = JSON.parse(buffer.from(bytes).toString('utf8')) as Record<string, Object>
    const exp = claims?.['exp']
    if (typeof exp !== 'number' || !Number.isSafeInteger(exp * 1000) || !Number.isInteger(exp) || exp <= 0) return undefined
    return { token, expiresAt: exp * 1000 }
  } catch (_error) { return undefined }
}

/** Read one value in the active main document. It is never published as WebView session data. */
export async function readSourceWebAccessToken(controller: webview.WebviewController, loginOrigin: string,
  storageKey: string, current: () => boolean): Promise<string> {
  if (!current() || loginOrigin.length === 0 || sourceAuthenticationOrigin(controller.getUrl()) !== loginOrigin) return ''
  const script = 'window === window.top && window.location.origin === ' + JSON.stringify(loginOrigin) +
    ' ? window.localStorage.getItem(' + JSON.stringify(storageKey) + ') : null'
  try {
    const response = await controller.runJavaScript(script)
    if (!current() || sourceAuthenticationOrigin(controller.getUrl()) !== loginOrigin) return ''
    const value = JSON.parse(response) as Object | null
    return typeof value === 'string' && value.length <= 8192 ? value : ''
  } catch (_error) { return '' }
}

export async function verifySourceWebAccessToken(descriptor: SourceWebTokenDescriptor, value: SourceWebTokenValue,
  current: () => boolean): Promise<boolean> {
  const active = (): boolean => current() && value.expiresAt > Date.now()
  // No cookies, redirects or provider response body leave the verification call.
  const response = await requestSourceRcpHop(descriptor.apiOrigin + descriptor.verifyPath, 'GET',
    { 'Accept': 'application/json', 'Authorization': 'Bearer ' + value.token, 'Cache-Control': 'no-store' },
    '', 15000, active, { maxBytes: 64 * 1024 })
  if (!active() || response.status !== 200) return false
  const profile = JSON.parse(sourceRcpResponseText(response.bytes)) as Object
  return validSourceWebTokenIdentity(profile, descriptor.verifyIdentityPath)
}

export function validSourceWebTokenIdentity(value: Object, path: string[]): boolean {
  let id: Object = value
  for (const key of path) {
    if (id === null || typeof id !== 'object' || Array.isArray(id) || !Object.keys(id).includes(key)) return false
    id = (id as Record<string, Object>)[key]
  }
  return (typeof id === 'number' && Number.isSafeInteger(id) && id > 0) ||
    (typeof id === 'string' && /^[A-Za-z0-9][A-Za-z0-9_.@:-]{0,127}$/.test(id))
}
