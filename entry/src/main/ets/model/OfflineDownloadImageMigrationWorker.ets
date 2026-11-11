import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { writeAppTextFile } from './AppFileTextPersistence'
import { loadOrScanDownloadDirectoryIndex } from './DownloadDirectoryIndex'
import { migrateOfflineChapterImageSuffixes } from './OfflineDownloadImageMigration'
import { OfflineDownloadStore, OFFLINE_DOWNLOAD_ROOT_DIR_NAME, offlineDownloadIndexDirectory } from './OfflineDownloadStore'

/** Runs before reader entry, off the UI thread, once per storage root. */
@Concurrent
export function migrateOfflineImageSuffixes(storageBase: string, appFilesDir: string): string {
  const marker = appFilesDir + '/.koma-download-image-suffix-v2'
  if (fs.accessSync(marker) && fs.readTextSync(marker, { encoding: 'utf-8' }) === storageBase) return 'already_complete'
  const root = storageBase.replace(/\/+$/, '') + '/' + OFFLINE_DOWNLOAD_ROOT_DIR_NAME
  const index = loadOrScanDownloadDirectoryIndex(root, offlineDownloadIndexDirectory(storageBase, appFilesDir))
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
  if (failures === 0) writeAppTextFile(marker, storageBase)
  return `chapters=${chapters} pages=${pages} failures=${failures}`
}
