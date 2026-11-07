const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || 'typescript')

test('JM signed API calls share three-per-two-second window per origin only', async () => {
  let now = 0
  const timers = [], exports = {}
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/sourceRuntime/SourceRequestPolicy.ets'), 'utf8')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  new Function('exports', 'require', 'Date', 'setTimeout', js)(exports, name => name === '@kit.ArkTS' ? { url: { URL } } : {},
    { now: () => now }, (fn, ms) => timers.push({ fn, due: now + ms }))
  const flush = async () => { for (let i=0;i<15;i++) await Promise.resolve() }
  const advance = async t => { now=t; for(const timer of timers.splice(0)) timer.due<=now?timer.fn():timers.push(timer); await flush() }
  const src='com.jmcomic.koma', signed={Token:'abc',Tokenparam:'123,2.1.12'}
  const call={}
  await exports.waitForSourceRequestSlot(src,'https://server-list.example/file',undefined,{},call)
  assert.equal(call.jmAdmitted,undefined)
  await exports.waitForSourceRequestSlot(src,'https://dynamic.example/album',undefined,signed,call)
  await exports.waitForSourceRequestSlot(src,'https://other.example/redirect',undefined,signed,call)
  for(let i=0;i<2;i++) await exports.waitForSourceRequestSlot(src,'https://dynamic.example/album',undefined,signed)
  let released=false
  const fourth=exports.waitForSourceRequestSlot(src,'https://dynamic.example/search',undefined,{token:'x',tokenparam:'y'}).then(()=>{released=true})
  await flush();assert.equal(released,false)
  for(const [id,url,headers] of [
    [src,'https://other.example/album',signed], [src,'https://dynamic.example/image',{}],
    [src,'https://dynamic.example/album',{Token:'a'}], ['other','https://dynamic.example/album',signed],
    [src,'http://dynamic.example/album',signed], [src,'https://server-list.example/file',{}],
  ]) await exports.waitForSourceRequestSlot(id,url,undefined,headers)
  await advance(1999);assert.equal(released,false)
  await advance(2000);await fourth;assert.equal(released,true)
  for(let i=0;i<2;i++) await exports.waitForSourceRequestSlot(src,'https://dynamic.example/album',undefined,signed)
  let current=true
  const cancelledCall={}
  const cancelled=exports.waitForSourceRequestSlot(src,'https://dynamic.example/album',()=>current,signed,cancelledCall)
  const rejected=assert.rejects(cancelled,/source_request_cancelled/)
  await flush();current=false
  const next=exports.waitForSourceRequestSlot(src,'https://dynamic.example/album',undefined,signed)
  await advance(4000);await rejected;await next;assert.equal(cancelledCall.jmAdmitted,undefined)
})

test('HC limits exact main hostname across paths and ports, without limiting CDN or other sources', async () => {
  const exports = {}
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/sourceRuntime/SourceRequestPolicy.ets'), 'utf8')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  new Function('exports', 'require', js)(exports, name => name === '@kit.ArkTS' ? { url: { URL } } : {})
  const src='com.hentaiclub.koma', start=Date.now()
  await exports.waitForSourceRequestSlot(src,'https://www.hentaiclub.net/page')
  await exports.waitForSourceRequestSlot(src,'https://www.hentaiclub.net/image.jpg')
  let released=false
  const third=exports.waitForSourceRequestSlot(src,'http://www.hentaiclub.net:8080/other').then(()=>{released=true})
  await exports.waitForSourceRequestSlot(src,'https://cdn.hentaiclub.net/image.jpg')
  await exports.waitForSourceRequestSlot(src,'https://hentaiclub.net/page')
  await exports.waitForSourceRequestSlot('other','https://www.hentaiclub.net/page')
  assert.equal(released,false)
  await third
  assert.ok(Date.now()-start >= 950)
})

test('WNACG mirrors share 50/minute and each redirected HTTP call pays once', async () => {
  let now=0
  const timers=[],exports={}
  const source=fs.readFileSync(path.join(__dirname,'../entry/src/main/ets/sourceRuntime/SourceRequestPolicy.ets'),'utf8')
  const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
  new Function('exports','require','Date','setTimeout',js)(exports,name=>name==='@kit.ArkTS'?{url:{URL}}:{},
    {now:()=>now},(fn,ms)=>timers.push({fn,due:now+ms}))
  const flush=async()=>{for(let i=0;i<20;i++) await Promise.resolve()}
  const advance=async t=>{now=t;for(const x of timers.splice(0)) x.due<=now?x.fn():timers.push(x);await flush()}
  const src='com.wnacg.koma',call={}
  await exports.waitForSourceRequestSlot(src,'https://external.example/redirect',undefined,undefined,call)
  assert.equal(call.wnacgAdmitted,undefined)
  await exports.waitForSourceRequestSlot(src,'https://www.wnacg.buzz/page',undefined,undefined,call)
  for(let i=0;i<49;i++) await exports.waitForSourceRequestSlot(src,'https://wn123.example/page')
  await exports.waitForSourceRequestSlot(src,'https://wnacgextra.example/redirect',undefined,undefined,call)
  await exports.waitForSourceRequestSlot(src,'https://cdn.wnacg.buzz/image')
  await exports.waitForSourceRequestSlot('other','https://wn123.example/page')
  let current=true
  const denied=exports.waitForSourceRequestSlot(src,'https://wnacg.buzz/a',()=>current,undefined,{})
  const rejected=assert.rejects(denied,/source_request_cancelled/)
  let passed=false
  const next=exports.waitForSourceRequestSlot(src,'https://www.wn123.example/b',undefined,undefined,{}).then(()=>{passed=true})
  await flush();assert.equal(passed,false);current=false
  await advance(59999);assert.equal(passed,false)
  await advance(60000);await rejected;await next;assert.equal(passed,true)
})

test('Xiutaku shares one 10/s main-host window and leaves its image CDN independent', async () => {
  let now = 0
  const timers = [], exports = {}
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/sourceRuntime/SourceRequestPolicy.ets'), 'utf8')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  new Function('exports', 'require', 'Date', 'setTimeout', js)(exports, name => name === '@kit.ArkTS' ? { url: { URL } } : {},
    { now: () => now }, (fn, ms) => timers.push({ fn, due: now + ms }))
  const call = {}, sourceId = 'com.xiutaku.koma'
  const wait = (url, admission, id = sourceId) => exports.waitForSourceRequestSlot(id, url, undefined, undefined, admission)
  const main = 'https://xiutaku.com'
  await wait(main + '/hot', call)
  await wait(main + '/hot?start=20', call)
  for (let i = 0; i < 9; i++) await wait(main + '/' + i)
  let allowed = false
  const queued = wait(main + '/?search=x').then(() => { allowed = true })
  await wait('https://i.xiutaku.com/cover.webp')
  await wait(main + '/different-source', undefined, 'other')
  assert.equal(allowed, false)
  assert.deepEqual(timers.map(timer => timer.due), [1000])
  now = 1000; timers.shift().fn()
  await queued
  assert.equal(allowed, true)
})
