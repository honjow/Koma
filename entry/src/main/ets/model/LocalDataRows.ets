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

  put(store: relationalStore.RdbStore, record: T): void {
    store.executeSync(this.upsert, this.encode(record))
  }

  remove(store: relationalStore.RdbStore, key: LocalColumnValue[]): void {
    store.executeSync(this.deleteKey, key)
  }

  async importRows(transaction: relationalStore.Transaction, records: T[]): Promise<void> {
    const maxRows = Math.floor(900 / this.columnCount)
    for (let start = 0; start < records.length; start += maxRows) {
      const batch = records.slice(start, start + maxRows)
      const args: LocalColumnValue[] = []
      for (const record of batch) args.push(...this.encode(record))
      await transaction.execute(this.batchStatement(batch.length), args)
    }
  }

  replace(store: relationalStore.RdbStore, records: T[], scopeColumn?: string, scope?: string): void {
    const predicate = scopeColumn === undefined ? '' : ' WHERE ' + scopeColumn + ' = ?'
    const scopeArgs: LocalColumnValue[] = scopeColumn === undefined ? [] : [scope ?? null]
    if (records.length === 0) {
      store.executeSync(this.deleteRows + predicate, scopeArgs)
      return
    }
    const keyRows = store.querySqlSync(this.selectKeys + predicate, scopeArgs)
    const keys = collectLocalRows(keyRows, (row: relationalStore.ResultSet): string[] => {
      const key: string[] = []
      for (let index = 0; index < this.keyCount; index++) key.push(row.getString(index))
      return key
    })
    const previous = new Map<string, string[]>()
    for (const key of keys) previous.set(JSON.stringify(key), key)
    const maxRows = Math.floor(900 / this.columnCount)
    for (let start = 0; start < records.length; start += maxRows) {
      const batch = records.slice(start, start + maxRows)
      const args: LocalColumnValue[] = []
      for (const record of batch) {
        const values = this.encode(record)
        previous.delete(JSON.stringify(values.slice(0, this.keyCount).map((value: LocalColumnValue): string => String(value))))
        args.push(...values)
      }
      store.executeSync(this.batchStatement(batch.length), args)
    }
    for (const key of previous.values()) store.executeSync(this.deleteKey, key)
  }

  private batchStatement(count: number): string {
    const inserts: string[] = []
    for (let index = 0; index < count; index++) inserts.push(this.valueSlots)
    return this.insertPrefix + inserts.join(', ') + this.conflictClause
  }
}
