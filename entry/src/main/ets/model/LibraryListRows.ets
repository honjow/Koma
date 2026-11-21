import type { relationalStore } from '@kit.ArkData'
import type { SyncLocalShelfMove } from '../deviceSync/DeviceSyncSignals'
import type { PersistedCategoryDisplayStrategy, PersistedLibraryCategory, PersistedLibraryStoreDocument } from './LibraryPersistence'
import type { LibrarySmartCategory, LibrarySmartFilter, LibrarySmartFilterMethod } from './LibrarySmartCategory'
import { booleanColumn, booleanValue, integerColumn, LocalColumnValue, LocalDataRows, textColumn } from './LocalDataRows'

interface ShelfCollections {
  id: number
  categories: boolean
  display: boolean
  smart: boolean
  mihon: boolean
  moves: boolean
}

export const shelfCollections = new LocalDataRows<ShelfCollections>('shelf_collections', ['id'],
  ['has_categories', 'has_display_strategies', 'has_smart_categories', 'has_mihon_imports', 'has_sync_moves'], 'id',
  (row: ShelfCollections): LocalColumnValue[] => [row.id, booleanValue(row.categories), booleanValue(row.display),
    booleanValue(row.smart), booleanValue(row.mihon), booleanValue(row.moves)],
  (row: relationalStore.ResultSet): ShelfCollections => ({
    id: row.getLong(0), categories: row.getLong(1) !== 0, display: row.getLong(2) !== 0, smart: row.getLong(3) !== 0,
    mihon: row.getLong(4) !== 0, moves: row.getLong(5) !== 0,
  }))

export function shelfCollectionRow(document: PersistedLibraryStoreDocument): ShelfCollections {
  return { id: 1, categories: document.customCategories !== undefined, display: document.categoryDisplayStrategies !== undefined,
    smart: document.smartCategories !== undefined, mihon: document.mihonImports !== undefined, moves: document.syncShelfMoves !== undefined }
}

interface OrderedShelfRow<T> {
  order: number
  entry: T
}

export function orderShelfRows<T>(rows: T[] | undefined): OrderedShelfRow<T>[] {
  return (rows ?? []).map((entry: T, order: number): OrderedShelfRow<T> => ({ order, entry }))
}

export const shelfCategories = new LocalDataRows<OrderedShelfRow<PersistedLibraryCategory>>('shelf_categories', ['category_id'],
  ['list_order', 'name', 'sort_order', 'created_at', 'updated_at', 'is_private'], 'list_order',
  (row: OrderedShelfRow<PersistedLibraryCategory>): LocalColumnValue[] => [
    row.entry.id, row.order, row.entry.name, row.entry.sortOrder, row.entry.createdAt,
    row.entry.updatedAt, booleanValue(row.entry.isPrivate),
  ],
  (row: relationalStore.ResultSet): OrderedShelfRow<PersistedLibraryCategory> => ({
    order: row.getLong(1),
    entry: { id: row.getString(0), name: row.getString(2), sortOrder: row.getLong(3),
      createdAt: row.getLong(4), updatedAt: row.getLong(5), isPrivate: booleanColumn(row, 6) },
  }))

export const shelfDisplayStrategies = new LocalDataRows<OrderedShelfRow<PersistedCategoryDisplayStrategy>>(
  'shelf_category_display_strategies', ['category_id'],
  ['list_order', 'sort_by', 'sort_direction', 'follows_default_sort', 'read_state', 'updated_at'], 'list_order',
  (row: OrderedShelfRow<PersistedCategoryDisplayStrategy>): LocalColumnValue[] => [
    row.entry.categoryId, row.order, row.entry.sortBy, row.entry.sortDirection ?? null,
    booleanValue(row.entry.followsDefaultSort), row.entry.readState, row.entry.updatedAt,
  ],
  (row: relationalStore.ResultSet): OrderedShelfRow<PersistedCategoryDisplayStrategy> => ({
    order: row.getLong(1),
    entry: { categoryId: row.getString(0), sortBy: row.getString(2), sortDirection: textColumn(row, 3),
      followsDefaultSort: booleanColumn(row, 4), readState: row.getString(5), updatedAt: row.getLong(6) },
  }))

export const shelfSmartCategories = new LocalDataRows<OrderedShelfRow<LibrarySmartCategory>>('shelf_smart_categories', ['category_id'],
  ['list_order', 'name', 'sort_order', 'created_at', 'updated_at'], 'list_order',
  (row: OrderedShelfRow<LibrarySmartCategory>): LocalColumnValue[] => [
    row.entry.id, row.order, row.entry.name, row.entry.sortOrder, row.entry.createdAt, row.entry.updatedAt,
  ],
  (row: relationalStore.ResultSet): OrderedShelfRow<LibrarySmartCategory> => ({
    order: row.getLong(1),
    entry: { id: row.getString(0), name: row.getString(2), sortOrder: row.getLong(3),
      createdAt: row.getLong(4), updatedAt: row.getLong(5), filters: [] },
  }))

interface ShelfSmartFilter {
  categoryId: string
  order: number
  filter: LibrarySmartFilter
}

export const shelfSmartFilters = new LocalDataRows<ShelfSmartFilter>('shelf_smart_category_filters', ['category_id', 'filter_order'],
  ['method', 'filter_value', 'excluded'], 'category_id, filter_order',
  (row: ShelfSmartFilter): LocalColumnValue[] => [
    row.categoryId, row.order, row.filter.method, row.filter.value ?? null, booleanValue(row.filter.exclude),
  ],
  (row: relationalStore.ResultSet): ShelfSmartFilter => ({
    categoryId: row.getString(0), order: row.getLong(1),
    filter: { method: row.getString(2) as LibrarySmartFilterMethod, value: textColumn(row, 3), exclude: row.getLong(4) !== 0 },
  }))

export function smartFilterRows(categories: LibrarySmartCategory[] | undefined): ShelfSmartFilter[] {
  const rows: ShelfSmartFilter[] = []
  for (const category of categories ?? []) {
    category.filters.forEach((filter: LibrarySmartFilter, order: number): void => {
      rows.push({ categoryId: category.id, order, filter })
    })
  }
  return rows
}

export function readSmartCategories(store: relationalStore.RdbStore): LibrarySmartCategory[] {
  const categories = shelfSmartCategories.read(store).map((row: OrderedShelfRow<LibrarySmartCategory>): LibrarySmartCategory => row.entry)
  const byId = new Map<string, LibrarySmartCategory>()
  for (const category of categories) byId.set(category.id, category)
  for (const row of shelfSmartFilters.read(store)) byId.get(row.categoryId)?.filters.push(row.filter)
  return categories
}

// A move records either an explicit cancellation or a target. A missing
// category list and an explicitly empty list have different WebDAV effects.
export const shelfMoves = new LocalDataRows<OrderedShelfRow<SyncLocalShelfMove>>('shelf_sync_moves', ['space', 'source_id', 'work_id'],
  ['list_order', 'target_source_id', 'target_work_id', 'has_target_categories'], 'list_order',
  (row: OrderedShelfRow<SyncLocalShelfMove>): LocalColumnValue[] => [
    row.entry.space, row.entry.source, row.entry.work, row.order, row.entry.target?.toSource ?? null,
    row.entry.target?.toWork ?? null, booleanValue(row.entry.target?.categories !== undefined),
  ],
  (row: relationalStore.ResultSet): OrderedShelfRow<SyncLocalShelfMove> => ({
    order: row.getLong(3),
    entry: { space: row.getString(0), source: row.getString(1), work: row.getString(2),
      target: row.isColumnNull(4) ? undefined : { toSource: row.getString(4), toWork: row.getString(5),
        categories: row.getLong(6) === 0 ? undefined : [] } },
  }))

interface ShelfMoveCategory {
  space: string
  source: string
  work: string
  order: number
  categoryId: string
}

export const shelfMoveCategories = new LocalDataRows<ShelfMoveCategory>('shelf_sync_move_categories',
  ['space', 'source_id', 'work_id', 'category_order'], ['category_id'], 'space, source_id, work_id, category_order',
  (row: ShelfMoveCategory): LocalColumnValue[] => [row.space, row.source, row.work, row.order, row.categoryId],
  (row: relationalStore.ResultSet): ShelfMoveCategory => ({
    space: row.getString(0), source: row.getString(1), work: row.getString(2), order: row.getLong(3), categoryId: row.getString(4),
  }))

export function shelfMoveCategoryRows(moves: SyncLocalShelfMove[] | undefined): ShelfMoveCategory[] {
  const rows: ShelfMoveCategory[] = []
  for (const move of moves ?? []) {
    move.target?.categories?.forEach((categoryId: string, order: number): void => {
      rows.push({ space: move.space, source: move.source, work: move.work, order, categoryId })
    })
  }
  return rows
}

export function readShelfMoves(store: relationalStore.RdbStore): SyncLocalShelfMove[] {
  const moves = shelfMoves.read(store).map((row: OrderedShelfRow<SyncLocalShelfMove>): SyncLocalShelfMove => row.entry)
  const byKey = new Map<string, SyncLocalShelfMove>()
  for (const move of moves) byKey.set(JSON.stringify([move.space, move.source, move.work]), move)
  for (const row of shelfMoveCategories.read(store)) {
    byKey.get(JSON.stringify([row.space, row.source, row.work]))?.target?.categories?.push(row.categoryId)
  }
  return moves
}
