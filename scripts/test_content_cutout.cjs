const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/utils/ContentCutout.ets'), 'utf8')
const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText
const compiled = {}
new Function('exports', output)(compiled)
const { contentSidePadding } = compiled

const rect = (left, top, width, height) => ({ left, top, width, height })
const empty = rect(0, 0, 0, 0)
const landscape = {
  window: rect(0, 0, 900, 420),
  left: empty,
  right: empty,
  topInset: 24,
  bottomInset: 24,
}

test('switching rotation moves the extra margin to the actual cutout side', () => {
  const left = { ...landscape, left: rect(8, 190, 24, 40) }
  const right = { ...landscape, right: rect(868, 190, 24, 40) }
  assert.deepEqual(contentSidePadding(left, 12), { left: 44, right: 12 })
  assert.deepEqual(contentSidePadding(right, 12), { left: 12, right: 44 })
  assert.deepEqual(contentSidePadding(left, 36), { left: 68, right: 36 })
  assert.deepEqual(contentSidePadding({ ...left, window: rect(0, 0, 420, 900) }, 12), { left: 12, right: 12 })
})

test('covered corner cutouts do not move content, but an exposed corner does', () => {
  const covered = { ...landscape, left: rect(4, 4, 26, 20), right: rect(870, 400, 26, 16) }
  assert.deepEqual(contentSidePadding(covered, 12), { left: 12, right: 12 })
  const exposed = { ...covered, left: rect(4, 4, 26, 22) }
  assert.deepEqual(contentSidePadding(exposed, 12), { left: 42, right: 12 })
  const header = rect(0, 0, 900, 45)
  assert.deepEqual(contentSidePadding(covered, 12, header, false), { left: 42, right: 12 })
})

test('a bottom corner inside the page’s existing bottom clearance adds no side padding', () => {
  const lowerLeft = { ...landscape, left: rect(4, 364, 26, 32) }
  assert.deepEqual(contentSidePadding(lowerLeft, 12, undefined, true, 48), { left: 12, right: 12 })
  assert.deepEqual(contentSidePadding(lowerLeft, 12), { left: 42, right: 12 })
  const partlyExposed = { ...lowerLeft, left: rect(4, 344, 26, 52) }
  assert.deepEqual(contentSidePadding(partlyExposed, 12, undefined, true, 48), { left: 42, right: 12 })
})

test('a centered sheet or opposite detail pane keeps its original padding', () => {
  const layout = { ...landscape, left: rect(8, 190, 24, 40) }
  assert.deepEqual(contentSidePadding(layout, 12, rect(120, 80, 660, 340)), { left: 12, right: 12 })
  assert.deepEqual(contentSidePadding(layout, 12, rect(333, 65, 567, 355)), { left: 12, right: 12 })
  assert.deepEqual(contentSidePadding(layout, 12, rect(16, 65, 300, 355)), { left: 28, right: 12 })
})
