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
