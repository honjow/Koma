import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  LibraryUpdateComicResult,
  LibraryUpdateResultStatus,
  LibraryUpdateSummary,
  countLibraryUpdateNewChapters,
} from './LibraryUpdateService'

export const LIBRARY_UPDATE_RESULT_STORE_NAME: string = 'koma_library_update_results_v1'
export const LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY: string = 'libraryUpdate.latestResultJson'
export const LIBRARY_UPDATE_RESULT_MAX_RESULTS: number = 200
export const LIBRARY_UPDATE_RESULT_MAX_COMIC_ID_LENGTH: number = 256
export const LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH: number = 512

export interface PersistedLibraryUpdateResult {
  comicId: string
  status: LibraryUpdateResultStatus
  previousChapterCount: number
  newChapterCount: number
  message: string
}

export interface PersistedLibraryUpdateSummary {
  checkedAt: number
  totalCount: number
  updatedCount: number
  unchangedCount: number
  skippedCount: number
  failedCount: number
  results: PersistedLibraryUpdateResult[]
}

export interface LibraryUpdateNotificationSummary {
  checkedAt: number
  totalCount: number
  updatedCount: number
  newChapterCount: number
  failedCount: number
  failureCodes: string[]
  summaryText: string
  systemDispatchEnabled: boolean
}

let latestLibraryUpdateSummary: LibraryUpdateSummary | undefined = undefined

function clampString(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value
  }
  return value.substring(0, maxLength)
}

export function redactLibraryUpdateFailureCode(value: string | undefined): string {
  if (value === undefined) {
    return 'unknown'
  }
  const trimmed = value.trim().toLocaleLowerCase()
  if (trimmed.length === 0) {
    return 'unknown'
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
  return clampString('unknown', 64)
}

function isNonNegativeFiniteNumber(value: number): boolean {
  return Number.isFinite(value) && value >= 0
}

function normalizeCount(value: number): number {
  if (!isNonNegativeFiniteNumber(value)) {
    return 0
  }
  return Math.floor(value)
}

function isValidCheckedAt(value: number): boolean {
  return Number.isFinite(value) && value > 0
}

function isValidStatus(value: string): boolean {
  return value === 'updated' ||
    value === 'unchanged' ||
    value === 'skipped' ||
    value === 'failed'
}

function sanitizeLibraryUpdateResultMessage(status: LibraryUpdateResultStatus, message: string): string {
  return status === 'failed' ? redactLibraryUpdateFailureCode(message) : message
}

function cloneLibraryUpdateResult(result: LibraryUpdateComicResult): LibraryUpdateComicResult {
  return {
    comicId: result.comicId,
    status: result.status,
    previousChapterCount: result.previousChapterCount,
    newChapterCount: result.newChapterCount,
    message: sanitizeLibraryUpdateResultMessage(result.status, result.message),
  }
}

function persistLibraryUpdateResult(result: LibraryUpdateComicResult): PersistedLibraryUpdateResult {
  const message = sanitizeLibraryUpdateResultMessage(result.status, result.message)
  return {
    comicId: clampString(result.comicId, LIBRARY_UPDATE_RESULT_MAX_COMIC_ID_LENGTH),
    status: result.status,
    previousChapterCount: normalizeCount(result.previousChapterCount),
    newChapterCount: normalizeCount(result.newChapterCount),
    message: clampString(message, LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH),
  }
}

export function createLibraryUpdateNotificationSummary(summary: LibraryUpdateSummary): LibraryUpdateNotificationSummary {
  const failureCodes: string[] = []
  summary.results.forEach((result: LibraryUpdateComicResult) => {
    if (result.status !== 'failed') {
      return
    }
    const code = redactLibraryUpdateFailureCode(result.message)
    if (!failureCodes.includes(code)) {
      failureCodes.push(code)
    }
  })
  const newChapterCount = countLibraryUpdateNewChapters(summary)
  const summaryText = `${newChapterCount} 新章 · ${summary.updatedCount} 更新 · ${summary.failedCount} 失败`
  return {
    checkedAt: summary.checkedAt,
    totalCount: summary.totalCount,
    updatedCount: summary.updatedCount,
    newChapterCount,
    failedCount: summary.failedCount,
    failureCodes,
    summaryText,
    systemDispatchEnabled: false,
  }
}

export function formatLibraryUpdateNotificationSummary(summary: LibraryUpdateSummary): string {
  const notificationSummary = createLibraryUpdateNotificationSummary(summary)
  if (notificationSummary.failureCodes.length === 0) {
    return notificationSummary.summaryText
  }
  return `${notificationSummary.summaryText} · ${notificationSummary.failureCodes.join(',')}`
}

export function serializeLibraryUpdateSummary(summary: LibraryUpdateSummary): string {
  const results = summary.results
    .slice(0, LIBRARY_UPDATE_RESULT_MAX_RESULTS)
    .map((result: LibraryUpdateComicResult): PersistedLibraryUpdateResult => persistLibraryUpdateResult(result))
  const persisted: PersistedLibraryUpdateSummary = {
    checkedAt: isValidCheckedAt(summary.checkedAt) ? summary.checkedAt : Date.now(),
    totalCount: normalizeCount(summary.totalCount),
    updatedCount: normalizeCount(summary.updatedCount),
    unchangedCount: normalizeCount(summary.unchangedCount),
    skippedCount: normalizeCount(summary.skippedCount),
    failedCount: normalizeCount(summary.failedCount),
    results,
  }
  return JSON.stringify(persisted)
}

function isRecord(value: Object | null): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function numberField(record: Record<string, Object>, key: string): number | undefined {
  const value = record[key]
  if (typeof value !== 'number') {
    return undefined
  }
  return value
}

function aggregateCountField(record: Record<string, Object>, key: string, fallback: number): number {
  const value = numberField(record, key)
  if (value === undefined || !isNonNegativeFiniteNumber(value)) {
    return fallback
  }
  return normalizeCount(value)
}

function stringField(record: Record<string, Object>, key: string): string | undefined {
  const value = record[key]
  if (typeof value !== 'string') {
    return undefined
  }
  return value
}

function hydrateLibraryUpdateResult(value: Object): LibraryUpdateComicResult | undefined {
  if (!isRecord(value)) {
    return undefined
  }
  const record = value as Record<string, Object>
  const comicId = stringField(record, 'comicId')
  const status = stringField(record, 'status')
  const previousChapterCount = numberField(record, 'previousChapterCount')
  const newChapterCount = numberField(record, 'newChapterCount')
  const message = stringField(record, 'message')
  if (comicId === undefined ||
    status === undefined ||
    previousChapterCount === undefined ||
    newChapterCount === undefined ||
    message === undefined) {
    return undefined
  }
  if (!isValidStatus(status) ||
    !isNonNegativeFiniteNumber(previousChapterCount) ||
    !isNonNegativeFiniteNumber(newChapterCount)) {
    return undefined
  }
  const safeStatus = status as LibraryUpdateResultStatus
  return {
    comicId: clampString(comicId, LIBRARY_UPDATE_RESULT_MAX_COMIC_ID_LENGTH),
    status: safeStatus,
    previousChapterCount: normalizeCount(previousChapterCount),
    newChapterCount: normalizeCount(newChapterCount),
    message: clampString(sanitizeLibraryUpdateResultMessage(safeStatus, message), LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH),
  }
}

export function hydrateLibraryUpdateSummaryFromJson(jsonText: string): LibraryUpdateSummary | undefined {
  try {
    const parsed = JSON.parse(jsonText) as Object
    if (!isRecord(parsed)) {
      return undefined
    }
    const record = parsed as Record<string, Object>
    const checkedAt = numberField(record, 'checkedAt')
    if (checkedAt === undefined || !isValidCheckedAt(checkedAt)) {
      return undefined
    }
    const rawResultsObject = record['results']
    if (!Array.isArray(rawResultsObject)) {
      return undefined
    }
    const rawResults = rawResultsObject as Object[]
    const results: LibraryUpdateComicResult[] = []
    const cappedResults: Object[] = rawResults.slice(0, LIBRARY_UPDATE_RESULT_MAX_RESULTS)
    for (const item of cappedResults) {
      const result = hydrateLibraryUpdateResult(item)
      if (result === undefined) {
        return undefined
      }
      results.push(result)
    }
    const resultTotalCount = results.length
    const resultUpdatedCount = results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'updated').length
    const resultUnchangedCount = results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'unchanged').length
    const resultSkippedCount = results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'skipped').length
    const resultFailedCount = results.filter((result: LibraryUpdateComicResult): boolean => result.status === 'failed').length
    return {
      checkedAt,
      totalCount: aggregateCountField(record, 'totalCount', resultTotalCount),
      updatedCount: aggregateCountField(record, 'updatedCount', resultUpdatedCount),
      unchangedCount: aggregateCountField(record, 'unchangedCount', resultUnchangedCount),
      skippedCount: aggregateCountField(record, 'skippedCount', resultSkippedCount),
      failedCount: aggregateCountField(record, 'failedCount', resultFailedCount),
      results,
    }
  } catch (_error) {
    return undefined
  }
}

export function cloneLibraryUpdateSummary(summary: LibraryUpdateSummary): LibraryUpdateSummary {
  return {
    checkedAt: summary.checkedAt,
    totalCount: summary.totalCount,
    updatedCount: summary.updatedCount,
    unchangedCount: summary.unchangedCount,
    skippedCount: summary.skippedCount,
    failedCount: summary.failedCount,
    results: summary.results.map((result: LibraryUpdateComicResult): LibraryUpdateComicResult => cloneLibraryUpdateResult(result)),
  }
}

export function setLatestLibraryUpdateSummary(summary: LibraryUpdateSummary): void {
  latestLibraryUpdateSummary = cloneLibraryUpdateSummary(summary)
}

export function getLatestLibraryUpdateSummary(): LibraryUpdateSummary | undefined {
  if (latestLibraryUpdateSummary === undefined) {
    return undefined
  }
  return cloneLibraryUpdateSummary(latestLibraryUpdateSummary)
}

export class LibraryUpdateResultStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<LibraryUpdateSummary | undefined> {
    try {
      const store = await this.preferences()
      const jsonText = await store.get(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, '') as string
      if (jsonText.length === 0) {
        return undefined
      }
      return hydrateLibraryUpdateSummaryFromJson(jsonText)
    } catch (_error) {
      return undefined
    }
  }

  async save(summary: LibraryUpdateSummary): Promise<void> {
    const store = await this.preferences()
    await store.put(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, serializeLibraryUpdateSummary(summary))
    await store.flush()
  }

  async clear(): Promise<void> {
    const store = await this.preferences()
    await store.put(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, '')
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, LIBRARY_UPDATE_RESULT_STORE_NAME)
  }
}
