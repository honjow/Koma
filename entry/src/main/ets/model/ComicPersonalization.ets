import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import { taskpool, buffer, util } from '@kit.ArkTS'
import { Comic, copyComicShell, sameComicIdentity } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { LibraryStorePersistenceService, upsertComicAndPersistLibraryStore } from './LibraryPersistence'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export interface ComicCoverBackup { comicId: string; base64: string }
export interface PreparedComicCovers { libraryStore: string; files: string[] }

export async function selectComicCover(context: common.UIAbilityContext): Promise<string | undefined> {
  const result = await new photoAccessHelper.PhotoViewPicker().select({
    MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1,
  })
  if (result.photoUris.length === 0) return undefined
  const directory = `${context.filesDir}/comic-custom-covers`
  if (!await fs.access(directory)) await fs.mkdir(directory)
  const path = `${directory}/${util.generateRandomUUID()}.img`
  const picked = await fs.open(result.photoUris[0], fs.OpenMode.READ_ONLY)
  try {
    await fs.copyFile(picked.fd, path)
    const source = image.createImageSource(path)
    try { await source.getImageInfo() } finally { await source.release() }
    return fileUri.getUriFromPath(path)
  } catch (error) {
    try { await fs.unlink(path) } catch (_) {}
    throw error as Error
  } finally { await fs.close(picked) }
}

/** Commit against the latest library value after the asynchronous picker returns. */
export function saveComicPersonalization(library: LibraryStore, persistence: LibraryStorePersistenceService,
  baseline: Comic, notes: string | undefined, customCover: string | undefined, resetCover: boolean = false): void {
  if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
  const current = library.getComic(baseline.id)
  if (current === undefined || !sameComicIdentity(baseline, current)) throw new Error('comic_changed')
  const next = copyComicShell(current)
  if (notes !== undefined) next.personalNotes = notes.length === 0 ? undefined : notes
  if (resetCover || customCover !== undefined) {
    next.enhancedCoverUri = undefined
    next.enhancedCoverModel = undefined
  }
  if (resetCover) {
    next.coverUri = next.sourceCoverUri
    next.customCoverUri = undefined
    next.sourceCoverUri = undefined
  } else if (customCover !== undefined) {
    if (!next.customCoverUri) next.sourceCoverUri = next.coverUri
    next.customCoverUri = customCover
    next.coverUri = customCover
  }
  next.updatedAt = Date.now()
  upsertComicAndPersistLibraryStore(library, persistence, next, false)
}

export function saveComicCoverEnhancement(library: LibraryStore, persistence: LibraryStorePersistenceService,
  baseline: Comic, cover: string | undefined, model: string | undefined): Comic {
  if (BackupRestoreActivity.isRestoring() || BackupRestoreActivity.deviceSyncIsCommitting()) {
    throw new Error('backup_restore_busy')
  }
  const current = library.getComic(baseline.id)
  if (current === undefined || !sameComicIdentity(baseline, current) ||
    current.coverUri !== baseline.coverUri || current.customCoverUri !== baseline.customCoverUri ||
    current.enhancedCoverUri !== baseline.enhancedCoverUri) {
    throw new Error('comic_cover_changed')
  }
  const next = copyComicShell(current)
  next.enhancedCoverUri = cover
  next.enhancedCoverModel = model
  upsertComicAndPersistLibraryStore(library, persistence, next, false)
  return next
}

/** Keep the source bytes for smaller covers. Downsample only a private inference input. */
export async function prepareComicCoverEnhancementInput(uri: string, target: string, maxEdge: number): Promise<void> {
  const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
  let source: image.ImageSource | undefined
  let pixels: image.PixelMap | undefined
  let packer: image.ImagePacker | undefined
  try {
    source = image.createImageSource(file.fd)
    const size = (await source.getImageInfo()).size
    if (size.width <= 0 || size.height <= 0) throw new Error('cover_invalid_dimensions')
    const scale = maxEdge / Math.max(size.width, size.height)
    if (scale >= 1) {
      // The decoder may have read ahead on its descriptor. Copy from a fresh
      // handle so the small-cover branch always starts at the original bytes.
      const original = await fs.open(uri, fs.OpenMode.READ_ONLY)
      try { await fs.copyFile(original.fd, target) } finally { await fs.close(original) }
      return
    }
    // Use an equal scale on both axes. A lossless temporary PNG avoids adding
    // another JPEG generation before enhancement. The original is the preview source.
    const desiredSize: image.Size = {
      width: Math.max(1, Math.floor(size.width * scale)),
      height: Math.max(1, Math.floor(size.height * scale)),
    }
    pixels = await source.createPixelMap({ editable: false, desiredSize })
    packer = image.createImagePacker()
    const out = await fs.open(target, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    try {
      await packer.packToFile(pixels, out.fd, { format: 'image/png', quality: 100 })
    } finally { await fs.close(out) }
    DiagnosticLogger.info('cover-enhancement', 'source_resampled',
      `source=${size.width}x${size.height} input=${desiredSize.width}x${desiredSize.height}`)
  } finally {
    await packer?.release().catch((): void => {})
    await pixels?.release().catch((): void => {})
    await source?.release().catch((): void => {})
    await fs.close(file)
  }
}

/** Use an immutable file so different cover versions never alias a decoded image. */
export async function stageEnhancedComicCover(context: common.Context, sourcePath: string): Promise<string> {
  const directory = `${context.filesDir}/comic-custom-covers`
  if (!await fs.access(directory)) await fs.mkdir(directory)
  const path = `${directory}/${util.generateRandomUUID()}.jpg`
  try {
    await fs.copyFile(sourcePath, path)
    const file = await fs.open(path, fs.OpenMode.READ_WRITE)
    try { await fs.fsync(file.fd) } finally { await fs.close(file) }
    const source = image.createImageSource(path)
    try { await source.getImageInfo() } finally { await source.release() }
    return fileUri.getUriFromPath(path)
  } catch (error) {
    await discardPreparedComicCovers([path])
    throw error as Error
  }
}

@Concurrent
export function exportComicCoversWorker(filesDir: string, libraryJson: string, enhanced: boolean): string {
  const document = JSON.parse(libraryJson) as Record<string, Object>
  const comics = document['comics'] as Comic[]
  const covers: ComicCoverBackup[] = []
  for (const comic of comics) {
    const uri = enhanced ? comic.enhancedCoverUri : comic.customCoverUri
    if (!uri) continue
    const path = new fileUri.FileUri(uri).path
    // Only assets owned by this feature can enter a portable backup.
    if (!path.startsWith(`${filesDir}/comic-custom-covers/`) || path.includes('/../')) throw new Error('custom_cover_path_invalid')
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    try {
      const bytes = new ArrayBuffer(fs.statSync(file.fd).size)
      if (fs.readSync(file.fd, bytes) !== bytes.byteLength) throw new Error('custom_cover_read_incomplete')
      covers.push({ comicId: comic.id, base64: buffer.from(bytes).toString('base64') })
    } finally { fs.closeSync(file) }
  }
  return JSON.stringify(covers)
}

export async function exportComicCovers(context: common.Context, libraryJson: string,
  enhanced: boolean = false): Promise<ComicCoverBackup[]> {
  const result = await taskpool.execute(exportComicCoversWorker, context.filesDir, libraryJson, enhanced)
  return JSON.parse(result as string) as ComicCoverBackup[]
}

/** Build new immutable files before replacing any live library record. Rollback keeps the old files. */
export async function prepareRestoredComicCovers(context: common.Context, libraryJson: string,
  covers: ComicCoverBackup[] | undefined, enhancements?: ComicCoverBackup[]): Promise<PreparedComicCovers> {
  const document = JSON.parse(libraryJson) as Record<string, Object>
  const comics = document['comics'] as Comic[]
  const files: string[] = []
  try {
    await restoreComicCoverFiles(context, comics, covers, files, false)
    await restoreComicCoverFiles(context, comics, enhancements, files, true)
    return { libraryStore: JSON.stringify(document), files }
  } catch (error) { await discardPreparedComicCovers(files); throw error as Error }
}

async function restoreComicCoverFiles(context: common.Context, comics: Comic[],
  covers: ComicCoverBackup[] | undefined, files: string[], enhanced: boolean): Promise<void> {
  if (covers !== undefined && !Array.isArray(covers)) throw new Error('backup_custom_covers_invalid')
  const seen = new Set<string>()
  for (const cover of covers ?? []) {
    const comic = comics.find((row: Comic): boolean => row.id === cover.comicId)
    if (comic === undefined || (enhanced ? comic.enhancedCoverUri : comic.customCoverUri) === undefined || typeof cover.base64 !== 'string' || seen.has(cover.comicId)) {
      throw new Error('backup_custom_covers_invalid')
    }
    seen.add(cover.comicId)
    const bytes = new util.Base64Helper().decodeSync(cover.base64)
    const source = image.createImageSource(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength))
    try { await source.getImageInfo() } finally { await source.release() }
    const directory = `${context.filesDir}/comic-custom-covers`
    if (!await fs.access(directory)) await fs.mkdir(directory)
    const path = `${directory}/${util.generateRandomUUID()}.img`
    files.push(path)
    const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    try { await fs.write(file.fd, bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)); await fs.fsync(file.fd) }
    finally { await fs.close(file) }
    if (enhanced) comic.enhancedCoverUri = fileUri.getUriFromPath(path)
    else {
      comic.customCoverUri = fileUri.getUriFromPath(path)
      comic.coverUri = comic.customCoverUri
    }
  }
  if (comics.some((comic: Comic): boolean => (enhanced ? comic.enhancedCoverUri : comic.customCoverUri) !== undefined && !seen.has(comic.id))) {
    throw new Error('backup_custom_cover_missing')
  }
}

export async function discardPreparedComicCovers(files: string[]): Promise<void> {
  for (const path of files) { try { await fs.unlink(path) } catch (_) {} }
}

export async function discardUncommittedComicCover(context: common.Context, uri: string): Promise<void> {
  const path = new fileUri.FileUri(uri).path
  if (path.startsWith(`${context.filesDir}/comic-custom-covers/`) && !path.includes('/../')) {
    await discardPreparedComicCovers([path])
  }
}
