import { Comic } from './ComicModels'
import { LibraryUpdateSummary } from './LibraryUpdateService'
import { newlyAddedChapterIds } from './LibraryAutomationPolicy'

export interface LibraryChapterUpdate {
  comicId: string
  chapterId: string
  discoveredAt: number
}

let cachedUpdates: LibraryChapterUpdate[] | undefined = undefined
let cacheEpoch: number = 0
export function cachedLibraryChapterUpdates(): LibraryChapterUpdate[] | undefined { return cachedUpdates }
export function libraryChapterUpdatesEpoch(): number { return cacheEpoch }
export function setCachedLibraryChapterUpdates(value: LibraryChapterUpdate[] | undefined): void {
  if (value === undefined) cacheEpoch += 1
  cachedUpdates = value
}

// Reuse the update pipeline's exact pre-update chapter IDs, also used by auto
// download. Display order, count differences and upload dates cannot prove a new chapter.
export function collectLibraryChapterUpdates(comics: Comic[], summary: LibraryUpdateSummary,
  previous: Map<string, Set<string>>): LibraryChapterUpdate[] {
  const byId = new Map<string, Comic>()
  comics.forEach((comic: Comic): void => { byId.set(comic.id, comic) })
  const updates: LibraryChapterUpdate[] = []
  for (const result of summary.results) {
    if (result.status !== 'updated') continue
    const comic = byId.get(result.comicId)
    const baseline = previous.get(result.comicId)
    if (comic === undefined || baseline === undefined) continue
    newlyAddedChapterIds(baseline, comic).forEach((chapterId: string): void => {
      updates.push({ comicId: comic.id, chapterId, discoveredAt: summary.checkedAt })
    })
  }
  return updates
}

export function parseLibraryChapterUpdates(value: string): LibraryChapterUpdate[] {
  if (value.length === 0) return []
  const records = JSON.parse(value) as LibraryChapterUpdate[]
  if (!Array.isArray(records) || records.some((record: LibraryChapterUpdate): boolean => record === null ||
    typeof record.comicId !== 'string' || typeof record.chapterId !== 'string' ||
    !Number.isFinite(record.discoveredAt) || record.discoveredAt <= 0)) throw new Error('library_updates_invalid')
  return records
}

export function mergeLibraryChapterUpdates(previous: LibraryChapterUpdate[], received: LibraryChapterUpdate[]): LibraryChapterUpdate[] {
  const records = new Map<string, LibraryChapterUpdate>()
  previous.concat(received).forEach((record: LibraryChapterUpdate): void => {
    const key = JSON.stringify([record.comicId, record.chapterId])
    if (!records.has(key)) records.set(key, record)
  })
  return Array.from(records.values()).sort((left: LibraryChapterUpdate, right: LibraryChapterUpdate): number =>
    right.discoveredAt - left.discoveredAt)
}
