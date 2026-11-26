import { taskpool } from '@kit.ArkTS'
import { ComicId } from './ComicModels'
import {
  OfflineChapterDownloadManifest,
  OfflineDownloadManifestValidation,
  OfflineDownloadStore,
  OfflineDownloadValidationOptions,
  persistDownloadManifest,
} from './OfflineDownloadStore'

@Concurrent
function writeDownloadManifest(filesDir: string, chapterDir: string,
  manifest: OfflineChapterDownloadManifest, appFilesDir: string): OfflineChapterDownloadManifest {
  return persistDownloadManifest(filesDir, chapterDir, manifest, appFilesDir)
}

@Concurrent
function validateOfflineDownload(filesDir: string, runtimeKey: string, comicId: ComicId,
  chapterId: string, options: OfflineDownloadValidationOptions, writtenChapterDir: string): OfflineDownloadManifestValidation {
  if (writtenChapterDir.length > 0) {
    return OfflineDownloadStore.validateChapterDirectory(filesDir, writtenChapterDir, comicId, chapterId, options, runtimeKey)
  }
  // Before writing, another batch may already have saved or resumed this
  // chapter. Resolve the latest directory mapping before reusing its pages.
  return new OfflineDownloadStore(filesDir, runtimeKey).validateDownloadedChapter(comicId, chapterId, options)
}


export function saveDownloadManifestAsync(store: OfflineDownloadStore,
  manifest: OfflineChapterDownloadManifest): Promise<OfflineChapterDownloadManifest> {
  return store.persistManifestWith(manifest, async (filesDir: string, chapterDir: string,
    normalized: OfflineChapterDownloadManifest, appFilesDir: string): Promise<OfflineChapterDownloadManifest> => {
    return await taskpool.execute(writeDownloadManifest, filesDir, chapterDir, normalized, appFilesDir) as OfflineChapterDownloadManifest
  })
}

export async function validateDownloadManifestAsync(store: OfflineDownloadStore, comicId: ComicId,
  chapterId: string, options: OfflineDownloadValidationOptions = {},
  writtenChapterDir: string = ''): Promise<OfflineDownloadManifestValidation> {
  return validateStoredDownloadManifestAsync(store.filesRootDir(), store.runtimeKey(),
    comicId, chapterId, options, writtenChapterDir)
}

/** The caller need not open the index or construct a store on the UI thread. */
export async function validateStoredDownloadManifestAsync(filesDir: string, runtimeKey: string, comicId: ComicId,
  chapterId: string, options: OfflineDownloadValidationOptions, writtenChapterDir: string = ''):
  Promise<OfflineDownloadManifestValidation> {
  return await taskpool.execute(validateOfflineDownload, filesDir, runtimeKey,
    comicId, chapterId, options, writtenChapterDir) as OfflineDownloadManifestValidation
}
