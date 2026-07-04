import {
  Comic,
  ComicSourceKind,
} from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { AppStrings } from '../i18n/AppStrings'

export type LocalLibraryRefreshResultStatus = 'unchanged' | 'reselect_required' | 'skipped'

export interface LocalLibraryRefreshComicResult {
  comicId: string
  sourceKind: ComicSourceKind
  status: LocalLibraryRefreshResultStatus
  previousChapterCount: number
  previousPageCount: number
  message: string
}

export interface LocalLibraryRefreshSummary {
  checkedAt: number
  totalCount: number
  archiveCount: number
  folderCount: number
  reselectRequiredCount: number
  unchangedCount: number
  skippedCount: number
  results: LocalLibraryRefreshComicResult[]
}

function isLocalRefreshCandidate(comic: Comic): boolean {
  return comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER
}

function localRefreshUnavailableMessage(sourceKind: ComicSourceKind): string {
  if (sourceKind === ComicSourceKind.LOCAL_FOLDER) {
    return AppStrings.get('local_library_refresh_folder_reselect_detail')
  }
  return AppStrings.get('local_library_refresh_archive_retained')
}

function localRefreshStatus(sourceKind: ComicSourceKind): LocalLibraryRefreshResultStatus {
  return sourceKind === ComicSourceKind.LOCAL_FOLDER ? 'reselect_required' : 'unchanged'
}

function summarizeLocalRefreshResults(checkedAt: number, results: LocalLibraryRefreshComicResult[]): LocalLibraryRefreshSummary {
  return {
    checkedAt,
    totalCount: results.length,
    archiveCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.sourceKind === ComicSourceKind.LOCAL_ARCHIVE).length,
    folderCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.sourceKind === ComicSourceKind.LOCAL_FOLDER).length,
    reselectRequiredCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'reselect_required').length,
    unchangedCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'unchanged').length,
    skippedCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'skipped').length,
    results,
  }
}

export function formatLocalLibraryRefreshSummary(summary?: LocalLibraryRefreshSummary): string {
  if (summary === undefined) {
    return AppStrings.get('local_library_refresh_not_checked')
  }
  if (summary.totalCount === 0) {
    return AppStrings.get('local_library_refresh_none')
  }
  if (summary.reselectRequiredCount > 0) {
    return AppStrings.get('local_library_refresh_reselect_required_detail')
      .replace('%s', `${summary.totalCount}`)
      .replace('%s', `${summary.reselectRequiredCount}`)
      .replace('%s', `${summary.archiveCount}`)
  }
  return AppStrings.get('local_library_refresh_clean_detail')
    .replace('%s', `${summary.totalCount}`)
    .replace('%s', `${summary.archiveCount}`)
}

export class LocalLibraryRefreshService {
  private libraryStore: LibraryStore

  constructor(libraryStore: LibraryStore) {
    this.libraryStore = libraryStore
  }

  checkLocalLibraryRefresh(): LocalLibraryRefreshSummary {
    const checkedAt = Date.now()
    const localComics = this.libraryStore.listComics().filter((comic: Comic): boolean => isLocalRefreshCandidate(comic))
    const results = localComics.map((comic: Comic): LocalLibraryRefreshComicResult => this.checkLocalComic(comic))
    const summary = summarizeLocalRefreshResults(checkedAt, results)
    console.info(
      `[LocalLibraryRefresh] step=done total=${summary.totalCount} reselectRequired=${summary.reselectRequiredCount} unchanged=${summary.unchangedCount} skipped=${summary.skippedCount}`
    )
    return summary
  }

  checkLocalComicRefresh(comic: Comic): LocalLibraryRefreshComicResult {
    if (!isLocalRefreshCandidate(comic)) {
      return {
        comicId: comic.id,
        sourceKind: comic.sourceKind,
        status: 'skipped',
        previousChapterCount: comic.chapterCount,
        previousPageCount: comic.pageCount,
        message: AppStrings.get('common_unavailable'),
      }
    }
    return this.checkLocalComic(comic)
  }

  private checkLocalComic(comic: Comic): LocalLibraryRefreshComicResult {
    return {
      comicId: comic.id,
      sourceKind: comic.sourceKind,
      status: localRefreshStatus(comic.sourceKind),
      previousChapterCount: comic.chapterCount,
      previousPageCount: comic.pageCount,
      message: localRefreshUnavailableMessage(comic.sourceKind),
    }
  }
}
