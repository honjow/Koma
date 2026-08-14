import { ComicId } from './ComicModels'

/**
 * A source Reader launch is deliberately not a Library `Comic`.  The request
 * contains only the stable source identity and the chapter list already known
 * by the detail page; page descriptors are resolved fresh for every open.
 */
export interface SourceReaderSessionRequest {
  comicId: ComicId
  sourceId: string
  mangaId: string
  title: string
  coverUri?: string
  sourceName?: string
  chapterId: string
  chapterIds: string[]
  chapterTitles?: string[]
}

/**
 * Persisted alongside Reader progress so a source item can reopen from
 * History without becoming a shelf record.  Do not persist page URLs: source
 * page descriptors can contain short-lived URLs or request headers.
 */
export interface SourceReadHistoryEntry {
  comicId: ComicId
  sourceId: string
  mangaId: string
  title: string
  coverUri?: string
  sourceName?: string
  chapterId: string
  chapterTitle?: string
}

function normalizedText(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const normalized = value.trim()
  return normalized.length > 0 ? normalized : undefined
}

function chapterTitleForRequest(request: SourceReaderSessionRequest): string | undefined {
  const index = request.chapterIds.indexOf(request.chapterId)
  if (index < 0) {
    return undefined
  }
  return normalizedText(request.chapterTitles?.[index])
}

export function cloneSourceReaderSessionRequest(request: SourceReaderSessionRequest): SourceReaderSessionRequest {
  const next: SourceReaderSessionRequest = {
    comicId: request.comicId,
    sourceId: request.sourceId,
    mangaId: request.mangaId,
    title: request.title,
    chapterId: request.chapterId,
    chapterIds: request.chapterIds.slice(),
  }
  const coverUri = normalizedText(request.coverUri)
  if (coverUri !== undefined) {
    next.coverUri = coverUri
  }
  const sourceName = normalizedText(request.sourceName)
  if (sourceName !== undefined) {
    next.sourceName = sourceName
  }
  if (request.chapterTitles !== undefined) {
    next.chapterTitles = request.chapterTitles.slice()
  }
  return next
}

export function sourceReaderSessionRequestForChapter(
  request: SourceReaderSessionRequest,
  chapterId: string,
): SourceReaderSessionRequest | undefined {
  const normalizedChapterId = chapterId.trim()
  if (normalizedChapterId.length === 0 || !request.chapterIds.includes(normalizedChapterId)) {
    return undefined
  }
  const next = cloneSourceReaderSessionRequest(request)
  next.chapterId = normalizedChapterId
  return next
}

export function sourceReadHistoryEntryFromRequest(
  request: SourceReaderSessionRequest,
): SourceReadHistoryEntry {
  const entry: SourceReadHistoryEntry = {
    comicId: request.comicId,
    sourceId: request.sourceId,
    mangaId: request.mangaId,
    title: request.title,
    chapterId: request.chapterId,
  }
  const coverUri = normalizedText(request.coverUri)
  if (coverUri !== undefined) {
    entry.coverUri = coverUri
  }
  const sourceName = normalizedText(request.sourceName)
  if (sourceName !== undefined) {
    entry.sourceName = sourceName
  }
  const chapterTitle = chapterTitleForRequest(request)
  if (chapterTitle !== undefined) {
    entry.chapterTitle = chapterTitle
  }
  return entry
}

export function sourceReaderSessionRequestFromHistory(
  entry: SourceReadHistoryEntry,
): SourceReaderSessionRequest | undefined {
  const sourceId = entry.sourceId.trim()
  const mangaId = entry.mangaId.trim()
  const title = entry.title.trim()
  const chapterId = entry.chapterId.trim()
  if (sourceId.length === 0 || mangaId.length === 0 || title.length === 0 || chapterId.length === 0) {
    return undefined
  }
  const request: SourceReaderSessionRequest = {
    comicId: entry.comicId,
    sourceId,
    mangaId,
    title,
    chapterId,
    chapterIds: [chapterId],
  }
  const coverUri = normalizedText(entry.coverUri)
  if (coverUri !== undefined) {
    request.coverUri = coverUri
  }
  const sourceName = normalizedText(entry.sourceName)
  if (sourceName !== undefined) {
    request.sourceName = sourceName
  }
  const chapterTitle = normalizedText(entry.chapterTitle)
  if (chapterTitle !== undefined) {
    request.chapterTitles = [chapterTitle]
  }
  return request
}
