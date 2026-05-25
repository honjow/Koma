import {
  LibraryUpdateComicResult,
  LibraryUpdateSummary,
} from './LibraryUpdateService'

let latestLibraryUpdateSummary: LibraryUpdateSummary | undefined = undefined

function cloneLibraryUpdateResult(result: LibraryUpdateComicResult): LibraryUpdateComicResult {
  return {
    comicId: result.comicId,
    status: result.status,
    previousChapterCount: result.previousChapterCount,
    newChapterCount: result.newChapterCount,
    message: result.message,
  }
}

export function cloneLibraryUpdateSummary(summary: LibraryUpdateSummary): LibraryUpdateSummary {
  return {
    checkedAt: summary.checkedAt,
    totalCount: summary.totalCount,
    updatedCount: summary.updatedCount,
    unchangedCount: summary.unchangedCount,
    skippedCount: summary.skippedCount,
    failedCount: summary.failedCount,
    results: summary.results.map((result: LibraryUpdateComicResult): LibraryUpdateComicResult => cloneLibraryUpdateResult(result)),
  }
}

export function setLatestLibraryUpdateSummary(summary: LibraryUpdateSummary): void {
  latestLibraryUpdateSummary = cloneLibraryUpdateSummary(summary)
}

export function getLatestLibraryUpdateSummary(): LibraryUpdateSummary | undefined {
  if (latestLibraryUpdateSummary === undefined) {
    return undefined
  }
  return cloneLibraryUpdateSummary(latestLibraryUpdateSummary)
}
