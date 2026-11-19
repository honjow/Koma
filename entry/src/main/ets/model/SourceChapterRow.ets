import { normalizeSourceDisplayText } from './SourceTextNormalizer'
import type { MangaChapterItem } from './MangaDetailModels'

type SourceRuntimeRecord = Record<string, Object>

export function optionalSourceString(value: Object | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  const normalized = value.trim()
  return normalized.length === 0 ? undefined : normalized
}

export function optionalSourceDisplayString(value: Object | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  return normalizeSourceDisplayText(value)
}

export function optionalSourceNumber(value: Object | undefined): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (typeof value !== 'string') {
    return undefined
  }
  if (value.trim().length === 0) {
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

export function sourceStringList(value: Object | undefined): string[] | undefined {
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

export function firstSourceDisplayString(values: (Object | undefined)[]): string | undefined {
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

export function firstSourceString(values: (string | undefined)[]): string | undefined {
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index]
    if (value !== undefined && value.trim().length > 0) {
      return value
    }
  }
  return undefined
}

export function firstSourceNumber(values: (Object | undefined)[]): number | undefined {
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

export function parseSourceChapterRow(item: SourceRuntimeRecord, untitledLabel: string,
  numberedTitleFormat: string): MangaChapterItem {
  const id = firstSourceString([
    optionalSourceString(item['id']),
    optionalSourceString(item['chapter_id']),
    optionalSourceString(item['title']),
  ]) ?? 'source-chapter'
  const hasContinuationContract = item['readingGroup'] !== undefined || item['continuationEligible'] !== undefined
  const chapterNumber = firstSourceNumber([
    item['chapter_number'],
    item['chapterNumber'],
    item['chapter'],
  ])
  const sourceTitle = optionalSourceDisplayString(item['title'])
  const sourceReadingOrder = optionalSourceNumber(item['readingOrder'])
  const readingOrder = sourceReadingOrder !== undefined && sourceReadingOrder >= 0 ? sourceReadingOrder : undefined
  const readingGroup = optionalSourceString(item['readingGroup'])
  const volumeNumber = firstSourceString([
    optionalSourceString(item['volume_number']),
    optionalSourceString(item['volumeNumber']),
    optionalSourceString(item['volume']),
  ])
  return {
    id,
    title: sourceTitle ?? (chapterNumber === undefined
      ? untitledLabel
      : numberedTitleFormat.replace('%s', `${chapterNumber}`)),
    chapterNumber,
    readingOrder,
    readingGroup,
    readingVariantGroup: optionalSourceString(item['readingVariantGroup']),
    readingVariantSequence: optionalSourceString(item['readingVariantSequence']),
    // The complete catalog can supply a position even if this row has no
    // display number. Preserve the source's own eligibility until that point.
    continuationEligible: hasContinuationContract ? item['continuationEligible'] === true &&
      readingGroup !== undefined : undefined,
    volumeNumber,
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
      item['publishedAt'],
      item['published_at'],
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
