import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'

const STORE: string = 'koma_manga_migration_v1'
const KEY: string = 'migration.selectedSources'
const OPTIONS_KEY: string = 'migration.matchOptions'
let writes: Promise<void> = Promise.resolve()

export interface MigrationMatchOptions {
  deepSearch: boolean
  prioritizeChapters: boolean
}

export function normalizedMigrationSourceIds(value: string[]): string[] {
  return value.filter((id: string, index: number): boolean =>
    typeof id === 'string' && id.trim().length > 0 && value.indexOf(id) === index)
}

/** Remember source IDs and their chosen order, independently of any migration transaction. */
export class MangaMigrationPreferencesStore {
  private context: common.Context
  constructor(context: common.Context) { this.context = context }

  async load(): Promise<string[]> {
    await writes
    const store = await preferences.getPreferences(this.context, STORE)
    const value = JSON.parse(await store.get(KEY, '[]') as string) as string[]
    return Array.isArray(value) ? normalizedMigrationSourceIds(value) : []
  }

  save(sourceIds: string[]): Promise<void> {
    return this.write(KEY, JSON.stringify(normalizedMigrationSourceIds(sourceIds)))
  }

  async loadOptions(): Promise<MigrationMatchOptions> {
    await writes
    const store = await preferences.getPreferences(this.context, STORE)
    const value = JSON.parse(await store.get(OPTIONS_KEY, '{}') as string) as MigrationMatchOptions
    return { deepSearch: value?.deepSearch === true, prioritizeChapters: value?.prioritizeChapters === true }
  }

  saveOptions(options: MigrationMatchOptions): Promise<void> {
    return this.write(OPTIONS_KEY, JSON.stringify(options))
  }

  private write(key: string, value: string): Promise<void> {
    const run = writes.then(() => BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const store = await preferences.getPreferences(this.context, STORE)
      const previous = await store.get(key, key === KEY ? '[]' : '{}') as string
      try { await store.put(key, value); await store.flush() }
      catch (error) { await store.put(key, previous); await store.flush(); throw error as Error }
    }))
    writes = run.catch(() => {})
    return run
  }
}
