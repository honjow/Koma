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

const compile = source => ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
} }).outputText
// Execute the actual adapter handoff; source-shape/constructor-arity checks do
// not establish this contract and became stale with the adopted provider chain.
const adapterExports = {}
new Function('exports','require',compile(fs.readFileSync(path.join(root,'readerLab/KomaReaderLabAdapter.ets'),'utf8')))
  (adapterExports,name=>name==='./KomaReaderFailure'?{KomaReaderFailure}:{})
const routed = adapterExports.KomaReaderLabAdapter.prototype.classify.call({},new Error('missing_chapter_page'))
assert.equal(routed.code,'pageUnavailable')
assert.equal(routed.title,'Koma page failed')
async function sourcePageFailureChain() {
  let response, settings = {}, requestGate = null, requested = 0
  const settingsIdentity = {}
  const crypto = require('node:crypto')
  new Function('exports', 'require', compile(fs.readFileSync(path.join(root,
    'sourceRuntime/SourceSettingsIdentity.ets'), 'utf8')))(settingsIdentity, name => name === '@kit.ArkTS'
      ? { util: { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value) } } } } : { cryptoFramework: { createMd() { const hash = crypto.createHash('sha256'); return {
        updateSync({data}) { hash.update(data) }, digestSync() { return {data: new Uint8Array(hash.digest())} },
      } } } })
  const models = {}
  new Function('exports','require',compile(fs.readFileSync(path.join(root,'model/ComicModels.ets'),'utf8')))(models,()=>({}))
  const hostFeatures = {}, requestPolicy = {}
  new Function('exports',compile(fs.readFileSync(path.join(root,'sourceRuntime/SourceHostFeatures.ets'),'utf8')))(hostFeatures)
  new Function('exports','require',compile(fs.readFileSync(path.join(root,'sourceRuntime/SourceRequestPolicy.ets'),'utf8')))
    (requestPolicy,()=>({url:{URL}}))
  const hydratedExports = {}
  new Function('exports', 'require', compile(fs.readFileSync(
    path.join(root, 'model/SourceChapterPageHydrator.ets'), 'utf8')))(hydratedExports, name => {
    if (name === './SourceRuntimeError') return errorExports
    if (name === '@kit.ArkTS') return { taskpool: { execute: async () => { requested++; if (requestGate) await requestGate; return JSON.stringify(response) } } }
    if (name === '../sourceRuntime/SourceRuntimeRunner') return { diagnoseSourceOperation: (_request, execute) => execute() }
    if (name === '../sourceRuntime/SourceWebSessionStore') return { sourceHttpIdentityJson: () => '{}' }
    if (name === '../sourceRuntime/SourceSettingsStore') return { appSourceSettingsStore: { loadForSource: () => JSON.parse(JSON.stringify(settings)) } }
    if (name === '../sourceRuntime/SourceSettingsIdentity') return settingsIdentity
    if (name === '../sourceRuntime/SourceHostFeatures') return hostFeatures
    if (name === '../sourceRuntime/SourceRequestPolicy') return requestPolicy
    if (name === './ComicModels') return models
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

  // 237 NamiComi counterexample: an existing /source/ plan bypassed get_pages
  // after dataSaver was saved. Only a changed snapshot should renew that plan.
  let book = { id: 'work', createdAt: 1, sourceRuntimeId: 'test.source', sourcePath: 'https://public.example/work',
    chapters: [{ id: 'chapter', createdAt: 1, sourcePath: 'chapter', pages: [{id:'p1',uri:'https://public.example/source/1.png'}],pageCount:1 }] }
  const bookHydrator = new hydratedExports.SourceChapterPageHydrator({ getComic: () => book,
    upsertComic: next => { writes++; book=next } }, registry)
  let calls = requested
  assert.equal((await bookHydrator.ensureChapterPages('work','test.source','chapter')).hydrated,true)
  assert.equal(requested,calls,'Empty legacy settings must keep existing pages cache-first')
  settings={'dataSaver_zh-hans':true,thumbnailQuality_zh:'512'}
  response={ok:true,data:{pages:[{id:'p1',url:'https://public.example/low/1.jpg'}]}}
  assert.equal((await bookHydrator.ensureChapterPages('work','test.source','chapter')).hydrated,true)
  assert.equal(requested,++calls);assert.equal(book.chapters[0].pages[0].uri,'https://public.example/low/1.jpg')
  assert.equal(book.chapters[0].sourceSettingsFingerprint,settingsIdentity.sourceSettingsFingerprint(settings))
  assert.equal(book.chapters[0].id,'chapter');assert.equal(book.chapters[0].createdAt,1)
  settings={thumbnailQuality_zh:'512','dataSaver_zh-hans':true}
  await bookHydrator.ensureChapterPages('work','test.source','chapter')
  assert.equal(requested,calls,'Equivalent key ordering must reuse the same prepared plan')
  settings={'dataSaver_zh-hans':false}
  response={ok:false,error:{code:'network_error'}}
  const kept=JSON.stringify(book),oldWrites=writes
  assert.equal((await bookHydrator.ensureChapterPages('work','test.source','chapter')).hydrated,false)
  assert.equal(JSON.stringify(book),kept);assert.equal(writes,oldWrites)
  settings={}
  response={ok:true,data:{pages:[{id:'p1',url:'https://public.example/source/1.png'}]}}
  await bookHydrator.ensureChapterPages('work','test.source','chapter')
  assert.equal(book.chapters[0].sourceSettingsFingerprint,'')
  assert.equal(book.chapters[0].pages[0].uri,'https://public.example/source/1.png')
  let release
  requestGate=new Promise(resolve=>{release=resolve})
  const pending=bookHydrator.ensureChapterPages('work','test.source','chapter',true)
  await Promise.resolve();settings={'dataSaver_zh-hans':true};release()
  assert.equal((await pending).hydrated,false)
  assert.equal(book.chapters[0].sourceSettingsFingerprint,'','A late response cannot claim newly changed settings')
  console.log('PASS Changed source settings renew only their chapter plan; warm plans, failure and old-response retention remain correct')
  console.log('PASS Koma page resolution preserves safe network/HTTP causes, unsupported copy, success, and library retention')
}
sourcePageFailureChain().catch(error => { console.error(error); process.exitCode = 1 })
