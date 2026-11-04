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
  '@kit.ArkTS': { buffer: Buffer, util: { generateRandomUUID: () => 'owned-direct-' + (++nextDirectKey),
    TextEncoder: class { encodeInto(s) { return new Uint8Array(Buffer.from(s)) } },
    Base64Helper: class { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64') } } } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createRandom: () => ({
    generateRandomSync: (size) => ({ data: require('node:crypto').randomBytes(size) }),
  }) } },
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
async function runAssetTokenStorage() {
  const tags = ['ALIAS', 'SECRET', 'DATA_LABEL_CRITICAL_1', 'DATA_LABEL_CRITICAL_2', 'DATA_LABEL_CRITICAL_3',
    'DATA_LABEL_CRITICAL_4', 'GROUP_ID', 'RETURN_TYPE', 'RETURN_LIMIT', 'ACCESSIBILITY', 'CONFLICT_RESOLUTION']
  const saved = new Map()
  let rejectRoot = false
  const key = value => Buffer.from(value).toString('hex')
  const match = (attributes, query) => [...query].every(([tag, value]) =>
    !(value instanceof Uint8Array || ArrayBuffer.isView(value)) || key(attributes.get(tag) ?? []) === key(value))
  bindings['@kit.AssetStoreKit'] = { asset: {
    Tag: Object.fromEntries(tags.map(tag => [tag, tag])),
    Accessibility: { DEVICE_FIRST_UNLOCKED: 1 }, ConflictResolution: { OVERWRITE: 1 }, ReturnType: { ALL: 1 },
    async add(attributes) {
      assert.ok(attributes.get('SECRET').length <= 1024)
      if (rejectRoot && attributes.has('DATA_LABEL_CRITICAL_4')) throw { code: 401 }
      saved.set(key(attributes.get('ALIAS')), attributes)
    },
    async query(query) { return [...saved.values()].filter(attributes => match(attributes, query)) },
    async remove(query) {
      for (const [alias, attributes] of saved) if (match(attributes, query)) saved.delete(alias)
    },
  } }
  const { randomUUID } = require('node:crypto')
  bindings['@kit.ArkTS'] = {
    ...bindings['@kit.ArkTS'],
    buffer: { from(value, encoding) {
      const bytes = Buffer.from(value, encoding)
      return { buffer: Uint8Array.from(bytes).buffer, toString: enc => bytes.toString(enc) }
    } },
    util: { ...bindings['@kit.ArkTS'].util, generateRandomUUID: randomUUID },
  }
  modules.delete('model/TrackerModels')
  const { AssetStoreTrackerCredentialSecretStore } = load('model/TrackerModels')
  const store = new AssetStoreTrackerCredentialSecretStore()
  const ref = { providerId: 'anilist', accountKey: 'long-secret-test', secretKind: 'access_token' }
  const legacy = new Uint8Array([5, 1, 3])
  const long = Uint8Array.from({ length: 2501 }, (_, index) => index % 251)
  assert.equal((await store.writeToken({ ...ref, secretBytes: legacy })).ok, true)
  rejectRoot = true
  assert.equal((await store.writeToken({ ...ref, secretBytes: long })).ok, false)
  assert.deepEqual([...await store.readToken(ref)], [...legacy])
  assert.equal(saved.size, 1)
  rejectRoot = false
  assert.equal((await store.writeToken({ ...ref, secretBytes: long })).ok, true)
  assert.deepEqual([...await store.readToken(ref)], [...long])
  assert.equal(saved.size, 3)
  assert.equal((await store.deleteAccount(ref)).ok, true)
  assert.equal(saved.size, 0)
}
async function runBangumiBrowserOAuth() {
  stores.clear()
  const context = { filesDir: 'bangumi-oauth-fixture' }
  const provider = model.TRACKER_PROVIDER_CONFIGS.find(item => item.providerId === 'bangumi')
  const configuredClientId = provider.clientId
  const configuredClientSecret = provider.clientSecret
  provider.clientId = 'test-app'
  provider.clientSecret = 'test-secret'
  const bytes = new Map()
  const secretStore = {
    isAvailable: () => true,
    async readToken(request) { return bytes.get(request.secretKind) },
    async writeToken(request) { bytes.set(request.secretKind, request.secretBytes); return { ok: true } },
  }
  const store = new model.TrackerPreferencesStore(context, secretStore)
  const { HarmonyTrackerOAuthTokenExchanger, TrackerOAuthCompletionService } = load('model/TrackerOAuthCompletionService')
  const { readBangumiAccessToken, saveBangumiOAuthTokens } = load('model/BangumiTrackerOAuth')
  const callback = model.TRACKER_APP_CALLBACK_URI
  const start = model.prepareTrackerOAuthStart({ providerId: 'bangumi', state: 'expected', codeChallenge: '' }, true)
  assert.equal(start.status, 'ready')
  const authorization = new URL(start.authorizationUrl)
  assert.equal(authorization.hostname, 'bgm.tv')
  assert.equal(authorization.searchParams.get('redirect_uri'), callback)
  const wireState = authorization.searchParams.get('state')
  assert.equal(wireState, 'expected&redirect_uri=' + callback)
  assert.equal(model.parseTrackerOAuthCallback(callback + '?code=example&state=expected', 'expected', false, wireState).ok, true)
  assert.equal(model.parseTrackerOAuthCallback(callback + '?code=example&state=' + encodeURIComponent(wireState), 'expected', false, wireState).ok, true)
  assert.equal(model.parseTrackerOAuthCallback(callback + '?code=example&state=' + encodeURIComponent(wireState + 'x'), 'expected', false, wireState).ok, false)
  assert.equal(authorization.searchParams.has('code_challenge'), false)
  nextNetworkResponse = { responseCode: 200, result: JSON.stringify({
    access_token: 'original-access', refresh_token: 'original-refresh', expires_in: 3600,
  }) }
  const exchanged = await new HarmonyTrackerOAuthTokenExchanger().exchange(provider, 'example-code', '')
  const request = networkCalls.at(-1)
  const form = new URLSearchParams(request.options.extraData)
  assert.equal(request.url, 'https://bgm.tv/oauth/access_token')
  assert.equal(form.get('client_secret'), 'test-secret')
  assert.equal(form.get('code'), 'example-code')
  assert.equal(form.has('code_verifier'), false)
  assert.equal(exchanged.expiresIn, 3600)

  await store.saveAccounts([{ providerId: 'bangumi', status: 'auth_pending', credentialAccountKey: 'expected' }])
  const completion = new TrackerOAuthCompletionService(context, { secretStore,
    tokenExchanger: { async exchange() {
      nextNetworkResponse = { responseCode: 200, result: JSON.stringify({ id: 7, username: 'owned-user' }) }
      return exchanged
    } },
  })
  assert.equal(await completion.completeBrowserCallback(callback + '?state=unrelated&code=example-code'), undefined)
  const connected = await completion.completeBrowserCallback(callback + '?state=' + encodeURIComponent(wireState) + '&code=example-code')
  assert.equal(connected.status, 'connected')
  assert.ok(bytes.has('bangumi_oauth'))
  assert.equal(bytes.has('access_token'), false)
  const account = connected.preferences.accounts.find(item => item.providerId === 'bangumi')
  assert.equal(await readBangumiAccessToken(context, secretStore, account), 'original-access')

  await saveBangumiOAuthTokens(secretStore, 'expected', 'original-access', 'original-refresh', Date.now() - 1)
  nextNetworkResponse = { responseCode: 200, result: JSON.stringify({
    access_token: 'renewed-access', refresh_token: 'renewed-refresh', expires_in: 3600,
  }) }
  const beforeRenew = networkCalls.length
  const tokens = await Promise.all([readBangumiAccessToken(context, secretStore, account),
    readBangumiAccessToken(context, secretStore, account)])
  assert.deepEqual(tokens, ['renewed-access', 'renewed-access'])
  assert.equal(networkCalls.length, beforeRenew + 1)
  const renewal = new URLSearchParams(networkCalls.at(-1).options.extraData)
  assert.equal(renewal.get('grant_type'), 'refresh_token')
  assert.equal(renewal.get('refresh_token'), 'original-refresh')
  assert.equal(await readBangumiAccessToken(context, secretStore, account), 'renewed-access')
  provider.clientId = configuredClientId
  provider.clientSecret = configuredClientSecret
}
async function runProvider(providerId) {
  stores.clear()
  const preferences = new Map([
    [model.TRACKER_ACCOUNTS_KEY, JSON.stringify([{ providerId, status: 'connected', credentialAccountKey: 'owned-test' }])],
    [model.TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify([{ providerId, comicId: 'owned-book', providerTitleId: '123',
      mappingState: 'confirmed', userConfirmed: true, createdAt: 1 }])],
    [model.TRACKER_AUTO_SYNC_ENABLED_KEY, true], [model.TRACKER_UPDATE_STRATEGY_KEY, 'on_chapter_complete'],
  ])
  stores.set(model.TRACKER_PREFERENCES_STORE_NAME, preferences)
  const calls = []; let fail = false; let aniListEntry = null
  const adapter = { async request(request) {
    calls.push(clone(request))
    if (fail) return { status: 503, body: '{}' }
    if (providerId === 'anilist' && JSON.parse(request.body).query.includes('mediaListEntry')) {
      return { status: 200, body: JSON.stringify({ data: { Media: { mediaListEntry: aniListEntry } } }) }
    }
    // Remote on-hold state must be parsed independently of local chapter completion.
    return { status: 200, body: providerId === 'anilist'
      ? JSON.stringify({ data: { SaveMediaListEntry: { mediaId: 123, progress: 2, status: 'PAUSED' } } })
      : JSON.stringify({ num_chapters_read: 2, status: 'on_hold' }) }
  } }
  const client = providerId === 'anilist' ? new ani.AniListTrackerClient(adapter) : new mal.MyAnimeListTrackerClient(adapter)
  if (providerId === 'anilist') {
    const absent = await client.fetchProgress('owned-test-token', '123')
    assert.equal(absent.ok, true)
    assert.equal(absent.value, undefined)
    aniListEntry = { mediaId: 123, progress: 17, status: 'CURRENT' }
    assert.equal((await client.fetchProgress('owned-test-token', '123')).value.progress, 17)
    aniListEntry = null
  }
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
  await client.pushProgress('owned-test-token', '123', undefined, undefined,
    { volumes: 3, score: 8, startedAt: '2026-01-02' })
  const fieldsRequest = calls.at(-1)
  if (providerId === 'anilist') {
    const variables = JSON.parse(fieldsRequest.body).variables
    assert.deepEqual(variables, { mediaId: 123, volumes: 3, score: 8,
      startedAt: { year: 2026, month: 1, day: 2 } })
  } else {
    const fields = new URLSearchParams(fieldsRequest.body)
    assert.equal(fields.get('num_volumes_read'), '3')
    assert.equal(fields.get('score'), '8')
    assert.equal(fields.get('start_date'), '2026-01-02')
    assert.equal(fields.has('status'), false)
    assert.equal(fields.has('num_chapters_read'), false)
  }
  const beforeInvalid = calls.length
  assert.equal((await client.pushProgress('owned-test-token', 'invalid', 2)).errorCode, 'not_found')
  assert.equal(calls.length, beforeInvalid)
  console.log(providerId + ': production first push, incomplete chapter, failure queue/retry and explicit status intent checked')
}
async function runAdditionalProvider(providerId) {
  stores.clear();let count, remoteStatus=providerId==='bangumi'?4:4, fail=false;const calls=[];
  const preferences=new Map([
    [model.TRACKER_ACCOUNTS_KEY,JSON.stringify([{providerId,status:'connected',credentialAccountKey:'owned-test',profile:{username:'owned-user'}}])],
    [model.TRACKER_COMIC_MAPPINGS_KEY,JSON.stringify([{providerId,comicId:'owned-book',providerTitleId:'123',mappingState:'confirmed',userConfirmed:true,createdAt:1}])],
    [model.TRACKER_AUTO_SYNC_ENABLED_KEY,true],[model.TRACKER_UPDATE_STRATEGY_KEY,'on_chapter_complete']]);
  stores.set(model.TRACKER_PREFERENCES_STORE_NAME,preferences);
  const adapter={async request(request){
    calls.push(clone(request));if(fail)return {status:503,body:'{}'};
    if(request.url.includes('/search/subjects')||request.url.endsWith('/series/search')) return {status:200,body:JSON.stringify(providerId==='bangumi'?{data:[{id:123,name:'Owned manga',platform:'漫画'}]}:{results:[{record:{series_id:123,title:'Owned manga'}}]})};
    if (providerId === 'bangumi') {
      assert.equal(request.url, request.method === 'GET'
        ? 'https://api.bgm.tv/v0/users/owned-user/collections/123'
        : 'https://api.bgm.tv/v0/users/-/collections/123')
    }
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
    secretStore:{isAvailable:()=>true,readToken:async({secretKind})=>secretKind==='access_token'?Buffer.from('owned-token'):undefined},
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
  const search=new TrackerMappingSearchService({},{secretStore:{isAvailable:()=>true,readToken:async({secretKind})=>secretKind==='access_token'?Buffer.from('owned-token'):undefined},
    ...(providerId==='bangumi'?{bangumiClient:client}:{mangaUpdatesClient:client})});
  const matched=await search.refreshComicMappingCandidates({id:'unmapped-book',title:'Owned manga'},providerId,15);
  assert.equal(matched.mappedCount,1,'connected provider must traverse actual mapping service and client');
  assert.equal(matched.results[0].mapping.providerTitleId,'123');
  assert.equal(matched.results[0].mapping.userConfirmed,false,'search never silently binds');
  const newBinding = { ...matched.results[0].mapping, mappingState: 'confirmed', userConfirmed: true }
  fail = true
  assert.equal((await service.bindComic(newBinding, 1)).status, 'failed')
  assert.equal(JSON.parse(preferences.get(model.TRACKER_COMIC_MAPPINGS_KEY))
    .find(mapping => mapping.comicId === 'unmapped-book').mappingState, 'candidate')
  fail = false
  const beforeBinding = calls.length
  assert.equal((await service.bindComic(newBinding, 1)).providerStatus, '4')
  assert.equal(count, 2)
  assert.equal(calls.length, beforeBinding + 1, 'binding an existing remote entry must not rewrite its progress')
  assert.equal((await service.editComicProgress('unmapped-book', providerId, 5)).providerProgress, 5)
  assert.equal(remoteStatus, 4, 'editing progress must preserve remote reading status')
  const beforeUnbind = calls.length
  const unbound = await service.unbindComic('unmapped-book', providerId)
  assert.equal(unbound.comicMappings.some(mapping => mapping.comicId === 'unmapped-book'), false)
  assert.equal(calls.length, beforeUnbind, 'unlinking a book must not delete the remote entry')

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
  let cleanupFailed = false
  const secretStore = { isAvailable: () => true, readToken: async () => new Uint8Array(Buffer.from('owned-token')),
    writeToken: async () => ({ ok: true }), deleteAccount: async () => cleanupFailed ? ({ ok: false, error: { code: 'locked' } }) : ({ ok: true }), deleteToken: async () => ({ ok: true }) }
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
  cleanupFailed = true
  const signedOut = await store().disconnectAccount('anilist')
  assert.equal(signedOut.accounts[0].status, 'disconnected')
  assert.equal(signedOut.accounts[0].credentialAccountKey, 'owned-account')
  resume({ ok: true, value: { providerUserId: '1', username: 'owned-user' } })
  const result = await refresh
  assert.equal(result.refreshedCount, 0); assert.equal(result.skippedCount, 1)
  assert.equal((await store().load()).accounts.find(account => account.providerId === 'anilist').status, 'disconnected')
  await store().saveProviderOAuthConfig('anilist', 'owned-a', model.TRACKER_APP_CALLBACK_URI)
  assert.equal((await store().prepareConnect('anilist')).status, 'ready')
  const pending = (await store().load()).accounts.find(account => account.providerId === 'anilist')
  assert.equal(pending.status, 'auth_pending')
  assert.notEqual(pending.credentialAccountKey, 'owned-account')
  cleanupFailed = false
  assert.equal((await store().prepareReconnect('anilist')).accounts[0].credentialAccountKey, pending.credentialAccountKey)
  const cleaned = await store().disconnectAccount('anilist')
  assert.equal(cleaned.accounts[0].credentialAccountKey, undefined)
  assert.equal(model.normalizeTrackerAccount({ providerId: 'anilist', status: 'error', statusReason: 'locked' }, true).status,
    'disconnected')
  assert.equal(model.normalizeTrackerAccount({ providerId: 'anilist', status: 'error',
    credentialAccountKey: 'owned-session', statusReason: 'invalid_callback' }, true).status, 'error')

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
async function runSimultaneousProgress() {
  stores.clear()
  const providers = ['anilist', 'myanimelist', 'bangumi']
  stores.set(model.TRACKER_PREFERENCES_STORE_NAME, new Map([
    [model.TRACKER_ACCOUNTS_KEY, JSON.stringify(providers.map(providerId =>
      ({ providerId, status: 'connected', credentialAccountKey: providerId })))],
    [model.TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify(providers.map(providerId =>
      ({ providerId, comicId: 'owned-book', providerTitleId: '123', mappingState: 'confirmed', userConfirmed: true, createdAt: 1 })))],
    [model.TRACKER_AUTO_SYNC_ENABLED_KEY, true],
    [model.TRACKER_UPDATE_STRATEGY_KEY, 'on_chapter_complete'],
  ]))
  const writes = new Map()
  const client = providerId => ({
    async fetchProgress() { return { ok: true } },
    async pushProgress(_token, providerTitleId, progress) {
      writes.set(providerId, progress)
      return providerId === 'myanimelist' ? { ok: false } :
        { ok: true, value: { providerId, providerTitleId, progress, completed: false } }
    },
  })
  const pending = new TrackerPendingSyncStore({})
  const service = new TrackerProgressSyncService({}, {
    pendingStore: pending,
    secretStore: { isAvailable: () => true, readToken: async ({ secretKind }) =>
      secretKind === 'access_token' ? Buffer.from('owned-test-token') : undefined },
    aniListClient: client('anilist'),
    myAnimeListClient: client('myanimelist'),
    bangumiClient: client('bangumi'),
  })
  const progress = { comicId: 'owned-book', chapterId: 'chapter33', completed: true,
    pageIndex: 0, totalPages: 1, progressRatio: 1, updatedAt: 1 }
  await service.pushReadingProgress(progress, ['chapter33'], 'on_chapter_complete', 10, undefined, 33)
  for (const providerId of providers) assert.equal(writes.get(providerId), 33)
  const pendingWrites = await pending.loadPendingProgress()
  assert.equal(pendingWrites.length, 1)
  assert.equal(pendingWrites[0].providerId, 'myanimelist')
  writes.clear()
  await service.pushReadingProgress(progress, ['chapter33'], 'manual', 11, 'bangumi', 33)
  assert.deepEqual([...writes.entries()], [['bangumi', 33]])
  console.log('Three bound providers receive chapter 33; only the failed provider is queued; manual sync targets one provider')
}
async function runChapterCompletionBeforeClose() {
  const { ReaderTrackerProgressCoordinator } = load('model/TrackerReadingProgress')
  let flushSucceeds = false
  const submitted = []
  const coordinator = new ReaderTrackerProgressCoordinator(
    { flush: () => flushSucceeds },
    { async pushReadingProgress(progress, _ids, trigger, _now, _provider, count) {
      submitted.push({ chapter: progress.chapterId, trigger, count })
      return { status: 'synced' }
    } })
  const base = { comicId: 'owned-book', chapterId: 'chapter33', completed: true,
    pageIndex: 9, totalPages: 10, progressRatio: 1, updatedAt: 1 }
  coordinator.beginReading()
  coordinator.observe(base, ['chapter33', 'chapter34'], 33)
  assert.equal(submitted.length, 0, 'a failed commit must not write to the website')
  flushSucceeds = true
  coordinator.observe({ ...base, chapterId: 'chapter34', completed: false, pageIndex: 0 }, ['chapter33', 'chapter34'], 34)
  assert.deepEqual(submitted, [{ chapter: 'chapter33', trigger: 'on_chapter_complete', count: 33 }])
  coordinator.observe(base, ['chapter33', 'chapter34'], 33)
  assert.equal(submitted.length, 1, 'an already submitted completion must not repeat')
  coordinator.observe({ ...base, chapterId: 'chapter34' }, ['chapter33', 'chapter34'], 34)
  assert.deepEqual(submitted[1], { chapter: 'chapter34', trigger: 'on_chapter_complete', count: 34 })
  console.log('Chapter completion deferred by a failed local commit retries on the next page without closing the reader')
}
async function run() {
  await runChapterCompletionBeforeClose()
  await runSimultaneousProgress()
  await runBangumiBrowserOAuth()
  await runDirectConnection()
  await runKitsuProvider()
  await runAdditionalProvider('bangumi'); await runAdditionalProvider('mangaupdates')
  await runProvider('anilist'); await runProvider('myanimelist')
  await runPreferenceOwner()
  // API binding observes options passed by the actual adapter, not real native HTTP delivery.
  const beforeAdapter = destroyed
  const adapter = new mal.HarmonyMyAnimeListTrackerHttpAdapter()
  await adapter.request({ method: 'PATCH', url: 'https://owned.invalid/status', headers: {
    contentType: 'application/x-www-form-urlencoded' }, body: 'num_chapters_read=2' })
  assert.equal(networkCalls.at(-1).options.customMethod, 'PATCH')
  assert.equal(networkCalls.at(-1).options.method, 'POST')
  assert.equal(networkCalls.at(-1).options.extraData, 'num_chapters_read=2')
  await adapter.request({ method: 'GET', url: 'https://owned.invalid/status', headers: {} })
  assert.equal(networkCalls.at(-1).options.method, 'GET'); assert.equal(networkCalls.at(-1).options.customMethod, undefined)
  assert.equal(destroyed - beforeAdapter, 2)
  await runAssetTokenStorage()
  console.log('Host binding checks completed; live accounts and native NetworkKit transport remain unaccepted.')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
