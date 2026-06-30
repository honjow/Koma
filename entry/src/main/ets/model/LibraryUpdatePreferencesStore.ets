import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'

export type LibraryUpdateNotificationStatus = 'disabled' | 'planned' | 'unavailable'

export interface LibraryUpdatePreferences {
  autoCheckEnabled: boolean
  intervalHours: number
  foregroundOnly: boolean
  lastCheckedAt?: number
  lastSummaryText?: string
  failureCount: number
  lastFailureCode?: string
}

export const LIBRARY_UPDATE_PREFERENCES_STORE_NAME: string = 'koma_library_update_preferences_v1'
export const LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY: string = 'libraryUpdate.autoCheckEnabled'
export const LIBRARY_UPDATE_INTERVAL_HOURS_KEY: string = 'libraryUpdate.intervalHours'
export const LIBRARY_UPDATE_FOREGROUND_ONLY_KEY: string = 'libraryUpdate.foregroundOnly'
export const LIBRARY_UPDATE_LAST_CHECKED_AT_KEY: string = 'libraryUpdate.lastCheckedAt'
export const LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY: string = 'libraryUpdate.lastSummaryText'
export const LIBRARY_UPDATE_FAILURE_COUNT_KEY: string = 'libraryUpdate.failureCount'
export const LIBRARY_UPDATE_LAST_FAILURE_CODE_KEY: string = 'libraryUpdate.lastFailureCode'
export const LIBRARY_UPDATE_INTERVAL_OPTIONS: number[] = [12, 24, 48]
export const LIBRARY_UPDATE_NOTIFICATION_STATUS: LibraryUpdateNotificationStatus = 'planned'
export const LIBRARY_UPDATE_MAX_BACKOFF_HOURS: number = 24

export const DEFAULT_LIBRARY_UPDATE_PREFERENCES: LibraryUpdatePreferences = {
  autoCheckEnabled: false,
  intervalHours: 24,
  foregroundOnly: true,
  failureCount: 0,
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

export function normalizeLibraryUpdateForegroundOnly(value: boolean | string | number): boolean {
  return value === false || value === 'false' || value === 0 || value === '0' ? false : true
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

export function normalizeLibraryUpdateFailureCount(value: number | string | undefined): number {
  if (value === undefined) {
    return 0
  }
  const parsed = typeof value === 'number' ? value : Number.parseInt(value, 10)
  if (Number.isFinite(parsed) && parsed > 0) {
    return Math.min(Math.floor(parsed), 12)
  }
  return 0
}

export function normalizeLibraryUpdateFailureCode(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const trimmed = value.trim().toLocaleLowerCase()
  if (trimmed.length === 0) {
    return undefined
  }
  if (/timeout|timed\s*out|deadline|etimedout/.test(trimmed)) {
    return 'timeout'
  }
  if (/storage|database|disk|quota|file|cache|path|directory|(^|\s)\/[^\s]+|(^|\s)[a-z]:[\\/]|enoent|eacces/.test(trimmed)) {
    return 'storage_error'
  }
  if (/auth|unauthori[sz]ed|forbidden|permission|login|credential|tok(?:en)?|api[_\s-]?key|secret|401|403/.test(trimmed)) {
    return 'auth_error'
  }
  if (/network|fetch|http|https|dns|socket|connection|econn|enotfound|eai_again|ssl|tls|remote/.test(trimmed)) {
    return 'network_error'
  }
  if (/source|runtime|wasm|provider|plugin|script|exception|unavailable/.test(trimmed)) {
    return 'source_runtime_error'
  }
  return 'unknown'
}

export function formatLibraryUpdateTimestamp(value: number): string {
  const date = new Date(value)
  const year = `${date.getFullYear()}`
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  const hour = `${date.getHours()}`.padStart(2, '0')
  const minute = `${date.getMinutes()}`.padStart(2, '0')
  return `${year}-${month}-${day} ${hour}:${minute}`
}

export function getLibraryUpdateAutoCheckLabel(preferences: LibraryUpdatePreferences): string {
  if (!preferences.autoCheckEnabled) {
    return AppStrings.get('library_update_auto_check_off')
  }
  return AppStrings.get('library_update_auto_check_every_hours').replace('%s', `${preferences.intervalHours}`)
}

export function getLibraryUpdateBackoffHours(preferences: LibraryUpdatePreferences): number {
  const failureCount = normalizeLibraryUpdateFailureCount(preferences.failureCount)
  if (failureCount <= 0) {
    return 0
  }
  return Math.min(Math.pow(2, failureCount - 1), LIBRARY_UPDATE_MAX_BACKOFF_HOURS)
}

export function getLibraryUpdateNextDueAt(preferences: LibraryUpdatePreferences): number | undefined {
  if (!preferences.autoCheckEnabled) {
    return undefined
  }
  if (preferences.lastCheckedAt === undefined) {
    return 0
  }
  const intervalMs = preferences.intervalHours * 60 * 60 * 1000
  const backoffMs = getLibraryUpdateBackoffHours(preferences) * 60 * 60 * 1000
  return preferences.lastCheckedAt + intervalMs + backoffMs
}

export function getLibraryUpdateNextDueLabel(preferences: LibraryUpdatePreferences): string {
  const nextDueAt = getLibraryUpdateNextDueAt(preferences)
  if (nextDueAt === undefined) {
    return AppStrings.get('library_update_next_due_disabled')
  }
  if (nextDueAt === 0) {
    return AppStrings.get('library_update_next_due_on_open')
  }
  const backoffHours = getLibraryUpdateBackoffHours(preferences)
  if (backoffHours > 0) {
    return AppStrings.get('library_update_next_due_backoff')
      .replace('%s', formatLibraryUpdateTimestamp(nextDueAt))
      .replace('%s', `${backoffHours}`)
  }
  return AppStrings.get('library_update_next_due_at').replace('%s', formatLibraryUpdateTimestamp(nextDueAt))
}

export function getLibraryUpdateLastResultLabel(preferences: LibraryUpdatePreferences): string {
  if (
    preferences.lastFailureCode !== undefined &&
      preferences.lastCheckedAt !== undefined &&
      normalizeLibraryUpdateFailureCount(preferences.failureCount) > 0
  ) {
    return AppStrings.get('library_update_last_failed')
      .replace('%s', preferences.lastFailureCode)
      .replace('%s', formatLibraryUpdateTimestamp(preferences.lastCheckedAt))
  }
  if (preferences.lastSummaryText !== undefined && preferences.lastCheckedAt !== undefined) {
    return AppStrings.get('library_update_last_result')
      .replace('%s', preferences.lastSummaryText)
      .replace('%s', formatLibraryUpdateTimestamp(preferences.lastCheckedAt))
  }
  if (preferences.lastFailureCode !== undefined && preferences.lastCheckedAt !== undefined) {
    return AppStrings.get('library_update_last_failed')
      .replace('%s', preferences.lastFailureCode)
      .replace('%s', formatLibraryUpdateTimestamp(preferences.lastCheckedAt))
  }
  return AppStrings.get('library_update_no_result')
}

export function getLibraryUpdateNotificationStatusLabel(status: LibraryUpdateNotificationStatus = LIBRARY_UPDATE_NOTIFICATION_STATUS): string {
  if (status === 'disabled') {
    return AppStrings.get('common_off')
  }
  if (status === 'unavailable') {
    return AppStrings.get('library_update_notification_unavailable')
  }
  return AppStrings.get('library_update_notification_planned')
}

export function isLibraryUpdateNotificationDeliveryEnabled(status: LibraryUpdateNotificationStatus = LIBRARY_UPDATE_NOTIFICATION_STATUS): boolean {
  if (status === 'planned') {
    return false
  }
  if (status === 'unavailable') {
    return false
  }
  return false
}

export function isLibraryUpdateDue(preferences: LibraryUpdatePreferences, now: number): boolean {
  if (!preferences.autoCheckEnabled) {
    return false
  }
  if (preferences.lastCheckedAt === undefined) {
    return true
  }
  const nextDueAt = getLibraryUpdateNextDueAt(preferences)
  return nextDueAt !== undefined && nextDueAt > 0 && now >= nextDueAt
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
      const foregroundOnly =
        await store.get(LIBRARY_UPDATE_FOREGROUND_ONLY_KEY, DEFAULT_LIBRARY_UPDATE_PREFERENCES.foregroundOnly) as boolean | string | number
      const lastCheckedAt = await store.get(LIBRARY_UPDATE_LAST_CHECKED_AT_KEY, 0) as number | string
      const lastSummaryText = await store.get(LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY, '') as string
      const failureCount = await store.get(LIBRARY_UPDATE_FAILURE_COUNT_KEY, 0) as number | string
      const lastFailureCode = await store.get(LIBRARY_UPDATE_LAST_FAILURE_CODE_KEY, '') as string
      const normalized: LibraryUpdatePreferences = {
        autoCheckEnabled: normalizeLibraryUpdateAutoCheckEnabled(autoCheckEnabled),
        intervalHours: normalizeLibraryUpdateIntervalHours(intervalHours),
        foregroundOnly: normalizeLibraryUpdateForegroundOnly(foregroundOnly),
        failureCount: normalizeLibraryUpdateFailureCount(failureCount),
      }
      const checkedAt = normalizeLibraryUpdateTimestamp(lastCheckedAt)
      if (checkedAt !== undefined) {
        normalized.lastCheckedAt = checkedAt
      }
      const summaryText = normalizeLibraryUpdateSummaryText(lastSummaryText)
      if (summaryText !== undefined) {
        normalized.lastSummaryText = summaryText
      }
      const failureCode = normalizeLibraryUpdateFailureCode(lastFailureCode)
      if (failureCode !== undefined) {
        normalized.lastFailureCode = failureCode
      }
      return normalized
    } catch (_error) {
      return {
        autoCheckEnabled: DEFAULT_LIBRARY_UPDATE_PREFERENCES.autoCheckEnabled,
        intervalHours: DEFAULT_LIBRARY_UPDATE_PREFERENCES.intervalHours,
        foregroundOnly: DEFAULT_LIBRARY_UPDATE_PREFERENCES.foregroundOnly,
        failureCount: DEFAULT_LIBRARY_UPDATE_PREFERENCES.failureCount,
      }
    }
  }

  async saveAutoCheckEnabled(autoCheckEnabled: boolean): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled,
      intervalHours: current.intervalHours,
      foregroundOnly: current.foregroundOnly,
      failureCount: current.failureCount,
    }
    if (current.lastCheckedAt !== undefined) {
      next.lastCheckedAt = current.lastCheckedAt
    }
    if (current.lastSummaryText !== undefined) {
      next.lastSummaryText = current.lastSummaryText
    }
    if (current.lastFailureCode !== undefined) {
      next.lastFailureCode = current.lastFailureCode
    }
    await this.save(next)
    return next
  }

  async saveIntervalHours(intervalHours: number): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled: current.autoCheckEnabled,
      intervalHours: normalizeLibraryUpdateIntervalHours(intervalHours),
      foregroundOnly: current.foregroundOnly,
      failureCount: current.failureCount,
    }
    if (current.lastCheckedAt !== undefined) {
      next.lastCheckedAt = current.lastCheckedAt
    }
    if (current.lastSummaryText !== undefined) {
      next.lastSummaryText = current.lastSummaryText
    }
    if (current.lastFailureCode !== undefined) {
      next.lastFailureCode = current.lastFailureCode
    }
    await this.save(next)
    return next
  }

  async saveLastSummary(checkedAt: number, summaryText: string): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled: current.autoCheckEnabled,
      intervalHours: current.intervalHours,
      foregroundOnly: current.foregroundOnly,
      lastCheckedAt: checkedAt,
      lastSummaryText: summaryText,
      failureCount: 0,
    }
    await this.save(next)
    return next
  }

  async saveFailedCheck(checkedAt: number, failureCode: string): Promise<LibraryUpdatePreferences> {
    const current = await this.load()
    const next: LibraryUpdatePreferences = {
      autoCheckEnabled: current.autoCheckEnabled,
      intervalHours: current.intervalHours,
      foregroundOnly: current.foregroundOnly,
      lastCheckedAt: checkedAt,
      failureCount: normalizeLibraryUpdateFailureCount(current.failureCount + 1),
      lastFailureCode: normalizeLibraryUpdateFailureCode(failureCode) ?? 'unknown',
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
    await store.put(
      LIBRARY_UPDATE_FOREGROUND_ONLY_KEY,
      normalizeLibraryUpdateForegroundOnly(libraryUpdatePreferences.foregroundOnly),
    )
    const checkedAt = normalizeLibraryUpdateTimestamp(libraryUpdatePreferences.lastCheckedAt)
    await store.put(LIBRARY_UPDATE_LAST_CHECKED_AT_KEY, checkedAt ?? 0)
    await store.put(
      LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY,
      normalizeLibraryUpdateSummaryText(libraryUpdatePreferences.lastSummaryText) ?? '',
    )
    await store.put(
      LIBRARY_UPDATE_FAILURE_COUNT_KEY,
      normalizeLibraryUpdateFailureCount(libraryUpdatePreferences.failureCount),
    )
    await store.put(
      LIBRARY_UPDATE_LAST_FAILURE_CODE_KEY,
      normalizeLibraryUpdateFailureCode(libraryUpdatePreferences.lastFailureCode) ?? '',
    )
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, LIBRARY_UPDATE_PREFERENCES_STORE_NAME)
  }
}
