import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { openUserDataDatabase } from './UserDataDatabase'
import { UserKeyedRecords, UserRecordValues, writeUserRecords } from './UserKeyedRecords'

export const AUTOMATIC_DOWNLOAD_WORK = 'automatic-download-pending.v1.json'
export const AFTER_READING_WORK = 'read-download-cleanup.v1.json'

export interface GeneratedDownloadChapter {
  comicId: string
  chapterId: string
}

const pending = new Map<string, Map<string, Promise<UserKeyedRecords>>>()
function workKey(item: GeneratedDownloadChapter): string { return JSON.stringify([item.comicId, item.chapterId]) }

async function openQueue(context: common.Context, name: string): Promise<UserKeyedRecords> {
  const database = await openUserDataDatabase(context)
  const records = new UserKeyedRecords(database, 'generated-download/' + name)
  if (records.isMigrated()) return records
  const path = context.filesDir + '/' + name
  const rows = fs.accessSync(path) ? JSON.parse(await fs.readText(path)) as GeneratedDownloadChapter[] : []
  if (!Array.isArray(rows) || rows.some((row: GeneratedDownloadChapter): boolean =>
    row === null || typeof row.comicId !== 'string' || typeof row.chapterId !== 'string')) {
    throw new Error('generated_download_invalid_queue')
  }
  records.migrate(chapterRows(rows))
  return records
}

function chapterRows(items: GeneratedDownloadChapter[]): UserRecordValues {
  const rows: UserRecordValues = new Map()
  for (const item of items) rows.set(workKey(item), JSON.stringify(item))
  return rows
}

async function workRecords(context: common.Context, name: string): Promise<UserKeyedRecords> {
  const scopes = pending.get(context.filesDir) ?? new Map<string, Promise<UserKeyedRecords>>()
  pending.set(context.filesDir, scopes)
  const existing = scopes.get(name)
  if (existing !== undefined) return existing
  const opening = openQueue(context, name).catch((error: Error): never => {
    scopes.delete(name)
    throw error
  })
  scopes.set(name, opening)
  return opening
}

export async function prepareGeneratedDownloadWork(context: common.Context): Promise<void> {
  await Promise.all([workRecords(context, AUTOMATIC_DOWNLOAD_WORK), workRecords(context, AFTER_READING_WORK)])
}

export async function readGeneratedDownloadWork(context: common.Context, name: string): Promise<GeneratedDownloadChapter[]> {
  const rows = (await workRecords(context, name)).entries()
  if (rows === undefined) return []
  return Array.from(rows.values()).map((value: string): GeneratedDownloadChapter => JSON.parse(value) as GeneratedDownloadChapter)
}

export async function saveGeneratedDownloadWork(context: common.Context, name: string, items: GeneratedDownloadChapter[]): Promise<void> {
  if (items.length === 0) return
  const database = await openUserDataDatabase(context)
  const records = await workRecords(context, name)
  writeUserRecords(database, (): void => records.mergeInTransaction(chapterRows(items)))
}

export async function removeGeneratedDownloadWork(context: common.Context, name: string, items: GeneratedDownloadChapter[]): Promise<void> {
  if (items.length === 0) return
  const database = await openUserDataDatabase(context)
  const records = await workRecords(context, name)
  writeUserRecords(database, (): void => {
    for (const item of items) records.putInTransaction(workKey(item), undefined)
  })
}

/** Restore changes the library owning these jobs. Retire both generated queues as one transaction. */
export async function clearGeneratedDownloadWork(context: common.Context): Promise<void> {
  const database = await openUserDataDatabase(context)
  const automatic = new UserKeyedRecords(database, 'generated-download/' + AUTOMATIC_DOWNLOAD_WORK)
  const cleanup = new UserKeyedRecords(database, 'generated-download/' + AFTER_READING_WORK)
  // Clearing generated work also covers legacy records, even if they have never been read.
  automatic.migrate(undefined)
  cleanup.migrate(undefined)
  writeUserRecords(database, (): void => {
    automatic.replaceInTransaction(undefined)
    cleanup.replaceInTransaction(undefined)
  })
}
