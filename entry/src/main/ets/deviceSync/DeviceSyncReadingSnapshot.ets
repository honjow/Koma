import { PersistedComic, PersistedChapter, readLibraryStoreDocument } from '../model/LibraryPersistence'
import { AppFilesReaderSessionPersistenceAdapter, ChapterReadingState } from '../model/ReaderSessionStore'
import { ReadingProgress } from '../model/ComicModels'
import { SourceReadHistoryEntry } from '../model/SourceReaderSession'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import { SyncFact } from './DeviceSyncFacts'
import {
  syncCoverAddress, syncGroupVisibleValue, syncKey, syncKeyParts, syncReadingIdentity, syncReadingPosition,
  syncReadingRecent, SyncPositionValue, SyncRecentValue,
} from './DeviceSyncData'
import { emptySyncLibrary, shelfSourceCover, SyncSourceIdentity } from './DeviceSyncShelfApply'
import { SyncReadingActionCapture, SyncReadingCapture } from './DeviceSyncSignals'
import { SyncLocalValue } from './DeviceSyncStorage'
import { syncDigest } from './DeviceSyncWire'

export interface SyncLocalReadingWork extends SyncSourceIdentity {
  comic?: PersistedComic
  history?: SourceReadHistoryEntry
}

export function validDate(date: number): number {
  const now = Date.now()
  return Number.isFinite(date) && date >= 0 ? Math.min(Math.round(date), now + 24 * 60 * 60 * 1000) : 0
}

export function rememberLibraryIdentity(result: Map<string, SyncLocalReadingWork>, comic: PersistedComic): void {
  const source = comic.sourceRuntimeId
  const work = comic.remoteResourceId
  if (source !== undefined && work !== undefined) result.set(comic.id, { source, work, comic })
}

export function rememberChapterIdentity(result: Map<string, SyncLocalReadingWork>, chapter: ChapterReadingState): void {
  const identity = chapter.sourceIdentity
  if (identity !== undefined && !result.has(chapter.comicId) &&
    syncReadingIdentity(identity.source, identity.work) && sourceLibraryComicId(identity.source, identity.work) === chapter.comicId) {
    result.set(chapter.comicId, { source: identity.source, work: identity.work })
  }
}

export function rememberHistoryIdentity(result: Map<string, SyncLocalReadingWork>, entry: SourceReadHistoryEntry): void {
  result.set(entry.comicId, { source: entry.sourceId, work: entry.mangaId, history: entry,
    comic: result.get(entry.comicId)?.comic })
}

export function rememberFactIdentity(result: Map<string, SyncLocalReadingWork>, fact: SyncFact): void {
  const parts = syncKeyParts(fact.key)
  const id = sourceLibraryComicId(parts[1], parts[2])
  if (!result.has(id)) result.set(id, { source: parts[1], work: parts[2] })
}

export function recentFromLocal(source: string, chapter: string, date: number, page: number | undefined,
  work?: SyncLocalReadingWork): SyncRecentValue {
  const history = work?.history
  const comic = work?.comic
  const chapterTitle = history?.chapterId === chapter ? history.chapterTitle : undefined
  return syncReadingRecent(source, chapter, validDate(date), history?.title ?? comic?.title ?? source,
    history?.sourceName ?? comic?.sourceMetadata?.sourceName ?? source,
    chapterTitle ?? comic?.chapters.find((row: PersistedChapter): boolean => row.id === chapter)?.title ?? '',
    page, history?.mangaUrl ?? comic?.sourcePath)
}

function row(values: SyncLocalValue[], key: string[], value: string | boolean | Object): void {
  values.push({ key: syncKey(key), value: JSON.stringify(value) })
}

function knownValue(facts: Map<string, SyncFact>, key: string): string | undefined {
  const fact = facts.get(key)
  return fact === undefined ? undefined : syncGroupVisibleValue('reading', fact)
}

/** The persisted chapter/page is sufficient for export. Source package and
 * account checks belong to opening the chapter on each device. */
export function appendReadingProgress(values: SyncLocalValue[], progress: ReadingProgress,
  identities: Map<string, SyncLocalReadingWork>, facts: Map<string, SyncFact>): number {
  const identity = identities.get(progress.comicId)
  if (identity === undefined || !syncReadingIdentity(identity.source, identity.work, progress.chapterId)) {
    return 1
  }
  const recentKey = syncKey(['recent', identity.source, identity.work])
  const cover = shelfSourceCover(identity.comic) ?? syncCoverAddress(identity.history?.coverUri)
  if (cover !== undefined) row(values, ['cover', identity.source, identity.work], cover)
  const known = knownValue(facts, recentKey)
  const saved = known === undefined ? undefined : JSON.parse(known) as SyncRecentValue
  if (known !== undefined && saved?.chapter === progress.chapterId && saved.date === validDate(progress.updatedAt)) {
    values.push({ key: recentKey, value: known })
    return 0
  }
  const position = syncReadingPosition(progress.pageIndex, progress.totalPages)
  row(values, ['recent', identity.source, identity.work],
    recentFromLocal(identity.source, progress.chapterId, progress.updatedAt, position?.page, identity))
  return 0
}

export function appendReadingChapter(values: SyncLocalValue[], chapter: ChapterReadingState,
  identities: Map<string, SyncLocalReadingWork>, facts: Map<string, SyncFact>): void {
  const identity = identities.get(chapter.comicId)
  if (identity === undefined || !syncReadingIdentity(identity.source, identity.work, chapter.chapterId)) return
  const suffix = [identity.source, identity.work, chapter.chapterId]
  const positionKey = syncKey(['position'].concat(suffix))
  const known = chapter.position === undefined ? undefined : knownValue(facts, positionKey)
  const saved = known === undefined ? undefined : JSON.parse(known) as SyncPositionValue
  const position = chapter.position === undefined ? undefined :
    syncReadingPosition(chapter.position.pageIndex, chapter.position.totalPages, chapter.position.updatedAt)
  if (position !== undefined) {
    if (known !== undefined && saved?.page === position.page && saved.total === position.total) {
      values.push({ key: positionKey, value: known })
    } else {
      row(values, ['position'].concat(suffix), position)
    }
  }
  if (chapter.isRead || knownValue(facts, syncKey(['read'].concat(suffix))) === 'false') {
    row(values, ['read'].concat(suffix), chapter.isRead)
  }
  if (chapter.bookmarked === true || knownValue(facts, syncKey(['bookmark'].concat(suffix))) === 'false') {
    row(values, ['bookmark'].concat(suffix), chapter.bookmarked === true)
  }
}

export interface SyncProjectedReadingSnapshot {
  valueChunks: string[]
  skipped: number
  revision: string
  historyKeys: string[]
  positions: SyncReadingCapture[]
  actions: SyncReadingActionCapture[]
}

/** Keep persisted chapter objects and key validation on the same worker.
 * Return the wire rows in bounded text chunks instead of the parsed document. */
export function buildSyncReadingSnapshot(directory: string, rawLibrary: string | null, rawReading: string | null,
  side: string, archive: string, factChunks: string[]): SyncProjectedReadingSnapshot {
  const library = rawLibrary === null ? emptySyncLibrary() : readLibraryStoreDocument(rawLibrary)
  const reading = new AppFilesReaderSessionPersistenceAdapter(directory).loadSnapshot(rawReading)
  const identities = new Map<string, SyncLocalReadingWork>()
  for (const comic of library.comics) rememberLibraryIdentity(identities, comic)
  for (const chapter of reading.chapters) rememberChapterIdentity(identities, chapter)
  for (const entry of reading.sourceHistory) rememberHistoryIdentity(identities, entry)
  const facts = new Map<string, SyncFact>()
  for (const chunk of factChunks) {
    for (const fact of JSON.parse(chunk) as SyncFact[]) {
      rememberFactIdentity(identities, fact)
      facts.set(fact.key, fact)
    }
  }
  const values: SyncLocalValue[] = []
  let skipped = 0
  for (const progress of reading.progress) skipped += appendReadingProgress(values, progress, identities, facts)
  for (const chapter of reading.chapters) appendReadingChapter(values, chapter, identities, facts)
  const valueChunks: string[] = []
  for (let start = 0; start < values.length; start += 64) {
    valueChunks.push(JSON.stringify(values.slice(start, start + 64)))
  }
  return { valueChunks, skipped, revision: syncDigest([rawLibrary ?? '', rawReading ?? '', side, archive].join('')),
    historyKeys: reading.sourceHistory.map((entry: SourceReadHistoryEntry): string =>
      syncKey(['recent', entry.sourceId, entry.mangaId])),
    positions: reading.syncPositions ?? [], actions: reading.syncActions ?? [] }
}
