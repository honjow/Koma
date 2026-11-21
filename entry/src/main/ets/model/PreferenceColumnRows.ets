import type { relationalStore } from '@kit.ArkData'
import { hasUserDataMigration, markUserDataMigration } from './UserDataDatabase'
import { booleanValue, collectLocalRows, LocalColumnValue } from './LocalDataRows'
import { readLibraryUpdateReport, REPORT_JOB_KEY, REPORT_RESULT_KEY, writeLibraryUpdateReport } from './LibraryUpdateReportRows'
import { UserKeyedRecords, UserRecordValues, writeUserRecords } from './UserKeyedRecords'
import { READER_GLOBAL_DOMAIN, readReaderPreferenceColumns, readerPreferenceWrite } from './ReaderPreferenceColumns'

interface PreferenceField {
  name: string
  column: string
  type: string
}

interface PreferenceLayout {
  table: string
  keyColumn: string
  fields: PreferenceField[]
  ordered?: boolean
  chapters?: boolean
  presenceColumn?: string
}

function field(name: string, column: string, type: string): PreferenceField {
  return { name, column, type }
}

function layoutFor(key: string): PreferenceLayout | undefined {
  if (key === 'chapterList.overrides.v1') return { table: 'book_preferences', keyColumn: 'comic_id',
    presenceColumn: 'has_chapter_settings', fields: [
    field('sortBasis', 'sort_basis', 'string'), field('sortDirection', 'sort_direction', 'string'),
    field('readFilter', 'read_filter', 'string'), field('languageFilter', 'language_filter', 'string'),
    field('groupFilter', 'group_filter', 'string'), field('bookmarkFilter', 'bookmark_filter', 'string'),
  ] }
  if (key === 'reader.seriesModeOverrides.v1') return { table: 'book_preferences', keyColumn: 'comic_id',
    presenceColumn: 'has_reader_mode', fields: [
    field('pageMode', 'page_mode', 'string'), field('readingDirection', 'reading_direction', 'string'),
  ] }
  if (key === 'tracker.comicMappings') return { table: 'tracker_mappings', keyColumn: 'binding_key', ordered: true, fields: [
    field('comicId', 'comic_id', 'string'), field('providerId', 'provider_id', 'string'),
    field('providerTitleId', 'provider_title_id', 'string'), field('providerTitle', 'provider_title', 'string'),
    field('mappingState', 'mapping_state', 'string'), field('confidence', 'confidence', 'number'),
    field('userConfirmed', 'user_confirmed', 'boolean'), field('createdAt', 'created_at', 'number'),
    field('updatedAt', 'updated_at', 'number'),
  ] }
  if (key === 'tracker.pendingProgressQueue') return { table: 'tracker_progress_outbox', keyColumn: 'operation_key', ordered: true,
    chapters: true, fields: [
      field('providerId', 'provider_id', 'string'), field('comicId', 'comic_id', 'string'), field('chapterId', 'chapter_id', 'string'),
      field('trigger', 'trigger_kind', 'string'), field('pageIndex', 'page_index', 'number'), field('totalPages', 'total_pages', 'number'),
      field('progressRatio', 'progress_ratio', 'number'), field('completed', 'completed', 'boolean'),
      field('providerProgress', 'provider_progress', 'number'), field('attempts', 'attempts', 'number'),
      field('firstQueuedAt', 'first_queued_at', 'number'), field('updatedAt', 'updated_at', 'number'),
      field('lastReason', 'last_reason', 'string'),
    ] }
  if (key === 'libraryUpdate.chapterUpdatesJson') return { table: 'library_chapter_discoveries', keyColumn: 'discovery_key',
    ordered: true, fields: [field('comicId', 'comic_id', 'string'), field('chapterId', 'chapter_id', 'string'),
      field('discoveredAt', 'discovered_at', 'number')] }
  return undefined
}

interface OrderedRecord {
  order: number
  value: Record<string, Object>
}

interface EncodedPreference {
  key: string
  value: string
}

function scalarFromRow(row: relationalStore.ResultSet, lists: Map<string, string[]>): string {
  const type = row.getString(1)
  if (type === 'string') return JSON.stringify(row.getString(2))
  if (type === 'number') return JSON.stringify(row.getDouble(3))
  if (type === 'boolean') return row.getLong(4) === 0 ? 'false' : 'true'
  if (type === 'list') return JSON.stringify(lists.get(row.getString(0)) ?? [])
  if (type === 'null') return 'null'
  throw new Error('unexpected_scalar_preference_type')
}

/** Existing Preferences codecs still read the portable value at API boundaries.
 * The database stores individual fields for records the host fully defines.
 */
export class PreferenceColumnRows {
  private readonly store: relationalStore.RdbStore
  private readonly domain: string
  private readonly marker: string
  private readonly layout?: PreferenceLayout
  private readonly previous: UserKeyedRecords
  private readonly bookScalar?: string

  constructor(store: relationalStore.RdbStore, name: string, key: string) {
    this.store = store
    this.domain = 'preferences/' + name + '/' + key
    this.marker = 'preference-columns/' + this.domain
    this.layout = layoutFor(key)
    if (name === 'koma_reader_preferences_v1' && key === 'reader.bannerFilterOverrides.v1') {
      this.bookScalar = 'banner_filter'
    }
    if (name === 'koma_manga_synopsis_v1' && key === '') this.bookScalar = 'synopsis_expanded'
    this.previous = new UserKeyedRecords(store, this.domain)
  }

  isMigrated(): boolean {
    return hasUserDataMigration(this.store, this.marker)
  }

  usesPreviousDatabase(): boolean {
    return this.previous.isMigrated()
  }

  migrate(fromPreferences: UserRecordValues | undefined): void {
    writeUserRecords(this.store, (): void => {
      if (this.isMigrated()) return
      this.replaceInTransaction(this.previous.isMigrated() ? this.previous.entries() : fromPreferences)
      markUserDataMigration(this.store, this.marker)
    })
  }

  private collectionExists(): boolean {
    const rows = this.store.querySqlSync('SELECT domain FROM typed_preference_collections WHERE domain = ?', [this.domain])
    try {
      return rows.goToNextRow()
    } finally {
      rows.close()
    }
  }

  private ensureCollection(): void {
    this.store.executeSync('INSERT OR IGNORE INTO typed_preference_collections (domain) VALUES (?)', [this.domain])
  }

  private rows(key?: string): EncodedPreference[] {
    const bookScalar = this.bookScalar
    if (bookScalar !== undefined) {
      const predicate = key === undefined ? '' : ' AND comic_id = ?'
      return collectLocalRows(this.store.querySqlSync('SELECT comic_id, ' + bookScalar + ' FROM book_preferences WHERE ' +
        bookScalar + ' IS NOT NULL' + predicate + ' ORDER BY rowid', key === undefined ? undefined : [key]),
      (row: relationalStore.ResultSet): EncodedPreference => ({
        key: row.getString(0), value: JSON.stringify(bookScalar === 'banner_filter' ? row.getString(1) : row.getLong(1) !== 0),
      }))
    }
    const layout = this.layout
    if (layout === undefined) {
      const predicate = key === undefined ? '' : ' AND preference_id = ?'
      const result = this.store.querySqlSync('SELECT preference_id, value_kind, value_text, value_number, value_boolean ' +
        'FROM typed_local_preferences WHERE domain = ?' + predicate + ' ORDER BY rowid',
        key === undefined ? [this.domain] : [this.domain, key])
      const lists = this.preferenceLists(key)
      const entries = collectLocalRows(result, (row: relationalStore.ResultSet): EncodedPreference =>
        ({ key: row.getString(0), value: scalarFromRow(row, lists) }))
      if (this.domain === READER_GLOBAL_DOMAIN) {
        readReaderPreferenceColumns(this.store, key).forEach((value: string, id: string): void => {
          entries.push({ key: id, value })
        })
      }
      if (this.domain === 'preferences/koma_library_update_results_v1/') {
        for (const report of [REPORT_RESULT_KEY, REPORT_JOB_KEY]) {
          if (key !== undefined && key !== report) continue
          const value = readLibraryUpdateReport(this.store, report)
          if (value !== undefined) entries.push({ key: report, value })
        }
      }
      return entries
    }
    const extras = (layout.ordered ? ', list_order' : '') + (layout.chapters ? ', has_chapters' : '')
    const presence = layout.presenceColumn === undefined ? '' : ' WHERE ' + layout.presenceColumn + '=1'
    const keyFilter = key === undefined ? '' : (presence === '' ? ' WHERE ' : ' AND ') + layout.keyColumn + ' = ?'
    const result = this.store.querySqlSync('SELECT ' + layout.keyColumn + ', ' +
      layout.fields.map((column: PreferenceField): string => column.column).join(', ') + extras + ' FROM ' + layout.table +
      presence + keyFilter + ' ORDER BY rowid',
      key === undefined ? undefined : [key])
    const chapters = layout.chapters ? this.chapterIds(key) : new Map<string, string[]>()
    return collectLocalRows(result, (row: relationalStore.ResultSet): EncodedPreference => {
      const rowKey = row.getString(0)
      const value: Record<string, Object> = {}
      layout.fields.forEach((column: PreferenceField, index: number): void => {
        const i = index + 1
        if (row.isColumnNull(i)) return
        if (column.type === 'boolean') value[column.name] = row.getLong(i) !== 0
        else if (column.type === 'number') value[column.name] = row.getDouble(i)
        else value[column.name] = row.getString(i)
      })
      if (layout.chapters && row.getLong(layout.fields.length + 2) !== 0) value['chapterIds'] = chapters.get(rowKey) ?? []
      if (!layout.ordered) return { key: rowKey, value: JSON.stringify(value) }
      const record: OrderedRecord = { order: row.getLong(layout.fields.length + 1), value }
      return { key: rowKey, value: JSON.stringify(record) }
    })
  }

  private preferenceLists(key?: string): Map<string, string[]> {
    const args = key === undefined ? [this.domain] : [this.domain, key]
    const predicate = key === undefined ? '' : ' AND preference_id = ?'
    const rows = this.store.querySqlSync('SELECT preference_id, item_text FROM typed_local_preference_items WHERE domain = ?' +
      predicate + ' ORDER BY preference_id, item_order', args)
    const lists = new Map<string, string[]>()
    try {
      while (rows.goToNextRow()) {
        const id = rows.getString(0)
        const items = lists.get(id)
        if (items === undefined) lists.set(id, [rows.getString(1)])
        else items.push(rows.getString(1))
      }
    } finally {
      rows.close()
    }
    return lists
  }

  private chapterIds(key?: string): Map<string, string[]> {
    const rows = this.store.querySqlSync('SELECT operation_key, chapter_id FROM tracker_outbox_chapters' +
      (key === undefined ? '' : ' WHERE operation_key = ?') + ' ORDER BY chapter_order', key === undefined ? undefined : [key])
    const ids = new Map<string, string[]>()
    try {
      while (rows.goToNextRow()) {
        const operation = rows.getString(0)
        const chapters = ids.get(operation)
        if (chapters === undefined) ids.set(operation, [rows.getString(1)])
        else chapters.push(rows.getString(1))
      }
    } finally {
      rows.close()
    }
    return ids
  }

  get(key: string): string | undefined {
    return this.rows(key)[0]?.value
  }

  entries(): UserRecordValues | undefined {
    if (!this.collectionExists()) return undefined
    const entries: UserRecordValues = new Map()
    for (const row of this.rows()) entries.set(row.key, row.value)
    return entries
  }

  put(key: string, raw: string | undefined): void {
    writeUserRecords(this.store, (): void => this.putInTransaction(key, raw))
  }

  putInTransaction(key: string, raw: string | undefined): void {
    const layout = this.layout
    const bookScalar = this.bookScalar
    if (bookScalar !== undefined) {
      if (raw === undefined) {
        this.store.executeSync('UPDATE book_preferences SET ' + bookScalar + '=NULL WHERE comic_id=?', [key])
        this.deleteEmptyBookPreferences(key)
      } else {
        const value = JSON.parse(raw) as Object
        this.ensureCollection()
        this.store.executeSync('INSERT INTO book_preferences (comic_id, ' + bookScalar + ') VALUES (?, ?) ' +
          'ON CONFLICT(comic_id) DO UPDATE SET ' + bookScalar + '=excluded.' + bookScalar,
          [key, bookScalar === 'banner_filter' ? value as string : booleanValue(value === true)])
      }
      return
    }
    if (this.domain === READER_GLOBAL_DOMAIN) {
      const reader = readerPreferenceWrite(key, raw)
      if (reader !== undefined) {
        if (raw !== undefined) this.ensureCollection()
        this.store.executeSync(reader.sql, reader.values)
        return
      }
    }
    if (this.domain === 'preferences/koma_library_update_results_v1/' &&
      (key === REPORT_RESULT_KEY || key === REPORT_JOB_KEY)) {
      if (raw !== undefined) this.ensureCollection()
      writeLibraryUpdateReport(this.store, key, raw)
      return
    }
    if (raw === undefined) {
      if (layout === undefined) {
        this.store.executeSync('DELETE FROM typed_local_preference_items WHERE domain = ? AND preference_id = ?', [this.domain, key])
        this.store.executeSync('DELETE FROM typed_local_preferences WHERE domain = ? AND preference_id = ?', [this.domain, key])
      } else {
        if (layout.chapters) this.store.executeSync('DELETE FROM tracker_outbox_chapters WHERE operation_key = ?', [key])
        const presence = layout.presenceColumn
        if (presence === undefined) {
          this.store.executeSync('DELETE FROM ' + layout.table + ' WHERE ' + layout.keyColumn + ' = ?', [key])
        } else {
          const cleared = layout.fields.map((field: PreferenceField): string => field.column + '=NULL').join(', ')
          this.store.executeSync('UPDATE book_preferences SET ' + cleared + ', ' + presence + '=0 WHERE comic_id=?', [key])
          this.deleteEmptyBookPreferences(key)
        }
      }
      return
    }
    this.ensureCollection()
    if (layout === undefined) this.putScalar(key, raw)
    else this.putRecord(layout, key, raw)
  }

  private deleteEmptyBookPreferences(key: string): void {
    this.store.executeSync('DELETE FROM book_preferences WHERE comic_id=? AND has_chapter_settings=0 AND ' +
      'has_reader_mode=0 AND banner_filter IS NULL AND synopsis_expanded IS NULL', [key])
  }

  private putScalar(key: string, raw: string): void {
    const value = JSON.parse(raw) as Object
    const type = value === null ? 'null' : Array.isArray(value) ? 'list' : typeof value
    if (!['null', 'list', 'string', 'number', 'boolean'].includes(type)) throw new Error('unexpected_scalar_preference_type')
    this.store.executeSync('INSERT INTO typed_local_preferences (domain, preference_id, value_kind, value_text, ' +
      'value_number, value_boolean) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(domain, preference_id) DO UPDATE SET ' +
      'value_kind=excluded.value_kind, value_text=excluded.value_text, value_number=excluded.value_number, ' +
      'value_boolean=excluded.value_boolean',
      [this.domain, key, type, typeof value === 'string' ? value : null, typeof value === 'number' ? value : null,
        typeof value === 'boolean' ? booleanValue(value) : null])
    this.store.executeSync('DELETE FROM typed_local_preference_items WHERE domain = ? AND preference_id = ?', [this.domain, key])
    if (Array.isArray(value)) {
      (value as string[]).forEach((item: string, order: number): void => {
        if (typeof item !== 'string') throw new Error('unexpected_local_preference_item')
        this.store.executeSync('INSERT INTO typed_local_preference_items (domain, preference_id, item_order, item_text) ' +
          'VALUES (?, ?, ?, ?)', [this.domain, key, order, item])
      })
    }
  }

  private putRecord(layout: PreferenceLayout, key: string, raw: string): void {
    const parsed = JSON.parse(raw) as Object
    const value = layout.ordered ? (parsed as OrderedRecord).value : parsed as Record<string, Object>
    const columns = layout.fields.map((column: PreferenceField): string => column.column)
    const args: LocalColumnValue[] = [key]
    for (const column of layout.fields) {
      const item = value[column.name]
      if (typeof item === 'string' || typeof item === 'number') args.push(item)
      else args.push(typeof item === 'boolean' ? booleanValue(item) : null)
    }
    if (layout.ordered) {
      columns.push('list_order')
      args.push((parsed as OrderedRecord).order)
    }
    const chapterIds = layout.chapters ? value['chapterIds'] as string[] | undefined : undefined
    if (layout.chapters) {
      columns.push('has_chapters')
      args.push(booleanValue(chapterIds !== undefined))
    }
    if (layout.presenceColumn !== undefined) {
      columns.push(layout.presenceColumn)
      args.push(1)
    }
    this.store.executeSync('INSERT INTO ' + layout.table + ' (' + layout.keyColumn + ', ' + columns.join(', ') +
      ') VALUES (' + args.map((): string => '?').join(', ') + ') ON CONFLICT(' + layout.keyColumn + ') DO UPDATE SET ' +
      columns.map((column: string): string => column + '=excluded.' + column).join(', '), args)
    if (layout.chapters) {
      this.store.executeSync('DELETE FROM tracker_outbox_chapters WHERE operation_key = ?', [key])
      chapterIds?.forEach((chapterId: string, order: number): void => {
        this.store.executeSync('INSERT INTO tracker_outbox_chapters (operation_key, chapter_order, chapter_id) VALUES (?, ?, ?)',
          [key, order, chapterId])
      })
    }
  }

  replace(values: UserRecordValues | undefined): void {
    writeUserRecords(this.store, (): void => this.replaceInTransaction(values))
  }

  replaceInTransaction(values: UserRecordValues | undefined): void {
    const previous = this.entries()
    previous?.forEach((_value: string, key: string): void => {
      if (!values?.has(key)) this.putInTransaction(key, undefined)
    })
    if (values === undefined) {
      this.store.executeSync('DELETE FROM typed_preference_collections WHERE domain = ?', [this.domain])
    } else {
      this.ensureCollection()
      this.mergeInTransaction(values, previous)
    }
  }

  mergeInTransaction(values: UserRecordValues, previous: UserRecordValues | undefined = this.entries()): void {
    this.ensureCollection()
    values.forEach((value: string, key: string): void => {
      if (value !== previous?.get(key)) this.putInTransaction(key, value)
    })
  }
}
