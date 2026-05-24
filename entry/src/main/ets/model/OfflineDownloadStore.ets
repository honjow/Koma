import { fileIo as fs } from '@kit.CoreFileKit'
import {
  ComicId,
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

export interface OfflineDownloadedPage {
  pageId: PageId
  pageIndex: number
  localPath: string
  size: number
  updatedAt: number
}

export interface OfflineChapterDownloadManifest {
  schemaVersion: number
  comicId: ComicId
  chapterId: string
  pageCount: number
  downloadedPageCount: number
  status: OfflineDownloadStatus
  updatedAt: number
  pages: OfflineDownloadedPage[]
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

function safeParseManifest(payload: string): OfflineChapterDownloadManifest {
  const parsed = JSON.parse(payload) as OfflineChapterDownloadManifest
  if (parsed.schemaVersion !== OFFLINE_DOWNLOAD_SCHEMA_VERSION || !Array.isArray(parsed.pages)) {
    throw new Error('Unsupported offline download manifest')
  }
  return parsed
}

function normalizeExtension(extension: string): string {
  const normalized = extension.toLocaleLowerCase().replace(/[^a-z0-9]/g, '')
  return normalized.length === 0 ? 'img' : normalized
}

export class OfflineDownloadStore {
  private readonly filesDir: string
  private readonly rootDir: string

  constructor(filesDir: string) {
    this.filesDir = trimTrailingSlash(filesDir)
    this.rootDir = joinOfflineDownloadPath(this.filesDir, OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
    this.ensureRoot()
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

  loadSummary(comicId: ComicId, chapterId: string): OfflineDownloadSummary | undefined {
    const manifest = this.loadManifest(comicId, chapterId)
    if (manifest === undefined) {
      return undefined
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
    const normalized: OfflineChapterDownloadManifest = {
      schemaVersion: OFFLINE_DOWNLOAD_SCHEMA_VERSION,
      comicId: manifest.comicId,
      chapterId: manifest.chapterId,
      pageCount: Math.max(0, Math.floor(manifest.pageCount)),
      downloadedPageCount: manifest.pages.length,
      status: manifest.status,
      updatedAt: Date.now(),
      pages: manifest.pages.slice().sort((left: OfflineDownloadedPage, right: OfflineDownloadedPage): number => {
        return left.pageIndex - right.pageIndex
      }),
      failureReasonCode: manifest.failureReasonCode,
    }
    writeTextSync(this.manifestPath(manifest.comicId, manifest.chapterId), JSON.stringify(normalized))
    return normalized
  }

  createManifest(comicId: ComicId, chapterId: string, pageCount: number, status: OfflineDownloadStatus): OfflineChapterDownloadManifest {
    return this.saveManifest({
      schemaVersion: OFFLINE_DOWNLOAD_SCHEMA_VERSION,
      comicId,
      chapterId,
      pageCount,
      downloadedPageCount: 0,
      status,
      updatedAt: Date.now(),
      pages: [],
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
    })
  }

  resolveDownloadedPage(comicId: ComicId, chapterId: string, pageId: string, pageIndex: number): string | undefined {
    const manifest = this.loadManifest(comicId, chapterId)
    if (manifest === undefined || manifest.status !== OfflineDownloadStatus.DOWNLOADED) {
      return undefined
    }
    const page = manifest.pages.find((item: OfflineDownloadedPage): boolean => {
      return item.pageId === pageId || item.pageIndex === pageIndex
    })
    if (page === undefined) {
      return undefined
    }
    assertSafeOfflineDownloadRoot(this.filesDir, page.localPath)
    return fs.accessSync(page.localPath) ? page.localPath : undefined
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
