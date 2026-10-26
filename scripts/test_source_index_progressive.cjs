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
  // Include production computed getters, so callers run the same reactive
  // projections introduced in the manager instead of an incomplete fake owner.
  const selected = cls.members.filter(n => methods.includes(n.name?.getText(tree)) || ts.isGetAccessorDeclaration(n))
  const body = selected.map(n => n.getText(tree).replace(/@Computed\b/g, '')).join('\n')
  const exports = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject {${body}}`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, console, ...globals })
  return Object.assign(new exports.Subject(), {packages:[],indexEntries:[],managerCache:{retireCheck(){},rememberSavedIndex(){}}})
}
const entry = id => ({ id, name: id, version: '1', icon: `${id}.png` })
const globals = {
  resolveIndexDocumentUrl: value => value,
  entryWithCachedIcon: (entry, iconUri) => ({ ...entry, iconUri }),
  SOURCE_INDEX_ICON_FETCH_CONCURRENCY: 4,
  taskpool: { execute: async (fn,...args) => fn(...args) },
  parseSourceIndexDocumentTask: body => ({ok:true,entries:JSON.parse(body)}),
  SourceIdentityIconState: class { uri = '' },
  DiagnosticLogger: { info() {}, error() {}, warn() {} },
}

test('identity image callbacks retain first-load async and cannot mark a replacement URI decoded', () => {
  const rendered = []
  const row = subject('components/ui/ConciseListRow.ets', 'ConciseListRow',
    ['sourceIdentityUri', 'sourceIdentityCanSyncLoad', 'sourceIdentityDecoded', 'sourceIdentityDecodeFailed', 'SourceIdentityImage'], {
      Builder() {}, ImageFit: { Contain: 0 }, ImageInterpolation: { Medium: 0 },
      Image(uri) {
        const image = { uri }; rendered.push(image)
        let chain
        chain = new Proxy({}, { get: (_target, key) => value => {
          if (key === 'syncLoad') image.sync = value
          if (key === 'onComplete') image.complete = value
          if (key === 'onError') image.error = value
          return chain
        } })
        return chain
      },
    })
  Object.assign(row, { sourceIdentityIconUri: 'file://A', decodedSourceIdentityUri: '', sourceIdentityOpticalScale: () => 1 })
  const image = uri => { row.SourceIdentityImage(uri); return rendered.at(-1) }
  const a = image('file://A'); assert.equal(a.sync, false)
  a.complete({ loadingStatus: 0 }); assert.equal(image('file://A').sync, false)
  a.complete({ loadingStatus: 1 }); assert.equal(image('file://A').sync, true)
  row.sourceIdentityIconUri = 'file://B'
  const b = image('file://B'); assert.equal(b.sync, false)
  a.complete({ loadingStatus: 1 }); assert.equal(image('file://B').sync, false)
  b.complete({ loadingStatus: 1 }); assert.equal(image('file://B').sync, true)
  a.error(); assert.equal(image('file://B').sync, true)
  b.error(); assert.equal(image('file://B').sync, false)
  row.sourceIdentityIconUri = 'https://remote.test/icon'
  const remote = image(row.sourceIdentityIconUri); remote.complete({ loadingStatus: 1 })
  assert.equal(image(row.sourceIdentityIconUri).sync, false)
})

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
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', ['fetchIndex', 'setSavedIndexFailure'], {
    ...globals, tf: key => key, t: key => key,
  })
  const metadata = [entry('A')], icons = { A: { uri: 'file://A.png' } }, packages = [installed('A', '1')]
  let finish
  Object.assign(manager, {
    sourceIndexUrl: 'https://same.test/index.json', indexLoadRevision: 1, indexDisplayRevision: 0, savedIndexLoadRevision: 0,
    indexFetchBusy: false, indexEntries: metadata, indexIconStates: icons, packages, sourceIndexFailures: {},
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
  Object.assign(manager, { updateInstallSourceId:'', indexInstallBusy:false, busy:false, packageInstallTasks:installLane(),
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
  // Run the real queue and per-source state constructors, including field
  // initialization; strip only platform observation decorators for Node.
  const source = fs.readFileSync(path.join(root,'sourceRuntime/SourceIndexService.ets'),'utf8')
  const tree = ts.createSourceFile('queue.ets',source,ts.ScriptTarget.Latest,true)
  const names = ['SourcePackageInstallState','SourcePackageInstallTasks']
  const code = names.map(name=>{
    const cls = tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text===name)
    assert.ok(cls,name)
    return cls.getText(tree).replace(/@ObservedV2\b/g,'').replace(/@Trace\b/g,'')
  }).join('\n')
  const exports = {}
  vm.runInNewContext(ts.transpileModule(code,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{exports})
  return new exports.SourcePackageInstallTasks()
}
test('other packages enqueue during an install; one identity shares one result and writes remain serial', async () => {
  const lane = installLane(), starts = []; let finishA, finishB
  const stateA=lane.stateFor('A'),stateB=lane.stateFor('B'),stateC=lane.stateFor('C')
  assert.equal(stateC.phase,'idle');assert.equal(lane.stateFor('C'),stateC)
  const a = lane.run('A', () => new Promise(resolve => {starts.push('A'); finishA = resolve}))
  const b = lane.run('B', () => new Promise(resolve => {starts.push('B'); finishB = resolve}))
  assert.equal(lane.run('A', () => {throw Error('duplicate install')}), a)
  assert.deepEqual(Array.from(lane.pendingIds), ['A','B'])
  assert.equal(stateA.phase,'queued');assert.equal(stateB.phase,'queued');assert.equal(stateC.phase,'idle')
  await new Promise(setImmediate)
  assert.deepEqual(starts, ['A']); assert.equal(lane.runningId, 'A')
  assert.equal(stateA.phase,'running');assert.equal(stateB.phase,'queued');assert.equal(stateC.phase,'idle')
  finishA({ok:true}); await a; await new Promise(setImmediate)
  assert.deepEqual(starts, ['A','B']); assert.equal(lane.runningId, 'B')
  assert.equal(stateA.phase,'idle');assert.equal(stateB.phase,'running');assert.equal(lane.stateFor('A'),stateA)
  assert.deepEqual(Array.from(lane.pendingIds), ['B'])
  finishB({ok:true}); await b
  assert.equal(lane.pendingIds.length, 0); assert.equal(lane.runningId, '')
  assert.equal(stateA.phase,'idle');assert.equal(stateB.phase,'idle');assert.equal(stateC.phase,'idle')
})
test('an installation rejection retires that source and does not poison the next queued package', async () => {
  const lane = installLane(); let failA
  const a = lane.run('A', () => new Promise((_resolve,reject) => {failA=reject}))
  const rejected = assert.rejects(a, /network/)
  const b = lane.run('B', async () => ({ok:true}))
  await new Promise(setImmediate); failA(Error('network')); await rejected
  assert.equal((await b).ok, true)
  assert.equal(lane.pendingIds.length,0)
  assert.equal(lane.stateFor('A').phase,'idle');assert.equal(lane.stateFor('B').phase,'idle')
  assert.equal((await lane.run('A', async () => ({ok:true}))).ok,true)
})
test('only queued identities are pending and each action reports its actual running or waiting state', () => {
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['packageInstallPending', 'packageActionLabel'], {t:key=>key})
  const states = {A:{phase:'running'}, B:{phase:'queued'}, C:{phase:'idle'}}
  manager.packageInstallTasks={
    stateFor:id=>states[id],
    get pendingIds(){throw Error('row subscribed to aggregate queue')},
    get runningId(){throw Error('row subscribed to aggregate running identity')},
  }
  assert.equal(manager.packageInstallPending('A'),true)
  assert.equal(manager.packageInstallPending('B'),true)
  assert.equal(manager.packageInstallPending('C'),false)
  assert.equal(manager.packageActionLabel('A',false),'source_pkg_installing')
  assert.equal(manager.packageActionLabel('B',true),'source_pkg_action_queued')
  assert.equal(manager.packageActionLabel('C',true),'source_pkg_action_update')
})

function settingsCapability(response, capabilities = ['settings'], onRequest = () => {}) {
  const source = fs.readFileSync(path.join(root,'sourceRuntime/SourceSettingsStore.ets'),'utf8')
  const tree = ts.createSourceFile('settings.ets',source,ts.ScriptTarget.Latest,true)
  const fn = tree.statements.find(n=>ts.isFunctionDeclaration(n) && n.name.text==='loadSourceSettingsDescriptorsAsync')
  const output={}
  vm.runInNewContext(ts.transpileModule(fn.getText(tree),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{
    exports:output, runRegisteredSourceRequestByIdAsync:async()=>{onRequest();return {response}},
    normalizeSourceSettingDescriptors:r=>r.data?.settings ?? r.data?.items ?? [], Date, JSON, Array,
  })
  return output.loadSourceSettingsDescriptorsAsync({lookup:()=>({entry:{capabilities}})},'source')
}
test('only successful empty settings or explicit unsupported operation establish that no settings exist', async()=>{
  let calls=0
  const unsupported=await settingsCapability(undefined, [],()=>{calls++})
  assert.equal(unsupported.ready,true);assert.equal(unsupported.descriptors.length,0);assert.equal(calls,0)
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
// The latest user prohibition replaces the old optimistic unknown settings entry.
test('route settings capability hides empty and unavailable sources and ignores a departed route', async()=>{
  let result={ready:true,descriptors:[]},finish
  const changes=[]
  const host=subject('components/SourceSettingsSheetHost.ets','SourceSettingsSheetHost',
    ['loadAvailability'],{appSourceRuntimeRegistry:{},loadSourceSettingsDescriptorsAsync:()=>result})
  Object.assign(host,{mounted:true,sourceId:'A',onAvailabilityChanged:value=>changes.push(value)})
  await host.loadAvailability(); assert.deepEqual(changes,[false])
  result={ready:false,descriptors:[]}; await host.loadAvailability();assert.deepEqual(changes,[false,false])
  result=new Promise(resolve=>{finish=resolve});const loading=host.loadAvailability();host.mounted=false
  finish({ready:true,descriptors:[{id:'region'}]});await loading;assert.deepEqual(changes,[false,false])
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
    resolveSourceLocalizedName:(name,names,locale)=>names?.[locale]??name,
    compareSourceNames:(left,_id,right)=>left.localeCompare(right),
  })
  Object.assign(manager,{languageState:{effectiveLocale:'zh-Hans'},packages:oldPackages,settingsReloadRevision:1,settingsSourceReloads:{},
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

// The user rejected replaying cache hydration and automatic checks on every
// destination creation. Exercise the retained production owner before navigation.
function retainedCache(service, packages = []) {
  const source=fs.readFileSync(path.join(root,'viewmodel/SourcePackageManagerCache.ets'),'utf8')
    .replace(/^import[\s\S]*?from '[^']+'\n/gm,'').replace(/@ObservedV2/g,'').replace(/@Trace /g,'')
  const exports={}
  vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText,{
    exports,console,JSON,Map,Promise,Date,
    AppStrings:{get:key=>key.startsWith('source_pkg_reason_')?key.slice('source_pkg_reason_'.length):key,format:(key,...values)=>JSON.stringify([key,...values])},
    listInstalled:()=>packages,resolveSourceLocalizedName:name=>name,compareSourceNames:(a,_id,b)=>a.localeCompare(b),
    SourceIdentityIconState:globals.SourceIdentityIconState,SourceIndexService:class{constructor(){return service}},
  })
  return new exports.SourcePackageManagerCache()
}
test('cache is ready before navigation, revisits retain row/icon inputs and do not recheck online',async()=>{
  let reads=0,fetches=0;const metadata=[entry('A')]
  const service={loadSavedUrl:async()=> 'https://saved.test/index.json',loadSavedRepositories:async()=>[],
    loadCachedIndex:async()=>{reads++;return metadata},loadIndexIcons:async()=>{},
    saveUrl:async()=>{},fetchIndex:async()=>{fetches++;return {ok:true,entries:metadata}}}
  const cache=retainedCache(service,[installed('B','1')]),context={filesDir:'data'}
  await cache.prepare(context,'zh');const rows=cache.indexEntries,icons=cache.indexIconStates,packages=cache.packages
  assert.equal(rows[0],metadata[0]);assert.equal(fetches,0)
  await cache.prepare(context,'zh');assert.equal(reads,1);assert.equal(fetches,0)
  assert.equal(cache.indexEntries,rows);assert.equal(cache.indexIconStates,icons);assert.equal(cache.packages,packages)
  cache.revalidateInBackground(context);await new Promise(setImmediate);assert.equal(fetches,1)
  const revision=cache.revision;await cache.prepare(context,'zh');cache.revalidateInBackground(context)
  await new Promise(setImmediate);assert.equal(fetches,1);assert.equal(cache.revision,revision)
  assert.equal(cache.indexEntries,rows);assert.equal(cache.indexIconStates,icons)
})
test('invalidated hydration cannot publish an old repository over the new cache',async()=>{
  let finish;let url='https://old.test/index.json'
  const cache=retainedCache({loadSavedUrl:async()=>url,loadSavedRepositories:async()=>[],loadIndexIcons:async()=>{},
    loadCachedIndex:async()=>url.includes('old')?new Promise(resolve=>{finish=resolve}):[entry('new')]})
  const old=cache.prepare({filesDir:'data'},'zh');await new Promise(setImmediate)
  cache.invalidate();url='https://new.test/index.json';await cache.prepare({filesDir:'data'},'zh')
  finish([entry('old')]);await old
  assert.equal(cache.sourceIndexUrl,url);assert.equal(cache.indexEntries[0].id,'new')
})

test('fresh install results and settings survive the previous frame package cache', async () => {
  const before = installed('A', '1.0'), after = installed('A', '2.0'), neighbor = installed('B', '1.0')
  const descriptors = [{ key: 'language' }]
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', [
    'updateInstalledPackage', 'refreshInstalledPackage', 'reloadInstalledPackageSettings',
    'publishSourceSettings', 'setUpdateStatus', 'installedPackage',
  ], { ...globals, getInstalledSourcePackage: () => after,
    resolveSourceLocalizedName: name => name, compareSourceNames: (left, _id, right) => left.localeCompare(right),
    appSourceSettingsStore: { loadForSource: () => ({}) }, appSourceRuntimeRegistry: {},
    loadSourceSettingsDescriptorsAsync: async () => ({ ready: true, descriptors }),
    sourceDisplayName: (_id, name) => name, t: key => key, tf: key => key,
  })
  Object.assign(manager, { packages: [before, neighbor], busy: false, packageUpdateStatuses: [],
    languageState: { effectiveLocale: 'zh-CN' }, sourceSheetSourceId: '', savedSettingCounts: {},
    settingsValidationStatuses: [], settingsSourceReloads: {}, settingsReloadRevision: 0,
    settingsDescriptorSnapshot: { A: [] }, settingsAvailability: { A: 'old' },
    settingsAvailabilityText: values => `fields:${values.length}`, packageInstallPending: () => false,
    sourceIndexService: { installPackage: async () => ({ ok: true, id: 'A' }) }, showToast() {},
  })
  // Official V2 behavior: a Computed value retains its old result until the
  // next frame, even after this task writes packages or awaits a ready result.
  Object.defineProperty(manager, 'installedPackagesById', { value: new Map([['A', before], ['B', neighbor]]) })
  const reloadSettings = manager.reloadInstalledPackageSettings.bind(manager)
  let settingsCompleted
  manager.reloadInstalledPackageSettings = (...args) => {
    settingsCompleted = reloadSettings(...args)
    return settingsCompleted
  }
  await manager.updateInstalledPackage(before, { entry: indexed('A', '2.0'), indexUrl: 'https://index.test/index.json' })
  await settingsCompleted
  assert.deepEqual({ version: manager.packageUpdateStatuses[0].localVersion,
    fields: manager.settingsDescriptorSnapshot.A, availability: manager.settingsAvailability.A },
  { version: '2.0', fields: descriptors, availability: 'fields:1' })
  assert.equal(manager.packages.find(item => item.id === 'B'), neighbor)
})

function updateCheckManager(packages, replies, statuses = []) {
  packages = packages.map(source => ({ ...source, lang: '' }))
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage', [
    'checkInstalledUpdates', 'retainDisplayCache', 'restoreDisplayCache', 'sourceIndexUrlsForUpdate', 'checkedUpdateStatuses', 'installedPackage',
    'compareVersion', 'entryDeclaresPackageIcon', 'needsPackageIdentityIconRepair', 'updateAvailableFor',
    'updateStatus', 'updateStatusText', 'packageListMetaText', 'savedIndexSubtitle', 'setSavedIndexFailure', 'fetchIndex',
  ], { ...globals, t: key => key, tf: (key, ...values) => JSON.stringify([key, ...values]) })
  Object.assign(manager, { packages, packageUpdateStatuses: statuses, sourceIndexFailures: {},
    sourceIndexUrl: 'https://active.test/index.json', indexEntries: [], indexIconStates: {},
    sourceIndexRepositories: [], indexLoadRevision: 0, indexDisplayRevision:0, savedIndexLoadRevision: 0, displayCacheRevision:0, settingsRouteActive:true,
    indexFetchBusy: false, updateCheckBusy: false,
    currentIndexUrlOrPrompt: async () => manager.sourceIndexUrl,
    sourceReasonText: reason => reason, sourceRedactedReasonText: reason => reason,
    sourceIndexService: { saveUrl: async () => {}, loadIndexIcons:async()=>{},
      loadSavedRepositories: async () => [...replies.keys()].map(url => ({ url })),
      fetchIndex: async url => replies.get(url) },
    showIndexEntries: (_url, entries) => { manager.indexEntries = entries },
  })
  manager.context=()=>({filesDir:'data'})
  manager.managerCache=retainedCache(manager.sourceIndexService,packages)
  manager.managerCache.packages=packages
  return manager
}

test('partial repository check cannot conclude latest/missing and retains fresh and previously confirmed updates', async () => {
  const active = 'https://active.test/index.json', other = 'https://other.test/index.json'
  const known = indexed('C', '2.0')
  const replies = new Map([[active, { ok: true, entries: [indexed('A', '1.0'), indexed('D', '2.0')] }],
    [other, { ok: false, reasonCode: 'network_error', entries: [] }]])
  const manager = updateCheckManager(['A','B','C','D'].map(id => installed(id, '1.0')), replies,
    [{ sourceId: 'C', status: 'update', localVersion: '1.0', remoteEntry: known, remoteIndexUrl: other }])
  await manager.checkInstalledUpdates()
  assert.deepEqual(Array.from(manager.packageUpdateStatuses, value => [value.sourceId, value.status]),
    [['A','incomplete'], ['B','incomplete'], ['C','update'], ['D','update']])
  assert.equal(manager.updateStatus('C').remoteEntry, known)
  assert.equal(manager.updateStatus('D').remoteIndexUrl, active)
  assert.equal(manager.statusText, JSON.stringify(['source_pkg_check_incomplete', 2]))
  assert.equal(manager.updateStatusText(manager.packages[0]), 'source_pkg_update_status_incomplete')
  assert.equal(manager.packageListMetaText(manager.packages[0]), 'v1.0 · source_pkg_update_status_incomplete')
  assert.equal(manager.savedIndexSubtitle({ url: other }), JSON.stringify(['source_pkg_check_failed','network_error']))
  assert.equal(manager.savedIndexSubtitle({ url: active }), 'source_pkg_current_index')
  assert.equal(manager.updateCheckBusy, false)
})

test('successful address retry clears its failure; complete and all-failed checks retain their original conclusions', async () => {
  const active = 'https://active.test/index.json', other = 'https://other.test/index.json'
  const replies = new Map([[active, { ok: true, entries: [indexed('A','1.0')] }],
    [other, { ok: false, reasonCode: 'network_error', entries: [] }]])
  const manager = updateCheckManager(['A','B','C'].map(id => installed(id,'1.0')), replies)
  await manager.checkInstalledUpdates()
  replies.set(other, { ok: true, entries: [indexed('B','2.0')] })
  manager.sourceIndexUrl = other
  await manager.fetchIndex()
  assert.equal(manager.sourceIndexFailures[other], undefined)
  assert.equal(manager.savedIndexSubtitle({ url: other }), 'source_pkg_current_index')
  await manager.checkInstalledUpdates()
  assert.deepEqual(Array.from(manager.packageUpdateStatuses, value => [value.sourceId,value.status]),
    [['A','latest'],['B','update'],['C','missing']])
  assert.equal(manager.statusText, JSON.stringify(['source_pkg_check_complete',1,1,1]))
  assert.equal(manager.packageListMetaText(manager.packages[0]), 'v1.0')
  for (const url of replies.keys()) replies.set(url, { ok: false, entries: [], reasonCode: 'network_error' })
  await manager.checkInstalledUpdates()
  assert.deepEqual(Array.from(manager.packageUpdateStatuses, value => value.status), ['failed','failed','failed'])
  assert.equal(manager.statusText, JSON.stringify(['source_pkg_check_failed','network_error']))
  assert.equal(Object.keys(manager.sourceIndexFailures).length, 0)
})

test('invalidating a queued or in-flight cache check stops later repositories and cannot publish old results',async()=>{
  let finish;const calls=[],active='https://active.test/index.json',other='https://other.test/index.json'
  const service={loadSavedUrl:async()=>active,loadSavedRepositories:async()=>[{url:other}],loadCachedIndex:async()=>[entry('A')],loadIndexIcons:async()=>{},saveUrl:async()=>{},
    fetchIndex:async url=>{calls.push(url);return url===active?new Promise(resolve=>{finish=resolve}):{ok:true,entries:[entry('B')]}}}
  const cache=retainedCache(service,[installed('A','1')]);await cache.prepare({filesDir:'data'},'zh')
  const running=cache.check({filesDir:'data'});await new Promise(setImmediate)
  cache.invalidate();finish({ok:true,entries:[entry('A')]});await running
  assert.deepEqual(calls,[active]);assert.equal(cache.packageUpdateStatuses.length,0)
})

// A URL typed in the sheet is a draft, not a saved repository. It must retire
// old background work without becoming the retained URL when the route closes.
test('editing a repository retires background results and cannot retain an unsaved URL',async()=>{
  let finish;const active='https://saved.test/index.json',other='https://other.test/index.json',draft='https://draft.test/index.json',calls=[]
  const service={loadSavedUrl:async()=>active,loadSavedRepositories:async()=>[{url:other}],loadCachedIndex:async()=>[entry('A')],loadIndexIcons:async()=>{},saveUrl:async()=>{},
    fetchIndex:async url=>{calls.push(url);return new Promise(resolve=>{finish=resolve})}}
  const cache=retainedCache(service,[installed('A','1')]);await cache.prepare({filesDir:'data'},'zh')
  const originalRows=cache.indexEntries,originalIcons=cache.indexIconStates
  const manager=subject('pages/SourcePackageManagerPage.ets','SourcePackageManagerPage',
    ['restoreDisplayCache','retainDisplayCache','setSourceIndexUrl'],globals)
  Object.assign(manager,{managerCache:cache,sourceIndexUrl:'',sourceIndexUrlEdited:false,indexLoadRevision:0,indexDisplayRevision:0,savedIndexLoadRevision:0})
  manager.restoreDisplayCache()
  const running=cache.check({filesDir:'data'});await new Promise(setImmediate)
  manager.setSourceIndexUrl(draft);manager.retainDisplayCache()
  assert.equal(cache.sourceIndexUrl,active);assert.equal(cache.indexEntries,originalRows);assert.equal(cache.indexIconStates,originalIcons)
  finish({ok:true,entries:[entry('old-result')]});await running
  assert.deepEqual(calls,[active]);assert.equal(cache.indexEntries,originalRows)
  manager.sourceIndexUrlEdited=false;manager.restoreDisplayCache();assert.equal(manager.sourceIndexUrl,active)
  service.saveUrl=async()=>{throw Error('save failed')};await cache.check({filesDir:'data'},draft)
  assert.equal(cache.sourceIndexUrl,active)
  cache.rememberSavedIndex(draft);cache.rememberSavedIndex(active,[{url:other}]);assert.equal(cache.sourceIndexUrl,draft)
})

// A single failed source must never claim the shared saved-settings file is bad.
test('opening an unavailable source schema leaves other saved settings healthy', async()=>{
  const manager=subject('pages/SourcePackageManagerPage.ets','SourcePackageManagerPage',
    ['openSourceSettingsFromSheet'],{...globals,appSourceRuntimeRegistry:{},
      loadSourceSettingsDescriptorsAsync:async()=>{throw Error('missing export')},})
  Object.assign(manager,{sourceSheetShown:true,sourceSheetSourceId:'A',savedSettingsReadFailed:false})
  await manager.openSourceSettingsFromSheet({id:'A'})
  assert.equal(manager.savedSettingsReadFailed,false)
  const toasts=[]
  const readFailure=subject('pages/SourcePackageManagerPage.ets','SourcePackageManagerPage',
    ['openSourceSettingsFromSheet'],{...globals,appSourceRuntimeRegistry:{},t:x=>x,
      loadSourceSettingsDescriptorsAsync:async()=>({ready:true,descriptors:[{id:'region'}]})})
  Object.assign(readFailure,{sourceSheetShown:true,sourceSheetSourceId:'A',savedSettingsReadFailed:false,
    openSettings(){throw Error('saved file read failed')},showToast:x=>toasts.push(x)})
  await readFailure.openSourceSettingsFromSheet({id:'A'})
  assert.equal(readFailure.savedSettingsReadFailed,true)
  assert.deepEqual(toasts,['source_pkg_reason_settings_read_failed'])
})

test('a real saved-settings read failure retains its known settings action and reports the read stage', async()=>{
  const visible=[],toast=[]
  const host=subject('components/SourceSettingsSheetHost.ets','SourceSettingsSheetHost',
    ['openSettings'],{appSourceRuntimeRegistry:{},loadSourceSettingsDescriptorsAsync:async()=>({ready:true,descriptors:[{id:'region'}]}),
      sourceSettingsDraft:()=>{},appSourceSettingsStore:{loadForSource(){throw Error('read failed')}},AppStrings:{get:x=>x}})
  Object.assign(host,{mounted:true,active:true,epoch:0,sourceId:'A',onAvailabilityChanged:x=>visible.push(x),
    getUIContext:()=>({getPromptAction:()=>({showToast:x=>toast.push(x.message)})})})
  await host.openSettings()
  assert.deepEqual(visible,[true]);assert.deepEqual(toast,['source_pkg_reason_settings_read_failed'])
})
