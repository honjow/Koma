import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'

const DATABASE_NAME = 'koma-user-data.db'
const DATABASE_VERSION = 4
const opens = new Map<string, Promise<relationalStore.RdbStore>>()

export function openUserDataDatabase(context: common.Context): Promise<relationalStore.RdbStore> {
  const directory = context.filesDir
  const pending = opens.get(directory)
  if (pending !== undefined) return pending
  const opening = initializeUserDataDatabase(context).catch((error: Error): never => {
    opens.delete(directory)
    throw error
  })
  opens.set(directory, opening)
  return opening
}

async function initializeUserDataDatabase(context: common.Context): Promise<relationalStore.RdbStore> {
  const store = await relationalStore.getRdbStore(context, {
    name: DATABASE_NAME, securityLevel: relationalStore.SecurityLevel.S3, allowRebuild: false,
  })
  if (store.version > DATABASE_VERSION) throw new Error('user_data_newer_schema')
  if (store.version === DATABASE_VERSION) return store
  await store.execute('CREATE TABLE IF NOT EXISTS local_data_migrations (name TEXT PRIMARY KEY)')
  await store.execute('CREATE TABLE IF NOT EXISTS search_history (' +
    'entry_key TEXT PRIMARY KEY, query TEXT, updated_at INTEGER, list_order INTEGER, ' +
    'source_filter TEXT, library_source_key TEXT, library_source_name TEXT, sync_source_set TEXT)')
  await store.execute('CREATE INDEX IF NOT EXISTS search_history_list ON search_history (updated_at DESC, list_order)')
  await store.execute('CREATE TABLE IF NOT EXISTS library_works (' +
    'id TEXT PRIMARY KEY, list_order INTEGER, payload TEXT, has_categories INTEGER)')
  await store.execute('CREATE TABLE IF NOT EXISTS library_chapters (' +
    'comic_id TEXT, list_order INTEGER, payload TEXT, PRIMARY KEY (comic_id, list_order))')
  await store.execute('CREATE TABLE IF NOT EXISTS library_memberships (' +
    'comic_id TEXT, list_order INTEGER, category_id TEXT, PRIMARY KEY (comic_id, list_order))')
  await store.execute('CREATE INDEX IF NOT EXISTS library_memberships_category ' +
    'ON library_memberships (category_id, comic_id)')
  await store.execute('CREATE TABLE IF NOT EXISTS library_lists (' +
    'kind TEXT, list_order INTEGER, payload TEXT, PRIMARY KEY (kind, list_order))')
  await store.execute('CREATE TABLE IF NOT EXISTS library_document (id INTEGER PRIMARY KEY, list_mask INTEGER)')
  await store.execute('CREATE TABLE IF NOT EXISTS reading_chapter_states (' +
    'comic_id TEXT, chapter_id TEXT, payload TEXT, PRIMARY KEY (comic_id, chapter_id))')
  await store.execute('CREATE TABLE IF NOT EXISTS reading_works (' +
    'kind TEXT, comic_id TEXT, payload TEXT, PRIMARY KEY (kind, comic_id))')
  await store.execute('CREATE TABLE IF NOT EXISTS reading_local_records (' +
    'kind TEXT, list_order INTEGER, payload TEXT, PRIMARY KEY (kind, list_order))')
  await store.execute('CREATE TABLE IF NOT EXISTS user_keyed_records (' +
    'domain TEXT NOT NULL, record_key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (domain, record_key))')
  await store.execute('CREATE TABLE IF NOT EXISTS user_record_collections (domain TEXT PRIMARY KEY)')
  store.version = DATABASE_VERSION
  return store
}
