import { AppStrings } from '../i18n/AppStrings'
import { normalizeSourceDisplayText } from './SourceTextNormalizer'

export interface MangaDetail {
  id: string
  title: string
  author?: string
  artist?: string
  description?: string
  coverUrl?: string
  status?: MangaStatus
  tags?: string[]
  sourceId?: string
  sourceName?: string
  chapterCount: number
  isInLibrary: boolean
  url?: string
}

export enum MangaStatus {
  ONGOING = 'ongoing',
  COMPLETED = 'completed',
  HIATUS = 'hiatus',
  CANCELLED = 'cancelled',
  UNKNOWN = 'unknown',
}

export interface MangaChapterItem {
  id: string
  title: string
  chapterNumber?: number
  volumeNumber?: string
  scanlator?: string
  language?: string
  dateUpload?: number
  isRead: boolean
  isDownloaded: boolean
}

export enum ChapterSortOrder {
  NEWEST_FIRST = 'newest_first',
  OLDEST_FIRST = 'oldest_first',
  BY_NUMBER_DESC = 'by_number_desc',
  BY_NUMBER_ASC = 'by_number_asc',
}

type SourceRuntimeRecord = Record<string, Object>

function optionalSourceString(value: Object | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  const normalized = value.trim()
  return normalized.length === 0 ? undefined : normalized
}

function optionalSourceDisplayString(value: Object | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  return normalizeSourceDisplayText(value)
}

function optionalSourceNumber(value: Object | undefined): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (typeof value !== 'string') {
    return undefined
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : undefined
}

function sourceStringList(value: Object | undefined): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const result: string[] = []
  value.forEach((item: Object) => {
    const normalized = optionalSourceDisplayString(item)
    if (normalized !== undefined) {
      result.push(normalized)
    }
  })
  return result.length === 0 ? undefined : result
}

function sourceStatus(value: string | undefined): MangaStatus {
  if (value === MangaStatus.ONGOING ||
    value === MangaStatus.COMPLETED ||
    value === MangaStatus.HIATUS ||
    value === MangaStatus.CANCELLED) {
    return value
  }
  return MangaStatus.UNKNOWN
}

function firstSourceString(values: (string | undefined)[]): string | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index]
    if (value !== undefined && value.trim().length > 0) {
      return value
    }
  }
  return undefined
}

export function parseMangaDetailFromSourceItem(sourceId: string, item: SourceRuntimeRecord): MangaDetail {
  const id = firstSourceString([
    optionalSourceString(item['id']),
    optionalSourceString(item['manga_id']),
    optionalSourceString(item['title']),
  ]) ?? 'source-manga'
  const title = firstSourceString([
    optionalSourceDisplayString(item['title']),
    optionalSourceDisplayString(item['name']),
    normalizeSourceDisplayText(id),
  ]) ?? AppStrings.get('manga_detail_title_fallback')
  return {
    id,
    title,
    author: optionalSourceDisplayString(item['author']),
    artist: optionalSourceDisplayString(item['artist']),
    description: optionalSourceDisplayString(item['description']),
    coverUrl: firstSourceString([
      optionalSourceString(item['cover_url']),
      optionalSourceString(item['coverUrl']),
    ]),
    status: sourceStatus(optionalSourceString(item['status'])),
    tags: sourceStringList(item['tags']),
    sourceId,
    sourceName: sourceId,
    chapterCount: 0,
    isInLibrary: false,
    url: optionalSourceString(item['url']),
  }
}

export function parseMangaChapterFromSourceItem(item: SourceRuntimeRecord): MangaChapterItem {
  const id = firstSourceString([
    optionalSourceString(item['id']),
    optionalSourceString(item['chapter_id']),
    optionalSourceString(item['title']),
  ]) ?? 'source-chapter'
  const chapterNumber = optionalSourceNumber(item['chapter_number']) ?? optionalSourceNumber(item['chapterNumber'])
  return {
    id,
    title: firstSourceString([optionalSourceDisplayString(item['title']), normalizeSourceDisplayText(id)]) ??
      AppStrings.get('manga_detail_chapter_untitled'),
    chapterNumber,
    volumeNumber: firstSourceString([
      optionalSourceString(item['volume_number']),
      optionalSourceString(item['volumeNumber']),
    ]),
    scanlator: optionalSourceDisplayString(item['scanlator']),
    language: firstSourceString([
      optionalSourceString(item['language']),
      optionalSourceString(item['lang']),
    ]),
    dateUpload: optionalSourceNumber(item['date_upload']) ?? optionalSourceNumber(item['dateUpload']),
    isRead: false,
    isDownloaded: false,
  }
}
