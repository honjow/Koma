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
const pageSource = read('pages/MangaDetailPage').replace(/\bstruct (\w+)/g, 'class $1')
const file = ts.createSourceFile('page.ts', pageSource, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const owner = file.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'MangaDetailPage')
const method = name => {
  const member = owner.members.find(node => node.name?.text === name)
  assert.ok(member, name)
  return member.getText(file)
}
function fixture() {
  const logs = [], writes = [], applied = [], reads = []
  const entry = { sourceId: 'source.test', enabled: true, manifestName: 'Test', wasmBytes: new Uint8Array(1) }
  const state = { response: { ok: true, data: { manga: { title: 'Real detail' } } },
    chapterError: undefined, library: undefined, cache: undefined, chapters: [], task: undefined }
  const exports = {}
  const code = compile(`export class Page {
    ${['runSourceMangaOperation', 'sourceMangaResponseItem', 'sourceOperationFailureText', 'isDetailPending', 'loadSourceMangaDetail'].map(method).join('\n')}
  }`)
  new Function('exports', 'SourceRuntimeError', 'DiagnosticLogger', 's', 'sourceHttpIdentityJson',
    'diagnoseSourceOperation', 'taskpool', 'executeMangaDetailSourceOperation', 'parseMangaDetailFromSourceItem',
    'parseMangaChapterFromSourceItem', 'sourceRuntimeEntryEnabled', 'sourceMangaDetailSnapshotCache',
    'resolveSourceChapterList', 'SourceDetailContentState', 'mangaChapterItemFromComicChapter', code)(
    exports, SourceRuntimeError, { warn: (...args) => logs.push(args.join(' ')) }, key => key, () => '{}',
    (_request, execute) => execute(), { execute: async () => state.task ? state.task() : JSON.stringify(state.response) }, () => {},
    (_source, item) => item, item => item, item => item.enabled,
    { read: () => { reads.push(true); return state.cache }, write: (...args) => writes.push(args) },
    async () => { if (state.chapterError) throw state.chapterError; return { resolved: true, chapters: state.chapters } },
    { UNRESOLVED: 'unresolved', LOADING: 'loading', READY: 'ready', ERROR: 'error' }, chapter => ({ ...chapter }))
  const page = new exports.Page()
  Object.assign(page, {
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
  return { page, state, entry, logs, applied, writes, reads }
}
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
    ${['canReloadSourceDetail', 'runTitleAction', 'shouldRenderDetailActions', 'isDetailPending'].map(method).join('\n')}
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
