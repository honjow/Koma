const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function functions(file, names, globals) {
  const source = fs.readFileSync(path.join(root, file), 'utf8')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const declarations = names.map(name => {
    const node = tree.statements.find(n => ts.isFunctionDeclaration(n) && n.name?.text === name)
    assert.ok(node, name)
    return node.getText(tree).replace(/^export /, '')
  }).join('\n')
  const code = ts.transpileModule(declarations + `\nObject.assign(exports,{${names.join(',')}})`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exports = {}
  new Function('exports', ...Object.keys(globals), code)(exports, ...Object.values(globals))
  return exports
}
const registryFile = 'sourceRuntime/SourceRuntimeAppRegistry.ets'
const response = { ok: true, operation: 'source_info', data: { capabilities: { search: true, pages: true } } }
function deferred() { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b }); return {promise,resolve,reject} }
function installFixture() {
  const probe = deferred(), events = [], old = {sourceId:'one',enabled:false,archivePath:'/packages/old/source.koma'}, other = {sourceId:'other'}
  let entries=[other,old], persistFails=false, registerFails=false, next
  const registry={ list:()=>entries.slice(), lookup:id=>({entry:entries.find(e=>e.sourceId===id)}),
    remove:id=>{const e=entries.find(e=>e.sourceId===id);events.push('remove:'+id);entries=entries.filter(e=>e.sourceId!==id);return e},
    register:(entry,index)=>{events.push('register');next=entry;if(registerFails)return {ok:false,reasonCode:'register_failed'};entries.splice(index,0,entry);return {ok:true}} }
  const globals={appSourceRuntimeRegistry:registry, ensureDirSync:()=>{},appSourceRoot:()=>'/files',appSourcePackagesRoot:()=>'/packages',joinSourceRuntimePath:(a,b)=>a+'/'+b,writeBytesSync:()=>{},
    importLocalSourceArchive:async()=>({ok:true,manifest:{package:{id:'one',name:'One',minAppVersion:'0'}},wasmBytes:new Uint8Array([1,2]),hashOk:true}),
    removeAppSourcePackageDir:async(_c,p)=>{events.push('delete:'+p)},isSourcePackageMinAppVersionSatisfied:()=>true,
    runSourceOperationFromValidatedBytesAsync:async(request,bytes)=>{const r=JSON.parse(request);assert.equal(r.operation,'source_info');assert.deepEqual(r.settings,{});assert.equal(r.hostHints.network,false);assert.equal(registry.lookup('one').entry,old);events.push('probe');return probe.promise},
    IMPORTED_SOURCE_ROUTE:'imported', DiagnosticLogger:{error(){},info(){}},persistInstalledSources:()=>{events.push('persist');if(persistFails)throw Error('disk')},
    restoreRuntimeRegistryEntry:(entry,index)=>{events.push('restore');if(entry&&!entries.some(e=>e.sourceId===entry.sourceId))entries.splice(index,0,entry)},
    SourceRuntimeStateBridge:{notifyChanged:()=>events.push('notify')},Date }
  const api=functions(registryFile,['sourceInfoCapabilityToken','detectSourceRuntimeCapabilities','registerSourcePackageFromBytes','installFromBytes'],{...globals,BackupRestoreActivity:{runWrite:async work=>work()}})
  return {api,probe,events,old,registry,set persistFails(v){persistFails=v},set registerFails(v){registerFails=v},get next(){return next}}
}
test('validated bytes use the existing worker executor, copied bytes and no HTTP identity',async()=>{
  const pending=deferred(), original=new Uint8Array([7,8]);let call, executed=0
  const executor=()=>{executed++}
  const api=functions('sourceRuntime/SourceRuntimeService.ets',['runSourceOperationFromValidatedBytesAsync'],{taskpool:{execute:(...args)=>{call=args;return pending.promise}},executeRegisteredSourceRequest:executor})
  const running=api.runSourceOperationFromValidatedBytesAsync('request',original)
  assert.equal(call[0],executor);assert.notEqual(call[2],original);assert.deepEqual(Array.from(call[2]),[7,8]);assert.equal(call[3],'');assert.equal(executed,0)
  original[0]=9;assert.equal(call[2][0],7);pending.resolve(JSON.stringify(response));assert.deepEqual(await running,response)
})
test('old source remains visible while probing; latest disabled state and position survive replacement',async()=>{
  const f=installFixture(), running=f.api.registerSourcePackageFromBytes({},new Uint8Array([1]),'source.koma','one','/packages/new')
  await new Promise(setImmediate);assert.deepEqual(f.events,['probe']);assert.equal(f.registry.lookup('one').entry,f.old)
  f.old.enabled=true;f.probe.resolve(response);assert.equal((await running).ok,true)
  assert.equal(f.registry.list()[1],f.next);assert.equal(f.next.enabled,true);assert.deepEqual(f.next.capabilities,['sourceInfo','search','pages'])
  assert.ok(f.events.indexOf('persist')<f.events.indexOf('delete:/packages/old'));assert.equal(f.events.at(-1),'notify')
})
test('disabled stays disabled and failed capability probe preserves the prior fallback semantics',async()=>{
  const f=installFixture(), running=f.api.registerSourcePackageFromBytes({},new Uint8Array([1]),'source.koma','one','/packages/new')
  await new Promise(setImmediate);f.probe.reject(Error('worker unavailable'));assert.equal((await running).ok,true)
  assert.equal(f.next.enabled,false);assert.equal(f.next.capabilities,undefined)
})
for(const failure of ['register','persist'])test(failure+' failure restores old position and never deletes old package',async()=>{
  const f=installFixture();if(failure==='register')f.registerFails=true;else f.persistFails=true
  const running=f.api.registerSourcePackageFromBytes({},new Uint8Array([1]),'source.koma','one','/packages/new')
  await new Promise(setImmediate);f.probe.resolve(response);assert.equal((await running).ok,false)
  assert.equal(f.registry.list()[1],f.old);assert.ok(f.events.includes('delete:/packages/new'));assert.ok(!f.events.includes('delete:/packages/old'));assert.ok(!f.events.includes('notify'))
})
test('writer admission stays held across capability await and releases on success',async()=>{
  const f=installFixture();let writers=0
  // Execute the real install wrapper and real registration; only the activity gate is observed.
  const api=functions(registryFile,['installFromBytes'],{BackupRestoreActivity:{runWrite:async work=>{writers++;try{return await work()}finally{writers--}}},DiagnosticLogger:{info(){}},registerSourcePackageFromBytes:f.api.registerSourcePackageFromBytes})
  const running=api.installFromBytes({},new Uint8Array([1]),'source.koma','one');await new Promise(setImmediate);assert.equal(writers,1)
  f.probe.resolve(response);assert.equal((await running).ok,true);assert.equal(writers,0)
})
test('single installed lookup preserves disabled metadata without enumerating every package',()=>{
  const entry={sourceId:'one',enabled:false};let reads=0
  const api=functions(registryFile,['getInstalledSourcePackage'],{appSourceRuntimeRegistry:{lookup:id=>({entry:id==='one'?entry:undefined}),list:()=>{throw Error('full list')}},sourcePackageFromEntry:e=>{reads++;return {id:e.sourceId,enabled:e.enabled}}})
  assert.deepEqual(api.getInstalledSourcePackage('one'),{id:'one',enabled:false});assert.equal(reads,1);assert.equal(api.getInstalledSourcePackage('missing'),undefined);assert.equal(reads,1)
})

const settingsResponseOk = functions('sourceRuntime/SourceRuntimeService.ets', ['sourceRuntimeRequestResponseOk'], {}).sourceRuntimeRequestResponseOk
const settingsReply = data => ({ok:true,operation:'get_settings',data,hostHints:{network:false}})
test('real source empty and nonempty settings do not need fixture-only content',()=>{
  for(const data of [{settings:[]},{settings:[{id:'region'}]},{items:[]}]) {
    assert.equal(settingsResponseOk('get_settings',settingsReply(data)),true)
  }
})
test('settings response validation retains operation, network and array-shape boundaries',()=>{
  const valid=settingsReply({settings:[]})
  for(const reply of [{...valid,ok:false},{...valid,operation:'search'},
    {...valid,hostHints:{network:true}},{...valid,hostHints:undefined},
    settingsReply({}),settingsReply({settings:'invalid'})]) {
    assert.equal(settingsResponseOk('get_settings',reply),false)
  }
})
