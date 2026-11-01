import { normalizeSearchText, searchTextMatchesQuery } from './CrossSearchText'
import { LibrarySearchFields, LibrarySearchSource, parseLibrarySearchQuery, matchesLibrarySearch } from './LibrarySearchQuery'

/** Only searchable public text crosses the worker boundary, not Comic/page trees. */
export interface LocalLibrarySearchDocument extends LibrarySearchFields {
  id: string
  title: string
  sortTitle: string
  createdAt: number
  subtitle?: string
  author?: string
  chapterCount: number
  pageCount: number
  chapterTitles: string[]
}

export interface LocalLibrarySearchMatch {
  comicId: string
  subtitle: string
}

// Keep chapter-title matching and the original base order. Moving this loop,
// rather than removing searchable fields, fixes the UI-thread pause.
@Concurrent
export function searchLocalLibraryTask(documents: LocalLibrarySearchDocument[], value: string,
  fallbackSubtitle: string, source: LibrarySearchSource | undefined = undefined): LocalLibrarySearchMatch[] {
  const plan = parseLibrarySearchQuery(value)
  const query = normalizeSearchText(plan.rankingText)
  const compact = query.replace(/ /g, '')
  const result: LocalLibrarySearchMatch[] = []
  documents.sort((a: LocalLibrarySearchDocument, b: LocalLibrarySearchDocument): number =>
    a.sortTitle.localeCompare(b.sortTitle) || a.createdAt - b.createdAt)
  for (const document of documents) {
    if (source !== undefined && document.sourceKey !== source.key) continue
    if (!matchesLibrarySearch(document, plan.root)) continue
    const title = searchTextMatchesQuery(document.title, query, compact)
    const subtitle = searchTextMatchesQuery(document.subtitle, query, compact)
    const author = searchTextMatchesQuery(document.author, query, compact)
    const chapter = !title && !subtitle && !author
      ? document.chapterTitles.find((name: string): boolean => searchTextMatchesQuery(name, query, compact)) : undefined
    result.push({ comicId: document.id, subtitle: !title && subtitle ? document.subtitle! :
      !title && author ? document.author! : chapter ?? document.author ?? fallbackSubtitle
        .replace('%s', `${document.chapterCount}`).replace('%s', `${document.pageCount}`) })
  }
  return result
}
