// Execute production ArkTS lifecycle methods with controlled Web persistence.
// This does not render ArkUI or prove native sheet animation/device behavior.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = path.join(__dirname, '../entry/src/main/ets')

function loadClass(source, mocks) {
  const exports = {}
  const javascript = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS },
  }).outputText
  vm.runInNewContext(javascript, { exports, Error, ...mocks })
  return exports
}

function sheetFixture() {
  let resolveSave
  let failSyncSave = false
  const calls = { completes: [], events: [], closes: 0, toasts: [] }
  const controller = {
    getCustomUserAgent: () => '', getUserAgent: () => 'ActualUA',
    getUrl: () => 'https://site.invalid/', loadUrl: () => {},
    accessBackward: () => false, accessForward: () => false,
  }
  const input = fs.readFileSync(path.join(base, 'components/SourceWebSessionSheet.ets'), 'utf8')
  // Remove only the UI DSL and ArkUI annotations; execute original method bodies.
  const source = (input.slice(0, input.indexOf('  build() {')) + '}\n')
    .replace(/^import .*\n/gm, '').replace('@ComponentV2', '')
    .replace('export struct', 'export class')
    .replace(/^  @Monitor\([^\n]+\)\n/gm, '').replace(/@(Param|Event|Local) /g, '')
  const { SourceWebSessionSheet } = loadClass(source, {
    webview: {
      WebviewController: function () { return controller },
      WebCookieManager: {
        saveCookieSync: () => { if (failSyncSave) throw Error('sync unavailable') },
        saveCookieAsync: () => new Promise(resolve => { resolveSave = resolve }),
      },
    },
    appSourceWebSessionStore: {
      complete: (sourceId, sessionId, url, ua) => {
        calls.completes.push({ sourceId, sessionId, url, ua })
        return { sourceId, sessionId, state: 'available' }
      },
    },
    connectLayoutSafeArea: () => ({ bottomAvoidHeight: 0 }),
    DiagnosticLogger: { info: () => {} },
    cancelSourceWebProbe: () => {},
    AppStrings: { get: key => key }, mangaHttpUrl: value => value,
  })
  const sheet = new SourceWebSessionSheet()
  sheet.params = { url: 'https://site.invalid/', title: 'test',
    sourceSession: { sourceId: 's', sessionId: 'one' } }
  sheet.onCompleted = status => calls.events.push(status)
  sheet.onClose = () => { calls.closes++ }
  sheet.getUIContext = () => ({ getPromptAction: () => ({
    showToast: value => calls.toasts.push(value),
  }) })
  sheet.aboutToAppear()
  sheet.loadInitialPage()
  sheet.loading = false
  return { sheet, calls, useAsyncSave: () => { failSyncSave = true }, finishSave: () => resolveSave() }
}

test('sheet completes once, preserving actual URL and user agent', async () => {
  const f = sheetFixture()
  await f.sheet.completeSourceSession()
  await f.sheet.completeSourceSession()
  assert.deepEqual(f.calls.completes, [{ sourceId: 's', sessionId: 'one',
    url: 'https://site.invalid/', ua: 'ActualUA' }])
  assert.equal(f.calls.events.length, 1)
  assert.equal(f.calls.events[0].state, 'available')
})

test('closing during asynchronous cookie save does not complete or notify', async () => {
  const f = sheetFixture(); f.useAsyncSave()
  const pending = f.sheet.completeSourceSession()
  f.sheet.close(); f.finishSave(); await pending
  assert.equal(f.calls.completes.length, 0)
  assert.equal(f.calls.events.length, 0)
  assert.equal(f.calls.closes, 1)
  assert.equal(f.calls.toasts.length, 0)
})

test('unmount during asynchronous cookie save invalidates completion', async () => {
  const f = sheetFixture(); f.useAsyncSave()
  const pending = f.sheet.completeSourceSession()
  f.sheet.aboutToDisappear(); f.finishSave(); await pending
  assert.equal(f.calls.completes.length, 0)
  assert.equal(f.calls.events.length, 0)
})

test('replacement session cannot inherit the previous asynchronous completion', async () => {
  const f = sheetFixture(); f.useAsyncSave()
  const pending = f.sheet.completeSourceSession()
  f.sheet.params = { ...f.sheet.params, sourceSession: { sourceId: 's', sessionId: 'two' } }
  f.sheet.sessionChanged(); f.finishSave(); await pending
  assert.equal(f.calls.completes.length, 0)
  assert.equal(f.calls.events.length, 0)
  assert.equal(f.sheet.completing, false)
})

test('concurrent completion taps share a single pending save', async () => {
  const f = sheetFixture(); f.useAsyncSave()
  const pending = f.sheet.completeSourceSession()
  await f.sheet.completeSourceSession()
  f.finishSave(); await pending
  assert.equal(f.calls.completes.length, 1)
  assert.equal(f.calls.events.length, 1)
})

test('loading page cannot complete', async () => {
  const f = sheetFixture(); f.sheet.loading = true
  await f.sheet.completeSourceSession()
  assert.equal(f.calls.completes.length, 0)
  assert.equal(f.calls.events.length, 0)
})

test('missing source session cannot complete', async () => {
  const f = sheetFixture(); f.sheet.params.sourceSession = undefined
  await f.sheet.completeSourceSession()
  assert.equal(f.calls.completes.length, 0)
  assert.equal(f.calls.events.length, 0)
})

for (const pageName of ['SourceBrowsePage', 'SourceSearchPage']) {
  test(`${pageName}: old dismissal cannot cancel a newly queued challenge`, () => {
    const input = fs.readFileSync(path.join(base, `pages/${pageName}.ets`), 'utf8')
    const start = input.indexOf('  private handleWebChallenge()')
    const end = input.indexOf('  @Builder\n  private WebChallengeSheet()', start)
    if (start < 0 || end < 0) throw Error('production lifecycle methods not found')
    const methods = input.slice(start, end)
    const canceled = []
    let sessionSequence = 0
    const { Page } = loadClass(`export class Page { ${methods} }`, {
      prepareSourceWebSession: () => ({ url: 'https://site.invalid/', title: 'test',
        sourceSession: { sourceId: 's', sessionId: String(++sessionSequence) } }),
      appSourceWebSessionStore: { cancel: (_source, id) => canceled.push(id) },
    })
    const page = new Page()
    const scope = pageName === 'SourceBrowsePage' ? 'browse' : 'search'
    const receiptField = `${scope}WebChallenge`
    page.chrome = { visible: true }
    page.source = { sourceId: 's' }
    page.currentSource = () => ({ sourceId: 's' })
    page.isSearchActive = () => false
    page.viewModel = { [receiptField]: { scope, sourceId: 's', id: 1 },
      claimWebChallenge: () => true, cancelWebChallenge: () => {} }
    page.handleWebChallenge()
    assert.equal(page.webChallengeParams.sourceSession.sessionId, '1')
    page.closeWebChallenge()
    page.viewModel[receiptField] = { scope, sourceId: 's', id: 2 }
    page.handleWebChallenge()
    assert.equal(page.webChallengeParams.sourceSession.sessionId, '1', 'wait for native dismissal')
    page.finishWebChallengeDismiss()
    assert.equal(page.webChallengeParams.sourceSession.sessionId, '2')
    assert.deepEqual(canceled, ['1'])
    assert.equal(page.webChallengeShown, true)
  })
}


function mangaWebPageFixture() {
  const logs = [], url = 'https://private.invalid/work?token=PRIVATE_TOKEN'
  const controller = {loadUrl:()=>{},getUrl:()=>url,accessBackward:()=>false,accessForward:()=>false}
  const input = fs.readFileSync(path.join(base,'pages/MangaWebPage.ets'),'utf8')
  const source = (input.slice(0,input.indexOf('  build() {'))+'}\n')
    .replace(/^import .*\n/gm,'').replace('@ComponentV2','').replace('export struct','export class')
    .replace(/@(Param|Local) /g,'')
  const trace = {info:(event,detail)=>logs.push({event,detail}),warn:(event,detail)=>logs.push({event,detail}),
    finish:(status,detail)=>logs.push({event:'end',status,detail})}
  const {MangaWebPage} = loadClass(source, {
    webview:{WebviewController:function(){return controller}},Scroller:function(){},
    DiagnosticLogger:{begin:(category,event,detail)=>{logs.push({category,event,detail});return trace}},
    mangaHttpUrl:value=>value,sourceWebOrigin:value=>new URL(value).origin,appSourceWebSessionStore:{cancel:()=>{}},
  })
  const page = new MangaWebPage();page.params={url,title:'PRIVATE_TITLE'};page.loadInitialPage()
  return {page,logs,url}
}

test('ordinary Web diagnostics keep content private and bound progress/resource events without changing loading',()=>{
  const {page,logs,url}=mangaWebPageFixture();page.pageBegan({url})
  for(let value=0;value<=100;value++)page.pageProgress({newProgress:value})
  page.pageVisible({url});page.pageVisible({url})
  for(let i=0;i<20;i++)page.resourceFailed({isMainFrame:()=>false},'http',()=>403)
  page.resourceFailed({isMainFrame:()=>true},'http',()=>500)
  assert.equal(page.loading,true,'visibility/progress/HTTP diagnostics do not end the existing loading state')
  assert.equal(logs.filter(x=>x.event==='progress').length,5)
  assert.equal(logs.filter(x=>x.event==='document_visible').length,1)
  assert.equal(logs.filter(x=>x.event==='resource_failed').length,2)
  page.pageEnded({url});assert.equal(page.loading,false);page.aboutToDisappear()
  assert.equal(logs.at(-1).status,'closed')
  assert.ok(!JSON.stringify(logs).includes('PRIVATE_'));assert.ok(!JSON.stringify(logs).includes('private.invalid'))
})

test('bad Web diagnostic metadata cannot throw into the UI callback and a new document resets only diagnostic limits',()=>{
  const {page,logs,url}=mangaWebPageFixture();page.pageBegan({url})
  assert.doesNotThrow(()=>page.resourceFailed({isMainFrame:()=>false},'transport',()=>{throw Error('PRIVATE_TOKEN')}))
  page.pageProgress({newProgress:NaN});assert.equal(logs.filter(x=>x.event==='progress').length,0)
  page.resourceFailed({isMainFrame:()=>false},'transport',()=>-100)
  page.pageBegan({url});page.resourceFailed({isMainFrame:()=>false},'transport',()=>-100)
  assert.equal(logs.filter(x=>x.event==='resource_failed').length,2)
  assert.equal(page.loading,true);page.aboutToDisappear();assert.equal(logs.at(-1).status,'partial')
  assert.ok(!JSON.stringify(logs).includes('PRIVATE_'))
})


test('document loops log origin relations without URLs and cap the whole navigation operation',()=>{
  const {page,logs,url}=mangaWebPageFixture()
  for(let i=0;i<200;i++){
    page.pageBegan({url:i%2===0?url:'https://other-private.invalid/work'})
    page.pageProgress({newProgress:25});page.pageEnded({url})
  }
  page.aboutToDisappear()
  assert.equal(logs.filter(x=>x.event==='events_suppressed').length,1)
  assert.equal(logs.length,51,'start, 48 bounded stages, one suppression marker and final summary')
  assert.ok(logs.some(x=>x.detail.includes('matchesInitialUrl=true sameInitialOrigin=true')))
  assert.ok(logs.some(x=>x.detail.includes('matchesInitialUrl=false sameInitialOrigin=false')))
  assert.ok(logs.at(-1).detail.includes('revision=200'))
  assert.ok(logs.at(-1).detail.includes('stageEvents=600'))
  assert.ok(!JSON.stringify(logs).includes('private.invalid'))
})
