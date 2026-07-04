import {
  compareNaturalPath,
  getBaseName,
  isSupportedArchivePath,
  isSupportedImagePath,
  normalizeSortKey,
  stripExtension,
} from '../import/ImageSortUtils'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
} from './ComicModels'
import {
  LocalLibraryMetadataSeriesInput,
  LocalLibrarySidecarMetadata,
  createDerivedLocalLibraryMetadata,
  parseLocalLibrarySidecarMetadata,
  resolveLocalLibraryMetadata,
  resolveLocalLibrarySeriesCoverReference,
} from './LocalLibraryMetadataService'

export const LOCAL_LIBRARY_FOLDER_CONTRACT_VERSION = 1
export const LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS = 'BEST_EFFORT_DOCUMENT_PICKER'
export const LOCAL_LIBRARY_FOLDER_ID_PREFIX = 'local-library-folder'

export type LocalLibraryFolderEntryKind = 'file' | 'directory'
export type LocalLibraryFolderChapterKind = 'archive' | 'image_folder'
export type LocalLibraryFolderAvailabilityStatus = 'available' | 'missing'

export interface LocalLibraryFolderRootContract {
  version: number
  rootName: string
  rootId: string
  directoryConvention: string
  runtimeFolderPicker: string
}

export interface LocalLibraryFolderEntry {
  relativePath: string
  kind?: LocalLibraryFolderEntryKind
  byteSize?: number
  textContent?: string
  exists?: boolean
}

export interface LocalLibraryFolderPage {
  id: string
  relativePath: string
  fileName: string
  index: number
  sortKey: string
}

export interface LocalLibraryFolderChapter {
  id: string
  seriesId: string
  title: string
  kind: LocalLibraryFolderChapterKind
  relativePath: string
  index: number
  pageCount: number
  pages: LocalLibraryFolderPage[]
  sourceArchivePath?: string
  sortKey: string
}

export interface LocalLibraryFolderSeries {
  id: string
  title: string
  relativePath: string
  sidecarMetadata?: LocalLibrarySidecarMetadata
  chapters: LocalLibraryFolderChapter[]
  chapterCount: number
  pageCount: number
  sortKey: string
}

export interface LocalLibraryFolderRejectedEntry {
  relativePath: string
  reason: string
}

export interface LocalLibraryFolderScanResult {
  contract: LocalLibraryFolderRootContract
  series: LocalLibraryFolderSeries[]
  rejectedEntries: LocalLibraryFolderRejectedEntry[]
  sourceEntryCount: number
}

export interface LocalLibraryFolderKnownSeries {
  id: string
}

export interface LocalLibraryFolderAvailability {
  id: string
  status: LocalLibraryFolderAvailabilityStatus
}

export interface LocalLibraryFolderComicBuildOptions {
  rootUri: string
  rootId?: string
  now?: number
}

interface NormalizedLocalLibraryEntry {
  relativePath: string
  kind: LocalLibraryFolderEntryKind
  byteSize?: number
  textContent?: string
}

interface ImageFolderGroup {
  folderPath: string
  images: NormalizedLocalLibraryEntry[]
}

interface ChapterCandidate {
  kind: LocalLibraryFolderChapterKind
  seriesPath: string
  chapterPath: string
  archivePath?: string
  pages: NormalizedLocalLibraryEntry[]
}

function stableHash(value: string): string {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash ^ value.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash.toString(16).padStart(8, '0')
}

function idFor(kind: string, relativePath: string): string {
  return `${LOCAL_LIBRARY_FOLDER_ID_PREFIX}-${kind}-${stableHash(relativePath)}`
}

function normalizeSeparator(value: string): string {
  return value.replace(/\\/g, '/').trim()
}

function trimSlashes(value: string): string {
  return normalizeSeparator(value).replace(/^\/+/, '').replace(/\/+$/, '')
}

function trimTrailingSlashes(value: string): string {
  let trimmed = value.trim()
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1)
  }
  return trimmed
}

function dirname(path: string): string {
  const normalized = trimSlashes(path)
  const slashIndex = normalized.lastIndexOf('/')
  return slashIndex < 0 ? '' : normalized.substring(0, slashIndex)
}

function isHiddenPath(path: string): boolean {
  return path.split('/').some((segment: string): boolean => segment.startsWith('.'))
}

function hasUnsafeControlCharacter(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    if (code < 32 || code === 127) {
      return true
    }
  }
  return false
}

export function normalizeLocalLibraryRelativePath(path: string): string {
  const normalized = normalizeSeparator(path)
  if (
    normalized.length === 0 ||
    normalized.startsWith('/') ||
    normalized.includes('://') ||
    /^[A-Za-z]:/.test(normalized) ||
    hasUnsafeControlCharacter(normalized)
  ) {
    throw new Error(`Unsafe local library path: ${path}`)
  }

  const parts = normalized.split('/')
  const safeParts: string[] = []
  for (const part of parts) {
    const trimmed = part.trim()
    if (trimmed.length === 0 || trimmed === '.' || trimmed === '..') {
      throw new Error(`Unsafe local library path segment: ${path}`)
    }
    if (trimmed.indexOf(':') >= 0) {
      throw new Error(`Unsafe local library path segment: ${path}`)
    }
    safeParts.push(trimmed)
  }
  return safeParts.join('/')
}

export function createLocalLibraryFolderRootContract(rootName: string = 'Local Library'): LocalLibraryFolderRootContract {
  const safeRootName = rootName.trim().length === 0 ? 'Local Library' : rootName.trim()
  return {
    version: LOCAL_LIBRARY_FOLDER_CONTRACT_VERSION,
    rootName: safeRootName,
    rootId: idFor('root', normalizeSortKey(safeRootName)),
    directoryConvention: 'root/{series path}/{chapter folder pages | chapter.cbz | chapter.zip}; image-only series folders are one chapter',
    runtimeFolderPicker: LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS,
  }
}

function normalizeEntries(entries: LocalLibraryFolderEntry[], rejectedEntries: LocalLibraryFolderRejectedEntry[]): NormalizedLocalLibraryEntry[] {
  const seenPaths = new Set<string>()
  const normalizedEntries: NormalizedLocalLibraryEntry[] = []
  entries.forEach((entry: LocalLibraryFolderEntry) => {
    if (entry.exists === false) {
      return
    }
    try {
      const relativePath = normalizeLocalLibraryRelativePath(entry.relativePath)
      if (isHiddenPath(relativePath)) {
        rejectedEntries.push({ relativePath, reason: 'hidden' })
        return
      }
      if (seenPaths.has(relativePath)) {
        return
      }
      seenPaths.add(relativePath)
      normalizedEntries.push({
        relativePath,
        kind: entry.kind ?? 'file',
        byteSize: entry.byteSize,
        textContent: entry.textContent,
      })
    } catch (_err) {
      rejectedEntries.push({ relativePath: entry.relativePath, reason: 'unsafe_path' })
    }
  })
  return normalizedEntries
}

function folderName(path: string): string {
  const baseName = getBaseName(path)
  return baseName.length === 0 ? path : baseName
}

function isExplicitImageChapterFolderName(path: string): boolean {
  return /^(chapter|chap|ch|episode|ep|volume|vol|book)\b/i.test(folderName(path))
}

function isLocalLibrarySidecarMetadataPath(path: string): boolean {
  const name = getBaseName(path).toLocaleLowerCase()
  return name === 'metadata.json' ||
    name === 'series.json' ||
    name === 'comicinfo.json' ||
    name === 'koma-metadata.json'
}

function inferImageFolderChapter(folder: ImageFolderGroup, childChapterCounts: Map<string, number>): ChapterCandidate {
  const parentPath = dirname(folder.folderPath)
  const siblingChapterCount = parentPath.length === 0 ? 0 : childChapterCounts.get(parentPath) ?? 0
  if (parentPath.length > 0 && (siblingChapterCount > 1 || isExplicitImageChapterFolderName(folder.folderPath))) {
    return {
      kind: 'image_folder',
      seriesPath: parentPath,
      chapterPath: folder.folderPath,
      pages: folder.images,
    }
  }
  return {
    kind: 'image_folder',
    seriesPath: folder.folderPath,
    chapterPath: folder.folderPath,
    pages: folder.images,
  }
}

function createPage(entry: NormalizedLocalLibraryEntry, chapterId: string, index: number): LocalLibraryFolderPage {
  return {
    id: `${chapterId}-page-${index + 1}`,
    relativePath: entry.relativePath,
    fileName: getBaseName(entry.relativePath),
    index,
    sortKey: normalizeSortKey(entry.relativePath),
  }
}

function encodeRelativeUriPath(relativePath: string): string {
  return relativePath.split('/').map((segment: string): string => encodeURIComponent(segment)).join('/')
}

export function localLibraryFolderUri(rootUri: string, relativePath: string): string {
  const safeRelativePath = normalizeLocalLibraryRelativePath(relativePath)
  const safeRootUri = trimTrailingSlashes(rootUri)
  if (safeRootUri.length === 0) {
    throw new Error('Local library root URI is required')
  }
  return `${safeRootUri}/${encodeRelativeUriPath(safeRelativePath)}`
}

export function buildComicFromLocalLibraryFolderSeries(
  series: LocalLibraryFolderSeries,
  options: LocalLibraryFolderComicBuildOptions,
): Comic {
  const now = options.now ?? Date.now()
  const rootId = options.rootId ?? LOCAL_LIBRARY_FOLDER_ID_PREFIX
  const comicId = series.id
  const sourcePath = localLibraryFolderUri(options.rootUri, series.relativePath)
  const chapters = series.chapters.map((folderChapter: LocalLibraryFolderChapter): Chapter => {
    const pages = folderChapter.pages.map((folderPage: LocalLibraryFolderPage, pageIndex: number): Page => {
      return {
        id: folderPage.id,
        comicId,
        chapterId: folderChapter.id,
        index: pageIndex,
        fileName: folderPage.fileName,
        uri: localLibraryFolderUri(options.rootUri, folderPage.relativePath),
        sortKey: folderPage.sortKey,
      }
    })
    return {
      id: folderChapter.id,
      comicId,
      title: folderChapter.title,
      index: folderChapter.index,
      sourcePath: localLibraryFolderUri(options.rootUri, folderChapter.relativePath),
      sortKey: folderChapter.sortKey,
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
  })
  const metadataSeries: LocalLibraryMetadataSeriesInput = {
    title: series.title,
    relativePath: series.relativePath,
  }
  const resolvedMetadata = resolveLocalLibraryMetadata({
    sidecar: series.sidecarMetadata,
    derived: createDerivedLocalLibraryMetadata(metadataSeries),
  })
  let coverUri = chapters.find((chapter: Chapter): boolean => chapter.pages.length > 0)?.pages[0].uri
  if (resolvedMetadata.coverReference !== undefined && resolvedMetadata.coverReferenceSource === 'valid_sidecar') {
    coverUri = localLibraryFolderUri(options.rootUri, resolveLocalLibrarySeriesCoverReference(metadataSeries, resolvedMetadata.coverReference))
  }
  const comic: Comic = {
    id: comicId,
    title: resolvedMetadata.title,
    sourceKind: ComicSourceKind.LOCAL_FOLDER,
    sourcePath,
    remoteResourceId: `${rootId}:${series.relativePath}`,
    sortTitle: normalizeSortKey(resolvedMetadata.title),
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters,
    chapterCount: chapters.length,
    pageCount: chapters.reduce((total: number, chapter: Chapter): number => total + chapter.pageCount, 0),
    createdAt: now,
    updatedAt: now,
    lastImportedAt: now,
  }
  if (resolvedMetadata.authors.length > 0) {
    comic.author = resolvedMetadata.authors.join(', ')
  }
  if (coverUri !== undefined) {
    comic.coverUri = coverUri
  }
  if (series.sidecarMetadata !== undefined) {
    comic.localMetadata = {}
    if (series.sidecarMetadata.title !== undefined) {
      comic.localMetadata.titleOverride = series.sidecarMetadata.title
    }
    if (series.sidecarMetadata.authors !== undefined) {
      comic.localMetadata.authors = series.sidecarMetadata.authors
    }
    if (series.sidecarMetadata.status !== undefined) {
      comic.localMetadata.status = series.sidecarMetadata.status
    }
    if (series.sidecarMetadata.coverPath !== undefined) {
      comic.localMetadata.coverOverridePath = series.sidecarMetadata.coverPath
    }
  }
  return comic
}

export function buildComicsFromLocalLibraryFolderScan(
  scanResult: LocalLibraryFolderScanResult,
  rootUri: string,
  now: number = Date.now(),
): Comic[] {
  return scanResult.series.map((series: LocalLibraryFolderSeries): Comic => {
    return buildComicFromLocalLibraryFolderSeries(series, {
      rootUri,
      rootId: scanResult.contract.rootId,
      now,
    })
  })
}

function createChapter(candidate: ChapterCandidate, seriesId: string, index: number): LocalLibraryFolderChapter {
  const chapterId = idFor('chapter', `${candidate.kind}:${candidate.chapterPath}`)
  const pages = candidate.pages
    .slice()
    .sort((left: NormalizedLocalLibraryEntry, right: NormalizedLocalLibraryEntry): number => compareNaturalPath(left.relativePath, right.relativePath))
    .map((entry: NormalizedLocalLibraryEntry, pageIndex: number): LocalLibraryFolderPage => createPage(entry, chapterId, pageIndex))
  const title = candidate.kind === 'archive' ? stripExtension(candidate.chapterPath) : folderName(candidate.chapterPath)
  const chapter: LocalLibraryFolderChapter = {
    id: chapterId,
    seriesId,
    title,
    kind: candidate.kind,
    relativePath: candidate.chapterPath,
    index,
    pageCount: pages.length,
    pages,
    sortKey: normalizeSortKey(candidate.chapterPath),
  }
  if (candidate.archivePath !== undefined) {
    chapter.sourceArchivePath = candidate.archivePath
  }
  return chapter
}

function createSeries(
  seriesPath: string,
  candidates: ChapterCandidate[],
  sidecarMetadata?: LocalLibrarySidecarMetadata,
): LocalLibraryFolderSeries {
  const seriesId = idFor('series', seriesPath)
  const chapters = candidates
    .slice()
    .sort((left: ChapterCandidate, right: ChapterCandidate): number => compareNaturalPath(left.chapterPath, right.chapterPath))
    .map((candidate: ChapterCandidate, index: number): LocalLibraryFolderChapter => createChapter(candidate, seriesId, index))
  const series: LocalLibraryFolderSeries = {
    id: seriesId,
    title: folderName(seriesPath),
    relativePath: seriesPath,
    chapters,
    chapterCount: chapters.length,
    pageCount: chapters.reduce((total: number, chapter: LocalLibraryFolderChapter): number => total + chapter.pageCount, 0),
    sortKey: normalizeSortKey(seriesPath),
  }
  if (sidecarMetadata !== undefined) {
    series.sidecarMetadata = sidecarMetadata
  }
  return series
}

function addChapterCandidate(candidatesBySeriesPath: Map<string, ChapterCandidate[]>, candidate: ChapterCandidate): void {
  const candidates = candidatesBySeriesPath.get(candidate.seriesPath) ?? []
  candidates.push(candidate)
  candidatesBySeriesPath.set(candidate.seriesPath, candidates)
}

export function scanLocalLibraryFolderEntries(entries: LocalLibraryFolderEntry[], rootName?: string): LocalLibraryFolderScanResult {
  const rejectedEntries: LocalLibraryFolderRejectedEntry[] = []
  const normalizedEntries = normalizeEntries(entries, rejectedEntries)
  const imageFolders = new Map<string, ImageFolderGroup>()
  const archiveEntries: NormalizedLocalLibraryEntry[] = []
  const sidecarMetadataBySeriesPath = new Map<string, LocalLibrarySidecarMetadata>()

  normalizedEntries.forEach((entry: NormalizedLocalLibraryEntry) => {
    if (entry.kind !== 'file') {
      return
    }
    if (isLocalLibrarySidecarMetadataPath(entry.relativePath)) {
      const seriesPath = dirname(entry.relativePath)
      if (seriesPath.length === 0) {
        rejectedEntries.push({ relativePath: entry.relativePath, reason: 'root_level_metadata' })
        return
      }
      if (entry.textContent === undefined || entry.textContent.trim().length === 0) {
        rejectedEntries.push({ relativePath: entry.relativePath, reason: 'metadata_missing' })
        return
      }
      const parsed = parseLocalLibrarySidecarMetadata(entry.textContent)
      if (parsed.status !== 'ok' || parsed.metadata === undefined) {
        rejectedEntries.push({ relativePath: entry.relativePath, reason: 'metadata_invalid' })
        return
      }
      sidecarMetadataBySeriesPath.set(seriesPath, parsed.metadata)
      return
    }
    if (isSupportedImagePath(entry.relativePath)) {
      const folderPath = dirname(entry.relativePath)
      if (folderPath.length === 0) {
        rejectedEntries.push({ relativePath: entry.relativePath, reason: 'root_level_image' })
        return
      }
      const group = imageFolders.get(folderPath) ?? { folderPath, images: [] }
      group.images.push(entry)
      imageFolders.set(folderPath, group)
      return
    }
    if (isSupportedArchivePath(entry.relativePath)) {
      archiveEntries.push(entry)
      return
    }
    rejectedEntries.push({ relativePath: entry.relativePath, reason: 'unsupported' })
  })

  const childChapterCounts = new Map<string, number>()
  archiveEntries.forEach((entry: NormalizedLocalLibraryEntry) => {
    const parentPath = dirname(entry.relativePath)
    if (parentPath.length > 0) {
      childChapterCounts.set(parentPath, (childChapterCounts.get(parentPath) ?? 0) + 1)
    }
  })
  Array.from(imageFolders.values()).forEach((group: ImageFolderGroup) => {
    const parentPath = dirname(group.folderPath)
    if (parentPath.length > 0) {
      childChapterCounts.set(parentPath, (childChapterCounts.get(parentPath) ?? 0) + 1)
    }
  })

  const candidatesBySeriesPath = new Map<string, ChapterCandidate[]>()
  archiveEntries.forEach((entry: NormalizedLocalLibraryEntry) => {
    const parentPath = dirname(entry.relativePath)
    const seriesPath = parentPath.length === 0 ? stripExtension(entry.relativePath) : parentPath
    addChapterCandidate(candidatesBySeriesPath, {
      kind: 'archive',
      seriesPath,
      chapterPath: entry.relativePath,
      archivePath: entry.relativePath,
      pages: [],
    })
  })
  Array.from(imageFolders.values()).forEach((group: ImageFolderGroup) => {
    addChapterCandidate(candidatesBySeriesPath, inferImageFolderChapter(group, childChapterCounts))
  })

  const series = Array.from(candidatesBySeriesPath.keys())
    .sort((left: string, right: string): number => compareNaturalPath(left, right))
    .map((seriesPath: string): LocalLibraryFolderSeries => {
      return createSeries(seriesPath, candidatesBySeriesPath.get(seriesPath) ?? [], sidecarMetadataBySeriesPath.get(seriesPath))
    })

  return {
    contract: createLocalLibraryFolderRootContract(rootName),
    series,
    rejectedEntries: rejectedEntries.sort((left: LocalLibraryFolderRejectedEntry, right: LocalLibraryFolderRejectedEntry): number => {
      return compareNaturalPath(left.relativePath, right.relativePath)
    }),
    sourceEntryCount: entries.length,
  }
}

export function reconcileLocalLibraryFolderAvailability(
  knownSeries: LocalLibraryFolderKnownSeries[],
  scanResult: LocalLibraryFolderScanResult,
): LocalLibraryFolderAvailability[] {
  const availableSeriesIds = new Set<string>(scanResult.series.map((series: LocalLibraryFolderSeries): string => series.id))
  return knownSeries.map((series: LocalLibraryFolderKnownSeries): LocalLibraryFolderAvailability => {
    return {
      id: series.id,
      status: availableSeriesIds.has(series.id) ? 'available' : 'missing',
    }
  })
}
