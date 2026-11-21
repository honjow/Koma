import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { taskpool } from '@kit.ArkTS'
import { AppStrings } from '../i18n/AppStrings'
import { SourceRuntimeError } from './SourceRuntimeError'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { configureSourceRequestPolicy } from '../sourceRuntime/SourceRequestPolicy'
import { sourceChapterForRetainedIdentity } from './SourceChapterIdentity'
import type { MangaChapterItem } from './MangaDetailModels'
import { projectSourceChapterResponse, SourceChapterProjection } from './SourceChapterResponseWorker'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { executeSourceRequestInWorker as executeSourceChapterListOperation } from '../sourceRuntime/SourceRuntimeWorkerClient'
import { SourceSettingsRecord, appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { appSourceSettingObservationStore } from '../sourceRuntime/SourceSettingObservationStore'
import { sourceRequestWithHostFeatures } from '../sourceRuntime/SourceHostFeatures'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { sourceChapterExclusions } from './SourceChapterVisibility'
import { sourceCatalogChronology } from './SourceChapterChronology'
import { selectSourceRejectedRequest } from '../sourceRuntime/SourceRuntimeHttpTransport'

interface SourceChapterPageArgs {
  cursor: string | null
  limit: number
}

interface SourceChapterArgs {
  mangaId: string
  mangaUrl?: string
  page: SourceChapterPageArgs
  chapterId?: string
  chapterContext?: Record<string, Object>
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
  excludedChapterIds?: string[]
}

/** Existing detail pagination/settings flow, shared without writing Library or history. */
export async function resolveSourceChapterList(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  mangaUrl?: string,
  isCurrent?: () => boolean,
  chapterContext?: Record<string, Object>,
  operationGuardId?: string,
): Promise<SourceChapterListResult> {
  return fetchSourceChapterList(entry, mangaId, undefined, mangaUrl, isCurrent, chapterContext, operationGuardId)
}

/** Exact-ID recovery never exposes its partial response as a full catalog. */
export async function resolveSourceChapterForResume(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  chapterId: string,
  mangaUrl?: string,
  isCurrent?: () => boolean,
  operationGuardId?: string,
): Promise<MangaChapterItem | undefined> {
  const result = await fetchSourceChapterList(entry, mangaId, chapterId, mangaUrl, isCurrent, undefined, operationGuardId)
  return sourceChapterForRetainedIdentity(entry.websitePolicy?.chapterIdentity, mangaId, chapterId, result.chapters)
}

async function fetchSourceChapterList(
  entry: SourceRuntimeRegistryEntry,
  mangaId: string,
  chapterId?: string,
  mangaUrl?: string,
  isCurrent?: () => boolean,
  chapterContext?: Record<string, Object>,
  operationGuardId?: string,
): Promise<SourceChapterListResult> {
  const chapters: MangaChapterItem[] = []
  const excludedChapterIds: Set<string> = new Set<string>()
  const chapterIdCounts: Map<string, number> = new Map<string, number>()
  let duplicateIdGroups = 0
  let duplicateRows = 0
  let numberedRows = 0
  let minNumber: number | undefined = undefined
  let maxNumber: number | undefined = undefined
  const leadingNumbers: string[] = []
  let cursor: string | null = null
  const requestedCursors: Set<string> = new Set()
  const settingsRevision = appSourceSettingsStore.revisionForSource(entry.sourceId)
  const settings = appSourceSettingsStore.loadForSource(entry.sourceId)
  configureSourceRequestPolicy(entry.requestLimits, settings)
  const observationToken = appSourceSettingObservationStore.tokenForSource(entry.sourceId)
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
    if (chapterId === undefined && chapterContext !== undefined) request.args.chapterContext = chapterContext
    const wasmBytes = new Uint8Array(entry.wasmBytes.byteLength)
    wasmBytes.set(entry.wasmBytes)
    const requestJson = sourceRequestWithHostFeatures(JSON.stringify(request), operationGuardId !== undefined)
    const responseJson = await diagnoseSourceOperation(requestJson, () => executeSourceChapterListOperation( requestJson, wasmBytes,
      sourceHttpIdentityJson(entry, operationGuardId, chapterContext !== undefined && chapterId === undefined, 'get_chapters'),
    ))
    if (!current()) return { chapters, resolved: false, reasonCode: 'source_chapters_cancelled' }
    const projection = await taskpool.execute(projectSourceChapterResponse, responseJson,
      AppStrings.get('manga_detail_chapter_untitled'), AppStrings.get('library_update_chapter_fallback_title')) as SourceChapterProjection
    if (!current()) return { chapters, resolved: false, reasonCode: 'source_chapters_cancelled' }
    const response = projection.response
    if (response.ok !== true) {
      const nativeReason = response.reasonCode
      const sourceReason = response.error?.['code']
      const reason = typeof nativeReason === 'string' && nativeReason.trim().length > 0 ? nativeReason :
        (typeof sourceReason === 'string' && sourceReason.trim().length > 0 ? sourceReason : 'get_chapters_failed')
      const failure = new SourceRuntimeError(response as SourceRuntimeCallResponse)
      if (operationGuardId !== undefined && failure.diagnostic.kind === 'challenge') {
        selectSourceRejectedRequest(entry.sourceId, operationGuardId, failure.challengeRequestId)
      }
      // Existing update/resume consumers classify message as a reason code; UI uses userText.
      failure.message = reason
      throw failure
    }
    projection.chapters.forEach((chapter: MangaChapterItem): void => {
      if (chapterId === undefined) {
        const count = (chapterIdCounts.get(chapter.id) ?? 0) + 1
        chapterIdCounts.set(chapter.id, count)
        if (count === 2) duplicateIdGroups += 1
        if (count > 1) duplicateRows += 1
        const number = chapter.chapterNumber
        const known = number !== undefined && Number.isFinite(number) && number >= 0
        if (known) {
          numberedRows += 1
          minNumber = minNumber === undefined ? number : Math.min(minNumber, number)
          maxNumber = maxNumber === undefined ? number : Math.max(maxNumber, number)
        }
        if (chapters.length < 8) leadingNumbers.push(chapters.length + ':' + (known ? number : '?'))
      }
      chapters.push(chapter)
    })
    try {
      sourceChapterExclusions(response.data?.excludedChapterIds).forEach((id: string): void => { excludedChapterIds.add(id) })
    } catch (_error) {
      const error: Record<string, Object | string | number | boolean | null> = {}
      error['code'] = 'invalid_response'
      const invalid: SourceRuntimeCallResponse = { ok: false, error }
      throw new SourceRuntimeError(invalid)
    }
    if (response.data?.settingObservations !== undefined) {
      // Optional metadata must not delay/fail a readable catalog or rebuild any
      // manager row. Only successful, still-current responses can contribute.
      try {
        void appSourceSettingObservationStore.observe(entry.sourceId, response.data.settingObservations,
          observationToken, (): boolean => current() && entry.enabled &&
            appSourceRuntimeRegistry.lookup(entry.sourceId).entry === entry).catch((): void => {
          DiagnosticLogger.warn('source_settings', 'observations_not_saved', 'reason=source_setting_observations_write_failed')
        })
      } catch (_error) {
        DiagnosticLogger.warn('source_settings', 'observations_ignored', 'reason=source_setting_observations_invalid')
      }
    }
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
        // Completed catalog only: no identifiers, titles, URLs, page-by-page or scroll logging.
        DiagnosticLogger.info('source_chapters', 'catalog_identity', 'total=' + chapters.length +
          ' uniqueId=' + chapterIdCounts.size + ' duplicateIdGroups=' + duplicateIdGroups + ' duplicateRows=' + duplicateRows)
        DiagnosticLogger.info('source_chapters', 'catalog_order', 'total=' + chapters.length +
          ' numbered=' + numberedRows + ' unknown=' + (chapters.length - numberedRows) +
          ' min=' + (minNumber ?? 'none') + ' max=' + (maxNumber ?? 'none') +
          ' leading=' + leadingNumbers.join(','))
      }
      const completeChapters = chapterId === undefined ? sourceCatalogChronology(chapters, entry.chapterOrder) : chapters
      const result: SourceChapterListResult = { chapters: completeChapters, resolved: true }
      if (excludedChapterIds.size > 0) result.excludedChapterIds = Array.from(excludedChapterIds)
      return result
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
