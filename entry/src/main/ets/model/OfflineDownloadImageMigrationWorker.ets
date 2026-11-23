import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { writeAppTextFile } from './AppFileTextPersistence'
import { loadOrScanDownloadDirectoryIndex } from './DownloadDirectoryIndex'
import { hasPreparedOfflineDownloadLayout, normalizeDownloadLayout, offlineDownloadLayoutCompletionPath } from './DownloadLayoutMigration'
import { migrateOfflineChapterImageSuffixes } from './OfflineDownloadImageMigration'
import { OfflineDownloadStore, OFFLINE_DOWNLOAD_ROOT_DIR_NAME, offlineDownloadIndexDirectory } from './OfflineDownloadStore'

/** Files and their paths must settle before the destination is used by readers. */
@Concurrent
export function prepareOfflineDownloadLayout(storageBase: string, appFilesDir: string, encodedSourceNames: string): string {
  if (hasPreparedOfflineDownloadLayout(storageBase, appFilesDir)) return 'already_complete'
  const root = storageBase.replace(/\/+$/, '') + '/' + OFFLINE_DOWNLOAD_ROOT_DIR_NAME
  const indexDir = offlineDownloadIndexDirectory(storageBase, appFilesDir)
  const sourceNames = JSON.parse(encodedSourceNames) as Record<string, string>
  const layoutComplete = normalizeDownloadLayout(root, indexDir, (sourceId: string): string => sourceNames[sourceId] ?? '')
  const index = loadOrScanDownloadDirectoryIndex(root, indexDir)
  const store = new OfflineDownloadStore(storageBase, appFilesDir)
  let chapters = 0
  let pages = 0
  let failures = 0
  for (const comicId of Object.keys(index.comics)) {
    for (const chapterId of Object.keys(index.comics[comicId].chapters)) {
      try {
        const count = migrateOfflineChapterImageSuffixes(store, comicId, chapterId)
        if (count > 0) { chapters++; pages += count }
      } catch (error) {
        failures++
        DiagnosticLogger.exception('downloads', 'image_suffix_migration_failed', error as Error)
      }
    }
  }
  if (layoutComplete && failures === 0) writeAppTextFile(offlineDownloadLayoutCompletionPath(appFilesDir), storageBase)
  return `chapters=${chapters} pages=${pages} failures=${failures} layout_complete=${layoutComplete}`
}
