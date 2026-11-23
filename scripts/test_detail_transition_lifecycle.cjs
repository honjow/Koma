const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs'), path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture() {
  const modules = new Map()
  function load(file) {
    if (modules.has(file)) return modules.get(file)
    const exports = {}; modules.set(file, exports)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8')
    const js = ts.transpileModule(source, { compilerOptions: {
      target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true,
    } }).outputText
    new Function('require', 'exports', 'ObservedV2', 'Trace', js)(name => {
      if (name === '@kit.ArkUI') return { AppStorageV2: {} }
      if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key } }
      if (name.startsWith('.')) return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
      throw Error('Unexpected import ' + name)
    }, exports, () => {}, () => {})
    return exports
  }
  const { MangaDetailTransitionState, MangaDetailTransitionPhase: Phase } = load('state/MangaDetailTransitionState')
  const state = new MangaDetailTransitionState()
  function prepare(token, mode) {
    const resources = Array.from({ length: 3 }, () => ({ releases: 0, release() {
      this.releases++
      return Promise.resolve()
    } }))
    assert.equal(state.beginRouteContext(), true)
    state.beginSourceHandoff(mode, `card-${token}`, `cover-${token}`, 'source-list', false,
      `target-${token}`, 10, 30, 100, 150, resources[1], 10, 30, 100, 130, 12, resources[2], 'cover-uri')
    state.prepare(String(token), 0.25, 0.25, 10, 30, 12, 400, 800, resources[0])
    state.bindRouteDestination(`destination-${token}`)
    return resources
  }
  return { state, Phase, prepare }
}

// NextE's route contract: nested transitions move ownership; a child failure restores the parent.
test('failed child push restores its parent mode and pixel ownership without consuming another destination', () => {
  const { state, Phase, prepare } = fixture()
  const parent = prepare(1, 'coverExpand')
  state.markPushSettled(true)
  const child = prepare(2, 'seamless')
  assert.equal(state.suspendedDepth(), 1)
  state.markDetailLayoutReady(1)
  assert.equal(state.detailLayoutReady, false)
  state.markPushSettled(false)
  assert.equal(state.phase, Phase.OPEN)
  assert.equal(state.mode, 'coverExpand')
  assert.equal(state.owns(1, 'destination-1'), true)
  assert.equal(state.owns(1, 'destination-2'), false)
  assert.equal(state.sourceSnapshot, parent[0])
  assert.deepEqual(child.map(item => item.releases), [1, 1, 1])
  assert.deepEqual(parent.map(item => item.releases), [0, 0, 0])
  state.discardRouteContext('1', 'destination-2')
  assert.equal(state.hidesSource('card-1'), true)
  state.discardRouteContext('1', 'destination-1')
  state.reset()
  assert.equal(state.phase, Phase.IDLE)
  assert.deepEqual(parent.map(item => item.releases), [1, 1, 1])
})

// Cancelling cover-expand POP must reveal the settled detail, including when target cover is absent.
test('cancelled cover-expand return restores detail after fade fallback and releases resources once on exit', () => {
  const { state, Phase, prepare } = fixture()
  const resources = prepare(3, 'coverExpand')
  state.markPushSettled(true)
  state.useCoverFadePopFallback()
  state.beginPop()
  state.collapseWindow(12)
  state.revealSourceCard()
  assert.equal(state.fallbackCoverVisible(), true)
  state.markPopSettled(false)
  assert.equal(state.phase, Phase.OPEN)
  assert.equal(state.contentOpacity, 1)
  assert.equal(state.cardOpacity, 0)
  assert.equal(state.chromeVisible, true)
  assert.equal(state.radius, 0)
  assert.equal(state.clipWidth, 400)
  assert.equal(state.clipHeight, 800)
  assert.equal(state.coverMaskVisible(), false)
  assert.equal(state.fallbackCoverVisible(), false)
  assert.deepEqual(resources.map(item => item.releases), [0, 0, 0])
  state.beginPop()
  state.markPopSettled(true)
  state.reset()
  assert.deepEqual(resources.map(item => item.releases), [1, 1, 1])
})
