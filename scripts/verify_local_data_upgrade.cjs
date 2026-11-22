const assert = require('node:assert/strict')
const { execFileSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { DatabaseSync } = require('node:sqlite')
const { createRdbPort } = require('./user_data_rdb_fixture.cjs')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const etsRoot = path.resolve(__dirname, '../entry/src/main/ets')
const temporaryDatabase = 'upgrade.db'
const cloudSchema = require('../entry/src/main/resources/rawfile/arkdata/cloud/cloud_schema.json')

function compareCloudTables(database) {
  for (const table of cloudSchema.databases[0].tables) {
    const columns = database.prepare('SELECT name, type, "notnull", dflt_value, pk FROM pragma_table_info(?)').all(table.name)
    const remoteNames = new Set(table.fields.map(field => field.colName))
    const localKey = columns.filter(column => column.pk > 0).sort((a, b) => a.pk - b.pk).map(column => column.name)
    const cloudKey = table.fields.filter(field => field.dupCheckCol).map(field => field.colName)
    assert.deepEqual(cloudKey, localKey, `${table.name}: deduplication key`)
    for (const field of table.fields) {
      const local = columns.find(column => column.name === field.colName)
      assert(local, `${table.name}.${field.colName} is missing`)
      assert.equal(local.type, { 1: 'INTEGER', 2: 'REAL', 3: 'TEXT' }[field.type], `${table.name}.${field.colName}: type`)
      assert.equal(local.notnull === 0, field.nullable, `${table.name}.${field.colName}: nullability`)
    }
    for (const local of columns) {
      if (!remoteNames.has(local.name)) {
        assert(local.notnull === 0 || local.dflt_value !== null, `${table.name}.${local.name}: omitted mandatory field`)
      }
    }
  }
}

async function prepareCloudBusinessTables(env) {
  const { SearchHistoryStore } = env.load('model/SearchHistoryStore')
  const { loadSourceSubscriptionPreferences } = env.load('sourceRuntime/SourceSubscriptionStorage')
  await new SearchHistoryStore(env.context).prepareStorage()
  await loadSourceSubscriptionPreferences(env.context)
}

function jsonFile(root, name) {
  const file = path.join(root, name)
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : undefined
}

function copyDatabase(source, target) {
  const code = [
    'import sqlite3, sys',
    'from pathlib import Path',
    'with sqlite3.connect(Path(sys.argv[1]).resolve().as_uri() + "?mode=ro", uri=True) as source:',
    '    with sqlite3.connect(sys.argv[2]) as target: source.backup(target)',
  ].join('\n')
  execFileSync('python3', ['-c', code, source, target])
}

function readLegacyPreferences(archive) {
  const script = [
    'import json,sys,xml.etree.ElementTree as ET',
    'from pathlib import Path',
    'out={}',
    'for file in Path(sys.argv[1]).glob("koma_*"):',
    '    if not file.is_file(): continue',
    '    fields={}',
    '    for row in ET.parse(file).getroot():',
    '        key=row.get("key") or row.get("name")',
    '        value=row.text or row.get("value","")',
    '        if row.tag=="bool": value=value=="true"',
    '        elif row.tag in ("double","float"): value=float(value)',
    '        elif row.tag in ("int","long"): value=int(value)',
    '        if key is not None: fields[key]=value',
    '    out[file.name]=fields',
    'print(json.dumps(out))',
  ].join('\n')
  return JSON.parse(execFileSync('python3', ['-c', script, archive], { encoding: 'utf8' }))
}

function moduleLoader(rdb, directory, archive, legacyPreferences) {
  const cache = new Map()
  function legacyPath(file) {
    const relative = path.relative(directory, file)
    if (relative.startsWith('..')) return file
    const exact = path.join(archive, relative)
    return fs.existsSync(exact) ? exact : path.join(archive, path.basename(file))
  }
  const fileIo = {
    accessSync: file => fs.existsSync(legacyPath(file)),
    access: async file => fs.existsSync(legacyPath(file)),
    readText: async file => fs.readFileSync(legacyPath(file), 'utf8'),
    readTextSync: file => fs.readFileSync(legacyPath(file), 'utf8'),
  }
  const ports = {
    '@kit.ArkData': {
      relationalStore: rdb.relationalStore,
      preferences: { getPreferences: async (_context, name) => {
        const values = legacyPreferences[name] ?? {}
        return {
          has: async key => Object.hasOwn(values, key),
          get: async (key, fallback) => values[key] ?? fallback,
          getAll: async () => values,
        }
      } },
    },
    '@kit.CoreFileKit': { fileIo },
    '@kit.ArkTS': { url: { URL: { parseURL: value => new URL(value) } },
      taskpool: { execute: async (worker, ...args) => worker(...args) } },
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { info() {}, warn() {}, error() {} } },
    './OfflineDownloadRuntime': { OfflineDownloadRuntime: {} },
    './OfflineDownloadStore': {},
    './ImageRuleAssetWorker': {},
    './SourceLibraryComic': {},
  }
  function load(name) {
    const file = path.resolve(etsRoot, name + '.ets')
    if (cache.has(file)) return cache.get(file)
    const exports = {}
    cache.set(file, exports)
    const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
    }).outputText
    new Function('exports', 'require', code)(exports, dependency => {
      if (Object.hasOwn(ports, dependency)) return ports[dependency]
      if (dependency.startsWith('@kit.')) return {}
      return load(path.relative(etsRoot, path.resolve(path.dirname(file), dependency)))
    })
    return exports
  }
  return { load, context: { filesDir: directory, databaseDir: directory } }
}

function plain(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value))
}

function assertSame(actual, expected, domain) {
  // Sanitized output. A comparison failure never prints values or identities.
  if (require('node:util').isDeepStrictEqual(plain(actual), plain(expected))) return
  function difference(left, right, names = []) {
    if (Object.is(left, right)) return undefined
    if (!left || !right || typeof left !== 'object' || typeof right !== 'object') return names
    for (const key of new Set([...Object.keys(left), ...Object.keys(right)])) {
      const next = /^[0-9]+$/.test(key) ? key : '[field]'
      const result = difference(left[key], right[key], names.concat(next))
      if (result !== undefined) return result
    }
  }
  throw new Error(domain + ' differs at ' + (difference(plain(actual), plain(expected)) ?? []).join('.'))
}

function checkpointRows(old, domain) {
  if (old === undefined || !hasMigration(old, domain)) return undefined
  if (!old.prepare('SELECT domain FROM user_record_collections WHERE domain=?').get(domain)) return undefined
  return new Map(old.prepare('SELECT record_key, value FROM user_keyed_records WHERE domain=? ORDER BY rowid')
    .all(domain).map(row => [row.record_key, row.value]))
}

function hasMigration(db, name) {
  return db !== undefined && db.prepare('SELECT 1 FROM local_data_migrations WHERE name=?').get(name) !== undefined
}

function previousShelf(old, root) {
  if (!hasMigration(old, 'library-from-json-v1')) return jsonFile(root, 'library-store.v1.json')
  const header = old.prepare('SELECT list_mask FROM library_document WHERE id=1').get()
  if (header === undefined) return undefined
  const chapterRows = old.prepare('SELECT payload FROM library_chapters WHERE comic_id=? ORDER BY list_order')
  const memberRows = old.prepare('SELECT category_id FROM library_memberships WHERE comic_id=? ORDER BY list_order')
  const listRows = old.prepare('SELECT payload FROM library_lists WHERE kind=? ORDER BY list_order')
  const result = { schemaVersion: 1, comics: [] }
  for (const row of old.prepare('SELECT id, payload, has_categories FROM library_works ORDER BY list_order').all()) {
    const comic = JSON.parse(row.payload)
    comic.chapters = chapterRows.all(row.id).map(item => JSON.parse(item.payload))
    if (row.has_categories) comic.categoryIds = memberRows.all(row.id).map(item => item.category_id)
    result.comics.push(comic)
  }
  for (const [flag, kind, name] of [
    [1, 'categories', 'customCategories'], [2, 'display', 'categoryDisplayStrategies'], [4, 'smart', 'smartCategories'],
    [8, 'mihon', 'mihonImports'], [16, 'moves', 'syncShelfMoves'],
  ]) {
    if (header.list_mask & flag) result[name] = listRows.all(kind).map(item => JSON.parse(item.payload))
  }
  return result
}

function previousReading(old, root) {
  let value
  if (hasMigration(old, 'reading-from-json-v1')) {
    const work = old.prepare('SELECT payload FROM reading_works WHERE kind=? ORDER BY rowid')
    const local = old.prepare('SELECT payload FROM reading_local_records WHERE kind=? ORDER BY list_order')
    const parse = rows => rows.map(row => JSON.parse(row.payload))
    value = { progress: parse(work.all('progress')), chapters: parse(old.prepare(
      'SELECT payload FROM reading_chapter_states ORDER BY rowid').all()),
    sourceHistory: parse(work.all('source')), remoteHistory: parse(work.all('remote')), readingSessions: parse(local.all('session')),
    syncPositions: parse(local.all('position')), syncActions: parse(local.all('action')) }
  } else {
    value = jsonFile(root, 'reader-sessions.v1.json') ?? {}
  }
  return { progress: value.progress ?? [], sourceHistory: value.sourceHistory ?? [], remoteHistory: value.remoteHistory ?? [],
    chapters: value.chapters ?? [], readingSessions: value.readingSessions ?? [],
    syncPositions: value.syncPositions?.length ? value.syncPositions : undefined,
    syncActions: value.syncActions?.length ? value.syncActions : undefined }
}

function compareVersionFive(source, target) {
  function rows(database, table) {
    return database.prepare('SELECT * FROM ' + table + ' ORDER BY rowid').all()
  }
  const tables = source.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").all()
  const transformed = new Set(['local_data_migrations', 'shelf_works', 'shelf_work_metadata', 'shelf_mihon_imports',
    'shelf_mihon_source_works', 'shelf_mihon_linked_works', 'chapter_list_settings', 'reader_book_modes',
    'typed_local_preferences', 'shelf_work_metadata_items', 'shelf_memberships',
    'reader_current_positions', 'reader_chapter_states', 'reader_source_history'])
  for (const { name } of tables) {
    if (name.startsWith('cloud_sync_')) {
      assert.equal(target.prepare('SELECT 1 FROM sqlite_master WHERE name=?').get(name), undefined)
    } else if (!transformed.has(name)) {
      assertSame(rows(target, name), rows(source, name), name)
    }
  }
  const works = new Map(rows(source, 'shelf_work_metadata').map(row => [row.comic_id, row]))
  assertSame(target.prepare('SELECT * FROM shelf_works_all ORDER BY list_order').all(),
    source.prepare('SELECT * FROM shelf_works ORDER BY list_order').all().map(row => ({
    ...row, ...works.get(row.comic_id),
  })), 'merged work metadata')
  const originalWorks = new Map(rows(source, 'shelf_mihon_source_works').map(row => [row.import_id, row]))
  const linked = new Map(rows(source, 'shelf_mihon_linked_works').map(row => [row.import_id, row]))
  const imports = rows(target, 'shelf_mihon_imports')
  assert.equal(imports.length, originalWorks.size)
  for (const row of imports) {
    const id = row.import_id
    for (const [column, value] of Object.entries(originalWorks.get(id))) assertSame(row[column], value, 'Mihon original ' + column)
    assertSame(row.has_linked_work, linked.has(id) ? 1 : 0, 'Mihon linked presence')
    for (const [column, value] of Object.entries(linked.get(id) ?? {})) {
      if (column !== 'import_id') assertSame(row['linked_' + column], value, 'Mihon linked ' + column)
    }
  }
  const chapter = 'SELECT comic_id, sort_basis, sort_direction, read_filter, language_filter, group_filter, bookmark_filter ' +
    'FROM book_preferences WHERE has_chapter_settings=1 ORDER BY comic_id'
  const modes = 'SELECT comic_id, page_mode, reading_direction FROM book_reader_modes_all ORDER BY comic_id'
  assertSame(target.prepare(chapter).all(), source.prepare('SELECT * FROM chapter_list_settings ORDER BY comic_id').all(), 'chapter options')
  assertSame(target.prepare(modes).all(), source.prepare('SELECT * FROM reader_book_modes ORDER BY comic_id').all(), 'book modes')
  const oldReader = source.prepare("SELECT preference_id, value_kind, value_text, value_number, value_boolean " +
    "FROM typed_local_preferences WHERE domain='preferences/koma_reader_preferences_v1/'").all()
  const reader = readSplitReaderPreferences(target)
  const snake = name => name.replace(/[A-Z]/g, letter => '_' + letter.toLowerCase())
  for (const row of oldReader) {
    const key = row.preference_id.slice('reader.'.length)
    if (key === 'displaySettings') {
      for (const [field, value] of Object.entries(JSON.parse(row.value_text))) {
        assertSame(reader['display_' + snake(field)], typeof value === 'boolean' ? Number(value) : value, 'reader display ' + field)
      }
    } else if (reader && Object.hasOwn(reader, snake(key))) {
      assertSame(reader[snake(key)], row['value_' + row.value_kind.replace('string', 'text')], 'reader ' + key)
    }
  }
  for (const [domain, column, sourceColumn] of [
    ['preferences/koma_reader_preferences_v1/reader.bannerFilterOverrides.v1', 'banner_filter', 'value_text'],
    ['preferences/koma_manga_synopsis_v1/', 'synopsis_expanded', 'value_boolean'],
  ]) {
    assertSame(target.prepare('SELECT comic_id, ' + column + ' AS value FROM book_preferences WHERE ' + column +
      ' IS NOT NULL ORDER BY comic_id').all(),
    source.prepare('SELECT preference_id AS comic_id, ' + sourceColumn +
      ' AS value FROM typed_local_preferences WHERE domain=? ORDER BY comic_id').all(domain), column)
  }
  assert.equal(target.prepare("SELECT count(*) AS total FROM typed_local_preferences WHERE preference_id='reader.displaySettings'").get().total, 0)
  compareSplitChapterCatalogs(source, target)
  compareScopedBusinessRows(source, target)
  assert.equal(target.prepare('PRAGMA user_version').get().user_version, 9)
  assert.equal(target.prepare('PRAGMA quick_check').get().quick_check, 'ok')
  assert.equal(target.prepare('PRAGMA foreign_key_check').all().length, 0)
}

function compareSplitChapterCatalogs(source, target) {
  const sort = ' ORDER BY comic_id, list_kind, item_order'
  assertSame(target.prepare('SELECT * FROM shelf_work_metadata_items UNION ALL ' +
    "SELECT comic_id, 'shared_chapter', chapter_order, chapter_id FROM shelf_shared_chapters_all" + sort).all(),
  source.prepare('SELECT * FROM shelf_work_metadata_items' + sort).all(), 'split shared chapter IDs')
}

function readSplitReaderPreferences(database) {
  const local = database.prepare('SELECT * FROM reader_preferences WHERE id=1').get()
  const shared = database.prepare('SELECT * FROM reader_shared_preferences WHERE id=1').get()
  if (!local && !shared) return undefined
  return { ...local, ...shared, page_mode: local?.page_mode ?? shared?.page_mode ?? null }
}

const scopedTables = ['shelf_works', 'shelf_memberships', 'reader_current_positions', 'reader_chapter_states', 'reader_source_history']

function compareScopedBusinessRows(source, target) {
  for (const table of scopedTables.slice(1)) {
    const names = source.prepare('PRAGMA table_info(' + table + ')').all()
    if (names.length === 0) continue
    const columns = names.map(row => row.name).join(', ')
    const key = names.filter(row => row.pk > 0).sort((left, right) => left.pk - right.pk).map(row => row.name).join(', ')
    const order = ' ORDER BY ' + key
    const migrated = table === 'reader_source_history' ? names.map(({ name }) =>
      name === 'manga_url' || name === 'cover_uri' ? `COALESCE(${name}, shared_${name}) AS ${name}` : name).join(', ') : columns
    assertSame(target.prepare('SELECT ' + migrated + ' FROM ' + table + '_all' + order).all(),
      source.prepare('SELECT ' + columns + ' FROM ' + table + order).all(), table)
  }
}

function compareVersionSix(source, target) {
  compareSplitChapterCatalogs(source, target)
  assertSame(readSplitReaderPreferences(target), source.prepare('SELECT * FROM reader_preferences WHERE id=1').get(),
    'effective global reader preferences')
  assertSame(target.prepare('SELECT comic_id, page_mode, reading_direction FROM book_reader_modes_all ORDER BY comic_id').all(),
    source.prepare('SELECT comic_id, page_mode, reading_direction FROM book_preferences ' +
      'WHERE has_reader_mode=1 ORDER BY comic_id').all(), 'split book reader modes')
  const order = ' ORDER BY comic_id'
  const columns = target.prepare('PRAGMA table_info(book_preferences)').all().map(row => row.name).join(', ')
  assertSame(target.prepare('SELECT ' + columns + ' FROM book_preferences' + order).all(),
    source.prepare('SELECT ' + columns + ' FROM book_preferences WHERE has_reader_mode=0 OR has_chapter_settings=1 ' +
      'OR banner_filter IS NOT NULL OR synopsis_expanded IS NOT NULL' + order).all(), 'retained book settings')
  assertSame(target.prepare('SELECT * FROM shelf_works_all ORDER BY comic_id').all(),
    source.prepare('SELECT * FROM shelf_works ORDER BY comic_id').all(), 'split shelf works')
  compareScopedBusinessRows(source, target)
  const transformed = new Set(['shelf_work_metadata_items', 'reader_preferences', 'book_preferences',
    'local_data_migrations', ...scopedTables])
  for (const { name } of source.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").all()) {
    if (transformed.has(name)) continue
    assertSame(target.prepare('SELECT * FROM ' + name + ' ORDER BY rowid').all(),
      source.prepare('SELECT * FROM ' + name + ' ORDER BY rowid').all(), name)
  }
  assert.equal(target.prepare('PRAGMA user_version').get().user_version, 9)
  assert.equal(target.prepare('PRAGMA quick_check').get().quick_check, 'ok')
  assert.equal(target.prepare('PRAGMA foreign_key_check').all().length, 0)
}

function previousPreferenceValues(old, domain) {
  const items = checkpointRows(old, domain)
  if (items === undefined) return undefined
  const values = {}
  for (const [key, value] of items) {
    let parsed = JSON.parse(value)
    if (key === 'libraryUpdate.latestResultJson' || key === 'libraryUpdate.latestJobJson') parsed = JSON.parse(parsed)
    values[key] = parsed
  }
  return values
}

async function verifyOtherDomains(old, env, store) {
  if (old === undefined) return []
  const { load, context } = env
  const verified = []
  const domains = old.prepare('SELECT name FROM local_data_migrations ORDER BY name').all().map(row => row.name)
  const { PreferenceColumnRows } = load('model/PreferenceColumnRows')
  for (const domain of domains.filter(name => name.startsWith('preferences/'))) {
    const [, name, key] = domain.split('/')
    const rows = new PreferenceColumnRows(store, name, key)
    rows.migrate(undefined)
    const values = rows.entries()
    const actual = values === undefined ? undefined : Object.fromEntries([...values.entries()].map(([id, value]) => {
      let decoded = JSON.parse(value)
      if (id === 'libraryUpdate.latestResultJson' || id === 'libraryUpdate.latestJobJson') decoded = JSON.parse(decoded)
      return [id, decoded]
    }))
    assertSame(actual, previousPreferenceValues(old, domain), domain)
    verified.push(domain)
  }
  const sourceRegistry = 'source-runtime/source-runtime-registry.json'
  if (domains.includes(sourceRegistry)) {
    const registry = load('sourceRuntime/SourceRegistryDatabase')
    await registry.prepareSourceRegistryDatabase(context, false)
    const previous = checkpointRows(old, sourceRegistry)
    const entries = previous === undefined ? undefined : [...previous.values()]
      .map(value => JSON.parse(value)).sort((left, right) => left.order - right.order).map(row => row.entry)
    assertSame(registry.readSourceRegistryMetadata(path.join(context.filesDir, sourceRegistry)),
      entries === undefined ? undefined : { schemaVersion: 1, entries }, sourceRegistry)
    verified.push(sourceRegistry)
  }
  const { SourcePreferenceRows } = load('sourceRuntime/SourcePreferencePersistence')
  for (const domain of ['source-runtime/source-settings.json', 'source-runtime/source-filter-preferences.json',
    'source-runtime/source-setting-observations.json'].filter(name => domains.includes(name))) {
    const current = new SourcePreferenceRows(store, domain)
    current.migrate(undefined)
    assertSame(current.read(), previousPreferenceValues(old, domain), domain)
    verified.push(domain)
  }
  if (domains.includes('source-subscriptions')) {
    const subscriptions = load('sourceRuntime/SourceSubscriptionStorage')
    const previous = checkpointRows(old, 'source-subscriptions') ?? new Map()
    const url = previous.has('active') ? JSON.parse(previous.get('active')) : undefined
    const repositories = previous.has('list') ? [...previous.entries()].filter(([key]) => key.startsWith('repo/'))
      .map(([, value]) => JSON.parse(value)).sort((left, right) => left.order - right.order).map(row => row.repository) : undefined
    assertSame(await subscriptions.loadSourceSubscriptionPreferences(context), { url, repositories }, 'source-subscriptions')
    verified.push('source-subscriptions')
  }
  if (domains.includes('image-rule-configuration')) {
    const images = load('model/ImageRuleDatabase')
    await images.prepareImageRuleDatabase(context)
    const legacy = checkpointRows(old, 'image-rule-configuration')
    const expected = legacy === undefined ? undefined : [...legacy.values()].map(value => JSON.parse(value))
    const checkpoint = images.readImageRuleDatabaseCheckpoint(context.filesDir)
    const normalize = rows => rows?.slice().sort((left, right) => left.key.localeCompare(right.key))
    assertSame(normalize(checkpoint === undefined ? undefined : JSON.parse(checkpoint).databaseRows.map(row => JSON.parse(row))),
      normalize(expected), 'image-rule-configuration')
    verified.push('image-rule-configuration')
  }
  const queues = domains.filter(name => name.startsWith('offline-queue/'))
  if (queues.length > 0) {
    const queue = load('model/OfflineDownloadQueueStore')
    await queue.prepareOfflineQueueDatabase(context)
    for (const domain of queues) {
      const legacy = checkpointRows(old, domain)
      const expected = legacy === undefined ? undefined : {
        schemaVersion: 1,
        preferences: legacy.has('settings') ? JSON.parse(legacy.get('settings')) : undefined,
        entries: [...legacy.entries()].filter(([key]) => key.startsWith('chapter/')).map(([, value]) => JSON.parse(value))
          .sort((left, right) => left.order - right.order).map(row => row.entry),
      }
      const raw = queue.readOfflineQueueDatabaseSnapshot(context.filesDir, domain.slice('offline-queue/'.length))
      assertSame(raw === undefined ? undefined : JSON.parse(raw), expected, domain)
      verified.push(domain)
    }
  }
  const jobs = domains.filter(name => name.startsWith('generated-download/'))
  if (jobs.length > 0) {
    const worker = load('model/GeneratedDownloadWork')
    for (const domain of jobs) {
      const previous = [...(checkpointRows(old, domain) ?? new Map()).values()].map(value => JSON.parse(value))
      assertSame(await worker.readGeneratedDownloadWork(context, domain.slice('generated-download/'.length)), previous, domain)
      verified.push(domain)
    }
  }
  return verified
}

async function verifyLegacyDomains(old, env, store, archive, preferences) {
  const { load, context } = env
  const checked = []
  const domains = load('model/MigratedPreferenceRecords')
  for (const label of ['chapterListRecords', 'sourceBrowseLayoutRecords', 'synopsisRecords', 'readerModeRecords',
    'readerBannerRecords', 'readerGlobalRecords', 'trackerMappingRecords', 'catalogFilterRecords']) {
    const domain = domains[label]
    const keys = preferences[domain.name]
    if (keys === undefined || hasMigration(old, 'preferences/' + domain.name + '/' + domain.key)) continue
    const records = await domain.prepare(context)
    if (domain.key === '') {
      const values = { ...keys }
      if (label === 'readerGlobalRecords') {
        delete values['reader.seriesModeOverrides.v1']
        delete values['reader.bannerFilterOverrides.v1']
        delete values['reader.seriesOverrides.v1']
      }
      assertSame(Object.fromEntries([...records.entries()].map(([key, value]) => [key, JSON.parse(value)])), values, label)
    } else {
      const raw = keys[domain.key]
      const actual = await domain.readBackupValue(context)
      assertSame(actual === undefined ? undefined : JSON.parse(actual),
        raw === undefined ? undefined : raw === '' && label === 'readerBannerRecords' ? {} : JSON.parse(raw), label)
    }
    checked.push(label)
  }
  const registryPath = 'source-runtime/source-runtime-registry.json'
  const registryDocument = jsonFile(archive, 'source-runtime-registry.json')
  if (!hasMigration(old, registryPath) && registryDocument !== undefined) {
    const registry = load('sourceRuntime/SourceRegistryDatabase')
    await registry.prepareSourceRegistryDatabase(context, true)
    assertSame(registry.readSourceRegistryMetadata(path.join(context.filesDir, registryPath)), registryDocument, 'legacy registry')
    checked.push('legacy registry')
  }
  const { SourcePreferenceRows } = load('sourceRuntime/SourcePreferencePersistence')
  for (const file of ['source-settings.json', 'source-filter-preferences.json', 'source-setting-observations.json']) {
    const scope = 'source-runtime/' + file
    const legacy = jsonFile(archive, file)
    if (legacy === undefined || hasMigration(old, scope)) continue
    const rows = new SourcePreferenceRows(store, scope)
    rows.migrate(legacy.sources)
    assertSame(rows.read(), legacy.sources, file)
    checked.push(file)
  }
  return checked
}

async function verify(archive) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-local-upgrade-'))
  const sourceIsBusinessDatabase = fs.existsSync(path.join(archive, 'Koma.db'))
  const sourcePath = path.join(archive, sourceIsBusinessDatabase ? 'Koma.db' : 'koma-user-data.db')
  const databasePath = path.join(directory, temporaryDatabase)
  let old
  let rdb
  try {
    const rdbDir = path.join(directory, 'rdb')
    fs.mkdirSync(rdbDir)
    if (fs.existsSync(sourcePath)) {
      copyDatabase(sourcePath, sourceIsBusinessDatabase ? databasePath : path.join(rdbDir, 'koma-user-data.db'))
      old = new DatabaseSync(sourcePath, { readOnly: true })
    } else {
      assert(fs.existsSync(path.join(archive, 'library-store.v1.json')), 'missing old library input')
      assert(fs.existsSync(path.join(archive, 'reader-sessions.v1.json')), 'missing old reader input')
    }
    const preferences = readLegacyPreferences(archive)
    rdb = createRdbPort(databasePath)
    const env = moduleLoader(rdb, directory, archive, preferences)
    const beforeVersion = old?.prepare('PRAGMA user_version').get().user_version ?? 0
    if (beforeVersion === 8 || beforeVersion === 9) {
      await env.load('model/UserDataDatabase').openUserDataDatabase(env.context)
      rdb.close()
      rdb = createRdbPort(databasePath)
      const reopened = moduleLoader(rdb, directory, archive, preferences)
      await reopened.load('model/UserDataDatabase').openUserDataDatabase(reopened.context)
      const target = new DatabaseSync(databasePath, { readOnly: true })
      try {
        const tables = old.prepare("SELECT name FROM sqlite_master WHERE type='table' " +
          "AND name NOT LIKE 'sqlite_%' AND name NOT GLOB 'naturalbase_*'").all()
        for (const { name } of tables) {
          const table = '"' + name.replaceAll('"', '""') + '"'
          const query = 'SELECT * FROM ' + table + ' ORDER BY rowid'
          assertSame(target.prepare(query).all(), old.prepare(query).all(), name)
        }
        await prepareCloudBusinessTables(reopened)
        compareCloudTables(target)
        assert.equal(target.prepare('PRAGMA quick_check').get().quick_check, 'ok')
        assert.equal(target.prepare('PRAGMA foreign_key_check').all().length, 0)
        console.log(JSON.stringify({ archive, schema: beforeVersion, migration: 'matched', reopened: true }))
      } finally { target.close() }
      return
    }
    if (beforeVersion === 5 || beforeVersion === 6) {
      const open = env.load('model/UserDataDatabase').openUserDataDatabase
      rdb.failNextCommit('upgrade interrupted before commit')
      await assert.rejects(open(env.context), /upgrade interrupted before commit/)
      const interrupted = new DatabaseSync(databasePath, { readOnly: true })
      try {
        assert.equal(interrupted.prepare('PRAGMA user_version').get().user_version, beforeVersion === 6 ? 6 : 0)
        assert.equal(interrupted.prepare("SELECT 1 FROM sqlite_master WHERE name='shelf_shared_chapters'").get(), undefined)
        if (beforeVersion === 6) {
          assertSame(interrupted.prepare('SELECT * FROM shelf_work_metadata_items ORDER BY rowid').all(),
            old.prepare('SELECT * FROM shelf_work_metadata_items ORDER BY rowid').all(), 'rollback kept the old catalog')
        }
      } finally { interrupted.close() }
      await open(env.context)
      rdb.close()
      rdb = createRdbPort(databasePath)
      const reopened = moduleLoader(rdb, directory, archive, preferences)
      await reopened.load('model/UserDataDatabase').openUserDataDatabase(reopened.context)
      const target = new DatabaseSync(databasePath, { readOnly: true })
      try {
        if (beforeVersion === 6) compareVersionSix(old, target)
        else compareVersionFive(old, target)
        await prepareCloudBusinessTables(reopened)
        compareCloudTables(target)
        console.log(JSON.stringify({ archive, schema: beforeVersion, migration: 'matched', rolledBackAndRetried: true, reopened: true }))
      } finally { target.close() }
      return
    }
    const expectedLibrary = previousShelf(old, archive)
    const expectedReader = previousReading(old, archive)
    const store = await env.load('model/UserDataDatabase').openUserDataDatabase(env.context)
    const { LibraryRdbStorage } = env.load('model/LibraryRdbStorage')
    const { ReaderRdbStorage } = env.load('model/ReaderRdbStorage')
    const library = new LibraryRdbStorage(store)
    const reader = new ReaderRdbStorage(store)
    await library.migrate(expectedLibrary)
    await reader.migrate(expectedReader)
    assertSame(library.read(), expectedLibrary, 'library')
    assertSame(reader.read(), expectedReader, 'reading')
    const otherDomains = await verifyOtherDomains(old, env, store)
    const legacyDomains = await verifyLegacyDomains(old, env, store, archive, preferences)
    rdb.close()
    rdb = createRdbPort(databasePath)
    const reopened = moduleLoader(rdb, directory, archive, preferences)
    const current = await reopened.load('model/UserDataDatabase').openUserDataDatabase(reopened.context)
    const nextLibrary = new (reopened.load('model/LibraryRdbStorage').LibraryRdbStorage)(current)
    const nextReader = new (reopened.load('model/ReaderRdbStorage').ReaderRdbStorage)(current)
    await nextLibrary.migrate(undefined)
    await nextReader.migrate({ progress: [], chapters: [], sourceHistory: [] })
    assertSame(nextLibrary.read(), expectedLibrary, 'library after reopen')
    assertSame(nextReader.read(), expectedReader, 'reading after reopen')
    await verifyOtherDomains(old, reopened, current)
    await verifyLegacyDomains(old, reopened, current, archive, preferences)
    const saved = new DatabaseSync(databasePath, { readOnly: true })
    try {
      await prepareCloudBusinessTables(reopened)
      compareCloudTables(saved)
      assert.equal(saved.prepare('PRAGMA quick_check').get().quick_check, 'ok')
      assert.equal(saved.prepare('PRAGMA foreign_key_check').all().length, 0)
      const schema = old?.prepare('PRAGMA user_version').get().user_version ?? 0
      console.log(JSON.stringify({ archive, schema, migration: 'matched',
        works: expectedLibrary?.comics.length ?? 0,
        chapters: expectedLibrary?.comics.reduce((count, work) => count + work.chapters.length, 0) ?? 0,
        chapterStates: expectedReader.chapters.length, readingPositions: expectedReader.progress.length,
        importRecords: expectedLibrary?.mihonImports?.length ?? 0,
        otherDomains, legacyDomains, reopened: true }))
    } finally {
      saved.close()
    }
  } finally {
    old?.close()
    rdb?.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
}

async function main() {
  const archives = process.argv.slice(2)
  assert(archives.length > 0, 'Usage: node scripts/verify_local_data_upgrade.cjs <old-data-directory> [...]')
  for (const archive of archives) await verify(path.resolve(archive))
}

main().catch(error => {
  console.error(error.message)
  process.exitCode = 1
})
