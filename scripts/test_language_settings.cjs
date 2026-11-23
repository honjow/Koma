const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

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
