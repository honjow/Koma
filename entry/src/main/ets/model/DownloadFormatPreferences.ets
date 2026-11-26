import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'

const STORE: string = 'koma_download_format_v1'
const SAVE_AS_CBZ: string = 'download.saveAsCbz'
export const DOWNLOAD_PAGE_CONCURRENCY_KEY: string = 'download.pageConcurrency'
export const DOWNLOAD_PAGE_CONCURRENCY_OPTIONS: number[] = [1, 2, 3, 4, 5]
const writes = new Map<string, Promise<void>>()

export async function loadDownloadSaveAsCbz(context: common.Context): Promise<boolean> {
  await writes.get(context.filesDir)?.catch((): void => {})
  const store = await preferences.getPreferences(context, STORE)
  return (await store.get(SAVE_AS_CBZ, true)) === true
}

export async function saveDownloadSaveAsCbz(context: common.Context, enabled: boolean): Promise<void> {
  await saveDownloadPreference(context, SAVE_AS_CBZ, enabled, true)
}

export async function loadDownloadPageConcurrency(context: common.Context): Promise<number> {
  await writes.get(context.filesDir)?.catch((): void => {})
  const store = await preferences.getPreferences(context, STORE)
  const limit = await store.get(DOWNLOAD_PAGE_CONCURRENCY_KEY, 1)
  // Older installations retain sequential downloads until the user opts in.
  return typeof limit === 'number' && DOWNLOAD_PAGE_CONCURRENCY_OPTIONS.includes(limit) ? limit : 1
}

export async function saveDownloadPageConcurrency(context: common.Context, limit: number): Promise<void> {
  if (!DOWNLOAD_PAGE_CONCURRENCY_OPTIONS.includes(limit)) throw new Error('download_page_concurrency_invalid')
  await saveDownloadPreference(context, DOWNLOAD_PAGE_CONCURRENCY_KEY, limit, 1)
}

async function saveDownloadPreference(context: common.Context, key: string, value: boolean | number,
  defaultValue: boolean | number): Promise<void> {
  const previous = writes.get(context.filesDir) ?? Promise.resolve()
  const write = previous.catch((): void => {}).then(async (): Promise<void> => {
    await BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, STORE)
      const existed = await store.has(key)
      const original = await store.get(key, defaultValue)
      try {
        await store.put(key, value)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(key, original)
        else await store.delete(key)
        throw error as Error
      }
    })
  })
  writes.set(context.filesDir, write)
  try { await write } finally {
    if (writes.get(context.filesDir) === write) writes.delete(context.filesDir)
  }
}
