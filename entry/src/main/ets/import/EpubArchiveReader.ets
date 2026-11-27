import { taskpool, util } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { image } from '@kit.ImageKit'
import { EPUB_CONTAINER_PATH, epubImageReferences, epubIsPageDocument, epubPackagePath, EpubResource,
  parseEpubPackage, readEpubImages, readEpubPackage } from './EpubReadingOrder'
import { getExtension, isEpubArchivePath, isSupportedImagePath } from './ImageSortUtils'
import { nativeComicArchive } from './NativeArchiveExtraction'
import { comicArchiveExtractionRoot } from './ComicArchiveBookmarks'
import { Chapter, Comic, ComicSourceKind, isDeferredFolderArchiveChapter } from '../model/ComicModels'
import { FOLDER_EPUB_COVER_DIRECTORY, folderEpubCoverUri, localLibraryFolderRootUriFromComic } from '../model/LocalLibraryFolderContract'
import { activateLocalLibraryFolderAccess } from '../model/LocalLibraryFolderAccessService'

const EPUB_XML_LIMIT: number = 4 * 1024 * 1024
const EPUB_COVER_LIMIT: number = 32 * 1024 * 1024
const EPUB_COVER_PROBE_EDGE: number = 128

interface EpubCover {
  path: string
  bytes: ArrayBuffer
}

@Concurrent
function parseEpubOnWorker(root: string): string[] { return readEpubImages(root) }

export async function readOrderedEpubImages(extractionDir: string): Promise<string[]> {
  return await taskpool.execute(new taskpool.Task(parseEpubOnWorker, extractionDir)) as string[]
}

function coverUri(path: string): string {
  return 'file://' + path.split('/').map((segment: string): string => encodeURIComponent(segment)).join('/')
}

function isCoverDocument(resource: EpubResource): boolean {
  return epubIsPageDocument(resource) || /\.(?:xhtml|html|htm|svg)$/i.test(resource.path)
}

async function coverImages(resource: EpubResource, readText: (path: string) => Promise<string>): Promise<string[]> {
  if (!isCoverDocument(resource)) {
    return resource.mediaType.startsWith('image/') || isSupportedImagePath(resource.path) ? [resource.path] : []
  }
  const images: string[] = resource.mediaType === 'image/svg+xml' || /\.svg$/i.test(resource.path) ? [resource.path] : []
  try {
    return images.concat(epubImageReferences(await readText(resource.path), resource.path, false))
  } catch (_error) {
    return images
  }
}

async function checkCoverImage(source: image.ImageSource): Promise<void> {
  try {
    const size = (await source.getImageInfo()).size
    if (size.width < 1 || size.height < 1) throw new Error('Invalid EPUB cover image size')
    const scale = Math.min(1, EPUB_COVER_PROBE_EDGE / Math.max(size.width, size.height))
    const pixels = await source.createPixelMap({
      desiredSize: { width: Math.max(1, Math.round(size.width * scale)),
        height: Math.max(1, Math.round(size.height * scale)) },
    })
    await pixels.release()
  } finally {
    await source.release()
  }
}

@Concurrent
function parseExtractedEpubCovers(root: string): EpubResource[] { return readEpubPackage(root, false).covers }

/** An explicit cover may be outside the spine. It never becomes an extra reading page. */
export async function findExtractedEpubCover(root: string, fallbackPaths: string[] = []): Promise<string | undefined> {
  const declared = await taskpool.execute(new taskpool.Task(parseExtractedEpubCovers, root))
    .catch((): EpubResource[] => []) as EpubResource[]
  const visited = new Set<string>()
  const readText = (path: string): Promise<string> => fs.readText(`${root}/${path}`)
  for (const resource of declared.concat(fallbackPaths.map((path: string): EpubResource => ({ path, mediaType: '' })))) {
    for (const path of await coverImages(resource, readText)) {
      if (visited.has(path)) continue
      visited.add(path)
      try {
        const absolute = `${root}/${path}`
        await checkCoverImage(image.createImageSource(absolute))
        return coverUri(absolute)
      } catch (_error) {
        // Bad/missing cover: keep trying the remaining declarations and body images.
      }
    }
  }
  return undefined
}

async function zipEpubCover(archive: number): Promise<EpubCover | undefined> {
  const readText = async (path: string): Promise<string> => {
    const bytes = await nativeComicArchive.readZipEntry(archive, path, EPUB_XML_LIMIT)
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes))
  }
  const container = await readText(EPUB_CONTAINER_PATH).catch((): undefined => undefined)
  const packagePath = epubPackagePath(container)
  const xml = await readText(packagePath)
  const declared = parseEpubPackage(xml, packagePath, false).covers
  const visited = new Set<string>()
  const pick = async (resources: EpubResource[]): Promise<EpubCover | undefined> => {
    for (const resource of resources) {
      for (const path of await coverImages(resource, readText)) {
        if (visited.has(path)) continue
        visited.add(path)
        try {
          const bytes = await nativeComicArchive.readZipEntry(archive, path, EPUB_COVER_LIMIT)
          await checkCoverImage(image.createImageSource(bytes))
          return { path, bytes }
        } catch (_error) {
          // The optional cover must not prevent importing the folder.
        }
      }
    }
    return undefined
  }
  const cover = await pick(declared)
  if (cover !== undefined) return cover
  return pick(parseEpubPackage(xml, packagePath).readingOrder)
}

/** Persist only the selected cover bytes. Content-addressed paths keep re-scans idempotent
 * and ensure new cover pixels cannot reuse a cached image for an earlier archive revision. */
export async function saveFolderEpubCover(sourceUri: string, filesDir: string): Promise<string | undefined> {
  const archive = await fs.open(sourceUri, fs.OpenMode.READ_ONLY)
  let cover: EpubCover | undefined
  try {
    cover = await zipEpubCover(archive.fd)
  } finally {
    await fs.close(archive)
  }
  if (cover === undefined) return undefined
  const digest = cryptoFramework.createMd('SHA256')
  await digest.update({ data: new Uint8Array(cover.bytes) })
  const hash = Array.from((await digest.digest()).data)
    .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  const directory = `${filesDir}/${FOLDER_EPUB_COVER_DIRECTORY}`
  const extension = getExtension(cover.path)
  const path = `${directory}/${hash}${/^\.[a-z0-9]+$/i.test(extension) ? extension : '.img'}`
  if (await fs.access(path)) return coverUri(path)
  try {
    await fs.mkdir(directory, true)
  } catch (error) {
    if (!(await fs.stat(directory)).isDirectory()) throw error as Error
  }
  const temporary = `${path}.${util.generateRandomUUID()}.tmp`
  try {
    const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
    try {
      if (await fs.write(file.fd, cover.bytes) !== cover.bytes.byteLength) throw new Error('Incomplete EPUB cover write')
    } finally {
      await fs.close(file)
    }
    await fs.rename(temporary, path)
  } finally {
    await fs.unlink(temporary).catch((): void => {})
  }
  return coverUri(path)
}

/** Repair one work when its detail is opened. A folder grant remains the
 * authority for its archive; a standalone import can use its retained assets. */
export async function repairLocalEpubCover(comic: Comic, filesDir: string): Promise<string | undefined> {
  const storedCover = comic.customCoverUri ? comic.sourceCoverUri : comic.coverUri
  if (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE && isEpubArchivePath(comic.sourcePath)) {
    const firstPage = comic.chapters[0]?.pages[0]?.uri
    const root = firstPage === undefined ? undefined : comicArchiveExtractionRoot(firstPage)
    if (root === undefined) return undefined
    if (storedCover !== undefined && storedCover !== firstPage &&
      !comic.chapters[0]?.pages.some((page): boolean => page.uri === storedCover)) {
      const existing = storedCover.startsWith('file://') ? decodeURIComponent(storedCover.substring(7)) : ''
      if (existing && await fs.access(existing).catch((): boolean => false)) return undefined
    }
    const declared = await findExtractedEpubCover(root)
    if (declared !== undefined) return declared
    if (storedCover !== undefined && storedCover.startsWith('file://') &&
      await fs.access(decodeURIComponent(storedCover.substring(7))).catch((): boolean => false)) return undefined
    return findExtractedEpubCover(root, await readOrderedEpubImages(root))
  }
  if (comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER || comic.localMetadata?.coverOverridePath ||
    comic.chapters.some((chapter: Chapter): boolean => chapter.pages.length > 0)) return undefined
  const chapter = comic.chapters.find((item: Chapter): boolean =>
    isDeferredFolderArchiveChapter(item) && isEpubArchivePath(item.sourcePath))
  if (chapter === undefined || (storedCover !== undefined && folderEpubCoverUri(storedCover) === undefined)) return undefined
  if (storedCover !== undefined &&
    await fs.access(decodeURIComponent(storedCover.substring(7))).catch((): boolean => false)) return undefined
  const rootUri = localLibraryFolderRootUriFromComic(comic)
  if (rootUri === undefined) return undefined
  const access = await activateLocalLibraryFolderAccess(rootUri)
  if (access.status !== 'activated' && access.status !== 'persisted') return undefined
  return saveFolderEpubCover(chapter.sourcePath, filesDir)
}
