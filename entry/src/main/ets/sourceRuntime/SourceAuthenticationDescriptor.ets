import { url } from '@kit.ArkTS'

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
}

export function sourceAuthenticationOrigin(value: string): string {
  try {
    if (value.trim() !== value || /[\s\\<>"\u0000-\u001f\u007f]/.test(value)) return ''
    const parsed = new url.URL(value)
    return parsed.protocol === 'https:' && parsed.username.length === 0 && parsed.password.length === 0 &&
      parsed.hostname.length > 0 ? parsed.origin : ''
  } catch (_error) { return '' }
}

export function sourceAuthenticationDescriptor(value: Object | undefined): SourceAuthenticationDescriptor | undefined {
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') return undefined
  const raw = value as Record<string, Object>
  if (Object.keys(raw).some((key: string): boolean =>
    !['kind', 'loginUrl', 'usernameLabel', 'passwordLabel', 'credentialStorage', 'userAgent',
      'loginUrls', 'sessionCookieNames'].includes(key))) return undefined
  if ((raw['kind'] !== 'web' && raw['kind'] !== 'credentials') || typeof raw['loginUrl'] !== 'string' ||
    (raw['loginUrl'] as string).length > 4096 || sourceAuthenticationOrigin(raw['loginUrl'] as string).length === 0) return undefined
  const result: SourceAuthenticationDescriptor = { kind: raw['kind'] as 'web' | 'credentials', loginUrl: raw['loginUrl'] as string }
  if (result.kind === 'credentials') {
    if (raw['credentialStorage'] !== 'private' && raw['credentialStorage'] !== 'memory') return undefined
    result.credentialStorage = raw['credentialStorage'] as 'private' | 'memory'
  } else if (raw['credentialStorage'] !== undefined) return undefined
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
  return JSON.stringify(base)
}
