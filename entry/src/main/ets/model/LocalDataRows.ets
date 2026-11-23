import { relationalStore } from '@kit.ArkData'

export type LocalColumnValue = string | number | null

export function textColumn(rows: relationalStore.ResultSet, index: number): string | undefined {
  return rows.isColumnNull(index) ? undefined : rows.getString(index)
}

export function integerColumn(rows: relationalStore.ResultSet, index: number): number | undefined {
  return rows.isColumnNull(index) ? undefined : rows.getLong(index)
}

export function realColumn(rows: relationalStore.ResultSet, index: number): number | undefined {
  return rows.isColumnNull(index) ? undefined : rows.getDouble(index)
}

export function booleanColumn(rows: relationalStore.ResultSet, index: number): boolean | undefined {
  const value = integerColumn(rows, index)
  return value === undefined ? undefined : value !== 0
}

export function booleanValue(value: boolean | undefined): number | null {
  return value === undefined ? null : (value ? 1 : 0)
}

/** Copy a hot catalog row across ArkData once. Fall back to the original
 * cursor conversion for older values stored with a different SQLite type. */
export class LocalRecord {
  private readonly values: relationalStore.RowData
  private readonly row: relationalStore.ResultSet

  constructor(row: relationalStore.ResultSet) {
    this.row = row
    this.values = row.getCurrentRowData()
  }

  string(index: number): string {
    const value = this.values[index]
    return typeof value === 'string' ? value : this.row.getString(index)
  }

  text(index: number): string | undefined {
    return this.values[index] === null ? undefined : this.string(index)
  }

  long(index: number): number {
    const value = this.values[index]
    return typeof value === 'number' && Number.isSafeInteger(value) ? value : this.row.getLong(index)
  }

  integer(index: number): number | undefined {
    return this.values[index] === null ? undefined : this.long(index)
  }

  real(index: number): number | undefined {
    const value = this.values[index]
    return value === null ? undefined : typeof value === 'number' ? value : this.row.getDouble(index)
  }

  boolean(index: number): boolean | undefined {
    const value = this.integer(index)
    return value === undefined ? undefined : value !== 0
  }
}

export function collectLocalRows<T>(rows: relationalStore.ResultSet, decode: (row: relationalStore.ResultSet) => T): T[] {
  const result: T[] = []
  try {
    while (rows.goToNextRow()) result.push(decode(rows))
  } finally {
    rows.close()
  }
  return result
}

/** Shared SQL for replacing ordered owner snapshots. The owner defines each physical column and its key. */
export class LocalDataRows<T> {
  private readonly select: string
  private readonly orderBy: string
  private readonly upsert: string
  private readonly insertPrefix: string
  private readonly orderedInsertPrefix: string
  private readonly valueSlots: string
  private readonly conflictClause: string
  private readonly columnCount: number
  private readonly selectKeys: string
  private readonly deleteKey: string
  private readonly deleteRows: string
  private readonly keyCount: number
  private readonly encode: (record: T) => LocalColumnValue[]
  private readonly decode: (row: relationalStore.ResultSet) => T

  constructor(table: string, keys: string[], fields: string[], order: string,
    encode: (record: T) => LocalColumnValue[], decode: (row: relationalStore.ResultSet) => T) {
    const columns = keys.concat(fields)
    this.keyCount = keys.length
    this.columnCount = columns.length
    this.select = 'SELECT ' + columns.join(', ') + ' FROM ' + table
    this.orderBy = ' ORDER BY ' + order
    this.selectKeys = 'SELECT ' + keys.map((key: string): string => 'CAST(' + key + ' AS TEXT)').join(', ') + ' FROM ' + table
    this.deleteKey = 'DELETE FROM ' + table + ' WHERE ' + keys.map((key: string): string => key + ' = ?').join(' AND ')
    this.deleteRows = 'DELETE FROM ' + table
    const assignments = fields.map((field: string): string => field + '=excluded.' + field).join(', ')
    const changed = fields.map((field: string): string => field + ' IS NOT excluded.' + field).join(' OR ')
    this.insertPrefix = 'INSERT INTO ' + table + ' (' + columns.join(', ') + ') VALUES '
    this.orderedInsertPrefix = 'INSERT INTO ' + table + ' (rowid, ' + columns.join(', ') + ') VALUES '
    this.valueSlots = '(' + columns.map((): string => '?').join(', ') + ')'
    this.conflictClause = ' ON CONFLICT(' + keys.join(', ') + ') ' +
      (fields.length === 0 ? 'DO NOTHING' : 'DO UPDATE SET ' + assignments + ' WHERE ' + changed)
    this.upsert = this.insertPrefix + this.valueSlots + this.conflictClause
    this.encode = encode
    this.decode = decode
  }

  read(store: relationalStore.RdbStore, filter?: string, args?: LocalColumnValue[]): T[] {
    const where = filter === undefined ? '' : ' WHERE ' + filter
    return collectLocalRows(store.querySqlSync(this.select + where + this.orderBy, args), this.decode)
  }

  /** A scheduler consumes the first eligible row in live storage order. */
  find(store: relationalStore.RdbStore, filter: string, args: LocalColumnValue[],
    predicate: (row: T) => boolean): T | undefined {
    const rows = store.querySqlSync(this.select + ' WHERE ' + filter + this.orderBy, args)
    try {
      while (rows.goToNextRow()) {
        const row = this.decode(rows)
        if (predicate(row)) return row
      }
      return undefined
    } finally {
      rows.close()
    }
  }

  put(store: relationalStore.RdbStore, record: T): void {
    store.executeSync(this.upsert, this.encode(record))
  }

  remove(store: relationalStore.RdbStore, key: LocalColumnValue[]): void {
    store.executeSync(this.deleteKey, key)
  }

  async importRows(transaction: relationalStore.Transaction, records: T[], rowIds?: number[]): Promise<void> {
    const maxRows = Math.floor(900 / (this.columnCount + (rowIds === undefined ? 0 : 1)))
    for (let start = 0; start < records.length; start += maxRows) {
      const batch = records.slice(start, start + maxRows)
      const args: LocalColumnValue[] = []
      for (let index = 0; index < batch.length; index++) {
        if (rowIds !== undefined) args.push(rowIds[start + index])
        args.push(...this.encode(batch[index]))
      }
      await transaction.execute(this.batchStatement(batch.length, rowIds !== undefined), args)
    }
  }

  async replaceWorkRows(transaction: relationalStore.Transaction, records: T[], comicId: string,
    column: string = 'comic_id', filter?: string): Promise<void> {
    const predicate = ' WHERE ' + column + ' = ?' + (filter === undefined ? '' : ' AND ' + filter)
    if (records.length === 0) {
      await transaction.execute(this.deleteRows + predicate, [comicId])
      return
    }
    const rows = await transaction.querySql(this.selectKeys + predicate, [comicId])
    const previous = this.previousKeys(rows)
    await this.importRows(transaction, records)
    for (const record of records) previous.delete(this.encodedKey(this.encode(record)))
    for (const key of previous.values()) await transaction.execute(this.deleteKey, key)
  }

  replace(store: relationalStore.RdbStore, records: T[], scopeColumn?: string, scope?: string): void {
    const predicate = scopeColumn === undefined ? '' : ' WHERE ' + scopeColumn + ' = ?'
    const scopeArgs: LocalColumnValue[] = scopeColumn === undefined ? [] : [scope ?? null]
    if (records.length === 0) {
      store.executeSync(this.deleteRows + predicate, scopeArgs)
      return
    }
    const previous = this.previousKeys(store.querySqlSync(this.selectKeys + predicate, scopeArgs))
    const maxRows = Math.floor(900 / this.columnCount)
    for (let start = 0; start < records.length; start += maxRows) {
      const batch = records.slice(start, start + maxRows)
      const args: LocalColumnValue[] = []
      for (const record of batch) {
        const values = this.encode(record)
        previous.delete(this.encodedKey(values))
        args.push(...values)
      }
      store.executeSync(this.batchStatement(batch.length), args)
    }
    for (const key of previous.values()) store.executeSync(this.deleteKey, key)
  }

  private encodedKey(values: LocalColumnValue[]): string {
    return JSON.stringify(values.slice(0, this.keyCount).map((value: LocalColumnValue): string => String(value)))
  }

  private previousKeys(keyRows: relationalStore.ResultSet): Map<string, string[]> {
    const keys = collectLocalRows(keyRows, (row: relationalStore.ResultSet): string[] => {
      const key: string[] = []
      for (let index = 0; index < this.keyCount; index++) key.push(row.getString(index))
      return key
    })
    const previous = new Map<string, string[]>()
    for (const key of keys) previous.set(JSON.stringify(key), key)
    return previous
  }

  private batchStatement(count: number, ordered: boolean = false): string {
    const inserts: string[] = []
    const slots = ordered ? '(?, ' + this.valueSlots.slice(1) : this.valueSlots
    for (let index = 0; index < count; index++) inserts.push(slots)
    return (ordered ? this.orderedInsertPrefix : this.insertPrefix) + inserts.join(', ') + this.conflictClause
  }
}
