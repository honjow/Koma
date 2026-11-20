import { Comic, CustomLibraryCategory } from './ComicModels'

export function privateLibraryCategoryIds(categories: CustomLibraryCategory[]): Set<string> {
  return new Set<string>(categories.filter((category: CustomLibraryCategory): boolean => category.isPrivate === true)
    .map((category: CustomLibraryCategory): string => category.id))
}

export function showLibraryComic(comic: Comic | undefined, privateIds: Set<string>, unlockedCategoryId: string = ''): boolean {
  const memberships = comic?.categoryIds
  if (memberships === undefined || privateIds.size === 0) return true
  return (unlockedCategoryId.length > 0 && privateIds.has(unlockedCategoryId) && memberships.includes(unlockedCategoryId)) ||
    !memberships.some((id: string): boolean => privateIds.has(id))
}
