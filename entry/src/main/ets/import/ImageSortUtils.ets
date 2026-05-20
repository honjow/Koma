export const SUPPORTED_ARCHIVE_EXTENSIONS: string[] = ['.cbz', '.zip']
export const SUPPORTED_IMAGE_EXTENSIONS: string[] = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif']

export interface NaturalSortToken {
  text: string
  numberValue?: number
}

function normalizePathSeparator(value: string): string {
  return value.replace(/\\/g, '/')
}

export function getBaseName(path: string): string {
  const normalized = normalizePathSeparator(path).trim()
  const parts = normalized.split('/').filter((part: string) => part.length > 0)
  if (parts.length === 0) {
    return normalized
  }
  return parts[parts.length - 1]
}

export function getExtension(path: string): string {
  const baseName = getBaseName(path)
  const dotIndex = baseName.lastIndexOf('.')
  if (dotIndex <= 0 || dotIndex === baseName.length - 1) {
    return ''
  }
  return baseName.substring(dotIndex).toLocaleLowerCase()
}

export function stripExtension(path: string): string {
  const baseName = getBaseName(path)
  const dotIndex = baseName.lastIndexOf('.')
  if (dotIndex <= 0) {
    return baseName
  }
  return baseName.substring(0, dotIndex)
}

export function isSupportedArchivePath(path: string): boolean {
  const extension = getExtension(path)
  return SUPPORTED_ARCHIVE_EXTENSIONS.indexOf(extension) >= 0
}

export function isSupportedImagePath(path: string): boolean {
  const extension = getExtension(path)
  return SUPPORTED_IMAGE_EXTENSIONS.indexOf(extension) >= 0
}

export function isSafeArchiveEntryPath(path: string): boolean {
  const normalized = normalizePathSeparator(path).trim()
  if (normalized.length === 0 || normalized.startsWith('/')) {
    return false
  }
  const parts = normalized.split('/')
  for (const part of parts) {
    if (part === '..') {
      return false
    }
  }
  return true
}

export function naturalSortTokens(value: string): NaturalSortToken[] {
  const normalized = normalizePathSeparator(value).trim().toLocaleLowerCase()
  const tokens: NaturalSortToken[] = []
  let index = 0

  while (index < normalized.length) {
    const code = normalized.charCodeAt(index)
    const isDigit = code >= 48 && code <= 57
    let end = index + 1
    while (end < normalized.length) {
      const nextCode = normalized.charCodeAt(end)
      const nextIsDigit = nextCode >= 48 && nextCode <= 57
      if (nextIsDigit !== isDigit) {
        break
      }
      end += 1
    }

    const text = normalized.substring(index, end)
    if (isDigit) {
      tokens.push({ text, numberValue: Number(text) })
    } else {
      tokens.push({ text })
    }
    index = end
  }

  return tokens
}

export function compareNaturalPath(a: string, b: string): number {
  const aTokens = naturalSortTokens(a)
  const bTokens = naturalSortTokens(b)
  const count = Math.min(aTokens.length, bTokens.length)

  for (let index = 0; index < count; index += 1) {
    const left = aTokens[index]
    const right = bTokens[index]
    if (left.numberValue !== undefined && right.numberValue !== undefined) {
      if (left.numberValue !== right.numberValue) {
        return left.numberValue - right.numberValue
      }
      if (left.text.length !== right.text.length) {
        return left.text.length - right.text.length
      }
      continue
    }

    const textCompare = left.text.localeCompare(right.text)
    if (textCompare !== 0) {
      return textCompare
    }
  }

  if (aTokens.length !== bTokens.length) {
    return aTokens.length - bTokens.length
  }
  return a.localeCompare(b)
}

export function sortImageEntryPaths(paths: string[]): string[] {
  const seenPaths = new Set<string>()
  return paths
    .filter((path: string) => isSafeArchiveEntryPath(path) && isSupportedImagePath(path))
    .filter((path: string) => {
      if (seenPaths.has(path)) {
        return false
      }
      seenPaths.add(path)
      return true
    })
    .sort((a: string, b: string) => compareNaturalPath(a, b))
}
