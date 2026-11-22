import type { relationalStore } from '@kit.ArkData'
import { LocalColumnValue, booleanValue } from './LocalDataRows'
import { ReaderDisplaySettings, ReaderFilterBlendMode, parseReaderDisplaySettings } from './ReaderDisplaySettings'

export const READER_GLOBAL_DOMAIN = 'preferences/koma_reader_preferences_v1/'
const DISPLAY_KEY = 'reader.displaySettings'

interface ReaderPreferenceField {
  key: string
  column: string
  type: string
}

const fields: ReaderPreferenceField[] = [
  { key: 'reader.pageMode', column: 'page_mode', type: 'string' },
  { key: 'reader.readingDirection', column: 'reading_direction', type: 'string' },
  { key: 'reader.themeMode', column: 'theme_mode', type: 'string' },
  { key: 'reader.backgroundMode', column: 'background_mode', type: 'string' },
  { key: 'reader.showProgressControls', column: 'show_progress_controls', type: 'boolean' },
  { key: 'reader.keepScreenAwake', column: 'keep_screen_awake', type: 'boolean' },
  { key: 'reader.screenOrientation', column: 'screen_orientation', type: 'string' },
  { key: 'reader.fullscreen', column: 'fullscreen', type: 'boolean' },
  { key: 'reader.imageFitMode', column: 'image_fit_mode', type: 'string' },
  { key: 'reader.imageScalingQuality', column: 'image_scaling_quality', type: 'string' },
  { key: 'reader.showPageNumber', column: 'show_page_number', type: 'boolean' },
  { key: 'reader.pageTurnAnimation', column: 'page_turn_animation', type: 'boolean' },
  { key: 'reader.doubleTapZoomEnabled', column: 'double_tap_zoom_enabled', type: 'boolean' },
  { key: 'reader.doubleTapIntervalMs', column: 'double_tap_interval_ms', type: 'number' },
  { key: 'reader.autoPageSeconds', column: 'auto_page_seconds', type: 'number' },
  { key: 'reader.preloadPages', column: 'preload_pages', type: 'number' },
  { key: 'reader.preloadWifiOnly', column: 'preload_wifi_only', type: 'boolean' },
  { key: 'reader.spreadLayoutMode', column: 'spread_layout_mode', type: 'string' },
  { key: 'reader.columnMode', column: 'column_mode', type: 'string' },
  { key: 'reader.tapZonePreset', column: 'tap_zone_preset', type: 'string' },
  { key: 'reader.tapZoneInvert', column: 'tap_zone_invert', type: 'string' },
  { key: 'reader.pageGapMode', column: 'page_gap_mode', type: 'string' },
  { key: 'reader.bannerFilter', column: 'banner_filter', type: 'string' },
  { key: 'reader.trimPageMarginsEnabled', column: 'trim_page_margins_enabled', type: 'boolean' },
  { key: 'reader.cropStrength', column: 'crop_strength', type: 'string' },
  { key: 'reader.superResolutionEnabled', column: 'super_resolution_enabled', type: 'boolean' },
  { key: 'reader.superResolutionModel', column: 'super_resolution_model', type: 'string' },
  { key: 'reader.superResolutionBackend', column: 'super_resolution_backend', type: 'string' },
  { key: 'reader.superResolutionMaxHeight', column: 'super_resolution_max_height', type: 'number' },
  { key: 'reader.readerImplementation', column: 'reader_implementation', type: 'string' },
  { key: 'reader.wideImageMode', column: 'wide_image_mode', type: 'string' },
  { key: 'reader.volumeKeyNavigationEnabled', column: 'volume_key_navigation_enabled', type: 'boolean' },
  { key: 'reader.eyeGazePageTurnEnabled', column: 'eye_gaze_page_turn_enabled', type: 'boolean' },
  { key: 'reader.smartKeyPageTurnEnabled', column: 'smart_key_page_turn_enabled', type: 'boolean' },
  { key: 'reader.volumeKeyBehavior', column: 'volume_key_behavior', type: 'string' },
]

const DISPLAY_COLUMNS: string[] = [
  'display_brightness_enabled', 'display_brightness', 'display_hdr_brightness_enabled', 'display_filter_enabled',
  'display_red', 'display_green', 'display_blue', 'display_alpha', 'display_blend_mode', 'display_grayscale', 'display_inverted',
]

function sqlType(type: string): string {
  if (type === 'number') return 'REAL'
  return type === 'boolean' ? 'INTEGER' : 'TEXT'
}

const SHARED_KEYS: string[] = ['reader.pageMode', 'reader.readingDirection', 'reader.imageFitMode',
  'reader.showPageNumber', 'reader.pageTurnAnimation']
const SHARED_FIELDS = fields.filter((field: ReaderPreferenceField): boolean => SHARED_KEYS.includes(field.key))
const LOCAL_FIELDS = fields.filter((field: ReaderPreferenceField): boolean =>
  !SHARED_KEYS.includes(field.key) || field.key === 'reader.pageMode')

// page_mode in the device table is only the automatic mode override. The
// portable mode and the other shared controls have a single durable owner.
export const CREATE_READER_PREFERENCES = 'CREATE TABLE IF NOT EXISTS reader_preferences (' +
  'id INTEGER PRIMARY KEY CHECK (id = 1), ' +
  LOCAL_FIELDS.map((field: ReaderPreferenceField): string => field.column + ' ' + sqlType(field.type)).join(', ') + ', ' +
  DISPLAY_COLUMNS.map((column: string): string => column + (column === 'display_blend_mode' ? ' TEXT' : ' INTEGER'))
    .join(', ') + ')'

export const CREATE_READER_SHARED_PREFERENCES = 'CREATE TABLE IF NOT EXISTS reader_shared_preferences (' +
  'id INTEGER PRIMARY KEY, ' +
  SHARED_FIELDS.map((field: ReaderPreferenceField): string => field.column + ' ' + sqlType(field.type)).join(', ') + ')'

export interface ReaderPreferenceWrite {
  sql: string
  values: LocalColumnValue[]
}

function upsert(columns: string[], table: string = 'reader_preferences'): string {
  return 'INSERT INTO ' + table + ' (id, ' + columns.join(', ') + ') VALUES (1, ' +
    columns.map((): string => '?').join(', ') + ') ON CONFLICT(id) DO UPDATE SET ' +
    columns.map((column: string): string => column + '=excluded.' + column).join(', ')
}

export function readerPreferenceWrites(key: string, raw?: string): ReaderPreferenceWrite[] | undefined {
  if (key !== DISPLAY_KEY) {
    const field = fields.find((item: ReaderPreferenceField): boolean => item.key === key)
    if (field === undefined) return undefined
    const parsed = raw === undefined ? null : JSON.parse(raw) as Object
    let value: LocalColumnValue = null
    if (field.type === 'boolean' && typeof parsed === 'boolean') value = booleanValue(parsed)
    if (field.type === 'number' && typeof parsed === 'number') value = parsed
    if (field.type === 'string' && typeof parsed === 'string') value = parsed
    if (!SHARED_KEYS.includes(key)) return [{ sql: upsert([field.column]), values: [value] }]
    const sharedSql = upsert([field.column], 'reader_shared_preferences')
    if (key !== 'reader.pageMode') return [{ sql: sharedSql, values: [value] }]
    return [
      { sql: upsert([field.column]), values: [value === 'auto_page' ? value : null] },
      { sql: sharedSql, values: [value === 'auto_page' ? 'single_page' : value] },
    ]
  }
  if (raw === undefined) return [{ sql: upsert(DISPLAY_COLUMNS), values: DISPLAY_COLUMNS.map((): LocalColumnValue => null) }]
  // The Preferences and backup formats supply display settings as an encoded string.
  const display = parseReaderDisplaySettings(JSON.parse(raw) as string)
  return [{ sql: upsert(DISPLAY_COLUMNS), values: [
    booleanValue(display.brightnessEnabled), display.brightness, booleanValue(display.hdrBrightnessEnabled),
    booleanValue(display.filterEnabled), display.red, display.green, display.blue, display.alpha, display.blendMode,
    booleanValue(display.grayscale), booleanValue(display.inverted),
  ] }]
}

export function readReaderPreferenceColumns(store: relationalStore.RdbStore, key?: string): Map<string, string> {
  const values = new Map<string, string>()
  const selected = key === undefined ? fields : fields.filter((field: ReaderPreferenceField): boolean => field.key === key)
  const readDisplay = key === undefined || key === DISPLAY_KEY
  const columns = selected.map((field: ReaderPreferenceField): string => {
    if (field.key === 'reader.pageMode') return 'COALESCE(l.page_mode, s.page_mode)'
    return (SHARED_KEYS.includes(field.key) ? 's.' : 'l.') + field.column
  })
  if (readDisplay) columns.push(...DISPLAY_COLUMNS.map((column: string): string => 'l.' + column))
  if (columns.length === 0) return values
  const row = store.querySqlSync('SELECT ' + columns.join(', ') + ' FROM (SELECT 1 AS id) p ' +
    'LEFT JOIN reader_preferences l ON l.id = p.id LEFT JOIN reader_shared_preferences s ON s.id = p.id')
  try {
    if (!row.goToNextRow()) return values
    selected.forEach((field: ReaderPreferenceField, index: number): void => {
      if (row.isColumnNull(index)) return
      if (field.type === 'boolean') values.set(field.key, row.getLong(index) === 0 ? 'false' : 'true')
      else if (field.type === 'number') values.set(field.key, JSON.stringify(row.getDouble(index)))
      else values.set(field.key, JSON.stringify(row.getString(index)))
    })
    const offset = selected.length
    if (readDisplay && !row.isColumnNull(offset)) {
      const display = new ReaderDisplaySettings()
      display.brightnessEnabled = row.getLong(offset) !== 0
      display.brightness = row.getLong(offset + 1)
      display.hdrBrightnessEnabled = row.getLong(offset + 2) !== 0
      display.filterEnabled = row.getLong(offset + 3) !== 0
      display.red = row.getLong(offset + 4)
      display.green = row.getLong(offset + 5)
      display.blue = row.getLong(offset + 6)
      display.alpha = row.getLong(offset + 7)
      display.blendMode = row.getString(offset + 8) as ReaderFilterBlendMode
      display.grayscale = row.getLong(offset + 9) !== 0
      display.inverted = row.getLong(offset + 10) !== 0
      values.set(DISPLAY_KEY, JSON.stringify(JSON.stringify(display)))
    }
    return values
  } finally { row.close() }
}

export async function migrateSharedReaderPreferences(transaction: relationalStore.Transaction): Promise<void> {
  const result = await transaction.querySql('PRAGMA table_info(reader_preferences)')
  let previousLayout = false
  try {
    while (result.goToNextRow()) {
      if (result.getString(1) === 'reading_direction') previousLayout = true
    }
  } finally { result.close() }
  if (!previousLayout) return
  const columns = SHARED_FIELDS.map((field: ReaderPreferenceField): string => field.column)
  const previous = columns.map((column: string): string => column === 'page_mode' ?
    "CASE WHEN page_mode = 'auto_page' THEN 'single_page' ELSE page_mode END" : column)
  // A legacy row with only device settings must not create an empty cloud
  // record that can win over the other device's existing reading settings.
  await transaction.execute('INSERT INTO reader_shared_preferences (id, ' + columns.join(', ') + ') SELECT id, ' +
    previous.join(', ') + ' FROM reader_preferences WHERE ' + columns.map(column => column + ' IS NOT NULL').join(' OR '))
  await transaction.execute("UPDATE reader_preferences SET page_mode = NULL WHERE page_mode <> 'auto_page'")
  for (const column of columns) {
    if (column !== 'page_mode') await transaction.execute('ALTER TABLE reader_preferences DROP COLUMN ' + column)
  }
}

/** Convert version 5 reader settings inside the rename transaction. */
export async function copyReaderPreferenceColumns(transaction: relationalStore.Transaction): Promise<void> {
  const result = await transaction.querySql('SELECT preference_id, value_kind, value_text, value_number, value_boolean ' +
    'FROM typed_local_preferences WHERE domain = ?', [READER_GLOBAL_DOMAIN])
  const writes = new Map<string, ReaderPreferenceWrite[]>()
  try {
    while (result.goToNextRow()) {
      const key = result.getString(0)
      const kind = result.getString(1)
      const encoded = kind === 'string' ? JSON.stringify(result.getString(2)) :
        (kind === 'number' ? JSON.stringify(result.getDouble(3)) :
          (kind === 'boolean' ? JSON.stringify(result.getLong(4) !== 0) : undefined))
      const write = readerPreferenceWrites(key, encoded)
      if (write !== undefined) writes.set(key, write)
    }
  } finally { result.close() }
  for (const key of writes.keys()) {
    const operations = writes.get(key) ?? []
    for (const write of operations) await transaction.execute(write.sql, write.values)
    await transaction.execute('DELETE FROM typed_local_preferences WHERE domain = ? AND preference_id = ?',
      [READER_GLOBAL_DOMAIN, key])
  }
}
