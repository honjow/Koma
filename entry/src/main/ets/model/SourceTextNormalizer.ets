function isHexDigit(value: string): boolean {
  return (value >= '0' && value <= '9') ||
    (value >= 'a' && value <= 'f') ||
    (value >= 'A' && value <= 'F')
}

function isHexQuad(value: string): boolean {
  if (value.length !== 4) {
    return false
  }
  for (let index = 0; index < value.length; index += 1) {
    if (!isHexDigit(value.charAt(index))) {
      return false
    }
  }
  return true
}

export function decodeSourceDisplayTextEscapes(value: string): string {
  let decoded = ''
  let index = 0
  while (index < value.length) {
    if (value.charAt(index) === '\\' &&
      value.charAt(index + 1) === 'u' &&
      index + 6 <= value.length) {
      const hex = value.substring(index + 2, index + 6)
      if (isHexQuad(hex)) {
        decoded += String.fromCharCode(Number.parseInt(hex, 16))
        index += 6
        continue
      }
    }
    decoded += value.charAt(index)
    index += 1
  }
  return decoded
}

export function normalizeSourceDisplayText(value: string | undefined): string | undefined {
  if (value === undefined || value.trim().length === 0) {
    return undefined
  }
  const decoded = decodeSourceDisplayTextEscapes(value)
  return decoded.trim().length === 0 ? undefined : decoded
}

export function normalizeSourceImageUrl(value: string | undefined): string | undefined {
  const decoded = normalizeSourceDisplayText(value)
  if (decoded === undefined) {
    return undefined
  }
  const normalized = decoded.split('\\/').join('/').trim()
  if (normalized.length === 0) {
    return undefined
  }
  // DM5 emits this image for rows without a cover.  It is a search-empty
  // graphic containing page text, not artwork for the selected manga.
  if (normalized.toLocaleLowerCase().includes('/search-empty.')) {
    return undefined
  }
  if (normalized.startsWith('//')) {
    return `https:${normalized}`
  }
  return normalized
}
