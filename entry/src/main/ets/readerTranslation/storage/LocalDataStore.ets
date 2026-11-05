// Adapted from NextE59a7a679. Koma owns configuration, credentials and files.
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { DiagnosticLogger } from '../../diagnostics/DiagnosticLogger'

const SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS comic_translation_document_cache (' +
    'cache_key TEXT PRIMARY KEY NOT NULL, ' +
    'scope_key TEXT NOT NULL, ' +
    'project_id TEXT NOT NULL, ' +
    'page_index INTEGER NOT NULL, ' +
    'payload TEXT NOT NULL, ' +
    'cached_at INTEGER NOT NULL, ' +
    'accessed_at INTEGER NOT NULL' +
  ')'
const SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_SCOPE_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_comic_translation_document_cache_scope ' +
  'ON comic_translation_document_cache (scope_key, page_index DESC, accessed_at DESC)'
const SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_ACCESS_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_comic_translation_document_cache_access ' +
  'ON comic_translation_document_cache (accessed_at DESC)'
/** Separate regenerable Koma translation cache; original library/progress stores are untouched. */
export class LocalDataStore {
  private static initialization: Promise<void> | null = null
  private static initialized: boolean = false
  static async open(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    let store: relationalStore.RdbStore
    try {
      store = await relationalStore.getRdbStore(context,
        { name: 'koma-reader-translation-cache.db', securityLevel: relationalStore.SecurityLevel.S1 })
    } catch (error) {
      DiagnosticLogger.warn('comic-translation-cache', 'open_failed', 'cache store unavailable')
      throw error as Error
    }
    if (!LocalDataStore.initialized) {
      try {
        if (LocalDataStore.initialization === null) LocalDataStore.initialization = LocalDataStore.initialize(store)
        await LocalDataStore.initialization
        LocalDataStore.initialized = true
      } catch (error) {
        DiagnosticLogger.warn('comic-translation-cache', 'schema_initialization_failed', 'cache initialization will retry')
        throw error as Error
      } finally {
        LocalDataStore.initialization = null
      }
    }
    return store
  }
  /** Keep the cursor inside the read and propagate failures to the caller's recovery path. */
  static async readQuery<T>(
    store: relationalStore.RdbStore,
    sql: string,
    args: relationalStore.ValueType[],
    read: (result: relationalStore.ResultSet) => T,
  ): Promise<T> {
    try {
      const result: relationalStore.ResultSet = await store.querySql(sql, args)
      try {
        return read(result)
      } finally {
        result.close()
      }
    } catch (error) {
      DiagnosticLogger.warn('comic-translation-cache', 'query_failed', 'cache query failed')
      throw error as Error
    }
  }

  /** @throws Initialization failure is handled by open and leaves the cache retryable. */
  private static async initialize(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_TABLE)
    await store.executeSql(SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_SCOPE_INDEX)
    await store.executeSql(SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_ACCESS_INDEX)
    store.version = 1
  }
}
