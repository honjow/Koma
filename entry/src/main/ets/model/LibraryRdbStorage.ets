import { relationalStore } from '@kit.ArkData'
import { PersistedChapter, PersistedComic, PersistedLibraryStoreDocument, PersistedLibraryCategory,
  PersistedCategoryDisplayStrategy } from './LibraryPersistence'
import { LibrarySmartCategory } from './LibrarySmartCategory'
import { SyncLocalShelfMove } from '../deviceSync/DeviceSyncSignals'
import { MihonImportRecord } from './MihonBackupReader'

const MIGRATION_NAME = 'library-from-json-v1'
const CATEGORY_LIST = 'categories'
const DISPLAY_LIST = 'display'
const SMART_LIST = 'smart'
const IMPORT_LIST = 'mihon'
const MOVE_LIST = 'moves'
const CATEGORY_MASK = 1
const DISPLAY_MASK = 2
const SMART_MASK = 4
const IMPORT_MASK = 8
const MOVE_MASK = 16

const WORK_UPSERT = 'INSERT INTO library_works (id, list_order, payload, has_categories) VALUES (?, ?, ?, ?) ' +
  'ON CONFLICT(id) DO UPDATE SET list_order=excluded.list_order, payload=excluded.payload, has_categories=excluded.has_categories'

interface LibraryWorkRow {
  id: string
  order: number
  payload: string
  chapters: string[]
  categories: string[] | undefined
}

interface LibraryList {
  kind: string
  rows: string[]
}

function workRow(comic: PersistedComic, order: number): LibraryWorkRow {
  // Chapter descriptors and category memberships each have their own rows.
  const metadata: PersistedComic = {
    id: comic.id, title: comic.title, subtitle: comic.subtitle, author: comic.author,
    sourceKind: comic.sourceKind, sourcePath: comic.sourcePath, sourceRuntimeId: comic.sourceRuntimeId,
    remoteServerId: comic.remoteServerId, remoteResourceId: comic.remoteResourceId, coverUri: comic.coverUri,
    personalNotes: comic.personalNotes, customCoverUri: comic.customCoverUri, sourceCoverUri: comic.sourceCoverUri,
    updateSchedule: comic.updateSchedule, localMetadata: comic.localMetadata,
    localImportOrigin: comic.localImportOrigin, sourceMetadata: comic.sourceMetadata,
    sortTitle: comic.sortTitle, preferredDirection: comic.preferredDirection, chapters: [],
    chapterCount: comic.chapterCount, pageCount: comic.pageCount, createdAt: comic.createdAt,
    updatedAt: comic.updatedAt, lastImportedAt: comic.lastImportedAt,
  }
  return {
    id: comic.id, order, payload: JSON.stringify(metadata), categories: comic.categoryIds,
    chapters: comic.chapters.map((chapter: PersistedChapter): string => JSON.stringify(chapter)),
  }
}

function encodeList<T>(kind: string, values: T[] | undefined): LibraryList {
  return { kind, rows: (values ?? []).map((row: T): string => JSON.stringify(row)) }
}

function collectLists(document: PersistedLibraryStoreDocument): LibraryList[] {
  return [
    encodeList(CATEGORY_LIST, document.customCategories), encodeList(DISPLAY_LIST, document.categoryDisplayStrategies),
    encodeList(SMART_LIST, document.smartCategories), encodeList(IMPORT_LIST, document.mihonImports),
    encodeList(MOVE_LIST, document.syncShelfMoves),
  ]
}

function listMask(document: PersistedLibraryStoreDocument): number {
  return (document.customCategories === undefined ? 0 : CATEGORY_MASK) |
    (document.categoryDisplayStrategies === undefined ? 0 : DISPLAY_MASK) |
    (document.smartCategories === undefined ? 0 : SMART_MASK) | (document.mihonImports === undefined ? 0 : IMPORT_MASK) |
    (document.syncShelfMoves === undefined ? 0 : MOVE_MASK)
}

function keyValues(result: relationalStore.ResultSet): Map<string, string[]> {
  const rows = new Map<string, string[]>()
  try {
    while (result.goToNextRow()) {
      const key = result.getString(0)
      let values = rows.get(key)
      if (values === undefined) {
        values = []
        rows.set(key, values)
      }
      values.push(result.getString(1))
    }
    return rows
  } finally {
    result.close()
  }
}

const CHAPTER_QUERY = 'SELECT comic_id, payload FROM library_chapters ORDER BY comic_id, list_order'
const MEMBER_QUERY = 'SELECT comic_id, category_id FROM library_memberships ORDER BY comic_id, list_order'
const LIST_QUERY = 'SELECT kind, payload FROM library_lists ORDER BY kind, list_order'
const WORK_QUERY = 'SELECT id, list_order, payload, has_categories FROM library_works ORDER BY list_order'
const DOCUMENT_QUERY = 'SELECT list_mask FROM library_document WHERE id = 1'

function readWorkRows(result: relationalStore.ResultSet, chapters: Map<string, string[]>,
  categories: Map<string, string[]>): Map<string, LibraryWorkRow> {
  const rows = new Map<string, LibraryWorkRow>()
  try {
    while (result.goToNextRow()) {
      const id = result.getString(0)
      rows.set(id, { id, order: result.getLong(1), payload: result.getString(2),
        chapters: chapters.get(id) ?? [], categories: result.getLong(3) === 0 ? undefined : categories.get(id) ?? [] })
    }
    return rows
  } finally {
    result.close()
  }
}

function parseList<T>(values: string[] | undefined): T[] {
  return (values ?? []).map((value: string): T => JSON.parse(value) as T)
}

function assembleDocument(mask: number, works: Map<string, LibraryWorkRow>,
  lists: Map<string, string[]>): PersistedLibraryStoreDocument {
  const comics: PersistedComic[] = []
  works.forEach((work: LibraryWorkRow): void => {
    const comic = JSON.parse(work.payload) as PersistedComic
    comic.chapters = parseList<PersistedChapter>(work.chapters)
    comic.categoryIds = work.categories
    comics.push(comic)
  })
  return { schemaVersion: 1, comics,
    customCategories: (mask & CATEGORY_MASK) !== 0 ? parseList<PersistedLibraryCategory>(lists.get(CATEGORY_LIST)) : undefined,
    categoryDisplayStrategies: (mask & DISPLAY_MASK) !== 0
      ? parseList<PersistedCategoryDisplayStrategy>(lists.get(DISPLAY_LIST)) : undefined,
    smartCategories: (mask & SMART_MASK) !== 0 ? parseList<LibrarySmartCategory>(lists.get(SMART_LIST)) : undefined,
    mihonImports: (mask & IMPORT_MASK) !== 0 ? parseList<MihonImportRecord>(lists.get(IMPORT_LIST)) : undefined,
    syncShelfMoves: (mask & MOVE_MASK) !== 0 ? parseList<SyncLocalShelfMove>(lists.get(MOVE_LIST)) : undefined,
  }
}

function readMask(result: relationalStore.ResultSet): number {
  try {
    return result.goToNextRow() ? result.getLong(0) : -1
  } finally {
    result.close()
  }
}

const UPSERT_DOCUMENT = 'INSERT INTO library_document (id, list_mask) VALUES (1, ?) ' +
  'ON CONFLICT(id) DO UPDATE SET list_mask=excluded.list_mask'

/** RDB owns the live shelf. Snapshots are exchanged at the existing backup and WebDAV boundaries. */
export class LibraryRdbStorage {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  async migrated(): Promise<boolean> {
    const result = await this.store.querySql('SELECT name FROM local_data_migrations WHERE name = ?', [MIGRATION_NAME])
    try {
      return result.goToNextRow()
    } finally {
      result.close()
    }
  }

  async migrate(document: PersistedLibraryStoreDocument | undefined): Promise<void> {
    const transaction = await this.store.createTransaction()
    try {
      if (document !== undefined) {
        await transaction.execute(UPSERT_DOCUMENT, [listMask(document)])
        const works = new Set<string>()
        for (let index = 0; index < document.comics.length; index += 1) {
          const row = workRow(document.comics[index], index)
          if (works.has(row.id)) throw new Error('library_legacy_duplicate_work')
          works.add(row.id)
          await transaction.execute(WORK_UPSERT, [row.id, row.order, row.payload, row.categories === undefined ? 0 : 1])
          await this.insertRows(transaction, 'library_chapters', 'comic_id', 'payload', row.id, row.chapters)
          if (row.categories !== undefined) {
            await this.insertRows(transaction, 'library_memberships', 'comic_id', 'category_id', row.id, row.categories)
          }
        }
        for (const list of collectLists(document)) {
          await this.insertRows(transaction, 'library_lists', 'kind', 'payload', list.kind, list.rows)
        }
      }
      await transaction.execute('INSERT INTO local_data_migrations (name) VALUES (?)', [MIGRATION_NAME])
      await transaction.commit()
    } catch (error) {
      await transaction.rollback()
      throw error as Error
    }
  }

  private async insertRows(transaction: relationalStore.Transaction, table: string, keyColumn: string, valueColumn: string,
    key: string, values: string[]): Promise<void> {
    for (let start = 0; start < values.length; start += 128) {
      const end = Math.min(start + 128, values.length)
      const placeholders: string[] = []
      const args: relationalStore.ValueType[] = []
      for (let index = start; index < end; index += 1) {
        placeholders.push('(?, ?, ?)')
        args.push(key, index, values[index])
      }
      await transaction.execute('INSERT INTO ' + table + ' (' + keyColumn + ', list_order, ' + valueColumn +
        ') VALUES ' + placeholders.join(', '), args)
    }
  }

  read(): PersistedLibraryStoreDocument | undefined {
    const mask = readMask(this.store.querySqlSync(DOCUMENT_QUERY))
    if (mask < 0) return undefined
    const works = this.readWorks()
    return assembleDocument(mask, works, keyValues(this.store.querySqlSync(LIST_QUERY)))
  }

  private readWorks(): Map<string, LibraryWorkRow> {
    const chapters = keyValues(this.store.querySqlSync(CHAPTER_QUERY))
    const categories = keyValues(this.store.querySqlSync(MEMBER_QUERY))
    return readWorkRows(this.store.querySqlSync(WORK_QUERY), chapters, categories)
  }

  /** Use one synchronous transaction to keep existing in-memory rollback and revision fences valid. */
  save(document: PersistedLibraryStoreDocument | undefined): void {
    this.store.beginTransaction()
    try {
      if (document === undefined) {
        this.store.executeSync('DELETE FROM library_chapters')
        this.store.executeSync('DELETE FROM library_memberships')
        this.store.executeSync('DELETE FROM library_works')
        this.store.executeSync('DELETE FROM library_lists')
        this.store.executeSync('DELETE FROM library_document')
      } else {
        this.saveDocument(document)
      }
      this.store.commit()
    } catch (error) {
      this.store.rollBack()
      throw error as Error
    }
  }

  private saveDocument(document: PersistedLibraryStoreDocument): void {
    const previousWorks = this.readWorks()
    const previousLists = keyValues(this.store.querySqlSync(LIST_QUERY))
    for (let index = 0; index < document.comics.length; index += 1) {
      const next = workRow(document.comics[index], index)
      const previous = previousWorks.get(next.id)
      previousWorks.delete(next.id)
      this.updateWork(next, previous)
    }
    for (const id of previousWorks.keys()) {
      this.store.executeSync('DELETE FROM library_chapters WHERE comic_id = ?', [id])
      this.store.executeSync('DELETE FROM library_memberships WHERE comic_id = ?', [id])
      this.store.executeSync('DELETE FROM library_works WHERE id = ?', [id])
    }
    for (const list of collectLists(document)) {
      this.updateRows('library_lists', 'kind', 'payload', list.kind, previousLists.get(list.kind) ?? [], list.rows)
    }
    this.store.executeSync(UPSERT_DOCUMENT, [listMask(document)])
  }

  /** Existing-work edits preserve order, work count and every other domain's rows. */
  saveExistingWorks(comics: PersistedComic[]): void {
    this.store.beginTransaction()
    try {
      for (const comic of comics) {
        const chapters = keyValues(this.store.querySqlSync(
          'SELECT comic_id, payload FROM library_chapters WHERE comic_id = ? ORDER BY list_order', [comic.id]))
        const categories = keyValues(this.store.querySqlSync(
          'SELECT comic_id, category_id FROM library_memberships WHERE comic_id = ? ORDER BY list_order', [comic.id]))
        const previous = readWorkRows(this.store.querySqlSync(
          'SELECT id, list_order, payload, has_categories FROM library_works WHERE id = ?', [comic.id]),
          chapters, categories).get(comic.id)
        if (previous === undefined) throw new Error('library_work_missing')
        this.updateWork(workRow(comic, previous.order), previous)
      }
      this.store.commit()
    } catch (error) {
      this.store.rollBack()
      throw error as Error
    }
  }

  private updateWork(next: LibraryWorkRow, previous?: LibraryWorkRow): void {
    const hasCategories = next.categories !== undefined
    if (previous === undefined || previous.payload !== next.payload || previous.order !== next.order ||
      (previous.categories !== undefined) !== hasCategories) {
      this.store.executeSync(WORK_UPSERT, [next.id, next.order, next.payload, hasCategories ? 1 : 0])
    }
    this.updateRows('library_chapters', 'comic_id', 'payload', next.id, previous?.chapters ?? [], next.chapters)
    this.updateRows('library_memberships', 'comic_id', 'category_id', next.id, previous?.categories ?? [], next.categories ?? [])
  }

  private updateRows(table: string, keyColumn: string, valueColumn: string, key: string,
    previous: string[], next: string[]): void {
    const upsert = 'INSERT INTO ' + table + ' (' + keyColumn + ', list_order, ' + valueColumn +
      ') VALUES (?, ?, ?) ON CONFLICT(' + keyColumn + ', list_order) DO UPDATE SET ' + valueColumn + '=excluded.' + valueColumn
    for (let index = 0; index < next.length; index += 1) {
      if (previous[index] !== next[index]) this.store.executeSync(upsert, [key, index, next[index]])
    }
    if (next.length < previous.length) {
      this.store.executeSync('DELETE FROM ' + table + ' WHERE ' + keyColumn + ' = ? AND list_order >= ?', [key, next.length])
    }
  }
}
