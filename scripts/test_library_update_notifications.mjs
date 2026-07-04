import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const settingsPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets'), 'utf8')
const resultPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/LibraryUpdateResultPage.ets'), 'utf8')
const serviceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets'), 'utf8')
const preferencesSource = readFileSync(resolve(root, 'entry/src/main/ets/model/LibraryUpdatePreferencesStore.ets'), 'utf8')
const resultStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/LibraryUpdateResultStore.ets'), 'utf8')
const constantsSource = readFileSync(resolve(root, 'entry/src/main/ets/common/Constants.ets'), 'utf8')
const routerHelperSource = readFileSync(resolve(root, 'entry/src/main/ets/common/RouterHelper.ets'), 'utf8')
const entryAbilitySource = readFileSync(resolve(root, 'entry/src/main/ets/entryability/EntryAbility.ets'), 'utf8')
const indexSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8')
const moduleSource = readFileSync(resolve(root, 'entry/src/main/module.json5'), 'utf8')

assert.doesNotMatch(
  moduleSource,
  /ohos\.permission\.NOTIFICATION|NOTIFICATION_CONTROLLER|PUBLISH_AGENT_REMINDER/i,
  'Library update notifications must not request unsupported manifest notification, controller, or reminder permissions',
)

assert.doesNotMatch(
  settingsPageSource + serviceSource + preferencesSource,
  /background\s*scheduler|后台自动更新|reminderAgentManager/i,
  'Foreground library update UX must not add a background scheduler or reminder delivery',
)

assert.match(
  preferencesSource,
  /export const LIBRARY_UPDATE_NOTIFICATION_STATUS: LibraryUpdateNotificationStatus = 'enabled'/,
  'Notification preference must enable the implemented foreground delivery path',
)
assert.match(
  preferencesSource,
  /getLibraryUpdateNotificationStatusLabel[\s\S]*library_update_notification_unavailable[\s\S]*library_update_notification_enabled/,
  'Notification preference label must stay localized and honest about delivery',
)
assert.match(
  preferencesSource,
  /isLibraryUpdateNotificationDeliveryEnabled[\s\S]*status === 'enabled'[\s\S]*return true[\s\S]*status === 'disabled'[\s\S]*return false[\s\S]*status === 'unavailable'[\s\S]*return false/,
  'Notification helper must expose only the implemented delivery state as enabled',
)
assert.match(
  settingsPageSource,
  /settings_row_library_update_results_title[\s\S]*settings_row_library_update_results_detail/,
  'Settings must expose the update result row',
)
assert.match(
  settingsPageSource,
  /library-update-notifications[\s\S]*settings_row_library_update_notifications_title[\s\S]*settings_row_library_update_notifications_detail/,
  'Settings must expose a real notification permission row for library updates',
)

assert.match(
  serviceSource,
  /countLibraryUpdateNewChapters\(summary: LibraryUpdateSummary\)[\s\S]*result\.status !== 'updated'[\s\S]*Math\.max\(result\.newChapterCount - result\.previousChapterCount, 0\)/,
  'New chapter count must be derived deterministically from persisted per-comic result counts',
)
assert.match(
  serviceSource,
  /export type LibraryUpdateProviderKind = 'source_runtime' \| 'local' \| 'komga' \| 'opds' \| 'webdav' \| 'private_library' \| 'unsupported'/,
  'Library update results must use a bounded provider allowlist',
)
assert.match(
  serviceSource,
  /private remoteServerStore\?: RemoteServerStore[\s\S]*if \(comic\.sourceKind === ComicSourceKind\.KOMGA_REMOTE\) \{[\s\S]*return this\.checkKomgaComic\(comic, previousChapterCount\)/,
  'Komga library updates must use a real provider probe instead of the generic remote-library skipped path',
)
assert.match(
  serviceSource,
  /checkKomgaComic\(comic: Comic, previousChapterCount: number\)[\s\S]*remoteServerStore\.loadKomga\(\)[\s\S]*client\.listBooks\(\{[\s\S]*seriesIds: \[seriesId\][\s\S]*client\.listBookPages\(book\.id\)[\s\S]*mapKomgaBookToChapter/,
  'Komga update probe must load the configured server, list series books, hydrate missing pages, and map chapters',
)
assert.match(
  serviceSource,
  /komgaSeriesIdForComic\(comic: Comic\)[\s\S]*comic\.remoteResourceId[\s\S]*const marker = ':series:'[\s\S]*comic\.id\.substring/,
  'Komga update probe must recover a series id from persisted remoteResourceId or legacy comic id shape',
)
assert.match(
  serviceSource,
  /if \(comic\.sourceKind === ComicSourceKind\.OPDS_REMOTE\) \{[\s\S]*return this\.checkOpdsComic\(comic, previousChapterCount\)/,
  'OPDS library updates must use a real provider probe instead of the generic remote-library skipped path',
)
assert.match(
  serviceSource,
  /checkOpdsComic\(comic: Comic, previousChapterCount: number\)[\s\S]*remoteServerStore\.loadOpds\(\)[\s\S]*client\.fetchCatalog\(comic\.sourcePath\)[\s\S]*catalog\.publications\.find[\s\S]*mapOpdsPublicationToImages\(publication\)[\s\S]*client\.fetchPublicationImages\(manifestLink\.href\)/,
  'OPDS update probe must reload the source catalog, find the persisted publication, and refresh manifest images when available',
)
assert.match(
  serviceSource,
  /if \(comic\.sourceKind === ComicSourceKind\.WEBDAV_REMOTE\) \{[\s\S]*return this\.checkWebDavComic\(comic, previousChapterCount\)/,
  'WebDAV library updates must use a real provider probe instead of the generic remote-library skipped path',
)
assert.match(
  serviceSource,
  /checkWebDavComic\(comic: Comic, previousChapterCount: number\)[\s\S]*remoteServerStore\.loadWebDav\(\)[\s\S]*webDavPathSegmentsForComic\(client\.buildUrl\(\[\]\), comic\.remoteResourceId\)[\s\S]*client\.propfind\(pathSegments, 1\)[\s\S]*DavComicCandidateKind\.IMAGE_FILE[\s\S]*client\.getResourceUrl\(resource\)/,
  'WebDAV update probe must reload the persisted directory and rebuild image pages from PROPFIND resources',
)
assert.match(
  serviceSource,
  /compareNaturalPath\(this\.webDavResourceName\(left\), this\.webDavResourceName\(right\)\)/,
  'WebDAV update probe must preserve natural image order when rebuilding remote chapters',
)
assert.match(
  settingsPageSource,
  /new LibraryUpdateService\([\s\S]*this\.libraryPersistenceService,[\s\S]*new RemoteServerStore\(this\.context\(\)\)/,
  'Settings foreground update runner must pass RemoteServerStore so Komga library items can refresh',
)
assert.match(
  serviceSource,
  /safeLibraryUpdateSourceKey\(value: string \| undefined\): string[\s\S]*return `source:\$\{\(hash >>> 0\)\.toString\(36\)\}`/,
  'Library update source keys must be hashed instead of persisting raw source/provider identifiers',
)
assert.match(
  serviceSource,
  /summarizeLibraryUpdateProviders\(results: LibraryUpdateComicResult\[\]\): LibraryUpdateProviderSummary\[\][\s\S]*item\.providerKind === result\.providerKind && item\.sourceKey === result\.sourceKey[\s\S]*failureCodes/,
  'Library update summaries must include per-provider/per-source grouped outcomes',
)
assert.match(
  serviceSource,
  /formatLibraryUpdateSummary\(summary\?: LibraryUpdateSummary\): string[\s\S]*library_unit_books[\s\S]*library_unit_new_chapters[\s\S]*library_unit_updated[\s\S]*library_unit_skipped[\s\S]*library_unit_failed/,
  'Summary formatting must include localized new, updated, skipped, and failed counts in a stable order',
)
assert.match(
  preferencesSource,
  /formatLibraryUpdateTimestamp\(value: number\)[\s\S]*padStart\(2, '0'\)[\s\S]*return `\$\{year\}-\$\{month\}-\$\{day\} \$\{hour\}:\$\{minute\}`/,
  'Timestamp formatting must be deterministic and not depend on locale formatting APIs',
)
assert.match(
  preferencesSource,
  /getLibraryUpdateNextDueAt\(preferences: LibraryUpdatePreferences\): number \| undefined[\s\S]*const intervalMs = preferences\.intervalHours \* 60 \* 60 \* 1000[\s\S]*const backoffMs = getLibraryUpdateBackoffHours\(preferences\) \* 60 \* 60 \* 1000[\s\S]*return preferences\.lastCheckedAt \+ intervalMs \+ backoffMs/,
  'Next due time must be deterministic from lastCheckedAt, intervalHours, and failure backoff',
)
assert.match(
  preferencesSource,
  /getLibraryUpdateBackoffHours\(preferences: LibraryUpdatePreferences\): number[\s\S]*Math\.pow\(2, failureCount - 1\)[\s\S]*LIBRARY_UPDATE_MAX_BACKOFF_HOURS/,
  'Failure backoff must be deterministic and capped',
)
assert.match(
  preferencesSource,
  /load\(\): Promise<LibraryUpdatePreferences>[\s\S]*LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY[\s\S]*LIBRARY_UPDATE_INTERVAL_HOURS_KEY[\s\S]*LIBRARY_UPDATE_FOREGROUND_ONLY_KEY[\s\S]*LIBRARY_UPDATE_LAST_CHECKED_AT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_TOTAL_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_NEW_CHAPTER_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_UPDATED_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_SKIPPED_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_FAILED_COUNT_KEY[\s\S]*LIBRARY_UPDATE_FAILURE_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_FAILURE_CODE_KEY/,
  'Settings persistence load must roundtrip every schedule field',
)
assert.match(
  preferencesSource,
  /save\(libraryUpdatePreferences: LibraryUpdatePreferences\): Promise<void>[\s\S]*LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY[\s\S]*LIBRARY_UPDATE_INTERVAL_HOURS_KEY[\s\S]*LIBRARY_UPDATE_FOREGROUND_ONLY_KEY[\s\S]*LIBRARY_UPDATE_LAST_CHECKED_AT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_TOTAL_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_NEW_CHAPTER_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_UPDATED_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_SKIPPED_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_SUMMARY_FAILED_COUNT_KEY[\s\S]*LIBRARY_UPDATE_FAILURE_COUNT_KEY[\s\S]*LIBRARY_UPDATE_LAST_FAILURE_CODE_KEY[\s\S]*store\.flush\(\)/,
  'Settings persistence save must flush every schedule field',
)
assert.match(
  settingsPageSource,
  /getLibraryUpdateNextDueLabel\(this\.libraryUpdatePreferences\)/,
  'Settings rows must surface the next foreground due time when auto-check is enabled',
)
assert.match(
  settingsPageSource,
  /catch\(\(error: Error\) => \{[\s\S]*step=library_update_failed[\s\S]*this\.libraryUpdateSummary = undefined[\s\S]*this\.libraryUpdatePreferences = \{[\s\S]*lastCheckedAt: checkedAt[\s\S]*failureCount: normalizeLibraryUpdateFailureCount\(this\.libraryUpdatePreferences\.failureCount \+ 1\)[\s\S]*lastFailureCode: failureCode[\s\S]*saveFailedCheck\(checkedAt, failureCode\)/,
  'Failed checks must clear the in-memory success summary and update failure prefs before async persistence completes',
)
assert.doesNotMatch(
  settingsPageSource,
  /catch\(\(error: Error\) => \{[\s\S]*step=library_update_failed[\s\S]*this\.libraryUpdatePreferences = \{[\s\S]*lastSummaryText[\s\S]*saveFailedCheck\(checkedAt, failureCode\)/,
  'Failed checks must not carry forward stale in-memory success summary text',
)
assert.match(
  resultPageSource,
  /SummaryMetric\(s\('library_update_results_metric_total'\), summary\.totalCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_updated'\), summary\.updatedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_unchanged'\), summary\.unchangedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_skipped'\), summary\.skippedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_failed'\), summary\.failedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_new_chapters'\), countLibraryUpdateNewChapters\(summary\)\)/,
  'Library update details must show all aggregate counts including new chapters',
)

assert.match(
  resultStoreSource,
  /store\.put\(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, serializeLibraryUpdateSummary\(summary\)\)[\s\S]*store\.flush\(\)/,
  'Existing update result persistence must continue to write and flush the latest sanitized JSON',
)
assert.match(
  resultStoreSource,
  /export type LibraryUpdateJobState = 'due' \| 'running' \| 'success' \| 'failed' \| 'backed-off'/,
  'Library update job snapshots must expose the D36 state machine states',
)
assert.match(
  resultStoreSource,
  /LIBRARY_UPDATE_LATEST_JOB_JSON_KEY[\s\S]*serializeLibraryUpdateJobSnapshot[\s\S]*hydrateLibraryUpdateJobSnapshotFromJson/,
  'Library update job snapshots must have durable serialization and hydration',
)
assert.match(
  resultStoreSource,
  /clearLatestLibraryUpdateSummary\(\): void \{[\s\S]*latestLibraryUpdateSummary = undefined[\s\S]*saveJobSnapshot\(snapshot: LibraryUpdateJobSnapshot\)[\s\S]*snapshot\.state === 'failed' \|\| snapshot\.state === 'backed-off'[\s\S]*store\.put\(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, ''\)/,
  'Failed or backed-off job snapshots must clear the persisted latest success while preserving the job snapshot',
)
assert.match(
  resultStoreSource,
  /persistLibraryUpdateProviderSummary\(summary: LibraryUpdateProviderSummary\)[\s\S]*redactLibraryUpdateFailureCode\(code\)[\s\S]*sourceKey: normalizeSourceKey\(summary\.sourceKey\)/,
  'Provider summaries must persist only redacted failure codes and safe source keys',
)
assert.match(
  resultStoreSource,
  /normalizeSourceKey\(value: string \| undefined\): string[\s\S]*\/\^\(source:\[a-z0-9\]\+\|local\|komga\|opds\|webdav\|private_library\|unsupported\)\$\/[\s\S]*return 'source:unknown'/,
  'Persisted source keys must be allowlisted and fail closed',
)
assert.match(
  resultStoreSource,
  /redactLibraryUpdateFailureCode\(value: string \| undefined\): string[\s\S]*return 'timeout'[\s\S]*return 'storage_error'[\s\S]*return 'auth_error'[\s\S]*return 'network_error'[\s\S]*return 'source_runtime_error'[\s\S]*return clampString\('unknown', 64\)/,
  'Notification-facing failure codes must use only coarse allowlisted buckets',
)
assert.match(
  settingsPageSource,
  /safeSettingsErrorCode\(error: Error\): string \{[\s\S]*return normalizeLibraryUpdateFailureCode\(error\.name\) \?\? 'unknown'[\s\S]*\}/,
  'Settings update failure logs must bucket exception names through the allowlisted failure-code normalizer',
)
assert.doesNotMatch(
  settingsPageSource,
  /safeSettingsErrorCode\(error: Error\): string \{[\s\S]*error\.name\.trim\(\)\.toLocaleLowerCase\(\)[\s\S]*replace\(\/\[\^a-z0-9_\.-\]\/g,[\s\S]*substring\(0, 48\)[\s\S]*\}/,
  'Settings update failure logs must not sanitize-and-emit raw exception names',
)
assert.match(
  preferencesSource,
  /saveFailedCheck\(checkedAt: number, failureCode: string\): Promise<LibraryUpdatePreferences>[\s\S]*lastFailureCode: normalizeLibraryUpdateFailureCode\(failureCode\) \?\? 'unknown'[\s\S]*await this\.save\(next\)/,
  'Failed checks must persist a coarse failure code without carrying forward stale success summaries',
)
assert.doesNotMatch(
  preferencesSource,
  /saveFailedCheck\(checkedAt: number, failureCode: string\): Promise<LibraryUpdatePreferences>[\s\S]*next\.lastSummaryText = current\.lastSummaryText[\s\S]*await this\.save\(next\)/,
  'Failed checks must clear stale success summaries before Settings renders the last result',
)
assert.match(
  preferencesSource,
  /getLibraryUpdateLastResultLabel\(preferences: LibraryUpdatePreferences\): string \{[\s\S]*normalizeLibraryUpdateFailureCount\(preferences\.failureCount\) > 0[\s\S]*library_update_last_failed[\s\S]*formatLibraryUpdateStoredSummary\(preferences\)/,
  'Settings last result label must prioritize an active failure over older success summary counts',
)
assert.match(
  resultStoreSource,
  /createLibraryUpdateNotificationSummary\(summary: LibraryUpdateSummary\): LibraryUpdateNotificationSummary[\s\S]*countLibraryUpdateNewChapters\(summary\)[\s\S]*systemDispatchEnabled: isLibraryUpdateNotificationDeliveryEnabled\(\)/,
  'Notification summary must expose counts and the real system dispatch capability',
)
assert.match(
  resultStoreSource,
  /import \{ notificationManager \} from '@kit\.NotificationKit'[\s\S]*publishLibraryUpdateNotification\(summary: LibraryUpdateSummary\)[\s\S]*newChapterCount <= 0 && notificationSummary\.failedCount <= 0[\s\S]*notificationManager\.isNotificationEnabled\(\)[\s\S]*wantAgent: await createLibraryUpdateResultWantAgent\(\)[\s\S]*notificationManager\.ContentType\.NOTIFICATION_CONTENT_BASIC_TEXT[\s\S]*notificationManager\.publish\(request\)/,
  'Library update notifications must use NotificationKit, skip boring checks, attach a detail-route WantAgent, and publish a basic system notification',
)
assert.match(
  resultStoreSource,
  /getLibraryUpdateNotificationStatus\(\): Promise<LibraryUpdateNotificationStatus>[\s\S]*notificationManager\.isNotificationEnabled\(\)[\s\S]*requestLibraryUpdateNotificationPermission\(context: common\.UIAbilityContext\): Promise<LibraryUpdateNotificationStatus>[\s\S]*notificationManager\.requestEnableNotification\(context\)[\s\S]*return getLibraryUpdateNotificationStatus\(\)/,
  'Library update notifications must expose real permission status and a UI-bound permission request helper',
)
assert.match(
  constantsSource,
  /KOMA_LAUNCH_ROUTE_PARAM[\s\S]*KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS/,
  'Notification route parameters must use shared constants',
)
assert.match(
  resultStoreSource,
  /createLibraryUpdateResultWantAgent\(\): Promise<WantAgent>[\s\S]*parameters\[KOMA_LAUNCH_ROUTE_PARAM\] = KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS[\s\S]*bundleName: KOMA_BUNDLE_NAME[\s\S]*abilityName: 'EntryAbility'[\s\S]*parameters,[\s\S]*wantAgent\.getWantAgent\(\{[\s\S]*wants: \[launchWant\][\s\S]*actionType: wantAgent\.OperationType\.START_ABILITY[\s\S]*UPDATE_PRESENT_FLAG/,
  'Notification tap action must launch Koma back into the library update result route',
)
assert.match(
  entryAbilitySource,
  /openLaunchRouteFromWant\(want\)[\s\S]*KOMA_LAUNCH_ROUTE_PARAM[\s\S]*KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS[\s\S]*RouterHelper\.pushLibraryUpdateResults\(\)/,
  'EntryAbility must route notification launch wants to update results',
)
assert.match(
  routerHelperSource + indexSource,
  /pendingLaunchRoute[\s\S]*consumePendingLaunchRoute\(\)[\s\S]*pushLibraryUpdateResults\(\)[\s\S]*RouterHelper\.consumePendingLaunchRoute\(\)/,
  'Notification launch routing must survive app cold start before the NavPathStack exists',
)
assert.match(
  settingsPageSource,
  /publishLibraryUpdateNotification\(summary\)[\s\S]*step=library_update_notification[\s\S]*publishLibraryUpdateFailureNotification\(checkedAt, failureCode\)/,
  'Settings checks must dispatch notifications for new update summaries and failed checks',
)
assert.match(
  settingsPageSource,
  /library-update-notifications[\s\S]*getLibraryUpdateNotificationStatusLabel\(this\.libraryUpdateNotificationStatus\)[\s\S]*loadLibraryUpdateNotificationStatus\(\): void[\s\S]*getLibraryUpdateNotificationStatus\(\)[\s\S]*requestLibraryUpdateNotifications\(\): void[\s\S]*requestLibraryUpdateNotificationPermission\(this\.context\(\)\)/,
  'Settings must show and refresh the real system notification permission state',
)
assert.match(
  settingsPageSource,
  /handleLibraryUpdateNotificationDispatch\(result: LibraryUpdateNotificationDispatchResult, reason: string\)[\s\S]*result\.code === 'disabled'[\s\S]*settings_library_update_notification_disabled[\s\S]*result\.code === 'publish_failed'[\s\S]*settings_library_update_notification_failed/,
  'Manual update checks must fail closed and tell the user when system notifications were not delivered',
)
assert.match(
  resultStoreSource,
  /hydrateLibraryUpdateSummaryFromJson\(jsonText: string\)[\s\S]*JSON\.parse\(jsonText\)[\s\S]*aggregateCountField\(record, 'totalCount', resultTotalCount\)/,
  'Existing update result persistence must continue to hydrate aggregate counts deterministically',
)
assert.match(
  settingsPageSource,
  /createLibraryUpdateJobSnapshot\('running'[\s\S]*saveJobSnapshot\(runningSnapshot\)[\s\S]*createLibraryUpdateJobSnapshot\('success'[\s\S]*failedState = nextDueAt !== undefined && nextDueAt > checkedAt \? 'backed-off' : 'failed'[\s\S]*saveJobSnapshot\(failedSnapshot\)/,
  'Settings foreground checks must persist running, success, failed, and backed-off job states',
)
assert.match(
  settingsPageSource,
  /runDueLibraryUpdateCheck\(\): void \{[\s\S]*isLibraryUpdateDue\(this\.libraryUpdatePreferences, Date\.now\(\)\)[\s\S]*createLibraryUpdateJobSnapshot\('due'[\s\S]*saveJobSnapshot\(dueSnapshot\)[\s\S]*this\.checkLibraryUpdates\('due'\)/,
  'Due checks must durably persist a due snapshot before transitioning to running',
)
assert.match(
  settingsPageSource,
  /step=library_update_failed[\s\S]*this\.libraryUpdateSummary = undefined[\s\S]*clearLatestLibraryUpdateSummary\(\)[\s\S]*saveJobSnapshot\(failedSnapshot\)/,
  'Settings must not leave an in-memory latest success available for navigation after a newer failure',
)
assert.match(
  resultPageSource,
  /getLatestLibraryUpdateJobSnapshot\(\)[\s\S]*effectiveSummaryForJob\(getLatestLibraryUpdateSummary\(\), latestJob\)[\s\S]*loadJobSnapshot\(\)[\s\S]*isSummaryBlockedByJob\(this\.summary, effectiveJob\)[\s\S]*clearLatestLibraryUpdateSummary\(\)/,
  'LibraryUpdateResultPage must not display a persisted latest success when a newer failed/backed-off job snapshot exists',
)
assert.match(
  resultPageSource,
  /emptyStateTitle\(\): string[\s\S]*library_update_results_empty_backed_off[\s\S]*library_update_results_empty_failed[\s\S]*emptyStateMessage\(\): string[\s\S]*library_update_results_failure_next_due[\s\S]*library_update_results_failure_last/,
  'LibraryUpdateResultPage must show an honest failure/backoff detail state instead of stale success',
)

function getLibraryUpdateBackoffHours(preferences) {
  const failureCount = Number.isFinite(preferences.failureCount) && preferences.failureCount > 0
    ? Math.min(Math.floor(preferences.failureCount), 12)
    : 0
  if (failureCount <= 0) return 0
  return Math.min(Math.pow(2, failureCount - 1), 24)
}

function getLibraryUpdateNextDueAt(preferences) {
  if (!preferences.autoCheckEnabled) return undefined
  if (preferences.lastCheckedAt === undefined) return 0
  return preferences.lastCheckedAt + preferences.intervalHours * 60 * 60 * 1000 + getLibraryUpdateBackoffHours(preferences) * 60 * 60 * 1000
}

function isLibraryUpdateDue(preferences, now) {
  if (!preferences.autoCheckEnabled) return false
  if (preferences.lastCheckedAt === undefined) return true
  const nextDueAt = getLibraryUpdateNextDueAt(preferences)
  return nextDueAt !== undefined && nextDueAt > 0 && now >= nextDueAt
}

function redactLibraryUpdateFailureCode(value) {
  if (value === undefined) return 'unknown'
  const trimmed = value.trim().toLocaleLowerCase()
  if (trimmed.length === 0) return 'unknown'
  if (/timeout|timed\s*out|deadline|etimedout/.test(trimmed)) return 'timeout'
  if (/storage|database|disk|quota|file|cache|path|directory|(^|\s)\/[^\s]+|(^|\s)[a-z]:[\\/]|enoent|eacces/.test(trimmed)) return 'storage_error'
  if (/auth|unauthori[sz]ed|forbidden|permission|login|credential|tok(?:en)?|api[_\s-]?key|secret|401|403/.test(trimmed)) return 'auth_error'
  if (/network|fetch|http|https|dns|socket|connection|econn|enotfound|eai_again|ssl|tls|remote/.test(trimmed)) return 'network_error'
  if (/source|runtime|wasm|provider|plugin|script|exception|unavailable/.test(trimmed)) return 'source_runtime_error'
  return 'unknown'
}

function getLibraryUpdateLastResultLabel(preferences) {
  if (preferences.lastFailureCode !== undefined && preferences.lastCheckedAt !== undefined && preferences.failureCount > 0) {
    return `上次检查失败 · ${preferences.lastFailureCode}`
  }
  if (preferences.lastSummaryTotalCount !== undefined && preferences.lastCheckedAt !== undefined) {
    return `${preferences.lastSummaryTotalCount} 总计 · ${preferences.lastSummaryNewChapterCount} 新章 · ${preferences.lastSummaryUpdatedCount} 更新 · ${preferences.lastSummarySkippedCount} 跳过 · ${preferences.lastSummaryFailedCount} 失败 · 上次`
  }
  return '尚无结果'
}

const checkedAt = Date.UTC(2026, 4, 26, 0, 0, 0)
assert.equal(getLibraryUpdateNextDueAt({ autoCheckEnabled: true, intervalHours: 24, foregroundOnly: true, lastCheckedAt: checkedAt, failureCount: 0 }), checkedAt + 24 * 60 * 60 * 1000, 'next due timestamp must come from interval')
assert.equal(getLibraryUpdateNextDueAt({ autoCheckEnabled: false, intervalHours: 24, foregroundOnly: true, lastCheckedAt: checkedAt, failureCount: 0 }), undefined, 'disabled state must never produce a due timestamp')
assert.equal(isLibraryUpdateDue({ autoCheckEnabled: false, intervalHours: 24, foregroundOnly: true, lastCheckedAt: checkedAt, failureCount: 0 }, checkedAt + 99 * 60 * 60 * 1000), false, 'disabled state must never be due')
assert.equal(getLibraryUpdateNextDueAt({ autoCheckEnabled: true, intervalHours: 24, foregroundOnly: true, lastCheckedAt: checkedAt, failureCount: 3 }), checkedAt + 28 * 60 * 60 * 1000, 'failure backoff must advance next due')
const failureCodeCases = [
  ['Provider MangaDex token sk_live_123 failed', 'auth_error'],
  ['GET https://example.test/a?token=secret failed', 'auth_error'],
  ['open /data/storage/el2/base/cache/file failed', 'storage_error'],
  ['C:\\Users\\reader\\secret.cbz failed', 'storage_error'],
  ['fetch failed: ENOTFOUND manga.example', 'network_error'],
  ['source runtime threw ProviderException MangaDex', 'source_runtime_error'],
]
for (const [raw, expected] of failureCodeCases) {
  const redacted = redactLibraryUpdateFailureCode(raw)
  assert.equal(redacted, expected, `failure code should map ${raw} to ${expected}`)
  assert.equal(/mangadex|sk_live|secret|https?:|example\.test|\/data\/storage|users|providerexception/i.test(redacted), false, 'failure code must not preserve sensitive raw words')
}
const settingsExceptionNameCases = [
  ['ProviderException', 'source_runtime_error'],
  ['TokenExpiredError', 'auth_error'],
  ['SecretPathUriException', 'storage_error'],
]
for (const [rawName, expected] of settingsExceptionNameCases) {
  const code = redactLibraryUpdateFailureCode(rawName)
  assert.equal(code, expected, `settings error code should bucket ${rawName} to ${expected}`)
  assert.equal(/providerexception|tokenexpirederror|secretpathuriexception|provider|token|secret|path|uri/i.test(code), false, 'settings error code must not preserve raw provider/token/secret/path/uri exception words')
}
const failedLabel = getLibraryUpdateLastResultLabel({
  autoCheckEnabled: true,
  intervalHours: 24,
  foregroundOnly: true,
  lastCheckedAt: checkedAt,
  lastSummaryTotalCount: 12,
  lastSummaryNewChapterCount: 12,
  lastSummaryUpdatedCount: 3,
  lastSummarySkippedCount: 0,
  lastSummaryFailedCount: 0,
  failureCount: 1,
  lastFailureCode: 'network_error',
})
assert.match(failedLabel, /上次检查失败 · network_error/, 'Settings must show failure status after a failed check')
assert.equal(failedLabel.includes('12 新章'), false, 'Settings must not show a stale success summary after a failed check')

console.log('Library update notification UX static checks passed')
