// Production service/client requests on host API bindings; not live-account or NetworkKit acceptance.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
const stores = new Map(), modules = new Map(), networkCalls = []
let nextDirectKey = 0
let failNextPreferenceFlush = false
let nextNetworkResponse = { responseCode: 200, result: '{}' }, destroyed = 0
const bindings = {
  '@kit.ArkData': { preferences: { async getPreferences(_context, name) {
    if (!stores.has(name)) stores.set(name, new Map())
    const data = stores.get(name)
    return { async get(key, fallback) { return data.has(key) ? data.get(key) : fallback },
      getSync(key, fallback) { return data.has(key) ? data.get(key) : fallback },
      async has(key) { return data.has(key) }, async delete(key) { data.delete(key) },
      hasSync(key) { return data.has(key) }, deleteSync(key) { data.delete(key) },
      async put(key, value) { data.set(key, value) }, putSync(key, value) { data.set(key, value) }, async flush() { if (failNextPreferenceFlush) { failNextPreferenceFlush = false; throw Error('owned_flush_failure') } } }
  } } },
  '@kit.ArkTS': { buffer: Buffer, util: { generateRandomUUID: () => 'owned-direct-' + (++nextDirectKey), TextEncoder: class { encodeInto(s) { return new Uint8Array(Buffer.from(s)) } } } },
  '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET', POST: 'POST' },
    HttpDataType: { STRING: 0 }, createHttp() {
      return { async request(url, options) { networkCalls.push({ url, options }); return nextNetworkResponse },
        destroy() { destroyed++ } }
    } } },
}
function load(file) {
  if (modules.has(file)) return modules.get(file)
  const exports = {}; modules.set(file, exports)
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8')
  const output = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText
  vm.runInNewContext(output, { exports, require(name) {
    if (bindings[name]) return bindings[name]
    if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key } }
    if (name.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
    if (name.startsWith('@kit.')) return {}
    throw Error('Unbound module ' + name)
  }, console, setTimeout, clearTimeout })
  return exports
}
const model = load('model/TrackerModels')
const { TrackerPendingSyncStore } = load('model/TrackerPendingSyncStore')
const { TrackerProgressSyncService } = load('model/TrackerProgressSyncService')
const ani = load('model/AniListTrackerClient'), mal = load('model/MyAnimeListTrackerClient')
const clone = value => JSON.parse(JSON.stringify(value))
async function runProvider(providerId) {
  stores.clear()
  const preferences = new Map([
    [model.TRACKER_ACCOUNTS_KEY, JSON.stringify([{ providerId, status: 'connected', credentialAccountKey: 'owned-test' }])],
    [model.TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify([{ providerId, comicId: 'owned-book', providerTitleId: '123',
      mappingState: 'confirmed', userConfirmed: true, createdAt: 1 }])],
    [model.TRACKER_AUTO_SYNC_ENABLED_KEY, true], [model.TRACKER_UPDATE_STRATEGY_KEY, 'on_chapter_complete'],
  ])
  stores.set(model.TRACKER_PREFERENCES_STORE_NAME, preferences)
  const calls = []; let fail = false
  const adapter = { async request(request) {
    calls.push(clone(request))
    if (fail) return { status: 503, body: '{}' }
    // Remote on-hold state must be parsed independently of local chapter completion.
    return { status: 200, body: providerId === 'anilist'
      ? JSON.stringify({ data: { SaveMediaListEntry: { mediaId: 123, progress: 2, status: 'PAUSED' } } })
      : JSON.stringify({ num_chapters_read: 2, status: 'on_hold' }) }
  } }
  const client = providerId === 'anilist' ? new ani.AniListTrackerClient(adapter) : new mal.MyAnimeListTrackerClient(adapter)
  const pending = new TrackerPendingSyncStore({})
  const service = new TrackerProgressSyncService({}, { pendingStore: pending,
    secretStore: { isAvailable: () => true, readToken: async () => Buffer.from('owned-test-token') },
    ...(providerId === 'anilist' ? { aniListClient: client } : { myAnimeListClient: client }) })
  const progress = { comicId: 'owned-book', chapterId: 'chapter2', pageIndex: 3, totalPages: 4,
    progressRatio: 1, completed: true, updatedAt: 1 }
  const chapters = ['chapter1', 'chapter2', 'chapter3']
  function checkRequest(call, count) {
    assert.equal(call.headers.authorization, 'Bearer owned-test-token')
    assert.ok(!call.url.includes('owned-test-token') && !call.body.includes('owned-test-token'))
    if (providerId === 'anilist') {
      assert.deepEqual(JSON.parse(call.body).variables, { mediaId: 123, progress: count })
    } else {
      assert.equal(call.method, 'PATCH')
      assert.equal(call.url, 'https://api.myanimelist.net/v2/manga/123/my_list_status')
      assert.equal(call.headers.contentType, 'application/x-www-form-urlencoded')
      assert.equal(call.body, 'num_chapters_read=' + count)
    }
  }
  const result = await service.pushReadingProgress(progress, chapters, 'on_chapter_complete', 10)
  assert.equal(result.status, 'synced'); assert.equal(result.completed, false); checkRequest(calls.at(-1), 2)
  await service.pushReadingProgress({ ...progress, completed: false }, chapters, 'manual', 11)
  checkRequest(calls.at(-1), 1)
  const count = calls.length
  assert.equal((await service.pushReadingProgress({ ...progress, completed: false }, chapters)).reason, 'strategy_not_due')
  assert.equal(calls.length, count)
  fail = true
  const failed = await service.pushReadingProgress(progress, chapters, 'manual', 12)
  assert.equal(failed.queued, true); checkRequest(calls.at(-1), 2)
  const queued = clone(await pending.loadPendingProgress())
  assert.equal(queued.length, 1); assert.equal(queued[0].completed, true); assert.equal(queued[0].providerProgress, 2)
  fail = false
  const retry = await service.retryPendingProgress(20, 13)
  assert.equal(retry.syncedCount, 1); checkRequest(calls.at(-1), 2)
  assert.equal((await pending.loadPendingProgress()).length, 0)
  for (const completed of [true, false]) {
    await client.pushProgress('owned-test-token', '123', 2, completed)
    const call = calls.at(-1)
    if (providerId === 'anilist') assert.equal(JSON.parse(call.body).variables.status, completed ? 'COMPLETED' : 'CURRENT')
    else assert.equal(new URLSearchParams(call.body).get('status'), completed ? 'completed' : 'reading')
  }
  const beforeInvalid = calls.length
  assert.equal((await client.pushProgress('owned-test-token', 'invalid', 2)).errorCode, 'not_found')
  assert.equal(calls.length, beforeInvalid)
  console.log(providerId + ': production first push, incomplete chapter, failure queue/retry and explicit status intent checked')
}
async function runAdditionalProvider(providerId) {
  stores.clear();let count, remoteStatus=providerId==='bangumi'?4:4, fail=false;const calls=[];
  const preferences=new Map([
    [model.TRACKER_ACCOUNTS_KEY,JSON.stringify([{providerId,status:'connected',credentialAccountKey:'owned-test'}])],
    [model.TRACKER_COMIC_MAPPINGS_KEY,JSON.stringify([{providerId,comicId:'owned-book',providerTitleId:'123',mappingState:'confirmed',userConfirmed:true,createdAt:1}])],
    [model.TRACKER_AUTO_SYNC_ENABLED_KEY,true],[model.TRACKER_UPDATE_STRATEGY_KEY,'on_chapter_complete']]);
  stores.set(model.TRACKER_PREFERENCES_STORE_NAME,preferences);
  const adapter={async request(request){
    calls.push(clone(request));if(fail)return {status:503,body:'{}'};
    if(request.url.includes('/search/subjects')||request.url.endsWith('/series/search')) return {status:200,body:JSON.stringify(providerId==='bangumi'?{data:[{id:123,name:'Owned manga',platform:'漫画'}]}:{results:[{record:{series_id:123,title:'Owned manga'}}]})};
    if(request.method==='GET')return count===undefined?{status:404,body:'{}'}:{status:200,body:JSON.stringify(providerId==='bangumi'?{type:remoteStatus,ep_status:count}:{list_id:remoteStatus,status:{chapter:count}})};
    const body=JSON.parse(request.body);
    if(providerId==='bangumi'){count=body.ep_status;if(body.type!==undefined)remoteStatus=body.type;}
    else {if(body[0].status)count=body[0].status.chapter;else count=0;remoteStatus=body[0].list_id;}
    return {status:204,body:''};
  }};
  const extra=load('model/AdditionalTrackerClients');
  const client=providerId==='bangumi'?new extra.BangumiTrackerClient(adapter):new extra.MangaUpdatesTrackerClient(adapter);
  const pending=new TrackerPendingSyncStore({});
  const service=new TrackerProgressSyncService({},{pendingStore:pending,
    secretStore:{isAvailable:()=>true,readToken:async()=>Buffer.from('owned-token')},
    ...(providerId==='bangumi'?{bangumiClient:client}:{mangaUpdatesClient:client})});
  const progress={comicId:'owned-book',chapterId:'c2',pageIndex:0,totalPages:1,progressRatio:1,completed:true,updatedAt:1};
  assert.equal((await service.pushReadingProgress(progress,['c1','c2'],'on_chapter_complete',10)).status,'synced');
  assert.equal(count,2);remoteStatus=4;const before=calls.length;
  await service.pushReadingProgress(progress,['c1','c2'],'on_chapter_complete',11);assert.equal(calls.length,before+1,'remote count must prevent a needless write');
  await service.pushReadingProgress({...progress,chapterId:'c1'},['c1','c2'],'manual',12);assert.equal(count,1);assert.equal(remoteStatus,4,'progress-only updates preserve on-hold state');
  fail=true;assert.equal((await service.pushReadingProgress(progress,['c1','c2'],'manual',13)).queued,true);
  fail=false;assert.equal((await service.retryPendingProgress(20,14)).syncedCount,1);assert.equal(count,2);
  assert.ok(calls.every(c=>c.token==='owned-token'&&!c.url.includes('owned-token')&&!String(c.body).includes('owned-token')));
  const {TrackerMappingSearchService}=load('model/TrackerMappingSearchService');
  const search=new TrackerMappingSearchService({},{secretStore:{isAvailable:()=>true,readToken:async()=>Buffer.from('owned-token')},
    ...(providerId==='bangumi'?{bangumiClient:client}:{mangaUpdatesClient:client})});
  const matched=await search.refreshComicMappingCandidates({id:'unmapped-book',title:'Owned manga'},providerId,15);
  assert.equal(matched.mappedCount,1,'connected provider must traverse actual mapping service and client');
  assert.equal(matched.results[0].mapping.providerTitleId,'123');
  assert.equal(matched.results[0].mapping.userConfirmed,false,'search never silently binds');
  console.log(providerId+': actual client create/readback, state preservation, monotonic auto-sync and failed retry checked');
}

async function runKitsuProvider() {
  stores.clear();let entry,fail=false;const calls=[],assets=new Map();
  const secretStore={isAvailable:()=>true,async writeToken(r){assets.set(r.accountKey,Buffer.from(r.secretBytes));return {ok:true}},
    async readToken(r){return assets.get(r.accountKey)},async deleteAccount(r){assets.delete(r.accountKey);return {ok:true}}};
  const client=new (load('model/KitsuTrackerClient').KitsuTrackerClient)({async request(request){
    calls.push(clone(request));if(fail)return {status:503,body:'{}'};
    if(request.url.endsWith('/oauth/token'))return {status:200,body:JSON.stringify({access_token:'owned-kitsu-token'})};
    const body=JSON.parse(request.body),q=body.query;let data;
    if(q.includes('currentAccount'))data={currentAccount:{id:'42',profile:{name:'Owned reader'}}};
    else if(q.includes('searchMangaByTitle'))data={searchMangaByTitle:{nodes:[{id:'38',titles:{preferred:'One Piece'}}]}};
    else if(q.includes('findMangaById'))data={findMangaById:{myLibraryEntry:entry}};
    else {
      const input=body.variables.input,isNew=q.includes('KomaAdd');
      if(isNew)entry={id:'entry-1',progress:input.progress,status:input.status,private:true,rating:80};
      else {assert.deepEqual(Object.keys(input).sort(),['id','progress']);entry.progress=input.progress;}
      data={libraryEntry:{[isNew?'create':'update']:{errors:[],libraryEntry:{id:entry.id}}}};
    }
    return {status:200,body:JSON.stringify({data})};
  }});
  const direct=new (load('model/TrackerDirectConnectionService').TrackerDirectConnectionService)({},{secretStore,kitsuClient:client});
  const login=await direct.connect('kitsu','owned@example.invalid','owned-test-password',1);assert.equal(login.ok,true);
  const form=new URLSearchParams(calls[0].body);assert.equal(form.get('grant_type'),'password');
  assert.equal(form.get('username'),'owned@example.invalid');assert.equal(form.has('client_secret'),false);
  assert.ok(!JSON.stringify(login.preferences).includes('owned-test-password'));
  const prefs=new model.TrackerPreferencesStore({},secretStore);
  await prefs.saveSyncPreferenceChanges({autoSyncEnabled:true,updateStrategy:'on_chapter_complete'});
  const search=new (load('model/TrackerMappingSearchService').TrackerMappingSearchService)({},{secretStore,kitsuClient:client});
  const found=await search.refreshComicMappingCandidates({id:'owned-kitsu-book',title:'One Piece'},'kitsu',2);
  assert.equal(found.mappedCount,1);assert.equal(found.results[0].mapping.userConfirmed,false);
  await prefs.confirmComicMapping('owned-kitsu-book','kitsu',3);
  const progress={comicId:'owned-kitsu-book',chapterId:'c2',pageIndex:0,totalPages:1,progressRatio:1,completed:true,updatedAt:3};
  const sync=new TrackerProgressSyncService({},{secretStore,kitsuClient:client});
  assert.equal((await sync.pushReadingProgress(progress,['c1','c2'],'manual',3,'kitsu')).status,'synced');
  assert.equal(entry.progress,2);entry.status='ON_HOLD';
  assert.equal((await sync.pushReadingProgress({...progress,chapterId:'c1'},['c1','c2'],'manual',4,'kitsu')).status,'synced');
  assert.equal(entry.status,'ON_HOLD');assert.equal(entry.private,true);assert.equal(entry.rating,80);
  fail=true;assert.equal((await sync.pushReadingProgress(progress,['c1','c2'],'manual',5,'kitsu')).queued,true);
  fail=false;assert.equal((await sync.retryPendingProgress(20,6)).syncedCount,1);assert.equal(entry.progress,2);
  console.log('kitsu: production password grant, secure login, mapping/confirmation, progress-only write and pending retry checked');
}

async function runDirectConnection() {
  stores.clear();const assets=new Map();let failDeleteOld=false;
  const secretStore={isAvailable:()=>true,async writeToken(r){assets.set(r.accountKey,Buffer.from(r.secretBytes).toString());return {ok:true}},
    async deleteAccount(r){if(failDeleteOld&&r.accountKey==='owned-direct-1')throw Error('owned cleanup failure');assets.delete(r.accountKey);return {ok:true}}};
  const {TrackerDirectConnectionService}=load('model/TrackerDirectConnectionService');
  const client={async fetchProfile(){return {ok:true,value:{providerId:'bangumi',providerUserId:'42',username:'owned-user'}}}};
  const service=new TrackerDirectConnectionService({},{secretStore,bangumiClient:client});
  let result=await service.connect('bangumi','','owned-token',1);assert.equal(result.ok,true);
  assert.equal(assets.get('owned-direct-1'),'owned-token','stored bytes must contain exactly the token');
  assert.ok(!JSON.stringify(result.preferences).includes('owned-token'));
  failNextPreferenceFlush=true;result=await service.connect('bangumi','','new-owned-token',2);
  assert.equal(result.ok,false);assert.equal(assets.get('owned-direct-1'),'owned-token');assert.equal(assets.has('owned-direct-2'),false);
  failDeleteOld=true;result=await service.connect('bangumi','','third-owned-token',3);
  assert.equal(result.ok,true);assert.equal(assets.get('owned-direct-3'),'third-owned-token');
  const extra=load('model/AdditionalTrackerClients'),requests=[];
  const mu=new extra.MangaUpdatesTrackerClient({async request(request){requests.push(clone(request));
    return {status:200,body:JSON.stringify(request.url.endsWith('/account/login')?
      {context:{uid:24,session_token:'owned-mu-session'}}:{username:'owned-mu-user'})};}});
  const muService=new TrackerDirectConnectionService({},{secretStore,mangaUpdatesClient:mu});
  const connected=await muService.connect('mangaupdates','owned-mu-user','owned-test-password',4);
  assert.equal(connected.ok,true);
  const account=connected.preferences.accounts.find(a=>a.providerId==='mangaupdates');
  assert.equal(account.profile.providerUserId,'24');
  assert.equal(assets.get(account.credentialAccountKey),'owned-mu-session');
  assert.ok(!JSON.stringify(connected.preferences).includes('owned-test-password'));
  assert.ok(!JSON.stringify(connected.preferences).includes('owned-mu-session'));
  assert.equal(requests[0].method,'PUT');
  assert.equal(requests[1].token,'owned-mu-session');
  console.log('Direct connection: verified session, exact secret bytes, rejected commit rollback and post-commit cleanup failure checked');
}

async function runPreferenceOwner() {
  stores.clear()
  const secretStore = { isAvailable: () => true, readToken: async () => new Uint8Array(Buffer.from('owned-token')),
    writeToken: async () => ({ ok: true }), deleteAccount: async () => ({ ok: true }), deleteToken: async () => ({ ok: true }) }
  const context = { filesDir: 'owned-tracker-preferences' }
  const store = () => new model.TrackerPreferencesStore(context, secretStore)
  await Promise.all([store().saveSyncPreferenceChanges({ autoSyncEnabled: true }),
    store().saveSyncPreferenceChanges({ updateStrategy: 'manual' })])
  let value = await store().load()
  assert.equal(value.autoSyncEnabled, true); assert.equal(value.updateStrategy, 'manual')
  const raw = stores.get(model.TRACKER_PREFERENCES_STORE_NAME), original = new Map(raw)
  failNextPreferenceFlush = true
  await assert.rejects(store().saveSyncPreferences(false, 'on_reader_close'), /owned_flush_failure/)
  assert.deepEqual(raw, original, 'failed commit must restore cache values and original missing keys')
  const mapping = id => ({ comicId: id, providerId: 'anilist', providerTitleId: id,
    mappingState: 'candidate', userConfirmed: false, createdAt: 1 })
  await Promise.all([store().upsertComicMapping(mapping('1')), store().upsertComicMapping(mapping('2'))])
  assert.equal((await store().load()).comicMappings.length, 2)
  await store().confirmComicMapping('1', 'anilist', 2)
  await store().removeComicMapping('2', 'anilist')
  assert.equal((await store().listComicMappings('1'))[0].mappingState, 'confirmed')
  await Promise.all([store().saveProviderOAuthConfig('anilist', 'owned-a', 'https://owned.invalid/a'),
    store().saveProviderOAuthConfig('myanimelist', 'owned-b', 'https://owned.invalid/b')])
  assert.equal((await store().load()).providerOAuthConfigs.length, 2)
  await store().saveAccounts([{ providerId: 'anilist', status: 'connected', credentialAccountKey: 'owned-account' }])
  let started, resume
  const began = new Promise(resolve => { started = resolve }), profile = new Promise(resolve => { resume = resolve })
  const { TrackerAccountRefreshService } = load('model/TrackerAccountRefreshService')
  const refresh = new TrackerAccountRefreshService(context, { secretStore,
    aniListClient: { async fetchProfile() { started(); return profile } } }).refreshAccounts('anilist', 10)
  await began
  await store().disconnectAccount('anilist')
  resume({ ok: true, value: { providerUserId: '1', username: 'owned-user' } })
  const result = await refresh
  assert.equal(result.refreshedCount, 0); assert.equal(result.skippedCount, 1)
  assert.equal((await store().load()).accounts.find(account => account.providerId === 'anilist').status, 'disconnected')
  for (const key of [model.TRACKER_ACCOUNTS_KEY, model.TRACKER_COMIC_MAPPINGS_KEY, model.TRACKER_PROVIDER_OAUTH_CONFIGS_KEY]) {
    const before = new Map(raw)
    raw.set(key, '{damaged')
    const damaged = new Map(raw)
    await assert.rejects(store().load(), /tracker_.*_invalid/)
    await assert.rejects(store().saveSyncPreferenceChanges({ autoSyncEnabled: false }), /tracker_.*_invalid/)
    assert.deepEqual(raw, damaged, 'a damaged existing document must not become an empty/default write')
    raw.clear(); for (const [name, value] of before) raw.set(name, value)
  }
  console.log('Tracker preference fields, rollback, mapping/config concurrent intents, nested methods and stale profile guard checked')
}
async function run() {
  await runDirectConnection()
  await runKitsuProvider()
  await runAdditionalProvider('bangumi'); await runAdditionalProvider('mangaupdates')
  await runProvider('anilist'); await runProvider('myanimelist')
  await runPreferenceOwner()
  // API binding observes options passed by the actual adapter, not real native HTTP delivery.
  const adapter = new mal.HarmonyMyAnimeListTrackerHttpAdapter()
  await adapter.request({ method: 'PATCH', url: 'https://owned.invalid/status', headers: {
    contentType: 'application/x-www-form-urlencoded' }, body: 'num_chapters_read=2' })
  assert.equal(networkCalls.at(-1).options.customMethod, 'PATCH')
  assert.equal(networkCalls.at(-1).options.method, 'POST')
  assert.equal(networkCalls.at(-1).options.extraData, 'num_chapters_read=2')
  await adapter.request({ method: 'GET', url: 'https://owned.invalid/status', headers: {} })
  assert.equal(networkCalls.at(-1).options.method, 'GET'); assert.equal(networkCalls.at(-1).options.customMethod, undefined)
  assert.equal(destroyed, 2)
  console.log('Host binding checks completed; live accounts and native NetworkKit transport remain unaccepted.')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
