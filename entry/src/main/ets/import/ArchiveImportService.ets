import { util } from '@kit.ArkTS'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from '../model/ComicModels'
import {
  getBaseName,
  isSupportedArchivePath,
  isSafeArchiveEntryPath,
  sortImageEntryPaths,
  stripExtension,
} from './ImageSortUtils'

export interface ArchiveEntryCandidate {
  path: string
  byteSize?: number
  width?: number
  height?: number
}

export interface ArchiveImportRequest {
  orderedImagePaths?: string[]
  archivePath: string
  entries: ArchiveEntryCandidate[]
  comicId?: string
  title?: string
  importedAt?: number
  readingDirection?: ReadingDirection
  extractionDir?: string
}

export interface ArchiveImportResult {
  comic: Comic
  rejectedEntryCount: number
  sourceEntryCount: number
}

function createArchiveId(_archivePath: string): string {
  return `local-archive-${util.generateRandomUUID()}`
}

function defaultArchiveTitle(archivePath: string): string {
  const title = stripExtension(archivePath)
  if (!archivePath.startsWith('file://')) return title
  try {
    return decodeURIComponent(title)
  } catch (_error) {
    return title
  }
}

function createArchiveEntryUri(archivePath: string, entryPath: string): string {
  return `${archivePath}#${entryPath}`
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

function stripFileUriScheme(value: string): string {
  return value.startsWith('file://') ? value.slice('file://'.length) : value
}

function encodeFileUriPath(path: string): string {
  return path.split('/').map((segment: string) => encodeURIComponent(segment)).join('/')
}

function createExtractedPageUri(extractionDir: string, entryPath: string): string {
  const normalizedEntryPath = normalizeSeparator(entryPath).replace(/^\/+/, '')
  if (!isSafeArchiveEntryPath(normalizedEntryPath)) {
    throw new Error(`Unsafe extracted entry path: ${entryPath}`)
  }
  const extractedPath = `${trimTrailingSlash(stripFileUriScheme(extractionDir))}/${normalizedEntryPath}`
  return `file://${encodeFileUriPath(extractedPath)}`
}

function createPageUri(archivePath: string, entryPath: string, extractionDir: string | undefined): string {
  if (extractionDir !== undefined && extractionDir.trim().length > 0) {
    return createExtractedPageUri(extractionDir, entryPath)
  }
  return createArchiveEntryUri(archivePath, entryPath)
}

function toPage(candidate: ArchiveEntryCandidate, comicId: string, chapterId: string, archivePath: string, extractionDir: string | undefined, index: number): Page {
  const fileName = getBaseName(candidate.path)
  return {
    id: `${chapterId}-page-${index + 1}`,
    comicId,
    chapterId,
    index,
    fileName,
    uri: createPageUri(archivePath, candidate.path, extractionDir),
    sortKey: normalizeSortKey(candidate.path),
    width: candidate.width,
    height: candidate.height,
    byteSize: candidate.byteSize,
  }
}

export class ArchiveImportService {
  buildComicFromArchive(request: ArchiveImportRequest): ArchiveImportResult {
    if (!isSupportedArchivePath(request.archivePath)) {
      throw new Error(`Unsupported archive path: ${request.archivePath}`)
    }

    const sortedImagePaths = request.orderedImagePaths ?? sortImageEntryPaths(request.entries.map((entry: ArchiveEntryCandidate) => entry.path))
    const entryByPath = new Map<string, ArchiveEntryCandidate>()
    request.entries.forEach((entry: ArchiveEntryCandidate) => {
      entryByPath.set(entry.path, entry)
    })
    if (sortedImagePaths.some((path: string): boolean => !isSafeArchiveEntryPath(path) || !entryByPath.has(path))) {
      throw new Error('Archive reading order references a missing image')
    }

    const now = request.importedAt === undefined ? Date.now() : request.importedAt
    const comicId = request.comicId === undefined ? createArchiveId(request.archivePath) : request.comicId
    const title = request.title === undefined ? defaultArchiveTitle(request.archivePath) : request.title
    const chapterId = `${comicId}-chapter-1`
    const pages: Page[] = sortedImagePaths.map((path: string, index: number) => {
      const candidate = entryByPath.get(path) as ArchiveEntryCandidate
      return toPage(candidate, comicId, chapterId, request.archivePath, request.extractionDir, index)
    })

    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title,
      index: 0,
      sourcePath: request.archivePath,
      sortKey: normalizeSortKey(title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }

    const comic: Comic = {
      id: comicId,
      title,
      sourceKind: ComicSourceKind.LOCAL_ARCHIVE,
      sourcePath: request.archivePath,
      coverUri: pages.length === 0 ? undefined : pages[0].uri,
      sortTitle: normalizeSortKey(title),
      preferredDirection: request.readingDirection === undefined ? ReadingDirection.RIGHT_TO_LEFT : request.readingDirection,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }

    return {
      comic,
      rejectedEntryCount: request.entries.length - new Set(sortedImagePaths).size,
      sourceEntryCount: request.entries.length,
    }
  }
}

export function buildComicFromArchive(request: ArchiveImportRequest): ArchiveImportResult {
  return new ArchiveImportService().buildComicFromArchive(request)
}
