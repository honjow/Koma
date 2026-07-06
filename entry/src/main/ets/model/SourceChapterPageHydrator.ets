import { taskpool } from '@kit.ArkTS'
import {
  Chapter,
  Comic,
  Page,
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
import { runSourceOperationFromBytes } from '../sourceRuntime/SourceRuntimeRunner'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { normalizeSourceImageUrl } from './SourceTextNormalizer'

interface SourceOperationDataPayload {
  items?: Record<string, Object>[]
  pages?: Record<string, Object>[]
}

interface SourceOperationResponsePayload {
  ok?: boolean
  data?: SourceOperationDataPayload
}

interface SourcePagesRequestArgs {
  mangaId?: string
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

  async ensureChapterPages(
    comicId: string,
    sourceId: string | undefined,
    chapterId: string,
  ): Promise<SourceChapterPageHydrationResult> {
    const comic = this.libraryStore.getComic(comicId)
    const chapter = comic?.chapters.find((item: Chapter): boolean => item.id === chapterId)
    if (comic === undefined || chapter === undefined) {
      return { hydrated: false, pageCount: 0, reasonCode: 'chapter_missing' }
    }
    if (chapter.pages.length > 0) {
      return { hydrated: true, pageCount: chapter.pages.length }
    }
    const resolvedSourceId = sourceId ?? comic.sourceRuntimeId
    if (resolvedSourceId === undefined || resolvedSourceId.trim().length === 0) {
      return { hydrated: false, pageCount: 0, reasonCode: 'source_missing' }
    }
    const lookup = this.sourceRegistry.lookup(resolvedSourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      return { hydrated: false, pageCount: 0, reasonCode: normalizeSourceLookupHydrationReason(lookup.reasonCode) }
    }
    if (!sourceRuntimeEntryEnabled(lookup.entry)) {
      return { hydrated: false, pageCount: 0, reasonCode: 'source_disabled' }
    }
    let pages: Page[] = []
    try {
      pages = await this.fetchChapterPages(lookup.entry, comic, chapterId)
    } catch (_error) {
      console.warn('[SourceChapterPageHydrator] step=fetch_pages_failed failed=true reason=source_pages_failed')
      return { hydrated: false, pageCount: 0, reasonCode: 'source_pages_failed' }
    }
    if (pages.length === 0) {
      return { hydrated: false, pageCount: 0, reasonCode: 'pages_missing' }
    }
    this.applyPages(comic, chapter, pages)
    return { hydrated: true, pageCount: pages.length }
  }

  private async fetchChapterPages(
    entry: SourceRuntimeRegistryEntry,
    comic: Comic,
    chapterId: string,
  ): Promise<Page[]> {
    const args: SourcePagesRequestArgs = { chapterId }
    const mangaId = sourceMangaIdFromComic(comic, entry.sourceId)
    if (mangaId !== undefined) {
      args.mangaId = mangaId
    }
    const request: SourcePagesRequest = {
      type: 'request',
      version: 1,
      requestId: `chapter-pages-${entry.sourceId}-${Date.now()}`,
      operation: 'get_pages',
      sourceId: entry.sourceId,
      args,
      settings: appSourceSettingsStore.loadForSource(entry.sourceId),
      hostHints: { network: true, imageStrategy: 'descriptor-or-url' },
    }
    const responseJson = await taskpool.execute(
      executeSourceChapterPagesOperation,
      JSON.stringify(request),
      cloneWasmBytes(entry),
    ) as string
    const response = JSON.parse(responseJson) as SourceOperationResponsePayload
    const rows = response.data?.pages !== undefined ? response.data.pages : (response.data?.items ?? [])
    if (response.ok !== true || rows.length === 0) {
      throw new Error('get_pages returned no pages')
    }
    return pagesFromSourceRows(comic.id, chapterId, rows)
  }

  private applyPages(comic: Comic, chapter: Chapter, pages: Page[]): void {
    chapter.pages = pages
    chapter.pageCount = pages.length
    chapter.updatedAt = Date.now()
    comic.pageCount = comic.chapters.reduce((total: number, item: Chapter): number => total + item.pageCount, 0)
    comic.updatedAt = chapter.updatedAt
    if (this.libraryPersistenceService === undefined) {
      this.libraryStore.upsertComic(comic)
    } else {
      upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
    }
    if (this.onLibraryChanged !== undefined) {
      this.onLibraryChanged()
    }
  }
}
