import { sourceRequestWithHostFeatures } from '../sourceRuntime/SourceHostFeatures'
import { configureSourceRequestPolicy } from '../sourceRuntime/SourceRequestPolicy'
import { sourceSettingsFingerprint } from '../sourceRuntime/SourceSettingsIdentity'
import { sourceTextPage, sourceTextPageRequest } from './SourceTextPageDescriptor'
import { cacheSourceTextPageImage } from './ReaderPageSourceAdapter'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
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
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { executeSourceRequestInWorker as executeSourceChapterPagesOperation } from '../sourceRuntime/SourceRuntimeWorkerClient'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { normalizeSourceImageUrl } from './SourceTextNormalizer'
import { resolveSourceChapterForResume, resolveSourceChapterList } from './SourceChapterListResolver'
import { continuationChapterIds } from './ReaderChapterSequence'
import { enrichSourceChapterMetadata } from './SourceChapterMetadata'
import { reconcileSourceChapterIdentity } from './SourceChapterIdentity'
import { SourceFailureDetails, sourceFailureDetails } from './SourceRuntimeError'

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
  sourceFailure?: SourceFailureDetails
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
  settingsFingerprint?: string
  reasonCode?: string
  sourceFailureReason?: string
  sourceFailure?: SourceFailureDetails
}

/** Reuse prepared pages across opens only while their generating settings match.
 * Offline manifests remain owned by the offline reader, outside this check.
 */
export function sourceChapterPagesMatchSettings(chapter: Chapter, sourceId: string): boolean {
  if (chapter.pages.length === 0) return false
  try {
    return (chapter.sourceSettingsFingerprint ?? '') ===
      sourceSettingsFingerprint(appSourceSettingsStore.loadForSource(sourceId))
  } catch (_error) {
    // Unknown settings cannot validate a plan. Normal resolution reports the
    // storage failure and retains the existing usable pages without stamping them.
    return false
  }
}

function normalizeSourceLookupHydrationReason(reasonCode: string | undefined): string {
  if (reasonCode === 'missing_source_id' || reasonCode === 'source_id_not_registered') {
    return 'source_not_installed'
  }
  return reasonCode ?? 'source_lookup_failed'
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

async function pagesFromSourceRows(comicId: string, chapterId: string, rows: Record<string, Object>[]): Promise<Page[]> {
  const pages: Page[] = []
  for (let index: number = 0; index < rows.length; index++) {
    const item = rows[index]
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
    const image = sourcePageImageRecord(item)
    if (image?.['kind'] === 'text') {
      const spec = sourceTextPage(image['text'])
      page.uri = await cacheSourceTextPageImage(spec)
      page.sourceText = spec
      page.width = spec.template === 'webtoon-author-notes' ? 1000 : 1080
      page.height = undefined
      page.fileName += '.png'
    } else if (image?.['kind'] === 'text_request') {
      // Publish the valid body pages before an optional page's network/render work.
      // The Reader preparation lane owns this page's failure and explicit retry.
      page.sourceTextRequest = sourceTextPageRequest(image['textRequest'])
      // Durable Page URIs must be nonempty. Use the real source page identity;
      // sourceTextRequest selects its resolver, so this never becomes an HTTP URL.
      page.uri = pageId
      page.width = 1080
      page.height = undefined
      page.fileName += '.png'
    }
    pages.push(page)
  }
  return pages
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
  configureSourceRequestPolicy(entry.sourceId, sourceRequest.settings)
  const requestJson: string = sourceRequestWithHostFeatures(JSON.stringify(sourceRequest))
  const responseJson = await diagnoseSourceOperation(requestJson, () => executeSourceChapterPagesOperation(
    requestJson,
    cloneWasmBytes(entry),
    sourceHttpIdentityJson(entry),
  ))
  const response = JSON.parse(responseJson) as SourceOperationResponsePayload
  const rows = response.data?.pages !== undefined ? response.data.pages : (response.data?.items ?? [])
  if (response.ok !== true) {
    const reason = optionalSourceString(response.reasonCode) ?? optionalSourceString(response.error?.['code'])
    // Keep download reason codes stable. Reader receives only the allowlisted
    // category/status, never provider messages, URLs, headers, or response bodies.
    return { pages: [], reasonCode: 'source_pages_failed',
      sourceFailureReason: reason?.trim().toLowerCase() === 'unsupported' ? 'unsupported' : undefined,
      sourceFailure: sourceFailureDetails({ ok: false, reasonCode: response.reasonCode, error: response.error }) }
  }
  if (rows.length === 0) return { pages: [], reasonCode: 'source_pages_failed' }
  return { pages: await pagesFromSourceRows(request.comicId, request.chapterId, rows),
    settingsFingerprint: sourceSettingsFingerprint(sourceRequest.settings) }
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
      readingOrder: descriptor.readingOrder,
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

  /** Upgrade legacy sequence metadata beside the displayed chapter. No page,
   * progress, chapter deletion or visible catalog reordering is performed. */
  async resolveChapterSequence(comicId: string, chapterId: string,
    isCurrent: () => boolean): Promise<string[] | undefined> {
    const comic = this.libraryStore.getComic(comicId)
    const sourceId = comic?.sourceRuntimeId?.trim()
    if (comic === undefined || sourceId === undefined || sourceId.length === 0) return undefined
    const mangaId = sourceMangaIdFromComic(comic, sourceId)
    const lookup = this.sourceRegistry.lookup(sourceId)
    if (mangaId === undefined || !lookup.ok || lookup.entry === undefined ||
      !sourceRuntimeEntryEnabled(lookup.entry)) return undefined
    const sourceCurrent = (): boolean => isCurrent() && this.sourceRegistry.lookup(sourceId).entry === lookup.entry
    const catalog = await resolveSourceChapterList(lookup.entry, mangaId, comic.sourcePath, sourceCurrent)
    const latest = this.libraryStore.getComic(comicId)
    if (!catalog.resolved || !sourceCurrent() || latest === undefined || !sameComicIdentity(comic, latest) ||
      latest.sourceRuntimeId !== sourceId || sourceMangaIdFromComic(latest, sourceId) !== mangaId) return undefined
    const resolved = reconcileSourceChapterIdentity(latest, mangaId, catalog.chapters, undefined)
    const updated = JSON.parse(JSON.stringify(latest)) as Comic
    if (enrichSourceChapterMetadata(updated, resolved.chapters)) {
      if (this.libraryPersistenceService === undefined) this.libraryStore.upsertComic(updated)
      else upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, updated)
      this.onLibraryChanged?.()
    }
    return continuationChapterIds(resolved.chapters, chapterId)
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
    const resolvedSourceId = sourceId ?? comic.sourceRuntimeId
    if (chapter.pages.length > 0 && !forceRefresh && (resolvedSourceId === undefined ||
      sourceChapterPagesMatchSettings(chapter, resolvedSourceId))) {
      return { hydrated: true, pageCount: chapter.pages.length }
    }
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
        sourceFailureReason: resolution.sourceFailureReason, sourceFailure: resolution.sourceFailure }
    }
    const fingerprint = resolution.settingsFingerprint ?? ''
    if (fingerprint !== sourceSettingsFingerprint(appSourceSettingsStore.loadForSource(resolvedSourceId))) {
      return { hydrated: false, pageCount: 0, reasonCode: 'source_pages_failed' }
    }
    return this.applyPages(baselineComic, baselineChapter, resolution.pages, fingerprint)
  }

  private applyPages(comic: Comic, chapter: Chapter, pages: Page[], fingerprint: string): SourceChapterPageHydrationResult {
    const current = this.libraryStore.getComic(comic.id)
    const currentChapter = current?.chapters.find((item: Chapter): boolean => item.id === chapter.id)
    if (current === undefined || !sameComicIdentity(comic, current) || currentChapter === undefined ||
      currentChapter.createdAt !== chapter.createdAt || currentChapter.sourcePath !== chapter.sourcePath) {
      return { hydrated: false, pageCount: 0, reasonCode: 'chapter_missing' }
    }
    // A newer page plan already committed while this request was resolving owns the chapter.
    if (JSON.stringify(currentChapter.pages) !== JSON.stringify(chapter.pages) ||
      currentChapter.sourceSettingsFingerprint !== chapter.sourceSettingsFingerprint) {
      return {
        hydrated: currentChapter.pages.length > 0,
        pageCount: currentChapter.pages.length,
        reasonCode: currentChapter.pages.length > 0 ? undefined : 'pages_missing',
      }
    }
    const next = JSON.parse(JSON.stringify(current)) as Comic
    const nextChapter = next.chapters.find((item: Chapter): boolean => item.id === chapter.id) as Chapter
    nextChapter.pages = pages
    nextChapter.sourceSettingsFingerprint = fingerprint
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
