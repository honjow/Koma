import {
  Comic,
  ComicId,
  ComicSourceKind,
  CustomLibraryCategory,
  LibraryItem,
  ReadingProgress,
  CUSTOM_LIBRARY_CATEGORY_ID_PREFIX,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH,
  isBuiltInLibraryCategoryId,
  isBuiltInLibraryCategoryName,
  libraryCategoryNameKey,
  normalizeLibraryCategoryName,
  comicToLibraryItem,
  normalizeCategoryIds,
  withComicCategoryIds,
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'

export type LibrarySortBy = 'lastRead' | 'added' | 'title' | 'source'
export type LibraryReadStateFilter = 'all' | 'unread' | 'reading' | 'completed'
export type LibraryCategoryFilter = 'all' | 'uncategorized' | string
export type LibraryCategoryDisplayCategoryId = 'all' | 'uncategorized' | string

export interface LibraryCategoryDisplayStrategy {
  categoryId: LibraryCategoryDisplayCategoryId
  sortBy: LibrarySortBy
  readState: LibraryReadStateFilter
  updatedAt: number
}

export interface LibraryListOptions {
  sortBy?: LibrarySortBy
  filterSource?: ComicSourceKind[]
  filterReadState?: LibraryReadStateFilter
  filterCategoryId?: LibraryCategoryFilter
}

export interface LibraryStore {
  getComic(comicId: ComicId): Comic | undefined
  findByRemote(serverId: string, resourceId: string): Comic | undefined
  listComics(): Comic[]
  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>, options?: LibraryListOptions): LibraryItem[]
  addComic(comic: Comic): void
  upsertComic(comic: Comic): void
  removeComic(comicId: ComicId): void
  listCustomCategories(): CustomLibraryCategory[]
  replaceCustomCategories(categories: CustomLibraryCategory[]): void
  createCustomCategory(name: string, now?: number): CustomLibraryCategory
  renameCustomCategory(categoryId: string, name: string, now?: number): CustomLibraryCategory
  moveCustomCategory(categoryId: string, direction: 'up' | 'down', now?: number): boolean
  deleteCustomCategory(categoryId: string): boolean
  listCategoryDisplayStrategies(): LibraryCategoryDisplayStrategy[]
  getCategoryDisplayStrategy(categoryId: LibraryCategoryDisplayCategoryId): LibraryCategoryDisplayStrategy | undefined
  replaceCategoryDisplayStrategies(strategies: LibraryCategoryDisplayStrategy[]): void
  setCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy
  clear(): void
  dumpJson(): string
  restoreJson(payload: string): void
}

export class InMemoryLibraryStore implements LibraryStore {
  private comics: Map<ComicId, Comic> = new Map<ComicId, Comic>()
  private customCategories: Map<string, CustomLibraryCategory> = new Map<string, CustomLibraryCategory>()
  private categoryDisplayStrategies: Map<string, LibraryCategoryDisplayStrategy> = new Map<string, LibraryCategoryDisplayStrategy>()

  getComic(comicId: ComicId): Comic | undefined {
    return this.comics.get(comicId)
  }

  findByRemote(serverId: string, resourceId: string): Comic | undefined {
    return Array.from(this.comics.values()).find((comic: Comic): boolean => {
      return comic.remoteServerId === serverId && comic.remoteResourceId === resourceId
    })
  }

  listComics(): Comic[] {
    return Array.from(this.comics.values()).sort((a: Comic, b: Comic) => {
      const titleCompare = a.sortTitle.localeCompare(b.sortTitle)
      if (titleCompare !== 0) {
        return titleCompare
      }
      return a.createdAt - b.createdAt
    })
  }

  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>, options?: LibraryListOptions): LibraryItem[] {
    const sourceFilters = options?.filterSource
    const readStateFilter = options?.filterReadState ?? 'all'
    const categoryFilter = options?.filterCategoryId ?? 'all'
    const sortBy = options?.sortBy ?? 'lastRead'
    const rows: LibraryItem[] = Array.from(this.comics.values())
      .filter((comic: Comic): boolean => {
        return sourceFilters === undefined || sourceFilters.includes(comic.sourceKind)
      })
      .filter((comic: Comic): boolean => {
        if (categoryFilter === 'all') {
          return true
        }
        const categoryIds = normalizeCategoryIds(comic.categoryIds)
        if (categoryFilter === 'uncategorized') {
          return categoryIds.length === 0
        }
        return categoryIds.includes(categoryFilter)
      })
      .map((comic: Comic): LibraryItem => {
        const progress = progressByComicId === undefined ? undefined : progressByComicId.get(comic.id)
        return comicToLibraryItem(comic, progress)
      })
      .filter((item: LibraryItem): boolean => {
        if (readStateFilter === 'all') {
          return true
        }
        if (readStateFilter === 'unread') {
          return item.progress === undefined
        }
        if (readStateFilter === 'completed') {
          return item.progress !== undefined && item.progress.completed
        }
        return item.progress !== undefined && !item.progress.completed
      })

    return rows.sort((a: LibraryItem, b: LibraryItem): number => {
      if (sortBy === 'added') {
        return this.compareByAddedDesc(a, b)
      }
      if (sortBy === 'title') {
        return this.compareByTitleAsc(a, b)
      }
      if (sortBy === 'source') {
        return this.compareBySourceKind(a, b)
      }
      return this.compareByLastReadDesc(a, b)
    })
  }

  private compareByLastReadDesc(a: LibraryItem, b: LibraryItem): number {
    const lastReadCompare = (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0)
    if (lastReadCompare !== 0) {
      return lastReadCompare
    }
    return this.compareByAddedDesc(a, b)
  }

  private compareByAddedDesc(a: LibraryItem, b: LibraryItem): number {
    const addedCompare = b.addedAt - a.addedAt
    if (addedCompare !== 0) {
      return addedCompare
    }
    return this.compareByTitleAsc(a, b)
  }

  private compareByTitleAsc(a: LibraryItem, b: LibraryItem): number {
    const titleCompare = this.sortTitleForItem(a).localeCompare(this.sortTitleForItem(b))
    if (titleCompare !== 0) {
      return titleCompare
    }
    return a.addedAt - b.addedAt
  }

  private compareBySourceKind(a: LibraryItem, b: LibraryItem): number {
    const comicA = this.comics.get(a.comicId)
    const comicB = this.comics.get(b.comicId)
    const sourceA = comicA === undefined ? '' : comicA.sourceKind
    const sourceB = comicB === undefined ? '' : comicB.sourceKind
    const sourceCompare = sourceA.localeCompare(sourceB)
    if (sourceCompare !== 0) {
      return sourceCompare
    }
    return this.compareByTitleAsc(a, b)
  }

  private sortTitleForItem(item: LibraryItem): string {
    const comic = this.comics.get(item.comicId)
    return comic === undefined ? item.title : comic.sortTitle
  }

  addComic(comic: Comic): void {
    this.upsertComic(comic)
  }

  upsertComic(comic: Comic): void {
    this.comics.set(comic.id, comic)
  }

  removeComic(comicId: ComicId): void {
    this.comics.delete(comicId)
  }

  listCustomCategories(): CustomLibraryCategory[] {
    return Array.from(this.customCategories.values()).sort((a: CustomLibraryCategory, b: CustomLibraryCategory): number => {
      const sortCompare = a.sortOrder - b.sortOrder
      if (sortCompare !== 0) {
        return sortCompare
      }
      return a.createdAt - b.createdAt
    }).map((category: CustomLibraryCategory): CustomLibraryCategory => {
      return this.cloneCustomCategory(category)
    })
  }

  replaceCustomCategories(categories: CustomLibraryCategory[]): void {
    const nextCategories: Map<string, CustomLibraryCategory> = new Map<string, CustomLibraryCategory>()
    const nameKeys: string[] = []
    categories.forEach((category: CustomLibraryCategory) => {
      const restoredCategory = this.validateRestoredCustomCategory(category, nextCategories, nameKeys)
      nextCategories.set(restoredCategory.id, restoredCategory)
    })
    this.customCategories.clear()
    nextCategories.forEach((category: CustomLibraryCategory, categoryId: string) => {
      this.customCategories.set(categoryId, this.cloneCustomCategory(category))
    })
  }

  createCustomCategory(name: string, now: number = Date.now()): CustomLibraryCategory {
    const normalizedName = this.validateCustomCategoryName(name)
    const category: CustomLibraryCategory = {
      id: this.createCustomCategoryId(now),
      name: normalizedName,
      sortOrder: this.nextCustomCategorySortOrder(),
      createdAt: now,
      updatedAt: now,
    }
    this.customCategories.set(category.id, this.cloneCustomCategory(category))
    return this.cloneCustomCategory(category)
  }

  renameCustomCategory(categoryId: string, name: string, now: number = Date.now()): CustomLibraryCategory {
    const previous = this.customCategories.get(categoryId)
    if (previous === undefined) {
      throw new Error(AppStrings.get('library_category_error_missing'))
    }
    const normalizedName = this.validateCustomCategoryName(name, categoryId)
    const next: CustomLibraryCategory = {
      id: previous.id,
      name: normalizedName,
      sortOrder: previous.sortOrder,
      createdAt: previous.createdAt,
      updatedAt: now,
    }
    this.customCategories.set(categoryId, next)
    return this.cloneCustomCategory(next)
  }

  moveCustomCategory(categoryId: string, direction: 'up' | 'down', now: number = Date.now()): boolean {
    if (isBuiltInLibraryCategoryId(categoryId)) {
      return false
    }
    const categories = this.listCustomCategories()
    const index = categories.findIndex((category: CustomLibraryCategory): boolean => category.id === categoryId)
    if (index < 0) {
      return false
    }
    const targetIndex = direction === 'up' ? index - 1 : index + 1
    if (targetIndex < 0 || targetIndex >= categories.length) {
      return false
    }
    const current = categories[index]
    const target = categories[targetIndex]
    this.customCategories.set(current.id, {
      id: current.id,
      name: current.name,
      sortOrder: target.sortOrder,
      createdAt: current.createdAt,
      updatedAt: now,
    })
    this.customCategories.set(target.id, {
      id: target.id,
      name: target.name,
      sortOrder: current.sortOrder,
      createdAt: target.createdAt,
      updatedAt: now,
    })
    return true
  }

  deleteCustomCategory(categoryId: string): boolean {
    if (isBuiltInLibraryCategoryId(categoryId)) {
      return false
    }
    if (!this.customCategories.has(categoryId)) {
      return false
    }
    this.customCategories.delete(categoryId)
    this.categoryDisplayStrategies.delete(categoryId)
    this.comics.forEach((comic: Comic, comicId: ComicId) => {
      const nextCategoryIds = normalizeCategoryIds(comic.categoryIds).filter((item: string): boolean => {
        return item !== categoryId
      })
      if (normalizeCategoryIds(comic.categoryIds).length !== nextCategoryIds.length) {
        this.comics.set(comicId, withComicCategoryIds(comic, nextCategoryIds))
      }
    })
    return true
  }

  listCategoryDisplayStrategies(): LibraryCategoryDisplayStrategy[] {
    return Array.from(this.categoryDisplayStrategies.values()).map((strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy => {
      return this.cloneCategoryDisplayStrategy(strategy)
    })
  }

  getCategoryDisplayStrategy(categoryId: LibraryCategoryDisplayCategoryId): LibraryCategoryDisplayStrategy | undefined {
    const strategy = this.categoryDisplayStrategies.get(categoryId.trim())
    return strategy === undefined ? undefined : this.cloneCategoryDisplayStrategy(strategy)
  }

  replaceCategoryDisplayStrategies(strategies: LibraryCategoryDisplayStrategy[]): void {
    const nextStrategies: Map<string, LibraryCategoryDisplayStrategy> = new Map<string, LibraryCategoryDisplayStrategy>()
    strategies.forEach((strategy: LibraryCategoryDisplayStrategy) => {
      const restoredStrategy = this.validateCategoryDisplayStrategy(strategy)
      nextStrategies.set(restoredStrategy.categoryId, restoredStrategy)
    })
    this.categoryDisplayStrategies.clear()
    nextStrategies.forEach((strategy: LibraryCategoryDisplayStrategy, categoryId: string) => {
      this.categoryDisplayStrategies.set(categoryId, this.cloneCategoryDisplayStrategy(strategy))
    })
  }

  setCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy {
    const nextStrategy = this.validateCategoryDisplayStrategy(strategy)
    this.categoryDisplayStrategies.set(nextStrategy.categoryId, this.cloneCategoryDisplayStrategy(nextStrategy))
    return this.cloneCategoryDisplayStrategy(nextStrategy)
  }

  clear(): void {
    this.comics.clear()
    this.customCategories.clear()
    this.categoryDisplayStrategies.clear()
  }

  dumpJson(): string {
    return JSON.stringify({
      comics: this.listComics(),
      customCategories: this.listCustomCategories(),
      categoryDisplayStrategies: this.listCategoryDisplayStrategies(),
    })
  }

  restoreJson(payload: string): void {
    this.comics.clear()
    this.customCategories.clear()
    this.categoryDisplayStrategies.clear()
    const parsed = JSON.parse(payload) as Record<string, Object>
    const rows = Array.isArray(parsed) ? parsed as Comic[] : parsed['comics'] as Comic[]
    rows.forEach((comic: Comic) => {
      this.comics.set(comic.id, comic)
    })
    if (!Array.isArray(parsed) && Array.isArray(parsed['customCategories'])) {
      this.replaceCustomCategories(parsed['customCategories'] as CustomLibraryCategory[])
    }
    if (!Array.isArray(parsed) && Array.isArray(parsed['categoryDisplayStrategies'])) {
      this.replaceCategoryDisplayStrategies(parsed['categoryDisplayStrategies'] as LibraryCategoryDisplayStrategy[])
    }
  }

  private cloneCustomCategory(category: CustomLibraryCategory): CustomLibraryCategory {
    return {
      id: category.id,
      name: category.name,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    }
  }

  private nextCustomCategorySortOrder(): number {
    const categories = this.listCustomCategories()
    if (categories.length === 0) {
      return 0
    }
    return categories[categories.length - 1].sortOrder + 1
  }

  private cloneCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy {
    return {
      categoryId: strategy.categoryId,
      sortBy: strategy.sortBy,
      readState: strategy.readState,
      updatedAt: strategy.updatedAt,
    }
  }

  private validateCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy {
    const categoryId = strategy.categoryId.trim()
    if (categoryId.length === 0) {
      throw new Error('Invalid category display strategy categoryId')
    }
    if (
      strategy.sortBy !== 'lastRead' &&
      strategy.sortBy !== 'added' &&
      strategy.sortBy !== 'title' &&
      strategy.sortBy !== 'source'
    ) {
      throw new Error('Invalid category display strategy sortBy')
    }
    if (
      strategy.readState !== 'all' &&
      strategy.readState !== 'unread' &&
      strategy.readState !== 'reading' &&
      strategy.readState !== 'completed'
    ) {
      throw new Error('Invalid category display strategy readState')
    }
    if (!Number.isFinite(strategy.updatedAt)) {
      throw new Error('Invalid category display strategy updatedAt')
    }
    return {
      categoryId,
      sortBy: strategy.sortBy,
      readState: strategy.readState,
      updatedAt: strategy.updatedAt,
    }
  }

  private createCustomCategoryId(now: number): string {
    let index = this.customCategories.size + 1
    let id = `${CUSTOM_LIBRARY_CATEGORY_ID_PREFIX}${now}_${index}`
    while (this.customCategories.has(id)) {
      index += 1
      id = `${CUSTOM_LIBRARY_CATEGORY_ID_PREFIX}${now}_${index}`
    }
    return id
  }

  private validateRestoredCustomCategory(
    category: CustomLibraryCategory,
    nextCategories: Map<string, CustomLibraryCategory>,
    nameKeys: string[]
  ): CustomLibraryCategory {
    if (!category.id.startsWith(CUSTOM_LIBRARY_CATEGORY_ID_PREFIX) || isBuiltInLibraryCategoryId(category.id)) {
      throw new Error('Invalid custom category id')
    }
    if (nextCategories.has(category.id)) {
      throw new Error('Duplicate custom category id')
    }
    const normalizedName = normalizeLibraryCategoryName(category.name)
    if (normalizedName.length === 0) {
      throw new Error(AppStrings.get('library_category_error_name_empty'))
    }
    if (normalizedName.length > LIBRARY_CATEGORY_NAME_MAX_LENGTH) {
      throw new Error(AppStrings.format('library_category_error_name_too_long', LIBRARY_CATEGORY_NAME_MAX_LENGTH))
    }
    if (isBuiltInLibraryCategoryName(normalizedName)) {
      throw new Error(AppStrings.get('library_category_error_name_builtin'))
    }
    const nameKey = libraryCategoryNameKey(normalizedName)
    if (nameKeys.includes(nameKey)) {
      throw new Error(AppStrings.get('library_category_error_name_duplicate'))
    }
    nameKeys.push(nameKey)
    return {
      id: category.id,
      name: normalizedName,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    }
  }

  private validateCustomCategoryName(name: string, currentCategoryId?: string): string {
    const normalizedName = normalizeLibraryCategoryName(name)
    if (normalizedName.length === 0) {
      throw new Error(AppStrings.get('library_category_error_name_empty'))
    }
    if (normalizedName.length > LIBRARY_CATEGORY_NAME_MAX_LENGTH) {
      throw new Error(AppStrings.format('library_category_error_name_too_long', LIBRARY_CATEGORY_NAME_MAX_LENGTH))
    }
    if (isBuiltInLibraryCategoryName(normalizedName)) {
      throw new Error(AppStrings.get('library_category_error_name_builtin'))
    }
    const key = libraryCategoryNameKey(normalizedName)
    const duplicate = Array.from(this.customCategories.values()).some((category: CustomLibraryCategory): boolean => {
      return category.id !== currentCategoryId && libraryCategoryNameKey(category.name) === key
    })
    if (duplicate) {
      throw new Error(AppStrings.get('library_category_error_name_duplicate'))
    }
    return normalizedName
  }
}
