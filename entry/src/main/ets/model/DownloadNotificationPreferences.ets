import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'

export type DownloadNotificationSound = 'silent' | 'sound' | 'vibrate' | 'sound_vibrate'
export interface DownloadNotificationPreferences {
  enabled: boolean
  sound: DownloadNotificationSound
}

const STORE: string = 'koma_download_notifications_v1'
const ENABLED: string = 'download.notifications.enabled'
const SOUND: string = 'download.notifications.sound'

export function normalizeDownloadNotificationSound(value: string): DownloadNotificationSound {
  return value === 'sound' || value === 'vibrate' || value === 'sound_vibrate' ? value : 'silent'
}

export async function loadDownloadNotificationPreferences(context: common.UIAbilityContext): Promise<DownloadNotificationPreferences> {
  const store = await preferences.getPreferences(context, STORE)
  return {
    enabled: await store.get(ENABLED, true) as boolean,
    sound: normalizeDownloadNotificationSound(await store.get(SOUND, 'silent') as string),
  }
}

const writes: Map<string, Promise<void>> = new Map()

async function writePreference(context: common.UIAbilityContext, key: string, value: string | boolean): Promise<void> {
  const previous = writes.get(context.filesDir) ?? Promise.resolve()
  const operation = previous.catch((): void => {}).then(async (): Promise<void> => {
    await BackupRestoreActivity.runWrite(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, STORE)
      const existed = await store.has(key)
      const old = await store.get(key, value)
      try {
        await store.put(key, value)
        await store.flush()
      } catch (error) {
        if (existed) await store.put(key, old)
        else await store.delete(key)
        throw error as Error
      }
    })
  })
  writes.set(context.filesDir, operation)
  try { await operation }
  finally { if (writes.get(context.filesDir) === operation) writes.delete(context.filesDir) }
}

export async function saveDownloadNotificationEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
  await writePreference(context, ENABLED, enabled)
}

export async function saveDownloadNotificationSound(context: common.UIAbilityContext, sound: DownloadNotificationSound): Promise<void> {
  await writePreference(context, SOUND, normalizeDownloadNotificationSound(sound))
}
