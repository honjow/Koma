export interface DiagnosticLogEntry {
  ts: number
  level: string
  category: string
  event: string
  message: string
}

/** Only operational metadata belongs in diagnostics, never request/response bodies. */
interface DiagnosticErrorFields {
  code?: string | number
}

export class DiagnosticsRedactor {
  // Logger, memory and file/export sinks repeat the same event. Only unchanged
  // values produced here that are stable under another redaction pass can
  // reuse a private snapshot. Return a fresh
  // copy even on a hit: neither callers nor getters can alter that snapshot.
  // Weak keys do not retain events after the existing log ring releases them.
  private static safeEvents: WeakMap<DiagnosticLogEntry, DiagnosticLogEntry> = new WeakMap<DiagnosticLogEntry, DiagnosticLogEntry>()

  static errorSummary(error: Error): string {
    try {
      const fields = error as DiagnosticErrorFields
      const code = fields.code === undefined ? 'none' : DiagnosticsRedactor.safeToken(String(fields.code))
      const reason = /^(?:reader_|koma_reader_|source_|backup_|download_|cache_|file_|search_)[a-z0-9_]+$/.test(error.message) || ['missing_chapter_page', 'network_error', 'http_error', 'timeout', 'unsupported', 'not_found', 'invalid_request', 'parse_error'].includes(error.message)
        ? error.message : 'unclassified'
      // The first stack line repeats an arbitrary message. Keep only code frames, never that header.
      const frames = (error.stack || '').split('\n').filter((line: string) => /^\s*at\s/.test(line))
        .slice(0, 3).map((line: string) => DiagnosticsRedactor.sanitizeString(line.trim())).join(';')
      return 'name=' + DiagnosticsRedactor.safeToken(error.name) + ' code=' + code + ' reason=' + reason +
        (frames.length > 0 ? ' stack=' + frames : '')
    } catch (_error) {
      return 'reason=error_details_unavailable'
    }
  }

  static sanitizeEvent(entry: DiagnosticLogEntry): DiagnosticLogEntry {
    const previous = DiagnosticsRedactor.safeEvents.get(entry)
    if (previous !== undefined && entry.ts === previous.ts && entry.level === previous.level &&
      entry.category === previous.category && entry.event === previous.event && entry.message === previous.message) {
      const copy = DiagnosticsRedactor.copyEvent(previous)
      DiagnosticsRedactor.safeEvents.set(copy, previous)
      return copy
    }
    const safe: DiagnosticLogEntry = {
      ts: entry.ts > 0 ? entry.ts : Date.now(),
      level: DiagnosticsRedactor.safeToken(entry.level),
      category: DiagnosticsRedactor.safeToken(entry.category),
      event: DiagnosticsRedactor.safeToken(entry.event),
      message: DiagnosticsRedactor.sanitizeString(entry.message),
    }
    // Preserve the original handling of malformed runtime inputs, but never
    // treat mutable nested values as a reusable primitive-value snapshot.
    if (typeof safe.ts === 'number' && safe.ts > 0 && typeof safe.level === 'string' && typeof safe.category === 'string' &&
      typeof safe.event === 'string' && typeof safe.message === 'string' &&
      DiagnosticsRedactor.sanitizeString(safe.message) === safe.message) {
      DiagnosticsRedactor.safeEvents.set(safe, DiagnosticsRedactor.copyEvent(safe))
    }
    return safe
  }

  private static copyEvent(entry: DiagnosticLogEntry): DiagnosticLogEntry {
    return { ts: entry.ts, level: entry.level, category: entry.category, event: entry.event, message: entry.message }
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
    clean = clean.replace(/(\b(?:comic|chapter|manga|pageId|work|unit|path|uri|file|pkg|owner|id)\s*=\s*)[^\s,;]+/gi, '$1<omitted>')
    clean = clean.replace(/\b(?:msg|message|errorMessage)\s*=[^\r\n]*/gi, 'message=<omitted>')
    clean = clean.replace(/[\r\n\t]/g, ' ').trim()
    return clean.length > 220 ? clean.substring(0, 220) + '...' : clean
  }

  static safeToken(value: string): string {
    return (value || '').replace(/[^a-zA-Z0-9_.:-]/g, '_').substring(0, 80) || 'unknown'
  }
}
