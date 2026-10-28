const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const crypto = require('node:crypto')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = path.resolve(__dirname, '../entry/src/main/ets')
function moduleFrom(relative, imports, globals = {}) {
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(base, relative), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true },
  }).outputText
  new Function('exports', 'require', ...Object.keys(globals), js)(exports, name => {
    if (!(name in imports)) throw new Error('Unexpected runtime dependency: ' + name)
    return imports[name]
  }, ...Object.values(globals))
  return exports
}
function deferred() { let resolve; const promise = new Promise(r => { resolve = r }); return { promise, resolve } }

test('an in-flight source save or deletion retains its original identity after leaving the editor', async () => {
  const sourceText = fs.readFileSync(path.join(base, 'components/KomaTranslationSourcesContent.ets'), 'utf8')
    .replace('export struct KomaTranslationSourcesContent', 'export class KomaTranslationSourcesContent')
  const ast = ts.createSourceFile('sources.ts', sourceText, ts.ScriptTarget.Latest, true)
  const owner = ast.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'KomaTranslationSourcesContent')
  const methods = ['saveSource', 'deleteSource', 'editorCurrent']
  const executable = ts.transpileModule(`class Editor { ${methods.map(name =>
    owner.members.find(node => node.name?.text === name).getText(ast)).join('\n')} }; exports.Editor = Editor`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const profile = id => ({ profile: { sourceProfileId: id, displayName: id, sourceRevision: 1 } })
  for (const action of ['saveSource', 'deleteSource']) {
    const gate = deferred(), output = {}, cleared = []; let saved, closed = false
    new Function('exports', 'KomaTranslationSettings', 'ComicTranslationCodexUsageService', executable)(output,
      { load: () => gate.promise, save: async (_context, next) => { saved = structuredClone(next) } },
      { clearCachedSource: async (_context, id) => { cleared.push(id) } })
    const editor = new output.Editor()
    editor.active = true; editor.editorShown = true; editor.editorLifetime = 1; editor.busy = false
    editor.editing = { ...profile('original'), copy: () => profile('original') }
    editor.context = () => ({}); editor.load = async () => {}; editor.toast = () => assert.fail('unexpected error')
    editor.closeEditor = () => { closed = true }
    const pending = editor[action]()
    editor.editing = profile('next-editor'); editor.editorLifetime = 2
    gate.resolve({ llmSources: [profile('original'), profile('next-editor')] })
    await pending
    assert.equal(closed, false, 'a completed old operation must not close a different editor')
    assert.equal(saved.llmSources.find(item => item.profile.sourceProfileId === 'next-editor').profile.sourceRevision, 1)
    assert.equal(saved.llmSources.some(item => item.profile.sourceProfileId === 'original'), action === 'saveSource')
    assert.deepEqual(cleared, action === 'deleteSource' ? ['original'] : [])
  }
})

test('model verification reads real files on a worker and still rejects missing, truncated and corrupt assets', async () => {
  const { Worker } = require('node:worker_threads')
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'koma-model-verify-'))
  const filename = path.join(directory, 'model.bin')
  const bytes = crypto.randomBytes(600013) // Multiple chunks, including a non-aligned final chunk.
  fs.writeFileSync(filename, bytes)
  const digest = crypto.createHash('sha256').update(bytes).digest('hex')
  const compiled = ts.transpileModule(fs.readFileSync(path.join(base, 'model/ReaderModelAssetValidation.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const imageCompiled = ts.transpileModule(fs.readFileSync(path.join(base, 'model/ReaderImageFileIdentity.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const runOnWorker = (fn, ...args) => new Promise((resolve, reject) => {
    const worker = new Worker(`
      const { parentPort, workerData, threadId } = require('node:worker_threads')
      const fs = require('node:fs'), crypto = require('node:crypto'), output = {}
      const io = { OpenMode: { READ_ONLY: 0 }, openSync: p => ({ fd: fs.openSync(p, 'r') }),
        statSync: fd => fs.fstatSync(fd), closeSync: file => fs.closeSync(file.fd),
        readSync: (fd, bytes, options) => fs.readSync(fd, new Uint8Array(bytes), 0, options.length, null) }
      const nativeCrypto = { createMd() { const md = crypto.createHash('sha256'); return {
        updateSync({ data }) { md.update(data) }, digestSync() { return { data: new Uint8Array(md.digest()) } } } } }
      new Function('exports', 'require', workerData.compiled)(output, name =>
        name === '@kit.CoreFileKit' ? { fileIo: io } : name === '@kit.CryptoArchitectureKit'
          ? { cryptoFramework: nativeCrypto } : {})
      parentPort.postMessage({ threadId, valid: output[workerData.method](...workerData.args) })
    `, { eval: true, workerData: { compiled: fn.name === 'readerImageFileSha256Worker' ? imageCompiled : compiled, method: fn.name, args } })
    worker.once('error', reject)
    worker.once('message', result => { assert.notEqual(result.threadId, 0); resolve(result.valid) })
  })
  const validation = moduleFrom('model/ReaderModelAssetValidation.ets', {
    '@kit.ArkTS': { taskpool: { execute: runOnWorker } },
    '@kit.CoreFileKit': { fileIo: new Proxy({}, { get() { throw new Error('UI-thread model I/O') } }) },
    '@kit.CryptoArchitectureKit': { cryptoFramework: new Proxy({}, { get() { throw new Error('UI-thread model hashing') } }) },
  })
  try {
    assert.equal(await validation.validateReaderModelAsset(filename, bytes.length, digest), true)
    assert.equal(await validation.validateReaderModelAsset(filename, bytes.length - 1, digest), false)
    assert.equal(await validation.validateReaderModelAsset(filename, bytes.length, '0'.repeat(64)), false)
    assert.equal(await validation.validateReaderModelAsset(filename + '.missing', bytes.length, digest), false)
    const originalIdentity = moduleFrom('model/ReaderImageFileIdentity.ets', {
      '@kit.ArkTS': { taskpool: { execute: runOnWorker } },
      '@kit.CoreFileKit': { fileIo: new Proxy({}, { get() { throw new Error('UI-thread original-file read') } }) },
      '@kit.CryptoArchitectureKit': {},
    })
    assert.equal(await originalIdentity.readerImageFileSha256(filename), digest)
    await assert.rejects(originalIdentity.readerImageFileSha256(filename + '.missing'), /ENOENT/)
    const pair = path.join(directory, 'reader-super-resolution-models/fixture')
    fs.mkdirSync(pair, { recursive: true })
    fs.writeFileSync(path.join(pair, 'param'), bytes)
    fs.writeFileSync(path.join(pair, 'model'), bytes)
    const definition = { id: 'fixture', directoryName: 'fixture', paramFileName: 'param', modelFileName: 'model',
      paramBytes: bytes.length, modelBytes: bytes.length, paramSha256: digest, modelSha256: digest,
      acceleratedModelFileName: '', acceleratedModelBytes: 0, installStrategy: 'direct', downloadBytes: () => bytes.length * 2 }
    const sr = moduleFrom('model/ReaderSuperResolutionModelService.ets', {
      '@kit.ArkTS': {}, '@kit.BasicServicesKit': {}, '@kit.CoreFileKit': {},
      '../diagnostics/DiagnosticLogger': {}, './ReaderModelAssetDownload': {},
      './ReaderModelAssetValidation': validation, '../state/ReaderModeState': {},
      './ReaderSuperResolutionModelRegistry': { ReaderSuperResolutionModelRegistry: { find: () => definition },
        ReaderSuperResolutionInstallStrategy: { REAL_ESRGAN_X2PLUS_COMPAT: 'compat' } },
    }).ReaderSuperResolutionModelService
    const context = { filesDir: directory }
    assert.equal(await sr.isInstalled(context, 'fixture'), true)
    assert.equal(await sr.remainingDownloadBytes(context, 'fixture'), 0)
    assert.ok(await sr.pathsIfReady(context, 'fixture'))
    fs.writeFileSync(path.join(pair, 'model'), Buffer.alloc(bytes.length))
    assert.equal(await sr.isInstalled(context, 'fixture'), false)
    assert.equal(await sr.pathsIfReady(context, 'fixture'), null)
    assert.equal(await sr.remainingDownloadBytes(context, 'fixture'), bytes.length * 2)
  } finally { fs.rmSync(directory, { recursive: true, force: true }) }
})

test('late model verification cannot resurrect paths after removal and readiness remains cached', async () => {
  let calls = 0
  const release = deferred()
  const model = moduleFrom('readerTranslation/services/ComicTranslationModelService.ets', {
    '@kit.CoreFileKit': { fileIo: { accessSync: () => false } },
    '../../diagnostics/DiagnosticLogger': { DiagnosticLogger: {} },
    '../../model/ReaderModelAssetDownload': {},
    '../../model/ReaderModelAssetValidation': { async validateReaderModelAsset() { calls++; await release.promise; return true } },
  }).ComicTranslationModelService
  const context = { filesDir: '/owned/models' }
  const pending = model.pathsIfReady(context)
  assert.equal(calls, 1)
  model.remove(context)
  release.resolve()
  assert.equal(await pending, null)
  const after = calls
  assert.equal(await model.isInstalled(context), false)
  assert.equal(calls, after, 'Removal must stay authoritative after the old worker finishes')
  const other = { filesDir: '/owned/other' }
  assert.ok(await model.pathsIfReady(other))
  const warmed = calls
  assert.ok(await model.pathsIfReady(other))
  assert.equal(calls, warmed, 'A warm readiness lookup must not hash the model again')
})

test('translation configuration serializes reads with atomic secure writes and recovers a rejected save', async () => {
  const assets = new Map(); let fail = false, nonce = 0
  const reached = deferred(), release = deferred()
  const state = { revision: 0 }
  const tags = Object.fromEntries(['ALIAS', 'SECRET', 'RETURN_TYPE', 'RETURN_LIMIT', 'ACCESSIBILITY', 'CONFLICT_RESOLUTION'].map(k => [k, k]))
  const profile = moduleFrom('readerTranslation/model/LlmSourceProfile.ets', { '@kit.ArkTS': {} })
  const contract = moduleFrom('readerTranslation/services/LlmSourceProfileContract.ets', { '../model/LlmSourceProfile': profile })
  const codec = moduleFrom('readerTranslation/services/LlmSourceProfileCodec.ets', {
    '../model/LlmSourceProfile': profile, './LlmSourceProfileContract': contract,
  })
  const oauth = moduleFrom('readerTranslation/model/CodexOAuth.ets', {})
  const tokenCodec = moduleFrom('readerTranslation/services/CodexOAuthTokenCodec.ets', { '../model/CodexOAuth': oauth })
  const source = moduleFrom('readerTranslation/KomaTranslationLlmSource.ets', {
    './model/LlmSourceProfile': profile, './services/LlmSourceProfileCodec': codec,
    './services/CodexOAuthTokenCodec': tokenCodec,
  })
  const settings = moduleFrom('readerTranslation/KomaTranslationSettings.ets', {
    './KomaTranslationLlmSource': source, './model/LlmSourceProfile': profile,
    './services/CodexOAuthTokenCodec': tokenCodec, './services/LlmSourceProfileContract': contract,
    '@kit.AssetStoreKit': { asset: { Tag: tags, ReturnType: { ALL: 1 }, Accessibility: { DEVICE_FIRST_UNLOCKED: 1 }, ConflictResolution: { OVERWRITE: 1 },
      async query(attrs) { const payload = assets.get(Buffer.from(attrs.get(tags.ALIAS)).toString('utf8')); return payload ? [new Map([[tags.SECRET, payload]])] : [] },
      async add(attrs) {
        reached.resolve(); await release.promise
        if (fail) throw new Error('native write rejected')
        assert.ok(attrs.get(tags.SECRET).byteLength <= 1024, 'Native SECRET limit from Huawei asset-js-add')
        assets.set(Buffer.from(attrs.get(tags.ALIAS)).toString('utf8'), attrs.get(tags.SECRET).slice())
      },
      async remove(attrs) { assets.delete(Buffer.from(attrs.get(tags.ALIAS)).toString('utf8')) },
    } },
    '@kit.CryptoArchitectureKit': { cryptoFramework: {
      createMd() { const digest = crypto.createHash('sha256'); return { updateSync({data}) { digest.update(data) }, digestSync() { return { data: new Uint8Array(digest.digest()) } } } },
      createRandom() { return { generateRandomSync(length) { return { data: new Uint8Array(length).fill(++nonce) } } } },
    } },
    '@kit.ArkUI': { AppStorageV2: { connect() { return state } } },
    '@kit.ArkTS': { buffer: { from(value, encoding) {
      const buf = Buffer.from(value, encoding)
      return { buffer: Uint8Array.from(buf).buffer, toString: codec => buf.toString(codec) }
    } } },
  }, { ObservedV2: value => value, Trace: () => {} })
  const Store = settings.KomaTranslationSettings, Snapshot = settings.KomaTranslationSettingsSnapshot
  const before = await Store.load({})
  assert.equal(before.configured(), false)
  assert.equal(before.targetLanguage, 'zh-CN')
  const next = new Snapshot(); next.targetLanguage = 'en'
  const write = Store.save({}, next)
  await reached.promise
  let completedBeforeCommit = false
  const during = Store.load({}).then(value => { completedBeforeCommit = true; return value })
  await Promise.resolve()
  assert.equal(completedBeforeCommit, false, 'No read may overtake the pending native write')
  release.resolve(); await write
  const committed = await during
  assert.equal(committed.targetLanguage, 'en')
  assert.ok(committed.revision > 0)
  Store.assertRevision(committed.revision)
  assert.throws(() => Store.assertRevision(committed.revision - 1), /configuration_changed/)
  fail = true
  const rejected = committed.copy(); rejected.targetLanguage = 'ja'
  await assert.rejects(Store.save({}, rejected), /configuration_write_failed/)
  assert.equal((await Store.load({})).targetLanguage, 'en')
  fail = false
  const restored = committed.copy(); restored.targetLanguage = 'zh-CN'
  await Store.save({}, restored)
  assert.equal((await Store.load({})).targetLanguage, 'zh-CN')
  // A real platform limit, not the old single-record mock, defines the storage boundary.
  const long = restored.copy(); long.apiKey = 'k'.repeat(4096)
  await Store.save({}, long)
  assert.equal((await Store.load({})).apiKey, long.apiKey)
  const rootKey = 'koma.reader.translation.configuration.v1'
  const current = JSON.parse(Buffer.from(assets.get(rootKey)).toString('utf8'))
  assert.equal(assets.size, current.chunks + 1, 'Superseded encrypted chunks are retired after commit')
  assets.delete(rootKey + '.chunk.' + current.id + '.0')
  await assert.rejects(Store.load({}), /configuration_invalid/, 'An incomplete configuration must never publish defaults')
  // The real legacy inline schema must migrate the selected API without losing the independent Torii credential.
  assets.clear()
  assets.set(rootKey, new Uint8Array(Buffer.from(JSON.stringify({ apiBaseUrl: 'https://provider.example/v1',
    apiKey: 'legacy-api', apiModel: 'legacy-model', toriiApiKey: 'existing-torii', revision: 1 }))))
  const migrated = await Store.load({})
  assert.equal(migrated.textSource().apiKey, 'legacy-api')
  assert.equal(migrated.toriiApiKey, 'existing-torii')
  assert.equal(migrated.apiModel, 'legacy-model')
  await Store.save({}, migrated)
  const loaded = await Store.load({})
  assert.equal(loaded.textConfigured(), true)
  loaded.llmSources = []
  await Store.save({}, loaded)
  assert.equal((await Store.load({})).textConfigured(), false, 'Deleting the bound source cannot fall back to legacy API fields')
  const codex = new source.KomaTranslationLlmSource()
  codex.profile.sourceProfileId = 'fixture-codex'
  codex.profile.displayName = 'Fixture Codex'
  codex.profile.sourceType = profile.LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL
  codex.profile.sourceRevision = 1
  codex.profile.capabilities.responses = true
  codex.profile.capabilities.imageInput = true
  const configuration = await Store.load({})
  configuration.llmSources = [codex]
  configuration.sourceProfileId = codex.profile.sourceProfileId
  await Store.save({}, configuration)
  const tokens = new oauth.CodexOAuthTokenSet()
  tokens.accessToken = 'fixture-access'
  tokens.refreshToken = 'fixture-refresh'
  tokens.accountId = 'fixture-account'
  await Store.updateSourceTokens({}, codex.profile.sourceProfileId, tokens)
  const staleForm = await Store.load({})
  const loginRevision = staleForm.revision
  const rotated = tokens.copy(); rotated.accessToken = 'fixture-access-2'; rotated.refreshToken = 'fixture-refresh-2'
  await Store.updateSourceTokens({}, codex.profile.sourceProfileId, rotated, tokens.refreshToken)
  assert.equal((await Store.load({})).revision, loginRevision, 'Automatic refresh must not cancel its own Reader request')
  await Store.save({}, staleForm)
  assert.equal(tokenCodec.CodexOAuthTokenCodec.parse((await Store.load({})).textSource().codexTokens).refreshToken,
    rotated.refreshToken, 'A stale settings form must not roll back a rotated credential')
  const oldConsumerForm = staleForm.copy(); oldConsumerForm.llmSources = []
  await Store.saveConfiguration({}, oldConsumerForm)
  assert.equal((await Store.load({})).llmSources.length, 1,
    'A consumer page retained before source creation must not erase the source registry')
  assert.equal(tokenCodec.CodexOAuthTokenCodec.parse((await Store.load({})).textSource().codexTokens).refreshToken,
    rotated.refreshToken)
  const removed = await Store.load({}); removed.llmSources = []
  await Store.save({}, removed)
  await assert.rejects(Store.updateSourceTokens({}, codex.profile.sourceProfileId, rotated, tokens.refreshToken), /no longer exists/)
  await Store.saveConfiguration({}, staleForm)
  assert.equal((await Store.load({})).llmSources.length, 0,
    'A retained consumer page must not resurrect a source removed in the manager')
  assert.equal((await Store.load({})).toriiApiKey, 'existing-torii')

})

test('model no-progress failure destroys transport and removes only its incomplete file', async () => {
  const timers = new Map(); let timerId = 0, destroyed = 0; const removed = [], writes = []
  let onData, onRequest
  const started = deferred()
  const download = moduleFrom('model/ReaderModelAssetDownload.ets', {
    '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET' }, createHttp() { return {
      on(name, fn) { if (name === 'dataReceive') onData = fn },
      requestInStream() { started.resolve(); return new Promise(resolve => { onRequest = resolve }) },
      destroy() { destroyed++ },
    } } } },
    '@kit.CoreFileKit': { fileIo: { OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 }, openSync() { return { fd: 10 } },
      writeSync(fd, chunk, options) { writes.push([fd, chunk.byteLength, options.offset]); return chunk.byteLength },
      closeSync() {}, unlinkSync(file) { removed.push(file) },
    } },
  }, { setTimeout(fn) { const id = ++timerId; timers.set(id, fn); return id }, clearTimeout(id) { timers.delete(id) } })
  const task = download.ReaderModelAssetDownload.download('https://models.example/asset', '/owned/asset.part', () => {}, 15000, 60000, '*/*', 1, 2700000)
  await started.promise
  onData(new Uint8Array(8).buffer)
  assert.deepEqual(writes, [[10, 8, 0]])
  assert.equal(timers.size, 1)
  const expire = [...timers.values()][0]; expire()
  await assert.rejects(task, /download_stalled/)
  assert.deepEqual(removed, ['/owned/asset.part'])
  assert.ok(destroyed >= 1)
  assert.equal(timers.size, 0)
  onRequest(200)
})

test('changed configuration prevents text, Torii, sidecar and login transports from starting requests', async () => {
  let revision = 8, requests = 0
  const guard = { KomaTranslationSettings: { assertRevision(expected) {
    if (expected !== revision) throw new Error('reader_translation_configuration_changed')
  } } }
  const http = { AxiosHttpClient: {
    requestText() { requests++; return Promise.resolve({ statusCode: 200, body: '{}' }) },
    requestBinaryWithBody() { requests++; return Promise.resolve({ statusCode: 200, bytes: null }) },
  } }
  const cases = [
    ['ComicResponsesPageAnalyzer', 'DefaultComicResponsesHttpTransport', 'requestText'],
    ['ToriiWholePageRenderBackend', 'DefaultToriiWholePageTransport', 'post'],
    ['MangaTranslatorUiSidecarBackend', 'DefaultMangaTranslatorUiSidecarTransport', 'post'],
    ['MangaTranslatorUiSidecarSessionService', 'DefaultMangaTranslatorUiSidecarSessionTransport', 'requestText'],
  ]
  let accepted
  for (const [file, exported, method] of cases) {
    const output = ts.transpileModule(fs.readFileSync(path.join(base, 'readerTranslation/services', file + '.ets'), 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    }).outputText
    const mod = {}
    new Function('exports', 'require', output)(mod, name => name.includes('KomaTranslationSettings') ? guard : name.includes('AxiosHttpClient') ? http : {})
    const transport = new mod[exported](7)
    const invoke = () => method === 'post' ? transport.post({}) : transport.requestText('https://provider.example', 'POST', {}, '{}', 1000, 1000)
    await assert.rejects(Promise.resolve().then(invoke), /configuration_changed/)
    assert.equal(requests, 0)
    if (method === 'requestText') accepted = invoke
  }
  revision = 7
  await accepted()
  assert.equal(requests, 1)
})

// Regression: the original fallback-only policy never admitted preloaded
// enhancement work. Run the production host policy against the real Kit policy.
test('enhancement without configured translation admits future-page processing and keeps disabled reading idle', () => {
  const raw = process.env.KOMA_POLICY_BEFORE === '1'
    ? require('node:child_process').execFileSync('git', ['show', '85eac652:entry/src/main/ets/readerLab/KomaReaderLabPage.ets'], {cwd:path.resolve(__dirname,'..'),encoding:'utf8'})
    : fs.readFileSync(path.join(base,'readerLab/KomaReaderLabPage.ets'),'utf8')
  const tree=ts.createSourceFile('host',raw.replace('export struct KomaReaderLabPage','export class KomaReaderLabPage'),ts.ScriptTarget.Latest,true)
  const owner=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='KomaReaderLabPage')
  const method=owner.members.find(n=>n.name?.text==='translationPolicy').getText(tree)
  class Preference { constructor(variant='default',identity=''){this.variant=variant;this.identity=identity} }
  const policyExports={}
  new Function('exports','require',ts.transpileModule(fs.readFileSync(path.resolve(__dirname,'../../reader-kit/reader-ui/src/main/ets/ReaderVariantPolicy.ets'),'utf8'),
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(policyExports,()=>({ReaderVariantPreference:Preference}))
  const exports={}
  new Function('exports','ReaderVariantPolicy',ts.transpileModule(`export class Host {${method}}`,
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(exports,policyExports.ReaderVariantPolicy)
  const host=new exports.Host()
  Object.assign(host,{translationSettings:{configured:()=>false},enhancementPreference:()=>new Preference('enhanced','model-v1')})
  const enabled=host.translationPolicy()
  assert.equal(enabled.supportsProcessing(),true)
  const future=enabled.processingPreference({sourceIndex:4,copy(){return this}},false)
  assert.deepEqual([future.variant,future.identity],['enhanced','model-v1'])
  host.enhancementPreference=()=>new Preference()
  assert.equal(host.translationPolicy().supportsProcessing(),false)
})
