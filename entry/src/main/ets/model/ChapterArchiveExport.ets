import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { zlib } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { OfflineDownloadedChapterStatus, OfflineDownloadStore } from './OfflineDownloadStore'
import { AppStrings } from '../i18n/AppStrings'
import { SourceTextOverlay } from './SourceTextOverlay'
import { fetchAndCacheReaderRemoteSource, ReaderPageRenderKind } from './ReaderPageSourceAdapter'
import { ensureKomaContentStorageBase } from './KomaContentStorage'

export interface ChapterArchiveFile { path: string; uri: string; fileName: string }
interface ArchivePage { path: string; name: string; pageId?: string; sourceId?: string; overlay?: SourceTextOverlay }


@Concurrent
export function chapterArchivePagesWorker(filesDir: string, appFilesDir: string, comicId: string, chapterId: string): string {
  const imageSuffix = (path: string): string => {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    const bytes = new ArrayBuffer(32)
    let count: number
    try { count = fs.readSync(file.fd, bytes) } finally { fs.closeSync(file) }
    const data = new Uint8Array(bytes, 0, count)
    if (data[0] === 0xff && data[1] === 0xd8) return 'jpg'
    if (data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4e && data[3] === 0x47) return 'png'
    const header = Array.from(data).map((value: number): string => String.fromCharCode(value)).join('')
    if (header.startsWith('GIF8')) return 'gif'
    if (header.startsWith('RIFF') && header.substring(8, 12) === 'WEBP') return 'webp'
    if (header.startsWith('BM')) return 'bmp'
    if (header.substring(4, 8) === 'ftyp') {
      if (header.includes('avif') || header.includes('avis')) return 'avif'
      if (header.includes('heic') || header.includes('heix') || header.includes('mif1')) return 'heic'
    }
    throw new Error('chapter_export_image_format_unknown')
  }
  // Existing integrity/path checks run off the UI thread. Export only complete
  // received originals, never manifests, source URLs, sessions or credentials.
  const validation = new OfflineDownloadStore(filesDir, appFilesDir).validateDownloadedChapter(comicId, chapterId)
  if (validation.status !== OfflineDownloadedChapterStatus.DOWNLOADED || validation.manifest === undefined) {
    throw new Error('chapter_export_download_incomplete')
  }
  const pages: ArchivePage[] = validation.manifest.pages.slice()
    .sort((left, right): number => left.pageIndex - right.pageIndex)
    .map((page, index: number): ArchivePage => {
      const name = `${String(index + 1).padStart(5, '0')}.${page.sourceTextOverlay === undefined ? imageSuffix(page.localPath) : 'jpg'}`
      if (page.sourceTextOverlay === undefined) return { path: page.localPath, name }
      return { path: page.localPath, name, pageId: page.pageId, sourceId: validation.manifest?.sourceId,
        overlay: page.sourceTextOverlay }
    })
  return JSON.stringify(pages)
}

function xml(value: string): string {
  return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&apos;').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '')
}

export async function prepareChapterArchive(context: common.UIAbilityContext,
  comicId: string, chapterId: string, comicTitle: string, chapterTitle: string): Promise<ChapterArchiveFile> {
  const storageBase = await ensureKomaContentStorageBase(context)
  const plan = await taskpool.execute(chapterArchivePagesWorker, storageBase, context.filesDir, comicId, chapterId) as string
  const pages = JSON.parse(plan) as ArchivePage[]
  const directory = await fs.mkdtemp(`${context.cacheDir}/chapter-export-XXXXXX`)
  const staging = `${directory}/pages`
  const fileName = `${comicTitle} - ${chapterTitle}`.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').slice(0, 140) + '.cbz'
  const path = `${directory}/${fileName}`
  await fs.mkdir(staging)
  const copied: string[] = []
  try {
    for (const page of pages) {
      // A CBZ cannot carry the local overlay descriptor: export the same
      // presentation as Reader, while retaining original download bytes/hash.
      const sourcePath = page.overlay === undefined ? page.path : await fetchAndCacheReaderRemoteSource({
        kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE, uri: `file://${page.path}`, imageUri: page.path,
        pageId: page.pageId, sourceRuntimeId: page.sourceId, sourceTextOverlay: page.overlay, skipBannerFilter: true,
      }, context)
      copied.push(`${staging}/${page.name}`)
      await fs.copyFile(sourcePath, copied[copied.length - 1])
    }
    const metadataPath = `${staging}/ComicInfo.xml`
    copied.push(metadataPath)
    const metadata = await fs.open(metadataPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    try {
      await fs.write(metadata.fd, `<?xml version="1.0" encoding="UTF-8"?><ComicInfo><Title>${xml(chapterTitle)}</Title>` +
        `<Series>${xml(comicTitle)}</Series><PageCount>${pages.length}</PageCount></ComicInfo>`)
    } finally { await fs.close(metadata) }
    await zlib.compressFile(staging, path + '.zip', { level: zlib.CompressLevel.COMPRESS_LEVEL_NO_COMPRESSION })
    await fs.rename(path + '.zip', path)
    // Keep this immutable cache file for the receiving app after the panel closes.
    return { path, uri: fileUri.getUriFromPath(path), fileName }
  } catch (error) {
    try { await fs.unlink(path + '.zip') } catch (_) {}
    throw error as Error
  } finally {
    for (const copiedPath of copied) { try { await fs.unlink(copiedPath) } catch (_) {} }
    try { await fs.rmdir(staging) } catch (_) {}
  }
}

/** One presentation owner per page; the prepared archive outlives the system panel. */
export class ChapterArchiveActions {
  private sharing?: systemShare.ShareController
  private busy: boolean = false

  async perform(context: common.UIAbilityContext, comicId: string, chapterId: string,
    comicTitle: string, chapterTitle: string, share: boolean, isActive: () => boolean): Promise<void> {
    if (this.busy || this.sharing !== undefined) return
    this.busy = true
    try {
      const file = await prepareChapterArchive(context, comicId, chapterId, comicTitle, chapterTitle)
      if (!isActive()) return
      if (share) {
        const controller = new systemShare.ShareController(new systemShare.SharedData({
          utd: utd.UniformDataType.FILE, title: file.fileName, uri: file.uri,
        }))
        this.sharing = controller
        const dismiss = (): void => { controller.off('dismiss', dismiss); if (this.sharing === controller) this.sharing = undefined }
        controller.on('dismiss', dismiss)
        try { await controller.show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
          previewMode: systemShare.SharePreviewMode.DEFAULT }) }
        catch (error) { dismiss(); throw error as Error }
      } else {
        const targets = await new picker.DocumentViewPicker(context).save({
          newFileNames: [file.fileName], fileSuffixChoices: [AppStrings.get('chapter_archive_type') + '|.cbz'],
        })
        if (targets.length === 0) return
        const target = await fs.open(targets[0], fs.OpenMode.WRITE_ONLY)
        try { await fs.copyFile(file.path, target.fd) } finally { await fs.close(target) }
      }
    } finally { this.busy = false }
  }
}
