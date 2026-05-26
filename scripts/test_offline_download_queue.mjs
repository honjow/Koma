import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const queueStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadQueueStore.ets')
const offlineDownloadStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadStore.ets')
const offlineDownloadServicePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadService.ets')
const downloadsPagePath = resolve(root, 'entry/src/main/ets/pages/DownloadsPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const constantsPath = resolve(root, 'entry/src/main/ets/common/Constants.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')
const chapterListSectionPath = resolve(root, 'entry/src/main/ets/components/ChapterListSection.ets')

assert.ok(existsSync(queueStorePath), 'OfflineDownloadQueueStore.ets must exist')
assert.ok(existsSync(downloadsPagePath), 'DownloadsPage.ets must exist')

const queueStoreSource = readFileSync(queueStorePath, 'utf8')
const offlineDownloadStoreSource = readFileSync(offlineDownloadStorePath, 'utf8')
const offlineDownloadServiceSource = readFileSync(offlineDownloadServicePath, 'utf8')
const downloadsPageSource = readFileSync(downloadsPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const constantsSource = readFileSync(constantsPath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const chapterListSectionSource = readFileSync(chapterListSectionPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

assertExport(queueStoreSource, 'OfflineDownloadQueueStore')
assertExport(queueStoreSource, 'OfflineDownloadQueueEntry')
assertExport(queueStoreSource, 'OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION')

assert.match(queueStoreSource, /OFFLINE_DOWNLOAD_QUEUE_FILE_NAME:\s*string = 'queue\.v1\.json'/, 'queue store must persist a schema-versioned queue document under files/downloads')
assert.match(queueStoreSource, /interface OfflineDownloadQueueDocument\s*{[\s\S]*schemaVersion:\s*number[\s\S]*entries:\s*OfflineDownloadQueueEntry\[\]/, 'queue document must include schemaVersion and entries')
assert.match(queueStoreSource, /export interface OfflineDownloadQueueEntry\s*{[\s\S]*comicId:[\s\S]*chapterId:[\s\S]*comicTitle\?:[\s\S]*chapterTitle\?:[\s\S]*status:\s*OfflineDownloadStatus[\s\S]*pageCount:\s*number[\s\S]*downloadedPageCount:\s*number[\s\S]*updatedAt:\s*number[\s\S]*failureReasonCode\?:\s*string/, 'queue entries must carry ids, title labels, status, counts, timestamp, and optional failure code')
assert.match(queueStoreSource, /fromManifest\([\s\S]*OfflineChapterDownloadManifest[\s\S]*OfflineDownloadQueueEntry/, 'queue store must map existing manifests into queue entries')
assert.match(queueStoreSource, /load\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*schemaVersion !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION/, 'queue load must enforce schema version and survive restart from disk')
assert.match(queueStoreSource, /saveDocument\([\s\S]*JSON\.stringify/, 'queue store must durably write queue records')
assert.match(queueStoreSource, /OFFLINE_DOWNLOAD_QUEUE_TEMP_FILE_NAME:\s*string = 'queue\.v1\.json\.tmp'/, 'queue store must use a temp queue file for replacement writes')
assert.match(queueStoreSource, /writeTextSync\(tempPath,[\s\S]*fs\.moveFileSync\(tempPath,\s*this\.queuePath,\s*0\)/, 'queue store must write the temp queue file then move it over the final queue file')
assert.match(queueStoreSource, /writeTextSync\([\s\S]*OpenMode\.TRUNC[\s\S]*fs\.fsyncSync/, 'queue temp write must flush the full JSON before replacing the durable queue')
assert.doesNotMatch(queueStoreSource, /writeTextSync\(this\.queuePath|openSync\(this\.queuePath,[\s\S]*OpenMode\.TRUNC|openSync\(path,[\s\S]*OpenMode\.TRUNC[\s\S]*writeTextSync\(this\.queuePath/, 'queue store must not directly truncate the final queue path')
assert.match(queueStoreSource, /upsert\([\s\S]*chapterId[\s\S]*saveDocument/, 'queue store must support durable upsert by comic/chapter')
assert.match(queueStoreSource, /remove\([\s\S]*chapterId[\s\S]*saveDocument/, 'queue store must support removing rows')
assert.match(queueStoreSource, /deleteChapterDownload\([\s\S]*remove\([\s\S]*OfflineDownloadStore/, 'queue store must support row removal with manifest/data cleanup')

for (const status of ['QUEUED', 'DOWNLOADING', 'DOWNLOADED', 'PARTIAL', 'FAILED', 'BLOCKED']) {
  assert.match(queueStoreSource, new RegExp(`OfflineDownloadStatus\\.${status}`), `queue store must use existing OfflineDownloadStatus.${status}`)
}

assert.match(offlineDownloadStoreSource, /deleteChapterDownload\([\s\S]*assertSafeOfflineDownloadRoot[\s\S]*(?:rmdir|rmdirSync|unlink|unlinkSync)/, 'offline download store must expose safe chapter cleanup under files/downloads')
assert.match(offlineDownloadStoreSource, /assertSafeOfflineDownloadRoot[\s\S]*hasTraversalSegment/, 'offline download safe path contract must remain present')

assert.match(offlineDownloadServiceSource, /new OfflineDownloadQueueStore\([\s\S]*downloadChapter\([\s\S]*queueStore\.upsert[\s\S]*OfflineDownloadStatus\.QUEUED[\s\S]*queueStore\.upsert[\s\S]*manifest/, 'download service must mirror queued/downloading/final status into the durable queue')

assert.match(settingsPageSource, /key: 'downloads', title: '下载管理'/, 'Settings must expose a Downloads row')
assert.match(settingsPageSource, /onOpenDownloads:\s*\(\) => void/, 'SettingsPage must accept a Downloads route callback')
assert.match(settingsPageSource, /row\.key === 'downloads'[\s\S]*this\.onOpenDownloads\(\)/, 'Settings Downloads row must open the route')
assert.match(constantsSource, /static readonly DOWNLOADS:\s*string = 'DownloadsPage'/, 'RouteName must define DownloadsPage')
assert.match(indexSource, /import \{ DownloadsPage \} from '\.\/DownloadsPage'/, 'Index must import DownloadsPage')
assert.match(indexSource, /name === RouteName\.DOWNLOADS[\s\S]*DownloadsPage\(\{[\s\S]*libraryStore: this\.libraryStore/, 'Index must route to DownloadsPage with the library store')
assert.match(indexSource, /onOpenDownloads:\s*\(\) => \{[\s\S]*this\.openSettingsSecondary\(RouteName\.DOWNLOADS\)/, 'Index must wire Settings Downloads callback to the top-level route')

assert.match(downloadsPageSource, /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20/, 'DownloadsPage must use secondary list scaffold bottom clearance')
assert.match(downloadsPageSource, /new OfflineDownloadQueueStore\(this\.context\(\)\.filesDir\)/, 'DownloadsPage must load queue from app files dir')
assert.match(downloadsPageSource, /this\.queueStore\(\)\.load\(\)/, 'DownloadsPage must load persisted queue entries')
assert.match(downloadsPageSource, /暂无下载任务/, 'DownloadsPage must show an explicit empty state')
assert.match(downloadsPageSource, /formatStatus\([\s\S]*queued[\s\S]*downloading[\s\S]*downloaded[\s\S]*partial[\s\S]*failed[\s\S]*blocked/, 'DownloadsPage must render all queue statuses')
assert.match(downloadsPageSource, /enum DownloadQueueFilter\s*{[\s\S]*QUEUED[\s\S]*DOWNLOADING[\s\S]*FAILED[\s\S]*BLOCKED[\s\S]*DOWNLOADED/, 'DownloadsPage must expose queue status filters')
assert.match(downloadsPageSource, /visibleEntries\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*DownloadQueueFilter\.FAILED[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*DownloadQueueFilter\.BLOCKED[\s\S]*OfflineDownloadStatus\.BLOCKED[\s\S]*DownloadQueueFilter\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.DOWNLOADED/, 'DownloadsPage filters must group failed/partial and keep blocked/downloaded explicit')
assert.match(downloadsPageSource, /FilterMenu\(\)[\s\S]*DownloadQueueFilter\.QUEUED[\s\S]*DownloadQueueFilter\.DOWNLOADING[\s\S]*DownloadQueueFilter\.FAILED[\s\S]*DownloadQueueFilter\.BLOCKED[\s\S]*DownloadQueueFilter\.DOWNLOADED/, 'DownloadsPage must provide user-visible queue filter controls')
assert.match(downloadsPageSource, /retryDownload\(entry: OfflineDownloadQueueEntry\)[\s\S]*OfflineDownloadService[\s\S]*downloadChapter/, 'DownloadsPage must retry failed/partial entries through OfflineDownloadService')
assert.match(downloadsPageSource, /canRetry\([\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL/, 'DownloadsPage must expose retry for failed and partial rows')
assert.doesNotMatch(downloadsPageSource, /canRetry\([\s\S]*OfflineDownloadStatus\.BLOCKED/, 'DownloadsPage must not expose misleading retry for blocked rows without page hydration')
assert.match(downloadsPageSource, /retryableEntries\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*this\.visibleEntries\(\)\.filter[\s\S]*this\.canRetry\(entry\)/, 'DownloadsPage batch retry must reuse canRetry so blocked rows are excluded')
assert.match(downloadsPageSource, /retryFailedDownloads\(\)[\s\S]*const targets = this\.retryableEntries\(\)[\s\S]*this\.runRetryBatch\(targets\)/, 'DownloadsPage must expose batch retry for failed/partial rows')
assert.match(downloadsPageSource, /removableCompletedFailedEntries\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL/, 'DownloadsPage must collect completed/failed rows for batch removal')
assert.match(downloadsPageSource, /runRemoveBatch\(targets: OfflineDownloadQueueEntry\[\]\)[\s\S]*deleteChapterDownload/, 'DownloadsPage batch remove must use queue cleanup instead of only hiding rows')
assert.doesNotMatch(downloadsPageSource, /retryableEntries\(\)[\s\S]*OfflineDownloadStatus\.BLOCKED/, 'DownloadsPage batch retry must not include blocked rows')
assert.match(downloadsPageSource, /blockedHelpText\(entry: OfflineDownloadQueueEntry\)[\s\S]*failureReasonCode === 'pages_missing'[\s\S]*打开漫画详情页后重试下载/, 'DownloadsPage must explain pages_missing blocked rows instead of offering a dead-end retry')
assert.match(downloadsPageSource, /removeDownload\(entry: OfflineDownloadQueueEntry\)[\s\S]*deleteChapterDownload/, 'DownloadsPage must remove queue rows and downloaded data where feasible')

assert.match(chapterListSectionSource, /export enum ChapterBatchDownloadMode\s*{[\s\S]*ALL_VISIBLE[\s\S]*FAILED_ONLY[\s\S]*NOT_DOWNLOADED/, 'ChapterListSection must define visible chapter batch download modes')
assert.match(chapterListSectionSource, /onDownloadChapter:\s*\(chapterId: string\) => void/, 'ChapterListSection must accept a per-chapter download callback')
assert.match(chapterListSectionSource, /onDownloadVisibleChapters:\s*\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\) => void/, 'ChapterListSection must accept a visible chapter batch download callback')
assert.match(chapterListSectionSource, /visibleChapterIds\(\):\s*string\[\][\s\S]*this\.sortedChapters\.map/, 'ChapterListSection batch actions must operate on the current visible sorted chapter list')
assert.match(chapterListSectionSource, /BatchDownloadMenu\(\)[\s\S]*ChapterBatchDownloadMode\.ALL_VISIBLE[\s\S]*ChapterBatchDownloadMode\.FAILED_ONLY[\s\S]*ChapterBatchDownloadMode\.NOT_DOWNLOADED/, 'ChapterListSection must expose all visible/failed/not downloaded batch actions')
assert.match(chapterListSectionSource, /Button\('↓'\)[\s\S]*this\.onDownloadChapter\(chapter\.id\)/, 'Chapter rows must expose a download action without replacing open-to-read')
assert.match(chapterListSectionSource, /onClick\(\(\) => \{[\s\S]*this\.onOpenChapter\(chapter\.id\)/, 'Chapter row click-to-read behavior must remain')
assert.match(chapterListSectionSource, /Row\(\{ space: 10 \}\) \{[\s\S]*Column\(\{ space: 4 \}\)[\s\S]*\.layoutWeight\(1\)[\s\S]*\.onClick\(\(\) => \{[\s\S]*this\.onOpenChapter\(chapter\.id\)[\s\S]*Button\('↓'\)[\s\S]*this\.onDownloadChapter\(chapter\.id\)/, 'Chapter open handler must be isolated to the left content area before the download button')
assert.doesNotMatch(chapterListSectionSource, /\.opacity\(chapter\.isRead \? 0\.68 : 1\)\s*\.onClick\(\(\) => \{[\s\S]*this\.onOpenChapter\(chapter\.id\)/, 'Chapter outer row must not open the reader when tapping the download button')
assert.match(mangaDetailPageSource, /handleDownloadChapter\(chapterId\?: string\)[\s\S]*const resolvedChapterId = chapterId \?\? this\.firstChapterId\(\)/, 'MangaDetail download handler must accept a specific chapter id')
assert.match(mangaDetailPageSource, /batchDownloadChapterIds\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\)[\s\S]*ChapterBatchDownloadMode\.FAILED_ONLY[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*ChapterBatchDownloadMode\.NOT_DOWNLOADED[\s\S]*OfflineDownloadStatus\.DOWNLOADED/, 'MangaDetailPage must filter visible chapter batch actions by existing durable summaries')
assert.match(mangaDetailPageSource, /handleDownloadVisibleChapters\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\)[\s\S]*service\.downloadChapter\(comic, chapterId/, 'MangaDetailPage must batch queue visible chapters through OfflineDownloadService')
assert.doesNotMatch(mangaDetailPageSource, /handleDownloadVisibleChapters\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\)[\s\S]*ensureSourceChapterPages[\s\S]*private async ensureSourceChapterPages/, 'MangaDetailPage batch download must not pretend source pages are hydrated before queuing; missing pages should become blocked rows')
assert.match(mangaDetailPageSource, /ChapterListSection\(\{[\s\S]*onOpenChapter:[\s\S]*onDownloadChapter:\s*\(chapterId: string\) => \{[\s\S]*this\.handleDownloadChapter\(chapterId\)/, 'MangaDetailPage must wire chapter row download action')
assert.match(mangaDetailPageSource, /ChapterListSection\(\{[\s\S]*onDownloadVisibleChapters:\s*\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\) => \{[\s\S]*this\.handleDownloadVisibleChapters\(chapterIds, mode\)/, 'MangaDetailPage must wire visible chapter batch download action')

console.log('offline download queue static checks passed')
