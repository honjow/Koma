import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from '../model/ComicModels'
import {
  compareNaturalPath,
  getBaseName,
  isSupportedImagePath,
  sortImageEntryPaths,
  stripExtension,
} from './ImageSortUtils'

export interface LocalImageImportCandidate {
  sourceUri: string
  sandboxPath: string
  fileName?: string
  byteSize?: number
  width?: number
  height?: number
  selectionIndex?: number
}

export interface LocalImageImportRequest {
  sourcePath: string
  images: LocalImageImportCandidate[]
  comicId?: string
  title?: string
  importedAt?: number
  readingDirection?: ReadingDirection
}

export interface LocalImageImportResult {
  comic: Comic
  rejectedEntryCount: number
  sourceEntryCount: number
}

function sanitizeIdPart(value: string): string {
  const normalized = value.trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, '-')
  const trimmed = normalized.replace(/^-+|-+$/g, '')
  return trimmed.length === 0 ? 'images' : trimmed
}

function createLocalImageComicId(sourcePath: string): string {
  return `local-folder-${sanitizeIdPart(sourcePath)}`
}

function stripFileUriScheme(value: string): string {
  return value.startsWith('file://') ? value.slice('file://'.length) : value
}

function encodeFileUriPath(path: string): string {
  return path.split('/').map((segment: string) => encodeURIComponent(segment)).join('/')
}

function createLocalImagePageUri(sandboxPath: string): string {
  return `file://${encodeFileUriPath(stripFileUriScheme(sandboxPath).replace(/\\/g, '/'))}`
}

function resolveCandidateFileName(candidate: LocalImageImportCandidate): string {
  const explicitName = candidate.fileName === undefined ? '' : candidate.fileName.trim()
  return explicitName.length > 0 ? explicitName : getBaseName(candidate.sandboxPath)
}

function toPage(candidate: LocalImageImportCandidate, comicId: string, chapterId: string, index: number): Page {
  const fileName = resolveCandidateFileName(candidate)
  return {
    id: `${chapterId}-page-${index + 1}`,
    comicId,
    chapterId,
    index,
    fileName,
    uri: createLocalImagePageUri(candidate.sandboxPath),
    sortKey: normalizeSortKey(fileName),
    width: candidate.width,
    height: candidate.height,
    byteSize: candidate.byteSize,
  }
}

interface OrderedLocalImageImportCandidate {
  candidate: LocalImageImportCandidate
  fileName: string
  originalIndex: number
}

function orderLocalImageCandidates(images: LocalImageImportCandidate[]): OrderedLocalImageImportCandidate[] {
  const supportedImages: OrderedLocalImageImportCandidate[] = []
  images.forEach((candidate: LocalImageImportCandidate, index: number) => {
    const fileName = resolveCandidateFileName(candidate)
    if (isSupportedImagePath(fileName)) {
      supportedImages.push({
        candidate,
        fileName,
        originalIndex: index,
      })
    }
  })

  const hasPickerOrder = supportedImages.some((item: OrderedLocalImageImportCandidate) => {
    return item.candidate.selectionIndex !== undefined
  })
  if (hasPickerOrder) {
    return supportedImages.sort((left: OrderedLocalImageImportCandidate, right: OrderedLocalImageImportCandidate) => {
      const leftSelectionIndex = left.candidate.selectionIndex === undefined ? Number.MAX_SAFE_INTEGER : left.candidate.selectionIndex
      const rightSelectionIndex = right.candidate.selectionIndex === undefined ? Number.MAX_SAFE_INTEGER : right.candidate.selectionIndex
      if (leftSelectionIndex !== rightSelectionIndex) {
        return leftSelectionIndex - rightSelectionIndex
      }
      const nameCompare = compareNaturalPath(left.fileName, right.fileName)
      if (nameCompare !== 0) {
        return nameCompare
      }
      return left.originalIndex - right.originalIndex
    })
  }

  const sortedImageNames = sortImageEntryPaths(supportedImages.map((item: OrderedLocalImageImportCandidate) => item.fileName))
  const sortOrderByName = new Map<string, number>()
  sortedImageNames.forEach((fileName: string, index: number) => {
    if (!sortOrderByName.has(fileName)) {
      sortOrderByName.set(fileName, index)
    }
  })
  return supportedImages.sort((left: OrderedLocalImageImportCandidate, right: OrderedLocalImageImportCandidate) => {
    const leftSortOrder = sortOrderByName.get(left.fileName) ?? Number.MAX_SAFE_INTEGER
    const rightSortOrder = sortOrderByName.get(right.fileName) ?? Number.MAX_SAFE_INTEGER
    if (leftSortOrder !== rightSortOrder) {
      return leftSortOrder - rightSortOrder
    }
    const nameCompare = compareNaturalPath(left.fileName, right.fileName)
    if (nameCompare !== 0) {
      return nameCompare
    }
    return left.originalIndex - right.originalIndex
  })
}

export class LocalImageImportService {
  buildComicFromLocalImages(request: LocalImageImportRequest): LocalImageImportResult {
    const orderedImages = orderLocalImageCandidates(request.images)
    if (orderedImages.length === 0) {
      throw new Error(`Local image selection contains no supported image pages: ${request.sourcePath}`)
    }

    const now = request.importedAt === undefined ? Date.now() : request.importedAt
    const title = request.title === undefined ? stripExtension(getBaseName(request.sourcePath)) : request.title
    const comicId = request.comicId === undefined ? createLocalImageComicId(request.sourcePath) : request.comicId
    const chapterId = `${comicId}-chapter-1`
    const pages: Page[] = orderedImages.map((item: OrderedLocalImageImportCandidate, index: number) => {
      return toPage(item.candidate, comicId, chapterId, index)
    })

    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title,
      index: 0,
      sourcePath: request.sourcePath,
      sortKey: normalizeSortKey(title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }

    const comic: Comic = {
      id: comicId,
      title,
      sourceKind: ComicSourceKind.LOCAL_FOLDER,
      sourcePath: request.sourcePath,
      coverUri: pages[0].uri,
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
      rejectedEntryCount: request.images.length - pages.length,
      sourceEntryCount: request.images.length,
    }
  }
}

export function buildComicFromLocalImages(request: LocalImageImportRequest): LocalImageImportResult {
  return new LocalImageImportService().buildComicFromLocalImages(request)
}
