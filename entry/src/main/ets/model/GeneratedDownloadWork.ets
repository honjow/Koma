import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo as fs } from '@kit.CoreFileKit'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from './UserDataDatabase'
import { UserKeyedRecords, writeUserRecords } from './UserKeyedRecords'

export const AUTOMATIC_DOWNLOAD_WORK = 'automatic-download-pending.v1.json'
export const AFTER_READING_WORK = 'read-download-cleanup.v1.json'

export interface GeneratedDownloadChapter {
  comicId: string
  chapterId: string
}

const pending = new Map<string, Map<string, Promise<relationalStore.RdbStore>>>()

function jobKind(name: string): string {
  if (name === AUTOMATIC_DOWNLOAD_WORK) return 'automatic_download'
  if (name === AFTER_READING_WORK) return 'after_reading_cleanup'
  throw new Error('generated_download_unknown_queue')
}

function migration(kind: string): string {
  return 'library-maintenance-jobs/' + kind
}

function insertJobs(store: relationalStore.RdbStore, kind: string, items: GeneratedDownloadChapter[]): void {
  for (const item of items) {
    if (item === null || typeof item.comicId !== 'string' || typeof item.chapterId !== 'string') {
      throw new Error('generated_download_invalid_queue')
    }
    store.executeSync('INSERT INTO library_maintenance_jobs (job_kind, comic_id, chapter_id) VALUES (?, ?, ?) ' +
      'ON CONFLICT(job_kind, comic_id, chapter_id) DO NOTHING', [kind, item.comicId, item.chapterId])
  }
}

async function openQueue(context: common.Context, name: string): Promise<relationalStore.RdbStore> {
  const store = await openUserDataDatabase(context)
  const kind = jobKind(name)
  const marker = migration(kind)
  if (hasUserDataMigration(store, marker)) return store
  const previous = new UserKeyedRecords(store, 'generated-download/' + name)
  const path = context.filesDir + '/' + name
  const legacy = !previous.isMigrated() && fs.accessSync(path) ?
    JSON.parse(await fs.readText(path)) as GeneratedDownloadChapter[] : []
  writeUserRecords(store, (): void => {
    if (hasUserDataMigration(store, marker)) return
    // A committed empty queue is newer than its retained legacy file.
    const saved = previous.isMigrated() ? Array.from(previous.entries()?.values() ?? [])
      .map((row: string): GeneratedDownloadChapter => JSON.parse(row) as GeneratedDownloadChapter) : legacy
    if (!Array.isArray(saved)) throw new Error('generated_download_invalid_queue')
    insertJobs(store, kind, saved)
    markUserDataMigration(store, marker)
  })
  return store
}

async function workStore(context: common.Context, name: string): Promise<relationalStore.RdbStore> {
  const scopes = pending.get(context.filesDir) ?? new Map<string, Promise<relationalStore.RdbStore>>()
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
  await Promise.all([workStore(context, AUTOMATIC_DOWNLOAD_WORK), workStore(context, AFTER_READING_WORK)])
}

export async function readGeneratedDownloadWork(context: common.Context, name: string): Promise<GeneratedDownloadChapter[]> {
  const store = await workStore(context, name)
  const rows = store.querySqlSync('SELECT comic_id, chapter_id FROM library_maintenance_jobs ' +
    'WHERE job_kind = ? ORDER BY enqueue_order', [jobKind(name)])
  const items: GeneratedDownloadChapter[] = []
  try {
    while (rows.goToNextRow()) items.push({ comicId: rows.getString(0), chapterId: rows.getString(1) })
  } finally {
    rows.close()
  }
  return items
}

export async function saveGeneratedDownloadWork(context: common.Context, name: string, items: GeneratedDownloadChapter[]): Promise<void> {
  if (items.length === 0) return
  const store = await workStore(context, name)
  writeUserRecords(store, (): void => insertJobs(store, jobKind(name), items))
}

export async function removeGeneratedDownloadWork(context: common.Context, name: string, items: GeneratedDownloadChapter[]): Promise<void> {
  if (items.length === 0) return
  const store = await workStore(context, name)
  const kind = jobKind(name)
  writeUserRecords(store, (): void => {
    for (const item of items) {
      store.executeSync('DELETE FROM library_maintenance_jobs WHERE job_kind = ? AND comic_id = ? AND chapter_id = ?',
        [kind, item.comicId, item.chapterId])
    }
  })
}

/** Restore changes the library owning these jobs. Retire both generated queues as one transaction. */
export async function clearGeneratedDownloadWork(context: common.Context): Promise<void> {
  const store = await openUserDataDatabase(context)
  writeUserRecords(store, (): void => {
    store.executeSync('DELETE FROM library_maintenance_jobs WHERE job_kind IN (?, ?)',
      [jobKind(AUTOMATIC_DOWNLOAD_WORK), jobKind(AFTER_READING_WORK)])
    // A restore retires old jobs even if their queues have not been opened yet.
    markUserDataMigration(store, migration(jobKind(AUTOMATIC_DOWNLOAD_WORK)))
    markUserDataMigration(store, migration(jobKind(AFTER_READING_WORK)))
  })
}
