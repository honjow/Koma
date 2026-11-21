import { relationalStore } from '@kit.ArkData'
import type { ReadingProgress } from './ComicModels'
import type { ChapterReadingState, ReaderSessionDocumentSnapshot } from './ReaderSessionStore'
import type { SourceReadHistoryEntry } from './SourceReaderSession'
import type { RemoteReadHistoryEntry } from './RemoteReaderSession'
import type { ReadingSessionRecord } from './ReadingStatistics'
import type { SyncReadingActionCapture, SyncReadingCapture } from '../deviceSync/DeviceSyncSignals'
import { collectLocalRows } from './LocalDataRows'
import { orderedReaderSessions, readerChapterStates, readerPositions, readerRemoteHistory, readerRemotePaths,
  readerSessions, readerSourceHistory, readRemoteHistory, remoteHistoryRows, remotePathRows } from './ReaderDataRows'
import { ReaderOutboxRows, readActionOutbox, readPositionOutbox } from './ReaderOutboxRows'
import { hasUserDataMigration } from './UserDataDatabase'
import { writeUserRecords } from './UserKeyedRecords'

const OLD_READER_MIGRATION = 'reading-from-json-v1'
const READER_MIGRATION = 'reader-relational-v1'

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
        await readerPositions.importRows(transaction, snapshot.progress)
        await readerSourceHistory.importRows(transaction, snapshot.sourceHistory)
        await readerRemoteHistory.importRows(transaction, remoteHistoryRows(remote))
        await readerRemotePaths.importRows(transaction, remotePathRows(remote))
        await readerChapterStates.importRows(transaction, snapshot.chapters)
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

  writeSyncEdits(scope: ReaderSyncWorkScope[], reading: ReaderSessionDocumentSnapshot): void {
    writeUserRecords(this.store, (): void => {
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
        else readerPositions.put(this.store, position)
        const source = history.get(work.comicId)
        if (source === undefined) readerSourceHistory.remove(this.store, [work.comicId])
        else readerSourceHistory.put(this.store, source)
        for (const chapterId of work.chapterIds) {
          const chapter = chapters.get(work.comicId)?.get(chapterId)
          if (chapter === undefined) readerChapterStates.remove(this.store, [work.comicId, chapterId])
          else readerChapterStates.put(this.store, chapter)
        }
      }
      new ReaderOutboxRows(reading.syncPositions ?? [], reading.syncActions ?? []).replace(this.store)
    })
  }

  save(snapshot: ReaderSessionDocumentSnapshot, pageTurns?: ChapterReadingState[]): void {
    writeUserRecords(this.store, (): void => {
      if (pageTurns === undefined) {
        const remote = snapshot.remoteHistory ?? []
        readerPositions.replace(this.store, snapshot.progress)
        readerSourceHistory.replace(this.store, snapshot.sourceHistory)
        readerRemoteHistory.replace(this.store, remoteHistoryRows(remote))
        readerRemotePaths.replace(this.store, remotePathRows(remote))
        readerChapterStates.replace(this.store, snapshot.chapters)
        readerSessions.replace(this.store, orderedReaderSessions(snapshot.readingSessions ?? []))
      } else {
        // The chapter position, current position and outbox advance together.
        for (const chapter of pageTurns) {
          if (chapter.position === undefined) continue
          readerChapterStates.put(this.store, chapter)
          readerPositions.put(this.store, chapter.position)
        }
        for (const history of snapshot.sourceHistory) readerSourceHistory.put(this.store, history)
      }
      new ReaderOutboxRows(snapshot.syncPositions ?? [], snapshot.syncActions ?? []).replace(this.store)
    })
  }
}
