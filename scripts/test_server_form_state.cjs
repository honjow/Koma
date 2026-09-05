const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..', 'entry/src/main/ets')
const read = path => readFileSync(resolve(root, path), 'utf8')
const parse = source => ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
function evaluate(source, globals) {
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
  const exports = {}
  new Function('exports', ...Object.keys(globals), output)(exports, ...Object.values(globals))
  return exports
}
function enums(file) {
  const ast = parse(read(file))
  return evaluate(ast.statements.filter(ts.isEnumDeclaration).map(node => node.getText(ast)).join('\n'), {})
}
const globals = {
  AppStrings: { get: key => key }, buffer: { from: Buffer.from },
  console: { info() {}, warn() {}, error() {} },
  ...enums('remote/KomgaModels.ets'),
  ...enums('remote/WebDavModels.ets'),
  ...enums('remote/OpdsModels.ets'),
}
const storeSource = read('model/RemoteServerStore.ets')
const storeAst = parse(storeSource)
const constants = storeAst.statements.filter(ts.isVariableStatement).map(node => node.getText(storeAst)).join('\n')
const errorClass = storeAst.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'RemoteServerDraftError')
const errorKey = storeAst.statements.find(node => ts.isFunctionDeclaration(node) && node.name.text === 'remoteServerDraftErrorKey')
const storeClass = storeAst.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'RemoteServerStore')
const normalizers = ['KomgaClient', 'KavitaClient', 'WebDavClient', 'OpdsParser'].map(file => {
  const ast = parse(read(`remote/${file}.ets`))
  return ast.statements.filter(node => ts.isFunctionDeclaration(node) && /^normalize.*(?:BaseUrl|RootUrl)$/.test(node.name.text))
    .map(node => node.getText(ast)).join('\n')
}).join('\n')
const production = evaluate(`${constants}\n${normalizers}\n${errorClass.getText(storeAst)}\n${errorKey.getText(storeAst)}\n${storeClass.getText(storeAst)}`, globals)

function fixture() {
  const metadata = new Map(), secrets = new Map()
  let writes = 0
  const prefs = {
    async get(key, fallback) { return metadata.get(key) ?? fallback },
    async put(key, value) { writes++; metadata.set(key, value) },
    async delete(key) { writes++; metadata.delete(key) },
    async flush() {},
  }
  const store = new production.RemoteServerStore({})
  store.preferences = async () => prefs
  store.readCredentialAssetPayload = async (kind, ref) => secrets.get(`${kind}:${ref}`)
  store.writeCredentialAsset = async (kind, ref, value) => { writes++; secrets.set(`${kind}:${ref}`, value) }
  store.deleteCredentialAsset = async (kind, ref) => { writes++; secrets.delete(`${kind}:${ref}`) }
  return { store, metadata, secrets, prefs, writes: () => writes }
}
function pageClass(name) {
  const source = read(`pages/${name}ServerPage.ets`)
  const prefix = source.slice(0, source.indexOf('  @Builder')) + '\n}'
  const plain = prefix.replace(/import[\s\S]*?from '[^']+'\n/g, '')
    .replace('@ComponentV2', '').replace(/@Local /g, '').replace('export struct', 'export class')
  const klass = evaluate(plain, { ...globals, ...production, connectLanguageState: () => ({}) })[`${name}ServerPage`]
  const callbacks = [...source.matchAll(/change: \(value: string\) => \{([\s\S]*?)\n\s*\} \}/g)]
    .map(match => evaluate(`export function edit(value: string) {${match[1]}\n}`, {}).edit)
  assert.ok(callbacks.length >= 2, `${name}: extract actual field callbacks`)
  assert.equal((source.match(/isEnabled: !this.formBusy\(\), change:|isEnabled: !this.formBusy\(\), isPassword: true, change:/g) || []).length,
    callbacks.length, `${name}: every field has the native enabled binding`)
  assert.ok(source.includes('if (this.hasSavedConfig) {'), `${name}: removal follows metadata existence`)
  return { klass, callbacks }
}
function deferred() {
  let resolve
  const promise = new Promise(done => { resolve = done })
  return { promise, resolve }
}
const protocols = [
  { name: 'Komga', kind: 'komga', url: 'baseUrl', urlError: 'komga_error_missing_server_url', basic: true },
  { name: 'Kavita', kind: 'kavita', url: 'baseUrl', urlError: 'kavita_error_missing_server_url' },
  { name: 'WebDav', kind: 'webdav', url: 'baseUrl', urlError: 'webdav_error_missing_server_url', basic: true },
  { name: 'Opds', kind: 'opds', url: 'rootUrl', urlError: 'opds_error_missing_catalog_url', basic: true },
]
async function run() {
  for (const protocol of protocols) {
    const { name, kind, url, urlError, basic } = protocol
    const f = fixture(), { klass, callbacks } = pageClass(name)
    let calls = 0, mode = 'success', gate
    f.store[`create${name}Client`] = () => {
      const request = async () => {
        calls++
        if (mode === 'failure') throw new Error('raw network error must not appear')
        if (gate) await gate.promise
        return name === 'Opds' ? { version: globals.OpdsVersion.OPDS_2, navigation: [], publications: [] } : []
      }
      return { listLibraries: request, propfind: request, fetchCatalog: request }
    }
    const makePage = () => {
      const page = new klass()
      page.store = () => f.store
      page.showToast = () => {}
      return page
    }
    let page = makePage()
    const loadGate = deferred(), preferences = f.store.preferences
    f.store.preferences = async () => { await loadGate.promise; return f.prefs }
    const loading = page.loadSaved()
    assert.equal(page.formBusy(), true)
    callbacks[0].call(page, 'ignored while loading')
    assert.equal(page[url], '')
    await page.saveAndTest()
    assert.equal(f.writes(), 0)
    loadGate.resolve(); await loading; f.store.preferences = preferences
    assert.equal(page.hasSavedConfig, false)
    await page.saveAndTest()
    assert.equal(page.statusKey, urlError)
    assert.equal(calls, 0); assert.equal(f.writes(), 0)
    page[url] = 'https://fixture.invalid/service/'
    if (name === 'Komga') page.authKind = globals.KomgaAuthKind.BASIC
    if (basic) page.username = 'fixture'
    await page.saveAndTest()
    assert.equal(page.statusKey, basic ? 'server_error_missing_username_password' : 'server_error_missing_api_key')
    assert.equal(calls, 0); assert.equal(f.writes(), 0)
    if (basic) { page.username = 'fixture'; page.password = 'secret' } else page.apiKey = 'auth-key'
    const writeAsset = f.store.writeCredentialAsset
    f.store.writeCredentialAsset = async () => { throw new Error('raw asset error') }
    await page.saveAndTest()
    assert.equal(page.statusKey, 'server_status_save_failed')
    assert.equal(calls, 0); assert.equal(page.hasSavedConfig, false)
    f.store.writeCredentialAsset = writeAsset
    mode = 'failure'; await page.saveAndTest()
    assert.equal(page.statusKey, `${kind}_status_failed`)
    assert.equal(page.hasSavedConfig, true, `${kind}: persistence precedes network result`)
    mode = 'success'
    page = makePage(); await page.loadSaved()
    if (basic) {
      assert.equal(page.username, ''); assert.equal(page.password, '')
      assert.equal(page.hasSavedBasicCredential, true)
    }
    const beforeToken = [...f.secrets.values()][0]
    await page.saveAndTest()
    assert.equal(page.statusKey, `${kind}_status_success`)
    assert.equal([...f.secrets.values()][0], beforeToken, `${kind}: reopen and retest retains credential`)
    for (const callback of callbacks) {
      page.statusKey = 'old_result'; page.statusArgs = ['old']
      if (name === 'Opds') page.detectedVersion = 'old_version'
      callback.call(page, 'edited')
      assert.equal(page.statusKey, ''); assert.deepEqual(page.statusArgs, [])
      if (name === 'Opds') assert.equal(page.detectedVersion, '')
    }
    page = makePage(); await page.loadSaved()
    gate = deferred()
    const testing = page.saveAndTest()
    for (let tick = 0; tick < 30 && page.statusKey !== 'server_status_testing'; tick++) await Promise.resolve()
    assert.equal(page.formBusy(), true)
    const address = page[url], count = calls
    callbacks[0].call(page, 'ignored while testing')
    assert.equal(page[url], address)
    await page.clearServer(); await page.saveAndTest()
    assert.equal(page.hasSavedConfig, true); assert.equal(calls, count)
    gate.resolve(); gate = undefined; await testing
    assert.equal(page.statusKey, `${kind}_status_success`)
    if (name === 'Opds') assert.equal((await f.store.loadOpds()).server.version, globals.OpdsVersion.OPDS_2)
    if (basic) {
      const before = f.writes()
      page[url] = 'https://different.invalid/service'
      await page.saveAndTest()
      assert.equal(page.statusKey, 'server_error_reenter_credentials')
      assert.equal(f.writes(), before, `${kind}: do not transfer credential or overwrite on changed address`)
      page[url] = address
      f.secrets.clear()
      page = makePage(); await page.loadSaved()
      assert.equal(page.hasSavedConfig, true); assert.equal(page.hasSavedBasicCredential, false)
      await page.saveAndTest()
      assert.equal(page.statusKey, 'server_error_reenter_credentials')
      assert.equal(f.writes(), before, `${kind}: missing saved secret must not become anonymous`)
    } else {
      f.secrets.clear()
      assert.equal(await f.store.loadKavita(), undefined)
      page = makePage(); await page.loadSaved()
      assert.equal(page.hasSavedConfig, true, 'Kavita metadata exists even if credential is unavailable')
      assert.equal(page.statusKey, 'server_status_load_failed')
    }
    const del = f.prefs.delete
    f.prefs.delete = async () => { throw new Error('raw delete error') }
    await page.clearServer()
    assert.equal(page.statusKey, 'server_status_remove_failed'); assert.equal(page.hasSavedConfig, true)
    f.prefs.delete = del
    await page.clearServer()
    assert.equal(page.hasSavedConfig, false); assert.equal(page[url], '')
    assert.equal(await f.store.hasSavedConfiguration(kind), false)
  }
  for (const name of ['Komga', 'WebDav', 'Opds']) {
    const f = fixture(), method = `save${name}`, urlKey = name === 'Opds' ? 'rootUrl' : 'baseUrl'
    const draft = { [urlKey]: 'https://fixture.invalid', username: 'one', password: 'secret', authKind: globals.KomgaAuthKind.BASIC }
    await f.store[method](draft)
    const replaced = await f.store[method]({ ...draft, username: 'two', preserveSavedCredentials: true })
    assert.equal(replaced.credential.basicToken, Buffer.from('two:secret').toString('base64'))
    const empty = { ...draft, username: '', password: '' }
    if (name === 'Komga') {
      await assert.rejects(f.store[method](empty), error => error.resourceKey === 'server_error_missing_username_password')
      await f.store.saveKomga({ ...draft, authKind: globals.KomgaAuthKind.NONE })
      await assert.rejects(f.store.saveKomga({ ...empty, preserveSavedCredentials: true }),
        error => error.resourceKey === 'server_error_missing_username_password')
    } else {
      const anonymous = await f.store[method](empty)
      assert.equal(anonymous.credential, undefined, `${name}: unspecified preserve flag retains existing API semantics`)
    }
  }
  console.log('PASS: actual store/page methods in isolated host fixtures — four-protocol load/edit/missing/save/network/remove states and Basic credential preservation; no device or real account acceptance')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
