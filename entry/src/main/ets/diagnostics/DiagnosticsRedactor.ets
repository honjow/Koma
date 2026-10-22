export interface DiagnosticLogEntry {
  ts: number
  level: string
  category: string
  event: string
  message: string
}

/** Only operational metadata belongs in diagnostics, never request/response bodies. */
export class DiagnosticsRedactor {
  static sanitizeEvent(entry: DiagnosticLogEntry): DiagnosticLogEntry {
    return {
      ts: entry.ts > 0 ? entry.ts : Date.now(),
      level: DiagnosticsRedactor.safeToken(entry.level),
      category: DiagnosticsRedactor.safeToken(entry.category),
      event: DiagnosticsRedactor.safeToken(entry.event),
      message: DiagnosticsRedactor.sanitizeString(entry.message),
    }
  }

  static sanitizeString(value: string): string {
    let clean = value || ''
    if (/<(?:html|div|body|script)\b/i.test(clean) || /(?:payload|responseBody|requestBody)\s*[:=]/i.test(clean)) {
      return '<omitted>'
    }
    // Drop the whole header: a Cookie can contain several secrets separated by semicolons.
    clean = clean.replace(/\b(?:Cookie|Set-Cookie|Authorization)\s*[:=][^\r\n]*/gi, '<redacted-header>')
    clean = clean.replace(/\bBearer\s+[^\s;,]+/gi, 'Bearer <redacted>')
    clean = clean.replace(/\b(?:https?|socks5|file|datashare):\/\/[^\s]+/gi, '<url>')
    clean = clean.replace(/\bdata:[^\s]+/gi, '<data>')
    clean = clean.replace(/(["']?(?:password|passphrase|passwd|token|access_token|refresh_token|api[_-]?key|secret|credential|cookie|authorization)["']?\s*[:=]\s*)(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s;,}]+)/gi, '$1<redacted>')
    clean = clean.replace(/(?:\/data\/|\/storage\/|\/Users\/|\/private\/|\/tmp\/)[^\s]+/g, '<path>')
    clean = clean.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '<email>')
    clean = clean.replace(/[\r\n\t]/g, ' ').trim()
    return clean.length > 220 ? clean.substring(0, 220) + '...' : clean
  }

  static safeToken(value: string): string {
    return (value || '').replace(/[^a-zA-Z0-9_.:-]/g, '_').substring(0, 80) || 'unknown'
  }
}
