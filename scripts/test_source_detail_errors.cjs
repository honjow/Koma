// Exercise production detail/chapters error paths without network, device, or private response text.
const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '..')
const read = name => fs.readFileSync(path.join(root, 'entry/src/main/ets', name + '.ets'), 'utf8')
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
}).outputText
const strings = { get: key => key, format: (_key, text, status) => `${text} HTTP ${status}` }
const errors = { exports: {} }
new Function('module', 'exports', 'require', compile(read('model/SourceRuntimeError')))(errors, errors.exports,
  () => ({ AppStrings: strings }))
const { SourceRuntimeError } = errors.exports
const gateModule = { exports: {} }
new Function('exports', compile(read('sourceRuntime/SourceWebChallengeGate')))(gateModule.exports)
const { SourceWebChallengeGate } = gateModule.exports
const pageSource = read('pages/MangaDetailPage').replace(/\bstruct (\w+)/g, 'class $1')
const file = ts.createSourceFile('page.ts', pageSource, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const owner = file.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'MangaDetailPage')
const method = name => {
  const member = owner.members.find(node => node.name?.text === name)
  assert.ok(member, name)
  return member.getText(file)
}
function fixture() {
  const logs = [], writes = [], applied = [], reads = [], cancelledSessions = []
  const entry = { sourceId: 'source.test', enabled: true, manifestName: 'Test', wasmBytes: new Uint8Array(1) }
  const state = { response: { ok: true, data: { manga: { title: 'Real detail' } } },
    chapterError: undefined, library: undefined, cache: undefined, chapters: [], task: undefined }
  const exports = {}
  const code = compile(`export class Page {
    ${['runSourceMangaOperation', 'sourceMangaResponseItem', 'sourceOperationFailureText', 'isDetailPending', 'canReloadSourceDetail', 'canPullRefreshDetail', 'refreshMangaDetail', 'performDetailRefresh', 'loadSourceMangaDetail', 'clearDetailWebChallenge', 'closeDetailWebChallenge', 'completeDetailWebChallenge', 'finishDetailWebChallengeDismiss', 'publishDetailWebChallenge'].map(method).join('\n')}
  }`)
  new Function('exports', 'SourceRuntimeError', 'DiagnosticLogger', 's', 'sourceHttpIdentityJson',
    'diagnoseSourceOperation', 'taskpool', 'executeMangaDetailSourceOperation', 'parseMangaDetailFromSourceItem',
    'parseMangaChapterFromSourceItem', 'sourceRuntimeEntryEnabled', 'sourceMangaDetailSnapshotCache',
    'resolveSourceChapterList', 'SourceDetailContentState', 'mangaChapterItemFromComicChapter', 'SourceWebChallengeGate', 'appSourceWebSessionStore', code)(
    exports, SourceRuntimeError, { warn: (...args) => logs.push(args.join(' ')) }, key => key, () => '{}',
    (_request, execute) => execute(), { execute: async () => state.task ? state.task() : JSON.stringify(state.response) }, () => {},
    (_source, item) => item, item => item, item => item.enabled,
    { read: () => { reads.push(true); return state.cache }, write: (...args) => writes.push(args) },
    async () => { if (state.chapterError) throw state.chapterError; return { resolved: true, chapters: state.chapters } },
    { UNRESOLVED: 'unresolved', LOADING: 'loading', READY: 'ready', ERROR: 'error' }, chapter => ({ ...chapter }), SourceWebChallengeGate, { cancel: (...args) => cancelledSessions.push(args) })
  const page = new exports.Page()
  Object.assign(page, {
    chrome: { visible: true }, detailWebChallenge: null, detailWebChallengeShown: false, detailWebChallengeId: 0,
    detailWebChallengeClosing: false, detailWebChallengeParams: { url: '', title: '' },
    detailWebChallengeGate: new SourceWebChallengeGate(), sourceDetailRegistryEntry: entry,
    handleDetailWebChallenge: () => {},
    sourceRegistry: { lookup: () => ({ ok: true, entry }) },
    buildSourceDetailRequestJson: () => '{}', copyWasmBytes: () => new Uint8Array(1),
    sourceEmbeddedChapterItems: () => [], sourceMangaRouteUrl: () => undefined,
    beginSourceDetailRequest: () => 1, isCurrentSourceDetailRequest: () => true,
    sourceDetailWithRouteIdentity: detail => detail, refreshSourceLibraryCover: () => {},
    applySourceMangaDetail: (...args) => { applied.push(args); page.manga = args[4]; page.chapters = args[5]; page.sourceDetailContentState = args[7]; page.sourceDetailDataResolved = true; return true },
    sourceComicId: () => 'saved', findSourceRuntimeComic: () => state.library,
    sourceDetailFromInitialRouteManga: () => ({ title: 'Original preview' }),
    loadLocalOrMissingManga: () => { page.chapters = state.library.chapters; page.manga = state.library },
  })
  return { page, state, entry, logs, applied, writes, reads, cancelledSessions }
}
for (const [code, kind] of [['not_implemented','unsupported'], ['not_supported','unsupported'], ['rate_limit','rate_limit']]) {
  for (const field of ['reasonCode', 'error']) test(`provider ${code} in ${field} retains its structured cause`, () => {
    const response = field === 'reasonCode' ? {ok:false,reasonCode:code} :
      {ok:false,error:{code,message:'PRIVATE_TOKEN https://private.invalid/work'}}
    const error = new SourceRuntimeError(response)
    assert.equal(error.diagnostic.kind,kind)
    assert.equal(error.diagnostic[field === 'reasonCode' ? 'reason' : 'code'],code)
    assert.equal(error.userText,'source_failure_'+kind)
    assert.ok(!JSON.stringify(error.diagnostic).includes('PRIVATE_TOKEN'))
    assert.ok(!error.userText.includes('private.invalid'))
  })
}
test('explicit HTTP status still takes precedence over a provider alias', () => {
  const error = new SourceRuntimeError({ok:false,error:{code:'not_implemented',status:403}})
  assert.equal(error.diagnostic.kind,'access');assert.equal(error.diagnostic.code,'not_implemented')
  assert.equal(error.diagnostic.status,403)
})
test('unknown provider text is still redacted rather than reclassified by message guesses', () => {
  const error = new SourceRuntimeError({ok:false,error:{code:'PRIVATE_TOKEN',message:'not_supported rate_limit'}})
  assert.equal(error.diagnostic.code,'unknown');assert.equal(error.diagnostic.kind,'runtime')
  assert.equal(error.userText,'source_failure_runtime')
})
test('get_manga keeps structured access status and never exposes the provider message', async () => {
  const f = fixture()
  f.state.response = { ok: false, error: { code: 'permission_denied', status: 403, message: 'PRIVATE_TOKEN' } }
  await assert.rejects(f.page.runSourceMangaOperation(f.entry, 'get_manga', 'work'), error => {
    assert.ok(error instanceof SourceRuntimeError)
    assert.equal(error.diagnostic.status, 403)
    assert.equal(error.diagnostic.kind, 'access')
    assert.ok(!error.userText.includes('PRIVATE_TOKEN'))
    return true
  })
})
test('successful envelope without manga is an invalid response, not an access failure', async () => {
  const f = fixture(); f.state.response = { ok: true, data: {} }
  await assert.rejects(f.page.runSourceMangaOperation(f.entry, 'get_manga', 'work'), error =>
    error instanceof SourceRuntimeError && error.diagnostic.kind === 'parse' && error.diagnostic.status === 0)
})
test('detail failure retains stored chapters while showing the structured cause', async () => {
  const f = fixture(); const chapters = [{ title: 'Saved chapter' }]
  f.state.library = { title: 'Saved detail', chapters }
  f.state.response = { ok: false, error: { code: 'rate_limited', status: 429, message: 'PRIVATE_TOKEN' } }
  await f.page.loadSourceMangaDetail('source.test', 'work')
  assert.equal(f.page.chapters, chapters)
  assert.match(f.page.feedbackText, /manga_detail_load_source_failed.*source_failure_rate_limit.*429/)
  assert.match(f.logs.join('\n'), /operation=get_manga.*error=rate_limited.*http=429/)
  assert.ok(!JSON.stringify(f.logs).includes('PRIVATE_TOKEN'))
  assert.equal(f.writes.length, 0)
})
test('chapter failure keeps real detail and saved rows without caching the fallback as resolved', async () => {
  const f = fixture(); f.state.library = { chapters: [{ title: 'Saved chapter' }] }
  f.state.chapterError = new SourceRuntimeError({ ok: false, error: { code: 'server_error', status: 503 } })
  await f.page.loadSourceMangaDetail('source.test', 'work')
  const final = f.applied.at(-1)
  assert.equal(final[4].title, 'Real detail')
  assert.deepEqual(final[5], [{ title: 'Saved chapter' }])
  assert.match(final[6], /manga_detail_load_source_chapters_failed.*source_failure_server.*503/)
  assert.equal(final[7], 'ready')
  assert.equal(f.writes.length, 1)
  assert.equal(f.writes[0][3].chaptersResolved, false)
})
test('directory resolver preserves legacy reason message alongside HTTP diagnostics', async () => {
  const exports = {}
  const response = { ok: false, reasonCode: 'http_error', error: { code: 'permission_denied', status: 403, message: 'PRIVATE_TOKEN' } }
  new Function('exports', 'require', compile(read('model/SourceChapterListResolver')))(exports, name => {
    if (name === './SourceRuntimeError') return { SourceRuntimeError }
    if (name === '@kit.ArkTS') return { taskpool: { execute: async () => JSON.stringify(response) } }
    if (name === '../sourceRuntime/SourceRuntimeRunner') return { diagnoseSourceOperation: (_request, execute) => execute() }
    if (name === '../sourceRuntime/SourceWebSessionStore') return { sourceHttpIdentityJson: () => '{}' }
    if (name === '../sourceRuntime/SourceSettingsStore') return { appSourceSettingsStore: {
      revisionForSource: () => 'same', loadForSource: () => ({}) } }
    return {}
  })
  await assert.rejects(exports.resolveSourceChapterList({ sourceId: 'source.test', wasmBytes: new Uint8Array(1) }, 'work'), error => {
    assert.ok(error instanceof SourceRuntimeError)
    assert.equal(error.message, 'http_error')
    assert.equal(error.diagnostic.code, 'permission_denied')
    assert.equal(error.diagnostic.status, 403)
    assert.match(error.userText, /source_failure_access.*403/)
    return true
  })
})

test('force reload bypasses a resolved work snapshot and replaces only after a real response', async () => {
  const f = fixture()
  const saved = { title: 'Previously loaded detail' }, chapters = [{ title: 'Previously loaded chapter' }]
  Object.assign(f.page, { manga: saved, chapters, sourceDetailDataResolved: true, sourceDetailContentState: 'ready' })
  f.state.cache = { detail: { title: 'Stale snapshot' }, chapters: [], chaptersResolved: true }
  let complete
  f.state.task = () => new Promise(resolve => { complete = resolve })
  f.state.chapters = [{ title: 'Fresh chapter' }]
  const pending = f.page.loadSourceMangaDetail('source.test', 'work', true)
  assert.equal(f.reads.length, 0)
  assert.equal(f.page.manga, saved)
  assert.equal(f.page.chapters, chapters)
  assert.equal(f.page.sourceDetailContentState, 'ready')
  complete(JSON.stringify({ ok: true, data: { manga: { title: 'Fresh detail' } } }))
  await pending
  assert.equal(f.applied.at(-1)[4].title, 'Fresh detail')
  assert.deepEqual(f.applied.at(-1)[5], [{ title: 'Fresh chapter' }])
  assert.equal(f.writes.at(-1)[3].chaptersResolved, true)
})
test('retry during a pending detail keeps its successful content and ends pending on failure', async () => {
  const f = fixture()
  const saved = { title: 'Loaded while chapters pending' }, chapters = [{ title: 'Saved chapter' }]
  Object.assign(f.page, { manga: saved, chapters, sourceDetailDataResolved: true, sourceDetailContentState: 'loading' })
  f.state.response = { ok: false, error: { code: 'network_error' } }
  await f.page.loadSourceMangaDetail('source.test', 'work', true)
  assert.equal(f.page.manga, saved)
  assert.deepEqual(f.page.chapters, chapters)
  assert.equal(f.page.sourceDetailContentState, 'ready')
  assert.match(f.page.feedbackText, /source_failure_network/)
})
test('force reload honors a successful empty remote directory instead of keeping stale rows', async () => {
  const f = fixture()
  Object.assign(f.page, { manga: { title: 'Old' }, chapters: [{ title: 'Old chapter' }],
    sourceDetailDataResolved: true, sourceDetailContentState: 'ready' })
  await f.page.loadSourceMangaDetail('source.test', 'work', true)
  assert.deepEqual(f.applied.at(-1)[5], [])
})
test('reload command remains callable when no manga has loaded', async () => {
  const exports = {}, calls = []
  const actions = { RELOAD_SOURCE: 'reload_source' }
  new Function('exports', 'MangaDetailTitleAction', compile(`export class Page {
    ${['canReloadSourceDetail', 'refreshMangaDetail', 'performDetailRefresh', 'runTitleAction', 'shouldRenderDetailActions', 'isDetailPending'].map(method).join('\n')}
  }`))(exports, actions)
  const page = new exports.Page()
  page.params = { sourceId: ' source.test ', mangaId: ' work ' }
  page.loadSourceMangaDetail = (...args) => { calls.push(args) }
  assert.equal(page.shouldRenderDetailActions(), false)
  page.runTitleAction(actions.RELOAD_SOURCE)
  assert.deepEqual(calls, [['source.test', 'work', true]])
  page.params = { mangaId: 'work' }
  page.runTitleAction(actions.RELOAD_SOURCE)
  assert.equal(calls.length, 1, 'Local detail cannot invoke source reloading')
})
test('root menu exposes only recovery when regular detail actions are unavailable', () => {
  const src = read('pages/Index').replace(/\bstruct (\w+)/g, 'class $1')
  const f = ts.createSourceFile('index.ts', src, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
  const owner = f.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'Index')
  const member = owner.members.find(node => node.name?.text === 'mangaDetailTitleBarOpts')
  const exports = {}, actions = [], chrome = { pageActionsAvailable: false, sourceReloadAvailable: true,
    requestAction: action => actions.push(action) }
  new Function('exports', 'RouterHelper', 'AppStrings', '$r', 'MangaDetailTitleAction',
    compile(`export class Root { ${member.getText(f)} }`))(
    exports, { ensureMangaDetailRouteChrome: () => chrome }, strings, value => value, { RELOAD_SOURCE: 'reload_source' })
  const page = new exports.Root()
  page.mangaDetailTitle = () => ''
  page.sourceRouteTitleBarOpts = content => content
  const menu = page.mangaDetailTitleBarOpts({}).menu
  assert.equal(menu.value.length, 1)
  assert.equal(menu.value[0].content.label, 'manga_detail_menu_reload_source')
  assert.equal(menu.value[0].content.isEnabled, true)
  menu.value[0].content.action()
  assert.deepEqual(actions, ['reload_source'])
  for (const locale of ['base', 'en_US', 'zh_CN']) {
    const values = JSON.parse(fs.readFileSync(path.join(root, `entry/src/main/resources/${locale}/element/string.json`))).string
    assert.equal(values.filter(item => item.name === 'manga_detail_menu_reload_source').length, 1)
  }
})
test('starting another reload invalidates the preceding request epoch', () => {
  const exports = {}, entry = {}
  new Function('exports', 'appSourceSettingsStore', compile(`export class Page {
    ${['beginSourceDetailRequest', 'isCurrentSourceDetailRequest'].map(method).join('\n')}
  }`))(exports, { revisionForSource: () => 'same' })
  const page = new exports.Page()
  Object.assign(page, { sourceDetailRequestEpoch: 0, params: { sourceId: 's', mangaId: 'm' },
    sourceRegistry: { lookup: () => ({ entry }) } })
  const first = page.beginSourceDetailRequest('s', 'm'); page.sourceDetailRegistryEntry = entry
  assert.equal(page.isCurrentSourceDetailRequest(first, 's', 'm'), true)
  const second = page.beginSourceDetailRequest('s', 'm'); page.sourceDetailRegistryEntry = entry
  assert.equal(page.isCurrentSourceDetailRequest(first, 's', 'm'), false)
  assert.equal(page.isCurrentSourceDetailRequest(second, 's', 'm'), true)
})

test('completed catalog diagnostic counts duplicate identities without merging titles or changing pagination', async () => {
  const exports = {}, logs = [], requests = []
  const first = [{ id: 'private-id-a', title: 'Private title one', chapterNumber: 0 }, { id: 'private-id-b', title: 'Same title', chapterNumber: 99 }]
  const second = [{ id: 'private-id-a', title: 'Different title', chapterNumber: 583 }, { id: 'private-id-c', title: 'Same title' }]
  let responses = [
    { ok: true, data: { items: first, page: { nextCursor: 'page-two', hasMore: true } } },
    { ok: true, data: { items: second, page: { nextCursor: null, hasMore: false } } },
  ]
  new Function('exports', 'require', compile(read('model/SourceChapterListResolver')))(exports, name => {
    if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { info: (...args) => logs.push(args.join(' ')) } }
    if (name === './SourceRuntimeError') return { SourceRuntimeError }
    if (name === '@kit.ArkTS') return { taskpool: { execute: async (_worker, request) => {
      requests.push(JSON.parse(request)); return JSON.stringify(responses.shift())
    } } }
    if (name === '../sourceRuntime/SourceRuntimeRunner') return { diagnoseSourceOperation: (_request, execute) => execute() }
    if (name === '../sourceRuntime/SourceWebSessionStore') return { sourceHttpIdentityJson: () => '{}' }
    if (name === './MangaDetailModels') return { parseMangaChapterFromSourceItem: item => item }
    if (name === '../sourceRuntime/SourceSettingsStore') return { appSourceSettingsStore: {
      revisionForSource: () => 'same', loadForSource: () => ({}) } }
    return {}
  })
  const entry = { sourceId: 'source.test', wasmBytes: new Uint8Array(1) }
  const result = await exports.resolveSourceChapterList(entry, 'private-work', 'https://private.invalid/work')
  assert.equal(result.resolved, true)
  assert.deepEqual(result.chapters, [...first, ...second])
  assert.equal(requests.length, 2)
  assert.equal(requests[1].args.page.cursor, 'page-two')
  assert.deepEqual(logs, [
    'source_chapters catalog_identity total=4 uniqueId=3 duplicateIdGroups=1 duplicateRows=1',
    'source_chapters catalog_order total=4 numbered=3 unknown=1 min=0 max=583 leading=0:0,1:99,2:583,3:?',
  ])
  assert(!logs.join('').includes('private'))
  responses = [{ ok: true, data: { items: first, page: { hasMore: true } } }]
  const incomplete = await exports.resolveSourceChapterList(entry, 'private-work')
  assert.equal(incomplete.resolved, false)
  assert.equal(logs.length, 2, 'Incomplete catalog must not publish completed catalog diagnostics')
})


test('detail challenge validates once and bypasses snapshot while retaining real content on repeated failure', async () => {
  const f = fixture(); f.entry.webSessionOrigins = ['https://site.invalid']
  f.state.response = { ok: false, error: { code: 'challenge_required', status: 403 } }
  f.page.sourceDetailDataResolved = true
  f.page.manga = { title: 'Retained' }; f.page.chapters = [{ id: 'old' }]
  f.page.sourceDetailContentState = 'ready'
  await f.page.loadSourceMangaDetail('source.test', 'work', true)
  const receipt = f.page.detailWebChallenge
  assert.ok(receipt); assert.equal(receipt.scope, 'detail')
  f.page.detailWebChallengeGate.claim(receipt.id, true)
  f.page.detailWebChallengeId = receipt.id; f.page.detailWebChallengeShown = true
  f.page.completeDetailWebChallenge()
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(f.page.detailWebChallenge, null)
  assert.equal(f.page.manga.title, 'Retained')
  assert.deepEqual(f.page.chapters, [{ id: 'old' }])
  assert.equal(f.reads.length, 0)
  assert.equal(f.page.detailWebChallengeClosing, true)
})
test('chapter challenge retries only chapter resolution and preserves the already resolved detail', async () => {
  const f = fixture(); f.entry.webSessionOrigins = ['https://site.invalid']
  f.state.chapterError = new SourceRuntimeError({ ok:false,error:{code:'challenge_required',status:403} })
  f.state.chapters = [{ id: 'new' }]
  await f.page.loadSourceMangaDetail('source.test','work')
  const receipt = f.page.detailWebChallenge
  assert.ok(receipt)
  f.state.chapterError = undefined
  f.state.task = async () => { throw Error('must not reload successful get_manga') }
  f.page.detailWebChallengeGate.claim(receipt.id,true)
  f.page.detailWebChallengeId = receipt.id; f.page.detailWebChallengeShown = true
  f.page.completeDetailWebChallenge()
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(f.page.manga.title,'Real detail')
  assert.deepEqual(f.page.chapters,[{id:'new'}])
  assert.equal(f.page.feedbackText,'')
  assert.equal(f.page.detailWebChallenge,null)
})
test('closing an old sheet never cancels a later session from its disappearance callback', () => {
  const f = fixture()
  f.page.detailWebChallengeId = 1; f.page.detailWebChallengeShown = true
  f.page.detailWebChallengeParams = { sourceSession: { sourceId: 'source.test', sessionId: 'old' } }
  f.page.closeDetailWebChallenge()
  f.page.detailWebChallengeParams = { sourceSession: { sourceId: 'source.test', sessionId: 'new' } }
  let openings = 0; f.page.handleDetailWebChallenge = () => openings++
  f.page.finishDetailWebChallengeDismiss()
  assert.deepEqual(f.cancelledSessions,[['source.test','old']])
  assert.equal(openings,1)
  assert.equal(f.page.detailWebChallengeClosing,false)
})
test('detail plain access denial has no automatic receipt and stale route challenge cannot retry', async () => {
  const f = fixture(); f.entry.webSessionOrigins=['https://site.invalid']
  f.state.response={ok:false,error:{code:'permission_denied',status:403}}
  await f.page.loadSourceMangaDetail('source.test','work')
  assert.equal(f.page.detailWebChallenge,null)
  f.state.response={ok:false,error:{code:'challenge_required',status:403}}
  await f.page.loadSourceMangaDetail('source.test','work')
  const receipt=f.page.detailWebChallenge
  f.page.detailWebChallengeGate.claim(receipt.id,true)
  f.page.isCurrentSourceDetailRequest=()=>false
  assert.equal(await f.page.detailWebChallengeGate.complete(receipt.id,true),false)
})


test('a fast challenge before onShown keeps its receipt for the visible route', async () => {
  const f = fixture(); f.entry.webSessionOrigins=['https://site.invalid']
  f.page.chrome.visible=false
  f.state.response={ok:false,error:{code:'challenge_required',status:403}}
  await f.page.loadSourceMangaDetail('source.test','work')
  const receipt=f.page.detailWebChallenge
  assert.ok(receipt)
  assert.equal(f.page.detailWebChallengeGate.claim(receipt.id,f.page.chrome.visible),false)
  f.page.chrome.visible=true
  assert.equal(f.page.detailWebChallengeGate.claim(receipt.id,f.page.chrome.visible),true)
})
test('a hidden detail completion consumes its claim without retrying', async () => {
  const f = fixture(); f.entry.webSessionOrigins=['https://site.invalid']
  f.state.response={ok:false,error:{code:'challenge_required',status:403}}
  await f.page.loadSourceMangaDetail('source.test','work')
  const receipt=f.page.detailWebChallenge
  f.page.detailWebChallengeGate.claim(receipt.id,true)
  f.page.detailWebChallengeId=receipt.id; f.page.detailWebChallengeShown=true
  let retries=0; f.page.loadSourceMangaDetail=async()=>{ retries++ }
  f.page.chrome.visible=false
  f.page.completeDetailWebChallenge()
  await new Promise(resolve=>setImmediate(resolve))
  assert.equal(retries,0)
  assert.equal(f.page.detailWebChallenge,null)
  assert.equal(f.page.detailWebChallengeGate.claim(receipt.id,true),false)
})


test('manual detail refresh merges in-flight requests and really bypasses the old snapshot', async () => {
  const f = fixture()
  let finish, calls = 0
  Object.assign(f.page, { params: { sourceId: 'source.test', mangaId: 'work' },
    manga: { title: 'Old readable detail' }, chapters: [{ title: 'Old readable chapter' }],
    sourceDetailDataResolved: true, sourceChaptersResolved: true, sourceDetailContentState: 'ready' })
  f.state.cache = { detail: { title: 'Stale snapshot' }, chapters: [], chaptersResolved: true }
  f.state.task = () => { calls++; return new Promise(resolve => { finish = resolve }) }
  const first = f.page.refreshMangaDetail(), concurrent = f.page.refreshMangaDetail()
  assert.equal(first, concurrent)
  assert.equal(calls, 1)
  assert.equal(f.reads.length, 0)
  assert.equal(f.page.manga.title, 'Old readable detail')
  assert.equal(f.page.chapters[0].title, 'Old readable chapter')
  finish(JSON.stringify({ ok: true, data: { manga: { title: 'Fresh detail' } } }))
  await first
  assert.equal(f.page.manga.title, 'Fresh detail')
  assert.equal(f.page.detailRefreshTask, undefined)
  f.state.task = async () => { calls++; throw new Error('network_error') }
  await f.page.refreshMangaDetail()
  assert.equal(calls, 2)
  assert.equal(f.page.manga.title, 'Fresh detail', 'a later failed refresh retains readable data')
  assert.equal(f.page.detailRefreshTask, undefined, 'a failed request must not leave refresh stuck')
})

test('detail pull refresh uses the existing local check and does not revive unsupported providers', async () => {
  const f = fixture()
  let localChecks = 0
  f.page.params = { mangaId: 'local' }
  f.page.canCheckLocalLibraryRefresh = () => true
  f.page.checkLocalLibraryRefreshNow = async () => { localChecks++ }
  assert.equal(f.page.canPullRefreshDetail(), true)
  await f.page.refreshMangaDetail()
  assert.equal(localChecks, 1)
  f.page.canCheckLocalLibraryRefresh = () => false
  assert.equal(f.page.canPullRefreshDetail(), false)
  await f.page.refreshMangaDetail()
  assert.equal(localChecks, 1)
})


test('only complete chapter results and resolved cache snapshots permit metadata persistence', async () => {
  const f = fixture()
  f.state.chapters = [{ id: 'chapter', title: 'Resolved', chapterNumber: 1 }]
  f.page.sourceChaptersResolved = true
  await f.page.loadSourceMangaDetail('source.test', 'work', true)
  assert.equal(f.applied[0][8], undefined, 'pending embedded/retained rows cannot write the library')
  assert.equal(f.applied.at(-1)[8], true)
  const failed = fixture()
  failed.page.sourceChaptersResolved = true
  failed.state.chapterError = new Error('network')
  await failed.page.loadSourceMangaDetail('source.test', 'work', true)
  assert.equal(failed.applied.at(-1)[8], false)
  const cached = fixture()
  cached.state.cache = { detail: { title: 'Cached detail' }, chapters: f.state.chapters, chaptersResolved: true }
  await cached.page.loadSourceMangaDetail('source.test', 'work')
  assert.equal(cached.applied.length, 1); assert.equal(cached.applied[0][8], true)
})
