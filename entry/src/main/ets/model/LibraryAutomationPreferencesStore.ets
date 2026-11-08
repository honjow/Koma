import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { LibraryAutomationPreferences, defaultLibraryAutomationPreferences } from './LibraryAutomationPolicy'

export const LIBRARY_AUTOMATION_STORE_NAME: string = 'koma_library_automation_v1'
export const LIBRARY_AUTOMATION_POLICY_KEY: string = 'automation.policy'
let mutations: Promise<void> = Promise.resolve()
let cachedAutomationPolicy: LibraryAutomationPreferences | undefined = undefined

function categoryIds(value: string[] | undefined): string[] {
  return Array.isArray(value) ? Array.from(new Set<string>(value.filter((id: string): boolean =>
    typeof id === 'string' && id.length > 0))) : []
}

function normalize(value: LibraryAutomationPreferences): LibraryAutomationPreferences {
  return {
    updateWifiOnly: value.updateWifiOnly === true,
    updateChargingOnly: value.updateChargingOnly === true,
    refreshWorkInfo: value.refreshWorkInfo === true,
    updateIncludedCategories: categoryIds(value.updateIncludedCategories),
    updateExcludedCategories: categoryIds(value.updateExcludedCategories),
    skipCompleted: value.skipCompleted === true, skipNotStarted: value.skipNotStarted === true,
    skipHasUnread: value.skipHasUnread === true, autoDownloadNewChapters: value.autoDownloadNewChapters === true,
    skipOutsideReleasePeriod: value.skipOutsideReleasePeriod === true,
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
    // Read once per process; every reader-of-record (post-read cleanup, auto
    // update, auto download) otherwise repeats two native preference calls.
    // Backup restore publishes through invalidateLibraryAutomationPolicyCache.
    if (cachedAutomationPolicy !== undefined) return cachedAutomationPolicy
    const store = await preferences.getPreferences(this.context, LIBRARY_AUTOMATION_STORE_NAME)
    const payload = await store.get(LIBRARY_AUTOMATION_POLICY_KEY, '') as string
    const policy = payload.length === 0 ? defaultLibraryAutomationPreferences() :
      normalize(JSON.parse(payload) as LibraryAutomationPreferences)
    cachedAutomationPolicy = policy
    return policy
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
    void pending.then((next: LibraryAutomationPreferences): void => {
      cachedAutomationPolicy = next
    })
    return pending
  }
}

/** Backup restore overwrites the preference file without update(); callers
 * must drop the process cache so the next load reads the restored values. */
export function invalidateLibraryAutomationPolicyCache(): void {
  cachedAutomationPolicy = undefined
}
