const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function subject(file, owner, methods, globals) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.getText(tree) === owner)
  const body = methods.map(name => cls.members.find(n => n.name?.getText(tree) === name).getText(tree)).join('\n')
  const exports = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject {${body}}`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, console, ...globals })
  return new exports.Subject()
}
const entry = id => ({ id, name: id, version: '1', icon: `${id}.png` })
const globals = {
  resolveIndexDocumentUrl: value => value,
  entryWithCachedIcon: (entry, iconUri) => ({ ...entry, iconUri }),
  SOURCE_INDEX_ICON_FETCH_CONCURRENCY: 4,
  SourceIdentityIconState: class { uri = '' },
  DiagnosticLogger: { info() {}, error() {}, warn() {} },
}

test('usable index metadata returns without waiting for any icon download', async () => {
  let iconFetches = 0, destroyed = false
  const service = subject('sourceRuntime/SourceIndexService.ets', 'SourceIndexService', ['fetchIndex'], {
    ...globals, isValidHttpUrl: () => true, parseIndexEntriesDocument: value => value,
    parseIndexEntry: value => value, safeResolveIndexAssetUrl: (_url, icon) => icon,
    http: { RequestMethod: { GET: 'GET' }, HttpDataType: { STRING: 'string' }, createHttp: () => ({
      async request() { return { responseCode: 200, result: JSON.stringify([entry('A'), entry('B')]) } },
      destroy() { destroyed = true },
    }) },
  })
  service.beginMetadataRequest = () => 1
  service.persistIndexMetadata = async () => {}
  service.cachedIconUriFor = () => { iconFetches++; return new Promise(() => {}) }
  const result = await service.fetchIndex('https://index.test/index.json')
  assert.equal(result.ok, true)
  assert.equal(result.entries.map(e => e.id).join(','), 'A,B')
  assert.equal(iconFetches, 0)
  assert.equal(destroyed, true)
})

test('one slow icon does not hold the next batch; every ready icon publishes independently within four workers', async () => {
  const service = subject('sourceRuntime/SourceIndexService.ets', 'SourceIndexService', ['loadIndexIcons'], globals)
  const pending = new Map(), published = []
  let active = 0, maxActive = 0
  service.cachedIconUriFor = (_url, item) => new Promise(resolve => {
    active++; maxActive = Math.max(maxActive, active)
    pending.set(item.id, () => { active--; resolve(`file://${item.id}.png`) })
  })
  const running = service.loadIndexIcons('https://index.test/index.json',
    ['A','B','C','D','E'].map(entry), item => published.push(item.id), () => true)
  assert.equal(active, 4)
  pending.get('B')()
  await new Promise(setImmediate)
  assert.equal(published.join(','), 'B')
  assert.equal(pending.has('E'), true)
  for (const id of ['A','C','D','E']) pending.get(id)()
  await running
  assert.equal(maxActive, 4)
  assert.equal([...published].sort().join(','), 'A,B,C,D,E')
})

test('changing the index retires old icon callbacks without overwriting the new list', async () => {
  let callback
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['showIndexEntries', 'setSourceIndexUrl'], { ...globals, tf: (_key, count) => String(count) })
  Object.assign(manager, {
    sourceIndexUrl: 'https://old.test/index.json', indexLoadRevision: 1, indexDisplayRevision: 0, savedIndexLoadRevision: 0,
    sortedIndexEntries: entries => entries,
    sourceIndexService: { loadIndexIcons: async (_url, _entries, onReady) => { callback = onReady } },
  })
  manager.showIndexEntries(manager.sourceIndexUrl, [entry('A')], 1)
  manager.setSourceIndexUrl('https://new.test/index.json')
  manager.indexEntries = [entry('B')]
  callback({ ...entry('A'), iconUri: 'file://A.png' })
  assert.equal(manager.indexEntries[0].id, 'B')
  manager.showIndexEntries('https://old.test/index.json', [entry('C')], 1)
  assert.equal(manager.indexEntries[0].id, 'B')
})


test('icon completion retains the displayed source metadata and ignores retired publications', () => {
  let publish
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['showIndexEntries', 'setSourceIndexUrl'], { ...globals, tf: (_key, count) => String(count) })
  Object.assign(manager, {
    sourceIndexUrl: 'https://old.test/index.json', indexLoadRevision: 1, indexDisplayRevision: 0, savedIndexLoadRevision: 0,
    sortedIndexEntries: entries => entries,
    sourceIndexService: { loadIndexIcons: async (_url, _entries, onReady) => { publish = onReady } },
  })
  const metadata = [entry('A'), entry('B')]
  manager.showIndexEntries(manager.sourceIndexUrl, metadata, 1)
  publish({ ...metadata[1], iconUri: 'file://B.png' })
  assert.equal(manager.indexEntries, metadata)
  assert.equal(manager.indexEntries[1], metadata[1])
  assert.equal(manager.indexIconStates.B.uri, 'file://B.png')
  publish({ ...metadata[0], version: 'other', iconUri: 'file://wrong.png' })
  assert.equal(manager.indexIconStates.A.uri, '')
  manager.setSourceIndexUrl('https://new.test/index.json')
  publish({ ...metadata[0], iconUri: 'file://late.png' })
  assert.equal(Object.keys(manager.indexIconStates).length, 0)
  assert.equal(manager.indexEntries.length, 0)
})

test('refresh keeps displayed icons until replacements arrive, including changed package versions', () => {
  let publish
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['showIndexEntries', 'setSourceIndexUrl'], { ...globals, tf: (_key, count) => String(count) })
  Object.assign(manager, {
    sourceIndexUrl: 'https://same.test/index.json', indexLoadRevision: 1, indexDisplayRevision: 0, savedIndexLoadRevision: 0,
    sortedIndexEntries: entries => entries,
    sourceIndexService: { loadIndexIcons: async (_url, _entries, onReady) => { publish = onReady } },
  })
  manager.showIndexEntries(manager.sourceIndexUrl, [entry('A'), entry('B')], 1)
  publish({ ...entry('A'), iconUri: 'file://A-old.png' })
  publish({ ...entry('B'), iconUri: 'file://B.png' })
  const state = manager.indexIconStates, a = state.A, b = state.B
  const late = publish
  manager.indexLoadRevision = 2
  const changed = { ...entry('A'), version: '2', icon: 'A-new.png' }
  manager.showIndexEntries(manager.sourceIndexUrl, [changed, entry('B')], 2)
  assert.equal(manager.indexIconStates, state)
  assert.equal(manager.indexIconStates.A, a)
  assert.equal(a.uri, 'file://A-old.png')
  assert.equal(manager.indexIconStates.B, b)
  late({ ...entry('A'), iconUri: 'file://retired.png' })
  assert.equal(a.uri, 'file://A-old.png')
  publish({ ...changed, iconUri: 'file://A-new.png' })
  assert.equal(a.uri, 'file://A-new.png')
  assert.equal(b.uri, 'file://B.png')
  manager.setSourceIndexUrl('https://other.test/index.json')
  manager.showIndexEntries(manager.sourceIndexUrl, [entry('A')], manager.indexLoadRevision)
  assert.notEqual(manager.indexIconStates.A, a)
  assert.equal(manager.indexIconStates.A.uri, '')
})

test('failed explicit refresh preserves the existing metadata, artwork and installed state', async () => {
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', ['fetchIndex'], {
    ...globals, tf: key => key, t: key => key,
  })
  const metadata = [entry('A')], icons = { A: { uri: 'file://A.png' } }, packages = [installed('A', '1')]
  let finish
  Object.assign(manager, {
    sourceIndexUrl: 'https://same.test/index.json', indexLoadRevision: 1, indexDisplayRevision: 0, savedIndexLoadRevision: 0,
    indexFetchBusy: false, indexEntries: metadata, indexIconStates: icons, packages,
    sourceReasonText: reason => reason,
    sourceIndexService: { saveUrl: async () => {}, loadSavedRepositories: async () => [],
      fetchIndex: () => new Promise(resolve => { finish = resolve }) },
  })
  const running = manager.fetchIndex()
  await new Promise(setImmediate)
  assert.equal(manager.indexFetchBusy, true)
  assert.equal(manager.indexEntries, metadata)
  assert.equal(manager.indexIconStates, icons)
  finish({ ok: false, reasonCode: 'network_error', entries: [] })
  await running
  assert.equal(manager.indexFetchBusy, false)
  assert.equal(manager.indexEntries, metadata)
  assert.equal(manager.indexIconStates, icons)
  assert.equal(manager.packages, packages)
})

function packageManager(packages, indexEntries, packageUpdateStatuses = []) {
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', [
    'installedSourceIds', 'installedPackage', 'compareVersion', 'entryDeclaresPackageIcon',
    'needsPackageIdentityIconRepair', 'updateAvailableFor', 'hasUpdate', 'missingIndexEntries',
    'updatableIndexEntries', 'availablePackageUpdates', 'packageListGroups', 'indexVersionText',
  ], { ...globals, compareSourceNames: (left, _id, right) => left.localeCompare(right),
    tf: (_key, local, remote) => `local ${local} / remote ${remote}` })
  Object.assign(manager, { packages, indexEntries, packageUpdateStatuses,
    sourceIndexUrl: 'https://active.test/index.json', indexDisplayName: item => item.name })
  return manager
}
const installed = (id, version, enabled = true) => ({ id, name: id, version, enabled, icon: 'file://installed.png' })
const indexed = (id, version) => ({ ...entry(id), version })
test('source groups contain each installed identity once; updates precede missing and current packages', () => {
  const packages = [installed('A', '1.0'), installed('B', '1.0'), installed('C', '2.0', false)]
  const manager = packageManager(packages, [indexed('A','1.1'), indexed('B','1.0'), indexed('C','1.0'), indexed('D','1.0')])
  const groups = manager.packageListGroups()
  assert.equal(groups.updates.map(c => c.entry.id).join(','), 'A')
  assert.equal(groups.missing.map(e => e.id).join(','), 'D')
  assert.equal(groups.installed.map(e => e.id).join(','), 'B,C')
  assert.equal(groups.installed[1].enabled, false)
  assert.equal(packages.map(e => e.id).join(','), 'A,B,C')
})
test('checked updates retain their actual repository and ignore a stale update after local installation', () => {
  const manager = packageManager([installed('A','1.0'), installed('B','1.0')], [indexed('A','1.1')], [
    { sourceId:'A', status:'update', remoteEntry:indexed('A','1.2'), remoteIndexUrl:'https://other.test/index.json' },
    { sourceId:'B', status:'update', remoteEntry:indexed('B','1.1'), remoteIndexUrl:'https://other.test/index.json' },
  ])
  let groups = manager.packageListGroups()
  assert.equal(groups.updates.length, 2)
  assert.equal(groups.updates[0].entry.version, '1.2')
  assert.equal(groups.updates[0].indexUrl, 'https://other.test/index.json')
  manager.packages = [installed('A','1.2'), installed('B','1.1')]
  groups = manager.packageListGroups()
  assert.equal(groups.updates.length, 0)
  assert.equal(groups.installed.length, 2)
})
test('equal versions print once while a real version change retains both sides', () => {
  const manager = packageManager([installed('A','1.0')], [])
  assert.equal(manager.indexVersionText(indexed('A','1.0')), 'v1.0')
  assert.equal(manager.indexVersionText(indexed('A','1.1')), 'local 1.0 / remote 1.1')
  assert.equal(manager.indexVersionText(indexed('new','1.1')), 'v1.1')
})
test('group update uses its repository and preserves a disabled source through the existing install transaction', async () => {
  const calls = []
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', ['updateInstalledPackage', 'packageInstallPending'], {
    ...globals, tf: key => key, t: key => key, sourceDisplayName: (_id, name) => name,
    setEnabled: (_context, id, value) => calls.push(['enabled', id, value]),
  })
  Object.assign(manager, { updateInstallSourceId:'', indexInstallBusy:false, busy:false, packageInstallTasks:{pendingIds:[]},
    context: () => ({}), refreshInstalledPackage() {}, installedPackage: () => installed('A','1.1',false),
    setUpdateStatus: status => calls.push(['status', status.status]), showToast() {},
    sourceIndexService: { installPackage: async (url, entry) => { calls.push(['install',url,entry.id]); return {ok:true} } },
  })
  await manager.updateInstalledPackage(installed('A','1.0',false), {
    entry:indexed('A','1.1'), indexUrl:'https://other.test/index.json',
  })
  assert.deepEqual(calls, [['install','https://other.test/index.json','A'],['enabled','A',false],['status','latest']])
  assert.equal(manager.updateInstallSourceId, '')
})

function installLane() {
  const queue = subject('sourceRuntime/SourceIndexService.ets', 'SourcePackageInstallTasks', ['run'], {})
  Object.assign(queue, {pendingIds: [], runningId: '', pending: new Map(), tail: Promise.resolve()})
  return queue
}
test('other packages enqueue during an install; one identity shares one result and writes remain serial', async () => {
  const lane = installLane(), starts = []; let finishA, finishB
  const a = lane.run('A', () => new Promise(resolve => {starts.push('A'); finishA = resolve}))
  const b = lane.run('B', () => new Promise(resolve => {starts.push('B'); finishB = resolve}))
  assert.equal(lane.run('A', () => {throw Error('duplicate install')}), a)
  assert.deepEqual(Array.from(lane.pendingIds), ['A','B'])
  await new Promise(setImmediate)
  assert.deepEqual(starts, ['A']); assert.equal(lane.runningId, 'A')
  finishA({ok:true}); await a; await new Promise(setImmediate)
  assert.deepEqual(starts, ['A','B']); assert.equal(lane.runningId, 'B')
  assert.deepEqual(Array.from(lane.pendingIds), ['B'])
  finishB({ok:true}); await b
  assert.equal(lane.pendingIds.length, 0); assert.equal(lane.runningId, '')
})
test('an installation rejection retires that source and does not poison the next queued package', async () => {
  const lane = installLane(); let failA
  const a = lane.run('A', () => new Promise((_resolve,reject) => {failA=reject}))
  const rejected = assert.rejects(a, /network/)
  const b = lane.run('B', async () => ({ok:true}))
  await new Promise(setImmediate); failA(Error('network')); await rejected
  assert.equal((await b).ok, true)
  assert.equal(lane.pendingIds.length,0)
  assert.equal((await lane.run('A', async () => ({ok:true}))).ok,true)
})
test('only queued identities are pending and each action reports its actual running or waiting state', () => {
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['packageInstallPending', 'packageActionLabel'], {t:key=>key})
  manager.packageInstallTasks={pendingIds:['A','B'],runningId:'A'}
  assert.equal(manager.packageInstallPending('A'),true)
  assert.equal(manager.packageInstallPending('B'),true)
  assert.equal(manager.packageInstallPending('C'),false)
  assert.equal(manager.packageActionLabel('A',false),'source_pkg_installing')
  assert.equal(manager.packageActionLabel('B',true),'source_pkg_action_queued')
  assert.equal(manager.packageActionLabel('C',true),'source_pkg_action_update')
})

function settingsCapability(response) {
  const source = fs.readFileSync(path.join(root,'sourceRuntime/SourceSettingsStore.ets'),'utf8')
  const tree = ts.createSourceFile('settings.ets',source,ts.ScriptTarget.Latest,true)
  const fn = tree.statements.find(n=>ts.isFunctionDeclaration(n) && n.name.text==='loadSourceSettingsDescriptorsAsync')
  const output={}
  vm.runInNewContext(ts.transpileModule(fn.getText(tree),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{
    exports:output, runRegisteredSourceRequestByIdAsync:async()=>({response}),
    normalizeSourceSettingDescriptors:r=>r.data?.settings ?? r.data?.items ?? [], Date, JSON, Array,
  })
  return output.loadSourceSettingsDescriptorsAsync({},'source')
}
test('only successful empty settings or explicit unsupported operation establish that no settings exist', async()=>{
  const none=await settingsCapability({ok:true,data:{settings:[]}})
  assert.equal(none.ready,true); assert.equal(none.descriptors.length,0)
  const yes=await settingsCapability({ok:true,data:{settings:[{id:'region'}]}})
  assert.equal(yes.ready,true); assert.equal(yes.descriptors.length,1)
  for (const code of ['unsupported_operation','unsupported','not_implemented','not_supported']) {
    assert.equal((await settingsCapability({ok:false,error:{code}})).ready,true)
  }
  for(const response of [undefined,{ok:false,error:{code:'wasm_call_failed'}},{ok:true,data:{}}]) {
    assert.equal((await settingsCapability(response)).ready,false)
  }
})
test('route settings capability hides an empty source, preserves unknown, and ignores a departed route', async()=>{
  let result={ready:true,descriptors:[]},finish
  const changes=[]
  const host=subject('components/SourceSettingsSheetHost.ets','SourceSettingsSheetHost',
    ['loadAvailability'],{appSourceRuntimeRegistry:{},loadSourceSettingsDescriptorsAsync:()=>result})
  Object.assign(host,{mounted:true,sourceId:'A',onAvailabilityChanged:value=>changes.push(value)})
  await host.loadAvailability(); assert.deepEqual(changes,[false])
  result={ready:false,descriptors:[]}; await host.loadAvailability();assert.deepEqual(changes,[false])
  result=new Promise(resolve=>{finish=resolve});const loading=host.loadAvailability();host.mounted=false
  finish({ready:true,descriptors:[{id:'region'}]});await loading;assert.deepEqual(changes,[false])
})


test('update-all submits merged candidates through per-source actions without a global lock or duplicate installs', async () => {
  const lane = installLane(), calls = [], statuses = [], enabled = []
  const packages = [installed('A','1'), installed('B','1',false), installed('C','1')]
  let finishA
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['updateAllAvailablePackages','updateInstalledPackage','packageInstallPending'], {
      ...globals, t:key=>key, tf:key=>key, sourceDisplayName:(_id,name)=>name,
      setEnabled:(_context,id,value)=>enabled.push([id,value]),
    })
  const candidates = ['A','B','C'].map(id=>({entry:indexed(id,'2'),indexUrl:`https://${id}.test/index.json`}))
  Object.assign(manager, {
    busy:false, packageInstallTasks:lane, indexInstallBusy:true, updateInstallSourceId:'other',
    availablePackageUpdates:()=>candidates,
    installedPackage:id=>packages.find(item=>item.id===id),
    context:()=>({}), refreshInstalledPackage(){}, showToast(){},
    setUpdateStatus:status=>statuses.push([status.sourceId,status.status]),
    sourceIndexService:{installPackage:(url,item)=>lane.run(item.id,async()=>{
      calls.push([item.id,url])
      if(item.id==='A') await new Promise(resolve=>{finishA=resolve})
      if(item.id==='C') return {ok:false,reasonCode:'network_error'}
      packages.find(p=>p.id===item.id).version=item.version
      return {ok:true}
    })},
    sourceRedactedReasonText:()=>'',
  })
  manager.updateAllAvailablePackages()
  manager.updateAllAvailablePackages()
  const tasks = Array.from(lane.pending.values())
  assert.deepEqual(Array.from(lane.pendingIds),['A','B','C'])
  await new Promise(setImmediate)
  assert.deepEqual(calls,[['A','https://A.test/index.json']])
  assert.equal(lane.runningId,'A')
  finishA(); await Promise.all(tasks); await new Promise(setImmediate)
  assert.deepEqual(calls,[['A','https://A.test/index.json'],['B','https://B.test/index.json'],['C','https://C.test/index.json']])
  assert.deepEqual(statuses,[['A','latest'],['B','latest'],['C','failed']])
  assert.deepEqual(enabled,[['B',false]])
  assert.equal(lane.pendingIds.length,0)
})


test('activity summary names the actual running source rather than the last queued request', () => {
  const manager = subject('pages/SourcePackageManagerPage.ets','SourcePackageManagerPage',
    ['packageActivityText'],{t:key=>key,tf:(key,name)=>`${key}:${name}`,sourceDisplayName:(_id,name)=>name})
  Object.assign(manager,{
    packageInstallTasks:{runningId:'A'},
    installedPackage:id=>id==='A'?{id:'A',name:'Active A'}:undefined,
    indexEntries:[{id:'new',name:'New source'}],indexDisplayName:entry=>entry.name,
    statusText:'last completion',
  })
  assert.equal(manager.packageActivityText(),'source_pkg_update_running:Active A')
  manager.packageInstallTasks.runningId='new'
  assert.equal(manager.packageActivityText(),'source_pkg_install_running:New source')
  manager.packageInstallTasks.runningId=''
  assert.equal(manager.packageActivityText(),'last completion')
})

function incrementalManager(oldPackages, getReplacement, load) {
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', [
    'refreshInstalledPackage','reloadInstalledPackageSettings','reloadSettingsDescriptors','settingsAvailabilityText','publishSourceSettings','installedPackage',
  ], { ...globals, getInstalledSourcePackage: getReplacement,
    appSourceRuntimeRegistry: {}, appSourceSettingsStore: {loadForSource:()=>({})},
    loadSourceSettingsDescriptorsAsync: load, t:key=>key, tf:key=>key,
    sourceDisplayName:(_id,name)=>name, compareSourceNames:(left,_id,right)=>left.localeCompare(right),
  })
  Object.assign(manager,{packages:oldPackages,settingsReloadRevision:1,settingsSourceReloads:{},
    settingsDescriptorSnapshot:{},settingsAvailability:{},savedSettingCounts:{},settingsValidationStatuses:[],sourceSheetSourceId:''})
  return manager
}
test('single package install preserves unrelated row identities and only probes its settings',async()=>{
  const a=installed('A','1'),b=installed('B','1'),replacement=installed('A','2'),probed=[]
  const manager=incrementalManager([a,b],()=>replacement,async(_registry,id)=>{probed.push(id);return {ready:true,descriptors:[{id:'new'}]}})
  const bSchema=[{id:'B-option'}];manager.settingsDescriptorSnapshot={B:bSchema}
  manager.refreshInstalledPackage('A');await new Promise(setImmediate)
  assert.equal(manager.installedPackage('B'),b)
  assert.equal(manager.installedPackage('A'),replacement)
  assert.equal(manager.settingsDescriptorSnapshot.B,bSchema)
  assert.deepEqual(probed,['A'])
  assert.equal(manager.settingsDescriptorSnapshot.A[0].id,'new')
})
test('older initial schema load cannot overwrite a newer installed package schema',async()=>{
  const a=installed('A','1'),b=installed('B','1'),replacement=installed('A','2')
  let finishOld,calls=0
  const manager=incrementalManager([a,b],()=>replacement,async(_registry,id)=>{
    if(id==='A' && calls++===0)return new Promise(resolve=>{finishOld=resolve})
    return {ready:true,descriptors:[{id:id==='A'?'new-A':'current-B'}]}
  })
  const oldLoad=manager.reloadSettingsDescriptors(manager.packages.slice(),1)
  await new Promise(setImmediate)
  manager.refreshInstalledPackage('A');await new Promise(setImmediate)
  finishOld({ready:true,descriptors:[{id:'old-A'}]});await oldLoad
  assert.equal(manager.settingsDescriptorSnapshot.A[0].id,'new-A')
  assert.equal(manager.settingsDescriptorSnapshot.B[0].id,'current-B')
})

function savedIndexManager(loadCachedIndex) {
  const shown=[], checks=[]
  const manager=subject('pages/SourcePackageManagerPage.ets','SourcePackageManagerPage',
    ['loadSavedIndexUrl','setSourceIndexUrl'],{...globals,tf:key=>key})
  Object.assign(manager,{savedIndexLoadRevision:0,indexLoadRevision:0,indexDisplayRevision:0,sourceIndexUrl:'',initialSettingsSourceId:'',
    sourceIndexService:{loadSavedUrl:async()=> 'https://saved.test/index.json',loadSavedRepositories:async()=>[],loadCachedIndex},
    showIndexEntries:(url,entries)=>shown.push({url,entries}),checkInstalledUpdates:async()=>{checks.push(shown.length)},sourceReasonText:r=>r})
  return {manager,shown,checks}
}
test('opening manager shows persisted metadata before launching background revalidation',async()=>{
  const metadata=[entry('A')], f=savedIndexManager(async()=>metadata)
  await f.manager.loadSavedIndexUrl()
  assert.equal(f.shown[0].entries,metadata);assert.equal(f.shown[0].url,'https://saved.test/index.json')
  assert.deepEqual(f.checks,[1])
  const empty=savedIndexManager(async()=>[]);await empty.manager.loadSavedIndexUrl()
  assert.equal(empty.shown.length,1);assert.equal(empty.shown[0].entries.length,0);assert.deepEqual(empty.checks,[1])
  const missing=savedIndexManager(async()=>undefined);await missing.manager.loadSavedIndexUrl()
  assert.equal(missing.shown.length,0);assert.deepEqual(missing.checks,[0])
})
test('late cached metadata cannot overwrite another selected repository or trigger its old refresh',async()=>{
  let finish
  const f=savedIndexManager(()=>new Promise(resolve=>{finish=resolve}))
  const running=f.manager.loadSavedIndexUrl();await new Promise(setImmediate)
  f.manager.setSourceIndexUrl('https://other.test/index.json')
  finish([entry('old')]);await running
  assert.equal(f.shown.length,0);assert.equal(f.checks.length,0)
  assert.equal(f.manager.sourceIndexUrl,'https://other.test/index.json')
})
