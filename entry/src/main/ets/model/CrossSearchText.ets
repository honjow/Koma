export function normalizeSearchText(value: string): string {
  const trimmed = value.trim()
  const lower = trimmed.toLowerCase() === trimmed ? trimmed : trimmed.toLocaleLowerCase()
  let normalized = ''
  let previousWasSpace = true
  for (let index = 0; index < lower.length; index += 1) {
    const ch = lower.charAt(index)
    const code = lower.charCodeAt(index)
    const isAsciiLetter = ch >= 'a' && ch <= 'z'
    const isDigit = ch >= '0' && ch <= '9'
    const isNonAsciiText = code > 127
    if (isAsciiLetter || isDigit || isNonAsciiText) {
      normalized += ch
      previousWasSpace = false
    } else if (!previousWasSpace) {
      normalized += ' '
      previousWasSpace = true
    }
  }
  return previousWasSpace && normalized.length > 0 ? normalized.substring(0, normalized.length - 1) : normalized
}


export function searchTextMatchesQuery(value: string | undefined, query: string, compact: string): boolean {
  if (value === undefined) return false
  const text = normalizeSearchText(value)
  return text.includes(query) || text.replace(/ /g, '').includes(compact)
}
