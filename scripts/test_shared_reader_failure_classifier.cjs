const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const root = path.resolve(__dirname, '../entry/src/main/ets')
const failureSource = fs.readFileSync(path.join(root, 'readerLab/KomaReaderFailure.ets'), 'utf8')
const output = ts.transpileModule(failureSource, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
} }).outputText
const exported = {}
new Function('exports', 'require', output)(exported, function (name) {
  if (name === '../i18n/AppStrings') return { AppStrings: { get: function (key) { return key === 'reader_page_load_failed' ? 'Koma page failed' : key } } }
  if (name === '@reader-kit/core') return { ReaderAssetFailure: class {
    constructor(code, title, hint) { Object.assign(this, { code: code, title: title || '', hint: hint || '' }) }
  } }
  throw new Error('Unexpected import: ' + name)
})
const KomaReaderFailure = exported.KomaReaderFailure
const failure = KomaReaderFailure.from(new Error('missing_chapter_page'))
assert.equal(failure.code, 'pageUnavailable')
assert.equal(failure.title, 'Koma page failed')

const adapter = fs.readFileSync(path.join(root, 'readerLab/KomaReaderLabAdapter.ets'), 'utf8')
assert.ok(adapter.indexOf('ReaderAssetFailureClassifier') >= 0)
assert.ok(adapter.indexOf('classify(error: Error): ReaderAssetFailure') >= 0)
assert.ok(adapter.indexOf('KomaReaderFailure.from(error)') >= 0)

const page = fs.readFileSync(path.join(root, 'readerLab/KomaReaderLabPage.ets'), 'utf8')
assert.ok(page.indexOf('new ReaderPagedSession(adapter, adapter, adapter, adapter)') >= 0)

console.log('PASS Koma host failure classification and session wiring')
