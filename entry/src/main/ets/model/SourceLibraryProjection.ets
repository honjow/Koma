import { Comic } from './ComicModels'
import { SourceManga } from './SourceModels'

export interface SourceLibraryItem {
  manga: SourceManga
  inLibrary: boolean
}

export function sourceLibraryKey(sourceId: string, mangaId: string): string {
  return JSON.stringify([sourceId, mangaId])
}

// Match the library/detail identity, never the title or URL. History-only works
// are not in LibraryStore. Build once per shelf revision, not once per card.
export function sourceLibraryKeys(comics: Comic[]): Set<string> {
  const keys = new Set<string>()
  comics.forEach((comic: Comic): void => {
    if (comic.sourceRuntimeId && comic.remoteResourceId) {
      keys.add(sourceLibraryKey(comic.sourceRuntimeId, comic.remoteResourceId))
    }
  })
  return keys
}

export function projectSourceLibrary(manga: SourceManga[], keys: Set<string>, hide: boolean): SourceLibraryItem[] {
  const items: SourceLibraryItem[] = []
  manga.forEach((item: SourceManga): void => {
    const inLibrary = keys.has(sourceLibraryKey(item.sourceId, item.id))
    if (!hide || !inLibrary) items.push({ manga: item, inLibrary })
  })
  // Keep the source response/page cursor intact, including fully hidden pages.
  return items
}
