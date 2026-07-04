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
} from '../sourceRuntime/SourceRuntimeRegistry'
import { runSourceOperationFromBytes } from '../sourceRuntime/SourceRuntimeRunner'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'

interface SourceOperationDataPayload {
  items?: Record<string, Object>[]
  pages?: Record<string, Object>[]
}

interface SourceOperationResponsePayload {
  ok?: boolean
  data?: SourceOperationDataPayload
}

interface SourcePagesRequestArgs {
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

function sourcePageImageUrl(item: Record<string, Object>): string | undefined {
  const directUrl = optionalSourceString(item['url']) ?? optionalSourceString(item['uri'])
  if (directUrl !== undefined) {
    return directUrl
  }
  const image = item['image']
  if (image === undefined || image === null || Array.isArray(image) || typeof image !== 'object') {
    return undefined
  }
  const imageRecord = image as Record<string, Object>
  return optionalSourceString(imageRecord['url']) ?? optionalSourceString(imageRecord['uri'])
}

function pagesFromSourceRows(comicId: string, chapterId: string, rows: Record<string, Object>[]): Page[] {
  return rows.map((item: Record<string, Object>, index: number): Page => {
    const pageId = optionalSourceString(item['id']) ?? optionalSourceString(item['pageId']) ?? `${chapterId}:page:${index + 1}`
    const page: Page = {
      id: pageId,
      comicId,
      chapterId,
      index,
      fileName: `source-page-${index + 1}`,
      uri: sourcePageImageUrl(item) ?? '',
      sortKey: `${index}`.padStart(6, '0'),
    }
    const width = optionalSourceNumber(item['width'])
    if (width !== undefined) {
      page.width = width
    }
    const height = optionalSourceNumber(item['height'])
    if (height !== undefined) {
      page.height = height
    }
    return page
  })
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
      return { hydrated: false, pageCount: 0, reasonCode: lookup.reasonCode ?? 'source_lookup_failed' }
    }
    const pages = await this.fetchChapterPages(lookup.entry, comic.id, chapterId)
    if (pages.length === 0) {
      return { hydrated: false, pageCount: 0, reasonCode: 'pages_missing' }
    }
    this.applyPages(comic, chapter, pages)
    return { hydrated: true, pageCount: pages.length }
  }

  private async fetchChapterPages(
    entry: SourceRuntimeRegistryEntry,
    comicId: string,
    chapterId: string,
  ): Promise<Page[]> {
    const request: SourcePagesRequest = {
      type: 'request',
      version: 1,
      requestId: `chapter-pages-${entry.sourceId}-${Date.now()}`,
      operation: 'get_pages',
      sourceId: entry.sourceId,
      args: { chapterId },
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
    return pagesFromSourceRows(comicId, chapterId, rows)
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
