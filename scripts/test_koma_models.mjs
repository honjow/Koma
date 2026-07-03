import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/model/ComicModels.ets')
const libraryStorePath = resolve(root, 'entry/src/main/ets/model/LibraryStore.ets')
const libraryFilterStorePath = resolve(root, 'entry/src/main/ets/model/LibraryFilterStore.ets')
const libraryCategoryManagementPagePath = resolve(root, 'entry/src/main/ets/pages/LibraryCategoryManagementPage.ets')
const progressStorePath = resolve(root, 'entry/src/main/ets/model/ReadingProgressStore.ets')
const readerSessionStorePath = resolve(root, 'entry/src/main/ets/model/ReaderSessionStore.ets')
const chapterReadStateStorePath = resolve(root, 'entry/src/main/ets/model/ChapterReadStateStore.ets')
const searchHistoryStorePath = resolve(root, 'entry/src/main/ets/model/SearchHistoryStore.ets')
const mockLibraryDataPath = resolve(root, 'entry/src/main/ets/model/MockLibraryData.ets')
const sourceModelsPath = resolve(root, 'entry/src/main/ets/model/SourceModels.ets')
const sourceTextNormalizerPath = resolve(root, 'entry/src/main/ets/model/SourceTextNormalizer.ets')
const mangaDetailModelsPath = resolve(root, 'entry/src/main/ets/model/MangaDetailModels.ets')
const libraryRepositoryPath = resolve(root, 'entry/src/main/ets/model/LibraryRepository.ets')
const libraryPersistencePath = resolve(root, 'entry/src/main/ets/model/LibraryPersistence.ets')
const libraryUpdateServicePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets')
const libraryUpdateResultStorePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdateResultStore.ets')
const libraryUpdatePreferencesStorePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdatePreferencesStore.ets')
const crossSearchServicePath = resolve(root, 'entry/src/main/ets/model/CrossSearchService.ets')
const backupServicePath = resolve(root, 'entry/src/main/ets/model/BackupService.ets')
const backupEncryptionServicePath = resolve(root, 'entry/src/main/ets/model/BackupEncryptionService.ets')
const trackerModelsPath = resolve(root, 'entry/src/main/ets/model/TrackerModels.ets')
const remoteServerStorePath = resolve(root, 'entry/src/main/ets/model/RemoteServerStore.ets')
const readerPreferencesStorePath = resolve(root, 'entry/src/main/ets/model/ReaderPreferencesStore.ets')
const offlineDownloadStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadStore.ets')
const offlineDownloadQueueStorePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadQueueStore.ets')
const offlineDownloadServicePath = resolve(root, 'entry/src/main/ets/model/OfflineDownloadService.ets')
const entryAbilityPath = resolve(root, 'entry/src/main/ets/entryability/EntryAbility.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const libraryPagePath = resolve(root, 'entry/src/main/ets/pages/LibraryPage.ets')
const browsePagePath = resolve(root, 'entry/src/main/ets/pages/BrowsePage.ets')
const historyPagePath = resolve(root, 'entry/src/main/ets/pages/HistoryPage.ets')
const searchPagePath = resolve(root, 'entry/src/main/ets/pages/SearchPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const libraryUpdateResultPagePath = resolve(root, 'entry/src/main/ets/pages/LibraryUpdateResultPage.ets')
const importPagePath = resolve(root, 'entry/src/main/ets/pages/ImportPage.ets')
const sourceBrowsePagePath = resolve(root, 'entry/src/main/ets/pages/SourceBrowsePage.ets')
const sourceSearchPagePath = resolve(root, 'entry/src/main/ets/pages/SourceSearchPage.ets')
const sourcePackageManagerPagePath = resolve(root, 'entry/src/main/ets/pages/SourcePackageManagerPage.ets')
const browseViewModelPath = resolve(root, 'entry/src/main/ets/viewmodel/BrowseViewModel.ets')
const localImportCoordinatorPath = resolve(root, 'entry/src/main/ets/import/LocalImportCoordinator.ets')
const localLibraryFolderContractPath = resolve(root, 'entry/src/main/ets/model/LocalLibraryFolderContract.ets')
const localLibraryRescanServicePath = resolve(root, 'entry/src/main/ets/model/LocalLibraryRescanService.ets')
const secondaryListScaffoldPath = resolve(root, 'entry/src/main/ets/components/SecondaryListScaffold.ets')
const comicCoverCardPath = resolve(root, 'entry/src/main/ets/components/ComicCoverCard.ets')
const chapterListSectionPath = resolve(root, 'entry/src/main/ets/components/ChapterListSection.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')
const readerPageSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const sourceSettingsStorePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets')
const sourceRuntimeAppRegistryPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeAppRegistry.ets')
const sourceIndexServicePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceIndexService.ets')
const sourcePackageTrustPolicyPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourcePackageTrustPolicy.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const libraryStoreSource = readFileSync(libraryStorePath, 'utf8')
const libraryFilterStoreSource = readFileSync(libraryFilterStorePath, 'utf8')
const progressStoreSource = readFileSync(progressStorePath, 'utf8')
const readerSessionStoreSource = readFileSync(readerSessionStorePath, 'utf8')
const chapterReadStateStoreSource = readFileSync(chapterReadStateStorePath, 'utf8')
const searchHistoryStoreSource = readFileSync(searchHistoryStorePath, 'utf8')
const mockLibraryDataSource = readFileSync(mockLibraryDataPath, 'utf8')
const sourceModelsSource = readFileSync(sourceModelsPath, 'utf8')
const sourceTextNormalizerSource = readFileSync(sourceTextNormalizerPath, 'utf8')
const mangaDetailModelsSource = readFileSync(mangaDetailModelsPath, 'utf8')
const libraryRepositorySource = readFileSync(libraryRepositoryPath, 'utf8')
const libraryPersistenceSource = readFileSync(libraryPersistencePath, 'utf8')
const libraryUpdateServiceSource = readFileSync(libraryUpdateServicePath, 'utf8')
const libraryUpdateResultStoreSource = readFileSync(libraryUpdateResultStorePath, 'utf8')
const libraryUpdatePreferencesStoreSource = readFileSync(libraryUpdatePreferencesStorePath, 'utf8')
const crossSearchServiceSource = readFileSync(crossSearchServicePath, 'utf8')
const backupServiceSource = readFileSync(backupServicePath, 'utf8')
const backupEncryptionServiceSource = readFileSync(backupEncryptionServicePath, 'utf8')
const trackerModelsSource = readFileSync(trackerModelsPath, 'utf8')
const remoteServerStoreSource = readFileSync(remoteServerStorePath, 'utf8')
const readerPreferencesStoreSource = readFileSync(readerPreferencesStorePath, 'utf8')
const offlineDownloadStoreSource = readFileSync(offlineDownloadStorePath, 'utf8')
const offlineDownloadQueueStoreSource = readFileSync(offlineDownloadQueueStorePath, 'utf8')
const offlineDownloadServiceSource = readFileSync(offlineDownloadServicePath, 'utf8')
const entryAbilitySource = readFileSync(entryAbilityPath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')
const libraryPageSource = readFileSync(libraryPagePath, 'utf8')
const libraryCategoryManagementPageSource = readFileSync(libraryCategoryManagementPagePath, 'utf8')
const browsePageSource = readFileSync(browsePagePath, 'utf8')
const historyPageSource = readFileSync(historyPagePath, 'utf8')
const searchPageSource = readFileSync(searchPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const libraryUpdateResultPageSource = readFileSync(libraryUpdateResultPagePath, 'utf8')
const importPageSource = readFileSync(importPagePath, 'utf8')
const sourceBrowsePageSource = readFileSync(sourceBrowsePagePath, 'utf8')
const sourceSearchPageSource = readFileSync(sourceSearchPagePath, 'utf8')
const sourcePackageManagerPageSource = readFileSync(sourcePackageManagerPagePath, 'utf8')
const browseViewModelSource = readFileSync(browseViewModelPath, 'utf8')
const localImportCoordinatorSource = readFileSync(localImportCoordinatorPath, 'utf8')
const localLibraryFolderContractSource = readFileSync(localLibraryFolderContractPath, 'utf8')
const localLibraryRescanServiceSource = readFileSync(localLibraryRescanServicePath, 'utf8')
const secondaryListScaffoldSource = readFileSync(secondaryListScaffoldPath, 'utf8')
const comicCoverCardSource = readFileSync(comicCoverCardPath, 'utf8')
const chapterListSectionSource = readFileSync(chapterListSectionPath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const readerPageSourceAdapterSource = readFileSync(readerPageSourceAdapterPath, 'utf8')
const sourceSettingsStoreSource = readFileSync(sourceSettingsStorePath, 'utf8')
const sourceRuntimeAppRegistrySource = readFileSync(sourceRuntimeAppRegistryPath, 'utf8')
const sourceIndexServiceSource = readFileSync(sourceIndexServicePath, 'utf8')
const sourcePackageTrustPolicySource = readFileSync(sourcePackageTrustPolicyPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

function assertUsesSecondaryListSafeArea(source, label) {
  assert.match(source, /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20/, `${label} must avoid floating tab chrome inside list content`)
}

function assertUsesScrollContentSafeArea(source, label) {
  assert.match(source, /connectLayoutSafeArea, LayoutSafeAreaState/, `${label} must import shared safe-area state`)
  assert.match(source, /@Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea\(\)/, `${label} must connect shared safe-area state`)
  assert.match(source, /topContentInset\(\): number \{[\s\S]*this\.safeArea\.topAvoidHeight/, `${label} must calculate a top inset inside scroll content`)
  assert.match(source, /bottomContentInset\(\): number \{[\s\S]*this\.safeArea\.bottomAvoidHeight[\s\S]*ThemeConstants\.FLOAT_BAR_HEIGHT/, `${label} must calculate bottom inset for floating chrome inside scroll content`)
  assert.match(source, /\.padding\(\{[^}]*top:\s*this\.topContentInset\(\)[^}]*bottom:\s*this\.bottomContentInset\(\)[^}]*\}\)/, `${label} must apply safe-area avoidance as scroll content padding`)
}

function assertSourceBrowseFloatingTabViewportClearance(source) {
  assert.match(source, /bottomContentInset\(\): number \{[\s\S]*this\.safeArea\.bottomAvoidHeight[\s\S]*ThemeConstants\.FLOAT_BAR_HEIGHT/, 'SourceBrowsePage must keep bottomContentInset for scroll-end clearance')
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

function normalizeLibraryCategoryName(name) {
  return name.trim().replace(/\s+/g, ' ')
}

function libraryCategoryNameKey(name) {
  return normalizeLibraryCategoryName(name).toLocaleLowerCase()
}

function isBuiltInLibraryCategoryName(name) {
  const key = libraryCategoryNameKey(name)
  return key === 'favorite' || key === 'read later' || key === 'read_later'
}

function isBuiltInLibraryCategoryId(categoryId) {
  return categoryId === 'favorite' || categoryId === 'read_later'
}

const CUSTOM_LIBRARY_CATEGORY_ID_PREFIX = 'custom_'
const LIBRARY_CATEGORY_NAME_MAX_LENGTH = 40

function assertValidCustomCategoryShape(row) {
  if (!row.id.startsWith(CUSTOM_LIBRARY_CATEGORY_ID_PREFIX) || isBuiltInLibraryCategoryId(row.id)) {
    throw new Error('Invalid library store persistence category.id: expected custom category id')
  }
  const normalizedName = normalizeLibraryCategoryName(row.name)
  if (normalizedName.length === 0) {
    throw new Error('Invalid library store persistence category.name: expected non-empty name')
  }
  if (normalizedName.length > LIBRARY_CATEGORY_NAME_MAX_LENGTH) {
    throw new Error(`Invalid library store persistence category.name: expected at most ${LIBRARY_CATEGORY_NAME_MAX_LENGTH} characters`)
  }
  if (isBuiltInLibraryCategoryName(normalizedName)) {
    throw new Error('Invalid library store persistence category.name: conflicts with built-in category')
  }
}

function assertUniquePersistedLibraryCategories(rows) {
  const ids = []
  const names = []
  for (const row of rows) {
    if (ids.includes(row.id)) {
      throw new Error('Invalid library store persistence customCategories: duplicate category id')
    }
    ids.push(row.id)
    const key = libraryCategoryNameKey(row.name)
    if (names.includes(key)) {
      throw new Error('Invalid library store persistence customCategories: duplicate category name')
    }
    names.push(key)
  }
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

function withComicAddedCategoryId(comic, categoryId) {
  const categoryIds = normalizeCategoryIds(comic.categoryIds)
  const normalizedCategoryId = categoryId.trim()
  if (normalizedCategoryId.length === 0 || categoryIds.includes(normalizedCategoryId)) {
    return withComicCategoryIds(comic, categoryIds)
  }
  return withComicCategoryIds(comic, [...categoryIds, normalizedCategoryId])
}

function withComicRemovedCategoryId(comic, categoryId) {
  const normalizedCategoryId = categoryId.trim()
  return withComicCategoryIds(comic, normalizeCategoryIds(comic.categoryIds).filter((item) => item !== normalizedCategoryId))
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
assertExport(modelSource, 'withComicAddedCategoryId')
assertExport(modelSource, 'withComicRemovedCategoryId')
assertExport(modelSource, 'CustomLibraryCategory')
assertExport(modelSource, 'LIBRARY_CATEGORY_NAME_MAX_LENGTH')
assertExport(libraryStoreSource, 'LibraryStore')
assertExport(libraryStoreSource, 'InMemoryLibraryStore')
assertExport(progressStoreSource, 'ReadingProgressStore')
assertExport(progressStoreSource, 'InMemoryReadingProgressStore')
assertExport(readerSessionStoreSource, 'ReaderSessionStore')
assertExport(readerSessionStoreSource, 'getReaderSessionPageWidth')
assertExport(readerSessionStoreSource, 'getReaderSessionPageHeight')
assert.match(
  readerSessionStoreSource,
  /removeProgress\(comicId: ComicId\): void[\s\S]*this\.progressStore\.remove\(comicId\)[\s\S]*this\.persist\(\)/,
  'ReaderSessionStore must expose persisted progress removal for mark-unread flows',
)
assertExport(chapterReadStateStoreSource, 'ChapterReadStateStore')
assertExport(chapterReadStateStoreSource, 'ChapterReadStateOverride')
assertExport(chapterReadStateStoreSource, 'AppFilesChapterReadStatePersistenceAdapter')
assertExport(chapterReadStateStoreSource, 'isChapterReadFromState')
assertExport(chapterReadStateStoreSource, 'CHAPTER_READ_STATE_SCHEMA_VERSION')
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
assertExport(libraryPersistenceSource, 'updateComicCategoryMembershipAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'createCustomCategoryAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'renameCustomCategoryAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'deleteCustomCategoryAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'upsertLocalLibraryFolderScanAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'upsertLocalLibraryFolderRescanAndPersistLibraryStore')
assertExport(libraryPersistenceSource, 'isRemovableLocalComic')
assertExport(libraryPersistenceSource, 'removeComicAndPersistLibraryStore')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateResultStatus')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateProviderKind')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateComicResult')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateProviderSummary')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateSummary')
assertExport(libraryUpdateServiceSource, 'LibraryUpdateService')
assertExport(libraryUpdateServiceSource, 'countLibraryUpdateNewChapters')
assertExport(libraryUpdateServiceSource, 'summarizeLibraryUpdateProviders')
assertExport(libraryUpdateServiceSource, 'formatLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_RESULT_STORE_NAME')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_LATEST_JOB_JSON_KEY')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_RESULT_MAX_RESULTS')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_RESULT_MAX_PROVIDER_SUMMARIES')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_RESULT_MAX_COMIC_ID_LENGTH')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH')
assertExport(libraryUpdateResultStoreSource, 'LIBRARY_UPDATE_RESULT_MAX_SOURCE_KEY_LENGTH')
assertExport(libraryUpdateResultStoreSource, 'LibraryUpdateJobState')
assertExport(libraryUpdateResultStoreSource, 'PersistedLibraryUpdateResult')
assertExport(libraryUpdateResultStoreSource, 'PersistedLibraryUpdateProviderSummary')
assertExport(libraryUpdateResultStoreSource, 'PersistedLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'LibraryUpdateJobSnapshot')
assertExport(libraryUpdateResultStoreSource, 'PersistedLibraryUpdateJobSnapshot')
assertExport(libraryUpdateResultStoreSource, 'LibraryUpdateNotificationSummary')
assertExport(libraryUpdateResultStoreSource, 'redactLibraryUpdateFailureCode')
assertExport(libraryUpdateResultStoreSource, 'serializeLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'createLibraryUpdateNotificationSummary')
assertExport(libraryUpdateResultStoreSource, 'formatLibraryUpdateNotificationSummary')
assertExport(libraryUpdateResultStoreSource, 'hydrateLibraryUpdateSummaryFromJson')
assertExport(libraryUpdateResultStoreSource, 'cloneLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'createLibraryUpdateJobSnapshot')
assertExport(libraryUpdateResultStoreSource, 'serializeLibraryUpdateJobSnapshot')
assertExport(libraryUpdateResultStoreSource, 'hydrateLibraryUpdateJobSnapshotFromJson')
assertExport(libraryUpdateResultStoreSource, 'setLatestLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'clearLatestLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'getLatestLibraryUpdateSummary')
assertExport(libraryUpdateResultStoreSource, 'setLatestLibraryUpdateJobSnapshot')
assertExport(libraryUpdateResultStoreSource, 'getLatestLibraryUpdateJobSnapshot')
assertExport(libraryUpdateResultStoreSource, 'LibraryUpdateResultStore')
assertExport(libraryUpdatePreferencesStoreSource, 'LibraryUpdatePreferences')
assertExport(libraryUpdatePreferencesStoreSource, 'LibraryUpdateNotificationStatus')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_PREFERENCES_STORE_NAME')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_AUTO_CHECK_ENABLED_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_INTERVAL_HOURS_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_FOREGROUND_ONLY_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_CHECKED_AT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_TEXT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_TOTAL_COUNT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_NEW_CHAPTER_COUNT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_UPDATED_COUNT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_SKIPPED_COUNT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_SUMMARY_FAILED_COUNT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_FAILURE_COUNT_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_LAST_FAILURE_CODE_KEY')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_INTERVAL_OPTIONS')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_NOTIFICATION_STATUS')
assertExport(libraryUpdatePreferencesStoreSource, 'LIBRARY_UPDATE_MAX_BACKOFF_HOURS')
assertExport(libraryUpdatePreferencesStoreSource, 'DEFAULT_LIBRARY_UPDATE_PREFERENCES')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateAutoCheckEnabled')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateIntervalHours')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateForegroundOnly')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateTimestamp')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateSummaryText')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateSummaryCount')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateFailureCount')
assertExport(libraryUpdatePreferencesStoreSource, 'normalizeLibraryUpdateFailureCode')
assertExport(libraryUpdatePreferencesStoreSource, 'formatLibraryUpdateStoredSummary')
assertExport(libraryUpdatePreferencesStoreSource, 'formatLibraryUpdateTimestamp')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateAutoCheckLabel')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateBackoffHours')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateNextDueAt')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateNextDueLabel')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateLastResultLabel')
assertExport(libraryUpdatePreferencesStoreSource, 'getLibraryUpdateNotificationStatusLabel')
assertExport(libraryUpdatePreferencesStoreSource, 'isLibraryUpdateNotificationDeliveryEnabled')
assertExport(libraryUpdatePreferencesStoreSource, 'isLibraryUpdateDue')
assertExport(libraryUpdatePreferencesStoreSource, 'LibraryUpdatePreferencesStore')

assert.match(entryAbilitySource, /const TRANSPARENT_COLOR: string = '#00FFFFFF'/, 'EntryAbility must keep transparent system bar color')
assert.match(entryAbilitySource, /setWindowLayoutFullScreen\(true\)/, 'EntryAbility must keep fullscreen window layout')
assert.match(entryAbilitySource, /statusBarColor:\s*TRANSPARENT_COLOR/, 'EntryAbility status bar must remain transparent')
assert.match(entryAbilitySource, /navigationBarColor:\s*TRANSPARENT_COLOR/, 'EntryAbility navigation bar must remain transparent')
assert.match(indexSource, /\.ignoreLayoutSafeArea\(\s*\[\s*LayoutSafeAreaType\.SYSTEM\s*\][\s\S]*\[LayoutSafeAreaEdge\.TOP,\s*LayoutSafeAreaEdge\.BOTTOM\]/, 'root shell must continue drawing under system safe areas')
assert.match(indexSource, /\.expandSafeArea\(\[SafeAreaType\.SYSTEM\], \[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/, 'root shell must preserve immersive safe-area expansion')
assert.doesNotMatch(indexSource, /HdsNavigation\(this\.appPathStack\)[\s\S]*\.(padding|margin)\(/, 'root app shell must not use root padding or margin to avoid safe areas')
assert.match(secondaryListScaffoldSource, /Blank\(\)\.height\(this\.safeArea\.topAvoidHeight \+ ThemeConstants\.TITLE_BAR_HEIGHT\)/, 'shared list scaffold must include an internal top spacer')
assert.match(secondaryListScaffoldSource, /Blank\(\)\.height\(this\.safeArea\.bottomAvoidHeight \+ this\.bottomPadding \+ this\.keyboardPadding\(\)\)/, 'shared list scaffold must include an internal bottom spacer')
for (const [source, label] of [
  [libraryPageSource, 'LibraryPage'],
  [browsePageSource, 'BrowsePage'],
  [historyPageSource, 'HistoryPage'],
  [searchPageSource, 'SearchPage'],
  [settingsPageSource, 'SettingsPage'],
  [libraryUpdateResultPageSource, 'LibraryUpdateResultPage'],
  [libraryCategoryManagementPageSource, 'LibraryCategoryManagementPage'],
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
  sourceBrowsePageSource,
  /listingForHomeSection\(section: SourceHomeSectionState\): SourceListingDescriptor \| undefined[\s\S]*section\.listingId[\s\S]*this\.viewModel\.listings\.find[\s\S]*openHomeSectionListing\(section: SourceHomeSectionState\)[\s\S]*this\.viewModel\.selectBrowseListing\(listing\)[\s\S]*HomeSection\(section: SourceHomeSectionState\)[\s\S]*s\('browse_section_open_listing'\)[\s\S]*this\.openHomeSectionListing\(section\)/,
  'SourceBrowsePage home sections with listingId must expose an action that opens the mapped runtime listing',
)

assert.match(
  searchHistoryStoreSource,
  /export function removeSearchHistoryEntry\(entries: SearchHistoryEntry\[\], query: string\): SearchHistoryEntry\[\][\s\S]*normalizeSearchQuery\(query\)[\s\S]*entry\.query\.toLocaleLowerCase\(\) !== normalizedQuery\.toLocaleLowerCase\(\)/,
  'SearchHistoryStore must support case-insensitive removal of a single history query',
)
assert.match(
  searchHistoryStoreSource,
  /async remove\(query: string\): Promise<SearchHistoryEntry\[\]>[\s\S]*removeSearchHistoryEntry\(await this\.load\(\), query\)[\s\S]*await this\.save\(entries\)/,
  'SearchHistoryStore.remove must persist the single-entry deletion',
)
assert.match(
  searchPageSource,
  /import \{ KomaIconButton \} from '..\/components\/ui\/KomaIconButton'[\s\S]*removeHistoryEntry\(query: string\): void[\s\S]*store\.remove\(query\)[\s\S]*this\.loadHistory\(\)/,
  'SearchPage must expose single history entry deletion and reload on failure',
)
assert.match(
  searchPageSource,
  /KomaIconButton\(\{[\s\S]*icon: \$r\('sys\.symbol\.trash'\)[\s\S]*this\.removeHistoryEntry\(entry\.query\)/,
  'SearchPage history rows must use a trash icon button for single-entry deletion',
)
assert.match(
  crossSearchServiceSource,
  /private sortSearchResultItems\(query: string, items: CrossSearchResultItem\[\]\): CrossSearchResultItem\[\][\s\S]*this\.searchResultScore\(left, normalizedQuery\) - this\.searchResultScore\(right, normalizedQuery\)[\s\S]*left\.title\.localeCompare\(right\.title\)/,
  'CrossSearchService must apply stable result scoring instead of raw provider order',
)
assert.match(
  crossSearchServiceSource,
  /private searchResultScore\(item: CrossSearchResultItem, normalizedQuery: string\): number[\s\S]*title === normalizedQuery[\s\S]*title\.startsWith\(normalizedQuery\)[\s\S]*title\.indexOf\(normalizedQuery\)[\s\S]*subtitle\.startsWith\(normalizedQuery\)[\s\S]*subtitle\.indexOf\(normalizedQuery\)/,
  'CrossSearchService scoring must prioritize exact title, title prefix, title contains, then subtitle matches',
)
assert.match(
  crossSearchServiceSource,
  /searchLocal\(query: string\)[\s\S]*this\.sortSearchResultItems\(query, libraryStore\.listComics\(\)[\s\S]*searchKomga\(query: string\)[\s\S]*this\.sortSearchResultItems\(query, response\.content\.map[\s\S]*searchWebDav\(query: string\)[\s\S]*const matchedItems[\s\S]*this\.sortSearchResultItems\(query, matchedItems\)[\s\S]*searchWasmSource[\s\S]*this\.sortSearchResultItems\(query, result\.manga\.map[\s\S]*filterOpdsPublications[\s\S]*return this\.sortSearchResultItems\(query, items\)/,
  'CrossSearchService must use shared scoring for local, Komga, WebDAV, WASM, and OPDS results',
)

assert.match(
  readerSessionStoreSource,
  /export interface ReaderSessionConfig[\s\S]*pageUris: string\[\][\s\S]*pageIds: string\[\][\s\S]*pageWidths: Array<number \| undefined>[\s\S]*pageHeights: Array<number \| undefined>/,
  'ReaderSessionConfig must carry optional page dimensions alongside URIs and ids',
)
assert.match(
  readerSessionStoreSource,
  /pageWidths: pages\.map\(\(page: Page\) => page\.width\)[\s\S]*pageHeights: pages\.map\(\(page: Page\) => page\.height\)/,
  'createReaderSessionConfigFromComic must preserve page width/height metadata for reader runtime decisions',
)
assert.match(
  readerSessionStoreSource,
  /export function getReaderSessionPageWidth\(config: ReaderSessionConfig, pageIndex: number\): number \| undefined[\s\S]*resolvedPageIndex >= config\.pageWidths\.length[\s\S]*return undefined[\s\S]*return config\.pageWidths\[resolvedPageIndex\]/,
  'ReaderSessionStore must expose fail-open page width lookup for missing metadata',
)
assert.match(
  readerSessionStoreSource,
  /export function getReaderSessionPageHeight\(config: ReaderSessionConfig, pageIndex: number\): number \| undefined[\s\S]*resolvedPageIndex >= config\.pageHeights\.length[\s\S]*return undefined[\s\S]*return config\.pageHeights\[resolvedPageIndex\]/,
  'ReaderSessionStore must expose fail-open page height lookup for missing metadata',
)

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
  /export interface OfflineChapterDownloadManifest\s*{[\s\S]*sourceKind\?: ComicSourceKind[\s\S]*sourceId\?: string[\s\S]*seriesId:[\s\S]*chapterId:[\s\S]*pageCount:\s*number[\s\S]*downloadedPageCount:\s*number[\s\S]*integrityHash:\s*string/s,
  'offline manifest must track source/series/chapter identity, counts, and integrity',
)
assert.match(
  offlineDownloadStoreSource,
  /export enum OfflineDownloadedChapterStatus\s*{[\s\S]*DOWNLOADED = 'downloaded'[\s\S]*PARTIAL = 'partial'[\s\S]*CORRUPT = 'corrupt'[\s\S]*MISSING = 'missing'/,
  'offline manifest validation must classify downloaded, partial, corrupt, and missing chapters',
)
assert.match(
  offlineDownloadStoreSource,
  /resolveDownloadedPage[\s\S]*validateDownloadedChapter\(comicId, chapterId\)[\s\S]*OfflineDownloadedChapterStatus\.DOWNLOADED[\s\S]*OfflineDownloadedChapterStatus\.PARTIAL[\s\S]*fs\.accessSync\(page\.localPath\)/,
  'offline resolver must expose validated existing files for downloaded and partial chapters',
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
  /downloadButtonLabel\(\)[\s\S]*s\('manga_detail_download_in_progress'\)[\s\S]*s\('manga_detail_action_redownload'\)[\s\S]*s\('manga_detail_action_download_chapter'\)/,
  'MangaDetailPage must label completed downloads as a redownload action',
)
assert.match(
  mangaDetailPageSource,
  /KomaActionButton\(\{[\s\S]*label: this\.downloadButtonLabel\(\)[\s\S]*this\.handleDownloadChapter\(\)/,
  'MangaDetailPage must expose a user-visible chapter download action',
)
assert.match(
  mangaDetailPageSource,
  /formatString\('manga_detail_download_status_downloaded', \[summary\.downloadedPageCount, summary\.pageCount\]\)/,
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
  libraryFilterStoreSource,
  /export type LibraryAvailabilityFilter = 'all' \| 'downloaded' \| 'not_downloaded'[\s\S]*availability: LibraryAvailabilityFilter[\s\S]*LIBRARY_FILTER_AVAILABILITY_KEY[\s\S]*value === 'downloaded' \|\| value === 'not_downloaded'[\s\S]*normalizeAvailability\(availability\)[\s\S]*store\.put\(LIBRARY_FILTER_AVAILABILITY_KEY, preferencesValue\.availability\)/,
  'Library filter preferences must persist downloaded and not-downloaded availability filters',
)
assert.match(
  libraryFilterStoreSource,
  /export type LibrarySourceFilter = 'all' \| 'local' \| 'private' \| 'komga' \| 'opds' \| 'webdav' \| 'source_package'[\s\S]*if \(value === 'wasm'\) \{[\s\S]*return 'source_package'[\s\S]*value === 'private'[\s\S]*value === 'source_package'/,
  'Library source filter preferences must expose private libraries/source packages and migrate the legacy wasm value',
)
assert.match(
  libraryPageSource,
  /filterAvailability: LibraryAvailabilityFilter = 'all'[\s\S]*filterAvailabilityComics\(this\.filterPreciseSourceComics\(nextComics\)\)[\s\S]*private filterAvailabilityComics\(comics: Comic\[\]\): Comic\[\][\s\S]*this\.filterAvailability === 'downloaded'[\s\S]*!downloadedComicIds\.has\(comic\.id\)[\s\S]*new OfflineDownloadQueueStore\(context\.filesDir\)\.reconcileWithManifests\(\)[\s\S]*OfflineDownloadStatus\.DOWNLOADED \|\| entry\.status === OfflineDownloadStatus\.PARTIAL/,
  'LibraryPage availability filter must derive downloaded and not-downloaded comics from reconciled download queue manifests',
)
assert.match(
  libraryPageSource,
  /filterAvailabilityComics\(this\.filterPreciseSourceComics\(nextComics\)\)[\s\S]*private filterPreciseSourceComics\(comics: Comic\[\]\): Comic\[\][\s\S]*this\.filterSource === 'source_package'[\s\S]*this\.filterSource === 'private'[\s\S]*private isSourcePackageComic\(comic: Comic\): boolean[\s\S]*comic\.sourceKind === ComicSourceKind\.PRIVATE_LIBRARY[\s\S]*comic\.sourceRuntimeId\.trim\(\)\.length > 0[\s\S]*private isPrivateLibraryComic\(comic: Comic\): boolean[\s\S]*this\.isSourcePackageComic\(comic\)[\s\S]*ComicSourceKind\.KOMGA_REMOTE[\s\S]*ComicSourceKind\.OPDS_REMOTE[\s\S]*ComicSourceKind\.WEBDAV_REMOTE/,
  'LibraryPage source filters must split private-library and source-package comics instead of grouping all PRIVATE_LIBRARY rows together',
)
assert.match(
  libraryPageSource,
  /private SourceMenu\(\)[\s\S]*setSourceFilter\('local'\)[\s\S]*library_source_private[\s\S]*setSourceFilter\('private'\)[\s\S]*route_komga_title[\s\S]*route_opds_title[\s\S]*route_webdav_title[\s\S]*library_source_package[\s\S]*setSourceFilter\('source_package'\)/,
  'LibraryPage must expose source filter menu entries for local, private libraries, individual servers, and source packages',
)
assert.match(
  libraryPageSource,
  /private AvailabilityMenu\(\)[\s\S]*setAvailabilityFilter\('all'\)[\s\S]*library_availability_downloaded[\s\S]*setAvailabilityFilter\('downloaded'\)[\s\S]*library_availability_not_downloaded[\s\S]*setAvailabilityFilter\('not_downloaded'\)[\s\S]*this\.availabilityLabel\(\)[\s\S]*this\.filterAvailability !== 'all'/,
  'LibraryPage must expose user-visible downloaded and not-downloaded availability filter chips',
)
assert.match(
  libraryPageSource,
  /private validCategoryFilter\(\): LibraryCategoryFilter \{[\s\S]*this\.filterCategory === LIBRARY_CATEGORY_FAVORITE_ID[\s\S]*listCustomCategories\(\)\.some[\s\S]*this\.filterCategory = 'all'[\s\S]*saveFilterPreferences\(\)/,
  'LibraryPage must reset stale deleted custom category filters before applying list options',
)
assert.match(
  libraryPageSource,
  /private categoryLabel\(\): string \{[\s\S]*s\('library_category_all'\)[\s\S]*CategoryMenu[\s\S]*MenuItem\(\{ content: s\('library_category_uncategorized'\) \}\)[\s\S]*MenuItem\(\{ content: s\('library_category_read_later'\) \}\)[\s\S]*MenuItem\(\{ content: s\('library_category_favorite'\) \}\)/,
  'LibraryPage must expose user-visible category filter labels',
)
assert.match(
  libraryPageSource,
  /this\.libraryStore\.listCustomCategories\(\)[\s\S]*this\.setCategoryFilter\(category\.id\)/,
  'LibraryPage category filter menu must include custom categories',
)
assert.match(
  libraryPageSource,
  /MenuItem\(\{ content: s\('library_batch_add_favorite'\) \}\)[\s\S]*addSelectedCategory\(LIBRARY_CATEGORY_FAVORITE_ID\)[\s\S]*MenuItem\(\{ content: s\('library_batch_remove_favorite'\) \}\)[\s\S]*removeSelectedCategory\(LIBRARY_CATEGORY_FAVORITE_ID\)[\s\S]*MenuItem\(\{ content: s\('library_batch_add_read_later'\) \}\)[\s\S]*addSelectedCategory\(LIBRARY_CATEGORY_READ_LATER_ID\)[\s\S]*MenuItem\(\{ content: s\('library_batch_remove_read_later'\) \}\)[\s\S]*removeSelectedCategory\(LIBRARY_CATEGORY_READ_LATER_ID\)[\s\S]*MenuItem\(\{ content: s\('library_batch_clear_categories'\) \}\)[\s\S]*assignSelectedCategory\(undefined\)/,
  'LibraryPage selection mode must expose bulk category add, remove, and clearing actions',
)
assert.match(
  libraryPageSource,
  /private canRemoveComic\(comicId: ComicId\): boolean[\s\S]*isRemovableLocalComic[\s\S]*private canSelectComic\(comicId: ComicId\): boolean[\s\S]*getComic\(comicId\) !== undefined[\s\S]*selectedRemovableCount\(\)[\s\S]*isEnabled: this\.selectedRemovableCount\(\) > 0/,
  'LibraryPage selection must support non-removable comics while keeping destructive remove local-only',
)
assert.match(
  libraryPageSource,
  /private chapterReadStateStore\(\): ChapterReadStateStore \| undefined[\s\S]*new ChapterReadStateStore[\s\S]*private markSelectedReadState\(isRead: boolean\): void[\s\S]*this\.chapterReadStateStore\(\)[\s\S]*readStateStore\.mark\(comic\.id, chapter\.id, isRead\)[\s\S]*sessionStore\.saveProgress\(this\.completedProgressForComic\(comic\)\)[\s\S]*sessionStore\.removeProgress\(comic\.id\)[\s\S]*private BatchReadStateMenu\(\)[\s\S]*library_batch_mark_read[\s\S]*library_batch_mark_unread/,
  'LibraryPage must batch mark selected comics read/unread through chapter overrides and comic-level progress',
)
assert.match(
  libraryPageSource,
  /ForEach\(this\.libraryStore\.listCustomCategories\(\)[\s\S]*this\.addSelectedCategory\(category\.id\)[\s\S]*this\.removeSelectedCategory\(category\.id\)/,
  'LibraryPage batch category menu must support custom category add and remove',
)
assert.match(
  libraryStoreSource,
  /createCustomCategory\(name: string[\s\S]*renameCustomCategory\(categoryId: string[\s\S]*deleteCustomCategory\(categoryId: string[\s\S]*isBuiltInLibraryCategoryName/,
  'LibraryStore must manage durable custom categories and reject built-in name collisions',
)
assert.match(
  libraryPersistenceSource,
  /customCategories\?: PersistedLibraryCategory\[\][\s\S]*categoryDisplayStrategies\?: PersistedCategoryDisplayStrategy\[\][\s\S]*createCustomCategoryAndPersistLibraryStore[\s\S]*renameCustomCategoryAndPersistLibraryStore[\s\S]*deleteCustomCategoryAndPersistLibraryStore[\s\S]*setCategoryDisplayStrategyAndPersistLibraryStore/,
  'Library persistence must include custom categories, display strategies, and persistence helpers',
)
assert.match(
  libraryPersistenceSource,
  /upsertLocalLibraryFolderScanAndPersistLibraryStore[\s\S]*buildComicsFromLocalLibraryFolderScan\(scanResult, rootUri, now\)[\s\S]*const previousPayload = serializeLibraryStore\(libraryStore\)[\s\S]*libraryStore\.upsertComic\(comic\)[\s\S]*persistenceService\.persist\(\)[\s\S]*hydrateLibraryStoreFromJson\(libraryStore, previousPayload\)/,
  'local library folder scan persistence must convert scan results, upsert comics, persist once, and rollback on save failure',
)
assert.match(
  libraryPersistenceSource,
  /upsertLocalLibraryFolderRescanAndPersistLibraryStore[\s\S]*createLocalLibraryRescanSummary\(previousKnownSeries, freshScan, failures\)[\s\S]*outcome\.status === 'added' \|\| outcome\.status === 'changed'[\s\S]*buildComicsFromLocalLibraryFolderScan\(freshScan, rootUri, now\)[\s\S]*changedSeriesIds\.has\(comic\.id\)[\s\S]*libraryStore\.upsertComic\(comic\)[\s\S]*persistenceService\.persist\(\)[\s\S]*hydrateLibraryStoreFromJson\(libraryStore, previousPayload\)/,
  'local library folder rescan persistence must upsert only added/changed scan results, return a summary, and rollback on save failure',
)
assert.doesNotMatch(
  libraryPersistenceSource,
  /upsertLocalLibraryFolderScanAndPersistLibraryStore[\s\S]*?(removeComic|deleteLocal|deleteComic)[\s\S]*?export function assignComicCategoriesAndPersistLibraryStore/i,
  'local library folder scan persistence must not implicitly delete existing shelf rows',
)
assert.doesNotMatch(
  libraryPersistenceSource,
  /upsertLocalLibraryFolderRescanAndPersistLibraryStore[\s\S]*?(removeComic|deleteLocal|deleteComic|unlink|rmdir)[\s\S]*?export function assignComicCategoriesAndPersistLibraryStore/i,
  'local library folder rescan persistence must report missing rows without deleting shelf rows or user files',
)
assert.match(
  libraryCategoryManagementPageSource,
  /createCustomCategoryAndPersistLibraryStore[\s\S]*deleteCustomCategoryAndPersistLibraryStore[\s\S]*renameCustomCategoryAndPersistLibraryStore[\s\S]*setCategoryDisplayStrategyAndPersistLibraryStore[\s\S]*export struct LibraryCategoryManagementPage[\s\S]*KomaFormTextField/,
  'LibraryCategoryManagementPage must expose list/create/rename/delete category management and display strategy controls',
)
assert.match(
  libraryCategoryManagementPageSource,
  /DisplayStrategySection\(\)[\s\S]*this\.StrategySummaryRow\('all', s\('library_category_all'\)\)[\s\S]*this\.StrategySummaryRow\('uncategorized', s\('library_category_uncategorized'\)\)[\s\S]*this\.StrategySummaryRow\(LIBRARY_CATEGORY_FAVORITE_ID, s\('library_category_favorite'\)\)[\s\S]*this\.StrategySummaryRow\(LIBRARY_CATEGORY_READ_LATER_ID, s\('library_category_read_later'\)\)[\s\S]*ForEach\(this\.categories/,
  'LibraryCategoryManagementPage must expose display strategies for default, built-in, and custom categories',
)
assert.match(
  libraryPageSource,
  /private setCategoryFilter\(category: LibraryCategoryFilter\): void \{[\s\S]*this\.applyCategoryDisplayStrategy\(category\)[\s\S]*private applyCategoryDisplayStrategy\(category: LibraryCategoryFilter\): void \{[\s\S]*this\.libraryStore\.getCategoryDisplayStrategy\(category\)[\s\S]*this\.sortBy = strategy\.sortBy[\s\S]*this\.filterReadState = strategy\.readState/,
  'LibraryPage must apply a persisted category display strategy when a category filter is selected',
)
assert.match(
  libraryCategoryManagementPageSource,
  /s\('library_category_delete_message'\)\.replace\('%s', category\.name\)/,
  'custom category delete copy must clearly state membership cleanup and built-in safety',
)
assert.match(
  indexSource,
  /onAssignCategoriesRequested:\s*\(comicIds: ComicId\[\], categoryIds\?: string\[\]\) => \{[\s\S]*return this\.handleAssignCategoriesRequested\(comicIds, categoryIds\)/,
  'Index must wire LibraryPage category assignment into the persistent library store',
)
assert.match(
  indexSource,
  /onUpdateCategoryMembershipRequested:\s*\(comicIds: ComicId\[\], categoryId: string, selected: boolean\)[\s\S]*return this\.handleUpdateCategoryMembershipRequested\(comicIds, categoryId, selected\)/,
  'Index must wire LibraryPage category add/remove actions into the persistent library store',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-update', titleKey: 'settings_row_library_update_title', detailKey: 'settings_row_library_update_detail' \}/,
  'SettingsPage must expose a foreground library update entry under Data',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-update-results', titleKey: 'settings_row_library_update_results_title', detailKey: 'settings_row_library_update_results_detail' \}/,
  'SettingsPage must expose a row for the latest library update result details',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-categories', titleKey: 'settings_row_library_categories_title', detailKey: 'settings_row_library_categories_detail' \}[\s\S]*onOpenLibraryCategories:\s*\(\) => void = \(\) => \{\}[\s\S]*row\.key === 'library-categories'[\s\S]*this\.onOpenLibraryCategories\(\)/,
  'SettingsPage must expose a Settings entry for custom category management',
)
assert.match(
  settingsPageSource,
  /\{ key: 'library-auto-update', titleKey: 'settings_row_library_auto_update_title', detailKey: 'settings_row_library_auto_update_detail' \}[\s\S]*\{ key: 'library-update-interval', titleKey: 'settings_row_library_update_interval_title', detailKey: 'settings_row_library_update_interval_detail' \}[\s\S]*\{ key: 'library-update-notifications', titleKey: 'settings_row_library_update_notifications_title', detailKey: 'settings_row_library_update_notifications_detail' \}[\s\S]*\{ key: 'library-update', titleKey: 'settings_row_library_update_title', detailKey: 'settings_row_library_update_detail' \}/,
  'SettingsPage must expose auto-check preferences next to the foreground library update entry',
)
assert.match(
  settingsPageSource,
  /library-update-notifications[\s\S]*getLibraryUpdateNotificationStatusLabel\(this\.libraryUpdateNotificationStatus\)[\s\S]*requestLibraryUpdateNotificationPermission\(this\.context\(\)\)/,
  'SettingsPage must expose a real update notification permission entry',
)
assert.match(
  settingsPageSource,
  /private isSwitchRow\(row: SettingsRow\): boolean \{[\s\S]*row\.key === 'library-auto-update'[\s\S]*private switchRowValue\(row: SettingsRow\): boolean \{[\s\S]*this\.libraryUpdatePreferences\.autoCheckEnabled[\s\S]*private setSwitchRowValue\(row: SettingsRow, value: boolean\): void \{[\s\S]*this\.setLibraryAutoUpdateEnabled\(value\)[\s\S]*ConciseListRow\(\{[\s\S]*hasSwitch: true[\s\S]*checked: this\.switchRowValue\(row\)[\s\S]*this\.setSwitchRowValue\(row, isOn\)/,
  'SettingsPage must use a switch row for library auto-check preference',
)
assert.match(
  settingsPageSource,
  /row\.key === 'library-update-interval'[\s\S]*SelectionMenuItem\(s\('library_update_interval_12h'\)[\s\S]*SelectionMenuItem\(s\('library_update_interval_24h'\)[\s\S]*SelectionMenuItem\(s\('library_update_interval_48h'\)/,
  'SettingsPage interval selector copy must describe app-open foreground checks',
)
assert.match(
  settingsPageSource,
  /loadLibraryUpdatePreferences\(\)[\s\S]*this\.runDueLibraryUpdateCheck\(\)/,
  'SettingsPage must evaluate due library checks when update preferences load',
)
assert.match(
  settingsPageSource,
  /isLibraryUpdateDue\(this\.libraryUpdatePreferences, Date\.now\(\)\)[\s\S]*createLibraryUpdateJobSnapshot\('due'[\s\S]*saveJobSnapshot\(dueSnapshot\)[\s\S]*this\.checkLibraryUpdates\('due'\)/,
  'SettingsPage must durably record a due state before starting due checks',
)
assert.match(
  settingsPageSource,
  /new LibraryUpdateService\([\s\S]*this\.libraryStore[\s\S]*this\.sourceRegistry[\s\S]*this\.libraryPersistenceService[\s\S]*\)\s*[\s\S]*\.checkLibraryUpdates\(\)/,
  'SettingsPage must trigger LibraryUpdateService from the foreground entry',
)
assert.match(
  settingsPageSource,
  /saveLastSummary\([\s\S]*summary\.checkedAt[\s\S]*summary\.totalCount[\s\S]*countLibraryUpdateNewChapters\(summary\)[\s\S]*summary\.updatedCount[\s\S]*summary\.skippedCount[\s\S]*summary\.failedCount[\s\S]*\)/,
  'SettingsPage must persist the latest manual or due update summary as locale-neutral counts',
)
assert.match(
  settingsPageSource,
  /setLatestLibraryUpdateSummary\(summary\)/,
  'SettingsPage must store the latest successful update summary for the result page',
)
assert.match(
  settingsPageSource,
  /private libraryUpdateResultStore\(\): LibraryUpdateResultStore \{[\s\S]*new LibraryUpdateResultStore\(this\.context\(\)\)/,
  'SettingsPage must construct a persisted library update result store from the UIAbility context',
)
assert.match(
  settingsPageSource,
  /loadLatestLibraryUpdateSummary\(\): void \{[\s\S]*getLatestLibraryUpdateSummary\(\)[\s\S]*this\.isLibraryUpdateSummaryStaleAfterFailure\(latest\)[\s\S]*this\.libraryUpdateResultStore\(\)\.load\(\)[\s\S]*const current = getLatestLibraryUpdateSummary\(\)[\s\S]*setLatestLibraryUpdateSummary\(summary\)[\s\S]*this\.isLibraryUpdateSummaryStaleAfterFailure\(effectiveSummary\)[\s\S]*step=load_library_update_results hasSummary=/,
  'SettingsPage must load persisted library update result details after checking fresh in-memory state and suppress stale success after newer failures',
)
assert.match(
  settingsPageSource,
  /\.then\(\(summary: LibraryUpdateSummary \| undefined\) => \{[\s\S]*const current = getLatestLibraryUpdateSummary\(\)[\s\S]*if \(summary !== undefined && \(current === undefined \|\| summary\.checkedAt > current\.checkedAt\)\) \{[\s\S]*setLatestLibraryUpdateSummary\(summary\)[\s\S]*this\.isLibraryUpdateSummaryStaleAfterFailure\(effectiveSummary\)/,
  'SettingsPage must only use persisted library update results as fallback or when newer than fresh in-memory state at load resolution',
)
assert.match(
  settingsPageSource,
  /this\.libraryUpdateResultStore\(\)\.save\(summary\)[\s\S]*step=save_library_update_results total=/,
  'SettingsPage must asynchronously persist latest successful library update result details',
)
assert.match(
  settingsPageSource,
  /onOpenLibraryUpdateResults:\s*\(\) => void = \(\) => \{\}/,
  'SettingsPage must accept a callback for opening library update result details',
)
assert.match(
  settingsPageSource,
  /row\.key === 'library-update-results'[\s\S]*this\.openLibraryUpdateResults\(\)/,
  'SettingsPage detail row must open the result page',
)
assert.match(
  settingsPageSource,
  /openLibraryUpdateResults\(\): void \{[\s\S]*\[Settings\] step=open_library_update_results[\s\S]*this\.onOpenLibraryUpdateResults\(\)/,
  'SettingsPage must log and call the callback when opening update result details',
)
assert.match(
  settingsPageSource,
  /catch\(\(error: Error\) => \{[\s\S]*step=library_update_failed[\s\S]*this\.libraryUpdateSummary = undefined[\s\S]*clearLatestLibraryUpdateSummary\(\)[\s\S]*saveJobSnapshot\(failedSnapshot\)/,
  'SettingsPage must clear in-memory latest success before a newer failed or backed-off snapshot can open result details',
)
assert.doesNotMatch(
  settingsPageSource,
  /row\.key === 'library-update-results'[\s\S]{0,160}checkLibraryUpdates\(/,
  'SettingsPage detail row must not run a library update check',
)
assert.doesNotMatch(
  settingsPageSource,
  /(Navigation|NavDestination)\(/,
  'SettingsPage must not nest Navigation/NavDestination for library update result details',
)
assert.match(
  settingsPageSource,
  /SecondaryListScaffold\(\{[\s\S]*bottomPadding:\s*ThemeConstants\.FLOAT_BAR_HEIGHT \+ 20 \+ ThemeConstants\.SPACE_XL/,
  'SettingsPage must preserve SecondaryListScaffold bottom clearance while adding update status',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /DEFAULT_LIBRARY_UPDATE_PREFERENCES:[\s\S]*autoCheckEnabled:\s*false[\s\S]*intervalHours:\s*24[\s\S]*foregroundOnly:\s*true[\s\S]*failureCount:\s*0/,
  'LibraryUpdatePreferencesStore defaults must disable automatic checks, use a 24h interval, stay foreground-only, and start with no failures',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /LIBRARY_UPDATE_INTERVAL_OPTIONS: number\[\] = \[12, 24, 48\]/,
  'LibraryUpdatePreferencesStore must expose 12h, 24h, and 48h interval choices',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /getLibraryUpdateNextDueAt\(preferences: LibraryUpdatePreferences\): number \| undefined[\s\S]*const intervalMs = preferences\.intervalHours \* 60 \* 60 \* 1000[\s\S]*const backoffMs = getLibraryUpdateBackoffHours\(preferences\) \* 60 \* 60 \* 1000[\s\S]*return preferences\.lastCheckedAt \+ intervalMs \+ backoffMs/,
  'LibraryUpdatePreferencesStore must compute next due time from the persisted foreground interval plus failure backoff',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /saveFailedCheck\(checkedAt: number, failureCode: string\): Promise<LibraryUpdatePreferences>[\s\S]*failureCount: normalizeLibraryUpdateFailureCount\(current\.failureCount \+ 1\)[\s\S]*lastFailureCode: normalizeLibraryUpdateFailureCode\(failureCode\) \?\? 'unknown'/,
  'LibraryUpdatePreferencesStore must persist failed foreground checks with redacted failure codes and increasing backoff state',
)
assert.doesNotMatch(
  libraryUpdatePreferencesStoreSource,
  /saveFailedCheck\(checkedAt: number, failureCode: string\): Promise<LibraryUpdatePreferences>[\s\S]*next\.lastSummaryText = current\.lastSummaryText[\s\S]*await this\.save\(next\)/,
  'LibraryUpdatePreferencesStore must clear stale success summaries after a failed foreground check',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /getLibraryUpdateLastResultLabel\(preferences: LibraryUpdatePreferences\): string \{[\s\S]*normalizeLibraryUpdateFailureCount\(preferences\.failureCount\) > 0[\s\S]*AppStrings\.get\('library_update_last_failed'\)[\s\S]*formatLibraryUpdateStoredSummary\(preferences\)/,
  'LibraryUpdatePreferencesStore must prioritize an active failure over stored success summary counts',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /saveLastSummary\([\s\S]*checkedAt: number[\s\S]*totalCount: number[\s\S]*newChapterCount: number[\s\S]*updatedCount: number[\s\S]*skippedCount: number[\s\S]*failedCount: number[\s\S]*lastSummaryTotalCount[\s\S]*lastSummaryNewChapterCount[\s\S]*lastSummaryUpdatedCount[\s\S]*lastSummarySkippedCount[\s\S]*lastSummaryFailedCount[\s\S]*failureCount:\s*0/,
  'LibraryUpdatePreferencesStore must clear failure backoff and persist locale-neutral counts after a completed check summary',
)
assert.match(
  libraryUpdateResultStoreSource,
  /createLibraryUpdateNotificationSummary\(summary: LibraryUpdateSummary\): LibraryUpdateNotificationSummary[\s\S]*redactLibraryUpdateFailureCode\(result\.message\)[\s\S]*systemDispatchEnabled: isLibraryUpdateNotificationDeliveryEnabled\(\)/,
  'LibraryUpdateResultStore must expose notification-ready counts and the real delivery capability',
)
assert.match(
  libraryUpdateResultStoreSource,
  /createLibraryUpdateNotificationSummary\(summary: LibraryUpdateSummary\): LibraryUpdateNotificationSummary[\s\S]*AppStrings\.format\('library_update_summary_counts', newChapterCount, summary\.updatedCount, summary\.failedCount\)/,
  'LibraryUpdateResultStore notification summary text must use localized summary resources',
)
assert.doesNotMatch(
  libraryUpdateResultStoreSource,
  /新章 · \$\{summary\.updatedCount\} 更新 · \$\{summary\.failedCount\} 失败/,
  'LibraryUpdateResultStore must not hardcode Chinese update summary labels',
)
assert.match(
  libraryUpdateResultStoreSource,
  /persistLibraryUpdateResult\(result: LibraryUpdateComicResult\)[\s\S]*sanitizeLibraryUpdateResultMessage\(result\.status, result\.message\)/,
  'Persisted failed library update results must store redacted failure codes instead of raw provider reasons',
)
assert.match(
  libraryUpdateResultStoreSource,
  /hydrateLibraryUpdateResult\(value: Object\): LibraryUpdateComicResult \| undefined[\s\S]*sanitizeLibraryUpdateResultMessage\(safeStatus, message\)/,
  'Hydrated old failed library update results must redact raw provider reasons before result pages render them',
)
assert.match(
  libraryUpdateResultStoreSource,
  /redactLibraryUpdateFailureCode\(value: string \| undefined\): string[\s\S]*return 'timeout'[\s\S]*return 'storage_error'[\s\S]*return 'auth_error'[\s\S]*return 'network_error'[\s\S]*return 'source_runtime_error'[\s\S]*return clampString\('unknown', 64\)/,
  'Persisted failed library update results must use only coarse allowlisted failure buckets',
)
assert.match(
  libraryUpdateServiceSource,
  /safeLibraryUpdateFailureCode\(value: string \| undefined\): string[\s\S]*return 'timeout'[\s\S]*return 'storage_error'[\s\S]*return 'auth_error'[\s\S]*return 'network_error'[\s\S]*return 'source_runtime_error'[\s\S]*return 'unknown'/,
  'LibraryUpdateService failure messages must be reduced to coarse allowlisted buckets before notification/status persistence',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /isLibraryUpdateNotificationDeliveryEnabled[\s\S]*status === 'enabled'[\s\S]*return true[\s\S]*status === 'disabled'[\s\S]*return false[\s\S]*status === 'unavailable'[\s\S]*return false/,
  'LibraryUpdatePreferencesStore must report only the implemented foreground notification path as enabled',
)
assert.match(
  libraryUpdatePreferencesStoreSource,
  /catch \(_error\) \{[\s\S]*autoCheckEnabled: DEFAULT_LIBRARY_UPDATE_PREFERENCES\.autoCheckEnabled[\s\S]*intervalHours: DEFAULT_LIBRARY_UPDATE_PREFERENCES\.intervalHours[\s\S]*foregroundOnly: DEFAULT_LIBRARY_UPDATE_PREFERENCES\.foregroundOnly[\s\S]*failureCount: DEFAULT_LIBRARY_UPDATE_PREFERENCES\.failureCount/,
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
  indexSource,
  /import \{ LibraryUpdateResultPage \} from '\.\/LibraryUpdateResultPage'/,
  'Index must import LibraryUpdateResultPage',
)
assert.match(
  indexSource,
  /onOpenLibraryUpdateResults:\s*\(\) => \{[\s\S]*this\.openSettingsSecondary\(RouteName\.LIBRARY_UPDATE_RESULTS\)/,
  'Index must wire Settings detail callback to the top-level route',
)
assert.match(
  indexSource,
  /import \{ LibraryCategoryManagementPage \} from '\.\/LibraryCategoryManagementPage'[\s\S]*name === RouteName\.LIBRARY_CATEGORIES[\s\S]*LibraryCategoryManagementPage\(\{[\s\S]*libraryStore: this\.libraryStore[\s\S]*libraryPersistenceService: this\.ensureLibraryPersistenceService\(\)[\s\S]*onOpenLibraryCategories:\s*\(\) => \{[\s\S]*RouteName\.LIBRARY_CATEGORIES/,
  'Index must route the Settings category management entry to a top-level page',
)
assert.match(
  indexSource,
  /name === RouteName\.LIBRARY_UPDATE_RESULTS[\s\S]*HdsNavDestination\(\)[\s\S]*LibraryUpdateResultPage\(\)[\s\S]*\.titleBar\(this\.navDestTitleBarOpts\(AppStrings\.get\('route_library_update_results_title'\)\)\)/,
  'Index must render library update results as a top-level HDS destination',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/common/Constants.ets'), 'utf8'),
  /static readonly LIBRARY_UPDATE_RESULTS: string = 'LibraryUpdateResultPage'/,
  'RouteName must include LIBRARY_UPDATE_RESULTS',
)
assert.match(
  libraryUpdateResultPageSource,
  /aboutToAppear\(\): void \{[\s\S]*getLatestLibraryUpdateJobSnapshot\(\)[\s\S]*effectiveSummaryForJob\(getLatestLibraryUpdateSummary\(\), latestJob\)[\s\S]*\[LibraryUpdateResults\] step=appear hasSummary=/,
  'LibraryUpdateResultPage must read the latest job snapshot before treating a latest summary as current',
)
assert.match(
  libraryUpdateResultPageSource,
  /new LibraryUpdateResultStore\(this\.context\(\)\)/,
  'LibraryUpdateResultPage must construct the persisted result store from context',
)
assert.match(
  libraryUpdateResultPageSource,
  /loadJobSnapshot\(\)[\s\S]*setLatestLibraryUpdateJobSnapshot\(snapshot\)[\s\S]*isSummaryBlockedByJob\(this\.summary, effectiveJob\)[\s\S]*clearLatestLibraryUpdateSummary\(\)[\s\S]*this\.loadPersistedSummary\(effectiveJob\)/,
  'LibraryUpdateResultPage must let newer failed or backed-off job snapshots suppress stale current successes',
)
assert.match(
  libraryUpdateResultPageSource,
  /\.then\(\(summary: LibraryUpdateSummary \| undefined\) => \{[\s\S]*const current = getLatestLibraryUpdateSummary\(\)[\s\S]*if \(summary !== undefined && \(current === undefined \|\| summary\.checkedAt > current\.checkedAt\)\) \{[\s\S]*setLatestLibraryUpdateSummary\(summary\)[\s\S]*this\.summary = this\.effectiveSummaryForJob\(effectiveSummary, jobSnapshot\)/,
  'LibraryUpdateResultPage must only hydrate persisted results when newer than memory and not blocked by a newer failed job',
)
assert.match(
  libraryUpdateResultPageSource,
  /emptyStateTitle\(\): string \{[\s\S]*s\('library_update_results_empty_backed_off'\)[\s\S]*s\('library_update_results_empty_failed'\)[\s\S]*s\('library_update_results_empty_none'\)[\s\S]*emptyStateMessage\(\): string \{[\s\S]*s\('library_update_results_run_first'\)/,
  'LibraryUpdateResultPage must render the empty state copy',
)
assert.match(
  libraryUpdateResultPageSource,
  /SummaryMetric\(s\('library_update_results_metric_total'\), summary\.totalCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_updated'\), summary\.updatedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_unchanged'\), summary\.unchangedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_skipped'\), summary\.skippedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_failed'\), summary\.failedCount\)[\s\S]*SummaryMetric\(s\('library_update_results_metric_new_chapters'\), countLibraryUpdateNewChapters\(summary\)\)/,
  'LibraryUpdateResultPage must render all aggregate counters',
)
assert.match(
  libraryUpdateResultPageSource,
  /result\.comicId[\s\S]*statusLabel\(result\.status\)[\s\S]*result\.previousChapterCount\} -> \$\{result\.newChapterCount\}[\s\S]*result\.message/,
  'LibraryUpdateResultPage must render per-comic ids, counts, status, and messages',
)
assert.match(
  libraryUpdateResultPageSource,
  /status === 'updated'[\s\S]*s\('library_update_results_status_updated'\)[\s\S]*status === 'unchanged'[\s\S]*s\('library_update_results_status_unchanged'\)[\s\S]*status === 'skipped'[\s\S]*s\('library_update_results_status_skipped'\)[\s\S]*s\('library_update_results_status_failed'\)/,
  'LibraryUpdateResultPage must expose required status labels',
)
assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.LOCAL_ARCHIVE[\s\S]*ComicSourceKind\.LOCAL_FOLDER[\s\S]*AppStrings\.get\('library_update_skip_local_unsupported'\)/,
  'LibraryUpdateService must skip local imports instead of faking update support',
)
assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.KOMGA_REMOTE[\s\S]*ComicSourceKind\.OPDS_REMOTE[\s\S]*ComicSourceKind\.WEBDAV_REMOTE[\s\S]*AppStrings\.get\('library_update_skip_remote_library_unsupported'\)/,
  'LibraryUpdateService must skip unsupported private remote metadata refresh paths',
)
assert.match(
  libraryUpdateServiceSource,
  /mergeSourceChapters[\s\S]*pages: existing\.pages[\s\S]*pageCount: existing\.pageCount/,
  'LibraryUpdateService must preserve existing pages when refreshing source-runtime chapter metadata',
)
assert.match(
  libraryUpdateResultStoreSource,
  /preferences\.getPreferences\(this\.context, LIBRARY_UPDATE_RESULT_STORE_NAME\)/,
  'LibraryUpdateResultStore must use Harmony preferences with its dedicated store name',
)
assert.match(
  libraryUpdateResultStoreSource,
  /JSON\.stringify\(persisted\)/,
  'LibraryUpdateResultStore must serialize persisted result details as JSON',
)
assert.match(
  libraryUpdateResultStoreSource,
  /JSON\.parse\(jsonText\)/,
  'LibraryUpdateResultStore must parse persisted result details as JSON',
)
assert.match(
  libraryUpdateResultStoreSource,
  /store\.put\(LIBRARY_UPDATE_LATEST_RESULT_JSON_KEY, serializeLibraryUpdateSummary\(summary\)\)[\s\S]*store\.flush\(\)/,
  'LibraryUpdateResultStore.save must write the latest result JSON and flush preferences',
)
assert.match(
  libraryUpdateResultStoreSource,
  /Number\.isFinite\(value\) && value >= 0[\s\S]*Number\.isFinite\(value\) && value > 0/,
  'LibraryUpdateResultStore must validate positive checkedAt and nonnegative count fields',
)
assert.match(
  libraryUpdateResultStoreSource,
  /value === 'updated'[\s\S]*value === 'unchanged'[\s\S]*value === 'skipped'[\s\S]*value === 'failed'/,
  'LibraryUpdateResultStore must validate persisted result statuses',
)
assert.match(
  libraryUpdateResultStoreSource,
  /const message = sanitizeLibraryUpdateResultMessage\(result\.status, result\.message\)[\s\S]*clampString\(result\.comicId, LIBRARY_UPDATE_RESULT_MAX_COMIC_ID_LENGTH\)[\s\S]*clampString\(message, LIBRARY_UPDATE_RESULT_MAX_MESSAGE_LENGTH\)/,
  'LibraryUpdateResultStore must clamp persisted comicId and sanitized message strings',
)
assert.match(
  libraryUpdateResultStoreSource,
  /\.slice\(0, LIBRARY_UPDATE_RESULT_MAX_RESULTS\)/,
  'LibraryUpdateResultStore must cap persisted result count',
)
assert.match(
  libraryUpdateResultStoreSource,
  /totalCount:\s*normalizeCount\(summary\.totalCount\)[\s\S]*updatedCount:\s*normalizeCount\(summary\.updatedCount\)[\s\S]*failedCount:\s*normalizeCount\(summary\.failedCount\)[\s\S]*results,/,
  'LibraryUpdateResultStore serialization must preserve sanitized aggregate counters independent of capped details',
)
assert.match(
  libraryUpdateResultStoreSource,
  /function aggregateCountField\([\s\S]*!isNonNegativeFiniteNumber\(value\)[\s\S]*return fallback[\s\S]*return normalizeCount\(value\)/,
  'LibraryUpdateResultStore hydration must sanitize aggregate counters and fall back for missing or malformed fields',
)
assert.match(
  libraryUpdateResultStoreSource,
  /totalCount:\s*aggregateCountField\(record, 'totalCount', resultTotalCount\)[\s\S]*updatedCount:\s*aggregateCountField\(record, 'updatedCount', resultUpdatedCount\)[\s\S]*failedCount:\s*aggregateCountField\(record, 'failedCount', resultFailedCount\)/,
  'LibraryUpdateResultStore hydration must prefer persisted aggregate counters over capped detail-derived counts when valid',
)
assert.match(
  libraryUpdateResultStoreSource,
  /catch \(_error\) \{[\s\S]*return undefined[\s\S]*\}/,
  'LibraryUpdateResultStore must fail closed to undefined for corrupt or unreadable persisted JSON',
)
assert.doesNotMatch(
  libraryUpdateResultStoreSource,
  /requestJson|settings|token|cookie|password|headers|payload|rawUrl|sourcePath|sourceRuntimeId|remoteResourceId/i,
  'LibraryUpdateResultStore must not persist raw source request/settings/headers/token/password/payload/url fields',
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
  /function parseValidatedLibraryStoreDocument[\s\S]*assertSupportedLibraryStoreDocument\(document\)[\s\S]*customCategories[\s\S]*assertValidPersistedLibraryCategory[\s\S]*assertUniquePersistedLibraryCategories[\s\S]*categoryDisplayStrategies[\s\S]*assertValidPersistedCategoryDisplayStrategy[\s\S]*assertUniquePersistedCategoryDisplayStrategies[\s\S]*document\.comics\.forEach[\s\S]*export function assertValidLibraryStoreJson[\s\S]*parseValidatedLibraryStoreDocument\(payload\)[\s\S]*export function hydrateLibraryStoreFromJson[\s\S]*const document = parseValidatedLibraryStoreDocument\(payload\)[\s\S]*libraryStore\.clear\(\)[\s\S]*libraryStore\.replaceCustomCategories[\s\S]*libraryStore\.replaceCategoryDisplayStrategies/,
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
  /@Local private libraryComics: Comic\[\][\s\S]*private refreshLibrarySnapshot\(\): void \{[\s\S]*this\.libraryComics = this\.libraryStore\.listComics\(\)[\s\S]*this\.libraryRevision \+= 1[\s\S]*private handleRemoveComicRequested\(comicId: ComicId\): boolean[\s\S]*removeComicAndPersistLibraryStore[\s\S]*this\.refreshLibrarySnapshot\(\)[\s\S]*return true/,
  'confirmed remove must publish a fresh comic array snapshot after successful persistence so the live shelf re-renders',
)
assert.match(
  offlineDownloadStoreSource,
  /deleteComicDownloads\(comicId: ComicId\): Promise<void>[\s\S]*const comicDir = this\.comicDir\(comicId\)[\s\S]*await this\.deleteDownloadDir\(comicDir\)/,
  'offline download store must support safe whole-comic cleanup for removed local shelf rows',
)
assert.match(
  offlineDownloadQueueStoreSource,
  /removeComic\(comicId: ComicId\): number[\s\S]*item\.comicId !== comicId[\s\S]*preferences: document\.preferences[\s\S]*return removedCount[\s\S]*deleteComicDownloads\(comicId: ComicId\): Promise<number>[\s\S]*await store\.deleteComicDownloads\(comicId\)[\s\S]*return this\.removeComic\(comicId\)/,
  'offline download queue store must clear all rows for a removed comic after deleting its app-sandbox downloads',
)
assert.match(
  indexSource,
  /private cleanupRemovedComicDownloads\(comicId: ComicId\): void[\s\S]*new OfflineDownloadQueueStore\(context\.filesDir\)\.deleteComicDownloads\(comicId\)[\s\S]*downloads_cleanup removed=\$\{removedCount\}[\s\S]*downloads_cleanup_failed reason=delete_downloads/,
  'successful local comic remove must asynchronously clean orphaned offline downloads with redacted diagnostics',
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
  /@Param libraryComics: Comic\[\][\s\S]*@Param libraryRevision: number[\s\S]*@Local private displayedComics: Comic\[\][\s\S]*@Local private displayedRevision: number[\s\S]*@Monitor\('libraryComics', 'libraryRevision'\)/,
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
  /export struct ComicCoverCard \{[\s\S]*@Param comic: ComicCoverInfo[\s\S]*@Param title: string[\s\S]*@Param subtitle: string[\s\S]*@Param progressText: string[\s\S]*Text\(this\.displayTitle\(\)\)[\s\S]*Text\(this\.displaySubtitle\(\)\)/,
  'ComicCoverCard must receive primitive reactive props for grid cells so reused card instances update after remove/reorder',
)
assert.match(
  libraryPageSource,
  /struct ContinueReadingShelfCard \{[\s\S]*@Param info: ContinueReadingCardViewModel[\s\S]*@Param revision: number[\s\S]*Text\(this\.info\.title\)[\s\S]*onOpenReader\(this\.info\.comicId\)/,
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
  /showRemoveConfirmation[\s\S]*primaryButton:\s*\{[\s\S]*value:\s*s\('common_remove'\)[\s\S]*if \(this\.onRemoveComicRequested\(comic\.id\)\) \{[\s\S]*this\.refreshDisplayedSnapshotFromStore\(\)[\s\S]*secondaryButton:\s*\{[\s\S]*value:\s*s\('common_cancel'\)/,
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
  /title:\s*normalizeSourceDisplayText\(title\) \?\? title[\s\S]*scanlator:\s*normalizeSourceDisplayText\(row\.scanlator\)[\s\S]*language:\s*optionalString\(firstNonEmpty\(\[row\.language, row\.lang\]\)\)[\s\S]*dateUpload:\s*optionalNumber\(row\.date_upload\) \?\? optionalNumber\(row\.dateUpload\)/,
  'SourceChapter normalization must preserve chapter scanlator, language, and upload date metadata',
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
assert.match(
  mangaDetailModelsSource,
  /export interface MangaChapterItem[\s\S]*scanlator\?: string[\s\S]*language\?: string[\s\S]*dateUpload\?: number[\s\S]*parseMangaChapterFromSourceItem[\s\S]*language:\s*firstSourceString\(\[[\s\S]*item\['language'\][\s\S]*item\['lang'\][\s\S]*dateUpload:\s*optionalSourceNumber\(item\['date_upload'\]\) \?\? optionalSourceNumber\(item\['dateUpload'\]\)/,
  'Manga chapter items must keep source-provided scanlator, language, and upload date metadata',
)
assert.match(
  chapterReadStateStoreSource,
  /CHAPTER_READ_STATE_FILE_NAME:\s*string = 'chapter-read-state\.v1\.json'/,
  'chapter read-state overrides must persist in a dedicated schema-versioned file',
)
assert.match(
  chapterReadStateStoreSource,
  /isChapterReadFromState\([\s\S]*override !== undefined[\s\S]*return override\.isRead[\s\S]*progress\.chapterId === chapterId[\s\S]*progress\.completed === true/,
  'chapter read-state helper must prefer explicit overrides and otherwise use completed reader progress for the same chapter',
)
assert.match(
  chapterReadStateStoreSource,
  /mark\(comicId: ComicId, chapterId: string, isRead: boolean\)[\s\S]*this\.overrides\.set\(chapterReadStateKey\([\s\S]*this\.persist\(\)/,
  'chapter read-state store must persist explicit per-chapter read/unread overrides',
)
assert.match(
  mangaDetailPageSource,
  /decorateChapterStates\(chapters: MangaChapterItem\[\]\): MangaChapterItem\[\][\s\S]*readerSessionStore\.getProgress\(comicId\)[\s\S]*scanlator: chapter\.scanlator[\s\S]*language: chapter\.language[\s\S]*dateUpload: chapter\.dateUpload[\s\S]*readStateStore\.isRead\(comicId, chapter\.id, progress\)[\s\S]*getChapterSummary\(comicId, chapter\.id\)[\s\S]*OfflineDownloadStatus\.DOWNLOADED/,
  'MangaDetailPage must preserve chapter metadata while deriving read/downloaded state',
)
assert.match(
  mangaDetailPageSource,
  /markChapterReadState\(chapterId: string, isRead: boolean\)[\s\S]*store\.mark\(this\.currentComicId\(\), chapterId, isRead\)[\s\S]*applyChapterStatesToCurrent\(\)/,
  'MangaDetailPage mark-read must persist explicit chapter overrides and refresh visible state',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /markChapterReadState\(chapterId: string, isRead: boolean\)[\s\S]*readerSessionStore\.saveProgress/,
  'MangaDetailPage manual mark-read must not overwrite comic reader progress',
)
assert.match(
  mangaDetailPageSource,
  /markVisibleChaptersReadState\(chapterIds: string\[\], isRead: boolean\)[\s\S]*targetIds\.forEach[\s\S]*store\.mark\(comicId, chapterId, isRead\)[\s\S]*applyChapterStatesToCurrent\(\)/,
  'MangaDetailPage visible read-state action must mark only the provided visible chapter ids',
)
assert.match(
  mangaDetailPageSource,
  /ChapterListSection\(\{[\s\S]*onMarkChapterReadState:[\s\S]*this\.markChapterReadState\(chapterId, isRead\)[\s\S]*onMarkVisibleChaptersReadState:[\s\S]*this\.markVisibleChaptersReadState\(chapterIds, isRead\)/,
  'MangaDetailPage must wire per-chapter and visible chapter read-state actions',
)
assert.match(
  chapterListSectionSource,
  /export enum ChapterReadFilter\s*{[\s\S]*ALL[\s\S]*UNREAD[\s\S]*READ[\s\S]*DOWNLOADED/,
  'ChapterListSection must expose all/unread/read/downloaded chapter filters',
)
assert.match(
  chapterListSectionSource,
  /filteredChapterList\(\): MangaChapterItem\[\][\s\S]*ChapterReadFilter\.UNREAD[\s\S]*!chapter\.isRead[\s\S]*ChapterReadFilter\.READ[\s\S]*chapter\.isRead[\s\S]*ChapterReadFilter\.DOWNLOADED[\s\S]*chapter\.isDownloaded/,
  'ChapterListSection filters must use durable read/downloaded flags on chapter rows',
)
assert.match(
  chapterListSectionSource,
  /@Local private languageFilter: string = ''[\s\S]*@Local private groupFilter: string = ''[\s\S]*filteredChapterList\(\): MangaChapterItem\[\][\s\S]*this\.normalizeMetadataValue\(chapter\.language\) === this\.languageFilter[\s\S]*this\.normalizeMetadataValue\(chapter\.scanlator\) === this\.groupFilter/,
  'ChapterListSection must filter chapters by language and scanlator group metadata',
)
assert.match(
  chapterListSectionSource,
  /LanguageFilterMenu\(\)[\s\S]*chapter_list_filter_language_all[\s\S]*ForEach\(this\.languageOptions\(\)[\s\S]*this\.setLanguageFilter\(language\)[\s\S]*GroupFilterMenu\(\)[\s\S]*chapter_list_filter_group_all[\s\S]*ForEach\(this\.groupOptions\(\)[\s\S]*this\.setGroupFilter\(group\)/,
  'ChapterListSection must expose language and group filters as menus',
)
assert.match(
  chapterListSectionSource,
  /VisibleReadStateMenu\(\)[\s\S]*onMarkVisibleChaptersReadState\(this\.visibleChapterIds\(\), true\)[\s\S]*onMarkVisibleChaptersReadState\(this\.visibleChapterIds\(\), false\)/,
  'ChapterListSection visible mark-read actions must target the current filtered visible chapter ids',
)
assert.match(
  chapterListSectionSource,
  /chapterSubtitle\(chapter: MangaChapterItem\): string[\s\S]*chapter\.scanlator[\s\S]*chapter\.language[\s\S]*formatLanguage\(chapter\.language\)[\s\S]*chapter\.dateUpload[\s\S]*formatDate\(chapter\.dateUpload\)/,
  'ChapterListSection subtitle must show scanlator, language, and upload date metadata',
)
assert.match(
  mangaDetailPageSource,
  /mangaChapterItemFromComicChapter\(chapter: Chapter\): MangaChapterItem[\s\S]*scanlator: chapter\.scanlator[\s\S]*language: chapter\.language[\s\S]*dateUpload: chapter\.dateUpload/,
  'MangaDetailPage must hydrate chapter metadata from library chapters',
)
assert.match(
  mangaDetailPageSource,
  /comicFromSourceManga\(manga: MangaDetail, chapters: MangaChapterItem\[\], comicId: string\): Comic[\s\S]*scanlator: chapter\.scanlator[\s\S]*language: chapter\.language[\s\S]*dateUpload: chapter\.dateUpload/,
  'Adding source manga to library must persist chapter metadata into library chapters',
)
assert.match(
  libraryUpdateServiceSource,
  /mergeSourceChapters[\s\S]*scanlator: remote\.scanlator \?\? existing\.scanlator[\s\S]*language: remote\.language \?\? existing\.language[\s\S]*dateUpload: remote\.dateUpload \?\? existing\.dateUpload[\s\S]*pages: existing\.pages[\s\S]*pageCount: existing\.pageCount/,
  'LibraryUpdateService must refresh chapter metadata without clearing older values and preserve downloaded pages',
)
assert.match(
  libraryPersistenceSource,
  /export interface PersistedChapter[\s\S]*scanlator\?: string[\s\S]*language\?: string[\s\S]*dateUpload\?: number[\s\S]*persistChapter\(chapter: Chapter\)[\s\S]*row\.scanlator = chapter\.scanlator[\s\S]*row\.language = chapter\.language[\s\S]*row\.dateUpload = chapter\.dateUpload[\s\S]*hydrateChapter\(row: PersistedChapter\)[\s\S]*chapter\.scanlator = row\.scanlator[\s\S]*chapter\.language = row\.language[\s\S]*chapter\.dateUpload = row\.dateUpload/,
  'LibraryPersistence must round-trip chapter metadata',
)

assert.match(backupServiceSource, /const BACKUP_SCHEMA_VERSION:\s*number = 3/, 'backup export must use schema v3')
assert.match(backupServiceSource, /const BACKUP_SCHEMA_VERSION_V2:\s*number = 2/, 'backup import must keep schema v2 compatibility')
assert.match(backupServiceSource, /const BACKUP_SCHEMA_VERSION_V1:\s*number = 1/, 'backup import must keep schema v1 compatibility')
for (const version of [1, 2, 3]) {
  assert.match(
    backupServiceSource,
    new RegExp(`isAcceptedPlaintextSchemaVersion[\\s\\S]*schemaVersion === BACKUP_SCHEMA_VERSION${version === 1 ? '_V1' : version === 2 ? '_V2' : ''}`),
    `backup plaintext import/preview must continue accepting v${version}`,
  )
}
assert.match(
  backupServiceSource,
  /import\(json: string\): Promise<void> \{\s*await this\.importDocument\(json, false\)/,
  'raw plaintext import must use the plaintext-only schema gate',
)
assert.match(
  backupServiceSource,
  /preview\(json: string\): BackupImportPreview[\s\S]*this\.previewDocument\(json, false\)/,
  'raw plaintext preview must use the plaintext-only schema gate',
)
assert.match(
  backupServiceSource,
  /export interface BackupImportPreview\s*{[\s\S]*exportedAt:\s*number[\s\S]*exportedAtText:\s*string/,
  'backup previews must keep numeric exportedAt for local backup retention ordering',
)
assert.match(
  backupServiceSource,
  /normalizeBackupExportedAt\(document\.exportedAt\)[\s\S]*exportedAtText:\s*formatBackupExportedAt\(document\.exportedAt\)/,
  'plaintext backup preview must preserve exportedAt as a sortable timestamp',
)
assert.match(
  backupEncryptionServiceSource,
  /export interface BackupEncryptedPublicPreview\s*{[\s\S]*exportedAt:\s*number[\s\S]*exportedAtText:\s*string[\s\S]*previewEncryptedBackupEnvelope[\s\S]*exportedAt:\s*envelope\.createdAt/,
  'encrypted backup envelope preview must expose createdAt as a sortable exportedAt timestamp',
)
assert.match(
  backupServiceSource,
  /listLocalBackups\(\): Promise<BackupLocalFileRecord\[\]>[\s\S]*const records: BackupLocalFileRecord\[\] = \[\][\s\S]*records\.push\(record\)[\s\S]*return records\.sort[\s\S]*right\.preview\.exportedAt - left\.preview\.exportedAt/,
  'local backup list and retention must order by backup exportedAt metadata instead of mutable file names',
)
assert.match(
  backupEncryptionServiceSource,
  /AppStrings\.get\('backup_preview_not_provided'\)/,
  'encrypted backup envelope preview fallback text must use localized backup resources',
)
assert.doesNotMatch(
  backupEncryptionServiceSource,
  /'未提供'|"未提供"/,
  'encrypted backup envelope preview must not hardcode Chinese fallback text',
)
assert.match(
  backupServiceSource,
  /function isAcceptedDecryptedSchemaVersion[\s\S]*BACKUP_ENCRYPTED_SCHEMA_VERSION/,
  'schema v4 must only be accepted by decrypted backup content gates',
)
assert.doesNotMatch(
  backupServiceSource,
  /function isAcceptedPlaintextSchemaVersion[^{]*\{[^}]*BACKUP_ENCRYPTED_SCHEMA_VERSION/,
  'standalone unencrypted v4 JSON backups must not be accepted by plaintext gates',
)
assert.match(
  backupServiceSource,
  /const libraryStorePayload = restoreLocalLibraryMetadataBackupEntries\(document\.libraryStore, document\.localLibraryMetadata\)[\s\S]*assertValidLibraryStoreJson\(libraryStorePayload\)[\s\S]*JSON\.parse\(document\.readingProgress\)[\s\S]*writeText\(this\.libraryPath\(\), libraryStorePayload\)/,
  'backup import must validate embedded libraryStore plus restored local metadata with production parser before writing restored categories',
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
  /downloadQueue\?: string[\s\S]*document\.downloadQueue = normalizeBackupDownloadQueuePayload\(downloadQueue\)/,
  'backup v3 export must include normalized download queue metadata when present',
)
assert.match(
  backupServiceSource,
  /trackerMappings\?: ComicTrackerMapping\[\][\s\S]*trackerMappings:\s*await this\.exportTrackerMappings\(\)/,
  'backup v3 export must include tracker comic mappings without account credentials',
)
assert.match(
  backupServiceSource,
  /exportTrackerMappings\(\): Promise<ComicTrackerMapping\[\]>[\s\S]*TRACKER_PREFERENCES_STORE_NAME[\s\S]*TRACKER_COMIC_MAPPINGS_KEY[\s\S]*normalizeComicTrackerMappings\(parsed\)/,
  'backup tracker export must read and normalize only comic mapping preferences',
)
assert.match(
  backupServiceSource,
  /if \(document\.schemaVersion >= BACKUP_SCHEMA_VERSION\) \{[\s\S]*importSourceSettings\(document\.sourceSettings\)[\s\S]*importDownloadQueue\(document\.downloadQueue\)[\s\S]*importTrackerMappings\(document\.trackerMappings\)[\s\S]*if \(document\.schemaVersion >= BACKUP_SCHEMA_VERSION_V2\) \{[\s\S]*importSourcePackages\(document\.sourcePackages\)[\s\S]*importSettings\(document\.settings\)/,
  'backup v3 import must restore source settings, download queue metadata, and tracker mappings while preserving v2 source package/settings restore',
)
assert.match(
  backupServiceSource,
  /importTrackerMappings\(mappings: ComicTrackerMapping\[\] \| undefined\): Promise<void>[\s\S]*TRACKER_PREFERENCES_STORE_NAME[\s\S]*TRACKER_COMIC_MAPPINGS_KEY[\s\S]*normalizeComicTrackerMappings\(mappings\)/,
  'backup tracker import must write sanitized comic mappings into tracker preferences',
)
assert.match(
  backupServiceSource,
  /trackerMappingCount:\s*countBackupTrackerMappings\(document\.trackerMappings\)[\s\S]*hasTrackerMappingCount:\s*document\.trackerMappings !== undefined/,
  'backup preview must report tracker mapping counts when v3 trackerMappings are present',
)
assert.doesNotMatch(
  backupServiceSource,
  /trackerAccounts|TRACKER_ACCOUNTS_KEY|credentialAccountKey|access_token|refresh_token/,
  'backup service must not export tracker accounts, credential references, or token fields',
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
  remoteServerStoreSource,
  /AppStrings\.get\('server_error_missing_api_key'\)[\s\S]*AppStrings\.get\('server_error_missing_username_password'\)/,
  'remote server credential validation errors must use localized resources',
)
assert.doesNotMatch(
  remoteServerStoreSource,
  /请输入 API key|请输入用户名和密码/,
  'remote server store must not hardcode Chinese credential validation errors',
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
  /KomaActionButton\(\{[\s\S]*label: this\.updateCheckBusy \? t\('source_pkg_checking'\) : t\('source_pkg_check_updates'\)[\s\S]*checkInstalledUpdates\(\)/,
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
  /updateStatusText\(source: InstalledSourcePackage\): string[\s\S]*t\('source_pkg_update_status_checking'\)[\s\S]*tf\('source_pkg_update_status_latest'[\s\S]*tf\('source_pkg_update_status_available'[\s\S]*t\('source_pkg_update_status_missing'\)[\s\S]*tf\('source_pkg_update_status_failed'[\s\S]*t\('source_pkg_update_status_unknown'\)/,
  'installed source cards must render per-package update status text',
)
assert.match(
  sourcePackageManagerPageSource,
  /if \(this\.updateEntry\(source\.id\) !== undefined\) \{[\s\S]*KomaActionButton\(\{[\s\S]*label: this\.updateActionLabel\(source\.id\)[\s\S]*this\.updateInstalledPackage\(source\)/,
  'installed source cards must show an update button only when an update is available',
)
assert.match(
  sourcePackageManagerPageSource,
  /\[SourceSettingsValidation\] step=start id=[\s\S]*\[SourceSettingsValidation\] step=done id=[\s\S]*ok=true[\s\S]*\[SourceSettingsValidation\] step=done id=[\s\S]*ok=false reason=/,
  'source package manager must log SourceSettingsValidation lifecycle without payloads',
)
assert.match(
  sourcePackageManagerPageSource,
  /validateSettings\(source: InstalledSourcePackage\): void[\s\S]*appSourceSettingsStore\.loadForSource\(source\.id\)[\s\S]*const args: SourceSettingsValidationArgs = \{\}[\s\S]*const hostHints: SourceSettingsValidationHostHints = \{ network: true \}[\s\S]*operation: 'get_home'[\s\S]*args,[\s\S]*settings: savedSettings[\s\S]*hostHints,[\s\S]*runRegisteredSourceRequestById\(appSourceRuntimeRegistry, source\.id, JSON\.stringify\(request\)\)/,
  'source settings validation must use saved per-source settings in a runtime get_home envelope',
)
assert.match(
  sourcePackageManagerPageSource,
  /settingsValidationText\(source: InstalledSourcePackage\): string[\s\S]*tf\('source_pkg_settings_saved_count', status\.savedCount\)[\s\S]*case 'running':[\s\S]*t\('source_pkg_settings_validation_status_running'\)[\s\S]*case 'pass':[\s\S]*t\('source_pkg_settings_validation_status_pass'\)[\s\S]*case 'fail':[\s\S]*tf\('source_pkg_settings_validation_status_fail'[\s\S]*case 'unknown':[\s\S]*t\('source_pkg_settings_validation_status_unknown'\)/,
  'installed source cards must render unknown/running/PASS/FAIL settings validation text with saved count',
)
assert.match(
  sourcePackageManagerPageSource,
  /KomaActionButton\(\{[\s\S]*label: this\.validateSettingsActionLabel\(source\.id\)[\s\S]*this\.validateSettings\(source\)/,
  'installed source cards must expose a settings validation action',
)
assert.match(
  sourcePackageManagerPageSource,
  /\[SourceRuntimeDiagnostics\] step=open id=[\s\S]*\[SourceRuntimeDiagnostics\] step=refresh id=/,
  'source package manager must log diagnostics open and refresh lifecycle with metadata only',
)
assert.match(
  sourcePackageManagerPageSource,
  /KomaActionButton\(\{[\s\S]*label: this\.isDiagnosticsOpen\(source\.id\) \? t\('source_pkg_hide_diagnostics'\) : t\('source_pkg_diagnostics'\)[\s\S]*this\.toggleDiagnostics\(source\)/,
  'installed source cards must expose a diagnostics action',
)
assert.match(
  sourcePackageManagerPageSource,
  /DiagnosticsPanel\(source: InstalledSourcePackage\)[\s\S]*t\('source_pkg_refresh_diagnostics'\)[\s\S]*diagnosticsSourceMetaText\(source\)[\s\S]*diagnosticsSmokeText\(source\)[\s\S]*diagnosticsUpdateText\(source\)[\s\S]*diagnosticsSettingsText\(source\)[\s\S]*diagnosticsSettingsValidationText\(source\)/,
  'diagnostics panel must render source id metadata, smoke, update, setting counts, and settings validation',
)
assert.match(
  sourcePackageManagerPageSource,
  /diagnosticsSourceMetaText\(source: InstalledSourcePackage\): string[\s\S]*id: [\s\S]*enabled:[\s\S]*imported:/,
  'diagnostics panel must include safe source id/enabled/imported metadata',
)
assert.match(
  sourcePackageManagerPageSource,
  /diagnosticsSettingCounts\(sourceId: string\): SourceDiagnosticsSettingCounts[\s\S]*fetchSourceSettingDescriptors\(appSourceRuntimeRegistry, sourceId\)[\s\S]*total:[\s\S]*editable:[\s\S]*sensitive:[\s\S]*saved:/,
  'diagnostics panel must compute descriptor total/editable/sensitive and saved safe setting counts',
)
assert.match(
  sourcePackageManagerPageSource,
  /capsText\(source\)/,
  'diagnostics panel must include source capabilities',
)
assert.match(
  sourcePackageManagerPageSource,
  /installedTrustMetaText\(source\)[\s\S]*installedTrustCapabilityText\(source\)[\s\S]*diagnosticsTrustText\(source\)/,
  'source package manager must display installed source trust metadata and capability summary',
)
assert.match(
  sourcePackageManagerPageSource,
  /RemoteIndexCard\(entry: SourceIndexEntry\)[\s\S]*sourceIndexTrustMetaText\(entry\)[\s\S]*sourceIndexTrustCapabilityText\(entry\)/,
  'source package manager must display trust metadata for source index update candidates',
)
assert.match(
  sourcePackageTrustPolicySource,
  /sourcePackageTrustBoundaryNotice\(\): string \{[\s\S]*t\('source_pkg_boundary_notice'\)[\s\S]*installedSourceTrustSummary[\s\S]*t\('source_pkg_provenance_imported'\)[\s\S]*t\('source_pkg_verification_unsigned'\)[\s\S]*t\('source_pkg_capability_summary_prefix'\)[\s\S]*sourceIndexCandidateTrustSummary[\s\S]*t\('source_pkg_capability_summary_pending'\)/,
  'source trust policy labels must stay honest about user import, unverified signatures, manifest-derived capabilities, and no default public sources',
)
assert.doesNotMatch(
  sourcePackageTrustPolicySource,
  /verifySignature|signatureVerified|realVerification|isSignatureValid|cryptoFramework|publicKey|certificate/i,
  'source trust policy must not add fake signature verification',
)
assert.doesNotMatch(
  sourcePackageManagerPageSource,
  /console\.(?:log|info|warn|error)\([^)]*JSON\.stringify\((?:settings|savedSettings|request|this\.settingDraft)/,
  'source settings validation must not log settings payloads or request JSON',
)
assert.doesNotMatch(
  sourcePackageManagerPageSource,
  /\[SourceRuntimeDiagnostics\][^)]*(?:JSON\.stringify|settings|savedSettings|request|settingDraft|token|cookie|password|apiKey|secret)/i,
  'source runtime diagnostics logs must not include settings payloads, request JSON, or secret descriptors',
)
assert.doesNotMatch(
  sourcePackageManagerPageSource,
  /catch \((?:error|err|e)\)[\s\S]{0,160}(?:statusText|showToast)\s*=[\s\S]{0,80}\.(?:message|stack)|catch \((?:error|err|e)\)[\s\S]{0,160}showToast\([^)]*\.(?:message|stack)/,
  'source package manager must not surface raw exception details in settings validation UI',
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
  sourceRuntimeAppRegistrySource,
  /smokeStatus: diagnostic === undefined \? AppStrings\.get\('source_pkg_not_run'\)/,
  'source package smoke status fallback must use localized source package resources',
)
assert.match(
  browseViewModelSource,
  /AppStrings\.get\('browse_untitled_manga'\)[\s\S]*AppStrings\.get\('browse_error_load_sources'\)[\s\S]*AppStrings\.get\('browse_error_load_home'\)[\s\S]*AppStrings\.get\('browse_error_load_more'\)[\s\S]*AppStrings\.get\('browse_error_source_unavailable'\)[\s\S]*AppStrings\.format\('browse_error_source_runtime_failed'/,
  'BrowseViewModel source browse fallback errors must use localized resources',
)
assert.match(
  sourceModelsSource,
  /export interface SourceFilter \{[\s\S]*id: string[\s\S]*optionIds\?: string\[\][\s\S]*parseSourceFiltersJson[\s\S]*id: firstNonEmpty\(\[row\.id, row\.name, row\.label\]\)[\s\S]*optionIds: normalizeFilterOptionIds\(row\.options\)/,
  'source filter parsing must preserve descriptor ids and option ids for runtime manga-list requests',
)
assert.match(
  browseViewModelSource,
  /@Trace filters: SourceFilter\[\] = \[\][\s\S]*@Trace browseFilterValues: SourceMangaListFilters = \{\}[\s\S]*this\.filters = await this\.loadSourceFilters\(source\)[\s\S]*this\.browseFilterValues = this\.defaultSourceFilterValues\(this\.filters\)[\s\S]*filters: this\.browseFilterValues/,
  'BrowseViewModel must load source filters and pass active values into get_manga_list requests',
)
assert.match(
  browseViewModelSource,
  /setBrowseFilterValue\(filterId: string, value: SourceFilterValue \| undefined\)[\s\S]*const key = this\.filterRequestKey\(filter\)[\s\S]*nextValues\[key\] = this\.normalizeFilterRequestValue\(key, value\)[\s\S]*await this\.selectBrowseListing\(listing\)/,
  'BrowseViewModel must update source filter values and reload the current listing',
)
assert.match(
  browseViewModelSource,
  /loadSourceFilters\(source: SourceRuntimeRegistryInstalledSourceSummary\): Promise<SourceFilter\[\]>[\s\S]*runSourceOperationResponse\(source\.sourceId, 'get_filters'[\s\S]*parseSourceFiltersJson\(JSON\.stringify\(response\.data \?\? \{\}\)\)/,
  'BrowseViewModel must request get_filters descriptors from installed source runtimes',
)
assert.match(
  browseViewModelSource,
  /filterRequestKey\(filter: SourceFilter\): string[\s\S]*raw\.startsWith\('filter:'\)[\s\S]*normalizeFilterRequestValue\(key: string, value: SourceFilterValue\)[\s\S]*const prefix = `\$\{key\}:`[\s\S]*value\.substring\(prefix\.length\)/,
  'BrowseViewModel must normalize fixture-style filter:sort and sort:popular ids before sending request filters',
)
assert.match(
  sourceBrowsePageSource,
  /SourceFilterControls\(\)[\s\S]*filter\.type === 'check'[\s\S]*Toggle\(\{ type: ToggleType\.Switch[\s\S]*filter\.type === 'text'[\s\S]*TextInput\([\s\S]*\.onSubmit\(\(\) =>[\s\S]*else if \(\(filter\.options \?\? \[\]\)\.length > 0\)[\s\S]*bindMenu\(this\.activeFilterMenuId === filter\.id, this\.FilterOptionMenu\(filter\)/,
  'SourceBrowsePage must render source filters with switch/text input/menu controls according to descriptor type',
)
assert.doesNotMatch(
  browseViewModelSource,
  /未命名漫画|无法加载源|源浏览失败|加载更多失败|源未安装或不可用|源运行失败/,
  'BrowseViewModel must not hardcode Chinese browse/runtime fallback messages',
)
assert.match(
  localImportCoordinatorSource,
  /AppStrings\.get\('import_image_title'\)/,
  'local image import fallback title must use localized import resources',
)
assert.doesNotMatch(
  localImportCoordinatorSource,
  /return '图片'|: '图片'/,
  'local image import coordinator must not hardcode Chinese image fallback title',
)
assert.match(
  sourceIndexServiceSource,
  /installFromBytes\(this\.context, archiveBytes, entry\.pkg, entry\.id\)/,
  'source index installs must pass the expected source id into package validation',
)
assertExport(localLibraryFolderContractSource, 'localLibraryFolderUri')
assertExport(localLibraryFolderContractSource, 'buildComicFromLocalLibraryFolderSeries')
assertExport(localLibraryFolderContractSource, 'buildComicsFromLocalLibraryFolderScan')
assert.match(
  localLibraryFolderContractSource,
  /localLibraryFolderUri\(rootUri: string, relativePath: string\): string[\s\S]*normalizeLocalLibraryRelativePath\(relativePath\)[\s\S]*encodeRelativeUriPath\(safeRelativePath\)/,
  'local library folder URIs must validate relative paths before encoding them',
)
assert.match(
  localLibraryFolderContractSource,
  /buildComicFromLocalLibraryFolderSeries[\s\S]*coverUri = chapters\.find[\s\S]*sourceKind: ComicSourceKind\.LOCAL_FOLDER[\s\S]*remoteResourceId: `\$\{rootId\}:\$\{series\.relativePath\}`[\s\S]*buildComicsFromLocalLibraryFolderScan/,
  'local library folder scans must be convertible into LOCAL_FOLDER comics with stable resource ids and cover fallback',
)
assert.doesNotMatch(
  localLibraryFolderContractSource,
  /subtitle:\s*`[^`]*(chapter|chapters|本|卷|话)/,
  'local library folder comic conversion must not hardcode user-visible subtitle copy in the model layer',
)
assert.match(
  localLibraryRescanServiceSource,
  /LOCAL_LIBRARY_RESCAN_UI_MUTATION_CONTRACT = 'MODEL_ONLY_NO_SYNC_UI_MUTATION'[\s\S]*LOCAL_LIBRARY_RESCAN_DESTRUCTIVE_ACTION_CONTRACT = 'NO_DELETE_LIBRARY_ROWS_OR_USER_FILES'[\s\S]*removedCount: missingCount[\s\S]*missingChapterCount/,
  'local library rescan summaries must report missing rows without deleting shelf entries or user files',
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
    title: 'Rain After Town',
    subtitle: 'Local ZIP - 12 chapters',
    chapterTitle: 'Chapter 8',
    fallbackProgressText: 'Chapter 8',
    coverColor: '#16745F',
    accentColor: '#2FAE84',
    pageCount: 5,
  },
  {
    id: 'local-02',
    title: 'North Window Shorts',
    subtitle: 'Image folder - 6 chapters',
    chapterTitle: 'Chapter 1',
    fallbackProgressText: 'Unread',
    coverColor: '#344E7A',
    accentColor: '#6E92CE',
    pageCount: 1,
  },
  {
    id: 'local-03',
    title: 'Seaside Slow Train',
    subtitle: 'CBZ - 4 chapters',
    chapterTitle: 'Chapter 2',
    fallbackProgressText: '42%',
    coverColor: '#8A6240',
    accentColor: '#D39A62',
    pageCount: 1,
  },
  {
    id: 'local-04',
    title: 'Three PM Notes',
    subtitle: 'Local ZIP - 18 chapters',
    chapterTitle: 'Chapter 3',
    fallbackProgressText: 'Chapter 3',
    coverColor: '#7A405D',
    accentColor: '#C46B92',
    pageCount: 1,
  },
  {
    id: 'local-05',
    title: 'Old Bookshop Tour',
    subtitle: 'Image folder - 9 chapters',
    chapterTitle: 'Chapter 1',
    fallbackProgressText: 'Newly added',
    coverColor: '#51624D',
    accentColor: '#89A57D',
    pageCount: 1,
  },
  {
    id: 'local-06',
    title: 'Galaxy Notes',
    subtitle: 'CBZ - 21 chapters',
    chapterTitle: 'Chapter 15',
    fallbackProgressText: 'Chapter 15',
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
  if (progress.completed) return 'Finished'
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
  const customCategories = new Map()
  const categoryDisplayStrategies = new Map()
  const categoryErrorNameEmpty = 'Category name cannot be empty'
  const categoryErrorNameTooLong = 'Category name cannot exceed 40 characters'
  const categoryErrorNameBuiltin = 'Category name cannot match a built-in category'
  const categoryErrorNameDuplicate = 'Category name already exists'
  const categoryErrorMissing = 'Category does not exist'
  mockLibraryComics.forEach((item, index) => {
    const comic = createMockComic(item, index + 1)
    comics.set(comic.id, comic)
  })
  function cloneCategory(category) {
    return { ...category }
  }
  function validateCustomCategoryName(name, currentCategoryId) {
    const normalizedName = normalizeLibraryCategoryName(name)
    if (normalizedName.length === 0) throw new Error(categoryErrorNameEmpty)
    if (normalizedName.length > 40) throw new Error(categoryErrorNameTooLong)
    if (isBuiltInLibraryCategoryName(normalizedName)) throw new Error(categoryErrorNameBuiltin)
    const key = libraryCategoryNameKey(normalizedName)
    for (const category of customCategories.values()) {
      if (category.id !== currentCategoryId && libraryCategoryNameKey(category.name) === key) {
        throw new Error(categoryErrorNameDuplicate)
      }
    }
    return normalizedName
  }
  function validateRestoredCustomCategory(category, nextCategories, nameKeys) {
    if (!category.id.startsWith('custom_') || isBuiltInLibraryCategoryId(category.id)) {
      throw new Error('Invalid custom category id')
    }
    if (nextCategories.has(category.id)) {
      throw new Error('Duplicate custom category id')
    }
    const normalizedName = normalizeLibraryCategoryName(category.name)
    if (normalizedName.length === 0) throw new Error(categoryErrorNameEmpty)
    if (normalizedName.length > 40) throw new Error(categoryErrorNameTooLong)
    if (isBuiltInLibraryCategoryName(normalizedName)) throw new Error(categoryErrorNameBuiltin)
    const key = libraryCategoryNameKey(normalizedName)
    if (nameKeys.includes(key)) {
      throw new Error(categoryErrorNameDuplicate)
    }
    nameKeys.push(key)
    return { ...category, name: normalizedName }
  }
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
      customCategories.clear()
    },
    getComic(comicId) {
      return comics.get(comicId)
    },
    removeComic(comicId) {
      comics.delete(comicId)
    },
    listCustomCategories() {
      return Array.from(customCategories.values()).sort((a, b) => {
        const sortCompare = a.sortOrder - b.sortOrder
        return sortCompare !== 0 ? sortCompare : a.createdAt - b.createdAt
      }).map((category) => cloneCategory(category))
    },
    replaceCustomCategories(categories) {
      const nextCategories = new Map()
      const nameKeys = []
      for (const category of categories) {
        const restoredCategory = validateRestoredCustomCategory(category, nextCategories, nameKeys)
        nextCategories.set(restoredCategory.id, restoredCategory)
      }
      customCategories.clear()
      for (const [categoryId, category] of nextCategories) {
        customCategories.set(categoryId, cloneCategory(category))
      }
    },
    createCustomCategory(name, now = Date.now()) {
      const normalizedName = validateCustomCategoryName(name)
      const categories = this.listCustomCategories()
      const category = {
        id: `custom_${now}_${customCategories.size + 1}`,
        name: normalizedName,
        sortOrder: categories.length === 0 ? 0 : categories.at(-1).sortOrder + 1,
        createdAt: now,
        updatedAt: now,
      }
      customCategories.set(category.id, cloneCategory(category))
      return cloneCategory(category)
    },
    renameCustomCategory(categoryId, name, now = Date.now()) {
      const previous = customCategories.get(categoryId)
      if (previous === undefined) throw new Error(categoryErrorMissing)
      const normalizedName = validateCustomCategoryName(name, categoryId)
      const next = { ...previous, name: normalizedName, updatedAt: now }
      customCategories.set(categoryId, next)
      return cloneCategory(next)
    },
    deleteCustomCategory(categoryId) {
      if (isBuiltInLibraryCategoryId(categoryId)) return false
      if (!customCategories.has(categoryId)) return false
      customCategories.delete(categoryId)
      categoryDisplayStrategies.delete(categoryId)
      for (const [comicId, comic] of comics) {
        const before = normalizeCategoryIds(comic.categoryIds)
        const after = before.filter((item) => item !== categoryId)
        if (after.length !== before.length) {
          comics.set(comicId, withComicCategoryIds(comic, after))
        }
      }
      return true
    },
    listCategoryDisplayStrategies() {
      return Array.from(categoryDisplayStrategies.values()).map((strategy) => ({ ...strategy }))
    },
    getCategoryDisplayStrategy(categoryId) {
      const strategy = categoryDisplayStrategies.get(categoryId.trim())
      return strategy === undefined ? undefined : { ...strategy }
    },
    replaceCategoryDisplayStrategies(strategies) {
      categoryDisplayStrategies.clear()
      for (const strategy of strategies) {
        const nextStrategy = validateCategoryDisplayStrategy(strategy)
        categoryDisplayStrategies.set(nextStrategy.categoryId, { ...nextStrategy })
      }
    },
    setCategoryDisplayStrategy(strategy) {
      const nextStrategy = validateCategoryDisplayStrategy(strategy)
      categoryDisplayStrategies.set(nextStrategy.categoryId, { ...nextStrategy })
      return { ...nextStrategy }
    },
  }
}

function validateCategoryDisplayStrategy(strategy) {
  const categoryId = strategy.categoryId.trim()
  if (categoryId.length === 0) throw new Error('Invalid category display strategy categoryId')
  if (!['lastRead', 'added', 'title', 'source'].includes(strategy.sortBy)) {
    throw new Error('Invalid category display strategy sortBy')
  }
  if (!['all', 'unread', 'reading', 'completed'].includes(strategy.readState)) {
    throw new Error('Invalid category display strategy readState')
  }
  if (typeof strategy.updatedAt !== 'number' || !Number.isFinite(strategy.updatedAt)) {
    throw new Error('Invalid category display strategy updatedAt')
  }
  return {
    categoryId,
    sortBy: strategy.sortBy,
    readState: strategy.readState,
    updatedAt: strategy.updatedAt,
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
  const row = {
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
  if (chapter.scanlator !== undefined) row.scanlator = chapter.scanlator
  if (chapter.language !== undefined) row.language = chapter.language
  if (chapter.dateUpload !== undefined) row.dateUpload = chapter.dateUpload
  return row
}

function hydrateChapter(row) {
  assertValidPersistedChapter(row)
  const chapter = {
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
  if (row.scanlator !== undefined) chapter.scanlator = row.scanlator
  if (row.language !== undefined) chapter.language = row.language
  if (row.dateUpload !== undefined) chapter.dateUpload = row.dateUpload
  return chapter
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
  const document = {
    schemaVersion: 1,
    comics: store.listComics().map((item) => persistComic(item)),
  }
  const customCategories = store.listCustomCategories().map((category) => ({ ...category }))
  if (customCategories.length > 0) document.customCategories = customCategories
  const categoryDisplayStrategies = store.listCategoryDisplayStrategies().map((strategy) => ({ ...strategy }))
  if (categoryDisplayStrategies.length > 0) document.categoryDisplayStrategies = categoryDisplayStrategies
  return JSON.stringify(document)
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
  assertOptionalStringField(row.scanlator, 'chapter.scanlator')
  assertOptionalStringField(row.language, 'chapter.language')
  assertOptionalNumberField(row.dateUpload, 'chapter.dateUpload')
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

function assertValidPersistedLibraryCategory(row) {
  assertPersistedObject(row, 'category')
  assertStringField(row.id, 'category.id')
  assertStringField(row.name, 'category.name')
  assertNumberField(row.sortOrder, 'category.sortOrder')
  assertNumberField(row.createdAt, 'category.createdAt')
  assertNumberField(row.updatedAt, 'category.updatedAt')
  assertValidCustomCategoryShape(row)
}

function assertValidPersistedCategoryDisplayStrategy(row) {
  assertPersistedObject(row, 'categoryDisplayStrategy')
  assertStringField(row.categoryId, 'categoryDisplayStrategy.categoryId')
  if (!['lastRead', 'added', 'title', 'source'].includes(row.sortBy)) {
    throw new Error('Invalid library store persistence categoryDisplayStrategy.sortBy: expected library sort')
  }
  if (!['all', 'unread', 'reading', 'completed'].includes(row.readState)) {
    throw new Error('Invalid library store persistence categoryDisplayStrategy.readState: expected read-state filter')
  }
  assertNumberField(row.updatedAt, 'categoryDisplayStrategy.updatedAt')
}

function assertUniquePersistedCategoryDisplayStrategies(rows) {
  const categoryIds = []
  for (const row of rows) {
    const categoryId = row.categoryId.trim()
    if (categoryIds.includes(categoryId)) {
      throw new Error('Invalid library store persistence categoryDisplayStrategies: duplicate category id')
    }
    categoryIds.push(categoryId)
  }
}

function parseValidatedLibraryStoreDocument(payload) {
  const document = JSON.parse(payload)
  assertPersistedObject(document, 'document')
  assertSupportedLibraryStoreDocument(document)
  if (document.customCategories !== undefined && !Array.isArray(document.customCategories)) {
    throw new Error('Invalid library store persistence customCategories: expected array')
  }
  if (document.categoryDisplayStrategies !== undefined && !Array.isArray(document.categoryDisplayStrategies)) {
    throw new Error('Invalid library store persistence categoryDisplayStrategies: expected array')
  }
  if (!Array.isArray(document.comics)) {
    throw new Error('Invalid library store persistence comics: expected array')
  }
  document.customCategories?.forEach((row) => assertValidPersistedLibraryCategory(row))
  if (document.customCategories !== undefined) {
    assertUniquePersistedLibraryCategories(document.customCategories)
  }
  document.categoryDisplayStrategies?.forEach((row) => assertValidPersistedCategoryDisplayStrategy(row))
  if (document.categoryDisplayStrategies !== undefined) {
    assertUniquePersistedCategoryDisplayStrategies(document.categoryDisplayStrategies)
  }
  document.comics.forEach((row) => assertValidPersistedComic(row))
  return document
}

function hydrateLibraryStoreFromJson(store, payload) {
  const document = parseValidatedLibraryStoreDocument(payload)
  const customCategories = document.customCategories ?? []
  const categoryDisplayStrategies = document.categoryDisplayStrategies ?? []
  const comics = document.comics.map((row) => hydrateComic(row))
  store.clear()
  store.replaceCustomCategories(customCategories)
  store.replaceCategoryDisplayStrategies(categoryDisplayStrategies)
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

function updateComicCategoryMembershipAndPersistLibraryStore(store, persistenceService, comicIds, categoryId, selected) {
  const normalizedCategoryId = categoryId.trim()
  if (normalizedCategoryId.length === 0) return 0
  const previousPayload = serializeLibraryStore(store)
  let changedCount = 0
  comicIds.forEach((comicId) => {
    const comic = store.getComic(comicId)
    if (comic !== undefined) {
      store.upsertComic(selected ?
        withComicAddedCategoryId(comic, normalizedCategoryId) :
        withComicRemovedCategoryId(comic, normalizedCategoryId))
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

function createCustomCategoryAndPersistLibraryStore(store, persistenceService, name) {
  const previousPayload = serializeLibraryStore(store)
  const category = store.createCustomCategory(name)
  try {
    persistenceService.persist()
    return category
  } catch (error) {
    hydrateLibraryStoreFromJson(store, previousPayload)
    throw error
  }
}

function renameCustomCategoryAndPersistLibraryStore(store, persistenceService, categoryId, name) {
  const previousPayload = serializeLibraryStore(store)
  const category = store.renameCustomCategory(categoryId, name)
  try {
    persistenceService.persist()
    return category
  } catch (error) {
    hydrateLibraryStoreFromJson(store, previousPayload)
    throw error
  }
}

function deleteCustomCategoryAndPersistLibraryStore(store, persistenceService, categoryId) {
  const previousPayload = serializeLibraryStore(store)
  const deleted = store.deleteCustomCategory(categoryId)
  if (!deleted) return false
  try {
    persistenceService.persist()
    return true
  } catch (error) {
    hydrateLibraryStoreFromJson(store, previousPayload)
    throw error
  }
}

function setCategoryDisplayStrategyAndPersistLibraryStore(store, persistenceService, strategy) {
  const previousPayload = serializeLibraryStore(store)
  const savedStrategy = store.setCategoryDisplayStrategy(strategy)
  try {
    persistenceService.persist()
    return savedStrategy
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
      subtitle: presentation?.subtitle ?? comic.subtitle ?? `Local ZIP - ${comic.chapterCount} chapters`,
      progressText: formatLibraryProgressText(presentation ?? { fallbackProgressText: 'Unread' }, itemProgress),
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
      detail: continueProgress === undefined ? `Continue ${chapterTitle}` : `Continue ${chapterTitle} / Page ${continueProgress.pageIndex + 1} · ${progressPercent(continueProgress)}%`,
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
assert.equal(seededVm.comics.find((item) => item.id === 'local-01').title, 'Rain After Town')
assert.equal(seededVm.comics.find((item) => item.id === 'local-01').coverUri, 'mock://local-01/001.jpg')

const libraryVm = createLibraryViewModelFromStores(seededStore, new Map([[sessionProgress.comicId, sessionProgress]]), createPresentationMap())
assert.equal(libraryVm.continueReading.title, 'Rain After Town')
assert.equal(libraryVm.continueReading.detail, 'Continue Chapter 8 / Page 2 · 40%')
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
assert.equal(importedProgressVm.continueReading.detail, 'Continue Imported Volume / Page 2 · 67%')
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
assert.equal(updateComicCategoryMembershipAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], 'favorite', true), 1, 'adding a batch category should update existing comics')
assert.deepEqual(categoryStore.getComic('imported-01').categoryIds, ['read_later', 'favorite'], 'adding Favorite must preserve existing Read Later')
assert.equal(updateComicCategoryMembershipAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], 'favorite', false), 1, 'removing a batch category should update existing comics')
assert.deepEqual(categoryStore.getComic('imported-01').categoryIds, ['read_later'], 'removing Favorite must preserve existing Read Later')
assert.equal(assignComicCategoriesAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], undefined), 1, 'clear category assignment should update existing comics')
assert.equal(categoryStore.getComic('imported-01').categoryIds, undefined, 'clearing categories must return the comic to uncategorized')
assert.equal(listLibraryItemsByCategory(categoryStore, 'uncategorized').some((item) => item.id === 'imported-01'), true, 'uncategorized filter must include cleared comics')

const customCategory = createCustomCategoryAndPersistLibraryStore(categoryStore, categoryService, '  Favorites 2026  ')
assert.equal(customCategory.name, 'Favorites 2026', 'custom category creation must trim names')
assert.equal(categoryStore.listCustomCategories().length, 1, 'custom category creation must update the live store')
assert.equal(JSON.parse(categoryAdapter.savedPayloads.at(-1)).customCategories[0].name, 'Favorites 2026', 'custom category definitions must persist')
assert.throws(
  () => createCustomCategoryAndPersistLibraryStore(categoryStore, categoryService, 'Favorite'),
  /built-in category/,
  'custom categories must not collide with built-in category names',
)
assert.throws(
  () => createCustomCategoryAndPersistLibraryStore(categoryStore, categoryService, 'favorites 2026'),
  /already exists/,
  'custom categories must reject case-insensitive duplicate names',
)
assert.throws(
  () => createCustomCategoryAndPersistLibraryStore(categoryStore, categoryService, 'x'.repeat(41)),
  /cannot exceed 40/,
  'custom categories must reject overlong names',
)
assert.equal(updateComicCategoryMembershipAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], customCategory.id, true), 1, 'batch add must accept custom category ids')
assert.equal(updateComicCategoryMembershipAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], 'read_later', true), 1, 'batch add must still accept built-in Read Later')
assert.equal(updateComicCategoryMembershipAndPersistLibraryStore(categoryStore, categoryService, ['imported-01'], 'favorite', true), 1, 'batch add must still accept built-in Favorite')
assert.equal(listLibraryItemsByCategory(categoryStore, customCategory.id).some((item) => item.id === 'imported-01'), true, 'custom category filter must include matching comics')
const savedFavoriteStrategy = setCategoryDisplayStrategyAndPersistLibraryStore(categoryStore, categoryService, {
  categoryId: 'favorite',
  sortBy: 'title',
  readState: 'unread',
  updatedAt: 10,
})
assert.deepEqual(savedFavoriteStrategy, {
  categoryId: 'favorite',
  sortBy: 'title',
  readState: 'unread',
  updatedAt: 10,
}, 'built-in category display strategy must be saved with a stable category id')
setCategoryDisplayStrategyAndPersistLibraryStore(categoryStore, categoryService, {
  categoryId: customCategory.id,
  sortBy: 'added',
  readState: 'reading',
  updatedAt: 11,
})
assert.equal(categoryStore.getCategoryDisplayStrategy(customCategory.id).sortBy, 'added', 'custom category display strategy must update live store')
assert.equal(JSON.parse(categoryAdapter.savedPayloads.at(-1)).categoryDisplayStrategies.length, 2, 'category display strategies must persist beside category definitions')
const renamedCategory = renameCustomCategoryAndPersistLibraryStore(categoryStore, categoryService, customCategory.id, 'Owned')
assert.equal(renamedCategory.name, 'Owned', 'custom category rename must update the name')
assert.equal(deleteCustomCategoryAndPersistLibraryStore(categoryStore, categoryService, customCategory.id), true, 'custom category delete must report success')
assert.equal(categoryStore.listCustomCategories().length, 0, 'custom category delete must remove the definition')
assert.equal(categoryStore.getCategoryDisplayStrategy(customCategory.id), undefined, 'custom category delete must remove only that category display strategy')
assert.equal(categoryStore.getCategoryDisplayStrategy('favorite').sortBy, 'title', 'custom category delete must preserve built-in display strategies')
assert.equal(normalizeCategoryIds(categoryStore.getComic('imported-01').categoryIds).includes(customCategory.id), false, 'custom category delete must remove custom membership references')
assert.equal(normalizeCategoryIds(categoryStore.getComic('imported-01').categoryIds).includes('read_later'), true, 'custom category delete must preserve existing Read Later membership')
assert.equal(normalizeCategoryIds(categoryStore.getComic('imported-01').categoryIds).includes('favorite'), true, 'custom category delete must preserve existing Favorite membership')

const categoryRestoreStore = createSeededStore()
const categoryRestorePayload = categoryAdapter.savedPayloads.find((payload) => JSON.parse(payload).customCategories?.length === 1 && JSON.parse(payload).categoryDisplayStrategies?.length === 2)
hydrateLibraryStoreFromJson(categoryRestoreStore, categoryRestorePayload)
assert.equal(categoryRestoreStore.listCustomCategories()[0].name, 'Favorites 2026', 'custom categories must restore from persisted library JSON')
assert.equal(categoryRestoreStore.getCategoryDisplayStrategy('favorite').readState, 'unread', 'category display strategies must restore from persisted library JSON')
const maliciousBuiltInCategoryIdPayload = JSON.stringify({
  ...JSON.parse(categoryRestorePayload),
  customCategories: [{ id: 'favorite', name: 'Restored Favorite', sortOrder: 0, createdAt: 1, updatedAt: 1 }],
})
assert.throws(
  () => hydrateLibraryStoreFromJson(createSeededStore(), maliciousBuiltInCategoryIdPayload),
  /custom category id/,
  'restored custom categories must reject built-in category ids',
)
const maliciousBuiltInCategoryNamePayload = JSON.stringify({
  ...JSON.parse(categoryRestorePayload),
  customCategories: [{ id: 'custom_bad', name: 'Favorite', sortOrder: 0, createdAt: 1, updatedAt: 1 }],
})
assert.throws(
  () => hydrateLibraryStoreFromJson(createSeededStore(), maliciousBuiltInCategoryNamePayload),
  /built-in category/,
  'restored custom categories must reject built-in category names',
)
const duplicateCustomCategoryPayload = JSON.stringify({
  ...JSON.parse(categoryRestorePayload),
  customCategories: [
    { id: 'custom_one', name: 'Owned', sortOrder: 0, createdAt: 1, updatedAt: 1 },
    { id: 'custom_two', name: ' owned ', sortOrder: 1, createdAt: 2, updatedAt: 2 },
  ],
})
assert.throws(
  () => hydrateLibraryStoreFromJson(createSeededStore(), duplicateCustomCategoryPayload),
  /already exists|duplicate category name/,
  'restored custom categories must reject duplicate names',
)

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
assert.throws(
  () => createCustomCategoryAndPersistLibraryStore(throwingCategoryStore, throwingCategoryService, 'Rollback'),
  /disk full/,
  'save failure during custom category creation must be visible to the caller',
)
assert.equal(throwingCategoryStore.listCustomCategories().length, 0, 'failed custom category creation must rollback the live store')
assert.throws(
  () => setCategoryDisplayStrategyAndPersistLibraryStore(throwingCategoryStore, throwingCategoryService, {
    categoryId: 'favorite',
    sortBy: 'title',
    readState: 'unread',
    updatedAt: 12,
  }),
  /disk full/,
  'save failure during category display strategy update must be visible to the caller',
)
assert.equal(throwingCategoryStore.getCategoryDisplayStrategy('favorite'), undefined, 'failed category display strategy update must rollback the live store')

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
