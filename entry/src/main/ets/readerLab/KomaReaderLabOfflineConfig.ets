import { ReaderSessionConfig } from '../model/ReaderSessionStore'
import {
  OfflineDownloadedChapterStatus, OfflineDownloadedPage, OfflineDownloadManifestValidation,
} from '../model/OfflineDownloadStore'
import { createReaderOfflineMissingUri } from '../model/ReaderPageSourceAdapter'

/** Mirrors Index's manifest fallback without changing the library or its chapter order. */
export function createKomaReaderLabOfflineConfig(
  baseConfig: ReaderSessionConfig,
  validation: OfflineDownloadManifestValidation,
): ReaderSessionConfig {
  if (baseConfig.totalPages > 0 || baseConfig.chapterId.length === 0) return baseConfig
  const hasReaderReadyPages = validation.availablePageCount > 0 &&
    (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
      validation.status === OfflineDownloadedChapterStatus.PARTIAL)
  const hasCorruptManifestPageMap = validation.status === OfflineDownloadedChapterStatus.CORRUPT &&
    validation.pageCount > 0
  const manifest = validation.manifest
  if (manifest === undefined || validation.pageCount <= 0 ||
    (!hasReaderReadyPages && !hasCorruptManifestPageMap)) return baseConfig

  const pageUris: string[] = []
  const pageIds: string[] = []
  const pageWidths: Array<number | undefined> = []
  const pageHeights: Array<number | undefined> = []
  for (let index = 0; index < validation.pageCount; index += 1) {
    const page = manifest.pages.find((item: OfflineDownloadedPage): boolean => item.pageIndex === index)
    pageIds.push(page?.pageId ?? `page-${index + 1}`)
    // Structural validation owns identity, safe paths and file checks. A corrupt
    // manifest keeps its page count but must never supply a readable local path.
    const localPath = hasReaderReadyPages ? (page?.localPath ?? '') : ''
    pageUris.push(localPath.length > 0
      ? localPath
      : createReaderOfflineMissingUri(baseConfig.comicId, baseConfig.chapterId, index))
    pageWidths.push(page?.width)
    pageHeights.push(page?.height)
  }
  const chapterIds = baseConfig.chapterIds.includes(baseConfig.chapterId)
    ? baseConfig.chapterIds : baseConfig.chapterIds.concat([baseConfig.chapterId])
  const chapterTitles = chapterIds.map((chapterId: string, index: number): string => {
    const title = baseConfig.chapterTitles?.[index] ?? ''
    return title.length > 0 || chapterId !== baseConfig.chapterId ? title : (manifest.chapterTitle ?? '')
  })
  return {
    comicId: baseConfig.comicId,
    chapterId: baseConfig.chapterId,
    title: baseConfig.title,
    chapterTitle: baseConfig.chapterTitle ?? manifest.chapterTitle,
    chapterIds,
    continuationChapterIds: baseConfig.continuationChapterIds,
    chapterTitles,
    totalPages: validation.pageCount,
    pageUris,
    pageIds,
    pageWidths,
    pageHeights,
    sourceRuntimeId: baseConfig.sourceRuntimeId,
  }
}
