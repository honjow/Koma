import { common } from '@kit.AbilityKit'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import {
  ArchiveExtractionResult,
  ArchiveExtractionService,
  createArchiveExtractionCachePaths,
} from './ArchiveExtractionService'
import { isSupportedArchivePath } from './ImageSortUtils'

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

  constructor(archiveExtractionService: ArchiveExtractionService = new ArchiveExtractionService()) {
    this.archiveExtractionService = archiveExtractionService
  }

  async preparePickedArchive(request: LocalArchiveImportRequest): Promise<LocalArchiveImportSelection> {
    assertSupportedPickedArchive(request.sourceUri)
    const paths = createArchiveExtractionCachePaths(request.context.cacheDir, request.sourceUri, request.sourceUri)
    await fs.mkdir(paths.rootDir, true)
    await copyPickedArchiveUriToSandbox(request.sourceUri, paths.archiveZipPath)
    return {
      sourceUri: request.sourceUri,
      sandboxZipPath: paths.archiveZipPath,
      extractionDir: paths.extractionDir,
      cacheRootDir: paths.rootDir,
    }
  }

  async importPickedArchive(request: LocalArchiveImportRequest): Promise<LocalArchiveImportResult> {
    const selection = await this.preparePickedArchive(request)
    const extractionResult = await this.archiveExtractionService.extractArchive({
      archivePath: selection.sourceUri,
      sandboxZipPath: selection.sandboxZipPath,
      extractionDir: selection.extractionDir,
      comicId: request.comicId,
      title: request.title,
      importedAt: request.importedAt,
    })

    return {
      sourceUri: selection.sourceUri,
      sandboxZipPath: selection.sandboxZipPath,
      extractionDir: selection.extractionDir,
      cacheRootDir: selection.cacheRootDir,
      extractionResult,
    }
  }

  async pickAndImportArchives(context: common.UIAbilityContext, maxSelectNumber: number = 100): Promise<LocalArchiveImportResult[]> {
    const uris = await pickArchiveUris(context, maxSelectNumber)
    const results: LocalArchiveImportResult[] = []
    for (const uri of uris) {
      results.push(await this.importPickedArchive({
        context,
        sourceUri: uri,
      }))
    }
    return results
  }
}
