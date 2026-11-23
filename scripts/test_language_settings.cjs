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
    await LanguageSettings.setMode({}, mode)
    assert.equal(data.get('app.language'), mode)
    assert.equal(state.mode, mode)
    assert.equal(state.effectiveLocale, mode)
    assert.equal(platformMode, mode)
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
