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
