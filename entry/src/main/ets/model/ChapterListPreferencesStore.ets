import { common } from '@kit.AbilityKit'
import { ChapterSortBasis, ChapterSortDirection } from './MangaDetailModels'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { ChapterSortPolicy } from './ChapterSortOrder'
import { connectLanguageState } from '../state/LanguageState'
import { chapterListRecords } from './MigratedPreferenceRecords'
import { ChapterMetadataFilter, filterChapterMetadata, ReaderChapterDescriptor } from './ReaderChapterSequence'

export enum ChapterReadFilter {
  ALL = 'all', UNREAD = 'unread', READ = 'read', DOWNLOADED = 'downloaded',
}

export interface ChapterListPreferences extends ChapterMetadataFilter {
  sortBasis: ChapterSortBasis
  sortDirection: ChapterSortDirection
  readFilter: ChapterReadFilter
  languageFilter: string
  groupFilter: string
  bookmarkFilter: 'all' | 'bookmarked' | 'unbookmarked'
}

let chapterPreferenceDirectory: string = ''
const pendingPreferences = new Map<string, ChapterListPreferences>()

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

function readingPreferencesFor(comicId: string): ChapterListPreferences | undefined {
  const saved = chapterListRecords.prepared(chapterPreferenceDirectory)?.get(comicId)
  return pendingPreferences.get(comicId) ?? (saved === undefined ? undefined : JSON.parse(saved) as ChapterListPreferences)
}

/** Every reader entry and catalog refresh consumes the same saved edition.
 * Keep the full source catalog in storage; this is only a reading projection. */
export function chapterReadingChaptersFor<T extends ReaderChapterDescriptor>(
  comicId: string, chapters: T[], currentId?: string,
): T[] {
  return filterChapterMetadata(chapters, readingPreferencesFor(comicId), currentId)
}

/** Old saved chapters can have ordinals but predate edition/language metadata.
 * Resolve the catalog in the background instead of treating that absence as a
 * confirmed mismatch. The adapter retires pending after that one resolution. */
export function chapterReadingMetadataPendingFor<T extends ReaderChapterDescriptor>(comicId: string, chapter?: T): boolean {
  if (chapter === undefined) return false
  const filter = readingPreferencesFor(comicId)
  return ((filter?.groupFilter?.trim().length ?? 0) > 0 && !chapter.scanlator?.trim()) ||
    ((filter?.languageFilter?.trim().length ?? 0) > 0 && !chapter.language?.trim())
}

/** History and the shelf reuse the same per-work sort record as the detail page. */
export function chapterReadingSortFor(comicId: string): ChapterSortPolicy | undefined {
  const value = readingPreferencesFor(comicId)
  const basis = value?.sortBasis
  if (basis !== ChapterSortBasis.CHAPTER_NUMBER && basis !== ChapterSortBasis.UPLOAD_DATE &&
    basis !== ChapterSortBasis.NAME) return undefined
  return { basis, locale: basis === ChapterSortBasis.NAME ? connectLanguageState().effectiveLocale || undefined : undefined }
}

/** View preferences belong to the stable comic ID, never to chapter order or reading progress. */
export class ChapterListPreferencesStore {
  private context: common.Context
  constructor(context: common.Context) { this.context = context }

  async prepare(): Promise<void> {
    await chapterListRecords.prepare(this.context)
    chapterPreferenceDirectory = this.context.filesDir
  }

  load(comicId: string, defaultDirection: ChapterSortDirection = ChapterSortDirection.FORWARD): ChapterListPreferences {
    const value = chapterListRecords.prepared(this.context.filesDir)?.get(comicId)
    const saved = pendingPreferences.get(comicId) ??
      (value === undefined ? undefined : JSON.parse(value) as ChapterListPreferences)
    const normalized = normalizeChapterListPreferences(saved)
    // A new work starts newest-first, even when its provider returns oldest-first.
    // Existing records keep their raw-array direction and the component labels it.
    if (saved === undefined) normalized.sortDirection = defaultDirection
    return normalized
  }

  save(comicId: string, value: ChapterListPreferences): Promise<void> {
    if (comicId.length === 0) return Promise.resolve()
    const captured = normalizeChapterListPreferences(value)
    pendingPreferences.set(comicId, captured)
    const run = BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const records = await chapterListRecords.prepare(this.context)
      records.put(comicId, JSON.stringify(captured))
    })
    return run.finally((): void => {
      if (pendingPreferences.get(comicId) === captured) pendingPreferences.delete(comicId)
    })
  }
}
