import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/model/ComicModels.ets')
const libraryStorePath = resolve(root, 'entry/src/main/ets/model/LibraryStore.ets')
const progressStorePath = resolve(root, 'entry/src/main/ets/model/ReadingProgressStore.ets')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')
const mockLibraryDataPath = resolve(root, 'entry/src/main/ets/model/MockLibraryData.ets')
const sourceModelsPath = resolve(root, 'entry/src/main/ets/model/SourceModels.ets')
const sourceTextNormalizerPath = resolve(root, 'entry/src/main/ets/model/SourceTextNormalizer.ets')
const mangaDetailModelsPath = resolve(root, 'entry/src/main/ets/model/MangaDetailModels.ets')
const libraryRepositoryPath = resolve(root, 'entry/src/main/ets/model/LibraryRepository.ets')
const libraryPersistencePath = resolve(root, 'entry/src/main/ets/model/LibraryPersistence.ets')
const libraryUpdateServicePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets')
const libraryUpdatePreferencesStorePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdatePreferencesStore.ets')
const backupServicePath = resolve(root, 'entry/src/main/ets/model/BackupService.ets')
const readerPreferencesStorePath = resolve(root, 'entry/src/main/ets/model/ReaderPreferencesStore.ets')
const offlineDownloadStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadStore.ets')
const offlineDownloadServicePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadService.ets')
const entryAbilityPath = resolve(root, 'entry/src/main/ets/entryability/EntryAbility.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const libraryPagePath = resolve(root, 'entry/src/main/ets/pages/LibraryPage.ets')
const browsePagePath = resolve(root, 'entry/src/main/ets/pages/BrowsePage.ets')
const historyPagePath = resolve(root, 'entry/src/main/ets/pages/HistoryPage.ets')
const searchPagePath = resolve(root, 'entry/src/main/ets/pages/SearchPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const importPagePath = resolve(root, 'entry/src/main/ets/pages/ImportPage.ets')
const sourceBrowsePagePath = resolve(root, 'entry/src/main/ets/pages/SourceBrowsePage.ets')
const sourceSearchPagePath = resolve(root, 'entry/src/main/ets/pages/SourceSearchPage.ets')
const sourcePackageManagerPagePath = resolve(root, 'entry/src/main/ets/pages/SourcePackageManagerPage.ets')
const secondaryListScaffoldPath = resolve(root, 'entry/src/main/ets/components/SecondaryListScaffold.ets')
const comicCoverCardPath = resolve(root, 'entry/src/main/ets/components/ComicCoverCard.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')
const readerPageSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const sourceSettingsStorePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets')
const sourceRuntimeAppRegistryPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeAppRegistry.ets')
const sourceIndexServicePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceIndexService.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const libraryStoreSource = readFileSync(libraryStorePath, 'utf8')
const progressStoreSource = readFileSync(progressStorePath, 'utf8')
const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')
const mockLibraryDataSource = readFileSync(mockLibraryDataPath, 'utf8')
const sourceModelsSource = readFileSync(sourceModelsPath, 'utf8')
const sourceTextNormalizerSource = readFileSync(sourceTextNormalizerPath, 'utf8')
const mangaDetailModelsSource = readFileSync(mangaDetailModelsPath, 'utf8')
const libraryRepositorySource = readFileSync(libraryRepositoryPath, 'utf8')
const libraryPersistenceSource = readFileSync(libraryPersistencePath, 'utf8')
const libraryUpdateServiceSource = readFileSync(libraryUpdateServicePath, 'utf8')
const libraryUpdatePreferencesStoreSource = readFileSync(libraryUpdatePreferencesStorePath, 'utf8')
const backupServiceSource = readFileSync(backupServicePath, 'utf8')
const readerPreferencesStoreSource = readFileSync(readerPreferencesStorePath, 'utf8')
const offlineDownloadStoreSource = readFileSync(offlineDownloadStorePath, 'utf8')
const offlineDownloadServiceSource = readFileSync(offlineDownloadServicePath, 'utf8')
const entryAbilitySource = readFileSync(entryAbilityPath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const libraryPageSource = readFileSync(libraryPagePath, 'utf8')
const browsePageSource = readFileSync(browsePagePath, 'utf8')
const historyPageSource = readFileSync(historyPagePath, 'utf8')
const searchPageSource = readFileSync(searchPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const importPageSource = readFileSync(importPagePath, 'utf8')
const sourceBrowsePageSource = readFileSync(sourceBrowsePagePath, 'utf8')
const sourceSearchPageSource = readFileSync(sourceSearchPagePath, 'utf8')
const sourcePackageManagerPageSource = readFileSync(sourcePackageManagerPagePath, 'utf8')
const secondaryListScaffoldSource = readFileSync(secondaryListScaffoldPath, 'utf8')
const comicCoverCardSource = readFileSync(comicCoverCardPath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const readerPageSourceAdapterSource = readFileSync(readerPageSourceAdapterPath, 'utf8')
const sourceSettingsStoreSource = readFileSync(sourceSettingsStorePath, 'utf8')
const sourceRuntimeAppRegistrySource = readFileSync(sourceRuntimeAppRegistryPath, 'utf8')
const sourceIndexServiceSource = readFileSync(sourceIndexServicePath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

function assertUsesSecondaryListSafeArea(source, label) {
  assert.match(source, /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20/, `${label} must avoid floating tab chrome inside list content`)
}

function assertUsesScrollContentSafeArea(source, label) {
  assert.match(source, /@StorageProp\(StorageKeys\.TOP_AVOID_HEIGHT\)\s+topH:\s*number = 0/, `${label} must read top safe-area avoidance height`)
  assert.match(source, /@StorageProp\(StorageKeys\.BOTTOM_AVOID_HEIGHT\)\s+bottomH:\s*number = 0/, `${label} must read bottom safe-area avoidance height`)
  assert.match(source, /topContentInset\(\): number \{[\s\S]*this\.topH/, `${label} must calculate a top inset inside scroll content`)
  assert.match(source, /bottomContentInset\(\): number \{[\s\S]*this\.bottomH[\s\S]*ThemeConstants\.FLOAT_BAR_HEIGHT/, `${label} must calculate bottom inset for floating chrome inside scroll content`)
  assert.match(source, /\.padding\(\{[^}]*top:\s*this\.topContentInset\(\)[^}]*bottom:\s*this\.bottomContentInset\(\)[^}]*\}\)/, `${label} must apply safe-area avoidance as scroll content padding`)
}

function assertSourceBrowseFloatingTabViewportClearance(source) {
  assert.match(source, /bottomContentInset\(\): number \{[\s\S]*this\.bottomH[\s\S]*ThemeConstants\.FLOAT_BAR_HEIGHT/, 'SourceBrowsePage must keep bottomContentInset for scroll-end clearance')
  assert.match(source, /bottomFloatingTabViewportClearance\(\): number \{[\s\S]*return this\.bottomContentInset\(\)/, 'SourceBrowsePage must expose a named floating tab viewport clearance')
  assert.match(source, /Scroll\(\)[\s\S]*\.padding\(\{\s*bottom:\s*this\.bottomFloatingTabViewportClearance\(\)\s*\}\)[\s\S]*\.clipContent\(ContentClipMode\.CONTENT_ONLY\)/, 'SourceBrowsePage scroll viewport must reserve and clip bottom content above floating tab chrome')
  assert.doesNotMatch(source, /\.expandSafeArea\(/, 'SourceBrowsePage must not change reader-style immersive safe-area expansion')
}

function normalizeSortKey(value) {
  return value.trim().toLocaleLowerCase()
}

function clampPageIndex(pageIndex, totalPages) {
  if (totalPages <= 0) return 0
  if (pageIndex < 0) return 0
  if (pageIndex >= totalPages) return totalPages - 1
  return Math.floor(pageIndex)
}

function calculateProgressRatio(pageIndex, totalPages) {
  if (totalPages <= 0) return 0
  return (clampPageIndex(pageIndex, totalPages) + 1) / totalPages
}

function createReadingProgress(comicId, chapterId, totalPages) {
  return {
    comicId,
    chapterId,
    pageIndex: 0,
    totalPages,
    progressRatio: totalPages > 0 ? 1 / totalPages : 0,
    completed: totalPages === 0,
    updatedAt: Date.now(),
  }
}

function updateReadingProgress(previous, pageIndex, pageId, totalPages = previous.totalPages) {
  const nextIndex = clampPageIndex(pageIndex, totalPages)
  return {
    comicId: previous.comicId,
    chapterId: previous.chapterId,
    pageId,
    pageIndex: nextIndex,
    totalPages,
    progressRatio: calculateProgressRatio(nextIndex, totalPages),
    completed: totalPages <= 0 || nextIndex >= totalPages - 1,
    updatedAt: Date.now(),
  }
}

function normalizeCategoryIds(categoryIds) {
  if (categoryIds === undefined) return []
  const nextIds = []
  for (const categoryId of categoryIds) {
    const normalized = categoryId.trim()
    if (normalized.length > 0 && !nextIds.includes(normalized)) {
      nextIds.push(normalized)
    }
  }
  return nextIds
}

function withComicCategoryIds(comic, categoryIds) {
  const normalizedCategoryIds = normalizeCategoryIds(categoryIds)
  const nextComic = {
    ...comic,
    updatedAt: Date.now(),
  }
  if (normalizedCategoryIds.length > 0) {
    nextComic.categoryIds = normalizedCategoryIds
  } else {
    delete nextComic.categoryIds
  }
  return nextComic
}

function buildSourceDetailRequestJson(sourceId, operation, args, hostHints, sourceSettings = {}) {
  return JSON.stringify({
    type: 'request',
    version: 1,
    requestId: `detail-${operation}-${sourceId}-1`,
    operation,
    sourceId,
    args,
    settings: sourceSettings,
    hostHints,
  })
}

function sourceMangaResponseItem(response) {
  if (response.data?.manga !== undefined) return response.data.manga
  if (response.data?.item !== undefined) return response.data.item
  return response.data?.items === undefined || response.data.items.length === 0 ? undefined : response.data.items[0]
}

function sourceChapterResponseItems(response) {
  if (response.data?.items !== undefined) return response.data.items
  return response.data?.chapters ?? []
}

function sourcePageResponseItems(response) {
  return response.data?.pages !== undefined ? response.data.pages : (response.data?.items ?? [])
}

function optionalSourceString(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value : undefined
}

function sourcePageImageUrl(item) {
  const directUrl = optionalSourceString(item.url) ?? optionalSourceString(item.uri)
  if (directUrl !== undefined) return directUrl
  const image = item.image
  if (image === undefined || image === null || Array.isArray(image) || typeof image !== 'object') return undefined
  return optionalSourceString(image.url) ?? optionalSourceString(image.uri)
}

function isReaderRemoteImageSourceUri(uri) {
  const normalized = uri.trim().replace(/\\/g, '/').toLocaleLowerCase()
  return normalized.startsWith('http://') || normalized.startsWith('https://')
}

function buildReaderSourceImageRequestArgs(pageId, pageUri) {
  const args = { pageId }
  if (pageUri !== undefined && isReaderRemoteImageSourceUri(pageUri)) {
    args.url = pageUri
    args.pageUri = pageUri
  }
  return args
}

function sourceComicId(sourceId, mangaId) {
  const normalizedSourceId = sourceId?.trim()
  if (normalizedSourceId === undefined || normalizedSourceId.length === 0) return mangaId
  return mangaId.startsWith(`${normalizedSourceId}:`) ? mangaId : `${normalizedSourceId}:${mangaId}`
}

function decodeSourceDisplayTextEscapes(value) {
  let decoded = ''
  let index = 0
  while (index < value.length) {
    if (value.charAt(index) === '\\' &&
      value.charAt(index + 1) === 'u' &&
      index + 6 <= value.length) {
      const hex = value.substring(index + 2, index + 6)
      if (/^[0-9a-fA-F]{4}$/.test(hex)) {
        decoded += String.fromCharCode(Number.parseInt(hex, 16))
        index += 6
        continue
      }
    }
    decoded += value.charAt(index)
    index += 1
  }
  return decoded
}

for (const symbol of ['Comic', 'Chapter', 'Page', 'ReadingProgress', 'LibraryItem']) {
  assertExport(modelSource, symbol)
}
assertExport(modelSource, 'serializeComic')
assertExport(modelSource, 'deserializeComic')
assertExport(modelSource, 'updateReadingProgress')
assertExport(modelSource, 'normalizeCategoryIds')
assertExport(modelSource, 'withComicCategoryIds')
assertExport(libraryStoreSource, 'LibraryStore')
assertExport(libraryStoreSource, 'InMemoryLibraryStore')
assertExport(progressStoreSource, 'ReadingProgressStore')
assertExport(progressStoreSource, 'InMemoryReadingProgressStore')
assertExport(readerSessionStoreSource, 'ReaderSessionStore')
assertExport(readerPreferencesStoreSource, 'READER_PREFERENCES_STORE_NAME')
assertExport(readerPreferencesStoreSource, 'PAGE_MODE_KEY')
assertExport(readerPreferencesStoreSource, 'READING_DIRECTION_KEY')
assertExport(readerPreferencesStoreSource, 'THEME_MODE_KEY')
assertExport(readerPreferencesStoreSource, 'BACKGROUND_MODE_KEY')
assertExport(readerPreferencesStoreSource, 'SHOW_PROGRESS_CONTROLS_KEY')
assertExport(readerPreferencesStoreSource, 'KEEP_SCREEN_AWAKE_KEY')
assertExport(offlineDownloadStoreSource, 'OfflineDownloadStore')
assertExport(offlineDownloadStoreSource, 'OfflineDownloadStatus')
assertExport(offlineDownloadStoreSource, 'OfflineChapterDownloadManifest')
assertExport(offlineDownloadServiceSource, 'OfflineDownloadService')
assertExport(readerSessionStoreSource, 'InMemoryReaderSessionStore')
assertExport(mockLibraryDataSource, 'MockLibraryComic')
assertExport(mockLibraryDataSource, 'LibraryViewModel')
assertExport(mockLibraryDataSource, 'MOCK_LIBRARY_READER_SESSION')
assertExport(mockLibraryDataSource, 'createSeededLibraryStore')
assertExport(mockLibraryDataSource, 'createLibraryViewModelFromComics')
assertExport(mockLibraryDataSource, 'createLibraryViewModelFromStores')
assertExport(mockLibraryDataSource, 'createLibraryViewModel')
assertExport(sourceTextNormalizerSource, 'decodeSourceDisplayTextEscapes')
assertExport(sourceTextNormalizerSource, 'normalizeSourceDisplayText')
assertExport(libraryRepositorySource, 'LibraryRepository')
assertExport(libraryRepositorySource, 'StoreBackedLibraryRepository')
assertExport(libraryRepositorySource, 'upsertComicAndCreateLibraryViewModel')
assertExport(libraryPersistenceSource, 'LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION')
assertExport(libraryPersistenceSource, 'PersistedLibraryStoreDocument')
assertExport(libraryPersistenceSource, 'persistComic')
assertExport(libraryPersistenceSource, 'hydrateComic')
assertExport(libraryPersistenceSource, 'serializeLibraryStore')
assertExport(libraryPersistenceSource, 'hydrateLibraryStoreFromJson')
assertExport(libraryPersistenceSource, 'LibraryStorePersistenceAdapter')
assertExport(libraryPersistenceSource, 'AppFilesLibraryStorePersistenceAdapter')
assertExport(libraryPersistenceSource, 'LibraryStorePersistenceService')
assertExport(libraryPersistenceSource, 'upsertComicAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'assignComicCategoriesAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'isRemovableLocalComic')
assertExport(libraryPersistenceSource, 'removeComicAndPersistLibraryStore')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateResultStatus')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateComicResult')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateSummary')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateService')
assertExport(libraryUpdateServiceSource, 'formatLibraryUpdateSummary')
assertExport(libraryUpdatePreferencesStoreSource, 'LibraryUpdatePreferences')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_PREFERENCES_STORE_NAME')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_INTERVAL_HOURS_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_CHECKED_AT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_INTERVAL_OPTIONS')
assertExport(libraryUpdatePreferencesStoreSource, 'DEFAULT_LIBRARY_UPDATE_PREFERENCES')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateAutoCheckEnabled')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateIntervalHours')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateTimestamp')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateSummaryText')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateAutoCheckLabel')
assertExport(libraryUpdatePreferencesStoreSource, 'isLibraryUpdateDue')
assertExport(libraryUpdatePreferencesStoreSource, 'LibraryUpdatePreferencesStore')

assert.match(entryAbilitySource, /const TRANSPARENT_COLOR: string = '#00FFFFFF'/, 'EntryAbility must keep transparent system bar color')
assert.match(entryAbilitySource, /setWindowLayoutFullScreen\(true\)/, 'EntryAbility must keep fullscreen window layout')
assert.match(entryAbilitySource, /statusBarColor:\s*TRANSPARENT_COLOR/, 'EntryAbility status bar must remain transparent')
assert.match(entryAbilitySource, /navigationBarColor:\s*TRANSPARENT_COLOR/, 'EntryAbility navigation bar must remain transparent')
assert.match(indexSource, /\.ignoreLayoutSafeArea\(\s*\[\s*LayoutSafeAreaType\.SYSTEM\s*\][\s\S]*\[LayoutSafeAreaEdge\.TOP,\s*LayoutSafeAreaEdge\.BOTTOM\]/, 'root shell must continue drawing under system safe areas')
assert.match(indexSource, /\.expandSafeArea\(\[SafeAreaType\.SYSTEM\], \[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/, 'root shell must preserve immersive safe-area expansion')
assert.doesNotMatch(indexSource, /HdsNavigation\(this\.appPathStack\)[\s\S]*\.(padding|margin)\(/, 'root app shell must not use root padding or margin to avoid safe areas')
assert.match(secondaryListScaffoldSource, /Blank\(\)\.height\(this\.topH \+ ThemeConstants\.TITLE_BAR_HEIGHT\)/, 'shared list scaffold must include an internal top spacer')
assert.match(secondaryListScaffoldSource, /Blank\(\)\.height\(this\.bottomH \+ this\.bottomPadding \+ this\.keyboardPadding\(\)\)/, 'shared list scaffold must include an internal bottom spacer')
for (const [source, label] of [
  [libraryPageSource, 'LibraryPage'],
  [browsePageSource, 'BrowsePage'],
  [historyPageSource, 'HistoryPage'],
  [searchPageSource, 'SearchPage'],
  [settingsPageSource, 'SettingsPage'],
]) {
  assertUsesSecondaryListSafeArea(source, label)
}
for (const [source, label] of [
  [importPageSource, 'ImportPage'],
  [sourceBrowsePageSource, 'SourceBrowsePage'],
  [sourceSearchPageSource, 'SourceSearchPage'],
  [mangaDetailPageSource, 'MangaDetailPage'],
]) {
  assertUsesScrollContentSafeArea(source, label)
}
assertSourceBrowseFloatingTabViewportClearance(sourceBrowsePageSource)

assert.match(
  libraryPersistenceSource,
  /export interface PersistedLibraryStoreDocument\s*{[^}]*\bschemaVersion:\s*number\b/s,
  'PersistedLibraryStoreDocument.schemaVersion must be required in production source',
)

assert.match(
  offlineDownloadStoreSource,
  /OFFLINE_DOWNLOAD_ROOT_DIR_NAME:\s*string = 'downloads'/,
  'offline downloads must be stored under a dedicated files/downloads root',
)
assert.match(
  offlineDownloadStoreSource,
  /assertSafeOfflineDownloadRoot[\s\S]*hasTraversalSegment[\s\S]*OFFLINE_DOWNLOAD_ROOT_DIR_NAME/,
  'offline download paths must reject traversal and stay under files/downloads',
)
assert.match(
  offlineDownloadStoreSource,
  /export interface OfflineChapterDownloadManifest\s*{[\s\S]*status:\s*OfflineDownloadStatus[\s\S]*pageCount:\s*number[\s\S]*downloadedPageCount:\s*number/s,
  'offline manifest must track status, pageCount, and downloadedPageCount',
)
assert.match(
  offlineDownloadStoreSource,
  /resolveDownloadedPage[\s\S]*manifest\.status !== OfflineDownloadStatus\.DOWNLOADED[\s\S]*manifest\.status !== OfflineDownloadStatus\.PARTIAL[\s\S]*fs\.accessSync\(page\.localPath\)/,
  'offline resolver must expose existing files for downloaded and partial chapters',
)
assert.doesNotMatch(
  offlineDownloadStoreSource,
  /reader-remote-image-cache|RemoteImageCacheStore|url:\s*string/,
  'offline download store must be separate from transient reader-remote-image-cache and not persist page URLs',
)
assert.match(
  offlineDownloadServiceSource,
  /fetchReaderRemoteSourceBytes/,
  'offline download service must reuse reader/source image request resolution for remote pages',
)
assert.match(
  offlineDownloadServiceSource,
  /ReaderPageRenderKind\.LOCAL_FILE_IMAGE[\s\S]*copyLocalFile/,
  'offline download service must copy existing local reader images into durable download storage',
)
assert.match(
  offlineDownloadServiceSource,
  /createReaderPageRenderSource\(config, index, \{ preferOffline: false \}\)/,
  'offline download service must bypass existing offline files while downloading pages',
)
assert.match(
  offlineDownloadServiceSource,
  /copyLocalFile\(sourcePath: string, targetPath: string\)[\s\S]*sourcePath === targetPath[\s\S]*fs\.statSync\(targetPath\)\.size[\s\S]*OpenMode\.TRUNC/,
  'offline download service must not truncate a file by copying it onto itself',
)
assert.match(
  mangaDetailPageSource,
  /downloadButtonLabel\(\)[\s\S]*'下载中'[\s\S]*'重新下载'[\s\S]*'下载章节'/,
  'MangaDetailPage must label completed downloads as a redownload action',
)
assert.match(
  mangaDetailPageSource,
  /Button\(this\.downloadButtonLabel\(\)[\s\S]*this\.handleDownloadChapter\(\)/,
  'MangaDetailPage must expose a user-visible chapter download action',
)
assert.match(
  mangaDetailPageSource,
  /已下载 \$\{summary\.downloadedPageCount\}\/\$\{summary\.pageCount\} 页/,
  'MangaDetailPage must expose an explicit downloaded N/M page status',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /debug|sandbox|internal|manifest\.v1|files\/downloads/i,
  'MangaDetailPage visible copy must avoid debug/internal storage wording',
)
assert.match(
  libraryPersistenceSource,
  /export interface PersistedLibraryStoreDocument\s*{[^}]*\bcomics:\s*PersistedComic\[\]/s,
  'PersistedLibraryStoreDocument.comics must be required in production source',
)
assert.match(
  modelSource,
  /categoryIds\?:\s*string\[\][\s\S]*export function normalizeCategoryIds/,
  'Comic model must expose optional categoryIds with a normalizer for backward-compatible uncategorized rows',
)
assert.match(
  libraryStoreSource,
  /filterCategoryId\?:\s*LibraryCategoryFilter[\s\S]*categoryFilter === 'uncategorized'[\s\S]*categoryIds\.includes\(categoryFilter\)/,
  'LibraryListOptions must support all, uncategorized, and concrete category filtering',
)
assert.match(
  libraryPageSource,
  /private categoryLabel\(\): string \{[\s\S]*'全部分类'[\s\S]*CategoryMenu[\s\S]*MenuItem\(\{ content: '未分类' \}\)[\s\S]*MenuItem\(\{ content: '稍后阅读' \}\)[\s\S]*MenuItem\(\{ content: '收藏' \}\)/,
  'LibraryPage must expose user-visible category filter labels',
)
assert.match(
  libraryPageSource,
  /Button\('稍后阅读'\)[\s\S]*assignSelectedCategory\(\[LIBRARY_CATEGORY_READ_LATER_ID\]\)[\s\S]*Button\('收藏'\)[\s\S]*assignSelectedCategory\(\[LIBRARY_CATEGORY_FAVORITE_ID\]\)[\s\S]*Button\('清除分类'\)[\s\S]*assignSelectedCategory\(undefined\)/,
  'LibraryPage selection mode must expose bulk category assignment and clearing actions',
)
assert.match(
  indexSource,
  /onAssignCategoriesRequested:\s*\(comicIds: ComicId\[\], categoryIds\?: string\[\]\) => \{[\s\S]*return this\.handleAssignCategoriesRequested\(comicIds, categoryIds\)/,
  'Index must wire LibraryPage category assignment into the persistent library store',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-update', title: '检查书架更新', detail: '尚未检查' \}/,
  'SettingsPage must expose a foreground library update entry under Data',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-auto-update', title: '自动检查更新', detail: '关闭' \}[\s\S]*\{ key: 'library-update-interval', title: '检查间隔', detail: '每 24 小时' \}[\s\S]*\{ key: 'library-update', title: '检查书架更新', detail: '尚未检查' \}/,
  'SettingsPage must expose auto-check preferences next to the foreground library update entry',
)
assert.match(
  settingsPageSource,
  /Toggle\(\{ type: ToggleType\.Switch, isOn: this\.libraryUpdatePreferences\.autoCheckEnabled \}\)[\s\S]*setLibraryAutoUpdateEnabled\(isOn\)/,
  'SettingsPage must use a switch row for library auto-check preference',
)
assert.match(
  settingsPageSource,
  /title: '检查间隔'[\s\S]*message: '打开应用时自动检查书架更新'[\s\S]*每 12 小时[\s\S]*每 24 小时[\s\S]*每 48 小时/,
  'SettingsPage interval selector copy must describe app-open foreground checks',
)
assert.match(
  settingsPageSource,
  /loadLibraryUpdatePreferences\(\)[\s\S]*this\.runDueLibraryUpdateCheck\(\)/,
  'SettingsPage must evaluate due library checks when update preferences load',
)
assert.match(
  settingsPageSource,
  /isLibraryUpdateDue\(this\.libraryUpdatePreferences, Date\.now\(\)\)[\s\S]*this\.checkLibraryUpdates\('due'\)/,
  'SettingsPage must trigger due checks only when preferences say they are due',
)
assert.match(
  settingsPageSource,
  /new LibraryUpdateService\([\s\S]*this\.libraryStore[\s\S]*this\.sourceRegistry[\s\S]*this\.libraryPersistenceService[\s\S]*\)\s*[\s\S]*\.checkLibraryUpdates\(\)/,
  'SettingsPage must trigger LibraryUpdateService from the foreground entry',
)
assert.match(
  settingsPageSource,
  /saveLastSummary\(summary\.checkedAt, summaryText\)/,
  'SettingsPage must persist the latest manual or due update summary',
)
assert.match(
  settingsPageSource,
  /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20 \+ ThemeConstants\.SPACE_XL/,
  'SettingsPage must preserve SecondaryListScaffold bottom clearance while adding update status',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /DEFAULT_LIBRARY_UPDATE_PREFERENCES:[\s\S]*autoCheckEnabled:\s*false[\s\S]*intervalHours:\s*24/,
  'LibraryUpdatePreferencesStore defaults must disable automatic checks and use a 24h interval',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /LIBRARY_UPDATE_INTERVAL_OPTIONS: number\[\] = \[12, 24, 48\]/,
  'LibraryUpdatePreferencesStore must expose 12h, 24h, and 48h interval choices',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /catch \(_error\) \{[\s\S]*autoCheckEnabled: DEFAULT_LIBRARY_UPDATE_PREFERENCES\.autoCheckEnabled[\s\S]*intervalHours: DEFAULT_LIBRARY_UPDATE_PREFERENCES\.intervalHours/,
  'LibraryUpdatePreferencesStore must safely restore defaults when preference data cannot be read',
)
assert.doesNotMatch(
  settingsPageSource,
  /后台自动更新|系统通知|通知权限/,
  'SettingsPage copy must not imply background auto updates or system notifications',
)
assert.match(
  indexSource,
  /SettingsPage\(\{[\s\S]*libraryStore: this\.libraryStore[\s\S]*sourceRegistry: this\.sourceRegistry[\s\S]*onLibraryChanged: \(\) => \{[\s\S]*this\.refreshLibrarySnapshot\(\)/,
  'Index must wire Settings library update completion back into the live shelf snapshot',
)
assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.LOCAL_ARCHIVE[\s\S]*ComicSourceKind\.LOCAL_FOLDER[\s\S]*本地导入暂不支持远程更新/,
  'LibraryUpdateService must skip local imports instead of faking update support',
)
assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.KOMGA_REMOTE[\s\S]*ComicSourceKind\.OPDS_REMOTE[\s\S]*ComicSourceKind\.WEBDAV_REMOTE[\s\S]*该远程库暂未接入安全的元数据刷新/,
  'LibraryUpdateService must skip unsupported private remote metadata refresh paths',
)
assert.match(
  libraryUpdateServiceSource,
  /mergeSourceChapters[\s\S]*pages: existing\.pages[\s\S]*pageCount: existing\.pageCount/,
  'LibraryUpdateService must preserve existing pages when refreshing source-runtime chapter metadata',
)
for (const [source, label] of [
  [settingsPageSource, 'SettingsPage'],
  [libraryUpdateServiceSource, 'LibraryUpdateService'],
  [libraryUpdatePreferencesStoreSource, 'LibraryUpdatePreferencesStore'],
  [indexSource, 'Index'],
]) {
  assert.doesNotMatch(source, /源市场|内置源|聚合源|fake source market/i, `${label} must not introduce built-in/fake source-market copy`)
}
assert.match(
  libraryPersistenceSource,
  /function assertSupportedLibraryStoreDocument[\s\S]*document\.schemaVersion !== LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION[\s\S]*throw new Error/,
  'production hydrate path must reject missing or unsupported schema versions',
)
assert.match(
  libraryPersistenceSource,
  /function parseValidatedLibraryStoreComics[\s\S]*assertSupportedLibraryStoreDocument\(document\)[\s\S]*return document\.comics\.map[\s\S]*export function hydrateLibraryStoreFromJson[\s\S]*const comics = parseValidatedLibraryStoreComics\(payload\)[\s\S]*libraryStore\.clear\(\)/,
  'production hydrate path must validate schemaVersion and persisted rows before clearing the store',
)
assert.match(
  libraryPersistenceSource,
  /export class AppFilesLibraryStorePersistenceAdapter[\s\S]*fs\.readTextSync[\s\S]*fs\.openSync[\s\S]*fs\.writeSync/,
  'HarmonyOS file adapter must use app sandbox fileIo text read/write APIs',
)
assert.match(
  libraryPersistenceSource,
  /restore\(\):\s*void\s*{[\s\S]*payload === undefined \|\| payload\.length === 0[\s\S]*return[\s\S]*hydrateLibraryStoreFromJson/,
  'empty persistence payload must leave the seeded startup store intact',
)
assert.match(
  libraryPersistenceSource,
  /export function upsertComicAndPersistLibraryStore[\s\S]*const previousPayload = serializeLibraryStore\(libraryStore\)[\s\S]*libraryStore\.(upsertComic|addComic)\(comic\)[\s\S]*persistenceService\.persist\(\)[\s\S]*hydrateLibraryStoreFromJson\(libraryStore, previousPayload\)[\s\S]*throw error/,
  'save-after-upsert helper must rollback the live store and rethrow when persistence fails',
)
assert.match(
  libraryPersistenceSource,
  /export function isRemovableLocalComic[\s\S]*comic\.sourcePath\.startsWith\('mock:\/\/'\)[\s\S]*ComicSourceKind\.LOCAL_ARCHIVE[\s\S]*ComicSourceKind\.LOCAL_FOLDER/,
  'remove affordance must exclude seed/demo rows and only allow local archive/folder comics',
)
assert.match(
  libraryPersistenceSource,
  /export function removeComicAndPersistLibraryStore[\s\S]*const comic = libraryStore\.getComic\(comicId\)[\s\S]*if \(!isRemovableLocalComic\(comic\)\) \{[\s\S]*return false[\s\S]*const previousPayload = serializeLibraryStore\(libraryStore\)[\s\S]*libraryStore\.removeComic\(comicId\)[\s\S]*persistenceService\.persist\(\)[\s\S]*hydrateLibraryStoreFromJson\(libraryStore, previousPayload\)[\s\S]*throw error/,
  'save-after-remove helper must no-op missing or protected rows and rollback the live store when persistence fails',
)
assert.match(
  indexSource,
  /@State private libraryComics: Comic\[\][\s\S]*private refreshLibrarySnapshot\(\): void \{[\s\S]*this\.libraryComics = this\.libraryStore\.listComics\(\)[\s\S]*this\.libraryRevision \+= 1[\s\S]*private handleRemoveComicRequested\(comicId: ComicId\): boolean[\s\S]*removeComicAndPersistLibraryStore[\s\S]*this\.refreshLibrarySnapshot\(\)[\s\S]*return true/,
  'confirmed remove must publish a fresh comic array snapshot after successful persistence so the live shelf re-renders',
)
assert.match(
  indexSource,
  /onRemoveComicRequested:\s*\(comicId: ComicId\) => \{[\s\S]*return this\.handleRemoveComicRequested\(comicId\)/,
  'Index remove callback must return whether deletion actually succeeded so LibraryPage can avoid stale local refresh on no-op paths',
)
assert.match(
  indexSource,
  /\[library-remove\] requested found=\$\{requestedComic !== undefined\} removable=\$\{removable\}[\s\S]*\[library-remove\] result removed=false persistence=unavailable[\s\S]*\[library-remove\] result removed=true persistence=unavailable[\s\S]*\[library-remove\] result removed=true persistence=available[\s\S]*\[library-remove\] result removed=false persistence=available/,
  'remove diagnostics must use redacted status-only request/result fields',
)
assert.doesNotMatch(
  indexSource,
  /\[library-remove\][^\n]*(title=|sourcePath|source path|id=\$\{comicId\}|\/)/,
  'remove diagnostics must not log comic titles, source paths, filesystem paths, or raw comic IDs',
)
assert.match(
  libraryPageSource,
  /@Prop @Watch\('syncDisplayedSnapshotFromProps'\) libraryComics: Comic\[\][\s\S]*@Prop @Watch\('syncDisplayedSnapshotFromProps'\) libraryRevision: number[\s\S]*@State private displayedComics: Comic\[\][\s\S]*@State private displayedRevision: number/,
  'LibraryPage must own a reactive displayed snapshot that can update while the mounted shelf stays alive',
)
assert.match(
  libraryPageSource,
  /private syncDisplayedSnapshotFromProps\(\): void \{[\s\S]*this\.refreshDisplayedSnapshotFromStore\(\)[\s\S]*this\.displayedRevision = this\.libraryRevision[\s\S]*private refreshDisplayedSnapshotFromStore\(\): void \{[\s\S]*this\.libraryStore\.listLibraryItems[\s\S]*this\.displayedRevision \+= 1/,
  'LibraryPage must sync parent snapshots for restore/import and locally refresh from the store after confirmed remove (post LS sort/filter — sync now delegates to store refresh)',
)
assert.match(
  libraryPageSource,
  /createLibraryViewModelFromComics\(this\.displayedComics[\s\S]*this\.displayedComics\.length > 0[\s\S]*`\$\{this\.displayedRevision\}:\$\{comic\.id\}`/,
  'LibraryPage Continue Reading, counts, and grid identity must derive from the local displayed snapshot',
)
assert.match(
  comicCoverCardSource,
  /export struct ComicCoverCard \{[\s\S]*@Prop comic: ComicCoverInfo[\s\S]*@Prop title: string[\s\S]*@Prop subtitle: string[\s\S]*@Prop progressText: string[\s\S]*Text\(this\.displayTitle\(\)\)[\s\S]*Text\(this\.displaySubtitle\(\)\)/,
  'ComicCoverCard must receive primitive reactive props for grid cells so reused card instances update after remove/reorder',
)
assert.match(
  libraryPageSource,
  /struct ContinueReadingShelfCard \{[\s\S]*@Prop info: ContinueReadingCardViewModel[\s\S]*@Prop revision: number[\s\S]*Text\(this\.info\.title\)[\s\S]*onOpenReader\(this\.info\.comicId\)/,
  'Continue Reading must render through reactive props so the live title changes when the first/latest comic is removed',
)
assert.match(
  libraryPageSource,
  /private comicRenderKey\(comic: ComicCoverInfo\): string \{[\s\S]*`\$\{this\.displayedRevision\}:\$\{comic\.id\}`[\s\S]*ForEach\(comics[\s\S]*this\.comicRenderKey\(comic\)/,
  'grid item identity must include the explicit library revision to avoid stale ArkUI child reuse after shrink/reorder',
)
assert.match(
  libraryPageSource,
  /private gridComics\(\): ComicCoverInfo\[\] \{[\s\S]*this\.viewModel\(\)\.comics\.map[\s\S]*return \{[\s\S]*id: comic\.id[\s\S]*title: comic\.title[\s\S]*subtitle: comic\.subtitle[\s\S]*progressText: comic\.progressText/,
  'grid source must rebuild fresh primitive card rows from the displayed snapshot before rendering',
)
assert.match(
  libraryPageSource,
  /private LibraryGridEven\(comics: ComicCoverInfo\[\]\)[\s\S]*this\.LibraryGrid\(comics\)[\s\S]*private LibraryGridOdd\(comics: ComicCoverInfo\[\]\)[\s\S]*this\.LibraryGrid\(comics\)[\s\S]*if \(this\.isEvenDisplayedRevision\(\)\) \{[\s\S]*this\.LibraryGridEven\(this\.gridComics\(\)\)[\s\S]*\} else \{[\s\S]*this\.LibraryGridOdd\(this\.gridComics\(\)\)/,
  'library grid must cross a real conditional remount boundary when displayedRevision changes',
)
assert.match(
  libraryPageSource,
  /showRemoveConfirmation[\s\S]*primaryButton:\s*\{[\s\S]*value:\s*'移出'[\s\S]*if \(this\.onRemoveComicRequested\(comic\.id\)\) \{[\s\S]*this\.refreshDisplayedSnapshotFromStore\(\)[\s\S]*secondaryButton:\s*\{[\s\S]*value:\s*'取消'/,
  'destructive remove confirmation must refresh the mounted displayed snapshot only after the primary remove callback succeeds while cancel remains secondary',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /JSON\.stringify\(\{\s*operation:\s*operation,\s*manga_id:|JSON\.stringify\(\{\s*operation:\s*'get_chapters',\s*manga_id:/,
  'MangaDetailPage source detail/chapter operations must not use the legacy manga_id request shape',
)
assert.match(
  mangaDetailPageSource,
  /private buildSourceDetailRequestJson[\s\S]*appSourceSettingsStore\.loadForSource\(sourceId\)[\s\S]*type:\s*'request'[\s\S]*version:\s*1[\s\S]*requestId:\s*`detail-\$\{operation\}-\$\{sourceId\}-\$\{Date\.now\(\)\}`[\s\S]*operation,[\s\S]*sourceId,[\s\S]*args,[\s\S]*settings,[\s\S]*hostHints/,
  'MangaDetailPage must build v1 source request envelopes for detail, chapters, and pages',
)
assert.match(
  readerPageSourceAdapterSource,
  /appSourceSettingsStore\.loadForSource\(sourceRuntimeId\)[\s\S]*operation: 'get_image_request'[\s\S]*settings,/,
  'ReaderPageSourceAdapter source image requests must inject per-source settings',
)
assert.match(
  mangaDetailPageSource,
  /const args: SourceMangaRequestArgs = \{ mangaId \}[\s\S]*this\.buildSourceDetailRequestJson\(entry\.sourceId, operation, args, \{ network: true \}\)/,
  'get_manga must send args.mangaId with network host hints',
)
assert.match(
  mangaDetailPageSource,
  /const args: SourceChaptersRequestArgs = \{[\s\S]*mangaId,[\s\S]*cursor:\s*null,[\s\S]*limit:\s*100[\s\S]*this\.buildSourceDetailRequestJson\(entry\.sourceId, 'get_chapters', args, \{ network: true \}\)/,
  'get_chapters must send args.mangaId plus a page cursor/limit with network host hints',
)
assert.match(
  mangaDetailPageSource,
  /private sourceMangaResponseItem[\s\S]*response\.data\?\.manga[\s\S]*response\.data\?\.item[\s\S]*response\.data\?\.items/,
  'get_manga parsing must accept data.manga, data.item, and data.items[0]',
)
assert.match(
  mangaDetailPageSource,
  /private sourceChapterResponseItems[\s\S]*response\.data\?\.items[\s\S]*response\.data\?\.chapters/,
  'get_chapters parsing must accept data.items and data.chapters',
)
assert.match(
  mangaDetailPageSource,
  /const rows = response\.data\?\.pages !== undefined \? response\.data\.pages : \(response\.data\?\.items \?\? \[\]\)/,
  'get_pages parsing must keep accepting data.pages and fixture data.items',
)
assert.match(
  mangaDetailPageSource,
  /private sourcePageImageUrl\(item: Record<string, Object>\): string \| undefined \{[\s\S]*this\.optionalSourceString\(item\['url'\]\) \?\? this\.optionalSourceString\(item\['uri'\]\)[\s\S]*const image = item\['image'\][\s\S]*imageRecord\['url'\]/,
  'get_pages parsing must accept nested image.url while preserving top-level url/uri compatibility',
)
assert.match(
  readerPageSourceAdapterSource,
  /interface ReaderSourceImageRequestArgs \{[\s\S]*pageId: string[\s\S]*url\?: string[\s\S]*pageUri\?: string[\s\S]*\}/,
  'reader source image request args must include pageId plus optional URL fields',
)
assert.match(
  readerPageSourceAdapterSource,
  /if \(pageUri !== undefined && isReaderRemoteImageSourceUri\(pageUri\)\) \{[\s\S]*args\.url = pageUri[\s\S]*args\.pageUri = pageUri[\s\S]*\}/,
  'reader source image requests must pass the source page URL when it is a valid remote URL',
)
assert.match(
  mangaDetailPageSource,
  /mangaId\.startsWith\(`\$\{normalizedSourceId\}:`\) \? mangaId : `\$\{normalizedSourceId\}:\$\{mangaId\}`/,
  'source comic ids must avoid double-prefixing already normalized source manga ids',
)
assert.match(
  mangaDetailPageSource,
  /private copyWasmBytes\(entry: SourceRuntimeRegistryEntry\): Uint8Array \{[\s\S]*new Uint8Array\(entry\.wasmBytes\.byteLength\)[\s\S]*copy\.set\(entry\.wasmBytes\)[\s\S]*return copy/,
  'MangaDetailPage must copy source wasm bytes before each taskpool call',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /new Uint8Array\(entry\.wasmBytes\.buffer\)/,
  'MangaDetailPage must not pass the registry wasm ArrayBuffer directly to taskpool',
)
assert.equal(
  (mangaDetailPageSource.match(/this\.copyWasmBytes\(entry\)/g) ?? []).length,
  3,
  'MangaDetailPage must copy wasm bytes for get_manga, get_chapters, and get_pages taskpool calls',
)

const mangaRequest = JSON.parse(buildSourceDetailRequestJson(
  'local.test.koma.fixture',
  'get_manga',
  { mangaId: 'manga:fixture-series' },
  { network: true },
  { 'setting:language': 'zh-Hans' },
))
assert.deepEqual(
  {
    type: mangaRequest.type,
    version: mangaRequest.version,
    operation: mangaRequest.operation,
    sourceId: mangaRequest.sourceId,
    args: mangaRequest.args,
    settings: mangaRequest.settings,
    hostHints: mangaRequest.hostHints,
  },
  {
    type: 'request',
    version: 1,
    operation: 'get_manga',
    sourceId: 'local.test.koma.fixture',
    args: { mangaId: 'manga:fixture-series' },
    settings: { 'setting:language': 'zh-Hans' },
    hostHints: { network: true },
  },
  'detail request envelope must match the source runtime v1 contract and include source settings',
)
const chaptersRequest = JSON.parse(buildSourceDetailRequestJson(
  'local.test.koma.fixture',
  'get_chapters',
  { mangaId: 'manga:fixture-series', page: { cursor: null, limit: 100 } },
  { network: true },
))
assert.deepEqual(chaptersRequest.args, { mangaId: 'manga:fixture-series', page: { cursor: null, limit: 100 } }, 'chapters request must use args.mangaId and page limit')
const pagesRequest = JSON.parse(buildSourceDetailRequestJson(
  'local.test.koma.fixture',
  'get_pages',
  { chapterId: 'chapter:fixture-series:001' },
  { network: true, imageStrategy: 'descriptor-or-url' },
))
assert.deepEqual(pagesRequest.args, { chapterId: 'chapter:fixture-series:001' }, 'pages request must keep args.chapterId')
assert.deepEqual(pagesRequest.hostHints, { network: true, imageStrategy: 'descriptor-or-url' }, 'pages request must keep source image host hints')
assert.equal(
  sourcePageImageUrl({ id: 'page:0', image: { kind: 'url', url: 'https://uploads.mangadex.org/data/hash/001.jpg' } }),
  'https://uploads.mangadex.org/data/hash/001.jpg',
  'source pages must preserve nested image.url from source runtime responses',
)
assert.equal(
  sourcePageImageUrl({ id: 'page:1', url: 'https://cdn.example.test/top-level.jpg', image: { url: 'https://cdn.example.test/nested.jpg' } }),
  'https://cdn.example.test/top-level.jpg',
  'source pages must keep top-level url precedence for compatibility',
)
assert.deepEqual(
  buildReaderSourceImageRequestArgs('page:0', 'https://uploads.mangadex.org/data/hash/001.jpg'),
  {
    pageId: 'page:0',
    url: 'https://uploads.mangadex.org/data/hash/001.jpg',
    pageUri: 'https://uploads.mangadex.org/data/hash/001.jpg',
  },
  'reader get_image_request args must include the real remote page URL for source runtimes',
)
assert.deepEqual(
  buildReaderSourceImageRequestArgs('page:descriptor', 'source://descriptor/one'),
  { pageId: 'page:descriptor' },
  'reader get_image_request args must not pass non-remote descriptor URIs as image URLs',
)

const sourceRepoDetailResponse = {
  ok: true,
  data: {
    manga: {
      id: 'manga:source-repo',
      title: 'Source Repo Detail',
    },
  },
}
const sourceRepoChaptersResponse = {
  ok: true,
  data: {
    items: [
      { id: 'chapter:source-repo:001', title: 'Chapter 1' },
      { id: 'chapter:source-repo:002', title: 'Chapter 2' },
    ],
  },
}
assert.equal(sourceMangaResponseItem(sourceRepoDetailResponse).title, 'Source Repo Detail', 'get_manga must parse source-repo data.manga.title')
assert.equal(sourceChapterResponseItems(sourceRepoChaptersResponse).length, 2, 'get_chapters must parse source-repo data.items chapters')
assert.equal(sourceMangaResponseItem({ ok: true, data: { item: { title: 'Fixture Item' } } }).title, 'Fixture Item', 'get_manga must keep data.item compatibility')
assert.equal(sourceMangaResponseItem({ ok: true, data: { items: [{ title: 'Fixture Items' }] } }).title, 'Fixture Items', 'get_manga must keep data.items[0] compatibility')
assert.equal(sourceChapterResponseItems({ ok: true, data: { chapters: [{ id: 'legacy-chapter' }] } }).length, 1, 'get_chapters must keep data.chapters compatibility')
assert.equal(sourcePageResponseItems({ ok: true, data: { pages: [{ id: 'page-1' }] } }).length, 1, 'get_pages must parse real-source data.pages')
assert.equal(sourcePageResponseItems({ ok: true, data: { items: [{ id: 'fixture-page-1' }] } }).length, 1, 'get_pages must keep fixture data.items compatibility')
assert.equal(sourceComicId('source.alpha', 'manga-1'), 'source.alpha:manga-1', 'source comic id should prefix plain manga ids')
assert.equal(sourceComicId('source.alpha', 'source.alpha:manga-1'), 'source.alpha:manga-1', 'source comic id should not double-prefix normalized manga ids')
assert.equal(
  decodeSourceDisplayTextEscapes('Days Off in the Dragon\\u0027s Stomach'),
  "Days Off in the Dragon's Stomach",
  'source display text unicode escapes must decode apostrophes',
)
assert.equal(
  decodeSourceDisplayTextEscapes('Title \\u4e2d\\u6587 \\uZZZZ'),
  'Title 中文 \\uZZZZ',
  'source display text unicode escapes must decode valid hex quads and leave invalid escapes untouched',
)
assert.match(
  sourceModelsSource,
  /title:\s*normalizeSourceDisplayText\(title\) \?\? title[\s\S]*description:\s*normalizeSourceDisplayText\(payload\.description\)[\s\S]*tags:\s*normalizeTags\(payload\)/,
  'SourceManga list normalization must decode source-provided title, description, and tags at model boundary',
)
assert.match(
  sourceModelsSource,
  /title:\s*normalizeSourceDisplayText\(title\) \?\? title[\s\S]*scanlator:\s*normalizeSourceDisplayText\(row\.scanlator\)/,
  'SourceChapter normalization must decode source-provided chapter display strings',
)
assert.match(
  mangaDetailModelsSource,
  /optionalSourceDisplayString\(item\['title'\]\)/,
  'Manga detail normalization must decode source-provided title text',
)
assert.match(
  mangaDetailModelsSource,
  /description:\s*optionalSourceDisplayString\(item\['description'\]\)/,
  'Manga detail normalization must decode source-provided description text',
)
assert.match(
  mangaDetailModelsSource,
  /tags:\s*sourceStringList\(item\['tags'\]\)/,
  'Manga detail normalization must decode source-provided tags',
)

assert.match(backupServiceSource, /const BACKUP_SCHEMA_VERSION:\s*number = 3/, 'backup export must use schema v3')
assert.match(backupServiceSource, /const BACKUP_SCHEMA_VERSION_V2:\s*number = 2/, 'backup import must keep schema v2 compatibility')
assert.match(backupServiceSource, /const BACKUP_SCHEMA_VERSION_V1:\s*number = 1/, 'backup import must keep schema v1 compatibility')
assert.match(
  backupServiceSource,
  /document\.schemaVersion !== BACKUP_SCHEMA_VERSION &&[\s\S]*document\.schemaVersion !== BACKUP_SCHEMA_VERSION_V2 &&[\s\S]*document\.schemaVersion !== BACKUP_SCHEMA_VERSION_V1/,
  'backup import must accept v1, v2, and v3 schema versions',
)
assert.match(
  backupServiceSource,
  /sourcePackages:\s*exportInstalledSourcePackages\(\)/,
  'backup v2 export must include source packages',
)
assert.match(
  backupServiceSource,
  /sourceSettings:\s*appSourceSettingsStore\.exportAll\(\)/,
  'backup v3 export must include sanitized source settings',
)
assert.match(
  backupServiceSource,
  /settings:\s*await new ReaderPreferencesStore\(this\.context\)\.load\(\)/,
  'backup export must include SettingsPage reader preferences',
)
assert.match(
  backupServiceSource,
  /if \(document\.schemaVersion >= BACKUP_SCHEMA_VERSION\) \{[\s\S]*importSourceSettings\(document\.sourceSettings\)[\s\S]*if \(document\.schemaVersion >= BACKUP_SCHEMA_VERSION_V2\) \{[\s\S]*importSourcePackages\(document\.sourcePackages\)[\s\S]*importSettings\(document\.settings\)/,
  'backup v3 import must restore source settings while preserving v2 source package/settings restore',
)
assert.match(
  backupServiceSource,
  /restoreSourcePackagesFromBackup\(this\.context, sourcePackages\)/,
  'backup v2 import must delegate source package restoration to the app registry helper',
)
assert.match(
  backupServiceSource,
  /backgroundMode:\s*settings\.backgroundMode \?\? DEFAULT_READER_PREFERENCES\.backgroundMode[\s\S]*showProgressControls:\s*settings\.showProgressControls \?\? DEFAULT_READER_PREFERENCES\.showProgressControls[\s\S]*keepScreenAwake:\s*settings\.keepScreenAwake \?\? DEFAULT_READER_PREFERENCES\.keepScreenAwake[\s\S]*new ReaderPreferencesStore\(this\.context\)\.save\(nextSettings\)/,
  'backup v2 import must preserve backward compatibility while restoring reader settings MVP preferences',
)
assert.doesNotMatch(
  backupServiceSource,
  /console\.(?:info|warn|error)\([^)]*(?:libraryStore|readingProgress|remoteServers|sourcePackages|wasmBase64|payload)/,
  'backup service must not log raw backup payloads, credentials, or source package bytes',
)
assert.match(
  sourceSettingsStoreSource,
  /filterSafeValues[\s\S]*descriptorIsCredentialLike\(key, ''\)/,
  'source settings backups must use the same non-secret filtering as normal persistence',
)
assert.match(
  sourcePackageManagerPageSource,
  /hasUpdate\(entry: SourceIndexEntry\)[\s\S]*compareVersion\(entry\.version, installed\.version\) > 0/,
  'source package manager must detect index updates by installed/current version',
)
assert.match(
  sourcePackageManagerPageSource,
  /installIndexEntry\(entry: SourceIndexEntry, replaceExisting: boolean = false\)[\s\S]*setEnabled\(this\.context\(\), existing\.id, false\)/,
  'source package manager update action must reinstall matching index entries while preserving disabled state',
)
assert.match(
  sourcePackageManagerPageSource,
  /Button\(this\.updateCheckBusy \? '检查中' : '检查更新'\)[\s\S]*checkInstalledUpdates\(\)/,
  'source package manager must expose a check-update action for installed source packages',
)
assert.match(
  sourcePackageManagerPageSource,
  /checkInstalledUpdates\(\): Promise<void>[\s\S]*this\.sourceIndexService\.fetchIndex\(url\)[\s\S]*compareVersion\(entry\.version, source\.version\)/,
  'installed source update checks must fetch the user-configured source index and compare remote/local versions',
)
assert.match(
  sourcePackageManagerPageSource,
  /\[SourcePackageUpdate\] step=check_start count=[\s\S]*\[SourcePackageUpdate\] step=check_done update=[\s\S]*\[SourcePackageUpdate\] step=install_start id=[\s\S]*\[SourcePackageUpdate\] step=install_done id=[\s\S]*\[SourcePackageUpdate\] step=install_failed id=/,
  'source package manager must log SourcePackageUpdate check and install lifecycle events',
)
assert.match(
  sourcePackageManagerPageSource,
  /updateStatusText\(source: InstalledSourcePackage\): string[\s\S]*更新：检查中[\s\S]*更新：已是最新 v[\s\S]*更新：可更新 v[\s\S]*更新：索引中未找到[\s\S]*更新：检查失败：[\s\S]*更新：未检查/,
  'installed source cards must render per-package update status text',
)
assert.match(
  sourcePackageManagerPageSource,
  /if \(this\.updateEntry\(source\.id\) !== undefined\) \{[\s\S]*Button\(this\.updateActionLabel\(source\.id\)\)[\s\S]*this\.updateInstalledPackage\(source\)/,
  'installed source cards must show an update button only when an update is available',
)
assert.doesNotMatch(
  sourcePackageManagerPageSource,
  /源市场|内置源|聚合源|fake source market/i,
  'source package manager must not introduce forbidden source-market copy',
)
assert.doesNotMatch(
  sourcePackageManagerPageSource,
  /sourceIndexUrl:\s*string\s*=\s*['"]https?:\/\//,
  'source package manager must not include a built-in default source index URL',
)
assertUsesSecondaryListSafeArea(sourcePackageManagerPageSource, 'SourcePackageManagerPage')
assert.match(
  sourceRuntimeAppRegistrySource,
  /restoreRuntimeRegistryEntry\(removedExisting\)[\s\S]*removeAppSourcePackageDir\(context, packageDir\)[\s\S]*registeredReplacementSourceId = sourceId[\s\S]*persistInstalledSources\(context\)[\s\S]*removeAppSourcePackageDir\(context, existingDir\)[\s\S]*appSourceRuntimeRegistry\.remove\(registeredReplacementSourceId\)[\s\S]*restoreRuntimeRegistryEntry\(removedExisting\)/,
  'source package replacement must restore the previous registry entry on failed registration/persist and delete the old package only after the replacement is persisted',
)
assert.match(
  sourceRuntimeAppRegistrySource,
  /expectedSourceId\?: string[\s\S]*sourceId !== expectedSourceId[\s\S]*reason=source_id_mismatch[\s\S]*return \{ ok: false, reasonCode: 'source_id_mismatch' \}/,
  'source package replacement must verify the downloaded manifest source id before replacing an installed source',
)
assert.match(
  sourceIndexServiceSource,
  /installFromBytes\(this\.context, archiveBytes, entry\.pkg, entry\.id\)/,
  'source index installs must pass the expected source id into package validation',
)
assert.match(
  sourcePackageManagerPageSource,
  /sourceReasonText\(reasonCode: string \| undefined\)[\s\S]*checksum_mismatch[\s\S]*network_not_allowed[\s\S]*unsafe_archive_entry[\s\S]*missing_manifest[\s\S]*smoke_failed/,
  'source package manager must map install/index/smoke reason codes to user-readable text',
)
assert.doesNotMatch(
  sourcePackageManagerPageSource,
  /失败：' \+ e\.message|失败：' \+ \(error as Error\)\.message/,
  'source package manager must not surface raw internal exception messages',
)

const comic = {
  id: 'comic-1',
  title: 'Volume 02',
  sourceKind: 'local_archive',
  sourcePath: '/library/Volume 02.cbz',
  coverUri: '/cache/comic-1/cover.jpg',
  sortTitle: normalizeSortKey('Volume 02'),
  preferredDirection: 'right_to_left',
  chapters: [
    {
      id: 'chapter-1',
      comicId: 'comic-1',
      title: 'Chapter 10',
      index: 10,
      sourcePath: '/library/Volume 02.cbz',
      sortKey: normalizeSortKey('Chapter 10'),
      pageCount: 2,
      createdAt: 100,
      updatedAt: 100,
      pages: [
        {
          id: 'page-1',
          comicId: 'comic-1',
          chapterId: 'chapter-1',
          index: 1,
          fileName: '001.jpg',
          uri: '/library/Volume 02.cbz/001.jpg',
          sortKey: normalizeSortKey('001.jpg'),
        },
        {
          id: 'page-2',
          comicId: 'comic-1',
          chapterId: 'chapter-1',
          index: 2,
          fileName: '010.jpg',
          uri: '/library/Volume 02.cbz/010.jpg',
          sortKey: normalizeSortKey('010.jpg'),
        },
      ],
    },
  ],
  chapterCount: 1,
  pageCount: 2,
  createdAt: 100,
  updatedAt: 200,
  lastImportedAt: 200,
}

const roundTrip = JSON.parse(JSON.stringify(comic))
assert.deepEqual(roundTrip, comic, 'comic JSON round trip must preserve model fields')
assert.equal(roundTrip.chapters[0].pages[1].sortKey, '010.jpg', 'page sortKey must survive serialization')

const progress = createReadingProgress('comic-1', 'chapter-1', 12)
assert.equal(progress.pageIndex, 0)
assert.equal(progress.progressRatio, 1 / 12)
assert.equal(progress.completed, false)

const updated = updateReadingProgress(progress, 99, 'page-12')
assert.equal(updated.pageIndex, 11, 'page index must clamp to the last page')
assert.equal(updated.progressRatio, 1)
assert.equal(updated.completed, true)
assert.equal(updated.pageId, 'page-12')

const firstPage = updateReadingProgress(updated, -4, 'page-1')
assert.equal(firstPage.pageIndex, 0, 'negative page index must clamp to zero')
assert.equal(firstPage.completed, false)

const libraryItems = [
  { id: 'b', sortTitle: normalizeSortKey('Beta'), createdAt: 2 },
  { id: 'a', sortTitle: normalizeSortKey('alpha'), createdAt: 1 },
  { id: 'c', sortTitle: normalizeSortKey('alpha'), createdAt: 0 },
].sort((a, b) => {
  const titleCompare = a.sortTitle.localeCompare(b.sortTitle)
  return titleCompare !== 0 ? titleCompare : a.createdAt - b.createdAt
})

assert.deepEqual(libraryItems.map((item) => item.id), ['c', 'a', 'b'], 'library items should sort by normalized title then creation time')

const mockLibraryReaderSession = {
  comicId: 'local-01',
  chapterId: 'chapter-8',
  totalPages: 5,
}

const mockLibraryComics = [
  {
    id: 'local-01',
    title: '雨后街区',
    subtitle: '本地 ZIP - 12 章',
    chapterTitle: '第 8 话',
    fallbackProgressText: '第 8 话',
    coverColor: '#16745F',
    accentColor: '#2FAE84',
    pageCount: 5,
  },
  {
    id: 'local-02',
    title: '北窗短篇集',
    subtitle: '图片文件夹 - 6 章',
    chapterTitle: '第 1 话',
    fallbackProgressText: '未读',
    coverColor: '#344E7A',
    accentColor: '#6E92CE',
    pageCount: 1,
  },
  {
    id: 'local-03',
    title: '海边的慢速列车',
    subtitle: 'CBZ - 4 章',
    chapterTitle: '第 2 话',
    fallbackProgressText: '42%',
    coverColor: '#8A6240',
    accentColor: '#D39A62',
    pageCount: 1,
  },
  {
    id: 'local-04',
    title: '午后三点的笔记',
    subtitle: '本地 ZIP - 18 章',
    chapterTitle: '第 3 话',
    fallbackProgressText: '第 3 话',
    coverColor: '#7A405D',
    accentColor: '#C46B92',
    pageCount: 1,
  },
  {
    id: 'local-05',
    title: '旧书店巡礼',
    subtitle: '图片文件夹 - 9 章',
    chapterTitle: '第 1 话',
    fallbackProgressText: '新加入',
    coverColor: '#51624D',
    accentColor: '#89A57D',
    pageCount: 1,
  },
  {
    id: 'local-06',
    title: '银河便签',
    subtitle: 'CBZ - 21 章',
    chapterTitle: '第 15 话',
    fallbackProgressText: '第 15 话',
    coverColor: '#4C4A70',
    accentColor: '#928FD2',
    pageCount: 1,
  },
]

function progressPercent(progress) {
  if (progress === undefined) return 0
  return Math.round(progress.progressRatio * 100)
}

function formatLibraryProgressText(comic, progress) {
  if (progress === undefined) return comic.fallbackProgressText
  if (progress.completed) return '已读完'
  return `${progressPercent(progress)}%`
}

function createMockComic(item, createdAt) {
  const chapterId = item.id === mockLibraryReaderSession.comicId ? mockLibraryReaderSession.chapterId : `${item.id}-chapter-1`
  const pages = Array.from({ length: item.pageCount }, (_, index) => ({
    id: `${chapterId}-page-${index + 1}`,
    comicId: item.id,
    chapterId,
    index,
    fileName: `${String(index + 1).padStart(3, '0')}.jpg`,
    uri: `mock://${item.id}/${String(index + 1).padStart(3, '0')}.jpg`,
    sortKey: `${String(index + 1).padStart(3, '0')}.jpg`,
  }))
  return {
    id: item.id,
    title: item.title,
    subtitle: item.subtitle,
    sourceKind: 'local_archive',
    sourcePath: `mock://${item.id}`,
    coverUri: pages[0]?.uri,
    sortTitle: normalizeSortKey(item.title),
    preferredDirection: 'right_to_left',
    chapters: [{
      id: chapterId,
      comicId: item.id,
      title: item.chapterTitle,
      index: 0,
      sourcePath: `mock://${item.id}`,
      sortKey: normalizeSortKey(item.chapterTitle),
      pages,
      pageCount: pages.length,
      createdAt,
      updatedAt: createdAt,
    }],
    chapterCount: 1,
    pageCount: pages.length,
    createdAt,
    updatedAt: createdAt,
    lastImportedAt: createdAt,
  }
}

function createSeededStore() {
  const comics = new Map()
  mockLibraryComics.forEach((item, index) => {
    const comic = createMockComic(item, index + 1)
    comics.set(comic.id, comic)
  })
  return {
    upsertComic(comic) {
      comics.set(comic.id, comic)
    },
    listComics() {
      return Array.from(comics.values()).sort((a, b) => {
        const titleCompare = a.sortTitle.localeCompare(b.sortTitle)
        return titleCompare !== 0 ? titleCompare : a.createdAt - b.createdAt
      })
    },
    clear() {
      comics.clear()
    },
    getComic(comicId) {
      return comics.get(comicId)
    },
    removeComic(comicId) {
      comics.delete(comicId)
    },
  }
}

function persistPage(page) {
  const row = {
    id: page.id,
    comicId: page.comicId,
    chapterId: page.chapterId,
    index: page.index,
    fileName: page.fileName,
    uri: page.uri,
    sortKey: page.sortKey,
  }
  if (page.width !== undefined) row.width = page.width
  if (page.height !== undefined) row.height = page.height
  if (page.byteSize !== undefined) row.byteSize = page.byteSize
  return row
}

function hydratePage(row) {
  assertValidPersistedPage(row)
  const page = {
    id: row.id,
    comicId: row.comicId,
    chapterId: row.chapterId,
    index: row.index,
    fileName: row.fileName,
    uri: row.uri,
    sortKey: row.sortKey,
  }
  if (row.width !== undefined) page.width = row.width
  if (row.height !== undefined) page.height = row.height
  if (row.byteSize !== undefined) page.byteSize = row.byteSize
  return page
}

function persistChapter(chapter) {
  return {
    id: chapter.id,
    comicId: chapter.comicId,
    title: chapter.title,
    index: chapter.index,
    sourcePath: chapter.sourcePath,
    sortKey: chapter.sortKey,
    pages: chapter.pages.map((page) => persistPage(page)),
    pageCount: chapter.pageCount,
    createdAt: chapter.createdAt,
    updatedAt: chapter.updatedAt,
  }
}

function hydrateChapter(row) {
  assertValidPersistedChapter(row)
  return {
    id: row.id,
    comicId: row.comicId,
    title: row.title,
    index: row.index,
    sourcePath: row.sourcePath,
    sortKey: row.sortKey,
    pages: row.pages.map((page) => hydratePage(page)),
    pageCount: row.pageCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  }
}

function persistComic(comic) {
  const row = {
    id: comic.id,
    title: comic.title,
    sourceKind: comic.sourceKind,
    sourcePath: comic.sourcePath,
    sortTitle: comic.sortTitle,
    preferredDirection: comic.preferredDirection,
    chapters: comic.chapters.map((chapter) => persistChapter(chapter)),
    chapterCount: comic.chapterCount,
    pageCount: comic.pageCount,
    createdAt: comic.createdAt,
    updatedAt: comic.updatedAt,
    lastImportedAt: comic.lastImportedAt,
  }
  if (comic.subtitle !== undefined) row.subtitle = comic.subtitle
  if (comic.author !== undefined) row.author = comic.author
  const categoryIds = normalizeCategoryIds(comic.categoryIds)
  if (categoryIds.length > 0) row.categoryIds = categoryIds
  if (comic.coverUri !== undefined) row.coverUri = comic.coverUri
  return row
}

function hydrateComic(row) {
  assertValidPersistedComic(row)
  const comic = {
    id: row.id,
    title: row.title,
    sourceKind: row.sourceKind,
    sourcePath: row.sourcePath,
    sortTitle: row.sortTitle,
    preferredDirection: row.preferredDirection,
    chapters: row.chapters.map((chapter) => hydrateChapter(chapter)),
    chapterCount: row.chapterCount,
    pageCount: row.pageCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    lastImportedAt: row.lastImportedAt,
  }
  if (row.subtitle !== undefined) comic.subtitle = row.subtitle
  if (row.author !== undefined) comic.author = row.author
  const categoryIds = normalizeCategoryIds(row.categoryIds)
  if (categoryIds.length > 0) comic.categoryIds = categoryIds
  if (row.coverUri !== undefined) comic.coverUri = row.coverUri
  return comic
}

function serializeLibraryStore(store) {
  return JSON.stringify({
    schemaVersion: 1,
    comics: store.listComics().map((item) => persistComic(item)),
  })
}

function assertSupportedLibraryStoreDocument(document) {
  if (document.schemaVersion !== 1) {
    throw new Error(`Unsupported library store persistence schema version: ${document.schemaVersion}`)
  }
}

function assertPersistedObject(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected object`)
  }
}

function assertStringField(value, label) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid library store persistence ${label}: expected non-empty string`)
  }
}

function assertOptionalStringField(value, label) {
  if (value !== undefined && typeof value !== 'string') {
    throw new Error(`Invalid library store persistence ${label}: expected string`)
  }
}

function assertOptionalStringArrayField(value, label) {
  if (value === undefined) return
  if (!Array.isArray(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected string array`)
  }
  value.forEach((item, index) => assertStringField(item, `${label}.${index}`))
}

function assertNumberField(value, label) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected finite number`)
  }
}

function assertOptionalNumberField(value, label) {
  if (value !== undefined && (typeof value !== 'number' || !Number.isFinite(value))) {
    throw new Error(`Invalid library store persistence ${label}: expected finite number`)
  }
}

function assertComicSourceKind(value, label) {
  if (!['local_archive', 'local_folder', 'private_library'].includes(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected comic source kind`)
  }
}

function assertReadingDirection(value, label) {
  if (!['left_to_right', 'right_to_left', 'webtoon'].includes(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected reading direction`)
  }
}

function assertValidPersistedPage(row) {
  assertPersistedObject(row, 'page')
  assertStringField(row.id, 'page.id')
  assertStringField(row.comicId, 'page.comicId')
  assertStringField(row.chapterId, 'page.chapterId')
  assertNumberField(row.index, 'page.index')
  assertStringField(row.fileName, 'page.fileName')
  assertStringField(row.uri, 'page.uri')
  assertStringField(row.sortKey, 'page.sortKey')
  assertOptionalNumberField(row.width, 'page.width')
  assertOptionalNumberField(row.height, 'page.height')
  assertOptionalNumberField(row.byteSize, 'page.byteSize')
}

function assertValidPersistedChapter(row) {
  assertPersistedObject(row, 'chapter')
  assertStringField(row.id, 'chapter.id')
  assertStringField(row.comicId, 'chapter.comicId')
  assertStringField(row.title, 'chapter.title')
  assertNumberField(row.index, 'chapter.index')
  assertStringField(row.sourcePath, 'chapter.sourcePath')
  assertStringField(row.sortKey, 'chapter.sortKey')
  if (!Array.isArray(row.pages)) {
    throw new Error('Invalid library store persistence chapter.pages: expected array')
  }
  assertNumberField(row.pageCount, 'chapter.pageCount')
  assertNumberField(row.createdAt, 'chapter.createdAt')
  assertNumberField(row.updatedAt, 'chapter.updatedAt')
}

function assertValidPersistedComic(row) {
  assertPersistedObject(row, 'comic')
  assertStringField(row.id, 'comic.id')
  assertStringField(row.title, 'comic.title')
  assertOptionalStringField(row.subtitle, 'comic.subtitle')
  assertOptionalStringField(row.author, 'comic.author')
  assertOptionalStringArrayField(row.categoryIds, 'comic.categoryIds')
  assertComicSourceKind(row.sourceKind, 'comic.sourceKind')
  assertStringField(row.sourcePath, 'comic.sourcePath')
  assertOptionalStringField(row.coverUri, 'comic.coverUri')
  assertStringField(row.sortTitle, 'comic.sortTitle')
  assertReadingDirection(row.preferredDirection, 'comic.preferredDirection')
  if (!Array.isArray(row.chapters)) {
    throw new Error('Invalid library store persistence comic.chapters: expected array')
  }
  assertNumberField(row.chapterCount, 'comic.chapterCount')
  assertNumberField(row.pageCount, 'comic.pageCount')
  assertNumberField(row.createdAt, 'comic.createdAt')
  assertNumberField(row.updatedAt, 'comic.updatedAt')
  assertNumberField(row.lastImportedAt, 'comic.lastImportedAt')
}

function parseValidatedLibraryStoreComics(payload) {
  const document = JSON.parse(payload)
  assertPersistedObject(document, 'document')
  assertSupportedLibraryStoreDocument(document)
  if (!Array.isArray(document.comics)) {
    throw new Error('Invalid library store persistence comics: expected array')
  }
  return document.comics.map((row) => hydrateComic(row))
}

function hydrateLibraryStoreFromJson(store, payload) {
  const comics = parseValidatedLibraryStoreComics(payload)
  store.clear()
  comics.forEach((comic) => store.upsertComic(comic))
}

class MemoryLibraryStorePersistenceAdapter {
  constructor(payload, saveError) {
    this.payload = payload
    this.saveError = saveError
    this.savedPayloads = []
  }

  load() {
    return this.payload
  }

  save(payload) {
    if (this.saveError !== undefined) {
      throw this.saveError
    }
    this.payload = payload
    this.savedPayloads.push(payload)
  }
}

class LibraryStorePersistenceService {
  constructor(store, adapter) {
    this.store = store
    this.adapter = adapter
  }

  restore() {
    const payload = this.adapter.load()
    if (payload === undefined || payload.length === 0) {
      return
    }
    hydrateLibraryStoreFromJson(this.store, payload)
  }

  persist() {
    this.adapter.save(serializeLibraryStore(this.store))
  }
}

function upsertComicAndPersistLibraryStore(store, persistenceService, comic) {
  const previousPayload = serializeLibraryStore(store)
  store.upsertComic(comic)
  try {
    persistenceService.persist()
  } catch (error) {
    hydrateLibraryStoreFromJson(store, previousPayload)
    throw error
  }
}

function isRemovableLocalComic(comic) {
  if (comic === undefined) return false
  if (comic.sourcePath.startsWith('mock://')) return false
  return comic.sourceKind === 'local_archive' || comic.sourceKind === 'local_folder'
}

function removeComicAndPersistLibraryStore(store, persistenceService, comicId) {
  const comic = store.getComic(comicId)
  if (!isRemovableLocalComic(comic)) {
    return false
  }
  const previousPayload = serializeLibraryStore(store)
  store.removeComic(comicId)
  try {
    persistenceService.persist()
    return true
  } catch (error) {
    hydrateLibraryStoreFromJson(store, previousPayload)
    throw error
  }
}

function assignComicCategoriesAndPersistLibraryStore(store, persistenceService, comicIds, categoryIds) {
  const normalizedCategoryIds = normalizeCategoryIds(categoryIds)
  const previousPayload = serializeLibraryStore(store)
  let changedCount = 0
  comicIds.forEach((comicId) => {
    const comic = store.getComic(comicId)
    if (comic !== undefined) {
      store.upsertComic(withComicCategoryIds(comic, normalizedCategoryIds))
      changedCount += 1
    }
  })
  if (changedCount === 0) return 0
  try {
    persistenceService.persist()
    return changedCount
  } catch (error) {
    hydrateLibraryStoreFromJson(store, previousPayload)
    throw error
  }
}

function listLibraryItemsByCategory(store, filterCategoryId = 'all') {
  return store.listComics().filter((comic) => {
    const categoryIds = normalizeCategoryIds(comic.categoryIds)
    if (filterCategoryId === 'all') return true
    if (filterCategoryId === 'uncategorized') return categoryIds.length === 0
    return categoryIds.includes(filterCategoryId)
  })
}

function createPresentationMap() {
  return new Map(mockLibraryComics.map((item) => [item.id, item]))
}

function getChapterTitle(comic, progress, presentation) {
  if (progress !== undefined) {
    const chapter = comic.chapters.find((item) => item.id === progress.chapterId)
    if (chapter !== undefined) return chapter.title
  }
  return presentation?.chapterTitle ?? comic.chapters[0]?.title ?? comic.title
}

function createLibraryViewModelFromComics(storeComics, progressByComicId, presentationByComicId = new Map()) {
  const comics = storeComics.map((comic) => {
    const itemProgress = progressByComicId.get(comic.id)
    const presentation = presentationByComicId.get(comic.id)
    return {
      id: comic.id,
      title: comic.title,
      subtitle: presentation?.subtitle ?? comic.subtitle ?? `本地 ZIP - ${comic.chapterCount} 章`,
      progressText: formatLibraryProgressText(presentation ?? { fallbackProgressText: '未读' }, itemProgress),
      coverColor: presentation?.coverColor ?? '#16745F',
      accentColor: presentation?.accentColor ?? '#2FAE84',
      pageCount: comic.pageCount,
      coverUri: comic.coverUri,
    }
  })
  let continueComic = storeComics[0]
  let continueProgress
  for (const item of storeComics) {
    const itemProgress = progressByComicId.get(item.id)
    if (itemProgress !== undefined && (continueProgress === undefined || itemProgress.updatedAt > continueProgress.updatedAt)) {
      continueComic = item
      continueProgress = itemProgress
    }
  }
  if (continueComic === undefined) {
    return {
      comics,
      continueReading: {
        comicId: '',
        title: '',
        detail: '',
        progress: 0,
        color: '#16745F',
      },
    }
  }
  const continuePresentation = presentationByComicId.get(continueComic.id)
  const chapterTitle = getChapterTitle(continueComic, continueProgress, continuePresentation)
  return {
    comics,
    continueReading: {
      title: continueComic.title,
      detail: continueProgress === undefined ? `继续阅读 ${chapterTitle}` : `继续阅读 ${chapterTitle} / 第 ${continueProgress.pageIndex + 1} 页 · ${progressPercent(continueProgress)}%`,
      progress: continueProgress === undefined ? 0 : progressPercent(continueProgress),
      color: continuePresentation?.coverColor ?? '#16745F',
      comicId: continueComic.id,
      coverUri: continueComic.coverUri,
    },
  }
}

function createLibraryViewModelFromStores(store, progressByComicId, presentationByComicId = new Map()) {
  return createLibraryViewModelFromComics(store.listComics(), progressByComicId, presentationByComicId)
}

const sessionProgress = updateReadingProgress(
  createReadingProgress(mockLibraryReaderSession.comicId, mockLibraryReaderSession.chapterId, mockLibraryReaderSession.totalPages),
  1,
  'mock-page-2',
  mockLibraryReaderSession.totalPages,
)
const seededStore = createSeededStore()
const seededVm = createLibraryViewModelFromStores(seededStore, new Map(), createPresentationMap())
assert.equal(seededVm.comics.length, 6, 'initial mock seed should generate the current six-book shelf')
assert.equal(seededVm.comics.find((item) => item.id === 'local-01').title, '雨后街区')
assert.equal(seededVm.comics.find((item) => item.id === 'local-01').coverUri, 'mock://local-01/001.jpg')

const libraryVm = createLibraryViewModelFromStores(seededStore, new Map([[sessionProgress.comicId, sessionProgress]]), createPresentationMap())
assert.equal(libraryVm.continueReading.title, '雨后街区')
assert.equal(libraryVm.continueReading.detail, '继续阅读 第 8 话 / 第 2 页 · 40%')
assert.equal(libraryVm.continueReading.progress, 40)
assert.equal(libraryVm.continueReading.comicId, 'local-01')
assert.equal(libraryVm.comics.find((item) => item.id === 'local-01').progressText, '40%')

const importedComic = {
  id: 'imported-01',
  title: 'Imported Volume',
  sourceKind: 'local_archive',
  sourcePath: '/library/Imported Volume.cbz',
  coverUri: '/library/Imported Volume.cbz#001.jpg',
  sortTitle: normalizeSortKey('Imported Volume'),
  preferredDirection: 'right_to_left',
  chapters: [{
    id: 'imported-01-chapter-1',
    comicId: 'imported-01',
    title: 'Imported Volume',
    index: 0,
    sourcePath: '/library/Imported Volume.cbz',
    sortKey: normalizeSortKey('Imported Volume'),
    pages: [
      { id: 'imported-page-1', comicId: 'imported-01', chapterId: 'imported-01-chapter-1', index: 0, fileName: '001.jpg', uri: '/library/Imported Volume.cbz#001.jpg', sortKey: '001.jpg' },
      { id: 'imported-page-2', comicId: 'imported-01', chapterId: 'imported-01-chapter-1', index: 1, fileName: '002.jpg', uri: '/library/Imported Volume.cbz#002.jpg', sortKey: '002.jpg' },
      { id: 'imported-page-3', comicId: 'imported-01', chapterId: 'imported-01-chapter-1', index: 2, fileName: '003.jpg', uri: '/library/Imported Volume.cbz#003.jpg', sortKey: '003.jpg' },
    ],
    pageCount: 3,
    createdAt: 500,
    updatedAt: 500,
  }],
  chapterCount: 1,
  pageCount: 3,
  createdAt: 500,
  updatedAt: 500,
  lastImportedAt: 500,
}

seededStore.upsertComic(importedComic)
const importedVm = createLibraryViewModelFromStores(seededStore, new Map(), createPresentationMap())
const importedCard = importedVm.comics.find((item) => item.id === 'imported-01')
assert.equal(importedVm.comics.length, 7, 'upsert should add imported comic to the shelf view model')
assert.equal(importedCard.title, 'Imported Volume')
assert.equal(importedCard.pageCount, 3)
assert.equal(importedCard.coverUri, '/library/Imported Volume.cbz#001.jpg')

const importedProgress = updateReadingProgress(
  createReadingProgress('imported-01', 'imported-01-chapter-1', 3),
  1,
  'imported-page-2',
  3,
)
const importedProgressVm = createLibraryViewModelFromStores(seededStore, new Map([[importedProgress.comicId, importedProgress]]), createPresentationMap())
assert.equal(importedProgressVm.continueReading.title, 'Imported Volume')
assert.equal(importedProgressVm.continueReading.detail, '继续阅读 Imported Volume / 第 2 页 · 67%')
assert.equal(importedProgressVm.continueReading.progress, 67)
assert.equal(importedProgressVm.comics.find((item) => item.id === 'imported-01').progressText, '67%')

const persistedPayload = serializeLibraryStore(seededStore)
const persistedDocument = JSON.parse(persistedPayload)
assert.equal(persistedDocument.schemaVersion, 1, 'library persistence payload must be versioned')
assert.equal(persistedDocument.comics.length, 7, 'library persistence payload must include all comics')
assert.deepEqual(Object.keys(persistedDocument), ['schemaVersion', 'comics'], 'library persistence document key order must be stable')

const persistedImported = persistedDocument.comics.find((item) => item.id === 'imported-01')
assert.equal(persistedImported.title, 'Imported Volume')
assert.equal(persistedImported.pageCount, 3)
assert.equal(persistedImported.coverUri, '/library/Imported Volume.cbz#001.jpg')
assert.equal(persistedImported.categoryIds, undefined, 'old imported comics without categoryIds must persist as uncategorized')
assert.deepEqual(
  persistedImported.chapters[0].pages.map((page) => page.uri),
  [
    '/library/Imported Volume.cbz#001.jpg',
    '/library/Imported Volume.cbz#002.jpg',
    '/library/Imported Volume.cbz#003.jpg',
  ],
  'persisted page URIs must remain stable',
)

const restoredStore = createSeededStore()
hydrateLibraryStoreFromJson(restoredStore, persistedPayload)
const restoredImported = restoredStore.getComic('imported-01')
assert.equal(restoredStore.listComics().length, 7, 'hydrating a store must replace current contents with persisted comics')
assert.equal(restoredImported.title, importedComic.title)
assert.equal(restoredImported.pageCount, importedComic.pageCount)
assert.equal(restoredImported.coverUri, importedComic.coverUri)
assert.deepEqual(restoredImported.chapters[0].pages.map((page) => page.id), ['imported-page-1', 'imported-page-2', 'imported-page-3'])
assert.equal(restoredImported.chapters[0].pages[1].uri, '/library/Imported Volume.cbz#002.jpg')

const optionalPayload = JSON.stringify({
  schemaVersion: 1,
  comics: [{
    ...persistedImported,
    coverUri: undefined,
    subtitle: undefined,
    author: undefined,
    extraFutureField: 'ignored',
    chapters: [{
      ...persistedImported.chapters[0],
      extraFutureChapterField: 'ignored',
      pages: persistedImported.chapters[0].pages.map((page) => ({
        ...page,
        width: undefined,
        height: undefined,
        byteSize: undefined,
        extraFuturePageField: 'ignored',
      })),
    }],
  }],
})
const optionalStore = createSeededStore()
hydrateLibraryStoreFromJson(optionalStore, optionalPayload)
const optionalComic = optionalStore.getComic('imported-01')
assert.equal(optionalStore.listComics().length, 1, 'hydrating a smaller document must clear stale comics')
assert.equal(optionalComic.coverUri, undefined, 'missing optional coverUri must be accepted')
assert.equal(optionalComic.categoryIds, undefined, 'missing optional categoryIds must be accepted as uncategorized')
assert.equal(optionalComic.chapters[0].pages[0].width, undefined, 'missing optional page dimensions must be accepted')
assert.equal(optionalComic.extraFutureField, undefined, 'unknown comic fields must not hydrate into the runtime model')
assert.equal(optionalComic.chapters[0].extraFutureChapterField, undefined, 'unknown chapter fields must not hydrate into the runtime model')
assert.equal(optionalComic.chapters[0].pages[0].extraFuturePageField, undefined, 'unknown page fields must not hydrate into the runtime model')

const emptyStore = createSeededStore()
hydrateLibraryStoreFromJson(emptyStore, JSON.stringify({ schemaVersion: 1, comics: [] }))
assert.equal(emptyStore.listComics().length, 0, 'explicit empty comics array should hydrate as an empty library')

const missingComicsStore = createSeededStore()
const missingComicsBefore = missingComicsStore.listComics().map((item) => item.id)
assert.throws(
  () => hydrateLibraryStoreFromJson(missingComicsStore, JSON.stringify({ schemaVersion: 1 })),
  /Invalid library store persistence comics: expected array/,
  'missing comics array must reject before mutating the library store',
)
assert.deepEqual(
  missingComicsStore.listComics().map((item) => item.id),
  missingComicsBefore,
  'missing comics array must leave existing library data unchanged',
)

const missingVersionStore = createSeededStore()
const missingVersionBefore = missingVersionStore.listComics().map((item) => item.id)
assert.throws(
  () => hydrateLibraryStoreFromJson(missingVersionStore, JSON.stringify({ comics: [] })),
  /Unsupported library store persistence schema version: undefined/,
  'missing schemaVersion must reject before mutating the library store',
)
assert.deepEqual(
  missingVersionStore.listComics().map((item) => item.id),
  missingVersionBefore,
  'missing schemaVersion must leave existing library data unchanged',
)

const unsupportedVersionStore = createSeededStore()
const unsupportedVersionBefore = unsupportedVersionStore.listComics().map((item) => item.id)
assert.throws(
  () => hydrateLibraryStoreFromJson(unsupportedVersionStore, JSON.stringify({ schemaVersion: 2, comics: [] })),
  /Unsupported library store persistence schema version: 2/,
  'unsupported schemaVersion must reject before mutating the library store',
)
assert.deepEqual(
  unsupportedVersionStore.listComics().map((item) => item.id),
  unsupportedVersionBefore,
  'unsupported schemaVersion must leave existing library data unchanged',
)

const malformedComicsStore = createSeededStore()
const malformedComicsBefore = malformedComicsStore.listComics().map((item) => item.id)
assert.throws(
  () => hydrateLibraryStoreFromJson(malformedComicsStore, JSON.stringify({ schemaVersion: 1, comics: {} })),
  /Invalid library store persistence comics: expected array/,
  'non-array comics must reject before mutating the library store',
)
assert.deepEqual(
  malformedComicsStore.listComics().map((item) => item.id),
  malformedComicsBefore,
  'non-array comics must leave existing library data unchanged',
)

const malformedChapterStore = createSeededStore()
const malformedChapterBefore = malformedChapterStore.listComics().map((item) => item.id)
const malformedChapterPayload = JSON.stringify({
  schemaVersion: 1,
  comics: [{
    ...persistedImported,
    chapters: [{
      ...persistedImported.chapters[0],
      pages: undefined,
    }],
  }],
})
assert.throws(
  () => hydrateLibraryStoreFromJson(malformedChapterStore, malformedChapterPayload),
  /Invalid library store persistence chapter\.pages: expected array/,
  'missing page array must reject before mutating the library store',
)
assert.deepEqual(
  malformedChapterStore.listComics().map((item) => item.id),
  malformedChapterBefore,
  'missing page array must leave existing library data unchanged',
)

const malformedPageStore = createSeededStore()
const malformedPageBefore = malformedPageStore.listComics().map((item) => item.id)
const malformedPagePayload = JSON.stringify({
  schemaVersion: 1,
  comics: [{
    ...persistedImported,
    chapters: [{
      ...persistedImported.chapters[0],
      pages: [{
        ...persistedImported.chapters[0].pages[0],
        uri: undefined,
      }],
    }],
  }],
})
assert.throws(
  () => hydrateLibraryStoreFromJson(malformedPageStore, malformedPagePayload),
  /Invalid library store persistence page\.uri: expected non-empty string/,
  'invalid page fields must reject before mutating the library store',
)
assert.deepEqual(
  malformedPageStore.listComics().map((item) => item.id),
  malformedPageBefore,
  'invalid page fields must leave existing library data unchanged',
)

const emptyAdapterStore = createSeededStore()
const emptyAdapter = new MemoryLibraryStorePersistenceAdapter(undefined)
new LibraryStorePersistenceService(emptyAdapterStore, emptyAdapter).restore()
assert.equal(
  emptyAdapterStore.listComics().length,
  6,
  'startup restore with no persistence file must keep deterministic seeded shelf data',
)

const persistedImportedOnlyPayload = JSON.stringify({
  schemaVersion: 1,
  comics: [persistedImported],
})
const persistedOnlyStore = createSeededStore()
new LibraryStorePersistenceService(
  persistedOnlyStore,
  new MemoryLibraryStorePersistenceAdapter(persistedImportedOnlyPayload),
).restore()
assert.deepEqual(
  persistedOnlyStore.listComics().map((item) => item.id),
  ['imported-01'],
  'startup restore with a valid document must replace seeds with persisted document contents',
)

const saveAfterUpsertStore = createSeededStore()
const saveAfterUpsertAdapter = new MemoryLibraryStorePersistenceAdapter(undefined)
const saveAfterUpsertService = new LibraryStorePersistenceService(saveAfterUpsertStore, saveAfterUpsertAdapter)
upsertComicAndPersistLibraryStore(saveAfterUpsertStore, saveAfterUpsertService, importedComic)
assert.equal(saveAfterUpsertAdapter.savedPayloads.length, 1, 'successful import upsert must save exactly once')
assert.equal(saveAfterUpsertStore.getComic('imported-01').title, 'Imported Volume')
assert.equal(
  JSON.parse(saveAfterUpsertAdapter.savedPayloads[0]).comics.some((item) => item.id === 'imported-01'),
  true,
  'saved library payload must include the imported comic after upsert',
)

const throwingSaveStore = createSeededStore()
const throwingSaveBefore = throwingSaveStore.listComics().map((item) => item.id)
const throwingSaveAdapter = new MemoryLibraryStorePersistenceAdapter(undefined, new Error('disk full'))
const throwingSaveService = new LibraryStorePersistenceService(throwingSaveStore, throwingSaveAdapter)
assert.throws(
  () => upsertComicAndPersistLibraryStore(throwingSaveStore, throwingSaveService, importedComic),
  /disk full/,
  'save failure during import persistence must be visible to the caller',
)
assert.deepEqual(
  throwingSaveStore.listComics().map((item) => item.id),
  throwingSaveBefore,
  'save failure during import persistence must rollback the in-memory upsert',
)
assert.equal(throwingSaveStore.getComic('imported-01'), undefined, 'failed import must not remain visible in the live shelf store')

const categoryStore = createSeededStore()
categoryStore.upsertComic(importedComic)
const categoryAdapter = new MemoryLibraryStorePersistenceAdapter(undefined)
const categoryService = new LibraryStorePersistenceService(categoryStore, categoryAdapter)
assert.deepEqual(normalizeCategoryIds([' read_later ', 'favorite', 'read_later', '']), ['read_later', 'favorite'], 'category ids must be trimmed and deduplicated')
assert.equal(assignComicCategoriesAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], ['read_later']), 1, 'bulk category assignment should update existing comics')
assert.deepEqual(categoryStore.getComic('imported-01').categoryIds, ['read_later'], 'bulk assignment must update the live store immediately')
assert.equal(listLibraryItemsByCategory(categoryStore, 'read_later').some((item) => item.id === 'imported-01'), true, 'category filter must include assigned comics')
assert.equal(listLibraryItemsByCategory(categoryStore, 'uncategorized').some((item) => item.id === 'imported-01'), false, 'uncategorized filter must exclude assigned comics')
assert.deepEqual(JSON.parse(categoryAdapter.savedPayloads.at(-1)).comics.find((item) => item.id === 'imported-01').categoryIds, ['read_later'], 'category assignment must persist categoryIds')
assert.equal(assignComicCategoriesAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], undefined), 1, 'clear category assignment should update existing comics')
assert.equal(categoryStore.getComic('imported-01').categoryIds, undefined, 'clearing categories must return the comic to uncategorized')
assert.equal(listLibraryItemsByCategory(categoryStore, 'uncategorized').some((item) => item.id === 'imported-01'), true, 'uncategorized filter must include cleared comics')

const throwingCategoryStore = createSeededStore()
throwingCategoryStore.upsertComic(importedComic)
const throwingCategoryAdapter = new MemoryLibraryStorePersistenceAdapter(undefined, new Error('disk full'))
const throwingCategoryService = new LibraryStorePersistenceService(throwingCategoryStore, throwingCategoryAdapter)
assert.throws(
  () => assignComicCategoriesAndPersistLibraryStore(throwingCategoryStore, throwingCategoryService, ['imported-01'], ['favorite']),
  /disk full/,
  'save failure during category assignment must be visible to the caller',
)
assert.equal(throwingCategoryStore.getComic('imported-01').categoryIds, undefined, 'failed category assignment must rollback the live store')

assert.equal(isRemovableLocalComic(importedComic), true, 'imported local archive comics should be removable')
assert.equal(isRemovableLocalComic(seededStore.getComic('local-01')), false, 'seed/demo comics must not be removable')
assert.equal(isRemovableLocalComic({ ...importedComic, sourceKind: 'private_library' }), false, 'private library comics must not be removed by the local shelf action')
assert.equal(isRemovableLocalComic(undefined), false, 'missing comics must not be removable')

const removeStore = createSeededStore()
removeStore.upsertComic(importedComic)
const removeAdapter = new MemoryLibraryStorePersistenceAdapter(undefined)
const removeService = new LibraryStorePersistenceService(removeStore, removeAdapter)
assert.equal(removeComicAndPersistLibraryStore(removeStore, removeService, 'imported-01'), true, 'removing an imported local comic should report success')
assert.equal(removeStore.getComic('imported-01'), undefined, 'removed imported comic must leave the live shelf store')
const removeSnapshot = removeStore.listComics()
const removeSnapshotVm = createLibraryViewModelFromComics(removeSnapshot, new Map(), createPresentationMap())
assert.equal(removeSnapshot.some((item) => item.id === 'imported-01'), false, 'post-remove snapshot must omit the removed comic for live shelf binding')
assert.equal(removeSnapshotVm.comics.some((item) => item.id === 'imported-01'), false, 'view model built from the live snapshot must omit the removed comic immediately')
assert.equal(removeAdapter.savedPayloads.length, 1, 'successful remove must persist exactly once')
assert.equal(
  JSON.parse(removeAdapter.savedPayloads[0]).comics.some((item) => item.id === 'imported-01'),
  false,
  'saved library payload must omit the removed comic',
)
const removeRestoredStore = createSeededStore()
hydrateLibraryStoreFromJson(removeRestoredStore, removeAdapter.savedPayloads[0])
assert.equal(removeRestoredStore.getComic('imported-01'), undefined, 'restore after remove must keep the comic absent')

const missingRemoveStore = createSeededStore()
const missingRemoveAdapter = new MemoryLibraryStorePersistenceAdapter(undefined)
const missingRemoveService = new LibraryStorePersistenceService(missingRemoveStore, missingRemoveAdapter)
const missingRemoveBefore = missingRemoveStore.listComics().map((item) => item.id)
assert.equal(removeComicAndPersistLibraryStore(missingRemoveStore, missingRemoveService, 'not-here'), false, 'missing remove should be a no-op')
assert.deepEqual(missingRemoveStore.listComics().map((item) => item.id), missingRemoveBefore, 'missing remove must leave the shelf unchanged')
assert.equal(missingRemoveAdapter.savedPayloads.length, 0, 'missing remove must not write persistence')

const seedRemoveStore = createSeededStore()
const seedRemoveAdapter = new MemoryLibraryStorePersistenceAdapter(undefined)
const seedRemoveService = new LibraryStorePersistenceService(seedRemoveStore, seedRemoveAdapter)
const seedRemoveBefore = seedRemoveStore.listComics().map((item) => item.id)
assert.equal(removeComicAndPersistLibraryStore(seedRemoveStore, seedRemoveService, 'local-01'), false, 'seed/demo remove should be a no-op')
assert.deepEqual(seedRemoveStore.listComics().map((item) => item.id), seedRemoveBefore, 'seed/demo remove must leave fallback shelf data unchanged')
assert.equal(seedRemoveAdapter.savedPayloads.length, 0, 'seed/demo remove must not write persistence')

const throwingRemoveStore = createSeededStore()
throwingRemoveStore.upsertComic(importedComic)
const throwingRemoveBefore = throwingRemoveStore.listComics().map((item) => item.id)
const throwingRemoveAdapter = new MemoryLibraryStorePersistenceAdapter(undefined, new Error('disk full'))
const throwingRemoveService = new LibraryStorePersistenceService(throwingRemoveStore, throwingRemoveAdapter)
assert.throws(
  () => removeComicAndPersistLibraryStore(throwingRemoveStore, throwingRemoveService, 'imported-01'),
  /disk full/,
  'save failure during remove persistence must be visible to the caller',
)
assert.deepEqual(
  throwingRemoveStore.listComics().map((item) => item.id),
  throwingRemoveBefore,
  'save failure during remove persistence must rollback the in-memory deletion',
)
assert.equal(throwingRemoveStore.getComic('imported-01').title, 'Imported Volume', 'failed remove must keep the imported comic visible')

console.log('PASS Koma model contracts')
