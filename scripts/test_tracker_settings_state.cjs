const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..', 'entry/src/main/ets')
const read = path => readFileSync(resolve(root, path), 'utf8')
function evaluate(source, globals = {}) {
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
  const exports = {}
  new Function('exports', ...Object.keys(globals), output)(exports, ...Object.values(globals))
  return exports
}
const globals = {
  $r: key => key,
  buffer: Buffer,
  connectTrackerBrowserAuthorization: () => ({ revision: 0 }),
  Scroller: class {},
  FormTitleActionState: class {},
  DiagnosticLogger: { warn() {} },
  AppStrings: { get: key => key }, connectLanguageState: () => ({}),
  console: { info() {}, warn() {} },
  AssetStoreTrackerCredentialSecretStore: class { isAvailable() { return true } },
}
function pureDeclarations(path) {
  const source = read(path)
  const ast = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true)
  return ast.statements.filter(node => ts.isVariableStatement(node) || ts.isFunctionDeclaration(node))
    .map(node => node.getText(ast)).join('\n')
}
const model = evaluate(pureDeclarations('model/TrackerModels.ets'), globals)
const pending = evaluate(pureDeclarations('model/TrackerPendingSyncStore.ets'), globals)
const source = read('pages/TrackerSettingsPage.ets')
const prefix = (source.slice(0, source.indexOf('  @Builder')) + '\n}')
  .replace(/import[\s\S]*?from '[^']+'\n/g, '')
  .replace('@ComponentV2', '').replace(/@(Local|Param|Event) /g, '')
  .replace(/@Monitor\('[^']+'\)/g, '').replace('export struct', 'export class')
const { TrackerSettingsPage } = evaluate(prefix, { ...globals, ...model, ...pending })
const ids = page => page.visibleProviders().map(provider => provider.providerId)
const drain = async () => { for (let i = 0; i < 30; i++) await Promise.resolve() }
const fresh = () => JSON.parse(JSON.stringify(model.DEFAULT_TRACKER_PREFERENCES))
function fixture(providerId = '') {
  let preferences = fresh(), loads = 0, failLoad = false
  const store = {
    async load() { loads++; if (failLoad) throw Error('fixture'); return preferences },
    async saveProviderOAuthConfig(providerId, clientId, redirectUri) {
      preferences.providerOAuthConfigs = [{ providerId, clientId, redirectUri }]
      return preferences
    },
    async prepareConnect(providerId) {
      preferences.accounts = preferences.accounts.map(account => account.providerId === providerId
        ? { ...account, status: 'auth_pending', credentialAccountKey: 'fixture-account' } : account)
      return { status: 'ready', providerId, authorizationUrl: `https://fixture.invalid/${providerId}/authorize` }
    },
  }
  const page = new TrackerSettingsPage()
  page.providerId = providerId
  page.trackerPreferencesStore = () => store
  page.pendingSyncStore = () => ({ loadPendingProgress: async () => [] })
  page.showToast = () => {}
  return { page, store, preferences: () => preferences, loads: () => loads,
    replace: next => { preferences = next }, fail: value => { failLoad = value } }
}
async function run() {
  const f = fixture(), page = f.page, anilist = model.TRACKER_PROVIDER_CONFIGS[0]
  assert.equal(page.authPreparationMessageKey, 'tracker_message_loading')
  assert.equal(page.canPrepareConnect(anilist), false)
  assert.equal(page.providerOAuthConfigs.length, 0)
  await page.reloadSettings()
  assert.equal(page.authPreparationMessageKey, '')
  // User adopted Bangumi token / MangaUpdates login and Kitsu email login on 2026-10-31.
  assert.deepEqual(ids(page), ['anilist', 'myanimelist', 'kitsu', 'mangaupdates', 'bangumi'])
  page.credentialSecretStore.isAvailable = () => false
  await page.reloadSettings()
  assert.equal(page.authPreparationMessageKey, 'tracker_message_connect_unavailable')
  page.credentialSecretStore.isAvailable = () => true
  f.fail(true); await page.reloadSettings()
  assert.equal(page.authPreparationMessageKey, 'tracker_message_load_failed')
  f.fail(false)

  const saved = fresh()
  saved.accounts[2] = { providerId: 'kitsu', status: 'error', credentialAccountKey: 'old-account' }
  saved.accounts[4] = { providerId: 'bangumi', status: 'disconnected', profile: { displayName: 'saved' } }
  saved.comicMappings = [{ comicId: 'comic', providerId: 'mangaupdates', providerTitleId: 'title',
    mappingState: 'candidate', userConfirmed: false, createdAt: 1 }]
  saved.providerOAuthConfigs = [{ providerId: 'anilist', clientId: 'saved-client', redirectUri: model.TRACKER_APP_CALLBACK_URI }]
  f.replace(saved)
  const before = f.loads()
  page.onRefreshRevision(); await drain()
  assert.equal(f.loads(), before + 1, 'root revision executes real reload')
  assert.deepEqual(ids(page), ['anilist', 'myanimelist', 'kitsu', 'mangaupdates', 'bangumi'])
  assert.equal(page.configuredProvider(anilist).clientId, 'saved-client')

  const child = fixture('anilist')
  child.replace(saved); await child.page.reloadSettings()
  const opened = []
  child.page.active = true
  child.page.context = () => ({ startAbility: async want => {
    opened.push(want)
    if (opened.length === 1) throw Error('browser unavailable')
  } })
  assert.deepEqual(ids(child.page), ['anilist'])
  const childLoads = child.loads()
  child.page.onRefreshRevision(); await drain()
  assert.equal(child.loads(), childLoads, 'root revision does not refill an edited child form')
  child.page.prepareConnect(anilist); await drain()
  assert.equal(child.page.findAccount(anilist).status, 'auth_pending')
  assert.equal(child.page.canDisconnectProvider(anilist), false)
  assert.equal(child.page.canRefreshProvider(anilist), false)
  assert.equal(child.page.preparedAuthorizationUrl, 'https://fixture.invalid/anilist/authorize')
  assert.equal(child.page.authPreparationMessageKey, '')
  assert.equal(model.getTrackerAccountStatusLabel('auth_pending'), model.getTrackerAccountStatusLabel('disconnected'))
  assert.equal(model.getTrackerAccountDetail(child.page.findAccount(anilist), true), model.getTrackerAccountDetail({ status: 'disconnected' }, true))
  assert.deepEqual(opened, [{ action: 'ohos.want.action.viewData', uri: 'https://fixture.invalid/anilist/authorize' }])
  const pendingAccount = child.page.findAccount(anilist)
  child.page.prepareConnect(anilist); await drain()
  assert.equal(opened.length, 2, 'retry opens AniList authorization again')
  assert.notEqual(child.page.findAccount(anilist), pendingAccount, 'AniList retry prepares a new authorization')
  const myAnimeList = model.TRACKER_PROVIDER_CONFIGS.find(provider => provider.providerId === 'myanimelist')
  child.page.providerId = myAnimeList.providerId
  child.page.providerOAuthConfigs.push({ providerId: myAnimeList.providerId, clientId: 'fixture-mal' })
  child.page.prepareConnect(anilist); await drain()
  assert.equal(opened.length, 2, 'a stale action cannot reopen the previous service')
  child.page.prepareConnect(myAnimeList); await drain()
  assert.equal(opened.at(-1).uri, 'https://fixture.invalid/myanimelist/authorize')
  child.page.accounts = [{ providerId: 'myanimelist', status: 'error', credentialAccountKey: 'failed-first-auth' }]
  assert.equal(child.page.canDisconnectProvider(myAnimeList), false)
  assert.equal(child.page.canRefreshProvider(myAnimeList), false)
  child.page.accounts = [{ providerId: 'myanimelist', status: 'connected', credentialAccountKey: 'linked' }]
  assert.equal(child.page.canDisconnectProvider(myAnimeList), true)
  assert.equal(child.page.canRefreshProvider(myAnimeList), true)
  const rootLogin = fixture().page
  rootLogin.active = true
  const rootActions = []
  rootLogin.context = () => ({ async startAbility(want) { rootActions.push(['browser', want.uri]) } })
  rootLogin.openProviderDialog = provider => rootActions.push(['dialog', provider.providerId])
  rootLogin.confirmDisconnectAccount = provider => rootActions.push(['confirm disconnect', provider.providerId])
  await rootLogin.reloadSettings()
  rootLogin.openProvider(myAnimeList); await drain()
  assert.equal(rootLogin.findAccount(myAnimeList).status, 'auth_pending')
  const kitsuProvider = model.TRACKER_PROVIDER_CONFIGS.find(provider => provider.providerId === 'kitsu')
  rootLogin.openProvider(kitsuProvider)
  rootLogin.accounts = [{ providerId: 'kitsu', status: 'connected', credentialAccountKey: 'linked' }]
  rootLogin.openProvider(kitsuProvider)
  assert.deepEqual(rootActions, [
    ['browser', 'https://fixture.invalid/myanimelist/authorize'],
    ['dialog', 'kitsu'],
    ['confirm disconnect', 'kitsu'],
  ])
  const callbackUri = model.TRACKER_APP_CALLBACK_URI
  const callbackPreferences = fresh()
  callbackPreferences.accounts[0] = { providerId: 'anilist', status: 'auth_pending', credentialAccountKey: 'expected' }
  callbackPreferences.providerOAuthConfigs = [{ providerId: 'anilist', clientId: 'fixture-client' }]
  const storedSecrets = []
  const { TrackerOAuthCompletionService } = evaluate(
    read('model/TrackerOAuthCompletionService.ets').replace(/import[\s\S]*?from '[^']+'\n/g, ''), {
      ...globals, ...model,
      BackupRestoreActivity: { runWrite: operation => operation() },
      TrackerPreferencesStore: class {
        async load() { return callbackPreferences }
        async saveAccountIfCurrent(previous, next, write) {
          const index = callbackPreferences.accounts.indexOf(previous)
          assert.notEqual(index, -1)
          await write?.()
          callbackPreferences.accounts[index] = next
          return { applied: true, preferences: callbackPreferences }
        }
      },
      TrackerAccountRefreshService: class {
        async refreshAccounts() { return { refreshedCount: 1, preferences: callbackPreferences } }
      },
    })
  const completion = new TrackerOAuthCompletionService({}, { secretStore: {
    async writeToken(request) { storedSecrets.push(request.secretKind); return { ok: true } },
  } })
  assert.equal(await completion.completeBrowserCallback(callbackUri + '#state=wrong&access_token=fixture&token_type=Bearer'), undefined)
  assert.equal(await completion.completeBrowserCallback(callbackUri + '-extra#state=expected&access_token=fixture&token_type=Bearer'), undefined)
  assert.equal(callbackPreferences.accounts[0].status, 'auth_pending')
  assert.deepEqual(storedSecrets, [])
  const incomplete = await completion.completeBrowserCallback(callbackUri + '#state=expected')
  assert.equal(incomplete.reason, 'invalid_callback')
  assert.equal(callbackPreferences.accounts[0].status, 'error')
  assert.deepEqual(storedSecrets, [])
  callbackPreferences.accounts[0] = { providerId: 'anilist', status: 'auth_pending', credentialAccountKey: 'expected' }
  const callback = callbackUri + '#state=expected&access_token=fixture&token_type=Bearer'
  assert.equal((await completion.completeBrowserCallback(callback)).status, 'connected')
  assert.equal(await completion.completeBrowserCallback(callback), undefined, 'replayed callback does not overwrite the account')
  assert.deepEqual(storedSecrets, ['access_token'])
  callbackPreferences.accounts[1] = { providerId: 'myanimelist', status: 'auth_pending', credentialAccountKey: 'mal-state' }
  callbackPreferences.providerOAuthConfigs.push({ providerId: 'myanimelist', clientId: 'fixture-mal' })
  const exchanges = []
  const malCompletion = new TrackerOAuthCompletionService({}, {
    secretStore: {
      async readToken() { return new TextEncoder().encode('fixture-verifier') },
      async writeToken() { return { ok: true } },
      async deleteToken() {},
    },
    tokenExchanger: {
      async exchange(provider, code, verifier) {
        exchanges.push([provider.providerId, code, verifier])
        return { ok: true, accessToken: 'fixture-token' }
      },
    },
  })
  const malCallback = callbackUri + '?state=mal-state&code=fixture-code'
  assert.equal(await malCompletion.completeBrowserCallback(malCallback + '#code=wrong'), undefined)
  assert.equal((await malCompletion.completeBrowserCallback(malCallback)).status, 'connected')
  assert.deepEqual(exchanges, [['myanimelist', 'fixture-code', 'fixture-verifier']])
  assert.equal(child.page.configuredProvider(anilist).clientId, 'saved-client')
  assert.deepEqual(child.preferences().comicMappings, saved.comicMappings, 'navigation does not migrate or delete saved data')

  const index = read('pages/Index.ets')
  const destination = index.slice(index.indexOf('} else if (name === RouteName.TRACKER_SETTINGS)'),
    index.indexOf('  onBackPress(): boolean'))
  const onShown = destination.match(/\.onShown\(\(\) => \{([\s\S]*?)\n\s*\}\)/)[1]
  const revision = { trackerSettingsRevision: 0 }
  new Function(onShown).call(revision)
  assert.equal(revision.trackerSettingsRevision, 1)
  assert.ok(destination.includes('refreshRevision: this.trackerSettingsRevision'))
  assert.ok(source.includes('this.providerId.length === 0 && this.pendingSummary.totalCount > 0'))
  // Execute login prerequisites and secret lifetime, rather than checking builder syntax.
  const bangumi = model.TRACKER_PROVIDER_CONFIGS.find(p => p.providerId === 'bangumi')
  const mu = model.TRACKER_PROVIDER_CONFIGS.find(p => p.providerId === 'mangaupdates')
  page.loading = false; page.secureStorageAvailable = true
  assert.equal(page.canPrepareConnect(bangumi), true)
  page.directSecret = 'token'
  assert.equal(page.canPrepareConnect(bangumi), true, 'the registered Bangumi app enables new browser logins')
  assert.equal(page.canPrepareConnect(mu), false, 'password login also needs a username')
  page.directUsername = 'user'
  assert.equal(page.canPrepareConnect(mu), true)
  page.busyProviderId = 'mangaupdates'
  assert.equal(page.canPrepareConnect(bangumi), false, 'no competing account submission')
  page.busyProviderId = ''
  page.accounts = [{ providerId: 'bangumi', status: 'connected', credentialAccountKey: 'saved' }]
  assert.equal(page.canRefreshProvider(bangumi), true)
  page.aboutToDisappear()
  assert.equal(page.directSecret, '')
  assert.equal(page.directUsername, '')
  console.log('PASS: Tracker production page state, provider routing, revision/ready reload, saved-data retention; direct-login prerequisites and secret lifetime (not device visual acceptance).')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
