import {
  Comic,
  ComicId,
  LibraryItem,
  ReadingProgress,
  comicToLibraryItem,
} from './ComicModels'

export interface LibraryStore {
  getComic(comicId: ComicId): Comic | undefined
  listComics(): Comic[]
  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>): LibraryItem[]
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

  listComics(): Comic[] {
    return Array.from(this.comics.values()).sort((a: Comic, b: Comic) => {
      const titleCompare = a.sortTitle.localeCompare(b.sortTitle)
      if (titleCompare !== 0) {
        return titleCompare
      }
      return a.createdAt - b.createdAt
    })
  }

  listLibraryItems(progressByComicId?: Map<ComicId, ReadingProgress>): LibraryItem[] {
    return this.listComics().map((comic: Comic) => {
      const progress = progressByComicId === undefined ? undefined : progressByComicId.get(comic.id)
      return comicToLibraryItem(comic, progress)
    })
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
