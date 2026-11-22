import { relationalStore } from '@kit.ArkData'
import type { ReadingProgress } from './ComicModels'
import type { ChapterReadingState, ReaderSessionDocumentSnapshot } from './ReaderSessionStore'
import type { SourceReadHistoryEntry } from './SourceReaderSession'
import type { RemoteReadHistoryEntry } from './RemoteReaderSession'
import type { ReadingSessionRecord } from './ReadingStatistics'
import type { SyncReadingActionCapture, SyncReadingCapture } from '../deviceSync/DeviceSyncSignals'
import { syncReadingIdentity } from '../deviceSync/DeviceSyncData'
import { collectLocalRows } from './LocalDataRows'
import { appendReaderSessions, orderedReaderSessions, readerChapterStates, readerPositions, readerRemoteHistory, readerRemotePaths,
  readerSessions, readerSourceHistory, readRemoteHistory, remoteHistoryRows, remotePathRows } from './ReaderDataRows'
import { ReaderOutboxRows, readActionOutbox, readPositionOutbox } from './ReaderOutboxRows'
import { hasUserDataMigration } from './UserDataDatabase'
import { writeUserRecords } from './UserKeyedRecords'

const OLD_READER_MIGRATION = 'reading-from-json-v1'
const READER_MIGRATION = 'reader-relational-v1'

function sameSourceWork(comicId: string, source: string, work: string, chapterId?: string): boolean {
  if (!syncReadingIdentity(source, work, chapterId)) return false
  const prefix = source + ':'
  return comicId === (work.startsWith(prefix) ? work : prefix + work)
}

function sharedHistory(row: SourceReadHistoryEntry): boolean {
  return sameSourceWork(row.comicId, row.sourceId, row.mangaId, row.chapterId)
}

function cloudMovedReadingPosition(received: ReadingProgress, before: ReadingProgress | undefined): boolean {
  return received.pageId !== undefined && (before === undefined || received.chapterId !== before.chapterId ||
    received.pageIndex !== before.pageIndex || received.totalPages !== before.totalPages)
}

/** Identity comes from the same staged reading snapshot as the pages. It
 * needs neither catalog hydration nor a cross-library scan during a turn. */
class ReadingScope {
  private readonly sources = new Map<string, string>()
  private readonly works = new Map<string, string>()

  constructor(snapshot: ReaderSessionDocumentSnapshot, turns: ChapterReadingState[] = snapshot.chapters) {
    for (const row of snapshot.sourceHistory) {
      if (!sharedHistory(row)) continue
      this.sources.set(row.comicId, row.sourceId)
      this.works.set(row.comicId, row.mangaId)
    }
    for (const row of turns) {
      const identity = row.sourceIdentity
      if (identity === undefined || this.sources.has(row.comicId) ||
        !sameSourceWork(row.comicId, identity.source, identity.work)) continue
      this.sources.set(row.comicId, identity.source)
      this.works.set(row.comicId, identity.work)
    }
  }

  shares(comicId: string, chapterId: string): boolean {
    const source = this.sources.get(comicId)
    const work = this.works.get(comicId)
    return source !== undefined && work !== undefined && syncReadingIdentity(source, work, chapterId)
  }
}

export interface ReaderSyncWorkScope {
  comicId: string
  chapterIds: string[]
}

async function legacyRows<T>(transaction: relationalStore.Transaction, sql: string, args?: string[]): Promise<T[]> {
  return collectLocalRows(await transaction.querySql(sql, args),
    (row: relationalStore.ResultSet): T => JSON.parse(row.getString(0)) as T)
}

async function readPreviousDatabase(transaction: relationalStore.Transaction): Promise<ReaderSessionDocumentSnapshot> {
  const work = 'SELECT payload FROM reading_works WHERE kind = ? ORDER BY rowid'
  const local = 'SELECT payload FROM reading_local_records WHERE kind = ? ORDER BY list_order'
  return {
    progress: await legacyRows<ReadingProgress>(transaction, work, ['progress']),
    sourceHistory: await legacyRows<SourceReadHistoryEntry>(transaction, work, ['source']),
    remoteHistory: await legacyRows<RemoteReadHistoryEntry>(transaction, work, ['remote']),
    chapters: await legacyRows<ChapterReadingState>(transaction, 'SELECT payload FROM reading_chapter_states ORDER BY rowid'),
    readingSessions: await legacyRows<ReadingSessionRecord>(transaction, local, ['session']),
    syncPositions: await legacyRows<SyncReadingCapture>(transaction, local, ['position']),
    syncActions: await legacyRows<SyncReadingActionCapture>(transaction, local, ['action']),
  }
}

async function hasMarker(transaction: relationalStore.Transaction, name: string): Promise<boolean> {
  const result = await transaction.querySql('SELECT name FROM local_data_migrations WHERE name = ?', [name])
  try {
    return result.goToNextRow()
  } finally {
    result.close()
  }
}

export class ReaderRdbStorage {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  migrated(): boolean {
    return hasUserDataMigration(this.store, READER_MIGRATION)
  }

  usesPreviousDatabase(): boolean {
    return hasUserDataMigration(this.store, OLD_READER_MIGRATION)
  }

  async migrate(legacy?: ReaderSessionDocumentSnapshot): Promise<void> {
    const transaction = await this.store.createTransaction({ transactionType: relationalStore.TransactionType.IMMEDIATE })
    try {
      if (!await hasMarker(transaction, READER_MIGRATION)) {
        // The persisted domain marker has priority even when the old rows are
        // empty. Retained files can contain records the user already removed.
        const snapshot = await hasMarker(transaction, OLD_READER_MIGRATION) ?
          await readPreviousDatabase(transaction) : legacy
        if (snapshot === undefined) throw new Error('reader_migration_source_missing')
        const remote = snapshot.remoteHistory ?? []
        const scope = new ReadingScope(snapshot)
        await readerPositions.importRows(transaction, snapshot.progress,
          (row: ReadingProgress): boolean => scope.shares(row.comicId, row.chapterId))
        await readerSourceHistory.importRows(transaction, snapshot.sourceHistory, sharedHistory)
        await readerRemoteHistory.importRows(transaction, remoteHistoryRows(remote))
        await readerRemotePaths.importRows(transaction, remotePathRows(remote))
        await readerChapterStates.importRows(transaction, snapshot.chapters,
          (row: ChapterReadingState): boolean => scope.shares(row.comicId, row.chapterId))
        await readerSessions.importRows(transaction, orderedReaderSessions(snapshot.readingSessions ?? []))
        await new ReaderOutboxRows(snapshot.syncPositions ?? [], snapshot.syncActions ?? []).importRows(transaction)
        await transaction.execute('INSERT INTO local_data_migrations (name) VALUES (?)', [READER_MIGRATION])
      }
      await transaction.commit()
    } catch (error) {
      await transaction.rollback()
      throw error as Error
    }
  }

  readForSync(): ReaderSessionDocumentSnapshot {
    const syncPositions = readPositionOutbox(this.store)
    const syncActions = readActionOutbox(this.store)
    return {
      progress: readerPositions.read(this.store),
      sourceHistory: readerSourceHistory.read(this.store),
      chapters: readerChapterStates.read(this.store),
      syncPositions: syncPositions.length === 0 ? undefined : syncPositions,
      syncActions: syncActions.length === 0 ? undefined : syncActions,
    }
  }

  read(): ReaderSessionDocumentSnapshot {
    const reading = this.readForSync()
    reading.remoteHistory = readRemoteHistory(this.store)
    reading.readingSessions = readerSessions.read(this.store).map(record => record.session)
    return reading
  }

  readWorkForSync(comicId: string): ReaderSessionDocumentSnapshot {
    return {
      progress: [],
      sourceHistory: readerSourceHistory.read(this.store, 'comic_id = ?', [comicId]),
      chapters: readerChapterStates.read(this.store, 'comic_id = ?', [comicId]),
    }
  }

  readCatalogLinkReading(comicIds: string[]): ReaderSessionDocumentSnapshot {
    const reading: ReaderSessionDocumentSnapshot = { progress: [], chapters: [], sourceHistory: [] }
    for (const id of comicIds) {
      reading.progress.push(...readerPositions.read(this.store, 'comic_id = ?', [id]))
      reading.sourceHistory.push(...readerSourceHistory.read(this.store, 'comic_id = ?', [id]))
      for (const row of readerChapterStates.read(this.store, 'comic_id = ?', [id])) reading.chapters.push(row)
    }
    return reading
  }

  async stageCatalogLink(transaction: relationalStore.Transaction, comicIds: string[],
    reading: ReaderSessionDocumentSnapshot): Promise<void> {
    const scope = new ReadingScope(reading)
    for (const id of comicIds) {
      const sharedPosition = await readerPositions.sharedChapterIds(transaction, id)
      const sharedChapters = await readerChapterStates.sharedChapterIds(transaction, id)
      await readerPositions.replaceWork(transaction, id,
        reading.progress.filter((row: ReadingProgress): boolean => row.comicId === id),
        (row: ReadingProgress): boolean => scope.shares(id, row.chapterId) || sharedPosition.has(row.chapterId))
      await readerSourceHistory.replaceWork(transaction, id,
        reading.sourceHistory.filter((row: SourceReadHistoryEntry): boolean => row.comicId === id), sharedHistory)
      await readerChapterStates.replaceWork(transaction, id,
        reading.chapters.filter((row: ChapterReadingState): boolean => row.comicId === id),
        (row: ChapterReadingState): boolean => scope.shares(id, row.chapterId) || sharedChapters.has(row.chapterId))
    }
  }

  /** WebDAV receipts only touch the works and chapters mentioned by remote edits.
   * Remote server history and local reading statistics have separate owners. */
  readSyncEdits(scope: ReaderSyncWorkScope[]): ReaderSessionDocumentSnapshot {
    const reading: ReaderSessionDocumentSnapshot = { progress: [], chapters: [], sourceHistory: [] }
    for (const work of scope) {
      reading.progress.push(...readerPositions.read(this.store, 'comic_id = ?', [work.comicId]))
      reading.sourceHistory.push(...readerSourceHistory.read(this.store, 'comic_id = ?', [work.comicId]))
      for (const chapterId of work.chapterIds) {
        reading.chapters.push(...readerChapterStates.read(this.store, 'comic_id = ? AND chapter_id = ?',
          [work.comicId, chapterId]))
      }
    }
    reading.syncPositions = readPositionOutbox(this.store)
    reading.syncActions = readActionOutbox(this.store)
    return reading
  }

  applyCloudReading(scope: ReaderSyncWorkScope[], before: ReaderSessionDocumentSnapshot): ReaderSessionDocumentSnapshot {
    const reading: ReaderSessionDocumentSnapshot = { progress: [], chapters: [], sourceHistory: [] }
    const local = new ReadingScope(before)
    writeUserRecords(this.store, (): void => {
      for (const work of scope) {
        const id = work.comicId
        const recent = readerPositions.read(this.store, 'comic_id = ?', [id])[0]
        const old = before.progress.find((row: ReadingProgress): boolean => row.comicId === id)
        let history = readerSourceHistory.read(this.store, 'comic_id = ?', [id])[0]
        const retained = recent !== undefined && old !== undefined && old.updatedAt >= recent.updatedAt &&
          (old.chapterId !== recent.chapterId || old.pageIndex !== recent.pageIndex)
        if (retained) {
          this.putPosition(old, local)
          const priorHistory = before.sourceHistory.find((row: SourceReadHistoryEntry): boolean => row.comicId === id)
          // The page conflict only decides the position. An absent history
          // row is already deleted, so retaining the page cannot restore it.
          if (history !== undefined && priorHistory !== undefined) {
            readerSourceHistory.put(this.store, priorHistory, sharedHistory(priorHistory))
            history = priorHistory
          }
          reading.progress.push(old)
        } else {
          if (recent !== undefined) {
            // ArkData updates the portable position and leaves the local page ID
            // in the row. It belongs to the previous position on this device.
            if (cloudMovedReadingPosition(recent, old)) {
              this.store.executeSync('UPDATE reader_current_positions SET page_id = NULL WHERE comic_id = ?', [id])
              recent.pageId = undefined
            }
            reading.progress.push(recent)
          }
        }
        if (history !== undefined) reading.sourceHistory.push(history)
        const chapters = new Set(work.chapterIds)
        if (recent !== undefined) chapters.add(recent.chapterId)
        if (old !== undefined && retained) chapters.add(old.chapterId)
        for (const chapterId of chapters) {
          const row = readerChapterStates.read(this.store, 'comic_id = ? AND chapter_id = ?', [id, chapterId])[0]
          if (row === undefined) continue
          const prior = before.chapters.find((entry: ChapterReadingState): boolean => entry.comicId === id && entry.chapterId === chapterId)
          if (row.position !== undefined && prior?.position !== undefined &&
            prior.position.updatedAt >= row.position.updatedAt && prior.position.pageIndex !== row.position.pageIndex) {
            row.position = prior.position
            this.putChapter(row, local)
          } else if (row.position !== undefined && cloudMovedReadingPosition(row.position, prior?.position)) {
            this.store.executeSync('UPDATE reader_chapter_states SET page_id = NULL WHERE comic_id = ? AND chapter_id = ?',
              [id, chapterId])
            row.position.pageId = undefined
          }
          reading.chapters.push(row)
        }
      }
    })
    return reading
  }

  writeSyncEdits(scope: ReaderSyncWorkScope[], reading: ReaderSessionDocumentSnapshot): void {
    writeUserRecords(this.store, (): void => {
      const share = new ReadingScope(reading)
      const progress = new Map<string, ReadingProgress>()
      const history = new Map<string, SourceReadHistoryEntry>()
      const chapters = new Map<string, Map<string, ChapterReadingState>>()
      for (const row of reading.progress) progress.set(row.comicId, row)
      for (const row of reading.sourceHistory) history.set(row.comicId, row)
      for (const row of reading.chapters) {
        let work = chapters.get(row.comicId)
        if (work === undefined) {
          work = new Map<string, ChapterReadingState>()
          chapters.set(row.comicId, work)
        }
        work.set(row.chapterId, row)
      }
      for (const work of scope) {
        const position = progress.get(work.comicId)
        if (position === undefined) readerPositions.remove(this.store, [work.comicId])
        else this.putPosition(position, share)
        const source = history.get(work.comicId)
        if (source === undefined) readerSourceHistory.remove(this.store, [work.comicId])
        else readerSourceHistory.put(this.store, source, sharedHistory(source))
        for (const chapterId of work.chapterIds) {
          const chapter = chapters.get(work.comicId)?.get(chapterId)
          if (chapter === undefined) readerChapterStates.remove(this.store, [work.comicId, chapterId])
          else this.putChapter(chapter, share)
        }
      }
      new ReaderOutboxRows(reading.syncPositions ?? [], reading.syncActions ?? []).replace(this.store)
    })
  }

  /** Chapter actions and history removal commit with the same outbox as page turns. */
  saveActivityEdits(reading: ReaderSessionDocumentSnapshot, removedHistory: string[] = []): void {
    writeUserRecords(this.store, (): void => {
      const scope = new ReadingScope(reading)
      for (const chapter of reading.chapters) this.putChapter(chapter, scope)
      for (const position of reading.progress) this.putPosition(position, scope)
      for (const id of removedHistory) {
        readerPositions.remove(this.store, [id])
        readerSourceHistory.remove(this.store, [id])
        readerRemoteHistory.remove(this.store, [id])
        this.store.executeSync('DELETE FROM reader_remote_history_paths WHERE comic_id = ?', [id])
        this.store.executeSync('DELETE FROM reader_sessions WHERE comic_id = ?', [id])
      }
      new ReaderOutboxRows(reading.syncPositions ?? [], reading.syncActions ?? []).replace(this.store)
    })
  }

  save(snapshot: ReaderSessionDocumentSnapshot, pageTurns?: ChapterReadingState[]): void {
    writeUserRecords(this.store, (): void => {
      const scope = new ReadingScope(snapshot, pageTurns)
      if (pageTurns === undefined) {
        const remote = snapshot.remoteHistory ?? []
        readerPositions.replace(this.store, snapshot.progress, (row: ReadingProgress): boolean => this.sharesPosition(row, scope))
        readerSourceHistory.replace(this.store, snapshot.sourceHistory, sharedHistory)
        readerRemoteHistory.replace(this.store, remoteHistoryRows(remote))
        readerRemotePaths.replace(this.store, remotePathRows(remote))
        readerChapterStates.replace(this.store, snapshot.chapters, (row: ChapterReadingState): boolean => this.sharesChapter(row, scope))
        readerSessions.replace(this.store, orderedReaderSessions(snapshot.readingSessions ?? []))
      } else {
        // The chapter position, current position and outbox advance together.
        for (const chapter of pageTurns) {
          if (chapter.position === undefined) continue
          this.putChapter(chapter, scope)
        }
        for (const position of snapshot.progress) {
          this.putPosition(position, scope)
        }
        for (const history of snapshot.sourceHistory) readerSourceHistory.put(this.store, history, sharedHistory(history))
        appendReaderSessions(this.store, snapshot.readingSessions ?? [])
      }
      new ReaderOutboxRows(snapshot.syncPositions ?? [], snapshot.syncActions ?? []).replace(this.store)
    })
  }

  private sharesPosition(row: ReadingProgress, scope: ReadingScope): boolean {
    return scope.shares(row.comicId, row.chapterId) ||
      readerPositions.hasSharedChapter(this.store, row.comicId, row.chapterId)
  }

  private sharesChapter(row: ChapterReadingState, scope: ReadingScope): boolean {
    return scope.shares(row.comicId, row.chapterId) ||
      readerChapterStates.hasSharedChapter(this.store, row.comicId, row.chapterId)
  }

  private putPosition(position: ReadingProgress, scope: ReadingScope): void {
    readerPositions.put(this.store, position, this.sharesPosition(position, scope))
  }

  private putChapter(chapter: ChapterReadingState, scope: ReadingScope): void {
    readerChapterStates.put(this.store, chapter, this.sharesChapter(chapter, scope))
  }
}
