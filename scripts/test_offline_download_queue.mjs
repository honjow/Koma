import assert from 'node:assert/strict'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const queueStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadQueueStore.ets')
const offlineDownloadStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadStore.ets')
const offlineDownloadServicePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadService.ets')
const offlineDownloadNotificationPath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadNotificationStore.ets')
const readerPageSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const downloadsPagePath = resolve(root, 'entry/src/main/ets/pages/DownloadsPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const constantsPath = resolve(root, 'entry/src/main/ets/common/Constants.ets')
const routerHelperPath = resolve(root, 'entry/src/main/ets/common/RouterHelper.ets')
const entryAbilityPath = resolve(root, 'entry/src/main/ets/entryability/EntryAbility.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')
const chapterListSectionPath = resolve(root, 'entry/src/main/ets/components/ChapterListSection.ets')

assert.ok(existsSync(queueStorePath), 'OfflineDownloadQueueStore.ets must exist')
assert.ok(existsSync(downloadsPagePath), 'DownloadsPage.ets must exist')

const queueStoreSource = readFileSync(queueStorePath, 'utf8')
const offlineDownloadStoreSource = readFileSync(offlineDownloadStorePath, 'utf8')
const offlineDownloadServiceSource = readFileSync(offlineDownloadServicePath, 'utf8')
const offlineDownloadNotificationSource = readFileSync(offlineDownloadNotificationPath, 'utf8')
const readerPageSourceAdapterSource = readFileSync(readerPageSourceAdapterPath, 'utf8')
const downloadsPageSource = readFileSync(downloadsPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const constantsSource = readFileSync(constantsPath, 'utf8')
const routerHelperSource = readFileSync(routerHelperPath, 'utf8')
const entryAbilitySource = readFileSync(entryAbilityPath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const chapterListSectionSource = readFileSync(chapterListSectionPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

function assertFunctionDoesNotContain(source, name, pattern, message) {
  const start = source.indexOf(`private ${name}(`)
  assert.notEqual(start, -1, `${name} must exist`)
  const next = source.indexOf('\n  private ', start + 1)
  const body = source.slice(start, next === -1 ? source.length : next)
  assert.doesNotMatch(body, pattern, message)
}

assertExport(queueStoreSource, 'OfflineDownloadQueueStore')
assertExport(queueStoreSource, 'OfflineDownloadQueueEntry')
assertExport(queueStoreSource, 'OfflineDownloadQueuePreferences')
assertExport(queueStoreSource, 'OfflineDownloadQueueSummary')
assertExport(queueStoreSource, 'OfflineDownloadQueueRecoverySummary')
assertExport(queueStoreSource, 'summarizeOfflineDownloadQueue')
assertExport(queueStoreSource, 'OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION')
assertExport(queueStoreSource, 'OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS')
assertExport(queueStoreSource, 'OFFLINE_DOWNLOAD_FAILURE_REASON_CODES')
assertExport(queueStoreSource, 'normalizeOfflineDownloadFailureReasonCode')

assert.match(queueStoreSource, /OFFLINE_DOWNLOAD_QUEUE_FILE_NAME:\s*string = 'queue\.v1\.json'/, 'queue store must persist a schema-versioned queue document under files/downloads')
assert.match(queueStoreSource, /OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS:\s*number\[\] = \[1, 2, 3\]/, 'queue store must expose a small foreground concurrency limit enum')
assert.match(queueStoreSource, /DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES:[\s\S]*foregroundConcurrencyLimit:\s*1[\s\S]*isPaused:\s*false[\s\S]*wifiOnly:\s*false/, 'queue preferences must default to conservative foreground concurrency, running state, and unrestricted network')
assert.match(queueStoreSource, /export interface OfflineDownloadQueuePreferences\s*{[\s\S]*foregroundConcurrencyLimit:\s*number[\s\S]*isPaused:\s*boolean[\s\S]*wifiOnly:\s*boolean/, 'queue preferences must carry foreground concurrency, pause state, and Wi-Fi-only state')
assert.match(queueStoreSource, /export interface OfflineDownloadQueueSummary\s*{[\s\S]*totalCount:\s*number[\s\S]*queuedCount:\s*number[\s\S]*downloadingCount:\s*number[\s\S]*downloadedCount:\s*number[\s\S]*partialCount:\s*number[\s\S]*failedCount:\s*number[\s\S]*blockedCount:\s*number[\s\S]*pageCount:\s*number[\s\S]*downloadedPageCount:\s*number/, 'queue summary must expose status and page progress counts')
assert.match(queueStoreSource, /interface OfflineDownloadQueueDocument\s*{[\s\S]*schemaVersion:\s*number[\s\S]*preferences\?:\s*OfflineDownloadQueuePreferences[\s\S]*entries:\s*OfflineDownloadQueueEntry\[\]/, 'queue document must include schemaVersion, optional preferences, and entries')
assert.match(queueStoreSource, /export interface OfflineDownloadQueueEntry\s*{[\s\S]*comicId:[\s\S]*chapterId:[\s\S]*comicTitle\?:[\s\S]*chapterTitle\?:[\s\S]*status:\s*OfflineDownloadStatus[\s\S]*pageCount:\s*number[\s\S]*downloadedPageCount:\s*number[\s\S]*updatedAt:\s*number[\s\S]*failureReasonCode\?:\s*string/, 'queue entries must carry ids, title labels, status, counts, timestamp, and optional failure code')
assert.match(queueStoreSource, /OFFLINE_DOWNLOAD_FAILURE_REASON_CODES: string\[\] = \[[\s\S]*'paused'[\s\S]*'wifi_only'[\s\S]*'download_interrupted'[\s\S]*'manifest_malformed'[\s\S]*'identity_mismatch'[\s\S]*'unsafe_page_path'[\s\S]*'outside_chapter_dir'[\s\S]*'page_index_invalid'[\s\S]*'page_size_mismatch'[\s\S]*'comic_missing'[\s\S]*'page_fetch_failed'[\s\S]*\]/, 'queue store must keep a bounded allowlist of persisted failure reason codes, including safe manifest validation reasons')
assert.match(queueStoreSource, /function normalizeOfflineDownloadFailureReasonCode\(value: string \| undefined\): string \| undefined \{[\s\S]*OFFLINE_DOWNLOAD_FAILURE_REASON_CODES\.indexOf\(value\) >= 0 \? value : undefined[\s\S]*const failureReasonCode = normalizeOfflineDownloadFailureReasonCode\(entry\.failureReasonCode\)/, 'queue entry normalization must drop unknown failure reason text before it can reach UI or notifications')
assert.match(queueStoreSource, /fromManifest\([\s\S]*OfflineChapterDownloadManifest[\s\S]*OfflineDownloadQueueEntry/, 'queue store must map existing manifests into queue entries')
assert.match(queueStoreSource, /load\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*loadDocument\(\)\.entries[\s\S]*private loadDocument\(\): OfflineDownloadQueueDocument[\s\S]*schemaVersion !== OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION/, 'queue load must enforce schema version and survive restart from disk')
assert.match(queueStoreSource, /function shouldReconcileEntry\(entry: OfflineDownloadQueueEntry\): boolean \{[\s\S]*OfflineDownloadStatus\.DOWNLOADING[\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.PARTIAL/, 'queue manifest reconciliation must inspect stale running rows plus reader-ready downloaded or partial rows')
assert.match(queueStoreSource, /reconcileWithManifests\(\): OfflineDownloadQueueEntry\[\] \{[\s\S]*validateDownloadedChapter\(entry\.comicId, entry\.chapterId\)[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*entry\.status === OfflineDownloadStatus\.DOWNLOADING[\s\S]*download_interrupted[\s\S]*OfflineDownloadStatus\.FAILED/, 'queue store must downgrade corrupt, missing, or interrupted running manifests into failed queue rows')
assert.match(queueStoreSource, /reconcileWithManifests\(\): OfflineDownloadQueueEntry\[\] \{[\s\S]*if \(changed\) \{[\s\S]*saveDocument\(\{[\s\S]*preferences: document\.preferences[\s\S]*entries,/, 'queue manifest reconciliation must persist changed rows without dropping queue preferences')
assert.match(queueStoreSource, /recoverFromManifests\(\): Promise<OfflineDownloadQueueRecoverySummary>[\s\S]*scanDownloadedChapterManifests\(\)[\s\S]*entryFromManifestValidation\(validation\)[\s\S]*entries\.unshift\(recovered\)[\s\S]*preferences: document\.preferences/, 'queue recovery must rebuild lost queue rows from downloaded manifests without dropping queue preferences')
assert.match(queueStoreSource, /entryFromManifestValidation\(validation: OfflineDownloadManifestValidation\)[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*manifest\.status === OfflineDownloadStatus\.DOWNLOADING[\s\S]*download_interrupted[\s\S]*OfflineDownloadStatus\.FAILED/, 'queue recovery must map downloaded, partial, corrupt, and stale running manifest validation into honest queue statuses')
assert.match(queueStoreSource, /summarizeOfflineDownloadQueue\(entries: OfflineDownloadQueueEntry\[\]\): OfflineDownloadQueueSummary[\s\S]*summary\.totalCount \+= 1[\s\S]*summary\.downloadedPageCount \+= Math\.min\(normalized\.downloadedPageCount, normalized\.pageCount\)[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*summary\.partialCount \+= 1/, 'queue summary must derive total, partial, and bounded page progress from entries')
assert.match(queueStoreSource, /loadSummary\(\): OfflineDownloadQueueSummary[\s\S]*summarizeOfflineDownloadQueue\(this\.load\(\)\)/, 'queue store must expose a reusable persisted queue summary')
assert.match(queueStoreSource, /loadPreferences\(\):\s*OfflineDownloadQueuePreferences[\s\S]*loadDocument\(\)\.preferences/, 'queue store must load durable queue preferences')
assert.match(queueStoreSource, /normalizeForegroundConcurrencyLimit\(value: number\): number[\s\S]*OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS\.indexOf\(normalized\)[\s\S]*DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES\.foregroundConcurrencyLimit/, 'queue store must clamp concurrency preferences to the safe enum')
assert.match(queueStoreSource, /savePreferences\(preferences: OfflineDownloadQueuePreferences\): OfflineDownloadQueuePreferences[\s\S]*saveDocument\(\{[\s\S]*preferences: normalized[\s\S]*entries: document\.entries/, 'queue store must persist preferences without dropping queue entries')
assert.match(queueStoreSource, /setForegroundConcurrencyLimit\(limit: number\): OfflineDownloadQueuePreferences[\s\S]*normalizeForegroundConcurrencyLimit\(limit\)/, 'queue store must expose a concurrency preference setter')
assert.match(queueStoreSource, /pauseAllQueuedWork\(\):\s*OfflineDownloadQueuePreferences[\s\S]*preferences\.isPaused = true[\s\S]*savePreferences/, 'queue store must persist pause-all state')
assert.match(queueStoreSource, /resumeAllQueuedWork\(\):\s*OfflineDownloadQueuePreferences[\s\S]*preferences\.isPaused = false[\s\S]*savePreferences/, 'queue store must persist resume-all state')
assert.match(queueStoreSource, /setWifiOnly\(wifiOnly: boolean\): OfflineDownloadQueuePreferences[\s\S]*preferences\.wifiOnly = wifiOnly[\s\S]*savePreferences/, 'queue store must persist Wi-Fi-only download preference')
assert.match(queueStoreSource, /saveDocument\([\s\S]*JSON\.stringify/, 'queue store must durably write queue records')
assert.match(queueStoreSource, /OFFLINE_DOWNLOAD_QUEUE_TEMP_FILE_NAME:\s*string = 'queue\.v1\.json\.tmp'/, 'queue store must use a temp queue file for replacement writes')
assert.match(queueStoreSource, /writeTextSync\(tempPath,[\s\S]*fs\.moveFileSync\(tempPath,\s*this\.queuePath,\s*0\)/, 'queue store must write the temp queue file then move it over the final queue file')
assert.match(queueStoreSource, /writeTextSync\([\s\S]*OpenMode\.TRUNC[\s\S]*fs\.fsyncSync/, 'queue temp write must flush the full JSON before replacing the durable queue')
assert.doesNotMatch(queueStoreSource, /writeTextSync\(this\.queuePath|openSync\(this\.queuePath,[\s\S]*OpenMode\.TRUNC|openSync\(path,[\s\S]*OpenMode\.TRUNC[\s\S]*writeTextSync\(this\.queuePath/, 'queue store must not directly truncate the final queue path')
assert.match(queueStoreSource, /upsert\([\s\S]*chapterId[\s\S]*saveDocument/, 'queue store must support durable upsert by comic/chapter')
assert.match(queueStoreSource, /remove\([\s\S]*chapterId[\s\S]*saveDocument/, 'queue store must support removing rows')
assert.match(queueStoreSource, /upsert\(entry: OfflineDownloadQueueEntry\): OfflineDownloadQueueEntry \{[\s\S]*const document = this\.loadDocument\(\)[\s\S]*preferences: document\.preferences[\s\S]*entries,/, 'queue upsert must preserve existing queue preferences when only entries change')
assert.match(queueStoreSource, /remove\(comicId: ComicId, chapterId: string\): void \{[\s\S]*const document = this\.loadDocument\(\)[\s\S]*preferences: document\.preferences[\s\S]*entries,/, 'queue remove must preserve existing queue preferences when only entries change')
assert.match(queueStoreSource, /deleteChapterDownload\([\s\S]*const store = new OfflineDownloadStore\(this\.filesDir\)[\s\S]*await store\.deleteChapterDownload\(comicId, chapterId\)[\s\S]*this\.remove\(comicId, chapterId\)/, 'queue store must remove durable data before hiding the queue row')
assert.match(queueStoreSource, /removeComic\(comicId: ComicId\): number \{[\s\S]*const document = this\.loadDocument\(\)[\s\S]*item\.comicId !== comicId[\s\S]*preferences: document\.preferences[\s\S]*return removedCount/, 'queue store must remove all rows for a deleted comic while preserving preferences')
assert.match(queueStoreSource, /deleteComicDownloads\(comicId: ComicId\): Promise<number>[\s\S]*await store\.deleteComicDownloads\(comicId\)[\s\S]*return this\.removeComic\(comicId\)/, 'queue store must delete app-sandbox comic downloads before removing all queue rows')

for (const status of ['QUEUED', 'DOWNLOADING', 'DOWNLOADED', 'PARTIAL', 'FAILED', 'BLOCKED']) {
  assert.match(queueStoreSource, new RegExp(`OfflineDownloadStatus\\.${status}`), `queue store must use existing OfflineDownloadStatus.${status}`)
}

assert.match(offlineDownloadStoreSource, /deleteChapterDownload\([\s\S]*assertSafeOfflineDownloadRoot[\s\S]*(?:rmdir|rmdirSync|unlink|unlinkSync)/, 'offline download store must expose safe chapter cleanup under files/downloads')
assert.match(offlineDownloadStoreSource, /comicDir\(comicId: ComicId\): string[\s\S]*createOfflineDownloadStableHash\(comicId\)[\s\S]*assertSafeOfflineDownloadRoot/, 'offline download store must derive a safe per-comic download directory')
assert.match(offlineDownloadStoreSource, /deleteComicDownloads\(comicId: ComicId\): Promise<void>[\s\S]*const comicDir = this\.comicDir\(comicId\)[\s\S]*await this\.deleteDownloadDir\(comicDir\)/, 'offline download store must expose whole-comic cleanup under files/downloads')
assert.match(offlineDownloadStoreSource, /private async deleteDownloadDir\(targetDir: string\): Promise<void>[\s\S]*assertSafeOfflineDownloadRoot\(this\.filesDir, targetDir\)[\s\S]*fs\.listFile\(targetDir[\s\S]*sort\(compareDeepestPathFirst\)[\s\S]*await fs\.rmdir\(targetDir\)/, 'offline download directory cleanup must stay bounded and remove deepest children first')
assert.match(offlineDownloadStoreSource, /assertSafeOfflineDownloadRoot[\s\S]*hasTraversalSegment/, 'offline download safe path contract must remain present')
assertExport(offlineDownloadStoreSource, 'OfflineDownloadedChapterStatus')
assertExport(offlineDownloadStoreSource, 'OfflineDownloadManifestValidation')
assertExport(offlineDownloadStoreSource, 'OfflineDownloadManifestScanResult')
assert.match(offlineDownloadStoreSource, /export enum OfflineDownloadedChapterStatus\s*{[\s\S]*DOWNLOADED = 'downloaded'[\s\S]*PARTIAL = 'partial'[\s\S]*CORRUPT = 'corrupt'[\s\S]*MISSING = 'missing'/, 'offline manifest validation must classify downloaded, partial, corrupt, and missing')
assert.match(offlineDownloadStoreSource, /export interface OfflineChapterDownloadManifest\s*{[\s\S]*sourceKind\?: ComicSourceKind[\s\S]*sourceId\?: string[\s\S]*comicId:[\s\S]*seriesId:[\s\S]*chapterId:[\s\S]*pageCount:[\s\S]*pages:[\s\S]*integrityHash: string/, 'offline chapter manifests must identify source, series, chapter, page list, and integrity hash')
assert.match(offlineDownloadStoreSource, /function manifestIntegrityPayload[\s\S]*page\.pageIndex[\s\S]*page\.pageId[\s\S]*page\.fileName[\s\S]*page\.size[\s\S]*createManifestIntegrityHash/, 'offline manifest integrity must be deterministic from bounded identity and page metadata')
assert.match(offlineDownloadStoreSource, /validateDownloadedChapter\(comicId: ComicId, chapterId: string\): OfflineDownloadManifestValidation[\s\S]*manifest_missing[\s\S]*manifest_malformed[\s\S]*integrity_mismatch[\s\S]*page_file_missing/, 'offline store must expose reader-usable manifest discovery with missing, corrupt, and partial reasons')
assert.match(offlineDownloadStoreSource, /loadSummary\(comicId: ComicId, chapterId: string\): OfflineDownloadSummary \| undefined \{[\s\S]*const validation = this\.validateDownloadedChapter\(comicId, chapterId\)[\s\S]*OfflineDownloadedChapterStatus\.CORRUPT[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.PARTIAL/, 'offline summary must reuse manifest validation so detail and batch download UI cannot trust corrupt or incomplete downloaded manifests')
assert.match(offlineDownloadStoreSource, /isChapterFullyDownloaded\(comicId: ComicId, chapterId: string\): boolean \{[\s\S]*validateDownloadedChapter\(comicId, chapterId\)[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*availablePageCount === validation\.pageCount[\s\S]*missingPageCount === 0/, 'offline store must expose a strict fully-downloaded predicate for completion-only flows')
assert.match(offlineDownloadStoreSource, /typeof parsed\.seriesId !== 'string'[\s\S]*typeof parsed\.integrityHash !== 'string'/, 'offline manifest parsing must validate seriesId and integrityHash types instead of defaulting unsafe legacy values')
assert.doesNotMatch(offlineDownloadStoreSource, /parsed\.integrityHash = ''/, 'offline manifest parsing must not default a missing integrity hash to an empty validated value')
assert.match(offlineDownloadStoreSource, /function parseOfflineDownloadStatus\(value: string\): OfflineDownloadStatus \| undefined[\s\S]*OfflineDownloadStatus\.QUEUED[\s\S]*OfflineDownloadStatus\.DOWNLOADING[\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.BLOCKED/, 'offline manifest validation must parse persisted manifest.status through the production enum')
assert.match(offlineDownloadStoreSource, /const manifestStatus = parseOfflineDownloadStatus\(manifest\.status\)[\s\S]*reasonCode: 'status_invalid'[\s\S]*!isReaderReadyOfflineDownloadStatus\(manifestStatus\)[\s\S]*reasonCode: 'status_not_reader_ready'[\s\S]*const chapterDir = this\.chapterDir/, 'offline manifest validation must reject invalid and non-reader-ready statuses before file availability can classify downloaded/partial')
assert.match(offlineDownloadStoreSource, /manifest\.integrityHash\.trim\(\)\.length === 0[\s\S]*reasonCode: 'integrity_missing'[\s\S]*createManifestIntegrityHash\(manifest\) !== manifest\.integrityHash/, 'offline manifest validation must reject empty integrity hashes before integrity comparison')
assert.match(offlineDownloadStoreSource, /if \(pageCount <= 0 \|\| manifest\.pages\.length === 0\)[\s\S]*reasonCode: pageCount <= 0 \? 'page_count_empty' : 'pages_missing'[\s\S]*status: missingPageCount === 0 \? OfflineDownloadedChapterStatus\.DOWNLOADED : OfflineDownloadedChapterStatus\.PARTIAL/, 'offline manifest validation must reject zero-page or empty-page manifests before downloaded/partial classification')
assert.match(offlineDownloadStoreSource, /saveManifest\(manifest: OfflineChapterDownloadManifest\)[\s\S]*assertSafeOfflineDownloadRoot\(this\.filesDir, page\.localPath\)[\s\S]*page\.localPath\.startsWith\(`\$\{chapterDir\}\/`\)[\s\S]*normalized\.integrityHash = createManifestIntegrityHash/, 'manifest saves must keep page paths bounded to the chapter dir and stamp integrity')
assert.match(offlineDownloadStoreSource, /recordPage\(manifest: OfflineChapterDownloadManifest, page: OfflineDownloadedPage\)[\s\S]*item\.pageId !== page\.pageId && item\.pageIndex !== page\.pageIndex/, 'recordPage must make duplicate page writes idempotent by page id or index')
assert.match(offlineDownloadStoreSource, /scanDownloadedChapterManifests\(\): Promise<OfflineDownloadManifestScanResult>[\s\S]*fs\.listFile\(this\.rootDir[\s\S]*pathBaseName\(entry\) !== OFFLINE_DOWNLOAD_MANIFEST_NAME[\s\S]*safeParseManifest[\s\S]*validateDownloadedChapter\(manifest\.comicId, manifest\.chapterId\)/, 'offline store must scan the downloads directory for manifest records and revalidate them through the production validator')
assert.match(offlineDownloadStoreSource, /scanDownloadedChapterManifests\(\): Promise<OfflineDownloadManifestScanResult>[\s\S]*assertSafeOfflineDownloadRoot\(this\.filesDir, manifestPath\)[\s\S]*skippedManifestCount \+= 1/, 'offline manifest scanning must stay bounded to the app download root and skip unsafe or malformed files')
assert.match(offlineDownloadStoreSource, /function matchesDownloadedPage\(page: OfflineDownloadedPage, pageId: string, pageIndex: number\): boolean \{[\s\S]*pageId\.trim\(\)\.length > 0[\s\S]*return page\.pageId === pageId[\s\S]*return page\.pageIndex === pageIndex[\s\S]*resolveDownloadedPage[\s\S]*matchesDownloadedPage\(item, pageId, pageIndex\)/, 'offline reader page resolution must prefer strict pageId matches and only use page index as an empty-id fallback')
assert.match(readerPageSourceAdapterSource, /options\?\.preferOffline !== false[\s\S]*createReaderOfflineDownloadRenderSource/, 'reader must keep offline resolution enabled by default')
assert.match(readerPageSourceAdapterSource, /localPath === undefined[\s\S]*isOfflineManifestReaderOwned\(validation\)[\s\S]*createReaderOfflineUnavailableSource\(config, pageIndex\)[\s\S]*createReaderSourceRuntimeRenderSource/, 'reader must stop at an honest offline placeholder for partial or corrupt downloaded chapters instead of falling through to remote/source runtime')
assert.match(readerPageSourceAdapterSource, /validation\.manifest === undefined && validation\.reasonCode === 'manifest_missing'[\s\S]*return undefined/, 'reader must allow normal online fallback only when no offline manifest exists')

assert.match(offlineDownloadServiceSource, /new OfflineDownloadQueueStore\([\s\S]*downloadChapter\([\s\S]*queueStore\.upsert[\s\S]*OfflineDownloadStatus\.QUEUED[\s\S]*queueStore\.upsert[\s\S]*manifest/, 'download service must mirror queued/downloading/final status into the durable queue')
assert.match(offlineDownloadServiceSource, /function manifestIdentityFromComic\(comic: Comic\): OfflineChapterManifestIdentity[\s\S]*sourceKind: comic\.sourceKind[\s\S]*sourceId: comic\.sourceRuntimeId \?\? comic\.remoteServerId \?\? comic\.sourceKind[\s\S]*seriesId: comic\.id/, 'download service must write source and series identity into chapter manifests without credentials')
assert.match(offlineDownloadServiceSource, /function reusableDownloadedPage\(pages: OfflineDownloadedPage\[\], pageId: string, pageIndex: number\): OfflineDownloadedPage \| undefined[\s\S]*pageId\.trim\(\)\.length > 0[\s\S]*return item\.pageId === pageId[\s\S]*return item\.pageIndex === pageIndex[\s\S]*fs\.accessSync\(page\.localPath\)/, 'download service must only reuse present page files that still match the requested page identity')
assert.match(offlineDownloadServiceSource, /const existingValidation = this\.store\.validateDownloadedChapter\(comic\.id, chapterId\)[\s\S]*existingValidation\.status === OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*existingValidation\.manifest !== undefined[\s\S]*queueStore\.upsert\(this\.queueStore\.fromManifest\(existingValidation\.manifest[\s\S]*step=download_reused[\s\S]*return existingValidation\.manifest[\s\S]*existingValidation\.status === OfflineDownloadedChapterStatus\.PARTIAL/, 'complete download retry must reuse the validated manifest instead of refetching pages')
assert.match(offlineDownloadServiceSource, /const existingValidation = this\.store\.validateDownloadedChapter\(comic\.id, chapterId\)[\s\S]*existingValidation\.status === OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*existingValidation\.manifest\.pages[\s\S]*const reusablePage = reusableDownloadedPage\(reusablePages, pageId, index\)[\s\S]*this\.store\.recordPage\(manifest, \{[\s\S]*localPath: reusablePage\.localPath[\s\S]*continue/, 'partial download retry must reuse validated existing pages and only fetch missing pages')
assert.match(offlineDownloadServiceSource, /const initialPreferences = this\.queueStore\.loadPreferences\(\)[\s\S]*this\.queueStore\.upsert\([\s\S]*const latestPreferences = this\.queueStore\.loadPreferences\(\)[\s\S]*const initialCanDownload = this\.canDownloadNow\(initialPreferences\)[\s\S]*const latestCanDownload = this\.canDownloadNow\(latestPreferences\)[\s\S]*if \(!initialCanDownload \|\| !latestCanDownload\)/, 'download service start guard must compare both initial and latest preferences after the queue upsert')
assert.match(offlineDownloadServiceSource, /const blockedReason = downloadBlockedReason\(!latestCanDownload \? latestPreferences : initialPreferences\)[\s\S]*OfflineDownloadStatus\.QUEUED/, 'download service must honor latest paused or non-Wi-Fi foreground queue state before starting work')
assert.match(offlineDownloadServiceSource, /for \(let index = 0; index < config\.totalPages; index \+= 1\)[\s\S]*const preferences = this\.queueStore\.loadPreferences\(\)[\s\S]*!this\.canDownloadNow\(preferences\)[\s\S]*failureReasonCode = preferences\.isPaused \? 'paused' : 'wifi_only'/, 'download service must stop foreground page work when the queue is paused or waiting for Wi-Fi')
assert.match(offlineDownloadServiceSource, /import \{ connection \} from '@kit\.NetworkKit'[\s\S]*getDefaultNetSync\(\)[\s\S]*getNetCapabilitiesSync\(netHandle\)[\s\S]*NetBearType\.BEARER_WIFI/, 'download service must use the platform default network capabilities for Wi-Fi-only gating')
assert.match(offlineDownloadServiceSource, /canDownloadNow\(preferences: OfflineDownloadQueuePreferences\): boolean[\s\S]*!preferences\.isPaused[\s\S]*!preferences\.wifiOnly \|\| isDefaultNetworkWifi\(\)/, 'download service must combine paused and Wi-Fi-only preferences before fetching pages')
assert.match(offlineDownloadServiceSource, /function downloadBlockedReason\(preferences: OfflineDownloadQueuePreferences\): string \{[\s\S]*preferences\.isPaused \? 'paused' : 'wifi_only'[\s\S]*failureReasonCode = blockedReason[\s\S]*failureReasonCode = preferences\.isPaused \? 'paused' : 'wifi_only'/, 'download service must record paused versus Wi-Fi-only queue wait reasons using the latest start guard state')
assert.match(offlineDownloadNotificationSource, /import \{ notificationManager \} from '@kit\.NotificationKit'[\s\S]*publishOfflineDownloadNotification\([\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*download_notification_complete_title[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*OfflineDownloadStatus\.BLOCKED[\s\S]*download_notification_failed_title[\s\S]*notificationManager\.isNotificationEnabled\(\)[\s\S]*wantAgent: await createOfflineDownloadWantAgent\(\)[\s\S]*notificationManager\.publish\(request\)/, 'offline downloads must publish completion and failure notifications only after real manifest outcomes')
assert.match(offlineDownloadNotificationSource, /requestOfflineDownloadNotificationPermission\(context: common\.UIAbilityContext\)[\s\S]*notificationManager\.requestEnableNotification\(context\)/, 'offline download notifications must expose a UI-bound permission request helper')
assert.match(offlineDownloadNotificationSource, /KOMA_LAUNCH_ROUTE_DOWNLOADS[\s\S]*actionType: wantAgent\.OperationType\.START_ABILITY[\s\S]*UPDATE_PRESENT_FLAG/, 'offline download notification taps must relaunch Koma into Downloads')
assert.match(offlineDownloadServiceSource, /publishNotification\(manifest[\s\S]*publishOfflineDownloadNotification\(manifest, labels\)[\s\S]*step=download_notification code=/, 'download service must log notification dispatch result without claiming success on disabled permission')
assert.match(offlineDownloadServiceSource, /step=download_done[\s\S]*this\.publishNotification\(manifest[\s\S]*catch \(error\)[\s\S]*step=download_failed[\s\S]*this\.publishNotification\(manifest/, 'download service must trigger notifications from real completed and failed manifest paths')
assert.match(offlineDownloadServiceSource, /manifest\.status = OfflineDownloadStatus\.DOWNLOADED[\s\S]*this\.store\.saveManifest\(manifest\)[\s\S]*const finalValidation = this\.store\.validateDownloadedChapter\(comic\.id, chapterId\)[\s\S]*!this\.store\.isChapterFullyDownloaded\(comic\.id, chapterId\)[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*step=download_final_validation_failed[\s\S]*this\.publishNotification\(manifest/, 'download service must validate the final manifest before publishing a completion result')
assert.match(offlineDownloadServiceSource, /step=download_blocked[\s\S]*reason=chapter_missing[\s\S]*manifest\.failureReasonCode = 'chapter_missing'[\s\S]*this\.store\.saveManifest\(manifest\)[\s\S]*this\.publishNotification\(manifest/, 'download service must persist and notify unretryable missing-chapter blocked download attempts')

assert.match(settingsPageSource, /key: 'downloads', titleKey: 'settings_row_downloads_title'/, 'Settings must expose a Downloads row')
assert.match(settingsPageSource, /key: 'download-retry-failed', titleKey: 'settings_row_download_retry_failed_title', detailKey: 'settings_row_download_retry_failed_detail' \}/, 'Settings retry-failed downloads row must be a real Downloads route entry, not a placeholder')
assert.match(settingsPageSource, /row\.key === 'downloads' \|\| row\.key === 'download-retry-failed'[\s\S]*this\.onOpenDownloads\(\)/, 'Settings retry-failed downloads row must open the real queue page instead of pretending to retry in settings')
assert.match(settingsPageSource, /key: 'download-notifications', titleKey: 'settings_row_download_notifications_title'[\s\S]*getOfflineDownloadNotificationStatusLabel\(this\.downloadNotificationStatus\)[\s\S]*requestOfflineDownloadNotificationPermission\(this\.context\(\)\)/, 'Settings must expose and request real download notification permission state')
assert.match(settingsPageSource, /key: 'download-notification-test', titleKey: 'settings_row_download_notification_test_title'[\s\S]*sendDownloadNotificationTest\(\): void[\s\S]*publishOfflineDownloadNotification\(\{[\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*download_notification_test_comic[\s\S]*download_notification_test_chapter[\s\S]*handleDownloadNotificationDispatch\(result\)/, 'Settings must expose a real test notification action using the download notification publish path')
assert.match(settingsPageSource, /handleDownloadNotificationDispatch\(result: OfflineDownloadNotificationDispatchResult\)[\s\S]*result\.delivered[\s\S]*settings_download_notification_test_sent[\s\S]*result\.code === 'disabled'[\s\S]*settings_download_notification_test_disabled[\s\S]*settings_download_notification_test_failed/, 'Settings test notification must fail closed for disabled or failed notification delivery')
assert.match(settingsPageSource, /key: 'download-concurrency', titleKey: 'settings_row_download_concurrency_title'[^}]*}/, 'Settings must expose real download concurrency preferences')
assert.match(settingsPageSource, /OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS[\s\S]*OfflineDownloadQueueStore/, 'Settings must reuse the durable download queue preference store')
assert.match(settingsPageSource, /saveDownloadForegroundConcurrencyLimit\(limit: number\)[\s\S]*setForegroundConcurrencyLimit\(limit\)/, 'Settings download concurrency row must persist through OfflineDownloadQueueStore')
assert.match(settingsPageSource, /key: 'download-wifi-only', titleKey: 'settings_row_download_wifi_only_title', detailKey: 'settings_row_download_wifi_only_detail' \}[\s\S]*downloadWifiOnly[\s\S]*setWifiOnly\(wifiOnly\)[\s\S]*row\.key === 'download-wifi-only'[\s\S]*hasSwitch: true/, 'Settings Wi-Fi-only downloads row must be a real durable switch')
assert.doesNotMatch(settingsPageSource, /key: 'download-(notifications|notification-test|retry-failed|concurrency|wifi-only)'[^}]*placeholder:\s*true/, 'Settings download rows must not remain placeholder rows')
assert.match(settingsPageSource, /onOpenDownloads:\s*\(\) => void/, 'SettingsPage must accept a Downloads route callback')
assert.match(settingsPageSource, /row\.key === 'downloads'[\s\S]*this\.onOpenDownloads\(\)/, 'Settings Downloads row must open the route')
assert.match(constantsSource, /static readonly DOWNLOADS:\s*string = 'DownloadsPage'/, 'RouteName must define DownloadsPage')
assert.match(constantsSource, /KOMA_LAUNCH_ROUTE_DOWNLOADS:\s*string = 'downloads'/, 'notification launch constants must include the downloads route')
assert.match(routerHelperSource, /pushDownloads\(\): void \{[\s\S]*RouteName\.DOWNLOADS/, 'RouterHelper must expose a notification-safe Downloads route push')
assert.match(entryAbilitySource, /KOMA_LAUNCH_ROUTE_DOWNLOADS[\s\S]*RouterHelper\.pushDownloads\(\)/, 'EntryAbility must route download notification launch wants to Downloads')
assert.match(indexSource, /import \{ DownloadsPage \} from '\.\/DownloadsPage'/, 'Index must import DownloadsPage')
assert.match(indexSource, /name === RouteName\.DOWNLOADS[\s\S]*DownloadsPage\(\{[\s\S]*libraryStore: this\.libraryStore/, 'Index must route to DownloadsPage with the library store')
assert.match(indexSource, /onOpenDownloads:\s*\(\) => \{[\s\S]*this\.openSettingsSecondary\(RouteName\.DOWNLOADS\)/, 'Index must wire Settings Downloads callback to the top-level route')

assert.match(downloadsPageSource, /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20/, 'DownloadsPage must use secondary list scaffold bottom clearance')
assert.match(downloadsPageSource, /new OfflineDownloadQueueStore\(this\.context\(\)\.filesDir\)/, 'DownloadsPage must load queue from app files dir')
assert.match(downloadsPageSource, /loadQueue\(reconcileManifests: boolean = true\)[\s\S]*reconcileManifests \? store\.reconcileWithManifests\(\) : store\.load\(\)/, 'DownloadsPage must support loading a raw queue snapshot when active work should not be downgraded by manifest reconciliation')
assert.match(downloadsPageSource, /rescanDownloads\(\): void[\s\S]*this\.busyKey = 'rescan'[\s\S]*runRescanDownloads\(\)/, 'DownloadsPage must expose a manual download manifest rescan action')
assert.match(downloadsPageSource, /formatRecoverySummary\(summary: OfflineDownloadQueueRecoverySummary\): string[\s\S]*downloads_toast_rescan_done[\s\S]*restoredCount[\s\S]*updatedCount/, 'DownloadsPage must format a user-visible download rescan summary')
assert.match(downloadsPageSource, /runRescanDownloads\(\): Promise<void>[\s\S]*recoverFromManifests\(\)[\s\S]*this\.loadQueue\(\)[\s\S]*formatRecoverySummary\(summary\)/, 'DownloadsPage rescan must recover queue rows from manifests and refresh visible queue state')
assert.match(downloadsPageSource, /step=rescan_failed failed=true reason=manifest_rescan/, 'DownloadsPage rescan failure log must use a redacted reason code')
assert.match(downloadsPageSource, /this\.QueueControls\(\)[\s\S]*if \(this\.entries\.length === 0\)[\s\S]*this\.EmptyState\(\)/, 'DownloadsPage must keep queue controls visible when the queue is empty so lost queue files can be recovered')
assert.match(downloadsPageSource, /this\.preferences = store\.loadPreferences\(\)/, 'DownloadsPage must load queue preferences from disk')
assert.match(downloadsPageSource, /queueStateText\(\):\s*string[\s\S]*paused[\s\S]*running[\s\S]*queued[\s\S]*failed[\s\S]*blocked[\s\S]*concurrency/, 'DownloadsPage must show honest queue state and concurrency preference text')
assert.match(downloadsPageSource, /queueProgressText\(\):\s*string[\s\S]*summarizeOfflineDownloadQueue\(this\.entries\)[\s\S]*downloads_queue_progress[\s\S]*downloadedPageCount[\s\S]*pageCount[\s\S]*totalCount[\s\S]*downloadedCount[\s\S]*partialCount/, 'DownloadsPage must show overall chapter and page download progress')
assert.match(downloadsPageSource, /QueueControls\(\)[\s\S]*Text\(this\.queueStateText\(\)\)[\s\S]*Text\(this\.queueProgressText\(\)\)/, 'DownloadsPage controls must render both queue state and total progress')
assert.match(downloadsPageSource, /ConcurrencyMenu\(\)[\s\S]*OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS[\s\S]*setForegroundConcurrencyLimit\(limit\)/, 'DownloadsPage must expose foreground concurrency controls')
assert.match(downloadsPageSource, /pauseQueuedDownloads\(\)[\s\S]*pauseAllQueuedWork\(\)/, 'DownloadsPage must expose pause-all queued work controls')
assert.match(downloadsPageSource, /pauseQueuedDownloads\(\): void \{[\s\S]*pauseAllQueuedWork\(\)[\s\S]*this\.loadQueue\(false\)/, 'DownloadsPage pause must avoid immediate manifest reconciliation so in-flight downloads can settle as paused or partial instead of false failed')
assertFunctionDoesNotContain(downloadsPageSource, 'pauseQueuedDownloads', /busyKey\.length > 0/, 'DownloadsPage must allow pause while a foreground batch is running')
assert.match(downloadsPageSource, /primaryQueueActionLabel\(\):\s*string[\s\S]*downloads_action_start_queue[\s\S]*downloads_action_pause_queue/, 'DownloadsPage primary queue action must expose start queued work before falling back to pause')
assert.match(downloadsPageSource, /handlePrimaryQueueAction\(\):\s*void[\s\S]*this\.resumeQueuedDownloads\(\)[\s\S]*this\.pauseQueuedDownloads\(\)[\s\S]*this\.startQueuedDownloads\(\)/, 'DownloadsPage primary queue control must resume, pause running work, or start queued work from one route')
assert.match(downloadsPageSource, /startQueuedDownloads\(\):\s*void[\s\S]*this\.preferences\.isPaused[\s\S]*downloads_toast_queue_paused[\s\S]*const targets = this\.queuedEntries\(\)[\s\S]*this\.runStartBatch\(targets\)/, 'DownloadsPage must expose a foreground start action for already queued downloads')
assert.match(downloadsPageSource, /runStartBatch\(targets: OfflineDownloadQueueEntry\[\]\): Promise<void>[\s\S]*runForegroundDownloadBatch\(targets\)[\s\S]*downloads_toast_started_queued[\s\S]*step=batch_start_failed failed=true reason=batch_start/, 'DownloadsPage queued start must use the same foreground batch worker and redacted failure logs')
assert.match(downloadsPageSource, /resumeQueuedDownloads\(\)[\s\S]*resumeAllQueuedWork\(\)[\s\S]*queuedEntries\(\)[\s\S]*runResumeBatch\(targets\)/, 'DownloadsPage must resume queued foreground work from durable paused state')
assert.match(downloadsPageSource, /runForegroundDownloadBatch\(targets: OfflineDownloadQueueEntry\[\]\): Promise<number>[\s\S]*foregroundConcurrencyLimit[\s\S]*Promise\.all\(workers\)/, 'DownloadsPage foreground batch worker must respect the concurrency preference')
assert.match(downloadsPageSource, /blockUnavailableEntry\(entry: OfflineDownloadQueueEntry\): void \{[\s\S]*OfflineDownloadStatus\.BLOCKED[\s\S]*failureReasonCode: 'comic_missing'[\s\S]*this\.entries = this\.entries\.map/, 'DownloadsPage must persist stale missing-comic queue rows as blocked instead of silently skipping them')
assert.match(downloadsPageSource, /retryDownload\(entry: OfflineDownloadQueueEntry\): void \{[\s\S]*comic === undefined[\s\S]*this\.blockUnavailableEntry\(entry\)[\s\S]*downloads_toast_entry_unavailable/, 'DownloadsPage single retry must block stale entries when the manga is no longer in the library')
assert.match(downloadsPageSource, /runForegroundDownloadBatch\(targets: OfflineDownloadQueueEntry\[\]\): Promise<number>[\s\S]*comic === undefined[\s\S]*this\.blockUnavailableEntry\(entry\)[\s\S]*continue/, 'DownloadsPage batch start and resume must block stale entries when the manga is no longer in the library')
assert.match(downloadsPageSource, /downloads_empty_title/, 'DownloadsPage must show an explicit empty state')
assert.match(downloadsPageSource, /formatStatus\([\s\S]*queued[\s\S]*downloading[\s\S]*downloaded[\s\S]*partial[\s\S]*failed[\s\S]*blocked/, 'DownloadsPage must render all queue statuses')
assert.match(downloadsPageSource, /formatEntryStatus\(entry: OfflineDownloadQueueEntry\): string[\s\S]*failureReasonCode === 'paused'[\s\S]*downloads_status_paused[\s\S]*failureReasonCode === 'wifi_only'[\s\S]*downloads_status_waiting_wifi/, 'DownloadsPage must render paused and Wi-Fi-only waiting rows clearly')
assert.match(downloadsPageSource, /enum DownloadQueueFilter\s*{[\s\S]*QUEUED[\s\S]*DOWNLOADING[\s\S]*FAILED[\s\S]*BLOCKED[\s\S]*DOWNLOADED/, 'DownloadsPage must expose queue status filters')
assert.match(downloadsPageSource, /visibleEntries\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*DownloadQueueFilter\.FAILED[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*DownloadQueueFilter\.BLOCKED[\s\S]*OfflineDownloadStatus\.BLOCKED[\s\S]*DownloadQueueFilter\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.DOWNLOADED/, 'DownloadsPage filters must group failed/partial and keep blocked/downloaded explicit')
assert.match(downloadsPageSource, /FilterMenu\(\)[\s\S]*DownloadQueueFilter\.QUEUED[\s\S]*DownloadQueueFilter\.DOWNLOADING[\s\S]*DownloadQueueFilter\.FAILED[\s\S]*DownloadQueueFilter\.BLOCKED[\s\S]*DownloadQueueFilter\.DOWNLOADED/, 'DownloadsPage must provide user-visible queue filter controls')
assert.match(downloadsPageSource, /retryDownload\(entry: OfflineDownloadQueueEntry\)[\s\S]*OfflineDownloadService[\s\S]*downloadChapter/, 'DownloadsPage must retry failed/partial entries through OfflineDownloadService')
assert.match(downloadsPageSource, /canRetry\([\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL/, 'DownloadsPage must expose retry for failed and partial rows')
assertFunctionDoesNotContain(downloadsPageSource, 'canRetry', /OfflineDownloadStatus\.BLOCKED/, 'DownloadsPage must not expose misleading retry for blocked rows without page hydration')
assert.match(downloadsPageSource, /retryableEntries\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*this\.visibleEntries\(\)\.filter[\s\S]*this\.canRetry\(entry\)/, 'DownloadsPage batch retry must reuse canRetry so blocked rows are excluded')
assert.match(downloadsPageSource, /retryFailedDownloads\(\)[\s\S]*const targets = this\.retryableEntries\(\)[\s\S]*this\.runRetryBatch\(targets\)/, 'DownloadsPage must expose batch retry for failed/partial rows')
assert.match(downloadsPageSource, /retryFailedDownloads\(\)[\s\S]*this\.preferences\.isPaused[\s\S]*downloads_toast_queue_paused/, 'DownloadsPage must not start retry work while paused')
assert.match(downloadsPageSource, /isEnabled:\s*!this\.preferences\.isPaused \|\| this\.busyKey\.length === 0[\s\S]*this\.handlePrimaryQueueAction\(\)/, 'DownloadsPage primary queue control must not be disabled by a generic busyKey guard while the queue is running')
assert.match(downloadsPageSource, /removableSettledEntries\(\):\s*OfflineDownloadQueueEntry\[\][\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*OfflineDownloadStatus\.BLOCKED/, 'DownloadsPage must collect completed/failed/blocked rows for batch removal')
assert.match(downloadsPageSource, /runRemoveBatch\(targets: OfflineDownloadQueueEntry\[\]\)[\s\S]*deleteChapterDownload/, 'DownloadsPage batch remove must use queue cleanup instead of only hiding rows')
assertFunctionDoesNotContain(downloadsPageSource, 'retryableEntries', /OfflineDownloadStatus\.BLOCKED/, 'DownloadsPage batch retry must not include blocked rows')
assert.match(downloadsPageSource, /blockedHelpText\(entry: OfflineDownloadQueueEntry\)[\s\S]*failureReasonCode === 'pages_missing'[\s\S]*downloads_blocked_pages_missing/, 'DownloadsPage must explain pages_missing blocked rows instead of offering a dead-end retry')
assert.match(downloadsPageSource, /blockedHelpText\(entry: OfflineDownloadQueueEntry\)[\s\S]*failureReasonCode === 'chapter_missing'[\s\S]*downloads_blocked_chapter_missing/, 'DownloadsPage must explain chapter_missing blocked rows instead of falling back to generic text')
assert.match(downloadsPageSource, /blockedHelpText\(entry: OfflineDownloadQueueEntry\)[\s\S]*failureReasonCode === 'comic_missing'[\s\S]*downloads_blocked_comic_missing/, 'DownloadsPage must explain stale missing-comic blocked rows instead of falling back to generic text')
assert.match(downloadsPageSource, /runRemoveBatch\(targets: OfflineDownloadQueueEntry\[\]\)[\s\S]*OfflineDownloadStatus\.DOWNLOADED[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*OfflineDownloadStatus\.BLOCKED[\s\S]*deleteChapterDownload/, 'DownloadsPage batch cleanup must delete blocked dead-end rows as settled work')
assert.match(downloadsPageSource, /removeDownload\(entry: OfflineDownloadQueueEntry\)[\s\S]*deleteChapterDownload/, 'DownloadsPage must remove queue rows and downloaded data where feasible')
assert.doesNotMatch(downloadsPageSource, /后台|系统通知|通知权限|background scheduler|notification delivery/i, 'DownloadsPage copy must not claim background downloads or notification delivery')
assert.doesNotMatch(downloadsPageSource, /\[Downloads\][^\n]*message=/, 'DownloadsPage recovery logs must use redacted reason codes instead of raw error messages')
assert.match(downloadsPageSource, /step=retry_failed failed=true reason=download_retry/, 'DownloadsPage retry failure log must retain a redacted retry reason code')
assert.match(downloadsPageSource, /step=batch_resume_failed failed=true reason=batch_resume/, 'DownloadsPage resume failure log must retain a redacted resume reason code')

assert.match(chapterListSectionSource, /export enum ChapterBatchDownloadMode\s*{[\s\S]*ALL_VISIBLE[\s\S]*FAILED_ONLY[\s\S]*NOT_DOWNLOADED/, 'ChapterListSection must define visible chapter batch download modes')
assert.match(chapterListSectionSource, /onDownloadChapter:\s*\(chapterId: string\) => void/, 'ChapterListSection must accept a per-chapter download callback')
assert.match(chapterListSectionSource, /onDownloadVisibleChapters:\s*\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\) => void/, 'ChapterListSection must accept a visible chapter batch download callback')
assert.match(chapterListSectionSource, /visibleChapterIds\(\):\s*string\[\][\s\S]*this\.sortedChapters\.map/, 'ChapterListSection batch actions must operate on the current visible sorted chapter list')
assert.match(chapterListSectionSource, /BatchDownloadMenu\(\)[\s\S]*ChapterBatchDownloadMode\.ALL_VISIBLE[\s\S]*ChapterBatchDownloadMode\.FAILED_ONLY[\s\S]*ChapterBatchDownloadMode\.NOT_DOWNLOADED/, 'ChapterListSection must expose all visible/failed/not downloaded batch actions')
assert.match(chapterListSectionSource, /KomaIconButton\(\{[\s\S]*arrow_down_to_line[\s\S]*this\.onDownloadChapter\(chapter\.id\)/, 'Chapter rows must expose a download action without replacing open-to-read')
assert.match(chapterListSectionSource, /onClick\(\(\) => \{[\s\S]*this\.onOpenChapter\(chapter\.id\)/, 'Chapter row click-to-read behavior must remain')
assert.match(chapterListSectionSource, /Row\(\{ space: ThemeConstants\.SPACE_MD \}\) \{[\s\S]*Column\(\{ space: ThemeConstants\.SPACE_XS \}\)[\s\S]*\.layoutWeight\(1\)[\s\S]*\.onClick\(\(\) => \{[\s\S]*this\.onOpenChapter\(chapter\.id\)[\s\S]*KomaIconButton\(\{[\s\S]*arrow_down_to_line[\s\S]*this\.onDownloadChapter\(chapter\.id\)/, 'Chapter open handler must be isolated to the left content area before the download button')
assert.doesNotMatch(chapterListSectionSource, /\.opacity\(chapter\.isRead \? 0\.68 : 1\)\s*\.onClick\(\(\) => \{[\s\S]*this\.onOpenChapter\(chapter\.id\)/, 'Chapter outer row must not open the reader when tapping the download button')
assert.match(mangaDetailPageSource, /handleDownloadChapter\(chapterId\?: string\)[\s\S]*const resolvedChapterId = chapterId \?\? this\.firstChapterId\(\)/, 'MangaDetail download handler must accept a specific chapter id')
assert.match(mangaDetailPageSource, /batchDownloadChapterIds\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\)[\s\S]*ChapterBatchDownloadMode\.FAILED_ONLY[\s\S]*OfflineDownloadStatus\.FAILED[\s\S]*OfflineDownloadStatus\.PARTIAL[\s\S]*ChapterBatchDownloadMode\.NOT_DOWNLOADED[\s\S]*OfflineDownloadStatus\.DOWNLOADED/, 'MangaDetailPage must filter visible chapter batch actions by existing durable summaries')
assert.match(mangaDetailPageSource, /handleDownloadVisibleChapters\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\)[\s\S]*ensureSourceChapterPages\(chapterId\)[\s\S]*this\.libraryStore\?\.getComic\(this\.currentComicId\(\)\)[\s\S]*service\.downloadChapter\(comic, chapterId/, 'MangaDetailPage batch download must hydrate source chapter pages and refresh the comic before OfflineDownloadService')
assert.match(mangaDetailPageSource, /ensureSourceChapterPages\(chapterId: string\): Promise<boolean>[\s\S]*chapter\.pages\.length > 0[\s\S]*return true[\s\S]*pages\.length === 0[\s\S]*return false/, 'MangaDetailPage source page hydration must report success/failure without pretending empty pages are valid')
assert.match(mangaDetailPageSource, /step=batch_pages_unavailable failed=true reason=source_pages_(missing|lookup)/, 'MangaDetailPage batch source hydration failures must use redacted reason codes')
assert.match(mangaDetailPageSource, /ChapterListSection\(\{[\s\S]*onOpenChapter:[\s\S]*onDownloadChapter:\s*\(chapterId: string\) => \{[\s\S]*this\.handleDownloadChapter\(chapterId\)/, 'MangaDetailPage must wire chapter row download action')
assert.match(mangaDetailPageSource, /ChapterListSection\(\{[\s\S]*onDownloadVisibleChapters:\s*\(chapterIds: string\[\], mode: ChapterBatchDownloadMode\) => \{[\s\S]*this\.handleDownloadVisibleChapters\(chapterIds, mode\)/, 'MangaDetailPage must wire visible chapter batch download action')

function stableHash(value) {
  let hashA = 2166136261
  let hashB = 2166136261 ^ 0x9e3779b9
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    hashA = Math.imul((hashA ^ code) >>> 0, 16777619) >>> 0
    hashB = Math.imul((hashB ^ (code + index)) >>> 0, 16777619) >>> 0
  }
  return `${hashA.toString(16).padStart(8, '0')}${hashB.toString(16).padStart(8, '0')}`
}

function manifestIntegrityPayload(manifest) {
  const pages = manifest.pages.slice().sort((left, right) => left.pageIndex - right.pageIndex).map((page) => {
    return [page.pageIndex, page.pageId, page.fileName, Math.max(0, Math.floor(page.size))].join(':')
  })
  return [
    1,
    manifest.sourceKind ?? '',
    manifest.sourceId ?? '',
    manifest.comicId,
    manifest.seriesId,
    manifest.chapterId,
    Math.max(0, Math.floor(manifest.pageCount)),
    pages.join('|'),
  ].join('\n')
}

function stampManifest(manifest) {
  const normalized = {
    ...manifest,
    schemaVersion: 1,
    downloadedPageCount: manifest.pages.length,
    pages: manifest.pages.slice().sort((left, right) => left.pageIndex - right.pageIndex),
    integrityHash: '',
  }
  normalized.integrityHash = stableHash(manifestIntegrityPayload(normalized))
  return normalized
}

function validateFixtureManifest(path) {
  let manifest
  try {
    manifest = JSON.parse(readFileSync(path, 'utf8'))
  } catch (_err) {
    return { status: 'corrupt', reasonCode: 'manifest_malformed' }
  }
  if (typeof manifest.seriesId !== 'string' || typeof manifest.integrityHash !== 'string') {
    return { status: 'corrupt', reasonCode: 'manifest_malformed' }
  }
  const pageCount = Math.max(0, Math.floor(manifest.pageCount))
  if (!['queued', 'downloading', 'downloaded', 'partial', 'failed', 'blocked'].includes(manifest.status)) {
    return {
      status: 'corrupt',
      reasonCode: 'status_invalid',
      availablePageCount: 0,
      missingPageCount: pageCount,
    }
  }
  if (!['downloaded', 'partial'].includes(manifest.status)) {
    return {
      status: 'missing',
      reasonCode: 'status_not_reader_ready',
      availablePageCount: 0,
      missingPageCount: pageCount,
    }
  }
  if (manifest.integrityHash.trim().length === 0) {
    return { status: 'corrupt', reasonCode: 'integrity_missing' }
  }
  if (stableHash(manifestIntegrityPayload(manifest)) !== manifest.integrityHash) {
    return { status: 'corrupt', reasonCode: 'integrity_mismatch' }
  }
  if (pageCount <= 0 || manifest.pages.length === 0) {
    return {
      status: 'missing',
      reasonCode: pageCount <= 0 ? 'page_count_empty' : 'pages_missing',
      availablePageCount: 0,
      missingPageCount: pageCount,
    }
  }
  let availablePageCount = 0
  for (const page of manifest.pages) {
    if (existsSync(page.localPath)) {
      assert.equal(statSync(page.localPath).size, page.size)
      availablePageCount += 1
    }
  }
  if (pageCount > 0 && availablePageCount === 0) {
    return { status: 'missing', reasonCode: 'pages_missing' }
  }
  const missingPageCount = Math.max(0, pageCount - availablePageCount)
  return {
    status: missingPageCount === 0 ? 'downloaded' : 'partial',
    reasonCode: missingPageCount === 0 ? undefined : 'page_file_missing',
    availablePageCount,
    missingPageCount,
  }
}

function recordFixturePage(manifest, page) {
  return stampManifest({
    ...manifest,
    pages: manifest.pages.filter((item) => item.pageId !== page.pageId && item.pageIndex !== page.pageIndex).concat(page),
  })
}

function matchesFixtureDownloadedPage(page, pageId, pageIndex) {
  if (pageId.trim().length > 0) {
    return page.pageId === pageId
  }
  return page.pageIndex === pageIndex
}

const fixtureRoot = mkdtempSync(join(tmpdir(), 'koma-d33-manifest-'))
try {
  const chapterDir = join(fixtureRoot, 'downloads', stableHash('comic-1'), stableHash('chapter-1'))
  mkdirSync(chapterDir, { recursive: true })
  const firstPage = join(chapterDir, '00001-a.jpg')
  const secondPage = join(chapterDir, '00002-b.jpg')
  writeFileSync(firstPage, 'page-a')
  writeFileSync(secondPage, 'page-bb')
  const manifestPath = join(chapterDir, 'manifest.v1.json')
  const completeManifest = stampManifest({
    schemaVersion: 1,
    sourceKind: 'local_archive',
    sourceId: 'local_archive',
    comicId: 'comic-1',
    seriesId: 'comic-1',
    chapterId: 'chapter-1',
    pageCount: 2,
    downloadedPageCount: 0,
    status: 'downloaded',
    updatedAt: 1,
    pages: [
      { pageId: 'page-a', pageIndex: 0, fileName: '00001-a.jpg', localPath: firstPage, size: 6, updatedAt: 1 },
      { pageId: 'page-b', pageIndex: 1, fileName: '00002-b.jpg', localPath: secondPage, size: 7, updatedAt: 1 },
    ],
    integrityHash: '',
  })
  assert.equal(
    matchesFixtureDownloadedPage(completeManifest.pages[0], 'different-page-id', 0),
    false,
    'offline page lookup must not use pageIndex when the requested pageId is non-empty but stale',
  )
  assert.equal(
    matchesFixtureDownloadedPage(completeManifest.pages[0], '', 0),
    true,
    'offline page lookup may use pageIndex only for empty pageId fallback',
  )
  writeFileSync(manifestPath, JSON.stringify(completeManifest))
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'downloaded',
    reasonCode: undefined,
    availablePageCount: 2,
    missingPageCount: 0,
  }, 'complete manifest fixture must validate as downloaded')

  for (const blockedStatus of ['queued', 'blocked', 'failed', 'downloading']) {
    const blockedManifest = stampManifest({
      ...completeManifest,
      status: blockedStatus,
      integrityHash: '',
    })
    writeFileSync(manifestPath, JSON.stringify(blockedManifest))
    assert.deepEqual(validateFixtureManifest(manifestPath), {
      status: 'missing',
      reasonCode: 'status_not_reader_ready',
      availablePageCount: 0,
      missingPageCount: 2,
    }, `${blockedStatus} manifest with present page files must not validate as downloaded or partial`)
  }

  const invalidStatusManifest = stampManifest({
    ...completeManifest,
    status: 'done',
    integrityHash: '',
  })
  writeFileSync(manifestPath, JSON.stringify(invalidStatusManifest))
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'corrupt',
    reasonCode: 'status_invalid',
    availablePageCount: 0,
    missingPageCount: 2,
  }, 'arbitrary invalid manifest status must validate as corrupt')

  const zeroPageManifest = stampManifest({
    ...completeManifest,
    pageCount: 0,
    downloadedPageCount: 0,
    status: 'downloaded',
    pages: [],
    integrityHash: '',
  })
  writeFileSync(manifestPath, JSON.stringify(zeroPageManifest))
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'missing',
    reasonCode: 'page_count_empty',
    availablePageCount: 0,
    missingPageCount: 0,
  }, 'zero-page downloaded manifest must not validate as downloaded')

  const emptyPagesManifest = stampManifest({
    ...completeManifest,
    downloadedPageCount: 0,
    status: 'downloaded',
    pages: [],
    integrityHash: '',
  })
  writeFileSync(manifestPath, JSON.stringify(emptyPagesManifest))
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'missing',
    reasonCode: 'pages_missing',
    availablePageCount: 0,
    missingPageCount: 2,
  }, 'empty-page downloaded manifest must not validate as downloaded')

  const emptyHashManifest = { ...completeManifest, integrityHash: '' }
  writeFileSync(manifestPath, JSON.stringify(emptyHashManifest))
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'corrupt',
    reasonCode: 'integrity_missing',
  }, 'empty-hash tampered manifest must not validate as downloaded or partial')
  writeFileSync(manifestPath, JSON.stringify(completeManifest))

  rmSync(secondPage)
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'partial',
    reasonCode: 'page_file_missing',
    availablePageCount: 1,
    missingPageCount: 1,
  }, 'missing one page file must validate as partial')

  rmSync(firstPage)
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'missing',
    reasonCode: 'pages_missing',
  }, 'missing all page files must validate as missing')
  writeFileSync(firstPage, 'page-a')

  writeFileSync(manifestPath, '{')
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'corrupt',
    reasonCode: 'manifest_malformed',
  }, 'malformed manifest JSON must validate as corrupt')

  writeFileSync(secondPage, 'page-bb')
  const duplicateUpdate = recordFixturePage(completeManifest, {
    pageId: 'page-b',
    pageIndex: 1,
    fileName: '00002-b.jpg',
    localPath: secondPage,
    size: 7,
    updatedAt: 2,
  })
  assert.equal(duplicateUpdate.pages.length, 2, 'duplicate page writes must update in place')
  assert.equal(duplicateUpdate.downloadedPageCount, 2, 'duplicate page writes must keep downloaded count idempotent')
  const tamperedManifest = { ...completeManifest, pageCount: 3 }
  writeFileSync(manifestPath, JSON.stringify(tamperedManifest))
  assert.deepEqual(validateFixtureManifest(manifestPath), {
    status: 'corrupt',
    reasonCode: 'integrity_mismatch',
  }, 'tampered manifest content must validate as corrupt')
} finally {
  rmSync(fixtureRoot, { recursive: true, force: true })
}

console.log('offline download queue static checks passed')
