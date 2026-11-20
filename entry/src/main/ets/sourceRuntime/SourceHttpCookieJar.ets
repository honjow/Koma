import { url as urlKit } from '@kit.ArkTS'

interface SourceHttpCookie {
  name: string
  value: string
  path: string
  expiresAt: number
}

/** Cookies set by this source's own HTTP responses, isolated from ArkWeb and account grants. */
export class SourceHttpCookieJar {
  private origins: Map<string, SourceHttpCookie[]> = new Map()

  private key(sourceId: string, packageIdentity: string, url: urlKit.URL): string {
    return JSON.stringify([sourceId, packageIdentity, url.origin])
  }

  headers(sourceId: string, packageIdentity: string, fullUrl: string, headers: Record<string, string>): Record<string, string> {
    const url = new urlKit.URL(fullUrl)
    const key = this.key(sourceId, packageIdentity, url)
    const cookies = (this.origins.get(key) ?? []).filter((cookie: SourceHttpCookie): boolean => cookie.expiresAt > Date.now())
    if (cookies.length === 0) this.origins.delete(key)
    else this.origins.set(key, cookies)
    const selected = cookies.filter((cookie: SourceHttpCookie): boolean => url.pathname === cookie.path ||
      (url.pathname.startsWith(cookie.path) && (cookie.path.endsWith('/') || url.pathname[cookie.path.length] === '/')))
      .sort((a: SourceHttpCookie, b: SourceHttpCookie): number => b.path.length - a.path.length)
    const result: Record<string, string> = {}
    let supplied = ''
    Object.keys(headers).forEach((name: string): void => {
      if (name.toLowerCase() === 'cookie') supplied = headers[name]
      else result[name] = headers[name]
    })
    const suppliedNames = new Set(supplied.split(';').map((pair: string): string => pair.split('=')[0].trim()))
    const parts = selected.filter((cookie: SourceHttpCookie): boolean => !suppliedNames.has(cookie.name))
      .map((cookie: SourceHttpCookie): string => cookie.name + '=' + cookie.value)
    if (supplied.length > 0) parts.push(supplied)
    if (parts.length > 0) result['Cookie'] = parts.join('; ')
    return result
  }

  accept(sourceId: string, packageIdentity: string, fullUrl: string, headers: Object): void {
    const url = new urlKit.URL(fullUrl)
    if (url.protocol !== 'https:') return
    const values = headers as Record<string, Object>
    const name = Object.keys(values).find((key: string): boolean => key.toLowerCase() === 'set-cookie')
    const raw = name === undefined ? undefined : values[name]
    const incoming: Object[] = typeof raw === 'string' ? [raw] : Array.isArray(raw) ? raw as Object[] : []
    const key = this.key(sourceId, packageIdentity, url)
    let cookies = (this.origins.get(key) ?? []).filter((cookie: SourceHttpCookie): boolean => cookie.expiresAt > Date.now())
    for (const value of incoming.slice(0, 64)) {
      if (typeof value !== 'string' || value.length > 4096 || /[^\x20-\x7e]/.test(value) ||
        /,\s*[^\s;=,]+=/.test(value)) continue
      const parts = value.split(';')
      const separator = parts[0].indexOf('=')
      if (separator <= 0) continue
      const name = parts[0].substring(0, separator).trim()
      const content = parts[0].substring(separator + 1).trim()
      if (!/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/.test(name) || /[\s;,\\]/.test(content)) continue
      let path = url.pathname.substring(0, url.pathname.lastIndexOf('/')) || '/'
      let expiresAt = Date.now() + 24 * 60 * 60 * 1000
      let maxAge: number | undefined = undefined
      let domain = ''
      let secure = false
      for (const part of parts.slice(1)) {
        const at = part.indexOf('=')
        const attribute = (at < 0 ? part : part.substring(0, at)).trim().toLowerCase()
        const argument = at < 0 ? '' : part.substring(at + 1).trim()
        if (attribute === 'domain') domain = argument.replace(/^\./, '').toLowerCase()
        if (attribute === 'path' && argument.startsWith('/')) path = argument
        if (attribute === 'secure') secure = true
        if (attribute === 'max-age' && /^-?\d+$/.test(argument)) maxAge = Number(argument)
        if (attribute === 'expires' && Number.isFinite(Date.parse(argument))) expiresAt = Date.parse(argument)
      }
      if (domain.length > 0 && domain !== url.hostname.toLowerCase()) continue
      if (name.startsWith('__Secure-') && !secure) continue
      if (name.startsWith('__Host-') && (!secure || path !== '/' || domain.length > 0)) continue
      if (maxAge !== undefined) expiresAt = Date.now() + Math.min(maxAge, 86400) * 1000
      cookies = cookies.filter((cookie: SourceHttpCookie): boolean => cookie.name !== name || cookie.path !== path)
      if (expiresAt > Date.now()) cookies.push({ name, value: content, path, expiresAt })
      if (cookies.length > 64) cookies.shift()
    }
    this.origins.delete(key)
    if (cookies.length > 0) this.origins.set(key, cookies)
    if (this.origins.size > 128) this.origins.delete(this.origins.keys().next().value)
  }
}

export const sourceHttpCookieJar: SourceHttpCookieJar = new SourceHttpCookieJar()
