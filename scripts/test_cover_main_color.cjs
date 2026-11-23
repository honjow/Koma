const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
function load(file, dependencies) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/', file), 'utf8').replace(/^@Concurrent\s*$/gm, '')
  const output = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true,
  } }).outputText
  const exports = {}
  new Function('exports', 'require', 'ObservedV2', 'Trace', output)(exports,
    name => dependencies[name] || {}, value => value, () => {})
  return exports
}
function setup(pick) {
  const cache = load('CoverPixelMapMemoryCache.ets', { '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn() {} } } })
  const palette = load('CoverPaletteSelection.ets', {})
  const worker = load('CoverPaletteWorker.ets', { './CoverPaletteSelection': palette })
  const colors = load('CoverMainColor.ets', { './CoverPixelMapMemoryCache': cache,
    './CoverPaletteWorker': worker,
    '@kit.ImageKit': { image: { PixelMapFormat: { RGBA_8888: 3, BGRA_8888: 4 } } },
    '@kit.ArkTS': { taskpool: { execute: async (fn, ...args) => fn(...args) } },
    '@kit.ArkGraphics2D': { effectKit: { createColorPicker: async map => {
      const color = await pick(map)
      return { getTopProportionColors: () => [color] }
    } } } })
  return { cache: cache.coverPixelMapMemoryCache, colors }
}
function bitmap() {
  return { released: false, getPixelBytesNumber: () => 4,
    getImageInfoSync: () => ({ size: { width: 1, height: 1 }, pixelFormat: 3 }),
    async readPixelsToBuffer(buffer) { new Uint8Array(buffer).set([0, 0, 0, 255]) },
    async release() { this.released = true } }
}
function deferred() {
  let resolve, reject
  const promise = new Promise((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}
test('one extraction retains the actual cache bitmap through row recycling and clear', async () => {
  const result = deferred(); let calls = 0
  const { cache, colors } = setup(() => { calls++; return result.promise })
  const map = bitmap(), lease = await cache.acquireOrLoad('thumb', async () => map)
  const first = colors.cacheCoverMainColor('cover-a', lease)
  assert.equal(colors.cacheCoverMainColor('cover-a', lease), first)
  await cache.release(lease); await cache.clear()
  assert.equal(map.released, false)
  // Use an eligible purple swatch: the former brown fixture was excluded by
  // AndroidX's red I-line filter and only passed through the removed bypass.
  result.resolve({ red: 132, green: 67, blue: 98 }); await first
  assert.equal(calls, 1); assert.equal(map.released, true)
  assert.equal(colors.coverMainColor('cover-a', '#fallback'), '#844362')
  assert.equal(colors.coverMainColor('cover-b', '#fallback'), '#fallback')
})
test('a replaced cover wins even when the old extraction finishes later', async () => {
  const oldResult = deferred(), newResult = deferred()
  const oldMap = bitmap(), newMap = bitmap()
  const { cache, colors } = setup(map => map === oldMap ? oldResult.promise : newResult.promise)
  const oldLease = await cache.acquireOrLoad('old', async () => oldMap)
  const oldWork = colors.cacheCoverMainColor('same-uri', oldLease)
  const newLease = await cache.acquireOrLoad('new', async () => newMap)
  const newWork = colors.cacheCoverMainColor('same-uri', newLease)
  newResult.resolve({ red: 20, green: 80, blue: 120 }); await newWork
  oldResult.resolve({ red: 250, green: 0, blue: 0 }); await oldWork
  assert.equal(colors.coverMainColor('same-uri', '#fallback'), '#145078')
  await cache.release(oldLease); await cache.release(newLease); await cache.clear()
  assert.ok(oldMap.released && newMap.released)
})
test('an extraction failure preserves the fallback and releases its lease', async () => {
  const { cache, colors } = setup(async () => { throw new Error('native color failure') })
  const map = bitmap(), lease = await cache.acquireOrLoad('thumb', async () => map)
  await colors.cacheCoverMainColor('cover', lease)
  assert.equal(colors.coverMainColor('cover', '#fallback'), '#fallback')
  await cache.release(lease); await cache.clear(); assert.equal(map.released, true)
})

// Replaces the rejected blanket-dimming expectation: the user reported that
// it turned every cover gray. Selection must preserve a real palette swatch.
test('colored covers keep an actual colored swatch rather than scaled gray', () => {
  const { selectCoverPaletteColor } = load('CoverPaletteSelection.ets', {})
  const white = { red: 246, green: 245, blue: 244 }
  const paper = { red: 232, green: 195, blue: 204 }
  const pink = { red: 126, green: 12, blue: 61 }
  const blue = { red: 10, green: 28, blue: 122 }
  const gray = { red: 38, green: 39, blue: 40 }
  assert.equal(selectCoverPaletteColor([white, paper, gray, pink]), pink)
  assert.equal(selectCoverPaletteColor([white, gray, blue]), blue)
  // The user subsequently required a lower bound on color depth after the
  // real 108 badge remained pale. No eligible swatch keeps the host fallback.
  assert.equal(selectCoverPaletteColor([paper]), undefined, 'pale-only artwork must not bypass the color-depth limit')
  assert.equal(selectCoverPaletteColor([white, gray]), gray, 'genuinely neutral artwork stays neutral')
  assert.equal(selectCoverPaletteColor([null]), undefined)
  assert.equal(selectCoverPaletteColor([paper, white, blue], [100, 90, 1]), blue,
    'a dominant pale swatch cannot beat a smaller real blue swatch')
  const vividPink = { red: 200, green: 20, blue: 100 }
  assert.equal(selectCoverPaletteColor([white, gray, pink, vividPink], [100, 60, 30, 20]), vividPink,
    'AndroidX VIBRANT selects the vivid midtone, without a white-text contrast gate')
})
