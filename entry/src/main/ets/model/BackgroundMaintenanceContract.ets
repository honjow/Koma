import type { Comic } from './ComicModels'
import type { LibraryUpdatePreferences } from './LibraryUpdatePreferencesStore'
import type { LibraryAutomationPreferences } from './LibraryAutomationPolicy'
import type { LibraryUpdateComicResult, LibraryUpdateSummary } from './LibraryUpdateService'
import type { BackupAutomaticPreferences } from './BackupService'
import type { KomgaServerRecord, KavitaServerRecord, WebDavServerRecord, OpdsServerRecord } from './RemoteServerStore'

export const LIBRARY_BACKGROUND_WORK_ID: number = 7101
export const BACKUP_BACKGROUND_WORK_ID: number = 7102
export const MAINTENANCE_ABILITY: string = 'KomaMaintenanceAbility'
export const MAINTENANCE_CONFIG_FILE: string = 'background-maintenance.v1.json'
export const BACKUP_SNAPSHOT: string = 'background-backup-snapshot.v1.json'
export const JOURNAL_DIR: string = 'background-library-results'
export const BACKUP_BACKGROUND_RESULT: string = 'background-backup-result.v1.json'
export const UPDATE_CURSOR: string = 'background-update-cursor.v1.json'

export interface BackgroundBackupResult { at: number; lastRunAt: number; failureCode: string }

export interface BackgroundServerSnapshot {
  komga?: KomgaServerRecord
  kavita?: KavitaServerRecord
  webdav?: WebDavServerRecord
  opds?: OpdsServerRecord
}

export interface BackgroundMaintenanceConfiguration {
  updates: LibraryUpdatePreferences
  policy: LibraryAutomationPreferences
  backup: BackupAutomaticPreferences
  servers: BackgroundServerSnapshot
}

export interface BackgroundLibraryChange { before: Comic; after: Comic }
export interface BackgroundLibraryJournal { generation: number; summary: LibraryUpdateSummary; changes: BackgroundLibraryChange[] }
export interface BackgroundUpdateCursor { generation: number; remaining: string[]; results: LibraryUpdateComicResult[]; startedAt: number }

export interface BackgroundComicObservation {
  checkedAt: number
  result: LibraryUpdateComicResult
  change?: BackgroundLibraryChange
}

// Several scheduled runs can finish before the UI opens. Select once per book before
// applying changes, so an older result cannot make a newer result appear stale.
export function latestBackgroundObservations(journals: BackgroundLibraryJournal[]): BackgroundComicObservation[] {
  const latest: Map<string, BackgroundComicObservation> = new Map()
  for (const journal of journals) {
    for (const result of journal.summary.results) {
      const previous = latest.get(result.comicId)
      if (previous !== undefined && previous.checkedAt > journal.summary.checkedAt) continue
      latest.set(result.comicId, { checkedAt: journal.summary.checkedAt, result,
        change: journal.changes.find((change: BackgroundLibraryChange): boolean => change.before.id === result.comicId) })
    }
  }
  return Array.from(latest.values())
}
