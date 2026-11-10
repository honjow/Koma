import { url } from '@kit.ArkTS'

export const SOURCE_FRESH_HTTP_MIN_SDK: number = 26

export interface SourceHomepageChoice { value: string; url: string }
export interface SourceHomepageChoices { setting: string; options: SourceHomepageChoice[] }
export interface SourceHttpProfile { origin: string; pathPrefix?: string; profile: string }
export interface SourceCookieOverride { origin: string; name: string; values: string[] }
export interface SourceImageUrlFallback { from: string; to: string }
export interface SourceGuestCookie { name: string; value?: string }
export interface SourceGuestCookieCapture { path: string; name: string }
export interface SourceGuestNumberedPath { prefix: string; suffix: string; numberSeparator?: string }
export interface SourceGuestHttp {
  origin: string
  exactPaths: string[]
  numberedPaths: SourceGuestNumberedPath[]
  redirectNumberedPaths?: SourceGuestNumberedPath[]
  cookies: SourceGuestCookie[]
  captures: SourceGuestCookieCapture[]
  cookieDomain?: string
}
export interface SourceLegacyChapterEncoding {
  prefix: string
  separator: string
  hexSuffixLength: number
}
export interface SourceChapterIdentityPolicy {
  workPrefix: string
  workSuffix?: string
  chapterPrefix: string
  chapterSeparator: string
  chapterSuffix?: string
  titleSeparator?: string
  encodedLegacy?: SourceLegacyChapterEncoding
}

export interface SourceDnsBootstrap {
  domain: string
  url: string
  urlSetting: string
  modeSetting: string
  modeValues: string[]
  userAgent: string
  statusKey: string
  statusValue: string
  addressesKey: string
}

/** Opt-in readiness for handing the visible verification document to its GET. */
export interface SourceRenderedDocumentPolicy {
  readySelector: string
}

export interface SourceWebsitePolicy {
  homepageChoices?: SourceHomepageChoices
  httpProfiles?: SourceHttpProfile[]
  // Opt-in only: the host may hand the visible verification page's document
  // to the exact rejected GET once. `true` keeps manual completion; an object
  // with `readySelector` lets the host close the sheet automatically when the
  // page actually contains the declared content. No background WebView opens.
  // See stageSourceWebDocument for the binding rules.
  renderedDocumentFallback?: boolean | SourceRenderedDocumentPolicy
  // Opt-in browser identity for this source's verification WebView. An empty
  // value keeps the engine default; the value must also be usable by the
  // source request so a clearance obtained here stays valid afterwards.
  webSessionUserAgent?: string
  // Opt-in: use the native engine UA with an Android token instead of the
  // OpenHarmony token Cloudflare does not recognize. Keeps Chrome/WebKit
  // versions and the mobile fingerprint consistent.
  webSessionAndroidAgent?: boolean
  // Opt-in: source HTTP reads may be served by an in-page fetch in the
  // granted WebView session when the native transport is rejected.
  webFetchBridge?: boolean
  systemWebAgentOrigins?: string[]
  publicCookieOverrides?: SourceCookieOverride[]
  dnsBootstrap?: SourceDnsBootstrap
  guestHttp?: SourceGuestHttp
  preserveRouteCover?: boolean
  routeCoverPlaceholderSuffix?: string
  mobileWebAndroidAgentOrigins?: string[]
  chapterIdentity?: SourceChapterIdentityPolicy
  publicWorkUrlDomains?: string[]
  imageUrlFallbacks?: SourceImageUrlFallback[]
}

function asRecord(value: Object | undefined): Record<string, Object> | undefined {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, Object> : undefined
}

function parsedWebUrl(value: Object | undefined): url.URL | undefined {
  if (typeof value !== 'string' || value.length > 4096 || /[\s\\]/.test(value)) return undefined
  try {
    const target = new url.URL(value)
    return (target.protocol === 'https:' || target.protocol === 'http:') && target.hostname.length > 0 &&
      target.username.length === 0 && target.password.length === 0 ? target : undefined
  } catch (_error) { return undefined }
}

function isOrigin(value: Object | undefined): boolean {
  const parsed = parsedWebUrl(value)
  return parsed !== undefined && parsed.protocol === 'https:' && parsed.origin === value
}

function safePath(value: Object): boolean {
  return typeof value === 'string' && value.length <= 256 && value.startsWith('/') && !value.startsWith('//') &&
    !/[\s#\\]/.test(value) && !value.includes('..')
}

function validGuestNumberedPaths(value: Object | undefined): boolean {
  return Array.isArray(value) && value.length <= 16 && value.every((item: Object): boolean => {
    const path = asRecord(item)
    const suffix = path?.['suffix']
    const separator = path?.['numberSeparator']
    return path !== undefined && safePath(path['prefix']) && typeof suffix === 'string' &&
      /^[A-Za-z0-9._-]{1,32}$/.test(suffix) &&
      (separator === undefined || (typeof separator === 'string' && /^[_-]$/.test(separator)))
  })
}

function validGuestHttp(value?: Object): boolean {
  if (value === undefined) return true
  const raw = asRecord(value)
  const exact = raw?.['exactPaths']
  const numbered = raw?.['numberedPaths']
  const redirects = raw?.['redirectNumberedPaths']
  const cookies = raw?.['cookies']
  const captures = raw?.['captures']
  const origin = raw?.['origin']
  const domain = raw?.['cookieDomain']
  if (!isOrigin(origin) || !Array.isArray(exact) || exact.length > 16 || !exact.every(safePath) ||
    !validGuestNumberedPaths(numbered) || (redirects !== undefined && !validGuestNumberedPaths(redirects)) ||
    !Array.isArray(cookies) || cookies.length > 16 || !Array.isArray(captures) || captures.length > 16) return false
  if (domain !== undefined) {
    const host = parsedWebUrl(origin)?.hostname ?? ''
    if (typeof domain !== 'string' || !/^[a-z0-9][a-z0-9.-]{0,252}\.[a-z]{2,63}$/.test(domain) ||
      (host !== domain && !host.endsWith('.' + domain))) return false
  }
  const names = new Set<string>()
  for (const row of cookies as Object[]) {
    const cookie = asRecord(row)
    const name = cookie?.['name']
    const fixed = cookie?.['value']
    if (typeof name !== 'string' || !/^[A-Za-z0-9_.-]{1,64}$/.test(name) || names.has(name) ||
      (fixed !== undefined && (typeof fixed !== 'string' || !/^[A-Za-z0-9_.-]{1,64}$/.test(fixed)))) return false
    names.add(name)
  }
  for (const row of captures as Object[]) {
    const capture = asRecord(row)
    const path = capture?.['path']
    const name = capture?.['name']
    if (typeof path !== 'string' || !exact.includes(path) || typeof name !== 'string' || !names.has(name)) return false
  }
  return true
}

function identityToken(value: Object | undefined): boolean {
  return typeof value === 'string' && /^[A-Za-z0-9/_:.-]{1,32}$/.test(value)
}

function validChapterIdentity(value?: Object): boolean {
  if (value === undefined) return true
  const rule = asRecord(value)
  if (rule === undefined || !identityToken(rule['workPrefix']) ||
    !identityToken(rule['chapterPrefix']) || !identityToken(rule['chapterSeparator']) ||
    (rule['workSuffix'] !== undefined && !identityToken(rule['workSuffix'])) ||
    (rule['chapterSuffix'] !== undefined && !identityToken(rule['chapterSuffix']))) return false
  const title = rule['titleSeparator']
  const encoded = rule['encodedLegacy']
  if (encoded === undefined) return typeof title === 'string' && /^[#|~]$/.test(title)
  if (title !== undefined) return false
  const legacy = asRecord(encoded)
  const suffix = legacy?.['hexSuffixLength']
  return legacy !== undefined && identityToken(legacy['prefix']) && identityToken(legacy['separator']) &&
    typeof suffix === 'number' && Number.isInteger(suffix) && suffix >= 1 && suffix <= 64
}

function declarationKey(value: Object | undefined): boolean {
  return typeof value === 'string' && /^[A-Za-z][A-Za-z0-9_-]{0,127}$/.test(value)
}

function validDnsBootstrap(value?: Object): boolean {
  if (value === undefined) return true
  const rule = asRecord(value)
  if (rule === undefined) return false
  const domain = rule['domain']
  const modes = rule['modeValues']
  const agent = rule['userAgent']
  const status = rule['statusValue']
  return typeof domain === 'string' && /^[a-z0-9][a-z0-9.-]{0,250}\.[a-z]{2,63}$/.test(domain) &&
    parsedWebUrl(rule['url']) !== undefined && declarationKey(rule['urlSetting']) &&
    declarationKey(rule['modeSetting']) && Array.isArray(modes) && modes.length > 0 && modes.length <= 16 &&
    modes.every((mode: Object): boolean => typeof mode === 'string' && /^[A-Za-z0-9_-]{1,32}$/.test(mode)) &&
    typeof agent === 'string' && /^[ -~]{1,256}$/.test(agent) && declarationKey(rule['statusKey']) &&
    typeof status === 'string' && /^[ -~]{1,64}$/.test(status) && declarationKey(rule['addressesKey'])
}

export function sourceDnsTarget(policy: SourceDnsBootstrap, fullUrl: string): boolean {
  const target = parsedWebUrl(fullUrl)
  return target !== undefined && target.protocol === 'https:' &&
    (target.hostname === policy.domain || target.hostname.endsWith('.' + policy.domain))
}

export function validSourceWebsitePolicy(value?: Object): boolean {
  if (value === undefined) return true
  const policy = asRecord(value)
  if (policy === undefined) return false
  if (!validGuestHttp(policy['guestHttp']) || !validDnsBootstrap(policy['dnsBootstrap'])) return false
  if (!validChapterIdentity(policy['chapterIdentity']) ||
    (policy['preserveRouteCover'] !== undefined && typeof policy['preserveRouteCover'] !== 'boolean')) return false
  const renderedDocument = policy['renderedDocumentFallback']
  if (renderedDocument !== undefined && typeof renderedDocument !== 'boolean') {
    const rule = asRecord(renderedDocument)
    const selector = rule?.['readySelector']
    if (rule === undefined || typeof selector !== 'string' || selector.length === 0 || selector.length > 256 ||
      /[<\\\r\n]/.test(selector)) return false
  }
  const sessionAgent = policy['webSessionUserAgent']
  if (sessionAgent !== undefined && (typeof sessionAgent !== 'string' || sessionAgent.length === 0 ||
    sessionAgent.length > 256 || /[\r\n]/.test(sessionAgent))) return false
  if (policy['webSessionAndroidAgent'] !== undefined && typeof policy['webSessionAndroidAgent'] !== 'boolean') return false
  if (policy['webFetchBridge'] !== undefined && typeof policy['webFetchBridge'] !== 'boolean') return false
  const coverSuffix = policy['routeCoverPlaceholderSuffix']
  if (coverSuffix !== undefined && (typeof coverSuffix !== 'string' || !safePath(coverSuffix))) return false
  const ordinaryOrigins = policy['mobileWebAndroidAgentOrigins']
  if (ordinaryOrigins !== undefined && (!Array.isArray(ordinaryOrigins) || ordinaryOrigins.length > 16 ||
    !ordinaryOrigins.every((origin: Object): boolean => isOrigin(origin)))) return false
  const workDomains = policy['publicWorkUrlDomains']
  if (workDomains !== undefined && (!Array.isArray(workDomains) || workDomains.length > 16 ||
    !workDomains.every((domain: Object): boolean => typeof domain === 'string' &&
      /^[a-z0-9][a-z0-9.-]{0,250}\.[a-z]{2,63}$/.test(domain)))) return false
  const imageFallbacks = policy['imageUrlFallbacks']
  if (imageFallbacks !== undefined) {
    if (!Array.isArray(imageFallbacks) || imageFallbacks.length > 8) return false
    for (const value of imageFallbacks as Object[]) {
      const rule = asRecord(value)
      if (rule === undefined || typeof rule['from'] !== 'string' || typeof rule['to'] !== 'string' ||
        !/^[a-z0-9][a-z0-9.-]{0,250}\.[a-z]{2,63}$/.test(rule['from']) ||
        !/^[a-z0-9][a-z0-9.-]{0,250}\.[a-z]{2,63}$/.test(rule['to']) || rule['from'] === rule['to']) return false
    }
  }
  const rawChoices = policy['homepageChoices']
  if (rawChoices !== undefined) {
    const choices = asRecord(rawChoices)
    const setting = choices?.['setting']
    const options = choices?.['options']
    if (typeof setting !== 'string' || !/^[A-Za-z][A-Za-z0-9_-]{0,127}$/.test(setting) ||
      !Array.isArray(options) || options.length < 1 || options.length > 16) return false
    const seen = new Set<string>()
    for (const value of options as Object[]) {
      const option = asRecord(value)
      const key = option?.['value']
      if (typeof key !== 'string' || key.length < 1 || key.length > 4096 || seen.has(key) ||
        parsedWebUrl(option?.['url']) === undefined) return false
      seen.add(key)
    }
  }
  const profiles = policy['httpProfiles']
  if (profiles !== undefined) {
    if (!Array.isArray(profiles) || profiles.length > 16) return false
    for (const value of profiles as Object[]) {
      const entry = asRecord(value)
      const prefix = entry?.['pathPrefix']
      const profile = entry?.['profile']
      if (!isOrigin(entry?.['origin']) || typeof profile !== 'string' ||
        !['firefox133', 'chrome145', 'chrome116', 'chrome131_android', 'fresh_http11'].includes(profile) ||
        (prefix !== undefined && (typeof prefix !== 'string' || !/^\/[A-Za-z0-9_./-]{0,128}$/.test(prefix) ||
          prefix.includes('..')))) return false
    }
  }
  const origins = policy['systemWebAgentOrigins']
  if (origins !== undefined && (!Array.isArray(origins) || origins.length > 16 ||
    !origins.every((origin: Object): boolean => isOrigin(origin)))) return false
  const cookies = policy['publicCookieOverrides']
  if (cookies !== undefined) {
    if (!Array.isArray(cookies) || cookies.length > 16) return false
    for (const value of cookies as Object[]) {
      const entry = asRecord(value)
      const name = entry?.['name']
      const values = entry?.['values']
      if (!isOrigin(entry?.['origin']) || typeof name !== 'string' || !/^[A-Za-z0-9_.-]{1,64}$/.test(name) ||
        !Array.isArray(values) || values.length < 1 || values.length > 16 ||
        !values.every((value: Object): boolean => typeof value === 'string' && /^[A-Za-z0-9_.-]{1,64}$/.test(value))) return false
    }
  }
  return true
}

export function selectedPolicyHomepage(policy: SourceWebsitePolicy | undefined, read: (key: string) => Object | undefined): string | undefined {
  const choices = policy?.homepageChoices
  if (choices === undefined) return undefined
  const saved = read(choices.setting)
  return choices.options.find((option: SourceHomepageChoice): boolean => option.value === saved)?.url
}

/** Rewrite only the host after a declared image host fails; path, query and cache identity stay unchanged. */
export function sourceImageFallbackUrl(policy: SourceWebsitePolicy | undefined, fullUrl: string): string | undefined {
  const rules = policy?.imageUrlFallbacks
  if (rules === undefined || rules.length === 0) return undefined
  try {
    const parsed = new url.URL(fullUrl)
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return undefined
    const rule = rules.find((item: SourceImageUrlFallback): boolean => item.from === parsed.hostname)
    if (rule === undefined) return undefined
    return `${parsed.protocol}//${rule.to}${parsed.port.length > 0 ? ':' + parsed.port : ''}` +
      `${parsed.pathname}${parsed.search}${parsed.hash}`
  } catch (_error) {
    return undefined
  }
}

export function renderedDocumentFallbackEnabled(policy: SourceWebsitePolicy | undefined): boolean {
  const value = policy?.renderedDocumentFallback
  return value === true || (value !== undefined && value !== false && typeof value === 'object')
}

export function renderedDocumentReadySelector(policy: SourceWebsitePolicy | undefined): string {
  const value = policy?.renderedDocumentFallback
  if (value === undefined || value === false || typeof value !== 'object') return ''
  const selector = (value as SourceRenderedDocumentPolicy).readySelector
  return typeof selector === 'string' ? selector : ''
}

export function declaredSourceHttpProfile(policy: SourceWebsitePolicy | undefined, fullUrl: string): string {
  const parsed = parsedWebUrl(fullUrl)
  if (parsed === undefined) return ''
  return policy?.httpProfiles?.find((profile: SourceHttpProfile): boolean => profile.origin === parsed.origin &&
    (profile.pathPrefix === undefined || parsed.pathname.startsWith(profile.pathPrefix)))?.profile ?? ''
}

export function mergeDeclaredSourceCookies(policy: SourceWebsitePolicy | undefined, fullUrl: string,
  headers: Record<string, string>, sessionCookie: string): string {
  if (policy?.publicCookieOverrides === undefined) return sessionCookie
  const parsed = parsedWebUrl(fullUrl)
  if (parsed === undefined) return sessionCookie
  const rules = policy.publicCookieOverrides.filter((rule: SourceCookieOverride): boolean => rule.origin === parsed.origin)
  if (rules.length === 0) return sessionCookie
  const original = Object.keys(headers).filter((key: string): boolean => key.toLowerCase() === 'cookie')
  if (original.length !== 1) return sessionCookie
  const requested = headers[original[0]].split(';').map((value: string): string => value.trim())
  let result = sessionCookie
  for (const rule of rules) {
    const pairs = requested.filter((pair: string): boolean => pair.startsWith(rule.name + '='))
    if (pairs.length !== 1 || !rule.values.includes(pairs[0].slice(rule.name.length + 1))) continue
    const retained = result.split(';').filter((part: string): boolean =>
      part.split('=')[0].trim() !== rule.name).join(';').trim()
    result = retained.length === 0 ? pairs[0] : retained + '; ' + pairs[0]
  }
  return result
}
