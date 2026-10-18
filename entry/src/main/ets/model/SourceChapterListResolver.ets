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
  reasonCode?: string
  error?: Record<string, Object | string | number | boolean | null>
  data?: SourceChapterData
}

interface SourceChapterPageArgs {
  cursor: string | null
  limit: number
}

interface SourceChapterArgs {
  mangaId: string
  mangaUrl?: string
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
  reasonCode?: string
}

@Concurrent
function executeSourceChapterListOperation(requestJson: string, wasmBytes: Uint8Array): string {
  return JSON.stringify(runSourceOperationFromBytes(requestJson, wasmBytes))
}

/** Existing detail pagination/settings flow, shared without writing Library or history. */
export async function resolveSourceChapterList(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  mangaUrl?: string,
  isCurrent?: () => boolean,
): Promise<SourceChapterListResult> {
  const chapters: MangaChapterItem[] = []
  let cursor: string | null = null
  const requestedCursors: Set<string> = new Set()
  const settingsRevision = appSourceSettingsStore.revisionForSource(entry.sourceId)
  const settings = appSourceSettingsStore.loadForSource(entry.sourceId)
  const current = (): boolean => (isCurrent === undefined || isCurrent()) &&
    appSourceSettingsStore.revisionForSource(entry.sourceId) === settingsRevision
  while (true) {
    if (!current()) return { chapters, resolved: false, reasonCode: 'source_chapters_cancelled' }
    const request: SourceChapterRequest = {
      type: 'request',
      version: 1,
      requestId: `detail-get_chapters-${entry.sourceId}-${Date.now()}`,
      operation: 'get_chapters',
      sourceId: entry.sourceId,
      args: { mangaId, mangaUrl, page: { cursor, limit: 100 } },
      settings,
      hostHints: { network: true },
    }
    const wasmBytes = new Uint8Array(entry.wasmBytes.byteLength)
    wasmBytes.set(entry.wasmBytes)
    const responseJson = await taskpool.execute(
      executeSourceChapterListOperation, JSON.stringify(request), wasmBytes,
    ) as string
    if (!current()) return { chapters, resolved: false, reasonCode: 'source_chapters_cancelled' }
    const response = JSON.parse(responseJson) as SourceChapterResponse
    if (response.ok !== true) {
      const nativeReason = response.reasonCode
      const sourceReason = response.error?.['code']
      const reason = typeof nativeReason === 'string' && nativeReason.trim().length > 0 ? nativeReason :
        (typeof sourceReason === 'string' && sourceReason.trim().length > 0 ? sourceReason : 'get_chapters_failed')
      throw new Error(reason)
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
    // A cursor belongs to the source. Never invent a numeric next page, or
    // turn a request budget into a complete catalog. Empty pages may continue.
    if (nextCursor === undefined) {
      return { chapters, resolved: false, reasonCode: 'source_chapter_cursor_missing' }
    }
    if (requestedCursors.has(nextCursor)) {
      return { chapters, resolved: false, reasonCode: 'source_chapter_cursor_repeated' }
    }
    requestedCursors.add(nextCursor)
    cursor = nextCursor
  }
}
