export interface ComicArchiveBookmark {
  title: string
  pageIndex: number
}

export interface ComicInfoNode {
  _name?: string
  _attributes?: Record<string, string>
  _elements?: ComicInfoNode[]
}

/** ComicInfo page indexes refer to the already sorted image list, not chapter IDs. */
export function comicArchiveBookmarks(root: ComicInfoNode, pageCount: number): ComicArchiveBookmark[] {
  const bookmarks: ComicArchiveBookmark[] = []
  const visit = (node: ComicInfoNode): void => {
    if (node._name === 'Page') {
      const attrs = node._attributes ?? {}
      const raw = attrs['Image'] ?? ''
      const title = (attrs['Bookmark'] ?? '').trim()
      const index = Number(raw)
      if (/^\d+$/.test(raw) && Number.isSafeInteger(index) && index < pageCount && title.length > 0) {
        bookmarks.push({ title, pageIndex: index })
      }
    }
    node._elements?.forEach(visit)
  }
  visit(root)
  return bookmarks.sort((left: ComicArchiveBookmark, right: ComicArchiveBookmark): number => left.pageIndex - right.pageIndex)
}
