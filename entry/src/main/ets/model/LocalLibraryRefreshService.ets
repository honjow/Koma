import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
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
  missingPageCount: number
  message: string
}

export interface LocalLibraryRefreshSummary {
  checkedAt: number
  totalCount: number
  archiveCount: number
  folderCount: number
  chapterCount: number
  pageCount: number
  missingPageCount: number
  reselectRequiredCount: number
  unchangedCount: number
  skippedCount: number
  results: LocalLibraryRefreshComicResult[]
}

export type LocalLibraryFolderRescanActionStatus =
  'no_local_folders' |
  'updated' |
  'unchanged' |
  'reselect_required' |
  'failed'

export interface LocalLibraryFolderRescanActionResult {
  status: LocalLibraryFolderRescanActionStatus
  rootCount: number
  scannedRootCount: number
  reselectRequiredCount: number
  failedRootCount: number
  addedCount: number
  changedCount: number
  missingCount: number
  metadataChangedCount: number
  rejectedEntryCount: number
  upsertedCount: number
}

function isLocalRefreshCandidate(comic: Comic): boolean {
  return comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER
}

function localFilePathFromUri(uri: string): string | undefined {
  if (!uri.startsWith('file://')) {
    return undefined
  }
  try {
    const path = uri.startsWith('file://docs/')
      ? new fileUri.FileUri(uri).path
      : decodeURIComponent(uri.substring('file://'.length))
    return path.trim().length === 0 ? undefined : path
  } catch (_error) {
    return undefined
  }
}

function localPathExists(path: string): boolean {
  try {
    return fs.accessSync(path)
  } catch (_error) {
    return false
  }
}

function countMissingLocalFolderPages(comic: Comic): number {
  if (comic.pageCount <= 0) {
    return 0
  }
  let missingPageCount = 0
  for (let chapterIndex = 0; chapterIndex < comic.chapters.length; chapterIndex += 1) {
    const chapter: Chapter = comic.chapters[chapterIndex]
    for (let pageIndex = 0; pageIndex < chapter.pages.length; pageIndex += 1) {
      const page: Page = chapter.pages[pageIndex]
      const localPath = localFilePathFromUri(page.uri)
      if (localPath === undefined || !localPathExists(localPath)) {
        missingPageCount += 1
      }
    }
  }
  return missingPageCount
}

function localRefreshStatus(comic: Comic, missingPageCount: number): LocalLibraryRefreshResultStatus {
  if (comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER) {
    return 'unchanged'
  }
  return comic.pageCount > 0 && missingPageCount === 0 ? 'unchanged' : 'reselect_required'
}

function localRefreshMessage(comic: Comic, status: LocalLibraryRefreshResultStatus, missingPageCount: number): string {
  if (comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER) {
    return AppStrings.get('local_library_refresh_archive_retained')
  }
  if (status === 'unchanged') {
    return AppStrings.get('local_library_refresh_folder_cached_available')
  }
  if (missingPageCount > 0) {
    return formatLocalLibraryRefreshText('local_library_refresh_folder_missing_pages_detail', [`${missingPageCount}`])
  }
  return AppStrings.get('local_library_refresh_folder_reselect_detail')
}

function summarizeLocalRefreshResults(checkedAt: number, results: LocalLibraryRefreshComicResult[]): LocalLibraryRefreshSummary {
  return {
    checkedAt,
    totalCount: results.length,
    archiveCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.sourceKind === ComicSourceKind.LOCAL_ARCHIVE).length,
    folderCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.sourceKind === ComicSourceKind.LOCAL_FOLDER).length,
    chapterCount: results.reduce((total: number, result: LocalLibraryRefreshComicResult): number => total + result.previousChapterCount, 0),
    pageCount: results.reduce((total: number, result: LocalLibraryRefreshComicResult): number => total + result.previousPageCount, 0),
    missingPageCount: results.reduce((total: number, result: LocalLibraryRefreshComicResult): number => total + result.missingPageCount, 0),
    reselectRequiredCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'reselect_required').length,
    unchangedCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'unchanged').length,
    skippedCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'skipped').length,
    results,
  }
}

function formatLocalLibraryRefreshText(key: string, values: string[]): string {
  let text = AppStrings.get(key)
  values.forEach((value: string): void => {
    text = text.replace('%s', value)
  })
  return text
}

export function formatLocalLibraryFolderRescanActionResult(
  result: LocalLibraryFolderRescanActionResult,
): string {
  if (result.status === 'no_local_folders') {
    return AppStrings.get('local_library_refresh_none')
  }
  if (result.status === 'reselect_required') {
    return formatLocalLibraryRefreshText('local_library_rescan_reselect_detail', [
      `${result.reselectRequiredCount}`,
    ])
  }
  if (result.status === 'failed') {
    return AppStrings.get('local_library_rescan_failed_detail')
  }
  const key = result.status === 'updated'
    ? 'local_library_rescan_updated_detail'
    : 'local_library_rescan_unchanged_detail'
  return formatLocalLibraryRefreshText(key, [
    `${result.scannedRootCount}`,
    `${result.addedCount}`,
    `${result.changedCount}`,
    `${result.metadataChangedCount}`,
    `${result.missingCount}`,
    `${result.reselectRequiredCount}`,
    `${result.failedRootCount}`,
  ])
}

export function formatLocalLibraryRefreshSummary(summary?: LocalLibraryRefreshSummary): string {
  if (summary === undefined) {
    return AppStrings.get('local_library_refresh_not_checked')
  }
  if (summary.totalCount === 0) {
    return AppStrings.get('local_library_refresh_none')
  }
  if (summary.reselectRequiredCount > 0) {
    return formatLocalLibraryRefreshText('local_library_refresh_reselect_required_detail', [
      `${summary.totalCount}`,
      `${summary.reselectRequiredCount}`,
      `${summary.archiveCount}`,
    ])
  }
  return formatLocalLibraryRefreshText('local_library_refresh_clean_detail', [
    `${summary.totalCount}`,
    `${summary.archiveCount}`,
  ])
}

export function formatLocalLibraryRefreshDetail(summary: LocalLibraryRefreshSummary): string {
  if (summary.totalCount === 0) {
    return AppStrings.get('local_library_refresh_detail_empty')
  }
  const key = summary.reselectRequiredCount > 0
    ? 'local_library_refresh_detail_reselect'
    : 'local_library_refresh_detail_clean'
  return formatLocalLibraryRefreshText(key, [
    `${summary.totalCount}`,
    `${summary.folderCount}`,
    `${summary.archiveCount}`,
    `${summary.chapterCount}`,
    `${summary.pageCount}`,
    `${summary.missingPageCount}`,
    `${summary.reselectRequiredCount}`,
  ])
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
        missingPageCount: 0,
        message: AppStrings.get('common_unavailable'),
      }
    }
    return this.checkLocalComic(comic)
  }

  private checkLocalComic(comic: Comic): LocalLibraryRefreshComicResult {
    const missingPageCount = comic.sourceKind === ComicSourceKind.LOCAL_FOLDER ? countMissingLocalFolderPages(comic) : 0
    const status = localRefreshStatus(comic, missingPageCount)
    return {
      comicId: comic.id,
      sourceKind: comic.sourceKind,
      status,
      previousChapterCount: comic.chapterCount,
      previousPageCount: comic.pageCount,
      missingPageCount,
      message: localRefreshMessage(comic, status, missingPageCount),
    }
  }
}
