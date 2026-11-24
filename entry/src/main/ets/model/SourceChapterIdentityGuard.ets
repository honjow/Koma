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
    const position = reader.getProgress(comic.id)
    if (position !== undefined) ids.add(position.chapterId)
    reader.listChapterStates(comic.id).forEach((row): void => { ids.add(row.chapterId) })
    const source = reader.getSourceHistory(comic.id)
    if (source !== undefined) ids.add(source.chapterId)
    const remote = reader.getRemoteHistory(comic.id)
    if (remote !== undefined) ids.add(remote.chapterId)
    const tasks = new OfflineDownloadQueueStore(filesDir, runtimeKey).loadTasksForComics([comic.id])
    tasks.forEach((row): void => { ids.add(row.chapterId) })
    const downloaded = new OfflineDownloadStore(filesDir, runtimeKey).storedChapterIds(comic.id)
    if (downloaded === undefined) return undefined
    downloaded.forEach((id: string): void => { ids.add(id) })
    return ids
  } catch (_error) {
    // Unknown references must preserve the stored records, never be treated as empty.
    return undefined
  }
}
