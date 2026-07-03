import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'
import {
  ComicId,
  ComicSourceKind,
  PageId,
} from './ComicModels'

export const OFFLINE_DOWNLOAD_SCHEMA_VERSION: number = 1
export const OFFLINE_DOWNLOAD_ROOT_DIR_NAME: string = 'downloads'
export const OFFLINE_DOWNLOAD_MANIFEST_NAME: string = 'manifest.v1.json'

export enum OfflineDownloadStatus {
  QUEUED = 'queued',
  DOWNLOADING = 'downloading',
  DOWNLOADED = 'downloaded',
  PARTIAL = 'partial',
  FAILED = 'failed',
  BLOCKED = 'blocked',
}

export enum OfflineDownloadedChapterStatus {
  DOWNLOADED = 'downloaded',
  PARTIAL = 'partial',
  CORRUPT = 'corrupt',
  MISSING = 'missing',
}

function parseOfflineDownloadStatus(value: string): OfflineDownloadStatus | undefined {
  if (value === OfflineDownloadStatus.QUEUED ||
    value === OfflineDownloadStatus.DOWNLOADING ||
    value === OfflineDownloadStatus.DOWNLOADED ||
    value === OfflineDownloadStatus.PARTIAL ||
    value === OfflineDownloadStatus.FAILED ||
    value === OfflineDownloadStatus.BLOCKED) {
    return value
  }
  return undefined
}

function isReaderReadyOfflineDownloadStatus(status: OfflineDownloadStatus): boolean {
  return status === OfflineDownloadStatus.DOWNLOADED || status === OfflineDownloadStatus.PARTIAL
}

export interface OfflineDownloadedPage {
  pageId: PageId
  pageIndex: number
  fileName?: string
  localPath: string
  size: number
  updatedAt: number
}

export interface OfflineChapterDownloadManifest {
  schemaVersion: number
  sourceKind?: ComicSourceKind
  sourceId?: string
  comicId: ComicId
  seriesId: ComicId
  chapterId: string
  pageCount: number
  downloadedPageCount: number
  status: OfflineDownloadStatus
  updatedAt: number
  pages: OfflineDownloadedPage[]
  integrityHash: string
  failureReasonCode?: string
}

export interface OfflineDownloadSummary {
  comicId: ComicId
  chapterId: string
  pageCount: number
  downloadedPageCount: number
  status: OfflineDownloadStatus
  updatedAt: number
}

export interface OfflineChapterManifestIdentity {
  sourceKind?: ComicSourceKind
  sourceId?: string
  seriesId?: ComicId
}

export interface OfflineDownloadManifestValidation {
  comicId: ComicId
  chapterId: string
  status: OfflineDownloadedChapterStatus
  manifest?: OfflineChapterDownloadManifest
  pageCount: number
  availablePageCount: number
  missingPageCount: number
  reasonCode?: string
}

function compareDeepestPathFirst(left: string, right: string): number {
  const leftDepth = left.split('/').length
  const rightDepth = right.split('/').length
  if (leftDepth !== rightDepth) {
    return rightDepth - leftDepth
  }
  return right.localeCompare(left)
}

function normalizeDownloadPath(value: string): string {
  return value.replace(/\\/g, '/').trim()
}

function trimTrailingSlash(value: string): string {
  let normalized = normalizeDownloadPath(value)
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function hasTraversalSegment(path: string): boolean {
  return path.split('/').some((segment: string): boolean => segment === '..')
}

export function assertSafeOfflineDownloadRoot(filesDir: string, candidatePath: string): void {
  const normalizedFilesDir = trimTrailingSlash(filesDir)
  const normalizedCandidate = trimTrailingSlash(candidatePath)
  if (normalizedFilesDir.length === 0 || !normalizedFilesDir.startsWith('/') || hasTraversalSegment(normalizedFilesDir)) {
    throw new Error('unsafe offline download filesDir')
  }
  const expectedPrefix = `${normalizedFilesDir}/${OFFLINE_DOWNLOAD_ROOT_DIR_NAME}/`
  if (!normalizedCandidate.startsWith(expectedPrefix) || hasTraversalSegment(normalizedCandidate)) {
    throw new Error('unsafe offline download path')
  }
}

export function createOfflineDownloadStableHash(value: string): string {
  let hashA = 2166136261
  let hashB = 2166136261 ^ 0x9e3779b9
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    hashA = Math.imul((hashA ^ code) >>> 0, 16777619) >>> 0
    hashB = Math.imul((hashB ^ (code + index)) >>> 0, 16777619) >>> 0
  }
  return `${hashA.toString(16).padStart(8, '0')}${hashB.toString(16).padStart(8, '0')}`
}

function joinOfflineDownloadPath(parent: string, child: string): string {
  const left = trimTrailingSlash(parent)
  const right = normalizeDownloadPath(child).replace(/^\/+/, '').replace(/\/+$/, '')
  return right.length === 0 ? left : `${left}/${right}`
}

function pathBaseName(path: string): string {
  return normalizeDownloadPath(path).split('/').pop() ?? ''
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

function ensureDirSync(path: string): void {
  if (!fs.accessSync(path)) {
    fs.mkdirSync(path, true)
  }
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
  }
}

async function pathExists(path: string): Promise<boolean> {
  try {
    return await fs.access(path)
  } catch (_err) {
    return false
  }
}

function safeParseManifest(payload: string): OfflineChapterDownloadManifest {
  const parsed = JSON.parse(payload) as OfflineChapterDownloadManifest
  if (parsed.schemaVersion !== OFFLINE_DOWNLOAD_SCHEMA_VERSION ||
    (parsed.sourceKind !== undefined && parsed.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE &&
      parsed.sourceKind !== ComicSourceKind.LOCAL_FOLDER &&
      parsed.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY &&
      parsed.sourceKind !== ComicSourceKind.KOMGA_REMOTE &&
      parsed.sourceKind !== ComicSourceKind.OPDS_REMOTE &&
      parsed.sourceKind !== ComicSourceKind.WEBDAV_REMOTE) ||
    (parsed.sourceId !== undefined && typeof parsed.sourceId !== 'string') ||
    typeof parsed.comicId !== 'string' ||
    typeof parsed.seriesId !== 'string' ||
    typeof parsed.chapterId !== 'string' ||
    typeof parsed.pageCount !== 'number' ||
    typeof parsed.downloadedPageCount !== 'number' ||
    typeof parsed.status !== 'string' ||
    typeof parsed.updatedAt !== 'number' ||
    !Array.isArray(parsed.pages) ||
    typeof parsed.integrityHash !== 'string') {
    throw new Error('Unsupported offline download manifest')
  }
  for (let index = 0; index < parsed.pages.length; index += 1) {
    const page = parsed.pages[index]
    if (typeof page.pageId !== 'string' ||
      typeof page.pageIndex !== 'number' ||
      typeof page.localPath !== 'string' ||
      typeof page.size !== 'number' ||
      typeof page.updatedAt !== 'number') {
      throw new Error('Unsupported offline download page manifest')
    }
  }
  return parsed
}

function normalizeExtension(extension: string): string {
  const normalized = extension.toLocaleLowerCase().replace(/[^a-z0-9]/g, '')
  return normalized.length === 0 ? 'img' : normalized
}

function manifestIntegrityPayload(manifest: OfflineChapterDownloadManifest): string {
  // The integrity hash excludes absolute sandbox prefixes; path safety is validated against the chapter dir.
  const pages = manifest.pages.slice().sort((left: OfflineDownloadedPage, right: OfflineDownloadedPage): number => {
    return left.pageIndex - right.pageIndex
  }).map((page: OfflineDownloadedPage): string => {
    return [
      page.pageIndex,
      page.pageId,
      page.fileName ?? pathBaseName(page.localPath),
      Math.max(0, Math.floor(page.size)),
    ].join(':')
  })
  return [
    OFFLINE_DOWNLOAD_SCHEMA_VERSION,
    manifest.sourceKind ?? '',
    manifest.sourceId ?? '',
    manifest.comicId,
    manifest.seriesId,
    manifest.chapterId,
    Math.max(0, Math.floor(manifest.pageCount)),
    pages.join('|'),
  ].join('\n')
}

function createManifestIntegrityHash(manifest: OfflineChapterDownloadManifest): string {
  return createOfflineDownloadStableHash(manifestIntegrityPayload(manifest))
}

export class OfflineDownloadStore {
  private readonly filesDir: string
  private readonly rootDir: string

  constructor(filesDir: string) {
    this.filesDir = trimTrailingSlash(filesDir)
    this.rootDir = joinOfflineDownloadPath(this.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
    this.ensureRoot()
  }

  filesRootDir(): string {
    return this.filesDir
  }

  chapterDir(comicId: ComicId, chapterId: string): string {
    const path = joinOfflineDownloadPath(
      joinOfflineDownloadPath(this.rootDir, createOfflineDownloadStableHash(comicId)),
      createOfflineDownloadStableHash(chapterId)
    )
    assertSafeOfflineDownloadRoot(this.filesDir, path)
    return path
  }

  manifestPath(comicId: ComicId, chapterId: string): string {
    return joinOfflineDownloadPath(this.chapterDir(comicId, chapterId), OFFLINE_DOWNLOAD_MANIFEST_NAME)
  }

  pageFilePath(comicId: ComicId, chapterId: string, pageId: string, pageIndex: number, extension: string): string {
    const fileName = `${String(pageIndex + 1).padStart(5, '0')}-${createOfflineDownloadStableHash(pageId)}.${normalizeExtension(extension)}`
    const path = joinOfflineDownloadPath(this.chapterDir(comicId, chapterId), fileName)
    assertSafeOfflineDownloadRoot(this.filesDir, path)
    return path
  }

  loadManifest(comicId: ComicId, chapterId: string): OfflineChapterDownloadManifest | undefined {
    const path = this.manifestPath(comicId, chapterId)
    if (!fs.accessSync(path)) {
      return undefined
    }
    try {
      return safeParseManifest(fs.readTextSync(path, { encoding: 'utf-8' }))
    } catch (_err) {
      return undefined
    }
  }

  validateDownloadedChapter(comicId: ComicId, chapterId: string): OfflineDownloadManifestValidation {
    const path = this.manifestPath(comicId, chapterId)
    if (!fs.accessSync(path)) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.MISSING,
        pageCount: 0,
        availablePageCount: 0,
        missingPageCount: 0,
        reasonCode: 'manifest_missing',
      }
    }
    let manifest: OfflineChapterDownloadManifest
    try {
      manifest = safeParseManifest(fs.readTextSync(path, { encoding: 'utf-8' }))
    } catch (_err) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.CORRUPT,
        pageCount: 0,
        availablePageCount: 0,
        missingPageCount: 0,
        reasonCode: 'manifest_malformed',
      }
    }
    if (manifest.comicId !== comicId || manifest.chapterId !== chapterId || manifest.seriesId !== comicId) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.CORRUPT,
        manifest,
        pageCount: Math.max(0, Math.floor(manifest.pageCount)),
        availablePageCount: 0,
        missingPageCount: Math.max(0, Math.floor(manifest.pageCount)),
        reasonCode: 'identity_mismatch',
      }
    }
    const pageCount = Math.max(0, Math.floor(manifest.pageCount))
    const manifestStatus = parseOfflineDownloadStatus(manifest.status)
    if (manifestStatus === undefined) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.CORRUPT,
        manifest,
        pageCount,
        availablePageCount: 0,
        missingPageCount: pageCount,
        reasonCode: 'status_invalid',
      }
    }
    if (!isReaderReadyOfflineDownloadStatus(manifestStatus)) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.MISSING,
        manifest,
        pageCount,
        availablePageCount: 0,
        missingPageCount: pageCount,
        reasonCode: 'status_not_reader_ready',
      }
    }
    if (manifest.integrityHash.trim().length === 0) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.CORRUPT,
        manifest,
        pageCount,
        availablePageCount: 0,
        missingPageCount: pageCount,
        reasonCode: 'integrity_missing',
      }
    }
    if (createManifestIntegrityHash(manifest) !== manifest.integrityHash) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.CORRUPT,
        manifest,
        pageCount,
        availablePageCount: 0,
        missingPageCount: pageCount,
        reasonCode: 'integrity_mismatch',
      }
    }
    if (pageCount <= 0 || manifest.pages.length === 0) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.MISSING,
        manifest,
        pageCount,
        availablePageCount: 0,
        missingPageCount: pageCount,
        reasonCode: pageCount <= 0 ? 'page_count_empty' : 'pages_missing',
      }
    }
    const chapterDir = this.chapterDir(comicId, chapterId)
    let availablePageCount = 0
    const seenIndexes: number[] = []
    for (let index = 0; index < manifest.pages.length; index += 1) {
      const page = manifest.pages[index]
      try {
        assertSafeOfflineDownloadRoot(this.filesDir, page.localPath)
      } catch (_err) {
        return {
          comicId,
          chapterId,
          status: OfflineDownloadedChapterStatus.CORRUPT,
          manifest,
          pageCount: manifest.pageCount,
          availablePageCount,
          missingPageCount: Math.max(0, manifest.pageCount - availablePageCount),
          reasonCode: 'unsafe_page_path',
        }
      }
      if (!page.localPath.startsWith(`${chapterDir}/`) || hasTraversalSegment(pathBaseName(page.localPath))) {
        return {
          comicId,
          chapterId,
          status: OfflineDownloadedChapterStatus.CORRUPT,
          manifest,
          pageCount: manifest.pageCount,
          availablePageCount,
          missingPageCount: Math.max(0, manifest.pageCount - availablePageCount),
          reasonCode: 'outside_chapter_dir',
        }
      }
      if (page.pageIndex < 0 || page.pageIndex >= manifest.pageCount || seenIndexes.includes(page.pageIndex)) {
        return {
          comicId,
          chapterId,
          status: OfflineDownloadedChapterStatus.CORRUPT,
          manifest,
          pageCount: manifest.pageCount,
          availablePageCount,
          missingPageCount: Math.max(0, manifest.pageCount - availablePageCount),
          reasonCode: 'page_index_invalid',
        }
      }
      seenIndexes.push(page.pageIndex)
      if (fs.accessSync(page.localPath)) {
        const stat = fs.statSync(page.localPath)
        if (stat.size !== Math.max(0, Math.floor(page.size))) {
          return {
            comicId,
            chapterId,
            status: OfflineDownloadedChapterStatus.CORRUPT,
            manifest,
            pageCount: manifest.pageCount,
            availablePageCount,
            missingPageCount: Math.max(0, manifest.pageCount - availablePageCount),
            reasonCode: 'page_size_mismatch',
          }
        }
        availablePageCount += 1
      }
    }
    const missingPageCount = Math.max(0, manifest.pageCount - availablePageCount)
    if (manifest.pageCount > 0 && availablePageCount === 0) {
      return {
        comicId,
        chapterId,
        status: OfflineDownloadedChapterStatus.MISSING,
        manifest,
        pageCount: manifest.pageCount,
        availablePageCount,
        missingPageCount,
        reasonCode: 'pages_missing',
      }
    }
    return {
      comicId,
      chapterId,
      status: missingPageCount === 0 ? OfflineDownloadedChapterStatus.DOWNLOADED : OfflineDownloadedChapterStatus.PARTIAL,
      manifest,
      pageCount: manifest.pageCount,
      availablePageCount,
      missingPageCount,
      reasonCode: missingPageCount === 0 ? undefined : 'page_file_missing',
    }
  }

  loadSummary(comicId: ComicId, chapterId: string): OfflineDownloadSummary | undefined {
    const validation = this.validateDownloadedChapter(comicId, chapterId)
    if (validation.status === OfflineDownloadedChapterStatus.MISSING &&
      validation.reasonCode === 'manifest_missing') {
      return undefined
    }
    const manifest = validation.manifest
    if (validation.status === OfflineDownloadedChapterStatus.CORRUPT) {
      return {
        comicId,
        chapterId,
        pageCount: validation.pageCount,
        downloadedPageCount: validation.availablePageCount,
        status: OfflineDownloadStatus.FAILED,
        updatedAt: manifest?.updatedAt ?? 0,
      }
    }
    if (manifest === undefined) {
      return undefined
    }
    if (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
      validation.status === OfflineDownloadedChapterStatus.PARTIAL) {
      return {
        comicId: manifest.comicId,
        chapterId: manifest.chapterId,
        pageCount: validation.pageCount,
        downloadedPageCount: validation.availablePageCount,
        status: validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ?
          OfflineDownloadStatus.DOWNLOADED : OfflineDownloadStatus.PARTIAL,
        updatedAt: manifest.updatedAt,
      }
    }
    return {
      comicId: manifest.comicId,
      chapterId: manifest.chapterId,
      pageCount: manifest.pageCount,
      downloadedPageCount: manifest.downloadedPageCount,
      status: manifest.status,
      updatedAt: manifest.updatedAt,
    }
  }

  saveManifest(manifest: OfflineChapterDownloadManifest): OfflineChapterDownloadManifest {
    const chapterDir = this.chapterDir(manifest.comicId, manifest.chapterId)
    ensureDirSync(chapterDir)
    const pages = manifest.pages.slice().sort((left: OfflineDownloadedPage, right: OfflineDownloadedPage): number => {
      return left.pageIndex - right.pageIndex
    }).map((page: OfflineDownloadedPage): OfflineDownloadedPage => {
      assertSafeOfflineDownloadRoot(this.filesDir, page.localPath)
      if (!page.localPath.startsWith(`${chapterDir}/`)) {
        throw new Error('offline download page path is outside chapter dir')
      }
      return {
        pageId: page.pageId,
        pageIndex: Math.max(0, Math.floor(page.pageIndex)),
        fileName: page.fileName ?? pathBaseName(page.localPath),
        localPath: page.localPath,
        size: Math.max(0, Math.floor(page.size)),
        updatedAt: page.updatedAt,
      }
    })
    const normalized: OfflineChapterDownloadManifest = {
      schemaVersion: OFFLINE_DOWNLOAD_SCHEMA_VERSION,
      sourceKind: manifest.sourceKind,
      sourceId: manifest.sourceId,
      comicId: manifest.comicId,
      seriesId: manifest.seriesId,
      chapterId: manifest.chapterId,
      pageCount: Math.max(0, Math.floor(manifest.pageCount)),
      downloadedPageCount: pages.length,
      status: manifest.status,
      updatedAt: Date.now(),
      pages,
      integrityHash: '',
      failureReasonCode: manifest.failureReasonCode,
    }
    normalized.integrityHash = createManifestIntegrityHash(normalized)
    writeTextSync(this.manifestPath(manifest.comicId, manifest.chapterId), JSON.stringify(normalized))
    return normalized
  }

  createManifest(
    comicId: ComicId,
    chapterId: string,
    pageCount: number,
    status: OfflineDownloadStatus,
    identity?: OfflineChapterManifestIdentity
  ): OfflineChapterDownloadManifest {
    return this.saveManifest({
      schemaVersion: OFFLINE_DOWNLOAD_SCHEMA_VERSION,
      sourceKind: identity?.sourceKind,
      sourceId: identity?.sourceId,
      comicId,
      seriesId: identity?.seriesId ?? comicId,
      chapterId,
      pageCount,
      downloadedPageCount: 0,
      status,
      updatedAt: Date.now(),
      pages: [],
      integrityHash: '',
    })
  }

  recordPage(manifest: OfflineChapterDownloadManifest, page: OfflineDownloadedPage): OfflineChapterDownloadManifest {
    const pages = manifest.pages.filter((item: OfflineDownloadedPage): boolean => {
      return item.pageId !== page.pageId && item.pageIndex !== page.pageIndex
    })
    pages.push(page)
    return this.saveManifest({
      schemaVersion: OFFLINE_DOWNLOAD_SCHEMA_VERSION,
      comicId: manifest.comicId,
      chapterId: manifest.chapterId,
      pageCount: manifest.pageCount,
      downloadedPageCount: pages.length,
      status: manifest.status,
      updatedAt: Date.now(),
      pages,
      sourceKind: manifest.sourceKind,
      sourceId: manifest.sourceId,
      seriesId: manifest.seriesId,
      integrityHash: manifest.integrityHash,
      failureReasonCode: manifest.failureReasonCode,
    })
  }

  resolveDownloadedPage(comicId: ComicId, chapterId: string, pageId: string, pageIndex: number): string | undefined {
    const validation = this.validateDownloadedChapter(comicId, chapterId)
    if (validation.manifest === undefined ||
      (validation.status !== OfflineDownloadedChapterStatus.DOWNLOADED && validation.status !== OfflineDownloadedChapterStatus.PARTIAL)) {
      return undefined
    }
    const page = validation.manifest.pages.find((item: OfflineDownloadedPage): boolean => {
      return item.pageId === pageId || item.pageIndex === pageIndex
    })
    if (page === undefined) {
      return undefined
    }
    assertSafeOfflineDownloadRoot(this.filesDir, page.localPath)
    return fs.accessSync(page.localPath) ? page.localPath : undefined
  }

  async deleteChapterDownload(comicId: ComicId, chapterId: string): Promise<void> {
    const chapterDir = this.chapterDir(comicId, chapterId)
    assertSafeOfflineDownloadRoot(this.filesDir, chapterDir)
    if (!(await pathExists(chapterDir))) {
      return
    }
    const options: ListFileOptions = {
      recursion: true,
      listNum: 0,
    }
    const entries = (await fs.listFile(chapterDir, options))
      .map((entry: string): string => entry.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, ''))
      .filter((entry: string): boolean => entry.length > 0 && entry.indexOf('..') < 0)
      .sort(compareDeepestPathFirst)
    for (let index = 0; index < entries.length; index += 1) {
      const entryPath = joinOfflineDownloadPath(chapterDir, entries[index])
      assertSafeOfflineDownloadRoot(this.filesDir, entryPath)
      const stat = await fs.stat(entryPath)
      if (stat.isDirectory()) {
        await fs.rmdir(entryPath)
      } else {
        await fs.unlink(entryPath)
      }
    }
    await fs.rmdir(chapterDir)
  }

  private ensureRoot(): void {
    const root = this.rootDir
    if (this.filesDir.length === 0 || !this.filesDir.startsWith('/') || hasTraversalSegment(this.filesDir)) {
      throw new Error('unsafe offline download filesDir')
    }
    if (!fs.accessSync(root)) {
      fs.mkdirSync(root, true)
    }
  }
}
