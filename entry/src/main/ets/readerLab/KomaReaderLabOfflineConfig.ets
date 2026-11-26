import { SourceTextOverlay } from '../model/SourceTextOverlay'
import { cloneReaderSessionConfig, ReaderSessionConfig } from '../model/ReaderSessionStore'
import {
  OfflineDownloadedChapterStatus, OfflineDownloadedPage, OfflineDownloadManifestValidation, downloadedPageReference,
} from '../model/OfflineDownloadStore'
import { createReaderOfflineMissingUri } from '../model/ReaderPageSourceAdapter'

/** A complete download owns the page plan. Partial or damaged downloads keep
 * the existing fallback rules, including an already available source plan. */
export function createKomaReaderLabOfflineConfig(
  baseConfig: ReaderSessionConfig,
  validation?: OfflineDownloadManifestValidation,
): ReaderSessionConfig {
  if (validation === undefined || validation.comicId !== baseConfig.comicId ||
    validation.chapterId !== baseConfig.chapterId || baseConfig.chapterId.length === 0) return baseConfig
  const complete = validation.status === OfflineDownloadedChapterStatus.DOWNLOADED
  if (!complete && baseConfig.totalPages > 0 && baseConfig.pageUris.length > 0) return baseConfig
  const hasReaderReadyPages = validation.availablePageCount > 0 &&
    (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
      validation.status === OfflineDownloadedChapterStatus.PARTIAL)
  const hasCorruptManifestPageMap = validation.status === OfflineDownloadedChapterStatus.CORRUPT &&
    validation.pageCount > 0
  const manifest = validation.manifest
  if (manifest === undefined || validation.pageCount <= 0 ||
    (!hasReaderReadyPages && !hasCorruptManifestPageMap)) return baseConfig

  const pageUris: string[] = []
  const sourceOriginalImageUris: Array<string | undefined> = []
  const pageTextOverlays: Array<SourceTextOverlay | undefined> = []
  const pageIds: string[] = []
  const pageWidths: Array<number | undefined> = []
  const pageHeights: Array<number | undefined> = []
  const downloadedPages = new Map<number, OfflineDownloadedPage>()
  manifest.pages.forEach((page: OfflineDownloadedPage): void => { downloadedPages.set(page.pageIndex, page) })
  const offlinePages: Array<OfflineDownloadedPage | undefined> = []
  for (let index = 0; index < validation.pageCount; index += 1) {
    const page = downloadedPages.get(index)
    if (complete) offlinePages.push(page)
    sourceOriginalImageUris.push(page?.sourceOriginalUri)
    pageTextOverlays.push(page?.sourceTextOverlay)
    pageIds.push(page?.pageId ?? `page-${index + 1}`)
    // Structural validation owns identity, safe paths and file checks. A corrupt
    // manifest keeps its page count but must never supply a readable local path.
    const localPath = hasReaderReadyPages && page !== undefined ? downloadedPageReference(page) : ''
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
  const config = cloneReaderSessionConfig(baseConfig)
  config.chapterTitle = baseConfig.chapterTitle ?? manifest.chapterTitle
  config.chapterIds = chapterIds
  config.chapterTitles = chapterTitles
  config.totalPages = validation.pageCount
  config.pageUris = pageUris
  config.sourceOriginalImageUris = sourceOriginalImageUris
  config.pageTextOverlays = pageTextOverlays
  config.pageRequiredImageDecodes = undefined
  config.pageTextPages = undefined
  config.pageTextRequests = undefined
  config.pageIds = pageIds
  config.pageWidths = pageWidths
  config.pageHeights = pageHeights
  config.sourceMangaUrl = baseConfig.sourceMangaUrl ?? manifest.sourceMangaUrl
  config.offlinePages = complete ? offlinePages : undefined
  return config
}
