import { relationalStore } from '@kit.ArkData'
import type { PersistedCategoryDisplayStrategy, PersistedChapter, PersistedComic, PersistedLibraryCategory,
  PersistedLibraryStoreDocument, PersistedPage } from './LibraryPersistence'
import type { LibrarySmartCategory } from './LibrarySmartCategory'
import type { SyncLocalShelfMove } from '../deviceSync/DeviceSyncSignals'
import type { MihonImportRecord } from './MihonBackupReader'
import { shelfChapters, shelfPages, shelfWorks, shelfWorkDetails, ShelfChapterRow, ShelfPageRow, ShelfWorkRow } from './LibraryCoreRows'
import { appendMetadataItem, appendPageContent, metadataItems, metadataRow, shelfMemberships, shelfMetadataLists,
  ShelfSharedChapter, shelfSharedChapters, shelfSharedChaptersAll, shelfSharedChaptersLocal, shelfMembershipsAll, shelfMembershipsLocal,
  shelfPageBalloons, shelfPageKey, shelfPageLines, ShelfMembershipRow, ShelfPageBalloon, ShelfPageLine, ShelfWorkListValue, ShelfWorkMetadata } from './LibraryRelations'
import { orderShelfRows, readShelfMoves, readSmartCategories, shelfCategories, shelfCollectionRow, shelfCollections,
  shelfDisplayStrategies, shelfMoveCategories, shelfMoveCategoryRows, shelfMoves, shelfSmartCategories, shelfSmartFilters,
  smartFilterRows } from './LibraryListRows'
import { readMihonImports, ShelfMihonImports } from './LibraryMihonRows'
import { collectLocalRows, textColumn } from './LocalDataRows'
import { hasUserDataMigration } from './UserDataDatabase'
import { writeUserRecords } from './UserKeyedRecords'
import { sharedShelfIdentity, sharedShelfWork, ShelfSharedWork, shelfSharedWorks } from './ShelfSharedRows'
import { readShelfCategoryAliases, reconcileShelfCategoryIds } from './LibraryCategoryIdentity'

const OLD_MIGRATION = 'library-from-json-v1'
const MIGRATION = 'library-relational-v1'
const LIST_MASK_CATEGORIES = 1
const LIST_MASK_DISPLAY = 2
const LIST_MASK_SMART = 4
const LIST_MASK_MIHON = 8
const LIST_MASK_MOVES = 16

export interface LibraryReadingMetadata {
  comicId: string
  source: string
  work: string
  title?: string
  sourceName?: string
  path?: string
  cover?: string
  chapterId?: string
  chapterTitle?: string
}

export interface LibraryMembershipEdit {
  comicId: string
  categoryIds?: string[]
  updatedAt: number
}

// Undefined leaves an existing collection alone. Null is an absent collection,
// which must remain distinct from an explicitly empty collection on recovery.
export interface LibraryShelfSyncImage {
  present: boolean
  works: PersistedComic[]
  order?: string[]
  categories?: PersistedLibraryCategory[] | null
  displayStrategies?: PersistedCategoryDisplayStrategy[] | null
  smartCategories?: LibrarySmartCategory[] | null
  moves?: SyncLocalShelfMove[] | null
}

export interface LibraryShelfSyncEdits {
  comicIds: string[]
  unchangedCatalogs: string[]
  before: LibraryShelfSyncImage
  after: LibraryShelfSyncImage
}

function addToGroup<T>(groups: Map<string, T[]>, key: string, record: T): void {
  const rows = groups.get(key)
  if (rows === undefined) groups.set(key, [record])
  else rows.push(record)
}

function legacyGroup(rows: relationalStore.ResultSet): Map<string, string[]> {
  const groups = new Map<string, string[]>()
  try {
    while (rows.goToNextRow()) addToGroup(groups, rows.getString(0), rows.getString(1))
  } finally {
    rows.close()
  }
  return groups
}

function decodeLegacyList<T>(values: string[] | undefined): T[] {
  return (values ?? []).map((value: string): T => JSON.parse(value) as T)
}

async function oldShelf(transaction: relationalStore.Transaction): Promise<PersistedLibraryStoreDocument | undefined> {
  const header = await transaction.querySql('SELECT list_mask FROM library_document WHERE id = 1')
  let mask = -1
  try {
    if (header.goToNextRow()) mask = header.getLong(0)
  } finally {
    header.close()
  }
  if (mask < 0) return undefined
  const chapters = legacyGroup(await transaction.querySql(
    'SELECT comic_id, payload FROM library_chapters ORDER BY comic_id, list_order'))
  const memberships = legacyGroup(await transaction.querySql(
    'SELECT comic_id, category_id FROM library_memberships ORDER BY comic_id, list_order'))
  const lists = legacyGroup(await transaction.querySql('SELECT kind, payload FROM library_lists ORDER BY kind, list_order'))
  const works = collectLocalRows(await transaction.querySql(
    'SELECT id, payload, has_categories FROM library_works ORDER BY list_order'), (row: relationalStore.ResultSet): PersistedComic => {
    const id = row.getString(0)
    const work = JSON.parse(row.getString(1)) as PersistedComic
    work.chapters = decodeLegacyList<PersistedChapter>(chapters.get(id))
    work.categoryIds = row.getLong(2) === 0 ? undefined : memberships.get(id) ?? []
    return work
  })
  return { schemaVersion: 1, comics: works,
    customCategories: (mask & LIST_MASK_CATEGORIES) === 0 ? undefined :
      decodeLegacyList<PersistedLibraryCategory>(lists.get('categories')),
    categoryDisplayStrategies: (mask & LIST_MASK_DISPLAY) === 0 ? undefined :
      decodeLegacyList<PersistedCategoryDisplayStrategy>(lists.get('display')),
    smartCategories: (mask & LIST_MASK_SMART) === 0 ? undefined : decodeLegacyList<LibrarySmartCategory>(lists.get('smart')),
    mihonImports: (mask & LIST_MASK_MIHON) === 0 ? undefined : decodeLegacyList<MihonImportRecord>(lists.get('mihon')),
    syncShelfMoves: (mask & LIST_MASK_MOVES) === 0 ? undefined : decodeLegacyList<SyncLocalShelfMove>(lists.get('moves')),
  }
}

function allocateOccurrence(occurrences: Map<string, number>, id: string): number {
  const count = occurrences.get(id) ?? 0
  occurrences.set(id, count + 1)
  return count
}

function membershipRows(comicId: string, categoryIds?: string[]): ShelfMembershipRow[] {
  const occurrences = new Map<string, number>()
  return (categoryIds ?? []).map((categoryId: string, order: number): ShelfMembershipRow =>
    ({ comicId, categoryId, order, occurrence: allocateOccurrence(occurrences, categoryId) }))
}

function chapterKey(comicId: string, chapterId: string, occurrence: number): string {
  return JSON.stringify([comicId, chapterId, occurrence])
}

class ShelfWorkRows {
  private readonly works: ShelfWorkRow[] = []
  private readonly sharedWorks: ShelfSharedWork[] = []
  private readonly chapters: ShelfChapterRow[] = []
  private readonly pages: ShelfPageRow[] = []
  private readonly members: ShelfMembershipRow[] = []
  private readonly localMembers: ShelfMembershipRow[] = []
  private readonly metadataList: ShelfWorkListValue[] = []
  private readonly sharedChapters: ShelfSharedChapter[] = []
  private readonly localSharedChapters: ShelfSharedChapter[] = []
  private readonly lines: ShelfPageLine[] = []
  private readonly balloons: ShelfPageBalloon[] = []

  constructor(works: PersistedComic[], existingOrder?: number) {
    const ids = new Set<string>()
    works.forEach((work: PersistedComic, order: number): void => {
      if (ids.has(work.id)) throw new Error('library_duplicate_work')
      ids.add(work.id)
      this.works.push({ work, order: existingOrder ?? order, hasCategories: work.categoryIds !== undefined })
      const shared = sharedShelfWork(work)
      if (shared !== undefined) this.sharedWorks.push(shared)
      const metadata = metadataRow(work)
      metadataItems(metadata, this.metadataList)
      const catalog = shared?.hasSharedChapters === 1 ? this.sharedChapters : this.localSharedChapters
      metadata.sourceMetadata?.sharedChapterIds?.forEach((chapterId: string, chapterOrder: number): void => {
        catalog.push({ comicId: work.id, order: chapterOrder, chapterId })
      })
      const members = shared === undefined ? this.localMembers : this.members
      members.push(...membershipRows(work.id, work.categoryIds))
      const chapters = new Map<string, number>()
      work.chapters.forEach((chapter: PersistedChapter, index: number): void => {
        // Older snapshots may repeat a chapter ID. The occurrence within
        // that ID preserves those rows without using catalog position as identity.
        const occurrence = allocateOccurrence(chapters, chapter.id)
        this.chapters.push({ ownerId: work.id, chapter, occurrence, order: index })
        const pages = new Map<string, number>()
        chapter.pages.forEach((page: PersistedPage, position: number): void => {
          const row: ShelfPageRow = { ownerId: work.id, ownerChapterId: chapter.id, chapterOccurrence: occurrence,
            page, occurrence: allocateOccurrence(pages, page.id), order: position }
          this.pages.push(row)
          appendPageContent(row, this.lines, this.balloons)
        })
      })
    })
  }

  async importRows(transaction: relationalStore.Transaction): Promise<void> {
    await shelfWorkDetails.importRows(transaction, this.works)
    await shelfSharedWorks.importRows(transaction, this.sharedWorks)
    await shelfMetadataLists.importRows(transaction, this.metadataList)
    await shelfSharedChapters.importRows(transaction, this.sharedChapters)
    await shelfSharedChaptersLocal.importRows(transaction, this.localSharedChapters)
    await shelfMemberships.importRows(transaction, this.members)
    await shelfMembershipsLocal.importRows(transaction, this.localMembers)
    await shelfChapters.importRows(transaction, this.chapters)
    await shelfPages.importRows(transaction, this.pages)
    await shelfPageLines.importRows(transaction, this.lines)
    await shelfPageBalloons.importRows(transaction, this.balloons)
  }

  replace(store: relationalStore.RdbStore, comicId?: string, replaceCatalog: boolean = true): void {
    const scope = comicId === undefined ? undefined : 'comic_id'
    shelfWorkDetails.replace(store, this.works, scope, comicId)
    shelfSharedWorks.replace(store, this.sharedWorks, scope, comicId)
    shelfMetadataLists.replace(store, this.metadataList, scope, comicId)
    shelfSharedChapters.replace(store, this.sharedChapters, scope, comicId)
    shelfSharedChaptersLocal.replace(store, this.localSharedChapters, scope, comicId)
    shelfMemberships.replace(store, this.members, scope, comicId)
    shelfMembershipsLocal.replace(store, this.localMembers, scope, comicId)
    if (!replaceCatalog) return
    shelfChapters.replace(store, this.chapters, scope, comicId)
    shelfPages.replace(store, this.pages, scope, comicId)
    shelfPageLines.replace(store, this.lines, scope, comicId)
    shelfPageBalloons.replace(store, this.balloons, scope, comicId)
  }
}

function readWorkCatalogs(store: relationalStore.RdbStore, where?: string, args?: string[]): Map<string, PersistedChapter[]> {
  const pages = new Map<string, PersistedPage[]>()
  const byPage = new Map<string, PersistedPage>()
  for (const row of shelfPages.read(store, where, args)) {
    const key = shelfPageKey(row.ownerId, row.ownerChapterId, row.chapterOccurrence, row.page.id, row.occurrence)
    byPage.set(key, row.page)
    addToGroup(pages, chapterKey(row.ownerId, row.ownerChapterId, row.chapterOccurrence), row.page)
  }
  for (const row of shelfPageLines.read(store, where, args)) {
    byPage.get(shelfPageKey(row.comicId, row.chapterId, row.chapterOccurrence, row.pageId, row.pageOccurrence))
      ?.sourceText?.paragraphs.push(row.text)
  }
  for (const row of shelfPageBalloons.read(store, where, args)) {
    byPage.get(shelfPageKey(row.comicId, row.chapterId, row.chapterOccurrence, row.pageId, row.pageOccurrence))
      ?.sourceTextOverlay?.balloons.push(row.balloon)
  }
  const chapters = new Map<string, PersistedChapter[]>()
  for (const row of shelfChapters.read(store, where, args)) {
    row.chapter.pages = pages.get(chapterKey(row.ownerId, row.chapter.id, row.occurrence)) ?? []
    addToGroup(chapters, row.ownerId, row.chapter)
  }
  return chapters
}

function readWorks(store: relationalStore.RdbStore, comicId?: string, catalog: boolean = true): PersistedComic[] {
  const where = comicId === undefined ? undefined : 'comic_id = ?'
  const args = comicId === undefined ? undefined : [comicId]
  const chapters = catalog ? readWorkCatalogs(store, where, args) : undefined
  const memberships = new Map<string, string[]>()
  for (const row of shelfMembershipsAll.read(store, where, args)) addToGroup(memberships, row.comicId, row.categoryId)
  const workRows = shelfWorks.read(store, where, args)
  const details = new Map<string, ShelfWorkMetadata>()
  for (const row of workRows) details.set(row.work.id, metadataRow(row.work))
  for (const item of shelfMetadataLists.read(store, where, args)) {
    const owner = details.get(item.comicId)
    if (owner !== undefined) appendMetadataItem(owner, item)
  }
  for (const item of shelfSharedChaptersAll.read(store, where, args)) {
    details.get(item.comicId)?.sourceMetadata?.sharedChapterIds?.push(item.chapterId)
  }
  return workRows.map((row: ShelfWorkRow): PersistedComic => {
    const work = row.work
    // The shared row may omit the public work URL. Cold restore and cloud
    // publication must resolve the same source path from the source work ID.
    if (!work.sourcePath && work.sourceKind === 'private_library' && work.remoteServerId === undefined &&
      work.sourceRuntimeId !== undefined && work.remoteResourceId !== undefined &&
      sharedShelfIdentity(work.id, work.sourceRuntimeId, work.remoteResourceId)) {
      work.sourcePath = work.remoteResourceId
    }
    work.chapters = chapters?.get(work.id) ?? []
    work.categoryIds = memberships.get(work.id) ?? (row.hasCategories ? [] : undefined)
    return work
  })
}

async function hasMarker(transaction: relationalStore.Transaction, marker: string): Promise<boolean> {
  const rows = await transaction.querySql('SELECT name FROM local_data_migrations WHERE name = ?', [marker])
  try {
    return rows.goToNextRow()
  } finally {
    rows.close()
  }
}

/** Durable shelf columns back normal mutations; compatibility snapshots remain at existing callers. */
export class LibraryRdbStorage {
  private readonly store: relationalStore.RdbStore
  private writeRevision: number = 0

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  currentWriteRevision(): number {
    return this.writeRevision
  }

  migrated(): boolean {
    return hasUserDataMigration(this.store, MIGRATION)
  }

  usesPreviousDatabase(): boolean {
    return hasUserDataMigration(this.store, OLD_MIGRATION)
  }

  async migrate(legacy?: PersistedLibraryStoreDocument): Promise<void> {
    const transaction = await this.store.createTransaction({ transactionType: relationalStore.TransactionType.IMMEDIATE })
    try {
      if (!await hasMarker(transaction, MIGRATION)) {
        const document = await hasMarker(transaction, OLD_MIGRATION) ? await oldShelf(transaction) : legacy
        if (document !== undefined) {
          await new ShelfWorkRows(document.comics).importRows(transaction)
          await shelfCategories.importRows(transaction, orderShelfRows(document.customCategories))
          await shelfDisplayStrategies.importRows(transaction, orderShelfRows(document.categoryDisplayStrategies))
          await shelfSmartCategories.importRows(transaction, orderShelfRows(document.smartCategories))
          await shelfSmartFilters.importRows(transaction, smartFilterRows(document.smartCategories))
          await shelfMoves.importRows(transaction, orderShelfRows(document.syncShelfMoves))
          await shelfMoveCategories.importRows(transaction, shelfMoveCategoryRows(document.syncShelfMoves))
          await new ShelfMihonImports(document.mihonImports ?? []).importRows(transaction)
          await shelfCollections.importRows(transaction, [shelfCollectionRow(document)])
        }
        await transaction.execute('INSERT INTO local_data_migrations (name) VALUES (?)', [MIGRATION])
      }
      await transaction.commit()
    } catch (error) {
      await transaction.rollback()
      throw error as Error
    }
  }

  read(): PersistedLibraryStoreDocument | undefined {
    return this.readDocument(true)
  }

  /** WebDAV shares chapter identities from work metadata. Local chapter and
   * page rows and Mihon originals belong to the device and backup. */
  readShelfSync(): PersistedLibraryStoreDocument | undefined {
    return this.readDocument(false)
  }

  private readDocument(catalog: boolean): PersistedLibraryStoreDocument | undefined {
    const header = shelfCollections.read(this.store)[0]
    if (header === undefined) return undefined
    return { schemaVersion: 1, comics: readWorks(this.store, undefined, catalog),
      customCategories: header.categories ? shelfCategories.read(this.store).map(row => row.entry) : undefined,
      categoryDisplayStrategies: header.display ? shelfDisplayStrategies.read(this.store).map(row => row.entry) : undefined,
      smartCategories: header.smart ? readSmartCategories(this.store) : undefined,
      mihonImports: catalog && header.mihon ? readMihonImports(this.store) : undefined,
      syncShelfMoves: header.moves ? readShelfMoves(this.store) : undefined,
    }
  }

  readWork(comicId: string, catalog: boolean = true): PersistedComic | undefined {
    return readWorks(this.store, comicId, catalog)[0]
  }

  categoryAliases(): Map<string, string> {
    return readShelfCategoryAliases(this.store)
  }

  migrateCategoryIds(): void {
    let changed = false
    writeUserRecords(this.store, (): void => {
      const identities = reconcileShelfCategoryIds(this.store, true)
      changed = identities.categoryIdsChanged || identities.comicIds.size > 0
    })
    if (changed) this.writeRevision += 1
  }

  cloudShelfEdits(comicIds: string[], categories: boolean, smart: boolean,
    removedCategoryIds: string[] = []): LibraryShelfSyncEdits {
    const affected = new Set(comicIds)
    let categoryIdsChanged = false
    writeUserRecords(this.store, (): void => {
      const identities = reconcileShelfCategoryIds(this.store, false)
      categoryIdsChanged = identities.categoryIdsChanged
      identities.comicIds.forEach((id: string): void => { affected.add(id) })
      // A download can populate an empty library. Keep its collection flags
      // with the affected rows so the same data is found on cold startup.
      const header = shelfCollections.read(this.store)[0]
      if (header === undefined || (categories && !header.categories) || (smart && !header.smart)) {
        const updated = header ?? shelfCollectionRow({ schemaVersion: 1, comics: [] })
        updated.categories ||= categories
        updated.smart ||= smart
        shelfCollections.put(this.store, updated)
      }
      // Match the ordinary category deletion. ArkData can deliver the
      // category before its memberships, including device-only memberships.
      for (const id of removedCategoryIds) {
        const category = shelfCategories.read(this.store, 'category_id = ?', [id])
        if (category.length !== 0) continue
        for (const table of ['shelf_memberships', 'shelf_memberships_local']) {
          const rows = this.store.querySqlSync('SELECT DISTINCT comic_id FROM ' + table + ' WHERE category_id = ?', [id])
          try {
            while (rows.goToNextRow()) affected.add(rows.getString(0))
          } finally { rows.close() }
          this.store.executeSync('DELETE FROM ' + table + ' WHERE category_id = ?', [id])
        }
        this.store.executeSync('DELETE FROM shelf_category_display_strategies WHERE category_id = ?', [id])
      }
      for (const comicId of affected) {
        // An incoming favorite only has shared business fields. Device
        // metadata and local chapter caches stay under their existing owner.
        this.store.executeSync('INSERT OR IGNORE INTO shelf_work_details ' +
          '(comic_id, list_order, has_categories, source_kind, sort_title, preferred_direction, chapter_count, page_count, ' +
          'created_at, updated_at, last_imported_at, has_local_metadata, has_local_authors, has_source_metadata, has_source_tags, ' +
          'has_excluded_chapters, has_shared_chapters, shared_scope) SELECT comic_id, ' +
          '(SELECT COALESCE(MAX(list_order), -1) + 1 FROM shelf_work_details), 1, \'private_library\', COALESCE(title, \'\'), \'left_to_right\', ' +
          '0, 0, ?, ?, ?, 0, 0, 1, 0, 0, 0, 1 FROM shelf_works WHERE comic_id = ?',
          [Date.now(), Date.now(), Date.now(), comicId])
      }
    })
    // A new shared work and its local details must both be visible to the
    // read connection before the live shelf treats it as a favorite.
    const works: PersistedComic[] = []
    for (const comicId of affected) {
      const work = this.readWork(comicId, false)
      if (work === undefined) continue
      if (!work.sortTitle) work.sortTitle = work.title
      works.push(work)
    }
    comicIds = Array.from(affected)
    const after: LibraryShelfSyncImage = { present: true, works,
      categories: categories || categoryIdsChanged ? shelfCategories.read(this.store).map(row => row.entry) : undefined,
      displayStrategies: removedCategoryIds.length > 0 || categoryIdsChanged ?
        shelfDisplayStrategies.read(this.store).map(row => row.entry) : undefined,
      smartCategories: smart || categoryIdsChanged ? readSmartCategories(this.store) : undefined,
      moves: categoryIdsChanged ? readShelfMoves(this.store) : undefined }
    this.writeRevision += 1
    return { comicIds, unchangedCatalogs: comicIds, before: { present: true, works: [] }, after }
  }

  /** Reading sync joins only its work identifiers and the saved chapter's label.
   * Opening the reader or recording progress must never reconstruct the shelf. */
  readReadingMetadata(comicId?: string, chapterId?: string): LibraryReadingMetadata[] {
    const scope = comicId === undefined
      ? '(SELECT comic_id FROM reader_current_positions_all UNION SELECT comic_id FROM reader_chapter_states_all)'
      : '(SELECT ? AS comic_id)'
    const chapter = chapterId === undefined ? 'COALESCE(p.chapter_id, local.chapter_id)' : '?'
    const args: string[] = []
    if (chapterId !== undefined) args.push(chapterId)
    if (comicId !== undefined) args.push(comicId)
    // Occurrence zero is the first title in older catalogs with duplicate IDs.
    const rows = this.store.querySqlSync('SELECT work.*, (SELECT c.title FROM shelf_chapters c ' +
      'WHERE c.comic_id = work.comic_id AND c.chapter_id = work.saved_chapter AND c.chapter_occurrence = 0) ' +
      'FROM (SELECT w.comic_id, w.source_runtime_id, w.remote_resource_id, w.title, ' +
      'CASE WHEN w.has_source_metadata != 0 THEN w.source_name END, w.source_path, ' +
      'COALESCE(w.source_cover_uri, CASE WHEN w.custom_cover_uri IS NULL THEN w.cover_uri END), ' +
      chapter + ' AS saved_chapter ' +
      'FROM ' + scope + ' r CROSS JOIN shelf_works_all w ON w.comic_id = r.comic_id ' +
      'LEFT JOIN reader_current_positions p ON p.comic_id = w.comic_id ' +
      'LEFT JOIN reader_current_positions_local local ON local.comic_id = w.comic_id ' +
      'WHERE w.source_runtime_id IS NOT NULL AND w.remote_resource_id IS NOT NULL) work ORDER BY work.comic_id', args)
    return collectLocalRows(rows, (row: relationalStore.ResultSet): LibraryReadingMetadata => ({
      comicId: row.getString(0), source: row.getString(1), work: row.getString(2), title: textColumn(row, 3),
      sourceName: textColumn(row, 4), path: textColumn(row, 5), cover: textColumn(row, 6),
      chapterId: textColumn(row, 7), chapterTitle: textColumn(row, 8),
    }))
  }

  save(document: PersistedLibraryStoreDocument | undefined): void {
    writeUserRecords(this.store, (): void => {
      new ShelfWorkRows(document?.comics ?? []).replace(this.store)
      shelfCategories.replace(this.store, orderShelfRows(document?.customCategories))
      shelfDisplayStrategies.replace(this.store, orderShelfRows(document?.categoryDisplayStrategies))
      shelfSmartCategories.replace(this.store, orderShelfRows(document?.smartCategories))
      shelfSmartFilters.replace(this.store, smartFilterRows(document?.smartCategories))
      shelfMoves.replace(this.store, orderShelfRows(document?.syncShelfMoves))
      shelfMoveCategories.replace(this.store, shelfMoveCategoryRows(document?.syncShelfMoves))
      new ShelfMihonImports(document?.mihonImports ?? []).replace(this.store)
      shelfCollections.replace(this.store, document === undefined ? [] : [shelfCollectionRow(document)])
    })
    this.writeRevision += 1
  }

  private existingWorkOrder(comicId: string): number {
    const result = this.store.querySqlSync('SELECT list_order FROM shelf_work_details WHERE comic_id = ?', [comicId])
    try {
      if (!result.goToNextRow()) throw new Error('library_work_missing')
      return result.getLong(0)
    } finally {
      result.close()
    }
  }

  saveExistingWorks(comics: PersistedComic[]): void {
    writeUserRecords(this.store, (): void => {
      for (const comic of comics) {
        new ShelfWorkRows([comic], this.existingWorkOrder(comic.id)).replace(this.store, comic.id)
      }
    })
    this.writeRevision += 1
  }

  saveMemberships(edits: LibraryMembershipEdit[]): void {
    writeUserRecords(this.store, (): void => {
      for (const edit of edits) {
        const result = this.store.querySqlSync('SELECT s.comic_id FROM shelf_work_details d LEFT JOIN shelf_works s ' +
          'ON s.comic_id = d.comic_id WHERE d.comic_id = ?', [edit.comicId])
        let shared: boolean
        try {
          if (!result.goToNextRow()) throw new Error('library_work_missing')
          shared = !result.isColumnNull(0)
        } finally {
          result.close()
        }
        // The category editor owns these columns and the selected works' memberships.
        this.store.executeSync('UPDATE shelf_work_details SET has_categories = ?, updated_at = ? WHERE comic_id = ?',
          [edit.categoryIds === undefined ? 0 : 1, edit.updatedAt, edit.comicId])
        const table = shared ? shelfMemberships : shelfMembershipsLocal
        table.replace(this.store, membershipRows(edit.comicId, edit.categoryIds), 'comic_id', edit.comicId)
      }
    })
    this.writeRevision += 1
  }

  saveSyncEdits(edits: LibraryShelfSyncEdits, image: LibraryShelfSyncImage): void {
    const unchanged = new Set(edits.unchangedCatalogs)
    writeUserRecords(this.store, (): void => {
      const works = new Map<string, PersistedComic>(image.works.map((work: PersistedComic): [string, PersistedComic] =>
        [work.id, work]))
      const order = new Map<string, number>()
      image.order?.forEach((id: string, position: number): void => { order.set(id, position) })
      for (const id of edits.comicIds) {
        const work = works.get(id)
        if (work === undefined) new ShelfWorkRows([]).replace(this.store, id)
        else new ShelfWorkRows([work], order.get(id) ?? this.existingWorkOrder(id)).replace(this.store, id, !unchanged.has(id))
      }
      if (image.order !== undefined) this.saveSyncWorkOrder(image.order)
      this.saveSyncCollections(image)
    })
    this.writeRevision += 1
  }

  private saveSyncWorkOrder(order: string[]): void {
    // Only ordinal columns are involved when an insert or delete shifts ranks.
    for (let start = 0; start < order.length; start += 180) {
      const ids = order.slice(start, start + 180)
      const cases = ids.map((): string => 'WHEN ? THEN ?').join(' ')
      const when: (string | number)[] = []
      ids.forEach((id: string, offset: number): void => { when.push(id, start + offset) })
      this.store.executeSync('UPDATE shelf_work_details SET list_order = CASE comic_id ' + cases +
        ' END WHERE comic_id IN (' + ids.map((): string => '?').join(',') +
        ') AND list_order IS NOT CASE comic_id ' + cases + ' END', [...when, ...ids, ...when])
    }
  }

  private saveSyncCollections(image: LibraryShelfSyncImage): void {
    const current = shelfCollections.read(this.store)[0] ?? shelfCollectionRow({ schemaVersion: 1, comics: [] })
    if (image.categories !== undefined) {
      current.categories = image.categories !== null
      shelfCategories.replace(this.store, orderShelfRows(image.categories ?? undefined))
    }
    if (image.displayStrategies !== undefined) {
      current.display = image.displayStrategies !== null
      shelfDisplayStrategies.replace(this.store, orderShelfRows(image.displayStrategies ?? undefined))
    }
    if (image.smartCategories !== undefined) {
      current.smart = image.smartCategories !== null
      shelfSmartCategories.replace(this.store, orderShelfRows(image.smartCategories ?? undefined))
      shelfSmartFilters.replace(this.store, smartFilterRows(image.smartCategories ?? undefined))
    }
    if (image.moves !== undefined) {
      current.moves = image.moves !== null
      shelfMoves.replace(this.store, orderShelfRows(image.moves ?? undefined))
      shelfMoveCategories.replace(this.store, shelfMoveCategoryRows(image.moves ?? undefined))
    }
    if (image.present) shelfCollections.put(this.store, current)
    else shelfCollections.remove(this.store, [1])
  }
}
