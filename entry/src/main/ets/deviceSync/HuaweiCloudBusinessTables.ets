import type { relationalStore } from '@kit.ArkData'
import type { SyncGroup } from './DeviceSyncFacts'
import type { ReaderSyncWorkScope } from '../model/ReaderRdbStorage'

export const SHELF_PARENT_TABLES: string[] = ['shelf_works', 'shelf_categories', 'shelf_smart_categories']
const SHELF_TABLES: string[] = SHELF_PARENT_TABLES.concat(['shelf_memberships', 'shelf_smart_category_filters', 'shelf_shared_chapters'])
const READING_TABLES: string[] = ['reader_current_positions', 'reader_chapter_states', 'reader_source_history']
const COMPOSITE_WORK_TABLES: string[] = ['shelf_memberships', 'shelf_shared_chapters', 'reader_chapter_states']
const DELETIONS = 'local_cloud_deleted_work_keys'

interface DeletedWorkKey {
  serial: number
  table: string
  comicId: string
  chapterId: string
}

export async function prepareCloudWorkDeletions(store: relationalStore.RdbStore): Promise<void> {
  // ArkData reports a composite key as a rowid even when it has already
  // removed that row. Capture the business key in the very same transaction.
  // This table belongs to local publication and is never registered with AGC.
  await store.execute('CREATE TABLE IF NOT EXISTS ' + DELETIONS +
    ' (serial INTEGER PRIMARY KEY, table_name TEXT NOT NULL, comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL)')
  for (const table of COMPOSITE_WORK_TABLES) {
    const chapter = table === 'reader_chapter_states' ? 'OLD.chapter_id' : "''"
    await store.execute('CREATE TRIGGER IF NOT EXISTS capture_cloud_delete_' + table + ' AFTER DELETE ON ' + table +
      ' WHEN EXISTS (SELECT 1 FROM ' + DELETIONS + " WHERE serial = 0 AND (comic_id = '' OR comic_id = OLD.comic_id))" +
      ' BEGIN INSERT INTO ' + DELETIONS + " (table_name, comic_id, chapter_id) VALUES ('" +
      table + "', OLD.comic_id, " + chapter + '); END')
  }
  // Startup loads the current business rows. Publication receipts left by a
  // stopped process do not belong to the new in-memory shelf.
  await store.execute('DELETE FROM ' + DELETIONS)
}

export async function startCloudWorkDeletions(store: relationalStore.RdbStore, comicId: string = ''): Promise<void> {
  // The zero row enables capture during the transfer. Outside this interval
  // local membership writes perform no journal inserts.
  await store.execute('INSERT OR REPLACE INTO ' + DELETIONS +
    " (serial, table_name, comic_id, chapter_id) VALUES (0, '', ?, '')", [comicId])
}

export async function stopCloudWorkDeletions(store: relationalStore.RdbStore): Promise<void> {
  await store.execute('DELETE FROM ' + DELETIONS + ' WHERE serial = 0')
}

export async function acknowledgeCloudWorkDeletions(store: relationalStore.RdbStore, serial: number): Promise<void> {
  if (serial > 0) await store.execute('DELETE FROM ' + DELETIONS + ' WHERE serial > 0 AND serial <= ?', [serial])
}

async function readCloudWorkDeletions(store: relationalStore.RdbStore): Promise<DeletedWorkKey[]> {
  const keys: DeletedWorkKey[] = []
  const rows = await store.querySql('SELECT serial, table_name, comic_id, chapter_id FROM ' +
    DELETIONS + ' WHERE serial > 0 ORDER BY serial')
  try {
    while (rows.goToNextRow()) {
      keys.push({ serial: rows.getLong(0), table: rows.getString(1), comicId: rows.getString(2), chapterId: rows.getString(3) })
    }
  } finally { rows.close() }
  return keys
}

function cloudTablesForGroup(group: SyncGroup): string[] {
  switch (group) {
    case 'shelf': return SHELF_TABLES
    case 'reading': return READING_TABLES
    case 'reader-settings': return ['reader_shared_preferences', 'book_reader_modes']
    case 'source-subscriptions': return ['source_subscriptions']
    case 'search-history': return ['search_history']
  }
}

export function cloudTablesForGroups(groups: SyncGroup[]): string[] {
  const tables: string[] = []
  for (const group of groups) tables.push(...cloudTablesForGroup(group))
  return tables
}

export class CloudBusinessChanges {
  readonly groups: Set<SyncGroup> = new Set()
  readonly shelfWorks: Set<string> = new Set()
  readonly removedCategoryIds: Set<string> = new Set()
  readonly reading: Map<string, Set<string>> = new Map()
  readonly removedSearchTerms: Set<string> = new Set()
  readonly removedSubscriptionUrls: Set<string> = new Set()
  deletedWorkSerial: number = 0
  categories: boolean = false
  smartCategories: boolean = false

  readingScope(): ReaderSyncWorkScope[] {
    const result: ReaderSyncWorkScope[] = []
    this.reading.forEach((chapters: Set<string>, id: string): void => {
      result.push({ comicId: id, chapterIds: Array.from(chapters) })
    })
    return result
  }

  addWork(group: SyncGroup, comicId: string, chapterId: string = ''): void {
    if (group === 'shelf') {
      this.shelfWorks.add(comicId)
      return
    }
    let chapters = this.reading.get(comicId)
    if (chapters === undefined) {
      chapters = new Set<string>()
      this.reading.set(comicId, chapters)
    }
    if (chapterId !== '') chapters.add(chapterId)
  }
}

async function accountForComicIds(store: relationalStore.RdbStore, effects: CloudBusinessChanges, table: string,
  keys: Array<string> | Array<number>): Promise<void> {
  const group: SyncGroup = READING_TABLES.includes(table) ? 'reading' : 'shelf'
  const chapter = table === 'reader_chapter_states'
  for (let i = 0; i < keys.length; i += 100) {
    const rowids: number[] = []
    for (let j = i; j < Math.min(i + 100, keys.length); j++) {
      const key = keys[j]
      if (typeof key === 'number') rowids.push(key)
      else effects.addWork(group, key)
    }
    if (rowids.length === 0) continue
    const rows = await store.querySql('SELECT comic_id' + (chapter ? ', chapter_id' : '') + ' FROM ' + table +
      ' WHERE rowid IN (' + rowids.map((): string => '?').join(', ') + ')', rowids)
    try {
      while (rows.goToNextRow()) effects.addWork(group, rows.getString(0), chapter ? rows.getString(1) : '')
    } finally { rows.close() }
  }
}

export async function cloudBusinessChanges(store: relationalStore.RdbStore,
  changes: relationalStore.ChangeInfo[], selected: SyncGroup[], selectedWork?: string): Promise<CloudBusinessChanges> {
  const effects = new CloudBusinessChanges()
  for (const change of changes) {
    const group = selected.find((value: SyncGroup): boolean => cloudTablesForGroup(value).includes(change.table))
    if (group === undefined) continue
    effects.groups.add(group)
    if (group === 'search-history' || group === 'source-subscriptions') {
      const removed = group === 'search-history' ? effects.removedSearchTerms : effects.removedSubscriptionUrls
      for (const key of change.deleted) {
        if (typeof key === 'string') removed.add(key)
      }
    }
    if (change.table === 'shelf_categories') {
      effects.categories = true
      for (const key of change.deleted) {
        if (typeof key === 'string') effects.removedCategoryIds.add(key)
      }
    }
    else if (change.table === 'shelf_smart_categories' || change.table === 'shelf_smart_category_filters') effects.smartCategories = true
    else if (group === 'shelf' || group === 'reading') {
      await accountForComicIds(store, effects, change.table, change.inserted)
      await accountForComicIds(store, effects, change.table, change.updated)
      if (!COMPOSITE_WORK_TABLES.includes(change.table)) {
        await accountForComicIds(store, effects, change.table, change.deleted)
      }
    }
  }
  // The committed keys are available even if the SDK delivers its change
  // callback after the final progress callback. Local edits during a round
  // can also appear here, so publication reads the current row by work key.
  for (const key of await readCloudWorkDeletions(store)) {
    effects.deletedWorkSerial = key.serial
    const group: SyncGroup = READING_TABLES.includes(key.table) ? 'reading' : 'shelf'
    if (!selected.includes(group) || (selectedWork !== undefined && selectedWork !== key.comicId)) continue
    effects.groups.add(group)
    effects.addWork(group, key.comicId, key.chapterId)
  }
  // Missing keys must never send the shelf through the full restore route.
  if (effects.shelfWorks.size === 0 && !effects.categories && !effects.smartCategories) effects.groups.delete('shelf')
  if (effects.reading.size === 0) effects.groups.delete('reading')
  return effects
}
