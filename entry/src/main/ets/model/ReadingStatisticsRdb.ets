import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { hasUserDataMigration, openUserDataSnapshotDatabase } from './UserDataDatabase'
import type { ReadingLibraryStatistics, ReadingSessionRecord } from './ReadingStatistics'

export interface ReadingStatisticsSnapshot {
  records: ReadingSessionRecord[]
  libraryStatistics: ReadingLibraryStatistics
}

@Concurrent
async function queryReadingStatisticsSnapshot(
  context: common.UIAbilityContext,
  queueId?: string
): Promise<ReadingStatisticsSnapshot | undefined> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    if (!hasUserDataMigration(store, 'library-relational-v1') ||
      !hasUserDataMigration(store, 'reader-relational-v1') ||
      (queueId !== undefined && !hasUserDataMigration(store, 'offline-download-relational/' + queueId))) {
      return undefined
    }

    const records: ReadingSessionRecord[] = []
    const sessionRows = store.querySqlSync(
      'SELECT comic_id, chapter_id, started_at, ended_at, pages_read FROM reader_sessions ORDER BY session_order')
    try {
      while (sessionRows.goToNextRow()) {
        records.push({
          comicId: sessionRows.getString(0),
          chapterId: sessionRows.getString(1),
          startedAt: sessionRows.getLong(2),
          endedAt: sessionRows.getLong(3),
          pagesRead: sessionRows.getLong(4),
        })
      }
    } finally {
      sessionRows.close()
    }

    let books = 0
    const booksResult = store.querySqlSync('SELECT COUNT(*) FROM shelf_works_all')
    try {
      if (booksResult.goToNextRow()) books = booksResult.getLong(0)
    } finally {
      booksResult.close()
    }

    let startedBooks = 0
    const startedResult = store.querySqlSync(
      'SELECT COUNT(*) FROM shelf_works_all w WHERE EXISTS (' +
      'SELECT 1 FROM reader_current_positions_all p WHERE p.comic_id = w.comic_id) OR EXISTS (' +
      'SELECT 1 FROM shelf_chapters c JOIN reader_chapter_states_all s ' +
      'ON s.comic_id = c.comic_id AND s.chapter_id = c.chapter_id AND s.is_read = 1 ' +
      'WHERE c.comic_id = w.comic_id)')
    try {
      if (startedResult.goToNextRow()) startedBooks = startedResult.getLong(0)
    } finally {
      startedResult.close()
    }

    let chapters = 0
    let readChapters = 0
    let completedBooks = 0
    const chapterAggResult = store.querySqlSync(
      'SELECT COALESCE(SUM(total_count), 0), COALESCE(SUM(read_count), 0), ' +
      'COALESCE(SUM(CASE WHEN total_count > 0 AND total_count = read_count THEN 1 ELSE 0 END), 0) ' +
      'FROM (' +
      'SELECT c.comic_id, COUNT(*) AS total_count, ' +
      'SUM(CASE WHEN s.is_read = 1 THEN 1 ELSE 0 END) AS read_count ' +
      'FROM (SELECT DISTINCT comic_id, chapter_id FROM shelf_chapters) c ' +
      'LEFT JOIN reader_chapter_states_all s ' +
      'ON s.comic_id = c.comic_id AND s.chapter_id = c.chapter_id ' +
      'GROUP BY c.comic_id) per_comic')
    try {
      if (chapterAggResult.goToNextRow()) {
        chapters = chapterAggResult.getLong(0)
        readChapters = chapterAggResult.getLong(1)
        completedBooks = chapterAggResult.getLong(2)
      }
    } finally {
      chapterAggResult.close()
    }

    let downloadedChapters = 0
    if (queueId !== undefined && queueId.length > 0) {
      const downloadedResult = store.querySqlSync(
        'SELECT COUNT(*) FROM (SELECT DISTINCT comic_id, chapter_id FROM shelf_chapters) c WHERE EXISTS (' +
        'SELECT 1 FROM offline_download_tasks t ' +
        'WHERE t.queue_id = ? AND t.comic_id = c.comic_id AND t.chapter_id = c.chapter_id AND t.status = ?)',
        [queueId, 'downloaded'])
      try {
        if (downloadedResult.goToNextRow()) downloadedChapters = downloadedResult.getLong(0)
      } finally {
        downloadedResult.close()
      }
    }

    return {
      records,
      libraryStatistics: {
        books,
        startedBooks,
        completedBooks,
        chapters,
        readChapters,
        downloadedChapters,
      },
    }
  } finally {
    await store.close()
  }
}

export async function loadReadingStatisticsFromRdb(
  context: common.UIAbilityContext,
  queueId?: string
): Promise<ReadingStatisticsSnapshot | undefined> {
  try {
    const snapshot = await taskpool.execute(queryReadingStatisticsSnapshot, context, queueId) as
      ReadingStatisticsSnapshot | undefined
    DiagnosticLogger.info('reading_statistics', 'rdb_snapshot_loaded',
      `hasSnapshot=${snapshot !== undefined} books=${snapshot?.libraryStatistics.books ?? -1}` +
      ` started=${snapshot?.libraryStatistics.startedBooks ?? -1}` +
      ` chapters=${snapshot?.libraryStatistics.chapters ?? -1}` +
      ` readChapters=${snapshot?.libraryStatistics.readChapters ?? -1}` +
      ` downloaded=${snapshot?.libraryStatistics.downloadedChapters ?? -1}` +
      ` sessions=${snapshot?.records.length ?? -1}`)
    return snapshot
  } catch (error) {
    DiagnosticLogger.exception('reading_statistics', 'rdb_snapshot_failed', error as Error)
    return undefined
  }
}
