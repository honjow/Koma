import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const servicePath = resolve(root, 'entry/src/main/ets/model/TrackerOAuthCompletionService.ets')
const modelsPath = resolve(root, 'entry/src/main/ets/model/TrackerModels.ets')
const constantsPath = resolve(root, 'entry/src/main/ets/common/Constants.ets')
const routerHelperPath = resolve(root, 'entry/src/main/ets/common/RouterHelper.ets')
const entryAbilityPath = resolve(root, 'entry/src/main/ets/entryability/EntryAbility.ets')
const serviceSource = readFileSync(servicePath, 'utf8')
const modelsSource = readFileSync(modelsPath, 'utf8')
const constantsSource = readFileSync(constantsPath, 'utf8')
const routerHelperSource = readFileSync(routerHelperPath, 'utf8')
const entryAbilitySource = readFileSync(entryAbilityPath, 'utf8')

assert.match(serviceSource, /export class TrackerOAuthCompletionService/, 'OAuth completion service must exist')
assert.match(
  serviceSource,
  /completeCallback\(providerId: TrackerProviderId, callbackUri: string[\s\S]*TrackerPreferencesStore\(this\.context, this\.secretStore\)[\s\S]*status === 'auth_pending'[\s\S]*credentialAccountKey/,
  'OAuth completion must only continue from a pending tracker account state',
)
assert.match(
  serviceSource,
  /parseTrackerOAuthCallback\(callbackUri, account\.credentialAccountKey\)[\s\S]*!callback\.ok[\s\S]*saveError/,
  'OAuth completion must reuse the state-checking callback parser and fail closed',
)
assert.match(
  serviceSource,
  /secretKind: 'oauth_code_verifier'[\s\S]*decodeTrackerSecretBytes\(verifierBytes\)[\s\S]*tokenExchanger\.exchange\(configuredProvider, fields\.code, verifier\)/,
  'OAuth completion must read the PKCE verifier from secure storage before token exchange',
)
assert.match(
  serviceSource,
  /secretKind: 'access_token'[\s\S]*secretBytes: utf8Bytes\(tokenResult\.accessToken\)[\s\S]*secretKind: 'refresh_token'[\s\S]*secretBytes: utf8Bytes\(tokenResult\.refreshToken\)/,
  'OAuth completion must write provider tokens only through the credential secret store',
)
assert.match(
  serviceSource,
  /secretKind: 'oauth_code_verifier'[\s\S]*TrackerAccountRefreshService\(this\.context, \{ secretStore: this\.secretStore \}\)\.refreshAccounts\(providerId, now\)[\s\S]*refresh\.refreshedCount <= 0[\s\S]*profile_refresh_failed/,
  'OAuth completion must delete the verifier and fetch the provider profile before reporting connected',
)
assert.match(
  serviceSource,
  /TRACKER_TOKEN_ENDPOINTS[\s\S]*anilist: 'https:\/\/anilist\.co\/api\/v2\/oauth\/token'[\s\S]*myanimelist: 'https:\/\/myanimelist\.net\/v1\/oauth2\/token'/,
  'OAuth completion must support AniList and MyAnimeList token endpoints',
)
assert.doesNotMatch(
  serviceSource,
  /console\.(log|info|warn|error)\([^)]*(code|token|authorization|Bearer|verifier|providerTitleId|comicId)/i,
  'OAuth completion must not log callback codes, tokens, verifiers, or user mapping identifiers',
)

const callbackBlock = modelsSource.match(/export function parseTrackerOAuthCallback[\s\S]*?\n\}/)?.[0] ?? ''
assert.doesNotMatch(
  callbackBlock,
  /code,\s*$|code: code|authorizationCode|authCode/,
  'shared callback parser must continue hiding raw callback codes from model results',
)
assert.match(
  constantsSource,
  /KOMA_LAUNCH_ROUTE_TRACKER_SETTINGS:\s*string = 'tracker_settings'/,
  'launch route constants must include the tracker settings route for OAuth QA',
)
assert.match(
  routerHelperSource,
  /pushTrackerSettings\(\): void \{[\s\S]*RouteName\.TRACKER_SETTINGS/,
  'RouterHelper must expose a direct tracker settings launch route',
)
assert.match(
  entryAbilitySource,
  /KOMA_LAUNCH_ROUTE_TRACKER_SETTINGS[\s\S]*RouterHelper\.pushTrackerSettings\(\)/,
  'EntryAbility must route tracker settings launch wants to TrackerSettingsPage',
)

console.log('tracker oauth completion service checks PASS')
