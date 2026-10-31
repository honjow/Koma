import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { LibraryAutomationPreferences, defaultLibraryAutomationPreferences } from './LibraryAutomationPolicy'

export const LIBRARY_AUTOMATION_STORE_NAME: string = 'koma_library_automation_v1'
export const LIBRARY_AUTOMATION_POLICY_KEY: string = 'automation.policy'
let mutations: Promise<void> = Promise.resolve()

function categoryIds(value: string[] | undefined): string[] {
  return Array.isArray(value) ? Array.from(new Set<string>(value.filter((id: string): boolean =>
    typeof id === 'string' && id.length > 0))) : []
}

function normalize(value: LibraryAutomationPreferences): LibraryAutomationPreferences {
  return {
    updateWifiOnly: value.updateWifiOnly === true,
    updateChargingOnly: value.updateChargingOnly === true,
    updateIncludedCategories: categoryIds(value.updateIncludedCategories),
    updateExcludedCategories: categoryIds(value.updateExcludedCategories),
    skipCompleted: value.skipCompleted === true, skipNotStarted: value.skipNotStarted === true,
    skipHasUnread: value.skipHasUnread === true, autoDownloadNewChapters: value.autoDownloadNewChapters === true,
    downloadUnreadOnly: value.downloadUnreadOnly !== false,
    downloadIncludedCategories: categoryIds(value.downloadIncludedCategories),
    downloadExcludedCategories: categoryIds(value.downloadExcludedCategories),
    removeAfterRead: [-1, 0, 2, 3, 5].includes(value.removeAfterRead) ? value.removeAfterRead : -1,
    cleanupExcludedCategories: categoryIds(value.cleanupExcludedCategories),
  }
}

export class LibraryAutomationPreferencesStore {
  private context: common.Context

  constructor(context: common.Context) { this.context = context }

  async load(): Promise<LibraryAutomationPreferences> {
    const store = await preferences.getPreferences(this.context, LIBRARY_AUTOMATION_STORE_NAME)
    const payload = await store.get(LIBRARY_AUTOMATION_POLICY_KEY, '') as string
    return payload.length === 0 ? defaultLibraryAutomationPreferences() :
      normalize(JSON.parse(payload) as LibraryAutomationPreferences)
  }

  update(change: (policy: LibraryAutomationPreferences) => void): Promise<LibraryAutomationPreferences> {
    const pending = mutations.then(() => BackupRestoreActivity.runWrite(async (): Promise<LibraryAutomationPreferences> => {
      const current = await this.load()
      const previous = JSON.stringify(current)
      change(current)
      const next = normalize(current)
      const store = await preferences.getPreferences(this.context, LIBRARY_AUTOMATION_STORE_NAME)
      try {
        await store.put(LIBRARY_AUTOMATION_POLICY_KEY, JSON.stringify(next))
        await store.flush()
      } catch (error) {
        await store.put(LIBRARY_AUTOMATION_POLICY_KEY, previous)
        await store.flush()
        throw error as Error
      }
      return next
    }))
    mutations = pending.then(() => {}, () => {})
    return pending
  }
}
