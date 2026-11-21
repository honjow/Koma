import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo as fs } from '@kit.CoreFileKit'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, writeUserRecords } from '../model/UserKeyedRecords'
import type { SourceRuntimeRegistryPersistedEntry, SourceRuntimeRegistryPersistedMetadata } from './SourceRuntimeRegistry'
import { readSourceRegistryRows, replaceSourceRegistryRows } from './SourceRegistryRows'

export const SOURCE_REGISTRY_PATH = 'source-runtime/source-runtime-registry.json'
const MIGRATION = 'source-registry-columns-v1'
const opened = new Map<string, relationalStore.RdbStore>()

interface LegacyRegistryRow {
  order: number
  entry: SourceRuntimeRegistryPersistedEntry
}

function oldRegistry(previous: UserKeyedRecords): SourceRuntimeRegistryPersistedMetadata | undefined {
  const values = previous.entries()
  if (values === undefined) return undefined
  const rows = Array.from(values.values()).map((value: string): LegacyRegistryRow => JSON.parse(value) as LegacyRegistryRow)
  rows.sort((left: LegacyRegistryRow, right: LegacyRegistryRow): number => left.order - right.order)
  return { schemaVersion: 1, entries: rows.map((row: LegacyRegistryRow): SourceRuntimeRegistryPersistedEntry => row.entry) }
}

function replaceRegistry(store: relationalStore.RdbStore, metadata: SourceRuntimeRegistryPersistedMetadata | undefined): void {
  if (metadata === undefined) {
    replaceSourceRegistryRows(store, [])
    store.executeSync('DELETE FROM source_registry_state')
    return
  }
  if (metadata === null || metadata.schemaVersion !== 1 || !Array.isArray(metadata.entries)) throw new Error('metadata_invalid')
  replaceSourceRegistryRows(store, metadata.entries)
  store.executeSync('INSERT OR IGNORE INTO source_registry_state (id) VALUES (1)')
}

export async function prepareSourceRegistryDatabase(context: common.Context, migrate: boolean): Promise<void> {
  const path = context.filesDir + '/' + SOURCE_REGISTRY_PATH
  const store = opened.get(path) ?? await openUserDataDatabase(context)
  if (!hasUserDataMigration(store, MIGRATION)) {
    const previous = new UserKeyedRecords(store, SOURCE_REGISTRY_PATH)
    if (migrate || previous.isMigrated()) {
      const legacy = !previous.isMigrated() && fs.accessSync(path) ?
        JSON.parse(await fs.readText(path)) as SourceRuntimeRegistryPersistedMetadata : undefined
      writeUserRecords(store, (): void => {
        if (hasUserDataMigration(store, MIGRATION)) return
        replaceRegistry(store, previous.isMigrated() ? oldRegistry(previous) : legacy)
        markUserDataMigration(store, MIGRATION)
      })
    }
  }
  opened.set(path, store)
}

export function usesSourceRegistryDatabase(path: string): boolean {
  const store = opened.get(path)
  return store !== undefined && hasUserDataMigration(store, MIGRATION)
}

export function readSourceRegistryMetadata(path: string): SourceRuntimeRegistryPersistedMetadata | undefined {
  const store = opened.get(path)
  if (store === undefined) return undefined
  const state = store.querySqlSync('SELECT id FROM source_registry_state WHERE id = 1')
  try {
    if (!state.goToNextRow()) return undefined
  } finally {
    state.close()
  }
  return { schemaVersion: 1, entries: readSourceRegistryRows(store) }
}

export function writeSourceRegistryMetadata(path: string, metadata: SourceRuntimeRegistryPersistedMetadata | undefined): void {
  const store = opened.get(path)
  if (store === undefined || !hasUserDataMigration(store, MIGRATION)) throw new Error('source_registry_database_not_migrated')
  writeUserRecords(store, (): void => replaceRegistry(store, metadata))
}
