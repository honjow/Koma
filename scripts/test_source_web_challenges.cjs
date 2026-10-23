const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs'), path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
const read = name => fs.readFileSync(path.join(root, name + '.ets'), 'utf8')
const compile = source => ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
} }).outputText
function moduleFrom(name, requireMock = () => ({})) {
  const exports = {}; new Function('exports', 'require', compile(read(name)))(exports, requireMock); return exports
}
const { SourceWebChallengeGate } = moduleFrom('sourceRuntime/SourceWebChallengeGate')
const { SourceRuntimeError } = moduleFrom('model/SourceRuntimeError', () => ({
  AppStrings: { get: key => key, format: (_key, text, status) => `${text}:${status}` },
}))
const ast = ts.createSourceFile('vm.ts', read('viewmodel/BrowseViewModel'), ts.ScriptTarget.Latest, true)
const owner = ast.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'BrowseViewModel')
const methods = ['challengeGate', 'clearWebChallenge', 'claimWebChallenge', 'cancelWebChallenge',
  'completeWebChallenge', 'challengeFingerprint', 'webChallengeGuard', 'publishWebChallenge',
  'runSearch', 'loadMoreSearch', 'retrySearchPage', 'retryBrowseFailure', 'beginBrowseLoad',
  'failBrowseLoad', 'loadMoreBrowse', 'selectBrowseListing', 'loadBrowseHome', 'setSelectedSource']
const source = `export class Model { ${methods.map(name => owner.members.find(node => node.name?.text === name).getText(ast)).join('\n')} }`
const intents = { NONE: 'none', INITIAL: 'initial', REFRESH: 'refresh', PAGINATION: 'page', LISTING_REPLACEMENT: 'listing' }
const challenge = () => new SourceRuntimeError({ ok: false, error: { code: 'challenge_required', status: 403 } })
function fixture() {
  let entry = {}, revision = 0
  const exports = {}
  new Function('exports', 'SourceRuntimeError', 'appSourceSettingsStore', 'safeSearchDiagnostic',
    'safeSourceBrowseErrorText', 'BrowseLoadIntent', 'BrowseContentState', 'appendUniqueSourceManga', compile(source))(
    exports, SourceRuntimeError, { revisionForSource: () => revision }, error => ({ userText: error.userText }),
    error => error.userText, intents, { CONTENT: 'content', LOADING: 'loading', ERROR: 'error' }, (a,b) => a.concat(b))
  const model = new exports.Model(), calls = [], replies = []
  const sourceSummary = { sourceId: 'test', version: '1', wasmByteCount: 12, webSessionOrigins: ['https://test.invalid'], capabilities: ['home'] }
  Object.assign(model, { selectedSource: sourceSummary, registry: { lookup: () => ({ ok: true, entry }) },
    browseWebChallenge: null, searchWebChallenge: null,
    browseWebChallengeGate: new SourceWebChallengeGate(), searchWebChallengeGate: new SourceWebChallengeGate(),
    browseRequestId: 1, searchRequestId: 1, selectedListingId: 'popular', searchQuery: '',
    browseFilterValues: {}, searchFilterValues: {}, browsePage: 1, searchPage: 1,
    browseNextCursor: '', searchNextCursor: '', searchResults: [], hasMoreSearch: false,
    searchSource: async (_source, query, page, cursor) => {
      calls.push({ query, page, cursor }); const reply = replies.shift(); if (reply instanceof Error) throw reply; return reply
    },
    clearBrowseContent: () => {}, currentListing: () => ({ id: model.selectedListingId }), hasBrowseContent: () => true,
    isCurrentBrowseSource: () => true, isSameBrowseSource: () => true,
    loadSourceListings: async () => [], loadSourceFilters: async () => [],
    loadSourceHomeSections: async () => { calls.push('home'); throw challenge() },
    loadMangaListing: async (_source, listing, page, cursor) => { calls.push({ listing, page, cursor }); throw challenge() },
  })
  return { model, source: sourceSummary, calls, replies, replaceEntry: () => { entry = {} }, changeSettings: () => revision++ }
}
test('a challenge is claimed once, cancelled without retry, and a new user attempt may ask again', async () => {
  const f = fixture(); f.replies.push(challenge(), challenge())
  await f.model.runSearch(f.source, 'one')
  const receipt = f.model.searchWebChallenge
  assert.deepEqual(Object.keys(receipt).sort(), ['id', 'scope', 'sourceId'])
  assert.equal(f.model.claimWebChallenge('search', receipt.id, false), false)
  assert.equal(f.model.claimWebChallenge('search', receipt.id, true), true)
  assert.equal(f.model.claimWebChallenge('search', receipt.id, true), false)
  f.model.cancelWebChallenge('search', receipt.id)
  assert.equal(await f.model.completeWebChallenge('search', receipt.id, true), false)
  assert.equal(f.calls.length, 1)
  await f.model.runSearch(f.source, 'one')
  assert.ok(f.model.searchWebChallenge.id > receipt.id)
})
test('completed verification retries the original first search once; repeated challenge stays manual', async () => {
  const f = fixture(); f.replies.push(challenge(), challenge())
  await f.model.runSearch(f.source, 'one')
  const { id } = f.model.searchWebChallenge
  assert.equal(f.model.claimWebChallenge('search', id, true), true)
  assert.equal(await f.model.completeWebChallenge('search', id, true), true)
  assert.deepEqual(f.calls.map(call => [call.query,call.page]), [['one',1],['one',1]])
  assert.equal(f.model.searchWebChallenge, null)
  assert.equal(f.model.searchNeedsWebSession, true)
  assert.equal(await f.model.completeWebChallenge('search', id, true), false)
})
for (const [name, mutate] of [
  ['query', f => { f.model.searchQuery = 'two' }], ['filters', f => { f.model.searchFilterValues = { genre: 'new' } }],
  ['page', f => { f.model.searchPage++ }], ['cursor', f => { f.model.searchNextCursor = 'other' }],
  ['request', f => { f.model.searchRequestId++ }], ['source', f => { f.model.selectedSource = { ...f.source, sourceId: 'other' } }],
  ['package', f => f.replaceEntry()], ['settings', f => f.changeSettings()],
]) test(`verification cannot retry stale ${name}`, async () => {
  const f = fixture(); f.replies.push(challenge())
  await f.model.runSearch(f.source, 'one'); const { id } = f.model.searchWebChallenge
  assert.equal(f.model.claimWebChallenge('search', id, true), true)
  mutate(f)
  assert.equal(await f.model.completeWebChallenge('search', id, true), false)
  assert.equal(f.calls.length, 1)
})
test('pagination challenge retains rows and retries the exact failed page/cursor without starting first search', async () => {
  const f = fixture(); Object.assign(f.model, { searchQuery: 'one', searchPage: 2,
    searchNextCursor: 'next3', searchResults: [{ id: 'old' }], hasMoreSearch: true })
  f.replies.push(challenge(), { manga: [{ id: 'new' }], hasNextPage: false })
  await f.model.loadMoreSearch(); const { id } = f.model.searchWebChallenge
  f.model.claimWebChallenge('search', id, true)
  assert.equal(await f.model.completeWebChallenge('search', id, true), true)
  assert.deepEqual(f.calls, [{ query: 'one', page: 3, cursor: 'next3' }, { query: 'one', page: 3, cursor: 'next3' }])
  assert.equal(f.model.searchResults.length, 2)
})
for (const intent of [intents.INITIAL, intents.LISTING_REPLACEMENT, intents.PAGINATION]) {
  test(`browse ${intent} retries only its original branch once`, async () => {
    const f = fixture()
    if (intent === intents.INITIAL) await f.model.loadBrowseHome(f.source)
    else if (intent === intents.LISTING_REPLACEMENT) await f.model.selectBrowseListing({ id: 'latest' })
    else { f.model.hasMoreBrowse = true; await f.model.loadMoreBrowse() }
    const receipt = f.model.browseWebChallenge
    assert.ok(receipt); assert.equal(f.model.claimWebChallenge('browse', receipt.id, true), true)
    assert.equal(await f.model.completeWebChallenge('browse', receipt.id, true), true)
    assert.equal(f.calls.length, 2)
    assert.deepEqual(f.calls[0], f.calls[1])
    assert.equal(f.model.browseWebChallenge, null)
    assert.equal(f.model.browseNeedsWebSession, true)
  })
}
test('plain HTTP403 and missing approved origins never issue an automatic challenge', async () => {
  for (const error of [new SourceRuntimeError({ ok:false,error:{code:'permission_denied',status:403} }), challenge()]) {
    const f = fixture(); if (error.diagnostic.kind === 'challenge') f.source.webSessionOrigins = []
    f.replies.push(error); await f.model.runSearch(f.source, 'one')
    assert.equal(f.model.searchWebChallenge, null)
  }
})
test('an old completion cannot consume a newer challenge receipt', async () => {
  const f = fixture(); f.replies.push(challenge(), challenge())
  await f.model.runSearch(f.source,'one'); const old = f.model.searchWebChallenge
  f.model.claimWebChallenge('search',old.id,true)
  await f.model.runSearch(f.source,'two'); const current = f.model.searchWebChallenge
  f.model.cancelWebChallenge('search',old.id)
  assert.equal(await f.model.completeWebChallenge('search',old.id,true),false)
  assert.equal(f.model.searchWebChallenge.id,current.id)
})


test('completion rejected on hidden route consumes the old claim, even after route becomes visible', async () => {
  const f = fixture(); f.replies.push(challenge())
  await f.model.runSearch(f.source, 'one'); const { id } = f.model.searchWebChallenge
  f.model.claimWebChallenge('search', id, true)
  assert.equal(await f.model.completeWebChallenge('search', id, false), false)
  assert.equal(f.model.searchWebChallenge, null)
  assert.equal(f.model.searchWebChallengeGate.claim(id, true), false)
  assert.equal(f.calls.length, 1)
})
test('home preliminary listing/filter results do not invalidate its later listing challenge', async () => {
  const f = fixture()
  f.model.loadSourceListings = async () => [{ id: 'latest' }]
  f.model.loadSourceFilters = async () => [{ id: 'genre' }]
  f.model.loadSourceHomeSections = async () => []
  f.model.mergeSavedSourceFilterValues = (_source, _kind, values) => values
  f.model.defaultSourceFilterValues = () => ({ genre: 'all' })
  f.model.sourceSupportsOperation = () => true
  f.model.defaultListingForBrowse = listings => listings[0]
  await f.model.loadBrowseHome(f.source)
  const receipt = f.model.browseWebChallenge
  assert.ok(receipt)
  assert.equal(f.model.claimWebChallenge('browse', receipt.id, true), true)
  assert.equal(await f.model.completeWebChallenge('browse', receipt.id, true), true)
  assert.deepEqual(f.calls, [{ listing: 'latest', page: 1, cursor: '' }, { listing: 'latest', page: 1, cursor: '' }])
})
