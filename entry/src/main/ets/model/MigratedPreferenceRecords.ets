import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { openUserDataDatabase } from './UserDataDatabase'
import type { UserRecordValues } from './UserKeyedRecords'
import { PreferenceColumnRows } from './PreferenceColumnRows'
import { loadSourceSubscriptionPreferences, recoverSourceSubscriptionPreferences,
  SOURCE_INDEX_PREFERENCES, SOURCE_INDEX_REPOSITORIES, SOURCE_INDEX_URL } from '../sourceRuntime/SourceSubscriptionStorage'

export type LegacyPreferenceValue = string | number | boolean

export interface PreferenceRecordCodec {
  decode: (value: LegacyPreferenceValue | undefined) => UserRecordValues | undefined
  encode: (records: UserRecordValues | undefined) => string | undefined
}

export function decodePreferenceRecordMap(value: LegacyPreferenceValue | undefined): UserRecordValues | undefined {
  if (value === undefined) return undefined
  if (typeof value !== 'string') throw new Error('invalid_legacy_record_map')
  const decoded = JSON.parse(value) as Record<string, Object>
  if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) throw new Error('invalid_legacy_record_map')
  const records: UserRecordValues = new Map()
  for (const key of Object.keys(decoded)) records.set(key, JSON.stringify(decoded[key]))
  return records
}

function canonicalPreference(value: Object | null): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value)
  if (Array.isArray(value)) {
    return '[' + (value as Object[]).map((row: Object): string => canonicalPreference(row)).join(',') + ']'
  }
  const row = value as Record<string, Object>
  return '{' + Object.keys(row).sort().map((key: string): string =>
    JSON.stringify(key) + ':' + canonicalPreference(row[key])).join(',') + '}'
}

function sameRecords(actual: UserRecordValues | undefined, expected: UserRecordValues | undefined): boolean {
  if (actual === undefined || expected === undefined) return actual === expected
  if (actual.size !== expected.size) return false
  for (const key of expected.keys()) {
    const left = actual.get(key)
    const right = expected.get(key)
    if (left === right) continue
    if (left === undefined || right === undefined ||
      canonicalPreference(JSON.parse(left) as Object) !== canonicalPreference(JSON.parse(right) as Object)) return false
  }
  return true
}

function encodePreferenceRecordMap(records: UserRecordValues | undefined): string | undefined {
  if (records === undefined) return undefined
  const parts: string[] = []
  records.forEach((value: string, key: string): void => { parts.push(JSON.stringify(key) + ':' + value) })
  return '{' + parts.join(',') + '}'
}

const recordMapCodec: PreferenceRecordCodec = { decode: decodePreferenceRecordMap, encode: encodePreferenceRecordMap }

interface OrderedPreferenceRow {
  order: number
  value: Object
}

/** Persist a legacy array as individually identifiable rows and retain its exact list order. */
export function orderedPreferenceRecords(identityFields: string[]): PreferenceRecordCodec {
  return {
    decode: (value: LegacyPreferenceValue | undefined): UserRecordValues | undefined => {
      if (value === undefined) return undefined
      if (typeof value !== 'string') throw new Error('invalid_legacy_record_list')
      const rows = JSON.parse(value) as Object[]
      if (!Array.isArray(rows)) throw new Error('invalid_legacy_record_list')
      const result: UserRecordValues = new Map()
      rows.forEach((row: Object, order: number): void => {
        const fields = row as Record<string, Object>
        const identity = JSON.stringify(identityFields.map((field: string): Object | undefined => fields?.[field]))
        // Keep duplicate legacy rows for the owning domain's existing reconciliation policy.
        let key = identity
        if (result.has(key)) key = identity + ':' + order
        const record: OrderedPreferenceRow = { order, value: row }
        result.set(key, JSON.stringify(record))
      })
      return result
    },
    encode: (records: UserRecordValues | undefined): string | undefined => {
      if (records === undefined) return undefined
      const ordered: OrderedPreferenceRow[] = Array.from(records.values())
        .map((value: string): OrderedPreferenceRow => JSON.parse(value) as OrderedPreferenceRow)
        .sort((left: OrderedPreferenceRow, right: OrderedPreferenceRow): number => left.order - right.order)
      return JSON.stringify(ordered.map((row: OrderedPreferenceRow): Object => row.value))
    },
  }
}

export class MigratedPreferenceRecords {
  private readonly opened = new Map<string, PreferenceColumnRows>()
  private readonly opening = new Map<string, Promise<PreferenceColumnRows>>()
  readonly name: string
  readonly key: string
  private readonly excludedKeys: string[]
  private readonly codec: PreferenceRecordCodec

  constructor(name: string, key: string = '', excludedKeys: string[] = [], codec: PreferenceRecordCodec = recordMapCodec) {
    this.name = name
    this.key = key
    this.excludedKeys = excludedKeys
    this.codec = codec
  }

  private async open(context: common.Context): Promise<PreferenceColumnRows> {
    return new PreferenceColumnRows(await openUserDataDatabase(context), this.name, this.key)
  }

  prepared(filesDir: string): PreferenceColumnRows | undefined {
    return this.opened.get(filesDir)
  }

  prepare(context: common.Context): Promise<PreferenceColumnRows> {
    const directory = context.filesDir
    const existing = this.opening.get(directory)
    if (existing !== undefined) return existing
    const opening = this.migrate(context).catch((error: Error): never => {
      this.opening.delete(directory)
      throw error
    })
    this.opening.set(directory, opening)
    return opening
  }

  private async migrate(context: common.Context): Promise<PreferenceColumnRows> {
    const records = await this.open(context)
    if (!records.isMigrated()) {
      let values: UserRecordValues | undefined
      if (!records.usesPreviousDatabase()) {
        const legacy = await preferences.getPreferences(context, this.name)
        if (this.key === '') {
          values = this.flatValues(await legacy.getAll() as Record<string, LegacyPreferenceValue>)
        } else if (await legacy.has(this.key)) {
          values = this.codec.decode(await legacy.get(this.key, '') as LegacyPreferenceValue)
        }
      }
      records.migrate(values)
    }
    this.opened.set(context.filesDir, records)
    return records
  }

  async readBackupValue(context: common.Context): Promise<string | undefined> {
    return this.readPreparedValue(await this.prepare(context))
  }

  readPreparedValue(records: PreferenceColumnRows): string | undefined {
    return this.codec.encode(records.entries())
  }

  async restoreBackupValue(context: common.Context, value: LegacyPreferenceValue | undefined): Promise<void> {
    (await this.prepare(context)).replace(this.codec.decode(value))
  }

  async updateEntries(context: common.Context, entries: UserRecordValues, deletedKeys: string[] = []): Promise<void> {
    const records = await this.prepare(context)
    records.putEntries(entries, deletedKeys)
  }

  async recoverMigratedValue(context: common.Context, value: LegacyPreferenceValue | undefined): Promise<boolean> {
    const records = await this.open(context)
    if (!records.isMigrated() && records.usesPreviousDatabase()) records.migrate(undefined)
    if (!records.isMigrated()) return false
    // Older prepared checkpoints can precede migration. Only a previously
    // migrated field must be rolled back in the database.
    const expected = this.codec.decode(value)
    records.replace(expected)
    if (!sameRecords(records.entries(), expected)) {
      throw new Error('backup_checkpoint_preferences_readback_failed')
    }
    return true
  }

  private flatValues(values: Record<string, LegacyPreferenceValue>): UserRecordValues {
    const records: UserRecordValues = new Map()
    for (const key of Object.keys(values)) {
      if (!this.excludedKeys.includes(key)) records.set(key, JSON.stringify(values[key]))
    }
    return records
  }

  async overlayFlatCheckpoint(context: common.Context,
    values: Record<string, LegacyPreferenceValue>): Promise<Record<string, LegacyPreferenceValue>> {
    const records = (await this.prepare(context)).entries()
    const merged: Record<string, LegacyPreferenceValue> = {}
    for (const key of Object.keys(values)) {
      if (this.excludedKeys.includes(key)) merged[key] = values[key]
    }
    records?.forEach((value: string, key: string): void => { merged[key] = JSON.parse(value) as LegacyPreferenceValue })
    return merged
  }

  async recoverFlatCheckpoint(context: common.Context, values: Record<string, LegacyPreferenceValue>,
    legacyKeys: string[], recovered: Set<string>): Promise<void> {
    const records = await this.open(context)
    if (!records.isMigrated() && records.usesPreviousDatabase()) records.migrate(undefined)
    if (!records.isMigrated()) return
    const expected = this.flatValues(values)
    records.replace(expected)
    if (!sameRecords(records.entries(), expected)) throw new Error('backup_checkpoint_preferences_readback_failed')
    for (const key of legacyKeys.concat(Object.keys(values))) {
      if (!this.excludedKeys.includes(key)) recovered.add(key)
    }
  }
}

export const chapterListRecords = new MigratedPreferenceRecords('koma_chapter_list_preferences_v1', 'chapterList.overrides.v1')
export const sourceBrowseLayoutRecords = new MigratedPreferenceRecords('koma_source_browse_layout_v1')
export const synopsisRecords = new MigratedPreferenceRecords('koma_manga_synopsis_v1')
const READER_GROUP = 'koma_reader_preferences_v1'
const readerModeCodec: PreferenceRecordCodec = {
  decode: (value: LegacyPreferenceValue | undefined): UserRecordValues | undefined => {
    if (value === undefined) return undefined
    const result: UserRecordValues = new Map()
    try {
      const raw = decodePreferenceRecordMap(value)
      raw?.forEach((payload: string, id: string): void => {
        const row = JSON.parse(payload) as Record<string, Object>
        const key = id.trim()
        if (key.length > 0 && row !== null && typeof row?.pageMode === 'string' && typeof row?.readingDirection === 'string') {
          result.set(key, payload)
        }
      })
    } catch (_error) {
      // The old reader already treated a malformed narrow map as no active overrides.
    }
    return result
  },
  encode: encodePreferenceRecordMap,
}
const readerBannerCodec: PreferenceRecordCodec = {
  decode: (value: LegacyPreferenceValue | undefined): UserRecordValues | undefined => decodePreferenceRecordMap(value === '' ? '{}' : value),
  encode: encodePreferenceRecordMap,
}
export const readerModeRecords = new MigratedPreferenceRecords(READER_GROUP, 'reader.seriesModeOverrides.v1', [], readerModeCodec)
export const readerBannerRecords = new MigratedPreferenceRecords(READER_GROUP, 'reader.bannerFilterOverrides.v1', [], readerBannerCodec)
export const readerGlobalRecords = new MigratedPreferenceRecords(READER_GROUP, '',
  [readerModeRecords.key, readerBannerRecords.key, 'reader.seriesOverrides.v1'])
export const trackerMappingRecords = new MigratedPreferenceRecords('koma_tracker_preferences_v1', 'tracker.comicMappings',
  [], orderedPreferenceRecords(['comicId', 'providerId']))
const CATALOG_PIN_PREFIX = 'pin/'
const catalogFilterCodec: PreferenceRecordCodec = {
  decode: (value: LegacyPreferenceValue | undefined): UserRecordValues | undefined => {
    const rows = decodePreferenceRecordMap(value)
    const pins = rows?.get('pinnedSourceIds')
    if (rows === undefined || pins === undefined) return rows
    const ids = JSON.parse(pins) as Object
    if (!Array.isArray(ids) || !(ids as Object[]).every((id: Object): boolean => typeof id === 'string')) return rows
    rows.set('pinnedSourceIds', '[]')
    const idsByOrder = ids as string[]
    idsByOrder.forEach((id: string, index: number): void => {
      const key = CATALOG_PIN_PREFIX + id
      if (!rows.has(key)) rows.set(key, String(index))
    })
    return rows
  },
  encode: (records: UserRecordValues | undefined): string | undefined => {
    if (records === undefined) return undefined
    const fields: UserRecordValues = new Map()
    const pins: string[] = []
    records.forEach((value: string, key: string): void => {
      if (key.startsWith(CATALOG_PIN_PREFIX)) pins.push(key)
      else fields.set(key, value)
    })
    if (pins.length > 0) fields.set('pinnedSourceIds', JSON.stringify(pins
      .sort((left: string, right: string): number => Number(records.get(left)) - Number(records.get(right)))
      .map((key: string): string => key.substring(CATALOG_PIN_PREFIX.length))))
    return encodePreferenceRecordMap(fields)
  },
}
export const catalogFilterRecords = new MigratedPreferenceRecords('koma_source_catalog_filters_v1', 'catalog.filters', [], catalogFilterCodec)

const backupPreferenceRecords: MigratedPreferenceRecords[] = [chapterListRecords, readerModeRecords, catalogFilterRecords]
const checkpointPreferenceRecords: MigratedPreferenceRecords[] = [
  chapterListRecords, readerModeRecords, readerBannerRecords, trackerMappingRecords, catalogFilterRecords,
]

export function migratedBackupPreference(name: string, key: string): MigratedPreferenceRecords | undefined {
  return backupPreferenceRecords.find((domain: MigratedPreferenceRecords): boolean => domain.name === name && domain.key === key)
}

export async function overlayMigratedCheckpointPreferences(context: common.Context, name: string,
  values: Record<string, LegacyPreferenceValue>): Promise<Record<string, LegacyPreferenceValue>> {
  const base = name === READER_GROUP ? await readerGlobalRecords.overlayFlatCheckpoint(context, values) : values
  const domains = checkpointPreferenceRecords.filter((domain: MigratedPreferenceRecords): boolean => domain.name === name)
  if (domains.length === 0 && name !== SOURCE_INDEX_PREFERENCES) return base
  const merged: Record<string, LegacyPreferenceValue> = {}
  for (const key of Object.keys(base)) {
    if (name === SOURCE_INDEX_PREFERENCES && (key === SOURCE_INDEX_REPOSITORIES || key === SOURCE_INDEX_URL)) continue
    if (!domains.some((domain: MigratedPreferenceRecords): boolean => domain.key === key)) merged[key] = base[key]
  }
  if (name === SOURCE_INDEX_PREFERENCES) {
    const snapshot = await loadSourceSubscriptionPreferences(context)
    if (snapshot.url !== undefined) merged[SOURCE_INDEX_URL] = snapshot.url
    if (snapshot.repositories !== undefined) merged[SOURCE_INDEX_REPOSITORIES] = JSON.stringify(snapshot.repositories)
  }
  for (const domain of domains) {
    const value = await domain.readBackupValue(context)
    if (value !== undefined) merged[domain.key] = value
  }
  return merged
}

export async function recoverMigratedCheckpointPreferences(context: common.Context, name: string,
  values: Record<string, LegacyPreferenceValue>, legacyKeys: string[]): Promise<Set<string>> {
  const recovered = new Set<string>()
  if (name === SOURCE_INDEX_PREFERENCES &&
    await recoverSourceSubscriptionPreferences(context, values[SOURCE_INDEX_URL], values[SOURCE_INDEX_REPOSITORIES])) {
    recovered.add(SOURCE_INDEX_URL)
    recovered.add(SOURCE_INDEX_REPOSITORIES)
  }
  if (name === READER_GROUP) await readerGlobalRecords.recoverFlatCheckpoint(context, values, legacyKeys, recovered)
  for (const domain of checkpointPreferenceRecords) {
    if (domain.name === name && await domain.recoverMigratedValue(context, values[domain.key])) recovered.add(domain.key)
  }
  return recovered
}
