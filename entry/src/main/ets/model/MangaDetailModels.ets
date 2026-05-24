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
    if (typeof item === 'string' && item.trim().length > 0) {
      result.push(item)
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
    optionalSourceString(item['title']),
    optionalSourceString(item['name']),
    id,
  ]) ?? '未命名漫画'
  return {
    id,
    title,
    author: optionalSourceString(item['author']),
    artist: optionalSourceString(item['artist']),
    description: optionalSourceString(item['description']),
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
    title: firstSourceString([optionalSourceString(item['title']), id]) ?? '未命名章节',
    chapterNumber,
    volumeNumber: firstSourceString([
      optionalSourceString(item['volume_number']),
      optionalSourceString(item['volumeNumber']),
    ]),
    scanlator: optionalSourceString(item['scanlator']),
    dateUpload: optionalSourceNumber(item['date_upload']) ?? optionalSourceNumber(item['dateUpload']),
    isRead: false,
    isDownloaded: false,
  }
}
