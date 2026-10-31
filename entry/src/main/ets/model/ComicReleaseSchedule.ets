/**
 * Calendar schedule port of Mihon's Apache-2.0 ReleaseSchedule/ReleasePattern/FetchInterval.
 * Reference: mihonapp/mihon @ feadad5e, domain/.../manga/interactor/.
 * Dates are local calendar days, so DST never changes a weekly/monthly interval.
 */
const DAY: number = 86400000
const MAX_INTERVAL: number = 28
interface ReleaseDate { dateUpload?: number; createdAt: number }
export interface ComicUpdateSchedule { intervalDays: number; nextCheckAt: number }
type ReleasePatternKind = 'days' | 'weekdays' | 'month-days' | 'month-weekday' | 'batches'
interface Pattern {
  kind: ReleasePatternKind
  interval: number
  anchor: number
  days: number[]
  week: number
  length: number
}

function mod(value: number, divisor: number): number { return ((value % divisor) + divisor) % divisor }
function median(values: number[]): number { return values.slice().sort((a: number, b: number): number => a - b)[Math.floor((values.length - 1) / 2)] }
function calendarDay(timestamp: number): number {
  const date = new Date(timestamp)
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / DAY
}
function localStart(day: number): number {
  const date = new Date(day * DAY)
  return new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()).getTime()
}
function weekday(day: number): number { return new Date(day * DAY).getUTCDay() }
function monthDay(day: number): number { return new Date(day * DAY).getUTCDate() }
function lastMonthDay(day: number): number {
  const date = new Date(day * DAY)
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate()
}
function pattern(kind: ReleasePatternKind, interval: number = 7, anchor: number = 0,
  days: number[] = [], week: number = 0, length: number = 0): Pattern {
  return { kind, interval, anchor, days, week, length }
}

function onPattern(value: Pattern, day: number): boolean {
  if (value.kind === 'weekdays') return value.days.includes(weekday(day))
  if (value.kind === 'month-days') return value.days.some((n: number): boolean => Math.min(n, lastMonthDay(day)) === monthDay(day))
  return weekday(day) === value.days[0] && (value.week === -1
    ? monthDay(day) + 7 > lastMonthDay(day) : Math.floor((monthDay(day) - 1) / 7) + 1 === value.week)
}

function nextPatternDay(value: Pattern, day: number, direction: number): number {
  if (value.kind === 'days') {
    return direction > 0 ? day + value.interval - mod(day - value.anchor, value.interval)
      : day - mod(day - value.anchor - 1, value.interval) - 1
  }
  if (value.kind === 'batches') {
    if (direction > 0) {
      const offset = mod(day - value.anchor, value.interval)
      return day + (offset + 1 < value.length ? 1 : value.interval - offset)
    }
    const previous = day - 1
    return previous - Math.max(0, mod(previous - value.anchor, value.interval) - value.length + 1)
  }
  let candidate = day + direction
  while (!onPattern(value, candidate)) candidate += direction
  return candidate
}

function nearest(value: Pattern, day: number): number {
  if (value.kind === 'weekdays') return day
  const before = nextPatternDay(value, day + 1, -1), after = nextPatternDay(value, day - 1, 1)
  return day - before <= after - day ? before : after
}

function mostCommon(days: number[], selector: (day: number) => number): number | undefined {
  const counts = new Map<number, number>()
  for (const day of days) { const key = selector(day); counts.set(key, (counts.get(key) ?? 0) + 1) }
  let best: number | undefined, count = 0
  counts.forEach((n: number, key: number): void => { if (n > count) { best = key; count = n } })
  return count >= days.length * 0.8 ? best : undefined
}

function detectBatches(history: number[]): Pattern | undefined {
  const runs: number[][] = []
  for (const day of history.slice(0, 40).reverse()) {
    const run = runs[runs.length - 1]
    if (run !== undefined && day - run[run.length - 1] <= 2) run.push(day)
    else runs.push([day])
  }
  const recent = runs.slice(-6)
  if (recent.length < 3 || recent.filter((run: number[]): boolean => run.length > 1).length * 2 < recent.length) return undefined
  const gaps = recent.slice(1).map((run: number[], index: number): number => run[0] - recent[index][0])
  const every = median(gaps), length = median(recent.map((run: number[]): number => run[run.length - 1] - run[0] + 1))
  if (every < length * 2 || gaps.some((gap: number): boolean => Math.abs(gap - every) > every / 4)) return undefined
  return pattern('batches', every, recent[recent.length - 1][0], [], 0, length)
}

function detectPattern(days: number[], history: number[], gap: number): Pattern | undefined {
  if (days.length < 4) return undefined
  const batch = detectBatches(history)
  if (batch !== undefined) return batch
  const monthDays = days.map(monthDay)
  if (gap >= 26 && gap <= 35) {
    if (Math.max(...monthDays) - Math.min(...monthDays) <= 3) return pattern('month-days', 0, 0, [median(monthDays)])
    if (monthDays.every((day: number): boolean => day >= 28)) return pattern('month-days', 0, 0, [31])
    const dayOfWeek = mostCommon(days, weekday)
    if (dayOfWeek === undefined) return undefined
    const week = mostCommon(days, (day: number): number => Math.floor((monthDay(day) - 1) / 7) + 1)
    if (week !== undefined && week < 5) return pattern('month-weekday', 0, 0, [dayOfWeek], week)
    const lastWeek = days.filter((day: number): boolean => monthDay(day) + 7 > lastMonthDay(day)).length >= days.length * 0.8
    return lastWeek ? pattern('month-weekday', 0, 0, [dayOfWeek], -1) : undefined
  }
  if (gap >= 12 && gap <= 18) {
    monthDays.sort((a: number, b: number): number => a - b)
    let split = 1
    for (let i = 2; i < monthDays.length; i++) if (monthDays[i] - monthDays[i - 1] > monthDays[split] - monthDays[split - 1]) split = i
    const halves = [monthDays.slice(0, split), monthDays.slice(split)]
    if (halves.some((half: number[]): boolean => half.length < 2 || half[half.length - 1] - half[0] > 3)) return undefined
    return pattern('month-days', 0, 0, halves.map(median))
  }
  const counts = new Map<number, number>()
  days.forEach((day: number): void => { const key = weekday(day); counts.set(key, (counts.get(key) ?? 0) + 1) })
  const ordered = Array.from(counts.keys()).sort((a: number, b: number): number => counts.get(b)! - counts.get(a)!)
  const weekdays: number[] = []; let covered = 0
  for (const day of ordered) { if (covered >= days.length * 0.8) break; weekdays.push(day); covered += counts.get(day)! }
  return weekdays.length >= 2 && weekdays.length <= 3 && covered >= days.length * 0.8 && gap <= Math.floor(7 / weekdays.length) + 1
    ? pattern('weekdays', 0, 0, weekdays) : undefined
}

export function estimateComicUpdateSchedule(chapters: ReleaseDate[], now: number,
  previous?: ComicUpdateSchedule, foundRelease: boolean = false): ComicUpdateSchedule {
  const today = calendarDay(now)
  const releaseDays = (dates: number[]): number[] => Array.from(new Set<number>(dates
    .filter((value: number): boolean => Number.isFinite(value) && value > 0)
    .map(calendarDay).filter((day: number): boolean => day <= today + 1))).sort((a: number, b: number): number => b - a)
  const upload = releaseDays(chapters.map((chapter: ReleaseDate): number => chapter.dateUpload ?? 0))
  const fetched = releaseDays(chapters.map((chapter: ReleaseDate): number => chapter.createdAt))
  const history = upload.length >= 3 ? upload : fetched.length >= 3 ? fetched : []
  const days = history.slice(0, chapters.length <= 8 ? 3 : 10)
  const lastRelease = days[0] ?? upload[0] ?? fetched[0]
  let interval = 7, lateness = 0, value = pattern('days', interval, lastRelease ?? today)
  let breaks: number[] = []
  if (days.length >= 3) {
    const gaps = days.slice(1).map((day: number, i: number): number => days[i] - day).sort((a: number, b: number): number => a - b)
    const gap = median(gaps), detected = detectPattern(days, history, gap)
    interval = Math.max(1, Math.min(MAX_INTERVAL, detected?.kind === 'batches' ? detected.interval : gap))
    let phase = days[0], score = Number.POSITIVE_INFINITY
    for (const candidate of days.slice(0, 5)) {
      const distance = days.slice(0, 5).reduce((sum: number, day: number): number => {
        const offset = mod(day - candidate, interval); return sum + Math.min(offset, interval - offset)
      }, 0)
      if (distance < score) { score = distance; phase = candidate }
    }
    const phaseDays = days.slice(0, 5)
    if (phaseDays.filter((day: number): boolean => mod(day - phase, interval) === 0).length * 5 < phaseDays.length * 3) phase = days[0]
    value = detected ?? pattern('days', interval, phase)
    lateness = Math.max(0, Math.min(Math.floor(interval / 2), gaps[gaps.length - 1] - interval))
    breaks = history.slice(1).map((day: number, i: number): number => history[i] - day).filter((gap: number): boolean => gap > interval * 4)
  }
  let next: number
  const expected = previous === undefined ? undefined : calendarDay(previous.nextCheckAt)
  if (!foundRelease && expected !== undefined && expected >= today - 1 && expected <= today + 1 &&
    (lastRelease === undefined || lastRelease < expected)) next = expected
  else if (foundRelease) {
    next = nextPatternDay(value, nearest(value, Math.min(lastRelease ?? today, today)), 1)
    while (next <= today) next = nextPatternDay(value, next, 1)
    next = Math.min(next, today + MAX_INTERVAL)
  } else {
    const anchor = lastRelease ?? today, since = today - anchor
    if (since > interval * 4 && !breaks.some((gap: number): boolean => since >= gap - interval && since <= gap + interval)) {
      let backoff = interval
      while (backoff < MAX_INTERVAL && since > backoff * 4) backoff *= 2
      backoff = Math.min(backoff, MAX_INTERVAL)
      next = anchor + Math.ceil(since / backoff) * backoff
      for (const gap of breaks) if (anchor + gap - interval > today) next = Math.min(next, anchor + gap - interval)
    } else {
      const due = nextPatternDay(value, nearest(value, anchor), 1)
      next = today >= due && today <= due + lateness ? today : due
      while (next < today) next = nextPatternDay(value, next, 1)
      next = Math.min(next, today + MAX_INTERVAL)
    }
  }
  return { intervalDays: interval, nextCheckAt: localStart(next) }
}

/** The reference allows a one-day grace window; an unknown schedule never skips a check. */
export function comicUpdateScheduleDue(schedule: ComicUpdateSchedule | undefined, now: number): boolean {
  return schedule === undefined || calendarDay(schedule.nextCheckAt) <= calendarDay(now) + 1
}
