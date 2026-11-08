import { common } from '@kit.AbilityKit'
import {
  ReaderRemoteImageCacheStats,
  clearReaderRemoteImageCache,
  getReaderRemoteImageCacheStats,
} from './ReaderPageSourceAdapter'
import { clearCoverImageCache, getCoverImageCacheStats } from './CoverImageCacheService'
import { clearSourceIndexIconCache, getSourceIndexIconCacheStats } from './SourceIndexIconCache'

function aggregate(totalBytes: number, entryCount: number): ReaderRemoteImageCacheStats {
  return { totalBytes, entryCount }
}

/** User-facing image cache: reader pages, covers and source-index icons. */
export async function getAllImageCacheStats(context: common.UIAbilityContext): Promise<ReaderRemoteImageCacheStats> {
  const stats = await Promise.all([
    getReaderRemoteImageCacheStats(),
    getCoverImageCacheStats(context),
  ])
  const reader = stats[0]
  const covers = stats[1]
  const icons = getSourceIndexIconCacheStats(context)
  return aggregate(reader.totalBytes + covers.totalBytes + icons.totalBytes,
    reader.entryCount + covers.entryCount + icons.fileCount)
}

export async function clearAllImageCaches(context: common.UIAbilityContext): Promise<ReaderRemoteImageCacheStats> {
  await clearReaderRemoteImageCache()
  await clearCoverImageCache(context)
  clearSourceIndexIconCache(context)
  return getAllImageCacheStats(context)
}
