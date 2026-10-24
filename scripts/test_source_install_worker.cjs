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

// Execute the production registry, keeping native filesystem calls observable.
// The import guards and localized-name rules also come from production code.
function persistenceFixture() {
  const importerSource=fs.readFileSync(path.join(root,'sourceRuntime/SourcePackageImporter.ets'),'utf8')
  const tree=ts.createSourceFile('importer',importerSource,ts.ScriptTarget.Latest,true)
  const pattern=tree.statements.filter(ts.isVariableStatement).flatMap(n=>[...n.declarationList.declarations])
    .find(n=>n.name.getText(tree)==='SOURCE_PACKAGE_MIN_APP_VERSION_PATTERN').initializer.getText(tree)
  const guards=functions('sourceRuntime/SourcePackageImporter.ets',
    ['isValidSourcePackageMinAppVersion','normalizeSourceOperationCapabilityToken','normalizeSourceOperationCapabilityTokens','validSourceWebSessionOrigins','normalizeSourceHomepage'],
    {SOURCE_PACKAGE_MIN_APP_VERSION_PATTERN:new Function('return ('+pattern+')')(),url:{URL:class extends URL {static parseURL(value){return new URL(value)}}}})
  function evaluate(file,requireModule) {
    const code=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{
      compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
    const exports={};new Function('exports','require',code)(exports,requireModule);return exports
  }
  const names=evaluate('sourceRuntime/SourceLocalizedNames.ets',()=>{throw Error('unexpected name dependency')})
  const files=new Map(),reads=[],writes=[];let writeFails=false
  const nativeFs={OpenMode:{READ_ONLY:0},accessSync:p=>p==='/files'||files.has(p),
    readTextSync:p=>files.get(p),statSync:p=>({size:files.get(p).length}),openSync:p=>({fd:p}),closeSync:()=>{},
    readSync:(fd,buffer)=>{reads.push(fd);const bytes=files.get(fd);new Uint8Array(buffer).set(bytes);return bytes.length},
    mkdirSync:()=>{throw Error('unexpected directory creation')}}
  const api=evaluate('sourceRuntime/SourceRuntimeRegistry.ets',name=>{
    if(name==='@kit.CoreFileKit')return {fileIo:nativeFs,fileUri:{getUriFromPath:p=>'file://'+p}}
    if(name==='./SourceLocalizedNames')return names
    if(name==='./SourcePackageImporter')return {...guards,SOURCE_REPO_PACKAGE_WASM_FILE:'source.wasm'}
    if(name==='../model/AppFileTextPersistence')return {writeAppTextFile:(p,text)=>{if(writeFails)throw Error('disk');writes.push({path:p,metadata:JSON.parse(text)});files.set(p,text)}}
    throw Error('unexpected registry dependency '+name)
  })
  const registry=new api.SourceRuntimeRegistry()
  function add(id,{status='imported',archive='/packages/'+id+'.koma',enabled=true}={}) {
    const bytes=new Uint8Array([1,2,3]);files.set('/packages/'+id+'.wasm',bytes)
    const input={sourceId:id,route:'source',importStatus:status,enabled,hashOk:true,network:false,wasmBytes:bytes,
      wasmPath:'/packages/'+id+'.wasm',archivePath:archive,capabilities:['sourceInfo','pages'],
      manifest:{package:{id,name:id,version:'0.1.0',language:'zh-Hant',type:'manga',nsfw:false,
        localizedNames:{'zh-Hans':'示例'},minAppVersion:'0.1.0'},
        permissions:{network:false,hostImports:[],webSessionOrigins:['https://example.org']}}}
    assert.equal(registry.register(input).ok,true);return input
  }
  return {registry,add,files,reads,writes,api,guards,names,set writeFails(value){writeFails=value}}
}
test('installed projection retains the exact existing metadata while excluding staged, unarchived and removed sources',()=>{
  const f=persistenceFixture();f.add('keep',{enabled:false});f.add('removed');f.add('staged',{status:'staged'});f.add('unarchived',{archive:undefined})
  // Explicitly represent an admitted source without an archive (the normal helper supplies one).
  f.registry.lookup('unarchived').entry.archivePath=undefined
  const expected=persistenceFixture();expected.add('keep',{enabled:false});expected.registry.persistToAppLocalMetadata('/files/registry.json')
  const before=f.registry.list().slice()
  const result=f.registry.persistImportedToAppLocalMetadata('/files/registry.json','removed')
  assert.equal(result.ok,true);assert.equal(result.persistedSourceCount,1)
  assert.deepEqual(f.writes,expected.writes);assert.deepEqual(f.reads,['/packages/keep.wasm'])
  assert.deepEqual(f.registry.list(),before);assert.equal(f.registry.lookup('keep').entry,before[0])
  assert.equal(f.writes[0].metadata.entries[0].enabled,false)
})
for(const failure of ['missingPath','missingFile','wrongSize'])test('installed projection retains '+failure+' validation before writing',()=>{
  const f=persistenceFixture();f.add('one');const entry=f.registry.lookup('one').entry
  if(failure==='missingPath')entry.wasmPath=undefined
  if(failure==='missingFile')f.files.delete(entry.wasmPath)
  if(failure==='wrongSize')f.files.set(entry.wasmPath,new Uint8Array([1,2]))
  const result=f.registry.persistImportedToAppLocalMetadata('/files/registry.json')
  assert.equal(result.ok,false);assert.equal(result.reasonCode,{missingPath:'missing_wasm_path',missingFile:'wasm_missing',wrongSize:'wasm_byte_count_mismatch'}[failure])
  assert.equal(f.writes.length,0);assert.equal(f.registry.count(),1)
})
test('projection write errors propagate to the existing rollback owner without mutating live entries',()=>{
  const f=persistenceFixture();f.add('one');const entry=f.registry.lookup('one').entry;f.writeFails=true
  assert.throws(()=>f.registry.persistImportedToAppLocalMetadata('/files/registry.json'),/disk/)
  assert.equal(f.registry.lookup('one').entry,entry);assert.deepEqual(f.reads,['/packages/one.wasm'])
})
test('app persistence uses the admitted registry projection without reconstructing or hashing all WASM bytes',()=>{
  const calls=[]
  const api=functions(registryFile,['persistInstalledSources'],{
    appSourceRuntimeRegistry:{persistImportedToAppLocalMetadata:(...args)=>{calls.push(args);return {ok:true}}},
    appSourceMetadataPath:()=>'/files/registry.json',
    SourceRuntimeRegistry:class {constructor(){throw Error('duplicate registry')}},
    manifestFromRegistryEntry:()=>{throw Error('recomputed all source hashes')}})
  api.persistInstalledSources({},'removed');assert.deepEqual(calls,[['/files/registry.json','removed']])
})

// Run the real manager method so local imports preserve the same row-update
// boundary as remote installs. No ArkUI rendering is simulated by this check.
function localImportMethod(globals) {
  const source=fs.readFileSync(path.join(root,'pages/SourcePackageManagerPage.ets'),'utf8')
  const tree=ts.createSourceFile('manager',source.replace('export struct SourcePackageManagerPage','export class SourcePackageManagerPage'),ts.ScriptTarget.Latest,true)
  const owner=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='SourcePackageManagerPage')
  const method=owner.members.find(n=>ts.isMethodDeclaration(n)&&n.name.getText(tree)==='importPackage')
  assert.ok(method)
  const code=ts.transpileModule('class Manager {'+method.getText(tree)+'} exports.Manager=Manager',{
    compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
  const exports={};new Function('exports',...Object.keys(globals),code)(exports,...Object.values(globals))
  return exports.Manager
}
for(const outcome of ['installed','cancelled','failed','exception'])test('local archive '+outcome+' retains its declared update boundary',async()=>{
  const events=[],pending=deferred()
  const Manager=localImportMethod({t:k=>k,tf:(k,r)=>k+':'+r,
    pickSourcePackageArchive:async()=>outcome==='cancelled'?undefined:'picked.koma',
    installFromArchive:()=>pending.promise})
  const manager=new Manager();manager.busy=false;manager.context=()=>({});manager.showToast=()=>{}
  manager.sourceReasonText=x=>x;manager.reload=()=>events.push('reload')
  manager.refreshInstalledPackage=id=>events.push('single:'+id)
  const work=manager.importPackage();await new Promise(setImmediate)
  if(outcome!=='cancelled'){
    assert.equal(manager.busy,true);assert.deepEqual(events,[])
    if(outcome==='exception')pending.reject(Error('read'))
    else pending.resolve(outcome==='installed'?{ok:true,id:'one'}:{ok:false,reasonCode:'invalid'})
  }
  await work;assert.equal(manager.busy,false)
  assert.deepEqual(events,outcome==='installed'?['single:one']:outcome==='cancelled'?[]:['reload'])
})


test('declared homepage survives real registry persistence/reload while session origins remain unchanged',()=>{
  const f=persistenceFixture(), input=f.add('one')
  f.registry.remove('one');input.manifest.package.homepage='https://website.example/comics/?type=all#list'
  assert.equal(f.registry.register(input).ok,true)
  const before=f.registry.lookup('one').entry
  assert.equal(f.registry.listInstalledSourceSummaries()[0].homepage,input.manifest.package.homepage)
  assert.equal(f.registry.persistImportedToAppLocalMetadata('/files/registry.json').ok,true)
  const result=f.api.SourceRuntimeRegistry.reloadFromAppLocalMetadata('/files/registry.json')
  assert.equal(result.ok,true);const after=result.registry.lookup('one').entry
  assert.equal(after.packageHomepage,before.packageHomepage)
  assert.deepEqual(after.webSessionOrigins,['https://example.org'])
  assert.equal(after.network,false);assert.equal(after.enabled,before.enabled)
  // The old metadata shape remains reloadable; invalid optional navigation metadata is ignored.
  const document=f.writes[0].metadata
  delete document.entries[0].packageHomepage;f.files.set('/files/registry.json',JSON.stringify(document))
  assert.equal(f.api.SourceRuntimeRegistry.reloadFromAppLocalMetadata('/files/registry.json').ok,true)
  document.entries[0].packageHomepage='javascript:alert(1)';f.files.set('/files/registry.json',JSON.stringify(document))
  const legacy=f.api.SourceRuntimeRegistry.reloadFromAppLocalMetadata('/files/registry.json')
  assert.equal(legacy.ok,true);assert.equal(legacy.registry.lookup('one').entry.packageHomepage,undefined)
})

test('flat package homepage survives import normalization and backup projection without adding permissions',()=>{
 const f=persistenceFixture()
 const parser=functions('sourceRuntime/SourcePackageImporter.ets',[
  'isPlainObject','nonEmptyString','optionalPackageMetadataText','packageMetadataValueInvalid',
  'optionalBoolean','optionalNumber','optionalStringArray','parseSourceRepoPackageManifest'],{
   ...f.guards,...f.names,SOURCE_PACKAGE_WASM_MAX_BYTES:131072,SOURCE_REPO_PACKAGE_WASM_FILE:'source.wasm'})
 const raw={id:'one',name:'One',version:'0.1.0',lang:'zh',homepage:'https://website.example/comics/?type=all#latest'}
 const manifest=parser.parseSourceRepoPackageManifest(JSON.stringify(raw),3)
 assert.equal(manifest.package.homepage,raw.homepage);assert.deepEqual(manifest.permissions.webSessionOrigins,[])
 assert.equal(manifest.permissions.network,false)
 for(const homepage of [undefined,42,'javascript:alert(1)']){
  const legacy=parser.parseSourceRepoPackageManifest(JSON.stringify({...raw,homepage}),3)
  assert.ok(legacy);assert.equal(legacy.package.homepage,undefined)
 }
 const input=f.add('one');f.registry.remove('one');input.manifest=manifest
 assert.equal(f.registry.register(input).ok,true)
 const backup=functions(registryFile,['manifestWasmPathFromRegistryEntry','manifestFromRegistryEntry'],{
  ...f.guards,...f.names,SOURCE_REPO_PACKAGE_WASM_FILE:'source.wasm',SOURCE_PACKAGE_WASM_FILE:'fixture.wasm',sha256Hex:()=>''})
 const restored=backup.manifestFromRegistryEntry(f.registry.lookup('one').entry)
 assert.equal(restored.package.homepage,raw.homepage);assert.deepEqual(restored.permissions.webSessionOrigins,[])
})
