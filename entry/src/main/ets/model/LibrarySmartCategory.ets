import { Comic, ComicSourceKind, normalizeLibraryCategoryName, libraryCategoryNameKey,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH, isBuiltInLibraryCategoryName } from './ComicModels'
import type { ReaderSessionStore } from './ReaderSessionStore'
import { AppStrings } from '../i18n/AppStrings'

export type LibrarySmartFilterMethod = 'downloaded' | 'tracking' | 'hasUnread' | 'started' | 'completed' |
  'source' | 'contentRating' | 'category'
export interface LibrarySmartFilter { method: LibrarySmartFilterMethod; value?: string; exclude: boolean }
export interface LibrarySmartCategory {
  id: string
  name: string
  sortOrder: number
  createdAt: number
  updatedAt: number
  filters: LibrarySmartFilter[]
}
export interface LibrarySmartFilterContext {
  reader: ReaderSessionStore
  downloaded: Set<string>
  tracked: Set<string>
}
export const LIBRARY_SMART_FILTER_METHODS: LibrarySmartFilterMethod[] = [
  'downloaded', 'tracking', 'hasUnread', 'started', 'completed', 'source', 'contentRating', 'category',
]

export function copyLibrarySmartCategory(category: LibrarySmartCategory): LibrarySmartCategory {
  return { id: category.id, name: category.name, sortOrder: category.sortOrder, createdAt: category.createdAt,
    updatedAt: category.updatedAt, filters: category.filters.map((filter: LibrarySmartFilter): LibrarySmartFilter =>
      ({ method: filter.method, value: filter.value, exclude: filter.exclude })) }
}

export function validateLibrarySmartCategories(categories: LibrarySmartCategory[], manualNames: string[]): LibrarySmartCategory[] {
  const names = new Set<string>(manualNames.map(libraryCategoryNameKey)), ids = new Set<string>()
  return categories.map((category: LibrarySmartCategory): LibrarySmartCategory => {
    const name = normalizeLibraryCategoryName(category.name)
    if (!category.id.startsWith('smart:') || ids.has(category.id)) throw new Error('Invalid smart category identity')
    if (!name) throw new Error(AppStrings.get('library_category_error_name_empty'))
    if (name.length > LIBRARY_CATEGORY_NAME_MAX_LENGTH) throw new Error(AppStrings.format('library_category_error_name_too_long', LIBRARY_CATEGORY_NAME_MAX_LENGTH))
    if (isBuiltInLibraryCategoryName(name)) throw new Error(AppStrings.get('library_category_error_name_builtin'))
    if (names.has(libraryCategoryNameKey(name))) throw new Error(AppStrings.get('library_category_error_name_duplicate'))
    if (!Number.isFinite(category.sortOrder) || !Number.isFinite(category.createdAt) || !Number.isFinite(category.updatedAt) ||
      !Array.isArray(category.filters) || category.filters.length === 0) throw new Error('Invalid smart category rules')
    const rules = new Set<string>()
    category.filters.forEach((filter: LibrarySmartFilter): void => {
      if (!LIBRARY_SMART_FILTER_METHODS.includes(filter.method) || typeof filter.exclude !== 'boolean' ||
        (['source', 'contentRating', 'category'].includes(filter.method) && !filter.value?.trim())) throw new Error('Invalid smart category rule')
      const key = JSON.stringify([filter.method, filter.value ?? ''])
      if (rules.has(key)) throw new Error('Duplicate smart category rule')
      rules.add(key)
    })
    ids.add(category.id); names.add(libraryCategoryNameKey(name))
    const next = copyLibrarySmartCategory(category); next.name = name
    return next
  })
}

export function comicSmartSourceKey(comic: Comic): string {
  if (comic.sourceRuntimeId) return `source:${comic.sourceRuntimeId}`
  if (comic.remoteServerId) return `server:${comic.remoteServerId}`
  return comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER ? 'local' : comic.sourceKind
}

/** A missing work rating stays unknown, never inferred from the whole source's adult classification. */
export function comicSmartContentRating(comic: Comic): string { return comic.sourceMetadata?.contentRating?.trim().toLowerCase() || 'unknown' }

/** Aidoku: positive values within source/rating/category are OR; different methods are AND.
 * Exclusions apply independently. A group is a projection, never written to Comic.categoryIds.
 */
export function comicMatchesSmartCategory(comic: Comic, group: LibrarySmartCategory, context: LibrarySmartFilterContext): boolean {
  const included = new Map<string, boolean>()
  for (const filter of group.filters) {
    let matches = false
    if (filter.method === 'downloaded') matches = context.downloaded.has(comic.id)
    else if (filter.method === 'tracking') matches = context.tracked.has(comic.id)
    else if (filter.method === 'hasUnread') matches = (context.reader.unreadChapterCount(comic) ?? 0) > 0
    else if (filter.method === 'started') matches = context.reader.getProgress(comic.id) !== undefined ||
      comic.chapters.some((chapter): boolean => context.reader.isChapterRead(comic.id, chapter.id) || context.reader.getChapterProgress(comic.id, chapter.id) !== undefined)
    else if (filter.method === 'completed') matches = (comic.sourceMetadata?.status ?? comic.localMetadata?.status) === 'completed'
    else if (filter.method === 'source') matches = comicSmartSourceKey(comic) === filter.value
    else if (filter.method === 'contentRating') matches = comicSmartContentRating(comic) === filter.value
    else if (filter.method === 'category') matches = filter.value === 'uncategorized' ? !comic.categoryIds?.length :
      comic.categoryIds?.includes(filter.value ?? '') === true
    if (filter.exclude) { if (matches) return false }
    else if (filter.method === 'source' || filter.method === 'contentRating' || filter.method === 'category') {
      included.set(filter.method, (included.get(filter.method) ?? false) || matches)
    } else if (!matches) return false
  }
  return Array.from(included.values()).every((matches: boolean): boolean => matches)
}
