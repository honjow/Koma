const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets/diagnostics')

function runtime() {
  const files = new Map(), modules = new Map(), emitted = []
  let failWrites = false
  const io = {
    OpenMode: { READ_WRITE: 1, CREATE: 2, APPEND: 4, TRUNC: 8 },
    mkdirSync() {}, accessSync: name => files.has(name),
    openSync(name) { if (!files.has(name)) files.set(name, ''); return { fd: name } },
    closeSync() {},
    writeSync(name, value) { if (failWrites) throw Error('disk full'); files.set(name, files.get(name) + value) },
    listFileSync: dir => [...files.keys()].filter(name => name.startsWith(dir + '/')).map(name => name.slice(dir.length + 1)),
    readTextSync: name => files.get(name) || '',
    statSync: name => ({ size: Buffer.byteLength(files.get(name) || '') }),
    unlinkSync: name => files.delete(name),
  }
  function load(name) {
    if (name === '@kit.CoreFileKit') return { fileIo: io, fileUri: { getUriFromPath: value => 'file://' + value } }
    if (name === '@kit.PerformanceAnalysisKit') return { hilog: new Proxy({}, { get: () => (...args) => emitted.push(args) }) }
    if (name === '@kit.AbilityKit') return {}
    if (name === './NativeSourceRuntime') return { NativeSourceRuntime: {} }
    const key = path.basename(name)
    if (modules.has(key)) return modules.get(key)
    const exports = {}
    modules.set(key, exports)
    vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, key === 'SourceRuntimeRunner' ? '../sourceRuntime/SourceRuntimeRunner.ets' : key + '.ets'), 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    }).outputText, { exports, require: load, Date, console, Map })
    return exports
  }
  return { load, files, emitted, failWrites: () => { failWrites = true } }
}

test('redacts whole headers, credentials, URLs and private paths before truncation', () => {
  const { DiagnosticsRedactor: redactor } = runtime().load('DiagnosticsRedactor')
  const input = 'Cookie: sid=secretA; token=secretB\nAuthorization: Basic secretC\n' +
    'Bearer secretD https://user:secretE@example.org/book/Title?key=secretF ' +
    'password="my secret G" {"api_key":"secretH"} /data/storage/el2/Title /Users/me/Title me@example.org'
  const result = redactor.sanitizeString(input)
  for (const secret of ['secretA','secretB','secretC','secretD','secretE','secretF','secret G','secretH','Title','me@example.org'])
    assert.equal(result.includes(secret), false, secret)
  assert.equal(redactor.sanitizeString('<html>secret</html>'), '<omitted>')
  assert.equal(redactor.sanitizeString('requestBody=secret'), '<omitted>')
  assert.equal(redactor.sanitizeString('x'.repeat(500)).length, 223)
})

test('filtering and disabling apply to every sink; file and HiLog receive only redacted text', () => {
  const r = runtime(), { DiagnosticLogger: log } = r.load('DiagnosticLogger')
  log.initializePersistentSink({ filesDir: '/sandbox' })
  log.debug('source','start','hidden')
  log.info('source','done','Authorization: Bearer secret')
  assert.equal(log.count(), 1)
  assert.equal(log.exportText().includes('secret'), false)
  assert.equal(JSON.stringify(r.emitted).includes('secret'), false)
  log.configure(false)
  log.error('app','failure','disabled')
  assert.equal(log.count(), 1)
  log.configure(true, 'error')
  log.warn('app','warn','hidden')
  log.error('app','failure','recorded')
  assert.equal(log.count(), 2)
})

test('memory ring, rotation, total retention and previous-launch recovery stay bounded', () => {
  const r = runtime(), { DiagnosticLogger: log } = r.load('DiagnosticLogger')
  const { DiagnosticsLogFileSink: sink } = r.load('DiagnosticsLogFileSink')
  log.initializePersistentSink({ filesDir: '/sandbox' })
  for (let i=0; i<12000; i++) log.info('app','status', '中'.repeat(200))
  assert.equal(log.count(), 500)
  assert.ok(sink.listRetainedLogFiles().length > 1)
  assert.ok([...r.files.values()].every(value => Buffer.byteLength(value) <= 512 * 1024))
  assert.ok([...r.files.values()].reduce((sum, value) => sum + Buffer.byteLength(value), 0) <= 2 * 1024 * 1024)
  const old = sink.listRetainedLogFiles()[0].fileName
  log.closePersistentSink()
  log.initializePersistentSink({ filesDir: '/sandbox' })
  assert.ok(sink.readLogFileText(old).includes('app.status'))
  assert.equal(sink.isDiagnosticsLogFileName('../koma-log-20261022-120000.txt'), false)
  assert.equal(sink.readLogFileText('../preferences.xml'), '')
})

test('disk failure leaves memory diagnostics usable, and clearing memory retains files', () => {
  const r = runtime(), { DiagnosticLogger: log } = r.load('DiagnosticLogger')
  log.initializePersistentSink({ filesDir: '/sandbox' })
  log.info('app','started','ok')
  const before = [...r.files.values()].join('')
  log.clear()
  assert.equal(log.count(), 0)
  assert.equal([...r.files.values()].join(''), before)
  r.failWrites()
  log.warn('app','disk_test','memory_survives')
  assert.ok(log.exportBufferedText().includes('memory_survives'))
  assert.ok(log.exportText().includes('memory_survives'))
})


test('errors preserve platform code, known cause and code frames without arbitrary messages or identities', () => {
  const { DiagnosticsRedactor: redactor } = runtime().load('DiagnosticsRedactor')
  const error = Object.assign(new Error('secretTitle token=secretToken'), { code: 2300028 })
  error.stack = 'Error: secretTitle\n    at fetch (/data/storage/el2/secretTitle:1:2)\n    at load (ReaderPage.ets:42:5)'
  const summary = redactor.errorSummary(error)
  assert.match(summary, /code=2300028 reason=unclassified/)
  assert.match(summary, /ReaderPage.ets:42:5/)
  assert.equal(summary.includes('secret'), false)
  assert.match(redactor.errorSummary(new Error('reader_remote_image_http_403')), /reason=reader_remote_image_http_403/)
  assert.match(redactor.errorSummary(new Error('koma_reader_source_chapter_unsupported')), /reason=koma_reader_source_chapter_unsupported/)
  const message = redactor.sanitizeString('comic=privateComic chapter=privateChapter uri=privateUri count=3')
  assert.equal(message.includes('private'), false)
  assert.match(message, /count=3/)
})

test('interleaved operations keep unique identities, context, duration and exactly one terminal event', () => {
  const r = runtime(), { DiagnosticLogger: log } = r.load('DiagnosticLogger')
  log.initializePersistentSink({ filesDir: '/sandbox' })
  const first = log.begin('source', 'request', 'source=com.first')
  const second = log.begin('source', 'request', 'source=com.second')
  second.finish('completed', 'count=4')
  first.fail(Object.assign(new Error('privateMessage'), { code: 2300028 }))
  first.finish('completed', 'should_not_appear')
  const lines = log.exportBufferedText().split('\n').filter(line => line.includes('source.request.'))
  assert.equal(lines.length, 4)
  const ids = lines.map(line => line.match(/op=([^ ]+)/)[1])
  assert.notEqual(ids[0], ids[1])
  assert.equal(ids[0], ids[3])
  assert.equal(ids[1], ids[2])
  assert.match(lines[3], /source=com.first.*status=failed durationMs=\d+.*code=2300028/)
  assert.equal(lines.join('').includes('privateMessage'), false)
  assert.equal(log.exportText().includes('should_not_appear'), false)
  log.configure(true, 'warn')
  log.begin('download', 'chapter', 'pages=2').finish('partial', 'reason=page_fetch_failed')
  assert.match(log.exportBufferedText(), /pages=2.*status=partial.*reason=page_fetch_failed/)
})


test('ordinary source operation logging preserves responses and thrown objects without request content', async () => {
  const r = runtime(), { DiagnosticLogger: log } = r.load('DiagnosticLogger')
  const { diagnoseSourceOperation: run } = r.load('SourceRuntimeRunner')
  log.initializePersistentSink({ filesDir: '/sandbox' })
  const request = JSON.stringify({ sourceId: 'com.fixture', operation: 'get_manga',
    args: { mangaId: 'secretWork', query: 'secretQuery' }, settings: { token: 'secretToken' } })
  const response = '{"ok":true,"data":{"items":[{"title":"secretTitle"}]}}'
  assert.equal(await run(request, async () => response), response)
  const failed = '{"ok":false,"error":{"code":"network_error","message":"secretBody"}}'
  assert.equal(await run(request, async () => failed), failed)
  assert.equal(await run(request, async () => 'invalid response'), 'invalid response')
  const original = Object.assign(new Error('secretThrown'), { code: 2300028 })
  await assert.rejects(run(request, async () => { throw original }), error => error === original)
  const text = log.exportText()
  assert.equal(text.includes('secret'), false)
  assert.match(text, /source=com.fixture operation=get_manga.*status=completed/)
  assert.match(text, /reason=network_error/)
  assert.match(text, /reason=source_response_invalid_json/)
  assert.match(text, /code=2300028/)
})


function readerImageRequestRuntime({ headers, error, responseCode = 200, observerFails = false }) {
  const r = runtime(), { DiagnosticLogger: log } = r.load('DiagnosticLogger')
  const file = path.join(__dirname, '../entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
  const source = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true)
  const fn = source.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === 'downloadReaderRemoteBytes')
  assert.ok(fn)
  let observer, destroyed = false, options
  const bytes = new ArrayBuffer(7)
  const http = {
    RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 'buffer' },
    createHttp: () => ({
      on(event, callback) {
        assert.equal(event, 'headersReceive')
        if (observerFails) throw Error('privateObserverFailure')
        observer = callback
      },
      async request(_url, requestOptions) {
        options = requestOptions
        if (headers !== undefined) observer?.(headers)
        if (error) throw error
        return { responseCode, result: bytes }
      },
      destroy() { destroyed = true },
    }),
  }
  const exports = {}
  const js = ts.transpileModule(fn.getText(source) + '\nexports.fetch = downloadReaderRemoteBytes', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  vm.runInNewContext(js, { exports, http, DiagnosticLogger: log, httpHeadersForReaderRequest: value => value })
  return { run: () => exports.fetch('https://example.test/privateWork', { Authorization: 'privateToken' }),
    bytes, log, destroyed: () => destroyed, options: () => options }
}

test('reader HTTP failures retain observed response metadata without inventing received bytes', async () => {
  for (const headers of [undefined, { 'Content-Length': '28793918', 'Set-Cookie': 'privateCookie' }, { 'content-length': 'invalid' }]) {
    const r = readerImageRequestRuntime({ headers, error: Object.assign(new Error('privateBody'), { code: 2300028 }) })
    await assert.rejects(r.run(), /reader_remote_image_fetch_failed_2300028/)
    const text = r.log.exportBufferedText()
    assert.match(text, new RegExp('responseStarted=' + (headers !== undefined)))
    assert.match(text, new RegExp('declaredBytes=' + (headers?.['Content-Length'] || '-1')))
    assert.match(text, /receivedBytes=unknown.*code=2300028/)
    assert.equal(text.includes('private'), false)
    assert.equal(r.destroyed(), true)
    assert.equal(r.options().readTimeout, 60000)
    assert.equal(r.options().connectTimeout, 30000)
    assert.equal(r.options().maxLimit, undefined)
  }
})

test('reader HTTP diagnostics preserve returned bytes and survive unavailable or malformed observers', async () => {
  for (const config of [{ headers: { 'cOnTeNt-LeNgTh': '7' } }, { observerFails: true }, { headers: null }]) {
    const r = readerImageRequestRuntime(config)
    assert.equal(await r.run(), r.bytes)
    assert.equal(r.destroyed(), true)
    const text = r.log.exportBufferedText()
    assert.match(text, /status=completed.*bytes=7/)
    assert.equal(text.includes('private'), false)
  }
})
