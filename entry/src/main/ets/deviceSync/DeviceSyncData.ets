import { SyncEdit, SyncFact, SyncGroup, isSyncReplica, syncVisibleHeads, syncVisibleValue, syncObserves } from './DeviceSyncFacts'
import { isSyncDigest, syncDigest } from './DeviceSyncWire'
import { syncDefaultCaseFold } from './DeviceSyncCaseFold'
import type { LibrarySmartFilter } from '../model/LibrarySmartCategory'

/** Bulk projection is asynchronous but each synchronous chunk still shares the UI event loop. */
export class SyncWorkSlice {
  private deadline: number = Date.now() + 6

  pause(): Promise<void> | undefined {
    if (Date.now() < this.deadline) return undefined
    return new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => {
        this.deadline = Date.now() + 6
        resolve()
      }, 0)
    })
  }
}

export const SYNC_OFFICIAL_CATALOG = 'https://github.com/honjow/koma-sources/releases/latest/download/index.json'
export const SYNC_CATALOG_ID = 'honjow/koma-sources'
export const SYNC_READING_DATASET = 'reading-records'
export const SYNC_SHELF_DATASET = 'shelf-records'
export const SYNC_SHELF_CATALOG_DATASET = 'shelf-catalog-records'
export const SYNC_SMART_CATEGORIES_DATASET = 'shelf-smart-categories'
export const SYNC_READER_SETTINGS_DATASET = 'reader-settings-records'
export const SYNC_SUBSCRIPTIONS_DATASET = 'source-subscriptions-records'
export const SYNC_SEARCH_DATASET = 'search-history-records'
export const CATEGORY_SYNC_PREFIX = 'custom_sync_'
const READING_CREDENTIAL_PARAMETER = /(?:^|[/?&#;])(?:[a-z0-9_.-]*(?:token|secret|password|signature|credential)[a-z0-9_.-]*|auth|authorization|cookie|key|api[_-]?key|access[_-]?key|sign|sig|ticket|session(?:[_-]?id)?|hdnts|hdnea|hmac|policy|key-pair-id|x-amz-[^=&#;]+|x-goog-[^=&#;]+)\s*=/i

export interface SyncWorkLabel {
  title: string
  sourceName: string
  sourceVersion?: string // Legacy shelf label.
  workUrl?: string
}

export interface SyncChapterCatalog {
  digest: string
  count: number
  blocks: number
  date: number
}

export interface SyncShelfMove {
  toSource: string
  toWork: string
  categories?: string[]
}

export interface SyncSmartCategory {
  name: string
  order: number
  createdAt: number
  filters: LibrarySmartFilter[]
}

export function syncStableId(text: string): string {
  const hash = syncDigest(text)
  return hash.substring(0, 8) + '-' + hash.substring(8, 12) + '-' + hash.substring(12, 16) + '-' +
    hash.substring(16, 20) + '-' + hash.substring(20, 32)
}

// Older backups and Huawei Cloud rows used the timestamp ID while WebDAV
// received its deterministic UUID. Both now refer to the same stored rule.
export function smartCategoryStorageId(id: string): string {
  return isSyncReplica(id.slice('smart:'.length)) ? id : 'smart:' + syncStableId('smart-category:' + id)
}

export function syncSharedCategoryId(replica: string, local: string): string {
  return syncStableId(replica + ':category:' + local)
}

// The exact name stored by legacy receivers, including trimming at 40 characters.
export function syncNumberedCategoryName(name: string, index: string): string {
  const suffix = ' (' + index + ')'
  return name.trim().replace(/\s+/g, ' ').substring(0, 40 - suffix.length).trimEnd() + suffix
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

export interface SyncReadingWorkProgress {
  recent: SyncRecentValue
  position?: SyncPositionValue
  chapter: string
  page: number
  total: number
  date: number
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
  if (['book', 'member', 'recent', 'position', 'read', 'bookmark', 'book-mode', 'cover'].includes(parts[0])) {
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
  if (!checkText(text, max)) return ''
  return text
}

// Source/work/chapter IDs are opaque business identities; matching words such
// as "key" in them must not make an otherwise valid reading silently disappear.
function safeReadingId(value: string, max: number = 512): boolean {
  return checkText(value, max)
}

function safeSharedWorkUrl(value: string, max: number): boolean {
  if (!checkText(value, max)) return false
  let decoded = value
  for (let pass = 0; pass < 3; pass++) {
    const next = decoded.replace(/%([0-7][0-9a-f])/gi, (_match: string, hex: string): string => String.fromCharCode(parseInt(hex, 16)))
    if (next === decoded) break
    decoded = next
  }
  // A work URL is optional display/navigation metadata; do not copy one that
  // carries account credentials into another device's shared data.
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
  return /^https?:\/\/(?:[a-z0-9.-]+|\[[0-9a-f:.]+\])(?::[0-9]{1,5})?(?:[/?#][^\s\\"<>]*)?$/i.test(value) &&
    safeSharedWorkUrl(value, 4096)
}

export function syncReadingWorkAddress(value: string | undefined): string | undefined {
  return value !== undefined && safeReadingWorkUrl(value) ? value : undefined
}

export function syncCoverAddress(value: string | undefined): string | undefined {
  if (value === undefined || value.length > 2048 || !safeReadingWorkUrl(value)) return undefined
  // The source may be hosted on the user's LAN; preserve its actual address.
  return value
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
  return syncReadingIdentity(source, work)
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
  const heads = syncVisibleHeads(fact)
  const value = syncVisibleValue(fact, heads)
  const kind = syncKeyParts(fact.key)[0]
  // A concurrent edit can keep a category private. An explicit later edit
  // that has observed that change can still make it public.
  if (kind === 'category-privacy' && heads.some((edit: SyncEdit): boolean => edit.value === 'true')) return 'true'
  if (value !== undefined && (kind === 'recent' || kind === 'position' || kind === 'query' || kind === 'chapter-catalog')) {
    // A single head or fallback reset already won. Only concurrent values need date comparison.
    if (heads.length <= 1) return value
    let best = value
    let date = (JSON.parse(best) as SyncRecentValue).date ?? 0
    for (let i = 0; i < heads.length - 1; i++) {
      const candidate = heads[i]
      const nextDate = (JSON.parse(candidate.value) as SyncRecentValue).date ?? 0
      if (nextDate > date) { date = nextDate; best = candidate.value }
    }
    return best
  }
  if (group !== 'shelf' || !fact.key.startsWith('["book",') ||
    !fact.barriers.some((edit: SyncEdit): boolean => syncShelfMove(edit.value) !== undefined)) return value
  // A move only replaces the shelf entry the sender observed. A separate
  // explicit re-add on a device that has not seen it wins over the move.
  const deletes = fact.barriers.filter((edit: SyncEdit): boolean => edit.kind === 'delete')
  const concurrent = fact.values.filter((edit: SyncEdit): boolean => !syncObserves(fact.cleared, edit.version) &&
    deletes.every((barrier: SyncEdit): boolean => syncObserves(edit.observed, barrier.version)))
  return concurrent[concurrent.length - 1]?.value ?? value
}

/** One work's visible resume position, shared by full and targeted reads. */
export function syncReadingWorkProgress(facts: SyncFact[], source: string, work: string): SyncReadingWorkProgress | undefined {
  return syncReadingProgressFromValues(source, work, (key: string): string | undefined => {
    const fact = facts.find((row: SyncFact): boolean => row.key === key)
    return fact === undefined ? undefined : syncGroupVisibleValue('reading', fact)
  })
}

export function syncReadingProgressFromValues(source: string, work: string,
  value: (key: string) => string | undefined): SyncReadingWorkProgress | undefined {
  const recentValue = value(syncKey(['recent', source, work]))
  if (recentValue === undefined) return undefined
  const recent = JSON.parse(recentValue) as SyncRecentValue
  const positionValue = value(syncKey(['position', source, work, recent.chapter]))
  const position = positionValue === undefined ? undefined : JSON.parse(positionValue) as SyncPositionValue
  return { recent, position, chapter: recent.chapter, page: position?.page ?? recent.savedPage ?? 0,
    total: position?.total ?? 0, date: position?.date ?? recent.date }
}

// A timestamp alone may come from opening stale history. Only a complete
// remote save, whose history and chapter page agree, can replace the local resume.
export function hasNewerCompleteRemoteReading(local: SyncReadingWorkProgress, remote: SyncReadingWorkProgress,
  localTarget?: SyncPositionValue): boolean {
  const saved = local.position
  const position = remote.position
  return saved?.date !== undefined && saved.date > 0 && position?.date !== undefined && position.date > saved.date &&
    position.date >= (localTarget?.date ?? 0) && (local.recent.savedPage === undefined || local.recent.savedPage === saved.page) &&
    position.date === remote.recent.date && remote.recent.savedPage === position.page
}

export type ContinuationResumeDecision = 'remote' | 'local' | 'ask'

/** Decide how continuation resume reconciles a conflict without rewinding to an older cloud page. */
export function continuationResumeResolution(local: SyncReadingWorkProgress,
  remote: SyncReadingWorkProgress): ContinuationResumeDecision {
  if (remote.date <= local.date) return 'local'
  if (remote.chapter !== local.chapter || remote.page >= local.page) return 'remote'
  return 'ask'
}

function isSourceWork(parts: string[]): boolean {
  return syncReadingIdentity(parts[1], parts[2])
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

function validLabel(label: SyncWorkLabel): boolean {
  return validLabelText(label) && typeof label.sourceVersion === 'string' && /^\d+\.\d+\.\d+$/.test(label.sourceVersion)
}

function validateDate(date: number): boolean {
  return Number.isSafeInteger(date) && date >= 0 && date <= 4102444800000
}

function validShelfValue(parts: string[], value: Object, legacy: boolean): boolean {
  if (parts[0] === 'smart-category') {
    const category = value as SyncSmartCategory
    if (!onlyFields(value, 'createdAt,filters,name,order') || !checkText(category.name, 40) ||
      !Number.isSafeInteger(category.order) || category.order < 0 || !validateDate(category.createdAt) ||
      !Array.isArray(category.filters) || category.filters.length === 0) return false
    const rules = new Set<string>()
    return category.filters.every((rule: LibrarySmartFilter): boolean => {
      if (rule === null || typeof rule !== 'object' || typeof rule.exclude !== 'boolean') return false
      const takesValue = rule.method === 'category' || rule.method === 'source' || rule.method === 'contentRating'
      if (!onlyFields(rule, takesValue ? 'exclude,method,value' : 'exclude,method')) return false
      if (takesValue) {
        if (rule.value === undefined || !checkText(rule.value, 512) ||
          (rule.method === 'category' && rule.value !== 'uncategorized' && !validCategory(rule.value))) return false
      } else if (!['downloaded', 'tracking', 'hasUnread', 'started', 'completed'].includes(rule.method)) return false
      const key = syncKey([rule.method, rule.value ?? '-'])
      if (rules.has(key)) return false
      rules.add(key)
      return true
    })
  }
  if (parts[0] === 'chapter-catalog') {
    const catalog = value as SyncChapterCatalog
    return onlyFields(value, 'blocks,count,date,digest') && isSyncDigest(catalog.digest) && validateDate(catalog.date) &&
      Number.isSafeInteger(catalog.count) && Number.isSafeInteger(catalog.blocks) && catalog.count >= 0 && catalog.count <= 1000000 &&
      catalog.blocks >= 0 && catalog.blocks <= catalog.count
  }
  if (parts[0] === 'chapter-catalog-block') {
    const ids = value as string[]
    return Array.isArray(ids) && ids.length > 0 && ids.every((id: string): boolean => syncReadingIdentity(parts[1], parts[2], id))
  }
  if (parts[0] === 'book') {
    const label = value as SyncWorkLabel
    if (legacy || label?.sourceVersion !== undefined) {
      return onlyFields(value, 'sourceName,sourceVersion,title') && isSourceWork(parts) && validLabel(label)
    }
    return onlyFields(value, label?.workUrl === undefined ? 'sourceName,title' : 'sourceName,title,workUrl') &&
      validLabelText(label) && (label.workUrl === undefined ||
        typeof label.workUrl === 'string' && safeReadingWorkUrl(label.workUrl))
  }
  if (parts[0] === 'member') return value === true
  if (parts[0] === 'category') return checkText(value as string, 40)
  if (parts[0] === 'category-privacy') return typeof value === 'boolean'
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
  return checkText(text, 240) && !/:\/\/|\b(?:token|password|cookie|secret|bearer|authorization)\s*[=:\s]|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/i.test(text)
}

export function syncCatalogAddress(value: string): boolean {
  return checkText(value, 2048) && /^https?:\/\/[^@?#\s\\/]+(?:\/[^?#\s\\]*)?$/i.test(value)
}

export function syncCatalogRecordKey(identity: string): string {
  return syncKey(['catalog', syncDigest(identity)])
}

/** Translate the original subscription key as wire data, not a permission rule. */
export function syncBusinessKey(group: SyncGroup, key: string): string {
  const parts = syncKeyParts(key)
  if (group === 'source-subscriptions' && parts[0] === 'catalog' && parts[1] === SYNC_CATALOG_ID) {
    return syncCatalogRecordKey(SYNC_OFFICIAL_CATALOG)
  }
  // A legacy search deletion only observed its own source scope. Keeping the
  // old key prevents it from deleting an independent same-term record.
  return key
}

export function syncSearchIdentity(text: string): string {
  return syncDefaultCaseFold(text.trim().replace(/\s+/g, ' ').normalize('NFC')).normalize('NFC')
}

function validKey(group: SyncGroup, parts: string[], legacyShelf: boolean): boolean {
  const kind = parts[0]
  if (kind === 'cover') return !legacyShelf && (group === 'shelf' || group === 'reading') &&
    parts.length === 3 && isSourceWork(parts)
  if (group === 'shelf') {
    if (kind === 'smart-category') return !legacyShelf && parts.length === 2 && isSyncReplica(parts[1])
    if (kind === 'category-privacy') return !legacyShelf && parts.length === 2 && isSyncReplica(parts[1])
    if (kind === 'chapter-catalog' || kind === 'chapter-catalog-block') {
      return !legacyShelf && isSourceWork(parts) && ((kind === 'chapter-catalog' && parts.length === 3) ||
        (kind === 'chapter-catalog-block' && parts.length === 5 && isSyncDigest(parts[3]) && /^\d+$/.test(parts[4])))
    }
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
    return kind === 'catalog' && parts.length === 2 && (isSyncDigest(parts[1]) || parts[1] === SYNC_CATALOG_ID)
  }
  return kind === 'query' && (parts.length === 2 || parts.length === 3) && safeSyncSearch(parts[1]) &&
    (parts.length === 2 || parts[2].split(',').every((source: string): boolean => syncReadingIdentity(source, 'query')))
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
    if (parts[0] === 'cover') valid = typeof value === 'string' && syncCoverAddress(value as string) !== undefined
    else if (group === 'shelf') valid = validShelfValue(parts, value, legacyShelf)
    else if (group === 'reading') valid = validReadingValue(parts, value)
    else if (group === 'reader-settings') valid = validPreferenceValue(parts, value)
    else if (group === 'source-subscriptions') {
      const subscription = value as SyncSubscription
      valid = onlyFields(value, 'address,label') && syncCatalogAddress(subscription.address) &&
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
