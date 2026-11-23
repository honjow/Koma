// Pure protocol helpers: this module is also loaded by TaskPool workers.
export const SOURCE_LOCALIZATION_FEATURE: string = 'source_localization_v1'
export const SOURCE_LOCALE_LIMIT: number = 16

export interface SourceEnvironment {
  version: number
  uiLocale: string
  localeFallbacks: string[]
}

export function normalizeSourceLocale(value: Object | undefined): string | undefined {
  if (typeof value !== 'string' || value.length > 63 ||
    !/^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8}){0,5}$/.test(value)) return undefined
  const parts = value.split('-')
  return parts.map((part: string, index: number): string => {
    if (index === 0) return part.toLowerCase()
    if (/^[A-Za-z]{4}$/.test(part)) return part[0].toUpperCase() + part.slice(1).toLowerCase()
    if (/^[A-Za-z]{2}$/.test(part)) return part.toUpperCase()
    return part.toLowerCase()
  }).join('-')
}

/** Exact region entries precede inferred scripts. Never infer Hans from Hant. */
export function sourceLocaleCandidates(value: string): string[] {
  const locale = normalizeSourceLocale(value)
  if (locale === undefined) return []
  const parts = locale.split('-')
  const language = parts[0]
  const explicitScript = parts.slice(1).find((part: string): boolean => /^[A-Z][a-z]{3}$/.test(part))
  const region = parts.slice(1).find((part: string): boolean => /^[A-Z]{2}$/.test(part) || /^[0-9]{3}$/.test(part))
  let script = explicitScript
  if (language === 'zh' && script === undefined) {
    if (region === 'TW' || region === 'HK' || region === 'MO') script = 'Hant'
    else if (region === 'CN' || region === 'SG') script = 'Hans'
  }
  const candidates: string[] = [locale]
  const add = (tag: string): void => { if (!candidates.includes(tag)) candidates.push(tag) }
  if (script !== undefined) {
    if (region !== undefined) add(language + '-' + script + '-' + region)
    add(language + '-' + script)
  } else if (region !== undefined) add(language + '-' + region)
  add(language)
  return candidates
}

export function sourceEnvironmentForLocale(locale: string): SourceEnvironment | undefined {
  const normalized = normalizeSourceLocale(locale)
  return normalized === undefined ? undefined :
    { version: 1, uiLocale: normalized, localeFallbacks: sourceLocaleCandidates(normalized) }
}

export function normalizeSourceEnvironment(value: Object | undefined): SourceEnvironment | undefined {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) return undefined
  const record = value as Record<string, Object>
  if (record['version'] !== 1 || typeof record['uiLocale'] !== 'string' ||
    !Array.isArray(record['localeFallbacks']) || record['localeFallbacks'].length > SOURCE_LOCALE_LIMIT) return undefined
  const environment = sourceEnvironmentForLocale(record['uiLocale'] as string)
  if (environment === undefined) return undefined
  const candidates = record['localeFallbacks'] as Object[]
  // The wire list is the complete canonical chain: do not deduplicate away
  // extra/duplicate input before validation. SDK and Host share this contract.
  if (candidates.length !== environment.localeFallbacks.length ||
    candidates.some((candidate: Object, index: number): boolean =>
      normalizeSourceLocale(candidate) !== environment.localeFallbacks[index])) return undefined
  return environment
}
