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
import { ReaderSessionStore } from './ReaderSessionStore'
import { LibrarySmartCategory, copyLibrarySmartCategory, validateLibrarySmartCategories } from './LibrarySmartCategory'

export type LibrarySortBy = 'lastRead' | 'added' | 'title' | 'source' | 'lastUpdate' | 'latestChapter' | 'unreadCount' | 'chapterCount'
export type LibrarySortDirection = 'asc' | 'desc'

export function isLibrarySortBy(value: string | undefined): boolean {
  return value === 'lastRead' || value === 'added' || value === 'title' || value === 'source' ||
    value === 'lastUpdate' || value === 'latestChapter' || value === 'unreadCount' || value === 'chapterCount'
}

export function librarySortDirection(sortBy: LibrarySortBy, value?: string): LibrarySortDirection {
  if (value === 'asc' || value === 'desc') return value
  // Older preferences and category strategies had implicit directions.
  return sortBy === 'title' || sortBy === 'source' ? 'asc' : 'desc'
}
export type LibraryReadStateFilter = 'all' | 'unread' | 'reading' | 'completed'
export type LibraryCategoryFilter = 'all' | 'uncategorized' | string
export type LibraryCategoryDisplayCategoryId = 'all' | 'uncategorized' | string

export interface LibraryCategoryDisplayStrategy {
  categoryId: LibraryCategoryDisplayCategoryId
  sortBy: LibrarySortBy
  sortDirection?: LibrarySortDirection
  followsDefaultSort?: boolean
  readState: LibraryReadStateFilter
  updatedAt: number
}

export interface LibraryListOptions {
  sortBy?: LibrarySortBy
  sortDirection?: LibrarySortDirection
  chapterUpdateTimes?: Map<ComicId, number>
  sourceSortName?: (comic: Comic) => string
  filterSource?: ComicSourceKind[]
  filterReadState?: LibraryReadStateFilter
  filterCategoryId?: LibraryCategoryFilter
  readerSessionStore?: ReaderSessionStore
}

export interface LibraryStore {
  listSmartCategories(): LibrarySmartCategory[]
  replaceSmartCategories(categories: LibrarySmartCategory[]): void
  getComic(comicId: ComicId): Comic | undefined
  findByRemote(serverId: string, resourceId: string): Comic | undefined
  listComics(sortByTitle?: boolean): Comic[]
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
  private smartCategories: LibrarySmartCategory[] = []

  listSmartCategories(): LibrarySmartCategory[] {
    return this.smartCategories.map(copyLibrarySmartCategory).sort((a: LibrarySmartCategory, b: LibrarySmartCategory): number =>
      a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
  }

  replaceSmartCategories(categories: LibrarySmartCategory[]): void {
    const next = validateLibrarySmartCategories(categories,
      this.listCustomCategories().map((category: CustomLibraryCategory): string => category.name))
    const retainedIds = new Set<string>(next.map((category: LibrarySmartCategory): string => category.id))
    this.smartCategories.forEach((category: LibrarySmartCategory): void => {
      if (!retainedIds.has(category.id)) this.categoryDisplayStrategies.delete(category.id)
    })
    this.smartCategories = next
  }
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

  listComics(sortByTitle: boolean = true): Comic[] {
    const comics = Array.from(this.comics.values())
    // Search takes a shallow snapshot and performs the same ordering in its
    // worker. Ordinary consumers retain the established sorted list.
    if (!sortByTitle) return comics
    return comics.sort((a: Comic, b: Comic) => {
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
    const direction = librarySortDirection(sortBy, options?.sortDirection)
    const multiplier = direction === 'asc' ? 1 : -1
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
        const comic = this.comics.get(item.comicId)
        if (options?.readerSessionStore !== undefined && comic !== undefined) {
          return options.readerSessionStore.comicReadingState(comic) === readStateFilter
        }
        if (readStateFilter === 'unread') {
          return item.progress === undefined
        }
        if (readStateFilter === 'completed') {
          return item.progress !== undefined && item.progress.completed
        }
        return item.progress !== undefined && !item.progress.completed
      })

    if (sortBy === 'title' || sortBy === 'source') {
      const sourceNames = new Map<ComicId, string>()
      const sourceName = options?.sourceSortName
      if (sortBy === 'source' && sourceName !== undefined) {
        rows.forEach((row: LibraryItem): void => {
          const comic = this.comics.get(row.comicId)
          if (comic !== undefined) sourceNames.set(row.comicId, sourceName(comic))
        })
      }
      return rows.sort((a: LibraryItem, b: LibraryItem): number => {
        const comparison = sortBy === 'source' ? (sourceNames.get(a.comicId) ?? a.sourceKind)
          .localeCompare(sourceNames.get(b.comicId) ?? b.sourceKind) :
          this.sortTitleForItem(a).localeCompare(this.sortTitleForItem(b))
        return multiplier * comparison || this.compareByTitleAsc(a, b)
      })
    }
    const values = new Map<ComicId, number | undefined>()
    for (const row of rows) {
      const comic = this.comics.get(row.comicId)
      let value: number | undefined
      if (sortBy === 'added') value = row.addedAt
      else if (sortBy === 'lastRead') value = row.lastReadAt
      else if (sortBy === 'lastUpdate') value = options?.chapterUpdateTimes?.get(row.comicId)
      else if (sortBy === 'chapterCount') value = row.chapterCount
      else if (comic !== undefined && sortBy === 'unreadCount') value = options?.readerSessionStore?.unreadChapterCount(comic)
      else if (comic !== undefined && sortBy === 'latestChapter') {
        for (const chapter of comic.chapters) {
          const date = chapter.dateUpload
          if (date !== undefined && Number.isFinite(date) && date > (value ?? 0)) value = date
        }
      }
      values.set(row.comicId, value)
    }
    return rows.sort((a: LibraryItem, b: LibraryItem): number => {
      const left = values.get(a.comicId)
      const right = values.get(b.comicId)
      // Unknown dates and incomplete unread counts stay after known values
      // in either direction. Direction affects the chosen key, not the tie break.
      if (left === undefined) return right === undefined ? this.compareByAddedDesc(a, b) : 1
      if (right === undefined) return -1
      return multiplier * (left - right) || this.compareByAddedDesc(a, b)
    })
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
    const nameKeys: string[] = this.smartCategories.map((category: LibrarySmartCategory): string => libraryCategoryNameKey(category.name))
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
    this.smartCategories = []
    this.comics.clear()
    this.customCategories.clear()
    this.categoryDisplayStrategies.clear()
  }

  dumpJson(): string {
    return JSON.stringify({
      smartCategories: this.listSmartCategories(),
      comics: this.listComics(),
      customCategories: this.listCustomCategories(),
      categoryDisplayStrategies: this.listCategoryDisplayStrategies(),
    })
  }

  restoreJson(payload: string): void {
    this.smartCategories = []
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
    if (!Array.isArray(parsed) && Array.isArray(parsed['smartCategories'])) {
      this.replaceSmartCategories(parsed['smartCategories'] as LibrarySmartCategory[])
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
      sortDirection: strategy.sortDirection,
      followsDefaultSort: strategy.followsDefaultSort,
      readState: strategy.readState,
      updatedAt: strategy.updatedAt,
    }
  }

  private validateCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy {
    const categoryId = strategy.categoryId.trim()
    if (categoryId.length === 0) {
      throw new Error('Invalid category display strategy categoryId')
    }
    if (!isLibrarySortBy(strategy.sortBy)) {
      throw new Error('Invalid category display strategy sortBy')
    }
    if (strategy.sortDirection !== undefined && strategy.sortDirection !== 'asc' && strategy.sortDirection !== 'desc') {
      throw new Error('Invalid category display strategy sortDirection')
    }
    if (strategy.followsDefaultSort !== undefined && typeof strategy.followsDefaultSort !== 'boolean') {
      throw new Error('Invalid category display strategy followsDefaultSort')
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
      sortDirection: strategy.sortDirection,
      followsDefaultSort: strategy.followsDefaultSort,
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
    }) || this.smartCategories.some((category: LibrarySmartCategory): boolean => libraryCategoryNameKey(category.name) === key)
    if (duplicate) {
      throw new Error(AppStrings.get('library_category_error_name_duplicate'))
    }
    return normalizedName
  }
}
