import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const trackerModelsSource = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerModels.ets'), 'utf8')
const backupServiceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/BackupService.ets'), 'utf8')

const trackerAccountBlock = trackerModelsSource.match(/export interface TrackerAccount \{[\s\S]*?\n\}/)?.[0] ?? ''
assert.match(trackerAccountBlock, /providerId: TrackerProviderId/, 'account must include provider id')
assert.match(trackerAccountBlock, /status: TrackerAccountStatus/, 'account must include honest status')
assert.match(trackerAccountBlock, /profile\?: TrackerPublicProfile/, 'account may include public profile only')
assert.match(trackerAccountBlock, /credentialAccountKey\?: string/, 'account may include opaque credential account ref')
assert.doesNotMatch(
  trackerAccountBlock,
  /secretBytes|access_token|refresh_token|accessToken|refreshToken|password|clientSecret|authorizationCode|authCode|cookie|bearer/i,
  'persisted account model must not include raw token or auth material fields',
)

const storeWriteBlock = trackerModelsSource.match(/async saveAccounts\(accounts: TrackerAccount\[\]\): Promise<TrackerPreferences> \{[\s\S]*?\n  \}/)?.[0] ?? ''
assert.match(storeWriteBlock, /JSON\.stringify\(next\.accounts\)/, 'account store must persist normalized account JSON')
assert.doesNotMatch(
  storeWriteBlock,
  /writeToken|secretBytes|readToken|authorizationUrl|codeVerifier/,
  'normal account persistence must not write token material or transient OAuth data',
)

assert.match(
  trackerModelsSource,
  /prepareTrackerOAuthStart\([\s\S]*!secureStorageAvailable[\s\S]*status: 'secure_storage_unavailable'/,
  'OAuth preparation must fail closed before auth URL creation when secure storage is unavailable',
)
assert.match(
  trackerModelsSource,
  /provider\.authorizationEndpoint === undefined \|\| provider\.clientId === undefined \|\| provider\.redirectUri === undefined[\s\S]*status: 'provider_config_missing'/,
  'OAuth preparation must require provider registration metadata without a client secret',
)
assert.match(
  trackerModelsSource,
  /createDeterministicPkceForTest\(seed: string\)/,
  'PKCE helper must be explicitly test-only while production remains gated',
)
const prepareConnectBlock = trackerModelsSource.match(/async prepareConnect\(providerId: TrackerProviderId\): Promise<TrackerOAuthStartPreparation> \{[\s\S]*?\n  \}/)?.[0] ?? ''
assert.match(
  prepareConnectBlock,
  /prepareTrackerOAuthStart\(\{[\s\S]*state: ''[\s\S]*codeChallenge: ''[\s\S]*this\.secretStore\.isAvailable\(\)/,
  'production prepareConnect must fail closed when production PKCE/state generation is unavailable',
)
assert.doesNotMatch(
  prepareConnectBlock,
  /createDeterministicPkceForTest|tracker-\$\{providerId\}|authorizationUrl/,
  'production prepareConnect must not use deterministic PKCE, predictable state, or produce an auth URL directly',
)
assert.doesNotMatch(
  trackerModelsSource,
  /clientSecret|client_secret/,
  'provider metadata must not embed OAuth client secrets',
)

const callbackBlock = trackerModelsSource.match(/export function parseTrackerOAuthCallback[\s\S]*?\n\}/)?.[0] ?? ''
assert.match(
  callbackBlock,
  /try \{[\s\S]*parseQuery\(callbackUri\)[\s\S]*catch \(_error\) \{[\s\S]*reason: 'invalid_callback'/,
  'callback parser must return invalid_callback for malformed percent-encoding instead of throwing',
)
assert.match(callbackBlock, /state_mismatch/, 'callback parser must detect state mismatch')
assert.doesNotMatch(
  callbackBlock,
  /code,\s*$|code: code|authorizationCode|authCode/,
  'callback parser must not return the raw authorization code',
)

const backupDocumentBlock = backupServiceSource.match(/interface KomaBackupDocument \{[\s\S]*?\n\}/)?.[0] ?? ''
assert.doesNotMatch(
  backupDocumentBlock,
  /tracker.*(token|secret|credential|authorization|code)|accessToken|refreshToken|clientSecret/i,
  'backup schema must not include tracker credential material',
)

console.log('tracker account store checks PASS')
