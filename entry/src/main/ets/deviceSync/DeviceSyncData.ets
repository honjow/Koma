import { SyncEdit, SyncFact, SyncGroup, isSyncReplica, syncVisibleValue, syncObserves } from './DeviceSyncFacts'
import { isSyncDigest } from './DeviceSyncWire'
import { syncDefaultCaseFold } from './DeviceSyncCaseFold'

export const SYNC_OFFICIAL_CATALOG = 'https://github.com/honjow/koma-sources/releases/latest/download/index.json'
export const SYNC_CATALOG_ID = 'honjow/koma-sources'
export const SYNC_READING_DATASET = 'reading-records'
export const SYNC_SHELF_DATASET = 'shelf-records'
export const MANGADEX_SYNC_SOURCE = 'org.mangadex.koma'
export const XKCD_SYNC_SOURCE = 'com.xkcd.zh.koma'
const UUID_TEXT = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const MANGADEX_WORK = new RegExp('^mdx:' + UUID_TEXT + '$')
const XKCD_GROUP = /^xkcd:zh:g:([1-9][0-9]{3}(0[0-9]|1[0-2]))$/
const READING_CREDENTIAL_PARAMETER = /(?:^|[/?&#;])(?:[a-z0-9_.-]*(?:token|secret|password|signature|credential)[a-z0-9_.-]*|auth|authorization|cookie|key|api[_-]?key|access[_-]?key|sign|sig|ticket|session(?:[_-]?id)?|hdnts|hdnea|hmac|policy|key-pair-id|x-amz-[^=&#;]+|x-goog-[^=&#;]+)\s*=/i

export interface SyncWorkLabel {
  title: string
  sourceName: string
  sourceVersion?: string // Legacy shelf label.
  workUrl?: string
}

export interface SyncShelfMove {
  toSource: string
  toWork: string
  categories?: string[]
}

export interface SyncRecentValue {
  title: string
  sourceName: string
  sourceVersion?: string // Kept when reading the legacy dataset.
  chapter: string
  chapterTitle: string
  date: number
  savedPage?: number
  workUrl?: string
}

export interface SyncPositionValue {
  page: number
  total: number
  date?: number
  pageTable?: string // Kept when reading the legacy dataset.
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

function safeReadingId(value: string, max: number = 512): boolean {
  if (!checkText(value, max)) return false
  let decoded = value
  for (let pass = 0; pass < 3; pass++) {
    const next = decoded.replace(/%([0-7][0-9a-f])/gi, (_match: string, hex: string): string => String.fromCharCode(parseInt(hex, 16)))
    if (next === decoded) break
    decoded = next
  }
  // Some chapter IDs include a path, stable query parameters or a title.
  // Exclude credentials and local paths from these IDs, independently of source.
  return checkText(decoded, max) && !READING_CREDENTIAL_PARAMETER.test(decoded) &&
    !/(?:^|:)file:\/\/|\/\/[^/?#\s]*@|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/i.test(decoded)
}

export function syncReadingIdentity(source: string, work: string, chapter?: string): boolean {
  return typeof source === 'string' && source.length <= 96 && source.trim() === source && safeReadingId(source) &&
    safeReadingId(work) && (chapter === undefined || safeReadingId(chapter))
}

export function syncReadingPosition(page: number, total: number, date?: number): SyncPositionValue | undefined {
  if (!Number.isSafeInteger(page) || !Number.isSafeInteger(total) || page < 0 || page >= total) return undefined
  return { page, total, date: date !== undefined && validateDate(date) ? date : undefined }
}

function safeReadingWorkUrl(value: string): boolean {
  return /^https?:\/\/[a-z0-9.-]+(?::[0-9]{1,5})?(?:[/?#][^\s\\"<>]*)?$/i.test(value) && safeReadingId(value, 4096)
}

export function syncReadingRecent(source: string, chapter: string, date: number, title: string,
  sourceName: string, chapterTitle: string, savedPage?: number, workUrl?: string): SyncRecentValue {
  return { title: syncPublicLabel(title.slice(0, 240), 240) || source,
    sourceName: syncPublicLabel(sourceName.slice(0, 80), 80) || source.slice(0, 80), chapter,
    chapterTitle: syncPublicLabel(chapterTitle.slice(0, 240), 240), date: validateDate(date) ? date : 0, savedPage,
    workUrl: workUrl !== undefined && safeReadingWorkUrl(workUrl) ? workUrl : undefined }
}

export function syncShelfLabel(source: string, title: string, sourceName: string, workUrl: string): SyncWorkLabel {
  return { title: syncPublicLabel(title.slice(0, 240), 240) || syncPublicLabel(source, 96) || '—',
    sourceName: syncPublicLabel(sourceName.slice(0, 80), 80) || syncPublicLabel(source.slice(0, 80), 80) || '—',
    workUrl: safeReadingWorkUrl(workUrl) ? workUrl : undefined }
}

export function syncShelfMove(value: string | undefined): SyncShelfMove | undefined {
  if (value === undefined || value === '') return undefined
  const move = JSON.parse(value) as SyncShelfMove
  return onlyFields(move, move?.categories === undefined ? 'toSource,toWork' : 'categories,toSource,toWork') &&
    syncShelfIdentity(move.toSource, move.toWork) &&
    (move.categories === undefined || (Array.isArray(move.categories) && move.categories.length <= 1024 &&
      move.categories.every(validCategory) && new Set<string>(move.categories).size === move.categories.length)) ? move : undefined
}

export function syncShelfIdentity(source: string, work: string): boolean {
  // Runtime package IDs cannot be the prefixes of local or private server rows.
  return syncReadingIdentity(source, work) && !['local', 'komga', 'kavita', 'opds', 'webdav'].includes(source.toLowerCase())
}

/** Resolve chains against accepted facts. A removed or cyclic destination
 * never authorizes a shelf removal. */
export function syncShelfMoveDestination(key: string, visible: (key: string) => string | undefined,
  known: (key: string) => boolean): SyncShelfMove | undefined {
  const visited = new Set<string>([key])
  let move = syncShelfMove(visible(key))
  while (move !== undefined) {
    const target = syncKey(['book', move.toSource, move.toWork])
    if (visited.has(target)) return undefined
    visited.add(target)
    const value = visible(target)
    if (value === undefined || value === '') return undefined
    const next = syncShelfMove(value)
    if (next === undefined) {
      const destination = move
      if (destination.categories?.some((category: string): boolean => {
        const member = syncKey(['member', destination.toSource, destination.toWork, category])
        return !known(member) || (visible(member) !== undefined &&
          category !== 'builtin-favorite' && category !== 'builtin-read-later' &&
          !known(syncKey(['category', category])))
      })) return undefined
      const categories = destination.categories?.filter((category: string): boolean =>
        visible(syncKey(['member', destination.toSource, destination.toWork, category])) !== undefined &&
        (category === 'builtin-favorite' || category === 'builtin-read-later' ||
          visible(syncKey(['category', category])) !== undefined))
      return { toSource: move.toSource, toWork: move.toWork, categories }
    }
    move = next
  }
  return undefined
}

export function syncGroupVisibleValue(group: SyncGroup, fact: SyncFact): string | undefined {
  const value = syncVisibleValue(fact)
  if (group !== 'shelf' || !fact.key.startsWith('["book",') ||
    !fact.barriers.some((edit: SyncEdit): boolean => syncShelfMove(edit.value) !== undefined)) return value
  // A move only replaces the shelf entry the sender observed. A separate
  // explicit re-add on a device that has not seen it wins over the move.
  const deletes = fact.barriers.filter((edit: SyncEdit): boolean => edit.kind === 'delete')
  const concurrent = fact.values.filter((edit: SyncEdit): boolean => !syncObserves(fact.cleared, edit.version) &&
    deletes.every((barrier: SyncEdit): boolean => syncObserves(edit.observed, barrier.version)))
  return concurrent[concurrent.length - 1]?.value ?? value
}

function isSourceWork(parts: string[]): boolean {
  return syncWorksOnSource(parts[1], parts[2])
}

function validCategory(value: string): boolean {
  return isSyncReplica(value) || value === 'builtin-favorite' || value === 'builtin-read-later'
}

function onlyFields(value: Object, keys: string): boolean {
  return value !== null && value !== undefined && typeof value === 'object' &&
    Object.keys(value).sort().join(',') === keys
}

function validLabelText(label: SyncRecentValue | SyncWorkLabel): boolean {
  return typeof label.title === 'string' && label.title === syncPublicLabel(label.title, 240) && label.title.length > 0 &&
    typeof label.sourceName === 'string' && label.sourceName === syncPublicLabel(label.sourceName, 80) && label.sourceName.length > 0
}

function validLabel(label: SyncWorkLabel, source: string): boolean {
  return validLabelText(label) && typeof label.sourceVersion === 'string' && /^\d+\.\d+\.\d+$/.test(label.sourceVersion) &&
    (!syncKnownSource(source) || syncSupportedSource(source, label.sourceVersion))
}

function validateDate(date: number): boolean {
  return Number.isSafeInteger(date) && date >= 0 && date <= 4102444800000
}

function validShelfValue(parts: string[], value: Object, legacy: boolean): boolean {
  if (parts[0] === 'book') {
    const label = value as SyncWorkLabel
    if (legacy || label?.sourceVersion !== undefined) {
      return onlyFields(value, 'sourceName,sourceVersion,title') && isSourceWork(parts) && validLabel(label, parts[1])
    }
    return onlyFields(value, label?.workUrl === undefined ? 'sourceName,title' : 'sourceName,title,workUrl') &&
      validLabelText(label) && (label.workUrl === undefined ||
        typeof label.workUrl === 'string' && safeReadingWorkUrl(label.workUrl))
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
    if (row === null || typeof row !== 'object') return false
    const fields = 'chapter,chapterTitle,date,' + (row.savedPage === undefined ? '' : 'savedPage,') +
      'sourceName,' + (row.sourceVersion === undefined ? '' : 'sourceVersion,') + 'title' +
      (row.workUrl === undefined ? '' : ',workUrl')
    if (!onlyFields(value, fields) || row.savedPage !== undefined &&
      (!Number.isSafeInteger(row.savedPage) || row.savedPage < 0)) return false
    return validLabelText(row) && typeof row.chapter === 'string' && syncReadingIdentity(parts[1], parts[2], row.chapter) &&
      (row.sourceVersion === undefined || (typeof row.sourceVersion === 'string' && /^\d+\.\d+\.\d+$/.test(row.sourceVersion))) &&
      (row.workUrl === undefined || (typeof row.workUrl === 'string' && safeReadingWorkUrl(row.workUrl))) &&
      typeof row.chapterTitle === 'string' &&
      (row.chapterTitle === '' || row.chapterTitle === syncPublicLabel(row.chapterTitle, 240)) && validateDate(row.date)
  }
  if (parts[0] === 'position') {
    const row = value as SyncPositionValue
    const fields = (row?.date === undefined ? '' : 'date,') + 'page,' + (row?.pageTable === undefined ? '' : 'pageTable,') + 'total'
    return onlyFields(value, fields) && syncReadingPosition(row.page, row.total) !== undefined &&
      (row.date === undefined || validateDate(row.date)) && (row.pageTable === undefined || isSyncDigest(row.pageTable))
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

function validKey(group: SyncGroup, parts: string[], legacyShelf: boolean): boolean {
  const kind = parts[0]
  if (group === 'shelf') {
    const work = (kind === 'book' || kind === 'member') &&
      (legacyShelf ? isSourceWork(parts) : syncShelfIdentity(parts[1], parts[2]))
    return (kind === 'book' && parts.length === 3 && work) ||
      (kind === 'member' && parts.length === 4 && work && validCategory(parts[3])) ||
      (kind === 'category' && parts.length === 2 && isSyncReplica(parts[1])) || (kind === 'order' && parts.length === 1)
  }
  if (group === 'reading') {
    return ((kind === 'recent' && parts.length === 3) ||
      (['position', 'read', 'bookmark'].includes(kind) && parts.length === 4)) &&
      syncReadingIdentity(parts[1], parts[2], parts[3])
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

export function checkSyncGroupFact(group: SyncGroup, fact: SyncFact, legacyShelf: boolean = false): void {
  const parts = syncKeyParts(fact.key)
  if (!validKey(group, parts, legacyShelf)) throw new Error('sync_update_required')
  fact.values.concat(fact.barriers).forEach((edit: SyncEdit): void => {
    if (edit.kind === 'delete') return
    const value = JSON.parse(edit.value) as Object
    let valid = false
    if (group === 'shelf' && edit.kind === 'reset' && parts[0] === 'book' && !legacyShelf) {
      const move = syncShelfMove(edit.value)
      if (move === undefined || move.toSource === parts[1] && move.toWork === parts[2]) throw new Error('sync_unsupported_value')
      return
    }
    if (group === 'shelf') valid = validShelfValue(parts, value, legacyShelf)
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
