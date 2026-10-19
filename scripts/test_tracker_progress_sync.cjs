// Production service/client requests on host API bindings; not live-account or NetworkKit acceptance.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
const stores = new Map(), modules = new Map(), networkCalls = []
let nextNetworkResponse = { responseCode: 200, result: '{}' }, destroyed = 0
const bindings = {
  '@kit.ArkData': { preferences: { async getPreferences(_context, name) {
    if (!stores.has(name)) stores.set(name, new Map())
    const data = stores.get(name)
    return { async get(key, fallback) { return data.has(key) ? data.get(key) : fallback },
      async put(key, value) { data.set(key, value) }, async flush() {} }
  } } },
  '@kit.ArkTS': { buffer: Buffer },
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
async function run() {
  await runProvider('anilist'); await runProvider('myanimelist')
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
