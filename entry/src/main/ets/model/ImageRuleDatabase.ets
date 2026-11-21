import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { openUserDataDatabase } from './UserDataDatabase'
import { UserKeyedRecords, UserRecordValues } from './UserKeyedRecords'
import { pruneImageRuleAssets, readImageRuleRows, stageImageRuleRows } from './ImageRuleAssetWorker'
import type { ImageRuleDatabaseRow } from './ImageRuleAssetFiles'

export const IMAGE_RULE_LEGACY_PATH = 'image-rules.v1.json'
const opened = new Map<string, UserKeyedRecords>()

function recordsFor(filesDir: string): UserKeyedRecords {
  const records = opened.get(filesDir)
  if (records === undefined) throw new Error('image_rule_database_not_open')
  return records
}

export async function prepareImageRuleDatabase(context: common.Context): Promise<void> {
  const directory = context.filesDir
  if (!opened.has(directory)) opened.set(directory, new UserKeyedRecords(await openUserDataDatabase(context), 'image-rule-configuration'))
}

export function usesImageRuleDatabase(filesDir: string): boolean { return opened.get(filesDir)?.isMigrated() === true }

export async function readImageRuleDatabaseSnapshot(filesDir: string): Promise<string | undefined> {
  const rows = recordsFor(filesDir).entries()
  if (rows === undefined) return undefined
  const serialized = '[' + Array.from(rows.values()).join(',') + ']'
  return await taskpool.execute(readImageRuleRows, filesDir + '/image-rule-assets', serialized) as string
}

interface ImageRuleDatabaseCheckpoint {
  databaseRows: string[]
}

export function readImageRuleDatabaseCheckpoint(filesDir: string): string | undefined {
  const rows = recordsFor(filesDir).entries()
  if (rows === undefined) return undefined
  const checkpoint: ImageRuleDatabaseCheckpoint = { databaseRows: Array.from(rows.values()) }
  return JSON.stringify(checkpoint)
}

export async function restoreImageRuleDatabaseCheckpoint(filesDir: string, payload: string | undefined): Promise<void> {
  if (payload === undefined) {
    recordsFor(filesDir).replace(undefined)
    return
  }
  const checkpoint = JSON.parse(payload) as ImageRuleDatabaseCheckpoint
  if (!Array.isArray(checkpoint?.databaseRows)) {
    await writeImageRuleDatabaseSnapshot(filesDir, payload)
    return
  }
  const records: UserRecordValues = new Map()
  for (const value of checkpoint.databaseRows) {
    const row = JSON.parse(value) as ImageRuleDatabaseRow
    if (typeof row?.key !== 'string' || !/^[0-9a-f]{64}$/.test(row.asset)) throw new Error('invalid_image_rule_checkpoint')
    records.set(row.key, value)
  }
  recordsFor(filesDir).replace(records)
}

export async function writeImageRuleDatabaseSnapshot(filesDir: string, payload: string | undefined, migrate: boolean = false): Promise<void> {
  const directory = filesDir + '/image-rule-assets'
  let records: UserRecordValues | undefined
  if (payload !== undefined) {
    const raw = await taskpool.execute(stageImageRuleRows, directory, payload) as string
    const rows = JSON.parse(raw) as ImageRuleDatabaseRow[]
    records = new Map()
    for (const row of rows) records.set(row.key, JSON.stringify(row))
  }
  const storage = recordsFor(filesDir)
  if (migrate) storage.migrate(records)
  else storage.replace(records)
  // A prepared rollback can still reference the previous committed assets.
  if (BackupRestoreActivity.isRestoring()) return
  const retained: string[] = []
  storage.entries()?.forEach((value: string): void => { retained.push((JSON.parse(value) as ImageRuleDatabaseRow).asset) })
  await taskpool.execute(pruneImageRuleAssets, directory, retained).catch((_error: Error): void => {})
}
