import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { relationalStore } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from './UserDataDatabase'
import { UserKeyedRecords, writeUserRecords } from './UserKeyedRecords'
import { pruneImageRuleAssets, readImageRuleRows, stageImageRuleRows } from './ImageRuleAssetWorker'
import type { ImageRuleDatabaseRow } from './ImageRuleAssetFiles'
import { readImageRuleStoreRows, replaceImageRuleStoreRows } from './ImageRuleRows'

export const IMAGE_RULE_LEGACY_PATH = 'image-rules.v1.json'
const OLD_MIGRATION = 'image-rule-configuration'
const MIGRATION = 'image-rule-columns-v1'
const opened = new Map<string, relationalStore.RdbStore>()

function databaseFor(filesDir: string): relationalStore.RdbStore {
  const database = opened.get(filesDir)
  if (database === undefined) throw new Error('image_rule_database_not_open')
  return database
}

export async function prepareImageRuleDatabase(context: common.Context): Promise<void> {
  const directory = context.filesDir
  if (opened.has(directory)) return
  const store = await openUserDataDatabase(context)
  if (!hasUserDataMigration(store, MIGRATION) && hasUserDataMigration(store, OLD_MIGRATION)) {
    writeUserRecords(store, (): void => {
      if (hasUserDataMigration(store, MIGRATION)) return
      const old = new UserKeyedRecords(store, OLD_MIGRATION).entries()
      const rows = old === undefined ? undefined : Array.from(old.values())
        .map((value: string): ImageRuleDatabaseRow => JSON.parse(value) as ImageRuleDatabaseRow)
      replaceImageRuleStoreRows(store, rows)
      markUserDataMigration(store, MIGRATION)
    })
  }
  opened.set(directory, store)
}

export function usesImageRuleDatabase(filesDir: string): boolean {
  const store = opened.get(filesDir)
  return store !== undefined && hasUserDataMigration(store, MIGRATION)
}

export async function readImageRuleDatabaseSnapshot(filesDir: string): Promise<string | undefined> {
  const rows = readImageRuleStoreRows(databaseFor(filesDir))
  if (rows === undefined) return undefined
  return await taskpool.execute(readImageRuleRows, filesDir + '/image-rule-assets', JSON.stringify(rows)) as string
}

interface ImageRuleDatabaseCheckpoint {
  databaseRows: string[]
}

export function readImageRuleDatabaseCheckpoint(filesDir: string): string | undefined {
  const rows = readImageRuleStoreRows(databaseFor(filesDir))
  if (rows === undefined) return undefined
  const checkpoint: ImageRuleDatabaseCheckpoint = { databaseRows: rows.map((row: ImageRuleDatabaseRow): string => JSON.stringify(row)) }
  return JSON.stringify(checkpoint)
}

export async function restoreImageRuleDatabaseCheckpoint(filesDir: string, payload: string | undefined): Promise<void> {
  const store = databaseFor(filesDir)
  if (payload === undefined) {
    writeUserRecords(store, (): void => replaceImageRuleStoreRows(store, undefined))
    return
  }
  const checkpoint = JSON.parse(payload) as ImageRuleDatabaseCheckpoint
  if (!Array.isArray(checkpoint?.databaseRows)) {
    await writeImageRuleDatabaseSnapshot(filesDir, payload)
    return
  }
  const rows = checkpoint.databaseRows.map((value: string): ImageRuleDatabaseRow => {
    const row = JSON.parse(value) as ImageRuleDatabaseRow
    if (typeof row?.key !== 'string' || !/^[0-9a-f]{64}$/.test(row.asset)) throw new Error('invalid_image_rule_checkpoint')
    return row
  })
  writeUserRecords(store, (): void => replaceImageRuleStoreRows(store, rows))
}

export async function writeImageRuleDatabaseSnapshot(filesDir: string, payload: string | undefined, migrate: boolean = false): Promise<void> {
  const directory = filesDir + '/image-rule-assets'
  let rows: ImageRuleDatabaseRow[] | undefined
  if (payload !== undefined) {
    const raw = await taskpool.execute(stageImageRuleRows, directory, payload) as string
    rows = JSON.parse(raw) as ImageRuleDatabaseRow[]
  }
  const store = databaseFor(filesDir)
  writeUserRecords(store, (): void => {
    if (migrate && hasUserDataMigration(store, MIGRATION)) return
    replaceImageRuleStoreRows(store, rows)
    if (migrate) markUserDataMigration(store, MIGRATION)
  })
  // A prepared rollback can still reference the previous committed assets.
  if (BackupRestoreActivity.isRestoring()) return
  const retained = readImageRuleStoreRows(store)?.map((row: ImageRuleDatabaseRow): string => row.asset) ?? []
  await taskpool.execute(pruneImageRuleAssets, directory, retained).catch((_error: Error): void => {})
}
