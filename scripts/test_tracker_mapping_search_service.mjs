import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const source = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerMappingSearchService.ets'), 'utf8')
const modelsSource = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerModels.ets'), 'utf8')
const aniListClientSource = readFileSync(resolve(root, 'entry/src/main/ets/model/AniListTrackerClient.ets'), 'utf8')
const myAnimeListClientSource = readFileSync(resolve(root, 'entry/src/main/ets/model/MyAnimeListTrackerClient.ets'), 'utf8')
const mangaDetailPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets'), 'utf8')
const baseStringsSource = readFileSync(resolve(root, 'entry/src/main/resources/base/element/string.json'), 'utf8')
const enStringsSource = readFileSync(resolve(root, 'entry/src/main/resources/en_US/element/string.json'), 'utf8')
const zhStringsSource = readFileSync(resolve(root, 'entry/src/main/resources/zh_CN/element/string.json'), 'utf8')

assert.match(
  source,
  /export class TrackerMappingSearchService/,
  'tracker mapping search service must exist',
)
assert.match(
  source,
  /constructor\(context: common\.UIAbilityContext, options: TrackerMappingSearchServiceOptions = \{\}\)[\s\S]*new AssetStoreTrackerCredentialSecretStore\(\)[\s\S]*options\.aniListClient \?\? new AniListTrackerClient\(new HarmonyAniListTrackerHttpAdapter\(\)\)[\s\S]*options\.myAnimeListClient \?\? new MyAnimeListTrackerClient\(new HarmonyMyAnimeListTrackerHttpAdapter\(\)\)/,
  'mapping search service must default to secure storage and real AniList/MyAnimeList clients while accepting injected fakes',
)
assert.match(
  source,
  /refreshComicMappingCandidates\([\s\S]*comic: Comic,[\s\S]*preferredProviderId\?: TrackerProviderId,[\s\S]*TrackerMappingSearchSummary/,
  'mapping search service must expose a reusable comic-level candidate refresh entrypoint',
)
assert.match(
  source,
  /const query = this\.searchQueryForComic\(comic\)[\s\S]*query\.length === 0[\s\S]*query_missing/,
  'mapping search must fail closed when the comic has no searchable title',
)
assert.match(
  source,
  /searchableProviderIds\(preferences: TrackerPreferences, preferredProviderId\?: TrackerProviderId\)[\s\S]*account\.status !== 'connected'[\s\S]*preferredProviderId !== undefined && account\.providerId !== preferredProviderId[\s\S]*this\.isSupportedSearchProvider\(account\.providerId\)/,
  'mapping search must only scan connected accounts for the requested implemented providers',
)
assert.match(
  source,
  /isSupportedSearchProvider\(providerId: TrackerProviderId\): boolean \{[\s\S]*providerId === 'anilist' \|\| providerId === 'myanimelist'/,
  'mapping search must currently limit provider search to implemented AniList/MyAnimeList clients',
)
assert.match(
  source,
  /existing !== undefined && existing\.mappingState === 'confirmed' && existing\.userConfirmed[\s\S]*confirmed_mapping_exists/,
  'mapping search must not overwrite user-confirmed mappings',
)
assert.match(
  source,
  /findConnectedAccount\(preferences[\s\S]*account\.providerId === providerId && account\.status === 'connected'/,
  'mapping search must require a connected account before provider lookup',
)
assert.match(
  source,
  /readAccessToken\(account: TrackerAccount, providerId: TrackerProviderId\)[\s\S]*secretStore\.readToken\(\{[\s\S]*providerId,[\s\S]*accountKey: account\.credentialAccountKey,[\s\S]*secretKind: 'access_token'[\s\S]*buffer\.from\(tokenBytes\.buffer\)\.toString\('utf-8'\)/,
  'mapping search must read provider credentials from secure storage at use time',
)
assert.match(
  source,
  /hasSearchClient\(providerId: TrackerProviderId\)[\s\S]*providerId === 'anilist'[\s\S]*this\.aniListClient !== undefined[\s\S]*providerId === 'myanimelist'[\s\S]*this\.myAnimeListClient !== undefined/,
  'mapping search must fail closed when no provider search client is available',
)
assert.match(
  source,
  /searchProvider\([\s\S]*providerId === 'myanimelist'[\s\S]*myAnimeListClient\.searchManga\(accessToken, query, 1, 8\)[\s\S]*aniListClient\.searchManga\(accessToken, query, 1, 8\)/,
  'mapping search must call existing provider manga search APIs for MAL and AniList',
)
assert.match(
  source,
  /bestCandidate\(query, providerResult\.value\)[\s\S]*results_empty[\s\S]*ComicTrackerMapping = \{[\s\S]*mappingState: 'candidate'[\s\S]*userConfirmed: false[\s\S]*createdAt: existing\?\.createdAt \?\? now,[\s\S]*updatedAt: now[\s\S]*upsertComicMapping\(mapping\)/,
  'mapping search must persist the best provider result as an unconfirmed candidate mapping',
)
assert.match(
  source,
  /candidateConfidence\(query: string, candidate: TrackerTitleSearchCandidate\)[\s\S]*return 0\.96[\s\S]*return 0\.9[\s\S]*return 0\.82[\s\S]*return 0\.78[\s\S]*return 0\.62/,
  'mapping search must score exact, native-title, partial, and fallback candidates deterministically',
)
assert.match(
  source,
  /TrackerMappingSearchSummary[\s\S]*scannedCount[\s\S]*mappedCount[\s\S]*skippedCount[\s\S]*failedCount[\s\S]*results/,
  'mapping search must return aggregate counts suitable for UI and background callers',
)
assert.doesNotMatch(
  source,
  /console\.(log|info|warn|error)\([^)]*(token|authorization|Bearer|accessToken|providerTitleId|comicId|query)/i,
  'mapping search must not log tokens, local ids, provider title ids, or search queries',
)
assert.doesNotMatch(
  source,
  /store\.put\([^)]*(token|secret|authorization|Bearer|accessToken)|JSON\.stringify\([^)]*(token|secret|authorization|Bearer|accessToken)/i,
  'mapping search must not persist OAuth material',
)
assert.match(
  modelsSource,
  /upsertComicMapping\(mapping: ComicTrackerMapping\)[\s\S]*filter\(\(item: ComicTrackerMapping\): boolean => \{[\s\S]*item\.comicId !== mapping\.comicId\.trim\(\) \|\| item\.providerId !== mapping\.providerId[\s\S]*saveComicMappings\(nextMappings\)/,
  'mapping search must rely on the shared mapping upsert path for dedupe and normalization',
)
assert.match(
  aniListClientSource,
  /searchManga\(accessToken: string, query: string, page: number = 1, perPage: number = 10\)/,
  'AniList client must expose authenticated manga search for mapping candidates',
)
assert.match(
  myAnimeListClientSource,
  /searchManga\(accessToken: string, query: string, page: number = 1, limit: number = 10\)/,
  'MyAnimeList client must expose authenticated manga search for mapping candidates',
)
assert.match(
  mangaDetailPageSource,
  /import \{[\s\S]*TrackerMappingSearchReason,[\s\S]*TrackerMappingSearchService,[\s\S]*TrackerMappingSearchSummary,[\s\S]*\} from '..\/model\/TrackerMappingSearchService'/,
  'MangaDetailPage must import the tracker mapping search service for manual candidate refresh',
)
assert.match(
  mangaDetailPageSource,
  /trackerMappingBusy: boolean = false[\s\S]*refreshTrackerMappingCandidates\(\): Promise<void>[\s\S]*new TrackerMappingSearchService\(context\)\.refreshComicMappingCandidates\(comic\)/,
  'MangaDetailPage must expose a guarded manual candidate refresh path backed by the mapping search service',
)
assert.match(
  mangaDetailPageSource,
  /this\.libraryStore\?\.getComic\(this\.currentComicId\(\)\) \?\?[\s\S]*comicFromSourceManga\(this\.manga, this\.chapters, this\.currentComicId\(\)\)/,
  'manual tracker candidate refresh must work for both library-backed and source-detail comics',
)
assert.match(
  mangaDetailPageSource,
  /manga_detail_menu_find_tracker_mapping[\s\S]*this\.refreshTrackerMappingCandidates\(\)[\s\S]*manga_detail_menu_sync_tracker/,
  'MangaDetailPage more menu must expose tracker candidate search before explicit progress sync',
)
assert.match(
  mangaDetailPageSource,
  /step=manual_candidate_refresh scanned=\$\{summary\.scannedCount\} mapped=\$\{summary\.mappedCount\} failed=\$\{summary\.failedCount\} skipped=\$\{summary\.skippedCount\}/,
  'manual tracker candidate refresh logs must expose only aggregate counts',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /\[TrackerMapping\] step=manual_candidate_refresh[^\n]*(token|authorization|Bearer|accessToken|providerTitleId|comic=|chapter=|query=|message=)/i,
  'manual tracker candidate refresh logs must not leak tokens, provider ids, local ids, queries, or raw errors',
)
assert.match(
  mangaDetailPageSource,
  /trackerMappingSkippedText\(reason: TrackerMappingSearchReason \| undefined\)[\s\S]*account_missing[\s\S]*credential_missing[\s\S]*confirmed_mapping_exists[\s\S]*results_empty[\s\S]*query_missing/,
  'manual tracker candidate refresh must map service reasons to user-facing copy',
)
;[
  baseStringsSource,
  enStringsSource,
  zhStringsSource,
].forEach((stringsSource, index) => {
  assert.match(stringsSource, /manga_detail_menu_find_tracker_mapping/, `locale ${index} must include tracker candidate menu copy`)
  assert.match(stringsSource, /manga_detail_tracker_mapping_searching/, `locale ${index} must include tracker candidate loading copy`)
  assert.match(stringsSource, /manga_detail_tracker_mapping_found/, `locale ${index} must include tracker candidate success copy`)
  assert.match(stringsSource, /manga_detail_tracker_mapping_account_missing/, `locale ${index} must include tracker candidate account-missing copy`)
  assert.match(stringsSource, /manga_detail_tracker_mapping_confirmed_exists/, `locale ${index} must include tracker candidate confirmed copy`)
  assert.match(stringsSource, /manga_detail_tracker_mapping_not_found/, `locale ${index} must include tracker candidate empty copy`)
  assert.match(stringsSource, /manga_detail_tracker_mapping_failed/, `locale ${index} must include tracker candidate failure copy`)
})

console.log('tracker mapping search service checks PASS')
