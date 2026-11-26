import { parseComicZipPage, readComicZipInfo } from './ComicZipPage'
import { convertxml, taskpool } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ComicArchiveBookmark, ComicInfoNode, comicArchiveBookmarks } from './ComicArchiveBookmarkParser'
import { comicArchiveEntryBookmarks, comicArchiveFolderBookmarks } from './ComicArchiveFolderBookmarks'

/** Only files under an import's extraction root can supply archive metadata. */
export function comicArchiveExtractionRoot(pageUri: string): string | undefined {
  const zipPage = parseComicZipPage(pageUri)
  if (zipPage !== undefined) return zipPage.archive
  if (!pageUri.startsWith('file://')) return undefined
  try {
    const path = decodeURIComponent(pageUri.substring('file://'.length))
    const match = /\/(?:import|local-folder-archives)\/[^/]+\/(?:extract\.chapters\/\d+\/)*extract\//.exec(path)
    return match === null ? undefined : path.substring(0, match.index + match[0].length - 1)
  } catch (_error) {
    return undefined
  }
}

@Concurrent
function readBookmarksOnWorker(root: string, pageCount: number, pageUris: string[], zipInfo: string | undefined): ComicArchiveBookmark[] {
  try {
    const document = new convertxml.ConvertXML().fastConvertToJSObject((zipInfo ?? fs.readTextSync(`${root}/ComicInfo.xml`))) as ComicInfoNode
    const explicit = comicArchiveBookmarks(document, pageCount)
    if (explicit.length > 0) return explicit
  } catch (_error) {
    // No valid ComicInfo: folder names may still provide chapter boundaries.
  }
  if (zipInfo === undefined) return comicArchiveFolderBookmarks(root, pageUris)
  return comicArchiveEntryBookmarks(pageUris.map((uri: string): string => {
    const page = parseComicZipPage(uri)
    return page?.archive === root ? page.entry : ''
  }))
}

/** Optional metadata cannot make an otherwise readable archive fail to open. */
export async function readComicArchiveBookmarks(root: string, pageCount: number, pageUris: string[]): Promise<ComicArchiveBookmark[]> {
  try {
    const zipInfo = parseComicZipPage(pageUris[0] ?? '') === undefined ? undefined :
      await readComicZipInfo(root).catch((): string => '')
    return await taskpool.execute(new taskpool.Task(readBookmarksOnWorker, root, pageCount, pageUris, zipInfo)) as ComicArchiveBookmark[]
  } catch (_error) {
    return []
  }
}
