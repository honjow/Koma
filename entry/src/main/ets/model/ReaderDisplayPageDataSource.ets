import { ReadingDirection } from './ComicModels'

export type ReaderSplitSide = 'none' | 'left' | 'right'

/**
 * One item in the paged reader's display space.
 *
 * `pageIndex` remains the chapter/source position used by downloads and
 * progress sync. A wide source page expands into two display items that keep
 * the same source position but own independent pager and gesture lifecycles.
 */
export interface ReaderDisplayPage {
  pageIndex: number
  splitSide: ReaderSplitSide
}

export function buildReaderDisplayPages(
  totalPages: number,
  widePageIndexes: number[],
  splitWidePages: boolean,
  readingDirection: ReadingDirection,
): ReaderDisplayPage[] {
  const pages: ReaderDisplayPage[] = []
  const firstSplitSide: ReaderSplitSide = readingDirection === ReadingDirection.RIGHT_TO_LEFT ? 'right' : 'left'
  const secondSplitSide: ReaderSplitSide = firstSplitSide === 'left' ? 'right' : 'left'
  for (let pageIndex = 0; pageIndex < Math.max(0, totalPages); pageIndex += 1) {
    if (splitWidePages && widePageIndexes.includes(pageIndex)) {
      pages.push({ pageIndex, splitSide: firstSplitSide })
      pages.push({ pageIndex, splitSide: secondSplitSide })
    } else {
      pages.push({ pageIndex, splitSide: 'none' })
    }
  }
  return pages
}

/** Find a source page in display space while preserving a live split side. */
export function readerDisplayIndexForPage(
  pages: ReaderDisplayPage[],
  pageIndex: number,
  preferredSide: ReaderSplitSide = 'none',
): number {
  let firstMatch = -1
  for (let index = 0; index < pages.length; index += 1) {
    const page = pages[index]
    if (page.pageIndex !== pageIndex) {
      continue
    }
    if (firstMatch < 0) {
      firstMatch = index
    }
    if (preferredSide !== 'none' && page.splitSide === preferredSide) {
      return index
    }
  }
  return firstMatch
}

/** Stable IDataSource for LazyForEach; the reader rebuilds it only when display geometry changes. */
export class ReaderDisplayPageDataSource implements IDataSource {
  private pages: ReaderDisplayPage[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.pages.length
  }

  getData(index: number): ReaderDisplayPage {
    return this.pages[index]
  }

  setPages(pages: ReaderDisplayPage[]): void {
    this.pages = pages.slice()
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}
