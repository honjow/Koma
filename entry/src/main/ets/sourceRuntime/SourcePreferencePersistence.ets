import { common } from '@kit.AbilityKit'
import { openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, UserRecordValues } from '../model/UserKeyedRecords'

export const SOURCE_SETTINGS_PATH = 'source-runtime/source-settings.json'
export const SOURCE_FILTERS_PATH = 'source-runtime/source-filter-preferences.json'

interface SourcePreferenceDocument<T> {
  schemaVersion: number
  sources: Record<string, T>
}

export class SourcePreferencePersistence<T> {
  private readonly opened = new Map<string, UserKeyedRecords>()
  private readonly relativePath: string

  constructor(relativePath: string) { this.relativePath = relativePath }

  async open(context: common.Context): Promise<void> {
    const absolute = context.filesDir + '/' + this.relativePath
    if (!this.opened.has(absolute)) {
      this.opened.set(absolute, new UserKeyedRecords(await openUserDataDatabase(context), this.relativePath))
    }
  }

  database(absolute: string): UserKeyedRecords | undefined {
    const records = this.opened.get(absolute)
    return records?.isMigrated() === true ? records : undefined
  }

  migrate(absolute: string, legacy: Record<string, T> | undefined): void {
    const records = this.opened.get(absolute)
    if (records === undefined) throw new Error('source_preferences_database_not_open')
    records.migrate(legacy === undefined ? undefined : this.rows(legacy))
  }

  readSource(records: UserKeyedRecords, id: string): T | undefined {
    const raw = records.get(id)
    return raw === undefined ? undefined : JSON.parse(raw) as T
  }

  readAll(records: UserKeyedRecords): Record<string, T> | undefined {
    const values = records.entries()
    if (values === undefined) return undefined
    const result: Record<string, T> = {}
    values.forEach((value: string, id: string): void => { result[id] = JSON.parse(value) as T })
    return result
  }

  replace(records: UserKeyedRecords, sources: Record<string, T>): void {
    records.replace(this.rows(sources))
  }

  readSnapshot(absolute: string): string | undefined {
    const database = this.database(absolute)
    const sources = database === undefined ? undefined : this.readAll(database)
    if (sources === undefined) return undefined
    const document: SourcePreferenceDocument<T> = { schemaVersion: 1, sources }
    return JSON.stringify(document)
  }

  restoreSnapshot(absolute: string, raw: string | undefined): void {
    const database = this.database(absolute)
    if (database === undefined) throw new Error('source_preferences_database_not_migrated')
    if (raw === undefined) {
      database.replace(undefined)
      return
    }
    const document = JSON.parse(raw) as SourcePreferenceDocument<T>
    if (document === null || document.schemaVersion !== 1 || document.sources === null ||
      typeof document.sources !== 'object' || Array.isArray(document.sources)) throw new Error('source_preferences_invalid')
    this.replace(database, document.sources)
  }

  private rows(values: Record<string, T>): UserRecordValues {
    const rows: UserRecordValues = new Map()
    Object.keys(values).forEach((id: string): void => { rows.set(id, JSON.stringify(values[id])) })
    return rows
  }
}
