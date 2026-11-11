import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { writeAppTextFile } from './AppFileTextPersistence'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  OfflineChapterDownloadManifest,
  OfflineDownloadedPage,
  OFFLINE_DOWNLOAD_MANIFEST_NAME,
  OFFLINE_DOWNLOAD_LEGACY_MANIFEST_NAME,
  OFFLINE_DOWNLOAD_ROOT_DIR_NAME,
  createOfflineDownloadStableHash,
} from './OfflineDownloadStore'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { normalizeDownloadLayout } from './DownloadLayoutMigration'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'

const CONTENT_STORAGE_SCHEMA_VERSION: number = 1
const CONTENT_STORAGE_STATE_FILE_NAME: string = '.koma-content-storage.v1.json'
const DOWNLOAD_ROOT_MARKER: string = '.koma-download-root'
const PUBLIC_APP_DIR_NAME: string = 'Koma'

interface PublicContentStorageState {
  schemaVersion: number
  rootPath: string
  rootUri: string
  migrationComplete: boolean
  cleanupPending: boolean
  legacyPreserved: boolean
  updatedAt: number
}

interface LegacyChapterCopySummary {
  copiedChapters: number
  failedChapters: number
  copiedPages: number
}

interface PublicRootSelection {
  path: string
  uri: string
}

let activeStorageBase: string = ''
let activeStorageUri: string = ''
let preparation: Promise<void> | undefined = undefined
let migration: Promise<boolean> | undefined = undefined
let rootResolutionFailed: boolean = false
let publicStorageReady: boolean = false
let preparationRunning: boolean = false
let cachedStateDirectory: string = ''
let cachedState: PublicContentStorageState | undefined = undefined

function normalizePath(value: string): string {
  return value.trim().replace(/\\/g, '/')
}

function trimTrailingSlash(value: string): string {
  let normalized = normalizePath(value)
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function joinPath(parent: string, child: string): string {
  const left = trimTrailingSlash(parent)
  const right = normalizePath(child).replace(/^\/+/, '').replace(/\/+$/, '')
  return right.length === 0 ? left : `${left}/${right}`
}

function joinUri(parent: string, child: string): string {
  const left = parent.trim().replace(/\/+$/, '')
  return `${left}/${child}`
}

function stateFilePath(context: common.Context): string {
  return joinPath(context.filesDir, CONTENT_STORAGE_STATE_FILE_NAME)
}

function readState(context: common.Context): PublicContentStorageState | undefined {
  if (cachedStateDirectory === context.filesDir) {
    return cachedState
  }
  cachedStateDirectory = context.filesDir
  cachedState = undefined
  const path = stateFilePath(context)
  try {
    if (!fs.accessSync(path)) return undefined
    const parsed = JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as PublicContentStorageState
    if (parsed.schemaVersion !== CONTENT_STORAGE_SCHEMA_VERSION || typeof parsed.rootPath !== 'string') {
      return undefined
    }
    cachedState = parsed
    return parsed
  } catch (_error) {
    return undefined
  }
}

function saveState(context: common.Context, state: PublicContentStorageState): void {
  writeAppTextFile(stateFilePath(context), JSON.stringify(state))
  cachedStateDirectory = context.filesDir
  cachedState = state
}

function createState(rootPath: string, rootUri: string, migrationComplete: boolean,
  cleanupPending: boolean, legacyPreserved: boolean): PublicContentStorageState {
  return {
    schemaVersion: CONTENT_STORAGE_SCHEMA_VERSION,
    rootPath,
    rootUri,
    migrationComplete,
    cleanupPending,
    legacyPreserved,
    updatedAt: Date.now(),
  }
}

function ensureDirectory(path: string): void {
  try {
    fs.mkdirSync(path, true)
  } catch (_error) {
    if (!fs.accessSync(path)) throw new Error('content_storage_directory_unavailable')
  }
}

function normalizePublicRootPath(path: string): string {
  let root = trimTrailingSlash(path)
  if (root.endsWith('/Koma/Koma')) {
    root = root.substring(0, root.length - '/Koma'.length)
  }
  const lastSegment = root.split('/').pop() ?? ''
  if (lastSegment.toLowerCase() === 'download') {
    root = joinPath(root, PUBLIC_APP_DIR_NAME)
  }
  return root
}

async function resolvePublicRoot(context: common.UIAbilityContext): Promise<PublicRootSelection> {
  const options = new picker.DocumentSaveOptions()
  options.pickerMode = picker.DocumentPickerMode.DOWNLOAD
  const result = await new picker.DocumentViewPicker(context).save(options)
  if (result.length === 0) throw new Error('content_storage_root_missing')
  const uri = result[0]
  DiagnosticLogger.info('storage', 'content_root_picker_returned', `uri_length=${uri.length}`)
  const markerPath = new fileUri.FileUri(joinUri(uri, DOWNLOAD_ROOT_MARKER)).path
  const suffix = `/${DOWNLOAD_ROOT_MARKER}`
  if (!markerPath.endsWith(suffix)) throw new Error('content_storage_root_invalid')
  const path = normalizePublicRootPath(markerPath.substring(0, markerPath.length - suffix.length))
  if (!path.startsWith('/')) throw new Error('content_storage_root_relative')
  DiagnosticLogger.info('storage', 'content_root_path_resolved', `path_length=${path.length}`)
  ensureDirectory(path)
  DiagnosticLogger.info('storage', 'content_root_ready', `path_length=${path.length}`)
  return { path, uri }
}

function isDirectory(path: string): boolean {
  try {
    return fs.accessSync(path) && fs.statSync(path).isDirectory()
  } catch (_error) {
    return false
  }
}

function removeDirectorySync(path: string): void {
  if (!fs.accessSync(path)) return
  const stat = fs.statSync(path)
  if (!stat.isDirectory()) {
    fs.unlinkSync(path)
    return
  }
  const names = fs.listFileSync(path)
  names.forEach((name: string): void => {
    removeDirectorySync(joinPath(path, name))
  })
  fs.rmdirSync(path)
}

function writeTextFileSync(path: string, payload: string): void {
  const temp = `${path}.migrating`
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(temp, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    fs.fsyncSync(file.fd)
    fs.closeSync(file)
    file = undefined
    if (fs.readTextSync(temp, { encoding: 'utf-8' }) !== payload) {
      throw new Error('content_storage_manifest_write_failed')
    }
    fs.renameSync(temp, path)
  } finally {
    if (file !== undefined) {
      try { fs.closeSync(file) } catch (_error) {}
    }
    try {
      if (fs.accessSync(temp)) fs.unlinkSync(temp)
    } catch (_error) {}
  }
}

@Concurrent
function copyLegacyDownloadTree(legacyBase: string, publicBase: string): LegacyChapterCopySummary {
  const normalize = (value: string): string => value.trim().replace(/\\/g, '/')
  const trimSlash = (value: string): string => {
    let out = normalize(value)
    while (out.length > 1 && out.endsWith('/')) out = out.substring(0, out.length - 1)
    return out
  }
  const join = (parent: string, child: string): string => {
    const left = trimSlash(parent)
    const right = normalize(child).replace(/^\/+/, '').replace(/\/+$/, '')
    return right.length === 0 ? left : `${left}/${right}`
  }
  const ensureDir = (path: string): void => {
    try {
      fs.mkdirSync(path, true)
    } catch (_error) {
      if (!fs.accessSync(path)) throw new Error('content_storage_directory_unavailable')
    }
  }
  const removeDir = (path: string): void => {
    if (!fs.accessSync(path)) return
    if (!fs.statSync(path).isDirectory()) {
      fs.unlinkSync(path)
      return
    }
    fs.listFileSync(path).forEach((name: string): void => { removeDir(join(path, name)) })
    fs.rmdirSync(path)
  }
  const writeManifest = (path: string, payload: string): void => {
    const temp = `${path}.migrating`
    let file: fs.File | undefined = undefined
    try {
      file = fs.openSync(temp, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
      fs.fsyncSync(file.fd)
      fs.closeSync(file)
      file = undefined
      if (fs.readTextSync(temp, { encoding: 'utf-8' }) !== payload) {
        throw new Error('content_storage_manifest_write_failed')
      }
      fs.renameSync(temp, path)
    } finally {
      if (file !== undefined) {
        try { fs.closeSync(file) } catch (_error) {}
      }
      try {
        if (fs.accessSync(temp)) fs.unlinkSync(temp)
      } catch (_error) {}
    }
  }
  const copyChapter = (sourceChapterDir: string, targetDownloadsDir: string,
    manifest: OfflineChapterDownloadManifest, tempSuffix: string): number => {
    if (!Array.isArray(manifest.pages) || manifest.comicId.length === 0 || manifest.chapterId.length === 0) {
      throw new Error('content_storage_manifest_invalid')
    }
    const ownerName = createOfflineDownloadStableHash(manifest.comicId)
    const chapterName = createOfflineDownloadStableHash(manifest.chapterId)
    const targetOwnerDir = join(targetDownloadsDir, ownerName)
    const targetChapterDir = join(targetOwnerDir, chapterName)
    ensureDir(targetOwnerDir)
    const tempDir = join(targetOwnerDir, `.${chapterName}.migrating-${tempSuffix}`)
    if (fs.accessSync(tempDir)) removeDir(tempDir)
    ensureDir(tempDir)
    let copiedPages = 0
    try {
      const migratedPages: OfflineDownloadedPage[] = manifest.pages.map((page: OfflineDownloadedPage): OfflineDownloadedPage => {
        const sourcePath = normalize(page.localPath)
        const fileName = normalize(page.fileName ?? sourcePath.split('/').pop() ?? '')
        if (fileName.length === 0 || fileName.includes('/') || fileName === '..') {
          throw new Error('content_storage_page_name_invalid')
        }
        const sourcePage = join(sourceChapterDir, fileName)
        const targetPage = join(tempDir, fileName)
        if (fs.accessSync(sourcePage)) {
          fs.copyFileSync(sourcePage, targetPage, 0)
          const sourceSize = fs.statSync(sourcePage).size
          const targetSize = fs.statSync(targetPage).size
          if (sourceSize !== targetSize || (page.size > 0 && targetSize !== page.size)) {
            throw new Error('content_storage_page_copy_mismatch')
          }
          copiedPages += 1
        }
        return {
          pageId: page.pageId, pageIndex: page.pageIndex, fileName: page.fileName ?? fileName,
          width: page.width, height: page.height, localPath: join(targetChapterDir, fileName),
          size: page.size, contentHash: page.contentHash,
          imageProcessingFingerprint: page.imageProcessingFingerprint,
          imageProcessingResolved: page.imageProcessingResolved, imageProcessing: page.imageProcessing,
          sourceOriginalUri: page.sourceOriginalUri, sourceTextOverlay: page.sourceTextOverlay,
          requiredImageDecodeResolved: page.requiredImageDecodeResolved, updatedAt: page.updatedAt,
        }
      })
      const migratedManifest: OfflineChapterDownloadManifest = {
        schemaVersion: manifest.schemaVersion, sourceKind: manifest.sourceKind, sourceId: manifest.sourceId,
        sourceMangaUrl: manifest.sourceMangaUrl, comicId: manifest.comicId, comicTitle: manifest.comicTitle,
        seriesId: manifest.seriesId, chapterId: manifest.chapterId, chapterTitle: manifest.chapterTitle,
        pageCount: manifest.pageCount, downloadedPageCount: manifest.downloadedPageCount,
        status: manifest.status, updatedAt: manifest.updatedAt, pages: migratedPages,
        integrityHash: manifest.integrityHash, failureReasonCode: manifest.failureReasonCode,
      }
      const metadataDir = join(tempDir, '.koma')
      ensureDir(metadataDir)
      writeManifest(join(metadataDir, OFFLINE_DOWNLOAD_MANIFEST_NAME), JSON.stringify(migratedManifest))
      const replacedDir = join(targetOwnerDir, `.${chapterName}.replaced-${tempSuffix}`)
      if (fs.accessSync(replacedDir)) removeDir(replacedDir)
      if (fs.accessSync(targetChapterDir)) {
        fs.renameSync(targetChapterDir, replacedDir)
      }
      try {
        fs.renameSync(tempDir, targetChapterDir)
      } catch (error) {
        if (fs.accessSync(replacedDir) && !fs.accessSync(targetChapterDir)) {
          fs.renameSync(replacedDir, targetChapterDir)
        }
        throw error as Error
      }
      if (fs.accessSync(replacedDir)) removeDir(replacedDir)
      return copiedPages
    } catch (error) {
      try { removeDir(tempDir) } catch (_error) {}
      throw error as Error
    }
  }
  const sourceDownloadsDir = join(legacyBase, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
  const targetDownloadsDir = join(publicBase, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
  const summary: LegacyChapterCopySummary = {
    copiedChapters: 0, failedChapters: 0, copiedPages: 0,
  }
  if (!fs.accessSync(sourceDownloadsDir)) return summary
  ensureDir(targetDownloadsDir)
  const owners = fs.listFileSync(sourceDownloadsDir)
  for (let ownerIndex = 0; ownerIndex < owners.length; ownerIndex += 1) {
    if (owners[ownerIndex].startsWith('.')) continue
    const ownerPath = join(sourceDownloadsDir, owners[ownerIndex])
    if (!fs.statSync(ownerPath).isDirectory()) continue
    const chapters = fs.listFileSync(ownerPath)
    for (let chapterIndex = 0; chapterIndex < chapters.length; chapterIndex += 1) {
      if (chapters[chapterIndex].startsWith('.')) continue
      const chapterPath = join(ownerPath, chapters[chapterIndex])
      if (!fs.statSync(chapterPath).isDirectory()) continue
      const candidates = [join(chapterPath, OFFLINE_DOWNLOAD_LEGACY_MANIFEST_NAME),
        join(join(chapterPath, '.koma'), OFFLINE_DOWNLOAD_LEGACY_MANIFEST_NAME),
        join(join(chapterPath, '.koma'), OFFLINE_DOWNLOAD_MANIFEST_NAME)]
      const manifestPath = candidates.find((candidate: string): boolean => fs.accessSync(candidate))
      if (manifestPath === undefined) {
        summary.failedChapters += 1
        continue
      }
      try {
        const manifest = JSON.parse(fs.readTextSync(manifestPath, { encoding: 'utf-8' })) as OfflineChapterDownloadManifest
        const copied = copyChapter(chapterPath, targetDownloadsDir, manifest,
          `${Date.now()}-${ownerIndex}-${chapterIndex}`)
        summary.copiedChapters += 1
        summary.copiedPages += copied
      } catch (_error) {
        summary.failedChapters += 1
      }
    }
  }
  return summary
}

function mergeQueueRoots(legacyBase: string, publicBase: string): void {
  const legacyQueue = new OfflineDownloadQueueStore(legacyBase)
  const publicQueue = new OfflineDownloadQueueStore(publicBase)
  publicQueue.mergeFromLegacy(legacyQueue)
}

async function migrateLegacyDownloads(context: common.UIAbilityContext, rootPath: string,
  rootUri: string): Promise<boolean> {
  const legacyBase = context.filesDir
  const legacyDownloads = joinPath(legacyBase, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
  if (!fs.accessSync(legacyDownloads)) {
    saveState(context, createState(rootPath, rootUri, true, false, false))
    activeStorageBase = rootPath
    activeStorageUri = rootUri
    publicStorageReady = true
    return true
  }
  try {
    const result = await taskpool.execute(new taskpool.Task(copyLegacyDownloadTree, legacyBase, rootPath)) as LegacyChapterCopySummary
    if (result.failedChapters > 0) {
      DiagnosticLogger.warn('storage', 'legacy_download_migration_failed',
        `failed=${result.failedChapters} copied=${result.copiedChapters}`)
      return false
    }
    mergeQueueRoots(legacyBase, rootPath)
    const nextState = createState(rootPath, rootUri, true, true, false)
    saveState(context, nextState)
    activeStorageBase = rootPath
    activeStorageUri = rootUri
    publicStorageReady = true
    cleanupLegacyDownloads(context, nextState)
    DiagnosticLogger.info('storage', 'legacy_download_migration_complete',
      `copied_chapters=${result.copiedChapters} copied_pages=${result.copiedPages}`)
    return true
  } catch (error) {
    DiagnosticLogger.exception('storage', 'legacy_download_migration_exception', error as Error)
    return false
  }
}

function cleanupLegacyDownloads(context: common.Context, state: PublicContentStorageState): void {
  if (!state.cleanupPending || state.legacyPreserved) return
  try {
    const legacyDownloads = joinPath(context.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
    if (fs.accessSync(legacyDownloads)) removeDirectorySync(legacyDownloads)
    saveState(context, createState(state.rootPath, state.rootUri, state.migrationComplete, false,
      state.legacyPreserved))
    DiagnosticLogger.info('storage', 'legacy_download_cleanup_complete', '')
  } catch (error) {
    DiagnosticLogger.exception('storage', 'legacy_download_cleanup_failed', error as Error)
  }
}

async function prepareInternal(context: common.UIAbilityContext): Promise<void> {
  migration = undefined
  publicStorageReady = false
  try {
    const previous = readState(context)
    let root: PublicRootSelection | undefined = undefined
    if (previous !== undefined && previous.migrationComplete && isDirectory(previous.rootPath)) {
      // DOWNLOAD-mode roots are app-owned paths; path access is the capability after a cold start.
      root = { path: previous.rootPath, uri: previous.rootUri }
    }
    if (root === undefined) root = await resolvePublicRoot(context)
    activeStorageUri = root.uri
    activeStorageBase = context.filesDir
    rootResolutionFailed = false
    migration = migrateLegacyDownloads(context, root.path, root.uri)
    const migrated = await migration
    // The source registry is bootstrapped before launch content. Persisting
    // the installed localized name keeps old downloads readable even if the
    // package is later unavailable; the resolver falls back to sourceId.
    if (migrated) {
      normalizeDownloadLayout(joinPath(root.path, OFFLINE_DOWNLOAD_ROOT_DIR_NAME),
        (sourceId: string): string => sourceDisplayName(sourceId))
    }
  } catch (error) {
    rootResolutionFailed = true
    activeStorageBase = context.filesDir
    DiagnosticLogger.exception('storage', 'content_root_unavailable', error as Error)
  }
}

/** Resolve the public Download app directory once per process and start legacy migration. */
export function prepareKomaContentStorage(context: common.UIAbilityContext): Promise<void> {
  if (!preparationRunning && !publicStorageReady) {
    preparationRunning = true
    preparation = prepareInternal(context).finally((): void => {
      preparationRunning = false
    })
  }
  return preparation ?? Promise.resolve()
}

/** Wait until legacy data has either migrated or been deliberately retained in the sandbox. */
export async function ensureKomaContentStorageBase(context: common.UIAbilityContext): Promise<string> {
  await prepareKomaContentStorage(context)
  if (migration !== undefined) await migration
  return activeStorageBase.length > 0 ? activeStorageBase : context.filesDir
}

export async function waitKomaContentStorageReady(): Promise<void> {
  if (preparation !== undefined) await preparation
  if (migration !== undefined) await migration
}

/** Synchronous consumers use the public root only after this process resolved it. */
export function komaContentStorageBase(context: common.Context): string {
  if (activeStorageBase.length > 0) return activeStorageBase
  if (rootResolutionFailed) return context.filesDir
  return context.filesDir
}

/** Background entry points activate the persisted public grant before reading the completed root. */
export async function ensureKomaBackgroundContentStorageBase(context: common.Context): Promise<string> {
  const state = readState(context)
  if (state !== undefined && state.migrationComplete) {
    try {
      if (fs.statSync(state.rootPath).isDirectory()) return state.rootPath
    } catch (error) {
      DiagnosticLogger.warn('storage', 'background_content_root_unavailable',
        `code=${(error as Error).message}`)
    }
  }
  return context.filesDir
}

export function komaContentStorageUri(): string {
  return activeStorageUri
}

export function komaRuntimeStorageKey(context: common.Context): string {
  return context.filesDir
}
