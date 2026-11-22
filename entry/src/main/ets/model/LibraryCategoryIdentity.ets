import type { relationalStore } from '@kit.ArkData'
import type { PersistedLibraryCategory } from './LibraryPersistence'
import { shelfCategories, shelfDisplayStrategies, shelfSmartCategories, shelfSmartFilters } from './LibraryListRows'
import { libraryCategoryNameKey } from './ComicModels'
import { CATEGORY_SYNC_PREFIX, smartCategoryStorageId, syncStableId } from '../deviceSync/DeviceSyncData'
import { isSyncReplica } from '../deviceSync/DeviceSyncFacts'

const ALIASES = 'shelf_category_aliases'
const MEMBERSHIPS = ['shelf_memberships', 'shelf_memberships_local']

interface SavedCategory {
  entry: PersistedLibraryCategory
  order: number
  sharedId?: string
}

export interface ShelfCategoryIdentityChanges {
  categoryIdsChanged: boolean
  comicIds: Set<string>
}

export function readShelfCategoryAliases(store: relationalStore.RdbStore): Map<string, string> {
  const aliases = new Map<string, string>()
  const table = store.querySqlSync("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?", [ALIASES])
  try {
    if (!table.goToNextRow()) return aliases
  } finally {
    table.close()
  }
  const rows = store.querySqlSync('SELECT old_id, category_id FROM ' + ALIASES)
  try {
    while (rows.goToNextRow()) aliases.set(rows.getString(0), rows.getString(1))
  } finally {
    rows.close()
  }
  return aliases
}

function categoryAliasesWithReferences(store: relationalStore.RdbStore): Map<string, string> {
  const affected = new Map<string, string>()
  const rows = store.querySqlSync('SELECT old_id, category_id FROM ' + ALIASES + ' a WHERE ' +
    'EXISTS (SELECT 1 FROM shelf_memberships WHERE category_id = a.old_id) OR ' +
    'EXISTS (SELECT 1 FROM shelf_memberships_local WHERE category_id = a.old_id) OR ' +
    'EXISTS (SELECT 1 FROM shelf_category_display_strategies WHERE category_id = a.old_id) OR ' +
    "EXISTS (SELECT 1 FROM shelf_smart_category_filters WHERE method = 'category' AND filter_value = a.old_id) OR " +
    'EXISTS (SELECT 1 FROM shelf_sync_move_categories WHERE category_id = a.old_id) OR ' +
    "EXISTS (SELECT 1 FROM shelf_mihon_text_items WHERE item_kind = 'local_category' AND item_text = a.old_id)")
  try {
    while (rows.goToNextRow()) affected.set(rows.getString(0), rows.getString(1))
  } finally {
    rows.close()
  }
  return affected
}

function sharedCategoryId(id: string): string | undefined {
  if (isSyncReplica(id)) return id
  if (!id.startsWith(CATEGORY_SYNC_PREFIX)) return undefined
  // Old receivers also added a numeric suffix if their allocated ID collided.
  const original = id.slice(CATEGORY_SYNC_PREFIX.length, CATEGORY_SYNC_PREFIX.length + 36)
  const suffix = id.slice(CATEGORY_SYNC_PREFIX.length + 36)
  return isSyncReplica(original) && (suffix === '' || /^_[0-9]+$/.test(suffix)) ? original : undefined
}

function moveDisplayStrategy(store: relationalStore.RdbStore, oldId: string, id: string): void {
  const oldStyle = shelfDisplayStrategies.read(store, 'category_id = ?', [oldId])[0]
  if (oldStyle === undefined) return
  const style = shelfDisplayStrategies.read(store, 'category_id = ?', [id])[0]
  if (style === undefined || oldStyle.entry.updatedAt > style.entry.updatedAt) {
    oldStyle.entry.categoryId = id
    shelfDisplayStrategies.put(store, oldStyle)
  }
  shelfDisplayStrategies.remove(store, [oldId])
}

/** Reuse the existing WebDAV identity for the RDB definition and its rules.
 * A cloud batch may have delivered the parent alone. Wait for its rules before changing the ID. */
export function reconcileSmartCategoryIds(store: relationalStore.RdbStore): boolean {
  let changed = false
  for (const legacy of shelfSmartCategories.read(store)) {
    const oldId = legacy.entry.id
    const id = smartCategoryStorageId(oldId)
    if (id === oldId) continue
    const rules = shelfSmartFilters.read(store, 'category_id = ?', [oldId])
    if (rules.length === 0) continue
    const canonical = shelfSmartCategories.read(store, 'category_id = ?', [id])[0]
    if (canonical === undefined || legacy.entry.updatedAt > canonical.entry.updatedAt ||
      shelfSmartFilters.read(store, 'category_id = ?', [id]).length === 0) {
      legacy.entry.id = id
      shelfSmartCategories.put(store, legacy)
      rules.forEach(rule => { rule.categoryId = id })
      shelfSmartFilters.replace(store, rules, 'category_id', id)
    }
    moveDisplayStrategy(store, oldId, id)
    shelfSmartFilters.replace(store, [], 'category_id', oldId)
    shelfSmartCategories.remove(store, [oldId])
    changed = true
  }
  return changed
}

function rewriteCategoryReferences(store: relationalStore.RdbStore, oldId: string, id: string, affected: Set<string>): void {
  for (const table of MEMBERSHIPS) {
    const rows = store.querySqlSync('SELECT DISTINCT comic_id FROM ' + table + ' WHERE category_id = ?', [oldId])
    try {
      while (rows.goToNextRow()) affected.add(rows.getString(0))
    } finally {
      rows.close()
    }
    const columns = '(comic_id, category_id, category_occurrence, list_order)'
    store.executeSync('INSERT OR IGNORE INTO ' + table + ' ' + columns +
      ' SELECT comic_id, ?, category_occurrence, list_order FROM ' + table + ' WHERE category_id = ?', [id, oldId])
    store.executeSync('DELETE FROM ' + table + ' WHERE category_id = ?', [oldId])
  }
  moveDisplayStrategy(store, oldId, id)
  store.executeSync("UPDATE shelf_smart_category_filters SET filter_value = ? WHERE method = 'category' AND filter_value = ?", [id, oldId])
  // If two rules were equivalent after rekeying, keep the exclusion. A
  // shortcut for the same category must not broaden an existing smart filter.
  store.executeSync("DELETE FROM shelf_smart_category_filters AS original WHERE method = 'category' AND filter_value = ? " +
    'AND EXISTS (SELECT 1 FROM shelf_smart_category_filters kept WHERE kept.category_id = original.category_id ' +
    'AND kept.method = original.method AND kept.filter_value = original.filter_value ' +
    'AND (COALESCE(kept.excluded, 0) > COALESCE(original.excluded, 0) OR ' +
    '(COALESCE(kept.excluded, 0) = COALESCE(original.excluded, 0) AND kept.filter_order < original.filter_order)))', [id])
  store.executeSync('UPDATE shelf_sync_move_categories SET category_id = ? WHERE category_id = ?', [id, oldId])
  store.executeSync("UPDATE shelf_mihon_text_items SET item_text = ? WHERE item_kind = 'local_category' AND item_text = ?", [id, oldId])
}

/** Runs inside the existing shelf write transaction. Only category rows and their references change. */
export function reconcileShelfCategoryIds(store: relationalStore.RdbStore, migrateLegacy: boolean): ShelfCategoryIdentityChanges {
  const aliases = readShelfCategoryAliases(store)
  const rows = shelfCategories.read(store)
  const canonicalRows = new Map<string, PersistedLibraryCategory>()
  for (const row of rows) {
    const category = row.entry
    const id = aliases.get(category.id) ?? sharedCategoryId(category.id)
    if (id === undefined) continue
    const current = canonicalRows.get(id)
    if (current === undefined || category.id === id || (current.id !== id && category.updatedAt > current.updatedAt)) {
      canonicalRows.set(id, category)
    }
  }
  const groups = new Map<string, SavedCategory[]>()
  for (const row of rows) {
    const category = row.entry
    if (category.id === 'favorite' || category.id === 'read_later') continue
    const sharedId = aliases.get(category.id) ?? sharedCategoryId(category.id)
    const name = sharedId === undefined ? category.name : canonicalRows.get(sharedId)?.name ?? category.name
    const key = libraryCategoryNameKey(name)
    const group = groups.get(key) ?? []
    group.push({ entry: category, order: row.order, sharedId })
    groups.set(key, group)
  }

  const result: ShelfCategoryIdentityChanges = { categoryIdsChanged: false, comicIds: new Set<string>() }
  for (const group of groups.values()) {
    const first = group[0]
    if (group.length === 1 && (first.sharedId === first.entry.id || first.sharedId === undefined && !migrateLegacy)) continue
    const candidates = group.flatMap((row: SavedCategory): string[] => row.sharedId === undefined ? [] : [row.sharedId]).sort()
    const legacyId = group.map((row: SavedCategory): string => row.entry.id).sort()[0]
    const id = candidates[0] ?? syncStableId('shelf-category:' + legacyId)
    const preferred = canonicalRows.get(id) ?? first.entry
    const privacy = group.some((row: SavedCategory): boolean => row.entry.isPrivate === true) ? true : preferred.isPrivate
    shelfCategories.put(store, { order: first.order, entry: {
      id, name: preferred.name, sortOrder: first.entry.sortOrder, createdAt: preferred.createdAt,
      updatedAt: preferred.updatedAt, isPrivate: privacy,
    } })
    for (const row of group) {
      const oldId = row.entry.id
      if (oldId === id) continue
      if (aliases.size === 0 && !result.categoryIdsChanged) {
        store.executeSync('CREATE TABLE IF NOT EXISTS ' + ALIASES + ' (old_id TEXT PRIMARY KEY NOT NULL, category_id TEXT NOT NULL)')
      }
      store.executeSync('UPDATE ' + ALIASES + ' SET category_id = ? WHERE category_id = ?', [id, oldId])
      store.executeSync('INSERT OR REPLACE INTO ' + ALIASES + ' (old_id, category_id) VALUES (?, ?)', [oldId, id])
      shelfCategories.remove(store, [oldId])
      result.categoryIdsChanged = true
    }
  }
  // A cloud membership may arrive in a later committed batch than its category.
  // Keep the migration key available for those rows and for the existing WebDAV projection.
  if (result.categoryIdsChanged || aliases.size > 0) {
    for (const alias of categoryAliasesWithReferences(store)) {
      rewriteCategoryReferences(store, alias[0], alias[1], result.comicIds)
    }
  }
  return result
}
