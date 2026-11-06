import { SyncEdit, SyncFact, SyncGroup, isSyncReplica } from './DeviceSyncFacts'
import { isSyncDigest } from './DeviceSyncWire'
import { syncDefaultCaseFold } from './DeviceSyncCaseFold'

export const SYNC_OFFICIAL_CATALOG = 'https://github.com/honjow/koma-sources/releases/latest/download/index.json'
export const SYNC_CATALOG_ID = 'honjow/koma-sources'
export const MANGADEX_SYNC_SOURCE = 'org.mangadex.koma'
export const XKCD_SYNC_SOURCE = 'com.xkcd.zh.koma'
const UUID_TEXT = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const MANGADEX_WORK = new RegExp('^mdx:' + UUID_TEXT + '$')
const MANGADEX_CHAPTER = new RegExp('^ch:' + UUID_TEXT + '$')
const XKCD_GROUP = /^xkcd:zh:g:([1-9][0-9]{3}(0[0-9]|1[0-2]))$/
const SOURCE_ID = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/

export interface SyncWorkLabel {
  title: string
  sourceName: string
  sourceVersion: string
}

export interface SyncRecentValue extends SyncWorkLabel {
  chapter: string
  chapterTitle: string
  date: number
  savedPage?: number
}

export interface SyncPositionValue {
  page: number
  total: number
  pageTable: string
}

export interface SyncReaderMode {
  mode: string
  direction: string
}

export interface SyncSubscription {
  address: string
  label: string
}

export interface SyncSearchValue {
  text: string
  date: number
}

export function syncSupportedSource(source: string, version: string): boolean {
  return (source === MANGADEX_SYNC_SOURCE && version === '0.1.25') ||
    (source === XKCD_SYNC_SOURCE && version === '0.1.7')
}

export function syncKnownSource(source: string): boolean {
  return source === MANGADEX_SYNC_SOURCE || source === XKCD_SYNC_SOURCE
}

export function syncWorksOnSource(source: string, work: string): boolean {
  if (source === MANGADEX_SYNC_SOURCE) return MANGADEX_WORK.test(work)
  if (source === XKCD_SYNC_SOURCE) return work === 'xkcd:zh' || XKCD_GROUP.test(work)
  return false
}

export function syncChapterBelongsToSource(source: string, work: string, chapter: string): boolean {
  if (!syncWorksOnSource(source, work)) return false
  if (source === MANGADEX_SYNC_SOURCE) return MANGADEX_CHAPTER.test(chapter)
  if (work === 'xkcd:zh') return /^xkcdch:zh:[1-9][0-9]{0,9}$/.test(chapter)
  const group = XKCD_GROUP.exec(work)
  return group !== null && new RegExp('^xkcdch:zh:g:' + group[1] + ':[1-9][0-9]{0,9}$').test(chapter)
}

export function syncKey(parts: string[]): string {
  return JSON.stringify(parts)
}

export function syncKeyParts(key: string): string[] {
  const parts = JSON.parse(key) as string[]
  if (!Array.isArray(parts) || parts.length < 1 || parts.length > 5 ||
    parts.some((part: string): boolean => typeof part !== 'string' || part.length < 1 || part.length > 512) ||
    syncKey(parts) !== key) throw new Error('sync_invalid_key')
  return parts
}

export function syncBucketKey(key: string): string {
  const parts = syncKeyParts(key)
  if (['book', 'member', 'recent', 'position', 'read', 'bookmark', 'book-mode'].includes(parts[0])) {
    return syncKey(parts.slice(1, 3))
  }
  return key
}

function checkText(value: string, max: number, allowEmpty: boolean = false): boolean {
  return typeof value === 'string' && value.length <= max && (allowEmpty || value.trim().length > 0) &&
    !/[\u0000-\u001f\u007f]/.test(value)
}

export function syncPublicLabel(value: string, max: number): string {
  const text = value.replace(/[\u0000-\u001f\u007f]/g, ' ').trim()
  if (!checkText(text, max) || /:\/\/|(?:password|token|cookie|secret)\s*[:=]/i.test(text)) return ''
  return text
}

function isSourceWork(parts: string[], hasChapter: boolean = false): boolean {
  if (!SOURCE_ID.test(parts[1])) return false
  if (!syncKnownSource(parts[1])) {
    return /^[a-zA-Z0-9:._-]{1,256}$/.test(parts[2]) &&
      (!hasChapter || /^[a-zA-Z0-9:._-]{1,256}$/.test(parts[3]))
  }
  return hasChapter ? syncChapterBelongsToSource(parts[1], parts[2], parts[3]) : syncWorksOnSource(parts[1], parts[2])
}

function validCategory(value: string): boolean {
  return isSyncReplica(value) || value === 'builtin-favorite' || value === 'builtin-read-later'
}

function onlyFields(value: Object, keys: string): boolean {
  return value !== null && value !== undefined && typeof value === 'object' &&
    Object.keys(value).sort().join(',') === keys
}

function validLabel(label: SyncWorkLabel, source: string): boolean {
  return typeof label.title === 'string' && label.title === syncPublicLabel(label.title, 240) && label.title.length > 0 &&
    typeof label.sourceName === 'string' && label.sourceName === syncPublicLabel(label.sourceName, 80) && label.sourceName.length > 0 &&
    typeof label.sourceVersion === 'string' && /^\d+\.\d+\.\d+$/.test(label.sourceVersion) &&
    (!syncKnownSource(source) || syncSupportedSource(source, label.sourceVersion))
}

function validateDate(date: number): boolean {
  return Number.isSafeInteger(date) && date >= 0 && date <= 4102444800000
}

function validShelfValue(parts: string[], value: Object): boolean {
  if (parts[0] === 'book') {
    return onlyFields(value, 'sourceName,sourceVersion,title') && validLabel(value as SyncWorkLabel, parts[1])
  }
  if (parts[0] === 'member') return value === true
  if (parts[0] === 'category') return checkText(value as string, 40)
  const ordered = value as string[]
  return Array.isArray(ordered) && ordered.length <= 1024 && ordered.every(validCategory) &&
    new Set<string>(ordered).size === ordered.length
}

function validReadingValue(parts: string[], value: Object): boolean {
  if (parts[0] === 'recent') {
    const row = value as SyncRecentValue
    const fields = row?.savedPage === undefined ? 'chapter,chapterTitle,date,sourceName,sourceVersion,title' :
      'chapter,chapterTitle,date,savedPage,sourceName,sourceVersion,title'
    if (!onlyFields(value, fields) || row.savedPage !== undefined &&
      (!Number.isSafeInteger(row.savedPage) || row.savedPage < 0 || row.savedPage >= 10000)) return false
    return validLabel(row, parts[1]) && isSourceWork([parts[0], parts[1], parts[2], row.chapter], true) &&
      typeof row.chapterTitle === 'string' &&
      (row.chapterTitle === '' || row.chapterTitle === syncPublicLabel(row.chapterTitle, 240)) && validateDate(row.date)
  }
  if (parts[0] === 'position') {
    if (!onlyFields(value, 'page,pageTable,total')) return false
    const row = value as SyncPositionValue
    return Number.isSafeInteger(row.page) && Number.isSafeInteger(row.total) && row.page >= 0 &&
      row.page < row.total && row.total <= 10000 && isSyncDigest(row.pageTable)
  }
  return typeof value === 'boolean'
}

function validPreferenceValue(parts: string[], value: Object): boolean {
  if (parts[0] === 'book-mode' || parts[1] === 'mode') {
    if (!onlyFields(value, 'direction,mode')) return false
    const mode = value as SyncReaderMode
    return ['single_page', 'double_page', 'continuous_scroll', 'vertical_page'].includes(mode.mode) &&
      ['left_to_right', 'right_to_left', 'webtoon'].includes(mode.direction) &&
      (mode.direction !== 'webtoon' || mode.mode === 'continuous_scroll')
  }
  if (parts[1] === 'image-fit') return ['contain', 'fit_width', 'fit_height'].includes(value as string)
  return typeof value === 'boolean'
}

export function safeSyncSearch(text: string): boolean {
  return checkText(text, 240) && !/:\/\/|\b(?:token|password|cookie|secret|bearer|authorization)\s*[=:\s]|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|[:=()<>]|&&|\|\|/i.test(text)
}

export function syncSearchIdentity(text: string): string {
  return syncDefaultCaseFold(text.trim().replace(/\s+/g, ' ').normalize('NFC')).normalize('NFC')
}

function validKey(group: SyncGroup, parts: string[]): boolean {
  const kind = parts[0]
  if (group === 'shelf') {
    return (kind === 'book' && parts.length === 3 && isSourceWork(parts)) ||
      (kind === 'member' && parts.length === 4 && isSourceWork(parts) && validCategory(parts[3])) ||
      (kind === 'category' && parts.length === 2 && isSyncReplica(parts[1])) || (kind === 'order' && parts.length === 1)
  }
  if (group === 'reading') {
    return (kind === 'recent' && parts.length === 3 && isSourceWork(parts)) ||
      (['position', 'read', 'bookmark'].includes(kind) && parts.length === 4 && isSourceWork(parts, true))
  }
  if (group === 'reader-settings') {
    return (kind === 'book-mode' && parts.length === 3 && isSourceWork(parts)) ||
      (kind === 'global' && parts.length === 2 && ['mode', 'animation', 'page-number', 'image-fit'].includes(parts[1]))
  }
  if (group === 'source-subscriptions') {
    return kind === 'catalog' && parts.length === 2 && parts[1] === SYNC_CATALOG_ID
  }
  return kind === 'query' && parts.length === 3 && safeSyncSearch(parts[1]) &&
    parts[2].split(',').every((source: string): boolean => syncKnownSource(source))
}

export function checkSyncGroupFact(group: SyncGroup, fact: SyncFact): void {
  const parts = syncKeyParts(fact.key)
  if (['book', 'member', 'recent', 'position', 'read', 'bookmark', 'book-mode'].includes(parts[0]) &&
    !syncKnownSource(parts[1])) throw new Error('sync_update_required')
  if (!validKey(group, parts)) throw new Error('sync_update_required')
  fact.values.concat(fact.barriers).forEach((edit: SyncEdit): void => {
    if (edit.kind === 'delete') return
    const value = JSON.parse(edit.value) as Object
    let valid = false
    if (group === 'shelf') valid = validShelfValue(parts, value)
    else if (group === 'reading') valid = validReadingValue(parts, value)
    else if (group === 'reader-settings') valid = validPreferenceValue(parts, value)
    else if (group === 'source-subscriptions') {
      const subscription = value as SyncSubscription
      valid = onlyFields(value, 'address,label') && subscription.address === SYNC_OFFICIAL_CATALOG &&
        checkText(subscription.label, 120, true)
    } else {
      const search = value as SyncSearchValue
      valid = onlyFields(value, 'date,text') && safeSyncSearch(search.text) && syncSearchIdentity(search.text) === parts[1] &&
        validateDate(search.date)
    }
    if (!valid || (edit.kind === 'reset' && (group !== 'reading' || !['position', 'read'].includes(parts[0])))) {
      throw new Error('sync_unsupported_value')
    }
  })
}
