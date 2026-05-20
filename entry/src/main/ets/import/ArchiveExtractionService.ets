import { zlib } from '@kit.BasicServicesKit'
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'
import { ReadingDirection } from '../model/ComicModels'
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
    await zlib.decompressFile(request.sandboxZipPath, request.extractionDir)
    assertNotCancelled(request.cancelToken)

    const entries = await this.listImageEntries(request.extractionDir)
    const importResult = buildComicFromArchive({
      archivePath: request.archivePath,
      entries,
      comicId: request.comicId,
      title: request.title,
      importedAt: request.importedAt,
      readingDirection: request.readingDirection,
    })

    return {
      archivePath: request.archivePath,
      sandboxZipPath: request.sandboxZipPath,
      extractionDir: request.extractionDir,
      entries,
      importResult,
    }
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
