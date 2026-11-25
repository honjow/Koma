import { SourceMangaWebLink, sourceMangaWebUrl } from './MangaWebLink'
import { AppStrings } from '../i18n/AppStrings'
import { normalizeSourceDisplayText, normalizeSourceImageUrl } from './SourceTextNormalizer'
import { optionalSourceString, optionalSourceDisplayString, sourceStringList, firstSourceDisplayString,
  firstSourceString, firstSourceNumber, parseSourceChapterRow } from './SourceChapterRow'
import { ChapterReadSequenceEntry } from './ReaderChapterSequence'
import { SourceManga } from './SourceModels'

export interface MangaDetail {
  contentRating?: string
  id: string
  title: string
  author?: string
  artist?: string
  description?: string
  coverUrl?: string
  status?: MangaStatus
  tags?: string[]
  relatedManga?: SourceManga[]
  sourceId?: string
  sourceImageId?: string
  sourceName?: string
  chapterCount: number
  isInLibrary: boolean
  url?: string
  webUrl?: string
}

export function copyMangaDetail(detail: MangaDetail): MangaDetail {
  return {
    contentRating: detail.contentRating,
    id: detail.id,
    title: detail.title,
    author: detail.author,
    artist: detail.artist,
    description: detail.description,
    coverUrl: detail.coverUrl,
    status: detail.status,
    tags: detail.tags?.slice(),
    relatedManga: detail.relatedManga?.slice(),
    sourceId: detail.sourceId,
    sourceImageId: detail.sourceImageId,
    sourceName: detail.sourceName,
    chapterCount: detail.chapterCount,
    isInLibrary: detail.isInLibrary,
    url: detail.url,
    webUrl: detail.webUrl,
  }
}

export function sameMangaDetail(a: MangaDetail, b: MangaDetail): boolean {
  if (a === b) return true
  if (a.contentRating !== b.contentRating || a.id !== b.id || a.title !== b.title ||
    a.author !== b.author || a.artist !== b.artist || a.description !== b.description ||
    a.coverUrl !== b.coverUrl || a.status !== b.status || a.sourceId !== b.sourceId ||
    a.sourceImageId !== b.sourceImageId || a.sourceName !== b.sourceName ||
    a.chapterCount !== b.chapterCount || a.isInLibrary !== b.isInLibrary ||
    a.url !== b.url || a.webUrl !== b.webUrl) return false
  const aTags = a.tags ?? []
  const bTags = b.tags ?? []
  if ((a.tags === undefined) !== (b.tags === undefined) || aTags.length !== bTags.length) return false
  for (let i = 0; i < aTags.length; i++) if (aTags[i] !== bTags[i]) return false
  const aRel = a.relatedManga ?? []
  const bRel = b.relatedManga ?? []
  if ((a.relatedManga === undefined) !== (b.relatedManga === undefined) || aRel.length !== bRel.length) return false
  if (aRel.length > 0 && JSON.stringify(aRel) !== JSON.stringify(bRel)) return false
  return true
}

export enum MangaStatus {
  ONGOING = 'ongoing',
  COMPLETED = 'completed',
  HIATUS = 'hiatus',
  CANCELLED = 'cancelled',
  UNKNOWN = 'unknown',
}

export interface MangaChapterItem extends ChapterReadSequenceEntry {
  id: string
  title: string
  chapterNumber?: number
  volumeNumber?: string
  readingOrder?: number
  readingGroup?: string
  readingVariantGroup?: string
  readingVariantSequence?: string
  continuationEligible?: boolean
  scanlator?: string
  language?: string
  dateUpload?: number
  pageCount?: number
  isRead: boolean
  isBookmarked?: boolean
  isDownloaded: boolean
  downloadStatus?: MangaChapterDownloadStatus
  downloadProgress?: string
}

export type MangaChapterDownloadStatus = 'queued' | 'downloading' | 'downloaded' | 'partial' | 'failed' | 'blocked' |
  'paused' | 'waiting_wifi' | 'waiting_network' | 'canceling'

export enum ChapterSortBasis {
  SOURCE_ORDER = 'source_order',
  CHAPTER_NUMBER = 'chapter_number',
  UPLOAD_DATE = 'upload_date',
  NAME = 'name',
}

export enum ChapterSortDirection {
  FORWARD = 'forward',
  REVERSE = 'reverse',
}

type SourceRuntimeRecord = Record<string, Object>

function sourceStatus(value: string | undefined): MangaStatus {
  if (value === MangaStatus.ONGOING ||
    value === MangaStatus.COMPLETED ||
    value === MangaStatus.HIATUS ||
    value === MangaStatus.CANCELLED) {
    return value
  }
  return MangaStatus.UNKNOWN
}

function nestedSourceString(record: SourceRuntimeRecord, key: string, nestedKey: string): string | undefined {
  const value = record[key]
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  return optionalSourceString((value as SourceRuntimeRecord)[nestedKey])
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
    contentRating: optionalSourceString(item['contentRating'] ?? item['content_rating']),
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
    webUrl: sourceMangaWebUrl(item['links'] as SourceMangaWebLink[] | undefined, optionalSourceString(item['url'])),
  }
}

export function parseMangaChapterFromSourceItem(item: SourceRuntimeRecord): MangaChapterItem {
  return parseSourceChapterRow(item, AppStrings.get('manga_detail_chapter_untitled'),
    AppStrings.get('library_update_chapter_fallback_title'))
}
