import {
  Comic,
  ComicSourceKind,
} from './ComicModels'
import { LibraryStore } from './LibraryStore'

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
    return '图片文件夹需要重新选择后才能刷新'
  }
  return '本地压缩包需要重新选择后才能刷新'
}

function summarizeLocalRefreshResults(checkedAt: number, results: LocalLibraryRefreshComicResult[]): LocalLibraryRefreshSummary {
  return {
    checkedAt,
    totalCount: results.length,
    reselectRequiredCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'reselect_required').length,
    unchangedCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'unchanged').length,
    skippedCount: results.filter((result: LocalLibraryRefreshComicResult): boolean => result.status === 'skipped').length,
    results,
  }
}

export function formatLocalLibraryRefreshSummary(summary?: LocalLibraryRefreshSummary): string {
  if (summary === undefined) {
    return '尚未检查'
  }
  if (summary.totalCount === 0) {
    return '没有本地导入项目'
  }
  if (summary.reselectRequiredCount > 0) {
    return `${summary.totalCount} 本地漫画 · ${summary.reselectRequiredCount} 本需要重新选择`
  }
  return `${summary.totalCount} 本地漫画 · 无需处理`
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

  private checkLocalComic(comic: Comic): LocalLibraryRefreshComicResult {
    return {
      comicId: comic.id,
      sourceKind: comic.sourceKind,
      status: 'reselect_required',
      previousChapterCount: comic.chapterCount,
      previousPageCount: comic.pageCount,
      message: localRefreshUnavailableMessage(comic.sourceKind),
    }
  }
}
