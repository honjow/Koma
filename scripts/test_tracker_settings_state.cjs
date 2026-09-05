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
      return { status: 'ready', authorizationUrl: 'https://fixture.invalid/authorize' }
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
  page.setProviderClientId(anilist, 'ignored during load')
  assert.equal(page.providerOAuthConfigs.length, 0)
  await page.reloadSettings()
  assert.equal(page.authPreparationMessageKey, '')
  assert.deepEqual(ids(page), ['anilist', 'myanimelist'])
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
  saved.providerOAuthConfigs = [{ providerId: 'anilist', clientId: 'saved-client', redirectUri: 'https://fixture.invalid/callback' }]
  f.replace(saved)
  const before = f.loads()
  page.onRefreshRevision(); await drain()
  assert.equal(f.loads(), before + 1, 'root revision executes real reload')
  assert.deepEqual(ids(page), ['anilist', 'myanimelist', 'kitsu', 'mangaupdates', 'bangumi'])
  assert.equal(page.providerClientId(anilist), 'saved-client')
  assert.equal(page.mappingSummary.total, 1)
  assert.equal(page.mappingSummary.candidate, 1)

  const child = fixture('anilist')
  child.replace(saved); await child.page.reloadSettings()
  assert.deepEqual(ids(child.page), ['anilist'])
  const childLoads = child.loads()
  child.page.onRefreshRevision(); await drain()
  assert.equal(child.loads(), childLoads, 'root revision does not refill an edited child form')
  child.page.prepareConnect(anilist); await drain()
  assert.equal(child.page.findAccount(anilist).status, 'auth_pending')
  assert.equal(child.page.preparedAuthorizationUrl, 'https://fixture.invalid/authorize')
  assert.equal(child.page.authPreparationMessageKey, 'tracker_message_auth_ready')
  child.page.setProviderOAuthCallbackUri(anilist, 'https://fixture.invalid/callback?code=test')
  assert.equal(child.page.canCompleteOAuthCallback(anilist), true, 'callback is immediately reachable after ready')
  assert.equal(child.page.providerClientId(anilist), 'saved-client')
  assert.deepEqual(child.preferences().comicMappings, saved.comicMappings, 'navigation does not migrate or delete saved data')

  const index = read('pages/Index.ets')
  const start = index.indexOf('  private openTrackerProvider(')
  const end = index.indexOf('  private openSettingsPane(', start)
  const constants = read('common/Constants.ets')
  const routeName = constants.match(/TRACKER_PROVIDER_SETTINGS: string = '([^']+)'/)[1]
  const { RouteFixture } = evaluate(`export class RouteFixture { ${index.slice(start, end)} }`, {
    ...globals, ...model, RouteName: { TRACKER_PROVIDER_SETTINGS: routeName },
  })
  const route = new RouteFixture(), pushed = []
  route.appPathStack = { pushPath: params => pushed.push(params) }
  route.openTrackerProvider('myanimelist')
  assert.deepEqual(pushed, [{ name: routeName, param: { providerId: 'myanimelist' } }])
  assert.equal(route.trackerProviderTitle(pushed[0].param), 'MyAnimeList')
  const destination = index.slice(index.indexOf('} else if (name === RouteName.TRACKER_SETTINGS)'),
    index.indexOf('} else if (name === RouteName.TRACKER_PROVIDER_SETTINGS)'))
  const onShown = destination.match(/\.onShown\(\(\) => \{([\s\S]*?)\n\s*\}\)/)[1]
  const revision = { trackerSettingsRevision: 0 }
  new Function(onShown).call(revision)
  assert.equal(revision.trackerSettingsRevision, 1)
  assert.ok(destination.includes('refreshRevision: this.trackerSettingsRevision'))
  assert.ok(index.includes('providerId: (param as TrackerProviderRouteParam).providerId'))
  assert.ok(source.includes('this.providerId.length === 0 && this.pendingSummary.totalCount > 0'))
  assert.ok(source.includes('this.providerId.length === 0 && this.mappings.length > 0'))
  const providerRow = source.slice(source.indexOf('private ProviderRow('), source.indexOf('private ProviderOAuthConfigForm('))
  assert.ok(!providerRow.includes('suffixPaddingRight: 0'), 'account actions inherit the existing 12vp suffix inset')
  assert.ok(read('components/ui/ConciseListRow.ets').includes('suffixPaddingRight: Length = ThemeConstants.SPACE_MD'))
  assert.ok(source.includes("if (this.findAccount(provider).status === 'auth_pending')"))
  const configForm = source.slice(source.indexOf('private ProviderOAuthConfigForm('),
    source.indexOf('private ProviderOAuthConfigActions('))
  const configActions = source.slice(source.indexOf('private ProviderOAuthConfigActions('),
    source.indexOf('private ProviderOAuthCallbackForm('))
  assert.ok(!configForm.includes('KomaActionButton(') &&
    configActions.includes("label: s('common_save')") && configActions.includes("kind: 'primary'") &&
    configActions.includes('fullWidth: true') && configActions.includes('isEnabled: !this.loading') &&
    configActions.includes('void this.saveProviderOAuthConfig(provider)') &&
    configActions.includes('.padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })') &&
    !/compact:|controlHeight:/.test(configActions), 'save uses the existing card-external full-width primary action and default height')
  assert.match(source.slice(source.indexOf('  build() {')),
    /this\.ProvidersCard\(\)[\s\S]*?if \(this\.providerId\.length > 0\)[\s\S]*?if \(provider\.supportStatus === 'available'\) \{\s*ListItem\(\) \{\s*this\.ProviderOAuthConfigActions\(provider\)[\s\S]*?this\.StatusCard\(\)/,
    'save is a separate item after the form card and before result, only on available single-provider pages')
  console.log('PASS: Tracker production page state, provider routing, revision/ready reload, saved-data retention; builder contracts checked (not device visual acceptance).')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
