import { fileIo as fs } from '@kit.CoreFileKit'

export const DOWNLOAD_INDEX_FILE_NAME: string = '.koma-download-index.v1.json'
export const DOWNLOAD_METADATA_DIR_NAME: string = '.koma'
export const DOWNLOAD_MANIFEST_FILE_NAME: string = 'manifest.v1.json'
export const DOWNLOAD_LEGACY_MANIFEST_FILE_NAME: string = 'manifest.v1.json'

const DOWNLOAD_INDEX_SCHEMA_VERSION: number = 1
const MAX_SEGMENT_LENGTH: number = 80

export interface DownloadComicIndexEntry {
  directory: string
  title: string
  sourceId?: string
  sourceName?: string
  chapters: Record<string, DownloadChapterIndexEntry>
}

export interface DownloadChapterIndexEntry {
  directory: string
  title: string
}

export interface DownloadDirectoryIndexFile {
  schemaVersion: number
  comics: Record<string, DownloadComicIndexEntry>
}

export interface EnsuredDownloadDirectory {
  comicDir: string
  chapterDir: string
  index: DownloadDirectoryIndexFile
}

interface ManifestIdentity {
  comicId: string
  chapterId: string
  comicTitle: string
  chapterTitle: string
  sourceId?: string
  sourceName?: string
}

function normalize(value: string): string {
  return value.replace(/\\/g, '/').trim()
}

function joinPath(parent: string, child: string): string {
  const left = normalize(parent).replace(/\/+$/, '')
  const right = normalize(child).replace(/^\/+/, '').replace(/\/+$/, '')
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
    if (!fs.accessSync(path)) throw new Error('download_directory_unavailable')
  }
}

function writeText(path: string, payload: string): void {
  const temporary = path + '.tmp'
  const file = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
  try {
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    fs.fsyncSync(file.fd)
  } finally {
    fs.closeSync(file)
  }
  if (fs.accessSync(path)) fs.unlinkSync(path)
  fs.renameSync(temporary, path)
}

export function sanitizeDownloadSegment(value: string, fallback: string): string {
  let result = value.trim()
    .replace(/[\/\\:*?"<>|]/g, ' ')
    .replace(/[\u0000-\u001f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/[. ]+$/g, '')
  if (result.length === 0 || result === '.' || result === '..') result = fallback
  if (result.length > MAX_SEGMENT_LENGTH) result = result.substring(0, MAX_SEGMENT_LENGTH).trim()
  return result.length === 0 ? fallback : result
}

export function downloadComicDirectoryName(comicTitle: string, sourceName: string = ''): string {
  const title = sanitizeDownloadSegment(comicTitle, '作品')
  const source = sanitizeDownloadSegment(sourceName, '')
  if (source.length === 0) return title
  const boundedSource = source.substring(0, 32).trim()
  const suffix = ' [' + boundedSource + ']'
  const titleBudget = Math.max(1, MAX_SEGMENT_LENGTH - suffix.length)
  const boundedTitle = title.substring(0, titleBudget).trimEnd()
  return sanitizeDownloadSegment((boundedTitle.length > 0 ? boundedTitle : '作品') + suffix, '作品')
}

export function uniqueDownloadDirectory(parent: string, requested: string): string {
  let candidate = requested
  let suffix = 2
  while (isDirectory(joinPath(parent, candidate)) ||
    fs.accessSync(joinPath(parent, candidate))) {
    candidate = requested + ' (' + suffix + ')'
    suffix += 1
  }
  return candidate
}

export function downloadPageFileName(pageIndex: number, extension: string): string {
  const normalizedExtension = extension.trim().replace(/^\./, '').toLowerCase() || 'jpg'
  return String(Math.max(0, Math.floor(pageIndex)) + 1).padStart(3, '0') + '.' + normalizedExtension
}

export function downloadIndexPath(rootDir: string): string {
  return joinPath(rootDir, DOWNLOAD_INDEX_FILE_NAME)
}

export function downloadManifestPath(chapterDir: string): string {
  return joinPath(joinPath(chapterDir, DOWNLOAD_METADATA_DIR_NAME), DOWNLOAD_MANIFEST_FILE_NAME)
}

export function legacyDownloadManifestPath(chapterDir: string): string {
  return joinPath(chapterDir, DOWNLOAD_LEGACY_MANIFEST_FILE_NAME)
}

export function emptyDownloadDirectoryIndex(): DownloadDirectoryIndexFile {
  return { schemaVersion: DOWNLOAD_INDEX_SCHEMA_VERSION, comics: {} }
}

function normalizeComicEntry(value: DownloadComicIndexEntry | undefined): DownloadComicIndexEntry | undefined {
  if (value === undefined || typeof value.directory !== 'string' || value.directory.length === 0) return undefined
  const chapters: Record<string, DownloadChapterIndexEntry> = {}
  const source = value.chapters ?? {}
  Object.keys(source).forEach((chapterId: string) => {
    const chapter = source[chapterId]
    if (chapter !== undefined && typeof chapter.directory === 'string' && chapter.directory.length > 0) {
      chapters[chapterId] = {
        directory: chapter.directory,
        title: typeof chapter.title === 'string' ? chapter.title : '',
      }
    }
  })
  return {
    directory: value.directory,
    title: typeof value.title === 'string' ? value.title : '',
    sourceId: typeof value.sourceId === 'string' ? value.sourceId : undefined,
    sourceName: typeof value.sourceName === 'string' ? value.sourceName : undefined,
    chapters,
  }
}

function normalizeIndex(value: DownloadDirectoryIndexFile | undefined): DownloadDirectoryIndexFile {
  const result = emptyDownloadDirectoryIndex()
  if (value === undefined || value.schemaVersion !== DOWNLOAD_INDEX_SCHEMA_VERSION || value.comics === undefined) {
    return result
  }
  Object.keys(value.comics).forEach((comicId: string) => {
    const comic = normalizeComicEntry(value.comics[comicId])
    if (comic !== undefined) result.comics[comicId] = comic
  })
  return result
}

export function loadDownloadDirectoryIndex(rootDir: string): DownloadDirectoryIndexFile | undefined {
  const path = downloadIndexPath(rootDir)
  if (!fs.accessSync(path)) return undefined
  try {
    return normalizeIndex(JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as DownloadDirectoryIndexFile)
  } catch (_error) {
    return undefined
  }
}

export function saveDownloadDirectoryIndex(rootDir: string, index: DownloadDirectoryIndexFile): void {
  ensureDirectory(rootDir)
  writeText(downloadIndexPath(rootDir), JSON.stringify(index))
}

function readManifestIdentity(path: string): ManifestIdentity | undefined {
  try {
    const parsed = JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as Record<string, Object>
    const comicId = parsed.comicId
    const chapterId = parsed.chapterId
    if (typeof comicId !== 'string' || comicId.length === 0 ||
      typeof chapterId !== 'string' || chapterId.length === 0) return undefined
    const comicTitle = parsed.comicTitle
    const chapterTitle = parsed.chapterTitle
    const sourceId = parsed.sourceId
    const sourceName = parsed.sourceName
    return {
      comicId,
      chapterId,
      comicTitle: typeof comicTitle === 'string' ? comicTitle : '',
      chapterTitle: typeof chapterTitle === 'string' ? chapterTitle : '',
      sourceId: typeof sourceId === 'string' ? sourceId : undefined,
      sourceName: typeof sourceName === 'string' ? sourceName : undefined,
    }
  } catch (_error) {
    return undefined
  }
}

/** Build a path index from the manifests already on disk. */
export function scanDownloadDirectoryIndex(rootDir: string): DownloadDirectoryIndexFile {
  const index = emptyDownloadDirectoryIndex()
  if (!isDirectory(rootDir)) return index
  let comics: string[] = []
  try { comics = fs.listFileSync(rootDir) } catch (_error) { return index }
  for (const comicName of comics) {
    if (comicName.startsWith('.') || comicName === 'Koma-Backups') continue
    const comicDir = joinPath(rootDir, comicName)
    if (!isDirectory(comicDir)) continue
    let chapters: string[] = []
    try { chapters = fs.listFileSync(comicDir) } catch (_error) { continue }
    for (const chapterName of chapters) {
      if (chapterName.startsWith('.')) continue
      const chapterDir = joinPath(comicDir, chapterName)
      if (!isDirectory(chapterDir)) continue
      const manifest = readManifestIdentity(downloadManifestPath(chapterDir)) ??
        readManifestIdentity(legacyDownloadManifestPath(chapterDir))
      if (manifest === undefined) continue
      const comic = index.comics[manifest.comicId] ?? {
        directory: comicName, title: manifest.comicTitle,
        sourceId: manifest.sourceId, sourceName: manifest.sourceName,
        chapters: {},
      }
      comic.title = comic.title.length > 0 ? comic.title : manifest.comicTitle
      if ((comic.sourceId ?? '').length === 0 && (manifest.sourceId ?? '').length > 0) comic.sourceId = manifest.sourceId
      if ((comic.sourceName ?? '').length === 0 && (manifest.sourceName ?? '').length > 0) comic.sourceName = manifest.sourceName
      comic.chapters[manifest.chapterId] = {
        directory: chapterName,
        title: manifest.chapterTitle,
      }
      index.comics[manifest.comicId] = comic
    }
  }
  saveDownloadDirectoryIndex(rootDir, index)
  return index
}

function rootNeedsDirectoryScan(rootDir: string, index: DownloadDirectoryIndexFile): boolean {
  if (!isDirectory(rootDir)) return false
  let entries: string[] = []
  try {
    entries = fs.listFileSync(rootDir)
  } catch (_error) {
    return false
  }
  const indexedDirectories = new Set<string>()
  Object.keys(index.comics).forEach((comicId: string) => {
    const directory = index.comics[comicId].directory
    if (directory.length > 0) indexedDirectories.add(directory)
  })
  return entries.some((name: string): boolean => {
    return !name.startsWith('.') && name !== 'Koma-Backups' &&
      isDirectory(joinPath(rootDir, name)) && !indexedDirectories.has(name)
  })
}

export function loadOrScanDownloadDirectoryIndex(rootDir: string): DownloadDirectoryIndexFile {
  const loaded = loadDownloadDirectoryIndex(rootDir)
  if (loaded === undefined) return scanDownloadDirectoryIndex(rootDir)
  if (!rootNeedsDirectoryScan(rootDir, loaded)) return loaded
  const scanned = scanDownloadDirectoryIndex(rootDir)
  const merged = emptyDownloadDirectoryIndex()
  Object.keys(loaded.comics).forEach((comicId: string) => {
    const comic = loaded.comics[comicId]
    const comicDir = joinPath(rootDir, comic.directory)
    if (!isDirectory(comicDir)) return
    const chapters: Record<string, DownloadChapterIndexEntry> = {}
    Object.keys(comic.chapters).forEach((chapterId: string) => {
      const chapter = comic.chapters[chapterId]
      if (isDirectory(joinPath(comicDir, chapter.directory))) chapters[chapterId] = chapter
    })
    merged.comics[comicId] = {
      directory: comic.directory,
      title: comic.title,
      sourceId: comic.sourceId,
      sourceName: comic.sourceName,
      chapters,
    }
  })
  Object.keys(scanned.comics).forEach((comicId: string) => {
    const diskComic = scanned.comics[comicId]
    const existing = merged.comics[comicId]
    if (existing === undefined) {
      merged.comics[comicId] = diskComic
      return
    }
    if (existing.title.length === 0 && diskComic.title.length > 0) existing.title = diskComic.title
    if ((existing.sourceId ?? '').length === 0 && (diskComic.sourceId ?? '').length > 0) {
      existing.sourceId = diskComic.sourceId
    }
    if ((existing.sourceName ?? '').length === 0 && (diskComic.sourceName ?? '').length > 0) {
      existing.sourceName = diskComic.sourceName
    }
    const comicDir = joinPath(rootDir, existing.directory)
    Object.keys(diskComic.chapters).forEach((chapterId: string) => {
      const diskChapter = diskComic.chapters[chapterId]
      if (existing.chapters[chapterId] === undefined && isDirectory(joinPath(comicDir, diskChapter.directory))) {
        existing.chapters[chapterId] = diskChapter
      }
    })
  })
  saveDownloadDirectoryIndex(rootDir, merged)
  return merged
}

function allocateComicDirectory(rootDir: string, index: DownloadDirectoryIndexFile,
  comicId: string, comicTitle: string, sourceId: string, sourceName: string): string {
  const existing = index.comics[comicId]
  if (existing !== undefined && isDirectory(joinPath(rootDir, existing.directory))) {
    if (existing.title.length === 0 && comicTitle.length > 0) existing.title = comicTitle
    if ((existing.sourceId ?? '').length === 0 && sourceId.length > 0) existing.sourceId = sourceId
    if ((existing.sourceName ?? '').length === 0 && sourceName.length > 0) existing.sourceName = sourceName
    return existing.directory
  }
  const requested = downloadComicDirectoryName(comicTitle, sourceName)
  const directory = uniqueDownloadDirectory(rootDir, requested)
  index.comics[comicId] = {
    directory,
    title: comicTitle,
    sourceId: sourceId.length > 0 ? sourceId : undefined,
    sourceName: sourceName.length > 0 ? sourceName : undefined,
    chapters: existing?.chapters ?? {},
  }
  return directory
}

function allocateChapterDirectory(comicDir: string, index: DownloadDirectoryIndexFile,
  comicId: string, chapterId: string, chapterTitle: string): string {
  const comic = index.comics[comicId]
  if (comic === undefined) return sanitizeDownloadSegment(chapterTitle, '章节')
  const existing = comic.chapters[chapterId]
  if (existing !== undefined && isDirectory(joinPath(comicDir, existing.directory))) return existing.directory
  const requested = sanitizeDownloadSegment(chapterTitle, '章节')
  const directory = uniqueDownloadDirectory(comicDir, requested)
  comic.chapters[chapterId] = { directory, title: chapterTitle }
  return directory
}

export function ensureDownloadDirectory(rootDir: string, index: DownloadDirectoryIndexFile,
  comicId: string, chapterId: string, comicTitle: string, chapterTitle: string,
  sourceId: string = '', sourceName: string = ''): EnsuredDownloadDirectory {
  const comicDirectory = allocateComicDirectory(rootDir, index, comicId, comicTitle, sourceId, sourceName)
  const comicDir = joinPath(rootDir, comicDirectory)
  ensureDirectory(comicDir)
  const chapterDirectory = allocateChapterDirectory(comicDir, index, comicId, chapterId, chapterTitle)
  const chapterDir = joinPath(comicDir, chapterDirectory)
  ensureDirectory(chapterDir)
  return { comicDir, chapterDir, index }
}
