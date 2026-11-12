import { ComicArchiveBookmark } from './ComicArchiveBookmarkParser'
import { ArchiveImageChapter, archiveImageChapters } from './ArchiveImageChapters'

/** A CBZ may encode chapter boundaries as folders instead of ComicInfo bookmarks. */
export function comicArchiveFolderBookmarks(root: string, pageUris: string[]): ComicArchiveBookmark[] {
  try {
    const prefix = `${root}/`
    const paths = pageUris.map((uri: string): string => {
      if (!uri.startsWith('file://')) return ''
      const path = decodeURIComponent(uri.substring('file://'.length))
      return path.startsWith(prefix) ? path.substring(prefix.length) : ''
    })
    if (paths.some((path: string): boolean => path.length === 0)) return []
    return archiveImageChapters(paths).map((chapter: ArchiveImageChapter): ComicArchiveBookmark => ({
      title: chapter.title, pageIndex: paths.indexOf(chapter.paths[0]),
    })).filter((bookmark: ComicArchiveBookmark): boolean => bookmark.pageIndex >= 0)
  } catch (_error) {
    return []
  }
}
