import { relationalStore } from '@kit.ArkData'

export type UserRecordValues = Map<string, string>

export function writeUserRecords(store: relationalStore.RdbStore, write: () => void): void {
  store.beginTransaction()
  try {
    write()
    store.commit()
  } catch (error) {
    store.rollBack()
    throw error as Error
  }
}

/** Read the prior database format only while upgrading an already migrated domain. */
export class UserKeyedRecords {
  private readonly store: relationalStore.RdbStore
  private readonly domain: string
  private migrationCommitted: boolean = false

  constructor(store: relationalStore.RdbStore, domain: string) {
    this.store = store
    this.domain = domain
  }

  isMigrated(): boolean {
    if (this.migrationCommitted) return true
    const rows = this.store.querySqlSync('SELECT name FROM local_data_migrations WHERE name = ?', [this.domain])
    try {
      this.migrationCommitted = rows.goToNextRow()
      return this.migrationCommitted
    } finally { rows.close() }
  }

  entries(): UserRecordValues | undefined {
    // Use one read snapshot. The collection row distinguishes a saved empty map from an absent legacy field.
    const rows = this.store.querySqlSync('SELECT r.record_key, r.value FROM user_record_collections c ' +
      'LEFT JOIN user_keyed_records r ON r.domain = c.domain WHERE c.domain = ? ORDER BY r.rowid', [this.domain])
    try {
      if (!rows.goToNextRow()) return undefined
      const result: UserRecordValues = new Map()
      do {
        if (!rows.isColumnNull(0)) result.set(rows.getString(0), rows.getString(1))
      } while (rows.goToNextRow())
      return result
    } finally { rows.close() }
  }

}
