import { zlib } from '@kit.BasicServicesKit'
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'
import { Chapter, Page, ReadingDirection, normalizeSortKey } from '../model/ComicModels'
import { extractNativeComicArchive } from './NativeArchiveExtraction'
import { readOrderedEpubImages } from './EpubArchiveReader'
import { ArchiveImageChapter, archiveImageChapters } from './ArchiveImageChapters'
import { parseLocalLibrarySidecarMetadata } from '../model/LocalLibraryMetadataService'
import {
  ArchiveEntryCandidate,
  ArchiveImportResult,
  buildComicFromArchive,
} from './ArchiveImportService'
import {
  getBaseName,
  isSafeArchiveEntryPath,
  isSupportedArchivePath,
  isSupportedImagePath,
  stripExtension,
  compareNaturalPath,
} from './ImageSortUtils'

export interface ArchiveExtractionCachePaths {
  rootDir: string
  archiveZipPath: string
  extractionDir: string
  manifestPath: string
}

export interface ArchiveExtractionCancelToken {
  isCancelled(): boolean
}

export interface ArchiveExtractionRequest {
  archivePath: string
  sandboxZipPath: string
  extractionDir: string
  comicId?: string
  title?: string
  importedAt?: number
  readingDirection?: ReadingDirection
  cleanOutputDir?: boolean
  cancelToken?: ArchiveExtractionCancelToken
  /** Folder scanning already owns its chapter boundaries. */
  expandNestedArchives?: boolean
}

export interface ArchiveExtractionResult {
  archivePath: string
  sandboxZipPath: string
  extractionDir: string
  entries: ArchiveEntryCandidate[]
  importResult: ArchiveImportResult
}

function normalizeSeparator(value: string): string {
  return value.replace(/\\/g, '/')
}

function trimTrailingSlash(value: string): string {
  let normalized = normalizeSeparator(value).trim()
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function joinSandboxPath(parent: string, child: string): string {
  const left = trimTrailingSlash(parent)
  const right = normalizeSeparator(child).replace(/^\/+/, '').replace(/\/+$/, '')
  return right.length === 0 ? left : `${left}/${right}`
}

function sanitizeCacheSegment(value: string): string {
  const normalized = stripExtension(getBaseName(value)).trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, '-')
  const trimmed = normalized.replace(/^-+|-+$/g, '')
  return trimmed.length === 0 ? 'archive' : trimmed
}

function createStableCacheHash(value: string): string {
  const normalized = normalizeSeparator(value).trim()
  let hash = 2166136261
  for (let index = 0; index < normalized.length; index += 1) {
    hash = (hash ^ normalized.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash.toString(16).padStart(8, '0')
}

function assertNoTraversalPath(path: string, label: string): void {
  const normalized = normalizeSeparator(path)
  if (normalized.indexOf('../') >= 0 || normalized.indexOf('/..') >= 0) {
    throw new Error(`${label} must not contain path traversal: ${path}`)
  }
}

function assertZipSandboxPath(path: string): void {
  assertNoTraversalPath(path, 'sandboxZipPath')
  if (!path.toLocaleLowerCase().endsWith('.zip')) {
    throw new Error(`sandboxZipPath must end with .zip for zlib.decompressFile: ${path}`)
  }
}

function normalizeListedEntryPath(path: string): string {
  return normalizeSeparator(path).replace(/^\/+/, '')
}

function assertNotCancelled(token: ArchiveExtractionCancelToken | undefined): void {
  if (token !== undefined && token.isCancelled()) {
    throw new Error('Archive extraction cancelled')
  }
}

async function removeDirectoryIfPresent(path: string): Promise<void> {
  try {
    await fs.rmdir(path)
  } catch (_err) {
  }
}

async function copyNestedArchive(source: string, destination: string): Promise<void> {
  let input: fs.File | undefined = undefined
  let output: fs.File | undefined = undefined
  try {
    input = await fs.open(source, fs.OpenMode.READ_ONLY)
    output = await fs.open(destination, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    await fs.copyFile(input.fd, output.fd, 0)
  } finally {
    if (input !== undefined) await fs.close(input)
    if (output !== undefined) await fs.close(output)
  }
}

export function createArchiveExtractionCachePaths(cacheDir: string, archivePath: string, cacheKeySeed?: string): ArchiveExtractionCachePaths {
  assertNoTraversalPath(cacheDir, 'cacheDir')
  const readableSegment = sanitizeCacheSegment(archivePath)
  const uniqueSegment = createStableCacheHash(cacheKeySeed ?? archivePath)
  const rootDir = joinSandboxPath(joinSandboxPath(cacheDir, 'import'), `${readableSegment}-${uniqueSegment}`)
  return {
    rootDir,
    archiveZipPath: joinSandboxPath(rootDir, 'archive.zip'),
    extractionDir: joinSandboxPath(rootDir, 'extract'),
    manifestPath: joinSandboxPath(rootDir, 'manifest.json'),
  }
}

export function shouldCopyArchiveAsZip(archivePath: string): boolean {
  if (!isSupportedArchivePath(archivePath)) {
    throw new Error(`Unsupported archive path: ${archivePath}`)
  }
  return !archivePath.toLocaleLowerCase().endsWith('.zip')
}

export function createExtractedPagePath(extractionDir: string, entryPath: string): string {
  const normalizedEntryPath = normalizeListedEntryPath(entryPath)
  if (!isSafeArchiveEntryPath(normalizedEntryPath)) {
    throw new Error(`Unsafe extracted entry path: ${entryPath}`)
  }
  return joinSandboxPath(extractionDir, normalizedEntryPath)
}

export class ArchiveExtractionService {
  async extractArchive(request: ArchiveExtractionRequest): Promise<ArchiveExtractionResult> {
    if (!isSupportedArchivePath(request.archivePath)) {
      throw new Error(`Unsupported archive path: ${request.archivePath}`)
    }
    assertZipSandboxPath(request.sandboxZipPath)
    assertNoTraversalPath(request.extractionDir, 'extractionDir')
    assertNotCancelled(request.cancelToken)

    if (request.cleanOutputDir !== false) {
      await removeDirectoryIfPresent(request.extractionDir)
    }
    await fs.mkdir(request.extractionDir, true)

    assertNotCancelled(request.cancelToken)
    // Preserve the accepted ZIP/CBZ route. New formats decode on native async workers.
    if (/\.(?:zip|cbz)$/i.test(request.archivePath)) {
      await zlib.decompressFile(request.sandboxZipPath, request.extractionDir)
    } else {
      await extractNativeComicArchive(request.sandboxZipPath, request.extractionDir)
    }
    assertNotCancelled(request.cancelToken)

    const entries = await this.listImageEntries(request.extractionDir)
    const nested = request.expandNestedArchives === false || /\.epub$/i.test(request.archivePath) ? [] :
      await this.listNestedArchives(request.extractionDir)
    if (entries.length === 0 && nested.length === 0) {
      throw new Error(`Archive contains no supported image pages: ${request.archivePath}`)
    }
    const importResult = buildComicFromArchive({
      orderedImagePaths: /\.epub$/i.test(request.archivePath) ? await readOrderedEpubImages(request.extractionDir) : undefined,
      archivePath: request.archivePath,
      entries,
      extractionDir: request.extractionDir,
      comicId: request.comicId,
      title: request.title,
      importedAt: request.importedAt,
      readingDirection: request.readingDirection,
    })
    try {
      const metadata = parseLocalLibrarySidecarMetadata(await fs.readText(`${request.extractionDir}/ComicInfo.xml`))
      if (metadata.status === 'ok' && (metadata.metadata?.authors?.length ?? 0) > 0) {
        importResult.comic.author = metadata.metadata?.authors?.join('、')
      }
      if (metadata.status === 'ok') {
        importResult.comic.subtitle = metadata.metadata?.description
        const tags = metadata.metadata?.tags
        if (tags !== undefined && tags.length > 0) importResult.comic.sourceMetadata = { tags: tags.slice() }
      }
    } catch (_error) {
      // Optional metadata is not required to read the archive.
    }

    const imageGroups = request.expandNestedArchives === false || !/\.zip$/i.test(request.archivePath) ? [] :
      archiveImageChapters(entries.map((entry: ArchiveEntryCandidate): string => entry.path))
    if (nested.length > 0 || imageGroups.length > 0) {
      const comic = importResult.comic
      const imagesAreCoverOnly = entries.length === 1 && stripExtension(getBaseName(entries[0].path)).toLowerCase() === 'cover'
      const chapters: Chapter[] = []
      if (imageGroups.length > 0) {
        imageGroups.forEach((group: ArchiveImageChapter): void => {
          const selected = new Set<string>(group.paths)
          const groupResult = buildComicFromArchive({ archivePath: request.archivePath, extractionDir: request.extractionDir,
            comicId: comic.id, title: group.title, importedAt: request.importedAt, readingDirection: request.readingDirection,
            entries: entries.filter((entry: ArchiveEntryCandidate): boolean => selected.has(entry.path)) })
          chapters.push(groupResult.comic.chapters[0])
        })
        const grouped = new Set<string>()
        imageGroups.forEach((group: ArchiveImageChapter): void => group.paths.forEach((path: string): void => { grouped.add(path) }))
        const cover = entries.find((entry: ArchiveEntryCandidate): boolean => !grouped.has(entry.path))
        if (cover !== undefined) {
          comic.coverUri = comic.chapters[0].pages.find((page: Page): boolean => page.sortKey === normalizeSortKey(cover.path))?.uri
        }
      } else if (entries.length > 0 && !imagesAreCoverOnly) {
        chapters.push(...comic.chapters)
      }
      for (let index = 0; index < nested.length; index += 1) {
        assertNotCancelled(request.cancelToken)
        const childPath = nested[index]
        const childRoot = `${request.extractionDir}.chapters/${index}`
        await fs.mkdir(childRoot, true)
        const copyPath = `${childRoot}/archive.zip`
        await copyNestedArchive(createExtractedPagePath(request.extractionDir, childPath), copyPath)
        const child = await this.extractArchive({
          archivePath: `${request.archivePath}#${childPath}`, sandboxZipPath: copyPath,
          extractionDir: `${childRoot}/extract`, title: stripExtension(getBaseName(childPath)),
          importedAt: request.importedAt, readingDirection: request.readingDirection,
          cleanOutputDir: false, cancelToken: request.cancelToken,
        })
        const childAuthor = child.importResult.comic.author
        if (childAuthor !== undefined && childAuthor.length > 0) {
          const existing = comic.author?.split('、') ?? []
          childAuthor.split('、').forEach((author: string): void => {
            if (!existing.includes(author)) existing.push(author)
          })
          comic.author = existing.join('、')
        }
        // Nested chapter archives often repeat the series metadata. Use the
        // first available series description and tags without replacing a parent value.
        if (comic.subtitle === undefined) comic.subtitle = child.importResult.comic.subtitle
        if (comic.sourceMetadata?.tags === undefined && child.importResult.comic.sourceMetadata?.tags !== undefined) {
          if (comic.sourceMetadata === undefined) comic.sourceMetadata = {}
          comic.sourceMetadata.tags = child.importResult.comic.sourceMetadata?.tags?.slice()
        }
        child.importResult.comic.chapters.forEach((chapter: Chapter): void => { chapters.push(chapter) })
      }
      chapters.sort((left: Chapter, right: Chapter): number => compareNaturalPath(left.title, right.title))
      chapters.forEach((chapter: Chapter, chapterIndex: number): void => {
        const chapterId = `${comic.id}-chapter-${chapterIndex + 1}`
        chapter.id = chapterId
        chapter.comicId = comic.id
        chapter.index = chapterIndex
        chapter.sortKey = normalizeSortKey(chapter.title)
        chapter.pages.forEach((page: Page, pageIndex: number): void => {
          page.id = `${chapterId}-page-${pageIndex + 1}`
          page.comicId = comic.id
          page.chapterId = chapterId
        })
      })
      comic.chapters = chapters
      comic.chapterCount = chapters.length
      comic.pageCount = chapters.reduce((sum: number, chapter: Chapter): number => sum + chapter.pageCount, 0)
      if (comic.coverUri === undefined) comic.coverUri = chapters[0]?.pages[0]?.uri
    }

    return {
      archivePath: request.archivePath,
      sandboxZipPath: request.sandboxZipPath,
      extractionDir: request.extractionDir,
      entries,
      importResult,
    }
  }

  async listNestedArchives(extractionDir: string): Promise<string[]> {
    const listed = await fs.listFile(extractionDir, { recursion: true, listNum: 0 })
    const candidates = listed.map(normalizeListedEntryPath)
      .filter((path: string): boolean => isSafeArchiveEntryPath(path) && isSupportedArchivePath(path))
      .sort(compareNaturalPath)
    const files: string[] = []
    for (const candidate of candidates) {
      if ((await fs.stat(createExtractedPagePath(extractionDir, candidate))).isFile()) files.push(candidate)
    }
    return files
  }

  async listImageEntries(extractionDir: string): Promise<ArchiveEntryCandidate[]> {
    const listFileOptions: ListFileOptions = {
      recursion: true,
      listNum: 0,
    }
    const listedPaths = await fs.listFile(extractionDir, listFileOptions)
    const candidates: ArchiveEntryCandidate[] = []

    for (const listedPath of listedPaths) {
      const entryPath = normalizeListedEntryPath(listedPath)
      if (!isSafeArchiveEntryPath(entryPath) || !isSupportedImagePath(entryPath)) {
        continue
      }

      const stat = await fs.stat(createExtractedPagePath(extractionDir, entryPath))
      candidates.push({
        path: entryPath,
        byteSize: stat.size,
      })
    }

    return candidates
  }

  async cleanExtraction(paths: ArchiveExtractionCachePaths): Promise<void> {
    await removeDirectoryIfPresent(paths.rootDir)
  }
}

export function extractArchive(request: ArchiveExtractionRequest): Promise<ArchiveExtractionResult> {
  return new ArchiveExtractionService().extractArchive(request)
}
