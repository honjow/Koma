import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ChapterSortBasis, ChapterSortDirection } from './MangaDetailModels'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { ChapterSortPolicy } from './ChapterSortOrder'
import { connectLanguageState } from '../state/LanguageState'

export enum ChapterReadFilter {
  ALL = 'all', UNREAD = 'unread', READ = 'read', DOWNLOADED = 'downloaded',
}

export interface ChapterListPreferences {
  sortBasis: ChapterSortBasis
  sortDirection: ChapterSortDirection
  readFilter: ChapterReadFilter
  languageFilter: string
  groupFilter: string
  bookmarkFilter: 'all' | 'bookmarked' | 'unbookmarked'
}

const STORE: string = 'koma_chapter_list_preferences_v1'
const KEY: string = 'chapterList.overrides.v1'
let writes: Promise<void> = Promise.resolve()
let decodedPayload: string = '{}'
let decodedPreferences: Record<string, ChapterListPreferences> = {}
const pendingPreferences = new Map<string, ChapterListPreferences>()

function decodeChapterListPreferences(payload: string): Record<string, ChapterListPreferences> {
  // Compare the persisted value so restoring a backup invalidates the same
  // cache as a normal save. Opening a work only reads its own preferences.
  if (payload !== decodedPayload) {
    decodedPreferences = JSON.parse(payload) as Record<string, ChapterListPreferences>
    decodedPayload = payload
  }
  return decodedPreferences
}

export function normalizeChapterListPreferences(value?: ChapterListPreferences): ChapterListPreferences {
  const basis = value?.sortBasis
  return {
    sortBasis: basis === ChapterSortBasis.CHAPTER_NUMBER || basis === ChapterSortBasis.UPLOAD_DATE ||
      basis === ChapterSortBasis.NAME ? basis : ChapterSortBasis.SOURCE_ORDER,
    sortDirection: value?.sortDirection === ChapterSortDirection.REVERSE ? ChapterSortDirection.REVERSE : ChapterSortDirection.FORWARD,
    readFilter: value !== undefined && [ChapterReadFilter.ALL, ChapterReadFilter.UNREAD, ChapterReadFilter.READ,
      ChapterReadFilter.DOWNLOADED].includes(value.readFilter) ? value.readFilter : ChapterReadFilter.ALL,
    languageFilter: typeof value?.languageFilter === 'string' ? value.languageFilter : '',
    groupFilter: typeof value?.groupFilter === 'string' ? value.groupFilter : '',
    bookmarkFilter: value?.bookmarkFilter === 'bookmarked' || value?.bookmarkFilter === 'unbookmarked'
      ? value.bookmarkFilter : 'all',
  }
}

/** Reuse the loaded preference snapshot when opening from history or the shelf. */
export function chapterReadingSortFor(comicId: string): ChapterSortPolicy | undefined {
  const basis = (pendingPreferences.get(comicId) ?? decodedPreferences[comicId])?.sortBasis
  if (basis !== ChapterSortBasis.CHAPTER_NUMBER && basis !== ChapterSortBasis.UPLOAD_DATE &&
    basis !== ChapterSortBasis.NAME) return undefined
  return { basis, locale: basis === ChapterSortBasis.NAME ? connectLanguageState().effectiveLocale || undefined : undefined }
}

/** View preferences belong to the stable comic ID, never to chapter order or reading progress. */
export class ChapterListPreferencesStore {
  private context: common.Context
  constructor(context: common.Context) { this.context = context }

  async prepare(): Promise<void> {
    const store = await preferences.getPreferences(this.context, STORE)
    decodeChapterListPreferences(await store.get(KEY, '{}') as string)
  }

  load(comicId: string): ChapterListPreferences {
    const store = preferences.getPreferencesSync(this.context, { name: STORE })
    const payload = store.getSync(KEY, '{}') as string
    const all = decodeChapterListPreferences(payload)
    return normalizeChapterListPreferences(all[comicId])
  }

  save(comicId: string, value: ChapterListPreferences): Promise<void> {
    if (comicId.length === 0) return Promise.resolve()
    const captured = normalizeChapterListPreferences(value)
    pendingPreferences.set(comicId, captured)
    const run = writes.then(() => BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, STORE)
      const previous = await store.get(KEY, '{}') as string
      const all = JSON.parse(previous) as Record<string, ChapterListPreferences>
      all[comicId] = captured
      const payload = JSON.stringify(all)
      try { await store.put(KEY, payload); await store.flush(); decodeChapterListPreferences(payload) }
      catch (error) { await store.put(KEY, previous); await store.flush(); throw error as Error }
    }))
    writes = run.catch(() => {})
    return run.finally((): void => {
      if (pendingPreferences.get(comicId) === captured) pendingPreferences.delete(comicId)
    })
  }
}
