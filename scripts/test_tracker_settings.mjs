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
  /安全存储未验证，追踪账号连接暂不可用/,
  'TrackerSettingsPage must surface secure storage unavailability',
)
assert.match(
  trackerPageSource,
  /getTrackerAccountStatusLabel/,
  'TrackerSettingsPage must use truthful status labels from the model',
)
assert.match(
  trackerPageSource,
  /\.enabled\(this\.canPrepareConnect\(provider\)\)/,
  'connect action must be disabled unless config and secure storage are available',
)
assert.doesNotMatch(
  trackerPageSource,
  /TextInput\(|InputType\.Password|已连接.*Button|connected:\s*true/,
  'TrackerSettingsPage must not collect secrets or fake connected state',
)

console.log('tracker settings checks PASS')
