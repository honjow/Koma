import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'

export interface DownloadNotificationPreferences {
  enabled: boolean
}

const STORE: string = 'koma_download_notifications_v1'
const ENABLED: string = 'download.notifications.enabled'

export async function loadDownloadNotificationPreferences(context: common.UIAbilityContext): Promise<DownloadNotificationPreferences> {
  const store = await preferences.getPreferences(context, STORE)
  return {
    enabled: await store.get(ENABLED, true) as boolean,
  }
}

const writes: Map<string, Promise<void>> = new Map()

export async function saveDownloadNotificationEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
  const previous = writes.get(context.filesDir) ?? Promise.resolve()
  const operation = previous.catch((): void => {}).then(async (): Promise<void> => {
    await BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, STORE)
      const existed = await store.has(ENABLED)
      const old = await store.get(ENABLED, enabled)
      try {
        await store.put(ENABLED, enabled)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(ENABLED, old)
        else await store.delete(ENABLED)
        throw error as Error
      }
    })
  })
  writes.set(context.filesDir, operation)
  try { await operation }
  finally { if (writes.get(context.filesDir) === operation) writes.delete(context.filesDir) }
}
