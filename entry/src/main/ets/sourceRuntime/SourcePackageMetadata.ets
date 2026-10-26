import { url } from '@kit.ArkTS'

// UI-free metadata rules shared by importer, cache validation and TaskPool.
export const SOURCE_REPO_PACKAGE_ICON_FILES: string[] = [
  'icon.png', 'icon.jpg', 'icon.jpeg', 'icon.gif', 'icon.webp', 'icon.ico',
]

const SOURCE_PACKAGE_MIN_APP_VERSION_PATTERN: RegExp = /^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$/

export function isValidSourcePackageMinAppVersion(value: string | undefined): boolean {
  return value === undefined || value.length === 0 || SOURCE_PACKAGE_MIN_APP_VERSION_PATTERN.test(value)
}

export function normalizeSourceHomepage(value: Object | undefined): string | undefined {
  if (typeof value !== 'string' || value.length === 0 || value.length > 2048 ||
    /[\s\u0000-\u001f\u007f\\<>"]/.test(value) || !/^https?:\/\//i.test(value)) return undefined
  try {
    const parsed = url.URL.parseURL(value)
    if ((parsed.protocol !== 'http:' && parsed.protocol !== 'https:') || parsed.hostname.length === 0 ||
      parsed.hostname.includes('%') || parsed.username.length > 0 || parsed.password.length > 0) return undefined
    return value
  } catch (_error) {
    return undefined
  }
}
