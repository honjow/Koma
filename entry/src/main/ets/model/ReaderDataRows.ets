import type { relationalStore } from '@kit.ArkData'
import { syncCoverAddress, syncReadingWorkAddress } from '../deviceSync/DeviceSyncData'
import type { ReaderSeriesFormat, ReadingProgress } from './ComicModels'
import type { ChapterReadingState } from './ReaderSessionStore'
import type { ReadingSessionRecord } from './ReadingStatistics'
import type { SourceReadHistoryEntry } from './SourceReaderSession'
import type { RemoteHistoryKind, RemoteReadHistoryEntry } from './RemoteReaderSession'
import { booleanColumn, booleanValue, integerColumn, LocalColumnValue, LocalDataRows, realColumn, textColumn } from './LocalDataRows'

const POSITION_FIELDS: string[] = ['page_id', 'page_index', 'total_pages', 'progress_ratio', 'completed', 'saved_at', 'column_mode']

function positionValues(position: ReadingProgress | undefined): LocalColumnValue[] {
  return [position?.pageId ?? null, position?.pageIndex ?? null, position?.totalPages ?? null,
    position?.progressRatio ?? null, booleanValue(position?.completed), position?.updatedAt ?? null,
    position?.columnMode ?? null]
}

function positionFromRow(row: relationalStore.ResultSet, offset: number, comicId: string, chapterId: string): ReadingProgress {
  return {
    comicId,
    chapterId,
    pageId: textColumn(row, offset),
    pageIndex: integerColumn(row, offset + 1) as number,
    totalPages: integerColumn(row, offset + 2) as number,
    progressRatio: realColumn(row, offset + 3) as number,
    completed: booleanColumn(row, offset + 4) as boolean,
    updatedAt: integerColumn(row, offset + 5) as number,
    columnMode: textColumn(row, offset + 6) as 'odd_left' | 'even_left' | undefined,
  }
}

class ScopedReaderRows<T> {
  private readonly table: string
  private readonly shared: LocalDataRows<T>
  private readonly local: LocalDataRows<T>
  private readonly combined: LocalDataRows<T>
  private readonly key: (row: T) => LocalColumnValue[]

  constructor(table: string, rows: (table: string, order: string) => LocalDataRows<T>,
    key: (row: T) => LocalColumnValue[]) {
    this.table = table
    this.shared = rows(table, 'rowid')
    this.local = rows(table + '_local', 'rowid')
    this.combined = rows(table + '_all', 'storage_order, comic_id')
    this.key = key
  }

  read(store: relationalStore.RdbStore, filter?: string, args?: LocalColumnValue[]): T[] {
    return this.combined.read(store, filter, args)
  }

  /** Scope is already established for this exact work and chapter, even
   * after history is removed and the cloud row has no local source metadata. */
  hasSharedChapter(store: relationalStore.RdbStore, comicId: string, chapterId: string): boolean {
    const result = store.querySqlSync('SELECT 1 FROM ' + this.table +
      ' WHERE comic_id = ? AND chapter_id = ? LIMIT 1', [comicId, chapterId])
    try {
      return result.goToNextRow()
    } finally {
      result.close()
    }
  }

  put(store: relationalStore.RdbStore, row: T, share: boolean): void {
    const target = share ? this.shared : this.local
    const previous = share ? this.local : this.shared
    target.put(store, row)
    previous.remove(store, this.key(row))
  }

  remove(store: relationalStore.RdbStore, key: LocalColumnValue[]): void {
    this.shared.remove(store, key)
    this.local.remove(store, key)
  }

  async importRows(transaction: relationalStore.Transaction, rows: T[], share: (row: T) => boolean): Promise<void> {
    const shared: T[] = []
    const local: T[] = []
    const sharedOrder: number[] = []
    const localOrder: number[] = []
    // The combined read preserves the original order across both partitions.
    rows.forEach((row: T, index: number): void => {
      const portable = share(row)
      if (portable) {
        shared.push(row)
        sharedOrder.push(index + 1)
      } else {
        local.push(row)
        localOrder.push(index + 1)
      }
    })
    await this.shared.importRows(transaction, shared, sharedOrder)
    await this.local.importRows(transaction, local, localOrder)
  }

  replace(store: relationalStore.RdbStore, rows: T[], share: (row: T) => boolean): void {
    const shared: T[] = []
    const local: T[] = []
    for (const row of rows) (share(row) ? shared : local).push(row)
    this.shared.replace(store, shared)
    this.local.replace(store, local)
  }
}

function positionRows(table: string, order: string): LocalDataRows<ReadingProgress> {
  return new LocalDataRows<ReadingProgress>(table, ['comic_id'], ['chapter_id'].concat(POSITION_FIELDS), order,
  (position: ReadingProgress): LocalColumnValue[] => {
    const keys: LocalColumnValue[] = [position.comicId, position.chapterId]
    return keys.concat(positionValues(position))
  },
    (row: relationalStore.ResultSet): ReadingProgress => positionFromRow(row, 2, row.getString(0), row.getString(1)))
}

function chapterRows(table: string, order: string): LocalDataRows<ChapterReadingState> {
  return new LocalDataRows<ChapterReadingState>(table, ['comic_id', 'chapter_id'],
  ['is_read', 'bookmarked', 'updated_at', 'source_id', 'source_work_id', 'has_position', 'position_comic_id_override',
    'position_chapter_id_override']
    .concat(POSITION_FIELDS), order,
  (chapter: ChapterReadingState): LocalColumnValue[] => {
    const values: LocalColumnValue[] = [chapter.comicId, chapter.chapterId, booleanValue(chapter.isRead),
      booleanValue(chapter.bookmarked), chapter.updatedAt ?? null, chapter.sourceIdentity?.source ?? null,
      chapter.sourceIdentity?.work ?? null, booleanValue(chapter.position !== undefined),
      chapter.position?.comicId === chapter.comicId ? null : chapter.position?.comicId ?? null,
      chapter.position?.chapterId === chapter.chapterId ? null : chapter.position?.chapterId ?? null]
    return values.concat(positionValues(chapter.position))
  },
  (row: relationalStore.ResultSet): ChapterReadingState => ({
    comicId: row.getString(0),
    chapterId: row.getString(1),
    isRead: booleanColumn(row, 2) as boolean,
    bookmarked: booleanColumn(row, 3),
    updatedAt: integerColumn(row, 4) as number,
    sourceIdentity: row.isColumnNull(5) ? undefined : { source: row.getString(5), work: row.getString(6) },
    position: row.getLong(7) === 0 ? undefined :
      positionFromRow(row, 10, textColumn(row, 8) ?? row.getString(0), textColumn(row, 9) ?? row.getString(1)),
  }))
}

function sourceHistoryRows(table: string, order: string): LocalDataRows<SourceReadHistoryEntry> {
  return new LocalDataRows<SourceReadHistoryEntry>(table, ['comic_id'],
  ['source_id', 'manga_id', 'manga_url', 'title', 'cover_uri', 'source_name', 'reading_format', 'chapter_id', 'chapter_title',
    'shared_manga_url', 'shared_cover_uri'],
  order,
  (entry: SourceReadHistoryEntry): LocalColumnValue[] => {
    const url = syncReadingWorkAddress(entry.mangaUrl)
    const cover = syncCoverAddress(entry.coverUri)
    return [entry.comicId, entry.sourceId ?? null, entry.mangaId ?? null,
      url === undefined ? entry.mangaUrl ?? null : null, entry.title ?? null,
      cover === undefined ? entry.coverUri ?? null : null, entry.sourceName ?? null,
      entry.readingFormat ?? null, entry.chapterId ?? null, entry.chapterTitle ?? null, url ?? null, cover ?? null]
  },
  (row: relationalStore.ResultSet): SourceReadHistoryEntry => ({
    comicId: row.getString(0),
    sourceId: textColumn(row, 1) as string,
    mangaId: textColumn(row, 2) as string,
    mangaUrl: textColumn(row, 3) ?? textColumn(row, 10),
    title: textColumn(row, 4) as string,
    coverUri: textColumn(row, 5) ?? textColumn(row, 11),
    sourceName: textColumn(row, 6),
    readingFormat: textColumn(row, 7) as ReaderSeriesFormat | undefined,
    chapterId: textColumn(row, 8) as string,
    chapterTitle: textColumn(row, 9),
  }))
}

export const readerPositions = new ScopedReaderRows<ReadingProgress>('reader_current_positions', positionRows,
  (row: ReadingProgress): LocalColumnValue[] => [row.comicId])
export const readerChapterStates = new ScopedReaderRows<ChapterReadingState>('reader_chapter_states', chapterRows,
  (row: ChapterReadingState): LocalColumnValue[] => [row.comicId, row.chapterId])
export const readerSourceHistory = new ScopedReaderRows<SourceReadHistoryEntry>('reader_source_history', sourceHistoryRows,
  (row: SourceReadHistoryEntry): LocalColumnValue[] => [row.comicId])

interface ReaderRemoteRow {
  entry: RemoteReadHistoryEntry
  hasPath: boolean
}

export const readerRemoteHistory = new LocalDataRows<ReaderRemoteRow>('reader_remote_history', ['comic_id'],
  ['remote_kind', 'chapter_id', 'server_id', 'resource_id', 'title', 'chapter_title', 'library_id', 'has_path',
    'is_opds_root_feed', 'opds_feed_path', 'opds_search_query'], 'rowid',
  (record: ReaderRemoteRow): LocalColumnValue[] => {
    const entry = record.entry
    return [entry.comicId, entry.kind, entry.chapterId, entry.serverId, entry.resourceId, entry.title,
      entry.chapterTitle ?? null, entry.libraryId ?? null, booleanValue(record.hasPath),
      booleanValue(entry.opdsRootFeed), entry.opdsFeedPath ?? null, entry.opdsSearchQuery ?? null]
  },
  (row: relationalStore.ResultSet): ReaderRemoteRow => ({
    entry: {
      comicId: row.getString(0),
      kind: row.getString(1) as RemoteHistoryKind,
      chapterId: row.getString(2),
      serverId: row.getString(3),
      resourceId: row.getString(4),
      title: row.getString(5),
      chapterTitle: textColumn(row, 6),
      libraryId: integerColumn(row, 7),
      opdsRootFeed: booleanColumn(row, 9),
      opdsFeedPath: textColumn(row, 10),
      opdsSearchQuery: textColumn(row, 11),
    },
    hasPath: row.getLong(8) !== 0,
  }))

interface ReaderRemotePathPart {
  comicId: string
  order: number
  segment: string
}

export const readerRemotePaths = new LocalDataRows<ReaderRemotePathPart>('reader_remote_history_paths',
  ['comic_id', 'path_order'], ['segment'], 'comic_id, path_order',
  (part: ReaderRemotePathPart): LocalColumnValue[] => [part.comicId, part.order, part.segment],
  (row: relationalStore.ResultSet): ReaderRemotePathPart =>
    ({ comicId: row.getString(0), order: row.getLong(1), segment: row.getString(2) }))

export function remoteHistoryRows(entries: RemoteReadHistoryEntry[]): ReaderRemoteRow[] {
  return entries.map((entry: RemoteReadHistoryEntry): ReaderRemoteRow => ({ entry, hasPath: entry.pathSegments !== undefined }))
}

export function remotePathRows(entries: RemoteReadHistoryEntry[]): ReaderRemotePathPart[] {
  const parts: ReaderRemotePathPart[] = []
  for (const entry of entries) {
    entry.pathSegments?.forEach((segment: string, order: number): void => { parts.push({ comicId: entry.comicId, order, segment }) })
  }
  return parts
}

export function readRemoteHistory(store: relationalStore.RdbStore): RemoteReadHistoryEntry[] {
  const paths = new Map<string, string[]>()
  for (const part of readerRemotePaths.read(store)) {
    const path = paths.get(part.comicId)
    if (path === undefined) paths.set(part.comicId, [part.segment])
    else path.push(part.segment)
  }
  return readerRemoteHistory.read(store).map((record: ReaderRemoteRow): RemoteReadHistoryEntry => {
    if (record.hasPath) record.entry.pathSegments = paths.get(record.entry.comicId) ?? []
    return record.entry
  })
}

interface OrderedReadingSession {
  order: number
  occurrence: number
  session: ReadingSessionRecord
}

export const readerSessions = new LocalDataRows<OrderedReadingSession>('reader_sessions',
  ['comic_id', 'chapter_id', 'started_at', 'ended_at', 'session_occurrence'], ['session_order', 'pages_read'], 'session_order',
  (record: OrderedReadingSession): LocalColumnValue[] => [record.session.comicId, record.session.chapterId,
    record.session.startedAt, record.session.endedAt, record.occurrence, record.order, record.session.pagesRead],
  (row: relationalStore.ResultSet): OrderedReadingSession => ({
    occurrence: row.getLong(4),
    order: row.getLong(5),
    session: {
      comicId: row.getString(0), chapterId: row.getString(1), startedAt: row.getLong(2),
      endedAt: row.getLong(3), pagesRead: row.getLong(6),
    },
  }))

export function orderedReaderSessions(rows: ReadingSessionRecord[]): OrderedReadingSession[] {
  const seen = new Map<string, number>()
  return rows.map((session: ReadingSessionRecord, order: number): OrderedReadingSession => {
    const key = JSON.stringify([session.comicId, session.chapterId, session.startedAt, session.endedAt])
    const occurrence = seen.get(key) ?? 0
    seen.set(key, occurrence + 1)
    return { order, occurrence, session }
  })
}
