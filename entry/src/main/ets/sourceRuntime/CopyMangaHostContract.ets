import { url } from '@kit.ArkTS'

const COPY_MANGA_SOURCE_ID: string = 'com.copymanga.koma'
export const COPY_MANGA_API_FEATURE: string = 'source_http_copymanga_api_v1'
export const COPY_MANGA_API_MIN_SDK: number = 26

interface CopyMangaDomain { api: string; web: string }

// The pinned source's three choices pair API and public website origins.
const COPY_MANGA_DOMAINS: CopyMangaDomain[] = [
  { api: 'https://api.mangacopy.com', web: 'https://www.mangacopy.com' },
  { api: 'https://api.copy3000.com', web: 'https://www.copy3000.com' },
  { api: 'https://api.copy4000.com', web: 'https://www.copy4000.com' },
]

export function copyMangaApiTarget(sourceId: string, value: string): boolean {
  if (sourceId !== COPY_MANGA_SOURCE_ID) return false
  try {
    const target = new url.URL(value)
    return target.username.length === 0 && target.password.length === 0 &&
      target.pathname.startsWith('/api/v3/') &&
      COPY_MANGA_DOMAINS.some((domain: CopyMangaDomain): boolean => domain.api === target.origin)
  } catch (_error) { return false }
}

/** Normal website navigation only. Settings values cannot declare URLs or authorize a Web session. */
export function copyMangaSelectedHomepage(sourceId: string, declaredHomepage: string | undefined,
  readSavedDomain: () => string | number | boolean | string[] | undefined): string | undefined {
  const fallback = COPY_MANGA_DOMAINS[0]
  if (sourceId !== COPY_MANGA_SOURCE_ID || declaredHomepage !== fallback.web) return undefined
  try {
    const selected = readSavedDomain()
    return COPY_MANGA_DOMAINS.find((domain: CopyMangaDomain): boolean => domain.api === selected)?.web ?? fallback.web
  } catch (_error) { return fallback.web }
}
