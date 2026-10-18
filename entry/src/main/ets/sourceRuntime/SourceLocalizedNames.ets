// Package display names are descriptive metadata, never source identity.
function hasUnpairedSurrogate(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const unit = value.charCodeAt(index)
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 >= value.length) {
        return true
      }
      const next = value.charCodeAt(index + 1)
      if (next < 0xDC00 || next > 0xDFFF) {
        return true
      }
      index += 1
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true
    }
  }
  return false
}

export function normalizeSourceLocalizedNames(value: Object | undefined): Record<string, string> | undefined {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return undefined
  }
  const record = value as Record<string, Object>
  const keys = Object.keys(record)
  if (keys.length > 16) {
    return undefined
  }
  const normalized: Record<string, string> = {}
  const seen = new Set<string>()
  for (let index = 0; index < keys.length; index += 1) {
    const key = keys[index]
    const tag = key.toLowerCase()
    const raw = record[key]
    if (key.length > 63 || /[\u0000-\u001F\u007F]/.test(key) || !/^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8}){0,5}$/.test(key) ||
      seen.has(tag) || typeof raw !== 'string') {
      return undefined
    }
    const name = raw.trim()
    if (raw !== name || name.length === 0 || name.length > 128 || hasUnpairedSurrogate(raw) || /[\u0000-\u001F\u007F]/.test(raw)) {
      return undefined
    }
    seen.add(tag)
    normalized[tag] = name
  }
  const sorted: Record<string, string> = {}
  Object.keys(normalized).sort().forEach((tag: string) => {
    sorted[tag] = normalized[tag]
  })
  return sorted
}

export function isInvalidSourceLocalizedNames(value: Object | undefined): boolean {
  return value !== undefined && normalizeSourceLocalizedNames(value) === undefined
}

export function resolveSourceLocalizedName(
  baseName: string,
  names: Record<string, string> | undefined,
  locale: string,
): string {
  const normalized = normalizeSourceLocalizedNames(names)
  if (normalized === undefined) {
    return baseName
  }
  const tag = locale.toLowerCase()
  if (!/^[a-z]{2,8}(?:-[a-z0-9]{1,8}){0,5}$/.test(tag) || tag.length > 63 ||
    /[\u0000-\u001F\u007F]/.test(tag)) {
    return baseName
  }
  if (normalized[tag] !== undefined) {
    return normalized[tag]
  }
  const parts = tag.split('-')
  const language = parts[0]
  let script = ''
  let region = ''
  for (let index = 1; index < parts.length; index += 1) {
    const part = parts[index]
    if (script.length === 0 && /^[a-z]{4}$/.test(part)) {
      script = part
    } else if (region.length === 0 && (/^[a-z]{2}$/.test(part) || /^[0-9]{3}$/.test(part))) {
      region = part
    }
  }
  if (language === 'zh' && script.length === 0) {
    if (region === 'tw' || region === 'hk' || region === 'mo') {
      script = 'hant'
    } else if (region === 'cn' || region === 'sg') {
      script = 'hans'
    }
  }
  const scriptTag = language + '-' + script
  if (script.length > 0 && normalized[scriptTag] !== undefined) {
    return normalized[scriptTag]
  }
  return normalized[language] ?? baseName
}
