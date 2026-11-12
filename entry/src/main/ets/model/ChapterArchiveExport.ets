import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { BusinessError, zlib } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { OfflineDownloadedChapterStatus, OfflineDownloadStore } from './OfflineDownloadStore'
import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { SourceTextOverlay } from './SourceTextOverlay'
import { fetchAndCacheReaderRemoteSource, ReaderPageRenderKind } from './ReaderPageSourceAdapter'
import { ensureKomaContentStorageBase } from './KomaContentStorage'

export interface ChapterArchiveFile { path: string; uri: string; fileName: string }
export interface ArchiveChapter {
  id: string
  title: string
}

export interface WorkArchiveProgress {
  isCanceled: () => boolean
  onChapterPrepared: (count: number) => void
}

export const CHAPTER_ARCHIVE_CANCELED: string = 'chapter_archive_canceled'
export const CHAPTER_ARCHIVE_INCOMPLETE: string = 'chapter_archive_incomplete:'
export const CHAPTER_ARCHIVE_SAVE_FAILED: string = 'chapter_archive_save_failed'
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
  return await prepareArchive(context, comicId, comicTitle, [{ id: chapterId, title: chapterTitle }], chapterTitle)
}

export async function prepareWorkArchive(context: common.UIAbilityContext, comicId: string, comicTitle: string,
  chapters: ArchiveChapter[], progress: WorkArchiveProgress): Promise<ChapterArchiveFile> {
  return await prepareArchive(context, comicId, comicTitle, chapters, undefined, progress)
}

async function prepareArchive(context: common.UIAbilityContext, comicId: string, comicTitle: string,
  chapters: ArchiveChapter[], singleChapterTitle?: string, progress?: WorkArchiveProgress): Promise<ChapterArchiveFile> {
  const checkCanceled = (): void => {
    if (progress?.isCanceled()) throw new Error(CHAPTER_ARCHIVE_CANCELED)
  }
  if (chapters.length === 0) throw new Error('chapter_archive_empty')
  checkCanceled()
  const storageBase = await ensureKomaContentStorageBase(context)
  const directory = await fs.mkdtemp(`${context.cacheDir}/chapter-export-XXXXXX`)
  const staging = `${directory}/pages`
  const title = singleChapterTitle === undefined ? comicTitle : `${comicTitle} - ${singleChapterTitle}`
  const fileName = title.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').slice(0, 140) + '.cbz'
  const path = `${directory}/${fileName}`
  await fs.mkdir(staging)
  const copied: string[] = []
  const chapterBookmarks: string[] = []
  let pageCount = 0
  let ready = false
  try {
    for (let index = 0; index < chapters.length; index += 1) {
      checkCanceled()
      const chapter = chapters[index]
      let plan: string
      try {
        plan = await taskpool.execute(chapterArchivePagesWorker, storageBase, context.filesDir, comicId, chapter.id) as string
      } catch (error) {
        if (progress !== undefined) throw new Error(CHAPTER_ARCHIVE_INCOMPLETE + chapter.title)
        throw error as Error
      }
      const pages = JSON.parse(plan) as ArchivePage[]
      // ComicInfo indexes the sorted image list from zero. Preserve the user's
      // chosen chapter order so a reimported work can navigate to each chapter.
      if (progress !== undefined && pages.length > 0) {
        chapterBookmarks.push(`<Page Image="${pageCount}" Bookmark="${xml(chapter.title)}"/>`)
      }
      for (const page of pages) {
        checkCanceled()
        // A CBZ cannot carry the local overlay descriptor. Export the Reader
        // presentation while retaining original download bytes and hash.
        const sourcePath = page.overlay === undefined ? page.path : await fetchAndCacheReaderRemoteSource({
          kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE, uri: `file://${page.path}`, imageUri: page.path,
          pageId: page.pageId, sourceRuntimeId: page.sourceId, sourceTextOverlay: page.overlay, skipBannerFilter: true,
        }, context)
        pageCount += 1
        const name = progress === undefined ? page.name :
          `${String(pageCount).padStart(8, '0')}${page.name.substring(page.name.lastIndexOf('.'))}`
        copied.push(`${staging}/${name}`)
        try {
          await fs.copyFile(sourcePath, copied[copied.length - 1])
        } catch (error) {
          if (progress !== undefined && !fs.accessSync(sourcePath)) {
            throw new Error(CHAPTER_ARCHIVE_INCOMPLETE + chapter.title)
          }
          throw error as Error
        }
      }
      progress?.onChapterPrepared(index + 1)
    }
    checkCanceled()
    const metadataPath = `${staging}/ComicInfo.xml`
    copied.push(metadataPath)
    const metadata = await fs.open(metadataPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    try {
      await fs.write(metadata.fd, `<?xml version="1.0" encoding="UTF-8"?><ComicInfo><Title>${xml(singleChapterTitle ?? comicTitle)}</Title>` +
        `<Series>${xml(comicTitle)}</Series><PageCount>${pageCount}</PageCount>` +
        `${chapterBookmarks.length > 0 ? `<Pages>${chapterBookmarks.join('')}</Pages>` : ''}</ComicInfo>`)
    } finally { await fs.close(metadata) }
    await zlib.compressFile(staging, path + '.zip', { level: zlib.CompressLevel.COMPRESS_LEVEL_NO_COMPRESSION })
    checkCanceled()
    await fs.rename(path + '.zip', path)
    ready = true
    // Keep this immutable cache file for the receiving app after the panel closes.
    return { path, uri: fileUri.getUriFromPath(path), fileName }
  } catch (error) {
    try { await fs.unlink(path + '.zip') } catch (_) {}
    throw error as Error
  } finally {
    for (const copiedPath of copied) { try { await fs.unlink(copiedPath) } catch (_) {} }
    try { await fs.rmdir(staging) } catch (_) {}
    if (!ready) { try { await fs.rmdir(directory) } catch (_) {} }
  }
}

export async function saveChapterArchive(context: common.UIAbilityContext, file: ChapterArchiveFile): Promise<boolean> {
  let source: fs.File | undefined
  let target: fs.File | undefined
  let stage = 'picker'
  try {
    const targets = await new picker.DocumentViewPicker(context).save({
      newFileNames: [file.fileName], fileSuffixChoices: [AppStrings.get('chapter_archive_type') + '|.cbz'],
    })
    if (targets.length === 0) return false
    stage = 'source'
    source = await fs.open(file.path, fs.OpenMode.READ_ONLY)
    stage = 'destination'
    // Use the picker grant to open the document, then copy via descriptors.
    target = await fs.open(targets[0], fs.OpenMode.READ_WRITE)
    stage = 'copy'
    await fs.copyFile(source.fd, target.fd, 0)
    return true
  } catch (error) {
    DiagnosticLogger.warn('downloads', CHAPTER_ARCHIVE_SAVE_FAILED,
      'stage=' + stage + ' code=' + String((error as BusinessError).code ?? 0))
    throw new Error(CHAPTER_ARCHIVE_SAVE_FAILED)
  } finally {
    if (target !== undefined) { try { await fs.close(target) } catch (_) {} }
    if (source !== undefined) { try { await fs.close(source) } catch (_) {} }
  }
}

export async function discardPreparedArchive(file: ChapterArchiveFile): Promise<void> {
  try {
    await fs.unlink(file.path)
    await fs.rmdir(file.path.substring(0, file.path.lastIndexOf('/')))
  } catch (_) {}
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
        await saveChapterArchive(context, file)
      }
    } finally { this.busy = false }
  }
}
