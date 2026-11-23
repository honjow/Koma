const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs'), path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture() {
  const modules = new Map(), states = new Map(), timers = new Map()
  let timerId = 0, sourceCurrent = true, navigations = 0, resolveCapture
  const capture = new Promise(resolve => { resolveCapture = resolve })
  const stack = { size: () => 0, getAllPathName: () => [] }
  function load(file) {
    if (modules.has(file)) return modules.get(file)
    const exports = {}; modules.set(file, exports)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8')
    const js = ts.transpileModule(source, { compilerOptions: {
      target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true,
    } }).outputText
    new Function('require', 'exports', 'ObservedV2', 'Trace', 'setTimeout', 'clearTimeout', js)(name => {
      if (name === '@kit.ArkUI') return {
        FrameCallback: class {}, UIUtils: { applySync: action => action() },
        curves: { cubicBezierCurve: () => ({ interpolate: x => x }) },
        AppStorageV2: { connect(_type, key, factory) {
          if (!states.has(key)) states.set(key, factory())
          return states.get(key)
        } },
      }
      if (name === '../common/RouterHelper') return { RouterHelper: { getAppPathStack: () => stack } }
      if (name === '../common/Constants') return { RouteName: { MANGA_DETAIL: 'MangaDetailPage' } }
      if (name === '../theme/ThemeConstants') return { ThemeConstants: { RADIUS_COVER: 12, RADIUS_CARD: 16 } }
      if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { info() {}, exception() {} } }
      if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key } }
      if (name.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
      throw Error('Unexpected import ' + name)
    }, exports, () => {}, () => {}, (action, delay) => {
      const id = ++timerId; timers.set(id, { action, delay }); return id
    }, id => timers.delete(id))
    return exports
  }
  const Coordinator = load('navigation/MangaDetailTransitionCoordinator').MangaDetailTransitionCoordinator
  const state = load('state/MangaDetailTransitionState').connectMangaDetailTransition()
  const ui = {
    px2vp: value => value,
    getComponentUtils: () => ({ getRectangleById: id => ({
      size: id === 'source-card' ? { width: 120, height: 240 } : { width: 400, height: 800 },
      windowOffset: { x: 0, y: 0 },
    }) }),
    getComponentSnapshot: () => ({ get: () => capture }),
  }
  return {
    state, get navigations() { return navigations },
    start: () => Coordinator.open(ui, 'source-card', () => { navigations++ }, '', '', undefined,
      () => sourceCurrent),
    leaveSource: () => { sourceCurrent = false },
    fireDeadline: () => {
      const timer = [...timers.values()].find(item => item.delay === 4500)
      assert.ok(timer, 'capture owns a bounded deadline')
      timer.action()
    },
    completeCapture: resolveCapture,
  }
}

test('capture deadline falls back once to ordinary details and releases the late snapshot', async () => {
  const f = fixture(), pending = f.start()
  f.fireDeadline()
  assert.equal(f.navigations, 1)
  assert.equal(f.state.eligible, false)
  let releases = 0
  f.completeCapture({ release: async () => { releases++ } })
  await pending
  assert.equal(f.navigations, 1)
  assert.equal(releases, 1)
})

test('leaving the source before the capture deadline cancels navigation and releases late pixels', async () => {
  const f = fixture(), pending = f.start()
  f.leaveSource()
  f.fireDeadline()
  let releases = 0
  f.completeCapture({ release: async () => { releases++ } })
  await pending
  assert.equal(f.navigations, 0)
  assert.equal(f.state.eligible, false)
  assert.equal(releases, 1)
})
