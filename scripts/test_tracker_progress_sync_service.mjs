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
const trackerSettingsPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/TrackerSettingsPage.ets'), 'utf8')

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
  /pushReadingProgress\([\s\S]*trigger === 'on_chapter_complete' && !progress\.completed[\s\S]*strategy_not_due[\s\S]*trigger !== 'manual' && preferences\.updateStrategy !== trigger/,
  'tracker progress push must not send normal page-turn progress through the chapter-complete strategy',
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
  /readAccessToken\(account: TrackerAccount, providerId: TrackerProviderId\)[\s\S]*secretStore\.readToken\(\{[\s\S]*providerId,[\s\S]*secretKind: 'access_token'[\s\S]*decodeTrackerSecretBytes\(tokenBytes\)\.trim\(\)/,
  'tracker progress sync must read the mapped provider access token from secure storage and decode only the returned byte range',
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
  /await this\.pendingStore\.removeProgressForComic\(mapping\.providerId, progress\.comicId\)/,
  'successful tracker progress push must clear retained pending sync items for the same provider/comic',
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
  /retryPendingProgress\(limit: number = 20[\s\S]*const preferences = await this\.preferencesStore\(\)\.load\(\)[\s\S]*!preferences\.autoSyncEnabled[\s\S]*readingProgressFromPendingEntry\(entry, now\)[\s\S]*this\.pushReadingProgress\(progress, entry\.chapterIds, 'manual', now, entry\.providerId\)[\s\S]*summary\.syncedCount \+= 1/,
  'tracker progress sync service must expose a bounded manual drain path for retained offline progress while respecting the auto-sync master switch',
)
assert.match(
  source,
  /const syncedComicKeys: string\[\] = \[\][\s\S]*const comicKey = `\$\{entry\.providerId\}:\$\{entry\.comicId\}`[\s\S]*syncedComicKeys\.includes\(comicKey\)[\s\S]*summary\.skippedCount \+= 1[\s\S]*syncedComicKeys\.push\(comicKey\)/,
  'tracker pending retry must skip stale older entries for a provider/comic after a newer pending progress syncs',
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
  /removeProgressForComic\(providerId: TrackerProviderId, comicId: ComicId\): Promise<number>[\s\S]*entry\.providerId !== providerId \|\| entry\.comicId !== comicId[\s\S]*await this\.savePendingProgress\(next\)/,
  'tracker pending sync store must remove stale entries by provider/comic after a successful sync',
)
assert.match(
  pendingStoreSource,
  /removeProgressForProvider\(providerId: TrackerProviderId\): Promise<number>[\s\S]*entry\.providerId !== providerId[\s\S]*await this\.savePendingProgress\(next\)/,
  'tracker pending sync store must remove all provider entries after a successful disconnect',
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
  /localProgressFromTrackerResult\(result: TrackerProgressSyncResult\): ReadingProgress \| undefined[\s\S]*result\.providerProgress === undefined \|\| result\.providerProgress <= 0[\s\S]*Math\.floor\(result\.providerProgress\) - 1[\s\S]*completedProgressForChapter\(chapterIds\[chapterIndex\]\)/,
  'MangaDetailPage must convert pulled tracker chapter progress into a completed local reader progress row',
)
assert.match(
  mangaDetailPageSource,
  /pullTrackerProgressNow\(\): Promise<void>[\s\S]*pullReadingProgress\(this\.currentComicId\(\)\)[\s\S]*localProgressFromTrackerResult\(result\)[\s\S]*readerSessionStore\.saveProgress\(progress\)[\s\S]*applyChapterStatesToCurrent\(\)/,
  'MangaDetailPage tracker pull must fetch mapped remote progress, save local reader progress, and refresh chapter state',
)
assert.match(
  mangaDetailPageSource,
  /manga_detail_menu_pull_tracker[\s\S]*this\.pullTrackerProgressNow\(\)/,
  'MangaDetailPage more menu must expose a real pull-tracker-progress action',
)
assert.match(
  mangaDetailPageSource,
  /latestTrackableMarkedReadProgress\(chapterIds: string\[\]\): ReadingProgress \| undefined[\s\S]*const currentProgress = this\.readerSessionStore\.getProgress\(this\.currentComicId\(\)\)[\s\S]*bestIndex < currentIndex[\s\S]*completedProgressForChapter\(bestChapterId\)/,
  'MangaDetailPage marked-read tracker sync must choose the latest marked chapter and avoid pushing older progress',
)
assert.match(
  mangaDetailPageSource,
  /syncMarkedReadTrackerProgress\(chapterIds: string\[\]\): void[\s\S]*pushReadingProgress\([\s\S]*progress,[\s\S]*this\.allChapterIds\(\),[\s\S]*'on_chapter_complete'[\s\S]*step=marked_read_progress/,
  'MangaDetailPage marked-read tracker sync must push completed chapter progress through the normal chapter-complete strategy',
)
assert.match(
  mangaDetailPageSource,
  /markChapterReadState\(chapterId: string, isRead: boolean\)[\s\S]*if \(isRead\) \{[\s\S]*this\.syncMarkedReadTrackerProgress\(\[chapterId\]\)[\s\S]*showToast/,
  'MangaDetailPage per-chapter mark-read must trigger tracker sync after local state refresh',
)
assert.match(
  mangaDetailPageSource,
  /markVisibleChaptersReadState\(chapterIds: string\[\], isRead: boolean\)[\s\S]*if \(isRead\) \{[\s\S]*this\.syncMarkedReadTrackerProgress\(targetIds\)[\s\S]*showToast/,
  'MangaDetailPage visible batch mark-read must trigger one bounded tracker sync from the visible target set',
)
assert.match(
  mangaDetailPageSource,
  /manga_detail_menu_sync_tracker[\s\S]*this\.syncTrackerProgressNow\(\)/,
  'MangaDetailPage more menu must expose a real manual tracker sync action',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /\[TrackerSync\] step=(manual_progress|marked_read_progress|manual_pull_progress)[^\n]*(token|authorization|Bearer|providerTitleId|comic=|chapter=|message=)/i,
  'MangaDetailPage tracker sync logs must not leak tokens, provider ids, local ids, or raw errors',
)

assert.match(
  trackerSettingsPageSource,
  /import \{[\s\S]*summarizeTrackerPendingProgress,[\s\S]*TrackerPendingProgressSummary,[\s\S]*TrackerPendingSyncStore,[\s\S]*\} from '..\/model\/TrackerPendingSyncStore'/,
  'TrackerSettingsPage must import pending tracker queue summary support',
)
assert.match(
  trackerSettingsPageSource,
  /import \{[\s\S]*TrackerPendingProgressDrainSummary,[\s\S]*TrackerProgressSyncService,[\s\S]*\} from '..\/model\/TrackerProgressSyncService'/,
  'TrackerSettingsPage must import the tracker pending retry service',
)
assert.match(
  trackerSettingsPageSource,
  /pendingSummary: TrackerPendingProgressSummary[\s\S]*pendingRetryBusy: boolean = false/,
  'TrackerSettingsPage must keep visible pending progress and retry state',
)
assert.match(
  trackerSettingsPageSource,
  /loadPendingProgressSummary\(\): void[\s\S]*this\.pendingSyncStore\(\)\.loadPendingProgress\(\)[\s\S]*summarizeTrackerPendingProgress\(entries\)/,
  'TrackerSettingsPage must load pending tracker progress from the durable queue',
)
assert.match(
  trackerSettingsPageSource,
  /retryPendingProgressNow\(\): void[\s\S]*new TrackerProgressSyncService\(this\.context\(\)\)\.retryPendingProgress\(20\)[\s\S]*tracker_pending_retry_done[\s\S]*this\.loadPendingProgressSummary\(\)/,
  'TrackerSettingsPage must expose bounded manual retry and refresh pending queue state',
)
assert.match(
  trackerSettingsPageSource,
  /clearPendingProgressNow\(\): void[\s\S]*this\.pendingSyncStore\(\)\.clear\(\)[\s\S]*tracker_pending_clear_done[\s\S]*this\.loadPendingProgressSummary\(\)/,
  'TrackerSettingsPage must expose a clear action for retained pending tracker progress',
)
assert.match(
  trackerSettingsPageSource,
  /confirmClearPendingProgress\(\): void[\s\S]*showAlertDialog\(\{[\s\S]*tracker_pending_clear_confirm_title[\s\S]*tracker_pending_clear_confirm_message[\s\S]*primaryButton:[\s\S]*common_clear[\s\S]*this\.clearPendingProgressNow\(\)/,
  'TrackerSettingsPage must confirm before clearing retained pending tracker progress',
)
assert.match(
  trackerSettingsPageSource,
  /step=settings_pending_retry scanned=\$\{summary\.scannedCount\} synced=\$\{summary\.syncedCount\} retained=\$\{summary\.retainedCount\} failed=\$\{summary\.failedCount\} skipped=\$\{summary\.skippedCount\}/,
  'TrackerSettingsPage pending retry logs must expose only aggregate counts',
)
assert.doesNotMatch(
  trackerSettingsPageSource,
  /\[TrackerSync\] step=settings_pending_(loaded|retry|retry_failed|clear|clear_failed)[^\n]*(token|authorization|Bearer|providerTitleId|comic=|chapter=|message=)/i,
  'TrackerSettingsPage pending progress logs must not leak tokens, provider ids, local ids, or raw errors',
)
assert.match(
  trackerSettingsPageSource,
  /PendingProgressCard\(\)[\s\S]*tracker_pending_title[\s\S]*tracker_pending_message[\s\S]*this\.retryPendingProgressNow\(\)[\s\S]*this\.confirmClearPendingProgress\(\)[\s\S]*this\.pendingProgressText\(\)[\s\S]*this\.PendingProgressCard\(\)/,
  'TrackerSettingsPage must render pending retry and clear actions before mapping review',
)

console.log('tracker progress sync service checks PASS')
