import type { Comic } from './ComicModels'
import type { ReaderSessionStore } from './ReaderSessionStore'

/** Aidoku's per-chapter reading session: foreground time and unique pages in that session.
 * Position/history timestamps are not durations. Old history therefore starts with no sessions.
 * These facts stay with the original book when copying/migrating to another source.
 */
export interface ReadingSessionRecord {
  comicId: string
  chapterId: string
  startedAt: number
  endedAt: number
  pagesRead: number
}

export type ReadingStatisticsPeriod = 'all' | 'month' | 'year'
export interface ReadingDayStatistics { day: string; durationMs: number; pagesRead: number }
export interface ReadingStatistics {
  durationMs: number
  pagesRead: number
  booksRead: number
  currentStreak: number
  longestStreak: number
  days: ReadingDayStatistics[]
}
export interface ReadingLibraryStatistics {
  books: number
  startedBooks: number
  completedBooks: number
  chapters: number
  readChapters: number
  downloadedChapters: number
}

export function readingDayKey(timestamp: number): string {
  const date = new Date(timestamp)
  return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}-${`${date.getDate()}`.padStart(2, '0')}`
}

function dayOrdinal(key: string): number {
  const parts = key.split('-').map((value: string): number => Number(value))
  return Date.UTC(parts[0], parts[1] - 1, parts[2]) / 86400000
}

export function summarizeReadingSessions(records: ReadingSessionRecord[], period: ReadingStatisticsPeriod,
  selected: number, now: number = Date.now()): ReadingStatistics {
  const target = new Date(selected)
  const books = new Set<string>(), dates = new Map<string, ReadingDayStatistics>()
  const allDays = new Set<string>()
  let durationMs = 0, pagesRead = 0
  for (const record of records) {
    const key = readingDayKey(record.endedAt)
    allDays.add(key)
    const date = new Date(record.endedAt)
    if (period !== 'all' && (date.getFullYear() !== target.getFullYear() ||
      period === 'month' && date.getMonth() !== target.getMonth())) continue
    const duration = Math.max(0, record.endedAt - record.startedAt)
    durationMs += duration
    pagesRead += record.pagesRead
    books.add(record.comicId)
    const day = dates.get(key) ?? { day: key, durationMs: 0, pagesRead: 0 }
    day.durationMs += duration; day.pagesRead += record.pagesRead
    dates.set(key, day)
  }
  const sorted = Array.from(allDays).map(dayOrdinal).sort((a: number, b: number): number => a - b)
  let longest = 0, run = 0, previous = -1
  sorted.forEach((day: number): void => {
    run = day === previous + 1 ? run + 1 : 1
    longest = Math.max(longest, run); previous = day
  })
  const today = dayOrdinal(readingDayKey(now))
  const current = previous === today || previous === today - 1 ? run : 0
  return { durationMs, pagesRead, booksRead: books.size, currentStreak: current,
    longestStreak: longest, days: Array.from(dates.values()).sort((a: ReadingDayStatistics, b: ReadingDayStatistics): number =>
      a.day.localeCompare(b.day)) }
}

export function summarizeReadingLibrary(comics: Comic[], store: ReaderSessionStore,
  downloaded: Set<string>): ReadingLibraryStatistics {
  const result: ReadingLibraryStatistics = { books: comics.length, startedBooks: 0, completedBooks: 0,
    chapters: 0, readChapters: 0, downloadedChapters: 0 }
  for (const comic of comics) {
    let read = 0
    const chapterIds = new Set<string>()
    for (const chapter of comic.chapters) {
      if (chapterIds.has(chapter.id)) continue
      chapterIds.add(chapter.id)
      if (store.isChapterRead(comic.id, chapter.id)) read++
      if (downloaded.has(JSON.stringify([comic.id, chapter.id]))) result.downloadedChapters++
    }
    result.chapters += chapterIds.size
    result.readChapters += read
    if (read > 0 || store.getProgress(comic.id) !== undefined) result.startedBooks++
    if (chapterIds.size > 0 && read === chapterIds.size) result.completedBooks++
  }
  return result
}

/** Zero-activity days remain visible instead of compressing gaps in the reading calendar. */
export function readingCalendarDays(stats: ReadingStatistics, period: ReadingStatisticsPeriod,
  selected: number, now: number = Date.now()): ReadingDayStatistics[] {
  const date = new Date(period === 'all' ? now : selected)
  const start = period === 'all' ? new Date(date.getFullYear(), date.getMonth(), date.getDate() - 364) :
    period === 'month' ? new Date(date.getFullYear(), date.getMonth(), 1) : new Date(date.getFullYear(), 0, 1)
  const end = period === 'all' ? new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1) :
    period === 'month' ? new Date(date.getFullYear(), date.getMonth() + 1, 1) : new Date(date.getFullYear() + 1, 0, 1)
  const byDay = new Map<string, ReadingDayStatistics>()
  stats.days.forEach((value: ReadingDayStatistics): void => { byDay.set(value.day, value) })
  const days: ReadingDayStatistics[] = []
  for (let day = new Date(start); day < end; day.setDate(day.getDate() + 1)) {
    const key = readingDayKey(day.getTime())
    days.push(byDay.get(key) ?? { day: key, durationMs: 0, pagesRead: 0 })
  }
  return days
}

/** One recorder per root Reader owner; a preload never reports a visible position here. */
export class ReadingSessionRecorder {
  private active: boolean = false
  private current: ReadingSessionRecord | undefined
  private pages: Set<number> = new Set<number>()
  private currentPages: number[] = []
  private save: (record: ReadingSessionRecord) => void
  private clock: () => number
  constructor(save: (record: ReadingSessionRecord) => void,
    clock: () => number = (): number => Date.now()) { this.save = save; this.clock = clock }

  setActive(active: boolean): void {
    if (this.active === active) return
    if (!active) this.commit()
    this.active = active
    if (active && this.current !== undefined) this.begin(this.current.comicId, this.current.chapterId, this.currentPages)
  }

  observe(comicId: string, chapterId: string, page: number): void {
    this.observePages(comicId, chapterId, [page])
  }

  observePages(comicId: string, chapterId: string, pages: number[]): void {
    if (!this.active || pages.length === 0) return
    if (this.current?.comicId !== comicId || this.current.chapterId !== chapterId) {
      this.commit()
      this.begin(comicId, chapterId, pages)
    }
    this.currentPages = pages.slice()
    pages.forEach((page: number): void => { this.pages.add(page) })
  }

  close(): void { this.commit(); this.current = undefined; this.active = false }
  reset(): void { this.current = undefined; this.pages.clear(); this.active = false }

  private begin(comicId: string, chapterId: string, pages: number[]): void {
    const now = this.clock()
    this.current = { comicId, chapterId, startedAt: now, endedAt: now, pagesRead: 0 }
    this.pages = new Set<number>(pages)
    this.currentPages = pages.slice()
  }

  private commit(): void {
    const current = this.current
    if (current === undefined || !this.active || this.pages.size === 0) return
    const endedAt = this.clock()
    if (endedAt > current.startedAt) this.save({ comicId: current.comicId, chapterId: current.chapterId,
      startedAt: current.startedAt, endedAt, pagesRead: this.pages.size })
    this.pages.clear()
  }
}
