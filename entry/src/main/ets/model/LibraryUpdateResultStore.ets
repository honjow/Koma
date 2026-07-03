import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { notificationManager } from '@kit.NotificationKit'
import {
  LibraryUpdateComicResult,
  LibraryUpdateProviderKind,
  LibraryUpdateProviderSummary,
  LibraryUpdateResultStatus,
  LibraryUpdateSummary,
  countLibraryUpdateNewChapters,
  summarizeLibraryUpdateProviders,
} from './LibraryUpdateService'
import { isLibraryUpdateNotificationDeliveryEnabled } from './LibraryUpdatePreferencesStore'
import { AppStrings } from '../i18n/AppStrings'

export const LIBRARY_UPDATE_RESULT_STORE_NAME: string = 'koma_library_update_results_v1'
export const LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY: string = 'libraryUpdate.latestResultJson'
export const LIBRARY_UPDATE_LATEST_JOB_JSON_KEY: string = 'libraryUpdate.latestJobJson'
export const LIBRARY_UPDATE_RESULT_MAX_RESULTS: number = 200
export const LIBRARY_UPDATE_RESULT_MAX_PROVIDER_SUMMARIES: number = 80
export const LIBRARY_UPDATE_RESULT_MAX_COMIC_ID_LENGTH: number = 256
export const LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH: number = 512
export const LIBRARY_UPDATE_RESULT_MAX_SOURCE_KEY_LENGTH: number = 64

export type LibraryUpdateJobState = 'due' | 'running' | 'success' | 'failed' | 'backed-off'

export interface PersistedLibraryUpdateResult {
  comicId: string
  providerKind: LibraryUpdateProviderKind
  sourceKey: string
  status: LibraryUpdateResultStatus
  previousChapterCount: number
  newChapterCount: number
  message: string
}

export interface PersistedLibraryUpdateProviderSummary {
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

export interface PersistedLibraryUpdateSummary {
  checkedAt: number
  totalCount: number
  updatedCount: number
  unchangedCount: number
  skippedCount: number
  failedCount: number
  providerSummaries: PersistedLibraryUpdateProviderSummary[]
  results: PersistedLibraryUpdateResult[]
}

export interface LibraryUpdateJobSnapshot {
  state: LibraryUpdateJobState
  updatedAt: number
  startedAt?: number
  finishedAt?: number
  nextDueAt?: number
  failureCode?: string
  summary?: LibraryUpdateSummary
  providerSummaries: LibraryUpdateProviderSummary[]
}

export interface PersistedLibraryUpdateJobSnapshot {
  state: LibraryUpdateJobState
  updatedAt: number
  startedAt?: number
  finishedAt?: number
  nextDueAt?: number
  failureCode?: string
  summary?: PersistedLibraryUpdateSummary
  providerSummaries: PersistedLibraryUpdateProviderSummary[]
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

export type LibraryUpdateNotificationDispatchCode =
  'delivered' |
    'disabled' |
    'not_needed' |
    'publish_failed'

export interface LibraryUpdateNotificationDispatchResult {
  delivered: boolean
  code: LibraryUpdateNotificationDispatchCode
}

let latestLibraryUpdateSummary: LibraryUpdateSummary | undefined = undefined
let latestLibraryUpdateJobSnapshot: LibraryUpdateJobSnapshot | undefined = undefined

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

function isValidProviderKind(value: string): boolean {
  return value === 'source_runtime' ||
    value === 'local' ||
    value === 'komga' ||
    value === 'opds' ||
    value === 'webdav' ||
    value === 'private_library' ||
    value === 'unsupported'
}

function isValidJobState(value: string): boolean {
  return value === 'due' ||
    value === 'running' ||
    value === 'success' ||
    value === 'failed' ||
    value === 'backed-off'
}

function normalizeProviderKind(value: string | undefined): LibraryUpdateProviderKind {
  if (value !== undefined && isValidProviderKind(value)) {
    return value as LibraryUpdateProviderKind
  }
  return 'unsupported'
}

function normalizeSourceKey(value: string | undefined): string {
  if (value === undefined) {
    return 'source:unknown'
  }
  const trimmed = value.trim().toLocaleLowerCase()
  if (/^(source:[a-z0-9]+|local|komga|opds|webdav|private_library|unsupported)$/.test(trimmed)) {
    return clampString(trimmed, LIBRARY_UPDATE_RESULT_MAX_SOURCE_KEY_LENGTH)
  }
  return 'source:unknown'
}

function sanitizeLibraryUpdateResultMessage(status: LibraryUpdateResultStatus, message: string): string {
  return status === 'failed' ? redactLibraryUpdateFailureCode(message) : message
}

function cloneLibraryUpdateResult(result: LibraryUpdateComicResult): LibraryUpdateComicResult {
  return {
    comicId: result.comicId,
    providerKind: result.providerKind,
    sourceKey: result.sourceKey,
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
    providerKind: normalizeProviderKind(result.providerKind),
    sourceKey: normalizeSourceKey(result.sourceKey),
    status: result.status,
    previousChapterCount: normalizeCount(result.previousChapterCount),
    newChapterCount: normalizeCount(result.newChapterCount),
    message: clampString(message, LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH),
  }
}

function persistLibraryUpdateProviderSummary(summary: LibraryUpdateProviderSummary): PersistedLibraryUpdateProviderSummary {
  const failureCodes: string[] = []
  summary.failureCodes.forEach((code: string) => {
    const safeCode = redactLibraryUpdateFailureCode(code)
    if (!failureCodes.includes(safeCode)) {
      failureCodes.push(safeCode)
    }
  })
  return {
    providerKind: normalizeProviderKind(summary.providerKind),
    sourceKey: normalizeSourceKey(summary.sourceKey),
    totalCount: normalizeCount(summary.totalCount),
    updatedCount: normalizeCount(summary.updatedCount),
    unchangedCount: normalizeCount(summary.unchangedCount),
    skippedCount: normalizeCount(summary.skippedCount),
    failedCount: normalizeCount(summary.failedCount),
    newChapterCount: normalizeCount(summary.newChapterCount),
    failureCodes,
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
  const summaryText = AppStrings.format('library_update_summary_counts', newChapterCount, summary.updatedCount, summary.failedCount)
  return {
    checkedAt: summary.checkedAt,
    totalCount: summary.totalCount,
    updatedCount: summary.updatedCount,
    newChapterCount,
    failedCount: summary.failedCount,
    failureCodes,
    summaryText,
    systemDispatchEnabled: isLibraryUpdateNotificationDeliveryEnabled(),
  }
}

export function formatLibraryUpdateNotificationSummary(summary: LibraryUpdateSummary): string {
  const notificationSummary = createLibraryUpdateNotificationSummary(summary)
  if (notificationSummary.failureCodes.length === 0) {
    return notificationSummary.summaryText
  }
  return `${notificationSummary.summaryText} · ${notificationSummary.failureCodes.join(',')}`
}

export async function publishLibraryUpdateNotification(summary: LibraryUpdateSummary): Promise<LibraryUpdateNotificationDispatchResult> {
  const notificationSummary = createLibraryUpdateNotificationSummary(summary)
  if (notificationSummary.newChapterCount <= 0 && notificationSummary.failedCount <= 0) {
    return { delivered: false, code: 'not_needed' }
  }
  const title = notificationSummary.failedCount > 0 && notificationSummary.newChapterCount <= 0
    ? AppStrings.get('library_update_notification_failed_title')
    : AppStrings.get('library_update_notification_title')
  return publishLibraryUpdateNotificationText(title, formatLibraryUpdateNotificationSummary(summary), notificationSummary.checkedAt)
}

export async function publishLibraryUpdateFailureNotification(
  checkedAt: number,
  failureCode: string,
): Promise<LibraryUpdateNotificationDispatchResult> {
  const safeFailureCode = redactLibraryUpdateFailureCode(failureCode)
  return publishLibraryUpdateNotificationText(
    AppStrings.get('library_update_notification_failed_title'),
    safeFailureCode,
    checkedAt,
  )
}

async function publishLibraryUpdateNotificationText(
  title: string,
  text: string,
  checkedAt: number,
): Promise<LibraryUpdateNotificationDispatchResult> {
  if (!isLibraryUpdateNotificationDeliveryEnabled()) {
    return { delivered: false, code: 'disabled' }
  }
  try {
    const enabled = await notificationManager.isNotificationEnabled()
    if (!enabled) {
      return { delivered: false, code: 'disabled' }
    }
    const request: notificationManager.NotificationRequest = {
      id: 3801,
      label: 'koma.library_update',
      appMessageId: `koma.library_update.${checkedAt}`,
      notificationSlotType: notificationManager.SlotType.CONTENT_INFORMATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title,
          text,
        },
      },
    }
    await notificationManager.publish(request)
    return { delivered: true, code: 'delivered' }
  } catch (error) {
    const businessError = error as BusinessError
    console.warn('[LibraryUpdateResultStore] step=publish_library_update_notification_failed code=' + businessError.code)
    return { delivered: false, code: 'publish_failed' }
  }
}

export function serializeLibraryUpdateSummary(summary: LibraryUpdateSummary): string {
  const results = summary.results
    .slice(0, LIBRARY_UPDATE_RESULT_MAX_RESULTS)
    .map((result: LibraryUpdateComicResult): PersistedLibraryUpdateResult => persistLibraryUpdateResult(result))
  const providerSummaries = (summary.providerSummaries.length > 0 ? summary.providerSummaries : summarizeLibraryUpdateProviders(summary.results))
    .slice(0, LIBRARY_UPDATE_RESULT_MAX_PROVIDER_SUMMARIES)
    .map((providerSummary: LibraryUpdateProviderSummary): PersistedLibraryUpdateProviderSummary =>
      persistLibraryUpdateProviderSummary(providerSummary))
  const persisted: PersistedLibraryUpdateSummary = {
    checkedAt: isValidCheckedAt(summary.checkedAt) ? summary.checkedAt : Date.now(),
    totalCount: normalizeCount(summary.totalCount),
    updatedCount: normalizeCount(summary.updatedCount),
    unchangedCount: normalizeCount(summary.unchangedCount),
    skippedCount: normalizeCount(summary.skippedCount),
    failedCount: normalizeCount(summary.failedCount),
    providerSummaries,
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
  const providerKind = stringField(record, 'providerKind')
  const sourceKey = stringField(record, 'sourceKey')
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
    providerKind: normalizeProviderKind(providerKind),
    sourceKey: normalizeSourceKey(sourceKey),
    status: safeStatus,
    previousChapterCount: normalizeCount(previousChapterCount),
    newChapterCount: normalizeCount(newChapterCount),
    message: clampString(sanitizeLibraryUpdateResultMessage(safeStatus, message), LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH),
  }
}

function hydrateLibraryUpdateProviderSummary(value: Object): LibraryUpdateProviderSummary | undefined {
  if (!isRecord(value)) {
    return undefined
  }
  const record = value as Record<string, Object>
  const providerKind = stringField(record, 'providerKind')
  const sourceKey = stringField(record, 'sourceKey')
  const totalCount = numberField(record, 'totalCount')
  const updatedCount = numberField(record, 'updatedCount')
  const unchangedCount = numberField(record, 'unchangedCount')
  const skippedCount = numberField(record, 'skippedCount')
  const failedCount = numberField(record, 'failedCount')
  const newChapterCount = numberField(record, 'newChapterCount')
  const rawFailureCodesObject = record['failureCodes']
  if (totalCount === undefined ||
    updatedCount === undefined ||
    unchangedCount === undefined ||
    skippedCount === undefined ||
    failedCount === undefined ||
    newChapterCount === undefined ||
    !Array.isArray(rawFailureCodesObject)) {
    return undefined
  }
  const failureCodes: string[] = []
  const rawFailureCodes = rawFailureCodesObject as Object[]
  rawFailureCodes.forEach((rawCode: Object) => {
    if (typeof rawCode !== 'string') {
      return
    }
    const code = redactLibraryUpdateFailureCode(rawCode)
    if (!failureCodes.includes(code)) {
      failureCodes.push(code)
    }
  })
  return {
    providerKind: normalizeProviderKind(providerKind),
    sourceKey: normalizeSourceKey(sourceKey),
    totalCount: normalizeCount(totalCount),
    updatedCount: normalizeCount(updatedCount),
    unchangedCount: normalizeCount(unchangedCount),
    skippedCount: normalizeCount(skippedCount),
    failedCount: normalizeCount(failedCount),
    newChapterCount: normalizeCount(newChapterCount),
    failureCodes,
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
    let providerSummaries = summarizeLibraryUpdateProviders(results)
    const rawProviderSummariesObject = record['providerSummaries']
    if (Array.isArray(rawProviderSummariesObject)) {
      const hydratedProviderSummaries: LibraryUpdateProviderSummary[] = []
      const cappedProviderSummaries = (rawProviderSummariesObject as Object[]).slice(0, LIBRARY_UPDATE_RESULT_MAX_PROVIDER_SUMMARIES)
      for (const item of cappedProviderSummaries) {
        const providerSummary = hydrateLibraryUpdateProviderSummary(item)
        if (providerSummary === undefined) {
          return undefined
        }
        hydratedProviderSummaries.push(providerSummary)
      }
      providerSummaries = hydratedProviderSummaries
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
      providerSummaries,
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
    providerSummaries: summary.providerSummaries.map((providerSummary: LibraryUpdateProviderSummary): LibraryUpdateProviderSummary => {
      return {
        providerKind: providerSummary.providerKind,
        sourceKey: providerSummary.sourceKey,
        totalCount: providerSummary.totalCount,
        updatedCount: providerSummary.updatedCount,
        unchangedCount: providerSummary.unchangedCount,
        skippedCount: providerSummary.skippedCount,
        failedCount: providerSummary.failedCount,
        newChapterCount: providerSummary.newChapterCount,
        failureCodes: providerSummary.failureCodes.map((code: string): string => redactLibraryUpdateFailureCode(code)),
      }
    }),
    results: summary.results.map((result: LibraryUpdateComicResult): LibraryUpdateComicResult => cloneLibraryUpdateResult(result)),
  }
}

export function createLibraryUpdateJobSnapshot(
  state: LibraryUpdateJobState,
  updatedAt: number,
  summary?: LibraryUpdateSummary,
  failureCode?: string,
  nextDueAt?: number,
  startedAt?: number,
): LibraryUpdateJobSnapshot {
  const snapshot: LibraryUpdateJobSnapshot = {
    state,
    updatedAt: isValidCheckedAt(updatedAt) ? updatedAt : Date.now(),
    providerSummaries: summary === undefined ? [] : cloneLibraryUpdateSummary(summary).providerSummaries,
  }
  if (startedAt !== undefined && isValidCheckedAt(startedAt)) {
    snapshot.startedAt = startedAt
  }
  if (summary !== undefined) {
    snapshot.finishedAt = summary.checkedAt
    snapshot.summary = cloneLibraryUpdateSummary(summary)
  }
  if (failureCode !== undefined) {
    snapshot.failureCode = redactLibraryUpdateFailureCode(failureCode)
  }
  if (nextDueAt !== undefined && nextDueAt >= 0) {
    snapshot.nextDueAt = normalizeCount(nextDueAt)
  }
  return snapshot
}

export function serializeLibraryUpdateJobSnapshot(snapshot: LibraryUpdateJobSnapshot): string {
  const persisted: PersistedLibraryUpdateJobSnapshot = {
    state: snapshot.state,
    updatedAt: isValidCheckedAt(snapshot.updatedAt) ? snapshot.updatedAt : Date.now(),
    providerSummaries: snapshot.providerSummaries
      .slice(0, LIBRARY_UPDATE_RESULT_MAX_PROVIDER_SUMMARIES)
      .map((providerSummary: LibraryUpdateProviderSummary): PersistedLibraryUpdateProviderSummary =>
        persistLibraryUpdateProviderSummary(providerSummary)),
  }
  if (snapshot.startedAt !== undefined && isValidCheckedAt(snapshot.startedAt)) {
    persisted.startedAt = snapshot.startedAt
  }
  if (snapshot.finishedAt !== undefined && isValidCheckedAt(snapshot.finishedAt)) {
    persisted.finishedAt = snapshot.finishedAt
  }
  if (snapshot.nextDueAt !== undefined && snapshot.nextDueAt >= 0) {
    persisted.nextDueAt = normalizeCount(snapshot.nextDueAt)
  }
  if (snapshot.failureCode !== undefined) {
    persisted.failureCode = redactLibraryUpdateFailureCode(snapshot.failureCode)
  }
  if (snapshot.summary !== undefined) {
    persisted.summary = JSON.parse(serializeLibraryUpdateSummary(snapshot.summary)) as PersistedLibraryUpdateSummary
  }
  return JSON.stringify(persisted)
}

export function hydrateLibraryUpdateJobSnapshotFromJson(jsonText: string): LibraryUpdateJobSnapshot | undefined {
  try {
    const parsed = JSON.parse(jsonText) as Object
    if (!isRecord(parsed)) {
      return undefined
    }
    const record = parsed as Record<string, Object>
    const state = stringField(record, 'state')
    const updatedAt = numberField(record, 'updatedAt')
    if (state === undefined || !isValidJobState(state) || updatedAt === undefined || !isValidCheckedAt(updatedAt)) {
      return undefined
    }
    const rawProviderSummariesObject = record['providerSummaries']
    if (!Array.isArray(rawProviderSummariesObject)) {
      return undefined
    }
    const providerSummaries: LibraryUpdateProviderSummary[] = []
    const cappedProviderSummaries = (rawProviderSummariesObject as Object[]).slice(0, LIBRARY_UPDATE_RESULT_MAX_PROVIDER_SUMMARIES)
    for (const item of cappedProviderSummaries) {
      const providerSummary = hydrateLibraryUpdateProviderSummary(item)
      if (providerSummary === undefined) {
        return undefined
      }
      providerSummaries.push(providerSummary)
    }
    const snapshot: LibraryUpdateJobSnapshot = {
      state: state as LibraryUpdateJobState,
      updatedAt,
      providerSummaries,
    }
    const startedAt = numberField(record, 'startedAt')
    if (startedAt !== undefined && isValidCheckedAt(startedAt)) {
      snapshot.startedAt = startedAt
    }
    const finishedAt = numberField(record, 'finishedAt')
    if (finishedAt !== undefined && isValidCheckedAt(finishedAt)) {
      snapshot.finishedAt = finishedAt
    }
    const nextDueAt = numberField(record, 'nextDueAt')
    if (nextDueAt !== undefined && nextDueAt >= 0) {
      snapshot.nextDueAt = normalizeCount(nextDueAt)
    }
    const failureCode = stringField(record, 'failureCode')
    if (failureCode !== undefined) {
      snapshot.failureCode = redactLibraryUpdateFailureCode(failureCode)
    }
    const summaryObject = record['summary']
    if (isRecord(summaryObject as Object | null)) {
      const summary = hydrateLibraryUpdateSummaryFromJson(JSON.stringify(summaryObject))
      if (summary === undefined) {
        return undefined
      }
      snapshot.summary = summary
    }
    return snapshot
  } catch (_error) {
    return undefined
  }
}

export function setLatestLibraryUpdateSummary(summary: LibraryUpdateSummary): void {
  latestLibraryUpdateSummary = cloneLibraryUpdateSummary(summary)
}

export function clearLatestLibraryUpdateSummary(): void {
  latestLibraryUpdateSummary = undefined
}

export function getLatestLibraryUpdateSummary(): LibraryUpdateSummary | undefined {
  if (latestLibraryUpdateSummary === undefined) {
    return undefined
  }
  return cloneLibraryUpdateSummary(latestLibraryUpdateSummary)
}

export function setLatestLibraryUpdateJobSnapshot(snapshot: LibraryUpdateJobSnapshot): void {
  latestLibraryUpdateJobSnapshot = createLibraryUpdateJobSnapshot(
    snapshot.state,
    snapshot.updatedAt,
    snapshot.summary,
    snapshot.failureCode,
    snapshot.nextDueAt,
    snapshot.startedAt,
  )
}

export function getLatestLibraryUpdateJobSnapshot(): LibraryUpdateJobSnapshot | undefined {
  if (latestLibraryUpdateJobSnapshot === undefined) {
    return undefined
  }
  return createLibraryUpdateJobSnapshot(
    latestLibraryUpdateJobSnapshot.state,
    latestLibraryUpdateJobSnapshot.updatedAt,
    latestLibraryUpdateJobSnapshot.summary,
    latestLibraryUpdateJobSnapshot.failureCode,
    latestLibraryUpdateJobSnapshot.nextDueAt,
    latestLibraryUpdateJobSnapshot.startedAt,
  )
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
    await store.put(LIBRARY_UPDATE_LATEST_JOB_JSON_KEY, serializeLibraryUpdateJobSnapshot(createLibraryUpdateJobSnapshot('success', summary.checkedAt, summary)))
    await store.flush()
  }

  async loadJobSnapshot(): Promise<LibraryUpdateJobSnapshot | undefined> {
    try {
      const store = await this.preferences()
      const jsonText = await store.get(LIBRARY_UPDATE_LATEST_JOB_JSON_KEY, '') as string
      if (jsonText.length === 0) {
        return undefined
      }
      return hydrateLibraryUpdateJobSnapshotFromJson(jsonText)
    } catch (_error) {
      return undefined
    }
  }

  async saveJobSnapshot(snapshot: LibraryUpdateJobSnapshot): Promise<void> {
    const store = await this.preferences()
    if (snapshot.state === 'failed' || snapshot.state === 'backed-off') {
      await store.put(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, '')
    }
    await store.put(LIBRARY_UPDATE_LATEST_JOB_JSON_KEY, serializeLibraryUpdateJobSnapshot(snapshot))
    await store.flush()
  }

  async clear(): Promise<void> {
    const store = await this.preferences()
    await store.put(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, '')
    await store.put(LIBRARY_UPDATE_LATEST_JOB_JSON_KEY, '')
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, LIBRARY_UPDATE_RESULT_STORE_NAME)
  }
}
