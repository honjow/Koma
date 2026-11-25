import { ComicSourceKind, ReaderSeriesFormat } from '../model/ComicModels'
import { SourceReaderSessionRequest } from '../model/SourceReaderSession'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'

export const CONTINUATION_SCHEMA_VERSION: number = 1
// Target devices older than this versionCode cannot decode reader continuation payloads.
export const CONTINUATION_MIN_TARGET_VERSION_CODE: number = 28
export const CONTINUATION_SESSION_ID_PARAM: string = 'koma.continuation.sessionId'

export interface ReaderContinuationPayload {
  schemaVersion: number
  sourceId: string
  sourceName: string
  mangaId: string
  mangaUrl?: string
  comicId: string
  title: string
  coverUri?: string
  readingFormat?: ReaderSeriesFormat
  chapterId: string
  chapterTitle?: string
  pageIndex: number
  totalPages: number
  requiresPrivacyAuth: boolean
  privateCategoryId?: string
  sourceVersion?: string
  timestamp: number
}

export interface ReaderContinuationEligibilityInput {
  continuationEnabled: boolean
  readerOpen: boolean
  readerClosing: boolean
  readerRouteVisible: boolean
  readerSessionLoading: boolean
  continuedAway: boolean
  incognitoEnabled: boolean
  sourceIncognitoEnabled: boolean
  privacyLocked: boolean
  sourceKind?: ComicSourceKind
  sourceId?: string
  mangaId?: string
  chapterId?: string
}

function normalizedString(value: Object | undefined): string {
  return typeof value === 'string' ? value.trim() : ''
}

function optionalNormalizedString(value: Object | undefined): string | undefined {
  const normalized = normalizedString(value)
  return normalized.length > 0 ? normalized : undefined
}

function nonNegativeInt(value: Object | undefined, fallback: number = 0): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback
  return Math.max(0, Math.floor(value))
}

export function canContinueSourceSession(input: ReaderContinuationEligibilityInput): boolean {
  if (!input.continuationEnabled) return false
  if (!input.readerOpen || input.readerClosing || !input.readerRouteVisible || input.readerSessionLoading) return false
  if (input.continuedAway || input.incognitoEnabled || input.sourceIncognitoEnabled || input.privacyLocked) return false
  if (input.sourceKind !== undefined && input.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY) return false
  const sourceId = input.sourceId?.trim() ?? ''
  const mangaId = input.mangaId?.trim() ?? ''
  const chapterId = input.chapterId?.trim() ?? ''
  return sourceId.length > 0 && !sourceId.startsWith('mihon:') && mangaId.length > 0 && chapterId.length > 0
}

export function isContinuationTargetVersionCompatible(
  targetVersion: Object | undefined,
  minVersionCode: number = CONTINUATION_MIN_TARGET_VERSION_CODE,
): boolean {
  if (typeof targetVersion !== 'number' || !Number.isFinite(targetVersion)) return true
  return targetVersion >= minVersionCode
}

export function encodeReaderContinuationPayload(payload: ReaderContinuationPayload): string {
  return JSON.stringify(payload)
}

export function decodeReaderContinuationPayload(raw: Object | undefined): ReaderContinuationPayload | undefined {
  if (typeof raw !== 'string' || raw.trim().length === 0) return undefined
  let parsed: Record<string, Object>
  try {
    const decoded = JSON.parse(raw) as Object
    if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) return undefined
    parsed = decoded as Record<string, Object>
  } catch (_error) {
    return undefined
  }
  const schemaVersion = nonNegativeInt(parsed['schemaVersion'], 0)
  if (schemaVersion !== CONTINUATION_SCHEMA_VERSION) return undefined
  const sourceId = normalizedString(parsed['sourceId'])
  const mangaId = normalizedString(parsed['mangaId'])
  const chapterId = normalizedString(parsed['chapterId'])
  const title = normalizedString(parsed['title'])
  if (sourceId.length === 0 || sourceId.startsWith('mihon:') ||
    mangaId.length === 0 || chapterId.length === 0 || title.length === 0) return undefined
  const comicId = sourceLibraryComicId(sourceId, mangaId)
  const sentComicId = optionalNormalizedString(parsed['comicId'])
  if (sentComicId !== undefined && sentComicId !== comicId) return undefined
  const sourceName = optionalNormalizedString(parsed['sourceName']) ?? sourceId
  const formatRaw = parsed['readingFormat']
  const readingFormat: ReaderSeriesFormat | undefined =
    formatRaw === 'manga' ? 'manga' : (formatRaw === 'webtoon' ? 'webtoon' : undefined)
  const payload: ReaderContinuationPayload = {
    schemaVersion,
    sourceId,
    sourceName,
    mangaId,
    comicId,
    title,
    chapterId,
    pageIndex: nonNegativeInt(parsed['pageIndex'], 0),
    totalPages: nonNegativeInt(parsed['totalPages'], 0),
    requiresPrivacyAuth: parsed['requiresPrivacyAuth'] === true,
    timestamp: nonNegativeInt(parsed['timestamp'], 0),
  }
  const mangaUrl = optionalNormalizedString(parsed['mangaUrl'])
  if (mangaUrl !== undefined) payload.mangaUrl = mangaUrl
  const coverUri = optionalNormalizedString(parsed['coverUri'])
  if (coverUri !== undefined) payload.coverUri = coverUri
  if (readingFormat !== undefined) payload.readingFormat = readingFormat
  const chapterTitle = optionalNormalizedString(parsed['chapterTitle'])
  if (chapterTitle !== undefined) payload.chapterTitle = chapterTitle
  const privateCategoryId = optionalNormalizedString(parsed['privateCategoryId'])
  if (privateCategoryId !== undefined) payload.privateCategoryId = privateCategoryId
  const sourceVersion = optionalNormalizedString(parsed['sourceVersion'])
  if (sourceVersion !== undefined) payload.sourceVersion = sourceVersion
  return payload
}

export function resolveContinuationPageIndex(requestedPageIndex: number, actualTotalPages: number): number {
  const safePage = Number.isFinite(requestedPageIndex) ? Math.max(0, Math.floor(requestedPageIndex)) : 0
  if (!Number.isFinite(actualTotalPages) || actualTotalPages <= 0) return safePage
  return Math.min(safePage, actualTotalPages - 1)
}

export function buildSourceRequestFromContinuation(payload: ReaderContinuationPayload): SourceReaderSessionRequest {
  const request: SourceReaderSessionRequest = {
    comicId: payload.comicId,
    sourceId: payload.sourceId,
    mangaId: payload.mangaId,
    title: payload.title,
    chapterId: payload.chapterId,
    chapterIds: [payload.chapterId],
    chaptersResolved: false,
  }
  if (payload.mangaUrl !== undefined && payload.mangaUrl.length > 0) request.mangaUrl = payload.mangaUrl
  if (payload.coverUri !== undefined && payload.coverUri.length > 0) request.coverUri = payload.coverUri
  if (payload.sourceName.length > 0) request.sourceName = payload.sourceName
  if (payload.readingFormat !== undefined) request.readingFormat = payload.readingFormat
  if (payload.chapterTitle !== undefined && payload.chapterTitle.length > 0) {
    request.chapterTitles = [payload.chapterTitle]
  }
  return request
}
