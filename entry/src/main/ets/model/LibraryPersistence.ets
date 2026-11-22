import type { relationalStore } from '@kit.ArkData'
import { deviceSyncShelfSpace, signalDeviceSyncChange, signalDeviceSyncLibrary, SyncLibrarySignal,
  SyncLocalShelfMove } from '../deviceSync/DeviceSyncSignals'
import { syncShelfIdentity } from '../deviceSync/DeviceSyncData'
import { isSyncReplica } from '../deviceSync/DeviceSyncFacts'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { SourceTextOverlay, sourceTextOverlay } from './SourceTextOverlay'
import { SourceRequiredImageDecode, sourceRequiredImageDecode } from './SourceRequiredImageDecode'
import { enrichSourceChapterMetadata } from './SourceChapterMetadata'
import { sourceCatalogChapter } from './SourceLibraryComic'
import { SourceTextPage, sourceTextPage, SourceTextPageRequest, sourceTextPageRequest } from './SourceTextPageDescriptor'
import { MangaChapterItem, MangaDetail } from './MangaDetailModels'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ComicUpdateSchedule } from './ComicReleaseSchedule'
import { MihonImportRecord } from './MihonBackupReader'
import { LibrarySmartCategory, validateLibrarySmartCategories } from './LibrarySmartCategory'
import { writeAppTextFile } from './AppFileTextPersistence'
import { common } from '@kit.AbilityKit'
import { LibraryMembershipEdit, LibraryRdbStorage, LibraryReadingMetadata, LibraryShelfSyncEdits,
  LibraryShelfSyncImage } from './LibraryRdbStorage'
import { openUserDataDatabase } from './UserDataDatabase'
import {
  Chapter,
  Comic,
  ComicId,
  LocalImportOrigin,
  copyLocalImportOrigin,
  copyComicPersonalFields,
  assignComicSourceCover,
  copyComicUpdateSchedule,
  SourceMangaMetadata,
  copySourceMangaMetadata,
  ComicSourceKind,
  CustomLibraryCategory,
  LegacyLibraryCategory,
  LEGACY_LIBRARY_CATEGORIES,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH,
  Page,
  ReadingDirection,
  isManualLibraryCategoryId,
  libraryCategoryNameKey,
  normalizeCategoryIds,
  normalizeLibraryCategoryName,
  normalizeSortKey,
  setCompleteSourceChapterCatalog,
  withComicCategoryIds,
} from './ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { fileIo as fs } from '@kit.CoreFileKit'
import {
  isLibrarySortBy,
  LibraryCategoryDisplayStrategy,
  LibrarySortBy,
  LibrarySortDirection,
  LibraryStore,
} from './LibraryStore'
import {
  LocalLibraryStoredMetadata,
  normalizeLocalLibraryStoredMetadata,
} from './LocalLibraryMetadataService'
import {
  LocalLibraryFolderScanResult,
  LocalLibraryFolderSeries,
  bindLocalLibraryFolderScanIdentity,
  buildComicsFromLocalLibraryFolderScan,
  localLibraryFolderUri,
} from './LocalLibraryFolderContract'
import {
  LocalLibraryRescanFailure,
  LocalLibraryRescanSummary,
  createLocalLibraryRescanSummary,
} from './LocalLibraryRescanService'

export const LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION = 1
export const LIBRARY_STORE_PERSISTENCE_FILE_NAME = 'library-store.v1.json'

const liveLibraryStorage = new Map<string, LibraryRdbStorage>()

/** Open existing RDB before recovery. Import legacy data only after old journals have been recovered. */
export async function prepareLiveLibraryStorage(context: common.Context, migrate: boolean): Promise<void> {
  const prepared = liveLibraryStorage.get(context.filesDir)
  if (prepared !== undefined && !migrate) return
  const storage = prepared ?? new LibraryRdbStorage(await openUserDataDatabase(context))
  if (!storage.migrated()) {
    const previousDatabase = storage.usesPreviousDatabase()
    if (!previousDatabase && !migrate) return
    try {
      let document: PersistedLibraryStoreDocument | undefined
      if (!previousDatabase) {
        const legacyPath = context.filesDir + '/' + LIBRARY_STORE_PERSISTENCE_FILE_NAME
        if (await fs.access(legacyPath)) {
          document = parseValidatedLibraryStoreDocument(await fs.readText(legacyPath, { encoding: 'utf-8' }))
        }
      }
      await storage.migrate(document)
      DiagnosticLogger.info('persistence', 'library_rdb_migrated',
        previousDatabase ? 'source=database' : 'source=legacy_file')
    } catch (error) {
      DiagnosticLogger.exception('persistence', 'library_rdb_migration_failed', error as Error)
      throw error as Error
    }
  }
  if (migrate) {
    try {
      storage.migrateCategoryIds()
    } catch (error) {
      // The migration is atomic. Existing books remain readable if it cannot commit.
      DiagnosticLogger.exception('persistence', 'shelf_category_identity_migration_failed', error as Error)
    }
  }
  liveLibraryStorage.set(context.filesDir, storage)
}

export function usesLibraryDatabase(filesDir: string): boolean {
  return liveLibraryStorage.has(filesDir)
}

export function liveShelfCategoryAliases(filesDir: string): Map<string, string> | undefined {
  return liveLibraryStorage.get(filesDir)?.categoryAliases()
}

export function liveLibraryWriteRevision(filesDir: string): number | undefined {
  return liveLibraryStorage.get(filesDir)?.currentWriteRevision()
}

export function readLiveShelfSync(filesDir: string): PersistedLibraryStoreDocument | undefined {
  const document = liveLibraryStorage.get(filesDir)?.readShelfSync()
  return document === undefined ? undefined : withLegacyLibraryCategories(document)
}

export function readLiveShelfSyncWork(filesDir: string, comicId: string): PersistedComic | undefined {
  return liveLibraryStorage.get(filesDir)?.readWork(comicId, false)
}

export function commitLiveMihonCatalog(filesDir: string, record: MihonImportRecord, comic: Comic | undefined,
  stageReading: (transaction: relationalStore.Transaction) => Promise<void>): Promise<void> {
  const storage = liveLibraryStorage.get(filesDir)
  if (storage === undefined) throw new Error('shelf_database_unavailable')
  return storage.commitCatalogLink(record, comic === undefined ? undefined : persistComic(comic), stageReading)
}

export function saveLiveMihonSourceMatches(filesDir: string, records: MihonImportRecord[]): Promise<void> {
  const storage = liveLibraryStorage.get(filesDir)
  if (storage === undefined) throw new Error('shelf_database_unavailable')
  return storage.saveMihonSourceMatches(records)
}

export function writeLiveLibrarySyncEdits(filesDir: string, edits: LibraryShelfSyncEdits, image: LibraryShelfSyncImage): void {
  const storage = liveLibraryStorage.get(filesDir)
  if (storage === undefined) throw new Error('shelf_database_unavailable')
  storage.saveSyncEdits(edits, image)
}

/** Publish the rows already committed by WebDAV without reopening the library. */
export function applyLibraryShelfSyncEdits(filesDir: string, library: LibraryStore, edits: LibraryShelfSyncEdits): void {
  const image = edits.after
  if (image.categories !== undefined) library.replaceCustomCategories((image.categories ?? []).map(hydrateLibraryCategory))
  if (image.displayStrategies !== undefined) library.replaceCategoryDisplayStrategies(
    (image.displayStrategies ?? []).map(hydrateCategoryDisplayStrategy))
  if (image.smartCategories !== undefined) library.replaceSmartCategories(image.smartCategories ?? [], true)
  if (image.moves !== undefined) library.replaceSyncShelfMoves(image.moves ?? [])
  const changed = new Map<ComicId, PersistedComic>(image.works.map((work: PersistedComic): [ComicId, PersistedComic] => [work.id, work]))
  const unchangedCatalogs = new Set(edits.unchangedCatalogs)
  for (const id of edits.comicIds) {
    const work = changed.get(id)
    if (work === undefined) {
      library.removeComic(id)
    } else if (unchangedCatalogs.has(id)) {
      const old = library.getComic(id)
      if (old !== undefined) {
        const comic = hydrateComic(work)
        comic.chapters = old.chapters
        library.upsertComic(comic)
      } else {
        const stored = liveLibraryStorage.get(filesDir)?.readWork(id)
        if (stored !== undefined) library.upsertComic(hydrateComic(stored))
      }
    } else library.upsertComic(hydrateComic(work))
  }
  if (image.order !== undefined) library.orderComics(image.order)
}

/** Compatibility snapshot for backup and sync. The old JSON file becomes a read-only migration input. */
export function readLiveLibrarySnapshot(filesDir: string): string | undefined {
  const storage = liveLibraryStorage.get(filesDir)
  if (storage !== undefined) {
    const document = storage.read()
    return document === undefined ? undefined : JSON.stringify(document)
  }
  const path = filesDir + '/' + LIBRARY_STORE_PERSISTENCE_FILE_NAME
  return fs.accessSync(path) ? fs.readTextSync(path, { encoding: 'utf-8' }) : undefined
}

export function liveReadingMetadata(filesDir: string, comicId?: string, chapterId?: string): LibraryReadingMetadata[] {
  const storage = liveLibraryStorage.get(filesDir)
  if (storage === undefined) throw new Error('reading_shelf_database_unavailable')
  return storage.readReadingMetadata(comicId, chapterId)
}

export function writeLiveLibrarySnapshot(filesDir: string, payload?: string): void {
  const storage = liveLibraryStorage.get(filesDir)
  if (storage !== undefined) {
    storage.save(payload === undefined ? undefined : parseValidatedLibraryStoreDocument(payload))
    return
  }
  const path = filesDir + '/' + LIBRARY_STORE_PERSISTENCE_FILE_NAME
  if (payload !== undefined) writeAppTextFile(path, payload)
  else if (fs.accessSync(path)) fs.unlinkSync(path)
}

export interface PersistedLibraryStoreDocument {
  mihonImports?: MihonImportRecord[]
  syncShelfMoves?: SyncLocalShelfMove[]
  smartCategories?: LibrarySmartCategory[]
  schemaVersion: number
  customCategories?: PersistedLibraryCategory[]
  categoryDisplayStrategies?: PersistedCategoryDisplayStrategy[]
  comics: PersistedComic[]
}

export interface PersistedLibraryCategory {
  id: string
  name: string
  sortOrder: number
  createdAt: number
  updatedAt: number
  isPrivate?: boolean
}

export interface PersistedCategoryDisplayStrategy {
  categoryId: string
  sortBy: string
  sortDirection?: string
  followsDefaultSort?: boolean
  readState: string
  updatedAt: number
}

export interface PersistedComic {
  id: string
  title: string
  subtitle?: string
  author?: string
  categoryIds?: string[]
  sourceKind: ComicSourceKind
  sourcePath: string
  sourceRuntimeId?: string
  remoteServerId?: string
  remoteResourceId?: string
  coverUri?: string
  personalNotes?: string
  customCoverUri?: string
  sourceCoverUri?: string
  enhancedCoverUri?: string
  enhancedCoverModel?: string
  updateSchedule?: ComicUpdateSchedule
  localMetadata?: LocalLibraryStoredMetadata
  localImportOrigin?: LocalImportOrigin
  sourceMetadata?: SourceMangaMetadata
  sortTitle: string
  preferredDirection: ReadingDirection
  chapters: PersistedChapter[]
  chapterCount: number
  pageCount: number
  createdAt: number
  updatedAt: number
  lastImportedAt: number
}

export interface PersistedChapter {
  id: string
  comicId: string
  title: string
  index: number
  chapterNumber?: number
  volumeNumber?: string
  readingOrder?: number
  readingGroup?: string
  readingVariantGroup?: string
  readingVariantSequence?: string
  continuationEligible?: boolean
  scanlator?: string
  language?: string
  dateUpload?: number
  sourcePath: string
  sortKey: string
  pages: PersistedPage[]
  sourceSettingsFingerprint?: string
  pageCount: number
  createdAt: number
  updatedAt: number
}

export interface PersistedPage {
  id: string
  comicId: string
  chapterId: string
  index: number
  fileName: string
  uri: string
  sortKey: string
  width?: number
  height?: number
  byteSize?: number
  sourceText?: SourceTextPage
  sourceTextRequest?: SourceTextPageRequest
  sourceTextOverlay?: SourceTextOverlay
  requiredImageDecode?: SourceRequiredImageDecode
}

function persistPage(page: Page): PersistedPage {
  const row: PersistedPage = {
    id: page.id,
    comicId: page.comicId,
    chapterId: page.chapterId,
    index: page.index,
    fileName: page.fileName,
    uri: page.uri,
    sortKey: page.sortKey,
  }
  if (page.width !== undefined) {
    row.width = page.width
  }
  if (page.height !== undefined) {
    row.height = page.height
  }
  if (page.byteSize !== undefined) {
    row.byteSize = page.byteSize
  }
  if (page.sourceText !== undefined) row.sourceText = sourceTextPage(page.sourceText)
  if (page.sourceTextRequest !== undefined) row.sourceTextRequest = sourceTextPageRequest(page.sourceTextRequest)
  if (page.sourceTextOverlay !== undefined) row.sourceTextOverlay = sourceTextOverlay(page.sourceTextOverlay)
  if (page.requiredImageDecode !== undefined) row.requiredImageDecode = sourceRequiredImageDecode(page.requiredImageDecode)
  return row
}

function hydratePage(row: PersistedPage): Page {
  assertValidPersistedPage(row)
  const page: Page = {
    id: row.id,
    comicId: row.comicId,
    chapterId: row.chapterId,
    index: row.index,
    fileName: row.fileName,
    uri: row.uri,
    sortKey: row.sortKey,
  }
  if (row.width !== undefined) {
    page.width = row.width
  }
  if (row.height !== undefined) {
    page.height = row.height
  }
  if (row.byteSize !== undefined) {
    page.byteSize = row.byteSize
  }
  if (row.sourceText !== undefined) page.sourceText = sourceTextPage(row.sourceText)
  if (row.sourceTextRequest !== undefined) page.sourceTextRequest = sourceTextPageRequest(row.sourceTextRequest)
  if (row.sourceTextOverlay !== undefined) page.sourceTextOverlay = sourceTextOverlay(row.sourceTextOverlay)
  if (row.requiredImageDecode !== undefined) page.requiredImageDecode = sourceRequiredImageDecode(row.requiredImageDecode)
  return page
}

function persistChapter(chapter: Chapter): PersistedChapter {
  const row: PersistedChapter = {
    id: chapter.id,
    comicId: chapter.comicId,
    title: chapter.title,
    index: chapter.index,
    chapterNumber: chapter.chapterNumber,
    volumeNumber: chapter.volumeNumber,
    readingOrder: chapter.readingOrder,
    readingGroup: chapter.readingGroup,
    readingVariantGroup: chapter.readingVariantGroup,
    readingVariantSequence: chapter.readingVariantSequence,
    continuationEligible: chapter.continuationEligible,
    sourcePath: chapter.sourcePath,
    sortKey: chapter.sortKey,
    pages: chapter.pages.map((page: Page) => persistPage(page)),
    sourceSettingsFingerprint: chapter.sourceSettingsFingerprint,
    pageCount: chapter.pageCount,
    createdAt: chapter.createdAt,
    updatedAt: chapter.updatedAt,
  }
  if (chapter.scanlator !== undefined) {
    row.scanlator = chapter.scanlator
  }
  if (chapter.language !== undefined) {
    row.language = chapter.language
  }
  if (chapter.dateUpload !== undefined) {
    row.dateUpload = chapter.dateUpload
  }
  return row
}

function hydrateChapter(row: PersistedChapter, isMihonPlaceholder: boolean): Chapter {
  assertValidPersistedChapter(row, isMihonPlaceholder)
  const pages = row.pages.map((page: PersistedPage) => hydratePage(page))
  const chapter: Chapter = {
    id: row.id,
    comicId: row.comicId,
    title: row.title,
    index: row.index,
    chapterNumber: row.chapterNumber,
    volumeNumber: row.volumeNumber,
    readingOrder: row.readingOrder,
    readingGroup: row.readingGroup,
    readingVariantGroup: row.readingVariantGroup,
    readingVariantSequence: row.readingVariantSequence,
    continuationEligible: row.continuationEligible,
    sourcePath: row.sourcePath,
    sortKey: row.sortKey,
    pages,
    sourceSettingsFingerprint: row.sourceSettingsFingerprint,
    pageCount: row.pageCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  }
  if (row.scanlator !== undefined) {
    chapter.scanlator = row.scanlator
  }
  if (row.language !== undefined) {
    chapter.language = row.language
  }
  if (row.dateUpload !== undefined) {
    chapter.dateUpload = row.dateUpload
  }
  return chapter
}

export function persistComic(comic: Comic): PersistedComic {
  const row: PersistedComic = {
    personalNotes: comic.personalNotes, customCoverUri: comic.customCoverUri, sourceCoverUri: comic.sourceCoverUri,
    enhancedCoverUri: comic.enhancedCoverUri, enhancedCoverModel: comic.enhancedCoverModel,
    updateSchedule: comic.updateSchedule,
    id: comic.id,
    title: comic.title,
    sourceKind: comic.sourceKind,
    sourcePath: comic.sourcePath,
    sortTitle: comic.sortTitle,
    preferredDirection: comic.preferredDirection,
    chapters: comic.chapters.map((chapter: Chapter) => persistChapter(chapter)),
    chapterCount: comic.chapterCount,
    pageCount: comic.pageCount,
    createdAt: comic.createdAt,
    updatedAt: comic.updatedAt,
    lastImportedAt: comic.lastImportedAt,
  }
  if (comic.subtitle !== undefined) {
    row.subtitle = comic.subtitle
  }
  if (comic.author !== undefined) {
    row.author = comic.author
  }
  const categoryIds = normalizeCategoryIds(comic.categoryIds)
  if (categoryIds.length > 0) {
    row.categoryIds = categoryIds
  }
  if (comic.sourceRuntimeId !== undefined) {
    row.sourceRuntimeId = comic.sourceRuntimeId
  }
  if (comic.remoteServerId !== undefined) {
    row.remoteServerId = comic.remoteServerId
  }
  if (comic.remoteResourceId !== undefined) {
    row.remoteResourceId = comic.remoteResourceId
  }
  if (comic.coverUri !== undefined) {
    row.coverUri = comic.coverUri
  }
  if (comic.localImportOrigin !== undefined) {
    row.localImportOrigin = copyLocalImportOrigin(comic.localImportOrigin)
  }
  if (comic.localMetadata !== undefined) {
    row.localMetadata = normalizeLocalLibraryStoredMetadata(comic.localMetadata as Object)
  }
  if (comic.sourceMetadata !== undefined) {
    row.sourceMetadata = copySourceMangaMetadata(comic.sourceMetadata)
  }
  return row
}

export function hydrateComic(row: PersistedComic): Comic {
  assertValidPersistedComic(row)
  const isMihonPlaceholder = row.sourceRuntimeId?.startsWith('mihon:') === true
  const chapters = row.chapters.map((chapter: PersistedChapter) => hydrateChapter(chapter, isMihonPlaceholder))
  const comic: Comic = {
    personalNotes: row.personalNotes, customCoverUri: row.customCoverUri, sourceCoverUri: row.sourceCoverUri,
    enhancedCoverUri: row.enhancedCoverUri, enhancedCoverModel: row.enhancedCoverModel,
    updateSchedule: row.updateSchedule,
    id: row.id,
    title: row.title,
    sourceKind: row.sourceKind,
    sourcePath: row.sourcePath,
    sortTitle: row.sortTitle,
    preferredDirection: row.preferredDirection,
    chapters,
    chapterCount: row.chapterCount,
    pageCount: row.pageCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    lastImportedAt: row.lastImportedAt,
  }
  if (row.subtitle !== undefined) {
    comic.subtitle = row.subtitle
  }
  if (row.author !== undefined) {
    comic.author = row.author
  }
  const categoryIds = normalizeCategoryIds(row.categoryIds)
  if (categoryIds.length > 0) {
    comic.categoryIds = categoryIds
  }
  if (row.sourceRuntimeId !== undefined) {
    comic.sourceRuntimeId = row.sourceRuntimeId
  }
  if (row.remoteServerId !== undefined) {
    comic.remoteServerId = row.remoteServerId
  }
  if (row.remoteResourceId !== undefined) {
    comic.remoteResourceId = row.remoteResourceId
  }
  if (row.coverUri !== undefined) {
    comic.coverUri = row.coverUri
  }
  if (row.localImportOrigin !== undefined) {
    comic.localImportOrigin = copyLocalImportOrigin(row.localImportOrigin)
  }
  if (row.localMetadata !== undefined) {
    comic.localMetadata = normalizeLocalLibraryStoredMetadata(row.localMetadata as Object)
  }
  if (row.sourceMetadata !== undefined) {
    comic.sourceMetadata = copySourceMangaMetadata(row.sourceMetadata)
  }
  return comic
}

export function createLibraryStorePersistenceDocument(libraryStore: LibraryStore): PersistedLibraryStoreDocument {
  const document: PersistedLibraryStoreDocument = {
    schemaVersion: LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION,
    comics: libraryStore.listComics().map((comic: Comic) => persistComic(comic)),
  }
  const customCategories = libraryStore.listCustomCategories().map((category: CustomLibraryCategory): PersistedLibraryCategory => {
    return persistLibraryCategory(category)
  })
  if (customCategories.length > 0) {
    document.customCategories = customCategories
  }
  const smartCategories = libraryStore.listSmartCategories()
  if (smartCategories.length > 0) document.smartCategories = smartCategories
  const categoryDisplayStrategies = libraryStore.listCategoryDisplayStrategies().map((strategy: LibraryCategoryDisplayStrategy): PersistedCategoryDisplayStrategy => {
    return persistCategoryDisplayStrategy(strategy)
  })
  if (categoryDisplayStrategies.length > 0) {
    document.categoryDisplayStrategies = categoryDisplayStrategies
  }
  const moves = libraryStore.listSyncShelfMoves()
  if (moves.length > 0) document.syncShelfMoves = moves
  const mihonImports = libraryStore.listMihonImports()
  if (mihonImports.length > 0) document.mihonImports = mihonImports
  return document
}

export function serializeLibraryStore(libraryStore: LibraryStore): string {
  return JSON.stringify(createLibraryStorePersistenceDocument(libraryStore))
}

export function replaceSmartCategoriesAndPersistLibraryStore(libraryStore: LibraryStore,
  persistence: LibraryStorePersistenceService, categories: LibrarySmartCategory[]): void {
  saveCategoryChange(libraryStore, persistence, 'smart', (): void => { libraryStore.replaceSmartCategories(categories) })
}

function assertSupportedLibraryStoreDocument(document: PersistedLibraryStoreDocument): void {
  if (document.schemaVersion !== LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION) {
    throw new Error(`Unsupported library store persistence schema version: ${document.schemaVersion}`)
  }
}

function assertPersistedObject(value: Object | null, label: string): void {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected object`)
  }
}

function assertStringField(value: string | undefined, label: string): void {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Invalid library store persistence ${label}: expected non-empty string`)
  }
}

function assertOptionalStringField(value: string | undefined, label: string): void {
  if (value !== undefined && typeof value !== 'string') {
    throw new Error(`Invalid library store persistence ${label}: expected string`)
  }
}

function assertOptionalStringArrayField(value: string[] | undefined, label: string): void {
  if (value === undefined) {
    return
  }
  if (!Array.isArray(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected string array`)
  }
  value.forEach((item: string, index: number) => {
    assertStringField(item, `${label}.${index}`)
  })
}

function assertNumberField(value: number | undefined, label: string): void {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected finite number`)
  }
}

function assertOptionalNumberField(value: number | undefined, label: string): void {
  if (value !== undefined && (typeof value !== 'number' || !Number.isFinite(value))) {
    throw new Error(`Invalid library store persistence ${label}: expected finite number`)
  }
}

function assertComicSourceKind(value: ComicSourceKind | undefined, label: string): void {
  if (
    value !== ComicSourceKind.LOCAL_ARCHIVE &&
    value !== ComicSourceKind.LOCAL_FOLDER &&
    value !== ComicSourceKind.PRIVATE_LIBRARY &&
    value !== ComicSourceKind.KOMGA_REMOTE &&
    value !== ComicSourceKind.KAVITA_REMOTE &&
    value !== ComicSourceKind.OPDS_REMOTE &&
    value !== ComicSourceKind.WEBDAV_REMOTE
  ) {
    throw new Error(`Invalid library store persistence ${label}: expected comic source kind`)
  }
}

function assertReadingDirection(value: ReadingDirection | undefined, label: string): void {
  if (
    value !== ReadingDirection.LEFT_TO_RIGHT &&
    value !== ReadingDirection.RIGHT_TO_LEFT &&
    value !== ReadingDirection.WEBTOON
  ) {
    throw new Error(`Invalid library store persistence ${label}: expected reading direction`)
  }
}

function assertLibrarySortBy(value: string | undefined, label: string): void {
  if (!isLibrarySortBy(value)) {
    throw new Error(`Invalid library store persistence ${label}: expected library sort`)
  }
}

function assertLibraryReadState(value: string | undefined, label: string): void {
  if (value !== 'all' && value !== 'unread' && value !== 'reading' && value !== 'completed') {
    throw new Error(`Invalid library store persistence ${label}: expected read-state filter`)
  }
}

function assertValidPersistedPage(row: PersistedPage): void {
  assertPersistedObject(row as Object, 'page')
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

function assertValidPersistedChapter(row: PersistedChapter, isMihonPlaceholder: boolean): void {
  assertPersistedObject(row as Object, 'chapter')
  assertStringField(row.id, 'chapter.id')
  assertStringField(row.comicId, 'chapter.comicId')
  // An unmatched Mihon chapter can have only its local ID and reading facts.
  // Keep blank metadata as exported, including in a library saved by 1.5.0.
  if (!isMihonPlaceholder || row.title !== '') {
    assertStringField(row.title, 'chapter.title')
  }
  assertNumberField(row.index, 'chapter.index')
  assertOptionalNumberField(row.chapterNumber, 'chapter.chapterNumber')
  assertOptionalStringField(row.volumeNumber, 'chapter.volumeNumber')
  assertOptionalNumberField(row.readingOrder, 'chapter.readingOrder')
  assertOptionalStringField(row.readingGroup, 'chapter.readingGroup')
  assertOptionalStringField(row.readingVariantGroup, 'chapter.readingVariantGroup')
  assertOptionalStringField(row.readingVariantSequence, 'chapter.readingVariantSequence')
  if (row.continuationEligible !== undefined && typeof row.continuationEligible !== 'boolean') {
    throw new Error('Invalid library store persistence chapter.continuationEligible: expected boolean')
  }
  assertOptionalStringField(row.scanlator, 'chapter.scanlator')
  assertOptionalStringField(row.language, 'chapter.language')
  assertOptionalNumberField(row.dateUpload, 'chapter.dateUpload')
  if (!isMihonPlaceholder || row.sourcePath !== '') {
    assertStringField(row.sourcePath, 'chapter.sourcePath')
  }
  assertStringField(row.sortKey, 'chapter.sortKey')
  assertOptionalStringField(row.sourceSettingsFingerprint, 'chapter.sourceSettingsFingerprint')
  if (!Array.isArray(row.pages)) {
    throw new Error('Invalid library store persistence chapter.pages: expected array')
  }
  assertNumberField(row.pageCount, 'chapter.pageCount')
  assertNumberField(row.createdAt, 'chapter.createdAt')
  assertNumberField(row.updatedAt, 'chapter.updatedAt')
}

function assertValidPersistedComic(row: PersistedComic): void {
  assertPersistedObject(row as Object, 'comic')
  assertStringField(row.id, 'comic.id')
  assertStringField(row.title, 'comic.title')
  assertOptionalStringField(row.subtitle, 'comic.subtitle')
  assertOptionalStringField(row.author, 'comic.author')
  assertOptionalStringArrayField(row.categoryIds, 'comic.categoryIds')
  assertComicSourceKind(row.sourceKind, 'comic.sourceKind')
  assertStringField(row.sourcePath, 'comic.sourcePath')
  assertOptionalStringField(row.sourceRuntimeId, 'comic.sourceRuntimeId')
  assertOptionalStringField(row.remoteServerId, 'comic.remoteServerId')
  assertOptionalStringField(row.remoteResourceId, 'comic.remoteResourceId')
  assertOptionalStringField(row.coverUri, 'comic.coverUri')
  assertOptionalStringField(row.personalNotes, 'comic.personalNotes')
  assertOptionalStringField(row.customCoverUri, 'comic.customCoverUri')
  assertOptionalStringField(row.sourceCoverUri, 'comic.sourceCoverUri')
  assertOptionalStringField(row.enhancedCoverUri, 'comic.enhancedCoverUri')
  assertOptionalStringField(row.enhancedCoverModel, 'comic.enhancedCoverModel')
  if (row.updateSchedule !== undefined) {
    assertPersistedObject(row.updateSchedule as Object, 'comic.updateSchedule')
    assertNumberField(row.updateSchedule.intervalDays, 'comic.updateSchedule.intervalDays')
    assertNumberField(row.updateSchedule.nextCheckAt, 'comic.updateSchedule.nextCheckAt')
  }
  if (row.sourceMetadata !== undefined) {
    const metadata = row.sourceMetadata
    assertOptionalStringField(metadata.sourceName, 'comic.sourceMetadata.sourceName')
    assertOptionalStringField(metadata.contentRating, 'comic.sourceMetadata.contentRating')
    assertPersistedObject(metadata as Object, 'comic.sourceMetadata')
    assertOptionalStringField(metadata.artist, 'comic.sourceMetadata.artist')
    assertOptionalStringField(metadata.status, 'comic.sourceMetadata.status')
    assertOptionalStringField(metadata.webUrl, 'comic.sourceMetadata.webUrl')
    assertOptionalStringField(metadata.settingsFingerprint, 'comic.sourceMetadata.settingsFingerprint')
    assertOptionalStringArrayField(metadata.tags, 'comic.sourceMetadata.tags')
    assertOptionalStringArrayField(metadata.excludedChapterIds, 'comic.sourceMetadata.excludedChapterIds')
    assertOptionalStringArrayField(metadata.sharedChapterIds, 'comic.sourceMetadata.sharedChapterIds')
    if (metadata.chapterCatalogUpdatedAt !== undefined) {
      assertNumberField(metadata.chapterCatalogUpdatedAt, 'comic.sourceMetadata.chapterCatalogUpdatedAt')
    }
  }
  if (row.localImportOrigin !== undefined) {
    copyLocalImportOrigin(row.localImportOrigin)
  }
  if (row.localMetadata !== undefined) {
    normalizeLocalLibraryStoredMetadata(row.localMetadata as Object)
  }
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

function persistLibraryCategory(category: CustomLibraryCategory): PersistedLibraryCategory {
  return {
    id: category.id,
    name: category.name,
    sortOrder: category.sortOrder,
    createdAt: category.createdAt,
    updatedAt: category.updatedAt,
    isPrivate: category.isPrivate,
  }
}

function hydrateLibraryCategory(row: PersistedLibraryCategory): CustomLibraryCategory {
  assertValidPersistedLibraryCategory(row)
  return {
    id: row.id,
    name: row.name,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isPrivate: row.isPrivate,
  }
}

function assertValidPersistedLibraryCategory(row: PersistedLibraryCategory): void {
  assertPersistedObject(row as Object, 'category')
  assertStringField(row.id, 'category.id')
  assertStringField(row.name, 'category.name')
  assertNumberField(row.sortOrder, 'category.sortOrder')
  assertNumberField(row.createdAt, 'category.createdAt')
  assertNumberField(row.updatedAt, 'category.updatedAt')
  if (row.isPrivate !== undefined && typeof row.isPrivate !== 'boolean') {
    throw new Error('Invalid library store persistence category.isPrivate: expected boolean')
  }
  if (!isManualLibraryCategoryId(row.id)) {
    throw new Error('Invalid library store persistence category.id: expected custom category id')
  }
  const normalizedName = normalizeLibraryCategoryName(row.name)
  if (normalizedName.length === 0) {
    throw new Error('Invalid library store persistence category.name: expected non-empty name')
  }
  if (normalizedName.length > LIBRARY_CATEGORY_NAME_MAX_LENGTH) {
    throw new Error(`Invalid library store persistence category.name: expected at most ${LIBRARY_CATEGORY_NAME_MAX_LENGTH} characters`)
  }
}

function assertUniquePersistedLibraryCategories(rows: PersistedLibraryCategory[]): void {
  // Memberships refer to the ID. A cloud or backup record with a colliding
  // label must remain loadable without dropping either category or its books.
  const ids = new Set<string>()
  rows.forEach((row: PersistedLibraryCategory) => {
    if (ids.has(row.id)) {
      throw new Error('Invalid library store persistence customCategories: duplicate category id')
    }
    ids.add(row.id)
  })
}

function persistCategoryDisplayStrategy(strategy: LibraryCategoryDisplayStrategy): PersistedCategoryDisplayStrategy {
  return {
    categoryId: strategy.categoryId,
    sortBy: strategy.sortBy,
    sortDirection: strategy.sortDirection,
    followsDefaultSort: strategy.followsDefaultSort,
    readState: strategy.readState,
    updatedAt: strategy.updatedAt,
  }
}

function hydrateCategoryDisplayStrategy(row: PersistedCategoryDisplayStrategy): LibraryCategoryDisplayStrategy {
  assertValidPersistedCategoryDisplayStrategy(row)
  return {
    categoryId: row.categoryId,
    sortBy: row.sortBy as LibrarySortBy,
    sortDirection: row.sortDirection as LibrarySortDirection | undefined,
    followsDefaultSort: row.followsDefaultSort,
    readState: row.readState as 'all' | 'unread' | 'reading' | 'completed',
    updatedAt: row.updatedAt,
  }
}

function assertValidPersistedCategoryDisplayStrategy(row: PersistedCategoryDisplayStrategy): void {
  assertPersistedObject(row as Object, 'categoryDisplayStrategy')
  assertStringField(row.categoryId, 'categoryDisplayStrategy.categoryId')
  if (row.categoryId.trim().length === 0) {
    throw new Error('Invalid library store persistence categoryDisplayStrategy.categoryId: expected non-empty category id')
  }
  assertLibrarySortBy(row.sortBy, 'categoryDisplayStrategy.sortBy')
  if (row.sortDirection !== undefined && row.sortDirection !== 'asc' && row.sortDirection !== 'desc') {
    throw new Error('Invalid library store persistence categoryDisplayStrategy.sortDirection')
  }
  if (row.followsDefaultSort !== undefined && typeof row.followsDefaultSort !== 'boolean') {
    throw new Error('Invalid library store persistence categoryDisplayStrategy.followsDefaultSort')
  }
  assertLibraryReadState(row.readState, 'categoryDisplayStrategy.readState')
  assertNumberField(row.updatedAt, 'categoryDisplayStrategy.updatedAt')
}

function assertUniquePersistedCategoryDisplayStrategies(rows: PersistedCategoryDisplayStrategy[]): void {
  const categoryIds: string[] = []
  rows.forEach((row: PersistedCategoryDisplayStrategy) => {
    const categoryId = row.categoryId.trim()
    if (categoryIds.includes(categoryId)) {
      throw new Error('Invalid library store persistence categoryDisplayStrategies: duplicate category id')
    }
    categoryIds.push(categoryId)
  })
}

function parseValidatedLibraryStoreDocument(payload: string): PersistedLibraryStoreDocument {
  const document = JSON.parse(payload) as PersistedLibraryStoreDocument
  validateLibraryStoreDocument(document)
  return document
}

function validateLibraryStoreDocument(document: PersistedLibraryStoreDocument): void {
  assertPersistedObject(document as Object, 'document')
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
  if (document.smartCategories !== undefined) {
    if (!Array.isArray(document.smartCategories)) throw new Error('Invalid library smart categories')
    validateLibrarySmartCategories(document.smartCategories,
      (document.customCategories ?? []).map((category: PersistedLibraryCategory): string => category.name), true)
  }
  if (document.customCategories !== undefined) {
    document.customCategories.forEach((row: PersistedLibraryCategory) => {
      assertValidPersistedLibraryCategory(row)
    })
    assertUniquePersistedLibraryCategories(document.customCategories)
  }
  if (document.categoryDisplayStrategies !== undefined) {
    document.categoryDisplayStrategies.forEach((row: PersistedCategoryDisplayStrategy) => {
      assertValidPersistedCategoryDisplayStrategy(row)
    })
    assertUniquePersistedCategoryDisplayStrategies(document.categoryDisplayStrategies)
  }
  document.comics.forEach((row: PersistedComic) => {
    assertValidPersistedComic(row)
  })
  if (document.syncShelfMoves !== undefined && (!Array.isArray(document.syncShelfMoves) ||
    document.syncShelfMoves.some((move: SyncLocalShelfMove): boolean => !move || !isSyncReplica(move.space) ||
      !syncShelfIdentity(move.source, move.work) || (move.target !== undefined && (!move.target ||
        !syncShelfIdentity(move.target.toSource, move.target.toWork) ||
        move.source === move.target.toSource && move.work === move.target.toWork))))) {
    throw new Error('Invalid library store persistence syncShelfMoves')
  }
  if (document.mihonImports !== undefined && (!Array.isArray(document.mihonImports) ||
    document.mihonImports.some((row: MihonImportRecord): boolean => !row || typeof row.id !== 'string' ||
      typeof row.sourceName !== 'string' || !row.work || typeof row.work.sourceId !== 'string' ||
      typeof row.work.url !== 'string' || !Array.isArray(row.categoryIds) ||
      (row.matchedSourceId !== undefined && typeof row.matchedSourceId !== 'string') ||
      (row.linkedWork !== undefined && (!row.linkedWork || typeof row.linkedWork.id !== 'string' ||
        typeof row.linkedWork.sourceId !== 'string' || typeof row.linkedWork.title !== 'string')) ||
      !Array.isArray(row.work.chapters) || !Array.isArray(row.work.history) ||
      !Array.isArray(row.work.tracking) || !Array.isArray(row.work.genres) || !Array.isArray(row.work.categoryIds)))) {
    throw new Error('Invalid library store persistence mihonImports')
  }
}

export function assertValidLibraryStoreJson(payload: string): void {
  parseValidatedLibraryStoreDocument(payload)
}

export function libraryStoreBackupPayload(payload: string): string {
  const document = parseValidatedLibraryStoreDocument(payload)
  // Pending replacements belong to this WebDAV space and this installation.
  if (document.syncShelfMoves === undefined) return payload
  document.syncShelfMoves = undefined
  return JSON.stringify(document)
}

export function readLibraryStoreDocument(payload: string): PersistedLibraryStoreDocument {
  return withLegacyLibraryCategories(parseValidatedLibraryStoreDocument(payload))
}

function withLegacyLibraryCategories(document: PersistedLibraryStoreDocument): PersistedLibraryStoreDocument {
  const categories = document.customCategories ?? []
  const names = new Set<string>(categories.map((category: PersistedLibraryCategory): string => libraryCategoryNameKey(category.name)))
  document.smartCategories?.forEach((category: LibrarySmartCategory): void => {
    names.add(libraryCategoryNameKey(category.name))
  })
  let nextOrder = categories.reduce((next: number, category: PersistedLibraryCategory): number =>
    Math.max(next, category.sortOrder + 1), 0)
  // Old shelves stored preset memberships without category records. Promote
  // used IDs to ordinary editable records, including when reading an old backup.
  LEGACY_LIBRARY_CATEGORIES.forEach((legacy: LegacyLibraryCategory): void => {
    if (categories.some((category: PersistedLibraryCategory): boolean => category.id === legacy.id)) return
    const strategy = document.categoryDisplayStrategies?.find((item: PersistedCategoryDisplayStrategy): boolean =>
      item.categoryId === legacy.id)
    if (strategy === undefined && !document.comics.some((comic: PersistedComic): boolean =>
      normalizeCategoryIds(comic.categoryIds).includes(legacy.id))) return
    const label = AppStrings.get(legacy.nameKey)
    let name = label
    let suffix = 2
    while (names.has(libraryCategoryNameKey(name))) {
      name = label + ' (' + suffix++ + ')'
    }
    names.add(libraryCategoryNameKey(name))
    categories.push({ id: legacy.id, name, sortOrder: nextOrder++, createdAt: 0, updatedAt: strategy?.updatedAt ?? 0 })
  })
  if (categories.length > 0) document.customCategories = categories
  return document
}

export function hydrateLibraryStoreFromJson(libraryStore: LibraryStore, payload: string): void {
  hydrateLibraryStoreFromDocument(libraryStore, readLibraryStoreDocument(payload))
}

function hydrateLibraryStoreFromDocument(libraryStore: LibraryStore, document: PersistedLibraryStoreDocument): void {
  const customCategories = document.customCategories === undefined ? [] : document.customCategories.map((row: PersistedLibraryCategory) => {
    return hydrateLibraryCategory(row)
  })
  const categoryDisplayStrategies = document.categoryDisplayStrategies === undefined ? [] : document.categoryDisplayStrategies.map((row: PersistedCategoryDisplayStrategy) => {
    return hydrateCategoryDisplayStrategy(row)
  })
  const comics = document.comics.map((row: PersistedComic) => hydrateComic(row))
  libraryStore.clear()
  libraryStore.replaceCustomCategories(customCategories)
  libraryStore.replaceSmartCategories(document.smartCategories ?? [], true)
  libraryStore.replaceCategoryDisplayStrategies(categoryDisplayStrategies)
  comics.forEach((comic: Comic) => {
    libraryStore.upsertComic(comic)
  })
  libraryStore.replaceSyncShelfMoves(document.syncShelfMoves ?? [])
  libraryStore.replaceMihonImports(document.mihonImports ?? [])
}

export interface LibraryStorePersistenceAdapter {
  databaseForEdits?(): LibraryRdbStorage | undefined
  load(): string | undefined
  save(payload: string): void
  loadForRestore?(): PersistedLibraryStoreDocument | string | undefined
  loadWorksForRestore?(comicIds: ComicId[]): PersistedComic[] | undefined
  saveDocument?(document: PersistedLibraryStoreDocument): void
  saveExistingWorks?(comics: PersistedComic[]): boolean
  saveMemberships?(edits: LibraryMembershipEdit[]): boolean
}

function joinLibraryPersistencePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  if (left.length === 0) {
    return right
  }
  return `${left}/${right}`
}

export class AppFilesLibraryStorePersistenceAdapter implements LibraryStorePersistenceAdapter {
  private readonly filePath: string
  private readonly libraryDirectory?: string

  constructor(filesDir: string, fileName: string = LIBRARY_STORE_PERSISTENCE_FILE_NAME) {
    this.filePath = joinLibraryPersistencePath(filesDir, fileName)
    if (fileName === LIBRARY_STORE_PERSISTENCE_FILE_NAME) this.libraryDirectory = filesDir
  }

  load(): string | undefined {
    if (this.libraryDirectory !== undefined) return readLiveLibrarySnapshot(this.libraryDirectory)
    if (!fs.accessSync(this.filePath)) {
      return undefined
    }
    return fs.readTextSync(this.filePath, { encoding: 'utf-8' })
  }

  loadForRestore(): PersistedLibraryStoreDocument | string | undefined {
    const database = this.libraryDirectory === undefined ? undefined : liveLibraryStorage.get(this.libraryDirectory)
    return database === undefined ? this.load() : database.read()
  }

  loadWorksForRestore(comicIds: ComicId[]): PersistedComic[] | undefined {
    const database = this.libraryDirectory === undefined ? undefined : liveLibraryStorage.get(this.libraryDirectory)
    if (database === undefined) return undefined
    const works: PersistedComic[] = []
    comicIds.forEach((id: ComicId): void => {
      const work = database.readWork(id)
      if (work !== undefined) works.push(work)
    })
    return works
  }

  databaseForEdits(): LibraryRdbStorage | undefined {
    if (this.libraryDirectory === undefined) return undefined
    return liveLibraryStorage.get(this.libraryDirectory)
  }

  save(payload: string): void {
    if (BackupRestoreActivity.hasPendingRecovery()) {
      throw new Error('sync_local_busy')
    }
    if (this.libraryDirectory !== undefined) writeLiveLibrarySnapshot(this.libraryDirectory, payload)
    else writeAppTextFile(this.filePath, payload)
    signalDeviceSyncChange('shelf')
  }

  saveDocument(document: PersistedLibraryStoreDocument): void {
    const database = this.libraryDirectory === undefined ? undefined : liveLibraryStorage.get(this.libraryDirectory)
    if (database === undefined) {
      this.save(JSON.stringify(document))
      return
    }
    if (BackupRestoreActivity.hasPendingRecovery()) throw new Error('sync_local_busy')
    database.save(document)
    signalDeviceSyncChange('shelf')
  }

  saveExistingWorks(comics: PersistedComic[]): boolean {
    const database = this.libraryDirectory === undefined ? undefined : liveLibraryStorage.get(this.libraryDirectory)
    if (database === undefined) return false
    if (BackupRestoreActivity.hasPendingRecovery()) throw new Error('sync_local_busy')
    database.saveExistingWorks(comics)
    signalDeviceSyncChange('shelf')
    return true
  }

  saveMemberships(edits: LibraryMembershipEdit[]): boolean {
    const database = this.libraryDirectory === undefined ? undefined : liveLibraryStorage.get(this.libraryDirectory)
    if (database === undefined) return false
    if (BackupRestoreActivity.hasPendingRecovery()) throw new Error('sync_local_busy')
    database.saveMemberships(edits)
    signalDeviceSyncChange('shelf')
    return true
  }
}

export class LibraryStorePersistenceService {
  private libraryStore: LibraryStore
  private adapter: LibraryStorePersistenceAdapter

  constructor(libraryStore: LibraryStore, adapter: LibraryStorePersistenceAdapter) {
    this.libraryStore = libraryStore
    this.adapter = adapter
  }

  restore(): void {
    const saved = this.adapter.loadForRestore === undefined ? this.adapter.load() : this.adapter.loadForRestore()
    if (typeof saved === 'string') {
      if (saved.length > 0) hydrateLibraryStoreFromJson(this.libraryStore, saved)
    } else if (saved !== undefined) {
      // Normal RDB reads consume the decoded rows directly. The exchange
      // format stays at backup, legacy file, and sync boundaries.
      validateLibraryStoreDocument(saved)
      hydrateLibraryStoreFromDocument(this.libraryStore, withLegacyLibraryCategories(saved))
    }
  }

  persist(): void {
    try {
      if (this.adapter.saveDocument !== undefined) {
        this.adapter.saveDocument(createLibraryStorePersistenceDocument(this.libraryStore))
      } else {
        this.adapter.save(serializeLibraryStore(this.libraryStore))
      }
      DiagnosticLogger.debug('persistence', 'library_saved', 'saved=true')
    } catch (error) {
      DiagnosticLogger.exception('persistence', 'library_save_failed', error as Error)
      throw error as Error
    }
  }

  persistExistingWorks(comics: Comic[]): void {
    if (this.adapter.saveExistingWorks?.(comics.map((comic: Comic): PersistedComic => persistComic(comic))) !== true) {
      this.persist()
    }
  }

  databaseForEdits(): LibraryRdbStorage | undefined {
    const database = this.adapter.databaseForEdits?.()
    if (database !== undefined && BackupRestoreActivity.hasPendingRecovery()) throw new Error('sync_local_busy')
    return database
  }

  restoreFailedWorkUpdates(previous: Comic[]): void {
    // Remote checks can span local edits. After a rolled-back transaction,
    // the still-committed rows include edits saved during the network requests.
    const saved = this.adapter.loadWorksForRestore?.(previous.map((comic: Comic): ComicId => comic.id))
    if (saved === undefined) {
      previous.forEach((comic: Comic): void => { this.libraryStore.upsertComic(comic) })
      return
    }
    const byId = new Map<ComicId, PersistedComic>(saved.map((comic: PersistedComic): [ComicId, PersistedComic] => [comic.id, comic]))
    previous.forEach((comic: Comic): void => {
      const restored = byId.get(comic.id)
      if (restored === undefined) this.libraryStore.removeComic(comic.id)
      else this.libraryStore.upsertComic(hydrateComic(restored))
    })
  }

  persistMemberships(comics: Comic[]): void {
    const edits = comics.map((comic: Comic): LibraryMembershipEdit => ({
      comicId: comic.id, categoryIds: comic.categoryIds, updatedAt: comic.updatedAt,
    }))
    if (this.adapter.saveMemberships?.(edits) !== true) this.persistExistingWorks(comics)
  }
}

export function isRemovableLocalComic(comic: Comic | undefined): boolean {
  if (comic === undefined) {
    return false
  }
  if (comic.sourcePath.startsWith('mock://')) {
    return false
  }
  return comic.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || comic.sourceKind === ComicSourceKind.LOCAL_FOLDER
}

export function isRemovableShelfComic(comic: Comic | undefined): boolean {
  return isRemovableLocalComic(comic) || (comic !== undefined &&
    comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY && (comic.sourceRuntimeId?.trim() ?? '').length > 0)
}

export function upsertComicAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comic: Comic
): void {
  const previousComic = libraryStore.getComic(comic.id)
  // The RDB keeps the existing row's storage order. A refreshed title or
  // creation date is re-sorted by the presentation without saving other works.
  if (previousComic !== undefined) {
    libraryStore.upsertComic(comic)
    try {
      persistenceService.persistExistingWorks([comic])
    } catch (error) {
      libraryStore.upsertComic(previousComic)
      throw error as Error
    }
    return
  }
  const previousMoves = libraryStore.listSyncShelfMoves()
  const moves = previousMoves.filter((move: SyncLocalShelfMove): boolean =>
    move.source !== comic.sourceRuntimeId || move.work !== comic.remoteResourceId)
  const database = persistenceService.databaseForEdits?.()
  if (database !== undefined) {
    database.saveLocalEdits({ present: true, works: [persistComic(comic)],
      moves: moves.length === previousMoves.length ? undefined : moves.length === 0 ? null : moves })
    libraryStore.addComic(comic)
    libraryStore.replaceSyncShelfMoves(moves)
    signalDeviceSyncChange('shelf')
  } else {
    const previous = serializeLibraryStore(libraryStore)
    libraryStore.addComic(comic)
    libraryStore.replaceSyncShelfMoves(moves)
    try { persistenceService.persist() } catch (error) {
      hydrateLibraryStoreFromJson(libraryStore, previous)
      throw error as Error
    }
  }
  if (comic.sourceRuntimeId !== undefined && comic.remoteResourceId !== undefined) {
    const edits: SyncLibrarySignal[] = [{ kind: 'add-book', source: comic.sourceRuntimeId, work: comic.remoteResourceId }]
    edits.push(...syncLibraryMembershipChanges(comic, normalizeCategoryIds(comic.categoryIds), []))
    signalDeviceSyncLibrary(edits)
  }
}

/** Save the last known public name before uninstalling a source. The library
 * remains the owner; one transaction preserves chapters, downloads and progress.
 * Old backups without this field still load without inventing a source name. */
export function retainLibrarySourceNameAndPersist(
  libraryStore: LibraryStore, persistence: LibraryStorePersistenceService,
  sourceId: string, sourceName: string,
): boolean {
  const name = sourceName.trim()
  if (name.length === 0) return false
  const changed = libraryStore.listComics().filter((comic: Comic): boolean =>
    comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY && comic.sourceRuntimeId === sourceId &&
    comic.sourceMetadata?.sourceName !== name)
  if (changed.length === 0) return false
  const previous = serializeLibraryStore(libraryStore)
  changed.forEach((comic: Comic): void => {
    const next = JSON.parse(JSON.stringify(comic)) as Comic
    next.sourceMetadata = next.sourceMetadata ?? {}
    next.sourceMetadata.sourceName = name
    libraryStore.addComic(next)
  })
  try { persistence.persist() } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previous)
    throw error as Error
  }
  return true
}

/** Refresh only the cover of an already-collected source work, keeping user state and ordering. */
export function refreshSourceComicCoverAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: string,
  sourceId: string,
  mangaId: string,
  coverUri: string | undefined,
): boolean {
  const cover = coverUri?.trim() ?? ''
  const previous = libraryStore.getComic(comicId)
  if (previous === undefined || previous.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY ||
    previous.sourceRuntimeId !== sourceId || previous.remoteResourceId !== mangaId ||
    !/^https?:\/\//i.test(cover) || (previous.customCoverUri ? previous.sourceCoverUri : previous.coverUri) === cover) {
    return false
  }
  // Clone the latest owner value, not the detail snapshot: chapter/progress/category fields stay intact.
  const next = JSON.parse(JSON.stringify(previous)) as Comic
  assignComicSourceCover(next, cover)
  upsertComicAndPersistLibraryStore(libraryStore, persistenceService, next)
  return true
}

/** Refresh a collected detail in one library transaction. Work identity and all
 * user-owned fields come from the latest library value, never a route snapshot.
 * Repeated equal responses do not rewrite the library or publish shelf rows.
 */
export function refreshSourceMangaDetailAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: string,
  sourceId: string,
  mangaId: string,
  detail: MangaDetail,
  chapters: MangaChapterItem[],
  chaptersResolved: boolean,
  excludedChapterIds: string[],
  settingsFingerprint: string,
): boolean {
  const previous = libraryStore.getComic(comicId)
  if (previous === undefined || previous.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY ||
    previous.sourceRuntimeId !== sourceId || previous.remoteResourceId !== mangaId) return false
  const next = updatedSourceMangaDetail(previous, detail, chapters, chaptersResolved, excludedChapterIds,
    settingsFingerprint)
  if (JSON.stringify(next) === JSON.stringify(previous)) return false
  upsertComicAndPersistLibraryStore(libraryStore, persistenceService, next)
  return true
}

/** Also used by the Mihon worker to write a freshly linked catalog in its existing transaction. */
export function updatedSourceMangaDetail(previous: Comic, detail: MangaDetail, chapters: MangaChapterItem[],
  chaptersResolved: boolean, excludedChapterIds: string[], settingsFingerprint: string): Comic {
  const next = JSON.parse(JSON.stringify(previous)) as Comic
  if (detail.title.trim().length > 0) {
    next.title = detail.title
    next.sortTitle = normalizeSortKey(detail.title)
  }
  next.subtitle = detail.description
  next.author = detail.author
  if (/^https?:\/\//i.test(detail.coverUrl?.trim() ?? '')) assignComicSourceCover(next, detail.coverUrl!)
  next.sourceMetadata = {
    sourceName: detail.sourceName?.trim() || previous.sourceMetadata?.sourceName,
    contentRating: detail.contentRating ?? previous.sourceMetadata?.contentRating,
    artist: detail.artist,
    status: detail.status !== undefined && detail.status !== 'unknown' ? detail.status : previous.sourceMetadata?.status,
    tags: detail.tags?.slice(),
    webUrl: detail.webUrl,
    excludedChapterIds: chaptersResolved ? excludedChapterIds.slice() : previous.sourceMetadata?.excludedChapterIds,
    settingsFingerprint: chaptersResolved ? settingsFingerprint : previous.sourceMetadata?.settingsFingerprint,
    sharedChapterIds: previous.sourceMetadata?.sharedChapterIds?.slice(),
    chapterCatalogUpdatedAt: previous.sourceMetadata?.chapterCatalogUpdatedAt,
  }
  if (chaptersResolved) {
    // The shared IDs can arrive before this device has any chapter rows.
    // Persist missing rows in the same transaction so a cold open can show
    // the catalog. Existing rows keep their pages and locally owned fields.
    const now = Date.now()
    const storedIds = new Set<string>(next.chapters.map((chapter: Chapter): string => chapter.id))
    const excluded = new Set<string>(excludedChapterIds)
    chapters.forEach((chapter: MangaChapterItem): void => {
      if (storedIds.has(chapter.id) || excluded.has(chapter.id)) return
      const stored = sourceCatalogChapter(chapter, next.id, next.sourcePath, next.chapters.length, now)
      next.chapters.push(stored)
      next.pageCount += stored.pageCount
      storedIds.add(chapter.id)
    })
    enrichSourceChapterMetadata(next, chapters)
    setCompleteSourceChapterCatalog(next, chapters.map((chapter: MangaChapterItem): string => chapter.id), now)
  }
  return next
}

/** Persist metadata for matching stored chapters only, without adding/removing chapters or replacing reading state. */
export function refreshSourceChapterMetadataAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: string,
  sourceId: string,
  mangaId: string,
  chapters: MangaChapterItem[],
): boolean {
  const previous = libraryStore.getComic(comicId)
  if (previous === undefined || previous.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY ||
    previous.sourceRuntimeId !== sourceId || previous.remoteResourceId !== mangaId || chapters.length === 0) return false
  const next = JSON.parse(JSON.stringify(previous)) as Comic
  if (!enrichSourceChapterMetadata(next, chapters)) return false
  upsertComicAndPersistLibraryStore(libraryStore, persistenceService, next)
  return true
}

function localFolderSeriesRelativePath(comic: Comic): string | undefined {
  const remoteResourceId = comic.remoteResourceId
  if (remoteResourceId === undefined) {
    return undefined
  }
  const separatorIndex = remoteResourceId.indexOf(':')
  if (separatorIndex < 0 || separatorIndex >= remoteResourceId.length - 1) {
    return undefined
  }
  return remoteResourceId.substring(separatorIndex + 1)
}

function localFolderRootUri(comic: Comic): string | undefined {
  const seriesRelativePath = localFolderSeriesRelativePath(comic)
  if (seriesRelativePath === undefined) {
    return undefined
  }
  const encodedSeriesPath = seriesRelativePath.split('/').map((segment: string): string => encodeURIComponent(segment)).join('/')
  const suffix = `/${encodedSeriesPath}`
  if (!comic.sourcePath.endsWith(suffix)) {
    return undefined
  }
  const rootUri = comic.sourcePath.substring(0, comic.sourcePath.length - suffix.length)
  return rootUri.length === 0 ? undefined : rootUri
}

function localFolderCoverUri(comic: Comic, coverOverridePath: string | undefined): string | undefined {
  if (coverOverridePath === undefined || comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER) {
    return undefined
  }
  const seriesRelativePath = localFolderSeriesRelativePath(comic)
  const rootUri = localFolderRootUri(comic)
  if (seriesRelativePath === undefined || rootUri === undefined) {
    return undefined
  }
  return localLibraryFolderUri(rootUri, `${seriesRelativePath}/${coverOverridePath}`)
}

export function updateLocalLibraryMetadataAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: ComicId,
  metadataInput: LocalLibraryStoredMetadata
): Comic | undefined {
  const previous = libraryStore.getComic(comicId)
  if (previous === undefined ||
    (previous.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE && previous.sourceKind !== ComicSourceKind.LOCAL_FOLDER)) {
    return undefined
  }
  const normalized = normalizeLocalLibraryStoredMetadata(metadataInput as Object) ?? {}
  const next: Comic = {
    id: previous.id,
    title: previous.title,
    sourceKind: previous.sourceKind,
    sourcePath: previous.sourcePath,
    sortTitle: previous.sortTitle,
    preferredDirection: previous.preferredDirection,
    chapters: previous.chapters,
    chapterCount: previous.chapterCount,
    pageCount: previous.pageCount,
    createdAt: previous.createdAt,
    updatedAt: Date.now(),
    lastImportedAt: previous.lastImportedAt,
  }
  if (previous.subtitle !== undefined) {
    next.subtitle = previous.subtitle
  }
  if (previous.author !== undefined) {
    next.author = previous.author
  }
  const categoryIds = normalizeCategoryIds(previous.categoryIds)
  if (categoryIds.length > 0) {
    next.categoryIds = categoryIds
  }
  if (previous.sourceRuntimeId !== undefined) {
    next.sourceRuntimeId = previous.sourceRuntimeId
  }
  if (previous.remoteServerId !== undefined) {
    next.remoteServerId = previous.remoteServerId
  }
  if (previous.remoteResourceId !== undefined) {
    next.remoteResourceId = previous.remoteResourceId
  }
  if (previous.coverUri !== undefined) {
    next.coverUri = previous.coverUri
  }
  if (previous.localImportOrigin !== undefined) {
    next.localImportOrigin = copyLocalImportOrigin(previous.localImportOrigin)
  }
  if (previous.localMetadata !== undefined) {
    next.localMetadata = previous.localMetadata
  }
  if (previous.sourceMetadata !== undefined) {
    next.sourceMetadata = copySourceMangaMetadata(previous.sourceMetadata)
  }
  copyComicPersonalFields(previous, next)
  copyComicUpdateSchedule(previous, next)
  next.localMetadata = normalized
  if (normalized.titleOverride !== undefined) {
    next.title = normalized.titleOverride
    next.sortTitle = normalizeSortKey(normalized.titleOverride)
  }
  if (normalized.authors !== undefined) {
    next.author = normalized.authors.join(', ')
  } else if (previous.localMetadata?.authors !== undefined) {
    next.author = undefined
  }
  const coverUri = localFolderCoverUri(previous, normalized.coverOverridePath)
  if (coverUri !== undefined) {
    next.coverUri = coverUri
  } else if (previous.localMetadata?.coverOverridePath !== undefined && normalized.coverOverridePath === undefined) {
    next.coverUri = undefined
  }

  const previousPayload = serializeLibraryStore(libraryStore)
  libraryStore.upsertComic(next)
  try {
    persistenceService.persist()
    return next
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}

export function upsertLocalLibraryFolderScanAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  scanResult: LocalLibraryFolderScanResult,
  rootUri: string,
  now: number = Date.now()
): number {
  const boundScan = bindLocalLibraryFolderScanIdentity(scanResult, rootUri, libraryStore.listComics())
  const comics = buildComicsFromLocalLibraryFolderScan(boundScan, rootUri, now)
  if (comics.length === 0) {
    return 0
  }
  const previousPayload = serializeLibraryStore(libraryStore)
  comics.forEach((comic: Comic) => {
    libraryStore.upsertComic(comic)
  })
  try {
    persistenceService.persist()
    return comics.length
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}

export interface LocalLibraryFolderRescanPersistResult {
  summary: LocalLibraryRescanSummary
  upsertedCount: number
}

function mergeLocalLibraryRescanComic(previous: Comic | undefined, fresh: Comic): Comic {
  if (previous === undefined) {
    return fresh
  }
  const merged: Comic = {
    id: fresh.id,
    title: fresh.title,
    sourceKind: fresh.sourceKind,
    sourcePath: fresh.sourcePath,
    sortTitle: fresh.sortTitle,
    preferredDirection: fresh.preferredDirection,
    chapters: fresh.chapters,
    chapterCount: fresh.chapterCount,
    pageCount: fresh.pageCount,
    createdAt: previous.createdAt,
    updatedAt: fresh.updatedAt,
    lastImportedAt: fresh.lastImportedAt,
  }
  if (fresh.subtitle !== undefined) {
    merged.subtitle = fresh.subtitle
  }
  if (fresh.author !== undefined) {
    merged.author = fresh.author
  }
  const shouldPreservePreviousLocalMetadata = fresh.localMetadata === undefined && previous.localMetadata !== undefined
  if (shouldPreservePreviousLocalMetadata) {
    merged.title = previous.title
    merged.sortTitle = previous.sortTitle
    if (previous.author !== undefined) {
      merged.author = previous.author
    }
    if (previous.coverUri !== undefined) {
      merged.coverUri = previous.coverUri
    }
    merged.localMetadata = previous.localMetadata
  }
  const categoryIds = normalizeCategoryIds(previous.categoryIds)
  if (categoryIds.length > 0) {
    merged.categoryIds = categoryIds
  }
  if (fresh.sourceRuntimeId !== undefined) {
    merged.sourceRuntimeId = fresh.sourceRuntimeId
  }
  if (fresh.remoteServerId !== undefined) {
    merged.remoteServerId = fresh.remoteServerId
  }
  if (fresh.remoteResourceId !== undefined) {
    merged.remoteResourceId = fresh.remoteResourceId
  }
  if (fresh.coverUri !== undefined && !shouldPreservePreviousLocalMetadata) {
    merged.coverUri = fresh.coverUri
  }
  if (fresh.localMetadata !== undefined) {
    merged.localMetadata = fresh.localMetadata
  }
  const sourceMetadata = fresh.sourceMetadata ?? previous.sourceMetadata
  if (sourceMetadata !== undefined) {
    merged.sourceMetadata = copySourceMangaMetadata(sourceMetadata)
  }
  copyComicPersonalFields(previous, merged)
  copyComicUpdateSchedule(previous, merged)
  return merged
}

export function upsertLocalLibraryFolderRescanAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  previousKnownSeries: LocalLibraryFolderSeries[],
  freshScan: LocalLibraryFolderScanResult,
  rootUri: string,
  failures: LocalLibraryRescanFailure[] = [],
  now: number = Date.now()
): LocalLibraryFolderRescanPersistResult {
  const boundScan = bindLocalLibraryFolderScanIdentity(freshScan, rootUri, libraryStore.listComics())
  const summary = createLocalLibraryRescanSummary(previousKnownSeries, boundScan, failures)
  const changedSeriesIds = new Set<string>()
  summary.outcomes.forEach((outcome) => {
    if (outcome.status === 'added' || outcome.status === 'changed') {
      changedSeriesIds.add(outcome.id)
    }
  })
  const comics = buildComicsFromLocalLibraryFolderScan(boundScan, rootUri, now)
    .filter((comic: Comic): boolean => changedSeriesIds.has(comic.id))
  if (comics.length === 0) {
    return { summary, upsertedCount: 0 }
  }
  const previousPayload = serializeLibraryStore(libraryStore)
  comics.forEach((comic: Comic) => {
    libraryStore.upsertComic(mergeLocalLibraryRescanComic(libraryStore.getComic(comic.id), comic))
  })
  try {
    persistenceService.persist()
    return { summary, upsertedCount: comics.length }
  } catch (error) {
    hydrateLibraryStoreFromJson(libraryStore, previousPayload)
    throw error as Error
  }
}

function syncLibraryMembershipChanges(comic: Comic, next: string[], before: string[] = comic.categoryIds ?? []): SyncLibrarySignal[] {
  if (comic.sourceRuntimeId === undefined || comic.remoteResourceId === undefined) return []
  const removed = before.filter((key: string): boolean => !next.includes(key))
  const added = next.filter((key: string): boolean => !before.includes(key))
  const actions: SyncLibrarySignal[] = []
  removed.forEach((category: string): void => {
    actions.push({ kind: 'remove-member', source: comic.sourceRuntimeId, work: comic.remoteResourceId, category })
  })
  added.forEach((category: string): void => {
    actions.push({ kind: 'add-member', source: comic.sourceRuntimeId, work: comic.remoteResourceId, category })
  })
  return actions
}

export function editComicCategoriesAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService | undefined,
  comicIds: ComicId[],
  addedCategoryIds: string[],
  removedCategoryIds: string[],
): number {
  const known = new Set<string>(libraryStore.listCustomCategories().map((category: CustomLibraryCategory): string => category.id))
  const added = normalizeCategoryIds(addedCategoryIds).filter((id: string): boolean => known.has(id))
  const removed = new Set<string>(normalizeCategoryIds(removedCategoryIds))
  const previous: Comic[] = []
  const edits: Comic[] = []
  const syncEdits: SyncLibrarySignal[] = []
  // A mixed row left untouched keeps each book's own membership. Apply only
  // explicit changes against the latest records and persist them together.
  new Set<ComicId>(comicIds).forEach((comicId: ComicId): void => {
    const comic = libraryStore.getComic(comicId)
    if (comic === undefined) return
    const before = normalizeCategoryIds(comic.categoryIds)
    const next = before.filter((id: string): boolean => !removed.has(id))
    added.forEach((id: string): void => { if (!next.includes(id)) next.push(id) })
    if (before.length === next.length && before.every((id: string): boolean => next.includes(id))) return
    syncEdits.push(...syncLibraryMembershipChanges(comic, next))
    previous.push(comic)
    edits.push(withComicCategoryIds(comic, next))
  })
  if (edits.length === 0) return 0
  edits.forEach((comic: Comic): void => { libraryStore.upsertComic(comic) })
  if (persistenceService === undefined) return edits.length
  try {
    persistenceService.persistMemberships(edits)
    signalDeviceSyncLibrary(syncEdits)
    return edits.length
  } catch (error) {
    previous.forEach((comic: Comic): void => { libraryStore.upsertComic(comic) })
    throw error as Error
  }
}

function saveCategoryChange<T>(library: LibraryStore, persistence: LibraryStorePersistenceService,
  kind: 'custom' | 'smart' | 'display', change: (memberIds?: string[]) => T, removedId?: string): T {
  const database = persistence.databaseForEdits?.()
  if (database === undefined) {
    const previous = serializeLibraryStore(library)
    const result = change()
    if (result === false) return result
    try { persistence.persist() } catch (error) {
      hydrateLibraryStoreFromJson(library, previous)
      throw error as Error
    }
    return result
  }
  const categoriesBefore = kind === 'custom' ? library.listCustomCategories() : undefined
  const smartBefore = kind === 'smart' ? library.listSmartCategories() : undefined
  const strategiesBefore = kind !== 'custom' || removedId !== undefined ? library.listCategoryDisplayStrategies() : undefined
  const memberIds = removedId === undefined ? [] : database.categoryMemberIds(removedId)
  const membersBefore: Comic[] = []
  for (const id of memberIds) {
    const comic = library.getComic(id)
    if (comic !== undefined) membersBefore.push(comic)
  }
  const result = change(memberIds)
  if (result === false) return result
  try {
    const image: LibraryShelfSyncImage = { present: true, works: [] }
    if (categoriesBefore !== undefined) {
      const categories = library.listCustomCategories().map(persistLibraryCategory)
      image.categories = categories.length === 0 ? null : categories
    }
    if (smartBefore !== undefined) {
      const smart = library.listSmartCategories()
      image.smartCategories = smart.length === 0 ? null : smart
    }
    if (strategiesBefore !== undefined) {
      const strategies = library.listCategoryDisplayStrategies().map(persistCategoryDisplayStrategy)
      image.displayStrategies = strategies.length === 0 ? null : strategies
    }
    const memberships: LibraryMembershipEdit[] = []
    for (const before of membersBefore) {
      const comic = library.getComic(before.id)
      if (comic !== undefined && comic !== before) {
        memberships.push({ comicId: comic.id, categoryIds: comic.categoryIds, updatedAt: comic.updatedAt })
      }
    }
    database.saveLocalEdits(image, [], memberships)
  } catch (error) {
    if (categoriesBefore !== undefined) library.replaceCustomCategories(categoriesBefore)
    if (smartBefore !== undefined) library.replaceSmartCategories(smartBefore, true)
    if (strategiesBefore !== undefined) library.replaceCategoryDisplayStrategies(strategiesBefore)
    for (const comic of membersBefore) library.upsertComic(comic)
    throw error as Error
  }
  signalDeviceSyncChange('shelf')
  return result
}

export function createCustomCategoryAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  name: string
): CustomLibraryCategory {
  return saveCategoryChange(libraryStore, persistenceService, 'custom', () => libraryStore.createCustomCategory(name))
}

export function renameCustomCategoryAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  categoryId: string,
  name: string
): CustomLibraryCategory {
  return saveCategoryChange(libraryStore, persistenceService, 'custom',
    () => libraryStore.renameCustomCategory(categoryId, name))
}

export function setCustomCategoryPrivacyAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistence: LibraryStorePersistenceService,
  categoryId: string,
  isPrivate: boolean,
): boolean {
  if (!saveCategoryChange(libraryStore, persistence, 'custom',
    () => libraryStore.setCustomCategoryPrivacy(categoryId, isPrivate))) return false
  signalDeviceSyncLibrary([{ kind: 'category-privacy', category: categoryId, isPrivate }])
  return true
}

export function moveCustomCategoryAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  categoryId: string,
  destinationId: string,
): boolean {
  return saveCategoryChange(libraryStore, persistenceService, 'custom',
    () => libraryStore.moveCustomCategory(categoryId, destinationId))
}

export function deleteCustomCategoryAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  categoryId: string
): boolean {
  if (!saveCategoryChange(libraryStore, persistenceService, 'custom',
    (members?: string[]): boolean => libraryStore.deleteCustomCategory(categoryId, members), categoryId)) return false
  signalDeviceSyncLibrary([{ kind: 'remove-category', category: categoryId }])
  return true
}

export function setCategoryDisplayStrategyAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  strategy: LibraryCategoryDisplayStrategy
): LibraryCategoryDisplayStrategy {
  return saveCategoryChange(libraryStore, persistenceService, 'display', () => libraryStore.setCategoryDisplayStrategy(strategy))
}

function removeShelfWorks(library: LibraryStore, persistence: LibraryStorePersistenceService,
  ids: ComicId[], moves?: SyncLocalShelfMove[]): void {
  const database = persistence.databaseForEdits?.()
  const payload = database === undefined ? serializeLibraryStore(library) : undefined
  if (database !== undefined) {
    database.saveLocalEdits({ present: true, works: [], moves: moves === undefined ? undefined : moves.length ? moves : null }, ids)
  }
  if (moves !== undefined) library.replaceSyncShelfMoves(moves)
  for (const id of ids) library.removeComic(id)
  if (payload !== undefined) {
    try { persistence.persist() } catch (error) {
      hydrateLibraryStoreFromJson(library, payload)
      throw error as Error
    }
  } else {
    signalDeviceSyncChange('shelf')
  }
}

export function removeComicAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: ComicId
): boolean {
  const comic = libraryStore.getComic(comicId)
  if (!isRemovableLocalComic(comic)) {
    return false
  }
  removeShelfWorks(libraryStore, persistenceService, [comicId])
  return true
}

/**
 * Remove a shelf record without deleting its source files, downloaded pages,
 * or any external-library data. This is for an explicit membership toggle,
 * not the local-file removal flow above.
 */
export function removeComicRecordAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicId: ComicId,
  migrationTarget?: Comic,
): boolean {
  const removedComic = libraryStore.getComic(comicId)
  if (removedComic === undefined) {
    return false
  }
  const space = migrationTarget === undefined ? undefined : deviceSyncShelfSpace()
  const fromSource = removedComic.sourceRuntimeId
  const fromWork = removedComic.remoteResourceId
  let moves: SyncLocalShelfMove[] | undefined
  if (space !== undefined && fromSource !== undefined && fromWork !== undefined && syncShelfIdentity(fromSource, fromWork)) {
    const toSource = migrationTarget?.sourceRuntimeId
    const toWork = migrationTarget?.remoteResourceId
    const move: SyncLocalShelfMove = { space, source: fromSource, work: fromWork,
      target: toSource !== undefined && toWork !== undefined && syncShelfIdentity(toSource, toWork) ?
        { toSource, toWork } : undefined }
    // Record the replacement in the same transaction that removes the original.
    // An unsyncable destination must never turn a migration into a bare delete.
    moves = libraryStore.listSyncShelfMoves().filter((item: SyncLocalShelfMove): boolean =>
      item.source !== fromSource || item.work !== fromWork).concat(move)
  }
  removeShelfWorks(libraryStore, persistenceService, [comicId], moves)
  if (migrationTarget === undefined && fromSource !== undefined && fromWork !== undefined) {
    signalDeviceSyncLibrary([{ kind: 'remove-book', source: fromSource, work: fromWork }])
  }
  return true
}

export function removeComicsAndPersistLibraryStore(
  libraryStore: LibraryStore,
  persistenceService: LibraryStorePersistenceService,
  comicIds: ComicId[]
): ComicId[] {
  const removedIds: ComicId[] = []
  const syncEdits: SyncLibrarySignal[] = []
  comicIds.forEach((comicId: ComicId) => {
    if (removedIds.includes(comicId)) {
      return
    }
    const comic = libraryStore.getComic(comicId)
    if (comic === undefined || !isRemovableShelfComic(comic)) return
    removedIds.push(comicId)
    if (comic.sourceRuntimeId !== undefined && comic.remoteResourceId !== undefined) {
      syncEdits.push({ kind: 'remove-book', source: comic.sourceRuntimeId, work: comic.remoteResourceId })
    }
  })
  if (removedIds.length === 0) {
    return []
  }
  removeShelfWorks(libraryStore, persistenceService, removedIds)
  if (syncEdits.length > 0) signalDeviceSyncLibrary(syncEdits)
  return removedIds
}
