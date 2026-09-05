const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..')
const button = readFileSync(resolve(root, 'entry/src/main/ets/components/ui/KomaActionButton.ets'), 'utf8')
const field = readFileSync(resolve(root, 'entry/src/main/ets/components/ui/KomaFormTextField.ets'), 'utf8')
const parsed = ts.createSourceFile('Button.ts', button.replace(/\bstruct (\w+)/g, 'class $1'),
  ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const owner = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'KomaActionButton')
const methods = ['buttonForegroundColor', 'buttonBackgroundColor', 'buttonCornerRadius', 'buttonHorizontalPadding',
  'buttonBorderColor', 'buttonBorderWidth', 'disabledContent']
  .map(name => {
    const method = owner.members.find(node => node.name?.text === name)
    assert.ok(method, name)
    return method.getText(parsed)
  })
const disabledContentClass = parsed.statements.find(node => ts.isClassDeclaration(node) &&
  node.name.text === 'KomaDisabledActionContent').getText(parsed)
const compiled = ts.transpileModule(`${disabledContentClass}\nexport class Style { ${methods.join('\n')} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
}).outputText
const result = { exports: {} }
const tokens = { BRAND_PRIMARY: 'brand', TEXT_PRIMARY: 'text', TEXT_ON_BRAND: 'on-brand', DANGER: 'danger',
  SPACE_MD: 12, SPACE_LG: 16 }
new Function('module', 'exports', 'ThemeConstants', '$r', 'Color', compiled)(
  result, result.exports, tokens, key => key, { Transparent: 'transparent' })
function style(options = {}) {
  return Object.assign(new result.exports.Style(), { kind: 'secondary', isEnabled: true, compact: false,
    busy: false, fullWidth: false, fill: false, label: 'Action', controlHeight: 40 }, options)
}

assert.equal(style({ kind: 'primary' }).buttonBackgroundColor(), 'brand')
assert.equal(style({ kind: 'primary' }).buttonForegroundColor(), 'app.color.koma_action_on_accent')
assert.equal(style({ kind: 'primary', accentColor: 'custom' }).buttonForegroundColor(), 'on-brand')
assert.equal(style({ kind: 'danger' }).buttonBackgroundColor(), 'danger')
assert.equal(style({ kind: 'ghost' }).buttonBackgroundColor(), 'transparent')
assert.equal(style({ kind: 'primary', accentColor: 'custom' }).buttonBackgroundColor(), 'custom')
assert.equal(style({ kind: 'primary', fillColor: 'fill', accentColor: 'custom' }).buttonBackgroundColor(), 'fill')
assert.equal(style({ contentColor: 'content' }).buttonForegroundColor(), 'content')
for (const kind of ['primary', 'secondary', 'danger', 'ghost']) {
  const disabled = style({ kind, isEnabled: false })
  assert.equal(disabled.buttonForegroundColor(), 'sys.color.font_secondary', `${kind}: readable disabled label`)
  assert.equal(disabled.buttonBackgroundColor(), kind === 'ghost' ? 'transparent' :
    'sys.color.ohos_id_color_button_normal', `${kind}: neutral disabled surface`)
  for (const compact of [true, false]) {
    for (const controlHeight of [28, 32, 40]) {
      assert.equal(style({ kind, compact, controlHeight }).buttonCornerRadius(), controlHeight / 2)
    }
  }
}
assert.equal(style({ compact: true }).buttonHorizontalPadding(), 12)
assert.equal(style().buttonHorizontalPadding(), 16)
assert.equal(style().disabledContent(), undefined, 'Enabled native content and input handling stay unchanged')
const disabled = style({ isEnabled: false, compact: true, controlHeight: 32, icon: 'icon', fullWidth: true })
assert.deepEqual(Object.assign({}, disabled.disabledContent()), {
  label: 'Action', icon: 'icon', controlHeight: 32, horizontalPadding: 12, expand: true,
  foreground: 'sys.color.font_secondary', background: 'sys.color.ohos_id_color_button_normal',
  borderColor: 'transparent', borderWidth: 0,
})
assert.equal(style({ busy: true }).disabledContent().expand, false)
assert.equal(style({ isEnabled: false, fill: true }).disabledContent().expand, true)
disabled.isEnabled = true
assert.equal(disabled.disabledContent(), undefined, 'Reset custom disabled content when the action becomes enabled')
disabled.isEnabled = false
assert.ok(disabled.disabledContent(), 'Restore disabled drawing after input is cleared')
const disabledBuilder = button.slice(button.indexOf('function disabledActionContent('), button.indexOf('@ComponentV2'))
assert.ok(!/onClick|gesture\(|triggerClick/.test(disabledBuilder), 'Disabled drawing must not introduce an input path')
assert.equal((button.match(/\.contentModifier\(this\.disabledContent\(\)\)/g) || []).length, 2)
assert.equal((button.match(/if \(this\.isEnabled && !this\.busy\) \{\s*this\.ButtonContent\(\)/g) || []).length, 2,
  'Native and custom disabled children must be mutually exclusive after enabled-to-disabled transitions')
assert.equal((button.match(/\.backgroundColor\(this\.isEnabled && !this\.busy \? this\.buttonBackgroundColor\(\) : undefined\)/g) || []).length, 2,
  'Native background is explicitly restored when custom disabled content is removed')
assert.equal((button.match(/\.enabled\(this\.isEnabled && !this\.busy\)/g) || []).length, 2,
  'Both width variants must retain disabled and busy click gating')
assert.equal((button.match(/\.opacity\(1\)/g) || []).length, 2, 'Do not stack whole-button fading')
assert.ok(!button.includes('ThemeConstants.TEXT_TERTIARY'))
assert.ok(field.includes('Column({ space: ThemeConstants.SPACE_XS })'))
assert.ok(field.includes('.fontSize(ThemeConstants.FONT_SIZE_CAPTION)'))
assert.ok(field.includes('.fontWeight(FontWeight.Regular)'))
assert.ok(field.includes('.borderRadius(ThemeConstants.LIST_ROW_RADIUS)'))
assert.ok(field.includes(".backgroundColor($r('sys.color.ohos_id_color_button_normal'))"))
assert.ok(field.includes('.height(ThemeConstants.BUTTON_HEIGHT)'), 'Keep existing touch height')
assert.ok(field.includes('.type(this.isPassword ? InputType.Password : InputType.Normal)'))
assert.ok(field.includes('this.change(next)') && field.includes('this.submit()'))
for (const page of ['KavitaServerPage', 'KomgaServerPage', 'OpdsServerPage', 'WebDavServerPage']) {
  const source = readFileSync(resolve(root, `entry/src/main/ets/pages/${page}.ets`), 'utf8')
  const card = source.slice(source.indexOf('private FormCard()'), source.indexOf('private FormActions()'))
  const actions = source.slice(source.indexOf('private FormActions()'), source.indexOf('\n  build()'))
  assert.ok(!card.includes('KomaActionButton('), `${page}: fields and operations are distinct groups`)
  assert.ok(actions.indexOf('this.statusText()') < actions.indexOf("s('server_action_remove_config')"),
    `${page}: connection result belongs beside submit, not after removal`)
  assert.ok(actions.includes('this.saveAndTest()') && actions.includes('this.clearServer()'))
  assert.ok(actions.includes('accentColor: ThemeConstants.DANGER'))
  assert.ok(source.includes('this.FormActions()'))
}
function luminance(hex) {
  const channels = hex.slice(-6).match(/../g).map(value => parseInt(value, 16) / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4)
  return channels.reduce((sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index], 0)
}
for (const theme of ['base', 'dark']) {
  const colors = new Map(JSON.parse(readFileSync(resolve(root,
    `entry/src/main/resources/${theme}/element/color.json`), 'utf8')).color.map(item => [item.name, item.value]))
  const values = ['koma_accent', 'koma_action_on_accent'].map(key => luminance(colors.get(key))).sort((a, b) => b - a)
  assert.ok((values[0] + 0.05) / (values[1] + 0.05) >= 4.5, `${theme}: opaque primary label contrast`)
}
console.log('PASS: form/action source contracts and production style methods; device visual review remains required')
