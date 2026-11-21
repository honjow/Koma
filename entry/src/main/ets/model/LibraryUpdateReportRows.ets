import type { relationalStore } from '@kit.ArkData'
import type { LibraryUpdateJobState, PersistedLibraryUpdateJobSnapshot, PersistedLibraryUpdateProviderSummary,
  PersistedLibraryUpdateResult, PersistedLibraryUpdateSummary } from './LibraryUpdateResultStore'
import type { LibraryUpdateProviderKind, LibraryUpdateResultStatus } from './LibraryUpdateService'
import { collectLocalRows, integerColumn, textColumn } from './LocalDataRows'

export const REPORT_RESULT_KEY = 'libraryUpdate.latestResultJson'
export const REPORT_JOB_KEY = 'libraryUpdate.latestJobJson'

function readProviders(store: relationalStore.RdbStore, kind: string): PersistedLibraryUpdateProviderSummary[] {
  const codes = new Map<number, string[]>()
  const rows = store.querySqlSync('SELECT provider_order, failure_code FROM library_update_provider_failures ' +
    'WHERE report_kind = ? ORDER BY provider_order, code_order', [kind])
  try {
    while (rows.goToNextRow()) {
      const index = rows.getLong(0)
      const list = codes.get(index)
      if (list === undefined) codes.set(index, [rows.getString(1)])
      else list.push(rows.getString(1))
    }
  } finally {
    rows.close()
  }
  return collectLocalRows(store.querySqlSync('SELECT provider_order, provider_kind, source_key, total_count, ' +
    'updated_count, unchanged_count, skipped_count, failed_count, new_chapter_count FROM library_update_provider_results ' +
    'WHERE report_kind = ? ORDER BY provider_order', [kind]),
    (row: relationalStore.ResultSet): PersistedLibraryUpdateProviderSummary => ({
      providerKind: row.getString(1) as LibraryUpdateProviderKind, sourceKey: row.getString(2), totalCount: row.getLong(3),
      updatedCount: row.getLong(4), unchangedCount: row.getLong(5), skippedCount: row.getLong(6), failedCount: row.getLong(7),
      newChapterCount: row.getLong(8), failureCodes: codes.get(row.getLong(0)) ?? [],
    }))
}

function readSummary(store: relationalStore.RdbStore, kind: string): PersistedLibraryUpdateSummary | undefined {
  const row = store.querySqlSync('SELECT checked_at, total_count, updated_count, unchanged_count, skipped_count, failed_count ' +
    'FROM library_update_summaries WHERE report_kind = ?', [kind])
  let summary: PersistedLibraryUpdateSummary
  try {
    if (!row.goToNextRow()) return undefined
    summary = { checkedAt: row.getLong(0), totalCount: row.getLong(1), updatedCount: row.getLong(2), unchangedCount: row.getLong(3),
      skippedCount: row.getLong(4), failedCount: row.getLong(5), providerSummaries: [], results: [] }
  } finally {
    row.close()
  }
  summary.providerSummaries = readProviders(store, kind)
  summary.results = collectLocalRows(store.querySqlSync('SELECT comic_id, provider_kind, source_key, status, previous_chapter_count, ' +
    'new_chapter_count, added_chapter_count, message FROM library_update_results WHERE report_kind = ? ORDER BY result_order', [kind]),
    (row: relationalStore.ResultSet): PersistedLibraryUpdateResult => ({
      comicId: row.getString(0), providerKind: row.getString(1) as LibraryUpdateProviderKind, sourceKey: row.getString(2),
      status: row.getString(3) as LibraryUpdateResultStatus, previousChapterCount: row.getLong(4), newChapterCount: row.getLong(5),
      addedChapterCount: integerColumn(row, 6), message: row.getString(7),
    }))
  return summary
}

function readJob(store: relationalStore.RdbStore): PersistedLibraryUpdateJobSnapshot | undefined {
  const rows = store.querySqlSync('SELECT state, updated_at, started_at, finished_at, next_due_at, failure_code ' +
    'FROM library_update_job WHERE id = 1')
  let job: PersistedLibraryUpdateJobSnapshot
  try {
    if (!rows.goToNextRow()) return undefined
    job = { state: rows.getString(0) as LibraryUpdateJobState, updatedAt: rows.getLong(1),
      startedAt: integerColumn(rows, 2), finishedAt: integerColumn(rows, 3), nextDueAt: integerColumn(rows, 4),
      failureCode: textColumn(rows, 5), providerSummaries: [] }
  } finally {
    rows.close()
  }
  job.providerSummaries = readProviders(store, 'job')
  job.summary = readSummary(store, 'job_summary')
  return job
}

export function readLibraryUpdateReport(store: relationalStore.RdbStore, key: string): string | undefined {
  const value = key === REPORT_JOB_KEY ? readJob(store) : readSummary(store, 'latest')
  return value === undefined ? undefined : JSON.stringify(JSON.stringify(value))
}

function clearReport(store: relationalStore.RdbStore, kind: string): void {
  for (const table of ['library_update_provider_failures', 'library_update_provider_results',
    'library_update_results', 'library_update_summaries']) {
    store.executeSync('DELETE FROM ' + table + ' WHERE report_kind = ?', [kind])
  }
}

function insertProviders(store: relationalStore.RdbStore, kind: string, providers: PersistedLibraryUpdateProviderSummary[]): void {
  providers.forEach((provider: PersistedLibraryUpdateProviderSummary, index: number): void => {
    store.executeSync('INSERT INTO library_update_provider_results (report_kind, provider_order, provider_kind, source_key, ' +
      'total_count, updated_count, unchanged_count, skipped_count, failed_count, new_chapter_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [kind, index, provider.providerKind, provider.sourceKey, provider.totalCount, provider.updatedCount, provider.unchangedCount,
        provider.skippedCount, provider.failedCount, provider.newChapterCount])
    provider.failureCodes.forEach((code: string, order: number): void => {
      store.executeSync('INSERT INTO library_update_provider_failures ' +
        '(report_kind, provider_order, code_order, failure_code) VALUES (?, ?, ?, ?)', [kind, index, order, code])
    })
  })
}

function insertSummary(store: relationalStore.RdbStore, kind: string, summary: PersistedLibraryUpdateSummary): void {
  store.executeSync('INSERT INTO library_update_summaries (report_kind, checked_at, total_count, updated_count, unchanged_count, ' +
    'skipped_count, failed_count) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [kind, summary.checkedAt, summary.totalCount, summary.updatedCount, summary.unchangedCount, summary.skippedCount, summary.failedCount])
  insertProviders(store, kind, summary.providerSummaries ?? [])
  summary.results.forEach((result: PersistedLibraryUpdateResult, order: number): void => {
    store.executeSync('INSERT INTO library_update_results (report_kind, result_order, comic_id, provider_kind, source_key, status, ' +
      'previous_chapter_count, new_chapter_count, added_chapter_count, message) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [kind, order, result.comicId, result.providerKind, result.sourceKey, result.status, result.previousChapterCount,
        result.newChapterCount, result.addedChapterCount ?? null, result.message])
  })
}

export function writeLibraryUpdateReport(store: relationalStore.RdbStore, key: string, value: string | undefined): void {
  const raw = value === undefined ? undefined : JSON.parse(value) as string
  if (key === REPORT_RESULT_KEY) {
    clearReport(store, 'latest')
    if (raw !== undefined && raw !== '') insertSummary(store, 'latest', JSON.parse(raw) as PersistedLibraryUpdateSummary)
    return
  }
  clearReport(store, 'job')
  clearReport(store, 'job_summary')
  store.executeSync('DELETE FROM library_update_job')
  if (raw === undefined || raw === '') return
  const job = JSON.parse(raw) as PersistedLibraryUpdateJobSnapshot
  store.executeSync('INSERT INTO library_update_job (id, state, updated_at, started_at, finished_at, next_due_at, failure_code) ' +
    'VALUES (1, ?, ?, ?, ?, ?, ?)',
    [job.state, job.updatedAt, job.startedAt ?? null, job.finishedAt ?? null, job.nextDueAt ?? null, job.failureCode ?? null])
  insertProviders(store, 'job', job.providerSummaries ?? [])
  if (job.summary !== undefined) insertSummary(store, 'job_summary', job.summary)
}
