import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const source = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerProgressSyncService.ets'), 'utf8')
const clientSource = readFileSync(resolve(root, 'entry/src/main/ets/model/AniListTrackerClient.ets'), 'utf8')

assert.match(source, /export class TrackerProgressSyncService/, 'tracker progress sync service must exist')
assert.match(source, /AniListTrackerClient/, 'tracker progress sync service must depend on the AniList provider client')
assert.match(
  source,
  /constructor\(context: common\.UIAbilityContext, options: TrackerProgressSyncServiceOptions = \{\}\)[\s\S]*new AssetStoreTrackerCredentialSecretStore\(\)[\s\S]*options\.aniListClient/,
  'tracker progress sync service must default to secure storage and accept an injected AniList client',
)
assert.match(
  source,
  /pushReadingProgress\(progress: ReadingProgress, chapterIds: string\[\][\s\S]*preferences\.autoSyncEnabled[\s\S]*auto_sync_disabled/,
  'tracker progress push must respect the durable auto-sync preference',
)
assert.match(
  source,
  /findConfirmedAniListMapping\(preferences[\s\S]*mapping\.providerId === 'anilist'[\s\S]*mapping\.mappingState === 'confirmed'[\s\S]*mapping\.userConfirmed/,
  'tracker progress sync must only use user-confirmed AniList mappings',
)
assert.match(
  source,
  /findConnectedAniListAccount\(preferences[\s\S]*account\.providerId === 'anilist' && account\.status === 'connected'/,
  'tracker progress sync must require a connected AniList account',
)
assert.match(
  source,
  /secretStore\.readToken\(\{[\s\S]*providerId: 'anilist'[\s\S]*secretKind: 'access_token'[\s\S]*buffer\.from\(tokenBytes\.buffer\)\.toString\('utf-8'\)/,
  'tracker progress sync must read the AniList access token from secure storage at use time',
)
assert.doesNotMatch(
  source,
  /store\.put\([^)]*(token|secret|authorization|Bearer|accessToken)|JSON\.stringify\([^)]*(token|secret|authorization|Bearer|accessToken)/i,
  'tracker progress sync must not persist token material',
)
assert.doesNotMatch(
  source,
  /console\.(log|info|warn|error)\([^)]*(token|authorization|Bearer|accessToken|providerTitleId|comicId)/i,
  'tracker progress sync must not log sensitive sync identifiers or tokens',
)
assert.match(
  source,
  /if \(this\.aniListClient === undefined\) \{[\s\S]*client_unavailable/,
  'tracker progress sync must fail closed when no real AniList client is available',
)
assert.match(
  source,
  /aniListClient\.pushProgress\(accessToken, mapping\.providerTitleId, providerProgress, progress\.completed\)/,
  'tracker progress push must call AniList progress mutation with mapped provider title id',
)
assert.match(
  source,
  /aniListClient\.fetchProgress\(accessToken, mapping\.providerTitleId\)/,
  'tracker progress pull must call AniList progress query with mapped provider title id',
)
assert.match(
  source,
  /markAniListAccountSynced\(preferences, account, now\)[\s\S]*saveAccounts\(nextAccounts\)/,
  'successful tracker sync must update account lastSyncAt without touching credentials',
)
assert.match(
  source,
  /calculateAniListChapterProgress\(progress: ReadingProgress, chapterIds: string\[\]\)[\s\S]*chapterIds\.indexOf\(progress\.chapterId\)[\s\S]*progress\.completed \? chapterIndex \+ 1 : chapterIndex/,
  'AniList progress calculation must convert local chapter completion into provider chapter count',
)
assert.match(
  source,
  /remote_progress_missing/,
  'tracker progress pull must distinguish absent remote progress from missing local mapping',
)
assert.match(
  clientSource,
  /pushProgress\(accessToken: string, providerTitleId: string, progress: number, completed: boolean\)/,
  'AniList client must expose pushProgress for the sync service',
)

console.log('tracker progress sync service checks PASS')
