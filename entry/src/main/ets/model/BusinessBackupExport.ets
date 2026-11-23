/** Whole-database JSON belongs exclusively to explicit backup export.
 * Import, sync and recovery must use their RDB owners and record scopes. */
import { Comic, CustomLibraryCategory } from './ComicModels'
import { LibraryCategoryDisplayStrategy, LibraryStore } from './LibraryStore'
import { LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, PersistedComic, PersistedLibraryCategory,
  PersistedCategoryDisplayStrategy, PersistedLibraryStoreDocument, persistComic, persistLibraryCategory,
  persistCategoryDisplayStrategy, readLibraryBackupDocument } from './LibraryPersistence'
import { ReaderSessionDocument, ReaderSessionDocumentSnapshot, READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
  readReaderBackupDocument } from './ReaderSessionStore'

export function exportLibraryBackup(filesDir: string): string | undefined {
  const document = readLibraryBackupDocument(filesDir)
  return document === undefined ? undefined : JSON.stringify(document)
}

export function exportReaderBackup(filesDir: string): string | undefined {
  const document = readReaderBackupDocument(filesDir)
  return document === undefined ? undefined : serializeReaderSessionForBackup(document)
}

export function createLibraryStoreBackupDocument(libraryStore: LibraryStore): PersistedLibraryStoreDocument {
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

export function serializeLibraryStoreForBackup(libraryStore: LibraryStore): string {
  return JSON.stringify(createLibraryStoreBackupDocument(libraryStore))
}

export function serializeReaderSessionForBackup(snapshot: ReaderSessionDocumentSnapshot): string {
  const document: ReaderSessionDocument = {
    schemaVersion: READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION,
    progress: snapshot.progress, sourceHistory: snapshot.sourceHistory, remoteHistory: snapshot.remoteHistory,
    chapters: snapshot.chapters, readingSessions: snapshot.readingSessions, syncPositions: snapshot.syncPositions,
    syncActions: snapshot.syncActions,
  }
  return JSON.stringify(document)
}
