import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { taskpool } from '@kit.ArkTS'
import {
  Chapter,
  Comic,
  Page,
  sameComicIdentity,
} from './ComicModels'
import { LibraryStore } from './LibraryStore'
import {
  LibraryStorePersistenceService,
  upsertComicAndPersistLibraryStore,
} from './LibraryPersistence'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
  sourceRuntimeEntryEnabled,
} from '../sourceRuntime/SourceRuntimeRegistry'
import { runSourceOperationFromBytes, diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { normalizeSourceImageUrl } from './SourceTextNormalizer'
import { resolveSourceChapterForResume } from './SourceChapterListResolver'

interface SourceOperationDataPayload {
  items?: Record<string, Object>[]
  pages?: Record<string, Object>[]
}

interface SourceOperationResponsePayload {
  ok?: boolean
  reasonCode?: string
  error?: Record<string, Object | string | number | boolean | null>
  data?: SourceOperationDataPayload
}

interface SourcePagesRequestArgs {
  mangaId?: string
  mangaUrl?: string
  chapterId: string
}

interface SourcePagesRequestHostHints {
  network: boolean
  imageStrategy: string
}

interface SourcePagesRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourcePagesRequestArgs
  settings: SourceSettingsRecord
  hostHints: SourcePagesRequestHostHints
}

export interface SourceChapterPageHydrationResult {
  hydrated: boolean
  pageCount: number
  reasonCode?: string
  sourceFailureReason?: string
}

/**
 * Resolves one source chapter into Reader page descriptors without touching
 * the library.  Consumers must treat the returned descriptors as one-open
 * data: hosts can issue expiring URLs or request headers, so this is never a
 * persistent page cache.
 */
export interface SourceChapterPagesResolveRequest {
  comicId: string
  sourceId: string
  mangaId?: string
  mangaUrl?: string
  chapterId: string
}

export interface SourceChapterPagesResolveResult {
  pages: Page[]
  reasonCode?: string
  sourceFailureReason?: string
}

function normalizeSourceLookupHydrationReason(reasonCode: string | undefined): string {
  if (reasonCode === 'missing_source_id' || reasonCode === 'source_id_not_registered') {
    return 'source_not_installed'
  }
  return reasonCode ?? 'source_lookup_failed'
}

@Concurrent
function executeSourceChapterPagesOperation(requestJson: string, wasmBytes: Uint8Array): string {
  const response = runSourceOperationFromBytes(requestJson, wasmBytes)
  return JSON.stringify(response)
}

function cloneWasmBytes(entry: SourceRuntimeRegistryEntry): Uint8Array {
  const copy = new Uint8Array(entry.wasmBytes.byteLength)
  copy.set(entry.wasmBytes)
  return copy
}

function optionalSourceString(value: Object | string | number | boolean | null | undefined): string | undefined {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined
  }
  return value
}

function optionalSourceNumber(value: Object | string | number | boolean | null | undefined): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (typeof value !== 'string') {
    return undefined
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : undefined
}

function sourcePageImageRecord(item: Record<string, Object>): Record<string, Object> | undefined {
  const image = item['image']
  if (image === undefined || image === null || Array.isArray(image) || typeof image !== 'object') {
    return undefined
  }
  return image as Record<string, Object>
}

function sourcePageImageUrl(item: Record<string, Object>): string | undefined {
  const directUrl = optionalSourceString(item['url']) ??
    optionalSourceString(item['uri']) ??
    optionalSourceString(item['imageUrl']) ??
    optionalSourceString(item['image_url']) ??
    optionalSourceString(item['src']) ??
    optionalSourceString(item['href'])
  if (directUrl !== undefined) {
    return normalizeSourceImageUrl(directUrl)
  }
  const imageRecord = sourcePageImageRecord(item)
  if (imageRecord === undefined) {
    return undefined
  }
  return normalizeSourceImageUrl(optionalSourceString(imageRecord['url']) ??
    optionalSourceString(imageRecord['uri']) ??
    optionalSourceString(imageRecord['src']) ??
    optionalSourceString(imageRecord['href']))
}

function sourcePageDimension(item: Record<string, Object>, key: string, alternateKey: string): number | undefined {
  const snakeKey = key === 'width' ? 'image_width' : 'image_height'
  const direct = optionalSourceNumber(item[key]) ??
    optionalSourceNumber(item[alternateKey]) ??
    optionalSourceNumber(item[snakeKey])
  if (direct !== undefined) {
    return direct
  }
  const imageRecord = sourcePageImageRecord(item)
  if (imageRecord === undefined) {
    return undefined
  }
  return optionalSourceNumber(imageRecord[key]) ??
    optionalSourceNumber(imageRecord[alternateKey]) ??
    optionalSourceNumber(imageRecord[snakeKey])
}

function sourcePageId(item: Record<string, Object>, chapterId: string, index: number): string {
  const direct = optionalSourceString(item['id']) ??
    optionalSourceString(item['pageId']) ??
    optionalSourceString(item['page_id'])
  if (direct !== undefined) {
    return direct
  }
  const imageRecord = sourcePageImageRecord(item)
  return optionalSourceString(imageRecord?.['id']) ??
    optionalSourceString(imageRecord?.['pageId']) ??
    optionalSourceString(imageRecord?.['page_id']) ??
    `${chapterId}:page:${index + 1}`
}

function pagesFromSourceRows(comicId: string, chapterId: string, rows: Record<string, Object>[]): Page[] {
  return rows.map((item: Record<string, Object>, index: number): Page => {
    const pageId = sourcePageId(item, chapterId, index)
    const page: Page = {
      id: pageId,
      comicId,
      chapterId,
      index,
      fileName: `source-page-${index + 1}`,
      uri: sourcePageImageUrl(item) ?? '',
      sortKey: `${index}`.padStart(6, '0'),
    }
    const width = sourcePageDimension(item, 'width', 'imageWidth')
    if (width !== undefined) {
      page.width = width
    }
    const height = sourcePageDimension(item, 'height', 'imageHeight')
    if (height !== undefined) {
      page.height = height
    }
    return page
  })
}

function sourceMangaIdFromComic(comic: Comic, sourceId: string): string | undefined {
  const remoteResourceId = comic.remoteResourceId?.trim()
  if (remoteResourceId !== undefined && remoteResourceId.length > 0) {
    return remoteResourceId
  }
  const prefix = `${sourceId}:`
  if (comic.id.startsWith(prefix) && comic.id.length > prefix.length) {
    return comic.id.substring(prefix.length)
  }
  return undefined
}

async function fetchSourceChapterPages(
  entry: SourceRuntimeRegistryEntry,
  request: SourceChapterPagesResolveRequest,
): Promise<SourceChapterPagesResolveResult> {
  const args: SourcePagesRequestArgs = { chapterId: request.chapterId }
  const mangaId = request.mangaId?.trim()
  if (mangaId !== undefined && mangaId.length > 0) {
    args.mangaId = mangaId
  }
  const mangaUrl = request.mangaUrl?.trim()
  if (mangaUrl !== undefined && mangaUrl.length > 0) {
    args.mangaUrl = mangaUrl
  }
  const sourceRequest: SourcePagesRequest = {
    type: 'request',
    version: 1,
    requestId: `chapter-pages-${entry.sourceId}-${Date.now()}`,
    operation: 'get_pages',
    sourceId: entry.sourceId,
    args,
    settings: appSourceSettingsStore.loadForSource(entry.sourceId),
    hostHints: { network: true, imageStrategy: 'descriptor-or-url' },
  }
  const responseJson = await diagnoseSourceOperation(JSON.stringify(sourceRequest), () => taskpool.execute(
    executeSourceChapterPagesOperation,
    JSON.stringify(sourceRequest),
    cloneWasmBytes(entry),
  ) as Promise<string>)
  const response = JSON.parse(responseJson) as SourceOperationResponsePayload
  const rows = response.data?.pages !== undefined ? response.data.pages : (response.data?.items ?? [])
  if (response.ok !== true) {
    const reason = optionalSourceString(response.reasonCode) ?? optionalSourceString(response.error?.['code'])
    // Preserve the existing download/lookup classification; only Reader consumes
    // the explicit provider category. Never forward source messages or raw errors.
    return { pages: [], reasonCode: 'source_pages_failed',
      sourceFailureReason: reason?.trim().toLowerCase() === 'unsupported' ? 'unsupported' : undefined }
  }
  if (rows.length === 0) return { pages: [], reasonCode: 'source_pages_failed' }
  return { pages: pagesFromSourceRows(request.comicId, request.chapterId, rows) }
}

export async function resolveSourceChapterPages(
  sourceRegistry: SourceRuntimeRegistry,
  request: SourceChapterPagesResolveRequest,
): Promise<SourceChapterPagesResolveResult> {
  const sourceId = request.sourceId.trim()
  const chapterId = request.chapterId.trim()
  if (sourceId.length === 0) {
    return { pages: [], reasonCode: 'source_missing' }
  }
  if (chapterId.length === 0) {
    return { pages: [], reasonCode: 'chapter_missing' }
  }
  const lookup = sourceRegistry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined) {
    return { pages: [], reasonCode: normalizeSourceLookupHydrationReason(lookup.reasonCode) }
  }
  if (!sourceRuntimeEntryEnabled(lookup.entry)) {
    return { pages: [], reasonCode: 'source_disabled' }
  }
  try {
    const resolution = await fetchSourceChapterPages(lookup.entry, {
      comicId: request.comicId,
      sourceId,
      mangaId: request.mangaId,
      mangaUrl: request.mangaUrl,
      chapterId,
    })
    if (resolution.pages.length === 0) {
      DiagnosticLogger.warn('source_chapter_page_hydrator', 'fetch_pages_failed', '[SourceChapterPages] step=fetch_pages_failed failed=true reason=source_pages_failed')
    }
    return resolution
  } catch (_error) {
    DiagnosticLogger.warn('source_chapter_page_hydrator', 'fetch_pages_failed', '[SourceChapterPages] step=fetch_pages_failed failed=true reason=source_pages_failed')
    return { pages: [], reasonCode: 'source_pages_failed' }
  }
}

export class SourceChapterPageHydrator {
  private readonly libraryStore: LibraryStore
  private readonly sourceRegistry: SourceRuntimeRegistry
  private readonly libraryPersistenceService?: LibraryStorePersistenceService
  private readonly onLibraryChanged?: () => void

  constructor(
    libraryStore: LibraryStore,
    sourceRegistry: SourceRuntimeRegistry,
    libraryPersistenceService?: LibraryStorePersistenceService,
    onLibraryChanged?: () => void,
  ) {
    this.libraryStore = libraryStore
    this.sourceRegistry = sourceRegistry
    this.libraryPersistenceService = libraryPersistenceService
    this.onLibraryChanged = onLibraryChanged
  }

  async ensureChapterDescriptor(
    comicId: string,
    chapterId: string,
    isCurrent: () => boolean,
  ): Promise<boolean> {
    const comic = this.libraryStore.getComic(comicId)
    if (comic === undefined) {
      return false
    }
    if (comic.chapters.some((chapter: Chapter): boolean => chapter.id === chapterId)) {
      return true
    }
    const sourceId = comic.sourceRuntimeId?.trim()
    if (sourceId === undefined || sourceId.length === 0) {
      return false
    }
    const mangaId = sourceMangaIdFromComic(comic, sourceId)
    const lookup = this.sourceRegistry.lookup(sourceId)
    if (mangaId === undefined || !lookup.ok || lookup.entry === undefined ||
      !sourceRuntimeEntryEnabled(lookup.entry)) {
      return false
    }
    const descriptor = await resolveSourceChapterForResume(lookup.entry, mangaId, chapterId, comic.sourcePath, isCurrent)
    const latest = this.libraryStore.getComic(comicId)
    if (descriptor === undefined || !isCurrent() || latest === undefined ||
      !sameComicIdentity(comic, latest) || latest.sourceRuntimeId !== sourceId || sourceMangaIdFromComic(latest, sourceId) !== mangaId) {
      return false
    }
    if (latest.chapters.some((chapter: Chapter): boolean => chapter.id === chapterId)) {
      return true
    }
    const now = Date.now()
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title: descriptor.title,
      index: latest.chapters.length,
      chapterNumber: descriptor.chapterNumber,
      volumeNumber: descriptor.volumeNumber,
      readingGroup: descriptor.readingGroup,
      continuationEligible: descriptor.continuationEligible,
      scanlator: descriptor.scanlator,
      language: descriptor.language,
      dateUpload: descriptor.dateUpload,
      sourcePath: `${latest.sourcePath}#${chapterId}`,
      sortKey: `${descriptor.chapterNumber ?? latest.chapters.length}`,
      pages: [],
      pageCount: 0,
      createdAt: now,
      updatedAt: now,
    }
    const updated = JSON.parse(JSON.stringify(latest)) as Comic
    updated.chapters = updated.chapters.concat([chapter])
    updated.chapterCount = updated.chapters.length
    updated.updatedAt = now
    if (this.libraryPersistenceService === undefined) {
      this.libraryStore.upsertComic(updated)
    } else {
      upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, updated)
    }
    this.onLibraryChanged?.()
    return true
  }

  async ensureChapterPages(
    comicId: string,
    sourceId: string | undefined,
    chapterId: string,
    forceRefresh: boolean = false,
  ): Promise<SourceChapterPageHydrationResult> {
    const comic = this.libraryStore.getComic(comicId)
    const chapter = comic?.chapters.find((item: Chapter): boolean => item.id === chapterId)
    if (comic === undefined || chapter === undefined) {
      return { hydrated: false, pageCount: 0, reasonCode: 'chapter_missing' }
    }
    if (chapter.pages.length > 0 && !forceRefresh) {
      return { hydrated: true, pageCount: chapter.pages.length }
    }
    const resolvedSourceId = sourceId ?? comic.sourceRuntimeId
    if (resolvedSourceId === undefined || resolvedSourceId.trim().length === 0) {
      return { hydrated: false, pageCount: 0, reasonCode: 'source_missing' }
    }
    const baselineComic = JSON.parse(JSON.stringify(comic)) as Comic
    const baselineChapter = JSON.parse(JSON.stringify(chapter)) as Chapter
    const resolution = await resolveSourceChapterPages(this.sourceRegistry, {
      comicId: comic.id,
      sourceId: resolvedSourceId,
      mangaId: sourceMangaIdFromComic(comic, resolvedSourceId),
      mangaUrl: comic.sourcePath,
      chapterId,
    })
    if (resolution.pages.length === 0) {
      return { hydrated: false, pageCount: 0, reasonCode: resolution.reasonCode ?? 'pages_missing',
        sourceFailureReason: resolution.sourceFailureReason }
    }
    return this.applyPages(baselineComic, baselineChapter, resolution.pages)
  }

  private applyPages(comic: Comic, chapter: Chapter, pages: Page[]): SourceChapterPageHydrationResult {
    const current = this.libraryStore.getComic(comic.id)
    const currentChapter = current?.chapters.find((item: Chapter): boolean => item.id === chapter.id)
    if (current === undefined || !sameComicIdentity(comic, current) || currentChapter === undefined ||
      currentChapter.createdAt !== chapter.createdAt || currentChapter.sourcePath !== chapter.sourcePath) {
      return { hydrated: false, pageCount: 0, reasonCode: 'chapter_missing' }
    }
    // A newer page plan already committed while this request was resolving owns the chapter.
    if (JSON.stringify(currentChapter.pages) !== JSON.stringify(chapter.pages)) {
      return {
        hydrated: currentChapter.pages.length > 0,
        pageCount: currentChapter.pages.length,
        reasonCode: currentChapter.pages.length > 0 ? undefined : 'pages_missing',
      }
    }
    const next = JSON.parse(JSON.stringify(current)) as Comic
    const nextChapter = next.chapters.find((item: Chapter): boolean => item.id === chapter.id) as Chapter
    nextChapter.pages = pages
    nextChapter.pageCount = pages.length
    nextChapter.updatedAt = Date.now()
    next.pageCount = next.chapters.reduce((total: number, item: Chapter): number => total + item.pageCount, 0)
    next.updatedAt = nextChapter.updatedAt
    if (this.libraryPersistenceService === undefined) {
      this.libraryStore.upsertComic(next)
    } else {
      upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, next)
    }
    if (this.onLibraryChanged !== undefined) {
      this.onLibraryChanged()
    }
    return { hydrated: true, pageCount: pages.length }
  }
}
