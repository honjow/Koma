import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  ArchiveExtractionResult,
  ArchiveExtractionService,
  ArchiveExtractionCachePaths,
} from './ArchiveExtractionService'
import {
  getBaseName,
  isSupportedArchivePath,
  isSupportedImagePath,
  stripExtension,
} from './ImageSortUtils'
import {
  LocalImageImportCandidate,
  LocalImageImportResult,
  buildComicFromLocalImages,
} from './LocalImageImportService'
import {
  LocalLibraryFolderEntry,
  LocalLibraryFolderScanResult,
  scanLocalLibraryFolderEntries,
} from '../model/LocalLibraryFolderContract'
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
  status: 'succeeded'
  extractionResult: ArchiveExtractionResult
}

export interface LocalArchiveImportFailedResult {
  status: 'failed'
  sourceUri: string
  sandboxZipPath?: string
  extractionDir?: string
  cacheRootDir?: string
  error: string
}

export type LocalArchiveImportItemResult = LocalArchiveImportResult | LocalArchiveImportFailedResult

export interface LocalImageImportSelection {
  sourceUris: string[]
  copiedImages: LocalImageImportCandidate[]
  extractionDir: string
  cacheRootDir: string
}

export interface LocalImageImportSucceededResult extends LocalImageImportSelection {
  status: 'succeeded'
  importResult: LocalImageImportResult
}

export interface LocalImageImportFailedResult {
  status: 'failed'
  sourceUris: string[]
  extractionDir?: string
  cacheRootDir?: string
  error: string
}

export type LocalImageImportItemResult = LocalImageImportSucceededResult | LocalImageImportFailedResult

export interface LocalArchiveImportRequest {
  context: common.UIAbilityContext
  sourceUri: string
  title?: string
  comicId?: string
  importedAt?: number
}

export interface LocalImageImportRequest {
  context: common.UIAbilityContext
  sourceUris: string[]
  title?: string
  comicId?: string
  importedAt?: number
}

export interface LocalFolderImportSucceededResult {
  status: 'succeeded'
  rootUri: string
  scanResult: LocalLibraryFolderScanResult
}

export interface LocalFolderImportFailedResult {
  status: 'failed'
  rootUri?: string
  error: string
}

export type LocalFolderImportItemResult = LocalFolderImportSucceededResult | LocalFolderImportFailedResult

export const ARCHIVE_FILE_SUFFIX_FILTER = 'Comic archives(.zip, .cbz)|.zip,.cbz'
export const IMAGE_FILE_SUFFIX_FILTER = 'Images(.jpg, .jpeg, .png, .webp, .gif, .bmp, .avif)|.jpg,.jpeg,.png,.webp,.gif,.bmp,.avif'

const LOCAL_IMPORT_ERROR_COPY_FAILED = 'copy_failed'
const LOCAL_IMPORT_ERROR_EXTRACTION_FAILED = 'extraction_failed'
const LOCAL_IMPORT_ERROR_IMPORT_FAILED = 'import_failed'
const LOCAL_IMPORT_ERROR_ARCHIVE_IMPORT_FAILED = 'archive_import_failed'
const LOCAL_IMPORT_ERROR_IMAGE_IMPORT_FAILED = 'image_import_failed'
const LOCAL_IMPORT_ERROR_FOLDER_PICKER_FAILED = 'folder_picker_failed'
const LOCAL_IMPORT_ERROR_FOLDER_SCAN_FAILED = 'folder_scan_failed'

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

export function createArchiveDocumentSelectOptions(maxSelectNumber: number = 100): picker.DocumentSelectOptions {
  const options = new picker.DocumentSelectOptions()
  options.fileSuffixFilters = [ARCHIVE_FILE_SUFFIX_FILTER]
  options.maxSelectNumber = maxSelectNumber
  return options
}

export function createImageDocumentSelectOptions(maxSelectNumber: number = 300): picker.DocumentSelectOptions {
  const options = new picker.DocumentSelectOptions()
  options.fileSuffixFilters = [IMAGE_FILE_SUFFIX_FILTER]
  options.maxSelectNumber = maxSelectNumber
  return options
}

export function createFolderDocumentSelectOptions(maxSelectNumber: number = 1): picker.DocumentSelectOptions {
  const options = new picker.DocumentSelectOptions()
  options.selectMode = picker.DocumentSelectMode.FOLDER
  options.maxSelectNumber = maxSelectNumber
  return options
}

export async function pickArchiveUris(context: common.UIAbilityContext, maxSelectNumber: number = 100): Promise<string[]> {
  const documentPicker = new picker.DocumentViewPicker(context)
  return documentPicker.select(createArchiveDocumentSelectOptions(maxSelectNumber))
}

export async function pickImageUris(context: common.UIAbilityContext, maxSelectNumber: number = 300): Promise<string[]> {
  const documentPicker = new picker.DocumentViewPicker(context)
  return documentPicker.select(createImageDocumentSelectOptions(maxSelectNumber))
}

export async function pickFolderUris(context: common.UIAbilityContext, maxSelectNumber: number = 1): Promise<string[]> {
  const documentPicker = new picker.DocumentViewPicker(context)
  return documentPicker.select(createFolderDocumentSelectOptions(maxSelectNumber))
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

function createUniqueLocalImageFileName(sourceUri: string, usedNames: Set<string>): string {
  const baseName = getBaseName(sourceUri)
  const fallbackName = baseName.length === 0 ? 'image.jpg' : baseName
  if (!usedNames.has(fallbackName)) {
    usedNames.add(fallbackName)
    return fallbackName
  }
  const extensionIndex = fallbackName.lastIndexOf('.')
  const stem = extensionIndex <= 0 ? fallbackName : fallbackName.substring(0, extensionIndex)
  const extension = extensionIndex <= 0 ? '' : fallbackName.substring(extensionIndex)
  let suffix = 2
  while (usedNames.has(`${stem}-${suffix}${extension}`)) {
    suffix += 1
  }
  const uniqueName = `${stem}-${suffix}${extension}`
  usedNames.add(uniqueName)
  return uniqueName
}

function decodePickerPathSegment(value: string): string {
  try {
    return decodeURIComponent(value)
  } catch (_err) {
    return value
  }
}

function createLocalImageImportTitle(sourceUris: string[]): string {
  if (sourceUris.length === 0) {
    return AppStrings.get('import_image_title')
  }
  const normalized = sourceUris[0].replace(/\\/g, '/').split('?')[0].split('#')[0]
  const parts = normalized.split('/').filter((part: string) => part.length > 0)
  if (parts.length > 1) {
    const parent = decodePickerPathSegment(parts[parts.length - 2]).trim()
    if (parent.length > 0 && parent !== 'file:') {
      return parent
    }
  }
  const fallback = stripExtension(getBaseName(normalized)).trim()
  return fallback.length === 0 ? AppStrings.get('import_image_title') : decodePickerPathSegment(fallback)
}

function createPickedFolderRootName(rootUri: string): string {
  const normalized = rootUri.replace(/\\/g, '/').split('?')[0].split('#')[0]
  const fallback = decodePickerPathSegment(getBaseName(normalized)).trim()
  return fallback.length === 0 ? AppStrings.get('import_folder_title') : fallback
}

function normalizePickedFolderRelativePath(rootUri: string, listedPath: string): string {
  const normalizedRoot = normalizeImportCachePath(rootUri).replace(/\/+$/, '')
  let normalizedPath = normalizeImportCachePath(listedPath)
  if (normalizedPath.startsWith(`${normalizedRoot}/`)) {
    normalizedPath = normalizedPath.substring(normalizedRoot.length + 1)
  }
  normalizedPath = normalizedPath.replace(/^\/+/, '')
  return normalizedPath.split('/').map((segment: string): string => decodePickerPathSegment(segment)).join('/')
}

function joinPickedFolderUri(rootUri: string, relativePath: string): string {
  return `${normalizeImportCachePath(rootUri).replace(/\/+$/, '')}/${relativePath.split('/').map((segment: string): string => encodeURIComponent(segment)).join('/')}`
}

function isLocalLibraryMetadataPath(relativePath: string): boolean {
  const baseName = getBaseName(relativePath).toLocaleLowerCase()
  return baseName === 'metadata.json' ||
    baseName === 'series.json' ||
    baseName === 'comicinfo.json' ||
    baseName === 'comicinfo.xml' ||
    baseName === 'koma-metadata.json'
}

function readPickedFolderTextIfNeeded(entryUri: string, relativePath: string, byteSize?: number): string | undefined {
  if (!isLocalLibraryMetadataPath(relativePath) || (byteSize !== undefined && byteSize > 1024 * 1024)) {
    return undefined
  }
  try {
    return fs.readTextSync(entryUri, { encoding: 'utf-8' })
  } catch (_err) {
    return undefined
  }
}

export async function scanPickedFolderUri(rootUri: string): Promise<LocalLibraryFolderScanResult> {
  const listFileOptions: ListFileOptions = {
    recursion: true,
    listNum: 0,
  }
  const listedEntries = await fs.listFile(rootUri, listFileOptions)
  const entries: LocalLibraryFolderEntry[] = []
  for (const listedEntry of listedEntries) {
    const relativePath = normalizePickedFolderRelativePath(rootUri, listedEntry)
    if (relativePath.length === 0) {
      continue
    }
    const entryUri = listedEntry.includes('://') ? listedEntry : joinPickedFolderUri(rootUri, relativePath)
    try {
      const stat = await fs.stat(entryUri)
      entries.push({
        relativePath,
        kind: stat.isDirectory() ? 'directory' : 'file',
        byteSize: stat.isDirectory() ? undefined : stat.size,
        textContent: stat.isDirectory() ? undefined : readPickedFolderTextIfNeeded(entryUri, relativePath, stat.size),
      })
    } catch (_err) {
      entries.push({
        relativePath,
        exists: false,
      })
    }
  }
  return scanLocalLibraryFolderEntries(entries, createPickedFolderRootName(rootUri))
}

export async function copyPickedImageUriToSandbox(sourceUri: string, sandboxPath: string): Promise<void> {
  let sourceFile: fs.File | undefined = undefined
  let targetFile: fs.File | undefined = undefined

  try {
    sourceFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY)
    targetFile = await fs.open(sandboxPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    await fs.copyFile(sourceFile.fd, targetFile.fd, 0)
  } finally {
    closeFileQuietly(sourceFile)
    closeFileQuietly(targetFile)
  }
}

function createManagedImportPaths(filesDir: string): ArchiveExtractionCachePaths {
  const rootDir = joinImportCachePath(joinImportCachePath(filesDir, 'import'), `v1-${util.generateRandomUUID()}`)
  assertSafeComputedArchiveImportCacheRoot(filesDir, rootDir)
  return {
    rootDir,
    archiveZipPath: joinImportCachePath(rootDir, 'archive.zip'),
    extractionDir: joinImportCachePath(rootDir, 'extract'),
    manifestPath: joinImportCachePath(rootDir, 'manifest.json'),
  }
}

async function createManagedImportRoot(filesDir: string, rootDir: string): Promise<void> {
  const parentDir = joinImportCachePath(filesDir, 'import')
  try {
    await fs.mkdir(parentDir, true)
  } catch (error) {
    // HarmonyOS recursive mkdir reports EEXIST for an existing target too.
    if ((error as BusinessError).code !== 13900015 || !(await fs.stat(parentDir)).isDirectory()) {
      throw new Error(`Import parent directory unavailable: ${(error as BusinessError).code}`)
    }
  }
  // Do not reuse or clear any existing content, even on an unexpected UUID collision.
  await fs.mkdir(rootDir, false)
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
    const paths = createManagedImportPaths(request.context.filesDir)
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_CACHE_PATHS,
      sourceUri: request.sourceUri,
      sandboxZipPath: paths.archiveZipPath,
      cacheRootDir: paths.rootDir,
      extractionDir: paths.extractionDir,
    })
    await createManagedImportRoot(request.context.filesDir, paths.rootDir)
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
        error: LOCAL_IMPORT_ERROR_COPY_FAILED,
      })
      throw new Error(LOCAL_IMPORT_ERROR_COPY_FAILED)
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
          cleanOutputDir: false,
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
          error: LOCAL_IMPORT_ERROR_EXTRACTION_FAILED,
        })
        throw new Error(LOCAL_IMPORT_ERROR_EXTRACTION_FAILED)
      }

      extractionResult.importResult.comic.localImportOrigin = { kind: 'archive', sourceUris: [request.sourceUri] }

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
        status: 'succeeded',
        extractionResult,
      }
    } catch (error) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_FAILED,
        sourceUri: request.sourceUri,
        error: LOCAL_IMPORT_ERROR_IMPORT_FAILED,
      })
      throw new Error(LOCAL_IMPORT_ERROR_IMPORT_FAILED)
    }
  }

  async pickAndImportArchives(context: common.UIAbilityContext, maxSelectNumber: number = 100): Promise<LocalArchiveImportItemResult[]> {
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED,
    })
    const uris = await pickArchiveUris(context, maxSelectNumber)
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
      uriCount: uris.length,
    })
    const results: LocalArchiveImportItemResult[] = []
    for (const uri of uris) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
        sourceUri: uri,
      })
      try {
        results.push(await this.importPickedArchive({
          context,
          sourceUri: uri,
        }))
      } catch (error) {
        results.push({
          status: 'failed',
          sourceUri: uri,
          error: LOCAL_IMPORT_ERROR_ARCHIVE_IMPORT_FAILED,
        })
      }
    }
    return results
  }

  async preparePickedImages(request: LocalImageImportRequest): Promise<LocalImageImportSelection> {
    const supportedSourceUris = request.sourceUris.filter((sourceUri: string) => isSupportedImagePath(sourceUri))
    const paths = createManagedImportPaths(request.context.filesDir)
    const selection: LocalImageImportSelection = {
      sourceUris: request.sourceUris,
      copiedImages: [],
      cacheRootDir: paths.rootDir,
      extractionDir: paths.extractionDir,
    }
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_CACHE_PATHS,
      sourceUri: request.sourceUris.join(','),
      cacheRootDir: selection.cacheRootDir,
      extractionDir: selection.extractionDir,
    })
    await createManagedImportRoot(request.context.filesDir, selection.cacheRootDir)
    await fs.mkdir(selection.extractionDir, false)

    const usedFileNames = new Set<string>()
    for (const sourceUri of supportedSourceUris) {
      const fileName = createUniqueLocalImageFileName(sourceUri, usedFileNames)
      const sandboxPath = joinImportCachePath(selection.extractionDir, fileName)
      const selectionIndex = request.sourceUris.indexOf(sourceUri)
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_COPY_STARTED,
        sourceUri,
        extractionDir: selection.extractionDir,
      })
      try {
        await copyPickedImageUriToSandbox(sourceUri, sandboxPath)
        const stat = await fs.stat(sandboxPath)
        selection.copiedImages.push({
          sourceUri,
          sandboxPath,
          fileName,
          byteSize: stat.size,
          selectionIndex: selectionIndex < 0 ? undefined : selectionIndex,
        })
        this.reportDebugEvent({
          step: LOCAL_ARCHIVE_DEBUG_STEP_COPY_SUCCEEDED,
          sourceUri,
          extractionDir: selection.extractionDir,
        })
      } catch (error) {
        this.reportDebugEvent({
          step: LOCAL_ARCHIVE_DEBUG_STEP_COPY_FAILED,
          sourceUri,
          extractionDir: selection.extractionDir,
          error: LOCAL_IMPORT_ERROR_COPY_FAILED,
        })
        throw new Error(LOCAL_IMPORT_ERROR_COPY_FAILED)
      }
    }

    return selection
  }

  async importPickedImages(request: LocalImageImportRequest): Promise<LocalImageImportSucceededResult> {
    try {
      const selection = await this.preparePickedImages(request)
      const importCandidates: LocalImageImportCandidate[] = [...selection.copiedImages]
      request.sourceUris.forEach((sourceUri: string) => {
        if (!isSupportedImagePath(sourceUri)) {
          importCandidates.push({
            sourceUri,
            sandboxPath: sourceUri,
            fileName: getBaseName(sourceUri),
            selectionIndex: request.sourceUris.indexOf(sourceUri),
          })
        }
      })
      const importResult = buildComicFromLocalImages({
        sourcePath: selection.cacheRootDir,
        images: importCandidates,
        comicId: request.comicId,
        title: request.title ?? createLocalImageImportTitle(request.sourceUris),
        importedAt: request.importedAt,
      })
      importResult.comic.localImportOrigin = { kind: 'images', sourceUris: request.sourceUris.slice() }
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_SUCCEEDED,
        sourceUri: request.sourceUris.join(','),
        extractionDir: selection.extractionDir,
        comicId: importResult.comic.id,
        title: importResult.comic.title,
        pageCount: importResult.comic.pageCount,
      })
      console.info(`[Import] step=comic_built id=${importResult.comic.id} pages=${importResult.comic.pageCount}`)
      return {
        status: 'succeeded',
        sourceUris: selection.sourceUris,
        copiedImages: selection.copiedImages,
        extractionDir: selection.extractionDir,
        cacheRootDir: selection.cacheRootDir,
        importResult,
      }
    } catch (error) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_FAILED,
        sourceUri: request.sourceUris.join(','),
        error: LOCAL_IMPORT_ERROR_IMPORT_FAILED,
      })
      throw new Error(LOCAL_IMPORT_ERROR_IMPORT_FAILED)
    }
  }

  async pickAndImportImages(context: common.UIAbilityContext, maxSelectNumber: number = 300): Promise<LocalImageImportItemResult[]> {
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED,
    })
    const uris = await pickImageUris(context, maxSelectNumber)
    console.info(`[Import] step=images_picked count=${uris.length}`)
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
      uriCount: uris.length,
    })
    if (uris.length === 0) {
      return []
    }
    try {
      return [await this.importPickedImages({
        context,
        sourceUris: uris,
      })]
    } catch (error) {
      return [{
        status: 'failed',
        sourceUris: uris,
        error: LOCAL_IMPORT_ERROR_IMAGE_IMPORT_FAILED,
      }]
    }
  }

  async pickAndScanFolders(context: common.UIAbilityContext, maxSelectNumber: number = 1): Promise<LocalFolderImportItemResult[]> {
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED,
    })
    let folderUris: string[]
    try {
      folderUris = await pickFolderUris(context, maxSelectNumber)
    } catch (error) {
      return [{
        status: 'failed',
        error: LOCAL_IMPORT_ERROR_FOLDER_PICKER_FAILED,
      }]
    }
    this.reportDebugEvent({
      step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
      uriCount: folderUris.length,
    })
    const results: LocalFolderImportItemResult[] = []
    for (const rootUri of folderUris) {
      this.reportDebugEvent({
        step: LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED,
        sourceUri: rootUri,
      })
      try {
        const scanResult = await scanPickedFolderUri(rootUri)
        results.push({
          status: 'succeeded',
          rootUri,
          scanResult,
        })
      } catch (error) {
        results.push({
          status: 'failed',
          rootUri,
          error: LOCAL_IMPORT_ERROR_FOLDER_SCAN_FAILED,
        })
      }
    }
    return results
  }
}
