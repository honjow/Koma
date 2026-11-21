import { relationalStore } from '@kit.ArkData'
import type { ReadingProgress } from './ComicModels'
import type { ChapterReadingState, ReaderSessionDocumentSnapshot } from './ReaderSessionStore'
import type { SourceReadHistoryEntry } from './SourceReaderSession'
import type { RemoteReadHistoryEntry } from './RemoteReaderSession'
import type { ReadingSessionRecord } from './ReadingStatistics'
import type { SyncReadingActionCapture, SyncReadingCapture } from '../deviceSync/DeviceSyncSignals'

const READER_MIGRATION = 'reading-from-json-v1'
const WORK_UPSERT = 'INSERT INTO reading_works (kind, comic_id, payload) VALUES (?, ?, ?) ' +
  'ON CONFLICT(kind, comic_id) DO UPDATE SET payload=excluded.payload WHERE payload<>excluded.payload'
const CHAPTER_UPSERT = 'INSERT INTO reading_chapter_states (comic_id, chapter_id, payload) VALUES (?, ?, ?) ' +
  'ON CONFLICT(comic_id, chapter_id) DO UPDATE SET payload=excluded.payload WHERE payload<>excluded.payload'
const LOCAL_UPSERT = 'INSERT INTO reading_local_records (kind, list_order, payload) VALUES (?, ?, ?) ' +
  'ON CONFLICT(kind, list_order) DO UPDATE SET payload=excluded.payload WHERE payload<>excluded.payload'

interface WorkRecord {
  comicId: string
}

function payloadList<T>(rows: relationalStore.ResultSet): T[] {
  const values: T[] = []
  try {
    while (rows.goToNextRow()) values.push(JSON.parse(rows.getString(0)) as T)
  } finally {
    rows.close()
  }
  return values
}

export class ReaderRdbStorage {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async migrated(): Promise<boolean> {
    const result = await this.store.querySql('SELECT name FROM local_data_migrations WHERE name = ?', [READER_MIGRATION])
    try {
      return result.goToNextRow()
    } finally {
      result.close()
    }
  }

  async migrate(snapshot: ReaderSessionDocumentSnapshot): Promise<void> {
    const transaction = await this.store.createTransaction()
    try {
      await this.importWorkRows(transaction, 'progress', snapshot.progress)
      await this.importWorkRows(transaction, 'source', snapshot.sourceHistory)
      await this.importWorkRows(transaction, 'remote', snapshot.remoteHistory ?? [])
      for (let start = 0; start < snapshot.chapters.length; start += 128) {
        const part = snapshot.chapters.slice(start, start + 128)
        const args: relationalStore.ValueType[] = []
        part.forEach((chapter: ChapterReadingState): void => {
          args.push(chapter.comicId, chapter.chapterId, JSON.stringify(chapter))
        })
        await transaction.execute('INSERT OR REPLACE INTO reading_chapter_states (comic_id, chapter_id, payload) VALUES ' +
          part.map((): string => '(?, ?, ?)').join(', '), args)
      }
      await this.importLocalRecords(transaction, 'session', snapshot.readingSessions ?? [])
      await this.importLocalRecords(transaction, 'position', snapshot.syncPositions ?? [])
      await this.importLocalRecords(transaction, 'action', snapshot.syncActions ?? [])
      await transaction.execute('INSERT INTO local_data_migrations (name) VALUES (?)', [READER_MIGRATION])
      await transaction.commit()
    } catch (error) {
      await transaction.rollback()
      throw error as Error
    }
  }

  private async importWorkRows<T extends WorkRecord>(transaction: relationalStore.Transaction, kind: string, rows: T[]): Promise<void> {
    for (let start = 0; start < rows.length; start += 128) {
      const part = rows.slice(start, start + 128)
      const args: relationalStore.ValueType[] = []
      part.forEach((row: T): void => { args.push(kind, row.comicId, JSON.stringify(row)) })
      await transaction.execute('INSERT OR REPLACE INTO reading_works (kind, comic_id, payload) VALUES ' +
        part.map((): string => '(?, ?, ?)').join(', '), args)
    }
  }

  private async importLocalRecords<T>(transaction: relationalStore.Transaction, kind: string, rows: T[]): Promise<void> {
    for (let start = 0; start < rows.length; start += 128) {
      const part = rows.slice(start, start + 128)
      const args: relationalStore.ValueType[] = []
      part.forEach((row: T, index: number): void => { args.push(kind, start + index, JSON.stringify(row)) })
      await transaction.execute('INSERT INTO reading_local_records (kind, list_order, payload) VALUES ' +
        part.map((): string => '(?, ?, ?)').join(', '), args)
    }
  }

  read(): ReaderSessionDocumentSnapshot {
    const syncPositions = this.localRecords<SyncReadingCapture>('position')
    const syncActions = this.localRecords<SyncReadingActionCapture>('action')
    return {
      progress: this.workRows<ReadingProgress>('progress'),
      sourceHistory: this.workRows<SourceReadHistoryEntry>('source'),
      remoteHistory: this.workRows<RemoteReadHistoryEntry>('remote'),
      chapters: payloadList<ChapterReadingState>(
        this.store.querySqlSync('SELECT payload FROM reading_chapter_states ORDER BY rowid')),
      readingSessions: this.localRecords<ReadingSessionRecord>('session'),
      syncPositions: syncPositions.length > 0 ? syncPositions : undefined,
      syncActions: syncActions.length > 0 ? syncActions : undefined,
    }
  }

  private workRows<T>(kind: string): T[] {
    return payloadList<T>(this.store.querySqlSync('SELECT payload FROM reading_works WHERE kind = ? ORDER BY rowid', [kind]))
  }

  private localRecords<T>(kind: string): T[] {
    return payloadList<T>(this.store.querySqlSync('SELECT payload FROM reading_local_records WHERE kind = ? ORDER BY list_order', [kind]))
  }

  save(snapshot: ReaderSessionDocumentSnapshot, pageTurns?: ChapterReadingState[]): void {
    this.store.beginTransaction()
    try {
      if (pageTurns === undefined) {
        this.saveWorks('progress', snapshot.progress)
        this.saveWorks('source', snapshot.sourceHistory)
        this.saveWorks('remote', snapshot.remoteHistory ?? [])
        this.replaceChapters(snapshot.chapters)
        this.saveLocalRecords('session', snapshot.readingSessions ?? [])
      } else {
        // A page-only batch may touch multiple chapters of one work.
        // The same transaction advances the per-chapter and latest positions.
        for (const chapter of pageTurns) {
          if (chapter.position === undefined) continue
          this.store.executeSync(CHAPTER_UPSERT, [chapter.comicId, chapter.chapterId, JSON.stringify(chapter)])
          this.store.executeSync(WORK_UPSERT, ['progress', chapter.comicId, JSON.stringify(chapter.position)])
        }
      }
      this.saveLocalRecords('position', snapshot.syncPositions ?? [])
      this.saveLocalRecords('action', snapshot.syncActions ?? [])
      this.store.commit()
    } catch (error) {
      this.store.rollBack()
      throw error as Error
    }
  }

  private saveWorks<T extends WorkRecord>(kind: string, next: T[]): void {
    const previous = new Map<string, string>()
    const rows = this.store.querySqlSync('SELECT comic_id, payload FROM reading_works WHERE kind = ?', [kind])
    try {
      while (rows.goToNextRow()) previous.set(rows.getString(0), rows.getString(1))
    } finally {
      rows.close()
    }
    for (const row of next) {
      const payload = JSON.stringify(row)
      const current = previous.get(row.comicId)
      previous.delete(row.comicId)
      if (current !== payload) this.store.executeSync(WORK_UPSERT, [kind, row.comicId, payload])
    }
    for (const comicId of previous.keys()) {
      this.store.executeSync('DELETE FROM reading_works WHERE kind = ? AND comic_id = ?', [kind, comicId])
    }
  }

  private replaceChapters(next: ChapterReadingState[]): void {
    const previous = new Map<string, Map<string, string>>()
    const rows = this.store.querySqlSync('SELECT comic_id, chapter_id, payload FROM reading_chapter_states')
    try {
      while (rows.goToNextRow()) {
        const comicId = rows.getString(0)
        let chapters = previous.get(comicId)
        if (chapters === undefined) {
          chapters = new Map<string, string>()
          previous.set(comicId, chapters)
        }
        chapters.set(rows.getString(1), rows.getString(2))
      }
    } finally {
      rows.close()
    }
    for (const row of next) {
      const known = previous.get(row.comicId)
      const current = known?.get(row.chapterId)
      const payload = JSON.stringify(row)
      known?.delete(row.chapterId)
      if (current !== payload) this.store.executeSync(CHAPTER_UPSERT, [row.comicId, row.chapterId, payload])
    }
    previous.forEach((chapters: Map<string, string>, comicId: string): void => {
      for (const chapter of chapters.keys()) {
        this.store.executeSync('DELETE FROM reading_chapter_states WHERE comic_id = ? AND chapter_id = ?', [comicId, chapter])
      }
    })
  }

  private saveLocalRecords<T>(kind: string, rows: T[]): void {
    const previous = new Map<number, string>()
    const result = this.store.querySqlSync('SELECT list_order, payload FROM reading_local_records WHERE kind = ?', [kind])
    try {
      while (result.goToNextRow()) previous.set(result.getLong(0), result.getString(1))
    } finally {
      result.close()
    }
    for (let index = 0; index < rows.length; index += 1) {
      const payload = JSON.stringify(rows[index])
      if (previous.get(index) !== payload) this.store.executeSync(LOCAL_UPSERT, [kind, index, payload])
    }
    this.store.executeSync('DELETE FROM reading_local_records WHERE kind = ? AND list_order >= ?', [kind, rows.length])
  }
}
