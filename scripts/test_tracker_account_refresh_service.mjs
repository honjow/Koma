import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const serviceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerAccountRefreshService.ets'), 'utf8')
const pageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/TrackerSettingsPage.ets'), 'utf8')
const baseStrings = readFileSync(resolve(root, 'entry/src/main/resources/base/element/string.json'), 'utf8')
const enStrings = readFileSync(resolve(root, 'entry/src/main/resources/en_US/element/string.json'), 'utf8')
const zhStrings = readFileSync(resolve(root, 'entry/src/main/resources/zh_CN/element/string.json'), 'utf8')

assert.match(
  serviceSource,
  /export class TrackerAccountRefreshService[\s\S]*AssetStoreTrackerCredentialSecretStore[\s\S]*AniListTrackerClient[\s\S]*MyAnimeListTrackerClient/,
  'tracker account refresh service must use secure token storage plus AniList/MAL clients',
)
assert.match(
  serviceSource,
  /async refreshAccounts\(preferredProviderId\?: TrackerProviderId[\s\S]*refreshableProviderIds\(preferences\.accounts, preferredProviderId\)[\s\S]*store\.saveAccounts\(accounts\)/,
  'tracker account refresh must load preferences, refresh selected providers, and persist account status only',
)
assert.match(
  serviceSource,
  /private async readAccessToken\(account: TrackerAccount, providerId: TrackerProviderId\)[\s\S]*secretKind: 'access_token'[\s\S]*decodeTrackerSecretBytes\(tokenBytes\)\.trim\(\)/,
  'tracker account refresh must read access tokens from AssetStore and decode only the returned byte range',
)
assert.match(
  serviceSource,
  /fetchProfile\(providerId: TrackerProviderId, accessToken: string\)[\s\S]*aniListClient\.fetchProfile\(accessToken\)[\s\S]*myAnimeListClient\.fetchProfile\(accessToken\)/,
  'tracker account refresh must verify accounts through provider profile APIs',
)
assert.match(
  serviceSource,
  /status: 'connected'[\s\S]*profile: \{[\s\S]*username[\s\S]*displayName[\s\S]*providerUserId[\s\S]*lastSyncAt: now/,
  'successful tracker account refresh must persist only public profile fields and a sync timestamp',
)
assert.match(
  serviceSource,
  /status: profileResult\.expired \? 'expired' : 'error'[\s\S]*statusReason: profileResult\.expired \? 'unauthorized' : 'provider_failed'/,
  'failed tracker account refresh must bucket unauthorized as expired and other failures as provider_failed',
)
assert.doesNotMatch(
  serviceSource,
  /console\.(?:log|info|warn|error)\([^)]*(token|accessToken|secret|message|error)/i,
  'tracker account refresh service must not log tokens or raw error messages',
)
assert.doesNotMatch(
  serviceSource,
  /saveComicMappings|TRACKER_COMIC_MAPPINGS_KEY|writeToken|deleteToken|authorizationUrl|codeVerifier/,
  'tracker account refresh must not mutate mappings, write credentials, or expose OAuth transient data',
)

assert.match(
  pageSource,
  /import \{[\s\S]*TrackerAccountRefreshService[\s\S]*TrackerAccountRefreshSummary[\s\S]*\} from '..\/model\/TrackerAccountRefreshService'/,
  'TrackerSettingsPage must import the account refresh service',
)
assert.match(
  pageSource,
  /refreshingProviderId: string = ''[\s\S]*canRefreshProvider\(provider: TrackerProviderConfig\)[\s\S]*provider\.providerId === 'anilist' \|\| provider\.providerId === 'myanimelist'[\s\S]*account\.credentialAccountKey !== undefined/,
  'TrackerSettingsPage must enable refresh only for supported providers with secure credential refs',
)
assert.match(
  pageSource,
  /refreshAccount\(provider: TrackerProviderConfig\)[\s\S]*new TrackerAccountRefreshService\(this\.context\(\), \{[\s\S]*secretStore: this\.credentialSecretStore[\s\S]*refreshAccounts\(provider\.providerId\)[\s\S]*this\.accounts = summary\.preferences\.accounts/,
  'TrackerSettingsPage must refresh provider accounts through the service and reload account state',
)
assert.match(
  pageSource,
  /step=account_refresh provider=\$\{provider\.providerId\} refreshed=\$\{summary\.refreshedCount\} skipped=\$\{summary\.skippedCount\} failed=\$\{summary\.failedCount\}/,
  'TrackerSettingsPage refresh logs must expose only provider id and aggregate counts',
)
assert.match(
  pageSource,
  /tracker_action_refresh[\s\S]*this\.refreshAccount\(provider\)/,
  'Provider rows must expose a real refresh action for connected accounts',
)
assert.doesNotMatch(
  pageSource,
  /account_refresh[\s\S]*(token|accessToken|secret|message=|error\.message)/i,
  'TrackerSettingsPage account refresh handling must not log tokens or raw error messages',
)

for (const source of [baseStrings, enStrings, zhStrings]) {
  for (const key of [
    'tracker_action_refresh',
    'tracker_refresh_done',
    'tracker_refresh_failed',
    'tracker_refresh_unavailable',
  ]) {
    assert.match(source, new RegExp(`"name": "${key}"`), `locale must define ${key}`)
  }
}

console.log('tracker account refresh service checks PASS')
