import { common } from '@kit.AbilityKit'
import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit'
import {
  ArchiveExtractionResult,
  ArchiveExtractionService,
  createArchiveExtractionCachePaths,
} from './ArchiveExtractionService'
import { isSupportedArchivePath } from './ImageSortUtils'
import {
  LOCAL_ARCHIVE_DEBUG_STEP_CACHE_PATHS,
  LOCAL_ARCHIVE_DEBUG_STEP_COPY_FAILED,
  LOCAL_ARCHIVE_DEBUG_STEP_COPY_STARTED,
  LOCAL_ARCHIVE_DEBUG_STEP_COPY_SUCCEEDED,
  LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_FAILED,
  LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_STARTED,
  LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_SUCCEEDED,
  LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_FAILED,
  LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_SUCCEEDED,
  LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
  LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED,
  LocalArchiveImportDebugEvent,
  LocalArchiveImportDebugSink,
} from './LocalImportDebugModels'

export interface LocalArchiveImportSelection {
  sourceUri: string
  sandboxZipPath: string
  extractionDir: string
  cacheRootDir: string
}

export interface LocalArchiveImportResult extends LocalArchiveImportSelection {
  extractionResult: ArchiveExtractionResult
}

export interface LocalArchiveImportRequest {
  context: common.UIAbilityContext
  sourceUri: string
  title?: string
  comicId?: string
  importedAt?: number
}

export const ARCHIVE_FILE_SUFFIX_FILTER = 'Comic archives(.zip, .cbz)|.zip,.cbz'

function assertSupportedPickedArchive(sourceUri: string): void {
  if (!isSupportedArchivePath(sourceUri)) {
    throw new Error(`Unsupported archive picker result: ${sourceUri}`)
  }
}

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function normalizeImportCachePath(value: string): string {
  let normalized = value.replace(/\\/g, '/').trim()
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function joinImportCachePath(parent: string, child: string): string {
  const left = normalizeImportCachePath(parent)
  const right = normalizeImportCachePath(child).replace(/^\/+/, '').replace(/\/+$/, '')
  if (left === '/') {
    return right.length === 0 ? left : `/${right}`
  }
  return right.length === 0 ? left : `${left}/${right}`
}

function hasUnsafeImportCachePathSegment(path: string): boolean {
  const normalized = normalizeImportCachePath(path)
  if (normalized === '/') {
    return false
  }
  return normalized.split('/').some((segment, index) => {
    if (segment === '.' || segment === '..') {
      return true
    }
    return segment.length === 0 && index > 0
  })
}

function normalizeListedImportCacheEntry(path: string): string {
  return path.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, '')
}

function compareDeepestPathFirst(left: string, right: string): number {
  const leftDepth = left.split('/').length
  const rightDepth = right.split('/').length
  if (leftDepth !== rightDepth) {
    return rightDepth - leftDepth
  }
  return right.localeCompare(left)
}

async function pathExists(path: string): Promise<boolean> {
  try {
    return await fs.access(path)
  } catch (_err) {
    return false
  }
}

export function assertSafeComputedArchiveImportCacheRoot(cacheDir: string, cacheRootDir: string): void {
  const normalizedCacheDir = normalizeImportCachePath(cacheDir)
  const normalizedRootDir = normalizeImportCachePath(cacheRootDir)
  const importParentDir = joinImportCachePath(normalizedCacheDir, 'import')
  if (
    hasUnsafeImportCachePathSegment(normalizedCacheDir) ||
    hasUnsafeImportCachePathSegment(normalizedRootDir) ||
    normalizedRootDir === importParentDir ||
    !normalizedRootDir.startsWith(`${importParentDir}/`)
  ) {
    throw new Error(`Refusing to delete outside computed archive import cache root: ${cacheRootDir}`)
  }
}

async function removeComputedArchiveImportCacheRoot(cacheDir: string, cacheRootDir: string): Promise<void> {
  assertSafeComputedArchiveImportCacheRoot(cacheDir, cacheRootDir)
  if (!(await pathExists(cacheRootDir))) {
    return
  }

  const listFileOptions: ListFileOptions = {
    recursion: true,
    listNum: 0,
  }
  const listedEntries = await fs.listFile(cacheRootDir, listFileOptions)
  const relativeEntries = listedEntries
    .map(normalizeListedImportCacheEntry)
    .filter((entry) => entry.length > 0)
    .sort(compareDeepestPathFirst)

  for (const relativeEntry of relativeEntries) {
    if (hasUnsafeImportCachePathSegment(relativeEntry)) {
      throw new Error(`Refusing to delete unsafe archive import cache entry: ${relativeEntry}`)
    }
    const entryPath = joinImportCachePath(cacheRootDir, relativeEntry)
    const stat = await fs.stat(entryPath)
    if (stat.isDirectory()) {
      await fs.rmdir(entryPath)
    } else {
      await fs.unlink(entryPath)
    }
  }

  await fs.rmdir(cacheRootDir)
}

export function createArchiveDocumentSelectOptions(maxSelectNumber: number = 100): picker.DocumentSelectOptions {
  const options = new picker.DocumentSelectOptions()
  options.fileSuffixFilters = [ARCHIVE_FILE_SUFFIX_FILTER]
  options.maxSelectNumber = maxSelectNumber
  return options
}

export async function pickArchiveUris(context: common.UIAbilityContext, maxSelectNumber: number = 100): Promise<string[]> {
  const documentPicker = new picker.DocumentViewPicker(context)
  return documentPicker.select(createArchiveDocumentSelectOptions(maxSelectNumber))
}

export async function copyPickedArchiveUriToSandbox(sourceUri: string, sandboxZipPath: string): Promise<void> {
  assertSupportedPickedArchive(sourceUri)
  let sourceFile: fs.File | undefined = undefined
  let targetFile: fs.File | undefined = undefined

  try {
    sourceFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY)
    targetFile = await fs.open(sandboxZipPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    await fs.copyFile(sourceFile.fd, targetFile.fd, 0)
  } finally {
    closeFileQuietly(sourceFile)
    closeFileQuietly(targetFile)
  }
}

export class LocalImportCoordinator {
  private readonly archiveExtractionService: ArchiveExtractionService
  private debugSink?: LocalArchiveImportDebugSink

  constructor(archiveExtractionService: ArchiveExtractionService = new ArchiveExtractionService(), debugSink?: LocalArchiveImportDebugSink) {
    this.archiveExtractionService = archiveExtractionService
    this.debugSink = debugSink
  }

  setDebugSink(debugSink?: LocalArchiveImportDebugSink): void {
    this.debugSink = debugSink
  }

  private reportDebugEvent(event: LocalArchiveImportDebugEvent): void {
    if (this.debugSink === undefined) {
      return
    }
    event.timestamp = Date.now()
    this.debugSink(event)
  }

  async preparePickedArchive(request: LocalArchiveImportRequest): Promise<LocalArchiveImportSelection> {
    assertSupportedPickedArchive(request.sourceUri)
    const paths = createArchiveExtractionCachePaths(request.context.cacheDir, request.sourceUri, request.sourceUri)
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_CACHE_PATHS,
      sourceUri: request.sourceUri,
      sandboxZipPath: paths.archiveZipPath,
      cacheRootDir: paths.rootDir,
      extractionDir: paths.extractionDir,
    })
    await removeComputedArchiveImportCacheRoot(request.context.cacheDir, paths.rootDir)
    await fs.mkdir(paths.rootDir, true)
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_COPY_STARTED,
      sourceUri: request.sourceUri,
      sandboxZipPath: paths.archiveZipPath,
    })
    try {
      await copyPickedArchiveUriToSandbox(request.sourceUri, paths.archiveZipPath)
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_COPY_SUCCEEDED,
        sourceUri: request.sourceUri,
        sandboxZipPath: paths.archiveZipPath,
      })
    } catch (error) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_COPY_FAILED,
        sourceUri: request.sourceUri,
        sandboxZipPath: paths.archiveZipPath,
        error: `${error}`,
      })
      throw new Error(`${error}`)
    }
    return {
      sourceUri: request.sourceUri,
      sandboxZipPath: paths.archiveZipPath,
      extractionDir: paths.extractionDir,
      cacheRootDir: paths.rootDir,
    }
  }

  async importPickedArchive(request: LocalArchiveImportRequest): Promise<LocalArchiveImportResult> {
    try {
      const selection = await this.preparePickedArchive(request)
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_STARTED,
        sourceUri: selection.sourceUri,
        sandboxZipPath: selection.sandboxZipPath,
        extractionDir: selection.extractionDir,
      })
      let extractionResult: ArchiveExtractionResult
      try {
        extractionResult = await this.archiveExtractionService.extractArchive({
          archivePath: selection.sourceUri,
          sandboxZipPath: selection.sandboxZipPath,
          extractionDir: selection.extractionDir,
          comicId: request.comicId,
          title: request.title,
          importedAt: request.importedAt,
        })
        this.reportDebugEvent({
          step: LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_SUCCEEDED,
          sourceUri: selection.sourceUri,
          sandboxZipPath: selection.sandboxZipPath,
          extractionDir: selection.extractionDir,
          pageCount: extractionResult.importResult.comic.pageCount,
        })
      } catch (error) {
        this.reportDebugEvent({
          step: LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_FAILED,
          sourceUri: selection.sourceUri,
          sandboxZipPath: selection.sandboxZipPath,
          extractionDir: selection.extractionDir,
          error: `${error}`,
        })
        throw new Error(`${error}`)
      }

      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_SUCCEEDED,
        sourceUri: selection.sourceUri,
        sandboxZipPath: selection.sandboxZipPath,
        extractionDir: selection.extractionDir,
        comicId: extractionResult.importResult.comic.id,
        title: extractionResult.importResult.comic.title,
        pageCount: extractionResult.importResult.comic.pageCount,
      })
      return {
        sourceUri: selection.sourceUri,
        sandboxZipPath: selection.sandboxZipPath,
        extractionDir: selection.extractionDir,
        cacheRootDir: selection.cacheRootDir,
        extractionResult,
      }
    } catch (error) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_FAILED,
        sourceUri: request.sourceUri,
        error: `${error}`,
      })
      throw new Error(`${error}`)
    }
  }

  async pickAndImportArchives(context: common.UIAbilityContext, maxSelectNumber: number = 100): Promise<LocalArchiveImportResult[]> {
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED,
    })
    const uris = await pickArchiveUris(context, maxSelectNumber)
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
      uriCount: uris.length,
    })
    const results: LocalArchiveImportResult[] = []
    for (const uri of uris) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
        sourceUri: uri,
      })
      results.push(await this.importPickedArchive({
        context,
        sourceUri: uri,
      }))
    }
    return results
  }
}
