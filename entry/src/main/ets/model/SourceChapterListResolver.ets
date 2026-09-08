import { taskpool } from '@kit.ArkTS'
import { MangaChapterItem, parseMangaChapterFromSourceItem } from './MangaDetailModels'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { runSourceOperationFromBytes } from '../sourceRuntime/SourceRuntimeRunner'
import { SourceSettingsRecord, appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'

interface SourceChapterPage {
  hasMore?: boolean
  hasNextPage?: boolean
  has_more?: boolean
  nextCursor?: string | null
  next_cursor?: string | null
}

interface SourceChapterData {
  items?: Record<string, Object>[]
  chapters?: Record<string, Object>[]
  page?: SourceChapterPage
  hasNextPage?: boolean
  hasMore?: boolean
  has_more?: boolean
}

interface SourceChapterResponse {
  ok?: boolean
  data?: SourceChapterData
}

interface SourceChapterPageArgs {
  cursor: string | null
  limit: number
}

interface SourceChapterArgs {
  mangaId: string
  page: SourceChapterPageArgs
}

interface SourceChapterHostHints {
  network: boolean
}

interface SourceChapterRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceChapterArgs
  settings: SourceSettingsRecord
  hostHints: SourceChapterHostHints
}

export interface SourceChapterListResult {
  chapters: MangaChapterItem[]
  resolved: boolean
}

@Concurrent
function executeSourceChapterListOperation(requestJson: string, wasmBytes: Uint8Array): string {
  return JSON.stringify(runSourceOperationFromBytes(requestJson, wasmBytes))
}

/** Existing detail pagination/settings flow, shared without writing Library or history. */
export async function resolveSourceChapterList(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
): Promise<SourceChapterListResult> {
  const chapters: MangaChapterItem[] = []
  let cursor: string | null = null
  for (let pageIndex = 1; pageIndex <= 20; pageIndex += 1) {
    const request: SourceChapterRequest = {
      type: 'request',
      version: 1,
      requestId: `detail-get_chapters-${entry.sourceId}-${Date.now()}`,
      operation: 'get_chapters',
      sourceId: entry.sourceId,
      args: { mangaId, page: { cursor, limit: 100 } },
      settings: appSourceSettingsStore.loadForSource(entry.sourceId),
      hostHints: { network: true },
    }
    const wasmBytes = new Uint8Array(entry.wasmBytes.byteLength)
    wasmBytes.set(entry.wasmBytes)
    const responseJson = await taskpool.execute(
      executeSourceChapterListOperation, JSON.stringify(request), wasmBytes,
    ) as string
    const response = JSON.parse(responseJson) as SourceChapterResponse
    if (response.ok !== true) {
      throw new Error('get_chapters failed')
    }
    const rows = response.data?.items ?? response.data?.chapters ?? []
    rows.forEach((item: Record<string, Object>): void => { chapters.push(parseMangaChapterFromSourceItem(item)) })
    const rawCursor = response.data?.page?.nextCursor ?? response.data?.page?.next_cursor
    const nextCursor = rawCursor === null || rawCursor === undefined || rawCursor.trim().length === 0
      ? undefined : rawCursor
    const hasMore = response.data?.hasNextPage === true || response.data?.hasMore === true ||
      response.data?.has_more === true || response.data?.page?.hasMore === true ||
      response.data?.page?.hasNextPage === true || response.data?.page?.has_more === true || nextCursor !== undefined
    if (!hasMore) {
      return { chapters, resolved: true }
    }
    cursor = nextCursor ?? `${pageIndex + 1}`
  }
  return { chapters, resolved: false }
}
