import { taskpool } from '@kit.ArkTS'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  normalizeSortKey,
} from './ComicModels'
import { LibraryStore } from './LibraryStore'
import {
  LibraryStorePersistenceService,
  serializeLibraryStore,
  hydrateLibraryStoreFromJson,
} from './LibraryPersistence'
import { MangaChapterItem, parseMangaChapterFromSourceItem } from './MangaDetailModels'
import { SourceRuntimeRegistry, SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { runSourceOperationFromBytes } from '../sourceRuntime/SourceRuntimeRunner'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { AppStrings } from '../i18n/AppStrings'
import {
  KomgaBookDto,
  KomgaPageDto,
  KomgaPageImageKind,
  createKomgaChapterId,
  mapKomgaBookToChapter,
  mapKomgaPageToPage,
} from '../remote/KomgaModels'
import {
  KavitaChapterDto,
  KavitaVolumeDto,
  createKavitaChapterId,
  mapKavitaChapterToChapter,
  mapKavitaPageToPage,
} from '../remote/KavitaModels'
import {
  mapOpdsPublicationToImages,
} from '../remote/OpdsParser'
import {
  OpdsBookDto,
  OpdsImageDto,
  OpdsLink,
  OpdsLinkKind,
} from '../remote/OpdsModels'
import {
  readWebDavUrlPath,
} from '../remote/WebDavClient'
import {
  DavComicCandidateKind,
  DavResource,
} from '../remote/WebDavModels'
import { RemoteServerStore } from './RemoteServerStore'
import { compareNaturalPath } from '../import/ImageSortUtils'
import {
  LocalLibraryRefreshComicResult,
  LocalLibraryRefreshService,
} from './LocalLibraryRefreshService'

export type LibraryUpdateResultStatus = 'unchanged' | 'updated' | 'skipped' | 'failed'
export type LibraryUpdateProviderKind = 'source_runtime' | 'local' | 'komga' | 'kavita' | 'opds' | 'webdav' | 'private_library' | 'unsupported'

export interface LibraryUpdateComicResult {
  comicId: string
  providerKind: LibraryUpdateProviderKind
  sourceKey: string
  status: LibraryUpdateResultStatus
  previousChapterCount: number
  newChapterCount: number
  message: string
}

export interface LibraryUpdateProviderSummary {
  providerKind: LibraryUpdateProviderKind
  sourceKey: string
  totalCount: number
  updatedCount: number
  unchangedCount: number
  skippedCount: number
  failedCount: number
  newChapterCount: number
  failureCodes: string[]
}

export interface LibraryUpdateSummary {
  checkedAt: number
  totalCount: number
  updatedCount: number
  unchangedCount: number
  skippedCount: number
  failedCount: number
  providerSummaries: LibraryUpdateProviderSummary[]
  results: LibraryUpdateComicResult[]
}

interface SourceOperationDataPayload {
  items?: Record<string, Object>[]
  chapters?: Record<string, Object>[]
  page?: SourceRuntimePagePayload
  hasNextPage?: boolean
  hasMore?: boolean
  has_more?: boolean
}

interface SourceRuntimePagePayload {
  hasMore?: boolean
  hasNextPage?: boolean
  has_more?: boolean
  nextCursor?: string | null
  next_cursor?: string | null
}

interface SourceOperationResponsePayload {
  ok?: boolean
  data?: SourceOperationDataPayload
  reasonCode?: string
}

interface SourceChaptersPageArg {
  cursor: string | null
  limit: number
}

interface SourceChaptersRequestArgs {
  mangaId: string
  page: SourceChaptersPageArg
}

interface SourceDetailRequestHostHints {
  network: boolean
}

interface SourceDetailRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceChaptersRequestArgs
  settings: SourceSettingsRecord
  hostHints: SourceDetailRequestHostHints
}

@Concurrent
function executeLibraryUpdateSourceOperation(requestJson: string, wasmBytes: Uint8Array): string {
  const response = runSourceOperationFromBytes(requestJson, wasmBytes)
  return JSON.stringify(response)
}

function cloneWasmBytes(entry: SourceRuntimeRegistryEntry): Uint8Array {
  const copy = new Uint8Array(entry.wasmBytes.byteLength)
  copy.set(entry.wasmBytes)
  return copy
}

const SOURCE_UPDATE_CHAPTER_PAGE_SIZE: number = 100
const SOURCE_UPDATE_CHAPTER_MAX_PAGES: number = 20

function sourceChapterResponseItems(response: SourceOperationResponsePayload): Record<string, Object>[] {
  if (response.data?.items !== undefined) {
    return response.data.items
  }
  return response.data?.chapters ?? []
}

function sourcePageNextCursor(response: SourceOperationResponsePayload): string | undefined {
  const nextCursor = response.data?.page?.nextCursor ?? response.data?.page?.next_cursor
  return nextCursor === null || nextCursor === undefined || nextCursor.trim().length === 0 ? undefined : nextCursor
}

function sourcePageHasMore(response: SourceOperationResponsePayload, nextCursor: string | undefined): boolean {
  return response.data?.hasNextPage === true ||
    response.data?.hasMore === true ||
    response.data?.has_more === true ||
    response.data?.page?.hasMore === true ||
    response.data?.page?.hasNextPage === true ||
    response.data?.page?.has_more === true ||
    nextCursor !== undefined
}

function sourceMangaIdFromComic(comic: Comic): string | undefined {
  const sourceRuntimeId = comic.sourceRuntimeId
  if (sourceRuntimeId === undefined || sourceRuntimeId.trim().length === 0) {
    return undefined
  }
  const prefix = `${sourceRuntimeId}:`
  if (comic.id.startsWith(prefix) && comic.id.length > prefix.length) {
    return comic.id.substring(prefix.length)
  }
  return undefined
}

function chapterSortKey(chapter: MangaChapterItem, index: number): string {
  if (chapter.chapterNumber !== undefined) {
    return `${chapter.chapterNumber}`
  }
  if (chapter.volumeNumber !== undefined && chapter.volumeNumber.length > 0) {
    return `${chapter.volumeNumber}:${index}`
  }
  return `${index}`
}

function mergeSourceChapters(comic: Comic, remoteChapters: MangaChapterItem[], now: number): Chapter[] {
  const existingById = new Map<string, Chapter>()
  comic.chapters.forEach((chapter: Chapter) => {
    existingById.set(chapter.id, chapter)
  })
  return remoteChapters.map((remote: MangaChapterItem, index: number): Chapter => {
    const existing = existingById.get(remote.id)
    if (existing !== undefined) {
      return {
        id: existing.id,
        comicId: comic.id,
        title: remote.title.length > 0 ? remote.title : existing.title,
        index,
        scanlator: remote.scanlator ?? existing.scanlator,
        language: remote.language ?? existing.language,
        dateUpload: remote.dateUpload ?? existing.dateUpload,
        sourcePath: existing.sourcePath,
        sortKey: chapterSortKey(remote, index),
        pages: existing.pages,
        pageCount: existing.pageCount,
        createdAt: existing.createdAt,
        updatedAt: now,
      }
    }
    return {
      id: remote.id,
      comicId: comic.id,
      title: remote.title.length > 0
        ? remote.title
        : AppStrings.get('library_update_chapter_fallback_title').replace('%s', `${index + 1}`),
      index,
      scanlator: remote.scanlator,
      language: remote.language,
      dateUpload: remote.dateUpload,
      sourcePath: `${comic.sourcePath}#${remote.id}`,
      sortKey: chapterSortKey(remote, index),
      pages: [],
      pageCount: 0,
      createdAt: now,
      updatedAt: now,
    }
  })
}

function updatedComicWithChapters(comic: Comic, chapters: Chapter[], now: number): Comic {
  const nextComic: Comic = {
    id: comic.id,
    title: comic.title,
    sourceKind: comic.sourceKind,
    sourcePath: comic.sourcePath,
    sortTitle: normalizeSortKey(comic.title),
    preferredDirection: comic.preferredDirection,
    chapters,
    chapterCount: chapters.length,
    pageCount: chapters.reduce((total: number, chapter: Chapter): number => total + chapter.pageCount, 0),
    createdAt: comic.createdAt,
    updatedAt: now,
    lastImportedAt: comic.lastImportedAt,
  }
  if (comic.subtitle !== undefined) {
    nextComic.subtitle = comic.subtitle
  }
  if (comic.author !== undefined) {
    nextComic.author = comic.author
  }
  if (comic.categoryIds !== undefined) {
    nextComic.categoryIds = comic.categoryIds
  }
  if (comic.sourceRuntimeId !== undefined) {
    nextComic.sourceRuntimeId = comic.sourceRuntimeId
  }
  if (comic.remoteServerId !== undefined) {
    nextComic.remoteServerId = comic.remoteServerId
  }
  if (comic.remoteResourceId !== undefined) {
    nextComic.remoteResourceId = comic.remoteResourceId
  }
  if (comic.coverUri !== undefined) {
    nextComic.coverUri = comic.coverUri
  }
  if (comic.localMetadata !== undefined) {
    nextComic.localMetadata = comic.localMetadata
  }
  return nextComic
}

function summarizeResults(checkedAt: number, results: LibraryUpdateComicResult[]): LibraryUpdateSummary {
  const providerSummaries = summarizeLibraryUpdateProviders(results)
  return {
    checkedAt,
    totalCount: results.length,
    updatedCount: results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'updated').length,
    unchangedCount: results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'unchanged').length,
    skippedCount: results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'skipped').length,
    failedCount: results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'failed').length,
    providerSummaries,
    results,
  }
}

export function countLibraryUpdateNewChapters(summary: LibraryUpdateSummary): number {
  return summary.results.reduce((total: number, result: LibraryUpdateComicResult): number => {
    if (result.status !== 'updated') {
      return total
    }
    return total + Math.max(result.newChapterCount - result.previousChapterCount, 0)
  }, 0)
}

export function summarizeLibraryUpdateProviders(results: LibraryUpdateComicResult[]): LibraryUpdateProviderSummary[] {
  const summaries: LibraryUpdateProviderSummary[] = []
  results.forEach((result: LibraryUpdateComicResult) => {
    let summary = summaries.find((item: LibraryUpdateProviderSummary): boolean =>
      item.providerKind === result.providerKind && item.sourceKey === result.sourceKey)
    if (summary === undefined) {
      summary = {
        providerKind: result.providerKind,
        sourceKey: result.sourceKey,
        totalCount: 0,
        updatedCount: 0,
        unchangedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        newChapterCount: 0,
        failureCodes: [],
      }
      summaries.push(summary)
    }
    summary.totalCount += 1
    if (result.status === 'updated') {
      summary.updatedCount += 1
      summary.newChapterCount += Math.max(result.newChapterCount - result.previousChapterCount, 0)
    } else if (result.status === 'unchanged') {
      summary.unchangedCount += 1
    } else if (result.status === 'skipped') {
      summary.skippedCount += 1
    } else {
      summary.failedCount += 1
      const code = safeLibraryUpdateFailureCode(result.message)
      if (!summary.failureCodes.includes(code)) {
        summary.failureCodes.push(code)
      }
    }
  })
  return summaries
}

export function formatLibraryUpdateSummary(summary?: LibraryUpdateSummary): string {
  if (summary === undefined) {
    return AppStrings.get('library_update_not_checked')
  }
  return `${summary.totalCount} ${AppStrings.get('library_unit_books')} · ` +
    `${countLibraryUpdateNewChapters(summary)} ${AppStrings.get('library_unit_new_chapters')} · ` +
    `${summary.updatedCount} ${AppStrings.get('library_unit_updated')} · ` +
    `${summary.skippedCount} ${AppStrings.get('library_unit_skipped')} · ` +
    `${summary.failedCount} ${AppStrings.get('library_unit_failed')}`
}

function safeLibraryUpdateFailureCode(value: string | undefined): string {
  if (value === undefined) {
    return 'source_runtime_error'
  }
  const trimmed = value.trim().toLocaleLowerCase()
  if (trimmed.length === 0) {
    return 'source_runtime_error'
  }
  if (/timeout|timed\s*out|deadline|etimedout/.test(trimmed)) {
    return 'timeout'
  }
  if (/storage|database|disk|quota|file|cache|path|directory|(^|\s)\/[^\s]+|(^|\s)[a-z]:[\\/]|enoent|eacces/.test(trimmed)) {
    return 'storage_error'
  }
  if (/auth|unauthori[sz]ed|forbidden|permission|login|credential|tok(?:en)?|api[_\s-]?key|secret|401|403/.test(trimmed)) {
    return 'auth_error'
  }
  if (/network|fetch|http|https|dns|socket|connection|econn|enotfound|eai_again|ssl|tls|remote/.test(trimmed)) {
    return 'network_error'
  }
  if (/source|runtime|wasm|provider|plugin|script|exception|unavailable/.test(trimmed)) {
    return 'source_runtime_error'
  }
  return 'unknown'
}

function safeLibraryUpdateSourceKey(value: string | undefined): string {
  if (value === undefined || value.trim().length === 0) {
    return 'source:unknown'
  }
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return `source:${(hash >>> 0).toString(36)}`
}

function createLibraryUpdateStableHash(value: string): string {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return (hash >>> 0).toString(36)
}

function providerKindForComic(comic: Comic): LibraryUpdateProviderKind {
  if (comic.sourceRuntimeId !== undefined && comic.sourceRuntimeId.trim().length > 0) {
    return 'source_runtime'
  }
  if (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
    return 'local'
  }
  if (comic.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
    return 'komga'
  }
  if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
    return 'kavita'
  }
  if (comic.sourceKind === ComicSourceKind.OPDS_REMOTE) {
    return 'opds'
  }
  if (comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE) {
    return 'webdav'
  }
  if (comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY) {
    return 'private_library'
  }
  return 'unsupported'
}

function sourceKeyForComic(comic: Comic): string {
  if (comic.sourceRuntimeId !== undefined && comic.sourceRuntimeId.trim().length > 0) {
    return safeLibraryUpdateSourceKey(comic.sourceRuntimeId)
  }
  if (comic.remoteServerId !== undefined && comic.remoteServerId.trim().length > 0) {
    return safeLibraryUpdateSourceKey(comic.remoteServerId)
  }
  return providerKindForComic(comic)
}

export class LibraryUpdateService {
  private libraryStore: LibraryStore
  private sourceRegistry: SourceRuntimeRegistry
  private persistenceService?: LibraryStorePersistenceService
  private remoteServerStore?: RemoteServerStore

  constructor(
    libraryStore: LibraryStore,
    sourceRegistry: SourceRuntimeRegistry,
    persistenceService?: LibraryStorePersistenceService,
    remoteServerStore?: RemoteServerStore,
  ) {
    this.libraryStore = libraryStore
    this.sourceRegistry = sourceRegistry
    this.persistenceService = persistenceService
    this.remoteServerStore = remoteServerStore
  }

  async checkLibraryUpdates(): Promise<LibraryUpdateSummary> {
    const checkedAt = Date.now()
    const comics = this.libraryStore.listComics()
    const results: LibraryUpdateComicResult[] = []
    let changed = false
    const previousPayload = this.persistenceService === undefined ? undefined : serializeLibraryStore(this.libraryStore)
    console.info(`[LibraryUpdate] step=start total=${comics.length}`)
    for (let index = 0; index < comics.length; index += 1) {
      const result = await this.checkComic(comics[index])
      if (result.status === 'updated') {
        changed = true
      }
      results.push(result)
    }
    if (changed && this.persistenceService !== undefined) {
      try {
        this.persistenceService.persist()
      } catch (error) {
        if (previousPayload !== undefined) {
          hydrateLibraryStoreFromJson(this.libraryStore, previousPayload)
        }
        const e = error as Error
        throw new Error(e.message)
      }
    }
    const summary = summarizeResults(checkedAt, results)
    console.info(`[LibraryUpdate] step=done total=${summary.totalCount} updated=${summary.updatedCount} unchanged=${summary.unchangedCount} skipped=${summary.skippedCount} failed=${summary.failedCount}`)
    return summary
  }

  private async checkComic(comic: Comic): Promise<LibraryUpdateComicResult> {
    const previousChapterCount = comic.chapters.length > 0 ? comic.chapters.length : comic.chapterCount
    if (comic.sourceRuntimeId !== undefined && comic.sourceRuntimeId.trim().length > 0) {
      return this.checkSourceRuntimeComic(comic, previousChapterCount)
    }
    if (comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
      return this.checkLocalLibraryComic(comic, previousChapterCount)
    }
    if (comic.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
      return this.checkKomgaComic(comic, previousChapterCount)
    }
    if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
      return this.checkKavitaComic(comic, previousChapterCount)
    }
    if (comic.sourceKind === ComicSourceKind.OPDS_REMOTE) {
      return this.checkOpdsComic(comic, previousChapterCount)
    }
    if (comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE) {
      return this.checkWebDavComic(comic, previousChapterCount)
    }
    if (comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_remote_library_unsupported'))
    }
    return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_source_kind_unsupported'))
  }

  private checkLocalLibraryComic(comic: Comic, previousChapterCount: number): LibraryUpdateComicResult {
    const result: LocalLibraryRefreshComicResult =
      new LocalLibraryRefreshService(this.libraryStore).checkLocalComicRefresh(comic)
    if (result.status === 'unchanged') {
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'unchanged',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: result.message,
      }
    }
    return this.skippedResult(comic, previousChapterCount, result.message)
  }

  private async checkSourceRuntimeComic(comic: Comic, previousChapterCount: number): Promise<LibraryUpdateComicResult> {
    const sourceRuntimeId = comic.sourceRuntimeId as string
    const mangaId = sourceMangaIdFromComic(comic)
    if (mangaId === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_missing_source_manga_id'))
    }
    const lookup = this.sourceRegistry.lookup(sourceRuntimeId)
    if (!lookup.ok || lookup.entry === undefined) {
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'failed',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: safeLibraryUpdateFailureCode(lookup.reasonCode ?? 'source_unavailable'),
      }
    }
    try {
      const remoteChapters = await this.fetchSourceRuntimeChapters(lookup.entry, mangaId)
      const remoteIds = remoteChapters.map((chapter: MangaChapterItem): string => chapter.id)
      const localIds = comic.chapters.map((chapter: Chapter): string => chapter.id)
      const hasNewId = remoteIds.some((chapterId: string): boolean => !localIds.includes(chapterId))
      if (remoteChapters.length <= previousChapterCount && !hasNewId) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'unchanged',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: AppStrings.get('library_update_no_new_chapters'),
        }
      }
      const now = Date.now()
      const mergedChapters = mergeSourceChapters(comic, remoteChapters, now)
      this.libraryStore.upsertComic(updatedComicWithChapters(comic, mergedChapters, now))
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'updated',
        previousChapterCount,
        newChapterCount: mergedChapters.length,
        message: AppStrings.get('library_update_found_new_chapters')
          .replace('%s', `${Math.max(mergedChapters.length - previousChapterCount, 0)}`),
      }
    } catch (error) {
      const e = error as Error
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'failed',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: safeLibraryUpdateFailureCode(e.message),
      }
    }
  }

  private async fetchSourceRuntimeChapters(entry: SourceRuntimeRegistryEntry, mangaId: string): Promise<MangaChapterItem[]> {
    const chapters: MangaChapterItem[] = []
    let cursor: string | null = null
    for (let pageIndex = 1; pageIndex <= SOURCE_UPDATE_CHAPTER_MAX_PAGES; pageIndex += 1) {
      const response = await this.fetchSourceRuntimeChapterPage(entry, mangaId, cursor)
      const rows = sourceChapterResponseItems(response)
      rows.forEach((row: Record<string, Object>) => {
        chapters.push(parseMangaChapterFromSourceItem(row))
      })
      const nextCursor = sourcePageNextCursor(response)
      if (!sourcePageHasMore(response, nextCursor)) {
        break
      }
      cursor = nextCursor ?? `${pageIndex + 1}`
    }
    return chapters
  }

  private async fetchSourceRuntimeChapterPage(
    entry: SourceRuntimeRegistryEntry,
    mangaId: string,
    cursor: string | null,
  ): Promise<SourceOperationResponsePayload> {
    const request: SourceDetailRequest = {
      type: 'request',
      version: 1,
      requestId: `library-update-get_chapters-${entry.sourceId}-${Date.now()}`,
      operation: 'get_chapters',
      sourceId: entry.sourceId,
      args: {
        mangaId,
        page: {
          cursor,
          limit: SOURCE_UPDATE_CHAPTER_PAGE_SIZE,
        },
      },
      settings: appSourceSettingsStore.loadForSource(entry.sourceId),
      hostHints: { network: true },
    }
    const responseJson = await taskpool.execute(
      executeLibraryUpdateSourceOperation,
      JSON.stringify(request),
      cloneWasmBytes(entry)
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    if (response.ok !== true) {
      throw new Error(response.reasonCode ?? 'get_chapters_failed')
    }
    return response
  }

  private async checkKomgaComic(comic: Comic, previousChapterCount: number): Promise<LibraryUpdateComicResult> {
    const remoteServerStore = this.remoteServerStore
    if (remoteServerStore === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_remote_library_unsupported'))
    }
    const seriesId = this.komgaSeriesIdForComic(comic)
    if (seriesId === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_missing_remote_resource_id'))
    }
    try {
      const record = await remoteServerStore.loadKomga()
      if (record === undefined || (comic.remoteServerId !== undefined && record.server.id !== comic.remoteServerId)) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'failed',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: safeLibraryUpdateFailureCode('server_unavailable'),
        }
      }
      const client = remoteServerStore.createKomgaClient(record)
      const response = await client.listBooks({
        page: 0,
        size: 100,
        seriesIds: [seriesId],
        sort: ['metadata.numberSort,asc'],
      })
      const books = response.content.filter((book: KomgaBookDto): boolean => book.seriesId === seriesId)
      const remoteIds = books.map((book: KomgaBookDto): string => createKomgaChapterId(record.server.id, book.id))
      const localIds = comic.chapters.map((chapter: Chapter): string => chapter.id)
      const hasNewId = remoteIds.some((chapterId: string): boolean => !localIds.includes(chapterId))
      if (books.length <= previousChapterCount && !hasNewId) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'unchanged',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: AppStrings.get('library_update_no_new_chapters'),
        }
      }
      const now = Date.now()
      const chapters: Chapter[] = []
      for (let index = 0; index < books.length; index += 1) {
        const book = books[index]
        const chapterId = createKomgaChapterId(record.server.id, book.id)
        const existing = comic.chapters.find((chapter: Chapter): boolean => chapter.id === chapterId)
        if (existing !== undefined && existing.pages.length > 0) {
          chapters.push(mapKomgaBookToChapter(record.server.id, book, comic.id, existing.pages, index, now))
          continue
        }
        const pageDtos = await client.listBookPages(book.id)
        const pages = pageDtos.map((page: KomgaPageDto) => {
          const mapped = mapKomgaPageToPage(record.server.id, book.id, comic.id, chapterId, page)
          mapped.uri = client.getPageImageUrl(book.id, page.number, KomgaPageImageKind.STREAM)
          return mapped
        })
        chapters.push(mapKomgaBookToChapter(record.server.id, book, comic.id, pages, index, now))
      }
      this.libraryStore.upsertComic(updatedComicWithChapters(comic, chapters, now))
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'updated',
        previousChapterCount,
        newChapterCount: chapters.length,
        message: AppStrings.get('library_update_found_new_chapters')
          .replace('%s', `${Math.max(chapters.length - previousChapterCount, 0)}`),
      }
    } catch (error) {
      const e = error as Error
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'failed',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: safeLibraryUpdateFailureCode(e.message),
      }
    }
  }

  private komgaSeriesIdForComic(comic: Comic): string | undefined {
    if (comic.remoteResourceId !== undefined && comic.remoteResourceId.trim().length > 0) {
      return comic.remoteResourceId
    }
    const marker = ':series:'
    const markerIndex = comic.id.indexOf(marker)
    if (markerIndex >= 0 && comic.id.length > markerIndex + marker.length) {
      return comic.id.substring(markerIndex + marker.length)
    }
    return undefined
  }

  private kavitaSeriesIdForComic(comic: Comic): number | undefined {
    let raw = ''
    if (comic.remoteResourceId !== undefined && comic.remoteResourceId.trim().length > 0) {
      raw = comic.remoteResourceId
    } else {
      const marker = ':series:'
      const markerIndex = comic.id.indexOf(marker)
      if (markerIndex >= 0 && comic.id.length > markerIndex + marker.length) {
        raw = comic.id.substring(markerIndex + marker.length)
      }
    }
    const parsed = Number.parseInt(raw, 10)
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return undefined
    }
    return parsed
  }

  private kavitaVolumeChapters(volumes: KavitaVolumeDto[]): KavitaChapterDto[] {
    const chapters: KavitaChapterDto[] = []
    volumes.forEach((volume: KavitaVolumeDto) => {
      if (volume.chapters !== undefined) {
        volume.chapters.forEach((chapter: KavitaChapterDto) => {
          if (chapters.find((item: KavitaChapterDto): boolean => item.id === chapter.id) === undefined) {
            chapters.push(chapter)
          }
        })
      }
    })
    return chapters.sort((left: KavitaChapterDto, right: KavitaChapterDto): number => {
      const leftIndex = left.sortOrder === undefined ? left.minNumber === undefined ? left.id : left.minNumber : left.sortOrder
      const rightIndex = right.sortOrder === undefined ? right.minNumber === undefined ? right.id : right.minNumber : right.sortOrder
      return leftIndex - rightIndex
    })
  }

  private async checkKavitaComic(comic: Comic, previousChapterCount: number): Promise<LibraryUpdateComicResult> {
    const remoteServerStore = this.remoteServerStore
    if (remoteServerStore === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_remote_library_unsupported'))
    }
    const seriesId = this.kavitaSeriesIdForComic(comic)
    if (seriesId === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_missing_remote_resource_id'))
    }
    try {
      const record = await remoteServerStore.loadKavita()
      if (record === undefined || (comic.remoteServerId !== undefined && record.server.id !== comic.remoteServerId)) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'failed',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: safeLibraryUpdateFailureCode('server_unavailable'),
        }
      }
      const client = remoteServerStore.createKavitaClient(record)
      const chapterDtos = this.kavitaVolumeChapters(await client.listVolumes(seriesId))
      const remoteIds = chapterDtos.map((chapter: KavitaChapterDto): string => createKavitaChapterId(record.server.id, chapter.id))
      const localIds = comic.chapters.map((chapter: Chapter): string => chapter.id)
      const hasNewId = remoteIds.some((chapterId: string): boolean => !localIds.includes(chapterId))
      if (chapterDtos.length <= previousChapterCount && !hasNewId) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'unchanged',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: AppStrings.get('library_update_no_new_chapters'),
        }
      }
      const now = Date.now()
      const chapters: Chapter[] = []
      for (let index = 0; index < chapterDtos.length; index += 1) {
        const chapterDto = chapterDtos[index]
        const chapterId = createKavitaChapterId(record.server.id, chapterDto.id)
        const existing = comic.chapters.find((chapter: Chapter): boolean => chapter.id === chapterId)
        if (existing !== undefined && existing.pages.length > 0) {
          chapters.push(mapKavitaChapterToChapter(record.server.id, chapterDto, comic.id, existing.pages, undefined, now))
          continue
        }
        const pageCount = chapterDto.pages === undefined ? 0 : chapterDto.pages
        const pages: Page[] = []
        for (let pageIndex = 0; pageIndex < pageCount; pageIndex += 1) {
          pages.push(mapKavitaPageToPage(
            record.server.id,
            chapterDto.id,
            comic.id,
            chapterId,
            pageIndex,
            client.buildReaderImageUrl(chapterDto.id, pageIndex),
          ))
        }
        chapters.push(mapKavitaChapterToChapter(record.server.id, chapterDto, comic.id, pages, undefined, now))
      }
      this.libraryStore.upsertComic(updatedComicWithChapters(comic, chapters, now))
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'updated',
        previousChapterCount,
        newChapterCount: chapters.length,
        message: AppStrings.get('library_update_found_new_chapters')
          .replace('%s', `${Math.max(chapters.length - previousChapterCount, 0)}`),
      }
    } catch (error) {
      const e = error as Error
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'failed',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: safeLibraryUpdateFailureCode(e.message),
      }
    }
  }

  private async checkOpdsComic(comic: Comic, previousChapterCount: number): Promise<LibraryUpdateComicResult> {
    const remoteServerStore = this.remoteServerStore
    if (remoteServerStore === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_remote_library_unsupported'))
    }
    if (comic.remoteResourceId === undefined || comic.remoteResourceId.trim().length === 0) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_missing_remote_resource_id'))
    }
    try {
      const record = await remoteServerStore.loadOpds()
      if (record === undefined || (comic.remoteServerId !== undefined && record.server.id !== comic.remoteServerId)) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'failed',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: safeLibraryUpdateFailureCode('server_unavailable'),
        }
      }
      const client = remoteServerStore.createOpdsClient(record)
      const catalog = await client.fetchCatalog(comic.sourcePath)
      const publication = catalog.publications.find((item: OpdsBookDto): boolean => item.id === comic.remoteResourceId)
      if (publication === undefined) {
        return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_missing_remote_resource_id'))
      }
      let images = mapOpdsPublicationToImages(publication)
      const manifestLink = this.findOpdsManifestLink(publication)
      if (manifestLink !== undefined) {
        const manifestImages = await client.fetchPublicationImages(manifestLink.href)
        if (manifestImages.length > 0) {
          images = manifestImages
        }
      }
      if (images.length === 0) {
        return this.skippedResult(comic, previousChapterCount, AppStrings.get('opds_no_direct_images'))
      }
      const existingChapter = comic.chapters.length > 0 ? comic.chapters[0] : undefined
      const chapterId = existingChapter?.id ?? `opds:${record.server.id}:chapter:${createLibraryUpdateStableHash(publication.id + catalog.feedUrl)}`
      const pages = images.map((image: OpdsImageDto, index: number): Page => {
        const name = image.title === undefined || image.title.length === 0 ? `page-${index + 1}` : image.title
        return {
          id: `${chapterId}:page:${index + 1}`,
          comicId: comic.id,
          chapterId,
          index,
          fileName: name,
          uri: image.href,
          sortKey: normalizeSortKey(name),
        }
      })
      const now = Date.now()
      const chapter: Chapter = {
        id: chapterId,
        comicId: comic.id,
        title: publication.title,
        index: 0,
        sourcePath: catalog.feedUrl,
        sortKey: normalizeSortKey(publication.title),
        pages,
        pageCount: pages.length,
        createdAt: existingChapter?.createdAt ?? now,
        updatedAt: now,
      }
      if (existingChapter !== undefined &&
        existingChapter.pageCount === pages.length &&
        existingChapter.title === publication.title &&
        existingChapter.pages.every((page: Page, index: number): boolean => page.uri === pages[index]?.uri)) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'unchanged',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: AppStrings.get('library_update_no_new_chapters'),
        }
      }
      this.libraryStore.upsertComic(updatedComicWithChapters(comic, [chapter], now))
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'updated',
        previousChapterCount,
        newChapterCount: 1,
        message: AppStrings.get('library_update_found_new_chapters')
          .replace('%s', `${Math.max(1 - previousChapterCount, 0)}`),
      }
    } catch (error) {
      const e = error as Error
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'failed',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: safeLibraryUpdateFailureCode(e.message),
      }
    }
  }

  private findOpdsManifestLink(publication: OpdsBookDto): OpdsLink | undefined {
    return publication.links.find((link: OpdsLink): boolean => {
      const type = link.type === undefined ? '' : link.type.toLocaleLowerCase()
      return link.kind === OpdsLinkKind.SELF &&
        (type.indexOf('json') >= 0 || type.indexOf('divina') >= 0 || type.indexOf('webpub') >= 0)
    })
  }

  private async checkWebDavComic(comic: Comic, previousChapterCount: number): Promise<LibraryUpdateComicResult> {
    const remoteServerStore = this.remoteServerStore
    if (remoteServerStore === undefined) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_remote_library_unsupported'))
    }
    if (comic.remoteResourceId === undefined || comic.remoteResourceId.trim().length === 0) {
      return this.skippedResult(comic, previousChapterCount, AppStrings.get('library_update_skip_missing_remote_resource_id'))
    }
    try {
      const record = await remoteServerStore.loadWebDav()
      if (record === undefined || (comic.remoteServerId !== undefined && record.server.id !== comic.remoteServerId)) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'failed',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: safeLibraryUpdateFailureCode('server_unavailable'),
        }
      }
      const client = remoteServerStore.createWebDavClient(record)
      const pathSegments = this.webDavPathSegmentsForComic(client.buildUrl([]), comic.remoteResourceId)
      const resources = await client.propfind(pathSegments, 1)
      const images = resources
        .filter((resource: DavResource): boolean => {
          return !resource.isCollection && resource.candidateKind === DavComicCandidateKind.IMAGE_FILE
        })
        .sort((left: DavResource, right: DavResource): number => compareNaturalPath(this.webDavResourceName(left), this.webDavResourceName(right)))
      if (images.length === 0) {
        return this.skippedResult(comic, previousChapterCount, AppStrings.get('common_no_images_to_add'))
      }
      const existingChapter = comic.chapters.length > 0 ? comic.chapters[0] : undefined
      const directoryUrl = client.buildUrl(pathSegments)
      const chapterId = existingChapter?.id ?? `webdav:${record.server.id}:chapter:${createLibraryUpdateStableHash(directoryUrl)}`
      const pages = images.map((resource: DavResource, index: number): Page => {
        const name = this.webDavResourceName(resource)
        return {
          id: `${chapterId}:page:${index + 1}`,
          comicId: comic.id,
          chapterId,
          index,
          fileName: name,
          uri: client.getResourceUrl(resource),
          sortKey: normalizeSortKey(name),
          byteSize: resource.contentLength,
        }
      })
      const now = Date.now()
      const chapter: Chapter = {
        id: chapterId,
        comicId: comic.id,
        title: comic.title,
        index: 0,
        sourcePath: directoryUrl,
        sortKey: normalizeSortKey(comic.title),
        pages,
        pageCount: pages.length,
        createdAt: existingChapter?.createdAt ?? now,
        updatedAt: now,
      }
      if (existingChapter !== undefined &&
        existingChapter.pageCount === pages.length &&
        existingChapter.pages.every((page: Page, index: number): boolean => page.uri === pages[index]?.uri)) {
        return {
          comicId: comic.id,
          providerKind: providerKindForComic(comic),
          sourceKey: sourceKeyForComic(comic),
          status: 'unchanged',
          previousChapterCount,
          newChapterCount: previousChapterCount,
          message: AppStrings.get('library_update_no_new_chapters'),
        }
      }
      this.libraryStore.upsertComic(updatedComicWithChapters(comic, [chapter], now))
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'updated',
        previousChapterCount,
        newChapterCount: 1,
        message: AppStrings.get('library_update_found_new_chapters')
          .replace('%s', `${Math.max(1 - previousChapterCount, 0)}`),
      }
    } catch (error) {
      const e = error as Error
      return {
        comicId: comic.id,
        providerKind: providerKindForComic(comic),
        sourceKey: sourceKeyForComic(comic),
        status: 'failed',
        previousChapterCount,
        newChapterCount: previousChapterCount,
        message: safeLibraryUpdateFailureCode(e.message),
      }
    }
  }

  private webDavPathSegmentsForComic(rootUrl: string, resourceUrl: string): string[] {
    const rootPath = readWebDavUrlPath(rootUrl).replace(/\/+$/, '')
    const resourcePath = readWebDavUrlPath(resourceUrl).replace(/\/+$/, '')
    if (resourcePath.length <= rootPath.length || !resourcePath.startsWith(rootPath)) {
      return []
    }
    return resourcePath
      .substring(rootPath.length)
      .split('/')
      .filter((segment: string): boolean => segment.length > 0)
      .map((segment: string): string => decodeURIComponent(segment))
  }

  private webDavResourceName(resource: DavResource): string {
    if (resource.displayname !== undefined && resource.displayname.length > 0) {
      return resource.displayname
    }
    const path = readWebDavUrlPath(resource.href)
    const trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path
    const name = trimmed.split('/').pop()
    return name === undefined || name.length === 0 ? resource.href : decodeURIComponent(name)
  }

  private skippedResult(comic: Comic, previousChapterCount: number, message: string): LibraryUpdateComicResult {
    return {
      comicId: comic.id,
      providerKind: providerKindForComic(comic),
      sourceKey: sourceKeyForComic(comic),
      status: 'skipped',
      previousChapterCount,
      newChapterCount: previousChapterCount,
      message,
    }
  }
}
