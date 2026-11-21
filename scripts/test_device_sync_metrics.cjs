const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/deviceSync/DeviceSyncMetrics.ets'), 'utf8')
const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText
const moduleExports = {}
const clock = { now: 0, timers: [] }
new Function('exports', 'require', 'setTimeout', code)(moduleExports, () => ({ systemDateTime: {
  TimeType: { STARTUP: 0 }, getUptime: () => clock.now,
} }), (callback, delay) => { clock.timers.push({ callback, delay }) })

test('sync slices leave a frame during reader motion and recheck cancellation when resuming', async () => {
  let cancelled = false
  const budget = new moduleExports.DeviceSyncSliceBudget(() => {
    if (cancelled) throw new Error('sync_cancelled')
  })
  try {
    clock.now = 2
    assert.equal(budget.yieldIfNeeded(), undefined)
    moduleExports.setDeviceSyncReaderMoving(true)
    const resume = budget.yieldIfNeeded()
    const timer = clock.timers.shift()
    assert.ok(timer.delay >= 1000 / 120)
    clock.now += timer.delay
    timer.callback()
    await resume
    assert.equal(budget.motionYields, 1)
    assert.equal(budget.yieldIfNeeded(), undefined)

    moduleExports.setDeviceSyncReaderMoving(false)
    clock.now += 4
    const cancelledResume = budget.yieldIfNeeded()
    const idleTimer = clock.timers.shift()
    assert.equal(idleTimer.delay, 0)
    cancelled = true
    idleTimer.callback()
    await assert.rejects(cancelledResume, /sync_cancelled/)
  } finally {
    moduleExports.setDeviceSyncReaderMoving(false)
  }
})

test('round metrics distinguish attempts, retries, success and overlapping elapsed time', () => {
  const metrics = new moduleExports.DeviceSyncMetrics(100)
  metrics.record('GET', 'v3', 0, 20, false)
  metrics.record('GET', 'v3', 200, 30, true)
  metrics.record('PROPFIND', 'v4', 207, 40, false)
  const first = metrics.snapshot(150)
  assert.equal(first.wallMs, 50)
  assert.deepEqual(first.requests[0], { method: 'GET', namespace: 'v3', attempts: 2,
    successful: 1, retries: 1, elapsedMs: 50, maxMs: 30 })
  assert.equal(first.requests[1].successful, 1)
  first.requests[0].attempts = 99
  assert.equal(metrics.snapshot(151).requests[0].attempts, 2)
})

test('only fixed labels are recorded and invalid durations do not pollute totals', () => {
  const metrics = new moduleExports.DeviceSyncMetrics(5)
  metrics.record('https://private.invalid/a', 'v3', 200, 10, false)
  metrics.record('GET', 'book-title', 200, 10, false)
  metrics.record('GET', 'v1', 404, NaN, false)
  metrics.record('GET', 'v1', 500, -1, true)
  const result = metrics.snapshot(4)
  assert.equal(result.wallMs, 0)
  assert.deepEqual(result.requests, [{ method: 'GET', namespace: 'v1', attempts: 2,
    successful: 0, retries: 1, elapsedMs: 0, maxMs: 0 }])
  assert.doesNotMatch(JSON.stringify(result), /private|book-title/)
})
