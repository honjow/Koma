// Executes production ArkTS backend with a controlled Web cookie jar and NetworkKit.
// No device, network, credentials, or artifact hashes.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = path.join(__dirname, '../entry/src/main/ets/sourceRuntime')
function moduleFrom(name, requireMock) {
  const exports = {}
  const javascript = ts.transpileModule(fs.readFileSync(path.join(base, name + '.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS },
  }).outputText
  vm.runInNewContext(javascript, { exports, require: requireMock, Map, Date, JSON, Error })
  return exports
}
function fixture() {
  const disk = new Map(), writes = [], fetched = [], diagnostics = [], configured = []
  const extraEntries = new Map()
  let uuid = 0, cookie = 'private-cookie-value', failWrite = false
  let entry = { sourceId: 'source.one', manifestVersion: '1', enabled: true,
    wasmPath: '/app/packages/one/source.wasm', webSessionOrigins: ['https://site.invalid'] }
  const registry = { lookup: id => ({ entry: id === entry.sourceId ? entry : extraEntries.get(id) }) }
  const mocks = name => {
    if (name === '@kit.ArkTS') return { url: { URL }, util: { generateRandomUUID: () => String(++uuid) } }
    if (name === '@kit.ArkWeb') return { webview: { WebCookieManager: { fetchCookieSync: fullUrl => {
      fetched.push(fullUrl); return cookie
    }, configCookieSync: (fullUrl, value, incognito, includeHttpOnly) => {
      configured.push({ fullUrl, value, incognito, includeHttpOnly }); cookie = value.split(';')[0]
    }, saveCookieSync: () => {} } } }
    if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { warn: (_category, _event, detail) => diagnostics.push(detail) } }
    if (name === '@kit.CoreFileKit') return { fileIo: { accessSync: p => disk.has(p),
      mkdirSync: p => disk.set(p, ''), readTextSync: p => disk.get(p) } }
    if (name === '../model/AppFileTextPersistence') return { writeAppTextFile: (p, content) => {
      if (failWrite) throw Error('storage unavailable')
      disk.set(p, content); writes.push(content)
    } }
    if (name === './SourceRuntimeRegistry' || name === '@kit.AbilityKit') return {}
    throw Error('unexpected import: ' + name)
  }
  const api = moduleFrom('SourceWebSessionStore', mocks)
  const store = new api.SourceWebSessionStore()
  store.configure({ filesDir: '/files' }, registry)
  const identity = () => ({ sourceId: entry.sourceId, sourceVersion: entry.manifestVersion,
    packageIdentity: api.sourceWebPackageIdentity(entry), webSessionOrigins: entry.webSessionOrigins })
  const grant = () => {
    const pending = store.begin(registry, entry.sourceId, 'https://site.invalid/verify?not-persisted')
    store.complete(entry.sourceId, pending.sessionId, 'https://site.invalid/done', 'ActualWebViewUA')
  }
  async function http(responses, context, sourceRequest = {}, network = {}) {
    let callback
    const calls = [], instances = [], intercepts = []
    const trace = { info: (_event, detail) => diagnostics.push(detail), fail: () => {}, finish: (_state, detail) => diagnostics.push(detail) }
    const transport = moduleFrom('SourceRuntimeHttpTransport', name => {
      if (name === '@kit.ArkTS') return { url: { URL } }
      if (name === './SourceWebSessionStore') return { appSourceWebSessionStore: store }
      if (name === './NativeSourceRuntime') return { NativeSourceRuntime: { configureHttpTransport: fn => { callback = fn; return true } } }
      if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { begin: () => trace, warn: (_category, _event, detail) => diagnostics.push(detail) } }
      if (name === '@kit.NetworkKit') return { http: {
        RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType: { STRING: 1 },
        InterceptorType: { REDIRECTION: 'REDIRECTION' },
        HttpInterceptorChain: class {
          addChain(chain) {
            if (network.addThrows) throw Error('interceptor setup failed')
            this.chain = chain
            return network.addResult !== false
          }
          apply(request) {
            if (network.applyThrows) throw Error('interceptor setup failed')
            if (network.applyResult === false) return false
            request.chain = this.chain
            return true
          }
        },
        createHttp: () => {
          const request = { chain: [], destroyed: false, requestCount: 0,
            request: async (initialUrl, options) => {
              assert.equal(request.destroyed, false)
              assert.equal(++request.requestCount, 1, 'A HttpRequest must not be reused for another hop')
              let fullUrl = initialUrl
              while (true) {
                calls.push({ fullUrl, options, instance: instances.indexOf(request) })
                if (network.requestError) throw network.requestError
                const response = responses.shift()
                if (!response) throw Error('unexpected additional request')
                if ([301, 302, 303, 307, 308].includes(response.responseCode)) {
                  // NetworkKit rejects even the first redirect when the configured maximum is zero.
                  if (options.maxRedirects === 0) throw Object.assign(Error('redirect limit'), { code: 2300047 })
                  let stopped = false
                  for (const interceptor of request.chain) {
                    assert.equal(interceptor.interceptorType, 'REDIRECTION')
                    const continued = await interceptor.interceptorHandle({ url: fullUrl, header: options.header }, response)
                    intercepts.push({ status: response.responseCode, continued })
                    if (!continued) { stopped = true; break }
                  }
                  if (stopped) return response
                  // A missing stop interceptor would send the next request automatically.
                  const key = Object.keys(response.header).find(key => key.toLowerCase() === 'location')
                  fullUrl = new URL(response.header[key], fullUrl).toString()
                  continue
                }
                return response
              }
            }, destroy: () => { request.destroyed = true },
          }
          instances.push(request)
          return request
        },
      } }
      if (name === '@kit.BasicServicesKit') return {}
      throw Error('unexpected import: ' + name)
    })
    transport.configureSourceRuntimeHttpTransport()
    const result = await callback(JSON.stringify({ url: 'https://site.invalid/a', method: 'GET', ...sourceRequest }), context)
    return { calls, instances, intercepts, result: JSON.parse(result) }
  }
  return { api, store, registry, writes, fetched, diagnostics, configured, identity, grant, http,
    addSource: e => extraEntries.set(e.sourceId, e), setWriteFailure: value => { failWrite = value },
    changeEntry: fn => { entry = fn(entry) }, setCookie: value => { cookie = value },
    reload: () => { const next = new api.SourceWebSessionStore(); next.configure({ filesDir: '/files' }, registry); return next } }
}
const response = (status = 200, header = {}) => ({ responseCode: status, result: 'public-body', header })
test('source, origin, package identity and pending boundary isolate cookie access', () => {
  const f = fixture()
  assert.throws(() => f.store.begin(f.registry, 'missing', 'https://site.invalid/'))
  assert.throws(() => f.store.begin(f.registry, 'source.one', 'https://user:secret@site.invalid/'))
  assert.throws(() => f.store.begin(f.registry, 'source.one', 'https://site.invalid.evil/'))
  const pending = f.store.begin(f.registry, 'source.one', 'https://site.invalid/verify')
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/a'), undefined)
  assert.throws(() => f.store.complete('source.one', pending.sessionId, 'https://other.invalid/', 'UA'))
  f.grant()
  for (const identity of [{ ...f.identity(), sourceId: 'other' }, { ...f.identity(), sourceVersion: 'old' },
    { ...f.identity(), packageIdentity: 'other-package' }, { ...f.identity(), webSessionOrigins: [] }]) {
    assert.equal(f.store.requestSession(identity, 'https://site.invalid/a'), undefined)
  }
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid.evil/a'), undefined)
  assert.equal(f.fetched.length, 0)
})
test('opening and cancelling verification preserves an existing ready grant', () => {
  const f = fixture(); f.grant()
  const pending = f.store.begin(f.registry, 'source.one', 'https://site.invalid/verify')
  f.store.cancel('source.one', 'another-pending')
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/a').userAgent, 'ActualWebViewUA')
  f.store.cancel('source.one', pending.sessionId)
  assert.equal(f.store.status('source.one').state, 'available')
  assert.throws(() => f.store.complete('source.one', pending.sessionId, 'https://site.invalid/', 'UA'))
})
test('equivalent registry reload preserves login; actual replacement or permission changes revoke it', () => {
  const f = fixture(); f.grant()
  f.changeEntry(entry => ({ ...entry, webSessionOrigins: [...entry.webSessionOrigins] }))
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/a').userAgent, 'ActualWebViewUA')
  f.changeEntry(entry => ({ ...entry, wasmPath: '/app/packages/replaced/source.wasm' }))
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/a'), undefined)
})
test('nonsecret authorization survives restart; cookies are read per full URL and never persisted', () => {
  const f = fixture(); f.grant(); const restarted = f.reload()
  assert.equal(restarted.requestSession(f.identity(), 'https://site.invalid/private/path').cookie, 'private-cookie-value')
  assert.equal(f.fetched.at(-1), 'https://site.invalid/private/path')
  f.setCookie('rotated-cookie-value')
  assert.equal(restarted.requestSession(f.identity(), 'https://site.invalid/b').cookie, 'rotated-cookie-value')
  assert(f.writes.every(content => !content.includes('cookie-value') && !content.includes('not-persisted')))
  restarted.revoke('source.one')
  assert.equal(restarted.requestSession(f.identity(), 'https://site.invalid/a'), undefined)
})
test('WASM-supplied identity cannot acquire a session; separate native identity supplies actual UA and cookie', async () => {
  const f = fixture(); f.grant()
  const plain = await f.http([response()], '', { sourceId: 'source.one' })
  assert.equal(plain.calls[0].options.header.Cookie, undefined)
  const actual = await f.http([response(200, { 'set-cookie': 'not-returned' })], JSON.stringify(f.identity()), {
    headers: { 'User-Agent': 'wasm-agent', Cookie: 'wasm-value' } })
  assert(f.diagnostics.includes('identity=native session=attached cookieState=present uaSource=webview'))
  assert(f.diagnostics.includes('identity=none session=none cookieState=empty uaSource=source'))
  assert.equal(actual.calls[0].options.header['User-Agent'], 'ActualWebViewUA')
  assert.equal(actual.calls[0].options.header.Cookie, 'private-cookie-value')
  assert.equal(actual.result.bodyText, 'public-body')
  assert.equal(actual.result.header, undefined)
  assert(!JSON.stringify(actual.result).includes('cookie'))
  assert(f.diagnostics.every(item => !item.includes('cookie-value')))
})
test('same-origin redirects re-read cookies for the exact path; cross-origin redirects never issue the next request', async () => {
  const f = fixture(); f.grant()
  const allowed = await f.http([response(302, { location: '/next' }), response()], JSON.stringify(f.identity()))
  assert.equal(allowed.calls.length, 2)
  assert.equal(allowed.calls[0].options.maxRedirects, undefined)
  assert.deepEqual(allowed.intercepts, [{ status: 302, continued: false }])
  assert.equal(allowed.instances.length, 2)
  assert(allowed.instances.every(request => request.destroyed))
  assert.equal(allowed.calls[1].fullUrl, 'https://site.invalid/next')
  assert(f.fetched.includes('https://site.invalid/next'))
  const denied = await f.http([response(302, { Location: 'https://evil.invalid/steal' })], JSON.stringify(f.identity()))
  assert.equal(denied.calls.length, 1)
  assert.equal(denied.instances.length, 1)
  assert(denied.instances.every(request => request.destroyed))
  assert.equal(denied.result.ok, false)
  assert.equal(denied.result.error.code, 'web_session_redirect_rejected')
})

test('version, permission, disable and explicit revoke invalidate authorization without retaining secrets', () => {
  for (const change of [e => ({ ...e, manifestVersion: '2' }), e => ({ ...e, enabled: false }),
    e => ({ ...e, webSessionOrigins: [] })]) {
    const f = fixture(); f.grant(); f.changeEntry(change)
    assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/a'), undefined)
    assert.equal(f.reload().status('source.one').state, 'none')
  }
  const f = fixture(); f.grant(); f.store.revoke('source.one')
  assert.equal(f.reload().status('source.one').state, 'none')
})
test('response cookies renew only the exact granted source/origin and preserve Expires comma', async () => {
  const f = fixture(); f.grant()
  const values = ['session=new; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/; Secure; HttpOnly', 'other=x; Path=/b']
  const result = await f.http([response(302, { 'set-cookie': values, location: '/next' }), response()], JSON.stringify(f.identity()))
  assert.deepEqual(f.configured.map(c => c.value), values)
  assert(f.configured.every(c => c.fullUrl === 'https://site.invalid/a' && c.includeHttpOnly === true))
  assert.equal(result.calls[1].options.header.Cookie, 'other=x')
  assert(!JSON.stringify(result.result).includes('session=new'))
  const count = f.configured.length
  f.store.acceptResponseCookies(f.identity(), 'https://evil.invalid/a', ['bad=secret'])
  f.store.acceptResponseCookies({ ...f.identity(), sourceId: 'other' }, 'https://site.invalid/a', ['bad=secret'])
  assert.equal(f.configured.length, count)
  assert(f.writes.every(v => !v.includes('session=new') && !v.includes('other=x')))
})
test('parallel native identities do not share a last-source session context', async () => {
  const f = fixture(); f.grant()
  const second = { sourceId: 'source.two', manifestVersion: '2', enabled: true, wasmPath: '/two', webSessionOrigins: ['https://two.invalid'] }
  f.addSource(second)
  const pending = f.store.begin(f.registry, second.sourceId, 'https://two.invalid/')
  f.store.complete(second.sourceId, pending.sessionId, 'https://two.invalid/', 'SecondWebViewUA')
  const identity = { sourceId: second.sourceId, sourceVersion: second.manifestVersion,
    packageIdentity: f.api.sourceWebPackageIdentity(second), webSessionOrigins: second.webSessionOrigins }
  const [one, two] = await Promise.all([f.http([response()], JSON.stringify(f.identity())),
    f.http([response()], JSON.stringify(identity), { url: 'https://two.invalid/a' })])
  assert.equal(one.calls[0].options.header['User-Agent'], 'ActualWebViewUA')
  assert.equal(two.calls[0].options.header['User-Agent'], 'SecondWebViewUA')
  assert.equal(f.store.requestSession(identity, 'https://site.invalid/a'), undefined)
})

test('automatic invalidation keeps memory revoked on storage failure while explicit disconnect reports failure', () => {
  const f = fixture(); f.grant(); f.setWriteFailure(true)
  f.changeEntry(e => ({ ...e, enabled: false }))
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/a'), undefined)
  assert(f.diagnostics.includes('reason=storage_write_failed'))
  assert.throws(() => f.store.revoke('source.one'), /storage unavailable/)
  assert.equal(f.store.status('source.one').state, 'none')
})

function declarations(relative, names, owner) {
  const file = path.join(base, '..', relative + '.ets')
  const source = fs.readFileSync(file, 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const values = owner ? tree.statements.find(s => ts.isClassDeclaration(s) && s.name?.text === owner).members : tree.statements
  return names.map(name => {
    const node = values.find(s => s.name?.getText(tree) === name ||
      (ts.isVariableStatement(s) && s.declarationList.declarations.some(v => v.name.getText(tree) === name)))
    assert.ok(node, `${relative}:${name}`)
    return node.getText(tree)
  }).join('\n')
}

test('ordinary Browse queue derives native identity from the admitted registry entry, not source JSON', async () => {
  const f = fixture(), nativeCalls = [], exports = {}
  const queue = declarations('viewmodel/BrowseViewModel', ['runBrowseSourceOperationTask', 'sourceOperationQueue', 'enqueueSourceOperation'])
  const method = declarations('viewmodel/BrowseViewModel', ['runSourceOperationResponse'], 'BrowseViewModel')
  const source = `${queue}\nexport class Host { ${method} }`
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, { exports, AppStrings: { get: key => key }, sourceHttpIdentityJson: f.api.sourceHttpIdentityJson,
    diagnoseSourceOperation: (_request, run) => run(), taskpool: { execute: (fn, ...args) => fn(...args) },
    require: name => {
      assert.equal(name, 'libkoma_source_runtime.so')
      return { runJsonCallFromBytes: (request, bytes, context) => {
        nativeCalls.push({ request, context }); return JSON.stringify({ ok: true })
      } }
    } })
  const host = new exports.Host()
  host.registry = { lookup: id => ({ ...f.registry.lookup(id), ok: id === 'source.one' }) }
  host.copyWasmBytes = () => new Uint8Array([0])
  host.buildRequestJson = () => JSON.stringify({ sourceId: 'wasm-forged', packageIdentity: 'forged' })
  await assert.rejects(host.runSourceOperationResponse('missing', 'get_home', {}, 1), /browse_error_source_unavailable/)
  assert.equal(nativeCalls.length, 0)
  await host.runSourceOperationResponse('source.one', 'get_home', {}, 1)
  assert.equal(nativeCalls.length, 1)
  assert.deepEqual(JSON.parse(nativeCalls[0].context), f.identity())
  assert.equal(JSON.parse(nativeCalls[0].request).sourceId, 'wasm-forged')
  assert(!nativeCalls[0].context.includes('cookie-value'))
})

test('detail, chapter list, page and image-request workers retain each invocation native context', () => {
  const lanes = [
    ['pages/MangaDetailPage', 'executeMangaDetailSourceOperation'],
    ['model/SourceChapterListResolver', 'executeSourceChapterListOperation'],
    ['model/SourceChapterPageHydrator', 'executeSourceChapterPagesOperation'],
    ['model/ReaderPageSourceAdapter', 'executeReaderSourceImageRequestOperation'],
  ]
  for (const [file, name] of lanes) {
    const calls = [], exports = {}
    const js = ts.transpileModule(declarations(file, [name]) + `\nexports.run = ${name}`, {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    }).outputText
    vm.runInNewContext(js, { exports, runSourceOperationFromBytes: (...args) => { calls.push(args); return { ok: true } } })
    const bytes = new Uint8Array([1]), context = JSON.stringify({ sourceId: file })
    assert.equal(JSON.parse(exports.run('public-request', bytes, context)).ok, true)
    assert.equal(calls.length, 1, file)
    assert.equal(calls[0][2], context, file)
  }
})

test('redirect interceptor setup failure never sends a credentialed request or falls back to automatic following', async () => {
  for (const network of [{ addResult: false }, { applyResult: false }, { addThrows: true }, { applyThrows: true }]) {
    const f = fixture(); f.grant()
    const failed = await f.http([response(302, { Location: 'https://other.invalid/' })], JSON.stringify(f.identity()), {}, network)
    assert.equal(failed.calls.length, 0)
    assert.equal(failed.result.error.code, 'web_session_redirect_unavailable')
    assert.equal(failed.result.error.retryable, false)
    assert.equal(failed.instances.length, 1)
    assert.equal(failed.instances[0].destroyed, true)
  }
})
test('manual redirect budget rejects the next hop and destroys every single-use request', async () => {
  const f = fixture(); f.grant()
  const result = await f.http(Array.from({ length: 31 }, (_, i) => response(302, { Location: '/hop-' + i })), JSON.stringify(f.identity()))
  assert.equal(result.result.error.code, 'web_session_redirect_rejected')
  assert.equal(result.calls.length, 31)
  assert.equal(result.intercepts.length, 31)
  assert(result.instances.every(request => request.requestCount === 1 && request.destroyed))
})
test('303 changes POST to GET while 307 retains the request body', async () => {
  const f = fixture(); f.grant()
  for (const [status, method, body] of [[303, 'GET', undefined], [307, 'POST', 'payload']]) {
    const result = await f.http([response(status, { Location: '/next' }), response()], JSON.stringify(f.identity()), { method: 'POST', body: 'payload' })
    assert.equal(result.calls[1].options.method, method)
    assert.equal(result.calls[1].options.extraData, body)
    assert(result.instances.every(request => request.destroyed))
  }
})

test('platform operation timeout survives the HTTP envelope while unknown transport failures remain network errors', async () => {
  for (const attached of [false, true]) {
    for (const code of [2300028, 2300006, undefined, '2300028', NaN]) {
      const f = fixture()
      if (attached) f.grant()
      const failed = await f.http([], attached ? JSON.stringify(f.identity()) : undefined, {}, {
        requestError: Object.assign(Error('private-platform-error-detail'), { code }),
      })
      assert.equal(failed.result.ok, false)
      assert.equal(failed.result.error.code, code === 2300028 ? 'timeout' : 'network_error')
      assert.equal(failed.result.error.retryable, true)
      assert.equal(failed.calls.length, 1)
      assert(failed.instances.every(request => request.requestCount === 1 && request.destroyed))
      assert(!JSON.stringify(failed.result).includes('private-platform-error-detail'))
      assert(!f.diagnostics.join(' ').includes('private-platform-error-detail'))
      assert(f.diagnostics.includes('platformCode=' + (typeof code === 'number' && Number.isFinite(code) ? code : 0)))
    }
  }
})
