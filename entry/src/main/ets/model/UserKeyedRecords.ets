import { relationalStore } from '@kit.ArkData'

const SAVE_RECORD = 'INSERT INTO user_keyed_records (domain, record_key, value) VALUES (?, ?, ?) ' +
  'ON CONFLICT (domain, record_key) DO UPDATE SET value=excluded.value WHERE value<>excluded.value'

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

/** A local domain owns its keys and payloads. No callers can enumerate another domain through this instance. */
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

  migrate(values: UserRecordValues | undefined): void {
    writeUserRecords(this.store, (): void => {
      // Recheck while holding the writer so two processes cannot reapply the legacy snapshot.
      if (!this.isMigrated()) {
        this.replaceInTransaction(values)
        this.store.executeSync('INSERT INTO local_data_migrations (name) VALUES (?)', [this.domain])
      }
    })
    this.migrationCommitted = true
  }

  get(key: string): string | undefined {
    const rows = this.store.querySqlSync('SELECT value FROM user_keyed_records WHERE domain = ? AND record_key = ?',
      [this.domain, key])
    try { return rows.goToNextRow() ? rows.getString(0) : undefined } finally { rows.close() }
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

  put(key: string, value: string | undefined): void {
    writeUserRecords(this.store, (): void => this.putInTransaction(key, value))
  }

  putInTransaction(key: string, value: string | undefined): void {
    if (value === undefined) {
      this.store.executeSync('DELETE FROM user_keyed_records WHERE domain = ? AND record_key = ?', [this.domain, key])
    } else {
      this.store.executeSync('INSERT OR IGNORE INTO user_record_collections (domain) VALUES (?)', [this.domain])
      this.store.executeSync(SAVE_RECORD, [this.domain, key, value])
    }
  }

  replace(values: UserRecordValues | undefined): void {
    writeUserRecords(this.store, (): void => this.replaceInTransaction(values))
  }

  replaceInTransaction(values: UserRecordValues | undefined): void {
    if (values === undefined) {
      this.store.executeSync('DELETE FROM user_keyed_records WHERE domain = ?', [this.domain])
      this.store.executeSync('DELETE FROM user_record_collections WHERE domain = ?', [this.domain])
      return
    }
    const previous = this.entries()
    previous?.forEach((_value: string, key: string): void => {
      if (!values.has(key)) this.putInTransaction(key, undefined)
    })
    this.mergeInTransaction(values, previous)
  }

  mergeInTransaction(values: UserRecordValues, previous: UserRecordValues | undefined = this.entries()): void {
    this.store.executeSync('INSERT OR IGNORE INTO user_record_collections (domain) VALUES (?)', [this.domain])
    const keys = Array.from(values.keys()).filter((key: string): boolean => values.get(key) !== previous?.get(key))
    for (let start = 0; start < keys.length; start += 128) {
      const batch = keys.slice(start, start + 128)
      const args: relationalStore.ValueType[] = []
      batch.forEach((key: string): void => { args.push(this.domain, key, values.get(key)!) })
      this.store.executeSync('INSERT INTO user_keyed_records (domain, record_key, value) VALUES ' +
        batch.map((): string => '(?, ?, ?)').join(', ') +
        ' ON CONFLICT(domain, record_key) DO UPDATE SET value=excluded.value', args)
    }
  }
}
