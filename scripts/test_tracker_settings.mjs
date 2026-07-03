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

function sourceSlice(source, startNeedle, endNeedle) {
  const start = source.indexOf(startNeedle)
  assert.notEqual(start, -1, `${startNeedle} must exist`)
  const end = source.indexOf(endNeedle, start + startNeedle.length)
  return end === -1 ? source.slice(start) : source.slice(start, end)
}

const trackerAccountDetailBlock = sourceSlice(
  trackerModelsSource,
  'export function getTrackerAccountDetail',
  'export function normalizeTrackerAccountStatus',
)
const trackerAuthPrepareStatusLabelBlock = sourceSlice(
  trackerPageSource,
  'private authPrepareStatusKey',
  'private showToast',
)

assert.match(
  trackerModelsSource,
  /export type TrackerAccountStatus = 'disconnected' \| 'auth_pending' \| 'connected' \| 'expired' \| 'error'/,
  'tracker model must expose honest account states',
)
assert.match(
  trackerModelsSource,
  /export interface TrackerAccount \{[\s\S]*providerId: TrackerProviderId[\s\S]*status: TrackerAccountStatus[\s\S]*profile\?: TrackerPublicProfile[\s\S]*credentialAccountKey\?: string/,
  'tracker account model must keep profile metadata separate from credential refs',
)
assert.match(
  trackerModelsSource,
  /export interface TrackerCredentialSecretStore \{[\s\S]*isAvailable\(\): boolean[\s\S]*writeToken\(request: TrackerCredentialWriteRequest\): Promise<TrackerCredentialStoreResult>[\s\S]*readToken\(ref: TrackerCredentialSecretRef\): Promise<Uint8Array \| undefined>/,
  'tracker model must define a narrow secure-token boundary',
)
assert.match(
  trackerModelsSource,
  /class UnavailableTrackerCredentialSecretStore[\s\S]*isAvailable\(\): boolean \{[\s\S]*return false[\s\S]*writeToken[\s\S]*storage_unavailable/,
  'default tracker credential store must fail closed',
)
assert.match(
  trackerModelsSource,
  /status === 'connected' && \(!secureStorageAvailable \|\| credentialAccountKey === undefined\)[\s\S]*next\.status = 'error'[\s\S]*secure_storage_unavailable/,
  'connected tracker accounts must be rejected when secure storage is unavailable',
)
assert.match(
  trackerAccountDetailBlock,
  /status === 'error'[\s\S]*return getTrackerAccountErrorDetail\(account\.statusReason\)/,
  'account detail helper must map error reasons through user-facing copy',
)
assert.doesNotMatch(
  trackerAccountDetailBlock,
  /return account\.statusReason|return reason/,
  'account detail helper must not expose raw internal status reasons',
)
assert.match(
  trackerAccountDetailBlock,
  /tracker_detail_account_status_unavailable[\s\S]*tracker_detail_connect_unavailable[\s\S]*tracker_detail_connect_failed/,
  'account detail helper must route error reasons through generic localized copy',
)
assert.match(
  trackerModelsSource,
  /parseTrackerOAuthCallback\(callbackUri: string, expectedState: string\)[\s\S]*codePresent: code !== undefined[\s\S]*reason: 'state_mismatch'/,
  'OAuth callback parser must reject state mismatch without returning the raw code',
)
assert.doesNotMatch(
  trackerModelsSource,
  /clientSecret|client_secret|accessToken|refreshToken|rawToken|authCode|authorizationCode|bearer/i,
  'tracker models must not add raw OAuth material fields',
)
assert.match(
  trackerModelsSource,
  /displayName: 'AniList'/,
  'tracker providers must include AniList',
)
assert.match(
  trackerModelsSource,
  /displayName: 'MyAnimeList'/,
  'tracker providers must include MyAnimeList',
)
assert.match(trackerModelsSource, /displayName: 'Kitsu'/, 'tracker providers should include Kitsu')
assert.match(trackerModelsSource, /displayName: 'MangaUpdates'/, 'tracker providers should include MangaUpdates')
assert.match(trackerModelsSource, /displayName: 'Bangumi'/, 'tracker providers should include Bangumi')

assert.match(
  settingsPageSource,
  /key: 'trackers', titleKey: 'settings_row_trackers_title', detailKey: 'settings_row_trackers_detail'/,
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
  /name === RouteName\.TRACKER_SETTINGS[\s\S]*HdsNavDestination\(\)[\s\S]*TrackerSettingsPage\(\)[\s\S]*\.titleBar\(this\.navDestTitleBarOpts\(AppStrings\.get\('route_tracker_settings_title'\)\)\)/,
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
  /tracker_message_secure_storage_unverified/,
  'TrackerSettingsPage must surface secure storage unavailability',
)
assert.match(
  trackerPageSource,
  /tracker_message_connect_unavailable/,
  'TrackerSettingsPage must use user-facing unavailable text for auth preparation failures',
)
assert.match(
  trackerPageSource,
  /tracker_message_auth_unavailable/,
  'TrackerSettingsPage must use user-facing unavailable text for incomplete auth setup',
)
assert.doesNotMatch(
  trackerAuthPrepareStatusLabelBlock,
  /PKCE|Provider 配置|secure_storage_unavailable'[\s\S]*return 'secure_storage_unavailable|provider_config_missing'[\s\S]*return 'provider_config_missing|pkce_unavailable'[\s\S]*return 'pkce_unavailable/,
  'TrackerSettingsPage must not expose OAuth implementation terms or raw reason codes in auth prompts',
)
assert.match(
  trackerPageSource,
  /getTrackerAccountStatusLabel/,
  'TrackerSettingsPage must use truthful status labels from the model',
)
assert.match(
  trackerPageSource,
  /isEnabled: this\.canPrepareConnect\(provider\)/,
  'connect action must be disabled unless config and secure storage are available',
)
assert.match(
  trackerPageSource,
  /ConciseListRow\(\{[\s\S]*title: provider\.displayName[\s\S]*subtitle: getTrackerAccountDetail/,
  'provider rows must use the shared HDS-backed list row component',
)
assert.match(
  trackerPageSource,
  /summarizeComicTrackerMappings\(preferences\.comicMappings\)/,
  'TrackerSettingsPage must surface tracker mapping state loaded from preferences',
)
assert.match(
  trackerPageSource,
  /tracker_mapping_title/,
  'TrackerSettingsPage must title the comic mapping summary section',
)
assert.match(
  trackerPageSource,
  /tracker_mapping_message/,
  'TrackerSettingsPage must describe the comic mapping summary honestly',
)
assert.match(
  trackerPageSource,
  /tracker_mapping_progress/,
  'TrackerSettingsPage must include the comic mapping summary section',
)
assert.doesNotMatch(
  trackerPageSource,
  /TextInput\(|InputType\.Password|已连接.*Button|connected:\s*true/,
  'TrackerSettingsPage must not collect secrets or fake connected state',
)

console.log('tracker settings checks PASS')
