import { util } from '@kit.ArkTS'
import {
  Chapter,
  ChapterId,
  Comic,
  ComicId,
  ComicSourceKind,
  CustomLibraryCategory,
  LibraryItem,
  ReadingProgress,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH,
  isManualLibraryCategoryId,
  libraryCategoryNameKey,
  normalizeLibraryCategoryName,
  comicToLibraryItem,
  currentComicReadingProgress,
  normalizeCategoryIds,
  withComicCategoryIds,
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { ReaderSessionStore } from './ReaderSessionStore'
import { LibrarySmartCategory, copyLibrarySmartCategory, validateLibrarySmartCategories } from './LibrarySmartCategory'
import { SyncLocalShelfMove } from '../deviceSync/DeviceSyncSignals'
import { MihonImportRecord, MihonImportWork } from './MihonBackupReader'

export type LibrarySortBy = 'lastRead' | 'added' | 'title' | 'source' | 'lastUpdate' | 'latestChapter' | 'unreadCount' | 'chapterCount'

/** Unknown times stay after known times in either direction. */
export function compareShelfTime(a: number | undefined, b: number | undefined, direction: LibrarySortDirection): number {
  if (a === undefined) return b === undefined ? 0 : 1
  if (b === undefined) return -1
  return (direction === 'asc' ? 1 : -1) * (a - b)
}
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

export interface LibraryShelfSourceFacet {
  sourceKind: ComicSourceKind
  remoteServerId?: string
  sourceRuntimeId?: string
  contentRating?: string
}

export interface LibraryWorkSummaryReader {
  work: (id: ComicId) => Comic | undefined
  category: (id: LibraryCategoryFilter) => Comic[]
  kinds: (kinds: ComicSourceKind[]) => Comic[]
  source?: (sourceId: string) => Comic[]
  identity: (owner: string, work: string, remote: boolean) => Comic[]
  hasWorks: () => boolean
  categoryCounts?: () => Map<string, number>
  sourceFacets?: () => LibraryShelfSourceFacet[]
  chapterIdsBatch?: (comicIds: ComicId[]) => Map<ComicId, ChapterId[]>
}

export interface LibraryStore {
  listMihonImportWorks(): MihonImportWork[]
  getMihonImportWork(id: string): MihonImportWork | undefined
  readMihonImport(id: string): MihonImportRecord | undefined
  listMihonImports(): MihonImportRecord[]
  restoreMihonImportWorks(readWorks: () => MihonImportWork[], readOriginals: (id?: string) => MihonImportRecord[]): void
  replaceMihonImports(records: MihonImportRecord[]): void
  updateMihonImports(records: MihonImportRecord[]): void
  updateMihonSourceMatches(records: MihonImportWork[]): void
  listSyncShelfMoves(): SyncLocalShelfMove[]
  replaceSyncShelfMoves(moves: SyncLocalShelfMove[]): void
  listSmartCategories(): LibrarySmartCategory[]
  replaceSmartCategories(categories: LibrarySmartCategory[], allowSavedNameCollisions?: boolean): void
  getComicSummary(comicId: ComicId): Comic | undefined
  listComicSummaries(sortByTitle?: boolean): Comic[]
  listShelfSummaries(category: LibraryCategoryFilter): Comic[]
  listComicSummariesByKind(kinds: ComicSourceKind[]): Comic[]
  listSourceComicSummaries(sourceId: string): Comic[]
  listCategoryUsageCounts(): Map<string, number>
  listSourceFacets(): LibraryShelfSourceFacet[]
  shelfProgress(comic: Comic, progress?: ReadingProgress): ReadingProgress | undefined
  deferWorkSummaries(category: LibraryCategoryFilter, source: LibraryWorkSummaryReader): void
  readComicChapter(comicId: ComicId, chapterId: ChapterId): Chapter | undefined
  readComicChapterTitle(comicId: ComicId, chapterId?: ChapterId): string | undefined
  listComicChapterIds(comicId: ComicId): ChapterId[]
  listComicsChapterIds(comicIds: ComicId[]): Map<ComicId, ChapterId[]>
  deferCatalogs(read: (comic: Comic, chapterId?: ChapterId) => Chapter[],
    title: (comicId: ComicId, chapterId?: ChapterId) => string | undefined, ids: (comicId: ComicId) => ChapterId[]): void
  getComic(comicId: ComicId): Comic | undefined
  findByRemote(serverId: string, resourceId: string): Comic | undefined
  findBySourceManga(sourceId: string, mangaId: string, sortByTitle?: boolean): Comic | undefined
  hasComics(): boolean
  listComics(sortByTitle?: boolean): Comic[]
  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>, options?: LibraryListOptions): LibraryItem[]
  listReadLibraryItems(progressByComicId: Map<ComicId, ReadingProgress>): LibraryItem[]
  addComic(comic: Comic): void
  upsertComic(comic: Comic): void
  removeComic(comicId: ComicId): void
  orderComics(comicIds: ComicId[]): void
  listCustomCategories(): CustomLibraryCategory[]
  replaceCustomCategories(categories: CustomLibraryCategory[]): void
  createCustomCategory(name: string, now?: number): CustomLibraryCategory
  renameCustomCategory(categoryId: string, name: string, now?: number): CustomLibraryCategory
  setCustomCategoryPrivacy(categoryId: string, isPrivate: boolean, now?: number): boolean
  moveCustomCategory(categoryId: string, destinationId: string, now?: number): boolean
  moveSmartCategory(categoryId: string, destinationId: string, now?: number): boolean
  deleteCustomCategory(categoryId: string, memberIds?: string[]): boolean
  listCategoryDisplayStrategies(): LibraryCategoryDisplayStrategy[]
  getCategoryDisplayStrategy(categoryId: LibraryCategoryDisplayCategoryId): LibraryCategoryDisplayStrategy | undefined
  replaceCategoryDisplayStrategies(strategies: LibraryCategoryDisplayStrategy[]): void
  setCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): LibraryCategoryDisplayStrategy
  clear(): void
  restoreJson(payload: string): void
}

export interface LibraryContents {
  comics: Comic[]
  customCategories: CustomLibraryCategory[]
  smartCategories: LibrarySmartCategory[]
  displayStrategies: LibraryCategoryDisplayStrategy[]
  shelfMoves: SyncLocalShelfMove[]
  mihonImports: MihonImportRecord[]
}

export function libraryContents(source: LibraryStore): LibraryContents {
  return { comics: source.listComics(false), customCategories: source.listCustomCategories(),
    smartCategories: source.listSmartCategories(), displayStrategies: source.listCategoryDisplayStrategies(),
    shelfMoves: source.listSyncShelfMoves(), mihonImports: source.listMihonImports() }
}

/** Publish the collections prepared by the library transaction. */
export function replaceLibraryContents(target: LibraryStore, source: LibraryContents): void {
  target.clear()
  target.replaceCustomCategories(source.customCategories)
  target.replaceSmartCategories(source.smartCategories, true)
  target.replaceCategoryDisplayStrategies(source.displayStrategies)
  source.comics.forEach((comic: Comic): void => { target.upsertComic(comic) })
  target.replaceSyncShelfMoves(source.shelfMoves)
  target.replaceMihonImports(source.mihonImports)
}

interface RestoredMihonImports {
  works?: MihonImportWork[]
  readWorks: () => MihonImportWork[]
  readOriginals: (id?: string) => MihonImportRecord[]
}

export class InMemoryLibraryStore implements LibraryStore {
  private mihonImports: MihonImportRecord[] = []
  private changedMihonImports: Map<string, MihonImportRecord> = new Map<string, MihonImportRecord>()
  private restoredMihonImports?: RestoredMihonImports
  private smartCategories: LibrarySmartCategory[] = []
  private syncShelfMoves: SyncLocalShelfMove[] = []

  listMihonImportWorks(): MihonImportWork[] {
    const restored = this.restoredMihonImports
    return restored === undefined ? this.mihonImports.slice() : this.restoredImportWorks(restored).slice()
  }

  getMihonImportWork(id: string): MihonImportWork | undefined {
    const restored = this.restoredMihonImports
    const records = restored === undefined ? this.mihonImports : this.restoredImportWorks(restored)
    return records.find(row => row.id === id)
  }

  readMihonImport(id: string): MihonImportRecord | undefined {
    return this.changedMihonImports.get(id) ?? (this.restoredMihonImports === undefined ? this.mihonImports.find(row => row.id === id) :
      this.restoredMihonImports.readOriginals(id)[0])
  }

  listMihonImports(): MihonImportRecord[] {
    const records = new Map<string, MihonImportRecord>((this.restoredMihonImports?.readOriginals() ?? this.mihonImports)
      .map((record: MihonImportRecord): [string, MihonImportRecord] => [record.id, record]))
    this.changedMihonImports.forEach((record: MihonImportRecord, id: string): void => { records.set(id, record) })
    return Array.from(records.values())
  }

  restoreMihonImportWorks(readWorks: () => MihonImportWork[], readOriginals: (id?: string) => MihonImportRecord[]): void {
    this.mihonImports = []
    this.changedMihonImports.clear()
    this.restoredMihonImports = { readWorks, readOriginals }
  }

  private restoredImportWorks(restored: RestoredMihonImports): MihonImportWork[] {
    if (restored.works === undefined) restored.works = restored.readWorks()
    return restored.works
  }

  replaceMihonImports(records: MihonImportRecord[]): void {
    this.restoredMihonImports = undefined
    this.changedMihonImports.clear()
    this.mihonImports = records.slice()
  }

  updateMihonImports(records: MihonImportRecord[]): void {
    if (records.length === 0) return
    if (this.restoredMihonImports !== undefined) {
      const restored = this.restoredMihonImports
      const works = new Map<string, MihonImportWork>(this.restoredImportWorks(restored)
        .map((record: MihonImportWork): [string, MihonImportWork] => [record.id, record]))
      for (const record of records) {
        this.changedMihonImports.set(record.id, record)
        works.set(record.id, record)
      }
      restored.works = Array.from(works.values())
      return
    }
    const updates = new Map<string, MihonImportRecord>(this.mihonImports.map((record): [string, MihonImportRecord] =>
      [record.id, record]))
    for (const record of records) updates.set(record.id, record)
    this.mihonImports = Array.from(updates.values())
  }

  updateMihonSourceMatches(records: MihonImportWork[]): void {
    const updates = new Map<string, MihonImportWork>(records.map((record): [string, MihonImportWork] =>
      [record.id, record]))
    if (this.restoredMihonImports !== undefined) {
      const restored = this.restoredMihonImports
      restored.works = this.restoredImportWorks(restored).map(row => updates.get(row.id) ?? row)
      return
    }
    this.mihonImports = this.mihonImports.map((record: MihonImportRecord): MihonImportRecord => {
      const update = updates.get(record.id)
      return update === undefined ? record : { id: record.id, sourceName: record.sourceName, work: record.work,
        categoryIds: record.categoryIds, matchedSourceId: update.matchedSourceId, targetComicId: update.targetComicId,
        linkedWork: update.linkedWork }
    })
  }

  listSyncShelfMoves(): SyncLocalShelfMove[] { return this.syncShelfMoves.slice() }

  replaceSyncShelfMoves(moves: SyncLocalShelfMove[]): void { this.syncShelfMoves = moves.slice() }

  listSmartCategories(): LibrarySmartCategory[] {
    return this.smartCategories.map(copyLibrarySmartCategory).sort((a: LibrarySmartCategory, b: LibrarySmartCategory): number =>
      a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
  }

  replaceSmartCategories(categories: LibrarySmartCategory[], allowSavedNameCollisions: boolean = false): void {
    const next = validateLibrarySmartCategories(categories,
      this.listCustomCategories().map((category: CustomLibraryCategory): string => category.name), allowSavedNameCollisions)
    const retainedIds = new Set<string>(next.map((category: LibrarySmartCategory): string => category.id))
    this.smartCategories.forEach((category: LibrarySmartCategory): void => {
      if (!retainedIds.has(category.id)) this.categoryDisplayStrategies.delete(category.id)
    })
    this.smartCategories = next
  }
  private comics: Map<ComicId, Comic> = new Map<ComicId, Comic>()
  private workSummaries?: LibraryWorkSummaryReader
  private readonly loadedShelfCategories = new Set<LibraryCategoryFilter>()
  private readonly removedSummaries = new Set<ComicId>()
  private readCatalog?: (comic: Comic, chapterId?: ChapterId) => Chapter[]
  private readChapterTitle?: (comicId: ComicId, chapterId?: ChapterId) => string | undefined
  private readChapterIds?: (comicId: ComicId) => ChapterId[]
  private customCategories: Map<string, CustomLibraryCategory> = new Map<string, CustomLibraryCategory>()
  private categoryDisplayStrategies: Map<string, LibraryCategoryDisplayStrategy> = new Map<string, LibraryCategoryDisplayStrategy>()

  getComic(comicId: ComicId): Comic | undefined {
    const comic = this.getComicSummary(comicId)
    if (comic?.chapterCatalogDeferred === true && this.readCatalog !== undefined) {
      comic.chapters = this.readCatalog(comic)
      comic.chapterCatalogDeferred = undefined
    }
    return comic
  }

  getComicSummary(comicId: ComicId): Comic | undefined {
    const current = this.comics.get(comicId)
    if (current !== undefined || this.removedSummaries.has(comicId)) return current
    const stored = this.workSummaries?.work(comicId)
    if (stored !== undefined) this.comics.set(comicId, stored)
    return stored
  }

  deferWorkSummaries(category: LibraryCategoryFilter, source: LibraryWorkSummaryReader): void {
    if (category === 'all') return
    this.workSummaries = source
    this.loadedShelfCategories.add(category)
  }

  private loadShelfWorks(category: LibraryCategoryFilter): void {
    const reader = this.workSummaries
    if (reader === undefined || this.loadedShelfCategories.has(category)) return
    const rows = reader.category(category)
    if (category === 'all') {
      const ordered = new Map<ComicId, Comic>()
      for (const row of rows) {
        if (!this.removedSummaries.has(row.id)) ordered.set(row.id, this.comics.get(row.id) ?? row)
      }
      this.comics.forEach((comic: Comic, id: ComicId): void => {
        if (!ordered.has(id)) ordered.set(id, comic)
      })
      this.comics = ordered
      this.workSummaries = undefined
      this.loadedShelfCategories.clear()
      this.removedSummaries.clear()
      return
    }
    for (const row of rows) {
      if (!this.comics.has(row.id) && !this.removedSummaries.has(row.id)) this.comics.set(row.id, row)
    }
    this.loadedShelfCategories.add(category)
  }

  private listKnownComicSummaries(): Comic[] {
    return Array.from(this.comics.values())
  }

  listShelfSummaries(category: LibraryCategoryFilter): Comic[] {
    this.loadShelfWorks(category)
    const rows = this.listKnownComicSummaries()
    if (category === 'all') return rows
    return rows.filter((comic: Comic): boolean => category === 'uncategorized' ?
      normalizeCategoryIds(comic.categoryIds).length === 0 : normalizeCategoryIds(comic.categoryIds).includes(category))
  }

  listComicSummariesByKind(kinds: ComicSourceKind[]): Comic[] {
    const rows = this.workSummaries?.kinds(kinds) ?? []
    for (const row of rows) {
      if (!this.comics.has(row.id) && !this.removedSummaries.has(row.id)) this.comics.set(row.id, row)
    }
    return this.listKnownComicSummaries().filter((comic: Comic): boolean => kinds.includes(comic.sourceKind))
  }

  listSourceComicSummaries(sourceId: string): Comic[] {
    if (this.workSummaries !== undefined) {
      if (this.workSummaries.source !== undefined) {
        const rows = this.workSummaries.source(sourceId)
        for (const row of rows) {
          if (!this.comics.has(row.id) && !this.removedSummaries.has(row.id)) this.comics.set(row.id, row)
        }
      } else {
        this.loadShelfWorks('all')
      }
    }
    return this.listKnownComicSummaries().filter((comic: Comic): boolean => comic.sourceRuntimeId === sourceId)
  }

  listCategoryUsageCounts(): Map<string, number> {
    const rdbCounts = this.workSummaries?.categoryCounts?.()
    if (rdbCounts !== undefined) return rdbCounts
    const counts = new Map<string, number>()
    this.listComicSummaries(false).forEach((comic: Comic): void => {
      if (comic.categoryIds === undefined) return
      new Set<string>(comic.categoryIds).forEach((categoryId: string): void => {
        counts.set(categoryId, (counts.get(categoryId) ?? 0) + 1)
      })
    })
    return counts
  }

  listSourceFacets(): LibraryShelfSourceFacet[] {
    const rdbFacets = this.workSummaries?.sourceFacets?.()
    if (rdbFacets !== undefined) return rdbFacets
    const facets: LibraryShelfSourceFacet[] = []
    this.listComicSummaries(false).forEach((comic: Comic): void => {
      facets.push({
        sourceKind: comic.sourceKind,
        remoteServerId: comic.remoteServerId,
        sourceRuntimeId: comic.sourceRuntimeId,
        contentRating: comic.sourceMetadata?.contentRating,
      })
    })
    return facets
  }

  readComicChapter(comicId: ComicId, chapterId: ChapterId): Chapter | undefined {
    const comic = this.getComicSummary(comicId)
    if (comic === undefined) return undefined
    if (comic.chapterCatalogDeferred === true) return this.readCatalog?.(comic, chapterId)[0]
    return comic.chapters.find((chapter: Chapter): boolean => chapter.id === chapterId)
  }

  readComicChapterTitle(comicId: ComicId, chapterId?: ChapterId): string | undefined {
    const comic = this.getComicSummary(comicId)
    if (comic === undefined) return undefined
    if (comic.chapterCatalogDeferred === true) return this.readChapterTitle?.(comicId, chapterId)
    return chapterId === undefined ? comic.chapters[0]?.title : this.readComicChapter(comicId, chapterId)?.title
  }

  listComicChapterIds(comicId: ComicId): ChapterId[] {
    const comic = this.getComicSummary(comicId)
    if (comic === undefined) return []
    if (comic.chapterCatalogDeferred === true && this.readChapterIds !== undefined) return this.readChapterIds(comicId)
    return comic.chapters.map((chapter: Chapter): ChapterId => chapter.id)
  }

  listComicsChapterIds(comicIds: ComicId[]): Map<ComicId, ChapterId[]> {
    const result = new Map<ComicId, ChapterId[]>()
    if (comicIds.length === 0) return result
    const deferredIds: ComicId[] = []
    for (const id of new Set<ComicId>(comicIds)) {
      const comic = this.getComicSummary(id)
      if (comic === undefined) continue
      if (comic.chapterCatalogDeferred === true) {
        deferredIds.push(id)
      } else {
        result.set(id, comic.chapters.map((chapter: Chapter): ChapterId => chapter.id))
      }
    }
    if (deferredIds.length === 0) return result
    const batchReader = this.workSummaries?.chapterIdsBatch
    if (batchReader !== undefined) {
      const fetched = batchReader(deferredIds)
      for (const id of deferredIds) result.set(id, fetched.get(id) ?? [])
      return result
    }
    for (const id of deferredIds) result.set(id, this.readChapterIds?.(id) ?? [])
    return result
  }

  shelfProgress(comic: Comic, progress?: ReadingProgress): ReadingProgress | undefined {
    if (progress === undefined || comic.chapterCatalogDeferred !== true ||
      (comic.localImportOrigin === undefined && comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER)) {
      return currentComicReadingProgress(comic, progress)
    }
    const chapter = this.readComicChapter(comic.id, progress.chapterId)
    return currentComicReadingProgress(comic, progress, chapter === undefined ? [] : [chapter])
  }

  /** A summary never replaces a stored catalog. Existing detail and full
   * snapshot consumers use getComic/listComics, which resolve the rows. */
  deferCatalogs(read: (comic: Comic, chapterId?: ChapterId) => Chapter[],
    title: (comicId: ComicId, chapterId?: ChapterId) => string | undefined, ids: (comicId: ComicId) => ChapterId[]): void {
    this.readCatalog = read
    this.readChapterTitle = title
    this.readChapterIds = ids
    for (const comic of this.comics.values()) comic.chapterCatalogDeferred = true
  }

  findByRemote(serverId: string, resourceId: string): Comic | undefined {
    const found = this.identityCandidates(serverId, resourceId, true).find((comic: Comic): boolean => {
      return comic.remoteServerId === serverId && comic.remoteResourceId === resourceId
    })
    return found === undefined ? undefined : this.getComic(found.id)
  }

  findBySourceManga(sourceId: string, mangaId: string, sortByTitle: boolean = true): Comic | undefined {
    let found: Comic | undefined
    for (const comic of this.identityCandidates(sourceId, mangaId, false)) {
      if (comic.sourceRuntimeId !== sourceId || comic.remoteResourceId !== mangaId) continue
      if (!sortByTitle) return this.getComic(comic.id)
      // Preserve the old title-sorted choice for duplicate legacy records.
      // New editions do not need to sort the entire shelf to detect a miss.
      if (found === undefined || this.compareTitles(comic, found) < 0) found = comic
    }
    return found === undefined ? undefined : this.getComic(found.id)
  }

  private identityCandidates(owner: string, work: string, remote: boolean): Comic[] {
    const reader = this.workSummaries
    if (reader === undefined) return this.listKnownComicSummaries()
    const persisted = reader.identity(owner, work, remote)
    const candidates = new Map<ComicId, Comic>()
    for (const row of persisted) {
      if (this.removedSummaries.has(row.id)) continue
      const current = this.comics.get(row.id) ?? row
      this.comics.set(row.id, current)
      candidates.set(row.id, current)
    }
    for (const row of this.comics.values()) {
      const identity = remote ? row.remoteServerId : row.sourceRuntimeId
      if (identity === owner && row.remoteResourceId === work && !candidates.has(row.id)) candidates.set(row.id, row)
    }
    return Array.from(candidates.values())
  }

  private compareTitles(a: Comic, b: Comic): number {
    return a.sortTitle.localeCompare(b.sortTitle) || a.createdAt - b.createdAt
  }

  hasComics(): boolean {
    return this.comics.size > 0 || this.workSummaries?.hasWorks() === true
  }

  listComics(sortByTitle: boolean = true): Comic[] {
    return this.listComicSummaries(sortByTitle).map((comic: Comic): Comic => this.getComic(comic.id) as Comic)
  }

  listComicSummaries(sortByTitle: boolean = true): Comic[] {
    this.loadShelfWorks('all')
    const comics = this.listKnownComicSummaries()
    // Search takes a shallow snapshot and performs the same ordering in its
    // worker. Ordinary consumers retain the established sorted list.
    if (!sortByTitle) return comics
    return comics.sort((a: Comic, b: Comic): number => this.compareTitles(a, b))
  }

  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>, options?: LibraryListOptions): LibraryItem[] {
    const sourceFilters = options?.filterSource
    const readStateFilter = options?.filterReadState ?? 'all'
    const categoryFilter = options?.filterCategoryId ?? 'all'
    this.loadShelfWorks(categoryFilter)
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
        return comicToLibraryItem(comic, this.shelfProgress(comic, progress))
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
        if (options?.readerSessionStore !== undefined) value = options.readerSessionStore.latestCatalogDate(comic)
        else {
          for (const chapter of comic.chapters) {
            const date = chapter.dateUpload
            if (date !== undefined && Number.isFinite(date) && date > (value ?? 0)) value = date
          }
        }
      }
      values.set(row.comicId, value)
    }
    return rows.sort((a: LibraryItem, b: LibraryItem): number => {
      const left = values.get(a.comicId)
      const right = values.get(b.comicId)
      return compareShelfTime(left, right, direction) || this.compareByAddedDesc(a, b)
    })
  }

  listReadLibraryItems(progressByComicId: Map<ComicId, ReadingProgress>): LibraryItem[] {
    this.loadShelfWorks('all')
    // History only needs works with a saved position. Project those works
    // directly and keep the shelf's recent-reading tie break.
    const rows: LibraryItem[] = []
    for (const comic of this.comics.values()) {
      const progress = progressByComicId.get(comic.id)
      if (progress !== undefined) {
        const item = comicToLibraryItem(comic, progress)
        if (comic.chapterCatalogDeferred === true) item.progress = this.shelfProgress(comic, progress)
        rows.push(item)
      }
    }
    return rows.sort((a: LibraryItem, b: LibraryItem): number =>
      (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0) || this.compareByAddedDesc(a, b))
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
    this.removedSummaries.delete(comic.id)
    this.comics.set(comic.id, comic)
  }

  removeComic(comicId: ComicId): void {
    if (this.workSummaries !== undefined) this.removedSummaries.add(comicId)
    this.comics.delete(comicId)
  }

  orderComics(comicIds: ComicId[]): void {
    this.loadShelfWorks('all')
    const ordered = new Map<ComicId, Comic>()
    for (const id of comicIds) {
      const comic = this.comics.get(id)
      if (comic !== undefined) ordered.set(id, comic)
    }
    this.comics.forEach((comic: Comic, id: ComicId): void => {
      if (!ordered.has(id)) ordered.set(id, comic)
    })
    this.comics = ordered
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
    // Independently synchronized IDs can share a saved name. Loading them must
    // keep their memberships and privacy flags. Creation and renaming still validate names.
    const nextCategories: Map<string, CustomLibraryCategory> = new Map<string, CustomLibraryCategory>()
    categories.forEach((category: CustomLibraryCategory) => {
      const restoredCategory = this.validateRestoredCustomCategory(category, nextCategories)
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
      id: util.generateRandomUUID(),
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
      isPrivate: previous.isPrivate,
    }
    this.customCategories.set(categoryId, next)
    return this.cloneCustomCategory(next)
  }

  setCustomCategoryPrivacy(categoryId: string, isPrivate: boolean, now: number = Date.now()): boolean {
    const category = this.customCategories.get(categoryId)
    if (category === undefined || (category.isPrivate === true) === isPrivate) return false
    category.isPrivate = isPrivate
    category.updatedAt = now
    return true
  }

  moveCustomCategory(categoryId: string, destinationId: string, now: number = Date.now()): boolean {
    const categories = this.listCustomCategories()
    const index = categories.findIndex((category: CustomLibraryCategory): boolean => category.id === categoryId)
    const targetIndex = categories.findIndex((category: CustomLibraryCategory): boolean => category.id === destinationId)
    if (index < 0 || targetIndex < 0 || index === targetIndex) return false
    const moved = categories.splice(index, 1)[0]
    categories.splice(targetIndex, 0, moved)
    categories.forEach((category: CustomLibraryCategory, position: number): void => {
      if (category.sortOrder === position) return
      category.sortOrder = position
      category.updatedAt = now
      this.customCategories.set(category.id, category)
    })
    return true
  }

  moveSmartCategory(categoryId: string, destinationId: string, now: number = Date.now()): boolean {
    const categories = this.listSmartCategories()
    const index = categories.findIndex((category: LibrarySmartCategory): boolean => category.id === categoryId)
    const targetIndex = categories.findIndex((category: LibrarySmartCategory): boolean => category.id === destinationId)
    if (index < 0 || targetIndex < 0 || index === targetIndex) return false
    const moved = categories.splice(index, 1)[0]
    categories.splice(targetIndex, 0, moved)
    categories.forEach((category: LibrarySmartCategory, position: number): void => {
      if (category.sortOrder === position) return
      category.sortOrder = position
      category.updatedAt = now
    })
    this.smartCategories = categories
    return true
  }

  deleteCustomCategory(categoryId: string, memberIds?: string[]): boolean {
    if (!this.customCategories.has(categoryId)) {
      return false
    }
    this.customCategories.delete(categoryId)
    this.categoryDisplayStrategies.delete(categoryId)
    const removeMembership = (comic: Comic, comicId: ComicId): void => {
      const owned = normalizeCategoryIds(comic.categoryIds)
      if (owned.includes(categoryId)) {
        const nextCategoryIds = owned.filter((item: string): boolean => item !== categoryId)
        this.comics.set(comicId, withComicCategoryIds(comic, nextCategoryIds))
      }
    }
    if (memberIds === undefined) this.comics.forEach(removeMembership)
    else for (const id of memberIds) {
      const comic = this.comics.get(id)
      if (comic !== undefined) removeMembership(comic, id)
    }
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
    this.workSummaries = undefined
    this.loadedShelfCategories.clear()
    this.removedSummaries.clear()
    this.readCatalog = undefined
    this.readChapterTitle = undefined
    this.readChapterIds = undefined
    this.replaceMihonImports([])
    this.smartCategories = []
    this.syncShelfMoves = []
    this.comics.clear()
    this.customCategories.clear()
    this.categoryDisplayStrategies.clear()
  }

  restoreJson(payload: string): void {
    this.clear()
    const parsed = JSON.parse(payload) as Record<string, Object>
    if (!Array.isArray(parsed) && Array.isArray(parsed['mihonImports'])) {
      this.replaceMihonImports(parsed['mihonImports'] as MihonImportRecord[])
    }
    const rows = Array.isArray(parsed) ? parsed as Comic[] : parsed['comics'] as Comic[]
    rows.forEach((comic: Comic) => {
      this.comics.set(comic.id, comic)
    })
    if (!Array.isArray(parsed) && Array.isArray(parsed['customCategories'])) {
      this.replaceCustomCategories(parsed['customCategories'] as CustomLibraryCategory[])
    }
    if (!Array.isArray(parsed) && Array.isArray(parsed['smartCategories'])) {
      this.replaceSmartCategories(parsed['smartCategories'] as LibrarySmartCategory[], true)
    }
    if (!Array.isArray(parsed) && Array.isArray(parsed['categoryDisplayStrategies'])) {
      this.replaceCategoryDisplayStrategies(parsed['categoryDisplayStrategies'] as LibraryCategoryDisplayStrategy[])
    }
  }

  private cloneCustomCategory(category: CustomLibraryCategory): CustomLibraryCategory {
    const clone: CustomLibraryCategory = {
      id: category.id,
      name: category.name,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    }
    if (category.isPrivate !== undefined) clone.isPrivate = category.isPrivate
    return clone
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

  private validateRestoredCustomCategory(
    category: CustomLibraryCategory,
    nextCategories: Map<string, CustomLibraryCategory>
  ): CustomLibraryCategory {
    if (!isManualLibraryCategoryId(category.id)) {
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
    return {
      id: category.id,
      name: normalizedName,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      isPrivate: category.isPrivate,
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
