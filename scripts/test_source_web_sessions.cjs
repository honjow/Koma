// Executes production ArkTS backend with a controlled Web cookie jar and NetworkKit.
// No device, network, credentials, or artifact hashes.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = path.join(__dirname, '../entry/src/main/ets/sourceRuntime')
function moduleFrom(name, requireMock, globals = {}) {
  const exports = {}
  const javascript = ts.transpileModule(fs.readFileSync(path.join(base, name + '.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS },
  }).outputText
  vm.runInNewContext(javascript, { exports, require: requireMock, Map, Date, JSON, Error, ...globals })
  return exports
}
function fixture(sdkApiVersion = 23) {
  const disk = new Map(), writes = [], fetched = [], diagnostics = [], configured = []
  const extraEntries = new Map(), cookieReads = []
  const guards = moduleFrom('SourceRuntimeOperationGuard', () => ({}))
  let uuid = 0, cookie = 'private-cookie-value', failWrite = false
  let entry = { sourceId: 'source.one', manifestVersion: '1', enabled: true,
    wasmPath: '/app/packages/one/source.wasm', webSessionOrigins: ['https://site.invalid'] }
  const registry = { lookup: id => ({ entry: id === entry.sourceId ? entry : extraEntries.get(id) }) }
  const mocks = name => {
    if (name === '@kit.ArkTS') return { url: { URL }, util: { generateRandomUUID: () => String(++uuid) } }
    if (name === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion } }
    if (name === '@kit.ArkWeb') return { webview: { WebCookieManager: { fetchCookieSync: (...args) => {
      cookieReads.push(args);fetched.push(args[0]); return cookie
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
    const trace = { info: (_event, detail) => diagnostics.push(detail), warn: (_event, detail) => diagnostics.push(detail), fail: () => {}, finish: (_state, detail) => diagnostics.push(detail) }
    const transport = moduleFrom('SourceRuntimeHttpTransport', name => {
      if (name === '@kit.ArkTS') return { url: { URL } }
      if (name === './SourceRequestPolicy') return network.policy ?? moduleFrom('SourceRequestPolicy', () => ({ url: { URL } }))
      if (name === './SourceWebSessionStore') return { appSourceWebSessionStore: store, sourceWebOrigin: api.sourceWebOrigin }
      if (name === './SourceWebChallengeGate') return moduleFrom('SourceWebChallengeGate', () => ({}))
      if (name === './SourceRuntimeOperationGuard') return guards
      if (name === './NativeSourceRuntime') return { NativeSourceRuntime: { configureHttpTransport: fn => { callback = fn; return true } } }
      if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { begin: () => trace, info: (_category, _event, detail) => diagnostics.push(detail), warn: (_category, _event, detail) => diagnostics.push(detail) } }
      if (name === '@kit.NetworkKit') return { http: {
        RequestMethod: { GET: 'GET', POST: 'POST', HEAD: 'HEAD' }, HttpDataType: { STRING: 1 },
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
          const listeners = new Map()
          const request = { chain: [], destroyed: false, requestCount: 0, listeners,
            on: (event, callback) => listeners.set(event, callback),
            off: event => listeners.delete(event),
            request: async (initialUrl, options) => {
              assert.equal(request.destroyed, false)
              assert.equal(++request.requestCount, 1, 'A HttpRequest must not be reused for another hop')
              let fullUrl = initialUrl
              while (true) {
                calls.push({ fullUrl, options, instance: instances.indexOf(request) })
                if (network.headersBeforeError) listeners.get('headersReceive')?.({ 'Set-Cookie': 'PRIVATE_HEADER' })
                if (network.requestError) throw network.requestError
                const response = await responses.shift()
                if (!response) throw Error('unexpected additional request')
                listeners.get('headersReceive')?.(response.header)
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
    }, network.clock ? { Date: network.clock } : {})
    transport.configureSourceRuntimeHttpTransport()
    const result = await callback(JSON.stringify({ url: 'https://site.invalid/a', method: 'GET', ...sourceRequest }), context)
    const after = network.afterInitial === undefined ? undefined : await network.afterInitial({ transport, execute: callback })
    return { calls, instances, intercepts, result: JSON.parse(result), after }
  }
  return { api, store, registry, writes, fetched, cookieReads, diagnostics, configured, identity, grant, http, guards,
    addSource: e => extraEntries.set(e.sourceId, e), setWriteFailure: value => { failWrite = value },
    changeEntry: fn => { entry = fn(entry) }, setCookie: value => { cookie = value },
    reload: () => { const next = new api.SourceWebSessionStore(); next.configure({ filesDir: '/files' }, registry); return next } }
}

test('a cancelled search cannot start an HTTP request after waiting for a policy slot', async () => {
  const f = fixture()
  const id = f.guards.newSourceRuntimeOperationGuardId()
  let current = true, waiting, resume
  const entered = new Promise(resolve => { waiting = resolve })
  const gate = new Promise(resolve => { resume = resolve })
  const release = f.guards.registerSourceRuntimeOperationGuard(id, () => current)
  const context = JSON.stringify({ ...f.identity(), operationGuardId: id })
  const request = f.http([response(200)], context, {}, { policy: { waitForSourceRequestSlot: async () => {
    waiting(); await gate
  } } })
  await entered
  current = false
  resume()
  const result = await request
  assert.equal(result.calls.length, 0)
  assert.equal(result.result.error.code, 'source_request_cancelled')
  release()
  assert.equal(f.guards.sourceRuntimeOperationIsCurrent(id), false)
})

test('verification navigation uses the installed source name for the current language', () => {
  const f = fixture()
  const names = moduleFrom('SourceLocalizedNames', () => ({}))
  f.changeEntry(entry => ({ ...entry, manifestName: 'DM5', localizedNames: { 'zh-Hans': '动漫屋', 'zh-Hant': '動漫屋' } }))
  let locale = 'zh-CN'
  const navigation = moduleFrom('SourceWebSessionNavigation', name => {
    if (name === '../common/RouterHelper') return { RouterHelper: {} }
    if (name === './SourceWebSessionStore') return { appSourceWebSessionStore: f.store }
    if (name === './SourceRuntimeHttpTransport') return { sourceRejectedRequestUrl: () => '' }
    if (name === './SourceRuntimeAppRegistry') return {
      appSourceRuntimeRegistry: f.registry,
      sourceDisplayName: (id, fallback) => {
        const entry = f.registry.lookup(id).entry
        return entry ? names.resolveSourceLocalizedName(entry.manifestName, entry.localizedNames, locale) : fallback
      },
    }
    throw Error('unexpected import: ' + name)
  })
  for (const [language, expected] of [['zh-CN', '动漫屋'], ['zh-TW', '動漫屋'], ['en-US', 'DM5']]) {
    locale = language
    const route = navigation.prepareSourceWebSession('source.one', 'DM5')
    assert.equal(route.title, expected)
    assert.equal(route.url, 'https://site.invalid/')
    assert.equal(route.sourceSession.sourceId, 'source.one')
    f.store.cancel('source.one', route.sourceSession.sessionId)
  }
  f.changeEntry(entry => ({ ...entry, enabled: false }))
  assert.equal(navigation.prepareSourceWebSession('source.one', 'DM5'), undefined)
})
const response = (status = 200, header = {}, body = 'public-body') => ({ responseCode: status, result: body, header })
test('one bounded HTTP group starts all original requests and keeps response order, session and failures', async () => {
  const f = fixture(); f.grant()
  const deferred = Array.from({ length: 5 }, () => {
    let resolve, reject
    const promise = new Promise((yes, no) => { resolve = yes; reject = no })
    return { promise, resolve, reject }
  })
  const pending = deferred.map(item => item.promise)
  const requests = pending.map((_, index) => ({ url: `https://site.invalid/probe/${index}`, method: 'POST',
    bodyBase64: `request-${index}`, timeoutMs: 15000 }))
  // Control the clock when checking the original timeout budget; fixture CPU
  // time must not make the expected remaining budget nondeterministic.
  const running = f.http(pending, JSON.stringify(f.identity()), { url: undefined, method: undefined, requests },
    { clock: { now: () => 1000 } })
  // None of the responses can complete yet. All five must already be in
  // NetworkKit; a serial implementation leaves four promises unconsumed.
  for (let i = 0; i < 30; i++) await Promise.resolve()
  assert.equal(pending.length, 0)
  deferred[4].resolve(response(200, {}, 'probe-4'))
  deferred[2].resolve(response(503, {}, 'probe-2'))
  deferred[3].reject(Object.assign(Error('timeout'), { code: 2300028 }))
  deferred[1].resolve(response(200, {}, 'probe-1'))
  deferred[0].resolve(response(200, {}, 'probe-0'))
  const actual = await running
  assert.equal(actual.result.ok, true)
  assert.deepEqual(actual.result.responses.map(item => item.bodyText ?? item.error.code),
    ['probe-0', 'probe-1', 'probe-2', 'timeout', 'probe-4'])
  assert.equal(actual.result.responses[2].status, 503)
  assert.equal(actual.result.responses[3].ok, false)
  assert.equal(actual.calls.length, 5)
  assert(actual.instances.every(item => item.destroyed))
  actual.calls.forEach((call, index) => {
    assert.equal(call.options.extraData, `request-${index}`)
    assert.equal(call.options.header.Cookie, 'private-cookie-value')
    assert.equal(call.options.header['User-Agent'], 'ActualWebViewUA')
    assert.equal(call.options.readTimeout, 15000)
  })
})

test('invalid, oversized or nested HTTP groups make no partial network request', async () => {
  const request = { url: 'https://site.invalid/probe', method: 'POST' }
  for (const requests of [[], Array(6).fill(request), [request, { requests: [request] }],
    [request, { ...request, url: 'file:///private' }], [request, { ...request, bodyBase64: 'x'.repeat(1024 * 1024 + 1) }]]) {
    const actual = await fixture().http([], '', { url: undefined, method: undefined, requests })
    assert.equal(actual.result.ok, false)
    assert.equal(actual.calls.length, 0)
  }
})

test('rate queue waiting preserves the existing network timeout budget and rechecks session cookies', async () => {
  const f = fixture(); f.grant()
  let now = 1000
  const result = await f.http([response()], JSON.stringify(f.identity()), { timeoutMs: 15000 }, {
    clock: { now: () => now },
    policy: { waitForSourceRequestSlot: async () => { now += 20000; f.setCookie('cookie-after-wait') } },
  })
  assert.equal(result.result.status, 200)
  assert.equal(result.calls[0].options.readTimeout, 15000)
  assert.equal(result.calls[0].options.connectTimeout, 15000)
  assert.equal(result.calls[0].options.header.Cookie, 'cookie-after-wait')
})
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
test('MangaBz language overrides only its own cookie while verification survives every redirect', async () => {
  function granted(sourceId = 'com.mangabz.koma', origin = 'https://www.mangabz.com') {
    const f = fixture()
    f.changeEntry(entry => ({ ...entry, sourceId, webSessionOrigins: [origin] }))
    const pending = f.store.begin(f.registry, sourceId, origin + '/verify')
    f.store.complete(sourceId, pending.sessionId, origin + '/done', 'ActualWebViewUA')
    f.setCookie('cf_clearance=jar-clearance; session=jar-login; mangabz_lang=1; mangabz_lang=2; other=kept')
    return f
  }
  for (const language of ['1', '2']) {
    const f = granted()
    const result = await f.http([response(302, { location: '/after' }), response()], JSON.stringify(f.identity()), {
      url: 'https://www.mangabz.com/browse',
      headers: { cookie: 'mangabz_lang=' + language + '; cf_clearance=source-attempt', 'User-Agent': 'source-agent' },
    })
    assert.equal(result.calls.length, 2)
    for (const call of result.calls) {
      assert.equal(call.options.header.Cookie,
        'cf_clearance=jar-clearance; session=jar-login; other=kept; mangabz_lang=' + language)
      assert.equal(call.options.header['User-Agent'], 'ActualWebViewUA')
    }
    assert.equal(f.configured.length, 0, 'Language selection does not write the Web cookie jar')
    assert(f.writes.every(value => !value.includes('jar-login') && !value.includes('mangabz_lang')))
    assert(f.diagnostics.every(value => !value.includes('jar-login') && !value.includes('jar-clearance')))
  }
  for (const [sourceId, origin, cookie] of [
    ['source.other', 'https://www.mangabz.com', 'mangabz_lang=1'],
    ['com.mangabz.koma', 'https://mangabz.com.evil.invalid', 'mangabz_lang=1'],
    ['com.mangabz.koma', 'https://www.mangabz.com', 'mangabz_lang=9'],
  ]) {
    const f = granted(sourceId, origin)
    const result = await f.http([response()], JSON.stringify(f.identity()), { url: origin + '/browse', headers: { Cookie: cookie } })
    assert.equal(result.calls[0].options.header.Cookie,
      'cf_clearance=jar-clearance; session=jar-login; mangabz_lang=1; mangabz_lang=2; other=kept')
  }
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
  const registeredBytes = new Uint8Array([0])
  f.changeEntry(entry => ({ ...entry, wasmBytes: registeredBytes }))
  const features = moduleFrom('SourceHostFeatures', () => ({}))
  const executionIdentity = moduleFrom('SourceRuntimeExecutionIdentity', () => ({}))
  const queue = declarations('sourceRuntime/SourceRuntimeWorker', ['runBrowseSourceOperationTask']) + '\n' +
    declarations('viewmodel/BrowseViewModel', ['SOURCE_OPERATION_CONCURRENCY', 'sourceOperationQueue', 'enqueueSourceOperation'])
  const method = declarations('viewmodel/BrowseViewModel', ['runSourceOperationResponse'], 'BrowseViewModel')
  const source = `${queue}\nexport class Host { ${method} }`
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, { exports, ...features, ...executionIdentity, AppStrings: { get: key => key }, sourceHttpIdentityJson: f.api.sourceHttpIdentityJson,
    diagnoseSourceOperation: (_request, run) => run(), taskpool: { execute: (fn, ...args) => fn(...args) },
    require: name => {
      assert.equal(name, 'libkoma_source_runtime.so')
      return { runJsonCallFromBytes: (request, bytes, context, sourceId) => {
        nativeCalls.push({ request, bytes, context, sourceId }); return JSON.stringify({ ok: true })
      } }
    } })
  const host = new exports.Host()
  host.registry = { lookup: id => ({ ...f.registry.lookup(id), ok: id === 'source.one' }) }
  host.buildRequestJson = () => JSON.stringify({ operation: 'get_home', settings: { traditional: false }, sourceId: 'wasm-forged', packageIdentity: 'forged' })
  await assert.rejects(host.runSourceOperationResponse('missing', 'get_home', {}, 1), /browse_error_source_unavailable/)
  assert.equal(nativeCalls.length, 0)
  await host.runSourceOperationResponse('source.one', 'get_home', {}, 1)
  assert.equal(nativeCalls.length, 1)
  assert.equal(nativeCalls[0].sourceId, 'source.one')
  assert.notStrictEqual(nativeCalls[0].bytes, registeredBytes)
  assert.deepEqual(Array.from(nativeCalls[0].bytes), Array.from(registeredBytes))
  assert.deepEqual(JSON.parse(nativeCalls[0].context), f.identity())
  assert.equal(JSON.parse(nativeCalls[0].request).sourceId, 'wasm-forged')
  assert.deepEqual(JSON.parse(nativeCalls[0].request).settings, { traditional: false })
  assert(JSON.parse(nativeCalls[0].request).hostFeatures.includes('mangabz_language_cookie_v1'))
  assert(!nativeCalls[0].context.includes('cookie-value'))
})

test('Browse queue lets another source proceed while discarding stale waiting searches', async () => {
  const exports = {}, calls = []
  const queue = declarations('viewmodel/BrowseViewModel', ['SOURCE_OPERATION_CONCURRENCY', 'sourceOperationQueue', 'enqueueSourceOperation']) +
    '\nexport { enqueueSourceOperation }'
  const js = ts.transpileModule(queue, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, {
    exports,
    runBrowseSourceOperationTask: () => {},
    diagnoseSourceOperation: (_request, run) => run(),
    taskpool: { execute: (_fn, request, _bytes, identity) => new Promise((resolve, reject) => {
      calls.push({ request, identity, resolve, reject })
    }) },
  })
  let current = true
  const bytes = new Uint8Array([1])
  const slow = exports.enqueueSourceOperation('slow', bytes, 'source-one', 'source-one', () => true)
  const otherSlow = exports.enqueueSourceOperation('other-slow', bytes, 'source-two', 'source-two', () => true)
  const failure = exports.enqueueSourceOperation('failed', bytes, 'source-three', 'source-three', () => true).catch(error => error.message)
  const fast = exports.enqueueSourceOperation('fast', bytes, 'source-four', 'source-four', () => true)
  const obsolete = exports.enqueueSourceOperation('obsolete', bytes, 'source-five', 'source-five', () => current).catch(error => error.message)
  const next = exports.enqueueSourceOperation('next', bytes, 'source-six', 'source-six', () => true)
  await new Promise(setImmediate)
  assert.deepEqual(calls.map(call => call.request), ['slow', 'other-slow', 'failed', 'fast'])
  current = false
  calls[2].reject(new Error('network'))
  assert.equal(await failure, 'network')
  await new Promise(setImmediate)
  assert.equal(await obsolete, 'search_cancelled')
  assert.deepEqual(calls.map(call => call.request), ['slow', 'other-slow', 'failed', 'fast', 'next'])
  assert.equal(calls[4].identity, 'source-six')
  calls[4].resolve('next result')
  calls[3].resolve('fast result')
  calls[0].resolve('slow result')
  calls[1].resolve('other slow result')
  assert.equal(await next, 'next result')
  assert.equal(await fast, 'fast result')
  assert.equal(await slow, 'slow result')
  assert.equal(await otherSlow, 'other slow result')
})

test('repeated operations for one source cannot occupy all workers and block another source', async () => {
  const exports = {}, calls = []
  const queue = declarations('viewmodel/BrowseViewModel', ['SOURCE_OPERATION_CONCURRENCY', 'sourceOperationQueue', 'enqueueSourceOperation']) +
    '\nexport { enqueueSourceOperation }'
  const js = ts.transpileModule(queue, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  vm.runInNewContext(js, {
    exports, runBrowseSourceOperationTask: () => {}, diagnoseSourceOperation: (_request, run) => run(),
    taskpool: { execute: (_fn, request) => new Promise(resolve => { calls.push({ request, resolve }) }) },
  })
  const bytes = new Uint8Array([1])
  const first = exports.enqueueSourceOperation('a1', bytes, '{}', 'a')
  const second = exports.enqueueSourceOperation('a2', bytes, '{}', 'a')
  const third = exports.enqueueSourceOperation('a3', bytes, '{}', 'a')
  const fourth = exports.enqueueSourceOperation('a4', bytes, '{}', 'a')
  const other = exports.enqueueSourceOperation('b1', bytes, '{}', 'b')
  await new Promise(setImmediate)
  assert.deepEqual(calls.map(call => call.request), ['a1', 'b1'])
  calls[1].resolve('b'); assert.equal(await other, 'b')
  const serial = [first, second, third, fourth]
  for (let index = 0; index < serial.length; index++) {
    calls.find(call => call.request === `a${index + 1}`).resolve('done')
    assert.equal(await serial[index], 'done')
    await new Promise(setImmediate)
  }
  assert.deepEqual(calls.map(call => call.request), ['a1', 'b1', 'a2', 'a3', 'a4'])
})

test('shared Native worker retains each invocation request, bytes, HTTP context, reply and thrown error', () => {
  const calls = [], bytes = new Uint8Array([1]); let failure
  const features = moduleFrom('SourceHostFeatures', () => ({}))
  const executionIdentity = moduleFrom('SourceRuntimeExecutionIdentity', () => ({}))
  const native = moduleFrom('NativeSourceRuntime', name => {
    if (name === './SourceRuntimeExecutionIdentity') return executionIdentity
    if (name === 'libkoma_source_runtime.so') return { default: { runJsonCallFromBytes: (...args) => {
      if (failure) throw failure
      calls.push(args); return JSON.stringify({ ok: false, reasonCode: 'not_implemented' })
    } } }
    throw Error('unexpected native dependency: ' + name)
  })
  const worker = moduleFrom('SourceRuntimeWorker', name => {
    if (name === './SourceHostFeatures') return features
    if (name === './SourceRuntimeExecutionIdentity') return executionIdentity
    if (name !== './NativeSourceRuntime') throw Error('unexpected worker dependency: ' + name)
    return native
  })
  for (const operation of ['get_manga', 'get_chapters', 'get_pages', 'get_image_request', 'source_info', 'get_settings']) {
    const request = JSON.stringify({ operation, settings: { traditional: true } }), context = JSON.stringify({ sourceId: operation })
    assert.deepEqual(JSON.parse(worker.executeSourceRuntimeRequest(request, bytes, context)), { ok: false, reasonCode: 'not_implemented' })
    const received = JSON.parse(calls.at(-1)[0])
    assert.equal(received.operation, operation)
    assert.deepEqual(received.settings, { traditional: true })
    if (operation === 'source_info') assert.equal(calls.at(-1)[0], request)
    else assert(received.hostFeatures.includes('mangabz_language_cookie_v1'))
    assert.equal(calls.at(-1)[1], bytes); assert.equal(calls.at(-1)[2], context)
    assert.equal(calls.at(-1)[3], operation)
  }
  worker.executeSourceRuntimeRequest(JSON.stringify({operation:'get_manga'}), bytes,
    JSON.stringify({sourceId:'one',detailChapterContext:true}))
  assert(JSON.parse(calls.at(-1)[0]).hostFeatures.includes('source_detail_chapter_context_v1'))
  worker.executeSourceRuntimeRequest(JSON.stringify({operation:'search'}), bytes,
    JSON.stringify({sourceId:'one',operationGuardId:'search-1'}))
  assert(JSON.parse(calls.at(-1)[0]).hostFeatures.includes('source_http_challenge_cause_v1'))
  worker.executeSourceRuntimeRequest(JSON.stringify({operation:'get_manga'}), bytes, JSON.stringify({sourceId:'one'}))
  const normalFeatures=JSON.parse(calls.at(-1)[0]).hostFeatures
  assert(!normalFeatures.includes('source_detail_chapter_context_v1'))
  assert(!normalFeatures.includes('source_http_challenge_cause_v1'))
  failure = Error('Native failure')
  assert.throws(() => worker.executeSourceRuntimeRequest('{}', bytes, ''), error => error === failure)
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

// A HEAD probe must use NetworkKit's body-free verb and retain the source timeout.
test('anonymous source HEAD uses the native verb without a custom GET override', async () => {
  const f = fixture()
  const out = await f.http([{responseCode:200,result:'',header:{'content-length':'2299450'}}], '',
    {method:'HEAD',timeoutMs:1500})
  assert.equal(out.calls.length,1)
  assert.equal(out.calls[0].options.method,'HEAD')
  assert.equal(out.calls[0].options.customMethod,undefined)
  assert.equal(out.calls[0].options.extraData,undefined)
  assert.equal(out.calls[0].options.readTimeout,1500)
  assert.equal(out.result.status,200)
  assert.equal(out.result.bodyText,'')
  assert.equal(f.fetched.length,0)
})
test('GET POST and extension verbs retain their request-method behavior', async () => {
  for(const method of ['GET','POST','PROPFIND']) {
    const f = fixture(), out = await f.http([response()], '', {method})
    assert.equal(out.calls[0].options.method,method==='POST'?'POST':'GET')
    assert.equal(out.calls[0].options.customMethod,method==='PROPFIND'?'PROPFIND':undefined)
  }
})


function homepageFixture({entry={sourceId:'one'},cached=[],fresh={ok:true,entries:[]},cacheFails=false,indexFails=false}={}){
 const source=fs.readFileSync(path.join(base,'SourcePackageMetadata.ets'),'utf8')
 const tree=ts.createSourceFile('importer',source,ts.ScriptTarget.Latest,true)
 const guard=tree.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text==='normalizeSourceHomepage')
 const exports={};vm.runInNewContext(ts.transpileModule(guard.getText(tree),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,
  {exports,url:{URL:{parseURL:value=>new URL(value)}}})
 let cacheReads=0,fetches=0,savedReads=0;const pushed=[]
 const api=moduleFrom('SourceHomepageNavigation',name=>{
  if(name==='./SourcePackageImporter')return exports
  if(name==='./SourceRuntimeAppRegistry')return {appSourceRuntimeRegistry:{lookup:id=>({entry:id==='one'?entry:undefined})}}
  if(name==='../common/RouterHelper')return {RouterHelper:{pushMangaWeb:params=>pushed.push(params)}}
  if(name==='./SourceIndexService')return {SourceIndexService:class{
   async loadSavedUrl(){savedReads++;return 'https://index.test/index.json'}
   async loadCachedIndex(){cacheReads++;if(cacheFails)throw Error('cache');return cached}
   async fetchIndex(){fetches++;if(indexFails)throw Error('network');return fresh}
  }}
  throw Error('unexpected navigation dependency '+name)
 })
 return {api,guard:exports.normalizeSourceHomepage,pushed,get reads(){return {cacheReads,fetches,savedReads}}}
}
test('homepage URL parsing preserves full HTTP(S) page paths and rejects non-navigation addresses',()=>{
 const {guard}=homepageFixture()
 for(const good of ['https://example.org/comics/?type=all#list','http://127.0.0.1:8080/comics/','https://例子.cn/漫画'])assert.equal(guard(good),good)
 for(const bad of [undefined,1,{},'', '/relative','//example.org','https:example.org','file:///local','data:text/html,hello','javascript:alert(1)',
  'https://user:secret@example.org/','https://example.org/ x',' https://example.org/','https://example.org/\\evil','https://example.org:99999/'])assert.equal(guard(bad),undefined)
})
test('installed homepage opens immediately even when browse failed, with no index IO or session grant',async()=>{
 const f=homepageFixture({entry:{sourceId:'one',packageHomepage:'https://website.example/comics/',webSessionOrigins:['https://session.example']}})
 assert.equal(await f.api.openSourceHomepage({},'one','Site',()=>true),true)
 assert.deepEqual({...f.pushed[0]},{url:'https://website.example/comics/',title:'Site'})
 assert.deepEqual(f.reads,{cacheReads:0,fetches:0,savedReads:0})
})
test('legacy packages use declared same-source cached homepage before fallback origins; unrelated/API fields are ignored',async()=>{
 const f=homepageFixture({entry:{sourceId:'one',webSessionOrigins:['https://session.example']},cached:[
  {id:'other',homepage:'https://wrong.example'},{id:'one',homepage:'https://website.example'}]})
 assert.equal(await f.api.resolveSourceHomepage({},'one'),'https://website.example');assert.equal(f.reads.fetches,0)
 const missing=homepageFixture({cached:[{id:'other',homepage:'https://wrong.example'},{id:'one',apiUrl:'https://api.example',icon:'https://cdn.example/icon.png'}]})
 assert.equal(await missing.api.resolveSourceHomepage({},'one'),undefined)
 assert.equal(await missing.api.resolveSourceHomepage({},'not-installed'),undefined)
})
test('existing explicit origin remains usable after an index cache failure without new fetches',async()=>{
 const f=homepageFixture({entry:{sourceId:'one',webSessionOrigins:['https://session.example']},cacheFails:true})
 assert.equal(await f.api.resolveSourceHomepage({},'one'),'https://session.example');assert.equal(f.reads.fetches,0)
})
test('old cached shape can adopt explicit homepage from fresh index metadata without installing a package',async()=>{
 const f=homepageFixture({cached:[{id:'one'}],fresh:{ok:true,entries:[{id:'one',homepage:'https://website.example'}]}})
 assert.equal(await f.api.resolveSourceHomepage({},'one'),'https://website.example');assert.equal(f.reads.fetches,1)
})
test('missing or failed optional metadata does not push an invalid page; retired route cannot open later',async()=>{
 for(const props of [{fresh:{ok:false,entries:[{id:'one',homepage:'https://website.example'}]}},{indexFails:true}]){
  const f=homepageFixture(props);assert.equal(await f.api.openSourceHomepage({},'one','Site',()=>true),false);assert.equal(f.pushed.length,0)
 }
 const f=homepageFixture({entry:{sourceId:'one',packageHomepage:'https://website.example'}})
 assert.equal(await f.api.openSourceHomepage({},'one','Site',()=>false),true);assert.equal(f.pushed.length,0)
})


// 2026-10-27 user decision: no address means no advertised action;
// retain independently known addresses even when browse/search contents fail.
test('ordinary source menus advertise only already-known website addresses',()=>{
 const file=path.join(base,'../pages/Index.ets'),sourceText=fs.readFileSync(file,'utf8').replace(/\bstruct /g,'class ')
 const tree=ts.createSourceFile('Index',sourceText,ts.ScriptTarget.Latest,true)
 const owner=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='Index')
 const methods=['sourceHomepageMenuItem','sourceBrowseTitleBarOpts','sourceSearchTitleBarOpts']
 const body=methods.map(name=>owner.members.find(n=>n.name?.getText(tree)===name).getText(tree)).join('\n')
 const exports={};vm.runInNewContext(ts.transpileModule('export class Subject {'+body+'}',{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{
  exports,AppStrings:{get:key=>key},$r:key=>key,sourceDisplayName:(_id,name)=>name,
  normalizeSourceHomepage:homepageFixture().guard,appSourcePackageManagerCache:{indexEntries:[]},RouterHelper:{pushMangaWeb(){}},
  BottomBuilderShowType:{DIRECTLY_SHOW:1},SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT:1,SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT:1})
 const subject=new exports.Subject();subject.browseFieldContent=()=>({});subject.sourceSearchFieldContent=()=>({});subject.sourceRouteTitleBarOpts=opts=>opts
 const source={sourceId:'one',displayName:'Site',enabled:true,homepage:'https://site.example/'},chrome={visible:true,filtersAvailable:false,settingsAvailable:false,webSessionAvailable:false}
 for(const method of ['sourceBrowseTitleBarOpts','sourceSearchTitleBarOpts']){
  const opts=subject[method]({source,chrome})
  assert.deepEqual(Array.from(opts.menu.value,item=>item.content.label),['manga_detail_menu_open_webview'])
  assert.equal(opts.menu.value[0].content.isEnabled,true)
  chrome.webSessionAvailable=true
  const withSession=subject[method]({source,chrome})
  assert.deepEqual(Array.from(withSession.menu.value,item=>item.content.label),['manga_detail_menu_open_webview','source_web_open'])
  chrome.webSessionAvailable=false
  const absent=subject[method]({source:{...source,homepage:undefined},chrome})
  assert.equal(absent.menu.value.length,0)
 }
})


test('documented Cloudflare mitigation marker crosses the host without exposing headers or granting a session', async () => {
  for (const status of [401, 403, 503]) {
    for (const name of ['cf-mitigated', 'CF-Mitigated', 'Cf-Mitigated']) {
      const f = fixture()
      const result = await f.http([{ responseCode: status, result: 'challenge-page-body', header: {
        [name]: 'challenge', 'set-cookie': 'private-response-cookie', 'cf-ray': 'private-ray-id',
      } }], JSON.stringify(f.identity()))
      assert.equal(result.result.ok, true)
      assert.equal(result.result.status, status)
      assert.equal(result.result.bodyText, 'challenge-page-body')
      assert.equal(result.result.accessSignal, 'challenge_required')
      assert.equal(result.result.networkPerformed, true)
      assert.equal(f.store.status('source.one').state, 'none')
      assert.equal(f.fetched.length, 0)
      assert.equal(f.configured.length, 0)
      assert.equal(result.calls.length, 1)
      for (const secret of ['private-response-cookie', 'private-ray-id']) {
        assert(!JSON.stringify(result.result).includes(secret))
        assert(!f.diagnostics.join(' ').includes(secret))
      }
      assert(!f.diagnostics.join(' ').includes('challenge-page-body'))
    }
  }
})

test('ordinary HTTP failures and body keywords do not become Cloudflare challenges', async () => {
  for (const header of [{}, {server:'cloudflare'}, {'cf-mitigated':'guardrails'},
    {'cf-mitigated':'Challenge'}, {'cf-mitigated':['challenge']}, {'x-cf-mitigated':'challenge'}]) {
    const f = fixture()
    const body = '<html>challenge_required cf-chl /cdn-cgi/challenge-platform</html>'
    const result = await f.http([{responseCode:403,result:body,header}], '',
      {headers:{'cf-mitigated':'challenge'}})
    assert.deepEqual(result.result, {ok:true,status:403,bodyText:body,networkPerformed:true})
    assert.equal(result.calls.length,1)
    assert.equal(f.store.status('source.one').state,'none')
    assert(!f.diagnostics.some(line=>line.includes('signal=challenge_required')))
  }
})

test('missing or malformed response headers retain the existing HTTP result', async () => {
  for (const header of [undefined, null, '', [], 42]) {
    const f = fixture()
    const result = await f.http([{responseCode:200,result:'retained-body',header}], '')
    assert.deepEqual(result.result,{ok:true,status:200,bodyText:'retained-body',networkPerformed:true})
  }
})

test('challenge signal follows each response and retains only the allowed rejected URL', async () => {
  const f = fixture()
  const challenged = await f.http([response(403, {'cf-mitigated':'challenge'})], JSON.stringify(f.identity()),
    {url:'https://site.invalid/category/order/hits/page/1'})
  assert.equal(challenged.result.accessSignal,'challenge_required')
  assert.equal(f.store.launchUrl(f.registry,'source.one'),'https://site.invalid/category/order/hits/page/1')
  const ordinary = await f.http([response()], JSON.stringify(f.identity()))
  assert.equal(ordinary.result.accessSignal,undefined)
  const rejected = await f.http([response(403, {'cf-mitigated':'challenge'})], JSON.stringify(f.identity()),
    {url:'https://other.invalid/not-allowed'})
  assert.equal(rejected.result.accessSignal,'challenge_required')
  assert.equal(f.store.launchUrl(f.registry,'source.one'),'https://site.invalid/category/order/hits/page/1')
  assert.equal(f.store.status('source.one').state,'none')
  assert.equal(f.fetched.length,0)
})

test('API26 includes only the requested first-party partition while API23-25 keep the old overload', () => {
  for (const version of [23,24,25,26,27]) {
    const f=fixture(version);f.grant()
    const session=f.store.requestSession(f.identity(),'https://site.invalid/a?original=query')
    assert.equal(session.cookie,'private-cookie-value')
    assert.deepEqual(f.cookieReads,[version>=26?['https://site.invalid/a?original=query',false,true]:['https://site.invalid/a?original=query',false]])
    assert.equal(f.store.requestSession(f.identity(),'https://other.invalid/'),undefined)
    assert.equal(f.cookieReads.length,1,'an ungranted origin cannot read any cookie partition')
    assert.equal(JSON.stringify(f.diagnostics).includes('private-cookie-value'),false)
  }
})

test('native session records only the clearance category, never a cookie value', async () => {
  const f=fixture();f.grant()
  for (const [cookie, state] of [['sid=secret', 'missing'], ['cf_clearance=', 'empty'],
    ['cf_clearance=secret', 'present'], ['cf_clearance=secret; cf_clearance=other', 'ambiguous']]) {
    f.setCookie(cookie);f.diagnostics.length=0
    await f.http([response()],JSON.stringify(f.identity()))
    assert.ok(f.diagnostics.includes('state='+state))
    assert.equal(JSON.stringify(f.diagnostics).includes('secret'),false)
  }
})


test('pending probe session is scoped and never publishes an ordinary request grant', () => {
  const f=fixture(26), id=f.identity(), pending=f.store.begin(f.registry,id.sourceId,'https://site.invalid/a')
  const proof={sessionId:pending.sessionId,initialUrl:'https://site.invalid/a',documentUrl:'https://site.invalid/a',userAgent:'ActualUA'}
  assert.equal(f.store.pendingRequestSession(id,'https://site.invalid/a',proof).cookie,'private-cookie-value')
  assert.equal(f.store.requestSession(id,'https://site.invalid/a'),undefined)
  assert.equal(f.store.status(id.sourceId).state,'none');assert.equal(f.writes.length,0)
  for (const bad of [{...proof,sessionId:'stale'},{...proof,initialUrl:'https://site.invalid/other'},
    {...proof,documentUrl:'https://other.invalid/'},{...proof,userAgent:'bad\r\nUA'}]) {
    assert.equal(f.store.pendingRequestSession(id,'https://site.invalid/a',bad),undefined)
  }
  assert.equal(f.store.pendingRequestSession(id,'https://other.invalid/a',proof),undefined)
  f.store.cancel(id.sourceId,pending.sessionId)
  assert.equal(f.store.pendingRequestSession(id,'https://site.invalid/a',proof),undefined)
})

test('successful native verification hands the exact original GET response over once without a duplicate network read', async () => {
  const f=fixture(26), context=JSON.stringify(f.identity()), pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const original=JSON.stringify({url:'https://site.invalid/a',method:'GET'})
  const result=await f.http([response(403),response(200),response(200)],context,{}, {afterInitial:async ({transport,execute})=>{
    assert.equal(await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true),true)
    assert.equal(f.store.status('source.one').state,'none');assert.equal(f.writes.length,0)
    f.store.complete('source.one',pending.sessionId,'https://site.invalid/a','ActualUA')
    const handed=JSON.parse(await execute(original,context))
    const repeated=JSON.parse(await execute(original,context))
    return {handed,repeated}
  }})
  assert.equal(result.calls.length,3,'initial refusal + probe + one later independent request')
  assert.equal(result.after.handed.status,200);assert.equal(result.after.repeated.status,200)
  assert.equal(f.diagnostics.filter(x=>x==='state=used_once').length,1)
  assert.equal(JSON.stringify(f.diagnostics).includes('cookie-value'),false)
})

test('a verified search response is reserved for its original search even when another sends the same GET', async () => {
  const f=fixture(26), first=f.guards.newSourceRuntimeOperationGuardId(), other=f.guards.newSourceRuntimeOperationGuardId()
  let releaseFirst=f.guards.registerSourceRuntimeOperationGuard(first,()=>true)
  const context=JSON.stringify({...f.identity(),operationGuardId:first})
  const otherContext=JSON.stringify({...f.identity(),operationGuardId:other})
  const pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const original=JSON.stringify({url:'https://site.invalid/a',method:'GET'})
  const r=await f.http([response(403),response(200,{},'verified'),response(200,{},'other')],context,{}, {
    afterInitial:async({transport,execute})=>{
      releaseFirst()
      assert.equal(await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true,first),true)
      f.store.complete('source.one',pending.sessionId,'https://site.invalid/a','ActualUA')
      const releaseOther=f.guards.registerSourceRuntimeOperationGuard(other,()=>true)
      const unrelated=JSON.parse(await execute(original,otherContext));releaseOther()
      releaseFirst=f.guards.registerSourceRuntimeOperationGuard(first,()=>true)
      const handed=JSON.parse(await execute(original,context));releaseFirst()
      return {unrelated,handed}
    },
  })
  assert.equal(r.calls.length,3)
  assert.equal(r.after.unrelated.bodyText,'other')
  assert.equal(r.after.handed.bodyText,'verified')
  assert.equal(f.diagnostics.filter(x=>x==='state=used_once').length,1)
})

test('same-source searches retain their own rejected GET for verification', async () => {
  const f=fixture(26), first=f.guards.newSourceRuntimeOperationGuardId(), other=f.guards.newSourceRuntimeOperationGuardId()
  const releaseFirst=f.guards.registerSourceRuntimeOperationGuard(first,()=>true)
  const releaseOther=f.guards.registerSourceRuntimeOperationGuard(other,()=>true)
  const firstContext=JSON.stringify({...f.identity(),operationGuardId:first})
  const otherContext=JSON.stringify({...f.identity(),operationGuardId:other})
  const original=JSON.stringify({url:'https://site.invalid/a',method:'GET'})
  const r=await f.http([response(403),response(403),response(200,{},'first verified')],firstContext,{}, {
    afterInitial:async({transport,execute})=>{
      await execute(JSON.stringify({url:'https://site.invalid/b',method:'GET'}),otherContext)
      assert.equal(transport.sourceRejectedRequestUrl('source.one',first),'https://site.invalid/a')
      assert.equal(transport.sourceRejectedRequestUrl('source.one',other),'https://site.invalid/b')
      const pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
      assert.equal(await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true,first),true)
      f.store.complete('source.one',pending.sessionId,'https://site.invalid/a','ActualUA')
      const handed=JSON.parse(await execute(original,firstContext))
      transport.clearSourceRejectedRequest('source.one',first)
      assert.equal(transport.sourceRejectedRequestUrl('source.one',first),'')
      return handed
    },
  })
  releaseFirst();releaseOther()
  assert.equal(r.calls.length,3)
  assert.equal(r.calls[2].fullUrl,'https://site.invalid/a')
  assert.equal(r.after.bodyText,'first verified')
})

test('multiple different rejected GETs in one search cannot be mistaken for the challenged request', async () => {
  const f=fixture(), id=f.guards.newSourceRuntimeOperationGuardId()
  const release=f.guards.registerSourceRuntimeOperationGuard(id,()=>true)
  const context=JSON.stringify({...f.identity(),operationGuardId:id})
  const r=await f.http([response(403),response(403)],context,{}, {afterInitial:async({transport,execute})=>{
    await execute(JSON.stringify({url:'https://site.invalid/b',method:'GET'}),context)
    const pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
    return {url:transport.sourceRejectedRequestUrl('source.one',id),
      probed:await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true,id)}
  }})
  release()
  assert.equal(r.calls.length,2)
  assert.equal(r.after.url,'')
  assert.equal(r.after.probed,false)
})

test('source-provided challenge ID selects only its own actual rejected GET', async () => {
  const f=fixture(), id=f.guards.newSourceRuntimeOperationGuardId()
  const release=f.guards.registerSourceRuntimeOperationGuard(id,()=>true)
  const context=JSON.stringify({...f.identity(),operationGuardId:id})
  const r=await f.http([response(403),response(403)],context,{wantChallengeRequestId:true,headers:{'User-Agent':'Source UA'}}, {
    afterInitial:async({transport,execute})=>{
      const later=JSON.parse(await execute(JSON.stringify({url:'https://site.invalid/b',method:'GET',wantChallengeRequestId:true}),context))
      return { transport,later }
    },
  })
  assert.equal(typeof r.result.challengeRequestId,'string')
  assert.notEqual(r.result.challengeRequestId,r.after.later.challengeRequestId)
  const transport=r.after.transport
  assert.equal(transport.sourceRejectedRequestUrl('source.one',id),'')
  assert.equal(transport.sourceRejectedRequestUserAgent('source.one',id,'https://site.invalid/a'),undefined)
  transport.selectSourceRejectedRequest('source.one',id,r.result.challengeRequestId)
  assert.equal(transport.sourceRejectedRequestUrl('source.one',id),'https://site.invalid/a')
  assert.equal(transport.sourceRejectedRequestUserAgent('source.one',id,'https://site.invalid/a'),'Source UA')
  assert.equal(transport.sourceRejectedRequestUserAgent('source.one',id,'https://site.invalid/b'),undefined)
  transport.selectSourceRejectedRequest('source.one',id,'forged')
  assert.equal(transport.sourceRejectedRequestUrl('source.one',id),'')
  transport.selectSourceRejectedRequest('another.source',id,r.after.later.challengeRequestId)
  assert.equal(transport.sourceRejectedRequestUrl('another.source',id),'')
  transport.clearSourceRejectedRequest('source.one',id)
  assert.equal(transport.sourceRejectedRequestUserAgent('source.one',id,'https://site.invalid/a'),undefined)
  transport.selectSourceRejectedRequest('source.one',id,r.result.challengeRequestId)
  assert.equal(transport.sourceRejectedRequestUrl('source.one',id),'')
  release()
})

test('an unrelated concurrent search request cannot consume the verified original response', async () => {
  const f=fixture(26), context=JSON.stringify(f.identity())
  const pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const original=JSON.stringify({url:'https://site.invalid/a',method:'GET'})
  const result=await f.http([response(403),response(200),response(200),response(200)],context,{}, {
    afterInitial:async ({transport,execute})=>{
      assert.equal(await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true),true)
      f.store.complete('source.one',pending.sessionId,'https://site.invalid/a','ActualUA')
      await execute(JSON.stringify({url:'https://site.invalid/other',method:'GET'}),context)
      const handed=JSON.parse(await execute(original,context))
      const repeated=JSON.parse(await execute(original,context))
      return {handed,repeated}
    },
  })
  assert.equal(result.calls.length,4,'refusal + verification + unrelated request + later independent original')
  assert.equal(result.after.handed.status,200)
  assert.equal(result.after.repeated.status,200)
  assert.equal(f.diagnostics.filter(x=>x==='state=used_once').length,1)
})

test('failed native probe keeps the pending manual completion usable and does not cache a refused response', async () => {
  const f=fixture(), context=JSON.stringify(f.identity()), pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const r=await f.http([response(403),response(403),response(200)],context,{}, {afterInitial:async ({transport,execute})=>{
    const ready=await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true)
    assert.equal(ready,false);assert.equal(f.store.status('source.one').state,'none')
    f.store.complete('source.one',pending.sessionId,'https://site.invalid/a','ActualUA')
    return JSON.parse(await execute(JSON.stringify({url:'https://site.invalid/a',method:'GET'}),context))
  }})
  assert.equal(r.calls.length,3);assert.equal(r.after.status,200)
  assert.equal(f.diagnostics.includes('state=used_once'),false)
})

for (const request of [{method:'POST'},{method:'HEAD'},{method:'GET',body:'payload'}]) {
  test('verification never probes a rejected '+JSON.stringify(request),async ()=>{
    const f=fixture(), pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
    const r=await f.http([response(403)],JSON.stringify(f.identity()),request,{afterInitial:async({transport})=>
      transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true)})
    assert.equal(r.after,false);assert.equal(r.calls.length,1)
  })
}

for (const changed of ['document','session','package','route']) test('pending probe cannot leave its '+changed+' boundary', async()=>{
  const f=fixture(), context=JSON.stringify(f.identity()),pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const r=await f.http([response(403)],context,{}, {afterInitial:async({transport})=>{
    if(changed==='package')f.changeEntry(e=>({...e,wasmPath:'/app/replaced.wasm'}))
    return transport.probeSourceWebSession('source.one',changed==='session'?'wrong':pending.sessionId,
      changed==='document'?'https://other.invalid/a':'https://site.invalid/a','ActualUA',()=>changed!=='route')
  }})
  assert.equal(r.after,false);assert.equal(r.calls.length,1)
})

test('a cancelled in-flight verification cannot publish a response or grant after navigation',async()=>{
  const f=fixture(), context=JSON.stringify(f.identity()),pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  let resolve, current=true;const deferred=new Promise(r=>resolve=r)
  const r=await f.http([response(403),deferred],context,{}, {afterInitial:async({transport})=>{
    const probe=transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>current)
    await new Promise(r=>setImmediate(r));current=false
    transport.cancelSourceWebProbe('source.one',pending.sessionId);f.store.cancel('source.one',pending.sessionId)
    resolve(response(200));return probe
  }})
  assert.equal(r.after,false);assert.equal(f.writes.length,0);assert.equal(f.store.status('source.one').state,'none')
  assert.equal(f.diagnostics.includes('state=ready_for_original_request'),false)
})

test('native verification refuses an off-origin redirect before issuing its next request',async()=>{
  const f=fixture(), pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const r=await f.http([response(403),response(302,{location:'https://other.invalid/'})],JSON.stringify(f.identity()),{},
    {afterInitial:async({transport})=>transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true)})
  assert.equal(r.after,false);assert.equal(r.calls.length,2);assert.ok(r.calls.every(c=>c.fullUrl==='https://site.invalid/a'))
})

test('HTTP200 still marked as a challenge is not a successful verification',async()=>{
  const f=fixture(), pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const r=await f.http([response(403),response(200,{'cf-mitigated':'challenge'})],JSON.stringify(f.identity()),{},
    {afterInitial:async({transport})=>transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true)})
  assert.equal(r.after,false);assert.equal(f.writes.length,0)
})

for(const change of ['request','session','package','cancel'])test('verified response is not reused after '+change,async()=>{
  const f=fixture(),context=JSON.stringify(f.identity()),pending=f.store.begin(f.registry,'source.one','https://site.invalid/a')
  const r=await f.http([response(403),response(200),response(200)],context,{}, {afterInitial:async({transport,execute})=>{
    assert.equal(await transport.probeSourceWebSession('source.one',pending.sessionId,'https://site.invalid/a','ActualUA',()=>true),true)
    if(change==='cancel')transport.cancelSourceWebProbe('source.one',pending.sessionId)
    f.store.complete('source.one',pending.sessionId,'https://site.invalid/a','ActualUA')
    if(change==='session')f.grant()
    if(change==='package')f.changeEntry(e=>({...e,wasmPath:'/app/replaced.wasm'}))
    return JSON.parse(await execute(JSON.stringify({url:change==='request'?'https://site.invalid/b':'https://site.invalid/a',method:'GET'}),context))
  }})
  assert.equal(r.calls.length,3);assert.equal(r.after.status,200)
  assert.equal(f.diagnostics.includes('state=used_once'),false)
  if(change==='package')assert.equal(r.calls[2].options.header.Cookie,undefined)
})


test('HTTP hop diagnostics distinguish a timeout before headers from one after headers, without retaining header content', async () => {
  for (const headersBeforeError of [false, true]) {
    const f = fixture()
    const failed = await f.http([], '{}', {}, { headersBeforeError,
      requestError: Object.assign(Error('PRIVATE_ERROR'), { code: 2300028 }) })
    assert.equal(failed.result.error.code, 'timeout')
    assert.equal(failed.instances[0].destroyed, true)
    assert.equal(failed.instances[0].listeners.size, 0)
    assert.ok(f.diagnostics.some(line => line.includes('headersReceived=' + headersBeforeError)))
    assert.ok(!f.diagnostics.join(' ').includes('PRIVATE_'))
    assert.ok(!f.diagnostics.join(' ').includes('site.invalid'))
  }
})

test('HTTP response diagnostics expose only finite cumulative timing checkpoints and leave the response unchanged', async () => {
  const f = fixture()
  const reply = { ...response(), performanceTiming: { dnsTiming: 2.5, tcpTiming: 4, tlsTiming: 8,
    firstReceiveTiming: 12, totalFinishTiming: 14, responseBodyTiming: NaN, totalTiming: Infinity } }
  const result = await f.http([reply], '{}')
  assert.equal(result.result.status, 200)
  assert.equal(result.result.bodyText, 'public-body')
  assert.equal(result.instances[0].listeners.size, 0)
  const timing = f.diagnostics.find(line => line.includes('dnsDoneMs='))
  assert.ok(timing, 'completed responses provide the platform timing checkpoints')
  assert.ok(timing.includes('dnsDoneMs=2.5 tcpDoneMs=4 tlsDoneMs=8 firstByteMs=12 finishMs=14'))
  assert.ok(!/NaN|Infinity|private|site.invalid/.test(timing))
})

test('mirror grants retain independent origin identities across restart and revoke on replacement', () => {
  const f = fixture()
  f.changeEntry(entry => ({ ...entry, webSessionOrigins: ['https://site.invalid', 'https://mirror.invalid'] }))
  for (const [origin, ua] of [['https://site.invalid', 'SiteUA'], ['https://mirror.invalid', 'MirrorUA']]) {
    const pending = f.store.begin(f.registry, 'source.one', origin + '/verify')
    f.store.complete('source.one', pending.sessionId, origin + '/done', ua)
  }
  assert.equal(f.store.requestSession(f.identity(), 'https://site.invalid/page').userAgent, 'SiteUA')
  assert.equal(f.store.requestSession(f.identity(), 'https://mirror.invalid/page').userAgent, 'MirrorUA')
  const restarted = f.reload()
  assert.equal(restarted.requestSession(f.identity(), 'https://site.invalid/page').userAgent, 'SiteUA')
  assert.equal(restarted.requestSession(f.identity(), 'https://mirror.invalid/page').userAgent, 'MirrorUA')
  f.changeEntry(entry => ({ ...entry, manifestVersion: '2' }))
  assert.equal(restarted.requestSession(f.identity(), 'https://site.invalid/page'), undefined)
  assert.equal(restarted.requestSession(f.identity(), 'https://mirror.invalid/page'), undefined)
})
