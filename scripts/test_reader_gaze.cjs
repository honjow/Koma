const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const path = require('node:path')
const { test } = require('node:test')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const logger = { info() {}, warn() {}, error() {} }
const diagnostic = '../diagnostics/DiagnosticLogger'

function load(name, ports = {}, globals = {}) {
  const filename = path.resolve(__dirname, '../entry/src/main/ets/readerGaze', name + '.ets')
  const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  }).outputText
  const exports = {}
  new Function('exports', 'require', ...Object.keys(globals), source)(exports, key => {
    assert.ok(key in ports, 'Unexpected platform import: ' + key)
    return ports[key]
  }, ...Object.values(globals))
  return exports
}

function deferred() {
  let resolve
  const promise = new Promise(done => { resolve = done })
  return { promise, resolve }
}

const engine = load('GazePageTurnEngine')
const enginePort = './GazePageTurnEngine'

test('a late permission callback cannot reopen a disposed reader', async () => {
  const permission = deferred()
  let cameraStarts = 0
  class Ar {
    static isSupported() { return true }
    onFrame() {}
    start() { cameraStarts++; return true }
    stop() {}
  }
  class Camera {
    static waitForPendingOperations() { return Promise.resolve() }
    onFrame() {}
    onError() {}
    stop() { return Promise.resolve() }
  }
  const { GazePageTurnController } = load('GazePageTurnController', {
    [enginePort]: engine, [diagnostic]: { DiagnosticLogger: logger },
    './GazeArTracker': { GazeArTracker: Ar }, './GazeCameraService': { GazeCameraService: Camera },
    '@kit.AbilityKit': { abilityAccessCtrl: { createAtManager: () => ({
      requestPermissionsFromUser: () => permission.promise
    }) } },
    '@kit.ArkUI': { display: { getDefaultDisplaySync: () => ({ width: 100, height: 200 }) } },
    '@kit.SensorServiceKit': {}
  })
  const controller = new GazePageTurnController(() => true, () => true)
  const pending = controller.setActive(true, {})
  controller.dispose()
  permission.resolve({ authResults: [0] })
  await pending
  assert.equal(cameraStarts, 0)
  assert.equal(controller.isTracking(), false)
})

test('cancelling detector setup releases it before starting a fresh camera', async () => {
  const initEntered = deferred()
  const finishInit = deferred()
  const events = []
  let first = true
  const front = { cameraPosition: 1 }
  const { GazeCameraService } = load('GazeCameraService', {
    [diagnostic]: { DiagnosticLogger: logger },
    '@kit.CoreVisionKit': { faceDetector: {
      init() {
        events.push('init')
        if (!first) return Promise.resolve(true)
        first = false
        initEntered.resolve()
        return finishInit.promise
      },
      async release() { events.push('release-detector') }
    } },
    '@kit.ImageKit': { image: {
      ImageFormat: { JPEG: 4 },
      createImageReceiver: () => ({
        async getReceivingSurfaceId() { return 'surface' },
        on() {},
        async release() {}
      })
    } },
    '@kit.CameraKit': { camera: {
      CameraPosition: { CAMERA_POSITION_FRONT: 1 },
      getCameraManager: () => ({
        getSupportedCameras: () => [front],
        getSupportedOutputCapability: () => ({ previewProfiles: [{ size: { width: 20, height: 10 } }] }),
        createCameraInput: () => ({
          async open() { events.push('open-camera') },
          async close() { events.push('close-camera') }
        }),
        createCaptureSession: () => ({
          beginConfig() {}, addInput() {}, addOutput() {}, async commitConfig() {},
          async start() {}, async stop() {}, async release() {}
        }),
        createPreviewOutput: () => ({ async release() {} })
      })
    } }
  })
  const camera = new GazeCameraService()
  let active = true
  const starting = camera.start({}, () => active)
  await initEntered.promise
  active = false
  const stopped = camera.stop()
  const next = camera.start({}, () => true)
  finishInit.resolve(true)
  assert.equal(await starting, false)
  await stopped
  assert.equal(await next, true)
  await camera.stop()
  assert.deepEqual(events, ['init', 'release-detector', 'init', 'open-camera', 'close-camera', 'release-detector'])
})

test('duplicate AR frames and interrupted confirmation cannot turn a page', () => {
  let now = Date.now()
  let poll = () => {}
  let raw
  let seq = 0
  let turns = 0
  let phase
  const native = { start: () => 0, stop() {}, readSample: () => raw }
  const { GazeArTracker } = load('GazeArTracker', {
    'libkoma_gaze_ar.so': { default: native }, [enginePort]: engine, [diagnostic]: { DiagnosticLogger: logger }
  }, { Date: { now: () => now }, setInterval: fn => { poll = fn; return 0 }, clearInterval() {} })
  const tracker = new GazeArTracker()
  const state = new engine.GazePageTurnEngine()
  state.onFire(() => { turns++ })
  state.onStateChange(next => { phase = next.phase })
  tracker.onFrame(sample => sample === null ? state.markLost(now) : state.feed(sample))
  tracker.start()
  const frame = (pitch, lossSequence = 0) => {
    raw = { hasFace: true, status: 0, frameSequence: ++seq, lossSequence, headPitchDeg: pitch, eyeUp: 0, eyeDown: 0 }
    now += 40
    poll()
  }
  for (let i = 0; i < 62; i++) frame(0)
  frame(-14)
  frame(-14)
  assert.equal(phase, engine.GazePhase.ARMED)
  frame(10)
  for (let i = 0; i < 5; i++) { now += 33; poll() }
  assert.equal(turns, 0)
  frame(10)
  frame(10, 1) // Native observed a loss between polls.
  frame(10, 1)
  assert.equal(turns, 0)
  frame(10, 1)
  assert.equal(turns, 1)
  tracker.stop()
})

test('low confidence cannot keep an armed engine alive', () => {
  const state = new engine.GazePageTurnEngine()
  let phase
  state.onStateChange(next => { phase = next.phase })
  let timestamp = Date.now()
  const frame = (pitch, probability = 1) => state.feed({ pitch, eyeCenterY: 0.5, probability, timestamp: timestamp += 40 })
  for (let i = 0; i < 62; i++) frame(0)
  frame(-14)
  frame(-14)
  assert.equal(phase, engine.GazePhase.ARMED)
  for (let i = 0; i < 60; i++) frame(0, 0.1)
  assert.equal(phase, engine.GazePhase.LOST)
})
