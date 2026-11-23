import { normalizeSourceLocale, sourceLocaleCandidates, SOURCE_LOCALE_LIMIT } from './SourceLocale'

export interface SourcePresentation {
  version: number
  defaultLocale?: string
  texts: Record<string, Record<string, string>>
}

const ROLES: string[] = ['name', 'description', 'author', 'authentication.usernameLabel', 'authentication.passwordLabel']

function validUnicode(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const unit = value.charCodeAt(index)
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      const next = value.charCodeAt(++index)
      if (!(next >= 0xDC00 && next <= 0xDFFF)) return false
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) return false
  }
  return true
}

/** Optional display resources never grant actions or invalidate the legacy package. */
export function normalizeSourcePresentation(value: Object | undefined): SourcePresentation | undefined {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) return undefined
  const record = value as Record<string, Object>
  const raw = record['texts']
  if (record['version'] !== 1 || raw === null || raw === undefined || typeof raw !== 'object' || Array.isArray(raw)) return undefined
  const fields = raw as Record<string, Object>
  const texts: Record<string, Record<string, string>> = {}
  for (const role of ROLES) {
    const field = fields[role]
    if (field === null || field === undefined || typeof field !== 'object' || Array.isArray(field)) continue
    const entries = field as Record<string, Object>
    const keys = Object.keys(entries)
    if (keys.length > SOURCE_LOCALE_LIMIT) continue
    const seen = new Set<string>()
    const translations: Record<string, string> = {}
    let duplicate = false
    for (const key of keys) {
      const tag = normalizeSourceLocale(key)?.toLowerCase()
      if (tag === undefined) continue
      if (seen.has(tag)) { duplicate = true; break }
      seen.add(tag)
      const text = entries[key]
      if (typeof text !== 'string' || text.trim().length === 0 || !validUnicode(text)) continue
      if (role === 'description') {
        if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) continue
      } else if (text.length > 128 || text.trim() !== text || /[\u0000-\u001f\u007f]/.test(text)) continue
      translations[tag] = text
    }
    if (!duplicate && Object.keys(translations).length > 0) {
      const ordered: Record<string, string> = {}
      Object.keys(translations).sort().forEach((tag: string): void => { ordered[tag] = translations[tag] })
      texts[role] = ordered
    }
  }
  return Object.keys(texts).length === 0 ? undefined :
    { version: 1, defaultLocale: normalizeSourceLocale(record['defaultLocale']), texts }
}

/** Resolve only display DTOs. Keep canonical authentication/manifest identity intact. */
export function resolveSourcePresentationText(literal: string, presentation: SourcePresentation | undefined,
  role: string, locale: string): string {
  if (presentation === undefined || presentation.version !== 1 || !ROLES.includes(role)) return literal
  const values = presentation.texts[role]
  if (values === undefined) return literal
  const candidates = sourceLocaleCandidates(locale).concat(sourceLocaleCandidates(presentation.defaultLocale ?? ''))
  for (const candidate of candidates) {
    const text = values[candidate.toLowerCase()]
    if (text !== undefined) return text
  }
  return literal
}
