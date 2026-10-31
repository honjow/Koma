import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ChapterSortBasis, ChapterSortDirection } from './MangaDetailModels'
import { BackupRestoreActivity } from './BackupRestoreActivity'

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

export function normalizeChapterListPreferences(value?: ChapterListPreferences): ChapterListPreferences {
  return {
    sortBasis: value?.sortBasis === ChapterSortBasis.CHAPTER_NUMBER ? ChapterSortBasis.CHAPTER_NUMBER : ChapterSortBasis.SOURCE_ORDER,
    sortDirection: value?.sortDirection === ChapterSortDirection.REVERSE ? ChapterSortDirection.REVERSE : ChapterSortDirection.FORWARD,
    readFilter: value !== undefined && [ChapterReadFilter.ALL, ChapterReadFilter.UNREAD, ChapterReadFilter.READ,
      ChapterReadFilter.DOWNLOADED].includes(value.readFilter) ? value.readFilter : ChapterReadFilter.ALL,
    languageFilter: typeof value?.languageFilter === 'string' ? value.languageFilter : '',
    groupFilter: typeof value?.groupFilter === 'string' ? value.groupFilter : '',
    bookmarkFilter: value?.bookmarkFilter === 'bookmarked' || value?.bookmarkFilter === 'unbookmarked'
      ? value.bookmarkFilter : 'all',
  }
}

/** View preferences belong to the stable comic ID, never to chapter order or reading progress. */
export class ChapterListPreferencesStore {
  private context: common.Context
  constructor(context: common.Context) { this.context = context }

  async prepare(): Promise<void> { await preferences.getPreferences(this.context, STORE) }

  load(comicId: string): ChapterListPreferences {
    const store = preferences.getPreferencesSync(this.context, { name: STORE })
    const payload = store.getSync(KEY, '{}') as string
    const all = JSON.parse(payload) as Record<string, ChapterListPreferences>
    return normalizeChapterListPreferences(all[comicId])
  }

  save(comicId: string, value: ChapterListPreferences): Promise<void> {
    if (comicId.length === 0) return Promise.resolve()
    const captured = normalizeChapterListPreferences(value)
    const run = writes.then(() => BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, STORE)
      const previous = await store.get(KEY, '{}') as string
      const all = JSON.parse(previous) as Record<string, ChapterListPreferences>
      all[comicId] = captured
      try { await store.put(KEY, JSON.stringify(all)); await store.flush() }
      catch (error) { await store.put(KEY, previous); await store.flush(); throw error as Error }
    }))
    writes = run.catch(() => {})
    return run
  }
}
