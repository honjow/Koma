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
    const key = path.basename(name)
    if (modules.has(key)) return modules.get(key)
    const exports = {}
    modules.set(key, exports)
    vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, key + '.ets'), 'utf8'), {
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
