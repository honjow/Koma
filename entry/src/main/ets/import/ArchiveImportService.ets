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
  archivePath: string
  entries: ArchiveEntryCandidate[]
  comicId?: string
  title?: string
  importedAt?: number
  readingDirection?: ReadingDirection
}

export interface ArchiveImportResult {
  comic: Comic
  rejectedEntryCount: number
  sourceEntryCount: number
}

function sanitizeIdPart(value: string): string {
  const normalized = value.trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, '-')
  const trimmed = normalized.replace(/^-+|-+$/g, '')
  return trimmed.length === 0 ? 'archive' : trimmed
}

function createArchiveId(archivePath: string): string {
  return `local-archive-${sanitizeIdPart(stripExtension(archivePath))}`
}

function createArchiveEntryUri(archivePath: string, entryPath: string): string {
  return `${archivePath}#${entryPath}`
}

function toPage(candidate: ArchiveEntryCandidate, comicId: string, chapterId: string, archivePath: string, index: number): Page {
  const fileName = getBaseName(candidate.path)
  return {
    id: `${chapterId}-page-${index + 1}`,
    comicId,
    chapterId,
    index,
    fileName,
    uri: createArchiveEntryUri(archivePath, candidate.path),
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

    const sortedImagePaths = sortImageEntryPaths(request.entries.map((entry: ArchiveEntryCandidate) => entry.path))
    const entryByPath = new Map<string, ArchiveEntryCandidate>()
    request.entries.forEach((entry: ArchiveEntryCandidate) => {
      entryByPath.set(entry.path, entry)
    })

    const now = request.importedAt === undefined ? Date.now() : request.importedAt
    const comicId = request.comicId === undefined ? createArchiveId(request.archivePath) : request.comicId
    const title = request.title === undefined ? stripExtension(request.archivePath) : request.title
    const chapterId = `${comicId}-chapter-1`
    const pages: Page[] = sortedImagePaths.map((path: string, index: number) => {
      const candidate = entryByPath.get(path) as ArchiveEntryCandidate
      return toPage(candidate, comicId, chapterId, request.archivePath, index)
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
      rejectedEntryCount: request.entries.length - pages.length,
      sourceEntryCount: request.entries.length,
    }
  }
}

export function buildComicFromArchive(request: ArchiveImportRequest): ArchiveImportResult {
  return new ArchiveImportService().buildComicFromArchive(request)
}
