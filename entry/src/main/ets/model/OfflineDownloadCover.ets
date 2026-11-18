import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'
import { connection } from '@kit.NetworkKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ComicSourceKind } from './ComicModels'
import { resolveCachedCoverImage } from './CoverImageCacheService'
import { DOWNLOAD_METADATA_DIR_NAME } from './DownloadDirectoryIndex'
import { OfflineDownloadStore } from './OfflineDownloadStore'
import { configureReaderRemoteImageCache, fetchAndCacheSourceRuntimeCoverImage } from './ReaderPageSourceAdapter'
import { komaContentStorageBase } from './KomaContentStorage'

export interface DownloadCoverSource {
  uri: string
  sourceId?: string
  imageId: string
  mangaUrl?: string
  sourceKind?: ComicSourceKind
  serverId?: string
}

const savingCovers = new Map<string, Promise<string>>()

interface DownloadCoverLocation {
  workDir: string
  path: string
}

async function exists(path: string): Promise<boolean> {
  try { return await fs.access(path) } catch (_error) { return false }
}

/** A download's cover is work metadata. Clearing disposable image caches leaves it intact. */
async function saveCoverFile(workDir: string, localImage: string): Promise<string> {
  const metadata = workDir + '/' + DOWNLOAD_METADATA_DIR_NAME
  const target = metadata + '/cover'
  const temp = target + '.tmp'
  if (!await exists(workDir) || localImage === target) return localImage
  if (!await exists(metadata)) await fs.mkdir(metadata, true)
  let file: fs.File | undefined
  let source: image.ImageSource | undefined
  try {
    file = await fs.open(localImage, fs.OpenMode.READ_ONLY)
    source = image.createImageSource(file.fd)
    const info = await source.getImageInfo()
    if (info.size.width <= 0 || info.size.height <= 0) return localImage
    await fs.copyFile(file.fd, temp)
    await fs.rename(temp, target)
    return target
  } finally {
    await source?.release()
    if (file !== undefined) await fs.close(file)
    if (await exists(temp)) await fs.unlink(temp).catch(() => {})
  }
}

async function resolveOriginal(context: common.UIAbilityContext, request: DownloadCoverSource): Promise<string> {
  if (request.uri.startsWith('file://')) return request.uri
  if ((request.sourceId ?? '').length > 0 && !request.sourceId?.startsWith('mihon:')) {
    configureReaderRemoteImageCache(context.cacheDir)
    return fetchAndCacheSourceRuntimeCoverImage(request.sourceId!, request.uri, request.imageId, request.mangaUrl)
  }
  return resolveCachedCoverImage(context, {
    uri: request.uri,
    identity: request.imageId,
    sourceKind: request.sourceKind,
    remoteServerId: request.serverId,
  })
}

function connected(): boolean {
  try { return connection.getDefaultNetSync().netId !== 0 } catch (_error) { return false }
}

@Concurrent
function findDownloadCover(filesDir: string, owner: string, comicId: string,
  useChapterPage: boolean): DownloadCoverLocation {
  const store = new OfflineDownloadStore(filesDir, owner)
  const workDir = store.comicDir(comicId)
  const cover = workDir + '/' + DOWNLOAD_METADATA_DIR_NAME + '/cover'
  return {
    workDir,
    path: fs.accessSync(cover) ? cover : (useChapterPage ? store.findFirstDownloadedImage(comicId) : ''),
  }
}

/** Preserve the original cover when available and share in-flight copies across chapters and rows. */
export function persistDownloadCover(context: common.UIAbilityContext, workDir: string,
  request: DownloadCoverSource): Promise<string> {
  const existing = savingCovers.get(workDir)
  if (existing !== undefined) return existing
  const saving = (async (): Promise<string> => {
    const path = workDir + '/' + DOWNLOAD_METADATA_DIR_NAME + '/cover'
    if (await exists(path)) return path
    if (request.uri.length === 0 || !connected()) return ''
    const localImage = await resolveOriginal(context, request)
    return await saveCoverFile(workDir, localImage)
  })().catch((error: Error): string => {
    DiagnosticLogger.warn('downloads', 'offline_cover_unavailable', DiagnosticLogger.errorSummary(error))
    return ''
  }).finally(() => {
    savingCovers.delete(workDir)
  })
  savingCovers.set(workDir, saving)
  return saving
}

/** Old downloads can show a local page offline before the actual cover has been saved. */
export async function resolveDownloadCover(context: common.UIAbilityContext, comicId: string,
  request: DownloadCoverSource): Promise<string> {
  const storage = komaContentStorageBase(context)
  const offline = !connected() || request.uri.length === 0
  const location = await taskpool.execute(findDownloadCover, storage, context.filesDir, comicId,
    offline) as DownloadCoverLocation
  if (location.path.endsWith('/' + DOWNLOAD_METADATA_DIR_NAME + '/cover')) {
    hiTraceMeter.startTrace('KomaOfflineSavedCover', 0)
    hiTraceMeter.finishTrace('KomaOfflineSavedCover', 0)
  }
  if (location.path.length > 0 || offline) return location.path
  const saved = await persistDownloadCover(context, location.workDir, request)
  if (saved.length > 0) return saved
  const fallback = await taskpool.execute(findDownloadCover, storage, context.filesDir, comicId,
    true) as DownloadCoverLocation
  return fallback.path
}
