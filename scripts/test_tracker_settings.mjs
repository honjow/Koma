import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const trackerModelsPath = resolve(root, 'entry/src/main/ets/model/TrackerModels.ets')
const trackerPagePath = resolve(root, 'entry/src/main/ets/pages/TrackerSettingsPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const constantsPath = resolve(root, 'entry/src/main/ets/common/Constants.ets')
const localeStringPaths = [
  resolve(root, 'entry/src/main/resources/base/element/string.json'),
  resolve(root, 'entry/src/main/resources/en_US/element/string.json'),
  resolve(root, 'entry/src/main/resources/zh_CN/element/string.json'),
]

const trackerModelsSource = readFileSync(trackerModelsPath, 'utf8')
const trackerPageSource = readFileSync(trackerPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const constantsSource = readFileSync(constantsPath, 'utf8')
const localeStringSources = localeStringPaths.map((path) => readFileSync(path, 'utf8'))

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
  /export interface TrackerProviderOAuthConfig \{[\s\S]*providerId: TrackerProviderId[\s\S]*clientId\?: string[\s\S]*redirectUri\?: string/,
  'tracker model must expose non-secret provider OAuth registration config',
)
assert.match(
  trackerModelsSource,
  /TRACKER_PROVIDER_OAUTH_CONFIGS_KEY: string = 'tracker\.providerOAuthConfigs'[\s\S]*providerOAuthConfigs: \[\]/,
  'tracker preferences must persist provider OAuth registration config separately from accounts and tokens',
)
assert.match(
  trackerModelsSource,
  /normalizeTrackerProviderOAuthConfigs\(values: TrackerProviderOAuthConfig\[\]\)[\s\S]*provider\.supportStatus !== 'available'[\s\S]*clientId[\s\S]*redirectUri[\s\S]*getConfiguredTrackerProviderConfig\([\s\S]*providerId: TrackerProviderId,[\s\S]*configs: TrackerProviderOAuthConfig\[\]/,
  'tracker provider OAuth configs must be normalized and merged only for supported providers',
)
assert.match(
  trackerModelsSource,
  /export interface TrackerCredentialSecretStore \{[\s\S]*isAvailable\(\): boolean[\s\S]*writeToken\(request: TrackerCredentialWriteRequest\): Promise<TrackerCredentialStoreResult>[\s\S]*readToken\(ref: TrackerCredentialSecretRef\): Promise<Uint8Array \| undefined>/,
  'tracker model must define a narrow secure-token boundary',
)
assert.match(
  trackerModelsSource,
  /export class AssetStoreTrackerCredentialSecretStore implements TrackerCredentialSecretStore/,
  'tracker model must include the HarmonyOS AssetStore-backed credential implementation',
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
assert.match(
  trackerModelsSource,
  /disconnectAccount\(providerId: TrackerProviderId\): Promise<TrackerPreferences>[\s\S]*this\.secretStore\.deleteAccount\(\{[\s\S]*providerId,[\s\S]*accountKey: account\.credentialAccountKey[\s\S]*!deleted\.ok[\s\S]*status: 'error'[\s\S]*statusReason: deleted\.error\?\.code \?\? 'storage_unavailable'[\s\S]*status: 'disconnected'/,
  'TrackerPreferencesStore must delete secure account credentials before marking a tracker account disconnected',
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
assert.doesNotMatch(
  settingsPageSource,
  /key: 'tracker-auto-sync'[^}]*placeholder: true|key: 'tracker-update-strategy'[^}]*placeholder: true/,
  'Settings tracker sync rows must not remain placeholders',
)
assert.match(
  settingsPageSource,
  /DEFAULT_TRACKER_PREFERENCES[\s\S]*TrackerPreferencesStore[\s\S]*TrackerUpdateStrategy[\s\S]*trackerAutoSyncEnabled: boolean = DEFAULT_TRACKER_PREFERENCES\.autoSyncEnabled[\s\S]*trackerUpdateStrategy: TrackerUpdateStrategy = DEFAULT_TRACKER_PREFERENCES\.updateStrategy/,
  'SettingsPage must keep tracker sync preferences as real typed state',
)
assert.match(
  settingsPageSource,
  /loadTrackerPreferences\(\): void[\s\S]*this\.trackerPreferencesStore\(\)\.load\(\)[\s\S]*this\.trackerAutoSyncEnabled = preferences\.autoSyncEnabled[\s\S]*this\.trackerUpdateStrategy = preferences\.updateStrategy/,
  'SettingsPage must load tracker sync preferences from TrackerPreferencesStore',
)
assert.match(
  settingsPageSource,
  /isSwitchRow\(row: SettingsRow\)[\s\S]*row\.key === 'tracker-auto-sync'[\s\S]*switchRowValue\(row: SettingsRow\)[\s\S]*this\.trackerAutoSyncEnabled[\s\S]*setSwitchRowValue\(row: SettingsRow, value: boolean\)[\s\S]*saveTrackerAutoSyncEnabled\(value\)/,
  'SettingsPage tracker auto sync must be a real switch row',
)
assert.match(
  settingsPageSource,
  /isSelectionRow\(row: SettingsRow\)[\s\S]*row\.key === 'tracker-update-strategy'[\s\S]*row\.key === 'tracker-update-strategy'[\s\S]*tracker_update_strategy_chapter_complete[\s\S]*saveTrackerUpdateStrategy\('on_chapter_complete'\)[\s\S]*tracker_update_strategy_reader_close[\s\S]*saveTrackerUpdateStrategy\('on_reader_close'\)[\s\S]*tracker_update_strategy_manual[\s\S]*saveTrackerUpdateStrategy\('manual'\)/,
  'SettingsPage tracker update timing must be a real menu row with all strategy options',
)
assert.match(
  settingsPageSource,
  /saveTrackerAutoSyncEnabled\(enabled: boolean\): void[\s\S]*saveSyncPreferences\(enabled, this\.trackerUpdateStrategy\)[\s\S]*saveTrackerUpdateStrategy\(strategy: TrackerUpdateStrategy\): void[\s\S]*saveSyncPreferences\(this\.trackerAutoSyncEnabled, strategy\)/,
  'SettingsPage must persist tracker sync controls through TrackerPreferencesStore',
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
assert.doesNotMatch(
  trackerPageSource,
  /(Navigation|NavDestination)\(/,
  'TrackerSettingsPage must not nest a Navigation/NavDestination inside Settings',
)
assert.match(
  trackerPageSource,
  /new AssetStoreTrackerCredentialSecretStore\(\)[\s\S]*new TrackerPreferencesStore\(this\.context\(\), this\.credentialSecretStore\)[\s\S]*this\.secureStorageAvailable = this\.credentialSecretStore\.isAvailable\(\)/,
  'TrackerSettingsPage must wire the system secure credential store into tracker preferences',
)
assert.match(
  trackerPageSource,
  /@Local private providerOAuthConfigs: TrackerProviderOAuthConfig\[\] = \[\][\s\S]*this\.providerOAuthConfigs = preferences\.providerOAuthConfigs[\s\S]*configuredProvider\(provider: TrackerProviderConfig\)[\s\S]*getConfiguredTrackerProviderConfig\(provider\.providerId, this\.providerOAuthConfigs\)/,
  'TrackerSettingsPage must load and use local provider OAuth registration config',
)
assert.match(
  trackerPageSource,
  /private canPrepareConnect\(provider: TrackerProviderConfig\): boolean \{[\s\S]*const configuredProvider = this\.configuredProvider\(provider\)[\s\S]*configuredProvider\.clientId !== undefined[\s\S]*configuredProvider\.redirectUri !== undefined/,
  'TrackerSettingsPage connect readiness must use configured provider metadata',
)
assert.match(
  trackerPageSource,
  /saveProviderOAuthConfig\(provider: TrackerProviderConfig[\s\S]*trackerPreferencesStore\(\)\.saveProviderOAuthConfig\([\s\S]*provider\.providerId[\s\S]*this\.providerClientId\(provider\)[\s\S]*this\.providerRedirectUri\(provider\)[\s\S]*tracker_oauth_config_saved[\s\S]*tracker_oauth_config_save_failed/,
  'TrackerSettingsPage must persist non-secret provider OAuth config through TrackerPreferencesStore',
)
assert.match(
  trackerPageSource,
  /prepareConnect\(provider: TrackerProviderConfig\): void[\s\S]*saveProviderOAuthConfig\(provider, false\)[\s\S]*trackerPreferencesStore\(\)\.prepareConnect\(provider\.providerId\)/,
  'TrackerSettingsPage must save local OAuth registration config before preparing authorization',
)
assert.match(
  trackerPageSource,
  /ProviderOAuthConfigForm\(provider: TrackerProviderConfig\)[\s\S]*KomaFormTextField\(\{[\s\S]*tracker_oauth_client_id_label[\s\S]*this\.setProviderClientId\(provider, value\)[\s\S]*tracker_oauth_redirect_uri_label[\s\S]*this\.setProviderRedirectUri\(provider, value\)[\s\S]*common_save[\s\S]*this\.saveProviderOAuthConfig\(provider\)/,
  'TrackerSettingsPage must expose non-secret client id and redirect URI fields for supported tracker providers',
)
assert.match(
  trackerPageSource,
  /import \{ pasteboard \} from '@kit\.BasicServicesKit'/,
  'TrackerSettingsPage must use the system pasteboard for user-triggered authorization URL copy',
)
assert.match(
  trackerPageSource,
  /@Local private preparedAuthorizationUrl: string = ''/,
  'TrackerSettingsPage must keep prepared authorization URLs in page-local state only',
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
  /prepareConnect\(provider: TrackerProviderConfig\): void[\s\S]*this\.preparedAuthorizationUrl = ''[\s\S]*prepareConnect\(provider\.providerId\)[\s\S]*this\.preparedAuthorizationUrl = result\.status === 'ready'[\s\S]*result\.authorizationUrl[\s\S]*this\.preparedAuthorizationUrl = ''[\s\S]*tracker_message_auth_prepare_failed/,
  'TrackerSettingsPage must expose a prepared authorization URL only for ready OAuth preparation and clear it on unavailable or failed attempts',
)
assert.match(
  trackerPageSource,
  /copyPreparedAuthorizationUrl\(\): void[\s\S]*pasteboard\.createData\(pasteboard\.MIMETYPE_TEXT_PLAIN, this\.preparedAuthorizationUrl\)[\s\S]*pasteboard\.getSystemPasteboard\(\)\.setData\(data\)[\s\S]*tracker_auth_url_copied[\s\S]*tracker_auth_url_copy_failed/,
  'TrackerSettingsPage must provide a real clipboard copy action for the prepared authorization URL',
)
assert.match(
  trackerPageSource,
  /import \{[\s\S]*TrackerOAuthCompletionReason[\s\S]*TrackerOAuthCompletionService[\s\S]*\} from '..\/model\/TrackerOAuthCompletionService'/,
  'TrackerSettingsPage must import the real OAuth completion service',
)
assert.match(
  trackerPageSource,
  /canCompleteOAuthCallback\(provider: TrackerProviderConfig\): boolean[\s\S]*account\.status === 'auth_pending'[\s\S]*credentialAccountKey !== undefined[\s\S]*providerOAuthCallbackUri\(provider\)\.trim\(\)\.length > 0/,
  'TrackerSettingsPage must only complete OAuth callbacks for pending accounts with a returned URL',
)
assert.match(
  trackerPageSource,
  /completeOAuthCallback\(provider: TrackerProviderConfig\): void[\s\S]*new TrackerOAuthCompletionService\(this\.context\(\), \{[\s\S]*secretStore: this\.credentialSecretStore[\s\S]*completeCallback\(provider\.providerId[\s\S]*providerOAuthCallbackUri\(provider\)\.trim\(\)[\s\S]*result\.status === 'connected'[\s\S]*tracker_callback_connected/,
  'TrackerSettingsPage must complete callback URLs through the secure completion service and refresh visible state',
)
assert.match(
  trackerPageSource,
  /ProviderOAuthConfigForm\(provider: TrackerProviderConfig\)[\s\S]*this\.findAccount\(provider\)\.status === 'auth_pending'[\s\S]*tracker_callback_uri_label[\s\S]*this\.setProviderOAuthCallbackUri\(provider, value\)[\s\S]*tracker_callback_complete[\s\S]*this\.completeOAuthCallback\(provider\)/,
  'TrackerSettingsPage must expose callback completion UI only while provider authorization is pending',
)
assert.match(
  trackerPageSource,
  /if \(this\.preparedAuthorizationUrl\.length > 0\) \{[\s\S]*tracker_auth_url_ready_detail[\s\S]*KomaActionButton\(\{[\s\S]*tracker_auth_url_copy[\s\S]*this\.copyPreparedAuthorizationUrl\(\)/,
  'TrackerSettingsPage status card must show a user-actionable copy control when an authorization URL is ready',
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
assert.match(
  trackerPageSource,
  /@Local private mappings:\s*ComicTrackerMapping\[\][\s\S]*this\.mappings = preferences\.comicMappings[\s\S]*MappingRow\(mapping: ComicTrackerMapping\)/,
  'TrackerSettingsPage must list non-secret comic mappings from preferences instead of summary only',
)
assert.match(
  trackerPageSource,
  /canReviewMapping\(mapping: ComicTrackerMapping\): boolean[\s\S]*mapping\.mappingState === 'candidate' \|\| mapping\.mappingState === 'stale'/,
  'TrackerSettingsPage must only expose review actions for candidate or stale mappings',
)
assert.match(
  trackerPageSource,
  /canDisconnectProvider\(provider: TrackerProviderConfig\): boolean[\s\S]*account\.status !== 'disconnected'[\s\S]*account\.credentialAccountKey === undefined \|\| this\.secureStorageAvailable[\s\S]*disconnectAccount\(provider: TrackerProviderConfig\): void[\s\S]*trackerPreferencesStore\(\)\.disconnectAccount\(provider\.providerId\)[\s\S]*account\.status === 'disconnected'[\s\S]*pendingSyncStore\(\)\.removeProgressForProvider\(provider\.providerId\)[\s\S]*loadPendingProgressSummary\(\)[\s\S]*tracker_message_disconnected[\s\S]*tracker_message_disconnect_failed/,
  'TrackerSettingsPage must expose a real disconnect action that clears secure tracker credentials, purges provider pending sync, and refreshes account state',
)
assert.match(
  trackerPageSource,
  /if \(this\.canDisconnectProvider\(provider\)\) \{[\s\S]*label: s\('tracker_action_disconnect'\)[\s\S]*kind: 'danger'[\s\S]*this\.confirmDisconnectAccount\(provider\)/,
  'TrackerSettingsPage provider rows must show a destructive disconnect action that opens confirmation for disconnectable accounts',
)
assert.match(
  trackerPageSource,
  /updateMappingReview\(mapping: ComicTrackerMapping, confirmed: boolean\)[\s\S]*confirmComicMapping\(mapping\.comicId, mapping\.providerId\)[\s\S]*rejectComicMapping\(mapping\.comicId, mapping\.providerId\)[\s\S]*summarizeComicTrackerMappings\(preferences\.comicMappings\)/,
  'TrackerSettingsPage review actions must update mapping state through TrackerPreferencesStore and refresh the summary',
)
assert.doesNotMatch(
  trackerPageSource,
  /TextInput\(|InputType\.Password|已连接.*Button|connected:\s*true/,
  'TrackerSettingsPage must not collect secrets or fake connected state',
)
for (const localeSource of localeStringSources) {
  for (const key of [
    'tracker_callback_uri_label',
    'tracker_callback_uri_placeholder',
    'tracker_callback_complete',
    'tracker_callback_connected',
    'tracker_callback_invalid',
    'tracker_callback_unavailable',
    'tracker_callback_account_missing',
    'tracker_callback_storage_failed',
    'tracker_callback_failed',
  ]) {
    assert.match(localeSource, new RegExp(`"name": "${key}"`), `locale strings must include ${key}`)
  }
}

console.log('tracker settings checks PASS')
