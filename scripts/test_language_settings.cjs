const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function sourceModules(state = { effectiveLocale: 'zh-HK' }, extra = {}) {
  const root = path.join(__dirname, '../entry/src/main/ets')
  const cache = new Map()
  const platform = {
    '../state/LanguageState': { connectLanguageState: () => state },
    '@kit.BasicServicesKit': { deviceInfo: { sdkApiVersion: 0 } },
    './SourceWebsitePolicy': { SOURCE_FRESH_HTTP_MIN_SDK: 26 },
    './SourceRequiredImageDecodeDeclaration': { SOURCE_IMAGE_PROCESSOR_FEATURE: 'source_required_image_decode_wasm_v1' },
    ...extra,
  }
  return function load(file) {
    if (cache.has(file)) return cache.get(file)
    const exports = {}
    cache.set(file, exports)
    const compiled = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
    }).outputText
    new Function('exports', 'require', compiled)(exports, name => {
      if (platform[name]) return platform[name]
      if (name.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)) + '.ets')
      throw Error('Unexpected source import: ' + name)
    })
    return exports
  }
}

test('static presentation resolves script/default per key, tolerates bad optional translations and keeps auth identity', () => {
  const load = sourceModules({}, { '@kit.ArkTS': { url: { URL } } })
  const { normalizeSourcePresentation: normalize, resolveSourcePresentationText: resolve } =
    load('sourceRuntime/SourcePresentation.ets')
  const { resolveSourceLocalizedName: name } = load('sourceRuntime/SourceLocalizedNames.ets')
  const { sourceAuthenticationIdentity } = load('sourceRuntime/SourceAuthenticationDescriptor.ets')
  const authentication = { kind: 'credentials', loginUrl: 'https://example.org/login',
    credentialStorage: 'private', usernameLabel: 'Login', passwordLabel: 'Password' }
  const identity = sourceAuthenticationIdentity(authentication)
  const presentation = normalize({ version: 1, defaultLocale: 'zh-Hant', texts: {
    name: { en: 'Example', 'zh-Hant': '範例', 'zh-Hans': '范例' },
    description: { en: '\ud800', 'zh-Hant': '完整說明', 'zh-Hans': '完整说明' },
    'authentication.usernameLabel': { 'zh-Hant': '帳號' },
    action: { en: 'Not an executable action' },
  } })
  assert.equal(resolve('', presentation, 'description', 'zh-HK'), '完整說明')
  assert.equal(resolve('literal', presentation, 'description', 'en-US'), '完整說明')
  assert.equal(resolve('literal', presentation, 'description', ''), '完整說明')
  assert.equal(name('literal', undefined, 'zh-Hans-HK', presentation), '范例')
  assert.equal(name('literal', undefined, 'zh-HK', presentation), '範例')
  assert.equal(name('MYCOMIC', undefined, 'zh-HK'), 'MYCOMIC')
  assert.equal(resolve(authentication.usernameLabel, presentation, 'authentication.usernameLabel', 'zh-HK'), '帳號')
  assert.equal(sourceAuthenticationIdentity(authentication), identity)
  assert.equal(resolve('literal', presentation, 'action', 'en'), 'literal')
  assert.equal(resolve('literal', normalize({ version: 2, texts: presentation.texts }), 'name', 'en'), 'literal')
  const overflow = Object.fromEntries(Array.from({ length: 17 }, (_, i) => ['en-' + (100 + i), 'value']))
  const partial = normalize({ version: 1, texts: { name: overflow, description: { en: 'still available' } } })
  assert.equal(resolve('literal', partial, 'name', 'en'), 'literal')
  assert.equal(resolve('', partial, 'description', 'en'), 'still available')
})

test('presentation survives real registry SQL, index cache projection and shared-manifest export with canonical auth', async () => {
  const rdb = require('./user_data_rdb_fixture.cjs').createRdbPort()
  try {
    const load = sourceModules({}, { '@kit.ArkData': { relationalStore: rdb.relationalStore },
      '@kit.ArkTS': { url: { URL: { parseURL: text => new URL(text) } } } })
    const store = await rdb.relationalStore.getRdbStore({ filesDir: 'localization' }, { name: 'Koma.db' })
    const root = path.join(__dirname, '../entry/src/main/ets')
    // Execute the actual schema declarations, rather than a second test schema.
    const schema = ts.createSourceFile('schema.ts', fs.readFileSync(path.join(root, 'model/UserDataDatabase.ets'), 'utf8'),
      ts.ScriptTarget.Latest, true)
    const config = schema.statements.flatMap(node => node.declarationList?.declarations ?? [])
      .find(node => node.name?.text === 'CONFIG_TABLES')
    for (const entry of config.initializer.elements.filter(node => node.getText(schema).includes('CREATE TABLE IF NOT EXISTS source_registry_'))) {
      store.executeSync(new Function('return ' + entry.getText(schema))())
    }
    const p = load('sourceRuntime/SourcePresentation.ets')
    const presentation = p.normalizeSourcePresentation({ version: 1, defaultLocale: 'zh-Hant',
      texts: { name: { en: 'Example', 'zh-Hant': '範例' }, description: { 'zh-Hant': '非空說明' } } })
    const authentication = { kind: 'credentials', loginUrl: 'https://example.org/login',
      credentialStorage: 'private', usernameLabel: 'Login', passwordLabel: 'Password' }
    const rows = load('sourceRuntime/SourceRegistryRows.ets')
    rows.replaceSourceRegistryRows(store, [{ sourceId: 'test', manifestId: 'test', manifestVersion: '1',
      presentation, authentication }])
    const restored = rows.readSourceRegistryRows(store)[0]
    assert.deepEqual(restored.presentation, presentation)
    assert.equal(restored.authentication.usernameLabel, 'Login')
    rows.replaceSourceRegistryRows(store, [{ sourceId: 'legacy' }])
    assert.equal(rows.readSourceRegistryRows(store)[0].presentation, undefined)
    const index = load('sourceRuntime/SourceIndexMetadata.ets')
    const entry = index.parseIndexEntry({ id: 'test', name: 'Example', pkg: 'test.koma',
      icon: 'test.png', presentation })
    const cached = index.parseCachedIndexEntries(JSON.parse(JSON.stringify([index.entryWithCachedIcon(entry, 'safe-icon')])),
      'https://example.org/index.json')
    assert.deepEqual(cached[0].presentation, presentation)
    const importer = ts.createSourceFile('importer.ts', fs.readFileSync(path.join(root,
      'sourceRuntime/SourcePackageImporter.ets'), 'utf8'), ts.ScriptTarget.Latest, true)
    const method = importer.statements.find(node => node.name?.text === 'sourceRepoManifestForShare')
    const js = ts.transpileModule(method.getText(importer), { compilerOptions: {
      module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
    const exports = {}
    new Function('exports', 'normalizeSourcePresentation', 'normalizeSourceCommentsCapability', js)(
      exports, p.normalizeSourcePresentation, () => undefined)
    const shared = JSON.parse(exports.sourceRepoManifestForShare({ package: { id: 'test', name: 'Example',
      version: '1', presentation, description: '' }, permissions: { authentication },
      runtime: {}, contentPolicy: {} }, 'icon.png'))
    assert.deepEqual(shared.presentation, presentation)
    assert.deepEqual(shared.authentication, authentication)
    assert.equal(shared.description, '')
  } finally { rdb.close() }
})

test('source calls capture one UI language before admission and feature negotiation keeps canonical arguments', () => {
  const state = { effectiveLocale: 'zh-HK' }
  const load = sourceModules(state)
  const environment = load('sourceRuntime/SourceRuntimeEnvironment.ets')
  const host = load('sourceRuntime/SourceHostFeatures.ets')
  for (const operation of ['search', 'get_manga', 'get_chapters', 'get_pages', 'get_settings', 'get_filters',
    'get_listings', 'get_home', 'get_image_request', 'get_comments', 'get_authentication', 'authenticate', 'logout']) {
    const original = { type: 'request', operation, args: { id: 'same', filters: { language: 'ja' } },
      settings: { mirror: 'default' }, hostHints: { network: operation !== 'get_settings' } }
    const captured = environment.sourceRequestWithEnvironment(JSON.stringify(original))
    const actual = JSON.parse(host.sourceRequestWithHostFeatures(captured))
    assert.equal(actual.environment.uiLocale, 'zh-HK')
    assert.deepEqual(actual.environment.localeFallbacks, ['zh-HK', 'zh-Hant-HK', 'zh-Hant', 'zh'])
    assert(actual.hostFeatures.includes('source_localization_v1'))
    assert.deepEqual(actual.args, original.args)
    assert.deepEqual(actual.settings, original.settings)
    assert.deepEqual(actual.hostHints, original.hostHints)
  }
  const captured = environment.sourceRequestWithEnvironment(JSON.stringify({ type: 'request', operation: 'get_filters' }))
  state.effectiveLocale = 'en-US'
  assert.equal(environment.sourceRequestWithEnvironment(captured), captured)
  assert.equal(JSON.parse(environment.sourceRequestWithEnvironment(JSON.stringify({ type: 'request',
    operation: 'get_filters' }))).environment.uiLocale, 'en-US')
  const unknown = { type: 'request', operation: 'get_filters', environment: { version: 2 } }
  const unknownJson = environment.sourceRequestWithEnvironment(JSON.stringify(unknown))
  assert(!JSON.parse(host.sourceRequestWithHostFeatures(unknownJson)).hostFeatures.includes('source_localization_v1'))
  assert.equal(environment.sourceRequestWithEnvironment('invalid'), 'invalid')
  assert(!JSON.parse(environment.sourceRequestWithEnvironment(JSON.stringify({ type: 'request',
    operation: 'source_info' }))).environment)
})

test('language schema refresh preserves control values and rejects old locale publications', async () => {
  const root = path.join(__dirname, '../entry/src/main/ets')
  let revision = 'Hant:1'
  const tree = ts.createSourceFile('settings.ts', fs.readFileSync(path.join(root, 'sourceRuntime/SourceSettingsStore.ets'), 'utf8'),
    ts.ScriptTarget.Latest, true)
  const names = ['sourceSettingDisplayDescriptors', 'sourceSettingsDescriptorsCurrent']
  const code = tree.statements.filter(node => names.includes(node.name?.text)).map(node => node.getText(tree)).join('\n')
  const api = {}
  new Function('exports', 'sourceRuntimeLocaleRevision', ts.transpileModule(code, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText)(api, () => revision)
  const original = [{ id: 'mirror', kind: 'select', label: '鏡像', defaultValue: 'com',
    options: [{ id: 'com', label: '原站' }], supported: true, sensitive: false,
    validation: { kind: 'non_blank', message: '不可空白' } }]
  const translated = [{ ...original[0], label: 'Mirror', defaultValue: 'cc', kind: 'text',
    options: [{ id: 'cc', label: 'Other' }, { id: 'com', label: 'Original' }],
    validation: { kind: 'non_blank', message: 'Required' } }]
  const result = api.sourceSettingDisplayDescriptors(original, translated)
  assert.equal(result[0].label, 'Mirror')
  assert.deepEqual(result[0].options, [{ id: 'com', label: 'Original' }])
  assert.equal(result[0].kind, 'select')
  assert.equal(result[0].defaultValue, 'com')
  assert.equal(result[0].validation.message, 'Required')
  const stale = { ready: true, descriptors: original, localeRevision: revision }
  revision = 'en:2'
  assert.equal(api.sourceSettingsDescriptorsCurrent(stale), false)
  revision = 'Hant:3'
  assert.equal(api.sourceSettingsDescriptorsCurrent(stale), false)
  assert.equal(api.sourceSettingsDescriptorsCurrent({ ...stale, localeRevision: revision }), true)

  const input = fs.readFileSync(path.join(root, 'components/SourceSettingsSheetContent.ets'), 'utf8')
    .replace('export struct SourceSettingsSheetContent', 'export class SourceSettingsSheetContent')
  const formTree = ts.createSourceFile('form.ts', input, ts.ScriptTarget.Latest, true)
  const owner = formTree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'SourceSettingsSheetContent')
  const methods = ['displayDescriptors', 'refreshLanguageDescriptors'].map(name =>
    owner.members.find(node => node.name?.text === name).getText(formTree)).join('\n').replace(/@Computed\s*/g, '')
  const exports = {}, entry = {}, pending = []
  new Function('exports', 'appSourceRuntimeRegistry', 'appSourceSettingsStore', 'loadSourceSettingsDescriptorsAsync',
    'sourceSettingsDescriptorsCurrent', 'sourceSettingDisplayDescriptors', ts.transpileModule(`export class Form {${methods}}`, {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    }).outputText)(exports, { lookup: () => ({ entry }) }, { revisionForSource: () => 0 },
    () => { const localeRevision = revision; return new Promise(resolve => pending.push(data =>
      resolve({ ready: true, descriptors: data, localeRevision }))) },
    api.sourceSettingsDescriptorsCurrent, api.sourceSettingDisplayDescriptors)
  const draft = { mirror: 'com' }
  const form = Object.assign(new exports.Form(), { mounted: true, active: true, settingsSourceId: 'source',
    textRefreshRevision: 0, settingDescriptors: original, localizedDescriptors: [], settingDraft: draft,
    regexErrors: { mirror: '不可空白' } })
  const old = form.refreshLanguageDescriptors()
  revision = 'en:4'
  const fresh = form.refreshLanguageDescriptors()
  pending[1](translated); await fresh
  pending[0](original); await old
  assert.equal(form.displayDescriptors[0].label, 'Mirror')
  assert.equal(form.regexErrors.mirror, 'Required')
  assert.equal(form.settingDraft, draft)
  assert.deepEqual(form.settingDraft, { mirror: 'com' })
})

test('browse labels publish only the latest locale while retaining content, selected IDs and filter values', async () => {
  const file = path.join(__dirname, '../entry/src/main/ets/viewmodel/BrowseViewModel.ets')
  const tree = ts.createSourceFile('browse.ts', fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true)
  const owner = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'BrowseViewModel')
  const methods = ['refreshSourceLanguage', 'filterDisplayTexts', 'listingDisplayText',
    'fetchSourceFilterData', 'cancelFilterDataLoad'].map(name =>
    owner.members.find(node => node.name?.text === name).getText(tree)).join('\n')
  const models = sourceModules({}, { '../i18n/AppStrings': { AppStrings: { get: key => key } } })('model/SourceModels.ets')
  let revision = 'Hant:1'
  const exports = {}, entry = {}, source = { sourceId: 'source' }
  new Function('exports', 'sourceRuntimeLocaleRevision', 'appSourceSettingsStore', 'parseSourceFilterSchemaJson',
    'safeSourceBrowseErrorText', ts.transpileModule(`export class Model {${methods}}`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText)(exports, () => revision, { revisionForSource: () => 0 }, models.parseSourceFilterSchemaJson, error => error.message)
  const choices = { genre: 'action' }, content = [{ id: 'retained', title: '原站作品' }]
  let releaseOld
  const network = []
  const model = Object.assign(new exports.Model(), { selectedSource: source, registry: { lookup: () => ({ entry }) },
    metadataLocaleRevision: '', metadataLanguagePending: '', filterDataRevision: 0,
    listings: [{ id: 'all', name: '全部', kind: 'latest', supportsFilters: false },
      { id: 'network-only', name: '動態欄目', kind: 'popular' }],
    filters: [], supportsFilterFetching: true, filterDataReady: false, useSearchForFilters: true,
    browseWebChallenge: null, searchWebChallenge: null, browseAuthentication: null, searchAuthentication: null,
    browseFilterValues: choices, searchFilterValues: choices, selectedListingId: 'all',
    browseSections: [{ listing: { id: 'all', name: '全部' }, manga: content, page: 3, hasNextPage: true }],
    loadSourceListings: async (_source, online) => {
      network.push(online)
      if (revision === 'Hant:1') return new Promise(resolve => { releaseOld = resolve })
      return [{ id: 'all', name: 'All', kind: 'popular', supportsFilters: true }]
    },
    loadSourceFilters: async (_source, online) => {
      network.push(online)
      // A real local-only initial response may contain only the base option;
      // it must not erase options loaded through fetchFilterData.
      return { filters: [{ id: 'header', type: 'header', name: 'Filters' },
        { id: 'genre', type: 'select', name: 'Genre', options: ['All'], optionIds: ['all'], value: 'changed' }] }
    },
    runSourceOperationResponse: async (_id, _op, args) => {
      assert.equal(args.fetchFilterData, true)
      return { data: { filters: [{ id: 'header', type: 'header', name: '篩選' },
        { id: 'genre', type: 'select', name: '題材', description: '保留原說明', scope: 'browse', value: 'all',
          options: [{ id: 'all', label: '全部' }, { id: 'action', label: '動作' }, { id: 'drama', label: '劇情' }] }] } }
    },
  })
  await model.fetchSourceFilterData()
  assert.equal(model.filterDataReady, true)
  assert.deepEqual(model.filters[1].optionIds, ['all', 'action', 'drama'])
  const filterDataRevision = model.filterDataRevision
  const old = model.refreshSourceLanguage()
  revision = 'en:2'
  await model.refreshSourceLanguage()
  releaseOld([{ id: 'all', name: '全部' }]); await old
  assert.equal(model.listings[0].name, 'All')
  assert.equal(model.listings[0].kind, 'latest')
  assert.equal(model.listings[0].supportsFilters, false)
  assert.equal(model.listings[1].id, 'network-only')
  assert.equal(model.browseSections[0].listing.name, 'All')
  assert.equal(model.filters[0].name, 'Filters')
  assert.equal(model.filters[1].name, 'Genre')
  assert.deepEqual(model.filters[1].options, ['All', '動作', '劇情'])
  assert.deepEqual(model.filters[1].optionIds, ['all', 'action', 'drama'])
  assert.equal(model.filters[1].value, 'all')
  assert.equal(model.filters[1].scope, 'browse')
  assert.equal(model.filters[1].description, '保留原說明')
  assert.equal(model.filterDataReady, true)
  assert.equal(model.filterDataRevision, filterDataRevision)
  assert.equal(model.supportsFilterFetching, true)
  assert.equal(model.useSearchForFilters, true)
  assert.equal(model.browseFilterValues, choices)
  assert.equal(model.searchFilterValues, choices)
  assert.equal(model.browseSections[0].manga, content)
  assert.equal(model.browseSections[0].page, 3)
  assert.equal(model.selectedListingId, 'all')
  assert(network.every(value => value === false))
  // An in-progress verification is never cancelled/replayed for UI text.
  revision = 'zh-Hans:3'
  model.browseWebChallenge = { id: 'active' }
  const before = network.length
  await model.refreshSourceLanguage()
  assert.equal(network.length, before)
  assert.equal(model.browseWebChallenge.id, 'active')
})

test('language preferences survive switches and roll back a failed change', async () => {
  const state = { mode: 'system', effectiveLocale: '' }
  const data = new Map()
  const store = {
    hasSync: key => data.has(key),
    getSync: (key, fallback) => data.has(key) ? data.get(key) : fallback,
    putSync: (key, value) => data.set(key, value),
    deleteSync: key => data.delete(key),
    flushSync() {},
  }
  let platformMode = 'default'
  let failLocale = false
  const modules = {
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn() {} } },
    '../model/BackupRestoreActivity': { BackupRestoreActivity: { runWrite: work => work() } },
    '@kit.AbilityKit': {},
    '@kit.ArkData': { preferences: { getPreferences: async () => store } },
    '@kit.LocalizationKit': { i18n: { System: {
      getSystemLanguage: () => 'zh-Hant-TW',
      setAppPreferredLanguage: mode => { platformMode = mode },
    } } },
    './AppStrings': { AppStrings: {
      get: name => name,
      setOverrideLocale: () => {
        if (failLocale) {
          failLocale = false
          throw new Error('locale failed')
        }
      },
    } },
    '../state/LanguageState': { connectLanguageState: () => state },
  }
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/i18n/LanguageSettings.ets'), 'utf8')
  const compiled = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  const exports = {}
  new Function('exports', 'require', compiled)(exports, name => {
    assert.ok(modules[name], `Unexpected import ${name}`)
    return modules[name]
  })
  const { LanguageSettings } = exports

  for (const mode of ['zh-Hans', 'zh-Hant', 'en-US', 'ja-JP', 'ko-KR']) {
    const revision = state.revision ?? 0
    await LanguageSettings.setMode({}, mode)
    assert.equal(data.get('app.language'), mode)
    assert.equal(state.mode, mode)
    assert.equal(state.effectiveLocale, mode)
    assert.equal(platformMode, mode)
    assert.equal(state.revision, revision + 1)
  }

  failLocale = true
  await assert.rejects(LanguageSettings.setMode({}, 'ja-JP'))
  assert.equal(data.get('app.language'), 'ko-KR')
  assert.equal(state.mode, 'ko-KR')
  assert.equal(platformMode, 'ko-KR')

  await LanguageSettings.setMode({}, 'system')
  assert.equal(platformMode, 'default')
  assert.equal(state.effectiveLocale, 'zh-Hant-TW')
  await LanguageSettings.restore({})
  assert.equal(state.mode, 'system')
})
