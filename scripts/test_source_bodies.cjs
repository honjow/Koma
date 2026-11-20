// Runs the production resource owner against real temporary files. No device or network.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const vm = require('node:vm')
const crypto = require('node:crypto')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function load(name, mocks) {
  const exports = {}
  const code = ts.transpileModule(fs.readFileSync(path.join(__dirname,
    '../entry/src/main/ets/sourceRuntime/' + name + '.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  vm.runInNewContext(code, { exports, require: mocks, Uint8Array, ArrayBuffer, Map, Date, JSON, Error,
    setTimeout, clearTimeout, setInterval, clearInterval })
  return exports
}
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-body-'))
  const io = {
    OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4, READ_ONLY: 8 },
    mkdirSync: p => fs.mkdirSync(p), listFileSync: p => fs.readdirSync(p),
    accessSync: p => fs.existsSync(p),
    unlinkSync: p => fs.unlinkSync(p), closeSync: f => fs.closeSync(f.fd ?? f),
    openSync: (p, mode) => ({ fd: fs.openSync(p, mode & 4 ? 'w+' : mode & 8 ? 'r' : 'r+') }),
    writeSync: (fd, data, o) => fs.writeSync(fd, Buffer.from(data), 0, o.length, o.offset),
    readSync: (fd, data, o) => fs.readSync(fd, Buffer.from(data), 0, o.length, o.offset),
  }
  const makeHost = () => load('SourceBodyHost', name => name === '@kit.CoreFileKit' ? { fileIo: io } : {
    util: { generateRandomUUID: () => crypto.randomUUID(), Base64Helper: class {
      encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64') }
      decodeSync(value) { return Uint8Array.from(Buffer.from(value, 'base64')) }
    } },
  }).SourceBodyHost
  const host = makeHost()
  const scope = { sourceId: 'fixture', packageIdentity: 'pkg1', callId: 'call1' }
  host.configure(root)
  t.after(() => { host.finishCall('call1'); host.finishCall('call2'); fs.rmSync(root, { recursive: true, force: true }) })
  return { root, host, scope, restart: () => { const next = makeHost(); next.configure(root); return next } }
}
test('cold start reuses its directory and clears data abandoned by a departed process', t => {
  const f = fixture(t), input = f.host.create(f.scope)
  f.host.append(f.scope, input.id, new ArrayBuffer(3))
  const next = f.restart()
  assert.equal(next.available(), true)
  assert.equal(fs.readdirSync(f.root + '/source-bodies-v1').length, 0)
  const output = next.create(f.scope)
  next.append(f.scope, output.id, new ArrayBuffer(4))
  next.finishCall(f.scope.callId)
  assert.equal(fs.readdirSync(f.root + '/source-bodies-v1').length, 0)
})
test('multiple inputs, offsets and image handoff preserve bytes after call retirement', t => {
  const { root, host, scope } = fixture(t)
  const a = host.create(scope), b = host.create(scope)
  const bytes = crypto.randomBytes(2 * 1024 * 1024 + 31)
  host.append(scope, a.id, Uint8Array.from(bytes).buffer)
  host.write(scope, a.id, 5, Uint8Array.from([0, 255, 128]).buffer)
  bytes.set([0, 255, 128], 5)
  for (let offset = 0; offset < bytes.length; offset += 65536) {
    host.append(scope, b.id, host.read(scope, a.id, offset, Math.min(65536, bytes.length - offset)))
  }
  const result = JSON.parse(host.handoff(JSON.stringify({ ok: true, data: { image: { kind: 'body', ref: b.id } } }),
    JSON.stringify({ operation: 'get_image_request' }), scope))
  host.finishCall(scope.callId)
  assert.equal(fs.readdirSync(root + '/source-bodies-v1').length, 1)
  assert.throws(() => host.read(scope, a.id, 0, 1), /body_not_found/)
  assert.deepEqual(Buffer.from(host.takeImage(result.data.hostImageBody, scope.sourceId, scope.packageIdentity)), bytes)
  assert.throws(() => host.takeImage(b.id, scope.sourceId, scope.packageIdentity), /body_image_expired/)
  assert.equal(fs.readdirSync(root + '/source-bodies-v1').length, 0)
})
test('cross-call access, invalid ranges, capacity and failed-result cleanup are enforced', t => {
  const { root, host, scope } = fixture(t), a = host.create(scope)
  const other = { ...scope, callId: 'call2' }
  assert.throws(() => host.read(other, a.id, 0, 1), /body_not_found/)
  assert.throws(() => host.read(scope, a.id, -1, 1), /invalid_body_range/)
  assert.throws(() => host.write(scope, a.id, 1, new ArrayBuffer(1)), /invalid_body_range/)
  for (let n = 1; n < 16; n++) host.create(scope)
  assert.throws(() => host.create(scope), /body_limit_exceeded/)
  const reply = JSON.parse(host.handoff(JSON.stringify({ ok: false, data: { hostImageBody: a.id, image: { kind: 'body', ref: a.id } } }),
    JSON.stringify({ operation: 'get_image_request' }), scope))
  assert.equal(reply.data.hostImageBody, '')
  host.finishCall(scope.callId)
  assert.equal(fs.readdirSync(root + '/source-bodies-v1').length, 0)
})
test('stream spools chunks and cancellation removes partial data', async t => {
  const { root, host, scope } = fixture(t)
  const { requestSourceBodyStream: stream } = load('SourceHttpBodyStream', name => name === './SourceBodyHost' ?
    { SourceBodyHost: host } : {})
  const handlers = new Map()
  let live = true
  const request = { on: (name, handler) => handlers.set(name, handler), off: name => handlers.delete(name),
    requestInStream: async () => {
      handlers.get('headersReceive')({ 'content-type': 'application/octet-stream' })
      handlers.get('dataReceive')(Uint8Array.from([0, 255]).buffer)
      handlers.get('dataEnd')()
      return 206
    } }
  const result = await stream(request, 'https://fixture.test', {}, scope, () => live)
  assert.equal(result.status, 206)
  assert.deepEqual(Buffer.from(host.bytes(scope, result.bodyRef.id)), Buffer.from([0, 255]))
  host.close(scope, result.bodyRef.id)
  request.requestInStream = async () => {
    handlers.get('dataReceive')(new ArrayBuffer(8))
    live = false
    handlers.get('dataReceive')(new ArrayBuffer(8))
    handlers.get('dataEnd')()
    return 200
  }
  await assert.rejects(stream(request, 'https://fixture.test', {}, scope, () => live), /source_request_cancelled/)
  assert.equal(fs.readdirSync(root + '/source-bodies-v1').length, 0)
})
