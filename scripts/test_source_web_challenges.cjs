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
const methods = ['challengeGate', 'clearWebChallenge', 'claimWebChallenge', 'canRetryWebChallenge', 'cancelWebChallenge',
  'completeWebChallenge', 'challengeFingerprint', 'webChallengeGuard', 'publishWebChallenge',
  'searchResultFingerprint', 'runSearch', 'clearSearch', 'loadMoreSearch', 'retrySearchPage', 'retryBrowseFailure', 'beginBrowseLoad',
  'failBrowseLoad', 'loadMoreBrowse', 'selectBrowseListing', 'selectBrowseHome', 'loadBrowseHome', 'setSelectedSource',
  'sourceSupportsOperation', 'clearBrowseContent', 'clearBrowseListing', 'hasBrowseContent', 'resolveBrowseLoad',
  'currentListing', 'defaultListingForBrowse', 'applyBrowseListing']
const source = `export class Model { ${methods.map(name => owner.members.find(node => node.name?.text === name).getText(ast)).join('\n')} }`
const intents = { NONE: 'none', INITIAL: 'initial', REFRESH: 'refresh', PAGINATION: 'page', LISTING_REPLACEMENT: 'listing' }
const challenge = () => new SourceRuntimeError({ ok: false, error: { code: 'challenge_required', status: 403 } })
function fixture() {
  let entry = {}, revision = 0
  const exports = {}
  new Function('exports', 'SourceRuntimeError', 'appSourceSettingsStore', 'safeSearchDiagnostic',
    'safeSourceBrowseErrorText', 'BrowseLoadIntent', 'BrowseContentState', 'appendUniqueSourceManga', compile(source))(
    exports, SourceRuntimeError, { revisionForSource: () => revision }, error => ({ userText: error.userText }),
    error => error.userText, intents, { CONTENT: 'content', LOADING: 'loading', ERROR: 'error', EMPTY: 'empty', UNRESOLVED: 'unresolved' }, (a,b) => a.concat(b))
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
    homeAvailable: true, homeSections: [], listings: [{ id: 'popular', name: 'Popular', kind: 'popular' }],
    browseSections: [{ listing: { id: 'popular' }, manga: [{ id: 'old' }] }], popularManga: [{ id: 'old' }],
    defaultSourceFilterValues: () => ({}), mergeSavedSourceFilterValues: (_source, _kind, values) => values,
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
  assert.deepEqual(Object.keys(receipt).sort(), ['allowClearanceRetry', 'id', 'scope', 'sourceId'])
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
test('browse metadata results do not invalidate its later listing challenge', async () => {
  const f = fixture()
  f.model.loadSourceListings = async () => [{ id: 'latest' }]
  f.model.loadSourceFilters = async () => [{ id: 'genre' }]
  f.model.loadSourceHomeSections = async () => []
  f.model.mergeSavedSourceFilterValues = (_source, _kind, values) => values
  f.model.defaultSourceFilterValues = () => ({ genre: 'all' })
  f.source.capabilities = ['sourceInfo', 'mangaList', 'listings', 'filters']
  f.model.defaultListingForBrowse = listings => listings[0]
  await f.model.loadBrowseHome(f.source)
  const receipt = f.model.browseWebChallenge
  assert.ok(receipt)
  assert.equal(f.model.claimWebChallenge('browse', receipt.id, true), true)
  assert.equal(await f.model.completeWebChallenge('browse', receipt.id, true), true)
  assert.deepEqual(f.calls, [{ listing: 'latest', page: 1, cursor: '' }, { listing: 'latest', page: 1, cursor: '' }])
})


// User adoption of SOURCE_BROWSE_HOME_STRUCTURE replaces the old mixed
// Home+default-listing behavior; these execute the production VM methods.
test('Home and listings are exclusive; refreshing a selected listing keeps its rows and destination', async () => {
  const f = fixture(), home = [{ id: 'recommend', manga: [{ id: 'home1' }] }]
  f.source.capabilities = ['sourceInfo', 'home', 'mangaList', 'listings']
  f.model.loadSourceListings = async () => [{ id: 'popular', kind: 'popular' }, { id: 'latest' }]
  f.model.loadSourceHomeSections = async () => { f.calls.push('home'); return home }
  f.model.loadMangaListing = async (_source, id) => { f.calls.push(id); return { manga: [{ id }], hasNextPage: false } }
  await f.model.loadBrowseHome(f.source)
  assert.deepEqual(f.calls, ['home']); assert.equal(f.model.selectedListingId, '')
  assert.deepEqual(f.model.homeSections, home); assert.deepEqual(f.model.browseSections, [])
  assert.equal(f.model.hasMoreBrowse, false)
  assert.equal(f.model.currentListing().id, 'popular') // existing filter destination from Home
  await f.model.selectBrowseListing({ id: 'latest' })
  assert.deepEqual(f.model.homeSections, []); assert.equal(f.model.homeAvailable, true)
  const oldRows = f.model.browseSections
  let reject
  f.model.loadMangaListing = async (_source, id) => { f.calls.push(id); return new Promise((_r, fail) => { reject = fail }) }
  const refreshing = f.model.loadBrowseHome(f.source, intents.REFRESH)
  await new Promise(setImmediate)
  assert.equal(f.model.browseSections, oldRows); assert.equal(f.model.selectedListingId, 'latest')
  reject(Error('offline')); await refreshing
  assert.equal(f.model.browseSections, oldRows); assert.equal(f.model.browseErrorIntent, intents.REFRESH)
  f.model.loadMangaListing = async (_source, id) => { f.calls.push(id); return { manga: [{ id: 'new' }], hasNextPage: false } }
  await f.model.retryBrowseFailure()
  assert.deepEqual(f.calls, ['home', 'latest', 'latest', 'latest'])
  assert.equal(f.model.selectedListingId, 'latest'); assert.deepEqual(f.model.homeSections, [])
})
test('a failed switch to Home keeps listing rows and verification retries Home only', async () => {
  const f = fixture(), oldRows = f.model.browseSections
  f.model.hasMoreBrowse = true
  await f.model.selectBrowseHome()
  assert.equal(f.model.browseSections, oldRows); assert.equal(f.model.selectedListingId, 'popular')
  await f.model.loadMoreBrowse() // retained tail must not consume the failed Home target
  assert.deepEqual(f.calls, ['home'])
  const receipt = f.model.browseWebChallenge
  assert.ok(receipt); f.model.claimWebChallenge('browse', receipt.id, true)
  f.model.loadSourceHomeSections = async () => { f.calls.push('home'); return [{ id: 'home', manga: [{ id: 'ready' }] }] }
  assert.equal(await f.model.completeWebChallenge('browse', receipt.id, true), true)
  assert.deepEqual(f.calls, ['home', 'home']); assert.equal(f.model.selectedListingId, '')
  assert.deepEqual(f.model.browseSections, []); assert.equal(f.model.homeSections[0].manga[0].id, 'ready')
})
test('a late Home response cannot overwrite a newly selected source', async () => {
  const f = fixture(); let resolve
  f.model.loadSourceHomeSections = async () => new Promise(done => { resolve = done })
  const switching = f.model.selectBrowseHome()
  f.model.setSelectedSource({ ...f.source, sourceId: 'other' })
  resolve([{ id: 'stale', manga: [{ id: 'wrong' }] }]); await switching
  assert.equal(f.model.selectedSource.sourceId, 'other')
  assert.deepEqual(f.model.homeSections, []); assert.deepEqual(f.model.browseSections, [])
  assert.equal(f.model.homeAvailable, false)
})


const { hasNewSourceClearance, sourceClearanceCookieState } = moduleFrom('sourceRuntime/SourceWebChallengeGate')
test('clearance candidate requires a nonempty changed exact cookie; other names and ambiguous duplicates cannot complete', () => {
  for (const [before, after] of [['', 'sid=x'], ['cf_clearance=a', 'cf_clearance=a; sid=new'],
    ['cf_clearance=a', 'cf_clearance='], ['', 'not_cf_clearance=a'], ['', 'cf_clearance=a; cf_clearance=b']]) {
    assert.equal(hasNewSourceClearance(before, after), false)
  }
  assert.equal(hasNewSourceClearance('', 'sid=x; cf_clearance=a=b; theme=y'), true)
  assert.equal(hasNewSourceClearance('cf_clearance=old', 'cf_clearance=new'), true)
})

const sheetText = read('components/SourceWebSessionSheet').replace('export struct SourceWebSessionSheet', 'export class SourceWebSessionSheet')
const sheetAst = ts.createSourceFile('sheet.ts', sheetText, ts.ScriptTarget.Latest, true)
const sheetOwner = sheetAst.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'SourceWebSessionSheet')
const sheetMethods = ['isCurrent','updateNavState','loadInitialPage','pageBegan','pageEnded','mainPageFailed',
  'completeSourceSession','close','sessionChanged','aboutToDisappear','consoleMessage','resourceFailed','navigationRequested']
const sheetSource = `export class Sheet { ${sheetMethods.map(name => sheetOwner.members.find(n => n.name?.text === name).getText(sheetAst).replace(/@Monitor\([^\n]*\)\s*/g, '')).join('\n')} }`
function sheetFixture() {
  let cookies = 'cf_clearance=old', failRead = false, saveError = false, saveWait = Promise.resolve(), probeResult = Promise.resolve(false)
  const probes = [], cancelledProbes = []
  const exports = {}, granted = [], completed = [], events = []
  const webview = { WebCookieManager: {
    isCookieAllowed: () => true, isThirdPartyCookieAllowed: () => false,
    fetchCookieSync: () => { if (failRead) throw Error('unavailable'); return cookies },
    saveCookieSync: () => { if (saveError) throw Error('async required') }, saveCookieAsync: () => saveWait,
  } }
  new Function('exports','webview','appSourceWebSessionStore','sourceWebOrigin','hasNewSourceClearance','sourceClearanceCookieState','DiagnosticLogger','AppStrings','mangaHttpUrl','readSourceWebCookies','probeSourceWebSession','cancelSourceWebProbe', compile(sheetSource))(
    exports, webview, { complete: (...args) => { granted.push(args); return { state:'available' } } },
    u => { try { return new URL(u).origin } catch { return '' } }, hasNewSourceClearance, sourceClearanceCookieState,
    { info: (...args) => events.push(args) }, { get: s => s }, moduleFrom('model/MangaWebLink').mangaHttpUrl,
    fullUrl => webview.WebCookieManager.fetchCookieSync(fullUrl, false),
    (...args) => { probes.push(args); return probeResult }, (...args) => cancelledProbes.push(args))
  const sheet = new exports.Sheet(), initialUrl = 'https://test.invalid/catalog'
  Object.assign(sheet, { params: {url:initialUrl,sourceSession:{sourceId:'test',sessionId:'attempt1'}},
    autoRetryOnClearance:true,canProbeOriginal:()=>true,active:true,epoch:1,controllerReady:true,loading:false,completing:false,completed:false,
    autoRetryStarted:false,pageRevision:0,pageUrl:'',pageFailed:false,clearanceBaseline:undefined,
    controller:{loadUrl:()=>{},getUrl:()=>sheet.pageUrl,getCustomUserAgent:()=>'',getUserAgent:()=> 'Web UA',
      accessBackward:()=>false,accessForward:()=>false},
    onCompleted: status => completed.push(status),onClose:()=>events.push('closed'),
    getUIContext:()=>({getPromptAction:()=>({showToast:()=>{}})}),
  })
  sheet.loadInitialPage(); sheet.navigationRequested({data:{isMainFrame:()=>true,getRequestUrl:()=>initialUrl}}); sheet.pageBegan({url:initialUrl})
  return { sheet, initialUrl, granted, completed, events, probes, cancelledProbes, setProbe:p=>probeResult=p, setCookies:s=>cookies=s, failRead:()=>failRead=true,
    delaySave:()=> { saveError=true; let resolve; saveWait=new Promise(r=>resolve=r); return resolve } }
}
const settled = () => new Promise(resolve=>setImmediate(resolve))
test('changed clearance on current successful document retries once without a manual tap', async () => {
  const f=sheetFixture();f.setCookies('cf_clearance=new');f.sheet.pageEnded({url:f.initialUrl});
  f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.granted.length,1);assert.equal(f.completed.length,1)
  assert.equal(f.granted[0][2],f.initialUrl);assert.equal(JSON.stringify(f.events).includes('cf_clearance'),false)
})
test('manual login does not auto-close when clearance changes; its completion control still works', async () => {
  const f=sheetFixture();f.sheet.autoRetryOnClearance=false;f.setCookies('cf_clearance=new');
  f.sheet.pageEnded({url:f.initialUrl});await settled();assert.equal(f.granted.length,0)
  await f.sheet.completeSourceSession();assert.equal(f.completed.length,1)
})
test('main document HTTP/transport error blocks auto candidate, while a subresource error does not', async () => {
  for (const isMain of [true,false]) {
    const f=sheetFixture();f.setCookies('cf_clearance=new');
    f.sheet.mainPageFailed({isMainFrame:()=>isMain,getRequestUrl:()=>f.initialUrl})
    f.sheet.pageEnded({url:f.initialUrl});await settled();assert.equal(f.granted.length,isMain?0:1)
  }
})
test('off-origin and stale navigation completion cannot auto-complete current source', async () => {
  for (const stale of [true,false]) {
    const f=sheetFixture();f.setCookies('cf_clearance=new')
    f.sheet.pageBegan({url:stale?'https://test.invalid/new':'https://other.invalid/'})
    f.sheet.pageEnded({url:stale?f.initialUrl:'https://other.invalid/'})
    await settled();assert.equal(f.granted.length,0)
  }
})
test('unknown cookie baseline never becomes an automatic success signal', async () => {
  const f=sheetFixture();f.sheet.clearanceBaseline=undefined;f.failRead();f.sheet.loadInitialPage();
  f.sheet.pageBegan({url:f.initialUrl});f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.granted.length,0);await f.sheet.completeSourceSession();assert.equal(f.completed.length,1)
})
for (const action of ['close','aboutToDisappear','navigation','replacement']) test(`pending cookie flush cannot complete after ${action}`, async () => {
  const f=sheetFixture(), release=f.delaySave();f.setCookies('cf_clearance=new');f.sheet.pageEnded({url:f.initialUrl})
  if (action==='navigation') f.sheet.pageBegan({url:'https://test.invalid/new'})
  else if (action==='replacement') {
    f.sheet.params={url:f.initialUrl,sourceSession:{sourceId:'test',sessionId:'attempt2'}}
    f.sheet.sessionChanged()
  } else f.sheet[action]()
  release();await settled();assert.equal(f.granted.length,0);assert.equal(f.completed.length,0)
})

test('authentication recovery may open Web but cannot auto-return on a challenge cookie before login', async () => {
  const f = fixture();f.replies.push(new SourceRuntimeError({ok:false,error:{code:'auth_required',status:401}}))
  await f.model.runSearch(f.source,'one');assert.ok(f.model.searchWebChallenge)
  assert.equal(f.model.searchWebChallenge.allowClearanceRetry,false)
  f.replies.push(challenge());await f.model.runSearch(f.source,'one')
  assert.equal(f.model.searchWebChallenge.allowClearanceRetry,true)
})

test('verification console keeps only a standard challenge code and never page text or secrets', () => {
  const f=sheetFixture();f.events.length=0
  const messages=['password=secret 123456', '[Cloudflare Turnstile] Error: 600010. token=secret',
    '[Cloudflare Turnstile] Error: 1234567 token=secret', 'normal page output']
  for (const message of messages) assert.equal(f.sheet.consoleMessage({message:{getMessage:()=>message}}), false)
  assert.deepEqual(f.events,[['source_web_session','challenge_console','code=600010']])
  f.sheet.active=false
  f.sheet.consoleMessage({message:{getMessage:()=> '[Cloudflare Turnstile] Error: 110600.'}})
  assert.equal(f.events.length,1)
})
test('verification resource diagnostics keep numeric stage and host classification without exposing URL', () => {
  const f=sheetFixture();f.events.length=0
  const sub={isMainFrame:()=>false,getRequestUrl:()=> 'https://challenges.cloudflare.com/private?token=secret'}
  f.sheet.resourceFailed(sub,'transport',-105)
  assert.equal(f.sheet.pageFailed,false)
  assert.deepEqual(f.events,[['source_web_session','resource_failed','revision=1 kind=transport code=-105 mainFrame=false matchingDocument=false challengeHost=true']])
  assert.equal(JSON.stringify(f.events).includes('secret'),false)
  f.sheet.resourceFailed({isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl},'http',403)
  assert.equal(f.sheet.pageFailed,true)
})

test('clearance diagnostics distinguish missing, empty and duplicate cookies without disclosing values', async () => {
  for (const [cookies, expected] of [['sid=secret', 'missing'], ['cf_clearance=', 'empty'],
    ['cf_clearance=secret', 'present'], ['cf_clearance=secret; cf_clearance=other', 'ambiguous'],
    ['not_cf_clearance=secret', 'missing']]) {
    assert.equal(sourceClearanceCookieState(cookies), expected)
    const f=sheetFixture();f.events.length=0;f.setCookies(cookies);f.sheet.pageEnded({url:f.initialUrl});await settled()
    const context=f.events.find(event=>event[1]==='cookie_context')
    assert.ok(context[2].includes('requestClearance='+expected))
    assert.ok(context[2].includes('currentClearance='+expected))
    assert.equal(JSON.stringify(f.events).includes('secret'),false)
    assert.equal(f.granted.length,expected==='present'?1:0)
  }
})
test('document revisions distinguish a stale main-frame error from the current document without logging paths', () => {
  const f=sheetFixture();f.events.length=0
  f.sheet.pageBegan({url:'https://test.invalid/current?token=secret'})
  f.sheet.resourceFailed({isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl},'http',403)
  assert.equal(f.sheet.pageFailed,false)
  assert.ok(f.events.some(event=>event[1]==='document_begin' && event[2].includes('revision=2')))
  assert.ok(f.events.some(event=>event[1]==='resource_failed' && event[2].includes('matchingDocument=false')))
  f.sheet.resourceFailed({isMainFrame:()=>true,getRequestUrl:()=>f.sheet.pageUrl},'http',403)
  assert.equal(f.sheet.pageFailed,true)
  assert.ok(f.events.at(-1)[2].includes('matchingDocument=true'))
  assert.equal(JSON.stringify(f.events).includes('secret'),false)
})

test('a main HTTP error arriving before pageBegin cannot be cleared into an automatic completion', async () => {
  const f=sheetFixture();f.setCookies('cf_clearance=new')
  f.sheet.mainPageFailed({isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl})
  f.sheet.pageBegan({url:f.initialUrl});f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.sheet.pageFailed,true);assert.equal(f.completed.length,0);assert.equal(f.sheet.autoRetryStarted,false)
  assert.equal(f.sheet.navigationRequested({data:{isMainFrame:()=>false,getRequestUrl:()=> 'https://other.invalid/frame'}}),false)
  assert.equal(f.sheet.pageFailed,true)
  assert.equal(f.sheet.navigationRequested({data:{isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl}}),false)
  f.sheet.pageBegan({url:f.initialUrl});f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.sheet.pageFailed,false);assert.equal(f.completed.length,1)
})
test('an initial main HTTP error before any pageBegin remains failed until a real new main request', async () => {
  const f=sheetFixture();f.sheet.pageUrl='';f.sheet.pageRevision=0;f.sheet.pageFailed=false;f.setCookies('cf_clearance=new')
  f.sheet.navigationRequested({data:{isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl}})
  f.sheet.resourceFailed({isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl},'http',403)
  f.sheet.pageBegan({url:f.initialUrl});f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.sheet.pageFailed,true);assert.equal(f.granted.length,0)
})

function opaqueChallengeRecovered(f) {
  f.sheet.clearanceBaseline='site_token=old';f.setCookies('site_token=new')
  f.sheet.resourceFailed({isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl},'http',403)
  f.sheet.navigationRequested({data:{isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl}})
  f.sheet.pageBegan({url:f.initialUrl});f.sheet.pageEnded({url:f.initialUrl})
}
test('a non-CF challenge keeps Web visible until the original native read actually passes',async()=>{
  const f=sheetFixture();let resolve;f.setProbe(new Promise(r=>resolve=r));opaqueChallengeRecovered(f)
  await settled();assert.equal(f.probes.length,1);assert.equal(f.completed.length,0);assert.equal(f.granted.length,0)
  resolve(true);await settled();assert.equal(f.granted.length,1);assert.equal(f.completed.length,1)
})
test('failed non-CF native verification leaves the manual control usable and never automatically loops',async()=>{
  const f=sheetFixture();opaqueChallengeRecovered(f);await settled()
  assert.equal(f.completed.length,0);assert.equal(f.granted.length,0);assert.equal(f.probes.length,1)
  f.sheet.pageEnded({url:f.initialUrl});await settled();assert.equal(f.probes.length,1)
  await f.sheet.completeSourceSession();assert.equal(f.completed.length,1)
})
test('an arbitrary cookie change without a current original native challenge cannot trigger a probe',async()=>{
  const f=sheetFixture();f.sheet.canProbeOriginal=()=>false;f.sheet.clearanceBaseline='site_token=old';f.setCookies('site_token=new')
  f.sheet.pageEnded({url:f.initialUrl});await settled();assert.equal(f.probes.length,0);assert.equal(f.completed.length,0)
})
for(const action of ['close','aboutToDisappear','navigation'])test('an in-flight non-CF probe cannot finish after '+action,async()=>{
  const f=sheetFixture();let resolve;f.setProbe(new Promise(r=>resolve=r));opaqueChallengeRecovered(f);await settled()
  if(action==='navigation')f.sheet.navigationRequested({data:{isMainFrame:()=>true,getRequestUrl:()=>f.initialUrl}})
  else f.sheet[action]()
  resolve(true);await settled();assert.equal(f.granted.length,0);assert.equal(f.completed.length,0)
})

test('a native probe requires the original claimed receipt and current route/query/settings',async()=>{
  const f=fixture();f.replies.push(challenge());await f.model.runSearch(f.source,'one')
  const {id}=f.model.searchWebChallenge
  assert.equal(f.model.canRetryWebChallenge('search',id,true),false)
  f.model.claimWebChallenge('search',id,true)
  assert.equal(f.model.canRetryWebChallenge('search',id,true),true)
  assert.equal(f.model.canRetryWebChallenge('search',id,false),false)
  f.changeSettings();assert.equal(f.model.canRetryWebChallenge('search',id,true),false)
})
test('a stale original receipt cannot start or complete the pending native verification',async()=>{
  const f=sheetFixture();f.sheet.canProbeOriginal=()=>false;opaqueChallengeRecovered(f);await settled()
  assert.equal(f.probes.length,0);assert.equal(f.granted.length,0)
  const g=sheetFixture();let resolve;g.setProbe(new Promise(r=>resolve=r));opaqueChallengeRecovered(g);await settled()
  g.sheet.canProbeOriginal=()=>false;resolve(true);await settled()
  assert.equal(g.granted.length,0);assert.equal(g.completed.length,0)
})

test('an already-working non-CF Web document validates the claimed native read without a Web403 or cookie change',async()=>{
  const f=sheetFixture();f.sheet.clearanceBaseline='site_token=unchanged';f.setCookies('site_token=unchanged')
  let resolve;f.setProbe(new Promise(r=>resolve=r));f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.probes.length,1);assert.equal(f.granted.length,0);assert.equal(f.completed.length,0)
  resolve(true);await settled();assert.equal(f.granted.length,1);assert.equal(f.completed.length,1)
})
test('a normal non-CF document alone never grants access when its original native read still fails',async()=>{
  const f=sheetFixture();f.sheet.clearanceBaseline='site_token=unchanged';f.setCookies('site_token=unchanged')
  f.sheet.pageEnded({url:f.initialUrl});await settled()
  assert.equal(f.probes.length,1);assert.equal(f.granted.length,0);assert.equal(f.completed.length,0)
  f.sheet.pageEnded({url:f.initialUrl});await settled();assert.equal(f.probes.length,1)
})

// Native197599–605: CF completes, site redirects /searchelxt1e1.aspx to its
// broken /search.aspx, while manual completion recovers the original GET200.
function failedSearchLanding(f, url='https://test.invalid/search', kind='http', code=404) {
  f.sheet.navigationRequested({data:{isMainFrame:()=>true,getRequestUrl:()=>url}})
  f.sheet.resourceFailed({isMainFrame:()=>true,getRequestUrl:()=>url},kind,code)
  f.sheet.pageBegan({url});f.sheet.pageEnded({url})
  return url
}
test('a404 landing with clearance only grants after the exact original native probe passes, once',async()=>{
  const f=sheetFixture();let resolve;f.setProbe(new Promise(r=>resolve=r))
  const landing=failedSearchLanding(f);await settled()
  assert.equal(f.sheet.pageFailed,true);assert.equal(f.probes.length,1)
  assert.equal(f.probes[0][2],landing);assert.equal(f.granted.length,0)
  f.sheet.pageEnded({url:landing});await settled();assert.equal(f.probes.length,1)
  resolve(true);await settled();assert.equal(f.granted.length,1);assert.equal(f.completed.length,1)
})
test('failed landing cannot widen native probe eligibility or automatically loop after refusal',async()=>{
  for(const [url,kind,code,cookies] of [
    ['https://test.invalid/catalog','http',404,'cf_clearance=old'],
    ['https://other.invalid/search','http',404,'cf_clearance=old'],
    ['https://test.invalid/search','http',500,'cf_clearance=old'],
    ['https://test.invalid/search','transport',404,'cf_clearance=old'],
    ['https://test.invalid/search','http',404,'sid=only'],
  ]) {
    const f=sheetFixture();f.setCookies(cookies);failedSearchLanding(f,url,kind,code);await settled()
    assert.equal(f.probes.length,0);assert.equal(f.granted.length,0)
  }
  const f=sheetFixture();const landing=failedSearchLanding(f);await settled()
  assert.equal(f.probes.length,1);assert.equal(f.granted.length,0)
  f.sheet.pageEnded({url:landing});await settled();assert.equal(f.probes.length,1)
  await f.sheet.completeSourceSession();assert.equal(f.completed.length,1)
})


test('same-query refresh failure retains loaded rows and retries page one through the existing footer', async () => {
  const f=fixture();f.replies.push({manga:[{id:'p1'}],hasNextPage:true,nextCursor:'cursor2'},
    {manga:[{id:'p2'}],hasNextPage:true,nextCursor:'cursor3'})
  await f.model.runSearch(f.source,'one');await f.model.loadMoreSearch()
  const rows=f.model.searchResults
  let reject;f.replies.push(new Promise((_resolve,r)=>{reject=r}))
  const refresh=f.model.runSearch(f.source,' one ')
  const pending={rows:f.model.searchResults,page:f.model.searchPage,cursor:f.model.searchNextCursor}
  reject(challenge());await refresh
  assert.equal(f.model.searchResults,rows,'a failed refresh preserves previously loaded rows')
  assert.equal(pending.rows,rows,'retain the exact displayed row array while pending')
  assert.equal(pending.page,2);assert.equal(pending.cursor,'cursor3')
  assert.equal(f.model.searchPage,2)
  assert.equal(f.model.searchNextCursor,'cursor3');assert.equal(f.model.hasMoreSearch,false)
  f.replies.push({manga:[{id:'fresh1'}],hasNextPage:true,nextCursor:'fresh2'})
  await f.model.retrySearchPage()
  assert.deepEqual(f.calls.map(x=>x.page),[1,2,1,1],'footer retries failed refresh, never appends page three')
  assert.deepEqual(f.model.searchResults,[{id:'fresh1'}]);assert.equal(f.model.searchPage,1)
  assert.equal(f.model.searchNextCursor,'fresh2')
})

for(const [name,change] of [
  ['query',f=>{f.query='different'}],['source',f=>{f.source={...f.source,sourceId:'other'}}],
  ['package version',f=>{f.source={...f.source,version:'2'}}],['entry',f=>f.replaceEntry()],
  ['settings',f=>f.changeSettings()],['filters',f=>{f.model.searchFilterValues={region:'new'}}],
])test('first-page failure does not inherit rows from a different '+name,async()=>{
  const f=fixture();f.query='one';f.replies.push({manga:[{id:'old'}],hasNextPage:false})
  await f.model.runSearch(f.source,'one');change(f);f.replies.push(challenge())
  await f.model.runSearch(f.source,f.query);assert.deepEqual(f.model.searchResults,[])
})

test('successful same-query empty refresh replaces old rows and clearSearch invalidates retention',async()=>{
  const f=fixture();f.replies.push({manga:[{id:'old'}],hasNextPage:false},{manga:[],hasNextPage:false})
  await f.model.runSearch(f.source,'one');await f.model.runSearch(f.source,'one')
  assert.deepEqual(f.model.searchResults,[]);assert.equal(f.model.searchErrorMessage,'')
  f.replies.push({manga:[{id:'again'}],hasNextPage:false});await f.model.runSearch(f.source,'one')
  f.model.clearSearch(f.source);f.replies.push(challenge());await f.model.runSearch(f.source,'one')
  assert.deepEqual(f.model.searchResults,[])
})

// Exercise the real global-search service and page owners together; no UI-tree
// or source spelling assertions stand in for receipt/retry ordering.
const crossAst = ts.createSourceFile('cross.ts', read('model/CrossSearchService'), ts.ScriptTarget.Latest, true)
const crossOwner = crossAst.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'CrossSearchService')
const crossMethods = ['search','cancelPendingSearch','cancelWebChallenges','claimWebChallenge','canRetryWebChallenge',
  'cancelWebChallenge','completeWebChallenge','sourceWebChallengeGuard','pendingSections','sourceMatchesFilter',
  'searchWasmSource','section','stateSection','errorSection','sourceSupportsSearch']
const pageAst = ts.createSourceFile('page.ts', read('pages/SearchPage').replace('struct SearchPage', 'class SearchPage'), ts.ScriptTarget.Latest, true)
const pageOwner = pageAst.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'SearchPage')
const pageMethods = ['ownsRoute','runSearch','prepareSearchResults','invalidateWebChallenges','cancelCurrentWebSession',
  'handleWebChallenges','closeWebChallenge','completeWebChallenge','finishWebChallengeDismiss']
const classText = (owner, ast, names) => `export class Owner { ${names.map(name => owner.members.find(n => n.name?.text === name).getText(ast)).join('\n')} }`
function deferredSearchReply() {
  let resolve, reject
  const promise = new Promise((yes,no) => { resolve=yes; reject=no })
  return {promise,resolve,reject}
}
const untilSearch = async predicate => {
  for (let i=0;i<50&&!predicate();i++) await new Promise(resolve => setImmediate(resolve))
  assert.equal(predicate(),true,'expected production async checkpoint')
}
function crossWebFixture(ids) {
  const entries=new Map(ids.map(id=>[id,{enabled:true}])), revisions=new Map(ids.map(id=>[id,0]))
  const sources=ids.map(sourceId=>({sourceId,displayName:sourceId,enabled:true,version:'1',wasmByteCount:12,
    capabilities:['search'],webSessionOrigins:['https://source.invalid']}))
  const registry={lookup:id=>({entry:entries.get(id)}),listInstalledSourceSummaries:()=>sources}
  let guardSequence=0
  const exports={}
  new Function('exports','SourceWebChallengeGate','SourceRuntimeError','appSourceRuntimeRegistry','appSourceSettingsStore',
    'DiagnosticLogger','AppStrings','safeSearchDiagnostic','searchStateUserText','SOURCE_PAGE_SIZE','isCrossSearchQueryMeaningful',
    'newSourceRuntimeOperationGuardId','clearSourceRejectedRequest','selectSourceRejectedRequest',
    compile(classText(crossOwner,crossAst,crossMethods)))(exports,SourceWebChallengeGate,SourceRuntimeError,registry,
    {revisionForSource:id=>revisions.get(id)},
    {begin:()=>({finish(){},fail(){}}),info(){},error(){}},{get:key=>key},
    error=>({code:error.diagnostic?.code??'unknown',userText:error.userText??'failed'}),()=>'',20,q=>q.length>0,
    ()=>`search-${++guardSequence}`,()=>{},()=>{})
  const service=new exports.Owner(), replies=new Map(), calls=[]
  Object.assign(service,{pagedSearchRuns:[],webChallengeGates:new Map(),webChallengeHandles:new Map(),sortSearchResultItems:(_q,items)=>items,
    sourceViewModel:{searchSource:async(source,query,page,cursor,active,handle)=>{
      calls.push([source.sourceId,query,page,cursor,handle])
      const queue=replies.get(source.sourceId+'|'+query)
      assert.ok(queue?.length,'unexpected source replay')
      const reply=await queue.shift()
      if(!active()) throw new Error('search_cancelled')
      if(reply instanceof Error) throw reply
      return reply
    }}})
  const pageExports={}; let session=0
  new Function('exports','isCrossSearchQueryMeaningful','safeSearchDiagnostic','DiagnosticLogger',
    'appSourceWebSessionStore','cancelSourceWebProbe','prepareSourceWebSession',
    compile(classText(pageOwner,pageAst,pageMethods)))(pageExports,q=>q.length>0,()=>({userText:'failed',code:'failed'}),
    {error(){}},{cancel(){}},()=>{},(sourceId,title,requestHandle)=>({url:'https://source.invalid/',title,
      sourceSession:{sourceId,sessionId:String(++session),requestHandle}}))
  const page=new pageExports.Owner()
  Object.assign(page,{service,routeEpoch:1,routeActive:true,chrome:{visible:true},searchSerial:0,sections:[],
    sourceFilter:'source',resultsQuery:'',resultsSourceFilter:'source',webChallengeEpoch:0,webChallengeRetrySerial:0,
    webChallengeRetryPending:false,webChallengeClosing:false,webChallengeShown:false,webChallengeParams:{url:'',title:''},
    recordHistory(){}})
  return {page,service,calls,revisions,entries,
    reply:(id,query,...values)=>replies.set(id+'|'+query,values),
    ready:id=>({manga:[{id,sourceId:id,title:id}],hasNextPage:false}),
    section:id=>page.sections.find(s=>s.id==='wasm:'+id)}
}

test('global verification serializes sources, retains independent results and only replays the verified source', async () => {
  const f=crossWebFixture(['one','two','three','four'])
  const recovered=deferredSearchReply(), third=deferredSearchReply(), fourth=deferredSearchReply()
  f.reply('one','q',challenge(),recovered.promise);f.reply('two','q',f.ready('two'))
  f.reply('three','q',third.promise);f.reply('four','q',fourth.promise)
  const search=f.page.runSearch('q')
  await untilSearch(()=>f.page.webChallengeShown&&f.section('two')?.state==='ready')
  assert.equal(f.page.webChallengeParams.sourceSession.sourceId,'one')
  third.reject(challenge())
  await untilSearch(()=>f.section('three')?.webChallenge!==undefined)
  assert.equal(f.page.webChallengeParams.sourceSession.sourceId,'one','only one visible verification')
  const retry=f.page.completeWebChallenge()
  f.page.finishWebChallengeDismiss()
  assert.equal(f.page.webChallengeShown,false,'next source waits for original replay, not only dismissal')
  assert.equal(f.section('one').state,'running');assert.equal(f.section('two').state,'ready')
  recovered.resolve(f.ready('one'));await retry
  assert.equal(f.page.webChallengeParams.sourceSession.sourceId,'three')
  fourth.resolve(f.ready('four'));await search
  assert.equal(f.section('one').state,'ready','late initial aggregate must retain the recovered result')
  assert.equal(f.section('two').state,'ready');assert.equal(f.section('four').state,'ready')
  f.page.closeWebChallenge();f.page.finishWebChallengeDismiss()
  assert.equal(f.page.webChallengeShown,false,'cancelled source does not immediately reopen')
  assert.deepEqual(f.calls.map(c=>c[0]),['one','two','three','four','one'])
  assert.equal(f.calls[0][4],f.calls[4][4],'verification retry retains the original operation identity')
  assert.notEqual(f.calls[0][4],f.calls[2][4],'different sources retain different operation identities')
})

test('a replaced global query retires old claims, and generic403 or changed settings cannot trigger recovery', async () => {
  const f=crossWebFixture(['one','two']), oldSecond=deferredSearchReply()
  f.reply('one','old',challenge());f.reply('two','old',oldSecond.promise)
  const oldSearch=f.page.runSearch('old')
  await untilSearch(()=>f.page.webChallengeShown)
  const oldReceipt=f.section('one').webChallenge
  f.reply('one','new',challenge())
  f.reply('two','new',new SourceRuntimeError({ok:false,error:{code:'http_error',status:403}}))
  const newSearch=f.page.runSearch('new')
  f.page.finishWebChallengeDismiss();await newSearch
  const next=f.section('one').webChallenge
  assert.ok(next.id>oldReceipt.id)
  assert.equal(await f.service.completeWebChallenge(oldReceipt,true),false)
  assert.equal(f.section('two').webChallenge,undefined,'plain403 is not a challenge')
  assert.equal(f.service.canRetryWebChallenge(next,true),true)
  f.revisions.set('one',1)
  assert.equal(f.service.canRetryWebChallenge(next,true),false,'settings revision belongs to the original read')
  f.page.chrome.visible=false;f.page.invalidateWebChallenges()
  oldSecond.reject(challenge());await oldSearch
  assert.equal(f.page.webChallengeShown,false)
  assert.equal(f.section('one').webChallenge.id,next.id,'late old aggregate cannot replace new query')
  assert.equal(await f.service.completeWebChallenge(next,true),false)
  assert.equal(f.calls.length,4)
})
