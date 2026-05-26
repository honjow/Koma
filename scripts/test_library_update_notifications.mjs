import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const settingsPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets'), 'utf8')
const resultPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/LibraryUpdateResultPage.ets'), 'utf8')
const serviceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets'), 'utf8')
const preferencesSource = readFileSync(resolve(root, 'entry/src/main/ets/model/LibraryUpdatePreferencesStore.ets'), 'utf8')
const resultStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/LibraryUpdateResultStore.ets'), 'utf8')
const moduleSource = readFileSync(resolve(root, 'entry/src/main/module.json5'), 'utf8')

assert.doesNotMatch(
  moduleSource,
  /ohos\.permission\.NOTIFICATION|NOTIFICATION_CONTROLLER|PUBLISH_AGENT_REMINDER/i,
  'D9 must not request notification/reminder permissions without a delivery implementation and device QA',
)

assert.doesNotMatch(
  settingsPageSource + serviceSource + preferencesSource,
  /background\s*scheduler|后台自动更新|系统通知|通知权限|notificationManager|publishBasicNotification|requestEnableNotification|reminderAgentManager/i,
  'Foreground library update UX must not claim a background scheduler or notification delivery',
)

assert.match(
  preferencesSource,
  /export const LIBRARY_UPDATE_NOTIFICATION_STATUS: LibraryUpdateNotificationStatus = 'planned'/,
  'Notification preference must be a planned skeleton until real delivery exists',
)
assert.match(
  preferencesSource,
  /getLibraryUpdateNotificationStatusLabel[\s\S]*return '计划中 · 暂不发送'/,
  'Notification preference label must be honest about non-delivery',
)
assert.match(
  preferencesSource,
  /isLibraryUpdateNotificationDeliveryEnabled[\s\S]*status === 'planned'[\s\S]*return false[\s\S]*status === 'unavailable'[\s\S]*return false[\s\S]*return false/,
  'Notification helper must never fake enabled delivery',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-update-notifications', title: '更新提醒', detail: '计划中 · 暂不发送' \}/,
  'Settings must expose the update reminder skeleton row',
)
assert.match(
  settingsPageSource,
  /showInfoDialog\('更新提醒', '当前版本只保存前台检查结果，不会发送提醒。真正可投递的提醒会在权限、实现和设备验证齐备后再开放。'\)/,
  'Settings reminder dialog must explain that delivery is unavailable in this lane',
)

assert.match(
  serviceSource,
  /countLibraryUpdateNewChapters\(summary: LibraryUpdateSummary\)[\s\S]*result\.status !== 'updated'[\s\S]*Math\.max\(result\.newChapterCount - result\.previousChapterCount, 0\)/,
  'New chapter count must be derived deterministically from persisted per-comic result counts',
)
assert.match(
  serviceSource,
  /return `\$\{summary\.totalCount\} 本 · \$\{countLibraryUpdateNewChapters\(summary\)\} 新章 · \$\{summary\.updatedCount\} 更新 · \$\{summary\.skippedCount\} 跳过 · \$\{summary\.failedCount\} 失败`/,
  'Summary formatting must include new, updated, skipped, and failed counts in a stable order',
)
assert.match(
  preferencesSource,
  /formatLibraryUpdateTimestamp\(value: number\)[\s\S]*padStart\(2, '0'\)[\s\S]*return `\$\{year\}-\$\{month\}-\$\{day\} \$\{hour\}:\$\{minute\}`/,
  'Timestamp formatting must be deterministic and not depend on locale formatting APIs',
)
assert.match(
  preferencesSource,
  /getLibraryUpdateNextDueAt\(preferences: LibraryUpdatePreferences\): number \| undefined[\s\S]*lastCheckedAt \+ preferences\.intervalHours \* 60 \* 60 \* 1000/,
  'Next due time must be deterministic from lastCheckedAt and intervalHours',
)
assert.match(
  settingsPageSource,
  /getLibraryUpdateNextDueLabel\(this\.libraryUpdatePreferences\)/,
  'Settings rows must surface the next foreground due time when auto-check is enabled',
)
assert.match(
  resultPageSource,
  /SummaryMetric\('总计', summary\.totalCount\)[\s\S]*SummaryMetric\('更新', summary\.updatedCount\)[\s\S]*SummaryMetric\('未变化', summary\.unchangedCount\)[\s\S]*SummaryMetric\('跳过', summary\.skippedCount\)[\s\S]*SummaryMetric\('失败', summary\.failedCount\)[\s\S]*SummaryMetric\('新章', countLibraryUpdateNewChapters\(summary\)\)/,
  'Library update details must show all aggregate counts including new chapters',
)

assert.match(
  resultStoreSource,
  /store\.put\(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, serializeLibraryUpdateSummary\(summary\)\)[\s\S]*store\.flush\(\)/,
  'Existing update result persistence must continue to write and flush the latest sanitized JSON',
)
assert.match(
  resultStoreSource,
  /hydrateLibraryUpdateSummaryFromJson\(jsonText: string\)[\s\S]*JSON\.parse\(jsonText\)[\s\S]*aggregateCountField\(record, 'totalCount', resultTotalCount\)/,
  'Existing update result persistence must continue to hydrate aggregate counts deterministically',
)

console.log('Library update notification UX static checks passed')
