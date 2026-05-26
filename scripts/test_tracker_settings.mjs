import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const trackerModelsPath = resolve(root, 'entry/src/main/ets/model/TrackerModels.ets')
const trackerPagePath = resolve(root, 'entry/src/main/ets/pages/TrackerSettingsPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const constantsPath = resolve(root, 'entry/src/main/ets/common/Constants.ets')

const trackerModelsSource = readFileSync(trackerModelsPath, 'utf8')
const trackerPageSource = readFileSync(trackerPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const constantsSource = readFileSync(constantsPath, 'utf8')

assert.match(
  trackerModelsSource,
  /export type TrackerConnectionStatus = 'not_configured' \| 'planned' \| 'disabled'/,
  'tracker model must expose only safe local placeholder statuses',
)
assert.match(
  trackerModelsSource,
  /export interface TrackerProviderConnection \{[\s\S]*providerId: TrackerProviderId[\s\S]*displayName: string[\s\S]*status: TrackerConnectionStatus[\s\S]*\}/,
  'tracker connection model must include provider id, display name, and status',
)
assert.match(
  trackerModelsSource,
  /export interface ComicTrackerMapping \{[\s\S]*comicId: ComicId[\s\S]*providerId: TrackerProviderId[\s\S]*externalSeriesId: string/,
  'tracker model should reserve a per-comic mapping shape',
)
assert.match(trackerModelsSource, /displayName: 'AniList'/, 'tracker providers must include AniList')
assert.match(trackerModelsSource, /displayName: 'MyAnimeList'/, 'tracker providers must include MyAnimeList')
assert.match(trackerModelsSource, /displayName: 'Kitsu'/, 'tracker providers should include Kitsu')
assert.match(trackerModelsSource, /displayName: 'MangaUpdates'/, 'tracker providers should include MangaUpdates')
assert.match(trackerModelsSource, /displayName: 'Bangumi'/, 'tracker providers should include Bangumi')

assert.match(
  settingsPageSource,
  /key: 'trackers', title: '追踪账号'/,
  'Settings must expose a tracker management row',
)
assert.match(
  settingsPageSource,
  /onOpenTrackerSettings:\s*\(\) => void/,
  'SettingsPage must accept a tracker route callback',
)
assert.match(
  settingsPageSource,
  /row\.key === 'trackers'[\s\S]*this\.onOpenTrackerSettings\(\)/,
  'Settings tracker row must open the tracker settings page',
)
assert.match(
  constantsSource,
  /static readonly TRACKER_SETTINGS: string = 'TrackerSettingsPage'/,
  'RouteName must include TrackerSettingsPage',
)
assert.match(
  indexSource,
  /import \{ TrackerSettingsPage \} from '\.\/TrackerSettingsPage'/,
  'Index must import TrackerSettingsPage',
)
assert.match(
  indexSource,
  /name === RouteName\.TRACKER_SETTINGS[\s\S]*HdsNavDestination\(\)[\s\S]*TrackerSettingsPage\(\)[\s\S]*\.titleBar\(this\.navDestTitleBarOpts\('追踪账号'\)\)/,
  'Index must render tracker settings as a top-level HDS destination',
)
assert.match(
  indexSource,
  /onOpenTrackerSettings:\s*\(\) => \{[\s\S]*this\.openSettingsSecondary\(RouteName\.TRACKER_SETTINGS\)/,
  'Index must wire Settings tracker callback through the secondary route helper',
)
assert.match(
  trackerPageSource,
  /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20 \+ ThemeConstants\.SPACE_XL/,
  'TrackerSettingsPage must use the safe secondary page scaffold',
)
assert.doesNotMatch(
  trackerPageSource,
  /(Navigation|NavDestination)\(/,
  'TrackerSettingsPage must not nest a Navigation/NavDestination inside Settings',
)
assert.match(
  trackerPageSource,
  /公共追踪账号同步尚未接入/,
  'TrackerSettingsPage must clearly say public tracker account sync is not connected yet',
)
assert.match(
  trackerPageSource,
  /不会要求登录，也不会保存账号授权数据/,
  'TrackerSettingsPage must avoid collecting account authorization data in this lane',
)
assert.match(
  trackerPageSource,
  /账号未连接/,
  'TrackerSettingsPage must present providers as not connected placeholders',
)

const trackerLaneSource = [
  trackerModelsSource,
  trackerPageSource,
  settingsPageSource.match(/key: 'trackers'[\s\S]*?\}/)?.[0] ?? '',
  indexSource.match(/RouteName\.TRACKER_SETTINGS[\s\S]*?titleBar/)?.[0] ?? '',
].join('\n')

assert.doesNotMatch(
  trackerLaneSource,
  /\b(token|secret|password|passwd|credential|authorization|apiKey|api_key|accessKey|refreshKey)\b/i,
  'tracker skeleton must not introduce credential-like fields or labels',
)
assert.doesNotMatch(
  trackerLaneSource,
  /\b(fetch|http\.request|POST|PUT|PATCH|DELETE|upload|remoteWrite|syncNow|syncEnabled|connected:\s*true)\b/,
  'tracker skeleton must not introduce public network write/sync behavior or connected claims',
)

console.log('tracker settings checks PASS')
