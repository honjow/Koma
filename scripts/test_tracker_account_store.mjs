import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const trackerModelsSource = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerModels.ets'), 'utf8')
const backupServiceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/BackupService.ets'), 'utf8')

function createDeterministicPkceForTest(seed) {
  const normalized = seed.replace(/[^A-Za-z0-9._~-]/g, '').slice(0, 32)
  const verifier = `koma-test-${normalized.length === 0 ? 'seed' : normalized}-verifier-000000000000000000000000`
  return {
    codeVerifier: verifier,
    codeChallenge: verifier,
  }
}

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
assert.match(storeWriteBlock, /autoSyncEnabled: current\.autoSyncEnabled[\s\S]*updateStrategy: current\.updateStrategy/, 'account store must preserve tracker sync preferences')
assert.doesNotMatch(
  storeWriteBlock,
  /writeToken|secretBytes|readToken|authorizationUrl|codeVerifier/,
  'normal account persistence must not write token material or transient OAuth data',
)
assert.match(
  trackerModelsSource,
  /export type TrackerUpdateStrategy = 'on_chapter_complete' \| 'on_reader_close' \| 'manual'[\s\S]*TRACKER_AUTO_SYNC_ENABLED_KEY[\s\S]*TRACKER_UPDATE_STRATEGY_KEY[\s\S]*autoSyncEnabled: false[\s\S]*updateStrategy: 'on_chapter_complete'/,
  'tracker preferences must define durable auto-sync and update strategy defaults',
)
assert.match(
  trackerModelsSource,
  /normalizeTrackerUpdateStrategy\(value: string\): TrackerUpdateStrategy[\s\S]*value === 'on_reader_close' \|\| value === 'manual'[\s\S]*return 'on_chapter_complete'/,
  'tracker update strategy must normalize unknown persisted values to a safe default',
)
assert.match(
  trackerModelsSource,
  /async load\(\): Promise<TrackerPreferences>[\s\S]*TRACKER_AUTO_SYNC_ENABLED_KEY[\s\S]*TRACKER_UPDATE_STRATEGY_KEY[\s\S]*autoSyncEnabled: autoSyncEnabled === true[\s\S]*updateStrategy: normalizeTrackerUpdateStrategy\(updateStrategy\)/,
  'tracker preferences load must hydrate sync preferences from dedicated preference keys',
)
assert.match(
  trackerModelsSource,
  /async saveSyncPreferences\(autoSyncEnabled: boolean, updateStrategy: TrackerUpdateStrategy\): Promise<TrackerPreferences>[\s\S]*accounts: current\.accounts[\s\S]*comicMappings: current\.comicMappings[\s\S]*store\.put\(TRACKER_AUTO_SYNC_ENABLED_KEY, next\.autoSyncEnabled\)[\s\S]*store\.put\(TRACKER_UPDATE_STRATEGY_KEY, next\.updateStrategy\)/,
  'tracker sync preferences must persist without touching account secrets or mapping data',
)
assert.match(
  trackerModelsSource,
  /import \{ asset \} from '@kit\.AssetStoreKit'/,
  'tracker credential store must use HarmonyOS AssetStoreKit for token storage',
)
assert.match(
  trackerModelsSource,
  /export class AssetStoreTrackerCredentialSecretStore implements TrackerCredentialSecretStore[\s\S]*asset\.add\(attributes\)[\s\S]*asset\.query\(query\)[\s\S]*asset\.remove\(trackerAssetQuery\(ref\)\)[\s\S]*asset\.remove\(trackerAssetAccountQuery\(ref\)\)/,
  'asset-backed tracker credential store must implement write/read/delete/logout cleanup through AssetStoreKit',
)
assert.match(
  trackerModelsSource,
  /asset\.Tag\.ALIAS[\s\S]*asset\.Tag\.DATA_LABEL_CRITICAL_1[\s\S]*asset\.Tag\.DATA_LABEL_CRITICAL_2[\s\S]*asset\.Tag\.DATA_LABEL_CRITICAL_3[\s\S]*asset\.Tag\.GROUP_ID[\s\S]*attributes\.set\(asset\.Tag\.SECRET, request\.secretBytes\)/,
  'tracker tokens must be stored as AssetStore secrets indexed only by alias and opaque labels',
)
assert.match(
  trackerModelsSource,
  /asset\.Tag\.RETURN_TYPE, asset\.ReturnType\.ALL[\s\S]*asset\.Tag\.RETURN_LIMIT, 1/,
  'tracker token reads must request only one plaintext asset from AssetStore',
)
assert.match(
  trackerModelsSource,
  /function trackerCredentialErrorCode[\s\S]*24000002[\s\S]*'not_found'[\s\S]*24000005[\s\S]*'locked'[\s\S]*24000007[\s\S]*'corrupted'[\s\S]*24000017[\s\S]*'unsupported'/,
  'asset-backed tracker credential store must bucket system errors into safe credential error codes',
)

const mappingNormalizeBlock = trackerModelsSource.match(/export function normalizeComicTrackerMappings\(values: ComicTrackerMapping\[\]\): ComicTrackerMapping\[\] \{[\s\S]*?\n\}/)?.[0] ?? ''
assert.match(
  trackerModelsSource,
  /export type TrackerMappingState = 'unmapped' \| 'candidate' \| 'confirmed' \| 'rejected' \| 'stale'/,
  'tracker mapping model must expose honest mapping states',
)
assert.match(
  trackerModelsSource,
  /export interface ComicTrackerMapping \{[\s\S]*comicId: ComicId[\s\S]*providerId: TrackerProviderId[\s\S]*providerTitleId: string[\s\S]*mappingState: TrackerMappingState/,
  'comic tracker mapping must identify a local comic and remote provider title',
)
assert.match(
  mappingNormalizeBlock,
  /findIndex\(\(item: ComicTrackerMapping\): boolean => \{[\s\S]*item\.comicId === next\.comicId && item\.providerId === next\.providerId/,
  'comic tracker mappings must be deduped by local comic and provider',
)
assert.match(
  mappingNormalizeBlock,
  /Math\.max\(0, Math\.min\(1, mapping\.confidence\)\)/,
  'comic tracker mapping confidence must be clamped to 0..1',
)
assert.match(
  trackerModelsSource,
  /function shouldReplaceComicTrackerMapping\([\s\S]*next\.mappingState === 'confirmed'[\s\S]*return nextUpdatedAt >= currentUpdatedAt/,
  'dedupe should prefer confirmed mappings, then the newest mapping',
)
assert.match(
  trackerModelsSource,
  /export function summarizeComicTrackerMappings\(mappings: ComicTrackerMapping\[\]\): TrackerComicMappingSummary[\s\S]*summary\.confirmed \+= 1[\s\S]*summary\.candidate \+= 1[\s\S]*summary\.stale \+= 1/,
  'tracker mapping summary must count mapping states for UI and sync planning',
)

const mappingSaveBlock = trackerModelsSource.match(/async saveComicMappings\(mappings: ComicTrackerMapping\[\]\): Promise<TrackerPreferences> \{[\s\S]*?\n  \}/)?.[0] ?? ''
assert.match(mappingSaveBlock, /TRACKER_COMIC_MAPPINGS_KEY/, 'mapping store must persist under the dedicated mapping key')
assert.match(mappingSaveBlock, /JSON\.stringify\(next\.comicMappings\)/, 'mapping store must persist normalized mapping JSON')
assert.match(mappingSaveBlock, /autoSyncEnabled: current\.autoSyncEnabled[\s\S]*updateStrategy: current\.updateStrategy/, 'mapping store must preserve tracker sync preferences')
assert.doesNotMatch(
  mappingSaveBlock,
  /writeToken|secretBytes|readToken|authorizationUrl|codeVerifier|TRACKER_ACCOUNTS_KEY/,
  'mapping persistence must not touch credentials or account records',
)

const mappingUpsertBlock = trackerModelsSource.match(/async upsertComicMapping\(mapping: ComicTrackerMapping\): Promise<TrackerPreferences> \{[\s\S]*?\n  \}/)?.[0] ?? ''
assert.match(
  mappingUpsertBlock,
  /item\.comicId !== mapping\.comicId\.trim\(\) \|\| item\.providerId !== mapping\.providerId[\s\S]*nextMappings\.push\(mapping\)[\s\S]*saveComicMappings\(nextMappings\)/,
  'upsert must replace the mapping for the same comic/provider pair',
)

const mappingRemoveBlock = trackerModelsSource.match(/async removeComicMapping\(comicId: ComicId, providerId: TrackerProviderId\): Promise<TrackerPreferences> \{[\s\S]*?\n  \}/)?.[0] ?? ''
assert.match(
  mappingRemoveBlock,
  /mapping\.comicId !== normalizedComicId \|\| mapping\.providerId !== providerId[\s\S]*saveComicMappings\(nextMappings\)/,
  'remove must delete only the requested comic/provider mapping',
)
assert.match(
  trackerModelsSource,
  /async listComicMappings\(comicId: ComicId\): Promise<ComicTrackerMapping\[\]> \{[\s\S]*findComicTrackerMappings\(comicId, current\.comicMappings\)/,
  'mapping store must list normalized mappings for a single local comic',
)
assert.match(
  trackerModelsSource,
  /async confirmComicMapping\(comicId: ComicId, providerId: TrackerProviderId, now: number = Date\.now\(\)\): Promise<TrackerPreferences> \{[\s\S]*updateComicMappingState\(comicId, providerId, 'confirmed', true, now\)/,
  'mapping store must confirm an existing candidate without inventing a provider match',
)
assert.match(
  trackerModelsSource,
  /async rejectComicMapping\(comicId: ComicId, providerId: TrackerProviderId, now: number = Date\.now\(\)\): Promise<TrackerPreferences> \{[\s\S]*updateComicMappingState\(comicId, providerId, 'rejected', false, now\)/,
  'mapping store must reject an existing candidate without deleting audit state',
)
const mappingStateUpdateBlock = trackerModelsSource.match(/private async updateComicMappingState\([\s\S]*?\n  \}/)?.[0] ?? ''
assert.match(
  mappingStateUpdateBlock,
  /mapping\.comicId !== normalizedComicId \|\| mapping\.providerId !== providerId[\s\S]*mappingState[\s\S]*userConfirmed[\s\S]*updatedAt: now[\s\S]*saveComicMappings\(nextMappings\)/,
  'mapping state updates must mutate only the requested comic/provider row and persist through the normalized mapping store',
)
assert.doesNotMatch(
  mappingStateUpdateBlock,
  /writeToken|readToken|deleteToken|TRACKER_ACCOUNTS_KEY|saveAccounts/,
  'mapping state updates must not touch tracker credentials or account records',
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
const testPkce = createDeterministicPkceForTest('tracker-account-store')
assert.equal(testPkce.codeVerifier, testPkce.codeChallenge, 'test-only PKCE helper should be deterministic for script fixtures')
assert.match(testPkce.codeVerifier, /^koma-test-tracker-account-store-verifier-0+$/, 'test-only PKCE helper should sanitize stable seeds')
assert.doesNotMatch(
  trackerModelsSource,
  /createDeterministicPkceForTest/,
  'deterministic PKCE helper must not be exported from production source',
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
