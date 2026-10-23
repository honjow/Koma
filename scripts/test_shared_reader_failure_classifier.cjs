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
const strings = {
  get: key => key === 'reader_page_load_failed' ? 'Koma page failed' : key,
  format: (_key, text, status) => `${text} HTTP ${status}`,
}
const errorExports = {}
new Function('exports', 'require', ts.transpileModule(
  fs.readFileSync(path.join(root, 'model/SourceRuntimeError.ets'), 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText)(errorExports, () => ({ AppStrings: strings }))
const exported = {}
const logEvents = []
const redactorExports = {}
new Function('exports', ts.transpileModule(fs.readFileSync(path.join(root, 'diagnostics/DiagnosticsRedactor.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
}).outputText)(redactorExports)
const redactor = redactorExports.DiagnosticsRedactor
new Function('exports', 'require', output)(exported, function (name) {
  if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { warn: (...args) => logEvents.push(args), errorSummary: error => redactor.errorSummary(error) } }
  if (name === '../i18n/AppStrings') return { AppStrings: strings }
  if (name === '../model/SourceRuntimeError') return errorExports
  if (name === '@reader-kit/core') return { ReaderAssetFailure: class {
    constructor(code, title, hint) { Object.assign(this, { code: code, title: title || '', hint: hint || '' }) }
  } }
  throw new Error('Unexpected import: ' + name)
})
const KomaReaderFailure = exported.KomaReaderFailure
const failure = KomaReaderFailure.from(new Error('missing_chapter_page'))
assert.equal(failure.code, 'pageUnavailable')
assert.equal(failure.title, 'Koma page failed')
assert.deepEqual(logEvents[0].slice(0, 2), ['reader', 'page_unavailable'])
assert.match(logEvents[0][2], /reason=missing_chapter_page/)
KomaReaderFailure.from(new Error('https://private.example/secret-title?token=secret'))
assert.equal(JSON.stringify(logEvents).includes('secret'), false)

const adapter = fs.readFileSync(path.join(root, 'readerLab/KomaReaderLabAdapter.ets'), 'utf8')
assert.ok(adapter.indexOf('ReaderAssetFailureClassifier') >= 0)
assert.ok(adapter.indexOf('classify(error: Error): ReaderAssetFailure') >= 0)
assert.ok(adapter.indexOf('KomaReaderFailure.from(error)') >= 0)

const page = fs.readFileSync(path.join(root, 'readerLab/KomaReaderLabPage.ets'), 'utf8')
assert.ok(page.indexOf('new ReaderPagedSession(adapter, adapter, adapter, adapter)') >= 0)

const compile = source => ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
} }).outputText
async function sourcePageFailureChain() {
  let response
  const hydratedExports = {}
  new Function('exports', 'require', compile(fs.readFileSync(
    path.join(root, 'model/SourceChapterPageHydrator.ets'), 'utf8')))(hydratedExports, name => {
    if (name === './SourceRuntimeError') return errorExports
    if (name === '@kit.ArkTS') return { taskpool: { execute: async () => JSON.stringify(response) } }
    if (name === '../sourceRuntime/SourceRuntimeRunner') return { diagnoseSourceOperation: (_request, execute) => execute() }
    if (name === '../sourceRuntime/SourceWebSessionStore') return { sourceHttpIdentityJson: () => '{}' }
    if (name === '../sourceRuntime/SourceSettingsStore') return { appSourceSettingsStore: { loadForSource: () => ({}) } }
    if (name === '../sourceRuntime/SourceRuntimeRegistry') return { sourceRuntimeEntryEnabled: () => true }
    if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { warn: () => {} } }
    if (name === './SourceTextNormalizer') return { normalizeSourceImageUrl: value => value }
    return {}
  })
  const registry = { lookup: () => ({ ok: true, entry: { sourceId: 'test.source', wasmBytes: new Uint8Array(1) } }) }
  const request = { comicId: 'work', sourceId: 'test.source', chapterId: 'chapter' }
  for (const [code, status, expected] of [
    ['network_error', 0, 'source_failure_network'], ['timeout', 0, 'source_failure_timeout'],
    ['permission_denied', 403, 'source_failure_access'], ['challenge_required', 403, 'source_failure_challenge'],
    ['server_error', 503, 'source_failure_server'], ['PRIVATE_TOKEN', 0, 'source_failure_runtime'],
  ]) {
    response = { ok: false, reasonCode: code, error: { code, status,
      message: 'https://private.example/PRIVATE_TOKEN?cookie=PRIVATE_TOKEN' } }
    const resolution = await hydratedExports.resolveSourceChapterPages(registry, request)
    assert.equal(resolution.reasonCode, 'source_pages_failed') // download/lookup contract stays unchanged
    const error = KomaReaderFailure.sourceError(resolution.sourceFailureReason, resolution.sourceFailure)
    const title = KomaReaderFailure.catalogMessage(error)
    assert.ok(title.startsWith(expected), title)
    assert.equal(title.includes('HTTP'), status > 0)
    assert.equal(JSON.stringify(resolution).includes('PRIVATE_TOKEN'), false)
    assert.equal(KomaReaderFailure.from(error).title, title)
  }
  response = { ok: false, reasonCode: 'unsupported', error: { code: 'unsupported' } }
  const unsupported = await hydratedExports.resolveSourceChapterPages(registry, request)
  assert.equal(KomaReaderFailure.catalogMessage(KomaReaderFailure.sourceError(
    unsupported.sourceFailureReason, unsupported.sourceFailure)), 'reader_source_chapter_unsupported')
  response = { ok: true, data: { pages: [{ id: 'p1', url: 'https://public.example/p1.jpg' }] } }
  const ready = await hydratedExports.resolveSourceChapterPages(registry, request)
  assert.equal(ready.pages.length, 1)
  assert.equal(ready.sourceFailure, undefined)
  assert.equal(JSON.stringify(logEvents).includes('PRIVATE_TOKEN'), false)

  // Exercise the real book hydrator: failure does not write pages or replace the stored book.
  let writes = 0
  response = { ok: false, error: { code: 'network_error' } }
  const comic = { id: 'work', sourceRuntimeId: 'test.source', sourcePath: 'https://public.example/work',
    chapters: [{ id: 'chapter', pages: [] }] }
  const hydrator = new hydratedExports.SourceChapterPageHydrator({
    getComic: () => comic, upsertComic: () => { writes++ },
  }, registry)
  const failed = await hydrator.ensureChapterPages('work', 'test.source', 'chapter')
  assert.equal(failed.hydrated, false)
  assert.equal(failed.sourceFailure.kind, 'network')
  assert.equal(writes, 0)
  console.log('PASS Koma page resolution preserves safe network/HTTP causes, unsupported copy, success, and library retention')
}
sourcePageFailureChain().catch(error => { console.error(error); process.exitCode = 1 })
