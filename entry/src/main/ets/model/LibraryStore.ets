import {
  Comic,
  ComicId,
  ComicSourceKind,
  LibraryItem,
  ReadingProgress,
  comicToLibraryItem,
} from './ComicModels'

export type LibrarySortBy = 'lastRead' | 'added' | 'title' | 'source'
export type LibraryReadStateFilter = 'all' | 'unread' | 'reading' | 'completed'

export interface LibraryListOptions {
  sortBy?: LibrarySortBy
  filterSource?: ComicSourceKind[]
  filterReadState?: LibraryReadStateFilter
}

export interface LibraryStore {
  getComic(comicId: ComicId): Comic | undefined
  findByRemote(serverId: string, resourceId: string): Comic | undefined
  listComics(): Comic[]
  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>, options?: LibraryListOptions): LibraryItem[]
  addComic(comic: Comic): void
  upsertComic(comic: Comic): void
  removeComic(comicId: ComicId): void
  clear(): void
  dumpJson(): string
  restoreJson(payload: string): void
}

export class InMemoryLibraryStore implements LibraryStore {
  private comics: Map<ComicId, Comic> = new Map<ComicId, Comic>()

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
    const sortBy = options?.sortBy ?? 'lastRead'
    const rows: LibraryItem[] = Array.from(this.comics.values())
      .filter((comic: Comic): boolean => {
        return sourceFilters === undefined || sourceFilters.includes(comic.sourceKind)
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

  clear(): void {
    this.comics.clear()
  }

  dumpJson(): string {
    return JSON.stringify(this.listComics())
  }

  restoreJson(payload: string): void {
    this.comics.clear()
    const rows = JSON.parse(payload) as Comic[]
    rows.forEach((comic: Comic) => {
      this.comics.set(comic.id, comic)
    })
  }
}
