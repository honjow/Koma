import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { SourceRuntimeError } from './SourceRuntimeError'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { sourceChapterForRetainedIdentity } from './SourceChapterIdentity'
import { taskpool } from '@kit.ArkTS'
import { MangaChapterItem, parseMangaChapterFromSourceItem } from './MangaDetailModels'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { runSourceOperationFromBytes, diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
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
  chapterId?: string
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
function executeSourceChapterListOperation(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string): string {
  return JSON.stringify(runSourceOperationFromBytes(requestJson, wasmBytes, httpContextJson))
}

/** Existing detail pagination/settings flow, shared without writing Library or history. */
export async function resolveSourceChapterList(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  mangaUrl?: string,
  isCurrent?: () => boolean,
): Promise<SourceChapterListResult> {
  return fetchSourceChapterList(entry, mangaId, undefined, mangaUrl, isCurrent)
}

/** Exact-ID recovery never exposes its partial response as a full catalog. */
export async function resolveSourceChapterForResume(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  chapterId: string,
  mangaUrl?: string,
  isCurrent?: () => boolean,
): Promise<MangaChapterItem | undefined> {
  const result = await fetchSourceChapterList(entry, mangaId, chapterId, mangaUrl, isCurrent)
  return sourceChapterForRetainedIdentity(entry.sourceId, mangaId, chapterId, result.chapters)
}

async function fetchSourceChapterList(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  chapterId?: string,
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
    if (chapterId !== undefined) {
      request.args.chapterId = chapterId
    }
    const wasmBytes = new Uint8Array(entry.wasmBytes.byteLength)
    wasmBytes.set(entry.wasmBytes)
    const responseJson = await diagnoseSourceOperation(JSON.stringify(request), () => taskpool.execute(
      executeSourceChapterListOperation, JSON.stringify(request), wasmBytes, sourceHttpIdentityJson(entry),
    ) as Promise<string>)
    if (!current()) return { chapters, resolved: false, reasonCode: 'source_chapters_cancelled' }
    const response = JSON.parse(responseJson) as SourceChapterResponse
    if (response.ok !== true) {
      const nativeReason = response.reasonCode
      const sourceReason = response.error?.['code']
      const reason = typeof nativeReason === 'string' && nativeReason.trim().length > 0 ? nativeReason :
        (typeof sourceReason === 'string' && sourceReason.trim().length > 0 ? sourceReason : 'get_chapters_failed')
      const failure = new SourceRuntimeError(response as SourceRuntimeCallResponse)
      // Existing update/resume consumers classify message as a reason code; UI uses userText.
      failure.message = reason
      throw failure
    }
    const rows = response.data?.items ?? response.data?.chapters ?? []
    rows.forEach((item: Record<string, Object>): void => { chapters.push(parseMangaChapterFromSourceItem(item)) })
    if (chapterId !== undefined) {
      const matched = chapters.find((chapter: MangaChapterItem): boolean => chapter.id === chapterId)
      if (matched !== undefined) {
        return { chapters: [matched], resolved: false }
      }
    }
    const rawCursor = response.data?.page?.nextCursor ?? response.data?.page?.next_cursor
    const nextCursor = rawCursor === null || rawCursor === undefined || rawCursor.trim().length === 0
      ? undefined : rawCursor
    const hasMore = response.data?.hasNextPage === true || response.data?.hasMore === true ||
      response.data?.has_more === true || response.data?.page?.hasMore === true ||
      response.data?.page?.hasNextPage === true || response.data?.page?.has_more === true || nextCursor !== undefined
    if (!hasMore) {
      if (chapterId === undefined) {
        const counts = new Map<string, number>()
        let duplicateIdGroups = 0
        let duplicateRows = 0
        chapters.forEach((chapter: MangaChapterItem): void => {
          const count = (counts.get(chapter.id) ?? 0) + 1
          counts.set(chapter.id, count)
          if (count === 2) duplicateIdGroups += 1
          if (count > 1) duplicateRows += 1
        })
        // Completed catalog only: no identifiers, titles, URLs, page-by-page or scroll logging.
        DiagnosticLogger.info('source_chapters', 'catalog_identity', 'total=' + chapters.length +
          ' uniqueId=' + counts.size + ' duplicateIdGroups=' + duplicateIdGroups + ' duplicateRows=' + duplicateRows)
      }
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
