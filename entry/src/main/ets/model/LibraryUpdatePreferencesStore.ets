import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export interface LibraryUpdatePreferences {
  autoCheckEnabled: boolean
  intervalHours: number
  lastCheckedAt?: number
  lastSummaryText?: string
}

export const LIBRARY_UPDATE_PREFERENCES_STORE_NAME: string = 'koma_library_update_preferences_v1'
export const LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY: string = 'libraryUpdate.autoCheckEnabled'
export const LIBRARY_UPDATE_INTERVAL_HOURS_KEY: string = 'libraryUpdate.intervalHours'
export const LIBRARY_UPDATE_LAST_CHECKED_AT_KEY: string = 'libraryUpdate.lastCheckedAt'
export const LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY: string = 'libraryUpdate.lastSummaryText'
export const LIBRARY_UPDATE_INTERVAL_OPTIONS: number[] = [12, 24, 48]

export const DEFAULT_LIBRARY_UPDATE_PREFERENCES: LibraryUpdatePreferences = {
  autoCheckEnabled: false,
  intervalHours: 24,
}

export function normalizeLibraryUpdateAutoCheckEnabled(value: boolean | string | number): boolean {
  if (value === true || value === 'true' || value === 1 || value === '1') {
    return true
  }
  return false
}

export function normalizeLibraryUpdateIntervalHours(value: number | string): number {
  const parsed = typeof value === 'number' ? value : Number.parseInt(value, 10)
  if (LIBRARY_UPDATE_INTERVAL_OPTIONS.includes(parsed)) {
    return parsed
  }
  return DEFAULT_LIBRARY_UPDATE_PREFERENCES.intervalHours
}

export function normalizeLibraryUpdateTimestamp(value: number | string | undefined): number | undefined {
  if (value === undefined) {
    return undefined
  }
  const parsed = typeof value === 'number' ? value : Number.parseInt(value, 10)
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed
  }
  return undefined
}

export function normalizeLibraryUpdateSummaryText(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : undefined
}

export function getLibraryUpdateAutoCheckLabel(preferences: LibraryUpdatePreferences): string {
  if (!preferences.autoCheckEnabled) {
    return '关闭'
  }
  return `每 ${preferences.intervalHours} 小时`
}

export function isLibraryUpdateDue(preferences: LibraryUpdatePreferences, now: number): boolean {
  if (!preferences.autoCheckEnabled) {
    return false
  }
  if (preferences.lastCheckedAt === undefined) {
    return true
  }
  return now - preferences.lastCheckedAt >= preferences.intervalHours * 60 * 60 * 1000
}

export class LibraryUpdatePreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<LibraryUpdatePreferences> {
    try {
      const store = await this.preferences()
      const autoCheckEnabled =
        await store.get(LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY, DEFAULT_LIBRARY_UPDATE_PREFERENCES.autoCheckEnabled) as boolean | string | number
      const intervalHours =
        await store.get(LIBRARY_UPDATE_INTERVAL_HOURS_KEY, DEFAULT_LIBRARY_UPDATE_PREFERENCES.intervalHours) as number | string
      const lastCheckedAt = await store.get(LIBRARY_UPDATE_LAST_CHECKED_AT_KEY, 0) as number | string
      const lastSummaryText = await store.get(LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY, '') as string
      const normalized: LibraryUpdatePreferences = {
        autoCheckEnabled: normalizeLibraryUpdateAutoCheckEnabled(autoCheckEnabled),
        intervalHours: normalizeLibraryUpdateIntervalHours(intervalHours),
      }
      const checkedAt = normalizeLibraryUpdateTimestamp(lastCheckedAt)
      if (checkedAt !== undefined) {
        normalized.lastCheckedAt = checkedAt
      }
      const summaryText = normalizeLibraryUpdateSummaryText(lastSummaryText)
      if (summaryText !== undefined) {
        normalized.lastSummaryText = summaryText
      }
      return normalized
    } catch (_error) {
      return {
        autoCheckEnabled: DEFAULT_LIBRARY_UPDATE_PREFERENCES.autoCheckEnabled,
        intervalHours: DEFAULT_LIBRARY_UPDATE_PREFERENCES.intervalHours,
      }
    }
  }

  async saveAutoCheckEnabled(autoCheckEnabled: boolean): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled,
      intervalHours: current.intervalHours,
    }
    if (current.lastCheckedAt !== undefined) {
      next.lastCheckedAt = current.lastCheckedAt
    }
    if (current.lastSummaryText !== undefined) {
      next.lastSummaryText = current.lastSummaryText
    }
    await this.save(next)
    return next
  }

  async saveIntervalHours(intervalHours: number): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled: current.autoCheckEnabled,
      intervalHours: normalizeLibraryUpdateIntervalHours(intervalHours),
    }
    if (current.lastCheckedAt !== undefined) {
      next.lastCheckedAt = current.lastCheckedAt
    }
    if (current.lastSummaryText !== undefined) {
      next.lastSummaryText = current.lastSummaryText
    }
    await this.save(next)
    return next
  }

  async saveLastSummary(checkedAt: number, summaryText: string): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled: current.autoCheckEnabled,
      intervalHours: current.intervalHours,
      lastCheckedAt: checkedAt,
      lastSummaryText: summaryText,
    }
    await this.save(next)
    return next
  }

  async save(libraryUpdatePreferences: LibraryUpdatePreferences): Promise<void> {
    const store = await this.preferences()
    await store.put(
      LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY,
      normalizeLibraryUpdateAutoCheckEnabled(libraryUpdatePreferences.autoCheckEnabled),
    )
    await store.put(
      LIBRARY_UPDATE_INTERVAL_HOURS_KEY,
      normalizeLibraryUpdateIntervalHours(libraryUpdatePreferences.intervalHours),
    )
    const checkedAt = normalizeLibraryUpdateTimestamp(libraryUpdatePreferences.lastCheckedAt)
    await store.put(LIBRARY_UPDATE_LAST_CHECKED_AT_KEY, checkedAt ?? 0)
    await store.put(
      LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY,
      normalizeLibraryUpdateSummaryText(libraryUpdatePreferences.lastSummaryText) ?? '',
    )
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, LIBRARY_UPDATE_PREFERENCES_STORE_NAME)
  }
}
