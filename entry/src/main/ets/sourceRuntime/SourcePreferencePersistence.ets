import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, writeUserRecords } from '../model/UserKeyedRecords'
import type { SettingsFieldValue, SettingsFieldValues } from '../model/SettingsFormFields'
import type { SourceFilterPreferenceSourceRecord, SourceSearchPreset } from './SourceFilterPreferencesStore'
import { booleanValue, textColumn } from '../model/LocalDataRows'

export const SOURCE_SETTINGS_PATH = 'source-runtime/source-settings.json'
export const SOURCE_FILTERS_PATH = 'source-runtime/source-filter-preferences.json'

interface SourcePreferenceDocument<T> {
  schemaVersion: number
  sources: Record<string, T>
}

interface SourcePreferenceGroup {
  kind: string
  order: number
  name?: string
  query?: string
  fields: SettingsFieldValues
}

function groupsFor<T>(path: string, source: T): SourcePreferenceGroup[] {
  if (path !== SOURCE_FILTERS_PATH) return [{ kind: 'fields', order: 0, fields: source as SettingsFieldValues }]
  const view = source as SourceFilterPreferenceSourceRecord
  const groups: SourcePreferenceGroup[] = []
  if (view.browse !== undefined) groups.push({ kind: 'browse', order: 0, fields: view.browse })
  if (view.search !== undefined) groups.push({ kind: 'search', order: 0, fields: view.search })
  if (view.searchPresets !== undefined) {
    groups.push({ kind: 'presets', order: 0, fields: {} })
    view.searchPresets.forEach((preset: SourceSearchPreset, order: number): void => {
      groups.push({ kind: 'preset', order, name: preset.name, query: preset.query, fields: preset.filters })
    })
  }
  return groups
}

function sourceFromGroups<T>(path: string, groups: SourcePreferenceGroup[]): T {
  if (path !== SOURCE_FILTERS_PATH) {
    const empty: SettingsFieldValues = {}
    return (groups[0]?.fields ?? empty) as T
  }
  const view: SourceFilterPreferenceSourceRecord = {}
  for (const group of groups) {
    if (group.kind === 'browse') view.browse = group.fields
    if (group.kind === 'search') view.search = group.fields
    if (group.kind === 'presets' && view.searchPresets === undefined) view.searchPresets = []
    if (group.kind === 'preset' && group.name !== undefined && group.query !== undefined) {
      const presets = view.searchPresets ?? []
      presets.push({ name: group.name, query: group.query, filters: group.fields })
      view.searchPresets = presets
    }
  }
  return view as T
}

const PREFERENCE_QUERY = 'SELECT s.source_id, g.group_kind, g.group_order, g.preset_name, g.preset_query, ' +
  'f.field_id, f.value_kind, f.value_text, f.value_number, f.value_boolean, i.item_text ' +
  'FROM source_preference_documents d LEFT JOIN source_preference_sources s ON d.scope=s.scope ' +
  'LEFT JOIN source_preference_groups g ON s.scope=g.scope AND s.source_id=g.source_id ' +
  'LEFT JOIN source_preference_fields f ON g.scope=f.scope AND g.source_id=f.source_id AND ' +
  'g.group_kind=f.group_kind AND g.group_order=f.group_order ' +
  'LEFT JOIN source_preference_field_items i ON f.scope=i.scope AND f.source_id=i.source_id AND ' +
  'f.group_kind=i.group_kind AND f.group_order=i.group_order AND f.field_id=i.field_id'
const PREFERENCE_ORDER = ' ORDER BY s.list_order, g.group_kind, g.group_order, f.field_order, i.item_order'

export class SourcePreferenceRows<T> {
  private readonly store: relationalStore.RdbStore
  private readonly scope: string
  private readonly marker: string
  private readonly previous: UserKeyedRecords

  constructor(store: relationalStore.RdbStore, path: string) {
    this.store = store
    this.scope = path
    this.marker = 'source-preferences-relational/' + path
    this.previous = new UserKeyedRecords(store, path)
  }

  isMigrated(): boolean {
    return hasUserDataMigration(this.store, this.marker)
  }

  usesPreviousDatabase(): boolean {
    return this.previous.isMigrated()
  }

  migrate(legacy: Record<string, T> | undefined): void {
    writeUserRecords(this.store, (): void => {
      if (this.isMigrated()) return
      let snapshot = legacy
      if (this.previous.isMigrated()) {
        const old = this.previous.entries()
        snapshot = undefined
        if (old !== undefined) {
          const sources: Record<string, T> = {}
          old.forEach((value: string, sourceId: string): void => { sources[sourceId] = JSON.parse(value) as T })
          snapshot = sources
        }
      }
      this.replaceInTransaction(snapshot)
      markUserDataMigration(this.store, this.marker)
    })
  }

  read(sourceId?: string): Record<string, T> | undefined {
    const predicate = sourceId === undefined ? ' WHERE d.scope = ?' : ' WHERE d.scope = ? AND s.source_id = ?'
    const rows = this.store.querySqlSync(PREFERENCE_QUERY + predicate + PREFERENCE_ORDER,
      sourceId === undefined ? [this.scope] : [this.scope, sourceId])
    const bySource = new Map<string, SourcePreferenceGroup[]>()
    const groups = new Map<string, SourcePreferenceGroup>()
    try {
      if (!rows.goToNextRow()) return undefined
      do {
        if (rows.isColumnNull(0)) continue
        const id = rows.getString(0)
        const list = bySource.get(id) ?? []
        if (!bySource.has(id)) bySource.set(id, list)
        if (rows.isColumnNull(1)) continue
        const kind = rows.getString(1)
        const order = rows.getLong(2)
        const key = JSON.stringify([id, kind, order])
        let group = groups.get(key)
        if (group === undefined) {
          group = { kind, order, name: textColumn(rows, 3), query: textColumn(rows, 4), fields: {} }
          groups.set(key, group)
          list.push(group)
        }
        if (!rows.isColumnNull(5)) this.readField(rows, group.fields)
      } while (rows.goToNextRow())
    } finally {
      rows.close()
    }
    const result: Record<string, T> = {}
    bySource.forEach((entries: SourcePreferenceGroup[], id: string): void => { result[id] = sourceFromGroups<T>(this.scope, entries) })
    return result
  }

  private readField(rows: relationalStore.ResultSet, fields: SettingsFieldValues): void {
    const id = rows.getString(5)
    const kind = rows.getString(6)
    if (kind === 'string') fields[id] = rows.getString(7)
    else if (kind === 'number') fields[id] = rows.getDouble(8)
    else if (kind === 'boolean') fields[id] = rows.getLong(9) !== 0
    else if (kind === 'list') {
      const existing = fields[id]
      const items = Array.isArray(existing) ? existing as string[] : []
      if (!rows.isColumnNull(10)) items.push(rows.getString(10))
      fields[id] = items
    } else throw new Error('source_preference_unknown_value_type')
  }

  put(sourceId: string, value: T | undefined): void {
    writeUserRecords(this.store, (): void => {
      const order = this.sourceOrder(sourceId)
      this.delete(sourceId)
      if (value !== undefined) this.insertSource(sourceId, order, value)
    })
  }

  replace(sources: Record<string, T> | undefined): void {
    writeUserRecords(this.store, (): void => this.replaceInTransaction(sources))
  }

  private replaceInTransaction(sources: Record<string, T> | undefined): void {
    this.delete()
    if (sources === undefined) {
      this.store.executeSync('DELETE FROM source_preference_documents WHERE scope = ?', [this.scope])
      return
    }
    this.store.executeSync('INSERT OR IGNORE INTO source_preference_documents (scope) VALUES (?)', [this.scope])
    Object.keys(sources).forEach((id: string, order: number): void => this.insertSource(id, order, sources[id]))
  }

  private delete(sourceId?: string): void {
    const predicate = sourceId === undefined ? ' WHERE scope = ?' : ' WHERE scope = ? AND source_id = ?'
    const args = sourceId === undefined ? [this.scope] : [this.scope, sourceId]
    for (const table of ['source_preference_field_items', 'source_preference_fields', 'source_preference_groups',
      'source_preference_sources']) this.store.executeSync('DELETE FROM ' + table + predicate, args)
  }

  private sourceOrder(sourceId: string): number {
    const rows = this.store.querySqlSync('SELECT COALESCE((SELECT list_order FROM source_preference_sources ' +
      'WHERE scope = ? AND source_id = ?), (SELECT MAX(list_order)+1 FROM source_preference_sources WHERE scope = ?), 0)',
      [this.scope, sourceId, this.scope])
    try {
      return rows.goToNextRow() ? rows.getLong(0) : 0
    } finally {
      rows.close()
    }
  }

  private insertSource(sourceId: string, order: number, value: T): void {
    this.store.executeSync('INSERT OR IGNORE INTO source_preference_documents (scope) VALUES (?)', [this.scope])
    this.store.executeSync('INSERT INTO source_preference_sources (scope, source_id, list_order) VALUES (?, ?, ?)',
      [this.scope, sourceId, order])
    for (const group of groupsFor(this.scope, value)) {
      this.store.executeSync('INSERT INTO source_preference_groups (scope, source_id, group_kind, group_order, ' +
        'preset_name, preset_query) VALUES (?, ?, ?, ?, ?, ?)',
        [this.scope, sourceId, group.kind, group.order, group.name ?? null, group.query ?? null])
      Object.keys(group.fields).forEach((key: string, index: number): void => {
        this.insertField(sourceId, group, key, index, group.fields[key])
      })
    }
  }

  private insertField(sourceId: string, group: SourcePreferenceGroup, key: string, index: number, value: SettingsFieldValue): void {
    const kind = Array.isArray(value) ? 'list' : typeof value
    if (kind !== 'list' && kind !== 'string' && kind !== 'number' && kind !== 'boolean') {
      throw new Error('source_preference_unexpected_value')
    }
    this.store.executeSync('INSERT INTO source_preference_fields (scope, source_id, group_kind, group_order, field_id, ' +
      'field_order, value_kind, value_text, value_number, value_boolean) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [this.scope, sourceId, group.kind, group.order, key, index, kind, typeof value === 'string' ? value : null,
        typeof value === 'number' ? value : null, typeof value === 'boolean' ? booleanValue(value) : null])
    if (Array.isArray(value)) {
      (value as string[]).forEach((item: string, order: number): void => {
        this.store.executeSync('INSERT INTO source_preference_field_items (scope, source_id, group_kind, group_order, ' +
          'field_id, item_order, item_text) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [this.scope, sourceId, group.kind, group.order, key, order, item])
      })
    }
  }
}

export class SourcePreferencePersistence<T> {
  private readonly opened = new Map<string, SourcePreferenceRows<T>>()
  private readonly relativePath: string

  constructor(relativePath: string) { this.relativePath = relativePath }

  async open(context: common.Context): Promise<void> {
    const absolute = context.filesDir + '/' + this.relativePath
    if (!this.opened.has(absolute)) {
      const records = new SourcePreferenceRows<T>(await openUserDataDatabase(context), this.relativePath)
      if (!records.isMigrated() && records.usesPreviousDatabase()) records.migrate(undefined)
      this.opened.set(absolute, records)
    }
  }

  database(absolute: string): SourcePreferenceRows<T> | undefined {
    const records = this.opened.get(absolute)
    return records?.isMigrated() === true ? records : undefined
  }

  migrate(absolute: string, legacy: Record<string, T> | undefined): void {
    const records = this.opened.get(absolute)
    if (records === undefined) throw new Error('source_preferences_database_not_open')
    records.migrate(legacy)
  }

  readSource(records: SourcePreferenceRows<T>, id: string): T | undefined {
    return records.read(id)?.[id]
  }

  readAll(records: SourcePreferenceRows<T>): Record<string, T> | undefined {
    return records.read()
  }

  replace(records: SourcePreferenceRows<T>, sources: Record<string, T>): void {
    records.replace(sources)
  }

  readSnapshot(absolute: string): string | undefined {
    const sources = this.database(absolute)?.read()
    if (sources === undefined) return undefined
    const document: SourcePreferenceDocument<T> = { schemaVersion: 1, sources }
    return JSON.stringify(document)
  }

  restoreSnapshot(absolute: string, raw: string | undefined): void {
    const database = this.database(absolute)
    if (database === undefined) throw new Error('source_preferences_database_not_migrated')
    if (raw === undefined) {
      database.replace(undefined)
      return
    }
    const document = JSON.parse(raw) as SourcePreferenceDocument<T>
    if (document === null || document.schemaVersion !== 1 || document.sources === null ||
      typeof document.sources !== 'object' || Array.isArray(document.sources)) throw new Error('source_preferences_invalid')
    this.replace(database, document.sources)
  }
}
