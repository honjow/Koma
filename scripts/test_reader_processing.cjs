const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
const crop = {}
new Function('exports', ts.transpileModule(fs.readFileSync(path.join(root, 'model/ReaderPageCropBounds.ets'), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText)(crop)

function borderedPage(background) {
  const pixels = new Uint8Array(100 * 100 * 4)
  for (let y = 0; y < 100; y++) for (let x = 0; x < 100; x++) {
    const edge = x < 12 || x >= 88 || y < 12 || y >= 88
    pixels.set(edge ? [background, background, background, 255] : [100, 0, 0, 255], (y * 100 + x) * 4)
  }
  return pixels
}

test('adopted strengths preserve uncertain/blank pages and distinguish a real gray margin', () => {
  const detector = crop.ReaderPageCropDetector
  const gray = borderedPage(210)
  assert.equal(detector.detect(100, 100, 400, gray, 100, 100, 'conservative').applied(), false)
  assert.equal(detector.detect(100, 100, 400, gray, 100, 100, 'standard').applied(), false)
  const strong = detector.detect(100, 100, 400, gray, 100, 100, 'strong')
  assert.deepEqual([strong.left, strong.top, strong.right, strong.bottom], [.12, .12, .12, .12])
  const white = new Uint8Array(100 * 100 * 4).fill(255)
  for (const strength of ['conservative', 'standard', 'strong']) {
    assert.equal(detector.detect(100, 100, 400, white, 100, 100, strength).applied(), false)
    assert.equal(detector.detect(100, 100, 1, gray, 100, 100, strength).applied(), false)
  }
  assert.equal(detector.normalizeStrength('invalid'), 'standard')
})
