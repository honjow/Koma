import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { SourceFilter } from '../model/SourceModels'

export type SourceFilterPreferenceValue = string | number | boolean | string[]
export type SourceFilterPreferenceRecord = Record<string, SourceFilterPreferenceValue>
export type SourceFilterPreferenceKind = 'browse' | 'search'

export interface SourceFilterPreferenceSourceRecord {
  browse?: SourceFilterPreferenceRecord
  search?: SourceFilterPreferenceRecord
}

interface SourceFilterPreferencesDocument {
  schemaVersion: number
  sources: Record<string, SourceFilterPreferenceSourceRecord>
}

type RuntimeValue = Object | string | number | boolean | null

const SOURCE_FILTER_PREFS_SCHEMA_VERSION: number = 1
const SOURCE_FILTER_PREFS_ROOT_NAME: string = 'source-runtime'
const SOURCE_FILTER_PREFS_FILE_NAME: string = 'source-filter-preferences.json'

function joinSourceFilterPreferencesPath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
}

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function ensureDirSync(path: string): void {
  if (fs.accessSync(path)) {
    return
  }
  fs.mkdirSync(path, true)
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
  }
}

function emptyDocument(): SourceFilterPreferencesDocument {
  return {
    schemaVersion: SOURCE_FILTER_PREFS_SCHEMA_VERSION,
    sources: {},
  }
}

function filterRequestKey(filter: SourceFilter): string {
  const raw = filter.id.length > 0 ? filter.id : filter.name
  return raw.startsWith('filter:') ? raw.substring('filter:'.length) : raw
}

function filterOptionValue(filter: SourceFilter, index: number): string {
  const optionIds = filter.optionIds ?? []
  const options = filter.options ?? []
  const raw = optionIds[index] ?? options[index] ?? ''
  const keyPrefix = `${filterRequestKey(filter)}:`
  return raw.startsWith(keyPrefix) ? raw.substring(keyPrefix.length) : raw
}

function filterOptionValues(filter: SourceFilter): string[] {
  const optionIds = filter.optionIds ?? []
  const options = filter.options ?? []
  const values: string[] = []
  for (let index = 0; index < optionIds.length || index < options.length; index += 1) {
    const value = filterOptionValue(filter, index)
    if (value.length > 0 && !values.includes(value)) {
      values.push(value)
    }
  }
  return values
}

function normalizeFilterStringValue(key: string, value: string): string {
  const trimmed = value.trim()
  const prefix = `${key}:`
  return trimmed.startsWith(prefix) ? trimmed.substring(prefix.length) : trimmed
}

function safeFilterPreferenceValue(value: RuntimeValue | undefined): SourceFilterPreferenceValue | undefined {
  if (typeof value === 'string' || typeof value === 'boolean') {
    return value
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (Array.isArray(value)) {
    const values: string[] = []
    value.forEach((item: RuntimeValue) => {
      if (typeof item === 'string') {
        values.push(item)
      }
    })
    return values
  }
  return undefined
}

function normalizedRangeFilterValue(value: SourceFilterPreferenceValue, filter: SourceFilter): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return undefined
  }
  let next = value
  if (filter.minValue !== undefined) {
    next = Math.max(filter.minValue, next)
  }
  if (filter.maxValue !== undefined) {
    next = Math.min(filter.maxValue, next)
  }
  return next
}

function sanitizeChoiceFilterValue(value: SourceFilterPreferenceValue, filter: SourceFilter): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  const normalized = normalizeFilterStringValue(filterRequestKey(filter), value)
  if (normalized.length === 0) {
    return undefined
  }
  const allowed = filterOptionValues(filter)
  return allowed.length === 0 || allowed.includes(normalized) ? normalized : undefined
}

function sanitizeMultiSelectFilterValue(value: SourceFilterPreferenceValue, filter: SourceFilter): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const key = filterRequestKey(filter)
  const allowed = filterOptionValues(filter)
  const selected: string[] = []
  value.forEach((item: string) => {
    const normalized = normalizeFilterStringValue(key, item)
    if (normalized.length === 0 || selected.includes(normalized)) {
      return
    }
    if (allowed.length === 0 || allowed.includes(normalized)) {
      selected.push(normalized)
    }
  })
  return selected.length > 0 ? selected : undefined
}

function sanitizeFilterValue(value: SourceFilterPreferenceValue, filter: SourceFilter): SourceFilterPreferenceValue | undefined {
  if (filter.type === 'check') {
    return typeof value === 'boolean' ? value : undefined
  }
  if (filter.type === 'text') {
    return typeof value === 'string' && value.trim().length > 0 ? value.trim().substring(0, 160) : undefined
  }
  if (filter.type === 'select' || filter.type === 'sort') {
    return sanitizeChoiceFilterValue(value, filter)
  }
  if (filter.type === 'multiselect') {
    return sanitizeMultiSelectFilterValue(value, filter)
  }
  if (filter.type === 'range') {
    return normalizedRangeFilterValue(value, filter)
  }
  return undefined
}

export class SourceFilterPreferencesStore {
  private storagePath: string = ''

  configure(context: common.UIAbilityContext): void {
    const root = joinSourceFilterPreferencesPath(context.filesDir, SOURCE_FILTER_PREFS_ROOT_NAME)
    ensureDirSync(root)
    this.storagePath = joinSourceFilterPreferencesPath(root, SOURCE_FILTER_PREFS_FILE_NAME)
  }

  isConfigured(): boolean {
    return this.storagePath.length > 0
  }

  loadForSource(sourceId: string, kind: SourceFilterPreferenceKind, filters: SourceFilter[]): SourceFilterPreferenceRecord {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return {}
    }
    const sourceRecord = this.readDocument().sources[normalizedSourceId]
    const values = kind === 'browse' ? sourceRecord?.browse : sourceRecord?.search
    return this.filterSafeValues(values ?? {}, filters)
  }

  saveForSource(
    sourceId: string,
    kind: SourceFilterPreferenceKind,
    values: SourceFilterPreferenceRecord,
    filters: SourceFilter[],
  ): void {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return
    }
    const safeValues = this.filterSafeValues(values, filters)
    const document = this.readDocument()
    const sourceRecord = document.sources[normalizedSourceId] ?? {}
    if (kind === 'browse') {
      sourceRecord.browse = safeValues
    } else {
      sourceRecord.search = safeValues
    }
    document.sources[normalizedSourceId] = sourceRecord
    this.writeDocument(document)
  }

  removeSource(sourceId: string): void {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return
    }
    const document = this.readDocument()
    const nextSources: Record<string, SourceFilterPreferenceSourceRecord> = {}
    Object.keys(document.sources).forEach((key: string) => {
      if (key !== normalizedSourceId) {
        nextSources[key] = document.sources[key]
      }
    })
    document.sources = nextSources
    this.writeDocument(document)
  }

  clearForSource(sourceId: string, kind: SourceFilterPreferenceKind): void {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return
    }
    const document = this.readDocument()
    const sourceRecord = document.sources[normalizedSourceId]
    if (sourceRecord === undefined) {
      return
    }
    const nextRecord: SourceFilterPreferenceSourceRecord = {}
    if (kind === 'browse' && sourceRecord.search !== undefined) {
      nextRecord.search = sourceRecord.search
    }
    if (kind === 'search' && sourceRecord.browse !== undefined) {
      nextRecord.browse = sourceRecord.browse
    }
    const nextSources: Record<string, SourceFilterPreferenceSourceRecord> = {}
    Object.keys(document.sources).forEach((key: string) => {
      if (key !== normalizedSourceId) {
        nextSources[key] = document.sources[key]
      }
    })
    if (nextRecord.browse !== undefined || nextRecord.search !== undefined) {
      nextSources[normalizedSourceId] = nextRecord
    }
    document.sources = nextSources
    this.writeDocument(document)
  }

  exportAll(): Record<string, SourceFilterPreferenceSourceRecord> {
    return this.readDocument().sources
  }

  importAll(sources: Record<string, SourceFilterPreferenceSourceRecord> | undefined): void {
    if (sources === undefined || !this.isConfigured()) {
      return
    }
    const sanitized: Record<string, SourceFilterPreferenceSourceRecord> = {}
    Object.keys(sources).forEach((sourceId: string) => {
      const sourceRecord = sources[sourceId]
      if (sourceRecord === undefined || sourceRecord === null || Array.isArray(sourceRecord) || typeof sourceRecord !== 'object') {
        return
      }
      const safeRecord: SourceFilterPreferenceSourceRecord = {}
      const browse = this.filterSafeStoredValues(sourceRecord.browse)
      const search = this.filterSafeStoredValues(sourceRecord.search)
      if (Object.keys(browse).length > 0) {
        safeRecord.browse = browse
      }
      if (Object.keys(search).length > 0) {
        safeRecord.search = search
      }
      if (safeRecord.browse !== undefined || safeRecord.search !== undefined) {
        sanitized[sourceId] = safeRecord
      }
    })
    this.writeDocument({
      schemaVersion: SOURCE_FILTER_PREFS_SCHEMA_VERSION,
      sources: sanitized,
    })
  }

  private filterSafeValues(values: SourceFilterPreferenceRecord, filters: SourceFilter[]): SourceFilterPreferenceRecord {
    const filterByKey: Record<string, SourceFilter> = {}
    filters.forEach((filter: SourceFilter) => {
      filterByKey[filterRequestKey(filter)] = filter
    })
    const safeValues: SourceFilterPreferenceRecord = {}
    Object.keys(values).forEach((key: string) => {
      const filter = filterByKey[key]
      if (filter === undefined) {
        return
      }
      const safe = safeFilterPreferenceValue(values[key] as RuntimeValue)
      if (safe === undefined) {
        return
      }
      const sanitized = sanitizeFilterValue(safe, filter)
      if (sanitized !== undefined) {
        safeValues[key] = sanitized
      }
    })
    return safeValues
  }

  private filterSafeStoredValues(values: SourceFilterPreferenceRecord | undefined): SourceFilterPreferenceRecord {
    if (values === undefined || values === null || Array.isArray(values) || typeof values !== 'object') {
      return {}
    }
    const safeValues: SourceFilterPreferenceRecord = {}
    Object.keys(values).forEach((key: string) => {
      const safe = safeFilterPreferenceValue(values[key] as RuntimeValue)
      if (safe !== undefined) {
        safeValues[key] = safe
      }
    })
    return safeValues
  }

  private readDocument(): SourceFilterPreferencesDocument {
    if (!this.isConfigured() || !fs.accessSync(this.storagePath)) {
      return emptyDocument()
    }
    try {
      const document = JSON.parse(fs.readTextSync(this.storagePath, { encoding: 'utf-8' })) as SourceFilterPreferencesDocument
      if (document.schemaVersion !== SOURCE_FILTER_PREFS_SCHEMA_VERSION || document.sources === undefined ||
        document.sources === null || Array.isArray(document.sources) || typeof document.sources !== 'object') {
        return emptyDocument()
      }
      return document
    } catch (_err) {
      return emptyDocument()
    }
  }

  private writeDocument(document: SourceFilterPreferencesDocument): void {
    if (!this.isConfigured()) {
      return
    }
    writeTextSync(this.storagePath, JSON.stringify(document))
  }
}

export const appSourceFilterPreferencesStore: SourceFilterPreferencesStore = new SourceFilterPreferencesStore()

export function configureSourceFilterPreferencesStore(context: common.UIAbilityContext): void {
  appSourceFilterPreferencesStore.configure(context)
}
