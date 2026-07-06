import { AppStrings } from '../i18n/AppStrings'
import { normalizeSourceDisplayText, normalizeSourceImageUrl } from './SourceTextNormalizer'

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
  sourceImageId?: string
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
  pageCount?: number
  isRead: boolean
  isDownloaded: boolean
  downloadStatus?: MangaChapterDownloadStatus
}

export type MangaChapterDownloadStatus = 'queued' | 'downloading' | 'downloaded' | 'partial' | 'failed' | 'blocked'

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

function optionalSourceTimestamp(value: Object | undefined): number | undefined {
  const numeric = optionalSourceNumber(value)
  if (numeric !== undefined) {
    return numeric > 0 && numeric < 100000000000 ? numeric * 1000 : numeric
  }
  if (typeof value !== 'string') {
    return undefined
  }
  const parsed = Date.parse(value)
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

function firstSourceDisplayString(values: (Object | undefined)[]): string | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index]
    const direct = optionalSourceDisplayString(value)
    if (direct !== undefined && direct.trim().length > 0) {
      return direct
    }
    const list = sourceStringList(value)
    if (list !== undefined && list.length > 0) {
      return list.join(', ')
    }
  }
  return undefined
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

function nestedSourceString(record: SourceRuntimeRecord, key: string, nestedKey: string): string | undefined {
  const value = record[key]
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  return optionalSourceString((value as SourceRuntimeRecord)[nestedKey])
}

function firstSourceNumber(values: (Object | undefined)[]): number | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = optionalSourceNumber(values[index])
    if (value !== undefined) {
      return value
    }
  }
  return undefined
}

function firstSourceTimestamp(values: (Object | undefined)[]): number | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = optionalSourceTimestamp(values[index])
    if (value !== undefined) {
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
    author: firstSourceDisplayString([item['author'], item['authors']]),
    artist: firstSourceDisplayString([item['artist'], item['artists']]),
    description: firstSourceDisplayString([item['description'], item['summary'], item['synopsis']]),
    coverUrl: normalizeSourceImageUrl(firstSourceString([
      optionalSourceString(item['cover_url']),
      optionalSourceString(item['coverUrl']),
      optionalSourceString(item['cover_uri']),
      optionalSourceString(item['coverUri']),
      optionalSourceString(item['thumbnail']),
      optionalSourceString(item['thumbnailUrl']),
      optionalSourceString(item['imageUrl']),
      optionalSourceString(item['image_url']),
      nestedSourceString(item, 'cover', 'url'),
      nestedSourceString(item, 'cover', 'uri'),
      nestedSourceString(item, 'cover', 'src'),
      nestedSourceString(item, 'cover', 'href'),
      nestedSourceString(item, 'image', 'url'),
      nestedSourceString(item, 'image', 'uri'),
      nestedSourceString(item, 'image', 'src'),
      nestedSourceString(item, 'image', 'href'),
    ])),
    status: sourceStatus(optionalSourceString(item['status'])),
    tags: sourceStringList(item['tags']),
    sourceId,
    sourceImageId: id,
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
  const chapterNumber = firstSourceNumber([
    item['chapter_number'],
    item['chapterNumber'],
    item['chapter'],
    item['index'],
  ])
  return {
    id,
    title: firstSourceString([optionalSourceDisplayString(item['title']), normalizeSourceDisplayText(id)]) ??
      AppStrings.get('manga_detail_chapter_untitled'),
    chapterNumber,
    volumeNumber: firstSourceString([
      optionalSourceString(item['volume_number']),
      optionalSourceString(item['volumeNumber']),
      optionalSourceString(item['volume']),
    ]),
    scanlator: firstSourceDisplayString([
      item['scanlator'],
      item['scanlators'],
      item['group'],
      item['groups'],
    ]),
    language: firstSourceString([
      optionalSourceString(item['language']),
      optionalSourceString(item['lang']),
      optionalSourceString(item['translatedLanguage']),
      optionalSourceString(item['locale']),
    ]),
    dateUpload: firstSourceTimestamp([
      item['date_upload'],
      item['dateUpload'],
      item['uploadDate'],
      item['uploadedAt'],
      item['updatedAt'],
    ]),
    pageCount: firstSourceNumber([
      item['page_count'],
      item['pageCount'],
      item['pages'],
    ]),
    isRead: false,
    isDownloaded: false,
  }
}
