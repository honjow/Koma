import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  DownloadDirectoryIndexFile,
  DownloadComicIndexEntry,
  downloadComicDirectoryName,
  downloadManifestPath,
  downloadPageFileName,
  legacyDownloadManifestPath,
  loadOrScanDownloadDirectoryIndex,
  previousDownloadManifestPath,
  sanitizeDownloadSegment,
  saveDownloadDirectoryIndex,
  uniqueDownloadDirectory,
} from './DownloadDirectoryIndex'

export type DownloadSourceNameResolver = (sourceId: string) => string

interface LayoutManifestPage {
  pageIndex: number
  fileName?: string
  localPath: string
}

interface LayoutManifest {
  comicId: string
  chapterId: string
  comicTitle?: string
  chapterTitle?: string
  sourceId?: string
  sourceName?: string
  pages: LayoutManifestPage[]
}

function joinPath(parent: string, child: string): string {
  const left = parent.replace(/\/+$/, '')
  const right = child.replace(/^\/+/, '').replace(/\/+$/, '')
  return right.length === 0 ? left : left + '/' + right
}

function isDirectory(path: string): boolean {
  try {
    return fs.accessSync(path) && fs.statSync(path).isDirectory()
  } catch (_error) {
    return false
  }
}

function ensureDirectory(path: string): void {
  try {
    fs.mkdirSync(path, true)
  } catch (_error) {
    if (!fs.accessSync(path)) throw new Error('download_layout_directory_unavailable')
  }
}

function isLegacyHashDirectory(name: string): boolean {
  return /^[0-9a-f]{16}$/.test(name)
}

function fileExtension(name: string): string {
  const dot = name.lastIndexOf('.')
  return dot >= 0 && dot < name.length - 1 ? name.substring(dot + 1) : 'jpg'
}

function readManifest(chapterDir: string): LayoutManifest | undefined {
  const paths: string[] = [downloadManifestPath(chapterDir), previousDownloadManifestPath(chapterDir),
    legacyDownloadManifestPath(chapterDir)]
  for (const path of paths) {
    if (!fs.accessSync(path)) continue
    try {
      return JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as LayoutManifest
    } catch (_error) {
      return undefined
    }
  }
  return undefined
}

function writeManifest(chapterDir: string, manifest: LayoutManifest): void {
  ensureDirectory(joinPath(chapterDir, '.koma'))
  const path = downloadManifestPath(chapterDir)
  const temporary = path + '.tmp'
  const file = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
  try {
    fs.writeSync(file.fd, JSON.stringify(manifest), { encoding: 'utf-8' })
    fs.fsyncSync(file.fd)
  } finally {
    fs.closeSync(file)
  }
  if (fs.accessSync(path)) fs.unlinkSync(path)
  fs.renameSync(temporary, path)
  const previousPath = previousDownloadManifestPath(chapterDir)
  try { if (fs.accessSync(previousPath)) fs.unlinkSync(previousPath) } catch (_error) {}
  const legacyPath = legacyDownloadManifestPath(chapterDir)
  try { if (fs.accessSync(legacyPath)) fs.unlinkSync(legacyPath) } catch (_error) {}
}

function normalizeChapterPages(chapterDir: string, manifest: LayoutManifest): boolean {
  if (!Array.isArray(manifest.pages)) return false
  let changed = false
  for (const page of manifest.pages) {
    const previousFileName = page.fileName
    const previousLocalPath = page.localPath
    let source = page.localPath
    const sourceName = page.fileName ?? source.split('/').pop() ?? ''
    if (!fs.accessSync(source)) {
      const movedSource = joinPath(chapterDir, sourceName)
      if (fs.accessSync(movedSource)) source = movedSource
    }
    const targetName = downloadPageFileName(page.pageIndex, fileExtension(sourceName))
    const target = joinPath(chapterDir, targetName)
    if (source === target && page.fileName === targetName) {
      page.localPath = target
      continue
    }
    if (source !== target && fs.accessSync(source) && !fs.accessSync(target)) {
      fs.renameSync(source, target)
    }
    page.fileName = targetName
    page.localPath = target
    if (page.fileName !== previousFileName || page.localPath !== previousLocalPath) changed = true
  }
  return changed
}

function removeEmptyDirectory(path: string): void {
  try {
    if (isDirectory(path) && fs.listFileSync(path).length === 0) fs.rmdirSync(path)
  } catch (_error) {}
}

function sourceNameForDirectory(comic: DownloadComicIndexEntry,
  resolver?: DownloadSourceNameResolver): string {
  const stored = comic.sourceName?.trim() ?? ''
  if (stored.length > 0) return stored
  const sourceId = comic.sourceId?.trim() ?? ''
  if (sourceId.length === 0) return ''
  const resolved = resolver?.(sourceId)?.trim() ?? ''
  return resolved.length > 0 ? resolved : sourceId
}

/**
 * Rename legacy hash folders to readable work/chapter names and rewrite page paths.
 * User-visible Download layout is data: keep this conservative and idempotent.
 */
export function normalizeDownloadLayout(rootDir: string,
  sourceNameResolver?: DownloadSourceNameResolver): void {
  let index: DownloadDirectoryIndexFile
  try {
    index = loadOrScanDownloadDirectoryIndex(rootDir)
  } catch (error) {
    DiagnosticLogger.exception('storage', 'download_layout_scan_failed', error as Error)
    return
  }
  let migratedChapters = 0
  let migratedPages = 0
  let indexChanged = false
  const comicIds = Object.keys(index.comics)
  for (const comicId of comicIds) {
    const comic = index.comics[comicId]
    const currentComicDir = joinPath(rootDir, comic.directory)
    if (!isDirectory(currentComicDir)) continue
    const resolvedSourceName = sourceNameForDirectory(comic, sourceNameResolver)
    if (resolvedSourceName.length > 0 && comic.sourceName !== resolvedSourceName) {
      comic.sourceName = resolvedSourceName
      indexChanged = true
    }
    const comicReadable = !isLegacyHashDirectory(comic.directory)
    const requestedComicName = downloadComicDirectoryName(comic.title, resolvedSourceName)
    const comicAlreadyNamed = comicReadable && (comic.directory === requestedComicName ||
      comic.directory.startsWith(requestedComicName + ' ('))
    let targetComicName = comic.directory
    if (!comicAlreadyNamed) {
      targetComicName = uniqueDownloadDirectory(rootDir, requestedComicName)
      comic.directory = targetComicName
      ensureDirectory(joinPath(rootDir, targetComicName))
      indexChanged = true
    }
    const targetComicDir = joinPath(rootDir, targetComicName)
    const chapterIds = Object.keys(comic.chapters)
    for (const chapterId of chapterIds) {
      const chapter = comic.chapters[chapterId]
      const sourceChapterDir = joinPath(currentComicDir, chapter.directory)
      if (!isDirectory(sourceChapterDir)) continue
      const chapterReadable = !isLegacyHashDirectory(chapter.directory)
      let targetChapterName = chapter.directory
      if (!comicReadable || !chapterReadable) {
        const requested = sanitizeDownloadSegment(chapter.title, '章节')
        targetChapterName = uniqueDownloadDirectory(targetComicDir, requested)
        chapter.directory = targetChapterName
        indexChanged = true
      }
      const targetChapterDir = joinPath(targetComicDir, targetChapterName)
      if (sourceChapterDir !== targetChapterDir) {
        ensureDirectory(targetComicDir)
        if (fs.accessSync(targetChapterDir)) {
          targetChapterName = uniqueDownloadDirectory(targetComicDir,
            sanitizeDownloadSegment(chapter.title, '章节'))
          chapter.directory = targetChapterName
          indexChanged = true
        }
        fs.renameSync(sourceChapterDir, joinPath(targetComicDir, targetChapterName))
      }
      const finalChapterDir = joinPath(targetComicDir, chapter.directory)
      const manifest = readManifest(finalChapterDir)
      if (manifest === undefined) continue
      try {
        let manifestChanged = !fs.accessSync(downloadManifestPath(finalChapterDir))
        if (resolvedSourceName.length > 0 && manifest.sourceName !== resolvedSourceName) {
          manifest.sourceName = resolvedSourceName
          manifestChanged = true
        }
        if ((manifest.sourceId ?? '').length === 0 && (comic.sourceId ?? '').length > 0) {
          manifest.sourceId = comic.sourceId
          manifestChanged = true
        }
        if (normalizeChapterPages(finalChapterDir, manifest)) manifestChanged = true
        if (manifestChanged) {
          writeManifest(finalChapterDir, manifest)
          migratedChapters += 1
          migratedPages += manifest.pages.length
        }
      } catch (error) {
        DiagnosticLogger.exception('storage', 'download_layout_chapter_failed', error as Error)
      }
    }
    if (currentComicDir !== targetComicDir) removeEmptyDirectory(currentComicDir)
  }
  try {
    if (indexChanged) saveDownloadDirectoryIndex(rootDir, index)
    DiagnosticLogger.info('storage', 'download_layout_ready',
      'chapters=' + migratedChapters + ' pages=' + migratedPages)
  } catch (error) {
    DiagnosticLogger.exception('storage', 'download_layout_index_failed', error as Error)
  }
}
