import { SourceChapterIdentityPolicy } from '../sourceRuntime/SourceWebsitePolicy'
import { Comic } from './ComicModels'
import { ReaderSessionStore } from './ReaderSessionStore'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { OfflineDownloadStore } from './OfflineDownloadStore'

/** Read references without migrating, reconciling or rewriting their owning stores. */
export function protectedSourceChapterIds(
  comic: Comic, filesDir: string, reader: ReaderSessionStore, policy?: SourceChapterIdentityPolicy,
  runtimeKey: string = filesDir,
): Set<string> | undefined {
  if (policy?.encodedLegacy === undefined) return undefined
  try {
    const ids = new Set<string>()
    reader.listProgress().forEach((row): void => { if (row.comicId === comic.id) ids.add(row.chapterId) })
    reader.listChapterStates().forEach((row): void => { if (row.comicId === comic.id) ids.add(row.chapterId) })
    reader.listSourceHistory().forEach((row): void => { if (row.comicId === comic.id) ids.add(row.chapterId) })
    reader.listRemoteHistory().forEach((row): void => { if (row.comicId === comic.id) ids.add(row.chapterId) })
    new OfflineDownloadQueueStore(filesDir, runtimeKey).load().forEach((row): void => {
      if (row.comicId === comic.id) ids.add(row.chapterId)
    })
    const downloaded = new OfflineDownloadStore(filesDir, runtimeKey).storedChapterIds(comic.id)
    if (downloaded === undefined) return undefined
    downloaded.forEach((id: string): void => { ids.add(id) })
    return ids
  } catch (_error) {
    // Unknown references must preserve the stored records, never be treated as empty.
    return undefined
  }
}
