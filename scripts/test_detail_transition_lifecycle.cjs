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
  const { MangaDetailTransitionState, MangaDetailTransitionPhase: Phase, MANGA_DETAIL_SOURCE_SURFACE_SCALE } =
    load('state/MangaDetailTransitionState')
  const state = new MangaDetailTransitionState()
  function prepare(token, mode, surfaceRadius = 12) {
    const resources = Array.from({ length: 3 }, () => ({ releases: 0, release() {
      this.releases++
      return Promise.resolve()
    } }))
    assert.equal(state.beginRouteContext(), true)
    state.beginSourceHandoff(mode, `card-${token}`, `cover-${token}`, 'source-list', false,
      `target-${token}`, 10, 30, 100, 150, resources[1], 10, 30, 100, 130, 12, resources[2], 'cover-uri', surfaceRadius)
    state.prepare(String(token), 0.25, 0.25, 10, 30, 12, 400, 800, resources[0])
    state.bindRouteDestination(`destination-${token}`)
    return resources
  }
  return { state, Phase, prepare, sourceScale: MANGA_DETAIL_SOURCE_SURFACE_SCALE }
}

test('cover expansion matches the source surface and each display corner in both directions', () => {
  const { state, prepare } = fixture()
  const displayRadius = { topLeft: 32, topRight: 28, bottomLeft: 29, bottomRight: 34 }
  for (const sourceRadius of [12, 20]) {
    prepare(1, 'coverExpand', sourceRadius)
    assert.equal(state.radius, sourceRadius)
    assert.equal(state.flightCoverRadius, 12)
    state.setCoverTarget(15, 25, 104, 150, 8, 400, 800)
    state.expandWindow(displayRadius)
    assert.deepEqual(state.radius, displayRadius)
    assert.equal(state.flightCoverRadius, 8)
    state.markPushSettled(true)
    state.beginPop(displayRadius)
    assert.deepEqual(state.radius, displayRadius)
    state.collapseWindow(24)
    assert.equal(state.radius, sourceRadius)
    assert.equal(state.flightCoverRadius, 12)
    state.markPopSettled(true)
  }
})

test('the backdrop animates only on its owning transition and recovers after a cancelled return', () => {
  const { state, prepare, sourceScale } = fixture()
  prepare(1, 'seamless')
  state.animationStarted = true
  state.sourceSurfaceScale = sourceScale
  assert.equal(state.seamlessSourceScale('source-list'), sourceScale)
  assert.equal(state.seamlessSourceScale('another-list'), 1)
  state.markPushSettled(true)
  assert.equal(state.seamlessSourceScale('source-list'), 1)
  state.beginPop()
  state.sourceSurfaceScale = sourceScale
  assert.equal(state.seamlessSourceScale('source-list'), sourceScale)
  state.markPopSettled(false)
  assert.equal(state.sourceSurfaceScale, 1)
  assert.equal(state.seamlessSourceScale('source-list'), 1)
  state.reset()

  prepare(2, 'coverExpand')
  state.sourceSurfaceScale = sourceScale
  assert.equal(state.seamlessSourceScale('source-list'), 1)
})

// NextE's route contract: nested transitions move ownership; a child failure restores the parent.
test('changed detail artwork replaces the POP image only for its route and preserves nested ownership', () => {
  const { state, prepare } = fixture()
  const resources = prepare(10, 'coverExpand')
  const old = { uri: 'file://old' }, current = { uri: 'file://current' }
  state.coverSource = old
  state.markPushSettled(true)
  state.setDetailCoverSource(10, current)
  assert.equal(state.coverSource, old, 'a running/opened flight keeps its own pixels until POP preparation')
  const replacement = { releases: 0, release() { this.releases++; return Promise.resolve() } }
  assert.equal(state.replacePopCover(9, current, replacement), false)
  assert.equal(state.coverSnapshot, resources[2])
  assert.equal(state.replacePopCover(10, current, replacement), true)
  assert.equal(resources[2].releases, 1)
  assert.equal(state.coverSource, current)
  assert.equal(state.sourceArtworkChanged, true)
  prepare(11, 'seamless')
  state.markPushSettled(false)
  assert.equal(state.coverSource, current)
  assert.equal(state.detailCoverSource, current)
  assert.equal(state.coverSnapshot, replacement)
  state.reset()
  assert.equal(replacement.releases, 1)
})

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
