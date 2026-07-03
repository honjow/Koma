import {
  LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS,
  LocalLibraryFolderChapter,
  LocalLibraryFolderRejectedEntry,
  LocalLibraryFolderScanResult,
  LocalLibraryFolderSeries,
} from './LocalLibraryFolderContract'

export const LOCAL_LIBRARY_RESCAN_CONTRACT_VERSION = 1
export const LOCAL_LIBRARY_RESCAN_UI_MUTATION_CONTRACT = 'MODEL_ONLY_NO_SYNC_UI_MUTATION'
export const LOCAL_LIBRARY_RESCAN_DESTRUCTIVE_ACTION_CONTRACT = 'NO_DELETE_LIBRARY_ROWS_OR_USER_FILES'

export type LocalLibraryRescanOutcomeStatus = 'added' | 'missing' | 'changed' | 'unchanged'
export type LocalLibraryRescanFailureStatus = 'partial_failure' | 'reselect_required' | 'deferred'

export interface LocalLibraryRescanFailure {
  status: LocalLibraryRescanFailureStatus
  reason: string
  message: string
}

export interface LocalLibraryRescanChapterOutcome {
  id: string
  status: LocalLibraryRescanOutcomeStatus
  previousRelativePath?: string
  currentRelativePath?: string
  previousPageCount: number
  currentPageCount: number
}

export interface LocalLibraryRescanSeriesOutcome {
  id: string
  title: string
  status: LocalLibraryRescanOutcomeStatus
  previousRelativePath?: string
  currentRelativePath?: string
  previousChapterCount: number
  currentChapterCount: number
  previousPageCount: number
  currentPageCount: number
  addedChapterCount: number
  missingChapterCount: number
  changedChapterCount: number
  unchangedChapterCount: number
  chapters: LocalLibraryRescanChapterOutcome[]
}

export interface LocalLibraryRescanSummary {
  contractVersion: number
  runtimeFolderPicker: string
  uiMutationContract: string
  destructiveActionContract: string
  previousSeriesCount: number
  currentSeriesCount: number
  addedCount: number
  removedCount: number
  missingCount: number
  changedCount: number
  unchangedCount: number
  addedChapterCount: number
  removedChapterCount: number
  missingChapterCount: number
  changedChapterCount: number
  unchangedChapterCount: number
  rejectedEntryCount: number
  partialFailureCount: number
  outcomes: LocalLibraryRescanSeriesOutcome[]
  rejectedEntries: LocalLibraryFolderRejectedEntry[]
  failures: LocalLibraryRescanFailure[]
}

function compareText(left: string, right: string): number {
  return left.localeCompare(right)
}

function chapterSignature(chapter: LocalLibraryFolderChapter): string {
  const pages = chapter.pages
    .map((page): string => page.relativePath)
    .slice()
    .sort(compareText)
    .join('|')
  return [
    chapter.kind,
    chapter.relativePath,
    chapter.pageCount.toString(),
    pages,
  ].join('\n')
}

function sidecarMetadataSignature(series: LocalLibraryFolderSeries): string {
  const metadata = series.sidecarMetadata
  if (metadata === undefined) {
    return ''
  }
  return [
    metadata.title ?? '',
    (metadata.authors ?? []).slice().sort(compareText).join('|'),
    metadata.status ?? '',
    metadata.coverPath ?? '',
  ].join('\n')
}

function seriesSignature(series: LocalLibraryFolderSeries): string {
  const chapters = series.chapters
    .map((chapter): string => chapterSignature(chapter))
    .slice()
    .sort(compareText)
    .join('\n--chapter--\n')
  return [
    series.relativePath,
    sidecarMetadataSignature(series),
    series.chapterCount.toString(),
    series.pageCount.toString(),
    chapters,
  ].join('\n')
}

function countChaptersWithStatus(chapters: LocalLibraryRescanChapterOutcome[], status: LocalLibraryRescanOutcomeStatus): number {
  return chapters.filter((chapter): boolean => chapter.status === status).length
}

function buildChapterOutcomes(
  previousChapters: LocalLibraryFolderChapter[],
  currentChapters: LocalLibraryFolderChapter[],
): LocalLibraryRescanChapterOutcome[] {
  const previousById = new Map<string, LocalLibraryFolderChapter>()
  const currentById = new Map<string, LocalLibraryFolderChapter>()
  previousChapters.forEach((chapter): void => {
    previousById.set(chapter.id, chapter)
  })
  currentChapters.forEach((chapter): void => {
    currentById.set(chapter.id, chapter)
  })

  const outcomes: LocalLibraryRescanChapterOutcome[] = []
  previousChapters.forEach((previous): void => {
    const current = currentById.get(previous.id)
    if (current === undefined) {
      outcomes.push({
        id: previous.id,
        status: 'missing',
        previousRelativePath: previous.relativePath,
        previousPageCount: previous.pageCount,
        currentPageCount: 0,
      })
      return
    }
    outcomes.push({
      id: previous.id,
      status: chapterSignature(previous) === chapterSignature(current) ? 'unchanged' : 'changed',
      previousRelativePath: previous.relativePath,
      currentRelativePath: current.relativePath,
      previousPageCount: previous.pageCount,
      currentPageCount: current.pageCount,
    })
  })

  currentChapters.forEach((current): void => {
    if (previousById.has(current.id)) {
      return
    }
    outcomes.push({
      id: current.id,
      status: 'added',
      currentRelativePath: current.relativePath,
      previousPageCount: 0,
      currentPageCount: current.pageCount,
    })
  })

  return outcomes.sort((left, right): number => compareText(left.previousRelativePath ?? left.currentRelativePath ?? left.id, right.previousRelativePath ?? right.currentRelativePath ?? right.id))
}

function buildSeriesOutcome(
  previous: LocalLibraryFolderSeries | undefined,
  current: LocalLibraryFolderSeries | undefined,
): LocalLibraryRescanSeriesOutcome {
  const chapters = buildChapterOutcomes(previous?.chapters ?? [], current?.chapters ?? [])
  const status: LocalLibraryRescanOutcomeStatus = previous === undefined
    ? 'added'
    : current === undefined
      ? 'missing'
      : seriesSignature(previous) === seriesSignature(current)
        ? 'unchanged'
        : 'changed'
  return {
    id: previous?.id ?? current?.id ?? '',
    title: current?.title ?? previous?.title ?? '',
    status,
    previousRelativePath: previous?.relativePath,
    currentRelativePath: current?.relativePath,
    previousChapterCount: previous?.chapterCount ?? 0,
    currentChapterCount: current?.chapterCount ?? 0,
    previousPageCount: previous?.pageCount ?? 0,
    currentPageCount: current?.pageCount ?? 0,
    addedChapterCount: countChaptersWithStatus(chapters, 'added'),
    missingChapterCount: countChaptersWithStatus(chapters, 'missing'),
    changedChapterCount: countChaptersWithStatus(chapters, 'changed'),
    unchangedChapterCount: countChaptersWithStatus(chapters, 'unchanged'),
    chapters,
  }
}

export function createLocalLibraryRescanSummary(
  previousKnownSeries: LocalLibraryFolderSeries[],
  freshScan: LocalLibraryFolderScanResult,
  failures: LocalLibraryRescanFailure[] = [],
): LocalLibraryRescanSummary {
  const previousById = new Map<string, LocalLibraryFolderSeries>()
  const currentById = new Map<string, LocalLibraryFolderSeries>()
  previousKnownSeries.forEach((series): void => {
    previousById.set(series.id, series)
  })
  freshScan.series.forEach((series): void => {
    currentById.set(series.id, series)
  })

  const outcomes: LocalLibraryRescanSeriesOutcome[] = []
  previousKnownSeries.forEach((previous): void => {
    outcomes.push(buildSeriesOutcome(previous, currentById.get(previous.id)))
  })
  freshScan.series.forEach((current): void => {
    if (!previousById.has(current.id)) {
      outcomes.push(buildSeriesOutcome(undefined, current))
    }
  })
  outcomes.sort((left, right): number => compareText(left.previousRelativePath ?? left.currentRelativePath ?? left.id, right.previousRelativePath ?? right.currentRelativePath ?? right.id))

  const missingCount = outcomes.filter((outcome): boolean => outcome.status === 'missing').length
  const missingChapterCount = outcomes.reduce((total, outcome): number => total + outcome.missingChapterCount, 0)
  return {
    contractVersion: LOCAL_LIBRARY_RESCAN_CONTRACT_VERSION,
    runtimeFolderPicker: LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS,
    uiMutationContract: LOCAL_LIBRARY_RESCAN_UI_MUTATION_CONTRACT,
    destructiveActionContract: LOCAL_LIBRARY_RESCAN_DESTRUCTIVE_ACTION_CONTRACT,
    previousSeriesCount: previousKnownSeries.length,
    currentSeriesCount: freshScan.series.length,
    addedCount: outcomes.filter((outcome): boolean => outcome.status === 'added').length,
    removedCount: missingCount,
    missingCount,
    changedCount: outcomes.filter((outcome): boolean => outcome.status === 'changed').length,
    unchangedCount: outcomes.filter((outcome): boolean => outcome.status === 'unchanged').length,
    addedChapterCount: outcomes.reduce((total, outcome): number => total + outcome.addedChapterCount, 0),
    removedChapterCount: missingChapterCount,
    missingChapterCount,
    changedChapterCount: outcomes.reduce((total, outcome): number => total + outcome.changedChapterCount, 0),
    unchangedChapterCount: outcomes.reduce((total, outcome): number => total + outcome.unchangedChapterCount, 0),
    rejectedEntryCount: freshScan.rejectedEntries.length,
    partialFailureCount: failures.filter((failure): boolean => failure.status === 'partial_failure').length,
    outcomes,
    rejectedEntries: freshScan.rejectedEntries.slice().sort((left, right): number => compareText(left.relativePath, right.relativePath)),
    failures: failures.slice().sort((left, right): number => compareText(left.reason, right.reason)),
  }
}

export class LocalLibraryRescanService {
  summarizeRescan(
    previousKnownSeries: LocalLibraryFolderSeries[],
    freshScan: LocalLibraryFolderScanResult,
    failures: LocalLibraryRescanFailure[] = [],
  ): LocalLibraryRescanSummary {
    return createLocalLibraryRescanSummary(previousKnownSeries, freshScan, failures)
  }
}
