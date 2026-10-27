const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function load(available, uiMaterial) {
  const exports = {}
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/theme/KomaPopupOptions.ets'), 'utf8')
  const js = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', 'Color', js)(exports, name => {
    if (name === '@kit.ArkUI') return { uiMaterial }
    if (name === '@kit.BasicServicesKit') return { deviceInfo: { apiAvailable: version => {
      assert.equal(version, '26.0.0')
      return available
    } } }
    throw Error(name)
  }, { Transparent: 'transparent' })
  return exports
}

test('API23 startup never reads the absent material enum for menus, context menus or sheets', () => {
  // The four AGC crash logs have ImmersiveStyle undefined. Also reject any
  // namespace read, proving the guard happens before evaluating the new API.
  const api = load(false, new Proxy({}, { get: () => { throw Error('API26 namespace accessed') } }))
  const menu = { placement: 'bottom', offset: { x: 1, y: 2 } }
  const context = { responseType: 'long-press' }
  const sheet = { height: 480, onDisappear: () => {} }
  assert.equal(api.komaMenuOptions(menu), menu)
  assert.equal(api.komaContextMenuOptions(context), context)
  assert.equal(api.komaSheetOptions(sheet), sheet)
  assert.equal(menu.systemMaterial, undefined)
  assert.equal(context.systemMaterial, undefined)
  assert.equal(sheet.systemMaterial, undefined)
  assert.deepEqual(menu.offset, { x: 1, y: 2 })
  assert.equal(sheet.height, 480)
  assert.equal(api.komaModalContentBackground('original-surface'), 'original-surface')
})

test('API26 keeps the adopted thick menus and ultra-thick sheets', () => {
  const api = load(true, { ImmersiveStyle: { THICK: 3, ULTRA_THICK: 4 },
    ImmersiveMaterial: class { constructor(options) { this.style = options.style } } })
  assert.equal(api.komaMenuOptions().systemMaterial.style, 3)
  assert.equal(api.komaContextMenuOptions().systemMaterial.style, 3)
  assert.equal(api.komaSheetOptions({}).systemMaterial.style, 4)
  assert.equal(api.komaModalContentBackground('original-surface'), 'transparent')
})
