const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture(run, clock = { setTimeout, clearTimeout }, execute = async (fn, ...args) => fn(...args)) {
  const handlers = new Map()
  const removed = []
  let destroyed = 0
  const request = {
    on(name, fn) { handlers.set(name, fn) },
    off(name, fn) { if (handlers.get(name) === fn) handlers.delete(name); removed.push(name) },
    destroy() { destroyed++ },
    requestInStream(address, options) { return run({ address, options, emit(name, value) { handlers.get(name)?.(value) } }) },
  }
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/deviceSync/DeviceSyncHttpStream.ets'), 'utf8')
  const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
  const exports = {}
  const ports = {
    '@kit.NetworkKit': { http: { createHttp: () => request } },
    '@kit.ArkTS': { taskpool: { execute }, util: {
      TextDecoder: { create: (encoding, options) => {
        const decoder = new TextDecoder(encoding, options)
        return { decodeToString: (bytes, options) => decoder.decode(bytes, options) }
      } },
    } },
  }
  new Function('require', 'exports', 'setTimeout', 'clearTimeout', code)(
    name => ports[name], exports, clock.setTimeout, clock.clearTimeout)
  return { request: exports.requestDeviceSyncStream, handlers, removed, destroyed: () => destroyed }
}
const noop = () => {}
const bytes = text => new TextEncoder().encode(text)
const buffer = part => part.buffer.slice(part.byteOffset, part.byteOffset + part.byteLength)
async function flushMicrotasks() { for (let i = 0; i < 6; i++) await Promise.resolve() }
function virtualClock() {
  let now = 0, next = 1
  const tasks = new Map()
  return {
    setTimeout(fn, delay) { const id = next++; tasks.set(id, { fn, at: now + delay }); return id },
    clearTimeout(id) { tasks.delete(id) },
    advance(ms) {
      const end = now + ms
      while (true) {
        const current = [...tasks.entries()].filter(([, task]) => task.at <= end).sort((a, b) => a[1].at - b[1].at)[0]
        if (!current) break
        tasks.delete(current[0]); now = current[1].at; current[1].fn()
      }
      now = end
    },
    count: () => tasks.size,
  }
}

test('waits for dataEnd after the status promise, preserving headers and split UTF-8', async () => {
  const source = bytes('你好😀/资料')
  const f = fixture(({ emit }) => {
    emit('headersReceive', { etag: '"abc"' })
    setTimeout(() => {
      for (const byte of source) emit('dataReceive', buffer(Uint8Array.of(byte)))
      emit('dataEnd')
    }, 5)
    return Promise.resolve(207)
  })
  const result = await f.request('https://fixture.invalid/', {}, noop)
  assert.deepEqual(result, { status: 207, body: '你好😀/资料', header: { etag: '"abc"' } })
  assert.equal(f.handlers.size, 0)
  assert.equal(f.destroyed(), 1)
  assert.deepEqual(f.removed.sort(), ['dataEnd', 'dataReceive', 'headersReceive'])
})

test('large directory responses have no shard-sized or 16 MiB receive limit', async () => {
  const chunk = bytes('abcdefgh'.repeat(128 * 1024))
  const f = fixture(({ emit }) => {
    emit('headersReceive', {})
    for (let i = 0; i < 17; i++) emit('dataReceive', buffer(chunk))
    emit('dataEnd')
    return Promise.resolve(207)
  })
  const result = await f.request('https://fixture.invalid/', {}, noop)
  assert.equal(result.body.length, 17 * 1024 * 1024)
  assert.equal(result.body.slice(-8), 'abcdefgh')
  assert.equal(f.destroyed(), 1)
})

test('empty and unsuccessful responses return without requiring a dataEnd event', async () => {
  for (const code of [204, 205, 401, 404]) {
    const f = fixture(({ emit }) => {
      emit('headersReceive', { 'content-length': '0' })
      return Promise.resolve(code)
    })
    assert.deepEqual(await f.request('https://fixture.invalid/', {}, noop),
      { status: code, body: '', header: { 'content-length': '0' } })
    assert.equal(f.handlers.size, 0)
    assert.equal(f.destroyed(), 1)
  }
})

test('network failure and cancellation preserve the error and clean up listeners', async () => {
  const failure = Object.assign(new Error('network'), { code: 2300028 })
  const f = fixture(() => Promise.reject(failure))
  await assert.rejects(f.request('https://fixture.invalid/', {}, noop), error => error === failure)
  assert.equal(f.handlers.size, 0)
  assert.equal(f.destroyed(), 1)

  let active = true
  const g = fixture(({ emit }) => {
    active = false
    emit('dataReceive', buffer(bytes('a')))
    return Promise.reject(new Error('request destroyed'))
  })
  await assert.rejects(g.request('https://fixture.invalid/', {}, () => {
    if (!active) throw new Error('sync_connection_changed')
  }), /sync_connection_changed/)
  assert.equal(g.handlers.size, 0)
  assert.equal(g.destroyed(), 1)
})

test('a progressing stream survives longer than five seconds without an artificial total deadline', async () => {
  const clock = virtualClock()
  let emit
  const f = fixture(({ emit: signal }) => { emit = signal; return Promise.resolve(207) }, clock)
  const request = f.request('https://fixture.invalid/', { readTimeout: 6000 }, noop)
  await flushMicrotasks()
  for (let i = 0; i < 4; i++) {
    clock.advance(4000)
    emit('dataReceive', buffer(bytes('x')))
    await flushMicrotasks()
  }
  emit('dataEnd')
  const result = await request
  assert.equal(result.body, 'xxxx')
  assert.equal(result.status, 207)
  assert.equal(clock.count(), 0)
  assert.equal(f.handlers.size, 0)
})

test('cancellation does not wait for a silent request or a missing dataEnd', async () => {
  for (const statusReturned of [false, true]) {
    const clock = virtualClock()
    let active = true
    const f = fixture(() => statusReturned ? Promise.resolve(207) : new Promise(() => {}), clock)
    const request = f.request('https://fixture.invalid/', { readTimeout: 60000 }, () => {
      if (!active) throw new Error('sync_connection_changed')
    })
    const rejection = assert.rejects(request, /sync_connection_changed/)
    await flushMicrotasks()
    active = false
    clock.advance(500)
    await rejection
    assert.equal(f.handlers.size, 0)
    assert.equal(f.destroyed(), 1)
    assert.equal(clock.count(), 0)
  }
})

test('cancellation during slow background decoding returns and observes a later worker error', async () => {
  const clock = virtualClock()
  let active = true, rejectWorker, signalWorker
  const decoding = new Promise((_resolve, reject) => { rejectWorker = reject })
  const workerStarted = new Promise(resolve => { signalWorker = resolve })
  const f = fixture(({ emit }) => {
    emit('dataReceive', buffer(bytes('body')))
    emit('dataEnd')
    return Promise.resolve(207)
  }, clock, () => { signalWorker(); return decoding })
  const request = f.request('https://fixture.invalid/', { readTimeout: 60000 }, () => {
    if (!active) throw new Error('sync_connection_changed')
  })
  const rejection = assert.rejects(request, /sync_connection_changed/)
  await workerStarted
  active = false
  clock.advance(500)
  await rejection
  assert.equal(f.handlers.size, 0)
  assert.equal(f.destroyed(), 1)
  assert.equal(clock.count(), 0)
  rejectWorker(new Error('late worker error'))
  await flushMicrotasks()
})

test('invalid UTF-8 and missing dataEnd fail instead of accepting truncated data', async () => {
  const bad = fixture(({ emit }) => {
    emit('dataReceive', Uint8Array.of(0xf0, 0x9f).buffer)
    emit('dataEnd')
    return Promise.resolve(207)
  })
  await assert.rejects(bad.request('https://fixture.invalid/', {}, noop), /sync_response_invalid/)
  assert.equal(bad.destroyed(), 1)

  const clock = virtualClock()
  const missingEnd = fixture(({ emit }) => {
    emit('dataReceive', buffer(bytes('<partial>')))
    return Promise.resolve(207)
  }, clock)
  const unfinished = missingEnd.request('https://fixture.invalid/', { readTimeout: 6000 }, noop)
  await flushMicrotasks()
  clock.advance(6000)
  await assert.rejects(unfinished, /sync_network_timeout/)
  assert.equal(missingEnd.handlers.size, 0)
  assert.equal(missingEnd.destroyed(), 1)
})
