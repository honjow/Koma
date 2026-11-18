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
  manifest: OfflineChapterDownloadManifest): OfflineChapterDownloadManifest {
  return persistDownloadManifest(filesDir, chapterDir, manifest)
}

@Concurrent
function validateOfflineDownload(filesDir: string, runtimeKey: string, comicId: ComicId,
  chapterId: string, options: OfflineDownloadValidationOptions): OfflineDownloadManifestValidation {
  return new OfflineDownloadStore(filesDir, runtimeKey).validateDownloadedChapter(comicId, chapterId, options)
}


export function saveDownloadManifestAsync(store: OfflineDownloadStore,
  manifest: OfflineChapterDownloadManifest): Promise<OfflineChapterDownloadManifest> {
  return store.persistManifestWith(manifest, async (filesDir: string, chapterDir: string,
    normalized: OfflineChapterDownloadManifest): Promise<OfflineChapterDownloadManifest> => {
    return await taskpool.execute(writeDownloadManifest, filesDir, chapterDir, normalized) as OfflineChapterDownloadManifest
  })
}

export async function validateDownloadManifestAsync(store: OfflineDownloadStore, comicId: ComicId,
  chapterId: string, options: OfflineDownloadValidationOptions = {}): Promise<OfflineDownloadManifestValidation> {
  return await taskpool.execute(validateOfflineDownload, store.filesRootDir(), store.runtimeKey(),
    comicId, chapterId, options) as OfflineDownloadManifestValidation
}
