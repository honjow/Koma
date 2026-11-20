import { url } from '@kit.ArkTS'

export interface SourceWebTokenDescriptor {
  version: number
  storageKey: string
  apiOrigin: string
  verifyPath: string
  verifyIdentityPath: string[]
  imageKeyDerivation?: 'sha512_cbc'
}

/** Package-declared login destination. Credentials never belong in this metadata or settings. */
export interface SourceAuthenticationDescriptor {
  kind: 'web' | 'credentials'
  loginUrl: string
  usernameLabel?: string
  passwordLabel?: string
  credentialStorage?: 'private' | 'memory'
  userAgent?: string
  loginUrls?: string[]
  sessionCookieNames?: string[]
  webToken?: SourceWebTokenDescriptor
}

export function sourceAuthenticationOrigin(value: string): string {
  try {
    if (value.trim() !== value || /[\s\\<>"\u0000-\u001f\u007f]/.test(value)) return ''
    const parsed = new url.URL(value)
    return parsed.protocol === 'https:' && parsed.username.length === 0 && parsed.password.length === 0 &&
      parsed.hostname.length > 0 ? parsed.origin : ''
  } catch (_error) { return '' }
}

function sourceWebTokenDescriptor(value: Object, loginUrl: string): SourceWebTokenDescriptor | undefined {
  if (value === null || Array.isArray(value) || typeof value !== 'object') return undefined
  const raw = value as Record<string, Object>
  if (Object.keys(raw).some((key: string): boolean =>
    !['version', 'storageKey', 'apiOrigin', 'verifyPath', 'verifyIdentityPath', 'imageKeyDerivation'].includes(key)) ||
    raw['version'] !== 1 || typeof raw['storageKey'] !== 'string' ||
    !/^[A-Za-z0-9_.-]{1,64}$/.test(raw['storageKey'] as string) ||
    typeof raw['apiOrigin'] !== 'string' || sourceAuthenticationOrigin(raw['apiOrigin'] as string) !== raw['apiOrigin'] ||
    typeof raw['verifyPath'] !== 'string' || !/^\/[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*$/.test(raw['verifyPath'] as string) ||
    (raw['verifyPath'] as string).length > 256 ||
    !Array.isArray(raw['verifyIdentityPath']) ||
    (raw['imageKeyDerivation'] !== undefined && raw['imageKeyDerivation'] !== 'sha512_cbc')) return undefined
  const apiOrigin = raw['apiOrigin'] as string
  const loginOrigin = sourceAuthenticationOrigin(loginUrl)
  const keys = raw['verifyIdentityPath'] as Object[]
  if (keys.length < 1 || keys.length > 4) return undefined
  const verifyIdentityPath: string[] = []
  for (const key of keys) {
    if (typeof key !== 'string' || !/^[A-Za-z_][A-Za-z0-9_-]{0,63}$/.test(key) ||
      ['__proto__', 'prototype', 'constructor'].includes(key)) return undefined
    verifyIdentityPath.push(key)
  }
  // A package cannot export another site's storage to an arbitrary origin.
  // This contract supports the same origin and the conventional www/api pair.
  const website = /^https:\/\/www\.([a-z0-9-]+\.[a-z]{2,})$/.exec(loginOrigin)
  if (apiOrigin !== loginOrigin && (website === null || apiOrigin !== 'https://api.' + website[1])) return undefined
  const result: SourceWebTokenDescriptor = { version: 1, storageKey: raw['storageKey'] as string,
    apiOrigin, verifyPath: raw['verifyPath'] as string, verifyIdentityPath }
  if (raw['imageKeyDerivation'] === 'sha512_cbc') result.imageKeyDerivation = 'sha512_cbc'
  return result
}

export function sourceAuthenticationDescriptor(value: Object | undefined): SourceAuthenticationDescriptor | undefined {
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') return undefined
  const raw = value as Record<string, Object>
  if (Object.keys(raw).some((key: string): boolean =>
    !['kind', 'loginUrl', 'usernameLabel', 'passwordLabel', 'credentialStorage', 'userAgent',
      'loginUrls', 'sessionCookieNames', 'webToken'].includes(key))) return undefined
  if ((raw['kind'] !== 'web' && raw['kind'] !== 'credentials') || typeof raw['loginUrl'] !== 'string' ||
    (raw['loginUrl'] as string).length > 4096 || sourceAuthenticationOrigin(raw['loginUrl'] as string).length === 0) return undefined
  const result: SourceAuthenticationDescriptor = { kind: raw['kind'] as 'web' | 'credentials', loginUrl: raw['loginUrl'] as string }
  if (result.kind === 'credentials') {
    if (raw['credentialStorage'] !== 'private' && raw['credentialStorage'] !== 'memory') return undefined
    result.credentialStorage = raw['credentialStorage'] as 'private' | 'memory'
  } else if (raw['credentialStorage'] !== undefined) return undefined
  if (raw['webToken'] !== undefined) {
    if (result.kind !== 'web' || result.loginUrl.includes('#')) return undefined
    const webToken = sourceWebTokenDescriptor(raw['webToken'], result.loginUrl)
    if (webToken === undefined) return undefined
    result.webToken = webToken
  }
  if (raw['loginUrls'] !== undefined || raw['sessionCookieNames'] !== undefined) {
    const urls = raw['loginUrls']
    const names = raw['sessionCookieNames']
    if (result.kind !== 'credentials' || !Array.isArray(urls) || urls.length === 0 || urls.length > 8 ||
      !Array.isArray(names) || names.length === 0 || names.length > 16) return undefined
    const origins = new Set<string>()
    const loginUrls: string[] = []
    for (const candidate of urls as Object[]) {
      if (typeof candidate !== 'string' || candidate.length > 4096 || candidate.includes('#')) return undefined
      const origin = sourceAuthenticationOrigin(candidate)
      if (origin.length === 0 || origins.has(origin)) return undefined
      origins.add(origin)
      loginUrls.push(candidate)
    }
    if (!loginUrls.includes(result.loginUrl)) return undefined
    const sessionCookieNames: string[] = []
    for (const name of names as Object[]) {
      if (typeof name !== 'string' || !/^[A-Za-z0-9_.-]{1,64}$/.test(name) ||
        sessionCookieNames.includes(name)) return undefined
      sessionCookieNames.push(name)
    }
    result.loginUrls = loginUrls
    result.sessionCookieNames = sessionCookieNames
  }
  if (raw['userAgent'] !== undefined) {
    if (result.kind !== 'web' || typeof raw['userAgent'] !== 'string' ||
      (raw['userAgent'] as string).trim().length === 0 || (raw['userAgent'] as string).length > 1024 ||
      /[\u0000-\u001f\u007f]/.test(raw['userAgent'] as string)) return undefined
    result.userAgent = raw['userAgent'] as string
  }
  for (const name of ['usernameLabel', 'passwordLabel']) {
    const label = raw[name]
    if (label !== undefined && (typeof label !== 'string' || label.trim().length === 0 || label.length > 128)) return undefined
  }
  if (typeof raw['usernameLabel'] === 'string') result.usernameLabel = raw['usernameLabel'] as string
  if (typeof raw['passwordLabel'] === 'string') result.passwordLabel = raw['passwordLabel'] as string
  return result
}

export function validSourceAuthentication(value: Object | undefined, webOrigins?: string[]): boolean {
  if (value === undefined) return true
  const descriptor = sourceAuthenticationDescriptor(value)
  return descriptor !== undefined && (descriptor.kind !== 'web' ||
    (webOrigins ?? []).includes(sourceAuthenticationOrigin(descriptor.loginUrl)))
}

export function sourceAuthenticationIdentity(descriptor: SourceAuthenticationDescriptor, loginUrl: string = descriptor.loginUrl): string {
  const base = [descriptor.kind, loginUrl, descriptor.usernameLabel ?? '', descriptor.passwordLabel ?? '',
    descriptor.credentialStorage ?? '', descriptor.userAgent ?? '']
  // Leave the Asset and WebView identity of existing sources byte-for-byte intact.
  if (descriptor.loginUrls !== undefined) base.push(JSON.stringify(descriptor.loginUrls), JSON.stringify(descriptor.sessionCookieNames))
  if (descriptor.webToken !== undefined) base.push(JSON.stringify(descriptor.webToken))
  return JSON.stringify(base)
}
