import { fileIo as fs, statfs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { taskpool } from '@kit.ArkTS'
import { ComicZipEntry, nativeComicArchive } from '../import/NativeArchiveExtraction'
import { downloadImageExtension } from './DownloadImageFormat'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { writeAppTextFile } from './AppFileTextPersistence'
import { downloadManifestPath, flatDownloadMetadataDirectory, legacyDownloadManifestPath,
  previousDownloadManifestPath } from './DownloadDirectoryIndex'
import { DownloadCbzMigrationWork, OfflineChapterDownloadManifest, OfflineDownloadedChapterStatus, OfflineDownloadedPage,
  OfflineDownloadStatus, OfflineDownloadStore, copyOfflineDownloadedPage, createOfflineDownloadFileContentHash,
  createOfflineDownloadStableHash, hasValidOfflineManifestIntegrity, isCompletedLooseDownload,
  isFlatDownloadPackagePath } from './OfflineDownloadStore'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { saveDownloadManifestAsync, validateDownloadManifestAsync } from './OfflineDownloadManifestWorker'

export const DOWNLOAD_CBZ_INSUFFICIENT_SPACE: string = 'download_cbz_insufficient_space'
const FILE_IO_NO_SPACE: number = 13900025
// Allow for ZIP directory records, the chapter manifest and the publish journal.
const CBZ_METADATA_RESERVE: number = 64 * 1024
const CBZ_METADATA_PER_PAGE: number = 1024
let cbzPublications: Promise<void> = Promise.resolve()

export function isDownloadCbzSpaceError(error: Error): boolean {
  return error?.message === DOWNLOAD_CBZ_INSUFFICIENT_SPACE || error?.message === 'archive_insufficient_space' ||
    (error as BusinessError)?.code === FILE_IO_NO_SPACE
}

async function checkCbzSpace(work: string, requiredBytes: number): Promise<void> {
  let available: number
  try {
    available = await statfs.getFreeSize(work)
  } catch (error) {
    // Older or externally provided paths may reject the query. The actual
    // filesystem write still reports ENOSPC and owns the final decision.
    DiagnosticLogger.exception('downloads', 'download_cbz_space_query_failed', error as Error)
    return
  }
  if (Number.isFinite(available) && available >= 0 && available < requiredBytes) {
    DiagnosticLogger.warn('downloads', 'download_cbz_insufficient_space', `required=${requiredBytes} available=${available}`)
    throw new Error(DOWNLOAD_CBZ_INSUFFICIENT_SPACE)
  }
}

function baseName(path: string): string {
  return path.substring(path.lastIndexOf('/') + 1)
}

function xml(value: string): string {
  return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '')
}

@Concurrent
function verifyDownloadCbz(path: string, pages: OfflineDownloadedPage[]): boolean {
  const entries = new Map<string, ComicZipEntry>()
  try {
    for (const entry of nativeComicArchive.listZipSync(path, true)) entries.set(entry.path, entry)
  } catch (_error) { return false }
  if (entries.size !== pages.length + 1 || !entries.has('ComicInfo.xml')) return false
  return pages.every((page: OfflineDownloadedPage): boolean => {
    const entry = entries.get(page.archiveEntry ?? '')
    return entry !== undefined && entry.size === page.size &&
      ((page.contentHash ?? '').length === 0 || entry.hash === page.contentHash)
  })
}

async function verifiedCbz(path: string, pages: OfflineDownloadedPage[]): Promise<boolean> {
  return await taskpool.execute(verifyDownloadCbz, path, pages) as boolean
}

@Concurrent
function prepareCbzPages(input: OfflineDownloadedPage[]): OfflineDownloadedPage[] {
  return input.slice().sort((left, right): number => left.pageIndex - right.pageIndex).map(
    (page: OfflineDownloadedPage): OfflineDownloadedPage => {
      if (page.archiveEntry !== undefined) throw new Error('download_cbz_mixed_formats')
      const name = page.localPath.substring(page.localPath.lastIndexOf('/') + 1)
      const file = fs.openSync(page.localPath, fs.OpenMode.READ_ONLY)
      const buffer = new ArrayBuffer(32)
      let count = 0
      try { count = fs.readSync(file.fd, buffer) } finally { fs.closeSync(file) }
      const extension = downloadImageExtension(new Uint8Array(buffer, 0, count))
      const copied = copyOfflineDownloadedPage(page)
      copied.fileName = name
      copied.archiveEntry = extension === undefined ? name : name.replace(/\.[^.]+$/, '.' + extension)
      copied.contentHash = page.contentHash ?? createOfflineDownloadFileContentHash(page.localPath)
      return copied
    })
}

function setPackagePath(pages: OfflineDownloadedPage[], path: string): OfflineDownloadedPage[] {
  for (const page of pages) page.localPath = path
  return pages
}

async function finishCbz(store: OfflineDownloadStore, manifest: OfflineChapterDownloadManifest): Promise<OfflineDownloadedPage[]> {
  const pages = await taskpool.execute(prepareCbzPages, manifest.pages) as OfflineDownloadedPage[]
  const files: string[] = []
  const names = new Set<string>()
  for (const page of pages) {
    const name = page.archiveEntry ?? ''
    if (!/^\d+\.[a-z0-9]+$/.test(name) || names.has(name)) throw new Error('download_cbz_page_name_invalid')
    files.push(page.localPath, name)
    names.add(name)
  }
  const info = '<?xml version="1.0" encoding="UTF-8"?><ComicInfo><Title>' + xml(manifest.chapterTitle ?? '') +
    '</Title><Series>' + xml(manifest.comicTitle ?? '') + '</Series><PageCount>' + pages.length + '</PageCount></ComicInfo>'
  // The ZIP writer stores images without recompressing them.
  const payloadBytes = pages.reduce((total, page): number => total + page.size, info.length * 4)
  return publishFlatCbz(store, manifest, pages, payloadBytes, (temp: string): Promise<void> =>
    nativeComicArchive.writeZip(temp, files, info))
}

function publishFlatCbz(store: OfflineDownloadStore, manifest: OfflineChapterDownloadManifest,
  pages: OfflineDownloadedPage[], payloadBytes: number,
  write: (temp: string) => Promise<void>): Promise<OfflineDownloadedPage[]> {
  // Downloads and conversion share the same disk budget. Serialize the check
  // and temporary file write so two packs cannot both spend the same free space.
  const publication = cbzPublications.then(() => writeFlatCbz(store, manifest, pages, payloadBytes, write))
  cbzPublications = publication.then((): void => {}, (): void => {})
  return publication
}

async function writeFlatCbz(store: OfflineDownloadStore, manifest: OfflineChapterDownloadManifest,
  pages: OfflineDownloadedPage[], payloadBytes: number,
  write: (temp: string) => Promise<void>): Promise<OfflineDownloadedPage[]> {
  const chapterDir = store.chapterDir(manifest.comicId, manifest.chapterId)
  const work = store.comicDir(manifest.comicId)
  const metadata = flatDownloadMetadataDirectory(chapterDir)
  const journal = metadata + '/publishing'
  if (fs.accessSync(journal)) {
    const name = fs.readTextSync(journal, { encoding: 'utf-8' })
    const pending = work + '/' + name
    if (name === baseName(name) && !name.includes('\\') && isFlatDownloadPackagePath(chapterDir, pending) &&
      fs.accessSync(pending) && await verifiedCbz(pending, pages)) return setPackagePath(pages, pending)
  }
  const stem = baseName(chapterDir)
  const suffix = createOfflineDownloadStableHash(manifest.chapterId).substring(0, 8)
  let path = work + '/' + stem + '.cbz'
  let collision = 1
  while (fs.accessSync(path)) {
    path = work + '/' + Array.from(stem).slice(0, 50).join('') + ' [' + suffix + '-' + collision + '].cbz'
    collision += 1
  }
  const temp = metadata + '/publishing.cbz.tmp'
  try {
    if (fs.accessSync(temp)) await fs.unlink(temp)
    await checkCbzSpace(work, payloadBytes + CBZ_METADATA_RESERVE + pages.length * CBZ_METADATA_PER_PAGE)
    if (!fs.accessSync(metadata)) fs.mkdirSync(metadata, true)
    writeAppTextFile(journal, baseName(path))
    await write(temp)
    if (!await verifiedCbz(temp, pages)) throw new Error('download_cbz_verify_failed')
    const file = await fs.open(temp, fs.OpenMode.READ_WRITE)
    try { await fs.fsync(file.fd) } finally { await fs.close(file) }
    if (fs.accessSync(path)) throw new Error('download_cbz_target_exists')
    fs.renameSync(temp, path)
    return setPackagePath(pages, path)
  } finally {
    if (fs.accessSync(temp)) await fs.unlink(temp).catch((): void => {})
  }
}

async function finishLoosePages(store: OfflineDownloadStore, manifest: OfflineChapterDownloadManifest):
  Promise<OfflineDownloadedPage[]> {
  const directory = store.chapterDir(manifest.comicId, manifest.chapterId)
  const pages: OfflineDownloadedPage[] = []
  for (const page of manifest.pages) {
    const target = directory + '/' + baseName(page.localPath)
    if (target !== page.localPath) {
      const temporary = target + '.download-tmp'
      try {
        await fs.copyFile(page.localPath, temporary)
        if ((await fs.stat(temporary)).size !== page.size) throw new Error('download_page_copy_incomplete')
        await fs.rename(temporary, target)
      } finally {
        if (fs.accessSync(temporary)) await fs.unlink(temporary).catch((): void => {})
      }
    }
    const copied = copyOfflineDownloadedPage(page)
    copied.localPath = target
    pages.push(copied)
  }
  return pages
}

/** Publish the completed chapter only after the output exists and is verified.
 * The old manifest and private checkpoint remain usable if packing is interrupted. */
export async function finishOfflineDownload(store: OfflineDownloadStore, manifest: OfflineChapterDownloadManifest,
  asCbz: boolean, canRemoveOriginals: () => boolean = () => true): Promise<OfflineChapterDownloadManifest> {
  if (manifest.pageCount === 0 || manifest.pages.length !== manifest.pageCount) throw new Error('download_pages_incomplete')
  const pages = asCbz ? await finishCbz(store, manifest) : await finishLoosePages(store, manifest)
  const previousPages = manifest.pages
  const previousStatus = manifest.status
  const previousReasonCode = manifest.failureReasonCode
  manifest.pages = pages
  manifest.status = OfflineDownloadStatus.DOWNLOADED
  manifest.failureReasonCode = undefined
  let committed: OfflineChapterDownloadManifest
  try {
    committed = await saveDownloadManifestAsync(store, manifest)
  } catch (error) {
    manifest.pages = previousPages
    manifest.status = previousStatus
    manifest.failureReasonCode = previousReasonCode
    throw error as Error
  }
  await cleanupCompletedDownload(store, committed, canRemoveOriginals)
  return committed
}

@Concurrent
function verifyLoosePage(path: string, size: number, hash: string): boolean {
  return fs.statSync(path).size === size && createOfflineDownloadFileContentHash(path) === hash
}

async function matchesLoosePage(path: string, page: OfflineDownloadedPage): Promise<boolean> {
  if (page.contentHash === undefined) return false
  return await taskpool.execute(verifyLoosePage, path, page.size, page.contentHash) as boolean
}

/** Also used on retry after a process was stopped just after the manifest was committed. */
export async function cleanupCompletedDownload(store: OfflineDownloadStore, manifest: OfflineChapterDownloadManifest,
  canRemoveOriginals: () => boolean = () => true): Promise<boolean> {
  const directory = store.chapterDir(manifest.comicId, manifest.chapterId)
  const stage = store.stagingDirectory(manifest.comicId, manifest.chapterId)
  const flat = isFlatDownloadPackagePath(directory, manifest.pages[0]?.localPath ?? '')
  const legacy = flat ? store.loadLegacyManifest(manifest.comicId, manifest.chapterId) : undefined
  try {
    if (!canRemoveOriginals()) return false
    if (legacy !== undefined && (legacy.comicId !== manifest.comicId || legacy.chapterId !== manifest.chapterId ||
      !hasValidOfflineManifestIntegrity(legacy))) return false
    const originalArchive = legacy?.pages.find((page: OfflineDownloadedPage): boolean =>
      page.archiveEntry !== undefined)?.localPath ?? ''
    if (originalArchive.startsWith(directory + '/') && originalArchive === directory + '/' + baseName(originalArchive) &&
      /\.cbz$/i.test(originalArchive) && fs.accessSync(originalArchive)) {
      if (!await verifiedCbz(originalArchive, manifest.pages) || !canRemoveOriginals()) return false
      fs.unlinkSync(originalArchive)
    }
    for (const page of manifest.pages) {
      const name = page.fileName ?? ''
      if (page.archiveEntry !== undefined && /^\d+\.[a-zA-Z0-9]+$/.test(name)) {
        const loose = directory + '/' + name
        if (fs.accessSync(loose) && await matchesLoosePage(loose, page)) {
          if (!canRemoveOriginals()) return false
          fs.unlinkSync(loose)
        }
      }
    }
    if (flat) {
      if (!canRemoveOriginals()) return false
      for (const path of [downloadManifestPath(directory), previousDownloadManifestPath(directory),
        legacyDownloadManifestPath(directory), flatDownloadMetadataDirectory(directory) + '/publishing']) {
        if (fs.accessSync(path)) fs.unlinkSync(path)
      }
      const previousMetadata = directory + '/.koma'
      if (fs.accessSync(previousMetadata) && fs.listFileSync(previousMetadata).length === 0) fs.rmdirSync(previousMetadata)
      if (fs.accessSync(directory) && fs.listFileSync(directory).length === 0) fs.rmdirSync(directory)
    }
    if (fs.accessSync(stage)) await fs.rmdir(stage)
    return true
  } catch (error) {
    DiagnosticLogger.exception('downloads', 'download_staging_cleanup_failed', error as Error)
    return false
  }
}

@Concurrent
function findLooseDownloadChapters(filesDir: string, runtimeKey: string, comicId: string,
  chapterIds: string[]): string[] {
  const store = new OfflineDownloadStore(filesDir, runtimeKey)
  return chapterIds.filter((chapterId: string): boolean => {
    const manifest = store.loadManifest(comicId, chapterId)
    return manifest !== undefined && manifest.comicId === comicId && manifest.chapterId === chapterId &&
      isCompletedLooseDownload(manifest)
  })
}

/** Read only the requested download manifests. The actual conversion revalidates
 * the chapter and page files before touching the existing download. */
export async function listLooseDownloadChapters(filesDir: string, runtimeKey: string, comicId: string,
  chapterIds: string[]): Promise<string[]> {
  if (chapterIds.length === 0) return []
  return await taskpool.execute(findLooseDownloadChapters, filesDir, runtimeKey, comicId, chapterIds) as string[]
}

export async function convertDownloadedChapterToCbz(store: OfflineDownloadStore, comicId: string, chapterId: string):
  Promise<boolean> {
  return migrateDownloadedChapterToFlatCbz(store, comicId, chapterId, true)
}

export async function migrateDownloadedChapterToFlatCbz(store: OfflineDownloadStore, comicId: string, chapterId: string,
  convertLoose: boolean, canRemoveOriginals: () => boolean = () => true): Promise<boolean> {
  const runtimeKey = store.runtimeKey()
  if (OfflineDownloadRuntime.isActive(runtimeKey, comicId, chapterId)) throw new Error('download_active')
  let converted = false
  await OfflineDownloadRuntime.run(runtimeKey, comicId, chapterId, async (): Promise<OfflineChapterDownloadManifest> => {
    const validation = await validateDownloadManifestAsync(store, comicId, chapterId)
    const manifest = validation.manifest
    if (validation.status !== OfflineDownloadedChapterStatus.DOWNLOADED || manifest === undefined) {
      throw new Error('chapter_export_download_incomplete')
    }
    if (manifest.pages.every((page: OfflineDownloadedPage): boolean => page.archiveEntry !== undefined)) {
      const chapterDir = store.chapterDir(comicId, chapterId)
      const original = manifest.pages[0].localPath
      if (isFlatDownloadPackagePath(chapterDir, original)) {
        const wasPending = store.loadLegacyManifest(comicId, chapterId) !== undefined
        if (!await cleanupCompletedDownload(store, manifest, canRemoveOriginals)) throw new Error('download_cbz_cleanup_pending')
        converted = wasPending
        return manifest
      }
      if (!manifest.pages.every((page: OfflineDownloadedPage): boolean => page.localPath === original)) {
        throw new Error('download_cbz_mixed_formats')
      }
      const pages = manifest.pages.map(copyOfflineDownloadedPage)
      const archiveBytes = (await fs.stat(original)).size
      manifest.pages = await publishFlatCbz(store, manifest, pages, archiveBytes,
        (temp: string): Promise<void> => fs.copyFile(original, temp))
      const committed = await saveDownloadManifestAsync(store, manifest)
      if (!await cleanupCompletedDownload(store, committed, canRemoveOriginals)) throw new Error('download_cbz_cleanup_pending')
      converted = true
      return committed
    }
    if (!isCompletedLooseDownload(manifest)) throw new Error('download_cbz_mixed_formats')
    if (!convertLoose) return manifest
    const completed = await finishOfflineDownload(store, manifest, true, canRemoveOriginals)
    if (store.loadLegacyManifest(comicId, chapterId) !== undefined) throw new Error('download_cbz_cleanup_pending')
    converted = true
    return completed
  })
  return converted
}

export interface DownloadCbzConversionResult {
  converted: number
  failed: number
  insufficientSpace: number
}

export interface DownloadCbzMigrationOptions {
  convertLoose: boolean
  canRemoveOriginals: () => boolean
}

@Concurrent
function planFlatCbzMigration(filesDir: string, runtimeKey: string, convertLoose: boolean): DownloadCbzMigrationWork[] {
  return new OfflineDownloadStore(filesDir, runtimeKey).legacyCbzMigrationPlan(convertLoose)
}

export async function listFlatCbzMigrationWork(filesDir: string, runtimeKey: string,
  convertLoose: boolean): Promise<DownloadCbzMigrationWork[]> {
  return await taskpool.execute(planFlatCbzMigration, filesDir, runtimeKey, convertLoose) as DownloadCbzMigrationWork[]
}

/** Pack one chapter at a time so the extra disk space is bounded by the current chapter.
 * The same operation serves a chapter row and an entire work. */
export async function convertDownloadedChaptersToCbz(store: OfflineDownloadStore, comicId: string,
  chapterIds: string[],
  onChapterHandled: (processed: number, result: DownloadCbzConversionResult) => void = () => {},
  migration?: DownloadCbzMigrationOptions):
  Promise<DownloadCbzConversionResult> {
  const result: DownloadCbzConversionResult = { converted: 0, failed: 0, insufficientSpace: 0 }
  let processed = 0
  for (const chapterId of chapterIds) {
    try {
      if (migration !== undefined) {
        if (await runUpgradeChapterMigration(store, comicId, chapterId, migration)) result.converted += 1
      } else if (await convertDownloadedChapterToCbz(store, comicId, chapterId)) result.converted += 1
    } catch (error) {
      result.failed += 1
      if (isDownloadCbzSpaceError(error as Error)) result.insufficientSpace += 1
      DiagnosticLogger.exception('downloads', 'download_convert_cbz_failed', error as Error)
    }
    processed += 1
    onChapterHandled(processed, result)
  }
  return result
}

async function runUpgradeChapterMigration(store: OfflineDownloadStore, comicId: string, chapterId: string,
  options: DownloadCbzMigrationOptions): Promise<boolean> {
  // While a reader holds paths from the old manifest, leave those assets intact.
  while (true) {
    while (!options.canRemoveOriginals()) await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 800) })
    try {
      return await migrateDownloadedChapterToFlatCbz(store, comicId, chapterId, options.convertLoose, options.canRemoveOriginals)
    } catch (error) {
      if ((error as Error).message !== 'download_cbz_cleanup_pending' || options.canRemoveOriginals()) throw error as Error
    }
  }
}
