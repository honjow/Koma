import { AppStrings } from '../i18n/AppStrings'
import { normalizeSourceDisplayText } from './SourceTextNormalizer'

export type SourceMangaStatus = 'ongoing' | 'completed' | 'hiatus' | 'cancelled' | 'unknown'

export interface SourceManga {
  id: string
  sourceId: string
  title: string
  author?: string
  artist?: string
  description?: string
  coverUrl?: string
  status?: SourceMangaStatus
  contentRating?: string
  tags?: string[]
  url?: string
}

export interface SourceMangaList {
  manga: SourceManga[]
  hasNextPage: boolean
  nextCursor?: string
}

export interface SourceChapter {
  id: string
  title: string
  scanlator?: string
  language?: string
  dateUpload?: number
  chapterNumber?: number
  volumeNumber?: number
  url?: string
}

export interface SourceFilter {
  id: string
  type: 'select' | 'text' | 'check' | 'sort' | 'multiselect' | 'group'
  name: string
  options?: string[]
  optionIds?: string[]
  value?: string | number | boolean | string[]
}

interface SourceRuntimeCoverPayload {
  url?: string
  kind?: string
}

interface SourceRuntimeMangaPayload {
  id?: string
  title?: string
  subtitle?: string
  author?: string
  artist?: string
  description?: string
  coverUrl?: string
  cover?: SourceRuntimeCoverPayload
  authors?: string[]
  artists?: string[]
  status?: string
  contentRating?: string
  tags?: string[]
  sourceTags?: string[]
  url?: string
}

interface SourceRuntimePagePayload {
  hasMore?: boolean
  hasNextPage?: boolean
  nextCursor?: string | null
}

interface SourceRuntimeMangaListPayload {
  manga?: SourceRuntimeMangaPayload[]
  items?: SourceRuntimeMangaPayload[]
  hasNextPage?: boolean
  page?: SourceRuntimePagePayload
}

interface SourceRuntimeChapterPayload {
  id?: string
  title?: string
  scanlator?: string
  lang?: string
  language?: string
  date_upload?: number | string
  dateUpload?: number | string
  chapterNumber?: number | string
  volumeNumber?: number | string
  url?: string
}

interface SourceRuntimeChapterListPayload {
  chapters?: SourceRuntimeChapterPayload[]
  items?: SourceRuntimeChapterPayload[]
}

interface SourceRuntimeFilterOptionPayload {
  label?: string
  name?: string
  id?: string
}

interface SourceRuntimeFilterPayload {
  id?: string
  type?: string
  kind?: string
  name?: string
  label?: string
  options?: string[] | SourceRuntimeFilterOptionPayload[]
  value?: string | number | boolean | string[]
}

interface SourceRuntimeFiltersPayload {
  filters?: SourceRuntimeFilterPayload[]
}

function normalizeSourceMangaStatus(value: string | undefined): SourceMangaStatus {
  if (value === 'ongoing' || value === 'completed' || value === 'hiatus' || value === 'cancelled') {
    return value
  }
  return 'unknown'
}

function optionalString(value: string | undefined): string | undefined {
  if (value === undefined || value.trim().length === 0) {
    return undefined
  }
  return value
}

function optionalNumber(value: number | string | undefined): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (typeof value !== 'string') {
    return undefined
  }
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : undefined
}

function firstNonEmpty(values: (string | undefined)[]): string | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const normalized = optionalString(values[index])
    if (normalized !== undefined) {
      return normalized
    }
  }
  return undefined
}

function normalizeTags(payload: SourceRuntimeMangaPayload): string[] | undefined {
  const source = payload.tags !== undefined ? payload.tags : payload.sourceTags
  if (source === undefined) {
    return undefined
  }
  const tags: string[] = []
  source.forEach((tag: string) => {
    const normalized = normalizeSourceDisplayText(tag)
    if (normalized !== undefined) {
      tags.push(normalized)
    }
  })
  return tags.length === 0 ? undefined : tags
}

export function normalizeSourceManga(sourceId: string, payload: SourceRuntimeMangaPayload): SourceManga {
  const title = firstNonEmpty([payload.title, payload.subtitle, payload.id]) ?? AppStrings.get('manga_detail_title_fallback')
  return {
    id: firstNonEmpty([payload.id, title]) ?? title,
    sourceId,
    title: normalizeSourceDisplayText(title) ?? title,
    author: normalizeSourceDisplayText(firstNonEmpty([payload.author, payload.authors === undefined ? undefined : payload.authors.join(', ')])),
    artist: normalizeSourceDisplayText(firstNonEmpty([payload.artist, payload.artists === undefined ? undefined : payload.artists.join(', ')])),
    description: normalizeSourceDisplayText(payload.description),
    coverUrl: firstNonEmpty([payload.coverUrl, payload.cover === undefined ? undefined : payload.cover.url]),
    status: normalizeSourceMangaStatus(payload.status),
    contentRating: optionalString(payload.contentRating),
    tags: normalizeTags(payload),
    url: optionalString(payload.url),
  }
}

export function parseSourceMangaListJson(sourceId: string, json: string): SourceMangaList {
  try {
    const payload = JSON.parse(json) as SourceRuntimeMangaListPayload
    const rows = payload.manga !== undefined ? payload.manga : (payload.items ?? [])
    const hasNextPage = payload.hasNextPage === true ||
      payload.page?.hasMore === true ||
      payload.page?.hasNextPage === true ||
      payload.page?.nextCursor !== undefined && payload.page?.nextCursor !== null
    return {
      manga: rows.map((row: SourceRuntimeMangaPayload): SourceManga => normalizeSourceManga(sourceId, row)),
      hasNextPage,
      nextCursor: optionalString(payload.page?.nextCursor === null ? undefined : payload.page?.nextCursor),
    }
  } catch (_err) {
    return { manga: [], hasNextPage: false }
  }
}

export function parseSourceChaptersJson(json: string): SourceChapter[] {
  try {
    const payload = JSON.parse(json) as SourceRuntimeChapterListPayload
    const rows = payload.chapters !== undefined ? payload.chapters : (payload.items ?? [])
    return rows.map((row: SourceRuntimeChapterPayload): SourceChapter => {
      const title = firstNonEmpty([row.title, row.id]) ?? AppStrings.get('manga_detail_chapter_untitled')
      return {
        id: firstNonEmpty([row.id, row.title]) ?? 'chapter',
        title: normalizeSourceDisplayText(title) ?? title,
        scanlator: normalizeSourceDisplayText(row.scanlator),
        language: optionalString(firstNonEmpty([row.language, row.lang])),
        dateUpload: optionalNumber(row.date_upload) ?? optionalNumber(row.dateUpload),
        chapterNumber: optionalNumber(row.chapterNumber),
        volumeNumber: optionalNumber(row.volumeNumber),
        url: optionalString(row.url),
      }
    })
  } catch (_err) {
    return []
  }
}

function normalizeFilterType(value: string | undefined): 'select' | 'text' | 'check' | 'sort' | 'multiselect' | 'group' {
  if (value === 'select' || value === 'text' || value === 'sort' || value === 'group') {
    return value
  }
  if (value === 'multiselect' || value === 'multi-select' || value === 'multiSelect') {
    return 'multiselect'
  }
  if (value === 'boolean' || value === 'check') {
    return 'check'
  }
  return 'text'
}

function normalizeFilterOptions(options: string[] | SourceRuntimeFilterOptionPayload[] | undefined): string[] | undefined {
  if (options === undefined) {
    return undefined
  }
  const labels: string[] = []
  options.forEach((option: string | SourceRuntimeFilterOptionPayload) => {
    if (typeof option === 'string') {
      labels.push(option)
      return
    }
    labels.push(firstNonEmpty([option.label, option.name, option.id]) ?? '')
  })
  return labels.filter((label: string): boolean => label.trim().length > 0)
}

function normalizeFilterOptionIds(options: string[] | SourceRuntimeFilterOptionPayload[] | undefined): string[] | undefined {
  if (options === undefined) {
    return undefined
  }
  const ids: string[] = []
  options.forEach((option: string | SourceRuntimeFilterOptionPayload) => {
    if (typeof option === 'string') {
      ids.push(option)
      return
    }
    ids.push(firstNonEmpty([option.id, option.label, option.name]) ?? '')
  })
  return ids.filter((id: string): boolean => id.trim().length > 0)
}

export function parseSourceFiltersJson(json: string): SourceFilter[] {
  try {
    const payload = JSON.parse(json) as SourceRuntimeFiltersPayload
    return (payload.filters ?? []).map((row: SourceRuntimeFilterPayload): SourceFilter => {
      const name = firstNonEmpty([row.name, row.label, row.id]) ?? AppStrings.get('common_filter')
      return {
        id: firstNonEmpty([row.id, row.name, row.label]) ?? name,
        type: normalizeFilterType(row.type ?? row.kind),
        name,
        options: normalizeFilterOptions(row.options),
        optionIds: normalizeFilterOptionIds(row.options),
        value: row.value,
      }
    })
  } catch (_err) {
    return []
  }
}
