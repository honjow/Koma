const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
function load(file, imports, suffix = '') {
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8') + suffix, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', 'setInterval', 'clearInterval', js)(exports,
    name => imports[name] ?? {}, setInterval, clearInterval)
  return exports
}
function fixture({ sdkApiVersion = 26, sourceId = 'com.picacomic.koma' } = {}) {
  const requests = [], addresses = [], replies = [], sessions = []
  let alive = true, revision = '1', allowed = true, credentialAllowed = true, sequence = 0
  let entry = { sourceId, manifestVersion: '1', enabled: true,
    authentication: { kind: 'credentials', loginUrl: 'https://picaapi.picacomic.com/auth/sign-in' } }
  let settings = {}, ordinary = 0
  let resolveAddress = async () => [{ address: '192.0.2.9' }]
  const decoder = { create: (_encoding, options) => ({ decodeToString: bytes => new TextDecoder('utf-8', options).decode(bytes) }) }
  const ark = { url: { URL }, util: { TextDecoder: decoder, generateRandomUUID: () => 'test-proof-' + ++sequence } }
  class Request { constructor(url, method, headers, content) { Object.assign(this, { url: new URL(url), method, headers, content }) } }
  const rcp = { Request, createSession(options) {
    const session = { options, closed: false }
    sessions.push(session)
    let cancelled = false
    return { cancel() { cancelled = true }, close() { session.closed = true }, async fetch(request) {
      requests.push(request)
      const reply = replies.shift() ?? { status: 200, text: '{}' }
      if (reply.before) await reply.before()
      if (cancelled) throw { code: 1007900042 }
      const buffer = Buffer.from(reply.bytes ?? reply.text ?? '')
      if (request.destination) request.destination(buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength))
      if (cancelled) throw { code: 1007900042 }
      return { statusCode: reply.status, headers: reply.headers ?? {} }
    } }
  } }
  const rcpTransport = load('sourceRuntime/SourceRcpTransport.ets', {
    '@kit.RemoteCommunicationKit': { rcp }, '@kit.ArkTS': ark,
    '../model/SourceRequiredImageDecodePrimitives': { inflateSourceGzip: async bytes => {
      const b = require('node:zlib').gunzipSync(Buffer.from(bytes)); return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)
    } },
  })
  const channel = load('sourceRuntime/SourcePicaChannelTransport.ets', {
    './SourceRcpTransport': rcpTransport, '@kit.ArkTS': ark,
    '@kit.NetworkKit': { connection: { getAddressesByName: async name => { addresses.push(name); return resolveAddress(name) } } },
  })
  const copy = load('sourceRuntime/CopyMangaHostContract.ets', { '@kit.ArkTS': ark })
  const platform = { deviceInfo: { sdkApiVersion } }
  const features = load('sourceRuntime/SourceHostFeatures.ets', {
    './CopyMangaHostContract': copy, '@kit.BasicServicesKit': platform,
  })
  const scope = { sourceId: entry.sourceId, packageIdentity: 'install-1', current: () => alive }
  const identity = { sourceId: entry.sourceId, sourceVersion: '1', packageIdentity: 'install-1', webSessionOrigins: [], privateCallId: 'call-1' }
  const privateHost = { callIsActive: () => alive, publicInitializationIsAllowed: () => allowed && alive,
    credentialRequestAllowed: (_call, grant, target) => sourceId === 'com.picacomic.koma'
      ? credentialAllowed && target.startsWith('https://picaapi.picacomic.com/') : grant === undefined }
  const trace = { info() {}, warn() {}, finish() {}, fail() {} }
  const imports = {
    './SourcePicaChannelTransport': channel, './SourceRcpTransport': rcpTransport, './CopyMangaHostContract': copy,
    '@kit.ArkTS': ark, '@kit.BasicServicesKit': platform,
    './SourceSettingsStore': { appSourceSettingsStore: { revisionForSource: () => revision, loadForSource: () => ({ ...settings }) } },
    './SourceRuntimeAppRegistry': { appSourceRuntimeRegistry: { lookup: () => ({ ok: true, entry }) } },
    './SourceRuntimeRegistry': { sourceRuntimeEntryEnabled: x => x?.enabled === true },
    './SourcePrivateSessionHost': { SourcePrivateSessionHost: privateHost },
    './SourceWebSessionStore': { sourceWebOrigin: u => { try { return new URL(u).origin } catch { return '' } },
      sourceWebPackageIdentity: () => 'install-1', appSourceWebSessionStore: { requestSession: () => undefined } },
    './SourceRuntimeOperationGuard': { sourceRuntimeOperationIsCurrent: () => alive },
    './SourceRequestPolicy': { waitForSourceRequestSlot: async () => {} },
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { begin: () => trace, info() {}, warn() {} } },
    '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET', POST: 'POST', HEAD: 'HEAD' }, HttpDataType: { STRING: 'string' },
      createHttp: () => ({ on() {}, off() {}, destroy() {}, request: async () => { ordinary++; return { responseCode: 200, result: '{}', header: {} } } }) } },
  }
  const transport = load('sourceRuntime/SourceRuntimeHttpTransport.ets', imports,
    '\nexport const executeForTest = executeSourceHttpRequest;')
  const run = request => transport.executeForTest(JSON.stringify(request), JSON.stringify(identity)).then(JSON.parse)
  const initialize = async address => {
    replies.push({ status: 200, text: JSON.stringify({ status: 'ok', addresses: [address ?? 'channel.example', 'unused.invalid'] }) })
    return channel.initializeSourcePicaChannel('http://68.183.234.72/init', scope, 15000)
  }
  return { channel, copy, features, ark, scope, identity, requests, replies, addresses, sessions, imports, run, initialize,
    ordinary: () => ordinary, setAlive: v => { alive = v }, setAllowed: v => { allowed = v },
    setResolver: fn => { resolveAddress = fn },
    setRevision: v => { revision = v }, setCredentials: v => { credentialAllowed = v },
    replaceEntry: () => { entry = { ...entry } }, setSettings: value => { settings = value } }
}

test('CopyManga API uses fresh HTTP/1.1, preserves refusals and keeps website and image transport separate', async () => {
  const f = fixture({ sourceId: 'com.copymanga.koma' })
  const headers = { 'User-Agent': 'Source fixture UA', Referer: 'https://www.mangacopy.com/' }
  const refusal = '{"code":210,"message":"fixture refusal"}'
  for (const domain of ['mangacopy.com', 'copy3000.com', 'copy4000.com']) {
    const url = 'https://api.' + domain + '/api/v3/comic/work/chapter/one?platform=1'
    f.replies.push({ status: 210, text: refusal })
    assert.deepEqual(await f.run({ version: 1, url, method: 'GET', headers }),
      { ok: true, status: 210, bodyText: refusal, networkPerformed: true })
    const request = f.requests.at(-1)
    assert.equal(request.url.toString(), url)
    assert.deepEqual(request.headers, headers)
    assert.equal(request.configuration.proxy, 'system')
    assert.equal(request.configuration.transfer.httpVersionSelectCallback(request.url), '1.1')
    assert.equal(request.configuration.transfer.connectionReusePolicy, 'forbidden')
    assert.equal(request.configuration.transfer.autoRedirect, false)
    assert.deepEqual(request.cacheControl, { noCache: true, noStore: true })
  }
  assert.deepEqual(f.sessions, Array.from({ length: 3 }, () => ({ options: undefined, closed: true })))
  assert.equal(f.ordinary(), 0)
  for (const url of ['https://www.mangacopy.com/comics', 'https://cdn.mangacopy.com/page.webp']) {
    assert.equal((await f.run({ version: 1, url, method: 'GET' })).status, 200)
  }
  assert.equal(f.ordinary(), 2)
  assert.equal(f.requests.length, 3)
  const unrelated = fixture({ sourceId: 'com.other.koma' })
  assert.equal((await unrelated.run({ url: 'https://api.mangacopy.com/api/v3/comic/work', method: 'GET' })).status, 200)
  assert.equal(unrelated.ordinary(), 1)
  assert.equal(unrelated.requests.length, 0)
})

test('CopyManga API capability, anonymous redirect bounds and saved homepage use the same declared domains', async () => {
  const sourceId = 'com.copymanga.koma', homepage = 'https://www.mangacopy.com'
  const url = 'https://api.mangacopy.com/api/v3/comic/work'
  const feature = 'source_http_copymanga_api_v1'
  const hostFeatures = (f) => JSON.parse(f.features.sourceRequestWithHostFeatures(
    JSON.stringify({ operation: 'get_manga', sourceId }))).hostFeatures
  for (const sdkApiVersion of [23, 24, 25]) {
    const old = fixture({ sourceId, sdkApiVersion })
    assert.equal(hostFeatures(old).includes(feature), false)
    const unsupported = await old.run({ url, method: 'GET' })
    assert.equal(unsupported.ok, false)
    assert.equal(unsupported.error.code, 'unsupported')
    assert.equal(unsupported.error.retryable, false)
    assert.equal(unsupported.networkPerformed, false)
    assert.equal(old.requests.length + old.ordinary(), 0)
  }
  const f = fixture({ sourceId })
  assert.equal(hostFeatures(f).includes(feature), true)
  for (const input of [{ method: 'POST' }, { headers: { COOKIE: 'private' } }, { headers: { Authorization: 'private' } }]) {
    const result = await f.run({ url, method: 'GET', ...input })
    assert.equal(result.error.code, 'invalid_request')
    assert.equal(result.networkPerformed, false)
  }
  assert.equal(f.requests.length + f.ordinary(), 0)
  f.replies.push({ status: 302, headers: { Location: ['/api/v3/comic/redirected'] } }, { status: 210, text: '{"code":210}' })
  assert.equal((await f.run({ url, method: 'GET' })).status, 210)
  assert.deepEqual(f.requests.map((request) => request.url.pathname), ['/api/v3/comic/work', '/api/v3/comic/redirected'])
  f.replies.push({ status: 302, headers: { Location: 'http://api.mangacopy.com/api/v3/comic/downgrade' } })
  assert.equal((await f.run({ url, method: 'GET' })).error.code, 'invalid_response')
  assert.equal(f.requests.length, 3)
  assert.equal(f.ordinary(), 0)
  for (const domain of ['mangacopy.com', 'copy3000.com', 'copy4000.com']) {
    assert.equal(f.copy.copyMangaSelectedHomepage(sourceId, homepage, () => 'https://api.' + domain), 'https://www.' + domain)
  }
  assert.equal(f.copy.copyMangaSelectedHomepage(sourceId, homepage, () => 'https://api.mangacopy.com.evil.invalid'), homepage)
  assert.equal(f.copy.copyMangaSelectedHomepage(sourceId, homepage, () => { throw Error('unreadable settings') }), homepage)
  const unexpectedRead = () => assert.fail('only the installed CopyManga package reads the saved mirror')
  assert.equal(f.copy.copyMangaSelectedHomepage(sourceId, undefined, unexpectedRead), undefined)
  assert.equal(f.copy.copyMangaSelectedHomepage('com.other.koma', homepage, unexpectedRead), undefined)
})

test('public preparation preserves exact unsigned redirect headers, first hostname and scoped DNS proof', async () => {
  const f = fixture()
  f.replies.push({ status: 302, headers: { Location: 'https://public.example/init' } },
    { status: 200, text: JSON.stringify({ status: 'ok', addresses: ['channel.example', 'unused.invalid'] }) })
  const response = await f.run({ type: 'pica_channel_init', version: 1 })
  assert.equal(response.status, 200)
  assert.equal(response.dnsOverride.kind, 'pica_channel_v1')
  assert.deepEqual(f.requests.map(r => r.url.href), ['http://68.183.234.72/init', 'https://public.example/init'])
  for (const request of f.requests) {
    assert.deepEqual(request.headers, { 'User-Agent': 'okhttp/3.8.1', 'Accept-Encoding': 'gzip' })
    assert.equal(request.method, 'GET'); assert.equal(request.content, undefined)
    assert.equal(request.configuration.transfer.autoRedirect, false)
    assert.equal(request.configuration.proxy, 'system')
    assert.equal(request.configuration.security, undefined)
  }
  const ip = await f.channel.sourcePicaChannelIp('https://picaapi.picacomic.com/comics', response.dnsOverride, f.scope)
  assert.equal(ip, '192.0.2.9'); assert.deepEqual(f.addresses, ['channel.example'])
  await assert.rejects(f.channel.sourcePicaChannelIp('https://picaapi.picacomic.com/', response.dnsOverride,
    { ...f.scope, packageIdentity: 'other-install' }))
  await assert.rejects(f.channel.sourcePicaChannelIp('https://other.example/', response.dnsOverride, f.scope))
  f.setSettings({ APP_CHANNEL_URL: 'https://next-process.example/init' })
  f.setRevision('2')
  const repeated = await f.run({ type: 'pica_channel_init', version: 1 })
  assert.deepEqual(repeated.dnsOverride, response.dnsOverride)
  assert.equal(f.requests.length, 2, 'same installation reuses the verified process plan without another GET')
})

test('init uses committed settings only, metadata and stale/cancelled/changed installs issue no proof', async () => {
  const f = fixture()
  f.setSettings({ APP_CHANNEL_URL: 'https://chosen.example/init' })
  f.replies.push({ status: 200, text: '{"status":"ok","addresses":["192.0.2.1"]}' })
  assert.equal((await f.run({ type: 'pica_channel_init', version: 1 })).ok, true)
  assert.equal(f.requests[0].url.href, 'https://chosen.example/init')
  const count = f.requests.length
  assert.equal((await f.run({ type: 'pica_channel_init', version: 1, url: 'https://injected.example/' })).ok, false)
  f.setAllowed(false)
  assert.equal((await f.run({ type: 'pica_channel_init', version: 1 })).ok, false)
  assert.equal(f.requests.length, count)
  for (const kind of ['revision', 'cancel', 'install', 'account']) {
    const g = fixture()
    g.replies.push({ status: 200, text: '{"status":"ok","addresses":["channel.example"]}', before: () => {
      if (kind === 'revision') g.setRevision('2')
      if (kind === 'cancel') g.setAlive(false)
      if (kind === 'install') g.replaceEntry()
      if (kind === 'account') g.setCredentials(false)
    } })
    const response = await g.run({ type: 'pica_channel_init', version: 1 })
    assert.equal(response.ok, false, kind); assert.equal(response.dnsOverride, undefined, kind)
    assert.equal(response.networkPerformed, true, kind)
  }
})

test('bad first address, refusal, resource excess and credential redirects never fall back to another route', async () => {
  for (const first of ['user@host.test', 'host.test/path', 'host.test:443', 'bad\nname', '', '999.1.2.3']) {
    const f = fixture()
    f.replies.push({ status: 200, text: JSON.stringify({ status: 'ok', addresses: [first, 'valid.example'] }) })
    await assert.rejects(f.channel.initializeSourcePicaChannel('http://68.183.234.72/init', f.scope, 15000))
    assert.equal(f.requests.length, 1); assert.equal(f.addresses.length, 0)
  }
  const f = fixture()
  f.replies.push({ status: 403, text: 'denied' })
  const refusal = await f.run({ type: 'pica_channel_init', version: 1 })
  assert.equal(refusal.status, 403); assert.equal(refusal.dnsOverride, undefined); assert.equal(f.requests.length, 1)
  f.replies.push({ status: 200, bytes: Buffer.alloc(65537) })
  const large = await f.run({ type: 'pica_channel_init', version: 1 })
  assert.equal(large.error.code, 'response_too_large'); assert.equal(large.networkPerformed, true)
  f.replies.push({ status: 200, bytes: require('node:zlib').gzipSync(Buffer.alloc(65537)) })
  assert.equal((await f.run({ type: 'pica_channel_init', version: 1 })).error.code, 'response_too_large')
  f.replies.push({ status: 302, headers: { Location: 'https://user:password@other.example/' } })
  assert.equal((await f.run({ type: 'pica_channel_init', version: 1 })).ok, false)
})

test('API POST retains URL, body, UA, signature and system TLS/proxy; ordinary channel1 stays NetworkKit', async () => {
  const f = fixture(), initialized = await f.initialize()
  const headers = { 'User-Agent': 'reference-fixture-UA', Authorization: 'fixture-token', signature: 'fixture-signature',
    'Content-Type': 'application/json; charset=UTF-8' }
  f.replies.push({ status: 200, text: '{"ok":true}' })
  const request = { version: 1, url: 'https://picaapi.picacomic.com/auth/sign-in', method: 'POST', headers,
    body: '{"fixture":1}', dnsOverride: initialized.dnsOverride }
  assert.equal((await f.run(request)).status, 200)
  const sent = f.requests.at(-1)
  assert.equal(sent.url.href, request.url); assert.equal(sent.content, request.body); assert.deepEqual(sent.headers, headers)
  assert.deepEqual(sent.configuration.dns.dnsRules, [{ host: 'picaapi.picacomic.com', port: 443, ipAddresses: ['192.0.2.9'] }])
  assert.equal(sent.configuration.security, undefined)
  f.replies.push({ status: 302, headers: { location: 'https://foreign.example/path' } })
  const redirect = await f.run(request)
  assert.equal(redirect.error.code, 'source_login_not_allowed')
  assert.equal(redirect.networkPerformed, true)
  assert.equal(f.requests.at(-1).url.hostname, 'picaapi.picacomic.com')
  f.replies.push({ status: 200, text: '{}' })
  assert.equal((await f.run(request)).status, 200)
  await f.run({ ...request, dnsOverride: undefined })
  assert.equal(f.ordinary(), 1)
})

test('cancellation while resolving a channel hostname releases the request and never starts a late HTTPS hop', async () => {
  const f = fixture(), initialized = await f.initialize()
  let complete
  f.setResolver(() => new Promise(resolve => { complete = resolve }))
  const pending = f.run({ url: 'https://picaapi.picacomic.com/comics', method: 'GET', dnsOverride: initialized.dnsOverride })
  await new Promise(resolve => setImmediate(resolve))
  assert.deepEqual(f.addresses, ['channel.example'])
  f.setAlive(false)
  const result = await pending
  assert.equal(result.error.code, 'source_request_cancelled')
  assert.equal(result.networkPerformed, false)
  complete([{ address: '192.0.2.9' }])
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(f.requests.length, 1) // only the completed unsigned initialization
})

test('the actual image descriptor and Reader byte path consume the same DNS plan for same-domain images', async () => {
  const f = fixture(), initialized = await f.initialize('channel.example')
  const source = fs.readFileSync(path.join(root, 'model/ReaderPageSourceAdapter.ets'), 'utf8')
  const tree = ts.createSourceFile('adapter', source, ts.ScriptTarget.Latest, true)
  const names = ['SourceImageRequestDescriptor', 'parseSourceImageRequestHeaders', 'parseSourceImageRequestDescriptor',
    'downloadPicaChannelImage', 'downloadReaderRemoteBytes']
  const body = names.map(name => tree.statements.find(node => node.name?.text === name).getText(tree)).join('\n')
  const js = ts.transpileModule(body + '\nexport const parse = parseSourceImageRequestDescriptor; export const download = downloadReaderRemoteBytes;',
    { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  const exports = {}, entry = { enabled: true }
  const globals = { ...f.channel, url: { URL }, appSourceRuntimeRegistry: { lookup: () => ({ entry }) },
    appSourceSettingsStore: { revisionForSource: () => '1' }, sourceHttpIdentityJson: () => '{"packageIdentity":"install-1"}',
    waitForSourceRequestSlot: async () => {}, sourceRequiredImageDecode: () => { throw Error('unexpected decode') } }
  new Function('exports', ...Object.keys(globals), js)(exports, ...Object.values(globals))
  const descriptor = exports.parse(JSON.stringify({ data: { url: 'https://storage1.picacomic.com/image.jpg',
    headers: { 'User-Agent': 'image-UA' }, dnsOverride: initialized.dnsOverride } }))
  const pixels = Buffer.from([255, 216, 255, 1, 2, 3]); f.replies.push({ status: 200, bytes: pixels })
  assert.deepEqual(Buffer.from(await exports.download(descriptor.url, descriptor.headers, 'com.picacomic.koma', descriptor.dnsOverride)), pixels)
  assert.equal(f.requests.at(-1).configuration.dns.dnsRules[0].host, 'storage1.picacomic.com')
  assert.equal(f.requests.at(-1).headers['User-Agent'], 'image-UA')
})
