export type SourceCatalogRating = 'all' | 'safe' | 'suggestive' | 'adult' | 'unknown'

export interface SourceCatalogFilters {
  // Undefined means all languages, including languages installed in the future.
  // An explicitly empty selection means none, not an accidental reset to all.
  languages?: string[]
  rating: SourceCatalogRating
}

export interface SourceLanguageGroup<T> {
  language: string
  items: T[]
}

export function sourceCatalogLanguage(language: string): string {
  const tag = language.trim().replace(/_/g, '-').toLowerCase()
  if (tag === 'zh-cn' || tag === 'zh-hans') return 'zh-Hans'
  if (tag === 'zh-tw' || tag === 'zh-hant') return 'zh-Hant'
  return tag
}

export function sourceCatalogRating(nsfw: boolean, rating: string = ''): SourceCatalogRating {
  const value = rating.trim().toLowerCase()
  if (nsfw || value === 'adult' || value === 'nsfw') return 'adult'
  if (value === 'safe') return 'safe'
  if (value === 'suggestive') return 'suggestive'
  return 'unknown'
}

export function sourceMatchesCatalogFilters(language: string, nsfw: boolean, rating: string | undefined,
  filters: SourceCatalogFilters): boolean {
  return (filters.languages === undefined || filters.languages.includes(sourceCatalogLanguage(language))) &&
    (filters.rating === 'all' || filters.rating === sourceCatalogRating(nsfw, rating))
}

export function groupSourcesByLanguage<T>(items: T[], language: (item: T) => string): SourceLanguageGroup<T>[] {
  const groups = new Map<string, T[]>()
  items.forEach((item: T): void => {
    const code = sourceCatalogLanguage(language(item))
    const group = groups.get(code)
    if (group === undefined) groups.set(code, [item])
    else group.push(item)
  })
  return Array.from(groups.keys()).sort((left: string, right: string): number => {
    if (left.length === 0) return right.length === 0 ? 0 : 1
    if (right.length === 0) return -1
    return left < right ? -1 : left > right ? 1 : 0
  }).map((code: string): SourceLanguageGroup<T> => ({ language: code, items: groups.get(code)! }))
}
