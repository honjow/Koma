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
  type: 'select' | 'text' | 'check' | 'sort' | 'multiselect' | 'range' | 'group'
  name: string
  options?: string[]
  optionIds?: string[]
  value?: string | number | boolean | string[]
  minValue?: number
  maxValue?: number
  step?: number
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
  scanlators?: string[]
  group?: string
  groups?: string[]
  lang?: string
  language?: string
  translatedLanguage?: string
  locale?: string
  date_upload?: number | string
  dateUpload?: number | string
  uploadDate?: number | string
  uploadedAt?: number | string
  updatedAt?: number | string
  chapter?: number | string
  index?: number | string
  volume?: number | string
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
  min?: number | string
  max?: number | string
  step?: number | string
  filters?: SourceRuntimeFilterPayload[]
}

interface SourceRuntimeFiltersPayload {
  filters?: SourceRuntimeFilterPayload[]
  items?: SourceRuntimeFilterPayload[]
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

function optionalTimestamp(value: number | string | undefined): number | undefined {
  const numeric = optionalNumber(value)
  if (numeric !== undefined) {
    return numeric > 0 && numeric < 100000000000 ? numeric * 1000 : numeric
  }
  if (typeof value !== 'string') {
    return undefined
  }
  const parsed = Date.parse(value)
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

function firstNumber(values: (number | string | undefined)[]): number | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = optionalNumber(values[index])
    if (value !== undefined) {
      return value
    }
  }
  return undefined
}

function firstTimestamp(values: (number | string | undefined)[]): number | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = optionalTimestamp(values[index])
    if (value !== undefined) {
      return value
    }
  }
  return undefined
}

function firstNonEmptyList(values: (string | string[] | undefined)[]): string | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index]
    if (typeof value === 'string') {
      const normalized = normalizeSourceDisplayText(value)
      if (normalized !== undefined) {
        return normalized
      }
    } else if (Array.isArray(value)) {
      const normalizedValues: string[] = []
      value.forEach((item: string) => {
        const normalized = normalizeSourceDisplayText(item)
        if (normalized !== undefined) {
          normalizedValues.push(normalized)
        }
      })
      if (normalizedValues.length > 0) {
        return normalizedValues.join(', ')
      }
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
        scanlator: firstNonEmptyList([row.scanlator, row.scanlators, row.group, row.groups]),
        language: optionalString(firstNonEmpty([row.language, row.lang, row.translatedLanguage, row.locale])),
        dateUpload: firstTimestamp([row.date_upload, row.dateUpload, row.uploadDate, row.uploadedAt, row.updatedAt]),
        chapterNumber: firstNumber([row.chapterNumber, row.chapter, row.index]),
        volumeNumber: firstNumber([row.volumeNumber, row.volume]),
        url: optionalString(row.url),
      }
    })
  } catch (_err) {
    return []
  }
}

function normalizeFilterType(value: string | undefined): 'select' | 'text' | 'check' | 'sort' | 'multiselect' | 'range' | 'group' {
  if (value === 'select' || value === 'text' || value === 'sort' || value === 'range' || value === 'group') {
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
    const filters: SourceFilter[] = []
    appendSourceFilters(filters, payload.filters ?? (payload.items ?? []))
    return filters
  } catch (_err) {
    return []
  }
}

function appendSourceFilters(target: SourceFilter[], rows: SourceRuntimeFilterPayload[]): void {
  rows.forEach((row: SourceRuntimeFilterPayload) => {
    const type = normalizeFilterType(row.type ?? row.kind)
    if (type === 'group') {
      appendSourceFilters(target, row.filters ?? [])
      return
    }
    const name = firstNonEmpty([row.name, row.label, row.id]) ?? AppStrings.get('common_filter')
    target.push({
      id: firstNonEmpty([row.id, row.name, row.label]) ?? name,
      type,
      name,
      options: normalizeFilterOptions(row.options),
      optionIds: normalizeFilterOptionIds(row.options),
      value: row.value,
      minValue: optionalNumber(row.min),
      maxValue: optionalNumber(row.max),
      step: optionalNumber(row.step),
    })
  })
}
