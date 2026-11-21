import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, UserRecordValues } from '../model/UserKeyedRecords'
import type { SourceRuntimeRegistryPersistedEntry, SourceRuntimeRegistryPersistedMetadata } from './SourceRuntimeRegistry'

export const SOURCE_REGISTRY_PATH = 'source-runtime/source-runtime-registry.json'
const opened = new Map<string, UserKeyedRecords>()

interface SourceRegistryRow {
  order: number
  entry: SourceRuntimeRegistryPersistedEntry
}

function entriesFor(metadata: SourceRuntimeRegistryPersistedMetadata | undefined): UserRecordValues | undefined {
  if (metadata === undefined) return undefined
  if (metadata === null || metadata.schemaVersion !== 1 || !Array.isArray(metadata.entries)) throw new Error('metadata_invalid')
  const rows: UserRecordValues = new Map()
  metadata.entries.forEach((entry: SourceRuntimeRegistryPersistedEntry, order: number): void => {
    if (entry === null || typeof entry.sourceId !== 'string' || entry.sourceId.length === 0) throw new Error('metadata_invalid')
    const row: SourceRegistryRow = { order, entry }
    const key = rows.has(entry.sourceId) ? JSON.stringify([entry.sourceId, order]) : entry.sourceId
    rows.set(key, JSON.stringify(row))
  })
  return rows
}

export async function prepareSourceRegistryDatabase(context: common.Context, migrate: boolean): Promise<void> {
  const path = context.filesDir + '/' + SOURCE_REGISTRY_PATH
  let records = opened.get(path)
  if (records === undefined) {
    records = new UserKeyedRecords(await openUserDataDatabase(context), SOURCE_REGISTRY_PATH)
    opened.set(path, records)
  }
  if (migrate && !records.isMigrated()) {
    const document = fs.accessSync(path) ? JSON.parse(await fs.readText(path)) as SourceRuntimeRegistryPersistedMetadata : undefined
    records.migrate(entriesFor(document))
  }
}

export function usesSourceRegistryDatabase(path: string): boolean { return opened.get(path)?.isMigrated() === true }

export function readSourceRegistryMetadata(path: string): SourceRuntimeRegistryPersistedMetadata | undefined {
  const rows = opened.get(path)?.entries()
  if (rows === undefined) return undefined
  const entries = Array.from(rows.values()).map((value: string): SourceRegistryRow => JSON.parse(value) as SourceRegistryRow)
    .sort((left: SourceRegistryRow, right: SourceRegistryRow): number => left.order - right.order)
    .map((row: SourceRegistryRow): SourceRuntimeRegistryPersistedEntry => row.entry)
  return { schemaVersion: 1, entries }
}

export function writeSourceRegistryMetadata(path: string, metadata: SourceRuntimeRegistryPersistedMetadata | undefined): void {
  const records = opened.get(path)
  if (records === undefined || !records.isMigrated()) throw new Error('source_registry_database_not_migrated')
  records.replace(entriesFor(metadata))
}
