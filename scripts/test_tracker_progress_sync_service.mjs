import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const source = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerProgressSyncService.ets'), 'utf8')
const clientSource = readFileSync(resolve(root, 'entry/src/main/ets/model/AniListTrackerClient.ets'), 'utf8')
const myAnimeListClientSource = readFileSync(resolve(root, 'entry/src/main/ets/model/MyAnimeListTrackerClient.ets'), 'utf8')
const pendingStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerPendingSyncStore.ets'), 'utf8')
const indexSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8')
const mangaDetailPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets'), 'utf8')

assert.match(source, /export class TrackerProgressSyncService/, 'tracker progress sync service must exist')
assert.match(source, /AniListTrackerClient/, 'tracker progress sync service must depend on the AniList provider client')
assert.match(source, /MyAnimeListTrackerClient/, 'tracker progress sync service must depend on the MyAnimeList provider client')
assert.match(
  source,
  /constructor\(context: common\.UIAbilityContext, options: TrackerProgressSyncServiceOptions = \{\}\)[\s\S]*new AssetStoreTrackerCredentialSecretStore\(\)[\s\S]*options\.aniListClient \?\? new AniListTrackerClient\(new HarmonyAniListTrackerHttpAdapter\(\)\)[\s\S]*options\.myAnimeListClient \?\? new MyAnimeListTrackerClient\(new HarmonyMyAnimeListTrackerHttpAdapter\(\)\)[\s\S]*options\.pendingStore \?\? new TrackerPendingSyncStore\(context\)/,
  'tracker progress sync service must default to secure storage, real AniList/MyAnimeList HTTP, and a durable pending sync queue while accepting injected fakes',
)
assert.match(
  source,
  /pushReadingProgress\([\s\S]*progress: ReadingProgress,[\s\S]*chapterIds: string\[\],[\s\S]*preferences\.autoSyncEnabled[\s\S]*auto_sync_disabled/,
  'tracker progress push must respect the durable auto-sync preference',
)
assert.match(
  source,
  /pushReadingProgress\([\s\S]*trigger: TrackerUpdateStrategy = 'on_chapter_complete'[\s\S]*trigger !== 'manual' && preferences\.updateStrategy !== trigger[\s\S]*strategy_not_due/,
  'tracker progress push must respect automatic update strategies while allowing explicit manual sync',
)
assert.match(
  source,
  /isSupportedProgressProvider\(providerId: TrackerProviderId\): boolean \{[\s\S]*providerId === 'anilist' \|\| providerId === 'myanimelist'[\s\S]*findConfirmedMapping\(preferences[\s\S]*this\.isSupportedProgressProvider\(mapping\.providerId\)[\s\S]*mapping\.mappingState === 'confirmed'[\s\S]*mapping\.userConfirmed/,
  'tracker progress sync must only use user-confirmed mappings for implemented providers',
)
assert.match(
  source,
  /findConnectedAccount\(preferences[\s\S]*account\.providerId === providerId && account\.status === 'connected'/,
  'tracker progress sync must require a connected account for the mapped provider',
)
assert.match(
  source,
  /readAccessToken\(account: TrackerAccount, providerId: TrackerProviderId\)[\s\S]*secretStore\.readToken\(\{[\s\S]*providerId,[\s\S]*secretKind: 'access_token'[\s\S]*buffer\.from\(tokenBytes\.buffer\)\.toString\('utf-8'\)/,
  'tracker progress sync must read the mapped provider access token from secure storage at use time',
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
  /client_unavailable[\s\S]*hasClientForProvider\(providerId: TrackerProviderId\): boolean[\s\S]*providerId === 'anilist'[\s\S]*this\.aniListClient !== undefined[\s\S]*providerId === 'myanimelist'[\s\S]*this\.myAnimeListClient !== undefined/,
  'tracker progress sync must fail closed when no real client is available for the mapped provider',
)
assert.match(
  source,
  /pushProviderProgress\([\s\S]*providerId === 'myanimelist'[\s\S]*myAnimeListClient\.pushProgress\(accessToken, providerTitleId, providerProgress, completed\)[\s\S]*aniListClient\.pushProgress\(accessToken, providerTitleId, providerProgress, completed\)/,
  'tracker progress push must call the mapped provider progress mutation with mapped provider title id',
)
assert.match(
  source,
  /failedWithPendingQueue\('account_missing'[\s\S]*failedWithPendingQueue\('client_unavailable'[\s\S]*failedWithPendingQueue\('credential_missing'[\s\S]*failedWithPendingQueue\('provider_failed'/,
  'tracker progress push must queue retryable failures after a confirmed mapping exists',
)
assert.match(
  source,
  /await this\.pendingStore\.removeProgress\(mapping\.providerId, progress\.comicId, progress\.chapterId\)/,
  'successful tracker progress push must clear any retained pending sync item for the same chapter',
)
assert.match(
  source,
  /failedWithPendingQueue\([\s\S]*enqueueFailedProgress\(mapping\.providerId, progress, chapterIds, providerProgress, reason, now\)[\s\S]*result\.queued = true/,
  'failed tracker progress push must persist a retryable pending progress item and mark the result queued',
)
assert.doesNotMatch(
  source,
  /failedWithPendingQueue\('mapping_missing'|failedWithPendingQueue\('auto_sync_disabled'|failedWithPendingQueue\('strategy_not_due'/,
  'tracker progress sync must not queue disabled, strategy-gated, or unmapped progress',
)
assert.match(
  source,
  /retryPendingProgress\(limit: number = 20[\s\S]*const preferences = await this\.preferencesStore\(\)\.load\(\)[\s\S]*!preferences\.autoSyncEnabled[\s\S]*readingProgressFromPendingEntry\(entry, now\)[\s\S]*this\.pushReadingProgress\(progress, entry\.chapterIds, preferences\.updateStrategy, now, entry\.providerId\)[\s\S]*summary\.syncedCount \+= 1/,
  'tracker progress sync service must expose a bounded drain path for retained offline progress using the current sync strategy while respecting auto-sync',
)
assert.match(
  source,
  /fetchProviderProgress\([\s\S]*providerId === 'myanimelist'[\s\S]*myAnimeListClient\.fetchProgress\(accessToken, providerTitleId\)[\s\S]*aniListClient\.fetchProgress\(accessToken, providerTitleId\)/,
  'tracker progress pull must call the mapped provider progress query with mapped provider title id',
)
assert.match(
  source,
  /markAccountSynced\(preferences, account, now\)[\s\S]*saveAccounts\(nextAccounts\)/,
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
assert.match(
  myAnimeListClientSource,
  /pushProgress\(accessToken: string, providerTitleId: string, progress: number, completed: boolean\)/,
  'MyAnimeList client must expose pushProgress for the sync service',
)
assert.match(
  pendingStoreSource,
  /export class TrackerPendingSyncStore[\s\S]*TRACKER_PENDING_PROGRESS_QUEUE_KEY[\s\S]*enqueueFailedProgress\([\s\S]*savePendingProgress\([\s\S]*removeProgress\(/,
  'tracker pending sync store must persist, dedupe, and remove pending progress entries',
)
assert.match(
  pendingStoreSource,
  /TRACKER_PENDING_PROGRESS_MAX_ENTRIES: number = 100[\s\S]*normalizeEntries[\s\S]*slice\(0, TRACKER_PENDING_PROGRESS_MAX_ENTRIES\)/,
  'tracker pending sync store must bound retained progress entries',
)
assert.match(
  pendingStoreSource,
  /enqueueFailedProgress\([\s\S]*providerId: TrackerProviderId,[\s\S]*providerId,[\s\S]*comicId: progress\.comicId[\s\S]*chapterId: progress\.chapterId[\s\S]*chapterIds,[\s\S]*providerProgress,[\s\S]*lastReason: reason/,
  'tracker pending sync entries must retain enough non-secret state to retry chapter progress later for the mapped provider',
)
assert.doesNotMatch(
  pendingStoreSource,
  /token|authorization|Bearer|accessToken|refreshToken|providerTitleId|raw|message/i,
  'tracker pending sync store must not persist tokens, provider title ids, raw messages, or authorization material',
)
assert.match(
  indexSource,
  /import \{ TrackerPendingProgressDrainSummary, TrackerProgressSyncService \} from '\.\.\/model\/TrackerProgressSyncService'/,
  'Index must import tracker progress sync service for app-open pending progress recovery',
)
assert.match(
  indexSource,
  /pendingTrackerProgressChecked: boolean = false[\s\S]*triggerPendingTrackerProgressSync\(context: common\.UIAbilityContext\)[\s\S]*new TrackerProgressSyncService\(context\)\.retryPendingProgress\(10\)[\s\S]*this\.triggerPendingTrackerProgressSync\(context\)/,
  'Index must run a bounded app-open drain for retained tracker progress',
)
assert.match(
  indexSource,
  /step=app_open_pending_progress scanned=[\s\S]*synced=[\s\S]*retained=[\s\S]*failed=[\s\S]*skipped=/,
  'Index pending tracker progress recovery logs must expose only aggregate counts',
)
assert.doesNotMatch(
  indexSource,
  /\[TrackerSync\] step=app_open_pending_progress[^\n]*(token|authorization|Bearer|providerTitleId|comic=|chapter=|message=)/i,
  'Index pending tracker progress recovery logs must not leak tokens, provider ids, local ids, or raw errors',
)
assert.match(
  mangaDetailPageSource,
  /import \{[\s\S]*TrackerProgressSyncReason,[\s\S]*TrackerProgressSyncService[\s\S]*\} from '..\/model\/TrackerProgressSyncService'/,
  'MangaDetailPage must import the tracker progress sync service for explicit manual sync',
)
assert.match(
  mangaDetailPageSource,
  /syncTrackerProgressNow\(\): Promise<void>[\s\S]*readerSessionStore\.getProgress\(this\.currentComicId\(\)\)[\s\S]*pushReadingProgress\([\s\S]*progress,[\s\S]*this\.allChapterIds\(\),[\s\S]*'manual'/,
  'MangaDetailPage manual tracker sync must push the current reader progress with the manual trigger',
)
assert.match(
  mangaDetailPageSource,
  /manga_detail_menu_sync_tracker[\s\S]*this\.syncTrackerProgressNow\(\)/,
  'MangaDetailPage more menu must expose a real manual tracker sync action',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /\[TrackerSync\] step=manual_progress[^\n]*(token|authorization|Bearer|providerTitleId|comic=|chapter=|message=)/i,
  'MangaDetailPage manual tracker sync logs must not leak tokens, provider ids, local ids, or raw errors',
)

console.log('tracker progress sync service checks PASS')
